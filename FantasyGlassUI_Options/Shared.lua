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
    local th = ns.theme
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 14, true)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(ns:Tr(text))
    ns:Paint(fs, "SetTextColor", "@accent")
    ns:IndexOption(text, fs)                                 -- (section headings can be searched for too)
    if ns.NoteSection and not (opts and opts.sub) then ns.NoteSection(parent, (opts and opts.nav) or text, x, y, fs) end
    return fs
end

function O.ShowPage(id)
    local th = ns.theme
    for key, page in pairs(O.pages) do
        if key == id then page:Show() else page:Hide() end
    end
    for key, b in pairs(O.tabButtons) do b:SetSelected(key == id) end
    if O.frame then O.frame.currentPage = id end
    if type(ns.root) == "table" and O.pages[id] then ns.root.optionsPage = id end      -- (opens there next time)
    if O.pages[id] and O.pages[id].Refresh then O.pages[id].Refresh() end
    if O.pages[id] and O.pages[id].NavRefresh then O.pages[id].NavRefresh() end
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
function O.ThemeSwatch(b)
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
