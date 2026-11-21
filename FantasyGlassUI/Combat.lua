local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Spell lookups that work on both the newer and the older spell functions.
local function SpellInfo(name)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        if ok and type(info) == "table" then return info.spellID, info.iconID end
    elseif GetSpellInfo then
        local ok, _, _, icon, _, _, _, id = pcall(GetSpellInfo, name)
        if ok then return id, icon end
    end
end

local function Icon(parent, size)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints()
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end      -- the game draws the seconds
        b.cd = cd
    end
    ns:AddBorder(b, 0, 0, 0, 1)
    return b
end

------------------------------------------------------------------------------------------
-- Cooldown tracker: a row of the abilities you chose, each with its cooldown sweeping over it.
------------------------------------------------------------------------------------------
ns:NewModule("cooldowns", function()
    local SIZE, GAP, MAX = 34, 4, 10
    local holder = CreateFrame("Frame", "FantasyGlassUICooldowns", UIParent)
    holder:SetSize(MAX * (SIZE + GAP), SIZE)
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, -250)
    local icons, active = {}, {}

    -- What an ability is doing right now. Returns: state, start, duration
    --   "ready"    nothing to wait for (this includes "only the global cooldown", which every ability
    --              shares for a second and a half and which is not what this row is for)
    --   "cooling"  on its own cooldown: the icon is grayed and the sweep runs
    --   "hidden"   the game is hiding the numbers (in combat on some clients). The sweep can still be
    --              handed to the game to draw, but whether to gray the icon cannot be known, so it isn't.
    local GCD = 61304                                        -- the game's stand-in spell for the global cooldown
    local function Read(id)
        if C_Spell and C_Spell.GetSpellCooldown then
            local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
            if ok and type(cd) == "table" then return cd.startTime, cd.duration, cd.isEnabled, cd.isOnGCD end
        elseif GetSpellCooldown then
            local ok, start, duration, enabled = pcall(GetSpellCooldown, id)
            if ok then return start, duration, enabled end
        end
    end
    local function State(id)
        local start, duration, enabled, onGCD = Read(id)
        if Secret(start) or Secret(duration) then return "hidden", start, duration, onGCD end
        -- an ability with charges: usable while any charge is left, however the recharge is going
        if C_Spell and C_Spell.GetSpellCharges then
            local ok, ch = pcall(C_Spell.GetSpellCharges, id)
            if ok and type(ch) == "table" and type(ch.maxCharges) == "number" and not Secret(ch.maxCharges) and ch.maxCharges > 1
               and type(ch.currentCharges) == "number" and not Secret(ch.currentCharges) then
                local cs, cdur = ch.cooldownStartTime, ch.cooldownDuration
                if Secret(cs) or Secret(cdur) then return "hidden", cs, cdur end
                if ch.currentCharges > 0 or type(cdur) ~= "number" or cdur <= 0 then return "ready", 0, 0 end
                return "cooling", cs, cdur
            end
        end
        if type(start) ~= "number" or type(duration) ~= "number" or duration <= 0 then return "ready", 0, 0 end
        if ns.Is(enabled, false) or ns.Is(enabled, 0) then return "ready", 0, 0 end         -- its cooldown has not started counting
        if ns.Is(onGCD, true) then return "ready", 0, 0 end
        local gs, gd = Read(GCD)                                                  -- the same clock as the global cooldown?
        if type(gs) == "number" and type(gd) == "number" and not Secret(gs) and not Secret(gd) and gd > 0
           and math.abs(gs - start) < 0.05 and math.abs(gd - duration) < 0.05 then
            return "ready", 0, 0
        end
        if duration <= 1.6 then return "ready", 0, 0 end                          -- (no stand-in spell to compare with)
        if start + duration <= GetTime() then return "ready", 0, 0 end            -- it has already finished
        return "cooling", start, duration
    end

    local hiddenSeen = false
    local function Refresh()
        for _, b in ipairs(active) do
            local state, start, duration, onGCD = State(b.spellID)
            -- The pulse: an ability coming off its own cooldown (not the shared one every ability has).
            -- Where the game shows the times, that moment is seen here. Where it hides them, the sweep
            -- itself tells us when it ends - if the game at least says it is not the shared cooldown.
            if state == "ready" and b.suiArmed then
                b.suiArmed = nil
                if ns.CooldownPulse then ns:CooldownPulse(b.tex:GetTexture()) end
            elseif state == "cooling" then
                b.suiArmed = true
            elseif state == "hidden" then
                if ns.Is(onGCD, false) then b.suiArmed = true elseif not b.suiArmed then b.suiArmed = nil end
            end
            if b.cd and not b.suiPulseHooked and b.cd.HookScript then
                b.suiPulseHooked = true
                pcall(b.cd.HookScript, b.cd, "OnCooldownDone", function()
                    if not b.suiArmed then return end
                    b.suiArmed = nil
                    if ns.CooldownPulse then ns:CooldownPulse(b.tex:GetTexture()) end
                end)
            end
            if b.tex.SetDesaturated then b.tex:SetDesaturated(state == "cooling") end
            if b.cd then
                if state == "ready" then
                    if b.cd.Clear then b.cd:Clear() else pcall(b.cd.SetCooldown, b.cd, 0, 0) end
                else
                    b.cd:Show()                              -- (never left hidden: one refusal must not end the sweeps for good)
                    local drawn = pcall(b.cd.SetCooldown, b.cd, start, duration)
                    if not drawn and state == "hidden" and C_Spell and C_Spell.GetSpellCooldownDuration and b.cd.SetCooldownFromDurationObject then
                        pcall(function() b.cd:SetCooldownFromDurationObject(C_Spell.GetSpellCooldownDuration(b.spellID)) end)
                    end
                end
            end
            b.state = state
            if state == "hidden" then hiddenSeen = true end
        end
    end
    function ns:CooldownTrackerState()
        if #active == 0 then return "no abilities chosen (Combat › Cooldowns)" end
        return #active .. " abilities" .. (hiddenSeen and "; in combat the game hides their cooldowns, so sweeps are drawn but icons are not grayed" or "")
    end
    ns.cooldownTest = { Refresh = Refresh, active = function() return active end }

    -- (Re)build the row from the saved list. Unknown spells are skipped quietly.
    function ns:RebuildCooldowns()
        active = {}
        local n = 0
        for _, name in ipairs(type(ns.db.cooldownSpells) == "table" and ns.db.cooldownSpells or {}) do
            if n >= MAX then break end
            local id, icon = SpellInfo(name)
            if id then
                n = n + 1
                local b = icons[n] or Icon(holder, SIZE)
                icons[n] = b
                b.spellID = id
                b.tex:SetTexture(icon)
                b:Show()
                active[n] = b
            end
        end
        for i = n + 1, #icons do icons[i]:Hide() end
        local width = n * (SIZE + GAP) - GAP                       -- keep the row centered on its anchor
        for i, b in ipairs(active) do
            b:ClearAllPoints()
            b:SetPoint("LEFT", holder, "CENTER", -width / 2 + (i - 1) * (SIZE + GAP), 0)
        end
        Refresh()
        return n
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Cooldown tracker", function(_, event)
        if event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then ns:RebuildCooldowns() else Refresh() end
    end))
    ns:RebuildCooldowns()
    -- The game says when a cooldown starts, but not when one finishes. So the row is also looked at a
    -- few times a second; otherwise an icon stays gray until something else happens to prompt a look.
    -- (11.14.1: only while one is counting down; a row that is all ready waits for the game's events)
    ns:Every(0.2, "Cooldown tracker", function()
        for _, b in ipairs(active) do
            if b.state ~= "ready" then Refresh() return end
        end
    end)
    ns:RegisterMovable(holder, "cooldowns", "Cooldown tracker")
end)

