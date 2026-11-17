local _, ns = ...

local function CoinString(copper)
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    return format("|cffffd700%dg|r |cffc7c7cf%ds|r |cffeda55f%dc|r", g, s, c)
end

-- Keep and sell lists ----------------------------------------------------------------------------------------
-- Selling junk goes by an item's color: grey is sold. Two lists, kept for the whole account, correct
-- it where that is wrong:
--   sell   always sold when junk is sold, whatever its color (a white item you never want)
--   keep   never sold automatically, even if grey (a grey item you are saving)
-- An item is on at most one of them. They are set from the bag window (Alt-click an item) or with
-- /fgui sell [item] and /fgui keep [item] (shift-click the item into the chat line).
local function List(kind)
    if not ns.root then return {} end
    local key = (kind == "keep") and "keepList" or "sellList"
    if type(ns.root[key]) ~= "table" then ns.root[key] = {} end
    return ns.root[key]
end
function ns:ItemIDOf(link)
    if type(link) == "number" then return link end
    if type(link) ~= "string" or ns:IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end
function ns:ItemListState(item)                              -- "sell", "keep" or nil
    local id = ns:ItemIDOf(item)
    if not id then return nil end
    if List("keep")[id] then return "keep" end
    if List("sell")[id] then return "sell" end
    return nil
end
function ns:SetItemList(item, state)                         -- state: "sell", "keep", or nil to take it off both
    local id = ns:ItemIDOf(item)
    if not id then return false end
    List("keep")[id] = (state == "keep") or nil
    List("sell")[id] = (state == "sell") or nil
    return true
end
-- Should this item go when junk is sold? Nothing without a price is ever sold (the vendor won't take it).
function ns:ShouldSell(link, quality, price)
    if type(price) ~= "number" or price <= 0 then return false end
    if ns.db.bagSetMark and ns.InGearSet and ns:InGearSet(link) then return false end      -- part of a saved gear set: never sold
    local state = ns:ItemListState(link)
    if state == "keep" then return false end
    if state == "sell" then return true end
    return quality == 0
end

-- Sell the junk: every grey item, and whatever is on the sell list, less whatever is on the keep list.
-- Returns the copper earned. announce = print even when nothing was sold.
function ns:SellJunk(announce)
    local total, sold = 0, 0
    for bag = 0, 5 do
        for slot = 1, (tonumber(ns:NumSlots(bag)) or 0) do
            local link, count, quality = ns:BagItem(bag, slot)
            if link then
                local q = quality or select(3, ns:GetItemInfo(link))
                local price = select(11, ns:GetItemInfo(link))
                if ns:ShouldSell(link, q, price) then
                    total = total + price * (count or 1)
                    sold = sold + 1
                    ns:UseBagItem(bag, slot)
                end
            end
        end
    end
    if total > 0 then ns:Print("Sold junk for %s", CoinString(total))
    elseif announce then ns:Print("No junk to sell.") end
    return total, sold
end

-- Who pays for a repair: "guild" (your guild allowance covers all of it), "own", or "none".
-- allowance: what the guild lets you withdraw today (-1 = no limit). bank: what the guild bank
-- holds, when the game says (it must cover the cost too).
function ns.RepairSource(cost, money, guildOK, allowance, bank)
    cost, money, allowance = tonumber(cost) or 0, tonumber(money) or 0, tonumber(allowance) or 0
    if guildOK and (allowance == -1 or allowance >= cost) and (type(bank) ~= "number" or bank == 0 or bank >= cost) then return "guild" end
    if money >= cost then return "own" end
    return "none"
end

local f = CreateFrame("Frame")
f:RegisterEvent("MERCHANT_SHOW")
f:SetScript("OnEvent", ns:Safe("Vendor automation", function()
    if not ns.db then return end
    if ns.db.autoSell then ns:SellJunk() end

    if ns.db.autoRepair and CanMerchantRepair and CanMerchantRepair() then
        local cost, canRepair = GetRepairAllCost()
        if canRepair and cost > 0 then
            local guildOK, allowance, bank = false, 0, nil
            if ns.db.repairGuild and IsInGuild and IsInGuild() and type(CanGuildBankRepair) == "function" and CanGuildBankRepair() then
                guildOK = true
                if type(GetGuildBankWithdrawMoney) == "function" then allowance = GetGuildBankWithdrawMoney() end
                if type(GetGuildBankMoney) == "function" then bank = GetGuildBankMoney() end
            end
            local source = ns.RepairSource(cost, GetMoney(), guildOK, allowance, bank)
            if source == "guild" then
                RepairAllItems(true)
                ns:Print("Repaired for %s from guild funds", CoinString(cost))
            elseif source == "own" then
                RepairAllItems()
                ns:Print("Repaired for %s", CoinString(cost))
            else
                ns:Print("|cffff4444Not enough gold to repair|r (%s)", CoinString(cost))
            end
        end
    end
end))
