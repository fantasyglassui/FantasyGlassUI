local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Small helpers that save clicks. Each is its own switch on the Features tab, and each starts
-- switched off: they act for you, and that should be something you chose.

------------------------------------------------------------------------------------------
-- Accept group invitations from friends and guildmates. Anyone else's invitation is left on screen
-- for you to answer as usual.
------------------------------------------------------------------------------------------
-- Is this person a friend, a Battle.net friend or a guildmate? By their unique id when the game
-- gives one, by name otherwise.
function ns:IsKnownPerson(name, guid)
    if type(guid) == "string" and not Secret(guid) and guid ~= "" then
        if C_FriendList and C_FriendList.IsFriend then
            local ok, yes = pcall(C_FriendList.IsFriend, guid)
            if ok and ns.Is(yes, true) then return "friend" end
        end
        if C_BattleNet and C_BattleNet.GetAccountInfoByGUID then
            local ok, info = pcall(C_BattleNet.GetAccountInfoByGUID, guid)
            if ok and type(info) == "table" and ns.Is(info.isFriend, true) then return "Battle.net friend" end
        end
        if IsGuildMember then
            local ok, yes = pcall(IsGuildMember, guid)
            if ok and ns.Is(yes, true) then return "guildmate" end
        end
    end
    if type(name) ~= "string" or Secret(name) or name == "" then return nil end
    local short = name:match("^([^%-]+)") or name                -- (without the realm)
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local ok, n = pcall(C_FriendList.GetNumFriends)
        for i = 1, (ok and type(n) == "number") and n or 0 do
            local okI, info = pcall(C_FriendList.GetFriendInfoByIndex, i)
            local friend = okI and type(info) == "table" and info.name
            if type(friend) == "string" and (friend == name or (friend:match("^([^%-]+)") or friend) == short) then return "friend" end
        end
    end
    if GetNumGuildMembers and GetGuildRosterInfo then
        local ok, n = pcall(GetNumGuildMembers)
        for i = 1, (ok and type(n) == "number") and n or 0 do
            local okI, member = pcall(GetGuildRosterInfo, i)
            if okI and type(member) == "string" and (member == name or (member:match("^([^%-]+)") or member) == short) then return "guildmate" end
        end
    end
    return nil
end

ns:NewModule("autoInvite", function()
    if type(AcceptGroup) ~= "function" then return end
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PARTY_INVITE_REQUEST")
    ev:SetScript("OnEvent", ns:Guard("Group invitations", function(_, _, name, _, _, _, _, _, guid)
        local who = ns:IsKnownPerson(name, guid)
        if not who then return end
        AcceptGroup()
        -- the invitation box: mark it answered, so closing it does not decline what was just accepted
        for i = 1, (type(STATICPOPUP_NUMDIALOGS) == "number" and STATICPOPUP_NUMDIALOGS or 4) do
            local popup = _G["StaticPopup" .. i]
            if type(popup) == "table" and popup.which == "PARTY_INVITE" then
                popup.inviteAccepted = 1
                if StaticPopup_Hide then pcall(StaticPopup_Hide, "PARTY_INVITE") end
                break
            end
        end
        ns:Print(format(ns:Tr("Joined %s's group (%s)."), tostring(name), ns:Tr(who)))
    end))
end)

------------------------------------------------------------------------------------------
-- Faster looting: when the game is set to auto-loot, take everything at once instead of one item
-- at a time. It does nothing unless auto-loot is in effect for that corpse (your setting, or the
-- auto-loot key held), so it never loots something you would not have looted.
------------------------------------------------------------------------------------------
ns:NewModule("fastLoot", function()
    if type(LootSlot) ~= "function" or type(GetNumLootItems) ~= "function" then return end
    local last = 0
    local function AutoLooting()
        local on = false
        if GetCVarBool then
            local ok, v = pcall(GetCVarBool, "autoLootDefault")
            on = ok and v and true or false
        end
        if IsModifiedClick then
            local ok, held = pcall(IsModifiedClick, "AUTOLOOTTOGGLE")
            if ok and held then on = not on end
        end
        return on
    end
    ns.FastLootWanted = AutoLooting
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "LOOT_READY")
    ev:SetScript("OnEvent", ns:Guard("Faster looting", function()
        if not AutoLooting() then return end
        local now = GetTime()
        if now - last < 0.25 then return end                 -- (the game can announce the same corpse twice)
        last = now
        local ok, n = pcall(GetNumLootItems)
        for slot = (ok and type(n) == "number") and n or 0, 1, -1 do pcall(LootSlot, slot) end
    end))
end)