------------------------------------------------------------------------------------------
-- Buff alerts: when one of the buffs you listed is on you, its icon pops up near the middle of the screen.
------------------------------------------------------------------------------------------
ns:NewModule("buffAlerts", function()
    if ns.aurasLocked then return end       -- buffs can't be read in combat on this client: nothing to alert on
    local SIZE, GAP, MAX = 44, 6, 6
    local holder = CreateFrame("Frame", "FantasyGlassUIAlerts", UIParent)
    holder:SetSize(MAX * (SIZE + GAP), SIZE)
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, 110)
    local icons = {}

    local function FindBuff(name)
        if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
            local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
            if ok and type(aura) == "table" then return aura end
            return nil
        end
        local get = ns.GetAura
        if not get then return nil end
        for i = 1, 40 do
            local aura = get("player", i, "HELPFUL")
            if not aura then return nil end
            if not Secret(aura.name) and aura.name == name then return aura end
        end
    end

    local function Refresh()
        local shown = {}
        for _, name in ipairs(type(ns.db.alertBuffs) == "table" and ns.db.alertBuffs or {}) do
            if #shown >= MAX then break end
            local aura = FindBuff(name)
            if aura then shown[#shown + 1] = { name = name, aura = aura } end
        end
        local width = #shown * (SIZE + GAP) - GAP
        for i, s in ipairs(shown) do
            local b = icons[i]
            if not b then
                b = Icon(holder, SIZE)
                ns:Paint(b.suiBorder, "SetBackdropBorderColor", "@accent", 1)     -- (follows a change of theme)
                -- a quick "pop" when the buff first appears
                local group = b:CreateAnimationGroup()
                local grow = group:CreateAnimation("Scale")
                if grow.SetScaleFrom then grow:SetScaleFrom(1.5, 1.5); grow:SetScaleTo(1, 1) end
                grow:SetDuration(0.22)
                if grow.SetSmoothing then grow:SetSmoothing("OUT") end
                b.pop = group
                icons[i] = b
            end
            pcall(b.tex.SetTexture, b.tex, s.aura.icon)
            if b.cd then
                if b.cd.SetReverse then b.cd:SetReverse(true) end      -- a buff: full color, darkening as it runs out
                local ok = false
                if b.cd.SetCooldownFromExpirationTime then
                    ok = pcall(b.cd.SetCooldownFromExpirationTime, b.cd, s.aura.expirationTime, s.aura.duration)
                end
                if not ok then ok = pcall(function() b.cd:SetCooldown(s.aura.expirationTime - s.aura.duration, s.aura.duration) end) end
                if ok then b.cd:Show() else b.cd:Hide() end
            end
            b:ClearAllPoints()
            b:SetPoint("LEFT", holder, "CENTER", -width / 2 + (i - 1) * (SIZE + GAP), 0)
            if b.buff ~= s.name or not b:IsShown() then            -- newly up: pop
                b.buff = s.name
                b:Show()
                if ns.db.fades and ns:Motion() then b.pop:Stop(); b.pop:Play() end
            end
        end
        for i = #shown + 1, #icons do icons[i]:Hide(); icons[i].buff = nil end
    end
    ns.RefreshAlerts = Refresh
    ns:OnAurasBack(Refresh)

    local ev = CreateFrame("Frame")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Buff alerts", Refresh))
    Refresh()
    ns:RegisterMovable(holder, "alerts", "Buff alerts")
end)

