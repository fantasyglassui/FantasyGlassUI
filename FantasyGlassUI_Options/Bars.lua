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
-- (12.3, polish) The Guide tab is laid out as the other sections are (FeaturesPage.lua): section labels
-- (O.Header: 13, secondary, upper-case in English only), and under each a group of rows, one setting
-- to a row with its name, what it does in 13 secondary lettering, and its switch at the right (or its
-- button or slider at the left, with what it does beside it). Rows grow with their text, so nothing
-- runs into what comes next at any text size.
local function GuideHeading(parent, text, x, y)
    local O = ns.optUI
    if O and O.Header then return O.Header(parent, text, x, y) end
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 13, true)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(ns:Tr(text))
    ns:Paint(fs, "SetTextColor", "dim")
    ns:IndexOption(text, fs)
    return fs
end
-- A row's switch: the settings window's switch, its own label hidden (the row's title is the label).
local function GuideSwitch(parent, label, checked, onChange)
    local c = ns:CreateCheckbox(parent, label, checked, onChange)
    c:SetWidth(c.suiSwitch and 38 or 36)
    c.label:Hide()
    return c
end
local ROW_PAD, ROW_MIN, ROW_BUTTON, ROW_SLIDER = 16, 58, 58, 66
-- the height a text takes: what the game says, or an estimate where it cannot yet (before it is drawn)
local function TextH(fs, size, width)
    local h = fs.GetStringHeight and fs:GetStringHeight()
    if type(h) == "number" and h > 0 and not ns:IsSecret(h) then return h end
    local scale = ns.fontScale or 1
    local text = fs.GetText and fs:GetText()
    local chars = (type(text) == "string") and #text or 0
    local lines = math.max(1, math.ceil(chars * 0.5 * size * scale / math.max(80, width)))
    return lines * size * scale * 1.25
end
-- The accent as lettering on the settings window's card: lighter where the accent is too dark to read
-- (4.5:1 at the least).
local function Lum(r, g, b)
    local function c(v) return (v <= 0.03928) and (v / 12.92) or (((v + 0.055) / 1.055) ^ 2.4) end
    return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b)
end
local function AccentTextHex(obj)
    local r, g, b = ns:Role("@accent", nil, obj)
    local br, bg, bb = ns:Role("card", nil, obj)
    r, g, b, br, bg, bb = tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1, tonumber(br) or 0, tonumber(bg) or 0, tonumber(bb) or 0
    local back = Lum(br, bg, bb)
    for _ = 1, 20 do
        local l = Lum(r, g, b)
        if (math.max(l, back) + 0.05) / (math.min(l, back) + 0.05) >= 4.5 then break end
        r, g, b = r + (1 - r) * 0.15, g + (1 - g) * 0.15, b + (1 - b) * 0.15
    end
    return format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- The rows. G is the tab's list of them (T.rows): each row is in one of the sections below, and the
-- tab lays them out section by section in this order, whichever function made them.
local GUIDE_SECTIONS = {
    { "guides", "Quest guides" }, { "record", "Record a guide as you play" }, { "plan", "Plan my route" },
    { "include", "What the route includes" }, { "advice", "Advice along the way" }, { "map", "On the map" },
    { "pace", "How long you play" }, { "style", "Speed or story" }, { "records", "Your records" },
    { "together", "With other players" },
}
local function RowTip(row)
    if not row.tipTitle then return end
    GameTooltip:SetOwner(row, "ANCHOR_NONE")
    GameTooltip:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 4)
    GameTooltip:AddLine(ns:Tr(row.tipTitle))
    local desc = row.desc and row.desc:GetText()
    if type(desc) == "string" and desc ~= "" then GameTooltip:AddLine(desc, 1, 1, 1, true) end
    GameTooltip:Show()
end
local function Hover(row, control)                         -- (a control in a row lights the row, and explains it unless it has its own tip)
    control:HookScript("OnEnter", function(self)
        row.wash:Show()
        if not rawget(self, "suiTipShown") then RowTip(row) end
    end)
    control:HookScript("OnLeave", function() row.wash:Hide(); GameTooltip:Hide() end)
