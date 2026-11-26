local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Quest guide: follow a route one step at a time. The panel shows the step you are on, the arrow
-- points to it, and the guide moves on by itself when the step is done (a quest accepted, its
-- objectives finished, the quest handed in, a place reached, a level gained).
--
-- A guide is a list of steps, written one to a line:
--     guide: Riverglades 1-6
--     accept 123 A Fine Start | Marshal Dunn @ 37:45.2,62.1
--     do 123 A Fine Start | Kill 8 young wolves @ 37:40,60
--     turnin 123 A Fine Start | Marshal Dunn @ 37:45.2,62.1
--     goto | Cross the bridge @ 37:50,50
--     note Sell and repair
--     level 6
-- "@ map:x,y" is where (the map's number, then percent across and down); "@ x,y" means the map you
-- are on. Guides come from three places: you record one as you play (/fgui guide record My route),
-- you paste one someone gave you (/fgui guide edit), or one ships with the add-on.
------------------------------------------------------------------------------------------
ns.guideKinds = {
    accept = { "!", { 1, 0.82, 0.2 }, "Accept" },   turnin = { "?", { 1, 0.82, 0.2 }, "Turn in" },
    ["do"] = { "*", { 0.92, 0.92, 0.92 }, "Do" },   ["goto"] = { ">", { 0.5, 0.8, 1 }, "Go to" },
    note = { "-", { 0.8, 0.8, 0.8 }, "Note" },      level = { "^", { 0.5, 1, 0.5 }, "Reach level" },
    hearth = { "H", { 0.6, 0.85, 1 }, "Hearth" },   fly = { "F", { 0.6, 0.85, 1 }, "Fly" },
    learnflight = { "L", { 0.6, 0.85, 1 }, "Learn the flight point" },
    sail = { "S", { 0.6, 0.85, 1 }, "Sail" },       bind = { "B", { 0.6, 0.85, 1 }, "Set your hearthstone" },
    -- stops on the way (PlannerStops.lua): a few words and a place, nothing else
    train = { "T", { 0.85, 0.7, 1 }, "Learn from your trainer" },     vendor = { "V", { 0.85, 0.7, 1 }, "Visit the vendor" },
    mail = { "M", { 0.85, 0.7, 1 }, "Check your mail" },
    explore = { "E", { 0.5, 1, 0.7 }, "Explore" },  gather = { "G", { 0.5, 1, 0.7 }, "Gather" },
}
-- Stops done when their window closes while they are the step you are on (Planner.lua ticks them).
ns.GUIDE_WINDOW_KINDS = { train = "TRAINER_CLOSED", vendor = "MERCHANT_CLOSED", mail = "MAIL_CLOSED" }
ns.GUIDE_STOP_KINDS = { train = true, vendor = true, mail = true, explore = true, gather = true }   -- (the kinds a planner stop may be)
ns.GUIDE_PLANNED = "\1planned"          -- the planned route's name: one no saved guide can have (guide names come from a line of text)
ns.GUIDE_TRIP = "\1trip"                -- a trip followed for a while (a gold idea's Go): the plan waits, and comes back after it
local QUEST_KIND = { accept = true, turnin = true, ["do"] = true }
ns.builtinGuides = ns.builtinGuides or {}

-- One line of a guide -> a step. Nil for an empty line or a comment; nil, why and what to put in it for a line
-- that is wrong (why: an English sentence, its %s filled with the third value: ns.GuideParseWhy says it in your language).
function ns.GuideParseWhy(why, arg)
    if type(why) ~= "string" then return "" end
    local text = ns:Tr(why)
    if arg ~= nil then local ok, t = pcall(format, text, tostring(arg)); if ok then text = t end end
    return text
end
function ns.GuideParseLine(line)
    line = ns.Trim(line)
    if line == "" or line:sub(1, 1) == "#" then return nil end
    local step = {}
    local body, map, x, y = line:match("^(.-)%s*@%s*(%d+):([%d%.]+)%s*,%s*([%d%.]+)$")
    if not body then body, x, y = line:match("^(.-)%s*@%s*([%d%.]+)%s*,%s*([%d%.]+)$") end
    if body then
        line = ns.Trim(body)
        step.map, step.x, step.y = tonumber(map), tonumber(x), tonumber(y)
        if not step.x or not step.y or step.x > 100 or step.y > 100 then return nil, "The place after @ must be two numbers up to 100." end
    end
    local left, text = line:match("^(.-)%s*|%s*(.*)$")
    left = ns.Trim(left or line)
    if text and ns.Trim(text) ~= "" then step.text = ns.Trim(text) end
    local kind, rest = left:match("^(%S+)%s*(.*)$")
    kind = kind and kind:lower()
    if not kind or not ns.guideKinds[kind] then return nil, "A step starts with accept, turnin, do, goto, note, level, hearth, fly, learnflight, sail, bind, train, vendor, mail, explore or gather." end
    step.kind = kind
    rest = ns.Trim(rest)
    if QUEST_KIND[kind] then
        local id, title = rest:match("^(%d+)%s*(.*)$")
        if not id then return nil, "%s needs the quest's number.", kind end
        step.quest = tonumber(id)
        if title ~= "" then step.title = title end
    elseif kind == "level" then
        step.level = tonumber(rest:match("^(%d+)"))
        if not step.level then return nil, "Level needs a number." end
    elseif kind == "fly" or kind == "learnflight" then
        local node, more = rest:match("^(%d+)%s*(.*)$")
        if node then
            step.node = tonumber(node)
            rest = more
        elseif kind == "learnflight" then
            return nil, "Learnflight needs the flight point's number."
        end
        if rest ~= "" and not step.text then step.text = rest end
    elseif kind == "sail" then
        local crossing, more = rest:match("^(%S+)%s*(.*)$")
        if not crossing then return nil, "Sail needs the crossing's name." end
        step.crossing = crossing
        if more ~= "" and not step.text then step.text = more end
    elseif rest ~= "" and not step.text then
        step.text = rest
    end
    if kind == "goto" and not step.x then return nil, "Goto needs a place: @ x,y." end
    return step
end
-- A whole guide from text. Returns the guide and a list of the lines that were not understood.
function ns.GuideParse(text, name)
    local guide, problems, n = { name = name, steps = {} }, {}, 0
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\r?\n") do
        n = n + 1
        local named = line:match("^%s*[Gg]uide:%s*(.-)%s*$")
        if named and named ~= "" then
            guide.name = named
        else
            local step, why, arg = ns.GuideParseLine(line)
            if step then guide.steps[#guide.steps + 1] = step
            elseif why then problems[#problems + 1] = format(ns:Tr("Line %d: %s"), n, ns.GuideParseWhy(why, arg)) end
        end
    end
    return guide, problems
end
function ns.GuideLine(step)
    local out = step.kind
    if step.quest then out = out .. " " .. step.quest .. (step.title and (" " .. step.title) or "") end
    if step.level then out = out .. " " .. step.level end
    if step.node then out = out .. " " .. step.node end
    if step.crossing then out = out .. " " .. step.crossing end
    if step.text then out = out .. " | " .. step.text end
    if step.x and step.y then
        out = out .. " @ " .. (step.map and (step.map .. ":") or "") .. format("%.1f,%.1f", step.x, step.y)
    end
    return out
end
function ns.GuideText(guide)
    local lines = { "guide: " .. tostring(guide.name or "") }
    for _, step in ipairs(guide.steps or {}) do lines[#lines + 1] = ns.GuideLine(step) end
    return table.concat(lines, "\n")
end
-- Why a planned step is there: what an accept is worth, or the time a trip saves. Only on the planned guide, only if switched on.
local function WhyText(step, guide)
    if not (type(guide) == "table" and guide.name ~= nil and guide.name == ns.GUIDE_PLANNED and ns.db and ns.db.plannerWhy ~= false) then return "" end
    if step.timed then return "  " .. ns:Tr("(timed: go straight on)") end
    local why = type(step.why) == "table" and step.why
    if not why then return "" end
    local xp, saves = tonumber(why.xp), tonumber(why.saves)
    if why.held then return "  " .. ns:Tr("(held for your trainer)") end
    if why.skin then return "  " .. ns:Tr("(skin them)") end
    if xp and xp > 0 then
        local n = xp - xp % 1
        local good, nice = pcall(BreakUpLargeNumbers or tostring, n)
        if not (good and type(nice) == "string") then nice = tostring(n) end
        return "  " .. format(ns:Tr("(+%s xp)"), nice)
    end
    if saves and saves > 0 then return "  " .. format(ns:Tr("(saves ~%d min)"), math.max(1, math.floor(saves / 60 + 0.5))) end
    local detour = tonumber(why.detour)
    if detour and detour > 0 then return "  " .. format(ns:Tr("(+%d s detour)"), math.floor(detour + 0.5)) end
    return ""
end
-- What the panel says for a step. `guide`: the guide it is on, for the planned one's "why".
function ns.GuideStepText(step, guide)
    return ns.GuideStepBase(step) .. WhyText(step, guide)
end
-- Has the game marked this quest failed (a timed or escort quest)?
local function Failed(q)
    local f = type(q) == "number" and C_QuestLog and C_QuestLog.IsFailed
    if type(f) ~= "function" then return false end
    local ok, v = pcall(f, q)
    return ok and ns.Is(v, true)
end
ns.GuideQuestFailed = Failed
function ns.GuideStepBase(step)
    local k = step.kind
    if k == "do" and Failed(step.quest) then
        return (step.text or (step.title or ("#" .. step.quest))) .. "  " .. ns:Tr("(failed: abandon it and take it again)")
    end
    if k == "accept" and Failed(step.quest) then         -- (planned again from its giver, F9: abandon it first)
        return ns:Tr("Accept") .. ": " .. (step.title or ("#" .. step.quest)) .. "  " .. ns:Tr("(failed: abandon it and take it again)")
    end
    if k == "accept" then return ns:Tr("Accept") .. ": " .. (step.title or ("#" .. step.quest)) .. (step.text and ("  (" .. step.text .. ")") or "") end
    if k == "turnin" then return ns:Tr("Turn in") .. ": " .. (step.title or ("#" .. step.quest)) .. (step.text and ("  (" .. step.text .. ")") or "") end
    if k == "do" then return step.text or (step.title or ("#" .. step.quest)) end
    if k == "goto" then return step.text or format("%s %.0f, %.0f", ns:Tr("Go to"), step.x, step.y) end
    if k == "level" then return ns:Tr("Reach level") .. " " .. step.level end
    if k == "hearth" then return step.text or ns:Tr("Use your hearthstone") end
    if k == "fly" then return step.text or ns:Tr("Take the flight") end
    if k == "learnflight" then return step.text or ns:Tr("Learn the flight point") end
    if k == "sail" then return step.text or ns:Tr("Take the boat") end
    if k == "bind" then return step.text or ns:Tr("Set your hearthstone here") end
    if ns.GUIDE_STOP_KINDS[k] then return step.text or ns:Tr(ns.guideKinds[k][3]) end   -- (a stop's words say what it is)
    return step.text or ""
end

-- The dock a sail step's crossing takes you to: the one farther from the step's own place (where you board), or nil.
function ns.GuideFarDock(step)
    if type(step) ~= "table" or not (step.x and step.y) then return nil end
    for _, c in ipairs(ns.PLANNER_CROSSINGS or {}) do
        if c.id == step.crossing and type(c.a) == "table" and type(c.b) == "table" then
            local function Off(d) return (d.map == step.map) and ((d.x - step.x) ^ 2 + (d.y - step.y) ^ 2) or math.huge end
            return Off(c.a) <= Off(c.b) and c.b or c.a
        end
    end
    return nil
end
-- Is this step done? `world` answers the questions about the game; `ticked` = you ticked it off yourself.
function ns.GuideStepDone(step, world, ticked)
    if ticked then return true end
    local k, q = step.kind, step.quest
    if k == "accept" then   -- (a failed quest in your log is not taken yet: abandon it and take it again, F9)
        return (world.onQuest(q) and not (type(world.failed) == "function" and world.failed(q) == true)) or world.completed(q)
    end
    if k == "turnin" then return world.completed(q) end
    if k == "do" then return world.completed(q) or world.ready(q) end
    if k == "goto" then return world.near(step) end
    if k == "level" then return (world.level or 0) >= step.level end
    local function Ask1(fn, arg) return type(fn) == "function" and fn(arg) == true end
    local function Landed(to)                                 -- (where a flight or the hearthstone takes you: within 60 yards)
        return type(to) == "table" and type(world.near) == "function" and world.near(to, 60) == true
    end
    if k == "fly" then
        if step.node and Ask1(world.landedAt, step.node) then return true end
        if Landed(step.to) then return true end
        return not step.node and step.x ~= nil and Ask1(world.near, step)
    end
    if k == "hearth" then return Landed(step.to) or Ask1(world.hearthed, step) end
    if k == "learnflight" then return Ask1(world.knownFlight, step.node) end
    if k == "sail" then return Ask1(world.crossed, step.crossing) or Landed(ns.GuideFarDock(step)) end   -- (or at the far dock: a crossing with no loading screen, after a /reload on board)
    if k == "bind" then return world.bind ~= nil and world.bind == step.text end
    if k == "explore" or k == "gather" then return step.x ~= nil and Ask1(world.near, step) end   -- (passing it is enough)
    return false                                              -- (train, vendor, mail: ticked when the window closes)
end
-- The first step from `from` on that is not done (one past the end when all are).
-- `skipped`: steps you skipped (passed over, never counted as done).
function ns.GuideNext(steps, from, world, ticked, skipped)
    local i = math.max(1, from or 1)
    while steps[i] and ((skipped and skipped[i]) or ns.GuideStepDone(steps[i], world, ticked and ticked[i])) do i = i + 1 end
    return i
end

-- The game, as the guide sees it --------------------------------------------------------------
local function Ask(fn, id)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, id)
    return ok and ns.Is(v, true)
end
local function Here()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if type(map) ~= "number" or Secret(map) then return nil end
    local x, y = nil, nil
    if ns.MapPosition then x, y = ns.MapPosition(map, "player") end
    if not x then return map end
    return map, math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
end
ns.GuideHere = Here
ns.GUIDE_NEAR = 15                                            -- yards: close enough to count as "there"
-- (one table, made once: each look refreshes its level and hearthstone; the questions read C_QuestLog as it is then)
local theWorld
local function Planner(fn, arg)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, arg)
    return ok and v == true
end
local function QL() return C_QuestLog or {} end
function ns:GuideWorld()
    local level = UnitLevel and UnitLevel("player")
    local bind
    if GetBindLocation then
        local ok, v = pcall(GetBindLocation)
        if ok and type(v) == "string" and not Secret(v) and v ~= "" then bind = v end
    end
    if theWorld then
        theWorld.bind, theWorld.level = bind, (type(level) == "number" and not Secret(level)) and level or 0
        return theWorld
    end
    theWorld = {
        bind = bind,
        knownFlight = function(node) return Planner(ns.PlannerKnownFlight, node) end,
        landedAt = function(node) return Planner(ns.PlannerLandedAt, node) end,
        crossed = function(crossing) return Planner(ns.PlannerCrossed, crossing) end,
        onQuest = function(id) return Ask(QL().IsOnQuest, id) end,
        failed = function(id) return Failed(id) end,
        completed = function(id) return Ask(QL().IsQuestFlaggedCompleted, id) end,
        ready = function(id) return Ask(QL().IsComplete, id) or Ask(QL().ReadyForTurnIn, id) end,
        level = (type(level) == "number" and not Secret(level)) and level or 0,
        hearthed = function(step) return ns.GuideHearthed(step, theWorld.bind) end,
        near = function(step, radius)
            if not (step.x and step.y and ns.MapPosition and ns.WayArrow) then return false end
            if ns.Yes(UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return false end   -- (a ghost running to its body passes places, never reaches them)
            local map = step.map or Here()
            if not map then return false end
            local px, py = ns.MapPosition(map, "player")
            if not px then return false end
            local w, h = 1000, 667
            if ns.MapWorldSize then w, h = ns.MapWorldSize(map) end
            local _, distance = ns.WayArrow(px, py, step.x / 100, step.y / 100, w, h, 0)
            return distance < (tonumber(radius) or ns.GUIDE_NEAR)
        end,
    }
    return theWorld
end
-- The hearth step without a place: done once you stand where your hearthstone is set (by the place's name, as the
-- game gives it) after being somewhere else while the step was up. `hearthFrom`: that step, and whether you were away.
local hearthFrom
local function ZoneTexts()
    local out = {}
    for _, f in ipairs({ GetMinimapZoneText, GetSubZoneText, GetZoneText }) do
        if type(f) == "function" then
            local ok, t = pcall(f)
            if ok and type(t) == "string" and not Secret(t) and t ~= "" then out[#out + 1] = t end
        end
    end
    return out
end
function ns.GuideHearthed(step, bind)
    if type(bind) ~= "string" then return false end
    local here = false
    for _, t in ipairs(ZoneTexts()) do if t == bind then here = true end end
    if not (hearthFrom and hearthFrom.step == step) then hearthFrom = { step = step, away = not here } end
    if not here then hearthFrom.away = true; return false end
    return hearthFrom.away == true
end

-- Guides kept with the settings (for every character), and the one this character is following ----
-- (made in the saved settings only when something is written: reading, as every quest event does, makes nothing,
-- so a character that never followed a guide saves nothing of it)
local function Store(create)
    if type(ns.root) ~= "table" then return {}, {} end
    if create then
        if type(ns.root.guides) ~= "table" then ns.root.guides = {} end
        if type(ns.root.guideState) ~= "table" then ns.root.guideState = {} end
    end
    return type(ns.root.guides) == "table" and ns.root.guides or {}, type(ns.root.guideState) == "table" and ns.root.guideState or {}
end
function ns:GuideGet(name)
    local guides, state = Store()
    if name ~= nil and name == ns.GUIDE_PLANNED then                -- the planned route: kept with your place in it
        local st = state[ns:CharKey()]
        local plan = type(st) == "table" and st.name == name and st.plan
        return (type(plan) == "table" and type(plan.steps) == "table") and plan or nil
    end
    return guides[name] or ns.builtinGuides[name]
end
function ns:GuideNames()
    local guides = Store()
    local names, seen = {}, {}
    for _, source in ipairs({ guides, ns.builtinGuides }) do
        for name in pairs(source) do if not seen[name] then seen[name] = true; names[#names + 1] = name end end
    end
    table.sort(names)
    return names
end
function ns:GuideSave(guide)
    if type(guide) ~= "table" or type(guide.name) ~= "string" or ns.Trim(guide.name) == "" then return false, "The guide needs a name (a first line such as \"guide: My route\")." end
    local guides = Store(true)
    guides[guide.name] = { name = guide.name, steps = guide.steps or {} }
    return true
end
function ns:GuideDelete(name)
    local guides, state = Store()
    if not guides[name] then return false end
    guides[name] = nil
    local mine = state[ns:CharKey()]
    if mine and mine.name == name and not ns.builtinGuides[name] then state[ns:CharKey()] = nil end
    return true
end
local function State()
    local _, state = Store()
    return state[ns:CharKey()]
end
ns.GuideState = State

local panel
local Draw
local FailedCheck, NotHere                          -- (the guide's events and its 1 s look, below)

-- Seams (what the planner uses of the guide):
--   GUIDE_PLANNED
--   GUIDE_STOP_KINDS
--   GUIDE_TRIP
--   GUIDE_WINDOW_KINDS
--   GuideAdvance
--   GuideFollow
--   GuideGet
--   GuideHere
--   GuideLine
--   GuideList
--   GuideMenu
--   GuideMovedText
--   GuideOn
--   GuidePanelEntries
--   GuidePanelShown
--   GuideParse
--   GuideParseLine
--   GuidePlanAgain
--   GuidePlanFailed
--   GuideRedraw
--   GuideRegisterAction
--   GuideRegisterAdvance
--   GuideRegisterCommand
--   GuideRegisterLine
--   GuideRegisterLock
--   GuideRegisterTitle
--   GuideReputation
--   GuideSave
--   GuideSaySent
--   GuideSetPlan
--   GuideShowPanel
--   GuideSkip
--   GuideSkipped
--   GuideSkippedText
--   GuideState
--   GuideStepBase
--   GuideStop
--   GuideText
--   GuideUnlocked
-- end of seams
-- (Every ns.Guide* and ns.GUIDE_* a Planner*.lua file uses is listed here and defined in this file: the small API the
-- planner may lean on; tests/test_addon.py::test_guide_seams_listed keeps it true. No file wraps a ns.Guide* function.)
--
-- What other files add to the panel (each list in the order first added; the same key again replaces
-- in place, fn nil removes):
--   ns.GuideRegisterLine(key, fn(st, steps, at) -> text|nil)    a faint line under the advice
--   ns.GuideRegisterTitle(key, fn(st) -> text|nil)              " · text" after the title
--   ns.GuideRegisterAction("step"|"panel", key, label, fn(step), shown(step), anyGuide)   a menu entry (label: English, or fn(step)
--                                                                -> text); anyGuide: a panel entry offered whatever guide you follow,
--                                                                not only the planned route (the "..." then shows for any guide)
--   ns.GuideRegisterAdvance(key, fn(st, guide, step, at, moved, resumed))  the step you are on changed (resumed: the
--                                                                first advance after a login or /reload, the step you were on: not new)
--   ns.GuideRegisterCommand(word, fn(rest))                      /fgui guide <word> ...
--   ns.GuideRegisterLock(key, fn(unlocked))                      after ns:GuideUnlock worked (true), and after ns:GuideLock
--                                                                cleared the key (false), before the switch is applied
-- Each is called through pcall (a command word too); a failure goes to ns.errors as "Guide hook <key>: <error>".
-- Menu labels stay English (or text a label fn made) until ns:GuideMenu, the one place they go through ns:Tr.
local extraLines, titleParts, stepActions, panelActions, advanceHooks, commands, lockHooks = {}, {}, {}, {}, {}, {}, {}
local function Register(list, key, entry)
    if key == nil then return end
    for i, e in ipairs(list) do
        if e.key == key then
            if entry then entry.key = key; list[i] = entry else table.remove(list, i) end
            return
        end
    end
    if entry then entry.key = key; list[#list + 1] = entry end
end
local function Hook(key, fn, ...)
    local ok, v = pcall(fn, ...)
    if ok then return v end
    if type(ns.errors) == "table" and #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Guide hook " .. tostring(key) .. ": " .. tostring(v) end
    return nil
end
local function Fn(fn, entry) return type(fn) == "function" and entry or nil end
function ns.GuideRegisterLine(key, fn) Register(extraLines, key, Fn(fn, { fn = fn })) end
function ns.GuideRegisterTitle(key, fn) Register(titleParts, key, Fn(fn, { fn = fn })) end
function ns.GuideRegisterAction(where, key, label, fn, shown, anyGuide)
    local list = (where == "step" and stepActions) or (where == "panel" and panelActions) or nil
    if list then Register(list, key, Fn(fn, { label = label, fn = fn, shown = shown, any = anyGuide and true or nil })) end
end
function ns.GuideRegisterAdvance(key, fn) Register(advanceHooks, key, Fn(fn, { fn = fn })) end
function ns.GuideRegisterLock(key, fn) Register(lockHooks, key, Fn(fn, { fn = fn })) end
local function LockChanged(unlocked)                       -- (on a copy: a hook may register or remove one)
    local copy = {}
    for i, e in ipairs(lockHooks) do copy[i] = e end
    for _, e in ipairs(copy) do Hook(e.key, e.fn, unlocked) end
end
function ns.GuideRegisterCommand(word, fn)
    if type(word) ~= "string" or word == "" then return end
    commands[word:lower()] = type(fn) == "function" and fn or nil
end
-- Is an action's entry shown for this step (no shown(): always)? Its label.
local function ActionShown(e, step)
    if type(e.shown) ~= "function" then return true end
    return Hook(e.key, e.shown, step) == true
end
local function ActionLabel(e, step)
    if type(e.label) == "function" then
        local t = Hook(e.key, e.label, step)
        return type(t) == "string" and t or tostring(e.key)
    end
    return tostring(e.label)
end
local function StepEntries(step)
    local out = {}
    for _, e in ipairs(stepActions) do
        if ActionShown(e, step) then out[#out + 1] = { ActionLabel(e, step), function() e.fn(step) end } end
    end
    return out
end
-- (anyOnly: following a guide that is not the planned route, only the entries offered for any guide)
local function PanelEntries(step, anyOnly)
    local out = {}
    for _, e in ipairs(panelActions) do
        if (e.any or not anyOnly) and ActionShown(e, step) then out[#out + 1] = { ActionLabel(e, step), function() e.fn(step) end } end
    end
    return out
end
-- Is any entry of `list` shown for this step? (No tables made: the panel asks on every draw.)
local function HasEntries(list, step, anyOnly)
    for _, e in ipairs(list) do if (e.any or not anyOnly) and ActionShown(e, step) then return true end end
    return false
end
-- The entries shown for a step: { { label, fn } } (labels as registered: ns:GuideMenu translates them).
ns.GuideStepEntries = StepEntries          -- the registered step actions only (not the built-in skip entry)
ns.GuidePanelEntries = PanelEntries        -- the registered panel actions shown now (what the "..." button lists)
-- Where the step is, for the arrow: its own place, or where the game says the quest goes next.
local function PlaceOf(step)
    if step.x and step.y then return step.map, step.x, step.y end
    if step.quest and step.kind ~= "accept" and C_QuestLog and C_QuestLog.GetNextWaypoint then
        local ok, map, x, y = pcall(C_QuestLog.GetNextWaypoint, step.quest)
        if ok and type(map) == "number" and type(x) == "number" and type(y) == "number" and not Secret(map) and not Secret(x) and not Secret(y) then return map, x * 100, y * 100 end
    end
end
-- A step on a map you are not on: the arrow points at the next leg of the way there, from the planner's travel
-- (only while the guide is unlocked): the flight master, the dock, or where your way leaves the map you are on.
-- (A planned route's own travel steps, a flight, a boat, the hearthstone, come before such a step and are pointed
-- at as they are; this is the walk between maps a plan leaves out, and a written guide's steps.)
-- Fractions of `map` for a world spot on continent c (off the map: below 0 or above 1), or nil.
local function MapFraction(map, c, wx, wy)
    local c0, ax, ay = ns.PlannerWorldPos(map, 0, 0)
    local c1, bx, by = ns.PlannerWorldPos(map, 100, 0)
    local c2, dx, dy = ns.PlannerWorldPos(map, 0, 100)
    if not (c0 ~= nil and c0 == c and c1 == c and c2 == c) then return nil end
    local e1x, e1y, e2x, e2y, px, py = bx - ax, by - ay, dx - ax, dy - ay, wx - ax, wy - ay
    local det = e1x * e2y - e1y * e2x
    if det == 0 then return nil end
    return (px * e2y - py * e2x) / det, (e1x * py - e1y * px) / det
end
-- Where the straight way from (fx, fy) to (u, v) leaves the map (fractions); the spot itself when it is on it.
local function MapEdge(fx, fy, u, v)
    local t = 1
    for _, a in ipairs({ { fx, u }, { fy, v } }) do
        local from, to = a[1], a[2]
        if to > 1 and to ~= from then t = math.min(t, (1 - from) / (to - from)) end
        if to < 0 and to ~= from then t = math.min(t, (0 - from) / (to - from)) end
    end
    t = math.max(0, t)
    return fx + (u - fx) * t, fy + (v - fy) * t
end
-- map, x, y (percent), the leg's words (nil: the step's own), and whether reaching it switches to another kind of
-- travel (a walk to the flight master, the dock or the place you hearth from); nil when the arrow points at the step.
-- A walk to the map's edge does not switch: it is worked out again once you are on another map. The last value:
-- a spot you pass through, not one to arrive at (the map's edge, or where you stand when you are there already).
local function LegPlace(map, x, y)
    if not (ns:GuideUnlocked() and type(map) == "number" and ns.PlannerTravel and ns.PlannerWorldPos and ns.MapPosition) then return nil end
    if ns.MapPosition(map, "player") then return nil end            -- (on its map, or on one it holds: the arrow points there itself)
    local hereMap, hx, hy = Here()
    if not (hereMap and hx and hereMap ~= map) then return nil end
    local okF, faction = pcall(UnitFactionGroup, "player")
    local ctx = { speed = ns.PLANNER_SPEED and ns.PLANNER_SPEED.run or 7, crossings = ns.PLANNER_CROSSINGS or {},
        flights = ns.PlannerFlightPoints and ns.PlannerFlightPoints() or {}, faction = (okF and type(faction) == "string" and not Secret(faction)) and faction or nil }
    local ok, _, legs = pcall(ns.PlannerTravel, { map = hereMap, x = hx, y = hy }, { map = map, x = x, y = y }, ctx)
    local leg, after = ok and type(legs) == "table" and legs[1], ok and type(legs) == "table" and legs[2]
    if type(leg) ~= "table" or type(leg.to) ~= "table" then return nil end   -- (no way there known: the arrow says "another map")
    local to, label, there = leg.to, nil, false
    if leg.kind ~= "run" then to, after, there = { map = hereMap, x = hx, y = hy }, leg, true end   -- (at the flight master or the dock already)
    if leg.kind == "run" and type(after) == "table" and after.kind ~= "run" then  -- (a few yards from it: there already)
        local c1, ax, ay = ns.PlannerWorldPos(hereMap, hx, hy)
        local c2, bx, by = ns.PlannerWorldPos(to.map, to.x, to.y)
        if c1 ~= nil and c1 == c2 and ((bx - ax) ^ 2 + (by - ay) ^ 2) ^ 0.5 < ns.GUIDE_NEAR then
            to, leg, there = { map = hereMap, x = hx, y = hy }, after, true
        end
    end
    local kind = type(after) == "table" and after.kind or nil
    if kind == "fly" then label = ns:Tr("Take the flight")
    elseif kind == "sail" then label = (ns.PlannerSailText and ns.PlannerSailText(after)) or ns:Tr("Take the boat")
    elseif kind == "hearth" then label = ns:Tr("Use your hearthstone") end
    local switches = leg.kind == "run" and (kind == "fly" or kind == "sail" or kind == "hearth")
    if ns.MapPosition(to.map, "player") then return to.map, to.x, to.y, label, switches, there end   -- (there already: no arrival)
    local c, wx, wy = ns.PlannerWorldPos(to.map, to.x, to.y)
    local u, v
    if c then u, v = MapFraction(hereMap, c, wx, wy) end
    if not u then return nil end
    local inside = u >= 0 and u <= 1 and v >= 0 and v <= 1
    u, v = MapEdge(hx / 100, hy / 100, u, v)
    return hereMap, u * 100, v * 100, label, switches and inside, not inside
end
-- TomTom (the optional waypoint add-on, when it is loaded and its switch is on): the guide's waypoint goes there, and
-- our own arrow stays hidden (TomTom shows its own: crazy = true).
local tomUid
local function TomTomAddon()
    if not (ns:GuideUnlocked() and ns.db and ns.db.plannerTomTom ~= false) then return nil end
    if type(TomTom) == "table" and type(TomTom.AddWaypoint) == "function" then return TomTom end
end
local function TomTomClear()
    if tomUid == nil then return end
    if type(TomTom) == "table" and type(TomTom.RemoveWaypoint) == "function" then pcall(TomTom.RemoveWaypoint, TomTom, tomUid) end
    tomUid = nil
end
local pointed, legMap, legSpot, pointedTomTom      -- (legSpot: a leg that switches to another kind of travel when reached)
local legReached                                    -- (the last leg spot reached, and the map you were on: never pointed at again there)
local legCache                                      -- (the leg worked out for one step on one map: { step, index, here, result })
local pointPending                                  -- (a leg not worked out in a fight: the 1 s look points once the fight is over)
-- LegPlace, kept per step and map (worked out again after a leg is reached); in a fight, false when not yet known.
local function LegFor(step, index, map, x, y)
    local here = Here()
    local c = legCache
    if c and c.step == step and c.index == index and c.here == here then return unpack(c.result, 1, 6) end
    if (ns.MapPosition and ns.MapPosition(map, "player")) or here == map then return nil end   -- (on its map: the arrow points there itself)
    if InCombatLockdown() then return false end              -- (no travel worked out in a fight: the arrow keeps what it shows)
    local result = { LegPlace(map, x, y) }
    legCache = { step = step, index = index, here = here, result = result }
    return unpack(result, 1, 6)
end
local function Point(step, index)
    if not step then
        if pointed and ns.waypoint and ns.waypoint.quiet then ns:ClearWaypoint(true) end
        TomTomClear()
        pointed, legMap, legSpot, legReached, legCache, pointPending = nil, nil, nil, nil, nil, nil
        return
    end
    local tt = TomTomAddon()                                  -- (pointed again: a new step, a leg on another map, TomTom on or off)
    if pointed == index and not (legMap and Here() ~= legMap) and (tt ~= nil) == pointedTomTom then return end
    local map, x, y = PlaceOf(step)
    local lm, lx, ly, words, switches, atEdge
    if x then
        lm, lx, ly, words, switches, atEdge = LegFor(step, index, map, x, y)
        if lm == false then pointPending = true; return end
    end
    pointPending = nil
    if legReached and legReached.here ~= Here() then legReached = nil end   -- (on another map: a spot may be pointed at again)
    pointed, legMap, legSpot, pointedTomTom = index, nil, nil, tt ~= nil
    local label = ns.GuideStepText(step)
    local edge = false
    if lm then
        map, x, y, label, legMap, edge = lm, lx, ly, words or label, Here(), atEdge == true
        local seen = legReached and legReached.map == lm and math.abs(legReached.x - lx) < 0.05 and math.abs(legReached.y - ly) < 0.05
        if switches and not seen then legSpot = { map = lm, x = lx, y = ly } end
    end
    TomTomClear()
    if tt and x then
        local ok, uid = pcall(tt.AddWaypoint, tt, map or Here(), x / 100, y / 100, { title = label, persistent = false, crazy = true, from = "Fantasy Glass UI" })
        if ok and uid ~= nil then
            tomUid = uid
            if ns.waypoint and ns.waypoint.quiet then ns:ClearWaypoint(true) end
            return
        end
    end
    if x and ns.SetWaypoint then
        ns:SetWaypoint(x, y, label, map, true)
        if edge and ns.waypoint then ns.waypoint.passing = true end      -- (a spot on the way, not one to arrive at: no pulse)
    elseif ns.waypoint and ns.waypoint.quiet then ns:ClearWaypoint(true) end
end
-- A leg that switches to another kind of travel (the flight master, the dock, the hearth) was reached: the next one.
-- (Whether our own arrow or TomTom points. A walk to the map's edge waits for the map to change.)
local function LegReached()
    local spot = legSpot
    if not (spot and pointed and ns.MapPosition) then return false end
    local px, py = ns.MapPosition(spot.map, "player")
    if not px then return false end
    local width, height = 1000, 667
    if ns.MapWorldSize then width, height = ns.MapWorldSize(spot.map) end
    local _, distance = ns.WayArrow(px, py, spot.x / 100, spot.y / 100, width, height, 0)
    if distance >= ns.GUIDE_NEAR then return false end
    legReached = { map = spot.map, x = spot.x, y = spot.y, here = Here() }
    legMap, legSpot, legCache = -1, nil, nil                  -- (not a map: the next Point works the leg out again)
    return true
end

local StepKey
local seenKey, freshPlan = nil, false               -- (the last step the advance hooks saw; a new plan's first advance)
-- A planned route that ran out (its last step was not a hand-in, or one handed in far away): plan what is next, at
-- most once a minute (a plan that is all done already does not plan again and again).
local endReplanAt
local function EndReplan()
    local now = GetTime and GetTime() or 0
    if endReplanAt and now >= endReplanAt and now - endReplanAt < 60 then return end
    endReplanAt = now
    ns:GuidePlanAgain("end")
end
-- Move on to the first step that is not done. Returns the step and its number (nil at the end).
-- `quiet` (the 1 s look): the panel is drawn again only when the step changed, something marked it dirty
-- (ns.GuideMarkDirty), or its last drawing is 10 s old (lines that count time down); every other call draws it.
local drawDirty, drawnAt, drawnAtStep, drawnGuide = true, nil, nil, nil
function ns.GuideMarkDirty() drawDirty = true end
function ns:GuideAdvance(quiet)
    local st = State()
    if not st or not ns:GuideOn() then return nil end
    local guide = ns:GuideGet(st.name)
    if not guide then return nil end
    st.ticked = type(st.ticked) == "table" and st.ticked or {}
    local skipped = type(st.skipped) == "table" and st.skipped or nil
    local before = st.at or 1
    st.at = ns.GuideNext(guide.steps, before, ns:GuideWorld(), st.ticked, skipped)
    local done = false                                        -- (passed a step that was done, not only skipped ones)
    for i = before, st.at - 1 do
        if not (skipped and skipped[i]) then done = true end
    end
    if st.name == ns.GUIDE_PLANNED and ns.PlannerExploreReached then      -- (an explore spot reached: not asked again)
        for i = before, st.at - 1 do
            local s = guide.steps[i]
            if type(s) == "table" and s.kind == "explore" and not st.ticked[i] and not (skipped and skipped[i]) then ns.PlannerExploreReached(s) end
        end
    end
    local step = guide.steps[st.at]
    if st.at ~= before and PlaySound and SOUNDKIT and ns.db.guideSound ~= false then pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_SELECT or 875) end
    local planned = st.name == ns.GUIDE_PLANNED
    if not step and not st.finished then
        st.finished = true
        if not planned then ns:Print("Guide finished: %s", tostring(guide.name))
        elseif #guide.steps > 0 and not (type(st.summary) == "table" and st.summary.empty) then EndReplan() end   -- (the plan ran out: the next one)
    end
    if planned and step then                                  -- (past the hearthstone: plan from where it took you)
        for i = before, st.at - 1 do
            local s = guide.steps[i]
            if type(s) == "table" and s.kind == "hearth" and not (skipped and skipped[i]) and not st.ticked[i] then ns:GuidePlanAgain("hearth"); break end
        end
    end
    Point(step, st.at)
    if Draw then
        local now = GetTime and GetTime() or 0
        if not quiet or drawDirty or st.at ~= before or drawnAtStep ~= st.at or drawnGuide ~= guide
            or not drawnAt or now < drawnAt or now - drawnAt >= 10 then
            drawDirty, drawnAt, drawnAtStep, drawnGuide = false, now, st.at, guide
            Draw()
        end
    end
    local key = step and StepKey(step) or "\1end"           -- (the step you are on changed: the advance hooks; nil step at the end)
    if key ~= seenKey then
        local resumed = seenKey == nil and not freshPlan and st.at == before   -- (the first look after a load: the step you left off on)
        seenKey = key
        local moved = st.at ~= before and not freshPlan and done   -- (a skipped step is not a step done)
        for _, e in ipairs(advanceHooks) do Hook(e.key, e.fn, st, guide, step, st.at, moved, resumed) end
    end
    freshPlan = false
    return step, st.at
end
function ns:GuideFollow(name)
    if name ~= nil and name == ns.GUIDE_PLANNED then return ns.PlannerStart ~= nil and ns:PlannerStart() end
    local guide = ns:GuideGet(name)
    if not guide then ns:Print("There is no guide called \"%s\". /fgui guide lists them.", tostring(name)); return false end
    local _, state = Store(true)
    local old = state[ns:CharKey()]
    local kept = type(old) == "table" and type(old.written) == "table" and old.written[name]   -- (where you were in it before a plan took over)
    state[ns:CharKey()] = (old and old.name == name) and old
        or { name = name, at = (type(kept) == "table" and tonumber(kept.at)) or 1, ticked = (type(kept) == "table" and type(kept.ticked) == "table") and kept.ticked or {} }
    state[ns:CharKey()].finished = nil
    if ns.PlannerStop then ns:PlannerStop() end
    pointed, freshPlan = nil, true
    ns:GuideShowPanel()
    ns:GuideAdvance()
    ns:Print(#guide.steps == 1 and "Following \"%s\": %d step." or "Following \"%s\": %d steps.", name, #guide.steps)
    return true
end
-- A step as the same thing to do, wherever it sits in a plan.
StepKey = function(step)
    -- (a planner stop is known by its stopKey: its words, such as what to buy, may change between plans)
    return table.concat({ tostring(step.kind), tostring(step.quest), tostring(step.node), tostring(step.crossing), step.stopKey and "" or tostring(step.text), tostring(step.stopKey) }, "\1")
end
-- Follow a new plan (Planner.lua), from its first step; nil = an empty one until the first is ready.
-- Steps you ticked off yourself in the old plan stay ticked where the new plan has them too (a
-- planner stop by its stopKey, so the next visit to the same trainer is a new step).
function ns:GuideSetPlan(guide, summary)
    local _, state = Store(true)
    local old = state[ns:CharKey()]
    local plan = guide or { name = ns.GUIDE_PLANNED, steps = {} }
    local ticked, had = {}, {}
    if type(old) == "table" and old.name == ns.GUIDE_PLANNED and type(old.plan) == "table" and type(old.plan.steps) == "table" and type(old.ticked) == "table" then
        for i, on in pairs(old.ticked) do
            local step = on and old.plan.steps[i]
            if type(step) == "table" then local k = StepKey(step); had[k] = (had[k] or 0) + 1 end
        end
    end
    for i, step in ipairs(plan.steps) do
        local k = StepKey(step)
        -- (a quest step is never carried: the game says whether you have it, finished it or handed it in, and a
        -- tick left from a quest you could not take would hold its steps for good)
        if (had[k] or 0) > 0 and not QUEST_KIND[step.kind] then had[k] = had[k] - 1; ticked[i] = true end
    end
    local written = type(old) == "table" and type(old.written) == "table" and old.written or nil
    if type(old) == "table" and old.name ~= nil and old.name ~= ns.GUIDE_PLANNED and ns:GuideGet(old.name) then   -- (a written guide: its place kept)
        written = { [old.name] = { at = old.at, ticked = old.ticked } }
    end
    state[ns:CharKey()] = { name = ns.GUIDE_PLANNED, at = 1, ticked = ticked, summary = summary, plan = plan, written = written }
    pointed, freshPlan = nil, true
    ns:GuideShowPanel()
    ns:GuideAdvance()
end
-- Planning failed: keep the plan you have, and say so on the panel.
function ns:GuidePlanFailed()
    local st = State()
    if not (type(st) == "table" and st.name == ns.GUIDE_PLANNED) then return end
    st.planFailed = true
    if Draw then Draw() end
end
function ns:GuideStop()
    if ns.PlannerStop then ns:PlannerStop() end
    local _, state = Store()
    state[ns:CharKey()] = nil
    Point(nil)
    seenKey = nil
    if panel then panel:Hide() end
end
-- Tick the step you are on off yourself (a note, or one the game cannot check), or step back one.
function ns:GuideSkip(back)
    local st = State()
    if not st then return end
    st.ticked = type(st.ticked) == "table" and st.ticked or {}
    if back then
        st.at = math.max(1, (st.at or 1) - 1)
        st.ticked[st.at] = nil
        if type(st.skipped) == "table" then st.skipped[st.at] = nil end
        st.finished = nil
        pointed = nil
        local guide = ns:GuideGet(st.name)
        local step = guide and guide.steps[st.at]
        Point(step, st.at)
        seenKey = step and StepKey(step) or seenKey        -- (no advance hook for Back; the next step is new to them again)
        if Draw then Draw() end
    else
        st.ticked[st.at or 1] = true
        ns:GuideAdvance()
    end
end

-- Skip the step you are on: passed over, never counted as done (not ticked). On the planned route a skipped quest
-- step leaves that quest out of this session's plans (never the permanent "never suggest"), and the route is planned
-- again from here; a skipped step of another kind is simply passed over.
function ns:GuideSkipStep()
    local st = State()
    if not st then return end
    local guide = ns:GuideGet(st.name)
    local at = st.at or 1
    local step = guide and guide.steps[at]
    if not step then return end
    st.skipped = type(st.skipped) == "table" and st.skipped or {}
    st.skipped[at] = true
    ns:GuideAdvance()
    if st.name == ns.GUIDE_PLANNED and type(step.quest) == "number" then
        if ns.PlannerDuoRole and ns.PlannerDuoRole() == "friend" then     -- (planning together: the leader plans, so only passed over here)
            ns:Print("Skipped here; %s plans the route.", tostring(ns.PlannerDuoPartner and ns.PlannerDuoPartner() or "?"))
            return
        end
        if ns.PlannerSessionSkip then pcall(ns.PlannerSessionSkip, step.quest) end
        ns:GuidePlanAgain("skip")
    end
end

-- The panel -------------------------------------------------------------------------------------
local function LevelText(v)
    v = tonumber(v)
    if not v then return "?" end
    return (v == math.floor(v)) and format("%d", v) or format("%.1f", v)
end
local function ZoneName(map)
    if not (map and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, map)
    local name = ok and type(info) == "table" and info.name
    if type(name) == "string" and not Secret(name) and name ~= "" then return name end
end
local function Planned(st) return st.name ~= nil and st.name == ns.GUIDE_PLANNED end
local TitleBase
local function Title(st, guide)
    local text = TitleBase(st, guide)
    if Planned(st) and (ns.plannerQueued or ns.plannerBusy) then text = text .. " · " .. ns:Tr("planning...") end   -- (Plan again was heard)
    for _, e in ipairs(titleParts) do
        local t = Hook(e.key, e.fn, st)
        if type(t) == "string" and t ~= "" then text = text .. " · " .. t end
    end
    return text
end
TitleBase = function(st, guide)
    if not Planned(st) then return guide.name end
    local s = type(st.summary) == "table" and st.summary
    local zone = s and ZoneName(s.zone)
    if not zone then return ns:Tr("Quest guide") end
    return format(ns:Tr("Planned: %s, level %s → %s"), zone, LevelText(s.fromLevel), LevelText(s.toLevel))
end
-- What the panel says when the guide has no step left: a plan still being made, or nothing worth doing.
local function EndText(st)
    if not Planned(st) then return ns:Tr("This guide is finished.") end
    local s = type(st.summary) == "table" and st.summary
    if not s then return ns:Tr("Planning your route...") end
    if s.empty and s.source == "log" then return ns:Tr("Install Questie to plan new quests; your quest log has none to plan") end   -- (not the world's fault)
    if s.empty then return ns:Tr("No quests left worth the trip; grinding or a dungeon may be faster") end
    if ns.plannerQueued or ns.plannerBusy then return ns:Tr("Planning what's next...") end   -- (only while a plan is really being made)
    return ns:Tr("End of the route. Press Plan again for what's next.")   -- (held back, refused, or the new plan is done already)
end
-- (from a plan's summary: the planner's preview shows the same line)
function ns.GuideSkippedText(s)
    local n = type(s) == "table" and type(s.skipped) == "table" and tonumber(s.skipped.group) or 0
    if n <= 0 then return nil end
    local group = ns.db and ns.db.plannerGroup
    local solo = group == nil or group == "solo"
    if n == 1 then return format(ns:Tr(solo and "Skipped: %d group quest (Solo is on)" or "Skipped: %d group quest"), n) end
    return format(ns:Tr(solo and "Skipped: %d group quests (Solo is on)" or "Skipped: %d group quests"), n)
end
local function SkippedText(st)
    return Planned(st) and ns.GuideSkippedText(st.summary) or nil
end
-- The talent and riding lines read the game's talents, spells and money: kept until one of those changes (or the
-- panel is shown afresh), not read again on every quest event.
local cached = {}
local function Cached(key, fn)
    local c = cached[key]
    if c == nil then c = fn() or false; cached[key] = c end
    return c or nil
end
function ns.GuideForget() cached = {} end
-- "2 talent points to spend", when the game says there are some.
local function TalentText()
    local n = ns.PlannerUnspentTalents and ns.PlannerUnspentTalents()
    if type(n) ~= "number" or n <= 0 then return nil end
    return format(ns:TrN(n, "%d talent point to spend", "%d talent points to spend"), n)
end
-- "Riding: 40g to go", at level 40 or more while you can't yet afford the trainer (and your mount).
local function RidingText()
    local level = UnitLevel and UnitLevel("player")
    local r = ns.PlannerRiding and type(level) == "number" and not ns:IsSecret(level) and ns.PlannerRiding(level)
    if not r or r.short <= 0 or not ns.PlannerGoldText then return nil end
    return format(ns:Tr("Riding: %s to go"), ns.PlannerGoldText(r.short))
end
-- "Stormwind: 2,300 to Honored": a faction you want that a quest in the plan gives reputation with.
local function RepText(st)
    local sum = Planned(st) and type(st.summary) == "table" and st.summary.reputation
    local goals = ns.PlannerRepGoals and ns.PlannerRepGoals()
    if type(sum) ~= "table" or type(goals) ~= "table" or not ns.PlannerRepNeeded then return nil end
    local best, bestValue                           -- (the wanted faction the plan gives most with)
    for id, value in pairs(sum) do
        value = tonumber(value)
        if type(id) == "number" and goals[id] and value and (not bestValue or value > bestValue or (value == bestValue and id < best)) then
            local need = ns.PlannerRepNeeded(id, goals[id])
            local name = ns.PlannerRepName and ns.PlannerRepName(id)
            local standing = ns.PlannerRepStandingName and ns.PlannerRepStandingName(goals[id])
            if need and name and standing then best, bestValue = id, value end
        end
    end
    if not best then return nil end
    local need = ns.PlannerRepNeeded(best, goals[best])
    local good, nice = pcall(BreakUpLargeNumbers or tostring, math.floor(need))
    if not (good and type(nice) == "string") then nice = tostring(math.floor(need)) end
    return format(ns:Tr("%s: %s reputation to %s"), ns.PlannerRepName(best), nice, ns.PlannerRepStandingName(goals[best]))
end
-- "Moved: you died twice here; only the quests you have are kept (back at level 14)": a hub left out of this plan
-- because you died twice there (its quests already in your log still are planned).
function ns.GuideMovedText(s)
    local lv = type(s) == "table" and tonumber(s.moved)
    if not lv then return nil end
    return format(ns:Tr("Moved: you died twice here; only the quests you have are kept (back at level %d)"), lv)
end
local function MovedText(st)
    return Planned(st) and ns.GuideMovedText(st.summary) or nil
end
-- "Class quest ready: Name (3 parts, about 20 min)": one you could start that the plan does not take.
local function ClassText(st)
    local s = Planned(st) and ns.db and ns.db.plannerClassQuests ~= false and type(st.summary) == "table" and st.summary
    local r = s and type(s.classReady) == "table" and s.classReady
    if not (r and type(r.name) == "string") then return nil end
    local text = format(ns:Tr("Class quest ready: %s"), r.name)
    if tonumber(r.parts) and r.parts > 1 and tonumber(r.minutes) then
        text = text .. " " .. format(ns:Tr("(%d parts, about %d min)"), r.parts, r.minutes)
    end
    return text
end
local function QuestName(id)
    local f = C_QuestLog and C_QuestLog.GetTitleForQuestID
    if type(f) == "function" then
        local ok, t = pcall(f, id)
        if ok and type(t) == "string" and not Secret(t) and t ~= "" then return t end
    end
    return "#" .. tostring(id)
end
-- The quests you told the planner never to suggest, each to click to allow again.
function ns:GuideSkipped()
    local lines, ids = {}, {}
    for id in pairs(ns.PlannerSkipList and ns.PlannerSkipList() or {}) do if type(id) == "number" then ids[#ids + 1] = id end end
    table.sort(ids)
    local list = ns.PlannerSkipList and ns.PlannerSkipList() or {}
    for _, id in ipairs(ids) do
        local kept = list[id]                                 -- (the name kept with the skip, for a quest no longer in your log)
        local name = QuestName(id)
        if name:sub(1, 1) == "#" and type(kept) == "string" and kept ~= "" then name = kept end
        lines[#lines + 1] = { left = name, right = ns:Tr("Suggest again"),
            click = function()
                if ns.PlannerSkip then ns.PlannerSkip(id, false) end
                ns:GuideSkipped()
            end }
    end
    return ns:ShowList("Skipped", "Quests you skipped", lines, "Click a quest to suggest it again.", 400, 340)
end
-- The guide's small menu (one frame, FantasyGlassUIGuideMenu): entries = { { label, fn } }, a 192x20 button
-- each (labels are English phrases or text already in your language). A click runs fn after the menu closes;
-- Escape or a click anywhere else closes it. Nil (and nothing shown) for no entries.
local stepMenu
local function MenuOver()
    if not stepMenu then return false end
    if stepMenu:IsMouseOver() then return true end
    for _, b in ipairs(stepMenu.buttons) do if b:IsShown() and b:IsMouseOver() then return true end end
    return false
end
function ns:GuideMenu(entries)
    if type(entries) ~= "table" or #entries == 0 then
        if stepMenu then stepMenu:Hide() end
        return nil
    end
    if not stepMenu then
        stepMenu = CreateFrame("Frame", "FantasyGlassUIGuideMenu", UIParent, ns.template)
        stepMenu:SetSize(200, 26)
        stepMenu:SetFrameStrata("DIALOG")
        if stepMenu.SetClampedToScreen then stepMenu:SetClampedToScreen(true) end      -- (opened near an edge: still all on the screen)
        stepMenu:SetBackdrop(ns.BACKDROP)
        ns:Paint(stepMenu, "SetBackdropColor", "window", 0.95)
        ns:Paint(stepMenu, "SetBackdropBorderColor", "@border", 1)
        stepMenu.buttons = {}
        stepMenu:SetScript("OnLeave", function(self) if not MenuOver() then self:Hide() end end)
        stepMenu:Hide()
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUIGuideMenu") end   -- (Escape closes it)
        ns.guideStepMenu = stepMenu
        local away = CreateFrame("Frame")                    -- (a click anywhere else closes it: heard only while it is open)
        away:SetScript("OnEvent", ns:Guard("Guide menu", function()
            if stepMenu:IsShown() and not MenuOver() then stepMenu:Hide() end
        end))
        stepMenu:SetScript("OnShow", function() pcall(away.RegisterEvent, away, "GLOBAL_MOUSE_DOWN") end)
        stepMenu:SetScript("OnHide", function() pcall(away.UnregisterEvent, away, "GLOBAL_MOUSE_DOWN") end)
        stepMenu.away = away
    end
    -- as wide as its longest label (at least 200), each button at least 24 high (larger with "Bigger controls")
    local bh = math.floor(24 * ((ns.db and ns.db.bigControls) and 1.3 or 1) + 0.5)
    local width = 200
    for i, e in ipairs(entries) do
        local b = stepMenu.buttons[i]
        if not b then
            b = ns:CreateButton(stepMenu, "", 192, 24, function(self)
                local fn = self.entryFn
                stepMenu:Hide()
                if type(fn) == "function" then fn() end
            end)
            b:HookScript("OnLeave", ns:Guard("Guide menu", function() if not MenuOver() then stepMenu:Hide() end end))
            stepMenu.buttons[i] = b
        end
        b.entryFn, b.entryLabel = e[2], ns:Tr(tostring(e[1]))
        b.text:SetText(b.entryLabel)
        width = math.max(width, ns.GuideFitButton(b, 192) + 8)
        b:Show()
    end
    for i, e in ipairs(entries) do
        local b = stepMenu.buttons[i]
        b:SetSize(width - 8, bh)
        if b.text.suiFit then b.text.suiFit() end
        b:ClearAllPoints()
        b:SetPoint("TOP", stepMenu, "TOP", 0, -3 - (i - 1) * (bh + 2))
    end
    for i = #entries + 1, #stepMenu.buttons do stepMenu.buttons[i]:Hide() end
    stepMenu.button = stepMenu.buttons[1]
    stepMenu:SetSize(width, 6 + #entries * bh + (#entries - 1) * 2)
    stepMenu:ClearAllPoints()
    local ok, cx, cy = pcall(GetCursorPosition)
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if ok and type(cx) == "number" and type(cy) == "number" and not Secret(cx) and not Secret(cy) and scale > 0 then
        stepMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale - 10, cy / scale + 10)
    else
        stepMenu:SetPoint("CENTER", UIParent, "CENTER")
    end
    stepMenu:Show()
    return stepMenu
end
-- The menu on a step (right click): on a quest step, never suggest the quest (or allow it again), then the
-- registered step actions shown for it. Nil when there is nothing to offer.
function ns:GuideStepMenu(step)
    if type(step) ~= "table" then return nil end
    local entries, quest, skipped = {}, nil, false
    if type(step.quest) == "number" then
        quest = step.quest
        skipped = (ns.PlannerSkipList and ns.PlannerSkipList()[quest]) and true or false
        entries[1] = { skipped and "Suggest again" or "Never suggest this quest", function()
            if ns.PlannerSkip then ns.PlannerSkip(quest, not skipped, step.title) end
        end }
        local st = State()
        local guide = st and Planned(st) and ns:GuideGet(st.name)
        if guide and guide.steps[st.at or 1] == step then           -- (the step you are on: this session's plans leave it out)
            entries[#entries + 1] = { "Skip this quest for now", function() ns:GuideSkipStep() end }
        end
    end
    for _, e in ipairs(StepEntries(step)) do entries[#entries + 1] = e end
    local menu = ns:GuideMenu(entries)
    if menu and quest then menu.quest, menu.skipped = quest, skipped end
    return menu
end
-- Redraw the panel, if it is there.
function ns:GuideRedraw()
    if panel and Draw then Draw() end
end
-- The factions you want reputation with: a list to click, each cycling Honored, Revered, Exalted, off.
function ns:GuideReputation()
    local lines = {}
    local goals = ns.PlannerRepGoals and ns.PlannerRepGoals() or {}
    for _, f in ipairs(ns.PlannerKnownFactions and ns.PlannerKnownFactions() or {}) do
        local now = goals[f.id]
        local at = 0
        for i, s in ipairs(ns.PLANNER_REP_STANDINGS or {}) do if s == now then at = i end end
        local nextStanding = (ns.PLANNER_REP_STANDINGS or {})[at + 1]
        lines[#lines + 1] = { left = f.name, right = now and ns.PlannerRepStandingName(now) or (ns:ToneHex("dim") .. ns:Tr("off") .. "|r"),
            tone = now and "@accent" or nil,
            click = function()
                if ns.PlannerSetRepGoal then ns.PlannerSetRepGoal(f.id, nextStanding) end
                ns:GuideReputation()
            end }
    end
    return ns:ShowList("Reputation", "Reputation I want", lines, "Click a faction to cycle: Honored, Revered, Exalted, off. Quests that give it count for more.", 400, 340)
end
-- The panel's measures. Its width grows a little with the lettering (up to 1.25 times); every line sits under the
-- one before by its measured height, so nothing overlaps at any font scale; the panel grows downward only (its top
-- stays put); the footer's buttons are at least 24 x 22, larger with "Bigger controls".
local PANEL_W, FOOTER_H = 280, 22
local LINE_KEYS = { "skipped", "talent", "riding", "rep", "moved", "classq", "advice", "extra" }
local UNKNOWN_KIND = { "-", { 0.8, 0.8, 0.8 }, "Note" }     -- (a step kind this version does not know: a saved guide from a newer one)
local function KindOf(step) return ns.guideKinds[step.kind] or UNKNOWN_KIND end
local function FontScale() return math.max(0.7, math.min(1.5, tonumber(ns.fontScale) or 1)) end
local function PanelWidth() return math.floor(PANEL_W * math.min(1.25, math.max(1, FontScale())) + 0.5) end
local function Big() return (ns.db and ns.db.bigControls) and 1.3 or 1 end
-- A text's height on screen in whole pixels (what `size` points take on one line when the game can't say).
local function TextHeight(fs, size)
    local ok, h = pcall(fs.GetStringHeight, fs)
    h = (ok and not Secret(h)) and tonumber(h) or nil
    if not h or h <= 0 then h = (size or 10) * FontScale() end
    return math.ceil(h)
end
-- A button as wide as its whole label needs, at least `least`; returns that width.
local function FitButton(b, least)
    local w = least
    if b.text then
        pcall(b.text.SetWidth, b.text, 0)
        ns:Font(b.text, 12)                                  -- (the label at its full size, to measure it)
        local ok, sw = pcall(b.text.GetStringWidth, b.text)
        sw = (ok and not Secret(sw)) and tonumber(sw) or nil
        if sw then w = math.max(least, math.ceil(sw) + 14) end
    end
    b:SetWidth(w)
    b.suiW = w
    if b.text and b.text.suiFit then b.text.suiFit() end
    return w
end
ns.GuideFitButton = FitButton
-- The accent as text on the panel: lightened toward white (or darkened, on a pale panel) until it reads at 4.5:1
-- against the panel's fill, so a dark accent (Midnight, Scarlet) still reads as a title.
local function Lum(r, g, b)
    local function c(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
    return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b)
end
function ns.GuideAccentText()
    local ar, ag, ab = ns:Role("@accent")
    local ok, wr, wg, wb = pcall(ns.Role, ns, "window")
    if not (type(ar) == "number" and ok and type(wr) == "number" and type(wg) == "number" and type(wb) == "number") then return ar, ag, ab end
    local bg = Lum(wr, wg, wb)
    local to = bg > 0.4 and 0 or 1                           -- (toward black on a pale panel, toward white on a dark one)
    local r, g, b = ar, ag, ab
    for _ = 1, 10 do
        local l = Lum(r, g, b)
        if (math.max(l, bg) + 0.05) / (math.min(l, bg) + 0.05) >= 4.5 then break end
        r, g, b = r + (to - r) * 0.15, g + (to - g) * 0.15, b + (to - b) * 0.15
    end
    return r, g, b
end
-- Badge colours read on dark panels; on a pale one (a light theme of your own) they are darkened, so they still read.
local function BadgeColor(c)
    local ok, r, g, b = pcall(ns.Role, ns, "window")
    if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" and 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.55 then
        return c[1] * 0.55, c[2] * 0.55, c[3] * 0.55
    end
    return c[1], c[2], c[3]
end
-- The footer: "<" ">" "Plan again" on the left, "..." "Guides" on the right; Plan again is left out when the two
-- sides would meet (a long word in another language): the key binding and the preview still have it.
local function Footer()
    local W, big = panel.drawnWidth or PanelWidth(), Big()
    local bh, sq = math.floor(FOOTER_H * big + 0.5), math.floor(24 * big + 0.5)
    for _, b in ipairs({ panel.back, panel.skip, panel.more }) do b:SetSize(sq, bh); b.suiW = sq end
    panel.again:SetHeight(bh)
    panel.list:SetHeight(bh)
    local pw = math.floor(44 * big + 0.5)
    panel.planner:SetSize(pw, bh)
    panel.planner:ClearAllPoints()                          -- (left of "...", or of Guides when there is no menu)
    panel.planner:SetPoint("RIGHT", panel.moreShown and panel.more or panel.list, "LEFT", -4, 0)
    local right = 8 + (panel.listW or 64) + (panel.moreShown and (4 + sq) or 0) + (panel.plannerShown and (4 + pw) or 0)
    local room = W - (8 + sq + 4 + sq + 4) - 6 - right       -- (what is left for Plan again between the two sides)
    local want = panel.againW or 72
    panel.againFits = room >= math.min(want, 56)
    local target = math.max(0, math.min(want, room))        -- (a long word in another language: drawn smaller, or cut with its tooltip)
    if panel.againFits and target ~= panel.againSetW then
        panel.againSetW = target
        panel.again:SetWidth(target)
        if panel.again.text and panel.again.text.suiFit then panel.again.text.suiFit() end
    end
    panel.hover:ClearAllPoints()
    panel.hover:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel.hover:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, bh + 10)
    return bh
end
-- Every line in its place, top to bottom, and the panel as tall as they need.
local function Layout()
    local W, s, big = PanelWidth(), FontScale(), Big()
    if W ~= panel.drawnWidth then panel.drawnWidth = W; panel:SetWidth(W) end
    local inner = W - 22
    panel.title:SetWidth(W - 64)
    local y = -8 - TextHeight(panel.title, 12) - 3
    panel.bar:ClearAllPoints()
    panel.bar:SetPoint("TOPLEFT", 10, y)
    panel.bar:SetPoint("TOPRIGHT", -10, y)
    y = y - 3 - 6
    local bw = math.ceil(20 * s)
    panel.badge:SetWidth(bw)
    panel.badge:ClearAllPoints()
    panel.badge:SetPoint("TOPLEFT", 10, y)
    local nx = 10 + bw + 6
    panel.now:ClearAllPoints()
    panel.now:SetPoint("TOPLEFT", nx, y)
    panel.now:SetWidth(W - nx - 10)
    local nh = math.max(TextHeight(panel.now, 12), math.ceil(20 * s))
    panel.stepButton:ClearAllPoints()
    panel.stepButton:SetPoint("TOPLEFT", nx, y)
    panel.stepButton:SetSize(W - nx - 10, nh)
    y = y - nh - 4
    for i = 1, 2 do
        local fs = panel.later[i]
        fs:SetWidth(inner)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 12, y)
        if panel.laterShown[i] then y = y - TextHeight(fs, 10) - 1 end
    end
    y = y - 4
    local tb = panel.talentButton
    local th = math.floor(20 * big + 0.5)
    for _, key in ipairs(LINE_KEYS) do
        local fs = panel[key]
        if panel.lineShown[key] then
            fs:SetWidth(key == "talent" and (inner - (tb.suiW or 56) - 6) or inner)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", 12, y)
            local h = TextHeight(fs, 10)
            if key == "talent" then
                tb:SetHeight(th)
                tb:ClearAllPoints()
                tb:SetPoint("RIGHT", panel, "TOPRIGHT", -8, y - h / 2)          -- (beside its line, at its middle)
                h = math.max(h, th)
            end
            y = y - h - 3
        end
    end
    local bh = Footer()
    local h = math.ceil(-y + 6 + bh + 6)
    if h ~= panel.drawnHeight then panel.drawnHeight = h; panel:SetHeight(h) end   -- (only when it changes: a resize redraws the frame)
end
-- The whole of what the panel says, in a tooltip: a line cut short on the panel is read here.
local function PanelTip(owner, menuHint)
    if not (panel and GameTooltip and type(panel.tipLines) == "table") then return end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    for i, t in ipairs(panel.tipLines) do
        if i == 1 then GameTooltip:AddLine(ns:AccentHex() .. t .. "|r") else GameTooltip:AddLine(t, 1, 1, 1, true) end
    end
    if menuHint then GameTooltip:AddLine(ns:Tr("Right-click: more for this step"), 0.75, 0.75, 0.75, true) end
    GameTooltip:Show()
end
Draw = function()
    if not panel then return end
    local st = State()
    local guide = st and ns:GuideGet(st.name)
    if not guide then panel:Hide(); return end
    local at, steps = st.at or 1, guide.steps
    local planned = Planned(st)
    panel.title:SetText(Title(st, guide))
    panel.title:SetTextColor(ns.GuideAccentText())
    local texts = {}
    texts.skipped = (planned and st.planFailed) and ns:Tr("Could not plan the route; trying again after your next quest") or SkippedText(st)
    texts.talent = planned and Cached("talent", TalentText) or nil          -- (talent points waiting; the planned guide only)
    texts.riding = (planned and ns.db and ns.db.plannerMount ~= false) and Cached("riding", RidingText) or nil
    texts.rep = planned and RepText(st) or nil
    texts.moved = planned and MovedText(st) or nil
    texts.classq = ClassText(st)
    local advice = (planned and ns.PlannerAdviceLines) and ns.PlannerAdviceLines(steps, at, st.summary) or {}
    texts.advice = #advice > 0 and table.concat(advice, "\n") or nil
    local extra = {}                                -- (lines other files add: GuideRegisterLine)
    for _, e in ipairs(extraLines) do
        local t = Hook(e.key, e.fn, st, steps, at)
        if type(t) == "string" and t ~= "" then extra[#extra + 1] = t end
    end
    if planned and st.notHere then table.insert(extra, 1, ns:Tr("Not here? Right-click: skip this quest for now")) end
    texts.extra = #extra > 0 and table.concat(extra, "\n") or nil
    if panel.advice.SetMaxLines then panel.advice:SetMaxLines(math.max(2, #advice * 2)) end   -- (each advice line may take two)
    if panel.extra.SetMaxLines then panel.extra:SetMaxLines(math.max(2, #extra * 2)) end
    panel.lineShown = {}
    for _, key in ipairs(LINE_KEYS) do
        panel[key]:SetText(texts[key] or "")
        panel[key]:SetShown(texts[key] ~= nil)
        panel.lineShown[key] = texts[key] ~= nil
    end
    panel.talentButton:SetShown(texts.talent ~= nil)
    panel.count:SetText(math.min(at, #steps) .. "/" .. #steps)
    local step = steps[at]
    if panel.stepButton then                        -- (it takes the mouse only while a planned step with a menu is shown)
        panel.stepButton:SetShown(planned and type(step) == "table" and (type(step.quest) == "number" or HasEntries(stepActions, step)))
    end
    panel.moreShown = HasEntries(panelActions, step, not planned)   -- (the panel's menu: some entry is there; another guide: those for any guide)
    panel.more:SetShown(panel.moreShown)
    panel.plannerShown = ns:GuideUnlocked() == true                 -- (the route planner's own window)
    panel.planner:SetShown(panel.plannerShown)
    if panel.ridingButton then panel.ridingButton:SetShown(texts.riding ~= nil) end   -- (the riding line: a click saves for it)
    local nowText
    if step then
        local kind = KindOf(step)
        panel.badge:SetText(kind[1])
        panel.badge:SetTextColor(BadgeColor(kind[2]))
        nowText = ns.GuideStepText(step, guide)
    else
        panel.badge:SetText("")
        nowText = EndText(st)
    end
    panel.now:SetText(nowText)
    local tip = { tostring(Title(st, guide)), nowText }
    panel.laterShown = {}
    for i = 1, 2 do
        local nextStep = steps[at + i]
        local text = nextStep and (KindOf(nextStep)[1] .. "  " .. ns.GuideStepText(nextStep, guide)) or ""
        if nextStep and type(st.skipped) == "table" and st.skipped[at + i] then text = ns:ToneHex("faint") .. text .. "  (" .. ns:Tr("skipped") .. ")|r" end   -- (fainter, and said)
        panel.later[i]:SetText(text)
        panel.laterShown[i] = text ~= ""
        if text ~= "" then tip[#tip + 1] = text end
    end
    for _, key in ipairs(LINE_KEYS) do if texts[key] then tip[#tip + 1] = texts[key] end end
    panel.tipLines = tip
    panel.bar:SetMinMaxValues(0, math.max(1, #steps))
    panel.bar:SetValue(math.min(at - 1, #steps))
    panel.bar:SetShown(not planned)                 -- (a plan starts again at 1 with each replan: its bar would never move on)
    -- (placed again only when something that moves a line changed: the width, the lettering, a text, a line shown)
    local sig = { PanelWidth(), FontScale(), Big(), tostring(panel.moreShown), tostring(panel.plannerShown), tostring(panel.againW), tostring(panel.listW), tostring(panel.againSetW) }
    for _, t in ipairs(tip) do sig[#sig + 1] = t end
    for _, key in ipairs(LINE_KEYS) do sig[#sig + 1] = texts[key] and key or "-" end
    sig = table.concat(sig, "\1")
    if sig ~= panel.layoutSig or panel.drawnWidth == nil or panel.drawnHeight == nil then   -- (a size forgotten: placed again)
        Footer()
        panel.layoutSig = sig
        Layout()
    end
    panel.again:SetShown(planned and ns.PlannerReplan ~= nil and panel.againFits ~= false)   -- (Plan again: only while following the plan)
end
-- (the lettering or the theme changed: the buttons measured again, the fill's strength, every line placed again)
local function Restyle()
    if not panel then return end
    ns:Paint(panel, "SetBackdropColor", "window", ns:IsHighContrast() and 1 or 0.95)   -- (high contrast: no world showing through)
    panel.againW = FitButton(panel.again, 72)
    panel.listW = FitButton(panel.list, 64)
    FitButton(panel.talentButton, 56)
    panel.drawnHeight, panel.drawnWidth, panel.againSetW, panel.layoutSig = nil, nil, nil, nil
    if panel:IsShown() then Draw() end
end
ns:OnTheme(function() pcall(Restyle) end)
-- A saved place from before the panel grew downward (its middle, or the screen's right edge), made a top-left one
-- where its top edge is now; so is the place a drag in move mode leaves (the middle), so lines added below never
-- move its top.
local function PinTop()
    local pos = ns.db and type(ns.db.pos) == "table" and ns.db.pos.questGuide
    if type(pos) ~= "table" or pos[1] == "TOPLEFT" then return end
    local okL, l = pcall(panel.GetLeft, panel)
    local okT, t = pcall(panel.GetTop, panel)
    if not (okL and okT and type(l) == "number" and type(t) == "number") or Secret(l) or Secret(t) then return end
    l, t = math.floor(l + 0.5), math.floor(t + 0.5)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    ns.db.pos.questGuide = { "TOPLEFT", "BOTTOMLEFT", l, t }
end
local function Line(size)
    local fs = ns:NewText(panel, size or 10, "LEFT")
    fs:SetPoint("TOPLEFT", 12, -92)
    fs:SetWidth(258)
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    if fs.SetMaxLines then fs:SetMaxLines(2) end
    ns:Paint(fs, "SetTextColor", "dim")
    fs:Hide()
    return fs
end
function ns:GuideShowPanel()
    if not ns:GuideOn() then return nil end
    if not panel then
        panel = CreateFrame("Frame", "FantasyGlassUIGuide", UIParent, ns.template)
        panel:SetSize(PanelWidth(), 118)
        panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -290, -300)   -- (left of the quest tracker, growing down)
        panel:SetBackdrop(ns.BACKDROP)
        ns:Paint(panel, "SetBackdropColor", "window", ns:IsHighContrast() and 1 or 0.95)
        ns:Paint(panel, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(panel)
        panel.hover = CreateFrame("Frame", nil, panel)               -- (the whole of every line in a tooltip; clicks go through)
        if panel.hover.SetMouseMotionEnabled and panel.hover.SetMouseClickEnabled then
            pcall(panel.hover.SetMouseMotionEnabled, panel.hover, true)
            pcall(panel.hover.SetMouseClickEnabled, panel.hover, false)
            panel.hover:SetScript("OnEnter", function(self) PanelTip(self) end)
            panel.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        panel.title = ns:NewText(panel, 12, "LEFT", true)
        panel.title:SetPoint("TOPLEFT", 10, -8)
        panel.title:SetWidth(216)
        if panel.title.SetWordWrap then panel.title:SetWordWrap(false) end
        panel.count = ns:NewText(panel, 10, "RIGHT")
        panel.count:SetPoint("TOPRIGHT", -10, -9)
        ns:Paint(panel.count, "SetTextColor", "faint")
        panel.bar = ns:NewStatusBar(panel, false)
        panel.bar:SetHeight(3)
        panel.bar:SetPoint("TOPLEFT", 10, -25)
        panel.bar:SetPoint("TOPRIGHT", -10, -25)
        ns:Paint(panel.bar, "SetStatusBarColor", "@accent")
        panel.badge = ns:NewText(panel, 20, "CENTER", true)
        panel.badge:SetPoint("TOPLEFT", 10, -34)
        panel.badge:SetWidth(20)
        panel.now = ns:NewText(panel, 12, "LEFT")
        panel.now:SetPoint("TOPLEFT", 36, -34)
        panel.now:SetWidth(234)
        if panel.now.SetWordWrap then panel.now:SetWordWrap(true) end
        if panel.now.SetMaxLines then panel.now:SetMaxLines(2) end
        panel.later = {}
        for i = 1, 2 do
            local fs = ns:NewText(panel, 10, "LEFT")
            fs:SetPoint("TOPLEFT", 12, -66 - (i - 1) * 13)
            fs:SetWidth(258)
            if fs.SetWordWrap then fs:SetWordWrap(false) end
            ns:Paint(fs, "SetTextColor", "dim")
            panel.later[i] = fs
        end
        panel.laterShown, panel.lineShown = {}, {}
        panel.skipped = Line()              -- (a planned route: quests left out by the group setting)
        panel.talent = Line()               -- (a planned route: talent points waiting)
        panel.talentButton = ns:CreateButton(panel, "Talents", 56, 20, function()
            if ns.TalentCommand then ns:TalentCommand("") end         -- (your talent builds, as /fgui talents)
        end)
        panel.talentButton:SetPoint("TOPRIGHT", -8, -90)
        panel.talentButton:Hide()
        panel.riding = Line()               -- (a planned route: gold still to find for riding)
        panel.rep = Line()                  -- (a planned route: a wanted faction's reputation a quest gives)
        panel.moved = Line()                -- (a planned route: a hub left out because you died twice there)
        panel.classq = Line()               -- (a planned route: a class quest you could start now)
        panel.advice = Line()               -- (a planned route: quests worth abandoning, an inn to log out at)
        panel.extra = Line()                -- (lines other files add: GuideRegisterLine)
        panel.stepButton = CreateFrame("Button", nil, panel)         -- (right click on a quest step: its menu)
        panel.stepButton:SetPoint("TOPLEFT", 36, -34)
        panel.stepButton:SetSize(234, 30)
        panel.stepButton:SetFrameLevel((tonumber(panel:GetFrameLevel()) or 1) + 3)
        panel.stepButton:RegisterForClicks("RightButtonUp")
        panel.stepButton:SetScript("OnClick", function(_, button)
            if button ~= "RightButton" then return end
            local st = State()
            local guide = st and Planned(st) and ns:GuideGet(st.name)
            local step = guide and guide.steps[st.at or 1]
            if type(step) == "table" then ns:GuideStepMenu(step) end
        end)
        panel.stepButton:SetScript("OnEnter", function(self) PanelTip(self, true) end)
        panel.stepButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        local back = ns:CreateButton(panel, "<", 24, FOOTER_H, function() ns:GuideSkip(true) end)
        back:SetPoint("BOTTOMLEFT", 8, 6)
        local skip = ns:CreateButton(panel, ">", 24, FOOTER_H, function() ns:GuideNextButton() end)
        skip:SetPoint("LEFT", back, "RIGHT", 4, 0)
        panel.back, panel.skip = back, skip
        panel.again = ns:CreateButton(panel, "Plan again", 72, FOOTER_H, function() ns:GuidePlanAgain() end)
        panel.again:SetPoint("LEFT", skip, "RIGHT", 4, 0)
        panel.again:Hide()
        local list = ns:CreateButton(panel, "Guides", 64, FOOTER_H, function() ns:GuideList() end)
        list:SetPoint("BOTTOMRIGHT", -8, 6)
        panel.list = list
        panel.more = ns:CreateButton(panel, "...", 24, FOOTER_H, function()   -- (the panel's menu: GuideRegisterAction("panel", ...))
            local st = State()
            local planned = st and Planned(st)
            local guide = planned and ns:GuideGet(st.name)
            ns:GuideMenu(PanelEntries(guide and guide.steps[st.at or 1] or nil, not planned))   -- (another guide: the entries for any guide)
        end)
        panel.more:SetPoint("RIGHT", list, "LEFT", -4, 0)
        panel.more:Hide()
        panel.planner = ns:CreateButton(panel, "Planner", 44, FOOTER_H, function() ns:PlannerOpen() end)   -- (the planner's own window: only while unlocked)
        panel.planner:SetPoint("RIGHT", panel.more, "LEFT", -4, 0)
        panel.planner:Hide()
        panel.ridingButton = CreateFrame("Button", nil, panel)    -- (over the riding line: ways to make gold, saving for riding)
        panel.ridingButton:SetAllPoints(panel.riding)
        panel.ridingButton:SetFrameLevel((tonumber(panel:GetFrameLevel()) or 1) + 3)
        panel.ridingButton:SetScript("OnClick", function() ns:GoldOpen({ goalName = "mount" }) end)
        panel.ridingButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:Tr("Save for riding: ways to make gold"), 1, 1, 1)
            GameTooltip:Show()
        end)
        panel.ridingButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        panel.ridingButton:Hide()
        panel.againW = FitButton(panel.again, 72)
        panel.listW = FitButton(list, 64)
        FitButton(panel.talentButton, 56)
        local function NextTip() return ns.GuideNextSkips() and "Skip this step" or "Tick this step off and move on" end
        for _, def in ipairs({ { back, "Back one step" }, { skip, NextTip }, { list, "Your guides: follow another, record, write or paste one" }, { panel.planner, "Your route planner: the plan and its settings" }, { panel.talentButton, "Open your talent builds" }, { panel.again, "Plan the route again from where you are now" } }) do
            def[1]:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(ns:Tr(type(def[2]) == "function" and def[2]() or def[2]), 1, 1, 1)
                GameTooltip:Show()
            end)
            def[1]:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        local watch = CreateFrame("Frame")                         -- (money, talents and skills: the talent and riding lines again)
        for _, e in ipairs({ "PLAYER_MONEY", "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED", "SKILL_LINES_CHANGED" }) do pcall(watch.RegisterEvent, watch, e) end
        watch:SetScript("OnEvent", ns:Guard("Guide panel", function()
            cached = {}
            if panel:IsShown() and not InCombatLockdown() then Draw() end
        end))
        local entry = ns:RegisterMovable(panel, "questGuide", "Quest guide")
        if type(entry) == "table" then
            entry.offPage = true
            entry.onMoved = function() pcall(PinTop) end
        end
        pcall(PinTop)
    end
    panel.drawnHeight, panel.layoutSig = nil, nil                       -- (shown afresh: its height is set once more; a redraw sets it only when it changes)
    cached = {}
    panel:Show()
    Draw()
    return panel
end
function ns:GuidePanelShown() return (panel and ns.Yes(panel:IsShown())) or false end
-- What the panel says, as one text to read aloud (the read key, /fgui read guide): the title, the step, the next
-- steps and every line shown. Nil while the guide is off or the panel hidden.
function ns.GuideReadText()
    if not (ns:GuideOn() and ns:GuidePanelShown() and type(panel.tipLines) == "table" and #panel.tipLines > 0) then return nil end
    local parts = {}
    for _, t in ipairs(panel.tipLines) do parts[#parts + 1] = (tostring(t):gsub("\n", ". ")) end
    return table.concat(parts, ". ")
end
function ns.GuidePanelUnderMouse()
    return ns:GuidePanelShown() and panel.IsMouseOver ~= nil and ns.Yes(panel:IsMouseOver()) or false
end
-- Plan the route again from where you are (the panel's button, the key binding): no preview, your pace mark
-- kept. A "replan" hook may refuse it (a duo friend's sends its state, so the leader plans again).
local toldFriend
function ns:GuidePlanAgain(reason)
    local st = State()
    if not (st and Planned(st) and ns:GuideOn() and ns.PlannerReplan) then return false end
    local ok = Hook("again", ns.PlannerReplan, ns, reason or "again") == true
    if not ok and (reason == nil or reason == "again") then ns.GuideSaySent() end
    if Draw then Draw() end                                  -- (the title says it is planning)
    return ok
end
-- Planning together, as the friend: what you asked for went to your partner, who plans (said at most once a minute).
function ns.GuideSaySent()
    if not (ns.PlannerDuoRole and ns.PlannerDuoRole() == "friend") then return false end
    local now = GetTime and GetTime() or 0
    if toldFriend and now - toldFriend < 60 then return false end
    toldFriend = now
    ns:Print("Sent to %s, who plans the route.", tostring(ns.PlannerDuoPartner and ns.PlannerDuoPartner() or "?"))
    return true
end
-- The panel's ">": on a planned quest step, skip it for this session (a tick would hold that quest's steps); on any
-- other step, tick it off.
function ns.GuideNextSkips()
    local st = State()
    if not (st and Planned(st)) then return false end
    local guide = ns:GuideGet(st.name)
    local step = guide and guide.steps[st.at or 1]
    return type(step) == "table" and type(step.quest) == "number"
end
function ns:GuideNextButton()
    if ns.GuideNextSkips() then return ns:GuideSkipStep() end
    return ns:GuideSkip(false)
end

-- Key bindings (Bindings.xml): next step (tick it off), skip step (ns:GuideSkipStep: passed over, not done), plan
-- again (as the panel's button). Each does nothing while the guide is locked or off, and nothing in combat. Their
-- tokens in Bindings.xml are neutral (FANTASYGLASSUI_EXTRA1 to 3), and so are their names in the key bindings window
-- while the guide is locked ("Fantasy Glass UI: extra 1"); they are named "Guide: ..." only once it is unlocked.
local EXTRA_KEYS = { { "NEXT", "Guide: next step" }, { "SKIP", "Guide: skip step" }, { "AGAIN", "Guide: plan again" } }
function ns.GuideBindingNames(unlocked)
    for i, e in ipairs(EXTRA_KEYS) do
        _G["BINDING_NAME_FANTASYGLASSUI_EXTRA" .. i] = unlocked and ns:Tr(e[2]) or format(ns:Tr("Fantasy Glass UI: extra %d"), i)
    end
end
ns.GuideBindingNames(false)
do
    local names = CreateFrame("Frame")                         -- (the translations and the unlock are known at login)
    names:RegisterEvent("PLAYER_LOGIN")
    names:SetScript("OnEvent", ns:Guard("Guide keys", function() ns.GuideBindingNames(ns:GuideUnlocked()) end))
end
ns.GuideRegisterLock("keys", function(unlocked) ns.GuideBindingNames(unlocked) end)
FantasyGlassUI_ExtraBinding = ns:Guard("Guide keys", function(which)
    if not (ns.db and ns:GuideOn()) or InCombatLockdown() then return end
    local st = State()
    if not st then return end
    which = EXTRA_KEYS[tonumber(which) or 0] and EXTRA_KEYS[tonumber(which)][1] or which
    if which == "NEXT" then ns:GuideSkip(false)
    elseif which == "SKIP" then ns:GuideSkipStep()
    elseif which == "AGAIN" then ns:GuidePlanAgain("again") end
end)

-- Recording: play as usual and every quest you take, finish and hand in becomes a step -----------
local rec
local function QuestTitle(id)
    local f = C_QuestLog and C_QuestLog.GetTitleForQuestID
    if type(f) == "function" then local ok, t = pcall(f, id); if ok and type(t) == "string" and not Secret(t) and t ~= "" then return t end end
    return nil
end
local function Speaker()
    for _, unit in ipairs({ "npc", "questnpc", "target" }) do
        if ns.Yes(UnitExists(unit)) then
            local name = UnitName(unit)
            if type(name) == "string" and not Secret(name) and name ~= "" then return name end
        end
    end
end
local function Objectives(id)
    local f = C_QuestLog and C_QuestLog.GetQuestObjectives
    if type(f) ~= "function" then return nil end
    local ok, list = pcall(f, id)
    if not (ok and type(list) == "table") then return nil end
    local parts = {}
    for _, o in ipairs(list) do
        if type(o) == "table" and type(o.text) == "string" and not Secret(o.text) and o.text ~= "" then parts[#parts + 1] = o.text end
    end
    return (#parts > 0) and table.concat(parts, ", ") or nil
end
-- Add a step to a recording, unless the same one was just added.
ns.GUIDE_RECORD_MAX = 500                                  -- (a recording left on for weeks stops growing here, and says so once)
function ns.GuideRecordStep(recording, step)
    for i = #recording.steps, math.max(1, #recording.steps - 40), -1 do
        local s = recording.steps[i]
        if s.kind == step.kind and s.quest == step.quest and (step.quest or s.text == step.text) then return false end
    end
    if #recording.steps >= ns.GUIDE_RECORD_MAX then
        if not recording.full then
            recording.full = true
            ns:Print("Recording \"%s\" is full (%d steps): start another to go on.", tostring(recording.name), ns.GUIDE_RECORD_MAX)
        end
        return false
    end
    recording.steps[#recording.steps + 1] = step
    return true
end
function ns:GuideRecordEvent(kind, id)
    if not rec or type(id) ~= "number" then return false end
    local map, x, y = Here()
    local step = { kind = kind, quest = id, title = QuestTitle(id), map = map, x = x, y = y }
    if kind == "do" then step.text = Objectives(id) else step.text = Speaker() end
    if kind == "accept" then rec.open[id] = true elseif kind ~= "accept" then rec.open[id] = (kind == "do") and "done" or nil end
    local added = ns.GuideRecordStep(rec, step)
    if added then ns:GuideSave(rec) end
    return added
end
function ns:GuideRecord(name)
    name = ns.Trim(name)
    if name == "" then ns:Print("Give the guide a name: /fgui guide record My route."); return false end
    local old = ns:GuideGet(name)
    rec = { name = name, steps = (old and not ns.builtinGuides[name]) and old.steps or {}, open = {} }
    ns.guideRecording = rec
    ns:GuideSave(rec)
    ns:Print("Recording \"%s\". Play as usual: every quest you accept, finish and hand in becomes a step. /fgui guide stop ends it.", name)
    return rec
end
function ns:GuideRecordStop()
    if not rec then return false end
    local done = rec
    rec, ns.guideRecording = nil, nil
    ns:GuideSave(done)
    ns:Print(#done.steps == 1 and "Recording stopped: \"%s\" has %d step. /fgui guide edit %s shows it." or "Recording stopped: \"%s\" has %d steps. /fgui guide edit %s shows them.", done.name, #done.steps, done.name)
    return done
end

-- The step you are on is a quest the game now marks failed: plan again once (the panel says to abandon and retake it).
local failedSeen = {}
FailedCheck = function(st)
    local guide = ns:GuideGet(st.name)
    local step = guide and guide.steps[st.at or 1]
    local q = type(step) == "table" and step.quest
    if type(q) ~= "number" or not Failed(q) then return end
    if ns.PlannerNoteFailed then ns.PlannerNoteFailed(q) end     -- (abandoning it now is to take it again, not a skip: every time it is seen)
    if failedSeen[q] then return end
    failedSeen[q] = true
    ns:GuidePlanAgain("failed")
end
-- The quest left your log or was taken again: a later failure plans again too.
function ns.GuideFailedForget(q) if type(q) == "number" then failedSeen[q] = nil end end
-- Standing at an accept step's place for a minute without the quest: its giver may not be there (old quest data).
local notHereAt
NotHere = function(st, step)
    if not (Planned(st) and type(step) == "table" and step.kind == "accept" and step.x and ns:GuideWorld().near(step)) then
        if notHereAt then notHereAt = nil; if st.notHere then st.notHere = nil; if Draw then Draw() end end end
        return
    end
    local now = GetTime and GetTime() or 0
    if not (notHereAt and notHereAt.step == step) then notHereAt = { step = step, at = now }; return end
    if now - notHereAt.at >= 60 and not st.notHere then st.notHere = true; if Draw then Draw() end end
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do pcall(ev.RegisterEvent, ev, e) end
    -- every event in a burst (QUEST_LOG_UPDATE comes several times a kill) asks for one advance, 0.3 s on
    local advancePending = false
    local function AdvanceSoon()
        if advancePending then return end
        advancePending = true
        ns:After(0.3, function() advancePending = false; pcall(ns.GuideAdvance, ns) end)      -- (once the game has caught up)
    end
    local function Id(v) return (type(v) == "number" and not Secret(v)) and v or nil end
    ev:SetScript("OnEvent", ns:Guard("Guide events", function(_, event, a, b)
        if not ns:GuideOn() then return end
        if event == "QUEST_ACCEPTED" then ns.GuideFailedForget(Id(b) or Id(a))
        elseif event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN" then ns.GuideFailedForget(Id(a)) end
        if event ~= "QUEST_LOG_UPDATE" and event ~= "ZONE_CHANGED_NEW_AREA" then cached = {} end   -- (a level, a quest: the talent and riding lines again)
        if rec then
            if event == "QUEST_ACCEPTED" then ns:GuideRecordEvent("accept", Id(b) or Id(a))
            elseif event == "QUEST_TURNED_IN" then ns:GuideRecordEvent("turnin", Id(a))
            elseif event == "QUEST_LOG_UPDATE" then
                local Q = C_QuestLog or {}
                for id, state in pairs(rec.open) do
                    if state == true and (Ask(Q.IsComplete, id) or Ask(Q.ReadyForTurnIn, id)) then ns:GuideRecordEvent("do", id) end
                end
            end
        end
        local st = State()
        if st then
            if event == "PLAYER_ENTERING_WORLD" then ns:GuideShowPanel() end
            AdvanceSoon()
            if event == "QUEST_LOG_UPDATE" and Planned(st) then FailedCheck(st) end
        end
    end))
    -- a place is reached without any event: look once a second while following
    local wait = 0
    local function Tick(_, elapsed)
        wait = wait + (elapsed or 0)
        if wait < 1 then return end
        wait = 0
        if not ns:GuideOn() then return end
        local st = State and State()
        if not st or st.finished then return end
        local guide = ns:GuideGet(st.name)
        local step = guide and guide.steps[st.at or 1]
        local reached = LegReached()                          -- (a leg reached: the arrow's next one, on any kind of step)
        if pointPending and not InCombatLockdown() then reached = true end   -- (a leg left for after the fight)
        if step and (reached or step.kind == "goto" or step.kind == "level" or step.kind == "explore" or step.kind == "gather" or step.kind == "hearth" or step.kind == "fly") then pcall(ns.GuideAdvance, ns, true) end
        NotHere(st, step)
    end
    ev:SetScript("OnUpdate", ns:Guard("Guide tick", Tick))    -- (a bad saved step says so once, never once a second)
    ns.guideTickTest = Tick
end

-- The list of guides, and the page where one is written, pasted or copied ------------------------
local editor
function ns:GuideEdit(name)
    if not editor then
        local w = CreateFrame("Frame", "FantasyGlassUIGuideEditor", UIParent, ns.template)
        w:SetSize(560, 420)
        w:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        w:SetFrameStrata("DIALOG")
        w:SetBackdrop(ns.BACKDROP)
        ns:Paint(w, "SetBackdropColor", "window", 0.97)
        ns:Paint(w, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(w)
        w:EnableMouse(true); w:SetMovable(true); if w.SetClampedToScreen then w:SetClampedToScreen(true) end; w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(self) self:StartMoving() end)
        w:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUIGuideEditor") end
        w.title = ns:NewText(w, 14, "LEFT", true)
        w.title:SetPoint("TOPLEFT", 14, -12)
        ns:Paint(w.title, "SetTextColor", "@accent")
        w.title:SetText(ns:Tr("Quest guide"))
        local close = ns:CreateButton(w, "X", 22, 20, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        ns:KeepPlace(w, "GuideEditor")                         -- (where you drag it, it stays)
        w.note = ns:NewText(w, 11, "LEFT")
        w.note:SetPoint("TOPLEFT", 14, -34)
        w.note:SetWidth(530)
        if w.note.SetWordWrap then w.note:SetWordWrap(true) end
        if w.note.SetMaxLines then w.note:SetMaxLines(3) end
        ns:Paint(w.note, "SetTextColor", "dim")
        w.note:SetText(ns:Tr("One step to a line: accept, do or turnin, the quest's number and name; goto, note, level. \"| text\" adds a few words, \"@ map:x,y\" a place. Ctrl+A and Ctrl+C copy a guide; Ctrl+V pastes one."))
        local scroll = CreateFrame("ScrollFrame", "FantasyGlassUIGuideEditorScroll", w, "UIPanelScrollFrameTemplate")
        w.scroll = scroll
        function w:Place()                                     -- (the box starts under the help, however many lines it takes)
            local okH, nh = pcall(self.note.GetStringHeight, self.note)
            nh = (okH and not Secret(nh)) and tonumber(nh) or nil
            if not nh or nh <= 0 then nh = 11 * (tonumber(ns.fontScale) or 1) * 2 end
            self.scroll:ClearAllPoints()
            self.scroll:SetPoint("TOPLEFT", 14, -(34 + math.ceil(nh) + 8))
            self.scroll:SetPoint("BOTTOMRIGHT", -32, 44)
        end
        w:Place()
        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetWidth(506)
        if box.SetFontObject and _G.ChatFontNormal then box:SetFontObject(_G.ChatFontNormal) end
        box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        scroll:SetScrollChild(box)
        w.box = box
        w.status = ns:NewText(w, 11, "LEFT")
        w.status:SetPoint("BOTTOMLEFT", 14, 16)
        function w:Read()
            local guide, problems = ns.GuideParse(self.box:GetText(), self.name)
            return guide, problems
        end
        local function Save(follow)
            local guide, problems = w:Read()
            local ok, why = ns:GuideSave(guide)
            if not ok then w.status:SetText(ns:SignalHex("bad") .. ns:Tr(why) .. "|r"); return false end
            w.name = guide.name
            local more = #problems - 1
            w.status:SetText((#problems > 0) and (ns:SignalHex("warn") .. problems[1] .. ((more > 0) and (" " .. format(ns:TrN(more, "(and %d more line)", "(and %d more lines)"), more)) or "") .. "|r")
                or format(ns:TrN(#guide.steps, "Saved: %d step.", "Saved: %d steps."), #guide.steps))
            if follow then ns:GuideFollow(guide.name) end
            return true
        end
        w.Save = Save
        local follow = ns:CreateButton(w, "Save and follow", 150, 24, function() Save(true) end)
        follow:SetPoint("BOTTOMRIGHT", -14, 12)
        local save = ns:CreateButton(w, "Save", 80, 24, function() Save(false) end)
        save:SetPoint("RIGHT", follow, "LEFT", -6, 0)
        local delete = ns:CreateButton(w, "Delete", 80, 24, function()
            if w.name and ns:GuideDelete(w.name) then w.status:SetText(ns:Tr("Deleted.")); w.box:SetText(""); w.name = nil end
        end)
        delete:SetPoint("RIGHT", save, "LEFT", -6, 0)
        for _, b in ipairs({ follow, save, delete }) do ns.GuideFitButton(b, b.suiW or 80) end   -- (as wide as their labels)
        w.status:SetPoint("RIGHT", delete, "LEFT", -8, 0)      -- (the message stops before Delete)
        editor = w
    end
    local guide = name and ns:GuideGet(name)
    editor.name = guide and guide.name or nil
    editor.box:SetText(guide and ns.GuideText(guide) or ("guide: " .. ((name and name ~= "") and name or ns:Tr("My route")) .. "\n"))
    editor.status:SetText("")
    editor:Place()
    editor:Show()
    return editor
end
function ns:GuideList()
    local st = State()
    local lines = {}
    if ns:GuideUnlocked() and ns.PlannerStart then                -- (the planned route first: following it starts a plan)
        local mine = st and Planned(st)
        lines[1] = { left = ns:Tr("Plan my route") .. (mine and ("  " .. ns:SignalHex("good") .. ns:Tr("following") .. "|r") or ""), tone = mine and "@accent" or nil,
            click = function()
                if mine then if ns.HideLists then ns:HideLists() end; return end   -- (following it already: just close the list)
                ns:GuideFollow(ns.GUIDE_PLANNED); ns:GuideList()
            end }
    end
    for _, name in ipairs(ns:GuideNames()) do
        local guide = ns:GuideGet(name)
        local mine = st and st.name == name
        lines[#lines + 1] = { left = name .. (mine and ("  " .. ns:SignalHex("good") .. ns:Tr("following") .. "|r") or "") .. ((rec and rec.name == name) and ("  " .. ns:SignalHex("bad") .. ns:Tr("recording") .. "|r") or ""),
            right = format(ns:TrN(#guide.steps, "%d step", "%d steps"), #guide.steps), tone = mine and "@accent" or nil,
            click = function(button) if button == "RightButton" then ns:GuideEdit(name) else ns:GuideFollow(name); ns:GuideList() end end }
    end
    lines[#lines + 1] = { left = "" }
    lines[#lines + 1] = { left = "+ " .. ns:Tr("Write or paste a guide"), action = true, click = function() ns:GuideEdit("") end }
    if st then lines[#lines + 1] = { left = "x " .. ns:Tr("Stop following"), action = true, click = function() ns:GuideStop(); ns:GuideList() end } end
    lines[#lines + 1] = { left = ns:Tr("Record one as you play: /fgui guide record My route"), tone = "dim", wrap = true }   -- (a hint, not a button)
    return ns:ShowList("Guides", "Quest guides", lines, "Click a guide to follow it. Right-click to read, change, copy or delete it.", 460, 340)
end

-- Quest guides are not released yet. Everyone sees a "coming soon" page; the guide itself runs only
-- where it has been unlocked with the author's phrase (/fgui unlock <phrase>; /fgui lock undoes it).
-- Only a number worked out from the phrase is kept here, not the phrase.
local GUIDE_KEY = 1859047492
function ns.GuideHash(text)
    local h = 5381
    text = tostring(text or "")
    for i = 1, #text do h = (h * 33 + text:byte(i)) % 4294967296 end
    return h
end
function ns:GuideUnlocked() return type(ns.root) == "table" and ns.root.guideKey == GUIDE_KEY end
function ns:GuideUnlock(phrase)
    if type(ns.root) ~= "table" or ns.GuideHash(ns.Trim(phrase):lower()) ~= GUIDE_KEY then return false end
    ns.root.guideKey = GUIDE_KEY
    LockChanged(true)
    return true
end
-- The switch (on the Guide tab, and in the setup) was changed: put that into effect.
function ns:GuideOn() return ns:GuideUnlocked() and not (ns.db and ns.db.questGuide == false) end
function ns:GuideLock()
    if type(ns.root) == "table" then ns.root.guideKey = nil end
    LockChanged(false)
    return ns:GuideApplySwitch()
end
function ns:GuideApplySwitch()
    if ns:GuideOn() then
        if State() then ns:GuideShowPanel(); ns:GuideAdvance() end
        return true
    end
    if rec then ns:GuideRecordStop() end                      -- (a recording is kept, and ends)
    Point(nil)
    if panel then panel:Hide() end
    return false
end

-- /fgui guide ...
function ns:GuideCommand(text)
    text = ns.Trim(text)
    if not ns:GuideUnlocked() then ns:Print("Quest guides are coming soon."); return false end
    if not ns:GuideOn() then
        ns:Print("Quest guides are switched off. Switch them on under Guide in /fgui, or in the setup.")
        return false
    end
    local word, rest = text:match("^(%S+)%s*(.*)$")
    word = word and word:lower() or ""
    if commands[word] then return Hook(word, commands[word], rest) end      -- (a word another file registered comes first)
    if word == "" or word == "list" then return ns:GuideList()
    elseif word == "record" then return ns:GuideRecord(rest)
    elseif word == "stop" then
        if not ns:GuideRecordStop() then ns:GuideStop(); ns:Print("No longer following a guide.") end
        if ns.PlannerInnSuggest then ns.PlannerInnSuggest() end
    elseif word == "edit" or word == "new" or word == "paste" then return ns:GuideEdit(rest)
    elseif word == "route" then return ns.GuideRouteEditor and ns:GuideRouteEditor(rest ~= "" and rest or nil)
    elseif word == "next" or word == "skip" then ns:GuideSkip(false)
    elseif word == "back" then ns:GuideSkip(true)
    elseif word == "off" then ns:GuideStop(); ns:Print("No longer following a guide.")
    elseif word == "follow" then return ns:GuideFollow(rest)
    elseif word == "plan" then return ns.PlannerStart ~= nil and ns:PlannerStart()
    elseif ns:GuideGet(text) then return ns:GuideFollow(text)
    else ns:Print("Quest guide: /fgui guide (your guides), record <name>, stop, edit <name>, route <name>, follow <name>, plan, next, back, off.") end
end
