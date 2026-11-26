-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local O = ns.optUI

-- The settings window (12.0): the categories down the left, with the sections of the one that is open
-- under it, and the section on the right. Home, the first entry, greets the player and holds the quick switches. The
-- pages built in LookPage, LayoutPage, CombatPage, Bars and Tools.lua are not shown as they are: each
-- section shows the slices of them it needs (see Categories.lua and FeaturesPage.lua).
local VIEW_H = 542
O.VIEW_H = VIEW_H
local HEAD_H, FOOT_H = 60, 52                       -- (12.3) the header and footer, a rule under / over each
local BODY_Y = HEAD_H + 12
local SIDE_X, SIDE_W = 14, 216
local CONTENT_X = SIDE_X + SIDE_W + 14
local CONTENT_R, AREA_R = 16, 10                    -- the content's gap to the window's right, and its scroll area's to the content's
-- (12.3) The window starts, and goes no narrower than, the width at which the widest block lent from
-- the older pages (laid out for 736) fits inside its card: the block, its card's padding at either
-- side, the card's gap to the page's right, then the sidebar and the margins (1054). Wider, the pages
-- follow the window up to 1600 and the theme grid takes more columns.
local MIN_W = (O.LEGACY_W or 736) + 2 * (O.BLOCK_PAD or 18) + (O.CARD_GAP or 12) + CONTENT_X + CONTENT_R + AREA_R
local W, H = MIN_W, 680
O.W, O.MIN_W = W, MIN_W
-- The width of the pages (Home's and a section's sheet) in a window `w` wide.
function O.PageWidth(w)
    w = tonumber(w)
    if not w or w <= 0 then w = W end
    return math.max(MIN_W, w) - CONTENT_X - CONTENT_R - AREA_R
