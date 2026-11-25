local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Prices: one store per auction house (realm and faction), shared by all your characters there.
-- What you see while browsing (Economy.lua), and what Scan prices reads (PriceScan.lua), goes in here;
-- tooltips, the auction house helper, farming and the sell hints read it through the functions below.
--   ns.root.prices = { v = 1, lastScan, migrated, houses = { ["Realm|Faction"] = { items = { [itemID] =
--     { price, day, hist, listed, listedDay } }, scanAt, scanItems } } }
-- Prices are never mixed between factions. The game cannot say whether a neutral auction house is open,
-- so a neutral one shares its faction's prices.
------------------------------------------------------------------------------------------

-- The current auction house's key, or nil while the realm or faction can't be read.
function ns.PriceHouseKey()
    local okR, realm = pcall(GetRealmName)
    local okF, faction = pcall(UnitFactionGroup, "player")
    if not okR or not okF or Secret(realm) or Secret(faction) then return nil end
    if type(realm) ~= "string" or type(faction) ~= "string" or realm == "" or faction == "" then return nil end
    return realm .. "|" .. faction
end

-- A house record in a saved root; the tables are made only when `create` is set.
local function House(root, key, create)
    if type(root) ~= "table" or type(key) ~= "string" then return nil end
    local p = root.prices
    if type(p) ~= "table" then
        if not create then return nil end
        p = { v = 1 }
        root.prices = p
    end
    if type(p.houses) ~= "table" then
        if not create then return nil end
        p.houses = {}
    end
    local h = p.houses[key]
    if type(h) ~= "table" then
        if not create then return nil end
        h = {}
        p.houses[key] = h
    end
    if create and type(h.items) ~= "table" then h.items = {} end
    return h
end
function ns.PriceHouse(create)
    return House(ns.root, ns.PriceHouseKey(), create)
end
-- The current house's items, for reading only. With no house, an empty table that is never kept.
function ns.PriceItems()
    local h = ns.PriceHouse()
    return (h and type(h.items) == "table") and h.items or {}
end
function ns.PriceEntry(id)
    if Secret(id) or type(id) ~= "number" then return nil end
    local e = ns.PriceItems()[id]
    return type(e) == "table" and e or nil
end

-- A price seen while browsing: today's lowest, and the day's low for the usual price. False when ignored.
function ns.PriceNote(id, price)
    if Secret(id) or Secret(price) or type(id) ~= "number" or type(price) ~= "number" or price <= 0 then return false end
    local h = ns.PriceHouse(true)
    if not h then return false end
    local today = ns.Today()
    local e = h.items[id]
    if type(e) ~= "table" then e = {}; h.items[id] = e end
    if e.day ~= today or type(e.price) ~= "number" or price < e.price then e.price, e.day = price, today end
    ns.AuctionHistoryAdd(e, today, price)
    return true
end

-- An old entry, cleaned: only what is a number is kept.
local function Clean(e)
    local hist
    for d, p in pairs(type(e.hist) == "table" and e.hist or {}) do
        if type(d) == "number" and type(p) == "number" then hist = hist or {}; hist[d] = p end
    end
    return { price = e.price, day = e.day, hist = hist }
end
-- The old prices (ns.root.auctionSeen, one list for every realm) go into the current house, once.
-- With no key it does nothing and keeps them for the next start. Returns how many went in.
function ns.PricesMigrate(root, key)
    if type(root) ~= "table" or type(key) ~= "string" then return 0 end
    if type(root.prices) == "table" and root.prices.migrated then return 0 end
    local moved = 0
    local old = root.auctionSeen
    for id, e in pairs(type(old) == "table" and old or {}) do
        if type(id) == "number" and type(e) == "table" and type(e.price) == "number" and type(e.day) == "number" then
            local h = House(root, key, true)
            local have = h.items[id]
            if type(have) ~= "table" or type(have.day) ~= "number" or e.day > have.day then
                h.items[id] = Clean(e)
                moved = moved + 1
            end
        end
    end
    if type(root.prices) ~= "table" then root.prices = { v = 1 } end
    root.auctionSeen = nil
    root.prices.migrated = true
    return moved
end

-- At start: the old prices moved in, and prices not seen for two months let go, in every house.
function ns.PricesStart(root, key, today)
    local moved = ns.PricesMigrate(root, key)
    local gone = 0
    local p = type(root) == "table" and root.prices
    for _, h in pairs((type(p) == "table" and type(p.houses) == "table") and p.houses or {}) do
        if type(h) == "table" and type(h.items) == "table" then gone = gone + ns.AuctionForget(h.items, today, 60) end
    end
    return moved, gone
end
local started = false
function ns.PricesBegin()
    if started or type(ns.root) ~= "table" then return end
    started = true
    ns.PricesStart(ns.root, ns.PriceHouseKey(), ns.Today())
end

-- How fresh the last scan of this house is, in words.
function ns.PriceFreshText(house, now)
    local at = type(house) == "table" and house.scanAt
    if type(at) ~= "number" then return ns:Tr("Never scanned") end
    now = tonumber(now) or time()
    local okA, a = pcall(date, "%Y%m%d", at)
    local okB, b = pcall(date, "%Y%m%d", now)
    a, b = okA and tonumber(a), okB and tonumber(b)
    local days = (a and b) and ns.DaysBetween(a, b) or math.floor((now - at) / 86400)
    days = math.max(0, days)
    if days == 0 then return ns:Tr("Scanned today") end
    if days == 1 then return ns:Tr("Scanned yesterday") end
    return format(ns:Tr("Scanned %d days ago"), days)
end
