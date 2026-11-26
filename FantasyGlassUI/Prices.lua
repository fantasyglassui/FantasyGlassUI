local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Prices: one store per auction house (realm and faction), shared by all your characters there.
-- What you see while browsing (Economy.lua), and what Scan prices reads (PriceScan.lua), goes in here;
-- tooltips, the auction house helper, farming and the sell hints read it through the functions below.
--   ns.root.prices = { v = 1, lastScan, migrated, houses = { ["Realm|Faction"] = { items = { [itemID] =
--     { price, day, hist, listed, listedDay, seenDay } }, scanAt, listedAt, scanItems } } }
-- Prices are never mixed between factions. The game cannot say whether a neutral auction house is open,
-- so a neutral one shares its faction's prices; a neutral character (a pandaren before choosing) has no
-- house at all. Connected realms each keep their own prices: Forever cannot list the connected realms.
------------------------------------------------------------------------------------------

-- The current auction house's key, or nil while the realm or faction can't be read, or for a neutral
-- character. Kept for the session; let go when the realm or faction could change.
local cachedKey
function ns.PriceHouseKey()
    if cachedKey then return cachedKey end
    local okR, realm = pcall(GetRealmName)
    local okF, faction = pcall(UnitFactionGroup, "player")
    if not okR or not okF or Secret(realm) or Secret(faction) then return nil end
    if type(realm) ~= "string" or realm == "" or (faction ~= "Alliance" and faction ~= "Horde") then return nil end
    cachedKey = realm .. "|" .. faction
    return cachedKey
end
function ns.PriceHouseKeyReset() cachedKey = nil end

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
-- The old account-wide prices, while they wait to move into the house where you first open the
-- auction house: until then they are read (never written) as this house's, as they always were.
local function Unmoved()
    local root = ns.root
    if type(root) ~= "table" or type(root.auctionSeen) ~= "table" then return nil end
    if type(root.prices) == "table" and root.prices.migrated then return nil end
    if not ns.PriceHouseKey() then return nil end
    return root.auctionSeen
end
-- The current house's items, for reading only. With no house, an empty table that is never kept.
function ns.PriceItems()
    local old = Unmoved()
    if old then return old end
    local h = ns.PriceHouse()
    return (h and type(h.items) == "table") and h.items or {}