end

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
-- The last five changes, the most recent first, each as "name: new value" (what Home's "Changed lately" listed).
function O.LatelyLines()
    local lines = {}
    for i = #O.changes, math.max(1, #O.changes - 4), -1 do
        local ch = O.changes[i]
        lines[#lines + 1] = ns:Tr(O.ChangeLabel(ch.key)) .. ": " .. O.ChangeValue(ch.key, ch.new)
    end
    return lines
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
        if O.LayoutFooter then O.LayoutFooter() end         -- (the note takes room in the footer)
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
    -- (12.3) The window wears a calm look of its own whatever the theme (ns.LOOKS.settings: dark
    -- grounds, Barlow lettering); only the accent comes from the theme. No sky, grain or glass.
    ns:SetLook(O.frame, "settings")                                   -- (O.frame.suiLook = "settings")
    ns.configFrame = O.frame
    local size = type(ns.root) == "table" and type(ns.root.optionsSize) == "table" and ns.root.optionsSize or nil
    O.frame:SetSize(math.max(MIN_W, size and tonumber(size[1]) or W), size and tonumber(size[2]) or H)
    O.frame:SetPoint("CENTER")
    O.frame:SetFrameStrata("DIALOG")
    O.frame:SetBackdrop(ns.BACKDROP)
    ns:Paint(O.frame, "SetBackdropColor", "window", 1)
    ns:Paint(O.frame, "SetBackdropBorderColor", "@rim", 1)            -- (a 1 px rim)
    if ns.After then ns:After(0, function() if ns.StarcutWindow then pcall(ns.StarcutWindow, O.frame) end end) end   -- (the Starcut corner cut stays)
    O.frame:EnableMouse(true)
    O.frame:SetMovable(true)
    O.frame:SetClampedToScreen(true)
    O.frame:RegisterForDrag("LeftButton")
    O.frame:SetScript("OnDragStart", O.frame.StartMoving)
    O.frame:SetScript("OnDragStop", O.frame.StopMovingOrSizing)
    ns:KeepPlace(O.frame, "Options")
    tinsert(UISpecialFrames, "FantasyGlassUIConfig")

    -- the header (60 px): the logo and name, the search filling the middle, language, the profile
    -- being edited, close
    local logo = O.frame:CreateTexture(nil, "OVERLAY")
    logo:SetSize(26, 26)
    logo:SetPoint("TOPLEFT", 18, -17)
    logo:SetTexture(ns.MEDIA .. "icon.tga")
    local title = O.frame:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 16, true)
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetJustifyH("LEFT")
    ns:Paint(title, "SetTextColor", "text")
    if title.SetWordWrap then title:SetWordWrap(false) end
    O.frame.title = title
    local chip = ns:CreateButton(O.frame, "", 150, 28, function() O.Open("layout:Profiles") end)
    ns:Font(chip.text, 12)
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
        title:SetText(ns:AccentHex() .. "Fantasy Glass|r UI")
        if O.frame.version then O.frame.version:SetText("v" .. tostring(ns.version)) end
        chip.text:SetText(ns:Tr("Profile:") .. " " .. ns:AccentHex() .. tostring(ns.profile) .. "|r")
        local w = chip.text.GetStringWidth and chip.text:GetStringWidth()
        if type(w) == "number" and w > 0 then chip:SetWidth(math.min(240, math.floor(w + 22))) end
    end
    Heading()
    O.frame:HookScript("OnShow", Heading)
    ns:OnTheme(function() if O.frame:IsShown() then Heading() end end)

    local close = ns:CreateButton(O.frame, "X", 28, 28, function() O.frame:Hide() end)
    close:SetPoint("TOPRIGHT", -16, -16)
    chip:SetPoint("RIGHT", close, "LEFT", -10, 0)

    -- Language: the word on the button is never translated, so the way back can be found by someone
    -- who picked a language they cannot read.
    local langList
    local langBtn = ns:CreateButton(O.frame, "Language", 100, 28, function(self)
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
    langBtn:SetPoint("RIGHT", chip, "LEFT", -10, 0)
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
    -- (12.3: at the top of the list down the left, where the search was; placed with it below)
    local modeAll = ns:CreateButton(O.frame, "All options", SIDE_W / 2 - 1, 24, function() O.SetSimple(false) end)
    local modeSimple = ns:CreateButton(O.frame, "Simple", SIDE_W / 2 - 1, 24, function() O.SetSimple(true) end)
    O.Tip(modeSimple, "Simple", "The options most players look for. The search still finds every one.")
    O.Tip(modeAll, "All options", "Every option there is.")
    O.frame.modeButtons = { simple = modeSimple, all = modeAll }
    local function DrawMode()
        local simple = ns:SettingsSimple()
        for which, b in pairs(O.frame.modeButtons) do
            local on = (which == "simple") == simple
            b.picked = on
            ns:Paint(b, "SetBackdropBorderColor", on and "@accent" or "@border", 1)
            ns:Paint(b.text, "SetTextColor", on and "text" or "dim")
        end
    end
    for _, b in pairs(O.frame.modeButtons) do b:HookScript("OnLeave", function() DrawMode() end) end

    -- plain rules under the header and over the footer
    local function Rule(y, fromBottom)
        local t = O.frame:CreateTexture(nil, "ARTWORK")
        t:SetTexture(ns.FLAT)
        t:SetHeight(1)
        local edge = fromBottom and "BOTTOM" or "TOP"
        t:SetPoint(edge .. "LEFT", 1, y)
        t:SetPoint(edge .. "RIGHT", -1, y)
        ns:Paint(t, "SetVertexColor", "@border", 1)
        return t
    end
    O.frame.headRule, O.frame.footRule = Rule(-HEAD_H), Rule(FOOT_H, true)

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
        page:SetPoint("TOPLEFT", CONTENT_X, -BODY_Y)
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
    content:SetPoint("TOPLEFT", CONTENT_X, -BODY_Y)
    content:SetPoint("BOTTOMRIGHT", -CONTENT_R, FOOT_H + 6)
    O.content = content
    local startW = O.PageWidth(size and tonumber(size[1]) or W)
    local sArea, sSheet = ns:ScrollArea(content, startW, VIEW_H)
    sArea:SetPoint("TOPLEFT", 0, 0)
    sArea:SetPoint("BOTTOMRIGHT", -AREA_R, 0)
    O.BuildSections(sSheet)
    O.sections = sSheet
    local hArea, hSheet = ns:ScrollArea(content, startW, VIEW_H)
    hArea:SetPoint("TOPLEFT", 0, 0)
    hArea:SetPoint("BOTTOMRIGHT", -AREA_R, 0)
    O.BuildHome(hSheet)
    O.home = hSheet
    O.sectionArea, O.homeArea = sArea, hArea

    -- The left side: the search, then the categories, with the sections of the open one under it.
    local side = CreateFrame("Frame", nil, O.frame)
    side:SetPoint("TOPLEFT", SIDE_X, -BODY_Y)
    side:SetPoint("BOTTOMLEFT", SIDE_X, FOOT_H + 6)
    side:SetWidth(SIDE_W)
    O.side = side
    local sideRule = O.frame:CreateTexture(nil, "ARTWORK")
    sideRule:SetTexture(ns.FLAT)
    sideRule:SetWidth(1)
    sideRule:SetPoint("TOPLEFT", side, "TOPRIGHT", 6, 0)
    sideRule:SetPoint("BOTTOMLEFT", side, "BOTTOMRIGHT", 6, 0)
    ns:Paint(sideRule, "SetVertexColor", "@border", 1)
    modeSimple:SetParent(side); modeAll:SetParent(side)
    modeSimple:SetPoint("TOPLEFT", side, "TOPLEFT", 0, 0)
    modeAll:SetPoint("TOPRIGHT", side, "TOPRIGHT", 0, 0)
    -- the search, filling the middle of the header
    local searchBox = ns:CreateEditBox(O.frame, 300, 28, "Search every option")
    searchBox:SetPoint("LEFT", title, "RIGHT", 28, 0)
    searchBox:SetPoint("RIGHT", langBtn, "LEFT", -24, 0)
    O.frame.searchBox = searchBox
    local catButtons, secButtons = {}, {}
    -- The list is its own scrolling area under the two mode buttons: with a long category open (Bags
    -- and items has nine sections) it is taller than the window.
    local ROW_W = SIDE_W - 8
    local sideArea, sideSheet = ns:ScrollArea(side, ROW_W, 400)
    sideArea:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -32)
    sideArea:SetPoint("BOTTOMRIGHT", side, "BOTTOMRIGHT", -8, 0)
    O.sideArea, O.sideSheet = sideArea, sideSheet
    -- A row: Home or a category (36 px, 14 px lettering) or a section of the open category (32 px, 13 px,
    -- indented 26). The selected row is filled (rounded where the window can round); the others are
    -- secondary text. No counts, no bar.
    local function NavButton(list, i, indent, size)
        local b = list[i]
        if b then return b end
        b = CreateFrame("Button", nil, sideSheet, ns.template)
        b:SetSize(ROW_W, size)
        b:SetBackdrop(ns.BACKDROP)
        ns:Paint(b, "SetBackdropColor", "select", 0)
        ns:Paint(b, "SetBackdropBorderColor", "select", 0)
        if ns:CanRound() then ns:Round(b) end
        local x = 12
        if indent > 12 then x = indent end
        if size >= 36 then
            b.icon = b:CreateTexture(nil, "ARTWORK")                -- (a category's `icon`, a texture of the add-on's own, drawn in the text color)
            b.icon:SetSize(16, 16)
            b.icon:SetPoint("LEFT", 12, 0)
            b.icon:Hide()
        end
        b.text = b:CreateFontString(nil, "OVERLAY")
        ns:Font(b.text, size >= 36 and 14 or 13)
        b.text:SetPoint("LEFT", x, 0)
        b.text:SetWidth(ROW_W - x - 40)
        b.text:SetJustifyH("LEFT")
        if b.text.SetWordWrap then b.text:SetWordWrap(false) end
        b.new = ns.NewTag(b)
        b.new:SetPoint("RIGHT", b, "RIGHT", -10, 0)
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
            b.picked = on and true or false
            ns:Paint(b, "SetBackdropColor", "select", on and 1 or 0)
            ns:Paint(b, "SetBackdropBorderColor", "select", on and 1 or 0)
            ns:Paint(b.text, "SetTextColor", on and "text" or "dim")
            if b.icon then ns:Paint(b.icon, "SetVertexColor", on and "text" or "dim") end
        end
        list[i] = b
        return b
    end
    O.catButtons, O.secButtons = catButtons, secButtons
    function O.DrawSidebar()
        local y, nc, ns2 = 0, 0, 0
        local pickedTop
        local openCat = O.current and (O.current.home and O.current or O.current.category)
        for _, cat in ipairs(ns.settingsCategories) do
            if CategoryShown(cat) then
                nc = nc + 1
                local b = NavButton(catButtons, nc, 12, 36)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 0, y)
                b.cat = cat
                b.text:SetText(ns:Tr(cat.title))
                local iconed = type(cat.icon) == "string" and cat.icon ~= ""
                if b.icon then
                    if iconed then b.icon:SetTexture(ns.MEDIA .. cat.icon); b.icon:Show() else b.icon:Hide() end
                    b.text:ClearAllPoints()
                    b.text:SetPoint("LEFT", iconed and 36 or 12, 0)
                end
                local new = false
                for _, sec in ipairs(cat.sections or {}) do if ns:SectionIsNew(sec) then new = true end end
                b.new:SetShown(new)
                b.open = function() O.Open(cat.id) end
                local on = cat.home and O.current and O.current.home == true or false
                b.Mark(on)
                if on then pickedTop = y end
                b:Show()
                y = y - 38
                if openCat == cat and not cat.home then
                    for _, sec in ipairs(cat.sections or {}) do
                        if SectionShown(sec) then
                            ns2 = ns2 + 1
                            local s = NavButton(secButtons, ns2, 26, 32)
                            s:ClearAllPoints()
                            s:SetPoint("TOPLEFT", 0, y)
                            s.text:SetText(ns:Tr(sec.title))
                            s.sec = sec
                            s.new:SetShown(ns:SectionIsNew(sec))
                            s.open = function() O.Open(sec.id) end
                            s.Mark(O.current == sec)
                            if O.current == sec then pickedTop = y end
                            s:Show()
                            y = y - 34
                        end
                    end
                end
            end
        end
        for i = nc + 1, #catButtons do catButtons[i]:Hide() end
        for i = ns2 + 1, #secButtons do secButtons[i]:Hide() end
        sideArea:SetContentHeight(-y + 4)
        if pickedTop then sideArea:ScrollToShow(-pickedTop, 36) end
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
            if O.resetButton then O.resetButton:Hide() end
            if O.LayoutFooter then O.LayoutFooter() end
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
    setup:SetPoint("BOTTOMLEFT", 18, 14)                          -- (the footer: 52 px, buttons centred in it)
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
    -- (12.3) "Reset <category> to how it came": it was at the top of a section page, it is here now
    local resetBtn = ns:CreateButton(O.frame, "", 220, 24, ns:ConfirmClick(function()
        local page = O.sections
        if page and page.category then O.ResetCategory(page.category) end
    end))
    resetBtn:SetPoint("LEFT", discord, "RIGHT", 8, 0)
    resetBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.suiFull or self.text:GetText())
        GameTooltip:AddLine(ns:Tr("Every switch and slider of this category goes back to how Fantasy Glass UI comes. Your lists, rules, designs and positions are kept."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    resetBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    resetBtn:Hide()
    O.resetButton = resetBtn
    -- its label changes when a click arms it ("Click to confirm") and when that runs out: the footer is
    -- laid out again for it, so in a narrow window the new label is not cut short
    local footerBusy = false                                     -- (while the footer is laid out, its own label changes are not news)
    hooksecurefunc(resetBtn.text, "SetText", function()
        if footerBusy or not O.LayoutFooter then return end
        pcall(O.LayoutFooter)
    end)
    local reload = ns:CreateButton(O.frame, "Reload UI", 110, 26, ReloadUI)
    ns:ReloadButton(reload)                                       -- (OnClick stays the game's own ReloadUI)
    reload:SetPoint("BOTTOMRIGHT", -24, 13)
    note:SetPoint("RIGHT", reload, "LEFT", -12, 0)
    local undo = ns:CreateButton(O.frame, "Undo last change", 140, 24, function() O.Undo() end)
    undo:SetPoint("RIGHT", note, "LEFT", -12, 0)
    local version = O.frame:CreateFontString(nil, "OVERLAY")
    ns:Font(version, 12)
    version:SetPoint("RIGHT", undo, "LEFT", -14, 0)
    version:SetJustifyH("RIGHT")
    ns:Paint(version, "SetTextColor", "faint")
    version:SetText("v" .. tostring(ns.version))
    O.frame.version = version
    undo:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local last = watch.stack[#watch.stack]
        if last then
            GameTooltip:AddLine(format(ns:Tr("Undo: %s"), ns:Tr(O.ChangeLabel(last.key))))
            GameTooltip:AddLine(format(ns:Tr("Back to %s."), O.ChangeValue(last.key, last.old)), 1, 1, 1, true)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns:Tr("Changed lately"), 1, 0.82, 0)
            for _, line in ipairs(O.LatelyLines()) do GameTooltip:AddLine(line, 1, 1, 1, true) end
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
    O.frame:SetResizeBounds(MIN_W, 600, 1600, 1200)
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

    -- (12.3) The pages follow the window's width: Home's cards, a section's card and rows, the blocks
    -- lent to it (the theme grid among them) are laid out again for the new width, and the footer
    -- makes room. While the corner is dragged this runs once a frame at most.
    local function Fit(b, least, most)                       -- (a button as wide as its label, between `least` and `most`)
        local w = b.text and b.text.GetStringWidth and b.text:GetStringWidth()
        if type(w) == "number" and w > 0 then b:SetWidth(math.min(most or 400, math.max(least, math.floor(w + 24)))) end
        local got = b:GetWidth()
        return type(got) == "number" and got or least
    end
    local function FrameWidth()
        local got = O.frame:GetWidth()
        return (type(got) == "number" and got > 0) and got or W
    end
    -- The footer in a window `w` wide. Its two ends must not meet: in a narrow window the version
    -- goes first, then the buttons are only as wide as their labels, then "Reset <category> to how
    -- it came" is cut to "Reset" and "Undo last change" to "Undo" (their tooltips still say all).
    local function LayoutFooter(w)
        w = tonumber(w) or FrameWidth()
        local full = resetBtn.suiFull
        local armed = resetBtn.suiArmed
        local nw = note.GetStringWidth and note:GetStringWidth()
        nw = (type(nw) == "number" and nw > 0) and (nw + 12) or 0
        local vw = version.GetStringWidth and version:GetStringWidth()
        vw = (type(vw) == "number" and vw > 0) and (vw + 14) or 50
        local function Try(stage)
            local snug = stage >= 2
            if full and not armed then resetBtn.text:SetText(stage >= 3 and ns:Tr("Reset") or full) end
            undo.text:SetText(ns:Tr(stage >= 4 and "Undo" or "Undo last change"))
            local left = 18 + Fit(setup, snug and 60 or 132) + 8 + Fit(report, snug and 60 or 132) + 8 + Fit(discord, snug and 60 or 96)
            if resetBtn:IsShown() then left = left + 8 + Fit(resetBtn, 60, 260) end
            local right = 24 + 110 + 12 + nw + Fit(undo, snug and 60 or 140) + ((stage == 0) and vw or 0)
            return left, right
        end
        local left, right, stage
        for s = 0, 4 do
            stage = s
            left, right = Try(s)
            if left + right + 24 <= w then break end
        end
        version:SetShown(stage == 0)
        O.footer = { left = left, right = right, width = w, stage = stage }
        return O.footer
    end
    function O.LayoutFooter(w)
        footerBusy = true
        local ok, got = pcall(LayoutFooter, w)
        footerBusy = false
        if not ok then error(got, 0) end
        return got
    end
    function O.Relayout(w)
        w = tonumber(w) or FrameWidth()
        local pw = O.PageWidth(w)
        O.pageWidth = pw
        O.sections:SetWidth(pw)
        O.home:SetWidth(pw)
        O.LayoutFooter(w)
        if O.current and O.current.home then
            if O.home.Layout then O.home.Layout() end
        elseif O.current and O.sections.section then
            O.sections.Show(O.sections.section, true)
        end
        return pw
    end
    local pending = false
    O.frame:HookScript("OnSizeChanged", function()
        if pending then return end
        pending = true
        ns:After(0, function() pending = false; O.Relayout() end)
    end)

    -- Search: one box that finds any setting. Each result says where it lives; Enter goes to the first.
    local results = CreateFrame("Frame", nil, O.frame, ns.template)
    results:SetFrameStrata("FULLSCREEN_DIALOG")
    results:SetBackdrop(ns.BACKDROP)
    ns:Paint(results, "SetBackdropColor", "@bg", 1)
    ns:Paint(results, "SetBackdropBorderColor", "@accent", 1)
    results:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
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

-- Home (12.3): a greeting with the theme and the counts, the quick switches as cards, what is new,
-- and the guide's question box with what suits your class.
local function Upper(text) return O.LabelCase(tostring(text or "")) end     -- (section labels in capitals: in English only, as O.Header)
function O.Greeting()
    local hour
    local ok, h = pcall(GetGameTime)
    if ok and type(h) == "number" and not ns:IsSecret(h) then hour = h end
    if not hour then hour = tonumber(date("%H")) or 20 end
    local phrase = hour < 12 and "Good morning, %s" or hour < 18 and "Good afternoon, %s" or "Good evening, %s"
    local class = UnitClass and UnitClass("player")
    if type(class) ~= "string" or class == "" or ns:IsSecret(class) then class = ns:Tr("adventurer") end
    return format(ns:Tr(phrase), class)
end
function O.HomeLine()
    local on, total = ns:CountFeatures()
    return format(ns:Tr("%s · %s frames · %d settings, %d switched off"), ns:ThemeName(ns.db.theme, "plain"),
        ns:Tr(ns.StarcutOn() and "Starcut" or "Classic"), total, total - on)
end
-- The entry of "what is new" for this version (the newest one when this version has none yet), and its
-- lines cut to their first sentence.
function O.NewIn()
    local mine = tostring(ns.version or ""):match("^(%d+%.%d+)")
    local entry = ns.whatsNew[1]
    for _, e in ipairs(ns.whatsNew) do
        if mine and tostring(e[1]):match("^(%d+%.%d+)") == mine then entry = e; break end
    end
    local lines = {}
    for _, line in ipairs(entry and entry[2] or {}) do
        line = ns:Tr(line)
        local first = line:match("^(.-[%.!?])%s") or line
        lines[#lines + 1] = first
    end
    return tostring(entry and entry[1] or ""):match("^(%d+%.%d+)") or tostring(entry and entry[1] or ""), lines
end
function O.BuildHome(page)
    local GAP = 12
    -- (12.3) Home follows the window's width: the page's own width, read at every layout
    local function Width()
        local w = page.GetWidth and page:GetWidth()
        return (type(w) == "number" and w > 300) and w or O.PageWidth()
    end
    local WIDTH = Width()
    local function Cols(w) return (w >= 640) and 3 or 2 end    -- (three quick cards to a row; two in a narrow window)
    local function CardW(w) local n = Cols(w); return math.floor((w - (n - 1) * GAP) / n) end
    local CW = CardW(WIDTH)
    local title = page:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 24, true)
    title:SetPoint("TOPLEFT", 0, -2)
    ns:Paint(title, "SetTextColor", "text")
    page.title = title
    local intro = page:CreateFontString(nil, "OVERLAY")
    ns:Font(intro, 13)
    intro:SetPoint("TOPLEFT", 0, -38)
    intro:SetWidth(WIDTH)
    intro:SetJustifyH("LEFT")
    ns:Paint(intro, "SetTextColor", "dim")
    page.intro = intro
    local function Label(text, x, y)
        local fs = page:CreateFontString(nil, "OVERLAY")
        ns:Font(fs, 13, true)
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetText(Upper(ns:Tr(text)))
        ns:Paint(fs, "SetTextColor", "faint")
        return fs
    end
    local function Card(parent, w, h)
        local c = CreateFrame("Frame", nil, parent, ns.template)
        c:SetSize(w, h)
        c:SetBackdrop(ns.BACKDROP)
        ns:Paint(c, "SetBackdropColor", "card", 1)
        ns:Paint(c, "SetBackdropBorderColor", "@border", 1)
        if ns:CanRound() then ns:Round(c) end
        return c
    end
    local y = -78
    Label("Quick switches", 0, y)
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
        btn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12 - px, y + 5)
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
    ns:Font(plabel, 12)
    plabel:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12 - px - 4, y - 1)
    plabel:SetText(ns:Tr("Presets"))
    ns:Paint(plabel, "SetTextColor", "dim")
    -- the quick switches: a card each (title, one line on what it does, the switch)
    y = y - 28
    page.quick, page.quickCards = {}, {}
    local n = 0
    for _, key in ipairs(ns.homeQuick) do
        local label = O.RowLabel(key)
        if label and not ns:FeatureHidden(key) then
            local c = Card(page, CW, 76)
            n = n + 1
            local name = c:CreateFontString(nil, "OVERLAY")
            ns:Font(name, 14, true)
            name:SetPoint("TOPLEFT", 14, -13)
            name:SetWidth(CW - 28 - 44)
            name:SetJustifyH("LEFT")
            if name.SetWordWrap then name:SetWordWrap(true) end      -- (a long name wraps to two lines and the card grows, it is not cut off)
            if name.SetMaxLines then name:SetMaxLines(2) end
            name:SetText(ns:Tr(label))
            ns:Paint(name, "SetTextColor", "text")
            local hint = c:CreateFontString(nil, "OVERLAY")
            ns:Font(hint, 12)
            hint:SetPoint("TOPLEFT", 14, -40)                        -- (moved under the title by Layout)
            hint:SetWidth(CW - 28)
            hint:SetJustifyH("LEFT")
            if hint.SetWordWrap then hint:SetWordWrap(false) end
            local desc = ns:Tr(ns.featureDesc[key] or "")
            hint:SetText(desc:match("^(.-[%.!?])%s") or desc)
            ns:Paint(hint, "SetTextColor", "dim")
            local cb = ns:CreateCheckbox(c, "", ns.db[key], function(v)
                ns.db[key] = v
                if ns.featureInstant[key] then ns:ApplyInstant() else O.NeedReload(key) end
                O.NoteChange()
                O.DrawSidebar()
            end)
            cb:SetSize(40, 22)
            cb:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -12)
            if cb.label then cb.label:Hide() end
            c:EnableMouse(true)                                      -- (the card takes the mouse, so pointing anywhere on it shows what the switch does)
            O.Tip(c, label, (ns.featureDesc[key] or "") .. "\n\n" .. ns:Tr(ns.featureInstant[key] and "Takes effect at once." or "Takes effect after a /reload."))
            O.Tip(cb, label, (ns.featureDesc[key] or "") .. "\n\n" .. ns:Tr(ns.featureInstant[key] and "Takes effect at once." or "Takes effect after a /reload."))
            cb.key = key
            c.key, c.switch, c.name, c.hint, c.label = key, cb, name, hint, label
            page.quick[key] = cb
            page.quickCards[#page.quickCards + 1] = c
        end
    end
    local quickTop = y
    -- "New in 12.3": what changed lately, each a diamond in the accent and one sentence
    local newCard = Card(page, WIDTH, 60)
    local newTitle = newCard:CreateFontString(nil, "OVERLAY")
    ns:Font(newTitle, 14, true)
    newTitle:SetPoint("TOPLEFT", 16, -14)
    ns:Paint(newTitle, "SetTextColor", "text")
    page.newTitle, page.newCard, page.newLines, page.newDots = newTitle, newCard, {}, {}
    local ver, lines = O.NewIn()
    newTitle:SetText(format(ns:Tr("New in %s"), ver))
    local last
    for i, text in ipairs(lines) do
        if i > 5 then break end
        local dot = newCard:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(ns.MEDIA .. "starcut\\diamond.tga")
        dot:SetSize(7, 7)
        ns:Paint(dot, "SetVertexColor", "@accent", 1)
        local fs = newCard:CreateFontString(nil, "OVERLAY")
        ns:Font(fs, 13)
        fs:SetWidth(WIDTH - 32 - 20)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        ns:Paint(fs, "SetTextColor", "dim")
        if last then fs:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -8) else fs:SetPoint("TOPLEFT", newCard, "TOPLEFT", 36, -44) end
        dot:SetPoint("TOPLEFT", fs, "TOPLEFT", -20, -5)
        last = fs
        page.newLines[#page.newLines + 1] = fs
        page.newDots[#page.newDots + 1] = dot
    end
    -- "Ask the guide": the question box, then what suits your class
    local askCard = Card(page, WIDTH, 200)                     -- (as tall as what is in it: see Layout)
    page.askCard = askCard
    local askTitle = askCard:CreateFontString(nil, "OVERLAY")
    ns:Font(askTitle, 14, true)
    askTitle:SetPoint("TOPLEFT", 16, -14)
    askTitle:SetText(ns:Tr("Ask the guide"))
    ns:Paint(askTitle, "SetTextColor", "text")
    local T = ns.toolsPage
    if T and T.askFrame then
        T.askFrame:SetParent(askCard); T.askFrame:ClearAllPoints(); T.askFrame:SetPoint("TOPLEFT", 16, -44)
        T.askFrame:Show()
    end
    local classTitle = askCard:CreateFontString(nil, "OVERLAY")
    ns:Font(classTitle, 13, true)
    classTitle:SetText(Upper(ns:Tr("Suggested for your class")))
    ns:Paint(classTitle, "SetTextColor", "faint")
    page.classTitle = classTitle
    if T and T.suggestFrame then
        T.suggestFrame:SetParent(askCard)
        T.suggestFrame:Show()
    end

    -- Placing the cards: a title of one or two lines, the hint under it, a row as tall as its tallest
    -- card; then the New card, the Ask card and the page's height under them.
    local function Lines(fs)
        local h = fs.GetStringHeight and fs:GetStringHeight()
        return (type(h) == "number" and h > 0) and h or 16
    end
    function page.Layout()
        local w = Width()
        local cols = Cols(w)
        CW = CardW(w)
        page.width, page.cols, page.cardWidth = w, cols, CW
        intro:SetWidth(w)
        local top, rows = quickTop, {}
        for i, c in ipairs(page.quickCards) do
            local row = math.floor((i - 1) / cols) + 1
            c:SetWidth(CW)
            c.name:SetWidth(CW - 28 - 44)
            c.hint:SetWidth(CW - 28)
            c.name:SetText(ns:Tr(c.label))
            local nameH = Lines(c.name)
            c.hint:ClearAllPoints()
            c.hint:SetPoint("TOPLEFT", c, "TOPLEFT", 14, -(13 + nameH + 4))
            c:SetHeight(math.max(76, 13 + nameH + 4 + Lines(c.hint) + 14))
            rows[row] = math.max(rows[row] or 0, c:GetHeight())
        end
        page.quickRows = {}
        local at = top
        for r = 1, #rows do
            page.quickRows[r] = { top = at, height = rows[r] }
            at = at - rows[r] - 12
        end
        for i, c in ipairs(page.quickCards) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", page, "TOPLEFT", ((i - 1) % cols) * (CW + GAP), page.quickRows[math.floor((i - 1) / cols) + 1].top)
        end
        -- "New in" lines: the card is as tall as its lines turn out to be
        newCard:SetWidth(w)
        local h = 44
        for _, fs in ipairs(page.newLines) do fs:SetWidth(w - 32 - 20); h = h + Lines(fs) + 8 end
        h = math.max(60, h + 8)
        newCard:SetHeight(h)
        newCard:ClearAllPoints()
        newCard:SetPoint("TOPLEFT", page, "TOPLEFT", 0, at + 4)
        -- "Ask the guide": as tall as the box with its answer, the heading and the suggestions
        askCard:SetWidth(w)
        local inner = w - 32
        local askH = (T and T.LayoutAsk) and T.LayoutAsk(inner) or 120
        local cy = -44 - askH - 18
        classTitle:ClearAllPoints()
        classTitle:SetPoint("TOPLEFT", askCard, "TOPLEFT", 16, cy)
        local sugH = 0
        if T and T.suggestFrame then
            T.suggestFrame:ClearAllPoints()
            T.suggestFrame:SetPoint("TOPLEFT", askCard, "TOPLEFT", 16, cy - 22)
            sugH = T.LayoutSuggest and T.LayoutSuggest(inner) or 96
        end
        local askCardH = -(cy - 22) + sugH + 16
        askCard:SetHeight(askCardH)
        page.askCardHeight = askCardH
        askCard:ClearAllPoints()
        askCard:SetPoint("TOPLEFT", newCard, "BOTTOMLEFT", 0, -12)
        page.contentHeight = -(at + 4) + h + 12 + askCardH + 16
        page.area:SetContentHeight(page.contentHeight)
    end
    if T then T.OnAnswer = function() if page.Layout then page.Layout() end end end
    function page.Refresh()
        title:SetText(O.Greeting())
        intro:SetText(O.HomeLine())
        for _, cb in pairs(page.quick) do cb:SetChecked(ns.db[cb.key]) end
        local ver2 = O.NewIn()
        newTitle:SetText(format(ns:Tr("New in %s"), ver2))
        page.Layout()
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
