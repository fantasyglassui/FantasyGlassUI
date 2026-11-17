import os as _os
ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))) + '/'   # the repository
# Hidden-value audit. In combat this game hands add-ons "secret" values: they can be stored and passed on,
# but comparing one (== or ~=) raises an error, and so does testing a hidden yes/no ("if afk then", "not afk",
# "afk and ..."): both seen in this client's error reports. Plain Lua cannot notice an == on a table standing in for a
# secret, so the test harness never saw these. This script rewrites every == and ~= in the add-on into a
# checked call (line numbers are kept), makes the harness hide unit identities (name, class, "is this unit
# that unit") the way the game does, runs the whole suite in hidden mode, and lists each line that compared
# a hidden value. Errors and test failures from the suite itself are ignored here: only those lines matter.
import sys, os, re, hashlib, json
from lupa import LuaRuntime

CACHE = _os.environ.get('FGUI_TEST_CACHE') or (ROOT + 'tests/.cache')
os.makedirs(CACHE, exist_ok=True)

def instrument(src, name):
    key = hashlib.sha1(('v5' + src).encode()).hexdigest()
    path = os.path.join(CACHE, key + '.lua')
    if os.path.exists(path):
        return open(path).read()
    from luaparser import ast
    tree = ast.parse(src)
    events = []                                     # (pos, order, depth, text, skip)
    def walk(n, depth):
        if not isinstance(n, ast.Node): return
        nm = type(n).__name__
        if nm in ('EqToOp', 'NotEqToOp'):
            ls, le = n.left.first_token.start, n.left.last_token.stop
            rs, re_ = n.right.first_token.start, n.right.last_token.stop
            between = src[le + 1:rs]
            op = '==' if nm == 'EqToOp' else '~='
            at = between.find(op)
            assert at >= 0 and '--' not in between[:at], (name, between)
            events.append((ls, 1, depth, '__EQ(' if nm == 'EqToOp' else '__NE(', 0))      # opens: outer first
            events.append((le + 1 + at, 2, 0, ',', 2))                                    # the operator becomes a comma
            events.append((re_ + 1, 0, -depth, ')', 0))                                   # closes: inner first
        tested = None                                # the part of this node whose truth is tested
        if nm in ('If', 'ElseIf', 'While', 'Repeat'): tested = n.test
        elif nm in ('AndLoOp', 'OrLoOp'): tested = n.left
        elif nm == 'ULNotOp': tested = n.operand
        if tested is not None and type(tested).__name__ not in ('EqToOp', 'NotEqToOp', 'TrueExpr', 'FalseExpr', 'Nil', 'Number', 'String',
                                                                 'LessThanOp', 'GreaterThanOp', 'LessOrEqThanOp', 'GreaterOrEqThanOp'):
            events.append((tested.first_token.start, 1, depth + 0.5, '__T(', 0))
            events.append((tested.last_token.stop + 1, 0, -(depth + 0.5), ')', 0))
        for k, v in vars(n).items():
            if k.startswith('_'): continue
            if isinstance(v, ast.Node): walk(v, depth + 1)
            elif isinstance(v, list):
                for i in v: walk(i, depth + 1)
    walk(tree, 0)
    events.sort(key=lambda e: (e[0], e[1], e[2]))
    out, pos = [], 0
    for at, _, _, text, skip in events:
        out.append(src[pos:at]); out.append(text); pos = at + skip
    out.append(src[pos:])
    res = ''.join(out)
    assert res.count('\n') == src.count('\n')
    open(path, 'w').write(res)
    return res

smoke = open(ROOT + 'tests/smoke.py', encoding='utf-8').read()
h = smoke[smoke.index("harness = r'''") + len("harness = r'''"): smoke.rindex("'''\nrun = lua.eval")]
def sub(old, new):
    global h
    assert h.count(old) == 1, (old[:60], h.count(old))
    h = h.replace(old, new)

sub('''local function SV(n) if secretMode then return setmetatable({ __secret = true }, secretmt) end return n end''',
    '''local function SV(n) if secretMode then return setmetatable({ __secret = true, __type = type(n) }, secretmt) end return n end''')