------------------------------------------------------------------------------------------
-- Destroying a good item: the game makes you type DELETE. This types it for you. You still have to
-- press the button to confirm, and the box still names the item.
------------------------------------------------------------------------------------------
ns:NewModule("deleteFill", function()
    if type(hooksecurefunc) ~= "function" or type(StaticPopup_Show) ~= "function" then return end
    local WHICH = { DELETE_GOOD_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
    local function Fill(which)
        if not WHICH[which] then return false end
        local word = (type(DELETE_ITEM_CONFIRM_STRING) == "string" and DELETE_ITEM_CONFIRM_STRING ~= "") and DELETE_ITEM_CONFIRM_STRING or "DELETE"
        for i = 1, (type(STATICPOPUP_NUMDIALOGS) == "number" and STATICPOPUP_NUMDIALOGS or 4) do
            local popup = _G["StaticPopup" .. i]
            if type(popup) == "table" and popup.which == which then
                local box = popup.editBox or popup.EditBox or _G["StaticPopup" .. i .. "EditBox"]
                if type(box) == "table" and box.SetText then
                    box:SetText(word)
                    return true
                end
            end
        end
        return false
    end
    ns.FillDeleteBox = Fill
    pcall(hooksecurefunc, "StaticPopup_Show", function(which) pcall(Fill, which) end)
end)

------------------------------------------------------------------------------------------
-- Cutscenes you have already seen are skipped. The first time through, one plays as normal and is
-- remembered; after that it is skipped. Hold Ctrl as it starts to watch it again.
--   Films have a number, so they are remembered exactly.
--   In-game scenes have none, so they are remembered by where you were standing when one began.
------------------------------------------------------------------------------------------
ns:NewModule("skipCinematics", function()
    local function Seen() ns.root.seenScenes = ns.root.seenScenes or {}; return ns.root.seenScenes end
    local function Watching() return IsControlKeyDown and IsControlKeyDown() and true or false end
    -- true: skip it.  false: let it play (and it is now remembered).
    local function ShouldSkip(key)
        if not key then return false end
        local seen = Seen()
        if not seen[key] then seen[key] = true; return false end
        return not Watching()
    end
    ns.SceneShouldSkip = ShouldSkip
    local function PlaceKey()
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        local sub = GetSubZoneText and GetSubZoneText() or ""
        if Secret(map) or Secret(sub) then return nil end
        if type(map) ~= "number" then return nil end
        return "scene:" .. map .. ":" .. tostring(sub)
    end
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CINEMATIC_START")
    pcall(ev.RegisterEvent, ev, "PLAY_MOVIE")
    ev:SetScript("OnEvent", ns:Guard("Cutscenes", function(_, event, id)
        if event == "PLAY_MOVIE" then
            if type(id) == "number" and ShouldSkip("film:" .. id) then
                local frame = _G.MovieFrame
                if type(frame) == "table" and frame.StopMovie then pcall(frame.StopMovie, frame)
                elseif GameMovieFinished then pcall(GameMovieFinished) end
            end
        elseif ShouldSkip(PlaceKey()) then
            if CinematicFrame_CancelCinematic then pcall(CinematicFrame_CancelCinematic)
            elseif StopCinematic then pcall(StopCinematic) end
        end
    end))
end)

------------------------------------------------------------------------------------------
-- Update notice. People in your guild or group who also run Fantasy Glass UI quietly tell each other
-- which version they have. If someone has a newer one than you, you are told once that an update
-- is out. Nothing else is sent, and nothing at all during combat.
------------------------------------------------------------------------------------------
-- "8.4.10" -> { 8, 4, 10 }; nil for anything that is not three numbers
function ns:ParseVersion(text)
    if type(text) ~= "string" then return nil end
    local a, b, c = text:match("^(%d+)%.(%d+)%.(%d+)$")
    if not a then return nil end
    return { tonumber(a), tonumber(b), tonumber(c) }
end
-- true if `theirs` is newer than `mine` (compared number by number, so 8.4.10 is newer than 8.4.9)
function ns:IsNewerVersion(theirs, mine)
    local t, m = ns:ParseVersion(theirs), ns:ParseVersion(mine)
    if not t or not m then return false end
    if t[1] > m[1] + 3 then return false end                 -- (not believable: someone is playing games)
    for i = 1, 3 do
        if t[i] ~= m[i] then return t[i] > m[i] end
    end
    return false
end

ns:NewModule("versionNotice", function()
    local chat = C_ChatInfo
    if type(chat) ~= "table" or not chat.SendAddonMessage or not chat.RegisterAddonMessagePrefix then return end
    local PREFIX = "FGUI"
    pcall(chat.RegisterAddonMessagePrefix, PREFIX)
    local lastSent = {}
    local function Send(channel)
        if InCombatLockdown() then return false end
        local now = GetTime()
        if lastSent[channel] and now - lastSent[channel] < 300 then return false end    -- at most once every five minutes
        lastSent[channel] = now
        return pcall(chat.SendAddonMessage, PREFIX, "V:" .. ns.version, channel)
    end
    local function Announce()
        if IsInGuild and IsInGuild() then Send("GUILD") end
        if IsInRaid and IsInRaid() then Send("RAID")
        elseif IsInGroup and IsInGroup() then Send("PARTY") end
    end
    -- Hearing a version: remember the newest, and say so once per version
    function ns:HeardVersion(text, from)
        local version = type(text) == "string" and text:match("^V:(%d+%.%d+%.%d+)$")
        if not version or not ns:IsNewerVersion(version, ns.version) then return false end
        if not ns.newestSeen or ns:IsNewerVersion(version, ns.newestSeen) then ns.newestSeen = version end
        if ns.root and ns.root.toldVersion and not ns:IsNewerVersion(version, ns.root.toldVersion) then return false end
        if ns.root then ns.root.toldVersion = version end
        ns:PrintRaw("|cff33ccffFantasy Glass UI|r: " .. format(ns:Tr("version %s is out (you have %s). Seen from %s."), version, ns.version, tostring(from or "?")))
        if ns.Toast and ns.db.toasts then
            pcall(ns.Toast, ns, ns.MEDIA .. "icon.tga", ns:Tr("Update available"), format(ns:Tr("Fantasy Glass UI %s is out."), version))
        end
        return true
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_ADDON", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Update notice", function(_, event, prefix, text, _, sender)
        if event == "CHAT_MSG_ADDON" then
            if prefix == PREFIX and not ns:IsSecret(text) then ns:HeardVersion(text, sender) end
        else
            ns:After(event == "PLAYER_ENTERING_WORLD" and 12 or 3, Announce)
        end
    end))
    ns.AnnounceVersion = Announce
