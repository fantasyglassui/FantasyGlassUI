local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Damage and healing meter. This client has no combat log, so a meter is only possible if the game
-- shares its own totals (C_DamageMeter). If it doesn't, this module quietly does nothing and
-- /fgui check says so. Totals can be hidden values in combat: bars take them as they are, and
-- number text is shown only when the game lets us format it.
--
-- It comes in two shapes, chosen by "Damage meter: drawer on the chat box":
--   * a drawer that comes out of the side of the chat box, as tall as the chat box, tucked away or
--     brought out with the small tab on its edge;
--   * a window of its own that you place in move mode, as it always was.
-- Either way: bars in class colors reading damage (or healing) per second, and under them who has
-- how much threat on your target, when you are in a group and fighting it.

ns.METER_LINGER = 8                                           -- seconds the drawer stays out after a fight it opened for
local ROW_H, ROW_GAP = 18, 2
local THREAT_H, THREAT_GAP, THREAT_MAX = 14, 2, 3
local HEADER_H = 22
local MAX_ROWS = 12

-- How many meter rows fit in a panel this tall, with this many threat rows under them.
function ns.MeterRowsThatFit(height, threatRows)
    if type(height) ~= "number" then return 8 end
    local threat = (threatRows and threatRows > 0) and (16 + threatRows * (THREAT_H + THREAT_GAP) + 4) or 0
    local n = math.floor((height - HEADER_H - threat - 6) / (ROW_H + ROW_GAP))
    return math.max(1, math.min(MAX_ROWS, n))
end

-- One player's amount per second, and where it came from. In order of preference:
--   "figure"   - the game gives a per-second figure with each player;
--   "list"     - the game was asked for its per-second list, so the amount it gives is per second;
--   "computed" - the total divided by the length of the fight, when both can be read;
--   nil        - none of those: the caller shows the total instead.
function ns.MeterPerSecond(src, data, rateList)
    if type(src) ~= "table" then return nil end
    local rate = src.amountPerSecond
    if Secret(rate) or type(rate) == "number" then return rate, "figure" end
    local total = src.totalAmount
    if rateList and (Secret(total) or type(total) == "number") then return total, "list" end
    local length = type(data) == "table" and (data.durationSeconds or data.duration) or nil
    if type(total) == "number" and not Secret(total) and type(length) == "number" and not Secret(length) and length > 0 then
        return math.floor(total / length + 0.5), "computed"
    end
    return nil
end
local READING = {
    figure = "per second, from the game's per-second figure", list = "per second, from the game's per-second list",
    computed = "per second, worked out from the total and the length of the fight", total = "totals (this game client gives no per-second amount)",
}

