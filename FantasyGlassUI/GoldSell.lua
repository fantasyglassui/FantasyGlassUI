-- Ways to make gold: Bags and selling, vendor flips (group A). Plugs into Gold.lua through ns.GoldRegister.
local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Sources "sell" (sell your bags and the bank you last saw at the auction house, vendor the junk)
-- and "vflip" (what a vendor sells for less than the auction house pays, and auction items a
-- vendor pays more for). The merchant recorder fills ns.root.goldVendor, which the flips read.
------------------------------------------------------------------------------------------
local floor, max, min, huge = math.floor, math.max, math.min, math.huge

local VENDOR_CAP = 3000                -- vendor prices kept; the oldest go first
local FLIP_CAP = 10                    -- flip ideas, the biggest first
local BANK_MINUTES = 2                 -- the walk to the bank first
local BOUND = { [1] = true, [4] = true, [7] = true, [8] = true }   -- (bind types no auction house takes, as SellHints.lua)

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
-- A plain finite number, or nil.
local function Num(v)
    if Secret(v) or type(v) ~= "number" or v ~= v or v == huge or v == -huge then return nil end
    return v
end
-- An item's name, quality, what a vendor pays for one (0 for nothing) and its bind type.
local function Info(id)
    local ok, name, link, quality, _, _, _, _, _, _, _, vendor, _, _, bindType = pcall(ns.GetItemInfo, ns, id)
    if not ok then return "item:" .. tostring(id), nil, 0, nil end
    if Secret(name) or type(name) ~= "string" or name == "" then
        name = (not Secret(link) and type(link) == "string") and link or ("item:" .. tostring(id))
    end
    vendor = Num(vendor)
    return name, Num(quality), (vendor and vendor > 0) and vendor or 0, Num(bindType)
end

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- What a merchant asks, read half a second after the merchant window opens or changes.
------------------------------------------------------------------------------------------
local function Store(create)
    local root = ns.root
    if type(root) ~= "table" then return nil end
    local s = root.goldVendor
    if type(s) ~= "table" or type(s.items) ~= "table" then
        if not create then return nil end
        s = { v = 1, items = {} }
        root.goldVendor = s
    end
    return s.items
end

-- Keep what a merchant asks for item `id` (info from C_MerchantFrame.GetItemInfo). True when kept,
-- and whether the item is new to the store.
function ns.GoldVendorNote(id, info, today)
    if Num(id) == nil or type(info) ~= "table" then return false end
    local price, stack, avail = info.price, info.stackCount, info.numAvailable
    local ext, hasExt = info.extendedCost, info.hasExtendedCost   -- (either spelling: the dump does not name the fields)
    if Secret(price) or Secret(stack) or Secret(avail) or Secret(ext) or Secret(hasExt) then return false end
    if ext or hasExt then return false end                        -- (tokens or honour: no copper price)
    price, stack, avail = Num(price), Num(stack), Num(avail)
    if not price or price <= 0 then return false end
    stack = max(1, floor(stack or 1))
    local buy = floor(price / stack)
    if buy <= 0 then return false end
    local items = Store(true)
    if not items then return false end
    local fresh = items[id] == nil
    items[id] = { buy = buy, stack = stack, limited = (avail and avail >= 0) and floor(avail) or nil, day = Num(today) or ns.Today() }
    return true, fresh
end