end)

------------------------------------------------------------------------------------------
-- A quieter red error line. The game prints a red line in the middle of the screen every time a key
-- is pressed that can't do anything yet: "Not enough mana", "Ability is not ready yet", "Out of
-- range". In a fight that is a constant stream. With this on, those particular lines are dropped
-- and everything else the game says there ("Inventory is full", "You can't do that yet") still shows.
------------------------------------------------------------------------------------------
-- The game's own names for the lines that are dropped. Each holds the text in your language.
ns.quietErrorNames = {
    "ERR_ABILITY_COOLDOWN", "ERR_SPELL_COOLDOWN", "ERR_ITEM_COOLDOWN", "SPELL_FAILED_SPELL_IN_PROGRESS", "ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS",
    "ERR_OUT_OF_MANA", "ERR_OUT_OF_RAGE", "ERR_OUT_OF_ENERGY", "ERR_OUT_OF_FOCUS", "ERR_OUT_OF_RUNIC_POWER", "ERR_OUT_OF_RUNES", "ERR_OUT_OF_HEALTH",
    "ERR_OUT_OF_HOLY_POWER", "ERR_OUT_OF_CHI", "ERR_OUT_OF_SOUL_SHARDS", "ERR_OUT_OF_ARCANE_CHARGES", "ERR_OUT_OF_POWER_DISPLAY",
    "ERR_OUT_OF_RANGE", "SPELL_FAILED_OUT_OF_RANGE", "ERR_SPELL_OUT_OF_RANGE", "ERR_USE_TOO_FAR", "SPELL_FAILED_TOO_CLOSE",
    "ERR_BADATTACKFACING", "ERR_BADATTACKPOS", "SPELL_FAILED_UNIT_NOT_INFRONT", "SPELL_FAILED_NOT_INFRONT", "SPELL_FAILED_NOT_BEHIND",
    "ERR_GENERIC_NO_TARGET", "ERR_NO_ATTACK_TARGET", "ERR_INVALID_ATTACK_TARGET", "SPELL_FAILED_BAD_TARGETS", "SPELL_FAILED_NO_COMBO_POINTS",
    "SPELL_FAILED_MOVING", "ERR_NOT_WHILE_MOVING", "SPELL_FAILED_NOT_READY", "ERR_CLIENT_LOCKED_OUT", "SPELL_FAILED_AURA_BOUNCED",
}
-- Is this one of the lines to drop? (An exact match with one of the game's own texts.)
function ns:IsQuietError(message)
    if type(message) ~= "string" or ns:IsSecret(message) or message == "" then return false end
    if not ns.quietErrorTexts then
        ns.quietErrorTexts = {}
        for _, name in ipairs(ns.quietErrorNames) do
            local text = _G[name]
            if type(text) == "string" and text ~= "" then ns.quietErrorTexts[text] = true end
        end
    end
    return ns.quietErrorTexts[message] == true
end
ns:NewModule("quietErrors", function()
    local frame = _G.UIErrorsFrame
    if type(frame) ~= "table" or not frame.UnregisterEvent or not frame.AddMessage or not ns:Usable(frame) then return end
    -- The game's frame stops listening for these itself; we listen instead and pass on what is kept.
    frame:UnregisterEvent("UI_ERROR_MESSAGE")
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UI_ERROR_MESSAGE")
    ev:SetScript("OnEvent", ns:Guard("Quiet errors", function(_, _, a, b)
        local message = (type(b) == "string") and b or a          -- (older clients send just the text; newer ones a number, then the text)
        if type(message) ~= "string" or ns:IsQuietError(message) then return end
        frame:AddMessage(message, 1, 0.1, 0.1, 1)
    end))
end)

------------------------------------------------------------------------------------------
-- A ring round the mouse pointer, in the accent color, so it can be found in a fight. It is not there
-- while the pointer itself is hidden (holding a mouse button to turn or look around).
------------------------------------------------------------------------------------------
ns:NewModule("cursorRing", function()
    local ring = CreateFrame("Frame", "FantasyGlassUICursorRing", UIParent)
    ring:SetSize(52, 52)
    ring:SetFrameStrata("TOOLTIP")
    ring:EnableMouse(false)
    ring.tex = ring:CreateTexture(nil, "OVERLAY")
    ring.tex:SetAllPoints()
    ring.tex:SetTexture(ns.MEDIA .. "ring.tga")
    ns:Paint(ring.tex, "SetVertexColor", "@accent", 0.75)
    local hidden = false
    ring:SetScript("OnUpdate", function()
        local looking = IsMouselooking and IsMouselooking()
        if looking then
            if not hidden then hidden = true; ring.tex:Hide() end
            return
        end
        if hidden then hidden = false; ring.tex:Show() end
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        if type(x) ~= "number" or type(y) ~= "number" or type(scale) ~= "number" or scale <= 0 then return end
        ring:ClearAllPoints()
        ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)
    ns.cursorRing = ring
end)

------------------------------------------------------------------------------------------
-- Stand up, or get off your mount, when what you just tried needs it.
--
-- When an action fails the game says why in the red line at the top of the screen: "You must be
-- standing to do that", "You are mounted". Those two are easily put right, so with these switches
-- they are: you are stood up, or taken off your mount, and the next press works.
--
-- Never off a mount in the air, and never off a flight path.
------------------------------------------------------------------------------------------
local WHY = {
    stand   = { "SPELL_FAILED_NOT_STANDING", "ERR_CANTATTACK_NOTSTANDING", "ERR_LOOT_NOTSTANDING", "ERR_TAXINOTSTANDING" },
    mounted = { "SPELL_FAILED_NOT_MOUNTED", "ERR_ATTACK_MOUNTED", "ERR_NOT_WHILE_MOUNTED", "ERR_TAXIPLAYERALREADYMOUNTED" },
}
-- Which of the two a red error line is about: "stand", "mounted", or nil for anything else.
function ns.WhyFailed(message)
    if type(message) ~= "string" or Secret(message) or message == "" then return nil end
    for kind, names in pairs(WHY) do
        for _, name in ipairs(names) do
            local text = _G[name]
            if type(text) == "string" and text == message then return kind end
        end
    end
    return nil
end
function ns:StandUp()
    if type(DoEmote) ~= "function" then return false end
    return (pcall(DoEmote, "STAND"))
end
-- Is it safe to get off? Not in the air, not on a flight path, and only if actually mounted.
function ns:CanDismount()
    local function yes(fn, ...)
        if type(fn) ~= "function" then return false end
        local ok, v = pcall(fn, ...)
        return ok and (Secret(v) or v == true)               -- (if the game will not say, assume so: the careful answer)
    end
    if yes(IsFlying) or yes(UnitOnTaxi, "player") then return false end
    if type(IsMounted) == "function" then
        local ok, v = pcall(IsMounted)
        if ok and ns.Is(v, false) then return false end
    end
    return type(Dismount) == "function"
end
function ns:GetOffMount()
    if not ns:CanDismount() then return false end
    return (pcall(Dismount))
end
do
    -- one listener for both switches; each reads its own setting when the moment comes
    local started, last = false, -10
    local function Start()
        if started then return end
        started = true
        local ev = CreateFrame("Frame")
        pcall(ev.RegisterEvent, ev, "UI_ERROR_MESSAGE")
        ev:SetScript("OnEvent", ns:Guard("Stand and dismount", function(_, _, a, b)
            local kind = ns.WhyFailed(b) or ns.WhyFailed(a)              -- (older clients send the text first)
            if not kind then return end
            local now = GetTime()
            if type(now) == "number" and now - last < 0.4 then return end      -- one press can raise the same line twice
            if kind == "stand" and ns.db.autoStand then
                if ns:StandUp() then last = now end
            elseif kind == "mounted" and ns.db.autoDismount then
                if ns:GetOffMount() then last = now end
            end
        end))
    end
    ns:NewModule("autoStand", function()
        ns.standState = type(DoEmote) == "function" and "on" or "not possible (this game client gives add-ons no way to stand up)"
        Start()
    end)
    ns:NewModule("autoDismount", function()
        ns.dismountState = type(Dismount) == "function" and "on (never in the air)" or "not possible (this game client gives add-ons no way to dismount)"
        Start()
    end)
end

------------------------------------------------------------------------------------------
-- Accept a resurrection for you. One cast by somebody who is in the middle of a fight is left on
-- screen: when to stand up again in a fight is a decision, and the game gives you time to make it.
-- Hold Shift as the offer arrives to answer it yourself.
------------------------------------------------------------------------------------------
-- "accept", or why not: "shift", "fighting" (they are in combat, or the game will not say).
function ns.ResurrectDecision(offererInCombat, shift)
    if shift then return "shift" end
    if not ns.Is(offererInCombat, false) then return "fighting" end
    return "accept"
end
ns:NewModule("autoRes", function()
    if type(AcceptResurrect) ~= "function" then
        ns.resState = "not possible (this game client gives add-ons no way to accept)"
        return
    end
    ns.resState = "on"
    local function Offerer()
        if type(ResurrectGetOfferer) ~= "function" then return nil end
        local ok, who = pcall(ResurrectGetOfferer)
        return (ok and type(who) == "string" and not Secret(who)) and who or nil
    end
    local function Accept(name)
        if type(ResurrectGetOfferer) == "function" and Offerer() == nil then return end      -- the offer has gone
        local ok = pcall(AcceptResurrect)
        if not ok then return end
        if type(StaticPopup_Hide) == "function" then
            for _, which in ipairs({ "RESURRECT", "RESURRECT_NO_SICKNESS", "RESURRECT_NO_TIMER" }) do pcall(StaticPopup_Hide, which) end
        end
        if type(name) == "string" and not Secret(name) then ns:Print("Resurrection from %s accepted.", name) end
    end
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "RESURRECT_REQUEST")
    ev:SetScript("OnEvent", ns:Guard("Resurrections", function(_, _, name)
        local fighting                                        -- true, false, or nil when the game will not say
        if type(name) == "string" and not Secret(name) and type(UnitAffectingCombat) == "function" then
            local ok, v = pcall(UnitAffectingCombat, name)
            if ok and not Secret(v) then fighting = (v == true) end
        end
        local shift = IsShiftKeyDown and IsShiftKeyDown() and true or false
        local decision = ns.ResurrectDecision(fighting, shift)
        if decision == "fighting" then
            if type(name) == "string" and not Secret(name) then ns:Print("%s is in combat: the resurrection is left for you to accept.", name) end
            return
        elseif decision ~= "accept" then
            return
        end
        -- some resurrections can only be taken after a short wait: accept when it is over
        local wait = 0
        if type(GetCorpseRecoveryDelay) == "function" then
            local ok, v = pcall(GetCorpseRecoveryDelay)
            if ok and type(v) == "number" and not Secret(v) and v > 0 then wait = v + 0.5 end
        end
        if wait > 0 then ns:After(wait, function() pcall(Accept, name) end) else Accept(name) end
    end))
end)

