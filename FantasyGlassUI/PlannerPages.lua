local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner, batch 4 group B: time to level, "Why this?", the preview page and finish the zone (Tasks 3 and 4).
-- Built on the seams: ns.PlannerHook (Planner.lua), the panel's registries (Guide.lua) and its
-- section of the Guide tab (Bars.lua). Everything here is behind ns:GuideUnlocked().
------------------------------------------------------------------------------------------

local format, floor, max = string.format, math.floor, math.max

-- A number read from the game, or nil (hidden values and non-numbers are nothing).
local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
local function Read(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, ...)
    return ok and Num(v) or nil
end
-- 7200 -> "7,200" (the game's own digit grouping).
local function Big(n)
    n = floor((tonumber(n) or 0) + 0.5)
    local ok, text = pcall(BreakUpLargeNumbers or tostring, n)
    if ok and type(text) == "string" then return text end
    return tostring(n)
end
local function Minutes(seconds, least)
    seconds = tonumber(seconds) or 0
    return max(least or (seconds > 0 and 1 or 0), floor(seconds / 60 + 0.5))   -- (a short trip is still 1 minute, not 0)
end
local function LevelText(v)
    v = tonumber(v)
    if not v then return "?" end
    return (v == floor(v)) and format("%d", v) or format("%.1f", v)
end
local function Unlocked() return ns:GuideUnlocked() == true end
-- The guide state, when it is the planned guide.
local function Planned()
    local st = ns.GuideState and ns.GuideState()
    if type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED then return st end
end

------------------------------------------------------------------------------------------
-- Task 3: time to your next level, why each step is there, a preview of the plan
------------------------------------------------------------------------------------------
-- Minutes to the next level at the plan's own speed (its seconds are already at your pace): needs 3 or more
-- pace samples, a plan that earns experience, and both experience values readable. Rounded, at least 1.
function ns.PlannerTimeToLevel(summary)
    if type(summary) ~= "table" then return nil end
    local gained, seconds = tonumber(summary.xp), tonumber(summary.seconds)
    if not (gained and seconds and gained > 0 and seconds > 0) then return nil end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    local samples = type(rec) == "table" and type(rec.pace) == "table" and rec.pace.samples
    if type(samples) ~= "table" or #samples < 3 then return nil end
    local have, need = Read(UnitXP, "player"), Read(UnitXPMax, "player")
    if not (have and need and need > 0) then return nil end
    return max(1, floor(max(0, need - have) / (gained / seconds) / 60 + 0.5))
end

ns.GuideRegisterTitle("planB", function(st)
    if not (Unlocked() and type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED) then return nil end
    local minutes = ns.PlannerTimeToLevel(st.summary)
    local level = Read(UnitLevel, "player")
    if not (minutes and level) then return nil end
    return format(ns:Tr("level %d in ~%d min"), level + 1, minutes)
end)

-- What made the Story or Safety weight take this hub over the one it beat: "story", "safety" or nil. The rank's
-- parts (PlannerPace's RankStyle): story = T x its story score, safety = F x its danger; the larger gain wins.
local function ChosenBy(hub, beat)
    local hp, bp = type(hub.parts) == "table" and hub.parts, type(beat.parts) == "table" and beat.parts
    if not (hp and bp) then return nil end
    local story = (tonumber(hp.story) or 0) - (tonumber(bp.story) or 0)
    local safety = (tonumber(bp.safety) or 0) - (tonumber(hp.safety) or 0)
    if story > 0 and story >= safety then return "story" end
    if safety > 0 then return "safety" end
    return nil
end

-- The numbers behind a planned step: { { left, right } }. A step of a hub: the hub's experience, travel, time
-- and rate, and the hub it beat (or that it was taken first); a stop on the way: what it saves or costs.
function ns.PlannerWhyLines(step, summary)
    local lines = {}
    if type(step) ~= "table" or type(summary) ~= "table" then return lines end
    local why = type(step.why) == "table" and step.why or nil
    local hub = type(summary.taken) == "table" and tonumber(step.hub) and summary.taken[step.hub] or nil
    local function Add(left, right) lines[#lines + 1] = { left = left, right = right } end
    if type(hub) == "table" then
        local xp = tonumber(why and why.xp) or tonumber(hub.xp)
        if xp then Add(ns:Tr("Experience"), Big(xp)) end
        if tonumber(hub.travel) then Add(ns:Tr("Travel"), format(ns:Tr("%d min"), Minutes(hub.travel))) end
        if tonumber(hub.seconds) then Add(ns:Tr("Time to do"), format(ns:Tr("%d min"), Minutes(hub.seconds))) end
        local rate = tonumber(hub.rate)
        if rate then Add(ns:Tr("Experience an hour"), Big(rate * 3600)) end
        local beat = type(hub.beat) == "table" and hub.beat or nil
        local beatRate = beat and tonumber(beat.rate)
        local chosen = not hub.lead and rate and beatRate and beatRate >= rate and (tonumber(hub.first) or 0) <= (tonumber(beat.first) or 0)
            and ChosenBy(hub, beat) or nil                     -- (a slower hub the Story or Safety weight chose over the runner-up)
        if chosen then
            Add(ns:Tr(chosen == "story" and "Chosen for its story" or "Chosen as safer"), "")
        elseif hub.lead or (rate and beatRate and beatRate >= rate) then
            Add(ns:Tr("Taken first"), "")                       -- (a lead-in, or put first: nothing it beat)
        elseif rate and beatRate and beatRate > 0 then
            local name = type(beat.name) == "string" and beat.name or ns:Tr("another hub")
            Add(format(ns:Tr("Beat %s at %s an hour (%d%% better)"), name, Big(beatRate * 3600), floor((rate / beatRate - 1) * 100 + 1e-9)), "")
        else
            Add(ns:Tr("Nothing else was worth the trip"), "")
        end
    elseif why then
        local saves, detour = tonumber(why.saves), tonumber(why.detour)
        if saves and saves > 0 then
            Add(ns:Tr("A stop on the way"), "")
            Add(format(ns:Tr("Saves about %d min"), Minutes(saves, 1)), "")
        elseif detour and detour > 0 then
            Add(ns:Tr("A stop on the way"), "")
            Add(format(ns:Tr("About %d min out of the way"), Minutes(detour, 1)), "")
        end
    end
    return lines
end

ns.GuideRegisterAction("step", "why", "Why this?", function(step)
    local st = Planned()
    if not (st and Unlocked()) then return end
    ns:ShowList("PlanWhy", "Why this?", ns.PlannerWhyLines(step, st.summary), nil, 420, 260)
end, function(step)
    local st = Planned()
    return (st and Unlocked() and type(step) == "table" and #ns.PlannerWhyLines(step, st.summary) > 0) and true or false
end)

-- The plan, as a page: its steps in order, what it earns, flights and crossings, what was left out.
local previewWindow
function ns.PlannerPreviewLines(guide, summary)
    local lines = {}
    summary = type(summary) == "table" and summary or {}
    local flights, crossings = 0, 0
    for i, step in ipairs(type(guide) == "table" and guide.steps or {}) do
        local ok, text = pcall(ns.GuideStepBase, step)
        lines[#lines + 1] = { left = format("%d. %s", i, ok and type(text) == "string" and text or tostring(step.kind)) }
        if step.kind == "fly" then flights = flights + 1 elseif step.kind == "sail" then crossings = crossings + 1 end
    end
    lines[#lines + 1] = { left = format(ns:Tr("Experience: %s"), Big(summary.xp)) }
    lines[#lines + 1] = { left = format(ns:Tr("Level %s → %s"), LevelText(summary.fromLevel), LevelText(summary.toLevel)) }
    lines[#lines + 1] = { left = format(ns:Tr("Flights: %d, crossings: %d"), flights, crossings) }
    local skipped = ns.GuideSkippedText and ns.GuideSkippedText(summary)       -- (the panel's own lines, Guide.lua)
    if skipped then lines[#lines + 1] = { left = skipped } end
    local moved = ns.GuideMovedText and ns.GuideMovedText(summary)
    if moved then lines[#lines + 1] = { left = moved } end
    local function Close() if previewWindow then previewWindow:Hide() end end
    lines[#lines + 1] = { left = ns:Tr("Follow"), color = { 1, 0.82, 0.3 }, click = Close }
    lines[#lines + 1] = { left = ns:Tr("Plan again"), color = { 1, 0.82, 0.3 }, click = function()
        Close()
        if ns.ToggleConfig then ns:ToggleConfig("guide") end
    end }
    return lines
end

local function ShowPreview(guide, summary)
    previewWindow = ns:ShowList("PlanPreview", "Preview the next hour", ns.PlannerPreviewLines(guide, summary), nil, 440, 420)
    return true
end
function ns:PlannerPreview()
    local st = Planned()
    if not (st and Unlocked()) then return false end
    local guide = ns:GuideGet(st.name)
    if type(guide) ~= "table" or type(guide.steps) ~= "table" or #guide.steps == 0 then return false end
    return ShowPreview(guide, st.summary)
end

ns.GuideRegisterAction("panel", "preview", "Preview", function() ns:PlannerPreview() end, function()
    local st = Planned()
    return (st and Unlocked() and type(st.summary) == "table" and (tonumber(st.summary.xp) or 0) > 0) and true or false   -- (a plan that earns something)
end)
-- The first plan after "Plan my route" opens the preview over it (a replan later does not).
ns.PlannerHook("applied", "preview", function(guide, summary, _, reason)
    if reason ~= "start" or not Unlocked() then return end
    if type(guide) ~= "table" or type(guide.steps) ~= "table" or #guide.steps == 0 or (type(summary) == "table" and summary.empty) then return end   -- (nothing to preview)
    local ok, err = pcall(ShowPreview, guide, summary)
    if not ok and type(ns.errors) == "table" and #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Planner preview: " .. tostring(err) end
end)

------------------------------------------------------------------------------------------
-- Task 4: a goal to finish a zone
-- The goal is one zone map, saved per character (rec.zoneGoal). While it is set: the level window of the
-- quests that start on that map reaches down to level 1, that map is the zone the plan picks (unless
-- "plan from here" came first), and the summary counts how far you are. When no hub is left on it, the
-- goal clears and the planner goes back to leveling.
------------------------------------------------------------------------------------------
local goalHubs                           -- did the zone hook find hubs on the goal map in the plan being made (nil: not asked)

function ns.PlannerZoneGoal()
    if not Unlocked() then return nil end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    return type(rec) == "table" and tonumber(rec.zoneGoal) or nil
end
-- Set the goal (a map) or clear it (nil), and plan again.
function ns.PlannerSetZoneGoal(map)
    if not Unlocked() then return false end
    map = tonumber(map)
    if map == nil and not ns.PlannerZoneGoal() then return true end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
    if type(rec) ~= "table" then return false end
    rec.zoneGoal = map
    if ns.PlannerReplan then ns:PlannerReplan("settings") end
    return true
end
-- The zone-level map you stand on (a city or cave map walked up to its zone).
function ns.PlannerGoalZone()
    local map = ns.GuideHere and ns.GuideHere()
    if type(map) ~= "number" or ns:IsSecret(map) then return nil end
    local chain = ns.PlannerZoneMaps and ns.PlannerZoneMaps(map) or { map }
    return chain[#chain]
end
function ns.PlannerMapName(map)
    local get = C_Map and C_Map.GetMapInfo
    if type(get) == "function" and type(map) == "number" then
        local ok, info = pcall(get, map)
        local name = ok and type(info) == "table" and info.name
        if type(name) == "string" and not ns:IsSecret(name) and name ~= "" then return name end
    end
    return tostring(map)
end

-- How far the goal map is done: { done, total } over its non-repeatable quests that are doable or done.
local progressCtx, progress
local function GoalProgress(goal, ctx)
    if progressCtx == ctx and progress and progress.map == goal then return progress end
    local src = ctx.source
    if type(src) ~= "table" or type(src.mapQuests) ~= "function" then return nil end
    local done, total = 0, 0
    local isDone = type(ctx.done) == "function" and ctx.done or function() return false end
    for _, id in ipairs(src.mapQuests(goal) or {}) do
        ns.PlannerYield()
        local rec = src.quest(id)
        if isDone(id) then
            if not (type(rec) == "table" and rec.repeatable) then done, total = done + 1, total + 1 end
        elseif type(rec) == "table" and rec.doable and not rec.repeatable then
            total = total + 1
        end
    end
    progressCtx, progress = ctx, { map = goal, done = done, total = total }
    return progress
end

-- Every plan starts here (what the zone hook found and the progress are the new plan's): with a goal set, the
-- goal map's quests pass the cheap level pre-filter whatever their level (ctx.windowPass); the quests of other
-- maps below the window are still left out cheaply. A source with no list of a map's quests: the pre-filter's
-- lower end drops to 1.
local function GoalContext(ctx)
    goalHubs, progressCtx, progress = nil, nil, nil
    local goal = ns.PlannerZoneGoal()
    if not goal then return end
    local src = ctx.source
    if type(src) == "table" and type(src.mapQuests) == "function" then
        local pass = type(ctx.windowPass) == "table" and ctx.windowPass or {}
        for _, id in ipairs(src.mapQuests(goal) or {}) do pass[id] = true end
        ctx.windowPass = pass
    else
        ctx.windowLo = 1
    end
end
ns.PlannerHook("context", "zoneGoal", GoalContext)
ns.PlannerHook("window", "zoneGoal", function(rec, _, lo, hi)
    local goal = ns.PlannerZoneGoal()
    local first = goal and type(rec) == "table" and type(rec.starts) == "table" and rec.starts[1]
    if first and first.map == goal then return math.min(1, tonumber(lo) or 1), hi end
    return lo, hi
end)
ns.PlannerHook("zone", "zoneGoal", function(maps)
    local goal = ns.PlannerZoneGoal()
    if not goal then return nil end
    goalHubs = type(maps[goal]) == "table" and #maps[goal] > 0
    return goalHubs and goal or nil
end)
ns.PlannerHook("route", "zoneGoal", function(_, summary, ctx)
    local goal = ns.PlannerZoneGoal()
    if not goal or (type(ctx.source) == "table" and ctx.source.kind == "log") then return end   -- (the quest log alone cannot count a zone)
    local p = GoalProgress(goal, ctx)
    if p then summary.zoneGoal = { map = goal, done = p.done, total = p.total } end
end)
-- Once, on the plan that was applied: no hub left on the goal map (the route hook runs up to four times a plan),
-- every counted quest of it done, or nothing at all to plan (the zone hook was never asked).
ns.PlannerHook("applied", "zoneGoal", function(_, summary, ctx)
    local goal = ns.PlannerZoneGoal()
    local asked = goalHubs
    goalHubs = nil
    if not goal or (type(ctx) == "table" and type(ctx.source) == "table" and ctx.source.kind == "log") then return end
    if type(ctx) == "table" and ctx.duo ~= nil then return end      -- (a plan for two is not yours alone: your goal stays)
    local took = false
    for _, t in pairs(type(summary.taken) == "table" and summary.taken or {}) do
        if type(t) == "table" and t.map == goal then took = true end
    end
    local zg = summary.zoneGoal
    local finished = type(zg) == "table" and (tonumber(zg.total) or 0) > 0 and (tonumber(zg.done) or 0) >= zg.total
    local nothing = asked == nil and type(summary) == "table" and summary.empty == true
    if took or not (asked == false or finished or nothing) then return end
    local rec = ns.PlannerCharRecord(true)
    rec.zoneGoal = nil
    local page = ns.guidePage                            -- (the Guide tab's goal button, when the tab was built)
    if type(page) == "table" and type(page.zoneGoalDraw) == "function" then pcall(page.zoneGoalDraw) end
    if type(zg) == "table" and (tonumber(zg.done) or 0) < (tonumber(zg.total) or 0) then   -- (doable quests are left, out of reach or above your level)
        ns:Print("No more quests in %s at your level", ns.PlannerMapName(goal))
    else
        ns:Print("Zone done: %s", ns.PlannerMapName(goal))
    end
    if ns.PlannerReplan then ns:PlannerReplan("zone done") end
end)

ns.GuideRegisterLine("zoneGoal", function(st)
    if not (Unlocked() and type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED) then return nil end
    local zg = type(st.summary) == "table" and st.summary.zoneGoal
    if type(zg) ~= "table" or not (tonumber(zg.done) and tonumber(zg.total)) then return nil end
    return format(ns:Tr("Zone: %d of %d quests"), zg.done, zg.total)
end)
