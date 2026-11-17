local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Swing timers for main hand, off hand and ranged.
-- This client has no combat log; it announces each swing itself with PLAYER_SWING(duration, type).
ns:NewModule("swingTimer", function()
    local ev = CreateFrame("Frame")
    if not pcall(ev.RegisterEvent, ev, "PLAYER_SWING") then
        ns:Print("Swing timers: this client has no PLAYER_SWING event, so they are off.")
        return
    end

    local th = ns.theme
    local W, H, GAP = 200, 8, 3
    local holder = CreateFrame("Frame", "FantasyGlassUISwing", UIParent)
    holder:SetSize(W, H * 3 + GAP * 2)
    holder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 170)

    local defs = {
        { "MH", th.accent[1], th.accent[2], th.accent[3] },
        { "OH", th.accent[1] * 0.6 + 0.4, th.accent[2] * 0.6 + 0.4, th.accent[3] * 0.6 + 0.4 },
        { "RNG", 1.0, 0.70, 0.20 },
    }
    local bars = {}
    for i, d in ipairs(defs) do
        local b = ns:NewStatusBar(holder, true)
        b:SetSize(W, H)
        b:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * (H + GAP))
        b:SetStatusBarColor(d[2], d[3], d[4])
        b.label = ns:NewText(b, 9, "LEFT")
        b.label:SetPoint("LEFT", 3, 0)
        b.label:SetText(d[1])
        b.time = ns:NewText(b, 9, "RIGHT")
        b.time:SetPoint("RIGHT", -3, 0)
        b:Hide()
        bars[i] = b
    end

    local T = Enum and Enum.PlayerSwingType
    local function Index(swingType)
        if Secret(swingType) or swingType == nil or type(T) ~= "table" then return 1 end
        if swingType == T.OffHand then return 2 end
        if swingType == T.Ranged then return 3 end
        return 1
    end

    local function Start(i, dur)
        local b = bars[i]
        if Secret(dur) then
            b.dur = nil                                   -- hidden: the bar still fills, without numbers
            if not pcall(function() b:SetMinMaxValues(0, dur) end) then return end
        else
            if not dur or dur <= 0 then return end
            b.dur = dur
            b:SetMinMaxValues(0, dur)
        end
        b.start, b.active = GetTime(), true
        b:SetAlpha(1)
        b:Show()
    end

    local preview = false
    holder:SetScript("OnUpdate", ns:Guard("Swing timers", function()
        local now = GetTime()
        if preview then                               -- keep sample swings going
            if not bars[1].active then Start(1, 2.6) end
            if not bars[2].active then Start(2, 1.8) end
            if not bars[3].active then Start(3, 2.2) end
        end
        for _, b in ipairs(bars) do
            if b.active then
                local el = now - b.start
                b:SetValue(el)
                if b.dur then
                    b.time:SetFormattedText("%.1f", math.max(b.dur - el, 0))
                    if el > b.dur then
                        local a = 1 - (el - b.dur) / 0.4       -- soft fade once the swing lands
                        if a <= 0 then b.active = false; b:Hide() else b:SetAlpha(a) end
                    end
                else
                    b.time:SetText("")
                    if el > 6 then b.active = false; b:Hide() end
                end
            end
        end
    end))

    pcall(ev.RegisterUnitEvent, ev, "UNIT_ATTACK_SPEED", "player")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", ns:Guard("Swing timers", function(_, event, a, b)
        if event == "PLAYER_SWING" then
            Start(Index(b), a)
        elseif event == "UNIT_ATTACK_SPEED" then
            -- haste changed mid-swing: keep the same progress, new length (only when readable)
            local mh, oh = UnitAttackSpeed("player")
            local now = GetTime()
            for i, speed in ipairs({ mh, oh }) do
                local bar = bars[i]
                if bar.active and bar.dur and not Secret(speed) and speed and speed > 0 then
                    local frac = math.min((now - bar.start) / bar.dur, 1)
                    bar.dur = speed
                    bar.start = now - frac * speed
                    bar:SetMinMaxValues(0, speed)
                end
            end
        end
    end))

    -- Out of melee range: this client has a range check made for swing timers. While you are fighting
    -- something you can't reach, a small red note sits above the bars. If the answer comes back hidden,
    -- the game sets the note's visibility for us.
    local R = C_SwingTimer
    if type(R) == "table" and R.IsTargetWithinSwingRange then
        if R.EnableRangeCheck then pcall(R.EnableRangeCheck, true) end
        local mark = CreateFrame("Frame", nil, holder)
        mark:SetSize(W, 12)
        mark:SetPoint("BOTTOM", holder, "TOP", 0, 2)
        local label = ns:NewText(mark, 10, "CENTER")
        label:SetPoint("CENTER")
        label:SetText(ns:Tr("out of range"))
        label:SetTextColor(1, 0.3, 0.3)
        mark:Hide()
        ns:Every(0.2, "Swing range", function()
            if preview or not InCombatLockdown() or not UnitExists("target") or not UnitCanAttack("player", "target") then
                mark:Hide()
                return
            end
            local ok, inRange = pcall(R.IsTargetWithinSwingRange)
            if not ok then
                mark:Hide()
            elseif Secret(inRange) then
                mark:Show()
                if mark.SetAlphaFromBoolean then pcall(mark.SetAlphaFromBoolean, mark, inRange, 0, 1) else mark:Hide() end
            else
                mark:SetAlpha(1)
                if inRange then mark:Hide() else mark:Show() end
            end
        end)
    end

    -- Blizzard ships its own swing bars: turn them off so there is only one set
    pcall(function()
        if GetCVar("showSwingTimer") == "1" then
            ns.db.swingCVarWasOn = true
            SetCVar("showSwingTimer", "0")
        end
    end)

    ns:RegisterMovable(holder, "swing", "Swing Timers")

    ns:RegisterPreview(function(on)
        preview = on
        if not on then
            for _, b in ipairs(bars) do b.active = false; b:Hide() end
        end
    end)
end)
