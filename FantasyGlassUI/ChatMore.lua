local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end
local PUBLIC = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_CHANNEL" }
local TALK = { "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
               "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_CHANNEL" }
local function AddFilter(events, fn)
    local add = ChatFrameUtil.AddMessageEventFilter
    if type(add) ~= "function" then return false end
    for _, e in ipairs(events) do pcall(add, e, fn) end
    return true
end
local function Me()
    local me = UnitName and UnitName("player")
    return (type(me) == "string" and not Secret(me)) and me or nil
end
local function Mine(sender, me)
    return type(sender) == "string" and not Secret(sender) and me and (sender == me or sender:sub(1, #me + 1) == me .. "-")
end

------------------------------------------------------------------------------------------
-- Keyword alerts: words you choose are picked out in any channel, with a sound.
--   /fgui keyword LFM      (the same again takes it off)
------------------------------------------------------------------------------------------
-- Returns the message with the words picked out, and how many were found.
function ns.HighlightWords(message, words, hex)
    local total = 0
    for _, word in ipairs(words or {}) do
        local out, count = ns.HighlightName(message, word, hex or "|cff66ff99")
        if count > 0 then message, total = out, total + count end
    end
    return message, total
end
ns:NewModule("chatKeywords", function()
    local me = Me()
    local lastSound = -100
    local function Filter(_, _, msg, sender, ...)
        if type(msg) ~= "string" or Secret(msg) or Mine(sender, me) then return false end
        local words = ns:SavedList("keywords")
        if #words == 0 then return false end
        local out, count = ns.HighlightWords(msg, words)
        if count == 0 then return false end
        if PlaySound and GetTime() - lastSound > 3 then
            lastSound = GetTime()
            pcall(PlaySound, (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081, "Master")
        end
        ns.keywordHits = (ns.keywordHits or 0) + 1
        return false, out, sender, ...
    end
    ns.KeywordFilter = Filter
    AddFilter(TALK, Filter)
end)

------------------------------------------------------------------------------------------
-- Spam filter: the same line from the same person within a few seconds is shown once.
------------------------------------------------------------------------------------------
ns.SPAM_SECONDS = 10
-- Should this line be hidden? `store` remembers what was said; `line` is the game's number for the
-- message (the same message is offered once for every chat tab, and must get the same answer each time).
function ns.SpamCheck(store, sender, message, now, line)
    if line ~= nil and store.lastLine == line then return store.lastAnswer end
    local key = tostring(sender) .. "\1" .. tostring(message)
    local before = store[key]
    local hide = (before ~= nil) and (now - before < ns.SPAM_SECONDS)
    store[key] = now
    store.lastLine, store.lastAnswer = line, hide
    store.n = (store.n or 0) + 1
    if store.n > 300 then                                      -- (forget what is old)
        for k, v in pairs(store) do if type(v) == "number" and k ~= "n" and now - v > ns.SPAM_SECONDS then store[k] = nil end end
        store.n = 0
    end
    return hide
end
ns:NewModule("chatSpam", function()
    local store, me = {}, Me()
    local function Filter(_, _, msg, sender, _, _, _, _, _, _, _, _, line)
        if type(msg) ~= "string" or Secret(msg) or type(sender) ~= "string" or Secret(sender) or Mine(sender, me) then return false end
        if Secret(line) then line = nil end
        if ns.SpamCheck(store, sender, msg, GetTime(), line) then
            ns.spamHidden = (ns.spamHidden or 0) + 1
            return true
        end
        return false
    end
    ns.SpamFilter = Filter
    AddFilter(PUBLIC, Filter)
end)

------------------------------------------------------------------------------------------
-- Names in chat: Alt-click one to invite. The right-click menu gains "Copy name" and "Guild invite".
------------------------------------------------------------------------------------------
-- The player a chat link names: "player:Bob-Realm:123:..." -> "Bob-Realm".
function ns.PlayerOfLink(link)
    if type(link) ~= "string" then return nil end
    return link:match("^player:([^:]+)")
end
ns:NewModule("chatNames", function()
    if type(hooksecurefunc) == "function" and type(SetItemRef) == "function" then
        pcall(hooksecurefunc, "SetItemRef", ns:Guard("Chat names", function(link)
            if not ns.Yes(IsAltKeyDown and IsAltKeyDown()) then return end
            local name = ns.PlayerOfLink(link)
            if not name then return end
            ns.InvitePlayer(name)
            ns:Print("Invited %s.", name)
            local box = ChatFrameUtil.GetActiveWindow()       -- (the click also opened a whisper: close it)
            if type(box) == "table" and box.Hide then pcall(ChatFrameUtil.DeactivateChat, box) end
        end))
    end
    local added = 0
    if type(Menu) == "table" and type(Menu.ModifyMenu) == "function" then
        for _, tag in ipairs({ "MENU_UNIT_FRIEND", "MENU_UNIT_PLAYER", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_COMMUNITIES_GUILD_MEMBER" }) do
            local ok = pcall(Menu.ModifyMenu, tag, function(_, root, context)
                local name = type(context) == "table" and context.name
                if type(name) ~= "string" or Secret(name) then return end
                if type(context.server) == "string" and context.server ~= "" then name = name .. "-" .. context.server end
                pcall(function()
                    root:CreateDivider()
                    root:CreateButton(ns:Tr("Copy name"), function() if ns.ShowCopyBox then ns:ShowCopyBox(name) end end)
                    root:CreateButton(ns:Tr("Guild invite"), function()
                        pcall(C_GuildInfo.Invite, name)
                    end)
                end)
            end)
            if ok then added = added + 1 end
        end
    end
    ns.chatNamesState = "Alt-click invites" .. ((added > 0) and "; right-click menu has Copy name and Guild invite" or "; this game client's right-click menu cannot be added to")
end)

------------------------------------------------------------------------------------------
-- Whisper windows: one window with a tab for each conversation, and a line to answer in.
------------------------------------------------------------------------------------------
ns.whispers = { order = {}, by = {} }
-- Add a line to a conversation; the conversation moves to the top. Returns it.
function ns.WhisperAdd(store, name, text, mine, now)
    local c = store.by[name]
    if not c then c = { name = name, lines = {}, unread = 0 }; store.by[name] = c end
    c.lines[#c.lines + 1] = { text = text, mine = mine and true or false, at = now }
    while #c.lines > 100 do table.remove(c.lines, 1) end
    if not mine then c.unread = c.unread + 1 end
    for i = #store.order, 1, -1 do if store.order[i] == name then table.remove(store.order, i) end end
    table.insert(store.order, 1, name)
    while #store.order > 12 do store.by[table.remove(store.order)] = nil end
    return c
end
local wwin
local function WhisperDraw()
    local w, store = wwin, ns.whispers
    if not w then return end
    if not (w.current and store.by[w.current]) then w.current = store.order[1] end
    for i = 1, 12 do
        local name, tab = store.order[i], w.tabs[i]
        if name then
            if not tab then
                tab = ns:CreateButton(w, "", 112, 20, function(self) w.current = self.who; WhisperDraw() end)
                tab:SetPoint("TOPLEFT", 12, -40 - (i - 1) * 22)
                w.tabs[i] = tab
            end
            local c = store.by[name]
            tab.who = name
            tab.text:SetText(name:gsub("%-.*$", "") .. ((c.unread > 0 and name ~= w.current) and (" (" .. c.unread .. ")") or ""))
            tab:Show()
        elseif tab then
            tab:Hide()
        end
    end
    w.log:Clear()
    local c = w.current and store.by[w.current]
    if c then
        c.unread = 0
        w.title:SetText(c.name)
        for _, line in ipairs(c.lines) do
            if line.mine then w.log:AddMessage("|cff9aa4b4" .. ns:Tr("You") .. ":|r " .. line.text, 0.85, 0.85, 0.85)
            else w.log:AddMessage(ns:AccentHex() .. c.name:gsub("%-.*$", "") .. ":|r " .. line.text, 1, 0.75, 1) end
        end
    else
        w.title:SetText(ns:Tr("Whispers"))
    end
end
function ns:ShowWhispers(name)
    if not wwin then
        local w = CreateFrame("Frame", "FantasyGlassUIWhispers", UIParent, ns.template)
        w:SetSize(470, 300)
        w:SetPoint("CENTER", UIParent, "CENTER", -260, -60)
        w:SetFrameStrata("HIGH")
        w:SetBackdrop(ns.BACKDROP)
        ns:Paint(w, "SetBackdropColor", "window", 0.97)
        ns:Paint(w, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(w)
        w:EnableMouse(true); w:SetMovable(true); if w.SetClampedToScreen then w:SetClampedToScreen(true) end; w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(self) self:StartMoving() end)
        ns:KeepPlace(w, "Whispers")
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, "FantasyGlassUIWhispers") end   -- (Escape closes it, like every window)
        w.title = ns:NewText(w, 14, "LEFT")
        w.title:SetPoint("TOPLEFT", 14, -12)
        ns:Paint(w.title, "SetTextColor", "@accent")
        local close = ns:CreateButton(w, "X", 22, 20, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        w.tabs = {}
        w.log = CreateFrame("ScrollingMessageFrame", nil, w)
        w.log:SetPoint("TOPLEFT", 132, -40)
        w.log:SetPoint("BOTTOMRIGHT", -12, 40)
        if w.log.SetFontObject and _G.ChatFontNormal then w.log:SetFontObject(_G.ChatFontNormal) end
        if w.log.SetJustifyH then w.log:SetJustifyH("LEFT") end
        if w.log.SetFading then w.log:SetFading(false) end
        if w.log.SetMaxLines then w.log:SetMaxLines(100) end
        w.log:EnableMouseWheel(true)
        w.log:SetScript("OnMouseWheel", function(self, delta) if delta > 0 then self:ScrollUp() else self:ScrollDown() end end)
        -- the add-on's own text box, like every other one, with a hint of what it is for
        local ok, box = pcall(ns.CreateEditBox, ns, w, 318, 22, "Write a reply, then press Enter")
        if ok and box then
            box:ClearAllPoints()
            box:SetPoint("BOTTOMLEFT", 138, 10)
            box:SetPoint("BOTTOMRIGHT", -14, 10)
            if box.SetMaxLetters then box:SetMaxLetters(255) end
            box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            box:SetScript("OnEnterPressed", ns:Guard("Whispers", function(self)
                local text = ns.Trim(self:GetText())
                if text ~= "" and w.current and not ns:SayMessagingLocked() then
                    pcall(C_ChatInfo.SendChatMessage, text, "WHISPER", nil, w.current)
                end
                self:SetText("")
            end))
            w.box = box
        end
        wwin = w
    end
    if name and ns.whispers.by[name] then wwin.current = name end
    wwin:Show()
    WhisperDraw()
    return wwin
end
ns:NewModule("whisperWindow", function()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Whispers", function(_, event, message, who)
        if type(message) ~= "string" or Secret(message) or type(who) ~= "string" or Secret(who) then return end
        local mine = (event == "CHAT_MSG_WHISPER_INFORM")
        ns.WhisperAdd(ns.whispers, who, message, mine, time and time() or 0)
        if wwin and ns.Yes(wwin:IsShown()) then WhisperDraw()
        elseif not mine and not InCombatLockdown() then ns:ShowWhispers(who) end      -- (never pops up in a fight)
    end))
end)

------------------------------------------------------------------------------------------
-- Chat tab setup: /fgui chattabs makes a "Loot" tab and a "Whispers" tab.
------------------------------------------------------------------------------------------
ns.chatTabPlans = {
    { name = "Loot", groups = { "LOOT", "MONEY", "CURRENCY", "COMBAT_XP_GAIN", "COMBAT_FACTION_CHANGE", "SKILL", "TRADESKILLS" } },
    { name = "Whispers", groups = { "WHISPER", "BN_WHISPER" } },
}
function ns:SetupChatTabs()
    if type(FCF_OpenNewWindow) ~= "function" then
        ns:Print("This game client does not let add-ons make chat tabs.")
        return 0
    end
    local have = {}
    for i = 1, Constants.ChatFrameConstants.MaxChatWindows do
        local name = GetChatWindowInfo and GetChatWindowInfo(i)
        if type(name) == "string" and not Secret(name) then have[name] = true end
    end
    local made = 0
    for _, plan in ipairs(ns.chatTabPlans) do
        local title = ns:Tr(plan.name)
        if not have[title] and not have[plan.name] then
            local ok, frame = pcall(FCF_OpenNewWindow, title)
            if ok and type(frame) == "table" then
                if frame.RemoveAllMessageGroups then pcall(frame.RemoveAllMessageGroups, frame) end
                if frame.RemoveAllChannels then pcall(frame.RemoveAllChannels, frame) end
                for _, group in ipairs(plan.groups) do if frame.AddMessageGroup then pcall(frame.AddMessageGroup, frame, group) end end
                made = made + 1
            end
        end
    end
    if made > 0 then ns:Print("Made %d chat tabs. Right-click a tab to change what it shows.", made)
    else ns:Print("The Loot and Whispers tabs are there already.") end
    return made
end

------------------------------------------------------------------------------------------
-- Short commands: /rl reloads, /rc starts a ready check, /tt whispers your target.
-- Each is left alone if another add-on already has it.
------------------------------------------------------------------------------------------
ns:NewModule("shortCommands", function()
    local taken = type(hash_SlashCmdList) == "table" and hash_SlashCmdList or {}
    local made = {}
    local function Add(slash, key, fn)
        if rawget(taken, slash:upper()) ~= nil or type(SlashCmdList) ~= "table" then return end
        _G["SLASH_" .. key .. "1"] = slash
        SlashCmdList[key] = fn
        made[#made + 1] = slash
    end
    -- /rl is the game's own /reload handler itself where the game has one, so it runs the same way;
    -- otherwise ours (and if the game refuses it, Blocked.lua says to type /reload).
    local own = type(SlashCmdList.RELOAD) == "function" and SlashCmdList.RELOAD or nil
    Add("/rl", "FANTASYGLASSUIRL", own or function() if ReloadUI then ReloadUI() end end)
    Add("/rc", "FANTASYGLASSUIRC", function() C_PartyInfo.DoReadyCheck() end)
    Add("/tt", "FANTASYGLASSUITT", function(text)
        if not (ns.Yes(UnitExists("target")) and ns.Yes(UnitIsPlayer("target"))) then ns:Print("Target a player first."); return end
        local name, realm = UnitName("target")
        if type(name) ~= "string" or Secret(name) then return end
        if type(realm) == "string" and not Secret(realm) and realm ~= "" then name = name .. "-" .. realm end
        text = ns.Trim(text)
        if text == "" then pcall(ChatFrameUtil.SendTell, name) return end
        if not ns:SayMessagingLocked() then pcall(C_ChatInfo.SendChatMessage, text, "WHISPER", nil, name) end
    end)
    ns.shortCommandsState = (#made > 0) and ("on: " .. table.concat(made, " ")) or "on, but another add-on already has all three"
    ns.shortCommandsMade = made
end)

------------------------------------------------------------------------------------------
-- Guild notices: the message of the day as a notice when you log in or it changes, and a notice
-- when a friend or guild mate comes online.
------------------------------------------------------------------------------------------
ns:NewModule("guildNotices", function()
    local shown
    local function Motd(text)
        if type(text) ~= "string" or Secret(text) or text == "" or text == shown then return false end
        shown = text
        if ns.Toast then pcall(ns.Toast, ns, nil, ns:Tr("Guild message of the day"), text) end
        return true
    end
    local online = ns.GamePattern(type(ERR_FRIEND_ONLINE_SS) == "string" and ERR_FRIEND_ONLINE_SS or "|Hplayer:%s|h[%s]|h has come online.")
    local function Online(message)
        if type(message) ~= "string" or Secret(message) or not online then return false end
        local _, name = message:match(online)
        if not name then return false end
        if ns.Toast then pcall(ns.Toast, ns, nil, name, ns:Tr("has come online")) end
        return name
    end
    ns.guildNoticeTest = { Motd = Motd, Online = Online }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "GUILD_MOTD", "PLAYER_ENTERING_WORLD", "CHAT_MSG_SYSTEM" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Guild notices", function(_, event, text)
        if event == "GUILD_MOTD" then Motd(text)
        elseif event == "CHAT_MSG_SYSTEM" then Online(text)
        else
            ns:After(8, function()
                local ok, motd = pcall(C_GuildInfo.GetMOTD); if ok then Motd(motd) end
            end)
        end
    end))
end)

------------------------------------------------------------------------------------------
-- Friends list: names in class colors, with level and zone.
------------------------------------------------------------------------------------------
local classToken
-- The game's code for a class from its name in your language ("Schamane" -> "SHAMAN").
function ns.ClassTokenOf(localName)
    if type(localName) ~= "string" then return nil end
    if not classToken then
        classToken = {}
        for _, t in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE, _G.LOCALIZED_CLASS_NAMES_FEMALE }) do
            if type(t) == "table" then for token, name in pairs(t) do if type(name) == "string" then classToken[name] = token end end end
        end
    end
    return classToken[localName]
end
ns:NewModule("friendColors", function()
    if type(hooksecurefunc) ~= "function" or type(FriendsFrame_UpdateFriendButton) ~= "function" or not (C_FriendList and C_FriendList.GetFriendInfoByIndex) then
        ns.friendColorsState = "this game client's friends list cannot be added to"
        return
    end
    ns.friendColorsState = "on"
    pcall(hooksecurefunc, "FriendsFrame_UpdateFriendButton", ns:Guard("Friends list", function(button)
        if type(button) ~= "table" or button.buttonType ~= _G.FRIENDS_BUTTON_TYPE_WOW or type(button.id) ~= "number" then return end
        local info = C_FriendList.GetFriendInfoByIndex(button.id)
        if type(info) ~= "table" or not ns.Is(info.connected, true) or type(info.name) ~= "string" or Secret(info.name) then return end
        local token = ns.ClassTokenOf(info.className)
        local ok, r, g, b = pcall(function() return ns:ClassRGB(token) end)
        if not (token and ok and type(r) == "number") then return end
        if button.name and button.name.SetText then
            button.name:SetText(format("|cff%02x%02x%02x%s|r, %s", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), info.name, tostring(info.level or "")))
        end
        if button.info and button.info.SetText and type(info.area) == "string" then button.info:SetText(info.area) end
        ns.friendColored = (ns.friendColored or 0) + 1
    end))
end)
