local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Gear upgrades (11.6): a green arrow on gear with a higher item level than what you wear in that
-- slot, on loot rolls, quest rewards and the game's own bags (the one-window bags always had it),
-- "Upgrade: +N item level" on item tooltips, and /fgui equipbest (or "Equip best" on the bags) to
-- put on every upgrade in your bags. A plain item-level comparison: it knows nothing about stats, so
-- treat the arrow as "worth a look". Equip best only takes gear already bound to you, so it never
-- binds anything, and leaves weapons alone unless the new one is the same kind as the one worn.
------------------------------------------------------------------------------------------
local ARROW = "|cff33ff55^|r"
local WEAPONS = { INVTYPE_WEAPON = true, INVTYPE_2HWEAPON = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true,
    INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true, INVTYPE_RELIC = true }

local function ItemLevel(link)
    if type(link) ~= "string" or Secret(link) or not (C_Item and C_Item.GetDetailedItemLevelInfo) then return nil end
    local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if ok and type(v) == "number" and not Secret(v) then return v end
end
local function EquipLoc(link)
    local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(GetInstant) ~= "function" or type(link) ~= "string" then return nil end
    local ok, _, _, _, loc = pcall(GetInstant, link)
    return ok and type(loc) == "string" and loc or nil
end
-- How many item levels better than what is worn, or nil when it is not an upgrade.
function ns.UpgradeAmount(link)
    local lvl = ItemLevel(link)
    if not lvl or not ns.IsUpgrade then return nil end
    local IsWorn = (C_Item and C_Item.IsEquippedItem) or IsEquippedItem
    if type(IsWorn) == "function" then
        local okW, worn = pcall(IsWorn, link)
        if okW and worn == true then return nil end              -- (a ring you wear is no upgrade on the other one)
    end
    local ok, up, by = pcall(ns.IsUpgrade, ns, link, lvl)
    if ok and up then return by end
end

