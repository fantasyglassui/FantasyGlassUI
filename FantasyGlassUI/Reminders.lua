local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Missing buff reminder.
--
-- Buffs that should always be on you (Lightning Shield, a seal, an aura): choose them with
--   /fgui remind Lightning Shield        (the same again takes it off the list)
-- and an icon with a "!" shows while one is missing. Not while dead, on a flight path, or resting
-- in a city outside combat.
------------------------------------------------------------------------------------------
-- Is this buff on you? true / false, or nil when the game will not say.
function ns:PlayerHasBuff(name)
    if type(name) ~= "string" or name == "" then return nil end
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if not ok then return nil end
        return type(aura) == "table"
    end
    local get = ns.GetAura
    if not get then return nil end
    for i = 1, 40 do
        local a = get("player", i, "HELPFUL")
        if not a then return false end
        if Secret(a.name) then return nil end
        if a.name == name then return true end
    end
    return false
end
-- The buffs on the list that are known to be missing (one the game hides is not counted).
function ns.MissingBuffs(list, has)
    local out = {}
    for _, name in ipairs(list or {}) do
        if has(name) == false then out[#out + 1] = name end
    end
    return out
end
-- Is this a moment to remind at all?
function ns.RemindNow(dead, taxi, resting, combat)
    if dead or taxi then return false end
    if resting and not combat then return false end
    return true
end

ns:NewModule("buffMissing", function()
    local SIZE, GAP, MAX = 36, 6, 4
    local holder = CreateFrame("Frame", "FantasyGlassUIMissingBuffs", UIParent)
    holder:SetSize(SIZE, SIZE)
    holder:SetPoint("CENTER", UIParent, "CENTER", -200, 40)
    local icons = {}
    local said = {}                                          -- (missing buffs already spoken of: see Alerts.lua)
    ns.buffMissingState = "on; nothing on the list (/fgui remind <buff name>)"

    local function TextureOf(name)
        local tex
        if C_Spell and C_Spell.GetSpellTexture then local ok, t = pcall(C_Spell.GetSpellTexture, name); if ok then tex = t end
        elseif GetSpellTexture then local ok, t = pcall(GetSpellTexture, name); if ok then tex = t end end
        return tex or "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    local function Refresh()
        local list = ns:SavedList("remindBuffs")
        local missing = {}
        local now = ns.RemindNow(ns.Yes(UnitIsDeadOrGhost("player")), ns.Yes(UnitOnTaxi and UnitOnTaxi("player")),
            ns.Yes(IsResting and IsResting()), ns.Yes(UnitAffectingCombat("player")))
        if ns.moving then missing = { "?" }
        elseif now and #list > 0 then missing = ns.MissingBuffs(list, function(name) return ns:PlayerHasBuff(name) end) end
        if ns.SpeakEvent and not ns.moving then
            local now = {}
            for _, name in ipairs(missing) do
                now[name] = true
                if not said[name] then ns:SpeakEvent("buffs", ns:Tr("Missing") .. " " .. name) end
            end
            said = now
        end
        for i = 1, math.max(#missing, #icons) do
            local name, b = missing[i], icons[i]
            if name and i <= MAX then
                if not b then
                    b = CreateFrame("Frame", nil, holder)
                    b:SetSize(SIZE, SIZE)
                    b:SetPoint("LEFT", holder, "LEFT", (i - 1) * (SIZE + GAP), 0)
                    b.tex = b:CreateTexture(nil, "ARTWORK")
                    b.tex:SetAllPoints()
                    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    if b.tex.SetDesaturated then b.tex:SetDesaturated(true) end
                    b.mark = ns:NewText(b, 20, "CENTER")
                    b.mark:SetPoint("CENTER")
                    b.mark:SetText("!")
                    b.mark:SetTextColor(ns:Signal("bad"))
                    ns:AddBorder(b, 0.85, 0.18, 0.18, 1)
                    icons[i] = b
                end
                b.name = name
                pcall(b.tex.SetTexture, b.tex, TextureOf(name))
                b:Show()
            elseif b then
                b.name = nil
                b:Hide()
            end
        end
        ns.buffMissingState = (#list == 0) and "on; nothing on the list (/fgui remind <buff name>)"
            or format("on; watching %d, %d missing now", #list, ns.moving and 0 or #missing)
        return missing
    end
    ns.buffMissingTest = { Refresh = Refresh, icons = icons }
    ns:Every(1, "Missing buff reminder", function() pcall(Refresh) end)
    local entry = ns:RegisterMovable(holder, "missingBuffs", "Missing buffs")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
end)

------------------------------------------------------------------------------------------
-- Focus cast alert: a sound and a line on screen when your focus starts a cast.
------------------------------------------------------------------------------------------
ns:NewModule("focusCastAlert", function()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Focus cast alert", function(_, event, unit)
        if not ns.Is(unit, "focus") then return end
        if not ns.Yes(UnitCanAttack("player", "focus")) then return end      -- (a friend's cast is not an alarm)
        local name
        if event == "UNIT_SPELLCAST_START" and UnitCastingInfo then name = UnitCastingInfo("focus")
        elseif UnitChannelInfo then name = UnitChannelInfo("focus") end
        if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959, "Master") end
        ns:Flash(ns:Tr("Focus") .. ": %s", 1, 0.45, 0.2, name ~= nil and name or "?")
        ns.focusCastCount = (ns.focusCastCount or 0) + 1
    end))
end)

------------------------------------------------------------------------------------------
-- Execute line: a tick on the target's health bar at a percentage you choose (/fgui execute 20).
-- Only on a target you can attack: on a friend it would be a stray line with no meaning.
------------------------------------------------------------------------------------------
function ns.ExecuteWanted()
    return ns.Yes(UnitExists("target")) and ns.Yes(UnitCanAttack("player", "target")) and true or false
end
-- How far along a bar this wide the tick sits.
function ns.ExecuteOffset(width, percent)
    percent = math.max(1, math.min(99, tonumber(percent) or 20))
    return math.floor((tonumber(width) or 0) * percent / 100 + 0.5), percent
end
ns:NewModule("executeLine", function()
    local tick
    local function Place()
        local frame = _G.FantasyGlassUI_Target
        local bar = type(frame) == "table" and frame.health
        if not (type(bar) == "table" and bar.CreateTexture and bar.GetWidth) then ns.executeState = "waiting for the target frame"; return false end
        if not tick then
            tick = bar:CreateTexture(nil, "OVERLAY")
            tick:SetTexture(ns.FLAT)
            tick:SetVertexColor(1, 1, 1, 0.9)
            tick:SetWidth(2)
        end
        if not ns.ExecuteWanted() then tick:Hide(); ns.executeState = "on, hidden (the target is not an enemy)"; return false end
        local w = bar:GetWidth()
        if type(w) ~= "number" or Secret(w) or w <= 0 then return false end
        local x, pct = ns.ExecuteOffset(w, ns.db.executePct)
        tick:ClearAllPoints()
        tick:SetPoint("TOP", bar, "TOPLEFT", x, 0)
        tick:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x, 0)
        tick:Show()
        ns.executeState = format("on, at %d%%", pct)
        return x
    end
    ns.executeTest = { Place = Place, tick = function() return tick end }
    ns:Every(2, "Execute line", function() pcall(Place) end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:SetScript("OnEvent", ns:Guard("Reminders events", function() pcall(Place) end))
end)
function ns:ExecuteCommand(text)
    local n = tonumber((tostring(text or ""):gsub("%%", "")))
    if n and n >= 1 and n <= 99 then
        ns.db.executePct = math.floor(n)
        if ns.executeTest then pcall(ns.executeTest.Place) end
    end
    ns:Print("The execute line is at %d%% of the target's health.", tonumber(ns.db.executePct) or 20)
    if not ns.db.executeLine then ns:Print("It is switched off: see \"Execute line on the target\" on the Features tab.") end
end

------------------------------------------------------------------------------------------
-- Loss-of-control alert: a large icon and a countdown while you are stunned, silenced, feared...
------------------------------------------------------------------------------------------
ns:NewModule("locAlert", function()
    local L = C_LossOfControl
    local Read = type(L) == "table" and (L.GetActiveLossOfControlData or L.GetEventInfo)
    if type(Read) ~= "function" then
        ns.locState = "this game client does not tell add-ons when you lose control"
        return
    end
    ns.locState = "on"
    local f = CreateFrame("Frame", "FantasyGlassUILossOfControl", UIParent)
    f:SetSize(52, 52)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local okC, cd = pcall(CreateFrame, "Cooldown", nil, f, "CooldownFrameTemplate")
    if okC and cd then cd:SetAllPoints(); if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end; f.cd = cd end
    f.text = ns:NewText(f, 14, "CENTER")
    f.text:SetPoint("TOP", f, "BOTTOM", 0, -4)
    f.text:SetTextColor(ns:Signal("bad"))
    ns:AddBorder(f, 0.85, 0.18, 0.18, 1)
    f:Hide()

    local function Update()
        if ns.moving then f.tex:SetTexture("Interface\\Icons\\Spell_Frost_Stun"); f.text:SetText(ns:Tr("Stunned")); f:Show(); return true end
        local ok, data = pcall(Read, 1)
        if not (ok and type(data) == "table") then f:Hide(); return false end
        if not ns.Yes(f:IsShown()) and ns.SpeakEvent then
            local said = (type(data.displayText) == "string" and not Secret(data.displayText)) and data.displayText or ns:Tr("Lost control")
            ns:SpeakEvent("loc", said)
        end
        pcall(f.tex.SetTexture, f.tex, data.iconTexture)
        if not pcall(f.text.SetText, f.text, data.displayText) then f.text:SetText("") end
        if f.cd then
            if not pcall(function() f.cd:SetCooldown(data.startTime, data.duration) end) then f.cd:Hide() else f.cd:Show() end
        end
        f:Show()
        ns.locCount = (ns.locCount or 0) + 1
        return true
    end
    ns.locTest = { Update = Update, frame = f }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "LOSS_OF_CONTROL_ADDED", "LOSS_OF_CONTROL_UPDATE", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Loss of control", function() Update() end))
    -- while it shows: gone as soon as control is back, and the sample put away after move mode
    ns:Every(0.5, "Loss of control", function() if f:IsShown() then pcall(Update) end end)
    local entry = ns:RegisterMovable(f, "lossOfControl", "Loss of control")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
end)

------------------------------------------------------------------------------------------
-- Aura filters: buffs you never want to see in your own buff row.
--   /fgui hidebuff Well Fed          (the same again shows it once more)
-- Auras.lua asks ns:AuraHidden for each buff it is about to draw.
------------------------------------------------------------------------------------------
local hideSet, hideSeen
function ns:AuraHidden(aura)
    if not ns.db.auraFilter or type(aura) ~= "table" then return false end
    local name = aura.name
    if type(name) ~= "string" or Secret(name) then return false end
    if hideSeen ~= ns.listChanged or not hideSet then
        hideSet, hideSeen = {}, ns.listChanged
        for _, n in ipairs(ns:SavedList("auraHide")) do hideSet[tostring(n):lower()] = true end
    end
    return hideSet[name:lower()] == true
end
