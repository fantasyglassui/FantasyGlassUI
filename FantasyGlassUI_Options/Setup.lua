-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- First-run setup: a guided tour in nine steps. It opens on first login, and again from the
-- "Run Setup Again" button in /fgui or with /fgui setup. Where it can, each choice applies as you
-- click; choices that need the interface to reload are collected, and the last step reloads once.
local frame
local step, pages, dots = 1, {}, {}
local refreshers = {}          -- re-mark every choice from the current settings when the wizard opens
local needReload = false       -- a feature switch or the theme family changed
local STEPS = { "Welcome", "Your role", "The look", "Lettering", "Features", "Bags and windows", "How it behaves", "Layout", "All set" }
local PAGE_W = 474

function ns:SetRole(key)
    ns:InitDB()
    ns.db.role = key
    if ns.RefreshRoleHUD then ns.RefreshRoleHUD() end
    if ns.roles[key] then
        ns:Print("Role set to %s. Change it any time with |cffffff00/fgui setup|r.", ns:RoleHex(key) .. ns:Tr(ns.roles[key].label) .. "|r")
    else
        ns:Print("Role skipped. Choose one any time with |cffffff00/fgui setup|r.")
    end
end

local function Heading(page, text, sub)
    local h = page:CreateFontString(nil, "OVERLAY")
    ns:Font(h, 18, true)
    h:SetPoint("TOPLEFT", 0, 0)
    h:SetText(ns:Tr(text))
    ns:Paint(h, "SetTextColor", "@accent")
    local s = page:CreateFontString(nil, "OVERLAY")
    ns:Font(s, 12)
    s:SetPoint("TOPLEFT", 0, -26)
    s:SetWidth(PAGE_W)
    s:SetJustifyH("LEFT")
    s:SetText(ns:Tr(sub))
    ns:Paint(s, "SetTextColor", "dim")
end

local function Label(page, text, x, y)
    local fs = page:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 13, true)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(ns:Tr(text))
    ns:Paint(fs, "SetTextColor", "@accent")
    return fs
end

local function Note(page, text, y)
    local fs = page:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 11)
    fs:SetPoint("TOPLEFT", 0, y)
    fs:SetWidth(PAGE_W)
    fs:SetJustifyH("LEFT")
    fs:SetText(ns:Tr(text))
    ns:Paint(fs, "SetTextColor", "faint")
    return fs
end

