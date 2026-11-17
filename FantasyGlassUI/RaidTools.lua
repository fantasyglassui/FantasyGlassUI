local _, ns = ...

-- A small pull-down for group leaders: ready check, role check, pull countdown, target markers.
--
-- Setting a target marker is something the game no longer lets an add-on do directly: it must come
-- from a "secure" button, one whose action is fixed in advance and carried out by the game itself.
-- So each marker here is such a button, set to run the game's own /tm command.
--
-- Secure buttons bring a rule with them: during combat an add-on may not show, hide or move anything
-- they sit inside. A leader needs this panel in a fight, so the tab that opens it is a secure button
-- too (the game does the opening and closing), and the tab appearing when you join a group and going
-- when you leave is likewise handed to the game.
ns:NewModule("raidTools", function()
    local tab, panel

    local secure = false
    do
        local ok, made = pcall(ns.CreateButton, ns, UIParent, "Raid Tools", 92, 18, nil, "SecureHandlerClickTemplate", "FantasyGlassUIRaidToolsTab")
        if ok and type(made) == "table" and made.SetFrameRef then tab, secure = made, true end
    end
    if not tab then tab = ns:CreateButton(UIParent, "Raid Tools", 92, 18) end
    ns:Font(tab.text, 11)
    tab:SetPoint("TOP", UIParent, "TOP", -330, -3)

    do
        local template = secure and ("SecureHandlerBaseTemplate" .. (ns.template and ("," .. ns.template) or "")) or ns.template
        local ok, made = pcall(CreateFrame, "Frame", "FantasyGlassUIRaidTools", tab, template)
        if not (ok and made) then made = CreateFrame("Frame", "FantasyGlassUIRaidTools", tab, ns.template) end
        panel = made
    end
    panel:SetSize(236, 112)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop(ns.BACKDROP)
    ns:Paint(panel, "SetBackdropColor", "window", 0.96)
    ns:Paint(panel, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(panel)
    panel:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -3)
    panel:Hide()

    if secure then
        tab:RegisterForClicks("AnyUp")
        tab:SetFrameRef("panel", panel)
        tab:SetAttribute("_onclick", [[
            local panel = self:GetFrameRef("panel")
            if panel:IsShown() then panel:Hide() else panel:Show() end
        ]])
    else
        tab:SetScript("OnClick", function()
            if InCombatLockdown() then return end
            if panel:IsShown() then panel:Hide() else panel:Show() end
        end)
    end

    local function Btn(text, w, x, y, fn)
        local b = ns:CreateButton(panel, text, w, 22, fn)
        b:SetPoint("TOPLEFT", x, y)
        return b
    end
    Btn("Ready Check", 106, 10, -12, function() if DoReadyCheck then DoReadyCheck() end end)
    Btn("Role Check", 106, 120, -12, function() if InitiateRolePoll then InitiateRolePoll() end end)
    local reset = ns:CreateButton(panel, "Reset Instances", 236, 20, function() if ns.ResetInstancesNow then ns:ResetInstancesNow() end end)
    reset:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -3)            -- (hangs under the panel, and shows with it)
    ns:ButtonTip(reset, "Reset the dungeons you have been in, so the next run starts fresh. Only the group leader can, and only outside.")
    Btn("Pull in 10", 106, 10, -38, function()
        if C_PartyInfo and C_PartyInfo.DoCountdown then C_PartyInfo.DoCountdown(10) end
    end)
    local convert
    convert = Btn("To Raid", 106, 120, -38, function()
        if not C_PartyInfo then return end
        if IsInRaid() then
            if C_PartyInfo.ConvertToParty then C_PartyInfo.ConvertToParty() end
        elseif C_PartyInfo.ConvertToRaid then
            C_PartyInfo.ConvertToRaid()
        end
    end)

    -- Markers. The top row marks your target (X clears it); each button runs the game's /tm command.
    -- The row under it, where the game has them, is the same eight as markers on the ground: click to
    -- place one where your mouse is next, click again to take it away (X takes them all away).
    local markers = {}
    local function Secure(b, attributes, describe)
        b:RegisterForClicks("AnyUp", "AnyDown")
        for key, value in pairs(attributes) do b:SetAttribute(key, value) end
        b.attributes, b.command = attributes, attributes.macrotext
        markers[#markers + 1] = b
        b:HookScript("OnEnter", function(self)
            local title, line = describe()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(title)
            if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8) end
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    local function MarkName(icon) return (type(_G["RAID_TARGET_" .. icon]) == "string" and _G["RAID_TARGET_" .. icon]) or ("Marker " .. icon) end
    local function Icon(name, x, y, icon, underline)
        local ok, m = pcall(CreateFrame, "Button", name, panel, "SecureActionButtonTemplate")
        if not (ok and m and m.SetAttribute) then return nil end
        m:SetSize(22, 22)
        m:SetPoint("TOPLEFT", x, y)
        local t = m:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. icon)
        local hl = m:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(ns.FLAT)
        hl:SetVertexColor(1, 1, 1, 0.18)
        if underline then                                    -- the ground row is told apart by a line under each
            local line = m:CreateTexture(nil, "OVERLAY")
            line:SetTexture(ns.FLAT)
            line:SetHeight(2)
            line:SetPoint("TOPLEFT", m, "BOTTOMLEFT", 2, -1)
            line:SetPoint("TOPRIGHT", m, "BOTTOMRIGHT", -2, -1)
            ns:Paint(line, "SetVertexColor", "@accent", 0.9)
        end
        return m
    end
    local function Clear(name, y)
        local ok, b = pcall(ns.CreateButton, ns, panel, "X", 22, 22, nil, "SecureActionButtonTemplate", name)
        if not (ok and type(b) == "table" and b.SetAttribute) then return nil end
        b:SetPoint("TOPLEFT", 10 + 8 * 24, y)
        return b
    end

    local made = 0
    for i = 1, 8 do
        local m = Icon("FantasyGlassUIRaidMark" .. i, 10 + (i - 1) * 24, -70, i)
        if m then
            Secure(m, { type = "macro", macrotext = "/tm " .. i }, function() return MarkName(i), ns:Tr("Click: mark your target") end)
            made = made + 1
        end
    end
    do
        local clear = Clear("FantasyGlassUIRaidMarkClear", -70)
        if clear then
            Secure(clear, { type = "macro", macrotext = "/tm 0" }, function() return ns:Tr("Clear your target's marker") end)
            made = made + 1
        end
    end

    -- ground markers: the game numbers them square, triangle, diamond, cross, star, circle, moon, skull
    local GROUND = { 6, 4, 3, 7, 1, 2, 5, 8 }
    ns.raidGroundIcons = GROUND
    local ground = 0
    if type(PlaceRaidMarker) == "function" or type(IsRaidMarkerActive) == "function" or type(ClearRaidMarker) == "function" then
        for i = 1, 8 do
            local m = Icon("FantasyGlassUIGroundMark" .. i, 10 + (i - 1) * 24, -98, GROUND[i], true)
            if m then
                Secure(m, { type = "worldmarker", marker = i, action = "toggle" },
                    function() return MarkName(GROUND[i]), ns:Tr("Click: place it on the ground, or take it away") end)
                ground = ground + 1
            end
        end
        local clear = Clear("FantasyGlassUIGroundMarkClear", -98)
        if clear then
            Secure(clear, { type = "worldmarker", action = "clear" }, function() return ns:Tr("Clear all ground markers") end)
            ground = ground + 1
        end
        if ground > 0 then panel:SetHeight(112 + 28) end
    end
    ns.raidToolsState = (made == 9) and "markers are secure buttons running /tm" .. (secure and "; the tab opens the panel in or out of combat" or "; the panel cannot be opened in combat on this client")
        or "this game client would not make the secure buttons markers need"
    ns.raidToolsState = ns.raidToolsState .. ((ground == 9) and "; ground markers too" or "; no ground markers on this game client")
    ns.raidToolsTest = { tab = tab, panel = panel, markers = markers, secure = secure, ground = ground }

    -- The tab is there while you are in a group. The game shows and hides it (it can in combat; we cannot).
    local driven = false
    if secure and type(RegisterStateDriver) == "function" then
        driven = pcall(RegisterStateDriver, tab, "visibility", "[group] show; hide")
    end
    local function Refresh()
        local grouped = IsInGroup and IsInGroup()
        if grouped then convert.text:SetText((IsInRaid and IsInRaid()) and "To Party" or "To Raid") end
        if driven or ns:Locked(tab) then return end
        if grouped then
            tab:Show()
        else
            tab:Hide()
            panel:Hide()
        end
    end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("GROUP_ROSTER_UPDATE")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Raid tools", Refresh))
    Refresh()

    ns:RegisterMovable(tab, "raidTools", "Raid Tools")
end)
