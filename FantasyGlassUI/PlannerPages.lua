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
    return max(least or 0, floor((tonumber(seconds) or 0) / 60 + 0.5))
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
        if hub.lead or (rate and beatRate and beatRate >= rate) then
            Add(ns:Tr("Taken first"), "")                       -- (a lead-in, or put first: nothing it beat)
        elseif rate and beatRate and beatRate > 0 and type(beat.name) == "string" then
            Add(format(ns:Tr("Beat %s at %s an hour (%d%% better)"), beat.name, Big(beatRate * 3600), floor((rate / beatRate - 1) * 100)), "")
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
    local n = type(summary.skipped) == "table" and tonumber(summary.skipped.group) or 0
    if n > 0 then
        local solo = ns.db == nil or ns.db.plannerGroup == nil or ns.db.plannerGroup == "solo"
        lines[#lines + 1] = { left = format(ns:Tr(solo and "Skipped: %d group quests (Solo is on)" or "Skipped: %d group quests"), n) }
    end
    local moved = tonumber(summary.moved)
    if moved then lines[#lines + 1] = { left = format(ns:Tr("Moved: you died twice here (back at level %d)"), moved) } end
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
    local ok, err = pcall(ShowPreview, guide, summary)
    if not ok and type(ns.errors) == "table" and #ns.errors < 60 then ns.errors[#ns.errors + 1] = "Planner preview: " .. tostring(err) end
end)