-- Over the cap: the oldest days go first (a job: it walks the whole store).
local function Trim()
    local items = Store(false)
    if not items then return end
    local keys = {}
    for k in pairs(items) do keys[#keys + 1] = k end              -- (the keys first: the store may change between slices)
    local over = #keys - VENDOR_CAP
    if over <= 0 then return end
    local function Day(e) return type(e) == "table" and Num(e.day) or 0 end
    local perDay = {}
    for _, k in ipairs(keys) do
        local d = Day(items[k])
        perDay[d] = (perDay[d] or 0) + 1
        ns.GoldYield()
    end
    local days = {}
    for d in pairs(perDay) do days[#days + 1] = d end
    table.sort(days)
    local cut, extra = 0, 0                                       -- every day before `cut` goes, and `extra` from that day
    for _, d in ipairs(days) do
        if perDay[d] >= over then cut, extra = d, over; break end
        over = over - perDay[d]
    end
    for _, k in ipairs(keys) do
        local e = items[k]
        if e ~= nil then
            local d = Day(e)
            if d < cut then items[k] = nil
            elseif d == cut and extra > 0 then items[k] = nil; extra = extra - 1 end
        end
        ns.GoldYield()
    end
end

-- Does this slot cost anything besides copper (tokens, honour, items)?
local function CostsMore(i)
    if type(GetMerchantItemCostInfo) ~= "function" then return false end
    local ok, n = pcall(GetMerchantItemCostInfo, i)
    if not ok then return false end
    n = Num(n)
    return n ~= nil and n > 0
end

local function InFight()
    local ok, v = pcall(InCombatLockdown)
    return ok and ns.Yes(v)
end

-- One merchant's list, as a job (a slot a step; jobs never run in a fight).
local again = false
local function Record()
    ns.goldVendorPasses = (ns.goldVendorPasses or 0) + 1
    local M = C_MerchantFrame
    if type(M) ~= "table" or type(M.GetItemInfo) ~= "function" or type(GetMerchantNumItems) ~= "function" or type(GetMerchantItemID) ~= "function" then return end
    local ok, n = pcall(GetMerchantNumItems)
    n = ok and Num(n) or 0
    local today, added = ns.Today(), false
    for i = 1, min(n, 500) do
        local okId, id = pcall(GetMerchantItemID, i)
        local okInfo, info = pcall(M.GetItemInfo, i)
        if okId and okInfo and not CostsMore(i) then
            local kept, fresh = ns.GoldVendorNote(id, info, today)
            if kept and fresh then added = true end
        end
        ns.GoldYield()
    end
    if added then ns.GoldJob(Trim, "goldVendorTrim") end
end

local Queue
local function RecordJob()
    Record()
    if again then again = false; ns:After(0, Queue) end            -- (the merchant changed while this one ran)
end
function Queue()
    if not Unlocked() or InFight() then return end
    if not ns.GoldJob(RecordJob, "goldVendorRecord") then again = true end
end

do
    local gen = 0
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
    pcall(ev.RegisterEvent, ev, "MERCHANT_UPDATE")
    -- (a plain handler first: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded = ns:Guard("Gold", function(_, event)
        if (event ~= "MERCHANT_SHOW" and event ~= "MERCHANT_UPDATE") or not Unlocked() then return end
        gen = gen + 1
        local mine = gen
        ns:After(0.5, function() if mine == gen then Queue() end end)
    end)
    ev:SetScript("OnEvent", function(...) if Unlocked() then guarded(...) end end)
end

------------------------------------------------------------------------------------------
-- Selling: the bags (and the bank last seen) at the auction house, the junk at a vendor
------------------------------------------------------------------------------------------
local function MerchantOpen()
    local f = _G.MerchantFrame
    if type(f) ~= "table" or type(f.IsShown) ~= "function" then return false end
    local ok, v = pcall(f.IsShown, f)
    return ok and not Secret(v) and v == true
end

-- One line an item: stacks of the same item put together (bound and unbound apart).
local function Merge(list)
    local out, at = {}, {}
    for _, it in ipairs(type(list) == "table" and list or {}) do
        local id = type(it) == "table" and Num(it.id)
        if id then
            local bound = ns.Yes(it.bound) or BOUND[select(4, Info(id))] == true   -- (as SellHintFor: these never sell there)
            local key = id .. (bound and ":b" or "")
            local o = at[key]
            if not o then
                o = { id = id, count = 0, vendor = Num(it.vendor) or 0, bound = bound, link = it.link }
                at[key] = o
                out[#out + 1] = o
            end
            o.count = o.count + max(1, Num(it.count) or 1)
        end
        ns.GoldYield()
    end
    return out
end

-- `bank`: false for the bags, else the bank's mark ("in your bank, seen 3 days ago").
local function Mark(text, bank)
    if not bank then return text end
    return text .. "  |cff9aa4b4(" .. bank .. ")|r"
end
local function BankMark(bank)
    local day = Num(bank.seen)
    local ago = day and ns.AuctionSeenText({ price = 0, day = day }, ns.Today())
    if ago then return format(ns:Tr("in your bank, seen %s"), ago) end
    return ns:Tr("in your bank")
end

-- Is this price one that says the item sells: listed in a scan, or seen while browsing, in the last
-- 7 days? (Otherwise it is only likely to sell.)
local SURE_DAYS, SURE, LIKELY = 7, ns.GOLD_SAFETY.sell.prices, 60
local function SellsSurely(e, today)
    if type(e) ~= "table" then return false end
    local listed, listedDay, seenDay = Num(e.listed), Num(e.listedDay), Num(e.seenDay)
    if listed and listed > 0 and listedDay and ns.DaysBetween(listedDay, today) <= SURE_DAYS then return true end
    return seenDay ~= nil and ns.DaysBetween(seenDay, today) <= SURE_DAYS
end
-- "Also used in: Make 3 × …", for an item a shown craft idea uses (the craft source runs first and
-- leaves ctx.craftUses = { [itemID] = title }).
local function AlsoUsed(ctx, detail, id)
    local uses = type(ctx.craftUses) == "table" and ctx.craftUses[id]
    if type(uses) == "string" then detail[#detail + 1] = { left = "|cff9aa4b4" .. format(ns:Tr("Also used in: %s"), uses) .. "|r" } end
end

-- Sell at the auction house. Returns the ids it sells (and holds), so the junk leaves them alone.
local function SellIdea(ctx, add, list, items, inBank)
    local worth = ns.WorthSelling(list, items, ctx.today)
    local sold = {}
    if #worth == 0 then return sold end
    local total, oldest, detail, held, sure = 0, nil, {}, {}, 0
    for _, w in ipairs(worth) do
        local it = w.item
        sold[it.id] = true
        local hint = ns.SellHintFor and ns.SellHintFor(it.id, it.bound)
        if hint == "hold" then
            -- cheap today against its usual price: not counted, only named
            held[#held + 1] = { left = "|cff9aa4b4" .. Mark(format(ns:Tr("Hold: %s (cheap today)"), (Info(it.id))), inBank) .. "|r" }
        else
            local net = floor(w.total * 0.95)
            total = total + net
            local e = items[it.id]
            if SellsSurely(e, ctx.today) then sure = sure + net end
            local d = type(e) == "table" and Num(e.day) or nil
            if d and (not oldest or d < oldest) then oldest = d end
            local right = ns:Coins(net)
            if hint == "sell" then right = "|cff4dd966" .. ns:Tr("Sell now") .. "|r  " .. right end
            detail[#detail + 1] = { left = Mark(format("%s ×%d", (Info(it.id)), it.count), inBank), right = right }
            AlsoUsed(ctx, detail, it.id)
        end
        ns.GoldYield()
    end
    for _, line in ipairs(held) do detail[#detail + 1] = line end
    if total <= 0 then return sold end
    -- how sure: the share of the money from items that surely sell, the rest only likely
    local safety = floor((SURE * sure + LIKELY * (total - sure)) / total + 0.5)
    local steps = { { text = ns:Tr("Go to the auction house") } }
    local minutes = min(15, 3 + 0.5 * (#worth - #held))
    if inBank then
        table.insert(steps, 1, { text = ns:Tr("Take the marked items out of your bank") })
        minutes = min(10, minutes + BANK_MINUTES)
    end
    add({
        id = inBank and "sell:bank" or "sell:bags", kind = "sell", oneOff = true, total = total, minutes = minutes,
        title = ns:Tr(inBank and "Sell what is in your bank at the auction house" or "Sell your bags at the auction house"),
        ease = ns.GOLD_EASE.sell, safety = safety, basis = "prices", priceDay = oldest, where = "both",
        steps = steps, detail = detail, tip = inBank and { inBank } or nil,
    })
    return sold
end

-- Vendor the grey items, and those a vendor pays about as much for.
local function JunkIdea(ctx, add, list, sold, inBank)
    local total, detail = 0, {}
    for _, it in ipairs(list) do
        if not sold[it.id] then
            local name, quality, vendor = Info(it.id)
            if it.vendor > 0 then vendor = it.vendor end
            if vendor > 0 and (quality == 0 or (ns.SellHintFor and ns.SellHintFor(it.id, it.bound) == "vendor")) then
                local value = vendor * it.count
                total = total + value
                detail[#detail + 1] = { left = Mark(format("%s ×%d", name, it.count), inBank), right = ns:Coins(value) }
                AlsoUsed(ctx, detail, it.id)
            end
        end
        ns.GoldYield()
    end
    if #detail == 0 then return end
    local minutes = MerchantOpen() and 1 or 3
    local steps
    if inBank then
        minutes = minutes + BANK_MINUTES
        steps = { { text = ns:Tr("Take the marked items out of your bank") }, { text = ns:Tr("Sell them to any vendor") } }
    end
    add({
        id = inBank and "sell:bankjunk" or "sell:junk", kind = "junk", oneOff = true, total = total, minutes = minutes,
        title = ns:Tr(inBank and "Vendor the junk in your bank" or "Vendor your junk"),
        ease = ns.GOLD_EASE.junk, safety = ns.GOLD_SAFETY.junk.prices, basis = "prices", priceDay = nil, where = "window",
        steps = steps, detail = detail, tip = inBank and { inBank } or nil,
    })
end

-- The ideas from the bags (and the bank, when given): bags and bank = { { id, count, vendor, bound } },
-- items = this auction house's prices. Pure apart from the item info and the sell hints.
-- bank.seen = the day the bank was last seen (yyyymmdd), shown with its items.
local function Today(ctx)
    local c = {}
    for k, v in pairs(type(ctx) == "table" and ctx or {}) do c[k] = v end
    c.today = c.today or ns.Today()
    return c
end
function ns.GoldSellIdeas(ctx, add, bags, items, bank)
    ctx = Today(ctx)
    items = type(items) == "table" and items or {}
    for _, where in ipairs({ { bags, false }, { bank, type(bank) == "table" and BankMark(bank) } }) do
        if type(where[1]) == "table" then
            local list = Merge(where[1])
            local sold = SellIdea(ctx, add, list, items, where[2])
            JunkIdea(ctx, add, list, sold, where[2])
        end
    end
end

-- How many are in the bank right now, by the game's own counts; nil when it cannot say.
local function LiveBankCount(id)
    local C = C_Item
    if type(C) ~= "table" or type(C.GetItemCount) ~= "function" then return nil end
    local okAll, all = pcall(C.GetItemCount, id, true)
    local okBags, bags = pcall(C.GetItemCount, id)
    if not (okAll and okBags) then return nil end
    all, bags = Num(all), Num(bags)
    if not (all and bags) then return nil end
    return max(0, all - bags)
end

-- This character's bank as the storage window last saw it; nil when it has never been seen.
local function BankItems()
    local inv = type(ns.root) == "table" and ns.root.inventory
    local me = type(inv) == "table" and type(inv.chars) == "table" and inv.chars[ns:CharKey()]
    if type(me) ~= "table" or type(me.bankTime) ~= "number" or type(me.bank) ~= "table" then return nil end
    local out, at = {}, {}
    for _, it in ipairs(me.bank) do
        local link = type(it) == "table" and it[1]
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
        if id then
            local _, _, vendor, bindType = Info(id)
            -- (bind on equip or use: the list cannot say whether this one is bound yet, so it is never
            -- suggested; details not loaded yet (no bind type): skipped until a later collection knows)
            if bindType ~= nil and bindType ~= 2 and bindType ~= 3 then
                local o = at[id]
                if not o then
                    o = { id = id, count = 0, vendor = vendor, bound = BOUND[bindType] == true, link = link }
                    at[id] = o
                    out[#out + 1] = o
                end
                o.count = o.count + max(1, Num(tonumber(it[2])) or 1)
            end
        end
        ns.GoldYield()
    end
    -- no more than the game says is in the bank now (taken out since the list was made: in the bags)
    local kept = {}
    for _, o in ipairs(out) do
        local live = LiveBankCount(o.id)
        if live then o.count = min(o.count, live) end
        if o.count > 0 then kept[#kept + 1] = o end
        ns.GoldYield()
    end
    local ok, d = pcall(date, "%Y%m%d", me.bankTime)
    kept.seen = ok and tonumber(d) or nil
    return kept
end

------------------------------------------------------------------------------------------
-- Vendor flips: buy from a vendor and list it, or buy the lowest listing and vendor it
------------------------------------------------------------------------------------------
local function FlipOrder(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.id < b.id
end

local function VendorToAuction(ctx, items, flips)
    local store = Store(false)
    if not store then return end
    local keys = {}
    for k in pairs(store) do keys[#keys + 1] = k end              -- (the keys first: the store may change between slices)
    for _, id in ipairs(keys) do
        local b, day, v = ns.GoldVendorBuy(id)
        local e = b and items[id]
        if type(e) == "table" and ns.DaysBetween(day, ctx.today) <= 30 then
            local u, days = ns.AuctionUsual(e)
            local listed = Num(e.listed)
            u = Num(u)
            if u and days >= 3 and listed and listed > 0 then
                local profit = floor(u * 0.95) - b
                if profit >= 100 and u >= 1.3 * b then
                    local count = max(1, floor(Num(v.limited) or Num(v.stack) or 1))
                    local name = Info(id)
                    flips[#flips + 1] = {
                        id = "vflip:" .. id, kind = "vflip", oneOff = true, total = profit * count, minutes = 8,
                        title = format(ns:Tr("Buy %s from a vendor, sell at the auction house"), name),
                        ease = ns.GOLD_EASE.vflip, safety = ns.GOLD_SAFETY.vflip.prices, basis = "prices",
                        priceDay = Num(e.day), where = "both",
                        steps = { { text = format(ns:Tr("Buy %d from the vendor that sells it"), count) }, { text = ns:Tr("Sell them at the auction house") } },
                        detail = {
                            { left = ns:Tr("A vendor asks"), right = ns:Coins(b) },
                            { left = ns:Tr("Its usual auction price"), right = ns:Coins(u) },
                            { left = ns:Tr("Listed in the last scan"), right = tostring(listed) },
                            { left = ns:Tr("Gain on each, after the auction house's cut"), right = ns:Coins(profit) },
                        },
                    }
                end
            end
        end
        ns.GoldYield()
    end
end

local function AuctionToVendor(ctx, items, flips)
    -- the keys first, in one go with no yield (the prices may change between slices), then walked
    local keys = {}
    for id in pairs(items) do keys[#keys + 1] = id end
    for _, id in ipairs(keys) do
        local e = items[id]
        local p = type(e) == "table" and e.day == ctx.today and Num(e.price) or nil
        if p and p > 0 then
            local name, _, v = Info(id)
            if v > 0 and p <= 0.9 * v and v - p >= 100 then
                flips[#flips + 1] = {
                    id = "aflip:" .. id, kind = "aflip", oneOff = true, total = v - p, minutes = 3,
                    title = format(ns:Tr("Buy %s at the auction house, a vendor pays more"), name),
                    ease = ns.GOLD_EASE.aflip, safety = ns.GOLD_SAFETY.aflip.prices, basis = "prices",
                    priceDay = ctx.today, where = "auction",
                    steps = { { text = ns:Tr("Buy the cheapest one") }, { text = ns:Tr("Sell it to any vendor") } },
                    detail = {
                        { left = ns:Tr("The cheapest listing today"), right = ns:Coins(p) },
                        { left = ns:Tr("A vendor pays"), right = ns:Coins(v) },
                    },
                }
            end
        end
        ns.GoldYield()
    end
end

-- The flips, at most 10, the biggest first. Auction flips only at the auction house (ctx.where).
function ns.GoldVendorFlipIdeas(ctx, add, items)
    ctx = Today(ctx)
    items = type(items) == "table" and items or {}
    local flips = {}
    VendorToAuction(ctx, items, flips)
    if ctx.where == "auction" then AuctionToVendor(ctx, items, flips) end
    table.sort(flips, FlipOrder)
    for i = 1, min(#flips, FLIP_CAP) do add(flips[i]) end
end

ns.GoldRegister("sell", function(ctx, add)
    local bags = ns.AuctionBagItems and ns.AuctionBagItems() or {}
    ns.GoldSellIdeas(ctx, add, bags, ns.PriceItems(), BankItems())
end)
ns.GoldRegister("vflip", function(ctx, add) ns.GoldVendorFlipIdeas(ctx, add, ns.PriceItems()) end)
