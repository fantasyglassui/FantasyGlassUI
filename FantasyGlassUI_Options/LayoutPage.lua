-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local O = ns.optUI
local Header = function(...) return O.Header(...) end
local groups = ns.featureGroups   -- luacheck: ignore

-- Page 2: move, preview, scale, sizes ----------------------------------------------------------
local function BuildLayout(page)
    local move = ns:CreateButton(page, "Move panels", 110, 24, function() ns:ToggleMove() end)
    move:SetPoint("TOPLEFT", 0, 0)
    local preview = ns:CreateButton(page, "Preview", 90, 24, function() ns:TogglePreview() end)
    preview:SetPoint("LEFT", move, "RIGHT", 8, 0)
    -- The first click only asks; while it asks, the button is a reload button (ns:ReloadButton), so the
    -- second click clears the positions and the game itself reloads.
    -- (If the reload does not come, it goes back to asking after the same 4 seconds; each ask has its
    -- own turn, so an older ask's timer never cuts a newer one short.)
    local reset, Arm
    local turn = 0
    local function Disarm()
        reset.armed = false
        reset.text:SetText(ns:Tr("Reset positions"))
        ns:ReloadButton(reset, false, Arm)
    end
    Arm = function(self)
        self.armed = true
        turn = turn + 1
        local mine = turn
        self.text:SetText(ns:SignalHex("bad") .. ns:Tr("Click to confirm") .. "|r")
        ns:ReloadButton(self, function() ns:ResetPositions() end)
        ns:After(4, function() if reset.armed and turn == mine then Disarm() end end)
    end
    reset = ns:CreateButton(page, "Reset positions", 130, 24, Arm)
    reset:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
    local roleLayout = ns:CreateButton(page, "Role layout", 110, 24, function() ns:ApplyRoleLayout() end)
    roleLayout:SetPoint("RIGHT", reset, "LEFT", -8, 0)
    -- Share layout: a small panel for exporting / importing just the layout, and per-talent-set layouts
    local share
    local function BuildShare()
        share = CreateFrame("Frame", "FantasyGlassUIShareLayout", O.frame, ns.template)
        share:SetSize(470, 264)
        share:SetPoint("CENTER", O.frame, "CENTER", 0, 40)
        share:SetFrameStrata("DIALOG")
        share:SetBackdrop(ns.BACKDROP)
        ns:Paint(share, "SetBackdropColor", "window", 0.98)
        ns:Paint(share, "SetBackdropBorderColor", "@accent", 1)
        ns:Dress(share)
        share:EnableMouse(true)
        local title = share:CreateFontString(nil, "OVERLAY")
        ns:Font(title, 15, true)
        title:SetPoint("TOPLEFT", 16, -12)
        title:SetText(ns:Tr("Share layout"))
        local close = ns:CreateButton(share, "X", 22, 22, function() share:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        local note = share:CreateFontString(nil, "OVERLAY")
        ns:Font(note, 11)
        note:SetPoint("TOPLEFT", 16, -38)
        note:SetWidth(438)
        note:SetJustifyH("LEFT")
        note:SetText(ns:Tr("A layout is only where panels sit and how big they are. Export gives a text string to copy; to use someone else's, paste it in the box and press Import."))
        ns:Paint(note, "SetTextColor", "dim")
        local box = ns:CreateEditBox(share, 438, 24, "Layout string")
        box:SetPoint("TOPLEFT", 16, -82)
        if box.SetMaxLetters then box:SetMaxLetters(0) end
        local msg = share:CreateFontString(nil, "OVERLAY")
        ns:Font(msg, 11)
        msg:SetPoint("BOTTOMLEFT", 16, 12)
        msg:SetWidth(438)
        msg:SetJustifyH("LEFT")
        local export = ns:CreateButton(share, "Export", 110, 24, function()
            box:SetText(ns:ExportLayout())
            box:SetFocus()
            box:HighlightText()
            msg:SetText(ns:SignalHex("good") .. ns:Tr("Press Ctrl+C to copy.") .. "|r")
        end)
        export:SetPoint("TOPLEFT", 16, -114)
        local import = ns:CreateButton(share, "Import", 110, 24, function()
            local ok, text = ns:ImportLayout(box:GetText())
            msg:SetText((ok and ns:SignalHex("good") or ns:SignalHex("bad")) .. ns:Tr(text) .. "|r")
        end)
        import:SetPoint("LEFT", export, "RIGHT", 8, 0)
        local set, how = ns:TalentSet()   -- luacheck: ignore
        local label = "A separate layout for each talent set"
        -- switching either option on or off changes the context: start the new one from what is on screen
        local function ContextChanged()
            local ctx = ns:LayoutContext()
            ns.db.layoutCtx = ctx
            if ctx then ns.db.layouts[ctx] = ns:LayoutSnapshot() end
        end
        local per = ns:CreateCheckbox(share, label, ns.db.specLayouts, function(v) ns.db.specLayouts = v; ContextChanged() end)
        per:SetWidth(438)
        per:SetPoint("TOPLEFT", 16, -148)
        local group = ns:CreateCheckbox(share, "A separate layout for solo, party and raid", ns.db.groupLayouts, function(v)
            ns.db.groupLayouts = v
            ContextChanged()
        end)
        group:SetWidth(438)
        group:SetPoint("TOPLEFT", 16, -172)
        local screen = ns:CreateCheckbox(share, "A separate layout for each screen size", ns.db.screenLayouts, function(v)
            ns.db.screenLayouts = v
            ContextChanged()
        end)
        screen:SetWidth(438)
        screen:SetPoint("TOPLEFT", 16, -196)
        share.screenBox = screen
        if how == "none" then
            msg:SetText("|cffffd100" .. ns:Tr("This client doesn't report a talent set, so that option has nothing to switch on.") .. "|r")
        end
    end
    local shareBtn = ns:CreateButton(page, "Share layout", 110, 24, function()
        if not share then BuildShare() end
        if share:IsShown() then share:Hide() else share:Show() end
    end)
    shareBtn:SetPoint("LEFT", preview, "RIGHT", 8, 0)
    local galleryBtn = ns:CreateButton(page, "Layout gallery", 110, 24, function() if ns.ShowGallery then ns:ShowGallery() end end)
    galleryBtn:SetPoint("LEFT", shareBtn, "RIGHT", 8, 0)
    page.topButtons = { move, preview, shareBtn, galleryBtn, roleLayout, reset }
    page.galleryButton = galleryBtn

    -- One scale slider per panel. Frames that are sized together share one (the party frames, the boss
    -- frames), and the action bars are left out: they are all sized by "Action bar size %" below.
    Header(page, "Panel scale", 0, -38)
    local groups, order = {}, {}
    for _, m in ipairs(ns.movables) do
        if not m.noScale and not m.offPage then                -- (the smaller tools are scaled from their own right-click menu)
            local label = m.key:find("^ufParty") and "Party frames" or m.key:find("^ufBoss") and "Boss frames" or m.key:find("^ufArena") and "Arena enemy frames" or m.label
            if not groups[label] then groups[label] = {}; order[#order + 1] = label end
            table.insert(groups[label], m.key)
        end
    end
    -- The page has room for about thirteen rows of sliders in all. If panels are ever added past that,
    -- the rows are packed a little closer rather than running into the buttons at the bottom.
    local scaleRows = math.ceil(#order / 4)
    local PITCH = 36
    page.scaleSliders, page.rowPitch = #order, PITCH
    for i, label in ipairs(order) do
        local keys = groups[label]
        local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
        local s = ns:CreateSlider(page, label, 0.6, 1.6, 0.05, ns.db.scale[keys[1]] or 1, "%.2f", function(v)
            ns:SetPanelScale(keys, v)
        end, 170)
        s:SetPoint("TOPLEFT", col * 187, -58 - row * PITCH)
    end

    -- (12.0: the sizes that were here are with what they size: the frames, the bars, chat, the info
    -- bar, the windows, and Accessibility: see Categories.lua)
    page.bottom = -58 - scaleRows * PITCH - 6
    local windowsBtn = ns:CreateButton(page, "Reset window positions", 200, 24, ns:ConfirmClick(function() ns:ResetWindowPositions() end))
    windowsBtn:SetPoint("TOPLEFT", 0, page.bottom - 4)
    O.Tip(windowsBtn, "Reset window positions", "Puts the game's windows you have dragged back where the game puts them.")
    page.bottom = page.bottom - 34
    -- The tab scrolls if it has to: the list of panels grows with every feature that adds one.
    page.contentHeight = -page.bottom + 10
    if page.area then page.area:SetContentHeight(page.contentHeight) end
    ns.layoutPage = page
end

-- Page 3: profiles ---------------------------------------------------------------------------------
local function BuildProfiles(page)
    local active = page:CreateFontString(nil, "OVERLAY")
    ns:Font(active, 13)
    active:SetPoint("TOPLEFT", 0, 0)

    local msg = page:CreateFontString(nil, "OVERLAY")
    ns:Font(msg, 12)
    msg:SetPoint("BOTTOMLEFT", 0, 0)
    msg:SetTextColor(1, 0.82, 0)
    local function Say(ok, text) msg:SetText((ok and ns:SignalHex("good") or ns:SignalHex("bad")) .. ns:Tr(tostring(text or "")) .. "|r") end     -- (what the profile functions say, in your language)

    local rows = {}
    local MAX = 8
    local function Refresh()
        active:SetText(ns:Tr("Active profile:") .. " " .. ns:AccentHex() .. ns.profile .. "|r    |cff9c8c6c" .. ns:Tr("each character remembers its own choice") .. "|r")
        local names = ns:ProfileList()
        for i = 1, MAX do
            local r = rows[i]
            if not r then
                r = CreateFrame("Frame", nil, page)
                r:SetSize(520, 24)
                r:SetPoint("TOPLEFT", 0, -28 - (i - 1) * 26)
                r.name = r:CreateFontString(nil, "OVERLAY")
                ns:Font(r.name, 12)
                r.name:SetPoint("LEFT", 4, 0)
                r.use = ns:CreateButton(r, "Use", 70, 22)
                ns:ReloadButton(r.use, function() return (ns:UseProfile(r.profile)) end)
                r.use:SetPoint("LEFT", 260, 0)
                ns:ButtonTip(r.use, "Switch to this profile.")
                r.del = ns:CreateButton(r, "Delete", 70, 22, ns:ConfirmClick(function()
                    Say(ns:DeleteProfile(r.profile))
                    O.pages.profiles.Refresh()
                end))
                r.del:SetPoint("LEFT", r.use, "RIGHT", 8, 0)
                rows[i] = r
            end
            local name = names[i]
            if name then
                r.profile = name
                local mine = (name == ns.profile)
                r.name:SetText(name .. (mine and ("   " .. ns:SignalHex("good") .. ns:Tr("in use") .. "|r") or ""))
                if mine then r.use:Hide() else r.use:Show() end
                if mine or name == "Default" then r.del:Hide() else r.del:Show() end
                r:Show()
            else
                r:Hide()
            end
        end
        if #names > MAX then Say(true, format(ns:Tr("%d more profiles are not listed."), #names - MAX)) end
    end
    page.Refresh = Refresh

    local y = -28 - MAX * 26 - 12
    Header(page, "New profile", 0, y)
    local newName = ns:CreateEditBox(page, 200, 22, "Name")
    newName:SetPoint("TOPLEFT", 0, y - 20)
    local create = ns:CreateButton(page, "Create copy of current", 170, 22, function()
        Say(ns:NewProfile(newName:GetText()))
        newName:SetText("")
        Refresh()
    end)
    create:SetPoint("LEFT", newName, "RIGHT", 10, 0)
    newName:SetScript("OnEnterPressed", function(self)            -- (Enter makes it, like the button)
        self:ClearFocus()
        if ns.Trim(self:GetText() or "") ~= "" then create:Click() end
    end)
    -- or a ready-made one for a role (Safety.lua)
    local prevT = create
    page.templates = {}
    for _, role in ipairs({ "TANK", "HEALER", "DAMAGE" }) do
        local t = ns.ROLE_TEMPLATES and ns.ROLE_TEMPLATES[role]
        if t then
            local b = ns:CreateButton(page, t.label, 84, 22, function()
                local ok, text = ns:NewTemplateProfile(role)
                Say(ok, text)
                Refresh()
            end)
            b:SetPoint("LEFT", prevT, "RIGHT", 8, 0)
            b:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine(format(ns:Tr("A new profile from the %s template"), ns:Tr(t.label)))
                GameTooltip:AddLine(ns:Tr("Your look is kept; the frames are placed for the role and the switches that suit it are on."), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            b:HookScript("OnLeave", function() GameTooltip:Hide() end)
            page.templates[role] = b
            prevT = b
        end
    end

    Header(page, "Share", 0, y - 56)
    local export = ns:CreateButton(page, "Export current profile", 170, 22, function()
        ns:ShowCopyBox(ns:ExportProfile(), "Profile string: press Ctrl+C to copy, Esc to close")
    end)
    export:SetPoint("TOPLEFT", 0, y - 76)

    local impName = ns:CreateEditBox(page, 200, 22, "Name for imported profile")
    impName:SetPoint("TOPLEFT", 0, y - 108)
    local impText = ns:CreateEditBox(page, 330, 22, "Paste a profile string here")
    impText:SetPoint("LEFT", impName, "RIGHT", 10, 0)
    if impText.SetMaxLetters then impText:SetMaxLetters(0) end
    local import = ns:CreateButton(page, "Import", 90, 22, function()
        local ok, text = ns:ImportProfile(impName:GetText(), impText:GetText())
        Say(ok, text)
        if ok then impName:SetText(""); impText:SetText("") end
        Refresh()
    end)
    import:SetPoint("LEFT", impText, "RIGHT", 10, 0)
    local peek = ns:CreateButton(page, "Preview a shared string", 170, 22, function()
        if ns.HideConfig then ns.HideConfig() end
        local text = impText:GetText()
        if type(text) == "string" and text ~= "" and ns.PreviewShared then ns:PreviewShared(text) elseif ns.ShowSharePreview then ns:ShowSharePreview() end
    end)
    peek:SetPoint("LEFT", export, "RIGHT", 10, 0)
    local packBtn = ns:CreateButton(page, "Copy my whole UI", 170, 22, function()
        ns:ShowCopyBox(ns:ExportPack(), ns:Tr("Your whole UI in one string: Ctrl+C to copy. Anyone with Fantasy Glass UI can paste it in Profiles, Preview a shared string."))
    end)
    packBtn:SetPoint("LEFT", peek, "RIGHT", 10, 0)
    page.packButton = packBtn
    O.Tip(packBtn, "Copy my whole UI", "One line of text with your profile, layout, theme, bars and rules. Anyone with Fantasy Glass UI can paste it in Preview a shared string.")
    -- send straight to another player who has the add-on
    local sendTo = ns:CreateEditBox(page, 200, 22, "a player's name")
    sendTo:SetPoint("TOPLEFT", 0, y - 142)
    local function SendKind(kind)
        local who = strtrim(sendTo:GetText() or "")
        if who == "" then Say(false, ns:Tr("Type who to send it to first.")); return end
        if ns.SendSetup and ns:SendSetup(who, kind) then Say(true, format(ns:Tr("Sending to %s. They choose whether to take it."), who)) end
    end
    local sendLayout = ns:CreateButton(page, "Send my layout", 130, 22, function() SendKind("layout") end)
    sendLayout:SetPoint("LEFT", sendTo, "RIGHT", 10, 0)
    local sendProfile = ns:CreateButton(page, "Send my profile", 130, 22, function() SendKind("profile") end)
    sendProfile:SetPoint("LEFT", sendLayout, "RIGHT", 8, 0)
    local sendTheme = ns:CreateButton(page, "Send my theme", 120, 22, function() SendKind("theme") end)
    sendTheme:SetPoint("LEFT", sendProfile, "RIGHT", 8, 0)
    local sendPack = ns:CreateButton(page, "Send whole UI", 120, 22, function() SendKind("pack") end)
    sendPack:SetPoint("LEFT", sendTheme, "RIGHT", 8, 0)
    O.Tip(sendPack, "Send whole UI", "Sends your whole UI to the player named in the box. They see a preview and choose whether to take it.")
    page.sendBox = sendTo
    -- new characters: their own copy of your main's setup (AltSetup.lua)
    Header(page, "New characters", 0, y - 178)
    local copyBox = ns:CreateCheckbox(page, "New characters copy my main's setup", ns.root.altCopy ~= false, function(on)
        ns.root.altCopy = (not on) and false or nil
    end)
    copyBox:SetPoint("TOPLEFT", 0, y - 198)
    local mainBtn = ns:CreateButton(page, "Make this character my main", 210, 22, function()
        ns:MainCommand("")
        Say(true, format(ns:Tr("%s is your main."), ns:CharKey()))
    end)
    mainBtn:SetPoint("TOPLEFT", 300, y - 198)
    page.altCopy, page.mainButton = copyBox, mainBtn
    O.Tip(copyBox, "New characters copy my main's setup", "A character you have never played before gets its own profile, copied from your main and fitted to its class. Off: new characters share the Default profile.")
    O.Tip(mainBtn, "Make this character my main", "New characters copy this one's setup. Without a main, they copy the character you played last.")
    -- backups and what changed (Safety.lua)
    local backups = ns:CreateButton(page, "Backups", 120, 22, function() if ns.HideConfig then ns.HideConfig() end; ns:BackupCommand("") end)
    backups:SetPoint("TOPLEFT", 0, y - 232)
    local history = ns:CreateButton(page, "Changes to this profile", 190, 22, function() if ns.HideConfig then ns.HideConfig() end; ns:ShowSettingHistory() end)
    history:SetPoint("LEFT", backups, "RIGHT", 8, 0)
    local dataButton = ns:CreateButton(page, "Saved data", 120, 22, function() if ns.HideConfig then ns.HideConfig() end; ns:DataCommand("") end)
    dataButton:SetPoint("LEFT", history, "RIGHT", 8, 0)
    page.backupButton, page.historyButton, page.dataButton = backups, history, dataButton
    O.Tip(backups, "Backups", "Your settings are copied before each update and at your first login each day. Pick one to see how to put it back.")
    O.Tip(history, "Changes to this profile", "What you changed and when, newest first. Click one to undo it.")
    O.Tip(dataButton, "Saved data", "What each part of the add-on keeps, and a tidy-up that asks before it removes anything.")
end
O.BuildLayout, O.BuildProfiles = BuildLayout, BuildProfiles
