local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Weekly recap (11.11): what each of your characters did in a week, from one weekly reset to the
-- next: the gold it made or spent, the time played, the levels gained, the raids and dungeons it
-- went into, and its best loot (rare and better). Kept for the last eight weeks.
--   /fgui recap        the week just finished (or this week so far, if none is finished yet)
--   /fgui recap this   this week so far
-- When a new week starts, the login briefing says the recap of the last one is ready.
------------------------------------------------------------------------------------------
local KEEP = 8

local function Store()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.weeks) ~= "table" then ns.root.weeks = {} end
    return ns.root.weeks
end
-- The week we are in: named by the minute of the next weekly reset (the same all week), or, where the
-- game does not say, by the calendar week.
function ns.RecapWeek(now, untilWeekly)
    if type(untilWeekly) == "number" then return "r" .. math.floor(((tonumber(now) or 0) + untilWeekly + 30) / 60) end
    local ok, w = pcall(date, "%Y-%W", now)
    return "w" .. (ok and tostring(w) or "0")
end
local function ThisWeek()
    local now = time and time() or 0
    local untilWeekly
    local D = C_DateAndTime
    if D and D.GetSecondsUntilWeeklyReset then
        local ok, v = pcall(D.GetSecondsUntilWeeklyReset)
        if ok and type(v) == "number" and not Secret(v) then untilWeekly = v end
    end
    return ns.RecapWeek(now, untilWeekly), now
end

-- One character's week, made if new. week = { at = first seen, chars = { [key] = entry } }
function ns.RecapEntry(weeks, week, char, now)
    weeks[week] = type(weeks[week]) == "table" and weeks[week] or { at = now, chars = {} }
    local w = weeks[week]
    w.chars = type(w.chars) == "table" and w.chars or {}
    w.chars[char] = type(w.chars[char]) == "table" and w.chars[char] or { played = 0, loot = {}, instances = {} }
    return w.chars[char]
end
-- Keep a looted item if it is among the five best of the week (quality first, then item level).
function ns.RecapLoot(entry, link, quality, ilvl)
    if type(link) ~= "string" or type(quality) ~= "number" or quality < 3 then return false end
    entry.loot = type(entry.loot) == "table" and entry.loot or {}
    for _, l in ipairs(entry.loot) do if l.link == link then return false end end
    entry.loot[#entry.loot + 1] = { link = link, q = quality, il = tonumber(ilvl) or 0 }
    table.sort(entry.loot, function(a, b) if a.q ~= b.q then return a.q > b.q end return a.il > b.il end)
    while #entry.loot > 5 do table.remove(entry.loot) end
    return true
end
-- The weeks on record, newest first; older than the newest eight are let go.
function ns.RecapPrune(weeks)
    local keys = {}
    for k, w in pairs(weeks) do if type(w) == "table" then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return (tonumber(weeks[a].at) or 0) > (tonumber(weeks[b].at) or 0) end)
    for i = KEEP + 1, #keys do weeks[keys[i]] = nil end
    for i = KEEP + 1, #keys do keys[i] = nil end
    return keys
end

