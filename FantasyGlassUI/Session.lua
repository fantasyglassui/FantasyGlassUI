local _, ns = ...

-- Session statistics: what has happened since you logged in, plus total time played.
-- Always running (it only listens and counts). Shown on the AFK screen and by /fgui session.
local S = { start = GetTime(), xp = 0, kills = 0, quests = 0, deaths = 0, levels = 0 }
ns.session = S

local function Duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local d, h, m = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    if d > 0 then return format("%dd %dh %02dm", d, h, m) end
    if h > 0 then return format("%dh %02dm", h, m) end
    return format("%dm %02ds", m, seconds % 60)
end
local function Num(n)
    n = math.floor(n)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

-- Time played: asked for once after login. The game normally prints the answer in chat; the chat
-- windows are told to skip that one message, then put back the way they were.
local played, waiting
local function RestoreChat()
    if not waiting then return end
    for _, cf in ipairs(waiting) do pcall(cf.RegisterEvent, cf, "TIME_PLAYED_MSG") end
    waiting = nil
end
local function AskPlayed()
    if not RequestTimePlayed or waiting then return end
    waiting = {}
    for i = 1, (type(NUM_CHAT_WINDOWS) == "number" and NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if type(cf) == "table" and cf.IsEventRegistered and cf.UnregisterEvent then
            local ok, registered = pcall(cf.IsEventRegistered, cf, "TIME_PLAYED_MSG")
            if ok and registered then
                pcall(cf.UnregisterEvent, cf, "TIME_PLAYED_MSG")
                waiting[#waiting + 1] = cf
            end
        end
    end
    pcall(RequestTimePlayed)
    ns:After(6, RestoreChat)                           -- whatever happens, chat gets its message back
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_XP_UPDATE", "QUEST_TURNED_IN", "PLAYER_DEAD", "PLAYER_LEVEL_UP", "TIME_PLAYED_MSG", "PLAYER_LOGOUT" }) do
    pcall(ev.RegisterEvent, ev, e)
end
local questUntil, asked = 0, false
ev:SetScript("OnEvent", ns:Guard("Session events", function(_, event, a, b)
    if event == "PLAYER_ENTERING_WORLD" then
        -- a /reload (or a quick relog) picks the session up where it left off
        local saved = type(FantasyGlassUIDB) == "table" and FantasyGlassUIDB.sessionSave
        if not S.restored and type(saved) == "table" then
            S.restored = true
            local fresh = type(saved.at) == "number" and time and (time() - saved.at) < 180
            if fresh and saved.char == ns:CharKey() and type(saved.elapsed) == "number" then
                S.start = GetTime() - saved.elapsed
                for _, k in ipairs({ "xp", "kills", "quests", "deaths", "levels" }) do
                    if type(saved[k]) == "number" then S[k] = saved[k] end
                end
                if type(saved.money) == "number" then S.money = saved.money end
            end
            FantasyGlassUIDB.sessionSave = nil
        end
        S.restored = true
        if S.money == nil then S.money = GetMoney() end
        if S.lastXP == nil then S.lastXP, S.lastMax = UnitXP("player") or 0, UnitXPMax("player") or 0 end
        if not asked then asked = true; ns:After(3, AskPlayed) end
    elseif event == "PLAYER_XP_UPDATE" then
        local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 0
        if ns:IsSecret(cur) or ns:IsSecret(max) then return end           -- (hidden in a fight: counted at the next one that isn't)
        if S.lastXP and not ns:IsSecret(S.lastXP) then
            local delta = cur - S.lastXP
            if delta < 0 then delta = (S.lastMax - S.lastXP) + cur end       -- levelled up
            if delta > 0 then
                S.xp = S.xp + delta
                if GetTime() >= questUntil then S.kills = S.kills + 1 end    -- experience that didn't come from a quest
            end
        end
        S.lastXP, S.lastMax = cur, max
    elseif event == "QUEST_TURNED_IN" then
        S.quests = S.quests + 1
        questUntil = GetTime() + 3
    elseif event == "PLAYER_DEAD" then
        S.deaths = S.deaths + 1
    elseif event == "PLAYER_LEVEL_UP" then
        S.levels = S.levels + 1
        if played then played.level, played.levelAt = 0, GetTime() end
    elseif event == "PLAYER_LOGOUT" then                 -- also fires for /reload
        if type(FantasyGlassUIDB) == "table" and time then
            FantasyGlassUIDB.sessionSave = { char = ns:CharKey(), at = time(), elapsed = GetTime() - S.start, money = S.money,
                                        xp = S.xp, kills = S.kills, quests = S.quests, deaths = S.deaths, levels = S.levels }
        end
    elseif event == "TIME_PLAYED_MSG" then
        if type(a) == "number" and type(b) == "number" then
            played = { total = a, level = b, at = GetTime(), levelAt = GetTime() }
        end
        RestoreChat()
    end
end))

-- The figures as { label, value } rows, ready to show.
function ns:SessionStats()
    local now = GetTime()
    local elapsed = now - S.start
    local rows = {}
    local level = UnitLevel("player")
    rows[#rows + 1] = { ns:Tr("This session"), Duration(elapsed) }
    if type(level) == "number" then
        rows[#rows + 1] = { ns:Tr("Level"), S.levels > 0 and format("%d  (+%d)", level, S.levels) or tostring(level) }
    end
    if S.xp > 0 then
        local perHour = elapsed > 60 and format("  (%s / h)", Num(S.xp / elapsed * 3600)) or ""
        rows[#rows + 1] = { ns:Tr("Experience gained"), Num(S.xp) .. perHour }
    end
    local change = S.money and (GetMoney() - S.money) or 0
    if change ~= 0 then
        rows[#rows + 1] = { ns:Tr("Gold"), (change > 0 and "|cff55ee66+" or "|cffff6655-") .. ns:Coins(math.abs(change)) .. "|r" }
    end
    rows[#rows + 1] = { ns:Tr("Quests / kills / deaths"), format("%d  /  %d  /  %d", S.quests, S.kills, S.deaths) }
    if played then
        rows[#rows + 1] = { ns:Tr("Time played"), Duration(played.total + (now - played.at)) }
        rows[#rows + 1] = { ns:Tr("Time at this level"), Duration(played.level + (now - played.levelAt)) }
    end
    return rows
end

function ns:PrintSession()
    ns:Print("Session so far:")
    for _, row in ipairs(ns:SessionStats()) do ns:PrintRaw("  " .. row[1] .. ":  |cffffffff" .. row[2] .. "|r") end
end
