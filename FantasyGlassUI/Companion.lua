local ADDON, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- 11.2: the tools from the Menu button, pixel-perfect scale, a round minimap, a preview of shared
-- strings, a raid composition panel, pull and break timers, a battleground helper, bag rules, mail
-- rules, holidays and events, and talent builds.
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
-- Tools from the Menu button: "Tools" in the Menu button's list opens a small palette with a button
-- for every tool window, so they can be used without opening the options.
------------------------------------------------------------------------------------------
ns.TOOL_MENU = {                                             -- (in groups: see ns.TOOL_MENU_GROUPS)
    { "Am I ready?", "ready", "me" }, { "Ready check", "ready" }, { "Who is missing", "missing" },
    { "Raid composition", "comp" }, { "Boss notes", "bossnote", "list" }, { "Death recap", "death" },
    { "Rolls", "rolls" }, { "Group practice", "testgroup" }, { "Battleground score", "bgscore" },
    { "Lockouts", "lockouts" },
    { "Your characters", "alts" }, { "Checklist", "checklist" }, { "Professions", "crafts" },
    { "Profession cooldowns", "profcd" }, { "Reputations and currencies", "reps" }, { "Goals", "goal" },
    { "Talent builds", "talents" }, { "Session", "session" }, { "Gold history", "gold" },
    { "Sort bags", "sort" }, { "Put on upgrades", "equipbest" }, { "Bag rules", "bagrules" },
    { "Mail rules", "mailrules" }, { "Worth selling", "ah" }, { "Shopping list", "shop" },
    { "Crafting queue", "queue", "list" }, { "Loot log", "loot" }, { "Trades", "trades" },
    { "Notes on players", "note", "list" }, { "Recent group mates", "recent" }, { "Whisper window", "whispers" },
    { "To do", "todo" }, { "Notepad", "notepad" },
    { "Where to level", "level" }, { "Rares you have seen", "rares" }, { "Events and holidays", "events" },
    { "Key bindings", "keys" }, { "Quiet mode", "quiet" }, { "Layout gallery", "gallery" },
    { "Preview a shared string", "sharepreview" }, { "Backups", "backup" }, { "Changes to this profile", "history" },
    { "What's this?", "whatsthis" }, { "Check new features", "checknew" }, { "Performance", "perf" },
    { "Self-test", "selftest" },
}
-- Where each group of the Tools menu starts, and its heading (the menu's buttons are in this order).
ns.TOOL_MENU_GROUPS = { [1] = "Groups and raids", [11] = "Your characters", [20] = "Bags, gear and trade",
                        [29] = "People and notes", [34] = "The world", [37] = "The add-on itself" }
local palette
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_DISABLED")
    ev:SetScript("OnEvent", function() if palette then palette:Hide() end end)
end
function ns:ToggleToolsMenu(anchor)
    if InCombatLockdown() then ns:Print("Not during a fight."); return false end
    if palette then
        if palette.open then palette:Hide(); palette.open = false; return false end
        palette:Show(); palette.open = true; return true
    end
    local COLS, BW, BH, HEAD = 4, 156, 22, 18            -- (four across keeps the panel on a small screen)
    -- where each button goes: a group starts on a new row, under its heading
    local spots, headings, y, col = {}, {}, -30, 0
    for i in ipairs(ns.TOOL_MENU) do
        local group = ns.TOOL_MENU_GROUPS and ns.TOOL_MENU_GROUPS[i]
        if group then
            if col > 0 then y = y - (BH + 2); col = 0 end
            headings[#headings + 1] = { text = group, y = y }
            y = y - HEAD
        elseif col >= COLS then
            y = y - (BH + 2); col = 0
        end
        spots[i] = { x = 8 + col * (BW + 4), y = y }
        col = col + 1
    end
    local height = -(y - (BH + 2)) + 12
    palette = CreateFrame("Frame", "FantasyGlassUIToolMenu", UIParent, ns.template)
    palette:SetSize(COLS * (BW + 4) + 16, height)
    palette:SetFrameStrata("DIALOG")
    if palette.SetClampedToScreen then palette:SetClampedToScreen(true) end
    palette:SetBackdrop(ns.BACKDROP)
    ns:Paint(palette, "SetBackdropColor", "window", 0.97)
    ns:Paint(palette, "SetBackdropBorderColor", "@accent", 1)
    ns:Dress(palette)
    palette:EnableMouse(true)
    palette:SetScript("OnShow", function(self) self.open = true end)
    palette:SetScript("OnHide", function(self) self.open = false end)
    tinsert(UISpecialFrames, "FantasyGlassUIToolMenu")
    local title = ns:NewText(palette, 13, "LEFT", true)
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText(ns:Tr("Tools"))
    ns:Paint(title, "SetTextColor", "@accent")
    local close = ns:CreateButton(palette, "X", 20, 18, function() palette:Hide() end)
    close:SetPoint("TOPRIGHT", -6, -6)
    for _, h in ipairs(headings) do
        local fs = ns:NewText(palette, 11, "LEFT")
        fs:SetPoint("TOPLEFT", 10, h.y - 3)
        fs:SetText(ns:Tr(h.text))
        ns:Paint(fs, "SetTextColor", "dim")
    end
    palette.buttons = {}
    for i, def in ipairs(ns.TOOL_MENU) do
        local b = ns:CreateButton(palette, def[1], BW, BH, function()
            palette:Hide()
            local word = def[2]
            ns:ToolCommand(word .. (def[3] and (" " .. def[3]) or ""), word .. (def[3] and (" " .. def[3]) or ""))
        end)
        b:SetPoint("TOPLEFT", spots[i].x, spots[i].y)
        local typed = (def[2] == "checknew") and "/fgui check new" or ("/fgui " .. def[2] .. (def[3] and (" " .. def[3]) or ""))
        ns:ButtonTip(b, function()                              -- (what the help says of it, and what to type instead)
            local about = ns.HelpAbout and ns.HelpAbout(def[2], def[3])
            return (about and (ns:Tr(about) .. "\n") or "") .. "|cffffd100" .. typed .. "|r"
        end)
        if b.text then ns:Font(b.text, 11) end
        palette.buttons[i] = b
    end
    palette:ClearAllPoints()
    local a = anchor or ns.menuButton
    if a then palette:SetPoint("BOTTOMRIGHT", a, "TOPRIGHT", 0, 4) else palette:SetPoint("CENTER") end
    palette:Show()
    palette.open = true
    ns.toolPalette = palette
    return true
end

------------------------------------------------------------------------------------------
-- Pixel-perfect scale: the whole interface at the scale where one of its pixels is one of the
-- screen's, so thin rims stay sharp. Switching it off puts back the scale the game had.
------------------------------------------------------------------------------------------
function ns.PixelScale(screenHeight)
    screenHeight = tonumber(screenHeight)
    if not screenHeight or screenHeight <= 0 then return nil end
    return 768 / screenHeight
end
function ns:ApplyPixelScale()
    if InCombatLockdown() then ns.pixelPending = true; return false end
    ns.pixelPending = nil
    if type(GetPhysicalScreenSize) ~= "function" then ns.pixelState = "this client does not give the screen size"; return false end
    local _, h = GetPhysicalScreenSize()
    if ns.db.pixelPerfect then
        local s = ns.PixelScale(h)
        if not s then return false end
        if ns.root and ns.root.scaleBefore == nil then ns.root.scaleBefore = UIParent:GetScale() end
        UIParent:SetScale(s)
        ns.pixelState = format("on: %.4f for a screen %d high", s, h)
        return s
    elseif ns.root and ns.root.scaleBefore then
        UIParent:SetScale(ns.root.scaleBefore)
        ns.root.scaleBefore = nil
        ns.pixelState = "off"
    end
    return false
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Pixel-perfect scale", function(_, event)
        if not ns.db then return end
        if event == "PLAYER_REGEN_ENABLED" and not ns.pixelPending then return end
        if ns.db.pixelPerfect or (ns.root and ns.root.scaleBefore) then ns:After(0.5, function() pcall(ns.ApplyPixelScale, ns) end) end
    end))
