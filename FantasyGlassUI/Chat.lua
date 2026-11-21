local _, ns = ...

-- Where the typing bar goes relative to the chat box: which of its edges meets which edge of the chat
-- box, a word for the self-check, and the gap between them.
function ns.ChatEditPlace(above)
    if above then return "BOTTOM", "TOP", "above the chat box", 4 end
    return "TOP", "BOTTOM", "under the chat box", -6
end

ns:NewModule("chat", function()
    -- Short channel names
    local short = {
        CHAT_GUILD_GET          = "|Hchannel:GUILD|h[G]|h %s: ",
        CHAT_OFFICER_GET        = "|Hchannel:OFFICER|h[O]|h %s: ",
        CHAT_PARTY_GET          = "|Hchannel:PARTY|h[P]|h %s: ",
        CHAT_PARTY_LEADER_GET   = "|Hchannel:PARTY|h[PL]|h %s: ",
        CHAT_PARTY_GUIDE_GET    = "|Hchannel:PARTY|h[PG]|h %s: ",
        CHAT_RAID_GET           = "|Hchannel:RAID|h[R]|h %s: ",
        CHAT_RAID_LEADER_GET    = "|Hchannel:RAID|h[RL]|h %s: ",
        CHAT_RAID_WARNING_GET   = "[RW] %s: ",
        CHAT_BATTLEGROUND_GET   = "|Hchannel:BATTLEGROUND|h[BG]|h %s: ",
        CHAT_BATTLEGROUND_LEADER_GET = "|Hchannel:BATTLEGROUND|h[BGL]|h %s: ",
    }
    for k, v in pairs(short) do
        if type(_G[k]) == "string" then _G[k] = v end
    end

    -- Class-colored names in every chat type
    if ToggleChatColorNamesByClassGroup and ChatTypeGroup then
        for group in pairs(ChatTypeGroup) do
            pcall(ToggleChatColorNamesByClassGroup, true, group)
        end
    end

    -- Timestamps: switched on once. If you then choose "None" in the game's chat settings, that stays.
    if not ns.db.chatStampsOffered then
        ns.db.chatStampsOffered = true
        local ts = GetCVar("showTimestamps")
        if not ts or ts == "none" then SetCVar("showTimestamps", "%H:%M ") end
    end

    for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
        local chat = _G["ChatFrame" .. i]
        if chat then
            -- Hide the clutter buttons
            local bf = _G["ChatFrame" .. i .. "ButtonFrame"]
            ns:Silence(bf)   -- invisible and unclickable, without hooking or hiding it

            -- Mouse wheel scroll: Shift = top/bottom, Ctrl = faster
            chat:EnableMouseWheel(true)
            chat:SetScript("OnMouseWheel", function(self, delta)
                if IsShiftKeyDown() then
                    if delta > 0 then self:ScrollToTop() else self:ScrollToBottom() end
                else
                    local n = IsControlKeyDown() and 5 or 2
                    for _ = 1, n do
                        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
                    end
                end
            end)

            chat:SetFading(true)
            chat:SetTimeVisible(25)
            chat:SetFadeDuration(3)

            -- Arrow keys work in the typing bar without holding Alt. The bar sits under the chat box, where
            -- the game puts it. Above the chat box it lies over the chat tabs, which then can't be clicked
            -- while you type, so that is only done if "Chat: typing bar above the chat" is chosen.
            local eb = _G["ChatFrame" .. i .. "EditBox"]
            if eb then
                eb:SetAltArrowKeyMode(false)
                if i == 1 then
                    local point, anchor, side, gap = ns.ChatEditPlace(ns.db.chatEditTop)
                    eb:ClearAllPoints()
                    eb:SetPoint(point .. "LEFT", chat, anchor .. "LEFT", -5, gap)
                    eb:SetPoint(point .. "RIGHT", chat, anchor .. "RIGHT", 5, gap)
                    ns.chatEditState = side
                end
            end
        end
    end
end)
