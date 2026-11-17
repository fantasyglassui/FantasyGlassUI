local _, ns = ...

ns:NewModule("tooltip", function()
    local function Style(tip, r, g, b)
        local nine = tip.NineSlice
        if nine and nine.SetCenterColor then
            ns:Paint(nine, "SetCenterColor", "bg", 0.94)
            nine:SetBorderColor(r or 0.2, g or 0.2, b or 0.26, 1)
            tip.suiStyledAt = GetTime()
        end
    end
    -- A tooltip being shown that the item-and-unit pass may not reach (or has only just colored):
    -- the panel always; the border only if nothing has set it in the last moment, so an item's
    -- quality color put on a split second earlier is not wiped.
    local function OnShown(tip)
        local nine = tip.NineSlice
        if not (nine and nine.SetCenterColor) then return end
        ns:Paint(nine, "SetCenterColor", "bg", 0.94)
        if not tip.suiStyledAt or GetTime() - tip.suiStyledAt > 0.1 then nine:SetBorderColor(0.2, 0.2, 0.26, 1) end
    end
    ns.TooltipOnShown = OnShown

    -- Is there already a line on this tooltip containing `needle`? (So nothing is added twice.)
    local function TipHasLine(tip, needle)
        local base = tip.GetName and tip:GetName()
        if type(needle) ~= "string" or needle == "" or type(base) ~= "string" then return false end
        for i = 1, (tip.NumLines and tonumber(tip:NumLines()) or 0) do
            local fs = _G[base .. "TextLeft" .. i]
            local text = type(fs) == "table" and fs.GetText and fs:GetText()
            if type(text) == "string" and not ns:IsSecret(text) and text:find(needle, 1, true) then return true end
        end
        return false
    end
    -- "Item ID" / "Spell ID", for people who write macros (a switch, off unless chosen)
    local function AddID(tip, label, id)
        if not ns.db.tooltipIDs or type(id) ~= "number" or ns:IsSecret(id) or TipHasLine(tip, label) then return end
        tip:AddDoubleLine(label, tostring(id), 0.55, 0.57, 0.62, 0.85, 0.85, 0.88)
    end

    local function OnTip(tip)
        if not tip or not tip.GetUnit then return end
        local r, g, b
        local _, unit = tip:GetUnit()
        if unit and ns:IsSecret(unit) then
            -- The game is keeping this unit to itself: nothing can be asked about it, so the tooltip
            -- is styled like any other and left at that.
        elseif unit then
            r, g, b = ns:ClassColor(unit)
            local line1 = _G[(tip:GetName() or "") .. "TextLeft1"]
            if r and line1 then line1:SetTextColor(r, g, b) end
            local tgt = unit .. "target"
            local okT, has = pcall(UnitExists, tgt)
            if okT and not ns:IsSecret(has) and has and not tip.suiTargetAdded and ns.db.tipTarget ~= false then
                local tr, tg, tb = ns:ClassColor(tgt)
                local okN, isMe = pcall(UnitIsUnit, tgt, "player")
                -- (for a token like "mouseovertarget" the game hides whether it is you: then it is named instead)
                local name = (okN and ns.Is(isMe, true)) and ns:Tr("YOU") or UnitName(tgt)
                if type(name) == "string" and not ns:IsSecret(name) then
                    tip:AddLine(ns:Tr("Targeting") .. ": " .. name, tr or 1, tg or 0.35, tb or 0.35)
                end
            end
            -- a player's rank in their guild (the game shows the guild's name, not the rank)
            local okP, isPlayer = pcall(UnitIsPlayer, unit)
            if okP and ns.Is(isPlayer, true) and type(GetGuildInfo) == "function" and ns.db.tipGuildRank ~= false then
                local okG, _, rank = pcall(GetGuildInfo, unit)
                local label = ns:Tr("Guild rank")
                if okG and type(rank) == "string" and rank ~= "" and not ns:IsSecret(rank) and not TipHasLine(tip, label) then
                    tip:AddLine(label .. ": " .. rank, 0.72, 0.74, 0.80)
                end
            end
        elseif tip.GetItem then
            local _, link = tip:GetItem()
            if link and ns:IsSecret(link) then link = nil end       -- (an item the game will not name: nothing to add)
            if type(link) == "string" then
                AddID(tip, "Item ID", ns.ItemIDOf and ns:ItemIDOf(link))
            elseif link == nil and tip.GetSpell and ns.db.tooltipIDs then
                local okS, _, spellID = pcall(tip.GetSpell, tip)
                if okS then AddID(tip, "Spell ID", spellID) end
            end
            if link and type(link) == "string" then                 -- on one of the two lists that correct "sell junk"
                local listed = ns.ItemListState and ns:ItemListState(link)
                if listed == "sell" then tip:AddLine(ns:Tr("Always sold with your junk"), 1, 0.82, 0.2)
                elseif listed == "keep" then tip:AddLine(ns:Tr("Never sold with your junk"), 0.35, 0.9, 0.45) end
            end
            if link and ns.db.tooltipExtras and type(link) == "string" then
                local function HasLine(needle)
                    if type(needle) ~= "string" or needle == "" then return false end
                    local base = tip:GetName()
                    if type(base) ~= "string" then return false end
                    for i = 1, (tip.NumLines and tip:NumLines() or 0) do
                        local fs = _G[base .. "TextLeft" .. i]
                        local text = fs and fs:GetText()
                        if type(text) == "string" and not ns:IsSecret(text) and text:find(needle, 1, true) then return true end
                    end
                    return false
                end
                local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
                local classID = GetInstant and select(6, GetInstant(link))
                local levelLabel = type(ITEM_LEVEL) == "string" and ITEM_LEVEL:gsub("%%d.*$", "") or "Item Level "
                if (classID == 2 or classID == 4) and C_Item and C_Item.GetDetailedItemLevelInfo and not HasLine(levelLabel) then
                    local lvl = C_Item.GetDetailedItemLevelInfo(link)
                    if type(lvl) == "number" and lvl > 1 then tip:AddLine(levelLabel .. lvl, 1, 0.82, 0) end
                end
                local price = select(11, ns:GetItemInfo(link))
                local atVendor = type(_G.MerchantFrame) == "table" and _G.MerchantFrame.IsShown and _G.MerchantFrame:IsShown()
                if type(price) == "number" and price > 0 and not atVendor and not HasLine(type(SELL_PRICE) == "string" and SELL_PRICE or "Sell Price") then
                    tip:AddDoubleLine(ns:Tr("Vendor price"), ns:Coins(price), 1, 1, 1, 1, 1, 1)
                end
            end
            if link and ns.db.itemCounts and ns.AddItemCounts and type(link) == "string" then
                ns:AddItemCounts(tip, link)          -- "who has how many", from the storage records
            end
            if link then
                local quality = select(3, ns:GetItemInfo(link))
                local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                if c and quality > 1 then r, g, b = c.r, c.g, c.b end
            end
        end
        Style(tip, r, g, b)
    end

    ns.TooltipOnTip = OnTip
    local safe = ns:Guard("Tooltips", OnTip)
    -- The other tooltips the game has: the side-by-side comparison ones, and the one that opens when
    -- an item link in chat is clicked (with its own comparisons and a close button).
    local extra = 0
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefTooltip", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2",
                            "WorldMapTooltip", "EmbeddedItemTooltip" }) do
        local tip = _G[name]
        if type(tip) == "table" and tip.HookScript and ns:Usable(tip) then
            if pcall(tip.HookScript, tip, "OnShow", ns:Guard("Tooltips", OnShown)) then extra = extra + 1 end
        end
    end
    ns.extraTooltips = extra
    local ref = _G.ItemRefTooltip
    if type(ref) == "table" and ns:Usable(ref) then pcall(ns.AutoSkin, ns, ref) end      -- its close button
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and TooltipDataProcessor.AllTypes then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, safe)
    elseif GameTooltip and GameTooltip.HookScript then
        GameTooltip:HookScript("OnTooltipSetUnit", safe)
        GameTooltip:HookScript("OnTooltipSetItem", safe)
    end
end)


-- Tooltips at the mouse. The game places most tooltips in the bottom-right corner; with this on they
-- follow the pointer instead. (Tooltips that are attached to a particular button, like those on the
-- action bars, are placed by that button and are not affected.) Works with or without our tooltip
-- styling, so it is its own small piece.
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        if type(GameTooltip_SetDefaultAnchor) ~= "function" or not hooksecurefunc then return end
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
            if not (ns.db and ns.db.tooltipCursor) or InCombatLockdown() then return end
            if type(tooltip) ~= "table" or not tooltip.SetOwner then return end
            pcall(tooltip.SetOwner, tooltip, parent or UIParent, "ANCHOR_CURSOR_RIGHT", 16, 8)
        end)
    end)
end