end
local function NewRow(G, sec, h, title)
    local row = CreateFrame("Button", nil, G.live)
    row:SetHeight(h)
    row.sec, row.tipTitle = sec, title or false
    -- (what a row may have, none yet: the settings window's keys look for these on a row)
    row.switch, row.button, row.slider, row.scaled, row.navKey, row.desc, row.title, row.text, row.Sync = false, false, false, false, false, false, false, false, false
    row.wash = row:CreateTexture(nil, "BACKGROUND")
    row.wash:SetAllPoints()
    row.wash:SetTexture(ns.FLAT)
    ns:Paint(row.wash, "SetVertexColor", "select", 1)
    row.wash:Hide()
    row.line = row:CreateTexture(nil, "BORDER")            -- (a rule between rows)
    row.line:SetTexture(ns.FLAT)
    row.line:SetHeight(1)
    row.line:SetPoint("TOPLEFT", ROW_PAD, 0)
    row.line:SetPoint("TOPRIGHT", -ROW_PAD, 0)
    ns:Paint(row.line, "SetVertexColor", "rule", 1)
    row:SetScript("OnEnter", function(self) self.wash:Show(); RowTip(self) end)
    row:SetScript("OnLeave", function(self) self.wash:Hide(); GameTooltip:Hide() end)
    row.Layout = function() return h end
    G.list[#G.list + 1] = row
    row.seq = #G.list                                      -- (its place within its section)
    return row
end
local function Desc(row, text)
    local fs = row:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 13)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    ns:Paint(fs, "SetTextColor", "dim")
    fs:SetText(ns:Tr(text or ""))
    row.desc = fs
    return fs
end
local function Words(control, title, desc)
    control.words = strlower(ns:Tr(title or "") .. " " .. ns:Tr(desc or ""))
end
-- A switch: its name and what it does, the switch at the right; a click anywhere on the row switches it.
local function SwitchRow(G, sec, key, label, desc, get, onChange)
    local row = NewRow(G, sec, ROW_MIN, label)
    row.title = row:CreateFontString(nil, "OVERLAY")
    ns:Font(row.title, 14)
    row.title:SetPoint("TOPLEFT", ROW_PAD, -14)
    row.title:SetJustifyH("LEFT")
    if row.title.SetWordWrap then row.title:SetWordWrap(false) end
    ns:Paint(row.title, "SetTextColor", "text")
    row.title:SetText(ns:Tr(label))
    Desc(row, desc)
    local c = GuideSwitch(row, label, get(), onChange)
    c:ClearAllPoints()
    c:SetPoint("RIGHT", row, "RIGHT", -ROW_PAD, 0)
    c.row, c.key = row, key
    row.switch, row.navKey = c, key
    row:SetScript("OnClick", function() c:Click() end)
    Hover(row, c)
    row.Sync = function() c:SetChecked(get()) end
    row.Layout = function(w)
        local tw = math.max(120, w - ROW_PAD - (ROW_PAD + 38 + ROW_PAD))
        row.title:SetWidth(tw)
        row.desc:SetWidth(tw)
        local th = TextH(row.title, 14, tw)
        local text = row.desc:GetText()
        local dh = (type(text) == "string" and text ~= "") and TextH(row.desc, 13, tw) or 0
        row.desc:ClearAllPoints()
        row.desc:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD, -(14 + th + 4))
        return math.max(ROW_MIN, math.ceil(14 + th + ((dh > 0) and (4 + dh) or 0) + 14))
    end
    Words(c, label, desc)
    return c
end
-- A button (one that does something, or steps through choices): the button at the left, what it does at its right.
local function ButtonRow(G, sec, label, desc, onClick, cycle)
    local row = NewRow(G, sec, ROW_BUTTON, label)
    local b = ns:CreateButton(row, label:find("%s", 1, true) and "" or label, 290, 24, onClick)   -- (a label with a value in it is set when drawn)
    b:SetPoint("TOPLEFT", ROW_PAD, -17)
    if cycle then b:RegisterForClicks("LeftButtonUp", "RightButtonUp") end      -- (a right-click steps back)
    b.row = row
    row.button, row.navKey = b, "guide:" .. label
    row.suiNoStep = not cycle or nil                         -- (an action row: Left and Right do nothing, only Space and Enter press it)
    Hover(row, b)
    local fs = Desc(row, desc)
    fs:SetPoint("TOPLEFT", 332, -19)
    row.Layout = function(w)
        local dw = math.max(120, w - 332 - ROW_PAD)
        fs:SetWidth(dw)
        return math.max(ROW_BUTTON, math.ceil(19 + TextH(fs, 13, dw) + 14))
    end
    Words(b, label, desc)
    return b