-- Which bag items to put on, and where. items: { { bag, slot, link, ilvl, loc, bound } },
-- worn: { [invSlot] = { ilvl, loc } }. The best pieces go first, each to the worse of its slots.
-- Returns { { item, invSlot } }, and the unbound upgrades left for you to decide on.
function ns.EquipPlan(items, worn)
    local plan, unbound, now = {}, {}, {}
    for slot, w in pairs(worn) do now[slot] = w end
    local list = {}
    for _, it in ipairs(items) do list[#list + 1] = it end
    table.sort(list, function(a, b) if a.ilvl ~= b.ilvl then return a.ilvl > b.ilvl end return tostring(a.link) < tostring(b.link) end)
    for _, it in ipairs(list) do
        local slots = ns.EQUIP_SLOTS and ns.EQUIP_SLOTS[it.loc]
        if slots then
            local best, bestLvl
            for _, s in ipairs(slots) do
                local w = now[s] or { ilvl = 0 }
                local sameKind = not WEAPONS[it.loc] or (w.loc == it.loc)
                if sameKind and (not bestLvl or (w.ilvl or 0) < bestLvl) then best, bestLvl = s, w.ilvl or 0 end
            end
            if best and it.ilvl > bestLvl then
                if it.bound then
                    plan[#plan + 1] = { item = it, slot = best }
                    now[best] = { ilvl = it.ilvl, loc = it.loc }
                else
                    unbound[#unbound + 1] = it
                end
            end
        end
    end
    return plan, unbound
end

local function BagItems()
    local C = C_Container
    local out = {}
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
    for bag = 0, tonumber(NUM_BAG_SLOTS) or 4 do
        local n = tonumber(C.GetContainerNumSlots(bag)) or 0
        for slot = 1, n do
            local info = C.GetContainerItemInfo(bag, slot)
            local link = type(info) == "table" and info.hyperlink
            local loc = link and EquipLoc(link)
            if loc and ns.EQUIP_SLOTS[loc] then
                local lvl = ItemLevel(link)
                local usable = lvl and ns:IsUpgrade(link, lvl)
                if usable then
                    local bound = info.isBound
                    if bound == nil and C_Item and C_Item.IsBound and ItemLocation and ItemLocation.CreateFromBagAndSlot then
                        local okB, b = pcall(C_Item.IsBound, ItemLocation:CreateFromBagAndSlot(bag, slot))
                        bound = okB and b
                    end
                    out[#out + 1] = { bag = bag, slot = slot, link = link, ilvl = lvl, loc = loc, bound = bound == true }
                end
            end
        end
    end
    return out
end
local function Worn()
    local out = {}
    for s = 1, 19 do
        local link = GetInventoryItemLink and GetInventoryItemLink("player", s)
        out[s] = { ilvl = ItemLevel(link) or 0, loc = link and EquipLoc(link) }
    end
    return out
end

local busy = false
function ns:EquipBest()
    if InCombatLockdown() then ns:Print("Not during a fight."); return 0 end
    if busy then return 0 end
    local plan, unbound = ns.EquipPlan(BagItems(), Worn())
    for _, it in ipairs(unbound) do ns:Print("%s would be an upgrade but is not bound to you yet: put it on yourself if you want it.", it.link) end
    if #plan == 0 then
        ns:Print("Nothing in your bags is an upgrade on what you wear.")
        return 0
    end
    busy = true
    local i = 0
    local function Next()
        i = i + 1
        local p = plan[i]
        if not p or InCombatLockdown() then busy = false; ns:Print("Put on %d upgrade(s).", i - 1); return end
        local C = C_Container
        if C and C.PickupContainerItem and EquipCursorItem then
            pcall(C.PickupContainerItem, p.item.bag, p.item.slot)
            pcall(EquipCursorItem, p.slot)
            if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
        end
        ns:After(0.4, Next)
    end
    Next()
    return #plan
end

-- an arrow in the corner of a button that is not ours
local arrows = setmetatable({}, { __mode = "k" })
local function Arrow(button, show)
    local a = arrows[button]
    if not a then
        if not show then return end
        local ok, fs = pcall(button.CreateFontString, button, nil, "OVERLAY")
        if not ok or not fs then return end
        ns:Font(fs, 14)
        fs:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
        fs:SetText(ARROW)
        arrows[button] = fs
        a = fs
    end
    if show then a:Show() else a:Hide() end
    return a
end
ns.UpgradeArrow = Arrow

ns:NewModule("upgradeArrows", function()
    -- quest rewards
    local function Rewards()
        local rf = (_G.QuestInfoFrame and _G.QuestInfoFrame.rewardsFrame) or _G.QuestInfoRewardsFrame
        if type(rf) ~= "table" then return 0 end
        local fromLog = _G.QuestInfoFrame and _G.QuestInfoFrame.questLog
        local n = 0
        for i = 1, 12 do
            local b = (type(QuestInfo_GetRewardButton) == "function" and QuestInfo_GetRewardButton(rf, i)) or (rf.RewardButtons and rf.RewardButtons[i])
            if type(b) == "table" and b.GetID then
                local link
                if b:IsShown() and (b.objectType == nil or b.objectType == "item") and type(b.type) == "string" then
                    local fn = fromLog and GetQuestLogItemLink or GetQuestItemLink
                    if type(fn) == "function" then local ok, l = pcall(fn, b.type, b:GetID()); if ok then link = l end end
                end
                local up = link and ns.UpgradeAmount(link)
                Arrow(b, up and true or false)
                if up then n = n + 1 end
            end
        end
        return n
    end
    if type(QuestInfo_Display) == "function" and hooksecurefunc then
        hooksecurefunc("QuestInfo_Display", function() pcall(Rewards) end)
    end
    -- the game's own bags (the one-window bags have their own arrows)
    local function GameBag(frame)
        if ns.db.bagWindow or type(frame) ~= "table" then return end
        local buttons = {}
        if frame.EnumerateValidItems then
            pcall(function() for _, b in frame:EnumerateValidItems() do buttons[#buttons + 1] = b end end)
        elseif frame.Items then
            for _, b in ipairs(frame.Items) do buttons[#buttons + 1] = b end
        end
        local C = C_Container
        for _, b in ipairs(buttons) do
            local bag = (b.GetBagID and b:GetBagID()) or (frame.GetID and frame:GetID())
            local slot = b.GetID and b:GetID()
            local info = C and C.GetContainerItemInfo and type(bag) == "number" and type(slot) == "number" and C.GetContainerItemInfo(bag, slot)
            local link = type(info) == "table" and info.hyperlink
            Arrow(b, link and ns.UpgradeAmount(link) and true or false)
        end
    end
    if hooksecurefunc then
        for i = 1, 13 do
            local f = _G["ContainerFrame" .. i]
            if type(f) == "table" and type(f.UpdateItems) == "function" then hooksecurefunc(f, "UpdateItems", function(self) pcall(GameBag, self) end) end
        end
        local combined = _G.ContainerFrameCombinedBags
        if type(combined) == "table" and type(combined.UpdateItems) == "function" then hooksecurefunc(combined, "UpdateItems", function(self) pcall(GameBag, self) end) end
    end
    -- tooltips: by how much
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ns:Guard("Upgrade tooltip", function(tip)
            if not ns.db.upgradeArrows or (tip ~= GameTooltip and tip ~= _G.ItemRefTooltip) or not tip.GetItem then return end
            local ok, _, link = pcall(tip.GetItem, tip)
            if not ok or type(link) ~= "string" or Secret(link) then return end
            local by = ns.UpgradeAmount(link)
            if by and by > 0 then tip:AddLine(format(ns:Tr("Upgrade: +%d item level over what you wear"), by), 0.3, 1, 0.4) end
        end))
    end
    ns.upgradeTest = { Rewards = Rewards, GameBag = GameBag }
end)
