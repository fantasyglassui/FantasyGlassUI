local _, ns = ...

-- Item levels on the inspect window: the level of each piece the other player is wearing, in the
-- corner of its slot, and their average above the head slot. The same as your own character window.
-- The game sends another player's gear a piece at a time, so the window is read again every half
-- second while it is open and the numbers fill in as they arrive.
local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs", "Feet",
                "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged" }
local NO_LEVEL = { [4] = true, [19] = true }               -- shirt and tabard

-- The item level of what `unit` wears in slot `id`, or nil (nothing there, not sent yet, or hidden).
function ns.InspectSlotLevel(unit, id)
    if type(unit) ~= "string" or type(id) ~= "number" or NO_LEVEL[id] then return nil end
    if type(GetInventoryItemLink) ~= "function" or not (C_Item and C_Item.GetDetailedItemLevelInfo) then return nil end
    local ok, link = pcall(GetInventoryItemLink, unit, id)
    if not ok or type(link) ~= "string" or ns:IsSecret(link) then return nil end
    local okL, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if okL and type(level) == "number" and not ns:IsSecret(level) and level > 1 then return level end
    return nil
end

ns:NewModule("inspectLevels", function()
    local avgText
    ns:Every(0.5, "Inspect window", function()
        local win = _G.InspectFrame
        if type(win) ~= "table" or not win.IsShown or not ns:Usable(win) or not win:IsShown() then return end
        local unit = win.unit
        if type(unit) ~= "string" or ns:IsSecret(unit) then unit = "target" end
        local levels, head = {}, nil
        for _, name in ipairs(SLOTS) do
            local slot = _G["Inspect" .. name .. "Slot"]
            if type(slot) == "table" and slot.GetObjectType and slot.GetID and ns:Usable(slot) then
                if name == "Head" then head = slot end
                if not slot.suiLevel then
                    local layer = CreateFrame("Frame", nil, slot)
                    layer:SetAllPoints()
                    layer:SetFrameLevel((slot:GetFrameLevel() or 1) + 6)
                    slot.suiLevel = ns:NewText(layer, 10, "RIGHT")
                    slot.suiLevel:SetPoint("BOTTOMRIGHT", -1, 2)
                    slot.suiLevel:SetTextColor(1, 0.82, 0)
                    if slot.suiLevel.SetShadowOffset then slot.suiLevel:SetShadowOffset(1, -1); slot.suiLevel:SetShadowColor(0, 0, 0, 1) end
                end
                local level = ns.InspectSlotLevel(unit, slot:GetID())
                slot.suiLevel:SetText(level or "")
                if level then levels[#levels + 1] = level end
            end
        end
        if head then
            if not avgText then                              -- (on the head slot, so it leaves with the gear page)
                local layer = CreateFrame("Frame", nil, head)
                layer:SetAllPoints()
                layer:SetFrameLevel((head:GetFrameLevel() or 1) + 8)
                avgText = ns:NewText(layer, 11, "LEFT")
                avgText:SetPoint("BOTTOMLEFT", head, "TOPLEFT", 0, 4)
                ns:Paint(avgText, "SetTextColor", "@accent")
            end
            local avg = ns.AverageItemLevel(levels)
            avgText:SetText(avg and (ns:Tr("Item level") .. "  " .. format("%.1f", avg)) or "")
        end
    end)
end)

------------------------------------------------------------------------------------------
-- Quest sounds: a chime when one of a quest's objectives is finished, and the "quest complete" sound
-- when the whole quest is ready to hand in. Every quest in your log is watched, whether or not it
-- is on the tracker. Nothing plays for a quest the first time it is seen (logging in, or accepting it).
------------------------------------------------------------------------------------------
-- before, now: { done = objectives finished, complete = ready to hand in }
function ns.QuestProgress(before, now)
    if type(before) ~= "table" or type(now) ~= "table" then return nil end
    if now.complete and not before.complete then return "complete" end
    if (now.done or 0) > (before.done or 0) then return "objective" end
    return nil
end
ns:NewModule("questSounds", function()
    local QL = C_QuestLog
    if type(QL) ~= "table" or not QL.GetNumQuestLogEntries or not QL.GetInfo or not QL.GetQuestObjectives then return end
    local state = {}
    -- Reads the whole log. Returns "complete", "objective" or nil: the most important thing that changed.
    local function Scan()
        local seen, best = {}, nil
        local ok, n = pcall(QL.GetNumQuestLogEntries)
        for i = 1, (ok and tonumber(n)) or 0 do
            local okI, info = pcall(QL.GetInfo, i)
            if okI and type(info) == "table" and not info.isHeader and type(info.questID) == "number" then
                local id, done, readable = info.questID, 0, true
                local okO, objectives = pcall(QL.GetQuestObjectives, id)
                if okO and type(objectives) == "table" then
                    for _, o in ipairs(objectives) do
                        if type(o) == "table" then
                            if ns:IsSecret(o.finished) then readable = false elseif o.finished then done = done + 1 end
                        end
                    end
                end
                local complete = false
                if QL.IsComplete then
                    local okC, c = pcall(QL.IsComplete, id)
                    complete = okC and ns.Is(c, true)
                end
                if readable then
                    local now = { done = done, complete = complete }
                    local what = ns.QuestProgress(state[id], now)
                    if what == "complete" or (what and not best) then best = what end
                    seen[id] = now
                else
                    seen[id] = state[id]
                end
            end
        end
        state = seen
        return best
    end
    ns.QuestSoundScan = Scan
    local dirty, lastSound = true, -100
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "QUEST_LOG_UPDATE")
    pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Inspect events", function() dirty = true end))
    ns:Every(0.3, "Quest sounds", function()
        if not dirty then return end
        dirty = false
        local what = Scan()
        if what and PlaySound and GetTime() - lastSound > 1 then
            lastSound = GetTime()
            pcall(PlaySound, what == "complete" and 619 or 618, "Master")      -- the game's "quest completed" and "quest update" sounds
        end
    end)
end)
