local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner: what a quest is worth (experience with kills, time, learned pace), and which quests
-- are candidates at all. Works on plain records from PlannerSource; nothing here sees Questie.
------------------------------------------------------------------------------------------
ns.PLANNER_BUDGET_MS = 4
ns.plannerBusy, ns.plannerQueued, ns.plannerSteps = false, false, 0

local running, sliceStart            -- the planning coroutine, and when its slice began

local function Clock()
    local v = debugprofilestop and debugprofilestop()
    return type(v) == "number" and v or 0
end

-- Called in the planner's loops: inside the planning coroutine it hands the frame back once this
-- slice has used its time; anywhere else it does nothing.
function ns.PlannerYield()
    if running and coroutine.running() == running and Clock() - sliceStart >= (ns.PLANNER_BUDGET_MS or 4) then
        coroutine.yield()
    end
end

local ipairs, type, tonumber, math = ipairs, type, tonumber, math
local floor, min, max, sqrt = math.floor, math.min, math.max, math.sqrt

local UNKNOWN_COUNT = 8 -- Questie gives no kill counts; the quest log does, once a quest is taken

------------------------------------------------------------------------------------------
-- Kill experience (the classic formula)
------------------------------------------------------------------------------------------
local function GrayLevel(p)
    if p <= 5 then return 0 end
    if p <= 39 then return p - floor(p / 10) - 5 end
    if p <= 59 then return p - floor(p / 5) - 1 end
    return p - 9
end

local ZD_STEPS = { { 8, 5 }, { 10, 6 }, { 12, 7 }, { 16, 8 }, { 20, 9 }, { 30, 11 }, { 40, 12 }, { 45, 13 }, { 50, 14 }, { 55, 15 }, { 60, 16 } }
local function ZeroDifference(p)
    for _, s in ipairs(ZD_STEPS) do if p < s[1] then return s[2] end end
    return 17
end

function ns.PlannerKillXP(playerLevel, mobLevel, elite)
    playerLevel, mobLevel = tonumber(playerLevel), tonumber(mobLevel)
    if not (playerLevel and mobLevel) then return 0 end
    local base = playerLevel * 5 + 45
    local xp
    if mobLevel >= playerLevel then
        xp = base * (1 + 0.05 * min(mobLevel - playerLevel, 4))
    elseif mobLevel <= GrayLevel(playerLevel) then
        return 0
    else
        xp = base * (1 - (playerLevel - mobLevel) / ZeroDifference(playerLevel))
    end
    if elite then xp = xp * 2 end
    return floor(xp)
end

------------------------------------------------------------------------------------------
-- Candidates
------------------------------------------------------------------------------------------
local function AllDone(list, done)
    for _, id in ipairs(list or {}) do if not done(id) then return false end end
    return true
end

local function AnyDone(list, done)
    if not list or #list == 0 then return true end
    for _, id in ipairs(list) do if done(id) then return true end end
    return false
end

local function NeedsGroup(rec) return (rec.elite or rec.group or rec.dungeon) and true or false end

