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
    if ns:AfterFight("Equip best", function() ns:EquipBest() end) then return 0 end
    if busy then return 0 end
    local plan, unbound = ns.EquipPlan(BagItems(), Worn())
    if #unbound > 0 then                                          -- (one line, however many there are)
        local links = {}
        for _, it in ipairs(unbound) do links[#links + 1] = tostring(it.link) end
        ns:Print("Upgrades not bound to you yet, so left for you to put on: %s", table.concat(links, ", "))
    end
    if #plan == 0 then
        ns:Print("Nothing in your bags is an upgrade on what you wear.")
        return 0
    end
    busy = true
    local i, done = 0, {}
    local function Next()
        i = i + 1
        local p = plan[i]
        if not p or InCombatLockdown() then
            busy = false
            if #done > 0 then ns:Print("Put on: %s", table.concat(done, ", ")) end
            return
        end
        done[#done + 1] = tostring(p.item.link)
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
            if by and by > 0 then local r, g, b = ns:Signal("good"); tip:AddLine(format(ns:Tr("Upgrade: +%d item level over what you wear"), by), r, g, b) end
        end))
    end
    ns.upgradeTest = { Rewards = Rewards, GameBag = GameBag }
end)

------------------------------------------------------------------------------------------
-- Equip prompt (11.17): loot an upgrade and a small notice shows it, with by how many item levels it
-- beats what you wear and a button to put it on. For a ring or a trinket there is a button for each
-- of the two you wear, so you choose which goes. In a fight the click waits for the fight to end.
-- An item that is not yet bound to you is put on the same way, and the game asks you first, as it
-- always does. The notice goes after a minute, or with its cross.
------------------------------------------------------------------------------------------
local SLOT_NAMES = { [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2", [16] = "Main hand", [17] = "Off hand" }

-- The choices for an item: { { slot, label, worn level } } - one for most, two for rings and trinkets.
function ns.EquipChoices(loc, worn)
    local slots = ns.EQUIP_SLOTS and ns.EQUIP_SLOTS[loc]
    if not slots then return {} end
    if loc ~= "INVTYPE_FINGER" and loc ~= "INVTYPE_TRINKET" then
        local best, bestLvl
        for _, s in ipairs(slots) do                          -- (the worse of its slots, as Equip best does)
            local l = (worn[s] and worn[s].ilvl) or 0
            if not best or l < bestLvl then best, bestLvl = s, l end
        end
        return { { slot = best, label = "Equip", ilvl = bestLvl } }
    end
    local out = {}
    for _, s in ipairs(slots) do out[#out + 1] = { slot = s, label = SLOT_NAMES[s], ilvl = (worn[s] and worn[s].ilvl) or 0 } end
    return out
end

local function FindInBags(link)
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
    local want = tonumber(tostring(link):match("item:(%d+)"))
    local fallback
    for bag = 0, tonumber(NUM_BAG_SLOTS) or 4 do
        for slot = 1, tonumber(C.GetContainerNumSlots(bag)) or 0 do
            local info = C.GetContainerItemInfo(bag, slot)
            local l = type(info) == "table" and info.hyperlink
            if l == link then return bag, slot, l end            -- (this very item; another of the same name only if it is not found)
            if not fallback and want and type(l) == "string" and tonumber(l:match("item:(%d+)")) == want then fallback = { bag, slot, l } end
        end
    end
    if fallback then return fallback[1], fallback[2], fallback[3] end
end
-- Put the item (found again in the bags, as it may have moved) into `invSlot`.
local function PutOn(link, invSlot)
    if ns:AfterFight("Equip upgrade", function() PutOn(link, invSlot) end) then
        ns:Print("It goes on when the fight is over.")
        return "later"
    end
    local bag, slot = FindInBags(link)
    if not bag then ns:Print("That item is no longer in your bags.") return false end
    local C = C_Container
    if not (C and C.PickupContainerItem and EquipCursorItem) then return false end
    pcall(C.PickupContainerItem, bag, slot)
    pcall(EquipCursorItem, invSlot)
    if CursorHasItem and CursorHasItem() and ClearCursor then ClearCursor() end
    return true
end
ns.EquipUpgradeNow = PutOn

ns:NewModule("upgradePrompt", function()
    local f = CreateFrame("Frame", "FantasyGlassUIUpgradePrompt", UIParent, ns.template)
    f:SetSize(300, 64)
    f:SetPoint("TOP", UIParent, "TOP", 0, -300)
    f:SetFrameStrata("HIGH")
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "bg", 0.92)
    ns:Paint(f, "SetBackdropBorderColor", "@border", 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(36, 36)
    f.icon:SetPoint("TOPLEFT", 8, -8)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = ns:NewText(f, 10, "LEFT", true)
    f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, 0)
    f.title:SetPoint("RIGHT", -24, 0)
    f.item = ns:NewText(f, 12, "LEFT")
    f.item:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.item:SetPoint("RIGHT", -10, 0)
    if f.item.SetWordWrap then f.item:SetWordWrap(false) end
    local queue = {}                                          -- (11.17.1) several upgrades at once: one after another
    local Show
    local function Next()
        f:Hide()
        while #queue > 0 do
            local q = table.remove(queue, 1)
            if FindInBags(q.link) and ns.UpgradeAmount(q.link) then Show(q.link, ns.UpgradeAmount(q.link)); return end
        end
    end
    f.close = ns:CreateButton(f, "x", 18, 18, function() Next() end)
    f.close:SetPoint("TOPRIGHT", -4, -4)
    f.buttons = {}
    for i = 1, 2 do
        local b = ns:CreateButton(f, "", 90, 20, function(self) if self.slot and f.link then PutOn(f.link, self.slot); ns:After(0.6, Next) end end)
        b:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 8 + (i - 1) * 96, -18)
        b:Hide()
        f.buttons[i] = b
    end
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if not (self.link and GameTooltip) then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    f:Hide()
    local entry = ns:RegisterMovable(f, "upgradePrompt", "Upgrade notice")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)

    Show = function(link, by)
        if f:IsShown() and f.link and f.link ~= link then              -- (one is showing: this one waits its turn)
            for _, q in ipairs(queue) do if q.link == link then return true end end
            queue[#queue + 1] = { link = link }
            f.title:SetText(ns:SignalHex("good") .. format(ns:Tr("Upgrade: +%d item levels"), math.floor((f.by or 0) + 0.5)) .. "|r  |cff9aa4b4" .. format(ns:Tr("(%d more)"), #queue) .. "|r")
            return true
        end
        local loc = EquipLoc(link)
        local choices = ns.EquipChoices(loc, Worn())
        if #choices == 0 then return false end
        f.link, f.by = link, by
        f.shownAt = GetTime()
        local id = tonumber(tostring(link):match("item:(%d+)"))
        local GetIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
        local okT, tex = pcall(GetIcon or error, id)
        f.icon:SetTexture((okT and tex) or 134400)
        f.title:SetText(ns:SignalHex("good") .. format(ns:Tr("Upgrade: +%d item levels"), math.floor(by + 0.5)) .. "|r"
            .. ((#queue > 0) and ("  |cff9aa4b4" .. format(ns:Tr("(%d more)"), #queue) .. "|r") or ""))
        f.item:SetText(link)
        for i, b in ipairs(f.buttons) do
            local c = choices[i]
            if c then
                b.slot = c.slot
                b.text:SetText(c.label == "Equip" and ns:Tr("Equip") or format(ns:Tr("Replace %s"), ns:Tr(c.label)))
                b:SetWidth(#choices == 1 and 90 or 120)
                b:ClearAllPoints()
                b:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 8 + (i - 1) * 126, -18)
                b:Show()
            else
                b:Hide()
            end
        end
        f:SetWidth(#choices == 1 and 300 or 320)
        f:Show()
        return true
    end
    ns.upgradePromptTest = { Show = function(...) return Show(...) end, frame = f, Queue = function() return queue end, Next = Next }

    local patterns = ns.LootPatterns({ LOOT_ITEM_SELF_MULTIPLE or "You receive loot: %sx%d.", LOOT_ITEM_SELF or "You receive loot: %s.",
        LOOT_ITEM_PUSHED_SELF_MULTIPLE or "You receive item: %sx%d.", LOOT_ITEM_PUSHED_SELF or "You receive item: %s." })
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_LOOT")
    pcall(ev.RegisterEvent, ev, "PLAYER_EQUIPMENT_CHANGED")
    ev:SetScript("OnEvent", ns:Guard("Upgrade notice", function(_, event, msg)
        if event == "PLAYER_EQUIPMENT_CHANGED" then              -- (put on some other way, or no longer an upgrade: it goes)
            ns:After(0.3, function()
                if f:IsShown() and f.link and not (FindInBags(f.link) and ns.UpgradeAmount(f.link)) then Next() end
            end)
            return
        end
        if type(msg) ~= "string" or Secret(msg) then return end
        local link = ns.ParseLoot(msg, patterns)
        if not link then return end
        local function Try(again)
            local by = ns.UpgradeAmount(link)
            if by then
                local _, _, real = FindInBags(link)
                Show(real or link, by)
            elseif again then
                ns:After(1, function() pcall(Try, false) end)         -- (the item's level may not be known on the first look)
            end
        end
        Try(true)
    end))
    ns:Every(5, "Upgrade notice", function()
        if f:IsShown() and f.shownAt and GetTime() - f.shownAt > 60 then Next() end
    end)
end)
