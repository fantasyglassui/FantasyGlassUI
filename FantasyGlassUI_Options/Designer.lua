-- Part of Fantasy Glass UI's options folder (see Config.lua): the frame designer, on the Bars and frames tab.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- One frame's design at a time: its size, power bar, portrait side, text size, and where its name
-- and health text sit. Each change shows at once on the frame (a size waits for the end of a fight).
function ns.BuildFrameDesigner(box)
    local D = { frames = ns.DESIGN_FRAMES or {} }
    if #D.frames == 0 then return nil end
    local current = 1
    local function Key() return D.frames[current].key end
    local function Frame()
        for _, f in ipairs(ns.unitFrameList or {}) do if f.designKey == Key() then return f end end
    end
    local function Get()
        if type(ns.db.ufDesign) ~= "table" then ns.db.ufDesign = {} end
        return ns.db.ufDesign[Key()]
    end
    local function Set(field, value)
        if type(ns.db.ufDesign) ~= "table" then ns.db.ufDesign = {} end
        local d = ns.db.ufDesign[Key()]
        if type(d) ~= "table" then d = {}; ns.db.ufDesign[Key()] = d end
        d[field] = value
        if ns.ApplyFrameDesign then ns:ApplyFrameDesign() end
        D.changes = (D.changes or 0) + 1
    end
    local title = box:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 15, true)
    title:SetPoint("TOPLEFT", 0, 0)
    ns:Paint(title, "SetTextColor", "@accent")
    local syncing = false
    local function Slider(label, lo, hi, step, y, field)
        local s = ns:CreateSlider(box, label, lo, hi, step, lo, "%d", function(v) if not syncing then Set(field, v) end end, 300)
        s:SetPoint("TOPLEFT", 0, y)
        return s
    end
    D.width = Slider("Width", 80, 420, 2, -34, "w")
    D.height = Slider("Height", 16, 90, 1, -74, "h")
    D.power = Slider("Power bar height", 0, 20, 1, -114, "power")
    D.font = Slider("Text size", 8, 22, 1, -154, "font")
    local CHOICES = {
        portrait = { { "LEFT", "Left" }, { "RIGHT", "Right" }, { "OFF", "None" } },
        name = { { "LEFT", "Left" }, { "CENTER", "Middle" }, { "OFF", "Hidden" } },
        health = { { "RIGHT", "Right" }, { "CENTER", "Middle" }, { "LEFT", "Left" }, { "OFF", "Hidden" } },
    }
    local LABEL = { portrait = "Portrait", name = "Name", health = "Health text" }
    D.buttons = {}
    local function Draw(field)
        local b = D.buttons[field]
        local d = Get() or {}
        local f = Frame()
        local now = d[field] or (field == "portrait" and f and f.baseOpt and f.baseOpt.portrait) or CHOICES[field][1][1]
        local name = now
        for _, c in ipairs(CHOICES[field]) do if c[1] == now then name = c[2] end end
        b.text:SetText(ns:Tr(LABEL[field]) .. ":  " .. ns:Tr(name))
    end
    -- the next choice for one of the three (what a click on its button does)
    function D.Step(field)
        local d = Get() or {}
        local list = CHOICES[field]
        local f = Frame()
        local now = d[field] or (field == "portrait" and f and f.baseOpt and f.baseOpt.portrait) or list[1][1]
        local at = 1
        for j, c in ipairs(list) do if c[1] == now then at = j end end
        Set(field, list[at % #list + 1][1])
        Draw(field)
    end
    for i, field in ipairs({ "portrait", "name", "health" }) do
        local b = ns:CreateButton(box, "", 300, 24, function() D.Step(field) end)
        b:SetPoint("TOPLEFT", 360, -34 - (i - 1) * 32)
        D.buttons[field] = b
    end
    local reset = ns:CreateButton(box, "Back to how it came", 300, 24, function()
        if type(ns.db.ufDesign) == "table" then ns.db.ufDesign[Key()] = nil end
        local f = Frame()
        if f and f.baseOpt and not InCombatLockdown() then
            local w, h = f.baseOpt.w, f.baseOpt.h
            if f.sizeKey == "main" then w, h = ns.db.ufW, ns.db.ufH end
            f:SetSize(w, h)
        end
        if ns.ApplyFrameDesign then ns:ApplyFrameDesign() end
        D.Show(current)
    end)
    reset:SetPoint("TOPLEFT", 360, -140)
    local note = box:CreateFontString(nil, "OVERLAY")
    ns:Font(note, 11)
    note:SetPoint("TOPLEFT", 0, -200)
    note:SetWidth(660)
    note:SetJustifyH("LEFT")
    ns:Paint(note, "SetTextColor", "faint")
    note:SetText(ns:Tr("Changes show on the frame at once; a new size waits until you are out of combat. /fgui test shows every frame, so you can see them while you design. To move a frame, type /fgui move."))
    local missing = box:CreateFontString(nil, "OVERLAY")
    ns:Font(missing, 12)
    missing:SetPoint("TOPLEFT", 0, -240)
    missing:SetWidth(660)
    missing:SetJustifyH("LEFT")

    function D.Show(j)
        if not D.frames[j] then return end
        current = j
        D.current = j
        local f = Frame()
        title:SetText(ns:Tr(D.frames[j].label))
        local d = Get() or {}
        syncing = true
        local w = d.w or (f and f:GetWidth()) or 200
        local h = d.h or (f and f:GetHeight()) or 40
        if type(w) ~= "number" or ns:IsSecret(w) then w = 200 end
        if type(h) ~= "number" or ns:IsSecret(h) then h = 40 end
        D.width:SetValue(w)
        D.height:SetValue(h)
        D.power:SetValue(d.power or (f and f.baseOpt and f.baseOpt.power) or 0)
        D.font:SetValue(d.font or (f and f.baseOpt and f.baseOpt.font) or 12)
        syncing = false
        D.power:SetAlpha((f and f.power) and 1 or 0.35)
        D.buttons.portrait:SetAlpha((f and f.portrait) and 1 or 0.35)
        for field in pairs(D.buttons) do Draw(field) end
        if f then missing:SetText("") else missing:SetText("|cffffd100" .. ns:Tr("This frame is not in use just now (switched off, or another add-on has the unit frames).") .. "|r") end
    end
    function D.Refresh() D.Show(current) end
    ns.frameDesigner = D
    return D
end

------------------------------------------------------------------------------------------
-- Custom alerts (Combat tab): the list of alerts, and a row for making a new one.
------------------------------------------------------------------------------------------
function ns.BuildAlertEditor(box)
    local E = {}
    local trig = 1
    local function T() return ns.ALERT_TRIGGERS[trig] end
    local trigBtn
    local value = ns:CreateEditBox(box, 90, 24, "value")
    local text = ns:CreateEditBox(box, 210, 24, "what to show")
    local function DrawTrig()
        trigBtn.text:SetText(ns:Tr(T().label))
        if T().input then
            value:Show()
            -- the box's grey hint says what to type (it once said "value" whatever the alert wanted)
            if value.hint and value.hint.SetText then value.hint:SetText(ns:Tr((T().input == "number") and "a number" or "a name")) end
        else value:Hide() end
    end
    trigBtn = ns:CreateButton(box, "", 230, 24, function(_, button)
        local n = #ns.ALERT_TRIGGERS
        trig = (button == "RightButton") and ((trig - 2) % n + 1) or (trig % n + 1)
        DrawTrig()
    end)
    trigBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    trigBtn:SetPoint("TOPLEFT", 0, 0)
    value:SetPoint("LEFT", trigBtn, "RIGHT", 8, 0)
    text:SetPoint("LEFT", value, "RIGHT", 8, 0)
    local sound = ns:CreateCheckbox(box, "Sound", true, function() end)
    sound:SetWidth(90)
    sound:SetPoint("TOPLEFT", 0, -32)
    local speak = ns:CreateCheckbox(box, "Say it", false, function() end)
    speak:SetWidth(90)
    speak:SetPoint("LEFT", sound, "RIGHT", 10, 0)
    local msg = box:CreateFontString(nil, "OVERLAY")
    ns:Font(msg, 11)
    local rows = {}
    local Refresh
    local add = ns:CreateButton(box, "Add", 80, 24, function()
        local v = value:GetText()
        if type(v) ~= "string" then v = "" end
        local t = text:GetText()
        if type(t) ~= "string" then t = "" end
        local a, why = ns:AddAlert(T().key, v, t, sound.checked ~= false, speak.checked == true)
        if a then msg:SetText(ns:SignalHex("good") .. ns:Tr("Added.") .. "|r"); value:SetText(""); text:SetText("")
        else msg:SetText(ns:SignalHex("bad") .. ns:Tr(why) .. "|r") end
        Refresh()
    end)
    add:SetPoint("LEFT", text, "RIGHT", 8, 0)
    msg:SetPoint("LEFT", speak, "RIGHT", 110, 0)
    local list = CreateFrame("Frame", nil, box)
    list:SetPoint("TOPLEFT", 0, -66)
    list:SetSize(700, 230)
    local empty = list:CreateFontString(nil, "OVERLAY")
    ns:Font(empty, 11)
    empty:SetPoint("TOPLEFT", 0, -4)
    ns:Paint(empty, "SetTextColor", "faint")
    empty:SetText(ns:Tr("No alerts yet. Choose what to watch for (click to step through), fill in a number or a name, and what to show."))
    Refresh = function()
        local alerts = ns:Alerts()
        for i, a in ipairs(alerts) do
            local r = rows[i]
            if not r then
                r = CreateFrame("Frame", nil, list)
                r:SetSize(700, 22)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
                r.text = r:CreateFontString(nil, "OVERLAY")
                ns:Font(r.text, 12)
                r.text:SetPoint("LEFT", 0, 0)
                r.text:SetWidth(620)
                r.text:SetJustifyH("LEFT")
                r.x = ns:CreateButton(r, "x", 22, 18, function() table.remove(ns:Alerts(), r.index); Refresh() end)
                r.x:SetPoint("RIGHT", -40, 0)
                rows[i] = r
            end
            r.index = i
            r.text:SetText(ns.AlertDescribe(a) .. ((a.speak and "  |cff9aa4b4(" .. ns:Tr("said") .. ")|r") or ""))
            r:Show()
        end
        for i = #alerts + 1, #rows do rows[i]:Hide() end
        empty:SetShown(#alerts == 0)
        E.count = #alerts
    end
    DrawTrig()
    Refresh()
    E.Refresh, E.triggerButton, E.value, E.text, E.add, E.sound, E.speak = Refresh, trigBtn, value, text, add, sound, speak
    ns.alertEditor = E
    return E
end

-- Spoken alerts (Combat tab): which things are said aloud.
function ns.BuildSpeakEditor(box)
    local S = {}
    local on = ns:CreateCheckbox(box, "Spoken alerts", ns.db.speakAlerts, function(v) ns.db.speakAlerts = v end)
    on:SetWidth(240)
    on:SetPoint("TOPLEFT", 0, 0)
    S.boxes = {}
    for i, def in ipairs(ns.SPEAK_KINDS or {}) do
        local cb = ns:CreateCheckbox(box, def[2], ns:SpeakWanted(def[1]) or not ns.db.speakAlerts, function(v)
            if type(ns.db.speakKinds) ~= "table" then ns.db.speakKinds = {} end
            ns.db.speakKinds[def[1]] = v and true or false
        end)
        cb:SetWidth(220)
        cb:SetPoint("TOPLEFT", ((i - 1) % 3) * 240, -30 - math.floor((i - 1) / 3) * 26)
        S.boxes[def[1]] = cb
    end
    local test = ns:CreateButton(box, "Try the voice", 140, 24, function() ns:Speak(ns:Tr("Fantasy Glass UI is speaking.")) end)
    test:SetPoint("TOPLEFT", 0, -92)
    local note = box:CreateFontString(nil, "OVERLAY")
    ns:Font(note, 11)
    note:SetPoint("LEFT", test, "RIGHT", 12, 0)
    note:SetWidth(540)
    note:SetJustifyH("LEFT")
    ns:Paint(note, "SetTextColor", "faint")
    note:SetText(ns:Tr("Uses the game's own text-to-speech voice (Options, Accessibility, Text to Speech chooses it)."))
    S.on, S.test = on, test
    ns.speakEditor = S
    return S
end

------------------------------------------------------------------------------------------
-- Nameplate designer and raid frame designer (Bars and frames tab, 11.0.1).
------------------------------------------------------------------------------------------
local function Cycler(box, width, list, get, set, label)
    local b
    local function Draw()
        local now, name = get(), nil
        for _, c in ipairs(list) do if c[1] == now then name = c[2] end end
        -- a value that is none of the choices (the game handed back something unexpected): the first choice, never "table: 0x..."
        if not name and type(now) ~= "string" and type(now) ~= "number" then name = list[1] and list[1][2] end
        b.text:SetText(ns:Tr(label) .. ":  " .. ns:Tr(name or tostring(now)))
    end
    b = ns:CreateButton(box, "", width, 24, function()
        local now, at = get(), 1
        for i, c in ipairs(list) do if c[1] == now then at = i end end
        set(list[at % #list + 1][1])
        Draw()
    end)
    b.Draw = Draw
    return b
end
local function Note(box, text, x, y, w)
    local fs = box:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 11)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(w or 660)
    fs:SetJustifyH("LEFT")
    ns:Paint(fs, "SetTextColor", "faint")
    fs:SetText(ns:Tr(text))
    return fs
end

function ns.BuildPlateDesigner(box)
    local P = {}
    local syncing = false
    local function Set(k, v)
        if type(ns.db.plateDesign) ~= "table" then ns.db.plateDesign = {} end
        ns.db.plateDesign[k] = v
        if ns.ApplyPlateDesign then ns:ApplyPlateDesign() end
        P.changes = (P.changes or 0) + 1
    end
    local title = box:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 15, true)
    title:SetPoint("TOPLEFT", 0, 0)
    ns:Paint(title, "SetTextColor", "@accent")
    title:SetText(ns:Tr("Nameplates"))
    local function Slider(label, lo, hi, step, x, y, fn, w)
        local s = ns:CreateSlider(box, label, lo, hi, step, lo, "%d", function(v) if not syncing then fn(v) end end, w or 300)
        s:SetPoint("TOPLEFT", x, y)
        return s
    end
    P.width = Slider("Nameplate width %", 60, 180, 5, 0, -34, function(v) ns.db.plateW = v; if ns.NameplateSizeChanged then ns:NameplateSizeChanged() end end)
    P.height = Slider("Nameplate height %", 60, 270, 5, 0, -74, function(v) ns.db.plateH = v; if ns.NameplateSizeChanged then ns:NameplateSizeChanged() end end)
    P.nameSize = Slider("Name size", 6, 18, 1, 0, -114, function(v) Set("nameSize", v) end)
    P.healthSize = Slider("Health text size", 6, 18, 1, 0, -154, function(v) Set("healthSize", v) end)
    P.castHeight = Slider("Cast bar height", 4, 20, 1, 0, -194, function(v) Set("castHeight", v) end)
    P.castText = Slider("Cast bar text size", 6, 14, 1, 0, -234, function(v) Set("castTextSize", v) end)
    P.auraSize = Slider("Debuff icon size", 10, 32, 1, 360, -34, function(v) Set("auraSize", v) end)
    P.auraMax = Slider("Debuffs shown", 0, 8, 1, 360, -74, function(v) Set("auraMax", v) end)
    P.health = Cycler(box, 300, { { "CENTER", "Middle" }, { "RIGHT", "Right" }, { "LEFT", "Left" }, { "OFF", "Hidden" } },
        function() return ns.PlateDesign().healthPos end, function(v) Set("healthPos", v) end, "Health text")
    P.health:SetPoint("TOPLEFT", 360, -118)
    P.nameShow = ns:CreateCheckbox(box, "Names on nameplates", true, function(v) Set("nameShow", v) end)
    P.nameShow:SetWidth(300); P.nameShow:SetPoint("TOPLEFT", 360, -150)
    P.threat = ns:CreateCheckbox(box, "Threat colors", true, function(v) Set("threat", v) end)
    P.threat:SetWidth(300); P.threat:SetPoint("TOPLEFT", 360, -176)
    P.highlight = ns:CreateCheckbox(box, "Mark my target's plate", true, function(v) Set("highlight", v) end)
    P.highlight:SetWidth(300); P.highlight:SetPoint("TOPLEFT", 360, -202)
    local reset = ns:CreateButton(box, "Back to how it came", 300, 24, function()
        ns.db.plateDesign = nil
        if ns.ApplyPlateDesign then ns:ApplyPlateDesign() end
        P.Refresh()
    end)
    reset:SetPoint("TOPLEFT", 360, -236)
    P.note = Note(box, "Size uses the game's own nameplate scale and waits until you are out of combat. Cast bars and debuff icons need \"Nameplate casts & debuffs\" on (Features tab); names and highlighting apply to plates as they appear.", 0, -280)
    function P.Refresh()
        local pd = ns.PlateDesign and ns.PlateDesign() or ns.PLATE_DEFAULT or {}
        syncing = true
        P.width:SetValue(tonumber(ns.db.plateW) or 100)
        P.height:SetValue(tonumber(ns.db.plateH) or 100)
        P.nameSize:SetValue(pd.nameSize or 10)
        P.healthSize:SetValue(pd.healthSize or 9)
        P.castHeight:SetValue(pd.castHeight or 8)
        P.castText:SetValue(pd.castTextSize or 8)
        P.auraSize:SetValue(pd.auraSize or 18)
        P.auraMax:SetValue(pd.auraMax or 5)
        syncing = false
        P.nameShow:SetChecked(pd.nameShow ~= false)
        P.threat:SetChecked(pd.threat ~= false)
        P.highlight:SetChecked(pd.highlight ~= false)
        P.health.Draw()
    end
    P.Refresh()
    ns.plateDesigner = P
    return P
end

function ns.BuildRaidDesigner(box)
    local R = {}
    local syncing = false
    local function Set(k, v)
        if type(ns.db.raidDesign) ~= "table" then ns.db.raidDesign = {} end
        ns.db.raidDesign[k] = v
        if ns.ApplyRaidDesign then ns:ApplyRaidDesign() end
        R.changes = (R.changes or 0) + 1
    end
    local title = box:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 15, true)
    title:SetPoint("TOPLEFT", 0, 0)
    ns:Paint(title, "SetTextColor", "@accent")
    title:SetText(ns:Tr("Raid frames"))
    local function Slider(label, lo, hi, step, x, y, fn)
        local s = ns:CreateSlider(box, label, lo, hi, step, lo, "%d", function(v) if not syncing then fn(v) end end, 300)
        s:SetPoint("TOPLEFT", x, y)
        return s
    end
    R.width = Slider("Width", 40, 200, 2, 0, -34, function(v) ns.db.raidW = v; if ns.ResizeRaid then ns:ResizeRaid() end end)
    R.height = Slider("Height", 20, 90, 1, 0, -74, function(v) ns.db.raidH = v; if ns.ResizeRaid then ns:ResizeRaid() end end)
    R.gap = Slider("Space between frames", 0, 12, 1, 0, -114, function(v) Set("gap", v) end)
    R.perColumn = Slider("Players in each column", 1, 10, 1, 0, -154, function(v) Set("perColumn", v) end)
    R.nameSize = Slider("Name size", 7, 16, 1, 0, -194, function(v) Set("nameSize", v) end)
    R.statusSize = Slider("Status text size", 7, 14, 1, 0, -234, function(v) Set("statusSize", v) end)
    R.direction = Cycler(box, 300, { { false, "Down" }, { true, "Across" } },
        function() return ns.RaidDesign().horizontal end, function(v) Set("horizontal", v) end, "Direction")
    R.direction:SetPoint("TOPLEFT", 360, -34)
    local sorts = {}
    for _, key in ipairs({ "group", "role", "name" }) do if ns.raidSorts and ns.raidSorts[key] then sorts[#sorts + 1] = { key, key:sub(1, 1):upper() .. key:sub(2) } end end
    R.sort = Cycler(box, 300, sorts, function() return ns.db.raidSort or "group" end, function(v)
        ns.db.raidSort = v
        if ns.ApplyRaidSort then ns:ApplyRaidSort() end
    end, "Order")
    R.sort:SetPoint("TOPLEFT", 360, -64)
    -- the game's own raid frames: its settings
    R.game = CreateFrame("Frame", nil, box)
    R.game:SetPoint("TOPLEFT", 360, -100)
    R.game:SetSize(320, 200)
    R.cvars = {}
    for i, def in ipairs(ns.RAID_CVARS or {}) do
        local cb = ns:CreateCheckbox(R.game, def.label, false, function(v) ns:RaidGameSetting(def.key, v and 1 or 0) end)
        cb:SetWidth(300)
        cb:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
        R.cvars[def.key] = cb
    end
    R.healthText = Cycler(R.game, 300, ns.RAID_HEALTH_TEXT or {}, function() return ns:RaidGameSetting("raidFramesHealthText") or "none" end,
        function(v) ns:RaidGameSetting("raidFramesHealthText", v) end, "Health text")
    R.healthText:SetPoint("TOPLEFT", 0, -(#(ns.RAID_CVARS or {})) * 26 - 4)
    local reset = ns:CreateButton(box, "Back to how it came", 300, 24, function()
        ns.db.raidDesign = nil
        if ns.ApplyRaidDesign then ns:ApplyRaidDesign() end
        R.Refresh()
    end)
    reset:SetPoint("TOPLEFT", 0, -276)
    R.note = Note(box, "", 0, -312)
    function R.Refresh()
        local rd = ns.RaidDesign and ns.RaidDesign() or ns.RAID_DEFAULT or {}
        syncing = true
        R.width:SetValue(tonumber(ns.db.raidW) or 78)
        R.height:SetValue(tonumber(ns.db.raidH) or 38)
        R.gap:SetValue(rd.gap or 4)
        R.perColumn:SetValue(rd.perColumn or 5)
        R.nameSize:SetValue(rd.nameSize or 11)
        R.statusSize:SetValue(rd.statusSize or 10)
        syncing = false
        R.direction.Draw(); R.sort.Draw(); R.healthText.Draw()
        for key, cb in pairs(R.cvars) do cb:SetChecked(tostring(ns:RaidGameSetting(key)) == "1") end
        local game = (ns.raidMode == "game")
        R.mode = ns.raidMode
        for _, s in ipairs({ R.width, R.height, R.gap, R.perColumn, R.direction, R.sort }) do s:SetAlpha(game and 0.35 or 1) end
        R.game:SetAlpha(game and 1 or 0.35)
        R.note:SetText(ns:Tr(game
            and "This client hides buffs from add-ons in a fight, so the game's own raid frames are used, restyled: their size and layout are in the game's Edit Mode (Esc, Edit Mode, Raid Frames). Here: their lettering and the game's raid frame settings on the right."
            or "The add-on's own raid frames. Size, spacing and layout change when you are out of combat; /fgui test shows sample players to look at."))
    end
    R.Refresh()
    ns.raidDesigner = R
    return R
end

------------------------------------------------------------------------------------------
-- Aura designer (11.3): which buffs and debuffs show on each frame, how many, how big and where.
------------------------------------------------------------------------------------------
function ns.BuildAuraDesigner(box)
    local A = { kind = "target" }
    local syncing = false
    local KINDS = { { "target", "Target frame" }, { "focus", "Focus frame" }, { "player", "Player frame" }, { "raid", "Raid frames" }, { "plates", "Nameplates" } }
    local function Set(k, v)
        if A.kind == "plates" then
            if type(ns.db.plateDesign) ~= "table" then ns.db.plateDesign = {} end
            ns.db.plateDesign[k] = v
        else
            if type(ns.db.auraDesign) ~= "table" then ns.db.auraDesign = {} end
            if type(ns.db.auraDesign[A.kind]) ~= "table" then ns.db.auraDesign[A.kind] = {} end
            ns.db.auraDesign[A.kind][k] = v
        end
        if ns.ApplyAuraDesign then pcall(ns.ApplyAuraDesign, ns) end
        if A.kind == "plates" and ns.ApplyPlateDesign then pcall(ns.ApplyPlateDesign, ns) end
        A.changes = (A.changes or 0) + 1
    end
    local function D() return (A.kind == "plates") and (ns.PlateDesign and ns.PlateDesign() or {}) or (ns.AuraDesign and ns.AuraDesign(A.kind) or {}) end
    local title = box:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 15, true)
    title:SetPoint("TOPLEFT", 0, 0)
    ns:Paint(title, "SetTextColor", "@accent")
    title:SetText(ns:Tr("Auras"))
    A.which = Cycler(box, 300, KINDS, function() return A.kind end, function(v) A.kind = v; A.Refresh() end, "Frame")
    A.which:SetPoint("TOPLEFT", 0, -32)
    local function Slider(label, lo, hi, x, y, key)
        local s = ns:CreateSlider(box, label, lo, hi, 1, lo, "%d", function(v) if not syncing then Set(key, v) end end, 300)
        s:SetPoint("TOPLEFT", x, y)
        return s
    end
    -- unit frames
    A.show = Cycler(box, 300, { { "both", "Buffs and debuffs" }, { "debuffs", "Debuffs" }, { "buffs", "Buffs" }, { "none", "Nothing" } },
        function() return D().show end, function(v) Set("show", v) end, "Show")
    A.show:SetPoint("TOPLEFT", 0, -70)
    A.max = Slider("How many", 0, 16, 0, -104, "max")
    A.size = Slider("Icon size", 14, 36, 0, -144, "size")
    A.side = Cycler(box, 300, { { "above", "Above the frame" }, { "below", "Below the frame" } }, function() return D().side end, function(v) Set("side", v) end, "Where")
    A.side:SetPoint("TOPLEFT", 360, -70)
    A.grow = Cycler(box, 300, { { "right", "To the right" }, { "left", "To the left" } }, function() return D().grow end, function(v) Set("grow", v) end, "Grow")
    A.grow:SetPoint("TOPLEFT", 360, -100)
    A.mine = ns:CreateCheckbox(box, "Only debuffs I put on", false, function(v) Set(A.kind == "plates" and "auraMine" or "mine", v) end)
    A.mine:SetWidth(300); A.mine:SetPoint("TOPLEFT", 360, -132)
    -- raid frames
    A.hots = Slider("My buffs on each player (heals over time)", 0, 3, 0, -70, "hots")
    A.debuff = ns:CreateCheckbox(box, "A debuff icon on each player", true, function(v) Set("debuff", v) end)
    A.debuff:SetWidth(300); A.debuff:SetPoint("TOPLEFT", 360, -70)
    A.dispel = ns:CreateCheckbox(box, "Light up players I can cleanse", true, function(v) Set("dispel", v) end)
    A.dispel:SetWidth(300); A.dispel:SetPoint("TOPLEFT", 360, -96)
    -- nameplates
    A.plateSize = Slider("Debuff icon size", 10, 32, 0, -104, "auraSize")
    A.plateMax = Slider("Debuffs shown", 0, 8, 0, -144, "auraMax")
    local reset = ns:CreateButton(box, "Back to how it came", 300, 24, function()
        if A.kind == "plates" then
            if type(ns.db.plateDesign) == "table" then ns.db.plateDesign.auraSize, ns.db.plateDesign.auraMax, ns.db.plateDesign.auraMine = nil, nil, nil end
        elseif type(ns.db.auraDesign) == "table" then ns.db.auraDesign[A.kind] = nil end
        if ns.ApplyAuraDesign then pcall(ns.ApplyAuraDesign, ns) end
        A.Refresh()
    end)
    reset:SetPoint("TOPLEFT", 360, -190)
    A.note = Note(box, "", 0, -232)
    local hide = ns:CreateButton(box, "Auras hidden on every frame", 220, 24, function()
        ns:ToggleConfig("tools")
        if ns.toolsPage and ns.toolsPage.SetList then
            for i, def in ipairs(ns.toolLists) do if def.key == "auraBlock" then ns.toolsPage.SetList(i) end end
        end
    end)
    hide:SetPoint("TOPLEFT", 0, -290)
    A.hideButton = hide
    local UNIT = { A.show, A.max, A.size, A.side, A.grow }
    local RAID = { A.hots, A.debuff, A.dispel }
    local PLATE = { A.plateSize, A.plateMax }
    function A.Refresh()
        local d = D()
        for _, c in ipairs(UNIT) do c:Hide() end
        for _, c in ipairs(RAID) do c:Hide() end
        for _, c in ipairs(PLATE) do c:Hide() end
        A.mine:Hide()
        A.which.Draw()
        syncing = true
        if A.kind == "raid" then
            for _, c in ipairs(RAID) do c:Show() end
            A.hots:SetValue(d.hots or 3)
            A.debuff:SetChecked(d.debuff ~= false)
            A.dispel:SetChecked(d.dispel ~= false)
            A.note:SetText(ns:Tr("Your own heals over time sit in the corner of each player; the debuff icon shows the first debuff on them."))
        elseif A.kind == "plates" then
            for _, c in ipairs(PLATE) do c:Show() end
            A.mine:Show()
            A.mine:SetChecked(d.auraMine ~= false)
            A.plateSize:SetValue(d.auraSize or 18)
            A.plateMax:SetValue(d.auraMax or 5)
            A.note:SetText(ns:Tr("Debuffs on nameplates need \"Nameplate casts & debuffs\" on (Features tab)."))
        else
            for _, c in ipairs(UNIT) do c:Show() end
            A.mine:Show()
            A.mine:SetChecked(d.mine and true or false)
            A.max:SetValue(d.max or 8)
            A.size:SetValue(d.size or 22)
            A.show.Draw(); A.side.Draw(); A.grow.Draw()
            A.note:SetText(ns:Tr("Debuffs come first, then buffs. Point at an icon on the frame for what it is."))
        end
        syncing = false
        if ns.aurasLocked then
            A.note:SetText(A.note:GetText() .. "\n|cffffd100" .. ns:Tr("This game client hides buffs and debuffs from add-ons during fights: these show outside fights.") .. "|r")
        end
    end
    A.Refresh()
    ns.auraDesigner = A
    return A
end

------------------------------------------------------------------------------------------
-- Class resource designer (11.5): dots, a bar or a number; width, height, gap, number size.
------------------------------------------------------------------------------------------
function ns.BuildResourceDesigner(box)
    local R = {}
    local syncing = false
    local function Set(k, v)
        if type(ns.db.resourceDesign) ~= "table" then ns.db.resourceDesign = {} end
        ns.db.resourceDesign[k] = v
        if ns.ApplyResourceDesign then pcall(ns.ApplyResourceDesign) end
        R.changes = (R.changes or 0) + 1
    end
    local function D() return ns.ResourceDesign and ns.ResourceDesign() or {} end
    local title = box:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 15, true)
    title:SetPoint("TOPLEFT", 0, 0)
    ns:Paint(title, "SetTextColor", "@accent")
    title:SetText(ns:Tr("Class resource"))
    R.style = Cycler(box, 300, { { "dots", "Dots" }, { "bar", "One bar" }, { "number", "A number" } },
        function() return D().style end, function(v) Set("style", v) end, "Show as")
    R.style:SetPoint("TOPLEFT", 0, -32)
    local function Slider(label, lo, hi, x, y, key)
        local s = ns:CreateSlider(box, label, lo, hi, 1, lo, "%d", function(v) if not syncing then Set(key, v) end end, 300)
        s:SetPoint("TOPLEFT", x, y)
        return s
    end
    R.width = Slider("Width", 60, 400, 0, -74, "width")
    R.height = Slider("Height", 4, 40, 0, -114, "height")
    R.gap = Slider("Space between dots", 0, 12, 360, -74, "gap")
    R.font = Slider("Number size", 10, 36, 360, -114, "font")
    local reset = ns:CreateButton(box, "Back to how it came", 300, 24, function()
        ns.db.resourceDesign = nil
        if ns.ApplyResourceDesign then pcall(ns.ApplyResourceDesign) end
        R.Refresh()
    end)
    reset:SetPoint("TOPLEFT", 360, -32)
    R.note = Note(box, "", 0, -160)
    function R.Refresh()
        local d = D()
        syncing = true
        R.style.Draw()
        R.width:SetValue(d.width or 180); R.height:SetValue(d.height or 12)
        R.gap:SetValue(d.gap or 4); R.font:SetValue(d.font or 16)
        syncing = false
        local _, class = UnitClass("player")
        local has = ns.ClassResource and ns.ClassResource(class)
        R.note:SetText(ns:Tr(not ns.db.classResource and "Switch on \"Class resource\" on the Features tab to see it. Move it with move mode."
            or (has and "It moves with move mode like any panel." or "Your class has no second resource to show.")))
    end
    R.Refresh()
    return R
end
