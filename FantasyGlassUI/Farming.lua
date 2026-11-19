local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Farming sessions (11.13): /fgui farm starts one, /fgui farm again shows it, /fgui farm stop ends it.
-- While it runs, a small panel shows how long you have been at it and what it is making an hour: the
-- gold you made, and what the items you looted are worth (the auction price you have seen for them,
-- or the vendor's, whichever is more). The session window lists every item with its count and value.
-- A /reload keeps the session going; each finished session counts in that week's recap.
--
-- 11.14: each session also notes where you farmed - its time, gold and loot zone by zone - and
-- /fgui farm zones lists your best spots by what they make an hour, with how the latest time there
-- compares with the ones before.
------------------------------------------------------------------------------------------
local ZONE_KEEP = 20        -- sessions remembered per zone
local function Store()
    if type(ns.root) ~= "table" then return {} end
    ns.root.farming = type(ns.root.farming) == "table" and ns.root.farming or {}
    return ns.root.farming
end
local function Now() return time and time() or 0 end
local function Money()
    local ok, m = pcall(GetMoney)
    return (ok and type(m) == "number" and not Secret(m)) and m or nil
end

-- What one of an item is worth: the auction price seen (today's, or the usual one), or the vendor's.
function ns.FarmItemValue(id, vendor, seen)
    vendor = (type(vendor) == "number" and not Secret(vendor)) and vendor or 0
    local e = type(seen) == "table" and seen[id]
    local ah
    if type(e) == "table" then ah = (ns.AuctionUsual and ns.AuctionUsual(e)) or e.price end
    ah = type(ah) == "number" and ah or 0
    return math.max(vendor, ah), ah > vendor and "ah" or "vendor"
end

-- A session's totals: seconds, gold made, item value, and both an hour. (`now` and `money` given for the tests.)
function ns.FarmTotals(s, now, money)
    if type(s) ~= "table" then return nil end
    local secs = math.max(1, (tonumber(s.elapsed) or 0) + ((s.resumed and (now or Now()) - s.resumed) or 0))
    local gold = (tonumber(s.gold) or 0) + ((money and s.moneyMark) and (money - s.moneyMark) or 0)
    local value = 0
    local seen = type(ns.root) == "table" and ns.root.auctionSeen or nil
    for id, it in pairs(type(s.items) == "table" and s.items or {}) do
        value = value + (ns.FarmItemValue(id, it.vendor, seen)) * (tonumber(it.n) or 0)
    end
    local hours = secs / 3600
    return { secs = secs, gold = gold, value = value, goldHour = gold / hours, valueHour = value / hours, totalHour = (gold + value) / hours }
end

-- An item looted during the session.
function ns.FarmAdd(s, link, count, vendor)
    if type(s) ~= "table" or type(link) ~= "string" or Secret(link) then return false end
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if not id then return false end
    s.items = type(s.items) == "table" and s.items or {}
    local it = s.items[id] or { n = 0 }
    it.n = (tonumber(it.n) or 0) + (tonumber(count) or 1)
    it.link = link
    if type(vendor) == "number" and not Secret(vendor) then it.vendor = vendor end
    s.items[id] = it
    return true
end

-- Zone by zone, within a session: { [zone] = { secs, gold, items = { [id] = { n, vendor } } } }.
local function ZoneName()
    local ok, z = pcall(GetRealZoneText)
    if ok and type(z) == "string" and z ~= "" and not Secret(z) then return z end
    return nil
end
local function ZoneEntry(s, zone)
    s.zones = type(s.zones) == "table" and s.zones or {}
    zone = zone or s.zone
    if type(zone) ~= "string" then return nil end
    s.zones[zone] = type(s.zones[zone]) == "table" and s.zones[zone] or { secs = 0, gold = 0, items = {} }
    return s.zones[zone]
end
-- Close the time spent in the zone so far, and start counting in `zone` (nil: stop the clock).
function ns.FarmZoneSwitch(s, zone, now)
    if type(s) ~= "table" then return end
    now = now or Now()
    if s.zone and s.zoneSince then
        local e = ZoneEntry(s)
        if e then e.secs = (tonumber(e.secs) or 0) + math.max(0, now - s.zoneSince) end
    end
    s.zone, s.zoneSince = zone, zone and now or nil
end
-- Gold and loot into the zone you are in.
function ns.FarmZoneGold(s, delta)
    local e = ZoneEntry(s)
    if e and type(delta) == "number" then e.gold = (tonumber(e.gold) or 0) + delta end
end
function ns.FarmZoneItem(s, id, count, vendor)
    local e = ZoneEntry(s)
    if not (e and id) then return end
    e.items = type(e.items) == "table" and e.items or {}
    local it = e.items[id] or { n = 0 }
    it.n = (tonumber(it.n) or 0) + (tonumber(count) or 1)
    if type(vendor) == "number" then it.vendor = vendor end
    e.items[id] = it
end
-- At the end of a session, each zone's share goes into the zone's history:
-- root.farmZones[zone] = { { at, secs, gold, value }, ... } (newest last, the last 20 kept).
function ns.FarmZonesSave(s, history, now)
    if type(s) ~= "table" or type(history) ~= "table" then return 0 end
    ns.FarmZoneSwitch(s, nil, now)
    local seen = type(ns.root) == "table" and ns.root.auctionSeen or nil
    local n = 0
    for zone, e in pairs(type(s.zones) == "table" and s.zones or {}) do
        if type(e) == "table" and (tonumber(e.secs) or 0) >= 60 then        -- (a minute passing through is not farming there)
            local value = 0
            for id, it in pairs(type(e.items) == "table" and e.items or {}) do value = value + (ns.FarmItemValue(id, it.vendor, seen)) * (tonumber(it.n) or 0) end
            history[zone] = type(history[zone]) == "table" and history[zone] or {}
            local list = history[zone]
            list[#list + 1] = { at = now or Now(), secs = e.secs, gold = e.gold or 0, value = value }
            while #list > ZONE_KEEP do table.remove(list, 1) end
            n = n + 1
        end
    end
    return n
end
-- The zones, best first: { zone, perHour (all its time together), last (the latest time there, an
-- hour), before (the times before it, an hour), times, secs }.
function ns.FarmZoneRanking(history)
    local out = {}
    for zone, list in pairs(type(history) == "table" and history or {}) do
        local secs, made, n = 0, 0, 0
        for _, r in ipairs(type(list) == "table" and list or {}) do
            secs = secs + (tonumber(r.secs) or 0); made = made + (tonumber(r.gold) or 0) + (tonumber(r.value) or 0); n = n + 1
        end
        if n > 0 and secs > 0 then
            local last = list[#list]
            local lastHour = ((tonumber(last.gold) or 0) + (tonumber(last.value) or 0)) / math.max(1, tonumber(last.secs) or 0) * 3600
            local before
            if n > 1 then
                local bs, bm = secs - (tonumber(last.secs) or 0), made - ((tonumber(last.gold) or 0) + (tonumber(last.value) or 0))
                if bs > 0 then before = bm / bs * 3600 end
            end
            out[#out + 1] = { zone = zone, perHour = made / secs * 3600, last = lastHour, before = before, times = n, secs = secs }
        end
    end
    table.sort(out, function(a, b) return a.perHour > b.perHour end)
    return out
end
local function ZoneHistory()
    if type(ns.root) ~= "table" then return {} end
    ns.root.farmZones = type(ns.root.farmZones) == "table" and ns.root.farmZones or {}
    return ns.root.farmZones
end

local function Current() return Store()[ns:CharKey()] end
local function Clock(secs)
    secs = math.floor(secs)
    return format("%d:%02d:%02d", math.floor(secs / 3600), math.floor(secs % 3600 / 60), secs % 60)
end
local function Gold(c) return ns:Coins(math.floor(math.max(0, c) / 100) * 100) end      -- (gold and silver; copper is noise here)

local panel
local function Panel()
    if panel then return panel end
    panel = CreateFrame("Frame", "FantasyGlassUIFarm", UIParent, ns.template)
    panel:SetSize(230, 46)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -160)
    panel:SetBackdrop(ns.BACKDROP)
    ns:Paint(panel, "SetBackdropColor", "window", 0.9)
    ns:Paint(panel, "SetBackdropBorderColor", "@border", 1)
    panel.top = ns:NewText(panel, 12, "LEFT", true)
    panel.top:SetPoint("TOPLEFT", 8, -7); panel.top:SetPoint("TOPRIGHT", -8, -7)
    ns:Paint(panel.top, "SetTextColor", "@accent")
    panel.bottom = ns:NewText(panel, 11, "LEFT")
    panel.bottom:SetPoint("BOTTOMLEFT", 8, 7); panel.bottom:SetPoint("BOTTOMRIGHT", -8, 7)
    panel:EnableMouse(true)
    panel:SetScript("OnMouseUp", function() ns:Farm("") end)
    local entry = ns:RegisterMovable(panel, "farmPanel", "Farming")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
    panel:Hide()
    return panel
end
local function Refresh()
    local s = Current()
    if not (ns.db and ns.db.farming) or type(s) ~= "table" then if panel then panel:Hide() end return end
    local p = Panel()
    local t = ns.FarmTotals(s, Now(), Money())
    p.top:SetText(format(ns:Tr("Farming %s"), Clock(t.secs)))
    p.bottom:SetText(format(ns:Tr("%s an hour (%s gold, %s items)"), Gold(t.totalHour), Gold(t.goldHour), Gold(t.valueHour)))
    p:Show()
end
ns.FarmRefresh = Refresh

-- Into the week's recap: the session's time, gold and item value.
local function ToRecap(t)
    if ns.RecapAddFarm then pcall(ns.RecapAddFarm, t.secs, t.gold, t.value) end
end

-- /fgui farm zones: the best places you have farmed.
function ns:FarmZones()
    local list = ns.FarmZoneRanking(ZoneHistory())
    local lines = {}
    for _, z in ipairs(list) do
        local trend = ""
        if z.before and z.before > 0 then
            local change = (z.last - z.before) / z.before
            if change >= 0.1 then trend = "  " .. ns:SignalHex("good") .. format(ns:Tr("up %d%%"), math.floor(change * 100 + 0.5)) .. "|r"
            elseif change <= -0.1 then trend = "  " .. ns:SignalHex("bad") .. format(ns:Tr("down %d%%"), math.floor(-change * 100 + 0.5)) .. "|r"
            else trend = "  |cff9aa4b4" .. ns:Tr("steady") .. "|r" end
        end
        lines[#lines + 1] = { left = z.zone .. "  |cff9aa4b4" .. format(ns:TrN(z.times, "%d time", "%d times"), z.times) .. "|r",
                              right = format(ns:Tr("%s an hour"), Gold(z.perHour)) .. trend,
                              tip = format(ns:Tr("Latest time there: %s an hour."), Gold(z.last)) }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No farming spots yet: a zone counts once a session spends a minute there.") } end
    ns:ShowList("FarmZones", "Best farming spots", lines, "Gold and loot an hour, all your time there together. Up or down: your latest time there against the ones before.", 480, math.min(400, 90 + #lines * 20))
    return list
end

function ns:Farm(text)
    local cmd = ns.Trim(text or ""):lower()
    if cmd == "zones" or cmd == "spots" or cmd == "best" then return ns:FarmZones() end
    local store, key = Store(), ns:CharKey()
    local s = store[key]
    if cmd == "stop" or cmd == "end" then
        if type(s) ~= "table" then ns:Print("No farming session is running. /fgui farm starts one.") return end
        local t = ns.FarmTotals(s, Now(), Money())
        ToRecap(t)
        ns.FarmZonesSave(s, ZoneHistory(), Now())
        store[key] = nil
        ns:Print(format(ns:Tr("Farming ended after %s: %s made, %s in items (%s an hour)."), Clock(t.secs), Gold(t.gold), Gold(t.value), Gold(t.totalHour)))
        Refresh()
        return t
    end
    if type(s) ~= "table" then
        if not ns.db.farming then ns:Print("Farming sessions are switched off (Features tab).") return end
        store[key] = { started = Now(), resumed = Now(), elapsed = 0, gold = 0, moneyMark = Money(), items = {}, lastMoney = Money() }
        ns.FarmZoneSwitch(store[key], ZoneName())
        ns:Print("Farming session started. /fgui farm shows it, /fgui farm stop ends it.")
        Refresh()
        return store[key]
    end
    -- the session window
    local t = ns.FarmTotals(s, Now(), Money())
    local seen = type(ns.root) == "table" and ns.root.auctionSeen or nil
    local lines = {
        { left = ns:Tr("Time"), right = Clock(t.secs) },
        { left = ns:Tr("Gold made"), right = Gold(t.gold) .. "   " .. format(ns:Tr("%s an hour"), Gold(t.goldHour)) },
        { left = ns:Tr("Items looted, worth"), right = Gold(t.value) .. "   " .. format(ns:Tr("%s an hour"), Gold(t.valueHour)) },
        { left = ns:AccentHex() .. ns:Tr("Altogether") .. "|r", right = format(ns:Tr("%s an hour"), Gold(t.totalHour)), color = { 1, 0.82, 0.3 } },
        { left = ns:AccentHex() .. ns:Tr("End this session") .. "|r", click = function() ns:Farm("stop"); ns:HideLists() end },
        { left = ns:AccentHex() .. ns:Tr("Best farming spots") .. "|r", click = function() ns:FarmZones() end },
        { left = " " },
    }
    local items = {}
    for id, it in pairs(type(s.items) == "table" and s.items or {}) do
        local each, from = ns.FarmItemValue(id, it.vendor, seen)
        items[#items + 1] = { link = it.link, n = it.n, worth = each * (tonumber(it.n) or 0), from = from }
    end
    table.sort(items, function(a, b) return a.worth > b.worth end)
    for _, it in ipairs(items) do
        lines[#lines + 1] = { left = (it.n > 1 and (it.n .. " x ") or "") .. tostring(it.link), link = it.link,
                              right = (it.worth > 0 and ns:Coins(it.worth) or "") .. (it.from == "ah" and (" |cff9aa4b4" .. ns:Tr("(auction)") .. "|r") or "") }
    end
    if #items == 0 then lines[#lines + 1] = { left = "|cff9aa4b4" .. ns:Tr("Nothing looted yet.") .. "|r" } end
    ns:ShowList("Farming", "Farming session", lines, "Item values: the auction price you have seen, or the vendor's. /fgui farm stop ends the session.", 480, 380)
    return t
end

ns:NewModule("farming", function()
    local patterns = ns.LootPatterns({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_PUSHED_SELF_MULTIPLE or "You receive item: %sx%d.",
        LOOT_ITEM_SELF or "You receive loot: %s.", LOOT_ITEM_PUSHED_SELF or "You receive item: %s." })
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_MONEY", "CHAT_MSG_LOOT", "ZONE_CHANGED_NEW_AREA" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Farming", function(_, event, message)
        local s = Current()
        if type(s) ~= "table" then return end
        if event == "CHAT_MSG_LOOT" then
            if type(message) ~= "string" or Secret(message) then return end
            local link, count = ns.ParseLoot(message, patterns)
            if link then
                local ok, vendor = pcall(function() return (select(11, ns:GetItemInfo(link))) end)
                vendor = (ok and type(vendor) == "number" and not Secret(vendor)) and vendor or nil
                if ns.FarmAdd(s, link, count, vendor) then ns.FarmZoneItem(s, tonumber(link:match("|Hitem:(%d+)")), count, vendor) end
            end
        elseif event == "PLAYER_MONEY" then
            local m = Money()
            if m and s.lastMoney then ns.FarmZoneGold(s, m - s.lastMoney) end
            s.lastMoney = m
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            ns.FarmZoneSwitch(s, ZoneName())
        elseif event == "PLAYER_LOGOUT" then
            -- bank the time and gold so far; the clock stops while you are away
            local m = Money()
            if s.resumed then s.elapsed = (tonumber(s.elapsed) or 0) + math.max(0, Now() - s.resumed); s.resumed = nil end
            if m and s.moneyMark then s.gold = (tonumber(s.gold) or 0) + (m - s.moneyMark) end
            s.moneyMark = nil
            ns.FarmZoneSwitch(s, nil)                          -- (the zone's clock stops too)
        elseif event == "PLAYER_ENTERING_WORLD" then
            if not s.resumed then s.resumed = Now() end
            if not s.moneyMark then s.moneyMark = Money() end
            s.lastMoney = Money()
            ns.FarmZoneSwitch(s, ZoneName())
        end
        Refresh()
    end))
    ns:Every(1, "Farming", function() if panel and panel:IsShown() then Refresh() end end)
end)
