local _, ns = ...

------------------------------------------------------------------------------------------
-- Advice around the plan: the best reward at a hand-in, quests worth dropping from a full log,
-- and an inn when you have played a long while. Advice only: nothing here hands in, abandons or
-- travels for you. Everything is behind the guide being unlocked.
------------------------------------------------------------------------------------------
local ipairs, pairs, type, pcall, select = ipairs, pairs, type, pcall, select
local format = string.format

ns.PLANNER_LOG_SIZE = 25                -- the quest log holds this many when the game cannot say
ns.PLANNER_LOG_FREE = 3                 -- advice when this many places or fewer are free
ns.PLANNER_LOG_ADVICE = 3               -- quests named at most
ns.PLANNER_GRAY_GAP = 8                 -- a quest this many levels below you is gray (check in game)
ns.PLANNER_INN_PLAY = 3600              -- seconds of play before an inn is suggested
ns.PLANNER_INN_SECONDS = 120            -- an inn this close (seconds of travel)
ns.PLANNER_INN_SHOWN = 600              -- the inn line stays on the panel this long
ns.plannerSessionStart = GetTime and GetTime() or 0

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
function ns.PlannerLogAdvice(steps, at)
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
    local accepts, byQuest = 0, {}
    steps = type(steps) == "table" and steps or {}
    for i, s in ipairs(steps) do
        if type(s) == "table" then
            if i >= (at or 1) and s.kind == "accept" then accepts = accepts + 1 end
            if type(s.quest) == "number" and s.map then
                byQuest[s.quest] = byQuest[s.quest] or {}
                byQuest[s.quest][s.map] = true
            end
        end
    end
    if not (free <= ns.PLANNER_LOG_FREE or accepts > free) then return {} end
    local okL, level = pcall(UnitLevel, "player")
    level = okL and Num(level) or 1
    local list = {}
    for _, q in ipairs(quests) do
        local own = byQuest[q.id]
        local rank, reason
        if q.level > 0 and q.level <= level - ns.PLANNER_GRAY_GAP then rank, reason = 1, "gray"
        elseif not own then rank, reason = 2, "never planned"
        else
            local other, anyOther = false, false
            for id, m in pairs(byQuest) do
                if id ~= q.id then
                    anyOther = true
                    for map in pairs(m) do if own[map] then other = true end end
                end
            end
            if anyOther and not other then rank, reason = 3, "off the route" end
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

-- The panel's lines: the quest log advice, then the inn.
function ns.PlannerAdviceLines(steps, at)
    local lines = {}
    for _, a in ipairs(ns.PlannerLogAdvice(steps, at)) do
        lines[#lines + 1] = format(ns:Tr("Worth abandoning: %s (%s)"), a.name, ns:Tr(a.reason))
    end
    local inn = ns.plannerInnLine
    if type(inn) == "table" and On("plannerInn") then
        local okT, now = pcall(GetTime)
        now = okT and Num(now) or nil
        if now and inn.t and now >= inn.t and now - inn.t <= ns.PLANNER_INN_SHOWN then lines[#lines + 1] = inn.text else ns.plannerInnLine = nil end
    end
    return lines
end

------------------------------------------------------------------------------------------
-- The inn
------------------------------------------------------------------------------------------
-- Suggest a nearby inn: after an hour of play, while rested experience is not full.
function ns.PlannerInnSuggest()
    if not On("plannerInn") then return false end
    local okT, now = pcall(GetTime)
    now = okT and Num(now) or nil
    if not now or now - (ns.plannerSessionStart or 0) < ns.PLANNER_INN_PLAY then return false end
    local okX, pool = pcall(GetXPExhaustion)
    pool = okX and Num(pool) or nil
    local okM, xpMax = pcall(UnitXPMax, "player")
    xpMax = okM and Num(xpMax) or nil
    if pool and xpMax and pool >= 1.5 * xpMax then return false end        -- (as rested as you can be)
    local okR, resting = pcall(IsResting)
    if okR and resting == true then return false end
    local ctx = ns.PlannerContext and ns.PlannerContext()
    if type(ctx) ~= "table" or type(ctx.here) ~= "table" then return false end
    local best, bestT
    for _, p in ipairs(ns.PlannerPlaces and ns.PlannerPlaces(ctx, "innkeeper") or {}) do
        local secs = ns.PlannerTravel(ctx.here, p, ctx)
        if type(secs) == "number" and secs <= ns.PLANNER_INN_SECONDS and (not bestT or secs < bestT) then best, bestT = p, secs end
    end
    if not best then return false end
    local name = Clean(best.name) or Clean(best.zone) or ns:Tr("an inn")
    local text = format(ns:Tr("Log out at %s for rested experience (about %d min away)"), name, math.max(1, math.ceil(bestT / 60)))
    ns.plannerInnLine = { text = text, t = now }
    ns:Print("Log out at %s for rested experience (about %d min away)", name, math.max(1, math.ceil(bestT / 60)))
    if ns.GuidePanelShown and ns:GuidePanelShown() and ns.GuideShowPanel then ns:GuideShowPanel() end
    return true
end

------------------------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------------------------
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "QUEST_COMPLETE")
    ev:SetScript("OnEvent", ns:Guard("Planner reward", PickReward))
    if _G.GameMenuFrame and _G.GameMenuFrame.HookScript then
        pcall(_G.GameMenuFrame.HookScript, _G.GameMenuFrame, "OnShow", ns:Guard("Planner inn", function() ns.PlannerInnSuggest() end))
    end
end
