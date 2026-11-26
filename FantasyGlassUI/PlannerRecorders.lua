local _, ns = ...

------------------------------------------------------------------------------------------
-- The planner's recorders, in the main add-on (the folders plan's group A): what the planner learns
-- as you play, kept while its folder (FantasyGlassUI_Planner) is not loaded. Each was moved here from its
-- folder file as it was, with the same saved keys: the per-character record, the kill formula PlannerKills.lua
-- needs, quest times, soloed elites, deaths, trainer visits and riding, the reward pick, the session start,
-- gathering nodes, places used, timed quests, the bind place, the level clock, when you were last here (and
-- the catch-up page it may call for), and the duo's prefix with a friend's ask handed over to the folder.
-- Everything here records nothing while the guide is locked.
------------------------------------------------------------------------------------------
local ipairs, pairs, type, tonumber, math, pcall, select = ipairs, pairs, type, tonumber, math, pcall, select
local floor, min, max, sqrt = math.floor, math.min, math.max, math.sqrt
local format = string.format

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end

------------------------------------------------------------------------------------------
-- The per-character record (Planner.lua): ns.root.planner[charKey]
------------------------------------------------------------------------------------------
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

-- The saved per-character planner record (PlannerRoute.lua keeps the bind place and the zone there).
ns.PlannerCharRecord = PaceRecord

------------------------------------------------------------------------------------------
-- Kill experience (the classic formula; Planner.lua): PlannerKills.lua needs it while the folder is not loaded
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
-- Quest times (Planner.lua)
------------------------------------------------------------------------------------------
-- A sample of how long a quest took from accept to hand-in (while following the plan); over 2 hours is away.
local QUEST_TIME_MAX = 7200
-- At most this many quests are remembered (per account): past it, the one seen longest ago goes first (an
-- entry from before days were kept counts as oldest; the same day: the lower id).
ns.PLANNER_QUEST_TIMES_CAP = 3000
local questTimesN                    -- how many entries the table holds (counted once a session)
function ns.PlannerRecordQuestTime(questID, seconds)
    seconds = tonumber(seconds)
    if type(questID) ~= "number" or not seconds or seconds <= 0 or seconds > QUEST_TIME_MAX or not ns.root then return end
    local root = ns.root
    if type(root.plannerQuestTimes) ~= "table" then root.plannerQuestTimes = {} end
    local times = root.plannerQuestTimes
    if not questTimesN or questTimesN.t ~= times then
        local count = 0
        for _ in pairs(times) do count = count + 1 end
        questTimesN = { t = times, n = count }
    end
    local okT, now = pcall(time)
    local day = okT and type(now) == "number" and not ns:IsSecret(now) and floor(now / 86400) or 0
    local e = times[questID]
    if type(e) ~= "table" or not tonumber(e.n) or not tonumber(e.avg) then
        if times[questID] == nil then questTimesN.n = questTimesN.n + 1 end
        e = { n = 0, avg = 0 }
        times[questID] = e
    end
    e.avg = (e.avg * e.n + seconds) / (e.n + 1)
    e.n = e.n + 1
    e.seen = day
    while questTimesN.n > ns.PLANNER_QUEST_TIMES_CAP do
        local old, oldDay
        for k, v in pairs(times) do
            local d = type(v) == "table" and tonumber(v.seen) or 0
            if k ~= questID and (not old or d < oldDay or (d == oldDay and tonumber(k) and tonumber(old) and k < old)) then old, oldDay = k, d end
        end
        if old == nil then break end
        times[old] = nil
        questTimesN.n = questTimesN.n - 1
    end
end

------------------------------------------------------------------------------------------
-- Elites your class has soloed, and deaths (Planner.lua)
------------------------------------------------------------------------------------------
local DEATHS_MAX = 50

