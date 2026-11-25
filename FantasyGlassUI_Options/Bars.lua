-- Part of Fantasy Glass UI's options folder (see Config.lua): the Bars tab and the Guide tab.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

local function Heading(parent, text, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 14, true)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(ns:Tr(text))
    ns:Paint(fs, "SetTextColor", "@accent")
    ns:IndexOption(text, fs)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(ns.FLAT)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", x, y - 20)
    line:SetWidth(width or 240)
    ns:Paint(line, "SetVertexColor", "@border", 0.8)
    return fs
end
local function Small(parent, size, width)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, size or 11)
    fs:SetJustifyH("LEFT")
    if width then fs:SetWidth(width) end
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    return fs
end

------------------------------------------------------------------------------------------
-- Bars: every action bar has its own settings. The bars are listed down the left; the chosen one's
-- settings are on the right. What the add-on does itself (size, opacity, when the bar shows, its
-- key text and macro names) applies as you change it. Rows, buttons, button size, spacing and
-- direction belong to the game's Edit Mode and are written to it with "Apply to the bar".
------------------------------------------------------------------------------------------
function ns.BuildBarsPage(page)
    local T = {}
    ns.barsPage = T
    local bars = ns.barHandles
    T.sheet = page
    -- two halves on one sheet: a bar's settings, and (11.0) a unit frame's design; the list down the left
    -- names every bar, then every frame
    local box = CreateFrame("Frame", nil, page)
    box:SetPoint("TOPLEFT", 0, 0)
    box:SetSize(736, 540)
    local frameBox = CreateFrame("Frame", nil, page)
    frameBox:SetPoint("TOPLEFT", 0, 0)
    frameBox:SetSize(736, 540)
    frameBox:Hide()
    T.box, T.frameBox = box, frameBox
    local designer = ns.BuildFrameDesigner and ns.BuildFrameDesigner(frameBox) or nil
    T.designer = designer
    -- (11.0.1) the nameplate and raid frame designers, after the frames
    local plateBox = CreateFrame("Frame", nil, page)
    plateBox:SetPoint("TOPLEFT", 0, 0); plateBox:SetSize(736, 540); plateBox:Hide()
    local raidBox = CreateFrame("Frame", nil, page)
    raidBox:SetPoint("TOPLEFT", 0, 0); raidBox:SetSize(736, 540); raidBox:Hide()
    T.plates = ns.BuildPlateDesigner and ns.BuildPlateDesigner(plateBox) or nil
    T.raid = ns.BuildRaidDesigner and ns.BuildRaidDesigner(raidBox) or nil
    T.plateBox, T.raidBox = plateBox, raidBox
    local auraBox = CreateFrame("Frame", nil, page)
    auraBox:SetPoint("TOPLEFT", 0, 0); auraBox:SetSize(736, 540); auraBox:Hide()
    T.auras = ns.BuildAuraDesigner and ns.BuildAuraDesigner(auraBox) or nil
    T.auraBox = auraBox
    local resBox = CreateFrame("Frame", nil, page)
    resBox:SetPoint("TOPLEFT", 0, 0); resBox:SetSize(736, 540); resBox:Hide()
    T.resource = ns.BuildResourceDesigner and ns.BuildResourceDesigner(resBox) or nil
    T.resBox = resBox
    page.navItems = {}
    local nBars = (type(bars) == "table") and #bars or 0
    for i = 1, nBars do page.navItems[i] = { title = bars[i].label or bars[i].key } end
    local nFrames = designer and #designer.frames or 0   -- luacheck: ignore
    for j, def in ipairs(designer and designer.frames or {}) do page.navItems[nBars + j] = { title = def.label } end
    if T.plates then page.navItems[#page.navItems + 1] = { title = "Nameplates" } end
    if T.raid then page.navItems[#page.navItems + 1] = { title = "Raid frames" } end
    if T.auras then page.navItems[#page.navItems + 1] = { title = "Auras" } end
    if T.resource then page.navItems[#page.navItems + 1] = { title = "Class resource" } end
    local Show
    page.NavSelect = function(i)
        box:Hide(); frameBox:Hide(); plateBox:Hide(); raidBox:Hide(); auraBox:Hide(); resBox:Hide()
        if page.NavMark then page.NavMark(i) end
        local title = page.navItems[i] and page.navItems[i].title
        if title == "Nameplates" and T.plates then
            plateBox:Show(); T.showing = "plates"; T.plates.Refresh(); T.current = nil
            return
        elseif title == "Raid frames" and T.raid then
            raidBox:Show(); T.showing = "raid"; T.raid.Refresh(); T.current = nil
            return
        elseif title == "Auras" and T.auras then
            auraBox:Show(); T.showing = "auras"; T.auras.Refresh(); T.current = nil
            return
        elseif title == "Class resource" and T.resource then
            resBox:Show(); T.showing = "resource"; T.resource.Refresh(); T.current = nil
            return
        elseif i > nBars and designer then
            frameBox:Show(); T.showing = "frame"
            designer.Show(i - nBars)
            T.current = nil
            return
        end
        box:Show(); T.showing = "bar"
        if Show then Show(i) end
    end
    if nBars == 0 then
        local none = Small(box, 12, 700)
        none:SetPoint("TOPLEFT", 0, -10)
        none:SetText(ns:Tr("The action bars are not being looked after by this add-on: either \"Action bars\" is switched off, above, or another add-on has the bars."))
        T.empty = true
        page.contentHeight = 540
        if page.area then page.area:SetContentHeight(page.contentHeight) end
        if designer then page.NavSelect(1) end
        return T
    end
    local RX = 0
    local current = 1

    -- what the add-on does itself
    local title = box:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 15, true)
    title:SetPoint("TOPLEFT", RX, 0)
    ns:Paint(title, "SetTextColor", "@accent")
    local function Key() return bars[current].key end

    local showBtn
    local function DrawShow() showBtn.text:SetText(ns:Tr("Show") .. ":  " .. ns:Tr(ns.barShowNames[ns:BarSetting(Key(), "show")] or "Always")) end
    showBtn = ns:CreateButton(box, "", 250, 24, function(_, button)
        local modes, at = ns.barShowModes, 1
        for i, mode in ipairs(modes) do if mode == ns:BarSetting(Key(), "show") then at = i end end
        at = (button == "RightButton") and ((at - 2) % #modes + 1) or (at % #modes + 1)
        ns:SetBarSetting(Key(), "show", modes[at])
        DrawShow()
    end)
    showBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    showBtn:SetPoint("TOPLEFT", RX, -30)
    showBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns:Tr("When this bar shows"))
        GameTooltip:AddLine(ns:Tr("Click to step through: always, when pointed at, in combat, out of combat, with a target, never. A bar that is not showing is see-through, and its buttons can still be pressed where they were. Every bar shows while you move panels or hold a spell on the mouse."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    showBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    T.showButton = showBtn

    local sizeS = ns:CreateSlider(box, "Size %", 50, 150, 5, 100, "%d", function(v) ns:SetBarSetting(Key(), "scale", v) end, 250)
    sizeS:SetPoint("TOPLEFT", RX, -66)
    local alphaS = ns:CreateSlider(box, "Opacity %", 0, 100, 5, 100, "%d", function(v) ns:SetBarSetting(Key(), "alpha", v) end, 250)
    alphaS:SetPoint("TOPLEFT", RX, -106)
    local keyC = ns:CreateCheckbox(box, "Key text on this bar", true, function(v) ns:SetBarSetting(Key(), "hotkeys", v) end)
    keyC:SetPoint("TOPLEFT", RX, -150)
    local nameC = ns:CreateCheckbox(box, "Macro names on this bar", false, function(v) ns:SetBarSetting(Key(), "names", v) end)
    nameC:SetPoint("TOPLEFT", RX, -176)
    local reset = ns:CreateButton(box, "Back to how it came", 250, 22, function()
        if type(ns.db.bars) == "table" then ns.db.bars[Key()] = nil end
        if ns.db.barFade then ns.db.barFade[Key()] = nil end
        if ns.ApplyBarScale then ns:ApplyBarScale(true) end
        if ns.ApplyBarText then ns:ApplyBarText() end
        Show(current)
    end)
    reset:SetPoint("TOPLEFT", RX, -210)
    local tip = Small(box, 11, 250)
    tip:SetPoint("TOPLEFT", RX, -244)
    ns:Paint(tip, "SetTextColor", "faint")
    tip:SetText(ns:Tr("These apply as you change them. To move a bar, type /fgui move and drag it."))
    T.sizeSlider, T.alphaSlider, T.keyBox, T.nameBox = sizeS, alphaS, keyC, nameC
    -- the add-on's own bars can each be switched off altogether (11.0.1)
    local useC = ns:CreateCheckbox(box, "Use this bar", true, function(v)
        local info = bars[current]
        if info and info.engine then ns:SetEngineBarOn(info.engine, v) end
    end)
    useC:SetWidth(250)
    useC:SetPoint("TOPLEFT", RX, -280)
    T.useBox = useC

    -- what the game's Edit Mode does
    local LX = RX + 300
    Heading(box, "Rows and buttons", LX, 0, 266)
    local pending = {}
    local status = Small(box, 11, 266)
    local layoutS = {}
    for i, def in ipairs({ { "rows", "Rows", 1, 4, 1 }, { "icons", "Buttons shown", 6, 12, 1 }, { "size", "Button size %", 50, 200, 10 }, { "padding", "Space between buttons", 2, 10, 1 } }) do
        local s = ns:CreateSlider(box, def[2], def[3], def[4], def[5], def[3], "%d", function(v) pending[def[1]] = v end, 266)
        s:SetPoint("TOPLEFT", LX, -30 - (i - 1) * 40)
        layoutS[def[1]] = s
    end
    local dirBtn
    local function DrawDir() dirBtn.text:SetText(ns:Tr("Direction") .. ":  " .. ns:Tr((pending.vertical == 1) and "Down" or "Across")) end
    dirBtn = ns:CreateButton(box, "", 266, 22, function() pending.vertical = (pending.vertical == 1) and 0 or 1; DrawDir() end)
    dirBtn:SetPoint("TOPLEFT", LX, -192)
    local apply = ns:CreateButton(box, "Apply to the bar", 266, 24, function()
        local ok, why = ns:BarLayoutWrite(bars[current].bar, pending)
        if ok then status:SetText(ns:SignalHex("good") .. ns:Tr((why == "nothing to change") and "Nothing to change." or "Applied.") .. "|r")
        elseif why == "preset" then status:SetText("|cffffd100" .. ns:Tr(ns.PRESET_NOTE) .. "|r")
        else status:SetText(ns:SignalHex("bad") .. ns:Tr(tostring(why)) .. "|r") end
        T.lastApply = ok and true or false
    end)
    apply:SetPoint("TOPLEFT", LX, -222)
    status:SetPoint("TOPLEFT", LX, -254)
    ns:Paint(status, "SetTextColor", "faint")
    T.layoutSliders, T.pending, T.applyButton, T.status = layoutS, pending, apply, status

    Show = function(i)
        if not bars[i] then return end
        current = i
        T.current = i
        if page.NavMark then page.NavMark(i) end
        local info = bars[i]
        title:SetText(ns:Tr(info.label or info.key))
        DrawShow()
        sizeS:SetValue(ns:BarSetting(info.key, "scale"))
        alphaS:SetValue(ns:BarSetting(info.key, "alpha"))
        keyC:SetChecked(ns:BarSetting(info.key, "hotkeys"))
        if info.engine then useC:Show(); useC:SetChecked(ns:EngineBarOn(info.engine)) else useC:Hide() end
        nameC:SetChecked(ns:BarSetting(info.key, "names"))
        -- the Edit Mode half: only the eight action bars have it
        for k in pairs(pending) do pending[k] = nil end
        local layout, why
        if info.layout then layout, why = ns:BarLayoutRead(info.bar) else why = "none" end
        T.engine = info.engine
        local can = type(layout) == "table"
        for name, s in pairs(layoutS) do
            if can and layout[name] then pending[name] = layout[name]; s:SetValue(layout[name]) end
            s:SetAlpha(can and 1 or 0.35)
        end
        pending.vertical = can and (tonumber(layout.vertical) or 0) or 0
        DrawDir()
        dirBtn:SetAlpha(can and 1 or 0.35)
        apply:SetAlpha(can and 1 or 0.35)
        T.canLayout = can
        if can and info.engine then status:SetText(ns:Tr("One of the add-on's own bars: set these, then press Apply."))
        elseif can then status:SetText(ns:Tr("These five belong to the game's Edit Mode. Set them, then press Apply."))
        elseif why == "none" then status:SetText(ns:Tr("The stance and pet bars have no rows or spacing to set."))
        elseif why == "preset" then status:SetText("|cffffd100" .. ns:Tr(ns.PRESET_NOTE) .. "|r")
        else status:SetText(ns:Tr(tostring(why))) end
    end
    T.Show = Show
    page.Refresh = function()
        if T.showing == "plates" and T.plates then T.plates.Refresh()
        elseif T.showing == "raid" and T.raid then T.raid.Refresh()
        elseif T.showing == "auras" and T.auras then T.auras.Refresh()
        elseif T.showing == "resource" and T.resource then T.resource.Refresh()
        elseif T.showing == "frame" and designer then designer.Refresh()
        else Show(current) end
    end
    Show(1)
    page.contentHeight = 540
    if page.area then page.area:SetContentHeight(page.contentHeight) end
    return T
end

------------------------------------------------------------------------------------------
-- Batch 4's sections of the Guide tab, one per group. Each gets the live frame, the y its first
-- control goes at, Replan (plans again while following) and the page's table T; it returns the y
-- below its last control and a refresh function (run by page.Refresh while the guide is unlocked).
-- Each group writes only inside its own function's body.
------------------------------------------------------------------------------------------
-- Group A: the route and the hubs on the map.
local function FeelMapSection(live, y, Replan, T)
    local function Redraw() if ns.PlannerMapRedraw then ns.PlannerMapRedraw() end end
    local line = ns:CreateCheckbox(live, "The route on the map", ns.db.plannerMapLine ~= false, function(v)
        ns.db.plannerMapLine = v
        Redraw()
    end)
    line:SetPoint("TOPLEFT", 0, y)
    local hubs = ns:CreateCheckbox(live, "Hubs on the map", ns.db.plannerMapHubs ~= false, function(v)
        ns.db.plannerMapHubs = v
        Redraw()
    end)
    hubs:SetPoint("TOPLEFT", 0, y - 26)
    T.mapLineBox, T.mapHubsBox = line, hubs
    return y - 52, function()
        line:SetChecked(ns.db.plannerMapLine ~= false)
        hubs:SetChecked(ns.db.plannerMapHubs ~= false)
    end
end

-- Group B: time to level, "Why this?", the preview, finish the zone.
local function FeelPanelSection(live, y, Replan, T)
    local function Draw(b)
        local goal = ns.PlannerZoneGoal and ns.PlannerZoneGoal()
        if not goal then b.text:SetText(ns:Tr("Goal: Level up")) return end
        local name = ns.PlannerMapName and ns.PlannerMapName(goal) or tostring(goal)
        b.text:SetText(string.format(ns:Tr("Goal: Finish %s"), name))
    end
    -- Cycles between leveling and finishing the zone you are in (the planner plans again either way).
    local goal = ns:CreateButton(live, "", 250, 24, function(b)
        if ns.PlannerZoneGoal and ns.PlannerZoneGoal() then
            ns.PlannerSetZoneGoal(nil)
        elseif ns.PlannerGoalZone and ns.PlannerSetZoneGoal then
            local zone = ns.PlannerGoalZone()
            if zone then ns.PlannerSetZoneGoal(zone) end
        end
        Draw(b)
    end)
    goal:SetPoint("TOPLEFT", 0, y)
    T.zoneGoalButton = goal
    T.zoneGoalDraw = function() Draw(goal) end          -- (the goal can end by itself: "Zone done" redraws the label)
    return y - 34, T.zoneGoalDraw
end

-- Group C: the time you have, break reminders, catch me up, speed or story.
local function FeelPaceSection(live, y, Replan, T)
    local refreshes = {}
    -- The time you have and break reminders
    Heading(live, "How long you play", 0, y, 736)
    y = y - 30
    local times = ns.PLANNER_PLAY_TIMES or { { 0, "No limit" } }
    local function DrawTime(b)
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        local now, name = tonumber(rec and rec.playDefault) or 0, times[1][2]
        for _, t in ipairs(times) do if t[1] == now then name = t[2] end end
        b.text:SetText(ns:Tr("How long can you play") .. ":  " .. ns:Tr(name))
    end
    local timeButton = ns:CreateButton(live, "", 300, 24, function(b)
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        local now, at = tonumber(rec and rec.playDefault) or 0, 1
        for i, t in ipairs(times) do if t[1] == now then at = i end end
        rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
        if rec then rec.playDefault = times[at % #times + 1][1] end
        DrawTime(b)
    end)
    timeButton:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local how = Small(live, 11, 700)
    how:SetPoint("TOPLEFT", 0, y)
    ns:Paint(how, "SetTextColor", "faint")
    how:SetText(ns:Tr("Used by /fgui guide plan with no number. The plan then takes only what fits, and ends at a place to stop."))
    y = y - 30
    local breaks = ns:CreateCheckbox(live, "Remind me to take a break at a stopping place", ns.db.plannerBreaks == true, function(v) ns.db.plannerBreaks = v end)
    breaks:SetPoint("TOPLEFT", 0, y)
    y = y - 30
    local lengths = { { 60, "1 hour" }, { 90, "1 hour 30" }, { 120, "2 hours" }, { 180, "3 hours" } }
    local function DrawBreak(b)
        local now, name = tonumber(ns.db.plannerBreakMinutes) or 120, "2 hours"
        for _, t in ipairs(lengths) do if t[1] == now then name = t[2] end end
        b.text:SetText(ns:Tr("Break reminder after") .. ":  " .. ns:Tr(name))
    end
    local breakButton = ns:CreateButton(live, "", 300, 24, function(b)
        local now, at = tonumber(ns.db.plannerBreakMinutes) or 120, 3
        for i, t in ipairs(lengths) do if t[1] == now then at = i end end
        ns.db.plannerBreakMinutes = lengths[at % #lengths + 1][1]
        DrawBreak(b)
    end)
    breakButton:SetPoint("TOPLEFT", 0, y)
    y = y - 34
    T.playTimeButton, T.breaksBox, T.breakButton = timeButton, breaks, breakButton
    refreshes[#refreshes + 1] = function()
        DrawTime(timeButton)
        breaks:SetChecked(ns.db.plannerBreaks == true)
        DrawBreak(breakButton)
    end

    -- Speed or story: a style, and the three weights it sets (a slider moved makes it Custom)
    Heading(live, "Speed or story", 0, y, 736)
    y = y - 30
    local styles = { { "speed", "Speed" }, { "story", "Story" }, { "custom", "Custom" } }
    local function DrawStyle(b)
        local now, name = ns.PlannerStyle and ns.PlannerStyle() or "speed", "Speed"
        for _, st in ipairs(styles) do if st[1] == now then name = st[2] end end
        b.text:SetText(string.format(ns:Tr("Style: %s"), ns:Tr(name)))
    end
    local sliders, syncing = {}, false
    local function SyncSliders()
        if not ns.PlannerWeights then return end
        local sp, sa, st = ns.PlannerWeights()
        syncing = true
        sliders.speed:SetValue(sp); sliders.safety:SetValue(sa); sliders.story:SetValue(st)
        syncing = false
    end
    local styleButton = ns:CreateButton(live, "", 300, 24, function(b)
        local now, at = ns.PlannerStyle and ns.PlannerStyle() or "speed", 1
        for i, st in ipairs(styles) do if st[1] == now then at = i end end
        if ns.PlannerSetStyle then ns.PlannerSetStyle(styles[at % #styles + 1][1]) end
        DrawStyle(b)
        SyncSliders()
    end)
    styleButton:SetPoint("TOPLEFT", 0, y)
    y = y - 34
    for _, def in ipairs({ { "speed", "Speed" }, { "safety", "Safety" }, { "story", "Story" } }) do
        local slider = ns:CreateSlider(live, def[2], 0, 100, 10, def[1] == "speed" and 100 or 0, "%d", function(v)
            if syncing then return end
            if ns.PlannerSetWeight then ns.PlannerSetWeight(def[1], v) end
            DrawStyle(styleButton)
        end, 300)
        slider:SetPoint("TOPLEFT", 0, y)
        sliders[def[1]] = slider
        y = y - 40
    end
    local what = Small(live, 11, 700)
    what:SetPoint("TOPLEFT", 0, y)
    ns:Paint(what, "SetTextColor", "faint")
    what:SetText(ns:Tr("Speed picks the most experience for the time. Story prefers the zone's quest chains, and at 100 reaches back up to 10 levels for them. Safety avoids elites, escorts and places where you died."))
    y = y - 40
    T.styleButton, T.speedSlider, T.safetySlider, T.storySlider = styleButton, sliders.speed, sliders.safety, sliders.story
    refreshes[#refreshes + 1] = function()
        DrawStyle(styleButton)
        SyncSliders()
    end
    return y, function() for _, r in ipairs(refreshes) do r() end end
end

-- Group D: level times, race your best, where you left off, save as guide, read aloud.
local function FeelRecordsSection(live, y, Replan, T)
    local race = ns:CreateCheckbox(live, "Race your best", ns.db.plannerRace == true, function(v) ns.db.plannerRace = v end)
    race:SetPoint("TOPLEFT", 0, y)
    local leftOff = ns:CreateCheckbox(live, "Where you left off, at login", ns.db.plannerLeftOff ~= false, function(v) ns.db.plannerLeftOff = v end)
    leftOff:SetPoint("TOPLEFT", 0, y - 26)
    local speak = ns:CreateCheckbox(live, "Read the route aloud", ns.db.plannerSpeak ~= false, function(v) ns.db.plannerSpeak = v end)
    speak:SetPoint("TOPLEFT", 0, y - 52)
    local hint = Small(live, 11, 440)                         -- (reading aloud is one switch in Accessibility; this one only narrows it)
    hint:SetPoint("LEFT", speak, "RIGHT", 12, 0)
    ns:Paint(hint, "SetTextColor", "dim")
    hint:SetText(ns:Tr("Needs reading aloud on in Accessibility"))
    T.raceBox, T.leftOffBox, T.speakBox = race, leftOff, speak
    local function Refresh()
        race:SetChecked(ns.db.plannerRace == true)
        leftOff:SetChecked(ns.db.plannerLeftOff ~= false)
        speak:SetChecked(ns.db.plannerSpeak ~= false)
        local on = ns.db.readDialog and true or false      -- (greyed with the hint while reading aloud is off)
        speak:SetAlpha(on and 1 or 0.45)
        hint:SetShown(not on)
    end
    Refresh()                                              -- (right from the start, not only after the first page refresh)
    return y - 78, Refresh
end

-- Batch 5's sections of the Guide tab, one per group, called the same way as batch 4's (after them).
-- Each group writes only inside its own function's body.
-- Group A: find a group for a group quest.
local function TogetherGroupSection(live, y, Replan, T)
    local find = ns:CreateCheckbox(live, "Find a group button", ns.db.plannerFindGroup ~= false, function(v)
        ns.db.plannerFindGroup = v
        if ns.GuideRedraw then ns:GuideRedraw() end
    end)
    find:SetPoint("TOPLEFT", 0, y)
    local function DrawChannel(b)
        local name = ns.db.plannerLFGChannel
        if type(name) ~= "string" or name == "" then name = ns:Tr("Chat box") end
        b.text:SetText(format(ns:Tr("Find a group in: %s"), name))
    end
    local channel = ns:CreateButton(live, "", 300, 24, function(b)
        local list = { "" }
        for _, name in ipairs(ns.PlannerLFGChannels and ns.PlannerLFGChannels() or {}) do list[#list + 1] = name end
        local at = 1
        for i, name in ipairs(list) do if name == (ns.db.plannerLFGChannel or "") then at = i end end
        ns.db.plannerLFGChannel = list[at % #list + 1]
        DrawChannel(b)
    end)
    channel:SetPoint("TOPLEFT", 0, y - 28)
    T.findGroupBox, T.findGroupChannel = find, channel
    return y - 58, function()
        find:SetChecked(ns.db.plannerFindGroup ~= false)
        DrawChannel(channel)
    end
end

-- Group B: plan with a friend (the duo).
local function TogetherDuoSection(live, y, Replan, T)
    return y, function() end
end

-- Group C: the plan code for the website's plan page.
local function TogetherCodeSection(live, y, Replan, T)
    return y, function() end
end

------------------------------------------------------------------------------------------
-- Guide: quest guides are not released yet. Everyone sees "coming soon"; where they have been
-- unlocked (see Guide.lua) this tab holds their switch and controls instead.
------------------------------------------------------------------------------------------
function ns.BuildGuidePage(page)
    local T = {}
    ns.guidePage = T
    local soon = CreateFrame("Frame", nil, page)
    soon:SetPoint("TOPLEFT", 0, 0)
    soon:SetSize(736, 400)
    local big = soon:CreateFontString(nil, "OVERLAY")
    ns:Font(big, 30, true)
    big:SetPoint("TOP", 0, -120)
    big:SetText(ns:Tr("Coming soon"))
    ns:Paint(big, "SetTextColor", "@accent")
    local what = Small(soon, 13, 520)
    what:SetPoint("TOP", big, "BOTTOM", 0, -16)
    what:SetJustifyH("CENTER")
    ns:Paint(what, "SetTextColor", "dim")
    what:SetText(ns:Tr("A quest guide is on its way: routes you follow one step at a time, with a panel for the step you are on and an arrow that points to it."))
    T.soon = soon
    page.navItems = { { title = "Quest guide" } }            -- (one section: no list to choose from)
    page.NavSelect = function() end

    local live = CreateFrame("Frame", nil, page)
    live:SetPoint("TOPLEFT", 0, 0)
    local LIVE_HEIGHT                       -- (set below the last section)
    live:SetSize(736, 896)
    T.live = live
    Heading(live, "Quest guides", 0, 0, 736)
    local status = Small(live, 12, 700)
    status:SetPoint("TOPLEFT", 0, -30)
    local on = ns:CreateCheckbox(live, "Quest guides", ns.db.questGuide ~= false, function(v)
        ns.db.questGuide = v
        if ns.GuideApplySwitch then ns:GuideApplySwitch() end
        page.Refresh()
    end)
    on:SetPoint("TOPLEFT", 0, -62)
    local sound = ns:CreateCheckbox(live, "A sound when a step is done", ns.db.guideSound ~= false, function(v) ns.db.guideSound = v end)
    sound:SetPoint("TOPLEFT", 0, -88)
    local list = ns:CreateButton(live, "Your guides", 170, 24, function() if ns.HideConfig then ns.HideConfig() end; ns:GuideList() end)
    list:SetPoint("TOPLEFT", 0, -126)
    local write = ns:CreateButton(live, "Write or paste a guide", 170, 24, function() if ns.HideConfig then ns.HideConfig() end; ns:GuideEdit("") end)
    write:SetPoint("LEFT", list, "RIGHT", 8, 0)
    local route = ns:CreateButton(live, "Edit the route", 170, 24, function()
        if ns.HideConfig then ns.HideConfig() end
        if ns.GuideRouteEditor then ns:GuideRouteEditor() end
    end)
    route:SetPoint("LEFT", write, "RIGHT", 8, 0)
    T.routeButton = route
    Heading(live, "Record a guide as you play", 0, -170, 736)
    local name = ns:CreateEditBox(live, 240, 24, "a name for the guide")
    name:SetPoint("TOPLEFT", 0, -200)
    local recBtn
    recBtn = ns:CreateButton(live, "", 170, 24, function()
        if ns.guideRecording then ns:GuideRecordStop() else ns:GuideRecord(name:GetText()) end
        page.Refresh()
    end)
    recBtn:SetPoint("LEFT", name, "RIGHT", 8, 0)
    local how = Small(live, 11, 700)
    how:SetPoint("TOPLEFT", 0, -236)
    ns:Paint(how, "SetTextColor", "faint")
    how:SetText(ns:Tr("While recording, every quest you accept, finish and hand in becomes a step, with where you stood and who you spoke to. In chat: /fgui guide (your guides), /fgui guide record <name>, stop, edit <name>, next, back, off."))
    T.onBox, T.recordButton, T.nameBox = on, recBtn, name

    -- The route planner: a button, and what it takes into account. Changing a setting plans again, if it is running.
    Heading(live, "Plan my route", 0, -270, 736)
    local function Replan() if ns.PlannerReplan then ns:PlannerReplan("settings") end end
    local plan = ns:CreateButton(live, "Plan my route", 170, 24, function() if ns.PlannerStart then ns:PlannerStart() end; page.Refresh() end)
    plan:SetPoint("TOPLEFT", 0, -300)
    local groups = { { "solo", "Solo" }, { "grouped", "When grouped" }, { "all", "Everything" } }
    local function DrawGroup(b)
        local now, name = ns.db.plannerGroup or "solo", nil
        for _, g in ipairs(groups) do if g[1] == now then name = g[2] end end
        b.text:SetText(ns:Tr("Group quests") .. ":  " .. ns:Tr(name or "Solo"))
    end
    local group = ns:CreateButton(live, "", 250, 24, function(b)
        local now, at = ns.db.plannerGroup or "solo", 1
        for i, g in ipairs(groups) do if g[1] == now then at = i end end
        ns.db.plannerGroup = groups[at % #groups + 1][1]
        DrawGroup(b)
        Replan()
    end)
    group:SetPoint("LEFT", plan, "RIGHT", 8, 0)
    local flights = ns:CreateCheckbox(live, "Learn new flight points on the way", ns.db.plannerLearnFlights ~= false, function(v)
        ns.db.plannerLearnFlights = v
        Replan()
    end)
    flights:SetPoint("TOPLEFT", 0, -334)
    local why = ns:CreateCheckbox(live, "Show why each step is there", ns.db.plannerWhy ~= false, function(v)
        ns.db.plannerWhy = v
        Replan()
    end)
    why:SetPoint("TOPLEFT", 0, -360)
    local trainer = ns:CreateCheckbox(live, "Visit your trainer on the way", ns.db.plannerTrainer ~= false, function(v)
        ns.db.plannerTrainer = v
        Replan()
    end)
    trainer:SetPoint("TOPLEFT", 0, -386)
    local hold = ns:CreateCheckbox(live, "Save hand-ins to level in town", ns.db.plannerHold ~= false, function(v)
        ns.db.plannerHold = v
        Replan()
    end)
    hold:SetPoint("TOPLEFT", 0, -412)
    local vendor = ns:CreateCheckbox(live, "Sell and repair stops", ns.db.plannerVendor ~= false, function(v)
        ns.db.plannerVendor = v
        Replan()
    end)
    vendor:SetPoint("TOPLEFT", 0, -438)
    local supplies = ns:CreateCheckbox(live, "Buy supplies at the vendor stop", ns.db.plannerSupplies ~= false, function(v)
        ns.db.plannerSupplies = v
        Replan()
    end)
    supplies:SetPoint("TOPLEFT", 0, -464)
    local profession = ns:CreateCheckbox(live, "Profession training stops", ns.db.plannerProfession ~= false, function(v)
        ns.db.plannerProfession = v
        Replan()
    end)
    profession:SetPoint("TOPLEFT", 0, -490)
    local mount = ns:CreateCheckbox(live, "Mount reminder", ns.db.plannerMount ~= false, function(v)
        ns.db.plannerMount = v
        Replan()
    end)
    mount:SetPoint("TOPLEFT", 0, -516)
    local mail = ns:CreateCheckbox(live, "Mail stops", ns.db.plannerMail ~= false, function(v)
        ns.db.plannerMail = v
        Replan()
    end)
    mail:SetPoint("TOPLEFT", 0, -542)
    local explore = ns:CreateCheckbox(live, "Explore on the way", ns.db.plannerExplore ~= false, function(v)
        ns.db.plannerExplore = v
        Replan()
    end)
    explore:SetPoint("TOPLEFT", 0, -568)
    local gather = ns:CreateCheckbox(live, "Gather on the way", ns.db.plannerGather ~= false, function(v)
        ns.db.plannerGather = v
        Replan()
    end)
    gather:SetPoint("TOPLEFT", 0, -594)
    local rested = ns:CreateCheckbox(live, "Count rested experience", ns.db.plannerRested ~= false, function(v)
        ns.db.plannerRested = v
        Replan()
    end)
    rested:SetPoint("TOPLEFT", 0, -620)
    local rewards = ns:CreateCheckbox(live, "Count upgrades in rewards", ns.db.plannerRewards ~= false, function(v)
        ns.db.plannerRewards = v
        Replan()
    end)
    rewards:SetPoint("TOPLEFT", 0, -646)
    local repButton = ns:CreateButton(live, "Reputation I want", 170, 24, function() if ns.GuideReputation then ns:GuideReputation() end end)
    repButton:SetPoint("TOPLEFT", 0, -676)
    local skipButton = ns:CreateButton(live, "Quests you skipped", 170, 24, function() if ns.GuideSkipped then ns:GuideSkipped() end end)
    skipButton:SetPoint("TOPLEFT", 180, -676)
    local deaths = ns:CreateCheckbox(live, "Learn from my deaths", ns.db.plannerDeaths ~= false, function(v)
        ns.db.plannerDeaths = v
        Replan()
    end)
    deaths:SetPoint("TOPLEFT", 0, -706)
    local soloElites = ns:CreateCheckbox(live, "Include elites my class has soloed", ns.db.plannerSoloElites ~= false, function(v)
        ns.db.plannerSoloElites = v
        Replan()
    end)
    soloElites:SetPoint("TOPLEFT", 0, -732)
    local classQuests = ns:CreateCheckbox(live, "Plan class quests", ns.db.plannerClassQuests ~= false, function(v)
        ns.db.plannerClassQuests = v
        Replan()
    end)
    classQuests:SetPoint("TOPLEFT", 0, -758)
    T.classQuestsBox = classQuests
    local pick = ns:CreateCheckbox(live, "Pick the best quest reward", ns.db.plannerPickReward ~= false, function(v) ns.db.plannerPickReward = v end)
    pick:SetPoint("TOPLEFT", 0, -784)
    local logAdvice = ns:CreateCheckbox(live, "Quest log advice", ns.db.plannerLogAdvice ~= false, function(v)
        ns.db.plannerLogAdvice = v
        if ns.GuideShowPanel and ns.GuidePanelShown and ns:GuidePanelShown() then ns:GuideShowPanel() end
    end)
    logAdvice:SetPoint("TOPLEFT", 0, -810)
    local inn = ns:CreateCheckbox(live, "Suggest an inn when you stop", ns.db.plannerInn ~= false, function(v) ns.db.plannerInn = v end)
    inn:SetPoint("TOPLEFT", 0, -836)
    local dry = ns:CreateCheckbox(live, "Suggest what to do when quests run dry", ns.db.plannerDry ~= false, function(v)
        ns.db.plannerDry = v
        Replan()
    end)
    dry:SetPoint("TOPLEFT", 0, -862)
    T.pickBox, T.logAdviceBox, T.innBox, T.dryBox = pick, logAdvice, inn, dry
    T.deathsBox, T.soloElitesBox, T.skippedButton = deaths, soloElites, skipButton
    T.restedBox, T.rewardsBox, T.reputationButton = rested, rewards, repButton
    T.planButton, T.groupButton, T.flightsBox, T.whyBox, T.trainerBox, T.holdBox = plan, group, flights, why, trainer, hold
    T.vendorBox, T.suppliesBox, T.professionBox, T.mountBox = vendor, supplies, profession, mount
    T.mailBox, T.exploreBox, T.gatherBox = mail, explore, gather

    -- batch 4's sections, then batch 5's, in this order, from below the last box
    local y, refreshes = -892, {}
    for _, section in ipairs({ FeelMapSection, FeelPanelSection, FeelPaceSection, FeelRecordsSection, TogetherGroupSection, TogetherDuoSection, TogetherCodeSection }) do
        local nextY, refresh = section(live, y, Replan, T)
        y = tonumber(nextY) or y
        if type(refresh) == "function" then refreshes[#refreshes + 1] = refresh end
    end
    LIVE_HEIGHT = -y + 4
    live:SetSize(736, LIVE_HEIGHT)

    page.Refresh = function()
        local open = ns.GuideUnlocked and ns:GuideUnlocked()
        T.unlocked = open and true or false
        if open then soon:Hide(); live:Show() else live:Hide(); soon:Show() return end
        on:SetChecked(ns.db.questGuide ~= false)
        sound:SetChecked(ns.db.guideSound ~= false)
        flights:SetChecked(ns.db.plannerLearnFlights ~= false)
        why:SetChecked(ns.db.plannerWhy ~= false)
        trainer:SetChecked(ns.db.plannerTrainer ~= false)
        hold:SetChecked(ns.db.plannerHold ~= false)
        vendor:SetChecked(ns.db.plannerVendor ~= false)
        supplies:SetChecked(ns.db.plannerSupplies ~= false)
        profession:SetChecked(ns.db.plannerProfession ~= false)
        mount:SetChecked(ns.db.plannerMount ~= false)
        mail:SetChecked(ns.db.plannerMail ~= false)
        explore:SetChecked(ns.db.plannerExplore ~= false)
        gather:SetChecked(ns.db.plannerGather ~= false)
        rested:SetChecked(ns.db.plannerRested ~= false)
        rewards:SetChecked(ns.db.plannerRewards ~= false)
        deaths:SetChecked(ns.db.plannerDeaths ~= false)
        soloElites:SetChecked(ns.db.plannerSoloElites ~= false)
        classQuests:SetChecked(ns.db.plannerClassQuests ~= false)
        pick:SetChecked(ns.db.plannerPickReward ~= false)
        logAdvice:SetChecked(ns.db.plannerLogAdvice ~= false)
        inn:SetChecked(ns.db.plannerInn ~= false)
        dry:SetChecked(ns.db.plannerDry ~= false)
        DrawGroup(group)
        recBtn.text:SetText(ns:Tr(ns.guideRecording and "Stop recording" or "Record"))
        local st = ns.GuideState and ns.GuideState()
        if ns.guideRecording then status:SetText(ns:SignalHex("bad") .. ns:Tr("Recording") .. ":|r " .. tostring(ns.guideRecording.name) .. "  (" .. #ns.guideRecording.steps .. ")")
        elseif st then status:SetText(ns:Tr("Following") .. ": " .. ns:AccentHex() .. tostring(st.name) .. "|r  -  " .. tostring(st.at))
        else status:SetText(ns:Tr("You are not following a guide.")) end
        for _, refresh in ipairs(refreshes) do refresh() end
    end
    page.Refresh()
    page.contentHeight = LIVE_HEIGHT
    if page.area then page.area:SetContentHeight(page.contentHeight) end
    return T
end