-- The lines for a week. names: { [charKey] = { name, class } }.
function ns.RecapLines(week, names)
    local lines = {}
    if type(week) ~= "table" or type(week.chars) ~= "table" then return lines end
    -- the characters that did something, most played first (a log-in to check the mail is left out)
    local function Busy(e)
        if type(e) ~= "table" then return false end
        if (tonumber(e.played) or 0) >= 60 then return true end
        if (tonumber(e.goldEnd) or 0) ~= (tonumber(e.goldStart) or 0) then return true end
        if (tonumber(e.levelEnd) or 0) > (tonumber(e.levelStart) or 0) then return true end
        return (type(e.loot) == "table" and #e.loot > 0) or (type(e.instances) == "table" and next(e.instances) ~= nil)
    end
    local keys = {}
    for k, e in pairs(week.chars) do if Busy(e) then keys[#keys + 1] = k end end
    if #keys == 0 then return lines end
    table.sort(keys, function(a, b)
        local pa, pb = tonumber(week.chars[a].played) or 0, tonumber(week.chars[b].played) or 0
        if pa ~= pb then return pa > pb end
        return tostring(a) < tostring(b)
    end)
    local gold, played = 0, 0
    for _, k in ipairs(keys) do
        local e = week.chars[k]
        gold = gold + ((tonumber(e.goldEnd) or 0) - (tonumber(e.goldStart) or 0))
        played = played + (tonumber(e.played) or 0)
    end
    local function Signed(c)
        if c == 0 then return "|cff9aa4b4" .. ns:Coins(0) .. "|r" end
        return (c > 0 and (ns:SignalHex("good") .. "+") or (ns:SignalHex("bad") .. "-")) .. ns:Coins(math.abs(c)) .. "|r"
    end
    local function Hours(s)
        s = math.floor((tonumber(s) or 0) / 60)
        if s >= 60 then return format(ns:Tr("%d h %d min"), math.floor(s / 60), s % 60) end
        return format(ns:Tr("%d min"), s)
    end
    lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("All your characters") .. "|r", right = Signed(gold) .. "   " .. Hours(played) }
    for _, k in ipairs(keys) do
        local e = week.chars[k]
        local who = type(names) == "table" and names[k] or {}
        local name = who.name or tostring(k):gsub(" %- .*$", "")
        local hex = "|cffffffff"
        if who.class and ns.ClassRGB then
            local r, g, b = ns:ClassRGB(who.class)
            if r then hex = format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end
        end
        lines[#lines + 1] = { left = " " }
        lines[#lines + 1] = { left = hex .. name .. "|r", right = Signed((tonumber(e.goldEnd) or 0) - (tonumber(e.goldStart) or 0)) .. "   " .. Hours(e.played) }
        if e.levelStart and e.levelEnd and e.levelEnd > e.levelStart then
            lines[#lines + 1] = { left = "    " .. format(ns:Tr("Levels %d to %d"), e.levelStart, e.levelEnd) }
        end
        local inst = {}
        for n in pairs(type(e.instances) == "table" and e.instances or {}) do inst[#inst + 1] = n end
        table.sort(inst)
        if #inst > 0 then lines[#lines + 1] = { left = "    " .. ns:Tr("Raids and dungeons:") .. " " .. table.concat(inst, ", ") } end
        for i, l in ipairs(type(e.loot) == "table" and e.loot or {}) do
            lines[#lines + 1] = { left = "    " .. (i == 1 and (ns:Tr("Best loot:") .. " ") or "      ") .. tostring(l.link), link = l.link }
        end
    end
    return lines
end

-- Is there a finished week whose recap has not been looked at?
function ns:RecapReady()
    local weeks = Store()
    local current = ThisWeek()
    local keys = ns.RecapPrune(weeks)
    for _, k in ipairs(keys) do
        if k ~= current then return ns.root.recapSeen ~= k, k end
    end
    return false
end

function ns:ShowRecap(text)
    local weeks = Store()
    local current = ThisWeek()
    local keys = ns.RecapPrune(weeks)
    local which, title
    local wantThis = ns.Trim(text or ""):lower() == "this"
    for _, k in ipairs(keys) do
        if k ~= current and not wantThis then which, title = k, "Your last week"; break end
    end
    if not which then which, title = current, "This week so far" end
    if which ~= current and type(ns.root) == "table" then ns.root.recapSeen = which end
    local names = {}
    for key, c in pairs(type(ns.root) == "table" and type(ns.root.alts) == "table" and ns.root.alts or {}) do
        if type(c) == "table" then names[key] = { name = c.name, class = c.class } end
    end
    local lines = ns.RecapLines(weeks[which], names)
    if #lines == 0 then lines[1] = { left = ns:Tr("Nothing yet: each character's week is noted as you play it.") } end
    ns:ShowList("Recap", title, lines, "From one weekly reset to the next. /fgui recap this shows this week so far.", 520, math.min(440, 80 + #lines * 18))
    return #lines
end

ns:NewModule("weeklyRecap", function()
    local mark = GetTime()
    local patterns = ns.LootPatterns({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_PUSHED_SELF_MULTIPLE or "You receive item: %sx%d.",
        LOOT_ITEM_SELF or "You receive loot: %s.", LOOT_ITEM_PUSHED_SELF or "You receive item: %s." })
    local function Mine()
        local week, now = ThisWeek()
        return ns.RecapEntry(Store(), week, ns:CharKey(), now)
    end
    local function Note()                                     -- gold, level and time played up to now
        if type(ns.root) ~= "table" then return end
        local e = Mine()
        local okG, gold = pcall(GetMoney)
        if okG and type(gold) == "number" and not Secret(gold) then
            if e.goldStart == nil then e.goldStart = gold end
            e.goldEnd = gold
        end
        local okL, level = pcall(UnitLevel, "player")
        if okL and type(level) == "number" and not Secret(level) then
            if e.levelStart == nil then e.levelStart = level end
            e.levelEnd = level
        end
        local t = GetTime()
        e.played = (tonumber(e.played) or 0) + math.max(0, t - mark)
        mark = t
        -- the raids and dungeons this character is saved to count for the week they were done in
        local me = type(ns.root.alts) == "table" and ns.root.alts[ns:CharKey()]
        local now = time and time() or 0
        e.instances = type(e.instances) == "table" and e.instances or {}
        for _, l in ipairs(type(me) == "table" and type(me.lockouts) == "table" and me.lockouts or {}) do
            if type(l.name) == "string" and (l.ends or 0) > now then e.instances[l.name] = true end
        end
    end
    ns.recapTest = { Note = Note, Mine = Mine }
    ns:Every(300, "Weekly recap", Note)
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_MONEY", "PLAYER_LEVEL_UP", "PLAYER_LOGOUT", "UPDATE_INSTANCE_INFO", "CHAT_MSG_LOOT" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Weekly recap", function(_, event, message)
        if event == "CHAT_MSG_LOOT" then
            if type(message) ~= "string" or Secret(message) then return end
            local link = ns.ParseLoot(message, patterns)
            if not link then return end
            local function Keep(again)
                local _, _, quality, ilvl = ns:GetItemInfo(link)
                if type(quality) == "number" and not Secret(quality) then ns.RecapLoot(Mine(), link, quality, ilvl)
                elseif again then ns:After(2, function() pcall(Keep, false) end) end   -- (not known yet: once more, soon)
            end
            Keep(true)
            return
        end
        Note()
    end))
end)
