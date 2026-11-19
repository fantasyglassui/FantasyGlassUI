local _, ns = ...

local BARS = {
    { "MainActionBar",       "ActionButton",              12 },
    { "MultiBarBottomLeft",  "MultiBarBottomLeftButton",  12 },
    { "MultiBarBottomRight", "MultiBarBottomRightButton", 12 },
    { "MultiBarRight",       "MultiBarRightButton",       12 },
    { "MultiBarLeft",        "MultiBarLeftButton",        12 },
    { "MultiBar5",           "MultiBar5Button",           12 },
    { "MultiBar6",           "MultiBar6Button",           12 },
    { "MultiBar7",           "MultiBar7Button",           12 },
    { "StanceBar",           "StanceButton",              10 },
    { "PetActionBar",        "PetActionButton",           10 },
}

local function Abbrev(btn)
    local hk = btn.HotKey or _G[(btn:GetName() or "") .. "HotKey"]
    if not hk or not hk.GetText then return end
    local t = hk:GetText()
    if not t or t == "" or t == RANGE_INDICATOR then return end
    t = t:gsub("Mouse Button ", "M"):gsub("Middle Mouse", "M3")
         :gsub("Mouse Wheel Up", "WU"):gsub("Mouse Wheel Down", "WD")
         :gsub("Num Pad ", "N"):gsub("Shift%-", "S"):gsub("Ctrl%-", "C"):gsub("Alt%-", "A")
         :gsub("s%-", "S"):gsub("c%-", "C"):gsub("a%-", "A")
    hk:SetText(t)
end

-- The two pieces of text on an action button: the key it is bound to, and (for a macro) its name.
-- Each is a switch on the Features tab. They are shown and hidden by transparency, which stays
-- as set even when the game rewrites the text.
local skinned = {}
-- A bar's own setting, or what applies to every bar when it has none.
ns.barShowModes = { "always", "hover", "combat", "nocombat", "target", "never" }
ns.barShowNames = { always = "Always", hover = "When pointed at", combat = "In combat", nocombat = "Out of combat", target = "With a target", never = "Never" }
function ns:BarSetting(key, name)
    local mine = type(ns.db.bars) == "table" and ns.db.bars[key]
    local own
    if type(mine) == "table" then own = mine[name] end
    if own ~= nil then return own end
    if name == "scale" or name == "alpha" then return 100 end
    if name == "show" then return (ns.db.barFade and ns.db.barFade[key]) and "hover" or "always" end
    if name == "hotkeys" then return ns.db.barHotkeys ~= false end
    if name == "names" then return ns.db.barMacroNames and true or false end
    return nil
end
function ns:SetBarSetting(key, name, value)
    if type(ns.db.bars) ~= "table" then ns.db.bars = {} end
    if type(ns.db.bars[key]) ~= "table" then ns.db.bars[key] = {} end
    ns.db.bars[key][name] = value
    if name == "show" then                                   -- (the older per-bar "fade" switch is the same thing)
        ns.db.barFade = ns.db.barFade or {}
        ns.db.barFade[key] = (value == "hover") and true or nil
    end
    if name == "scale" and ns.ApplyBarScale then ns:ApplyBarScale(true) end
    if (name == "hotkeys" or name == "names") and ns.ApplyBarText then ns:ApplyBarText() end
    return value
end
local function ApplyButtonText(btn)
    local key = btn.suiBarKey
    local hk = btn.HotKey
    if type(hk) == "table" and hk.SetAlpha then hk:SetAlpha(((key and ns:BarSetting(key, "hotkeys")) or (not key and ns.db.barHotkeys ~= false)) and 1 or 0) end
    local name = btn.Name
    if type(name) == "table" and name.SetAlpha then name:SetAlpha(((key and ns:BarSetting(key, "names")) or (not key and ns.db.barMacroNames)) and 1 or 0) end