end
-- A slider at the left, what it does at its right. Left and Right (with the keyboard) move it a step.
local function SliderRow(G, sec, label, desc, minV, maxV, step, value, onChange)
    local row = NewRow(G, sec, ROW_SLIDER, label)
    local s = ns:CreateSlider(row, label, minV, maxV, step, value, "%d", onChange, 300)
    s:SetPoint("TOPLEFT", ROW_PAD, -12)
    s.row = row
    if s.slider then Hover(row, s.slider) end
    row.scaled, row.navKey = s.slider, "guide:" .. label
    row.button = { GetScript = function()                    -- (what the settings window's keys press on a row)
        return function(_, button)
            local v = tonumber(s.slider and s.slider.GetValue and s.slider:GetValue()) or minV
            s:SetValue(math.max(minV, math.min(maxV, v + ((button == "RightButton") and -step or step))))
        end
    end }
    local fs = Desc(row, desc)
    fs:SetPoint("TOPLEFT", 352, -14)
    row.Layout = function(w)
        local dw = math.max(120, w - 352 - ROW_PAD)
        fs:SetWidth(dw)
        return math.max(ROW_SLIDER, math.ceil(14 + TextH(fs, 13, dw) + 14))
    end
    Words(s, label, desc)
    return s
end
-- A line of text alone (what the guide is doing now).
local function TextRow(G, sec, size)
    local row = NewRow(G, sec, 40)
    local fs = row:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, size or 13)
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    ns:Paint(fs, "SetTextColor", "text")
    fs:SetPoint("TOPLEFT", ROW_PAD, -12)
    row:EnableMouse(false)
    row.Layout = function(w)
        local tw = math.max(120, w - 2 * ROW_PAD)
        fs:SetWidth(tw)
        return math.max(40, math.ceil(12 + TextH(fs, size or 13, tw) + 12))
    end
    row.text = fs
    return fs, row
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
-- Batch 4's sections of the Guide tab, one per group. Each gets the live frame, the y it was given,
-- Replan (plans again while following) and the page's table T; it adds its rows to T.rows (each in
-- one of GUIDE_SECTIONS, laid out in that order) and returns the y and a refresh function (run by
-- page.Refresh while the guide is unlocked). Each group writes only inside its own function's body.
------------------------------------------------------------------------------------------
-- Group A: the route and the quest areas on the map.
local function FeelMapSection(live, y, Replan, T)
    local G = T.rows
    local function Redraw() if ns.PlannerMapRedraw then ns.PlannerMapRedraw() end end
    local line = SwitchRow(G, "map", "plannerMapLine", "The route on the map", "The route's stops, numbered, and the line between them on the world map.",
        function() return ns.db.plannerMapLine ~= false end, function(v)
        ns.db.plannerMapLine = v
        Redraw()
    end)
    local hubs = SwitchRow(G, "map", "plannerMapHubs", "Quest areas on the map", "A mark on each area with quests the planner found, brighter where the experience comes faster.",
        function() return ns.db.plannerMapHubs ~= false end, function(v)
        ns.db.plannerMapHubs = v
        Redraw()
    end)
    local tomtom = SwitchRow(G, "map", "plannerTomTom", "Use TomTom's arrow when TomTom is loaded", "The step you are on goes to TomTom's arrow instead of this add-on's.",
        function() return ns.db.plannerTomTom ~= false end, function(v)
        ns.db.plannerTomTom = v
        if ns.GuideAdvance then ns:GuideAdvance() end
    end)
    T.mapLineBox, T.mapHubsBox, T.tomTomBox = line, hubs, tomtom
    return y, function()
        tomtom:SetChecked(ns.db.plannerTomTom ~= false)
        line:SetChecked(ns.db.plannerMapLine ~= false)
        hubs:SetChecked(ns.db.plannerMapHubs ~= false)
    end
end

-- Group B: time to level, "Why this?", the preview, finish the zone.
local function FeelPanelSection(live, y, Replan, T)
    local G = T.rows
    local function Draw(b)
        local goal = ns.PlannerZoneGoal and ns.PlannerZoneGoal()
        if not goal then b.text:SetText(ns:Tr("Goal: Level up")) return end
        local name = ns.PlannerMapName and ns.PlannerMapName(goal) or tostring(goal)
        b.text:SetText(string.format(ns:Tr("Goal: Finish %s"), name))
    end
    -- Switches between leveling and finishing the zone you are in (the planner plans again either way).
    local goal = ButtonRow(G, "plan", "", "Level up plans the most experience wherever it is. Finish the zone plans every quest left in the zone you are in, then goes back to levelling.", function(b)
        if ns.PlannerZoneGoal and ns.PlannerZoneGoal() then
            ns.PlannerSetZoneGoal(nil)
        elseif ns.PlannerGoalZone and ns.PlannerSetZoneGoal then
            local zone = ns.PlannerGoalZone()
            if zone then ns.PlannerSetZoneGoal(zone) end
        end
        Draw(b)
    end, true)
    goal.row.tipTitle, goal.row.navKey = "Goal: Level up", "guide:goal"
    if T.groupButton and T.groupButton.row then goal.row.seq = T.groupButton.row.seq + 0.5 end   -- (under Group quests)
    T.zoneGoalButton = goal
    T.zoneGoalDraw = function() Draw(goal) end          -- (the goal can end by itself: "Zone done" redraws the label)
    return y, T.zoneGoalDraw
end

