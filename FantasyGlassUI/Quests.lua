local _, ns = ...

-- Objective-complete banner + "best reward for vendor" hint
ns:NewModule("quests", function()
    local f = CreateFrame("Frame")
    f:RegisterEvent("UI_INFO_MESSAGE")
    f:RegisterEvent("QUEST_COMPLETE")
    f:SetScript("OnEvent", ns:Safe("Quests", function(_, event, a, b)
        if event == "UI_INFO_MESSAGE" then
            local msg = (type(b) == "string") and b or a
            if type(msg) ~= "string" then return end
            local cur, need = msg:match("(%d+)/(%d+)%s*$")
            if cur and cur == need then
                local r, g, bl = ns:Signal("good")
                UIErrorsFrame:AddMessage(format(ns:Tr("Objective complete: %s"), msg), r, g, bl)
            end
        elseif event == "QUEST_COMPLETE" then
            local n = GetNumQuestChoices and GetNumQuestChoices() or 0
            if n > 1 then
                local bestPrice, bestLink = 0, nil
                for i = 1, n do
                    local link = GetQuestItemLink("choice", i)
                    if link then
                        local price = select(11, ns:GetItemInfo(link))
                        if price and price > bestPrice then bestPrice, bestLink = price, link end
                    end
                end
                if bestLink then ns:Print("Highest vendor value reward: %s", bestLink) end
            end
        end
    end))
end)

-- Opt-in: auto accept / turn in. Hold SHIFT to bypass. Never picks a reward for you.
ns:NewModule("autoQuest", function()
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW" }) do
        f:RegisterEvent(e)
    end
    f:SetScript("OnEvent", ns:Safe("Auto quest", function(_, event)
        if IsShiftKeyDown() then return end

        if event == "QUEST_DETAIL" then
            AcceptQuest()
        elseif event == "QUEST_PROGRESS" then
            if IsQuestCompletable and IsQuestCompletable() then CompleteQuest() end
        elseif event == "QUEST_COMPLETE" then
            if (GetNumQuestChoices() or 0) <= 1 then GetQuestReward(1) end
        elseif event == "QUEST_GREETING" then
            for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
                local _, isComplete = GetActiveTitle(i)
                if isComplete then SelectActiveQuest(i) return end
            end
            if GetNumAvailableQuests and GetNumAvailableQuests() > 0 then SelectAvailableQuest(1) end
        elseif event == "GOSSIP_SHOW" then
            local G = C_GossipInfo
            if not G then return end
            local options = G.GetOptions and G.GetOptions() or {}
            if #options > 0 then return end        -- vendors/trainers etc. open normally
            for _, q in ipairs(G.GetActiveQuests and G.GetActiveQuests() or {}) do
                if q.isComplete then G.SelectActiveQuest(q.questID) return end
            end
            local avail = G.GetAvailableQuests and G.GetAvailableQuests() or {}
            if avail[1] then G.SelectAvailableQuest(avail[1].questID) end
        end
    end))
end)
