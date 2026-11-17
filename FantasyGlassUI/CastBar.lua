local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Our own player cast bar. Replaces Blizzard's (which is silenced, not hooked).
ns:NewModule("playerCast", function()
    local th = ns.theme
    local H = 20

    local bar = ns:NewStatusBar(UIParent, true)
    bar:SetSize(260, H)
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 11, 210)
    bar:SetFrameStrata("MEDIUM")
    bar:Hide()

    local iconBox = CreateFrame("Frame", nil, bar)
    iconBox:SetSize(H, H)
    iconBox:SetPoint("RIGHT", bar, "LEFT", -3, 0)
    ns:AddBorder(iconBox, 0, 0, 0, 1)
    local icon = iconBox:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- bright edge that rides the end of the fill (anchored to the fill, so it works with hidden values)
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(ns.FLAT)
    spark:SetVertexColor(1, 1, 1, 0.9)
    spark:SetSize(2, H)
    spark:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)

    local name = ns:NewText(bar, 12, "LEFT")
    name:SetPoint("LEFT", 6, 0)
    local timer = ns:NewText(bar, 12, "RIGHT")
    timer:SetPoint("RIGHT", -6, 0)
    name:SetPoint("RIGHT", timer, "LEFT", -6, 0)

    -- State ---------------------------------------------------------------------------
    local active, channel, raw = false, false, false
    local startS, endS = nil, nil
    local holdUntil, fadeStart = nil, nil

    local function Begin(isChannel)
        local spell, _, texture, startMS, endMS, isTradeSkill, spellID
        if isChannel then spell, _, texture, startMS, endMS = UnitChannelInfo("player")
        else spell, _, texture, startMS, endMS, isTradeSkill, _, _, spellID = UnitCastingInfo("player") end
        if not Secret(spell) and spell == nil then return false end
        -- crafting: the profession's icon (the game gives crafts a placeholder picture)
        if not isChannel and ns.CraftIcon then texture = ns:CraftIcon(isTradeSkill, texture, spellID) end

        channel = isChannel
        if Secret(startMS) or Secret(endMS) or not startMS or not endMS then
            -- hidden times: give the bar the raw range and feed it the clock
            raw = true
            startS, endS = nil, nil
            pcall(function() bar:SetMinMaxValues(startMS, endMS) end)
        else
            raw = false
            startS, endS = startMS / 1000, endMS / 1000
            bar:SetMinMaxValues(0, math.max(endS - startS, 0.01))
        end
        name:SetText(spell)
        pcall(icon.SetTexture, icon, texture)
        if isChannel then bar:SetStatusBarColor(0.35, 0.85, 0.45)
        else ns:Paint(bar, "SetStatusBarColor", "@accent") end
        spark:Show()
        active, holdUntil, fadeStart = true, nil, nil
        bar:SetAlpha(1)
        bar:Show()
        return true
    end

    local function Finish()
        active = false
        spark:Hide()
        fadeStart = GetTime()
    end

    local function Interrupted()
        active = false
        spark:Hide()
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(1)
        bar:SetStatusBarColor(0.9, 0.2, 0.2)
        name:SetText(ns:Tr("Interrupted"))
        timer:SetText("")
        bar:SetAlpha(1)
        holdUntil, fadeStart = GetTime() + 0.7, nil
    end

    local preview = false
    bar:SetScript("OnUpdate", ns:Guard("Cast bar", function(self)
        local now = GetTime()
        if preview then                               -- looping sample cast
            local t = now % 2.5
            self:SetValue(t)
            timer:SetFormattedText("%.1f", 2.5 - t)
            return
        end
        if active and ns.craftCovering then               -- the crafting bar in the profession window is showing this one
            active = false
            self:Hide()
            return
        end
        if active then
            if raw then
                self:SetValue(now * 1000)
                timer:SetText("")
            else
                local left = endS - now
                if channel then self:SetValue(math.max(left, 0)) else self:SetValue(now - startS) end
                timer:SetFormattedText("%.1f", math.max(left, 0))
                if left < -0.3 then Finish() end      -- safety net if the stop event never arrives
            end
        elseif holdUntil then
            if now >= holdUntil then holdUntil, fadeStart = nil, now end
        elseif fadeStart then
            local a = 1 - (now - fadeStart) / 0.3
            if a <= 0 then fadeStart = nil; self:Hide() else self:SetAlpha(a) end
        else
            self:Hide()
        end
    end))

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                         "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
                         "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
        pcall(ev.RegisterUnitEvent, ev, e, "player")
    end
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Cast bar", function(_, event)
        if event == "UNIT_SPELLCAST_INTERRUPTED" then
            if active then Interrupted() end
            return
        end
        -- any other event: ask the game what we are casting right now
        if Begin(false) or Begin(true) then return end
        if active then Finish() end
    end))

    -- Silence Blizzard's player cast bar
    local blizz = _G.PlayerCastingBarFrame or _G.CastingBarFrame
    if type(blizz) == "table" then
        local function Quiet() if blizz.UnregisterAllEvents then blizz:UnregisterAllEvents() end end
        Quiet()
        ns:Kill(blizz, true)
        local q = CreateFrame("Frame")
        q:RegisterEvent("PLAYER_ENTERING_WORLD")
        pcall(q.RegisterUnitEvent, q, "UNIT_ENTERED_VEHICLE", "player")
        pcall(q.RegisterUnitEvent, q, "UNIT_EXITED_VEHICLE", "player")
        q:SetScript("OnEvent", ns:Guard("CastBar events", function() ns:After(0.1, Quiet) end))
    end

    ns:RegisterMovable(bar, "playerCast", "Cast Bar")
    ns.castBarFrame = bar

    ns:RegisterPreview(function(on)
        preview = on
        active, holdUntil, fadeStart = false, nil, nil
        if on then
            bar:SetMinMaxValues(0, 2.5)
            ns:Paint(bar, "SetStatusBarColor", "@accent")
            name:SetText(ns:Tr("Sample Spell"))
            icon:SetTexture(136243)
            spark:Show()
            bar:SetAlpha(1)
            bar:Show()
        else
            bar:Hide()
        end
    end)
end)
