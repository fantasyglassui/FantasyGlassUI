-- Ways to make gold: Crafting for profit and auction flipping (group D). Plugs into Gold.lua through ns.GoldRegister.
local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end
local floor, max, min, huge = math.floor, math.max, math.min, math.huge

------------------------------------------------------------------------------------------
-- What the advisor knows about crafting comes from the recipes you know, read when a profession
-- opens; the ideas price them with the auction house's prices and the vendors you have seen.
--   ns.root.goldChars[charKey].recipes = { [recipeID] = { name, out, nMin, nMax,
--     reagents = { { id, need } }, prof, day } }    (at most 600; one profession's are replaced at its open)
-- Nothing here buys, posts or crafts: every purchase is the player's own click.
------------------------------------------------------------------------------------------
local RECIPE_CAP = 600
local CRAFT_MAX = 8

-- A plain finite number from the game or the store, else nil.
local function Num(v)
    if Secret(v) or type(v) ~= "number" or v ~= v or v == huge or v == -huge then return nil end
    return v
end
local function Str(v)
    if Secret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end
-- The first answer of a game function, or nil when it is missing, errors or hides its answer.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or Secret(v) then return nil end
    return v
end
local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function InFight()
    local ok, v = pcall(InCombatLockdown)
    return ok and ns.Yes(v)
end

-- This character's record in ns.root.goldChars; the tables are made only when `create` is set.
local function CharRecord(create, key)
    if type(ns.root) ~= "table" then return nil end
    local all = ns.root.goldChars
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        ns.root.goldChars = all
    end
    key = key or ns:CharKey()
    local rec = all[key]
    if type(rec) ~= "table" then
        if not create then return nil end
        rec = {}
        all[key] = rec
    end
    return rec
end

------------------------------------------------------------------------------------------
-- recorders (light; may stay in the main add-on when the folder moves)
-- When a profession opens, one job walks its recipes (a second of quiet first, as the list fills).
------------------------------------------------------------------------------------------
-- Is your own profession window open and filled? Someone else's list (a link, a guild's or an NPC's
-- crafting) is not what you can make.
local function Ready()
    local T = C_TradeSkillUI
    if type(T) ~= "table" or not ns.Yes(Call(T.IsTradeSkillReady)) then return false end
    if ns.Yes(Call(T.IsTradeSkillLinked)) or ns.Yes(Call(T.IsTradeSkillGuild)) or ns.Yes(Call(T.IsNPCCrafting)) then return false end
    return true
end

