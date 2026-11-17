local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Nameplate designer (11.0.1): what a nameplate shows and how big, from the Bars and frames tab.
-- Width and height are the game's own nameplate scale (plateW, plateH); the rest is ns.db.plateDesign.
ns.PLATE_DEFAULT = { nameSize = 10, nameShow = true, healthPos = "CENTER", healthSize = 9, castHeight = 8, castTextSize = 8,
                     auraSize = 18, auraMax = 5, auraMine = true, threat = true, highlight = true }
function ns.PlateDesign()
    local d = type(ns.db and ns.db.plateDesign) == "table" and ns.db.plateDesign or {}
    local out = {}
    for k, v in pairs(ns.PLATE_DEFAULT) do
        if d[k] == nil then out[k] = v else out[k] = d[k] end
    end
    local function clamp(k, lo, hi) out[k] = math.max(lo, math.min(hi, tonumber(out[k]) or ns.PLATE_DEFAULT[k])) end
    clamp("nameSize", 6, 18); clamp("healthSize", 6, 18); clamp("castHeight", 4, 20); clamp("castTextSize", 6, 14)
    clamp("auraSize", 10, 32); clamp("auraMax", 0, 8)
    return out
end

ns:NewModule("nameplates", function()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local th = ns.theme
    local extrasOn = ns.db.plateExtras
    local getAura = ns.GetAura

    local function HealthBar(uf)
        return uf.healthBar or uf.healthbar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
    end

    local function Usable(frame)
        return type(frame) == "table" and not (frame.IsForbidden and frame:IsForbidden())
    end
    local function IsTexture(o)
        return type(o) == "table" and o.GetObjectType and o:GetObjectType() == "Texture"
    end

    -- "This is your target": the game marks it with a thick yellow box around the health bar and
    -- another around the level badge (both called selectedBorder). Those are hidden; the game still
    -- shows and hides them, so we read that and turn our own thin rims to the accent color instead.
    local plates = setmetatable({}, { __mode = "k" })        -- unit frame -> was it selected last time we looked
    local function Marks(uf)
        local bar = uf.healthBar or uf.healthbar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
        local badge = uf.PlayerLevelDiffFrame
        return bar, (type(badge) == "table") and badge or nil
    end
    local function ShowSelection(uf)
        local bar, badge = Marks(uf)
        local mark = bar and bar.selectedBorder
        if not IsTexture(mark) then return end
        local badgeMark = badge and badge.selectedBorder
        if mark:GetAlpha() ~= 0 then mark:SetAlpha(0) end
        if IsTexture(badgeMark) and badgeMark:GetAlpha() ~= 0 then badgeMark:SetAlpha(0) end
        local selected = mark:IsShown() and true or false
        if not ns.PlateDesign().highlight then selected = false end
        if plates[uf] == selected then return end
        plates[uf] = selected
        for _, rim in ipairs({ bar.suiBorder, badge and badge.suiBorder }) do
            if selected then ns:Paint(rim, "SetBackdropBorderColor", "@accent", 1)
            else ns:Paint(rim, "SetBackdropBorderColor", "@border", 1) end           -- back to the rim every plate has
        end
    end

    local function Skin(uf)
        if not Usable(uf) then return end
        local bar = HealthBar(uf)
        if bar and not bar.suiSkinned then
            bar.suiSkinned = true
            bar:SetStatusBarTexture(ns.BAR or ns.FLAT)
            ns:Kill(bar.border)
            ns:AddBorder(bar, 0, 0, 0, 1)
        end
        local badge = uf.PlayerLevelDiffFrame                  -- the level badge beside the bar
        if type(badge) == "table" and badge.CreateTexture and not badge.suiBorder then
            ns:AddBorder(badge, 0, 0, 0, 1, 0)                 -- the same rim as the bar, recolored on selection
            if type(badge.playerLevelDiffText) == "table" and badge.playerLevelDiffText.SetFont then ns:Font(badge.playerLevelDiffText, 10) end
        end
        if bar then
            plates[uf] = nil                                   -- a reused plate: look at its selection afresh
            pcall(ShowSelection, uf)
        end
        if uf.name and uf.name.SetFont then
            local pd = ns.PlateDesign()
            ns:Font(uf.name, pd.nameSize)
            uf.name:SetAlpha(pd.nameShow and 1 or 0)
            -- our rim makes the bar a little taller than Blizzard's, which put the name's lower edge
            -- behind it: lift the name by that much, once, keeping whatever anchor the game chose
            if not uf.name.suiLifted then
                uf.name.suiLifted = true
                pcall(function()
                    if uf.name:GetNumPoints() == 1 then
                        local point, rel, relPoint, x, y = uf.name:GetPoint(1)
                        if type(y) == "number" and not ns:IsSecret(y) then
                            uf.name:SetPoint(point, rel, relPoint, x, y + 3)
                        end
                    end
                end)
            end
        end
        if extrasOn then          -- runs on every plate (re)use          -- ours replace Blizzard's cast bar and aura icons on the plate
            local cb = uf.castBar or uf.CastBar
            if type(cb) == "table" then
                if cb.UnregisterAllEvents then cb:UnregisterAllEvents() end
                ns:Kill(cb, true)
            end
            ns:Kill(uf.BuffFrame); ns:Kill(uf.AurasFrame)
        end
    end

    local function Color(frame)
        if not Usable(frame) then return end
        local unit = frame.unit
        if type(unit) ~= "string" or not unit:find("^nameplate") then return end
        local bar = HealthBar(frame)
        if not bar then return end

        local r, g, b = ns:ClassColor(unit)
        if not r and ns.PlateDesign().threat and UnitCanAttack("player", unit) and UnitThreatSituation then
            local s = UnitThreatSituation("player", unit)
            if not ns:IsSecret(s) and s ~= nil then
                if ns.db.role == "TANK" then
                    if s == 3 then r, g, b = ns:Signal("good")
                    elseif s == 2 then r, g, b = ns:Signal("warn")
                    else r, g, b = ns:Signal("bad") end
                elseif s == 3 then r, g, b = ns:Signal("bad")
                elseif s == 2 then r, g, b = ns:Signal("warn") end
            end
        end
        if r then bar:SetStatusBarColor(r, g, b) end
    end

    -- Extras: enemy cast bar + your own debuffs ----------------------------------------------------
    local extras = {}

    local function PlateCast(x)
        local bar, unit = x.cast, x.unit
        if not unit then bar.active = false; bar:Hide(); return end
        local name, _, texture, startMS, endMS, _, _, locked = UnitCastingInfo(unit)
        local channel = false
        if not Secret(name) and name == nil then
            name, _, texture, startMS, endMS, _, locked = UnitChannelInfo(unit)
            channel = true
        end
        if not Secret(name) and name == nil then bar.active = false; bar:Hide(); return end

        pcall(function() bar:SetMinMaxValues(startMS, endMS) end)
        bar.text:SetText(name)
        pcall(bar.icon.SetTexture, bar.icon, texture)
        if channel then bar:SetStatusBarColor(0.35, 0.85, 0.45) else ns:Paint(bar, "SetStatusBarColor", "@accent") end
        -- casts you cannot interrupt are grayed out
        if Secret(locked) then
            if not (bar.lock.SetAlphaFromBoolean and pcall(bar.lock.SetAlphaFromBoolean, bar.lock, locked, 0.8, 0)) then bar.lock:SetAlpha(0) end
        else
            bar.lock:SetAlpha(locked and 0.8 or 0)
        end
        bar.endsAt = (not Secret(endMS) and endMS) and (endMS / 1000) or nil
        bar.active = true
        bar:Show()
    end

    local function AuraIcon(x, i)
        local b = CreateFrame("Frame", nil, x)
        local size = ns.PlateDesign().auraSize
        b:SetSize(size, size)
        b:SetPoint("BOTTOMLEFT", x.auraRow, "BOTTOMLEFT", (i - 1) * (size + 3), 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if ok and cd then
            cd:SetAllPoints()
            if cd.SetReverse then cd:SetReverse(true) end
            if cd.SetDrawEdge then cd:SetDrawEdge(false) end
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
            b.cd = cd
        end
        ns:AddBorder(b, 0, 0, 0, 1)
        x.auras[i] = b
        return b
    end

    local function PlateAuras(x)
        local n = 0
        if getAura and x.unit and not ns.aurasLocked then       -- locked clients keep the game's own nameplate debuffs
            local pd = ns.PlateDesign()
            local most = pd.auraMax
            local filter = (pd.auraMine ~= false) and "HARMFUL|PLAYER" or "HARMFUL"      -- only the debuffs you applied, unless the designer says all
            for i = 1, 20 do
                if n >= most then break end
                local a = getAura(x.unit, i, filter)
                if not a then break end
                if ns.AuraBlocked and ns.AuraBlocked(a.name) then a = nil end
                if a then
                n = n + 1
                local b = x.auras[n] or AuraIcon(x, n)
                pcall(b.icon.SetTexture, b.icon, a.icon)
                if b.cd then
                    local shown = false
                    if b.cd.SetCooldownFromExpirationTime then
                        shown = pcall(b.cd.SetCooldownFromExpirationTime, b.cd, a.expirationTime, a.duration)
                    end
                    if not shown then shown = pcall(function() b.cd:SetCooldown(a.expirationTime - a.duration, a.duration) end) end
                    if shown then b.cd:Show() else b.cd:Hide() end
                end
                b:Show()
                end
            end
        end
        for i = n + 1, #x.auras do x.auras[i]:Hide() end
    end
    function ns:RefreshPlateAuras()
        local n = 0
        for _, x in pairs(extras) do if x.unit then pcall(PlateAuras, x); n = n + 1 end end
        return n
    end

    local function GetExtra(plate, uf)
        local x = extras[plate]
        if x then return x end
        local hb = HealthBar(uf)
        if not hb then return nil end
        x = CreateFrame("Frame", nil, plate)
        x:SetAllPoints(hb)
        x.auras = {}

        local bar = ns:NewStatusBar(x, true)
        bar:SetHeight(ns.PlateDesign().castHeight)
        bar:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -4)
        bar:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", 0, -4)
        bar.lock = bar:CreateTexture(nil, "ARTWORK", nil, 3)
        bar.lock:SetAllPoints()
        bar.lock:SetTexture(ns.FLAT)
        bar.lock:SetVertexColor(0.45, 0.45, 0.5, 1)
        bar.lock:SetAlpha(0)
        bar.icon = bar:CreateTexture(nil, "ARTWORK")
        bar.icon:SetSize(12, 12)
        bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        bar.text = ns:NewText(bar, ns.PlateDesign().castTextSize, "CENTER")
        bar.text:SetPoint("TOP", bar, "BOTTOM", 0, -1)
        bar:Hide()
        bar:SetScript("OnUpdate", ns:Guard("Nameplate casts", function(self)
            if not self.active then return end
            local now = GetTime()
            self:SetValue(now * 1000)
            if self.endsAt and now > self.endsAt + 0.3 then self.active = false; self:Hide() end
        end))
        x.cast = bar

        x.auraRow = CreateFrame("Frame", nil, x)
        x.auraRow:SetSize(105, 18)
        x.auraRow:SetPoint("BOTTOMLEFT", hb, "TOPLEFT", 0, 16)

        x:SetScript("OnEvent", ns:Guard("Nameplate extras", function(self, event)
            if event == "UNIT_AURA" then PlateAuras(self) else PlateCast(self) end
        end))
        extras[plate] = x
        return x
    end

    -- Nameplate size: width and height as a percentage of the game's own (Layout tab). The game sizes
    -- its nameplates through two settings of its own; these sliders set those. They are only touched
    -- once you have moved a slider, and cannot be changed during combat (the change waits).
    local SIZE_CVARS = { w = "NamePlateHorizontalScale", h = "NamePlateVerticalScale" }
    local function HasCVar(name)
        if C_CVar and C_CVar.GetCVar then
            local ok, v = pcall(C_CVar.GetCVar, name)
            return ok and v ~= nil
        end
        if GetCVar then
            local ok, v = pcall(GetCVar, name)
            return ok and v ~= nil
        end
        return false
    end
    ns.plateSizeSupport = (HasCVar(SIZE_CVARS.w) and HasCVar(SIZE_CVARS.h)) and "the game's nameplate scale settings" or nil
    local sizePending = false
    function ns:ApplyNameplateSize()
        if not ns.plateSizeSupport or not ns.db.plateSized then return false end
        if InCombatLockdown() then sizePending = true; return false end
        sizePending = false
        local w = math.max(60, math.min(180, tonumber(ns.db.plateW) or 100)) / 100
        local h = math.max(60, math.min(270, tonumber(ns.db.plateH) or 100)) / 100
        local set = (C_CVar and C_CVar.SetCVar) or SetCVar
        local okW = pcall(set, SIZE_CVARS.w, tostring(w))
        local okH = pcall(set, SIZE_CVARS.h, tostring(h))
        return okW and okH
    end
    function ns:NameplateSizeChanged() ns.db.plateSized = true; return ns:ApplyNameplateSize() end
    do
        local sizer = CreateFrame("Frame")
        sizer:RegisterEvent("PLAYER_REGEN_ENABLED")
        sizer:RegisterEvent("PLAYER_ENTERING_WORLD")
        sizer:SetScript("OnEvent", ns:Guard("Nameplates events", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" or sizePending then pcall(ns.ApplyNameplateSize, ns) end
        end))
    end

    -- Health text on the plate's bar: a percentage, or the amount when "Health as numbers" is on (the
    -- same choice the unit frames follow). It has its own small frame on each plate, so it works
    -- whether or not casts and debuffs on plates are switched on, and on friendly plates too.
    local healthTexts = setmetatable({}, { __mode = "k" })
    local function WriteHealth(h)
        if not h.suiUnit or not ns.db.plateHealth then h.text:SetText(""); return end
        local ok, gone = pcall(function() return UnitIsDeadOrGhost(h.suiUnit) end)
        if ok and ns.Is(gone, true) then h.text:SetText(""); return end
        if ns.SetHealthText then ns.SetHealthText(h.text, h.suiUnit) end
    end
    -- Resource percentage beside the bar, for units that have a resource (most beasts have none). Whether
    -- a unit has one can only be told while its amounts are readable. A plate that first appears in
    -- the middle of a fight, when they are hidden, is left blank: showing "0%" on every creature that
    -- has no mana at all would be worse than showing nothing.
    local function WritePower(h)
        local fs, unit = h.power, h.suiUnit
        if not unit or not ns.db.powerText or not ns.SetPowerPct then fs:SetText(""); return end
        local ok, max = pcall(UnitPowerMax, unit)
        if ok and not ns:IsSecret(max) then
            h.suiHasPower = (type(max) == "number" and max > 0)
        elseif h.suiHasPower == nil then
            -- The maximum is hidden, so it can't be asked directly. What can be told: players always
            -- have a resource, and among creatures it is the spell-casting kinds that carry mana.
            local okP, isPlayer = pcall(UnitIsPlayer, unit)
            local okC, _, class = pcall(UnitClass, unit)
            if okP and ns.Is(isPlayer, true) then
                h.suiHasPower = true
            elseif okC and not ns:IsSecret(class) then
                h.suiHasPower = (class == "MAGE" or class == "PALADIN")
            end
            -- (if the game hides the class as well, nothing is decided: it is asked again next time)
        end
        if not h.suiHasPower then fs:SetText(""); return end
        ns.SetPowerPct(fs, unit)
        fs:SetTextColor(ns:PowerTextColor(unit))
    end

    -- where the health text sits on a plate's bar, and how big
    function ns.PlaceHealthText(h)
        local pd = ns.PlateDesign()
        ns:Font(h.text, pd.healthSize)
        h.text:ClearAllPoints()
        h.text:SetAlpha(pd.healthPos == "OFF" and 0 or 1)
        if pd.healthPos == "LEFT" then h.text:SetPoint("LEFT", h, "LEFT", 3, 0); h.text:SetJustifyH("LEFT")
        elseif pd.healthPos == "RIGHT" then h.text:SetPoint("RIGHT", h, "RIGHT", -3, 0); h.text:SetJustifyH("RIGHT")
        else h.text:SetPoint("CENTER", h, "CENTER", 0, 0); h.text:SetJustifyH("CENTER") end
    end
    local function PlateHealth(plate, uf, unit)
        if not Usable(plate) then return end
        local h = healthTexts[plate]
        if not h then
            local hb = HealthBar(uf)
            if not hb then return end
            h = CreateFrame("Frame", nil, plate)
            h:SetAllPoints(hb)
            h:SetFrameLevel((hb:GetFrameLevel() or 1) + 4)
            h.text = ns:NewText(h, 9, "CENTER")
            h.text:SetPoint("CENTER", h, "CENTER", 0, 0)
            h.suiPlaced = nil
            h.text:SetTextColor(1, 1, 1)
            if h.text.SetShadowOffset then h.text:SetShadowOffset(1, -1); h.text:SetShadowColor(0, 0, 0, 1) end
            h.power = ns:NewText(h, 8, "LEFT")               -- just outside the bar's right end
            h.power:SetPoint("LEFT", h, "RIGHT", 3, 0)
            if h.power.SetShadowOffset then h.power:SetShadowOffset(1, -1); h.power:SetShadowColor(0, 0, 0, 1) end
            h:SetScript("OnEvent", ns:Guard("Nameplate health", function(self, event)
                if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then WriteHealth(self) else WritePower(self) end
            end))
            healthTexts[plate] = h
        end
        if not h.suiPlaced then ns.PlaceHealthText(h); h.suiPlaced = true end
        h:UnregisterAllEvents()
        h.suiUnit = unit
        h.suiHasPower = nil                                  -- a plate is reused for different units: learn afresh
        if unit then
            for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
                pcall(h.RegisterUnitEvent, h, e, unit)
            end
            h:Show()
        else
            h:Hide()
        end
        WriteHealth(h)
        WritePower(h)
        return h
    end
    ns.PlateHealth = PlateHealth
    function ns:RefreshPlateHealth()                        -- the option changed: rewrite every plate showing
        for _, h in pairs(healthTexts) do pcall(WriteHealth, h); pcall(WritePower, h) end
    end
    -- the designer's changes, on every plate there is (new plates take them as they are made)
    function ns:ApplyPlateDesign()
        local pd = ns.PlateDesign()
        local n = 0
        for _, h in pairs(healthTexts) do ns.PlaceHealthText(h); n = n + 1 end
        for _, x in pairs(extras) do
            x.cast:SetHeight(pd.castHeight)
            ns:Font(x.cast.text, pd.castTextSize)
            for i, b in ipairs(x.auras) do
                b:SetSize(pd.auraSize, pd.auraSize)
                b:ClearAllPoints()
                b:SetPoint("BOTTOMLEFT", x.auraRow, "BOTTOMLEFT", (i - 1) * (pd.auraSize + 3), 0)
                if i > pd.auraMax then b:Hide() end
            end
        end
        for uf in pairs(plates) do
            if Usable(uf) and uf.name and uf.name.SetFont then
                ns:Font(uf.name, pd.nameSize)
                uf.name:SetAlpha(pd.nameShow and 1 or 0)
            end
            plates[uf] = nil                                 -- (selection looked at afresh)
        end
        ns.plateDesignApplied = n
        return n
    end

    local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                          "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
                          "UNIT_SPELLCAST_CHANNEL_UPDATE" }

    local function Attach(plate, uf, unit)
        if not Usable(plate) then return end
        local x = GetExtra(plate, uf)
        if not x then return end
        x:UnregisterAllEvents()
        if UnitCanAttack("player", unit) then
            x.unit = unit
            for _, e in ipairs(CAST_EVENTS) do pcall(x.RegisterUnitEvent, x, e, unit) end
            pcall(x.RegisterUnitEvent, x, "UNIT_AURA", unit)
            x:Show()
            PlateCast(x)
            PlateAuras(x)
        else
            x.unit = nil
            x:Hide()
        end
    end

    local function Detach(plate)
        local x = plate and extras[plate]
        if not x then return end
        x:UnregisterAllEvents()
        x.unit = nil
        x.cast.active = false
        x.cast:Hide()
        for _, b in ipairs(x.auras) do b:Hide() end
    end

    if CompactUnitFrame_UpdateHealthColor then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ns:Guard("Nameplates", Color))
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    f:SetScript("OnEvent", ns:Guard("Nameplates", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            local uf = plate and plate.UnitFrame
            if uf then
                Skin(uf); Color(uf)
                if extrasOn then Attach(plate, uf, unit) end
                PlateHealth(plate, uf, unit)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            Detach(plate)
            if plate and healthTexts[plate] then PlateHealth(plate, plate.UnitFrame, nil) end
        elseif C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                if plate.UnitFrame then Color(plate.UnitFrame) end
            end
        end
    end))
    -- which plate is your target: at once when you change target, and three times a second as well
    -- (for the moments the game moves a plate to another unit without saying so)
    local function Selection()
        for uf in pairs(plates) do
            if Usable(uf) and uf.IsVisible and uf:IsVisible() then pcall(ShowSelection, uf) end
        end
    end
    local sel = CreateFrame("Frame")
    sel:RegisterEvent("PLAYER_TARGET_CHANGED")
    sel:SetScript("OnEvent", ns:Guard("Nameplates events", function() Selection() end))
    ns:Every(0.3, "Nameplate selection", function()
        for uf in pairs(plates) do
            if Usable(uf) and uf.IsVisible and uf:IsVisible() then pcall(ShowSelection, uf) end
        end
    end)
end)
