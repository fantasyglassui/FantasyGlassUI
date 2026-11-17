local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Our own buff and debuff rows. Blizzard's are made invisible (not hooked).
-- Temporary weapon enchants (poisons, sharpening stones, shaman imbues) lead the buff row.
ns:NewModule("auraBars", function()
    if ns.aurasLocked then return end      -- this client hides auras from add-ons in combat: see Frames.lua
    local get = ns.GetAura
    if not get then
        ns:Print("Buff bars: this client lacks C_UnitAuras, keeping Blizzard's buffs.")
        return
    end
    local th = ns.theme

    -- main hand / off hand / ranged enchants that are active right now
    local function Enchants()
        local list = {}
        if not GetWeaponEnchantInfo then return list end
        local ok, mh, mhTime, mhCharges, _, oh, ohTime, ohCharges, _, rh, rhTime, rhCharges = pcall(GetWeaponEnchantInfo)
        if not ok then return list end
        if mh then list[#list + 1] = { inv = 16, index = 1, left = mhTime, charges = mhCharges } end
        if oh then list[#list + 1] = { inv = 17, index = 2, left = ohTime, charges = ohCharges } end
        if rh then list[#list + 1] = { inv = 18, index = 3, left = rhTime, charges = rhCharges } end
        return list
    end

    local function TimeText(ms)
        if Secret(ms) or type(ms) ~= "number" then return "" end
        local s = ms / 1000
        if s >= 3600 then return format("%dh", math.floor(s / 3600 + 0.5)) end
        if s >= 60 then return format("%dm", math.floor(s / 60 + 0.5)) end
        return format("%ds", math.floor(s))
    end

    local function NewRow(key, label, size, perRow, max, filter, x, y)
        local holder = CreateFrame("Frame", "FantasyGlassUI" .. key, UIParent)
        holder:SetSize(perRow * (size + 4), size + 4)
        holder:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
        holder.buttons = {}

        local function Button(i)
            local b = CreateFrame("Button", nil, holder)
            b:SetSize(size, size)
            local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
            b:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -col * (size + 4), -row * (size + 6))
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
            if ok and cd then
                cd:SetAllPoints()
                if cd.SetReverse then cd:SetReverse(true) end
                if cd.SetDrawEdge then cd:SetDrawEdge(false) end
                if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end   -- the client draws the time left
                b.cd = cd
            end
            local layer = CreateFrame("Frame", nil, b)
            layer:SetAllPoints()
            layer:SetFrameLevel(b:GetFrameLevel() + 5)
            b.count = ns:NewText(layer, 11, "RIGHT")
            b.count:SetPoint("BOTTOMRIGHT", 1, 0)
            b.kind = ns:NewText(layer, 10, "LEFT")            -- color-blind aid: M / C / P / D
            b.kind:SetPoint("TOPLEFT", 1, -1)
            b.time = ns:NewText(layer, 10, "CENTER")          -- weapon enchants only: we know their time left directly
            b.time:SetPoint("TOP", b, "BOTTOM", 0, -1)
            ns:AddBorder(b, 0, 0, 0, 1)
            b:RegisterForClicks("RightButtonUp")
            b:SetScript("OnClick", function(self)
                if InCombatLockdown() then return end
                if self.enchant then
                    if CancelItemTempEnchantment then pcall(CancelItemTempEnchantment, self.enchant.index) end
                elseif filter == "HELPFUL" and CancelUnitBuff then
                    pcall(CancelUnitBuff, "player", self.index, "HELPFUL")
                end
            end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
                local ok
                if self.enchant then
                    ok = pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", self.enchant.inv)
                else
                    ok = pcall(GameTooltip.SetUnitAura, GameTooltip, "player", self.index, filter)
                end
                if ok then GameTooltip:Show() else GameTooltip:Hide() end
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            holder.buttons[i] = b
            return b
        end

        function holder.Update()
            local n = 0
            if filter == "HELPFUL" then
                for _, e in ipairs(Enchants()) do
                    n = n + 1
                    local b = holder.buttons[n] or Button(n)
                    b.enchant, b.index = e, nil
                    b.kind:SetText("")
                    b.icon:SetTexture(GetInventoryItemTexture and GetInventoryItemTexture("player", e.inv) or nil)
                    if b.cd then b.cd:Hide() end
                    b.time:SetText(TimeText(e.left))
                    local c = e.charges
                    if not Secret(c) and type(c) == "number" and c > 1 then b.count:SetText(c) else b.count:SetText("") end
                    b.suiBorder:SetBackdropBorderColor(0.64, 0.36, 0.95, 1)        -- purple: a weapon enchant
                    b:Show()
                end
            end
            for i = 1, max do
                local a = get("player", i, filter)
                if not a then break end
                if not (filter ~= "HARMFUL" and ns.AuraHidden and ns:AuraHidden(a)) then      -- (a buff you chose never to see)
                n = n + 1
                local b = holder.buttons[n] or Button(n)
                b.enchant, b.index = nil, i
                b.time:SetText("")
                pcall(b.icon.SetTexture, b.icon, a.icon)
                if b.cd then
                    local shown = false
                    if b.cd.SetCooldownFromExpirationTime then
                        shown = pcall(b.cd.SetCooldownFromExpirationTime, b.cd, a.expirationTime, a.duration)
                    end
                    if not shown then
                        shown = pcall(function() b.cd:SetCooldown(a.expirationTime - a.duration, a.duration) end)
                    end
                    if shown then b.cd:Show() else b.cd:Hide() end
                end
                local apps = a.applications
                if not Secret(apps) and apps and apps > 1 then b.count:SetText(apps) else b.count:SetText("") end
                b.kind:SetText((filter == "HARMFUL" and ns.db.colorblind) and ns:DispelLetter(a.dispelName) or "")
                if filter == "HARMFUL" then
                    b.suiBorder:SetBackdropBorderColor(0.85, 0.18, 0.18, 1)
                else
                    ns:Paint(b.suiBorder, "SetBackdropBorderColor", "@border", 1)
                end
                b:Show()
                end
            end
            for i = n + 1, #holder.buttons do holder.buttons[i]:Hide() end
        end

        ns:RegisterMovable(holder, key, label)
        return holder
    end

    local buffs = NewRow("Buffs", "Buffs", 30, 12, 36, "HELPFUL", -218, -14)
    local debuffs = NewRow("Debuffs", "Debuffs", 36, 8, 16, "HARMFUL", -218, -130)

    local ev = CreateFrame("Frame")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_INVENTORY_CHANGED", "player")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    local refresh = ns:Guard("Buff bars", function()
        buffs.Update()
        debuffs.Update()
    end)
    ev:SetScript("OnEvent", refresh)
    -- weapon enchants tick down with no event of their own: refresh the buff row once a second
    local acc = 0
    ev:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 1 then return end
        acc = 0
        refresh()
    end)
    refresh()

    ns:Silence(_G.BuffFrame)
    ns:Silence(_G.DebuffFrame)
end)
