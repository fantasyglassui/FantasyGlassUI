local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

local function Count(id, bank)
    local Get = (C_Item and C_Item.GetItemCount) or GetItemCount
    if type(Get) ~= "function" then return 0 end
    local ok, n = pcall(Get, id, bank and true or false)
    return (ok and type(n) == "number" and not Secret(n)) and n or 0
end
local function Name(id)
    local ok, name = pcall(function() return ns:GetItemInfo(id) end)
    return (ok and type(name) == "string") and name or ("item " .. tostring(id))
end

------------------------------------------------------------------------------------------
-- Restock list: "always keep 5 of these". Whenever a vendor sells one, the difference is bought.
--   /fgui restock [item] 5     (shift-click the item in; 0 takes it off)     /fgui restock   the list
------------------------------------------------------------------------------------------
-- What to buy: a list of amounts (one purchase each) and what it costs.
-- maxStack: the most the vendor sells in one purchase. stock: limited supply (-1 or nil = unlimited).
-- price is for `per` items.
function ns.RestockPlan(want, have, maxStack, stock, price, per, money)
    local need = (tonumber(want) or 0) - (tonumber(have) or 0)
    stock = tonumber(stock)
    if stock and stock >= 0 then need = math.min(need, stock) end
    maxStack, per, price, money = math.max(1, tonumber(maxStack) or 1), math.max(1, tonumber(per) or 1), tonumber(price) or 0, tonumber(money) or 0
    local each = price / per
    local buys, cost = {}, 0
    while need > 0 and #buys < 40 do
        local n = math.min(need, maxStack)
        if each > 0 and cost + n * each > money then n = math.floor((money - cost) / each) end
        if n <= 0 then break end
        buys[#buys + 1] = n
        cost = cost + n * each
        need = need - n
    end
    return buys, cost
end
function ns:RestockCommand(text)
    local list = ns:SavedList("restock")
    text = ns.Trim(text)
    if text == "" then
        local any = false
        for id, n in pairs(list) do any = true; ns:Print("Restock: keep %d of %s.", n, Name(id)) end
        if not any then ns:Print("Nothing on the restock list. Add with /fgui restock, a space, shift-click the item, a space and how many to keep.") end
        return
    end
    local id = ns:ItemIDOf(text)
    local n = tonumber(text:match("(%d+)%s*$"))
    if not id or not n then ns:Print("Shift-click an item into the line, then a space and how many to keep: /fgui restock [item] 5."); return end
    list[id] = (n > 0) and math.min(n, 10000) or nil
    if n > 0 then ns:Print("Restock: keep %d of %s.", n, Name(id)) else ns:Print("Restock: %s is off the list.", Name(id)) end
    if not ns.db.restockOn then ns:Print("It is switched off: see \"Vendors: restock list\" on the Features tab.") end
end
ns:NewModule("restockOn", function()
    local function Shop()
        local list = ns:SavedList("restock")
        if next(list) == nil or type(GetMerchantNumItems) ~= "function" or type(BuyMerchantItem) ~= "function" then return 0 end
        local bought, spent = 0, 0
        for i = 1, tonumber(GetMerchantNumItems()) or 0 do
            local id = GetMerchantItemID and GetMerchantItemID(i)
            local want = type(id) == "number" and list[id]
            if want then
                local price, per, stock
                if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
                    local info = C_MerchantFrame.GetItemInfo(i)
                    if type(info) == "table" then price, per, stock = info.price, info.stackCount, info.numAvailable end
                elseif GetMerchantItemInfo then
                    local _, _, p, q, a = GetMerchantItemInfo(i)
                    price, per, stock = p, q, a
                end
                local buys, cost = ns.RestockPlan(want, Count(id), GetMerchantItemMaxStack and GetMerchantItemMaxStack(i), stock, price, per, (GetMoney() or 0) - spent)
                local n = 0
                for _, amount in ipairs(buys) do pcall(BuyMerchantItem, i, amount); n = n + amount end
                if n > 0 then
                    bought, spent = bought + n, spent + cost
                    if not ns:VendorSummaryOn() then ns:Print("Restocked %d of %s.", n, Name(id)) end
                end
            end
        end
        return bought, spent
    end
    ns.restockTest = { Shop = Shop }
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "MERCHANT_SHOW")
    ev:SetScript("OnEvent", ns:Guard("Economy events", function() ns:After(0.3, function() pcall(Shop) end) end))
end)

