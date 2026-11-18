local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

local CELL_W, CELL_H, GAP = 78, 38, 4
local cells = {}
ns.raidCellList = cells                                      -- (for buff coverage marks)

-- Raid frame designer (11.0.1): from the Bars and frames tab. Size is raidW and raidH (Layout tab too);
-- the rest is ns.db.raidDesign. Where the game's own raid frames are used (clients that hide auras in a
-- fight), what can be changed is their lettering and the game's own raid frame settings.
ns.RAID_DEFAULT = { nameSize = 11, statusSize = 10, gap = 4, perColumn = 5, horizontal = false }
function ns.RaidDesign()
    local d = type(ns.db and ns.db.raidDesign) == "table" and ns.db.raidDesign or {}
    local out = {}
    for k, v in pairs(ns.RAID_DEFAULT) do if d[k] == nil then out[k] = v else out[k] = d[k] end end
    out.nameSize = math.max(7, math.min(16, tonumber(out.nameSize) or 11))
    out.statusSize = math.max(7, math.min(14, tonumber(out.statusSize) or 10))
    out.gap = math.max(0, math.min(12, tonumber(out.gap) or 4))
    out.perColumn = math.max(1, math.min(10, tonumber(out.perColumn) or 5))
    out.horizontal = out.horizontal and true or false
    return out
end
-- How the group header lays the cells out: { point, xOffset, yOffset, columnAnchorPoint, maxColumns }.
function ns.RaidGrid(d)
    if d.horizontal then
        return { point = "LEFT", xOffset = d.gap, yOffset = 0, columnAnchorPoint = "TOP", columnSpacing = d.gap, unitsPerColumn = d.perColumn, maxColumns = math.ceil(40 / d.perColumn) }
    end
    return { point = "TOP", xOffset = 0, yOffset = -d.gap, columnAnchorPoint = "LEFT", columnSpacing = d.gap, unitsPerColumn = d.perColumn, maxColumns = math.ceil(40 / d.perColumn) }
end
-- The game's own raid frame settings the designer offers (they are the game's: the game keeps them).
ns.RAID_CVARS = {
    { key = "raidFramesDisplayPowerBars", label = "Power bars" },
    { key = "raidFramesDisplayClassColor", label = "Class colors" },
    { key = "raidOptionDisplayPets", label = "Pets" },
    { key = "raidFramesDisplayOnlyDispellableDebuffs", label = "Only debuffs I can remove" },
    { key = "raidFramesDisplayAggroHighlight", label = "Aggro highlight" },
}
ns.RAID_HEALTH_TEXT = { { "none", "None" }, { "health", "Health" }, { "losthealth", "Health lost" }, { "perc", "Percent" } }
local function CVarGet(name)
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, v = pcall(get, name)
    return ok and v or nil
end
function ns:RaidGameSetting(name, value)
    if value == nil then return CVarGet(name) end
    if InCombatLockdown() then return false end
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    local ok = pcall(set, name, tostring(value))
    if CompactUnitFrameProfiles_ApplyCurrentSettings then pcall(CompactUnitFrameProfiles_ApplyCurrentSettings) end
    if CompactRaidFrameContainer and CompactRaidFrameContainer.TryUpdate then pcall(CompactRaidFrameContainer.TryUpdate, CompactRaidFrameContainer) end
    return ok
end

