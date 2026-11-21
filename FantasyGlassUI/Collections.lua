local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- 11.4: sorting your bags by your bag rules, mount and pet buttons, and reputations and currencies
-- across all your characters.
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Sort bags (/fgui sort, or the Tools menu): your bags in the order of your bag sections - your own
-- rules first, then the ready-made sections switched on, then gear, consumables, quest items, trade
-- goods, the rest and junk - best quality first inside each. One move at a time, waiting for the game
-- each time; never in a fight. Special bags (and the reagent bag) are left as they are.
------------------------------------------------------------------------------------------
local USUAL = { Equipment = 1, Consumables = 2, Quest = 3, ["Trade Goods"] = 4, Other = 5, Junk = 6 }
function ns.UsualSection(classID, quality)
    if quality == 0 then return "Junk" end
    if classID == 2 or classID == 4 then return "Equipment" end
    if classID == 0 then return "Consumables" end
    if classID == 12 then return "Quest" end
    if classID == 7 or classID == 5 or classID == 3 or classID == 9 or classID == 8 then return "Trade Goods" end
    return "Other"
end
-- The order key of an item: { section rank, -quality, classID, itemID, -count, link }.
function ns.SortKey(item)
    local rank
    if item.section then rank = ns.BagRuleRank and ns.BagRuleRank(item.section) or 1000 end
    if not rank or rank >= 1000 then rank = 2000 + (USUAL[ns.UsualSection(item.classID, item.quality)] or 9) end
    return { rank, -(item.quality or 0), item.classID or 99, item.itemID or 0, -(item.count or 1), item.link or "" }
end
function ns.SortBefore(a, b)
    local ka, kb = a.key, b.key
    for i = 1, #ka do
        if ka[i] ~= kb[i] then return ka[i] < kb[i] end
    end
    return false