-- Earlier fights the game still has, newest first, for the heading's right-click: { id, label }.
-- "list" is what the game returns; clients name the fields differently, so several are tried.
function ns.MeterPastSessions(list, max)
    local out = {}
    if type(list) ~= "table" then return out end
    for i = #list, 1, -1 do
        local e = list[i]
        if type(e) == "table" then
            local id = e.sessionID or e.combatSessionID or e.id
            if id ~= nil and not Secret(id) then
                local name = e.name or e.sessionName
                if type(name) ~= "string" or Secret(name) or name == "" then name = nil end
                out[#out + 1] = { id = id, label = name }
                if #out >= (max or 6) then break end
            end
        end
    end
    return out
end

-- One player's abilities from the game's breakdown, largest first as the game gives them:
-- { { name, amount } ... }, or nil and what the game sent instead (for the self-check).
function ns.MeterSpells(detail, perSecond, max)
    if type(detail) ~= "table" then return nil, "nothing" end
    local list = detail.combatSpells or detail.spells or detail.combatSpellDetails
    if type(list) ~= "table" then
        local keys = {}
        for k in pairs(detail) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        return nil, "no list of abilities (the game sent: " .. table.concat(keys, ", ") .. ")"
    end
    local out = {}
    for i = 1, math.min(#list, max or 8) do
        local e = list[i]
        if type(e) == "table" then
            local id = e.spellID or e.spellId
            local name
            if id ~= nil and not Secret(id) then
                if C_Spell and C_Spell.GetSpellName then
                    local ok, v = pcall(C_Spell.GetSpellName, id)
                    if ok and type(v) == "string" then name = v end
                end
            end
            if not name and type(e.name) == "string" and not Secret(e.name) then name = e.name end
            if type(e.creatureName) == "string" and not Secret(e.creatureName) and e.creatureName ~= "" then
                name = (name or "?") .. " (" .. e.creatureName .. ")"
            end
            local amount = e.totalAmount
            if perSecond and (Secret(e.amountPerSecond) or type(e.amountPerSecond) == "number") then amount = e.amountPerSecond end
            out[#out + 1] = { name = name or "?", amount = amount }
        end
    end
    return out
end

-- Threat entries { unit, pct }, highest first. If the game hides any of the amounts they cannot be
-- compared, and the order they came in (you first, then your group) is kept.
function ns.SortThreat(list)
    for _, e in ipairs(list) do
        if Secret(e.pct) or type(e.pct) ~= "number" then return list, false end
    end
    table.sort(list, function(a, b) return a.pct > b.pct end)
    return list, true
end

-- Who has threat on your target: you, your pet, your group. Nil when there is nothing worth showing
-- (no hostile target, or nobody but you).
function ns:ThreatOnTarget(most)                         -- most: how many rows (3 for the meter)
    if type(UnitDetailedThreatSituation) ~= "function" or type(UnitExists) ~= "function" then return nil end
    local function is(fn, ...)
        if type(fn) ~= "function" then return false end
        local ok, v = pcall(fn, ...)
        return ok and not Secret(v) and v == true
    end
    if not is(UnitExists, "target") or not is(UnitCanAttack, "player", "target") then return nil end
    local units = { "player", "pet" }
    if is(IsInRaid) then
        local ok, n = pcall(GetNumGroupMembers)
        for i = 1, (ok and type(n) == "number" and not Secret(n)) and math.min(n, 40) or 0 do
            local unit = "raid" .. i
            if not is(UnitIsUnit, unit, "player") then units[#units + 1] = unit end
        end
    elseif is(IsInGroup) then
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    end
    local list = {}
    for _, unit in ipairs(units) do
        if is(UnitExists, unit) then
            local ok, _, _, scaled = pcall(UnitDetailedThreatSituation, unit, "target")
            if ok and (Secret(scaled) or type(scaled) == "number") then list[#list + 1] = { unit = unit, pct = scaled } end
        end
    end
    if #list < 2 then return nil end                          -- alone, everything is on you: nothing to compare
    ns.SortThreat(list)
    while #list > (most or THREAT_MAX) do table.remove(list) end
    return list
end

ns:NewModule("damageMeter", function()
    local DM = C_DamageMeter
    local T = Enum and Enum.DamageMeterType
    local S = Enum and Enum.DamageMeterSessionType
    if not (type(DM) == "table" and DM.GetCombatSessionFromType and type(T) == "table" and type(S) == "table") then
        ns.meterState = "this game client does not share damage totals with add-ons"
        return
    end

    local W = 220
    local FULL = W + 12
    -- The views, in the order the heading steps through them. Each: its heading, what to ask the game
    -- for, whether that is the game's per-second list, and whether the bars read per second (the
    -- first two) or a plain total or count. A view the game client does not offer is left out.
    local modes = {}
    for _, view in ipairs({
        { "dps",        "Damage per second",  T.Dps or T.DamageDone,  T.Dps ~= nil, true },
        { "hps",        "Healing per second", T.Hps or T.HealingDone, T.Hps ~= nil, true },
        { "damage",     "Damage done",        T.DamageDone },
        { "healing",    "Healing done",       T.HealingDone },
        { "taken",      "Damage taken",       T.DamageTaken },
        { "absorbs",    "Absorbs",            T.Absorbs },
        { "interrupts", "Interrupts",         T.Interrupts },
        { "dispels",    "Dispels",            T.Dispels },
        { "deaths",     "Deaths",             T.Deaths },
    }) do
        if view[3] ~= nil then modes[#modes + 1] = { view[2], view[3], view[4] and true or false, key = view[1], perSecond = view[5] and true or false } end
    end
    if #modes == 0 then
        ns.meterState = "this game client lists nothing the meter could show"
        return
    end
    local sessions = { { "This fight", S.Current }, { "Overall", S.Overall } }
    local mode, session = 1, 1
    for i, view in ipairs(modes) do if view.key == ns.db.meterView then mode = i end end      -- the view you last chose

    local chat = _G.ChatFrame1
    local docked = ns.db.meterDock ~= false and type(chat) == "table" and chat.GetObjectType ~= nil and ns:Usable(chat)

    -- The panel -------------------------------------------------------------------------------------
    -- "panel" has the backdrop; "body" holds everything in it at full width. In the drawer the panel is
    -- what grows and shrinks, and the body rides its outer edge, so the contents come out with it.
    local panel = CreateFrame("Frame", "FantasyGlassUIMeter", UIParent, ns.template)
    panel:SetBackdrop(ns.BACKDROP)
    ns:Paint(panel, "SetBackdropColor", "bg2", 0.75)
    ns:Paint(panel, "SetBackdropBorderColor", "@border", 1)
    local body = CreateFrame("Frame", nil, panel)
    body:SetWidth(FULL)

    -- header: what is being measured. Left-click steps to the next view (Shift: back; the mouse wheel does
    -- both), right-click changes this fight/overall, Shift-right-click resets the meter.
    local header = CreateFrame("Button", nil, body)
    header:SetHeight(HEADER_H - 4)
    header:SetPoint("TOPLEFT", 6, -3)
    header:SetPoint("TOPRIGHT", -6, -3)
    header.text = ns:NewText(header, 11, "LEFT")
    header.text:SetPoint("LEFT", 2, 0)
    header.text:SetPoint("RIGHT", -2, 0)
    ns:Paint(header.text, "SetTextColor", "@accent")
    local function Title()
        local s = sessions[session]
        local label = s.id and (s.label or format(ns:Tr("Earlier fight %d"), s.nth or 1)) or ns:Tr(s[1])
        header.text:SetText(ns:Tr(modes[mode][1]) .. "  -  " .. label)
    end
    Title()
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local Refresh
    local function Step(by)
        mode = (mode - 1 + by) % #modes + 1
        ns.db.meterView = modes[mode].key
        Title()
        if Refresh then Refresh() end
    end
    local function NextSession()
        -- this fight, overall, then the earlier fights the game still has (looked up afresh each time round)
        if session == 1 then
            for i = #sessions, 3, -1 do sessions[i] = nil end
            if type(DM.GetAvailableCombatSessions) == "function" then
                local ok, list = pcall(DM.GetAvailableCombatSessions)
                for n, past in ipairs(ns.MeterPastSessions(ok and list or nil, 6)) do
                    past.nth = n
                    sessions[#sessions + 1] = past
                end
            end
        end
        session = session % #sessions + 1
    end
    local function Reset()
        if type(DM.ResetAllCombatSessions) ~= "function" then return false end
        if not pcall(DM.ResetAllCombatSessions) then return false end
        ns:Print("Damage meter reset.")
        if Refresh then Refresh() end
        return true
    end
    header:SetScript("OnClick", ns:Guard("Damage meter", function(_, button)
        local shift = IsShiftKeyDown and IsShiftKeyDown()
        if button == "RightButton" then
            if shift then Reset() return end
            NextSession()
            Title()
            if Refresh then Refresh() end
        else
            Step(shift and -1 or 1)
        end
    end))
    if header.EnableMouseWheel then
        header:EnableMouseWheel(true)
        header:SetScript("OnMouseWheel", ns:Guard("Damage meter", function(_, delta) Step((tonumber(delta) or 0) > 0 and -1 or 1) end))
    end
    header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns:Tr("Damage meter"))
        GameTooltip:AddLine(ns:Tr("Left-click or mouse wheel: next view (Shift: back)"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(ns:Tr("Right-click: this fight or overall"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(ns:Tr("Shift-right-click: reset the meter"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local empty = ns:NewText(body, 11, "CENTER")              -- (before the first fight: say so, not a blank panel)
    empty:SetPoint("TOPLEFT", 10, -HEADER_H - 8)
    empty:SetPoint("TOPRIGHT", -10, -HEADER_H - 8)
    ns:Paint(empty, "SetTextColor", "dim")
    empty:SetText(ns:Tr("Nothing yet: the meter fills during a fight."))
    local rows = {}
    for i = 1, MAX_ROWS do
        local bar = ns:NewStatusBar(body)
        bar:SetSize(W, ROW_H)
        bar:SetPoint("TOPLEFT", 6, -HEADER_H - (i - 1) * (ROW_H + ROW_GAP))
        bar.name = ns:NewText(bar, 11, "LEFT")
        bar.name:SetPoint("LEFT", 5, 0)
        bar.value = ns:NewText(bar, 11, "RIGHT")
        bar.value:SetPoint("RIGHT", -5, 0)
        bar.name:SetPoint("RIGHT", bar.value, "LEFT", -6, 0)
        bar.me = bar:CreateTexture(nil, "OVERLAY")           -- a white edge on your own row
        bar.me:SetTexture(ns.FLAT)
        bar.me:SetVertexColor(1, 1, 1, 0.95)
        bar.me:SetWidth(2)
        bar.me:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
        bar.me:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
        bar.me:Hide()
        bar:Hide()
        rows[i] = bar
    end
    -- Point at a row for that player's abilities: what the damage (or healing, or whatever the view is)
    -- was made of. The game is asked for the breakdown only then.
    local function Breakdown(src)
        local s = sessions[session]
        local fn = s.id and DM.GetCombatSessionSourceFromID or DM.GetCombatSessionSourceFromType
        if type(fn) ~= "function" then return nil, "this game client gives no breakdown" end
        local ok, detail = pcall(fn, s.id or s[2], modes[mode][2], src.sourceGUID, src.sourceCreatureID)
        if not ok then return nil, "the game refused (" .. tostring(detail):sub(1, 80) .. ")" end
        return ns.MeterSpells(detail, modes[mode].perSecond, 8)
    end
    for _, bar in ipairs(rows) do
        bar:EnableMouse(true)
        bar:SetScript("OnEnter", ns:Guard("Damage meter", function(self)
            local src = self.src
            if type(src) ~= "table" then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if not pcall(GameTooltip.AddLine, GameTooltip, src.name) then GameTooltip:AddLine(ns:Tr("Damage meter")) end
            local spells, why = Breakdown(src)
            if spells and #spells > 0 then
                ns.meterBreakdown = format("worked (%d abilities listed)", #spells)
                local A = AbbreviateNumbers
                for _, spell in ipairs(spells) do
                    local okA, text = pcall(function() return A and A(spell.amount) or spell.amount end)
                    if not (okA and pcall(GameTooltip.AddDoubleLine, GameTooltip, spell.name, text, 1, 1, 1, 1, 0.82, 0)) then
                        GameTooltip:AddLine(spell.name, 1, 1, 1)
                    end
                end
            else
                ns.meterBreakdown = "nothing to show: " .. tostring(why or "the game listed no abilities")
                GameTooltip:AddLine(ns:Tr("The game gives no breakdown for this row."), 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end))
        bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    ns.MeterBreakdownOf = Breakdown
    -- Is this row yours? The game says so on newer clients; otherwise the name is compared, when it can be.
    local function Mine(src)
        if ns.Is(src.isLocalPlayer, true) then return true end
        if src.isLocalPlayer ~= nil or Secret(src.isLocalPlayer) then return false end
        local ok, me = pcall(UnitName, "player")
        return ok and type(me) == "string" and not Secret(me) and ns.Is(src.name, me)
    end

    -- threat on your target, at the foot of the panel
    local threatLabel = ns:NewText(body, 10, "LEFT")
    ns:Paint(threatLabel, "SetTextColor", "@accent")
    threatLabel:Hide()
    local threatRows = {}
    for i = 1, THREAT_MAX do
        local bar = ns:NewStatusBar(body)
        bar:SetSize(W, THREAT_H)
        bar:SetMinMaxValues(0, 100)
        bar.name = ns:NewText(bar, 10, "LEFT")
        bar.name:SetPoint("LEFT", 5, 0)
        bar.value = ns:NewText(bar, 10, "RIGHT")
        bar.value:SetPoint("RIGHT", -5, 0)
        bar.name:SetPoint("RIGHT", bar.value, "LEFT", -6, 0)
        bar:Hide()
        threatRows[i] = bar
    end

    -- The number on a bar: a whole number, no decimals ("138", not "138.2342"). An amount we can read is
    -- rounded here. A hidden one cannot be rounded by us, so the game is asked to write it without
    -- decimals; only if it will not is it shortened or written as it comes.
    local function Value(fs, amount)
        local A = AbbreviateNumbers
        if type(amount) == "number" and not Secret(amount) then
            local whole = math.floor(amount + 0.5)
            if whole < 100000 or not A then fs:SetText(tostring(whole)) return end
            if pcall(function() fs:SetText(A(whole)) end) then return end
            fs:SetText(tostring(whole))
            return
        end
        if pcall(fs.SetFormattedText, fs, "%.0f", amount) then return end
        if A and pcall(function() fs:SetText(A(amount)) end) then return end
        if not pcall(fs.SetText, fs, amount) then fs:SetText("") end
    end
    ns.MeterValueText = Value
    local function Color(bar, classFile)
        local ok, r, g, b = pcall(function() return ns:ClassRGB(classFile) end)
        if ok and type(r) == "number" then bar:SetStatusBarColor(r, g, b) else ns:Paint(bar, "SetStatusBarColor", "@accent") end
    end

    local function ShowThreat(list)
        local count = list and #list or 0
        for i = 1, THREAT_MAX do
            local bar, entry = threatRows[i], list and list[i]
            if entry then
                bar:ClearAllPoints()
                bar:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 6, 6 + (count - i) * (THREAT_H + THREAT_GAP))
                pcall(bar.SetValue, bar, entry.pct)
                if Secret(entry.pct) then
                    if not pcall(function() bar.value:SetFormattedText("%.0f%%", entry.pct) end) then bar.value:SetText("") end
                else
                    bar.value:SetText(math.floor(entry.pct + 0.5) .. "%")
                end
                local okN, name = pcall(UnitName, entry.unit)
                if not (okN and pcall(bar.name.SetText, bar.name, name)) then bar.name:SetText("") end
                local okC, _, classFile = pcall(UnitClass, entry.unit)
                Color(bar, okC and classFile or nil)
                bar:Show()
            else
                bar:Hide()
            end
        end
        if count > 0 then
            threatLabel:ClearAllPoints()
            threatLabel:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 8, 6 + count * (THREAT_H + THREAT_GAP) + 1)
            local okN, name = pcall(UnitName, "target")
            if not (okN and pcall(threatLabel.SetText, threatLabel, name)) then threatLabel:SetText("") end
            threatLabel:Show()
        else
            threatLabel:Hide()
        end
        return count
    end

    Refresh = function()
        local okT, threat = pcall(ns.ThreatOnTarget, ns)
        local threatCount = ShowThreat(okT and threat or nil)
        local okH, height = pcall(body.GetHeight, body)
        local fit = ns.MeterRowsThatFit(okH and height or nil, threatCount)
        local shown = 0
        local chosen = sessions[session]
        if modes[mode][2] and (chosen[2] or chosen.id) then
            local data
            if chosen.id then
                if type(DM.GetCombatSessionFromID) == "function" then
                    local ok, v = pcall(DM.GetCombatSessionFromID, chosen.id, modes[mode][2])
                    if ok then data = v end
                end
            else
                data = DM.GetCombatSessionFromType(chosen[2], modes[mode][2])
            end
            local sources = type(data) == "table" and data.combatSources
            if type(sources) == "table" then
                -- bars are measured against the first player, who leads the list
                local rateList, perSecond = modes[mode][3], modes[mode].perSecond
                local top, how
                if perSecond then top, how = ns.MeterPerSecond(sources[1], data, rateList) end
                for i = 1, fit do
                    local src = sources[i]
                    if type(src) ~= "table" then break end
                    local bar = rows[i]
                    local amount = how and ns.MeterPerSecond(src, data, rateList) or nil
                    pcall(function()
                        if how and (Secret(amount) or amount ~= nil) then
                            bar:SetMinMaxValues(0, top)
                            bar:SetValue(amount)
                        else
                            bar:SetMinMaxValues(0, data.maxAmount)
                            bar:SetValue(src.totalAmount)
                        end
                    end)
                    Color(bar, src.classFilename)
                    if not pcall(bar.name.SetText, bar.name, src.name) then bar.name:SetText("") end
                    if how and (Secret(amount) or amount ~= nil) then Value(bar.value, amount) else Value(bar.value, src.totalAmount) end
                    if Mine(src) then bar.me:Show() else bar.me:Hide() end
                    bar.src = src
                    bar:Show()
                    shown = i
                end
                if shown > 0 then ns.meterReading = perSecond and READING[how or "total"] or "totals (the view chosen)" end
            end
        end
        for i = shown + 1, MAX_ROWS do rows[i].src = nil; rows[i]:Hide() end
        empty:SetShown(shown == 0)
        return shown, threatCount
    end

    function ns:ResetMeter() return Reset() end               -- (/fgui meter reset, in either shape)

    -- A window of its own ------------------------------------------------------------------------------
    if not docked then
        panel:SetSize(FULL, HEADER_H + 8 * (ROW_H + ROW_GAP) + 16 + THREAT_MAX * (THREAT_H + THREAT_GAP) + 10)
        panel:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 260)
        body:SetPoint("TOPLEFT")
        body:SetPoint("BOTTOMLEFT")
        ns:Dress(panel, true)
        ns:RegisterMovable(panel, "meter", "Damage meter")
        ns.meterState = "a window of its own"
        -- one failure switches the meter off rather than repeating an error every second
        ns:Every(1, "Damage meter", ns:Safe("Damage meter", function()
            if panel:IsShown() then Refresh() end
        end))
        ns.meterTest = { Refresh = Refresh, rows = rows, threatRows = threatRows, panel = panel, docked = false }
        return
    end

    -- A drawer on the chat box ------------------------------------------------------------------------
    -- It comes out of the side of the chat box that faces the middle of the screen.
    local function Side()
        local okX, x = pcall(chat.GetCenter, chat)
        local okW, w = pcall(UIParent.GetWidth, UIParent)
        if okX and okW and type(x) == "number" and type(w) == "number" and x > w / 2 then return "LEFT" end
        return "RIGHT"
    end
    local side = Side()
    local canSlide = type(panel.SetClipsChildren) == "function"
    if canSlide then pcall(panel.SetClipsChildren, panel, true) end
    panel:SetFrameStrata("LOW")

    local function Place(width)
        panel:ClearAllPoints()
        body:ClearAllPoints()
        if side == "RIGHT" then
            panel:SetPoint("TOPLEFT", chat, "TOPRIGHT", 5, 4)
            panel:SetPoint("BOTTOMLEFT", chat, "BOTTOMRIGHT", 5, -4)
            body:SetPoint("TOPRIGHT", panel, "TOPRIGHT")
            body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT")
        else
            panel:SetPoint("TOPRIGHT", chat, "TOPLEFT", -5, 4)
            panel:SetPoint("BOTTOMRIGHT", chat, "BOTTOMLEFT", -5, -4)
            body:SetPoint("TOPLEFT", panel, "TOPLEFT")
            body:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT")
        end
        panel:SetWidth(math.max(1, width))
    end

    -- the tab on its edge: click to tuck the drawer away or bring it out
    local handle = CreateFrame("Button", "FantasyGlassUIMeterTab", UIParent, ns.template)
    handle:SetSize(13, 46)
    handle:SetFrameStrata("LOW")
    handle:SetBackdrop(ns.BACKDROP)
    ns:Paint(handle, "SetBackdropColor", "bg2", 0.85)
    ns:Paint(handle, "SetBackdropBorderColor", "@border", 1)
    handle.text = ns:NewText(handle, 11, "CENTER")
    handle.text:SetPoint("CENTER", 0, 0)
    ns:Paint(handle.text, "SetTextColor", "@accent")

    local open = ns.db.meterOpen ~= false
    local width = open and FULL or 0
    local function Dress()
        local out = (side == "RIGHT")
        handle.text:SetText(((open and out) or (not open and not out)) and "<" or ">")
        handle:ClearAllPoints()
        if open then
            if out then handle:SetPoint("LEFT", panel, "RIGHT", -1, 0) else handle:SetPoint("RIGHT", panel, "LEFT", 1, 0) end
        else
            if out then handle:SetPoint("LEFT", chat, "RIGHT", 4, 0) else handle:SetPoint("RIGHT", chat, "LEFT", -4, 0) end
        end
        handle:SetAlpha((open or handle.over) and 1 or 0.45)
    end

    local slider = CreateFrame("Frame")
    slider:Hide()
    local function Settle()
        slider:Hide()
        width = open and FULL or 0
        if open then Place(width); panel:Show() else panel:Hide() end
        Dress()
    end
    slider:SetScript("OnUpdate", function(_, elapsed)
        local goal = open and FULL or 0
        local step = FULL * (tonumber(elapsed) or 0) / 0.18              -- the whole way in under a fifth of a second
        if math.abs(goal - width) <= step then return Settle() end
        width = width + (goal > width and step or -step)
        Place(width)
    end)
    -- "auto" is the drawer opening itself for a fight: that is not remembered as your choice.
    local function SetOpen(want, instant, auto)
        open = want and true or false
        if not auto then ns.db.meterOpen = open end
        side = Side()
        if open then Place(math.max(1, width)); panel:Show(); Refresh() end
        if instant or not canSlide or not ns:Motion() then Settle() else Dress(); slider:Show() end
    end
    -- Opening itself for a fight (if "Damage meter: open in combat" is on): out as the fight starts, tucked
    -- away a few seconds after it ends. Touch the tab yourself and it is left as you set it.
    local autoOpened, autoToken = false, 0
    local function Manual() autoOpened = false; autoToken = autoToken + 1; SetOpen(not open) end
    handle:SetScript("OnClick", ns:Guard("Damage meter", Manual))
    local fight = CreateFrame("Frame")
    fight:RegisterEvent("PLAYER_REGEN_DISABLED")
    fight:RegisterEvent("PLAYER_REGEN_ENABLED")
    fight:SetScript("OnEvent", ns:Guard("Damage meter", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            autoToken = autoToken + 1
            if ns.db.meterAuto and not open then autoOpened = true; SetOpen(true, false, true) end
        elseif autoOpened then
            autoToken = autoToken + 1
            local mine = autoToken
            ns:After(ns.METER_LINGER, function()
                if mine ~= autoToken or not autoOpened or InCombatLockdown() then return end
                autoOpened = false
                if open then SetOpen(false, false, true) end
            end)
        end
    end))
    handle:SetScript("OnEnter", function(self)
        self.over = true
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(ns:Tr("Damage meter"))
        GameTooltip:AddLine(ns:Tr(open and "Click to tuck it away" or "Click to bring it out"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    handle:SetScript("OnLeave", function(self)
        self.over = nil
        GameTooltip:Hide()
        Dress()
    end)

    SetOpen(open, true)
    ns.meterState = "a drawer on the " .. (side == "RIGHT" and "right" or "left") .. " of the chat box"

    ns:Every(1, "Damage meter", ns:Safe("Damage meter", function()
        if open and panel:IsShown() then Refresh() end
    end))
    function ns:ToggleMeter() Manual() end
    ns.meterTest = { Refresh = Refresh, rows = rows, threatRows = threatRows, panel = panel, handle = handle, docked = true,
                     SetOpen = SetOpen, IsOpen = function() return open end, Side = function() return side end,
                     Step = Step, View = function() return modes[mode].key end,
                     NextSession = function() NextSession(); Title() end, Session = function() return sessions[session] end, views = modes, AutoOpened = function() return autoOpened end }
end)