-- Where you died: remembered per character (the last 50), with the level you were.
function ns.PlannerRecordDeath()
    local level = UnitLevel and UnitLevel("player")
    if type(level) ~= "number" or ns:IsSecret(level) or not ns.GuideHere then return end
    local map, x, y = ns.GuideHere()
    if not (map and x and y and ns.PlannerWorldPos(map, x, y)) then return end        -- (no place in the outdoor world: a dungeon or a battleground)
    local rec = ns.PlannerCharRecord(true)
    if not rec then return end
    if type(rec.deaths) ~= "table" then rec.deaths = {} end
    rec.deaths[#rec.deaths + 1] = { level = level, map = map, x = x, y = y }
    while #rec.deaths > DEATHS_MAX do table.remove(rec.deaths, 1) end
end

-- The class token of this character ("WARRIOR"), or nil.
function ns.PlannerClassToken()
    local ok, c = pcall(function() return (UnitClassBase and UnitClassBase("player")) or select(2, UnitClass("player")) end)
    if ok and type(c) == "string" and not ns:IsSecret(c) and c ~= "" then return c end
end

-- An elite quest handed in alone: remember, per class, the biggest quest level over yours.
function ns.PlannerRecordSoloElite(class, diff)
    diff = tonumber(diff)
    if type(class) ~= "string" or not diff or not ns.root then return end
    if type(ns.root.plannerSoloElites) ~= "table" then ns.root.plannerSoloElites = {} end
    local t = ns.root.plannerSoloElites
    if type(t[class]) ~= "number" or t[class] < diff then t[class] = diff end
end

------------------------------------------------------------------------------------------
-- Trainer visits (Planner.lua) and being seen mounted (PlannerStops.lua)
------------------------------------------------------------------------------------------
-- The level of your last class trainer visit. The trainer whose window opened is yours when it is no
-- profession trainer and, where your class trainers are known, it is one of them (by its id, or
-- standing within 10 yards of one); with none known, any trainer but a profession one counts.
-- (While the planner's folder is not loaded no class trainers are known: any trainer but a profession one counts.)
local CLASS_TRAINER_YARDS = 10
local classTrainer = false
local ridingTrainer = false
local function IsClassTrainer()
    ridingTrainer = false
    local ok, trade = pcall(IsTradeskillTrainer)
    if ok and ns.Is(trade, true) then return false end
    local src = ns.PlannerSource and ns.PlannerSource() or nil
    local places = (src and ns.PlannerPlaces) and ns.PlannerPlaces({ source = src }, "classTrainer") or {}
    local riding = (src and ns.PlannerPlaces) and ns.PlannerPlaces({ source = src }, "professionTrainer", ns.PLANNER_RIDING_LINE or 762) or {}
    if #places == 0 and #riding == 0 then return true end
    local okG, guid = pcall(UnitGUID, "npc")
    local id = okG and type(guid) == "string" and not ns:IsSecret(guid) and tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")) or nil
    local c, x, y
    if ns.GuideHere then
        local map, px, py = ns.GuideHere()
        c, x, y = ns.PlannerWorldPos(map, px, py)
    end
    local function At(list, byId)
        for _, p in ipairs(list) do
            if id and p.id == id then return true end
            if not byId then
                local pc, ppx, ppy = ns.PlannerWorldPos(p.map, p.x, p.y)
                if c and pc == c and sqrt((ppx - x) ^ 2 + (ppy - y) ^ 2) <= CLASS_TRAINER_YARDS then return true end
            end
        end
        return false
    end
    if At(places, true) then return true end          -- (a class trainer by its id, even next to the riding trainer)
    if At(riding) then ridingTrainer = true; return false end   -- (the riding trainer is no class trainer)
    if #places == 0 then return true end
    return At(places)
end
local function TrainerClosed()
    if ridingTrainer and ns:GuideUnlocked() then           -- (you were at the riding trainer: you ride from now on)
        local r = PaceRecord(true)
        if r then r.ridingKnown = true end
    end
    ridingTrainer = false                                  -- (once per visit: a second close sets nothing again)
    if not classTrainer or not ns:GuideUnlocked() then return end
    local level = UnitLevel and UnitLevel("player")
    if type(level) ~= "number" or ns:IsSecret(level) then return end
    local d = PaceRecord(true)
    if d then d.trainerLevel = level end
end

-- Have you been seen mounted (you have a mount)? true / false, or nil when the game can't say. Once
-- seen it is kept for the character (and so is riding).
function ns.PlannerMountSeen()
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    if type(rec) == "table" and rec.mountSeen then return true end
    if type(IsMounted) ~= "function" then return nil end
    local ok, v = pcall(IsMounted)
    if not (ok and type(v) == "boolean" and not ns:IsSecret(v)) then return nil end
    if v then
        local r = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
        if type(r) == "table" then r.mountSeen, r.ridingKnown = true, true end
    end
    return v
end

-- Following the planned guide (as Planner.lua asks it): quest times are taken only then.
local function Following()
    if not ns:GuideOn() then return false, nil end           -- (asked first: a locked character's state is never read, so never made)
    local st = ns.GuideState and ns.GuideState()
    return (type(st) == "table" and st.name == ns.GUIDE_PLANNED) and true or false, st
end

-- An elite quest in your log, and its level (what the quest log says, as PlannerSource.lua's log source reads it).
local function LogNum(v) if type(v) == "number" and not ns:IsSecret(v) then return v end end
local function LoggedQuest(id)
    local QL = C_QuestLog
    if not (QL and QL.GetLogIndexForQuestID) then return nil end
    local okI, index = pcall(QL.GetLogIndexForQuestID, id)
    index = okI and LogNum(index)
    if not index then return nil end
    local info
    if QL.GetInfo then
        local ok, v = pcall(QL.GetInfo, index)
        info = ok and type(v) == "table" and v or nil
    end
    local tag
    if QL.GetQuestTagInfo then
        local ok, v = pcall(QL.GetQuestTagInfo, id)
        tag = ok and type(v) == "table" and v or nil
    end
    return { level = info and LogNum(info.questLevel) or 1, elite = tag and ns.Yes(tag.isElite) or false }
end

do
    local ev = CreateFrame("Frame")
    -- Quest times: each quest accepted while following gathers its share of the time that passes, the
    -- time split evenly among the quests open at once (a hub's quests are done together). Memory only.
    -- (a quest carried longer than a sample may be, 2 hours, gives none and stops taking a share)
    -- Time passes for them only while you are present and out of town: not AFK and not resting (each
    -- readable; a hidden flag counts as present). The state is read at login and at an unlock (you may
    -- log in at an inn), then PLAYER_FLAGS_CHANGED and PLAYER_UPDATE_RESTING share out the time so far
    -- and set the new state.
    local open, openN, openAt, since = {}, 0, nil, {}  -- questID -> seconds so far; how many; the last time shared out; accepted at
    local away = false
    local function Flag(fn, ...)
        if type(fn) ~= "function" then return false end
        local ok, v = pcall(fn, ...)
        return ok and not ns:IsSecret(v) and v == true
    end
    local function Away() return Flag(UnitIsAFK, "player") or Flag(IsResting) end
    local function Share(now)
        for id, t0 in pairs(since) do
            if t0 > now or now - t0 > QUEST_TIME_MAX then
                if open[id] then open[id], openN = nil, openN - 1 end
                since[id] = nil
            end
        end
        if openN == 0 then openAt = nil end
        if openAt and openN > 0 and now > openAt and not away then
            local part = (now - openAt) / openN
            for id, t in pairs(open) do open[id] = t + part end
        end
        openAt = now
    end
    local function Close(id, now)
        Share(now)
        local t = open[id]
        if t then open[id], openN = nil, openN - 1 end
        since[id] = nil
        if openN == 0 then openAt = nil end
        return t
    end
    -- Forever can send QUEST_REMOVED before QUEST_TURNED_IN (or no QUEST_TURNED_IN at all); a quest handed in
    -- is flagged completed by then, an abandoned one is not.
    local function Completed(id)
        local QL = C_QuestLog
        if type(QL) ~= "table" or type(QL.IsQuestFlaggedCompleted) ~= "function" then return false end
        local ok, v = pcall(QL.IsQuestFlaggedCompleted, id)
        return ok and ns.Is(v, true)
    end
    local function Now()
        local okT, now = pcall(GetTime)
        if okT and type(now) == "number" and not ns:IsSecret(now) then return now end
    end
    ns.PlannerQuestClock = function() return { open = openN, away = away } end    -- (read only: the tests)
    local function ReadAway()
        local now = Now()
        if now then Share(now) end
        away = Away()
    end
    ns.GuideRegisterLock("questclock", function(unlocked) if unlocked then ReadAway() end end)
    -- A QUEST_REMOVED of a quest not (yet) flagged completed: abandoned, unless QUEST_TURNED_IN for it follows
    -- within a second (then it was a hand-in, counted once). questID -> { t, level = a soloed elite's, took = its time }.
    local removed = {}
    local function Removed(id, now)
        for k, e in pairs(removed) do
            if now and (e.t > now or now - e.t > 600) then removed[k] = nil end
        end
        local e = removed[id] or {}
        e.t = now or 0
        removed[id] = e
        return e
    end
    local function JustRemoved(id, now)
        local e = removed[id]
        removed[id] = nil
        if e and now and now >= e.t and now - e.t <= 1 then return e end
    end
    -- elite questID -> its quest level, accepted while not in a group: kept per character, so a /reload
    -- or a new session in between still counts (cleared at hand-in or when the quest leaves the log)
    local function SoloAt(create)
        local r = ns.PlannerCharRecord(create)
        if type(r) ~= "table" then return nil end
        if type(r.soloAt) ~= "table" then
            if not create then return nil end
            r.soloAt = {}
        end
        return r.soloAt
    end
    for _, e in ipairs({ "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "TRAINER_SHOW", "TRAINER_CLOSED",
                         "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_DEAD", "PLAYER_FLAGS_CHANGED", "PLAYER_UPDATE_RESTING", "PLAYER_LOGIN" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Planner", function(_, event, a, b)
        if event == "PLAYER_FLAGS_CHANGED" or event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_LOGIN" then   -- (away or in town: the quest clock stops)
            if (event == "PLAYER_FLAGS_CHANGED" and a ~= "player") or not ns:GuideUnlocked() then return end
            ReadAway()
            return
        end
        if event == "TRAINER_SHOW" then               -- (a locked guide: nothing is looked up)
            classTrainer, ridingTrainer = false, false
            if ns:GuideUnlocked() then classTrainer = IsClassTrainer() == true end
            return
        end
        if event == "TRAINER_CLOSED" then TrainerClosed(); return end
        if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then          -- (seen mounted: you have a mount and ride; kept for the character)
            if ns:GuideUnlocked() and ns.PlannerMountSeen then ns.PlannerMountSeen() end
            return
        end
        if event == "PLAYER_DEAD" then                -- (where you died: a hub that took you twice is left alone for two levels)
            if ns:GuideUnlocked() then ns.PlannerRecordDeath() end
            return
        end
        if event ~= "QUEST_ACCEPTED" and event ~= "QUEST_TURNED_IN" and event ~= "QUEST_REMOVED" then return end
        local recent = (event == "QUEST_TURNED_IN" and type(a) == "number") and JustRemoved(a, Now()) or nil   -- (removed a moment ago: a hand-in)
        if ns:GuideUnlocked() then
            local id = (event == "QUEST_ACCEPTED" and type(b) == "number") and b or a
            if type(id) == "number" then
                local okG, grouped = pcall(IsInGroup)
                grouped = not okG or not ns.Is(grouped, false)      -- (hidden or unreadable: counted as grouped)
                if event == "QUEST_ACCEPTED" then
                    local list = SoloAt(false)
                    if list then list[id] = nil end
                    if not grouped then
                        local okQ, q = pcall(LoggedQuest, id)
                        if okQ and type(q) == "table" and q.elite == true and type(q.level) == "number" then
                            list = SoloAt(true)
                            if list then list[id] = q.level end
                        end
                    end
                elseif event == "QUEST_REMOVED" and not Completed(id) then         -- (abandoned, unless QUEST_TURNED_IN follows at once)
                    local list = SoloAt(false)
                    local e = Removed(id, Now())
                    if list then e.level = list[id]; list[id] = nil end
                else                                                         -- (handed in: Forever may say so by QUEST_REMOVED first)
                    local list = SoloAt(false)
                    local questLevel = list and tonumber(list[id])
                    if list then list[id] = nil end
                    if not questLevel and recent then questLevel = tonumber(recent.level) end
                    local level = UnitLevel and UnitLevel("player")
                    local class = ns.PlannerClassToken()
                    if questLevel and not grouped and class and type(level) == "number" and not ns:IsSecret(level) then
                        ns.PlannerRecordSoloElite(class, questLevel - level)
                    end
                end
            end
        end
        local on = Following()
        if not on then
            if (event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED") and type(a) == "number" and open[a] then   -- (not followed to the end: no sample)
                local now = Now()
                if now then Close(a, now) else open[a], openN, since[a] = nil, openN - 1, nil end
            end
            return
        end
        if event == "QUEST_ACCEPTED" then
            local id = (type(b) == "number") and b or a                -- (the quest id comes second or first, by client)
            local now = Now()
            if type(id) == "number" and now and not open[id] then
                Share(now)
                open[id], openN, since[id] = 0, openN + 1, now
            end
        elseif event == "QUEST_TURNED_IN" then
            if type(a) == "number" then
                local now = Now()
                local took = now and open[a] and Close(a, now)
                if not took and recent then took = recent.took end
                if took then ns.PlannerRecordQuestTime(a, took) end
            end
        elseif type(a) == "number" then                                  -- (QUEST_REMOVED)
            local now, done = Now(), Completed(a)              -- (handed in, said by QUEST_REMOVED first: a sample; abandoned: none)
            if open[a] then
                local took
                if now then took = Close(a, now) else open[a], openN, since[a] = nil, openN - 1, nil end
                if took and done then ns.PlannerRecordQuestTime(a, took) end
                if took and not done then Removed(a, now).took = took end    -- (kept a second, for a QUEST_TURNED_IN to come)
            end
        end
    end))
end

------------------------------------------------------------------------------------------
-- The best reward (PlannerAdvice.lua), and the session start
------------------------------------------------------------------------------------------
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

-- The best reward is shown, never chosen: a frame of our own lies over the game's reward button (it is not
-- clicked, and none of the game's quest frames is written to), and a chat line names it. The click is yours.
local mark, markedAt
function ns.PlannerRewardMarked() return markedAt end            -- (the choice shown, or nil)
function ns.PlannerRewardMarkFrame() return mark end              -- (read only: the tests)
local function Unmark()
    markedAt = nil
    if mark then mark:Hide() end
end
local function Mark(button)
    if not mark then
        mark = CreateFrame("Frame")
        local fill = mark:CreateTexture(nil, "OVERLAY")
        fill:SetAllPoints()
        mark.parts = { { fill, 0.18 } }
        local function Edge(a1, a2, w, h)
            local t = mark:CreateTexture(nil, "OVERLAY")
            t:SetPoint(a1); t:SetPoint(a2)
            if w then t:SetWidth(w) else t:SetHeight(h) end
            mark.parts[#mark.parts + 1] = { t, 0.9 }
        end
        Edge("TOPLEFT", "TOPRIGHT", nil, 2); Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 2)
        Edge("TOPLEFT", "BOTTOMLEFT", 2); Edge("TOPRIGHT", "BOTTOMRIGHT", 2)
        mark:EnableMouse(false)                    -- (the click goes through to the game's button)
    end
    local r, g, b = ns:Role("@accent")             -- (the accent as it is now: each time it is shown, after a theme change too)
    for _, p in ipairs(mark.parts) do p[1]:SetColorTexture(r, g, b, p[2]) end
    mark:SetParent(button)
    mark:ClearAllPoints()
    mark:SetAllPoints(button)
    local okL, level = pcall(button.GetFrameLevel, button)
    if okL and type(level) == "number" and not ns:IsSecret(level) then mark:SetFrameLevel(level + 5) end
    mark:Show()
end
local function PickReward()
    Unmark()
    if not On("plannerPickReward") then return end
    local i = ns.PlannerBestChoice()
    if not i then return end
    markedAt = i
    local okB, button = pcall(function() return _G.QuestInfo_GetRewardButton(_G.QuestInfoFrame.rewardsFrame, i) end)
    if okB and type(button) == "table" and type(button.GetFrameLevel) == "function" then pcall(Mark, button) end
    local okL, link = pcall(_G.GetQuestItemLink, "choice", i)
    local name = okL and type(link) == "string" and not ns:IsSecret(link) and link ~= "" and link or nil
    if not name then
        local okI, n = pcall(_G.GetQuestItemInfo, "choice", i)
        name = okI and Clean(n) or nil
    end
    if name then ns:Print("Best reward for you: %s", name) end
end

do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "QUEST_COMPLETE")
    pcall(ev.RegisterEvent, ev, "QUEST_FINISHED")               -- (the hand-in window closed: the mark goes)
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
        if event == "QUEST_FINISHED" then Unmark(); return end
        if event ~= "QUEST_COMPLETE" then return end
        if C_Timer and C_Timer.After then
            local ok = pcall(C_Timer.After, 0, pick)
            if ok then return end
        end
        pick()
    end))
end

------------------------------------------------------------------------------------------
-- Gathering nodes you have seen: recorded per account when you cast a gathering spell on one (PlannerPath.lua)
------------------------------------------------------------------------------------------
ns.PLANNER_NODE_YARDS = 10              -- two gatherings this close are one node
local NODE_CAP = 300                    -- nodes kept per map
ns.PLANNER_NODE_CAP = NODE_CAP         -- (the gold advisor's node fold reads it: one number)
local function R1(v) return floor(v * 10 + 0.5) / 10 end

local HERBALISM, MINING, SKINNING = 182, 186, 393
local GATHER_SPELLS = {
    [2366] = HERBALISM, [2368] = HERBALISM, [3570] = HERBALISM, [11993] = HERBALISM,
    [2575] = MINING, [2576] = MINING, [3564] = MINING, [10248] = MINING,
    [8613] = SKINNING, [8617] = SKINNING, [8618] = SKINNING, [10768] = SKINNING,
}
local BASE_SPELLS = { [2366] = HERBALISM, [2575] = MINING, [8613] = SKINNING }   -- (their names, in your language, say the rest)

local function SpellName(id)
    if type(C_Spell) ~= "table" or type(C_Spell.GetSpellInfo) ~= "function" then return nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    local name = ok and type(info) == "table" and not ns:IsSecret(info) and info.name or nil
    return type(name) == "string" and not ns:IsSecret(name) and name or nil
end

-- The skill line (182, 186, 393) a spell gathers with, or nil: the one such function (the gold advisor's
-- gathering and farming read it too). The answer is kept per spell for the session
-- ("none" too), and the base spells' names once: a cast in a fight asks the game nothing new.
local skillOf, baseNames = {}, nil
function ns.PlannerGatherSkill(spellID)
    spellID = Num(spellID)
    if not spellID then return nil end
    if GATHER_SPELLS[spellID] then return GATHER_SPELLS[spellID] end
    local hit = skillOf[spellID]
    if hit ~= nil then return hit or nil end
    local name = SpellName(spellID)
    if not name then return nil end                  -- (not readable now: asked again next time)
    if not baseNames then
        local names, all = {}, true
        for id, line in pairs(BASE_SPELLS) do
            local n = SpellName(id)
            if n then names[n] = line else all = false end
        end
        if not all then
            for n, line in pairs(names) do if n == name then return line end end
            return nil
        end
        baseNames = names
    end
    skillOf[spellID] = baseNames[name] or false
    return baseNames[name]
end
function ns.PlannerGatherSkillReset() skillOf, baseNames = {}, nil end   -- (the tests: a new language)

local function NodeWorld(map, x, y)
    local c, wx, wy = ns.PlannerWorldPos(map, x, y)
    return c, wx, wy
end
-- A saved node's world position, kept beside it for the session (a weak table: nothing is added to the saved node).
local nodePos = setmetatable({}, { __mode = "k" })
local function NodePos(map, n)
    local e = nodePos[n]
    local x, y = tonumber(n.x), tonumber(n.y)
    if not e or e[1] ~= map or e[2] ~= x or e[3] ~= y then
        local c, wx, wy = NodeWorld(map, x, y)
        e = { map, x, y, c or false, wx, wy }
        nodePos[n] = e
    end
    if e[4] then return e[4], e[5], e[6] end
end
ns.PLANNER_NODES_TOTAL = 4000           -- nodes kept on all maps together (past it the fullest map loses its oldest)

-- Record a node (once per 10 yards, per skill). Saved tables are made only here.
function ns.PlannerRecordNode(map, x, y, name, skill)
    map, x, y = Num(map), Num(x), Num(y)
    name = Clean(name)
    if not (map and x and y and name and type(ns.root) == "table") then return false end
    if skill ~= HERBALISM and skill ~= MINING then return false end
    local list = type(ns.root.plannerNodesSeen) == "table" and type(ns.root.plannerNodesSeen[map]) == "table" and ns.root.plannerNodesSeen[map] or nil
    local c1, x1, y1 = NodeWorld(map, x, y)
    if not c1 then return false end                 -- (no world scale on this map: nothing is recorded)
    if list then
        for _, n in ipairs(list) do
            if type(n) == "table" and n.skill == skill and n.name == name then
                local c2, x2, y2 = NodePos(map, n)
                if c2 == c1 and sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) <= ns.PLANNER_NODE_YARDS then return false end
            end
        end
    end
    if type(ns.root.plannerNodesSeen) ~= "table" then ns.root.plannerNodesSeen = {} end
    local all = ns.root.plannerNodesSeen
    if type(all[map]) ~= "table" then all[map] = {} end
    local out = all[map]
    out[#out + 1] = { name = name, x = R1(x), y = R1(y), skill = skill }
    while #out > NODE_CAP do table.remove(out, 1) end      -- (a full map keeps learning: its oldest node goes)
    local total, fullest, most = 0, nil, 0
    for m, l in pairs(all) do
        if type(l) == "table" then
            total = total + #l
            if #l > most then fullest, most = m, #l end
        end
    end
    while total > ns.PLANNER_NODES_TOTAL and fullest do
        table.remove(all[fullest], 1)
        total, most = total - 1, most - 1
        for m, l in pairs(all) do if type(l) == "table" and #l > most then fullest, most = m, #l end end
    end
    return true
end

-- The one UNIT_SPELLCAST_SENT recorder: a herb or ore node goes into plannerNodesSeen (unless plannerGather is
-- off), and every gathering, skinning too, is handed to the gold advisor (ns.GoldGatherSent), which records
-- what it gives. A plain handler first: while locked it returns at once, so nothing is timed by /fgui perf.
-- ns.PlannerGatherFrame(frame) builds it on a frame (the tests: one without unit events).
function ns.PlannerGatherFrame(ev)
    local unitOk = type(ev.RegisterUnitEvent) == "function" and pcall(ev.RegisterUnitEvent, ev, "UNIT_SPELLCAST_SENT", "player")
    if not unitOk then pcall(ev.RegisterEvent, ev, "UNIT_SPELLCAST_SENT") end   -- (no unit events: every unit's, and the handler keeps the player's)
    local guarded = ns:Guard("Planner gather", function(_, _, unit, target, _, spellID)
        if ns:IsSecret(unit) or unit ~= "player" then return end
        local skill = ns.PlannerGatherSkill(spellID)
        if not skill then return end
        local name = (type(target) == "string" and not ns:IsSecret(target) and target ~= "") and target or nil
        if name and skill ~= SKINNING and not (ns.db and ns.db.plannerGather == false) and ns.GuideHere then   -- (skinning only drives the "skin them" note)
            local map, x, y = ns.GuideHere()
            if map and x and y then ns.PlannerRecordNode(map, x, y, name, skill) end
        end
        if type(ns.GoldGatherSent) == "function" then ns.GoldGatherSent(name, skill, spellID) end
    end)
    ev:SetScript("OnEvent", function(...) if ns.GuideUnlocked and ns:GuideUnlocked() == true then guarded(...) end end)
    return ev
end
ns.PlannerGatherFrame(CreateFrame("Frame"))

------------------------------------------------------------------------------------------
-- Places you have used (PlannerSource.lua): where you stood at a mailbox or a vendor, saved per account
-- (only while the guide is unlocked) with your faction, unique within 30 yards per faction; at most
-- ns.PLANNER_SEEN_CAP of each kind (the oldest go first).
------------------------------------------------------------------------------------------
local SEEN_NEAR = 30
ns.PLANNER_SEEN_CAP = 300
local SEEN_EVENT = { MAIL_SHOW = "mailbox", MERCHANT_SHOW = "vendor" }

local function Try(f, ...) return pcall(f, ...) end
local function MyFaction()
    local ok, faction = Try(UnitFactionGroup, "player")
    if ok and type(faction) == "string" and not ns:IsSecret(faction) and faction ~= "" then return faction end
end

local function SeenYards(a, b)
    if a.map ~= b.map then return math.huge end
    local c1, x1, y1 = ns.PlannerWorldPos(a.map, a.x, a.y)
    local c2, x2, y2 = ns.PlannerWorldPos(b.map, b.x, b.y)
    if c1 and c1 == c2 then return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2) end
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) * 10   -- (no world position: a rough guess, a map is about 1000 yards)
end

function ns.PlannerSeen(kind)
    if not ns:GuideUnlocked() or not ns.GuideHere then return end
    local map, x, y = ns.GuideHere()
    if not (tonumber(map) and tonumber(x) and tonumber(y)) then return end
    local here = { map = map, x = x, y = y }
    local faction = MyFaction()
    if not faction then return end
    local list = type(ns.root.plannerSeen) == "table" and type(ns.root.plannerSeen[kind]) == "table" and ns.root.plannerSeen[kind]
    local repair = false
    if kind == "vendor" and CanMerchantRepair then
        local okR, can = Try(CanMerchantRepair)
        repair = okR and ns.Is(can, true)
    end
    for _, p in ipairs(list or {}) do
        if type(p) == "table" and p.faction == faction and tonumber(p.map) and tonumber(p.x) and tonumber(p.y) and SeenYards(here, p) < SEEN_NEAR then
            if repair then p.repair = true end
            return
        end
    end
    local okN, name = Try(UnitName, "npc")
    if not okN or type(name) ~= "string" or ns:IsSecret(name) or name == "" then name = kind == "mailbox" and ns:Tr("Mailbox") or nil end
    if not name then return end
    if type(ns.root.plannerSeen) ~= "table" then ns.root.plannerSeen = {} end
    local seen = ns.root.plannerSeen
    if type(seen[kind]) ~= "table" then seen[kind] = {} end
    local out = seen[kind]
    for i = #out, 1, -1 do                                  -- (entries saved before factions were: dropped)
        if type(out[i]) ~= "table" or out[i].faction == nil then table.remove(out, i) end
    end
    out[#out + 1] = { name = name, map = map, x = x, y = y, repair = repair or nil, faction = faction }
    while #out > ns.PLANNER_SEEN_CAP do table.remove(out, 1) end
end

do
    local ev = CreateFrame("Frame")
    for e in pairs(SEEN_EVENT) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("PlannerSeen", function(_, event) if SEEN_EVENT[event] then ns.PlannerSeen(SEEN_EVENT[event]) end end))
end

------------------------------------------------------------------------------------------
-- Timed quests (PlannerSource.lua): a per-account memory of every quest any of your characters accepted with
-- a clock on it (ns.root.plannerTimed[questID] = { secs = seconds, seen = day }, written only while the guide
-- is unlocked; at most ns.PLANNER_TIMED_CAP, the oldest `seen` go first). PlannerSource.lua reads it.
------------------------------------------------------------------------------------------
ns.PLANNER_TIMED_CAP = 500

local function Seconds(v) if type(v) == "number" and not ns:IsSecret(v) and v > 0 then return v end end

-- The day an entry was last seen (an older plain number: never, so it goes first).
local function SeenDay(e) return type(e) == "table" and tonumber(e.seen) or 0 end

function ns.PlannerRecordTimed(id)
    if type(id) ~= "number" or ns:IsSecret(id) or not ns:GuideUnlocked() or type(ns.root) ~= "table" then return end
    local QL = C_QuestLog
    if not (QL and type(QL.GetTimeAllowed) == "function") then return end
    local ok, total = pcall(QL.GetTimeAllowed, id)
    local secs = ok and Seconds(total) or nil
    if not secs then return end
    secs = math.floor(secs)
    if secs <= 0 then return end
    local okT, now = pcall(time)
    local day = okT and type(now) == "number" and not ns:IsSecret(now) and math.floor(now / 86400) or 0
    if type(ns.root.plannerTimed) ~= "table" then ns.root.plannerTimed = {} end
    local mem = ns.root.plannerTimed
    mem[id] = { secs = secs, seen = day }
    local n = 0
    for _ in pairs(mem) do n = n + 1 end
    while n > ns.PLANNER_TIMED_CAP do                       -- (the oldest seen first; the same day: the lower id)
        local old, oldDay
        for k, e in pairs(mem) do
            local d = SeenDay(e)
            if k ~= id and (not old or d < oldDay or (d == oldDay and tonumber(k) and tonumber(old) and k < old)) then old, oldDay = k, d end
        end
        if old == nil then break end
        mem[old] = nil
        n = n - 1
    end
end

do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "QUEST_ACCEPTED")
    ev:SetScript("OnEvent", ns:Guard("PlannerTimed", function(_, event, a, b)
        if event ~= "QUEST_ACCEPTED" then return end
        local id = (type(b) == "number") and b or a           -- (questID; older clients send the log index first)
        ns.PlannerRecordTimed(id)
    end))
end

------------------------------------------------------------------------------------------
-- The hearthstone was set: remember where, so the planner knows where it takes you (PlannerRoute.lua).
------------------------------------------------------------------------------------------
local function BindName()
    local ok, v = pcall(function() return type(GetBindLocation) == "function" and GetBindLocation() or nil end)
    if ok and type(v) == "string" and not ns:IsSecret(v) and v ~= "" then return v end
end
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "HEARTHSTONE_BOUND")
    ev:SetScript("OnEvent", ns:Guard("Planner bind", function(_, event)
        if event ~= "HEARTHSTONE_BOUND" or not ns:GuideUnlocked() then return end
        local name = BindName()
        local m, px, py
        if ns.GuideHere then m, px, py = ns.GuideHere() end
        if not (name and m and px and py) then return end
        local d = PaceRecord(true)
        if d then d.bindAt = { name = name, map = m, x = px, y = py } end
    end))
end

------------------------------------------------------------------------------------------
-- Level times (PlannerRecords.lua): a play clock per character (seconds while logged in, added by a 10 second
-- ticker; never RequestTimePlayed, which prints in chat). At a level-up the old level's time is kept per
-- account, ns.root.plannerLevels[charKey][level] = { s, xph, partial }, so characters can be
-- compared. The first level seen after install is partial (some of it was not timed): it is kept
-- but left out of fastest, slowest, average and the race.
------------------------------------------------------------------------------------------
local TICK, TICK_MAX = 10, 30

-- A number the game gave (nil when unreadable or hidden).
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and type(v) == "number" and not ns:IsSecret(v) then return v end
    return nil
end

-- Add a tick to this character's clock. `elapsed` is the GetTime() time since the last tick, at most
-- 30 s, so a reload or a loading screen adds nothing extra. Skips when the level or the xp max is unreadable.
function ns.PlannerLevelTick(elapsed)
    if not Unlocked() then return false end
    elapsed = tonumber(elapsed) or 0
    if elapsed ~= elapsed or elapsed < 0 then elapsed = 0 end
    elapsed = min(elapsed, TICK_MAX)
    local level, xpMax = Read(UnitLevel, "player"), Read(UnitXPMax, "player")
    if not level or level < 1 or not xpMax or xpMax <= 0 then return false end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
    if type(rec) ~= "table" then return false end
    local c = rec.levelClock
    if type(c) ~= "table" or c.level ~= level then          -- (first tick, or a level gained while not timed: only part of it is known)
        rec.levelClock = { level = level, seconds = elapsed, xpMax = xpMax, partial = true }
    else
        c.seconds = (tonumber(c.seconds) or 0) + elapsed
        c.xpMax = xpMax
    end
    return true
end

-- PLAYER_LEVEL_UP: keep the level you left, then start a clock for the new one.
function ns.PlannerRecordLevel(oldLevel)
    if not Unlocked() or type(oldLevel) ~= "number" then return false end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
    if type(rec) ~= "table" or type(ns.root) ~= "table" then return false end
    local c = rec.levelClock
    local seconds, xpMax = type(c) == "table" and tonumber(c.seconds), type(c) == "table" and tonumber(c.xpMax)
    if type(c) == "table" and c.level == oldLevel and seconds and seconds > 0 and xpMax and xpMax > 0 then
        if type(ns.root.plannerLevels) ~= "table" then ns.root.plannerLevels = {} end
        local key = ns:CharKey()
        if type(ns.root.plannerLevels[key]) ~= "table" then ns.root.plannerLevels[key] = {} end
        local s = floor(seconds + 0.5)
        ns.root.plannerLevels[key][oldLevel] = { s = s, xph = floor(xpMax * 3600 / max(1, s) + 0.5), partial = c.partial and true or nil }
    end
    rec.levelClock = { level = oldLevel + 1, seconds = 0, xpMax = Read(UnitXPMax, "player") or 0, partial = false }   -- (a level begun at the level-up is whole)
    return true
end

-- The recorded levels of one character, whole ones only: { fastest = { level, s }, slowest = { level, s }, average, count }.
function ns.PlannerLevelSummary(charKey)
    local root = ns.root
    local list = type(root) == "table" and type(root.plannerLevels) == "table" and root.plannerLevels[charKey or ns:CharKey()]
    local out, total = { count = 0 }, 0
    if type(list) ~= "table" then return out end
    for level, e in pairs(list) do
        local s = type(e) == "table" and not e.partial and tonumber(e.s)
        if type(level) == "number" and s and s > 0 then
            out.count, total = out.count + 1, total + s
            local f, sl = out.fastest, out.slowest
            if not f or s < f.s or (s == f.s and level < f.level) then out.fastest = { level = level, s = s } end
            if not sl or s > sl.s or (s == sl.s and level < sl.level) then out.slowest = { level = level, s = s } end
        end
    end
    if out.count > 0 then out.average = total / out.count end
    return out
end

-- A length of time as the stats page shows it: 1d 2h, 3h 5m, 12m.
local function Span(secs)
    secs = floor(tonumber(secs) or 0)
    local d, h, m = floor(secs / 86400), floor(secs % 86400 / 3600), floor(secs % 3600 / 60)
    if d > 0 then return format(ns:Tr("%d d %d h"), d, h) end           -- (the same way as the rest of the add-on writes a time)
    if h > 0 then return format(ns:Tr("%d h %d min"), h, m) end
    return format(ns:Tr("%d min"), m)
end
local function Commas(n)
    local s = tostring(floor((tonumber(n) or 0) + 0.5))
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

-- The Levels part of /fgui stats: lines for ShowLifetime (empty while locked or with nothing recorded).
function ns.PlannerLevelLines()
    local lines = {}
    if not Unlocked() then return lines end
    local sum = ns.PlannerLevelSummary()
    if sum.count < 1 then return lines end
    lines[1] = { left = " " }
    lines[2] = { left = ns:AccentHex() .. ns:Tr("Levels") .. "|r" }
    lines[3] = { left = format(ns:Tr("Fastest level: %d (%s)"), sum.fastest.level, Span(sum.fastest.s)), indent = 16 }
    lines[4] = { left = format(ns:Tr("Slowest level: %d (%s)"), sum.slowest.level, Span(sum.slowest.s)), indent = 16 }
    lines[5] = { left = format(ns:Tr("Average per level: %s"), Span(sum.average)), indent = 16 }
    return lines
end

-- The run log's first list: one line per recorded level of this character, newest first, at most 20.
function ns.PlannerLevelRunLines()
    local lines = {}
    if not Unlocked() then return lines end
    local root = ns.root
    local list = type(root) == "table" and type(root.plannerLevels) == "table" and root.plannerLevels[ns:CharKey()]
    if type(list) ~= "table" then return lines end
    local levels = {}
    for level, e in pairs(list) do
        if type(level) == "number" and type(e) == "table" and tonumber(e.s) then levels[#levels + 1] = level end
    end
    table.sort(levels, function(a, b) return a > b end)
    for i = 1, min(20, #levels) do
        local e = list[levels[i]]
        local text = format(ns:Tr("Level %d: %s, %s xp an hour"), levels[i], Span(e.s), Commas(e.xph))
        if e.partial then text = text .. "  " .. ns:ToneHex("dim") .. "(" .. ns:Tr("partly timed") .. ")|r" end     -- (not counted in fastest, slowest, average or the race)
        lines[#lines + 1] = { left = text }
    end
    return lines
end

-- Events and the 10 second ticker. The initial login's time is kept too (memory only): a planner folder
-- loaded a moment after it still says where you left off (PlannerRecords.lua).
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    local loginAt
    function ns.PlannerLoginAt() return loginAt end                 -- (the GetTime of this session's initial login, seen unlocked; or nil)
    ev:SetScript("OnEvent", ns:Guard("Planner records", function(_, event, a)
        if not Unlocked() then return end
        if event == "PLAYER_LEVEL_UP" then
            if type(a) == "number" and a > 1 then ns.PlannerRecordLevel(a - 1) end
        elseif event == "PLAYER_ENTERING_WORLD" and a == true then       -- (an initial login: not a reload, not a loading screen)
            loginAt = Read(GetTime)
        end
    end))
    local acc, last = 0, nil
    ns.plannerRecordsFrame = ev
    function ns.PlannerLevelGapReset() acc, last = 0, nil end      -- (as after a reload: the next tick adds nothing)
    ev:SetScript("OnUpdate", ns:Guard("Planner records", function(_, elapsed)
        acc = acc + (tonumber(elapsed) or 0)
        if acc < TICK then return end
        acc = 0
        local now = GetTime()
        local gap = last and (now - last) or 0           -- (the first tick after a login or a reload adds nothing)
        last = now
        ns.PlannerLevelTick(gap)
        if ns.db and ns.db.plannerRace == true and Unlocked() and ns.GuideRedraw and not InCombatLockdown() then     -- (the race line follows the clock, on a panel you can see; not in a fight)
            local panel = _G.FantasyGlassUIGuide
            if type(panel) == "table" and panel.IsShown and panel:IsShown() then ns:GuideRedraw() end
        end
    end))
end

------------------------------------------------------------------------------------------
-- When you were last here (PlannerPace.lua), every minute and at logout; and at an initial login after 14 days
-- or more away, the catch-up page (the planner's folder is loaded for it, after the fight when in one).
------------------------------------------------------------------------------------------
ns.PLANNER_CATCHUP_DAYS = 14                -- away this many days or more: the catch-up page

local entered = false                        -- (the login's own handling is done: the clock may be saved from now on)
local inWorld = false                        -- (a PLAYER_ENTERING_WORLD came, locked or not: an unlock after it starts the clock at once)
-- Forget that the login was handled (the pace reset of PlannerPace.lua, the tests).
function ns.PlannerSeenReset() entered, inWorld = false, false end

local function SeenNow()
    local ok, t = pcall(time)
    return ok and Num(t) or 0
end

-- Remember when you were last here, and which version it was (every minute, and at logout).
function ns.PlannerSeenSave()
    if not entered or not Unlocked() then return end            -- (whether or not the guide is on: you are still playing)
    local rec = PaceRecord(true)
    if rec then rec.lastSeen, rec.lastVersion = SeenNow(), ns.version end
end

-- The catch-up page: the planner's folder loads for it (quietly; after the fight when in one).
local function CatchUp(away, since)
    if ns:LoadPlanner(true) then ns:PlannerCatchUp(away, since); return end
    if InCombatLockdown() then
        ns:AfterFight("Catch me up", function()
            if Unlocked() and ns:LoadPlanner(true) then ns:PlannerCatchUp(away, since) end
        end, true)                                                   -- (automatic: it waits without a word)
    end
end

do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
    pcall(ev.RegisterEvent, ev, "PLAYER_LOGOUT")
    ev:SetScript("OnEvent", ns:Guard("Planner pace", function(_, event, isInitial)
        if event == "PLAYER_LOGOUT" then ns.PlannerSeenSave(); return end
        if event ~= "PLAYER_ENTERING_WORLD" then return end
        inWorld = true
        if not (type(ns.root) == "table" and Unlocked()) then return end
        if isInitial and ns.GuideOn ~= nil and ns:GuideOn() == true then
            local rec = PaceRecord(false)
            local was = rec and tonumber(rec.lastSeen)
            local away = was and SeenNow() - was
            if away and away >= ns.PLANNER_CATCHUP_DAYS * 86400 then CatchUp(away, rec.lastVersion) end
        end
        entered = true
        ns.PlannerSeenSave()
    end))
    ns:Every(60, "Planner seen", function()
        if entered then ns.PlannerSeenSave() end
    end)
end
-- Unlocked mid-session: the login is long handled, so the clock is saved from now on, at once.
ns.GuideRegisterLock("paceSeen", function(unlocked)
    if unlocked and inWorld and not entered and Unlocked() then
        entered = true
        ns.PlannerSeenSave()
    end
end)

------------------------------------------------------------------------------------------
-- The duo's prefix (PlannerDuo.lua), and a friend's ask while the planner's folder is not loaded: the folder
-- is loaded and the ask handed to its listener (ns.PlannerDuoEvent), once. Only "D1:ASK:<session>:<level>",
-- whispered with our prefix, every value readable, unlocked, with asking on. In a fight the latest ask waits
-- (one at most) and is handed over when the fight ends, if it is under 60 s old. Nothing is sent from here,
-- and once the folder is loaded nothing more is handed over: its own listener hears them.
------------------------------------------------------------------------------------------
ns.PLANNER_DUO_PREFIX = "FGUIPlan"
local DUO_PREFIX, DUO_MAX_BYTES, ASK_HELD = ns.PLANNER_DUO_PREFIX, 255, 60

local registered = false
local AskListen                                  -- (below: CHAT_MSG_ADDON, only while unlocked and the folder is not loaded)
-- The prefix, registered once, when the guide is unlocked.
function ns.PlannerDuoRegister()
    if not ns:GuideUnlocked() then return end
    if AskListen then AskListen(true) end
    if registered then return end
    local chat = C_ChatInfo
    if type(chat) == "table" and chat.RegisterAddonMessagePrefix then registered = pcall(chat.RegisterAddonMessagePrefix, DUO_PREFIX) end
end

do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
    local listening, held = false, nil               -- held: { prefix, msg, channel, sender, at }
    AskListen = function(on)                         -- (a locked player does not even hear add-on messages)
        on = (on and not ns.folderReady.planner) and true or false
        if on == listening then return end
        listening = on
        if on then pcall(ev.RegisterEvent, ev, "CHAT_MSG_ADDON") else pcall(ev.UnregisterEvent, ev, "CHAT_MSG_ADDON") end
    end
    local function Now()
        local ok, t = pcall(GetTime)
        return ok and Num(t) or nil
    end
    local function HandOver(prefix, msg, channel, sender)
        if ns.folderReady.planner or not Unlocked() then return end
        if not ns:LoadPlanner(true) then return end
        AskListen(false)
        if type(ns.PlannerDuoEvent) == "function" then ns.PlannerDuoEvent("CHAT_MSG_ADDON", prefix, msg, channel, sender) end
    end
    ev:SetScript("OnEvent", ns:Guard("Planner duo", function(_, event, prefix, msg, channel, sender)
        if event == "PLAYER_LOGIN" then ns.PlannerDuoRegister(); return end
        if event == "PLAYER_REGEN_ENABLED" then                      -- (an ask that came in the fight: handed over now, if it is recent)
            local h = held
            held = nil
            local now = Now()
            if h and now and now >= h.at and now - h.at < ASK_HELD and not InCombatLockdown() then HandOver(h[1], h[2], h[3], h[4]) end
            return
        end
        if event ~= "CHAT_MSG_ADDON" then return end
        if ns.folderReady.planner then AskListen(false); return end     -- (the folder hears its own)
        if not Unlocked() or (ns.db and ns.db.plannerDuoAsk == false) then return end
        if ns:IsSecret(prefix) or ns:IsSecret(msg) or ns:IsSecret(channel) or ns:IsSecret(sender) then return end
        if type(prefix) ~= "string" or type(msg) ~= "string" or type(channel) ~= "string" or type(sender) ~= "string" or sender == "" then return end
        if prefix ~= DUO_PREFIX or channel ~= "WHISPER" or #msg > DUO_MAX_BYTES then return end
        local session = msg:match("^D1:ASK:(%x+):%d+$")
        if not (session and #session >= 4 and #session <= 8) then return end
        if InCombatLockdown() then
            local now = Now()
            if now then held = { prefix, msg, channel, sender, at = now } end
            return
        end
        HandOver(prefix, msg, channel, sender)
    end))
    ns.GuideRegisterLock("duoPrefix", function(unlocked)
        if unlocked and ns:GuideUnlocked() then ns.PlannerDuoRegister()
        else registered, held = false, nil; AskListen(false) end
    end)
end
