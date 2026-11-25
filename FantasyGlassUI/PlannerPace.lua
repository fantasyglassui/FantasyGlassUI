local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner, batch 4 group C: the time you have, break reminders, catch me up, speed or story (Tasks 5 and 6).
-- Built on the seams: ns.PlannerHook (Planner.lua), the panel's registries (Guide.lua) and its
-- section of the Guide tab (Bars.lua). Everything here is behind ns:GuideUnlocked(): the hooks
-- and the panel's entries are only registered while the guide is unlocked (ns.PlannerPaceSync),
-- and a planner hook only while its feature is in use, so a plan that uses neither is unchanged.
------------------------------------------------------------------------------------------
local format, floor, min, max = string.format, math.floor, math.min, math.max
local ipairs, type, tonumber, tostring = ipairs, type, tonumber, tostring

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function On() return Unlocked() and ns.GuideOn ~= nil and ns:GuideOn() == true end
local function Rec(create) return ns.PlannerCharRecord and ns.PlannerCharRecord(create) or nil end
local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
local function Now()
    local ok, t = pcall(time)
    return ok and Num(t) or 0
end
local function Uptime()
    local ok, t = pcall(GetTime)
    return ok and Num(t) or nil
end
local function Fighting() return InCombatLockdown ~= nil and InCombatLockdown() == true end
local function Replan(why) if ns.PlannerReplan then ns:PlannerReplan(why) end end
local function R1(v) return floor(v * 10 + 0.5) / 10 end
local function Plain(s)
    if type(s) ~= "string" or ns:IsSecret(s) then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    return s ~= "" and s or nil
end

ns.PLANNER_PLAY_HORIZON = 6                 -- hubs a plan may take while you have a time limit (the lead-in counts)
ns.PLANNER_STOP_SECONDS = 300               -- the stop place is at most this far (or what time is left, if less)
ns.PLANNER_BREAK_REPEAT = 3600              -- a break reminder at most once in this many seconds
ns.PLANNER_BREAK_SHOWN = 600                -- and its panel line for this long
ns.PLANNER_CATCHUP_DAYS = 14                -- away this many days or more: the catch-up page
ns.PLANNER_CATCHUP_NEW = 3                  -- at most this many "New:" lines
ns.PLANNER_PLAY_TIMES = { { 0, "No limit" }, { 30, "30 min" }, { 60, "1 hour" }, { 90, "1 hour 30" }, { 120, "2 hours" } }
local STOP_KEY = "pace:stop"
local Sync                                  -- (below: what is registered)

------------------------------------------------------------------------------------------
-- The time you have
------------------------------------------------------------------------------------------
-- Minutes you can play (0 clears): a deadline per character, in time() seconds.
function ns.PlannerSetPlayTime(minutes)
    minutes = tonumber(minutes)
    if not minutes or minutes <= 0 then
        local rec = Rec(false)
        if rec then rec.playUntil = nil end
    else
        local rec = Rec(true)
        if rec then rec.playUntil = Now() + min(minutes, 600) * 60 end
    end
    Sync()
end

-- Seconds left of the time you can play, 0 when it is up; nil with no limit.
function ns.PlannerTimeLeft()
    local rec = Rec(false)
    local deadline = rec and tonumber(rec.playUntil)
    if not deadline then return nil end
    return max(0, deadline - Now())
end

-- "context": with a deadline the plan has the time left and a horizon of 6 hubs.
local function ContextTime(ctx)
    if not Unlocked() then return end
    local rec = Rec(false)
    local deadline = rec and tonumber(rec.playUntil)
    if deadline and Now() - deadline > 3600 then     -- (a limit that ran out long ago, never ticked off: forgotten)
        rec.playUntil = nil
        return
    end
    local left = ns.PlannerTimeLeft()
    if left then ctx.timeLeft, ctx.horizon = left, ns.PLANNER_PLAY_HORIZON end
end

-- "rank": a hub (the lead-in too) that does not fit in what is left is out. A cut, or the horizon, ends the plan with a stop.
local function RankTime(ranked, c, info)
    local left = tonumber(c.timeLeft)
    if not left then return end
    if info.round == info.horizon then c.timeCut = true end
    for _, e in ipairs(ranked) do
        ns.PlannerYield()
        if (tonumber(e.score) or -1) >= 0 and (tonumber(e.rate) or -1) >= 0 then
            local hub = e.hub
            local need = (tonumber(info.seconds) or 0) + (tonumber(e.travel) or 0) + (type(hub) == "table" and tonumber(hub.seconds) or 0)
            if need > left then e.score, c.timeCut = -1, true end
        end
    end