------------------------------------------------------------------------------------------
-- Accept a summon for you, after a few seconds in which you can still decline it. A summon that
-- arrives during a fight is taken when the fight ends, if it is still on offer.
-- Hold Shift as it arrives to answer it yourself.
------------------------------------------------------------------------------------------
ns.SUMMON_DELAY = 5
-- What to do with a summon when its few seconds are up: "accept", "wait" (in combat), or "drop".
function ns.SummonDecision(stillOffered, sameSummoner, inCombat)
    if not stillOffered or not sameSummoner then return "drop" end
    if inCombat then return "wait" end
    return "accept"
end
ns:NewModule("autoSummon", function()
    local S = type(C_SummonInfo) == "table" and C_SummonInfo or {}
    local confirm = S.ConfirmSummon or ConfirmSummon
    local summoner = S.GetSummonConfirmSummoner or GetSummonConfirmSummoner
    local area = S.GetSummonConfirmAreaName or GetSummonConfirmAreaName
    local left = S.GetSummonConfirmTimeLeft or GetSummonConfirmTimeLeft
    if type(confirm) ~= "function" then
        ns.summonState = "not possible (this game client gives add-ons no way to accept)"
        return
    end
    ns.summonState = "on"
    local function ask(fn)
        if type(fn) ~= "function" then return nil end
        local ok, v = pcall(fn)
        return (ok and not Secret(v)) and v or nil
    end
    local token, from, waiting = 0, nil, false
    local function Try(mine)
        if mine ~= token then return end                      -- declined, or a newer summon took its place
        local timeLeft = ask(left)
        local offered = (type(left) ~= "function") or (type(timeLeft) == "number" and timeLeft > 0)
        local same = (type(summoner) ~= "function") or ask(summoner) == from
        local combat = InCombatLockdown() and true or false
        local decision = ns.SummonDecision(offered, same, combat)
        waiting = (decision == "wait")
        if decision ~= "accept" then return end
        if pcall(confirm) and type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "CONFIRM_SUMMON") end
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CONFIRM_SUMMON", "CANCEL_SUMMON", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Summons", function(_, event)
        if event == "CANCEL_SUMMON" then
            token, waiting = token + 1, false
        elseif event == "PLAYER_REGEN_ENABLED" then
            if waiting then local mine = token; ns:After(0.5, function() pcall(Try, mine) end) end
        elseif event == "CONFIRM_SUMMON" then
            token, waiting = token + 1, false
            if IsShiftKeyDown and IsShiftKeyDown() then return end
            from = ask(summoner)
            local mine = token
            ns:Print("Summon from %s to %s: accepting in %d seconds. Decline it to stay.",
                type(from) == "string" and from or "?", tostring(ask(area) or "?"), ns.SUMMON_DELAY)
            ns:After(ns.SUMMON_DELAY, function() pcall(Try, mine) end)
        end
    end))
    ns.summonTest = { Try = function(mine) return Try(mine) end, token = function() return token end }