-- The basic reagents of a schematic, as Economy's shopping list reads them: { { id, need } }, and
-- true when a slot that counts could not be read (its item, its count or its kind): such a recipe is
-- never priced, since the cost would be too low.
local function SchematicReagents(s)
    local out, incomplete = {}, false
    for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
        if type(slot) == "table" then
            local rt = slot.reagentType
            if Secret(rt) or Secret(slot.required) then
                incomplete = true
            elseif rt == nil or rt == 1 or ns.Is(slot.required, true) then
                local first = type(slot.reagents) == "table" and slot.reagents[1]
                local id = type(first) == "table" and Num(first.itemID)
                local need = Num(slot.quantityRequired)
                if not id or not need then incomplete = true
                elseif need > 0 then out[#out + 1] = { id = id, need = need } end
            end
        end
    end
    return out, incomplete
end

-- The open profession's name, or nil.
local function ProfessionName()
    local T = C_TradeSkillUI
    local base = type(T) == "table" and Call(T.GetBaseProfessionInfo)
    return type(base) == "table" and Str(base.professionName) or nil
end

local again = false                    -- another profession opened while one was being read: read again after
local function ReadRecipes()
    if not Unlocked() or not Ready() then return end
    local T = C_TradeSkillUI
    local prof = ProfessionName()
    local ids = Call(T.GetAllRecipeIDs)
    if not prof or type(ids) ~= "table" then return end           -- (whose recipes these are must be known to replace them)
    local today = ns.Today()
    local found, order = {}, {}
    for _, id in ipairs(ids) do
        id = Num(id)
        local info = id and Call(T.GetRecipeInfo, id)
        if type(info) == "table" and ns.Is(info.learned, true) then
            local s = Call(T.GetRecipeSchematic, id, false)
            local out = type(s) == "table" and Num(s.outputItemID)
            if out and out > 0 then
                local nMin = Num(s.quantityMin) or 1
                local nMax = Num(s.quantityMax) or nMin
                if nMin < 1 then nMin = 1 end
                if nMax < nMin then nMax = nMin end
                local reagents, incomplete = SchematicReagents(s)
                found[id] = { name = Str(info.name) or Str(s.name), out = out, nMin = nMin, nMax = nMax, reagents = reagents,
                              incomplete = incomplete or nil, prof = prof, day = today }
                order[#order + 1] = id
            end
        end
        ns.GoldYield()
    end
    -- the window closed or went to another profession between slices: this read is not kept
    if not Ready() then return end
    if ProfessionName() ~= prof then again = true; return end
    -- this profession's old recipes go; the others stay; at most RECIPE_CAP in all
    local rec = CharRecord(#order > 0)
    if not rec then return end
    local kept, n = {}, 0
    for id, r in pairs(type(rec.recipes) == "table" and rec.recipes or {}) do
        if type(r) == "table" and r.prof ~= prof then kept[id] = r; n = n + 1 end
    end
    table.sort(order)
    for _, id in ipairs(order) do
        if n >= RECIPE_CAP then break end
        kept[id] = found[id]
        n = n + 1
    end
    rec.recipes = kept
end
local function RecipesJob()
    ReadRecipes()
    if again then
        again = false
        ns:After(0, function() ns.GoldRecipesRead() end)          -- (next frame: this job is gone by then)
    end
end

-- Read the open profession's recipes, as a job. False when locked, in a fight or not ready. While a read
-- is already queued, the open profession is read again right after it (true).
function ns.GoldRecipesRead()
    if not Unlocked() or InFight() or not Ready() then return false end
    if ns.GoldBusy("recipes") then again = true; return true end
    return ns.GoldJob(RecipesJob, "recipes")
end

do
    local ev, gen = CreateFrame("Frame"), 0
    pcall(ev.RegisterEvent, ev, "TRADE_SKILL_SHOW")
    pcall(ev.RegisterEvent, ev, "TRADE_SKILL_LIST_UPDATE")
    -- (a plain handler first: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded = ns:Guard("Gold recipes", function(_, event)
        if (event ~= "TRADE_SKILL_SHOW" and event ~= "TRADE_SKILL_LIST_UPDATE") or not Unlocked() then return end
        gen = gen + 1
        local mine = gen
        ns:After(1, function() if mine == gen then ns.GoldRecipesRead() end end)
    end)
    ev:SetScript("OnEvent", function(...) if Unlocked() then guarded(...) end end)
end

------------------------------------------------------------------------------------------
-- Prices for buying and selling
------------------------------------------------------------------------------------------
local function ItemName(id)
    if not Num(id) then return nil end
    local ok, name = pcall(ns.GetItemInfo, ns, id)
    return ok and Str(name) or nil
end
local function NameOf(id, fallback)
    return ItemName(id) or Str(fallback) or format(ns:Tr("item %d"), tonumber(id) or 0)
end

-- An auction price for one: today's lowest, else the usual, else the last seen; and that entry's day.
local function AuctionPrice(id, today)
    if not Num(id) then return nil end
    local e = ns.PriceEntry(id)
    if type(e) ~= "table" then return nil end
    local p = e.price
    if e.day ~= today then p = ns.AuctionUsual(e) or e.price end
    p = Num(p)
    if not p or p <= 0 then return nil end
    return p, Num(e.day), e
end
-- What a vendor asks for one (GoldSell.lua writes the store; the reader may not be there).
local function VendorBuy(id)
    if type(ns.GoldVendorBuy) ~= "function" then return nil end
    local ok, buy = pcall(ns.GoldVendorBuy, id)
    buy = ok and Num(buy) or nil
    if buy and buy > 0 then return buy end
    return nil
end
-- The cheaper way to buy one reagent: copper, "auction"|"vendor", and the auction price's day.
-- A tie goes to the vendor: its price does not move.
local function ReagentPrice(id, today)
    local ah, day = AuctionPrice(id, today)
    local vendor = VendorBuy(id)
    if vendor and (not ah or vendor <= ah) then return vendor, "vendor", nil end
    if ah then return ah, "auction", day end
    return nil
end

-- What a recipe makes after the house's cut, what its reagents cost, and the oldest auction price used.
-- nil and why ("unpriced": a reagent with no price; "no price": the product has no auction price).
function ns.GoldCraftMargin(rec, today)
    if type(rec) ~= "table" then return nil, "no recipe" end
    today = today or ns.Today()
    -- a reagent that could not be read, or none at all: the cost is not known, so no profit is claimed
    if rec.incomplete or type(rec.reagents) ~= "table" or #rec.reagents == 0 then return nil, "unpriced" end
    local cost, oldest = 0, nil
    for _, r in ipairs(rec.reagents) do
        local need = type(r) == "table" and Num(r.need)
        if not need or need <= 0 then return nil, "unpriced" end
        local unit, from, day = ReagentPrice(r.id, today)
        if not unit then return nil, "unpriced" end
        if from == "auction" and day and (not oldest or day < oldest) then oldest = day end
        cost = cost + unit * need
    end
    local p, day = AuctionPrice(rec.out, today)
    if not p then return nil, "no price" end
    if day and (not oldest or day < oldest) then oldest = day end
    local nMin = Num(rec.nMin) or 1
    local nMax = Num(rec.nMax) or nMin
    if nMax < nMin then nMax = nMin end
    local sale = floor(p * 95 * (nMin + nMax) / 200)            -- (95% of the price, times the average made, in whole numbers)
    return sale - cost, cost, sale, oldest
end

-- How many of these items your other characters hold (bags and bank), from what Storage has saved:
-- { [itemID] = n }. It walks the saved lists itself, a slice at a time, instead of asking
-- ns:ItemOwners, whose index is rebuilt in one go after every bag change. Only while the storage
-- feature is on (it is what defines ns.ItemOwners); the guild bank is not counted.
local function AltCounts(wanted)
    local out = {}
    local inv = type(ns.root) == "table" and ns.root.inventory
    if type(ns.ItemOwners) ~= "function" or type(inv) ~= "table" or type(inv.chars) ~= "table" then return out end
    local me = ns:CharKey()
    local keys = {}
    for key in pairs(inv.chars) do if key ~= me then keys[#keys + 1] = key end end
    for _, key in ipairs(keys) do
        local c = inv.chars[key]
        for _, field in ipairs({ "bags", "bank" }) do
            local list = type(c) == "table" and c[field]
            for _, it in ipairs(type(list) == "table" and list or {}) do
                local link = type(it) == "table" and it[1]
                local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
                if id and wanted[id] then out[id] = (out[id] or 0) + (tonumber(it[2]) or 1) end
                ns.GoldYield()
            end
        end
    end
    return out
end
-- have(id) -> on this character (bags and bank), on your other characters, for these recipes' reagents.
local function Haves(recs)
    local wanted = {}
    for _, rec in ipairs(recs) do
        for _, r in ipairs(rec.reagents) do wanted[r.id] = true end
    end
    local alts = AltCounts(wanted)
    return function(id)
        return Num(Call(C_Item and C_Item.GetItemCount, id, true)) or 0, alts[id] or 0
    end
end

local function CraftIdea(f, today, have)
    local rec, count = f.rec, f.count
    local product = NameOf(rec.out, rec.name)
    local detail, buys, gets = {}, {}, {}
    for _, r in ipairs(ns.ShoppingLines(rec.reagents, count, have)) do
        local unit, from = ReagentPrice(r.id, today)
        local name = NameOf(r.id)
        local right
        if r.buy > 0 then
            right = format(ns:Tr("%d to buy, %s each"), r.buy, ns:Coins(unit or 0)) .. "  |cff9aa4b4(" .. ns:Tr(from or "auction") .. ")|r"
            buys[#buys + 1] = { text = format(ns:Tr("Buy %d × %s"), r.buy, name) }
        else
            right = ns:Tr("enough")
        end
        if r.fromAlts > 0 then
            right = right .. "  |cff9aa4b4" .. format(ns:Tr("%d on other characters"), r.others) .. "|r"
            gets[#gets + 1] = { text = format(ns:Tr("Get %d × %s from your other characters"), r.fromAlts, name) }
        end
        detail[#detail + 1] = { left = format("%d × %s  |cff9aa4b4(%d)|r", r.need, name, r.mine), right = right }
    end
    if not f.counted then
        detail[#detail + 1] = { left = "|cff9aa4b4" .. ns:Tr("No recent scan says how many are listed, so this is for one.") .. "|r" }
    end
    local steps = buys
    for _, s in ipairs(gets) do steps[#steps + 1] = s end
    steps[#steps + 1] = { text = format(ns:Tr("Make %d × %s"), count, product) }
    steps[#steps + 1] = { text = ns:Tr("Sell them at the auction house") }
    return {
        id = "craft:" .. tostring(f.id), kind = "craft", oneOff = true,
        title = format(ns:Tr("Make %d × %s and sell them"), count, product),
        total = f.total, minutes = 5 + count,
        ease = ns.GOLD_EASE.craft, safety = ns.GOLD_SAFETY.craft.prices, basis = "prices", priceDay = f.day,
        where = "both", detail = detail, steps = steps,
    }
end

local function ByTotal(a, b)
    if a.total ~= b.total then return a.total > b.total end
    return a.id < b.id
end
-- The craft ideas from these recipes: the best CRAFT_MAX by total. `have(id) -> mine, others` (the
-- bags, the bank and your other characters by default, counted only for the ideas that are kept).
function ns.GoldCraftIdeas(ctx, add, recipes, have)
    if type(recipes) ~= "table" or type(add) ~= "function" then return end
    local today = (type(ctx) == "table" and Num(ctx.today)) or ns.Today()
    local ids = {}
    for id in pairs(recipes) do if Num(id) then ids[#ids + 1] = id end end   -- (the keys first: the table may change between slices)
    local found = {}
    for _, id in ipairs(ids) do
        local rec = recipes[id]
        if type(rec) == "table" then
            local margin, cost, _, day = ns.GoldCraftMargin(rec, today)
            if margin and margin >= max(50, 0.1 * cost) then
                -- how many to make follows how many are listed, from a scan no more than a day old
                local e = ns.PriceEntry(rec.out)
                local listed = type(e) == "table" and Num(e.listed) or nil
                local listedDay = type(e) == "table" and Num(e.listedDay) or nil
                if not listedDay or ns.DaysBetween(listedDay, today) > 1 then listed = nil end
                local count = listed and min(5, max(1, floor(listed / 4))) or 1
                found[#found + 1] = { id = id, rec = rec, count = count, counted = listed ~= nil, total = margin * count, day = day }
            end
        end
        ns.GoldYield()
    end
    table.sort(found, ByTotal)
    for i = #found, CRAFT_MAX + 1, -1 do found[i] = nil end
    if not have then
        local recs = {}
        for i, f in ipairs(found) do recs[i] = f.rec end
        have = Haves(recs)
    end
    -- what the kept ideas use, for the sell ideas' "Also used in" (the sell source runs after this one)
    local uses = type(ctx) == "table" and {} or nil
    for _, f in ipairs(found) do
        local idea = CraftIdea(f, today, have)
        add(idea)
        if uses then
            for _, r in ipairs(f.rec.reagents) do if Num(r.id) and not uses[r.id] then uses[r.id] = idea.title end end
        end
    end
    if uses then ctx.craftUses = uses end
end

ns.GoldRegister("craft", function(ctx, add)
    local rec = CharRecord(false, type(ctx) == "table" and ctx.charKey or nil)
    ns.GoldCraftIdeas(ctx, add, rec and rec.recipes)
end)

------------------------------------------------------------------------------------------
-- Auction flips: an item listed today well under its usual price, bought to list again near it.
-- Flips can lose gold, so only a sure-looking case counts: today's price, at least five days of
-- history in the last 14 days (four of them before today), at least three listed in a recent scan,
-- and the tips say to check before buying.
------------------------------------------------------------------------------------------
local FLIP_MAX = 10

local function Quality(id)
    local ok, _, _, q = pcall(ns.GetItemInfo, ns, id)
    return ok and Num(q) or nil
end

-- The flip for one price entry: profit, lowest price, usual price, days of history; nil when it is not one.
local function Flip(id, e, today)
    if not Num(id) or type(e) ~= "table" or e.day ~= today then return nil end
    local p = Num(e.price)
    if not p or p <= 0 then return nil end
    -- the usual price from the last 14 days only, and at least 4 of those days from before today:
    -- old lows from months back would make a price that has fallen look like a bargain
    local recent, before = {}, 0
    for d, low in pairs(type(e.hist) == "table" and e.hist or {}) do
        local age = Num(d) and ns.DaysBetween(d, today)
        if age and age >= 0 and age <= 14 and Num(low) then
            recent[d] = low
            if age >= 1 then before = before + 1 end
        end
    end
    if before < 4 then return nil end
    local u, days = ns.AuctionUsual({ hist = recent })
    u, days = Num(u), Num(days)
    if not u or u <= 0 or not days or days < 5 then return nil end
    -- a thin listing, or a count from an old scan, says nothing about whether it sells
    local listed, listedDay = Num(e.listed), Num(e.listedDay)
    if not listed or listed < 3 or not listedDay or ns.DaysBetween(listedDay, today) > 1 then return nil end
    if p > 0.6 * u then return nil end
    -- a vendor pays more than it costs: that is the auction-to-vendor flip (GoldSell.lua), the safer one
    local okV, _, _, _, _, _, _, _, _, _, _, vendor = pcall(ns.GetItemInfo, ns, id)
    vendor = okV and Num(vendor) or nil
    if vendor and vendor > 0 and p <= 0.9 * vendor and vendor - p >= 100 then return nil end
    local profit = floor(u * 95 / 100) - p
    if profit < 2000 then return nil end
    local q = Quality(id)
    if not q or q < 1 then return nil end
    return profit, p, u, days, listed
end

local function ByProfit(a, b)
    if a.profit ~= b.profit then return a.profit > b.profit end
    return a.id < b.id
end
-- The flip ideas among these price entries ({ [itemID] = entry }): the best FLIP_MAX by profit.
function ns.GoldFlipIdeas(ctx, add, items, today)
    if type(items) ~= "table" or type(add) ~= "function" then return end
    today = Num(today) or (type(ctx) == "table" and Num(ctx.today)) or ns.Today()
    local ids = {}
    for id in pairs(items) do if Num(id) then ids[#ids + 1] = id end end   -- (the keys first: a scan may add prices between slices)
    local found = {}
    for _, id in ipairs(ids) do
        local profit, p, u, days, listed = Flip(id, items[id], today)
        if profit then found[#found + 1] = { id = id, profit = profit, p = p, u = u, days = days, listed = listed } end
        ns.GoldYield()
    end
    table.sort(found, ByProfit)
    for i = 1, min(FLIP_MAX, #found) do
        local f = found[i]
        local name = NameOf(f.id)
        add({
            id = "flip:" .. tostring(f.id), kind = "flip", oneOff = true,
            title = format(ns:Tr("Buy %s at %s and list it again near %s"), name, ns:Coins(f.p), ns:Coins(f.u)),
            total = f.profit, minutes = 3,
            ease = ns.GOLD_EASE.flip, safety = ns.GOLD_SAFETY.flip.prices, basis = "prices", priceDay = today, where = "auction",
            detail = {
                { left = ns:Tr("Lowest listed today"), right = ns:Coins(f.p) },
                { left = format(ns:Tr("Usual price (%d days)"), f.days), right = ns:Coins(f.u) },
                { left = ns:Tr("Listed in the last scan"), right = tostring(f.listed) },
                { left = ns:Tr("Profit after the house's cut"), right = ns:Coins(f.profit) },
            },
            tip = {
                ns:Tr("Only the cheapest one is known; buy one and look again."),
                ns:Tr("Check before buying: this far under its usual price, it may be a seller's mistake, or the price may have fallen."),
                ns:Tr("Nothing is bought for you: every purchase is your own click."),
            },
        })
    end
end

ns.GoldRegister("auction", function(ctx, add)
    if type(ctx) ~= "table" or ctx.where ~= "auction" then return end    -- (only at the auction house: nowhere else shows flips)
    ns.GoldFlipIdeas(ctx, add, ns.PriceItems(), type(ctx) == "table" and ctx.today or nil)
end)
