local _, ns = ...

ns:NewModule("questLog", function()
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo and QL.GetTitleForQuestID) then
        ns:Print("Quest log: this client lacks the C_QuestLog API, keeping Blizzard's quest log.")
        return
    end

    local th, FONT = ns.theme, ns.FONT

    local frame = CreateFrame("Frame", "FantasyGlassUIQuestLog", UIParent, ns.template)
    frame:SetSize(820, 540)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop(ns.BACKDROP)
    ns:Paint(frame, "SetBackdropColor", "window", 0.96)
    ns:Paint(frame, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(frame)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "FantasyGlassUIQuestLog")

    local title = frame:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 20, true)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText(ns:AccentHex() .. "Quest|r Log")
    local count = frame:CreateFontString(nil, "OVERLAY")
    ns:Font(count, 12)
    count:SetPoint("LEFT", title, "RIGHT", 14, 0)
    ns:Paint(count, "SetTextColor", "dim")

    local close = ns:CreateButton(frame, "X", 24, 24, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)

    local function Rule(x1, y1, x2, y2, vertical)
        local t = frame:CreateTexture(nil, "ARTWORK")
        t:SetTexture(ns.FLAT)
        ns:Paint(t, "SetVertexColor", "@accent", 0.6)
        if vertical then
            t:SetWidth(1)
            t:SetPoint("TOPLEFT", x1, y1)
            t:SetPoint("BOTTOMLEFT", x1, y2)
        else
            t:SetHeight(1)
            t:SetPoint("TOPLEFT", x1, y1)
            t:SetPoint("TOPRIGHT", x2, y1)
        end
    end
    local div = ns:Divider(frame, 12)
    div:SetPoint("TOPLEFT", 40, -38)
    div:SetPoint("TOPRIGHT", -40, -38)
    Rule(298, -52, nil, 14, true)

    -- Left: quest list -------------------------------------------------------------------------------
    local listScroll, listContent = ns:CreateScroll(frame, 270)
    listScroll:SetPoint("TOPLEFT", 12, -52)
    listScroll:SetSize(276, 474)

    -- Right: details ---------------------------------------------------------------------------------
    local detScroll, det = ns:CreateScroll(frame, 480)
    detScroll:SetPoint("TOPLEFT", 312, -52)
    detScroll:SetSize(494, 420)

    local function FS(size, r, g, b)
        local fs = det:CreateFontString(nil, "OVERLAY")
        ns:Font(fs, size)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWidth(476)
        fs:SetTextColor(r or 1, g or 1, b or 1)
        return fs
    end
    local dTitle = FS(18, 1, 0.82, 0)
    local dLevel = FS(12, ns:T("dim"))
    local hObj   = FS(13, th.accent[1], th.accent[2], th.accent[3])
    local dObj   = FS(12, ns:T("text"))
    local hDesc  = FS(13, th.accent[1], th.accent[2], th.accent[3])
    local dDesc  = FS(12, ns:T("text"))
    local hRew   = FS(13, th.accent[1], th.accent[2], th.accent[3])
    local dRew   = FS(12, ns:T("text"))
    ns:Font(dTitle, 20, true)
    for _, h in ipairs({ hObj, hDesc, hRew }) do ns:Font(h, 14, true) end

    local function Layout()
        local y = 0
        local function put(fs, gap)
            local txt = fs:GetText()
            if txt and txt ~= "" then
                fs:ClearAllPoints()
                fs:SetPoint("TOPLEFT", det, "TOPLEFT", 0, -y)
                fs:Show()
                y = y + fs:GetStringHeight() + (gap or 8)
            else
                fs:Hide()
            end
        end
        put(dTitle, 2); put(dLevel, 14)
        put(hObj, 4); put(dObj, 14)
        put(hDesc, 4); put(dDesc, 14)
        put(hRew, 4); put(dRew, 8)
        detScroll:SetContentHeight(y + 10)
        detScroll:SetVerticalScroll(0)
    end

    -- State -------------------------------------------------------------------------------------------
    local rows, collapsed, selectedID = {}, {}, nil
    local ShowDetails, Rebuild

    local function FindInfo(questID)
        local idx = QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(questID)
        return idx and QL.GetInfo(idx)
    end

    local function Tracked(id)
        return QL.GetQuestWatchType and QL.GetQuestWatchType(id) ~= nil
    end

    local function LevelColor(level)
        if GetQuestDifficultyColor and level then
            local c = GetQuestDifficultyColor(level)
            if c then return c.r, c.g, c.b end
        end
        return 1, 0.82, 0
    end

    local function RewardsText(id)
        local r = {}
        pcall(function()
            local xp = GetQuestLogRewardXP and GetQuestLogRewardXP(id)
            if xp and xp > 0 then r[#r + 1] = "|cffffffff" .. xp .. "|r experience" end
            local money = GetQuestLogRewardMoney and GetQuestLogRewardMoney(id)
            if money and money > 0 then
                r[#r + 1] = ns:Coins(money)
            end
            local n = GetNumQuestLogRewards and GetNumQuestLogRewards(id) or 0
            for i = 1, n do
                local name, tex, num = GetQuestLogRewardInfo(i, id)
                if name then r[#r + 1] = format("|T%s:14|t %s%s", tex or "", name, (num and num > 1) and (" x" .. num) or "") end
            end
            local c = GetNumQuestLogChoices and GetNumQuestLogChoices(id, true) or 0
            if c > 0 then
                r[#r + 1] = "|cffb5a585Choose one:|r"
                for i = 1, c do
                    local name, tex, num = GetQuestLogChoiceInfo(i)
                    if name then r[#r + 1] = format("   |T%s:14|t %s%s", tex or "", name, (num and num > 1) and (" x" .. num) or "") end
                end
            end
        end)
        return table.concat(r, "\n")
    end

    -- Action buttons ----------------------------------------------------------------------------------
    local btnTrack, btnMap, btnShare, btnAbandon
    local abandonToken = 0

    btnTrack = ns:CreateButton(frame, "Track", 110, 26, function()
        if not selectedID then return end
        if Tracked(selectedID) then QL.RemoveQuestWatch(selectedID) else QL.AddQuestWatch(selectedID) end
        Rebuild(); ShowDetails(selectedID)
    end)
    btnTrack:SetPoint("BOTTOMLEFT", 312, 14)

    btnMap = ns:CreateButton(frame, "Show on Map", 110, 26, function()
        if not selectedID then return end
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then C_SuperTrack.SetSuperTrackedQuestID(selectedID) end
        if InCombatLockdown() then                               -- (the game does not let an add-on open the map in a fight)
            ns:Print("The quest is tracked. The map can't be opened for you in combat: press M.")
            return
        end
        if QuestMapFrame_OpenToQuestDetails then pcall(QuestMapFrame_OpenToQuestDetails, selectedID)
        elseif ToggleWorldMap then ToggleWorldMap() end
    end)
    btnMap:SetPoint("LEFT", btnTrack, "RIGHT", 8, 0)

    btnShare = ns:CreateButton(frame, "Share", 80, 26, function()
        if not selectedID then return end
        if QL.IsPushableQuest and QL.IsPushableQuest(selectedID) and IsInGroup() then
            QL.SetSelectedQuest(selectedID)
            if QuestLogPushQuest then QuestLogPushQuest() end
        else
            ns:Print("This quest can't be shared (or you're not in a group).")
        end
    end)
    btnShare:SetPoint("LEFT", btnMap, "RIGHT", 8, 0)

    btnAbandon = ns:CreateButton(frame, "Abandon", 110, 26, function(self)
        if not selectedID then return end
        if self.armed then
            self.armed = false
            self.text:SetText(ns:Tr("Abandon"))
            QL.SetSelectedQuest(selectedID)
            QL.SetAbandonQuest()
            QL.AbandonQuest()
            selectedID = nil
        else
            self.armed = true
            self.text:SetText("|cffff5555Click to confirm|r")
            abandonToken = abandonToken + 1
            local token = abandonToken
            ns:After(4, function()
                if token == abandonToken and btnAbandon.armed then
                    btnAbandon.armed = false
                    btnAbandon.text:SetText(ns:Tr("Abandon"))
                end
            end)
        end
    end)
    btnAbandon:SetPoint("BOTTOMRIGHT", -14, 14)

    -- Details -----------------------------------------------------------------------------------------
    function ShowDetails(id)
        selectedID = id
        if not id then
            dTitle:SetText("")
            dLevel:SetText(ns:Tr("Select a quest from the list."))
            hObj:SetText(""); dObj:SetText(""); hDesc:SetText(""); dDesc:SetText(""); hRew:SetText(""); dRew:SetText("")
            Layout()
            return
        end
        pcall(QL.SetSelectedQuest, id)
        local info = FindInfo(id)
        local complete = QL.IsComplete and QL.IsComplete(id)
        dTitle:SetText(QL.GetTitleForQuestID(id) or "")
        local lvl = info and info.questLevel
        dLevel:SetText(((lvl and lvl > 0) and ("Level " .. lvl) or "") .. (complete and "   |cff66dd77Ready to turn in|r" or ""))

        local lines = {}
        for _, o in ipairs(QL.GetQuestObjectives(id) or {}) do
            if o.text and o.text ~= "" then
                lines[#lines + 1] = (o.finished and "|cff66dd77" or "|cffddd2b8") .. "- " .. o.text .. "|r"
            end
        end
        hObj:SetText(ns:Tr("Objectives"))
        dObj:SetText(#lines > 0 and table.concat(lines, "\n") or "|cffb5a585None|r")

        local ok, desc = pcall(GetQuestLogQuestText)
        hDesc:SetText(ns:Tr("Description"))
        dDesc:SetText((ok and desc) or "")

        local rew = RewardsText(id)
        hRew:SetText(rew ~= "" and "Rewards" or "")
        dRew:SetText(rew)

        btnTrack.text:SetText(Tracked(id) and "Untrack" or "Track")
        Layout()
    end

    -- List ----------------------------------------------------------------------------------------------
    local function OnRowClick(self)
        if self.header then
            collapsed[self.header] = not collapsed[self.header]
            Rebuild()
        else
            ShowDetails(self.questID)
            Rebuild()
        end
    end

    local function GetRow(i)
        if rows[i] then return rows[i] end
        local b = CreateFrame("Button", nil, listContent)
        b:SetSize(268, 22)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.bg:SetTexture(ns.FLAT)
        b.bg:SetVertexColor(1, 1, 1, 0)
        b.text = b:CreateFontString(nil, "OVERLAY")
        ns:Font(b.text, 12)
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b.text:SetPoint("LEFT", 6, 0)
        b.text:SetPoint("RIGHT", -20, 0)
        b.mark = b:CreateTexture(nil, "OVERLAY")
        b.mark:SetSize(8, 8)
        b.mark:SetPoint("RIGHT", -8, 0)
        b.mark:SetTexture(ns.FLAT)
        ns:Paint(b.mark, "SetVertexColor", "@accent", 1)
        b:SetScript("OnEnter", function(self) if not self.selected then self.bg:SetVertexColor(1, 1, 1, 0.06) end end)
        b:SetScript("OnLeave", function(self) if not self.selected then self.bg:SetVertexColor(1, 1, 1, 0) end end)
        b:SetScript("OnClick", OnRowClick)
        rows[i] = b
        return b
    end

    function Rebuild()
        local num, numQuests = QL.GetNumQuestLogEntries()
        local groups, cur = {}, nil
        for i = 1, num do
            local info = QL.GetInfo(i)
            if info and not info.isHidden and not info.isTask then
                if info.isHeader then
                    cur = { title = info.title, quests = {} }
                    groups[#groups + 1] = cur
                else
                    if not cur then cur = { title = "Other", quests = {} }; groups[#groups + 1] = cur end
                    cur.quests[#cur.quests + 1] = info
                end
            end
        end

        local list = {}
        local firstQuest
        for _, g in ipairs(groups) do
            if #g.quests > 0 then
                list[#list + 1] = { header = g.title, n = #g.quests }
                if not collapsed[g.title] then
                    for _, q in ipairs(g.quests) do
                        list[#list + 1] = { quest = q }
                        firstQuest = firstQuest or q.questID
                    end
                end
            end
        end

        for i = 1, math.max(#list, #rows) do
            local b, e = GetRow(i), list[i]
            if e then
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * 22)
                if e.header then
                    b.header, b.questID, b.selected = e.header, nil, false
                    b.text:SetText((collapsed[e.header] and "+ " or "- ") .. e.header .. "  |cff9c8c6c(" .. e.n .. ")|r")
                    ns:Paint(b.text, "SetTextColor", "@accent")
                    b.text:SetPoint("LEFT", 6, 0)
                    b.bg:SetVertexColor(1, 1, 1, 0.03)
                    b.mark:Hide()
                else
                    local q = e.quest
                    b.header, b.questID = nil, q.questID
                    b.selected = (q.questID == selectedID)
                    local done = QL.IsComplete and QL.IsComplete(q.questID)
                    local lvl = q.questLevel
                    b.text:SetText(((lvl and lvl > 0) and ("[" .. lvl .. "] ") or "") .. (q.title or "?") .. (done and "  |cff66dd77Done|r" or ""))
                    b.text:SetTextColor(LevelColor(lvl))
                    b.text:SetPoint("LEFT", 16, 0)
                    b.bg:SetVertexColor(th.accent[1], th.accent[2], th.accent[3], b.selected and 0.25 or 0)
                    if Tracked(q.questID) then b.mark:Show() else b.mark:Hide() end
                end
                b:Show()
            else
                b:Hide()
            end
        end
        listScroll:SetContentHeight(#list * 22 + 4)

        local maxQ = QL.GetMaxNumQuestsCanAccept and QL.GetMaxNumQuestsCanAccept() or 25
        count:SetText((numQuests or 0) .. " / " .. maxQ)
        return firstQuest
    end

    local function Open(questID)
        pcall(function()
            for i = (QL.GetNumQuestLogEntries()), 1, -1 do        -- make sure no zone is collapsed in Blizzard's log
                local info = QL.GetInfo(i)
                if info and info.isHeader and info.isCollapsed and QL.ExpandQuestHeader then QL.ExpandQuestHeader(i) end
            end
        end)
        local first = Rebuild()
        if questID then selectedID = questID
        elseif not selectedID or not FindInfo(selectedID) then selectedID = first end
        ShowDetails(selectedID)
        Rebuild()
        frame:Show()
    end

    function ns:ToggleQuestLog(questID)
        if frame:IsShown() and not questID then frame:Hide() else Open(questID) end
    end
    function ns:OpenQuestLog(questID) Open(questID) end

    -- Keep in sync --------------------------------------------------------------------------------------
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do
        pcall(f.RegisterEvent, f, e)
    end
    f:SetScript("OnEvent", ns:Safe("Quest log", function()
        if not frame:IsShown() then return end
        Rebuild()
        if selectedID and FindInfo(selectedID) then ShowDetails(selectedID) else ShowDetails(nil) end
    end))

    -- Take over the default "L" / micro-menu quest log
    if ToggleQuestLog then
        hooksecurefunc("ToggleQuestLog", ns:Safe("Quest log", function()
            if WorldMapFrame and WorldMapFrame:IsShown() and not InCombatLockdown() then      -- (in a fight the game's own stays)
                HideUIPanel(WorldMapFrame)
                ns:ToggleQuestLog()
            end
        end))
    end

    SLASH_FANTASYGLASSUIQL1 = "/ql"
    SLASH_FANTASYGLASSUIQL2 = "/quests"
    SlashCmdList["FANTASYGLASSUIQL"] = function() ns:ToggleQuestLog() end
end)
