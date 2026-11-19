local _, ns = ...

------------------------------------------------------------------------------------------
-- Boss and dungeon timer: how long this boss has taken, and how long you have been in the dungeon
-- or raid. When a boss dies you are told the time and your best; a finished dungeon run likewise.
-- (11.16) The bests are the run log's (/fgui runs), so the two never disagree; with the run log
-- switched off, the timer keeps its own as before.
------------------------------------------------------------------------------------------
-- A new time against the best so far. Returns: is it a new best, and the line to say.
function ns.BossResult(name, seconds, best)
    local t = ns.Clock(seconds)
    if type(best) ~= "number" then return true, format(ns:Tr("%s: %s (first time timed)"), name, t) end
    if seconds < best then return true, format(ns:Tr("%s: %s - a new best (was %s)"), name, t, ns.Clock(best)) end
    return false, format(ns:Tr("%s: %s (best %s)"), name, t, ns.Clock(best))
end

ns:NewModule("bossTimer", function()
    if type(ns.root) ~= "table" then return end
    if type(ns.root.bossBest) ~= "table" then ns.root.bossBest = {} end
    if type(ns.root.runBest) ~= "table" then ns.root.runBest = {} end
    local best, runBest = ns.root.bossBest, ns.root.runBest
    local f = CreateFrame("Frame", "FantasyGlassUIBossTimer", UIParent)
    f:SetSize(170, 34)
    f:SetPoint("TOP", UIParent, "TOP", 260, -40)
    f.boss = ns:NewText(f, 13, "CENTER")
    f.boss:SetPoint("TOP", 0, -2)
    f.run = ns:NewText(f, 11, "CENTER")
    f.run:SetPoint("BOTTOM", 0, 2)
    f.run:SetTextColor(0.75, 0.75, 0.75)
    local fight, run                                          -- { name, key, start }, { name, key, start }
    ns.bossTimerState = "on"

    local function Now() return (GetTime and GetTime()) or 0 end
    local function Instance()
        local inside, kind = false, nil
        if IsInInstance then local ok, a, b = pcall(IsInInstance); if ok then inside, kind = ns.Is(a, true), b end end
        if not inside or (kind ~= "party" and kind ~= "raid" and kind ~= "scenario") then return nil end
        local name, _, difficulty, _, _, _, _, id = GetInstanceInfo()
        if type(name) ~= "string" then return nil end
        return { name = name, key = tostring(id or name) .. ":" .. tostring(difficulty or 0) }
    end
    local function Start(id, name, difficulty)
        local here = Instance()
        fight = { name = type(name) == "string" and name or ns:Tr("Boss"), key = tostring(id) .. ":" .. tostring(difficulty or 0), start = Now(),
                  instance = here and here.name }
    end
    local function Finish(success)
        local was = fight
        fight = nil
        if not was then return end
        local took = Now() - was.start
        if not ns.Is(success, 1) and not ns.Is(success, true) then
            ns:Print("%s: not this time, after %s.", was.name, ns.Clock(took))
            return false
        end
        -- (11.16) the best is the run log's, where there is one, so the two agree; an older record
        -- from before the log still counts
        local logged = ns.db.runLog and ns.RunBossBest and was.instance and ns.RunBossBest(ns.RunLogged(), was.instance, was.name)
        local before = best[was.key]
        if logged and (not before or logged < before) then before = logged end
        local newBest, line = ns.BossResult(was.name, took, before)
        if newBest and not ns.db.runLog then best[was.key] = took end
        ns:PrintRaw(line)
        return true, newBest
    end
    local function Zone()
        local here = Instance()
        if here and not (run and run.key == here.key) then run = { name = here.name, key = here.key, start = Now() }
        elseif not here then run, fight = nil, nil end
    end
    local function RunDone()
        if not run or run.done then return end
        run.done = true
        local took = Now() - run.start
        local logged = ns.db.runLog and ns.RunPlaceBest and ns.RunPlaceBest(ns.RunLogged(), run.name)
        local before = runBest[run.key]
        if logged and (not before or logged < before) then before = logged end
        local newBest, line = ns.BossResult(run.name, took, before)
        if newBest and not ns.db.runLog then runBest[run.key] = took end
        ns:PrintRaw(line)
        return newBest
    end
    ns.bossTimerTest = { Start = Start, Finish = Finish, Zone = Zone, RunDone = RunDone, best = best, runBest = runBest,
        fight = function() return fight end, run = function() return run end }

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "LFG_COMPLETION_REWARD", "CHALLENGE_MODE_COMPLETED", "SCENARIO_COMPLETED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Boss timer", function(_, event, id, name, difficulty, _, success)
        if event == "ENCOUNTER_START" then Start(id, name, difficulty)
        elseif event == "ENCOUNTER_END" then Finish(success)
        elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then ns:After(1, function() pcall(Zone) end)
        else RunDone() end
    end))
    f:SetScript("OnUpdate", ns:Guard("Boss timer", function(self, elapsed)
        self.wait = (self.wait or 0) + (elapsed or 0)
        if self.wait < 0.25 then return end
        self.wait = 0
        if ns.moving then self.boss:SetText(ns:Tr("Boss") .. "  1:23"); self.run:SetText(ns:Tr("Run") .. "  12:34"); self:SetAlpha(1) return end
        if not (fight or run) then self:SetAlpha(0) return end
        self:SetAlpha(1)
        self.boss:SetText(fight and (fight.name .. "  " .. ns.Clock(Now() - fight.start)) or "")
        self.run:SetText(run and not run.done and (ns:Tr("Run") .. "  " .. ns.Clock(Now() - run.start)) or "")
    end))
    local entry = ns:RegisterMovable(f, "bossTimer", "Boss timer")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