end
-- Where every item should be: the slots in bag order, filled from the front.
function ns.SortPlan(slots)
    local items = {}
    for _, s in ipairs(slots) do if s.item then items[#items + 1] = s.item end end
    for _, it in ipairs(items) do it.key = it.key or ns.SortKey(it) end
    table.sort(items, ns.SortBefore)
    return items
end
-- The next move: the first slot that holds the wrong thing, and the slot to fetch the right one from.
local function Same(a, b)
    if not a or not b then return a == b end
    return a.itemID == b.itemID and a.count == b.count and a.link == b.link
end
function ns.SortNextMove(slots, plan)
    for i, s in ipairs(slots) do
        local want = plan[i]
        if not Same(s.item, want) then
            if not want then return nil end            -- (everything wanted is in front: the rest is empty)
            for j = i + 1, #slots do
                if Same(slots[j].item, want) then return i, j end
            end
            return nil
        end
    end
    return nil
end
local function SortableBags()
    local out = {}
    local C = C_Container
    for bag = 0, 4 do
        local okF, _, bagType = pcall(C.GetContainerNumFreeSlots, bag)
        if okF and (bagType == 0 or bagType == nil) then out[#out + 1] = bag end
    end
    return out
end
local function ReadSlots()
    local C = C_Container
    local slots, locked = {}, false
    local GetInstant = C_Item.GetItemInfoInstant
    for _, bag in ipairs(SortableBags()) do
        for slot = 1, (tonumber(C.GetContainerNumSlots(bag)) or 0) do
            local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
            local s = { bag = bag, slot = slot }
            if ok and type(info) == "table" and info.itemID then
                if info.isLocked then locked = true end
                local it = { itemID = info.itemID, count = info.stackCount or 1, quality = info.quality,
                             link = (type(info.hyperlink) == "string" and not Secret(info.hyperlink)) and info.hyperlink or nil }
                if GetInstant then local okI, _, _, _, _, _, classID = pcall(GetInstant, info.itemID); if okI then it.classID = classID end end
                if ns.BagRuleFor then local okR, sec = pcall(ns.BagRuleFor, ns, info); if okR then it.section = sec end end
                s.item = it
            end
            slots[#slots + 1] = s
        end
    end
    return slots, locked
end
local sorting
function ns:SortBags()
    if ns:AfterFight("Sort bags", function() ns:SortBags() end) then return false end
    local C = C_Container
    if not (C and C.PickupContainerItem and C.GetContainerItemInfo) then ns:Print("This game client cannot sort bags for an add-on."); return false end
    if sorting then sorting = nil; ns:Print("Sorting stopped."); return false end
    if CursorHasItem and CursorHasItem() then ns:Print("Put down what you are holding first."); return false end
    sorting = { moves = 0, waits = 0 }
    local function Step()
        if not sorting then return end
        if InCombatLockdown() then sorting = nil; ns:Print("Sorting stopped: a fight started."); return end
        local slots, locked = ReadSlots()
        if locked or (CursorHasItem and CursorHasItem()) then
            sorting.waits = sorting.waits + 1
            if sorting.waits > 60 then sorting = nil; ns:Print("Sorting stopped: the game kept the bags busy."); return end
            ns:After(0.1, Step)
            return
        end
        sorting.waits = 0
        local i, j = ns.SortNextMove(slots, ns.SortPlan(slots))
        if not i or sorting.moves >= 500 then
            ns:Print(sorting.moves == 1 and "Bags sorted (%d move)." or "Bags sorted (%d moves).", sorting.moves)
            sorting = nil
            if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end
            return
        end
        sorting.moves = sorting.moves + 1
        pcall(C.PickupContainerItem, slots[j].bag, slots[j].slot)
        pcall(C.PickupContainerItem, slots[i].bag, slots[i].slot)
        if CursorHasItem and CursorHasItem() then pcall(C.PickupContainerItem, slots[j].bag, slots[j].slot) end   -- (a swap the game did by halves)
        ns:After(0.08, Step)
    end
    Step()
    return true
end

------------------------------------------------------------------------------------------
-- Mount and pet buttons: two small movable buttons - a random favorite mount (one that suits where
-- you are) and a random favorite pet - and key bindings for both (the game's Key Bindings, AddOns).
------------------------------------------------------------------------------------------
function ns:SummonPet()
    local P = C_PetJournal
    if not (type(P) == "table" and type(P.SummonRandomPet) == "function") then ns:Print("This game client has no pet collection an add-on can use."); return false end
    return pcall(P.SummonRandomPet, true) and "summoned" or false
end
BINDING_NAME_FANTASYGLASSUI_PET = "Pet (random favorite)"
ns:NewModule("mountButtons", function()
    local f = CreateFrame("Frame", "FantasyGlassUIMountButtons", UIParent)
    f:SetSize(2 * 32 + 4, 32)
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -300, 60)
    local function Button(i, icon, tip, fn)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(32, 32)
        b:SetPoint("LEFT", (i - 1) * 36, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexture(icon)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ns:AddBorder(b, 0, 0, 0, 1)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function() fn() end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:Tr(tip))
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end
    f.mount = Button(1, 132261, "Mount (random favorite)", function() ns:MountUp() end)
    f.pet = Button(2, 132599, "Pet (random favorite)", function() ns:SummonPet() end)
    ns.mountButtonsTest = f
    local entry = ns:RegisterMovable(f, "mountButtons", "Mount and pet")
    if type(entry) == "table" then entry.offPage = true end
end)

------------------------------------------------------------------------------------------
-- Reputations and currencies on all your characters (/fgui reps). Each character's are noted as
-- you play it; pin the ones you care about (click a line) and they are listed first, with every
-- character's standing.
------------------------------------------------------------------------------------------
local function Store()
    if type(ns.root) ~= "table" then return { chars = {}, pins = {} } end
    local s = ns.root.repTrack
    if type(s) ~= "table" then s = {}; ns.root.repTrack = s end
    s.chars = type(s.chars) == "table" and s.chars or {}
    s.pins = type(s.pins) == "table" and s.pins or {}
    return s
end
ns.RepStore = Store
-- What a character has: reps[name] = { standing = "Honored", now, max, reaction }, money[name] = quantity.
function ns:RecordRepsAndCurrencies()
    if InCombatLockdown() then return false end
    local me = ns:CharKey()
    local mine = { reps = {}, currencies = {}, class = select(2, UnitClass("player")), at = time and time() or 0 }
    local R = C_Reputation
    if R and R.GetNumFactions and R.GetFactionDataByIndex then
        local okN, n = pcall(R.GetNumFactions)
        for i = 1, (okN and tonumber(n)) or 0 do
            local ok, d = pcall(R.GetFactionDataByIndex, i)
            if ok and type(d) == "table" and type(d.name) == "string" and not d.isHeader and not Secret(d.currentStanding) then
                local lo, hi = tonumber(d.currentReactionThreshold) or 0, tonumber(d.nextReactionThreshold) or 0
                mine.reps[d.name] = { reaction = d.reaction, now = (tonumber(d.currentStanding) or 0) - lo, max = math.max(0, hi - lo) }
            end
        end
    end
    local Cu = C_CurrencyInfo
    if Cu and Cu.GetCurrencyListSize and Cu.GetCurrencyListInfo then
        local okN, n = pcall(Cu.GetCurrencyListSize)
        for i = 1, (okN and tonumber(n)) or 0 do
            local ok, c = pcall(Cu.GetCurrencyListInfo, i)
            if ok and type(c) == "table" and type(c.name) == "string" and not c.isHeader and type(c.quantity) == "number" and not Secret(c.quantity) then
                mine.currencies[c.name] = c.quantity
            end
        end
    end
    Store().chars[me] = mine
    return true
end
-- The lines of the window: pinned first (every character), then this character's.
function ns.RepLines(store, me)
    local lines = {}
    local function Standing(r)
        local label = r.reaction and _G["FACTION_STANDING_LABEL" .. tostring(r.reaction)] or ""
        if (r.max or 0) <= 0 then return label end                  -- (at the top: no progress to show)
        return format("%s  %d / %d", label, r.now or 0, r.max or 0)
    end
    local chars = {}
    for char in pairs(store.chars) do chars[#chars + 1] = char end
    table.sort(chars, function(a, b) if a == me then return true elseif b == me then return false end return a < b end)
    local pinned = {}
    for name in pairs(store.pins) do pinned[#pinned + 1] = name end
    table.sort(pinned)
    for _, name in ipairs(pinned) do
        lines[#lines + 1] = { head = true, name = name }
        for _, char in ipairs(chars) do
            local c = store.chars[char]
            local r = c.reps and c.reps[name]
            local q = c.currencies and c.currencies[name]
            if r then lines[#lines + 1] = { char = char, class = c.class, text = Standing(r), name = name }
            elseif q then lines[#lines + 1] = { char = char, class = c.class, text = tostring(q), name = name } end
        end
    end
    local here = store.chars[me]
    if here then
        local names = {}
        for name in pairs(here.reps or {}) do if not store.pins[name] then names[#names + 1] = name end end
        table.sort(names)
        if #names > 0 then lines[#lines + 1] = { section = "Reputations" } end
        for _, name in ipairs(names) do lines[#lines + 1] = { mine = true, name = name, text = Standing(here.reps[name]) } end
        local cur = {}
        for name in pairs(here.currencies or {}) do if not store.pins[name] then cur[#cur + 1] = name end end
        table.sort(cur)
        if #cur > 0 then lines[#lines + 1] = { section = "Currencies" } end
        for _, name in ipairs(cur) do lines[#lines + 1] = { mine = true, name = name, text = tostring(here.currencies[name]) } end
    end
    return lines
end
function ns:ShowReps()
    pcall(ns.RecordRepsAndCurrencies, ns)
    local store = Store()
    local out = {}
    for _, l in ipairs(ns.RepLines(store, ns:CharKey())) do
        if l.head then
            out[#out + 1] = { left = ns:AccentHex() .. l.name .. "|r", right = "|cff9aa4b4" .. ns:Tr("pinned") .. "|r",
                click = function() store.pins[l.name] = nil; ns:ShowReps() end, tip = { l.name, ns:Tr("Click: unpin it.") } }
        elseif l.section then
            out[#out + 1] = { left = ns:AccentHex() .. ns:Tr(l.section) .. "|r" }
        elseif l.char then
            local r, g, b = ns:ClassRGB(l.class)
            out[#out + 1] = { left = "    " .. tostring(l.char):gsub(" %- .*$", ""), right = l.text, color = { r or 1, g or 1, b or 1 } }
        else
            out[#out + 1] = { left = "    " .. l.name, right = l.text,
                click = function() store.pins[l.name] = true; ns:ShowReps() end, tip = { l.name, ns:Tr("Click: pin it, to see it for all your characters.") } }
        end
    end
    if #out == 0 then out[1] = { left = ns:Tr("Nothing noted yet: open your reputation window once.") } end
    return ns:ShowList("Reps", "Reputations and currencies", out, "Pin a line to see it for all your characters. Each character's are noted as you play it.", 480, 440)
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_FACTION", "CURRENCY_DISPLAY_UPDATE", "PLAYER_LOGOUT" }) do pcall(ev.RegisterEvent, ev, e) end
    local pending
    ev:SetScript("OnEvent", ns:Guard("Reputations", function(_, event)
        if not ns.db then return end
        if event == "PLAYER_LOGOUT" then pcall(ns.RecordRepsAndCurrencies, ns); return end
        if pending then return end
        pending = true
        ns:After(3, function() pending = nil; pcall(ns.RecordRepsAndCurrencies, ns) end)
    end))
end