end)

------------------------------------------------------------------------------------------
-- Greed on green items. When a group roll starts for an uncommon item, Greed is chosen for you.
-- Left for you to decide: anything blue or better, anything that binds when picked up, and gear with
-- a higher item level than what you are wearing (or that cannot be compared yet).
------------------------------------------------------------------------------------------
local ROLL_GREED = 2
-- Should Greed be rolled without asking? Second result: why not.
function ns.GreedDecision(quality, bindsOnPickup, canGreed, upgrade)
    if Secret(quality) or Secret(bindsOnPickup) or Secret(canGreed) then return false, "the game hides this roll from add-ons" end
    if quality ~= 2 then return false, "not a green item" end
    if canGreed == false then return false, "Greed is not offered" end
    if bindsOnPickup then return false, "it binds when picked up" end
    if upgrade then return false, "it may be an upgrade" end
    return true
end
-- Might this item be better than what is worn? True too when it is gear that cannot be compared yet.
function ns:RollMightBeUpgrade(link)
    if type(link) ~= "string" or Secret(link) then return false end
    local level
    if C_Item and C_Item.GetDetailedItemLevelInfo then
        local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok and type(v) == "number" and not Secret(v) then level = v end
    end
    if level then return ns:IsUpgrade(link, level) and true or false end
    local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(GetInstant) ~= "function" then return false end
    local ok, _, _, _, equipLoc = pcall(GetInstant, link)
    return ok and type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG" and equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
