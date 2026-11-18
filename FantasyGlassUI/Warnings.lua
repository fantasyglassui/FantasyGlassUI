local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Aggro warning: when a monster turns on you and you are not the tank. Only inside a group (alone,
-- everything attacks you), and only when the game lets us read the threat state.
ns:NewModule("aggroWarn", function()
    if not UnitThreatSituation then return end
    local f = CreateFrame("Frame", "FantasyGlassUIAggro", UIParent)
    f:SetSize(220, 36)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
    local text = ns:NewText(f, 26, "CENTER", true)
    text:SetPoint("CENTER")
    text:SetText(ns:Tr("AGGRO"))
    text:SetTextColor(ns:Signal("bad"))
    local pulse = f:CreateAnimationGroup()
    local a = pulse:CreateAnimation("Alpha")
    a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.35)
    if pulse.SetLooping then pulse:SetLooping("BOUNCE") end
    f:Hide()

    local preview, was = false, false
    local function Check()
        if preview then return end
        local on = false
        if ns.db.role ~= "TANK" and IsInGroup and IsInGroup() and InCombatLockdown() then
            local ok, status = pcall(UnitThreatSituation, "player")
            if ok and not Secret(status) and type(status) == "number" and status >= 2 then on = true end
        end
        if on and not was then
            f:Show()
            text:SetTextColor(ns:Signal("bad"))
            if ns:Motion() then pulse:Play() end
            if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then pcall(PlaySound, SOUNDKIT.RAID_WARNING) end
        elseif was and not on then
            pulse:Stop(); f:Hide()
        end
        was = on
    end
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_THREAT_SITUATION_UPDATE", "player")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", ns:Guard("Aggro warning", Check))
    ns:Every(0.5, "Aggro warning", Check)

    ns:RegisterPreview(function(on)
        preview = on
        was = false
        if on then f:Show(); pulse:Play() else pulse:Stop(); f:Hide() end
    end)
    ns:RegisterMovable(f, "aggro", "Aggro warning")
end)

------------------------------------------------------------------------------------------
-- Combat timer: how long the fight has lasted, for any role. It counts from the moment you enter
-- combat, stays on screen for a few seconds after the fight with the final time dimmed, then goes.
-- Only the start and end of combat are needed, which the game always tells add-ons.
------------------------------------------------------------------------------------------
-- 83 -> "1:23", 3725 -> "1:02:05"
function ns.CombatTimerText(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if seconds >= 3600 then return format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60) end
    return format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

ns:NewModule("combatTimer", function()
    local LINGER = 8                                        -- seconds the final time stays up
    -- the holder is what gets moved and is always there; the box inside it comes and goes
    local holder = CreateFrame("Frame", "FantasyGlassUICombatTimer", UIParent)
    holder:SetSize(86, 28)
    holder:SetPoint("TOP", UIParent, "TOP", 0, -200)
    local box = CreateFrame("Frame", nil, holder, ns.template)
    box:SetAllPoints()
    box:SetBackdrop(ns.BACKDROP)
    ns:Paint(box, "SetBackdropColor", "window", (ns.db.panelAlpha or 78) / 100)
    ns:Paint(box, "SetBackdropBorderColor", "@border", 1)
    box.text = ns:NewText(box, 15, "CENTER", true)
    box.text:SetPoint("CENTER")
    box:Hide()

    local startedAt, endedAt, last = nil, nil, 0
    local preview = false
    local function Draw()
        local now = GetTime()
        if preview then
            box.text:SetText("1:23")
            ns:Paint(box.text, "SetTextColor", "@accent")
            box:Show()
            return "preview"
        elseif startedAt then
            box.text:SetText(ns.CombatTimerText(now - startedAt))
            ns:Paint(box.text, "SetTextColor", "@accent")
            box:Show()
            return "counting"
        elseif endedAt and now - endedAt < LINGER then
            box.text:SetText(ns.CombatTimerText(last))
            ns:Paint(box.text, "SetTextColor", "dim")
            box:Show()
            return "final"
        end
        box:Hide()
        return "hidden"
    end
    ns.CombatTimerDraw = Draw
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Combat timer", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            startedAt, endedAt = GetTime(), nil
        elseif event == "PLAYER_REGEN_ENABLED" then
            if startedAt then last = GetTime() - startedAt; endedAt = GetTime() end
            startedAt = nil
        elseif InCombatLockdown() and not startedAt then      -- logged in or reloaded mid-fight
            startedAt = GetTime()
        end
        Draw()
    end))
    ns:Every(0.2, "Combat timer", function() if startedAt or endedAt or preview then Draw() end end)
    ns:RegisterPreview(function(on) preview = on and true or false; Draw() end)
    ns:RegisterMovable(holder, "combatTimer", "Combat timer")
end)
