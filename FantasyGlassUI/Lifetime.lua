local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Lifetime stats (11.16): /fgui stats. One page of totals for this character and for all of them
-- together: time played, levels, quests, kills, deaths, gold made and spent, items looted, bosses
-- killed, dungeon and raid runs and their best times, time spent farming. The counts start the
-- first time this version runs (the page says since when); the bosses, runs and farming come from
-- the run log, the loot browser and the farming sessions, so they reach back as far as those do.
--
-- 11.17: milestones. Your 1,000th kill, 100th quest, first boss, 10,000 gold made and so on are
-- marked with a short notice when they are reached, and listed (with the day) on the stats page.
------------------------------------------------------------------------------------------
local MILESTONES = {
    kills = { 100, 500, 1000, 5000, 10000, 25000, 50000, 100000 },
    quests = { 10, 50, 100, 250, 500, 1000, 2500, 5000 },
    looted = { 100, 1000, 5000, 10000, 50000 },
    goldMade = { 1000000, 10000000, 100000000, 1000000000 },          -- (copper: 100, 1,000, 10,000 and 100,000 gold)
    bosses = { 1, 10, 50, 100, 250, 500, 1000 },
    runs = { 1, 10, 25, 50, 100, 250 },
}
local MILESTONE_TEXT = {
    kills = "%s kills", quests = "%s quests done", looted = "%s items looted",
    goldMade = "%s gold made", bosses = "%s bosses killed", runs = "%s dungeon and raid runs",
}
-- The thresholds crossed going from `before` to `after` (lowest first).
function ns.MilestonesCrossed(kind, before, after)
    local out = {}
    for _, t in ipairs(MILESTONES[kind] or {}) do
        if (tonumber(before) or 0) < t and (tonumber(after) or 0) >= t then out[#out + 1] = t end
    end
    return out
end
function ns.MilestoneText(kind, n)
    local spec = MILESTONE_TEXT[kind]
    if not spec then return tostring(n) end
    if kind == "bosses" and n == 1 then return ns:Tr("Your first boss") end
    if kind == "runs" and n == 1 then return ns:Tr("Your first dungeon or raid run") end
    local shown = kind == "goldMade" and math.floor(n / 10000) or n
    local okB, nice = pcall(BreakUpLargeNumbers or tostring, shown)
    return format(ns:Tr(spec), (okB and type(nice) == "string") and nice or tostring(shown))
end
------------------------------------------------------------------------------------------
local function Store()
    if type(ns.root) ~= "table" then return {} end
    ns.root.lifetime = type(ns.root.lifetime) == "table" and ns.root.lifetime or {}
    return ns.root.lifetime
end
local function Mine()
    local s, key = Store(), ns:CharKey()
    s[key] = type(s[key]) == "table" and s[key] or { since = time and time() or 0 }
    return s[key]
end

-- A milestone reached: noted (once), and said with a short notice.
local function Reach(me, kind, n)
    me.milestones = type(me.milestones) == "table" and me.milestones or {}
    local key = kind .. ":" .. n
    for _, m in ipairs(me.milestones) do if m.key == key then return false end end
    me.milestones[#me.milestones + 1] = { key = key, kind = kind, n = n, at = time and time() or 0 }
    if ns.db.milestones == false then return true end
    local text = ns.MilestoneText(kind, n)
    ns:Print(format(ns:Tr("Milestone: %s!"), text))
    if ns.Flash then pcall(ns.Flash, ns, format(ns:Tr("Milestone: %s!"), text), 1, 0.82, 0.3) end
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.LEVEL_UP or 888, "Master") end
    return true
end
ns.MilestoneReach = Reach
function ns.LifetimeCount(k, n)
    if not (ns.db and ns.db.lifetimeStats) or type(n) ~= "number" or Secret(n) then return end
    local me = Mine()
    local before = tonumber(me[k]) or 0
    me[k] = before + n
    for _, t in ipairs(ns.MilestonesCrossed(k, before, me[k])) do Reach(me, k, t) end
end
-- Bosses and runs come from the run log, so they are looked at after a kill and after a run.
local function LogCounts(root, key)
    local bosses, runs = 0, 0
    for _, r in ipairs(type(root.runs) == "table" and root.runs or {}) do
        if type(r) == "table" and r.char == key then runs = runs + 1; bosses = bosses + (ns.RunKills and ns.RunKills(r) or 0) end
    end
    local now = type(root.runNow) == "table" and root.runNow[key]
    if type(now) == "table" and ns.RunKills then bosses = bosses + ns.RunKills(now) end
    return bosses, runs
end
local function CheckLog()
    if not (ns.db and ns.db.lifetimeStats) then return end
    local bosses, runs = LogCounts(type(ns.root) == "table" and ns.root or {}, ns:CharKey())
    local me = Mine()
    for kind, n in pairs({ bosses = bosses, runs = runs }) do
        local seen = tonumber(me["seen_" .. kind]) or 0
        if n > seen then
            for _, t in ipairs(ns.MilestonesCrossed(kind, seen, n)) do Reach(me, kind, t) end
            me["seen_" .. kind] = n
        end
    end
end
ns.MilestoneCheckLog = CheckLog
function ns.LifetimePlayed(total)
    if not (ns.db and ns.db.lifetimeStats) or type(total) ~= "number" or Secret(total) then return end
    Mine().played = total
end

-- The rows: { label, this character, all characters } as numbers (or nil), and the earliest "since".
function ns.LifetimeRows(store, me, runs, farm)
    local function Sum(k)
        local t = 0
        for _, c in pairs(store) do if type(c) == "table" then t = t + (tonumber(c[k]) or 0) end end
        return t
    end
    local mine = store[me] or {}
    local rows = {}
    for _, k in ipairs({ "played", "levels", "quests", "kills", "deaths", "goldMade", "goldSpent", "looted" }) do
        rows[#rows + 1] = { k, tonumber(mine[k]) or 0, Sum(k) }
    end
    -- from the run log: bosses, runs, best times
    local myBosses, allBosses, myRuns, allRuns = 0, 0, 0, 0
    for _, r in ipairs(type(runs) == "table" and runs or {}) do
        local k = ns.RunKills and ns.RunKills(r) or 0
        allBosses, allRuns = allBosses + k, allRuns + 1
        if r.char == me then myBosses, myRuns = myBosses + k, myRuns + 1 end
    end
    rows[#rows + 1] = { "bosses", myBosses, allBosses }
    rows[#rows + 1] = { "runs", myRuns, allRuns }
    -- from the farming zones: time farmed (all characters share one history)
    local farmed = 0
    for _, list in pairs(type(farm) == "table" and farm or {}) do
        for _, e in ipairs(type(list) == "table" and list or {}) do farmed = farmed + (tonumber(e.secs) or 0) end
    end
    rows[#rows + 1] = { "farmed", nil, farmed }
    local since
    for _, c in pairs(store) do
        if type(c) == "table" and tonumber(c.since) and (not since or c.since < since) then since = c.since end
    end
    return rows, since
end

local LABELS = {
    played = "Time played", levels = "Levels gained", quests = "Quests done", kills = "Kills", deaths = "Deaths",
    goldMade = "Gold made", goldSpent = "Gold spent", looted = "Items looted", bosses = "Bosses killed",
    runs = "Dungeon and raid runs", farmed = "Time farming",
}
local function Hours(secs)
    secs = math.floor(tonumber(secs) or 0)
    local d, h, m = math.floor(secs / 86400), math.floor(secs % 86400 / 3600), math.floor(secs % 3600 / 60)
    if d > 0 then return format(ns:Tr("%dd %dh"), d, h) end
    if h > 0 then return format(ns:Tr("%dh %dm"), h, m) end
    return format(ns:Tr("%dm"), m)
end
local function Show(k, v)
    if v == nil then return "-" end
    if k == "played" or k == "farmed" then return Hours(v) end
    if k == "goldMade" or k == "goldSpent" then return ns:Coins(math.floor(v / 10000) * 10000) end
    return BreakUpLargeNumbers and BreakUpLargeNumbers(v) or tostring(v)
end

function ns:ShowLifetime()
    local root = type(ns.root) == "table" and ns.root or {}
    local rows, since = ns.LifetimeRows(Store(), ns:CharKey(), root.runs, root.farmZones)
    local lines = { { left = " ", right = ns:AccentHex() .. ns:Tr("This character") .. "  /  " .. ns:Tr("All characters") .. "|r" } }   -- (11.17.1: over the numbers it names)
    for _, r in ipairs(rows) do
        local mine = r[2] ~= nil and Show(r[1], r[2]) or ""
        lines[#lines + 1] = { left = ns:Tr(LABELS[r[1]] or r[1]), right = (mine ~= "" and (mine .. "  |cff9aa4b4/|r  ") or "") .. Show(r[1], r[3]) }
    end
    -- the best runs, place by place
    local places = ns.RunPlaces and ns.RunPlaces(root.runs) or {}
    if #places > 0 then
        lines[#lines + 1] = { left = " " }
        lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Best times") .. "|r", click = function() ns:ShowRuns() end }
        for i, p in ipairs(places) do
            if i > 8 then break end
            if p.best then lines[#lines + 1] = { left = "    " .. p.instance, right = ns.RunClock(ns.RunLength(p.best)), click = function() ns:ShowRuns() end } end
        end
    end
    -- the milestones this character has reached, latest first
    local mine = Store()[ns:CharKey()]
    local ms = type(mine) == "table" and type(mine.milestones) == "table" and mine.milestones or {}
    if #ms > 0 then
        local sorted = {}
        for _, m in ipairs(ms) do sorted[#sorted + 1] = m end
        table.sort(sorted, function(a, b) return (a.at or 0) > (b.at or 0) end)
        lines[#lines + 1] = { left = " " }
        lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Milestones") .. "|r" }
        for i, m in ipairs(sorted) do
            if i > 12 then break end
            local okD, day = pcall(date, "%d %b %Y", m.at or 0)
            lines[#lines + 1] = { left = "    " .. ns.MilestoneText(m.kind, m.n), right = "|cff9aa4b4" .. (okD and day or "") .. "|r" }
        end
    end
    local note = since and format(ns:Tr("Counted since %s. Bosses, runs and farming reach back as far as the run log and farming sessions do. Kills are counted from the experience they give, so not at the level cap."),
        (pcall(date, "%d %b %Y", since) and date("%d %b %Y", since)) or "") or ""
    ns:ShowList("Lifetime", "Lifetime stats", lines, note, 440, math.min(460, 90 + #lines * 18))
    return rows
end

ns:NewModule("lifetimeStats", function()
    local me = Mine()                                          -- (so "since" starts today for this character)
    -- bosses and runs already in the log when milestones began are counted as seen, not celebrated
    if me.seen_bosses == nil then
        me.seen_bosses, me.seen_runs = LogCounts(type(ns.root) == "table" and ns.root or {}, ns:CharKey())
    end
    local patterns = ns.LootPatterns({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_SELF or "You receive loot: %s.",
        LOOT_ITEM_PUSHED_SELF_MULTIPLE or "You receive item: %sx%d.", LOOT_ITEM_PUSHED_SELF or "You receive item: %s." })
    local lastMoney
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "CHAT_MSG_LOOT", "ENCOUNTER_END", "ZONE_CHANGED_NEW_AREA" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Lifetime stats", function(_, event, msg)
        if event == "ENCOUNTER_END" or event == "ZONE_CHANGED_NEW_AREA" then
            ns:After(2, function() pcall(CheckLog) end)           -- (after the run log has written it down)
            return
        end
        if event == "CHAT_MSG_LOOT" then
            if type(msg) ~= "string" or Secret(msg) then return end
            local link, count = ns.ParseLoot(msg, patterns)
            if link then ns.LifetimeCount("looted", tonumber(count) or 1) end
            return
        end
        local ok, m = pcall(GetMoney)
        if not ok or type(m) ~= "number" or Secret(m) then return end
        if event == "PLAYER_MONEY" and lastMoney then
            local d = m - lastMoney
            if d > 0 then ns.LifetimeCount("goldMade", d) elseif d < 0 then ns.LifetimeCount("goldSpent", -d) end
        end
        lastMoney = m
    end))
end)