-- Group C: the time you have, break reminders, catch me up, speed or story.
local function FeelPaceSection(live, y, Replan, T)
    local G = T.rows
    local refreshes = {}
    -- The time you have and break reminders
    local times = ns.PLANNER_PLAY_TIMES or { { 0, "No limit" } }
    local function DrawTime(b)
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        local now, name = tonumber(rec and rec.playDefault) or 0, times[1][2]
        for _, t in ipairs(times) do if t[1] == now then name = t[2] end end
        b.text:SetText(ns:Tr("How long can you play?") .. "  " .. ns:Tr(name))
    end
    local timeButton = ButtonRow(G, "pace", "How long can you play?", "Plan my route then takes only what fits in this time, and ends at a good place to stop. /fgui guide plan with no number does the same.", function(b, button)
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        local now, at = tonumber(rec and rec.playDefault) or 0, 1
        for i, t in ipairs(times) do if t[1] == now then at = i end end
        rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
        at = (button == "RightButton") and ((at - 2) % #times + 1) or (at % #times + 1)
        if rec then rec.playDefault = times[at][1] end
        DrawTime(b)
    end, true)
    local breaks = SwitchRow(G, "pace", "plannerBreaks", "Remind me to take a break at a stopping place", "After a long stretch of play, the panel says so when you reach a good place to stop.",
        function() return ns.db.plannerBreaks == true end, function(v) ns.db.plannerBreaks = v end)
    local lengths = { { 60, "1 hour" }, { 90, "1 hour 30" }, { 120, "2 hours" }, { 180, "3 hours" } }
    local function DrawBreak(b)
        local now, name = tonumber(ns.db.plannerBreakMinutes) or 120, "2 hours"
        for _, t in ipairs(lengths) do if t[1] == now then name = t[2] end end
        b.text:SetText(ns:Tr("Break reminder after") .. ":  " .. ns:Tr(name))
    end
    local breakButton = ButtonRow(G, "pace", "Break reminder after", "How long that stretch of play is.", function(b, button)
        local now, at = tonumber(ns.db.plannerBreakMinutes) or 120, 3
        for i, t in ipairs(lengths) do if t[1] == now then at = i end end
        at = (button == "RightButton") and ((at - 2) % #lengths + 1) or (at % #lengths + 1)
        ns.db.plannerBreakMinutes = lengths[at][1]
        DrawBreak(b)
    end, true)
    T.playTimeButton, T.breaksBox, T.breakButton = timeButton, breaks, breakButton
    refreshes[#refreshes + 1] = function()
        DrawTime(timeButton)
        breaks:SetChecked(ns.db.plannerBreaks == true)
        DrawBreak(breakButton)
    end

    -- Speed or story: a style, and the three weights it sets (a slider moved makes it Custom)
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
    local styleButton = ButtonRow(G, "style", "Style: %s", "Speed and Story each set the three sliders below. Set the sliders yourself for a style of your own.", function(b, button)
        local now, at = ns.PlannerStyle and ns.PlannerStyle() or "speed", 1
        for i, st in ipairs(styles) do if st[1] == now then at = i end end
        at = (button == "RightButton") and ((at - 2) % #styles + 1) or (at % #styles + 1)
        if ns.PlannerSetStyle then ns.PlannerSetStyle(styles[at][1]) end
        DrawStyle(b)
        SyncSliders()
    end, true)
    styleButton.row.tipTitle = "Speed or story"
    local means = { speed = "How much the route goes for the most experience in the time.",
                    safety = "How much it keeps away from elites, escorts and places where you died.",
                    story = "How much it goes for the zone's quest chains. At 100 it reaches back up to 10 levels for them." }
    for _, def in ipairs({ { "speed", "Speed" }, { "safety", "Safety" }, { "story", "Story" } }) do
        local slider = SliderRow(G, "style", def[2], means[def[1]], 0, 100, 10, def[1] == "speed" and 100 or 0, function(v)
            if syncing then return end
            if ns.PlannerSetWeight then ns.PlannerSetWeight(def[1], v) end
            DrawStyle(styleButton)
        end)
        sliders[def[1]] = slider
    end
    T.styleButton, T.speedSlider, T.safetySlider, T.storySlider = styleButton, sliders.speed, sliders.safety, sliders.story
    refreshes[#refreshes + 1] = function()
        DrawStyle(styleButton)
        SyncSliders()
    end
    return y, function() for _, r in ipairs(refreshes) do r() end end
end

-- Group D: level times, race your best, where you left off, save as guide, read aloud.
local function FeelRecordsSection(live, y, Replan, T)
    local G = T.rows
    local race = SwitchRow(G, "records", "plannerRace", "Race your best", "The panel says how far ahead or behind you are of your fastest character's time at this level.",
        function() return ns.db.plannerRace == true end, function(v) ns.db.plannerRace = v end)
    local leftOff = SwitchRow(G, "records", "plannerLeftOff", "Where you left off, at login", "When you log in, a line says where you were on the route and what comes next.",
        function() return ns.db.plannerLeftOff ~= false end, function(v) ns.db.plannerLeftOff = v end)
    local SPEAK = "Each new step is read aloud as you reach it."
    local speak = SwitchRow(G, "records", "plannerSpeak", "Read the route aloud", SPEAK,
        function() return ns.db.plannerSpeak ~= false end, function(v) ns.db.plannerSpeak = v end)
    T.raceBox, T.leftOffBox, T.speakBox = race, leftOff, speak
    local function Refresh()
        race:SetChecked(ns.db.plannerRace == true)
        leftOff:SetChecked(ns.db.plannerLeftOff ~= false)
        speak:SetChecked(ns.db.plannerSpeak ~= false)
        local on = ns.db.readDialog and true or false      -- (reading aloud is one switch in Accessibility; this one only narrows it)
        speak.row:SetAlpha(on and 1 or 0.6)                -- (dimmed, as a 12.3 switch whose parent is off; it can still be set)
        speak.row.desc:SetText(ns:Tr(SPEAK) .. (on and "" or ("  " .. ns:Tr("Needs reading aloud on in Accessibility"))))
    end
    Refresh()                                              -- (right from the start, not only after the first page refresh)
    return y, Refresh
end

-- Batch 5's sections of the Guide tab, one per group, called the same way as batch 4's (after them).
-- Each group writes only inside its own function's body.
-- Group A: find a group for a group quest.
local function TogetherGroupSection(live, y, Replan, T)
    local G = T.rows
    local find = SwitchRow(G, "together", "plannerFindGroup", "Find a group button", "A group quest on the panel gets a button that writes a line asking for a group. It only fills your chat box: you send it.",
        function() return ns.db.plannerFindGroup ~= false end, function(v)
        ns.db.plannerFindGroup = v
        if ns.GuideRedraw then ns:GuideRedraw() end
    end)
    local function DrawChannel(b)
        local name = ns.db.plannerLFGChannel
        if type(name) ~= "string" or name == "" then name = ns:Tr("Chat box") end
        b.text:SetText(string.format(ns:Tr("Find a group in: %s"), name))
    end
    local channel = ButtonRow(G, "together", "Find a group in: %s", "Where that line goes: your chat box's current channel, or a channel you have joined.", function(b, button)
        local list = { "" }
        for _, name in ipairs(ns.PlannerLFGChannels and ns.PlannerLFGChannels() or {}) do list[#list + 1] = name end
        local at = 1
        for i, name in ipairs(list) do if name == (ns.db.plannerLFGChannel or "") then at = i end end
        at = (button == "RightButton") and ((at - 2) % #list + 1) or (at % #list + 1)
        ns.db.plannerLFGChannel = list[at]
        DrawChannel(b)
    end, true)
    channel.row.tipTitle = "Find a group button"
    T.findGroupBox, T.findGroupChannel = find, channel
    return y, function()
        find:SetChecked(ns.db.plannerFindGroup ~= false)
        DrawChannel(channel)
    end
end

-- Group B: plan with a friend (the duo).
local function TogetherDuoSection(live, y, Replan, T)
    local G = T.rows
    local ask = SwitchRow(G, "together", "plannerDuoAsk", "Let friends ask to plan with you", "A friend with Fantasy Glass UI can ask to plan one route for you both. You are always asked first.",
        function() return ns.db.plannerDuoAsk ~= false end, function(v) ns.db.plannerDuoAsk = v end)
    local start = ButtonRow(G, "together", "Plan with a friend", "One route for you and your target or the one other player in your party: the same quests, in the same order.", function()
        if ns.PlannerDuoStart then ns:PlannerDuoStart() end         -- (your target, your one party member, or it says how)
    end)
    T.duoAskBox, T.duoButton = ask, start
    local function Refresh() ask:SetChecked(ns.db.plannerDuoAsk ~= false) end
    Refresh()
    return y, Refresh
end

-- Group C: the plan code for the website's plan page.
local function TogetherCodeSection(live, y, Replan, T)
    local G = T.rows
    local share = ButtonRow(G, "together", "Share plan", "Turns the route you are following into a plan code to copy.", function()
        if ns.PlannerCodeFollowing and ns.PlannerCodeFollowing() then ns:PlannerSharePlan() end
    end)
    T.sharePlanButton = share
    local function Refresh()                                -- (greyed, and says why, while the planned guide is not the one you follow)
        local can = ns.PlannerCodeFollowing and ns.PlannerCodeFollowing() and true or false
        share:SetAlpha(can and 1 or 0.45)
        if can then share:Enable() else share:Disable() end
        ns:ButtonTip(share, not can and "Follow the planned route to share it" or nil)
    end
    Refresh()
    return y, Refresh
end

------------------------------------------------------------------------------------------
-- Guide: quest guides are not released yet. Everyone sees "coming soon"; where they have been
-- unlocked (see Guide.lua) this tab holds their switch and controls instead.
------------------------------------------------------------------------------------------
-- (polish) While this tab is the section on show, its rows join the settings window's keys: Tab and
-- the arrows reach them, Space and Enter use them, Left and Right step a choice or a slider
-- (FeaturesPage.lua's page.Focus and page.Use, which go by page.shownKeys and page.rows).
local function GuideShowing()
    local O = ns.optUI
    local host, fp = O and O.pages and O.pages.guide, O and O.sections
    if type(host) == "table" and type(fp) == "table" and type(host.area) == "table" and rawget(host.area, "lentTo") == fp then return host, fp end
    return nil
end
local function JoinKeys(T, fp)
    if type(fp.rows) ~= "table" or type(fp.shownKeys) ~= "table" then return end
    local mine = T.navKeys or {}
    for i = #fp.shownKeys, 1, -1 do if mine[fp.shownKeys[i]] then table.remove(fp.shownKeys, i) end end
    T.navKeys = {}
    for _, row in ipairs(T.rows.shown or {}) do
        local key = row.navKey
        if key and (row.switch or row.button) and not T.navKeys[key] then
            T.navKeys[key] = true
            fp.rows[key] = row
            fp.shownKeys[#fp.shownKeys + 1] = key
        end
    end
end

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
    live:SetSize(736, 896)
    T.live = live
    local G = { live = live, list = {}, heads = {}, groups = {}, width = 736 }
    T.rows = G
    for _, s in ipairs(GUIDE_SECTIONS) do
        local group = CreateFrame("Frame", nil, live, ns.template)   -- (each section's rows sit together, in a thin rim)
        group:SetBackdrop(ns.BACKDROP)
        ns:Paint(group, "SetBackdropColor", "card", 0)
        ns:Paint(group, "SetBackdropBorderColor", "rule", 1)
        group:Hide()
        G.groups[s[1]] = group
        G.heads[s[1]] = GuideHeading(live, s[2], 0, 0)
    end

    -- Quest guides: what the guide is doing, its switches, and the windows it has
    local status = TextRow(G, "guides", 13)
    local on = SwitchRow(G, "guides", "questGuide", "Use quest guides", "The step panel, and the arrow that points to your step. Off, nothing of the guide shows.",
        function() return ns.db.questGuide ~= false end, function(v)
        ns.db.questGuide = v
        if ns.GuideApplySwitch then ns:GuideApplySwitch() end
        page.Refresh()
    end)
    local sound = SwitchRow(G, "guides", "guideSound", "A sound when a step is done", "A short sound each time a step ticks off.",
        function() return ns.db.guideSound ~= false end, function(v) ns.db.guideSound = v end)
    ButtonRow(G, "guides", "Your guides", "The guides you have: follow one, or open it to change it.", function() if ns.HideConfig then ns.HideConfig() end; ns:GuideList() end)
    ButtonRow(G, "guides", "Write or paste a guide", "The guide editor: write the steps yourself, or paste a guide someone gave you.", function() if ns.HideConfig then ns.HideConfig() end; ns:GuideEdit("") end)
    local route = ButtonRow(G, "guides", "Edit the route", "The steps of the guide you are following, to change, move or take out.", function()
        if ns.HideConfig then ns.HideConfig() end
        if ns.GuideRouteEditor then ns:GuideRouteEditor() end
    end)
    T.routeButton = route
    T.introButton = ButtonRow(G, "guides", "How the planner works", "The short tour from the first time: what the planner does, following a route, your pace, and planning with a friend.", function()
        if ns.PlannerIntro then ns:PlannerIntro(1) end
    end)

    -- Record a guide as you play: a name, the button, and what recording does
    local recRow = NewRow(G, "record", 90, "Record a guide as you play")
    local name = ns:CreateEditBox(recRow, 240, 24, "a name for the guide")
    name:SetPoint("TOPLEFT", ROW_PAD, -14)
    local recBtn
    recBtn = ns:CreateButton(recRow, "", 170, 24, function()
        if ns.guideRecording then ns:GuideRecordStop() else ns:GuideRecord(name:GetText()) end
        page.Refresh()
    end)
    recBtn:SetPoint("LEFT", name, "RIGHT", 8, 0)
    Hover(recRow, recBtn)
    recRow.button, recRow.navKey = recBtn, "guide:record"
    local how = Desc(recRow, "While recording, every quest you accept, finish and hand in becomes a step, with where you stood and who you spoke to. In chat: /fgui guide (your guides), /fgui guide record <name>, stop, edit <name>, next, back, off.")
    how:SetPoint("TOPLEFT", ROW_PAD, -(14 + 24 + 10))
    recRow.Layout = function(w)
        local dw = math.max(120, w - 2 * ROW_PAD)
        how:SetWidth(dw)
        return math.ceil(14 + 24 + 10 + TextH(how, 13, dw) + 14)
    end
    T.onBox, T.soundBox, T.recordButton, T.nameBox = on, sound, recBtn, name

    -- The route planner: a button, and what it takes into account. Changing a setting plans again, if it is running.
    local function Replan() if ns.PlannerReplan then ns:PlannerReplan("settings") end end
    local plan = ButtonRow(G, "plan", "Plan my route", "Works out a route of quests for your level from where you are, and starts following it.", function()
        if ns.GuideOn and not ns:GuideOn() then
            ns:Print("Quest guides are switched off. Switch them on under Guide in /fgui, or in the setup.")
        elseif ns.PlannerPlanCommand then ns.PlannerPlanCommand("")      -- (with the time you can play, as set below)
        elseif ns.PlannerStart then ns:PlannerStart() end
        page.Refresh()
    end)
    local groups = { { "solo", "Solo" }, { "grouped", "When grouped" }, { "all", "Everything" } }
    local function DrawGroup(b)
        local now, gname = ns.db.plannerGroup or "solo", nil
        for _, g in ipairs(groups) do if g[1] == now then gname = g[2] end end
        b.text:SetText(ns:Tr("Group quests") .. ":  " .. ns:Tr(gname or "Solo"))
    end
    local group = ButtonRow(G, "plan", "Group quests", "Solo plans only quests you can do alone. When grouped adds group quests while you are in a group, and Everything always does.", function(b, button)
        local now, at = ns.db.plannerGroup or "solo", 1
        for i, g in ipairs(groups) do if g[1] == now then at = i end end
        at = (button == "RightButton") and ((at - 2) % #groups + 1) or (at % #groups + 1)
        ns.db.plannerGroup = groups[at][1]
        DrawGroup(b)
        Replan()
    end, true)
    -- What the route includes: each a switch that plans again
    local function Include(key, label, desc)
        return SwitchRow(G, "include", key, label, desc, function() return ns.db[key] ~= false end, function(v)
            ns.db[key] = v
            Replan()
        end)
    end
    local flights = Include("plannerLearnFlights", "Learn new flight points on the way", "A short way round to a flight master you do not know yet, when the route passes close.")
    local trainer = Include("plannerTrainer", "Visit your trainer on the way", "A stop at your class trainer every two levels, for your new spells.")
    local hold = Include("plannerHold", "Save hand-ins to level in town", "A hand-in that would take you up a level waits until the route reaches your trainer's town.")
    local vendor = Include("plannerVendor", "Sell and repair stops", "A stop at a vendor when your bags are nearly full or your gear is worn.")
    local supplies = Include("plannerSupplies", "Buy supplies at the vendor stop", "At that stop, ammunition, food and drink are bought too.")
    local profession = Include("plannerProfession", "Profession training stops", "A stop at a profession's trainer when your skill has reached what you can learn now.")
    local mount = Include("plannerMount", "Mount reminder", "From level 40: the riding trainer, your mount, and how much gold is still to find.")
    local mail = Include("plannerMail", "Mail stops", "A stop at a mailbox when mail is waiting and one is close.")
    local explore = Include("plannerExplore", "Explore on the way", "Places you have not discovered yet, when they are close to the route.")
    local gather = Include("plannerGather", "Gather on the way", "Herbs and ore you have gathered before, close to the route, and a note to skin what you kill.")
    local classQuests = Include("plannerClassQuests", "Plan class quests", "Your class quests go on the route at the right level, and the panel says when one is ready.")
    T.classQuestsBox = classQuests
    local rested = Include("plannerRested", "Count rested experience", "Kills are worth double while you are rested, and the route counts them so.")
    local rewards = Include("plannerRewards", "Count upgrades in rewards", "A quest whose reward is better than what you wear counts for more.")
    local deaths = Include("plannerDeaths", "Learn from my deaths", "A place where you died twice is left alone until you are two levels higher.")
    local soloElites = Include("plannerSoloElites", "Include elites my class has soloed", "Elite quests that one of your characters of this class has done alone count as Solo quests.")
    local repButton = ButtonRow(G, "plan", "Reputation I want", "For each faction, the standing you want to reach: quests that raise it count for more until you get there.", function()
        if ns.HideConfig then ns.HideConfig() end
        if ns.GuideReputation then ns:GuideReputation() end
    end)
    local skipButton = ButtonRow(G, "plan", "Quests you skipped", "The quests you told the planner never to suggest. Click one there to have it suggested again.", function()
        if ns.HideConfig then ns.HideConfig() end
        if ns.GuideSkipped then ns:GuideSkipped() end
    end)
    -- Advice along the way: what the panel says as you go
    local function Advice(key, label, desc, after)
        return SwitchRow(G, "advice", key, label, desc, function() return ns.db[key] ~= false end, function(v)
            ns.db[key] = v
            after()
        end)
    end
    local why = Advice("plannerWhy", "Show why each step is there", "Each step on the panel says what it is worth: the experience, or the time it saves.", Replan)
    local pick = Advice("plannerPickReward", "Show the best quest reward", "At a hand-in, the reward that suits you best is marked and named in chat. You choose it yourself.", function() end)
    local logAdvice = Advice("plannerLogAdvice", "Quest log advice", "When your quest log is nearly full, the panel says which quests are worth abandoning.", function()
        if ns.GuideShowPanel and ns.GuidePanelShown and ns:GuidePanelShown() then ns:GuideShowPanel() end
    end)
    local inn = Advice("plannerInn", "Suggest an inn when you stop", "After a long stretch of play, the panel points to an inn close by, to log out in for rested experience.", function() end)
    local dry = Advice("plannerDry", "Suggest what to do when quests run dry", "When no quest is worth the trip, a dungeon or a place to grind is suggested instead.", Replan)
    T.pickBox, T.logAdviceBox, T.innBox, T.dryBox = pick, logAdvice, inn, dry
    T.deathsBox, T.soloElitesBox, T.skippedButton = deaths, soloElites, skipButton
    T.restedBox, T.rewardsBox, T.reputationButton = rested, rewards, repButton
    T.planButton, T.groupButton, T.flightsBox, T.whyBox, T.trainerBox, T.holdBox = plan, group, flights, why, trainer, hold
    T.vendorBox, T.suppliesBox, T.professionBox, T.mountBox = vendor, supplies, profession, mount
    T.mailBox, T.exploreBox, T.gatherBox = mail, explore, gather

    -- batch 4's sections, then batch 5's, in this order (each puts its rows in its own place on the tab)
    local y, refreshes = 0, {}
    for _, section in ipairs({ FeelMapSection, FeelPanelSection, FeelPaceSection, FeelRecordsSection, TogetherGroupSection, TogetherDuoSection, TogetherCodeSection }) do
        local nextY, refresh = section(live, y, Replan, T)
        y = tonumber(nextY) or y
        if type(refresh) == "function" then refreshes[#refreshes + 1] = refresh end
    end

    -- Laying the rows out: section by section, each row as tall as its text needs at this width and text
    -- size, a little taller with "Bigger controls". Run again on every refresh and for a new width.
    local function Layout(w)
        w = tonumber(w)
        if not w or w < 300 then w = G.width end
        G.width = w
        local big = ns.db.bigControls and true or false
        local at, shown = 0, {}
        for _, s in ipairs(GUIDE_SECTIONS) do
            local mine = {}
            for _, row in ipairs(G.list) do if row.sec == s[1] then mine[#mine + 1] = row end end
            table.sort(mine, function(a, b) return a.seq < b.seq end)
            local head, box = G.heads[s[1]], G.groups[s[1]]
            if #mine > 0 then
                head:ClearAllPoints()
                head:SetPoint("TOPLEFT", live, "TOPLEFT", 0, at)
                head:Show()
                at = at - (math.ceil(TextH(head, 13, w)) + 10)
                local top = at
                for i, row in ipairs(mine) do
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", live, "TOPLEFT", 0, at)
                    row:SetWidth(w)
                    row.line:SetShown(i > 1)
                    local h = (tonumber(row.Layout(w)) or ROW_MIN) + (big and 12 or 0)
                    row:SetHeight(h)
                    local control = row.switch or row.scaled or (row.button and row.button.SetScale and row.button)
                    if control and control.SetScale then control:SetScale(big and 1.35 or 1) end
                    row:Show()
                    shown[#shown + 1] = row
                    at = at - h
                end
                box:ClearAllPoints()
                box:SetPoint("TOPLEFT", live, "TOPLEFT", 0, top)
                box:SetSize(w, top - at)
                box:Show()
                at = at - 22
            else
                head:Hide()
                box:Hide()
            end
        end
        G.shown = shown
        local height = math.max(896, math.ceil(-at + 4))
        live:SetSize(w, height)
        local was = rawget(page, "contentHeight")
        page.contentHeight = height
        if page.area then page.area:SetContentHeight(height) end
        local host, fp = GuideShowing()
        if host and host.sheet == page then
            JoinKeys(T, fp)
            -- the card it is shown on was sized before this: once the height has changed, show the section again
            local now = GetTime and GetTime() or 0
            if was ~= height and (now - (T.reshownAt or -10)) > 1 and fp.section and fp.Show then
                T.reshownAt = now
                ns:After(0, function()
                    if GuideShowing() and fp.section then pcall(fp.Show, fp.section, true) end
                end)
            end
        end
        return height
    end
    T.Layout = Layout
    page.FollowWidth = function(w) Layout(w) end              -- (shown on a section's card: as wide as the card)

    page.Refresh = function()
        local open = ns.GuideUnlocked and ns:GuideUnlocked()
        T.unlocked = open and true or false
        if open then soon:Hide(); live:Show() else live:Hide(); soon:Show() return end
        for _, row in ipairs(G.list) do if row.Sync then row.Sync() end end
        DrawGroup(group)
        recBtn.text:SetText(ns:Tr(ns.guideRecording and "Stop recording" or "Record"))
        local st = ns.GuideState and ns.GuideState()
        if ns.guideRecording then status:SetText(ns:SignalHex("bad") .. ns:Tr("Recording") .. ":|r " .. tostring(ns.guideRecording.name) .. "  (" .. #ns.guideRecording.steps .. ")")
        elseif st then status:SetText(ns:Tr("Following") .. ": " .. AccentTextHex(status) .. tostring(st.name) .. "|r  -  " .. tostring(st.at))
        else status:SetText(ns:Tr("You are not following a guide.")) end
        for _, refresh in ipairs(refreshes) do refresh() end
        Layout(G.width)
        -- the first time the tab is opened after the guide was unlocked: the planner's short tour
        local host = GuideShowing()
        if host and host.sheet == page and ns.PlannerIntroDue and ns:PlannerIntroDue() then ns:PlannerIntro(1) end
    end
    page.Refresh()
    if not T.unlocked then Layout(G.width) end
    return T
end
