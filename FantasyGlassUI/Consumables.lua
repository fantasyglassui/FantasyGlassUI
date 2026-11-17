local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- The consumables bar: a small bar that fills itself with what is in your bags - potions, bandages,
-- food and drink, flasks, elixirs, scrolls - one button for each, with how many you have. Click one
-- to use it. Nothing to drag anywhere.
--
-- The buttons are secure ones (using an item is something only the game may do), so which item each
-- holds can only be changed between fights. In a fight the counts still tick down, and a button
-- whose item has run out is grayed until the fight ends and the bar is laid out again.
------------------------------------------------------------------------------------------
-- The kinds shown, by the game's number for the kind, in the order they appear on the bar.
local ORDER = { [1] = 1,    -- potions
                [7] = 2,    -- bandages
                [5] = 3,    -- food and drink
                [3] = 4,    -- flasks
                [2] = 5,    -- elixirs
                [4] = 6 }   -- scrolls
ns.consumableKinds = ORDER

-- Which of these items go on the bar, and in what order: by kind, then the better item first.
-- items: { { id, sub (the game's number for its kind), level, icon } ... }
function ns.ConsumablePick(items, max)
    local out, seen = {}, {}
    for _, item in ipairs(items or {}) do
        if type(item) == "table" and item.id and not seen[item.id] and ORDER[item.sub] then
            seen[item.id] = true
            out[#out + 1] = item
        end
    end
    table.sort(out, function(a, b)
        if ORDER[a.sub] ~= ORDER[b.sub] then return ORDER[a.sub] < ORDER[b.sub] end
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) > (b.level or 0) end
        return a.id < b.id
    end)
    while #out > (max or 10) do table.remove(out) end
    return out
end

-- Everything consumable in your bags, one entry per kind of item.
function ns:BagConsumables()
    local list, seen = {}, {}
    local C = C_Container
    local Instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (type(C) == "table" and type(C.GetContainerNumSlots) == "function" and type(C.GetContainerItemID) == "function" and type(Instant) == "function") then return list end
    for bag = 0, 4 do
        local okN, slots = pcall(C.GetContainerNumSlots, bag)
        for slot = 1, (okN and type(slots) == "number") and slots or 0 do
            local okI, id = pcall(C.GetContainerItemID, bag, slot)
            if okI and type(id) == "number" and not Secret(id) and not seen[id] then
                seen[id] = true
                local ok, _, _, _, _, icon, class, sub = pcall(Instant, id)
                if ok and class == 0 and ORDER[sub] then
                    local level = 0
                    local GetInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
                    if type(GetInfo) == "function" then
                        local okL, _, _, _, itemLevel = pcall(GetInfo, id)
                        if okL and type(itemLevel) == "number" then level = itemLevel end
                    end
                    list[#list + 1] = { id = id, sub = sub, level = level, icon = icon }
                end
            end
        end
    end
    return list
end

ns:NewModule("consumeBar", function()
    local SIZE, GAP, MAX = 30, 4, 10
    ns.consumeState = "waiting for your bags"

    local holder = CreateFrame("Frame", "FantasyGlassUIConsumables", UIParent)
    holder:SetSize(SIZE, SIZE)
    holder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
    local buttons = {}
    local dirty, pending = true, false

    local function Button(i)
        local ok, b = pcall(CreateFrame, "Button", "FantasyGlassUIConsumable" .. i, holder, "SecureActionButtonTemplate")
        if not (ok and b and b.SetAttribute) then return nil end
        b:SetSize(SIZE, SIZE)
        b:SetPoint("LEFT", holder, "LEFT", (i - 1) * (SIZE + GAP), 0)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetTexture(ns.FLAT)
        b.hl:SetVertexColor(1, 1, 1, 0.18)
        local okC, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if okC and cd then cd:SetAllPoints(); b.cd = cd end
        b.count = ns:NewText(b, 11, "RIGHT")
        b.count:SetPoint("BOTTOMRIGHT", -1, 2)
        if b.count.SetShadowOffset then b.count:SetShadowOffset(1, -1); b.count:SetShadowColor(0, 0, 0, 1) end
        ns:AddBorder(b, 0, 0, 0, 1)
        b:HookScript("OnEnter", function(self)
            if not self.itemID then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if not (GameTooltip.SetItemByID and pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID)) then GameTooltip:AddLine("item " .. self.itemID) end
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        buttons[i] = b
        return b
    end

    -- which item each button holds: only between fights
    local function Assign()
        if InCombatLockdown() then pending = true; return false end
        pending, dirty = false, false
        local list = ns.ConsumablePick(ns:BagConsumables(), MAX)
        for i = 1, math.max(#list, #buttons) do
            local item, b = list[i], buttons[i]
            if item then
                b = b or Button(i)
                if b then
                    b.itemID = item.id
                    b:SetAttribute("type", "item")
                    b:SetAttribute("item", "item:" .. item.id)
                    b.icon:SetTexture(item.icon)
                    b:Show()
                end
            elseif b then
                b.itemID = nil
                b:SetAttribute("item", nil)
                b:Hide()
            end
        end
        holder:SetWidth(math.max(1, #list) * (SIZE + GAP) - GAP)
        ns.consumeState = (#list == 0) and "on; nothing consumable in your bags" or format("on; %d items on the bar", #list)
        return #list
    end
    local Count = (C_Item and C_Item.GetItemCount) or GetItemCount
    local Cooldown = (C_Container and C_Container.GetItemCooldown) or (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
    -- how many are left, and the cooldown: any time
    local function Tick()
        for _, b in ipairs(buttons) do
            if b.itemID then
                local n = 0
                if type(Count) == "function" then
                    local ok, v = pcall(Count, b.itemID)
                    if ok and type(v) == "number" and not Secret(v) then n = v end
                end
                b.count:SetText(n > 1 and tostring(n) or "")
                if b.icon.SetDesaturated then b.icon:SetDesaturated(n == 0) end
                if b.cd and type(Cooldown) == "function" then
                    pcall(function()
                        local start, duration = Cooldown(b.itemID)
                        b.cd:SetCooldown(start, duration)
                    end)
                end
            end
        end
    end
    ns.consumeTest = { Assign = Assign, Tick = Tick, buttons = buttons, holder = holder, Pending = function() return pending end }

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Consumables events", function() dirty = true end))
    ns:Every(0.5, "Consumables bar", function()
        if (dirty or pending) and not InCombatLockdown() then pcall(Assign) end
        Tick()
    end)
    ns:RegisterMovable(holder, "consumables", "Consumables")
end)
