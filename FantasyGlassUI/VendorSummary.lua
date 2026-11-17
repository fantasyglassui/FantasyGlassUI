local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Vendor summary (11.10): when you close a vendor, one line in chat says what the visit came to:
--   At the vendor: sold 12 items for 3g 20s, bought 3 items for 40s, repaired for 1g 5s. In all: +1g 75s.
-- It counts every change in your gold while the vendor is open: what came in was sold; what went
-- out was bought, bought back or repaired. Repairs are told apart by watching the game's own repair,
-- and items counted by watching selling and buying (only watched: nothing of the game's is changed).
-- With it on, the junk seller, auto-repair and restock list say nothing of their own: it is all in
-- the one line. A visit where nothing changed hands says nothing at all.
------------------------------------------------------------------------------------------

-- The line for a visit, or nil when nothing happened.
-- v = { sold = copper in, spent = copper out, soldCount, boughtCount, repair = copper (own gold),
--       guildRepair = copper (guild's gold) }
function ns.VendorSummaryLine(v)
    if type(v) ~= "table" then return nil end
    local sold, spent = math.max(0, v.sold or 0), math.max(0, v.spent or 0)
    local repair, guild = math.max(0, v.repair or 0), math.max(0, v.guildRepair or 0)
    repair = math.min(repair, spent)                                -- (never more than went out)
    local bought = spent - repair
    local soldN, boughtN = v.soldCount or 0, v.boughtCount or 0
    local parts = {}
    if sold > 0 or soldN > 0 then
        if soldN == 1 or soldN == 0 then parts[#parts + 1] = format(ns:Tr(soldN == 1 and "sold 1 item for %s" or "sold for %s"), ns:Coins(sold))
        else parts[#parts + 1] = format(ns:Tr("sold %d items for %s"), soldN, ns:Coins(sold)) end
    end
    if bought > 0 or boughtN > 0 then
        if boughtN == 1 or boughtN == 0 then parts[#parts + 1] = format(ns:Tr(boughtN == 1 and "bought 1 item for %s" or "bought for %s"), ns:Coins(bought))
        else parts[#parts + 1] = format(ns:Tr("bought %d items for %s"), boughtN, ns:Coins(bought)) end
    end
    if repair > 0 then parts[#parts + 1] = format(ns:Tr("repaired for %s"), ns:Coins(repair)) end
    if guild > 0 then parts[#parts + 1] = format(ns:Tr("repaired for %s from guild funds"), ns:Coins(guild)) end
    if #parts == 0 then return nil end
    local net = sold - spent
    local line = ns:Tr("At the vendor:") .. " " .. table.concat(parts, ", ") .. "."
    if (sold > 0 and spent > 0) then                                -- ("in all" only says something when both happened)
        line = line .. " " .. format(ns:Tr("In all: %s."), (net >= 0 and "|cff66dd77+" or "|cffff6655-") .. ns:Coins(math.abs(net)) .. "|r")
    end
    return line
end

-- Is the one-line summary taking the place of the junk seller's and repair's own lines?
function ns:VendorSummaryOn()
    return ns.db and ns.db.vendorSummary and not ns.safeMode and true or false
end

ns:NewModule("vendorSummary", function()
    local visit
    local function Money()
        local m = type(GetMoney) == "function" and GetMoney()
        if type(m) == "number" and not Secret(m) then return m end
    end
    local function RepairCost()
        if type(GetRepairAllCost) ~= "function" then return 0 end
        local ok, cost = pcall(GetRepairAllCost)
        return (ok and type(cost) == "number" and not Secret(cost)) and cost or 0
    end
    local function Start()
        visit = { last = Money(), sold = 0, spent = 0, soldCount = 0, boughtCount = 0, repair = 0, guildRepair = 0, repairCost = RepairCost() }
    end
    local function Open() return visit ~= nil and not visit.closing end
    -- (the junk seller and auto-repair act the moment a vendor opens: they start the visit first)
    function ns.VendorVisitBegin()
        if ns.db.vendorSummary and (not visit or visit.closing) then Start() end
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Vendor summary", function(_, event)
        if not ns.db.vendorSummary then visit = nil; return end
        if event == "MERCHANT_SHOW" then
            ns.VendorVisitBegin()
        elseif event == "PLAYER_MONEY" then
            if not visit then return end
            local now = Money()
            if now and visit.last then
                local d = now - visit.last
                if d > 0 then visit.sold = visit.sold + d elseif d < 0 then visit.spent = visit.spent - d end
            end
            visit.last = now or visit.last
        elseif event == "UPDATE_INVENTORY_DURABILITY" then
            if Open() then visit.repairCost = RepairCost() end
        elseif event == "MERCHANT_CLOSED" then
            if not visit or visit.closing then return end
            visit.closing = true                                     -- (the last sales can arrive a moment later)
            local this = visit
            ns:After(1, function()
                if visit ~= this then return end
                visit = nil
                local line = ns.VendorSummaryLine(this)
                if line then ns:Print(line) end
            end)
        end
    end))

    -- what is watched (never changed): selling, buying, buying back and repairing
    if hooksecurefunc then
        local function Sold() if Open() then visit.soldCount = visit.soldCount + 1 end end
        if C_Container and type(C_Container.UseContainerItem) == "function" then pcall(hooksecurefunc, C_Container, "UseContainerItem", Sold)
        elseif type(UseContainerItem) == "function" then pcall(hooksecurefunc, "UseContainerItem", Sold) end
        if type(BuyMerchantItem) == "function" then
            pcall(hooksecurefunc, "BuyMerchantItem", function(_, qty)
                if Open() then visit.boughtCount = visit.boughtCount + math.max(1, tonumber(qty) or 1) end
            end)
        end
        if type(BuybackItem) == "function" then
            pcall(hooksecurefunc, "BuybackItem", function() if Open() then visit.boughtCount = visit.boughtCount + 1 end end)
        end
        if type(RepairAllItems) == "function" then
            pcall(hooksecurefunc, "RepairAllItems", function(guild)
                if not Open() then return end
                local cost = visit.repairCost or 0                        -- (what it cost just before)
                if guild then visit.guildRepair = visit.guildRepair + cost else visit.repair = visit.repair + cost end
                visit.repairCost = 0
            end)
        end
    end
    ns.vendorSummaryTest = { Start = Start, Visit = function() return visit end }
end)
