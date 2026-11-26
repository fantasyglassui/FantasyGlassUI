local _, ns = ...

------------------------------------------------------------------------------------------
-- Advice around the plan: the best reward at a hand-in, quests worth dropping from a full log,
-- and an inn when you have played a long while. Advice only: nothing here hands in, abandons or
-- travels for you. Everything is behind the guide being unlocked.
------------------------------------------------------------------------------------------
local ipairs, type, pcall, select = ipairs, type, pcall, select
local format = string.format

ns.PLANNER_LOG_SIZE = 25                -- the quest log holds this many when the game cannot say
ns.PLANNER_LOG_FREE = 3                 -- advice when this many places or fewer are free
ns.PLANNER_LOG_ADVICE = 3               -- quests named at most
ns.PLANNER_GRAY_GAP = 8                 -- a quest this many levels below you is gray (check in game)
ns.PLANNER_INN_PLAY = 3600              -- seconds of play before an inn is suggested
ns.PLANNER_INN_SECONDS = 120            -- an inn this close (seconds of travel)
ns.PLANNER_INN_SHOWN = 600              -- the inn line stays on the panel this long
ns.plannerSessionStart = GetTime and GetTime() or 0     -- (a /reload keeps the login's time: see PLAYER_ENTERING_WORLD below)

local function Num(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
local function Clean(s)
    if type(s) ~= "string" or ns:IsSecret(s) then return nil end
    s = ns.Trim((s:gsub("[|@\r\n]", " ")))
    return s ~= "" and s or nil
end
local function On(setting)
    return ns.GuideUnlocked and ns:GuideUnlocked() and ns.db and ns.db[setting] ~= false
end

------------------------------------------------------------------------------------------
-- The best reward
------------------------------------------------------------------------------------------
-- Which of the choices to take: the biggest upgrade, else the best sell price; nil when none can be judged.
function ns.PlannerBestChoice()
    local nf = _G.GetNumQuestChoices
    local ok, n = pcall(nf)
    n = ok and Num(n) or 0
    if n <= 1 then return nil end
    local bestUp, upAt, bestPrice, priceAt = 0, nil, 0, nil
    for i = 1, n do
        local okL, link = pcall(_G.GetQuestItemLink, "choice", i)
        if okL and type(link) == "string" and not ns:IsSecret(link) then
            local up = ns.UpgradeAmount and Num(ns.UpgradeAmount(link)) or nil
            if up and up > bestUp then bestUp, upAt = up, i end
            local okI, info = pcall(function() return select(11, C_Item.GetItemInfo(link)) end)
            local price = okI and Num(info) or nil
            local okC, count = pcall(function() return select(3, _G.GetQuestItemInfo("choice", i)) end)
            count = okC and Num(count) or 1
            if price and price * count > bestPrice then bestPrice, priceAt = price * count, i end
        end
    end
    return upAt or priceAt
end

local function PickReward()
    if not On("plannerPickReward") then return end
    local i = ns.PlannerBestChoice()
    if not i then return end
    local okB, button = pcall(function() return _G.QuestInfo_GetRewardButton(_G.QuestInfoFrame.rewardsFrame, i) end)
    if not (okB and button) then return end
    pcall(_G.QuestInfoItem_OnClick, button)        -- (selects it only: the hand-in itself is yours)
end

------------------------------------------------------------------------------------------
-- The quest log
------------------------------------------------------------------------------------------
-- Up to 3 { name, reason } worth dropping, when the log is nearly full or the plan needs more room than it has.
-- Gray quests are seen here; the other reasons were worked out with the plan (summary.logReasons, in the
-- planner's slices): this only counts the log and looks them up. A quest still in the plan is never named,
-- not even a gray one.
function ns.PlannerLogAdvice(steps, at, summary)
    if not On("plannerLogAdvice") then return {} end
    local QL = C_QuestLog
    if type(QL) ~= "table" or type(QL.GetNumQuestLogEntries) ~= "function" or type(QL.GetInfo) ~= "function" then return {} end
    local okN, num = pcall(QL.GetNumQuestLogEntries)
    num = okN and Num(num) or 0
    local max = ns.PLANNER_LOG_SIZE
    if type(QL.GetMaxNumQuestsCanAccept) == "function" then
        local okM, m = pcall(QL.GetMaxNumQuestsCanAccept)
        if okM and Num(m) and m > 0 then max = m end
    end
    local quests = {}
    for i = 1, num do
        local ok, info = pcall(QL.GetInfo, i)
        if ok and type(info) == "table" and not info.isHeader and Num(info.questID) then
            quests[#quests + 1] = { id = info.questID, name = Clean(info.title) or ("#" .. info.questID), level = Num(info.level) or 0 }
        end
    end
    local free = max - #quests
    steps = type(steps) == "table" and steps or {}
    at = at or 1
    local inLog = {}
    for _, q in ipairs(quests) do inLog[q.id] = true end
    -- the log along the plan: an accept takes a place, a hand-in gives one back; the peak is what must fit
    local occ, peak, planned = #quests, #quests, {}
    for i = at, #steps do
        local st = steps[i]
        if type(st) == "table" then
            if type(st.quest) == "number" then planned[st.quest] = true end
            if st.kind == "accept" and type(st.quest) == "number" and not inLog[st.quest] then
                inLog[st.quest] = true
                occ = occ + 1
                if occ > peak then peak = occ end
            elseif st.kind == "turnin" and type(st.quest) == "number" and inLog[st.quest] then
                inLog[st.quest] = nil
                occ = occ - 1
            end
        end
    end
    if not (free <= ns.PLANNER_LOG_FREE or peak > max) then return {} end
    local okL, level = pcall(UnitLevel, "player")
    level = okL and Num(level) or 1
    local reasons = type(summary) == "table" and type(summary.logReasons) == "table" and summary.logReasons or {}
    local list = {}
    for _, q in ipairs(quests) do
        local rank, reason
        if planned[q.id] then                                             -- (the planner chose to do it: never named, gray or not)
        elseif q.level > 0 and q.level <= level - ns.PLANNER_GRAY_GAP then rank, reason = 1, "gray"
        else
            local why = reasons[q.id]
            if why == "never planned" then rank, reason = 2, why elseif why == "off the route" then rank, reason = 3, why end
        end
        if rank then list[#list + 1] = { name = q.name, reason = reason, rank = rank, level = q.level, id = q.id } end
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.level ~= b.level then return a.level < b.level end
        return a.id < b.id
    end)
    local out = {}
    for i = 1, math.min(#list, ns.PLANNER_LOG_ADVICE) do out[i] = { name = list[i].name, reason = list[i].reason } end
    return out
end

------------------------------------------------------------------------------------------
-- When quests run dry
------------------------------------------------------------------------------------------
ns.PLANNER_GRIND_KILLS = 60             -- kills an hour when no measured rate is kept

local function MapName(map)
    if not (map and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, map)
    return ok and type(info) == "table" and Clean(info.name) or nil
end

-- A dungeon worth a group at this level: { name, count, xp, start } from the Questie quests filed under it
-- that you could take, or nil. Runs inside the planning coroutine (yields in plain loops only).
local function DungeonAdvice(ctx)
    local src = ctx.source
    if type(src) ~= "table" or type(src.zoneQuests) ~= "function" or type(src.quest) ~= "function" then return nil end
    local grouped = ctx.group == "all" or (ctx.group == "grouped" and ctx.inGroup == true)
    if not grouped then return nil end
    local level = ctx.level or 1
    local done = type(ctx.done) == "function" and ctx.done or function() return false end
    local onQuest = type(ctx.onQuest) == "function" and ctx.onQuest or function() return false end
    local never = type(ctx.skip) == "table" and ctx.skip or {}
    local function Done(q) return done(type(q) == "number" and math.abs(q) or q) end   -- (Questie's -id: that quest done)
    local function AllDone(list) for _, q in ipairs(type(list) == "table" and list or {}) do if not Done(q) then return false end end return true end
    local function AnyDone(list)
        if type(list) ~= "table" or #list == 0 then return true end
        for _, q in ipairs(list) do if Done(q) then return true end end
        return false
    end
    local best
    for _, d in ipairs(type(ns.PLANNER_DUNGEONS) == "table" and ns.PLANNER_DUNGEONS or {}) do
        if type(d) == "table" and tonumber(d.minLevel) and tonumber(d.maxLevel) and d.minLevel <= level and level <= d.maxLevel then
            local count, xp, maps, open = 0, 0, {}, {}
            for _, id in ipairs(src.zoneQuests(d.zone)) do
                ns.PlannerYield()
                local rec = (not done(id) and not onQuest(id) and not never[id]) and src.quest(id) or nil
                if rec and rec.doable and not rec.repeatable and (rec.minLevel or 1) <= level and AllDone(rec.pre) and AnyDone(rec.preAny) then
                    open[#open + 1] = rec
                end
            end
            local keep = ns.PlannerExclusiveKeep and ns.PlannerExclusiveKeep(open, ctx) or nil   -- (one of quests that exclude each other)
            for _, rec in ipairs(open) do
                ns.PlannerYield()
                if not keep or keep[rec.id] then
                    count, xp = count + 1, xp + (Num(rec.xp) or 0)
                    local sp = type(rec.starts) == "table" and rec.starts[1]
                    if type(sp) == "table" and sp.map then maps[sp.map] = (maps[sp.map] or 0) + 1 end
                end
            end
            if count > 0 and (not best or xp > best.xp) then
                local at, atN
                for map, n in pairs(maps) do if not atN or n > atN or (n == atN and map < at) then at, atN = map, n end end
                best = { name = Clean(d.name) or "?", count = count, xp = xp, start = MapName(at or d.map) or Clean(d.name) or "?" }
            end
        end
    end
    return best
end

-- Grinding: the best cluster of monsters 0 to 2 levels above you.
local function GrindAdvice(ctx)
    local src = ctx.source
    if type(src) ~= "table" or type(src.grindSpots) ~= "function" then return nil end
    local level = ctx.level or 1
    local spots = src.grindSpots(level)
    local spot = type(spots) == "table" and spots[1]
    if type(spot) ~= "table" or not Num(spot.count) or spot.count <= 0 then return nil end
    local kills = ns.PLANNER_GRIND_KILLS
    local d = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    if type(d) == "table" and Num(d.killsPerHour) and d.killsPerHour > 0 then kills = d.killsPerHour end
    local mob = Num(spot.mobLevel) or level
    local ratio = ns.PlannerKillRatio and ns.PlannerKillRatio(mob - level) or 1      -- (what your kills there really give)
    local xph = math.floor(kills * ns.PlannerKillXP(level, mob) * ratio + 0.5)
    if xph <= 0 then return nil end
    return { name = Clean(spot.name) or "?", zone = MapName(spot.map) or "?", xph = xph }
end

-- What to do instead, for the summary of an empty plan: { dungeon, grind, first } or nil when there is nothing.
function ns.PlannerDry(ctx)
    if not On("plannerDry") or type(ctx) ~= "table" then return nil end
    if InCombatLockdown and InCombatLockdown() then return nil end
    local dungeon, grind = DungeonAdvice(ctx), GrindAdvice(ctx)
    if not (dungeon or grind) then return nil end
    return { dungeon = dungeon, grind = grind, first = (dungeon and (not grind or dungeon.xp >= grind.xph)) and "dungeon" or "grind" }
end

local function DryLines(summary)
    local dry = type(summary) == "table" and summary.empty and type(summary.dry) == "table" and summary.dry
    if not dry or not On("plannerDry") then return {} end
    local out = {}
    local function Dungeon()
        local d = dry.dungeon
        if type(d) == "table" then out[#out + 1] = format(ns:Tr("Try %s: %d quests, start at %s"), tostring(d.name), tonumber(d.count) or 0, tostring(d.start)) end
    end
    local function Grind()
        local g = dry.grind
        if type(g) == "table" then out[#out + 1] = format(ns:Tr("Or grind %s at %s (about %s xp an hour)"), tostring(g.name), tostring(g.zone), tostring(tonumber(g.xph) or 0)) end
    end
    if dry.first == "grind" then Grind(); Dungeon() else Dungeon(); Grind() end
    return out
end

-- The panel's lines: the quest log advice, then the inn, then what to do when quests run dry.
function ns.PlannerAdviceLines(steps, at, summary)
    local lines = {}
    for _, a in ipairs(ns.PlannerLogAdvice(steps, at, summary)) do
        lines[#lines + 1] = format(ns:Tr("Worth abandoning: %s (%s)"), a.name, ns:Tr(a.reason))
    end
    local inn = ns.plannerInnLine
    if type(inn) == "table" and On("plannerInn") then
        local okT, now = pcall(GetTime)
        now = okT and Num(now) or nil
        if now and inn.t and now >= inn.t and now - inn.t <= ns.PLANNER_INN_SHOWN then lines[#lines + 1] = inn.text else ns.plannerInnLine = nil end
    end
    for _, l in ipairs(DryLines(summary)) do lines[#lines + 1] = l end
    return lines
end

------------------------------------------------------------------------------------------
-- The inn
------------------------------------------------------------------------------------------
-- Suggest a nearby inn: after an hour of play, while rested experience is not full.
-- The innkeepers are read once a session; only those on this continent within a straight line of the
-- time are asked the travel planner.
local function InnKeepers(ctx)
    if type(ns.plannerInns) ~= "table" then
        local list = {}
        for _, p in ipairs(ns.PlannerPlaces and ns.PlannerPlaces(ctx, "innkeeper") or {}) do
            ns.PlannerYield()
            local c, wx, wy = ns.PlannerWorldPos(p.map, p.x, p.y)
            if c then list[#list + 1] = { place = p, c = c, x = wx, y = wy } end
        end
        if #list > 0 then ns.plannerInns = list end
        return list
    end
    return ns.plannerInns
end
-- The cheap tests (switch, fight, time played, the line already shown, rested, resting): the time, or nil.
local function InnWanted()
    if not On("plannerInn") then return nil end
    if InCombatLockdown and InCombatLockdown() then return nil end
    local okT, now = pcall(GetTime)
    now = okT and Num(now) or nil
    if not now or now - (ns.plannerSessionStart or 0) < ns.PLANNER_INN_PLAY then return nil end
    local shown = ns.plannerInnLine
    if type(shown) == "table" and shown.t and now >= shown.t and now - shown.t < ns.PLANNER_INN_SHOWN then return nil end
    local okX, pool = pcall(GetXPExhaustion)
    pool = okX and Num(pool) or nil
    local okM, xpMax = pcall(UnitXPMax, "player")
    xpMax = okM and Num(xpMax) or nil
    if pool and xpMax and pool >= 1.5 * xpMax then return nil end        -- (as rested as you can be)
    local okR, resting = pcall(IsResting)
    if okR and resting == true then return nil end
    return now
end

-- The search itself: run as a planner job (a slice a frame, never in a fight), so opening the game menu costs nothing.
local function InnSearch()
    local now = InnWanted()
    if not now then return false end
    local ctx = ns.PlannerContext and ns.PlannerContext()
    if type(ctx) ~= "table" or type(ctx.here) ~= "table" then return false end
    local hc, hx, hy = ns.PlannerWorldPos(ctx.here.map, ctx.here.x, ctx.here.y)
    if not hc then return false end
    local reach = ns.PLANNER_INN_SECONDS * (Num(ctx.speed) or 7)
    local best, bestT
    for _, inn in ipairs(InnKeepers(ctx)) do
        ns.PlannerYield()
        local dx, dy = inn.x - hx, inn.y - hy
        if inn.c == hc and dx * dx + dy * dy <= reach * reach then
            local secs = ns.PlannerTravel(ctx.here, inn.place, ctx)
            if type(secs) == "number" and secs <= ns.PLANNER_INN_SECONDS and (not bestT or secs < bestT) then best, bestT = inn.place, secs end
        end
    end
    if not best then return false end
    local name = Clean(best.name) or Clean(best.zone) or ns:Tr("an inn")
    local text = format(ns:Tr("Log out at %s for rested experience (about %d min away)"), name, math.max(1, math.ceil(bestT / 60)))
    ns.plannerInnLine = { text = text, t = now }
    ns:Print("Log out at %s for rested experience (about %d min away)", name, math.max(1, math.ceil(bestT / 60)))
    if ns.GuidePanelShown and ns:GuidePanelShown() and ns.GuideShowPanel then ns:GuideShowPanel() end
    return true
end

-- Suggest an inn: the cheap tests now, the search as a job (true when one was queued).
function ns.PlannerInnSuggest()
    if not InnWanted() then return false end
    if not ns.PlannerJob then return InnSearch() end
    return ns.PlannerJob(InnSearch, "inn")
end

------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "QUEST_COMPLETE")
    -- (one frame later: the game's own hand-in panel resets its selection while it is drawn)
    local pick = ns:Guard("Planner reward", PickReward)
    pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Planner events", function(_, event, isInitial, isReload)
        if event == "PLAYER_ENTERING_WORLD" then
            if not (isInitial or isReload) then return end            -- (a zone change)
            local okT, now = pcall(GetTime)
            now = okT and Num(now) or nil
            if not (now and type(ns.root) == "table" and ns:GuideUnlocked()) then return end
            local was = tonumber(ns.root.plannerSessionAt)
            if isReload and not isInitial and was and was <= now then ns.plannerSessionStart = was
            else ns.root.plannerSessionAt = now; ns.plannerSessionStart = now end
            return
        end
        if C_Timer and C_Timer.After then
            local ok = pcall(C_Timer.After, 0, pick)
            if ok then return end
        end
        pick()
    end))
    if _G.GameMenuFrame and _G.GameMenuFrame.HookScript then
        pcall(_G.GameMenuFrame.HookScript, _G.GameMenuFrame, "OnShow", ns:Guard("Planner inn", function() ns.PlannerInnSuggest() end))
    end
end
