-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- The options window: tabs down the top, a list of each tab's sections down the left, and the
-- page. The pages themselves are built in FeaturesPage, LookPage, LayoutPage and CombatPage.lua
-- (with the switch list in FeatureList.lua and the shared pieces in Shared.lua).
local O = ns.optUI
local Header = function(...) return O.Header(...) end   -- luacheck: ignore
-- The list of a tab's sections, down the left of the window. A tab either says what its sections
-- are itself (sheet.navItems and sheet.NavSelect: the Features switches, the action bars), or they
-- are found from its headings: each heading starts a slice of the sheet, and choosing it shows that
-- slice and nothing else.
local NAV_W, VIEW_H = 178, 542
local WHOLE_X = 100                                          -- (a 736 page in the middle of a 936 window)
local function BuildNav(page, sheet, area, tabTitle)
    local items = rawget(sheet, "navItems")
    if type(items) ~= "table" then
        local heads = {}
        for _, h in ipairs(rawget(sheet, "suiHeads") or {}) do if h.x == 0 then heads[#heads + 1] = h end end
        table.sort(heads, function(a, b) return a.y > b.y end)
        items = {}
        local total = tonumber(rawget(sheet, "contentHeight")) or VIEW_H
        if #heads == 0 or heads[1].y < -24 then items[1] = { title = tabTitle, top = 0 } end      -- what stands above the first heading
        for _, h in ipairs(heads) do items[#items + 1] = { title = h.text, top = math.max(0, -h.y - 4), fs = h.fs } end
        for i, item in ipairs(items) do item.height = math.max(1, ((items[i + 1] and items[i + 1].top) or total) - item.top) end
        sheet.NavSelect = function(i)
            local item = items[i]
            if not item then return end
            area:SetHeight(math.max(40, math.min(VIEW_H, item.height)))
            area:SetBand(item.top, item.height)
        end
        sheet.banded = true
    end
    sheet.navList = items
    local buttons = {}
    local function Mark(which)
        for i, b in ipairs(buttons) do
            b.picked = (i == which)
            if b.picked then b.bar:Show(); b.bg:Show(); ns:Paint(b.text, "SetTextColor", "@accent")
            else b.bar:Hide(); b.bg:Hide(); ns:Paint(b.text, "SetTextColor", "dim") end
        end
        sheet.navCurrent = which
    end
    sheet.NavMark = Mark
    for i, item in ipairs(items) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(NAV_W, 24)
        b:SetPoint("TOPLEFT", 0, -(i - 1) * 25)
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
        ns:Font(b.text, 12)
        b.text:SetPoint("LEFT", 12, 0)
        b.text:SetWidth(NAV_W - 12 - (item.count and 38 or 8))
        b.text:SetJustifyH("LEFT")
        if b.text.SetWordWrap then b.text:SetWordWrap(false) end
        b.text:SetText(ns:Tr(item.title))
        b:SetScript("OnClick", function() Mark(i); sheet.NavSelect(i) end)
        b:SetScript("OnEnter", function(self) if not self.picked then ns:Paint(self.text, "SetTextColor", "text") end end)
        b:SetScript("OnLeave", function(self) if not self.picked then ns:Paint(self.text, "SetTextColor", "dim") end end)
        buttons[i] = b
    end
    sheet.nav = buttons
    local rule = page:CreateTexture(nil, "ARTWORK")            -- a hairline between the list and the page
    rule:SetTexture(ns.FLAT)
    rule:SetWidth(1)
    rule:SetPoint("TOPLEFT", NAV_W + 8, 0)
    rule:SetPoint("BOTTOMLEFT", NAV_W + 8, 0)
    ns:Paint(rule, "SetVertexColor", "@border", 0.6)
    sheet.NavCounts = function()
        for i, b in ipairs(buttons) do b.count:SetText(items[i].count and items[i].count() or "") end
    end
    -- a section whose heading is not showing just now (no themes of your own yet) is left off the list
    page.NavRefresh = function()
        local n = 0
        for i, b in ipairs(buttons) do
            local fs = items[i].fs
            if fs and fs.IsShown and fs:IsShown() == false then
                b:Hide()
            else
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", 0, -n * 25)
                b:Show()
                n = n + 1
            end
        end
        sheet.NavCounts()
    end
    -- for the search and the guide: the section a place on the sheet belongs to, or one by its name
    sheet.SelectFor = function(y)
        if not sheet.banded then return false end
        local at = 1
        for i, item in ipairs(items) do if (tonumber(y) or 0) >= item.top then at = i end end
        Mark(at); sheet.NavSelect(at)
        return at
    end
    sheet.SelectTitle = function(title)
        for i, item in ipairs(items) do
            if item.title == title then Mark(i); sheet.NavSelect(i); return i end
        end
        return false
    end
    Mark(1)
    if sheet.banded then sheet.NavSelect(1) end
    sheet.NavCounts()
end

local function Build()
    local th = ns.theme
    O.frame = CreateFrame("Frame", "FantasyGlassUIConfig", UIParent, ns.template)
    ns.configFrame = O.frame
    O.frame:SetSize(980, 680)                                  -- (the list of sections, then a page 736 wide)
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
    tinsert(UISpecialFrames, "FantasyGlassUIConfig")

    local logo = O.frame:CreateTexture(nil, "OVERLAY")           -- the add-on's icon, beside its name
    logo:SetSize(24, 24)
    logo:SetPoint("TOPLEFT", 16, -11)
    logo:SetTexture(ns.MEDIA .. "icon.tga")
    local title = O.frame:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 17, true)
    title:SetPoint("TOPLEFT", 48, -15)
    title:SetJustifyH("LEFT")
    if title.SetWordWrap then title:SetWordWrap(false) end
    title:SetText(ns:AccentHex() .. "Fantasy Glass|r UI  |cff9c8c6cv" .. ns.version .. "  by " .. ns.author .. "|r")
    O.frame.title = title

    local roleText = O.frame:CreateFontString(nil, "OVERLAY")
    ns:Font(roleText, 11)
    ns:Paint(roleText, "SetTextColor", "dim")
    roleText:SetPoint("LEFT", title, "RIGHT", 16, 0)
    O.frame:SetScript("OnShow", function()
        local r = ns.roles[ns.db.role]
        roleText:SetText(ns:Tr("Role:") .. " " .. (r and (ns:RoleHex(ns.db.role) .. ns:Tr(r.label) .. "|r") or ("|cffa59575" .. ns:Tr("not set") .. "|r"))
            .. "     Profile: " .. ns:AccentHex() .. ns.profile .. "|r")
    end)

    local close = ns:CreateButton(O.frame, "X", 24, 24, function() O.frame:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)

    -- Language: a button at the top of every tab. The word "Language" on it is never translated, so
    -- the way back can be found by someone who picked a language they cannot read.
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
                        O.frame.note:Show()                    -- labels change when the interface reloads
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
    function O.frame.RefreshLanguage() end                     -- the current choice is shown in the list and the tooltip
    O.frame.languageButton = langBtn
    -- the role and profile text stops short of the button, and is cut with "..." if it would not fit
    -- (the role and profile line sits in the footer: see below)
    roleText:SetJustifyH("LEFT")
    roleText:SetWordWrap(false)
    langBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Language: " .. ns:LanguageName(ns:Language()))
        GameTooltip:AddLine(ns:Tr("The language Fantasy Glass UI's own labels are shown in. A change takes effect when the interface reloads."), 1, 1, 1, true)
        GameTooltip:AddLine(ns:Tr("Names of items, spells and places come from the game, in the game's language."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    langBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- tabs
    local defs = { { "features", "Features", O.BuildFeatures, true }, { "look", "Look", O.BuildLook, true }, { "layout", "Layout", O.BuildLayout, true, whole = true },
                   { "combat", "Combat", O.BuildCombat, true }, { "profiles", "Profiles", O.BuildProfiles, nil, whole = true },
                   { "bars", "Bars and frames", function(page) return ns.BuildBarsPage(page) end, true },
                   { "tools", "Tools", function(page) return ns.BuildToolsPage(page) end, true, whole = true },
                   { "guide", "Guide", function(page) return ns.BuildGuidePage(page) end, true } }
    -- eight tabs: each as wide as its name needs, side by side
    local tabX = 18
    for i, d in ipairs(defs) do
        local id = d[1]
        -- a tab is its name with a line under the one that is open: no boxes
        local b = CreateFrame("Button", nil, O.frame)
        b.text = b:CreateFontString(nil, "OVERLAY")
        ns:Font(b.text, 12)
        b.text:SetPoint("CENTER", 0, 1)
        b.text:SetText(ns:Tr(d[2]))
        local wide = b.text.GetStringWidth and b.text:GetStringWidth()
        if type(wide) ~= "number" or wide <= 0 then wide = #ns:Tr(d[2]) * 7 end
        wide = math.floor(wide + 22)
        b:SetSize(wide, 26)
        b:SetPoint("TOPLEFT", tabX, -42)
        tabX = tabX + wide + 2
        b.line = b:CreateTexture(nil, "ARTWORK")
        b.line:SetTexture(ns.FLAT)
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT", 6, 0)
        b.line:SetPoint("BOTTOMRIGHT", -6, 0)
        ns:Paint(b.line, "SetVertexColor", "@accent", 1)
        function b:SetSelected(on)
            self.selected = on and true or false
            if self.selected then self.line:Show(); ns:Paint(self.text, "SetTextColor", "@accent")
            else self.line:Hide(); ns:Paint(self.text, "SetTextColor", "dim") end
        end
        b:SetScript("OnClick", function() O.ShowPage(id) end)
        b:SetScript("OnEnter", function(self) if not self.selected then ns:Paint(self.text, "SetTextColor", "text") end end)
        b:SetScript("OnLeave", function(self) self:SetSelected(self.selected) end)
        b:SetSelected(false)
        O.tabButtons[id] = b
        local page = CreateFrame("Frame", nil, O.frame)
        page:SetPoint("TOPLEFT", 22, -84)
        page:SetPoint("BOTTOMRIGHT", -22, 54)
        page:Hide()
        O.pages[id] = page
        ns.indexingTab = id                                  -- (labelled controls made from here on note which tab they are on)
        -- A tab is built on a sheet that scrolls, to the right of the list of its sections; only the
        -- chosen section shows (the page is 542 tall: the window less its header and footer). Layout,
        -- Profiles and Tools are whole pages instead: everything on them at once, in the middle of the window.
        local area, sheet = ns:ScrollArea(page, 736, VIEW_H)
        area:SetPoint("TOPLEFT", d.whole and WHOLE_X or (NAV_W + 18), 0)
        d[3](sheet)
        page.area, page.sheet = area, sheet
        if type(rawget(sheet, "contentHeight")) ~= "number" then
            sheet.contentHeight = VIEW_H
            area:SetContentHeight(VIEW_H)
        end
        if not d.whole then BuildNav(page, sheet, area, d[2]) end
        page.Refresh = function() if sheet.Refresh then sheet.Refresh() end end
        ns.indexingTab = nil
    end

    local rule = ns:Divider(O.frame, 12)
    rule:SetPoint("TOPLEFT", 40, -69)
    rule:SetPoint("TOPRIGHT", -40, -69)

    O.frame.note = O.frame:CreateFontString(nil, "OVERLAY")
    ns:Font(O.frame.note, 11)
    O.frame.note:SetPoint("BOTTOMRIGHT", -138, 14)            -- beside the Reload button
    O.frame.note:SetWidth(128)
    O.frame.note:SetJustifyH("RIGHT")
    O.frame.note:SetText("|cffffd100" .. ns:Tr("Reload to apply these changes.") .. "|r")
    O.frame.note:Hide()

    local role = ns:CreateButton(O.frame, "Run Setup Again", 132, 24, function() O.frame:Hide(); ns:ShowSetup() end)
    role:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns:Tr("Run Setup Again"))
        GameTooltip:AddLine(ns:Tr("Opens the first-run setup: role, look, lettering and portraits, layout. It starts from your current choices and changes nothing until you click."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    role:HookScript("OnLeave", function() GameTooltip:Hide() end)
    role:SetPoint("BOTTOMLEFT", 20, 14)
    local report = ns:CreateButton(O.frame, "Report a Problem", 132, 24, function() ns:ProblemReport() end)
    report:SetPoint("LEFT", role, "RIGHT", 8, 0)
    report:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(ns:Tr("Report a Problem"))
        GameTooltip:AddLine(ns:Tr("Gathers what is needed to look into a problem - what is running, any errors, the settings you changed and your other add-ons - into text you can copy. Nothing is sent by itself: add-ons have no access to the internet."), 1, 1, 1, true)
        if ns:ReportLink() then GameTooltip:AddLine(ns:Tr("The window shows where to send it."), 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    report:HookScript("OnLeave", function() GameTooltip:Hide() end)
    local reload = ns:CreateButton(O.frame, "Reload UI", 110, 26, ReloadUI)
    reload:SetPoint("BOTTOMRIGHT", -20, 14)

    -- Search: one box that finds a setting on any tab. Results open above it; choosing one goes to
    -- its tab, scrolls it into view if the tab scrolls, and rings it for a moment.
    -- (the box is in the header, beside the Language button; the role and profile line takes its old place in the footer)
    local searchBox = ns:CreateEditBox(O.frame, 180, 24, "Search all options")
    searchBox:SetPoint("RIGHT", langBtn, "LEFT", -8, 0)
    title:SetPoint("RIGHT", searchBox, "LEFT", -12, 0)        -- (a wide lettering style is cut short rather than running under the box)
    roleText:ClearAllPoints()
    roleText:SetPoint("LEFT", report, "RIGHT", 14, 0)
    roleText:SetWidth(210)
    roleText:SetJustifyH("LEFT")
    if roleText.SetWordWrap then roleText:SetWordWrap(false) end
    local results = CreateFrame("Frame", nil, O.frame, ns.template)
    results:SetFrameStrata("FULLSCREEN_DIALOG")
    results:SetBackdrop(ns.BACKDROP)
    ns:Paint(results, "SetBackdropColor", "@bg", 1)
    ns:Paint(results, "SetBackdropBorderColor", "@accent", 1)
    results:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    results:SetWidth(300)
    results:Hide()
    results.rows = {}
    local ring = CreateFrame("Frame", nil, O.frame, ns.template)   -- the marker round the setting that was found
    ring:SetFrameStrata("FULLSCREEN_DIALOG")
    ring:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 2 })
    ns:Paint(ring, "SetBackdropBorderColor", "@accent", 1)
    ring:Hide()
    local TAB_NAMES = {}
    for _, d in ipairs(defs) do TAB_NAMES[d[1]] = d[2] end
    local function GoTo(hit)
        results:Hide()
        searchBox:ClearFocus()
        O.ShowPage(hit.tab)
        local page, target = O.pages[hit.tab], hit.frame
        if page and page.sheet and page.sheet.Reveal then page.sheet.Reveal(target) end      -- (a tab that shows one section at a time)
        if page and page.sheet and rawget(page.sheet, "banded") and type(target) == "table" and target.GetTop then
            local sheetTop, mine = page.sheet:GetTop(), target:GetTop()
            if type(sheetTop) == "number" and type(mine) == "number" then page.sheet.SelectFor(sheetTop - mine) end
        end
        if page and page.area and page.sheet and type(target) == "table" and target.GetTop then
            local top, mine, height = page.sheet:GetTop(), target:GetTop(), target.GetHeight and target:GetHeight()
            if type(top) == "number" and type(mine) == "number" then
                page.area:ScrollToShow(top - mine - 24, (type(height) == "number" and height or 24) + 48)
            end
        end
        if type(target) == "table" and target.GetObjectType then
            ring:ClearAllPoints()
            ring:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
            ring:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
            ring:Show()
            ring.shownAt = GetTime()
            ns:After(2.5, function() if ring.shownAt and GetTime() - ring.shownAt >= 2.4 then ring:Hide() end end)
        end
        ns.lastSearchHit = hit
    end
    O.frame.GoToOption = GoTo
    ns.GoToOption = GoTo
    ns.OptionsSheet = function(id) return O.pages[id] and O.pages[id].sheet end
    ns.HideConfig = function() O.frame:Hide() end
    ns.ShowReloadNote = function() O.frame.note:Show() end
    local function ShowResults(query)
        local hits = ns:SearchOptions(query or searchBox:GetText(), 10)
        O.frame.searchHits = hits
        if #hits == 0 then results:Hide(); return hits end
        for i, hit in ipairs(hits) do
            local row = results.rows[i]
            if not row then
                row = ns:CreateButton(results, "", 290, 22, function(self) if self.hit then GoTo(self.hit) end end)
                row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 24)
                row.text:ClearAllPoints()
                row.text:SetPoint("LEFT", 8, 0)
                row.text:SetPoint("RIGHT", -8, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                results.rows[i] = row
            end
            row.hit = hit
            row.text:SetText(ns:AccentHex() .. ns:Tr(TAB_NAMES[hit.tab] or hit.tab) .. "|r  " .. hit.label)
            row:Show()
        end
        for i = #hits + 1, #results.rows do results.rows[i]:Hide() end
        results:SetHeight(#hits * 24 + 8)
        results:Show()
        return hits
    end
    O.frame.SearchOptions = function(text) searchBox:SetText(text or ""); return ShowResults(text or "") end
    searchBox:HookScript("OnTextChanged", function() ShowResults() end)
    searchBox:HookScript("OnEnterPressed", function() local hits = O.frame.searchHits; if hits and hits[1] then GoTo(hits[1]) end end)
    searchBox:HookScript("OnEscapePressed", function(self) self:SetText(""); results:Hide(); self:ClearFocus() end)
    O.frame:HookScript("OnHide", function() results:Hide(); ring:Hide(); if ns.NoteSettingChanges then pcall(ns.NoteSettingChanges, ns) end end)

    local last = type(ns.root) == "table" and ns.root.optionsPage
    O.ShowPage((type(last) == "string" and O.pages[last]) and last or "features")
end

function ns:NoteNothing() end        -- settings that are simply read the next time they are needed


function ns:ToggleConfig(page)
    ns:InitDB()
    if not O.frame then Build() end
    local section
    if page == "clickcast" then page, section = "combat", "Click casting" end      -- (it is a section of Combat now)
    if page == "colors" then page, section = "look", "Portraits and class colors" end    -- (and class colors are part of Look)
    if page and O.pages[page] then
        O.ShowPage(page)
        if section and O.pages[page].sheet and rawget(O.pages[page].sheet, "SelectTitle") then O.pages[page].sheet.SelectTitle(section) end
        O.frame:Show()
    elseif O.frame:IsShown() then
        O.frame:Hide()
    else
        O.frame:Show()
    end
end

-- (Config.lua is the last of this folder's files to load: reaching here means all of it is in.)
ns.optionsLoaded = true