local READY = {
    ready    = "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting  = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

-- The role mark on a cell: the first letter of the game's own word for the role, in your language
-- (T and H in English; one whole letter, also where a letter takes several bytes).
function ns.RoleLetter(role)
    local word = (role == "TANK" and _G.TANK) or (role == "HEALER" and _G.HEALER) or nil
    if type(word) ~= "string" or word == "" then return role == "TANK" and "T" or "H" end
    return word:match("^[%z\1-\127\194-\244][\128-\191]*") or word:sub(1, 1)
end

local function UpdateHealth(b)
    local u = b.unit
    pcall(function()
        b.health:SetMinMaxValues(0, UnitHealthMax(u))
        ns:SetBar(b.health, UnitHealth(u))
    end)
    local ok, state = pcall(function()
        if not UnitIsConnected(u) then return ns.OfflineWord() end
        if UnitIsDeadOrGhost(u) then return ns.DeadWord() end
    end)
    b.status:SetText((ok and state) or "")
end

-- Heals on their way: a paler bar that begins exactly where the health fill ends. Both bars use the
-- same width and maximum, so the game draws the right length without us doing any arithmetic.
local function UpdateIncoming(b)
    if not b.incoming then return end
    local u = b.unit
    local inc = UnitGetIncomingHeals and UnitGetIncomingHeals(u)
    pcall(function()
        b.incoming:SetMinMaxValues(0, UnitHealthMax(u))
        if Secret(inc) or inc ~= nil then b.incoming:SetValue(inc) else b.incoming:SetValue(0) end
    end)
end


local function UpdatePower(b)
    local u = b.unit
    local ptype, token = UnitPowerType(u)
    local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])
    if c and c.r then b.power:SetStatusBarColor(c.r, c.g, c.b) else b.power:SetStatusBarColor(0.25, 0.5, 1) end
    pcall(function()
        b.power:SetMinMaxValues(0, UnitPowerMax(u))
        ns:SetBar(b.power, UnitPower(u))
    end)
end

local function UpdateInfo(b)
    local u = b.unit
    local r, g, bl = ns:ClassColor(u)
    b.health:SetStatusBarColor(r or 0.3, g or 0.75, bl or 0.35)
    b.name:SetText(UnitName(u) or "")
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(u)
    if role == "TANK" then b.role:SetText("|cff4d99ff" .. ns.RoleLetter("TANK") .. "|r")
    elseif role == "HEALER" then b.role:SetText("|cff4dff80" .. ns.RoleLetter("HEALER") .. "|r")
    else b.role:SetText("") end
    if UnitIsGroupLeader and UnitIsGroupLeader(u) then b.leader:Show() else b.leader:Hide() end
    local idx = GetRaidTargetIndex and GetRaidTargetIndex(u)
    if not Secret(idx) and idx and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(b.raidIcon, idx)
        b.raidIcon:Show()
    else
        b.raidIcon:Hide()
    end
end

