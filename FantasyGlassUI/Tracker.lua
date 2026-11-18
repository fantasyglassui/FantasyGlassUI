local _, ns = ...

ns:NewModule("questTracker", function()
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestWatches and QL.GetQuestIDForQuestWatchIndex and QL.GetQuestObjectives) then
        ns:Print("This game client does not hand its quests to add-ons, so the game's own quest tracker stays.")
        return
    end

    local th, FONT = ns.theme, ns.FONT
    local W = 250
    local blizz = _G.ObjectiveTrackerFrame

    local tracker = CreateFrame("Frame", "FantasyGlassUITracker", UIParent, ns.template)
    tracker:SetSize(W + 16, 40)
    tracker:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -12, -300)
    tracker:SetFrameStrata("LOW")
    tracker:SetFrameLevel(3)
    -- The tracker holds the quest-item buttons, and those are secure (they use an item). The game
    -- does not let an add-on resize, show or hide the frame a secure button sits in during combat,
    -- and quests update all through a fight. So the part that grows and shrinks with the list - the
    -- panel you see - is a frame of its own behind the tracker, which may change at any time, and
    -- the tracker itself is only resized between fights.
    local body = CreateFrame("Frame", nil, tracker, ns.template)
    body:SetFrameLevel(2)
    body:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 0, 0)
    body:SetHeight(40)
    body:EnableMouse(false)
    body:SetBackdrop(ns.BACKDROP)
    ns:Paint(body, "SetBackdropColor", "bg2", 0.55)
    ns:Paint(body, "SetBackdropBorderColor", "@border", 0.8)
    ns:Dress(body, true)
    local function SetTrackerHeight(h)
        body:SetHeight(h)
        if not ns:Locked(tracker) then tracker:SetHeight(h) end      -- (a fight ending redraws the list, which catches this up)
    end
    ns.trackerTest = { tracker = tracker, body = body, SetHeight = SetTrackerHeight }

    -- Header -------------------------------------------------------------------------------
    local header = CreateFrame("Button", nil, tracker)
    header:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 0, 0)
    header:SetHeight(24)
    header.text = header:CreateFontString(nil, "OVERLAY")
    ns:Font(header.text, 15, true)
    header.text:SetPoint("LEFT", 8, 0)
    ns:Paint(header.text, "SetTextColor", "@accent")
    header.fold = header:CreateFontString(nil, "OVERLAY")
    ns:Font(header.fold, 12)
    header.fold:SetPoint("RIGHT", -8, 0)
    local line = ns:Divider(tracker, 10)
    line:SetPoint("TOPLEFT", tracker, "TOPLEFT", 10, -20)
    line:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", -10, -20)

    local collapsed = false
    local dirty = true

    -- Pools -----------------------------------------------------------------------------------
    local titles, lines, items = {}, {}, {}

    local function OpenQuest(id)
        if ns.OpenQuestLog then ns:OpenQuestLog(id)
        elseif QuestMapFrame_OpenToQuestDetails then QuestMapFrame_OpenToQuestDetails(id) end
    end

    local function TitleClick(self, button)
        local id = self.questID
        if not id then return end
        if IsShiftKeyDown() then
            QL.RemoveQuestWatch(id)
        elseif button == "RightButton" then
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(id) end
        else
            OpenQuest(id)
        end
    end

    local function GetTitle(i)
        if titles[i] then return titles[i] end
        local b = CreateFrame("Button", nil, tracker)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b.text = b:CreateFontString(nil, "OVERLAY")
        ns:Font(b.text, 12)
        b.text:SetJustifyH("LEFT")
        b.text:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
        b.mark = b:CreateTexture(nil, "OVERLAY")
        b.mark:SetTexture(ns.FLAT)
        ns:Paint(b.mark, "SetVertexColor", "@accent", 1)
        b.mark:SetWidth(2)
        b.mark:SetPoint("TOPRIGHT", b, "TOPLEFT", -4, 0)
        b.mark:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -4, 0)
        b:SetScript("OnClick", TitleClick)
        b:SetScript("OnEnter", function(self) self.text:SetAlpha(0.75) end)
        b:SetScript("OnLeave", function(self) self.text:SetAlpha(1) end)
        titles[i] = b
        return b
    end

    local function GetLine(i)
        if lines[i] then return lines[i] end
        local fs = tracker:CreateFontString(nil, "OVERLAY")
        ns:Font(fs, 11)
        fs:SetJustifyH("LEFT")
        lines[i] = fs
        return fs
    end

    -- Usable quest-item buttons (secure, only touched out of combat)
    local itemsOK = pcall(function()
        for i = 1, 8 do
            local b = CreateFrame("Button", "FantasyGlassUITrackerItem" .. i, tracker, "SecureActionButtonTemplate")
            b:SetSize(22, 22)
            b:RegisterForClicks("AnyUp", "AnyDown")
            b:SetAttribute("type", "item")
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetAllPoints()
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            ns:AddBorder(b, 0, 0, 0, 1)
            b:Hide()
            items[i] = b
        end
    end)

    local function QuestColor(level, complete)
        if complete then return ns:Signal("good") end
        if GetQuestDifficultyColor and level then
            local c = GetQuestDifficultyColor(level)
            if c then return c.r, c.g, c.b end
        end
        return 1, 0.82, 0
    end

    -- Layout ------------------------------------------------------------------------------------
    local function Update()
        local n = QL.GetNumQuestWatches() or 0
        header.text:SetText(ns:Tr("Quests") .. "  |cffffffff" .. n .. "|r")
        header.fold:SetText(collapsed and "+" or "-")

        local combat = InCombatLockdown()
        for _, t in ipairs(titles) do t:Hide() end
        for _, l in ipairs(lines) do l:Hide() end
        if itemsOK and not combat then for _, b in ipairs(items) do b:Hide() end end

        if collapsed or n == 0 then
            SetTrackerHeight(24)
            return
        end

        local y, ti, li, ii = -32, 0, 0, 0
        local superID = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID and C_SuperTrack.GetSuperTrackedQuestID()

        for i = 1, n do
            local id = QL.GetQuestIDForQuestWatchIndex(i)
            if id then
                local logIndex = QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(id)
                local info = logIndex and QL.GetInfo(logIndex)
                local complete = QL.IsComplete and QL.IsComplete(id)
                local indent = 8

                -- quest item button
                if itemsOK and not combat and logIndex and GetQuestLogSpecialItemInfo then
                    local link, itemID, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
                    if link and (not complete or showWhenComplete) and ii < #items then
                        ii = ii + 1
                        local b = items[ii]
                        b:ClearAllPoints()
                        b:SetPoint("TOPLEFT", tracker, "TOPLEFT", 8, y)
                        b:SetAttribute("item", link)
                        local icon = (C_Item and C_Item.GetItemIconByID and itemID and C_Item.GetItemIconByID(itemID))
                                  or select(10, ns:GetItemInfo(link))
                        b.icon:SetTexture(icon)
                        b:Show()
                        indent = 36
                    end
                end

                ti = ti + 1
                local t = GetTitle(ti)
                t.questID = id
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", tracker, "TOPLEFT", indent, y)
                t:SetWidth(W + 8 - indent)
                t.text:SetWidth(W + 8 - indent)
                local title = QL.GetTitleForQuestID(id) or format(ns:Tr("Quest %d"), id)
                local lvl = info and info.questLevel
                t.text:SetTextColor(QuestColor(lvl, complete))
                local reward = ""
                if ns.db.questRewards and ns.QuestRewards then
                    local xp, money = ns:QuestRewards(id)
                    reward = ns.QuestRewardText(xp, money, complete)
                end
                t.text:SetText(((lvl and lvl > 0) and ("[" .. lvl .. "] " .. title) or title) .. reward)
                local h = t.text:GetStringHeight()
                t:SetHeight(h)
                if superID == id then t.mark:Show() else t.mark:Hide() end
                t:Show()
                y = y - h - 2

                -- objectives
                local objs = QL.GetQuestObjectives(id)
                local any = false
                for _, o in ipairs(objs or {}) do
                    local text = o.text
                    if o.type == "progressbar" and GetQuestProgressBarPercent then
                        text = (text and text ~= "" and text or ns:Tr("Progress")) .. format(" %d%%", GetQuestProgressBarPercent(id) or 0)
                    end
                    if text and text ~= "" then
                        li = li + 1
                        any = true
                        local fs = GetLine(li)
                        fs:ClearAllPoints()
                        fs:SetPoint("TOPLEFT", tracker, "TOPLEFT", indent + 8, y)
                        fs:SetWidth(W - indent - 4)
                        if o.finished then fs:SetTextColor(ns:Signal("good")) else ns:Paint(fs, "SetTextColor", "text") end
                        fs:SetText("- " .. text)
                        fs:Show()
                        y = y - fs:GetStringHeight() - 1
                    end
                end
                if complete and not any then
                    li = li + 1
                    local fs = GetLine(li)
                    fs:ClearAllPoints()
                    fs:SetPoint("TOPLEFT", tracker, "TOPLEFT", indent + 8, y)
                    fs:SetWidth(W - indent - 4)
                    fs:SetTextColor(ns:Signal("good"))
                    fs:SetText("- " .. ns:Tr("Ready to turn in"))
                    fs:Show()
                    y = y - fs:GetStringHeight() - 1
                end
                y = y - 6
            end
        end
        SetTrackerHeight(-y + 4)
    end

    -- Fallback: if we ever fail, give the player Blizzard's tracker back ---------------------
    local function Restore()
        ns.trackerFailed = true
        if ns:Locked(tracker) then tracker:SetAlpha(0) else tracker:Hide() end
        ns:Unkill(blizz)
        ns:Print("|cffff4444Something went wrong in the quest tracker, so the game's own tracker is back.|r Type /reload to try ours again.")
    end

    header:SetScript("OnClick", function()
        collapsed = not collapsed
        dirty = true
    end)

    local f = CreateFrame("Frame", nil, tracker)
    for _, e in ipairs({ "QUEST_WATCH_LIST_CHANGED", "QUEST_LOG_UPDATE", "QUEST_POI_UPDATE", "UNIT_QUEST_LOG_CHANGED",
                         "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "SUPER_TRACKING_CHANGED",
                         "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", ns:Guard("Tracker events", function() dirty = true end))

    local acc = 0
    f:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.25 or not dirty then return end
        acc = 0
        dirty = false
        local ok, err = pcall(Update)
        if not ok then
            ns:Print(tostring(err))
            Restore()
            f:SetScript("OnUpdate", nil)
        end
    end)

    -- Hide Blizzard's tracker
    -- (a managed frame: never Hide() it or hook it; make it see-through and unclickable instead)
    ns:Silence(blizz)

    ns:RegisterMovable(tracker, "tracker", "Quest tracker")
end)
