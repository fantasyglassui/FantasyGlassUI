local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Sell now, Hold, Vendor it: in item tooltips and as a small square on the bag window, from this
-- auction house's prices (Prices.lua: what you have seen and what Scan prices read).
--   Sell now   well above its usual price today
--   Hold       cheap today, and usually worth more than a vendor pays
--   Vendor it  a vendor pays about as much, or nobody lists it here (uncommon and lower only)
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
    -- a vendor pays about as much
    if vendor > 0 and price then
        local p = price
        if entry.day ~= today then p = ns.AuctionUsual(entry) or price end
        if p <= vendor * CUT then return "vendor", nil, "pays" end
    end
    -- nobody lists it here (a recent scan did not find it); never for rare and better
    if vendor > 0 and type(quality) == "number" and quality <= 2 and type(scanDay) == "number"
        and ns.DaysBetween(scanDay, today) <= 3 and (not entry or entry.listed == 0) then
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

-- The day this house was last scanned, or nil.
local function ScanDay(house)
    local at = type(house) == "table" and house.scanAt
    if type(at) ~= "number" then return nil end
    local ok, d = pcall(date, "%Y%m%d", at)
    return ok and tonumber(d) or nil
end

-- The same, for an item: reads the game and the store. `bound` from the bag slot, when known.
function ns.SellHintFor(id, bound)
    if Secret(id) or type(id) ~= "number" or not ns.PriceHouseKey() then return nil end
    local ok, _, _, quality, _, _, _, _, _, _, _, vendor, _, _, bindType = pcall(ns.GetItemInfo, ns, id)
    if not ok then return nil end
    if Secret(quality) or type(quality) ~= "number" then quality = nil end
    if Secret(vendor) or type(vendor) ~= "number" then vendor = 0 end
    if Secret(bindType) or type(bindType) ~= "number" then bindType = nil end
    bound = ns.Yes(bound) or bindType == 1 or bindType == 4         -- (binds when picked up, or a quest item)
    return ns.SellHint(ns.PriceEntry(id), vendor, quality, bound, ns.Today(), ScanDay(ns.PriceHouse()))
end

-- The tooltip line for an item: text, and the right side (how fresh the prices are). Nil for no hint.
function ns.SellHintLine(id, bound)
    local kind, pct, why = ns.SellHintFor(id, bound)
    if not kind then return nil end
    local text
    if kind == "sell" then text = format(ns:Tr("Sell now: %d%% above its usual price"), pct)
    elseif kind == "hold" then text = format(ns:Tr("Hold: %d%% under its usual price"), pct)
    elseif why == "unlisted" then text = ns:Tr("Vendor it: nobody lists it here")
    else text = ns:Tr("Vendor it: a vendor pays about as much") end
    local entry = ns.PriceEntry(id)
    local fresh
    if entry and type(entry.listedDay) ~= "number" then fresh = ns.AuctionSeenText(entry, ns.Today()) end   -- (only browsed: when it was seen)
    fresh = fresh or ns.PriceFreshText(ns.PriceHouse(), time and time() or 0)
    return text, fresh, kind
end

ns:NewModule("sellHints", function()
    local function Tip(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
        local id = type(data) == "table" and data.id
        if type(id) ~= "number" and tooltip.GetItem then local ok, _, link = pcall(tooltip.GetItem, tooltip); if ok then id = ns:ItemIDOf(link) end end
        if Secret(id) or type(id) ~= "number" then return end
        local text, fresh, kind = ns.SellHintLine(id)
        if not text then return end
        local c = ns.SELL_HINT_COLOR[kind]
        tooltip:AddDoubleLine(text, fresh or "", c[1], c[2], c[3], 0.7, 0.7, 0.7)
    end
    ns.sellHintsTest = { Tip = Tip }
    local safe = ns:Guard("Sell hints", Tip)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, safe)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", safe)
    end
end)
