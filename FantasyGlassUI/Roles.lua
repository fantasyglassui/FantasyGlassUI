local _, ns = ...

-- Role HUD: a small movable readout whose content depends on the chosen role.
-- Combat values (health, power, threat) can be SECRET on this client: they may be
-- passed straight to a status bar or font string, but never compared or used in math.
-- So every readout here is a bar that accepts the raw value, with number text and
-- alerts added only when the client lets us read the number.
ns:NewModule("roleHUD", function()
    local FONT, th = ns.FONT, ns.theme
    local Secret = function(v) return ns:IsSecret(v) end

    local hud = CreateFrame("Frame", "FantasyGlassUIRoleHUD", UIParent)
    hud:SetSize(210, 96)
    hud:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    hud:SetFrameStrata("MEDIUM")

    local alert = hud:CreateFontString(nil, "OVERLAY")
    ns:Font(alert, 26, true)
    alert:SetPoint("BOTTOM", hud, "TOP", 0, 24)
    alert:SetText("")

    local main = hud:CreateFontString(nil, "OVERLAY")
    ns:Font(main, 22)
    local sub = hud:CreateFontString(nil, "OVERLAY")
    ns:Font(sub, 12)

    local function NewBar(h)
        local bar = CreateFrame("StatusBar", nil, hud)
        bar:SetSize(200, h)
        bar:SetStatusBarTexture(ns.BAR or ns.FLAT)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(ns.FLAT)
        bg:SetVertexColor(0, 0, 0, 0.6)
        ns:AddBorder(bar, 0, 0, 0, 1)
        bar.left = bar:CreateFontString(nil, "OVERLAY")
        ns:Font(bar.left, 10)
        bar.left:SetPoint("LEFT", 4, 0)
        bar.right = bar:CreateFontString(nil, "OVERLAY")
        ns:Font(bar.right, 10)
        bar.right:SetPoint("RIGHT", -4, 0)
        bar:Hide()
        return bar
    end

    local wide = NewBar(12)             -- threat (tank) / mana (healer)
    local rows = {}                     -- healer: one bar per party member
    local healUnits = { "player", "party1", "party2", "party3", "party4" }
    for i = 1, #healUnits do
        rows[i] = NewBar(14)
        rows[i]:SetPoint("TOP", hud, "TOP", 0, -(i - 1) * 17)
    end

    -- State -------------------------------------------------------------------------
    local inCombat, combatStart, lastThreat = false, 0, nil
    local alertUntil, lowManaFlag, durFlag = 0, false, false

    local function ShowAlert(msg, r, g, b, secs)
        alert:SetText(ns:Tr(msg))
        alert:SetTextColor(r, g, b)
        alert:SetAlpha(1)
        alertUntil = GetTime() + (secs or 2)
    end

    local function HasHostileTarget()
        return ns.Yes(UnitExists("target")) and ns.Yes(UnitCanAttack("player", "target")) and not ns.Yes(UnitIsDead("target"))
    end

    -- Health bar fill: accepts secret values as-is
    local function FillHealth(bar, unit)
        pcall(function()
            bar:SetMinMaxValues(0, UnitHealthMax(unit))
            bar:SetValue(UnitHealth(unit))
        end)
    end

    -- Health % text. Returns the number when we may read it, nil otherwise.
    local function SetPct(fs, unit)
        local hp, max = UnitHealth(unit), UnitHealthMax(unit)
        if not Secret(hp) and not Secret(max) then
            if hp and max and max > 0 then
                local pct = floor(hp / max * 100)
                fs:SetText(pct .. "%")
                return pct
            end
            fs:SetText("")
            return nil
        end
        -- hidden in combat: let the client format it for us if it offers a way
        if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            local ok = pcall(function()
                fs:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100))
            end)
            if ok then return nil end
        end
        fs:SetText("")
        return nil
    end

    -- Layout per role ------------------------------------------------------------------
    local function Refresh()
        local role = ns.db.role
        main:ClearAllPoints(); sub:ClearAllPoints(); wide:ClearAllPoints()
        main:SetText(""); sub:SetText("")
        wide:Hide()
        for _, r in ipairs(rows) do r:Hide() end
        if role == "HEALER" then
            wide:SetPoint("TOP", hud, "TOP", 0, -#rows * 17 - 2)
            wide:SetStatusBarColor(0.25, 0.5, 1)
            wide.left:SetText(ns:Tr("Mana"))
            main:SetPoint("TOP", wide, "BOTTOM", 0, -4)
            sub:SetPoint("TOP", main, "BOTTOM", 0, -2)
            hud:SetHeight(#rows * 17 + 18)
        elseif role == "TANK" then
            ns:Font(main, 15)
            main:SetPoint("TOP", hud, "TOP", 0, -2)
            wide:SetPoint("TOP", main, "BOTTOM", 0, -6)
            ns:Paint(wide, "SetStatusBarColor", "@accent")
            wide.left:SetText(ns:Tr("Threat"))
            sub:SetPoint("TOP", wide, "BOTTOM", 0, -5)
            hud:SetHeight(70)
        else
            ns:Font(main, 22)
            main:SetPoint("TOP", hud, "TOP", 0, -2)
            sub:SetPoint("TOP", main, "BOTTOM", 0, -4)
            hud:SetHeight(60)
        end
    end
    ns.RefreshRoleHUD = Refresh

    -- Damage: target health %, execute alert, combat timer --------------------------------
    local function UpdateDamage()
        local line2 = ""
        if HasHostileTarget() then
            local pct = SetPct(main, "target")                -- (the percentage still decides the color and the execute alert)
            if ns.db.healthNumbers and ns.SetHealthText then ns.SetHealthText(main, "target") end
            if pct then
                if pct <= 20 then main:SetTextColor(ns:Signal("bad")); line2 = ns:SignalHex("bad") .. ns:Tr("EXECUTE RANGE") .. "|r   "
                elseif pct <= 35 then main:SetTextColor(1, 0.65, 0)
                else main:SetTextColor(1, 1, 1) end
            else
                main:SetTextColor(1, 1, 1)
            end
        else
            main:SetText("")
        end
        if inCombat then
            local t = floor(GetTime() - combatStart)
            line2 = line2 .. format("|cffd8ccb0%d:%02d|r", floor(t / 60), t % 60)
        end
        sub:SetText(line2)
    end

    -- Tank: threat bar (always), status text + lost-aggro alert when readable ---------------
    local threatWords = { [3] = "SECURE AGGRO", [2] = "INSECURE AGGRO", [1] = "HIGH THREAT - NOT TANKING", [0] = "NO AGGRO" }
    local function ThreatText(status)          -- translated, colored when shown (so the color-blind setting counts)
        local word = threatWords[status]
        if not word then return "" end
        local hex = (status == 3 and ns:SignalHex("good")) or (status == 0 and ns:SignalHex("bad"))
            or (status == 2 and "|cffffd100") or "|cffffa500"
        return hex .. ns:Tr(word) .. "|r"
    end

    local function UpdateTank()
        if not HasHostileTarget() then
            main:SetText(""); sub:SetText(""); wide:Hide()
            return
        end
        wide:Show()
        local status, scaled
        if UnitDetailedThreatSituation then
            local _, st, sc = UnitDetailedThreatSituation("player", "target")
            status, scaled = st, sc
        end

        -- bar + % text take the raw value, secret or not
        pcall(function()
            wide:SetMinMaxValues(0, 100)
            if Secret(scaled) or scaled ~= nil then wide:SetValue(scaled) else wide:SetValue(0) end
        end)
        if Secret(scaled) then
            if not pcall(function() wide.right:SetFormattedText("%.0f%%", scaled) end) then wide.right:SetText("") end
        elseif scaled ~= nil then
            wide.right:SetText(floor(scaled) .. "%")
        else
            wide.right:SetText("")
        end

        if not Secret(status) and status ~= nil then
            main:SetText(ThreatText(status))
            if inCombat then
                if lastThreat == 3 and status < 3 then local r, g, b = ns:Signal("bad"); ShowAlert("LOST AGGRO!", r, g, b, 2.5) end
                lastThreat = status
            end
        else
            main:SetText("")       -- hidden by the client during this fight
        end

        -- who the target is attacking (skipped quietly if the client hides it)
        local ok, text = pcall(function()
            if ns.Yes(UnitExists("targettarget")) and ns.Is(UnitIsUnit("targettarget", "player"), false) then
                return format(ns:Tr("Attacking: %s"), UnitName("targettarget") or "?")
            end
            return ""
        end)
        sub:SetText(ok and text or "")
    end

    -- Healer: party health bars + mana ---------------------------------------------------------
    local function UpdateHealer()
        local grouped = IsInGroup and IsInGroup()
        for i, unit in ipairs(healUnits) do
            local row = rows[i]
            if grouped and UnitExists(unit) then
                FillHealth(row, unit)
                local r, g, b = ns:ClassColor(unit)
                row:SetStatusBarColor(r or 0.2, g or 0.8, b or 0.3)
                row.left:SetText(UnitName(unit) or "")
                if ns.db.healthNumbers and ns.SetHealthText then ns.SetHealthText(row.right, unit) else SetPct(row.right, unit) end
                row:Show()
            else
                row:Hide()
            end
        end

        if UnitPowerType("player") == 0 then
            wide:Show()
            local p, pm = UnitPower("player", 0), UnitPowerMax("player", 0)
            pcall(function() wide:SetMinMaxValues(0, pm); wide:SetValue(p) end)
            if not Secret(p) and not Secret(pm) and p and pm and pm > 0 then
                local pct = floor(p / pm * 100)
                wide.right:SetText(pct .. "%")
                if pct <= 25 and not lowManaFlag then
                    lowManaFlag = true
                    ShowAlert("LOW MANA", 0.3, 0.5, 1, 2.5)
                elseif pct > 40 then
                    lowManaFlag = false
                end
            else
                wide.right:SetText("")
            end
        else
            wide:Hide()
        end
    end

    local function CheckDurability()
        local d = ns:LowestDurability()
        if d < 30 and not durFlag then
            durFlag = true
            ShowAlert("LOW DURABILITY", 1, 0.6, 0.1, 3)
        elseif d >= 40 then
            durFlag = false
        end
    end

    -- Main loop & events ---------------------------------------------------------------------
    local acc = 0
    hud:SetScript("OnUpdate", ns:Guard("Role HUD", function(_, e)
        if alertUntil ~= 0 then
            local left = alertUntil - GetTime()
            if left > 0 then alert:SetAlpha(math.min(1, left / 0.8))
            else alert:SetText(""); alertUntil = 0 end
        end
        acc = acc + e
        if acc < 0.1 then return end
        acc = 0
        if ns.moving then                                    -- arranging the screen: a sample, so the panel can be seen and placed
            if (main:GetText() or "") == "" then main:SetText("72%"); sub:SetText("|cffd8ccb00:42|r") end
            return
        end
        local role = ns.db.role
        if role == "DAMAGE" then UpdateDamage()
        elseif role == "TANK" then UpdateTank()
        elseif role == "HEALER" then UpdateHealer() end
    end))

    hud:RegisterEvent("PLAYER_REGEN_DISABLED")
    hud:RegisterEvent("PLAYER_REGEN_ENABLED")
    hud:RegisterEvent("PLAYER_TARGET_CHANGED")
    hud:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
    hud:RegisterEvent("PLAYER_ENTERING_WORLD")
    hud:SetScript("OnEvent", ns:Guard("Role HUD", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat, combatStart, lastThreat = true, GetTime(), nil
        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat, lastThreat = false, nil
        elseif event == "PLAYER_TARGET_CHANGED" then
            lastThreat = nil
        else
            CheckDurability()
        end
    end))

    Refresh()
    ns:RegisterMovable(hud, "roleHUD", "Role HUD")
end)
