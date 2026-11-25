-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local O = ns.optUI
local Header = function(...) return O.Header(...) end

-- Page: look (themes, accent, lettering, portraits, and making your own theme) -----------------------
local function PickColor(r, g, b, onChange)
    if type(ColorPickerFrame) ~= "table" then return false end
    local function apply()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        if type(nr) == "number" then onChange(nr, ng, nb) end
    end
    local function cancel() onChange(r, g, b) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel })
    elseif ColorPickerFrame.SetColorRGB then
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc, ColorPickerFrame.hasOpacity = apply, cancel, false
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    else
        return false
    end
    return true
end

local BuildColors                                           -- (made further down; the Look tab holds it)
local function BuildLook(page)
    local th = ns.theme
    local Refresh                                            -- redraws every "which one is selected" mark
    local function Changed()
        if not ns:Retheme() then O.frame.note:Show() end
        Refresh()
    end
    local function Mark(btn, on)
        if on then ns:Paint(btn, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(btn, "SetBackdropBorderColor", "@border", 1) end
        btn.picked = on
    end
    local function Choice(text, width, onClick)
        local b = ns:CreateButton(page, text, width, 24, onClick)
        b:HookScript("OnLeave", function(self) Mark(self, self.picked) end)
        return b
    end

    -- Themes (12.3): a family control, a grid of tiles for the family, and a preview column. A tile
    -- shows the theme's real panel colour, with its rim colour for the top edge and two bars (and
    -- three star dots for Celestial). Picking a tile previews it; "Use this theme" puts it on. The
    -- tile and the preview carry the theme's own colours, set straight on their textures: the
    -- window wears a look of its own, so a role would give them the look's colours instead. Only the
    -- chrome (names, the ring, the buttons) uses roles.
    local FAMILIES = { { "GLASS", "Glass" }, { "FANTASY", "Fantasy" }, { "CELESTIAL", "Celestial" }, { "MINE", "Your themes" } }
    local FAMILY_LINE = {
        GLASS = "See-through panes with soft shadows and a bright top edge.",
        FANTASY = "Solid panels with a dark rim, a grain and corner ornaments.",
        CELESTIAL = "A night sky: a fine starfield, constellations and star points in the accent color.",
    }
    local function StyleFamily(t)
        return (t.style == "GLASS") and "GLASS" or (t.style == "CELESTIAL") and "CELESTIAL" or "FANTASY"
    end
    local function GroupOf(t)
        if t.custom then return "MINE" end
        return StyleFamily(t)
    end
    local TOP, GRID_H = 40, 420                              -- the grid starts under the family control and is this tall
    local PV_W, PV_MIN, GAP = 250, 180, 16                   -- the preview column (narrower in a narrow window), and the space between it and the grid
    local CELL_W, CELL_H, TILE_W = 98, 88, 90
    local picker = { cols = 4, width = 736, tiles = {}, list = {}, family = "GLASS", cell = { CELL_W, CELL_H } }
    page.themePicker = picker
    local Swatch, ShowSwatch = O.ThemeSwatch, O.ShowThemeSwatch     -- (Shared.lua: the setup uses the small kind too)
    page.ShowSwatch = ShowSwatch
    -- the section's two headings stay (the sections are cut from the page by them); the page itself
    -- has no use for the words
    Header(page, "Glass", 0, 0):Hide()
    Header(page, "Your themes", 0, -(TOP + GRID_H + 4)):Hide()

    local familyButtons = {}
    local grid, gsheet = ns:ScrollArea(page, CELL_W * 4, GRID_H)
    grid:SetPoint("TOPLEFT", 0, -TOP)
    picker.grid = grid
    local Place, Preview

    local function Pick(key)
        if not (key and ns.themes[key]) then return end
        picker.picked = key
        Place()
        Preview()
    end
    local function Apply(key)                                -- as clicking a theme did before (the reload note comes from Retheme)
        local t = key and ns.themes[key]
        if not t then return end                             -- (a theme deleted since this tile was drawn)
        ns.db.theme = key
        ns.db.accent = t.accent or ns.db.accent
        if ns.NoteHomeTheme then ns:NoteHomeTheme() end
        Changed()
    end
    picker.Pick, picker.Apply = Pick, Apply

    local function NewTile(i)
        local b = CreateFrame("Button", nil, gsheet)
        b:SetSize(TILE_W, CELL_H - 6)
        b.text = b:CreateFontString(nil, "OVERLAY")
        ns:Font(b.text, 12)
        b.text:SetPoint("TOP", b, "TOP", 0, -58)
        b.text:SetWidth(TILE_W)
        b.text:SetJustifyH("CENTER")
        if b.text.SetWordWrap then b.text:SetWordWrap(false) end
        Swatch(b, true)
        local ring = CreateFrame("Frame", nil, b, ns.template)       -- the picked tile: 2 px in the accent
        ring:SetPoint("TOPLEFT", b.swatch, "TOPLEFT", -4, 4)
        ring:SetPoint("BOTTOMRIGHT", b.swatch, "BOTTOMRIGHT", 4, -4)
        ring:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 2 })
        ns:Paint(ring, "SetBackdropBorderColor", "@accent", 1)
        ring:Hide()
        b.ring = ring
        b.suiClick = function(self) if self.key then Pick(self.key) end end
        b:SetScript("OnClick", b.suiClick)
        b:HookScript("OnClick", function() ns.UISound("IG_MAINMENU_OPTION") end)
        b:SetScript("OnEnter", function(self)
            local t = self.key and ns.themes[self.key]
            if not t then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:ThemeName(self.key))
            if t.custom then GameTooltip:AddLine(ns:Tr("One of your own themes."), 0.6, 0.6, 0.6) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        picker.tiles[i] = b
        return b
    end

    -- the tiles in their cells, and the row the picked one is in
    Place = function()
        local cols = picker.cols
        local at
        for i, key in ipairs(picker.list) do
            local b = picker.tiles[i] or NewTile(i)
            b.key = key
            b.px, b.py = ((i - 1) % cols) * CELL_W, -math.floor((i - 1) / cols) * CELL_H
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", gsheet, "TOPLEFT", b.px, b.py)
            b.text:SetText(ns:ThemeName(key, "short"))
            if key == (ns.db.theme or "SMOKE") then ns:Paint(b.text, "SetTextColor", "@accent") else ns:Paint(b.text, "SetTextColor", "text") end
            ShowSwatch(b.swatch, key)
            b.picked = (key == picker.picked)
            b.ring:SetShown(key == picker.picked)
            if key == picker.picked then at = i end
            b:Show()
        end
        for i = #picker.list + 1, #picker.tiles do picker.tiles[i]:Hide() end
        grid:SetContentHeight(math.max(1, math.ceil(#picker.list / cols) * CELL_H))
        if at and picker.scrollTo ~= picker.family then      -- a family just opened: start where the picked tile is
            picker.scrollTo = picker.family
            grid:ScrollToShow(math.floor((at - 1) / cols) * CELL_H, CELL_H)
        end
    end
    -- 4 columns at the window's usual width, 3 (and at last 2) as it narrows; the preview column takes
    -- what is left, from 180 up to 250. (8: the grid's scroll track, drawn right of the grid.)
    function picker.Layout(w)
        w = (type(w) == "number" and w > 0) and w or 736
        picker.width = w
        picker.cols = math.max(2, math.min(4, math.floor((w - PV_MIN - GAP - 8) / CELL_W)))
        picker.gridW = picker.cols * CELL_W
        picker.pvW = math.max(PV_MIN, math.min(PV_W, w - picker.gridW - GAP - 8))
        picker.previewX = w - picker.pvW
        grid:SetWidth(picker.gridW)
        if picker.SizePreview then picker.SizePreview(picker.pvW) end
        picker.pv:ClearAllPoints()
        picker.pv:SetPoint("TOPLEFT", page, "TOPLEFT", picker.previewX, -TOP)
        Place()
    end
    page:HookScript("OnSizeChanged", function(_, w) if picker.pv then picker.Layout(w) end end)
    page.FollowWidth = function(w) if picker.pv then picker.Layout(w) end end

    -- the family control
    local function ShowFamily(which)
        picker.family = which
        picker.Draw()
    end
    for i, def in ipairs(FAMILIES) do
        local b = Choice(def[2], 110, function() ShowFamily(def[1]) end)
        b:SetPoint("TOPLEFT", (i - 1) * 116, 0)
        familyButtons[def[1]] = b
    end
    picker.familyButtons = familyButtons
    for _, key in ipairs(ns.themeOrder) do                   -- (a search for a theme's name lands on its family)
        local t = ns.themes[key]
        if t and not t.custom then
            local was = ns.indexingTab
            ns.indexingTab = "look"
            ns:IndexOption(t.name, familyButtons[GroupOf(t)])
            ns.indexingTab = was
        end
    end

    -- the preview column: a sample frame in the picked theme's colours, its name, its family's line, the two buttons
    local pv = CreateFrame("Frame", nil, page)
    pv:SetSize(PV_W, 300)
    picker.pv = pv
    local sf = CreateFrame("Frame", nil, pv)
    sf:SetSize(PV_W, 104)
    sf:SetPoint("TOPLEFT", 0, 0)
    local function Tex(parent, layer, sub) local t = parent:CreateTexture(nil, layer, nil, sub); t:SetTexture(ns.FLAT); return t end
    local S = {}
    S.edge = Tex(sf, "BACKGROUND", 0); S.edge:SetAllPoints()
    S.fill = Tex(sf, "BACKGROUND", 1); S.fill:SetPoint("TOPLEFT", 2, -2); S.fill:SetPoint("BOTTOMRIGHT", -2, 2)
    S.gloss = Tex(sf, "BORDER", 0); S.gloss:SetPoint("TOPLEFT", 2, -2); S.gloss:SetPoint("TOPRIGHT", -2, -2); S.gloss:SetHeight(1)
    S.portEdge = Tex(sf, "ARTWORK", 0); S.portEdge:SetSize(42, 42); S.portEdge:SetPoint("TOPLEFT", 12, -12)
    S.port = Tex(sf, "ARTWORK", 1); S.port:SetPoint("TOPLEFT", S.portEdge, "TOPLEFT", 1, -1); S.port:SetPoint("BOTTOMRIGHT", S.portEdge, "BOTTOMRIGHT", -1, 1)
    S.hpBack = Tex(sf, "ARTWORK", 0); S.hpBack:SetSize(164, 12); S.hpBack:SetPoint("TOPLEFT", 64, -30)
    S.hp = Tex(sf, "ARTWORK", 1); S.hp:SetSize(118, 12); S.hp:SetPoint("TOPLEFT", S.hpBack, "TOPLEFT", 0, 0)
    S.mpBack = Tex(sf, "ARTWORK", 0); S.mpBack:SetSize(164, 8); S.mpBack:SetPoint("TOPLEFT", 64, -46)
    S.mp = Tex(sf, "ARTWORK", 1); S.mp:SetSize(84, 8); S.mp:SetPoint("TOPLEFT", S.mpBack, "TOPLEFT", 0, 0)
    S.who = sf:CreateFontString(nil, "OVERLAY"); ns:Font(S.who, 12, true); S.who:SetPoint("TOPLEFT", 64, -12)
    S.line = sf:CreateFontString(nil, "OVERLAY"); ns:Font(S.line, 11); S.line:SetPoint("TOPLEFT", 12, -66)
    S.plateEdge = Tex(sf, "ARTWORK", 0); S.plateEdge:SetSize(78, 22); S.plateEdge:SetPoint("BOTTOMLEFT", 12, 8)
    S.plate = Tex(sf, "ARTWORK", 1); S.plate:SetPoint("TOPLEFT", S.plateEdge, "TOPLEFT", 1, -1); S.plate:SetPoint("BOTTOMRIGHT", S.plateEdge, "BOTTOMRIGHT", -1, 1)
    S.btn = sf:CreateFontString(nil, "OVERLAY"); ns:Font(S.btn, 11); S.btn:SetPoint("CENTER", S.plateEdge, "CENTER")
    S.studs = {}
    for k, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local d = sf:CreateTexture(nil, "OVERLAY")
        d:SetTexture(ns.MEDIA .. "dot.tga")
        d:SetSize(6, 6)
        d:SetPoint("CENTER", sf, point, point:find("LEFT") and 6 or -6, point:find("TOP") and -6 or 6)
        S.studs[k] = d
    end
    picker.sample = S

    local pvName = pv:CreateFontString(nil, "OVERLAY")
    ns:Font(pvName, 16, true)
    pvName:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -12)
    pvName:SetWidth(PV_W)
    pvName:SetJustifyH("LEFT")
    if pvName.SetWordWrap then pvName:SetWordWrap(false) end      -- (one line: "In use now" sits under it)
    ns:Paint(pvName, "SetTextColor", "text")
    local pvNow = pv:CreateFontString(nil, "OVERLAY")
    ns:Font(pvNow, 12)
    pvNow:SetPoint("TOPLEFT", pvName, "BOTTOMLEFT", 0, -4)
    ns:Paint(pvNow, "SetTextColor", "faint")
    local pvDesc = pv:CreateFontString(nil, "OVERLAY")
    ns:Font(pvDesc, 12)
    pvDesc:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -56)
    pvDesc:SetWidth(PV_W)
    pvDesc:SetJustifyH("LEFT")
    pvDesc:SetJustifyV("TOP")
    pvDesc:SetHeight(50)
    ns:Paint(pvDesc, "SetTextColor", "dim")
    picker.name, picker.desc, picker.now = pvName, pvDesc, pvNow

    local use = ns:CreateButton(pv, "Use this theme", PV_W, 30, function() Apply(picker.picked) end)
    use:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -116)
    ns:Paint(use, "SetBackdropColor", "@accent", 1)          -- the accent fill: the one button here that is not a plain plate
    ns:Paint(use, "SetBackdropBorderColor", "@accent", 1)
    use:HookScript("OnEnter", function(self)
        self.wash:Hide()
        local c = self.suiTextColor
        if c then self.text:SetTextColor(c[1], c[2], c[3]) end
    end)
    use:HookScript("OnLeave", function(self) ns:Paint(self, "SetBackdropBorderColor", "@accent", 1) end)
    picker.use = use
    local own = ns:CreateButton(pv, "Make my own", PV_W, 28, function()
        if O.Open then O.Open("look:Your own theme") end
    end)
    own:SetPoint("TOPLEFT", use, "BOTTOMLEFT", 0, -8)
    picker.own = own
    -- the column's width: the sample frame's bars and the lines and buttons under it follow it
    function picker.SizePreview(pw)
        pv:SetWidth(pw); sf:SetWidth(pw)
        pvName:SetWidth(pw); pvDesc:SetWidth(pw)
        use:SetWidth(pw); own:SetWidth(pw)
        local bar = math.max(60, pw - 64 - 22)
        S.hpBack:SetWidth(bar); S.hp:SetWidth(math.floor(bar * 0.72))
        S.mpBack:SetWidth(bar); S.mp:SetWidth(math.floor(bar * 0.51))
    end

    Preview = function()
        local key = picker.picked
        local c = key and ns:ThemeColors(key)
        if not c then return end
        local t = ns.themes[key]
        local function V(x, col, a) x:SetVertexColor(col[1], col[2], col[3], a or 1) end
        V(S.edge, c.border); V(S.fill, c.bg); V(S.portEdge, c.border); V(S.port, c.plate)
        V(S.hpBack, c.border, 0.55); V(S.hp, c.accent); V(S.mpBack, c.border, 0.55); V(S.mp, c.accent, 0.6)
        V(S.plateEdge, c.border); V(S.plate, c.plate)
        S.gloss:SetVertexColor(1, 1, 1, c.style == "GLASS" and 0.5 or 0)
        for _, d in ipairs(S.studs) do
            if c.style == "CELESTIAL" then V(d, c.accent) else V(d, c.border) end
            d:SetShown(c.style ~= "GLASS")
        end
        S.who:SetText((UnitName and UnitName("player")) or "")
        S.who:SetTextColor(c.accent[1], c.accent[2], c.accent[3])
        S.line:SetText(ns:Tr("Unit frames, bags and quests"))
        S.line:SetTextColor(c.text[1], c.text[2], c.text[3])
        S.btn:SetText(ns:Tr("Button"))
        S.btn:SetTextColor(c.btn[1], c.btn[2], c.btn[3])
        local fam = StyleFamily(t)
        local label
        for _, def in ipairs(FAMILIES) do if def[1] == fam then label = def[2] end end
        picker.nameText = ns:Tr(label) .. ": " .. ns:ThemeName(key, "short")
        picker.descText = ns:Tr(FAMILY_LINE[fam])
        pvName:SetText(picker.nameText)
        pvDesc:SetText(picker.descText)
        S.panel, S.rim, S.key = c.bg, c.border, key
        pvNow:SetText(key == (ns.db.theme or "SMOKE") and ns:Tr("In use now") or "")
        local a = ns.theme.accent                            -- text on the accent fill: dark on a light accent, white on a dark one
        local light = (a[1] * 0.299 + a[2] * 0.587 + a[3] * 0.114) > 0.55
        use.suiTextColor = light and { 0.07, 0.08, 0.1 } or { 1, 1, 1 }
        use.text:SetTextColor(use.suiTextColor[1], use.suiTextColor[2], use.suiTextColor[3])
    end
    picker.Preview = Preview

    -- everything that changes with the family, the theme in use or the colours
    function picker.Draw()
        local mine = {}
        local lists = { GLASS = {}, FANTASY = {}, CELESTIAL = {}, MINE = mine }
        for _, key in ipairs(ns.themeOrder) do
            local t = ns.themes[key]
            if t then table.insert(lists[GroupOf(t)], key) end
        end
        if picker.family == "MINE" and #mine == 0 then picker.family = "GLASS" end
        for _, def in ipairs(FAMILIES) do
            local b = familyButtons[def[1]]
            Mark(b, def[1] == picker.family)
            if def[1] == "MINE" then b:SetShown(#mine > 0) end
        end
        picker.list = lists[picker.family]
        if not (picker.picked and ns.themes[picker.picked]) then picker.picked = ns.db.theme or "SMOKE" end
        Place()
        Preview()
    end
    -- the theme in use shows: its family, its tile ringed, its name in the preview
    function picker.Sync()
        local now = ns.db.theme or "SMOKE"
        local t = ns.themes[now]
        picker.picked = now
        if t then picker.family = GroupOf(t) end
        picker.scrollTo = nil
        picker.Draw()
    end
    picker.Layout(type(page.GetWidth) == "function" and page:GetWidth() or 736)

    local Y = -(TOP + GRID_H + 28)                           -- under the themes

    -- accent
    Header(page, "Accent", 0, Y, { nav = "Accent and style" })       -- (accent, lettering, menu and bars, your own theme and theme by place: one section)
    local swatches = {}
    for i, key in ipairs(ns.accentOrder) do
        local sw = CreateFrame("Button", nil, page, ns.template)
        sw:SetSize(24, 20)
        sw:SetPoint("TOPLEFT", 90 + ((i - 1) % 16) * 29, Y - 1 - math.floor((i - 1) / 16) * 24)   -- two rows of sixteen
        sw:SetBackdrop(ns.BACKDROP)
        local r, g, b = ns:AccentColor(key)
        sw:SetBackdropColor(r, g, b, 1)
        sw:SetScript("OnClick", function() ns.db.accent = key; Changed() end)
        sw:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:AccentName(key))
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        swatches[key] = sw
    end
    Y = Y - 24 * (math.ceil(#ns.accentOrder / 16) - 1)       -- (room for the second row of accents)

    -- lettering, portraits, the game's micro menu
    Header(page, "Lettering", 0, Y - 34, { sub = true })
    local fontButtons = {}
    for i, key in ipairs(ns.fontOrder) do
        local style = ns.fontStyles[key]
        local b = Choice(style.name, 124, function() ns.db.fontStyle = key; Changed() end)
        b:SetPoint("TOPLEFT", 90 + ((i - 1) % 5) * 129, Y - 34 - math.floor((i - 1) / 5) * 28)
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:Tr(style.name))
            GameTooltip:AddLine(ns:Tr(style.face), 1, 1, 1)
            if not style.wide and (style.body or style.title) then
                GameTooltip:AddLine(ns:Tr("Western European letters only; other languages use the game's fonts."), 0.6, 0.6, 0.6, true)
            end
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        fontButtons[key] = b
    end
    page.fontButtons = fontButtons
    Y = Y - 28 * (math.ceil(#ns.fontOrder / 5) - 1)          -- (one row of lettering is allowed for below; this is the rest)
    Header(page, "Menu and bars", 0, Y - 68, { sub = true })
    local portraitButtons = {}                               -- (filled in the Portraits and class colors section, below)
    local frameStyleButtons = {}                             -- (the same section: Starcut or Classic)
    local modes = { "HIDE", "HOVER", "DIM", "SHOW" }
    local modeNames = { HIDE = "Hidden (Menu button)", HOVER = "Show on hover", DIM = "Dimmed", SHOW = "Shown" }
    local mbtn
    mbtn = ns:CreateButton(page, "", 300, 24, function()
        local cur = ns.db.microMode or "HIDE"
        local nextMode = modes[1]
        for i, m in ipairs(modes) do if m == cur then nextMode = modes[i % #modes + 1] end end
        ns.db.microMode = nextMode
        mbtn.text:SetText(ns:Tr("Game menu & bag bar: ") .. ns:Tr(modeNames[nextMode]))
        O.frame.note:Show()
    end)
    mbtn:SetPoint("TOPLEFT", 0, Y - 102)
    local barPanel = ns:CreateCheckbox(page, "Frame behind action bars", ns.db.barPanel, function(v)
        ns.db.barPanel = v
        if ns.ApplyBarPanels then ns:ApplyBarPanels() end
    end)
    barPanel:SetWidth(300)
    barPanel:SetPoint("TOPLEFT", 330, Y - 102)
    barPanel:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns:Tr("Frame behind action bars"))
        GameTooltip:AddLine(ns:Tr("Draws a themed panel behind each action bar. Off, the buttons stand on their own."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    barPanel:HookScript("OnLeave", function() GameTooltip:Hide() end)
    page.barPanel = barPanel
    mbtn.text:SetText(ns:Tr("Game menu & bag bar: ") .. ns:Tr(modeNames[ns.db.microMode or "HIDE"] or modeNames.HIDE))

    -- your own theme: three colors, a name, save
    local EY = Y - 142
    Header(page, "Make your own theme", 0, EY, { sub = true })
    local msg = page:CreateFontString(nil, "OVERLAY")
    ns:Font(msg, 11)
    msg:SetPoint("TOPLEFT", 200, EY - 2)
    msg:SetWidth(530)
    msg:SetJustifyH("LEFT")
    ns:Paint(msg, "SetTextColor", "faint")
    msg:SetText(ns:Tr("Pick colors and watch the interface change. Give it a name and save it to keep it."))

    -- The definition being edited: the current theme if it is one of yours, otherwise a new unsaved
    -- one started from the colors on screen right now.
    local function Work()
        local t = ns.themes[ns.db.theme]
        if t and t.custom then return ns.db.customThemes[t.customName], t.customName end
        local ar, ag, ab = ns:AccentColor(ns.db.accent or "AZURE")
        ns:SaveCustomTheme("*", { panel = { th.bg[1], th.bg[2], th.bg[3] }, rim = { th.border[1], th.border[2], th.border[3] }, accent = { ar, ag, ab },
                                  style = ns.style })       -- starts in the family you are looking at
        ns.db.theme, ns.db.accent = "U:*", "CUSTOM"
        return ns.db.customThemes["*"], "*"
    end
    local function SetPart(part, r, g, b)
        local def = Work()
        def[part] = { r, g, b }
        if part == "accent" then ns.db.accent = "CUSTOM" end
        Changed()
    end
    page.SetPart = SetPart                                   -- (also lets the editor be driven without the color wheel)

    -- glass or fantasy: the two families draw their panels differently (see-through panes with soft
    -- shadows, or solid panels with rims, grain and corner ornaments)
    local function SetStyle(style)
        local def = Work()
        def.style = (style == "FANTASY" or style == "CELESTIAL") and style or "GLASS"
        Changed()
    end
    page.SetStyle = SetStyle
    local styleButtons = {}
    for i, def in ipairs({ { "GLASS", "Glass" }, { "FANTASY", "Fantasy" }, { "CELESTIAL", "Celestial" } }) do
        local b = Choice(def[2], 58, function() SetStyle(def[1]) end)
        b:SetPoint("TOPLEFT", 556 + (i - 1) * 60, EY - 28)
        b:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:Tr(def[2]))
            GameTooltip:AddLine(ns:Tr(def[1] == "GLASS" and "See-through panes with soft shadows and a bright top edge."
                or def[1] == "CELESTIAL" and "A night sky: a fine starfield, constellations and star points in the accent color."
                or "Solid panels with a dark rim, a grain and corner ornaments."), 1, 1, 1, true)
            GameTooltip:AddLine(ns:Tr("Changing family finishes after a /reload."), 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        styleButtons[def[1]] = b
    end

    local partButtons = {}
    for i, def in ipairs({ { "panel", "Panel color" }, { "rim", "Rim color" }, { "accent", "Accent color" } }) do
        local b = ns:CreateButton(page, def[2], 150, 24, function()
            local d = Work()
            local c = d[def[1]]
            if not PickColor(c[1], c[2], c[3], function(r, g, bl) SetPart(def[1], r, g, bl) end) then
                msg:SetText("|cffffd100" .. ns:Tr("This client has no color wheel to open.") .. "|r")
            end
            Refresh()
        end)
        b:SetPoint("TOPLEFT", (i - 1) * 188, EY - 28)
        local chip = b:CreateTexture(nil, "OVERLAY")           -- shows the color itself
        chip:SetTexture(ns.FLAT)
        chip:SetSize(14, 14)
        chip:SetPoint("LEFT", b, "RIGHT", 6, 0)
        b.chip = chip
        partButtons[def[1]] = b
    end

    local nameBox = ns:CreateEditBox(page, 330, 24, "Name for your theme, or a theme string to import")
    nameBox:SetPoint("TOPLEFT", 0, EY - 60)
    local function Save()
        local name = nameBox:GetText()
        name = type(name) == "string" and strtrim(name):sub(1, 24) or ""
        if name == "" or name == "*" or name:find("[|:]") then
            msg:SetText(ns:SignalHex("bad") .. ns:Tr("Type a name for the theme first (letters and numbers).") .. "|r")
            return false
        end
        local def, was = Work()
        ns.db.theme = ns:SaveCustomTheme(name, { panel = def.panel, rim = def.rim, accent = def.accent, style = def.style })
        ns.db.accent = "CUSTOM"
        if was == "*" then ns:DeleteCustomTheme("*") end
        nameBox:SetText("")
        msg:SetText(ns:SignalHex("good") .. format(ns:Tr("Saved as %s."), name) .. "|r")
        Changed()
        return true
    end
    page.SaveAs = function(name) nameBox:SetText(name); return Save() end
    local save = ns:CreateButton(page, "Save", 80, 24, Save)
    save:SetPoint("LEFT", nameBox, "RIGHT", 10, 0)
    local DeleteTheme = ns:ConfirmClick(function()
        local t = ns.themes[ns.db.theme]
        ns:DeleteCustomTheme(t.customName)
        ns.db.theme, ns.db.accent = "SMOKE", "AZURE"
        msg:SetText(ns:Tr("Theme deleted."))
        Changed()
    end)
    local delete = ns:CreateButton(page, "Delete", 80, 24, function(self, ...)
        local t = ns.themes[ns.db.theme]
        if not (t and t.custom) then                                 -- (asked before anything is armed)
            msg:SetText("|cffffd100" .. ns:Tr("Only themes you made can be deleted.") .. "|r")
            return
        end
        return DeleteTheme(self, ...)
    end)
    delete:SetPoint("LEFT", save, "RIGHT", 10, 0)
    page.Delete = function() delete:Click() end

    -- share a theme as text: Export puts the string in the name box to copy; Import reads one pasted there
    local export = ns:CreateButton(page, "Export", 80, 24, function()
        nameBox:SetText(ns:ExportTheme())
        nameBox:SetFocus()
        nameBox:HighlightText()
        msg:SetText(ns:SignalHex("good") .. ns:Tr("The theme is in the box as text. Press Ctrl+C to copy it.") .. "|r")
    end)
    export:SetPoint("LEFT", delete, "RIGHT", 10, 0)
    local import = ns:CreateButton(page, "Import", 80, 24, function()
        local ok, result = ns:ImportTheme(nameBox:GetText())
        if ok then
            nameBox:SetText("")
            msg:SetText(ns:SignalHex("good") .. format(ns:Tr("Imported as %s."), result) .. "|r")
            Changed()
        else
            msg:SetText(ns:SignalHex("bad") .. ns:Tr(result) .. "  " .. ns:Tr("Paste a theme string into the box first.") .. "|r")
        end
    end)
    import:SetPoint("LEFT", export, "RIGHT", 6, 0)
    if nameBox.SetMaxLetters then nameBox:SetMaxLetters(0) end

    Refresh = function()
        ns:RegisterCustomThemes()
        picker.Sync()
        for key, sw in pairs(swatches) do
            if key == (ns.db.accent or "AZURE") then sw:SetBackdropBorderColor(1, 1, 1, 1) else sw:SetBackdropBorderColor(0, 0, 0, 1) end
        end
        for key, b in pairs(fontButtons) do Mark(b, key == (ns.db.fontStyle or "GLASS")) end
        barPanel:SetChecked(ns.db.barPanel)
        for key, b in pairs(portraitButtons) do Mark(b, key == (ns.db.ufPortrait or "3D")) end
        for key, b in pairs(frameStyleButtons) do Mark(b, key == ((ns.db.ufStyle == "CLASSIC") and "CLASSIC" or "STARCUT")) end
        -- the three chips show the colors that an edit would start from
        local t = ns.themes[ns.db.theme]
        local def = (t and t.custom) and ns.db.customThemes[t.customName] or nil
        local ar, ag, ab = ns:AccentColor(ns.db.accent or "AZURE")
        local now = { panel = def and def.panel or { th.bg[1], th.bg[2], th.bg[3] }, rim = def and def.rim or { th.border[1], th.border[2], th.border[3] },
                      accent = { ar, ag, ab } }
        for part, b in pairs(partButtons) do b.chip:SetVertexColor(now[part][1], now[part][2], now[part][3], 1) end
        local family = def and def.style or ns.style
        for key, b in pairs(styleButtons) do Mark(b, key == family) end
    end
    -- Portraits and class colors: what the portraits show, and each class's own color (this used to be
    -- the Class Colors tab, and the portrait choice was a section of its own).
    -- Theme by place: a theme for cities, dungeons, raids and everywhere else (see Journey.lua)
    local TY = EY - 60 - 24 - 16
    Header(page, "Theme by place", 0, TY, { sub = true })
    local tbp = ns:CreateCheckbox(page, "Switch by itself as I travel", ns.db.themeByPlace, function(v)
        ns.db.themeByPlace = v
        if v then ns.db.themeHome = ns.db.themeHome or ns.db.theme; ns:ApplyPlaceTheme() end
        Refresh()
    end)
    tbp:SetWidth(300)
    tbp:SetPoint("TOPLEFT", 200, TY + 2)
    local placeRows = {}
    for i, def in ipairs(ns.PLACES or {}) do
        local y = TY - 30 - (i - 1) * 28
        local label = page:CreateFontString(nil, "OVERLAY")
        ns:Font(label, 12)
        ns:Paint(label, "SetTextColor", "dim")
        label:SetPoint("TOPLEFT", 0, y - 5)
        label:SetText(ns:Tr(def[2]))
        local now = page:CreateFontString(nil, "OVERLAY")
        ns:Font(now, 12)
        now:SetPoint("TOPLEFT", 150, y - 5)
        now:SetWidth(240)
        now:SetJustifyH("LEFT")
        local use = ns:CreateButton(page, "Use my current theme", 170, 22, function()
            ns.db.placeThemes[def[1]] = ns.db.theme
            Refresh()
        end)
        use:SetPoint("TOPLEFT", 400, y)
        local clear = ns:CreateButton(page, "Clear", 70, 22, function()
            ns.db.placeThemes[def[1]] = nil
            if ns.db.themeByPlace and ns.ApplyPlaceTheme then ns:ApplyPlaceTheme() end      -- (standing there now: back at once)
            Refresh()
        end)
        clear:SetPoint("LEFT", use, "RIGHT", 6, 0)
        placeRows[def[1]] = now
    end
    page.placeRows = placeRows
    local lookRefresh0 = Refresh
    Refresh = function()
        lookRefresh0()
        tbp:SetChecked(ns.db.themeByPlace)
        for key, fs in pairs(placeRows) do
            local t = ns.db.placeThemes[key] and ns.themes[ns.db.placeThemes[key]]
            if t then fs:SetText(ns:ThemeName(ns.db.placeThemes[key], "plain")); ns:Paint(fs, "SetTextColor", "text")
            else fs:SetText(ns:Tr(key == "world" and "the theme you choose above" or "no change")); ns:Paint(fs, "SetTextColor", "faint") end
        end
    end
    local PY = TY - 30 - 4 * 28 - 16
    Header(page, "Frame style", 0, PY)                      -- (shown with the unit frames, in Frames and bars)
    -- the unit frames' style: Starcut (bars cut to points, a diamond portrait) or Classic (the box)
    local slabel = page:CreateFontString(nil, "OVERLAY")
    ns:Font(slabel, 12)
    ns:Paint(slabel, "SetTextColor", "dim")
    slabel:SetPoint("TOPLEFT", 0, PY - 36)
    slabel:SetText(ns:Tr("Frame style"))
    for i, def in ipairs({ { "STARCUT", "Starcut" }, { "CLASSIC", "Classic" } }) do
        local b = Choice(def[2], 150, function()
            ns.db.ufStyle = def[1]
            if InCombatLockdown() then ns:Print("The frame style will change when the fight is over.") end
            ns:ApplyFrameStyle()
            Refresh()
        end)
        b:SetPoint("TOPLEFT", 90 + (i - 1) * 156, PY - 30)
        frameStyleButtons[def[1]] = b
    end
    page.frameStyleButtons = frameStyleButtons
    PY = PY - 36                                              -- (the rows below move down one)
    local plabel = page:CreateFontString(nil, "OVERLAY")
    ns:Font(plabel, 12)
    ns:Paint(plabel, "SetTextColor", "dim")
    plabel:SetPoint("TOPLEFT", 0, PY - 36)
    plabel:SetText(ns:Tr("Portrait"))
    for i, def in ipairs({ { "3D", "3D model" }, { "2D", "2D picture" }, { "CLASS", "Class emblem" }, { "OFF", "None" } }) do
        local b = Choice(def[2], 150, function()
            ns.db.ufPortrait = def[1]
            if ns.RefreshUnitFrames then ns:RefreshUnitFrames() end
            Refresh()
        end)
        b:SetPoint("TOPLEFT", 90 + (i - 1) * 156, PY - 30)
        portraitButtons[def[1]] = b
    end
    local CC_H = 36 + #ns.classOrder * 24 + 8
    Header(page, "Class colors", 0, PY - 70)
    local cc = CreateFrame("Frame", nil, page)
    cc:SetPoint("TOPLEFT", 0, PY - 70 - 26)
    cc:SetSize(736, CC_H)
    BuildColors(cc)
    page.classColors = cc
    -- Contrast and text size (12.0; since 12.1 shown in Accessibility › Seeing, with the rest there).
    local AY = PY - 70 - 26 - CC_H - 24
    Header(page, "Contrast and text size", 0, AY)
    local access = {}
    local hlabel = page:CreateFontString(nil, "OVERLAY")
    ns:Font(hlabel, 12)
    ns:Paint(hlabel, "SetTextColor", "dim")
    hlabel:SetPoint("TOPLEFT", 0, AY - 36)
    hlabel:SetText(ns:Tr("High contrast"))
    for i, key in ipairs({ "CONTRAST", "FCONTRAST" }) do
        local b = Choice(ns:ThemeName(key), 200, function()
            local t = ns.themes[key]
            if not t then return end
            ns.db.theme = key
            ns.db.accent = t.accent or ns.db.accent
            if ns.NoteHomeTheme then ns:NoteHomeTheme() end
            Changed()
        end)
        b:SetPoint("TOPLEFT", 120 + (i - 1) * 206, AY - 30)
        access[key] = b
    end
    local tlabel = page:CreateFontString(nil, "OVERLAY")
    ns:Font(tlabel, 12)
    ns:Paint(tlabel, "SetTextColor", "dim")
    tlabel:SetPoint("TOPLEFT", 0, AY - 70)
    tlabel:SetText(ns:Tr("Text size"))
    for i, size in ipairs({ 100, 120, 140 }) do
        local b = Choice(size .. "%", 96, function()
            ns:SizeCommand("fontScale", tostring(size), 70, 150)
            Refresh()
        end)
        b:SetPoint("TOPLEFT", 120 + (i - 1) * 102, AY - 64)
        access["size" .. size] = b
    end
    local snote = page:CreateFontString(nil, "OVERLAY")
    ns:Font(snote, 10)
    ns:Paint(snote, "SetTextColor", "faint")
    snote:SetPoint("LEFT", access.size140, "RIGHT", 10, 0)
    snote:SetText(ns:Tr("Any size from 70 to 150: /fgui textsize."))
    page.access = access

    local lookRefresh = Refresh
    page.Refresh = function()
        lookRefresh()
        if cc.Refresh then cc.Refresh() end
    end
    ns.lookPage = page                                       -- (lets the page be checked without the mouse)
    page.contentHeight = -(AY - 96) + 12                     -- down to the foot of Contrast and text size
    if page.area then page.area:SetContentHeight(page.contentHeight) end
    Refresh()
end


-- Page 4: class colors -------------------------------------------------------------------------------
function BuildColors(page)
    local th = ns.theme
    local rows, sliders, selected, syncing = {}, {}, nil, false
    local preview, emblem, title, customNote

    local intro = page:CreateFontString(nil, "OVERLAY")
    ns:Font(intro, 12)
    intro:SetPoint("TOPLEFT", 0, 0)
    intro:SetText(ns:Tr("Pick a class, then set its color. This changes Fantasy Glass UI's frames, emblems and class theme; the game's own windows keep theirs."))
    ns:Paint(intro, "SetTextColor", "dim")
    intro:SetWidth(730)
    intro:SetJustifyH("LEFT")

    local function ClassName(token)
        local n = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]
        if type(n) == "string" then return n end
        return token:sub(1, 1) .. token:sub(2):lower()
    end

    local function Paint()
        for token, row in pairs(rows) do
            local r, g, b = ns:ClassRGB(token)
            row.swatch:SetBackdropColor(r or 1, g or 1, b or 1, 1)
            row.name:SetTextColor(r or 1, g or 1, b or 1)
            row.custom:SetText(ns.db.classColors[token] and ns:Tr("custom") or "")
            if token == selected then ns:Paint(row.bg, "SetVertexColor", "@accent", 0.22) else row.bg:SetVertexColor(1, 1, 1, 0) end
        end
        if not selected then return end
        local r, g, b = ns:ClassRGB(selected)
        r, g, b = r or 1, g or 1, b or 1
        title:SetText(ClassName(selected))
        title:SetTextColor(r, g, b)
        preview:SetStatusBarColor(r, g, b)
        emblem:SetClass(selected, r, g, b)
        customNote:SetText(ns:Tr(ns.db.classColors[selected] and "Custom color" or "Game default"))
        syncing = true                                   -- move the sliders without treating it as an edit
        sliders[1].slider:SetValue(math.floor(r * 255 + 0.5))
        sliders[2].slider:SetValue(math.floor(g * 255 + 0.5))
        sliders[3].slider:SetValue(math.floor(b * 255 + 0.5))
        syncing = false
    end

    local function Changed()
        Paint()
        if ns.RefreshUnitFrames and not InCombatLockdown() then ns:RefreshUnitFrames() end
        O.frame.note:Show()
    end

    -- class list
    local i = 0
    for _, token in ipairs(ns.classOrder) do
        if ns:DefaultClassRGB(token) then                 -- only classes this client knows
            i = i + 1
            local row = CreateFrame("Button", nil, page)
            row:SetSize(250, 22)
            row:SetPoint("TOPLEFT", 0, -36 - (i - 1) * 24)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetTexture(ns.FLAT)
            row.bg:SetVertexColor(1, 1, 1, 0)
            row.swatch = CreateFrame("Frame", nil, row, ns.template)
            row.swatch:SetSize(26, 16)
            row.swatch:SetPoint("LEFT", 4, 0)
            row.swatch:SetBackdrop(ns.BACKDROP)
            row.swatch:SetBackdropBorderColor(0, 0, 0, 1)
            row.name = row:CreateFontString(nil, "OVERLAY")
            ns:Font(row.name, 13)
            row.name:SetPoint("LEFT", row.swatch, "RIGHT", 10, 0)
            row.name:SetText(ClassName(token))
            row.custom = row:CreateFontString(nil, "OVERLAY")
            ns:Font(row.custom, 10)
            row.custom:SetPoint("RIGHT", -6, 0)
            ns:Paint(row.custom, "SetTextColor", "faint")
            row:SetScript("OnClick", function() selected = token; Paint() end)
            rows[token] = row
            selected = selected or token
        end
    end

    -- editor
    local X = 290
    title = page:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 20, true)
    title:SetPoint("TOPLEFT", X + 70, -44)
    customNote = page:CreateFontString(nil, "OVERLAY")
    ns:Font(customNote, 11)
    customNote:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    ns:Paint(customNote, "SetTextColor", "faint")

    local box = CreateFrame("Frame", nil, page)              -- the class's medallion, as the portraits show it
    box:SetSize(58, 58)
    box:SetPoint("TOPLEFT", X, -36)
    emblem = ns:CreateEmblem(box)
    page.emblem = emblem

    preview = ns:NewStatusBar(page, true)
    preview:SetSize(420, 26)
    preview:SetPoint("TOPLEFT", X, -104)
    preview:SetMinMaxValues(0, 1)
    preview:SetValue(0.8)
    local sample = ns:NewText(preview, 13, "LEFT")
    sample:SetPoint("LEFT", 8, 0)
    sample:SetText(ns:Tr("Health bar preview"))

    local function Component(index, label, y)
        local c = ns:CreateSlider(page, label, 0, 255, 1, 255, "%d", function(v)
            if syncing or not selected then return end
            local r, g, b = ns:ClassRGB(selected)
            local rgb = { r or 1, g or 1, b or 1 }
            rgb[index] = v / 255
            ns.db.classColors[selected] = rgb
            Changed()
        end)
        c:SetPoint("TOPLEFT", X, y)
        c:SetWidth(420)
        c.slider:SetWidth(420)
        sliders[index] = c
    end
    Component(1, "Red", -150)
    Component(2, "Green", -192)
    Component(3, "Blue", -234)

    -- the game's color wheel, for those who prefer it
    local wheel = ns:CreateButton(page, "Color wheel...", 130, 24, function()
        if not selected or type(ColorPickerFrame) ~= "table" then return end
        local token = selected
        local r, g, b = ns:ClassRGB(token)
        local before = ns.db.classColors[token]
        local function apply()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            if type(nr) == "number" then ns.db.classColors[token] = { nr, ng, nb }; Changed() end
        end
        local function cancel()
            ns.db.classColors[token] = before
            Changed()
        end
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({ r = r or 1, g = g or 1, b = b or 1, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel })
        elseif ColorPickerFrame.SetColorRGB then
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc, ColorPickerFrame.hasOpacity = apply, cancel, false
            ColorPickerFrame:SetColorRGB(r or 1, g or 1, b or 1)
            ColorPickerFrame:Show()
        end
    end)
    wheel:SetPoint("TOPLEFT", X, -286)
    local reset = ns:CreateButton(page, "Reset this class", 130, 24, function()
        if selected then ns.db.classColors[selected] = nil; Changed() end
    end)
    reset:SetPoint("LEFT", wheel, "RIGHT", 10, 0)
    local resetAll = ns:CreateButton(page, "Reset all", 130, 24, ns:ConfirmClick(function()
        ns.db.classColors = {}
        Changed()
    end))
    resetAll:SetPoint("LEFT", reset, "RIGHT", 10, 0)

    page.Refresh = Paint
    Paint()
end
O.BuildLook = BuildLook
