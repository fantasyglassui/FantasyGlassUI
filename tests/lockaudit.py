import os as _os
ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))) + '/'   # the repository
# Combat-lockdown audit: loads the add-on in the smoke harness, marks the game's frames and every frame made
# from a secure template as protected, then replays timers, events and hooks "in combat" and lists every
# protected call (Show, Hide, SetPoint...) the add-on makes on one of them. Each of those is a blocked action in game.
import re, sys
from lupa import LuaRuntime
src = open(ROOT + 'tests/smoke.py', encoding='utf-8').read()
h = src[src.index("harness = r'''") + len("harness = r'''"): src.rindex("'''\nrun = lua.eval")]
def sub(old, new, count=1):
    global h
    assert h.count(old) == count, (old[:60], h.count(old))
    h = h.replace(old, new)

sub('''if not ns.featureGroups or not ns.configFrame then out[#out+1] = "the options did not come up after loading" end''', '''if not ns.featureGroups or not ns.configFrame then out[#out+1] = "the options did not come up after loading" end
for name in pairs(folderFiles or {}) do LoadFolderFiles(name) end       -- (the audit: both folders' handlers are in from the start)''')
sub('''local speedTimed = true''', '''local speedTimed = false''')     # (13.5 C's speed tests: no timing or speed lines in an instrumented run)
sub("local function newmock() return setmetatable({}, mockmt) end", r"""local function newmock() return setmetatable({}, mockmt) end
-- Protection, as the game works it out: a frame is protected if it was made so (a secure template, or one of the
-- game's own frames here), or if a protected frame is parented to it or anchored to it, and so on up the chain.
local audit = { on = false, hits = {}, order = {}, handler = "?", explicit = {}, dirty = true, set = {}, why = {} }
local PROT = {}
for _, m in ipairs({ "Show", "Hide", "SetShown", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight",
    "SetParent", "SetScale", "SetAttribute", "EnableMouse", "EnableMouseWheel", "SetFrameLevel", "SetFrameStrata", "Raise", "Lower",
    "StartMoving", "StopMovingOrSizing", "SetMovable", "SetHitRectInsets", "RegisterForClicks", "SetID", "SetToplevel", "SetClampedToScreen" }) do PROT[m] = true end
local EXEMPT = {}
local explicit
local function inset(f) return rawget(f, "__explicit") or audit.set[f] end
local function add(g, from, how)                              -- g becomes protected because of "from", and so on up its own chain
    if type(g) ~= "table" or getmetatable(g) ~= mockmt or EXEMPT[g] or inset(g) then return end
    audit.set[g] = true
    audit.why[g] = how .. " <- " .. tostring(rawget(from, "__label") or audit.why[from] or "?")
    add(rawget(g, "__parent"), g, "parent")
    for _, x in ipairs(rawget(g, "__anchors") or {}) do add(x, g, "anchor") end
end
local function spread(f)
    add(rawget(f, "__parent"), f, "parent")
    for _, x in ipairs(rawget(f, "__anchors") or {}) do add(x, f, "anchor") end
end
local function closure()
    if audit.dirty then
        audit.set, audit.why, audit.dirty = {}, {}, false
        for _, f in ipairs(audit.explicit) do if rawget(f, "__parent") or rawget(f, "__anchors") then spread(f) end end
    end
    return audit.set
end
explicit = function(f, label)
    if type(f) ~= "table" or getmetatable(f) ~= mockmt or rawget(f, "__explicit") or EXEMPT[f] then return end
    rawset(f, "__explicit", true); if not rawget(f, "__label") then rawset(f, "__label", label) end
    audit.explicit[#audit.explicit + 1] = f
    audit.set[f] = nil
    spread(f)
end
local function loses(f, g) return type(g) == "table" and not rawget(g, "__explicit") and audit.set[g] end   -- dropping this link may unprotect g
local function relation(self, name, a, b, c)
    local mine = inset(self)
    if name == "SetParent" then
        if mine and loses(self, rawget(self, "__parent")) then audit.dirty = true end
        rawset(self, "__parent", type(a) == "table" and a or nil)
        if mine and type(a) == "table" then add(a, self, "parent") end
    elseif name == "ClearAllPoints" or name == "SetAllPoints" or name == "SetPoint" then
        local list = rawget(self, "__anchors")
        if name ~= "SetPoint" then
            if mine and list then for _, g in ipairs(list) do if loses(self, g) then audit.dirty = true end end end
            list = nil
        end
        if name ~= "ClearAllPoints" then
            list = list or {}
            local got = false
            local function keep(v)                         -- (each frame once: a frame laid out again and again, as the Guide tab
                for _, x in ipairs(list) do if x == v then return end end      -- and the panel are, keeps a short list)
                list[#list + 1] = v
            end
            for _, v in ipairs({ a, b, c }) do if type(v) == "table" and getmetatable(v) == mockmt then keep(v); got = true end end
            if not got then local p = rawget(self, "__parent"); if p then keep(p) end end     -- (no frame named: its parent)
            if mine then for _, g in ipairs(list) do add(g, self, "anchor") end end
        end
        rawset(self, "__anchors", list)
    end
end
local wrapped = {}
local function method(name)
    if wrapped[name] then return wrapped[name] end
    wrapped[name] = function(self, a, b, c)
        if audit.on and type(self) == "table" and (rawget(self, "__explicit") or closure()[self]) then
            local tb = debug.traceback("", 2)
            local where = "?"
            for file, line in tb:gmatch("([%w_/]+%.lua):(%d+)") do where = file .. ":" .. line; break end
            local key = where .. "  " .. name .. "  on " .. tostring(rawget(self, "__label") or audit.why[self] or "?") .. "  [" .. audit.handler .. "]"
            if not audit.hits[key] then audit.hits[key] = 0; audit.order[#audit.order + 1] = key end
            audit.hits[key] = audit.hits[key] + 1
        end
        if type(self) == "table" then relation(self, name, a, b, c) end
        return newmock()
    end
    return wrapped[name]
end""")

