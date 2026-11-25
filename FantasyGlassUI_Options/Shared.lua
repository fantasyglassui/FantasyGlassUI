-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- What the options pages share: the window, its pages and tab buttons, headings and page switching.
-- The pages are built in their own files (Features, Look, Layout and Profiles, Combat); Config.lua
-- makes the window and puts them in it.
local O = { pages = {}, tabButtons = {} }
ns.optUI = O

-- opts.nav: the name this heading's section has in the list down the left (when it differs);
-- opts.sub: a heading inside a section, not a section of its own.
function O.Header(parent, text, x, y, opts)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 13, true)                                    -- (12.3) a section label: 13, secondary, upper-case
    fs:SetPoint("TOPLEFT", x, y)
    local shown = ns:Tr(text)
    local lang = ns:Language()
    if lang == "auto" then lang = GetLocale and GetLocale() or "enUS" end
    if type(shown) == "string" and (lang == "enUS" or lang == "enGB") then shown = string.upper(shown) end     -- (only English: the game's upper-casing is byte-wise, so other languages keep their own case)
    fs:SetText(shown)
    ns:Paint(fs, "SetTextColor", "dim")
    ns:IndexOption(text, fs)                                 -- (section headings can be searched for too)
    if ns.NoteSection and not (opts and opts.sub) then ns.NoteSection(parent, (opts and opts.nav) or text, x, y, fs) end
    O.Mark(parent, text, y, fs, x)
    return fs
end
-- Every heading (and every mark: a place on a page with no heading of its own) is noted with where
-- it is, so the settings window can show a page from one of them to another (see Config.lua).
function O.Mark(parent, text, y, fs, x)
    if type(parent) ~= "table" then return end
    local list = rawget(parent, "allHeads")
    if not list then list = {}; rawset(parent, "allHeads", list) end
    list[#list + 1] = { text = text, y = tonumber(y) or 0, x = x or 0, fs = fs }
    if parent == O.buildingSheet and (x or 0) == 0 then ns.indexingHead = text end      -- (what is made next is under this heading)
end
-- The slice of a page from one heading to the one after `to` (or to its foot): top and height.
function O.Band(sheet, from, to)
    local heads = {}
    for _, h in ipairs(rawget(sheet, "allHeads") or {}) do if (h.x or 0) == 0 then heads[#heads + 1] = h end end
    table.sort(heads, function(a, b) return a.y > b.y end)
    local total = tonumber(rawget(sheet, "contentHeight")) or 540
    if not from then return 0, total end
    local top, bottom
    for i, h in ipairs(heads) do
        if h.text == from and not top then top = math.max(0, -h.y - 4) end
        if top and h.text == (to or from) then
            local after = heads[i + 1]
            bottom = after and math.max(0, -after.y - 4) or total
            break
        end
    end
    if not top then return nil end
    return top, math.max(1, (bottom or total) - top)
end

-- The pages the window builds (Look, Layout, Combat, Profiles, Bars and frames, Tools, Guide) are not
-- shown as they are: the sections show slices of them (see Config.lua). Showing a page by its old
-- name opens the section it starts in.
function O.ShowPage(id)
    if O.OpenPage then return O.OpenPage(id) end
end

-- Hover help for a button or box: a title and a line or two of explanation.
function O.Tip(widget, title, text)
    if type(widget) ~= "table" or not widget.HookScript then return end
    widget:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns:Tr(title))
        if text then GameTooltip:AddLine(ns:Tr(text), 1, 1, 1, true) end
        GameTooltip:Show()
    end)
    widget:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- A small picture of a theme on its button (11.9): its panel color in its edge color, a line of its
-- accent along the foot, and the mark of its family (glass: a lit top edge; fantasy: gold studs at
-- the top corners; celestial: a star point). On the Look tab and in the setup.
-- With `tile` it is the picture on the Themes page instead (12.3): 52 px, the panel colour with a
-- top edge and two bars in the rim colour, and three star dots for a Celestial theme. Its colours are the
-- theme's own, set straight on the textures (never painted with a role: the settings window wears a
-- look of its own, and a theme's picture must not).
function O.ThemeSwatch(b, tile)
    if tile then
        local t = CreateFrame("Frame", nil, b)
        t.tile = true
        t:SetSize(52, 52)
        t:SetPoint("TOP", b, "TOP", 0, 0)
        local function Part(layer, sub) local x = t:CreateTexture(nil, layer, nil, sub); x:SetTexture(ns.FLAT); return x end
        t.fill = Part("ARTWORK", 0); t.fill:SetAllPoints()
        t.top = Part("ARTWORK", 1); t.top:SetPoint("TOPLEFT", 0, 0); t.top:SetPoint("TOPRIGHT", 0, 0); t.top:SetHeight(3)
        t.bars = {}
        for i, w in ipairs({ 34, 22 }) do
            local bar = Part("ARTWORK", 1)
            bar:SetSize(w, 5)
            bar:SetPoint("TOPLEFT", 9, -14 - (i - 1) * 11)
            t.bars[i] = bar
        end
        t.stars = {}
        for i, at in ipairs({ { 38, -30 }, { 30, -40 }, { 43, -43 } }) do
            local d = t:CreateTexture(nil, "OVERLAY")
            d:SetTexture(ns.MEDIA .. "dot.tga")
            d:SetSize(i == 1 and 6 or 4, i == 1 and 6 or 4)
            d:SetPoint("CENTER", t, "TOPLEFT", at[1], at[2])
            t.stars[i] = d
        end
        b.swatch = t
        return t
    end
    local s = CreateFrame("Frame", nil, b)
    s:SetSize(26, 16)
    s:SetPoint("LEFT", 5, 0)
    local function Tex(layer, sub) local t = s:CreateTexture(nil, layer, nil, sub); t:SetTexture(ns.FLAT); return t end
    s.edge = Tex("ARTWORK", 0); s.edge:SetAllPoints()
    s.fill = Tex("ARTWORK", 1); s.fill:SetPoint("TOPLEFT", 1, -1); s.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    s.accent = Tex("ARTWORK", 2); s.accent:SetPoint("BOTTOMLEFT", 1, 1); s.accent:SetPoint("BOTTOMRIGHT", -1, 1); s.accent:SetHeight(2)
    s.gloss = Tex("ARTWORK", 3); s.gloss:SetPoint("TOPLEFT", 1, -1); s.gloss:SetPoint("TOPRIGHT", -1, -1); s.gloss:SetHeight(1)
    s.studs = {}
    for k, point in ipairs({ "TOPLEFT", "TOPRIGHT" }) do
        local d = s:CreateTexture(nil, "OVERLAY")
        d:SetTexture(ns.MEDIA .. "dot.tga")
        d:SetSize(5, 5)
        d:SetPoint("CENTER", s, point, (k == 1) and 3 or -3, -3)
        s.studs[k] = d
    end
    s.rune = s:CreateTexture(nil, "OVERLAY")
    s.rune:SetTexture(ns.MEDIA .. "sparkle.tga")              -- (a star point, for the Celestial family)
    s.rune:SetSize(12, 12)
    s.rune:SetPoint("CENTER", 0, 1)
    s.halo = s:CreateTexture(nil, "OVERLAY", nil, -1)
    s.halo:SetTexture(ns.MEDIA .. "dot.tga")
    s.halo:SetSize(14, 14)
    s.halo:SetPoint("CENTER", 0, 1)
    if s.halo.SetBlendMode then s.halo:SetBlendMode("ADD") end
    b.swatch = s
    b.text:ClearAllPoints()
    b.text:SetPoint("LEFT", s, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
    if b.text.SetJustifyH then b.text:SetJustifyH("LEFT") end
    return s
end
function O.ShowThemeSwatch(s, key)
    local c = ns:ThemeColors(key)
    if not c then s:Hide(); return end
    s:Show()
    if s.tile then
        s.key, s.panel, s.rim = key, c.bg, c.border          -- (what it was given: the theme's own, never a role)
        s.fill:SetVertexColor(c.bg[1], c.bg[2], c.bg[3], 1)
        s.top:SetVertexColor(c.border[1], c.border[2], c.border[3], 1)
        for _, bar in ipairs(s.bars) do bar:SetVertexColor(c.border[1], c.border[2], c.border[3], 1) end
        for _, d in ipairs(s.stars) do d:SetVertexColor(c.accent[1], c.accent[2], c.accent[3], 1); d:SetShown(c.style == "CELESTIAL") end
        return
    end
    s.edge:SetVertexColor(c.border[1], c.border[2], c.border[3], 1)
    s.fill:SetVertexColor(c.bg[1], c.bg[2], c.bg[3], 1)
    s.accent:SetVertexColor(c.accent[1], c.accent[2], c.accent[3], 1)
    s.gloss:SetVertexColor(1, 1, 1, 0.45)
    s.gloss:SetShown(c.style == "GLASS")
    for _, d in ipairs(s.studs) do d:SetVertexColor(c.border[1], c.border[2], c.border[3], 1); d:SetShown(c.style == "FANTASY") end
    s.rune:SetVertexColor(c.accent[1], c.accent[2], c.accent[3], 1)
    s.halo:SetVertexColor(c.accent[1], c.accent[2], c.accent[3], 0.5)
    s.rune:SetShown(c.style == "CELESTIAL"); s.halo:SetShown(c.style == "CELESTIAL")
end
