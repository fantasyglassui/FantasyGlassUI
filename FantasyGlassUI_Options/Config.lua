-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local O = ns.optUI

-- The settings window (12.0): the categories down the left, with the sections of the one that is open
-- under it, and the section on the right. Home, the first entry, has a card for each category. The
-- pages built in LookPage, LayoutPage, CombatPage, Bars and Tools.lua are not shown as they are: each
-- section shows the slices of them it needs (see Categories.lua and FeaturesPage.lua).
local VIEW_H = 542
O.VIEW_H = VIEW_H
local W, H = 1000, 680
local SIDE_X, SIDE_W = 14, 204
local CONTENT_X = SIDE_X + SIDE_W + 14

-- Is a category or section shown? (simple settings: those with an everyday switch, and a few more)
local function SectionShown(sec)
    if not ns:SettingsSimple() or sec.simple then return true end
    for _, key in ipairs(sec.keys or {}) do if ns.simpleFeatures[key] and not ns:FeatureHidden(key) then return true end end
    return false
end
local function CategoryShown(cat)
    if cat.home then return true end
    if cat.guide then return ns.GuideUnlocked and ns:GuideUnlocked() and true or false end
    if cat.allOnly and ns:SettingsSimple() then return false end
    for _, sec in ipairs(cat.sections or {}) do if SectionShown(sec) then return true end end
    return false
end
O.SectionShown, O.CategoryShown = SectionShown, CategoryShown
-- How many of a category's switches are on, of those shown.
function O.CategoryCount(cat)
    local on, of = 0, 0
    for _, sec in ipairs(cat.sections or {}) do
        for _, key in ipairs(sec.keys or {}) do
            if not ns:FeatureHidden(key) and (not ns:SettingsSimple() or ns.simpleFeatures[key]) then
                of = of + 1
                if ns.db[key] then on = on + 1 end
            end
        end
    end
    return on, of
end
function O.CategoryHasSettings(cat)
    for _, sec in ipairs(cat.sections or {}) do if #(sec.rows or {}) > 0 then return true end end
    return false
end

-- Back to how it came: every switch and slider of a category (lists, rules, designs and places stay).
function O.ResetCategory(cat)
    if type(cat) ~= "table" then return 0 end
    local changed, reload = 0, false
    for _, sec in ipairs(cat.sections or {}) do
        for _, name in ipairs(sec.rows or {}) do
            local def = ns.settingRows[name]
            if not (def and (def.set or def.run)) then
                local want = ns.defaults[name]
                if want == nil and def then want = def.default end
                if ns.db[name] ~= want and not ns:FeatureHidden(name) then
                    ns.db[name] = want
                    changed = changed + 1
                    if not def and not ns.featureInstant[name] then reload = true; O.NeedReload(name) end
                    if def and def.apply then pcall(def.apply, want) end
                end
            end
        end
    end
    if changed > 0 then
        if ns.ApplyInstant then pcall(ns.ApplyInstant, ns) end
        if ns.Retheme then pcall(ns.Retheme, ns) end
        O.NoteChange(true)
        O.RefreshAll()
    end
    O.resetCount = changed
    return changed, reload
end

-- Undo last change: what changed in the settings while the window is open, most recent last.
local watch = { stack = {} }
O.changes = watch.stack
local function Scalar(v) local t = type(v); return t == "boolean" or t == "number" or t == "string" end
local function Snap()
    local t = {}
    for k, v in pairs(ns.db) do if Scalar(v) then t[k] = v end end
    return t
end
local NAMES = { theme = "Theme", accent = "Accent color", fontStyle = "Lettering", ufStyle = "Frame style", ufPortrait = "Portrait",
    microMode = "Game menu & bag bar", barPanel = "Frame behind action bars", afkDelay = "AFK screen", afkFlag = "Also mark my character as away then" }
function O.ChangeLabel(key)
    return O.RowLabel(key) or NAMES[key] or key
end
function O.ChangeValue(key, v)
    if v == nil then return ns:Tr("how it came") end
    if type(v) == "boolean" then return ns:Tr(v and "on" or "off") end
    if key == "theme" and ns.ThemeName and ns.themes[v] then return ns:ThemeName(v, "plain") end
    return tostring(v)