sub("""    if k == "IsProtected" or k == "IsForbidden" then return function() return false end end""",
    """    if k == "IsForbidden" then return function() return false end end
    if k == "IsProtected" then return function(self)
        if rawget(self, "__explicit") then return true, true end
        if not audit.on then return false, false end
        return closure()[self] and true or false, false
    end end
    if k == "RegisterEvent" or k == "RegisterUnitEvent" then
        return function(self, ev)
            if type(ev) == "string" then
                audit.events = audit.events or {}; audit.events[ev] = true
                local set = rawget(self, "__events") or {}; rawset(self, "__events", set); set[ev] = true
            end
            return true
        end
    end
    if PROT[k] then return method(k) end""")

sub("""    local m = newmock(); rawset(t, k, m); return m
end
mockmt.__call""", """    local m = newmock(); rawset(t, k, m)
    if rawget(t, "__game") and type(k) == "string" then
        if k == "GetChildren" and (rawget(t, "__depth") or 0) < 2 then rawset(m, "__kids", tostring(rawget(t, "__label")) .. ":" .. k .. "()"); rawset(m, "__depth", (rawget(t, "__depth") or 0) + 1)
        elseif k:match("^[A-Z]") and not k:match("^Get") and not k:match("^Create") and not k:match("^Is") and not k:match("^Set")
            and (rawget(t, "__depth") or 0) < 6 then         -- (a game frame's own parts, a few levels down: a walk that goes on
            rawset(m, "__game", true); rawset(m, "__depth", (rawget(t, "__depth") or 0) + 1)   -- through .ScrollTarget for ever stops)
            explicit(m, tostring(rawget(t, "__label")) .. "." .. k)
        end
    end
    return m
end
mockmt.__call""")
sub("""mockmt.__call = function() return newmock() end""", """mockmt.__call = function(fn)
    local kids = rawget(fn, "__kids")
    if not kids then return newmock() end
    local m = rawget(fn, "__kid")                      -- (the same child every time, so tree walks stay bounded)
    if not m then m = newmock(); rawset(fn, "__kid", m); rawset(m, "__game", true); rawset(m, "__depth", rawget(fn, "__depth")); explicit(m, kids) end
    return m
end""")

