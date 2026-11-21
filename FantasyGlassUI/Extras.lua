local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Dragging the game's own windows. The character window, spellbook, vendor, mailbox and the rest
-- can be dragged by any empty part of them (the title bar is the easy place), and each opens where
-- you left it. The game places these windows itself every time one opens or closes, so the saved
-- place is put back a moment after it does.
--   * A window the game protects cannot be moved during combat; a drag then does nothing.
--   * /fgui windows reset (or the button on the Layout tab) forgets every saved place.
-- Left out on purpose: the world map (it resizes and re-centres itself), the small question boxes,
-- the loot window (it opens at the mouse) and the game menu.
------------------------------------------------------------------------------------------
ns.windowMoveSkip = {
    StaticPopup1 = true, StaticPopup2 = true, StaticPopup3 = true, StaticPopup4 = true, WorldMapFrame = true, LootFrame = true,
    GameMenuFrame = true, SettingsPanel = true, ReadyCheckFrame = true, RolePollPopup = true, BonusRollFrame = true, MasterLooterFrame = true,
}
function ns.WindowPosValid(p)
    return type(p) == "table" and type(p[1]) == "string" and type(p[2]) == "string" and type(p[3]) == "number" and type(p[4]) == "number"
end
local function Positions()
    if type(ns.db.windowPos) ~= "table" then ns.db.windowPos = {} end
    return ns.db.windowPos
end
local function Locked(win)                                   -- protected, and a fight is on
    if not InCombatLockdown() then return false end
    local ok, protected = pcall(win.IsProtected, win)
    return (not ok) or (protected and true or false)
end
function ns:PlaceWindow(win, name)
    local p = Positions()[name]
    if not ns.db.moveWindows or not ns.WindowPosValid(p) or Locked(win) then return false end
    win.suiPlacing = true
    win:ClearAllPoints()
    win:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    win.suiPlacing = nil
    return true
end
function ns:MakeWindowMovable(win, name)
    if type(win) ~= "table" or win.suiMove then return false end
    if not ns:Usable(win) or not win.SetMovable or not win.StartMoving or not win.HookScript then return false end
    if InCombatLockdown() then return false end
    win:SetMovable(true)
    if win.SetClampedToScreen then win:SetClampedToScreen(true) end      -- it can't be dragged off the screen and lost
    local move = {}
    function move.Start()
        if not ns.db.moveWindows or Locked(win) then return end
        move.dragging = true
        win:StartMoving()
    end
    function move.Stop()
        if not move.dragging then return end
        move.dragging = nil
        win:StopMovingOrSizing()
        if win.SetUserPlaced then pcall(win.SetUserPlaced, win, false) end   -- (we remember the place; the game need not)
        local point, _, relPoint, x, y = win:GetPoint(1)
        if type(point) == "string" and type(x) == "number" and type(y) == "number" then
            Positions()[name] = { point, type(relPoint) == "string" and relPoint or point, x, y }
        end
    end
    win.suiMove = move
    local handles = { win }
    local title = win.TitleContainer
    if type(title) == "table" and title.EnableMouse and title.HookScript and ns:Usable(title) then
        title:EnableMouse(true)
        handles[2] = title
    end
    for _, h in ipairs(handles) do
        if h.RegisterForDrag then
            h:RegisterForDrag("LeftButton")
            h:HookScript("OnDragStart", move.Start)
            h:HookScript("OnDragStop", move.Stop)
        end
    end
    local function Again()                                   -- the game placed it: put it back where it was left
        if win.suiPlacing or move.dragging or move.queued or not ns.WindowPosValid(Positions()[name]) then return end
        move.queued = true
        ns:After(0, function() move.queued = nil; ns:PlaceWindow(win, name) end)
    end
    win:HookScript("OnShow", Again)
    if hooksecurefunc then pcall(hooksecurefunc, win, "SetPoint", Again) end
    return true
end
function ns:ResetWindowPositions()
    ns.db.windowPos = {}
    ns:Print("The game's windows will open in their usual places again.")