local function UpdateDebuffs(b)
    local get = ns.GetAura
    if not get then return end
    local d = ns.AuraDesign and ns.AuraDesign("raid") or { hots = 3, debuff = true, dispel = true }
    local a = d.debuff and get(b.unit, 1, "HARMFUL") or nil
    if a and ns.AuraBlocked and ns.AuraBlocked(a.name) then a = get(b.unit, 2, "HARMFUL") end
    if a then
        pcall(b.debuff.icon.SetTexture, b.debuff.icon, a.icon)
        if b.debuff.suiBorder and ns.DebuffColor then b.debuff.suiBorder:SetBackdropBorderColor(ns:DebuffColor(a.dispelName)) end
        b.debuff:Show()
    else
        b.debuff:Hide()
    end
    -- something on them that you can remove: light the whole cell up
    if d.dispel and get(b.unit, 1, "HARMFUL|RAID") then
        b.dispel:Show()
        if ns.db.colorblind then b.dispelMark:Show() else b.dispelMark:Hide() end      -- "!" as well as the outline
    else
        b.dispel:Hide()
        b.dispelMark:Hide()
    end

    -- your own heal-over-time effects (and any other buff you put on them), up to three
    local n = 0
    for i = 1, 12 do
        if n >= math.min(#b.hots, d.hots) then break end
        local h = get(b.unit, i, "HELPFUL|PLAYER")
        if not h then break end
        n = n + 1
        local icon = b.hots[n]
        pcall(icon.tex.SetTexture, icon.tex, h.icon)
        if icon.cd then
            local shown = false
            if icon.cd.SetCooldownFromExpirationTime then
                shown = pcall(icon.cd.SetCooldownFromExpirationTime, icon.cd, h.expirationTime, h.duration)
            end
            if not shown then shown = pcall(function() icon.cd:SetCooldown(h.expirationTime - h.duration, h.duration) end) end
            if shown then icon.cd:Show() else icon.cd:Hide() end
        end
        icon:Show()
    end
    for i = n + 1, #b.hots do b.hots[i]:Hide() end
end

ns:OnAurasBack(function()
    for _, b in ipairs(cells) do
        if b.unit and not b.suiSample then pcall(UpdateDebuffs, b) end
    end
end)
function ns:RefreshRaidAuras()
    for _, b in ipairs(cells) do
        if b.unit and not b.suiSample then pcall(UpdateDebuffs, b) end
    end
end

local function UpdateReady(b)
    local s = GetReadyCheckStatus and GetReadyCheckStatus(b.unit)
    if s and READY[s] then
        b.ready:SetTexture(READY[s])
        b.ready:Show()
    else
        b.ready:Hide()
    end
end

local function UpdateRange(b)
    local u = b.unit
    if not u then return end
    local inRange, checked = UnitInRange(u)
    if not Secret(inRange) and not Secret(checked) then
        b:SetAlpha((checked and not inRange) and 0.45 or 1)
    elseif b.SetAlphaFromBoolean then
        if not pcall(b.SetAlphaFromBoolean, b, inRange, 1, 0.45) then b:SetAlpha(1) end
    else
        b:SetAlpha(1)
    end
end

local function UpdateAll(b)
    if not b.unit or not UnitExists(b.unit) then return end
    pcall(UpdateHealth, b)
    pcall(UpdateIncoming, b)
    pcall(UpdatePower, b)
    pcall(UpdateInfo, b)
    pcall(UpdateDebuffs, b)
    pcall(UpdateReady, b)
    pcall(UpdateRange, b)
end

local UNIT_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_CONNECTION", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER",
                      "UNIT_DISPLAYPOWER", "UNIT_NAME_UPDATE", "UNIT_AURA", "UNIT_HEAL_PREDICTION" }

local function SetUnit(b, unit)
    b.unit = unit
    b:UnregisterAllEvents()
    if type(unit) ~= "string" then return end
    for _, e in ipairs(UNIT_EVENTS) do pcall(b.RegisterUnitEvent, b, e, unit) end
    for _, e in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
                         "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED" }) do
        pcall(b.RegisterEvent, b, e)
    end
    UpdateAll(b)
end

local function OnEvent(self, event)
    if not self.unit then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then UpdateHealth(self); UpdateIncoming(self)
    elseif event == "UNIT_HEAL_PREDICTION" then UpdateIncoming(self)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then UpdatePower(self)
    elseif event == "UNIT_AURA" then UpdateDebuffs(self)
    elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" then
        if event == "READY_CHECK" then self.readyRound = (self.readyRound or 0) + 1 end
        UpdateReady(self)
    elseif event == "READY_CHECK_FINISHED" then
        UpdateReady(self)
        self.readyRound = (self.readyRound or 0) + 1
        local round = self.readyRound
        ns:After(6, function() if self.readyRound == round then self.ready:Hide() end end)      -- (unless a new check has begun)
    else UpdateInfo(self) end
end