sub("""  CreateFrame = function(kind) local f = newmock(); if type(kind) == "string" then rawset(f, "__kind", kind) end; return f end,""",
    """  CreateFrame = function(kind, name, parent, template)
      local f = newmock(); if type(kind) == "string" then rawset(f, "__kind", kind) end
      if type(parent) == "table" then rawset(f, "__parent", parent) end
      if type(name) == "string" then rawset(f, "__label", "our " .. name) end
      if type(template) == "string" and template:find("Secure") then explicit(f, "our " .. template .. (type(name) == "string" and (" " .. name) or "")) end
      return f
  end,""")

sub("""    missing[k] = true
    local m = newmock(); rawset(t, k, m); return m
end })""", """    missing[k] = true
    local m = newmock(); rawset(t, k, m)
    local plain = { UIParent = 1, WorldFrame = 1, GameTooltip = 1, Minimap = 1, MinimapCluster = 1, DEFAULT_CHAT_FRAME = 1 }
    if type(k) == "string" and k:match("^[A-Z]") and not k:match("^C_") and not k:match("^[A-Z_0-9]+$") and not k:match("^ChatFrame") and not k:match("Font") then
        if plain[k] then EXEMPT[m] = true else rawset(m, "__game", true); explicit(m, k) end
    end
    return m
end })""")

tail = '''local seen, uniq = {}, {}
for _, l in ipairs(out) do'''
sub(tail, r'''-- ===== the combat pass =====
do
    -- a fight begins: the game sends this first, and only then do its combat rules apply
    env.InCombatLockdown = function() return false end
    for i = 1, #handlers do
        local hd = handlers[i]
        if hd.name == "OnEvent" and (rawget(hd.self, "__events") or {}).PLAYER_REGEN_DISABLED then pcall(hd.fn, hd.self, "PLAYER_REGEN_DISABLED") end
    end
    env.InCombatLockdown = function() return true end
    env.UnitAffectingCombat = function() return true end
    ns.moving, ns.previewing = nil, nil
    audit.on = true
    -- (a window opened for the first time during a fight is restyled during that fight: forget what was already done)
    for _, f in ipairs(audit.explicit) do
        local drop = {}
        for k in pairs(f) do if type(k) == "string" and k:sub(1, 3) == "sui" then drop[#drop + 1] = k end end
        for _, k in ipairs(drop) do rawset(f, k, nil) end
    end
    local evs = {}
    for ev in pairs(audit.events or {}) do evs[#evs + 1] = ev end
    table.sort(evs)
    local SKIP = { OnClick = 1, PostClick = 1, PreClick = 1, OnMouseDown = 1, OnMouseUp = 1, OnDragStart = 1, OnDragStop = 1, OnTextChanged = 1,
                   OnValueChanged = 1, OnEscapePressed = 1, OnEnterPressed = 1, OnMouseWheel = 1, OnKeyDown = 1, OnEditFocusLost = 1, OnEditFocusGained = 1, OnChar = 1 }
    local args = { { "player" }, { "target" }, { "Blizzard_TalentUI" }, { 1, 2 } }
    for round = 1, 2 do
        local n = #handlers
        for i = 1, n do
            local hd = handlers[i]
            if not SKIP[hd.name] then
                audit.handler = hd.name
                if hd.name == "OnUpdate" then for _, e in ipairs({ 0.06, 0.25, 1.01, 2.5 }) do pcall(hd.fn, hd.self, e) end
                elseif hd.name == "OnEvent" then
                    local mine = rawget(hd.self, "__events") or {}
                    for _, ev in ipairs(evs) do
                        if mine[ev] and ev ~= "PLAYER_REGEN_ENABLED" and ev ~= "PLAYER_REGEN_DISABLED" and ev ~= "PLAYER_LOGIN" and ev ~= "VARIABLES_LOADED" and ev ~= "PLAYER_LOGOUT" then
                            audit.handler = "event " .. ev
                            for _, a in ipairs(args) do pcall(hd.fn, hd.self, ev, a[1], a[2]) end
                        end
                    end
                elseif hd.name == "hook" then pcall(hd.fn, newmock(), "player")
                elseif hd.name == "OnAttributeChanged" then pcall(hd.fn, hd.self, "unit", "raid3")
                else pcall(hd.fn, hd.self) end
            end
        end
        audit.handler = "timer"
        for _ = 1, 6 do local batch = timers; timers = {}; for _, fn in ipairs(batch) do pcall(fn) end end
    end
    local lines = {}
    for _, key in ipairs(audit.order) do lines[#lines + 1] = string.format("%5d  %s", audit.hits[key], key) end
    table.sort(lines, function(a, b) return a:sub(8) < b:sub(8) end)
    lines[#lines + 1] = "--- our frames that count as protected in combat (and why) ---"
    audit.dirty = true
    local set, tally = {}, {}
    for f in pairs(closure()) do set[f] = true end
    for _, f in ipairs(audit.explicit) do set[f] = true end
    for f in pairs(set) do
        if not rawget(f, "__game") then
            local label = tostring(rawget(f, "__label") or "(unnamed)") .. (rawget(f, "__explicit") and "  [secure template]" or ("  <= " .. tostring(audit.why[f])))
            tally[label] = (tally[label] or 0) + 1
        end
    end
    local names = {}
    for label, n in pairs(tally) do names[#names + 1] = string.format("%4d x %s", n, label) end
    table.sort(names, function(a, b) return a:sub(8) < b:sub(8) end)
    for _, l in ipairs(names) do lines[#lines + 1] = l end
    return table.concat(lines, "\n"), #evs, #handlers, 0
end
''' + tail)