------------------------------------------------------------------------------------------
-- Gold history: your gold at the end of each day, and where this session's gold came from and went.
------------------------------------------------------------------------------------------
-- Where a change in gold came from, by what was open at the time.
function ns.MoneySource(ctx)
    if ctx.merchant then return "Vendors and repairs" end
    if ctx.auction then return "Auction house" end
    if ctx.mail then return "Mail" end
    if ctx.trade then return "Trade" end
    if ctx.trainer then return "Training" end
    if ctx.taxi then return "Flights" end
    if ctx.quest then return "Quests" end
    if ctx.loot then return "Loot" end
    return "Other"
end
-- The last `count` days on record, newest first: { day, gold, change (against the day before on record) }.
function ns.GoldDays(days, count)
    local keys = {}
    for day in pairs(days or {}) do keys[#keys + 1] = day end
    table.sort(keys)
    local out = {}
    for i = #keys, math.max(1, #keys - (count or 14) + 1), -1 do
        out[#out + 1] = { day = keys[i], gold = days[keys[i]], change = keys[i - 1] and (days[keys[i]] - days[keys[i - 1]]) or nil }
    end
    return out
end
ns.sessionMoney = {}                                          -- { [source] = { earned, spent } }
local function Shown(name)
    local f = _G[name]
    return type(f) == "table" and f.IsShown and ns.Yes(f:IsShown())
end
do
    local last, lootAt, questAt = nil, 0, 0
    local function Record()
        local money = GetMoney and GetMoney()
        if type(money) ~= "number" or Secret(money) or type(ns.root) ~= "table" then return end
        if type(ns.root.goldDays) ~= "table" then ns.root.goldDays = {} end
        local key = ns:CharKey()
        if type(ns.root.goldDays[key]) ~= "table" then ns.root.goldDays[key] = {} end
        local days = ns.root.goldDays[key]
        days[ns.Today()] = money
        local n = 0
        for _ in pairs(days) do n = n + 1 end
        if n > 120 then                                       -- (four months is plenty)
            local oldest
            for day in pairs(days) do if not oldest or day < oldest then oldest = day end end
            days[oldest] = nil
        end
        if last and money ~= last then
            local now = (GetTime and GetTime()) or 0
            local source = ns.MoneySource({ merchant = Shown("MerchantFrame"), auction = Shown("AuctionHouseFrame") or Shown("AuctionFrame"), mail = Shown("MailFrame"),
                trade = Shown("TradeFrame"), trainer = Shown("ClassTrainerFrame"), taxi = Shown("TaxiFrame") or Shown("FlightMapFrame"),
                quest = Shown("QuestFrame") or (now - questAt < 2), loot = Shown("LootFrame") or (now - lootAt < 2) })
            local s = ns.sessionMoney[source] or { earned = 0, spent = 0 }
            ns.sessionMoney[source] = s
            if money > last then s.earned = s.earned + (money - last) else s.spent = s.spent + (last - money) end
        end
        last = money
    end
    ns.RecordGold = Record
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_MONEY", "LOOT_OPENED", "CHAT_MSG_MONEY", "QUEST_TURNED_IN" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Gold history", function(_, event)
        local now = (GetTime and GetTime()) or 0
        if event == "LOOT_OPENED" or event == "CHAT_MSG_MONEY" then lootAt = now
        elseif event == "QUEST_TURNED_IN" then questAt = now
        else Record() end
    end))