end
ns:NewModule("autoGreed", function()
    if not (type(GetLootRollItemInfo) == "function" and type(RollOnLoot) == "function") then
        ns.greedState = "not possible (this game client gives add-ons no way to roll)"
        return
    end
    ns.greedState = "on"
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "START_LOOT_ROLL")
    ev:SetScript("OnEvent", ns:Guard("Greed on greens", function(_, _, rollID)
        local ok, _, _, _, quality, bindsOnPickup, _, canGreed = pcall(GetLootRollItemInfo, rollID)
        if not ok then return end
        local link
        if type(GetLootRollItemLink) == "function" then
            local okL, v = pcall(GetLootRollItemLink, rollID)
            if okL then link = v end
        end
        local yes, why = ns.GreedDecision(quality, bindsOnPickup, canGreed, ns:RollMightBeUpgrade(link))
        ns.greedLast = yes and "rolled Greed" or ("left for you: " .. tostring(why))
        if yes then pcall(RollOnLoot, rollID, ROLL_GREED) end
    end))
end)

------------------------------------------------------------------------------------------
-- Invite by whisper. Someone whispers you the word (by default "inv") and is invited to your
-- group. Friends and guildmates only, unless "from anyone" is switched on. Only when you could
-- invite at all: alone, or leading or assisting the group. /fgui invword <word> changes the word.
------------------------------------------------------------------------------------------
-- Is this whisper the invite word and nothing else? (Case, spaces and punctuation around it don't matter.)
function ns.WhisperAsksInvite(text, word)
    if type(text) ~= "string" or Secret(text) or type(word) ~= "string" or word == "" then return false end
    local said = text:lower():gsub("^[%s%p]+", ""):gsub("[%s%p]+$", "")
    return said == word:lower()
end
function ns:InviteWord()
    local word = ns.db and ns.db.whisperInviteWord
    if type(word) ~= "string" or word:gsub("%s", "") == "" then return "inv" end
    return word
end
function ns:CanInviteNow()
    local function yes(fn, ...)
        if type(fn) ~= "function" then return false end
        local ok, v = pcall(fn, ...)
        return ok and ns.Yes(v)
    end
    if not yes(IsInGroup) then return true end
    return yes(UnitIsGroupLeader, "player") or yes(UnitIsGroupAssistant, "player")
end
ns:NewModule("whisperInvite", function()
    local function Invite(name)
        local fn = type(C_PartyInfo) == "table" and C_PartyInfo.InviteUnit
        if type(fn) ~= "function" then fn = InviteUnit end
        if type(fn) ~= "function" then return false end
        return (pcall(fn, name))
    end
    if not ((type(C_PartyInfo) == "table" and type(C_PartyInfo.InviteUnit) == "function") or type(InviteUnit) == "function") then
        ns.whisperInviteState = "not possible (this game client gives add-ons no way to invite)"
        return
    end
    ns.whisperInviteState = "on"
    local last = {}
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_WHISPER")
    ev:SetScript("OnEvent", ns:Guard("Whisper invites", function(_, _, text, sender, ...)
        local word = ns:InviteWord()
        if not ns.WhisperAsksInvite(text, word) then return end
        if type(sender) ~= "string" or Secret(sender) or sender == "" then return end
        local guid = select(10, ...)
        if not ns.db.whisperInviteAll and not ns:IsKnownPerson(sender, guid) then return end
        if not ns:CanInviteNow() then return end
        local now = GetTime()
        if type(now) == "number" and last[sender] and now - last[sender] < 10 then return end
        last[sender] = now
        if Invite(sender) then ns:Print("Invited %s (whispered \"%s\").", sender, word) end
    end))
end)

------------------------------------------------------------------------------------------
-- Decline duels. A duel request is turned down for you, with a line in chat saying who asked.
-- Hold Shift as it arrives to answer it yourself.
------------------------------------------------------------------------------------------
ns:NewModule("declineDuels", function()
    if type(CancelDuel) ~= "function" then
        ns.duelState = "not possible (this game client gives add-ons no way to decline)"
        return
    end
    ns.duelState = "on"
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "DUEL_REQUESTED")
    pcall(ev.RegisterEvent, ev, "PET_BATTLE_PVP_DUEL_REQUESTED")
    ev:SetScript("OnEvent", ns:Guard("Decline duels", function(_, event, name)
        if IsShiftKeyDown and IsShiftKeyDown() then return end
        if event == "DUEL_REQUESTED" then
            if not pcall(CancelDuel) then return end
            if type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "DUEL_REQUESTED") end
        else
            if not (type(C_PetBattles) == "table" and type(C_PetBattles.CancelPVPDuel) == "function" and pcall(C_PetBattles.CancelPVPDuel)) then return end
            if type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "PET_BATTLE_PVP_DUEL_REQUESTED") end
        end
        if type(name) == "string" and not Secret(name) then ns:Print("Declined a duel from %s.", name) else ns:Print("Declined a duel.") end
    end))