-- list of records worth considering, skipped = { group = n } (left out only by the group setting).
function ns.PlannerCandidates(source, ctx)
    local list, skipped = {}, { group = 0 }
    if type(source) ~= "table" or type(ctx) ~= "table" then return list, skipped end
    local level, done, onQuest = ctx.level or 1, ctx.done or function() return false end, ctx.onQuest or function() return false end
    for _, id in ipairs(source.ids()) do
        ns.PlannerYield()
        local rec = source.quest(id)
        if rec then
            if onQuest(id) then
                list[#list + 1] = rec
            elseif rec.doable and not rec.repeatable and not done(id)
                and rec.level >= level - 4 and rec.level <= level + 2
                and AllDone(rec.pre, done) and AnyDone(rec.preAny, done) then
                if NeedsGroup(rec) and ctx.group ~= "all" and not (ctx.group == "grouped" and ctx.inGroup) then
                    skipped.group = skipped.group + 1
                else
                    list[#list + 1] = rec
                end
            end
        end
    end
    return list, skipped
end

------------------------------------------------------------------------------------------
-- Time
------------------------------------------------------------------------------------------
-- The farthest two spots of an objective, in yards (0 when they can't be placed).
local function Spread(spots)
    local pts = {}
    for _, s in ipairs(spots or {}) do
        local c, x, y = ns.PlannerWorldPos(s.map, s.x, s.y)
        if c then pts[#pts + 1] = { c = c, x = x, y = y } end
    end
    local far = 0
    for i = 1, #pts do
        for j = i + 1, #pts do
            if pts[i].c == pts[j].c then
                local dx, dy = pts[i].x - pts[j].x, pts[i].y - pts[j].y
                far = max(far, sqrt(dx * dx + dy * dy))
            end
        end
    end
    return far
end

local function Count(o) return o.count or UNKNOWN_COUNT end

function ns.PlannerQuestTime(rec, ctx)
    ctx = ctx or {}
    local speed = tonumber(ctx.speed) or 0
    local t = 0
    for _, o in ipairs(rec.objectives or {}) do
        if o.kind == "kill" then t = t + Count(o) * 25
        elseif o.kind == "item" then t = t + Count(o) * 25 / 0.5
        elseif o.kind == "place" then t = t + 0
        else t = t + 60 end
        if speed > 0 then t = t + Spread(o.spots) / speed end
    end
    return t * (ctx.pace or 1)
end

------------------------------------------------------------------------------------------
-- Experience
------------------------------------------------------------------------------------------
-- ctx.candidate(id) -> record, when that quest is itself a candidate (its follow-up counts half).
function ns.PlannerQuestXP(rec, ctx)
    ctx = ctx or {}
    local xp = rec.xp or 0
    local level = ctx.level or 1
    for _, o in ipairs(rec.objectives or {}) do
        if o.kind == "kill" then
            xp = xp + Count(o) * ns.PlannerKillXP(level, o.mobLevel or rec.level, rec.elite)
        end
    end
    if rec.nextQuest and ctx.candidate then
        local nxt = ctx.candidate(rec.nextQuest)
        if nxt then xp = xp + (nxt.xp or 0) / 2 end
    end
    return xp
end

------------------------------------------------------------------------------------------
-- Pace: how long you really take against the estimate (average of the last 10, 0.5 to 3)
------------------------------------------------------------------------------------------
local PACE_SAMPLES, PACE_MIN, PACE_MAX = 10, 0.5, 3

local function PaceRecord(create)
    local root = ns.root
    if not root then return nil end
    local key = ns:CharKey()
    if create then
        root.planner = root.planner or {}
        root.planner[key] = root.planner[key] or {}
        return root.planner[key]
    end
    return root.planner and root.planner[key]
end

function ns.PlannerPace()
    local rec = PaceRecord(false)
    local p = rec and rec.pace
    return type(p) == "table" and tonumber(p.value) or 1
end

function ns.PlannerRecordPace(actualSeconds, estimatedSeconds)
    actualSeconds, estimatedSeconds = tonumber(actualSeconds), tonumber(estimatedSeconds)
    if not (actualSeconds and estimatedSeconds) or actualSeconds <= 0 or estimatedSeconds <= 0 then return end
    local rec = PaceRecord(true)
    local p = type(rec.pace) == "table" and rec.pace or {}
    rec.pace = p
    p.samples = p.samples or {}
    p.samples[#p.samples + 1] = actualSeconds / estimatedSeconds
    while #p.samples > PACE_SAMPLES do table.remove(p.samples, 1) end
    local sum = 0
    for _, v in ipairs(p.samples) do sum = sum + v end
    p.value = max(PACE_MIN, min(PACE_MAX, sum / #p.samples))
end

-- The saved per-character planner record (PlannerRoute.lua keeps the bind place and the zone there).
ns.PlannerCharRecord = PaceRecord

------------------------------------------------------------------------------------------
-- Running it: a slice per frame (ns.PLANNER_BUDGET_MS), never in a fight or without a place in the
-- world, and again after each hand-in, level, lost quest, new flight point and set hearthstone.
-- The plan becomes the guide you follow (Guide.lua keeps it with your place in it).
------------------------------------------------------------------------------------------
local fighting = false
local told = {}                      -- the Questie lines, once a session each
local started = {}                   -- quest -> when its clock started (accepted, or in the log when planned)
local SOURCE_LINES = { missing = "Install Questie to plan new quests too.", changed = "Questie changed; planning from your quest log only." }

local function Following()
    local st = ns.GuideState and ns.GuideState()
    return (ns:GuideOn() and type(st) == "table" and st.name == ns.GUIDE_PLANNED) and true or false, st
end

local function Placed()
    if not ns.GuideHere then return false end
    local map, x, y = ns.GuideHere()
    return ns.PlannerWorldPos(map, x, y) ~= nil
end

-- Each planned quest's time at your usual pace of 1 (what the hand-in is measured against).
local function Estimates(guide, ctx)
    local out, src = {}, ctx.source
    for _, s in ipairs(guide.steps) do
        ns.PlannerYield()
        local id = s.quest
        if id and out[id] == nil and type(src) == "table" then
            local rec = src.quest(id)
            out[id] = rec and floor(ns.PlannerQuestTime(rec, { speed = ctx.speed }) + 0.5) or 0
        end
    end
    return out
end

-- The coroutine's body: guide, summary, ctx; nothing while Questie is still loading (it asks again).
local function Plan()
    local ctx = ns.PlannerContext()
    if ctx.sourceWhy == "waiting" then return nil end
    local line = SOURCE_LINES[ctx.sourceWhy]
    if line and not told[ctx.sourceWhy] then
        told[ctx.sourceWhy] = true
        ns:Print(line)
    end
    local guide, summary = ns.PlannerRoute(ctx)
    guide.estimates = Estimates(guide, ctx)
    return guide, summary, ctx
end

local function Apply(guide, summary, ctx)
    local now = GetTime()
    for id in pairs(guide.estimates) do
        if not started[id] and ctx.onQuest(id) then started[id] = now end
    end
    if summary.newZone and summary.zone then ns.PlannerSetZone(summary.zone, ctx.level) end
    ns:GuideSetPlan(guide, summary)
end

local function Tick()
    if not (ns.plannerBusy or ns.plannerQueued) then return end
    if not Following() then ns:PlannerStop(); return end
    if fighting or InCombatLockdown() or not Placed() then return end
    if not running then
        ns.plannerQueued, ns.plannerBusy = false, true
        running = coroutine.create(Plan)
    end
    sliceStart = Clock()
    ns.plannerSteps = ns.plannerSteps + 1
    local ok, guide, summary, ctx = coroutine.resume(running)
    if ok and coroutine.status(running) ~= "dead" then return end
    running, ns.plannerBusy = nil, false
    if not ok then error(guide, 0) end
    if guide then Apply(guide, summary, ctx) end
end
ns:Every(0, "Planner", Tick)

-- Plan again (soon, a slice at a time). `reason` is only for debugging.
function ns:PlannerReplan(reason)
    if not Following() then return false end
    ns.plannerQueued, ns.plannerReason = true, reason
    return true
end

-- Follow the planned route, and plan it (again).
function ns:PlannerStart()
    if not ns:GuideOn() then return false end
    if not Following() then ns:GuideSetPlan(nil) end
    ns:GuideShowPanel()
    ns.plannerQueued, ns.plannerReason = true, "start"
    return true
end

function ns:PlannerStop()
    running, ns.plannerBusy, ns.plannerQueued = nil, false, false
end

do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP", "HEARTHSTONE_BOUND",
                         "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Planner", function(_, event, a, b)
        if event == "PLAYER_REGEN_DISABLED" then fighting = true; return end
        if event == "PLAYER_REGEN_ENABLED" then fighting = false; return end
        local on, st = Following()
        if not on then return end
        local plan = type(st.plan) == "table" and st.plan or {}
        local est = type(plan.estimates) == "table" and plan.estimates or {}
        if event == "QUEST_ACCEPTED" then
            local id = (type(b) == "number") and b or a
            if type(id) == "number" and est[id] and not started[id] then started[id] = GetTime() end
        elseif event == "QUEST_TURNED_IN" then
            if type(a) == "number" then
                if started[a] and est[a] then ns.PlannerRecordPace(GetTime() - started[a], est[a]) end
                started[a] = nil
            end
            ns:PlannerReplan("hand-in")
        elseif event == "HEARTHSTONE_BOUND" then
            local step = type(plan.steps) == "table" and plan.steps[st.at or 1]
            if type(step) == "table" and step.kind == "bind" then ns:GuideSkip(false) end   -- (bound by place, not by the innkeeper's name)
            ns:PlannerReplan("bind")
        elseif event == "PLAYER_LEVEL_UP" then
            ns:PlannerReplan("level")
        else
            ns:PlannerReplan("quest removed")
        end
    end))
end