sub('''-- resurrections and summons: what the game would answer, changed by the tests''', r'''-- ===== hidden-value audit =====
local secretHits, secretOrder = {}, {}
local function isSecret(v) return type(v) == "table" and rawget(v, "__secret") == true end
local function check(a, b)
    if (isSecret(a) and b ~= nil) or (isSecret(b) and a ~= nil) then
        local tb = debug.traceback("", 3)
        local where = "?"
        for file, line in tb:gmatch("([%w_/]+%.lua):(%d+)") do where = file .. ":" .. line; break end
        if not secretHits[where] then secretHits[where] = 0; secretOrder[#secretOrder + 1] = where end
        secretHits[where] = secretHits[where] + 1
        error("attempt to compare a secret value", 3)
    end
end
known.__EQ = function(a, b) check(a, b); return a == b end
-- a hidden yes/no cannot be tested; a hidden number or text can (it only says "there is something")
known.__T = function(v)
    if isSecret(v) and rawget(v, "__type") == "boolean" then
        local tb = debug.traceback("", 2)
        local where = "?"
        for file, line in tb:gmatch("([%w_/]+%.lua):(%d+)") do where = file .. ":" .. line; break end
        where = where .. "  (tested a hidden yes/no)"
        if not secretHits[where] then secretHits[where] = 0; secretOrder[#secretOrder + 1] = where end
        secretHits[where] = secretHits[where] + 1
        error("attempt to perform boolean test on a secret boolean value", 2)
    end
    return v
end
known.__NE = function(a, b) check(a, b); return a ~= b end
-- Unit identities are hidden for anyone who is not you or in your group, and "is this unit that unit"
-- is hidden whenever a token like "mouseovertarget" is involved.
do
    local function mine(u) return u == "player" or u == "pet" or u == "vehicle" or (type(u) == "string" and (u:match("^party%d+$") or u:match("^raid%d+$"))) end
    local function compound(u) return type(u) == "string" and (u:match("^nameplate") or u:match("^boss") or (#u > 6 and u:sub(-6) == "target")) end
    local names = { "UnitName", "UnitClass", "UnitGUID", "UnitClassification", "UnitCreatureType", "UnitRace", "GetUnitName", "UnitFullName", "UnitIsUnit",
                    "UnitIsAFK", "UnitIsDND" }
    local ALWAYS = { UnitIsAFK = true, UnitIsDND = true }       -- hidden in combat even about yourself
    local BOOLS = { UnitIsUnit = true, UnitIsAFK = true, UnitIsDND = true, UnitIsPlayer = true, UnitCanAttack = true, UnitIsDead = true, UnitIsDeadOrGhost = true,
                    UnitIsTapDenied = true, UnitIsFriend = true, UnitIsEnemy = true, UnitIsConnected = true }
    if os.getenv("TIER") == "2" then          -- (a wider guess at what the game might hide: for looking, not for the build)
        for _, extra in ipairs({ "UnitIsPlayer", "UnitReaction", "UnitCanAttack", "UnitIsDead", "UnitIsDeadOrGhost", "UnitIsTapDenied", "UnitPowerType",
                                 "UnitIsFriend", "UnitIsEnemy", "UnitLevel", "GetRaidTargetIndex", "UnitThreatSituation", "UnitCastingInfo", "UnitChannelInfo",
                                 "UnitIsConnected", "UnitGroupRolesAssigned" }) do names[#names + 1] = extra end
    end
    known.__hiddenNames = names
    for _, name in ipairs(names) do
        local real = known[name]
        known[name] = function(u, v, ...)
            local hide
            if name == "UnitIsUnit" then hide = compound(u) or compound(v)
            elseif ALWAYS[name] then hide = true
            else hide = type(u) == "string" and not mine(u) end
            if not hide then
                if real then return real(u, v, ...) end
                return newmock()
            end
            local r = real and { real(u, v, ...) } or {}
            if #r == 0 then if BOOLS[name] then r[1] = false else r[1] = "x" end end
            for i = 1, #r do
                local kind = type(r[i])
                if kind == "table" then kind = BOOLS[name] and "boolean" or "string" end       -- (a mock stood in for the answer)
                r[i] = setmetatable({ __secret = true, __type = kind }, secretmt)
            end
            return (table.unpack or unpack)(r)
        end
    end
end
-- resurrections and summons: what the game would answer, changed by the tests''')