end
function O.NoteChange(quiet)
    if watch.profile ~= ns.profile or not watch.snap then           -- (another profile: nothing to compare with)
        watch.snap, watch.profile = Snap(), ns.profile
        return
    end
    local now = watch.snap
    for k, v in pairs(ns.db) do
        if Scalar(v) and now[k] ~= v then
            if not quiet then watch.stack[#watch.stack + 1] = { key = k, old = now[k], new = v, profile = ns.profile } end
            now[k] = v
        end
    end
    for k, v in pairs(now) do
        if ns.db[k] == nil then
            if not quiet then watch.stack[#watch.stack + 1] = { key = k, old = v, profile = ns.profile } end
            now[k] = nil
        end
    end
    while #watch.stack > 40 do table.remove(watch.stack, 1) end
    if O.DrawUndo then O.DrawUndo() end
end
function O.Undo()
    O.NoteChange()
    local last = table.remove(watch.stack)
    while last and last.profile ~= ns.profile do last = table.remove(watch.stack) end
    if not last then if O.DrawUndo then O.DrawUndo() end return nil end
    local key = last.key
    ns.db[key] = last.old
    watch.snap[key] = last.old
    local def = ns.settingRows[key]
    if def and def.apply then pcall(def.apply, last.old) end
    if ns.featureLabels[key] and not ns.featureInstant[key] then O.NeedReload(key) end
    if ns.ApplyInstant then pcall(ns.ApplyInstant, ns) end
    if not ns.featureLabels[key] and ns.Retheme then pcall(ns.Retheme, ns) end
    O.RefreshAll()
    if O.DrawUndo then O.DrawUndo() end
    return last
end

-- "1 change needs a reload", by the Reload button.
local pending, generic = {}, 0
function O.NeedReload(key)
    if key then pending[key] = true else generic = generic + 1; pending["#" .. generic] = true end
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    O.reloadCount = n
    if O.frame and O.frame.note then
        O.frame.note:SetText("|cffffd100" .. format(ns:TrN(n, "%d change needs a reload", "%d changes need a reload"), n) .. "|r")
        O.frame.note.ShowNow(O.frame.note)
    end
end

-- Every page shows the settings as they are now (the setup, an undo or a reset may have changed them).
function O.RefreshAll()
    if O.sections and O.sections.Refresh then pcall(O.sections.Refresh) end
    if O.home and O.home.Refresh then pcall(O.home.Refresh) end
    if O.DrawSidebar then O.DrawSidebar() end
end

local function Build()
    O.frame = CreateFrame("Frame", "FantasyGlassUIConfig", UIParent, ns.template)
    ns.configFrame = O.frame
    local size = type(ns.root) == "table" and type(ns.root.optionsSize) == "table" and ns.root.optionsSize or nil
    O.frame:SetSize(size and tonumber(size[1]) or W, size and tonumber(size[2]) or H)
    O.frame:SetPoint("CENTER")
    O.frame:SetFrameStrata("DIALOG")
    O.frame:SetBackdrop(ns.BACKDROP)
    ns:Paint(O.frame, "SetBackdropColor", "window", 0.97)
    ns:Paint(O.frame, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(O.frame)
    O.frame:EnableMouse(true)
    O.frame:SetMovable(true)
    O.frame:SetClampedToScreen(true)
    O.frame:RegisterForDrag("LeftButton")
    O.frame:SetScript("OnDragStart", O.frame.StartMoving)
    O.frame:SetScript("OnDragStop", O.frame.StopMovingOrSizing)
    ns:KeepPlace(O.frame, "Options")
    tinsert(UISpecialFrames, "FantasyGlassUIConfig")

    -- the header: the add-on's name, the profile being edited, simple or all options, language, close
    local logo = O.frame:CreateTexture(nil, "OVERLAY")
    logo:SetSize(24, 24)
    logo:SetPoint("TOPLEFT", 16, -14)
    logo:SetTexture(ns.MEDIA .. "icon.tga")
    local title = O.frame:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 17, true)
    title:SetPoint("TOPLEFT", 48, -18)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(false) end
    O.frame.title = title
    local chip = ns:CreateButton(O.frame, "", 150, 22, function() O.Open("layout:Profiles") end)
    chip:SetPoint("LEFT", title, "RIGHT", 14, 0)
    ns:Font(chip.text, 11)
    chip:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(ns:Tr("The profile these settings are saved in"))
        local r = ns.roles[ns.db.role]
        GameTooltip:AddLine(ns:Tr("Role:") .. " " .. (r and ns:Tr(r.label) or ns:Tr("not set")), 1, 1, 1)
        GameTooltip:AddLine(ns:Tr("Click to change profile, or make a new one."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    chip:HookScript("OnLeave", function() GameTooltip:Hide() end)
    O.frame.profileChip = chip
    local function Heading()
        title:SetText(ns:AccentHex() .. "Fantasy Glass|r UI  |cff9c8c6cv" .. ns.version .. "|r")
        chip.text:SetText(ns:Tr("Profile:") .. " " .. ns:AccentHex() .. tostring(ns.profile) .. "|r")
        local w = chip.text.GetStringWidth and chip.text:GetStringWidth()
        if type(w) == "number" and w > 0 then chip:SetWidth(math.min(240, math.floor(w + 22))) end
    end
    Heading()
    O.frame:HookScript("OnShow", Heading)
    ns:OnTheme(function() if O.frame:IsShown() then Heading() end end)

    local close = ns:CreateButton(O.frame, "X", 24, 24, function() O.frame:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -13)

    -- Language: the word on the button is never translated, so the way back can be found by someone
    -- who picked a language they cannot read.
    local langList
    local langBtn = ns:CreateButton(O.frame, "Language", 100, 24, function(self)
        if langList and langList:IsShown() then langList:Hide() return end
        if not langList then
            langList = CreateFrame("Frame", nil, O.frame, ns.template)
            langList:SetFrameStrata("FULLSCREEN_DIALOG")
            langList:SetBackdrop(ns.BACKDROP)
            ns:Paint(langList, "SetBackdropColor", "@bg", 1)
            ns:Paint(langList, "SetBackdropBorderColor", "@accent", 1)
            langList:SetSize(178, #ns.languages * 24 + 10)
            langList:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -2)
            langList.rows = {}
            for i, def in ipairs(ns.languages) do
                local row = ns:CreateButton(langList, "", 168, 22, function()
                    langList:Hide()
                    if ns:SetLanguage(def[1]) then
                        O.frame.RefreshLanguage()
                        O.NeedReload("language")                    -- labels change when the interface reloads
                    end
                end)
                row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 24)
                langList.rows[def[1]] = row
            end
        end
        for code, row in pairs(langList.rows) do
            row.text:SetText(ns:LanguageName(code))
            ns:LanguageFont(row.text, code)                  -- (Korean and Chinese in a face that has their letters)
            if code == ns:Language() then ns:Paint(row, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(row, "SetBackdropBorderColor", "@border", 1) end
        end
        langList:Show()
    end)
    langBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
    langBtn.text:SetText("Language")                         -- (set directly: this one word is never translated)
    function O.frame.RefreshLanguage() end
    O.frame.languageButton = langBtn
    langBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(ns:Tr("Language") .. ": " .. ns:LanguageName(ns:Language()))
        GameTooltip:AddLine(ns:Tr("The language Fantasy Glass UI's own labels are shown in. A change takes effect when the interface reloads."), 1, 1, 1, true)
        GameTooltip:AddLine(ns:Tr("Names of items, spells and places come from the game, in the game's language."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    langBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- Simple or all options: two buttons side by side, kept for the account. A new player starts on
    -- simple, one who already knows the add-on on all options. The search always looks through all.
    if type(ns.root) == "table" and ns.root.settingsMode == nil then ns.root.settingsMode = ns.freshInstall and "simple" or "all" end
    local modeAll = ns:CreateButton(O.frame, "All options", 100, 24, function() O.SetSimple(false) end)
    modeAll:SetPoint("RIGHT", langBtn, "LEFT", -14, 0)
    local modeSimple = ns:CreateButton(O.frame, "Simple", 80, 24, function() O.SetSimple(true) end)
    modeSimple:SetPoint("RIGHT", modeAll, "LEFT", -2, 0)
    O.Tip(modeSimple, "Simple", "The options most players look for. The search still finds every one.")
    O.Tip(modeAll, "All options", "Every option there is.")
    O.frame.modeButtons = { simple = modeSimple, all = modeAll }
    local function DrawMode()
        local simple = ns:SettingsSimple()
        for which, b in pairs(O.frame.modeButtons) do
            local on = (which == "simple") == simple
            b.picked = on
            ns:Paint(b, "SetBackdropBorderColor", on and "@accent" or "@border", 1)
            ns:Paint(b.text, "SetTextColor", on and "@accent" or "dim")
        end
    end
    for _, b in pairs(O.frame.modeButtons) do b:HookScript("OnLeave", function() DrawMode() end) end

    local rule = ns:Divider(O.frame, 12)
    rule:SetPoint("TOPLEFT", 16, -48)
    rule:SetPoint("TOPRIGHT", -16, -48)

    -- the reload note, by the Reload button (anything may ask for it: O.frame.note:Show())
    local note = O.frame:CreateFontString(nil, "OVERLAY")
    ns:Font(note, 11)
    note:SetJustifyH("RIGHT")
    O.frame.note = note
    note.ShowNow = note.Show
    note.Show = function() O.NeedReload() end
    note:SetText("")
    note.ShowNow(note)
    function ns.ShowReloadNote() O.NeedReload() end

    -- The pages the sections show slices of. Each is built on a sheet that scrolls, kept out of sight.
    local defs = { { "look", O.BuildLook }, { "layout", O.BuildLayout }, { "combat", O.BuildCombat }, { "profiles", O.BuildProfiles },
                   { "bars", function(page) return ns.BuildBarsPage(page) end },
                   { "tools", function(page) return ns.BuildToolsPage(page) end },
                   { "guide", function(page) return ns.BuildGuidePage(page) end } }
    for _, d in ipairs(defs) do
        local id = d[1]
        local page = CreateFrame("Frame", nil, O.frame)
        page:SetPoint("TOPLEFT", CONTENT_X, -60)
        page:SetSize(736, VIEW_H)
        page:Hide()
        O.pages[id] = page
        ns.indexingTab = id                                  -- (labelled controls made from here on note which page they are on)
        local area, sheet = ns:ScrollArea(page, 736, VIEW_H)
        area:SetPoint("TOPLEFT", 0, 0)
        O.buildingSheet, ns.indexingHead = sheet, nil
        d[2](sheet)
        O.buildingSheet, ns.indexingHead = nil, nil
        page.area, page.sheet = area, sheet
        if type(rawget(sheet, "contentHeight")) ~= "number" then
            sheet.contentHeight = VIEW_H
            area:SetContentHeight(VIEW_H)
        end
        page.Refresh = function() if sheet.Refresh then sheet.Refresh() end end
        sheet.Refresh = rawget(sheet, "Refresh")
        ns.indexingTab = nil
    end

    -- the right side: Home, or a section
    local content = CreateFrame("Frame", nil, O.frame)
    content:SetPoint("TOPLEFT", CONTENT_X, -60)
    content:SetPoint("BOTTOMRIGHT", -16, 52)
    O.content = content
    local sArea, sSheet = ns:ScrollArea(content, 748, VIEW_H)
    sArea:SetPoint("TOPLEFT", 0, 0)
    sArea:SetPoint("BOTTOMRIGHT", -10, 0)
    O.BuildSections(sSheet)
    O.sections = sSheet
    local hArea, hSheet = ns:ScrollArea(content, 748, VIEW_H)
    hArea:SetPoint("TOPLEFT", 0, 0)
    hArea:SetPoint("BOTTOMRIGHT", -10, 0)
    O.BuildHome(hSheet)
    O.home = hSheet
    O.sectionArea, O.homeArea = sArea, hArea

    -- The left side: the search, then the categories, with the sections of the open one under it.
    local side = CreateFrame("Frame", nil, O.frame)
    side:SetPoint("TOPLEFT", SIDE_X, -60)
    side:SetPoint("BOTTOMLEFT", SIDE_X, 52)
    side:SetWidth(SIDE_W)
    O.side = side
    local sideRule = O.frame:CreateTexture(nil, "ARTWORK")
    sideRule:SetTexture(ns.FLAT)
    sideRule:SetWidth(1)
    sideRule:SetPoint("TOPLEFT", side, "TOPRIGHT", 6, 0)
    sideRule:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 6, 0)
    ns:Paint(sideRule, "SetVertexColor", "@border", 0.6)
    local searchBox = ns:CreateEditBox(side, SIDE_W, 24, "Search every option")
    searchBox:SetPoint("TOPLEFT", 0, 0)
    O.frame.searchBox = searchBox
    local catButtons, secButtons = {}, {}
    local function NavButton(list, i, indent, size)
        local b = list[i]
        if b then return b end
        b = CreateFrame("Button", nil, side)
        b:SetSize(SIDE_W, size)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(ns.FLAT)
        ns:Paint(b.bg, "SetVertexColor", "@accent", 0.14)
        b.bar = b:CreateTexture(nil, "ARTWORK")
        b.bar:SetTexture(ns.FLAT)
        b.bar:SetWidth(3)
        b.bar:SetPoint("TOPLEFT", 0, 0)
        b.bar:SetPoint("BOTTOMLEFT", 0, 0)
        ns:Paint(b.bar, "SetVertexColor", "@accent", 1)
        b.count = b:CreateFontString(nil, "OVERLAY")
        ns:Font(b.count, 10)
        b.count:SetPoint("RIGHT", -8, 0)
        ns:Paint(b.count, "SetTextColor", "faint")
        b.text = b:CreateFontString(nil, "OVERLAY")
        ns:Font(b.text, size > 24 and 12 or 11)
        b.text:SetPoint("LEFT", indent, 0)
        b.text:SetWidth(SIDE_W - indent - 44)
        b.text:SetJustifyH("LEFT")
        if b.text.SetWordWrap then b.text:SetWordWrap(false) end
        b.new = ns.NewTag(b)
        b.new:SetPoint("RIGHT", b.count, "LEFT", -4, 0)
        b:SetScript("OnClick", function(self) if self.open then self.open() end end)
        b:SetScript("OnEnter", function(self)
            if not self.picked then ns:Paint(self.text, "SetTextColor", "text") end
            if self.text.IsTruncated and ns.Yes(self.text:IsTruncated()) then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.text:GetText() or "")
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function(self) self.Mark(self.picked); if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        function b.Mark(on)
            b.picked = on
            if on then b.bar:Show(); b.bg:Show(); ns:Paint(b.text, "SetTextColor", "@accent")
            else b.bar:Hide(); b.bg:Hide(); ns:Paint(b.text, "SetTextColor", b.dimmed and "dim" or "text") end
        end
        list[i] = b
        return b
    end
    O.catButtons, O.secButtons = catButtons, secButtons
    function O.DrawSidebar()
        local y, nc, ns2 = -32, 0, 0
        local openCat = O.current and (O.current.home and O.current or O.current.category)
        for _, cat in ipairs(ns.settingsCategories) do
            if CategoryShown(cat) then
                nc = nc + 1
                local b = NavButton(catButtons, nc, 12, 26)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 0, y)
                b.text:SetText(ns:Tr(cat.title))
                b.cat = cat
                local on, of = O.CategoryCount(cat)
                b.count:SetText(of > 0 and (on .. "/" .. of) or "")
                local new = false
                for _, sec in ipairs(cat.sections or {}) do if ns:SectionIsNew(sec) then new = true end end
                b.new:SetShown(new)
                b.open = function() O.Open(cat.id) end
                b.dimmed = false
                b.Mark(openCat == cat and O.current.home == true)
                if openCat == cat and not cat.home then b.Mark(false); ns:Paint(b.text, "SetTextColor", "@accent") end
                b:Show()
                y = y - 27
                if openCat == cat and not cat.home then
                    for _, sec in ipairs(cat.sections or {}) do
                        if SectionShown(sec) then
                            ns2 = ns2 + 1
                            local s = NavButton(secButtons, ns2, 26, 21)
                            s:ClearAllPoints()
                            s:SetPoint("TOPLEFT", 0, y)
                            s.text:SetText(ns:Tr(sec.title))
                            s.sec = sec
                            local son, sof = 0, 0
                            for _, key in ipairs(sec.keys or {}) do
                                if not ns:FeatureHidden(key) and (not ns:SettingsSimple() or ns.simpleFeatures[key]) then
                                    sof = sof + 1; if ns.db[key] then son = son + 1 end
                                end
                            end
                            s.count:SetText(sof > 0 and (son .. "/" .. sof) or "")
                            s.new:SetShown(ns:SectionIsNew(sec))
                            s.open = function() O.Open(sec.id) end
                            s.dimmed = true
                            s.Mark(O.current == sec)
                            s:Show()
                            y = y - 22
                        end
                    end
                    y = y - 4
                end
            end
        end
        for i = nc + 1, #catButtons do catButtons[i]:Hide() end
        for i = ns2 + 1, #secButtons do secButtons[i]:Hide() end
        DrawMode()
    end
    O.RefreshCounts = O.DrawSidebar

    -- Opening a place: Home, a category (its first section), a section, or one of the old page names.
    local OLD = { features = "home", look = "look:Themes", layout = "layout:Moving and scale", profiles = "layout:Profiles",
                  combat = "combat:Cooldowns", bars = "frames:Action bars", tools = "tools:Tools", guide = "guide:Guide",
                  clickcast = "frames:Raid frames", colors = "look:Class colors" }
    O.OLD_PAGES = OLD
    function O.Open(id, asked)
        local place = ns:SettingsSection(id) or ns:SettingsCategory(id)
        if not place and OLD[id] then return O.Open(OLD[id], id) end
        if not place then return false end
        if place.sections and not place.home then                    -- a category: its first section shown
            local first
            for _, sec in ipairs(place.sections) do if SectionShown(sec) then first = sec; break end end
            place = first or place.sections[1]
        end
        if place.home then
            O.sections.GiveBack()
            sArea:Hide(); hArea:Show()
            O.current = place
            O.home.Refresh()
            O.frame.currentPage = asked or "home"
        else
            if not SectionShown(place) or (place.category.allOnly and ns:SettingsSimple()) then O.SetSimple(false) end
            hArea:Hide(); sArea:Show()
            O.current = place
            O.sections.Show(place)
            local host
            for _, block in ipairs(place.blocks or {}) do host = host or block.host or (block.bars and "bars") end
            O.frame.currentPage = asked or host or "features"
        end
        if type(ns.root) == "table" then ns.root.optionsSection = place.home and "home" or place.id end
        O.DrawSidebar()
        return place
    end
    O.OpenPage = function(id) return O.Open(id, id) end

    function O.SetSimple(simple)
        if type(ns.root) == "table" then ns.root.settingsMode = simple and "simple" or "all" end
        local cur = O.current
        if cur and not cur.home and simple and not SectionShown(cur) then
            O.Open(cur.category.id)
        elseif cur and not cur.home then
            O.sections.Show(cur)
        end
        if O.current and not O.current.home and O.current.category.allOnly and simple then O.Open("home") end
        if O.home and O.home.Refresh then O.home.Refresh() end
        O.DrawSidebar()
    end

    -- The foot: setup, report, Discord; then undo, the reload note and Reload.
    local setup = ns:CreateButton(O.frame, "Run setup again", 132, 24, function() O.frame:Hide(); ns:ShowSetup() end)
    O.Tip(setup, "Run setup again", "Opens the first-run setup: how you play, your look, your layout. It starts from your current choices and changes nothing until you click.")
    setup:SetPoint("BOTTOMLEFT", 18, 14)
    local report = ns:CreateButton(O.frame, "Report a problem", 132, 24, function() ns:ProblemReport() end)
    report:SetPoint("LEFT", setup, "RIGHT", 8, 0)
    report:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns:Tr("Report a problem"))
        GameTooltip:AddLine(ns:Tr("Gathers what is needed to look into a problem - what is running, any errors, the settings you changed and your other add-ons - into text you can copy. Nothing is sent by itself: add-ons have no access to the internet."), 1, 1, 1, true)
        if ns:ReportLink() then GameTooltip:AddLine(ns:Tr("The window shows where to send it."), 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    report:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local discord = ns:CreateButton(O.frame, "Discord", 96, 24, function() ns:ShowDiscord() end)
    discord:SetPoint("LEFT", report, "RIGHT", 8, 0)
    O.Tip(discord, "Join the Discord", "Help, ideas, themes to share and other players. Click for the invite to copy: add-ons cannot open web pages themselves.")
    local reload = ns:CreateButton(O.frame, "Reload UI", 110, 26, ReloadUI)
    reload:SetPoint("BOTTOMRIGHT", -24, 13)
    note:SetPoint("RIGHT", reload, "LEFT", -12, 0)
    local undo = ns:CreateButton(O.frame, "Undo last change", 140, 24, function() O.Undo() end)
    undo:SetPoint("RIGHT", note, "LEFT", -12, 0)
    undo:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local last = watch.stack[#watch.stack]
        if last then
            GameTooltip:AddLine(format(ns:Tr("Undo: %s"), ns:Tr(O.ChangeLabel(last.key))))
            GameTooltip:AddLine(format(ns:Tr("Back to %s."), O.ChangeValue(last.key, last.old)), 1, 1, 1, true)
        else
            GameTooltip:AddLine(ns:Tr("Undo last change"))
            GameTooltip:AddLine(ns:Tr("Nothing changed yet. Each change you make here can be taken back, one at a time."), 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    undo:HookScript("OnLeave", function() GameTooltip:Hide() end)
    O.frame.undoButton = undo
    function O.DrawUndo() undo:SetAlpha(#watch.stack > 0 and 1 or 0.45) end
    O.DrawUndo()
    local elapsed = 0
    O.frame:HookScript("OnUpdate", function(_, dt)                -- (changes made anywhere in the window, twice a second)
        elapsed = elapsed + (tonumber(dt) or 0)
        if elapsed < 0.5 then return end
        elapsed = 0
        O.NoteChange()
    end)
    O.frame:HookScript("OnShow", function() watch.snap = nil; O.NoteChange() end)

    -- (12.1) The keyboard, with "Move through the settings with the keyboard" on: Tab and the arrows
    -- move from setting to setting, Space and Enter use one, Left and Right move a slider or step a
    -- choice, Page Up and Page Down change section. Every other key goes on to the game, and in a
    -- fight every key does (the game does not let a window hold keys then).
    local function Sections()
        local list = {}
        for _, cat in ipairs(ns.settingsCategories) do
            if CategoryShown(cat) then
                if cat.home then list[#list + 1] = "home" end
                for _, sec in ipairs(cat.sections or {}) do if SectionShown(sec) then list[#list + 1] = sec.id end end
            end
        end
        return list
    end
    function O.KeyPress(key)
        if not (ns.db and ns.db.keyNav) then return false end
        local page = O.sections
        local onPage = O.current and not O.current.home
        local shift = IsShiftKeyDown and IsShiftKeyDown()
        if key == "TAB" or key == "DOWN" or key == "UP" then
            if not onPage then return false end
            local back = (key == "UP") or (key == "TAB" and shift)
            page.Focus((page.focused or (back and 1 or 0)) + (back and -1 or 1))
            return true
        elseif key == "SPACE" or key == "ENTER" then
            return onPage and page.Use() or false
        elseif key == "LEFT" or key == "RIGHT" then
            return onPage and page.Use(key == "LEFT" and -1 or 1) or false
        elseif key == "PAGEDOWN" or key == "PAGEUP" then
            local list, at = Sections(), 1
            local id = O.current and (O.current.home and "home" or O.current.id)
            for i, v in ipairs(list) do if v == id then at = i end end
            at = ((at - 1 + (key == "PAGEDOWN" and 1 or -1)) % #list) + 1
            O.Open(list[at])
            return true
        end
        return false
    end
    if O.frame.EnableKeyboard then O.frame:EnableKeyboard(true) end
    if O.frame.SetPropagateKeyboardInput and not (InCombatLockdown and InCombatLockdown()) then O.frame:SetPropagateKeyboardInput(true) end
    O.frame:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown and InCombatLockdown() then return end
        local used = O.KeyPress(key)
        if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not used) end
    end)

    -- Drag the corner to make the window bigger or smaller; the size is kept.
    if O.frame.SetResizable then O.frame:SetResizable(true) end
    O.frame:SetResizeBounds(W, 600, 1600, 1200)
    local grip = CreateFrame("Button", nil, O.frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip.tex = grip:CreateTexture(nil, "OVERLAY")
    grip.tex:SetAllPoints()
    grip.tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetScript("OnMouseDown", function() if O.frame.StartSizing then O.frame:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function()
        O.frame:StopMovingOrSizing()
        local w, h = O.frame:GetWidth(), O.frame:GetHeight()
        if type(ns.root) == "table" and type(w) == "number" and type(h) == "number" then ns.root.optionsSize = { math.floor(w), math.floor(h) } end
    end)
    O.Tip(grip, "Drag to resize", "Drag the corner to make the window bigger or smaller. The size is kept.")
    O.frame.grip = grip

    -- Search: one box that finds any setting. Each result says where it lives; Enter goes to the first.
    local results = CreateFrame("Frame", nil, O.frame, ns.template)
    results:SetFrameStrata("FULLSCREEN_DIALOG")
    results:SetBackdrop(ns.BACKDROP)
    ns:Paint(results, "SetBackdropColor", "@bg", 1)
    ns:Paint(results, "SetBackdropBorderColor", "@accent", 1)
    results:SetPoint("TOPLEFT", searchBox, "TOPRIGHT", 8, 0)
    results:SetWidth(470)
    results:Hide()
    results.rows = {}
    local ring = CreateFrame("Frame", nil, O.frame, ns.template)   -- the marker round the setting that was found
    ring:SetFrameStrata("FULLSCREEN_DIALOG")
    ring:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 2 })
    ns:Paint(ring, "SetBackdropBorderColor", "@accent", 1)
    ring:Hide()
    -- the section a search result lives in
    local function Within(frame, holder)
        local f, n = frame, 0
        while type(f) == "table" and f.GetParent and n < 16 do
            if f == holder then return true end
            f = f:GetParent(); n = n + 1
        end
        return false
    end
    function O.SectionOfHit(hit)
        local f = hit and hit.frame
        if type(f) ~= "table" then return nil end
        local sec = rawget(f, "section")
        if sec then return sec end
        local T = ns.toolsPage
        if T then
            if Within(f, T.askFrame) or Within(f, T.suggestFrame) then return ns:SettingsCategory("home") end
            for key, block in pairs(T.listBlocks) do if type(key) == "string" and Within(f, block) then return ns:SectionOfBlock("list", key) end end
            for key, block in pairs(T.ruleBlocks) do if type(key) == "string" and Within(f, block) then return ns:SectionOfBlock("rule", key) end end
        end
        local B = ns.barsPage
        if B and hit.tab == "bars" then
            if B.box and Within(f, B.box) then return ns:SettingsSection("frames:Action bars") end
            if B.plateBox and Within(f, B.plateBox) then return ns:SettingsSection("frames:Nameplates") end
            if B.raidBox and Within(f, B.raidBox) then return ns:SettingsSection("frames:Raid frames") end
            return ns:SettingsSection("frames:Your frames")
        end
        local host = O.pages[hit.tab]
        if not host then return nil end
        -- where it is on its page: under the heading it was made after, or failing that, how far down it is
        local y
        if hit.head then
            local ht = O.Band(host.sheet, hit.head)
            if ht then y = ht + 4 end
        end
        if not y then
            local top, mine = host.sheet.GetTop and host.sheet:GetTop(), f.GetTop and f:GetTop()
            if type(top) == "number" and type(mine) == "number" then y = top - mine end
        end
        local first
        for _, cat in ipairs(ns.settingsCategories) do
            for _, s in ipairs(cat.sections or {}) do
                for _, block in ipairs(s.blocks or {}) do
                    if block.host == hit.tab then
                        first = first or s
                        local bt, bh = O.Band(host.sheet, block.from, block.to)
                        if bt and y and y >= bt - 2 and y < bt + bh then return s end
                    end
                end
            end
        end
        return first
    end
    function O.Breadcrumb(sec)
        if not sec then return "" end
        if sec.home then return ns:Tr("Home") end
        local text = ns:Tr(sec.category.title) .. " › " .. ns:Tr(sec.title)
        if ns:SettingsSimple() and not SectionShown(sec) then text = text .. " · " .. ns:Tr("in All options") end
        return text
    end
    local function GoTo(hit)
        results:Hide()
        searchBox:ClearFocus()
        local sec = hit.section or O.SectionOfHit(hit)
        if not sec then return false end
        local target = hit.frame
        if type(target) == "table" and rawget(target, "key") and ns:SettingsSimple() and not ns.simpleFeatures[target.key] and not ns.settingRows[target.key] then O.SetSimple(false) end
        O.Open(sec.home and "home" or sec.id)
        local sheet = sec.home and O.home or O.sections
        local area = sec.home and hArea or sArea
        local spot = (type(target) == "table" and rawget(target, "row")) or target
        if type(spot) == "table" and spot.GetTop then
            local top, mine, height = sheet:GetTop(), spot:GetTop(), spot.GetHeight and spot:GetHeight()
            if type(top) == "number" and type(mine) == "number" then
                area:ScrollToShow(top - mine - 24, (type(height) == "number" and height or 24) + 48)
            end
            ring:ClearAllPoints()
            ring:SetPoint("TOPLEFT", spot, "TOPLEFT", -4, 4)
            ring:SetPoint("BOTTOMRIGHT", spot, "BOTTOMRIGHT", 4, -4)
            ring:Show()
            ring.shownAt = GetTime()
            ns:After(2.5, function() if ring.shownAt and GetTime() - ring.shownAt >= 2.4 then ring:Hide() end end)
        end
        ns.lastSearchHit = hit
        return sec
    end
    O.frame.GoToOption = GoTo
    ns.GoToOption = GoTo
    ns.OptionsSheet = function(id) return O.pages[id] and O.pages[id].sheet or (id == "features" and O.sections) or nil end
    ns.HideConfig = function() O.frame:Hide() end
    local function Row(i)
        local row = results.rows[i]
        if row then return row end
        row = ns:CreateButton(results, "", 460, 34, function(self) if self.hit then GoTo(self.hit) end end)
        row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 36)
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", 10, -4)
        row.text:SetPoint("RIGHT", -10, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)
        row.where = row:CreateFontString(nil, "OVERLAY")
        ns:Font(row.where, 10)
        row.where:SetPoint("TOPLEFT", 10, -19)
        row.where:SetPoint("RIGHT", -10, 0)
        row.where:SetJustifyH("LEFT")
        if row.where.SetWordWrap then row.where:SetWordWrap(false) end
        ns:Paint(row.where, "SetTextColor", "faint")
        results.rows[i] = row
        return row
    end
    local function ShowResults(query)
        local q = strtrim(tostring(query or searchBox:GetText() or ""))
        local hits = {}
        for _, hit in ipairs(ns:SearchOptions(q, 40)) do
            if #hits >= 10 then break end
            local sec = O.SectionOfHit(hit)
            if sec then hit.section = sec; hits[#hits + 1] = hit end
        end
        O.frame.searchHits = hits
        if #hits == 0 then
            if q == "" or #q < 2 then results:Hide(); return hits end
            local row = Row(1)
            row.hit = nil
            row.text:SetText("|cff9aa4b4" .. format(ns:Tr("No option matches \"%s\"."), q) .. "|r")
            row.where:SetText("")
            row:Show()
            for i = 2, #results.rows do results.rows[i]:Hide() end
            results:SetHeight(46)
            results:Show()
            return hits
        end
        for i, hit in ipairs(hits) do
            local row = Row(i)
            row.hit = hit
            row.text:SetText(hit.label)
            row.where:SetText(O.Breadcrumb(hit.section))
            row:Show()
        end
        for i = #hits + 1, #results.rows do results.rows[i]:Hide() end
        results:SetHeight(#hits * 36 + 8)
        results:Show()
        return hits
    end
    O.frame.SearchOptions = function(text) searchBox:SetText(text or ""); return ShowResults(text or "") end
    searchBox:HookScript("OnTextChanged", function() ShowResults() end)
    searchBox:HookScript("OnEnterPressed", function() local hits = O.frame.searchHits; if hits and hits[1] then GoTo(hits[1]) end end)
    searchBox:HookScript("OnEscapePressed", function(self) self:SetText(""); results:Hide(); self:ClearFocus() end)
    O.frame:HookScript("OnHide", function() results:Hide(); ring:Hide(); if ns.NoteSettingChanges then pcall(ns.NoteSettingChanges, ns) end end)

    local last = type(ns.root) == "table" and ns.root.optionsSection
    if not (type(last) == "string" and (ns:SettingsSection(last) or last == "home") and O.Open(last)) then O.Open("home") end
end

-- The section a list, a rule or another block is shown in.
function ns:SectionOfBlock(kind, key)
    for _, cat in ipairs(ns.settingsCategories) do
        for _, sec in ipairs(cat.sections or {}) do
            for _, block in ipairs(sec.blocks or {}) do if block[kind] == key then return sec end end
        end
    end
end

-- Home: a card for each category, a few switches most people look for, what changed lately, the
-- guide's question box and what suits your class.
function O.BuildHome(page)
    local title = page:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 18, true)
    title:SetPoint("TOPLEFT", 0, -2)
    ns:Paint(title, "SetTextColor", "@accent")
    title:SetText(ns:Tr("What would you like to change?"))
    local intro = page:CreateFontString(nil, "OVERLAY")
    ns:Font(intro, 11)
    intro:SetPoint("TOPLEFT", 0, -28)
    intro:SetWidth(730)
    intro:SetJustifyH("LEFT")
    ns:Paint(intro, "SetTextColor", "dim")
    page.intro = intro
    -- presets: one click sets every switch (click twice, so a slip of the mouse changes nothing)
    local px = 0
    page.presetButtons = {}
    for _, def in ipairs({ { "EVERYTHING", "Everything" }, { "STANDARD", "Standard" }, { "MINIMAL", "Minimal" } }) do
        local btn = ns:CreateButton(page, def[2], 96, 22, ns:ConfirmClick(function()
            local n = ns:ApplyPreset(def[1])
            if n > 0 then O.NeedReload("preset") end
            O.NoteChange(true)
            O.RefreshAll()
            ns:Print(ns:TrN(n, "%d switch changed", "%d switches changed"), n)
        end))
        btn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12 - px, 0)
        btn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(ns:Tr(def[2]))
            local text = def[1] == "EVERYTHING" and "Every feature on."
                or def[1] == "MINIMAL" and "Only the core: frames, bars, minimap, quests, bags, chat and windows."
                or "How Fantasy Glass UI comes: everything except the four that flash, pop up or act on their own - notifications, the aggro warning, the AFK screen and level-up screenshots."
            GameTooltip:AddLine(ns:Tr(text), 1, 1, 1, true)
            GameTooltip:AddLine(ns:Tr("Click twice. Auto quest and the look options are left as they are."), 0.6, 0.6, 0.6, true)
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        page.presetButtons[def[1]] = btn
        px = px + 102
    end
    local plabel = page:CreateFontString(nil, "OVERLAY")
    ns:Font(plabel, 11)
    plabel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12 - px - 4, -5)
    plabel:SetText(ns:Tr("Presets"))
    ns:Paint(plabel, "SetTextColor", "dim")
    page.cards = {}
    local CW, CH = 240, 72
    for i, id in ipairs(ns.homeCards) do
        local cat = ns:SettingsCategory(id)
        local c = CreateFrame("Button", nil, page, ns.template)
        c:SetSize(CW, CH)
        c:SetPoint("TOPLEFT", ((i - 1) % 3) * (CW + 8), -54 - math.floor((i - 1) / 3) * (CH + 8))
        c:SetBackdrop(ns.BACKDROP)
        ns:Paint(c, "SetBackdropColor", "field", 0.55)
        ns:Paint(c, "SetBackdropBorderColor", "@border", 0.8)
        c.name = c:CreateFontString(nil, "OVERLAY")
        ns:Font(c.name, 13, true)
        c.name:SetPoint("TOPLEFT", 12, -9)
        c.name:SetText(ns:Tr(cat.title))
        ns:Paint(c.name, "SetTextColor", "text")
        c.desc = c:CreateFontString(nil, "OVERLAY")
        ns:Font(c.desc, 10)
        c.desc:SetPoint("TOPLEFT", 12, -27)
        c.desc:SetWidth(CW - 24)
        c.desc:SetJustifyH("LEFT")
        if c.desc.SetWordWrap then c.desc:SetWordWrap(true) end
        c.desc:SetText(ns:Tr(cat.desc or ""))
        ns:Paint(c.desc, "SetTextColor", "dim")
        c.state = c:CreateFontString(nil, "OVERLAY")
        ns:Font(c.state, 10)
        c.state:SetPoint("BOTTOMLEFT", 12, 8)
        ns:Paint(c.state, "SetTextColor", "@accent")
        c:SetScript("OnClick", function() O.Open(cat.id) end)
        c:SetScript("OnEnter", function(self) ns:Paint(self, "SetBackdropBorderColor", "@accent", 1) end)
        c:SetScript("OnLeave", function(self) ns:Paint(self, "SetBackdropBorderColor", "@border", 0.8) end)
        c.cat = cat
        page.cards[i] = c
    end
    local y = -54 - math.ceil(#ns.homeCards / 3) * (CH + 8) - 8
    local function Head(text, x, yy)
        local fs = page:CreateFontString(nil, "OVERLAY")
        ns:Font(fs, 13, true)
        fs:SetPoint("TOPLEFT", x, yy)
        fs:SetText(ns:Tr(text))
        ns:Paint(fs, "SetTextColor", "@accent")
        return fs
    end
    Head("Quick switches", 0, y)
    page.quick = {}
    for i, key in ipairs(ns.homeQuick) do
        local label = O.RowLabel(key)
        if label and not ns:FeatureHidden(key) then
            local cb = ns:CreateCheckbox(page, label, ns.db[key], function(v)
                ns.db[key] = v
                if ns.featureInstant[key] then ns:ApplyInstant() else O.NeedReload(key) end
                O.NoteChange()
                O.DrawSidebar()
            end)
            cb:SetWidth(232)
            cb:SetPoint("TOPLEFT", ((i - 1) % 2) * 240, y - 24 - math.floor((i - 1) / 2) * 26)
            O.Tip(cb, label, (ns.featureDesc[key] or "") .. "\n\n" .. ns:Tr(ns.featureInstant[key] and "Takes effect at once." or "Takes effect after a /reload."))
            cb.key = key
            page.quick[key] = cb
        end
    end
    Head("Changed lately", 496, y)
    local lately = page:CreateFontString(nil, "OVERLAY")
    ns:Font(lately, 11)
    lately:SetPoint("TOPLEFT", 496, y - 24)
    lately:SetWidth(236)
    lately:SetJustifyH("LEFT")
    ns:Paint(lately, "SetTextColor", "dim")
    page.lately = lately
    y = y - 24 - math.ceil(#ns.homeQuick / 2) * 26 - 18
    local T = ns.toolsPage
    Head("Ask the guide", 0, y)
    if T and T.askFrame then
        T.askFrame:SetParent(page); T.askFrame:ClearAllPoints(); T.askFrame:SetPoint("TOPLEFT", 0, y - 24); T.askFrame:Show()
    end
    y = y - 24 - 120 - 8
    Head("Suggested for your class", 0, y)
    if T and T.suggestFrame then
        T.suggestFrame:SetParent(page); T.suggestFrame:ClearAllPoints(); T.suggestFrame:SetPoint("TOPLEFT", 0, y - 24); T.suggestFrame:Show()
    end
    y = y - 24 - 96
    page.contentHeight = -y + 12
    page.area:SetContentHeight(page.contentHeight)

    function page.Refresh()
        local on, total = ns:CountFeatures()
        local r = ns.roles[ns.db.role]
        intro:SetText(format(ns:Tr("Pick a place below or in the list, or search. %s theme · %d of %d features on."), ns:ThemeName(ns.db.theme, "plain"), on, total)
            .. (r and ("  " .. ns:Tr("Role:") .. " " .. ns:Tr(r.label)) or ""))
        for _, c in ipairs(page.cards) do
            local cat = c.cat
            if cat.id == "look" then c.state:SetText(ns:ThemeName(ns.db.theme, "plain"))
            elseif cat.id == "layout" then c.state:SetText(ns:Tr("Profile:") .. " " .. tostring(ns.profile))
            else
                local con, of = O.CategoryCount(cat)
                c.state:SetText(of > 0 and format(ns:Tr("%d of %d on"), con, of) or "")
            end
            c:SetShown(O.CategoryShown(cat))
        end
        for key, cb in pairs(page.quick) do cb:SetChecked(ns.db[key]) end
        local lines = {}
        for i = #O.changes, math.max(1, #O.changes - 4), -1 do
            local ch = O.changes[i]
            lines[#lines + 1] = ns:Tr(O.ChangeLabel(ch.key)) .. ": " .. O.ChangeValue(ch.key, ch.new)
        end
        lately:SetText(#lines > 0 and table.concat(lines, "\n") or ns:Tr("Nothing changed yet. Changes you make show here, and Undo takes them back."))
        if T and T.DrawSuggest then pcall(T.DrawSuggest) end
    end
    page.Refresh()
end

function ns:NoteNothing() end        -- settings that are simply read the next time they are needed


-- Open the window, or close it. `page`: a section ("items:Vendors"), a category ("combat"), Home, or one
-- of the old page names ("look", "clickcast": see O.Open).
function ns:ToggleConfig(page)
    ns:InitDB()
    if not O.frame then Build() end
    if page and O.Open(page, page) then
        O.frame:Show()
    elseif O.frame:IsShown() then
        O.frame:Hide()
    else
        O.frame:Show()
    end
end

-- (Config.lua is the last of this folder's files to load: reaching here means all of it is in.)
ns.optionsLoaded = true
