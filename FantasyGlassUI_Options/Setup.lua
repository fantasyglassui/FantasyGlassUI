-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- First-run setup (12.0): four steps. Welcome (language, and how much to take over), how you play
-- (your role and what you enjoy, each switching on the features made for it), your look (theme,
-- accent and text size), and ready (what you chose, where your frames go). It opens on first login,
-- and again from the "Run setup again" button in /fgui or with /fgui setup. Each choice applies as
-- you click; choices that need the interface to reload are collected, and the last step reloads once.
-- Everything the setup no longer asks (lettering, opacity, small behaviors) is in the settings.
local frame
local step, pages, dots = 1, {}, {}
local refreshers = {}          -- re-mark every choice from the current settings when the wizard opens
local needReload = false       -- a feature switch or the theme family changed
local STEPS = { "Welcome", "How you play", "Your look", "Comfort", "Ready" }
local PAGE_W = 580

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

-- Step 1: welcome: language, and how much of the interface to take over ----------------------------------
-- Picking a language in the setup. Every label was written when its window was built, so the change
-- needs a reload; the setup then opens again by itself, in the language chosen. The language's button
-- does the reload (ns:ReloadButton); false here (the language already in use) and it does not.
function ns:SetupPickLanguage(code)
    if not ns:SetLanguage(code) then return false end
    ns.root.resumeSetup = true
    return true
end