sub('''    if k == "IsProtected" or k == "IsForbidden" then return function() return false end end''',
    '''    if k == "IsProtected" or k == "IsForbidden" then return function() return false end end
    if k == "RegisterEvent" or k == "RegisterUnitEvent" then
        return function(self, ev)
            if type(ev) == "string" then local set = rawget(self, "__events") or {}; rawset(self, "__events", set); set[ev] = true end
            return true
        end
    end''')
sub('''return (#uniq == 0 and "no errors" or table.concat(uniq, "\\n")), (#puniq == 0 and "none" or table.concat(puniq, "\\n")), #handlers, #ns.modules''',
    '''-- Every handler once more, with each event it asked for and as each kind of unit, in and out of combat:
-- the tests above only fire what they are testing.
do
    local SKIP = { OnClick = 1, PostClick = 1, PreClick = 1, OnMouseDown = 1, OnMouseUp = 1, OnDragStart = 1, OnDragStop = 1, OnTextChanged = 1,
                   OnValueChanged = 1, OnEscapePressed = 1, OnEnterPressed = 1, OnMouseWheel = 1, OnKeyDown = 1, OnEditFocusLost = 1, OnEditFocusGained = 1, OnChar = 1 }
    for _, name in ipairs(known.__hiddenNames) do rawset(env, name, nil) end      -- (a test may have left its own answer in place)
    for _, combat in ipairs({ false, true }) do
        env.InCombatLockdown = function() return combat end
        local n = #handlers
        for i = 1, n do
            local hd = handlers[i]
            if not SKIP[hd.name] then
                if hd.name == "OnUpdate" then for _, e in ipairs({ 0.06, 1.01, 2.5 }) do pcall(hd.fn, hd.self, e) end
                elseif hd.name == "OnEvent" then
                    for ev in pairs(rawget(hd.self, "__events") or {}) do
                        if ev ~= "PLAYER_LOGIN" and ev ~= "VARIABLES_LOADED" and ev ~= "PLAYER_LOGOUT" and ev ~= "ADDON_LOADED" then
                            for _, a in ipairs({ "player", "target", "nameplate1", "party1" }) do pcall(hd.fn, hd.self, ev, a, a) end
                        end
                    end
                elseif hd.name == "hook" then pcall(hd.fn, newmock(), "target")
                else pcall(hd.fn, hd.self) end
            end
        end
        for _ = 1, 6 do local batch = timers; timers = {}; for _, fn in ipairs(batch) do pcall(fn) end end
    end
end
local lines = {}
table.sort(secretOrder)
for _, where in ipairs(secretOrder) do lines[#lines + 1] = string.format("%5d  %s", secretHits[where], where) end
return table.concat(lines, "\\n"), #secretOrder, #handlers, #ns.modules''')

os.chdir(ROOT + 'FantasyGlassUI')
OPT = '../FantasyGlassUI_Options/'
toc = [l.strip() for l in open('FantasyGlassUI.toc') if l.strip().endswith('.lua')]
opt_toc = [l.strip() for l in open(OPT + 'FantasyGlassUI_Options.toc') if l.strip().endswith('.lua')]
srcs = {}
for f in toc: srcs[f] = instrument(open(f).read(), f)
for f in opt_toc: srcs['options/' + f] = instrument(open(OPT + f).read(), f)
srcs['locales/Locales.lua'] = open('../FantasyGlassUI_Locales/Locales.lua').read()     # (the translations folder: only tables)
lua = LuaRuntime(unpack_returned_tuples=True)
run = lua.eval('function(code, ...) return load(code)(...) end')
report, n, nh, nm = run(h, lua.table_from(toc), lua.table_from(srcs), lua.table(), True, lua.table_from(['options/' + f for f in opt_toc]))
print(f"hidden-value audit: {nm} modules, {nh} scripts and hooks; {n} lines compared a hidden value")
if report: print(report)
