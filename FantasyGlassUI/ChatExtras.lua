local _, ns = ...

-- Your name in chat ------------------------------------------------------------------------------------------
-- When someone else says your character's name in say, yell, party, raid, guild or a channel, the
-- name is picked out in a bright color so the line catches your eye. Optionally a sound plays too.
-- Whispers are left alone: they are addressed to you already.
--
-- Returns the message with each whole-word occurrence of `name` wrapped in `hex` (any capitalisation
-- of it), and how many there were. Text inside a link (an item, a player) is never touched, so links
-- keep working.
function ns.HighlightName(message, name, hex)
    if type(message) ~= "string" or type(name) ~= "string" or #name < 3 then return message, 0 end
    local pattern = "%f[%w]" .. name:gsub("%p", "%%%0"):gsub("%a", function(ch) return "[" .. ch:lower() .. ch:upper() .. "]" end) .. "%f[%W]"
    local count = 0
    local function mark(text)
        return (text:gsub(pattern, function(found) count = count + 1; return (hex or "|cffffe14d") .. found .. "|r" end))
    end
    local out, pos = {}, 1
    while true do
        local s, e = message:find("|H.-|h.-|h", pos)
        if not s then out[#out + 1] = mark(message:sub(pos)); break end
        out[#out + 1] = mark(message:sub(pos, s - 1))
        out[#out + 1] = message:sub(s, e)
        pos = e + 1
    end
    return table.concat(out), count
end

ns:NewModule("chatHighlight", function()
    local addFilter = ChatFrameUtil.AddMessageEventFilter
    if not addFilter then return end
    local me = UnitName and UnitName("player")
    if type(me) ~= "string" or ns:IsSecret(me) or #me < 3 then return end
    local lastSound = -100
    local function Filter(_, _, msg, sender, ...)
        if type(msg) ~= "string" or ns:IsSecret(msg) then return false end
        if type(sender) == "string" and not ns:IsSecret(sender) and (sender == me or sender:sub(1, #me + 1) == me .. "-") then return false end   -- you said it yourself
        local out, count = ns.HighlightName(msg, me, "|cffffe14d")
        if count == 0 then return false end
        if ns.db.chatNameSound and PlaySound and GetTime() - lastSound > 3 then
            lastSound = GetTime()
            pcall(PlaySound, (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master")
        end
        return false, out, sender, ...
    end
    ns.ChatNameFilter = Filter
    for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
                         "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_CHANNEL" }) do
        pcall(addFilter, e, Filter)
    end
end)

ns:NewModule("chatExtras", function()
    local th = ns.theme

    local function ShowURL(url) ns:ShowCopyBox(url) end

    -- Web addresses in chat become clickable -------------------------------------------------------------
    local function Linkify(_, _, msg, ...)
        if type(msg) ~= "string" or ns:IsSecret(msg) then return false end
        if not (msg:find("://", 1, true) or msg:find("www.", 1, true)) then return false end
        local out = msg:gsub("%S+", function(word)
            if word:find("^https?://") or word:find("^www%.[%w%-]+%.%a") then
                local url, tail = word:match("^(.-)([%.,;:!%?%)]*)$")      -- (a full stop after an address is not part of it)
                return "|cff66bbff|Haddon:FantasyGlassUI:" .. url .. "|h[" .. url .. "]|h|r" .. tail
            end
        end)
        return false, out, ...
    end
    local addFilter = ChatFrameUtil.AddMessageEventFilter
    if addFilter then
        for _, e in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
                             "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_WHISPER",
                             "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM",
                             "CHAT_MSG_INSTANCE_CHAT" }) do
            pcall(addFilter, e, Linkify)
        end
    end
    local function OnLink(link)
        if type(link) ~= "string" then return end
        local url = link:match("^addon:FantasyGlassUI:(.+)$")
        if url then ShowURL(url) end
    end
    if SetItemRef then
        hooksecurefunc("SetItemRef", ns:Guard("Chat links", function(link) OnLink(link) end))
    elseif EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("SetItemRef", function(_, link) OnLink(link) end, ns)
    end

    -- Copy window: the last 200 lines of a chat tab as selectable text ------------------------------------
    local function Clean(s)
        s = s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "?")
        s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|n", " ")
        return s
    end

    -- Chat history: the last lines of each chat tab are saved when you log out or reload, and shown
    -- again (dimmed) when you come back within half an hour. The combat log is not kept. Lines the
    -- game hides from add-ons are skipped. It reads the tabs once, as you leave: nothing is hooked.
    do
        local KEEP, FRESH = 40, 1800
        local root = ns.root
        local key = ns:CharKey()
        local tabs = {}                                  -- { chat, index, carried, mark } for each tab that can be read
        if type(root) == "table" and ns.db.chatHistory == false then
            if type(root.chatHistory) == "table" then root.chatHistory[key] = nil end      -- switched off: forget what was kept
            ns.chatHistoryState = "off"
        elseif type(root) == "table" then
            if type(root.chatHistory) ~= "table" then root.chatHistory = {} end
            local saved = root.chatHistory[key]
            local fresh = type(saved) == "table" and type(saved.at) == "number" and time and (time() - saved.at) < FRESH
            local restored = 0
            for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
                local chat = _G["ChatFrame" .. i]
                local isLog = (i == 2)
                if type(chat) == "table" and type(IsCombatLog) == "function" then
                    local ok, yes = pcall(IsCombatLog, chat)
                    if ok and ns.Is(yes, true) then isLog = true end
                end
                if type(chat) == "table" and not isLog and chat.AddMessage and chat.GetNumMessages and chat.GetMessageInfo then
                    local tab = { chat = chat, index = i, carried = {}, mark = 0 }
                    -- (before every tab was kept, the main window's lines were saved as "lines")
                    local old = fresh and ((type(saved.tabs) == "table" and saved.tabs[i]) or (i == 1 and saved.lines)) or nil
                    for _, line in ipairs(type(old) == "table" and old or {}) do
                        if type(line) == "table" and type(line[1]) == "string" then
                            local r, g, b = tonumber(line[2]) or 1, tonumber(line[3]) or 1, tonumber(line[4]) or 1
                            pcall(chat.AddMessage, chat, line[1], r * 0.6, g * 0.6, b * 0.6)
                            tab.carried[#tab.carried + 1] = line
                        end
                    end
                    if #tab.carried > 0 then
                        restored = restored + 1
                        pcall(chat.AddMessage, chat, "|cff777777- " .. ns:Tr("earlier messages above") .. " -|r")
                    end
                    local okN, n = pcall(chat.GetNumMessages, chat)
                    tab.mark = (okN and type(n) == "number") and n or 0      -- messages up to here were restored, not new
                    tabs[#tabs + 1] = tab
                end
            end
            ns.chatHistoryState = format("on (%d chat tabs watched, earlier lines brought back in %d)", #tabs, restored)

            local function Save()
                local out, any = {}, false
                for _, tab in ipairs(tabs) do
                    local chat, lines = tab.chat, {}
                    for _, line in ipairs(tab.carried) do lines[#lines + 1] = line end
                    local okC, count = pcall(chat.GetNumMessages, chat)
                    for i = tab.mark + 1, (okC and type(count) == "number") and count or 0 do
                        local ok, text, r, g, b = pcall(chat.GetMessageInfo, chat, i)
                        if ok and type(text) == "string" and not ns:IsSecret(text) and #text < 600 and not text:find("|K", 1, true) then
                            lines[#lines + 1] = { text, tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1 }
                        end
                    end
                    while #lines > KEEP do table.remove(lines, 1) end
                    if #lines > 0 then out[tab.index] = lines; any = true end
                end
                root.chatHistory[key] = any and { at = time and time() or 0, tabs = out } or nil
            end
            ns.chatHistoryTest = { Save = Save, tabs = tabs }
            local saver = CreateFrame("Frame")
            saver:RegisterEvent("PLAYER_LOGOUT")
            saver:SetScript("OnEvent", Save)
        end
    end

    local function ShowCopy(chat)
        local lines = {}
        local n = tonumber(chat.GetNumMessages and chat:GetNumMessages()) or 0
        for i = math.max(1, n - 199), n do
            local ok, text = pcall(chat.GetMessageInfo, chat, i)
            if ok and type(text) == "string" and not ns:IsSecret(text) then
                local good, cleaned = pcall(Clean, text)
                lines[#lines + 1] = good and cleaned or text
            end
        end
        ns:ShowTextWindow("Copy chat", table.concat(lines, "\n"), true)
    end

    -- a small "Copy" button in the corner of each chat tab, bright only on hover
    for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
        local chat = _G["ChatFrame" .. i]
        if type(chat) == "table" and chat.GetMessageInfo then
            local b = ns:SizeToLabel(ns:CreateButton(chat, "Copy", 200, 16, function() ShowCopy(chat) end), 40)
            ns:Font(b.text, 10)
            b:SetPoint("TOPRIGHT", chat, "TOPRIGHT", 0, 0)
            b:SetAlpha(0.25)
            b:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
            b:HookScript("OnLeave", function(self) self:SetAlpha(0.25) end)
        end
    end
end)