end
function ns:ApplyBarText()
    for _, btn in ipairs(skinned) do pcall(ApplyButtonText, btn) end
    return #skinned
end

local function HideButtonArt(btn)
    ns:Kill(btn.NormalTexture or (btn.GetNormalTexture and btn:GetNormalTexture()))
    for _, k in ipairs({ "SlotBackground", "SlotArt", "FlyoutBorder", "FlyoutBorderShadow", "BorderShadow" }) do
        ns:Kill(btn[k])
    end
end

local function SkinButton(btn)
    if not btn or btn.suiSkinned then return end
    btn.suiSkinned = true
    local name = btn:GetName() or ""

    local icon = btn.icon or btn.Icon or _G[name .. "Icon"]
    if icon then
        if btn.IconMask and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, btn.IconMask) end
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    HideButtonArt(btn)   -- kept invisible by the keeper in Skin.lua; no hooks on the button

    -- The dark backing behind the icon. It must sit at the very bottom of the background layer: the
    -- game draws the icon in that same layer, and two things at the same depth are drawn in no fixed
    -- order. Left at the default depth, this backing could end up on top of the icon, and the whole
    -- bar looked grayed out, as if every ability were on cooldown.
    local bg = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetTexture(ns.FLAT)
    ns:Paint(bg, "SetVertexColor", "bg2", 0.85)
    ns:AddBorder(btn, 0, 0, 0, 1)
    ns:CelestialButtonEdge(btn)                              -- (Celestial themes: a fine frame with star points)

    if btn.GetHighlightTexture then ns:ColorTex(btn:GetHighlightTexture(), 1, 1, 1, 0.25) end
    if btn.GetPushedTexture then ns:ColorTex(btn:GetPushedTexture(), 1, 0.85, 0.2, 0.35) end
    if btn.GetCheckedTexture then ns:ColorTex(btn:GetCheckedTexture(), 1, 0.82, 0.4, 0.40) end

    if btn.Name and btn.Name.SetFont then ns:Font(btn.Name, 10) end          -- macro names (shown or not: see ApplyButtonText)
    if btn.Count and btn.Count.SetFont then ns:Font(btn.Count, 12) end
    local hk = btn.HotKey
    if hk and hk.SetFont then
        ns:Font(hk, 11)
        hk:ClearAllPoints()
        hk:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -3)
        hk:SetJustifyH("RIGHT")
    end
    skinned[#skinned + 1] = btn
    ApplyButtonText(btn)
    -- Starcut: the button cut like a gem, its cooldown sweep to match (Classic: the square box)
    local cd = btn.cooldown or btn.Cooldown or _G[name .. "Cooldown"]
    ns:StarcutFacet(btn, { icon = icon, also = { bg }, cooldown = (type(cd) == "table") and cd or nil })
end

ns.SkinActionButton, ns.AbbrevHotkey = SkinButton, Abbrev      -- (the add-on's own bars use these too: BarEngine.lua)

-- Dim a frame until the mouse is over it (polled; no hooks on Blizzard frames)
local function MakeFade(frame, idle)
    if not frame or not frame.IsMouseOver then return end
    frame:SetAlpha(idle)
    local driver, acc, lit = CreateFrame("Frame"), 0, false
    driver:SetScript("OnUpdate", ns:Guard("Fade", function(_, e)
        acc = acc + e
        if acc < 0.1 then return end
        acc = 0
        local over = frame:IsMouseOver() and true or false
        if over ~= lit then
            lit = over
            frame:SetAlpha(over and 1 or idle)
        end
    end))
end

ns:NewModule("actionBars", function()
    local panels = {}
    for _, def in ipairs(BARS) do
        local bar = _G[def[1]]
        if not bar and def[1] == "MainActionBar" then bar = _G.MainMenuBar end
        local prefix, n = def[2], def[3]

        -- with the add-on's own bars on, the game's eight bars and its stance bar are only put out of
        -- sight (BarEngine.lua): nothing of theirs is restyled either
        local leave = ns.db.barEngine and (n == 12 or def[1] == "StanceBar")
        for i = 1, leave and 0 or n do
            local btn = _G[prefix .. i]
            if btn then btn.suiBarKey = "bar_" .. def[1]; SkinButton(btn); Abbrev(btn) end
        end
        if leave then bar = nil end

        if bar then
            -- remove Blizzard's ornate art (gryphons, bar frame, background)
            for _, k in ipairs({ "BorderArt", "Background", "EndCaps" }) do ns:Kill(bar[k]) end

            -- slim dark panel behind the buttons
            local first, last = _G[prefix .. 1], _G[prefix .. n]
            if first and last and def[1] ~= "StanceBar" and def[1] ~= "PetActionBar" then
                local panel = CreateFrame("Frame", nil, bar, ns.template)
                panel:SetFrameLevel(math.max(0, bar:GetFrameLevel() - 1))
                panel:SetPoint("TOPLEFT", first, "TOPLEFT", -9, 9)       -- room for the inner gold hairline
                panel:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 9, -9)
                panel:EnableMouse(false)
                panel:SetBackdrop(ns.BACKDROP)
                ns:Paint(panel, "SetBackdropColor", "bg", 0.75)
                ns:Paint(panel, "SetBackdropBorderColor", "border", 1)
                ns:Dress(panel)
                panels[#panels + 1] = panel
            end
        end
    end

    -- The extra action button (some quests and encounters give you one) and the zone ability button.
    -- Each sits in an ornate frame the game picks per encounter; that frame is kept out of sight and
    -- the button itself gets the same look as the action bars. These only appear in particular
    -- places, so this is done whenever they turn up, a few times a second.
    local function ExtraButtons()
        local styled = 0
        for _, name in ipairs({ "ExtraActionButton1" }) do
            local b = _G[name]
            if type(b) == "table" and ns:Usable(b) then
                if type(b.style) == "table" and b.style.SetAlpha and not b.style.suiKilled then ns:Kill(b.style) end
                if not b.suiSkinned then pcall(SkinButton, b) end       -- (it marks the button itself)
                styled = styled + 1
            end
        end
        local zone = _G.ZoneAbilityFrame
        if type(zone) == "table" and ns:Usable(zone) and type(zone.Style) == "table" and zone.Style.SetAlpha and not zone.Style.suiKilled then
            ns:Kill(zone.Style)
            styled = styled + 1
        end
        return styled
    end
    ns.StyleExtraButtons = ExtraButtons
    ns:Every(1, "Extra action button", ExtraButtons)
    ns:Every(1, "Action button text", function() ns:ApplyBarText() end)      -- the switches take effect without a reload

    -- The panels are an option ("Frame behind action bars", Look tab) and start hidden: buttons on their
    -- own look cleaner, and a panel on a bar whose buttons are not laid out in a row shows as a stray line.
    function ns:ApplyBarPanels()
        for _, panel in ipairs(panels) do
            if ns.db.barPanel then panel:Show() else panel:Hide() end
        end
        return #panels
    end
    ns:ApplyBarPanels()

    -- Keep keybind text short: re-apply after the events that make Blizzard rewrite it
    local function AbbrevAll()
        for _, def in ipairs(BARS) do
            for i = 1, def[3] do
                local btn = _G[def[2] .. i]
                if btn then Abbrev(btn) end
            end
        end
    end
    local kev = CreateFrame("Frame")
    for _, e in ipairs({ "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR" }) do
        pcall(kev.RegisterEvent, kev, e)
    end
    kev:SetScript("OnEvent", ns:Guard("Hotkeys", function() ns:After(0.2, AbbrevAll) end))
    if ActionButton_UpdateHotkeys then
        hooksecurefunc("ActionButton_UpdateHotkeys", ns:Guard("Hotkeys", function(self)
            if self and self.GetName then Abbrev(self) end
        end))
    end

    -- XP / reputation bar ornaments
    local stm = _G.StatusTrackingBarManager
    if stm then
        for _, k in ipairs({ "BottomBarFrameTexture", "TopBarFrameTexture", "SingleBarSmall", "SingleBarLarge",
                             "SingleBarSmallUpper", "SingleBarLargeUpper" }) do
            ns:Kill(stm[k])
        end
    end
end)

-- Countdown numbers on cooldowns (drawn by the client, so hidden combat values are no problem)
ns:NewModule("cooldownText", function()
    pcall(SetCVar, "countdownForCooldowns", "1")
end)

-- Blizzard's micro menu and bag bar. On this client they sit in the same row as the main action
-- bar, so anything less than fully hidden shows through behind our buttons.
--   HIDE  (default): gone, replaced by a small "Menu" button that lists the same windows
--   HOVER: invisible until the mouse is over them      DIM: faint until hovered      SHOW: untouched
ns:NewModule("microMenu", function()
    local mode = ns.db.microMode or "HIDE"
    local micro, bagsBar = _G.MicroMenu, _G.BagsBar

    if mode == "SHOW" then return end
    if mode == "HOVER" or mode == "DIM" then
        MakeFade(micro, mode == "DIM" and 0.35 or 0)
        MakeFade(bagsBar, mode == "DIM" and 0.35 or 0)
        return
    end

    ns:Silence(micro)
    ns:Silence(bagsBar)

    -- Our replacement: one button, one short list.
    -- Each row is a secure button that clicks the real micro button for you. That runs the game's
    -- own, untainted code, so windows like Talents open exactly as they would from the original.
    local th = ns.theme
    local list = CreateFrame("Frame", "FantasyGlassUIMenu", UIParent, ns.template)
    list:SetFrameStrata("DIALOG")
    list:SetBackdrop(ns.BACKDROP)
    ns:Paint(list, "SetBackdropColor", "window", 0.97)
    ns:Paint(list, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(list, true)
    list:Hide()
    tinsert(UISpecialFrames, "FantasyGlassUIMenu")        -- Escape closes it

    -- The game's own name for each micro button (already in the player's language)
    local function Label(child)
        local text = child.tooltipText
        if type(text) == "string" and text ~= "" then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s*%(.-%)%s*$", "")
            if text ~= "" then return text end
        end
        local name = child.GetName and child:GetName()
        if type(name) == "string" then
            name = name:gsub("MicroButton$", ""):gsub("(%l)(%u)", "%1 %2")
            if name ~= "" then return name end
        end
        return nil
    end

    local rows = {}
    local function Row(target, run)
        local i = #rows + 1
        local ok, r = pcall(CreateFrame, "Button", "FantasyGlassUIMenuRow" .. i, list, "SecureActionButtonTemplate")
        if not ok or not r then r = CreateFrame("Button", nil, list) end
        r:SetSize(170, 20)
        r:SetPoint("TOPLEFT", 6, -8 - (i - 1) * 20)
        r:RegisterForClicks("AnyUp", "AnyDown")
        if target then
            r:SetAttribute("type", "click")
            r:SetAttribute("clickbutton", target)
        end
        r.target, r.run = target, run
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetTexture(ns.FLAT)
        r.bg:SetVertexColor(1, 1, 1, 0)
        r.text = ns:NewText(r, 12, "LEFT")
        r.text:SetPoint("LEFT", 8, 0)
        r:SetScript("OnEnter", function(self) ns:Paint(self.bg, "SetVertexColor", "@accent", 0.3) end)
        r:SetScript("OnLeave", function(self) self.bg:SetVertexColor(1, 1, 1, 0) end)
        r:SetScript("PostClick", function(self, _, down)
            if down then return end
            if self.run then pcall(self.run) end
            if not InCombatLockdown() then list:Hide() end
        end)
        rows[i] = r
        return r
    end

    -- The game menu button is the odd one out: it reacts to a real mouse release with the pointer
    -- over it, not to a click, so "clicking it for you" does nothing. That row opens the menu itself.
    local function GameMenu()
        local gm = _G.GameMenuFrame
        if type(gm) ~= "table" or not gm.IsShown then
            if ToggleGameMenu then ToggleGameMenu() end
            return
        end
        if gm:IsShown() then
            if HideUIPanel then HideUIPanel(gm) else gm:Hide() end
        else
            if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPEN) end
            if ShowUIPanel then ShowUIPanel(gm) else gm:Show() end
        end
    end
    local function IsGameMenuButton(child)
        if child == _G.MainMenuMicroButton then return true end
        local name = child.GetName and child:GetName()
        return type(name) == "string" and name:find("MainMenu", 1, true) ~= nil
    end

    local hasGameMenu = false
    if type(micro) == "table" and micro.GetChildren then
        for _, child in ipairs({ micro:GetChildren() }) do
            if type(child) == "table" and child.Click and Label(child) then
                if IsGameMenuButton(child) then
                    Row(nil, GameMenu).label = Label(child)
                    hasGameMenu = true
                else
                    Row(child)
                end
            end
        end
    end
    if not hasGameMenu then Row(nil, GameMenu).label = "Game menu" end        -- always offer it
    Row(nil, function() ns:ToggleKeybindMode() end).label = "Keybind mode"
    Row(nil, function() if ToggleAllBags then ToggleAllBags() end end).label = "Bags"
    Row(nil, function() if ns.ToggleToolsMenu then ns:ToggleToolsMenu() end end).label = "Tools"
    local optionsRow = Row(nil, function() ns:ToggleConfig() end)
    optionsRow.label, optionsRow.accent = "Fantasy Glass UI options", true
    list:SetSize(182, #rows * 20 + 16)

    local function Relabel()                                  -- names can change (level-ups unlock buttons)
        for _, r in ipairs(rows) do
            local text = (r.label and ns:Tr(r.label)) or (r.target and Label(r.target)) or "?"
            r.text:SetText(r.accent and (ns:AccentHex() .. text .. "|r") or text)      -- (the accent as it is now)
        end
    end
    Relabel()

    local btn = ns:CreateButton(UIParent, "Menu", 60, 20, function()
        if InCombatLockdown() then
            ns:Print("The menu can't open in combat. Use your keybinds until the fight ends.")
            return
        end
        if list:IsShown() then
            list:Hide()
        else
            Relabel()
            list:ClearAllPoints()
            list:SetPoint("BOTTOMRIGHT", ns.menuButton, "TOPRIGHT", 0, 4)
            list:Show()
        end
    end)
    ns.menuButton, ns.menuList = btn, list
    ns:Font(btn.text, 11)
    btn:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -8, 8)
    ns:ButtonTip(btn, "The game menu: character, spellbook, talents, quests, the shop and the rest. Tools opens the add-on's own tool windows.")
    -- The rows are secure buttons, so the game locks whatever the list is anchored to for the length of a
    -- fight: here, the Menu button. The list is therefore fixed to the button only while it is open, and
    -- lets go as a fight starts (this event arrives just before the game's combat rules begin).
    local closer = CreateFrame("Frame")
    closer:RegisterEvent("PLAYER_REGEN_DISABLED")
    closer:SetScript("OnEvent", ns:Guard("ActionBars events", function() list:Hide(); list:ClearAllPoints() end))

    ns:RegisterMovable(btn, "menu", "Menu button")

    -- Action bar size. At 100 the bars are left exactly as the game (and its Edit Mode) sized them.
    -- Any other value scales every bar; the game re-applies its own size now and then, so ours is put
    -- back after those moments.
    local scaled = false
    -- (Each bar also has a size of its own, on the Bars tab: the two multiply.)
    function ns:ApplyBarScale(force)
        local v = math.max(70, math.min(140, tonumber(ns.db.barScale) or 100))
        local own = false
        for _, def in ipairs(BARS) do if ns:BarSetting("bar_" .. def[1], "scale") ~= 100 then own = true end end
        if v == 100 and not own and not scaled and not force then return end
        if InCombatLockdown() then ns.barScalePending = true; return end
        ns.barScalePending = nil
        scaled = true
        for _, def in ipairs(BARS) do
            local bar = _G[def[1]]
            if not bar and def[1] == "MainActionBar" then bar = _G.MainMenuBar end
            local mine = math.max(50, math.min(150, tonumber(ns:BarSetting("bar_" .. def[1], "scale")) or 100))
            if type(bar) == "table" and bar.SetScale then pcall(ns.RawFrameCall and ns.RawFrameCall(bar, "SetScale") or bar.SetScale, bar, v / 100 * mine / 100) end
        end
    end
    local sizer = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "EDIT_MODE_LAYOUTS_UPDATED", "UI_SCALE_CHANGED" }) do
        pcall(sizer.RegisterEvent, sizer, e)
    end
    sizer:SetScript("OnEvent", ns:Guard("ActionBars events", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not ns.barScalePending then return end
        ns:After(0.5, function() pcall(ns.ApplyBarScale, ns) end)
    end))
    ns:ApplyBarScale()

    -- Movable bars: each bar is adopted (see ns:AdoptGameFrame in Skin.lua) and gets a handle in move mode.
    local LABELS = {
        -- (the same names as the add-on's own bars: BarEngine.lua)
        MainActionBar = "Bar 1", MultiBarBottomLeft = "Bar 2", MultiBarBottomRight = "Bar 3",
        MultiBarRight = "Bar 4", MultiBarLeft = "Bar 5", MultiBar5 = "Bar 6",
        MultiBar6 = "Bar 7", MultiBar7 = "Bar 8", StanceBar = "Stance bar", PetActionBar = "Pet bar",
    }
    local infos = {}
    for _, def in ipairs(BARS) do
        local bar = _G[def[1]]
        if not bar and def[1] == "MainActionBar" then bar = _G.MainMenuBar end
        local key = "bar_" .. def[1]
        -- with the add-on's own bars on, the game's eight bars are put out of sight (BarEngine.lua):
        -- they are not moved or held in place at all, so nothing of theirs is touched
        if ns.db.barEngine and (def[3] == 12 or def[1] == "StanceBar") then bar = nil end
        local info, entry = ns:AdoptGameFrame(bar, key, LABELS[def[1]] or def[1], "Bar size is set for all bars together, on the Layout tab.")
        if info then
            info.label = LABELS[def[1]] or def[1]
            info.layout = (def[3] == 12)                     -- (the eight action bars have rows and spacing; stance and pet do not)
            entry.fadeKey = key                              -- its menu gets a "fade" switch
            infos[#infos + 1] = info
        end
    end
    ns.barHandles = infos

    -- Fading: a bar set to fade is invisible while you are out of combat and not pointing at it, and
    -- returns the moment you enter combat, hover it, pick something up on the cursor, or open move or
    -- keybind mode. Chosen per bar, from its right-click menu in move mode. (Changing how see-through
    -- a bar is, unlike moving it, is allowed during combat.)
    -- (A bar has one of six "show" settings on the Bars tab; "When pointed at" is the fade described here.)
    local function WantVisible(info)
        local mode = ns:BarSetting(info.key, "show")
        if mode == "always" then return true end
        if ns.moving or ns.keybinding or ns.previewing then return true end
        if GetCursorInfo and GetCursorInfo() then return true end              -- dragging a spell or item to the bar
        if mode == "never" then return false end
        if mode == "combat" then return InCombatLockdown() and true or false end
        if mode == "nocombat" then return not InCombatLockdown() end
        if mode == "target" then return ns.Yes(UnitExists("target")) end
        if InCombatLockdown() then return true end
        local ok, over = pcall(info.holder.IsMouseOver, info.holder)
        if ok and over then return true end
        ok, over = pcall(info.bar.IsMouseOver, info.bar)
        return (ok and over) and true or false
    end
    ns.barWantVisible = WantVisible
    function ns:BarFadeTick(step)
        for _, info in ipairs(infos) do
            local target = WantVisible(info) and (math.max(0, math.min(100, tonumber(ns:BarSetting(info.key, "alpha")) or 100)) / 100) or 0
            local now = info.alpha or 1
            if now ~= target then
                if ns:Motion() then
                    now = (target > now) and math.min(target, now + step * 2) or math.max(target, now - step)   -- in quickly, out gently
                else
                    now = target
                end
                info.alpha = now
                pcall(info.bar.SetAlpha, info.bar, now)
            end
        end
    end
    ns:Every(0.05, "Action bar fading", function() ns:BarFadeTick(0.12) end)
    function ns:SetBarFade(key, on)
        ns.db.barFade = ns.db.barFade or {}
        ns.db.barFade[key] = on and true or nil
        if type(ns.db.bars) == "table" and type(ns.db.bars[key]) == "table" then ns.db.bars[key].show = on and "hover" or "always" end
    end

end)

------------------------------------------------------------------------------------------
-- A bar's rows, number of buttons, button size, spacing and direction belong to the game's Edit
-- Mode, which lays the bars out itself (in and out of combat). So these are changed by changing the
-- Edit Mode layout you are using, the same way its own window does - not by moving buttons about,
-- which the game would undo. Only a layout of your own can be changed; the game's two presets
-- ("Modern" and "Classic") are fixed.
------------------------------------------------------------------------------------------
local function EditEnums()
    local S = Enum and Enum.EditModeActionBarSetting
    if type(S) ~= "table" or not (Enum.EditModeSystem and Enum.EditModeSystem.ActionBar ~= nil) then return nil end
    return { rows = S.NumRows, icons = S.NumIcons, size = S.IconSize, padding = S.IconPadding, vertical = S.Orientation }
end
ns.barLayoutLimits = { rows = { 1, 4 }, icons = { 6, 12 }, size = { 50, 200 }, padding = { 2, 10 }, vertical = { 0, 1 } }
-- Button size is kept by the game as steps of ten from 50% (0 = 50%, 5 = 100%, 15 = 200%).
function ns.BarSizeToRaw(percent) return math.floor((math.max(50, math.min(200, tonumber(percent) or 100)) - 50) / 10 + 0.5) end
function ns.BarSizeFromRaw(raw) raw = tonumber(raw) or 5; if raw > 20 then return raw end return raw * 10 + 50 end
-- The entry for one bar in a layout: the system with this kind and number.
function ns.EditModeFind(layout, system, index)
    for _, entry in ipairs(type(layout) == "table" and type(layout.systems) == "table" and layout.systems or {}) do
        if entry.system == system and entry.systemIndex == index then return entry end
    end
end
function ns.EditModeGet(entry, setting)
    for _, s in ipairs(type(entry) == "table" and type(entry.settings) == "table" and entry.settings or {}) do
        if s.setting == setting then return s.value end
    end
end
-- Change one value that is already there (never adds one: a layout is only ever edited, not built).
function ns.EditModeSet(entry, setting, value)
    for _, s in ipairs(type(entry) == "table" and type(entry.settings) == "table" and entry.settings or {}) do
        if s.setting == setting then
            local changed = s.value ~= value
            s.value = value
            return true, changed
        end
    end
    return false
end
-- The layout in use, if it is one of your own. Returns: everything the game holds, the layout; or nil and why.
function ns:EditModeActive()
    local E = C_EditMode
    if not (type(E) == "table" and type(E.GetLayouts) == "function" and type(E.SaveLayouts) == "function") then return nil, "This game client has no Edit Mode an add-on can use." end
    local ok, info = pcall(E.GetLayouts)
    if not (ok and type(info) == "table" and type(info.layouts) == "table" and type(info.activeLayout) == "number") then return nil, "The game did not hand over its Edit Mode layouts." end
    local presets = 0
    local M = _G.EditModePresetLayoutManager
    if type(M) == "table" and type(M.GetCopyOfPresetLayouts) == "function" then
        local okP, list = pcall(M.GetCopyOfPresetLayouts, M)
        if okP and type(list) == "table" then presets = #list end
    end
    local layout = info.layouts[info.activeLayout - presets]
    if type(layout) ~= "table" then return nil, "preset" end
    return info, layout
end
ns.PRESET_NOTE = "You are using one of the game's own Edit Mode layouts, which cannot be changed. Make one of your own first: Esc, Edit Mode, the Layout menu, New Layout. Then come back here."
function ns:BarLayoutRead(bar)
    if type(bar) == "table" and bar.suiEngine and ns.EngineLayoutRead then return ns:EngineLayoutRead(bar) end      -- one of our own bars
    local enums = EditEnums()
    if not enums then return nil, "This game client has no Edit Mode an add-on can use." end
    if type(bar) ~= "table" or type(bar.systemIndex) ~= "number" then return nil, "This bar is not one the Edit Mode lays out." end
    local info, layout = ns:EditModeActive()
    if not info then return nil, layout end
    local entry = ns.EditModeFind(layout, Enum.EditModeSystem.ActionBar, bar.systemIndex)
    if not entry then return nil, "This bar is not in your Edit Mode layout." end
    local out = {}
    for name, setting in pairs(enums) do out[name] = ns.EditModeGet(entry, setting) end
    out.size = ns.BarSizeFromRaw(out.size)
    out.sizeIsPercent = (tonumber(ns.EditModeGet(entry, enums.size)) or 0) > 20
    return out
end
-- values: { rows, icons, size (percent), padding, vertical (0 across, 1 down) }. Returns true, or nil and why.
function ns:BarLayoutWrite(bar, values)
    if type(bar) == "table" and bar.suiEngine and ns.EngineLayoutWrite then return ns:EngineLayoutWrite(bar, values) end
    if InCombatLockdown() then return nil, "Not during a fight." end
    local enums = EditEnums()
    if not enums then return nil, "This game client has no Edit Mode an add-on can use." end
    if type(bar) ~= "table" or type(bar.systemIndex) ~= "number" then return nil, "This bar is not one the Edit Mode lays out." end
    local info, layout = ns:EditModeActive()
    if not info then return nil, layout end
    local entry = ns.EditModeFind(layout, Enum.EditModeSystem.ActionBar, bar.systemIndex)
    if not entry then return nil, "This bar is not in your Edit Mode layout." end
    local percent = (tonumber(ns.EditModeGet(entry, enums.size)) or 0) > 20
    local any = false
    for name, setting in pairs(enums) do
        local v = tonumber(values[name])
        local lim = ns.barLayoutLimits[name]
        if v and setting ~= nil then
            v = math.max(lim[1], math.min(lim[2], math.floor(v + 0.5)))
            if name == "size" and not percent then v = ns.BarSizeToRaw(v) end
            local found, changed = ns.EditModeSet(entry, setting, v)
            if found and changed then any = true end
        end
    end
    if not any then return true, "nothing to change" end
    local ok, err = pcall(C_EditMode.SaveLayouts, info)
    if not ok then return nil, tostring(err) end
    if type(C_EditMode.SetActiveLayout) == "function" then pcall(C_EditMode.SetActiveLayout, info.activeLayout) end      -- (makes the game lay the bars out again)
    return true
end