end
ns:NewModule("moveWindows", function()
    local pending = {}
    for _, def in ipairs(ns.windowNames or {}) do
        if not ns.windowMoveSkip[def[1]] then pending[#pending + 1] = def[1] end
    end
    pending[#pending + 1] = "LFGParentFrame"
    local function Try()
        if InCombatLockdown() then return end
        for i = #pending, 1, -1 do
            local win = _G[pending[i]]
            if type(win) == "table" and (ns:MakeWindowMovable(win, pending[i]) or win.suiMove) then table.remove(pending, i) end
        end
    end
    Try()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_LOADED")                         -- windows that load when first opened
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", ns:Guard("Movable windows", Try))
end)

------------------------------------------------------------------------------------------
-- Class-colored names in chat. The game can do this itself; it is a setting most people never find.
-- This turns it on, and puts the game's setting back if the switch is turned off again.
------------------------------------------------------------------------------------------
local CHAT_TYPES = { "SAY", "EMOTE", "YELL", "GUILD", "OFFICER", "WHISPER", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
                     "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "CHANNEL1", "CHANNEL2", "CHANNEL3", "CHANNEL4", "CHANNEL5", "CHANNEL6" }
local function CVar(name, value)
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if value == nil then
        local ok, v = pcall(get, name)
        return ok and type(v) == "string" and v or nil
    end
    return pcall(set, name, value)
end
------------------------------------------------------------------------------------------
-- Game settings: a few of the game's own settings that people usually change by hand, or never find,
-- as switches. Switching one on remembers what the setting was; switching it off puts that back
-- (unless you have changed it yourself since). They take effect at once.
------------------------------------------------------------------------------------------
ns.TWEAKS = {
    { key = "tweakCamera",     cvar = "cameraDistanceMaxZoomFactor",     on = "2.6", atLeast = true },      -- zoom out further
    { key = "tweakErrorVoice", cvar = "Sound_EnableErrorSpeech",         on = "0" },                        -- "Not enough mana!"
    { key = "tweakBgSound",    cvar = "Sound_EnableSoundWhenGameIsInBG", on = "1" },                        -- hear the game while in another window
    { key = "tweakScreenshot", cvar = "screenshotQuality",               on = "10", atLeast = true },
    { key = "tweakAutoLoot", cvar = "autoLootDefault", on = "1" },
    { key = "tweakLootMouse", cvar = "lootUnderMouse", on = "1" },
    { key = "tweakSelfCast", cvar = "autoSelfCast", on = "1" },
    { key = "tweakPlateRange", cvar = "nameplateMaxDistance", on = "41", atLeast = true },
    { key = "tweakPlateStack", cvar = "nameplateMotion", on = "1" },
    { key = "tweakCameraFollow", cvar = "cameraSmoothStyle", on = "0" },
    { key = "tweakWeather", cvar = "weatherDensity", on = "0", atMost = true },
    { key = "tweakBgFps", cvar = "maxFPSBk", on = "30", atMost = true },
    { key = "tweakTutorials", cvar = "showTutorials", on = "0" },
    { key = "tweakProfanity", cvar = "profanityFilter", on = "0" },
    { key = "tweakMusic", cvar = "Sound_EnableMusic", on = "0" },
    { key = "tweakAmbience", cvar = "Sound_EnableAmbience", on = "0" },
    { key = "tweakDeathGrey", cvar = "ffxDeath", on = "0" },
    { key = "tweakGlow", cvar = "ffxGlow", on = "0" },
}
local function Same(a, b)
    local x, y = tonumber(a), tonumber(b)
    if x and y then return math.abs(x - y) < 0.001 end
    return a == b
end
function ns:ApplyTweaks()
    if not ns.db or not ns.root then return false end
    if InCombatLockdown() then ns.tweaksPending = true; return false end      -- (the game refuses some settings in a fight)
    ns.tweaksPending = nil
    if type(ns.root.tweakBefore) ~= "table" then ns.root.tweakBefore = {} end
    local before = ns.root.tweakBefore
    ns.tweakState = {}
    for _, t in ipairs(ns.TWEAKS) do
        local now = CVar(t.cvar)
        local state
        if now == nil then
            state = "this game client has no such setting"
        elseif ns.db[t.key] then
            if before[t.cvar] == nil then before[t.cvar] = now end
            local enough = Same(now, t.on) or (t.atLeast and tonumber(now) and tonumber(now) >= tonumber(t.on))
                or (t.atMost and tonumber(now) and tonumber(now) > 0 and tonumber(now) <= tonumber(t.on))      -- (0 frames a second means "no limit")
            if not enough then CVar(t.cvar, t.on) end
            state = "on"
        else
            if before[t.cvar] ~= nil then
                if Same(now, t.on) and not Same(before[t.cvar], t.on) then CVar(t.cvar, before[t.cvar]) end
                before[t.cvar] = nil
            end
            state = "off"
        end
        ns.tweakState[t.key] = state
    end
    return true
end
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", ns:Guard("Game settings", function(_, event)
        if event == "PLAYER_LOGIN" then ns:After(1, function() pcall(ns.ApplyTweaks, ns) end)
        elseif ns.tweaksPending then ns:ApplyTweaks() end
    end))
end

------------------------------------------------------------------------------------------
-- Vendors: mark what you already know. A recipe, pattern, pet or mount on sale that you have already
-- learned is washed in red, so you don't buy it twice. The game says "Already known" in the item's
-- tooltip; that line is what is looked for. The wash is a layer of our own over the item's button:
-- nothing of the game's is recolored.
------------------------------------------------------------------------------------------
local scanTip
function ns:MerchantItemKnown(index)
    local known = _G.ITEM_SPELL_KNOWN
    if type(known) ~= "string" or type(index) ~= "number" then return false end
    if type(C_TooltipInfo) == "table" and type(C_TooltipInfo.GetMerchantItem) == "function" then
        local ok, data = pcall(C_TooltipInfo.GetMerchantItem, index)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                if type(line) == "table" and ns.Is(line.leftText, known) then return true end
            end
        end
        return false
    end
    -- older clients: read a tooltip that is never shown
    if not scanTip then
        local ok, tip = pcall(CreateFrame, "GameTooltip", "FantasyGlassUIScanTip", nil, "GameTooltipTemplate")
        if not ok or not tip then return false end
        scanTip = tip
    end
    if not (scanTip.SetOwner and scanTip.SetMerchantItem and scanTip.NumLines) then return false end
    scanTip:SetOwner(WorldFrame or UIParent, "ANCHOR_NONE")
    if not pcall(scanTip.SetMerchantItem, scanTip, index) then return false end
    local okN, lines = pcall(scanTip.NumLines, scanTip)
    for i = 1, (okN and type(lines) == "number") and lines or 0 do
        local fs = _G["FantasyGlassUIScanTipTextLeft" .. i]
        if fs and fs.GetText and ns.Is(fs:GetText(), known) then return true end
    end
    return false
end
ns:NewModule("vendorKnown", function()
    ns.vendorKnownState = "waiting for a vendor"
    local dirty, lastKey = true, nil
    local function Mark()
        local frame = _G.MerchantFrame
        if not (type(frame) == "table" and ns:Usable(frame) and frame.IsShown and frame:IsShown()) then lastKey = nil; return end
        local okC, count = pcall(GetMerchantNumItems)
        local key = tostring(frame.page) .. ":" .. tostring(okC and count or "?") .. ":" .. tostring(frame.selectedTab)
        if not dirty and key == lastKey then return end
        dirty, lastKey = false, key
        local marked = 0
        for i = 1, 12 do
            local button = _G["MerchantItem" .. i .. "ItemButton"]
            if type(button) == "table" and ns:Usable(button) and button.GetID then
                if not button.suiKnown then
                    local wash = button:CreateTexture(nil, "OVERLAY")
                    wash:SetAllPoints()
                    wash:SetTexture(ns.FLAT)
                    wash:SetVertexColor(0.85, 0.10, 0.10, 0.45)
                    wash:Hide()
                    button.suiKnown = wash
                end
                local shown = button.IsVisible and button:IsVisible()
                local index = button:GetID()
                -- (the buy-back tab shows other things on the same buttons)
                local onSale = frame.selectedTab == nil or ns.Is(frame.selectedTab, 1)
                if shown and onSale and type(index) == "number" and index > 0 and ns:MerchantItemKnown(index) then
                    button.suiKnown:Show()
                    marked = marked + 1
                else
                    button.suiKnown:Hide()
                end
            end
        end
        ns.vendorKnownState = format("on (%d marked on the page last looked at)", marked)
    end
    ns.vendorKnownTest = { Mark = function() dirty = true; return Mark() end }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "NEW_RECIPE_LEARNED", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Extras events", function() dirty = true end))
    ns:Every(0.3, "Vendor: already known", function() Mark() end)
end)

ns:NewModule("chatClassColors", function()
    local now = CVar("chatClassColorOverride")
    if now then                                              -- "0" = always, "1" = never, "2" = channel by channel
        if now ~= "0" and ns.root and ns.root.chatClassPrev == nil then ns.root.chatClassPrev = now end
        CVar("chatClassColorOverride", "0")
        ns.chatClassState = "on (the game's own setting)"
    elseif type(SetChatColorNameByClass) == "function" then
        for _, kind in ipairs(CHAT_TYPES) do pcall(SetChatColorNameByClass, kind, true) end
        ns.chatClassState = "on (set channel by channel)"
    else
        ns.chatClassState = "this client has no setting for it"
    end
end)
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", ns:Guard("Extras events", function()
        ns:After(3, function()                               -- switched off since last time: the game's setting goes back
            if ns.db and not ns.db.chatClassColors and ns.root and type(ns.root.chatClassPrev) == "string" then
                CVar("chatClassColorOverride", ns.root.chatClassPrev)
                ns.root.chatClassPrev = nil
            end
        end)
    end))