end)

------------------------------------------------------------------------------------------
-- Queue alert: a dungeon finder or battleground invitation is as hard to miss as a ready check.
------------------------------------------------------------------------------------------
ns:NewModule("queueAlert", function()
    local announced = {}
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "LFG_PROPOSAL_SHOW", "UPDATE_BATTLEFIELD_STATUS", "PET_BATTLE_QUEUE_PROPOSE_MATCH" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Queue alert", function(_, event, index)
        if event == "UPDATE_BATTLEFIELD_STATUS" then
            if type(index) ~= "number" or not GetBattlefieldStatus then return end
            local status = GetBattlefieldStatus(index)
            if not ns.Is(status, "confirm") then announced[index] = nil; return end
            if announced[index] then return end
            announced[index] = true
        end
        ns:LoudAlert("Your queue is ready", "Answer the invitation before it runs out.")
        ns.queueAlertCount = (ns.queueAlertCount or 0) + 1
    end))
end)

------------------------------------------------------------------------------------------
-- Automatic combat log: the game's combat log file is started in raids (and dungeons, if chosen)
-- and stopped again when you leave - but only if this is what started it.
------------------------------------------------------------------------------------------
-- Should the log be running here?
function ns.LogWanted(inside, kind, dungeonsToo)
    if not inside then return false end
    return kind == "raid" or (dungeonsToo and kind == "party") or false
end
ns:NewModule("autoCombatLog", function()
    if type(LoggingCombat) ~= "function" then ns.combatLogState = "this game client does not let add-ons start the combat log"; return end
    ns.combatLogState = "on"
    local ours = false
    local function Check()
        local inside, kind = false, nil
        if IsInInstance then local ok, a, b = pcall(IsInInstance); if ok then inside, kind = ns.Is(a, true), b end end
        local want = ns.LogWanted(inside, kind, ns.db.combatLogDungeons)
        local running = ns.Yes(LoggingCombat())
        if want and not running then
            LoggingCombat(true); ours = true
            ns:Print("Combat log started for this raid or dungeon.")
        elseif not want and running and ours then
            LoggingCombat(false); ours = false
            ns:Print("Combat log stopped.")
        end
        return want
    end
    ns.combatLogTest = { Check = Check }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Encounters events", function() ns:After(2, function() pcall(Check) end) end))
end)

------------------------------------------------------------------------------------------
-- A screenshot when a boss dies and when you earn an achievement.
------------------------------------------------------------------------------------------
ns:NewModule("bossShot", function()
    if type(Screenshot) ~= "function" then return end
    local last = 0
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BOSS_KILL", "ACHIEVEMENT_EARNED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Screenshots", function()
        local now = (GetTime and GetTime()) or 0
        if now - last < 5 and last > 0 then return end        -- (a kill and its achievement: one picture)
        last = now
        ns.bossShotCount = (ns.bossShotCount or 0) + 1
        ns:After(1.5, function() pcall(Screenshot) end)
    end))
end)
