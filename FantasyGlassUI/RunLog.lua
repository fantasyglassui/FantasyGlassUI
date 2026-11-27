local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Run log (11.14): /fgui runs. Each dungeon and raid you go into is a run: how long it took, the
-- bosses killed (and when in the run), the wipes on each, your deaths and the rare and better loot
-- you got. Each place keeps its best time: the quickest of the runs that killed the most bosses
-- there. Shared by all your characters, the last 100 runs.
--
-- A run starts when you go in and ends when you have been out for 15 minutes, or go into somewhere
-- else (stepping out to repair is still the same run). A /reload keeps it going.
--
-- 11.16: the one record of best times. Each kill also keeps how long the fight itself took, and the
-- boss timer's "new best" lines (a boss, a finished dungeon) are measured against this log, so
-- they agree with /fgui runs.
------------------------------------------------------------------------------------------
local KEEP, AWAY = 100, 900

local function Root()
    if type(ns.root) ~= "table" then return nil end
    ns.root.runs = type(ns.root.runs) == "table" and ns.root.runs or {}
    ns.root.runNow = type(ns.root.runNow) == "table" and ns.root.runNow or {}
    return ns.root
end
local function Now() return time and time() or 0 end
local function Clock(secs)
    secs = math.max(0, math.floor(tonumber(secs) or 0))
    if secs >= 3600 then return format("%d:%02d:%02d", math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60) end
    return format("%d:%02d", math.floor(secs / 60), secs % 60)
end
ns.RunClock = Clock

-- A run's length: to its last kill if it had any (the walk out is not the run), else to when you left.
function ns.RunLength(r)
    if type(r) ~= "table" then return 0 end
    local stop = tonumber(r.lastKill) or tonumber(r.left) or tonumber(r.start) or 0
    return math.max(0, stop - (tonumber(r.start) or 0))
end
local function Kills(r) local n = 0; for _ in pairs(type(r.kills) == "table" and r.kills or {}) do n = n + 1 end; return n end
ns.RunKills = Kills