local function BuildWelcome(page)
    Heading(page, "Welcome to Fantasy Glass UI", "Three quick questions, about a minute. Every choice applies as you click, and all of it can be changed later in /fgui.")

    Label(page, "Language", 0, -66)
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
        local b = ns:CreateButton(list, "", 190, 22)
        ns:ReloadButton(b, function() list:Hide(); return ns:SetupPickLanguage(code) end)
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

    Label(page, "How much should Fantasy Glass UI do?", 0, -122)
    local cards = {}
    local defs = {
        { "STANDARD",   "The whole interface", "Fantasy Glass UI's own frames, bars, bags, minimap, quest tracker and windows, with its helpers. Recommended." },
        { "RESTYLE",    "Just restyle the game's own", "The game's own unit frames, bags and quest tracker stay; the windows, tooltips, chat, minimap and action bars get the look." },
        { "EVERYTHING", "Everything", "Every feature on, those that pop up or act on their own included." },
    }
    local custom = Note(page, "", -340)
    function page.Mark()
        local current = ns.CurrentPreset and ns:CurrentPreset()
        for key, card in pairs(cards) do
            if key == current then ns:Paint(card, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(card, "SetBackdropBorderColor", "@border", 1) end
        end
        custom:SetText(current and "" or ns:Tr("Your switches are your own mix, so none of the three is marked. The next step adds to them."))
    end
    for i, def in ipairs(defs) do
        local card = ns:CreateButton(page, "", PAGE_W, 60, function()
            if ns.ApplyPreset and ns:ApplyPreset(def[1]) > 0 then needReload = true end
            for _, refresh in ipairs(refreshers) do pcall(refresh) end
        end)
        card:SetPoint("TOPLEFT", 0, -146 - (i - 1) * 66)
        card.text:ClearAllPoints()
        card.text:SetPoint("TOPLEFT", 14, -9)
        ns:Font(card.text, 15, true)
        card.text:SetText(ns:Tr(def[2]))
        card:HookScript("OnLeave", function() page.Mark() end)
        local desc = card:CreateFontString(nil, "OVERLAY")
        ns:Font(desc, 11)
        desc:SetPoint("TOPLEFT", 14, -29)
        desc:SetWidth(PAGE_W - 30)
        desc:SetJustifyH("LEFT")
        desc:SetText(ns:Tr(def[3]))
        ns:Paint(desc, "SetTextColor", "dim")
        cards[def[1]] = card
    end
    page.cards = cards
    page.Mark()
    refreshers[#refreshers + 1] = page.Mark
end

-- Step 2: how you play ------------------------------------------------------------------------------------
-- Your role (one), and what you enjoy (any). Each switches on the features made for it, and says which;
-- taking one back restores what those switches were before, unless another choice still wants them.
-- (Features that act on their own, auto quest above all, are never switched on here.)
ns.playStyles = {
    TANK     = { "roleHUD", "cooldowns", "threatMeter", "aggroWarn", "bossTimer", "ufBoss", "deathRecap" },
    HEALER   = { "roleHUD", "cooldowns", "raidFrames", "ufParty", "groupCDs", "buffCoverage", "deathRecap" },
    DAMAGE   = { "roleHUD", "cooldowns", "damageMeter", "executeLine", "cooldownPulse", "deathRecap" },
    QUESTING = { "questTracker", "questRewards", "questLog", "quests", "plateQuest", "xpBar", "mapCoords", "upgradeArrows", "upgradePrompt" },
    GROUPS   = { "lootBook", "lootBossTip", "bossGuide", "bossTimer", "runLog", "groupLoot", "gearCheck", "lootRoll", "rollAdvice", "readyAlert", "threatMeter" },
    PVP      = { "bgHelper", "enemyCDs", "ufArena", "queueAlert", "locAlert" },
    COLLECT  = { "storage", "itemCounts", "skillUps", "profCooldowns", "craftBar", "auctionMemory", "auctionHelper", "mailTools", "rareAlert", "rareMemory", "farming" },
    SOCIAL   = { "chatSkin", "chatExtras", "chatClassColors", "chatHighlight", "whisperWindow", "playerNotes", "recentMates", "guildNotices", "friendColors", "groupNotices" },
}
local INTERESTS = {
    { "QUESTING", "Questing and leveling", "Quest marks on mobs, rewards in the tracker, upgrades shown as you loot." },
    { "GROUPS",   "Dungeons and raids",    "Boss guides and timers, what drops, whose upgrade, your best run times." },
    { "PVP",      "PvP",                   "Battleground help, enemy cooldowns, arena frames, queue alerts." },
    { "COLLECT",  "Collecting and crafting", "What your characters own, profession help, auction prices, farming." },
    { "SOCIAL",   "Casual and social",     "A better chat, a whisper window, notes on players, guild notices." },
}
local function Usable(key)
    if ns.FeatureHidden and ns:FeatureHidden(key) then return false end
    for _, group in ipairs(ns.featureGroups or {}) do
        for _, opt in ipairs(group[2]) do if opt[1] == key then return true end end
    end
    return false
end
function ns:PlayStyleKeys(style)
    local out = {}
    for _, key in ipairs(ns.playStyles[style] or {}) do if Usable(key) then out[#out + 1] = key end end
    return out
end
-- Is this play style chosen? (the role is one of them: TANK, HEALER or DAMAGE)
function ns:PlayStyleOn(style)
    if ns.roles[style] then return ns.db.role == style end
    return type(ns.db.playStyles) == "table" and ns.db.playStyles[style] == true
end
local function WantedByOthers(key, except)
    for style in pairs(ns.playStyles) do
        if style ~= except and ns:PlayStyleOn(style) then
            for _, k in ipairs(ns.playStyles[style]) do if k == key then return true end end
        end
    end
    return false
end
function ns:SetPlayStyle(style, on)
    ns.db.playStyles = type(ns.db.playStyles) == "table" and ns.db.playStyles or {}
    ns.db.playStylePrev = type(ns.db.playStylePrev) == "table" and ns.db.playStylePrev or {}
    local prev = ns.db.playStylePrev
    local changed = 0
    if on then
        for _, key in ipairs(ns:PlayStyleKeys(style)) do
            if prev[key] == nil then prev[key] = ns.db[key] and true or false end     -- (as it was before any choice wanted it)
            if not ns.db[key] then ns.db[key] = true; changed = changed + 1 end
        end
        if not ns.roles[style] then ns.db.playStyles[style] = true end
    else
        if not ns.roles[style] then ns.db.playStyles[style] = nil end
        for _, key in ipairs(ns:PlayStyleKeys(style)) do
            if not WantedByOthers(key, style) and prev[key] ~= nil then
                if (ns.db[key] and true or false) ~= prev[key] then ns.db[key] = prev[key]; changed = changed + 1 end
                prev[key] = nil
            end
        end
    end
    if changed > 0 then needReload = true end
    return changed
end

local function BuildPlay(page)
    Heading(page, "How do you play?", "Each choice switches on the features made for it; hover one to see which. Taking a choice back puts them as they were.")
    ns.setupPlayPage = page
    local cards = {}
    local count = Note(page, "", -344)
    local function Mark()
        for style, card in pairs(cards) do
            if ns:PlayStyleOn(style) then ns:Paint(card, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(card, "SetBackdropBorderColor", "@border", 1) end
        end
        local n, seen = 0, {}
        for style in pairs(ns.playStyles) do
            if ns:PlayStyleOn(style) then
                for _, key in ipairs(ns:PlayStyleKeys(style)) do if not seen[key] then seen[key] = true; n = n + 1 end end
            end
        end
        count:SetText(n > 0 and format(ns:TrN(n, "Your choices use %d feature. Every switch is in /fgui, by category.", "Your choices use %d features. Every switch is in /fgui, by category."), n)
            or ns:Tr("Pick none at all if you like: the features you have stay as they are."))
    end
    page.Mark = Mark
    local function Tip(card, style, desc)
        card:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.text:GetText() or "")
            if desc then GameTooltip:AddLine(ns:Tr(desc), 1, 1, 1, true) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(ns:Tr("Switches on:"), 0.6, 0.6, 0.6)
            for _, key in ipairs(ns:PlayStyleKeys(style)) do GameTooltip:AddLine("  " .. FeatureName(key), 1, 1, 1) end
            GameTooltip:Show()
        end)
        card:HookScript("OnLeave", function() GameTooltip:Hide(); Mark() end)
    end

    Label(page, "Your role", 0, -58)
    local roleW = math.floor((PAGE_W - 3 * 6) / 4)
    local roleDefs = {}
    for _, key in ipairs(ns.roleOrder) do roleDefs[#roleDefs + 1] = key end
    roleDefs[#roleDefs + 1] = "NONE"
    for i, key in ipairs(roleDefs) do
        local role = ns.roles[key]
        local card = ns:CreateButton(page, "", roleW, 44, function()
            local old = ns.db.role
            if old == key then return end
            if ns.roles[old] then ns.db.role = nil; ns:SetPlayStyle(old, false) end
            ns:SetRole(key)
            if role then ns:SetPlayStyle(key, true) end
            Mark()
        end)
        card:SetPoint("TOPLEFT", (i - 1) * (roleW + 6), -80)
        card.text:ClearAllPoints()
        card.text:SetPoint("CENTER", 0, 0)
        ns:Font(card.text, 14, true)
        if role then
            card.text:SetText(ns:Tr(role.label))
            card.text:SetTextColor(role.color[1], role.color[2], role.color[3])
            card:HookScript("OnLeave", function(self) self.text:SetTextColor(role.color[1], role.color[2], role.color[3]) end)
            Tip(card, key, role.desc)
            cards[key] = card
        else
            card.text:SetText(ns:Tr("No role"))
            card:HookScript("OnLeave", function() if ns.db.role == "NONE" then ns:Paint(card, "SetBackdropBorderColor", "@accent", 1) end end)
            page.noRole = card
        end
    end

    Label(page, "What do you enjoy? (pick any)", 0, -140)
    local cardW = math.floor((PAGE_W - 6) / 2)
    for i, def in ipairs(INTERESTS) do
        local style = def[1]
        local card = ns:CreateButton(page, "", cardW, 58, function()
            ns:SetPlayStyle(style, not ns:PlayStyleOn(style))
            Mark()
        end)
        card:SetPoint("TOPLEFT", ((i - 1) % 2) * (cardW + 6), -162 - math.floor((i - 1) / 2) * 62)
        card.text:ClearAllPoints()
        card.text:SetPoint("TOPLEFT", 12, -8)
        ns:Font(card.text, 13, true)
        card.text:SetText(ns:Tr(def[2]))
        local desc = card:CreateFontString(nil, "OVERLAY")
        ns:Font(desc, 10)
        desc:SetPoint("TOPLEFT", 12, -26)
        desc:SetWidth(cardW - 24)
        desc:SetJustifyH("LEFT")
        desc:SetText(ns:Tr(def[3]))
        ns:Paint(desc, "SetTextColor", "dim")
        Tip(card, style, nil)
        cards[style] = card
    end
    page.cards = cards
    -- the quest guide: on or off here (quest guides are not released yet: only where they have been unlocked)
    if ns.GuideUnlocked and ns:GuideUnlocked() then
        page.guideToggle = Toggle(page, cardW + 6, -162 - 2 * 62 + 14, "questGuide", "Quest guides", "Follow a quest route one step at a time, with a panel for the step you are on and an arrow pointing to it. Nothing shows until you follow a guide.")
    end
    Mark()
    refreshers[#refreshers + 1] = Mark
end

-- Step 3: your look: a family, a theme of it, the accent, and how big the lettering is ----------------------
-- (Themes you made yourself get a fourth group, which only appears once you have some.)
local function BuildLook(page)
    Heading(page, "Your look", "Choose glass, fantasy or celestial, then a theme. The accent is the highlight color. Everything applies as you click; the lettering style and much more are under Look and themes in /fgui.")

    local COLS, BW = 5, 115
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
        return (t.style == "GLASS") and "GLASS" or (t.style == "CELESTIAL") and "CELESTIAL" or "FANTASY"
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
    note:SetPoint("TOPLEFT", 0, -362)
    note:SetWidth(PAGE_W)
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

    local families = { { "GLASS", "Glass" }, { "FANTASY", "Fantasy" }, { "CELESTIAL", "Celestial" }, { "MINE", "My themes" } }
    for i, def in ipairs(families) do
        local b = ns:CreateButton(page, def[2], 140, 26, function() family = def[1]; Refresh() end)
        b:SetPoint("TOPLEFT", (i - 1) * 146, -74)
        b:HookScript("OnLeave", function(self) Mark(self, self.picked) end)
        familyButtons[def[1]] = b
    end
    page.SetFamily = function(which) family = which; Refresh() end
    page.themeButtons = themeButtons

    -- the themes of the chosen family: four rows show at a time, and the grid scrolls for the rest
    local ROWS_SHOWN = 4
    local grid, sheet = ns:ScrollArea(page, PAGE_W - 12, ROWS_SHOWN * 30 - 4)
    grid:SetPoint("TOPLEFT", 0, -110)
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
            GameTooltip:AddLine(ns:ThemeName(self.key))
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        if ns.optUI and ns.optUI.ThemeSwatch then ns.optUI.ThemeSwatch(b) end      -- (a small picture of the theme)
        themeButtons[i] = b
        return b
    end

    local label = page:CreateFontString(nil, "OVERLAY")
    ns:Font(label, 12)
    label:SetPoint("TOPLEFT", 0, -247)
    label:SetText(ns:Tr("Accent"))
    ns:Paint(label, "SetTextColor", "dim")
    for i, key in ipairs(ns.accentOrder) do
        local sw = CreateFrame("Button", nil, page, ns.template)
        sw:SetSize(18, 18)
        sw:SetPoint("TOPLEFT", 80 + ((i - 1) % 20) * 24, -242 - math.floor((i - 1) / 20) * 22)   -- rows of twenty
        sw:SetBackdrop(ns.BACKDROP)
        local r, g, b = ns:AccentColor(key)
        sw:SetBackdropColor(r, g, b, 1)
        sw:SetScript("OnClick", function() ns.db.accent = key; ns:Retheme(); Refresh() end)
        sw:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:AccentName(key))
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        swatches[key] = sw
    end
    local rows = math.ceil(#ns.accentOrder / 20)
    local y = -242 - rows * 22 - 12
    Label(page, "Text size", 0, y - 4)
    Choices(page, y - 26, { { 90, "Small" }, { 100, "Normal" }, { 115, "Large" }, { 130, "Larger" } },
        function() return tonumber(ns.db.fontScale) or 100 end,
        function(v) ns.db.fontScale = v; ns:Retheme() end, 4, 136)

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
            b.text:SetText(ns:ThemeName(key, "short"))
            if b.swatch then ns.optUI.ShowThemeSwatch(b.swatch, key) end
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
        note:SetText(needReload and ns:Tr("Each family of themes is built differently, so this change finishes when the setup reloads the interface at the end.") or "")
    end
    refreshers[#refreshers + 1] = function() family = FamilyOf(ns.db.theme or "SMOKE"); Refresh() end
    family = FamilyOf(ns.db.theme or "SMOKE")
    Refresh()
end

-- Step 4 (12.1): comfort: whatever makes the game easier to see, hear or follow -------------------------------
local function BuildComfort(page)
    Heading(page, "Comfort", "Anything that makes the game easier to see, hear or follow. All of it can be changed later in /fgui, under Accessibility.")
    Label(page, "Color vision", 0, -64)
    Choices(page, -88, { { "off", "Usual colors" }, { "redgreen", "Red-green" }, { "blueyellow", "Blue-yellow" }, { "none", "No color" } },
        function() return ns:ColorVisionChoice() end, function(v) ns:SetColorVision(v) end, 4, 136)
    Label(page, "Lettering", 0, -132)
    Choices(page, -156, { { "off", "As chosen" }, { "READABLE", "Readable" }, { "DYSLEXIC", "Dyslexia-friendly" } },
        function() return ns:ReadableFont() end, function(v) ns:SetReadableFont(v) end, 3, 186)
    Label(page, "More", 0, -200)
    local items = {
        { "captions", "Captions for sounds", true }, { "reduceMotion", "Reduce motion" },
        { "safeFlash", "Safe flashing" }, { "calmMode", "Calm mode" },
        { "cursorRing", "Ring round the mouse pointer", true }, { "bigControls", "Bigger controls in the settings" },
    }
    for i, it in ipairs(items) do
        local desc = ns.settingRows and ns.settingRows[it[1]] and ns.settingRows[it[1]].desc
        Toggle(page, ((i - 1) % 2) * 290, -224 - math.floor((i - 1) / 2) * 30, it[1], it[2], desc, it[3])
    end
    local paste = ns:CreateButton(page, "Paste shared settings", 200, 24, function() if ns.ShowAccessPaste then ns:ShowAccessPaste() end end)
    paste:SetPoint("TOPLEFT", 0, -324)
    Note(page, "Someone gave you a line of accessibility settings? Paste it here and they are all set at once.", -356)
end

-- Step 4: ready: what you chose, where your frames go, and where everything else is -------------------------
local function BuildReady(page)
    Heading(page, "Ready", "Here is what you chose. Use Back to change anything, then put your frames where you want them.")
    ns.setupReadyPage = page
    local rows = {}
    for i = 1, 5 do
        local label = page:CreateFontString(nil, "OVERLAY")
        ns:Font(label, 12)
        label:SetPoint("TOPLEFT", 0, -52 - (i - 1) * 20)
        ns:Paint(label, "SetTextColor", "dim")
        local value = page:CreateFontString(nil, "OVERLAY")
        ns:Font(value, 12)
        value:SetPoint("TOPLEFT", 150, -52 - (i - 1) * 20)
        value:SetWidth(PAGE_W - 150)
        value:SetJustifyH("LEFT")
        if value.SetWordWrap then value:SetWordWrap(false) end
        rows[i] = { label = label, value = value }
    end

    local BW3 = math.floor((PAGE_W - 12) / 3)
    Label(page, "Place your frames", 0, -164)
    local apply = ns:CreateButton(page, "Use the layout for my role", BW3, 26, function() ns:ApplyRoleLayout() end)
    apply:SetPoint("TOPLEFT", 0, -184)
    local preview = ns:CreateButton(page, "Show sample frames", BW3, 26, function() ns:TogglePreview() end)
    preview:SetPoint("TOPLEFT", BW3 + 6, -184)
    local move = ns:CreateButton(page, "Move panels", BW3, 26, function() ns:ToggleMove() end)
    move:SetPoint("TOPLEFT", 2 * (BW3 + 6), -184)

    -- coming from another interface: the closest whole-screen setup, one click (Gallery.lua)
    Label(page, "Coming from another UI?", 0, -222)
    local found = ns.OtherUIsFound and ns.OtherUIsFound() or {}
    local foundKey = found[1] and found[1].ui.key
    page.otherUI = {}
    for i, ui in ipairs(ns.OTHER_UIS or {}) do
        local b = ns:CreateButton(page, ui.label, BW3, 24, function()
            if ns.ApplyGallery then ns:ApplyGallery(ui.gallery) end
        end)
        b:SetPoint("TOPLEFT", ((i - 1) % 3) * (BW3 + 6), -242 - math.floor((i - 1) / 3) * 28)
        if ui.key == foundKey then ns:Paint(b, "SetBackdropBorderColor", "@accent", 1) end
        page.otherUI[ui.key] = b
    end
    local otherRows = math.ceil(#(ns.OTHER_UIS or {}) / 3)
    local y = -242 - otherRows * 28 - 4
    Note(page, found[1] and format(ns:Tr("You have %s: the marked one is the closest. Fantasy Glass UI leaves the jobs that add-on does to it."), found[1].addon)
        or "Each puts your frames where that interface does. One undo (/fgui undo) takes it back.", y)
    local more = ns:CreateButton(page, "Fine-tune in all settings", BW3, 24, function()
        if type(ns.root) == "table" then ns.root.settingsMode = "all" end
        frame:Hide()
        ns:ToggleConfig()
        if ns.optUI and ns.optUI.SetSimple then ns.optUI.SetSimple(false) end
    end)
    more:SetPoint("TOPLEFT", 0, y - 34)
    local tips = page:CreateFontString(nil, "OVERLAY")
    ns:Font(tips, 11)
    tips:SetPoint("LEFT", more, "RIGHT", 12, 0)
    tips:SetWidth(PAGE_W - BW3 - 12)
    tips:SetJustifyH("LEFT")
    ns:Paint(tips, "SetTextColor", "faint")
    tips:SetText("|cffffff00/fgui|r " .. ns:Tr("all the options") .. "   |cffffff00/fgui move|r " .. ns:Tr("arrange panels") .. "   |cffffff00/fgui check|r " .. ns:Tr("if something looks wrong"))

    local PRESETS = { STANDARD = "The whole interface", EVERYTHING = "Everything", MINIMAL = "Minimal", RESTYLE = "Just restyle the game's own" }
    function page.Refresh()
        local role = ns.roles[ns.db.role]
        local liked = {}
        for _, def in ipairs(INTERESTS) do if ns:PlayStyleOn(def[1]) then liked[#liked + 1] = ns:Tr(def[2]) end end
        local on, total = 0, 0
        if ns.CountFeatures then on, total = ns:CountFeatures() end
        local preset = ns.CurrentPreset and ns:CurrentPreset()
        local data = {
            { "How much", ns:Tr(PRESETS[preset] or "your own mix") },
            { "Role", role and ns:Tr(role.label) or ns:Tr("not chosen") },
            { "You enjoy", #liked > 0 and table.concat(liked, ", ") or ns:Tr("not chosen") },
            { "Theme", ns:ThemeName(ns.themes[ns.db.theme or "SMOKE"] and (ns.db.theme or "SMOKE") or "SMOKE", "plain") .. "  (" .. (tonumber(ns.db.fontScale) or 100) .. "%)" },
            { "Features", format(ns:Tr("%d of %d switched on"), on, total) },
        }
        for i, row in ipairs(rows) do
            row.label:SetText(data[i] and ns:Tr(data[i][1]) or "")
            row.value:SetText(data[i] and data[i][2] or "")
        end
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
    if step < #STEPS then frame.next:Show(); frame.finish:Hide() else frame.next:Hide(); frame.finish:Show() end
    frame.count:SetText(step .. " / " .. #STEPS .. "   " .. ns:Tr(STEPS[step]))
end

local function Build()
    frame = CreateFrame("Frame", "FantasyGlassUISetup", UIParent, ns.template)
    ns.setupFrame = frame
    frame:SetSize(PAGE_W + 60, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop(ns.BACKDROP)
    ns:Paint(frame, "SetBackdropColor", "window", 0.97)
    ns:Paint(frame, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(frame)
    frame:EnableMouse(true)
    frame:SetMovable(true); if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
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
    title:SetText(ns:Tr("Fantasy Glass UI setup") .. "  |cff808080" .. ns:Tr("by") .. " " .. ns.author .. "|r")
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

    local builders = { BuildWelcome, BuildPlay, BuildLook, BuildComfort, BuildReady }
    for i, build in ipairs(builders) do
        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", 30, -48)
        page:SetPoint("BOTTOMRIGHT", -30, 56)
        page:Hide()
        build(page)
        pages[i] = page
        local dot = frame:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(ns.FLAT)
        dot:SetSize(28, 3)
        dot:SetPoint("BOTTOM", frame, "BOTTOM", (i - (#builders + 1) / 2) * 34, 26)
        dots[i] = dot
    end

    frame.back = ns:CreateButton(frame, "Back", 90, 26, function() if step > 1 then Show(step - 1) end end)
    frame.back:SetPoint("BOTTOMLEFT", 30, 16)
    frame.next = ns:CreateButton(frame, "Next", 160, 26, function() if step < #STEPS then Show(step + 1) end end)
    frame.next:SetPoint("BOTTOMRIGHT", -30, 16)
    -- Finishing always reloads, so everything chosen is in place at once. The tour (and the note on
    -- where everything is) comes after the reload. Its own button, in Next's place on the last step:
    -- the choices are kept in PreClick and the game's own ReloadUI is the click (ns:ReloadButton).
    frame.finish = ns:CreateButton(frame, "Finish & reload", 160, 26)
    frame.finish:SetPoint("BOTTOMRIGHT", -30, 16)
    frame.finish:Hide()
    ns:ReloadButton(frame.finish, function()
        if not ns.db.role then ns:SetRole("NONE") end
        ns.db.setupDone = true
        needReload = false
        ns.root.setupJustFinished = true
        frame:Hide()
    end)
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
function ns:HideSetup() if frame then frame:Hide() end end
function ns:SetupStepCount() return #STEPS end