end
function ns:ShowGold()
    if ns.RecordGold then pcall(ns.RecordGold) end
    local days = ns.GoldDays(type(ns.root) == "table" and type(ns.root.goldDays) == "table" and ns.root.goldDays[ns:CharKey()] or {}, 14)
    local most = 1
    for _, d in ipairs(days) do most = math.max(most, d.gold) end
    local lines = {}
    for _, d in ipairs(days) do
        local s = tostring(d.day)
        local change = ""
        if d.change and d.change > 0 then change = "   |cff33ff66+" .. ns:Coins(d.change) .. "|r" elseif d.change and d.change < 0 then change = "   |cffff5555-" .. ns:Coins(-d.change) .. "|r" end
        lines[#lines + 1] = { left = s:sub(1, 4) .. "-" .. s:sub(5, 6) .. "-" .. s:sub(7, 8) .. change, right = ns:Coins(d.gold), bar = d.gold / most }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No days kept yet: your gold is noted at the end of each day you play.") } end
    local names = {}
    for source in pairs(ns.sessionMoney) do names[#names + 1] = source end
    table.sort(names)
    if #names > 0 then
        lines[#lines + 1] = { left = "" }
        lines[#lines + 1] = { left = ns:Tr("This session"), color = { 1, 0.82, 0.3 } }
        for _, source in ipairs(names) do
            local s = ns.sessionMoney[source]
            lines[#lines + 1] = { left = "    " .. ns:Tr(source),
                right = (s.earned > 0 and ("|cff33ff66+" .. ns:Coins(s.earned) .. "|r  ") or "") .. (s.spent > 0 and ("|cffff5555-" .. ns:Coins(s.spent) .. "|r") or "") }
        end
    end
    return ns:ShowList("Gold", "Gold history", lines, "Your gold at the end of each day you played this character.", 420, 380)
end

------------------------------------------------------------------------------------------
-- Gear set mark: an item that belongs to a saved gear set says "Set" in the bags, and is never sold.
------------------------------------------------------------------------------------------
local setItems
function ns:GearSetItems()
    if setItems then return setItems end
    setItems = {}
    local E = C_EquipmentSet
    if type(E) == "table" and type(E.GetEquipmentSetIDs) == "function" and type(E.GetItemIDs) == "function" then
        local ok, ids = pcall(E.GetEquipmentSetIDs)
        for _, setID in ipairs((ok and type(ids) == "table") and ids or {}) do
            local okI, items = pcall(E.GetItemIDs, setID)
            if okI and type(items) == "table" then
                for _, id in pairs(items) do if type(id) == "number" and id > 1 then setItems[id] = true end end
            end
        end
    end
    return setItems
end
function ns:InGearSet(item)
    local id = ns:ItemIDOf(item)
    return (id and ns:GearSetItems()[id]) or false
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "EQUIPMENT_SETS_CHANGED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Economy events", function() setItems = nil end))
end

------------------------------------------------------------------------------------------
-- Shopping list: what the recipe you have selected still needs, counting bank and other characters.
------------------------------------------------------------------------------------------
-- The reagents of the selected recipe: name of the recipe, { { id, need } ... }. Nil when none is selected.
function ns:SelectedRecipe()
    local T = C_TradeSkillUI
    local page = _G.ProfessionsFrame and _G.ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    local recipeID, name
    if type(form) == "table" then
        local info = (form.GetRecipeInfo and select(2, pcall(form.GetRecipeInfo, form))) or form.currentRecipeInfo
        if type(info) == "table" then recipeID, name = info.recipeID, info.name end
    end
    if type(recipeID) ~= "number" or type(T) ~= "table" or type(T.GetRecipeSchematic) ~= "function" then return nil end
    local ok, schematic = pcall(T.GetRecipeSchematic, recipeID, false)
    if not (ok and type(schematic) == "table" and type(schematic.reagentSlotSchematics) == "table") then return nil end
    local reagents = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        local first = type(slot.reagents) == "table" and slot.reagents[1]
        local basic = slot.reagentType == nil or slot.reagentType == 1 or ns.Is(slot.required, true)
        if type(first) == "table" and type(first.itemID) == "number" and basic and (tonumber(slot.quantityRequired) or 0) > 0 then
            reagents[#reagents + 1] = { id = first.itemID, need = slot.quantityRequired }
        end
    end
    return (type(name) == "string" and name) or schematic.name or "Recipe", reagents, recipeID
end
-- One line per reagent: how many more you need, and where the rest is.
-- have(id) -> on this character (bags and bank), on your other characters.
function ns.ShoppingLines(reagents, times, have)
    local out = {}
    for _, r in ipairs(reagents or {}) do
        local need = r.need * (times or 1)
        local mine, others = have(r.id)
        local short = math.max(0, need - mine)
        out[#out + 1] = { id = r.id, need = need, mine = mine, others = others, short = short, fromAlts = math.min(short, others), buy = math.max(0, short - others) }
    end
    return out
end
function ns:ShowShopping(text)
    local name, reagents = ns:SelectedRecipe()
    if not name then ns:Print("Open a profession and select a recipe first, then type /fgui shop (or /fgui shop 5 to make five)."); return end
    local times = math.max(1, math.floor(tonumber(ns.Trim(text)) or 1))
    local lines = {}
    for _, r in ipairs(ns.ShoppingLines(reagents, times, function(id)
        local others = 0
        local owners, me = nil, nil
        if ns.ItemOwners then owners, me = ns:ItemOwners(id) end
        for owner, o in pairs(type(owners) == "table" and owners or {}) do
            if owner ~= me then others = others + (o.bags or 0) + (o.bank or 0) end
        end
        return Count(id, true), others
    end)) do
        local right
        if r.short == 0 then right = "|cff33ff66" .. ns:Tr("enough") .. "|r"
        else
            right = "|cffff5555" .. format(ns:Tr("%d short"), r.short) .. "|r"
            if r.fromAlts > 0 then right = right .. "  |cff9aa4b4" .. format(ns:Tr("%d on other characters"), r.others) .. "|r" end
        end
        lines[#lines + 1] = { left = format("%d x %s  |cff9aa4b4(%d)|r", r.need, Name(r.id), r.mine), right = right }
    end
    return ns:ShowList("Shopping", name .. (times > 1 and (" x " .. times) or ""), lines, "Needed, with how many you have in brackets (bags and bank).", 460, 300)
end

------------------------------------------------------------------------------------------
-- Trade log: what changed hands, with whom. A line in chat, and /fgui trades to look back.
------------------------------------------------------------------------------------------
-- "Bob: gave 2 x [Linen Cloth], 5g; got [Sword]".
function ns.TradeLine(t)
    local function side(items, money)
        local parts = {}
        for _, item in ipairs(items or {}) do parts[#parts + 1] = ((item.count or 1) > 1 and (item.count .. " x ") or "") .. tostring(item.link or item.name) end
        if (money or 0) > 0 then parts[#parts + 1] = ns:Coins(money) end
        return (#parts > 0) and table.concat(parts, ", ") or nil
    end
    local gave, got = side(t.gave, t.gaveMoney), side(t.got, t.gotMoney)
    if not gave and not got then return nil end
    return format("%s: %s%s%s", tostring(t.who or "?"), gave and (ns:Tr("gave") .. " " .. gave) or "", (gave and got) and "; " or "", got and (ns:Tr("got") .. " " .. got) or "")
end
ns:NewModule("tradeLog", function()
    if type(ns.root) ~= "table" then return end
    if type(ns.root.trades) ~= "table" then ns.root.trades = {} end
    local now
    local function Items(Link, Info)
        local out = {}
        for i = 1, 6 do
            local link = type(Link) == "function" and Link(i)
            if type(link) == "string" and not Secret(link) then
                local _, _, count = Info(i)
                out[#out + 1] = { link = link, count = (type(count) == "number" and not Secret(count)) and count or 1 }
            end
        end
        return out
    end
    local function Snapshot()
        if not now then return end
        now.gave, now.got = Items(GetTradePlayerItemLink, GetTradePlayerItemInfo), Items(GetTradeTargetItemLink, GetTradeTargetItemInfo)
        local a, b = GetPlayerTradeMoney and GetPlayerTradeMoney(), GetTargetTradeMoney and GetTargetTradeMoney()
        now.gaveMoney, now.gotMoney = tonumber(a) or 0, tonumber(b) or 0
    end
    local function Done()
        local t = now
        now = nil
        if not t then return end
        local line = ns.TradeLine(t)
        if not line then return end
        t.at = time and time() or 0
        table.insert(ns.root.trades, 1, t)
        while #ns.root.trades > 50 do table.remove(ns.root.trades) end
        ns:PrintRaw("|cff33ccffFantasy Glass UI|r: " .. ns:Tr("Traded with") .. " " .. line)
        return line
    end
    ns.tradeTest = { Start = function(who) now = { who = who } end, Snapshot = Snapshot, Done = Done, Now = function() return now end }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "TRADE_SHOW", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_MONEY_CHANGED", "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE", "TRADE_REQUEST_CANCEL" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Trade log", function(_, event, a, b)
        if event == "TRADE_SHOW" then
            local who = UnitName("NPC")
            now = { who = (type(who) == "string" and not Secret(who)) and who or "?" }
        elseif event == "UI_INFO_MESSAGE" then
            local message = (type(b) == "string") and b or a
            if type(message) == "string" and not Secret(message) and message == ERR_TRADE_COMPLETE then Done() end
        elseif event == "TRADE_REQUEST_CANCEL" then
            now = nil
        else
            Snapshot()
        end
    end))
end)
function ns:ShowTrades()
    local lines = {}
    for _, t in ipairs(type(ns.root) == "table" and type(ns.root.trades) == "table" and ns.root.trades or {}) do
        local ok, when = pcall(date, "%m-%d %H:%M", t.at)
        lines[#lines + 1] = { left = ns.TradeLine(t) or "?", right = ok and when or "", tip = { tostring(t.who), ns.TradeLine(t) or "" } }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No trades on record yet.") } end
    return ns:ShowList("Trades", "Trades", lines, nil, 560, 320)
end

------------------------------------------------------------------------------------------
-- Deposit materials: with the bank open, every crafting material in your bags goes in.
------------------------------------------------------------------------------------------
function ns:DepositMaterials()
    local bank = _G.BankFrame
    if not (type(bank) == "table" and bank.IsShown and ns.Yes(bank:IsShown())) then ns:Print("Open your bank first."); return 0 end
    local C = C_Container
    local Instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (type(C) == "table" and C.GetContainerItemID and type(Instant) == "function") then return 0 end
    local queue = {}
    for bag = 0, 4 do
        for slot = 1, tonumber(ns:NumSlots(bag)) or 0 do
            local ok, id = pcall(C.GetContainerItemID, bag, slot)
            if ok and type(id) == "number" and not Secret(id) then
                local okI, _, _, _, _, _, class = pcall(Instant, id)
                if okI and class == 7 then queue[#queue + 1] = { bag, slot } end
            end
        end
    end
    local function Next(i)
        local move = queue[i]
        if not move or not ns.Yes(bank:IsShown()) then return end
        pcall(ns.UseBagItem, ns, move[1], move[2])
        ns:After(0.15, function() Next(i + 1) end)                -- (one at a time: the game drops moves sent together)
    end
    Next(1)
    ns:Print(#queue == 1 and "Depositing %d stack of crafting materials." or "Depositing %d stacks of crafting materials.", #queue)
    return #queue
end

------------------------------------------------------------------------------------------
-- Auction price memory: the lowest price you last saw for an item at the auction house, in its tooltip.
------------------------------------------------------------------------------------------
-- The lowest price seen each day, for the last two weeks of days you looked.
function ns.AuctionHistoryAdd(e, day, price)
    e.hist = type(e.hist) == "table" and e.hist or {}
    if not e.hist[day] or price < e.hist[day] then e.hist[day] = price end
    local days = {}
    for d in pairs(e.hist) do days[#days + 1] = d end
    table.sort(days)
    for i = 1, #days - 14 do e.hist[days[i]] = nil end
end
-- The usual price: the middle of the daily lows. Returns price, how many days.
function ns.AuctionUsual(e)
    if type(e) ~= "table" or type(e.hist) ~= "table" then return nil, 0 end
    local list = {}
    for _, p in pairs(e.hist) do if type(p) == "number" then list[#list + 1] = p end end
    if #list == 0 then return nil, 0 end
    table.sort(list)
    local mid = math.floor((#list + 1) / 2)
    local usual = (#list % 2 == 1) and list[mid] or math.floor((list[mid] + list[mid + 1]) / 2)
    return usual, #list
end
-- Let go of items not seen at the auction house for `days` days, so the list doesn't grow forever.
-- Returns how many were let go.
function ns.AuctionForget(seen, today, days)
    local gone = 0
    for id, e in pairs(seen) do
        if type(e) ~= "table" or type(e.day) ~= "number" or ns.DaysBetween(e.day, today) > days then
            seen[id] = nil
            gone = gone + 1
        end
    end
    return gone
end
function ns.AuctionSeenText(entry, today)
    if type(entry) ~= "table" or type(entry.price) ~= "number" then return nil end
    local days = math.max(0, ns.DaysBetween(entry.day, today))
    return (days == 0) and "today" or (days == 1) and "yesterday" or format("%d days ago", days)
end
-- Days from one 20261115-style date to another.
function ns.DaysBetween(a, b)
    local function dayNumber(d)                               -- (days since a fixed date, by the calendar's own rules)
        d = tonumber(d) or 0
        local y, m, day = math.floor(d / 10000), math.floor(d / 100) % 100, d % 100
        if m <= 2 then y, m = y - 1, m + 12 end
        return 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) + math.floor((153 * (m - 3) + 2) / 5) + day
    end
    return dayNumber(b) - dayNumber(a)
end
ns:NewModule("auctionMemory", function()
    if type(ns.root) ~= "table" then return end
    if type(ns.root.auctionSeen) ~= "table" then ns.root.auctionSeen = {} end
    local seen = ns.root.auctionSeen
    ns.AuctionForget(seen, ns.Today(), 60)                        -- (prices older than two months are let go)
    local function Note(id, price)
        if type(id) ~= "number" or type(price) ~= "number" or Secret(price) or price <= 0 then return end
        local today = ns.Today()
        local e = seen[id]
        if not e then e = {}; seen[id] = e end
        if e.day ~= today or not e.price or price < e.price then e.price, e.day = price, today end
        ns.AuctionHistoryAdd(e, today, price)                     -- (the lowest each day, for the usual price)
        ns.auctionNoted = (ns.auctionNoted or 0) + 1
    end
    ns.auctionTest = { Note = Note, seen = seen }
    ns.auctionState = "on; waiting for the auction house"
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "AUCTION_ITEM_LIST_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Auction prices", function(_, event, a)
        local A = C_AuctionHouse
        if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" and A and A.GetBrowseResults then
            for _, r in ipairs(A.GetBrowseResults() or {}) do
                if type(r) == "table" and type(r.itemKey) == "table" then Note(r.itemKey.itemID, r.minPrice) end
            end
        elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" and A and A.GetCommoditySearchResultInfo then
            local r = A.GetCommoditySearchResultInfo(a, 1)
            if type(r) == "table" then Note(a, r.unitPrice) end
        elseif event == "ITEM_SEARCH_RESULTS_UPDATED" and A and A.GetItemSearchResultInfo and type(a) == "table" then
            local r = A.GetItemSearchResultInfo(a, 1)
            if type(r) == "table" then Note(a.itemID, r.buyoutAmount or r.bidAmount) end
        elseif event == "AUCTION_ITEM_LIST_UPDATE" and GetNumAuctionItems and GetAuctionItemInfo then
            for i = 1, tonumber((GetNumAuctionItems("list"))) or 0 do
                local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = GetAuctionItemInfo("list", i)
                if type(buyout) == "number" and type(count) == "number" and count > 0 then Note(id, math.floor(buyout / count)) end
            end
        end
        ns.auctionState = "on; prices noted this session: " .. tostring(ns.auctionNoted or 0)
    end))
    local function Tip(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= _G.ItemRefTooltip then return end
        local id = type(data) == "table" and data.id
        if type(id) ~= "number" and tooltip.GetItem then local ok, _, link = pcall(tooltip.GetItem, tooltip); if ok then id = ns:ItemIDOf(link) end end
        if type(id) ~= "number" or Secret(id) then return end
        local e = seen[id]
        local when = ns.AuctionSeenText(e, ns.Today())
        if when then tooltip:AddDoubleLine(ns:Tr("Auction house") .. " (" .. ns:Tr(when) .. ")", ns:Coins(e.price), 0.6, 0.8, 1, 1, 1, 1) end
        local usual, days = ns.AuctionUsual(e)
        if usual and days >= 2 then tooltip:AddDoubleLine(format(ns:Tr("Usual price (%d days)"), days), ns:Coins(usual), 0.6, 0.8, 1, 1, 1, 1) end
    end
    local safe = ns:Guard("Auction prices", Tip)
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, safe)
    elseif GameTooltip and GameTooltip.HookScript then
        pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", safe)
    end
end)

------------------------------------------------------------------------------------------
-- Loot log: everything you looted this session, with what a vendor would pay for it all.
------------------------------------------------------------------------------------------
-- The game's "You receive loot: %s." (and "%sx%d.") as patterns.
function ns.LootPatterns(templates)
    local out = {}
    for _, template in ipairs(templates) do
        if type(template) == "string" then
            local p = template:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
            p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
            out[#out + 1] = "^" .. p .. "$"
        end
    end
    return out
end
function ns.ParseLoot(message, patterns)
    if type(message) ~= "string" then return nil end
    for _, p in ipairs(patterns) do
        local link, count = message:match(p)
        if link and link:find("|Hitem:", 1, true) then return link, tonumber(count) or 1 end
    end
    return nil
end
ns.lootLog = {}
ns:NewModule("lootLog", function()
    local patterns = ns.LootPatterns({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_PUSHED_SELF_MULTIPLE or "You receive item: %sx%d.",
        LOOT_ITEM_SELF or "You receive loot: %s.", LOOT_ITEM_PUSHED_SELF or "You receive item: %s." })
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_LOOT")
    ev:SetScript("OnEvent", ns:Guard("Loot log", function(_, _, message)
        if type(message) ~= "string" or Secret(message) then return end
        local link, count = ns.ParseLoot(message, patterns)
        if not link then return end
        local ok, price = pcall(function() return (select(11, ns:GetItemInfo(link))) end)
        ns.lootLog[#ns.lootLog + 1] = { link = link, count = count, value = (ok and type(price) == "number") and price * count or 0 }
        while #ns.lootLog > 400 do table.remove(ns.lootLog, 1) end
    end))
end)
function ns:ShowLoot(text)
    if ns.Trim(text):lower() == "clear" then
        for i = #ns.lootLog, 1, -1 do ns.lootLog[i] = nil end
        ns:Print("Loot log cleared.")
        return
    end
    local lines, total = {}, 0
    for i = #ns.lootLog, 1, -1 do
        local l = ns.lootLog[i]
        total = total + (l.value or 0)
        lines[#lines + 1] = { left = (l.count > 1 and (l.count .. " x ") or "") .. l.link, right = (l.value or 0) > 0 and ns:Coins(l.value) or "" }
    end
    if #lines == 0 then lines[1] = { left = "|cff9aa4b4" .. ns:Tr("Nothing looted yet this session.") .. "|r" } end
    table.insert(lines, 1, { left = ns:Tr("Vendor value of it all"), right = ns:Coins(total), color = { 1, 0.82, 0.3 } })
    if not ns.db.lootLog then lines[#lines + 1] = { left = ns:Tr("The loot log is switched off (Features tab).") } end
    return ns:ShowList("Loot", "Looted this session", lines, "/fgui loot clear empties the list.", 460, 360), total
end
