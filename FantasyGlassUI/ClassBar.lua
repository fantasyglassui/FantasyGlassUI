local _, ns = ...

-- Class extras, under your own frame:
--   * a segmented bar for your class's second resource (holy power, soul shards, chi, arcane charges,
--     essence), and rune cooldowns for death knights. Rogues and druids already have combo points.
--   * your mana, while your main bar is showing something else (a druid in bear or cat form)
--   * a hunter's pet happiness, on the pet frame
-- Which of these your class and this game actually have is checked while playing: a resource that
-- doesn't exist here has a maximum of zero and its bar simply never appears.
ns:NewModule("classBar", function()
    local _, class = UnitClass("player")
    local player = _G.FantasyGlassUI_Player
    local PT = Enum and Enum.PowerType or {}

    local host = CreateFrame("Frame", "FantasyGlassUIClassBar", UIParent)
    host:SetSize(220, 6)
    if type(player) == "table" then
        -- rogues and druids have the combo bar in the first slot under the frame; sit below it
        local drop = (class == "ROGUE" or class == "DRUID") and -14 or -4
        host:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, drop)
        host:SetPoint("TOPRIGHT", player, "BOTTOMRIGHT", 0, drop)
    else
        host:SetPoint("CENTER", UIParent, "CENTER", 0, -200)      -- unit frames are off: stand alone
    end

    local function Bar(height)
        local bar = CreateFrame("StatusBar", nil, host)
        bar:SetStatusBarTexture(ns.BAR or ns.FLAT)
        bar:SetHeight(height)
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetTexture(ns.FLAT)
        ns:Paint(bar.bg, "SetVertexColor", "trough", 0.9)
        ns:AddBorder(bar, 0, 0, 0, 1)
        bar:Hide()
        return bar
    end
    local function Number(fn, ...)                           -- a plain number, or nil (hidden values count as nil)
        if type(fn) ~= "function" then return nil end
        local ok, v = pcall(fn, ...)
        if ok and type(v) == "number" and not ns:IsSecret(v) then return v end
    end

    -- 1. Second resource --------------------------------------------------------------------------------
    local RESOURCE = {
        PALADIN = { PT.HolyPower or 9,      { 0.95, 0.85, 0.35 } },
        WARLOCK = { PT.SoulShards or 7,     { 0.62, 0.42, 0.90 } },
        MONK    = { PT.Chi or 12,           { 0.45, 0.95, 0.75 } },
        MAGE    = { PT.ArcaneCharges or 16, { 0.45, 0.65, 1.00 } },
        EVOKER  = { PT.Essence or 19,       { 0.35, 0.85, 0.80 } },
    }
    local res = RESOURCE[class]
    local pips, ticks, lastMax, lastW
    if res then
        pips = Bar(6)
        pips:SetPoint("TOPLEFT"); pips:SetPoint("TOPRIGHT")
        pips:SetStatusBarColor(res[2][1], res[2][2], res[2][3])
        ticks = {}
    end
    local function UpdatePips()
        if not pips then return false end
        local max = Number(UnitPowerMax, "player", res[1])
        if not max or max < 1 or max > 10 then pips:Hide(); return false end     -- this game has no such resource
        local w = host:GetWidth()
        if type(w) ~= "number" or w <= 0 then w = 220 end
        if max ~= lastMax or w ~= lastW then                 -- (re)draw the dividers: a new maximum, or the frame was resized
            lastMax, lastW = max, w
            pips:SetMinMaxValues(0, max)
            for i = 1, math.max(max - 1, #ticks) do
                local t = ticks[i]
                if not t then
                    t = pips:CreateTexture(nil, "OVERLAY")
                    t:SetTexture(ns.FLAT)
                    t:SetVertexColor(0, 0, 0, 1)
                    t:SetWidth(1)
                    ticks[i] = t
                end
                if i < max then
                    t:ClearAllPoints()
                    t:SetPoint("TOP", pips, "TOPLEFT", w * i / max, 0)
                    t:SetPoint("BOTTOM", pips, "BOTTOMLEFT", w * i / max, 0)
                    t:Show()
                else
                    t:Hide()
                end
            end
        end
        local ok, value = pcall(UnitPower, "player", res[1])
        if ok and value ~= nil then pips:SetValue(value) end  -- raw: a bar accepts a hidden value
        pips:Show()
        return true
    end

    -- 2. Death knight runes: six small bars, each filling as its rune comes back ---------------------
    local runes
    if class == "DEATHKNIGHT" and type(GetRuneCooldown) == "function" then
        runes = {}
        for i = 1, 6 do
            local r = Bar(6)
            r:SetMinMaxValues(0, 1)
            r:SetStatusBarColor(0.55, 0.80, 0.95)
            runes[i] = r
        end
    end
    local function UpdateRunes()
        if not runes then return false end
        local w = host:GetWidth()
        if type(w) ~= "number" or w <= 0 then w = 220 end
        local each = (w - 5 * 3) / 6
        local now = GetTime()
        for i, r in ipairs(runes) do
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", host, "TOPLEFT", (i - 1) * (each + 3), 0)
            r:SetWidth(each)
            local ok, start, duration, ready = pcall(GetRuneCooldown, i)
            local fill = 1
            if ok and ns.Is(ready, false) and type(start) == "number" and type(duration) == "number"
               and not ns:IsSecret(start) and not ns:IsSecret(duration) and duration > 0 then
                fill = math.max(0, math.min(1, (now - start) / duration))
            end
            r:SetValue(fill)
            r:SetAlpha(fill >= 1 and 1 or 0.55)
            r:Show()
        end
        return true
    end

    -- 3. Mana, while the main bar shows rage or energy -------------------------------------------------
    local MANA = PT.Mana or 0
    local mana = Bar(5)
    local mc = (PowerBarColor and PowerBarColor["MANA"]) or { r = 0.25, g = 0.45, b = 1 }
    mana:SetStatusBarColor(mc.r or 0.25, mc.g or 0.45, mc.b or 1)
    local manaOn, pipsOn = false, false
    local function UpdateMana(slotTaken)
        local kind = Number(UnitPowerType, "player")
        local max = Number(UnitPowerMax, "player", MANA)
        manaOn = not (kind == nil or kind == MANA or not max or max <= 0)
        if not manaOn then mana:Hide(); return end
        mana:ClearAllPoints()
        local y = slotTaken and -10 or 0
        mana:SetPoint("TOPLEFT", host, "TOPLEFT", 0, y)
        mana:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, y)
        mana:SetMinMaxValues(0, max)
        local ok, value = pcall(UnitPower, "player", MANA)
        if ok and value ~= nil then mana:SetValue(value) end
        mana:Show()
    end

    -- 4. Pet happiness (hunters) ---------------------------------------------------------------------------
    local petFrame = _G.FantasyGlassUI_Pet
    local mood
    if type(GetPetHappiness) == "function" and type(petFrame) == "table" then
        mood = CreateFrame("Frame", nil, petFrame, ns.template)
        mood:SetSize(12, 12)
        mood:SetPoint("RIGHT", petFrame, "LEFT", -4, 0)
        mood:SetBackdrop(ns.BACKDROP)
        mood:SetBackdropBorderColor(0, 0, 0, 1)
        mood:EnableMouse(true)
        mood:SetScript("OnEnter", function(self)
            if not self.level then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:Tr(self.level == 3 and "Your pet is happy" or self.level == 2 and "Your pet is content" or "Your pet is unhappy"))
            if type(self.damage) == "number" then GameTooltip:AddLine(format(ns:Tr("It deals %d%% of its normal damage."), self.damage), 1, 1, 1) end
            if self.level < 3 then GameTooltip:AddLine(ns:Tr("Feed it to make it happier."), 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        mood:SetScript("OnLeave", function() GameTooltip:Hide() end)
        mood:Hide()
    end
    local function UpdateMood()
        if not mood then return end
        local ok, level, damage = pcall(GetPetHappiness)
        if not ok or type(level) ~= "number" or ns:IsSecret(level) or not UnitExists("pet") then mood:Hide(); return end
        mood.level, mood.damage = level, (type(damage) == "number" and not ns:IsSecret(damage)) and damage or nil
        mood:SetBackdropColor(ns:Signal(level >= 3 and "good" or level == 2 and "warn" or "bad"))
        mood:Show()
    end

    local function Update()
        pipsOn = UpdatePips()
        UpdateMana(pipsOn or UpdateRunes())
    end
    ns.classBarState = function()
        local parts = {}
        if pipsOn then parts[#parts + 1] = "second resource shown" end
        if runes then parts[#parts + 1] = "runes" end
        if manaOn then parts[#parts + 1] = "mana bar shown" end
        if mood then parts[#parts + 1] = "pet happiness available" end
        return #parts > 0 and table.concat(parts, ", ") or "nothing for this class on this game"
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
                         "UPDATE_SHAPESHIFT_FORM", "RUNE_POWER_UPDATE", "UNIT_PET", "UNIT_HAPPINESS" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Class bar", function(_, event, unit)
        if event == "UNIT_PET" or event == "UNIT_HAPPINESS" then UpdateMood() return end
        if unit == nil or ns.Is(unit, "player") then Update() end
    end))
    ns:Every(0.1, "Class bar (runes)", function() if runes then UpdateRunes() end end)
    ns:Every(2, "Class bar (pet)", UpdateMood)
    Update(); UpdateMood()
end)