-- Dress one raid cell. The secure group header creates the buttons; we only draw on them.
function ns.RaidStyle(b)
    if type(b) ~= "table" or b.suiStyled then return end
    b.suiStyled = true
    pcall(b.RegisterForClicks, b, "AnyUp")

    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetTexture(ns.FLAT)
    ns:Paint(b.bg, "SetVertexColor", "bg4", 0.92)
    ns:AddBorder(b, 0, 0, 0, 1)

    b.health = ns:NewStatusBar(b)
    b.health:SetPoint("TOPLEFT", 1, -1)
    b.health:SetPoint("BOTTOMRIGHT", -1, 5)
    local okInc, inc = pcall(CreateFrame, "StatusBar", nil, b.health)
    if okInc and inc then
        inc:SetStatusBarTexture(ns.BAR or ns.FLAT)
        inc:SetStatusBarColor(0.45, 1, 0.60, 0.55)
        inc:SetMinMaxValues(0, 1)
        inc:SetValue(0)
        inc:SetPoint("TOPLEFT", b.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
        inc:SetPoint("BOTTOMLEFT", b.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
        inc:SetWidth(CELL_W - 2)
        if b.health.SetClipsChildren then b.health:SetClipsChildren(true) end       -- overheal stops at the cell's edge
        b.incoming = inc
    end

    b.power = ns:NewStatusBar(b)
    b.power:SetPoint("BOTTOMLEFT", 1, 1)
    b.power:SetPoint("BOTTOMRIGHT", -1, 1)
    b.power:SetHeight(3)

    local layer = CreateFrame("Frame", nil, b)
    layer:SetAllPoints()
    layer:SetFrameLevel(b:GetFrameLevel() + 6)

    b.name = ns:NewText(layer, ns.RaidDesign().nameSize, "CENTER")
    b.name:SetPoint("LEFT", 3, 4)
    b.name:SetPoint("RIGHT", -3, 4)
    b.status = ns:NewText(layer, ns.RaidDesign().statusSize, "CENTER")
    b.status:SetPoint("TOP", b.name, "BOTTOM", 0, -1)
    ns:Paint(b.status, "SetTextColor", "text")
    b.role = ns:NewText(layer, 9, "LEFT")
    b.role:SetPoint("TOPLEFT", 3, -2)

    b.leader = layer:CreateTexture(nil, "OVERLAY")
    b.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    b.leader:SetSize(10, 10)
    b.leader:SetPoint("CENTER", b, "TOPLEFT", 4, 0)
    b.leader:Hide()

    b.raidIcon = layer:CreateTexture(nil, "OVERLAY")
    b.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    b.raidIcon:SetSize(12, 12)
    b.raidIcon:SetPoint("TOPRIGHT", -2, -2)
    b.raidIcon:Hide()

    b.ready = layer:CreateTexture(nil, "OVERLAY")
    b.ready:SetSize(16, 16)
    b.ready:SetPoint("CENTER", 0, 0)
    b.ready:Hide()

    b.debuff = CreateFrame("Frame", nil, layer)
    b.debuff:SetSize(13, 13)
    b.debuff:SetPoint("BOTTOMRIGHT", -2, 6)
    b.debuff.icon = b.debuff:CreateTexture(nil, "ARTWORK")
    b.debuff.icon:SetAllPoints()
    b.debuff.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ns:AddBorder(b.debuff, 0.85, 0.18, 0.18, 1)
    b.debuff:Hide()

    b.hots = {}
    for i = 1, 3 do
        local h = CreateFrame("Frame", nil, layer)
        h:SetSize(11, 11)
        h:SetPoint("BOTTOMLEFT", 2 + (i - 1) * 13, 6)
        h.tex = h:CreateTexture(nil, "ARTWORK")
        h.tex:SetAllPoints()
        h.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local okCd, cd = pcall(CreateFrame, "Cooldown", nil, h, "CooldownFrameTemplate")
        if okCd and cd then
            cd:SetAllPoints()
            if cd.SetReverse then cd:SetReverse(true) end
            if cd.SetDrawEdge then cd:SetDrawEdge(false) end
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
            h.cd = cd
        end
        h:Hide()
        b.hots[i] = h
    end

    b.dispelMark = ns:NewText(layer, 14, "CENTER")
    b.dispelMark:SetPoint("TOP", 0, -1)
    b.dispelMark:SetText("!")
    b.dispelMark:SetTextColor(1, 0.9, 0.2)
    b.dispelMark:Hide()

    b.dispel = CreateFrame("Frame", nil, layer, ns.template)
    b.dispel:SetAllPoints()
    b.dispel:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 2 })
    b.dispel:SetBackdropBorderColor(0.8, 0.35, 1, 1)
    b.dispel:Hide()

    b:SetScript("OnEnter", function(self)
        if not self.unit then return end
        if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self)
        else GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT") end
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnEvent", ns:Guard("Raid frames", OnEvent))
    b:SetScript("OnShow", ns:Guard("Raid frames", UpdateAll))
    -- the header moves players between cells by changing this attribute
    b:HookScript("OnAttributeChanged", ns:Guard("Raid frames", function(self, key, value)
        if key == "unit" then SetUnit(self, value) end
    end))

    cells[#cells + 1] = b
    if b.SetAttribute and ns.RegisterClickCast then ns:RegisterClickCast(b) end
    SetUnit(b, b:GetAttribute("unit"))
end

-- The game's own raid frames, restyled. Used on clients that hide buffs and debuffs from add-ons in
-- combat: Blizzard's frames are allowed to show debuffs, dispels, heal-over-time effects and incoming
-- heals during a fight, and ours are not. We only change how they look (bar texture, backdrop,
-- lettering, icon crops); the game keeps doing all the updating. Nothing is written onto the frames.
local function RestyleBlizzardRaid()
    local done = setmetatable({}, { __mode = "k" })
    local EDGES = { "horizDivider", "horizTopBorder", "horizBottomBorder", "vertLeftBorder", "vertRightBorder" }
    local function IsTexture(o) return type(o) == "table" and o.GetObjectType and o:GetObjectType() == "Texture" end

    local function Style(f)
        if type(f) ~= "table" or (f.IsForbidden and f:IsForbidden()) then return end
        local hb = f.healthBar
        if type(hb) ~= "table" or not hb.SetStatusBarTexture then return end
        -- the game puts its own textures back whenever it re-lays the frames out, so these repeat
        pcall(hb.SetStatusBarTexture, hb, ns.BAR or ns.FLAT)
        if type(f.powerBar) == "table" and f.powerBar.SetStatusBarTexture then pcall(f.powerBar.SetStatusBarTexture, f.powerBar, ns.BAR or ns.FLAT) end
        if IsTexture(f.background) and f.background.SetColorTexture then
            local r, g, b = ns:T("bg")
            pcall(f.background.SetColorTexture, f.background, r, g, b, 0.9)
        end
        if not done[f] then
            done[f] = true
            for _, k in ipairs(EDGES) do
                if IsTexture(f[k]) and f[k].SetColorTexture then pcall(f[k].SetColorTexture, f[k], 0, 0, 0, 1) end
            end
            local rd = ns.RaidDesign()
            if type(f.name) == "table" then ns:Font(f.name, rd.nameSize) end
            if type(f.statusText) == "table" then ns:Font(f.statusText, rd.statusSize) end
        end
        for _, list in ipairs({ f.buffFrames, f.debuffFrames }) do          -- not the dispel icons: those are cut from a sheet
            if type(list) == "table" then
                for _, a in ipairs(list) do
                    if type(a) == "table" and not done[a] and IsTexture(a.icon) then
                        done[a] = true
                        a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    end
                end
            end
        end
    end

    function ns:RestyleRaidLettering()                        -- the designer changed the sizes: once more, every frame
        for f in pairs(done) do
            if type(f) == "table" and f.healthBar then
                local rd = ns.RaidDesign()
                if type(f.name) == "table" then pcall(ns.Font, ns, f.name, rd.nameSize) end
                if type(f.statusText) == "table" then pcall(ns.Font, ns, f.statusText, rd.statusSize) end
            end
        end
    end
    local members, borders = {}, { "CompactPartyFrameBorderFrame" }          -- every name, written out once
    for i = 1, 40 do members[#members + 1] = "CompactRaidFrame" .. i end
    for g = 1, 8 do
        for m = 1, 5 do members[#members + 1] = "CompactRaidGroup" .. g .. "Member" .. m end
        borders[#borders + 1] = "CompactRaidGroup" .. g .. "BorderFrame"
    end
    for m = 1, 5 do members[#members + 1] = "CompactPartyFrameMember" .. m end

    ns:Every(1, "Raid frames", function()
        if not (IsInGroup and IsInGroup()) then return end                   -- nothing to restyle when alone
        for i = 1, #members do
            local f = _G[members[i]]
            if f then pcall(Style, f) end
        end
        for i = 1, #borders do
            local border = _G[borders[i]]
            if type(border) == "table" and not done[border] then done[border] = true; border:SetAlpha(0) end
        end
    end)
end

ns:NewModule("raidFrames", function()
    if ns.aurasLocked then                              -- see the note above
        ns.raidMode = "game"
        RestyleBlizzardRaid()
        function ns:ApplyRaidDesign() if ns.RestyleRaidLettering then ns:RestyleRaidLettering() end; return true end
        return
    end
    ns.raidMode = "ours"
    CELL_W, CELL_H = ns.db.raidW, ns.db.raidH
    -- plain anchor we can drag and scale; the secure header hangs off it
    local anchor = CreateFrame("Frame", "FantasyGlassUIRaidAnchor", UIParent)
    anchor:SetSize((CELL_W + GAP) * 8, (CELL_H + GAP) * 5)
    anchor:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 20, -160)

    local header = CreateFrame("Frame", "FantasyGlassUIRaid", anchor, "SecureGroupHeaderTemplate")
    header:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    function header:InitChild(name)
        local b = _G[name]
        if b then ns.RaidStyle(b) end
    end
    header:SetAttribute("template", "SecureUnitButtonTemplate")
    header:SetAttribute("cellWidth", CELL_W)
    header:SetAttribute("cellHeight", CELL_H)
    header:SetAttribute("initialConfigFunction", [[
        local header = self:GetParent()
        self:SetWidth(header:GetAttribute("cellWidth"))
        self:SetHeight(header:GetAttribute("cellHeight"))
        self:SetAttribute("*type1", "target")
        self:SetAttribute("*type2", "togglemenu")
        -- click-cast bindings, for cells the game creates in the middle of a fight
        local n = header:GetAttribute("ccCount") or 0
        for i = 1, n do
            self:SetAttribute(header:GetAttribute("ccTypeKey" .. i), "spell")
            self:SetAttribute(header:GetAttribute("ccSpellKey" .. i), header:GetAttribute("ccSpell" .. i))
        end
        header:CallMethod("InitChild", self:GetName())
    ]])
    ns.raidHeader = header
    if ns.ApplyClickCast then ns:ApplyClickCast() end
    -- one column per raid group, five players down each
    header:SetAttribute("showRaid", true)
    header:SetAttribute("showParty", false)
    header:SetAttribute("showSolo", false)
    header:SetAttribute("groupBy", "GROUP")
    header:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
    header:SetAttribute("sortMethod", "INDEX")
    local function Grid()
        local g = ns.RaidGrid(ns.RaidDesign())
        for k, v in pairs(g) do header:SetAttribute(k, v) end
        return g
    end
    Grid()
    header:Show()
    -- the designer's changes: the layout of the cells (not in a fight) and their lettering
    function ns:ApplyRaidDesign()
        local rd = ns.RaidDesign()
        for _, b in ipairs(cells) do
            if b.name then pcall(ns.Font, ns, b.name, rd.nameSize) end
            if b.status then pcall(ns.Font, ns, b.status, rd.statusSize) end
        end
        if InCombatLockdown() then ns.raidDesignPending = true; return false end
        ns.raidDesignPending = nil
        GAP = rd.gap
        local g = Grid()
        header:Hide(); header:Show()                          -- (the header lays its cells out again)
        if ns.PlaceRaidSamples then pcall(ns.PlaceRaidSamples) end      -- (and the sample players follow)
        return g
    end
    do
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", ns:Guard("RaidFrames events", function() if ns.raidDesignPending then pcall(ns.ApplyRaidDesign, ns) end end))
    end

    -- range dimming, a couple of times a second
    local acc = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", ns:Guard("Raid frames", function(_, e)
        acc = acc + e
        if acc < 0.5 then return end
        acc = 0
        for _, b in ipairs(cells) do
            if b.unit and b:IsShown() then pcall(UpdateRange, b) end
        end
    end))

    -- Put Blizzard's raid frames away; its raid manager tab (markers, ready check) stays
    local function Park()
        local c = _G.CompactRaidFrameContainer
        if type(c) == "table" and c.SetParent then
            if c.UnregisterAllEvents then c:UnregisterAllEvents() end
            c:SetParent(ns.hidden)
        end
    end
    if InCombatLockdown() then
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", ns:Guard("RaidFrames events", function(self) self:UnregisterAllEvents(); pcall(Park) end))
    else
        Park()
    end

    ns:RegisterMovable(anchor, "raid", "Raid frames")

    -- Preview: ten sample players, since real raid frames only exist inside a raid
    local samples = {}
    ns.raidSamples = samples                                    -- (group practice puts buff coverage marks on them)
    local CLASSES = { "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "HUNTER", "PALADIN", "SHAMAN", "WARLOCK", "PRIEST" }
    local function PlaceSample(i, b)                         -- (laid out as the designer says: across or down, so many a column)
        local d = ns.RaidDesign()
        local per = d.perColumn
        local col, row = math.floor((i - 1) / per), (i - 1) % per
        if d.horizontal then col, row = (i - 1) % per, math.floor((i - 1) / per) end
        GAP = d.gap
        b:SetSize(CELL_W, CELL_H)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", anchor, "TOPLEFT", col * (CELL_W + GAP), -row * (CELL_H + GAP))
    end
    ns:RegisterPreview(function(on)
        if on and IsInRaid and IsInRaid() then return end       -- the real ones are already on screen
        for i = 1, 10 do
            local b = samples[i]
            if on and not b then
                b = CreateFrame("Button", nil, anchor)
                ns.RaidStyle(b)
                b.suiSample = true
                local cr, cg, cb = ns:ClassRGB(CLASSES[i])
                b.health:SetStatusBarColor(cr or 0.3, cg or 0.75, cb or 0.35)
                b.health:SetMinMaxValues(0, 100)
                b.health:SetValue(100 - (i * 37) % 70)
                b.power:SetMinMaxValues(0, 100)
                b.power:SetValue(40 + (i * 23) % 60)
                b.power:SetStatusBarColor(0.25, 0.5, 1)
                b.name:SetText(format(ns:Tr("Player %d"), i))
                b.role:SetText(i == 1 and ("|cff4d99ff" .. ns.RoleLetter("TANK") .. "|r") or (i == 2 and ("|cff4dff80" .. ns.RoleLetter("HEALER") .. "|r") or ""))
                if i == 4 then b.status:SetText(ns.DeadWord()); b.health:SetValue(0) end
                if i == 7 then b.dispel:Show() end
                samples[i] = b
            end
            if b then
                if on then PlaceSample(i, b); b:Show() else b:Hide() end
            end
        end
    end)

    -- Live resize (size sliders in /fgui layout)
    function ns:ResizeRaid()
        if InCombatLockdown() then
            ns:Print("Raid frame size will apply after combat or a /reload.")
            return
        end
        CELL_W, CELL_H = ns.db.raidW, ns.db.raidH
        anchor:SetSize((CELL_W + GAP) * 8, (CELL_H + GAP) * 5)
        header:SetAttribute("cellWidth", CELL_W)
        header:SetAttribute("cellHeight", CELL_H)
        for _, b in ipairs(cells) do
            if not b.suiSample then b:SetSize(CELL_W, CELL_H) end
            if b.incoming then b.incoming:SetWidth(CELL_W - 2) end
        end
        for i, b in ipairs(samples) do PlaceSample(i, b) end
    end
    ns.PlaceRaidSamples = function() for i, b in ipairs(samples) do PlaceSample(i, b) end end
end)
