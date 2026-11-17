local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Totem timers: one icon per totem slot with its time sweeping down.
-- The game reports totems separately from buffs, so this can work in combat on clients that hide
-- buffs there. Three cases are handled: values readable (normal), values hidden (the icon and timer
-- are still drawn, and the game decides visibility for us), or the call refused (nothing shown).
-- ns.totemState says which one we met, for /fgui check.
ns:NewModule("totems", function()
    if not GetTotemInfo then ns.totemState = "this client has no totem function"; return end
    local SIZE, GAP = 30, 4
    local MAX = (type(MAX_TOTEMS) == "number" and MAX_TOTEMS > 0 and MAX_TOTEMS <= 8) and MAX_TOTEMS or 4

    local holder = CreateFrame("Frame", "FantasyGlassUITotems", UIParent)
    holder:SetSize(MAX * (SIZE + GAP) - GAP, SIZE)
    holder:SetPoint("CENTER", UIParent, "CENTER", -250, -236)

    local icons = {}
    for slot = 1, MAX do
        local b = CreateFrame("Frame", nil, holder)
        b:SetSize(SIZE, SIZE)
        b:SetPoint("LEFT", holder, "LEFT", (slot - 1) * (SIZE + GAP), 0)       -- each slot keeps its place
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetAllPoints()
        b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if ok and cd then
            cd:SetAllPoints()
            if cd.SetReverse then cd:SetReverse(true) end
            if cd.SetDrawEdge then cd:SetDrawEdge(false) end
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
            b.cd = cd
        end
        ns:AddBorder(b, 0, 0, 0, 1)
        b:EnableMouse(true)
        b:SetScript("OnEnter", function(self)
            if self.sample then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if GameTooltip.SetTotem and pcall(GameTooltip.SetTotem, GameTooltip, slot) then GameTooltip:Show() else GameTooltip:Hide() end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        icons[slot] = b
    end

    -- the border round a slot (two thin lines), shown or not
    local function Box(b, on)
        if b.suiBoxed == on then return end
        b.suiBoxed = on
        local border = b.suiBorder
        if not border then return end
        if on then border:Show() else border:Hide() end
        if border.outer then
            if on then border.outer:Show() else border.outer:Hide() end
        end
    end

    local preview = false
    local function Update()
        if preview then return end
        for slot = 1, MAX do
            local b = icons[slot]
            local ok, have, name, start, duration, icon = pcall(GetTotemInfo, slot)
            if not ok then
                ns.totemState = "refused by the game"
                b:Hide()
            elseif Secret(have) or Secret(duration) then
                -- The game is hiding how long this totem has left, so "is there a totem here?" can't be
                -- answered from the time. ("have" is no help: it says you own the totem, not that one is
                -- standing.) What may still be readable is the totem's icon or name: an empty slot has
                -- neither. An empty slot must never be drawn: it is just a hollow box on the screen.
                local standing                                         -- true, false, or nil when it can't be told
                if not Secret(icon) then standing = (icon ~= nil and icon ~= 0 and icon ~= "")
                elseif not Secret(name) then standing = (type(name) == "string" and name ~= "") end
                if standing == false then
                    ns.totemState = "time hidden; empty slots told apart by their icon"
                    b:Hide()
                else
                    pcall(b.tex.SetTexture, b.tex, icon)
                    if b.cd then pcall(b.cd.SetCooldown, b.cd, start, duration) end
                    b:SetAlpha(1)
                    b:EnableMouse(false)
                    -- Known to be standing: drawn with its box. Not knowable: drawn without one, so that
                    -- if the slot is in fact empty, nothing at all appears.
                    Box(b, standing == true)
                    ns.totemState = (standing == true) and "time hidden; empty slots told apart by their icon"
                        or "everything hidden (icons drawn without boxes, since empty slots can't be told apart)"
                    b:Show()
                end
            else
                if InCombatLockdown() then ns.totemState = "readable in combat"
                elseif ns.totemState == nil then ns.totemState = "readable (not yet seen in combat)" end
                b:EnableMouse(true)
                if have and type(duration) == "number" and duration > 0 then
                    b.tex:SetTexture(icon)
                    if b.cd then pcall(b.cd.SetCooldown, b.cd, start, duration) end
                    b:SetAlpha(1)
                    Box(b, true)
                    b:Show()
                else
                    b:Hide()
                end
            end
        end
    end

    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_TOTEM_UPDATE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Totem timers", Update))
    ns:Every(1, "Totem timers", Update)
    Update()

    ns:RegisterPreview(function(on)
        preview = on
        for slot, b in ipairs(icons) do
            b.sample = on or nil
            if on then
                b.tex:SetTexture(136102)
                if b.cd then pcall(b.cd.SetCooldown, b.cd, GetTime() - slot * 10, 120) end
                b:SetAlpha(1)
                Box(b, true)
                b:Show()
            end
        end
        if not on then Update() end
    end)
    ns.totemTest = { icons = icons, Update = Update, max = MAX }
    ns:RegisterMovable(holder, "totems", "Totem Timers")
end)

-- Weapon imbue reminder (shamans' weapon imbues, rogues' poisons): says so when the main hand has
-- no temporary enchant, or when it is about to run out. Hidden whenever the game won't let us read it.
ns:NewModule("imbueReminder", function()
    local _, class = UnitClass("player")
    if (class ~= "SHAMAN" and class ~= "ROGUE") or not GetWeaponEnchantInfo then return end
    local MAINHAND = 16

    local f = CreateFrame("Frame", "FantasyGlassUIImbue", UIParent, ns.template)
    f:SetSize(190, 30)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -205)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "bg", 0.85)
    f:SetBackdropBorderColor(0.85, 0.25, 0.2, 1)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(24, 24)
    f.icon:SetPoint("LEFT", 3, 0)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.text = ns:NewText(f, 12, "LEFT")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 7, 0)
    f.text:SetPoint("RIGHT", -6, 0)
    f:Hide()

    local preview = false
    local want = false                 -- is there something to say (missing, or about to run out)?
    local function Say(text, r, g, b)
        f.icon:SetTexture((GetInventoryItemTexture and GetInventoryItemTexture("player", MAINHAND)) or 135130)
        f.text:SetText(text)
        f:SetBackdropBorderColor(r, g, b, 1)
        want = true
    end

    -- What we last managed to read. In combat the game may hide the weapon enchant from us, so the
    -- reminder then goes by what it saw before the fight, counting the imbue's remaining time down.
    local seen = { known = false, has = false, expires = nil }

    ns:Every(1, "Imbue reminder", function()
        if preview then return end
        local ok, has, left = pcall(GetWeaponEnchantInfo)
        if ok and not Secret(has) then
            seen.known, seen.has = true, has and true or false
            seen.expires = (has and not Secret(left) and type(left) == "number" and left > 0) and (GetTime() + left / 1000) or nil
        end
        local weapon = GetInventoryItemLink and GetInventoryItemLink("player", MAINHAND)
        local level = UnitLevel("player")
        want = false
        if not seen.known or not weapon or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
           or (class == "ROGUE" and type(level) == "number" and level < 20) then
            return
        end
        local remaining = seen.expires and (seen.expires - GetTime()) or nil
        if not seen.has or (remaining and remaining <= 0) then
            Say(ns:Tr("No weapon imbue"), 0.85, 0.25, 0.2)
        elseif remaining and remaining < 60 then
            Say(format(ns:Tr("Imbue ends in %d s"), math.floor(remaining)), 1, 0.82, 0)
        end
    end)

    -- Fading: out of combat the reminder fades away (unless that option is off); it fades back in when
    -- a fight starts and there is still something to say.
    f:SetAlpha(0)
    ns:Every(0.05, "Imbue reminder", function()
        local target
        if preview or ns.moving then
            target = 1
        elseif want and (not ns.db.imbueCombatOnly or InCombatLockdown()) then
            target = 1
        else
            target = 0
        end
        local cur = f:GetAlpha()
        if type(cur) ~= "number" then cur = target end
        if cur == target and (target == 0) ~= (f:IsShown() and true or false) then return end   -- (settled: nothing to do this tick)
        if math.abs(cur - target) < 0.02 then
            cur = target
        else
            cur = cur + (target - cur) * 0.18
        end
        f:SetAlpha(cur)
        if cur <= 0.01 then
            if f:IsShown() then f:Hide() end
        elseif not f:IsShown() then
            f:Show()
        end
    end)

    ns:RegisterPreview(function(on)
        preview = on
        if on then Say(ns:Tr("No weapon imbue"), 0.85, 0.25, 0.2) else want = false end
    end)
    ns:RegisterMovable(f, "imbue", "Imbue Reminder")
end)
