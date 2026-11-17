local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Quest marks on nameplates: a yellow "!" beside the nameplate of anything you still need for a
-- quest - to kill, to loot, to use something on - so it can be picked out of a pack at a glance.
--
-- Whether a unit belongs to one of your quests is asked of the game: directly where it answers that,
-- otherwise by looking for an unfinished quest objective in the unit's tooltip. If the game hides the
-- answer (it may in a fight), the mark stays as it was.
------------------------------------------------------------------------------------------
-- true / false, or nil when it cannot be told right now. Second result: how it was found out.
function ns:UnitOnQuest(unit)
    if type(unit) ~= "string" then return nil end
    if type(C_QuestLog) == "table" and type(C_QuestLog.UnitIsRelatedToActiveQuest) == "function" then
        local ok, v = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)
        if ok then
            if Secret(v) then return nil, "hidden" end
            return v and true or false, "the game's own answer"
        end
    end
    local T = type(Enum) == "table" and Enum.TooltipDataLineType or nil
    if type(C_TooltipInfo) == "table" and type(C_TooltipInfo.GetUnit) == "function" and type(T) == "table" and T.QuestObjective ~= nil then
        local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
        if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil, "no tooltip" end
        for _, line in ipairs(data.lines) do
            if type(line) == "table" and ns.Is(line.type, T.QuestObjective) and not ns.Yes(line.completed) then
                return true, "the unit's tooltip"
            end
        end
        return false, "the unit's tooltip"
    end
    return nil, "this game client does not say"
end

ns:NewModule("plateQuest", function()
    if not (type(C_NamePlate) == "table" and C_NamePlate.GetNamePlateForUnit) then
        ns.plateQuestState = "no nameplates an add-on can reach"
        return
    end
    ns.plateQuestState = "on"
    local marks = setmetatable({}, { __mode = "k" })        -- plate -> its mark
    local units = {}                                         -- unit -> plate, for the ones on screen

    local function Mark(plate)
        local m = marks[plate]
        if m then return m end
        m = CreateFrame("Frame", nil, plate)
        m:SetSize(14, 18)
        local uf = plate.UnitFrame
        local bar = type(uf) == "table" and (uf.healthBar or uf.HealthBar or (type(uf.HealthBarsContainer) == "table" and uf.HealthBarsContainer.healthBar)) or nil
        if type(bar) == "table" and ns:Usable(bar) then
            m:SetPoint("RIGHT", bar, "LEFT", -2, 0)
            pcall(function() m:SetFrameLevel((bar:GetFrameLevel() or 1) + 5) end)
        else
            m:SetPoint("RIGHT", plate, "LEFT", 8, 0)
        end
        m.text = ns:NewText(m, 17, "CENTER")
        m.text:SetPoint("CENTER")
        m.text:SetText("!")
        m.text:SetTextColor(1, 0.82, 0)
        if m.text.SetShadowOffset then m.text:SetShadowOffset(1, -1); m.text:SetShadowColor(0, 0, 0, 1) end
        m:Hide()
        marks[plate] = m
        return m
    end
    local shown, how = 0, nil
    local function Update(unit, plate)
        if not (type(plate) == "table" and ns:Usable(plate)) then return end
        local on, via = ns:UnitOnQuest(unit)
        if via then how = via end
        if on == nil then return end                         -- cannot tell right now: leave it as it is
        local m = Mark(plate)
        if on then m:Show() else m:Hide() end
    end
    local function UpdateAll()
        shown = 0
        for unit, plate in pairs(units) do
            pcall(Update, unit, plate)
            local m = marks[plate]
            if m and m.IsShown and m:IsShown() then shown = shown + 1 end
        end
        ns.plateQuestState = format("on (%d marked now; asked by %s)", shown, tostring(how or "nothing yet"))
    end
    ns.plateQuestTest = { units = units, marks = marks, UpdateAll = UpdateAll }

    local dirty = false
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Quest marks", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            if type(unit) ~= "string" or Secret(unit) then return end
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if type(plate) == "table" and ns:Usable(plate) then
                units[unit] = plate
                local m = marks[plate]
                if m then m:Hide() end                       -- a plate is reused: start clean
                Update(unit, plate)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if type(unit) ~= "string" or Secret(unit) then return end
            local plate = units[unit]
            units[unit] = nil
            if plate and marks[plate] then marks[plate]:Hide() end
        else
            dirty = true                                     -- your quests changed: look at every plate again, shortly
        end
    end))
    ns:Every(0.5, "Quest marks", function()
        if dirty then dirty = false; UpdateAll() end
    end)
end)