end

------------------------------------------------------------------------------------------
-- Follow the reputation you are earning: when you gain reputation with a faction, the reputation bar
-- switches to it. The faction's name is read out of the game's own "Reputation with X increased"
-- line, in whatever language the game is in.
------------------------------------------------------------------------------------------
local FACTION_LINES = { "FACTION_STANDING_INCREASED", "FACTION_STANDING_INCREASED_GENERIC", "FACTION_STANDING_INCREASED_BONUS",
                        "FACTION_STANDING_INCREASED_DOUBLE_BONUS", "FACTION_STANDING_INCREASED_ACH_BONUS",
                        "FACTION_STANDING_INCREASED_ACCOUNT_WIDE", "FACTION_STANDING_INCREASED_ACCOUNT_WIDE_BONUS" }
local function LineToPattern(line)
    local p = line:gsub("[%^%$%(%)%.%[%]%*%+%-%?%%]", "%%%0")            -- every character literally ...
    local first = true
    p = p:gsub("%%%%[%d%$%.%%]*[sdf]", function()                         -- ... except the blanks: the first is the name
        if first then first = false; return "(.-)" end
        return ".-"
    end)
    return "^" .. p .. "$"
end
function ns.FactionFromMessage(message)
    if type(message) ~= "string" or Secret(message) then return nil end
    if not ns.factionPatterns then
        ns.factionPatterns = {}
        for _, key in ipairs(FACTION_LINES) do
            local line = _G[key]
            if type(line) == "string" and line:find("%s", 1, true) then ns.factionPatterns[#ns.factionPatterns + 1] = LineToPattern(line) end
        end
        if #ns.factionPatterns == 0 then                     -- (a client without those texts: the English ones)
            ns.factionPatterns = { LineToPattern("Reputation with %s increased by %d."), LineToPattern("Reputation with %s increased.") }
        end
    end
    for _, pattern in ipairs(ns.factionPatterns) do
        local name = message:match(pattern)
        if name and name ~= "" then return name end
    end
    return nil
end
-- Make `name` the watched faction. Returns true if it was changed.
function ns:WatchFaction(name)
    if type(name) ~= "string" then return false end
    local R = C_Reputation
    if type(R) == "table" and R.GetWatchedFactionData then
        local ok, now = pcall(R.GetWatchedFactionData)
        if ok and type(now) == "table" and now.name == name then return false end      -- already watching it
    end
    if type(R) == "table" and R.GetNumFactions and R.GetFactionDataByIndex and R.SetWatchedFactionByIndex then
        local ok, n = pcall(R.GetNumFactions)
        for i = 1, (ok and tonumber(n)) or 0 do
            local okD, d = pcall(R.GetFactionDataByIndex, i)
            if okD and type(d) == "table" and d.name == name and (not d.isHeader or d.isHeaderWithRep) then
                return (pcall(R.SetWatchedFactionByIndex, i))
            end
        end
    end
    return false
end
ns:NewModule("repFollow", function()
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "CHAT_MSG_COMBAT_FACTION_CHANGE")
    ev:SetScript("OnEvent", ns:Guard("Follow reputation", function(_, _, message)
        local name = ns.FactionFromMessage(message)
        if name then ns:WatchFaction(name) end
    end))
end)

