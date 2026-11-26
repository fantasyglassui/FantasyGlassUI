local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Sell now, Hold, Vendor it: in item tooltips and as a small square on the bag window, from this
-- auction house's prices (Prices.lua: what you have seen and what Scan prices read).
--   Sell now   well above its usual price today
--   Hold       cheap today, and usually worth more than a vendor pays
--   Vendor it  a vendor pays about as much, or nobody lists it here (common and uncommon items only)
-- With no price here, Auctionator's or TSM's (Prices.lua) can give Vendor it, never Sell now or Hold.
-- The tooltip line says it in words, so the colour is never the only sign.
------------------------------------------------------------------------------------------
ns.SELL_HINT_COLOR = { sell = { 0.30, 0.85, 0.40 }, hold = { 1, 0.70, 0.20 }, vendor = { 0.60, 0.60, 0.60 } }
local CUT = 1.15                             -- (the auction house's cut and the deposit)

-- What to do with an item: "sell", "hold", "vendor" or nil, the percent above or under its usual
-- price (sell and hold), and for "vendor" why ("pays": a vendor pays about as much; "unlisted").
function ns.SellHint(entry, vendor, quality, bound, today, scanDay)
    if bound then return nil end
    entry = type(entry) == "table" and entry or nil
    vendor = (type(vendor) == "number" and vendor > 0) and vendor or 0
    if vendor == 0 and not entry then return nil end
    local price = entry and type(entry.price) == "number" and entry.price or nil
    local plain = type(quality) == "number" and quality <= 2        -- (Vendor it is never said of rare and better)
    -- a vendor pays about as much
    if vendor > 0 and price and plain then
        local p = price
        if entry.day ~= today then p = ns.AuctionUsual(entry) or price end
        if p <= vendor * CUT then return "vendor", nil, "pays" end
    end
    -- nobody lists it here: a recent full scan did not find it, and it hasn't been seen listed since
    if vendor > 0 and plain and type(scanDay) == "number" and ns.DaysBetween(scanDay, today) <= 3
        and (not entry or (entry.listed == 0 and not (type(entry.seenDay) == "number" and entry.seenDay >= scanDay))) then
        return "vendor", nil, "unlisted"
    end
    -- well above or under its usual price, from a price no more than a day old
    if price and type(entry.day) == "number" and ns.DaysBetween(entry.day, today) <= 1 then
        local usual, days = ns.AuctionUsual(entry)
        if usual and usual > 0 and days >= 3 then
            if price >= usual * CUT then return "sell", math.floor((price / usual - 1) * 100 + 0.5) end
            if price <= usual * 0.80 and usual > vendor * CUT then return "hold", math.floor((1 - price / usual) * 100 + 0.5) end
        end
    end
    return nil
end

-- The day of this house's last full scan (one that could say what nobody lists), or nil.
local function ListedDay(house)
    local at = type(house) == "table" and house.listedAt
    if type(at) ~= "number" then return nil end
    local ok, d = pcall(date, "%Y%m%d", at)
    return ok and tonumber(d) or nil
end

-- The same, for an item: reads the game and the store. `bound` from the bag slot or the tooltip, when known.
-- (`entry` and `house` may be passed in when the caller has them already.)
function ns.SellHintFor(id, bound, entry, house)
    if Secret(id) or type(id) ~= "number" or not ns.PriceHouseKey() then return nil end
    local ok, _, _, quality, _, _, _, _, _, _, _, vendor, _, _, bindType = pcall(ns.GetItemInfo, ns, id)
    if not ok then return nil end
    if Secret(quality) or type(quality) ~= "number" then quality = nil end
    if Secret(vendor) or type(vendor) ~= "number" then vendor = 0 end
    if Secret(bindType) or type(bindType) ~= "number" then bindType = nil end
    -- (binds when picked up, a quest item, or bound to the account: none can be sold at the auction house)
    bound = ns.Yes(bound) or bindType == 1 or bindType == 4 or bindType == 7 or bindType == 8
    house = house or ns.PriceHouse()
    if entry == nil then entry = ns.PriceEntry(id) end
    local today = ns.Today()
    if not (type(entry) == "table" and type(entry.price) == "number") then
        -- (12.4.1) no price here: another add-on's (Auctionator, TSM), as safe as a price with no history:
        -- never Sell now or Hold, only Vendor it when a vendor pays about as much. The fourth value is its source.
        -- When it doesn't give that, the hint from this house's own store follows, as before ("nobody lists it").
        local other, source = ns.OtherAddonPrice(id)
        if other then
            local kind, _, why = ns.SellHint({ price = other, day = today }, vendor, quality, bound, today, nil)
            if kind == "vendor" and why == "pays" then return kind, nil, why, source end
        end
    end
    return ns.SellHint(entry, vendor, quality, bound, today, ListedDay(house))
end

-- The tooltip line for an item: text, and the right side (how fresh the prices are). Nil for no hint.
function ns.SellHintLine(id, bound)
    if Secret(id) or type(id) ~= "number" then return nil end
    local house = ns.PriceHouse()
    local entry = ns.PriceEntry(id)
    local kind, pct, why, source = ns.SellHintFor(id, bound, entry or false, house)
    if not kind then return nil end
    local text
    if kind == "sell" then text = format(ns:Tr("Sell now: %d%% above its usual price"), pct)
    elseif kind == "hold" then text = format(ns:Tr("Hold: %d%% under its usual price"), pct)
    elseif why == "unlisted" then text = ns:Tr("Vendor it: nobody lists it here")
    else text = ns:Tr("Vendor it: a vendor pays about as much") end
    if source then return text, ns:Tr("Auction house") .. " (" .. source .. ")", kind end   -- (another add-on's price: its name, in place of how fresh)
    local fresh
    if entry and type(entry.listedDay) ~= "number" then fresh = ns.AuctionSeenText(entry, ns.Today()) end   -- (only browsed: when it was seen)
    local now = time and time() or 0
    if why == "unlisted" then fresh = ns.PriceFreshText({ scanAt = type(house) == "table" and house.listedAt or nil }, now) end   -- (as old as the full scan)
    fresh = fresh or ns.PriceFreshText(house, now)
    return text, fresh, kind
end

ns:NewModule("sellHints", function()
    ns.PriceTooltipHook()                                 -- (the line itself is added by ns.PriceTooltip, after the price lines)
    ns.sellHintsTest = { Tip = ns.PriceTooltip }
end)