end

-- Where you stand when the plan ends: its last step with a place, else where you are.
local function PlanEnd(guide, ctx)
    for i = #guide.steps, 1, -1 do
        local s = guide.steps[i]
        if type(s) == "table" and s.map and s.x and s.y then return { map = s.map, x = s.x, y = s.y } end
    end
    local h = ctx.here
    if type(h) == "table" and h.map and h.x and h.y then return h end
    return nil
end

-- The nearest innkeeper or known flight point reachable within `limit` seconds, or nil.
local function StopPlace(c, from, limit)
    if not from or limit <= 0 or not (ns.PlannerWorldPos and ns.PlannerTravel) then return nil end
    local fc, fx, fy = ns.PlannerWorldPos(from.map, from.x, from.y)
    local list = {}
    local function Add(p, name)
        local pc, px, py = ns.PlannerWorldPos(p.map, p.x, p.y)
        if pc and (not fc or pc == fc) then
            local dx, dy = (px or 0) - (fx or 0), (py or 0) - (fy or 0)
            list[#list + 1] = { place = p, name = name, d = dx * dx + dy * dy }
        end
    end
    if ns.PlannerPlaces then
        for _, p in ipairs(ns.PlannerPlaces(c, "innkeeper")) do ns.PlannerYield(); Add(p, Plain(p.name)) end
    end
    for _, f in ipairs(type(c.flights) == "table" and c.flights or {}) do
        ns.PlannerYield()
        if type(f) == "table" and f.known and tonumber(f.map) and tonumber(f.x) and tonumber(f.y) then Add(f, Plain(f.name)) end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local best, bestT
    for i = 1, min(8, #list) do
        ns.PlannerYield()
        local t = ns.PlannerTravel(from, list[i].place, c)
        if type(t) == "number" and t <= limit and (not bestT or t < bestT) then best, bestT = list[i], t end
    end
    return best
end

-- "route": a plan cut by the time (or one with no time left) ends at the nearest place to stop, and a note.
local function RouteTime(guide, summary, ctx, c)
    local left = tonumber(c.timeLeft or ctx.timeLeft)
    if not left or not (c.timeCut or left <= 0) then return end
    for _, s in ipairs(guide.steps) do if s.stopKey == STOP_KEY then return end end
    local limit = left <= 0 and ns.PLANNER_STOP_SECONDS or min(ns.PLANNER_STOP_SECONDS, left - (tonumber(summary.seconds) or 0))
    local at = StopPlace(c, PlanEnd(guide, ctx), limit)
    if at then
        local p = at.place
        guide.steps[#guide.steps + 1] = { kind = "goto", text = at.name, map = p.map, x = R1(p.x), y = R1(p.y), stopKey = STOP_KEY }
    end
    guide.steps[#guide.steps + 1] = { kind = "note", text = ns:Tr("Good place to stop"), stopKey = STOP_KEY }
    summary.stop = true
end

-- Advance: the note "Good place to stop" done: the time limit is over.
local function AdvanceStop(st, guide, _, at, moved)
    if not moved or not Unlocked() or type(st) ~= "table" or st.name ~= ns.GUIDE_PLANNED or type(guide) ~= "table" then return end
    for i, s in ipairs(guide.steps or {}) do
        if type(s) == "table" and s.kind == "note" and s.stopKey == STOP_KEY then
            if (tonumber(at) or 0) > i then ns.PlannerSetPlayTime(0) end
            return
        end
    end
end

-- /fgui guide plan [minutes]: a number sets the time (0 clears it), none uses the default; then plan.
function ns.PlannerPlanCommand(rest)
    local n = tonumber(tostring(rest or ""):match("^%s*(%d+)"))
    if n then
        ns.PlannerSetPlayTime(n)
    else
        local rec = Rec(false)
        local d = rec and tonumber(rec.playDefault)
        if d and d > 0 then ns.PlannerSetPlayTime(d) end
    end
    return ns.PlannerStart ~= nil and ns:PlannerStart()
end

-- The panel's "How long can you play?": a list to pick from.
local function OpenTimeList()
    local w
    local lines = {}
    for _, t in ipairs(ns.PLANNER_PLAY_TIMES) do
        lines[#lines + 1] = { left = ns:Tr(t[2]), click = function()
            ns.PlannerSetPlayTime(t[1])
            Replan("time")
            if w and w.Hide then w:Hide() end
        end }
    end
    w = ns:ShowList("PlanTime", "How long can you play?", lines, nil, 300, 200)
    return w
end

------------------------------------------------------------------------------------------
-- A stopping place, and break reminders
------------------------------------------------------------------------------------------
-- Is `at` a good place to stop: the first step of a new hub after a hand-in, right after a flight, boat,
-- hearthstone or bind, or the end of the plan.
function ns.PlannerStoppingPlace(steps, at)
    if type(steps) ~= "table" then return false end
    at = tonumber(at) or 1
    if at > #steps then return true end
    if at <= 1 then return false end
    local prev, cur = steps[at - 1], steps[at]
    if type(prev) ~= "table" or type(cur) ~= "table" then return false end
    local k = prev.kind
    if k == "fly" or k == "sail" or k == "hearth" or k == "bind" then return true end
    return k == "turnin" and prev.hub ~= cur.hub
end

local lastBreak, breakLine                   -- (uptime of the last reminder; its text, for the panel)
local function PlayedText(seconds)
    local h, m = floor(seconds / 3600), floor(seconds % 3600 / 60)
    if h > 0 then return format(ns:Tr("%d h %d min"), h, m) end
    return format(ns:Tr("%d min"), m)
end

local function AdvanceBreak(st, guide, _, at, moved)
    if not moved or type(st) ~= "table" or st.name ~= ns.GUIDE_PLANNED or not On() then return end
    if not (ns.db and ns.db.plannerBreaks == true) or Fighting() then return end
    local now = Uptime()
    if not now then return end
    local played = now - (tonumber(ns.plannerSessionStart) or now)
    if played < (tonumber(ns.db.plannerBreakMinutes) or 120) * 60 then return end
    if lastBreak and now >= lastBreak and now - lastBreak < ns.PLANNER_BREAK_REPEAT then return end
    if not ns.PlannerStoppingPlace(type(guide) == "table" and guide.steps or nil, at) then return end
    lastBreak = now
    local text = PlayedText(played)
    breakLine = { t = now, text = text }
    ns:Print("You've been playing %s; this is a good place to stop", text)
    if ns.GuideRedraw then ns:GuideRedraw() end
end

local function BreakLine()
    local b = breakLine
    if not b or not On() then return nil end
    local now = Uptime()
    if not now or now < b.t or now - b.t > ns.PLANNER_BREAK_SHOWN then breakLine = nil; return nil end
    return format(ns:Tr("You've been playing %s; this is a good place to stop"), b.text)
end
function ns.PlannerBreakReset() lastBreak, breakLine = nil, nil end

------------------------------------------------------------------------------------------
-- Catch me up
------------------------------------------------------------------------------------------
local entered = false                        -- (the login's own handling is done: the clock may be saved from now on)

local function VersionNumber(v)
    local a, b, c = tostring(v or ""):match("^(%d+)%.?(%d*)%.?(%d*)")
    return (tonumber(a) or 0) * 10000 + (tonumber(b) or 0) * 100 + (tonumber(c) or 0)
end

-- Remember when you were last here, and which version it was (every minute, and at logout).
function ns.PlannerSeenSave()
    if not entered or not On() then return end
    local rec = Rec(true)
    if rec then rec.lastSeen, rec.lastVersion = Now(), ns.version end
end

local function ZoneName(map)
    local get = C_Map and C_Map.GetMapInfo
    if type(get) ~= "function" or type(map) ~= "number" then return nil end
    local ok, info = pcall(get, map)
    return ok and type(info) == "table" and Plain(info.name) or nil
end

-- The page: how long you were away, where you were, what is in your log, how you play, what is new.
function ns:PlannerCatchUp(away, since)
    local rec = Rec(false)
    away = tonumber(away) or (rec and tonumber(rec.lastSeen) and Now() - rec.lastSeen) or 0
    since = since or (rec and rec.lastVersion)
    local lines = {}
    lines[#lines + 1] = { left = format(ns:Tr("Away for %d days"), floor(away / 86400)) }
    local st = ns.GuideState and ns.GuideState()
    local steps = type(st) == "table" and st.name == ns.GUIDE_PLANNED and type(st.plan) == "table" and st.plan.steps or nil
    if steps then
        local step = steps[tonumber(st.at) or 1]
        local where = {}
        local zone = ZoneName(type(st.summary) == "table" and st.summary.zone or nil)
        if zone then where[#where + 1] = zone end
        if type(step) == "table" and ns.GuideStepBase then
            local ok, text = pcall(ns.GuideStepBase, step)
            if ok and Plain(text) then where[#where + 1] = Plain(text) end
        end
        if #where > 0 then lines[#lines + 1] = { left = format(ns:Tr("You were at: %s"), table.concat(where, ", ")) } end
    end
    local QL = C_QuestLog or {}
    local okN, _, inLog = pcall(QL.GetNumQuestLogEntries or function() return 0, 0 end)
    inLog = okN and Num(inLog) or 0
    local inPlan, seen = 0, {}
    for _, s in ipairs(steps or {}) do
        local id = type(s) == "table" and s.quest
        if id and not seen[id] then
            seen[id] = true
            local okQ, on = pcall(QL.IsOnQuest or function() return false end, id)
            if okQ and on == true then inPlan = inPlan + 1 end
        end
    end
    lines[#lines + 1] = { left = format(ns:Tr("%d quests in your log, %d of them in the plan"), inLog, inPlan) }
    local okL, level = pcall(UnitLevel, "player")
    level = okL and Num(level) or 1
    local pace = ns.PlannerPace and ns.PlannerPace() or 1
    lines[#lines + 1] = { left = format(ns:Tr("Level %d, pace %.1f× the estimate"), level, pace) }
    local before, shown = VersionNumber(since), 0
    for i, entry in ipairs(type(ns.whatsNew) == "table" and ns.whatsNew or {}) do
        local newer = since == nil and i == 1 or (since ~= nil and VersionNumber(entry[1]) > before)
        if newer and shown < ns.PLANNER_CATCHUP_NEW and type(entry[2]) == "table" and entry[2][1] then
            shown = shown + 1
            lines[#lines + 1] = { left = format(ns:Tr("New: %s"), ns:Tr(entry[2][1])) }
        end
    end
    local w
    lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Plan my route") .. "|r", click = function()
        if w and w.Hide then w:Hide() end
        if ns.PlannerStart then ns:PlannerStart() end
    end }
    w = ns:ShowList("PlanCatchUp", "Catch me up", lines, nil, 460, 240)
    return w
end

-- Events: a login (never a reload) after 14 days or more away; the clock kept every minute and at logout.
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
    pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
    pcall(ev.RegisterEvent, ev, "PLAYER_LOGOUT")
    ev:SetScript("OnEvent", ns:Guard("Planner pace", function(_, event, isInitial)
        if event == "PLAYER_LOGOUT" then ns.PlannerSeenSave(); return end
        if event == "PLAYER_LOGIN" then Sync(); return end        -- (what is registered: the panel's entries, and the hooks of a limit or a style in use)
        if event ~= "PLAYER_ENTERING_WORLD" then return end
        if not (type(ns.root) == "table" and Unlocked()) then return end
        if isInitial and On() then
            local rec = Rec(false)
            local was = rec and tonumber(rec.lastSeen)
            local away = was and Now() - was
            if away and away >= ns.PLANNER_CATCHUP_DAYS * 86400 then ns:PlannerCatchUp(away, rec.lastVersion) end
        end
        entered = true
        ns.PlannerSeenSave()
    end))
    ns:Every(60, "Planner seen", function()
        if entered then ns.PlannerSeenSave() end
        if type(ns.root) == "table" then Sync() end
    end)
end

------------------------------------------------------------------------------------------
-- What is registered: with the guide unlocked, the panel's entries; a planner hook only while its feature is in use.
------------------------------------------------------------------------------------------
ns.PlannerPaceHooks = { time = { context = ContextTime, rank = RankTime, route = RouteTime } }
Sync = function()
    local open = Unlocked()
    local function Reg(fn) return open and fn or nil end
    ns.GuideRegisterCommand("plan", Reg(ns.PlannerPlanCommand))
    ns.GuideRegisterAdvance("paceStop", Reg(AdvanceStop))
    ns.GuideRegisterAdvance("paceBreak", Reg(AdvanceBreak))
    ns.GuideRegisterLine("paceBreak", Reg(BreakLine))
    ns.GuideRegisterAction("panel", "paceTime", "How long can you play?", Reg(OpenTimeList))
    local rec = open and Rec(false) or nil
    local timed = rec and tonumber(rec.playUntil) and true or false
    local h = ns.PlannerPaceHooks.time
    ns.PlannerHook("context", "paceTime", timed and h.context or nil)
    ns.PlannerHook("rank", "paceTime", timed and h.rank or nil)
    ns.PlannerHook("route", "paceTime", timed and h.route or nil)
end
ns.PlannerPaceSync = function() Sync() end
