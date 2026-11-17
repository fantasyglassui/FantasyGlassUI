local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Auction house helper (11.7): built on the prices you have seen there (auction prices in
-- tooltips). On the sell page, "Lowest -1c" fills in a price one copper under the lowest one
-- seen for that item today. "Worth selling" (and /fgui ah) lists what in your bags is worth more at
-- the auction house than at a vendor, best first; click one to put it on the sell page. Posting
-- is always your own click: the game allows nothing else.
------------------------------------------------------------------------------------------
local function Seen() return (type(ns.root) == "table" and type(ns.root.auctionSeen) == "table") and ns.root.auctionSeen or {} end

-- The price to post at: one copper under today's lowest, never under the vendor price. nil if none.
function ns.UndercutPrice(entry, today, vendor)
    if type(entry) ~= "table" or type(entry.price) ~= "number" then return nil end
    local base = entry.price
    if entry.day ~= today then
        local usual = ns.AuctionUsual and ns.AuctionUsual(entry)
        base = usual or base
    end
    local p = math.max(1, base - 1)
    if type(vendor) == "number" and vendor > 0 then p = math.max(p, vendor + 1) end
    return p
end
-- What in the bags is worth selling there: items = { { id, count, vendor, bound, link } }.
-- Returns { item, price, total } for those whose auction price beats the vendor's by half again.
function ns.WorthSelling(items, seen, today)
    local out = {}
    for _, it in ipairs(items) do
        local e = seen[it.id]
        if not it.bound and type(e) == "table" and type(e.price) == "number" then
            local price = (e.day == today) and e.price or (ns.AuctionUsual(e) or e.price)
            local vendor = it.vendor or 0
            if price >= 100 and price >= vendor * 1.5 then
                out[#out + 1] = { item = it, price = price, total = price * (it.count or 1) }
            end
        end
    end
    table.sort(out, function(a, b) return a.total > b.total end)
    return out
end
local function BagItems()
    local C = C_Container
    local out = {}
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
    for bag = 0, tonumber(NUM_BAG_SLOTS) or 4 do
        for slot = 1, tonumber(C.GetContainerNumSlots(bag)) or 0 do
            local info = C.GetContainerItemInfo(bag, slot)
            if type(info) == "table" and type(info.itemID) == "number" and not info.hasNoValue then
                local vendor = select(11, ns:GetItemInfo(info.itemID))
                out[#out + 1] = { id = info.itemID, count = info.stackCount or 1, vendor = tonumber(vendor) or 0,
                    bound = info.isBound == true, link = info.hyperlink, bag = bag, slot = slot }
            end
        end
    end
    return out
end
local function PutOnSellPage(it)
    if InCombatLockdown() then return false end
    local ahf = _G.AuctionHouseFrame
    if type(ahf) == "table" and ahf.SetPostItem and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        return pcall(ahf.SetPostItem, ahf, ItemLocation:CreateFromBagAndSlot(it.bag, it.slot))
    end
    if C_Container and C_Container.PickupContainerItem and ClickAuctionSellItemButton then          -- (the older auction house)
        pcall(C_Container.PickupContainerItem, it.bag, it.slot)
        pcall(ClickAuctionSellItemButton)
        if ClearCursor then pcall(ClearCursor) end
        return true
    end
    return false
end
function ns:ShowWorthSelling()
    local list = ns.WorthSelling(BagItems(), Seen(), ns.Today())
    local lines = {}
    for _, w in ipairs(list) do
        lines[#lines + 1] = {
            left = tostring(w.item.link or ("item " .. w.item.id)) .. ((w.item.count or 1) > 1 and (" x" .. w.item.count) or ""),
            right = ns:Coins(w.price) .. "  |cff9aa4b4" .. ns:Tr("vendor") .. " " .. ns:Coins(w.item.vendor) .. "|r",
            click = function() if not PutOnSellPage(w.item) then ns:Print("Open the auction house's sell page first.") end end,
        }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("Nothing in your bags is worth more there than at a vendor, from the prices you have seen.") }
    else
        local total = 0
        for _, w in ipairs(list) do total = total + w.total end
        table.insert(lines, 1, { left = ns:AccentHex() .. ns:Tr("In all") .. "|r", right = ns:Coins(total) })
    end
    ns:ShowList("WorthSelling", "Worth selling at the auction house", lines,
        "From the prices you have seen. Click one to put it on the sell page.", 480, math.min(420, 80 + #lines * 18))
    return #list
end

-- The item on a sell page, and fill in the price.
local function SellPageItemID(sf)
    if type(sf) ~= "table" or not sf.GetItem then return nil end
    local ok, loc = pcall(sf.GetItem, sf)
    if not ok or type(loc) ~= "table" or not (C_Item and C_Item.GetItemID) then return nil end
    local okI, id = pcall(C_Item.GetItemID, loc)
    return okI and type(id) == "number" and id or nil
end
local function SetSellPrice(sf, price)
    local input = sf and (sf.PriceInput or sf.UnitPriceInput)
    if type(input) == "table" and input.SetAmount then
        local ok = pcall(input.SetAmount, input, price)
        if sf.OnPriceChanged then pcall(sf.OnPriceChanged, sf) end
        return ok
    end
    return false
end
function ns:UndercutOn(sf)
    local id = SellPageItemID(sf)
    if not id then ns:Print("Put an item on the sell page first."); return nil end
    local vendor = tonumber((select(11, ns:GetItemInfo(id)))) or 0
    local price = ns.UndercutPrice(Seen()[id], ns.Today(), vendor)
    if not price then ns:Print("No price seen for that item yet: search for it once."); return nil end
    if not SetSellPrice(sf, price) then ns:Print("This auction house's sell page could not be filled in."); return nil end
    return price
end

ns:NewModule("auctionHelper", function()
    local done = false
    local function Dress()
        local ahf = _G.AuctionHouseFrame
        if done or type(ahf) ~= "table" then return false end
        done = true
        local worth = ns:CreateButton(ahf, "Worth selling", 120, 22, function() ns:ShowWorthSelling() end)
        worth:SetPoint("TOPRIGHT", ahf, "TOPRIGHT", -60, -30)
        for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
            local sf = ahf[key]
            if type(sf) == "table" then
                local b = ns:CreateButton(sf, "Lowest -1c", 96, 20, function() ns:UndercutOn(sf) end)
                local input = sf.PriceInput or sf.UnitPriceInput
                if type(input) == "table" then b:SetPoint("LEFT", input, "RIGHT", 10, 0) else b:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -10, -10) end
            end
        end
        return true
    end
    ns.auctionHelperTest = { Dress = Dress }
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "ADDON_LOADED")
    pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
    ev:SetScript("OnEvent", ns:Guard("Auction house helper", function(_, event, name)
        if event == "AUCTION_HOUSE_SHOW" or (not Secret(name) and name == "Blizzard_AuctionHouseUI") then pcall(Dress) end
    end))
end)