------------------------------------------------------------------------------------------
-- The cooldown pulse: when an ability on the cooldown tracker comes off cooldown, its icon appears in
-- the middle of the screen for a moment, swelling and fading. Place it in move mode.
------------------------------------------------------------------------------------------
ns.PULSE_TIME = 0.7
ns:NewModule("cooldownPulse", function()
    local holder = CreateFrame("Frame", "FantasyGlassUICooldownPulse", UIParent)
    holder:SetSize(64, 64)
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, 90)
    holder:SetFrameStrata("HIGH")
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns:AddBorder(holder, 0, 0, 0, 1)
    holder:SetAlpha(0)
    local left, count = 0, 0
    function ns:CooldownPulse(texture)
        if not ns.db.cooldownPulse then return false end
        pcall(icon.SetTexture, icon, texture)
        left = ns.PULSE_TIME
        count = count + 1
        ns.pulseCount = count
        holder:SetAlpha(1)
        return true
    end
    holder:SetScript("OnUpdate", function(self, elapsed)
        if ns.moving then                                   -- arranging the screen: shown, so it can be placed
            if not self.suiSample then self.suiSample = true; pcall(icon.SetTexture, icon, "Interface\\Icons\\INV_Misc_QuestionMark"); self:SetAlpha(1) end
            return
        elseif self.suiSample then
            self.suiSample = nil
            self:SetAlpha(left > 0 and 1 or 0)
        end
        if left <= 0 then return end
        left = left - (tonumber(elapsed) or 0)
        if left <= 0 then self:SetAlpha(0); icon:SetAllPoints(); return end
        if ns:Motion() then
            local p = 1 - left / ns.PULSE_TIME                -- 0 at the start, 1 at the end
            local grow = 12 * p
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", -grow, grow)
            icon:SetPoint("BOTTOMRIGHT", grow, -grow)
            self:SetAlpha(1 - p * p)
        end
    end)
    ns:RegisterMovable(holder, "cooldownPulse", "Cooldown pulse")
    ns.pulseTest = { holder = holder, icon = icon }
end)