end

------------------------------------------------------------------------------------------
-- A round minimap (the add-on's minimap panel is square unless this is on).
------------------------------------------------------------------------------------------
local roundRing
function ns:ApplyMinimapShape()
    if type(Minimap) ~= "table" or not Minimap.SetMaskTexture then return false end
    local round = ns.db.minimapRound and true or false
    Minimap:SetMaskTexture(round and "Interface\\CharacterFrame\\TempPortraitAlphaMask" or "Interface\\ChatFrame\\ChatFrameBackground")
    _G.GetMinimapShape = function() return round and "ROUND" or "SQUARE" end
    if round and not roundRing then
        roundRing = CreateFrame("Frame", nil, Minimap)
        roundRing:SetAllPoints()
        roundRing:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 3)
        local t = roundRing:CreateTexture(nil, "OVERLAY")
        t:SetPoint("TOPLEFT", -3, 3)
        t:SetPoint("BOTTOMRIGHT", 3, -3)
        local runic = (ns.style == "RUNIC")                  -- (Runic: a band of runes round the map)
        t:SetTexture(ns.MEDIA .. (runic and "ring_runic.tga" or "ring.tga"))
        if runic then t:SetPoint("TOPLEFT", -6, 6); t:SetPoint("BOTTOMRIGHT", 6, -6) end
        ns:Paint(t, "SetVertexColor", runic and "@accent" or "@border", runic and 0.7 or 1)
        roundRing.tex = t
    end
    if roundRing then roundRing:SetShown(round) end
    if ns.minimapRunes then ns.minimapRunes:SetShown(not round) end        -- (the square's rune band, not round the circle)
    ns.minimapShape = round and "ROUND" or "SQUARE"
    return round
end

------------------------------------------------------------------------------------------
-- Preview a shared string: paste a profile, layout or theme string someone gave you and see it
-- before taking it: where their panels go (drawn like the gallery's cards) and their colors.
------------------------------------------------------------------------------------------
local preview
function ns:ShowSharePreview()
    if not preview then
        preview = CreateFrame("Frame", "FantasyGlassUISharePreview", UIParent, ns.template)
        preview:SetSize(520, 430)
        preview:SetPoint("CENTER")
        preview:SetFrameStrata("DIALOG")
        preview:SetBackdrop(ns.BACKDROP)
        ns:Paint(preview, "SetBackdropColor", "window", 0.97)
        ns:Paint(preview, "SetBackdropBorderColor", "@accent", 1)
        ns:Dress(preview)
        preview:EnableMouse(true); preview:SetMovable(true); if preview.SetClampedToScreen then preview:SetClampedToScreen(true) end; preview:RegisterForDrag("LeftButton")
        preview:SetScript("OnDragStart", preview.StartMoving); preview:SetScript("OnDragStop", preview.StopMovingOrSizing)
        tinsert(UISpecialFrames, "FantasyGlassUISharePreview")
        local title = preview:CreateFontString(nil, "OVERLAY")
        ns:Font(title, 15, true)
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetText(ns:Tr("Preview a shared string"))
        ns:Paint(title, "SetTextColor", "@accent")
        local close = ns:CreateButton(preview, "X", 22, 20, function() preview:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        preview.box = ns:CreateEditBox(preview, 400, 24, "paste a profile, layout or theme string")
        preview.box:SetPoint("TOPLEFT", 14, -42)
        preview.go = ns:CreateButton(preview, "Preview", 80, 24, function() ns:PreviewShared(preview.box:GetText()) end)
        preview.go:SetPoint("LEFT", preview.box, "RIGHT", 8, 0)
        preview.screen = CreateFrame("Frame", nil, preview)
        preview.screen:SetSize(492, 276)
        preview.screen:SetPoint("TOPLEFT", 14, -76)
        local bg = preview.screen:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); bg:SetTexture(ns.FLAT); bg:SetVertexColor(0.04, 0.05, 0.08, 0.9)
        preview.screen.bg = bg
        preview.boxes = {}
        preview.info = ns:NewText(preview, 12, "LEFT")
        preview.info:SetPoint("TOPLEFT", 14, -360)
        preview.info:SetWidth(492)
        preview.use = ns:CreateButton(preview, "Use it", 120, 24, function() if preview.apply then preview.apply() end end)
        preview.use:SetPoint("BOTTOMRIGHT", -14, 12)
        preview.use:Hide()
    end
    preview:Show()
    return preview
end
-- What a shared string is and holds, without taking it: kind ("profile", "layout", "theme"), data.
function ns:PeekShared(text)
    if type(text) ~= "string" or text == "" then return nil, "Paste a string first." end
    text = strtrim(text)
    if ns.DecodeShared then return ns:DecodeShared(text) end
    return nil, "this version cannot read shared strings"
end
function ns:PreviewShared(text)
    local p = ns:ShowSharePreview()
    for _, b in ipairs(p.boxes) do b:Hide() end
    if p.screen.bg then p.screen.bg:SetVertexColor(0.04, 0.05, 0.08, 0.9) end
    p.use:Hide()
    p.apply = nil
    local kind, data = ns:PeekShared(text)
    if not kind then p.info:SetText("|cffff5555" .. ns:Tr(tostring(data)) .. "|r"); return false end
    local pack = (kind == "pack") and data or nil
    if pack then data = type(pack.profile) == "table" and pack.profile or {} end
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    if type(W) ~= "number" or W <= 0 then W, H = 1920, 1080 end
    local fx, fy = 492 / W, 276 / H
    local pos = type(data.pos) == "table" and data.pos or {}
    local n = 0
    local accent = { ns:Role("@accent") }
    local themeName
    if kind == "profile" or kind == "pack" then
        local t = data.theme and ns.themes[data.theme]
        themeName = t and t.name or data.theme
        if type(data.accent) == "string" and ns.AccentColor then local okA, r, g, b = pcall(ns.AccentColor, ns, data.accent); if okA and type(r) == "number" then accent = { r, g, b } end end
    elseif kind == "theme" then
        themeName = type(data.name) == "string" and data.name or nil
        local a = data.accent
        if type(a) == "table" and type(a[1]) == "number" then accent = { a[1], a[2] or 1, a[3] or 1 } end
        local bg = p.screen.bg
        if bg and type(data.panel) == "table" and type(data.panel[1]) == "number" then bg:SetVertexColor(data.panel[1], data.panel[2] or 0, data.panel[3] or 0, 0.95) end
    end
    for key, at in pairs(pos) do
        if type(at) == "table" and at[1] then
            n = n + 1
            local b = p.boxes[n]
            if not b then b = p.screen:CreateTexture(nil, "ARTWORK"); b:SetTexture(ns.FLAT); p.boxes[n] = b end
            local w, h = 160, 32
            for _, m in ipairs(ns.movables or {}) do
                if m.key == key then local okS, mw, mh = pcall(m.frame.GetSize, m.frame); if okS and type(mw) == "number" and not Secret(mw) then w, h = mw, mh end end
            end
            local s = type(data.scale) == "table" and tonumber(data.scale[key]) or 1
            w, h = w * s, h * s
            local left, top = ns.GalleryRect(at[1], at[3] or 0, at[4] or 0, w, h, W, H)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", p.screen, "TOPLEFT", math.max(0, math.min(490, left * fx)), -math.max(0, math.min(274, top * fy)))
            b:SetSize(math.max(2, w * fx), math.max(2, h * fy))
            if key == "ufPlayer" or key == "ufTarget" then b:SetVertexColor(accent[1], accent[2], accent[3], 0.9)
            elseif key == "raid" or key:find("^ufParty") then b:SetVertexColor(0.35, 0.75, 0.45, 0.8)
            else b:SetVertexColor(0.7, 0.72, 0.78, 0.6) end
            b:Show()
        end
    end
    local what = { profile = "A whole profile", layout = "A layout", theme = "A theme", pack = "A whole-UI pack" }
    p.info:SetText(format("%s.  %s", ns:Tr(what[kind] or kind), format(ns:Tr("%d panels placed."), n))
        .. (themeName and ("  " .. ns:Tr("Theme") .. ": " .. tostring(themeName)) or ""))
    p.use:Show()
    p.apply = function()
        local ok, msg
        if kind == "layout" then ok, msg = ns:ImportLayout(text)
        elseif kind == "theme" then ok, msg = ns:ImportTheme(text)
        elseif kind == "pack" then
            local name = "Pack " .. date("%m-%d %H%M")
            local editMode
            ok, msg, editMode = ns:ImportPack(name, text)
            if ok then msg = format(ns:Tr("Saved as the profile \"%s\": choose it on the Profiles tab."), name) end
            if ok and editMode and ns.ShowCopyBox then
                ns:After(0.2, function() ns:ShowCopyBox(editMode, ns:Tr("The game's bar layout from the pack: Esc, Edit Mode, Import, and paste this.")) end)
            end
        else
            local name = "Shared " .. date("%m-%d %H%M")
            ok, msg = ns:ImportProfile(name, text)
            if ok then msg = format(ns:Tr("Saved as the profile \"%s\": choose it on the Profiles tab."), name) end
        end
        p.info:SetText((ok and "|cff33ff66" or "|cffff5555") .. ns:Tr(tostring(msg or (ok and "Done." or "Not taken."))) .. "|r")
    end
    p.kind, p.count = kind, n
    return kind, n
end

------------------------------------------------------------------------------------------
-- Raid composition: roles, classes, and which group-wide things your group has someone for.
------------------------------------------------------------------------------------------
ns.COMP_NEEDS = {
    { label = "Fortitude", classes = { PRIEST = true } },
    { label = "Mark of the Wild", classes = { DRUID = true } },
    { label = "Arcane Intellect", classes = { MAGE = true } },
    { label = "Blessings", classes = { PALADIN = true } },
    { label = "Battle Shout", classes = { WARRIOR = true } },
    { label = "Totems", classes = { SHAMAN = true } },
    { label = "Battle resurrection", classes = { DRUID = true } },
    { label = "Soulstone and healthstones", classes = { WARLOCK = true } },
    { label = "Remove curses", classes = { MAGE = true, DRUID = true } },
    { label = "Dispel magic", classes = { PRIEST = true, PALADIN = true } },
    { label = "Cure poison", classes = { DRUID = true, PALADIN = true, SHAMAN = true } },
}
-- members = { { name, class, role } }; returns roles counts, class counts, and for each need who covers it.
function ns.Composition(members)
    local roles, classes, cover = { TANK = 0, HEALER = 0, DAMAGER = 0, NONE = 0 }, {}, {}
    for _, m in ipairs(members) do
        roles[m.role or "NONE"] = (roles[m.role or "NONE"] or 0) + 1
        if m.class then classes[m.class] = (classes[m.class] or 0) + 1 end
    end
    for _, need in ipairs(ns.COMP_NEEDS) do
        local who = {}
        for _, m in ipairs(members) do if m.class and need.classes[m.class] then who[#who + 1] = m.name end end
        cover[#cover + 1] = { label = need.label, who = who }
    end
    return roles, classes, cover
end
function ns:ShowComposition()
    local list = {}
    local _, myClass = UnitClass("player")
    local myRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    list[1] = { name = UnitName("player"), class = myClass, role = (type(myRole) == "string" and not Secret(myRole)) and myRole or ns.db.role and ({ TANK = "TANK", HEALER = "HEALER", DAMAGE = "DAMAGER" })[ns.db.role] or "NONE" }
    for _, m in ipairs(ns:GroupMembers()) do
        local r = UnitGroupRolesAssigned and UnitGroupRolesAssigned(m.unit)
        list[#list + 1] = { name = m.name, class = m.class, role = (type(r) == "string" and not Secret(r)) and r or "NONE" }
    end
    local roles, classes, cover = ns.Composition(list)
    local lines = {}
    lines[#lines + 1] = { left = ns:AccentHex() .. format(ns:Tr("%d players"), #list) .. "|r",
        right = format("|cff4d99ff%d %s|r  |cff4dff80%d %s|r  |cffff6655%d %s|r", roles.TANK, ns:Tr("tanks"), roles.HEALER, ns:Tr("healers"), roles.DAMAGER + roles.NONE, ns:Tr("damage")) }
    local cls = {}
    for c, n in pairs(classes) do cls[#cls + 1] = { c = c, n = n } end
    table.sort(cls, function(a, b) return a.n > b.n end)
    for _, e in ipairs(cls) do
        local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[e.c]) or e.c
        local r, g, b = ns:ClassRGB(e.c)
        lines[#lines + 1] = { left = "    " .. name, right = tostring(e.n), color = { r or 1, g or 1, b or 1 } }
    end
    lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Who covers what") .. "|r" }
    for _, c in ipairs(cover) do
        lines[#lines + 1] = { left = "    " .. ns:Tr(c.label), right = (#c.who > 0) and ("|cff33ff66" .. table.concat(c.who, ", ") .. "|r") or ("|cffff5555" .. ns:Tr("nobody") .. "|r") }
    end
    return ns:ShowList("Composition", "Raid composition", lines, "Roles as people chose them in the group finder or role check.", 460, 420)
end

------------------------------------------------------------------------------------------
-- Pull and break timers: a big countdown for everyone in the group who has the add-on. /fgui pull 10
-- also starts the game's own pull countdown; /fgui break 5 is minutes. Group leaders and assistants.
------------------------------------------------------------------------------------------
local PREFIX = "FGUI"
local bigBar
local function BigBar()
    if bigBar then return bigBar end
    local f = CreateFrame("Frame", "FantasyGlassUICountdown", UIParent, ns.template)
    f:SetSize(320, 30)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "bg", 0.85)
    ns:Paint(f, "SetBackdropBorderColor", "@accent", 1)
    f.bar = ns:NewStatusBar(f, true)
    f.bar:SetPoint("TOPLEFT", 3, -3); f.bar:SetPoint("BOTTOMRIGHT", -3, 3)
    ns:Paint(f.bar, "SetStatusBarColor", "@accent")
    f.text = ns:NewText(f.bar, 14, "CENTER", true)
    f.text:SetPoint("CENTER")
    f:Hide()
    f:SetScript("OnUpdate", function(self)
        local left = (self.ends or 0) - GetTime()
        if left <= 0 then
            self:Hide()
            if self.kind == "pull" and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959, "Master") end
            return
        end
        self.bar:SetValue(left)
        self.text:SetText(format("%s  %s", self.label, ns.Clock(left)))
    end)
    local entry = ns:RegisterMovable(f, "countdown", "Pull and break timer")
    if type(entry) == "table" then entry.offPage = true end
    bigBar = f
    return f
end
function ns:StartCountdown(kind, seconds, from)
    seconds = math.max(1, math.min(3600, tonumber(seconds) or 0))
    if kind == "pull" and ns.db.bossNotes and ns.TargetBoss then         -- a pull on a boss: its note (Raid.lua)
        local boss = ns.TargetBoss()
        if boss then pcall(ns.ShowBossNote, ns, boss, true) end
    end
    local f = BigBar()
    f.kind = kind
    f.label = ns:Tr(kind == "pull" and "Pull" or kind == "bg" and "The battle begins" or "Break") .. (from and ("  |cff9aa4b4(" .. from .. ")|r") or "")
    f.ends = GetTime() + seconds
    f.bar:SetMinMaxValues(0, seconds)
    f:Show()
    ns.countdownLast = kind
    return f
end
-- "PULL:10" / "BREAK:300" from a group member
function ns.ParseCountdown(text)
    local kind, n = tostring(text or ""):match("^(%u+):(%d+)$")
    if kind == "PULL" then return "pull", tonumber(n) end
    if kind == "BREAK" then return "break", tonumber(n) end
    return nil
end
function ns:CountdownCommand(kind, text)
    local n = tonumber(ns.Trim(text))
    if not n then n = (kind == "pull") and 10 or 5 end
    local seconds = (kind == "break") and n * 60 or n
    if not (IsInGroup and IsInGroup()) then ns:StartCountdown(kind, seconds); return true end
    local leader = (UnitIsGroupLeader and UnitIsGroupLeader("player")) or (UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
    if not ns.Yes(leader) then ns:Print("Only the group leader or an assistant can start it."); return false end
    local channel = (IsInRaid and IsInRaid()) and "RAID" or "PARTY"
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        pcall(C_ChatInfo.SendAddonMessage, PREFIX, (kind == "pull" and "PULL:" or "BREAK:") .. seconds, channel)
    end
    if kind == "pull" and C_PartyInfo and C_PartyInfo.DoCountdown then pcall(C_PartyInfo.DoCountdown, seconds) end
    ns:StartCountdown(kind, seconds)
    return true
end
do
    local ev = CreateFrame("Frame")
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    for _, e in ipairs({ "CHAT_MSG_ADDON", "START_PLAYER_COUNTDOWN", "CHAT_MSG_BG_SYSTEM_NEUTRAL" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Countdowns", function(_, event, a, b, c, d)
        if event == "CHAT_MSG_ADDON" then
            if a ~= PREFIX or Secret(b) then return end
            local kind, n = ns.ParseCountdown(b)
            local me = UnitName("player")
            local from = type(d) == "string" and not Secret(d) and d:gsub("%-.*$", "") or nil
            if kind and from ~= me then ns:StartCountdown(kind, n, from) end
        elseif event == "START_PLAYER_COUNTDOWN" then
            local seconds = tonumber(b) or tonumber(c)            -- (initiator, timeRemaining, totalTime)
            if seconds and seconds > 0 and not (bigBar and bigBar:IsShown() and bigBar.kind == "pull") then ns:StartCountdown("pull", seconds) end
        elseif event == "CHAT_MSG_BG_SYSTEM_NEUTRAL" and ns.db.bgHelper then
            local seconds = ns.BattleStartsIn(a)
            if seconds then ns:StartCountdown("bg", seconds) end
        end
    end))
end

------------------------------------------------------------------------------------------
-- Battleground helper: how long you have waited in the queue, how long the invitation has left,
-- a countdown to the battle's start, and the score (/fgui bgscore).
------------------------------------------------------------------------------------------
-- "The battle begins in 1 minute." / "... 30 seconds." -> seconds (the message's own numbers and units)
function ns.BattleStartsIn(text)
    if type(text) ~= "string" or Secret(text) then return nil end
    local n, unit = text:match("(%d+)%s*(%a+)")
    n = tonumber(n)
    if not n or not unit then return nil end
    unit = unit:lower()
    if unit:find("^min") then return n * 60 end
    if unit:find("^sec") or unit:find("^sek") or unit:find("^seg") then return n end
    return nil
end
ns:NewModule("bgHelper", function()
    if type(GetBattlefieldStatus) ~= "function" then ns.bgState = "this client has no battlegrounds"; return end
    local f = CreateFrame("Frame", "FantasyGlassUIQueue", UIParent, ns.template)
    f:SetSize(220, 22)
    f:SetPoint("TOP", UIParent, "TOP", 0, -30)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "bg", 0.8)
    ns:Paint(f, "SetBackdropBorderColor", "@border", 1)
    f.text = ns:NewText(f, 11, "CENTER")
    f.text:SetPoint("CENTER")
    f:Hide()
    local function Update()
        local max = (GetMaxBattlefieldID and GetMaxBattlefieldID()) or 3
        local shown
        for i = 1, max do
            local ok, status, name = pcall(GetBattlefieldStatus, i)
            if ok and not Secret(status) then
                if status == "queued" and GetBattlefieldTimeWaited then
                    local waited = (tonumber(GetBattlefieldTimeWaited(i)) or 0) / 1000
                    local est = GetBattlefieldEstimatedWaitTime and (tonumber(GetBattlefieldEstimatedWaitTime(i)) or 0) / 1000 or 0
                    shown = format("%s  %s%s", tostring(name or ns:Tr("Queue")), ns.Clock(waited), est > 0 and ("  |cff9aa4b4~" .. ns.Clock(est) .. "|r") or "")
                elseif status == "confirm" and GetBattlefieldPortExpiration then
                    local left = tonumber(GetBattlefieldPortExpiration(i)) or 0
                    shown = format("|cffffd100%s|r  %s", ns:Tr("Enter now"), ns.Clock(left))
                end
            end
        end
        if shown or ns.moving then f.text:SetText(shown or ns:Tr("Queue")); f:Show() else f:Hide() end
        ns.bgState = shown and "queued" or "on"
        return shown
    end
    ns.bgTest = { Update = Update, frame = f }
    ns:Every(1, "Battleground queue", Update)
    local entry = ns:RegisterMovable(f, "bgQueue", "Battleground Queue")
    if type(entry) == "table" then entry.offPage = true end
end)
function ns:ShowBattlegroundScore()
    if type(GetNumBattlefieldScores) ~= "function" or type(GetBattlefieldScore) ~= "function" then ns:Print("This client gives no battleground scores."); return end
    if RequestBattlefieldScoreData then pcall(RequestBattlefieldScoreData) end
    local rows = {}
    local okN, n = pcall(GetNumBattlefieldScores)
    for i = 1, (okN and tonumber(n)) or 0 do
        local ok, name, kb, hk, deaths, honor, faction, _, _, class, classToken, damage, healing = pcall(GetBattlefieldScore, i)
        if ok and type(name) == "string" and not Secret(name) then
            rows[#rows + 1] = { name = name, kb = tonumber(kb) or 0, hk = tonumber(hk) or 0, deaths = tonumber(deaths) or 0,
                faction = faction, class = classToken, damage = tonumber(damage) or 0, healing = tonumber(healing) or 0 }
        end
    end
    table.sort(rows, function(a, b) if a.kb ~= b.kb then return a.kb > b.kb end return a.hk > b.hk end)
    local lines = {}
    for _, r in ipairs(rows) do
        local cr, cg, cb = ns:ClassRGB(r.class)
        lines[#lines + 1] = { left = r.name:gsub("%-.*$", ""), right = format("%d / %d / %d   %s", r.kb, r.hk, r.deaths,
            r.damage > 0 and (ns.ShortNumber and ns.ShortNumber(r.damage) or tostring(r.damage)) or ""), color = { cr or 1, cg or 1, cb or 1 } }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No scores: you are not in a battleground.") } end
    return ns:ShowList("BGScore", "Battleground score", lines, "Killing blows / honorable kills / deaths, and damage done.", 440, 420)
end

------------------------------------------------------------------------------------------
-- Bag rules: sections of your own in the one-window bags, each with a rule, in the order you set.
--   kinds: ilvl (item level at least), boe (bind on equip, not bound), set (in a gear set),
--   quality (at least: 0 gray .. 5 legendary), type (consumable, gear, trade, quest, recipe, gem),
--   name (the name contains)
------------------------------------------------------------------------------------------
ns.BAG_RULE_KINDS = {
    { "ilvl", "Item level at least" }, { "boe", "Bind on equip" }, { "set", "In a gear set" },
    { "quality", "Quality at least (0-5)" }, { "type", "Kind of item" }, { "name", "Name contains" },
}
local TYPE_CLASS = { consumable = 0, gear = { 2, 4 }, trade = 7, quest = 12, recipe = 9, gem = 3, reagent = 5 }
-- Does an item (its facts) meet a rule?
function ns.BagRuleMatch(rule, item)
    local k, v = rule.kind, rule.value
    if k == "ilvl" then return (tonumber(item.ilvl) or 0) >= (tonumber(v) or 1e9) end
    if k == "boe" then return item.bindType == 2 and not item.bound end
    if k == "set" then return item.inSet and true or false end
    if k == "quality" then return (tonumber(item.quality) or -1) >= (tonumber(v) or 99) end
    if k == "type" then
        local want = TYPE_CLASS[tostring(v or ""):lower()]
        if type(want) == "table" then return item.classID == want[1] or item.classID == want[2] end
        return want ~= nil and item.classID == want
    end
    if k == "name" then return type(item.name) == "string" and type(v) == "string" and v ~= "" and item.name:lower():find(v:lower(), 1, true) ~= nil end
    return false
end
local function Rules()
    if type(ns.db.bagRules) ~= "table" then ns.db.bagRules = {} end
    return ns.db.bagRules
end
ns.BagRules = Rules
-- Ready-made sections, each a switch on the Features tab (Bag rules), in the order they are tried
-- after your own rules: { switch, section, test(item) }.
local MATS = { [5] = "Cloth", [6] = "Leather", [7] = "Ore and stone", [8] = "Cooking ingredients", [9] = "Herbs",
               [10] = "Elemental", [12] = "Enchanting materials" }
ns.BAG_PRESETS = {
    { "bagSecUpgrades", "Upgrades", function(it) return it.upgrade end },
    { "bagSecSets", "Gear sets", function(it) return it.inSet end },
    { "bagSecBoE", "Bind on equip", function(it) return (it.classID == 2 or it.classID == 4) and it.bindType == 2 and not it.bound end },
    { "bagSecMats", nil, function(it)
        if it.classID == 7 then return MATS[it.subclassID] end
        if it.classID == 3 then return "Gems" end
    end },
    { "bagSecConsumables", nil, function(it)
        if it.classID ~= 0 then return nil end
        if it.subclassID == 1 or it.subclassID == 2 or it.subclassID == 3 then return "Potions and elixirs" end
        if it.subclassID == 5 then return "Food and drink" end
        if it.subclassID == 4 then return "Scrolls" end
        if it.subclassID == 7 then return "Bandages" end
    end },
    { "bagSecRecipes", "Recipes", function(it) return it.classID == 9 end },
}
-- The facts about a bag slot's item that the rules need.
local function Facts(info, wantUpgrade)
    local link = info.hyperlink
    local item = { quality = info.quality, bound = ns.Is(info.isBound, true), name = nil }
    if info.itemID then
        local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        if GetInstant then
            local ok, _, _, _, _, _, classID, subclassID = pcall(GetInstant, info.itemID)
            if ok then item.classID, item.subclassID = classID, subclassID end
        end
        item.inSet = ns.InGearSet and ns:InGearSet(info.itemID) or false
    end
    if type(link) == "string" and not Secret(link) then
        local ok, name, _, _, _, _, _, _, _, _, _, _, _, _, bindType = pcall(function() return ns:GetItemInfo(link) end)
        if ok then item.name, item.bindType = name, bindType end
        if C_Item and C_Item.GetDetailedItemLevelInfo then local okL, l = pcall(C_Item.GetDetailedItemLevelInfo, link); if okL then item.ilvl = l end end
        if wantUpgrade and (item.classID == 2 or item.classID == 4) and type(item.ilvl) == "number" and ns.IsUpgrade then
            local okU, up = pcall(ns.IsUpgrade, ns, link, item.ilvl)
            item.upgrade = okU and up and true or false
        end
    end
    return item
end
ns.BagFacts = Facts
-- The section an item goes in: your own rules first (if their switch is on), then the ready-made
-- sections that are switched on. nil: the bags' usual sections.
function ns.BagSectionFor(item, rules, db)
    if db.bagSecMine ~= false then
        for _, rule in ipairs(rules) do
            if ns.BagRuleMatch(rule, item) then return rule.section end
        end
    end
    for _, p in ipairs(ns.BAG_PRESETS) do
        if db[p[1]] then
            local hit = p[3](item)
            if hit then return ns:Tr(type(hit) == "string" and hit or p[2]) end
        end
    end
    return nil
end
local function AnyPreset()
    for _, p in ipairs(ns.BAG_PRESETS) do if ns.db[p[1]] then return true end end
    return false
end
-- The section a bag slot's item goes in by your rules (the first that fits), or nil.
function ns:BagRuleFor(info)
    if type(info) ~= "table" then return nil end
    local rules = Rules()
    local mine = ns.db.bagSecMine ~= false and #rules > 0
    if not mine and not AnyPreset() then return nil end
    return ns.BagSectionFor(Facts(info, ns.db.bagSecUpgrades), rules, ns.db)
end
-- Where a section of yours comes in the bags: your rules' order, then the ready-made ones in their
-- order, then any other of yours A to Z.
local PRESET_ORDER = { "Upgrades", "Gear sets", "Bind on equip", "Cloth", "Leather", "Ore and stone", "Herbs", "Cooking ingredients",
    "Elemental", "Enchanting materials", "Gems", "Potions and elixirs", "Food and drink", "Scrolls", "Bandages", "Recipes" }
function ns.BagRuleRank(section)
    for i, rule in ipairs(Rules()) do if rule.section == section then return i end end
    for i, name in ipairs(PRESET_ORDER) do if section == name or section == ns:Tr(name) then return 500 + i end end
    return 1000
end
function ns:BagRulesCommand(text)
    text = ns.Trim(text)
    local word, rest = text:match("^(%S+)%s*(.*)$")
    word = word and word:lower()
    local rules = Rules()
    if word == "add" then
        -- /fgui bagrules add <kind> [value] = <section name>
        local spec, section = rest:match("^(.-)%s*=%s*(.+)$")
        if not spec then ns:Print("/fgui bagrules add ilvl 50 = Upgrades   (kinds: ilvl, boe, set, quality, type, name)"); return end
        local kind, value = spec:match("^(%S+)%s*(.*)$")
        kind = kind and kind:lower()
        local known = false
        for _, k in ipairs(ns.BAG_RULE_KINDS) do if k[1] == kind then known = true end end
        if not known then ns:Print("Kinds: ilvl, boe, set, quality, type (consumable, gear, trade, quest, recipe, gem), name."); return end
        rules[#rules + 1] = { kind = kind, value = value ~= "" and value or nil, section = ns.Trim(section):sub(1, 24) }
        ns:Print("Bag rule added: %s.", rules[#rules].section)
    elseif word == "remove" then
        local n = tonumber(rest)
        if n and rules[n] then table.remove(rules, n) end
    elseif word == "up" or word == "down" then
        local n = tonumber(rest)
        local m = n and (word == "up" and n - 1 or n + 1)
        if n and m and rules[n] and rules[m] then rules[n], rules[m] = rules[m], rules[n] end
    end
    if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end
    return ns:ShowBagRules()
end
function ns:ShowBagRules()
    local lines = {}
    for i, rule in ipairs(Rules()) do
        local label = rule.kind
        for _, k in ipairs(ns.BAG_RULE_KINDS) do if k[1] == rule.kind then label = ns:Tr(k[2]) end end
        lines[#lines + 1] = { left = format("%d. %s%s", i, label, rule.value and (" " .. rule.value) or ""), right = ns:AccentHex() .. rule.section .. "|r",
            click = function(button)
                if button == "RightButton" then table.remove(Rules(), i)
                elseif i > 1 then local r = Rules(); r[i], r[i - 1] = r[i - 1], r[i] end
                if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end
                ns:ShowBagRules()
            end, tip = { rule.section, ns:Tr("Click: move it up. Right-click: remove it.") } }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No rules yet. Example: /fgui bagrules add ilvl 50 = Upgrades") } end
    return ns:ShowList("BagRules", "Bag rules", lines, "The first rule an item meets decides its section. /fgui bagrules add <kind> [value] = <section>", 460, 300)
end

------------------------------------------------------------------------------------------
-- Mail rules: "all cloth to my tailor". With the mailbox open, "Send by my rules" (on the mail
-- window, or /fgui mailrules send) sends each rule's items, up to twelve to a letter.
--   /fgui mailrules add <character> <what>      what: cloth, leather, ore, herbs, cooking, elemental,
--   enchanting, gems, potions, or name:<part of a name>
------------------------------------------------------------------------------------------
ns.MAIL_KINDS = { cloth = { 7, 5 }, leather = { 7, 6 }, ore = { 7, 7 }, cooking = { 7, 8 }, herbs = { 7, 9 }, elemental = { 7, 10 },
                  enchanting = { 7, 12 }, gems = { 3 }, potions = { 0 } }
function ns.MailRuleMatch(what, classID, subclassID, name)
    what = tostring(what or ""):lower()
    local part = what:match("^name:(.+)$")
    if part then return type(name) == "string" and name:lower():find(part, 1, true) ~= nil end
    local k = ns.MAIL_KINDS[what]
    if not k then return false end
    if classID ~= k[1] then return false end
    return k[2] == nil or subclassID == k[2]
end
local function MailRules()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.mailRules) ~= "table" then ns.root.mailRules = {} end
    return ns.root.mailRules
end
ns.MailRules = MailRules
-- The bag slots a rule would send: { { bag, slot } ... } (soulbound items stay).
local function ItemsFor(rule)
    local out = {}
    local C = C_Container
    if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return out end
    local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    for bag = 0, 4 do
        for slot = 1, (tonumber(C.GetContainerNumSlots(bag)) or 0) do
            local ok, info = pcall(C.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and info.itemID and not ns.Is(info.isBound, true) then
                local okI, _, _, _, _, _, classID, subclassID = pcall(GetInstant, info.itemID)
                local name = (type(info.hyperlink) == "string" and not Secret(info.hyperlink)) and info.hyperlink:match("%[(.-)%]") or nil
                if okI and ns.MailRuleMatch(rule.what, classID, subclassID, name) then out[#out + 1] = { bag, slot } end
            end
        end
    end
    return out
end
-- The materials that can be sent by switches on the Features tab (Mail rules), each to the character
-- typed beside it there (kept for the whole account).
ns.MAIL_SWITCHES = { { "mailCloth", "cloth" }, { "mailLeather", "leather" }, { "mailOre", "ore" }, { "mailHerbs", "herbs" },
    { "mailCooking", "cooking" }, { "mailElemental", "elemental" }, { "mailEnchanting", "enchanting" }, { "mailGems", "gems" }, { "mailPotions", "potions" } }
function ns.MailTargets()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.mailTo) ~= "table" then ns.root.mailTo = {} end
    return ns.root.mailTo
end
-- Everything to send, one job per character: { { to, whats = { ... } } }. Your own rules (Tools tab)
-- and the switches; never to the character you are on.
function ns.MailJobs(rules, db, targets, me)
    local jobs, byTo = {}, {}
    local function Add(to, what)
        if type(to) ~= "string" then return end
        to = ns.Trim(to)
        if to == "" or (type(me) == "string" and to:lower() == me:lower()) then return end
        local key = to:lower()
        local job = byTo[key]
        if not job then job = { to = to, whats = {} }; byTo[key] = job; jobs[#jobs + 1] = job end
        for _, w in ipairs(job.whats) do if w == what then return end end
        job.whats[#job.whats + 1] = what
    end
    if db.mailRulesOn ~= false then
        for _, r in ipairs(rules) do Add(r.to, r.what) end
    end
    for _, sw in ipairs(ns.MAIL_SWITCHES) do
        if db[sw[1]] then Add(targets[sw[2]], sw[2]) end
    end
    return jobs
end
local function Jobs() return ns.MailJobs(MailRules(), ns.db, ns.MailTargets(), UnitName("player")) end
local sending
local function SendNext()
    if not sending or InCombatLockdown() then sending = nil; return end
    local job = table.remove(sending, 1)
    if not job then sending = nil; ns:Print("Mail rules: all sent."); return end
    local items = {}
    for _, what in ipairs(job.whats) do
        for _, it in ipairs(ItemsFor({ what = what })) do items[#items + 1] = it end
    end
    if #items == 0 then return SendNext() end
    if MailFrameTab_OnClick then pcall(MailFrameTab_OnClick, nil, 2) end
    for i = 1, math.min(12, #items) do pcall(C_Container.UseContainerItem, items[i][1], items[i][2]) end
    if #items > 12 then table.insert(sending, 1, job) end         -- (more than one letter's worth: the same again)
    ns:After(0.4, function()
        local subject = ns:Tr("From your mail rules") .. ": " .. table.concat(job.whats, ", "):gsub("name:", "")
        local ok = pcall(SendMail, job.to, subject:sub(1, 64), "")
        if not ok then sending = nil; ns:Print("The game refused to send that letter.") end
    end)
end
function ns:SendByMailRules()
    if InCombatLockdown() then ns:Print("Not during a fight."); return false end
    if not (MailFrame and MailFrame:IsShown()) then ns:Print("Open a mailbox first."); return false end
    sending = Jobs()
    if #sending == 0 then ns:Print("Nothing to send: switch on a material under Mail rules (Features tab) and say who it goes to."); sending = nil; return false end
    SendNext()
    return true
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_CLOSED", "MAIL_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Mail rules", function(_, event)
        if event == "MAIL_SEND_SUCCESS" and sending then ns:After(0.5, SendNext)
        elseif event == "MAIL_FAILED" or event == "MAIL_CLOSED" then sending = nil
        elseif event == "MAIL_SHOW" and MailFrame then
            local want = ns.db.mailButton ~= false and #Jobs() > 0
            if want and not ns.mailRuleButton then
                local b = ns:CreateButton(MailFrame, "Send by my rules", 140, 22, function() ns:SendByMailRules() end)
                ns:ButtonTip(b, "Send the items your mail rules name to the characters they name. /fgui mailrules to change them.")
                b:SetPoint("BOTTOMRIGHT", MailFrame, "TOPRIGHT", 0, 2)
                ns.mailRuleButton = b
            end
            if ns.mailRuleButton then ns.mailRuleButton:SetShown(want) end
        end
    end))
end
function ns:MailRulesCommand(text)
    text = ns.Trim(text)
    local word, rest = text:match("^(%S+)%s*(.*)$")
    word = word and word:lower()
    local rules = MailRules()
    if word == "add" then
        local to, what = rest:match("^(%S+)%s+(.+)$")
        what = what and what:lower()
        if not to or not (ns.MAIL_KINDS[what or ""] or (what or ""):match("^name:.+")) then
            ns:Print("/fgui mailrules add <character> <what>   what: cloth, leather, ore, herbs, cooking, elemental, enchanting, gems, potions, name:<text>")
            return
        end
        rules[#rules + 1] = { to = to, what = what }
        ns:Print("Mail rule: %s to %s.", what, to)
    elseif word == "remove" then
        local n = tonumber(rest)
        if n and rules[n] then table.remove(rules, n) end
    elseif word == "send" then
        return ns:SendByMailRules()
    end
    local lines = {}
    for i, r in ipairs(rules) do
        lines[#lines + 1] = { left = format("%d. %s", i, r.what), right = ns:AccentHex() .. r.to .. "|r",
            click = function(button) if button == "RightButton" then table.remove(MailRules(), i); ns:MailRulesCommand("") end end,
            tip = { r.what .. " -> " .. r.to, ns:Tr("Right-click: remove it.") } }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No rules yet. Example: /fgui mailrules add Mytailor cloth") } end
    return ns:ShowList("MailRules", "Mail rules", lines, "With the mailbox open: \"Send by my rules\" above the mail window, or /fgui mailrules send.", 440, 300)
end

------------------------------------------------------------------------------------------
-- Holidays and events: what the game's calendar has on, now and in the next two weeks. A holiday
-- that is on now is added to your checklist as a daily job, and taken off again when it ends.
------------------------------------------------------------------------------------------
local function CalendarEvents(days)
    local C = C_Calendar
    if type(C) ~= "table" or not (C.GetNumDayEvents and C.GetDayEvent) then return nil end
    local out, seen = {}, {}
    local today = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
    local d0 = type(today) == "table" and today.monthDay or tonumber(date("%d"))
    local monthDays = 31
    if C.GetMonthInfo then local ok, m = pcall(C.GetMonthInfo, 0); if ok and type(m) == "table" then monthDays = m.numDays or 31 end end
    for k = 0, days do
        local day, offset = d0 + k, 0
        if day > monthDays then day, offset = day - monthDays, 1 end
        local okN, n = pcall(C.GetNumDayEvents, offset, day)
        for i = 1, (okN and tonumber(n)) or 0 do
            local ok, e = pcall(C.GetDayEvent, offset, day, i)
            if ok and type(e) == "table" and type(e.title) == "string" and (e.calendarType == "HOLIDAY" or e.calendarType == "RAID_LOCKOUT" or e.calendarType == "SYSTEM") then
                if not seen[e.title] then
                    seen[e.title] = true
                    out[#out + 1] = { title = e.title, inDays = k, now = (k == 0), kind = e.calendarType }
                end
            end
        end
    end
    return out
end
ns.CalendarEvents = CalendarEvents
-- Keep the checklist's holiday jobs in step with the holidays that are on now.
function ns.SyncHolidayJobs(store, onNow)
    local want = {}
    for _, title in ipairs(onNow) do want[title] = true end
    for i = #store.items, 1, -1 do
        local item = store.items[i]
        if item.holiday and not want[item.holiday] then table.remove(store.items, i) end
    end
    for _, title in ipairs(onNow) do
        local have = false
        for _, item in ipairs(store.items) do if item.holiday == title then have = true end end
        if not have then
            local item = ns.ChecklistAdd(store, "daily", title)
            if item then item.holiday = title end
        end
    end
end
function ns:ShowEvents()
    if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
    local events = CalendarEvents(14)
    local lines = {}
    if not events then
        lines[1] = { left = ns:Tr("This game client does not tell add-ons about the calendar.") }
    else
        for _, e in ipairs(events) do
            lines[#lines + 1] = { left = (e.now and "|cff33ff66" or "|cffffffff") .. e.title .. "|r",
                right = e.now and ns:Tr("on now") or format(ns:Tr("in %d days"), e.inDays) }
        end
        if #lines == 0 then lines[1] = { left = ns:Tr("Nothing on the calendar for the next two weeks.") } end
    end
    return ns:ShowList("Events", "Events and holidays", lines, "From the game's calendar. Holidays that are on now are on your checklist too.", 420, 320)
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "CALENDAR_UPDATE_EVENT_LIST" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Events and holidays", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            if C_Calendar and C_Calendar.OpenCalendar then ns:After(8, function() pcall(C_Calendar.OpenCalendar) end) end
            return
        end
        if not (ns.db and ns.db.holidayJobs ~= false and ns.ChecklistStore) then return end
        local events = CalendarEvents(0)
        if not events then return end
        local now = {}
        for _, e in ipairs(events) do if e.kind == "HOLIDAY" then now[#now + 1] = e.title end end
        ns.SyncHolidayJobs(ns.ChecklistStore(), now)
    end))
end

------------------------------------------------------------------------------------------
-- Talent builds: save the talents you have under a name, see each build's points, and put one back
-- (as many of its points as you have free). Kept for each character.
--   /fgui talents            the builds          /fgui talents save <name>
------------------------------------------------------------------------------------------
local function TalentAPI()
    return type(GetNumTalentTabs) == "function" and type(GetNumTalents) == "function" and type(GetTalentInfo) == "function"
end
-- The talents you have now: { [tab] = { [index] = rank } }, and points per tab.
local function ReadTalents()
    local build, points = {}, {}
    local okT, tabs = pcall(GetNumTalentTabs)
    for tab = 1, (okT and tonumber(tabs)) or 0 do
        build[tab], points[tab] = {}, 0
        local okN, n = pcall(GetNumTalents, tab)
        for i = 1, (okN and tonumber(n)) or 0 do
            local ok, _, _, _, _, rank = pcall(GetTalentInfo, tab, i)
            rank = ok and tonumber(rank) or 0
            if rank > 0 then build[tab][i] = rank; points[tab] = points[tab] + rank end
        end
    end
    return build, points
end
-- What learning a build needs from where you are: { { tab, index, ranks } } in tier order.
function ns.TalentSteps(want, have)
    local steps = {}
    for tab, list in pairs(want) do
        for index, rank in pairs(list) do
            local now = (have[tab] and have[tab][index]) or 0
            if rank > now then steps[#steps + 1] = { tab = tab, index = index, ranks = rank - now } end
        end
    end
    table.sort(steps, function(a, b) if a.tab ~= b.tab then return a.tab < b.tab end return a.index < b.index end)
    return steps
end
local function Builds()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.talentBuilds) ~= "table" then ns.root.talentBuilds = {} end
    local key = ns:CharKey()
    if type(ns.root.talentBuilds[key]) ~= "table" then ns.root.talentBuilds[key] = {} end
    return ns.root.talentBuilds[key]
end
ns.TalentBuilds, ns.TalentAPI = Builds, TalentAPI
-- Keep the talents you have now as a build. Returns the points per tree, or nil.
function ns:SaveTalentBuild(name)
    name = ns.Trim(name)
    if name == "" or not TalentAPI() then return nil end
    local t, points = ReadTalents()
    Builds()[name:sub(1, 24)] = { talents = t, points = points }
    return points
end
-- A build as text to send: "SHAMAN|Name|1.2.3,1.5.1" (tree.talent.rank), and back.
function ns.EncodeTalentBuild(class, name, talents)
    local parts = {}
    for tab, list in pairs(talents or {}) do
        for index, rank in pairs(list) do parts[#parts + 1] = format("%d.%d.%d", tab, index, rank) end
    end
    table.sort(parts)
    return tostring(class) .. "|" .. tostring(name):gsub("|", "") .. "|" .. table.concat(parts, ",")
end
function ns.DecodeTalentBuild(text)
    local class, name, list = tostring(text or ""):match("^(%u+)|([^|]*)|([%d%.,]*)$")
    if not class then return nil end
    local talents, points = {}, {}
    for t1, i1, r1 in list:gmatch("(%d+)%.(%d+)%.(%d+)") do
        local tab, index, rank = tonumber(t1), tonumber(i1), tonumber(r1)
        if tab <= 5 and index <= 40 and rank <= 5 then
            talents[tab] = talents[tab] or {}
            talents[tab][index] = rank
            points[tab] = (points[tab] or 0) + rank
        end
    end
    for i = 1, #points do points[i] = points[i] or 0 end
    for t = 1, 3 do points[t] = points[t] or 0 end
    return class, name, talents, points
end
function ns:SendTalentBuild(target, name)
    local b = Builds()[name or ""]
    if not b then ns:Print("No talent build called \"%s\". /fgui talents lists yours.", tostring(name)); return false end
    local _, class = UnitClass("player")
    return ns.SendSetup and ns:SendSetup(target, "talents", ns.EncodeTalentBuild(class, name, b.talents))
end
function ns:ReceiveTalentBuild(from, text)
    local class, name, talents, points = ns.DecodeTalentBuild(text)
    if not class then return false end
    local _, mine = UnitClass("player")
    if class ~= mine then
        ns:Print("%s sent you a talent build for another class (%s): it was not kept.", from, (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class]) or class)
        return false
    end
    local key = (name ~= "" and name or ns:Tr("Build")) .. " (" .. from .. ")"
    Builds()[key:sub(1, 40)] = { talents = talents, points = points }
    ns:Print("%s sent you a talent build: \"%s\". It is with your builds (/fgui talents); nothing is learned until you choose it.", from, key)
    return key
end
function ns:ApplyTalentBuild(name)
    if ns:AfterFight("Talent build", function() ns:ApplyTalentBuild(name) end) then return false end
    local b = Builds()[name]
    if not b or not TalentAPI() or type(LearnTalent) ~= "function" then return false end
    local have = ReadTalents()
    local learned = 0
    for _, step in ipairs(ns.TalentSteps(b.talents, have)) do
        for _ = 1, step.ranks do
            if pcall(LearnTalent, step.tab, step.index) then learned = learned + 1 end
        end
    end
    ns:Print("%s: %d points spent. Anything left needs free points (or a talent reset at a trainer).", name, learned)
    return learned
end
function ns:TalentCommand(text)
    text = ns.Trim(text)
    local word, rest = text:match("^(%S+)%s*(.*)$")
    word = word and word:lower()
    if not TalentAPI() then ns:Print("This game client does not let add-ons read talents."); return false end
    local builds = Builds()
    if word == "save" and rest ~= "" then
        local points = ns:SaveTalentBuild(rest)
        if points then ns:Print("Talent build saved: %s (%s).", rest, table.concat(points, "/")) end
    elseif word == "delete" and builds[rest] then
        builds[rest] = nil
    elseif word == "use" and builds[rest] then
        return ns:ApplyTalentBuild(rest)
    elseif word == "send" then
        local who, which = rest:match("^(%S+)%s+(.+)$")
        if not who then ns:Print("/fgui talents send <player> <build name>"); return false end
        return ns:SendTalentBuild(who, which)
    end
    local lines, names = {}, {}
    for name in pairs(builds) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local b = builds[name]
        lines[#lines + 1] = { left = name, right = table.concat(b.points or {}, " / "),
            click = function(button)
                if button == "RightButton" then Builds()[name] = nil; ns:TalentCommand("") else ns:ApplyTalentBuild(name) end
            end, tip = { name, ns:Tr("Click: learn this build's points. Right-click: delete it.") } }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("No builds yet: spend your points, then /fgui talents save <name>.") } end
    return ns:ShowList("Talents", "Talent builds", lines, "Kept for this character. /fgui talents save <name>", 380, 280)
end

------------------------------------------------------------------------------------------
-- The game's raid manager (the panel that slides out from the left edge in a group), hidden when
-- "Hide the game's raid manager" is on: unseen and unclickable, and given back when switched off.
-- (Its group filters only matter to the game's own raid frames; the Raid tools panel has ready
-- checks, markers and role polls, and leaving a group is in the game menu or on your portrait.)
------------------------------------------------------------------------------------------
function ns:ApplyRaidManager()
    local m = _G.CompactRaidFrameManager
    if type(m) ~= "table" then ns.raidManagerState = "not loaded"; return nil end
    if ns.db.hideRaidManager then
        if not m.suiHidden then ns:Silence(m); m.suiHidden = true end
        ns.raidManagerState = "hidden"
        return true
    elseif m.suiHidden then
        ns:Unsilence(m)
        m.suiHidden = nil
    end
    ns.raidManagerState = "shown"
    return false
end
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "GROUP_ROSTER_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Raid manager", function(_, event, name)
        if not ns.db then return end
        if event == "ADDON_LOADED" and name ~= "Blizzard_CompactRaidFrames" then return end
        local m = _G.CompactRaidFrameManager
        if ns.db.hideRaidManager or (type(m) == "table" and m.suiHidden) then ns:ApplyRaidManager() end
    end))
end
