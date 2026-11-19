local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Farming sessions (11.13): /fgui farm starts one, /fgui farm again shows it, /fgui farm stop ends it.
-- While it runs, a small panel shows how long you have been at it and what it is making an hour: the
-- gold you made, and what the items you looted are worth (the auction price you have seen for them,
-- or the vendor's, whichever is more). The session window lists every item with its count and value.
-- A /reload keeps the session going; each finished session counts in that week's recap.
------------------------------------------------------------------------------------------
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

function ns:Farm(text)
    local cmd = ns.Trim(text or ""):lower()
    local store, key = Store(), ns:CharKey()
    local s = store[key]
    if cmd == "stop" or cmd == "end" then
        if type(s) ~= "table" then ns:Print("No farming session is running. /fgui farm starts one.") return end
        local t = ns.FarmTotals(s, Now(), Money())
        ToRecap(t)
        store[key] = nil
        ns:Print(format(ns:Tr("Farming ended after %s: %s made, %s in items (%s an hour)."), Clock(t.secs), Gold(t.gold), Gold(t.value), Gold(t.totalHour)))
        Refresh()
        return t
    end
    if type(s) ~= "table" then
        if not ns.db.farming then ns:Print("Farming sessions are switched off (Features tab).") return end
        store[key] = { started = Now(), resumed = Now(), elapsed = 0, gold = 0, moneyMark = Money(), items = {} }
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
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "PLAYER_MONEY", "CHAT_MSG_LOOT" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Farming", function(_, event, message)
        local s = Current()
        if type(s) ~= "table" then return end
        if event == "CHAT_MSG_LOOT" then
            if type(message) ~= "string" or Secret(message) then return end
            local link, count = ns.ParseLoot(message, patterns)
            if link then
                local ok, vendor = pcall(function() return (select(11, ns:GetItemInfo(link))) end)
                ns.FarmAdd(s, link, count, ok and vendor or nil)
            end
        elseif event == "PLAYER_LOGOUT" then
            -- bank the time and gold so far; the clock stops while you are away
            local m = Money()
            if s.resumed then s.elapsed = (tonumber(s.elapsed) or 0) + math.max(0, Now() - s.resumed); s.resumed = nil end
            if m and s.moneyMark then s.gold = (tonumber(s.gold) or 0) + (m - s.moneyMark) end
            s.moneyMark = nil
        elseif event == "PLAYER_ENTERING_WORLD" then
            if not s.resumed then s.resumed = Now() end
            if not s.moneyMark then s.moneyMark = Money() end
        end
        Refresh()
    end))
    ns:Every(1, "Farming", function() if panel and panel:IsShown() then Refresh() end end)
end)