lua = LuaRuntime(unpack_returned_tuples=True)
import glob, os
os.chdir(ROOT + 'FantasyGlassUI')
OPT = '../FantasyGlassUI_Options/'
toc = [l.strip() for l in open('FantasyGlassUI.toc') if l.strip().endswith('.lua')]
opt_toc = [l.strip() for l in open(OPT + 'FantasyGlassUI_Options.toc') if l.strip().endswith('.lua')]
run = lua.eval('function(code, ...) return load(code)(...) end')
FOLDERS = [('planner/', '../FantasyGlassUI_Planner/', 'FantasyGlassUI_Planner'), ('gold/', '../FantasyGlassUI_Gold/', 'FantasyGlassUI_Gold')]
folder_toc = {name: [l.strip() for l in open(d + name + '.toc') if l.strip().endswith('.lua')] for _, d, name in FOLDERS}
sources = lua.table_from({**{f: open(f).read() for f in toc}, **{'options/' + f: open(OPT + f).read() for f in opt_toc},
                          **{pre + f: open(d + f).read() for pre, d, name in FOLDERS for f in folder_toc[name]},
                          'locales/Locales.lua': open('../FantasyGlassUI_Locales/Locales.lua').read()})
secret = len(sys.argv) > 1 and sys.argv[1] == 'secret'
h = """local __t0, __n = os.clock(), 0
debug.sethook(function()
    if os.clock() - __t0 > (tonumber(os.getenv("STUCK")) or 1e9) then __n = __n + 1; print(debug.traceback("STUCK " .. __n, 2)); if __n >= 3 then os.exit(1) end; __t0 = os.clock() - (tonumber(os.getenv("STUCK")) or 0) + 2 end
end, "", 5000000)
""" + h
folder_files = lua.table_from({name: lua.table_from([pre + f for f in folder_toc[name]]) for pre, d, name in FOLDERS})
report, nev, nh, _ = run(h, lua.table_from(toc), sources, lua.table(), secret, lua.table_from(['options/' + f for f in opt_toc]), None, folder_files)
print(f"events the add-on listens for: {nev}; handlers replayed in combat: {nh}")
print(report if report else "(no protected calls in combat)")
