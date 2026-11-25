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
    learnflight = { "L", { 0.6, 0.85, 1 }, "Learn the flight path" },
    sail = { "S", { 0.6, 0.85, 1 }, "Sail" },       bind = { "B", { 0.6, 0.85, 1 }, "Set your hearthstone" },
    -- stops on the way (PlannerStops.lua): a few words and a place, nothing else
    train = { "T", { 0.85, 0.7, 1 }, "Train" },     vendor = { "V", { 0.85, 0.7, 1 }, "Visit the vendor" },
    mail = { "M", { 0.85, 0.7, 1 }, "Check your mail" },
    explore = { "E", { 0.5, 1, 0.7 }, "Explore" },  gather = { "G", { 0.5, 1, 0.7 }, "Gather" },
}
-- Stops done when their window closes while they are the step you are on (Planner.lua ticks them).
ns.GUIDE_WINDOW_KINDS = { train = "TRAINER_CLOSED", vendor = "MERCHANT_CLOSED", mail = "MAIL_CLOSED" }
ns.GUIDE_STOP_KINDS = { train = true, vendor = true, mail = true, explore = true, gather = true }   -- (the kinds a planner stop may be)
local QUEST_KIND = { accept = true, turnin = true, ["do"] = true }
ns.builtinGuides = ns.builtinGuides or {}

