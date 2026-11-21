local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- 11.0: custom alerts and spoken alerts.
--
-- Custom alerts: "when this happens, show this (and play a sound, and say it)". Made on the Combat
-- tab. While the game hides a value from add-ons (health and buffs in a fight, on this client), an
-- alert that needs it keeps whatever it last knew rather than guessing.
--
-- Spoken alerts: the game reads out ready checks, whispers, missing buffs, loss of control and your
-- custom alerts, with its own text-to-speech voice. Off until chosen.
------------------------------------------------------------------------------------------

-- Speaking ------------------------------------------------------------------------------
local voice
local function Voice()
    if voice ~= nil then return voice end
    voice = false
    local V = C_VoiceChat
    if type(V) == "table" and V.GetTtsVoices then
        local ok, list = pcall(V.GetTtsVoices)
        if ok and type(list) == "table" and list[1] then voice = list[1].voiceID or 0 end
    end
    return voice
end
local lastSaid, lastAt = nil, 0
-- Say a line aloud. The same line is not repeated within three seconds.
function ns:Speak(text)
    if type(text) ~= "string" or text == "" or Secret(text) then return false end
    local V = C_VoiceChat
    if type(V) ~= "table" or type(V.SpeakText) ~= "function" then ns.speakState = "this game client cannot speak"; return false end
    local now = GetTime()
    if text == lastSaid and now - lastAt < 3 then return false end
    lastSaid, lastAt = text, now
    local id = Voice() or 0
    local rate = tonumber(ns.db and ns.db.speakRate) or 0
    local volume = tonumber(ns.db and ns.db.speakVolume) or 100
    -- the newer game asks (voice, text, rate, volume, overlap); the older (voice, text, destination, rate, volume)
    local ok = pcall(V.SpeakText, id, text, rate, volume, true)
    if not ok then
        local dest = Enum and Enum.VoiceTtsDestination and (Enum.VoiceTtsDestination.LocalPlayback or Enum.VoiceTtsDestination.QueuedLocalPlayback) or 1
        ok = pcall(V.SpeakText, id, text, dest, rate, volume)
    end
    ns.speakCount = (ns.speakCount or 0) + (ok and 1 or 0)
    ns.speakState = ok and "on" or "the game refused to speak"
    ns.speakLast = text
    return ok
end
ns.SPEAK_KINDS = {
    { "ready", "Ready checks" }, { "whisper", "Whispers" }, { "buffs", "Missing buffs" },
    { "loc", "Loss of control" }, { "custom", "My custom alerts" },
}
function ns:SpeakWanted(kind)
    if not (ns.db and ns.db.speakAlerts) then return false end
    local s = ns.db.speakKinds
    if type(s) ~= "table" then return true end
    return s[kind] ~= false
end
-- Something worth saying happened: say it if spoken alerts are on for this kind.
function ns:SpeakEvent(kind, text)
    if not ns:SpeakWanted(kind) then return false end
    return ns:Speak(ns:Tr(text))
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "READY_CHECK", "CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Spoken alerts", function(_, event, msg, sender)
        if not (ns.db and ns.db.speakAlerts) then return end
        if event == "READY_CHECK" then ns:SpeakEvent("ready", "Ready check")
        else
            local who = (type(sender) == "string" and not Secret(sender)) and sender:gsub("%-.*$", "") or nil
            ns:SpeakEvent("whisper", who and (ns:Tr("Whisper from") .. " " .. who) or ns:Tr("Whisper"))
        end
    end))
end

-- Custom alerts ---------------------------------------------------------------------------
-- Each kind of trigger: its name, whether it takes a number or a name, and how to read it now.
-- read(value) returns true (it is happening), false (it is not) or nil (the game will not say).
local function Percent(cur, max)
    if Secret(cur) or Secret(max) or type(cur) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    return cur / max * 100
end
local function BelowPct(unit, value, power)
    if not ns.Yes(UnitExists(unit)) then return false end
    local p
    if power then p = Percent(UnitPower(unit), UnitPowerMax(unit)) else p = Percent(UnitHealth(unit), UnitHealthMax(unit)) end
    if p == nil then return nil end
    return p < (tonumber(value) or 0)