end)

------------------------------------------------------------------------------------------
-- Confirm bind-on-pickup loot when alone. "Looting this item will bind it to you" is a real question
-- in a group, where someone else might want it. Alone there is nobody else, so with this switch it is
-- answered for you. Hold Shift as you loot to be asked all the same.
------------------------------------------------------------------------------------------
ns:NewModule("lootBindSolo", function()
    if type(ConfirmLootSlot) ~= "function" then
        ns.bindSoloState = "not possible (this game client gives add-ons no way to confirm)"
        return
    end
    ns.bindSoloState = "on"
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "LOOT_BIND_CONFIRM")
    ev:SetScript("OnEvent", ns:Guard("Bind-on-pickup loot", function(_, _, slot)
        if IsShiftKeyDown and IsShiftKeyDown() then return end
        if type(IsInGroup) == "function" then
            local ok, grouped = pcall(IsInGroup)
            if not ok or Secret(grouped) or grouped then return end      -- in a group it stays a question
        end
        if not pcall(ConfirmLootSlot, slot) then return end
        if type(StaticPopup_Hide) == "function" then pcall(StaticPopup_Hide, "LOOT_BIND") end
    end))
end)

------------------------------------------------------------------------------------------
-- Accept role checks. When the group finder asks everyone to confirm their role, yours is confirmed
-- as you last set it. Hold Shift as the check arrives to answer it yourself.
------------------------------------------------------------------------------------------
ns:NewModule("autoRoleCheck", function()
    if type(CompleteLFGRoleCheck) ~= "function" then
        ns.roleCheckState = "not possible (this game client has no role check an add-on can answer)"
        return
    end
    ns.roleCheckState = "on"
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "LFG_ROLE_CHECK_SHOW")
    ev:SetScript("OnEvent", ns:Guard("Role checks", function()
        if IsShiftKeyDown and IsShiftKeyDown() then return end
        if pcall(CompleteLFGRoleCheck, true) then ns:Print("Role check accepted.") end
    end))
