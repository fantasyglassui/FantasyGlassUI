local _, ns = ...

------------------------------------------------------------------------------------------
-- Gear set buttons.
--
-- The sets saved in the game's equipment manager, as a row of buttons under the character window:
-- one click puts a set on. The set you are wearing is marked, and a set with pieces you no longer
-- own is shown gray with the count in its tooltip.
--
-- The buttons are ordinary ones, not secure ones: the game lets an add-on ask for a set outside
-- combat, and refuses anyone during it, so there is nothing a secure button would add - and nothing
-- here that the game locks during a fight.
------------------------------------------------------------------------------------------
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- The saved sets, A to Z: { id, name, icon, worn, items, wearing, missing }.
-- "id" is whatever this client's "use this set" function takes: a number on newer ones, the name on older.
function ns:EquipmentSets()
    local list = {}
    local function add(id, name, icon, worn, items, wearing, missing)
        if type(name) ~= "string" or name == "" or ns:IsSecret(name) then return end
        local function n(v) return (type(v) == "number" and not ns:IsSecret(v)) and v or 0 end
        list[#list + 1] = { id = id, name = name, icon = icon, worn = ns.Is(worn, true), items = n(items), wearing = n(wearing), missing = n(missing) }
    end
    local E = C_EquipmentSet
    if type(E) == "table" and type(E.GetEquipmentSetIDs) == "function" and type(E.GetEquipmentSetInfo) == "function" then
        local ok, ids = pcall(E.GetEquipmentSetIDs)
        for _, id in ipairs((ok and type(ids) == "table") and ids or {}) do
            pcall(function()
                local name, icon, _, worn, items, wearing, _, missing = E.GetEquipmentSetInfo(id)
                add(id, name, icon, worn, items, wearing, missing)
            end)
        end
    elseif type(GetNumEquipmentSets) == "function" and type(GetEquipmentSetInfo) == "function" then
        local ok, count = pcall(GetNumEquipmentSets)
        for i = 1, (ok and tonumber(count)) or 0 do
            pcall(function()
                local name, icon, _, worn, items, wearing, _, missing = GetEquipmentSetInfo(i)
                add(name, name, icon, worn, items, wearing, missing)
            end)
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Does this client have an equipment manager an add-on can use?
function ns:CanUseSets()
    local E = C_EquipmentSet
    if type(E) == "table" and type(E.GetEquipmentSetIDs) == "function" and type(E.UseEquipmentSet) == "function" then return true end
    return type(GetNumEquipmentSets) == "function" and type(UseEquipmentSet) == "function"
end

-- Put a set on. Returns true when the game was asked to.
function ns:WearSet(set)
    if type(set) ~= "table" or set.id == nil then return false end
    if InCombatLockdown() then
        ns:Print("Gear sets can't be changed in combat.")
        return false
    end
    local use = (type(C_EquipmentSet) == "table" and C_EquipmentSet.UseEquipmentSet) or UseEquipmentSet
    if type(use) ~= "function" then return false end
    return (pcall(use, set.id))
end

-- What a set's tooltip says under its name.
function ns.SetSummary(set)
    local lines = {}
    if set.items > 0 then lines[#lines + 1] = format(ns:Tr("%d of %d pieces on"), set.wearing, set.items) end
    if set.missing > 0 then lines[#lines + 1] = "|cffff5555" .. format(ns:TrN(set.missing, "%d piece missing", "%d pieces missing"), set.missing) .. "|r" end
    lines[#lines + 1] = "|cff999999" .. ns:Tr(set.worn and "You are wearing this set" or "Click to wear this set") .. "|r"
    return lines
end

ns:NewModule("equipSets", function()
    if not ns:CanUseSets() then
        ns.setsState = "this game client has no equipment manager an add-on can use"
        return
    end
    ns.setsState = "waiting for the character window to be opened"

    local SIZE, GAP, MAX = 30, 6, 12
    local holder
    local buttons = {}

    local function Button(i)
        local b = CreateFrame("Button", nil, holder)
        b:SetSize(SIZE, SIZE)
        b:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (SIZE + GAP), 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints()
        b.hl:SetTexture(ns.FLAT)
        b.hl:SetVertexColor(1, 1, 1, 0.18)
        b.mark = b:CreateTexture(nil, "OVERLAY")              -- a line under the set you are wearing
        b.mark:SetTexture(ns.FLAT)
        b.mark:SetHeight(2)
        b.mark:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -3)
        b.mark:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -3)
        ns:Paint(b.mark, "SetVertexColor", "@accent", 1)
        ns:AddBorder(b, 0, 0, 0, 1)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", ns:Guard("Gear sets", function(self)
            if self.set and ns:WearSet(self.set) and PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then
                pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB)
            end
        end))
        b:SetScript("OnEnter", ns:Guard("Gear sets", function(self)
            if not self.set then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:AccentHex() .. self.set.name .. "|r")
            for _, line in ipairs(ns.SetSummary(self.set)) do GameTooltip:AddLine(line, 1, 1, 1) end
            GameTooltip:Show()
        end))
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        buttons[i] = b
        return b
    end

    local function Refresh(win)
        if not holder then
            holder = CreateFrame("Frame", "FantasyGlassUISets", win)
            holder:SetSize(SIZE, SIZE)
            holder:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 10, -8)
            holder:SetFrameLevel((win:GetFrameLevel() or 1) + 5)
        end
        local sets = ns:EquipmentSets()
        local shown = math.min(#sets, MAX)
        for i = 1, math.max(shown, #buttons) do
            local set, b = sets[i], buttons[i]
            if set and i <= MAX then
                b = b or Button(i)
                b.set = set
                b.icon:SetTexture(set.icon or QUESTION)
                if b.icon.SetDesaturated then b.icon:SetDesaturated(set.missing > 0) end
                if set.worn then b.mark:Show() else b.mark:Hide() end
                b:Show()
            elseif b then
                b.set = nil
                b:Hide()
            end
        end
        if shown > 0 then
            holder:SetWidth(shown * (SIZE + GAP) - GAP)
            holder:Show()
        else
            holder:Hide()
        end
        ns.setsState = (#sets == 0) and "no sets saved in the equipment manager yet"
            or format("%d sets shown under the character window%s", shown, #sets > MAX and format(" (of %d)", #sets) or "")
        return shown
    end
    ns.setsTest = { Refresh = Refresh, buttons = buttons, holder = function() return holder end }

    local dirty, wasShown = true, false
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED", "PLAYER_EQUIPMENT_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Sets events", function() dirty = true end))

    ns:Every(0.5, "Gear sets", function()
        local win = _G.CharacterFrame
        if not (type(win) == "table" and ns:Usable(win) and win.IsShown and win:IsShown()) then wasShown = false; return end
        if dirty or not wasShown then
            dirty = false
            pcall(Refresh, win)
        end
        wasShown = true
    end)
end)

------------------------------------------------------------------------------------------
-- Gear sets that follow your spec.
--
-- Each talent set remembers the gear set you last put on while it was active. Switch talent sets and
-- that gear set goes on by itself. Nothing to name and nothing to set up: wear your healing set once
-- while in your healing spec and it is remembered. Only a whole-set change is remembered (through
-- the buttons above or the game's equipment manager), not a single item swapped by hand.
------------------------------------------------------------------------------------------
-- The set to put on for a talent set, or nil and why not.
function ns.SetForSpec(memory, spec, sets)
    local name = type(memory) == "table" and memory[spec] or nil
    if type(name) ~= "string" then return nil, "no gear set remembered for this talent set yet" end
    for _, set in ipairs(sets or {}) do
        if set.name == name then
            if set.worn then return nil, "already wearing it" end
            return set
        end
    end
    return nil, "the remembered gear set no longer exists"
end
ns:NewModule("setsFollowSpec", function()
    if not ns:CanUseSets() then
        ns.specSetState = "this game client has no equipment manager an add-on can use"
        return
    end
    local root = ns.root
    if type(root) ~= "table" then return end
    if type(root.specSets) ~= "table" then root.specSets = {} end
    local key = ns:CharKey()
    if type(root.specSets[key]) ~= "table" then root.specSets[key] = {} end
    local memory = root.specSets[key]
    local spec = ns:TalentSet()
    local pending = false
    ns.specSetState = "on"

    local function Remember(setID)
        for _, set in ipairs(ns:EquipmentSets()) do
            if ns.Is(set.id, setID) then
                memory[ns:TalentSet()] = set.name
                return set.name
            end
        end
    end
    local function Follow(force)
        local now = ns:TalentSet()
        if now == spec and not force then return end
        spec = now
        local set, why = ns.SetForSpec(memory, now, ns:EquipmentSets())
        if not set then ns.specSetState = "on; talent set " .. now .. ": " .. tostring(why); pending = false; return end
        if InCombatLockdown() then pending = true; return end        -- (gear cannot change in a fight: afterwards)
        pending = false
        if ns:WearSet(set) then
            ns.specSetState = "on; talent set " .. now .. ": put on \"" .. set.name .. "\""
            ns:Print("Talent set %d: putting on \"%s\".", now, set.name)
        end
    end
    ns.specSetTest = { Remember = Remember, Follow = Follow, memory = memory, SetSpec = function(n) spec = n end }

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "EQUIPMENT_SWAP_FINISHED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "PLAYER_REGEN_ENABLED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Gear sets follow spec", function(_, event, a, b)
        if event == "EQUIPMENT_SWAP_FINISHED" then
            if ns.Is(a, false) then return end                 -- the change did not go through
            Remember(b)
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pending then Follow(true) end
        else
            ns:After(0.5, function() pcall(Follow) end)        -- (once the game has finished switching)
        end
    end))
end)