end
ns.ALERT_TRIGGERS = {
    { key = "health", label = "My health below %", input = "number", read = function(v) return BelowPct("player", v) end },
    { key = "targethealth", label = "Target's health below %", input = "number", read = function(v) return BelowPct("target", v) end },
    { key = "power", label = "My mana or resource below %", input = "number", read = function(v) return BelowPct("player", v, true) end },
    { key = "buffmissing", label = "A buff missing from me", input = "name", read = function(v)
        local has = ns:PlayerHasBuff(v); if has == nil then return nil end; return not has end },
    { key = "buffon", label = "A buff on me", input = "name", read = function(v) return ns:PlayerHasBuff(v) end },
    { key = "spellready", label = "An ability is ready", input = "name", read = function(v)
        if not (C_Spell and C_Spell.GetSpellCooldown) then return nil end
        local ok, cd = pcall(C_Spell.GetSpellCooldown, v)
        if not ok or type(cd) ~= "table" then return nil end
        if Secret(cd.startTime) or Secret(cd.duration) then return nil end
        return (cd.duration or 0) <= 1.6 end },
    { key = "targetcasting", label = "My target is casting", input = nil, read = function()
        if not ns.Yes(UnitExists("target")) then return false end
        local name = UnitCastingInfo and UnitCastingInfo("target")
        if Secret(name) then return true end
        if name == nil and UnitChannelInfo then name = UnitChannelInfo("target") end
        if Secret(name) then return true end
        return name ~= nil end },
    { key = "combat", label = "I am in combat", input = nil, read = function() return InCombatLockdown() and true or false end },
    { key = "bags", label = "Free bag slots below", input = "number", read = function(v)
        local C, free = C_Container, 0
        if not (C and C.GetContainerNumFreeSlots) then return nil end
        for bag = 0, 4 do local ok, f = pcall(C.GetContainerNumFreeSlots, bag); if ok and type(f) == "number" then free = free + f end end
        return free < (tonumber(v) or 0) end },
    { key = "durability", label = "Durability below %", input = "number", read = function(v)
        local d = ns.LowestDurability and ns:LowestDurability()
        if type(d) ~= "number" then return nil end
        return d < (tonumber(v) or 0) end },
}
local BY_KEY = {}
for _, t in ipairs(ns.ALERT_TRIGGERS) do BY_KEY[t.key] = t end
ns.ALERT_BY_KEY = BY_KEY

-- The words for an alert, as the list shows it.
function ns.AlertDescribe(a)
    local t = BY_KEY[a.trigger]
    if not t then return "?" end
    local what = ns:Tr(t.label)
    if t.input then what = what .. " " .. tostring(a.value or "") end
    return what .. "  ->  " .. tostring(a.text ~= "" and a.text or what)
end
-- One step of an alert: given what the trigger reads now (true/false/nil) and whether it was on,
-- is it on now, and did it just start?
function ns.AlertStep(wasOn, reading)
    if reading == nil then return wasOn, false end
    return reading, (reading and not wasOn) and true or false
end
function ns:Alerts()
    if type(ns.db.customAlerts) ~= "table" then ns.db.customAlerts = {} end
    return ns.db.customAlerts
end
function ns:AddAlert(trigger, value, text, sound, speak)
    if not BY_KEY[trigger] then return nil, "There is no such alert." end
    local t = BY_KEY[trigger]
    if t.input == "number" and not tonumber(value) then return nil, "This alert needs a number." end
    if t.input == "name" and (type(value) ~= "string" or ns.Trim(value) == "") then return nil, "This alert needs a name: a buff or an ability." end
    local list = ns:Alerts()
    if #list >= 20 then return nil, "Twenty alerts is the most." end
    local a = { trigger = trigger, value = (t.input == "number") and tonumber(value) or (value and ns.Trim(value)) or nil,
                text = ns.Trim(text or ""), sound = sound ~= false, speak = speak and true or false }
    list[#list + 1] = a
    return a
end

ns:NewModule("customAlerts", function()
    local f = CreateFrame("Frame", "FantasyGlassUICustomAlerts", UIParent)
    f:SetSize(240, 20)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 230)
    local lines = {}
    local function Line(i)
        local fs = f:CreateFontString(nil, "OVERLAY")
        ns:Font(fs, 15, true)
        fs:SetPoint("TOP", f, "TOP", 0, -(i - 1) * 22)
        if fs.SetShadowOffset then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1) end
        lines[i] = fs
        return fs
    end
    local on = {}
    local function Update()
        local list = ns:Alerts()
        local shown = 0
        for i, a in ipairs(list) do
            local t = BY_KEY[a.trigger]
            local reading
            if t then local ok, r = pcall(t.read, a.value); reading = ok and r or nil end
            local now, started = ns.AlertStep(on[a], reading)
            on[a] = now
            if started then
                if a.sound and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959, "Master") end
                if a.sound and ns.Caption then ns:Caption("alert", (a.text ~= "" and a.text) or ns:Tr(t and t.label or "?")) end
                if a.speak then ns:SpeakEvent("custom", (a.text ~= "" and a.text) or ns:Tr(t.label)) end
            end
            if now or (ns.moving and i == 1) then
                shown = shown + 1
                local fs = lines[shown] or Line(shown)
                fs:SetText((a.text ~= "" and a.text) or ns:Tr(t and t.label or "?"))
                ns:Paint(fs, "SetTextColor", "@accent")
                fs:Show()
            end
        end
        if ns.moving and shown == 0 then
            local fs = lines[1] or Line(1)
            fs:SetText(ns:Tr("Custom alerts")); fs:Show(); shown = 1
        end
        for i = shown + 1, #lines do lines[i]:Hide() end
        f:SetHeight(math.max(20, shown * 22))
        ns.customAlertsShown = shown
        return shown
    end
    ns.customAlertsTest = { Update = Update, on = on, frame = f }
    ns:Every(0.25, "Custom alerts", Update)
    local entry = ns:RegisterMovable(f, "customAlerts", "Custom alerts")
    if type(entry) == "table" then entry.offPage = true end
end)