end)

------------------------------------------------------------------------------------------
-- Combat alerts: a word in the middle of the screen as a fight starts and as it ends, gone in a
-- moment. Movable like any other panel.
------------------------------------------------------------------------------------------
ns.COMBAT_ALERT_TIME = 1.4
ns:NewModule("combatAlert", function()
    local holder = CreateFrame("Frame", "FantasyGlassUICombatAlert", UIParent)
    holder:SetSize(220, 30)
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
    holder:SetFrameStrata("HIGH")
    local text = ns:NewText(holder, 22, "CENTER")
    text:SetPoint("CENTER")
    holder:SetAlpha(0)
    local left = 0
    local function Say(starting)
        text:SetText((starting and "+ " or "- ") .. ns:Tr("Combat"))
        if starting then text:SetTextColor(1, 0.30, 0.25) else text:SetTextColor(0.35, 0.90, 0.40) end
        left = ns.COMBAT_ALERT_TIME
        holder:SetAlpha(1)
        ns.combatAlertLast = starting and "start" or "end"
    end
    holder:SetScript("OnUpdate", function(self, elapsed)
        if ns.moving then                                   -- arranging the screen: shown, so it can be seen and placed
            if not self.suiSample then self.suiSample = true; text:SetText("+ " .. ns:Tr("Combat")); text:SetTextColor(1, 0.30, 0.25); self:SetAlpha(1) end
            return
        elseif self.suiSample then
            self.suiSample = nil
            self:SetAlpha(left > 0 and 1 or 0)
        end
        if left <= 0 then return end
        left = left - (tonumber(elapsed) or 0)
        if left <= 0 then self:SetAlpha(0) return end
        -- hold, then fade over the last half second (or simply vanish, with "less motion" on)
        if ns:Motion() and left < 0.5 then self:SetAlpha(left / 0.5) end
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", ns:Guard("Combat alerts", function(_, event) Say(event == "PLAYER_REGEN_DISABLED") end))
    ns:RegisterMovable(holder, "combatAlert", "Combat Alert")
    ns.combatAlertTest = { holder = holder, text = text, Say = Say }
end)

------------------------------------------------------------------------------------------
-- Ready check alert: when someone starts a ready check, a sound that plays even with the game's sound
-- effects turned down or the game in another window, the game's icon flashing in the taskbar, and a
-- notice saying who asked. Not for a check you started yourself.
------------------------------------------------------------------------------------------
ns:NewModule("readyAlert", function()
    ns.readyAlertState = "on"
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "READY_CHECK")
    ev:SetScript("OnEvent", ns:Guard("Ready check alert", function(_, _, who)
        local name = (type(who) == "string" and not Secret(who)) and who or nil
        local okN, me = pcall(UnitName, "player")
        if name and okN and ns.Is(name, me) then return end       -- your own check
        if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then pcall(PlaySound, SOUNDKIT.READY_CHECK, "Master") end
        if type(FlashClientIcon) == "function" then pcall(FlashClientIcon) end
        ns.readyAlertLast = name or "someone"
        if ns.Toast then
            pcall(ns.Toast, ns, nil, ns:Tr("Ready check"), name and format(ns:Tr("%s asks if you are ready."), name) or ns:Tr("Are you ready?"), "?")
        else
            ns:Print("Ready check.")
        end
    end))
end)