end
function ns.PriceEntry(id)
    if Secret(id) or type(id) ~= "number" then return nil end
    local e = ns.PriceItems()[id]
    if type(e) ~= "table" or type(e.day) ~= "number" or (e.price ~= nil and type(e.price) ~= "number") then return nil end   -- (an odd old entry)
    return e
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
    e.seenDay = today                                     -- (seen listed: a scan from before can't say nobody lists it)
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
            local clean = Clean(e)
            if type(have) == "table" and type(have.day) == "number" then
                -- both kept a history: one history, the lower price each day, the last 14 days
                local later = (e.day > have.day) and clean or have
                local merged = { price = later.price, day = later.day, listed = have.listed, listedDay = have.listedDay, seenDay = have.seenDay }
                for _, src in ipairs({ have, clean }) do
                    for d, pr in pairs(type(src.hist) == "table" and src.hist or {}) do
                        if type(d) == "number" and type(pr) == "number" then ns.AuctionHistoryAdd(merged, d, pr) end
                    end
                end
                h.items[id] = merged
            else
                h.items[id] = clean
            end
            moved = moved + 1
        end
    end
    if type(root.prices) ~= "table" then root.prices = { v = 1 } end
    root.auctionSeen = nil
    root.prices.migrated = true
    return moved
end

-- The old prices moved in and this house's prices not seen for two months let go, at once (for the tests).
function ns.PricesStart(root, key, today)
    local moved = ns.PricesMigrate(root, key)
    local h = House(root, key, false)
    local gone = (h and type(h.items) == "table") and ns.AuctionForget(h.items, today, 60) or 0
    return moved, gone
end

-- At login only the current house is cleaned, a slice a frame (4 ms, or 200 entries with no clock).
local forget                                          -- { items, key, today }
function ns.PricesForgetStep()
    local f = forget
    if not f then return false end
    local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
    local start, n = clock and clock(), 0
    while true do
        local ok, id, e = pcall(next, f.items, f.key)
        if not ok then forget = nil; return false end     -- (the list changed under us: the rest waits for the next login)
        if id == nil then forget = nil; return false end
        f.key = id
        if type(e) ~= "table" or type(e.day) ~= "number" or ns.DaysBetween(e.day, f.today) > 60 then
            f.items[id] = nil                             -- (clearing the current key is allowed while walking)
        end
        n = n + 1
        if (clock and clock() - start >= 4) or (not clock and n >= 200) then return true end
    end
end
local runner
function ns.PricesForget(items, today)
    forget = type(items) == "table" and { items = items, today = today } or nil
    if forget and runner then runner:Show() end
end
local started = false
function ns.PricesBegin()
    if started or type(ns.root) ~= "table" then return end
    started = true
    local h = House(ns.root, ns.PriceHouseKey(), false)
    if h then ns.PricesForget(h.items, ns.Today()) end
end

do
    local ev = CreateFrame("Frame")
    runner = CreateFrame("Frame")                         -- (shown only while there is cleaning to do)
    runner:Hide()
    for _, e in ipairs({ "PLAYER_LOGIN", "NEUTRAL_FACTION_SELECT_RESULT", "UNIT_FACTION", "AUCTION_HOUSE_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Prices", function(_, event, unit)
        if ns.safeMode then return end                    -- (safe mode: every feature is off, this too)
        if event == "UNIT_FACTION" then
            if not Secret(unit) and unit == "player" then cachedKey = nil end
        elseif event == "AUCTION_HOUSE_SHOW" then
            -- the old prices move into the house where you first open the auction house, once
            if type(ns.root) == "table" then ns.PricesMigrate(ns.root, ns.PriceHouseKey()) end
        else
            cachedKey = nil
        end
    end))
    runner:SetScript("OnUpdate", ns:Guard("Prices", function(self)
        if ns.safeMode or not (forget and ns.PricesForgetStep()) then self:Hide() end
    end))
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

------------------------------------------------------------------------------------------
-- The item tooltip: the price lines (Auction prices in tooltips), then the Sell now / Hold / Vendor
-- it line (SellHints.lua), always in that order, from one hook that either feature puts in place.
------------------------------------------------------------------------------------------
-- Is the item under this tooltip bound to you? From its place in your bags (data.guid), else from the
-- game's own "Soulbound" lines. Nil when it can't be told.
local BOUND_LINES = { "ITEM_SOULBOUND", "ITEM_ACCOUNTBOUND", "ITEM_BNETACCOUNTBOUND" }
function ns.TooltipItemBound(data)
    if type(data) ~= "table" then return nil end
    local guid = data.guid
    local I = C_Item
    if guid ~= nil and not Secret(guid) and type(I) == "table" and type(I.GetItemLocation) == "function" and type(I.IsBound) == "function" then
        local okL, loc = pcall(I.GetItemLocation, guid)
        if okL and type(loc) == "table" then
            local okB, bound = pcall(I.IsBound, loc)
            if okB and not Secret(bound) and bound ~= nil then return bound and true or false end
        end
    end
    if type(data.lines) == "table" then
        for _, line in ipairs(data.lines) do
            local text = type(line) == "table" and line.leftText
            if type(text) == "string" and not Secret(text) then
                for _, name in ipairs(BOUND_LINES) do
                    local want = _G[name]
                    if type(want) == "string" and want ~= "" and text == want then return true end
                end
            end
        end
    end
    return nil
end
function ns.PriceTooltip(tooltip, data)
    if tooltip ~= GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
    local id = type(data) == "table" and data.id
    if Secret(id) then return end
    if type(id) ~= "number" and tooltip.GetItem then local ok, _, link = pcall(tooltip.GetItem, tooltip); if ok then id = ns:ItemIDOf(link) end end
    if Secret(id) or type(id) ~= "number" then return end
    if ns.db.auctionMemory then
        local e = ns.PriceEntry(id)
        local when = ns.AuctionSeenText(e, ns.Today())
        if when then tooltip:AddDoubleLine(ns:Tr("Auction house") .. " (" .. ns:Tr(when) .. ")", ns:Coins(e.price), 0.6, 0.8, 1, 1, 1, 1) end
        local usual, days = ns.AuctionUsual(e)
        if usual and days >= 2 then tooltip:AddDoubleLine(format(ns:Tr("Usual price (%d days)"), days), ns:Coins(usual), 0.6, 0.8, 1, 1, 1, 1) end
    end
    if ns.db.sellHints and ns.SellHintLine then
        local text, fresh, kind = ns.SellHintLine(id, ns.TooltipItemBound(data))
        local c = text and ns.SELL_HINT_COLOR[kind]
        if c then tooltip:AddDoubleLine(text, fresh or "", c[1], c[2], c[3], 0.7, 0.7, 0.7) end
    end
end
local hooked = false
function ns.PriceTooltipHook()
    if hooked then return end
    hooked = true
    local safe = ns:Guard("Auction prices", ns.PriceTooltip)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, safe)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", safe)
    end
end