-- One line of a guide -> a step. Nil for an empty line or a comment; nil and why for a line that is wrong.
function ns.GuideParseLine(line)
    line = ns.Trim(line)
    if line == "" or line:sub(1, 1) == "#" then return nil end
    local step = {}
    local body, map, x, y = line:match("^(.-)%s*@%s*(%d+):([%d%.]+)%s*,%s*([%d%.]+)$")
    if not body then body, x, y = line:match("^(.-)%s*@%s*([%d%.]+)%s*,%s*([%d%.]+)$") end
    if body then
        line = ns.Trim(body)
        step.map, step.x, step.y = tonumber(map), tonumber(x), tonumber(y)
        if not step.x or not step.y or step.x > 100 or step.y > 100 then return nil, "the place after @ is not two numbers up to 100" end
    end
    local left, text = line:match("^(.-)%s*|%s*(.*)$")
    left = ns.Trim(left or line)
    if text and ns.Trim(text) ~= "" then step.text = ns.Trim(text) end
    local kind, rest = left:match("^(%S+)%s*(.*)$")
    kind = kind and kind:lower()
    if not kind or not ns.guideKinds[kind] then return nil, "a step starts with accept, turnin, do, goto, note, level, hearth, fly, learnflight, sail, bind, train, vendor, mail, explore or gather" end
    step.kind = kind
    rest = ns.Trim(rest)
    if QUEST_KIND[kind] then
        local id, title = rest:match("^(%d+)%s*(.*)$")
        if not id then return nil, kind .. " needs the quest's number" end
        step.quest = tonumber(id)
        if title ~= "" then step.title = title end
    elseif kind == "level" then
        step.level = tonumber(rest:match("^(%d+)"))
        if not step.level then return nil, "level needs a number" end
    elseif kind == "fly" or kind == "learnflight" then
        local node, more = rest:match("^(%d+)%s*(.*)$")
        if node then
            step.node = tonumber(node)
            rest = more
        elseif kind == "learnflight" then
            return nil, "learnflight needs the flight point's number"
        end
        if rest ~= "" and not step.text then step.text = rest end
    elseif kind == "sail" then
        local crossing, more = rest:match("^(%S+)%s*(.*)$")
        if not crossing then return nil, "sail needs the crossing's name" end
        step.crossing = crossing
        if more ~= "" and not step.text then step.text = more end
    elseif rest ~= "" and not step.text then
        step.text = rest
    end
    if kind == "goto" and not step.x then return nil, "goto needs a place: @ x,y" end
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
            local step, why = ns.GuideParseLine(line)
            if step then guide.steps[#guide.steps + 1] = step
            elseif why then problems[#problems + 1] = format("line %d: %s", n, why) end
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
function ns.GuideStepBase(step)
    local k = step.kind
    if k == "accept" then return ns:Tr("Accept") .. ": " .. (step.title or ("#" .. step.quest)) .. (step.text and ("  (" .. step.text .. ")") or "") end
    if k == "turnin" then return ns:Tr("Turn in") .. ": " .. (step.title or ("#" .. step.quest)) .. (step.text and ("  (" .. step.text .. ")") or "") end
    if k == "do" then return step.text or (step.title or ("#" .. step.quest)) end
    if k == "goto" then return step.text or format("%s %.0f, %.0f", ns:Tr("Go to"), step.x, step.y) end
    if k == "level" then return ns:Tr("Reach level") .. " " .. step.level end
    if k == "hearth" then return step.text or ns:Tr("Use your hearthstone") end
    if k == "fly" then return step.text or ns:Tr("Take the flight") end
    if k == "learnflight" then return step.text or ns:Tr("Learn the flight path") end
    if k == "sail" then return step.text or ns:Tr("Take the boat") end
    if k == "bind" then return step.text or ns:Tr("Set your hearthstone here") end
    if ns.GUIDE_STOP_KINDS[k] then return step.text or ns:Tr(ns.guideKinds[k][3]) end   -- (a stop's words say what it is)
    return step.text or ""
end

-- Is this step done? `world` answers the questions about the game; `ticked` = you ticked it off yourself.
function ns.GuideStepDone(step, world, ticked)
    if ticked then return true end
    local k, q = step.kind, step.quest
    if k == "accept" then return world.onQuest(q) or world.completed(q) end
    if k == "turnin" then return world.completed(q) end
    if k == "do" then return world.completed(q) or world.ready(q) end
    if k == "goto" then return world.near(step) end
    if k == "level" then return (world.level or 0) >= step.level end
    local function Ask1(fn, arg) return type(fn) == "function" and fn(arg) == true end
    if k == "fly" then
        if step.node then return Ask1(world.landedAt, step.node) end
        return step.x ~= nil and Ask1(world.near, step)
    end
    if k == "learnflight" then return Ask1(world.knownFlight, step.node) end
    if k == "sail" then return Ask1(world.crossed, step.crossing) end
    if k == "bind" then return world.bind ~= nil and world.bind == step.text end
    if k == "explore" or k == "gather" then return step.x ~= nil and Ask1(world.near, step) end   -- (passing it is enough)
    return false                                              -- (train, vendor, mail: ticked when the window closes)
end
-- The first step from `from` on that is not done (one past the end when all are).
function ns.GuideNext(steps, from, world, ticked)
    local i = math.max(1, from or 1)
    while steps[i] and ns.GuideStepDone(steps[i], world, ticked and ticked[i]) do i = i + 1 end
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
function ns:GuideWorld()
    local Q = C_QuestLog or {}
    local level = UnitLevel and UnitLevel("player")
    local bind
    if GetBindLocation then
        local ok, v = pcall(GetBindLocation)
        if ok and type(v) == "string" and not Secret(v) and v ~= "" then bind = v end
    end
    local function Planner(fn, arg)
        if type(fn) ~= "function" then return false end
        local ok, v = pcall(fn, arg)
        return ok and v == true
    end
    return {
        bind = bind,
        knownFlight = function(node) return Planner(ns.PlannerKnownFlight, node) end,
        landedAt = function(node) return Planner(ns.PlannerLandedAt, node) end,
        crossed = function(crossing) return Planner(ns.PlannerCrossed, crossing) end,
        onQuest = function(id) return Ask(Q.IsOnQuest, id) end,
        completed = function(id) return Ask(Q.IsQuestFlaggedCompleted, id) end,
        ready = function(id) return Ask(Q.IsComplete, id) or Ask(Q.ReadyForTurnIn, id) end,
        level = (type(level) == "number" and not Secret(level)) and level or 0,
        near = function(step)
            if not (step.x and step.y and ns.MapPosition and ns.WayArrow) then return false end
            local map = step.map or Here()
            if not map then return false end
            local px, py = ns.MapPosition(map, "player")
            if not px then return false end
            local w, h = 1000, 667
            if ns.MapWorldSize then w, h = ns.MapWorldSize(map) end
            local _, distance = ns.WayArrow(px, py, step.x / 100, step.y / 100, w, h, 0)
            return distance < ns.GUIDE_NEAR
        end,
    }
end

-- Guides kept with the settings (for every character), and the one this character is following ----
local function Store()
    if type(ns.root) ~= "table" then return {}, {} end
    if type(ns.root.guides) ~= "table" then ns.root.guides = {} end
    if type(ns.root.guideState) ~= "table" then ns.root.guideState = {} end
    return ns.root.guides, ns.root.guideState
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
    if type(guide) ~= "table" or type(guide.name) ~= "string" or ns.Trim(guide.name) == "" then return false, "the guide needs a name (a first line such as \"guide: My route\")" end
    local guides = Store()
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
-- Where the step is, for the arrow: its own place, or where the game says the quest goes next.
local function PlaceOf(step)
    if step.x and step.y then return step.map, step.x, step.y end
    if step.quest and step.kind ~= "accept" and C_QuestLog and C_QuestLog.GetNextWaypoint then
        local ok, map, x, y = pcall(C_QuestLog.GetNextWaypoint, step.quest)
        if ok and type(map) == "number" and type(x) == "number" and type(y) == "number" and not Secret(x) then return map, x * 100, y * 100 end
    end
end
local pointed
local function Point(step, index)
    if not step then
        if pointed and ns.waypoint and ns.waypoint.quiet then ns:ClearWaypoint(true) end
        pointed = nil
        return
    end
    if pointed == index then return end
    pointed = index
    local map, x, y = PlaceOf(step)
    if x and ns.SetWaypoint then ns:SetWaypoint(x, y, ns.GuideStepText(step), map, true)
    elseif ns.waypoint and ns.waypoint.quiet then ns:ClearWaypoint(true) end
end

-- Move on to the first step that is not done. Returns the step and its number (nil at the end).
function ns:GuideAdvance()
    local st = State()
    if not st or not ns:GuideOn() then return nil end
    local guide = ns:GuideGet(st.name)
    if not guide then return nil end
    st.ticked = type(st.ticked) == "table" and st.ticked or {}
    local before = st.at or 1
    st.at = ns.GuideNext(guide.steps, before, ns:GuideWorld(), st.ticked)
    if st.name == ns.GUIDE_PLANNED and ns.PlannerExploreReached then      -- (an explore spot reached: not asked again)
        for i = before, st.at - 1 do
            local s = guide.steps[i]
            if type(s) == "table" and s.kind == "explore" and not st.ticked[i] then ns.PlannerExploreReached(s) end
        end
    end
    local step = guide.steps[st.at]
    if st.at ~= before and PlaySound and SOUNDKIT and ns.db.guideSound ~= false then pcall(PlaySound, SOUNDKIT.IG_QUEST_LIST_SELECT or 875) end
    if not step and not st.finished then
        st.finished = true
        if st.name ~= ns.GUIDE_PLANNED then ns:Print("Guide finished: %s", tostring(guide.name)) end
    end
    Point(step, st.at)
    if Draw then Draw() end
    return step, st.at
end
function ns:GuideFollow(name)
    if name ~= nil and name == ns.GUIDE_PLANNED then return ns.PlannerStart ~= nil and ns:PlannerStart() end
    local guide = ns:GuideGet(name)
    if not guide then ns:Print("There is no guide called \"%s\". /fgui guide lists them.", tostring(name)); return false end
    local _, state = Store()
    local old = state[ns:CharKey()]
    state[ns:CharKey()] = (old and old.name == name) and old or { name = name, at = 1, ticked = {} }
    state[ns:CharKey()].finished = nil
    if ns.PlannerStop then ns:PlannerStop() end
    pointed = nil
    ns:GuideShowPanel()
    ns:GuideAdvance()
    ns:Print("Following \"%s\": %d steps.", name, #guide.steps)
    return true
end
-- A step as the same thing to do, wherever it sits in a plan.
local function StepKey(step)
    -- (a planner stop is known by its stopKey: its words, such as what to buy, may change between plans)
    return table.concat({ tostring(step.kind), tostring(step.quest), tostring(step.node), tostring(step.crossing), step.stopKey and "" or tostring(step.text), tostring(step.stopKey) }, "\1")
end
-- Follow a new plan (Planner.lua), from its first step; nil = an empty one until the first is ready.
-- Steps you ticked off yourself in the old plan stay ticked where the new plan has them too (a
-- planner stop by its stopKey, so the next visit to the same trainer is a new step).
function ns:GuideSetPlan(guide, summary)
    local _, state = Store()
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
        if (had[k] or 0) > 0 then had[k] = had[k] - 1; ticked[i] = true end
    end
    state[ns:CharKey()] = { name = ns.GUIDE_PLANNED, at = 1, ticked = ticked, summary = summary, plan = plan }
    pointed = nil
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
        st.finished = nil
        pointed = nil
        local guide = ns:GuideGet(st.name)
        Point(guide and guide.steps[st.at], st.at)
        if Draw then Draw() end
    else
        st.ticked[st.at or 1] = true
        ns:GuideAdvance()
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
local function Title(st, guide)
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
    if s.empty then return ns:Tr("No quests left worth the trip; grinding or a dungeon may be faster") end
    return ns:Tr("This guide is finished.")
end
local function SkippedText(st)
    local s = Planned(st) and type(st.summary) == "table" and st.summary
    local n = s and type(s.skipped) == "table" and tonumber(s.skipped.group) or 0
    if n <= 0 then return nil end
    local group = ns.db and ns.db.plannerGroup
    local solo = group == nil or group == "solo"
    return format(ns:Tr(solo and "Skipped: %d group quests (Solo is on)" or "Skipped: %d group quests"), n)
end
-- "2 talent points to spend", when the game says there are some.
local function TalentText()
    local n = ns.PlannerUnspentTalents and ns.PlannerUnspentTalents()
    if type(n) ~= "number" or n <= 0 then return nil end
    return format(ns:Tr(n == 1 and "%d talent point to spend" or "%d talent points to spend"), n)
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
    return format(ns:Tr("%s: %s to %s"), ns.PlannerRepName(best), nice, ns.PlannerRepStandingName(goals[best]))
end
-- "Moved: you died twice here (back at level 14)": a hub left out of this plan because you died twice there.
local function MovedText(st)
    local s = Planned(st) and type(st.summary) == "table" and st.summary
    local lv = s and tonumber(s.moved)
    if not lv then return nil end
    return format(ns:Tr("Moved: you died twice here (back at level %d)"), lv)
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
    for _, id in ipairs(ids) do
        lines[#lines + 1] = { left = QuestName(id), right = ns:Tr("Suggest again"),
            click = function()
                if ns.PlannerSkip then ns.PlannerSkip(id, false) end
                ns:GuideSkipped()
            end }
    end
    return ns:ShowList("Skipped", "Quests you skipped", lines, "Click a quest to suggest it again.", 400, 340)
end
-- The small menu on a quest step (right click): one entry, to never suggest the quest (or to allow it again).
local stepMenu
function ns:GuideStepMenu(step)
    if type(step) ~= "table" or type(step.quest) ~= "number" then return nil end
    if not stepMenu then
        stepMenu = CreateFrame("Frame", "FantasyGlassUIGuideMenu", UIParent, ns.template)
        stepMenu:SetSize(200, 26)
        stepMenu:SetFrameStrata("DIALOG")
        stepMenu:SetBackdrop(ns.BACKDROP)
        ns:Paint(stepMenu, "SetBackdropColor", "window", 0.95)
        ns:Paint(stepMenu, "SetBackdropBorderColor", "@border", 1)
        stepMenu.button = ns:CreateButton(stepMenu, "", 192, 20, function()
            local id = stepMenu.quest
            stepMenu:Hide()
            if id and ns.PlannerSkip then ns.PlannerSkip(id, not stepMenu.skipped) end
        end)
        stepMenu.button:SetPoint("CENTER")
        stepMenu:SetScript("OnLeave", function(self) if not (self:IsMouseOver() or stepMenu.button:IsMouseOver()) then self:Hide() end end)
        stepMenu.button:HookScript("OnLeave", function() if not stepMenu:IsMouseOver() then stepMenu:Hide() end end)
        stepMenu:Hide()
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUIGuideMenu") end   -- (Escape closes it)
        ns.guideStepMenu = stepMenu
        local away = CreateFrame("Frame")                    -- (a click anywhere else closes it)
        pcall(away.RegisterEvent, away, "GLOBAL_MOUSE_DOWN")
        away:SetScript("OnEvent", function()
            if stepMenu:IsShown() and not (stepMenu:IsMouseOver() or stepMenu.button:IsMouseOver()) then stepMenu:Hide() end
        end)
    end
    stepMenu.quest = step.quest
    stepMenu.skipped = (ns.PlannerSkipList and ns.PlannerSkipList()[step.quest]) and true or false
    stepMenu.button.text:SetText(ns:Tr(stepMenu.skipped and "Suggest again" or "Never suggest this quest"))
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
-- The factions you want reputation with: a list to click, each cycling Honored, Revered, Exalted, off.
function ns:GuideReputation()
    local lines = {}
    local goals = ns.PlannerRepGoals and ns.PlannerRepGoals() or {}
    for _, f in ipairs(ns.PlannerKnownFactions and ns.PlannerKnownFactions() or {}) do
        local now = goals[f.id]
        local at = 0
        for i, s in ipairs(ns.PLANNER_REP_STANDINGS or {}) do if s == now then at = i end end
        local nextStanding = (ns.PLANNER_REP_STANDINGS or {})[at + 1]
        lines[#lines + 1] = { left = f.name, right = now and ns.PlannerRepStandingName(now) or ("|cff9aa4b4" .. ns:Tr("off") .. "|r"),
            color = now and { 1, 0.82, 0.3 } or nil,
            click = function()
                if ns.PlannerSetRepGoal then ns.PlannerSetRepGoal(f.id, nextStanding) end
                ns:GuideReputation()
            end }
    end
    return ns:ShowList("Reputation", "Reputation I want", lines, "Click a faction to cycle: Honored, Revered, Exalted, off. Quests that give it count for more.", 400, 340)
end
Draw = function()
    if not panel then return end
    local st = State()
    local guide = st and ns:GuideGet(st.name)
    if not guide then panel:Hide(); return end
    local at, steps = st.at or 1, guide.steps
    panel.title:SetText(Title(st, guide))
    local skipped = (Planned(st) and st.planFailed) and ns:Tr("Couldn't plan the route; trying again after your next quest") or SkippedText(st)
    panel.skipped:SetText(skipped or "")
    panel.skipped:SetShown(skipped ~= nil)
    local talents = Planned(st) and TalentText() or nil          -- (talent points waiting; the planned guide only)
    panel.talent:SetText(talents or "")
    panel.talent:SetShown(talents ~= nil)
    panel.talentButton:SetShown(talents ~= nil)
    panel.talent:ClearAllPoints()
    panel.talent:SetPoint("TOPLEFT", 12, skipped and -105 or -92)
    panel.talentButton:ClearAllPoints()
    panel.talentButton:SetPoint("TOPRIGHT", -8, skipped and -103 or -90)
    local riding = (Planned(st) and ns.db and ns.db.plannerMount ~= false) and RidingText() or nil
    panel.riding:SetText(riding or "")
    panel.riding:SetShown(riding ~= nil)
    panel.riding:ClearAllPoints()
    panel.riding:SetPoint("TOPLEFT", 12, -92 - (skipped and 13 or 0) - (talents and 13 or 0))
    local rep = Planned(st) and RepText(st) or nil
    panel.rep:SetText(rep or "")
    panel.rep:SetShown(rep ~= nil)
    panel.rep:ClearAllPoints()
    panel.rep:SetPoint("TOPLEFT", 12, -92 - (skipped and 13 or 0) - (talents and 13 or 0) - (riding and 13 or 0))
    local moved = Planned(st) and MovedText(st) or nil
    panel.moved:SetText(moved or "")
    panel.moved:SetShown(moved ~= nil)
    panel.moved:ClearAllPoints()
    panel.moved:SetPoint("TOPLEFT", 12, -92 - (skipped and 13 or 0) - (talents and 13 or 0) - (riding and 13 or 0) - (rep and 13 or 0))
    panel:SetHeight(118 + (skipped and 13 or 0) + (talents and 13 or 0) + (riding and 13 or 0) + (rep and 13 or 0) + (moved and 13 or 0))
    panel.count:SetText(math.min(at, #steps) .. "/" .. #steps)
    local step = steps[at]
    if step then
        local kind = ns.guideKinds[step.kind]
        panel.badge:SetText(kind[1])
        panel.badge:SetTextColor(kind[2][1], kind[2][2], kind[2][3])
        panel.now:SetText(ns.GuideStepText(step, guide))
    else
        panel.badge:SetText("")
        panel.now:SetText(EndText(st))
    end
    for i = 1, 2 do
        local nextStep = steps[at + i]
        panel.later[i]:SetText(nextStep and (ns.guideKinds[nextStep.kind][1] .. "  " .. ns.GuideStepText(nextStep, guide)) or "")
    end
    panel.bar:SetMinMaxValues(0, math.max(1, #steps))
    panel.bar:SetValue(math.min(at - 1, #steps))
end
function ns:GuideShowPanel()
    if not ns:GuideOn() then return nil end
    if not panel then
        panel = CreateFrame("Frame", "FantasyGlassUIGuide", UIParent, ns.template)
        panel:SetSize(280, 118)
        panel:SetPoint("RIGHT", UIParent, "RIGHT", -260, 120)
        panel:SetBackdrop(ns.BACKDROP)
        ns:Paint(panel, "SetBackdropColor", "window", 0.9)
        ns:Paint(panel, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(panel)
        panel.title = ns:NewText(panel, 12, "LEFT", true)
        panel.title:SetPoint("TOPLEFT", 10, -8)
        panel.title:SetWidth(200)
        if panel.title.SetWordWrap then panel.title:SetWordWrap(false) end
        ns:Paint(panel.title, "SetTextColor", "@accent")
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
        panel.badge:SetWidth(18)
        panel.now = ns:NewText(panel, 12, "LEFT")
        panel.now:SetPoint("TOPLEFT", 34, -34)
        panel.now:SetWidth(236)
        if panel.now.SetWordWrap then panel.now:SetWordWrap(true) end
        if panel.now.SetMaxLines then panel.now:SetMaxLines(2) end
        panel.later = {}
        for i = 1, 2 do
            local fs = ns:NewText(panel, 10, "LEFT")
            fs:SetPoint("TOPLEFT", 12, -66 - (i - 1) * 13)
            fs:SetWidth(258)
            if fs.SetWordWrap then fs:SetWordWrap(false) end
            ns:Paint(fs, "SetTextColor", "faint")
            panel.later[i] = fs
        end
        panel.skipped = ns:NewText(panel, 10, "LEFT")              -- (a planned route: quests left out by the group setting)
        panel.skipped:SetPoint("TOPLEFT", 12, -92)
        panel.skipped:SetWidth(258)
        if panel.skipped.SetWordWrap then panel.skipped:SetWordWrap(false) end
        ns:Paint(panel.skipped, "SetTextColor", "faint")
        panel.talent = ns:NewText(panel, 10, "LEFT")               -- (a planned route: talent points waiting)
        panel.talent:SetPoint("TOPLEFT", 12, -92)
        panel.talent:SetWidth(206)
        if panel.talent.SetWordWrap then panel.talent:SetWordWrap(false) end
        ns:Paint(panel.talent, "SetTextColor", "faint")
        panel.talentButton = ns:CreateButton(panel, "Build", 44, 14, function()
            if ns.TalentCommand then ns:TalentCommand("") end         -- (your talent builds, as /fgui talents)
        end)
        panel.talentButton:SetPoint("TOPRIGHT", -8, -90)
        panel.talent:Hide(); panel.talentButton:Hide()
        panel.riding = ns:NewText(panel, 10, "LEFT")               -- (a planned route: gold still to find for riding)
        panel.riding:SetPoint("TOPLEFT", 12, -92)
        panel.riding:SetWidth(206)
        if panel.riding.SetWordWrap then panel.riding:SetWordWrap(false) end
        ns:Paint(panel.riding, "SetTextColor", "faint")
        panel.riding:Hide()
        panel.rep = ns:NewText(panel, 10, "LEFT")                  -- (a planned route: a wanted faction's reputation a quest gives)
        panel.rep:SetPoint("TOPLEFT", 12, -92)
        panel.rep:SetWidth(206)
        if panel.rep.SetWordWrap then panel.rep:SetWordWrap(false) end
        ns:Paint(panel.rep, "SetTextColor", "faint")
        panel.rep:Hide()
        panel.moved = ns:NewText(panel, 10, "LEFT")                -- (a planned route: a hub left out because you died twice there)
        panel.moved:SetPoint("TOPLEFT", 12, -92)
        panel.moved:SetWidth(258)
        if panel.moved.SetWordWrap then panel.moved:SetWordWrap(false) end
        ns:Paint(panel.moved, "SetTextColor", "faint")
        panel.moved:Hide()
        panel.stepButton = CreateFrame("Button", nil, panel)         -- (right click on a quest step: never suggest it)
        panel.stepButton:SetPoint("TOPLEFT", 34, -34)
        panel.stepButton:SetSize(236, 30)
        panel.stepButton:RegisterForClicks("RightButtonUp")
        panel.stepButton:SetScript("OnClick", function(_, button)
            if button ~= "RightButton" then return end
            local st = State()
            local guide = st and Planned(st) and ns:GuideGet(st.name)
            local step = guide and guide.steps[st.at or 1]
            if type(step) == "table" and type(step.quest) == "number" then ns:GuideStepMenu(step) end
        end)
        local back = ns:CreateButton(panel, "<", 22, 18, function() ns:GuideSkip(true) end)
        back:SetPoint("BOTTOMLEFT", 8, 6)
        local skip = ns:CreateButton(panel, ">", 22, 18, function() ns:GuideSkip(false) end)
        skip:SetPoint("LEFT", back, "RIGHT", 4, 0)
        local list = ns:CreateButton(panel, "Guides", 64, 18, function() ns:GuideList() end)
        list:SetPoint("BOTTOMRIGHT", -8, 6)
        for _, def in ipairs({ { back, "Back one step" }, { skip, "Tick this step off and move on" }, { list, "Your guides: follow another, record, write or paste one" }, { panel.talentButton, "Open your talent builds" } }) do
            def[1]:HookScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(ns:Tr(def[2]), 1, 1, 1); GameTooltip:Show() end)
            def[1]:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        local entry = ns:RegisterMovable(panel, "questGuide", "Quest guide")
        if type(entry) == "table" then entry.offPage = true end
    end
    panel:Show()
    Draw()
    return panel
end
function ns:GuidePanelShown() return (panel and ns.Yes(panel:IsShown())) or false end

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
function ns.GuideRecordStep(recording, step)
    for i = #recording.steps, math.max(1, #recording.steps - 40), -1 do
        local s = recording.steps[i]
        if s.kind == step.kind and s.quest == step.quest and (step.quest or s.text == step.text) then return false end
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
    ns:Print("Recording stopped: \"%s\" has %d steps. /fgui guide edit %s shows them.", done.name, #done.steps, done.name)
    return done
end

do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Quest guide", function(_, event, a, b)
        if not ns:GuideOn() then return end
        if rec then
            if event == "QUEST_ACCEPTED" then ns:GuideRecordEvent("accept", (type(b) == "number") and b or a)
            elseif event == "QUEST_TURNED_IN" then ns:GuideRecordEvent("turnin", a)
            elseif event == "QUEST_LOG_UPDATE" then
                local Q = C_QuestLog or {}
                for id, state in pairs(rec.open) do
                    if state == true and (Ask(Q.IsComplete, id) or Ask(Q.ReadyForTurnIn, id)) then ns:GuideRecordEvent("do", id) end
                end
            end
        end
        if State() then
            if event == "PLAYER_ENTERING_WORLD" then ns:GuideShowPanel() end
            ns:After(0.3, function() pcall(ns.GuideAdvance, ns) end)      -- (once the game has caught up)
        end
    end))
    -- a place is reached without any event: look once a second while following
    local wait = 0
    ev:SetScript("OnUpdate", function(_, elapsed)
        wait = wait + (elapsed or 0)
        if wait < 1 then return end
        wait = 0
        if not ns:GuideOn() then return end
        local st = State and State()
        if not st or st.finished then return end
        local guide = ns:GuideGet(st.name)
        local step = guide and guide.steps[st.at or 1]
        if step and (step.kind == "goto" or step.kind == "level" or step.kind == "explore" or step.kind == "gather") then pcall(ns.GuideAdvance, ns) end
    end)
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
        w.note = ns:NewText(w, 10, "LEFT")
        w.note:SetPoint("TOPLEFT", 14, -34)
        w.note:SetWidth(530)
        ns:Paint(w.note, "SetTextColor", "faint")
        w.note:SetText(ns:Tr("One step to a line: accept, do or turnin, the quest's number and name; goto, note, level. \"| text\" adds a few words, \"@ map:x,y\" a place. Ctrl+A and Ctrl+C copy a guide; Ctrl+V pastes one."))
        local scroll = CreateFrame("ScrollFrame", "FantasyGlassUIGuideEditorScroll", w, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 14, -66)
        scroll:SetPoint("BOTTOMRIGHT", -32, 44)
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
        w.status:SetWidth(250)
        function w:Read()
            local guide, problems = ns.GuideParse(self.box:GetText(), self.name)
            return guide, problems
        end
        local function Save(follow)
            local guide, problems = w:Read()
            local ok, why = ns:GuideSave(guide)
            if not ok then w.status:SetText(ns:SignalHex("bad") .. ns:Tr(why) .. "|r"); return false end
            w.name = guide.name
            w.status:SetText((#problems > 0) and ("|cffffd100" .. problems[1] .. ((#problems > 1) and format(" (+%d)", #problems - 1) or "") .. "|r")
                or format(ns:Tr("Saved: %d steps."), #guide.steps))
            if follow then ns:GuideFollow(guide.name) end
            return true
        end
        w.Save = Save
        local follow = ns:CreateButton(w, "Save and follow", 130, 24, function() Save(true) end)
        follow:SetPoint("BOTTOMRIGHT", -14, 12)
        local save = ns:CreateButton(w, "Save", 80, 24, function() Save(false) end)
        save:SetPoint("RIGHT", follow, "LEFT", -6, 0)
        local delete = ns:CreateButton(w, "Delete", 80, 24, function()
            if w.name and ns:GuideDelete(w.name) then w.status:SetText(ns:Tr("Deleted.")); w.box:SetText(""); w.name = nil end
        end)
        delete:SetPoint("RIGHT", save, "LEFT", -6, 0)
        editor = w
    end
    local guide = name and ns:GuideGet(name)
    editor.name = guide and guide.name or nil
    editor.box:SetText(guide and ns.GuideText(guide) or ("guide: " .. ((name and name ~= "") and name or "My route") .. "\n"))
    editor.status:SetText("")
    editor:Show()
    return editor
end
function ns:GuideList()
    local st = State()
    local lines = {}
    for _, name in ipairs(ns:GuideNames()) do
        local guide = ns:GuideGet(name)
        local mine = st and st.name == name
        lines[#lines + 1] = { left = name .. (mine and ("  |cff33ff66" .. ns:Tr("following") .. "|r") or "") .. ((rec and rec.name == name) and ("  |cffff5555" .. ns:Tr("recording") .. "|r") or ""),
            right = format(ns:Tr("%d steps"), #guide.steps), color = mine and { 1, 0.82, 0.3 } or nil,
            click = function(button) if button == "RightButton" then ns:GuideEdit(name) else ns:GuideFollow(name); ns:GuideList() end end }
    end
    lines[#lines + 1] = { left = "" }
    lines[#lines + 1] = { left = "|cff9aa4b4+ " .. ns:Tr("Write or paste a guide") .. "|r", click = function() ns:GuideEdit("") end }
    lines[#lines + 1] = { left = "|cff9aa4b4+ " .. ns:Tr("Record one as you play: /fgui guide record My route") .. "|r" }
    if st then lines[#lines + 1] = { left = "|cff9aa4b4x " .. ns:Tr("Stop following") .. "|r", click = function() ns:GuideStop(); ns:GuideList() end } end
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
    return true
end
-- The switch (on the Guide tab, and in the setup) was changed: put that into effect.
function ns:GuideOn() return ns:GuideUnlocked() and not (ns.db and ns.db.questGuide == false) end
function ns:GuideLock()
    if type(ns.root) == "table" then ns.root.guideKey = nil end
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
    if word == "" or word == "list" then return ns:GuideList()
    elseif word == "record" then return ns:GuideRecord(rest)
    elseif word == "stop" then
        if not ns:GuideRecordStop() then ns:GuideStop(); ns:Print("No longer following a guide.") end
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