------------------------------------------------------------------------------------------
-- "Learn all" at a trainer: buys every skill you can learn and afford, one after another.
------------------------------------------------------------------------------------------
-- The skills on offer that can be learned now: { index, name, cost }, and what they cost together.
function ns:TrainerAvailable()
    local list, total = {}, 0
    if type(GetNumTrainerServices) ~= "function" or type(GetTrainerServiceInfo) ~= "function" then return list, total end
    local ok, n = pcall(GetNumTrainerServices)
    for i = 1, (ok and tonumber(n)) or 0 do
        local okI, name, a, b = pcall(GetTrainerServiceInfo, i)             -- (older clients: name, rank, state; newer: name, state)
        if okI and (a == "available" or b == "available") then
            local cost = 0
            if type(GetTrainerServiceCost) == "function" then
                local okC, c = pcall(GetTrainerServiceCost, i)
                cost = okC and tonumber(c) or 0
            end
            list[#list + 1] = { index = i, name = name, cost = cost }
            total = total + cost
        end
    end
    return list, total
end
ns:NewModule("trainAll", function()
    if type(BuyTrainerService) ~= "function" then return end
    local running, learned, spent = false, 0, 0
    local function Finish()
        running = false
        if learned > 0 then ns:Print(learned == 1 and "Learned %d skill for %s." or "Learned %d skills for %s.", learned, ns:Coins(spent)) else ns:Print("Nothing here that you can learn and afford.") end
    end
    local function Step(left, lastName, repeats)
        if not running then return end
        local win = _G.ClassTrainerFrame
        if type(win) ~= "table" or not win.IsShown or not win:IsShown() then return Finish() end
        local money = tonumber(GetMoney()) or 0
        local pick
        for _, service in ipairs((ns:TrainerAvailable())) do
            if service.cost <= money then pick = service; break end
        end
        if not pick or left <= 0 then return Finish() end
        repeats = (pick.name == lastName) and repeats + 1 or 0            -- the same skill offered again and again: it isn't being bought
        if repeats >= 3 then return Finish() end
        if repeats == 0 then learned, spent = learned + 1, spent + pick.cost end
        pcall(BuyTrainerService, pick.index)
        ns:After(0.35, function() Step(left - 1, pick.name, repeats) end)
    end
    local btn
    ns:Every(0.3, "Learn all", function()
        local win = _G.ClassTrainerFrame
        if type(win) ~= "table" or not win.IsShown or not ns:Usable(win) then return end
        if not btn then
            btn = ns:CreateButton(win, "Learn all", 90, 22, function()
                if running then return end
                running, learned, spent = true, 0, 0
                Step(150, nil, 0)
            end)
            local train = _G.ClassTrainerTrainButton
            if type(train) == "table" and train.GetObjectType and ns:Usable(train) then
                btn:SetPoint("RIGHT", train, "LEFT", -4, 0)
            else
                btn:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -110, 6)
            end
            btn:SetFrameLevel((win:GetFrameLevel() or 1) + 10)
            btn:HookScript("OnEnter", function(self)
                local list, total = ns:TrainerAvailable()
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(ns:Tr("Learn all"))
                GameTooltip:AddLine(format(ns:TrN(#list, "%d skill you can learn now, for %s.", "%d skills you can learn now, %s in all. Buys each one you can afford."), #list, ns:Coins(total)), 1, 1, 1, true)
                GameTooltip:Show()
            end)
            btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        if win:IsShown() then btn:SetAlpha(#(ns:TrainerAvailable()) > 0 and 1 or 0.45) end
    end)
end)

------------------------------------------------------------------------------------------
-- Alt-click a vendor's item to buy a full stack of it (as many as you can afford, if that is fewer).
------------------------------------------------------------------------------------------
-- How many to buy. maxStack: the most the vendor sells at once. numAvailable: limited stock (-1 or
-- nil = unlimited). price is for `perPurchase` items (some things are sold five at a time).
function ns.StackToBuy(maxStack, numAvailable, price, perPurchase, money)
    maxStack = tonumber(maxStack) or 0
    if maxStack <= 1 then return 0 end
    local n = maxStack
    numAvailable = tonumber(numAvailable)
    if numAvailable and numAvailable >= 0 then n = math.min(n, numAvailable) end
    price, perPurchase, money = tonumber(price) or 0, math.max(1, tonumber(perPurchase) or 1), tonumber(money) or 0
    if price > 0 then n = math.min(n, math.floor(money / (price / perPurchase))) end
    return math.max(0, n)
end
ns:NewModule("vendorStack", function()
    if type(hooksecurefunc) ~= "function" or type(MerchantItemButton_OnModifiedClick) ~= "function" or type(BuyMerchantItem) ~= "function" then
        ns.vendorStackState = "not possible on this client"
        return
    end
    ns.vendorStackState = "on"
    hooksecurefunc("MerchantItemButton_OnModifiedClick", ns:Guard("Buy a stack", function(self)
        if not (IsAltKeyDown and IsAltKeyDown() == true) then return end
        local merchant = _G.MerchantFrame
        if type(merchant) == "table" and merchant.selectedTab == 2 then return end       -- the buyback page
        local id = type(self) == "table" and self.GetID and self:GetID()
        if type(id) ~= "number" then return end
        local price, per, stock
        local info = C_MerchantFrame.GetItemInfo(id)
        if type(info) == "table" then price, per, stock = info.price, info.stackCount, info.numAvailable end
        local n = ns.StackToBuy(GetMerchantItemMaxStack and GetMerchantItemMaxStack(id), stock, price, per, GetMoney())
        if n > 1 then BuyMerchantItem(id, n) end
    end))
end)

------------------------------------------------------------------------------------------
-- A conversation with only one thing to say: say it. Only when the character offers exactly one
-- choice and no quests, never inside a dungeon or raid (where the one choice is often "start the
-- fight"), and not while Shift is held.
------------------------------------------------------------------------------------------
function ns.GossipPick(options, availableQuests, activeQuests, shift, inInstance)
    if shift or inInstance or type(options) ~= "table" or #options ~= 1 then return nil end
    if (tonumber(availableQuests) or 0) > 0 or (tonumber(activeQuests) or 0) > 0 then return nil end
    return options[1]
end
ns:NewModule("gossipOne", function()
    local G = C_GossipInfo
    if type(G) ~= "table" or not G.GetOptions then return end
    local lastPick = -100
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "GOSSIP_SHOW")
    ev:SetScript("OnEvent", ns:Guard("One-choice conversations", function()
        if GetTime() - lastPick < 1.5 then return end        -- (a choice that leads straight to another single choice is left to you)
        local inside = false
        if IsInInstance then local ok, v = pcall(IsInInstance); inside = ok and ns.Is(v, true) end
        local count = function(fn) local ok, n = pcall(fn); return ok and tonumber(n) or 0 end
        local pick = ns.GossipPick(G.GetOptions(), G.GetNumAvailableQuests and count(G.GetNumAvailableQuests), G.GetNumActiveQuests and count(G.GetNumActiveQuests),
            IsShiftKeyDown and IsShiftKeyDown() == true, inside)
        if type(pick) ~= "table" then return end
        lastPick = GetTime()
        if pick.gossipOptionID and G.SelectOption then pcall(G.SelectOption, pick.gossipOptionID)
        elseif type(SelectGossipOption) == "function" then pcall(SelectGossipOption, 1) end
    end))
end)

------------------------------------------------------------------------------------------
-- Rare spawn alert. The game marks rare creatures, treasures and events on the minimap as you come
-- near; when a new one appears you are told once, with a sound.
------------------------------------------------------------------------------------------
function ns.VignetteKind(atlas)
    if type(atlas) ~= "string" then return "other" end
    atlas = atlas:lower()
    if atlas:find("kill", 1, true) or atlas:find("rare", 1, true) then return "rare" end
    if atlas:find("loot", 1, true) or atlas:find("treasure", 1, true) or atlas:find("chest", 1, true) then return "treasure" end
    if atlas:find("event", 1, true) then return "event" end
    return "other"
end
local KIND_LABEL = { rare = "Rare creature", treasure = "Treasure", event = "Event", other = "Something" }
ns:NewModule("rareAlert", function()
    local V = C_VignetteInfo
    if type(V) ~= "table" or not V.GetVignetteInfo then ns.rareAlertState = "this client does not mark them"; return end
    ns.rareAlertState = "on"
    local seen, count = {}, 0
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "VIGNETTE_MINIMAP_UPDATED")
    ev:SetScript("OnEvent", ns:Guard("Rare spawn alert", function(_, _, id, onMinimap)
        if type(id) ~= "string" or Secret(id) or onMinimap == false or seen[id] then return end
        local ok, info = pcall(V.GetVignetteInfo, id)
        if not ok or type(info) ~= "table" or type(info.name) ~= "string" or Secret(info.name) or info.name == "" then return end
        if count > 300 then seen, count = {}, 0 end
        seen[id], count = true, count + 1
        local label = ns:Tr(KIND_LABEL[ns.VignetteKind(info.atlasName)])
        ns:PrintRaw(label .. " " .. ns:Tr("nearby") .. ": |cffffd100" .. info.name .. "|r")
        if ns.Toast and ns.db.toasts then pcall(ns.Toast, ns, nil, label, info.name, "!") end
        if ns.RareSighted then pcall(ns.RareSighted, ns, id, info) end      -- (remembered for the map: Journey.lua)
        if PlaySound then pcall(PlaySound, (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959, "Master") end
    end))
end)