-- What happens in a run (the tests call these directly). `id`: the game's instance id (GetInstanceInfo's 8th value; 13.5),
-- which names the place in every language (the planner's dungeon run times match by it; a run from before has none).
function ns.RunNew(instance, difficulty, now, char, id)
    return { instance = instance, difficulty = difficulty, start = now, char = char, id = id, kills = {}, wipes = {}, deaths = 0, loot = {}, fights = {} }
end
-- A pull: when the fight began, so a kill can say how long it took.
function ns.RunPull(r, boss, now)
    if type(r) ~= "table" or type(boss) ~= "string" then return end
    r.pulls = type(r.pulls) == "table" and r.pulls or {}
    r.pulls[boss] = now
end
function ns.RunEncounter(r, boss, success, now)
    if type(r) ~= "table" or type(boss) ~= "string" then return end
    if success then
        if not r.kills[boss] then r.kills[boss] = now - (tonumber(r.start) or now) end
        r.lastKill = now
        local pulled = type(r.pulls) == "table" and r.pulls[boss]
        r.fights = type(r.fights) == "table" and r.fights or {}
        if pulled and not r.fights[boss] then r.fights[boss] = now - pulled end
    else
        r.wipes[boss] = (tonumber(r.wipes[boss]) or 0) + 1
    end
end
function ns.RunLoot(r, link, quality)
    if type(r) ~= "table" or type(link) ~= "string" or type(quality) ~= "number" or quality < 3 then return false end
    r.loot[#r.loot + 1] = link
    return true
end
-- A finished run into the log (runs that saw nothing happen are let go).
function ns.RunFinish(log, r)
    if type(r) ~= "table" then return false end
    local wipes = 0
    for _, n in pairs(r.wipes) do wipes = wipes + (tonumber(n) or 0) end
    if Kills(r) == 0 and wipes == 0 and #r.loot == 0 and (tonumber(r.deaths) or 0) == 0 then return false end
    log[#log + 1] = r
    while #log > KEEP do table.remove(log, 1) end
    return true
end
-- The quickest kill of `boss` in `instance` among the finished runs (seconds), or nil.
function ns.RunBossBest(log, instance, boss)
    local best
    for _, r in ipairs(type(log) == "table" and log or {}) do
        local f = type(r) == "table" and r.instance == instance and type(r.fights) == "table" and tonumber(r.fights[boss])
        if f and (not best or f < best) then best = f end
    end
    return best
end
-- The best time for a place (the quickest of its runs with the most kills), or nil.
function ns.RunPlaceBest(log, instance)
    for _, p in ipairs(ns.RunPlaces(log)) do
        if p.instance == instance and p.best then return ns.RunLength(p.best), p.bestKills end
    end
end
function ns.RunLogged() local root = Root(); return root and root.runs or {} end
-- Each place: { instance, runs, best (the run), bestKills }. Best: the quickest of the runs with the most kills.
function ns.RunPlaces(log)
    local by = {}
    for _, r in ipairs(type(log) == "table" and log or {}) do
        if type(r) == "table" and type(r.instance) == "string" then
            local p = by[r.instance] or { instance = r.instance, runs = 0, bestKills = 0, latest = 0 }
            p.runs = p.runs + 1
            p.latest = math.max(p.latest, tonumber(r.start) or 0)
            local k = Kills(r)
            if k > p.bestKills or (k == p.bestKills and k > 0 and (not p.best or ns.RunLength(r) < ns.RunLength(p.best))) then
                p.best, p.bestKills = r, k
            end
            by[r.instance] = p
        end
    end
    local out = {}
    for _, p in pairs(by) do out[#out + 1] = p end
    table.sort(out, function(a, b) return a.latest > b.latest end)
    return out
end

------------------------------------------------------------------------------------------
-- The window: places (with their best time), a place's runs, one run.
------------------------------------------------------------------------------------------
local view = { level = 0 }
local function Day(t)
    local ok, d = pcall(date, "%d %b, %H:%M", tonumber(t) or 0)
    return ok and d or ""
end
function ns.RunLines(state)
    state = state or view
    local root = Root()
    local log = root and root.runs or {}
    local lines = {}
    local function Back(to, extra)
        lines[#lines + 1] = { left = ns:AccentHex() .. "<  " .. ns:Tr("Back") .. "|r", click = function() view.level = to; for k, v in pairs(extra or {}) do view[k] = v end; ns:ShowRuns() end }
    end
    if state.level == 0 then
        for _, p in ipairs(ns.RunPlaces(log)) do
            local best = p.best and (format(ns:Tr("best %s"), Clock(ns.RunLength(p.best))) .. "  |cff9aa4b4" .. format(ns:TrN(p.bestKills, "%d boss", "%d bosses"), p.bestKills) .. "|r") or ""
            lines[#lines + 1] = { left = p.instance .. "  |cff9aa4b4" .. format(ns:TrN(p.runs, "%d run", "%d runs"), p.runs) .. "|r", right = best,
                                  click = function() view.level, view.instance = 1, p.instance; ns:ShowRuns() end }
        end
        if ns.PlannerLevelRunLines then                  -- (level times)
            for _, l in ipairs(ns.PlannerLevelRunLines()) do lines[#lines + 1] = l end
        end
        return lines
    end
    if state.level == 1 then
        Back(0)
        local list = {}
        for i, r in ipairs(log) do if r.instance == state.instance then list[#list + 1] = { i = i, r = r } end end
        table.sort(list, function(a, b) return (tonumber(a.r.start) or 0) > (tonumber(b.r.start) or 0) end)
        for _, e in ipairs(list) do
            local r = e.r
            local wipes = 0
            for _, n in pairs(r.wipes) do wipes = wipes + (tonumber(n) or 0) end
            local bits = { format(ns:TrN(Kills(r), "%d boss", "%d bosses"), Kills(r)) }
            if wipes > 0 then bits[#bits + 1] = format(ns:TrN(wipes, "%d wipe", "%d wipes"), wipes) end
            if (tonumber(r.deaths) or 0) > 0 then bits[#bits + 1] = format(ns:TrN(r.deaths, "%d death", "%d deaths"), r.deaths) end
            if #r.loot > 0 then bits[#bits + 1] = format(ns:TrN(#r.loot, "%d piece of loot", "%d pieces of loot"), #r.loot) end
            local who = type(r.char) == "string" and ("  |cff9aa4b4" .. r.char:gsub(" %- .*$", "") .. "|r") or ""
            lines[#lines + 1] = { left = Day(r.start) .. who, right = Clock(ns.RunLength(r)) .. "   |cff9aa4b4" .. table.concat(bits, ", ") .. "|r",
                                  click = function() view.level, view.run = 2, e.i; ns:ShowRuns() end }
        end
        return lines
    end
    -- level 2: one run
    Back(1)
    local r = log[state.run]
    if type(r) ~= "table" then return lines end
    lines[#lines + 1] = { left = Day(r.start), right = Clock(ns.RunLength(r)), color = { 1, 0.82, 0.3 } }
    local bosses = {}
    for b, at in pairs(r.kills) do bosses[#bosses + 1] = { b = b, at = at } end
    for b in pairs(r.wipes) do if not r.kills[b] then bosses[#bosses + 1] = { b = b } end end
    table.sort(bosses, function(a, b) return (a.at or math.huge) < (b.at or math.huge) end)
    for _, e in ipairs(bosses) do
        local w = tonumber(r.wipes[e.b]) or 0
        local right = e.at and (ns:SignalHex("good") .. Clock(e.at) .. "|r") or (ns:SignalHex("bad") .. ns:Tr("not killed") .. "|r")
        local fight = type(r.fights) == "table" and tonumber(r.fights[e.b])
        if fight then
            local best = ns.RunBossBest(log, r.instance, e.b)
            right = right .. "   |cff9aa4b4" .. format(ns:Tr("fight %s"), Clock(fight)) .. ((best and best < fight) and ("  " .. format(ns:Tr("best %s"), Clock(best))) or "") .. "|r"
        end
        if w > 0 then right = right .. "   |cff9aa4b4" .. format(ns:TrN(w, "%d wipe", "%d wipes"), w) .. "|r" end
        lines[#lines + 1] = { left = "    " .. e.b, right = right }
    end
    if (tonumber(r.deaths) or 0) > 0 then lines[#lines + 1] = { left = "    " .. format(ns:TrN(r.deaths, "You died %d time", "You died %d times"), r.deaths) } end
    for _, link in ipairs(r.loot) do lines[#lines + 1] = { left = "    " .. link, link = link } end
    return lines
end

function ns:ShowRuns()
    local title = "Runs"
    if view.level >= 1 then title = view.instance or title end
    local lines = ns.RunLines(view)
    if #lines == 0 then lines[1] = { left = ns:Tr("No runs yet: each dungeon and raid you go into is noted here.") } end
    ns:ShowList("Runs", title, lines, "Best time: the quickest of the runs that killed the most bosses. Times run to the last kill.", 560, 420)
    return #lines
end

ns:NewModule("runLog", function()
    local function Instance()
        local ok, name, kind, _, difficulty, _, _, _, id = pcall(GetInstanceInfo)
        if ok and type(name) == "string" and not Secret(name) and not Secret(kind) and (kind == "party" or kind == "raid") then
            return name, (type(difficulty) == "string" and not Secret(difficulty)) and difficulty or nil,
                (type(id) == "number" and not Secret(id)) and id or nil
        end
    end
    local function Mine()
        local root = Root()
        return root and root.runNow[ns:CharKey()]
    end
    local function SetMine(r) local root = Root(); if root then root.runNow[ns:CharKey()] = r end end
    local function Finish()
        local r, root = Mine(), Root()
        if r and root then ns.RunFinish(root.runs, r) end
        SetMine(nil)
    end
    local function Where()
        local r = Mine()
        local inst, diff, id = Instance()
        local now = Now()
        if inst then
            if r and (r.instance ~= inst or (r.left and now - r.left > AWAY)) then Finish(); r = nil end
            if not r then SetMine(ns.RunNew(inst, diff, now, ns:CharKey(), id)) else r.left = nil end
        elseif r then
            if not r.left then r.left = now
            elseif now - r.left > AWAY then Finish() end
        end
    end
    local patterns = ns.LootPatterns({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_SELF or "You receive loot: %s." })
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_DEAD", "CHAT_MSG_LOOT" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Run log", function(_, event, a, b, _, _, e)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then Where() return end
        local r = Mine()
        if not r or r.left then return end
        if event == "ENCOUNTER_START" then
            if type(b) == "string" and not Secret(b) then ns.RunPull(r, b, Now()) end
        elseif event == "ENCOUNTER_END" then
            if type(b) == "string" and not Secret(b) then ns.RunEncounter(r, b, e == 1 or e == true, Now()) end
        elseif event == "PLAYER_DEAD" then
            r.deaths = (tonumber(r.deaths) or 0) + 1
        elseif event == "CHAT_MSG_LOOT" then
            if type(a) ~= "string" or Secret(a) then return end
            local link = ns.ParseLoot(a, patterns)
            if not link then return end
            local function Keep(again)
                local _, _, q = ns:GetItemInfo(link)
                if type(q) == "number" and not Secret(q) then ns.RunLoot(r, link, q)
                elseif again then ns:After(2, function() pcall(Keep, false) end) end
            end
            Keep(true)
        end
    end))
    ns:Every(60, "Run log", Where)                            -- (fifteen minutes out ends it, even standing still)
    ns.runLogTest = { Where = Where, Mine = Mine, Finish = Finish }
end)