-- A row of mutually exclusive choices; the current one is outlined in the accent color.
local function Choices(page, y, items, getCurrent, onPick, perRow, width)
    local buttons = {}
    local function Mark(key)
        for k, b in pairs(buttons) do
            b.picked = (k == key)
            if b.picked then ns:Paint(b, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(b, "SetBackdropBorderColor", "@border", 1) end
        end
    end
    for i, item in ipairs(items) do
        local key, label = item[1], item[2]
        local b = ns:CreateButton(page, label, width, 26, function() onPick(key); Mark(key) end)
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        b:SetPoint("TOPLEFT", col * (width + 8), y - row * 32)
        b:HookScript("OnLeave", function(self) if self.picked then ns:Paint(self, "SetBackdropBorderColor", "@accent", 1) end end)
        buttons[key] = b
    end
    Mark(getCurrent())
    refreshers[#refreshers + 1] = function() Mark(getCurrent()) end
    return y - math.ceil(#items / perRow) * 32
end

-- A switch for one setting. `reload` marks settings that only take effect after a reload.
local function Toggle(page, x, y, key, label, desc, reload)
    if ns.FeatureLabel then label = ns:FeatureLabel(key, label) end
    desc = desc or (ns.featureDesc and ns.featureDesc[key]) or ""
    local cb = ns:CreateCheckbox(page, label, ns.db[key], function(v)
        ns.db[key] = v
        if reload then needReload = true end
        if (key == "healthNumbers" or key == "powerNumbers") and ns.RefreshHealthText then ns:RefreshHealthText() end
        if key == "questGuide" and ns.GuideApplySwitch then ns:GuideApplySwitch() end
    end)
    cb:SetWidth(230)
    cb:SetPoint("TOPLEFT", x, y)
    cb:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns:Tr(label))
        if desc ~= "" then GameTooltip:AddLine(ns:Tr(desc), 1, 1, 1, true) end
        if reload then GameTooltip:AddLine(ns:Tr("Takes effect when the setup reloads the interface at the end."), 0.6, 0.6, 0.6, true) end
        GameTooltip:Show()
    end)
    cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
    refreshers[#refreshers + 1] = function() cb:SetChecked(ns.db[key]) end
    return cb
end

-- The label a feature has on the Features tab, so both places use the same words.
local function FeatureName(key)
    for _, group in ipairs(ns.featureGroups or {}) do
        for _, opt in ipairs(group[2]) do
            if opt[1] == key then return opt[2] end
        end
    end
    return key
end

-- Step 1: welcome, and how much of the interface to take over ---------------------------------------------
-- Picking a language in the setup. Every label was written when its window was built, so the change
-- needs a reload; the setup then opens again by itself, in the language chosen.
function ns:SetupPickLanguage(code)
    if not ns:SetLanguage(code) then return false end
    ns.root.resumeSetup = true
    ReloadUI()
    return true
end

local function BuildWelcome(page)
    Heading(page, "Welcome to Fantasy Glass UI", "A short tour of the choices worth making; about two minutes. Each choice applies as you click where it can, and all of it can be changed later in /fgui.")

    -- language: each under its own name, so it can be found whatever is showing now
    Label(page, "Language", 0, -66)
    -- one button showing the language in use; it opens the list of all of them, each under its own name
    local langButtons = {}
    local pick = ns:CreateButton(page, "", 200, 24, nil)
    pick:SetPoint("TOPLEFT", 96, -62)
    local list = CreateFrame("Frame", nil, page, ns.template)
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetBackdrop(ns.BACKDROP)
    ns:Paint(list, "SetBackdropColor", "@bg", 1)
    ns:Paint(list, "SetBackdropBorderColor", "@accent", 1)
    list:SetSize(200, #ns.languages * 24 + 10)
    list:SetPoint("TOPLEFT", pick, "BOTTOMLEFT", 0, -2)
    list:Hide()
    for i, def in ipairs(ns.languages) do
        local code = def[1]
        local b = ns:CreateButton(list, "", 190, 22, function() list:Hide(); ns:SetupPickLanguage(code) end)
        b.text:SetText(ns:LanguageName(code))
        ns:LanguageFont(b.text, code)                         -- (Korean and Chinese in a face that has their letters)
        b:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 24)
        b:HookScript("OnLeave", function(self)
            if self.picked then ns:Paint(self, "SetBackdropBorderColor", "@accent", 1) end
        end)
        langButtons[code] = b
    end
    pick:SetScript("OnClick", function() if list:IsShown() then list:Hide() else list:Show() end end)
    page.langList = list
    local function MarkLanguage()
        local now = ns:Language()
        pick.text:SetText(ns:LanguageName(now) .. "  v")
        ns:LanguageFont(pick.text, now)
        for code, b in pairs(langButtons) do
            b.picked = (code == now)
            if b.picked then ns:Paint(b, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(b, "SetBackdropBorderColor", "@border", 1) end
        end
    end
    MarkLanguage()
    refreshers[#refreshers + 1] = MarkLanguage
    Note(page, "Choosing a language reloads the interface and brings you straight back here.", -92)

    Label(page, "How much should Fantasy Glass UI do?", 0, -114)
    local cards = {}
    local defs = {
        { "STANDARD",   "Standard",   "How it comes: everything except the four that flash, pop up or act on their own. Step 5 lets you switch those on." },
        { "EVERYTHING", "Everything", "Every feature on, those four included." },
        { "MINIMAL",    "Minimal",    "Only the core: frames, bars, minimap, quests, bags, chat and windows. No extra helpers." },
    }
    local custom = Note(page, "", -310)
    function page.Mark()
        local current = ns.CurrentPreset and ns:CurrentPreset()
        for key, card in pairs(cards) do
            if key == current then ns:Paint(card, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(card, "SetBackdropBorderColor", "@border", 1) end
        end
        custom:SetText(current and "" or ns:Tr("Your switches have been set by hand, so none of the three is marked."))
    end
    for i, def in ipairs(defs) do
        local card = ns:CreateButton(page, "", PAGE_W, 52, function()
            if ns.ApplyPreset and ns:ApplyPreset(def[1]) > 0 then needReload = true end
            for _, refresh in ipairs(refreshers) do pcall(refresh) end      -- the switches on later steps follow
        end)
        card:SetPoint("TOPLEFT", 0, -136 - (i - 1) * 58)
        card.text:ClearAllPoints()
        card.text:SetPoint("TOPLEFT", 14, -7)
        ns:Font(card.text, 15, true)
        card.text:SetText(ns:Tr(def[2]))
        card:HookScript("OnLeave", function() page.Mark() end)
        local desc = card:CreateFontString(nil, "OVERLAY")
        ns:Font(desc, 11)
        desc:SetPoint("TOPLEFT", 14, -26)
        desc:SetWidth(PAGE_W - 30)
        desc:SetJustifyH("LEFT")
        desc:SetText(ns:Tr(def[3]))
        ns:Paint(desc, "SetTextColor", "dim")
        cards[def[1]] = card
    end
    page.Mark()
    refreshers[#refreshers + 1] = page.Mark
end

-- Step 2: role ------------------------------------------------------------------------------------------------
local function BuildRole(page)
    Heading(page, "What do you play?", "This sets up the role HUD, and the layout offered in the last step.")
    for i, key in ipairs(ns.roleOrder) do
        local role = ns.roles[key]
        local r, g, b = role.color[1], role.color[2], role.color[3]
        local btn = ns:CreateButton(page, "", 474, 62, function() ns:SetRole(key); page.Mark() end)
        btn:SetPoint("TOPLEFT", 0, -62 - (i - 1) * 70)
        btn.text:ClearAllPoints()
        btn.text:SetPoint("TOPLEFT", 14, -8)
        ns:Font(btn.text, 16, true)
        btn.text:SetText(role.label)
        btn.text:SetTextColor(r, g, b)
        btn:HookScript("OnLeave", function(self) self.text:SetTextColor(r, g, b); page.Mark() end)
        local desc = btn:CreateFontString(nil, "OVERLAY")
        ns:Font(desc, 11)
        desc:SetPoint("TOPLEFT", 14, -30)
        desc:SetWidth(444)
        desc:SetJustifyH("LEFT")
        desc:SetText(role.desc)
        ns:Paint(desc, "SetTextColor", "dim")
        btn.role = key
        page[key] = btn
    end
    function page.Mark()
        for _, key in ipairs(ns.roleOrder) do
            if ns.db.role == key then ns:Paint(page[key], "SetBackdropBorderColor", "@accent", 1)
            else ns:Paint(page[key], "SetBackdropBorderColor", "@border", 1) end
        end
    end
    page.Mark()
    refreshers[#refreshers + 1] = page.Mark
end


-- Step 3: the look: glass or fantasy first, then every theme of that family, then the accent color.
-- (Themes you made yourself get a third group, which only appears once you have some.)
local function BuildLook(page)
    Heading(page, "Pick a look", "Choose glass, fantasy or runic, then a theme. The accent is the highlight color. Everything applies as you click, and all of it can be changed later on the Look tab of /fgui.")

    local COLS, BW = 4, 114
    local family = "GLASS"
    ns.setupLookPage = page
    local familyButtons, themeButtons, swatches = {}, {}, {}
    local Refresh

    local function Mark(btn, on)
        btn.picked = on
        if on then ns:Paint(btn, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(btn, "SetBackdropBorderColor", "@border", 1) end
    end
    local function FamilyOf(key)
        local t = ns.themes[key]
        if not t then return "GLASS" end
        if t.custom then return "MINE" end
        return (t.style == "GLASS") and "GLASS" or (t.style == "RUNIC") and "RUNIC" or "FANTASY"
    end
    local function ThemesOf(which)
        local list = {}
        for _, key in ipairs(ns.themeOrder) do
            if ns.themes[key] and FamilyOf(key) == which then list[#list + 1] = key end
        end
        return list
    end

    local note = page:CreateFontString(nil, "OVERLAY")
    ns:Font(note, 11)
    note:SetPoint("TOPLEFT", 0, -272)
    note:SetWidth(474)
    note:SetJustifyH("LEFT")
    ns:Paint(note, "SetTextColor", "faint")

    local function Pick(key)
        local t = ns.themes[key]
        if not t then return end
        ns.db.theme = key
        ns.db.accent = t.accent or ns.db.accent
        if not ns:Retheme() then needReload = true end       -- glass <-> fantasy: finishes at the reload
        Refresh()
    end
    page.Pick = Pick

    local families = { { "GLASS", "Glass" }, { "FANTASY", "Fantasy" }, { "RUNIC", "Runic" }, { "MINE", "My themes" } }
    for i, def in ipairs(families) do
        local b = ns:CreateButton(page, def[2], 112, 26, function() family = def[1]; Refresh() end)
        b:SetPoint("TOPLEFT", (i - 1) * 118, -70)
        b:HookScript("OnLeave", function(self) Mark(self, self.picked) end)
        familyButtons[def[1]] = b
    end
    page.SetFamily = function(which) family = which; Refresh() end

    -- the themes of the chosen family: four rows show at a time, and the grid scrolls for the rest
    local ROWS_SHOWN = 4
    local grid, sheet = ns:ScrollArea(page, PAGE_W - 12, ROWS_SHOWN * 30 - 4)
    grid:SetPoint("TOPLEFT", 0, -106)
    page.themeGrid = grid
    local function ThemeButton(i)
        if themeButtons[i] then return themeButtons[i] end
        local b = ns:CreateButton(sheet, "", BW - 3, 24, function(self) if self.key then Pick(self.key) end end)
        b:SetPoint("TOPLEFT", ((i - 1) % COLS) * (BW + 3), -math.floor((i - 1) / COLS) * 30)
        b:HookScript("OnLeave", function(self) Mark(self, self.picked) end)
        b:HookScript("OnEnter", function(self)
            local t = self.key and ns.themes[self.key]
            if not t then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(t.name)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        themeButtons[i] = b
        return b
    end

    local label = page:CreateFontString(nil, "OVERLAY")
    ns:Font(label, 12)
    label:SetPoint("TOPLEFT", 0, -241)
    label:SetText(ns:Tr("Accent"))
    ns:Paint(label, "SetTextColor", "dim")
    for i, key in ipairs(ns.accentOrder) do
        local sw = CreateFrame("Button", nil, page, ns.template)
        sw:SetSize(18, 18)
        sw:SetPoint("TOPLEFT", 58 + (i - 1) * 22, -238)
        sw:SetBackdrop(ns.BACKDROP)
        local r, g, b = ns:AccentColor(key)
        sw:SetBackdropColor(r, g, b, 1)
        sw:SetScript("OnClick", function() ns.db.accent = key; ns:Retheme(); Refresh() end)
        sw:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(key == "CLASS" and ns:Tr("Your class color") or (key:sub(1, 1) .. key:sub(2):lower()))
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        swatches[key] = sw
    end

    Refresh = function()
        ns:RegisterCustomThemes()
        local mine = ThemesOf("MINE")
        if family == "MINE" and #mine == 0 then family = "GLASS" end
        for key, b in pairs(familyButtons) do
            Mark(b, key == family)
            if key == "MINE" then if #mine > 0 then b:Show() else b:Hide() end end
        end
        local list = ThemesOf(family)
        local current
        for i, key in ipairs(list) do
            local b = ThemeButton(i)
            b.key = key
            b.text:SetText((ns.themes[key].name:gsub(" %(.-%)$", ""):gsub("^Fantasy: ", ""):gsub("^Glass: ", "")))
            Mark(b, key == (ns.db.theme or "SMOKE"))
            if key == (ns.db.theme or "SMOKE") then current = i end
            b:Show()
        end
        for i = #list + 1, #themeButtons do themeButtons[i]:Hide() end
        grid:SetContentHeight(math.ceil(#list / COLS) * 30 - 6)
        page.themeCount = #list
        if family ~= page.shownFamily then                   -- a different family: start where the theme in use is
            page.shownFamily = family
            if current then grid:ScrollToShow(math.floor((current - 1) / COLS) * 30, 24) else grid:ScrollTo(0) end
        end
        for key, sw in pairs(swatches) do
            if key == (ns.db.accent or "AZURE") then sw:SetBackdropBorderColor(1, 1, 1, 1) else sw:SetBackdropBorderColor(0, 0, 0, 1) end
        end
        note:SetText(needReload and ns:Tr("Glass and fantasy panels are built differently, so this change finishes when the setup reloads the interface at the end.") or "")
    end
    -- each time the setup opens: show the family of the theme in use
    refreshers[#refreshers + 1] = function() family = FamilyOf(ns.db.theme or "SMOKE"); Refresh() end
    family = FamilyOf(ns.db.theme or "SMOKE")
    Refresh()
end


-- Step 4: lettering, text size, portraits -----------------------------------------------------------------
local function BuildLettering(page)
    ns.setupLetteringPage = page
    Heading(page, "Lettering", "The lettering style changes every label. Text size scales all of it. Portraits are what the unit frames show beside the health bar.")
    local lettering = {}
    for _, key in ipairs(ns.fontOrder) do lettering[#lettering + 1] = { key, ns.fontStyles[key].name } end
    -- three and a half rows show at a time (the half row says "there is more"), and the grid scrolls
    local grid, sheet = ns:ScrollArea(page, PAGE_W - 12, 110)
    grid:SetPoint("TOPLEFT", 0, -62)
    local bottom = Choices(sheet, 0, lettering, function() return ns.db.fontStyle or "GLASS" end,
        function(key) ns.db.fontStyle = key; ns:Retheme() end, 3, 148)
    grid:SetContentHeight(-bottom - 6)
    page.letteringGrid, page.letteringCount = grid, #lettering
    refreshers[#refreshers + 1] = function()                 -- each time the setup opens: show the style in use
        for i, item in ipairs(lettering) do
            if item[1] == (ns.db.fontStyle or "GLASS") then grid:ScrollToShow(math.floor((i - 1) / 3) * 32, 26) end
        end
    end
    local y = -62 - 110 - 8
    Label(page, "Text size", 0, y - 4)
    y = Choices(page, y - 26, { { 90, "Small" }, { 100, "Normal" }, { 115, "Large" }, { 130, "Larger" } },
        function() return tonumber(ns.db.fontScale) or 100 end,
        function(v) ns.db.fontScale = v; ns:Retheme() end, 4, 112)
    Label(page, "Portraits", 0, y - 4)
    Choices(page, y - 26, { { "3D", "3D model" }, { "2D", "2D picture" }, { "CLASS", "Class emblem" }, { "OFF", "None" } },
        function() return ns.db.ufPortrait or "3D" end,
        function(key)
            ns.db.ufPortrait = key
            if ns.RefreshUnitFrames then ns:RefreshUnitFrames() end
        end, 4, 112)
end

-- Step 5: the helpers most worth a decision ---------------------------------------------------------------
local function BuildFeatures(page)
    Heading(page, "Choose your features", "The helpers most worth a decision. Hover one to read what it does. Every switch the add-on has is on the Features tab of /fgui.")
    local _, class = UnitClass("player")
    local fight = { "cooldowns", "damageMeter", "swingTimer", "aggroWarn", "classBar", "roleHUD" }
    if class == "SHAMAN" then fight[#fight + 1] = "totems" end
    if class == "SHAMAN" or class == "ROGUE" then fight[#fight + 1] = "imbueReminder" end
    local around = { "toasts", "chatBubbles", "lootRoll", "buttonBag", "afkScreen", "levelShot", "autoSell", "autoRepair", "autoQuest" }
    Label(page, "In a fight", 0, -68)
    for i, key in ipairs(fight) do
        if not (ns.FeatureHidden and ns:FeatureHidden(key)) then Toggle(page, 0, -68 - i * 24, key, FeatureName(key), nil, true) end
    end
    Label(page, "Around the game", 244, -68)
    for i, key in ipairs(around) do Toggle(page, 244, -68 - i * 24, key, FeatureName(key), nil, true) end
    -- the quest guide: on or off here, and it applies at once (no reload)
    -- (under the left column, which is the shorter one, so the page keeps its height)
    -- (quest guides are not released yet: the switch is only offered where they have been unlocked)
    if ns.GuideUnlocked and ns:GuideUnlocked() then
        page.guideToggle = Toggle(page, 0, -68 - (#fight + 1) * 24, "questGuide", "Quest guides", "Follow a quest route one step at a time, with a panel for the step you are on and an arrow pointing to it. Nothing shows until you follow a guide.")
    end
    Note(page, "Auto quest accepts and hands in quests without asking, so it is off unless you tick it.", -302)
end

-- Step 6: bags, bank, the game's windows, and how see-through panels are ------------------------------
local function BuildWindows(page)
    Heading(page, "Bags and windows", "Fantasy Glass UI can replace the game's bags and bank with a single window of its own, and restyle the game's other windows to match.")
    for i, key in ipairs({ "bagWindow", "bankWindow", "storage", "itemCounts" }) do
        Toggle(page, 0, -44 - i * 24, key, FeatureName(key), nil, true)
    end
    for i, key in ipairs({ "windows", "characterWindow", "spellbook", "rounded" }) do
        Toggle(page, 244, -44 - i * 24, key, FeatureName(key), nil, true)
    end
    Label(page, "Panels on screen", 0, -172)
    local y = Choices(page, -194, { { 55, "See-through" }, { 78, "Normal" }, { 90, "Dense" }, { 100, "Solid" } },
        function() return tonumber(ns.db.panelAlpha) or 78 end,
        function(v) ns.db.panelAlpha = v; ns:Retheme() end, 4, 112)
    Label(page, "Windows", 0, y - 4)
    Choices(page, y - 26, { { 85, "Lighter" }, { 95, "Normal" }, { 100, "Solid" } },
        function() return tonumber(ns.db.windowAlpha) or 95 end,
        function(v) ns.db.windowAlpha = v; ns:Retheme() end, 4, 112)
    Note(page, "The two opacity settings apply to glass themes; fantasy panels are always solid.", -304)
end

-- Step 7: small touches that apply straight away, and the cooldown tracker ----------------------------
local function BuildBehavior(page)
    Heading(page, "How it behaves", "Small touches. These apply straight away.")
    local _, class = UnitClass("player")
    local list = {
        { "smoothBars", "Bars glide to their new value", "Health and power bars slide to a new value instead of jumping." },
        { "fades",      "Windows fade in",               "Windows fade in when they open." },
        { "hitFlash",   "Flash on critical hits and heals", "Your frame and your target's flash red on a critical hit taken, green on a critical heal." },
        { "idleFade",   "Dim my frame when idle",        "Out of combat, at full health and with no target, your own frame dims." },
    }
    list[#list + 1] = { "combatFocus", "Dim tracker and info bar in fights", "During combat the quest tracker and the info bar dim right down, and return when the fight ends." }
    list[#list + 1] = { "tooltipCursor", "Tooltips follow the mouse", "Tooltips appear at the pointer instead of in the bottom-right corner." }
    list[#list + 1] = { "healthNumbers", "Health as numbers, not %", "Unit frames show how much health is left as an amount (12.4k) instead of a percentage (85%)." }
    list[#list + 1] = { "powerNumbers", "Mana & resources as numbers, not %", "Mana, rage, energy and so on are written as an amount (1.2k) instead of a percentage." }
    list[#list + 1] = { "emblemAnim", "Animated class emblems", "Class emblems move, glow and turn. Off, they hold still. (Choose \"Class emblem\" under Portraits to use them on your frames.)" }
    list[#list + 1] = { "reduceMotion", "Reduce motion", "No fades, pulses, gliding bars or camera drift: things appear and change at once." }
    list[#list + 1] = { "colorblind", "Color-blind safe colors", "Good and bad are shown in blue and orange instead of green and red: on talents, nameplates, the info bar and warnings." }
    if not ns.aurasLocked then
        list[#list + 1] = { "myDebuffsOnly", "Target: only my debuffs", "Shows only the debuffs you applied on the target frame." }
    end
    if class == "SHAMAN" or class == "ROGUE" then
        list[#list + 1] = { "imbueCombatOnly", "Imbue reminder only in combat", "The weapon imbue reminder fades away outside combat." }
    end
    for i, def in ipairs(list) do
        Toggle(page, ((i - 1) % 2) * 244, -44 - math.ceil(i / 2) * 24, def[1], def[2], def[3], false)
    end
    local y = -44 - math.ceil(#list / 2) * 24 - 40
    Label(page, "Cooldown tracker", 0, y)
    local msg = Note(page, "A row of your abilities that have a cooldown, each showing when it is ready. One click fills it from your action bars; you can edit the list later on the Combat tab.", y - 22)
    local result = page:CreateFontString(nil, "OVERLAY")
    ns:Font(result, 12)
    result:SetPoint("TOPLEFT", 236, y - 76)
    result:SetWidth(238)
    result:SetJustifyH("LEFT")
    local fill = ns:CreateButton(page, "Fill from my action bars", 220, 26, function()
        local names = ns.CooldownCandidates and ns:CooldownCandidates(9) or {}
        if #names == 0 then
            result:SetText("|cffffd100" .. ns:Tr("No abilities with a cooldown were found on your action bars.") .. "|r")
            return
        end
        ns.db.cooldownSpells = names
        if ns.RebuildCooldowns then ns:RebuildCooldowns() end
        result:SetText("|cff66dd77" .. format(ns:Tr("%d abilities taken from your action bars."), #names) .. "|r")
    end)
    fill:SetPoint("TOPLEFT", 0, y - 72)
    page.FillCooldowns = function() fill:Click() end
    refreshers[#refreshers + 1] = function() result:SetText("") end
end

-- Step 8: layout ----------------------------------------------------------------------------------------------
local function BuildLayout(page)
    Heading(page, "Place your frames", "Start from a layout made for your role, look at it with sample frames, then drag anything that isn't where you want it.")
    local apply = ns:CreateButton(page, "Use the layout for my role", 230, 28, function() ns:ApplyRoleLayout() end)
    apply:SetPoint("TOPLEFT", 0, -70)
    local preview = ns:CreateButton(page, "Show sample frames", 230, 28, function() ns:TogglePreview() end)
    preview:SetPoint("TOPLEFT", 0, -106)
    local move = ns:CreateButton(page, "Move panels", 230, 28, function() ns:ToggleMove() end)
    move:SetPoint("TOPLEFT", 0, -142)
    Note(page, "Panels snap to a grid and to the centre lines; hold Shift to place one freely. Sizes and scales are on the Layout tab of /fgui, where you can also share a layout as a text string or keep one per talent set.", -186)

    -- coming from another interface: the closest whole-screen setup, one click (Gallery.lua)
    Label(page, "Coming from another UI?", 0, -230)
    local found = ns.OtherUIsFound and ns.OtherUIsFound() or {}
    local foundKey = found[1] and found[1].ui.key
    page.otherUI = {}
    for i, ui in ipairs(ns.OTHER_UIS or {}) do
        local b = ns:CreateButton(page, ui.label, 230, 24, function()
            if ns.ApplyGallery then ns:ApplyGallery(ui.gallery) end
        end)
        b:SetPoint("TOPLEFT", ((i - 1) % 2) * 240, -250 - math.floor((i - 1) / 2) * 28)
        if ui.key == foundKey then ns:Paint(b, "SetBackdropBorderColor", "@accent", 1) end
        page.otherUI[ui.key] = b
    end
    Note(page, found[1] and format(ns:Tr("You have %s: the marked one is the closest. Fantasy Glass UI leaves the jobs that add-on does to it."), found[1].addon)
        or "Each puts your frames where that interface does. One undo (/fgui undo) takes it back.", -308)
end

-- Step 9: what you chose, and what to remember ------------------------------------------------------------
local function BuildFinish(page)
    Heading(page, "All set", "Here is what you chose. Use Back to change anything.")
    local rows = {}
    for i = 1, 6 do
        local label = page:CreateFontString(nil, "OVERLAY")
        ns:Font(label, 12)
        label:SetPoint("TOPLEFT", 0, -50 - (i - 1) * 20)
        ns:Paint(label, "SetTextColor", "dim")
        local value = page:CreateFontString(nil, "OVERLAY")
        ns:Font(value, 12)
        value:SetPoint("TOPLEFT", 150, -50 - (i - 1) * 20)
        value:SetWidth(320)
        value:SetJustifyH("LEFT")
        rows[i] = { label = label, value = value }
    end
    Label(page, "Worth remembering", 0, -184)
    local tips = page:CreateFontString(nil, "OVERLAY")
    ns:Font(tips, 12)
    tips:SetPoint("TOPLEFT", 0, -206)
    tips:SetWidth(PAGE_W)
    tips:SetJustifyH("LEFT")
    if tips.SetSpacing then tips:SetSpacing(4) end
    tips:SetText("|cffffff00/fgui|r  " .. ns:Tr("all the options") .. "\n"
        .. "|cffffff00/fgui move|r  " .. ns:Tr("arrange panels") .. "\n"
        .. "|cffffff00/fgui bind|r  " .. ns:Tr("set keys by hovering an action button and pressing a key") .. "\n"
        .. "|cffffff00/fgui check|r  " .. ns:Tr("a report to copy if something looks wrong"))
    local reload = Note(page, "", -290)

    local PRESETS = { STANDARD = "Standard", EVERYTHING = "Everything", MINIMAL = "Minimal" }
    function page.Refresh()
        local theme = ns.themes[ns.db.theme or "SMOKE"] or ns.themes.SMOKE
        local accent = ns.db.accent or "AZURE"
        local font = ns.fontStyles[ns.db.fontStyle or "GLASS"] or ns.fontStyles.GLASS
        local role = ns.roles[ns.db.role]
        local on, total = 0, 0
        if ns.CountFeatures then on, total = ns:CountFeatures() end
        local preset = ns.CurrentPreset and ns:CurrentPreset()
        local data = {
            { "Role", role and ns:Tr(role.label) or ns:Tr("not chosen") },
            { "Theme", theme.name },
            { "Accent", accent == "CUSTOM" and ns:Tr("your own color") or accent == "CLASS" and ns:Tr("your class color") or (accent:sub(1, 1) .. accent:sub(2):lower()) },
            { "Lettering", ns:Tr(font.name) .. "  (" .. font.face .. ")" },
            { "Features", format(ns:Tr("%d of %d switched on"), on, total) .. "  (" .. ns:Tr(PRESETS[preset] or "set by hand") .. ")" },
            { "Bags", ns:Tr(ns.db.bagWindow and "Fantasy Glass UI's single window" or "the game's own") },
        }
        for i, row in ipairs(rows) do
            row.label:SetText(data[i] and ns:Tr(data[i][1]) or "")
            row.value:SetText(data[i] and data[i][2] or "")
        end
        reload:SetText(ns:Tr("Finish & reload puts everything you chose in place at once."))
    end
    page.Refresh()
end

local function Show(n)
    step = math.max(1, math.min(#STEPS, n))
    for i, page in ipairs(pages) do
        if i == step then page:Show() else page:Hide() end
    end
    if pages[step].Refresh then pcall(pages[step].Refresh) end
    for i, dot in ipairs(dots) do
        if i == step then ns:Paint(dot, "SetVertexColor", "@accent", 1) else ns:Paint(dot, "SetVertexColor", "faint", 0.6) end
    end
    frame.back:SetAlpha(step == 1 and 0.4 or 1)
    frame.next.text:SetText(ns:Tr(step < #STEPS and "Next" or "Finish & reload"))
    frame.count:SetText(step .. " / " .. #STEPS .. "   " .. ns:Tr(STEPS[step]))
end

local function Build()
    frame = CreateFrame("Frame", "FantasyGlassUISetup", UIParent, ns.template)
    frame:SetSize(540, 440)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop(ns.BACKDROP)
    ns:Paint(frame, "SetBackdropColor", "window", 0.97)
    ns:Paint(frame, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(frame)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "FantasyGlassUISetup")

    local logo = frame:CreateTexture(nil, "OVERLAY")           -- the add-on's icon, beside its name
    logo:SetSize(20, 20)
    logo:SetPoint("TOPLEFT", 30, -12)
    logo:SetTexture(ns.MEDIA .. "icon.tga")
    local title = frame:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 13, true)
    title:SetPoint("TOPLEFT", 58, -16)
    title:SetText(ns:Tr("Fantasy Glass UI setup") .. "  |cff808080by " .. ns.author .. "|r")
    ns:Paint(title, "SetTextColor", "dim")
    frame.count = frame:CreateFontString(nil, "OVERLAY")
    ns:Font(frame.count, 11)
    frame.count:SetPoint("TOPRIGHT", -44, -18)
    ns:Paint(frame.count, "SetTextColor", "faint")
    local close = ns:CreateButton(frame, "X", 22, 22, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns:Tr("Close the setup"))
        GameTooltip:AddLine(ns:Tr("What you have chosen so far is kept. Run it again any time from /fgui."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    close:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local builders = { BuildWelcome, BuildRole, BuildLook, BuildLettering, BuildFeatures, BuildWindows, BuildBehavior, BuildLayout, BuildFinish }
    for i, build in ipairs(builders) do
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 30, -48)
        page:SetPoint("BOTTOMRIGHT", -30, 56)
        page:Hide()
        build(page)
        pages[i] = page
        local dot = frame:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(ns.FLAT)
        dot:SetSize(16, 3)
        dot:SetPoint("BOTTOM", frame, "BOTTOM", (i - (#builders + 1) / 2) * 21, 26)
        dots[i] = dot
    end

    frame.back = ns:CreateButton(frame, "Back", 90, 26, function() if step > 1 then Show(step - 1) end end)
    frame.back:SetPoint("BOTTOMLEFT", 30, 16)
    frame.next = ns:CreateButton(frame, "Next", 140, 26, function()
        if step < #STEPS then
            Show(step + 1)
        else
            if not ns.db.role then ns:SetRole("NONE") end
            ns.db.setupDone = true
            -- Finishing always reloads, so everything chosen is in place at once. The tour (and the
            -- note on where everything is) comes after the reload.
            needReload = false
            ns.root.setupJustFinished = true
            frame:Hide()
            ReloadUI()
        end
    end)
    frame.next:SetPoint("BOTTOMRIGHT", -30, 16)
    frame:SetScript("OnHide", function()
        if not ns.db.role then ns.db.role = "NONE" end      -- closing counts as "skip": don't ask again every login
        if needReload then
            needReload = false
            ns:Print("Some of the choices you made in the setup need a |cffffff00/reload|r to take effect.")
        end
    end)
end

function ns:ShowSetup(startAt)
    ns:InitDB()
    if not frame then Build() end
    for _, refresh in ipairs(refreshers) do pcall(refresh) end
    Show(tonumber(startAt) or 1)
    frame:Show()
end
function ns:SetupStepCount() return #STEPS end
