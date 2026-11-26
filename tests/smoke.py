import os as _os
ROOT = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))) + '/'   # the repository
import glob, sys
from lupa import LuaRuntime
lua = LuaRuntime(unpack_returned_tuples=True)
chk = lua.eval('function(s) local f, e = load(s); return f ~= nil, e end')
bad = False
OPT = '../FantasyGlassUI_Options/'
for p in sorted(glob.glob('*.lua')) + sorted(glob.glob(OPT + '*.lua')) + ['../FantasyGlassUI_Locales/Locales.lua']:
    ok, err = chk(open(p).read())
    if not ok: print("SYNTAX FAIL", p, err); bad = True
print("syntax:", "FAIL" if bad else "all %d files OK" % (len(glob.glob('*.lua')) + len(glob.glob(OPT + '*.lua')) + 1))
opt_toc = [l.strip() for l in open(OPT + 'FantasyGlassUI_Options.toc') if l.strip().endswith('.lua')]
assert sorted(opt_toc) == sorted(f[len(OPT):] for f in glob.glob(OPT + '*.lua')), "the options TOC and its folder disagree"
toc = [l.strip() for l in open('FantasyGlassUI.toc') if l.strip().endswith('.lua')]
for f in toc:
    assert f in glob.glob('*.lua'), "TOC lists missing file " + f
for f in glob.glob('*.lua'):
    assert f in toc, "file not in TOC: " + f

harness = r'''
local files, sources, missing, secretMode, optionFiles = ...
local handlers = {}
local mockmt = {}
local function newmock() return setmetatable({}, mockmt) end
-- Methods that exist only on certain kinds of widget in the game. kind -> allowed.
local WIDGET_ONLY = {}
do
    local function only(methods, kinds)
        local set = { __list = table.concat(kinds, ", ") }
        for _, kind in ipairs(kinds) do set[kind] = true end
        for _, m in ipairs(methods) do WIDGET_ONLY[m] = set end
    end
    only({ "SetValue", "GetValue", "SetMinMaxValues", "GetMinMaxValues" }, { "Slider", "StatusBar" })
    only({ "SetValueStep", "SetThumbTexture", "SetOrientation", "SetObeyStepOnDrag" }, { "Slider", "StatusBar" })
    only({ "SetStatusBarTexture", "SetStatusBarColor", "GetStatusBarTexture" }, { "StatusBar" })
    only({ "SetReverseFill", "GetReverseFill" }, { "StatusBar" })
    only({ "SetChecked", "GetChecked" }, { "CheckButton" })
    only({ "Click", "SetNormalTexture", "GetNormalTexture", "SetPushedTexture", "GetPushedTexture", "SetHighlightTexture",
           "GetHighlightTexture", "RegisterForClicks", "SetDisabledTexture", "GetDisabledTexture", "Enable", "Disable" }, { "Button", "CheckButton" })
    only({ "SetText", "GetText" }, { "Button", "CheckButton", "EditBox", "SimpleHTML" })
    only({ "SetFocus", "ClearFocus", "HighlightText", "SetMaxLetters", "SetAutoFocus", "SetMultiLine", "SetTextInsets",
           "SetAltArrowKeyMode", "HasFocus", "SetCursorPosition" }, { "EditBox" })
    only({ "SetCooldown", "SetReverse", "SetDrawEdge", "SetHideCountdownNumbers", "SetCooldownFromExpirationTime", "SetSwipeColor" }, { "Cooldown" })
    only({ "AddMessage", "SetFading", "SetTimeVisible", "SetFadeDuration", "ScrollUp", "ScrollDown", "ScrollToTop", "ScrollToBottom",
           "GetNumMessages", "GetMessageInfo" }, { "ScrollingMessageFrame", "MessageFrame" })
    only({ "SetScrollChild", "SetVerticalScroll", "GetVerticalScroll", "GetVerticalScrollRange" }, { "ScrollFrame" })
    only({ "SetUnit", "SetCamDistanceScale", "SetPortraitZoom", "ClearModel", "SetPosition", "SetFacing" }, { "PlayerModel", "DressUpModel", "CinematicModel" })
end
mockmt.__index = function(t, k)
    if k == nil or type(k) == "number" then return nil end
    if type(k) == "string" and k:sub(1,3) == "sui" then return nil end
    if k == "GetObjectType" then return function() return "Frame" end end
    if k == "SetScript" or k == "HookScript" then
        return function(self, name, fn) if type(fn) == "function" then handlers[#handlers+1] = { self = self, name = name, fn = fn } end end
    end
    if k == "IsProtected" or k == "IsForbidden" then return function() return false end end
    local kind = rawget(t, "__kind")
    if kind then
        local owners = WIDGET_ONLY[k]
        if owners and not owners[kind] then
            return function() error("a " .. kind .. " has no method " .. k .. " (it belongs to: " .. owners.__list .. ")", 2) end
        end
    end
    local m = newmock(); rawset(t, k, m); return m
end
mockmt.__call = function() return newmock() end
mockmt.__add = function() return 1 end
mockmt.__sub = function() return 1 end
mockmt.__mul = function() return 1 end
mockmt.__div = function() return 1 end
mockmt.__mod = function() return 1 end
mockmt.__unm = function() return 1 end
mockmt.__lt = function() return false end
mockmt.__le = function() return false end
mockmt.__concat = function() return "x" end
mockmt.__len = function() return 0 end

local secretmt = {}
local function boom() error("attempt to use a SECRET value", 2) end
for _, m in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__lt", "__le", "__concat", "__len", "__call", "__idiv", "__pow" }) do secretmt[m] = boom end
local function SV(n) if secretMode then return setmetatable({ __secret = true }, secretmt) end return n end
local env = {}
local reloadCount = 0                -- the game's ReloadUI: counts, so a test can see a reload
local known = {
  ReloadUI = function() reloadCount = reloadCount + 1 end,
  ipairs=ipairs, pairs=pairs, pcall=pcall, select=select, type=type, tostring=tostring, tonumber=tonumber,
  table=table, math=math, string=string, setmetatable=setmetatable, getmetatable=getmetatable, rawset=rawset, rawget=rawget,
  next=next, error=error, assert=assert, coroutine=coroutine,
  unpack = table.unpack, floor = math.floor, max = math.max, min = math.min,
  format = string.format, strlower = string.lower,
  strtrim = function(s) return (s:gsub("^%s+",""):gsub("%s+$","")) end,
  tinsert = table.insert, date = function() return "12:00" end,
  hooksecurefunc = function(a, b, c) local fn = c or b; if type(fn) == "function" then handlers[#handlers+1] = { self = newmock(), name = "hook", fn = fn } end end,
  CreateFrame = function(kind) local f = newmock(); if type(kind) == "string" then rawset(f, "__kind", kind) end; return f end,
  GetTime = function() return 100 end,
  IsRaidMarkerActive = function() return false end,
  C_EquipmentSet = { GetEquipmentSetIDs = function() return {} end, GetEquipmentSetInfo = function() end, UseEquipmentSet = function() end },
  InCombatLockdown = function() return false end,
  IsShiftKeyDown = function() return false end,
  IsInGroup = function() return true end,
  UnitExists = function() return true end,
  UnitIsPlayer = function(u) return u == 'player' or u == 'party1' end,
  UnitCanAttack = function() return true end,
  UnitIsDead = function() return false end,
  UnitIsUnit = function() return false end,
  UnitName = function() return "Someone" end,
  UnitHealth = function() return SV(50) end,
  UnitHealthMax = function() return SV(200) end,
  UnitPower = function() return SV(30) end,
  UnitPowerMax = function() return SV(100) end,
  UnitPowerType = function() return 3, 'ENERGY' end,
  UnitThreatSituation = function() return SV(2) end,
  UnitDetailedThreatSituation = function() return true, SV(2), SV(87.5) end,
  GetMoney = function() return 12345 end,
  GetFramerate = function() return 60 end,
  GetNetStats = function() return 1,1,40,50 end,
  GetInventoryItemDurability = function() return 20, 100 end,
  GetMinimapZoneText = function() return "Elwynn Forest" end,
  issecretvalue = function(v) return type(v) == "table" and rawget(v, "__secret") == true end,
  UnitHealthPercent = function() return SV(25) end,
  CurveConstants = { ScaleTo100 = 1 },
  UnitGetIncomingHeals = function() return SV(40) end,
  C_PaperDollInfo = { GetTemporaryEnchantmentInfo = function(slot)
                          if slot == 16 then return { remainingTimeMs = 1750000, chargesRemaining = 0, enchantID = 11 } end
                          if slot == 17 then return { remainingTimeMs = 42000, chargesRemaining = 5, enchantID = 12 } end
                      end, CancelTemporaryEnchantment = function() end },
  C_Bank = { FetchNumPurchasedBankTabs = function() return 1 end, CanPurchaseBankTab = function() return true end,
             FetchNextPurchasableBankTabData = function() return { tabCost = 25000 } end, PurchaseBankTab = function() end },
  time = function() return 1800000000 end,
  GetBuildInfo = function() return '1.60.1', '70888', 'Nov 1 2026', secretMode and 16001 or 110200 end,
  C_NewItems = { IsNewItem = function(bag, slot) return slot == 2 end, RemoveNewItem = function() end },
  IsAltKeyDown = function() return false end,
  AbbreviateNumbers = function(n) return tostring(n) end,
  C_DamageMeter = { GetCombatSessionFromType = function() return { maxAmount = SV(900), combatSources = {
      { name = 'Someone', classFilename = 'ROGUE', totalAmount = SV(900) }, { name = 'Other', classFilename = 'MAGE', totalAmount = SV(400) } } } end },
  C_Spell = { GetSpellInfo = function(name) if name ~= 'Unknown Spell' then return { spellID = 133, iconID = 135812, name = name } end end,
              GetSpellCooldown = function() return { startTime = SV(90), duration = SV(8) } end,
              GetSpellName = function(id) return "Spell " .. tostring(id) end, GetSpellTexture = function() return 135812 end },
  GetLootRollItemInfo = function() return 135349, "Sword", 1, 3, false, true, true, false end,
  GetLootRollTimeLeft = function() return 20000 end, RollOnLoot = function() end,
  GetInboxNumItems = function() return 3 end, TakeInboxMoney = function() end, AutoLootMailItem = function() end,
  GetInboxHeaderInfo = function(i) return nil, nil, "Bob", "Hi", (i == 2) and 500 or 0, (i == 3) and 100 or 0, 5, i == 1 end,
  GetTotemInfo = function(slot) return SV(slot <= 2), "Searing Totem", SV(100), SV(60), 135825 end,
  GetNumGuildMembers = function() return 3, 2, 2 end,
  GetGuildRosterInfo = function(i) return "Mate" .. i .. "-Realm", "Member", 2, 20 + i, "Mage", "Ironforge", "", "", i <= 2, 0, "MAGE" end,
  IsInGuild = function() return true end, HasNewMail = function() return true end,
  C_FriendList = { GetNumOnlineFriends = function() return 1 end, GetNumFriends = function() return 2 end,
                   GetFriendInfoByIndex = function(i) return { name = "Pal" .. i, connected = i == 1, level = 12, area = "Elwynn" } end },
  BNGetNumFriends = function() return 4, 1 end,
  C_CurveUtil = { CreateCurve = function() local c = newmock(); rawset(c, "AddPoint", function() end); return c end },
  UnitThreatSituation = function() return SV(3) end, IsInGroup = function() return true end,
  C_SwingTimer = { IsTargetWithinSwingRange = function() return SV(false) end, EnableRangeCheck = function() end },
  GetBindingKey = function() return "3", "SHIFT-E" end, SetBinding = function() return true end,
  SaveBindings = function() end, GetCurrentBindingSet = function() return 1 end,
  UnitIsAFK = function() return false end, Screenshot = function() end,
  GetActionInfo = function(slot) if slot <= 4 then return "spell", 100 + slot elseif slot == 5 then return "macro", 1 elseif slot == 6 then return "spell", 101 end end,
  GetSpellBaseCooldown = function(id) return (id == 102) and 1500 or 30000, 1500 end,
  time = function() return 1000000 end,
  GetMirrorTimerInfo = function() return "UNKNOWN", 0, 0, 0, 0, "" end,
  GetMirrorTimerProgress = function(name) return name == "BREATH" and 15000 or 0 end,
  LOOT_ITEM_SELF = "You receive loot: %s.", LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d.",
  LOOT_ITEM_PUSHED_SELF = "You receive item: %s.", LOOT_ITEM_CREATED_SELF = "You create: %s.",
  LibStub = setmetatable({}, { __call = function(_, name)
      if name ~= "LibDataBroker-1.1" then return nil end
      local objects = { Gold = { type = "data source", text = "12g", label = "Gold", icon = 133784, OnClick = function() end, OnTooltipShow = function() end },
                        Launcher = { type = "launcher", text = "x" }, Empty = { type = "data source", text = "" },
                        Memory = { type = "data source", text = 42 } }
      return { DataObjectIterator = function() return pairs(objects) end }
  end }),
  GetGuildInfo = function() return "Night Watch" end, GetCurrentGuildBankTab = function() return 2 end,
  GetGuildBankItemLink = function(tab, slot) if slot <= 3 then return "|Hitem:5|h[Guild Thing " .. slot .. "]|h" end end,
  GetGuildBankItemInfo = function() return 134400, 5, false, false, 2 end,
  GetGuildBankTabInfo = function() return "Materials" end,
  GetInventoryItemTexture = function() return 134400 end, CursorHasItem = function() return false end,
  IsBagOpen = function() return true end, CloseAllBags = function() end,
  UnitXP = function() return 1200 end, UnitXPMax = function() return 5000 end, GetXPExhaustion = function() return 300 end,
  GetMaxPlayerLevel = function() return 60 end,
  C_Reputation = { GetWatchedFactionData = function() return { name = "Stormwind", reaction = 5, currentReactionThreshold = 0, nextReactionThreshold = 6000, currentStanding = 1500 } end },
  FACTION_BAR_COLORS = { [5] = { r = 0, g = 0.6, b = 0.1 } }, FACTION_STANDING_LABEL5 = "Friendly",
  GetLocale = function() return "enUS" end, IsInRaid = function() return false end,
  IsModifiedClick = function(kind) return kind == 'SPLITSTACK' end,
  ChatFrameUtil = { AddMessageEventFilter = function(ev, fn) if ev == "CHAT_MSG_SAY" then handlers[#handlers+1] = { self = newmock(), name = "chatfilter", fn = fn } end end,
                    OpenChat = function() end, SendTell = function() end, GetActiveWindow = function() end,
                    DeactivateChat = function() end, InsertLink = function() end },
  C_ChatInfo = { SendChatMessage = function() end, PerformEmote = function() return true end, InChatMessagingLockdown = function() return false end,
                 SendAddonMessage = function() return 0 end, RegisterAddonMessagePrefix = function() return true end },
  C_PartyInfo = { DoReadyCheck = function() end, InviteUnit = function() end, DoCountdown = function() end },
  C_ActionBar = { HasAction = function() return false end, GetActionTexture = function() end, GetActionText = function() end,
                  GetActionUseCount = function() return 0 end, GetActionCooldown = function() return { startTime = 0, duration = 0, isEnabled = true } end,
                  IsUsableAction = function() return true, false end, IsActionInRange = function() return nil end,
                  IsCurrentAction = function() return false end, IsAutoRepeatAction = function() return false end,
                  IsConsumableAction = function() return false end, IsStackableAction = function() return false end },
  GetNumSpecGroups = function() return 1 end,
  C_SpecializationInfo = { GetActiveSpecGroup = function() return 1 end, SetActiveSpecGroup = function() end,
                           GetSpecialization = function() return 1 end, GetSpecializationInfo = function() return 262, "Elemental" end },
  AuraUtil = { GetDebuffDisplayInfoTable = function() return { Magic = { color = { r = 0.2, g = 0.6, b = 1 } }, None = { color = { r = 0.8, g = 0, b = 0 } } } end },
  C_CurrencyInfo = { GetCoinTextureString = function() return "5s" end },
  StaticPopup_FindVisible = function(which)
      for i = 1, 4 do local p = env["StaticPopup" .. i]; if type(p) == "table" and rawget(p, "which") == which then return p end end
  end,
  Enum = { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 }, BankType = { Character = 0 }, DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, Absorbs = 4, Interrupts = 5, Dispels = 6, DamageTaken = 7, AvoidableDamageTaken = 8, Deaths = 9, EnemyDamageTaken = 10 }, DamageMeterSessionType = { Overall = 0, Current = 1 },
           BagIndex = { ReagentBag = 5, CharacterBankTab_1 = 6, CharacterBankTab_2 = 7, Keyring = -1, Characterbanktab = -2 } },
  GetRealmName = function() return 'Realm' end,
  UnitAttackSpeed = function() return SV(2.6), SV(1.8) end,
  GetCVar = function() return "1" end, SetCVar = function() end,
  UnitInRange = function() return SV(1) ~= nil, true end,
  GetReadyCheckStatus = function() return "ready" end,
  UnitGroupRolesAssigned = function() return "TANK" end,
  UnitLevel = function() return 12 end, UnitClass = function() return "Rogue", "ROGUE" end,
  UnitReaction = function() return 4 end, UnitIsConnected = function() return true end,
  UnitIsDeadOrGhost = function() return false end, UnitIsVisible = function() return true end,
  UnitIsTapDenied = function() return false end, UnitClassification = function() return "elite" end,
  UnitAffectingCombat = function() return true end, IsResting = function() return true end,
  UnitIsGroupLeader = function() return true end, GetRaidTargetIndex = function() return 3 end,
  GetCreatureDifficultyColor = function() return { r = 1, g = 0.5, b = 0.25 } end,
  UnitCastingInfo = function(u) if u == "target" or u == "player" then return "Fireball", "Fireball", 135812, SV(1000), SV(3000) end end,
  UnitChannelInfo = function(u) if u == "focus" then return "Blizzard", "Blizzard", 135857, SV(1000), SV(9000) end end,
  PowerBarColor = { MANA = { r = 0, g = 0, b = 1 }, [3] = { r = 1, g = 1, b = 0 } },
  CLASS_ICON_TCOORDS = { ROGUE = { 0.5, 0.75, 0, 0.25 } },
  C_UnitAuras = { GetAuraDataByIndex = function(unit, i, filter)
      if i <= 3 then return { icon = 136243, duration = SV(10), expirationTime = SV(110), applications = SV(3), auraInstanceID = i } end
  end },
  GetQuestLogQuestText = function() return "A long description.", "Objectives text" end,
  GetQuestLogRewardXP = function() return 100 end, GetQuestLogRewardMoney = function() return 500 end,
  GetNumQuestLogRewards = function() return 1 end, GetQuestLogRewardInfo = function() return "Item", "tex", 2 end,
  GetNumQuestLogChoices = function() return 2 end, GetQuestLogChoiceInfo = function() return "Choice", "tex", 1 end,
  GetQuestLogSpecialItemInfo = function() return "|Hitem:9|h[Thing]|h", 9, 1, false end,
  GetQuestDifficultyColor = function() return { r = 1, g = 1, b = 0 } end,
  GetQuestProgressBarPercent = function() return 40 end,
  GetNumQuestChoices = function() return 2 end, GetQuestItemLink = function() return "|Hitem:7|h[Reward]|h" end,
  GetNumActiveQuests = function() return 1 end, GetActiveTitle = function() return "t", true end,
  GetNumAvailableQuests = function() return 1 end,
  CanMerchantRepair = function() return true end, GetRepairAllCost = function() return 100, true end,
  ITEM_QUALITY_COLORS = { [0] = { r = .5, g = .5, b = .5 }, [2] = { r = 0, g = 1, b = 0 }, [3] = { r = 0, g = .4, b = 1 } },
  C_QuestLog = {
    GetNumQuestWatches = function() return 2 end,
    GetQuestIDForQuestWatchIndex = function(i) return 100 + i end,
    GetQuestObjectives = function() return { { text = "Wolves slain: 3/8", finished = false, type = "monster" },
                                             { text = "", finished = false, type = "progressbar" },
                                             { text = "Speak to Bob", finished = true, type = "event" } } end,
    GetTitleForQuestID = function(id) return "Quest " .. id end,
    GetLogIndexForQuestID = function(id) return id - 99 end,
    GetInfo = function(i)
        if i == 1 then return { title = "Elwynn Forest", isHeader = true, isCollapsed = true } end
        if i == 2 or i == 3 then return { title = "Quest " .. (99 + i), questLevel = 5, questID = 99 + i } end
    end,
    GetNumQuestLogEntries = function() return 3, 2 end,
    IsComplete = function(id) return id == 102 end,
    GetQuestWatchType = function(id) if id == 101 then return 1 end end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    IsPushableQuest = function() return true end,
    AddQuestWatch = function() end, RemoveQuestWatch = function() end, SetSelectedQuest = function() end,
    ExpandQuestHeader = function() end, SetAbandonQuest = function() end, AbandonQuest = function() end,
  },
  C_Container = {
    GetContainerNumSlots = function(bag) if bag == 7 then return 0 end return 4 end,
    GetContainerItemInfo = function(bag, slot) if slot == 4 then return nil end return { hyperlink = "|Hitem:1|h[Junk Cloth]|h", stackCount = 2, quality = (slot == 1) and 0 or 3, itemID = 100 + slot, iconFileID = 134400, isLocked = false } end,
    UseContainerItem = function() end, PickupContainerItem = function() end, SortBags = function() end, SortBankBags = function() end,
    GetContainerItemCooldown = function() return 0, 0, 1 end, SplitContainerItem = function() end,
    ContainerIDToInventoryID = function(bag) return 30 + bag end,
  },
  C_Item = { GetItemInfo = function() return "Junk", "link", 0, 1, 1, "a", "b", 20, "", 134400, 25 end,
             GetItemIconByID = function() return 134400 end,
             GetItemInfoInstant = function() return 1, 'Armor', 'Cloth', 'INVTYPE_CHEST', 134400, 4, 1 end,
             GetDetailedItemLevelInfo = function() return 22 end },
  C_Map = { GetBestMapForUnit = function() return 1 end,
            GetPlayerMapPosition = function() return { GetXY = function() return 0.512, 0.404 end } end },
  C_GossipInfo = { GetOptions = function() return {} end,
                   GetActiveQuests = function() return { { isComplete = true, questID = 1 } } end,
                   GetAvailableQuests = function() return { { questID = 2 } } end,
                   SelectActiveQuest = function() end, SelectAvailableQuest = function() end },
  UISpecialFrames = {}, Constants = { ChatFrameConstants = { MaxChatWindows = 3 } }, RAID_CLASS_COLORS = { ROGUE = { r = 1, g = 0.96, b = 0.41 } }, ChatTypeInfo = {},
  DEFAULT_CHAT_FRAME = newmock(), SlashCmdList = {}, BackdropTemplateMixin = {},
}
do
    local bagf = newmock()
    rawset(bagf, "EnumerateValidItems", function() return ipairs({ newmock(), newmock() }) end)
    rawset(bagf, "IsShown", function() return true end)
    known.ContainerFrameCombinedBags = bagf
end
do
    local function part(kind) local t = newmock(); rawset(t, "GetObjectType", function() return kind end); rawset(t, "GetDrawLayer", function() return "BORDER" end); return t end
    local str = part("FontString"); rawset(str, "GetText", function() return "Hello there" end)
    local holder = newmock(); rawset(holder, "String", str); rawset(holder, "GetRegions", function() return part("Texture"), part("Texture"), str end)
    local bubble = newmock(); rawset(bubble, "GetChildren", function() return holder end)
    known.C_ChatBubbles = { GetAllChatBubbles = function() return { bubble } end }
    known.GetPlayerInfoByGUID = function() return "Rogue", "ROGUE" end
    known.__bubbleHolder = holder
end
do  -- a character window shaped like the real one (/sui tree CharacterFrame)
    local function tex(layer) local t = newmock(); rawset(t, "GetObjectType", function() return "Texture" end); rawset(t, "GetDrawLayer", function() return layer or "BORDER" end); return t end
    local function frame(kind, name, kids, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end); rawset(f, "GetName", function() return name end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return table.unpack(regions or { tex("BORDER"), tex("ARTWORK") }) end); rawset(f, "IsShown", function() return true end); return f end
    local nine = frame("Frame"); rawset(nine, "TopLeftCorner", tex()); rawset(nine, "Center", tex())
    local borderFrame = frame("Frame")
    local slot = frame("Button", "CharacterHeadSlot", { borderFrame, nine }); rawset(slot, "GetID", function() return 1 end)
    rawset(slot, "icon", tex("BORDER")); rawset(slot, "BorderFrame", borderFrame); rawset(slot, "Mask", newmock()); rawset(slot, "HighlightTexture", tex("HIGHLIGHT")); rawset(slot, "PushedTexture", tex("ARTWORK"))
    local header = frame("Frame"); rawset(header, "Background", tex("BACKGROUND")); rawset(header, "Title", newmock())
    local row = frame("Frame"); rawset(row, "Background", tex("BACKGROUND")); rawset(row, "Label", newmock()); rawset(row, "Value", newmock())
    local target = frame("Frame", nil, { header, row })
    local scrollbox = frame("Frame", nil, { target })
    local stats = frame("Frame", "CharacterStatsPaneScrollBox", { scrollbox }); rawset(stats, "Border", tex()); rawset(stats, "ClassBackground", tex())
    local selected = tex(); rawset(selected, "IsShown", function() return true end)
    local tab = frame("Frame", "CharacterFrameModeTab1"); rawset(tab, "Background", tex()); rawset(tab, "SelectedTexture", selected); rawset(tab, "Icon", tex("ARTWORK")); rawset(tab, "Mask", newmock()); rawset(tab, "HighlightTexture", tex("HIGHLIGHT"))
    local sidebar = frame("CheckButton", "PaperDollSidebarTab1"); rawset(sidebar, "Icon", tex("ARTWORK"))
    local control = frame("Button"); rawset(control, "Icon", tex()); rawset(control, "NormalTexture", tex()); rawset(control, "PushedTexture", tex()); rawset(control, "HighlightTexture", tex())
    local controls = frame("Frame", nil, { control })
    local scene = frame("ModelScene", "CharacterModelScene"); rawset(scene, "ControlFrame", controls)
    local right = frame("Frame", "CharacterFrameRightPaneHost", { frame("Frame") }); rawset(right, "StoneBg", tex("ARTWORK"))
    local items = frame("Frame", "PaperDollItemsFrame", { slot })
    local doll = frame("Frame", "PaperDollFrame", { scene, items })
    local win = frame("Frame", "CharacterFrame", { right, stats, frame("Frame", "CharacterFrameModeTabs", { tab }), doll, frame("Frame", "PaperDollSidebarTabs", { sidebar }) })
    known.CharacterFrame = win; known.CharacterHeadSlot = slot; known.CharacterFrameModeTab1 = tab; known.CharacterFrameRightPaneHost = right
    known.CharacterStatsPaneScrollBox = stats; known.PaperDollFrame = doll; known.CharacterModelScene = scene
    known.GetInventoryItemQuality = function() return 3 end
    known.GetInventoryItemLink = function() return "|Hitem:55|h[Helm]|h" end
    known.__char = { slot = slot, header = header, row = row, tab = tab, sidebar = sidebar, control = control }
end
do  -- stand-ins built from the real outlines: quest panel, guild window, a Blizzard raid frame
    local function tex(layer) local t = newmock(); rawset(t, "GetObjectType", function() return "Texture" end); rawset(t, "GetDrawLayer", function() return layer or "BORDER" end); return t end
    local function frame(kind, name, kids, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end); rawset(f, "GetName", function() return name end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return table.unpack(regions or { tex("BORDER"), tex("ARTWORK") }) end)
        rawset(f, "IsShown", function() return true end); rawset(f, "IsVisible", function() return true end); return f end
    -- quest panel
    local header = frame("Button"); rawset(header, "CollapseButton", frame("Button")); rawset(header, "ButtonText", newmock()); rawset(header, "Checkbox", false)
    local check = frame("Frame"); rawset(check, "CheckMark", tex())
    local quest = frame("Button"); rawset(quest, "Checkbox", check); rawset(quest, "CollapseButton", false)
    local scroll = frame("ScrollFrame", "QuestScrollFrame"); rawset(scroll, "Background", tex()); rawset(scroll, "Edge", tex())
    rawset(scroll, "Contents", frame("Frame", nil, { header, quest }))
    local rim = frame("Frame"); rawset(rim, "Border", tex()); rawset(rim, "TopDetail", tex()); rawset(scroll, "BorderFrame", rim)
    local qtab = frame("Frame"); rawset(qtab, "Background", tex()); rawset(qtab, "SelectedTexture", tex()); rawset(qtab, "Icon", tex("ARTWORK"))
    local panel = frame("Frame", "QuestMapFrame"); rawset(panel, "QuestsTab", qtab); rawset(panel, "VerticalSeparator", tex())
    local count = frame("Frame", "QuestLogCount"); rawset(count, "Left", tex()); rawset(count, "Middle", tex()); rawset(count, "Right", tex())
    known.QuestMapFrame = panel; known.QuestScrollFrame = scroll; known.QuestLogCount = count
    -- guild
    local column = frame("Button"); rawset(column, "Left", tex()); rawset(column, "Middle", tex()); rawset(column, "Right", tex())
    local display = frame("Frame", nil, { column }); rawset(display, "Background", tex()); rawset(display, "InsetBorderTop", tex())
    local members = frame("Frame"); rawset(members, "ColumnDisplay", display)
    local side = frame("CheckButton"); rawset(side, "Icon", tex("ARTWORK"))
    local clist = frame("Frame"); rawset(clist, "TopFiligree", tex())
    local guild = frame("Frame", "CommunitiesFrame", { side }); rawset(guild, "MemberList", members); rawset(guild, "CommunitiesList", clist)
    known.CommunitiesFrame = guild
    -- one of the game's raid frames
    local raid = frame("Button", "CompactRaidFrame1"); rawset(raid, "healthBar", newmock()); rawset(raid, "background", tex()); rawset(raid, "name", newmock())
    local aura = newmock(); rawset(aura, "icon", tex()); rawset(raid, "debuffFrames", { aura })
    known.CompactRaidFrame1 = raid
    known.__polish = { header = header, check = check, qtab = qtab, count = count, column = column, side = side, scroll = scroll }
end
do  -- the three small tabs above the character stats: the selected one shows one piece fewer
    local function tex(shown) local t = newmock(); rawset(t, "GetObjectType", function() return "Texture" end); rawset(t, "GetDrawLayer", function() return "BORDER" end); rawset(t, "IsShown", function() return shown end); return t end
    local function tab(hiderShown) local f = newmock(); local icon = tex(true)
        rawset(f, "Icon", icon); rawset(f, "IsShown", function() return true end)
        local regions = { icon, tex(true), tex(hiderShown), tex(true) }
        rawset(f, "GetRegions", function() return table.unpack(regions) end); return f end
    known.PaperDollSidebarTab1 = tab(false)        -- selected: its "hider" is hidden
    known.PaperDollSidebarTab2 = tab(true)
    known.PaperDollSidebarTab3 = tab(true)
    local gone = newmock(); rawset(gone, "IsShown", function() return false end); known.PaperDollSidebarTab4 = gone
end
do  -- reputation page, from its real outline
    local function tex(layer) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end); return x end
    local function frame(kind, kids, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return table.unpack(regions or {}) end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end); return f end
    local function bar() local fill = tex("ARTWORK"); local art = tex("BORDER"); local b = frame("Frame", nil, { fill, art })
        rawset(b, "Fill", fill); rawset(b, "FillArea", frame("Frame")); rawset(b, "Mask", newmock()); rawset(b, "Text", newmock()); rawset(b, "__art", art); return b end
    local icon = tex("ARTWORK"); local plate = tex("BACKGROUND")
    local header = frame("Button", nil, { icon, plate }); rawset(header, "Name", newmock()); rawset(header, "StateIcon", icon); rawset(header, "Content", false)
    local rbar = bar()
    local glow = frame("Frame"); rawset(glow, "Left", tex()); rawset(glow, "Middle", tex()); rawset(glow, "Right", tex())
    local content = frame("Frame"); rawset(content, "ReputationBar", rbar); rawset(content, "Name", newmock()); rawset(content, "BackgroundHighlight", glow)
    local faction = frame("Button"); rawset(faction, "Content", content); rawset(faction, "StateIcon", false)
    local target = frame("Frame", { header, faction })
    local box = frame("Frame"); rawset(box, "ScrollTarget", target)
    local check = frame("CheckButton"); rawset(check, "Label", newmock())
    local detail = frame("Frame"); rawset(detail, "StandingBar", bar()); rawset(detail, "AtWarCheckbox", check); rawset(detail, "Divider", tex())
    rawset(detail, "MakeInactiveCheckbox", false); rawset(detail, "WatchFactionCheckbox", false)
    local page = frame("Frame"); rawset(page, "ScrollBox", box); rawset(page, "ReputationDetailFrame", detail)
    known.ReputationFrame = page
    known.__rep = { header = header, faction = faction, bar = rbar, detail = detail, check = check }
end
do  -- skills page, from its real outline: the bars are StatusBars called SkillsBar / RankBar
    local function tex(layer) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end); return x end
    local function frame(kind, kids, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return table.unpack(regions or {}) end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end); return f end
    local function bar() local fill = tex("ARTWORK"); local art = tex("BORDER"); local b = frame("StatusBar", nil, { fill, art })
        rawset(b, "Fill", fill); rawset(b, "FillArea", frame("Frame")); rawset(b, "GetStatusBarTexture", function() return fill end)
        rawset(b, "__art", art); rawset(b, "__alpha", {}); rawset(art, "SetAlpha", function(_, a) rawget(b, "__alpha").art = a end); rawset(fill, "SetAlpha", function(_, a) rawget(b, "__alpha").fill = a end); return b end
    local icon = tex("ARTWORK")
    local header = frame("Button", nil, { icon, tex("BACKGROUND") }); rawset(header, "Name", newmock()); rawset(header, "StateIcon", icon); rawset(header, "Content", false)
    local sbar = bar()
    local content = frame("Frame"); rawset(content, "SkillsBar", sbar); rawset(content, "Name", newmock()); rawset(content, "BackgroundHighlight", false)
    local skill = frame("Button"); rawset(skill, "Content", content); rawset(skill, "StateIcon", false)
    rawset(content, "Value", false); rawset(skill, "ToggleCollapseButton", false)
    -- a statistics entry: Name + Value, and a collapse button
    local arrow = frame("Button", nil, { tex("BORDER") })
    local scontent = frame("Frame"); rawset(scontent, "Name", newmock()); rawset(scontent, "Value", newmock()); rawset(scontent, "BackgroundHighlight", false)
    local stat = frame("Button"); rawset(stat, "Content", scontent); rawset(stat, "StateIcon", false); rawset(stat, "ToggleCollapseButton", arrow)
    local statBox = frame("Frame"); rawset(statBox, "ScrollTarget", frame("Frame", { stat }))
    local statPage = frame("Frame"); rawset(statPage, "ScrollBox", statBox); rawset(statPage, "DetailFrame", false)
    known.StatisticsFrame = statPage; known.__stat = stat
    local box = frame("Frame"); rawset(box, "ScrollTarget", frame("Frame", { header, skill }))
    local detail = frame("Frame"); rawset(detail, "RankBar", bar()); rawset(detail, "Divider", tex())
    local page = frame("Frame"); rawset(page, "ScrollBox", box); rawset(page, "SkillDetailFrame", detail)
    known.SkillsFrame = page
    known.__skills = { header = header, skill = skill, bar = sbar, detail = detail }
end
do  -- PvP page, from its real outline
    local function tex() local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return "BORDER" end); return x end
    local function frame(kids) local f = newmock(); rawset(f, "GetObjectType", function() return "Frame" end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return end); rawset(f, "IsVisible", function() return true end); return f end
    local sub = frame(); rawset(sub, "Background", tex()); rawset(sub, "Label", newmock()); rawset(sub, "IconSlot", false)
    local plain = frame(); rawset(plain, "Label", newmock()); rawset(plain, "Background", false); rawset(plain, "IconSlot", false)
    local slot = tex(); local item = frame(); rawset(item, "IconSlot", slot); rawset(item, "Background", false)
    local detail = frame(); rawset(detail, "Content", frame({ plain, sub, item })); rawset(detail, "Divider", tex())
    local reward = frame(); rawset(reward, "RingBorder", tex())
    local ring = frame(); rawset(ring, "NextRewardLevel", reward)
    local main = frame(); rawset(main, "Line", tex()); rawset(main, "RankProgressBarDisplay", ring)
    local page = frame(); rawset(page, "MainInfoFrame", main); rawset(page, "DetailFrame", detail); rawset(page, "ScrollBox", false)
    known.PVPRankFrame = page
    known.__pvp = { sub = sub, plain = plain, slot = slot, main = main }
end
do  -- vendor and mailbox, from their real outlines
    local function tex(layer, shown) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end)
        rawset(x, "IsShown", function() return shown ~= false end); rawset(x, "GetVertexColor", function() return 0.12, 1, 0, 1 end); return x end
    local function frame(kind, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetRegions", function() return table.unpack(regions or {}) end); rawset(f, "GetChildren", function() return end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end); return f end
    -- vendor: one item
    local quality = tex("OVERLAY", true)
    local ibtn = frame("Button"); rawset(ibtn, "icon", tex("BORDER")); rawset(ibtn, "IconBorder", quality); rawset(ibtn, "NormalTexture", tex("ARTWORK")); rawset(ibtn, "Mask", newmock())
    local item = frame("Frame"); rawset(item, "ItemButton", ibtn); rawset(item, "Name", newmock()); rawset(item, "SlotTexture", tex("BACKGROUND"))
    known.MerchantFrame = frame("Frame"); known.MerchantItem1 = item
    for i = 2, 12 do known["MerchantItem" .. i] = false end
    known.MerchantBuyBackItem = false; known.MerchantPrevPageButton = false; known.MerchantNextPageButton = false
    -- mailbox: one row, and a named edit box
    local mbtn = frame("CheckButton"); rawset(mbtn, "Icon", tex("ARTWORK")); rawset(mbtn, "IconBorder", tex("OVERLAY", false))
    local row = frame("Frame", { tex("BACKGROUND") }); rawset(row, "Button", mbtn)
    known.MailFrame = frame("Frame"); known.MailItem1 = row
    for i = 2, 7 do known["MailItem" .. i] = false end
    known.InboxFrame = false
    local field = frame("EditBox"); rawset(field, "left", false); rawset(field, "right", false); rawset(field, "texture", false)
    known.SendMailFrame = frame("Frame"); known.SendMailNameEditBox = field
    for _, n in ipairs({ "SendMailSubjectEditBox", "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" }) do known[n] = false end
    known.__shop = { item = item, ibtn = ibtn, quality = quality, row = row, mbtn = mbtn, field = field }
end
do  -- quest giver's dialog: dark ink must be relit, light lettering left alone
    local function text(r, g, b) local f = newmock(); local c = { r, g, b }
        rawset(f, "GetObjectType", function() return "FontString" end); rawset(f, "GetTextColor", function() return c[1], c[2], c[3], 1 end)
        rawset(f, "SetTextColor", function(_, nr, ng, nb) c[1], c[2], c[3] = nr, ng, nb end); rawset(f, "IsVisible", function() return true end)
        rawset(f, "__color", c); return f end
    local function tex() local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return "BACKGROUND" end)
        rawset(x, "__alpha", { 1 }); rawset(x, "SetAlpha", function(_, a) rawget(x, "__alpha")[1] = a end); return x end
    local function frame(kind, kids, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return table.unpack(regions or {}) end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end); return f end
    local ink, bright, heading = text(0.18, 0.12, 0.06), text(1, 0.82, 0), text(0, 0, 0)
    local child = frame("Frame", nil, { ink, bright, heading })
    local parchment = tex()
    local panel = frame("Frame", { frame("ScrollFrame", { child }) }); rawset(panel, "Bg", parchment)
    for _, k in ipairs({ "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight", "SealMaterialBG" }) do rawset(panel, k, false) end
    known.QuestFrame = frame("Frame"); known.QuestFrameDetailPanel = panel; known.QuestInfoTitleHeader = heading
    for _, n in ipairs({ "QuestFrameRewardPanel", "QuestFrameProgressPanel", "QuestFrameGreetingPanel", "QuestInfoObjectivesHeader", "QuestProgressTitleText",
                         "CurrentQuestsText", "AvailableQuestsText", "QuestInfoRewardsFrame", "QuestProgressScrollChildFrame", "QuestGreetingFrameHorizontalBreak",
                         "QuestInfoItemHighlight", "QuestInfoPlayerTitleFrame" }) do known[n] = false end
    known.__quest = { ink = ink, bright = bright, heading = heading, parchment = parchment }
end
do  -- professions window, from its real outline (overview page showing)
    local function tex(layer) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end); return x end
    local function frame(kind, kids) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end); return f end
    local tab = frame("Frame"); rawset(tab, "Background", tex()); rawset(tab, "SelectedTexture", tex()); rawset(tab, "Icon", tex("ARTWORK"))
    local bar = frame("Frame"); rawset(bar, "Fill", tex("ARTWORK")); rawset(bar, "Background", tex()); rawset(bar, "Border", tex()); rawset(bar, "Mask", newmock()); rawset(bar, "FillArea", false)
    local spell = frame("CheckButton"); rawset(spell, "IconTexture", tex("ARTWORK")); rawset(spell, "IconBorder", tex()); rawset(spell, "BorderShadow", tex())
    local panel = frame("Frame"); rawset(panel, "StatusBar", bar); rawset(panel, "SpellButton1", spell); rawset(panel, "ProfessionName", newmock())
    for i = 2, 6 do rawset(panel, "SpellButton" .. i, false) end
    local content = frame("Frame", { panel })
    local book = frame("Frame"); rawset(book, "ProfessionsContentFrame", content)
    local plain = frame("Frame"); rawset(plain, "SelectedTexture", false); rawset(plain, "Background", false)
    local win = frame("Frame", { tab, plain }); rawset(win, "BookPage", book); rawset(win, "CraftingPage", false)
    known.ProfessionsFrame = win
    known.__prof = { tab = tab, bar = bar, spell = spell, plain = plain }
end
do  -- collections window, from its real outline (pets tab showing, mounts tab hidden)
    local function tex(layer) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end); return x end
    local function frame(kind, kids, shown) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return end)
        rawset(f, "IsVisible", function() return shown ~= false end); rawset(f, "IsShown", function() return shown ~= false end); return f end
    local NO = { "background", "icon", "BorderTopLeft", "BorderBottomRight", "BackgroundTile", "slotFrameCollected", "border", "Border", "Icon", "BlackCover", "ControlFrame" }
    local function plain(f) for _, k in ipairs(NO) do if rawget(f, k) == nil then rawset(f, k, false) end end return f end
    local tab = frame("Frame"); rawset(tab, "Background", tex()); rawset(tab, "SelectedTexture", tex()); rawset(tab, "Icon", tex("ARTWORK"))
    local row = frame("Button"); rawset(row, "background", tex()); rawset(row, "icon", tex("ARTWORK")); rawset(row, "selectedTexture", tex()); rawset(row, "name", newmock()); plain(row)
    local count = frame("Frame"); rawset(count, "BorderTopLeft", tex()); rawset(count, "BorderBottomRight", tex()); rawset(count, "Bg", tex()); plain(count)
    local grid = frame("Frame"); rawset(grid, "BackgroundTile", tex()); rawset(grid, "BGCornerTopLeft", tex()); plain(grid)
    local hiddenRow = frame("Button"); rawset(hiddenRow, "background", tex()); rawset(hiddenRow, "icon", tex()); plain(hiddenRow)
    local mounts = plain(frame("Frame", { hiddenRow }, false))
    local list = plain(frame("Frame", { row }))
    local pets = plain(frame("Frame", { count, list, grid }))
    local win = frame("Frame", { mounts, pets }); rawset(win, "TabContainer", frame("Frame", { tab }))
    known.CollectionsJournal = win
    known.__coll = { tab = tab, row = row, count = count, grid = grid, hiddenRow = hiddenRow }
end
do  -- auction house, from its real outline: one visible panel, one hidden
    local function tex(layer) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end)
        rawset(x, "IsShown", function() return false end); return x end
    local KEYS = { "NineSlice", "Background", "ItemButton", "Arrow", "Left", "Right", "Middle", "Lines", "SelectedTexture", "SelectedHighlight", "NormalTexture", "Name", "left", "right", "texture",
                   "CreateAuctionTabLeft", "CreateAuctionTabMiddle", "CreateAuctionTabRight" }
    local function frame(kind, kids, shown) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return end)
        rawset(f, "IsVisible", function() return shown ~= false end); rawset(f, "IsShown", function() return shown ~= false end)
        return f end
    local function finish(f) for _, k in ipairs(KEYS) do if rawget(f, k) == nil then rawset(f, k, false) end end return f end
    local header = frame("Button"); rawset(header, "Arrow", tex()); rawset(header, "Left", tex()); rawset(header, "Middle", tex()); rawset(header, "Right", tex()); finish(header)
    local row = frame("Button"); rawset(row, "NormalTexture", tex()); rawset(row, "SelectedHighlight", tex()); finish(row)
    local ibtn = finish(frame("Button")); rawset(ibtn, "Icon", tex("ARTWORK")); rawset(ibtn, "IconBorder", tex()); rawset(ibtn, "CircleMask", newmock())
    local display = frame("Button"); rawset(display, "ItemButton", ibtn); rawset(display, "Name", newmock()); rawset(display, "Background", tex()); rawset(display, "NineSlice", frame("Frame")); finish(display)
    local money = frame("EditBox"); rawset(money, "left", tex()); rawset(money, "right", tex()); rawset(money, "texture", tex()); finish(money)
    local panel = frame("Frame", { header, row, display, money }); rawset(panel, "NineSlice", frame("Frame")); rawset(panel, "Background", tex()); finish(panel)
    local hiddenRow = frame("Button"); rawset(hiddenRow, "NormalTexture", tex()); rawset(hiddenRow, "SelectedHighlight", tex()); finish(hiddenRow)
    local hidden = finish(frame("Frame", { hiddenRow }, false))
    known.AuctionHouseFrame = frame("Frame", { panel, hidden })
    known.__ah = { panel = panel, header = header, row = row, display = display, ibtn = ibtn, money = money, hiddenRow = hiddenRow, hidden = hidden }
end
do  -- a confirmation box as this client builds it: a frame piece laid over the box, red buttons in a holder, a warning icon
    local function tex() local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return "ARTWORK" end)
        rawset(x, "__alpha", { 1 }); rawset(x, "SetAlpha", function(_, a) rawget(x, "__alpha")[1] = a end); return x end
    local function frame(kind, kids) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end)
        rawset(f, "__alpha", { 1 }); rawset(f, "SetAlpha", function(_, a) rawget(f, "__alpha")[1] = a end); return f end
    local function redButton()
        local b = frame("Button")
        local normal, pushed, disabled, highlight = tex(), tex(), tex(), tex()
        rawset(b, "GetNormalTexture", function() return normal end); rawset(b, "GetPushedTexture", function() return pushed end)
        rawset(b, "GetDisabledTexture", function() return disabled end); rawset(b, "GetHighlightTexture", function() return highlight end)
        for _, k in ipairs({ "Left", "Middle", "Right", "Center" }) do rawset(b, k, false) end
        return b, normal
    end
    local yes, yesArt = redButton()
    local no = redButton()
    local holder = frame("Frame", { yes, no }); rawset(holder, "Button1", yes); rawset(holder, "Button2", no); rawset(holder, "Button3", false); rawset(holder, "Button4", false)
    local over = frame("Frame")
    local icon = tex()
    local box = frame("Frame", { over, holder })
    rawset(box, "BG", over); rawset(box, "ButtonContainer", holder); rawset(box, "AlertIcon", icon)
    for _, k in ipairs({ "Border", "NineSlice", "Bg", "Background", "Backdrop", "Text", "text", "Buttons", "extraButton", "ExtraButton",
                         "button1", "button2", "button3", "button4", "Button1", "Button2", "Button3", "Button4", "TitleText", "TitleContainer", "Inset", "BorderFrame", "CloseButton" }) do rawset(box, k, false) end
    known.StaticPopup3 = box
    known.__popup = { box = box, over = over, yes = yes, yesArt = yesArt, no = no, icon = icon }
end
do  -- group finder, from its real outline: a shell, one page showing and one hidden, a side tab and the pieces on a page
    local function tex(layer) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end)
        rawset(x, "__alpha", { 1 }); rawset(x, "SetAlpha", function(_, a) rawget(x, "__alpha")[1] = a end); rawset(x, "IsShown", function() return false end); return x end
    local KEYS = { "SelectedTexture", "Icon", "Background", "Mask", "HighlightTexture", "Arrow", "Left", "Right", "LeftActive", "LeftDisabled", "CheckButton", "cover", "Cover", "Label", "TopLeftTex",
                   "Checkbox", "Border", "CustomBG", "NineSlice", "Bg", "Track", "Back", "Forward", "ScrollTarget", "CloseButton", "Inset", "BorderFrame", "TitleText", "TitleContainer" }
    local function frame(kind, kids, shown, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return table.unpack(regions or {}) end)
        rawset(f, "IsVisible", function() return shown ~= false end); rawset(f, "IsShown", function() return shown ~= false end)
        return f end
    local function finish(f) for _, k in ipairs(KEYS) do if rawget(f, k) == nil then rawset(f, k, false) end end return f end
    local tab = frame("Frame"); rawset(tab, "Background", tex()); rawset(tab, "SelectedTexture", tex()); rawset(tab, "Icon", tex("ARTWORK")); rawset(tab, "Mask", newmock()); rawset(tab, "HighlightTexture", tex()); finish(tab)
    local dropdown = frame("Button"); rawset(dropdown, "Arrow", tex()); rawset(dropdown, "Background", tex()); finish(dropdown)
    local tick = frame("CheckButton", nil, true, { tex(), tex() }); finish(tick)
    local role = frame("Button"); rawset(role, "Background", tex()); rawset(role, "CheckButton", tick); rawset(role, "cover", tex()); finish(role)
    local category = frame("Button"); rawset(category, "Cover", tex()); rawset(category, "Icon", tex("ARTWORK")); rawset(category, "Label", newmock()); finish(category)
    local comment = frame("ScrollFrame"); rawset(comment, "TopLeftTex", tex()); rawset(comment, "MiddleTex", tex()); finish(comment)
    local inset = frame("Frame"); rawset(inset, "Border", tex()); rawset(inset, "CustomBG", tex()); finish(inset)
    local loose = tex("BACKGROUND")
    local page = frame("Frame", { dropdown, role, category, comment, inset }, true, { loose })
    rawset(page, "Bg", tex()); rawset(page, "NineSlice", frame("Frame")); rawset(page, "BackgroundArt", tex()); finish(page)
    local hiddenDropdown = frame("Button"); rawset(hiddenDropdown, "Arrow", tex()); rawset(hiddenDropdown, "Background", tex()); finish(hiddenDropdown)
    local hiddenPage = finish(frame("Frame", { hiddenDropdown }, false))
    local shellArt = tex("ARTWORK")
    local eye = frame("Button"); rawset(eye, "__alpha", { 1 }); rawset(eye, "SetAlpha", function(_, a) rawget(eye, "__alpha")[1] = a end); finish(eye)
    known.LFGParentFrame = finish(frame("Frame", { tab, page, hiddenPage }, true, { shellArt }))
    known.LFGListingFrame, known.LFGBrowseFrame, known.LFGParentFramePortrait = page, hiddenPage, eye
    known.__lfg = { tab = tab, dropdown = dropdown, role = role, tick = tick, category = category, comment = comment, inset = inset, page = page, loose = loose,
                    hiddenPage = hiddenPage, hiddenDropdown = hiddenDropdown, shellArt = shellArt, eye = eye }
end
do  -- talent tree, from its real outline: three talents in different states, one whose state is unreadable
    local function tex() local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return "BORDER" end)
        rawset(x, "__alpha", { 1 }); rawset(x, "SetAlpha", function(_, a) rawget(x, "__alpha")[1] = a end); return x end
    local function frame(kind, kids) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end); return f end
    local function node(state) local b = frame("Button"); rawset(b, "Icon", tex()); rawset(b, "StateBorder", tex()); rawset(b, "IconMask", newmock())
        rawset(b, "DisabledOverlay", false); rawset(b, "visualState", state or false); rawset(b, "MainRing", false); return b end
    local canTake, full, locked, unknown = node(5), node(6), node(4), node(nil)
    local buttons = frame("Frame", { canTake, full, locked, unknown }); rawset(buttons, "MainRing", false)
    local heading = frame("Frame"); rawset(heading, "MainRing", tex()); rawset(heading, "Name", newmock())
    local tree = frame("Frame", { buttons, heading })
    for _, k in ipairs({ "DividerHorizontalLeft", "DividerHorizontalRight", "DividerVerticalLeft", "DividerVerticalRight", "BackgroundBorder", "ClassCurrencyDisplay" }) do rawset(tree, k, false) end
    local host = frame("Frame"); rawset(host, "TalentsFrame", tree); rawset(host, "SpellBookFrame", false)
    known.PlayerSpellsFrame = host
    known.TalentButtonUtil = { BaseVisualState = { Normal = 1, Gated = 2, Disabled = 3, Locked = 4, Selectable = 5, Maxed = 6, Invisible = 7, RefundInvalid = 8, DisplayError = 9 } }
    known.__talents = { canTake = canTake, full = full, locked = locked, unknown = unknown, heading = heading }
end
do  -- class trainer, from its real outline
    local function tex(layer) local x = newmock(); rawset(x, "GetObjectType", function() return "Texture" end); rawset(x, "GetDrawLayer", function() return layer or "BORDER" end)
        rawset(x, "__alpha", { 1 }); rawset(x, "SetAlpha", function(_, a) rawget(x, "__alpha")[1] = a end); return x end
    local function frame(kind, kids, regions) local f = newmock(); rawset(f, "GetObjectType", function() return kind end)
        rawset(f, "GetChildren", function() return table.unpack(kids or {}) end); rawset(f, "GetRegions", function() return table.unpack(regions or {}) end)
        rawset(f, "IsVisible", function() return true end); rawset(f, "IsShown", function() return true end); return f end
    local function row()
        local icon, sel, plate, hl = tex("OVERLAY"), tex(), tex(), tex("HIGHLIGHT")
        local r = frame("Button", nil, { icon, sel, plate, hl })
        rawset(r, "icon", icon); rawset(r, "selectedTex", sel); rawset(r, "disabledBG", false); rawset(r, "lock", false); rawset(r, "name", newmock())
        return r, plate, hl
    end
    local r1, plate1, hl1 = row()
    local step = row()
    local notRow = frame("Frame"); rawset(notRow, "icon", false); rawset(notRow, "name", false)
    local target = frame("Frame", { r1, notRow })
    local box = frame("Frame"); rawset(box, "ScrollTarget", target)
    local win = frame("Frame"); rawset(win, "ScrollBox", box); rawset(win, "skillStepButton", step); rawset(win, "BG", tex())
    known.ClassTrainerFrame = win
    known.ClassTrainerFrameMoneyBg = tex()
    known.__trainer = { row = r1, step = step, notRow = notRow, plate = plate1, hl = hl1 }
end
do  -- the game's own loot roll frames, which must stay out of sight while ours are in use
    local function frame()
        local f = newmock()
        local state = { alpha = 1, mouse = true }
        rawset(f, "state", state)
        rawset(f, "SetAlpha", function(_, a) state.alpha = a end)
        rawset(f, "GetAlpha", function() return state.alpha end)
        rawset(f, "EnableMouse", function(_, on) state.mouse = on end)
        rawset(f, "IsMouseEnabled", function() return state.mouse end)
        rawset(f, "IsProtected", function() return false end)
        rawset(f, "IsForbidden", function() return false end)
        rawset(f, "GetChildren", function() return end)
        return f
    end
    known.GroupLootContainer = frame()
    known.GroupLootFrame1 = frame()
    known.GroupLootFrame2 = frame()
    for i = 3, 8 do known["GroupLootFrame" .. i] = false end
end
do  -- an action button that remembers where each texture made on it was put
    local b = newmock()
    local made = {}
    rawset(b, "GetName", function() return "ExtraActionButton1" end)
    rawset(b, "IsForbidden", function() return false end)
    rawset(b, "CreateTexture", function(_, _, layer, _, sub) local tx = newmock(); made[#made + 1] = { layer = layer, sub = sub }; return tx end)
    known.ExtraActionButton1 = b
    known.__actionButtonTextures = made
end
-- loot confirmations and role checks: counted, for the tests
known.__bound, known.__roles = {}, 0
known.ConfirmLootSlot = function(slot) known.__bound[#known.__bound + 1] = slot end
known.CompleteLFGRoleCheck = function() known.__roles = known.__roles + 1 end
-- invites and duels: counted, for the tests
known.__invited, known.__duels = {}, 0
known.C_PartyInfo.InviteUnit = function(name) known.__invited[#known.__invited + 1] = name end
known.CancelDuel = function() known.__duels = known.__duels + 1 end
-- resurrections and summons: what the game would answer, changed by the tests
known.__res = { offerer = "Healer", delay = 0, combat = false, accepted = 0 }
known.AcceptResurrect = function() known.__res.accepted = known.__res.accepted + 1 end
known.ResurrectGetOfferer = function() return known.__res.offerer end
known.GetCorpseRecoveryDelay = function() return known.__res.delay end
known.UnitAffectingCombat = function(unit) if unit == "Healer" then return known.__res.combat end return true end
known.__summon = { who = "Warlock", left = 60, confirmed = 0 }
known.C_SummonInfo = { ConfirmSummon = function() known.__summon.confirmed = known.__summon.confirmed + 1 end,
                       GetSummonConfirmSummoner = function() return known.__summon.who end,
                       GetSummonConfirmAreaName = function() return "Orgrimmar" end,
                       GetSummonConfirmTimeLeft = function() return known.__summon.left end }
env._G = env
setmetatable(env, { __index = function(t, k)
    local v = known[k]
    if v ~= nil then return v end
    if type(k) == 'string' and (k:match('^ContainerFrame%d') or k == 'ChatFrameUtil' or k == 'FantasyGlassUIDB' or k == 'Stylish' .. 'UIDB') then return nil end
    missing[k] = true
    local m = newmock(); rawset(t, k, m); return m
end })

local ns = {}
ns.keepAllLocales = true                                   -- (the tests switch language back and forth; the trim has a test of its own)
-- The options folder: the game loads it only when the add-on asks, so the harness does the same.
local optionsPresent, optionLoads = true, 0
local out = {}
for _, f in ipairs(files) do
    local fn, err = load(sources[f], "@" .. f, "t", env)
    if not fn then error(err) end
    local ok, e = pcall(fn, "FantasyGlassUI", ns)
    if not ok then out[#out+1] = "LOAD ERROR " .. f .. ": " .. tostring(e) end
end
local localeLoads = 0
local function LoadLocalesFolder()
    localeLoads = localeLoads + 1
    local fn, err = load(sources["locales/Locales.lua"], "@Locales.lua", "t", env)
    if not fn then error(err) end
    local ok, e = pcall(fn, "FantasyGlassUI_Locales", {})
    if not ok then out[#out+1] = "LOAD ERROR Locales.lua: " .. tostring(e) end
end
LoadLocalesFolder()                                        -- (the tests use every language; the on-demand load has a test of its own)
rawset(env.C_AddOns, "LoadAddOn", function(name)
    if name == "FantasyGlassUI_Locales" then LoadLocalesFolder(); return true end
    if name ~= "FantasyGlassUI_Options" or not optionsPresent then return false, "MISSING" end
    optionLoads = optionLoads + 1
    for _, f in ipairs(optionFiles) do
        local fn, err = load(sources[f], "@" .. f, "t", env)
        if not fn then error(err) end
        local ok, e = pcall(fn, "FantasyGlassUI_Options", {})        -- (its own private table, as in the game: not the main add-on's)
        if not ok then out[#out+1] = "LOAD ERROR " .. f .. ": " .. tostring(e) end
    end
    return true
end)
local printed = {}
function ns:PrintRaw(msg) printed[#printed+1] = tostring(msg) end       -- every message ends up here, errors included

if secretMode then env.FantasyGlassUIDB = { profiles = { Default = { actionBars = true, accent = "VIOLET", role = "TANK", pos = { minimap = { "TOPRIGHT", "TOPRIGHT", -30, -30 } } } }, chars = {} } end
ns:InitDB(); ns:ApplyTheme()
if secretMode then
    local okMig = ns.profile == "Default" and ns.db.accent == "AZURE" and ns.db.theme == "SMOKE" and ns.db.pos.minimap[3] == -30
        and env.FantasyGlassUIDB.profiles.Default == ns.db and env.FantasyGlassUIDB.chars["Someone - Realm"] == "Default" and not ns.settingsReset
    if not okMig then out[#out+1] = "settings in the current format were not read as they are" end
end
for _, m in ipairs(ns.modules) do
    ns.startingModule = m.key                    -- (as the add-on itself does: panels made now belong to this feature)
    local ok, err = pcall(m.fn)
    ns.startingModule = nil
    if not ok then out[#out+1] = "MODULE ERROR " .. m.key .. " -> " .. tostring(err) end
end
-- Everything above ran without the options folder: it must not have been needed, or loaded.
if ns.optionsLoaded or optionLoads ~= 0 then out[#out+1] = "the options folder was loaded before anything asked for it" end
if ns.featureGroups or ns.CheckFunctionLine then out[#out+1] = "something from the options folder is in memory at login" end
for name, stub in pairs(ns.optionsStubs) do
    if ns[name] ~= stub then out[#out+1] = "ns:" .. name .. " should be a stand-in until the options load" end
end
-- The first request loads it, once, and the real functions take over.
ns:ToggleConfig(); ns:ToggleConfig()
if not ns.optionsLoaded or optionLoads ~= 1 then out[#out+1] = "opening the options should load their folder exactly once (loads: " .. optionLoads .. ")" end
for name, stub in pairs(ns.optionsStubs) do
    if ns[name] == stub then out[#out+1] = "ns:" .. name .. " was not replaced when the options loaded" end
end
if not ns.featureGroups or not ns.configFrame then out[#out+1] = "the options did not come up after loading" end
local function try(name, f) local ok, e = pcall(f); if not ok then out[#out+1] = "CALL ERROR " .. name .. " -> " .. tostring(e) end end
local function fireEvent(ev, ...) for i = 1, #handlers do local h = handlers[i]; if h.name == "OnEvent" then pcall(h.fn, h.self, ev, ...) end end end
local timers = {}
env.C_Timer = { After = function(_, fn) if type(fn) == "function" then timers[#timers + 1] = fn end end }
local function runTimers()                                  -- run everything scheduled, including what those schedule (bounded)
    for _ = 1, 8 do
        if #timers == 0 then return end
        local batch = timers; timers = {}
        for _, fn in ipairs(batch) do
            local ok, e = pcall(fn)
            if not ok then out[#out+1] = "TIMER ERROR -> " .. tostring(e) end
        end
    end
    timers = {}
end
try("ToggleConfig", function() ns:ToggleConfig() end)
try("ShowSetup", function() ns:ShowSetup() end)
try("ToggleMove", function() ns:ToggleMove(); ns:ToggleMove() end)
try("ToggleQuestLog", function() ns:ToggleQuestLog(); ns:OpenQuestLog(5) end)
try("RaidStyle", function() ns.RaidStyle(newmock()); ns.RaidStyle(newmock()) end)
try("Preview", function() ns:TogglePreview(); if not ns.previewing then error("preview did not start") end end)
try("Config pages", function() ns:ToggleConfig("layout"); ns:ToggleConfig("profiles"); ns:ToggleConfig("colors"); ns:ToggleConfig("look"); ns:ToggleConfig("clickcast"); ns:ToggleConfig("combat"); ns:ToggleConfig("features") end)
try("Profiles", function()
    local ok1 = ns:NewProfile("Alt"); local s = ns:ExportProfile(); local ok2 = ns:ImportProfile("Imported", s)
    if not (ok1 and ok2 and ns.root.profiles.Imported.ufW == ns.db.ufW) then error("profile round trip failed") end
    if ns:ImportProfile("Bad", "garbage") then error("garbage import accepted") end
end)
try("Themes", function()
    for _, key in ipairs(ns.themeOrder) do
        ns.db.theme = key; ns:BuildPalette()
        local r, g, b, a = ns:T("border", 0.5)
        if type(r) ~= "number" or a ~= 0.5 or select("#", ns:T("text")) ~= 3 then error("palette broken for " .. key) end
        for _, role in ipairs({ "bg", "bg2", "bg3", "bg4", "window", "inset", "field", "trough", "plate", "plate2", "border", "text", "dim", "faint" }) do
            if type(ns.colors[role]) ~= "table" then error(key .. " lacks " .. role) end
        end
    end
    ns.db.theme = "SMOKE"; ns:BuildPalette()
    ns:SetChatBackground(40); ns.db.chatBg = 10; ns:ApplyChatBackground()
end)
try("AutoSkin controls", function()
    local function tex() local t = newmock(); rawset(t, "GetObjectType", function() return "Texture" end); rawset(t, "GetDrawLayer", function() return "ARTWORK" end); return t end
    local function frame(kind, name) local f = newmock(); rawset(f, "GetObjectType", function() return kind end); rawset(f, "GetName", function() return name end); rawset(f, "GetChildren", function() end); rawset(f, "GetRegions", function() return tex(), tex() end); return f end
    local win = frame("Frame", "TestWindow")
    local close = frame("Button", "TestWindowCloseButton")
    local push = frame("Button", "TestButton"); rawset(push, "Left", tex()); rawset(push, "Right", tex()); rawset(push, "Middle", tex())
    local tab = frame("Button", "TestTab1"); rawset(tab, "LeftActive", tex()); rawset(tab, "Left", tex())
    local box = frame("EditBox", "TestBox"); rawset(box, "Left", tex()); rawset(box, "Right", tex())
    local modern = frame("Frame", "TestScroll"); local track = frame("Frame"); rawset(track, "Thumb", frame("Frame")); rawset(modern, "Track", track); rawset(modern, "Back", frame("Button"))
    local old = frame("Slider", "TestSlider")
    local listbox = frame("Frame", "TestList"); local target = frame("Frame"); rawset(target, "GetChildren", function() return frame("Button", "Row1"), frame("Button", "Row2") end); rawset(target, "IsVisible", function() return true end); rawset(listbox, "ScrollTarget", target)
    rawset(win, "CloseButton", close)
    rawset(win, "GetChildren", function() return close, push, tab, box, modern, old, listbox end)
    ns:SkinWindow(win)
    for _, c in ipairs({ close, push, tab, box }) do if not rawget(c, "suiControl") then error("a control was not dressed: " .. c:GetName()) end end
    if not (rawget(modern, "suiControl") and rawget(old, "suiControl")) then error("scroll bars were not dressed") end
    ns:StripArt(win)
end)
try("Window opacity", function()
    ns.db.theme = "SMOKE"; ns.db.panelAlpha = 50; ns.db.windowAlpha = 95; ns:BuildPalette()
    local _, _, _, hud = ns:T("bg", 1)
    local _, _, _, win = ns:T("window", 1)
    if math.abs(hud - 0.5) > 0.001 or math.abs(win - 0.95) > 0.001 then error("HUD " .. hud .. " / window " .. win) end
    ns.db.theme = "WARM"; ns:BuildPalette()
    if select(4, ns:T("window", 1)) ~= 1 then error("fantasy windows should be fully solid") end
    ns.db.theme = "SMOKE"; ns.db.panelAlpha = 78; ns:BuildPalette()
end)
try("Scale", function() if not ns:SetPanelScale({ "ufPlayer", "minimap" }, 1.2) then error("scale refused") end
    if ns.db.scale.ufPlayer ~= 1.2 then error("scale not saved") end
    ns.db.ufW = 280; ns:ResizeUnitFrames(); ns.db.raidW = 90; if ns.ResizeRaid then ns:ResizeRaid() end end)
try("slash", function() env.SlashCmdList["FANTASYGLASSUI"]("status"); env.SlashCmdList["FANTASYGLASSUI"]("help"); env.SlashCmdList["FANTASYGLASSUI"]("layout") end)
try("Discord invite", function()
    local shown
    local real = ns.ShowCopyBox
    ns.ShowCopyBox = function(_, text) shown = text end
    env.SlashCmdList["FANTASYGLASSUI"]("discord")
    ns.ShowCopyBox = real
    if shown ~= "https://discord.gg/qeSMwQWyPR" then error("/fgui discord should show the invite to copy, got " .. tostring(shown)) end
end)

-- fire every registered script / hook with plausible arguments
local events = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_ENABLED",
                 "BAG_UPDATE_DELAYED", "MERCHANT_SHOW", "QUEST_COMPLETE", "GOSSIP_SHOW", "ZONE_CHANGED", "QUEST_LOG_UPDATE",
                 "UPDATE_INVENTORY_DURABILITY", "ADDON_LOADED", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_GREETING",
                 "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_AURA", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP",
                 "UNIT_SPELLCAST_CHANNEL_START", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE", "UNIT_PORTRAIT_UPDATE",
                 "UNIT_LEVEL", "RAID_TARGET_UPDATE", "PLAYER_UPDATE_RESTING",
                 "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "READY_CHECK", "READY_CHECK_FINISHED", "UNIT_ATTACK_SPEED",
                 "NAME_PLATE_UNIT_REMOVED", "PLAYER_XP_UPDATE", "UPDATE_FACTION", "ITEM_LOCK_CHANGED", "PLAYER_MONEY",
                 "GUILDBANKBAGSLOTS_CHANGED", "BANKFRAME_OPENED" }
local function fire()
    local n = #handlers
    for i = 1, n do
        local h = handlers[i]
        local function call(...) local ok, e = pcall(h.fn, ...); if not ok then out[#out+1] = "HANDLER ERROR [" .. tostring(h.name) .. "] -> " .. tostring(e) end end
        if h.name == "OnUpdate" then call(h.self, 2); call(h.self, 2)
        elseif h.name == "OnEvent" then
            for _, ev in ipairs(events) do call(h.self, ev, "nameplate1") end
            call(h.self, "NAME_PLATE_UNIT_ADDED", "nameplate1")
            call(h.self, "UI_INFO_MESSAGE", 1, "Wolves slain: 8/8")
            call(h.self, "CHAT_MSG_SAY", "Hello there", "Bob-Realm", nil, nil, nil, nil, nil, nil, nil, nil, nil, "Player-1-ABC")
            call(h.self, "START_LOOT_ROLL", 7, 60000); call(h.self, "CANCEL_LOOT_ROLL", 7)
            call(h.self, "UNIT_COMBAT", "player", "WOUND", "CRITICAL", 50, 1)
            call(h.self, "PLAYER_SWING", SV(2.6), 0); call(h.self, "PLAYER_SWING", SV(1.8), 1); call(h.self, "PLAYER_SWING", 2.2, 2)
            call(h.self, "UNIT_ATTACK_SPEED", "player")
        elseif h.name == "OnMouseWheel" then call(h.self, 1)
        elseif h.name == "chatfilter" then call(h.self, "CHAT_MSG_SAY", "see https://example.com/a?b=1 and www.test.org now", "Bob")
        elseif h.name == "PostClick" then call(h.self, "LeftButton", false); call(h.self, "LeftButton", true)
        elseif h.name == "OnAttributeChanged" then call(h.self, "unit", "raid3"); call(h.self, "unit", nil)
        elseif h.name == "OnClick" then call(h.self, "LeftButton"); call(h.self, "RightButton")
        elseif h.name == "hook" then call(newmock(), "player")
        else call(h.self) end
    end
end
for _, role in ipairs({ "DAMAGE", "TANK", "HEALER" }) do
    ns:SetRole(role)
    fire()
end
-- (Exercising every button above also clicked the language buttons. Put the language back to English,
--  and clear the "come back to the setup" mark, before any test reads a label.)
if ns.root then ns.root.language = nil; ns.root.resumeSetup = nil end
ns:LoadLocale()
ns.db.panelShow = {}                                       -- (and any "when to show" rules those clicks set)
ns:PanelShowTick()
try("Storage", function()
    local me = ns.root.inventory.chars["Someone - Realm"]
    if not (me and me.bags and #me.bags > 0) then error("bags were not recorded") end
    if not (me.bank and #me.bank > 0) then error("bank was not recorded") end
    local g = ns.root.inventory.guilds["Night Watch - Realm"]
    if not (g and g.tabs[2] and #g.tabs[2].items == 3 and g.tabs[2].name == "Materials") then error("guild bank was not recorded") end
    ns.root.inventory.chars["Alt - Realm"] = { class = "ROGUE", bags = { { "|Hitem:9|h[Alt Sword]|h", 1, 3, 134400 } }, time = 1799990000, money = 123456 }
    ns:OpenStorage("bank"); ns:OpenStorage("guild"); ns:OpenStorage("bags", "Alt - Realm")
    local coins = ns:Coins(615)
    if type(coins) ~= "string" or coins == "" then error("coins") end
end)
try("Class colors", function()
    local r0 = ns:ClassRGB("ROGUE")
    ns.db.classColors.ROGUE = { 0.1, 0.2, 0.3 }
    local r, g, b = ns:ClassRGB("ROGUE")
    if r ~= 0.1 or g ~= 0.2 or b ~= 0.3 then error("custom class color not used") end
    if ns:ClassRGB("NOPE") ~= nil then error("unknown class should have no color") end
    local s = ns:ExportProfile(); local ok = ns:ImportProfile("WithColors", s)
    if not ok or ns.root.profiles.WithColors.classColors.ROGUE[2] ~= 0.2 then error("class colors lost on export/import") end
    ns.db.classColors.ROGUE = nil
    if ns:ClassRGB("ROGUE") ~= r0 then error("reset did not restore the default") end
end)
try("Item counts", function()
    local lines = {}
    local tip = { AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " = " .. r end }
    local link = "|Hitem:101:0|h[Junk Cloth]|h"
    ns.root.inventory.chars["Alt - Realm"] = { class = "ROGUE", bags = { { link, 5, 1, 1 } }, bank = { { link, 7, 1, 1 } } }
    ns.root.inventory.chars["Bob - Realm"] = { class = "ROGUE", bags = { { link, 3, 1, 1 } } }
    ns.root.inventory.guilds["Night Watch - Realm"].tabs[5] = { name = "Cloth", items = { { link, 20, 1, 1 } } }
    if not ns:AddItemCounts(tip, link) then error("no counts for a recorded item") end
    local joined = table.concat(lines, " / ")
    for _, want in ipairs({ "Alt", "12", "bags 5, bank 7", "Bob", "Night Watch", "guild bank", "Total = 35" }) do
        if not joined:find(want, 1, true) then error("missing '" .. want .. "' in: " .. joined) end
    end
    if ns:AddItemCounts(tip, "|Hitem:999999|h[Nothing]|h") then error("counts for an item nobody has") end
end)
try("Click cast", function()
    ns.db.clickCast = { { mod = "shift", button = 1, spell = "Renew" }, { mod = "", button = 3, spell = "Heal" }, { mod = "bogus", button = 9, spell = "x" } }
    if not ns:ApplyClickCast() then error("click cast did not apply out of combat") end
    ns.db.clickCast = {}
    ns:ApplyClickCast()
end)
try("Live theme", function()
    ns.db.theme = "SMOKE"; ns:Retheme()          -- earlier clicks in this run may have left any theme selected
    ns.db.theme = "MIDNIGHT"; ns.db.accent = "VIOLET"; ns.db.fontStyle = "CLEAN"
    if not ns:Retheme() then error("retheme within the glass family should not need a reload") end
    ns.db.theme = "WARM"; if ns:Retheme() then error("changing family should ask for a reload") end
    ns.db.theme = "SMOKE"; ns.db.accent = "AZURE"; ns.db.fontStyle = "GLASS"; ns:Retheme()
    ns:ApplyRoleLayout("HEALER"); ns:ApplyRoleLayout("TANK")
end)
try("Self-check", function()
    local out = ns:SelfCheck()
    local text = table.concat(out, "\n")
    for _, want in ipairs({ "self-check", "by DustyMouse", "FEATURES", "GAME FUNCTIONS", "EVENTS", "BLIZZARD FRAMES", "unitFrames" }) do
        if not text:find(want, 1, true) then error("report lacks " .. want) end
    end
end)
try("Sell junk", function() ns:SellJunk(true) end)
try("Chat bubbles", function()
    local holder = known.__bubbleHolder
    if not rawget(holder, "suiBubble") then error("the bubble was not dressed") end
    if not rawget(holder, "suiName") then error("the bubble has no name label") end
end)
try("Combat trackers", function()
    ns.db.cooldownSpells = { "Fireball", "Unknown Spell", "Frost Nova" }
    if ns:RebuildCooldowns() ~= 2 then error("expected 2 known cooldown spells") end
    ns.db.alertBuffs = { "Clearcasting" }; if ns.RefreshAlerts then ns.RefreshAlerts() end
    ns.db.fontScale = 120; ns:Retheme(); if math.abs(ns.fontScale - 1.2) > 0.001 then error("text scale") end
    ns.db.fontScale = 100; ns:Retheme()
    if ns.L["Never translated"] ~= "Never translated" then error("missing translations should fall back to English") end
    ns.locales.enUS = { ["Sort"] = "Sortieren" }; ns:LoadLocale()
    if ns:Tr("Sort") ~= "Sortieren" or not ns.seenStrings["Sort"] then error("translation lookup") end
    rawset(ns.L, "Sort", nil)
end)
try("Strings export", function() if ns:ExportStrings() < 20 then error("too few labels collected") end end)
try("Character window", function()
    local c = known.__char
    if not rawget(c.slot, "suiSlot") or not rawget(c.slot, "suiLevel") or not rawget(c.slot, "suiBorder") then error("equipment slot not styled") end
    if not rawget(c.tab, "suiTab") or rawget(c.tab, "suiSelected") ~= true then error("mode tab not styled, or its selected state was not read") end
    for name, f in pairs({ header = c.header, row = c.row, sidebar = c.sidebar, control = c.control }) do
        if not rawget(f, "suiChar") then error(name .. " was not reached") end
    end
    if ns:DumpTree("CharacterFrame") < 4 then error("tree dump too short") end
    env.SlashCmdList["FANTASYGLASSUI"]("tree CharacterFrame")
end)
try("Setup again", function()
    ns:ShowSetup()
    ns.db.theme = "MIDNIGHT"; ns.db.fontStyle = "CLEAN"; ns.db.role = "HEALER"
    ns:ShowSetup()                               -- reopening must pick up the changed settings without error
    ns.db.theme = "SMOKE"; ns.db.fontStyle = "GLASS"; ns:Retheme()
end)
try("Aura lock at login", function()
    local toc = select(4, env.GetBuildInfo())
    if (toc == 16001) ~= (ns.aurasLocked == true) then error("lock flag does not match the client: " .. tostring(toc) .. " / " .. tostring(ns.aurasLocked)) end
    if ns.aurasLocked and ns.loaded.auraBars and env.FantasyGlassUIAuras then error("our buff bars should stand down on a locked client") end
end)
try("Aura lock", function()
    local real = env.C_UnitAuras.GetAuraDataByIndex
    local combat = env.InCombatLockdown
    env.C_UnitAuras.GetAuraDataByIndex = function() error("Auras cannot be accessed when secret while tainted by 'FantasyGlassUI'") end
    env.InCombatLockdown = function() return true end
    env.FantasyGlassUIDB.aurasLocked = nil
    if ns.GetAura("player", 1, "HELPFUL") ~= nil then error("a refused read must come back as nil") end
    if not ns.auraLock or not env.FantasyGlassUIDB.aurasLocked then error("the refusal was not remembered") end
    if ns.GetAura("target", 1, "HARMFUL") ~= nil then error("no reads while locked") end
    env.C_UnitAuras.GetAuraDataByIndex = real
    env.InCombatLockdown = combat
    ns.auraLock = false
end)
try("Tree of hovered window", function()
    env.GetMouseFoci = function() return { known.__char.slot } end      -- mouse over a slot: should climb to CharacterFrame
    local lines = ns:DumpTree()
    if not lines or lines < 5 then error("hover dump failed") end
    env.GetMouseFoci = function() return {} end
    if ns:DumpTree() ~= nil then error("nothing under the mouse should just print a hint") end
end)
try("Window polish", function()
    local p = known.__polish
    for name, f in pairs({ header = p.header, column = p.column }) do
        if not rawget(f, "suiHeading") then error(name .. " did not get a heading") end
    end
    if not rawget(p.check, "suiBoxDone") then error("quest checkbox not tinted") end
    if not rawget(p.qtab, "suiTab") then error("quest panel tab not styled") end
    if not rawget(p.count, "suiPolish") or not rawget(p.side, "suiPolish") or not rawget(p.scroll, "suiPolish") then error("a piece was not reached") end
end)
try("Raid mode", function()
    if ns.aurasLocked and ns.raidMode ~= "game" then error("locked client should restyle the game's raid frames") end
    if not ns.aurasLocked and ns.raidMode ~= "ours" then error("unlocked client should use our raid frames") end
end)
try("Small character tabs", function()
    local a, b = known.PaperDollSidebarTab1, known.PaperDollSidebarTab2
    if not rawget(a, "suiPlate") or not rawget(b, "suiPlate") then error("tabs did not take the plate although their piece counts differ") end
    if rawget(a, "suiSelected") ~= true or rawget(b, "suiSelected") ~= false then error("wrong tab marked as selected") end
end)
try("Layout sharing", function()
    ns.db.pos = { ufPlayer = { "CENTER", "CENTER", -250, -180 } }; ns.db.scale = { ufPlayer = 1.2 }; ns.db.ufW = 244
    local text = ns:ExportLayout()
    if text:sub(1, 6) ~= "SUIL1!" then error("bad layout header") end
    ns.db.pos = {}; ns.db.scale = {}; ns.db.ufW = 200
    local ok, msg = ns:ImportLayout(text)
    if not ok then error("layout import refused: " .. tostring(msg)) end
    if ns.db.pos.ufPlayer[3] ~= -250 or ns.db.scale.ufPlayer ~= 1.2 or ns.db.ufW ~= 244 then error("layout did not round-trip") end
    for _, bad in ipairs({ "", "hello", "SUIL1!{", ns:ExportProfile(), "SUIL1!N5;" }) do
        if ns:ImportLayout(bad) then error("a bad layout string was accepted: " .. bad:sub(1, 12)) end
    end
    ns:ApplyLayout({ pos = { x = { "CENTER", "CENTER", 0, 0 }, y = "junk" }, scale = { x = 99 }, size = { ufW = 9999, evil = 1 } })
    if ns.db.scale.x ~= 2 or ns.db.ufW ~= 400 or ns.db.pos.y ~= nil or ns.db.evil ~= nil then error("layout values were not cleaned") end
    ns.db.ufW = 220; ns.db.scale = {}; ns.db.pos = {}
end)
try("Layout per talent set", function()
    local set = 1
    env.C_SpecializationInfo.GetActiveSpecGroup = function() return set end
    ns.db.specLayouts = true; ns.db.groupLayouts = false; ns.db.layouts = {}; ns.db.layoutCtx = "1"
    ns.db.pos = { ufPlayer = { "CENTER", "CENTER", -100, -100 } }
    set = 2
    fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
    if not ns.db.layouts["1"] or ns.db.layouts["1"].pos.ufPlayer[3] ~= -100 then error("leaving set 1 did not save its layout") end
    ns.db.pos = { ufPlayer = { "CENTER", "CENTER", 300, 0 } }
    set = 1
    fireEvent("ACTIVE_TALENT_GROUP_CHANGED")
    if ns.db.pos.ufPlayer[3] ~= -100 then error("returning to set 1 did not restore its layout") end
    if ns.db.layouts["2"].pos.ufPlayer[3] ~= 300 then error("set 2 layout not saved") end
    ns.db.specLayouts = false; ns.db.pos = {}; ns.db.layouts = {}
end)
try("What's new", function()
    env.FantasyGlassUIDB.seenVersion = "8.7.1"; ns.freshInstall = false
    local text = ns:WhatsNew()
    -- after a long break: the five newest releases, and a count of the rest
    local _, shownCount = text:gsub("Version %d", "")
    if not text or shownCount ~= 5 or not text:find("Version " .. ns.version, 1, true) or not text:find("earlier updates since yours", 1, true)
        or text:find("Version 8.8.0", 1, true) then error("wrong notes for an update from 8.7.1") end
    -- 8.12.0 is newer than 8.7.1: versions are compared as numbers, not as text
    env.FantasyGlassUIDB.seenVersion = "8.7.1"
    local saveNew = ns.whatsNew
    ns.whatsNew = { { "9.0.0", { "a" } }, { "8.12.0", { "b" } }, { "8.8.0", { "c" } }, { "8.7.0", { "d" } } }
    text = ns:WhatsNew()
    ns.whatsNew = saveNew
    if not text:find("Version 8.12.0", 1, true) or not text:find("Version 8.8.0", 1, true) or text:find("Version 8.7.0", 1, true) then error("8.12.0 should count as newer than 8.7.1") end
    -- asked for by hand, it is the last four releases, not the whole history
    local all = ns:WhatsNew(true)
    local _, count = all:gsub("Version %d", "")
    if count ~= 4 or not all:find("Version " .. ns.version, 1, true) then error("/fgui new should show the last four releases, newest first, showed " .. count) end
    env.FantasyGlassUIDB.seenVersion = "8.7.1"
    text = ns:WhatsNew()
    if ns:WhatsNew() ~= nil then error("the note must appear once per update") end
    env.FantasyGlassUIDB.seenVersion = nil; ns.freshInstall = true
    if ns:WhatsNew() ~= nil then error("no notes on a first install") end
end)
try("Translatable messages", function()
    ns.locales.enUS = { ["Sold junk for %s"] = "Schrott verkauft: %s" }; ns:LoadLocale()
    local said
    local real = ns.PrintRaw
    ns.PrintRaw = function(_, m) said = m end
    ns:Print("Sold junk for %s", "3g")
    ns.PrintRaw = real
    rawset(ns.L, "Sold junk for %s", nil)
    if said ~= "Schrott verkauft: 3g" then error("got: " .. tostring(said)) end
end)
try("Options match the client", function()
    if ns.aurasLocked then
        if ns.RefreshAlerts then error("buff alerts should not start on a locked client") end
    else
        if not ns.RefreshAlerts then error("buff alerts should run on an unlocked client") end
    end
    if env.FantasyGlassUIDB.seenVersion ~= nil and ns:WhatsNew(true) == nil then error("forced what's-new came back empty") end
end)
try("Reputation page", function()
    local r = known.__rep
    if not rawget(r.header, "suiHeading") then error("reputation header not restyled") end
    if not rawget(r.faction, "suiRep") or not rawget(r.bar, "suiBar") then error("faction row or its bar not restyled") end
    if not rawget(rawget(r.detail, "StandingBar"), "suiBar") or not rawget(r.check, "suiCheck") then error("detail pane not restyled") end
end)
try("Skills page", function()
    local k = known.__skills
    if not rawget(k.header, "suiHeading") then error("skills header not restyled") end
    if not rawget(k.skill, "suiRep") or not rawget(k.bar, "suiBar") then error("skill row or its bar not restyled") end
    if not rawget(rawget(k.detail, "RankBar"), "suiBar") then error("rank bar in the detail pane not restyled") end
    local alpha = rawget(k.bar, "__alpha")
    if alpha.art ~= 0 then error("the bar's decorative frame should be hidden") end
    if alpha.fill ~= nil then error("the bar's fill must never be hidden") end
end)
try("PvP page", function()
    local v = known.__pvp
    if not rawget(v.sub, "suiHeading") then error("PvP sub-heading not restyled") end
    if rawget(v.plain, "suiHeading") then error("a plain line must not become a heading") end
    if not rawget(v.slot, "suiTinted") or not rawget(v.main, "suiPvp") then error("slot or main area not reached") end
end)
try("Statistics page", function()
    if not rawget(known.__stat, "suiRep") then error("statistics entry not restyled") end
end)
try("Totems and imbue", function()
    if not ns.totemState then error("totem timers never reported a state") end
    if secretMode and not ns.totemState:find("hidden", 1, true) then error("hidden totem values should be handled, got: " .. ns.totemState) end
end)
try("Info bar details", function()
    ns.db.infobarExtras = true
    for _, h in ipairs(handlers) do
        if h.name == "OnEnter" then pcall(h.fn, h.self) end      -- includes the info bar's tooltip
    end
end)
try("Warnings", function()
    -- the low health / mana glow was removed: nothing of it may remain, even for a profile that had it on
    ns.db.lowWarning = true
    for _, m in ipairs(ns.modules) do if m.key == "lowWarning" then error("the low-health glow module is still registered") end end
    if ns.warnState ~= nil then error("the low-health glow still reports a state") end
    for _, group in ipairs(ns.featureGroups) do
        for _, opt in ipairs(group[2]) do if opt[1] == "lowWarning" then error("the switch is still on the Features tab") end end
    end
    if ns.featureDesc.lowWarning then error("its description is still there") end
    -- every switch that needs another names one that exists and starts on
    for child, parent in pairs(ns.featureNeeds or {}) do
        if ns.defaults[child] == nil or ns.defaults[parent] ~= true then error("needs: " .. child .. " -> " .. parent) end
    end
    if not ns.featureNeeds or ns.featureNeeds.tipHealth ~= "playerTips" then error("the switch dependencies are missing") end
    local aggro = false
    for _, m in ipairs(ns.modules) do if m.key == "aggroWarn" then aggro = true end end
    if not aggro then error("the aggro warning must still be there") end
    ns.db.lowWarning = nil
end)
try("Keybind mode", function()
    if ns:KeybindCommandFor("ActionButton3") ~= "ACTIONBUTTON3" then error("main bar command") end
    if ns:KeybindCommandFor("MultiBar5Button12") ~= "MULTIACTIONBAR5BUTTON12" then error("extra bar command") end
    if ns:KeybindCommandFor("MultiBarBottomLeftButton1") ~= "MULTIACTIONBAR1BUTTON1" then error("bottom-left bar command") end
    if ns:KeybindCommandFor("SomeOtherFrame7") ~= nil then error("an unrelated frame must not be bindable") end
    ns:ToggleKeybindMode(); ns:ToggleKeybindMode()
end)
try("AFK screen", function()
    local alpha
    local realSet = env.UIParent.SetAlpha
    rawset(env.UIParent, "SetAlpha", function(_, a) alpha = a end)
    ns.db.afkScreen = true                        -- (earlier clicks in this run may have applied a preset)
    env.UnitIsAFK = function() return true end
    fireEvent("PLAYER_FLAGS_CHANGED")
    if alpha ~= 0 then error("going AFK should fade the interface") end
    fireEvent("PLAYER_REGEN_DISABLED")
    if alpha ~= 1 then error("a fight starting must bring the interface back") end
    env.UnitIsAFK = function() return false end
    fireEvent("PLAYER_FLAGS_CHANGED")
    if alpha ~= 1 then error("coming back must restore the interface") end
    rawset(env.UIParent, "SetAlpha", realSet)
end)
try("Bar size", function()
    ns.db.barScale = 100; ns:ApplyBarScale()
    ns.db.barScale = 120; ns:ApplyBarScale()
    ns.db.barScale = 100; ns:ApplyBarScale()
end)
try("Session stats", function()
    fireEvent("PLAYER_ENTERING_WORLD"); fireEvent("QUEST_TURNED_IN"); fireEvent("PLAYER_DEAD")
    fireEvent("TIME_PLAYED_MSG", 200000, 4000)
    local rows = ns:SessionStats()
    local text = {}
    for _, r in ipairs(rows) do text[#text + 1] = tostring(r[1]) .. "=" .. tostring(r[2]) end
    text = table.concat(text, " | ")
    for _, want in ipairs({ "This session", "Quests / kills / deaths", "Time played=2d 7h", "Time at this level=1h 06m" }) do
        if not text:find(want, 1, true) then error("missing '" .. want .. "' in: " .. text) end
    end
    if ns.session.quests < 1 or ns.session.deaths < 1 then error("events were not counted") end
    ns:PrintSession()
end)
try("Cooldown auto-fill", function()
    local real = env.C_Spell.GetSpellName
    env.C_Spell.GetSpellName = function(id) return "Spell " .. id end
    local names = ns:CooldownCandidates(9)
    env.C_Spell.GetSpellName = real
    -- slots 1-4 are spells 101-104; 102 has only the global cooldown; slot 5 is a macro; slot 6 repeats 101
    if #names ~= 3 or names[1] ~= "Spell 101" or names[2] ~= "Spell 103" or names[3] ~= "Spell 104" then
        error("got: " .. table.concat(names, ", "))
    end
end)
try("Upgrade arrow", function()
    local realInstant, realLevel, realWorn = env.C_Item.GetItemInfoInstant, env.C_Item.GetDetailedItemLevelInfo, env.GetInventoryItemLink
    env.C_Item.GetItemInfoInstant = function(link) return 1, "Armor", "Mail", (link:find("ring") and "INVTYPE_FINGER") or (link:find("potion") and "") or "INVTYPE_HEAD", 1, 4, 3 end
    env.C_Item.GetDetailedItemLevelInfo = function(link) return tonumber(link:match("L(%d+)")) end
    env.GetInventoryItemLink = function(_, slot) if slot == 1 then return "worn helm L10" elseif slot == 11 then return "worn ring L20" end end   -- second ring slot empty
    local results = {
        ns:IsUpgrade("bag helm L12", 12), ns:IsUpgrade("bag helm L10", 10), ns:IsUpgrade("bag helm L8", 8),
        ns:IsUpgrade("bag ring L5", 5), ns:IsUpgrade("bag potion L50", 50),
    }
    env.C_Item.GetItemInfoInstant, env.C_Item.GetDetailedItemLevelInfo, env.GetInventoryItemLink = realInstant, realLevel, realWorn
    local want = { true, false, false, true, false }      -- the ring beats an EMPTY second ring slot; a potion is not gear
    for i = 1, #want do if results[i] ~= want[i] then error("case " .. i .. " gave " .. tostring(results[i])) end end
end)
try("Session survives a reload", function()
    ns.session.quests, ns.session.deaths = 7, 2
    fireEvent("PLAYER_LOGOUT")
    local saved = env.FantasyGlassUIDB.sessionSave
    if type(saved) ~= "table" or saved.quests ~= 7 then error("the session was not saved on logout") end
    ns.session.quests, ns.session.deaths, ns.session.restored = 0, 0, nil
    fireEvent("PLAYER_ENTERING_WORLD")
    if ns.session.quests ~= 7 or ns.session.deaths ~= 2 then error("the session was not restored") end
    if env.FantasyGlassUIDB.sessionSave ~= nil then error("the saved session should be used once") end
end)
try("Presets", function()
    if ns:PresetValue("EVERYTHING", "damageMeter") ~= true or ns:PresetValue("MINIMAL", "damageMeter") ~= false then error("preset values") end
    if ns:PresetValue("MINIMAL", "unitFrames") ~= true then error("minimal must keep unit frames") end
    for _, key in ipairs({ "toasts", "aggroWarn", "afkScreen", "levelShot" }) do
        if ns.defaults[key] ~= false then error(key .. " should start switched off") end
        if ns:PresetValue("STANDARD", key) ~= false then error("Standard should leave " .. key .. " off") end
        if ns:PresetValue("EVERYTHING", key) ~= true then error("Everything should switch " .. key .. " on") end
    end
    for _, key in ipairs({ "damageMeter", "unitFrames", "autoSell", "autoRepair" }) do
        if ns:PresetValue("STANDARD", key) ~= true then error("Standard keeps " .. key) end
    end
    -- the three presets must really be three different things
    local function signature(preset)
        local s = {}
        for _, group in ipairs(ns.featureGroups) do
            for _, opt in ipairs(group[2]) do s[#s + 1] = tostring(ns:PresetValue(preset, opt[1])) end
        end
        return table.concat(s, ",")
    end
    local e, st, m = signature("EVERYTHING"), signature("STANDARD"), signature("MINIMAL")
    if e == st or st == m or e == m then error("two presets are identical") end
    for _, preset in ipairs({ "EVERYTHING", "STANDARD", "MINIMAL" }) do
        for _, key in ipairs({ "autoQuest", "rounded", "barTexture" }) do
            if ns:PresetValue(preset, key) ~= nil then error(preset .. " must leave " .. key .. " alone") end
        end
    end
end)
try("Custom themes", function()
    local key = ns:SaveCustomTheme("Ember Night", { panel = { 0.10, 0.04, 0.03 }, rim = { 0.6, 0.3, 0.2 }, accent = { 1, 0.5, 0.2 } })
    if key ~= "U:Ember Night" or not ns.themes[key] then error("theme not registered") end
    local found = false
    for _, k in ipairs(ns.themeOrder) do if k == key then found = true end end
    if not found then error("theme not listed") end
    ns.db.theme, ns.db.accent = key, "CUSTOM"
    if not ns:Retheme() then error("a custom glass theme should apply without a reload") end
    local r, g, b = ns:AccentColor("CUSTOM")
    if math.abs(r - 1) > 0.001 or math.abs(g - 0.5) > 0.001 then error("custom accent not applied: " .. r .. "," .. g .. "," .. b) end
    if math.abs(ns.theme.bg[1] - 0.10) > 0.001 or math.abs(ns.theme.border[1] - 0.6) > 0.001 then error("panel / rim colors not applied") end
    -- nonsense in a saved theme must not break anything
    ns.db.customThemes.Broken = { panel = "red", rim = { 9, -4, "x" } }
    ns:RegisterCustomThemes()
    local t = ns.themes["U:Broken"]
    if not t or type(t.bg[1]) ~= "number" or t.border[1] > 1 then error("a damaged theme was not cleaned") end
    -- a pale panel flips the lettering dark
    ns:SaveCustomTheme("Paper", { panel = { 0.9, 0.9, 0.85 }, rim = { 0.3, 0.3, 0.3 }, accent = { 0.2, 0.4, 0.8 } })
    if ns.themes["U:Paper"].text[1] > 0.3 then error("pale panels need dark text") end
    ns:DeleteCustomTheme("Ember Night"); ns:DeleteCustomTheme("Broken"); ns:DeleteCustomTheme("Paper")
    if ns.themes[key] then error("deleted theme still registered") end
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
end)
try("Vendor and mailbox", function()
    local v = known.__shop
    if not rawget(v.item, "suiCard") then error("vendor item did not get its card") end
    if not rawget(v.ibtn, "suiItem") or not rawget(v.ibtn, "suiBorder") then error("vendor item button not restyled") end
    if not rawget(v.row, "suiPolish") or not rawget(v.mbtn, "suiItem") then error("mail row not restyled") end
    if not rawget(v.field, "suiControl") then error("send-mail field not flattened") end
end)
try("Quest dialog", function()
    local q = known.__quest
    local function lum(f) local c = rawget(f, "__color"); return c[1] * 0.30 + c[2] * 0.59 + c[3] * 0.11 end
    if lum(q.ink) < 0.6 then error("dark quest text was not relit") end
    local b = rawget(q.bright, "__color")
    if b[1] ~= 1 or b[2] ~= 0.82 or b[3] ~= 0 then error("lettering that was already light must be left alone") end
    local a = ns.theme.accent
    local h = rawget(q.heading, "__color")
    if math.abs(h[1] - a[1]) > 0.01 or math.abs(h[2] - a[2]) > 0.01 then error("the heading should take the accent color") end
    if rawget(q.parchment, "__alpha")[1] ~= 0 then error("the parchment was not removed") end
end)
try("Professions", function()
    local f = known.__prof
    if not rawget(f.tab, "suiTab") then error("profession tab not restyled") end
    if rawget(f.plain, "suiTab") then error("a frame that is not a tab must be left alone") end
    if not rawget(f.bar, "suiBar") then error("rank bar not flattened") end
    if not rawget(f.spell, "suiPolish") or not rawget(f.spell, "suiBorder") then error("ability button not restyled") end
end)
try("Collections", function()
    local c = known.__coll
    if not rawget(c.tab, "suiTab") then error("collections tab not restyled") end
    for name, f in pairs({ row = c.row, count = c.count, grid = c.grid }) do
        if not rawget(f, "suiPolish") then error("collections " .. name .. " not restyled") end
    end
    if rawget(c.hiddenRow, "suiPolish") then error("a hidden tab's rows should wait until it is opened") end
end)
try("Auction house", function()
    local a = known.__ah
    for name, f in pairs({ panel = a.panel, header = a.header, row = a.row, display = a.display, money = a.money }) do
        if not rawget(f, "suiPolish") then error("auction house " .. name .. " not restyled") end
    end
    if not rawget(a.header, "suiHeading") then error("column header did not get a heading") end
    if not rawget(a.ibtn, "suiItem") then error("the item on display was not restyled") end
    if not rawget(a.panel, "suiAuto") then error("a visible panel did not get the general pass") end
    if rawget(a.hidden, "suiAuto") or rawget(a.hiddenRow, "suiPolish") then error("hidden pages should wait until they are opened") end
end)
try("Lettering styles", function()
    if #ns.fontOrder ~= 36 then error("expected thirty-six lettering styles, found " .. #ns.fontOrder) end
    local names = {}
    for _, key in ipairs(ns.fontOrder) do
        local n = ns.fontStyles[key] and ns.fontStyles[key].name
        if names[n] then error("two lettering styles are both called " .. tostring(n)) end
        names[n] = true
    end
    local before = ns.db.fontStyle
    for _, key in ipairs(ns.fontOrder) do
        local style = ns.fontStyles[key]
        if not style or type(style.name) ~= "string" then error("style " .. key .. " is not defined") end
        ns.db.fontStyle = key
        ns:ApplyTheme()
        if type(ns.FONT) ~= "string" or type(ns.TITLEFONT) ~= "string" or type(ns.FONTFLAGS) ~= "string" then error(key .. " left a font unset") end
        if style.body and not ns.FONT:find(style.body, 1, true) then error(key .. " body face not applied: " .. ns.FONT) end
        if style.title and not ns.TITLEFONT:find(style.title, 1, true) then error(key .. " heading face not applied: " .. ns.TITLEFONT) end
        if not style.body and ns.FONT:find("FantasyGlassUI", 1, true) then error(key .. " should use the game's body face") end
    end
    ns.db.fontStyle = "NOSUCH"; ns:ApplyTheme()
    if not ns.FONT:find("Exo2", 1, true) then error("an unknown style should fall back to the default") end
    ns.db.fontStyle = before; ns:ApplyTheme()
end)
try("Lettering faces are loaded with the add-on", function()
    if not (ns.fontHolder and ns.fontHolder.strings) then error("the faces were not put to use while loading") end
    local files = {}
    for _, style in pairs(ns.fontStyles) do
        if style.body then files[style.body] = true end
        if style.title then files[style.title] = true end
    end
    local n = 0
    for _ in pairs(files) do n = n + 1 end
    if #ns.fontHolder.strings ~= n then error("expected " .. n .. " faces loaded, found " .. #ns.fontHolder.strings) end
    local count = ns.fontsPreloaded and #ns.fontHolder.strings
    ns:PreloadFonts()
    if #ns.fontHolder.strings ~= count then error("the faces should only be loaded once") end
end)
try("Bag window's top row fits inside it", function()
    for _, name in ipairs({ "FantasyGlassUIBags", "FantasyGlassUIBank" }) do
        local w = _G[name]
        if w and w.suiRow then
            local row = w.suiRow.search:GetWidth() + w.suiRow.used
            if row > w:GetWidth() - 24 then error(name .. ": the search box and buttons take " .. row .. " of " .. (w:GetWidth() - 24)) end
        end
    end
end)
try("Fantasy custom theme", function()
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
    local key = ns:SaveCustomTheme("Old Oak", { panel = { 0.08, 0.06, 0.04 }, rim = { 0.45, 0.33, 0.18 }, accent = { 1, 0.8, 0.4 }, style = "FANTASY" })
    local t = ns.themes[key]
    if t.style ~= "FANTASY" then error("the theme should be a fantasy one") end
    if not (t.grain[4] > 0) then error("a fantasy theme needs a visible grain") end
    if t.rim[1] >= t.bg[1] then error("a fantasy theme's outer rim should be darker than its panel") end
    ns.db.theme, ns.db.accent = key, "CUSTOM"
    if ns:Retheme() then error("going from glass to a fantasy theme should ask for a reload") end
    if ns.style ~= "FANTASY" then error("style not switched") end
    -- the same colors as glass stay glass, and nonsense in the style field means glass
    local g = ns.themes[ns:SaveCustomTheme("Plain", { panel = { 0.08, 0.06, 0.04 }, rim = { 0.45, 0.33, 0.18 }, accent = { 1, 0.8, 0.4 } })]
    local odd = ns.themes[ns:SaveCustomTheme("Odd", { style = 42 })]
    if g.style ~= "GLASS" or odd.style ~= "GLASS" or g.grain[4] ~= 0 then error("default family should be glass") end
    ns:DeleteCustomTheme("Old Oak"); ns:DeleteCustomTheme("Plain"); ns:DeleteCustomTheme("Odd")
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
end)
try("Talent tree", function()
    local n = known.__talents
    for name, want in pairs({ canTake = "Selectable", full = "Maxed", locked = "Locked" }) do
        local b = n[name]
        if not rawget(b, "suiTalent") or rawget(b, "suiState") ~= want then error(name .. " talent: state not shown (got " .. tostring(rawget(b, "suiState")) .. ")") end
        if rawget(rawget(b, "StateBorder"), "__alpha")[1] ~= 0 then error(name .. " talent: the game's border should be replaced") end
    end
    if rawget(n.unknown, "suiTalent") then error("a talent whose state can't be read must be left alone") end
    if rawget(rawget(n.unknown, "StateBorder"), "__alpha")[1] ~= 1 then error("its border must stay visible") end
    if not rawget(n.heading, "suiPolish") then error("tree heading not tinted") end
    if not ns.talentState or not ns.talentState:find("3 restyled, 1 left", 1, true) then error("report: " .. tostring(ns.talentState)) end
end)
try("Theme palette", function()
    local function lum(c) return c[1] * 0.30 + c[2] * 0.59 + c[3] * 0.11 end
    if #ns.themeOrder ~= 116 then error("expected 116 built-in themes, found " .. #ns.themeOrder) end
    local seen = {}
    for _, key in ipairs(ns.themeOrder) do
        if seen[key] then error("theme listed twice: " .. key) end
        seen[key] = true
        local t = ns.themes[key]
        if not t then error("theme in the list but not defined: " .. key) end
        if ns.accents[t.accent] == nil then error(key .. " names an accent that doesn't exist: " .. tostring(t.accent)) end
        if key ~= "CLASS" and key ~= "GCLASS" and key ~= "CCLASS" then     -- those three are worked out from your class at login
            for _, field in ipairs({ "bg", "border", "rim", "light", "plate", "text", "dim", "faint", "btn" }) do
                local c = t[field]
                if type(c) ~= "table" then error(key .. " lacks " .. field) end
                for i = 1, 3 do
                    if type(c[i]) ~= "number" or c[i] < 0 or c[i] > 1 then error(key .. "." .. field .. " has a bad value") end
                end
            end
            if type(t.grain) ~= "table" or type(t.grain[4]) ~= "number" then error(key .. " lacks grain") end
            if lum(t.text) - lum(t.bg) < 0.6 then error(key .. ": text does not stand out enough from the panel") end
            if lum(t.faint) - lum(t.bg) < 0.3 then error(key .. ": faint text too close to the panel") end
            if lum(t.plate) <= lum(t.bg) then error(key .. ": buttons should be lighter than the panel") end
            if lum(t.border) <= lum(t.plate) then error(key .. ": the rim should stand out from buttons") end
            if (t.style == "GLASS" or t.style == "CELESTIAL") ~= (t.grain[4] == 0) then error(key .. ": glass and celestial themes have no grain, fantasy themes have one") end
        end
        ns.db.theme = key; ns:BuildPalette()
        if ns.style ~= (t.style or "FANTASY") then error(key .. " did not set its family") end
    end
    if #ns.accentOrder ~= 31 then error("expected 31 accents") end
    local seenAccent = {}
    for _, key in ipairs(ns.accentOrder) do
        if seenAccent[key] then error("accent listed twice: " .. key) end
        seenAccent[key] = true
        if key ~= "CLASS" and not ns.accents[key] then error("accent in the list but not defined: " .. key) end
        if type(ns:AccentName(key)) ~= "string" then error("accent with no name: " .. key) end
    end
    for _, key in ipairs(ns.accentOrder) do
        local r, g, b = ns:AccentColor(key)
        if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then error("accent " .. key .. " has no color") end
    end
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
end)
try("Black and red", function()
    for _, key in ipairs({ "NOIR", "ONYX" }) do
        local t = ns.themes[key]
        local bg, rim = t.bg, t.border
        if math.max(bg[1], bg[2], bg[3]) > 0.05 then error(key .. ": the panel should be black") end
        if not (rim[1] > 0.5 and rim[2] < 0.25 and rim[3] < 0.25) then error(key .. ": the rim should be red") end
        if t.accent ~= "SCARLET" then error(key .. " should come with the red accent") end
    end
    local r, g, b = ns:AccentColor("SCARLET")
    if not (r > 0.9 and g < 0.3 and b < 0.3) then error("Scarlet should be a true red") end
    if ns.themes.NOIR.style ~= "GLASS" or ns.themes.ONYX.style ~= nil then error("one of each family") end
end)
try("Setup offers every theme", function()
    -- every built-in theme must be reachable through one of the setup's two families
    local glass, fantasy, celestial = 0, 0, 0
    for _, key in ipairs(ns.themeOrder) do
        local th = ns.themes[key]
        if not th.custom then if th.style == "GLASS" then glass = glass + 1 elseif th.style == "CELESTIAL" then celestial = celestial + 1 else fantasy = fantasy + 1 end end
    end
    if glass ~= 38 or fantasy ~= 39 or celestial ~= 39 then error("expected 38 + 39 + 39 themes, found " .. glass .. " + " .. fantasy .. " + " .. celestial) end
    -- (a family no longer has to fit four rows: the setup's grid scrolls, which is tested further down)
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
    ns:ShowSetup()
    ns:SaveCustomTheme("Mine", { panel = { 0.1, 0.1, 0.1 }, rim = { 0.5, 0.5, 0.5 }, accent = { 1, 1, 1 } })
    ns:ShowSetup()                                    -- reopening with a theme of your own must not error
    ns:DeleteCustomTheme("Mine")
    ns:ShowSetup()
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
end)
try("Setup tour", function()
    if ns:SetupStepCount() ~= 5 then error("expected five steps (12.1)") end
    for stepNumber = 1, 4 do ns:ShowSetup(stepNumber) end            -- every step opens without error
    -- (12.0) Just restyle the game's own: the look without replacing the game's frames and bags
    ns:ApplyPreset("RESTYLE")
    if ns:CurrentPreset() ~= "RESTYLE" then error("after applying Restyle it should be recognised") end
    if ns.db.unitFrames or ns.db.bagWindow or not ns.db.windows or not ns.db.tooltip then error("Restyle: wrong switches") end
    -- presets, as the welcome step uses them
    ns:ApplyPreset("MINIMAL")
    if ns:CurrentPreset() ~= "MINIMAL" then error("after applying Minimal it should be recognised") end
    if ns.db.damageMeter or not ns.db.unitFrames then error("Minimal: wrong switches") end
    local auto = ns.db.autoQuest
    ns:ApplyPreset("EVERYTHING")
    if ns:CurrentPreset() ~= "EVERYTHING" or not ns.db.damageMeter then error("Everything: wrong switches") end
    if ns.db.autoQuest ~= auto then error("presets must never touch auto quest") end
    ns.db.lootRoll = false
    if ns:CurrentPreset() ~= nil then error("a hand-made change means no preset matches") end
    if ns:ApplyPreset("STANDARD") == 0 or ns:CurrentPreset() ~= "STANDARD" then error("Standard should be applied and recognised") end
    if ns.db.afkScreen or ns.db.toasts or not ns.db.autoSell or not ns.db.lootRoll then error("Standard: wrong switches") end
    ns:ApplyPreset("EVERYTHING")                                      -- leave every feature on for the tests that follow
    local on, total = ns:CountFeatures()
    if not (total > 40 and on > 20 and on <= total) then error("feature count looks wrong: " .. on .. " of " .. total) end
    ns:ShowSetup(4)                                                   -- the summary reads all of that back
    -- (12.0) how you play: a choice switches its features on, taking it back puts them as they were
    ns:ApplyPreset("MINIMAL")
    local wasRole = ns.db.role
    ns.db.role = "NONE"
    local before = ns.db.lootBook and true or false
    ns:SetPlayStyle("GROUPS", true)
    if not ns:PlayStyleOn("GROUPS") or not ns.db.lootBook or not ns.db.bossGuide then error("Dungeons and raids should switch on its features") end
    ns:SetPlayStyle("TANK", true); ns.db.role = "TANK"
    ns:SetPlayStyle("GROUPS", false)
    if (ns.db.lootBook and true or false) ~= before then error("taking a choice back should put its switches as they were") end
    if not ns.db.threatMeter then error("a switch another choice still wants (Tank: threat meter) must stay on") end
    ns.db.role = nil; ns:SetPlayStyle("TANK", false)
    for style in pairs(ns.playStyles) do
        for _, key in ipairs(ns.playStyles[style]) do
            if key == "autoQuest" then error("a play style must never switch on auto quest") end
        end
        if #ns:PlayStyleKeys(style) == 0 then error("a play style with no feature: " .. style) end
    end
    ns.db.role = wasRole
    ns:ShowSetup(2)
    ns:ApplyPreset("EVERYTHING")                                      -- leave every feature on for the tests that follow
end)
try("Panel settings", function()
    local key = ns.movables[1].key
    ns:OpenPanelMenu(key)                                  -- builds the menu and fills it in
    ns.db.pos[key] = { "CENTER", "CENTER", 10, 20 }
    ns:ResetPanel(key)
    if ns.db.pos[key] ~= nil or ns.db.scale[key] ~= nil then error("reset should forget the saved position and scale") end
    ns:OpenPanelMenu("ufParty2")
end)
try("Layout by group size", function()
    local kind = "solo"
    env.IsInRaid = function() return kind == "raid" end
    env.IsInGroup = function() return kind ~= "solo" end
    ns.db.specLayouts, ns.db.groupLayouts, ns.db.layouts = false, true, {}
    if ns:LayoutContext() ~= "solo" then error("context should be solo, got " .. tostring(ns:LayoutContext())) end
    ns.db.layoutCtx = "solo"
    ns.db.pos = { ufPlayer = { "CENTER", "CENTER", -100, -100 } }
    kind = "raid"; fireEvent("GROUP_ROSTER_UPDATE")
    if not ns.db.layouts.solo or ns.db.layouts.solo.pos.ufPlayer[3] ~= -100 then error("leaving solo did not save its layout") end
    ns.db.pos = { ufPlayer = { "CENTER", "CENTER", 400, 0 } }
    kind = "solo"; fireEvent("GROUP_ROSTER_UPDATE")
    if ns.db.pos.ufPlayer[3] ~= -100 then error("coming back to solo did not restore its layout") end
    if ns.db.layouts.raid.pos.ufPlayer[3] ~= 400 then error("the raid layout was not saved") end
    -- both options together: the context names both
    env.C_SpecializationInfo.GetActiveSpecGroup = function() return 2 end
    ns.db.specLayouts = true; kind = "party"
    if ns:LayoutContext() ~= "2/party" then error("combined context: " .. tostring(ns:LayoutContext())) end
    ns.db.specLayouts, ns.db.groupLayouts, ns.db.layouts, ns.db.pos, ns.db.layoutCtx = false, false, {}, {}, nil
    if ns:LayoutContext() ~= nil then error("no context when both options are off") end
    env.IsInRaid = function() return false end; env.IsInGroup = function() return true end
end)
try("Theme sharing", function()
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
    local key = ns:SaveCustomTheme("Ember Night", { panel = { 0.10, 0.04, 0.03 }, rim = { 0.6, 0.3, 0.2 }, accent = { 1, 0.5, 0.2 }, style = "FANTASY" })
    ns.db.theme, ns.db.accent = key, "CUSTOM"; ns:BuildPalette()
    local text = ns:ExportTheme()
    if text:sub(1, 6) ~= "SUIT1!" then error("bad theme header") end
    local ok, name = ns:ImportTheme(text)
    if not ok or name ~= "Ember Night 2" then error("an import must not overwrite a theme of the same name: " .. tostring(name)) end
    local copy = ns.db.customThemes[name]
    if math.abs(copy.rim[1] - 0.6) > 0.001 or copy.style ~= "FANTASY" or math.abs(copy.accent[2] - 0.5) > 0.001 then error("the theme did not survive the trip") end
    for _, bad in ipairs({ "", "hello", "SUIT1!{", "SUIT1!N5;", ns:ExportLayout(), ns:ExportProfile() }) do
        if ns:ImportTheme(bad) then error("a bad theme string was accepted: " .. bad:sub(1, 10)) end
    end
    ns.db.theme, ns.db.accent = "MIDNIGHT", "VIOLET"; ns:BuildPalette()
    local builtin = ns:ExportTheme()                       -- a built-in theme can be shared too, as what is on screen
    local ok2, name2 = ns:ImportTheme(builtin)
    if not ok2 or name2 ~= "Midnight" then error("sharing a built-in theme: " .. tostring(name2)) end
    for _, n in ipairs({ "Ember Night", "Ember Night 2", "Midnight" }) do ns:DeleteCustomTheme(n) end
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
end)
try("Add-on conflicts", function()
    local real = env.C_AddOns.IsAddOnLoaded
    env.C_AddOns.IsAddOnLoaded = function(name) return name == "Bartender4" or name == "Plater" end
    ns.db.stepAside = true
    if ns:ConflictFor("actionBars") ~= "Bartender4" or ns:ConflictFor("nameplates") ~= "Plater" then error("conflicts not detected") end
    if ns:ConflictFor("unitFrames") ~= nil then error("a feature with no rival add-on must run") end
    ns.db.stepAside = false
    if ns:ConflictFor("actionBars") ~= nil then error("stepping aside can be switched off") end
    ns.db.stepAside = true
    env.C_AddOns.IsAddOnLoaded = real
end)
try("Accessibility", function()
    ns.db.colorblind = false
    local gr, gg = ns:Signal("good"); local br, bg2 = ns:Signal("bad")
    if not (gg > gr and br > bg2) then error("default signals should be green and red") end
    ns.db.colorblind, ns.db.colorVision = true, "redgreen"
    local r, g, b = ns:Signal("good"); local r2, g2, b2 = ns:Signal("bad")
    if not (b > r and b > g) then error("color-blind good should be blue") end
    if not (r2 > 0.9 and g2 > 0.4 and b2 < 0.3) then error("color-blind bad should be orange") end
    if ns:SignalHex("good"):sub(1, 4) ~= "|cff" or #ns:SignalHex("good") ~= 10 then error("bad color code") end
    ns.db.colorblind = false
    ns.db.reduceMotion = true;  if ns:Motion() then error("motion should be off") end
    ns.db.reduceMotion = false; if not ns:Motion() then error("motion should be on") end
    local t = ns.themes.CONTRAST
    if t.bg[1] ~= 0 or t.border[1] ~= 1 or t.text[1] ~= 1 then error("high contrast should be black with white") end
end)
try("Clean screen", function()
    local alpha
    local realSet = env.UIParent.SetAlpha
    rawset(env.UIParent, "SetAlpha", function(_, a) alpha = a end)
    if ns:CleanScreen(5) ~= true or alpha ~= 0 then error("the interface should fade out") end
    if ns:CleanScreen(5) ~= false or alpha ~= 1 then error("pressing it again should bring the interface back") end
    ns:CleanScreen(5); fireEvent("PLAYER_REGEN_DISABLED")
    if alpha ~= 1 then error("a fight starting must bring the interface back") end
    env.FantasyGlassUI_Binding("CLEAN"); env.FantasyGlassUI_Binding("CLEAN")
    if alpha ~= 1 then error("the key binding should toggle it") end
    rawset(env.UIParent, "SetAlpha", realSet)
end)
try("Problem report", function()
    local realShow, gotLink, gotAlt = ns.ShowTextWindow, nil, nil
    ns.ShowTextWindow = function(self, title, text, toBottom, link, alt) gotLink, gotAlt = link, alt; return realShow(self, title, text, toBottom, link, alt) end
    local out = ns:ProblemReport()
    ns.ShowTextWindow = realShow
    local text = table.concat(out, "\n")
    for _, want in ipairs({ "WHAT WENT WRONG", "self-check", "SETTINGS CHANGED FROM THE DEFAULTS", "OTHER ADD-ONS RUNNING" }) do
        if not text:find(want, 1, true) then error("the report lacks: " .. want) end
    end
    -- (11.18) two places to send it: the form, and the Discord server's #bug-reports
    if gotLink ~= ns:ReportLink() then error("the first address should still be the form") end
    if type(gotAlt) ~= "table" or gotAlt.link ~= ns.discordInvite then error("the second address should be the Discord invite") end
end)
try("Notifications", function()
    if type(ns.Toast) ~= "function" then error("the notification module did not start") end
    local link, count = ns.ToastLootMatch("You receive loot: |Hitem:55|h[Fine Sword]|hx3.")
    if not link or not link:find("Fine Sword", 1, true) or count ~= 3 then error("a stack of loot was not recognised: " .. tostring(link) .. " / " .. tostring(count)) end
    local one, n = ns.ToastLootMatch("You receive loot: |Hitem:56|h[Odd Ring]|h.")
    if not one or n ~= 1 then error("a single item was not recognised") end
    if ns.ToastLootMatch("Bob receives loot: |Hitem:56|h[Odd Ring]|h.") then error("someone else's loot must not make a toast") end
    for i = 1, 20 do ns:Toast(nil, "Title " .. i, "text", "!") end      -- a flood must not error or pile up without limit
    fireEvent("PLAYER_LEVEL_UP", 11); fireEvent("CHAT_MSG_WHISPER", "hello there", "Bob-Realm")
end)
try("Info bar plugins", function()
    if not ns.brokerState or not ns.brokerState:find("2 shown", 1, true) then
        error("expected the two published lines (not the launcher, not the empty one), got: " .. tostring(ns.brokerState))
    end
end)
try("Class trainer", function()
    local tr = known.__trainer
    if not rawget(tr.row, "suiPolish") or not rawget(tr.step, "suiPolish") then error("trainer rows not restyled") end
    if rawget(tr.notRow, "suiPolish") then error("a frame that is not a row must be left alone") end
    if rawget(known.ClassTrainerFrameMoneyBg, "__alpha")[1] ~= 0 then error("the money plate should be hidden") end
end)
try("Class extras", function()
    local module
    for _, m in ipairs(ns.modules) do if m.key == "classBar" then module = m.fn end end
    if not module then error("the class extras module is not registered") end
    local realClass, realMax, realType = env.UnitClass, env.UnitPowerMax, env.UnitPowerType
    local function as(class, setup, want)
        env.UnitClass = function() return class, class end
        env.UnitPowerMax = function() return 0 end
        env.UnitPowerType = function() return 0, "MANA" end
        env.C_PetInfo, env.GetRuneCooldown = nil, nil
        setup()
        module()
        local state = ns.classBarState()
        if not state:find(want, 1, true) then error(class .. ": expected '" .. want .. "', got '" .. state .. "'") end
    end
    as("PALADIN", function() env.UnitPowerMax = function(_, kind) return kind == 9 and 5 or 0 end end, "second resource shown")
    as("PALADIN", function() end, "nothing for this class")            -- a game without holy power: no bar
    as("DEATHKNIGHT", function() env.GetRuneCooldown = function(i) return 0, 10, i % 2 == 0 end end, "runes")
    as("DRUID", function()
        env.UnitPowerType = function() return 1, "RAGE" end
        env.UnitPowerMax = function(_, kind) return (kind == 0 or kind == nil) and 800 or 100 end
    end, "mana bar shown")
    as("DRUID", function() env.UnitPowerMax = function() return 800 end end, "nothing for this class")   -- in caster form: mana is the main bar
    as("HUNTER", function() env.C_PetInfo = { GetPetHappiness = function() return 2, 100, 0 end } end, "pet happiness available")
    as("SHAMAN", function() end, "nothing for this class")
    env.UnitClass, env.UnitPowerMax, env.UnitPowerType = realClass, realMax, realType
end)
try("Movable action bars", function()
    local handles = ns.barHandles
    if type(handles) ~= "table" or #handles == 0 then error("no action bar got a handle") end
    local info
    for _, h in ipairs(handles) do if not h.engine then info = h; break end end      -- (a game bar: the add-on's own bars are not adopted)
    local entry
    for _, m in ipairs(ns.movables) do if m.key == info.key then entry = m end end
    if not entry or not entry.onMoved or not entry.onReset or not entry.noScale then error("the handle is not wired up") end
    ns:ResetPanel(info.key)                                -- (the harness "drags" every handle once while exercising scripts)
    if info.attached or ns.db.pos[info.key] ~= nil then error("after a reset the bar belongs to the game again") end
    ns.db.pos[info.key] = nil; entry.onMoved()
    if info.attached then error("a bar with no saved place must be left to the game") end
    -- dragging the handle pins the bar to it
    ns.db.pos[info.key] = { "CENTER", "CENTER", 0, -300 }
    entry.onMoved()
    if not info.attached then error("moving the handle should pin the bar") end
    -- in combat the bar can't be re-placed: it waits
    info.attached = nil
    env.InCombatLockdown = function() return true end
    entry.onMoved()
    if info.attached or not info.pending then error("in combat the move must wait") end
    env.InCombatLockdown = function() return false end
    fireEvent("PLAYER_REGEN_ENABLED"); runTimers()
    if not info.attached then error("the move should complete when combat ends") end
    -- Reset hands the bar back
    ns:ResetPanel(info.key)
    if info.attached or ns.db.pos[info.key] ~= nil then error("Reset should hand the bar back to the game") end
    ns:OpenPanelMenu(info.key)                             -- its menu opens (without a scale slider)
end)
try("AFK idle time", function()
    local clock, afkFlag, sentAFK = 1000, false, 0
    local realTime, realAFK, realSend = env.GetTime, env.UnitIsAFK, env.C_ChatInfo.SendChatMessage
    env.GetTime = function() return clock end
    env.UnitIsAFK = function() return afkFlag end
    env.C_ChatInfo.SendChatMessage = function(_, kind) if kind == "AFK" then sentAFK = sentAFK + 1 end end
    env.InCombatLockdown = function() return false end
    local alpha = 1
    local realSet = rawget(env.UIParent, "SetAlpha")
    rawset(env.UIParent, "SetAlpha", function(_, a) alpha = a end)
    local function tick() for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 1.01) end end end
    ns.db.afkScreen, ns.db.afkDelay, ns.db.afkFlag = true, 2, false
    ns.AFKActive(); tick()
    if alpha ~= 1 then error("the screen must not appear straight away") end
    clock = clock + 100; tick()
    if alpha ~= 1 then error("100 seconds idle with a 2 minute setting: too early") end
    clock = clock + 30; tick()
    if alpha ~= 0 then error("after 2 minutes idle the screen should appear") end
    if sentAFK ~= 0 then error("the character must not be marked away unless asked") end
    fireEvent("PLAYER_STARTED_MOVING"); tick()
    if alpha ~= 1 then error("moving should bring the interface back") end
    -- with the option: also marked away, once
    ns.db.afkFlag = true
    clock = clock + 200; tick(); tick()
    if alpha ~= 0 or sentAFK ~= 1 then error("with the option the character should be marked away once (sent " .. sentAFK .. ")") end
    fireEvent("PLAYER_STARTED_MOVING"); tick()
    -- 0 = the game's own flag, as before
    ns.db.afkDelay, ns.db.afkFlag = 0, false
    clock = clock + 5000; tick()
    if alpha ~= 1 then error("with no idle time set, only the game's away flag counts") end
    afkFlag = true; tick()
    if alpha ~= 0 then error("the game's away flag should show the screen") end
    afkFlag = false; tick()
    if alpha ~= 1 then error("and clearing it should bring the interface back") end
    env.GetTime, env.UnitIsAFK, env.C_ChatInfo.SendChatMessage = realTime, realAFK, realSend
    rawset(env.UIParent, "SetAlpha", realSet)
end)
try("Demo", function()
    ns:TogglePreview(true)
    env.InCombatLockdown = function() return false end
    ns:ToggleDemo()
    if not ns.demo or not ns.previewing then error("the demo should start the preview") end
    for _ = 1, 7 do if not ns:DemoTick() then error("the demo should keep producing samples") end end
    fireEvent("PLAYER_REGEN_DISABLED")
    if ns.demo or ns.previewing then error("a fight starting should end the demo and the preview") end
    ns:ToggleDemo(); ns:ToggleDemo()
    if ns.demo or ns.previewing then error("the demo should end when asked") end
    if ns:DemoTick() then error("no samples once the demo is off") end
end)
try("Fading action bars", function()
    local info = ns.barHandles[1]
    if type(ns.db.bars) == "table" then ns.db.bars[info.key] = nil end      -- (start from how the bar came)
    if ns.db.barFade then ns.db.barFade[info.key] = nil end
    rawset(info.holder, "IsMouseOver", function() return false end)
    rawset(info.bar, "IsMouseOver", function() return false end)
    local realCursor = env.GetCursorInfo
    env.GetCursorInfo = function() return nil end
    env.InCombatLockdown = function() return false end
    ns.moving, ns.keybinding = false, nil
    ns:TogglePreview(true)
    info.alpha = 1
    for _ = 1, 20 do ns:BarFadeTick(0.12) end
    if info.alpha ~= 1 then error("a bar that is not set to fade must stay visible") end
    ns:SetBarFade(info.key, true)
    for _ = 1, 20 do ns:BarFadeTick(0.12) end
    if info.alpha ~= 0 then error("out of combat and not hovered, a fading bar should be invisible (alpha " .. tostring(info.alpha) .. ")") end
    rawset(info.holder, "IsMouseOver", function() return true end)
    for _ = 1, 20 do ns:BarFadeTick(0.12) end
    if info.alpha ~= 1 then error("pointing at the bar should bring it back") end
    rawset(info.holder, "IsMouseOver", function() return false end)
    for _ = 1, 20 do ns:BarFadeTick(0.12) end
    env.InCombatLockdown = function() return true end
    for _ = 1, 20 do ns:BarFadeTick(0.12) end
    if info.alpha ~= 1 then error("combat should bring the bar back") end
    env.InCombatLockdown = function() return false end
    env.GetCursorInfo = function() return "spell" end
    for _ = 1, 20 do ns:BarFadeTick(0.12) end
    if info.alpha ~= 1 then error("dragging something should keep the bar visible") end
    ns:SetBarFade(info.key, false)
    if ns.db.barFade[info.key] ~= nil then error("switching fade off should forget the bar") end
    env.GetCursorInfo = realCursor
    ns:OpenPanelMenu(info.key)
end)
try("Combat focus", function()
    ns.db.combatFocus, ns.moving = true, false
    env.InCombatLockdown = function() return true end
    local level
    for _ = 1, 30 do level = ns:CombatFocusTick(0.1) or level end
    if not level or math.abs(level - 0.12) > 0.001 then error("in a fight the panels should dim, got " .. tostring(level)) end
    env.InCombatLockdown = function() return false end
    for _ = 1, 30 do level = ns:CombatFocusTick(0.1) or level end
    if level ~= 1 then error("after the fight they should return") end
    ns.db.combatFocus = false
    env.InCombatLockdown = function() return true end
    if ns:CombatFocusTick(0.1) ~= nil then error("switched off, nothing should change in a fight") end
    env.InCombatLockdown = function() return false end
end)
try("Warning notifications", function()
    local shown = {}
    local realToast = ns.Toast
    ns.Toast = function(_, _, title) shown[#shown + 1] = title end
    local free, worn = 10, 100
    local realContainer = env.C_Container
    env.C_Container = { GetContainerNumSlots = function() return 16 end, GetContainerNumFreeSlots = function(bag) return bag == 0 and free or 0 end }
    local realLow = ns.LowestDurability
    ns.LowestDurability = function() return worn end
    ns.ToastCheckSupplies()
    if #shown ~= 0 then error("nothing to warn about yet") end
    free = 2; ns.ToastCheckSupplies(); ns.ToastCheckSupplies()
    if #shown ~= 1 or not shown[1]:find("Bags", 1, true) then error("full bags should be said once, got " .. #shown) end
    free = 3; ns.ToastCheckSupplies()
    if #shown ~= 1 then error("still nearly full: not said again") end
    free = 8; ns.ToastCheckSupplies(); free = 1; ns.ToastCheckSupplies()
    if #shown ~= 2 then error("after clearing out and filling up again it should be said again") end
    worn = 15; ns.ToastCheckSupplies(); ns.ToastCheckSupplies()
    if #shown ~= 3 or not shown[3]:find("repair", 1, true) then error("worn gear should be said once") end
    worn = 100; ns.ToastCheckSupplies(); worn = 10; ns.ToastCheckSupplies()
    if #shown ~= 4 then error("after a repair, worn gear should be said again") end
    ns.Toast, ns.LowestDurability = realToast, realLow
    env.C_Container = realContainer
end)
try("Rename", function()
    -- both the new commands and the old one reach the add-on
    local cmds = { env.SLASH_FANTASYGLASSUI1, env.SLASH_FANTASYGLASSUI2, env.SLASH_FANTASYGLASSUI3 }
    if cmds[1] ~= "/fgui" or cmds[3] ~= "/sui" then error("slash commands: " .. tostring(cmds[1]) .. ", " .. tostring(cmds[3])) end
    if type(env.SlashCmdList.FANTASYGLASSUI) ~= "function" then error("the slash handler is not registered under the new name") end
    if type(env.FantasyGlassUI_Binding) ~= "function" then error("key bindings are not under the new name") end
    -- every key binding has a name in the key bindings window, and does something without an error
    for _, which in ipairs({ "OPTIONS", "MOVE", "KEYBIND", "CLEAN", "METER", "ALTS", "MOUNT", "PET", "SORT", "KEYS", "QUIET", "NOTEPAD", "WHISPERS", "TODO", "WHATSTHIS", "TOOLS", "EQUIPBEST", "DEATH", "BOSSNOTE", "HELP", "BRIEFING", "RECAP", "SKILLUPS", "GEARSET1", "GEARSET5" }) do
        if which ~= "KEYS" and type(env["BINDING_NAME_FANTASYGLASSUI_" .. which]) ~= "string" then error("the " .. which .. " key binding has no name") end
        local ok, err = pcall(env.FantasyGlassUI_Binding, which, "down")
        if not ok then error("the " .. which .. " key binding failed: " .. tostring(err)) end
    end
    if ns.HideLists then ns:HideLists() end
    if not ns.MEDIA:find("FantasyGlassUI", 1, true) then error("media is not loaded from the new folder: " .. ns.MEDIA) end
    -- (12.0) settings from before profiles start afresh, and say so; current settings are kept as they are
    local keepRoot, keepDb = env.FantasyGlassUIDB, ns.db
    local flat = { barScale = 120, role = "HEALER" }
    ns.db, env.FantasyGlassUIDB, ns.settingsReset, ns.freshInstall = nil, flat, nil, nil
    ns:InitDB()
    if not ns.settingsReset or not ns.freshInstall then error("settings from before profiles should start afresh, with the setup") end
    if env.FantasyGlassUIDB.barScale ~= nil or ns.db.barScale == 120 then error("the old flat settings should be gone") end
    local current = { profiles = { Default = { barScale = 90 } }, chars = {} }
    ns.db, env.FantasyGlassUIDB, ns.settingsReset = nil, current, nil
    ns:InitDB()
    if env.FantasyGlassUIDB ~= current or ns.settingsReset or ns.db.barScale ~= 90 then error("current settings must be kept as they are") end
    ns.freshInstall = nil
    ns.db, env.FantasyGlassUIDB = nil, keepRoot
    ns:InitDB()
    if ns.db ~= keepDb and ns.db.theme == nil then error("could not restore the test profile") end
end)
try("Accessibility (12.0)", function()
    if not ns.themes.FCONTRAST or ns:ThemeName("FCONTRAST") == "" then error("a high-contrast fantasy theme should exist") end
    local was = ns.db.colorblind
    local slot = env.CreateFrame("Button", nil, env.UIParent)
    ns.db.colorblind = false
    ns:QualityPips(slot, 4)
    if rawget(slot, "suiPips") then error("quality dots should not be made without the color-blind option") end
    ns.db.colorblind = true
    ns:QualityPips(slot, 4)
    local pips = rawget(slot, "suiPips")
    if type(pips) ~= "table" or #pips ~= 4 then error("an epic item should get its quality dots") end
    ns:QualityPips(slot, nil)                                -- (an emptied slot)
    ns.db.colorblind = was
    if ns.lookPage and not (ns.lookPage.access and ns.lookPage.access.FCONTRAST and ns.lookPage.access.size140) then error("the Look page should have its contrast and text size buttons") end
end)
try("Simple settings (12.0)", function()
    ns:ToggleConfig("home")
    local O = ns.optUI
    if not O.SetSimple then error("the settings window should have simple settings") end
    O.SetSimple(true)
    if not ns:SettingsSimple() or ns.root.settingsMode ~= "simple" then error("simple settings should be kept for the account") end
    if O.CategoryShown(ns:SettingsCategory("tools")) then error("the Tools category should be tucked away in simple settings") end
    local fp = ns.featuresPage
    O.Open("items:Bags and bank")
    for _, key in ipairs(fp.shownKeys) do
        if ns.featureLabels[key] and not ns.simpleFeatures[key] then error("a switch outside the everyday ones shows in simple settings: " .. key) end
    end
    if O.SectionShown(ns:SettingsSection("chat:Player tooltips")) then error("a section with no everyday switch is tucked away") end
    -- the search of all options finds every switch, and says where it is
    local hit
    for _, h in ipairs(ns.configFrame.SearchOptions("realm in the name")) do if rawget(h.frame, "key") == "tipRealm" then hit = h end end
    if not hit then error("a search should find every switch, simple settings or not") end
    if hit.section.id ~= "chat:Player tooltips" or not O.Breadcrumb(hit.section):find(ns:Tr("in All options"), 1, true) then error("a result says where it lives: " .. O.Breadcrumb(hit.section)) end
    ns.configFrame.GoToOption(hit)
    if ns:SettingsSimple() then error("going to a switch outside the everyday ones should show all options") end
    if not O.CategoryShown(ns:SettingsCategory("tools")) then error("the Tools category should be back with all options") end
    if O.current ~= hit.section then error("going to a result opens its section") end
    for key in pairs(ns.simpleFeatures) do
        if not ns:SectionOfRow(key) then error("an everyday switch is in no section: " .. key) end
    end
    ns:ToggleConfig()
end)
try("Look tab sections", function()
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
    ns:ToggleConfig("look")
    local page = ns.lookPage
    if not page or not page.themePicker then error("the Look tab did not build its theme picker") end
    local pk = page.themePicker
    local function listOf(fam) pk.family = fam; pk.Draw(); local out = {}; for i, k in ipairs(pk.list) do out[i] = k end return out end
    local glass, fantasy, skyG = listOf("GLASS"), listOf("FANTASY"), listOf("CELESTIAL")
    if #glass ~= 38 or #fantasy ~= 39 or #skyG ~= 39 then error("expected 38 glass, 39 fantasy and 39 celestial tiles, got " .. #glass .. ", " .. #fantasy .. " and " .. #skyG) end
    for _, k in ipairs(glass) do if ns.themes[k].style ~= "GLASS" then error("a fantasy theme is under Glass: " .. k) end end
    for _, k in ipairs(fantasy) do if ns.themes[k].style == "GLASS" or ns.themes[k].style == "CELESTIAL" or ns.themes[k].custom then error("wrong theme under Fantasy: " .. k) end end
    for _, k in ipairs(skyG) do if ns.themes[k].style ~= "CELESTIAL" then error("wrong theme under Celestial: " .. k) end end
    for name in pairs(ns.db.customThemes) do ns:DeleteCustomTheme(name) end       -- (earlier tests may have left some)
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme(); page.Refresh()
    listOf("MINE")
    if pk.family == "MINE" then error("no themes of your own: that family should not be offered") end
    -- one of your own, of either kind, goes in the fourth family
    local key = ns:SaveCustomTheme("Mine Own", { panel = { 0.1, 0.1, 0.1 }, rim = { 0.5, 0.5, 0.5 }, accent = { 1, 1, 1 }, style = "FANTASY" })
    page.Refresh()
    local mine = listOf("MINE")
    if #mine ~= 1 or mine[1] ~= key then error("your own theme should be listed under Your themes") end
    if #listOf("FANTASY") ~= 39 then error("your own fantasy theme must not be listed under Fantasy as well") end
    ns:DeleteCustomTheme("Mine Own"); page.Refresh()
    -- the panel behind the action bars starts off, and the switch reaches the bars
    if ns.defaults.barPanel ~= false then error("the action bar panel should start off") end
    if type(ns.ApplyBarPanels) ~= "function" or ns:ApplyBarPanels() < 1 then error("no action bar panels to switch") end
    ns:ToggleConfig()
end)
try("Bag window: using items", function()
    for _, e in ipairs({ "MERCHANT_CLOSED", "BANKFRAME_CLOSED", "GUILDBANKFRAME_CLOSED", "TRADE_CLOSED", "AUCTION_HOUSE_CLOSED" }) do fireEvent(e) end
    local bag
    for _, api in pairs(ns.bagTest or {}) do bag = bag or api end
    if not bag then error("the bag window offers nothing to test") end
    local used = 0
    local realUse, realSpell = env.C_Container.UseContainerItem, env.C_Item and env.C_Item.GetItemSpell
    env.C_Container.UseContainerItem = function() used = used + 1 end
    env.C_Item = env.C_Item or {}
    local spell = "Healing Potion"
    env.C_Item.GetItemSpell = function() return spell end
    local slot = { bag = 0, slot = 1, info = { hyperlink = "item:118" } }
    env.InCombatLockdown = function() return false end
    -- an item with a Use: effect is never used directly: the secure button is brought to the slot instead
    if bag.RightClick(slot) ~= "attached" or used ~= 0 then error("a usable item must go through the secure button (direct uses: " .. used .. ")") end
    if rawget(bag.overlay(), "target") ~= slot then error("the secure button should now be on that slot") end
    -- in combat the secure button can't be moved: no direct use either, only the reminder
    env.InCombatLockdown = function() return true end
    if bag.RightClick(slot) ~= "combat" or used ~= 0 then error("in combat a usable item must not be used directly") end
    if bag.Attach({ bag = 0, slot = 2 }) ~= false then error("the secure button must not be moved in combat") end
    env.InCombatLockdown = function() return false end
    -- gear and other items without a Use: effect are fine to act on directly (equip, sell, bank)
    spell = nil
    if bag.RightClick(slot) ~= "used" or used ~= 1 then error("an item without a Use: effect should be acted on directly") end
    -- if the game can't tell us, assume the item is protected
    env.C_Item.GetItemSpell = nil; env.GetItemSpell = nil
    if bag.RightClick(slot) == "used" then error("when unsure, an item must be treated as protected") end
    env.C_Container.UseContainerItem = realUse
    env.C_Item.GetItemSpell = realSpell
    rawset(bag.overlay(), "target", nil)                   -- (the stand-in slot must not outlive this test)
end)
try("Painting a frame that gives no texture", function()
    local made = 0
    local odd = { CreateTexture = function() made = made + 1; return nil end }           -- as reported from the game
    if ns:PaintPanel(odd, 0.98, true) ~= nil then error("a frame that can't be painted should be skipped") end
    if made ~= 1 then error("it should have been tried exactly once") end
    ns:PaintPanel(odd, 0.98, true)
    if made ~= 1 then error("it must not be tried again") end
    local broken = { CreateTexture = function() error("refused") end }
    if ns:PaintPanel(broken) ~= nil then error("a frame that refuses must be skipped, not raise an error") end
    if type(ns:PaintPanel(newmock())) ~= "table" then error("an ordinary frame should still be painted") end
end)
try("Class emblems (medallions)", function()
    ns.db.reduceMotion, ns.db.emblemAnim = false, true
    local m = ns:CreateEmblem(newmock(), 1)
    if type(m) ~= "table" or type(m.SetClass) ~= "function" then error("no medallion") end
    if #m.loops ~= 4 then error("four loops: ring, sparks, glow, sigil; got " .. #m.loops) end
    -- stand-in loops that remember whether they are playing
    local fakes = {}
    for i = 1, 4 do
        local g = { playing = false }
        function g:Play() self.playing = true end
        function g:Stop() self.playing = false end
        function g:IsPlaying() return self.playing end
        fakes[i] = g
    end
    m.loops = fakes
    local sigilFile, ringFile
    rawset(m.sigil, "SetTexture", function(_, f) sigilFile = f end)
    rawset(m.ring, "SetTexture", function(_, f) ringFile = f end)
    rawset(m, "IsVisible", function() return true end)
    local oldStyle = ns.style
    ns.style = "GLASS"
    m.style = nil
    m:SetClass("MAGE", 0.25, 0.78, 0.92)
    if not (sigilFile and sigilFile:find("emblem", 1, true) and sigilFile:find("MAGE.tga", 1, true)) then error("wrong sigil: " .. tostring(sigilFile)) end
    if not (ringFile and ringFile:find("ring_glass", 1, true)) then error("Glass themes: the clean ring, got " .. tostring(ringFile)) end
    for i, g in ipairs(fakes) do if not g.playing then error("loop " .. i .. " should be playing") end end
    -- the game stops a loop (a hidden frame, a loading screen): the check once a second starts it again
    fakes[3].playing = false
    local shown, moving = ns:EmblemTick()
    if not fakes[3].playing then error("a stopped loop should be started again") end
    if shown < 1 or moving < 1 then error("the medallion should be counted as on screen and moving") end
    -- a Fantasy theme: the ring of runes
    ns.style = "FANTASY"
    ns:EmblemTick()
    if not ringFile:find("ring_rune", 1, true) then error("Fantasy themes: the rune ring, got " .. tostring(ringFile)) end
    -- reduce motion, or the switch off: everything holds still, and stays still
    for _, how in ipairs({ "reduceMotion", "emblemAnim" }) do
        ns.db.reduceMotion, ns.db.emblemAnim = (how == "reduceMotion"), (how ~= "emblemAnim")
        ns:EmblemTick()
        for i, g in ipairs(fakes) do if g.playing then error("with " .. how .. " loop " .. i .. " should stop") end end
        local _, mv = ns:EmblemTick()
        if mv ~= 0 then error("nothing counts as moving with " .. how) end
    end
    ns.db.reduceMotion, ns.db.emblemAnim = false, true
    ns:EmblemTick()
    for i, g in ipairs(fakes) do if not g.playing then error("switched back on: loop " .. i .. " plays again") end end
    -- a medallion that is not on screen is not counted
    rawset(m, "IsVisible", function() return false end)
    fakes[1].playing = false
    ns:EmblemTick()
    if fakes[1].playing then error("one off screen is left alone until it is shown") end
    ns.style = oldStyle
    -- the sigil itself is animated: sixteen frames, each inside its own cell of the 4 x 4 sheet
    for frame = 0, 15 do
        local l, r, tp, b = ns:EmblemCoords(frame)
        local col, row = frame % 4, math.floor(frame / 4)
        if not (l > col / 4 and r < (col + 1) / 4 and tp > row / 4 and b < (row + 1) / 4) then error("frame " .. frame .. " reaches outside its cell") end
    end
    local seen = {}
    for step = 0, 15 do seen[ns.EmblemFrameAt(100 + step / 12 + 0.001, 12, true)] = true end
    local n = 0; for _ in pairs(seen) do n = n + 1 end
    if n ~= 16 then error("all sixteen frames in one loop, saw " .. n) end
    if ns.EmblemFrameAt(123.4, 12, false) ~= 0 then error("held still: the first frame") end
    local clock, realTime = 50, env.GetTime
    env.GetTime = function() return clock end
    local coords
    rawset(m.sigil, "SetTexCoord", function(_, a, b, c, d) coords = { a, b, c, d } end)
    m:SetClass("HUNTER", 0.67, 0.83, 0.45)
    local first = coords and coords[1]
    clock = clock + 0.5
    ns.EmblemStep(m)
    if not coords or coords[1] == first and coords[3] == coords[3] and ns.EmblemFrameAt(clock, m.fps, true) == ns.EmblemFrameAt(50, m.fps, true) then error("the sigil should move on with the clock") end
    if m.frame ~= ns.EmblemFrameAt(clock, m.fps, true) then error("the sigil shows the frame for this moment") end
    env.GetTime = realTime
end)
try("Chat bubbles in each style", function()
    if type(ns.StyleBubble) ~= "function" then error("the chat bubble module did not start") end
    -- a stand-in bubble whose textures remember what was done to them
    local function standIn()
        local made, label = {}, { hidden = nil }
        local holder = newmock()
        rawset(holder, "CreateTexture", function(_, _, layer, _, sub)
            local tx = newmock()
            local rec = { layer = layer, sub = sub or 0, points = {} }
            rawset(tx, "rec", rec)
            rawset(tx, "SetTexture", function(_, file) rec.file = file end)
            rawset(tx, "SetVertexColor", function(_, r, g, b, a) rec.color = { r, g, b, a } end)
            rawset(tx, "SetAllPoints", function(_, to) rec.all = to end)
            rawset(tx, "SetPoint", function(_, point, rel, _, x, y) rec.points[point] = { rel = rel, x = x or 0, y = y or 0 } end)
            rawset(tx, "Show", function() rec.hidden = false end)
            rawset(tx, "Hide", function() rec.hidden = true end)
            made[#made + 1] = tx
            return tx
        end)
        rawset(holder, "CreateFontString", function()
            local fs = newmock()
            rawset(fs, "SetText", function(_, s) label.text = s end)
            rawset(fs, "Show", function() label.hidden = false end)
            rawset(fs, "Hide", function() label.hidden = true end)
            return fs
        end)
        local str = newmock(); rawset(str, "GetText", function() return "lol" end)
        rawset(holder, "String", str)
        rawset(holder, "GetRegions", function() return end)
        rawset(holder, "IsForbidden", function() return false end)
        local bubble = newmock()
        rawset(bubble, "GetChildren", function() return holder end)
        rawset(bubble, "IsForbidden", function() return false end)
        return bubble, holder, made, label
    end
    local function same(c, r, g, b) return c and math.abs(c[1] - r) < 0.002 and math.abs(c[2] - g) < 0.002 and math.abs(c[3] - b) < 0.002 end
    local function check(style, wantRound)
        local bubble, holder, made, label = standIn()
        ns.StyleBubble(bubble)
        local by, fill = {}, nil
        for _, tx in ipairs(made) do
            local part = rawget(tx, "part")
            if not rawget(tx, "sui") or not part then error(style .. ": a piece is not tagged, so the strip of Blizzard's art would remove it") end
            by[part] = (by[part] or 0) + 1
            if part == "fill" then fill = tx end
        end
        if by.fill ~= 1 then error(style .. ": expected one pane") end
        local wr, wg, wb = ns:Role("window", 1)
        local br, bg, bb = ns:Role("@border", 1)
        local ar, ag, ab = ns:Role("@accent", 1)
        local fillRec = rawget(fill, "rec")
        if not same(fillRec.color, wr, wg, wb) then error(style .. ": the pane is not in the panel color") end
        -- the fault this replaced: a solid sheet in another color lying over the pane
        for _, tx in ipairs(made) do
            local rec, part = rawget(tx, "rec"), rawget(tx, "part")
            local covers = rec.all == fill
            local a, b = rec.points.TOPLEFT, rec.points.BOTTOMRIGHT
            if a and b and a.rel == fill and b.rel == fill and math.abs(a.x) <= 2 and math.abs(a.y) <= 2 and math.abs(b.x) <= 2 and math.abs(b.y) <= 2 then covers = true end
            if covers and part ~= "fill" and rec.sub > fillRec.sub and rec.file == ns.FLAT and rec.color and (rec.color[4] or 1) > 0.5 then
                error(style .. ": the piece '" .. part .. "' is a solid sheet over the pane")
            end
        end
        for _, part in ipairs({ "tail", "tailEdge", "joint", "tab" }) do
            if by[part] ~= 1 then error(style .. ": missing " .. part) end
        end
        for _, tx in ipairs(made) do
            local rec, part = rawget(tx, "rec"), rawget(tx, "part")
            if part == "tail" and not (rec.file:find("tail.tga", 1, true) and same(rec.color, wr, wg, wb)) then error(style .. ": the tail should be the pane's color") end
            if part == "tailEdge" and not (rec.file:find("tail_edge.tga", 1, true) and same(rec.color, br, bg, bb)) then error(style .. ": the tail's edge should be the rim's color") end
            if part == "corner" and not (rec.file:find("corner.tga", 1, true) and same(rec.color, ar, ag, ab)) then error(style .. ": corner brackets should be in the accent color") end
            if part == "accent" and not same(rec.color, ar, ag, ab) then error(style .. ": the side bar should be in the accent color") end
        end
        if style == "celestial" then
            if by.sky ~= 1 or by.stars ~= 1 or by.star ~= 1 or by.rim ~= 4 or by.glow ~= 4 or by.horizon ~= 1 then error("celestial: expected a sky, stars, a horizon, a fine rim with a glow, and the star at the top") end
            if by.corner or by.grain or by.accent or by.shadow then error("celestial: glass or fantasy pieces on a celestial bubble") end
            for _, tx in ipairs(made) do
                local rec = rawget(tx, "rec")
                if rawget(tx, "part") == "star" and not (rec.file:find("sparkle.tga", 1, true) and same(rec.color, ar, ag, ab)) then error("celestial: the star should be in the accent color") end
            end
        elseif style == "fantasy" then
            if by.corner ~= 4 or by.grain ~= 1 or by.outline ~= 4 or by.rim ~= 4 then error("fantasy: expected brackets, grain, an outer line and a rim") end
            if by.accent or by.shadow then error("fantasy: glass pieces on a fantasy bubble") end
        else
            if by.accent ~= 1 or by.shadow ~= 1 or by.edge ~= 1 then error(style .. ": expected a shadow, a lit top edge and an accent bar") end
            if by.corner or by.grain then error(style .. ": fantasy pieces on a glass bubble") end
            if wantRound and by.rim ~= 1 then error("rounded glass: the rim should be one rounded piece") end
            if not wantRound and by.rim ~= 4 then error("square glass: the rim should be four lines") end
        end
        -- no name known yet: the tab stays away. Once the line has been heard, it shows with the name.
        if label.hidden ~= true then error(style .. ": the name should be hidden until the speaker is known") end
        for _, tx in ipairs(made) do
            local part = rawget(tx, "part")
            if (part == "tab" or part == "tabRim" or part == "tabOutline") and rawget(tx, "rec").hidden ~= true then error(style .. ": the tab should hide with the name") end
        end
        ns:BubbleHeard("lol", "Denogh", "SHAMAN")
        ns.StyleBubble(bubble)
        if label.hidden ~= false or label.text ~= "Denogh" then error(style .. ": the speaker's name should now show") end
        for _, tx in ipairs(made) do
            if rawget(tx, "part") == "tab" and rawget(tx, "rec").hidden ~= false then error(style .. ": the tab should show with the name") end
        end
        local before = #made
        ns.StyleBubble(bubble)
        if #made ~= before then error(style .. ": a bubble must be dressed only once") end
        ns.db.bubbleNames = false; ns.StyleBubble(bubble)
        if label.hidden ~= true then error(style .. ": with names switched off the tab should hide") end
        ns.db.bubbleNames = true
        ns:BubbleHeard("lol", nil, nil)
    end
    local keepTheme, keepRounded = ns.db.theme, ns.db.rounded
    ns.db.theme = "SMOKE"; ns.db.rounded = true; ns:BuildPalette()
    if ns:CanRound() then check("rounded glass", true) end
    ns.db.rounded = false; ns:BuildPalette(); check("square glass", false)
    ns.db.theme = "ROYAL"; ns:BuildPalette(); check("fantasy", false)
    for key, t in pairs(ns.themes) do if t.style == "CELESTIAL" and not t.custom then ns.db.theme = key; break end end
    ns:BuildPalette(); check("celestial", false)
    ns.db.theme, ns.db.rounded = keepTheme, keepRounded; ns:Retheme()
end)
try("Where reports go", function()
    local keep = ns.reportLink
    -- the address the add-on ships with: a real web address, and it survives the tidying unchanged
    if type(keep) ~= "string" or not keep:find("^https://[%w%.%-]+/[%w%-_/]+$") then error("the shipped report address is not a plain web address: " .. tostring(keep)) end
    if ns:ReportLink() ~= keep then error("the shipped address should be shown exactly as written") end
    ns.reportLink = ""
    if ns:ReportLink() ~= nil then error("no address set: nothing to show") end
    ns.reportLink = "   https://example.com/form  \n"
    if ns:ReportLink() ~= "https://example.com/form" then error("the address should be tidied: '" .. tostring(ns:ReportLink()) .. "'") end
    ns.reportLink = "|cffff0000bad|r@example.com"
    if ns:ReportLink():find("|", 1, true) then error("formatting codes must be removed from the address") end
    ns.reportLink = string.rep("x", 500)
    if #ns:ReportLink() ~= 200 then error("an absurdly long address should be cut") end
    ns.reportLink = 42
    if ns:ReportLink() ~= nil then error("an address that is not text is ignored") end
    if ns.reportAsFile ~= true then error("the add-on ships asking for the report as a file") end
    -- the instructions are a list of whole steps: several of them, none empty, none hiding a line break
    local function steps(link, asFile, want)
        ns.reportAsFile = asFile
        local list = ns:ReportSteps(link)
        if #list ~= want then error("expected " .. want .. " steps for " .. link .. ", got " .. #list) end
        if #list > 5 then error("more steps than the window has lines for") end
        for i, s in ipairs(list) do
            if type(s) ~= "string" or #s < 20 then error("step " .. i .. " is not a full instruction") end
            if s:find("\n", 1, true) then error("step " .. i .. " hides a line break: each step must be its own line") end
        end
        return list
    end
    local file = steps("https://example.com/form", true, 5)
    if not (file[2]:find("Notepad", 1, true) and file[3]:find("Save", 1, true) and file[5]:find("upload", 1, true)) then error("the file steps should say: Notepad, save, upload") end
    steps("https://example.com/form", false, 3)
    local mail = steps("reports@example.com", true, 3)
    if not mail[1]:find("email", 1, true) then error("an email address gets email steps even when files are asked for") end
    if #ns:ReportSteps("") ~= 0 or #ns:ReportSteps(nil) ~= 0 then error("no address, no steps") end
    ns.reportAsFile = true
    for _, asFile in ipairs({ true, false }) do                                              -- upload a file, or paste
        ns.reportAsFile = asFile
        for _, link in ipairs({ "https://example.com/form", "reports@example.com", "" }) do  -- a web page, an email, none
            ns.reportLink = link
            ns:ProblemReport()
        end
    end
    ns.reportLink, ns.reportAsFile = keep, true
end)
try("The game's roll frames stay out of sight", function()
    for _, name in ipairs({ "GroupLootContainer", "GroupLootFrame1", "GroupLootFrame2" }) do
        local f = known[name]
        local s = rawget(f, "state")
        if s.alpha ~= 0 then error(name .. " should be invisible while our roll frames are on") end
        if s.mouse ~= false then error(name .. " should not take clicks") end
        if rawget(f, "suiWindow") then error(name .. " must not be given a window panel") end
        s.alpha = 1                                        -- the game shows it for a roll ...
        for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.02) end end
        if s.alpha ~= 0 then error(name .. " should be cleared again at once, not a second later") end
    end
    if ns.QuietGameRolls() ~= 3 then error("expected the container and two roll frames to be found") end
    fireEvent("START_LOOT_ROLL", 7, 60000); fireEvent("CANCEL_LOOT_ROLL", 7)       -- and a roll still runs through ours
end)
try("Storage: naming a character", function()
    local L = ns.StorageLabel
    if type(L) ~= "function" then error("the storage module did not start") end
    local long = "Denogh - CAMWOW US1 Realm 6 PvP"
    -- one realm: the realm is left out, however long it is
    if L(long, { [long] = {}, ["Ysolde - CAMWOW US1 Realm 6 PvP"] = {} }) ~= "Denogh" then error("same realm: just the name") end
    if L(long, { [long] = {} }) ~= "Denogh" then error("one character: just the name") end
    -- more than one realm: the realm is needed to tell them apart
    if L(long, { [long] = {}, ["Denogh - Other Realm"] = {} }) ~= long then error("different realms: the full name") end
    -- names with a hyphen of their own, and things that are not names
    if L("Mary-Jane - Realm", { ["Mary-Jane - Realm"] = {} }) ~= "Mary-Jane" then error("a hyphen inside the name must survive") end
    if L("NoRealm", {}) ~= "NoRealm" or L(nil, {}) ~= "nil" then error("an odd key should be shown as it is") end
    ns:OpenStorage("bags"); ns:OpenStorage("bank")           -- the window builds, and the picker is fitted, without error
end)
try("Frames the game has locked away", function()
    -- a forbidden frame: every method raises, except the one that says it is forbidden
    local function forbidden()
        local f = {}
        return setmetatable(f, { __index = function(_, k)
            if k == "IsForbidden" then return function() return true end end
            if type(k) == "string" and k:sub(1, 3) == "sui" then return nil end
            return function() error("Attempt to access forbidden object from code tainted by an AddOn") end
        end })
    end
    local locked = forbidden()
    if ns:Usable(locked) then error("a forbidden frame must not be treated as usable") end
    if ns:Usable(nil) or ns:Usable(42) then error("only frames are usable") end
    if not ns:Usable(newmock()) then error("an ordinary frame is usable") end
    local broken = setmetatable({}, { __index = function(_, k) if k == "IsForbidden" then return function() error("no") end end end })
    if ns:Usable(broken) then error("a frame that cannot even answer is not usable") end

    -- the fault that was reported: a forbidden frame among the screen's children while a menu is open
    local realChildren, realMenu = rawget(env.UIParent, "GetChildren"), env.Menu
    local root = newmock()
    rawset(root, "IsForbidden", function() return false end)
    rawset(root, "GetRegions", function() return end)
    rawset(root, "GetChildren", function() return locked end)
    rawset(root, "GetParent", function() return env.UIParent end)
    rawset(root, "OpenSomething", function() end)                       -- (a function for the menu "signature")
    rawset(env.UIParent, "GetChildren", function() return locked, newmock() end)
    env.Menu = { GetManager = function() return { GetOpenMenu = function() return root end } end }
    local before = #ns.errors
    for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.06) end end
    for i = before + 1, #ns.errors do
        if ns.errors[i]:find("forbidden", 1, true) then error("a forbidden frame was touched: " .. ns.errors[i]) end
    end
    -- and a menu that is itself forbidden is left alone
    env.Menu = { GetManager = function() return { GetOpenMenu = function() return locked end } end }
    for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.06) end end
    for i = before + 1, #ns.errors do
        if ns.errors[i]:find("forbidden", 1, true) then error("a forbidden menu was touched: " .. ns.errors[i]) end
    end
    rawset(env.UIParent, "GetChildren", realChildren)
    env.Menu = realMenu
end)
try("Bags: using items in combat", function()
    local bag = ns.bagTest["FantasyGlassUIBags"]
    if not bag or not bag.secure then error("the bag window offers nothing to test") end
    local C = env.C_Container
    local keepSlots, keepInfo = C.GetContainerNumSlots, C.GetContainerItemInfo
    local size = 4
    local first                                            -- whichever bag the window asks about first holds the test items
    local asked = {}
    C.GetContainerNumSlots = function(id) asked[#asked + 1] = tostring(id); if first == nil then first = id end; return id == first and size or 0 end
    C.GetContainerItemInfo = function(_, slot) return { iconFileID = 1, stackCount = 1, quality = 1, itemID = 100 + slot, hyperlink = "item:" .. slot } end
    local combat = false
    env.InCombatLockdown = function() return combat end
    local function tick() for _ = 1, 2 do for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.2) end end end end
    local function update() fireEvent("BAG_UPDATE_DELAYED"); tick() end
    local function each(fn) for _, list in pairs(bag.slots()) do for _, b in pairs(list) do fn(b) end end end

    -- switched off (as it ships): no slot carries a secure button
    if ns.defaults.bagCombatUse ~= false then error("this option must ship switched off") end
    ns.db.bagCombatUse = false; update()
    if bag.secure() ~= 0 then error("off: there should be no secure buttons") end

    -- switched on: every slot gets one, and a right-click is left to it
    ns.db.bagCombatUse = true; update()
    do local ok, e = pcall(bag.Layout); if not ok then error("the bag window could not be arranged: " .. tostring(e)) end end
    if bag.secure() ~= 4 then
        local n = 0; each(function() n = n + 1 end)
        error("asked about bags: " .. table.concat(asked, ",", 1, math.min(#asked, 14)) .. " | on: expected a secure button on each of the 4 slots, got " .. bag.secure() .. " | slots made: " .. n .. " | state: " .. tostring(ns.BagUseState()) .. " | last error: " .. tostring(ns.errors[#ns.errors]))
    end
    local have = 0
    each(function(b)
        if rawget(b, "suiUse") then
            have = have + 1
            if bag.RightClick(b) ~= "secure" then error("a slot with its own secure button must not act on a right-click itself") end
        end
    end)
    if have ~= 4 then error("the four slots in use should each carry a button, found " .. have) end
    if not ns.BagUseState():find("4 slots", 1, true) then error("the self-check should report it: " .. ns.BagUseState()) end

    -- in combat nothing may be moved, shown or hidden: the arrangement is frozen
    local moved = 0
    each(function(b)
        for _, method in ipairs({ "SetPoint", "ClearAllPoints", "Show", "Hide", "SetSize" }) do
            rawset(b, method, function() moved = moved + 1 end)
        end
    end)
    local winMoved = 0
    rawset(bag.win, "SetHeight", function() winMoved = winMoved + 1 end)
    combat = true; size = 5; update(); update()
    if moved ~= 0 or winMoved ~= 0 then error("in combat " .. moved .. " slot changes and " .. winMoved .. " window changes were made: nothing may move") end
    if bag.secure() ~= 4 then error("no secure button may be made during combat") end
    -- when the fight ends the window is arranged again, and the slot that appeared meanwhile gets its button
    combat = false; fireEvent("PLAYER_REGEN_ENABLED"); tick()
    if moved == 0 or winMoved == 0 then error("after combat the window should be arranged again") end
    if bag.secure() ~= 5 then error("the slot that appeared during combat should get its button afterwards, have " .. bag.secure()) end
    -- just before a fight starts the window is arranged, open or not, while that is still allowed
    moved = 0; fireEvent("PLAYER_REGEN_DISABLED")
    if moved == 0 then error("the window should be arranged as a fight begins") end

    -- switched off again: the buttons come off
    ns.db.bagCombatUse = false; update()
    if bag.secure() ~= 0 then error("switching it off should take the buttons off") end
    each(function(b) if rawget(b, "suiUse") then error("a button was left on a slot") end end)

    -- a client where secure buttons would stop the window opening in combat: it backs out, and says so
    rawset(bag.win, "IsProtected", function() return true end)
    ns.db.bagCombatUse = true; update()
    if bag.secure() ~= 0 then error("it should have backed out") end
    if not ns.BagUseState():find("not possible", 1, true) then error("the self-check should say why: " .. ns.BagUseState()) end
    ns.db.bagCombatUse = false
    C.GetContainerNumSlots, C.GetContainerItemInfo = keepSlots, keepInfo
    env.InCombatLockdown = function() return false end
    rawset(bag.overlay(), "target", nil)
end)
try("Minimap button for the options", function()
    if type(ns.LauncherClick) ~= "function" then error("the launcher module did not start") end
    runTimers(); ns.BuildLauncher()
    if type(ns.PlaceLauncher) ~= "function" then error("the button was not built") end
    -- it can't be dragged away from the minimap and lost
    local x, y = ns.PlaceLauncher(5000, -5000)
    if not (x <= 188 and y >= -8) then error("the button escaped the minimap: " .. x .. ", " .. y) end
    x, y = ns.PlaceLauncher(40, 60)
    if x ~= 40 or y ~= 60 then error("a spot on the minimap should be kept as given") end
    local opened, moving = 0, 0
    local realConfig, realMove = ns.ToggleConfig, ns.ToggleMove
    ns.ToggleConfig = function() opened = opened + 1 end
    ns.ToggleMove = function() moving = moving + 1 end
    ns.LauncherClick("LeftButton"); ns.LauncherClick("RightButton")
    ns.ToggleConfig, ns.ToggleMove = realConfig, realMove
    if opened ~= 1 or moving ~= 1 then error("left-click should open the options and right-click start moving panels") end
end)
try("Boss frames", function()
    if type(ns.bossFrames) ~= "table" or #ns.bossFrames ~= 5 then error("expected five boss frames") end
    local found = 0
    for _, m in ipairs(ns.movables) do if m.key:find("^ufBoss%d$") then found = found + 1 end end
    if found ~= 5 then error("each boss frame should be movable, found " .. found) end
    ns:OpenPanelMenu("ufBoss2")                             -- its settings open, for all five as a group
    if ns:PresetValue("MINIMAL", "ufBoss") ~= true then error("boss frames are part of the core set") end
end)
try("Breath bar", function()
    if type(ns.MirrorDraw) ~= "function" then error("the breath bar module did not start") end
    if ns.MirrorDraw() ~= 0 then error("nothing should show until a timer starts") end
    fireEvent("MIRROR_TIMER_START", "BREATH", 30000, 60000, -1, 0, "Breath")
    if ns.MirrorDraw() ~= 1 then error("the breath bar should show") end
    fireEvent("MIRROR_TIMER_START", "EXHAUSTION", 20000, 30000, -1, 0, "Fatigue")
    if ns.MirrorDraw() ~= 2 then error("breath and fatigue can run together") end
    fireEvent("MIRROR_TIMER_PAUSE", "BREATH", 1)
    fireEvent("MIRROR_TIMER_STOP", "BREATH"); fireEvent("MIRROR_TIMER_STOP", "EXHAUSTION")
    -- a game that will not say how much is left: the bar counts down by itself, and holds while paused
    local realProgress, realTime, clock = env.GetMirrorTimerProgress, env.GetTime, 500
    env.GetMirrorTimerProgress, env.GetTime = function() return nil end, function() return clock end
    fireEvent("MIRROR_TIMER_START", "BREATH", 30000, 60000, -1, 0, "Breath")
    clock = clock + 10; ns.MirrorDraw()
    local bar = ns.mirrorBars and ns.mirrorBars[1]
    if not bar then error("the breath bar's own bar could not be found for the countdown check") end
    local shown; rawset(bar, "SetValue", function(_, v) shown = v end); ns.MirrorDraw()
    local function Left() return shown end
    if math.abs((Left() or 0) - 20) > 0.01 then error("after 10 seconds 20 should be left, not " .. tostring(Left())) end
    fireEvent("MIRROR_TIMER_PAUSE", "BREATH", 1); clock = clock + 10; ns.MirrorDraw()
    if math.abs((Left() or 0) - 20) > 0.01 then error("a paused timer should hold, not " .. tostring(Left())) end
    fireEvent("MIRROR_TIMER_PAUSE", "BREATH", 0); clock = clock + 5; ns.MirrorDraw()
    if math.abs((Left() or 0) - 15) > 0.01 then error("it should run on from where it held, not " .. tostring(Left())) end
    fireEvent("MIRROR_TIMER_STOP", "BREATH"); rawset(bar, "SetValue", nil)
    env.GetMirrorTimerProgress, env.GetTime = realProgress, realTime
    if ns.MirrorDraw() ~= 0 then error("the bars should go when their timers stop") end
    fireEvent("MIRROR_TIMER_START", "UNKNOWN", 0, 0, 0, 0, "")
    if ns.MirrorDraw() ~= 0 then error("an unused timer slot must not show a bar") end
    fireEvent("PLAYER_ENTERING_WORLD")
    if type(ns.StyleExtraButtons()) ~= "number" then error("the extra action button pass should run") end
end)
try("Translations", function()
    local codes = { "deDE", "frFR", "esES" }
    local n = {}
    for _, code in ipairs(codes) do
        local tab = ns.locales[code]
        if type(tab) ~= "table" then error("no table for " .. code) end
        n[code] = 0
        for english, translated in pairs(tab) do
            n[code] = n[code] + 1
            if type(translated) ~= "string" or translated == "" then error(code .. ": empty translation for " .. english) end
            -- every %s, %d and %% in the English must still be in the translation, the same number of times
            for _, hole in ipairs({ "%%s", "%%d", "%%%%" }) do
                local _, a = english:gsub(hole, "")
                local _, b = translated:gsub(hole, "")
                if a ~= b then error(code .. ": the placeholders differ in '" .. english .. "'") end
            end
        end
    end
    if n.deDE < 250 or n.deDE ~= n.frFR or n.frFR ~= n.esES then error("the three languages should cover the same labels: " .. n.deDE .. ", " .. n.frFR .. ", " .. n.esES) end
    if ns.locales.esMX ~= ns.locales.esES then error("Latin American Spanish should share the Spanish table") end
    -- switching language changes labels; anything not translated stays in English
    local realLocale = env.GetLocale
    env.GetLocale = function() return "deDE" end
    ns:LoadLocale()
    if ns:Tr("Unit frames") ~= "Einheitenfenster" then error("German was not applied: " .. tostring(ns:Tr("Unit frames"))) end
    if ns:Tr("Some label nobody translated") ~= "Some label nobody translated" then error("an untranslated label should stay as it is") end
    for k in pairs(ns.L) do rawset(ns.L, k, nil) end            -- back to English for the rest of the run
    env.GetLocale = realLocale
    if ns:Tr("Unit frames") ~= "Unit frames" then error("could not return to English") end
end)
try("Choosing a language", function()
    local realLocale = env.GetLocale
    env.GetLocale = function() return "enUS" end
    ns.root.language = nil; ns:LoadLocale()
    if ns:Language() ~= "auto" then error("with nothing chosen the language follows the game") end
    if ns:Tr("Unit frames") ~= "Unit frames" then error("an English game should give English") end
    -- chosen by hand: it wins over the game's language
    if not ns:SetLanguage("deDE") then error("choosing German should report a change") end
    if ns.root.language ~= "deDE" or ns:Tr("Unit frames") ~= "Einheitenfenster" then error("German was not applied") end
    if ns:SetLanguage("deDE") then error("choosing the same language again is not a change") end
    if env.BINDING_NAME_FANTASYGLASSUI_OPTIONS ~= ns:Tr("Open options") or env.BINDING_NAME_FANTASYGLASSUI_OPTIONS == "Open options" then
        error("the Key Bindings window should name our keys in German: " .. tostring(env.BINDING_NAME_FANTASYGLASSUI_OPTIONS)) end
    if env["BINDING_NAME_CLICK FantasyGlassUIHealKey:LeftButton"] == "Use my best healing potion" then error("the potion key name should be in German too") end
    env.GetLocale = function() return "frFR" end
    ns:SetLanguage("enUS")
    if ns:Tr("Unit frames") ~= "Unit frames" then error("English chosen by hand must hold even on a French game") end
    if env.BINDING_NAME_FANTASYGLASSUI_OPTIONS ~= "Open options" then error("going back to English should give the English key names again") end
    -- "Same as the game" follows the game again, and is stored as nothing at all
    ns:SetLanguage("auto")
    if ns.root.language ~= nil or ns:Tr("Unit frames") ~= "Cadres d'unité" then error("following the game should give French here") end
    -- a language nobody offers is refused, and nothing changes
    if ns:SetLanguage("xxXX") or ns:SetLanguage(nil) then error("an unknown language must be refused") end
    ns.root.language = "garbage"
    if ns:Language() ~= "auto" then error("a damaged setting should fall back to following the game") end
    -- every language is listed under its own name
    local names = {}
    for _, def in ipairs(ns.languages) do names[def[1]] = def[2] end
    if names.deDE ~= "Deutsch" or names.frFR ~= "Français" or names.esES ~= "Español" or names.enUS ~= "English" then error("languages should be listed under their own names") end
    -- picking one in the setup: saved and marked to come back (the language's button then hands the
    -- click to the game's own reload: see "12.3 reload"); the one already in use says no, so no reload
    env.GetLocale = function() return "enUS" end
    ns.root.language = nil; ns:LoadLocale()
    local reloads = 0
    local realReload = env.ReloadUI
    env.ReloadUI = function() reloads = reloads + 1 end
    if not ns:SetupPickLanguage("esES") then error("picking Spanish in the setup should take") end
    if reloads ~= 0 or ns.root.resumeSetup ~= true or ns.root.language ~= "esES" then error("the setup should save the language and mark itself to resume, and leave the reload to its button") end
    if ns:SetupPickLanguage("esES") then error("picking the language already in use must say no, so its button does not reload") end
    -- after the reload, logging in opens the setup again and clears the mark
    fireEvent("PLAYER_LOGIN"); runTimers()
    if ns.root.resumeSetup ~= nil then error("the mark should be cleared once the setup has come back") end
    -- the slash command, for someone who cannot read what is on screen
    env.SlashCmdList.FANTASYGLASSUI("language english")
    if ns:Language() ~= "enUS" then error("/fgui language english should work") end
    env.SlashCmdList.FANTASYGLASSUI("language français")
    if ns:Language() ~= "frFR" then error("/fgui language français should work") end
    env.SlashCmdList.FANTASYGLASSUI("language auto")
    if ns:Language() ~= "auto" then error("/fgui language auto should work") end
    env.ReloadUI, env.GetLocale = realReload, realLocale
    ns.root.language, ns.root.resumeSetup = nil, nil
    ns:LoadLocale()
end)
try("Health text", function()
    local shown
    local fs = newmock()
    rawset(fs, "SetText", function(_, s) shown = s end)
    rawset(fs, "SetFormattedText", function(_, f, ...) shown = { f, ... } end)
    local realHP, realMax = env.UnitHealth, env.UnitHealthMax
    env.UnitHealth = function() return 12400 end
    env.UnitHealthMax = function() return 14588 end
    if ns.defaults.healthNumbers ~= false then error("health should be a percentage unless chosen otherwise") end
    ns.db.healthNumbers = false; ns.SetHealthText(fs, "player")
    if shown ~= "85%" then error("as a percentage: expected 85%, got " .. tostring(shown)) end
    ns.db.healthNumbers = true; ns.SetHealthText(fs, "player")
    if shown ~= "12.4k" then error("as a number: expected 12.4k, got " .. tostring(shown)) end
    for n, want in pairs({ [0] = "0", [950] = "950", [9999] = "9999", [10000] = "10.0k", [125300] = "125.3k", [1250000] = "1.25m" }) do
        if ns.ShortNumber(n) ~= want then error(n .. " should be written " .. want .. ", got " .. ns.ShortNumber(n)) end
    end
    -- an amount the game hides in combat: something is always shown, never an empty label and never an error
    env.UnitHealth = function() return SV(12400) end
    shown = nil
    local how = ns.SetHealthText(fs, "player")
    if shown == nil or shown == "" then error("with a hidden amount the label was left empty") end
    if type(how) ~= "string" then error("it should say how the hidden amount was written") end
    -- and if the game refuses every way of writing it, the percentage is shown instead
    local realAbbrev = env.AbbreviateNumbers
    env.AbbreviateNumbers = function() error("refused") end
    rawset(fs, "SetFormattedText", function(_, f) if f == "%d" then error("refused") end; shown = "percent" end)
    rawset(fs, "SetText", function(_, s) shown = s end)
    env.UnitHealth = function() return secretMode and SV(12400) or 12400 end
    ns.SetHealthText(fs, "player")
    if shown == nil or shown == "" then error("with everything refused the label should still show something") end
    env.AbbreviateNumbers = realAbbrev
    env.UnitHealth, env.UnitHealthMax = realHP, realMax
    ns.db.healthNumbers = false
    ns:RefreshHealthText()
end)
try("Nameplate health text", function()
    if type(ns.PlateHealth) ~= "function" then error("the nameplate module did not start") end
    local realHP, realMax = env.UnitHealth, env.UnitHealthMax
    env.UnitHealth = function() return 12400 end
    env.UnitHealthMax = function() return 14588 end
    local plate, uf = newmock(), newmock()
    rawset(uf, "healthBar", newmock())
    ns.db.plateHealth, ns.db.healthNumbers = true, false
    local h = ns.PlateHealth(plate, uf, "nameplate1")
    if not h then error("no health text was made for the plate") end
    local shown
    rawset(rawget(h, "text"), "SetText", function(_, s) shown = s end)
    ns:RefreshPlateHealth()
    if shown ~= "85%" then error("a plate should show a percentage by default, got " .. tostring(shown)) end
    -- it follows the same choice as the unit frames, the moment that choice changes
    ns.db.healthNumbers = true; ns:RefreshHealthText()
    if shown ~= "12.4k" then error("with numbers chosen a plate should show the amount, got " .. tostring(shown)) end
    -- switched off: nothing written on the bar
    ns.db.plateHealth = false; ns:RefreshPlateHealth()
    if shown ~= "" then error("switched off, the plate should carry no health text") end
    -- a plate that has lost its unit shows nothing, and making it again reuses the same text
    ns.db.plateHealth = true
    ns.PlateHealth(plate, uf, nil)
    if shown ~= "" then error("a plate with no unit should be blank") end
    if ns.PlateHealth(plate, uf, "nameplate2") ~= h then error("a reused plate should keep its text, not grow another") end
    if shown ~= "12.4k" then error("a reused plate should show its new unit's health") end
    ns.db.healthNumbers = false
    env.UnitHealth, env.UnitHealthMax = realHP, realMax
end)
try("Changing the resource text option rewrites the frames at once", function()
    local f
    for _, uf in ipairs(ns.unitFrameList or {}) do if rawget(uf, "ppct") and uf.unit == "player" then f = uf end end
    if not f then return end                                 -- (no player frame with resource text in this mode)
    local shown
    rawset(f.ppct, "SetText", function(_, t) shown = t end)
    rawset(f, "IsShown", function() return true end)
    local realP, realMax, keepText, keepNum = env.UnitPower, env.UnitPowerMax, ns.db.powerText, ns.db.powerNumbers
    env.UnitPower, env.UnitPowerMax = function() return 500 end, function() return 1000 end
    ns.db.powerText, ns.db.powerNumbers = true, false
    ns:RefreshHealthText()
    if shown ~= "50%" then error("a percentage first: " .. tostring(shown)) end
    ns.db.powerNumbers = true
    ns:RefreshHealthText()
    if shown ~= "500" then error("switching to numbers should show the amount at once, not " .. tostring(shown)) end
    ns.db.powerText, ns.db.powerNumbers = keepText, keepNum
    env.UnitPower, env.UnitPowerMax = realP, realMax
    rawset(f.ppct, "SetText", nil); rawset(f, "IsShown", nil)
    ns:RefreshHealthText()
end)
try("Resource text", function()
    local shown
    local fs = newmock()
    rawset(fs, "SetText", function(_, s) shown = s end)
    rawset(fs, "SetFormattedText", function(_, f, v) shown = { f, v } end)
    local realP, realMax, realPct, realCurves, realAbbrev = env.UnitPower, env.UnitPowerMax, env.UnitPowerPercent, env.CurveConstants, env.AbbreviateNumbers
    local curve = {}
    env.CurveConstants = { ScaleTo100 = curve }
    env.AbbreviateNumbers = function(v) return "abbr" end
    env.UnitPower = function() return 50 end
    env.UnitPowerMax = function() return 200 end
    -- the game's function, in the form (unit, powerType, unmodified, curve): right only when called that way
    env.UnitPowerPercent = function(_, _, _, c) if c == curve then return 25 end return 0.25 end
    ns.db.powerNumbers = false
    ns:ForgetPowerCall()
    if ns.defaults.powerText ~= true or ns.defaults.powerNumbers ~= false then error("resource text should ship on, as a percentage") end

    -- amounts that can be read: plain arithmetic, either way round
    ns.SetPowerText(fs, "player"); if shown ~= "25%" then error("readable percentage: expected 25%, got " .. tostring(shown)) end
    ns.db.powerNumbers = true
    ns.SetPowerText(fs, "player"); if shown ~= "50" then error("readable amount: expected 50, got " .. tostring(shown)) end
    env.UnitPower = function() return 12400 end; env.UnitPowerMax = function() return 20000 end
    ns.SetPowerText(fs, "player"); if shown ~= "12.4k" then error("a large amount should be shortened, got " .. tostring(shown)) end
    ns.db.powerNumbers = false
    env.UnitPower = function() return 0 end; env.UnitPowerMax = function() return 200 end
    ns.SetPowerText(fs, "player"); if shown ~= "0%" then error("empty should read 0%") end
    env.UnitPowerMax = function() return 0 end
    ns.SetPowerText(fs, "player"); if shown ~= "" then error("a unit with no resource should show nothing") end

    if secretMode then
        -- (a) amounts hidden only some of the time: the way of asking was checked while they were readable
        env.UnitPower = function() return 50 end; env.UnitPowerMax = function() return 200 end
        ns:ForgetPowerCall(); ns.SetPowerText(fs, "player")                       -- learns here
        env.UnitPower = function() return SV(50) end; env.UnitPowerMax = function() return SV(200) end
        local how = ns.SetPowerText(fs, "player")
        if type(shown) ~= "table" or shown[2] ~= 25 or how:find("unchecked", 1, true) then error("hidden, checked: the checked way should be used: " .. tostring(how)) end

        -- (b) the fault that was reported: amounts hidden ALL the time, so nothing could ever be checked.
        --     The label must not be blank: the game is asked anyway.
        ns:ForgetPowerCall()
        shown = nil
        how = ns.SetPowerText(fs, "player")
        if shown == nil or shown == "" then error("always-hidden amounts left the label blank") end
        if type(shown) ~= "table" or shown[2] ~= 25 then error("always hidden: expected the game's percentage") end
        if not how:find("unchecked", 1, true) then error("it should say the percentage could not be checked: " .. how) end

        -- (c) as amounts, hidden: the game shortens and writes it, like hidden health
        ns.db.powerNumbers = true
        how = ns.SetPowerText(fs, "player")
        if shown ~= "abbr" or not how:find("hidden amount", 1, true) then error("hidden amount: expected the game to write it, got " .. tostring(shown)) end
        ns.db.powerNumbers = false

        -- (d) a way was checked and none agreed: the amount is shown, never an untrusted percentage
        ns:ForgetPowerCall()
        env.UnitPowerPercent = function() return 0.25 end
        env.UnitPower = function() return 50 end; env.UnitPowerMax = function() return 200 end
        ns.SetPowerText(fs, "player")                                             -- readable: checks, nothing agrees
        env.UnitPower = function() return SV(50) end; env.UnitPowerMax = function() return SV(200) end
        how = ns.SetPowerText(fs, "player")
        if shown ~= "abbr" or not how:find("no percentage available", 1, true) then error("untrusted percentage: the amount should be shown instead: " .. tostring(how)) end

        -- (e) a client with no percentage function at all
        ns:ForgetPowerCall()
        env.UnitPowerPercent = false                       -- (the harness's way of saying "not there")
        how = ns.SetPowerText(fs, "player")
        if shown ~= "abbr" then error("no percentage function: the amount should be shown") end
    end
    if type(ns:PowerPercentProbe()) ~= "string" or type(ns:PowerTextState()) ~= "string" then error("the self-check lines should be text") end
    ns:ForgetPowerCall()
    env.UnitPower, env.UnitPowerMax, env.UnitPowerPercent, env.CurveConstants, env.AbbreviateNumbers = realP, realMax, realPct, realCurves, realAbbrev
end)
try("Options that must fit", function()
    -- the Layout tab: boss frames share a slider, action bars are not listed, and the page ends above the footer
    ns:ToggleConfig("layout")
    local page = ns.layoutPage
    if not page then error("the Layout tab did not build") end
    local listed = 0
    for _, m in ipairs(ns.movables) do if not m.noScale and not m.offPage then listed = listed + 1 end end
    if page.scaleSliders >= listed then error("frames sized together should share a slider (" .. page.scaleSliders .. " sliders for " .. listed .. " panels)") end
    if page.scaleSliders > 36 then error("too many scale sliders for the page: " .. page.scaleSliders) end
    -- however many panels there are, nothing runs into the footer: the tab is on a scrolling page that
    -- knows exactly how tall its contents are
    if not rawget(page, "area") then error("the Layout tab should be on a scrolling page") end
    if page.contentHeight < -page.bottom then error("the Layout tab's contents are taller than its page allows for") end
    -- (Layout is a whole page, not one section at a time: no list of sections, and all of it can be scrolled to)
    if rawget(page, "navList") or rawget(page, "banded") then error("the Layout tab should be a whole page, without a list of sections") end
    if page.area.most ~= math.max(0, page.contentHeight - 542) and rawget(page.area, "most") ~= nil then error("the Layout tab should scroll as far as its contents go") end
    ns:ToggleConfig()
    -- the Combat tab's switches: both of the number-or-percent choices are there
    ns:ToggleConfig("combat"); ns:ToggleConfig()
end)
try("Resource percentage on nameplates", function()
    local realP, realMax, realPct, realCurves, realHP, realHPMax = env.UnitPower, env.UnitPowerMax, env.UnitPowerPercent, env.CurveConstants, env.UnitHealth, env.UnitHealthMax
    local curve = {}
    env.CurveConstants = { ScaleTo100 = curve }
    env.UnitPowerPercent = function(_, _, _, c) if c == curve then return 25 end return 0.25 end
    env.UnitHealth = function() return 100 end; env.UnitHealthMax = function() return 100 end
    env.UnitPower = function() return 50 end
    local max = 200
    env.UnitPowerMax = function() return max end
    ns:ForgetPowerCall()
    ns.db.powerText, ns.db.plateHealth = true, true
    local plate, uf = newmock(), newmock()
    rawset(uf, "healthBar", newmock())
    local h = ns.PlateHealth(plate, uf, "nameplate1")
    local shown
    rawset(rawget(h, "power"), "SetText", function(_, s) shown = s end)
    rawset(rawget(h, "power"), "SetFormattedText", function(_, f, v) shown = "game:" .. tostring(v) end)
    ns:RefreshPlateHealth()
    if shown ~= "25%" then error("a unit with a resource should show its percentage, got " .. tostring(shown)) end
    -- a creature with no resource at all shows nothing, not 0%
    max = 0; ns.PlateHealth(plate, uf, "nameplate2")
    if shown ~= "" then error("a unit with no resource must be blank, got " .. tostring(shown)) end
    -- switched off
    max = 200; ns.PlateHealth(plate, uf, "nameplate3")
    ns.db.powerText = false; ns:RefreshPlateHealth()
    if shown ~= "" then error("switched off, the plate should carry no resource text") end
    ns.db.powerText = true
    if secretMode then
        -- seen before the fight, so known to have a resource: in combat the game writes it
        ns:RefreshPlateHealth()
        env.UnitPower = function() return SV(50) end
        env.UnitPowerMax = function() return SV(200) end
        ns:RefreshPlateHealth()
        if shown ~= "game:25" then error("a unit known to have a resource should keep showing it in combat, got " .. tostring(shown)) end
        -- a plate first seen with everything hidden: a creature of a kind that has no mana stays blank ...
        local realClass, realIsPlayer = env.UnitClass, env.UnitIsPlayer
        env.UnitIsPlayer = function() return false end
        env.UnitClass = function() return "Warrior", "WARRIOR" end
        ns.PlateHealth(plate, uf, "nameplate4")
        if shown ~= "" then error("a creature with no mana, first seen hidden, must be blank, got " .. tostring(shown)) end
        -- ... a spell-casting kind shows one, and so does any player
        env.UnitClass = function() return "Mage", "MAGE" end
        ns.PlateHealth(plate, uf, "nameplate5")
        if shown ~= "game:25" then error("a spell-casting creature should show its resource, got " .. tostring(shown)) end
        env.UnitClass = function() return "Warrior", "WARRIOR" end
        env.UnitIsPlayer = function() return true end
        ns.PlateHealth(plate, uf, "nameplate6")
        if shown ~= "game:25" then error("a player's plate should show a resource, got " .. tostring(shown)) end
        env.UnitClass, env.UnitIsPlayer = realClass, realIsPlayer
    end
    local r, g, b = ns:PowerTextColor("player")
    if not (r >= 0.45 and g >= 0.45 and b >= 0.45) then error("the resource color should be lightened enough to read") end
    ns:ForgetPowerCall()
    env.UnitPower, env.UnitPowerMax, env.UnitPowerPercent, env.CurveConstants, env.UnitHealth, env.UnitHealthMax = realP, realMax, realPct, realCurves, realHP, realHPMax
end)
try("Cooldown tracker states", function()
    if not ns.cooldownTest then error("the cooldown tracker did not start") end
    local realSpell, realTime = env.C_Spell, env.GetTime
    local clock = 500
    env.GetTime = function() return clock end
    local cds = {}                                         -- spell id -> what the game reports
    env.C_Spell = {
        GetSpellInfo = function(name) return { spellID = (name == "Slow") and 11 or 22, iconID = 1 } end,
        GetSpellCooldown = function(id) return cds[id] or { startTime = 0, duration = 0, isEnabled = true } end,
    }
    local keep = ns.db.cooldownSpells
    ns.db.cooldownSpells = { "Slow", "Quick" }
    if ns:RebuildCooldowns() ~= 2 then error("two abilities should make two icons") end
    local icons = ns.cooldownTest.active()
    local grey, swept, shown = {}, {}, {}
    for i, b in ipairs(icons) do
        rawset(rawget(b, "tex"), "SetDesaturated", function(_, v) grey[i] = v end)
        local cd = rawget(b, "cd")
        rawset(cd, "SetCooldown", function(_, s, d) swept[i] = { s, d } end)
        rawset(cd, "Clear", function() swept[i] = "cleared" end)
        rawset(cd, "Show", function() shown[i] = (shown[i] or 0) + 1 end)
    end
    local Refresh = ns.cooldownTest.Refresh
    Refresh()
    if grey[1] or grey[2] then error("nothing is on cooldown: no icon should be grey") end

    -- used: a 30-second cooldown. Grey, with a sweep.
    cds[11] = { startTime = 500, duration = 30, isEnabled = true }
    Refresh()
    if grey[1] ~= true or type(swept[1]) ~= "table" or swept[1][2] ~= 30 then error("an ability on cooldown should be grey with a sweep") end
    if grey[2] then error("the other ability should be untouched") end

    -- the fault that was reported: the cooldown finishes and the game says nothing. Time alone must clear it.
    clock = 531
    for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.25) end end
    if grey[1] ~= false then error("an icon stayed grey after its cooldown had finished") end
    if swept[1] ~= "cleared" then error("the sweep should be cleared once the cooldown is over") end

    -- only the global cooldown: not what this row is for
    clock = 600
    cds[61304] = { startTime = 600, duration = 1.5, isEnabled = true }
    cds[22] = { startTime = 600, duration = 1.5, isEnabled = true }
    Refresh()
    if grey[2] then error("the global cooldown alone must not grey an icon") end
    -- a slower global cooldown is still recognised, because it is compared with the game's own clock
    cds[61304] = { startTime = 600, duration = 2.4, isEnabled = true }
    cds[22] = { startTime = 600, duration = 2.4, isEnabled = true }
    Refresh()
    if grey[2] then error("a long global cooldown was mistaken for the ability's own") end
    cds[61304] = nil
    -- a cooldown that has not started counting (the ability is still in effect)
    cds[22] = { startTime = 600, duration = 60, isEnabled = false }
    Refresh()
    if grey[2] then error("a cooldown that has not started must not grey the icon") end
    -- an ability with charges stays lit while one is left
    env.C_Spell.GetSpellCharges = function(id) if id == 22 then return { currentCharges = 1, maxCharges = 2, cooldownStartTime = 600, cooldownDuration = 20 } end end
    cds[22] = { startTime = 600, duration = 20, isEnabled = true }
    Refresh()
    if grey[2] then error("an ability with a charge left should stay lit") end
    env.C_Spell.GetSpellCharges = function(id) if id == 22 then return { currentCharges = 0, maxCharges = 2, cooldownStartTime = 600, cooldownDuration = 20 } end end
    Refresh()
    if grey[2] ~= true then error("with no charges left it should be grey") end
    env.C_Spell.GetSpellCharges = nil

    -- numbers the game hides: the sweep is still handed over, the icon is not greyed, and a refusal
    -- does not put the sweep away for good
    cds[11] = { startTime = SV(600), duration = SV(30), isEnabled = true }
    if secretMode then
        Refresh()
        if grey[1] then error("with hidden numbers the icon must not be greyed on a guess") end
        if type(swept[1]) ~= "table" then error("with hidden numbers the sweep should still be handed to the game") end
    end
    rawset(rawget(icons[1], "cd"), "SetCooldown", function() error("refused") end)
    cds[11] = { startTime = 600, duration = 30, isEnabled = true }
    local before = shown[1] or 0
    Refresh(); Refresh()
    if (shown[1] or 0) <= before then error("after a refusal the sweep must still be shown next time") end
    if grey[1] ~= true then error("a refused sweep must not stop the icon being greyed") end

    env.C_Spell, env.GetTime = realSpell, realTime
    ns.db.cooldownSpells = keep
    ns:RebuildCooldowns()
end)
try("A tooltip for a unit the game keeps hidden", function()
    if type(ns.TooltipOnTip) ~= "function" then error("the tooltip module did not start") end
    -- the game refuses questions about a hidden unit, exactly as it did in the report
    local realIsPlayer, realExists, realClass = env.UnitIsPlayer, env.UnitExists, env.UnitClass
    local function refuse(unit)
        if ns:IsSecret(unit) then error("bad argument #1 (Secret values are only allowed during untainted execution for this argument.)") end
    end
    env.UnitIsPlayer = function(unit) refuse(unit); return true end
    env.UnitExists = function(unit) refuse(unit); return false end
    env.UnitClass = function(unit) refuse(unit); return "Shaman", "SHAMAN" end
    -- an ordinary unit still gets its class color
    if ns:ClassColor("player") ~= ns:ClassRGB("SHAMAN") then error("a player should get their class's color") end
    if ns:ClassColor(nil) ~= nil then error("no unit, no color") end
    if secretMode then
        local hidden = SV("mouseover")
        if ns:ClassColor(hidden) ~= nil then error("a hidden unit has no color to give") end
        local tip = newmock()
        rawset(tip, "GetUnit", function() return "Someone", hidden end)
        local ok, e = pcall(ns.TooltipOnTip, tip)
        if not ok then error("a tooltip for a hidden unit raised: " .. tostring(e)) end
    end
    -- a unit the game answers oddly about must not raise either
    env.UnitIsPlayer = function() error("refused") end
    if ns:ClassColor("target") ~= nil then error("a refused question should just mean no color") end
    env.UnitIsPlayer, env.UnitExists, env.UnitClass = realIsPlayer, realExists, realClass
end)
try("XP bar text", function()
    if type(ns.RefreshXPBar) ~= "function" then error("the XP bar module did not start") end
    local realXP, realMax, realBreak, realAtMax = env.UnitXP, env.UnitXPMax, env.BreakUpLargeNumbers, env.GetMaxPlayerLevel
    env.GetMaxPlayerLevel = function() return 60 end
    env.BreakUpLargeNumbers = false                        -- (plain digits, so the text can be compared)
    env.UnitXP = function() return 4520 end
    env.UnitXPMax = function() return 10000 end
    if ns.defaults.xpNumbers ~= false then error("the XP text should be a percentage unless chosen otherwise") end
    ns.db.xpNumbers = false; ns:RefreshXPBar()
    if ns.xpBarText ~= "45.2%" then error("as a percentage: expected 45.2%, got " .. tostring(ns.xpBarText)) end
    ns.db.xpNumbers = true; ns:RefreshXPBar()
    if ns.xpBarText ~= "4520 / 10000" then error("as amounts: expected 4520 / 10000, got " .. tostring(ns.xpBarText)) end
    -- the two ends of a level
    ns.db.xpNumbers = false
    env.UnitXP = function() return 0 end; ns:RefreshXPBar()
    if ns.xpBarText ~= "0.0%" then error("a fresh level should read 0.0%, got " .. tostring(ns.xpBarText)) end
    env.UnitXP = function() return 9999 end; ns:RefreshXPBar()
    if ns.xpBarText ~= "99.9%" then error("one point short of the level must not read 100%: got " .. tostring(ns.xpBarText)) end
    -- a client that hides the amounts: no text, and no error
    if secretMode then
        env.UnitXP = function() return SV(4520) end
        env.UnitXPMax = function() return SV(10000) end
        local before = #ns.errors
        ns:RefreshXPBar(); fireEvent("PLAYER_XP_UPDATE")
        if ns.xpBarText ~= "" then error("hidden amounts should leave the text empty, got " .. tostring(ns.xpBarText)) end
        if #ns.errors ~= before then error("hidden amounts raised: " .. tostring(ns.errors[#ns.errors])) end
    end
    env.UnitXP, env.UnitXPMax, env.BreakUpLargeNumbers, env.GetMaxPlayerLevel = realXP, realMax, realBreak, realAtMax
    ns.db.xpNumbers = false; ns:RefreshXPBar()
end)
try("What counts as a submenu", function()
    -- a menu: general layout functions that many frames share, plus functions only menus have
    local shared = { Layout = function() end, MarkDirty = function() end, MarkClean = function() end, IsDirty = function() end }
    local menuOnly = { OpenSubmenu = function() end, CloseSubmenu = function() end, AddButton = function() end,
                       SetMenuDescription = function() end, GetMenuAnchor = function() end, Close = function() end }
    local function frame(name, strata, withMenuParts)
        -- as in the game: the mixin's functions sit on the frame itself, the frame's own methods do not
        local methods = { GetName = function() return name end, GetFrameStrata = function() return strata end }
        local f = setmetatable({}, { __index = methods })
        for k, v in pairs(shared) do f[k] = v end
        if withMenuParts then for k, v in pairs(menuOnly) do f[k] = v end end
        return f
    end
    local root = frame(nil, "FULLSCREEN_DIALOG", true)
    local sig, n = ns.MenuSignature(root)
    if n < 10 then error("the signature should take in all of the menu's functions, got " .. n) end
    -- the fault that was reported: a named container on another layer that shares only the layout functions
    local container = frame("UIParentRightManagedFrameContainer", "MEDIUM", false)
    if ns.IsMenuFrame(container, sig, n, root) then error("a layout container was taken for a menu") end
    -- each difference is enough on its own
    if ns.IsMenuFrame(frame(nil, "FULLSCREEN_DIALOG", false), sig, n, root) then error("sharing a few layout functions is not enough") end
    if ns.IsMenuFrame(frame("SomeNamedFrame", "FULLSCREEN_DIALOG", true), sig, n, root) then error("a named frame is not a menu the game made on demand") end
    if ns.IsMenuFrame(frame(nil, "MEDIUM", true), sig, n, root) then error("a frame on another layer is not this menu's submenu") end
    -- a real submenu: anonymous, same layer, same parts
    if not ns.IsMenuFrame(frame(nil, "FULLSCREEN_DIALOG", true), sig, n, root) then error("a real submenu was not recognised") end
    -- a menu too bare to recognise anything by matches nothing
    local bare = { Layout = shared.Layout }
    local bs, bn = ns.MenuSignature(bare)
    if ns.IsMenuFrame(frame(nil, "FULLSCREEN_DIALOG", false), bs, bn, bare) then error("a signature of one function should match nothing") end
end)
try("Action button backing stays behind the icon", function()
    ns.StyleExtraButtons()                                 -- skins the stand-in button with the real skinning code
    local made = known.__actionButtonTextures
    local backing = 0
    for _, tx in ipairs(made) do
        if tx.layer == "BACKGROUND" then
            backing = backing + 1
            if tx.sub ~= -8 then
                error("a backing texture was put at depth " .. tostring(tx.sub) .. " of the background layer, where it can cover the icon")
            end
        end
    end
    if backing == 0 then error("the button was not given its backing") end
end)
try("Moving one of the game's frames", function()
    env.InCombatLockdown = function() return false end
    local function gameFrame()
        local f = newmock()
        local placed = {}
        rawset(f, "placed", placed)
        rawset(f, "GetNumPoints", function() return 1 end)
        rawset(f, "GetPoint", function() return "TOPRIGHT", env.UIParent, "TOPRIGHT", -200, -10 end)
        rawset(f, "SetPoint", function(_, point, rel, relPoint, x, y) placed[#placed + 1] = { point, rel, relPoint, x, y } end)
        rawset(f, "IsForbidden", function() return false end)
        return f, placed
    end
    -- the buff frame: pinned by the corner the game uses, so it keeps growing from the same end
    local buffs, placed = gameFrame()
    local info, entry = ns:AdoptGameFrame(buffs, "testBuffs", "Buffs", "note", true)
    if not info or not entry or not entry.onMoved or not entry.onReset or entry.noScale ~= "note" then error("the frame was not adopted properly") end
    if info.attached or #placed ~= 0 then error("a frame that has not been moved must be left exactly where the game put it") end
    ns.db.pos.testBuffs = { "CENTER", "CENTER", 120, 200 }
    entry.onMoved()
    local last = placed[#placed]
    if not info.attached or not last or last[1] ~= "TOPRIGHT" or last[2] ~= info.holder or last[3] ~= "TOPRIGHT" then
        error("a moved buff frame should be pinned to its handle by its own corner, got " .. tostring(last and last[1]))
    end
    -- Reset hands it back: the game's own anchor is restored and the saved place forgotten
    ns:ResetPanel("testBuffs")
    last = placed[#placed]
    if info.attached or ns.db.pos.testBuffs ~= nil then error("Reset should hand the frame back") end
    if last[1] ~= "TOPRIGHT" or last[2] ~= env.UIParent or last[4] ~= -200 or last[5] ~= -10 then error("Reset should restore the game's own anchor") end
    -- adopting the same frame twice gives the same handle, not a second one
    local again = ns:AdoptGameFrame(buffs, "testBuffs", "Buffs", "note", true)
    if again ~= info then error("the same frame was given a second handle") end
    -- an action bar: pinned by its centre, as before
    local bar, barPlaced = gameFrame()
    local barInfo, barEntry = ns:AdoptGameFrame(bar, "testBar", "Bar")
    ns.db.pos.testBar = { "CENTER", "CENTER", 0, -300 }
    barEntry.onMoved()
    if barPlaced[#barPlaced][1] ~= "CENTER" then error("a bar should be pinned by its centre") end
    ns:ResetPanel("testBar")
    -- a frame the game has locked away, or nothing at all, is not adopted
    local locked = setmetatable({}, { __index = function(_, k)
        if k == "IsForbidden" then return function() return true end end
        return function() error("forbidden") end
    end })
    if ns:AdoptGameFrame(locked, "testLocked", "X") ~= nil or ns:AdoptGameFrame(nil, "testNil", "X") ~= nil then error("an unusable frame must not be adopted") end
    -- in combat a move waits, and completes when the fight ends
    ns.db.pos.testBuffs = { "CENTER", "CENTER", 5, 5 }
    env.InCombatLockdown = function() return true end
    entry.onMoved()
    if info.attached or not info.pending then error("in combat the move must wait") end
    env.InCombatLockdown = function() return false end
    fireEvent("PLAYER_REGEN_ENABLED"); runTimers()
    if not info.attached then error("the move should complete when combat ends") end
    ns:ResetPanel("testBuffs")
end)
try("Reputation bar text", function()
    local realRep, realBreak = env.C_Reputation, env.BreakUpLargeNumbers
    env.BreakUpLargeNumbers = false                        -- (plain digits, so the text can be compared)
    local data = { name = "Stormwind", reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 5712 }
    env.C_Reputation = { GetWatchedFactionData = function() return data end }
    ns.db.xpNumbers = false; ns:RefreshXPBar()
    if ns.repBarText ~= "45.2%" then error("as a percentage: expected 45.2% (2712 of 6000), got " .. tostring(ns.repBarText)) end
    ns.db.xpNumbers = true; ns:RefreshXPBar()
    if ns.repBarText ~= "2712 / 6000" then error("as amounts: expected 2712 / 6000, got " .. tostring(ns.repBarText)) end
    ns.db.xpNumbers = false
    -- one point short of the next standing must not read 100%
    data.currentStanding = 8999; ns:RefreshXPBar()
    if ns.repBarText ~= "99.9%" then error("nearly there: got " .. tostring(ns.repBarText)) end
    -- no faction watched: no text
    data = nil; ns:RefreshXPBar()
    if ns.repBarText ~= "" then error("with no faction watched there should be no text, got " .. tostring(ns.repBarText)) end
    -- a client that hides the amounts: no text, and no error
    if secretMode then
        data = { name = "Stormwind", reaction = 5, currentReactionThreshold = SV(3000), nextReactionThreshold = SV(9000), currentStanding = SV(5712) }
        local before = #ns.errors
        ns:RefreshXPBar(); fireEvent("UPDATE_FACTION")
        if ns.repBarText ~= "" then error("hidden amounts should leave the text empty") end
        if #ns.errors ~= before then error("hidden amounts raised: " .. tostring(ns.errors[#ns.errors])) end
    end
    env.C_Reputation, env.BreakUpLargeNumbers = realRep, realBreak
    ns:RefreshXPBar()
end)
try("No box round an empty buff slot", function()
    if type(ns.StyleGameAura) ~= "function" then error("the buff button styling is missing") end
    -- a stand-in for one of the game's buff buttons, whose icon can be filled and emptied
    local function button(texture, shown, alpha)
        local icon = newmock()
        local state = { texture = texture, shown = shown, alpha = alpha }
        rawset(icon, "GetTexture", function() return state.texture end)
        rawset(icon, "IsShown", function() return state.shown end)
        rawset(icon, "GetAlpha", function() return state.alpha end)
        local b = newmock()
        rawset(b, "Icon", icon)
        return b, state
    end
    local function boxed(b)                                -- is our border showing? (both of its lines)
        local border = rawget(b, "suiBorder")
        if not border then error("the button was given no border at all") end
        local seen = { border = true, outer = true }
        rawset(border, "Show", function() seen.border = true end)
        rawset(border, "Hide", function() seen.border = false end)
        local outer = rawget(border, "outer")
        if not outer then error("the border's outer line cannot be reached") end
        rawset(outer, "Show", function() seen.outer = true end)
        rawset(outer, "Hide", function() seen.outer = false end)
        rawset(b, "suiBoxed", nil)                         -- look afresh
        ns.StyleGameAura(b)
        if seen.border ~= seen.outer then error("the two lines of the border disagree") end
        return seen.border
    end
    -- the fault that was reported: a button with nothing in it must not get a box
    local empty = button(nil, true, 1)
    ns.StyleGameAura(empty)
    if boxed(empty) then error("an empty slot was given a box") end
    -- a real debuff gets one
    local full, state = button(136243, true, 1)
    ns.StyleGameAura(full)
    if not boxed(full) then error("a debuff with an icon should have its border") end
    -- and loses it when the debuff ends, and gets it back when another arrives
    state.texture = nil;    if boxed(full) then error("the border should go when the icon goes") end
    state.texture = 136243; if not boxed(full) then error("the border should return with the next icon") end
    state.shown = false;    if boxed(full) then error("a hidden icon is an empty slot") end
    state.shown = true; state.alpha = 0
    if boxed(full) then error("an invisible icon is an empty slot") end
    state.alpha = 1
    -- an icon the game will not name is still an icon
    if secretMode then
        state.texture = SV(136243)
        if not boxed(full) then error("an icon the game keeps hidden should still be boxed") end
    end
end)
try("No box for an empty totem slot", function()
    local T = ns.totemTest
    if not T then error("the totem timers did not start") end
    local realInfo = env.GetTotemInfo
    env.InCombatLockdown = function() return false end
    if ns.previewing then ns:TogglePreview() end            -- (sample totems would stand in for the real ones)
    -- watch the first slot: is it showing, and does it have its box?
    local b = T.icons[1]
    local seen = { shown = false, box = true }
    rawset(b, "Show", function() seen.shown = true end)
    rawset(b, "Hide", function() seen.shown = false end)
    local border = rawget(b, "suiBorder")
    if not border or not rawget(border, "outer") then error("a totem slot has no border to manage") end
    rawset(border, "Show", function() seen.box = true end)
    rawset(border, "Hide", function() seen.box = false end)
    local slot1
    env.GetTotemInfo = function(slot)
        if slot == 1 then return table.unpack(slot1, 1, 5) end
        return false, "", 0, 0, nil
    end
    local function now(info) slot1 = info; rawset(b, "suiBoxed", nil); T.Update() end

    -- everything readable: a standing totem shows in its box; an empty slot does not show
    now({ true, "Searing Totem", 100, 60, 135825 })
    if not seen.shown or not seen.box then error("a standing totem should show in its box") end
    now({ true, "", 0, 0, nil })
    if seen.shown then error("an empty slot should not show") end

    if secretMode then
        -- the fault that was reported: you own the totem, its time is hidden, and nothing is standing.
        -- The slot used to be shown regardless, as a hollow box.
        now({ true, "", SV(0), SV(0), nil })
        if seen.shown then error("an empty slot was drawn as a hollow box") end
        -- time hidden but a totem standing (it has an icon): shown, in its box
        now({ true, "Searing Totem", SV(100), SV(60), 135825 })
        if not seen.shown or not seen.box then error("a standing totem with a hidden time should still show in its box") end
        -- the icon hidden too, but the name readable: an empty name is an empty slot
        now({ true, "", SV(0), SV(0), SV(0) })
        if seen.shown then error("an empty slot (no name) was drawn") end
        now({ true, "Searing Totem", SV(100), SV(60), SV(135825) })
        if not seen.shown or not seen.box then error("a named totem should show in its box") end
        -- nothing readable at all: drawn, but without a box, so an empty slot shows nothing
        now({ SV(true), SV(""), SV(0), SV(0), SV(0) })
        if not seen.shown then error("with everything hidden the slot should still be handed to the game to draw") end
        if seen.box then error("with everything hidden the slot must not have a box") end
    end
    env.GetTotemInfo = realInfo
    T.Update()
end)
try("No boxes on the game's debuff row", function()
    -- a debuff button, with an icon the game shows and hides in a way we cannot see (as on this client)
    local function button()
        local icon = newmock()
        rawset(icon, "GetTexture", function() return 136243 end)
        rawset(icon, "IsShown", function() return true end)
        rawset(icon, "GetAlpha", function() return SV(0) end)
        local b = newmock()
        rawset(b, "Icon", icon)
        return b
    end
    -- the fault that was reported: such a button must get no box of ours at all
    local debuff = button()
    ns.StyleGameAura(debuff, true)
    if rawget(debuff, "suiBorder") then error("a debuff button was given a box") end
    ns.StyleGameAura(debuff, true)                         -- (and not on a later look either)
    if rawget(debuff, "suiBorder") then error("a debuff button was given a box on the second look") end
    -- a button boxed by an earlier version in the same session has its box taken down, both lines
    local old = button()
    ns.StyleGameAura(old)                                  -- as a buff: gets a border
    local border = rawget(old, "suiBorder")
    if not border then error("a buff button should have a border") end
    local hidden = { border = false, outer = false }
    rawset(border, "Hide", function() hidden.border = true end)
    rawset(rawget(border, "outer"), "Hide", function() hidden.outer = true end)
    rawset(old, "suiBoxed", true)
    ns.StyleGameAura(old, true)
    if not (hidden.border and hidden.outer) then error("an existing box on a debuff button should be taken down") end
    -- buffs are unchanged: still boxed
    local buff = button()
    ns.StyleGameAura(buff)
    if not rawget(buff, "suiBorder") then error("buffs should keep their border") end
end)
try("A scrolling area", function()
    local area, sheet = ns:ScrollArea(newmock(), 400, 100)
    if not area or not sheet or rawget(sheet, "area") ~= area then error("no scrolling area was made") end
    -- nothing to scroll to: it stays at the top
    area:SetContentHeight(60)
    if area.most ~= 0 or area.offset ~= 0 then error("contents that fit should not scroll") end
    area:Scroll(500); if area.offset ~= 0 then error("contents that fit must not move") end
    -- three times as tall as the area: 200 to scroll through, and no further in either direction
    area:SetContentHeight(300)
    if area.most ~= 200 then error("expected 200 of scrolling room, got " .. tostring(area.most)) end
    area:Scroll(50);    if area.offset ~= 50 then error("scrolling down by 50 should move 50") end
    area:ScrollTo(999); if area.offset ~= 200 then error("it scrolled past the end") end
    area:ScrollTo(-40); if area.offset ~= 0 then error("it scrolled above the top") end
    -- bringing a piece into view moves only as far as needed
    area:ScrollToShow(250, 24); if area.offset ~= 174 then error("a piece near the bottom should be brought just into view, offset " .. area.offset) end
    area:ScrollToShow(200, 24); if area.offset ~= 174 then error("a piece already in view should not move anything") end
    area:ScrollToShow(30, 24);  if area.offset ~= 30 then error("a piece above should be brought to the top") end
    -- if the contents shrink, the position is pulled back inside them
    area:ScrollTo(200); area:SetContentHeight(150)
    if area.offset ~= 50 then error("after the contents shrank the position should be pulled back, offset " .. area.offset) end
end)
try("Every theme and lettering style can be reached", function()
    -- the Look tab: a button for every built-in theme and every lettering style, and a page that scrolls
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
    ns:ToggleConfig("look")
    local page = ns.lookPage
    local shown = 0
    for _, fam in ipairs({ "GLASS", "FANTASY", "CELESTIAL" }) do
        page.themePicker.family = fam; page.themePicker.Draw()
        for _, k in ipairs(page.themePicker.list) do if ns.themes[k] and not ns.themes[k].custom then shown = shown + 1 end end
    end
    if shown ~= #ns.themeOrder then error("the Look tab shows " .. shown .. " of " .. #ns.themeOrder .. " themes") end
    local fonts = 0
    for key in pairs(page.fontButtons) do if ns.fontStyles[key] then fonts = fonts + 1 end end
    if fonts ~= #ns.fontOrder then error("the Look tab shows " .. fonts .. " of " .. #ns.fontOrder .. " lettering styles") end
    if not rawget(page, "area") then error("the Look tab should be on a scrolling page") end
    if page.contentHeight <= 542 then error("with this many choices the Look tab should need to scroll") end
do   -- (the sections show slices of the page: each starts at a heading, and the last reaches its foot)
        local O = ns.optUI
        for _, from in ipairs({ "Glass", "Accent", "Make your own theme", "Theme by place", "Frame style", "Class colors", "Contrast and text size" }) do
            if not O.Band(page, from) then error("the Look page has no " .. from) end
        end
        local top = O.Band(page, "Glass", "Your themes")
        if top ~= 0 then error("the themes start at the top") end
        local at, ah = O.Band(page, "Contrast and text size")
        if at + ah ~= page.contentHeight then error("the last slice should reach the foot of the page") end
        local ct, ch = O.Band(page, "Class colors")
        if ch < 36 + #ns.classOrder * 24 then error("Class colors should be tall enough for every class: " .. ch) end
    end
    -- the themes' slice runs from the top down to the heading under it
    local _, hh = ns.optUI.Band(page, "Glass", "Your themes")
    if hh < 420 then error("the themes' slice should hold the grid, got " .. tostring(hh)) end
    ns:ToggleConfig()
    -- the setup: both grids hold everything too
    ns:ShowSetup()
    local look = ns.setupLookPage
    if not look then error("the setup's look step did not build") end
    for _, family in ipairs({ "GLASS", "FANTASY", "CELESTIAL" }) do
        look.SetFamily(family)
        local want = 0
        for _, key in ipairs(ns.themeOrder) do
            local t = ns.themes[key]
            local fam = (t.style == "GLASS") and "GLASS" or (t.style == "CELESTIAL") and "CELESTIAL" or "FANTASY"
            if not t.custom and fam == family then want = want + 1 end
        end
        if look.themeCount ~= want then error("the setup shows " .. tostring(look.themeCount) .. " of " .. want .. " " .. family .. " themes") end
        if look.themeGrid.most <= 0 then error("the setup's theme grid should scroll for " .. family) end
        if not (look.themeButtons[1] and look.themeButtons[1].swatch) then error("the setup's theme buttons show a picture") end
    end
    -- picking a theme far down the list works like any other
    look.Pick("ROSEWOOD")
    if ns.db.theme ~= "ROSEWOOD" then error("a theme at the end of the list could not be picked") end
    ns.db.theme, ns.db.accent = "SMOKE", "AZURE"; ns:Retheme()
    if ns.HideSetup then ns:HideSetup() end
end)
try("New themes are complete and readable", function()
    local function lum(c)
        local function ch(v) if v <= 0.03928 then return v / 12.92 end return ((v + 0.055) / 1.055) ^ 2.4 end
        return 0.2126 * ch(c[1]) + 0.7152 * ch(c[2]) + 0.0722 * ch(c[3])
    end
    local function ratio(a, b)
        local la, lb = lum(a), lum(b)
        return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
    end
    local names = {}
    for _, key in ipairs(ns.themeOrder) do
        local t = ns.themes[key]
        if not t then error("theme " .. key .. " is listed but not defined") end
        if names[t.name] then error("two themes are both named " .. t.name) end
        names[t.name] = true
        if t.accent ~= "CLASS" then                        -- (the two class themes are filled in at login)
            for _, part in ipairs({ "bg", "border", "rim", "grain", "light", "plate", "text", "dim", "faint", "btn" }) do
                if type(t[part]) ~= "table" or type(t[part][1]) ~= "number" then error(key .. " has no " .. part) end
            end
            if not ns.accents[t.accent] then error(key .. " names an accent that does not exist: " .. tostring(t.accent)) end
            if ratio(t.text, t.bg) < 12 then error(key .. ": main text is too faint against its panel") end
            if ratio(t.dim, t.bg) < 7 then error(key .. ": secondary text is too faint") end
            if ratio(t.faint, t.bg) < 4.5 then error(key .. ": hint text is too faint") end
            if ratio(t.btn, t.plate) < 7 then error(key .. ": button text is too faint against its button") end
        end
    end
end)
try("Helpers start switched off", function()
    for _, key in ipairs({ "autoInvite", "fastLoot", "deleteFill", "skipCinematics" }) do
        if ns.defaults[key] ~= false then error(key .. " acts for you, so it must start switched off") end
        if ns:PresetValue("EVERYTHING", key) ~= nil or ns:PresetValue("STANDARD", key) ~= nil then error("a preset must never switch " .. key) end
        if type(ns.featureDesc[key]) ~= "string" then error(key .. " has no description") end
    end
    if ns:PresetValue("EVERYTHING", "bagCombatUse") ~= nil then error("a preset must never switch the experimental bag option") end
    -- every switch has a place in the settings, once, and every section's rows fit
    ns:ToggleConfig("home")
    local page = ns.featuresPage
    if not page or not rawget(page, "area") then error("the sections should be on a scrolling page") end
    local placed = {}
    for _, cat in ipairs(ns.settingsCategories) do
        for _, sec in ipairs(cat.sections or {}) do
            for _, key in ipairs(sec.keys) do
                if placed[key] then error(key .. " is in two sections") end
                placed[key] = sec
            end
        end
    end
    for _, group in ipairs(ns.featureGroups) do
        for _, opt in ipairs(group[2]) do
            local key = opt[1]
            if not placed[key] and key ~= "themeByPlace" then error(key .. " was not given a place") end
            if not page.boxes[key] and not ns:FeatureHidden(key) and key ~= "themeByPlace" then error(key .. " has no switch") end
        end
    end
    for name in pairs(ns.settingRows) do
        if name ~= "fontScale" and not ns:SectionOfRow(name) then error("the setting " .. name .. " is in no section") end
    end
    for _, cat in ipairs(ns.settingsCategories) do
        for _, sec in ipairs(cat.sections or {}) do
            for _, name in ipairs(sec.rows) do
                if not ns.settingRows[name] and not ns.featureLabels[name] then error(sec.id .. " lists " .. name .. ", which is no setting") end
            end
        end
    end
    ns:ToggleConfig()
end)
try("Who counts as someone you know", function()
    local realFriends, realGuild, realBN = env.C_FriendList, env.IsGuildMember, env.C_BattleNet
    env.C_BattleNet = { GetAccountInfoByGUID = function(guid) return { isFriend = (guid == "Player-9") } end }
    env.C_FriendList = {
        IsFriend = function(guid) return guid == "Player-1" end,
        GetNumFriends = function() return 2 end,
        GetFriendInfoByIndex = function(i) return { name = (i == 1) and "Thrall" or "Jaina-Stormrage" } end,
    }
    env.IsGuildMember = function(guid) return guid == "Player-2" end
    local realNum, realRoster = env.GetNumGuildMembers, env.GetGuildRosterInfo
    env.GetNumGuildMembers = function() return 1 end
    env.GetGuildRosterInfo = function() return "Varian-Stormrage" end
    if ns:IsKnownPerson("Whoever", "Player-1") ~= "friend" then error("a friend by id should be known") end
    if ns:IsKnownPerson("Whoever", "Player-2") ~= "guildmate" then error("a guildmate by id should be known") end
    if ns:IsKnownPerson("Whoever", "Player-9") ~= "Battle.net friend" then error("a Battle.net friend should be known") end
    -- by name when the game gives no id, with or without the realm on either side
    if ns:IsKnownPerson("Thrall", nil) ~= "friend" or ns:IsKnownPerson("Thrall-Stormrage", nil) ~= "friend" then error("a friend by name should be known") end
    if ns:IsKnownPerson("Jaina", nil) ~= "friend" then error("a friend listed with a realm should match the bare name") end
    if ns:IsKnownPerson("Varian", nil) ~= "guildmate" then error("a guildmate by name should be known") end
    -- a stranger is never accepted, whatever is or isn't known about them
    if ns:IsKnownPerson("Stranger", "Player-77") ~= nil then error("a stranger must not count as known") end
    if ns:IsKnownPerson("Stranger", nil) ~= nil or ns:IsKnownPerson(nil, nil) ~= nil or ns:IsKnownPerson("", "") ~= nil then error("an unknown name must not count as known") end
    if ns:IsKnownPerson("Thr", nil) ~= nil then error("part of a friend's name is not that friend") end
    env.C_FriendList, env.IsGuildMember, env.C_BattleNet, env.GetNumGuildMembers, env.GetGuildRosterInfo = realFriends, realGuild, realBN, realNum, realRoster
end)
try("Map coordinates and the BoE tag", function()
    local t = ns.MapCoordsText(0.409, 0.603, 0.521, 0.330)
    if t ~= "You  40.9, 60.3      Cursor  52.1, 33.0" then error("unexpected coordinates text: " .. t) end
    if ns.MapCoordsText(nil, nil, 0.5, 0.5) ~= "Cursor  50.0, 50.0" then error("viewing another zone: only the cursor should show") end
    if ns.MapCoordsText(0.1, 0.2, nil, nil) ~= "You  10.0, 20.0" then error("mouse off the map: only you should show") end
    if ns.MapCoordsText(0.1, 0.2, 1.4, 0.5) ~= "You  10.0, 20.0" then error("a cursor outside the map must not be shown") end
    if ns.MapCoordsText(nil, nil, nil, nil) ~= "" then error("nothing known: nothing shown") end
    -- "BoE": gear that binds when equipped and is not bound yet
    local realInfo = ns.GetItemInfo
    local bindType = 2
    ns.GetItemInfo = function() return "Sword", "link", 2, 20, 15, "Weapon", "Sword", 1, "INVTYPE_WEAPON", 1, 100, 2, 7, bindType end
    ns.db.bagBoE = true
    if ns:BindTag({ hyperlink = "item:1", isBound = false }) ~= "BoE" then error("unbound bind-on-equip gear should be tagged") end
    if ns:BindTag({ hyperlink = "item:1", isBound = true }) ~= "" then error("gear already bound to you must not be tagged") end
    bindType = 1
    if ns:BindTag({ hyperlink = "item:1", isBound = false }) ~= "" then error("bind-on-pickup gear must not be tagged") end
    bindType = 2
    if ns:BindTag(nil) ~= "" or ns:BindTag({}) ~= "" then error("an empty slot has no tag") end
    ns.db.bagBoE = false
    if ns:BindTag({ hyperlink = "item:1", isBound = false }) ~= "" then error("switched off, there should be no tag") end
    ns.db.bagBoE = true
    ns.GetItemInfo = realInfo
end)
try("Cutscenes, looting and the DELETE box", function()
    -- a cutscene plays the first time and is skipped after that
    if type(ns.SceneShouldSkip) == "function" then
        ns.root.seenScenes = nil
        local realCtrl = env.IsControlKeyDown
        env.IsControlKeyDown = function() return false end
        if ns.SceneShouldSkip("film:7") then error("a cutscene never seen must be allowed to play") end
        if not ns.SceneShouldSkip("film:7") then error("a cutscene seen once should be skipped the next time") end
        if ns.SceneShouldSkip("film:8") then error("a different cutscene has not been seen") end
        if ns.SceneShouldSkip(nil) then error("a cutscene that can't be told apart must be allowed to play") end
        env.IsControlKeyDown = function() return true end
        if ns.SceneShouldSkip("film:7") then error("holding Ctrl should let a seen cutscene play again") end
        env.IsControlKeyDown = realCtrl
        ns.root.seenScenes = nil
    end
    -- the DELETE box is filled only for the two "destroy a good item" questions
    if type(ns.FillDeleteBox) == "function" then
        local typed
        local box = newmock(); rawset(box, "SetText", function(_, s) typed = s end)
        local popup = newmock(); rawset(popup, "which", "DELETE_GOOD_ITEM"); rawset(popup, "GetEditBox", function() return box end)
        local realPopup, realWord = env.StaticPopup1, env.DELETE_ITEM_CONFIRM_STRING
        env.StaticPopup1, env.DELETE_ITEM_CONFIRM_STRING = popup, "DELETE"
        if not ns.FillDeleteBox("DELETE_GOOD_ITEM") or typed ~= "DELETE" then error("the box should be filled with the game's word") end
        typed = nil
        if ns.FillDeleteBox("CONFIRM_SOMETHING_ELSE") or typed ~= nil then error("no other question's box may be touched") end
        env.StaticPopup1, env.DELETE_ITEM_CONFIRM_STRING = realPopup, realWord
    end
end)
try("Nameplate size", function()
    if not ns.plateSizeSupport then return end             -- (a client without the settings has no sliders)
    local set = {}
    local realC = env.C_CVar
    env.C_CVar = { SetCVar = function(name, value) set[name] = value end, GetCVar = function() return "1" end }
    env.InCombatLockdown = function() return false end
    -- the game's own sizes are left alone until a slider is moved
    ns.db.plateSized, ns.db.plateW, ns.db.plateH = nil, 100, 100
    ns:ApplyNameplateSize()
    if next(set) then error("the game's nameplate sizes were changed without being asked") end
    ns.db.plateW, ns.db.plateH = 140, 200
    ns:NameplateSizeChanged()
    if set.NamePlateHorizontalScale ~= "1.4" or set.NamePlateVerticalScale ~= "2.0" and set.NamePlateVerticalScale ~= "2" then
        error("expected width 1.4 and height 2, got " .. tostring(set.NamePlateHorizontalScale) .. " and " .. tostring(set.NamePlateVerticalScale))
    end
    -- in combat the change waits, and is made when the fight ends
    set = {}
    env.InCombatLockdown = function() return true end
    ns.db.plateW = 80; ns:NameplateSizeChanged()
    if next(set) then error("nameplate size must not be changed during combat") end
    env.InCombatLockdown = function() return false end
    fireEvent("PLAYER_REGEN_ENABLED")
    if set.NamePlateHorizontalScale ~= "0.8" then error("the waiting change should be made when combat ends") end
    ns.db.plateSized, ns.db.plateW, ns.db.plateH = nil, 100, 100
    env.C_CVar = realC
end)
try("Safe mode", function()
    local base = reloadCount         -- (the game's own ReloadUI stays in place: the banner's button is built with it)
    ns.root.safeMode = nil
    if not ns:SetSafeMode(true) or ns.root.safeMode ~= true then error("safe mode should be switched on and kept") end
    if ns:SetSafeMode(true) then error("switching it on twice is not a change") end
    if not ns:SetSafeMode(false) or ns.root.safeMode ~= nil then error("safe mode should be switched off again") end
    -- the command goes in, and comes back out
    ns.safeMode = nil
    env.SlashCmdList.FANTASYGLASSUI("safe")
    if ns.root.safeMode ~= true or reloadCount - base ~= 1 then error("/fgui safe should switch safe mode on and reload") end
    -- logging in while it is on: nothing is started, and the banner is put up
    local before = {}
    for k, v in pairs(ns.loaded) do before[k] = v end
    for k in pairs(ns.loaded) do ns.loaded[k] = nil end
    fireEvent("PLAYER_LOGIN"); runTimers()
    if not ns.safeMode then error("logging in with safe mode on should put the add-on in safe mode") end
    if next(ns.loaded) then error("in safe mode no feature may be started") end
    if not ns.safeBanner then error("safe mode should say so on screen") end
    env.SlashCmdList.FANTASYGLASSUI("safe")
    if ns.root.safeMode ~= nil or reloadCount - base ~= 2 then error("/fgui safe again should leave safe mode and reload") end
    ns.safeMode = nil
    for k, v in pairs(before) do ns.loaded[k] = v end
end)
try("Group finder", function()
    local g = known.__lfg
    local function gone(x) return rawget(x, "__alpha")[1] == 0 end
    -- the shell: its own art and the eye go; each page is treated as a window of its own
    if not gone(g.shellArt) then error("the shell's own art should be hidden") end
    if not gone(g.eye) then error("the eye in the portrait corner should be hidden") end
    if not rawget(g.page, "suiWindow") or not rawget(g.page, "suiPainted") then error("the page showing should get the standard window treatment and a panel") end
    if not rawget(g.hiddenPage, "suiWindow") then error("every page should be made ready, whether or not it is showing") end
    if not gone(rawget(g.page, "Bg")) or not gone(rawget(g.page, "BackgroundArt")) or not gone(g.loose) then error("a page's own art should be hidden") end
    -- the pieces on the page that is showing
    if not rawget(g.tab, "suiTab") then error("a side tab was not restyled") end
    if not rawget(g.dropdown, "suiPolish") or not rawget(rawget(g.dropdown, "Background"), "suiTinted") then error("a dropdown was not restyled") end
    if not rawget(g.tick, "suiBoxDone") then error("a role's tick box was not restyled") end
    if not rawget(g.category, "suiPolish") or not rawget(g.category, "suiBorder") then error("a category button was not given its border") end
    if not rawget(g.comment, "suiPolish") or not gone(rawget(g.comment, "TopLeftTex")) then error("the comment box's art should be hidden") end
    if not rawget(g.inset, "suiPolish") or not gone(rawget(g.inset, "Border")) then error("an inset's ornate border should be hidden") end
    -- pieces on a page that is not showing wait until it is opened
    if rawget(g.hiddenDropdown, "suiPolish") then error("a hidden page's controls should wait until that page is opened") end
end)
try("When a panel shows", function()
    local combat, target = false, false
    env.InCombatLockdown = function() return combat end
    local realCombat, realExists = env.UnitAffectingCombat, env.UnitExists
    env.UnitAffectingCombat = function() return combat end
    env.UnitExists = function(unit) if unit == "target" then return target end return true end
    ns.db.panelShow = {}
    if ns.moving then ns:ToggleMove() end
    if ns.previewing then ns:TogglePreview(true) end
    -- two panels of our own: one ordinary, one the game protects (as the unit frames are)
    local function panel(key, protected)
        local f = newmock()
        local state = { shown = true, alpha = 1 }
        rawset(f, "Show", function() state.shown = true end)
        rawset(f, "Hide", function() state.shown = false end)
        rawset(f, "IsShown", function() return state.shown end)
        rawset(f, "SetAlpha", function(_, a) state.alpha = a end)
        rawset(f, "IsProtected", function() return protected end)
        ns:RegisterMovable(f, key, key)
        return state
    end
    local plain, secure = panel("testPlain", false), panel("testSecure", true)
    -- the rules themselves
    if not ns.RuleWants("ALWAYS", false, false) or ns.RuleWants("COMBAT", false, true) or not ns.RuleWants("COMBAT", true, false) then error("the combat rule is wrong") end
    if ns.RuleWants("NOCOMBAT", true, true) or not ns.RuleWants("NOCOMBAT", false, false) then error("the out-of-combat rule is wrong") end
    if ns.RuleWants("TARGET", true, false) or not ns.RuleWants("TARGET", false, true) then error("the target rule is wrong") end
    -- with no rule, nothing is touched
    ns:PanelShowTick()
    if not plain.shown or secure.alpha ~= 1 then error("a panel with no rule must be left alone") end
    -- only in combat: an ordinary panel is really hidden, a protected one is made see-through
    ns:SetPanelShow({ "testPlain", "testSecure" }, "COMBAT")
    if plain.shown then error("out of combat, a combat-only panel should be hidden") end
    if secure.alpha ~= 0 or not secure.shown then error("a protected panel must be made see-through, never hidden") end
    combat = true; ns:PanelShowTick()
    if not plain.shown or secure.alpha ~= 1 then error("in combat, combat-only panels should be back") end
    combat = false; ns:PanelShowTick()
    if plain.shown or secure.alpha ~= 0 then error("after the fight they should go again") end
    -- something else raising it is put down again at the next look
    plain.shown = true; secure.alpha = 1; ns:PanelShowTick()
    if plain.shown or secure.alpha ~= 0 then error("a panel raised by its own feature should be put down again") end
    -- while panels are being moved, everything shows
    ns:ToggleMove(); ns:PanelShowTick()
    if not plain.shown or secure.alpha ~= 1 then error("everything should show while panels are being moved") end
    ns:ToggleMove(); ns:PanelShowTick()
    if plain.shown then error("leaving move mode should apply the rules again") end
    -- only with a target
    ns:SetPanelShow("testPlain", "TARGET")
    if plain.shown then error("with no target a target-only panel should be hidden") end
    target = true; ns:PanelShowTick()
    if not plain.shown then error("with a target it should show") end
    -- Reset gives a panel back its place and its "always"
    ns:ResetPanel("testSecure"); ns:PanelShowTick()
    if ns:PanelShowRule("testSecure") ~= "ALWAYS" or secure.alpha ~= 1 then error("Reset should return a panel to showing always") end
    ns:SetPanelShow("testPlain", "ALWAYS")
    if ns.db.panelShow.testPlain ~= nil or not plain.shown then error("\"always\" should clear the rule") end
    if ns:PanelShowRule("nonsense") ~= "ALWAYS" then error("an unknown panel shows always") end
    -- the game's own frames (action bars, buffs) are not offered the choice and are never touched
    for _, m in ipairs(ns.movables) do
        if m.adopted then
            ns.db.panelShow[m.key] = "COMBAT"
            local hidden = false
            rawset(m.frame, "Hide", function() hidden = true end)
            ns:PanelShowTick()
            if hidden or m.ruleHidden then error("one of the game's own frames was hidden by a rule") end
            ns.db.panelShow[m.key] = nil
            break
        end
    end
    env.UnitAffectingCombat, env.UnitExists = realCombat, realExists
    env.InCombatLockdown = function() return false end
    ns.db.panelShow = {}
end)
try("Update notice", function()
    if not ns:IsNewerVersion("8.7.1", "8.7.0") or not ns:IsNewerVersion("8.8.0", "8.7.9") or not ns:IsNewerVersion("9.0.0", "8.9.9") then error("a newer version was not recognised") end
    if not ns:IsNewerVersion("8.4.10", "8.4.9") then error("8.4.10 is newer than 8.4.9: versions are numbers, not text") end
    if ns:IsNewerVersion("8.7.0", "8.7.0") or ns:IsNewerVersion("8.6.9", "8.7.0") then error("the same or an older version is not newer") end
    if ns:IsNewerVersion("nonsense", "8.7.0") or ns:IsNewerVersion("8.7", "8.7.0") or ns:IsNewerVersion(nil, "8.7.0") then error("something that is not a version is not newer") end
    if ns:IsNewerVersion("99.0.0", "8.7.0") then error("an unbelievable version should be ignored") end
    if type(ns.HeardVersion) ~= "function" then return end           -- (a client with no add-on messages)
    local keepTold, keepSeen, keepVersion = ns.root.toldVersion, ns.newestSeen, ns.version
    ns.root.toldVersion, ns.newestSeen, ns.version = nil, nil, "8.7.0"
    local said = 0
    local realPrint = ns.PrintRaw
    ns.PrintRaw = function() said = said + 1 end
    if not ns:HeardVersion("V:8.7.2", "Friend") or said ~= 1 then error("a newer version heard for the first time should be announced") end
    if ns:HeardVersion("V:8.7.2", "Someone") or ns:HeardVersion("V:8.7.1", "Other") or said ~= 1 then error("the same or an older one must not be announced again") end
    if not ns:HeardVersion("V:8.8.0", "Friend") or said ~= 2 or ns.newestSeen ~= "8.8.0" then error("a newer one still should be announced") end
    if ns:HeardVersion("V:8.6.0", "Friend") or ns:HeardVersion("hello", "Friend") or ns:HeardVersion("V:8.9.0 and more", "Friend") or said ~= 2 then error("older versions and other messages must be ignored") end
    ns.PrintRaw = realPrint
    ns.root.toldVersion, ns.newestSeen, ns.version = keepTold, keepSeen, keepVersion
end)
try("Searching the options", function()
    ns:ToggleConfig("features")
    local frame = ns.configFrame
    if type(frame) ~= "table" or type(frame.SearchOptions) ~= "function" then error("the options window has no search") end
    if #ns.optionIndex < 150 then error("too few settings were noted for searching: " .. #ns.optionIndex) end
    local function find(query, tab, part)
        for _, hit in ipairs(ns:SearchOptions(query, 20)) do
            if hit.tab == tab and hit.label:lower():find(part, 1, true) then return hit end
        end
    end
    -- settings on different pages are all found from the one box
    if not find("boss", "sections", "boss frames") then error("a feature's switch was not found") end
    if not find("high contrast", "look", "high contrast") then error("a heading on the Look page was not found") end
    if not find("reduce motion", "sections", "reduce motion") then error("an accessibility switch was not found") end
    if not find("interface size", "sections", "interface size") then error("a slider of a section was not found") end
    if not find("rosewood", "look", "rosewood") then error("a theme on the Look tab was not found") end
    if not find("calligraphy", "look", "calligraphy") then error("a lettering style on the Look tab was not found") end
    -- a word from a switch's description finds it too
    if not find("guildmate", "sections", "accept invites") then error("a switch should be found by a word from its description") end
    -- nothing for nothing, or for one letter, or for nonsense
    if #ns:SearchOptions("") ~= 0 or #ns:SearchOptions("a") ~= 0 or #ns:SearchOptions("qqqqzz") ~= 0 or #ns:SearchOptions(nil) ~= 0 then error("an empty or meaningless search should find nothing") end
    if #ns:SearchOptions("e", 5) > 5 or #ns:SearchOptions("bar", 5) > 5 then error("the number of results should be capped") end
    -- labels that start with what was typed come first
    local hits = ns:SearchOptions("health", 10)
    if #hits == 0 or hits[1].label:lower():find("health", 1, true) ~= 1 then error("labels starting with the search should come first") end
    -- choosing a result opens the section it is in
    local hit = find("reduce motion", "sections", "reduce motion")
    frame.GoToOption(hit)
    if not ns.optUI.current or ns.optUI.current.id ~= "access:Flashing and motion" then error("choosing a result should open its section, now on " .. tostring(ns.optUI.current and ns.optUI.current.id)) end
    hit = find("auto-repair", "sections", "repair")
    if not hit or frame.GoToOption(hit) ~= ns:SettingsSection("items:Vendors") then error("a switch's result opens its section") end
    -- each result in the list says where it lives; Enter goes to the first
    local listed = frame.SearchOptions("execute line")
    if not listed[1] or not listed[1].section or listed[1].section.id ~= "combat:Alerts and warnings" then error("a result knows its section") end
    if ns.lastSearchHit ~= hit then error("the chosen result was not remembered") end
    -- typing in the box lists results; clearing it lists none
    if #frame.SearchOptions("boss") == 0 then error("typing should list results") end
    if #frame.SearchOptions("") ~= 0 then error("an empty box should list nothing") end
    ns:ToggleConfig()
end)
try("Confirmation boxes", function()
    local p = known.__popup
    local function gone(x) return rawget(x, "__alpha")[1] == 0 end
    -- the piece that covered our panel is taken away, and the box has its panel
    if not gone(p.over) then error("the frame piece laid over the box should be hidden") end
    if not rawget(p.box, "suiPainted") then error("the box should have its panel") end
    -- both red buttons lose their red and get our plate
    for name, b in pairs({ yes = p.yes, no = p.no }) do
        if not rawget(b, "suiControl") then error("the " .. name .. " button was not given our plate") end
    end
    if not gone(p.yesArt) then error("a button's red art should be hidden") end
    -- what belongs to the question itself is kept
    if gone(p.icon) then error("the warning icon must be kept") end
end)
try("Undo in move mode", function()
    env.InCombatLockdown = function() return false end
    local clock = 1000
    local realTime = env.GetTime
    env.GetTime = function() return clock end
    -- a panel whose place can be followed
    local f = newmock()
    local at = { "CENTER", "CENTER", 0, 0 }
    local scale = 1
    rawset(f, "GetPoint", function() return at[1], env.UIParent, at[2], at[3], at[4] end)
    rawset(f, "SetPoint", function(_, p, _, rp, x, y) at = { p, rp, x, y } end)
    rawset(f, "ClearAllPoints", function() end)
    rawset(f, "SetScale", function(_, s) scale = s end)
    rawset(f, "GetScale", function() return scale end)
    rawset(f, "GetCenter", function() return 400, 300 end)
    rawset(f, "GetEffectiveScale", function() return 1 end)
    ns.db.pos.testUndo, ns.db.scale.testUndo = nil, nil
    ns:RegisterMovable(f, "testUndo", "Test Panel")
    for i = #ns.undoStack, 1, -1 do ns.undoStack[i] = nil end
    if ns:Undo() then error("with nothing done there should be nothing to undo") end

    -- three nudges in a row are one step back
    ns:NudgePanel("testUndo", 5, 0); clock = clock + 0.3
    ns:NudgePanel("testUndo", 5, 0); clock = clock + 0.3
    ns:NudgePanel("testUndo", 5, 0)
    if at[3] ~= 15 then error("three nudges should have moved it 15, at " .. tostring(at[3])) end
    if #ns.undoStack ~= 1 then error("a run of nudges should be one undo step, got " .. #ns.undoStack) end
    if not ns:Undo() then error("the nudges should be undoable") end
    if at[3] ~= 0 or ns.db.pos.testUndo ~= nil then error("undo should put it back where it started (it had never been moved)") end

    -- separate changes are separate steps, undone in reverse order
    ns:NudgePanel("testUndo", 20, 0); clock = clock + 5
    ns:NudgePanel("testUndo", 0, 30); clock = clock + 5
    ns:SetPanelScale({ "testUndo" }, 1.3); clock = clock + 5
    if #ns.undoStack ~= 3 then error("three separate changes should be three steps, got " .. #ns.undoStack) end
    ns:Undo(); if scale ~= 1 or ns.db.scale.testUndo ~= nil then error("the resize should be undone first") end
    ns:Undo(); if at[3] ~= 20 or at[4] ~= 0 then error("then the second nudge: at " .. at[3] .. ", " .. at[4]) end
    ns:Undo(); if at[3] ~= 0 or at[4] ~= 0 then error("then the first") end
    if #ns.undoStack ~= 0 then error("the stack should be empty again") end

    -- one drag of a scale slider is one step, however many values it passes through
    for _, v in ipairs({ 1.05, 1.1, 1.15, 1.2 }) do ns:SetPanelScale({ "testUndo" }, v); clock = clock + 0.1 end
    if #ns.undoStack ~= 1 then error("one drag of a slider should be one step, got " .. #ns.undoStack) end
    ns:Undo(); if scale ~= 1 then error("undoing the slider drag should return to the size before it") end

    -- Reset can be undone, bringing back the place, the size and the "when to show" rule together
    ns:NudgePanel("testUndo", 40, 40); clock = clock + 5
    ns:SetPanelScale({ "testUndo" }, 1.4); clock = clock + 5
    ns.db.panelShow.testUndo = "COMBAT"
    ns:ResetPanel("testUndo")
    if ns.db.pos.testUndo ~= nil or ns.db.panelShow.testUndo ~= nil then error("Reset should have cleared its settings") end
    ns:Undo()
    if at[3] ~= 40 or scale ~= 1.4 or ns.db.panelShow.testUndo ~= "COMBAT" then error("undoing Reset should restore place, size and rule") end
    ns.db.panelShow.testUndo = nil

    -- in combat nothing is moved, and the step is kept for afterwards
    local depth = #ns.undoStack
    env.InCombatLockdown = function() return true end
    if ns:Undo() or #ns.undoStack ~= depth then error("undo must wait during combat, and keep its step") end
    env.InCombatLockdown = function() return false end

    -- no more than thirty steps are kept
    for i = 1, 40 do ns:PushUndo("testUndo", nil, "step " .. i) end
    if #ns.undoStack ~= 30 then error("the stack should hold thirty steps at most, has " .. #ns.undoStack) end
    for i = #ns.undoStack, 1, -1 do ns.undoStack[i] = nil end
    ns:ResetPanel("testUndo")
    for i = #ns.undoStack, 1, -1 do ns.undoStack[i] = nil end
    env.GetTime = realTime
    -- the bar that shows while moving, and the command
    if not ns.moving then ns:ToggleMove() end
    if not ns.moveBar then error("moving panels should put up its bar") end
    ns:ToggleMove()
    env.SlashCmdList.FANTASYGLASSUI("undo")
end)
try("Panels snap to each other", function()
    local snap = ns.SnapToPanels
    -- { left, right, top, bottom }
    local other = { 100, 300, 200, 150 }
    -- dropped just right of it and level: its left edge closes up to the other's right edge
    local dx, dy = snap({ 306, 406, 200, 150 }, { other }, 10)
    if dx ~= -6 then error("it should close the 6 gap to the neighbour, got " .. dx) end
    if dy ~= 0 then error("already level: no shift up or down, got " .. dy) end
    -- dropped just below and nearly lined up on the left: left edges line up, and its top meets the other's bottom
    dx, dy = snap({ 104, 204, 146, 96 }, { other }, 10)
    if dx ~= -4 or dy ~= 4 then error("left edges should line up and it should close up underneath, got " .. dx .. ", " .. dy) end
    -- too far away to snap
    dx, dy = snap({ 330, 430, 200, 150 }, { other }, 10)
    if dx ~= 0 or dy ~= 0 then error("a panel 30 away should not snap") end
    -- on the far side of the screen vertically: edges that happen to share a column do not pull
    dx, dy = snap({ 103, 203, 900, 850 }, { other }, 10)
    if dx ~= 0 then error("panels far apart should not pull on each other") end
    -- the nearest edge wins when two panels are in reach
    dx = snap({ 306, 406, 200, 150 }, { other, { 409, 500, 200, 150 } }, 10)
    if dx ~= 3 then error("the nearer of two neighbours should win, got " .. dx) end
    if select("#", snap({ 0, 10, 10, 0 }, {}, 10)) ~= 2 then error("it should always return two shifts") end
    if ns.defaults.snapPanels ~= true then error("snapping should be on by default") end
end)
try("Action button text, quiet errors and the cursor ring", function()
    -- key text and macro names follow their switches
    local b = known.ExtraActionButton1
    local keyAlpha, nameAlpha
    local hk, name = newmock(), newmock()
    rawset(hk, "SetAlpha", function(_, a) keyAlpha = a end)
    rawset(name, "SetAlpha", function(_, a) nameAlpha = a end)
    rawset(b, "HotKey", hk); rawset(b, "Name", name)
    if ns.defaults.barHotkeys ~= true or ns.defaults.barMacroNames ~= false then error("by default key text shows and macro names do not, as before") end
    ns.db.barHotkeys, ns.db.barMacroNames = true, false
    if ns:ApplyBarText() < 1 then error("no action buttons are being looked after") end
    if keyAlpha ~= 1 or nameAlpha ~= 0 then error("default: key text shown, macro names hidden") end
    ns.db.barHotkeys, ns.db.barMacroNames = false, true; ns:ApplyBarText()
    if keyAlpha ~= 0 or nameAlpha ~= 1 then error("switched: key text hidden, macro names shown") end
    ns.db.barHotkeys, ns.db.barMacroNames = true, false; ns:ApplyBarText()

    -- the red lines that are dropped, and those that are kept
    local keepMana, keepReady = env.ERR_OUT_OF_MANA, env.ERR_ABILITY_COOLDOWN
    env.ERR_OUT_OF_MANA, env.ERR_ABILITY_COOLDOWN = "Not enough mana", "Ability is not ready yet."
    ns.quietErrorTexts = nil
    if not ns:IsQuietError("Not enough mana") or not ns:IsQuietError("Ability is not ready yet.") then error("the repeating lines should be dropped") end
    if ns:IsQuietError("Inventory is full.") or ns:IsQuietError("You can't do that yet") then error("everything else must still be shown") end
    if ns:IsQuietError("") or ns:IsQuietError(nil) or ns:IsQuietError(42) then error("nothing is not a line to drop") end
    if ns:IsQuietError("Not enough") then error("only an exact match with the game's own text counts") end
    env.ERR_OUT_OF_MANA, env.ERR_ABILITY_COOLDOWN = keepMana, keepReady
    ns.quietErrorTexts = nil
    if ns.defaults.quietErrors ~= false or ns:PresetValue("EVERYTHING", "quietErrors") ~= nil then error("quieter errors must start off and never be set by a preset") end
    if ns.defaults.cursorRing ~= false then error("the cursor ring should start off") end
end)
try("Info bar pieces", function()
    if type(ns.InfoBarCompose) ~= "function" then error("the info bar did not start") end
    local keep = { env.GetFramerate, env.GetNetStats, env.GetMoney, ns.LowestDurability, env.HasNewMail }
    env.GetFramerate = function() return 60 end
    env.GetNetStats = function() return 0, 0, 20, 30 end
    env.GetMoney = function() return 12345 end
    env.HasNewMail = function() return false end
    ns.LowestDurability = function() return 88 end
    local keepParts, keepExtras = ns.db.infobarParts, ns.db.infobarExtras
    ns.db.infobarParts, ns.db.infobarExtras = {}, false
    -- everything on: the pieces appear in their fixed order
    local line, count = ns.InfoBarCompose()
    local fps, ms, dur = line:find(" fps", 1, true), line:find(" ms", 1, true), line:find("durability", 1, true)
    if not (fps and ms and dur and fps < ms and ms < dur) then error("frame rate, latency and durability should appear in that order: " .. line) end
    -- switching pieces off takes exactly those away
    ns.db.infobarParts = { fps = false, clock = false }
    local line2, count2 = ns.InfoBarCompose()
    if line2:find(" fps", 1, true) then error("frame rate was switched off but still shows") end
    if not line2:find(" ms", 1, true) then error("latency was not switched off but has gone") end
    if count2 ~= count - 2 then error("two pieces off should leave two fewer, had " .. count .. " now " .. count2) end
    if ns.InfoBarPieceOn("fps") or not ns.InfoBarPieceOn("ms") or not ns.InfoBarPieceOn("anything else") then error("a piece is on unless it was switched off") end
    -- the four extra pieces need their Features switch as well as their own tick
    ns.db.infobarParts = {}
    ns.db.infobarExtras = true
    local _, withExtras = ns.InfoBarCompose()
    if withExtras <= count then error("the extra pieces should add to the bar") end
    ns.db.infobarParts = { friends = false }
    local line3, fewer = ns.InfoBarCompose()
    if fewer ~= withExtras - 1 or line3:find("friends", 1, true) then error("an extra piece switched off should go") end
    -- everything off: an empty bar, not an error
    local off = {}
    for _, def in ipairs(ns.infobarPieces) do off[def[1]] = false end
    ns.db.infobarParts = off
    local empty, none = ns.InfoBarCompose()
    if empty ~= "" or none ~= 0 then error("with every piece off the bar should be empty") end
    -- the switches in the list: off must really be off (gold stayed on the bar after being unticked)
    ns.db.infobarParts = {}
    if ns.InfoBarSetPiece("gold", false) ~= false or ns.db.infobarParts.gold ~= false then error("switching gold off must store that and take it off the bar") end
    if ns.InfoBarCompose():find("fps", 1, true) == nil then error("the others stay") end
    local goldLine = ns.InfoBarCompose()
    ns.InfoBarSetPiece("gold", true)
    if ns.db.infobarParts.gold ~= nil or #ns.InfoBarCompose() <= #goldLine then error("switching gold back on returns it to the bar") end
    if ns.InfoBarSetPiece("hearth", true) ~= true or ns.db.infobarParts.hearth ~= true then error("a piece that starts off is stored when switched on") end
    ns.InfoBarSetPiece("hearth", false)
    if ns.db.infobarParts.hearth ~= nil then error("and forgotten when switched off again") end
    -- and through the list itself
    ns:ToggleInfoBarPieces()
    if not ns.infoBarPiecesFrame then ns:ToggleInfoBarPieces() end
    local box = ns.infoBarPiecesFrame.boxes.gold
    box:SetChecked(true)                                      -- (as it shows when gold is on the bar)
    for i = 1, #handlers do local h = handlers[i]; if h.self == box and h.name == "OnClick" then h.fn(box) end end
    if ns.db.infobarParts.gold ~= false or box.checked ~= false then error("clicking Gold in the list should switch it off") end
    ns:ToggleInfoBarPieces()
    ns.db.infobarParts, ns.db.infobarExtras = keepParts, keepExtras
    env.GetFramerate, env.GetNetStats, env.GetMoney, ns.LowestDurability, env.HasNewMail = keep[1], keep[2], keep[3], keep[4], keep[5]
    ns:ToggleInfoBarPieces(); ns:ToggleInfoBarPieces()
end)
try("Keep and sell lists", function()
    local keepSell, keepKeep = ns.root.sellList, ns.root.keepList
    ns.root.sellList, ns.root.keepList = nil, nil
    local link = function(id) return "|cffffffff|Hitem:" .. id .. ":0:0|h[Thing " .. id .. "]|h|r" end
    if ns:ItemIDOf(link(4306)) ~= 4306 or ns:ItemIDOf(4306) ~= 4306 or ns:ItemIDOf("nonsense") ~= nil or ns:ItemIDOf(nil) ~= nil then error("an item's number was not read from its link") end
    -- by color alone: grey goes, everything else stays, and nothing without a price is ever sold
    if not ns:ShouldSell(link(1), 0, 50) then error("a grey item with a price should be sold") end
    if ns:ShouldSell(link(1), 1, 50) or ns:ShouldSell(link(1), 4, 5000) then error("an item that is not grey should be kept") end
    if ns:ShouldSell(link(1), 0, 0) or ns:ShouldSell(link(1), 0, nil) then error("an item with no price must never be sold") end
    -- the sell list overrides the color one way, the keep list the other
    ns:SetItemList(link(2), "sell")
    if not ns:ShouldSell(link(2), 1, 50) or not ns:ShouldSell(link(2), 3, 50) then error("an item on the sell list should go whatever its color") end
    if ns:ShouldSell(link(2), 3, 0) then error("even on the sell list, an item with no price is not sold") end
    ns:SetItemList(link(3), "keep")
    if ns:ShouldSell(link(3), 0, 50) then error("a grey item on the keep list must not be sold") end
    -- an item is on one list at most; putting it on one takes it off the other
    ns:SetItemList(link(2), "keep")
    if ns:ItemListState(link(2)) ~= "keep" or ns.root.sellList[2] then error("moving an item to the keep list should take it off the sell list") end
    ns:SetItemList(link(2), nil)
    if ns:ItemListState(link(2)) ~= nil then error("an item should come off both lists") end
    if ns:SetItemList("nonsense", "sell") then error("something that is not an item cannot be listed") end

    -- selling: a grey item, a white item on the sell list, a grey item on the keep list, and a plain white item
    ns:SetItemList(link(12), "sell"); ns:SetItemList(link(13), "keep")
    local bag = { { link(11), 2, 0 }, { link(12), 1, 1 }, { link(13), 5, 0 }, { link(14), 1, 1 } }
    local realSlots, realItem, realInfo, realUse = ns.NumSlots, ns.BagItem, ns.GetItemInfo, ns.UseBagItem
    ns.NumSlots = function(_, b) return b == 0 and #bag or 0 end
    ns.BagItem = function(_, b, slot) local it = b == 0 and bag[slot]; if it then return it[1], it[2], it[3] end end
    ns.GetItemInfo = function(_, l) return "Thing", l, 1, 1, 1, "", "", 1, "", 1, 10 end
    local used = {}
    ns.UseBagItem = function(_, b, slot) used[#used + 1] = slot end
    local total, sold = ns:SellJunk()
    if sold ~= 2 or used[1] ~= 1 or used[2] ~= 2 then error("exactly the grey item and the sell-listed item should be sold, sold slots: " .. table.concat(used, ",")) end
    if total ~= 30 then error("2 at 10 and 1 at 10 should come to 30, got " .. tostring(total)) end
    ns.NumSlots, ns.BagItem, ns.UseBagItem = realSlots, realItem, realUse

    -- the commands: a link toggles its list, and the word "list" changes nothing
    env.SlashCmdList.FANTASYGLASSUI("sell " .. link(77))
    if ns:ItemListState(77) ~= "sell" then error("/fgui sell [item] should put it on the sell list") end
    env.SlashCmdList.FANTASYGLASSUI("sell " .. link(77))
    if ns:ItemListState(77) ~= nil then error("/fgui sell [item] again should take it off") end
    env.SlashCmdList.FANTASYGLASSUI("keep " .. link(77))
    if ns:ItemListState(77) ~= "keep" then error("/fgui keep [item] should put it on the keep list") end
    env.SlashCmdList.FANTASYGLASSUI("sell list")
    if ns:ItemListState(77) ~= "keep" then error("/fgui sell list must not change anything") end
    ns.GetItemInfo = realInfo
    ns.root.sellList, ns.root.keepList = keepSell, keepKeep
end)
try("Mail: your other characters", function()
    local realKey, realInv = ns.CharKey, ns.root.inventory
    ns.CharKey = function() return "Denogh - Stormrage" end
    ns.root.inventory = { chars = {
        ["Denogh - Stormrage"] = { class = "SHAMAN" }, ["Zara - Stormrage"] = { class = "MAGE" }, ["Abel - Stormrage"] = { class = "ROGUE" },
        ["Bank - Area 52"] = { class = "WARRIOR" }, ["Unknown - Stormrage"] = {},
    } }
    local alts = ns:MailAlts()
    if #alts ~= 3 then error("three other characters should be listed (not yourself, not an unnamed one), got " .. #alts) end
    if alts[1].name ~= "Abel" or alts[2].name ~= "Zara" then error("characters on this realm should come first, by name") end
    if alts[1].target ~= "Abel" then error("a character on your realm is addressed by name alone") end
    if alts[3].target ~= "Bank-Area52" or not alts[3].other then error("a character on another realm is addressed Name-Realm, got " .. tostring(alts[3].target)) end
    if alts[2].class ~= "MAGE" then error("the class should come along, for the name's color") end
    ns.root.inventory = nil
    if #ns:MailAlts() ~= 0 then error("with nothing recorded there is nobody to list") end
    ns.CharKey, ns.root.inventory = realKey, realInv
    if ns.FillMailAlts then ns.FillMailAlts() end
end)
try("Combat timer", function()
    local T = ns.CombatTimerText
    if T(0) ~= "0:00" or T(9) ~= "0:09" or T(83) ~= "1:23" or T(600) ~= "10:00" or T(3725) ~= "1:02:05" then error("a duration was written wrongly") end
    if T(-5) ~= "0:00" or T(nil) ~= "0:00" or T(59.9) ~= "0:59" then error("odd durations should be handled") end
    if type(ns.CombatTimerDraw) ~= "function" then error("the combat timer did not start") end
    if ns.defaults.combatTimer ~= false then error("the combat timer should start switched off") end
    local clock = 100
    local realTime = env.GetTime
    env.GetTime = function() return clock end
    env.InCombatLockdown = function() return false end
    if ns.previewing then ns:TogglePreview(true) end
    fireEvent("PLAYER_REGEN_ENABLED")
    clock = 500
    if ns.CombatTimerDraw() ~= "hidden" then error("out of combat, with no recent fight, the timer should be hidden") end
    fireEvent("PLAYER_REGEN_DISABLED"); clock = 542
    if ns.CombatTimerDraw() ~= "counting" then error("in combat the timer should be counting") end
    fireEvent("PLAYER_REGEN_ENABLED"); clock = 545
    if ns.CombatTimerDraw() ~= "final" then error("just after a fight the final time should stay up") end
    clock = 560
    if ns.CombatTimerDraw() ~= "hidden" then error("a while after the fight the timer should go") end
    env.GetTime = realTime
end)
try("Your name in chat", function()
    local H = ns.HighlightName
    local C = "|cffffe14d"
    local out, n = H("hey Denogh, over here", "Denogh", C)
    if out ~= "hey " .. C .. "Denogh|r, over here" or n ~= 1 then error("the name should be picked out once: " .. out) end
    -- however it is capitalised, and it keeps the capitals it was written with
    out, n = H("DENOGH! denogh?", "Denogh", C)
    if out ~= C .. "DENOGH|r! " .. C .. "denogh|r?" or n ~= 2 then error("any capitalisation should match and be kept as written: " .. out) end
    -- only as a whole word
    for _, text in ipairs({ "Denoghson is here", "xDenogh", "Denogh2", "Den ogh" }) do
        local same, count = H(text, "Denogh", C)
        if same ~= text or count ~= 0 then error("part of another word must not be picked out: " .. text) end
    end
    -- text inside a link is never touched, so the link still works
    local linked = "|Hplayer:Denogh|h[Denogh]|h waves at Denogh"
    out, n = H(linked, "Denogh", C)
    if n ~= 1 or out ~= "|Hplayer:Denogh|h[Denogh]|h waves at " .. C .. "Denogh|r" then error("a name inside a link must be left alone: " .. out) end
    out, n = H("look at |Hitem:1|h[Denogh's Blade]|h", "Denogh", C)
    if n ~= 0 or out ~= "look at |Hitem:1|h[Denogh's Blade]|h" then error("an item link must be left whole") end
    -- nothing to find, a name too short to be safe, or nonsense in: the message comes back as it was
    if select(2, H("nothing here", "Denogh", C)) ~= 0 then error("no name, no highlight") end
    if H("is it Al or al", "Al", C) ~= "is it Al or al" then error("a two-letter name would light up half the chat: it is skipped") end
    if H(nil, "Denogh", C) ~= nil or H("text", nil, C) ~= "text" then error("missing input should pass straight through") end
    -- a name with a character that means something in a pattern is taken literally
    out, n = H("ask Mal-Gor about it", "Mal-Gor", C)
    if n ~= 1 then error("a name with a hyphen should still be found") end
    if ns.defaults.chatHighlight ~= true or ns.defaults.chatNameSound ~= false then error("highlighting is on by default, the sound is not") end
    -- the filter itself, where the harness has a character name to give it
    if ns.ChatNameFilter then
        local me = env.UnitName("player")
        local block, text = ns.ChatNameFilter(nil, "CHAT_MSG_GUILD", "thanks " .. me, "Otherplayer-Realm")
        if block ~= false or not text or not text:find(C, 1, true) then error("another player saying your name should be highlighted") end
        local b2, t2 = ns.ChatNameFilter(nil, "CHAT_MSG_GUILD", me .. " here", me .. "-Realm")
        if b2 ~= false or t2 ~= nil then error("your own message must be left exactly as it is") end
    end
end)
try("Focus's target frame", function()
    if ns.defaults.ufFocusTarget ~= true then error("the focus's target frame should be on by default") end
    if not ns.focusTargetFrame then error("the focus's target frame was not made") end
    local found
    for _, m in ipairs(ns.movables) do if m.key == "ufFocusTarget" then found = m end end
    if not found or found.frame ~= ns.focusTargetFrame then error("the focus's target frame should be movable") end
    if type(ns.featureDesc.ufFocusTarget) ~= "string" then error("it should have a description") end
end)
try("Dragging the game's windows", function()
    env.InCombatLockdown = function() return false end
    ns.db.moveWindows, ns.db.windowPos = true, {}
    local function window(protected)
        local w = newmock()
        local at = { "CENTER", nil, "CENTER", 0, 0 }
        local placed = 0
        rawset(w, "IsForbidden", function() return false end)
        rawset(w, "IsProtected", function() return protected end)
        rawset(w, "GetPoint", function() return at[1], at[2], at[3], at[4], at[5] end)
        rawset(w, "SetPoint", function(_, p, _, rp, x, y) at = { p, nil, rp, x, y }; placed = placed + 1 end)
        rawset(w, "StartMoving", function() end)
        rawset(w, "StopMovingOrSizing", function() at = { "TOPLEFT", nil, "TOPLEFT", 310, -140 } end)   -- where the drag ended
        return w, function() return at end, function() return placed end
    end
    local win, where, placed = window(false)
    if not ns:MakeWindowMovable(win, "TestWindow") then error("an ordinary window should become movable") end
    if ns:MakeWindowMovable(win, "TestWindow") then error("a window is only set up once") end
    local move = rawget(win, "suiMove")
    -- nothing saved yet: the game's own placement is left alone
    if ns:PlaceWindow(win, "TestWindow") or placed() ~= 0 then error("a window that was never dragged must not be placed") end
    -- a drag is remembered ...
    move.Start(); move.Stop()
    local saved = ns.db.windowPos.TestWindow
    if not ns.WindowPosValid(saved) or saved[1] ~= "TOPLEFT" or saved[3] ~= 310 or saved[4] ~= -140 then error("the place a window was dragged to should be saved") end
    -- ... and put back after the game places the window again
    rawget(win, "SetPoint")(win, "CENTER", nil, "CENTER", 0, 0)
    if not ns:PlaceWindow(win, "TestWindow") then error("a saved place should be restored") end
    local at = where()
    if at[1] ~= "TOPLEFT" or at[4] ~= 310 or at[5] ~= -140 then error("the window should be back where it was left") end
    -- letting go without having dragged saves nothing
    ns.db.windowPos.TestWindow = nil
    move.Stop()
    if ns.db.windowPos.TestWindow ~= nil then error("a stop with no drag must not save a place") end
    -- a protected window in combat is neither dragged nor placed
    local secure, _, securePlaced = window(true)
    ns:MakeWindowMovable(secure, "SecureWindow")
    ns.db.windowPos.SecureWindow = { "CENTER", "CENTER", 50, 50 }
    env.InCombatLockdown = function() return true end
    rawget(secure, "suiMove").Start(); rawget(secure, "suiMove").Stop()
    if ns.db.windowPos.SecureWindow[3] ~= 50 then error("a protected window must not be dragged during combat") end
    if ns:PlaceWindow(secure, "SecureWindow") or securePlaced() ~= 0 then error("a protected window must not be placed during combat") end
    if ns:MakeWindowMovable(window(false), "LateWindow") then error("windows are not set up during combat") end
    env.InCombatLockdown = function() return false end
    if not ns:PlaceWindow(secure, "SecureWindow") then error("after the fight it can be placed") end
    -- switched off: nothing moves; reset forgets everything
    ns.db.moveWindows = false
    move.Start(); move.Stop()
    if ns.db.windowPos.TestWindow ~= nil or ns:PlaceWindow(secure, "SecureWindow") then error("switched off, windows are neither dragged nor placed") end
    ns.db.moveWindows = true
    ns:ResetWindowPositions()
    if next(ns.db.windowPos) then error("reset should forget every saved place") end
    env.SlashCmdList.FANTASYGLASSUI("windows reset")
    if ns.WindowPosValid(nil) or ns.WindowPosValid({ "CENTER" }) or ns.WindowPosValid({ "A", "B", "x", 1 }) then error("a damaged saved place must be refused") end
    for _, name in ipairs({ "WorldMapFrame", "StaticPopup1", "LootFrame" }) do
        if not ns.windowMoveSkip[name] then error(name .. " should be left to the game") end
    end
end)
try("Clock, durability and item level", function()
    local F = ns.FormatClock
    if F(15, 5) ~= "15:05" or F(0, 0) ~= "00:00" or F(9, 30) ~= "09:30" then error("24-hour time was written wrongly") end
    if F(15, 5, true) ~= "3:05pm" or F(0, 0, true) ~= "12:00am" or F(12, 0, true) ~= "12:00pm" or F(11, 59, true) ~= "11:59am" or F(23, 59, true) ~= "11:59pm" then error("12-hour time was written wrongly") end
    local realGame = env.GetGameTime
    env.GetGameTime = function() return 21, 7 end
    ns.db.clockServer, ns.db.clock12 = true, false
    if ns:ClockText() ~= "21:07" then error("server time should be used when chosen, got " .. ns:ClockText()) end
    ns.db.clock12 = true
    if ns:ClockText() ~= "9:07pm" then error("server time in 12-hour form, got " .. ns:ClockText()) end
    ns.db.clockServer, ns.db.clock12 = false, false
    if not ns:ClockText():match("^%d%d:%d%d$") then error("the local clock should read HH:MM") end
    env.GetGameTime = realGame
    -- durability: nothing for a whole piece, a percentage and a grade for a worn one
    local D = ns.DurabilityText
    if D(50, 50) ~= nil or D(0, 0) ~= nil or D(nil, nil) ~= nil or D(false, false) ~= nil then error("a whole piece, or one with no durability, shows nothing") end
    local pct, state = D(31, 50); if pct ~= "62%" or state ~= "good" then error("31 of 50 is 62%, fine") end
    pct, state = D(30, 50); if pct ~= "60%" or state ~= "warn" then error("60% is a warning") end
    pct, state = D(5, 50); if pct ~= "10%" or state ~= "bad" then error("10% is bad") end
    pct, state = D(0, 50); if pct ~= "0%" or state ~= "bad" then error("broken is 0%") end
    if secretMode and D(SV(5), SV(50)) ~= nil then error("hidden durability shows nothing") end
    local A = ns.AverageItemLevel
    if A({ 20, 22, 24 }) ~= 22 or A({ 15 }) ~= 15 or A({}) ~= nil or A(nil) ~= nil then error("the average item level is wrong") end
end)
try("Repairs, stacks and trainers", function()
    local R = ns.RepairSource
    if R(100, 500, true, 1000) ~= "guild" or R(100, 500, true, -1) ~= "guild" then error("an allowance that covers the bill pays it") end
    if R(100, 500, true, 50) ~= "own" then error("an allowance too small for the whole bill is not used") end
    if R(100, 500, true, 1000, 40) ~= "own" then error("a guild bank without the money cannot pay") end
    if R(100, 500, true, 1000, 0) ~= "guild" then error("a bank total the game has not told us yet should not block it") end
    if R(100, 500, false, 1000) ~= "own" then error("without guild repairs you pay") end
    if R(100, 50, false, 0) ~= "none" or R(100, 50, true, 10) ~= "none" then error("nobody can pay") end
    if ns.defaults.repairGuild ~= false then error("spending guild money must start switched off") end
    local S = ns.StackToBuy
    if S(20, -1, 10, 1, 100000) ~= 20 then error("a full stack when you can afford it") end
    if S(20, -1, 10, 1, 75) ~= 7 then error("as many as you can afford") end
    if S(20, 3, 10, 1, 100000) ~= 3 then error("no more than the vendor has") end
    if S(200, -1, 50, 5, 1000) ~= 100 then error("an item sold five at a time costs a fifth each") end
    if S(1, -1, 10, 1, 100000) ~= 0 or S(nil, nil, nil, nil, nil) ~= 0 then error("something that does not stack is not bought in stacks") end
    if S(20, -1, 0, 1, 0) ~= 20 then error("a free item is limited only by the stack") end
    if S(20, -1, 10, 1, 0) ~= 0 then error("with no money, nothing") end
    -- trainer: only what can be learned now, with its cost
    local keep = { env.GetNumTrainerServices, env.GetTrainerServiceInfo, env.GetTrainerServiceCost }
    local services = { { "Bolt II", "available", 100 }, { "Shield", "unavailable", 500 }, { "Totem", "used", 0 }, { "Shock III", "available", 250 } }
    env.GetNumTrainerServices = function() return #services end
    env.GetTrainerServiceInfo = function(i) return services[i][1], services[i][2] end
    env.GetTrainerServiceCost = function(i) return services[i][3] end
    local list, total = ns:TrainerAvailable()
    if #list ~= 2 or list[1].index ~= 1 or list[2].index ~= 4 or total ~= 350 then error("two skills for 350 should be on offer") end
    env.GetTrainerServiceInfo = function(i) return services[i][1], "Rank 2", services[i][2] end     -- the older order of answers
    list, total = ns:TrainerAvailable()
    if #list ~= 2 or total ~= 350 then error("the older order of answers should be understood too") end
    env.GetNumTrainerServices, env.GetTrainerServiceInfo, env.GetTrainerServiceCost = keep[1], keep[2], keep[3]
end)
try("Conversations, reputation and rare spawns", function()
    local G = ns.GossipPick
    local one, two = { { gossipOptionID = 7 } }, { { gossipOptionID = 7 }, { gossipOptionID = 8 } }
    if G(one, 0, 0, false, false) ~= one[1] then error("a single choice with no quests should be picked") end
    if G(two, 0, 0, false, false) or G({}, 0, 0, false, false) or G(nil, 0, 0, false, false) then error("only exactly one choice is picked") end
    if G(one, 1, 0, false, false) or G(one, 0, 1, false, false) then error("a character with quests is left to you") end
    if G(one, 0, 0, true, false) then error("holding Shift means you choose") end
    if G(one, 0, 0, false, true) then error("nothing is picked for you inside a dungeon or raid") end
    if ns.defaults.gossipOne ~= false or ns:PresetValue("EVERYTHING", "gossipOne") ~= nil then error("it must start off and never be set by a preset") end
    -- the faction named in the game's own line, in the game's own wording
    local keep = { env.FACTION_STANDING_INCREASED, env.FACTION_STANDING_INCREASED_GENERIC, env.FACTION_STANDING_INCREASED_BONUS }
    env.FACTION_STANDING_INCREASED = "Reputation with %s increased by %d."
    env.FACTION_STANDING_INCREASED_GENERIC = "Reputation with %s increased."
    env.FACTION_STANDING_INCREASED_BONUS = "Reputation with %s increased by %d. (+%.1f Refer-A-Friend bonus)"
    ns.factionPatterns = nil
    local F = ns.FactionFromMessage
    if F("Reputation with Stormwind increased by 250.") ~= "Stormwind" then error("the faction was not read from the line") end
    if F("Reputation with The Argent Dawn increased.") ~= "The Argent Dawn" then error("a name of several words should be read whole") end
    if F("Reputation with Darnassus increased by 10. (+1.5 Refer-A-Friend bonus)") ~= "Darnassus" then error("a line with a bonus should be read") end
    if F("Reputation with Stormwind decreased by 5.") or F("You have gained 250 experience.") or F("") or F(nil) or F(42) then error("any other line names no faction") end
    env.FACTION_STANDING_INCREASED = "Euer Ruf bei %s hat sich um %d verbessert."
    env.FACTION_STANDING_INCREASED_GENERIC, env.FACTION_STANDING_INCREASED_BONUS = false, false
    ns.factionPatterns = nil
    if F("Euer Ruf bei Sturmwind hat sich um 75 verbessert.") ~= "Sturmwind" then error("the line should be read in the game's language") end
    env.FACTION_STANDING_INCREASED, env.FACTION_STANDING_INCREASED_GENERIC, env.FACTION_STANDING_INCREASED_BONUS = keep[1], keep[2], keep[3]
    ns.factionPatterns = nil
    -- switching the watched faction
    local realRep = env.C_Reputation
    local watched, set = "Ironforge", nil
    env.C_Reputation = {
        GetWatchedFactionData = function() return { name = watched } end,
        GetNumFactions = function() return 3 end,
        GetFactionDataByIndex = function(i) return ({ { name = "Alliance", isHeader = true }, { name = "Ironforge" }, { name = "Stormwind" } })[i] end,
        SetWatchedFactionByIndex = function(i) set = i end,
    }
    if not ns:WatchFaction("Stormwind") or set ~= 3 then error("the bar should switch to the faction named") end
    set = nil
    if ns:WatchFaction("Ironforge") or set then error("a faction already being watched is left alone") end
    if ns:WatchFaction("Alliance") or set then error("a heading is not a faction to watch") end
    if ns:WatchFaction("Nowhere") or ns:WatchFaction(nil) or set then error("an unknown faction changes nothing") end
    env.C_Reputation = realRep
    if ns.defaults.repFollow ~= false then error("following reputation should start off") end
    local K = ns.VignetteKind
    if K("VignetteKill") ~= "rare" or K("VignetteKillElite") ~= "rare" or K("VignetteLoot") ~= "treasure" or K("VignetteEvent") ~= "event" or K("SomethingElse") ~= "other" or K(nil) ~= "other" then error("a minimap marker was classed wrongly") end
end)
try("Item levels when inspecting", function()
    local keepLink, keepItem = env.GetInventoryItemLink, env.C_Item
    local gear = { [1] = "item:100", [5] = "item:200", [4] = "item:300", [16] = "item:400" }
    local levels = { ["item:100"] = 20, ["item:200"] = 24, ["item:300"] = 1, ["item:400"] = 1 }
    env.GetInventoryItemLink = function(unit, id) if unit == "target" then return gear[id] end end
    env.C_Item = setmetatable({ GetDetailedItemLevelInfo = function(link) return levels[link] end }, { __index = keepItem })
    local L = ns.InspectSlotLevel
    if L("target", 1) ~= 20 or L("target", 5) ~= 24 then error("a worn piece's item level should be read") end
    if L("target", 4) ~= nil then error("a shirt has no level worth showing") end
    if L("target", 16) ~= nil then error("an item of level 1 shows nothing") end
    if L("target", 2) ~= nil then error("an empty slot shows nothing") end
    if L("party1", 1) ~= nil or L(nil, 1) ~= nil or L("target", nil) ~= nil then error("nothing known, nothing shown") end
    if secretMode then
        env.GetInventoryItemLink = function() return SV("item:100") end
        if L("target", 1) ~= nil then error("a hidden item shows nothing") end
    end
    env.GetInventoryItemLink, env.C_Item = keepLink, keepItem
    if ns.defaults.inspectLevels ~= true then error("item levels when inspecting should be on") end
end)
try("Tooltip rank and IDs", function()
    local function tip(unit, link, spellID)
        local lines = {}
        local t = { lines = lines }
        t.GetUnit = function() if unit then return "Someone", unit end end
        t.GetItem = function() if link then return "Thing", link end end
        t.GetSpell = function() if spellID then return "Bolt", spellID end end
        t.GetName = function() return "TestTip" .. tostring(unit or link or spellID) end
        t.NumLines = function() return 0 end
        t.AddLine = function(_, text) lines[#lines + 1] = tostring(text) end
        t.AddDoubleLine = function(_, left, right) lines[#lines + 1] = tostring(left) .. "=" .. tostring(right) end
        return t
    end
    local function has(t, text) for _, line in ipairs(t.lines) do if line:find(text, 1, true) then return true end end return false end
    local keepIDs, keepExtras, keepGuild = ns.db.tooltipIDs, ns.db.tooltipExtras, env.GetGuildInfo
    ns.db.tooltipExtras = false
    -- IDs only when chosen
    ns.db.tooltipIDs = false
    local a = tip(nil, "|Hitem:4306:0|h[Silk Cloth]|h"); ns.TooltipOnTip(a)
    if has(a, "Item ID") then error("IDs must not show unless chosen") end
    ns.db.tooltipIDs = true
    a = tip(nil, "|Hitem:4306:0|h[Silk Cloth]|h"); ns.TooltipOnTip(a)
    if not has(a, "Item ID=4306") then error("the item's ID should be on its tooltip") end
    local s = tip(nil, nil, 403); ns.TooltipOnTip(s)
    if not has(s, "Spell ID=403") then error("the spell's ID should be on its tooltip") end
    local none = tip(nil, nil, nil); ns.TooltipOnTip(none)
    if #none.lines ~= 0 then error("a tooltip that is neither gets nothing") end
    ns.db.tooltipIDs = false
    -- a player's guild rank
    env.GetGuildInfo = function() return "Imperium", "Officer", 2 end
    local keepPlayer, keepClass = env.UnitIsPlayer, env.UnitClass
    env.UnitIsPlayer = function() return true end
    env.UnitClass = function() return "Shaman", "SHAMAN" end
    local u = tip("target"); ns.TooltipOnTip(u)
    if not has(u, "Guild rank: Officer") then error("a player's guild rank should be on their tooltip") end
    env.GetGuildInfo = function() return nil end
    u = tip("target"); ns.TooltipOnTip(u)
    if has(u, "Guild rank") then error("a player with no guild has no rank line") end
    env.GetGuildInfo = function() return "Imperium", "Officer", 2 end
    env.UnitIsPlayer = function() return false end
    u = tip("target"); ns.TooltipOnTip(u)
    if has(u, "Guild rank") then error("a creature has no guild rank") end
    env.UnitIsPlayer, env.UnitClass = keepPlayer, keepClass
    ns.db.tooltipIDs, ns.db.tooltipExtras, env.GetGuildInfo = keepIDs, keepExtras, keepGuild
    if ns.defaults.tooltipIDs ~= false or ns:PresetValue("EVERYTHING", "tooltipIDs") ~= nil then error("IDs start off and no preset sets them") end
    -- the switches for the target and guild rank lines
    env.GetGuildInfo = function() return "Imperium", "Officer", 2 end
    env.UnitIsPlayer = function() return true end
    ns.db.tipGuildRank = false
    local r = tip("target"); ns.TooltipOnTip(r)
    if has(r, "Guild rank") then error("the guild rank line should go when switched off") end
    ns.db.tipGuildRank = true
    env.UnitIsPlayer, env.GetGuildInfo = keepPlayer, keepGuild
end)
try("A long button label fits its button", function()
    local b = ns:CreateButton(UIParent, "Short", 60, 20)
    local t = b.text
    local size, width, label = 12, 0, ""
    rawset(t, "SetFont", function(_, _, s) size = s end)
    rawset(t, "SetWidth", function(_, w) width = w end)
    rawset(t, "GetStringWidth", function() return #label * size * 0.55 end)
    rawset(b, "GetWidth", function() return 60 end)
    label = "Short"; t.suiFit()
    if size ~= 12 * (ns.fontScale or 1) or width ~= 0 then error("a label that fits keeps its size: " .. tostring(size)) end
    label = "Longerlab"; t.suiFit()                  -- 9 letters: fits a little smaller
    if size >= 12 * (ns.fontScale or 1) or width ~= 0 then error("a label a little too long is drawn smaller: " .. tostring(size)) end
    label = "A label far too long for this button"; t.suiFit()
    if math.floor(size + 0.5) ~= math.floor(9 * (ns.fontScale or 1) + 0.5) or width ~= 52 then error("one far too long is cut short at 9 points: " .. tostring(size) .. " " .. tostring(width)) end
end)
try("Pull and break timers say what they take", function()
    if ns:CountdownCommand("pull", "soon") ~= false then error("a word that is not a number is refused, with how") end
    if ns:CountdownCommand("pull", "0") ~= false or ns:CountdownCommand("break", "500") ~= false then error("out of range is refused") end
end)
try("Sizes go back to 100 when asked", function()
    local before = ns.db.fontScale
    ns.db.fontScale = 130
    if ns:SizeCommand("fontScale", "reset", 70, 150) ~= 100 or ns.db.fontScale ~= 100 then error("/fgui textsize reset puts it back to 100") end
    ns.db.fontScale = before
end)
try("Weekly recap", function()
    -- a week is named by the next weekly reset: the same all week, different after it
    if ns.RecapWeek(1000, 600000) ~= ns.RecapWeek(5000, 596000) then error("one week, one name") end
    if ns.RecapWeek(1000, 600000) == ns.RecapWeek(700000, 504800) then error("a new week, a new name") end
    -- the five best loot items: quality first, then item level; nothing below rare
    local e = { loot = {} }
    if ns.RecapLoot(e, "|Hitem:1|h[Green]|h", 2, 50) then error("uncommon loot is not kept") end
    for i = 1, 7 do ns.RecapLoot(e, "|Hitem:" .. (10 + i) .. "|h[Rare " .. i .. "]|h", 3, 40 + i) end
    ns.RecapLoot(e, "|Hitem:99|h[Epic]|h", 4, 30)
    if #e.loot ~= 5 or not e.loot[1].link:find("Epic", 1, true) or e.loot[2].il ~= 47 then error("the five best, epic first") end
    -- old weeks are let go
    local weeks = {}
    for i = 1, 11 do weeks["w" .. i] = { at = i * 1000, chars = {} } end
    ns.RecapPrune(weeks)
    local n = 0; for _ in pairs(weeks) do n = n + 1 end
    if n ~= 8 or weeks.w1 or not weeks.w11 then error("the newest eight weeks are kept") end
    -- the lines
    local week = { chars = { ["Arthas - R"] = { goldStart = 10000, goldEnd = 35000, played = 3 * 3600 + 120, levelStart = 30, levelEnd = 33,
        instances = { ["Molten Core"] = true }, loot = { { link = "|Hitem:5|h[Sword]|h", q = 4, il = 60 } } } } }
    local text = {}
    for _, l in ipairs(ns.RecapLines(week, { ["Arthas - R"] = { name = "Arthas" } })) do text[#text + 1] = l.left .. " " .. tostring(l.right or "") end
    local all = table.concat(text, " | ")
    for _, want in ipairs({ "All your characters", "Arthas", "3 h 2 min", "Levels 30 to 33", "Molten Core", "[Sword]" }) do
        if not all:find(want, 1, true) then error("the recap should show " .. want .. ": " .. all) end
    end
    -- most played first; a character that only logged in is left out
    week.chars["Jaina - R"] = { goldStart = 5, goldEnd = 5, played = 20 * 3600 }
    week.chars["Thrall - R"] = { goldStart = 5, goldEnd = 5, played = 10 }
    local order = {}
    for _, l in ipairs(ns.RecapLines(week, { ["Arthas - R"] = { name = "Arthas" }, ["Jaina - R"] = { name = "Jaina" }, ["Thrall - R"] = { name = "Thrall" } })) do order[#order + 1] = l.left end
    local o = table.concat(order, "|")
    if not o:find("Jaina.*Arthas") then error("the most played character first") end
    if o:find("Thrall", 1, true) then error("a character that did nothing is left out") end
    -- noted as you play
    if type(ns.recapTest) ~= "table" then error("the weekly recap did not start") end
    ns.recapTest.Note()
    local mine = ns.recapTest.Mine()
    if mine.goldStart == nil or mine.levelEnd == nil then error("this character's week should be noted") end
    if ns:ShowRecap() < 1 then error("the recap window should show") end
    ns:HideLists()
end)
try("Interface and text size", function()
    local S = ns.InterfaceScale
    if S(false, 1080, 100, 0.9) ~= nil then error("as the game set it: nothing to change") end
    if math.abs(S(false, 1080, 80, 0.9) - 0.72) > 0.001 then error("80% of the game's scale") end
    if math.abs(S(true, 1080, 100, 0.9) - 768 / 1080) > 0.001 then error("pixel-perfect alone") end
    if math.abs(S(true, 1080, 120, 0.9) - 768 / 1080 * 1.2) > 0.001 then error("pixel-perfect times the interface size") end
    if S(false, 1080, 10, 0.9) < 0.35 or S(false, 1080, 999, 1.5) > 1.6 then error("kept in a range the game can draw") end
    local keepFont, keepUi = ns.db.fontScale, ns.db.uiScale
    if ns:SizeCommand("fontScale", "500", 70, 150) ~= 150 then error("a text size out of range is brought into it") end
    if ns:SizeCommand("uiScale", "90", 50, 150) ~= 90 then error("the interface size is taken") end
    if ns:SizeCommand("uiScale", "", 50, 150) ~= nil then error("with no number it only says the size") end
    ns.db.fontScale, ns.db.uiScale = keepFont, keepUi
    ns:ApplyPixelScale(); ns:Retheme()
end)
try("Profession leveling helper", function()
    local P = ns.SkillUpPlan
    local recipes = {
        { id = 1, name = "Gray Bolt", difficulty = 3, reagents = { { id = 10, need = 1 } } },
        { id = 2, name = "Green Shirt", difficulty = 2, reagents = { { id = 10, need = 2 } } },
        { id = 3, name = "Orange Cloak", difficulty = 0, reagents = { { id = 10, need = 3 }, { id = 11, need = 1 } } },
        { id = 4, name = "Yellow Gloves", difficulty = 1, reagents = { { id = 10, need = 2 } } },
        { id = 5, name = "Orange Boots", difficulty = 0, reagents = { { id = 12, need = 5 } } },
    }
    local stock = { [10] = { 5, 0 }, [11] = { 0, 4 }, [12] = { 1, 0 } }
    local plan = P(recipes, function(id) local s = stock[id] or { 0, 0 }; return s[1], s[2] end)
    for _, p in ipairs(plan) do if p.name == "Gray Bolt" then error("gray recipes give nothing more and are left out") end end
    if plan[1].name ~= "Yellow Gloves" or plan[1].makeNow ~= 2 then error("what you can make now comes first, the surer skill-up before the green one: " .. tostring(plan[1].name)) end
    if plan[2].name ~= "Green Shirt" then error("then the other one you can make now: " .. tostring(plan[2].name)) end
    if plan[3].name ~= "Orange Cloak" or plan[3].missing ~= 1 or plan[3].short[1].others ~= 4 then error("then the one missing least, and another character has it") end
    if plan[4].name ~= "Orange Boots" or plan[4].missing ~= 4 then error("and the one missing most last") end
    -- a recipe with no materials can always be made; more skill points first among equals
    local plan2 = P({ { id = 6, name = "B Charm", difficulty = 1, skillUps = 1, reagents = {} },
                      { id = 7, name = "A Charm", difficulty = 1, skillUps = 1, reagents = {} },
                      { id = 8, name = "Z Charm", difficulty = 1, skillUps = 2, reagents = {} } }, function() return 0, 0 end)
    if not plan2[1].free or plan2[1].makeNow < 1 then error("a recipe with no materials can be made now") end
    if plan2[1].name ~= "Z Charm" or plan2[2].name ~= "A Charm" then error("the one worth two points first, then by name: " .. tostring(plan2[1].name)) end
    -- the window, with a profession open
    env.C_TradeSkillUI = { GetAllRecipeIDs = function() return { 1, 2 } end,
        GetRecipeInfo = function(id) return { learned = true, name = id == 1 and "Linen Bandage" or "Wool Bandage", relativeDifficulty = id == 1 and 0 or 2, numSkillUps = id } end,
        GetRecipeSchematic = function(id) return { reagentSlotSchematics = { { reagentType = 1, quantityRequired = 2, reagents = { { itemID = 2589 + id } } } } } end,
        OpenRecipe = function() end }
    if ns:ShowSkillUps() ~= 2 then error("both recipes that still give points are listed") end
    env.C_TradeSkillUI = nil
    if ns:ShowSkillUps(true) ~= 0 then error("no profession open: nothing, and quietly when asked to be") end
    -- the button on the profession window
    env.ProfessionsFrame = env.CreateFrame("Frame", "ProfessionsFrame")
    ns.skillUpTest.Dress()
    env.ProfessionsFrame = nil
    if type(ns.ShowSkillUps) ~= "function" then error("the skill-ups window is missing") end
end)
try("Login briefing", function()
    local B = ns.BriefingLines
    if #B({ now = 1000 }) ~= 0 then error("nothing known, nothing waiting") end
    local d = {
        me = "Arthas - Realm", now = 100000, lastSeen = 50000,
        alts = { ["Arthas - Realm"] = { name = "Arthas", mail = true }, ["Jaina - Realm"] = { name = "Jaina", mail = true }, ["Thrall - Realm"] = { name = "Thrall", mail = false } },
        profCD = { ["Jaina - Realm"] = { [1] = { name = "Transmute: Arcanite", readyAt = 90000 } } },
        oldLockouts = { { name = "Molten Core", ends = 80000 }, { name = "Molten Core", ends = 80000 }, { name = "Onyxia's Lair", ends = 200000 }, { name = "Old", ends = 40000 } },
        rested = 45, level = 30, maxLevel = 60,
        checklist = { done = { daily = { 1, 3 }, weekly = { 2, 2 } } },
    }
    local text = {}
    for _, l in ipairs(B(d)) do text[#text + 1] = l.left end
    local all = table.concat(text, " | ")
    for _, want in ipairs({ "Transmute: Arcanite", "Mail waiting for Jaina", "Molten Core", "Rested: 45%", "Daily jobs: 1 of 3" }) do
        if not all:find(want, 1, true) then error("the briefing should say " .. want .. ": " .. all) end
    end
    if all:find("Arthas", 1, true) then error("this character's own mail is the game's to tell") end
    if all:find("Onyxia", 1, true) or all:find("Old", 1, true) then error("only lockouts reset since you last played") end
    if all:find("Weekly jobs", 1, true) then error("finished jobs are not mentioned") end
    local extra = B({ now = 1, durability = 12, freeSlots = 2 })
    if #extra ~= 2 or not extra[1].left:find("12", 1, true) or not extra[2].left:find("2", 1, true) then error("gear to repair and bags nearly full are mentioned") end
    if #B({ now = 1, durability = 80, freeSlots = 20 }) ~= 0 then error("good gear and room in the bags are not mentioned") end
    local _, mc = all:gsub("Molten Core", "")
    if mc ~= 1 then error("a raid saved on two difficulties is named once") end
    d.level = 60
    for _, l in ipairs(B(d)) do if l.left:find("Rested", 1, true) then error("no rested line at the top level") end end
    -- the window
    if ns:ShowBriefing() < 1 then error("asked for, the briefing always shows (even if only to say nothing is waiting)") end
    ns:HideLists()
end)
try("Buttons that delete ask first", function()
    local ran = 0
    local b = ns:CreateButton(env.UIParent, "Delete", 80, 24, ns:ConfirmClick(function() ran = ran + 1 end))
    local click = b:GetScript("OnClick")
    if type(click) ~= "function" then
        for _, h in ipairs(handlers) do if h.self == b and h.name == "OnClick" then click = h.fn end end
    end
    click(b)
    if ran ~= 0 then error("one click should only ask") end
    if not rawget(b, "suiArmed") then error("the button should be waiting for the second click") end
    click(b)
    if ran ~= 1 then error("the second click should do it") end
    if rawget(b, "suiArmed") then error("and then it waits no longer") end
end)
try("Right-click hands items over", function()
    local T = ns.bagTest and ns.bagTest.FantasyGlassUIBags
    if not T then error("the bag window's test hooks are missing") end
    local used
    local keep = env.C_Container.UseContainerItem
    env.C_Container.UseContainerItem = function(bag, slot) used = bag .. ":" .. slot end
    local b = { bag = 0, slot = 3, info = { hyperlink = "|Hitem:2000|h[Trinket]|h" } }
    fireEvent("MERCHANT_SHOW")
    if not ns.BagHandOver() then error("an open vendor should count") end
    local r = T.RightClick(b)
    if r ~= "handed" or used ~= "0:3" then error("right-click at a vendor should sell, even gear with a use: " .. tostring(r)) end
    -- a slot's own secure button leaves the right button to the game while the vendor is open
    local attr = {}
    b.suiUse = { GetAttribute = function(_, k) return attr[k] end, SetAttribute = function(_, k, v) attr[k] = v end }
    attr.type2 = "item"
    T.RightToGame()
    fireEvent("MERCHANT_CLOSED")
    if ns.BagHandOver() then error("a closed vendor should not count") end
    used = nil
    if T.RightClick({ bag = 0, slot = 4, info = {} }) ~= "used" or used ~= "0:4" then error("away from a vendor an item with no use is used as before") end
    env.C_Container.UseContainerItem = keep
end)
try("Vendor summary", function()
    local L = ns.VendorSummaryLine
    if L({ sold = 0, spent = 0 }) then error("a visit where nothing happened says nothing") end
    local plain = function(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    local one = plain(L({ sold = 32000, spent = 0, soldCount = 12 }))
    if not one:find("sold 12 items for", 1, true) or one:find("In all", 1, true) then error("sold only: " .. one) end
    local all = plain(L({ sold = 32000, spent = 14500, soldCount = 12, boughtCount = 3, repair = 10500 }))
    if not (all:find("bought 3 items for", 1, true) and all:find("repaired for", 1, true) and all:find("In all: +", 1, true)) then error("the whole visit: " .. all) end
    local guild = plain(L({ sold = 0, spent = 0, guildRepair = 5000 }))
    if not guild:find("from guild funds", 1, true) then error("a guild repair: " .. guild) end
    local minus = plain(L({ sold = 100, spent = 900, soldCount = 1, boughtCount = 1 }))
    if not (minus:find("sold 1 item for", 1, true) and minus:find("In all: -", 1, true)) then error("spent more than sold: " .. minus) end
    -- a whole visit, through the game's events
    local money = 10000
    local keepMoney, keepCost = env.GetMoney, env.GetRepairAllCost
    env.GetMoney = function() return money end
    env.GetRepairAllCost = function() return 2500, true end
    local printed
    local realPrint = ns.Print
    ns.Print = function(_, f, ...) printed = tostring(f) end
    fireEvent("MERCHANT_SHOW")
    money = money + 600; fireEvent("PLAYER_MONEY")              -- (sold)
    if type(env.RepairAllItems) == "function" then env.RepairAllItems() end
    money = money - 2500; fireEvent("PLAYER_MONEY")             -- (repaired)
    fireEvent("MERCHANT_CLOSED"); runTimers()
    ns.Print = realPrint
    env.GetMoney, env.GetRepairAllCost = keepMoney, keepCost
    if not printed or not plain(printed):find("At the vendor:", 1, true) then error("closing the vendor should print the summary: " .. tostring(printed)) end
    if type(ns.vendorSummaryTest) ~= "table" or ns.vendorSummaryTest.Visit() ~= nil then error("the visit should be over") end
end)
try("Tooltips wear the theme", function()
    local tip = env.CreateFrame("Frame", "PanelTestTip")
    local alpha = 1
    tip.NineSlice = { SetAlpha = function(_, a) alpha = a end, SetCenterColor = function() end, SetBorderColor = function() end }
    if ns.TooltipPanel(tip) ~= true or not tip.suiRim then error("a tooltip should get the theme's panel") end
    if alpha ~= 0 then error("the game's own tooltip frame should be put out of sight") end
    local inside = env.CreateFrame("Frame", "EmbeddedItemTooltip")
    rawset(inside, "GetName", function() return "EmbeddedItemTooltip" end)
    if ns.TooltipPanel(inside) then error("a tooltip inside another gets no panel of its own") end
    ns.TooltipOnTip(tip)                                     -- (no unit, no item: styled, nothing added)
end)
try("Player tooltips", function()
    local P = ns.PlayerTipPlan
    local info = { name = "Arthas", realm = "Stormrage", pvpName = "Champion Arthas", guild = "Imperium", faction = "Alliance",
                   class = "Paladin", level = 60, levelWord = "Level", pvp = "PvP" }
    local lines = { "Champion Arthas-Stormrage <Away>", "<Imperium>", "Level 60 Human Paladin (Player)", "Alliance", "PvP" }
    local all = {}
    for _, def in ipairs(ns.PLAYER_TIP_LINES) do all[def[1]] = ns.defaults[def[1]] end
    local drop, first = P(lines, info, all)
    if next(drop) or first then error("with every line on, nothing should change") end
    local some = {}; for k, v in pairs(all) do some[k] = v end
    some.tipGuild, some.tipLevel, some.tipFaction, some.tipPvP = false, false, false, false
    drop = P(lines, info, some)
    if not (drop[2] and drop[3] and drop[4] and drop[5]) or drop[1] then error("the guild, level, faction and PvP lines should go") end
    some = {}; for k, v in pairs(all) do some[k] = v end
    some.tipTitle, some.tipRealm = false, false
    drop, first = P(lines, info, some)
    if first ~= "Arthas <Away>" then error("no title or realm should leave the name and its tag: " .. tostring(first)) end
    some.tipTitle = true
    drop, first = P(lines, info, some)
    if first ~= "Champion Arthas <Away>" then error("the title without the realm: " .. tostring(first)) end
    -- a line the game keeps hidden is never touched
    drop = P({ "Arthas", nil, "Level 60 Human Paladin", n = 3 }, info, { tipLevel = false, tipGuild = false })
    if drop[2] or not drop[3] then error("a hidden line stays, the level line goes") end
    -- this game's own layout: the guild with no brackets, and the class on a line of its own
    local faxe = { name = "Faxe", class = "Priest", level = 16, levelWord = "Level", guild = "Solaris Vanguard", faction = "Alliance", pvp = "PvP" }
    drop = P({ "Faxe Shenjingbing", "Solaris Vanguard", "Level 16 Dwarf (Player)", "Priest", "Alliance" }, faxe,
             { tipLevel = false, tipGuild = false, tipFaction = true, tipPvP = true, tipTitle = true, tipRealm = true })
    if not (drop[2] and drop[3] and drop[4]) or drop[5] then error("guild, level and the class line of its own should go, faction stays") end
    -- health in numbers
    if ns.PlayerTipHealth(12345, 20000) ~= "12,345 / 20,000 (62%)" and ns.PlayerTipHealth(12345, 20000) ~= "12345 / 20000 (62%)" then error("health in numbers: " .. tostring(ns.PlayerTipHealth(12345, 20000))) end
    if ns.PlayerTipHealth(nil, 100) or ns.PlayerTipHealth(5, 0) then error("no health, no line") end
    -- every switch has a default and a name in the options
    for _, def in ipairs(ns.PLAYER_TIP_LINES) do
        if ns.defaults[def[1]] == nil then error(def[1] .. " has no default") end
    end
    if ns.defaults.tipHealth ~= false or ns.defaults.tipCombatHide ~= false or ns.defaults.tipRole ~= true then error("new lines start as chosen") end
    if type(ns.PlayerTipTest) ~= "table" then error("the player tooltip module did not start") end
    -- a whole tooltip, rewritten without the hidden lines
    local texts = { "Champion Arthas", "<Imperium>", "Level 60 Human Paladin (Player)", "Alliance", "PvP" }
    local function FS(i)
        return { GetText = function() return texts[i] end, GetTextColor = function() return 1, 1, 1 end,
                 SetText = function(_, t) texts[i] = t end, IsShown = function() return false end }
    end
    local keep = {}
    for _, k in ipairs({ "GameTooltip", "UnitIsPlayer", "UnitName", "UnitPVPName", "GetGuildInfo", "UnitFactionGroup", "UnitClass", "UnitLevel", "IsInGroup", "InCombatLockdown" }) do keep[k] = env[k] end
    local out = {}
    local gt = { GetUnit = function() return "Arthas", "mouseover" end, GetName = function() return "PTipTest" end,
                 NumLines = function() return #texts end, ClearLines = function() out = {} end,
                 AddLine = function(_, t) out[#out + 1] = t end, AddDoubleLine = function(_, l, r) out[#out + 1] = l .. "=" .. r end,
                 Show = function() end, Hide = function() out.hidden = true end }
    for i = 1, 5 do env["PTipTestTextLeft" .. i] = FS(i); env["PTipTestTextRight" .. i] = FS(99) end
    env.GameTooltip = gt
    env.UnitIsPlayer = function() return true end
    env.UnitName = function() return "Arthas", nil end
    env.UnitPVPName = function() return "Champion Arthas" end
    env.GetGuildInfo = function() return "Imperium", "Officer", 2 end
    env.UnitFactionGroup = function() return "Alliance", "Alliance" end
    env.UnitClass = function() return "Paladin", "PALADIN" end
    env.UnitLevel = function() return 60 end
    env.IsInGroup = function() return false end
    local saved = {}
    for _, def in ipairs(ns.PLAYER_TIP_LINES) do saved[def[1]] = ns.db[def[1]]; ns.db[def[1]] = ns.defaults[def[1]] end
    ns.db.tipPvP, ns.db.tipFaction, ns.db.tipTitle = false, false, false
    ns.PlayerTipTest.OnUnit(gt)
    if #out ~= 3 or out[1] ~= "Arthas" or out[2] ~= "<Imperium>" or not tostring(out[3]):find("Level 60", 1, true) then
        error("the tooltip should be written again without the hidden lines: " .. table.concat(out, " | "))
    end
    -- put away during a fight
    ns.db.tipCombatHide = true
    env.InCombatLockdown = function() return true end
    ns.PlayerTipTest.OnUnit(gt)
    if not out.hidden then error("player tooltips should hide during a fight when chosen") end
    for k, v in pairs(saved) do ns.db[k] = v end
    for k, v in pairs(keep) do env[k] = v end
    for i = 1, 5 do env["PTipTestTextLeft" .. i] = nil; env["PTipTestTextRight" .. i] = nil end
end)
try("Quest sounds", function()
    local P = ns.QuestProgress
    if P({ done = 0, complete = false }, { done = 1, complete = false }) ~= "objective" then error("a finished objective should chime") end
    if P({ done = 1, complete = false }, { done = 2, complete = true }) ~= "complete" then error("a finished quest outranks its last objective") end
    if P({ done = 2, complete = true }, { done = 2, complete = true }) ~= nil then error("nothing changed, nothing plays") end
    if P({ done = 2, complete = false }, { done = 1, complete = false }) ~= nil then error("losing progress is not a reason to chime") end
    if P(nil, { done = 3, complete = true }) ~= nil then error("a quest seen for the first time plays nothing") end
    if type(ns.QuestSoundScan) ~= "function" then return end
    -- the whole log, read twice
    local QL = env.C_QuestLog
    local keep = { QL.GetNumQuestLogEntries, QL.GetInfo, QL.GetQuestObjectives, QL.IsComplete }
    local quests = { [11] = { { finished = false }, { finished = false } }, [22] = { { finished = true } } }
    local complete = {}
    QL.GetNumQuestLogEntries = function() return 3 end
    QL.GetInfo = function(i) return ({ { isHeader = true, title = "Elwynn" }, { questID = 11 }, { questID = 22 } })[i] end
    QL.GetQuestObjectives = function(id) return quests[id] end
    QL.IsComplete = function(id) return complete[id] == true end
    ns.QuestSoundScan()                                    -- first sight of everything
    if ns.QuestSoundScan() ~= nil then error("with nothing changed, nothing should play") end
    quests[11][1].finished = true
    if ns.QuestSoundScan() ~= "objective" then error("an objective finishing should be noticed") end
    quests[11][2].finished = true; complete[11] = true
    if ns.QuestSoundScan() ~= "complete" then error("the quest finishing should be noticed") end
    if ns.QuestSoundScan() ~= nil then error("it should be noticed once") end
    quests[33] = { { finished = true } }
    QL.GetNumQuestLogEntries = function() return 4 end
    local realInfo = QL.GetInfo
    QL.GetInfo = function(i) if i == 4 then return { questID = 33 } end return realInfo(i) end
    if ns.QuestSoundScan() ~= nil then error("a quest just accepted must not chime, whatever state it arrives in") end
    QL.GetNumQuestLogEntries, QL.GetInfo, QL.GetQuestObjectives, QL.IsComplete = keep[1], keep[2], keep[3], keep[4]
    ns.QuestSoundScan()
end)
try("Self-check: older function names", function()
    local L = ns.CheckFunctionLine
    local function client(present) return function(path) return present[path] == true end end
    -- this client: the newer functions are there, the older names are not
    local here = client({ ["C_Spell.GetSpellCooldown"] = true, ["C_CurrencyInfo.GetCoinTextureString"] = true,
                          ["C_SpecializationInfo.GetActiveSpecGroup"] = true, ["C_Reputation.SetWatchedFactionByIndex"] = true })
    for _, name in ipairs({ "GetSpellCooldown", "GetCoinTextureString", "GetActiveTalentGroup", "GetSpecialization", "SetWatchedFactionIndex" }) do
        local text, fault = L(name, here)
        if fault or text:find("MISSING", 1, true) or not text:find("is used instead", 1, true) then error(name .. " has a replacement and must not read as missing: " .. text) end
    end
    for _, name in ipairs({ "ActionButton_UpdateHotkeys", "GetPetHappiness" }) do
        local text, fault = L(name, here)
        if fault or text:find("MISSING", 1, true) then error(name .. " should be explained, not flagged: " .. text) end
    end
    -- present is simply ok
    local text, fault = L("C_Spell.GetSpellCooldown", here)
    if text ~= "ok" or fault then error("a function that is there is ok") end
    -- a real fault is still called one: no replacement known, or the replacement absent too
    text, fault = L("RollOnLoot", here)
    if text ~= "MISSING" or not fault then error("a function with nothing to use instead is a fault") end
    text, fault = L("GetSpellCooldown", client({}))
    if not fault or not text:find("MISSING", 1, true) then error("an older name whose replacement is absent too is a fault") end
end)
try("Help and the Combat tab", function()
    -- /fgui help: headings and commands, each command with something to say, none listed twice
    local seen, commands, headings = {}, 0, 0
    for _, line in ipairs(ns.helpLines) do
        if line[2] then
            commands = commands + 1
            if line[1]:sub(1, 5) ~= "/fgui" then error("a help line that is not a command: " .. line[1]) end
            if #line[2] < 10 then error(line[1] .. " has no explanation") end
            if seen[line[1]] then error(line[1] .. " is listed twice") end
            seen[line[1]] = true
        else
            headings = headings + 1
        end
    end
    if commands < 20 or headings < 3 then error("the help looks incomplete: " .. commands .. " commands under " .. headings .. " headings") end
    for _, must in ipairs({ "/fgui", "/fgui move", "/fgui check", "/fgui safe", "/fgui undo", "/fgui report" }) do
        if not seen[must] then error(must .. " is missing from the help") end
    end
    -- /fgui help: one window with every command, not chat; /fgui help <word> keeps the ones that mention it
    local listed = 0
    local realList = ns.ShowList
    ns.ShowList = function(_, key, title, rows) if key == "Help" then listed = #rows end return realList(ns, key, title, rows) end
    env.SlashCmdList.FANTASYGLASSUI("help")
    if listed ~= #ns.helpLines then error("/fgui help should list every heading and command: " .. listed) end
    env.SlashCmdList.FANTASYGLASSUI("help bags")
    ns.ShowList = realList
    if listed < 2 or listed >= #ns.helpLines then error("/fgui help bags should keep only the bag commands: " .. listed) end
    local m = ns.HelpMatches(ns.helpLines, "equipbest")
    if #m ~= 2 or m[1][2] or m[2][1] ~= "/fgui equipbest" then error("a match comes with its heading") end
    if #ns.HelpMatches(ns.helpLines, "zzzz") ~= 0 then error("nothing matches nonsense") end
    -- every Tools menu button has words from the help
    local without = {}
    for _, def in ipairs(ns.TOOL_MENU) do if not ns.HelpAbout(def[2], def[3]) then without[#without + 1] = def[2] end end
    if #without > 0 then error("Tools menu buttons the help says nothing of: " .. table.concat(without, ", ")) end
    -- a mistyped command gets a suggestion, not the options window
    if ns.ClosestCommand("equipbets") ~= "equipbest" then error("equipbets should suggest equipbest: " .. tostring(ns.ClosestCommand("equipbets"))) end
    if ns.ClosestCommand("zzzzzz") or ns.ClosestCommand("") then error("nonsense suggests nothing") end
    local printed = {}
    local realPrint = ns.Print
    ns.Print = function(_, f, ...) local ok, t = pcall(string.format, tostring(f), ...); printed[#printed + 1] = ok and t or tostring(f) end
    pcall(env.SlashCmdList.FANTASYGLASSUI, "equipbets")
    ns.Print = realPrint
    if not (printed[1] or ""):find("Did you mean", 1, true) then error("a typo should be answered: " .. tostring(printed[1])) end
    -- what the game does not allow in a fight is done when it ends, once
    env.InCombatLockdown = function() return true end
    local before = ns.AfterFightCount()
    ns:EquipBest(); ns:EquipBest()
    if ns.AfterFightCount() ~= before + 1 then error("asking twice in a fight should wait once") end
    env.InCombatLockdown = function() return false end
    fireEvent("PLAYER_REGEN_ENABLED"); runTimers()
    if ns.AfterFightCount() ~= 0 then error("the waiting job should run when the fight ends") end
    -- time in words, one way everywhere
    if ns.Ago(20) ~= "just now" or ns.Ago(600) ~= "10 min ago" or ns.Ago(7300) ~= "2 h ago" or ns.Ago(3 * 86400) ~= "3 days ago" then error("time ago in words: " .. ns.Ago(600)) end
    if ns.TimeLeft(90000) ~= "1 d 1 h" or ns.TimeLeft(3700) ~= "1 h 1 min" or ns.TimeLeft(30) ~= "1 min" then error("time left in words: " .. ns.TimeLeft(3700)) end
    -- /fgui reset is typed twice, and keeps a backup first
    do
        local reloads, realReload = 0, env.ReloadUI
        env.ReloadUI = function() reloads = reloads + 1 end
        local keep = ns.root.profiles[ns.profile]
        ns.root.profiles[ns.profile] = { theme = "probe" }
        ns:ResetProfileCommand(5000)
        if reloads ~= 0 or ns.root.profiles[ns.profile].theme ~= "probe" then error("one /fgui reset only asks") end
        ns:ResetProfileCommand(5020)
        if reloads ~= 0 then error("a second /fgui reset long after is asking again, not doing it") end
        ns:ResetProfileCommand(5025)
        if reloads ~= 1 or next(ns.root.profiles[ns.profile]) ~= nil then error("twice within ten seconds should reset and reload") end
        local b = ns.root.backups.reset
        if not b or b.profiles[ns.profile].theme ~= "probe" then error("the reset should keep a backup first") end
        ns.root.profiles[ns.profile] = keep
        ns.root.backups.reset = nil
        env.ReloadUI = realReload
    end
    -- a list window is kept where you leave it
    local lw = ns:ListWindow("PlaceTest", "Place test")
    rawset(lw, "GetPoint", function() return "TOPLEFT", env.UIParent, "TOPLEFT", 120.4, -80 end)
    for _, h in ipairs(handlers) do if h.self == lw and h.name == "OnDragStop" then h.fn(lw) end end
    local kept = ns.root.listPos and ns.root.listPos.PlaceTest
    if not kept or kept[1] ~= "TOPLEFT" or kept[3] ~= 120 then error("the window's place should be kept") end
    -- the Combat tab scrolls as far as its contents go, so another row of switches can never reach the footer
    ns:ToggleConfig("combat")
    local page = ns.combatPage
    if not page or not rawget(page, "area") then error("the Combat tab should be on a scrolling page") end
    if page.contentHeight < 520 then error("the Combat page's height should cover everything on it") end
    do   -- (the slices of the page shown in its sections reach exactly to its foot)
        local t, h = ns.optUI.Band(page, "Click casting")
        if t + h ~= page.contentHeight then error("the last slice should reach the foot of the page") end
    end
    -- opening the tab again shows the buff alerts you saved (it once read another setting and emptied them)
    local buffBoxes = rawget(page, "buffBoxes")
    if type(buffBoxes) == "table" and buffBoxes[1] then
        local keep, shown = ns.db.alertBuffs, {}
        for i, eb in ipairs(buffBoxes) do rawset(eb, "SetText", function(_, t) shown[i] = t end) end
        ns.db.alertBuffs = { "Power Word: Fortitude", "Bloodlust" }
        page.Refresh()
        for _, eb in ipairs(buffBoxes) do rawset(eb, "SetText", nil) end
        if shown[1] ~= "Power Word: Fortitude" or shown[2] ~= "Bloodlust" then
            error("the buff alert boxes should show the saved list: " .. tostring(shown[1])) end
        ns.db.alertBuffs = keep
    end
    ns:ToggleConfig()
end)
try("Switches that need no reload", function()
    local n = 0
    for key in pairs(ns.featureInstant) do
        n = n + 1
        if ns.defaults[key] == nil then error(key .. " is marked as instant but is not a setting") end
        if ns.loaded[key] ~= nil then error(key .. " starts a feature at login, so it cannot take effect at once") end
        local onTab = false
        for _, group in ipairs(ns.featureGroups) do for _, opt in ipairs(group[2]) do if opt[1] == key then onTab = true end end end
        if not onTab then error(key .. " is marked as instant but has no switch") end
    end
    if n < 10 then error("too few switches marked as instant") end
    ns:ApplyInstant()
end)
try("Memory: nothing built while idle", function()
    -- notifications: with nothing showing and nothing waiting, the ticker leaves at once
    for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.06) end end
    if ns.toastsIdle == nil then error("the notification ticker did not run") end
    -- confirmation boxes: the half-second pass touches only a box that is on screen
    if type(ns.PolishPopups) ~= "function" then error("the confirmation box pass is missing") end
    local touched = 0
    local box = known.StaticPopup3
    local yes = known.__popup.yes
    local realShown, realType = rawget(box, "IsShown"), rawget(yes, "GetObjectType")
    rawset(yes, "GetObjectType", function() touched = touched + 1; return "Button" end)     -- (each of its buttons is asked what it is)
    rawset(box, "IsShown", function() return false end)
    rawset(box, "IsVisible", function() return false end)
    ns.PolishPopups()
    if touched ~= 0 then error("a hidden confirmation box was worked on") end
    rawset(box, "IsShown", function() return true end)
    rawset(box, "IsVisible", function() return true end)
    ns.PolishPopups()
    if touched == 0 then error("a confirmation box on screen should be looked at") end
    rawset(box, "IsShown", realShown); rawset(yes, "GetObjectType", realType)
end)
try("Memory: unused languages are let go", function()
    local keep = {}
    for k, v in pairs(ns.locales) do keep[k] = v end
    local realLocale = env.GetLocale
    ns.keepAllLocales = true
    if ns:TrimLocales() ~= 0 or not ns.locales.deDE then error("the tests' own switch should hold the trim off") end
    ns.keepAllLocales = nil
    -- an English game: every language table goes
    env.GetLocale = function() return "enUS" end
    ns.root.language = nil
    ns:TrimLocales()
    if ns.locales.deDE or ns.locales.frFR or ns.locales.esES or ns.locales.esMX then error("on an English game no translation is needed") end
    -- a German choice: only German stays, and it still works
    for k, v in pairs(keep) do ns.locales[k] = v end
    ns.root.language = "deDE"; ns:LoadLocale()
    ns:TrimLocales()
    if not ns.locales.deDE or ns.locales.frFR or ns.locales.esES then error("only the language in use should be kept") end
    if ns:Tr("Unit frames") ~= "Einheitenfenster" then error("the language in use must keep working after the trim") end
    -- Spanish in Mexico shares the Spanish table: both names survive
    for k, v in pairs(keep) do ns.locales[k] = v end
    ns.root.language = nil
    env.GetLocale = function() return "esMX" end
    ns:TrimLocales()
    if not ns.locales.esMX or not ns.locales.esES or ns.locales.deDE then error("a shared table should be kept under both its names") end
    -- picking another language afterwards is saved, falls back to English for now, and raises no error
    env.GetLocale = function() return "enUS" end
    ns:TrimLocales()
    local keepTried = ns.localesLoadTried
    ns.localesLoadTried = true                             -- (the folder was loaded this session, then let go)
    if not ns:SetLanguage("frFR") or ns.root.language ~= "frFR" then error("a language can still be chosen after the trim") end
    if ns:Tr("Unit frames") ~= "Unit frames" then error("until the reload, text falls back to English") end
    for k, v in pairs(keep) do ns.locales[k] = v end
    ns.root.language = nil; ns.keepAllLocales = true; ns.localesTrimmed = nil; ns.localesLoadTried = keepTried
    env.GetLocale = realLocale
    ns:LoadLocale()
end)
try("Options folder missing or switched off", function()
    local said = {}
    local realPrint, realLoad, realEnable = ns.PrintRaw, rawget(env.C_AddOns, "LoadAddOn"), rawget(env.C_AddOns, "EnableAddOn")
    ns.PrintRaw = function(_, m) said[#said + 1] = tostring(m) end
    ns.optionsLoaded, ns.optionsWarned = nil, nil
    -- the folder is not there: nothing opens, nothing errors, and the player is told what to do, once
    optionsPresent = false
    for name, stub in pairs(ns.optionsStubs) do
        local ok, result = pcall(stub, ns)
        if not ok then error("ns:" .. name .. " raised with the options folder missing: " .. tostring(result)) end
        if result ~= nil then error("ns:" .. name .. " should do nothing without its folder") end
    end
    if #said ~= 1 then error("the missing folder should be explained once, not " .. #said .. " times") end
    if not said[1]:find("FantasyGlassUI_Options", 1, true) or not said[1]:find("MISSING", 1, true) then error("the message should name the folder and the reason: " .. said[1]) end
    if ns:LoadOptions() then error("loading should report failure") end
    -- switched off in the add-on list: it is switched on and loaded
    local enabled = false
    rawset(env.C_AddOns, "EnableAddOn", function(name) if name == "FantasyGlassUI_Options" then enabled = true end end)
    rawset(env.C_AddOns, "LoadAddOn", function()
        if not enabled then return false, "DISABLED" end
        ns.optionsLoaded = true
        return true
    end)
    if not ns:LoadOptions() or not enabled then error("a switched-off options folder should be switched on and loaded") end
    -- once loaded, nothing is loaded again
    local calls = 0
    rawset(env.C_AddOns, "LoadAddOn", function() calls = calls + 1; return true end)
    ns:LoadOptions(); ns:LoadOptions()
    if calls ~= 0 then error("the options must only be loaded once") end
    ns.PrintRaw = realPrint
    rawset(env.C_AddOns, "LoadAddOn", realLoad); rawset(env.C_AddOns, "EnableAddOn", realEnable)
    optionsPresent, ns.optionsLoaded = true, true
    env.SlashCmdList.FANTASYGLASSUI("memory")
end)
try("Info bar clicks", function()
    if type(ns.InfoBarClicked) ~= "function" then error("the info bar has no click handler") end
    local opened, pieces = 0, 0
    local realConfig, realPieces = ns.ToggleConfig, ns.ToggleInfoBarPieces
    ns.ToggleConfig = function() opened = opened + 1 end
    ns.ToggleInfoBarPieces = function() pieces = pieces + 1 end
    ns.InfoBarClicked(newmock(), "LeftButton")
    if opened ~= 1 or pieces ~= 0 then error("a left-click should open the options, and only that") end
    ns.InfoBarClicked(newmock(), "RightButton")
    if opened ~= 1 or pieces ~= 1 then error("a right-click should open the list of pieces, and only that") end
    ns.ToggleConfig, ns.ToggleInfoBarPieces = realConfig, realPieces
end)
try("Blocked actions are counted, with where they came from", function()
    if type(ns.NoteBlocked) ~= "function" or type(ns.BlockedLines) ~= "function" then error("nothing counts blocked actions") end
    local keep, keepSaved, keepBefore = ns.blocked, ns.root.blockedNow, ns.blockedBefore
    ns.blocked = { total = 0, list = {}, byKey = {} }; ns.blockedBefore = nil
    if table.concat(ns:BlockedLines(8), "\n") ~= "Blocked actions this session: none." then error("a clean session should say so in one line") end
    if ns:NoteBlocked("ADDON_ACTION_BLOCKED", "SomeOtherAddOn", "Frame:Show()", "") then error("another add-on's blocked action was counted as ours") end
    local stack = "[Interface/AddOns/FantasyGlassUI/Blocked.lua]:99: in function <Interface/AddOns/FantasyGlassUI/Blocked.lua:95>\n"
               .. "[C]: in function 'SetHeight'\n[Interface/AddOns/FantasyGlassUI/Tracker.lua]:213: in function <Interface/AddOns/FantasyGlassUI/Tracker.lua:120>"
    local combat = env.InCombatLockdown
    env.InCombatLockdown = function() return true end
    ns:NoteBlocked("ADDON_ACTION_BLOCKED", "FantasyGlassUI", "Frame:SetHeight()", stack)
    ns:NoteBlocked("ADDON_ACTION_BLOCKED", "FantasyGlassUI", "Frame:SetHeight()", stack)
    env.InCombatLockdown = function() return false end
    ns:NoteBlocked("ADDON_ACTION_FORBIDDEN", "FantasyGlassUI_Options", "CastSpellByName()", "Interface\\AddOns\\FantasyGlassUI_Options\\Config.lua:10: in function")
    env.InCombatLockdown = combat
    if ns.blocked.total ~= 3 or #ns.blocked.list ~= 2 then error("three refusals in two places: got " .. ns.blocked.total .. " in " .. #ns.blocked.list) end
    local text = table.concat(ns:BlockedLines(8), "\n")
    for _, want in ipairs({ "this session: 3", "2 x  Frame:SetHeight()", "from Tracker.lua:213", "options: Config.lua:10", "never allowed", "1 of them outside combat" }) do
        if not text:find(want, 1, true) then error("the report lacks \"" .. want .. "\":\n" .. text) end
    end
    if text:find("Blocked.lua", 1, true) then error("the counter named its own file as the culprit") end
    if type(ns.root.blockedNow) ~= "table" or ns.root.blockedNow.total ~= 3 then error("the count is not kept with the settings, so a reload would lose it") end
    -- the next login shows it as "before", and starts clean
    ns.blocked = { total = 0, list = {}, byKey = {} }; ns.blockedCarried = nil
    ns:BlockedCarryOver()
    text = table.concat(ns:BlockedLines(8), "\n")
    if not (text:find("this session: none", 1, true) and text:find("Before the last reload or login", 1, true) and text:find("Tracker.lua:213", 1, true)) then
        error("after a reload the earlier count should still be shown:\n" .. text)
    end
    if ns.root.blockedNow ~= nil then error("the earlier count was not cleared from the saved settings") end
    -- no more than a fixed number of places is remembered
    for i = 1, 60 do ns:NoteBlocked("ADDON_ACTION_BLOCKED", "FantasyGlassUI", "Frame:Thing" .. i .. "()", stack) end
    if #ns.blocked.list > 31 or ns.blocked.total ~= 60 then error("the list of places must stay bounded while the total keeps counting") end
    ns.blocked, ns.root.blockedNow, ns.blockedBefore = keep, keepSaved, keepBefore
end)
try("Nothing locked is shown, hidden or resized in combat", function()
    local combat = false
    local keep = env.InCombatLockdown
    env.InCombatLockdown = function() return combat end
    local function counted(f, method) local n = { 0 }; rawset(f, method, function() n[1] = n[1] + 1 end); return n end
    local function free(f, ...) for _, m in ipairs({ ... }) do rawset(f, m, nil) end end
    if ns:Locked(newmock()) then error("nothing is locked outside combat") end

    -- the quest tracker holds secure buttons: its panel may grow in a fight, the tracker itself may not
    local T = ns.trackerTest
    if not T then error("the quest tracker offers nothing to test") end
    rawset(T.tracker, "IsProtected", function() return true, false end)
    local outer, inner = counted(T.tracker, "SetHeight"), counted(T.body, "SetHeight")
    T.SetHeight(120)
    if outer[1] ~= 1 or inner[1] ~= 1 then error("outside combat both the tracker and its panel take the new height") end
    combat = true
    T.SetHeight(180)
    if outer[1] ~= 1 then error("the tracker (it holds secure buttons) was resized during combat") end
    if inner[1] ~= 2 then error("the tracker's panel should still follow the list during combat") end
    combat = false
    free(T.tracker, "IsProtected", "SetHeight"); free(T.body, "SetHeight")

    -- the bags' roaming "use" button lets go of its slot as a fight starts
    local bag = ns.bagTest["FantasyGlassUIBags"]
    local overlay = bag.overlay()
    if overlay then
        local slot = newmock(); slot.bag, slot.slot = 0, 1
        local cleared = counted(overlay, "ClearAllPoints")
        if not bag.Attach(slot) or rawget(overlay, "target") ~= slot then error("the roaming button did not take its place on the slot") end
        local was = cleared[1]
        fireEvent("PLAYER_REGEN_DISABLED")
        if rawget(overlay, "target") ~= nil or cleared[1] <= was then error("the roaming button stayed fixed to a bag slot into combat: the game would lock the whole bag window") end
        -- and if the game has the window locked all the same, it is not shown or hidden until the fight ends
        combat = true
        rawset(bag.win, "IsProtected", function() return true, false end)
        local shown, hidden = counted(bag.win, "Show"), counted(bag.win, "Hide")
        rawset(bag.win, "IsShown", function() return false end)
        for _ = 1, 3 do for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.2) end end end
        rawset(bag.win, "IsShown", function() return true end)
        for _ = 1, 3 do for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.2) end end end
        if shown[1] ~= 0 or hidden[1] ~= 0 then error("a locked bag window was shown or hidden during combat (" .. shown[1] .. " / " .. hidden[1] .. ")") end
        combat = false
        free(bag.win, "IsProtected", "Show", "Hide", "IsShown"); free(overlay, "ClearAllPoints")
    end

    -- the Menu button's list of secure rows lets go of the button as a fight starts
    if ns.menuList then
        local cleared = counted(ns.menuList, "ClearAllPoints")
        fireEvent("PLAYER_REGEN_DISABLED")
        if cleared[1] < 1 then error("the menu list stayed anchored to the Menu button into combat") end
        free(ns.menuList, "ClearAllPoints")
    end

    -- a panel hidden by a show rule is not shown again while the game has it locked
    local f = newmock()
    rawset(f, "IsProtected", function() return true, false end)
    local shows = counted(f, "Show")
    local entry = { frame = f, key = "lockTest", ruleHidden = "hide" }
    local keepRules = ns.db.panelShow
    ns.movables[#ns.movables + 1] = entry
    ns.db.panelShow = { lockTest = "COMBAT" }
    combat = true
    env.UnitAffectingCombat = function() return true end
    ns:PanelShowTick(); ns:PanelShowTick()
    if shows[1] ~= 0 then error("a show rule showed a locked frame during combat") end
    combat = false
    ns.db.panelShow = {}
    ns:PanelShowTick()
    if shows[1] ~= 1 or entry.ruleHidden ~= nil then error("after the fight the panel should come back") end
    table.remove(ns.movables)
    ns.db.panelShow = keepRules
    env.UnitAffectingCombat = nil
    env.InCombatLockdown = keep
end)
try("Gear set buttons", function()
    local E = known.C_EquipmentSet
    local keepIDs, keepInfo, keepUse = E.GetEquipmentSetIDs, E.GetEquipmentSetInfo, E.UseEquipmentSet
    local ids, used = { 3, 1, 2 }, {}
    E.GetEquipmentSetIDs = function() return ids end
    E.GetEquipmentSetInfo = function(id)
        if id == 1 then return "Tank", 111, 1, true, 16, 16, 0, 0, 0 end
        if id == 2 then return "Healing", 222, 2, false, 15, 4, 9, 2, 0 end
        return "Fishing", nil, 3, false, 3, 0, 3, 0, 0
    end
    E.UseEquipmentSet = function(id) used[#used + 1] = id; return true end
    if not ns:CanUseSets() then error("an equipment manager is there, and was not recognised") end
    local sets = ns:EquipmentSets()
    if #sets ~= 3 or sets[1].name ~= "Fishing" or sets[2].name ~= "Healing" or sets[3].name ~= "Tank" then error("three sets, A to Z") end
    local heal = sets[2]
    if heal.id ~= 2 or heal.worn or heal.items ~= 15 or heal.wearing ~= 4 or heal.missing ~= 2 then error("the Healing set was read wrongly") end
    local text = table.concat(ns.SetSummary(heal), " / ")
    for _, want in ipairs({ "4 of 15 pieces on", "2 pieces missing", "Click to wear this set" }) do
        if not text:find(want, 1, true) then error("the tooltip lacks \"" .. want .. "\": " .. text) end
    end
    text = table.concat(ns.SetSummary(sets[3]), " / ")
    if not text:find("You are wearing this set", 1, true) or text:find("missing", 1, true) then error("the set being worn should say so: " .. text) end

    -- one click asks the game for the set; in combat nothing is asked (the game would refuse)
    local combat = false
    local keepCombat = env.InCombatLockdown
    env.InCombatLockdown = function() return combat end
    if not ns:WearSet(heal) or used[1] ~= 2 then error("clicking a set should ask the game for it") end
    combat = true
    if ns:WearSet(sets[3]) or #used ~= 1 then error("a set was asked for during combat") end
    combat = false
    env.InCombatLockdown = keepCombat

    -- the row under the character window
    local T = ns.setsTest
    if not T then error("the gear set buttons did not start") end
    local win = newmock()
    if T.Refresh(win) ~= 3 then error("three sets should make three buttons") end
    if rawget(T.buttons[1], "set").name ~= "Fishing" or rawget(T.buttons[3], "set").name ~= "Tank" then error("the buttons are not in the sets' order") end
    ids = { 1 }                                             -- two sets deleted: their buttons go
    if T.Refresh(win) ~= 1 or rawget(T.buttons[2], "set") ~= nil or rawget(T.buttons[3], "set") ~= nil then error("deleted sets kept their buttons") end
    ids = {}
    local hidden = 0
    rawset(T.holder(), "Hide", function() hidden = hidden + 1 end)
    if T.Refresh(win) ~= 0 or hidden ~= 1 then error("with no sets saved, the row should not be there") end
    rawset(T.holder(), "Hide", nil)
    if not tostring(ns.setsState):find("no sets saved", 1, true) then error("the self-check should say there are no sets: " .. tostring(ns.setsState)) end

    -- more sets than fit: the first twelve
    ids = {}
    for i = 1, 15 do ids[i] = i end
    E.GetEquipmentSetInfo = function(id) return string.format("Set %02d", id), 1, id, false, 1, 0, 1, 0, 0 end
    if T.Refresh(win) ~= 12 or not tostring(ns.setsState):find("(of 15)", 1, true) then error("fifteen sets: twelve buttons, and the count said") end

    E.GetEquipmentSetIDs, E.GetEquipmentSetInfo, E.UseEquipmentSet = keepIDs, keepInfo, keepUse
end)
try("Stand up and dismount when an action needs it", function()
    env.SPELL_FAILED_NOT_STANDING, env.ERR_ATTACK_MOUNTED = "You must be standing to do that", "You are mounted"
    if ns.WhyFailed("You must be standing to do that") ~= "stand" or ns.WhyFailed("You are mounted") ~= "mounted" then error("the two error lines were not recognised") end
    if ns.WhyFailed("Out of range") or ns.WhyFailed(nil) or ns.WhyFailed(50) or ns.WhyFailed("") then error("another error was taken for one of the two") end
    if ns.WhyFailed(setmetatable({ __secret = true }, {})) then error("a hidden message was read") end

    -- never off a mount in the air or on a flight path; never when not mounted
    local off, stood = 0, 0
    env.Dismount = function() off = off + 1 end
    local realEmote = env.C_ChatInfo.PerformEmote
    env.C_ChatInfo.PerformEmote = function(what) if what == "STAND" then stood = stood + 1 end; return true end
    local flying, taxi, mounted = true, false, true
    env.IsFlying = function() return flying end
    env.UnitOnTaxi = function() return taxi end
    env.IsMounted = function() return mounted end
    if ns:GetOffMount() or off ~= 0 then error("dismounted in the air") end
    flying, taxi = false, true
    if ns:GetOffMount() or off ~= 0 then error("dismounted on a flight path") end
    taxi, mounted = false, false
    if ns:GetOffMount() or off ~= 0 then error("dismounted while not mounted") end
    mounted = true
    env.IsFlying = function() return setmetatable({ __secret = true }, {}) end
    if ns:GetOffMount() or off ~= 0 then error("the game would not say whether you are flying: that must count as flying") end
    env.IsFlying = function() return flying end
    if not ns:GetOffMount() or off ~= 1 then error("on the ground and mounted: should dismount") end

    -- the red error line does it, once per press, and only for the switch that is on
    local clock = 500
    env.GetTime = function() return clock end
    local keepStand, keepOff = ns.db.autoStand, ns.db.autoDismount
    ns.db.autoStand, ns.db.autoDismount = true, true
    fireEvent("UI_ERROR_MESSAGE", 50, "You must be standing to do that")
    if stood ~= 1 then error("sitting: should stand up (stood " .. stood .. " times)") end
    fireEvent("UI_ERROR_MESSAGE", 50, "You must be standing to do that")
    if stood ~= 1 then error("the same press raised the line twice: stand up once") end
    clock = clock + 2
    fireEvent("UI_ERROR_MESSAGE", 50, "You are mounted")
    if off ~= 2 then error("mounted: should dismount") end
    clock = clock + 2
    fireEvent("UI_ERROR_MESSAGE", 50, "Out of range")
    if stood ~= 1 or off ~= 2 then error("an unrelated error did something") end
    ns.db.autoStand, ns.db.autoDismount = false, false
    fireEvent("UI_ERROR_MESSAGE", 50, "You must be standing to do that")
    fireEvent("UI_ERROR_MESSAGE", 50, "You are mounted")
    if stood ~= 1 or off ~= 2 then error("switched off, and it still acted") end
    for _, key in ipairs({ "autoStand", "autoDismount", "autoRes", "autoSummon" }) do
        if ns.defaults[key] ~= false then error(key .. " acts for you: it must ship switched off") end
    end
    ns.db.autoStand, ns.db.autoDismount = keepStand, keepOff
    env.C_ChatInfo.PerformEmote = realEmote
    for _, k in ipairs({ "GetTime", "Dismount", "IsFlying", "UnitOnTaxi", "IsMounted", "SPELL_FAILED_NOT_STANDING", "ERR_ATTACK_MOUNTED" }) do env[k] = nil end
end)
try("Accepting resurrections and summons", function()
    if ns.ResurrectDecision(false, false) ~= "accept" or ns.ResurrectDecision(true, false) ~= "fighting"
       or ns.ResurrectDecision(nil, false) ~= "fighting" or ns.ResurrectDecision(false, true) ~= "shift" then error("the resurrection rule is wrong") end
    if ns.SummonDecision(true, true, false) ~= "accept" or ns.SummonDecision(true, true, true) ~= "wait"
       or ns.SummonDecision(false, true, false) ~= "drop" or ns.SummonDecision(true, false, false) ~= "drop" then error("the summon rule is wrong") end

    local R = known.__res
    R.offerer, R.delay, R.combat, R.accepted = "Healer", 0, false, 0
    runTimers()
    fireEvent("RESURRECT_REQUEST", "Healer")
    if R.accepted ~= 1 then error("a resurrection from someone out of combat should be accepted") end
    R.combat = true
    fireEvent("RESURRECT_REQUEST", "Healer")
    if R.accepted ~= 1 then error("a resurrection cast mid-fight must be left for the player") end
    R.combat = false
    env.IsShiftKeyDown = function() return true end
    fireEvent("RESURRECT_REQUEST", "Healer")
    if R.accepted ~= 1 then error("holding Shift should leave the resurrection alone") end
    env.IsShiftKeyDown = nil
    R.delay = 10                                            -- one that can only be taken after a wait
    fireEvent("RESURRECT_REQUEST", "Healer")
    if R.accepted ~= 1 then error("a resurrection with a wait was accepted before the wait was over") end
    runTimers()
    if R.accepted ~= 2 then error("after the wait it should be accepted") end
    fireEvent("RESURRECT_REQUEST", "Healer")
    R.offerer = nil                                         -- withdrawn during the wait
    runTimers()
    if R.accepted ~= 2 then error("an offer that had gone was accepted") end
    R.offerer, R.delay = "Healer", 0

    local S = known.__summon
    local combat = false
    local keepCombat = env.InCombatLockdown
    env.InCombatLockdown = function() return combat end
    S.who, S.left, S.confirmed = "Warlock", 60, 0
    fireEvent("CONFIRM_SUMMON")
    if S.confirmed ~= 0 then error("a summon was accepted at once: there should be a few seconds to decline") end
    local said = false
    for _, line in ipairs(printed) do if line:find("Warlock", 1, true) and line:find("Orgrimmar", 1, true) then said = true end end
    if not said then error("chat should say who the summon is from and where it leads") end
    runTimers()
    if S.confirmed ~= 1 then error("after the few seconds the summon should be accepted") end
    fireEvent("CONFIRM_SUMMON"); fireEvent("CANCEL_SUMMON"); runTimers()
    if S.confirmed ~= 1 then error("a summon declined in time was accepted anyway") end
    combat = true
    fireEvent("CONFIRM_SUMMON"); runTimers()
    if S.confirmed ~= 1 then error("a summon was accepted during combat") end
    combat = false
    fireEvent("PLAYER_REGEN_ENABLED"); runTimers()
    if S.confirmed ~= 2 then error("when the fight ends a waiting summon should be accepted") end
    fireEvent("CONFIRM_SUMMON"); S.who = "Someone else"; runTimers()
    if S.confirmed ~= 2 then error("the offer changed hands during the wait and was still accepted") end
    S.who = "Warlock"
    fireEvent("CONFIRM_SUMMON"); S.left = 0; runTimers()
    if S.confirmed ~= 2 then error("a summon that had run out was accepted") end
    S.left = 60
    env.IsShiftKeyDown = function() return true end
    fireEvent("CONFIRM_SUMMON"); runTimers()
    if S.confirmed ~= 2 then error("holding Shift should leave the summon alone") end
    env.IsShiftKeyDown = nil
    env.InCombatLockdown = keepCombat
end)
try("Chat history covers every chat tab", function()
    local T = ns.chatHistoryTest
    if not T then error("chat history did not start") end
    local byIndex = {}
    for _, tab in ipairs(T.tabs) do byIndex[tab.index] = tab end
    if not byIndex[1] or not byIndex[3] then error("the main tab and the other chat tabs should all be kept") end
    if byIndex[2] then error("the combat log must not be kept") end
    local key = ns:CharKey()
    local function fill(tab, lines)
        tab.mark, tab.carried = 0, {}
        rawset(tab.chat, "GetNumMessages", function() return #lines end)
        rawset(tab.chat, "GetMessageInfo", function(_, i) local l = lines[i]; return l[1], l[2] or 1, l[3] or 1, l[4] or 1 end)
    end
    local long = {}
    for i = 1, 55 do long[i] = { "line " .. i, 1, 0.5, 0.25 } end
    fill(byIndex[1], long)
    fill(byIndex[3], { { "a whisper", 1, 0.5, 1 }, { setmetatable({ __secret = true }, {}) }, { "hidden |Kq1|k name" }, { string.rep("x", 700) }, { "kept" } })
    for index, tab in pairs(byIndex) do if index ~= 1 and index ~= 3 then fill(tab, {}) end end
    T.Save()
    local saved = ns.root.chatHistory[key]
    if type(saved) ~= "table" or type(saved.tabs) ~= "table" or type(saved.at) ~= "number" then error("nothing was saved") end
    local main = saved.tabs[1]
    if #main ~= 40 or main[1][1] ~= "line 16" or main[40][1] ~= "line 55" then error("the main tab keeps its last 40 lines, got " .. #main) end
    if main[40][3] ~= 0.5 then error("a line's color should be kept") end
    local third = saved.tabs[3]
    if #third ~= 2 or third[1][1] ~= "a whisper" or third[2][1] ~= "kept" then error("the third tab should keep its two readable lines, got " .. #third) end
    for index in pairs(saved.tabs) do if index ~= 1 and index ~= 3 then error("an empty tab was saved") end end
    -- lines brought back last time stay ahead of the new ones
    byIndex[3].carried = { { "from before", 1, 1, 1 } }
    T.Save()
    third = ns.root.chatHistory[key].tabs[3]
    if #third ~= 3 or third[1][1] ~= "from before" then error("lines restored earlier should be kept in front of the new ones") end
    -- nothing to keep: nothing is left in the settings file
    for _, tab in pairs(byIndex) do fill(tab, {}) end
    T.Save()
    if ns.root.chatHistory[key] ~= nil then error("with no lines to keep, nothing should be saved") end
    for _, tab in pairs(byIndex) do rawset(tab.chat, "GetNumMessages", nil); rawset(tab.chat, "GetMessageInfo", nil) end
    if ns.defaults.chatHistory ~= true then error("chat history was already there for the main tab: it stays on") end
end)
try("Greed on green items", function()
    local D = ns.GreedDecision
    if D(2, false, true, false) ~= true then error("a plain green should be rolled on") end
    if D(3, false, true, false) or D(4, false, true, false) or D(1, false, true, false) then error("only green items") end
    if D(2, true, true, false) then error("a green that binds when picked up is left for the player") end
    if D(2, false, false, false) then error("no Greed offered: nothing to roll") end
    if D(2, false, true, true) then error("a possible upgrade is left for the player") end
    if D(setmetatable({ __secret = true }, { __index = function() error("read") end }), false, true, false) and secretMode then error("a hidden roll was acted on") end
    if ns:RollMightBeUpgrade(nil) then error("no link: not an upgrade") end
    if ns.defaults.autoGreed ~= false then error("rolling for you must ship switched off") end

    local rolled = {}
    local info = { 1, "Cloth Belt", 1, 2, false, true, true, false }
    env.GetLootRollItemInfo = function() return info[1], info[2], info[3], info[4], info[5], info[6], info[7], info[8] end
    env.GetLootRollItemLink = function() return nil end
    env.RollOnLoot = function(id, kind) rolled[#rolled + 1] = { id, kind } end
    fireEvent("START_LOOT_ROLL", 7, 60000)
    if #rolled ~= 1 or rolled[1][1] ~= 7 or rolled[1][2] ~= 2 then error("a green should get one Greed roll (got " .. #rolled .. ")") end
    info[4] = 3
    fireEvent("START_LOOT_ROLL", 8, 60000)
    if #rolled ~= 1 then error("a blue item was rolled on") end
    info[4], info[5] = 2, true
    fireEvent("START_LOOT_ROLL", 9, 60000)
    if #rolled ~= 1 then error("a bind-on-pickup green was rolled on") end
    info[5] = false
    local real = ns.RollMightBeUpgrade
    ns.RollMightBeUpgrade = function() return true end
    fireEvent("START_LOOT_ROLL", 10, 60000)
    if #rolled ~= 1 then error("an upgrade was rolled on") end
    if not tostring(ns.greedLast):find("upgrade", 1, true) then error("the self-check should say why the last roll was left: " .. tostring(ns.greedLast)) end
    ns.RollMightBeUpgrade = real
    env.GetLootRollItemInfo, env.GetLootRollItemLink, env.RollOnLoot = nil, nil, nil
end)
try("Game settings as switches", function()
    local store = { cameraDistanceMaxZoomFactor = "1.9", Sound_EnableErrorSpeech = "1", Sound_EnableSoundWhenGameIsInBG = "0" }
    local realC, keepBefore = env.C_CVar, ns.root.tweakBefore
    env.C_CVar = { GetCVar = function(name) return store[name] end, SetCVar = function(name, value) store[name] = tostring(value) end }
    local keep = {}
    for _, t in ipairs(ns.TWEAKS) do
        keep[t.key] = ns.db[t.key]; ns.db[t.key] = false
        if ns.defaults[t.key] ~= false then error(t.key .. " changes a game setting: it must ship switched off") end
        if not ns.featureInstant[t.key] then error(t.key .. " should take effect at once") end
    end
    ns.root.tweakBefore = nil
    ns:ApplyTweaks()
    if store.cameraDistanceMaxZoomFactor ~= "1.9" or store.Sound_EnableErrorSpeech ~= "1" or next(ns.root.tweakBefore) then error("with every switch off, nothing may change") end
    if not tostring(ns.tweakState.tweakScreenshot):find("no such setting", 1, true) then error("a setting this client lacks should be reported") end

    ns.db.tweakCamera = true
    ns:ApplyTweaks()
    if store.cameraDistanceMaxZoomFactor ~= "2.6" or ns.root.tweakBefore.cameraDistanceMaxZoomFactor ~= "1.9" then error("camera: set to 2.6, remembering 1.9") end
    ns.db.tweakCamera = false
    ns:ApplyTweaks()
    if store.cameraDistanceMaxZoomFactor ~= "1.9" or ns.root.tweakBefore.cameraDistanceMaxZoomFactor ~= nil then error("camera: switching off puts 1.9 back") end

    ns.db.tweakCamera = true
    ns:ApplyTweaks()
    store.cameraDistanceMaxZoomFactor = "2.0"               -- changed by hand afterwards
    ns.db.tweakCamera = false
    ns:ApplyTweaks()
    if store.cameraDistanceMaxZoomFactor ~= "2.0" then error("a setting you changed yourself since must be left as you set it") end

    store.cameraDistanceMaxZoomFactor = "3.4"               -- already further out than the switch asks
    ns.db.tweakCamera = true
    ns:ApplyTweaks()
    if store.cameraDistanceMaxZoomFactor ~= "3.4" then error("the camera switch must never pull the camera in") end
    ns.db.tweakCamera = false
    ns:ApplyTweaks()

    ns.db.tweakErrorVoice, ns.db.tweakBgSound = true, true
    local combat = true
    local keepCombat = env.InCombatLockdown
    env.InCombatLockdown = function() return combat end
    if ns:ApplyTweaks() or store.Sound_EnableErrorSpeech ~= "1" then error("game settings are not changed during combat") end
    combat = false
    fireEvent("PLAYER_REGEN_ENABLED")
    if store.Sound_EnableErrorSpeech ~= "0" or store.Sound_EnableSoundWhenGameIsInBG ~= "1" then error("after the fight the waiting change should be made") end
    env.InCombatLockdown = keepCombat
    ns.db.tweakErrorVoice, ns.db.tweakBgSound = false, false
    ns:ApplyTweaks()
    if store.Sound_EnableErrorSpeech ~= "1" or store.Sound_EnableSoundWhenGameIsInBG ~= "0" then error("switching off puts both sound settings back") end

    -- 10.7: the new game settings
    local seen = {}
    for _, t in ipairs(ns.TWEAKS) do
        if seen[t.cvar] then error("two switches change " .. t.cvar) end
        seen[t.cvar] = true
        if ns.featureDesc and not ns.featureDesc[t.key] then error(t.key .. " has no description") end
    end
    if #ns.TWEAKS < 18 then error("expected the fourteen new game settings, have " .. #ns.TWEAKS) end
    -- a background frame-rate cap only ever lowers the frame rate (0 is "no limit", so that is lowered too)
    for _, case in ipairs({ { "60", "30" }, { "20", "20" }, { "0", "30" } }) do
        store.maxFPSBk = case[1]; ns.root.tweakBefore.maxFPSBk = nil
        ns.db.tweakBgFps = true; ns:ApplyTweaks()
        if store.maxFPSBk ~= case[2] then error("background frame rate " .. case[1] .. " should become " .. case[2] .. ", is " .. tostring(store.maxFPSBk)) end
        ns.db.tweakBgFps = false; ns:ApplyTweaks()
        if store.maxFPSBk ~= case[1] then error("switching off puts " .. case[1] .. " back, is " .. tostring(store.maxFPSBk)) end
    end
    store.autoLootDefault, store.nameplateMotion = "0", "0"
    ns.db.tweakAutoLoot, ns.db.tweakPlateStack = true, true; ns:ApplyTweaks()
    if store.autoLootDefault ~= "1" or store.nameplateMotion ~= "1" then error("auto loot and stacking nameplates should be on") end
    ns.db.tweakAutoLoot, ns.db.tweakPlateStack = false, false; ns:ApplyTweaks()
    if store.autoLootDefault ~= "0" or store.nameplateMotion ~= "0" then error("and off again") end

    for _, t in ipairs(ns.TWEAKS) do ns.db[t.key] = keep[t.key] end
    env.C_CVar, ns.root.tweakBefore = realC, keepBefore
end)
try("Damage meter: a drawer on the chat box", function()
    local M = ns.meterTest
    if not M then error("the damage meter did not start") end
    if not M.docked or ns.defaults.meterDock ~= true then error("the meter should be a drawer on the chat box unless switched back") end

    -- how many bars fit beside the chat box, with and without the threat list under them
    if ns.MeterRowsThatFit(190, 0) ~= 8 or ns.MeterRowsThatFit(190, 3) ~= 4 then error("rows that fit in a 190 tall chat box: " .. ns.MeterRowsThatFit(190, 0) .. " and " .. ns.MeterRowsThatFit(190, 3)) end
    if ns.MeterRowsThatFit(30, 0) ~= 1 or ns.MeterRowsThatFit(1000, 0) ~= 12 or ns.MeterRowsThatFit(nil, 0) ~= 8 then error("the number of rows has limits") end

    -- bars: name, and "per second - total"
    local data = { maxAmount = 2600, combatSources = {
        { name = "Kaladin", classFilename = "WARRIOR", totalAmount = 2600, amountPerSecond = 330 },
        { name = "Shallan", classFilename = "MAGE", totalAmount = 2400, amountPerSecond = 306 } } }
    local keepGet = rawget(env.C_DamageMeter, "GetCombatSessionFromType")
    rawset(env.C_DamageMeter, "GetCombatSessionFromType", function() return data end)
    env.AbbreviateNumbers = function(v) if v >= 1000 then return string.format("%.1fK", v / 1000) end return tostring(math.floor(v)) end
    local values, names, hid, scale, filled = {}, {}, 0, {}, {}
    for i = 1, 2 do
        rawset(M.rows[i].value, "SetText", function(_, s) values[i] = s end)
        rawset(M.rows[i].name, "SetText", function(_, s) names[i] = s end)
        rawset(M.rows[i], "SetMinMaxValues", function(_, _, max) scale[i] = max end)
        rawset(M.rows[i], "SetValue", function(_, v) filled[i] = v end)
    end
    rawset(M.rows[3], "Hide", function() hid = hid + 1 end)
    env.UnitExists = function() return false end           -- (no target yet)
    local shown, threat = M.Refresh()
    if shown ~= 2 or threat ~= 0 then error("two players and no threat list, got " .. tostring(shown) .. " and " .. tostring(threat)) end
    if values[1] ~= "330" or values[2] ~= "306" then error("a bar should read damage per second: " .. tostring(values[1])) end
    if not tostring(ns.meterReading):find("per second", 1, true) then error("the self-check should say the meter reads per second: " .. tostring(ns.meterReading)) end
    if scale[1] ~= 330 or filled[2] ~= 306 then error("bars are measured in damage per second against the leader: " .. tostring(scale[1]) .. " / " .. tostring(filled[2])) end
    if names[1] ~= "Kaladin" or names[2] ~= "Shallan" then error("names on the bars") end
    if hid < 1 then error("rows with nobody in them should be hidden") end
    -- whole numbers only: 138.2342352 reads "138"
    data.combatSources[1].amountPerSecond = 138.2342352352342
    data.combatSources[2].amountPerSecond = 99.5
    M.Refresh()
    if values[1] ~= "138" or values[2] ~= "100" then error("a bar should read a whole number, got " .. tostring(values[1]) .. " and " .. tostring(values[2])) end
    local asked
    local label = newmock()
    rawset(label, "SetFormattedText", function(_, fmt) asked = fmt end)
    ns.MeterValueText(label, setmetatable({ __secret = true }, secretmt))
    if asked ~= "%.0f" then error("a hidden amount should be written by the game without decimals") end
    data.combatSources[1].amountPerSecond, data.combatSources[2].amountPerSecond = 330, 306
    -- where the per-second amount comes from, in order of preference
    local P = ns.MeterPerSecond
    local v, how = P({ amountPerSecond = 330, totalAmount = 2600 }, {}, true)
    if v ~= 330 or how ~= "figure" then error("the game's own per-second figure comes first") end
    v, how = P({ totalAmount = 330 }, {}, true)
    if v ~= 330 or how ~= "list" then error("from the game's per-second list, the amount given is per second") end
    v, how = P({ totalAmount = 2600 }, { durationSeconds = 8 }, false)
    if v ~= 325 or how ~= "computed" then error("otherwise: the total over the length of the fight, got " .. tostring(v)) end
    v, how = P({ totalAmount = 2600 }, {}, false)
    if v ~= nil or how ~= nil then error("with nothing to go on there is no per-second amount") end
    v, how = P({ totalAmount = setmetatable({ __secret = true }, {}) }, { durationSeconds = 8 }, false)
    if secretMode and v ~= nil then error("a hidden total cannot be divided") end
    for i = 1, 2 do rawset(M.rows[i], "SetMinMaxValues", nil); rawset(M.rows[i], "SetValue", nil) end

    -- threat on the target: highest first, three at most, and only when there is someone to compare with
    local sorted = ns.SortThreat({ { unit = "a", pct = 40 }, { unit = "b", pct = 100 }, { unit = "c", pct = 70 } })
    if sorted[1].unit ~= "b" or sorted[2].unit ~= "c" or sorted[3].unit ~= "a" then error("threat should be sorted highest first") end
    local hiddenList, readable = ns.SortThreat({ { unit = "a", pct = 40 }, { unit = "b", pct = setmetatable({}, {}) } })
    if readable or hiddenList[1].unit ~= "a" then error("amounts that cannot be read cannot be sorted: the order stays") end
    local there = { target = true, player = true, party1 = true, party2 = true, party3 = true }
    local pct = { player = 70, party1 = 100, party2 = 84, party3 = 12 }
    local grouped = true
    env.UnitExists = function(u) return there[u] == true end
    env.UnitCanAttack = function() return true end
    env.IsInRaid = function() return false end
    env.IsInGroup = function() return grouped end
    env.UnitDetailedThreatSituation = function(u) return false, 1, pct[u] end
    env.UnitName = function(u) return ({ player = "Shallan", party1 = "Kaladin", party2 = "Daylight", party3 = "Lift", target = "Sadeas" })[u] end
    env.UnitClass = function() return "Mage", "MAGE" end
    local list = ns:ThreatOnTarget()
    if not list or #list ~= 3 or list[1].unit ~= "party1" or list[2].unit ~= "party2" or list[3].unit ~= "player" then error("the three highest on threat, in order") end
    local tNames, tValues = {}, {}
    for i = 1, 3 do
        rawset(M.threatRows[i].name, "SetText", function(_, s) tNames[i] = s end)
        rawset(M.threatRows[i].value, "SetText", function(_, s) tValues[i] = s end)
    end
    shown, threat = M.Refresh()
    if threat ~= 3 or tNames[1] ~= "Kaladin" or tValues[1] ~= "100%" or tNames[2] ~= "Daylight" or tValues[2] ~= "84%" or tValues[3] ~= "70%" then
        error("the threat list should read Kaladin 100%, Daylight 84%, Shallan 70%: " .. tostring(tNames[1]) .. " " .. tostring(tValues[1]))
    end
    grouped = false
    there.party1, there.party2, there.party3 = nil, nil, nil
    if ns:ThreatOnTarget() ~= nil then error("alone, there is no threat list: everything is on you") end
    grouped, there.party1 = true, true
    env.UnitCanAttack = function() return false end
    if ns:ThreatOnTarget() ~= nil then error("a friendly target has no threat list") end

    -- the drawer: its tab, and /fgui meter, tuck it away and bring it out; the choice is remembered
    local keepOpen = ns.db.meterOpen
    M.SetOpen(false, true)
    if M.IsOpen() or ns.db.meterOpen ~= false then error("tucked away: remembered as such") end
    M.SetOpen(true, true)
    if not M.IsOpen() or ns.db.meterOpen ~= true then error("brought out: remembered as such") end
    ns:ToggleMeter()
    if M.IsOpen() then error("/fgui meter should tuck an open drawer away") end
    ns:ToggleMeter()
    if not M.IsOpen() then error("/fgui meter should bring it out again") end
    -- it comes out on the side of the chat box that faces the middle of the screen
    rawset(env.ChatFrame1, "GetCenter", function() return 1700, 200 end)
    rawset(env.UIParent, "GetWidth", function() return 1920 end)
    M.SetOpen(true, true)
    if M.Side() ~= "LEFT" then error("chat on the right of the screen: the drawer should come out on its left") end
    rawset(env.ChatFrame1, "GetCenter", function() return 250, 200 end)
    M.SetOpen(true, true)
    if M.Side() ~= "RIGHT" then error("chat on the left of the screen: the drawer should come out on its right") end
    rawset(env.ChatFrame1, "GetCenter", nil); rawset(env.UIParent, "GetWidth", nil)
    M.SetOpen(keepOpen ~= false, true)
    ns.db.meterOpen = keepOpen

    for i = 1, 3 do
        for _, part in ipairs({ "name", "value" }) do
            if M.rows[i][part] then rawset(M.rows[i][part], "SetText", nil); rawset(M.rows[i][part], "SetFormattedText", nil) end
            rawset(M.threatRows[i][part], "SetText", nil)
        end
    end
    rawset(M.rows[3], "Hide", nil)
    rawset(env.C_DamageMeter, "GetCombatSessionFromType", keepGet)
    for _, k in ipairs({ "AbbreviateNumbers", "UnitExists", "UnitCanAttack", "IsInRaid", "IsInGroup", "UnitDetailedThreatSituation", "UnitName", "UnitClass" }) do env[k] = nil end
end)
try("Hidden values are never compared", function()
    if not ns.Is(true, true) or ns.Is(true, false) or not ns.Is("MAGE", "MAGE") or ns.Is(nil, false) or not ns.Is(nil, nil) then error("plain values compare as usual") end
    local hidden = setmetatable({ __secret = true }, secretmt)
    if ns.Is(hidden, true) or ns.Is(hidden, false) or ns.Is(hidden, "MAGE") or ns.Is("MAGE", hidden) or ns.Is(hidden, hidden) then error("a hidden value is never equal to anything") end
    -- a hidden yes/no is never tested: it counts as "no"
    if not ns.Yes(true) or not ns.Yes(1) or not ns.Yes("x") or ns.Yes(false) or ns.Yes(nil) then error("plain values test as usual") end
    if ns.Yes(hidden) then error("a hidden yes/no must count as no") end
    -- a resurrection whose caster's combat state is hidden is left for the player
    if ns.ResurrectDecision(hidden, false) ~= "fighting" then error("a hidden combat state must count as fighting") end
    -- dismounting: a hidden "are you mounted" must not be read as "not mounted", and must not raise an error
    env.IsFlying = function() return false end
    env.UnitOnTaxi = function() return false end
    env.IsMounted = function() return hidden end
    env.Dismount = function() end
    local ok, can = pcall(ns.CanDismount, ns)
    if not ok then error("a hidden answer raised an error: " .. tostring(can)) end
    for _, k in ipairs({ "IsFlying", "UnitOnTaxi", "IsMounted", "Dismount" }) do env[k] = nil end
end)
try("Crafting bar and profession icons", function()
    local keepT = env.C_TradeSkillUI
    local info = { professionID = 165, professionName = "Leatherworking" }
    local gameIcon = 133611
    env.C_TradeSkillUI = { GetBaseProfessionInfo = function() return info end, GetTradeSkillTexture = function(id) if id == 165 then return gameIcon end end }
    -- the icon: the game's own first, then your list of professions, then the add-on's table
    local icon, from = ns:ProfessionIcon()
    if icon ~= 133611 or not from:find("game", 1, true) then error("the game's own icon for the profession comes first") end
    gameIcon = nil
    env.GetProfessions = function() return 1, 2, nil, 4 end
    env.GetProfessionInfo = function(i) if i == 2 then return "Leatherworking", 136247, 75, 150, 2, 0, 165 end return "Skinning", 134366, 1, 75, 1, 0, 393 end
    icon, from = ns:ProfessionIcon()
    if icon ~= 136247 or not from:find("your list", 1, true) then error("then the icon from your own list of professions, got " .. tostring(icon)) end
    env.GetProfessions, env.GetProfessionInfo = false, false
    icon, from = ns:ProfessionIcon()
    if icon ~= "Interface\\Icons\\Trade_LeatherWorking" then error("then the add-on's table, got " .. tostring(icon)) end
    info = { professionID = 2575, parentProfessionID = 186, professionName = "Smelting" }
    if ns:ProfessionIcon() ~= "Interface\\Icons\\Trade_Mining" then error("a branch of a profession (smelting) shows its parent's icon") end
    for line, label in pairs({ [164] = "blacksmithing", [171] = "alchemy", [185] = "cooking", [197] = "tailoring", [202] = "engineering", [333] = "enchanting", [755] = "jewelcrafting", [773] = "inscription", [129] = "first aid" }) do
        info = { professionID = line }
        if type(ns:ProfessionIcon()) ~= "string" then error("no icon for " .. label) end
    end
    info = { professionID = 99999 }
    if ns:ProfessionIcon() ~= nil then error("an unknown profession has no icon: the cast keeps its own") end

    -- the cast bar's icon: the profession's while crafting, the spell's own otherwise
    info = { professionID = 165 }
    local keepSwitch = ns.db.craftBar
    ns.db.craftBar = true
    if ns:CraftIcon(true, 136243) ~= "Interface\\Icons\\Trade_LeatherWorking" then error("a craft should show the profession's icon") end
    if ns:CraftIcon(false, 135812) ~= 135812 then error("an ordinary spell keeps its own icon") end
    -- how a craft is recognised: the game's flag, or the spell being a recipe, or (when the game says
    -- nothing either way) a profession window being open
    local windows = { "ProfessionsFrame", "TradeSkillFrame", "CraftFrame" }
    for _, w in ipairs(windows) do env[w] = false end
    if ns:IsCraft(nil, 2881) or ns:IsCraft(false, 2881) then error("no flag, no recipe, no window: not a craft") end
    if not ns:IsCraft(true, 2881) then error("the game's own flag is believed") end
    -- every spell has a skill line, and the game answers "which line is this recipe in" for any spell:
    -- only a profession's line makes it a craft (a mage's "Arcane" line, number 237, does not)
    env.C_TradeSkillUI.GetTradeSkillLineForRecipe = function(id) if id == 2881 then return 165, "Leatherworking" end return 237, "Arcane" end
    env.C_TradeSkillUI.GetRecipeInfo = function(id) return { recipeID = id, name = "Something", icon = 1 } end      -- (answers for any spell too)
    local yes, why = ns:IsCraft(false, 2881)
    if not yes or not why:find("profession", 1, true) then error("a spell in a profession's skill line is a craft, whatever the flag says") end
    if ns:IsCraft(false, 1326080) then error("an ordinary spell (line 237, Arcane) was taken for a craft") end
    if ns:CraftIcon(false, 236222, 1326080) ~= 236222 then error("an ordinary spell must keep its own icon") end
    if ns:CraftProfession(1326080) ~= nil and ns:CraftProfession(1326080).line == 237 then error("a class skill line is not a profession") end
    if not ns.IsProfessionLine(165) or ns.IsProfessionLine(237) then error("165 is a profession's line, 237 is not") end
    env.C_TradeSkillUI.GetTradeSkillLineForRecipe = nil
    env.C_TradeSkillUI.GetRecipeInfo = nil
    local open = newmock(); rawset(open, "IsVisible", function() return true end)
    env.ProfessionsFrame = open
    yes, why = ns:IsCraft(nil, 2881)
    if not yes or not why:find("ProfessionsFrame", 1, true) then error("no flag at all, and the profession window open: taken as a craft") end
    if ns:IsCraft(false, 2881) then error("the game saying \"not a craft\" outweighs an open window") end
    for _, w in ipairs(windows) do env[w] = false end
    -- the profession can be told from the recipe itself, or from the open profession's name alone
    local keepBase = env.C_TradeSkillUI.GetBaseProfessionInfo
    env.C_TradeSkillUI.GetBaseProfessionInfo = nil
    env.C_TradeSkillUI.GetProfessionInfoByRecipeID = function(id) if id == 2881 then return { professionID = 165, professionName = "Leatherworking" } end end
    local prof = ns:CraftProfession(2881)
    if not prof or prof.line ~= 165 or prof.via ~= "GetProfessionInfoByRecipeID" then error("the profession should be told from the recipe") end
    env.C_TradeSkillUI.GetProfessionInfoByRecipeID = nil
    env.C_TradeSkillUI.GetBaseProfessionInfo = function() return { professionName = "Leatherworking" } end
    prof = ns:CraftProfession(2881)
    if not prof or prof.name ~= "Leatherworking" or ns:ProfessionIcon(prof) ~= "Interface\\Icons\\Trade_LeatherWorking" then error("a name alone is enough to find the icon") end
    env.C_TradeSkillUI.GetBaseProfessionInfo = function() return nil end
    if ns:CraftProfession(2881) ~= nil then error("no profession open: none is reported") end
    -- nothing known about the profession: the recipe's own picture is better than the placeholder
    env.C_TradeSkillUI.GetRecipeInfo = function() return { recipeID = 2881, name = "Light Leather", icon = 134251 } end
    if ns:CraftIcon(true, 136243, 2881) ~= 134251 then error("with no profession to be found, the recipe's own icon is used") end
    env.C_TradeSkillUI.GetRecipeInfo = nil
    env.C_TradeSkillUI.GetBaseProfessionInfo = keepBase
    for _, w in ipairs(windows) do env[w] = nil end
    -- what the self-check will say about a craft
    env.UnitCastingInfo = function() return "Light Leather", nil, 136243, 100000, 105000, true, "cast-1", false, 2881 end
    local facts = table.concat(ns:CraftFacts() or {}, "\n")
    for _, want in ipairs({ "\"Light Leather\"", "9 details", "craft flag true", "spell number 2881", "taken as a craft: yes", "number 165", "Trade_LeatherWorking" }) do
        if not facts:find(want, 1, true) then error("the self-check's account of a craft lacks " .. want .. ":\n" .. facts) end
    end
    env.UnitCastingInfo = nil
    ns.db.craftBar = false
    if ns:CraftIcon(true, 136243) ~= 136243 then error("switched off: the cast keeps the game's picture") end
    ns.db.craftBar = true

    -- the game's crafting bar is found and replaced while a craft runs
    local C = ns.craftTest
    if not C then error("the crafting bar did not start") end
    C.Forget()
    local game = newmock()
    rawset(game, "GetObjectType", function() return "StatusBar" end)
    rawset(game, "IsVisible", function() return true end)
    rawset(game, "IsShown", function() return true end)
    env.OverlayPlayerCastingBarFrame = game
    local shownName, shownIcon
    rawset(C.name, "SetText", function(_, s) shownName = s end)
    rawset(C.icon, "SetTexture", function(_, s) shownIcon = s end)
    local cast = { "Light Leather", nil, 136243, 100000, 105000, true }
    env.UnitCastingInfo = function(u) if u == "player" and cast then return cast[1], cast[2], cast[3], cast[4], cast[5], cast[6] end end
    fireEvent("UNIT_SPELLCAST_START", "player")
    if not C.IsCovering() or C.Host() ~= game then error("the game's crafting bar should be found and replaced") end
    if shownName ~= "Light Leather" or shownIcon ~= "Interface\\Icons\\Trade_LeatherWorking" then error("our bar should name the craft and show the leatherworking icon: " .. tostring(shownName) .. " / " .. tostring(shownIcon)) end
    if not ns.craftCovering then error("the ordinary cast bar should be told to stand aside") end
    if not tostring(ns.craftState):find("OverlayPlayerCastingBarFrame", 1, true) then error("the self-check should say which bar was replaced: " .. tostring(ns.craftState)) end
    cast = nil
    fireEvent("UNIT_SPELLCAST_STOP", "player")
    if C.IsCovering() or C.IsCasting() or ns.craftCovering then error("when the craft ends our bar goes too") end
    -- an ordinary spell is none of its business
    cast = { "Fireball", nil, 135812, 100000, 103000, false }
    fireEvent("UNIT_SPELLCAST_START", "player")
    if C.IsCovering() or C.IsCasting() then error("a spell that is not a craft was treated as one") end
    -- no bar of the game's to be found: the craft is still followed, and the self-check says so
    C.Forget()
    env.OverlayPlayerCastingBarFrame, env.TradeSkillCastingBarFrame, env.ProfessionsCastingBarFrame = false, false, false
    rawset(env.UIParent, "GetChildren", function() return end)
    cast = { "Light Leather", nil, 136243, 100000, 105000, true }
    fireEvent("UNIT_SPELLCAST_START", "player")
    if C.IsCovering() or not C.IsCasting() then error("with no bar to replace, nothing is covered") end
    if not tostring(ns.craftState):find("not found", 1, true) then error("the self-check should say the bar was not found: " .. tostring(ns.craftState)) end
    cast = nil
    fireEvent("UNIT_SPELLCAST_STOP", "player")

    rawset(env.UIParent, "GetChildren", nil)
    rawset(C.name, "SetText", nil); rawset(C.icon, "SetTexture", nil)
    env.OverlayPlayerCastingBarFrame, env.UnitCastingInfo, env.GetProfessions, env.GetProfessionInfo = nil, nil, nil, nil
    env.TradeSkillCastingBarFrame, env.ProfessionsCastingBarFrame = nil, nil
    env.C_TradeSkillUI = keepT
    ns.db.craftBar = keepSwitch
    C.Forget()
end)
try("The chat typing bar sits under the chat box", function()
    if ns.defaults.chatEditTop ~= false then error("by default the typing bar goes under the chat box, clear of the tabs") end
    local point, anchor, side, gap = ns.ChatEditPlace(false)
    if point ~= "TOP" or anchor ~= "BOTTOM" or gap >= 0 or not side:find("under", 1, true) then error("under the chat box: its top edge meets the chat's bottom edge") end
    point, anchor, side, gap = ns.ChatEditPlace(true)
    if point ~= "BOTTOM" or anchor ~= "TOP" or gap <= 0 or not side:find("above", 1, true) then error("above, when chosen: its bottom edge meets the chat's top edge") end
    if not tostring(ns.chatEditState):find("chat box", 1, true) then error("the self-check should say where the typing bar was put: " .. tostring(ns.chatEditState)) end
end)
try("A moved action bar is held in place through a fight", function()
    -- the margins that make "kept on screen" mean "kept exactly here"
    local l, r, t, b = ns.PinInsets(100, 500, 300, 250, 1920, 1080)
    if l ~= -100 or r ~= 1420 or t ~= 780 or b ~= -250 then error("the margins for a frame at 100..500 x 250..300 on a 1920x1080 screen are wrong: " .. l .. " " .. r .. " " .. t .. " " .. b) end
    local frame = newmock()
    local protected = true
    for name, value in pairs({ GetLeft = 100, GetRight = 500, GetTop = 300, GetBottom = 250, GetEffectiveScale = 1, GetWidth = 400, GetHeight = 50, GetScale = 1, GetNumPoints = 0 }) do
        rawset(frame, name, function() return value end)
    end
    rawset(frame, "IsProtected", function() return protected, protected end)
    rawset(frame, "IsClampedToScreen", function() return false end)
    rawset(frame, "GetClampRectInsets", function() return 0, 0, 0, 0 end)
    local insets, clamped
    rawset(frame, "SetClampRectInsets", function(_, a, b2, c, d) insets = { a, b2, c, d } end)
    rawset(frame, "SetClampedToScreen", function(_, v) clamped = v end)
    rawset(env.UIParent, "GetWidth", function() return 1920 end)
    rawset(env.UIParent, "GetHeight", function() return 1080 end)
    rawset(env.UIParent, "GetEffectiveScale", function() return 1 end)
    local wasMoving = ns.moving
    ns.moving = false
    ns.db.pos.pinTest = { "CENTER", "CENTER", 0, 0 }
    local before = #ns.movables
    local info, entry = ns:AdoptGameFrame(frame, "pinTest", "Pin test")
    if not info then error("the frame was not adopted") end
    entry.onMoved()
    if not info.pinned or clamped ~= true then error("a moved, locked frame should be pinned where it was put") end
    if insets[1] ~= -100 or insets[2] ~= 1420 or insets[3] ~= 780 or insets[4] ~= -250 then error("pinned with the wrong margins") end
    local report = table.concat(ns:AdoptedReport(), "\n")
    if not report:find("pinTest: held in place through fights", 1, true) then error("the self-check should say the frame is held: " .. report) end
    -- arranging the screen: let go while move mode is on, hold again when it ends
    ns:ToggleMove()
    if info.pinned or clamped ~= false or insets[1] ~= 0 then error("move mode should let the frame go") end
    ns:ToggleMove()
    if not info.pinned or clamped ~= true or insets[1] ~= -100 then error("leaving move mode should hold it again") end
    -- never changed during combat (the game would refuse)
    local keep = env.InCombatLockdown
    env.InCombatLockdown = function() return true end
    insets, clamped = nil, nil
    entry.onMoved()
    if insets ~= nil or clamped ~= nil or not info.pending then error("in combat nothing may be changed: it waits for the fight to end") end
    env.InCombatLockdown = keep
    -- "Reset" gives the frame back as the game had it
    entry.onReset()
    if info.pinned or clamped ~= false or insets[1] ~= 0 or insets[4] ~= 0 then error("Reset should undo the pin") end
    -- a frame the game does not lock needs no pin: it is put back the moment it is moved
    protected = false
    insets, clamped = nil, nil
    entry.onMoved()
    if info.pinned or insets ~= nil then error("an unlocked frame should not be pinned") end
    entry.onReset()
    for i = #ns.adopted, 1, -1 do if ns.adopted[i] == info then table.remove(ns.adopted, i) end end
    while #ns.movables > before do table.remove(ns.movables) end
    ns.db.pos.pinTest = nil
    ns.moving = wasMoving
    for _, k in ipairs({ "GetWidth", "GetHeight", "GetEffectiveScale" }) do rawset(env.UIParent, k, nil) end
end)
try("Raid tools set markers through secure buttons", function()
    local R = ns.raidToolsTest
    if not R then error("the raid tools did not start") end
    if #R.markers ~= 18 then error("eight target markers, eight ground markers and a clear button for each, got " .. #R.markers) end
    for i = 1, 8 do
        if R.markers[i].command ~= "/tm " .. i then error("marker " .. i .. " should run /tm " .. i) end
    end
    if R.markers[9].command ~= "/tm 0" then error("the X should clear the marker with /tm 0") end
    -- ground markers: the game's own secure "world marker" action, one per marker, and one to clear them all
    for i = 1, 8 do
        local a = R.markers[9 + i].attributes
        if a.type ~= "worldmarker" or a.marker ~= i or a.action ~= "toggle" then error("ground marker " .. i .. " is set up wrongly") end
    end
    local all = R.markers[18].attributes
    if all.type ~= "worldmarker" or all.action ~= "clear" or all.marker ~= nil then error("the ground row's X should clear every ground marker") end
    local seen = {}
    for i, icon in ipairs(ns.raidGroundIcons) do seen[icon] = true end
    for icon = 1, 8 do if not seen[icon] then error("each ground marker needs its own picture") end end
    if ns.raidGroundIcons[1] ~= 6 or ns.raidGroundIcons[5] ~= 1 or ns.raidGroundIcons[8] ~= 8 then error("ground markers run square, triangle, diamond, cross, star, circle, moon, skull") end
    -- nothing in the add-on may call the game's own marker function: the game forbids it
    for file, src in pairs(sources) do
        if not tostring(file):find("Locales", 1, true) then
            for line in tostring(src):gmatch("[^\n]+") do
                if line:find("SetRaidTarget%(") and not line:find("^%s*%-%-") then error(tostring(file) .. " still calls SetRaidTarget, which the game forbids add-ons: " .. line) end
            end
        end
    end
    if not tostring(ns.raidToolsState):find("/tm", 1, true) then error("the self-check should say how markers are set: " .. tostring(ns.raidToolsState)) end
end)
try("Damage meter: more views, your own row, reset, opening itself", function()
    local M = ns.meterTest
    local keepView, keepOpen, keepAuto = ns.db.meterView, ns.db.meterOpen, ns.db.meterAuto
    if #M.views ~= 9 then error("nine views when the game offers them all, got " .. #M.views) end
    local order = {}
    for i, v in ipairs(M.views) do order[i] = v.key end
    if table.concat(order, " ") ~= "dps hps damage healing taken absorbs interrupts dispels deaths" then error("the views are out of order: " .. table.concat(order, " ")) end
    while M.View() ~= "dps" do M.Step(1) end
    M.Step(1)
    if M.View() ~= "hps" or ns.db.meterView ~= "hps" then error("stepping should move to the next view and remember it") end
    M.Step(-1); M.Step(-1)
    if M.View() ~= "deaths" then error("stepping back from the first view wraps to the last") end
    M.Step(1)

    -- a totals view reads the total, measured against the largest; a per-second view reads per second
    local data = { maxAmount = 5000, combatSources = {
        { name = "Kaladin", classFilename = "WARRIOR", totalAmount = 5000, amountPerSecond = 330, isLocalPlayer = false },
        { name = "Shallan", classFilename = "MAGE", totalAmount = 1200, amountPerSecond = 80, isLocalPlayer = true } } }
    local keepGet = rawget(env.C_DamageMeter, "GetCombatSessionFromType")
    rawset(env.C_DamageMeter, "GetCombatSessionFromType", function() return data end)
    env.UnitExists = function() return false end
    local values, scale, mine = {}, {}, {}
    for i = 1, 2 do
        rawset(M.rows[i].value, "SetText", function(_, s) values[i] = s end)
        rawset(M.rows[i], "SetMinMaxValues", function(_, _, max) scale[i] = max end)
        rawset(M.rows[i].me, "Show", function() mine[i] = true end)
        rawset(M.rows[i].me, "Hide", function() mine[i] = false end)
    end
    while M.View() ~= "taken" do M.Step(1) end
    if values[1] ~= "5000" or values[2] ~= "1200" or scale[1] ~= 5000 then error("damage taken should read totals against the largest: " .. tostring(values[1]) .. " / " .. tostring(scale[1])) end
    if not tostring(ns.meterReading):find("totals", 1, true) then error("the self-check should say this view reads totals") end
    while M.View() ~= "dps" do M.Step(1) end
    if values[1] ~= "330" or scale[1] ~= 330 then error("back on damage per second it should read per second") end
    -- your own row is marked: by the game's word, or else by your name
    if mine[1] ~= false or mine[2] ~= true then error("only your own row should be marked") end
    data.combatSources[1].isLocalPlayer, data.combatSources[2].isLocalPlayer = nil, nil
    env.UnitName = function(u) if u == "player" then return "Kaladin" end return "x" end
    M.Refresh()
    if mine[1] ~= true or mine[2] ~= false then error("without the game's word, the row with your name is yours") end
    env.UnitName = nil

    -- reset asks the game to clear its totals
    local resets = 0
    rawset(env.C_DamageMeter, "ResetAllCombatSessions", function() resets = resets + 1 end)
    if not ns:ResetMeter() or resets ~= 1 then error("resetting should clear the game's totals once") end
    rawset(env.C_DamageMeter, "ResetAllCombatSessions", nil)

    -- opening itself for a fight: out as it starts, away a few seconds after, and not remembered as your choice
    if ns.defaults.meterAuto ~= false then error("the drawer opening itself is off until chosen") end
    ns.db.meterAuto = false
    M.SetOpen(false, true)
    fireEvent("PLAYER_REGEN_DISABLED")
    if M.IsOpen() then error("switched off, the drawer must stay as it is when a fight starts") end
    fireEvent("PLAYER_REGEN_ENABLED"); runTimers()
    ns.db.meterAuto = true
    fireEvent("PLAYER_REGEN_DISABLED")
    if not M.IsOpen() or not M.AutoOpened() then error("the drawer should come out as a fight starts") end
    if ns.db.meterOpen ~= false then error("opening for a fight must not be remembered as your choice") end
    fireEvent("PLAYER_REGEN_ENABLED")
    if not M.IsOpen() then error("it should stay out for a few seconds after the fight") end
    runTimers()
    if M.IsOpen() or M.AutoOpened() then error("a few seconds after the fight it should tuck itself away") end
    -- touch the tab during the fight and it is left alone
    fireEvent("PLAYER_REGEN_DISABLED")
    ns:ToggleMeter(); ns:ToggleMeter()
    if not M.IsOpen() or M.AutoOpened() then error("opened by hand: it is yours now") end
    fireEvent("PLAYER_REGEN_ENABLED"); runTimers()
    if not M.IsOpen() then error("a drawer you opened yourself must not be tucked away for you") end
    -- already out when the fight starts: nothing to do, and it is not closed afterwards
    fireEvent("PLAYER_REGEN_DISABLED"); fireEvent("PLAYER_REGEN_ENABLED"); runTimers()
    if not M.IsOpen() then error("a drawer that was already out stays out") end

    for i = 1, 2 do
        rawset(M.rows[i].value, "SetText", nil); rawset(M.rows[i], "SetMinMaxValues", nil)
        rawset(M.rows[i].me, "Show", nil); rawset(M.rows[i].me, "Hide", nil)
    end
    rawset(env.C_DamageMeter, "GetCombatSessionFromType", keepGet)
    env.UnitExists = nil
    while M.View() ~= (keepView or "dps") do M.Step(1) end
    ns.db.meterView, ns.db.meterAuto = keepView, keepAuto
    M.SetOpen(keepOpen ~= false, true)
    ns.db.meterOpen = keepOpen
end)
try("Gear sets follow the talent set", function()
    local S = ns.SetForSpec
    local sets = { { id = 1, name = "Tank", worn = true }, { id = 2, name = "Heal", worn = false } }
    local set, why = S({ [2] = "Heal" }, 2, sets)
    if not set or set.id ~= 2 then error("the remembered set for the talent set should be chosen") end
    set, why = S({ [1] = "Tank" }, 1, sets)
    if set or not why:find("already", 1, true) then error("a set already worn is not put on again") end
    set, why = S({}, 2, sets)
    if set or not why:find("no gear set remembered", 1, true) then error("nothing remembered: nothing to do") end
    set, why = S({ [2] = "Gone" }, 2, sets)
    if set or not why:find("no longer exists", 1, true) then error("a deleted set cannot be worn") end
    if ns.defaults.setsFollowSpec ~= false then error("changing gear for you must ship switched off") end

    local T = ns.specSetTest
    if not T then error("gear sets following the talent set did not start") end
    local E = known.C_EquipmentSet
    local keepIDs, keepInfo, keepUse = E.GetEquipmentSetIDs, E.GetEquipmentSetInfo, E.UseEquipmentSet
    local worn, used, spec = 1, {}, 1
    E.GetEquipmentSetIDs = function() return { 1, 2 } end
    E.GetEquipmentSetInfo = function(id) return (id == 1) and "Tank" or "Heal", 1, id, worn == id, 10, 10, 0, 0, 0 end
    E.UseEquipmentSet = function(id) used[#used + 1] = id; worn = id; return true end
    local keepSpec = env.C_SpecializationInfo.GetActiveSpecGroup
    env.C_SpecializationInfo.GetActiveSpecGroup = function() return spec end
    for k in pairs(T.memory) do T.memory[k] = nil end
    T.SetSpec(1)
    -- wearing a set while a talent set is active is what teaches it
    fireEvent("EQUIPMENT_SWAP_FINISHED", true, 1)
    if T.memory[1] ~= "Tank" then error("the set put on in talent set 1 should be remembered for it") end
    fireEvent("EQUIPMENT_SWAP_FINISHED", false, 2)
    if T.memory[1] ~= "Tank" then error("a change that did not go through must not be remembered") end
    spec = 2
    T.Follow()
    if #used ~= 0 then error("nothing remembered for talent set 2 yet: nothing should be worn") end
    worn = 2
    fireEvent("EQUIPMENT_SWAP_FINISHED", true, 2)
    if T.memory[2] ~= "Heal" or T.memory[1] ~= "Tank" then error("each talent set remembers its own gear set") end
    -- switching back puts the remembered set on
    spec = 1
    T.Follow()
    if #used ~= 1 or used[1] ~= 1 then error("back in talent set 1, its gear set should go on") end
    T.Follow()
    if #used ~= 1 then error("with no change of talent set, nothing more should happen") end
    -- not during combat: once the fight is over
    local combat = true
    local keepCombat = env.InCombatLockdown
    env.InCombatLockdown = function() return combat end
    spec = 2
    T.Follow()
    if #used ~= 1 then error("gear must not be changed during combat") end
    combat = false
    fireEvent("PLAYER_REGEN_ENABLED")
    if #used ~= 2 or used[2] ~= 2 then error("after the fight the waiting gear set should go on") end
    env.InCombatLockdown = keepCombat
    env.C_SpecializationInfo.GetActiveSpecGroup = keepSpec
    for k in pairs(T.memory) do T.memory[k] = nil end
    E.GetEquipmentSetIDs, E.GetEquipmentSetInfo, E.UseEquipmentSet = keepIDs, keepInfo, keepUse
end)
try("Whisper invites and declined duels", function()
    local W = ns.WhisperAsksInvite
    if not W("inv", "inv") or not W("Inv", "inv") or not W("  INV!  ", "inv") or not W("inv.", "inv") then error("the word alone, in any case, with stray punctuation, asks for an invite") end
    if W("inv please", "inv") or W("invite", "inv") or W("", "inv") or W(nil, "inv") or W("inv", "") then error("anything more than the word is not a request") end
    if W(setmetatable({ __secret = true }, secretmt), "inv") then error("a hidden whisper cannot be read") end
    for _, key in ipairs({ "whisperInvite", "whisperInviteAll", "declineDuels" }) do
        if ns.defaults[key] ~= false then error(key .. " acts for you: it must ship switched off") end
    end
    local keepWord, keepAll = ns.db.whisperInviteWord, ns.db.whisperInviteAll
    ns.db.whisperInviteWord = "   "
    if ns:InviteWord() ~= "inv" then error("a blank word falls back to inv") end
    ns.db.whisperInviteWord = "summon"
    if ns:InviteWord() ~= "summon" then error("/fgui invword should change the word") end
    ns.db.whisperInviteWord, ns.db.whisperInviteAll = "inv", false

    local invited = known.__invited
    for i = #invited, 1, -1 do invited[i] = nil end
    local realKnown = ns.IsKnownPerson
    local friends = { Adolin = true }
    ns.IsKnownPerson = function(_, name) return friends[name] and "friend" or nil end
    local grouped, leader = false, false
    env.IsInGroup = function() return grouped end
    env.UnitIsGroupLeader = function() return leader end
    env.UnitIsGroupAssistant = function() return false end
    local clock = 1000
    env.GetTime = function() return clock end
    fireEvent("CHAT_MSG_WHISPER", "inv", "Adolin")
    if #invited ~= 1 or invited[1] ~= "Adolin" then error("a friend who whispers inv should be invited") end
    fireEvent("CHAT_MSG_WHISPER", "inv", "Adolin")
    if #invited ~= 1 then error("the same person asking again at once is invited only once") end
    clock = clock + 30
    fireEvent("CHAT_MSG_WHISPER", "hello there", "Adolin")
    fireEvent("CHAT_MSG_WHISPER", "inv", "Stranger")
    if #invited ~= 1 then error("ordinary whispers and strangers must not be invited") end
    ns.db.whisperInviteAll = true
    fireEvent("CHAT_MSG_WHISPER", "inv", "Stranger")
    if #invited ~= 2 or invited[2] ~= "Stranger" then error("with \"from anyone\" on, a stranger is invited") end
    grouped = true                                          -- in someone else's group: you cannot invite
    fireEvent("CHAT_MSG_WHISPER", "inv", "Dalinar")
    if #invited ~= 2 then error("not leading the group: nobody can be invited") end
    leader = true
    fireEvent("CHAT_MSG_WHISPER", "inv", "Dalinar")
    if #invited ~= 3 then error("leading the group: the invite goes out") end
    ns.IsKnownPerson = realKnown
    ns.db.whisperInviteWord, ns.db.whisperInviteAll = keepWord, keepAll
    for _, k in ipairs({ "IsInGroup", "UnitIsGroupLeader", "UnitIsGroupAssistant", "GetTime" }) do env[k] = nil end

    known.__duels = 0
    fireEvent("DUEL_REQUESTED", "Sadeas")
    if known.__duels ~= 1 then error("a duel request should be declined") end
    local said = false
    for _, line in ipairs(printed) do if line:find("Sadeas", 1, true) and line:find("duel", 1, true) then said = true end end
    if not said then error("chat should say whose duel was declined") end
    env.IsShiftKeyDown = function() return true end
    fireEvent("DUEL_REQUESTED", "Sadeas")
    if known.__duels ~= 1 then error("holding Shift should leave the duel for you to answer") end
    env.IsShiftKeyDown = nil
end)
try("Damage meter: earlier fights and a player's abilities", function()
    local P = ns.MeterPastSessions
    local past = P({ { sessionID = 1, name = "Boar" }, { sessionID = 2, name = "Wolf" }, { sessionID = 3 } }, 6)
    if #past ~= 3 or past[1].id ~= 3 or past[1].label ~= nil or past[2].label ~= "Wolf" or past[3].id ~= 1 then error("earlier fights should come newest first, with their names") end
    if #P({ { sessionID = 1 }, { sessionID = 2 }, { sessionID = 3 } }, 2) ~= 2 then error("no more earlier fights than asked for") end
    if #P(nil) ~= 0 or #P({ "x", {}, { name = "no number" } }) ~= 0 then error("anything that is not a fight is left out") end

    local keepName = env.C_Spell and env.C_Spell.GetSpellName
    local realSpell = env.C_Spell
    env.C_Spell = { GetSpellName = function(id) return ({ [1] = "Lightning Bolt", [2] = "Bite" })[id] end }
    local detail = { combatSpells = { { spellID = 1, totalAmount = 900, amountPerSecond = 30 }, { spellID = 2, totalAmount = 100, creatureName = "Spirit Wolf" } } }
    local spells = ns.MeterSpells(detail, true, 8)
    if #spells ~= 2 or spells[1].name ~= "Lightning Bolt" or spells[1].amount ~= 30 then error("abilities by name, per second on a per-second view") end
    if spells[2].name ~= "Bite (Spirit Wolf)" or spells[2].amount ~= 100 then error("a pet's ability carries the pet's name; with no per-second figure, the total") end
    if ns.MeterSpells(detail, false, 8)[1].amount ~= 900 then error("on a totals view the total is listed") end
    if #ns.MeterSpells(detail, false, 1) ~= 1 then error("no more abilities than asked for") end
    local none, why = ns.MeterSpells({ maxAmount = 5, totalAmount = 9 }, false, 8)
    if none ~= nil or not why:find("maxAmount, totalAmount", 1, true) then error("with no list of abilities, the self-check is told what did arrive: " .. tostring(why)) end

    -- the heading's right-click goes: this fight, overall, each earlier fight, and round again
    local M = ns.meterTest
    local DM = env.C_DamageMeter
    local byID, byType = 0, 0
    local data = { maxAmount = 10, combatSources = { { name = "Kaladin", classFilename = "WARRIOR", totalAmount = 10, amountPerSecond = 1, sourceGUID = "Player-1" } } }
    rawset(DM, "GetAvailableCombatSessions", function() return { { sessionID = 11, name = "Boar" }, { sessionID = 12, name = "Wolf" } } end)
    rawset(DM, "GetCombatSessionFromID", function(id) byID = id; return data end)
    local keepGet = rawget(DM, "GetCombatSessionFromType")
    rawset(DM, "GetCombatSessionFromType", function() byType = byType + 1; return data end)
    env.UnitExists = function() return false end
    while M.Session().id or M.Session()[1] ~= "This fight" do M.NextSession() end
    M.NextSession()
    if M.Session()[1] ~= "Overall" then error("after this fight comes overall") end
    M.NextSession()
    if M.Session().id ~= 12 or M.Session().label ~= "Wolf" then error("then the newest earlier fight") end
    M.Refresh()
    if byID ~= 12 then error("an earlier fight is fetched by its own number") end
    M.NextSession()
    if M.Session().id ~= 11 then error("then the one before it") end
    M.NextSession()
    if M.Session()[1] ~= "This fight" then error("and round again to this fight") end

    -- pointing at a row asks the game for that player's abilities
    local askedFor
    rawset(DM, "GetCombatSessionSourceFromType", function(_, _, guid) askedFor = guid; return detail end)
    local list = ns.MeterBreakdownOf(data.combatSources[1])
    if askedFor ~= "Player-1" or not list or #list ~= 2 then error("the breakdown should be asked for that player and come back with their abilities") end
    rawset(DM, "GetCombatSessionSourceFromType", function() error("no") end)
    local nothing, reason = ns.MeterBreakdownOf(data.combatSources[1])
    if nothing ~= nil or not tostring(reason):find("refused", 1, true) then error("if the game refuses, that is reported, not raised") end

    for _, k in ipairs({ "GetAvailableCombatSessions", "GetCombatSessionFromID", "GetCombatSessionSourceFromType" }) do rawset(DM, k, nil) end
    rawset(DM, "GetCombatSessionFromType", keepGet)
    env.C_Spell = realSpell
    env.UnitExists = nil
end)
try("Vendors, loot, role checks, combat alerts and speed", function()
    -- movement speed on the info bar: off until chosen
    env.GetUnitSpeed = function() return 7, 7 end
    if ns.SpeedPercent() ~= 100 then error("an ordinary run is 100%") end
    env.GetUnitSpeed = function() return 0, 14 end
    if ns.SpeedPercent() ~= 200 then error("standing still shows what you would do if you set off (200% mounted)") end
    env.GetUnitSpeed = function() return setmetatable({ __secret = true }, secretmt), 7 end
    if ns.SpeedPercent() ~= nil then error("a hidden speed shows nothing") end
    env.GetUnitSpeed = function() return 7, 7 end
    local keepParts = ns.db.infobarParts
    ns.db.infobarParts = nil
    if ns.InfoBarPieceOn("speed") then error("the speed piece is off until chosen") end
    if ns.InfoBarCompose():find("speed", 1, true) then error("unchosen, speed must not be on the bar") end
    ns.db.infobarParts = { speed = true }
    if not ns.InfoBarPieceOn("speed") or not ns.InfoBarCompose():find("100%%|r speed") then error("chosen, the bar should read 100% speed: " .. ns.InfoBarCompose()) end
    ns.db.infobarParts = keepParts
    env.GetUnitSpeed = nil

    -- at a vendor: what you already know is marked
    if ns.defaults.vendorKnown ~= true then error("marking known items only adds information: on by default") end
    env.ITEM_SPELL_KNOWN = "Already known"
    local realTip = env.C_TooltipInfo
    env.C_TooltipInfo = { GetMerchantItem = function(i) return { lines = { { leftText = "Recipe: Thing" }, { leftText = (i == 2) and "Already known" or "Requires Cooking (10)" } } } end }
    if not ns:MerchantItemKnown(2) or ns:MerchantItemKnown(1) or ns:MerchantItemKnown(nil) then error("only the item whose tooltip says it is already known") end
    local V = ns.vendorKnownTest
    if not V then error("the vendor marking did not start") end
    local shown = {}
    local function button(n, id)
        local b = newmock()
        local wash = newmock()
        rawset(wash, "Show", function() shown[n] = true end)
        rawset(wash, "Hide", function() shown[n] = false end)
        rawset(b, "CreateTexture", function() return wash end)
        rawset(b, "GetID", function() return id end)
        rawset(b, "IsVisible", function() return true end)
        env["MerchantItem" .. n .. "ItemButton"] = b
    end
    button(1, 1); button(2, 2)
    for n = 3, 12 do env["MerchantItem" .. n .. "ItemButton"] = false end
    local frame = newmock()
    rawset(frame, "IsShown", function() return true end)
    frame.page, frame.selectedTab = 1, 1
    env.MerchantFrame = frame
    env.GetMerchantNumItems = function() return 2 end
    V.Mark()
    if shown[1] ~= false or shown[2] ~= true then error("the second item is known and should be the only one marked") end
    frame.selectedTab = 2                                   -- the buy-back tab: nothing there is "on sale"
    V.Mark()
    if shown[2] ~= false then error("the buy-back tab must not be marked") end
    for n = 1, 12 do env["MerchantItem" .. n .. "ItemButton"] = nil end
    env.MerchantFrame, env.GetMerchantNumItems, env.ITEM_SPELL_KNOWN = nil, nil, nil
    env.C_TooltipInfo = realTip

    -- bind-on-pickup loot is confirmed when alone, never in a group
    for _, key in ipairs({ "lootBindSolo", "autoRoleCheck", "combatAlert" }) do
        if ns.defaults[key] ~= false then error(key .. " must ship switched off") end
    end
    local grouped = false
    env.IsInGroup = function() return grouped end
    known.__bound = {}
    fireEvent("LOOT_BIND_CONFIRM", 3)
    if #known.__bound ~= 1 or known.__bound[1] ~= 3 then error("alone, bind-on-pickup loot should be confirmed") end
    grouped = true
    fireEvent("LOOT_BIND_CONFIRM", 4)
    if #known.__bound ~= 1 then error("in a group the question must be left for the player") end
    grouped = false
    env.IsShiftKeyDown = function() return true end
    fireEvent("LOOT_BIND_CONFIRM", 5)
    if #known.__bound ~= 1 then error("holding Shift should leave the question on screen") end
    -- role checks
    known.__roles = 0
    fireEvent("LFG_ROLE_CHECK_SHOW")
    if known.__roles ~= 0 then error("holding Shift should leave the role check for you") end
    env.IsShiftKeyDown = nil
    fireEvent("LFG_ROLE_CHECK_SHOW")
    if known.__roles ~= 1 then error("a role check should be accepted") end
    env.IsInGroup = nil

    -- combat alerts
    local C = ns.combatAlertTest
    if not C then error("the combat alert did not start") end
    local said
    rawset(C.text, "SetText", function(_, s) said = s end)
    fireEvent("PLAYER_REGEN_DISABLED")
    if said ~= "+ Combat" or ns.combatAlertLast ~= "start" then error("a fight starting should say + Combat, said " .. tostring(said)) end
    fireEvent("PLAYER_REGEN_ENABLED")
    if said ~= "- Combat" or ns.combatAlertLast ~= "end" then error("a fight ending should say - Combat") end
    rawset(C.text, "SetText", nil)
    runTimers()
end)
try("Quest marks on nameplates", function()
    if ns.defaults.plateQuest ~= true then error("quest marks only add information: on by default") end
    local realQ, realT, realEnum = env.C_QuestLog, env.C_TooltipInfo, env.Enum
    local answer = true
    env.C_QuestLog = { UnitIsRelatedToActiveQuest = function() return answer end }
    if ns:UnitOnQuest("nameplate3") ~= true then error("a unit the game says is on a quest of yours should be marked") end
    answer = false
    if ns:UnitOnQuest("nameplate3") ~= false then error("a unit not on a quest should not be marked") end
    answer = setmetatable({ __secret = true }, secretmt)
    if ns:UnitOnQuest("nameplate3") ~= nil then error("a hidden answer is \"cannot tell\", not yes or no") end
    if ns:UnitOnQuest(nil) ~= nil then error("no unit: cannot tell") end
    -- a client without that question: an unfinished objective in the unit's tooltip
    env.C_QuestLog = {}
    env.Enum = setmetatable({ TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17 } }, { __index = realEnum })
    local lines = { { type = 0, leftText = "Rot Hide Gnoll" }, { type = 17, leftText = "The Dead Fields" }, { type = 8, leftText = "Rot Hide Gnolls slain: 3/10", completed = false } }
    env.C_TooltipInfo = { GetUnit = function() return { lines = lines } end }
    if ns:UnitOnQuest("nameplate3") ~= true then error("an unfinished objective in the tooltip means the unit is still needed") end
    lines[3].completed = true
    if ns:UnitOnQuest("nameplate3") ~= false then error("a finished objective no longer needs the unit") end
    env.C_QuestLog = { UnitIsRelatedToActiveQuest = function() return answer end }

    -- on the plates: marked when it appears, cleared when the quest is done, left alone when the game hides the answer
    local T = ns.plateQuestTest
    if not T then error("quest marks did not start") end
    local plate = newmock()
    local realPlates = rawget(env.C_NamePlate, "GetNamePlateForUnit")
    rawset(env.C_NamePlate, "GetNamePlateForUnit", function() return plate end)
    answer = true
    fireEvent("NAME_PLATE_UNIT_ADDED", "nameplate3")
    local mark = T.marks[plate]
    if T.units["nameplate3"] ~= plate or not mark then error("the plate should be followed and given a mark") end
    local shown = true
    rawset(mark, "Show", function() shown = true end)
    rawset(mark, "Hide", function() shown = false end)
    answer = false
    T.UpdateAll()
    if shown then error("the quest is done: the mark should go") end
    answer = true
    T.UpdateAll()
    if not shown then error("needed again: the mark should come back") end
    answer = setmetatable({ __secret = true }, secretmt)
    T.UpdateAll()
    if not shown then error("a hidden answer must leave the mark as it was") end
    fireEvent("NAME_PLATE_UNIT_REMOVED", "nameplate3")
    if shown or T.units["nameplate3"] ~= nil then error("when the plate goes, so does its mark") end
    rawset(env.C_NamePlate, "GetNamePlateForUnit", realPlates)
    env.C_QuestLog, env.C_TooltipInfo, env.Enum = realQ, realT, realEnum
end)
try("Consumables bar", function()
    if ns.defaults.consumeBar ~= false then error("a new bar on screen is off until chosen") end
    local pick = ns.ConsumablePick({
        { id = 10, sub = 5, level = 5 }, { id = 11, sub = 1, level = 12 }, { id = 12, sub = 1, level = 35 }, { id = 13, sub = 8, level = 60 },
        { id = 14, sub = 7, level = 20 }, { id = 12, sub = 1, level = 35 }, { id = 15, sub = 4, level = 1 }, { id = 16, sub = 3, level = 50 } }, 10)
    local ids = {}
    for i, item in ipairs(pick) do ids[i] = item.id end
    if table.concat(ids, " ") ~= "12 11 14 10 16 15" then error("potions (best first), bandages, food, flasks, scrolls - and nothing else, nothing twice: " .. table.concat(ids, " ")) end
    if #ns.ConsumablePick(pick, 2) ~= 2 then error("no more buttons than the bar has") end
    -- read from the bags
    local realC, realI = env.C_Container, env.C_Item
    local bag0 = { 12, 99, 12, 14 }
    env.C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and #bag0 or 0 end, GetContainerItemID = function(bag, slot) return bag == 0 and bag0[slot] or nil end }
    env.C_Item = { GetItemInfoInstant = function(id) if id == 99 then return id, "Armor", "Cloth", "INVTYPE_CHEST", 1, 4, 1 end return id, "Consumable", "x", "", 134830, 0, (id == 14) and 7 or 1 end,
                   GetItemInfo = function(id) return "Item", nil, 1, 20 end }
    local found = ns:BagConsumables()
    if #found ~= 2 then error("two kinds of consumable in the bag (a potion twice, a bandage; the armor is not one), found " .. #found) end
    -- the bar: laid out between fights only
    local T = ns.consumeTest
    if not T then error("the consumables bar did not start") end
    local combat = false
    local keep = env.InCombatLockdown
    env.InCombatLockdown = function() return combat end
    if T.Assign() ~= 2 or T.buttons[1].itemID ~= 12 or T.buttons[2].itemID ~= 14 then error("the bar should hold the potion, then the bandage") end
    bag0 = { 14 }
    combat = true
    if T.Assign() ~= false or not T.Pending() or T.buttons[1].itemID ~= 12 then error("in combat the buttons must not be changed: it waits") end
    combat = false
    if T.Assign() ~= 1 or T.buttons[1].itemID ~= 14 or rawget(T.buttons[2], "itemID") ~= nil then error("after the fight the bar is laid out again") end
    if not tostring(ns.consumeState):find("1 items", 1, true) then error("the self-check should count the bar: " .. tostring(ns.consumeState)) end
    bag0 = {}
    T.Assign()
    env.InCombatLockdown = keep
    env.C_Container, env.C_Item = realC, realI
end)
try("Characters overview and timers", function()
    local keepAlts = ns.root.alts
    ns.root.alts = { ["Adolin - Roshar"] = { name = "Adolin", realm = "Roshar", class = "WARRIOR", level = 40, gold = 500000 },
                     ["Lift - Roshar"] = { name = "Lift", realm = "Roshar", class = "ROGUE", level = 12, gold = 900 } }
    env.GetMoney = function() return 123456 end
    local me = ns:RecordCharacter()
    if not me or me.gold ~= 123456 or ns.root.alts[ns:CharKey()] ~= me then error("the character being played should be recorded with its gold") end
    local list, total = ns:Characters()
    if #list ~= 3 or list[1].name ~= "Adolin" or list[3].name ~= "Lift" then error("characters are listed richest first") end
    if total ~= 500000 + 123456 + 900 then error("the total is every character's gold, got " .. tostring(total)) end
    local current
    for _, c in ipairs(list) do if c.current then current = c end end
    if not current or current.key ~= ns:CharKey() then error("the character you are on should be marked") end
    if ns:ForgetCharacter(ns:CharKey()) then error("the character being played cannot be forgotten") end
    ns.root.lifetime = ns.root.lifetime or {}; ns.root.lifetime["Lift - Roshar"] = { since = 1 }
    ns.root.goldDays = ns.root.goldDays or {}; ns.root.goldDays["Lift - Roshar"] = { [1] = 5 }
    if not ns:ForgetCharacter("Lift - Roshar") or #(ns:Characters()) ~= 2 then error("a deleted character can be forgotten") end
    if ns.root.lifetime["Lift - Roshar"] or ns.root.goldDays["Lift - Roshar"] then error("forgetting a character should clear what was kept for it") end
    local window, shownList = ns:ShowCharacters()
    if not window or #shownList ~= 2 then error("/fgui alts should open the list") end
    ns.root.alts = keepAlts
    env.GetMoney = nil

    local P = ns.ParseDuration
    local function is(text, seconds, label)
        local s, l = P(text)
        if s ~= seconds or (seconds and l ~= label) then error("\"" .. tostring(text) .. "\" should be " .. tostring(seconds) .. " seconds, \"" .. tostring(label) .. "\"; got " .. tostring(s) .. ", \"" .. tostring(l) .. "\"") end
    end
    is("5m bread", 300, "bread"); is("90s", 90, ""); is("1h30m raid night", 5400, "raid night"); is("2:30 pull", 150, "pull"); is("10 tea", 600, "tea")
    is("  45S  ", 45, ""); is("abc", nil); is("0", nil); is("5x", nil); is("25h", nil); is("", nil); is("m5", nil)
    if ns.TimerText(754) ~= "12:34" or ns.TimerText(4000) ~= "1:06:40" or ns.TimerText(0) ~= "0:00" or ns.TimerText(59.2) ~= "1:00" then error("time left is written wrongly") end

    local keepTimers = ns.root.timers
    ns.root.timers = nil
    ns:ClearTimers()
    local t = ns:StartTimer(300, "bread")
    if not t or #ns:TimerList() ~= 1 or ns:TimerList()[1].label ~= "bread" then error("a timer should start") end
    local saved = ns.root.timers[ns:CharKey()]
    if type(saved) ~= "table" or saved[1].label ~= "bread" then error("a running timer is kept for a reload") end
    ns:StartTimer(60, "soon")
    if ns:TimerList()[1].label ~= "soon" then error("the timer ending first is listed first") end
    for i = 1, 4 do ns:StartTimer(1000 + i, "x" .. i) end
    local seventh, why = ns:StartTimer(5, "too many")
    if seventh or not tostring(why):find("six", 1, true) then error("no more than six timers") end
    -- one runs out: it is announced and goes
    ns:TimerList()[1].ends = 0
    for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.1) end end
    local said = false
    for _, line in ipairs(printed) do if line:find("Timer finished", 1, true) and line:find("soon", 1, true) then said = true end end
    if not said or #ns:TimerList() ~= 5 then error("a finished timer should be announced and removed") end
    ns:TimerCommand("off")
    if #ns:TimerList() ~= 0 or ns.root.timers[ns:CharKey()] ~= nil then error("/fgui timer off cancels every timer") end
    ns:TimerCommand("2m tea")
    if #ns:TimerList() ~= 1 or ns:TimerList()[1].label ~= "tea" then error("/fgui timer 2m tea should start one") end
    ns:TimerCommand("nonsense")
    if #ns:TimerList() ~= 1 then error("a bad length of time must not start a timer") end
    ns:ClearTimers()
    ns.root.timers = keepTimers
end)
try("Ready check alert and cooldown pulse", function()
    if ns.defaults.readyAlert ~= true or ns.defaults.cooldownPulse ~= true then error("both only add information: on by default") end
    local played = {}
    local realPlay = env.PlaySound
    env.PlaySound = function(id, channel) played[#played + 1] = tostring(channel) end
    env.UnitName = function(u) if u == "player" then return "Shallan" end return "x" end
    ns.readyAlertLast = nil
    fireEvent("READY_CHECK", "Kaladin", 30)
    if ns.readyAlertLast ~= "Kaladin" then error("a ready check from someone else should raise the alert") end
    local master = false
    for _, channel in ipairs(played) do if channel == "Master" then master = true end end
    if not master then error("the alert sound should play on the channel that is heard from another window") end
    ns.readyAlertLast = nil
    fireEvent("READY_CHECK", "Shallan", 30)
    if ns.readyAlertLast ~= nil then error("your own ready check needs no alert") end
    env.PlaySound, env.UnitName = realPlay, nil

    -- the pulse: an ability coming off its own cooldown, not the shared one
    local keepSwitch = ns.db.cooldownPulse
    ns.db.cooldownPulse = true
    local before = ns.pulseCount or 0
    if not ns:CooldownPulse("icon") or ns.pulseCount ~= before + 1 then error("the pulse should show when asked") end
    ns.db.cooldownPulse = false
    if ns:CooldownPulse("icon") or ns.pulseCount ~= before + 1 then error("switched off, no pulse") end
    ns.db.cooldownPulse = true
    local realSpell = env.C_Spell
    local cd = { startTime = 90, duration = 30, isEnabled = true, isOnGCD = false }
    local idle = { startTime = 0, duration = 0, isEnabled = true, isOnGCD = false }
    env.C_Spell = { GetSpellCooldown = function(id) if id == 1 then return cd end return idle end }     -- (the shared cooldown is not running)
    env.GetTime = function() return 100 end
    local tex = newmock(); rawset(tex, "GetTexture", function() return "icon" end)
    local fake = { spellID = 1, tex = tex }
    local active = ns.cooldownTest.active()
    local others = {}
    for i = #active, 1, -1 do others[i] = active[i]; active[i] = nil end      -- (only the one being tested)
    active[1] = fake
    ns.cooldownTest.Refresh()
    if ns.pulseCount ~= before + 1 then error("an ability that is cooling down has not come off cooldown yet") end
    cd = { startTime = 0, duration = 0, isEnabled = true, isOnGCD = false }
    ns.cooldownTest.Refresh()
    if ns.pulseCount ~= before + 2 then error("coming off cooldown should pulse once") end
    ns.cooldownTest.Refresh()
    if ns.pulseCount ~= before + 2 then error("and only once") end
    cd = { startTime = 99, duration = 1.5, isEnabled = true, isOnGCD = true }      -- only the shared cooldown
    ns.cooldownTest.Refresh()
    cd = { startTime = 0, duration = 0, isEnabled = true, isOnGCD = false }
    ns.cooldownTest.Refresh()
    if ns.pulseCount ~= before + 2 then error("the shared cooldown ending is not an ability coming off cooldown") end
    active[1] = nil
    for i, b in ipairs(others) do active[i] = b end
    env.C_Spell, env.GetTime = realSpell, nil
    ns.db.cooldownPulse = keepSwitch
end)
try("10.0: shared lists and combat tools", function()
    local list = {}
    local a, n = ns.ListEdit(list, "Lightning Shield")
    if a ~= "added" or list[1] ~= "Lightning Shield" then error("a name alone adds it") end
    if ns.ListEdit(list, "lightning shield") ~= "removed" or #list ~= 0 then error("the same again (any case) removes it") end
    ns.ListEdit(list, "add Seal of Truth"); ns.ListEdit(list, "add Seal of Truth")
    if #list ~= 1 then error("adding twice keeps one") end
    if ns.ListEdit(list, "remove Nothing") ~= "missing" or ns.ListEdit(list, "") ~= "list" then error("remove of a stranger, and an empty line") end
    if ns.Clock(221) ~= "3:41" or ns.Clock(3700) ~= "1:01:40" then error("clock text") end
    if ns.GamePattern("%s rolls %d (%d-%d)") ~= "^(.+) rolls (%d+) %((%d+)%-(%d+)%)$" then error("game sentence pattern: " .. tostring(ns.GamePattern("%s rolls %d (%d-%d)"))) end
    local w = ns:ShowList("TestList", "Test", { { left = "a", right = "1", bar = 0.5 }, { left = "b" } }, "note")
    if #w.lines ~= 2 or not w.rows[2] then error("the list window should hold its lines") end
    w:SetLines({ { left = "only" } })
    if rawget(w.rows[2], "line") ~= nil then error("a row past the end is cleared") end
    if not ns:Flash("Hello") or ns.flashLast ~= "Hello" then error("the flash line") end

    -- missing buffs
    local missing = ns.MissingBuffs({ "A", "B", "C" }, function(name) if name == "A" then return true elseif name == "B" then return false end return nil end)
    if #missing ~= 1 or missing[1] ~= "B" then error("only a buff known to be missing is reported (hidden is not)") end
    if ns.RemindNow(true, false, false, true) or ns.RemindNow(false, true, false, false) or ns.RemindNow(false, false, true, false) then error("not dead, flying or resting") end
    if not ns.RemindNow(false, false, true, true) or not ns.RemindNow(false, false, false, false) then error("in combat even in a city; and out in the world") end
    if ns.defaults.buffMissing ~= true or ns.defaults.focusCastAlert ~= false or ns.defaults.executeLine ~= false then error("defaults: information on, alarms off") end
    -- execute line
    local x, pct = ns.ExecuteOffset(200, 20)
    if x ~= 40 or pct ~= 20 or select(2, ns.ExecuteOffset(200, 150)) ~= 99 or select(2, ns.ExecuteOffset(200, nil)) ~= 20 then error("execute line position") end
    -- buff filter
    local keepF, keepL = ns.db.auraFilter, ns.db.auraHide
    ns.db.auraFilter, ns.db.auraHide = true, { "Well Fed" }
    ns.listChanged = (ns.listChanged or 0) + 1
    if not ns:AuraHidden({ name = "well fed" }) or ns:AuraHidden({ name = "Fortitude" }) then error("a chosen buff is hidden, others not") end
    if ns:AuraHidden({ name = setmetatable({ __secret = true }, secretmt) }) then error("a hidden name is never filtered") end
    ns.db.auraFilter = false
    if ns:AuraHidden({ name = "Well Fed" }) then error("switched off, nothing is hidden") end
    ns.db.auraFilter, ns.db.auraHide = keepF, keepL
    ns.listChanged = ns.listChanged + 1

    -- potions and food
    local best = ns.BestHealItem({ { id = 1, heals = true, level = 10, minLevel = 5 }, { id = 2, heals = true, level = 40, minLevel = 35 }, { id = 3, heals = true, level = 60, minLevel = 55 } }, 40)
    if not best or best.id ~= 2 then error("the best potion you are high enough for") end
    best = ns.BestHealItem({ { id = 2, heals = true, level = 40 }, { id = 9, stone = true, level = 1 } }, 40)
    if best.id ~= 9 then error("a healthstone goes first: it is free") end
    if ns.BestHealItem({ { id = 4, level = 9 } }, 40) ~= nil then error("something that does not heal is not chosen") end
    local food, drink = ns.BestFoodDrink({ { id = 1, food = true, level = 5 }, { id = 2, food = true, level = 25 }, { id = 3, drink = true, level = 15 }, { id = 4, food = true, drink = true, level = 20, minLevel = 99 } }, 30)
    if food.id ~= 2 or drink.id ~= 3 then error("best food and best drink, within your level") end

    -- boss times
    local new, line = ns.BossResult("Ragnaros", 221, nil)
    if not new or not line:find("3:41", 1, true) then error("a first kill is a best") end
    new, line = ns.BossResult("Ragnaros", 200, 221)
    if not new or not line:find("new best", 1, true) then error("faster is a new best") end
    new = ns.BossResult("Ragnaros", 250, 221)
    if new then error("slower is not") end
    if ns.LogWanted(true, "raid", false) ~= true or ns.LogWanted(true, "party", false) ~= false or ns.LogWanted(true, "party", true) ~= true or ns.LogWanted(false, "raid", true) ~= false then error("when the combat log runs") end
end)
try("10.0: people", function()
    local joined, left = ns.RosterDiff({ A = true, B = true }, { B = true, C = true })
    if #joined ~= 1 or joined[1] ~= "C" or #left ~= 1 or left[1] ~= "A" then error("who joined and who left") end
    local recent = { { name = "Old", at = 1 } }
    ns.RecentAdd(recent, { { name = "New", class = "MAGE" }, { name = "Old" } }, 50, "Deadmines")
    if #recent ~= 2 or recent[1].name ~= "Old" or recent[1].at ~= 50 or recent[2].name ~= "New" then error("recent mates: each once, newest first") end
    for i = 1, 60 do ns.RecentAdd(recent, { { name = "P" .. i } }, 60 + i) end
    if #recent ~= ns.RECENT_MAX then error("no more than forty are remembered") end

    local keep = ns.root.playerNotes
    ns.root.playerNotes = {}
    ns:SetPlayerNote("Bob", "good tank")
    if ns:PlayerNote("Bob") ~= "good tank" or ns:PlayerNote("Bob-Realm") ~= "good tank" then error("a note is found by name, with or without the realm") end
    ns:SetPlayerNote("Bob", "clear")
    if ns:PlayerNote("Bob") ~= nil then error("\"clear\" removes the note") end
    if ns:PlayerNote(setmetatable({ __secret = true }, secretmt)) ~= nil then error("a hidden name has no note") end
    ns.root.playerNotes = keep

    local m = ns.MissingFrom({ { name = "A", online = true, zone = "Here" }, { name = "B", online = false }, { name = "C", online = true, zone = "Away" }, { name = "D", online = true, far = true } }, "Here")
    if #m ~= 3 or m[1].name ~= "B" or m[1].why ~= "offline" or m[2].why ~= "Away" or m[3].why ~= "not nearby" then error("who is missing, and why") end

    local p = ns.RollPattern("%s rolls %d (%d-%d)")
    local name, roll, low, high = ns.ParseRoll("Bob rolls 77 (1-100)", p)
    if name ~= "Bob" or roll ~= 77 or low ~= 1 or high ~= 100 then error("a roll should be read") end
    if ns.ParseRoll("Bob has come online.", p) then error("another system line is not a roll") end
    local sorted = ns.SortRolls({ { name = "A", roll = 40, low = 1, high = 100 }, { name = "B", roll = 90, low = 1, high = 100 }, { name = "A", roll = 99, low = 1, high = 100 }, { name = "C", roll = 500, low = 1, high = 1000 } })
    if sorted[1].name ~= "B" or sorted[2].name ~= "A" or sorted[2].roll ~= 40 or not sorted[3].void or not sorted[4].void then error("highest first; a second roll and a roll not out of 100 do not count") end

    local lines = ns.LockoutLines({ ["B - R"] = { name = "B", lockouts = { { name = "Molten Core", difficulty = "40", ends = 1000 + 90000, done = 3, bosses = 10 }, { name = "Old", ends = 5 } } }, ["A - R"] = { name = "A" } }, 1000)
    if #lines ~= 2 or not lines[1].header or not lines[2].left:find("Molten Core", 1, true) or not lines[2].left:find("3/10", 1, true) or lines[2].right ~= "1 d 1 h" then error("lockouts: one character, one live lockout") end
    if ns.raidSorts.role.groupBy ~= "ASSIGNEDROLE" or ns.defaults.raidSort ~= "group" then error("raid frame orders") end
end)
try("10.0: map and travel", function()
    local x, y, label = ns.ParseWay("45.5, 62 the cave")
    if x ~= 45.5 or y ~= 62 or label ~= "the cave" then error("waypoint text") end
    if ns.ParseWay("north") or ns.ParseWay("145 20") then error("not a place") end
    local turn, dist = ns.WayArrow(0.5, 0.5, 0.5, 0.4, 1000, 1000, 0)
    if math.abs(turn) > 0.001 or math.abs(dist - 100) > 0.01 then error("due north, 100 yards: straight ahead") end
    turn = ns.WayArrow(0.5, 0.5, 0.4, 0.5, 1000, 1000, 0)
    if math.abs(turn - math.pi / 2) > 0.001 then error("due west is a quarter turn to the left") end
    turn = ns.WayArrow(0.5, 0.5, 0.4, 0.5, 1000, 1000, math.pi / 2)
    if math.abs(turn) > 0.001 then error("facing west already: straight ahead") end
    if ns.FlightKey("A", "B") ~= "A > B" then error("flight route name") end
    if not ns.IsFishingPole(2, 20) or ns.IsFishingPole(2, 7) then error("what a fishing pole is") end
    if ns.MapScale(75) ~= 0.75 or ns.MapScale(10) ~= 0.4 or ns.MapScale(nil) ~= 0.75 then error("map size limits") end
    local ox, oy = ns.MapDotOffset(0.5, 0.25, 1000, 800, 0.5)
    if ox ~= 1000 or oy ~= -400 then error("a dot drawn at half scale sits at twice the offset") end
    -- the flight timer learns a route
    local T = ns.flightTest
    if T then
        local flying, clock = false, 100
        env.UnitOnTaxi = function() return flying end
        env.GetTime = function() return clock end
        T.Tick()                                                  -- (land, whatever the harness left in the air)
        T.Trip({ key = "A > B", to = "B" })
        flying = true; T.Tick()
        clock = 190; flying = false; T.Tick()
        if T.known["A > B"] ~= 90 then error("the route's time should be learned: " .. tostring(T.known["A > B"])) end
        T.known["A > B"] = nil
        env.UnitOnTaxi, env.GetTime = nil, nil
    end
end)
try("10.0: bags, gold and trade", function()
    local buys, cost = ns.RestockPlan(20, 5, 10, -1, 100, 1, 100000)
    if #buys ~= 2 or buys[1] ~= 10 or buys[2] ~= 5 or cost ~= 1500 then error("fifteen short, ten at a time") end
    buys = ns.RestockPlan(20, 25, 10, -1, 100, 1, 100000)
    if #buys ~= 0 then error("enough already: buy nothing") end
    buys, cost = ns.RestockPlan(20, 0, 20, 3, 100, 1, 100000)
    if buys[1] ~= 3 or #buys ~= 1 then error("no more than the vendor has") end
    buys, cost = ns.RestockPlan(20, 0, 20, -1, 500, 5, 1000)
    if buys[1] ~= 10 or cost ~= 1000 then error("no more than you can afford (sold five for 500)") end
    if ns.MoneySource({ merchant = true, loot = true }) ~= "Vendors and repairs" or ns.MoneySource({ quest = true }) ~= "Quests" or ns.MoneySource({}) ~= "Other" then error("where gold came from") end
    local days = ns.GoldDays({ [20261110] = 100, [20261112] = 250, [20261115] = 200 }, 2)
    if #days ~= 2 or days[1].day ~= 20261115 or days[1].change ~= -50 or days[2].change ~= 150 then error("gold by day, newest first, with the change") end
    local lines = ns.ShoppingLines({ { id = 1, need = 4 }, { id = 2, need = 2 } }, 3, function(id) if id == 1 then return 5, 4 end return 10, 0 end)
    if lines[1].need ~= 12 or lines[1].short ~= 7 or lines[1].fromAlts ~= 4 or lines[1].buy ~= 3 or lines[2].short ~= 0 then error("shopping list arithmetic") end
    local line = ns.TradeLine({ who = "Bob", gave = { { link = "[Cloth]", count = 2 } }, gaveMoney = 0, got = { { link = "[Sword]", count = 1 } }, gotMoney = 0 })
    if not line:find("Bob", 1, true) or not line:find("2 x [Cloth]", 1, true) or not line:find("[Sword]", 1, true) then error("trade line: " .. tostring(line)) end
    if ns.TradeLine({ who = "Bob", gave = {}, got = {} }) ~= nil then error("an empty trade is not recorded") end
    if ns.DaysBetween(20261110, 20261115) ~= 5 or ns.DaysBetween(20261231, 20270101) ~= 1 then error("days between dates") end
    if ns.AuctionSeenText({ price = 100, day = 20261115 }, 20261115) ~= "today" or ns.AuctionSeenText({ price = 100, day = 20261112 }, 20261115) ~= "3 days ago" or ns.AuctionSeenText(nil, 1) ~= nil then error("when a price was seen") end
    local pats = ns.LootPatterns({ "You receive loot: %sx%d.", "You receive loot: %s." })
    local link, count = ns.ParseLoot("You receive loot: |cffffffff|Hitem:2589::::|h[Linen Cloth]|h|rx3.", pats)
    if not link or count ~= 3 then error("loot with a count") end
    link, count = ns.ParseLoot("You receive loot: |cffffffff|Hitem:2589::::|h[Linen Cloth]|h|r.", pats)
    if not link or count ~= 1 then error("loot of one") end
    if ns.ParseLoot("Bob receives loot: |Hitem:1|h[X]|h.", pats) then error("someone else's loot is not yours") end
    -- a gear set item is never sold
    local keep = ns.db.bagSetMark
    ns.db.bagSetMark = true
    local realIn = ns.InGearSet
    ns.InGearSet = function(_, item) return item == "item:55" end
    if ns:ShouldSell("item:55", 0, 10) then error("an item in a gear set must not be sold, even grey") end
    if not ns:ShouldSell("item:56", 0, 10) then error("other grey items still are") end
    ns.InGearSet, ns.db.bagSetMark = realIn, keep
end)
try("10.0: chat, characters and the rest", function()
    local out, n = ns.HighlightWords("LFM healer for Deadmines", { "healer", "tank" })
    if n ~= 1 or not out:find("|cff66ff99healer|r", 1, true) then error("a keyword is picked out: " .. out) end
    local store = {}
    if ns.SpamCheck(store, "Bob", "WTS stuff", 100, 1) then error("the first time is shown") end
    if ns.SpamCheck(store, "Bob", "WTS stuff", 100, 1) then error("the same message offered to another tab gets the same answer") end
    if not ns.SpamCheck(store, "Bob", "WTS stuff", 104, 2) then error("repeated within ten seconds: hidden") end
    if not ns.SpamCheck(store, "Bob", "WTS stuff", 104, 2) then error("and hidden on every tab") end
    if ns.SpamCheck(store, "Bob", "WTS stuff", 120, 3) then error("after ten seconds it may be said again") end
    if ns.SpamCheck(store, "Ann", "WTS stuff", 121, 4) then error("someone else saying it is not a repeat") end
    if ns.PlayerOfLink("player:Bob-Realm:12:WHISPER") ~= "Bob-Realm" or ns.PlayerOfLink("item:5") then error("the player a chat link names") end
    local w = { order = {}, by = {} }
    ns.WhisperAdd(w, "Ann", "hi", false, 1); ns.WhisperAdd(w, "Bob", "yo", false, 2); ns.WhisperAdd(w, "Ann", "there?", false, 3); ns.WhisperAdd(w, "Ann", "yes", true, 4)
    if w.order[1] ~= "Ann" or #w.by.Ann.lines ~= 3 or w.by.Ann.unread ~= 2 or w.by.Bob.unread ~= 1 then error("whisper conversations: newest first, unread counted, your own lines not") end
    if #ns.chatTabPlans ~= 2 then error("two chat tabs are offered") end

    local e, g = ns.LinkEnchant("|cff0070dd|Hitem:18832:2564:0:0:0:0:0:0|h[Brutality Blade]|h|r")
    if e ~= 2564 or g ~= 0 then error("an enchant in a link") end
    if ns.EnchantMarks("|Hitem:100::::::::|h[X]|h", true, 0) ~= "E" or ns.EnchantMarks("|Hitem:100:5:::::::|h[X]|h", true, 2) ~= "G" or ns.EnchantMarks("|Hitem:100::7:8::::::|h[X]|h", false, 2) ~= "" then error("enchant and gem marks") end
    if ns.ShortTime(3700) ~= "1h 1m" or ns.ShortTime(125) ~= "3m" then error("short times") end
    if ns.TodoDone({ doneAt = 50 }, 100) ~= true or ns.TodoDone({ doneAt = 50, daily = true }, 100) ~= false or ns.TodoDone({ doneAt = 150, daily = true }, 100) ~= true or ns.TodoDone({}, 100) then error("to-do: a daily comes back after the reset") end
    local text, daily = ns.TodoParse("Daily cooking quest")
    if text ~= "cooking quest" or not daily or select(2, ns.TodoParse("buy flasks")) then error("to-do text") end
    env.loadstring = function(s) return load(s) end
    if ns.Calc("20*45+3") ~= 903 or ns.Calc("(2+3)^2") ~= 25 or ns.Calc("10 x 2,5") ~= 25 then error("the calculator") end
    if ns.Calc("os.exit()") or ns.Calc("") or ns.Calc("2+") then error("the calculator takes sums only") end
    env.loadstring = nil
    local tip = ns.AltTip({ name = "Lift", realm = "Roshar", level = 12, ilvl = 20, rested = 30, professions = { { name = "Mining", skill = 75, max = 150 } }, mail = true, at = 0 }, 86400 * 3)
    if #tip ~= 6 or not tip[4]:find("75/150", 1, true) or not tip[6]:find("3", 1, true) then error("what the characters list says about a character: " .. #tip) end
    local plan = ns.RaidGraphicsPlan({ graphicsShadowQuality = "3", graphicsSSAO = "0", graphicsLiquidDetail = nil }, ns.RAID_GRAPHICS)
    if plan.graphicsShadowQuality ~= "0" or plan.graphicsSSAO ~= nil or plan.graphicsLiquidDetail ~= nil then error("only what is above the raid value is turned down") end
    local sorted, total = ns.AddonLines({ { name = "B", kb = 100 }, { name = "A", kb = 3000 } })
    if sorted[1].name ~= "A" or total ~= 3100 or ns.Memory(3000) ~= "2.9 MB" or ns.Memory(100) ~= "100 KB" then error("add-on memory list") end
    -- every tool command has its function, and runs
    for word in pairs(ns.toolCommands) do
        if word ~= "resetinstances" and word ~= "deposit" and word ~= "spec" and word ~= "mount" then
            local before = #printed
            if not ns:ToolCommand(word, word) then error("/fgui " .. word .. " was not taken") end
            for i = before + 1, #printed do if printed[i]:find("|cffff4444/fgui", 1, true) then error("/fgui " .. word .. " failed: " .. printed[i]) end end
        end
    end
    if ns:ToolCommand("nonsense", "nonsense") then error("an unknown word is not a tool command") end
    ns:ClearWaypoint(true)
    for _, key in ipairs({ "Notes", "Recent", "Rolls", "Lockouts", "Gold", "Trades", "Loot", "Todo", "Addons", "TestList" }) do
        local win = env["FantasyGlassUIList" .. key]
        if type(win) == "table" and win.Hide then win:Hide() end
    end
end)
try("10.1: the Tools tab and the guide", function()
    -- words
    local words = ns.GuideWords("How do I move the action bars?")
    if table.concat(words, " ") ~= "move action bar" then error("question words: " .. table.concat(words, " ")) end
    words = ns.GuideWords("change the font", true)
    if table.concat(words, " ") ~= "font letter" then error("a word the add-on calls something else is widened: " .. table.concat(words, " ")) end
    -- answers
    local function best(q) local e = ns:GuideAnswer(q); return e end
    local e = best("how do I get an icon when Lightning Shield drops?")
    if not e or e.key ~= "buffMissing" then error("lightning shield question should find the missing buff reminder, got " .. tostring(e and (e.key or e.title))) end
    e = best("how do I move the action bars")
    if not e or e.title ~= "Moving things" then error("moving question: " .. tostring(e and e.title)) end
    e = best("change the font")
    if not e or e.title ~= "Lettering" then error("font question: " .. tostring(e and e.title)) end
    e = best("sell junk automatically")
    if not e or e.key ~= "autoSell" then error("junk question: " .. tostring(e and (e.key or e.title))) end
    e = best("where did my gold go")
    if not e or not (e.command == "/fgui gold" or (e.title or ""):lower():find("gold", 1, true)) then error("gold question: " .. tostring(e and e.title)) end
    e = best("fishing")
    if not e or e.key ~= "fishingMode" then error("one word should do: " .. tostring(e and (e.key or e.title))) end
    if ns:GuideAnswer("xyzzy plugh") ~= nil or ns:GuideAnswer("how do I") ~= nil then error("nonsense, or no words that mean anything, has no answer") end
    local lines, found = ns:GuideLines("xyzzy")
    if found ~= nil or #lines ~= 1 then error("no answer: one line saying so") end
    local keep = ns.db.fishingMode
    ns.db.fishingMode = false
    lines = ns:GuideLines("fishing")
    if not lines[2]:find("switched off", 1, true) then error("a feature that is off should say so") end
    ns.db.fishingMode = keep
    -- every written topic that names a place points at a label that exists on that tab
    ns:ToggleConfig("tools")
    for _, topic in ipairs(ns.guideTopics) do
        if topic.tab and topic.find then
            local ok = false
            for _, o in ipairs(ns.optionIndex) do if o.tab == topic.tab and o.label == topic.find then ok = true end end
            if not ok then error("the guide's \"" .. topic.title .. "\" points at \"" .. topic.find .. "\" on the " .. topic.tab .. " tab, which is not there") end
        end
    end
    -- the tab
    local T = ns.toolsPage
    if not T then error("the Tools tab did not build") end
    if #T.windowButtons ~= #ns.toolWindows then error("a button for every window") end
    for _, def in ipairs(ns.toolWindows) do
        if def[2] ~= "alts" and not ns.toolCommands[def[2]] then error("the Tools tab has a button for /fgui " .. def[2] .. ", which does not exist") end
    end
    if T.Ask("how do I move the action bars") == nil or T.best.title ~= "Moving things" then error("asking on the tab") end
    if ns:GuideShow(T.best) ~= "tab" then error("Show me should go to the tab") end
    ns:ToggleConfig("tools")
    -- lists
    local keepList = ns.db.remindBuffs
    ns.db.remindBuffs = {}
    T.SetList(1)
    if not ns:ToolListAdd(ns.toolLists[1], "Lightning Shield") or ns.db.remindBuffs[1] ~= "Lightning Shield" then error("adding to a list") end
    ns:ToolListAdd(ns.toolLists[1], "Lightning Shield")
    if #ns.db.remindBuffs ~= 1 then error("the same again is not added twice") end
    local rows = ns:ToolListRows(ns.toolLists[1])
    if #rows ~= 1 or T.DrawList() ~= 1 then error("the list should show one line") end
    rows[1].remove()
    if #ns.db.remindBuffs ~= 0 or T.DrawList() ~= 0 then error("the x takes it off") end
    ns.db.remindBuffs = keepList
    local keepStock = ns.db.restock
    ns.db.restock = { [17030] = 5 }
    rows = ns:ToolListRows(ns.toolLists[4])
    if #rows ~= 1 or not rows[1].text:find("x5", 1, true) then error("the restock list shows the item and how many") end
    rows[1].remove()
    if next(ns.db.restock) ~= nil then error("removing from the restock list") end
    ns.db.restock = keepStock
    -- your rules, on the same tab
    local R = T.rules
    ns.db.bagRules = {}
    R.Set(1, 1)                                               -- bag rules: item level at least
    R.addBox:SetText("50 = Upgrades"); rawset(R.addBox, "GetText", function() return "50 = Upgrades" end)
    if not R.Add() or ns.db.bagRules[1].kind ~= "ilvl" or ns.db.bagRules[1].section ~= "Upgrades" then error("a bag rule from the tab") end
    if ns.toolRules[1].add("lots = Upgrades", 1) then error("an item level needs a number") end
    if not ns.toolRules[1].add("Sell", 2) or ns.db.bagRules[2].kind ~= "boe" then error("a rule with no value") end
    local br = ns.toolRules[1].rows()
    if #br ~= 2 or br[1].act ~= nil or not br[2].act then error("rows: only later rules move up") end
    br[2].act()
    if ns.db.bagRules[1].kind ~= "boe" then error("moved up") end
    br = ns.toolRules[1].rows(); br[1].remove(); br = ns.toolRules[1].rows(); br[1].remove()
    if #ns.db.bagRules ~= 0 then error("bag rules removed") end
    ns.root.mailRules = {}
    if not ns.toolRules[2].add("Mytailor", 1) or ns.root.mailRules[1].what ~= "cloth" then error("a mail rule") end
    if ns.toolRules[2].add("Mytailor", 10) then error("a name rule needs a name") end
    if not ns.toolRules[2].add("Mytailor Silk", 10) or ns.root.mailRules[2].what ~= "name:silk" then error("a mail rule by name") end
    if R.Set(2) ~= 2 then error("the mail rules show") end
    ns.toolRules[2].rows()[1].remove()
    ns.root.mailRules = nil
    ns.root.checklist = nil
    if not ns.toolRules[3].add("Raid", 2) or ns.ChecklistStore().items[1].period ~= "weekly" then error("a weekly job from the tab") end
    if R.Set(3) ~= 1 then error("the checklist jobs show") end
    ns.root.checklist = nil
    R.Set(4)
    ns.toolRules[4].rows()
    -- stepping through choices: ours (nil) sits between the last and the first
    local names = { "A", "B" }
    if ns.NextChoice(names, nil) ~= "A" or ns.NextChoice(names, "A") ~= "B" or ns.NextChoice(names, "B") ~= nil or ns.NextChoice(names, nil, true) ~= "B" then error("stepping through fonts") end
    -- suggestions
    local s = ns:ClassSuggestions("SHAMAN")
    if #s ~= 4 or s[1].key ~= "buffMissing" then error("suggestions for a shaman") end
    for class, keys in pairs(ns.classSuggestions) do
        for _, key in ipairs(keys) do if ns.defaults[key] == nil then error(class .. " is offered a switch that does not exist: " .. key) end end
    end
    local keepT, keepB = ns.db.travelBar, ns.db.buffMissing
    ns.db.travelBar, ns.db.buffMissing = false, false
    if ns:ApplySuggestions("SHAMAN") < 2 or not ns.db.travelBar or ns:ApplySuggestions("SHAMAN") ~= 0 then error("turning the suggestions on, once") end
    ns.db.travelBar, ns.db.buffMissing = keepT, keepB
    ns:ToggleConfig()
end)
try("12.1: accessibility", function()
    local keep = {}
    for _, k in ipairs({ "colorblind", "colorVision", "safeFlash", "calmMode", "captions", "fontStyle", "textOutline", "keyNav", "reduceMotion", "theme", "fontScale" }) do keep[k] = ns.db[k] end
    -- a palette for each kind of color vision
    ns.db.colorblind, ns.db.colorVision = true, "blueyellow"
    local r, g, b = ns:Signal("good")
    if not (g > 0.6 and b > 0.6 and r < 0.3) then error("blue-yellow: good should be teal") end
    ns.db.colorVision = "none"
    local gr, gg, gb = ns:Signal("good"); local wr = ns:Signal("warn"); local br = ns:Signal("bad")
    if not (gr == gg and gg == gb) or not (br > wr and wr > gr) then error("no color: brightness only, bad brightest") end
    if ns:ColorVisionChoice() ~= "none" then error("the choice") end
    ns:SetColorVision("off")
    if ns.db.colorblind or ns:ColorVision() ~= nil then error("usual colors") end
    -- safe flashing
    ns.db.safeFlash, ns.db.reduceMotion = true, false
    if ns:Flashy() then error("safe flashing: no pulses") end
    ns.flashTimes = nil
    if not ns:FlashAllowed("probe") or ns:FlashAllowed("probe") then error("safe flashing: at most three a second from one source") end
    ns.db.safeFlash = false
    if not ns:Flashy() or not ns:FlashAllowed("probe") then error("without safe flashing everything may flash") end
    -- captions
    ns.db.captions, ns.db.calmMode = true, false
    if not ns:Caption("ready", "Ready check from Bob") or ns.captionLast ~= "Ready check from Bob" then error("a caption shows") end
    ns.db.captions = false
    if ns:Caption("ready", "x") then error("no captions while they are off") end
    -- calm mode holds notifications longer
    -- readable lettering, and back
    ns.db.fontStyle = "SLAB"
    ns:SetReadableFont("DYSLEXIC")
    if ns.db.fontStyle ~= "DYSLEXIC" or ns:ReadableFont() ~= "DYSLEXIC" or not ns.fontStyles.DYSLEXIC then error("dyslexia-friendly lettering") end
    ns:SetReadableFont("READABLE")
    ns:SetReadableFont("off")
    if ns.db.fontStyle ~= "SLAB" then error("back to the lettering chosen before: " .. tostring(ns.db.fontStyle)) end
    -- a thick outline round letters
    ns.db.textOutline = "thick"; ns:ApplyTheme()
    if ns.FONTFLAGS ~= "THICKOUTLINE" then error("thick outline") end
    ns.db.textOutline = "normal"; ns:ApplyTheme()
    -- read aloud: the last whisper
    ns.ReadSetLastWhisper("Bob: are you ready")
    local text, kind = ns:ReadText("whisper")
    if text ~= "Bob: are you ready" or kind ~= "whisper" then error("reading the last whisper") end
    -- sharing: one line, and back
    ns.db.colorblind, ns.db.colorVision, ns.db.calmMode, ns.db.fontScale, ns.db.theme = true, "none", true, 140, "FCONTRAST"
    local line = ns:AccessExport()
    if line:sub(1, 14) ~= "FGUI-ACCESS:1;" or not line:find("colorVision=none", 1, true) or not line:find("theme=FCONTRAST", 1, true) then error("the shared line: " .. line) end
    ns.db.colorblind, ns.db.calmMode, ns.db.fontScale, ns.db.theme = false, false, 100, "SMOKE"
    if (ns:AccessImport(line) or 0) < 4 or not ns.db.colorblind or ns.db.colorVision ~= "none" or ns.db.fontScale ~= 140 or ns.db.theme ~= "FCONTRAST" then error("taking a shared line") end
    if ns:AccessParse("hello") or ns:AccessParse("FGUI-ACCESS:1;nothing=1") or ns:AccessParse("FGUI-ACCESS:1;theme=SMOKE") then error("a bad line is refused") end
    local only = ns:AccessParse("FGUI-ACCESS:1;fontScale=999;profile=1")
    if not only or only.fontScale ~= 150 or only.profile ~= nil then error("only accessibility settings travel, within their bounds") end
    -- the settings: a category of its own, and the keyboard
    ns:ToggleConfig("access")
    local O, page = ns.optUI, ns.featuresPage
    if not O.current or O.current.id ~= "access:Seeing" then error("/fgui access opens Accessibility") end
    for _, name in ipairs({ "colorblind", "colorVision", "readableFont", "targetOutline", "cursorRing" }) do
        if not page.rows[name] then error("Seeing has " .. name) end
    end
    ns.db.keyNav = true
    O.KeyPress("TAB")
    if page.focused ~= 1 then error("Tab focuses the first setting") end
    O.KeyPress("DOWN")
    if page.focused ~= 2 then error("Down moves to the next") end
    O.KeyPress("PAGEDOWN")
    if O.current.id ~= "access:Hearing" then error("Page Down goes to the next section: " .. tostring(O.current.id)) end
    ns.db.keyNav = false
    if O.KeyPress("TAB") then error("the keyboard is left alone unless it is switched on") end
    if ns:SettingsSection("access:Hearing").keys[1] ~= "captions" then error("captions are with Hearing") end
    ns:ToggleConfig()
    for k, v in pairs(keep) do ns.db[k] = v end
    ns:Retheme()
end)
try("12.2: reading on its own, the game's windows by keyboard, keys for one hand", function()
    local keep = {}
    for _, k in ipairs({ "readDialog", "readHover", "windowKeys", "windowKeysSay", "stillSky", "tooltipDelay", "theme", "accent", "reduceMotion" }) do keep[k] = ns.db[k] end
    local realVoice, realTime, realTip = env.C_VoiceChat, env.GetTime, env.GameTooltip
    local said, stopped, now = {}, 0, 1000
    env.GetTime = function() return now end
    env.C_VoiceChat = { GetTtsVoices = function() return { { voiceID = 1 } } end, SpeakText = function(_, text) said[#said + 1] = text end,
                        StopSpeakingText = function() stopped = stopped + 1 end }
    -- talk and quests are read as they open, and stop when they close
    env.C_GossipInfo = { GetText = function() return "Greetings, |cffffd100traveler|r." end,
                         GetOptions = function() return { { name = "Train me" }, { name = "Goodbye" } } end,
                         GetAvailableQuests = function() return { { title = "Wolves at the Gate" } } end, GetActiveQuests = function() return {} end }
    local text = ns:DialogText("GOSSIP_SHOW")
    if text ~= "Greetings, traveler. Choices: Train me, Goodbye, Wolves at the Gate" then error("an NPC's talk and its choices: " .. tostring(text)) end
    env.GetTitleText, env.GetQuestText, env.GetObjectiveText = function() return "Wolves" end, function() return "Kill them." end, function() return "Kill 8 wolves." end
    if ns:DialogText("QUEST_DETAIL") ~= "Wolves. Kill them. Kill 8 wolves." then error("a quest's text") end
    ns.db.readDialog = true
    fireEvent("QUEST_DETAIL")
    local heardQuest = false                                     -- (the harness gives every event to every handler: others may speak too)
    for _, t in ipairs(said) do if t == "Wolves. Kill them. Kill 8 wolves." then heardQuest = true end end
    if not heardQuest or ns.readLast ~= "QUEST_DETAIL" then error("the quest is read as it opens") end
    local before = stopped
    fireEvent("QUEST_FINISHED")
    if stopped ~= before + 1 then error("closing the quest stops the reading") end
    ns.db.readDialog = false
    said = {}
    ns.readLast = nil
    fireEvent("QUEST_DETAIL")
    for _, t in ipairs(said) do if t == "Wolves. Kill them. Kill 8 wolves." then error("nothing is read with the switch off") end end
    -- what the mouse rests on: read once, after it settles
    local line = newmock(); rawset(line, "GetText", function() return "Peacebloom" end)
    env.GameTooltipTextLeft1, env.GameTooltipTextRight1 = line, false
    local tip = newmock()
    rawset(tip, "IsShown", function() return true end); rawset(tip, "NumLines", function() return 1 end)
    local alpha = 1
    rawset(tip, "SetAlpha", function(_, a) alpha = a end)
    env.GameTooltip = tip
    ns.db.readHover = true
    if ns.HoverReadTick(now) ~= nil then error("not yet: the tooltip has only just come") end
    if ns.HoverReadTick(now + 0.6) ~= "Peacebloom" then error("a tooltip that stays is read") end
    if ns.HoverReadTick(now + 1.2) ~= nil then error("and only once") end
    ns.db.readHover = false
    -- a wait before tooltips show
    ns.db.tooltipDelay = 500
    ns.TooltipDelayTick(now)                                      -- (a tooltip already up: the wait starts now)
    if ns.TooltipDelayTick(now) ~= false or alpha ~= 0 then error("the tooltip waits unseen") end
    if ns.TooltipDelayTick(now + 0.6) ~= true or alpha ~= 1 then error("then shows") end
    ns.db.tooltipDelay = 0
    ns.TooltipDelayTick(now + 1)
    -- the game's windows by keyboard
    local pressed = {}
    local function Button(label, top, left)
        local b = { label = label }
        function b:IsObjectType(kind) return kind == "Button" end
        function b:IsVisible() return true end
        function b:IsEnabled() return true end
        function b:IsMouseClickEnabled() return true end
        function b:GetWidth() return 120 end
        function b:GetHeight() return 22 end
        function b:GetTop() return top end
        function b:GetLeft() return left end
        function b:GetText() return label end
        function b:GetChildren() end
        function b:Click() pressed[#pressed + 1] = label end
        return b
    end
    local accept, decline, small = Button("Accept", 100, 10), Button("Decline", 100, 200), Button("Tiny", 300, 10)
    function small:GetWidth() return 4 end                        -- (too small to be a button anyone presses)
    local window = { IsVisible = function() return true end }
    function window:GetChildren() return decline, accept, small end
    local keepFrame = env.QuestFrame
    for _, name in ipairs({ "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }) do env[name] = false end
    for _, name in ipairs(ns.WINDOW_KEYS_FRAMES) do env[name] = false end
    env.QuestFrame = window
    local list = ns.WindowKeysButtons(window)
    if #list ~= 2 or list[1] ~= accept or list[2] ~= decline then error("the buttons, left to right, without the tiny one") end
    ns.db.windowKeys, ns.db.windowKeysSay = true, true
    env.IsShiftKeyDown = function() return false end
    env.GetCurrentKeyBoardFocus = function() return nil end
    if not ns.WindowKeysPress("TAB") or ns.windowKeysFocus ~= accept or ns.windowKeysSaid ~= "Accept, 1 of 2" then error("Tab goes to the first: " .. tostring(ns.windowKeysSaid)) end
    if said[#said] ~= "Accept, 1 of 2" then error("and says it") end
    ns.WindowKeysPress("TAB")
    if ns.windowKeysFocus ~= decline then error("Tab again: the next") end
    ns.WindowKeysPress("UP")
    if ns.windowKeysFocus ~= accept then error("Up: the one before") end
    if not ns.WindowKeysPress("ENTER") or pressed[#pressed] ~= "Accept" then error("Enter presses it") end
    if ns.WindowKeysPress("A") then error("other keys are the game's") end
    env.GetCurrentKeyBoardFocus = function() return {} end
    if ns.WindowKeysPress("TAB") then error("never while typing") end
    env.GetCurrentKeyBoardFocus = function() return nil end
    ns.db.windowKeys = false
    if ns.WindowKeysPress("TAB") then error("nothing with the switch off") end
    env.QuestFrame = keepFrame
    -- keys for one hand, and back
    local bound, set = { W = "MOVEFORWARD", NUMPAD8 = "CAMERAZOOMIN" }, {}
    env.GetBindingAction = function(key) return bound[key] or "" end
    env.SetBinding = function(key, action) set[#set + 1] = { key, action }; bound[key] = action; return true end
    env.SaveBindings, env.GetCurrentBindingSet = function() end, function() return 1 end
    ns.root.keysWere = nil
    local n1 = ns:UseKeyPreset("numpad")
    if n1 ~= 15 or bound.NUMPAD8 ~= "MOVEFORWARD" or bound.NUMPADPLUS ~= "TARGETNEARESTENEMY" then error("the number pad set: " .. tostring(n1)) end
    if ns.root.keysWere.NUMPAD8 ~= "CAMERAZOOMIN" or ns.root.keysWere.NUMPAD1 ~= "" then error("what the keys did before is noted") end
    ns:UseKeyPreset("numpad")
    if ns.root.keysWere.NUMPAD8 ~= "CAMERAZOOMIN" then error("noted once: a second use keeps what they did before") end
    ns:RestoreKeys()
    if bound.NUMPAD8 ~= "CAMERAZOOMIN" or bound.NUMPAD1 ~= nil or next(ns.root.keysWere) ~= nil then error("put back as they were") end
    if ns:UseKeyPreset("both hands") then error("an unknown set") end
    -- high contrast in the family you use, and a still sky
    ns.db.theme = "C_POLARIS"
    if ns:UseHighContrast() ~= "C_CONTRAST" or ns.db.theme ~= "C_CONTRAST" then error("celestial: its high-contrast theme") end
    ns.db.theme = "SMOKE"
    if ns:UseHighContrast() ~= "CONTRAST" then error("glass: its high-contrast theme") end
    ns.db.reduceMotion, ns.db.stillSky = false, true
    if ns.SkyMoves() then error("a still sky does not move") end
    if not ns:Motion() then error("but everything else still may") end
    ns.db.stillSky = false
    if not ns.SkyMoves() then error("the sky moves again") end
    -- all of it travels in the shared line
    ns.db.readDialog, ns.db.tooltipDelay = true, 750
    local line2 = ns:AccessExport()
    if not line2:find("readDialog=1", 1, true) or not line2:find("tooltipDelay=750", 1, true) then error("shared: " .. line2) end
    local got = ns:AccessParse("FGUI-ACCESS:1;tooltipDelay=99999;stillSky=1")
    if got.tooltipDelay ~= 2000 or got.stillSky ~= true then error("a shared line is kept in bounds") end
    for k, v in pairs(keep) do ns.db[k] = v end
    ns:ApplyTheme()
    env.C_VoiceChat, env.GetTime, env.GameTooltip = realVoice, realTime, realTip
    env.GameTooltipTextLeft1, env.GameTooltipTextRight1 = nil, nil
end)
try("12.0: the settings window", function()
    ns:ToggleConfig("home")
    local O, frame = ns.optUI, ns.configFrame
    O.SetSimple(false)
    if not O.current or not O.current.home then error("the window opens on Home") end
    -- the categories down the left; the open one lists its sections under it
    local shown = 0
    for _, b in ipairs(O.catButtons) do if rawget(b, "cat") then shown = shown + 1 end end
    if shown < 10 then error("a line for every category, got " .. shown) end
    O.Open("items")
    if not O.current or O.current.id ~= "items:Bags and bank" then error("a category opens at its first section") end
    local secs = 0
    for _, b in ipairs(O.secButtons) do if rawget(b, "sec") and b.sec.category.id == "items" then secs = secs + 1 end end
    if secs ~= #ns:SettingsCategory("items").sections then error("the open category lists its sections, got " .. secs) end
    -- a section shows its rows: its feature switches first, then the others
    local page = ns.featuresPage
    O.Open("items:Vendors")
    if page.shownKeys[1] ~= "autoSell" or not page.rows.autoSell then error("the section's switches are shown") end
    if page.boxes.autoSell.checked ~= (ns.db.autoSell and true or false) then error("a switch shows its setting") end
    -- and its larger pieces, lent while it shows and given back after
    local restock = ns.toolsPage.listBlocks.restock
    if rawget(restock, "lentTo") ~= page then error("Vendors shows the restock list") end
    O.Open("access:Seeing")
    if rawget(restock, "lentTo") == page then error("the restock list is given back when another section opens") end
    local lookArea = O.pages.look.area
    if rawget(lookArea, "lentTo") ~= page or not lookArea.band then error("Seeing shows its slice of the Look page") end
    local top = ns.optUI.Band(O.pages.look.sheet, "Contrast and text size")
    if lookArea.band.top ~= top then error("the slice starts at Contrast and text size") end
    local hasScale = false
    for _, k in ipairs(page.shownKeys) do if k == "uiScale" then hasScale = true end end
    if not hasScale then error("Interface size % is with Seeing") end
    O.Open("frames:Your frames")
    if lookArea.band.top ~= ns.optUI.Band(O.pages.look.sheet, "Frame style") then error("Your frames shows the frame style and portraits") end
    if rawget(O.pages.bars.area, "lentTo") ~= page then error("Your frames shows the frame designer") end
    if not page.sampleButton:IsShown() then error("Frames and bars has the sample frames button") end
    -- the old page names still open the right place
    for old, want in pairs({ clickcast = "frames:Raid frames", colors = "look:Class colors", profiles = "layout:Profiles", tools = "tools:Tools", combat = "combat:Cooldowns" }) do
        ns:ToggleConfig(old)
        if not O.current or O.current.id ~= want then error(old .. " should open " .. want .. ", got " .. tostring(O.current and O.current.id)) end
        if frame.currentPage ~= old then error("the window says it opened " .. old) end
    end
    if not frame:IsShown() then frame:Show() end
    -- Undo last change: what changed while the window was open, taken back one at a time
    O.Open("items:Vendors")
    O.NoteChange()
    local function click(f) for _, h in ipairs(handlers) do if h.self == f and h.name == "OnClick" then h.fn(f, "LeftButton") end end end
    local keep = ns.db.autoSell
    click(page.boxes.autoSell)
    if ns.db.autoSell == keep then error("the switch changes the setting") end
    local last = O.changes[#O.changes]
    if not last or last.key ~= "autoSell" or last.old ~= keep then error("the change is noted") end
    if O.Undo().key ~= "autoSell" or ns.db.autoSell ~= keep then error("undo puts it back") end
    if page.boxes.autoSell.checked ~= (keep and true or false) then error("the switch follows the undo") end
    -- Reset a category to how it came: its switches and sliders, nothing else
    local keepMap, keepCoords = ns.db.mapSize, ns.db.mapCoords
    ns.db.mapSize, ns.db.mapCoords = 55, not ns.defaults.mapCoords
    O.ResetCategory(ns:SettingsCategory("quests"))
    if ns.db.mapSize ~= ns.settingRows.mapSize.default or ns.db.mapCoords ~= ns.defaults.mapCoords then error("resetting a category puts its settings back") end
    ns.db.mapSize, ns.db.mapCoords = keepMap, keepCoords
    -- what is new is marked until it has been seen
    ns.root.seenNew = nil
    local acc = ns:SettingsSection("access:Seeing")
    local keepV = ns.version
    ns.version = "12.2.0"
    if not ns:SectionIsNew(acc) then error("a new section is marked NEW") end
    O.Open("access:Seeing")
    if ns:SectionIsNew(acc) then error("once seen it is not NEW any more") end
    ns.version = "12.3.0"; ns.root.seenNew = nil
    if ns:SectionIsNew(acc) then error("only in the version it came in") end
    ns.version = keepV
    -- the profile being changed is in the header; the corner resizes the window
    if not frame.profileChip.text:GetText():find(tostring(ns.profile), 1, true) then error("the header names the profile") end
    click(frame.profileChip)
    if O.current.id ~= "layout:Profiles" then error("the profile button opens Profiles") end
    if not frame.grip then error("the window can be resized from its corner") end
    -- a change that needs a reload is counted by the Reload button
    O.NeedReload("probe")
    if (O.reloadCount or 0) < 1 or not frame.note:GetText():find(tostring(O.reloadCount), 1, true) then error("the reload note counts the changes") end
    ns:ToggleConfig()
end)
try("10.3: quest guides", function()
    local P = ns.GuideParseLine
    local s = P("accept 123 A Fine Start | Marshal Dunn @ 37:45.2,62.1")
    if not s or s.kind ~= "accept" or s.quest ~= 123 or s.title ~= "A Fine Start" or s.text ~= "Marshal Dunn" or s.map ~= 37 or s.x ~= 45.2 or s.y ~= 62.1 then error("a full accept line") end
    s = P("do 123 | Kill 8 wolves @ 40,60")
    if s.kind ~= "do" or s.title ~= nil or s.text ~= "Kill 8 wolves" or s.map ~= nil or s.x ~= 40 then error("a do line on the map you are on") end
    s = P("  TURNIN 55  ")
    if s.kind ~= "turnin" or s.quest ~= 55 then error("capitals and spaces do not matter") end
    if P("level 6").level ~= 6 or P("note Sell and repair").text ~= "Sell and repair" or P("hearth").kind ~= "hearth" then error("level, note, hearth") end
    if P("") ~= nil or P("# a comment") ~= nil then error("empty lines and comments are passed over") end
    local bad, why = P("dance 5")
    if bad or not why then error("an unknown step must be refused with a reason") end
    if P("accept A Fine Start") or P("goto | the bridge") or P("level up") or P("goto @ 150,20") then error("a quest step needs its number, goto a place, level a number, and a place stays on the map") end
    local guide, problems = ns.GuideParse("guide: Test route\n# first\naccept 1 One | Bob @ 5:10,20\ndo 1 One | Slay @ 5:11,21\nnonsense here\nturnin 1 One @ 5:10,20\n\nlevel 3\n")
    if guide.name ~= "Test route" or #guide.steps ~= 4 or #problems ~= 1 or not problems[1]:find("line 5", 1, true) then error("a guide from text, with the bad line named: " .. #guide.steps .. " steps, " .. #problems .. " problems") end
    local again = ns.GuideParse(ns.GuideText(guide))
    if again.name ~= "Test route" or #again.steps ~= 4 or again.steps[2].text ~= "Slay" or again.steps[1].x ~= 10 or again.steps[4].level ~= 3 then error("a guide written out and read back is the same guide") end
    if not ns.GuideStepText(guide.steps[1]):find("One", 1, true) or ns.GuideStepText(guide.steps[2]) ~= "Slay" then error("what the panel says") end

    -- when a step counts as done
    local on, done, ready, near = {}, {}, {}, false
    local world = { onQuest = function(id) return on[id] or false end, completed = function(id) return done[id] or false end, ready = function(id) return ready[id] or false end,
                    near = function() return near end, level = 1 }
    local D = ns.GuideStepDone
    if D(guide.steps[1], world) then error("not accepted yet") end
    on[1] = true
    if not D(guide.steps[1], world) or D(guide.steps[2], world) or D(guide.steps[3], world) then error("accepted: the accept step is done, the rest not") end
    ready[1] = true
    if not D(guide.steps[2], world) or D(guide.steps[3], world) then error("objectives finished: the do step is done") end
    on[1], ready[1], done[1] = nil, nil, true
    if not (D(guide.steps[1], world) and D(guide.steps[2], world) and D(guide.steps[3], world)) then error("handed in: all three steps of the quest are done") end
    if D(guide.steps[4], world) then error("level 3 not reached") end
    world.level = 3
    if not D(guide.steps[4], world) then error("level 3 reached") end
    if D({ kind = "note", text = "x" }, world) or not D({ kind = "note", text = "x" }, world, true) then error("a note is done only when ticked") end
    if D({ kind = "goto", x = 1, y = 1 }, world) then error("not there yet") end
    near = true
    if not D({ kind = "goto", x = 1, y = 1 }, world) then error("there") end
    on, done, ready, world.level = {}, {}, {}, 1
    if ns.GuideNext(guide.steps, 1, world, {}) ~= 1 then error("nothing done: the first step") end
    done[1] = true
    if ns.GuideNext(guide.steps, 1, world, {}) ~= 4 then error("the quest handed in: on to the level step") end
    world.level = 5
    if ns.GuideNext(guide.steps, 1, world, {}) ~= 5 then error("all done: one past the end") end

    -- recording: the same step is not written twice
    local recording = { steps = {} }
    if not ns.GuideRecordStep(recording, { kind = "accept", quest = 7 }) or ns.GuideRecordStep(recording, { kind = "accept", quest = 7 }) then error("a step recorded once") end
    if not ns.GuideRecordStep(recording, { kind = "turnin", quest = 7 }) or #recording.steps ~= 2 then error("a different step of the same quest is recorded") end

    -- not released yet: locked unless the author's phrase has been given
    local keepKey = ns.root.guideKey
    ns.root.guideKey = nil
    if ns:GuideUnlocked() or ns:GuideOn() then error("quest guides start locked") end
    if ns:GuideCommand("") ~= false or ns:GuideShowPanel() ~= nil then error("locked: the guide does nothing") end
    if ns:GuideUnlock("open sesame") or ns:GuideUnlock("") or ns:GuideUnlocked() then error("a wrong phrase must not unlock") end
    -- (the phrase is never written in any file, these tests included: they unlock with the stored number,
    -- read from Guide.lua, and check the phrase's handling with a stand-in number)
    local key = tonumber((sources["Guide.lua"] or ""):match("local GUIDE_KEY = (%d+)"))
    if not key then error("Guide.lua keeps the number worked out from the phrase") end
    if ns.GuideHash("abc") ~= 193485963 or ns.GuideHash("") ~= 5381 then error("the phrase's number is worked out the same way every time") end
    ns.root.guideKey = key
    if not ns:GuideUnlocked() then error("the stored number unlocks") end
    ns:GuideLock()
    if ns:GuideUnlocked() then error("locking again") end
    ns.root.guideKey = key
    ns:ToggleConfig("guide")
    if not ns.guidePage or ns.guidePage.unlocked ~= true then error("unlocked: the Guide tab shows the controls") end
    ns:GuideLock()
    ns:ToggleConfig("guide")
    if ns.guidePage.unlocked ~= false then error("locked: the Guide tab says coming soon") end
    ns:ToggleConfig()
    ns.root.guideKey = key
    -- following one: saved, followed, and it moves on as the game changes
    local keepG, keepS, keepQ = ns.root.guides, ns.root.guideState, env.C_QuestLog
    ns.root.guides, ns.root.guideState = nil, nil
    local accepted, handed = {}, {}
    env.C_QuestLog = { IsOnQuest = function(id) return accepted[id] or false end, IsQuestFlaggedCompleted = function(id) return handed[id] or false end,
                       IsComplete = function() return false end, ReadyForTurnIn = function() return false end, GetTitleForQuestID = function(id) return "Quest " .. id end }
    env.UnitLevel = function() return 1 end
    if ns:GuideSave({ steps = {} }) then error("a guide with no name cannot be saved") end
    if not ns:GuideSave(guide) or not ns:GuideGet("Test route") then error("saving a guide") end
    if not ns:GuideFollow("Test route") then error("following a guide") end
    local step, at = ns:GuideAdvance()
    if at ~= 1 or step.kind ~= "accept" then error("the guide starts at its first step") end
    accepted[1] = true
    step, at = ns:GuideAdvance()
    if at ~= 2 or step.kind ~= "do" then error("the quest accepted: on to doing it, at " .. tostring(at)) end
    ns:GuideSkip(false)
    if ns.GuideState().at ~= 3 then error("ticking a step off moves on") end
    ns:GuideSkip(true)
    if ns.GuideState().at ~= 2 then error("and back again") end
    accepted[1], handed[1] = nil, true
    step, at = ns:GuideAdvance()
    if at ~= 4 or step.kind ~= "level" then error("handed in: on to the level step") end
    -- recording through the game's events
    if not ns:GuideRecord("My route") then error("recording should start") end
    fireEvent("QUEST_ACCEPTED", 42)
    fireEvent("QUEST_ACCEPTED", 42)
    fireEvent("QUEST_TURNED_IN", 42, 100, 0)
    local made = ns:GuideRecordStop()
    if not made or #made.steps ~= 2 or made.steps[1].kind ~= "accept" or made.steps[1].title ~= "Quest 42" or made.steps[2].kind ~= "turnin" then error("a recording of one quest: accept and turn in, once each") end
    if #ns:GuideNames() ~= 2 then error("both guides are listed") end
    ns:GuideCommand("")
    ns:GuideEdit("Test route")
    if not ns:GuideDelete("My route") or ns:GuideGet("My route") then error("deleting a guide") end
    -- the switch: off hides everything and keeps your place; on brings it back
    ns:GuideFollow("Test route")
    local keepSwitch = ns.db.questGuide
    ns.db.questGuide = false
    if ns:GuideApplySwitch() ~= false or ns:GuideOn() then error("switched off") end
    if ns:GuideAdvance() ~= nil or ns:GuideShowPanel() ~= nil then error("switched off, the guide does nothing") end
    if ns:GuideCommand("") ~= false then error("switched off, /fgui guide says so") end
    if ns.GuideState() == nil or ns.GuideState().name ~= "Test route" then error("your place in the guide is kept while it is off") end
    if ns:GuideRecord("Another") and ns.guideRecording then ns.db.questGuide = false; ns:GuideApplySwitch() end
    if ns.guideRecording then error("switching off ends a recording") end
    ns:GuideDelete("Another")
    ns.db.questGuide = true
    if ns:GuideApplySwitch() ~= true or not ns:GuideAdvance() then error("switched on again, the guide carries on") end
    for _, group in ipairs(ns.featureGroups) do for _, opt in ipairs(group[2]) do
        if opt[1] == "questGuide" then error("the quest guide's switch lives on the Guide tab, not among the Features") end
    end end
    for _, line in ipairs(ns.helpLines) do if type(line[1]) == "string" and line[1]:find("/fgui guide", 1, true) then error("/fgui help must not list the guide while it is unreleased") end end
    ns.db.questGuide = keepSwitch
    ns:GuideStop()
    if ns.GuideState() ~= nil then error("stopping forgets where you were") end
    env.C_QuestLog, env.UnitLevel = keepQ, nil
    ns.root.guides, ns.root.guideState = keepG, keepS
    ns.root.guideKey = keepKey
end)
try("10.4: each action bar's own settings", function()
    local info = ns.barHandles[1]
    local key = info.key
    local keepBars, keepFade = ns.db.bars, ns.db.barFade
    ns.db.bars, ns.db.barFade = nil, {}
    if ns:BarSetting(key, "scale") ~= 100 or ns:BarSetting(key, "alpha") ~= 100 or ns:BarSetting(key, "show") ~= "always" then error("a bar starts at full size, solid, always shown") end
    ns.db.barFade[key] = true
    if ns:BarSetting(key, "show") ~= "hover" then error("the older fade switch reads as \"when pointed at\"") end
    ns:SetBarSetting(key, "show", "combat")
    if ns.db.barFade[key] ~= nil or ns:BarSetting(key, "show") ~= "combat" then error("choosing another rule replaces the fade") end
    -- when it shows
    rawset(info.holder, "IsMouseOver", function() return false end)
    rawset(info.bar, "IsMouseOver", function() return false end)
    local realCursor, realCombat, realExists = env.GetCursorInfo, env.InCombatLockdown, env.UnitExists
    local combat, target = false, false
    env.GetCursorInfo = function() return nil end
    env.InCombatLockdown = function() return combat end
    env.UnitExists = function() return target end
    ns.moving, ns.keybinding = false, nil
    local keepPreview = ns.previewing
    ns.previewing = false
    local V = ns.barWantVisible
    if V(info) then error("\"in combat\": hidden outside it") end
    combat = true
    if not V(info) then error("\"in combat\": shown in it") end
    ns:SetBarSetting(key, "show", "nocombat")
    if V(info) then error("\"out of combat\": hidden in a fight") end
    combat = false
    ns:SetBarSetting(key, "show", "target")
    if V(info) then error("\"with a target\": hidden without one") end
    target = true
    if not V(info) then error("\"with a target\": shown with one") end
    ns:SetBarSetting(key, "show", "never")
    if V(info) then error("\"never\" hides it") end
    ns.moving = true
    if not V(info) then error("every bar shows while panels are being moved") end
    ns.moving = false
    -- opacity is how solid a shown bar is
    ns:SetBarSetting(key, "show", "always")
    ns:SetBarSetting(key, "alpha", 40)
    info.alpha = 1
    for _ = 1, 40 do ns:BarFadeTick(0.12) end
    if math.abs(info.alpha - 0.4) > 0.001 then error("a bar at 40% opacity should settle there, at " .. tostring(info.alpha)) end
    ns:SetBarSetting(key, "alpha", 100)
    for _ = 1, 40 do ns:BarFadeTick(0.12) end
    -- its own key text and macro names
    local keepHot, keepNames = ns.db.barHotkeys, ns.db.barMacroNames
    ns.db.barHotkeys, ns.db.barMacroNames = true, false
    if ns:BarSetting(key, "hotkeys") ~= true or ns:BarSetting(key, "names") ~= false then error("a bar follows the two general switches until it has its own") end
    ns:SetBarSetting(key, "hotkeys", false)
    if ns:BarSetting(key, "hotkeys") ~= false or ns:BarSetting(ns.barHandles[2].key, "hotkeys") ~= true then error("one bar's key text can be off while the others' stays") end
    ns.db.barHotkeys, ns.db.barMacroNames = keepHot, keepNames
    env.GetCursorInfo, env.InCombatLockdown, env.UnitExists = realCursor, realCombat, realExists
    ns.previewing = keepPreview

    -- the Edit Mode half: sizes as the game keeps them, and a layout edited in place
    if ns.BarSizeToRaw(100) ~= 5 or ns.BarSizeToRaw(50) ~= 0 or ns.BarSizeToRaw(200) ~= 15 or ns.BarSizeFromRaw(5) ~= 100 or ns.BarSizeFromRaw(120) ~= 120 then error("button size steps") end
    local S = { NumRows = 1, NumIcons = 2, IconSize = 3, IconPadding = 4, Orientation = 0 }
    local realEnum, realEdit, realPresets = env.Enum, env.C_EditMode, env.EditModePresetLayoutManager
    env.Enum = setmetatable({ EditModeActionBarSetting = S, EditModeSystem = { ActionBar = 0 } }, { __index = realEnum })
    local saved, activated
    local function fresh(active)
        return { activeLayout = active, layouts = { { layoutName = "Mine", systems = {
            { system = 0, systemIndex = 1, settings = { { setting = 0, value = 0 }, { setting = 1, value = 1 }, { setting = 2, value = 12 }, { setting = 3, value = 5 }, { setting = 4, value = 2 } } },
            { system = 0, systemIndex = 2, settings = { { setting = 1, value = 1 } } }, { system = 3, systemIndex = 1, settings = {} } } } } }
    end
    local state = fresh(3)
    env.C_EditMode = { GetLayouts = function() return state end, SaveLayouts = function(info) saved = info end, SetActiveLayout = function(n) activated = n end }
    env.EditModePresetLayoutManager = { GetCopyOfPresetLayouts = function() return { {}, {} } end }
    local bar = { systemIndex = 1 }
    local read = ns:BarLayoutRead(bar)
    if not read or read.rows ~= 1 or read.icons ~= 12 or read.size ~= 100 or read.padding ~= 2 or read.vertical ~= 0 then error("reading a bar's layout") end
    local ok = ns:BarLayoutWrite(bar, { rows = 2, icons = 99, size = 150, padding = 4, vertical = 1 })
    local e = state.layouts[1].systems[1]
    if not ok or saved ~= state or activated ~= 3 then error("a change is saved to the game and the layout applied again") end
    if ns.EditModeGet(e, 1) ~= 2 or ns.EditModeGet(e, 2) ~= 12 or ns.EditModeGet(e, 3) ~= 10 or ns.EditModeGet(e, 4) ~= 4 or ns.EditModeGet(e, 0) ~= 1 then error("rows 2, buttons held to 12, size 150% as step 10, spacing 4, downward") end
    if ns.EditModeGet(state.layouts[1].systems[2], 1) ~= 1 or #state.layouts[1].systems ~= 3 or #e.settings ~= 5 then error("only that bar is touched, and nothing is added") end
    saved = nil
    local again, note = ns:BarLayoutWrite(bar, { rows = 2 })
    if not again or note ~= "nothing to change" or saved ~= nil then error("the same values again save nothing") end
    env.InCombatLockdown = function() return true end
    if ns:BarLayoutWrite(bar, { rows = 3 }) or saved ~= nil then error("never in combat") end
    env.InCombatLockdown = realCombat
    state = fresh(1)                                              -- one of the game's presets is in use
    local none, why = ns:BarLayoutWrite(bar, { rows = 3 })
    if none or why ~= "preset" or saved ~= nil then error("a preset layout cannot be changed, and is not") end
    if select(2, ns:BarLayoutRead({})) == nil then error("a bar the Edit Mode does not lay out says so") end
    state = fresh(3)
    -- the tab
    ns:ToggleConfig("bars")
    local T = ns.barsPage
    if not T or T.empty or #T.sheet.navItems ~= #ns.barHandles + #(ns.DESIGN_FRAMES or {}) + 4 then error("the bars page holds every bar, every frame, nameplates, raid frames, auras and class resource") end
    T.Show(1)
    if T.current ~= 1 then error("choosing a bar") end
    -- Action bars: a button for each bar above its settings
    ns:ToggleConfig("frames:Action bars")
    local chips = ns.featuresPage.chipCount or 0
    if chips < #ns.barHandles then error("Action bars has a button for every bar, got " .. chips) end
    T.Show(#ns.barHandles)
    if T.canLayout then error("the pet bar has no rows to set") end
    ns:ToggleConfig()
    env.Enum, env.C_EditMode, env.EditModePresetLayoutManager = realEnum, realEdit, realPresets
    ns.db.bars, ns.db.barFade = keepBars, keepFade
end)
try("10.4.1: gathered minimap buttons are not greyed out", function()
    local T = ns.buttonBagTest
    if not T then error("the button collector did not start") end
    local keep = {}
    for i, f in ipairs(T.order) do keep[i] = f end
    for i = #T.order, 1, -1 do T.order[i] = nil end
    local function button(shown, level, stubborn)
        local f = newmock()
        local state = { level = level, alpha = 0.2, shown = shown, strata = "MEDIUM", fixS = true, fixL = true }
        rawset(f, "IsShown", function() return state.shown end)
        -- like the minimap-button library's: its layer is fixed, and a fixed layer ignores being set
        rawset(f, "SetFixedFrameStrata", function(_, on) if not stubborn then state.fixS = on end end)
        rawset(f, "SetFixedFrameLevel", function(_, on) if not stubborn then state.fixL = on end end)
        rawset(f, "SetFrameStrata", function(_, s) if not state.fixS then state.strata = s end end)
        rawset(f, "GetFrameStrata", function() return state.strata end)
        rawset(f, "GetFrameLevel", function() return state.level end)
        rawset(f, "SetFrameLevel", function(_, n) if not state.fixL then state.level = n end end)
        rawset(f, "SetAlpha", function(_, a) state.alpha = a end)
        rawset(f, "state", state)
        return f
    end
    local pstate = { level = 12, strata = "HIGH" }
    rawset(T.panel, "GetFrameLevel", function() return pstate.level end)
    rawset(T.panel, "GetFrameStrata", function() return pstate.strata end)
    rawset(T.panel, "SetFrameLevel", function(_, n) pstate.level = n end)
    rawset(T.panel, "SetFrameStrata", function(_, s) pstate.strata = s end)
    local a, b, c = button(true, 3), button(false, 3), button(true, 8)
    rawset(a, "showOnMouseover", true)
    T.order[1], T.order[2], T.order[3] = a, b, c
    if T.Arrange() ~= 2 then error("a button its add-on has hidden is left out, with no gap") end
    if rawget(a, "state").level <= 12 or rawget(c, "state").level <= 12 then error("every gathered button must sit in front of the panel's backing") end
    if rawget(a, "state").strata ~= "HIGH" or rawget(c, "state").strata ~= "HIGH" then error("a button whose layer is fixed must still be brought onto the panel's layer") end
    if not rawget(a, "state").fixS or pstate.strata ~= "HIGH" then error("its layer is fixed again afterwards, and the panel stays where it was") end
    if rawget(a, "state").alpha ~= 1 or rawget(a, "showOnMouseover") ~= nil then error("a button that fades itself is kept solid") end
    if rawget(b, "state").level ~= 3 then error("a hidden button is left alone") end
    rawget(b, "state").shown = true
    if T.Arrange() ~= 3 then error("and takes its place when its add-on shows it again") end
    -- one that will not come forward whatever is tried: the panel goes behind it instead
    local d = button(true, 8, true)
    T.order[4] = d
    T.Arrange()
    if pstate.strata ~= "MEDIUM" or pstate.level >= 8 then error("the panel should drop behind a button that cannot be raised, now " .. pstate.strata .. " " .. pstate.level) end
    for _, m in ipairs({ "GetFrameLevel", "GetFrameStrata", "SetFrameLevel", "SetFrameStrata" }) do rawset(T.panel, m, nil) end
    for i = #T.order, 1, -1 do T.order[i] = nil end
    for i, f in ipairs(keep) do T.order[i] = f end
    T.Arrange()
end)
try("10.5: tabs list their sections", function()
    -- a scrolling page can be held to one slice of its sheet
    local area, sheet = ns:ScrollArea(newmock(), 700, 200)
    rawset(area, "GetHeight", function() return 200 end)
    area:SetContentHeight(1000)
    area:SetBand(300, 500)
    if area.offset ~= 300 or area.least ~= 300 or area.most ~= 600 then error("a slice from 300, 500 tall, seen through 200: scroll from 300 to 600, got " .. tostring(area.offset) .. " " .. tostring(area.least) .. " " .. tostring(area.most)) end
    area:ScrollTo(0)
    if area.offset ~= 300 then error("what is above the slice cannot be scrolled to") end
    area:ScrollTo(900)
    if area.offset ~= 600 then error("nor what is below it") end
    area:SetBand(300, 120)
    if area.most ~= 300 then error("a slice shorter than the view does not scroll") end
    area:SetBand(nil)
    area:ScrollTo(900)
    if area.offset ~= 800 then error("without a slice the whole sheet scrolls again") end
    -- headings are noted where they stand
    local parent = {}
    ns.NoteSection(parent, "One", 0, 0); ns.NoteSection(parent, "Two", 0, -200)
    if #parent.suiHeads ~= 2 or parent.suiHeads[2].y ~= -200 then error("headings should be noted") end
    -- the pages are shown in slices, by heading, in the sections that need them
    local O = ns.optUI
    ns:ToggleConfig("home")
    local frame = ns.configFrame
    for _, cat in ipairs(ns.settingsCategories) do
        for _, sec in ipairs(cat.sections or {}) do
            for _, block in ipairs(sec.blocks or {}) do
                if block.host and O.pages[block.host] and block.from then
                    if not O.Band(O.pages[block.host].sheet, block.from, block.to) then error(sec.id .. " needs the heading " .. block.from .. " on the " .. block.host .. " page") end
                end
                if block.list and not ns.toolsPage.listBlocks[block.list] then error(sec.id .. " shows a list that does not exist: " .. block.list) end
                if block.rule and not ns.toolsPage.ruleBlocks[block.rule] then error(sec.id .. " shows rules that do not exist: " .. block.rule) end
            end
        end
    end
    -- no section shows two slices of one page (a page can be in one place at a time)
    for _, cat in ipairs(ns.settingsCategories) do
        for _, sec in ipairs(cat.sections or {}) do
            local hosts = {}
            for _, block in ipairs(sec.blocks or {}) do
                local h = block.host or (block.bars and "bars")
                if h then
                    if hosts[h] then error(sec.id .. " shows the " .. h .. " page twice") end
                    hosts[h] = true
                end
            end
        end
    end
    -- the Combat page: the AFK screen, alerts, the cooldown tracker and click casting, in that order
    local combat = O.pages.combat.sheet
    local order = {}
    for _, h in ipairs(rawget(combat, "allHeads")) do order[#order + 1] = h.text end
    if table.concat(order, ",") ~= "AFK screen,Custom alerts,Spoken alerts,Buff alerts,Cooldown tracker,Click casting" then error("the Combat page's order: " .. table.concat(order, ",")) end
    -- class colors and the frame style are slices of the Look page
    local look = O.pages.look.sheet
    if not (look.classColors and look.classColors.Refresh) then error("the class color editor should be on the Look page") end
    ns:ToggleConfig("colors")
    if O.current.id ~= "look:Class colors" then error("/fgui colors should open Class colors") end
    ns:ToggleConfig("clickcast")
    if O.current.id ~= "frames:Raid frames" then error("/fgui clickcast should open Raid frames, where click casting is now") end
    for _, o in ipairs(ns.optionIndex) do if o.tab == "colors" or o.tab == "clickcast" or o.tab == "features" then error("nothing should still point at an old tab: " .. o.tab) end end
    ns:ToggleConfig()
end)
try("10.8: the recommended features", function()
    -- quest rewards beside a quest's name
    if ns.QuestRewardText(1250, 23500, false) ~= "  |cff8c93a3" .. "1.2k xp, 2g 35s|r" then error("rewards text: " .. ns.QuestRewardText(1250, 23500, false)) end
    if not ns.QuestRewardText(800, 0, true):find("ffd100", 1, true) then error("a quest ready to turn in shows its reward in gold") end
    if ns.QuestRewardText(0, 50) ~= "" then error("nothing worth showing: nothing shown") end
    -- the timeline: ready at the left, five minutes at the right, the short end stretched out
    if ns.TimelineX(0, 300) ~= 0 or ns.TimelineX(300, 300) ~= 300 or ns.TimelineX(9999, 300) ~= 300 then error("timeline ends") end
    if not (ns.TimelineX(5, 300) > 80 and ns.TimelineX(30, 300) > 170) then error("the short end should be stretched: 5s at " .. ns.TimelineX(5, 300)) end
    -- ready-check: food, flask and the class buffs the group can give
    local buffNames = { Fortitude = { ["Power Word: Fortitude"] = true }, ["Mark of the Wild"] = { ["Mark of the Wild"] = true }, Intellect = {} }
    local miss = ns.ReadyMissing({ "Well Fed", "Power Word: Fortitude" }, { PRIEST = true, DRUID = true }, buffNames)
    if #miss ~= 2 or miss[1] ~= "flask" or miss[2] ~= "Mark of the Wild" then error("missing: " .. table.concat(miss, ",")) end
    if #ns.ReadyMissing({ "Satt", "Fläschchen der Titanen" }, {}, buffNames) ~= 0 then error("German food and flask names count too") end
    -- rare memory: the same rare near the same spot is one sighting
    local list = {}
    local _, new1 = ns.RareRemember(list, "Old Grizzlegut", 0.40, 0.50, 1)
    local s2, new2 = ns.RareRemember(list, "Old Grizzlegut", 0.41, 0.51, 2)
    ns.RareRemember(list, "Old Grizzlegut", 0.70, 0.20, 3)
    if not new1 or new2 or #list ~= 2 or s2.seen ~= 2 then error("rare memory: " .. #list .. " spots") end
    -- theme by place
    if ns.PlaceNow("raid", false) ~= "raid" or ns.PlaceNow("party", true) ~= "dungeon" or ns.PlaceNow("none", true) ~= "city" or ns.PlaceNow(nil, false) ~= "world" then error("places") end
    if ns.PlaceTheme({ city = "A" }, "city", "H") ~= "A" or ns.PlaceTheme({ city = "A" }, "raid", "H") ~= "H" then error("a place without a theme of its own uses yours") end
    do
        local keepT, keepOn, keepPlaces, keepHome, keepStyle = ns.db.theme, ns.db.themeByPlace, ns.db.placeThemes, ns.db.themeHome, ns.style
        local same, other
        for key, t in pairs(ns.themes) do
            if not t.custom and key ~= ns.db.theme then
                if (t.style or "FANTASY") == (ns.style or "FANTASY") then same = same or key else other = other or key end
            end
        end
        local realInst, realRest = env.IsInInstance, env.IsResting
        env.IsInInstance = function() return true, "raid" end
        env.IsResting = function() return false end
        ns.db.themeByPlace, ns.db.themeHome = true, keepT
        ns.db.placeThemes = { raid = same }
        ns:ApplyPlaceTheme()
        if ns.db.theme ~= same then error("in a raid the raid theme should be used") end
        env.IsInInstance = function() return false, "none" end
        ns:ApplyPlaceTheme()
        if ns.db.theme ~= keepT then error("out of the raid your own theme comes back") end
        if other then
            env.IsInInstance = function() return true, "raid" end
            ns.db.placeThemes = { raid = other }
            ns:ApplyPlaceTheme()
            if ns.db.theme ~= keepT or not tostring(ns.placeState):find("reload", 1, true) then error("a theme of the other family is not switched to") end
        end
        ns.db.themeByPlace = false
        ns:ApplyPlaceTheme()
        env.IsInInstance, env.IsResting = realInst, realRest
        ns.db.theme, ns.db.themeByPlace, ns.db.placeThemes, ns.db.themeHome = keepT, keepOn, keepPlaces, keepHome
        pcall(ns.Retheme, ns)
    end
    -- crafting queue: the same recipe twice adds up; the shopping list adds up every recipe
    local queue = {}
    ns.QueueAdd(queue, 11, "Linen Bandage", 5); ns.QueueAdd(queue, 11, "Linen Bandage", 3); ns.QueueAdd(queue, 12, "Wool Bandage", 2)
    if #queue ~= 2 or queue[1].times ~= 8 then error("queue: " .. #queue) end
    local need = ns.QueueNeeds(queue, function(id) return id == 11 and { { id = 2589, need = 1 } } or { { id = 2592, need = 1 }, { id = 2589, need = 2 } } end)
    if need[2589] ~= 12 or need[2592] ~= 2 then error("queue needs: " .. tostring(need[2589]) .. " " .. tostring(need[2592])) end
    -- goals
    local read = { count = function() return 7 end, faction = function() return { currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 6000, reaction = 5 } end }
    local done, label = ns.GoalProgress({ kind = "item", id = 1, need = 20 }, read)
    if math.abs(done - 0.35) > 1e-9 or not label:find("7 / 20", 1, true) then error("item goal: " .. label) end
    done, label = ns.GoalProgress({ kind = "rep", id = 1 }, read)
    if math.abs(done - 0.5) > 1e-9 or not label:find("3000 / 6000", 1, true) then error("rep goal: " .. label) end
    if ns.goalsTest then
        ns.db.goals = { { kind = "item", id = 2589, need = 10, name = "Linen Cloth" } }
        if ns.goalsTest.Update() ~= 1 then error("the goals panel shows one goal") end
        ns.db.goals = {}
        ns.goalsTest.Update()
    end
    -- the windows open
    ns:ShowSession()
    ns:ShowRares()
    ns:ShowCraftQueue()
    ns:ToolCommand("goal", "goal")
    if ns.splashTest and not ns.splashTest.Show() then error("the splash should show") end
    -- the Look tab: theme by place rows
    ns:ToggleConfig("look")
    local lp = ns.lookPage
    if not (lp and lp.placeRows and lp.placeRows.city and lp.placeRows.world) then error("the Look tab should have the theme-by-place rows") end
    ns:ToggleConfig()
end)
try("10.9: tour, what's this, levelling, profession cooldowns, performance", function()
    -- the tour walks its steps and ends
    ns.db.tourDone = false
    if ns:StartTour() ~= 1 then error("the tour starts at step 1") end
    if ns:TourStep(#ns.TOUR) ~= #ns.TOUR then error("the last step") end
    ns:TourStep(#ns.TOUR + 1)
    if not ns.db.tourDone then error("finishing the tour marks it done") end
    -- what's this: a box over each panel on screen, knowing which feature made it
    local n = ns:WhatsThis(true)
    if type(n) ~= "number" or n < 1 then error("what's this should cover the panels on screen, got " .. tostring(n)) end
    local withFeature = 0
    for i = 1, n do if ns.whatsThisTest.boxes[i].entry.feature then withFeature = withFeature + 1 end end
    if withFeature < 1 then error("panels should know which feature made them") end
    ns:WhatsThis(false)
    for _, m in ipairs(ns.movables) do
        if m.key == "cdTimeline" and m.feature ~= "cdTimeline" and ns.db.cdTimeline then error("the timeline belongs to its feature") end
    end
    -- where to level
    if ns.ZoneFit(20, 15, 25) ~= "now" or ns.ZoneFit(20, 23, 30) ~= "soon" or ns.ZoneFit(20, 10, 19) ~= "past" or ns.ZoneFit(20, 40, 50) ~= nil then error("zone fit") end
    ns:ShowLevelZones()
    -- profession cooldowns: recorded per character, ready ones first
    local store = {}
    ns.ProfCDRecord(store, "A - R", { [1] = { name = "Transmute: Arcanite", seconds = 3600 } }, 1000)
    ns.ProfCDRecord(store, "B - R", { [2] = { name = "Mooncloth", seconds = 0 } }, 1000)
    local lines = ns.ProfCDLines(store, 2000)
    if #lines ~= 2 or lines[1].name ~= "Mooncloth" or lines[2].left ~= 2600 then error("profession cooldown lines") end
    ns:ShowProfCooldowns()
    -- performance: rows heaviest first; measuring times what runs
    local rows = ns.PerfRows({ a = { ms = 10, calls = 5, worst = 3 }, b = { ms = 40, calls = 2, worst = 30 } }, 10)
    if rows[1].label ~= "b" or math.abs(rows[1].perSec - 4) > 1e-9 then error("perf rows") end
    local realDP = env.debugprofilestop
    local t = 0
    env.debugprofilestop = function() t = t + 1.5; return t end
    ns:PerfCommand("5")
    local g = ns:Guard("Probe", function() end)
    g(); g()
    if not ns.perfData.Probe or ns.perfData.Probe.calls ~= 2 then error("measuring should time guarded calls") end
    runTimers()
    ns.perfOn = false
    env.debugprofilestop = realDP
end)
try("10.9: four more languages", function()
    local de = 0
    for _ in pairs(ns.locales.deDE or {}) do de = de + 1 end
    for _, code in ipairs({ "ruRU", "ptBR", "itIT", "koKR", "ptPT" }) do
        local t = ns.locales[code]
        if type(t) ~= "table" then error(code .. " is missing") end
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        if n ~= de then error(code .. " has " .. n .. " labels, German has " .. de) end
        local found = false
        for _, def in ipairs(ns.languages) do if def[1] == code then found = true end end
        if code ~= "ptPT" and not found then error(code .. " should be on the language list") end
    end
    if ns.locales.ruRU["Options"] ~= "Настройки" or ns.locales.koKR["Options"] ~= "설정" then error("translations") end
end)
try("11.0: own action bars", function()
    -- layout maths
    local s = ns.EngineSettings({ buttons = 12, rows = 2, size = 40, padding = 4 })
    local x, y, w, h = ns.EngineGrid(s, 7)
    if x ~= 0 or y ~= -44 or w ~= 6 * 44 - 4 or h ~= 2 * 44 - 4 then error("grid: " .. x .. "," .. y .. " " .. w .. "x" .. h) end
    local v = ns.EngineSettings({ buttons = 6, rows = 2, size = 30, padding = 2, vertical = 1 })
    local x2, y2 = ns.EngineGrid(v, 4)
    if x2 ~= 32 or y2 ~= 0 then error("downward grid: " .. x2 .. "," .. y2) end
    local c = ns.EngineSettings({ buttons = 99, rows = 0, size = 5, padding = 50 })
    if c.buttons ~= 12 or c.rows ~= 1 or c.size ~= 20 or c.padding ~= 20 then error("settings are kept in bounds") end
    if ns.EngineSettings({ buttons = 3, rows = 8 }).rows ~= 3 then error("no more rows than buttons") end
    -- the bars themselves (the harness turns every feature on)
    local bars = ns.engine and ns.engine.bars
    if type(bars) ~= "table" then error("the bar engine should run: " .. tostring(ns.barEngineState)) end
    if #bars ~= 8 then error("eight bars") end
    -- (11.18) the quarter-second look is the light one: usable, range and lit, not the icon all over again
    do
        local b = ns.engine.all[1]
        local asked = 0
        local AB = env.C_ActionBar
        local realTex = AB.GetActionTexture
        AB.GetActionTexture = function(...) asked = asked + 1; return realTex(...) end
        b.suiHas = true
        pcall(ns.engine.UpdateState, b)
        AB.GetActionTexture = realTex
        if asked ~= 0 then error("the light look at a button should not ask for its icon") end
        if type(ns.engine.events) ~= "table" then error("the bars' timer should be kept, to start with the bars") end
    end
    -- (11.4.3) our buttons keep themselves up to date (no game action button template)
    local b1 = bars[1].buttons[1]
    local AB = env.C_ActionBar
    local realHas, realTex = AB.HasAction, AB.GetActionTexture
    AB.HasAction = function() return true end
    AB.GetActionTexture = function() return 135000 end
    if ns.engine.UpdateButton(b1) ~= true then error("a button with an action") end
    AB.HasAction = function() return false end
    if ns.engine.UpdateButton(b1) ~= false then error("an empty button") end
    AB.HasAction, AB.GetActionTexture = realHas, realTex
    ns.engine.UpdateHotkey(b1)
    if #ns.engine.all ~= 96 then error("every button is kept up to date: " .. #ns.engine.all) end
    -- (11.4.2) our own stance bar: a button for each form, casting its spell
    local realN, realI = env.GetNumShapeshiftForms, env.GetShapeshiftFormInfo
    env.GetNumShapeshiftForms = function() return 2 end
    env.GetShapeshiftFormInfo = function(i) return 136000 + i, i == 1, true, 2645 + i end
    if not ns.engine.stance then ns.engine.BuildStance() end
    local st = ns.engine.stance
    if not st then error("the stance bar of our own") end
    if #ns.StanceForms() ~= 2 then error("the forms") end
    local rN = st.Refresh()
    if rN ~= 2 or st.buttons[1].spellID ~= 2646 or rawget(st.buttons[3], "spellID") ~= nil then error("a button per form: " .. tostring(rN) .. " " .. tostring(st.buttons[1].spellID) .. " " .. tostring(InCombatLockdown and env.InCombatLockdown())) end
    env.GetNumShapeshiftForms, env.GetShapeshiftFormInfo = realN, realI
    local seenStance, seenGame = false, false
    for _, info in ipairs(ns.barHandles) do if info.key == "fgstance" then seenStance = true end; if info.key == "bar_StanceBar" then seenGame = true end end
    if not seenStance or seenGame then error("our stance bar is on the Bars tab, the game's is not") end
    for k, bar in ipairs(bars) do
        local first = bar.buttons[1].suiAction
        if first ~= (ns.ENGINE_BARS[k].page - 1) * 12 + 1 then error("bar " .. k .. " starts at action " .. tostring(first)) end
        if bar.buttons[1].suiCommand ~= ns.ENGINE_BARS[k].bind .. "1" then error("bar " .. k .. " answers to its binding") end
    end
    for _, gameBar in ipairs({ "bar_MainActionBar", "bar_MultiBarBottomLeft" }) do
        for _, info in ipairs(ns.barHandles) do if info.key == gameBar then error("the game's bars step aside: " .. gameBar) end end
    end
    local found = 0
    for _, info in ipairs(ns.barHandles) do if info.engine then found = found + 1 end end
    if found ~= 8 then error("the Bars tab lists the eight own bars") end
    -- writing a layout lays the bar out again, and reads back
    local hidden = false
    rawset(bars[2].buttons[10], "Hide", function() hidden = true end)
    local ok = ns:BarLayoutWrite(bars[2], { rows = 3, icons = 9, size = 100, padding = 6, vertical = 0 })
    local back = ns:BarLayoutRead(bars[2])
    if not ok or back.rows ~= 3 or back.icons ~= 9 or back.padding ~= 6 then error("own bar layout write and read") end
    if not hidden then error("buttons past the number shown are hidden") end
    rawset(bars[2].buttons[10], "Hide", nil)
    local again, note = ns:BarLayoutWrite(bars[2], { rows = 3 })
    if note ~= "nothing to change" then error("the same layout again changes nothing") end
    -- key bindings press our buttons
    local realKey, realSet, realClear, bound = env.GetBindingKey, env.SetOverrideBindingClick, env.ClearOverrideBindings, {}
    env.GetBindingKey = function(cmd) if cmd == "ACTIONBUTTON3" then return "3" end end
    env.SetOverrideBindingClick = function(owner, prio, key, name) bound[key] = name end
    env.ClearOverrideBindings = function() end
    ns.engine.Bind()
    if bound["3"] ~= "FantasyGlassUIBar1Button3" then error("key 3 should press bar 1's third button, got " .. tostring(bound["3"])) end
    env.GetBindingKey, env.SetOverrideBindingClick, env.ClearOverrideBindings = realKey, realSet, realClear
    ns.db.engineBars = nil
end)
try("11.0: frame designer", function()
    local f
    for _, u in ipairs(ns.unitFrameList or {}) do if u.designKey == "Target" then f = u end end
    if not f then error("the target frame should know its design key") end
    ns.db.ufDesign = { Target = { name = "CENTER", health = "LEFT", font = 16, power = 0, portrait = "OFF" } }
    ns:ApplyFrameDesign()
    if f.opt.power ~= 0 or not f.portraitOff then error("power bar and portrait from the design") end
    local sw, sh
    rawset(f, "SetSize", function(_, w, h) sw, sh = w, h end)
    ns.db.ufDesign = { Target = { w = 300, h = 50 } }
    ns:ApplyFrameDesign()
    if sw ~= 300 or sh ~= 50 then error("size from the design: " .. tostring(sw)) end
    rawset(f, "SetSize", nil)
    ns.db.ufDesign = nil
    ns:ApplyFrameDesign()
    if f.opt.power ~= f.baseOpt.power or f.portraitOff then error("no design: as the frame was made") end
    ns:ToggleConfig("bars")
    local T = ns.barsPage
    if not (T and T.designer and #T.designer.frames >= 5) then error("the Bars and frames tab has the designer") end
    local nBars = #ns.barHandles
    T.sheet.NavSelect(nBars + 2)
    if T.showing ~= "frame" or T.designer.current ~= 2 then error("choosing a frame shows the designer") end
    T.designer.Step("health")
    if not (ns.db.ufDesign and ns.db.ufDesign.Target and ns.db.ufDesign.Target.health == "CENTER") then error("the health text button steps to the middle") end
    T.sheet.NavSelect(1)
    if T.showing ~= "bar" then error("choosing a bar shows the bar settings again") end
    ns.db.ufDesign = nil
    ns:ApplyFrameDesign()
    ns:ToggleConfig()
end)
try("11.0: API for other add-ons", function()
    local FG = ns.api
    if not FG or FG.version ~= 1 then error("FantasyGlassUI_API version 1") end
    local key = FG.RegisterInfoPiece("test:piece", "Test piece", function() return "PIECE-TEXT" end)
    local line = ns.InfoBarCompose()
    if not line:find("PIECE-TEXT", 1, true) then error("an added piece shows on the info bar") end
    local listed = false
    for _, p in ipairs(ns.infobarPieces) do if p[1] == key then listed = true end end
    if not listed then error("and in the bar's list of pieces") end
    local id = FG.RegisterTheme("test", "Test Theme", { style = "GLASS", panel = { 0.1, 0.1, 0.2 }, rim = { 0.3, 0.3, 0.5 }, accent = { 0.9, 0.5, 0.2 } })
    if not ns.themes[id] or ns.themes[id].name ~= "Test Theme" then error("a theme from another add-on") end
    local ran
    FG.RegisterCommand("apitest", function(rest) ran = rest end, "a test")
    ns:ToolCommand("apitest hello", "apitest hello")
    if ran ~= "hello" then error("a command from another add-on") end
    if pcall(FG.RegisterCommand, "apitest", function() end) then error("a command word that is taken is refused") end
    if pcall(FG.RegisterInfoPiece, 5, "x", nil) then error("bad arguments are refused") end
    FG.RegisterGuideTopic({ title = "Test topic", text = "An answer.", keys = "zebra" })
    local r, g, b = FG.GetColor("accent")
    if type(r) ~= "number" then error("colors") end
    FG.RegisterToolWindow("Test window", function() end)
    if not FG.Style(newmock()) == nil then end
    ns.apiInfoPieces[#ns.apiInfoPieces] = nil
end)
try("11.0: layout gallery", function()
    -- where a panel lands on the screen, from its anchor
    local l, t = ns.GalleryRect("CENTER", -250, -180, 200, 40, 1920, 1080)
    if l ~= 1920 / 2 - 250 - 100 or t ~= 1080 / 2 + 180 - 20 then error("centre anchor: " .. l .. "," .. t) end
    l, t = ns.GalleryRect("TOPLEFT", 20, -160, 300, 200, 1920, 1080)
    if l ~= 20 or t ~= 160 then error("top-left anchor: " .. l .. "," .. t) end
    l, t = ns.GalleryRect("BOTTOMRIGHT", -10, 10, 100, 50, 1920, 1080)
    if l ~= 1920 - 10 - 100 or t ~= 1080 - 10 - 50 then error("bottom-right anchor: " .. l .. "," .. t) end
    if #ns.GALLERY ~= 6 then error("six setups") end
    local w = ns:ShowGallery()
    if not w or #w.cards ~= 6 or w.cards[1].boxes < 8 then error("six cards, each with its picture") end
    local keepPos, keepBars = ns.db.pos, ns.db.bars
    ns.db.pos = {}
    if not ns:ApplyGallery("minimal") then error("applying a setup") end
    if not ns.db.pos.ufPlayer or ns.db.pos.ufPlayer[1] ~= "BOTTOM" then error("the setup's places are saved") end
    if ns:BarSetting(ns.barHandles[1].key, "show") ~= "combat" then error("minimal: bars in combat only") end
    ns:ApplyGallery("classic")
    if ns:BarSetting(ns.barHandles[1].key, "show") ~= "always" then error("classic: bars always") end
    ns.db.pos, ns.db.bars = keepPos, keepBars
    w:Hide()
end)
try("11.0: custom and spoken alerts", function()
    -- one step: unknown keeps the last state; a start is reported once
    local on, started = ns.AlertStep(false, true)
    if not on or not started then error("an alert starts") end
    on, started = ns.AlertStep(true, true)
    if not on or started then error("it does not start twice") end
    on, started = ns.AlertStep(true, nil)
    if not on or started then error("when the game will not say, keep what was known") end
    on = ns.AlertStep(true, false)
    if on then error("and it ends") end
    -- making alerts
    ns.db.customAlerts = {}
    if ns:AddAlert("health", "abc", "x") then error("health needs a number") end
    if ns:AddAlert("buffmissing", " ", "x") then error("a buff needs a name") end
    local a = ns:AddAlert("health", "35", "Heal up!", true, true)
    if not a or a.value ~= 35 then error("adding a health alert") end
    if not ns.AlertDescribe(a):find("Heal up!", 1, true) then error("described") end
    -- it shows, sounds and speaks when health falls below 35%
    local realH, realM, realSpeak = env.UnitHealth, env.UnitHealthMax, env.C_VoiceChat
    local said = {}
    env.C_VoiceChat = { GetTtsVoices = function() return { { voiceID = 2 } } end, SpeakText = function(id, text) said[#said + 1] = text end }
    ns.db.speakAlerts = true
    env.UnitHealth, env.UnitHealthMax = function() return 900 end, function() return 1000 end
    ns.customAlertsTest.Update()
    if ns.customAlertsShown ~= 0 then error("at 90% nothing shows") end
    env.UnitHealth = function() return 200 end
    ns.customAlertsTest.Update()
    if ns.customAlertsShown ~= 1 then error("at 20% the alert shows") end
    if said[#said] ~= "Heal up!" then error("and is said: " .. tostring(said[#said])) end
    local n = #said
    ns.customAlertsTest.Update()
    if #said ~= n then error("said once, not every look") end
    -- spoken alerts: whispers, kinds switched off
    fireEvent("CHAT_MSG_WHISPER", "hi", "Thrall-Realm")
    if not tostring(said[#said]):find("Thrall", 1, true) then error("a whisper is said with who sent it: " .. tostring(said[#said])) end
    ns.db.speakKinds = { whisper = false }
    n = #said
    fireEvent("CHAT_MSG_WHISPER", "hi", "Jaina")
    if #said ~= n then error("a kind switched off is not said") end
    ns.db.speakAlerts, ns.db.speakKinds, ns.db.customAlerts = false, nil, {}
    env.UnitHealth, env.UnitHealthMax, env.C_VoiceChat = realH, realM, realSpeak
    -- the Combat tab has the editors
    ns:ToggleConfig("combat")
    if not (ns.alertEditor and ns.speakEditor) then error("the Combat tab has the alert and speech editors") end
    do  -- the value box's hint says what the chosen alert wants typed
        local E, saw = ns.alertEditor, {}
        local hint = rawget(E.value, "hint")
        if type(hint) ~= "table" then error("the value box has no hint") end
        rawset(hint, "SetText", function(_, t) saw[t] = true end)
        local click
        for _, h in ipairs(handlers) do if h.self == E.triggerButton and h.name == "OnClick" then click = h.fn end end
        if not click then error("the alert kind button has no click") end
        for _ = 1, #ns.ALERT_TRIGGERS do
            click(E.triggerButton, "LeftButton")
            if type(rawget(E.value, "hint")) ~= "table" then error("the value box's hint was replaced by plain text") end
        end
        rawset(hint, "SetText", nil)
        if not (saw[ns:Tr("a number")] or saw[ns:Tr("a name")]) then error("the hint should ask for a number or a name") end
    end
    local cs = ns.OptionsSheet("combat")
    -- custom and spoken alerts show with the alert switches, in Combat > Alerts and warnings
    ns:ToggleConfig("combat:Alerts and warnings")
    if rawget(ns.optUI.pages.combat.area, "lentTo") ~= ns.featuresPage then error("Alerts and warnings shows the alert editors") end
    local top = ns.optUI.Band(cs, "Custom alerts", "Buff alerts")
    if ns.optUI.pages.combat.area.band.top ~= top then error("the slice starts at Custom alerts") end
    ns:ToggleConfig()
end)
try("11.0: route editor and the route on the map", function()
    local steps = { { kind = "do" }, { kind = "goto" }, { kind = "note" } }
    local _, at = ns.RouteMove(steps, 1, 1)
    if steps[2].kind ~= "do" or at ~= 2 then error("move down") end
    _, at = ns.RouteMove(steps, 1, -1)
    if at ~= 1 then error("the first step cannot go up") end
    _, at = ns.RouteInsert(steps, 1, { kind = "hearth" })
    if steps[2].kind ~= "hearth" or at ~= 2 or #steps ~= 4 then error("insert after") end
    _, at = ns.RouteDelete(steps, 4)
    if #steps ~= 3 or at ~= 3 then error("delete the last") end
    local ahead = ns.RouteAhead({ { x = 1, y = 1, map = 5 }, { kind = "note" }, { x = 2, y = 2, map = 6 }, { x = 3, y = 3 } }, 1, 5, 6)
    if #ahead ~= 2 or ahead[1].index ~= 1 or ahead[2].index ~= 4 then error("steps ahead on this map") end
end)
try("11.0: live self-test", function()
    local results
    env.InCombatLockdown = function() return false end
    ns.selfTesting = false
    if not ns:SelfTest(function(r) results = r end, false) then error("the self-test did not start") end
    if not results then error("the self-test should finish (stopped at " .. tostring(ns.selfTestAt) .. ")") end
    local names = {}
    for _, r in ipairs(results) do names[r.name] = r end
    for _, want in ipairs({ "Options tab: look", "Window: /fgui session", "What's this? on and off", "Fantasy Glass action bars" }) do
        if not names[want] then error("missing step: " .. want) end
        if not names[want].ok then error(want .. " failed: " .. tostring(names[want].err)) end
    end
    if ns:ShowSelfTest(results) == nil then error("the report") end
end)
try("11.0.1: bars on and off, nameplate and raid designers, checklist", function()
    -- own bars: switching one off hides it, and the setting survives a layout change
    local bars = ns.engine and ns.engine.bars
    if bars then
        local drivers = {}
        local real = env.RegisterStateDriver
        env.RegisterStateDriver = function(frame, state, value) drivers[frame] = value end
        ns:SetEngineBarOn(3, false)
        if drivers[bars[3]] ~= "hide" or ns:EngineBarOn(3) then error("bar 3 switched off is hidden") end
        ns:BarLayoutWrite(bars[3], { rows = 2 })
        if ns:EngineBarOn(3) then error("a layout change keeps the bar off") end
        ns:SetEngineBarOn(3, true)
        if drivers[bars[3]] == "hide" or not ns:EngineBarOn(3) then error("and on again") end
        env.RegisterStateDriver = real
        ns.db.engineBars = nil
        ns:ToggleConfig("bars")
        ns.barsPage.Show(1)
        if not ns.barsPage.useBox then error("the Bars tab has a Use this bar switch") end
        ns:ToggleConfig()
    end
    -- nameplate designer
    ns.db.plateDesign = { nameSize = 40, auraMax = -3, healthPos = "LEFT" }
    local pd = ns.PlateDesign()
    if pd.nameSize ~= 18 or pd.auraMax ~= 0 or pd.healthPos ~= "LEFT" or pd.castHeight ~= 8 then error("plate design kept in bounds, defaults filled in") end
    if ns.ApplyPlateDesign then ns:ApplyPlateDesign() end
    ns.db.plateDesign = nil
    -- raid designer
    ns.db.raidDesign = { horizontal = true, perColumn = 8, gap = 2 }
    local g = ns.RaidGrid(ns.RaidDesign())
    if g.point ~= "LEFT" or g.unitsPerColumn ~= 8 or g.maxColumns ~= 5 or g.xOffset ~= 2 then error("raid grid across") end
    ns.db.raidDesign = nil
    g = ns.RaidGrid(ns.RaidDesign())
    if g.point ~= "TOP" or g.yOffset ~= -4 or g.maxColumns ~= 8 then error("raid grid down, as it came") end
    if ns.ApplyRaidDesign then ns:ApplyRaidDesign() end
    -- the tab lists the two designers and shows them
    ns:ToggleConfig("bars")
    local T = ns.barsPage
    local pi, ri
    for i, item in ipairs(T.sheet.navItems or {}) do if item.title == "Nameplates" then pi = i elseif item.title == "Raid frames" then ri = i end end
    if not (pi and ri) then error("Nameplates and Raid frames on the Bars and frames tab") end
    T.sheet.NavSelect(pi)
    if T.showing ~= "plates" then error("choosing Nameplates") end
    T.sheet.NavSelect(ri)
    if T.showing ~= "raid" then error("choosing Raid frames") end
    ns:ToggleConfig()
    -- checklist: a tick lasts until the reset comes round
    local store = { items = {}, done = {}, nextId = 1 }
    local item = ns.ChecklistAdd(store, "daily", "  Cooking quest ")
    local wk = ns.ChecklistAdd(store, "weekly", "Raid")
    if not item or item.text ~= "Cooking quest" or wk.period ~= "weekly" or ns.ChecklistAdd(store, "daily", "  ") then error("adding jobs") end
    local before = { daily = ns.ChecklistStamp(1000, 5000), weekly = ns.ChecklistStamp(1000, 90000) }
    local later = { daily = ns.ChecklistStamp(3000, 3000), weekly = ns.ChecklistStamp(3000, 88000) }
    if before.daily ~= later.daily then error("the same period has the same stamp") end
    ns.ChecklistToggle(store, "Me", item, before)
    if not ns.ChecklistDone(store, "Me", item, later) then error("ticked earlier in the same day: still done") end
    local nextDay = { daily = ns.ChecklistStamp(7000, 86400 - 1000), weekly = later.weekly }
    if ns.ChecklistDone(store, "Me", item, nextDay) then error("after the daily reset it is not done any more") end
    local d, t = ns.ChecklistCount(store, "Me", "daily", later)
    if d ~= 1 or t ~= 1 then error("count") end
    ns.ChecklistToggle(store, "Me", item, later)
    if ns.ChecklistDone(store, "Me", item, later) then error("untick") end
    ns.root.checklist = nil
    ns:ChecklistCommand("add weekly Dungeon run")
    if #ns.ChecklistStore().items ~= 1 then error("the command adds a job") end
    ns:ShowChecklist()
    ns.root.checklist = nil
end)
try("11.2.0: tools menu, timers, bag and mail rules, talents, holidays, preview", function()
    -- every button of the Tools menu runs a real command
    for _, def in ipairs(ns.TOOL_MENU) do if not ns.toolCommands[def[2]] then error("Tools menu: no command " .. def[2]) end end
    for i, first in pairs({ [1] = "Am I ready?", [11] = "Your characters", [23] = "Sort bags", [32] = "Notes on players", [37] = "Where to level", [40] = "Key bindings" }) do
        if not ns.TOOL_MENU_GROUPS[i] or ns.TOOL_MENU[i][1] ~= first then error("the Tools menu's groups start in the wrong places: " .. i) end
    end
    if not ns:ToggleToolsMenu() then error("the Tools menu opens") end
    if #ns.toolPalette.buttons ~= #ns.TOOL_MENU then error("a button for each tool") end
    ns:ToggleToolsMenu()
    -- pixel-perfect scale
    if math.abs(ns.PixelScale(1080) - 0.7111) > 0.001 or ns.PixelScale(0) ~= nil then error("pixel scale") end
    -- minimap shape
    ns.db.minimapRound = true; ns:ApplyMinimapShape()
    if env.GetMinimapShape() ~= "ROUND" then error("round minimap") end
    ns.db.minimapRound = false; ns:ApplyMinimapShape()
    if env.GetMinimapShape() ~= "SQUARE" then error("square again") end
    -- shared strings are read, not taken
    local kind, data = ns:DecodeShared(ns:ExportLayout())
    if kind ~= "layout" or type(data.pos) ~= "table" then error("a layout string is read") end
    if ns:DecodeShared(ns:ExportProfile()) ~= "profile" then error("a profile string is read") end
    if ns:DecodeShared("nonsense") ~= nil then error("not one of ours") end
    if ns:PreviewShared(ns:ExportLayout()) ~= "layout" then error("the preview draws a layout") end
    -- composition
    local roles, classes, cover = ns.Composition({ { name = "A", class = "PRIEST", role = "HEALER" }, { name = "B", class = "WARRIOR", role = "TANK" }, { name = "C", class = "MAGE", role = "DAMAGER" } })
    if roles.HEALER ~= 1 or roles.TANK ~= 1 or classes.MAGE ~= 1 then error("roles and classes") end
    local fort, motw
    for _, c in ipairs(cover) do if c.label == "Fortitude" then fort = c end; if c.label == "Mark of the Wild" then motw = c end end
    if #fort.who ~= 1 or #motw.who ~= 0 then error("who covers what") end
    ns:ShowComposition()
    -- countdowns
    local k, n = ns.ParseCountdown("PULL:10")
    if k ~= "pull" or n ~= 10 or ns.ParseCountdown("BREAK:300") ~= "break" or ns.ParseCountdown("x") then error("countdown messages") end
    ns:CountdownCommand("pull", "8")
    if ns.countdownLast ~= "pull" then error("a pull timer alone") end
    if ns.BattleStartsIn("The battle begins in 1 minute.") ~= 60 or ns.BattleStartsIn("The battle begins in 30 seconds!") ~= 30 or ns.BattleStartsIn("Hello") then error("battle start") end
    if ns.bgTest then ns.bgTest.Update() end
    ns:ShowBattlegroundScore()
    -- bag rules
    if not ns.BagRuleMatch({ kind = "ilvl", value = "50" }, { ilvl = 55 }) or ns.BagRuleMatch({ kind = "ilvl", value = "50" }, { ilvl = 40 }) then error("ilvl rule") end
    if not ns.BagRuleMatch({ kind = "boe" }, { bindType = 2, bound = false }) or ns.BagRuleMatch({ kind = "boe" }, { bindType = 2, bound = true }) then error("boe rule") end
    if not ns.BagRuleMatch({ kind = "type", value = "gear" }, { classID = 4 }) or ns.BagRuleMatch({ kind = "type", value = "trade" }, { classID = 0 }) then error("type rule") end
    if not ns.BagRuleMatch({ kind = "name", value = "potion" }, { name = "Healing Potion" }) then error("name rule") end
    ns.db.bagRules = nil
    ns:BagRulesCommand("add ilvl 50 = Upgrades")
    ns:BagRulesCommand("add boe = Sell")
    if #ns.db.bagRules ~= 2 or ns.BagRuleRank("Sell") ~= 2 then error("rules added in order") end
    ns:BagRulesCommand("up 2")
    if ns.BagRuleRank("Sell") ~= 1 then error("a rule moves up") end
    ns:BagRulesCommand("remove 1"); ns:BagRulesCommand("remove 1")
    if #ns.db.bagRules ~= 0 then error("rules removed") end
    -- mail rules
    if not ns.MailRuleMatch("cloth", 7, 5) or ns.MailRuleMatch("cloth", 7, 6) or not ns.MailRuleMatch("gems", 3, 1) then error("mail kinds") end
    if not ns.MailRuleMatch("name:silk", 7, 5, "Silk Cloth") then error("mail by name") end
    ns.root.mailRules = nil
    ns:MailRulesCommand("add Mytailor cloth")
    ns:MailRulesCommand("add Mytailor wood")
    if #ns.root.mailRules ~= 1 then error("only kinds we know") end
    ns:MailRulesCommand("remove 1")
    -- holidays: on the checklist while they are on
    local store = { items = {}, done = {}, nextId = 1 }
    ns.SyncHolidayJobs(store, { "Brewfest" })
    ns.SyncHolidayJobs(store, { "Brewfest" })
    if #store.items ~= 1 or store.items[1].holiday ~= "Brewfest" then error("a holiday job, once") end
    ns.ChecklistAdd(store, "daily", "Mine")
    ns.SyncHolidayJobs(store, {})
    if #store.items ~= 1 or store.items[1].text ~= "Mine" then error("the holiday job goes, your own stays") end
    ns:ShowEvents()
    -- 11.5: interrupt rotation
    local roster = { Ann = { spells = { [1766] = 0 } }, Bob = { spells = { [6552] = 105 } }, Cid = { spells = { [2139] = 0, [20484] = 0 } }, Dee = { spells = { [20484] = 0 } } }
    local holders = ns.KickHolders(roster, 100)
    if holders.Ann ~= 0 or holders.Bob ~= 5 or holders.Cid ~= 0 or holders.Dee ~= nil then error("who has an interrupt") end
    local order = ns.KickOrder({ "Cid", "Bob", "Zed", "Ann" }, holders)
    if #order ~= 3 or order[1] ~= "Cid" or order[3] ~= "Ann" then error("the order set, people with an interrupt only") end
    if ns.KickOrder(nil, holders)[1] ~= "Ann" then error("A to Z with no order") end
    if ns.KickNext(order, holders, nil) ~= "Cid" then error("first in the order") end
    if ns.KickNext(order, holders, "Cid") ~= "Ann" then error("skips one whose interrupt is not ready") end
    holders.Ann = 3; holders.Cid = 10
    local who, left = ns.KickNext(order, holders, "Cid")
    if who ~= "Ann" or left ~= 3 then error("the soonest when nobody is ready") end
    ns:KickCommand("cid bob"); if ns.db.kickOrder[1] ~= "Cid" then error("names") end
    ns:KickCommand(""); if #ns.db.kickOrder ~= 0 then error("cleared") end
    if ns.kickTest then ns.kickTest.Update() end
    -- 11.5: class resource
    ns.db.resourceDesign = { style = "zigzag", width = 9999, gap = -3 }
    local rd = ns.ResourceDesign()
    if rd.style ~= "dots" or rd.width ~= 400 or rd.gap ~= 0 then error("resource design kept in range") end
    ns.db.resourceDesign = nil
    local x3, w3 = ns.DotLayout(3, 5, 180, 5)
    if w3 ~= 32 or x3 ~= 74 then error("dot layout: " .. tostring(x3) .. " " .. tostring(w3)) end
    if not ns.ClassResource("ROGUE") or ns.ClassResource("SHAMAN") then error("which classes have one") end
    if ns.resourceTest then ns.resourceTest.Update() end
    -- 11.5: professions
    local crafts = { ["Me - R"] = { Tailoring = { [1] = { n = "Bolt of Silk", i = 4305 }, [2] = { n = "Silk Bag", i = 4245 } } },
                     ["Alt - R"] = { Alchemy = { [3] = { n = "Healing Potion", i = 929 } }, Tailoring = { [1] = { n = "Bolt of Silk", i = 4305 } } } }
    local who2 = ns.WhoMakes(crafts, 4305)
    if #who2 ~= 2 or who2[1] ~= "Alt (Tailoring)" then error("who makes it") end
    local found = ns.SearchCrafts(crafts, "silk")
    if #found ~= 3 or found[1].name ~= "Bolt of Silk" then error("searching recipes") end
    ns:ShowCrafts(""); ns:ShowCrafts("silk")
    -- 11.5: key sheet, buff coverage, quiet mode
    if #ns.KeySheetBars() < 1 then error("the key sheet's bars") end
    ns:ShowKeySheet(true); ns:ShowKeySheet(false)
    local names = ns.CoverBuffNames("PRIEST", function() return true end)
    if ns.CoverBuffNames("SHAMAN", function() return true end) then error("no buff for that class") end
    local rawE, rawD = env.UnitExists, env.UnitIsDeadOrGhost
    env.UnitExists = function() return true end; env.UnitIsDeadOrGhost = function() return false end
    if ns.MissingBuff("raid1", { "Fortitude" }, function() return nil end) ~= true then error("missing a buff") end
    if ns.MissingBuff("raid1", { "Fortitude" }, function() return { name = "Fortitude" } end) ~= false then error("has the buff") end
    env.UnitExists, env.UnitIsDeadOrGhost = rawE, rawD
    if ns.coverTest then ns.coverTest.Update() end
    if ns:ToggleQuiet(true) ~= true or ns:ToggleQuiet(false) ~= false then error("quiet mode on and off") end
    -- 11.5: layouts per screen size
    if ns.ScreenKey(2560, 1440) ~= "2560x1440" or ns.ScreenKey(0, 0) ~= "screen" then error("screen key") end
    if not ns.DescribeLayoutContext("2/raid/1920x1080"):find("1920x1080") then error("describing a screen layout") end
    -- 11.4.5: cutscenes are never given a window's look
    local cine = newmock()
    rawset(cine, "GetName", function() return "CinematicFrame" end)
    if not ns.FullScreenFrame(cine) then error("the cutscene frame") end
    local big = newmock()
    rawset(big, "GetName", function() return "SomeFrame" end)
    rawset(big, "GetWidth", function() return 5000 end); rawset(big, "GetHeight", function() return 5000 end)
    local uw, uh = rawget(env.UIParent, "GetWidth"), rawget(env.UIParent, "GetHeight")
    rawset(env.UIParent, "GetWidth", function() return 1920 end); rawset(env.UIParent, "GetHeight", function() return 1080 end)
    local isFull = ns.FullScreenFrame(big)
    rawset(env.UIParent, "GetWidth", uw); rawset(env.UIParent, "GetHeight", uh)
    if not isFull then error("a frame as big as the screen") end
    -- 11.4: sorting bags by the bag sections
    local A = { itemID = 10, count = 1, quality = 4, classID = 4, link = "a" }
    local B = { itemID = 20, count = 5, quality = 1, classID = 0, link = "b" }
    local J = { itemID = 30, count = 1, quality = 0, classID = 15, link = "j" }
    local slots = { { item = J }, { item = nil }, { item = B }, { item = A } }
    local plan = ns.SortPlan(slots)
    if plan[1] ~= A or plan[2] ~= B or plan[3] ~= J then error("gear, then consumables, then junk") end
    local i1, j1 = ns.SortNextMove(slots, plan)
    if i1 ~= 1 or j1 ~= 4 then error("the first move") end
    slots[1].item, slots[4].item = A, J
    local i2, j2 = ns.SortNextMove(slots, plan)
    if i2 ~= 2 or j2 ~= 3 then error("the second move (into an empty slot)") end
    slots[2].item, slots[3].item = B, nil
    local i3, j3 = ns.SortNextMove(slots, plan)
    if i3 ~= 3 or j3 ~= 4 then error("the third move") end
    slots[3].item, slots[4].item = J, nil
    if ns.SortNextMove(slots, plan) then error("sorted: no more moves") end
    local R = { itemID = 40, count = 1, quality = 2, classID = 7, link = "r", section = "Mine" }
    ns.db.bagRules = { { kind = "name", value = "x", section = "Mine" } }
    if ns.SortPlan({ { item = A }, { item = R } })[1] ~= R then error("your own sections first") end
    ns.db.bagRules = nil
    -- 11.4: talent builds sent and received
    local text = ns.EncodeTalentBuild("SHAMAN", "Resto", "BkGAAAAAAAAAAAAAAAAAAAAAAMz+/=")
    local cls, nm, code = ns.DecodeTalentBuild(text)
    if cls ~= "SHAMAN" or nm ~= "Resto" or code ~= "BkGAAAAAAAAAAAAAAAAAAAAAAMz+/=" then error("a talent build as text and back") end
    if ns.DecodeTalentBuild("nonsense") then error("not a build") end
    -- 11.4: reputations across characters
    local store = { pins = { Darnassus = true }, chars = {
        ["Me - Realm"] = { class = "SHAMAN", reps = { Darnassus = { reaction = 5, now = 100, max = 6000 }, Stormwind = { reaction = 6, now = 5, max = 12000 } }, currencies = { Honor = 40 } },
        ["Alt - Realm"] = { class = "MAGE", reps = { Darnassus = { reaction = 4, now = 50, max = 3000 } }, currencies = {} } } }
    local rl = ns.RepLines(store, "Me - Realm")
    if not (rl[1].head and rl[1].name == "Darnassus" and rl[2].char == "Me - Realm" and rl[3].char == "Alt - Realm") then error("pinned, for every character, you first") end
    local sawStorm, sawHonor
    for _, l in ipairs(rl) do if l.name == "Stormwind" then sawStorm = true end; if l.name == "Honor" then sawHonor = true end end
    if not (sawStorm and sawHonor) then error("this character's others") end
    ns:ShowReps()
    -- 11.4: goals of your own and achievements
    if select(2, ns.GoalProgress({ kind = "own", need = 50, have = 10 }, {})) ~= "10 / 50" then error("your own goal") end
    local keepG = ns.db.goals
    ns.db.goals = {}
    ns:GoalCommand("add 20 Kill raptors")
    ns:GoalCommand("+ 1 5")
    if ns.db.goals[1].have ~= 5 or ns.db.goals[1].need ~= 20 then error("counting your own goal") end
    ns:GoalCommand("- 1 9")
    if ns.db.goals[1].have ~= 0 then error("never below nothing") end
    local d0, t0 = ns.GoalProgress({ kind = "ach", id = 1 }, { ach = function() return 3, 4, false end })
    if d0 ~= 0.75 or t0 ~= "3 / 4" then error("an achievement's progress") end
    ns.db.goals = keepG
    if ns.mountButtonsTest then ns.mountButtonsTest.mount:GetScript("OnClick")() end
    -- 11.3.1: the game's Edit Mode frames are moved with their plain SetPointBase, never their Lua SetPoint
    local gf = newmock()
    local used = {}
    rawset(gf, "SetPoint", function() used.lua = true end)
    rawset(gf, "ClearAllPoints", function() used.luaClear = true end)
    rawset(gf, "SetPointBase", function() used.base = true end)
    rawset(gf, "ClearAllPointsBase", function() used.baseClear = true end)
    rawset(gf, "GetWidth", function() return 100 end); rawset(gf, "GetHeight", function() return 20 end); rawset(gf, "GetScale", function() return 1 end)
    rawset(gf, "GetNumPoints", function() return 0 end)
    ns.db.pos.testEditModeFrame = { "CENTER", "CENTER", 10, 10 }
    local ginfo = ns:AdoptGameFrame(gf, "testEditModeFrame", "Test")
    if not ginfo then error("the test frame was not adopted") end
    do
        ginfo.entry.onMoved()
        if not (used.base and used.baseClear) or used.lua or used.luaClear then error("an Edit Mode frame was moved with its Lua SetPoint") end
        ginfo.entry.onReset()
    end
    ns.db.pos.testEditModeFrame = nil
    -- 11.3: group cooldowns
    local k, ids = ns.ParseGroupCD("GCH:20484,1766")
    if k ~= "have" or #ids ~= 2 or ids[1] ~= 20484 then error("what someone has") end
    local k2, id2, s2 = ns.ParseGroupCD("GCD:1766:10")
    if k2 ~= "used" or id2 ~= 1766 or s2 ~= 10 or ns.ParseGroupCD("GCD:x") or ns.ParseGroupCD("GCQ") ~= "ask" then error("cooldown messages") end
    for key in pairs(ns.groupCDRoster) do ns.groupCDRoster[key] = nil end
    ns.GroupCDHave("Ally", "DRUID", { 20484, 29166 }, 100)
    ns.GroupCDHave("Rogue", "ROGUE", { 1766 }, 100)
    ns.GroupCDUsed("Ally", "DRUID", 20484, 1800, 100)
    local lines = ns.GroupCDLines(160, nil)
    if #lines ~= 3 or lines[1].kind ~= "res" or math.floor(lines[1].left) ~= 1740 or lines[2].kind ~= "kick" or lines[2].left ~= 0 then error("the panel's lines, in order") end
    if #ns.GroupCDLines(160, { Rogue = true }) ~= 1 then error("only people in the group") end
    ns.GroupCDHave("Ally", "DRUID", { 29166 }, 200)
    if ns.groupCDRoster.Ally.spells[20484] ~= nil then error("a spell no longer had is dropped") end
    if ns.groupCDTest then ns.groupCDTest.Update() end
    for key in pairs(ns.groupCDRoster) do ns.groupCDRoster[key] = nil end
    -- 11.3: sending a setup
    local text = string.rep("abcdefghij", 45)
    local parts = ns.ShareChunks(text)
    if #parts ~= 3 or table.concat(parts) ~= text then error("pieces") end
    local whole
    for i = #parts, 1, -1 do                                   -- (out of order, and one twice)
        local id, n, total, kind, piece = ns.ParseSharePiece(string.format("SS:ab12:%d:%d:layout:%s", i, #parts, parts[i]))
        whole = ns.ShareReceive("Friend", id, n, total, kind, piece, 10) or whole
        if i == 2 then ns.ShareReceive("Friend", id, n, total, kind, piece, 10) end
    end
    if whole ~= text then error("the pieces are put back together") end
    if ns.ParseSharePiece("SS:bad") or ns.ShareReceive("X", "a", 5, 2, "layout", "x", 1) then error("bad pieces are ignored") end
    if ns:SendSetup("", "layout") then error("no name, nothing sent") end
    -- 11.3: totems
    local fake = { ids = { 1, 2, 3 } }
    local realName = env.C_Spell
    local known = ns.KnownTotems(fake, function(id) return id ~= 2 end)
    if ns.NextTotem({}, nil) ~= nil then error("no totems") end
    local list = { { name = "A" }, { name = "B" } }
    if ns.NextTotem(list, "A").name ~= "B" or ns.NextTotem(list, "B").name ~= "A" or ns.NextTotem(list, "B", true).name ~= "A" or ns.NextTotem(list, "Z").name ~= "A" then error("choosing the next totem") end
    -- 11.3: auras
    ns.db.auraDesign = nil
    local d = ns.AuraDesign("target")
    if d.show ~= "both" or d.max ~= 10 or ns.AuraDesign("focus").show ~= "none" then error("aura defaults") end
    ns.db.auraDesign = { target = { max = 99, size = 5, show = "nope" }, raid = { hots = 9 } }
    d = ns.AuraDesign("target")
    if d.max ~= 16 or d.size ~= 14 or d.show ~= "both" or ns.AuraDesign("raid").hots ~= 3 then error("aura values are kept in range") end
    local p, x = ns.AuraSlot(3, 20, "left")
    if p ~= "BOTTOMRIGHT" or x ~= -46 then error("growing left") end
    ns.db.auraBlock = { "Weakened Soul" }
    if not ns.AuraBlocked("weakened soul") or ns.AuraBlocked("Renew") then error("hidden on frames") end
    ns.db.auraBlock = nil; ns.db.auraDesign = nil
    if ns.ApplyAuraDesign then ns:ApplyAuraDesign() end
    -- the game's raid manager, hidden and given back
    local mgr = newmock()
    env.CompactRaidFrameManager = mgr
    ns.db.hideRaidManager = true
    if ns:ApplyRaidManager() ~= true or not rawget(mgr, "suiHidden") then error("the raid manager is hidden") end
    ns.db.hideRaidManager = false
    if ns:ApplyRaidManager() ~= false or rawget(mgr, "suiHidden") then error("the raid manager comes back") end
    env.CompactRaidFrameManager = nil
    -- ready-made bag sections and mail by switches
    local db = { bagSecMine = true, bagSecMats = true, bagSecConsumables = true, bagSecBoE = true }
    if ns.BagSectionFor({ classID = 7, subclassID = 5 }, {}, db) ~= ns:Tr("Cloth") then error("cloth has its section") end
    if ns.BagSectionFor({ classID = 0, subclassID = 5 }, {}, db) ~= ns:Tr("Food and drink") then error("food has its section") end
    if ns.BagSectionFor({ classID = 4, bindType = 2, bound = false }, {}, db) ~= ns:Tr("Bind on equip") then error("BoE section") end
    if ns.BagSectionFor({ classID = 4, bindType = 2, bound = true }, {}, db) ~= nil then error("bound gear stays") end
    if ns.BagSectionFor({ classID = 7, subclassID = 5 }, { { kind = "type", value = "trade", section = "Mine" } }, db) ~= "Mine" then error("your own rules first") end
    db.bagSecMine = false
    if ns.BagSectionFor({ classID = 7, subclassID = 5 }, { { kind = "type", value = "trade", section = "Mine" } }, db) ~= ns:Tr("Cloth") then error("own rules switched off") end
    db.bagSecMats = false
    if ns.BagSectionFor({ classID = 7, subclassID = 5 }, {}, db) ~= nil then error("switched off: the usual sections") end
    if ns.BagRuleRank(ns:Tr("Upgrades")) >= ns.BagRuleRank(ns:Tr("Recipes")) or ns.BagRuleRank("Zzz") ~= 1000 then error("ready-made order") end
    local jobs = ns.MailJobs({ { to = "Tailor", what = "name:silk" } }, { mailCloth = true, mailOre = true, mailHerbs = true },
        { cloth = "Tailor", ore = "Smith", herbs = "Me" }, "Me")
    if #jobs ~= 2 or jobs[1].to ~= "Tailor" or #jobs[1].whats ~= 2 or jobs[2].whats[1] ~= "ore" then error("one letter's worth per character, never to yourself") end
    if #ns.MailJobs({ { to = "Tailor", what = "cloth" } }, { mailRulesOn = false }, {}, "Me") ~= 0 then error("own mail rules switched off") end
    -- the Layout tab's buttons fit side by side on one row, and the "as numbers" switches are on the Features tab
    local lp = ns.OptionsSheet("layout")
    local bw = 0
    for _, b in ipairs(rawget(lp, "topButtons") or {}) do bw = bw + (rawget(b, "suiW") or 0) end
    if bw > 0 and bw + 5 * 8 + 10 > 736 then error("the Layout tab's buttons overlap") end
    local numbers = ns:SettingsSection("frames:Numbers on frames")
    local foundN = 0
    for _, k in ipairs(numbers.keys) do if k == "healthNumbers" or k == "powerNumbers" or k == "xpNumbers" then foundN = foundN + 1 end end
    if foundN ~= 3 then error("the three 'as numbers' switches are in Numbers on frames") end
    -- Mail has a box per material and the mail rules; Bag sections has the bag rules
    ns:ToggleConfig("items:Mail")
    local fp = ns.featuresPage
    local e = fp.extras and fp.extras.mailTargets
    if not e or not e.frame.boxes.cloth then error("the Mail section has the Send to boxes") end
    if rawget(ns.toolsPage.ruleBlocks.mailRules, "lentTo") ~= fp then error("the Mail section has the mail rules") end
    ns:ToggleConfig("items:Bag sections")
    if rawget(ns.toolsPage.ruleBlocks.bagRules, "lentTo") ~= fp then error("the Bag sections section has the bag rules") end
    -- 11.6: the translations are a folder of their own, loaded only for a language other than English
    do
        local keepL, keepTried, keepLang, before = ns.locales, ns.localesLoadTried, ns.root.language, localeLoads
        ns.locales = {}; ns.localesLoadTried = nil
        if ns:NeedLocale("enUS") or ns:NeedLocale("enGB") or localeLoads ~= before then error("English needs no translations folder") end
        ns.root.language = "deDE"; ns:LoadLocale()
        if localeLoads ~= before + 1 or not ns.locales.deDE or ns:Tr("Options") == "Options" then error("German loads the translations folder") end
        ns:NeedLocale("frFR")
        if localeLoads ~= before + 1 then error("the folder is loaded once") end
        ns.locales, ns.localesLoadTried, ns.root.language = keepL, keepTried, keepLang
        ns:LoadLocale()
    end
    -- talent builds
    ns:TalentCommand("")
    ns:HideLists()
end)
try("Talent builds are the game's loadout codes, put back through its own Import box", function()
    local keep = { env.C_ClassTalents, env.C_Traits, env.PlayerSpellsUtil, env.ClassTalentLoadoutImportDialog }
    local code = "BkGAAAAAAAAAAAAAAAAAAAAAAMzMjZmZMzYGzMjZGAAAAAAgZmZmZGzMzMzYmBAAAAgZmB"
    env.C_ClassTalents = { GetActiveConfigID = function() return 7 end }
    env.C_Traits = { GenerateImportString = function(id) if id == 7 then return code end end }
    -- saving keeps the game's own code and the specialization's name
    ns.TalentBuilds()["Old style"] = { talents = { [1] = { [1] = 3 } }, points = { 3 } }     -- (from the older talent system: dropped)
    local b = ns:SaveTalentBuild("Elemental AoE")
    if not b or b.code ~= code or b.spec ~= "Elemental" then error("a build is the game's code: " .. tostring(b and b.code)) end
    if ns.TalentBuilds()["Old style"] then error("a build from the older talent system cannot be used and is dropped") end
    -- putting it back: the talent window opens, and its Import box gets the code and the name
    local opened, shown, typed = 0, 0, {}
    env.PlayerSpellsUtil = { OpenToClassTalentsTab = function() opened = opened + 1 end }
    local function box(key) local e = newmock(); rawset(e, "SetText", function(_, t) typed[key] = t end); local c = newmock(); rawset(c, "GetEditBox", function() return e end); return c end
    local dialog = newmock()
    rawset(dialog, "ShowDialog", function() shown = shown + 1 end)
    rawset(dialog, "ImportControl", box("code")); rawset(dialog, "NameControl", box("name"))
    rawset(dialog, "UpdateAcceptButtonEnabledState", function() end)
    env.ClassTalentLoadoutImportDialog = dialog
    if not ns:ApplyTalentBuild("Elemental AoE") then error("putting a build back") end
    if opened ~= 1 or shown ~= 1 or typed.code ~= code or typed.name ~= "Elemental AoE" then error("the game's Import box should be filled in") end
    if ns.talentImportState ~= "the game's Import box" then error("said: " .. tostring(ns.talentImportState)) end
    -- without that box, the code is shown to copy instead
    env.ClassTalentLoadoutImportDialog = false
    if not ns:ApplyTalentBuild("Elemental AoE") or ns.talentImportState ~= "copy box" then error("no Import box: the code to copy") end
    ns:HideLists()
    ns.TalentBuilds()["Elemental AoE"] = nil
    env.C_ClassTalents, env.C_Traits, env.PlayerSpellsUtil, env.ClassTalentLoadoutImportDialog = keep[1], keep[2], keep[3], keep[4]
end)
try("11.6: execute line, group practice, enemy cooldowns, upgrades, new characters", function()
    -- the execute line only on an enemy
    local realAttack, realExists = env.UnitCanAttack, env.UnitExists
    env.UnitCanAttack = function() return false end
    if ns.ExecuteWanted() then error("no execute line on a friend") end
    env.UnitCanAttack = function() return true end
    if not ns.ExecuteWanted() then error("an execute line on an enemy") end
    env.UnitExists = function() return false end
    if ns.ExecuteWanted() then error("no execute line without a target") end
    env.UnitCanAttack, env.UnitExists = realAttack, realExists
    if ns.executeTest then
        local frame = newmock(); local bar = newmock(); rawset(frame, "health", bar)
        rawset(bar, "GetWidth", function() return 200 end)
        local realT = env.FantasyGlassUI_Target
        env.FantasyGlassUI_Target = frame
        env.UnitCanAttack = function() return false end
        if ns.executeTest.Place() ~= false or not ns.executeState:find("not an enemy") then error("the line hides on a friend") end
        env.UnitCanAttack = function() return true end
        local px = ns.executeTest.Place(); if type(px) ~= "number" or px <= 0 then error("the line shows on an enemy: " .. tostring(px) .. " " .. tostring(ns.executeState)) end
        env.UnitCanAttack, env.FantasyGlassUI_Target = realAttack, realT
    end

    -- group practice: made-up group mates in the cooldown list, taking turns to interrupt
    local roster = {}
    local names = ns.TestGroupFill(roster, 100, "Me", "SHAMAN", { 8042 })
    if #names ~= 6 or not roster.Aldric or roster.Aldric.spells[871] ~= 1600 or roster.Brenna.spells[1766] ~= 0 or not roster.Me.spells[8042] then error("the practice group") end
    local realRoster = {}
    for k, v in pairs(ns.groupCDRoster) do realRoster[k] = v; ns.groupCDRoster[k] = nil end
    ns.TestGroupFill(ns.groupCDRoster, 100, "Me", "SHAMAN", { 8042 })
    ns.kickState.last = nil
    local keepOrder = ns.db.kickOrder; ns.db.kickOrder = nil
    local t = { me = "Me", myKick = 8042, lastTurn = 0 }
    local who = ns.TestGroupStep(t, 100)
    if who ~= "Aldric" or ns.kickState.last ~= "Aldric" or ns.groupCDRoster.Aldric.spells[6552] ~= 110 then error("the first made-up player interrupts: " .. tostring(who)) end
    if ns.TestGroupStep(t, 101) then error("one turn every few seconds") end
    if ns.TestGroupStep(t, 104.5) ~= "Brenna" or ns.TestGroupStep(t, 109) ~= "Corin" then error("the turn goes round") end
    if ns.TestGroupStep(t, 113) ~= nil or not t.myTurnSince then error("your turn waits for you") end
    if ns.TestGroupStep(t, 120) ~= "Me" then error("your turn is taken for you after a while") end
    for k in pairs(ns.groupCDRoster) do ns.groupCDRoster[k] = nil end
    for k, v in pairs(realRoster) do ns.groupCDRoster[k] = v end
    ns.db.kickOrder = keepOrder; ns.kickState.last = nil
    -- the command: refused in a group, on alone, off again with nothing left behind
    local realGroup, realRaid = env.IsInGroup, env.IsInRaid
    if ns:ToggleTestGroup(true) ~= false or ns.testGroup then error("no practice in a real group") end
    env.IsInGroup = function() return false end; env.IsInRaid = function() return false end
    local keepCD, keepKick, keepCover = ns.db.groupCDs, ns.db.kickRotation, ns.db.buffCoverage
    if ns:ToggleTestGroup(true) ~= true or not ns.testGroup or not ns.groupCDRoster.Dalia then error("practice starts alone") end
    if ns.kickTest and ns.kickTest.Update() == nil then error("the interrupt bar shows in practice") end
    if ns.groupCDTest and ns.groupCDTest.Update() < 5 then error("the cooldown panel lists the practice group") end
    if ns.coverTest and ns.raidSamples and #ns.raidSamples > 0 then
        if ns.coverTest.Update() < 1 then error("buff coverage marks sample raid frames in practice") end
    end
    if ns:ToggleTestGroup() ~= false or ns.testGroup or ns.groupCDRoster.Dalia or ns.previewing then error("practice ends cleanly") end
    env.IsInGroup, env.IsInRaid = realGroup, realRaid

    -- enemy cooldowns
    if ns.EnemyCDFor(2139)[2] ~= "kick" or ns.EnemyCDFor(42292)[2] ~= "trinket" or ns.EnemyCDFor(12345) then error("enemy spells") end
    if ns.EnemyCDFor(setmetatable({ __secret = true }, secretmt)) then error("a hidden spell is skipped") end
    ns.EnemyCDReset()
    local line = ns.EnemyCDLine("arena1", 100, true)
    if #line ~= 1 or line[1].kind ~= "trinket" or line[1].left ~= 0 then error("an arena enemy has a trinket from the start") end
    if #ns.EnemyCDLine("Someone", 100, false) ~= 0 then error("nothing known about someone else yet") end
    if ns.EnemyCDUsed("arena1", 2139, 100) ~= "kick" or ns.EnemyCDUsed("arena1", 42292, 101) ~= "trinket" then error("used") end
    line = ns.EnemyCDLine("arena1", 110, true)
    if #line ~= 2 or line[1].kind ~= "trinket" or math.floor(line[1].left) ~= 111 or line[2].kind ~= "kick" or line[2].left ~= 14 then error("the icons, in order, counting down") end
    if ns.EnemyWho("arena2") ~= "arena2" or ns.EnemyWho(setmetatable({ __secret = true }, secretmt)) then error("who") end
    ns.EnemyCDReset()
    if ns.arenaTest then ns.arenaTest.Update() end

    -- upgrades: what goes on, and where
    local items = {
        { link = "ring60", ilvl = 60, loc = "INVTYPE_FINGER", bound = true },
        { link = "ring55", ilvl = 55, loc = "INVTYPE_FINGER", bound = true },
        { link = "helm70", ilvl = 70, loc = "INVTYPE_HEAD", bound = false },
        { link = "axe90", ilvl = 90, loc = "INVTYPE_2HWEAPON", bound = true },
        { link = "sword80", ilvl = 80, loc = "INVTYPE_WEAPON", bound = true },
    }
    local worn = { [1] = { ilvl = 50, loc = "INVTYPE_HEAD" }, [11] = { ilvl = 50, loc = "INVTYPE_FINGER" }, [12] = { ilvl = 58, loc = "INVTYPE_FINGER" },
                   [16] = { ilvl = 40, loc = "INVTYPE_WEAPON" }, [17] = { ilvl = 40, loc = "INVTYPE_WEAPON" } }
    local plan, unbound = ns.EquipPlan(items, worn)
    local where = {}
    for _, p in ipairs(plan) do where[p.item.link] = p.slot end
    if where.ring60 ~= 11 or where.ring55 ~= nil then error("the better ring replaces the worse one, and the next is no longer better") end
    if where.axe90 ~= nil then error("a two-hander is not swapped for a one-hander") end
    if where.sword80 ~= 16 then error("a weapon of the same kind is") end
    if where.helm70 ~= nil or #unbound ~= 1 or unbound[1].link ~= "helm70" then error("unbound gear is left to you") end
    if ns:EquipBest() ~= 0 then error("nothing to put on in the harness") end
    if ns.upgradeTest then ns.upgradeTest.Rewards() end

    -- new characters
    if ns.AltRole("HEALER", "WARRIOR") ~= "DAMAGE" or ns.AltRole("TANK", "WARRIOR") ~= "TANK" or ns.AltRole("HEALER", "DRUID") ~= "HEALER" then error("roles") end
    local db = { role = "HEALER", executeLine = false, swingTimer = true, pos = {}, kickOrder = { "A" } }
    local ch = ns.FitProfile(db, "PRIEST", "WARRIOR")
    if db.role ~= "DAMAGE" or not ch.roleChanged or db.pos.ufPlayer[3] ~= ns.layouts.DAMAGE.ufPlayer[2] then error("a healer's layout becomes damage's") end
    if db.executeLine ~= true or #ch.switched ~= 1 or db.kickOrder ~= nil then error("the class's suggestions") end
    local root = { profiles = { Default = { role = "HEALER" }, Alt = { role = "TANK" } },
                   chars = { ["Main - R"] = "Default", ["Old - R"] = "Alt" },
                   charInfo = { ["Main - R"] = { class = "PRIEST", last = 200 }, ["Old - R"] = { class = "WARRIOR", last = 100 } } }
    if ns.AltSource(root, "New - R") ~= "Main - R" then error("the character played last") end
    root.mainChar = "Old - R"
    if ns.AltSource(root, "New - R") ~= "Old - R" then error("your main first") end
    local made = ns:NewCharacterProfile(root, "New - R")
    if made ~= "New - R" or type(root.profiles["New - R"]) ~= "table" or root.profiles["New - R"] == root.profiles.Alt then error("a profile of its own") end
    if root.profiles["New - R"].role ~= "DAMAGE" then error("fitted to a rogue") end
    root.altCopy = false
    if ns:NewCharacterProfile(root, "Other - R") ~= nil then error("switched off: share Default") end
    if ns.AltSource({ profiles = { Default = {} }, chars = {} }, "X") ~= nil then error("nothing set up yet: the setup runs") end
    ns:NoteCharacter(root, "New - R")
    if root.charInfo["New - R"].class ~= "ROGUE" then error("each character is noted") end
    local keepMain = ns.root.mainChar
    ns:MainCommand("")
    if ns.root.mainChar ~= ns:CharKey() then error("/fgui main") end
    ns:MainCommand("off")
    if ns.root.mainChar ~= nil then error("/fgui main off") end
    ns.root.mainChar = keepMain
    ns.altSetupNote = nil
end)
try("11.7: ready me, boss notes, death recap, backups, history, templates, packs, auction, home key, costs", function()
    -- am I ready?
    local lines = ns.ReadyMeLines({ buffs = { "Well Fed", "Flask of the Titans" }, weapon = false, durability = 30, reagents = { { name = "Ankh", n = 0 } }, free = 2, talentSet = 1, gearSet = false })
    local by = {}
    for _, l in ipairs(lines) do by[l.label] = l end
    if by.Food.ok ~= true or by["Flask or elixir"].ok ~= true or by["Weapon oil, stone or imbue"].ok ~= false then error("buffs and weapon") end
    if by.Repair.ok ~= false or by.Ankh.ok ~= false or by["Bag space"].ok ~= false or by["Talent set"].ok ~= true or by["Gear set"].ok ~= nil then error("repair, reagents, bags, talents, gear") end
    if ns.ReadyMeLines({})[1].ok ~= nil then error("buffs that cannot be read are not called missing") end
    if type(ns:ReadyMe()) ~= "number" then error("the panel") end
    -- boss notes
    local keepNotes, keepSent = ns.root.bossNotes, ns.root.bossNotesSent
    ns.root.bossNotes, ns.root.bossNotesSent = nil, nil
    if ns.BossKey("  Ragnaros ") ~= "ragnaros" or ns.BossKey(setmetatable({ __secret = true }, secretmt)) then error("boss keys") end
    ns:SetBossNote("Ragnaros", "Melee out at submerge.\nHealers: tank.")
    local mine = ns:BossNote("ragnaros")
    if not mine or mine.name ~= "Ragnaros" or not mine.text:find("submerge") then error("a note is kept") end
    if not ns:ShowBossNote("Ragnaros") or ns:ShowBossNote("Onyxia", true) then error("shown, or quietly not") end
    if not ns:ReceiveBossNote("Leader", "Onyxia~n~Deep breath: move.") then error("a sent note") end
    local m2, s2 = ns:BossNote("Onyxia")
    if m2 or not s2 or s2.from ~= "Leader" or s2.text ~= "Deep breath: move." then error("a sent note sits beside your own") end
    if ns:BossNoteCommand("list") ~= 2 then error("the list") end
    ns:SetBossNote("Ragnaros", "")
    if ns:BossNote("Ragnaros") then error("an empty note is deleted") end
    ns.root.bossNotes, ns.root.bossNotesSent = keepNotes, keepSent
    -- death recap
    local list = {}
    ns.DeathRecapNote(list, "WOUND", "CRITICAL", 500, 10)
    ns.DeathRecapNote(list, "HEAL", nil, 200, 11)
    ns.DeathRecapNote(list, "ENERGIZE", nil, 5, 11.5)
    ns.DeathRecapNote(list, setmetatable({ __secret = true }, secretmt), nil, setmetatable({ __secret = true }, secretmt), 12)
    if #list ~= 3 or not list[1].crit or list[2].kind ~= "Heal" or list[3].kind ~= "Hit" then error("what is noted") end
    ns.DeathRecapNote(list, "WOUND", nil, 10, 12.5, 4)
    if list[#list].school ~= "Fire" and list[#list].school ~= env.STRING_SCHOOL_FIRE then error("the kind of damage") end
    if ns.DamageSchool(setmetatable({ __secret = true }, secretmt)) or ns.DamageSchool(3) then error("hidden or mixed schools are left out") end
    table.remove(list)
    for i = 1, 30 do ns.DeathRecapNote(list, "WOUND", nil, i, 12 + i) end
    if #list ~= 20 then error("only the last twenty are kept") end
    local recent = ns.DeathRecapLines(list, 42, 5)
    if #recent ~= 6 then error("the last few seconds: " .. #recent) end
    ns.deathRecap.last = { at = 12, events = { { kind = "Hit", amount = setmetatable({ __secret = true }, secretmt), t = 11 }, { kind = "Heal", amount = 50, t = 11.5 } } }
    if ns:ShowDeathRecap() ~= 2 then error("the recap window, a hidden amount included") end
    ns.deathRecap.last = nil
    -- backups
    local root = { profiles = { Default = { a = 1 } }, chars = { X = "Default" }, seenVersion = "11.5.0" }
    ns.backupsTaken = nil
    local took = ns:TakeBackups(root, 20261116)
    if #took ~= 2 or root.backups.update.label ~= "11.5.0" or root.backups.daily.profiles.Default.a ~= 1 or root.backups.daily.profiles.Default == root.profiles.Default then error("backups are copies") end
    ns.backupsTaken = nil
    root.seenVersion = ns.version
    if #ns:TakeBackups(root, 20261116) ~= 0 then error("once a day, and once an update") end
    ns.backupsTaken = true
    local bl = ns.BackupLines(root.backups, (root.backups.daily.when or 0) + 7200)
    if #bl ~= 2 or bl[1].kind ~= "update" or bl[2].profiles ~= 1 then error("the backup list") end
    local realRoot = ns.root
    ns.root = root
    root.profiles.Default.a = 2
    local okR = ns:RestoreBackup("daily")
    if not okR or root.profiles.Default.a ~= 1 or root.backups.restore.profiles.Default.a ~= 2 then error("restore, keeping what was there") end
    if ns:RestoreBackup("nothing") then error("no such backup") end
    ns.root = realRoot
    if ns:BackupCommand("") < 1 then error("the backups window") end
    -- what changed
    local before = ns.FlattenSettings({ raidW = 80, pos = { ufPlayer = { "CENTER", "CENTER", 0, 0 } }, layouts = { x = 1 } })
    local after = ns.FlattenSettings({ raidW = 96, pos = { ufPlayer = { "CENTER", "CENTER", 10, 0 } }, newThing = true })
    local diff = ns.SettingsDiff(before, after)
    local paths = {}
    for _, d in ipairs(diff) do paths[d.path] = d end
    if not paths.raidW or paths.raidW.old ~= "80" or paths.raidW.new ~= "96" or not paths["pos.ufPlayer"] or not paths.newThing or paths.layouts then error("the changes, the layouts snapshots left out") end
    local keepW = ns.db.raidW
    ns:NoteSettingChanges()
    ns.db.raidW = (tonumber(keepW) or 80) + 7
    if ns:NoteSettingChanges() ~= 1 then error("one change noted") end
    if not ns:UndoSettingChange(1) or ns.db.raidW ~= keepW then error("undone") end
    if ns:ShowSettingHistory() < 1 then error("the history window") end
    -- the list says what a change is in words, not by its stored name
    if ns.SettingName("pos.ufPlayer") == "pos.ufPlayer" or not ns.SettingName("pos.ufPlayer"):find(ns:Tr("Panel positions"), 1, true) then
        error("a panel's place should read as its name: " .. tostring(ns.SettingName("pos.ufPlayer"))) end
    if ns.SettingValue("true") ~= ns:Tr("on") or ns.SettingValue("false") ~= ns:Tr("off") or ns.SettingValue("42") ~= "42" then error("on and off in words") end
    if ns.SettingName("someUnknownKey") ~= "someUnknownKey" then error("an unknown setting keeps its stored name") end
    -- templates
    local t = ns.TemplateProfile("HEALER", { theme = "SMOKE", accent = "VIOLET" })
    if t.role ~= "HEALER" or t.accent ~= "VIOLET" or t.raidFrames ~= true or t.pos.raid[1] ~= "CENTER" then error("a healer template") end
    local okT, _, tName = ns:NewTemplateProfile("TANK")
    if not okT or type(ns.root.profiles[tName]) ~= "table" or ns.root.profiles[tName].role ~= "TANK" then error("a tank profile") end
    ns.root.profiles[tName] = nil
    if ns:NewTemplateProfile("BARD") then error("no such role") end
    -- whole-UI packs
    local pack = ns:ExportPack()
    if pack:sub(1, 5) ~= "FGP1!" then error("a pack string") end
    local kind, data = ns:DecodeShared(pack)
    if kind ~= "pack" or type(data.profile) ~= "table" then error("read back") end
    local okP = ns:ImportPack("Pack test", pack)
    if not okP or type(ns.root.profiles["Pack test"]) ~= "table" or ns.root.profiles["Pack test"].theme ~= ns.db.theme then error("taken") end
    ns.root.profiles["Pack test"] = nil
    if ns:ImportPack("Other", ns:ExportProfile()) then error("a profile string is not a pack") end
    local clean = ns.CleanPackProfile({ pos = { a = { "X", "X", 1, 2 }, b = "nonsense" }, scale = { a = 9 }, ufDesign = { Player = { w = 200 } }, theme = 5 })
    if clean.pos.b or clean.pos.a[3] ~= 1 or clean.scale.a ~= 2 or clean.ufDesign.Player.w ~= 200 or clean.theme == 5 then error("a pack is cleaned") end
    ns:PreviewShared(pack)
    -- auction house
    local e = {}
    for d = 1, 20 do ns.AuctionHistoryAdd(e, 20261100 + d, 100 + d) end
    local n = 0
    for _ in pairs(e.hist) do n = n + 1 end
    if n ~= 14 then error("two weeks of daily lows") end
    local usual, days = ns.AuctionUsual({ hist = { [1] = 100, [2] = 300, [3] = 200 } })
    if usual ~= 200 or days ~= 3 then error("the usual price") end
    if ns.UndercutPrice({ price = 500, day = 5 }, 5, 0) ~= 499 or ns.UndercutPrice({ price = 500, day = 5 }, 5, 600) ~= 601 or ns.UndercutPrice(nil, 5) then error("undercut") end
    local worth = ns.WorthSelling({ { id = 1, count = 2, vendor = 10 }, { id = 2, count = 1, vendor = 1000 }, { id = 3, bound = true, vendor = 0 }, { id = 4, count = 1, vendor = 0 } },
        { [1] = { price = 500, day = 7 }, [2] = { price = 1200, day = 7 }, [3] = { price = 9999, day = 7 }, [4] = { price = 50, day = 7 } }, 7)
    if #worth ~= 1 or worth[1].item.id ~= 1 or worth[1].total ~= 1000 then error("worth selling") end
    ns:ShowWorthSelling()
    if ns.auctionHelperTest then ns.auctionHelperTest.Dress() end
    -- the price store: one per auction house (realm and faction), the old prices moved in once
    local function HouseAs(realm, faction)                     -- (the key is kept for the session: let it go after a change)
        env.GetRealmName = function() return realm end
        env.UnitFactionGroup = function() return faction end
        ns.PriceHouseKeyReset()
    end
    do
        local oldRealm, oldFaction = env.GetRealmName, env.UnitFactionGroup
        local okP, errP = pcall(function()
            HouseAs("Stormreach", "Alliance")
            if ns.PriceHouseKey() ~= "Stormreach|Alliance" then error("house key") end
            env.UnitFactionGroup = function() return "Horde" end
            if ns.PriceHouseKey() ~= "Stormreach|Alliance" then error("the key is kept for the session") end
            fireEvent("UNIT_FACTION", "player")
            if ns.PriceHouseKey() ~= "Stormreach|Horde" then error("a faction change lets the key go") end
            HouseAs("Stormreach", "Neutral")
            if ns.PriceHouseKey() ~= nil then error("a neutral character has no auction house") end
            local root = { auctionSeen = { [10] = { price = 500, day = 20261120, hist = { [20261120] = 500 } }, [11] = "junk", [12] = { price = "x" } } }
            local moved = ns.PricesMigrate(root, "Stormreach|Alliance")
            if moved ~= 1 or root.auctionSeen ~= nil or not root.prices.migrated or root.prices.houses["Stormreach|Alliance"].items[10].price ~= 500 then error("migrated once") end
            if ns.PricesMigrate(root, "Stormreach|Alliance") ~= 0 then error("only once") end
            local root2 = { auctionSeen = { [10] = { price = 1, day = 1 } } }
            if ns.PricesMigrate(root2, nil) ~= 0 or not root2.auctionSeen then error("no key: wait, keep the old prices") end
            -- the house already has the item: the later day gives the price, the histories are merged (the lower each day)
            local root3 = { auctionSeen = { [10] = { price = 7, day = 20261101, hist = { [20261101] = 7, [20261110] = 4 } }, [11] = { price = 9, day = 20261124 } },
                prices = { v = 1, houses = { K = { items = { [10] = { price = 5, day = 20261110, hist = { [20261110] = 5 } }, [11] = { price = 3, day = 20261110 } } } } } }
            ns.PricesMigrate(root3, "K")
            local m10 = root3.prices.houses.K.items[10]
            if m10.price ~= 5 or root3.prices.houses.K.items[11].price ~= 9 then error("the later day wins") end
            if m10.hist[20261101] ~= 7 or m10.hist[20261110] ~= 4 then error("both histories are kept, the lower price each day") end
            local long = { price = 1, day = 20261130, hist = {} }
            for d = 1, 10 do long.hist[20261100 + d] = d end
            local root4 = { auctionSeen = { [10] = long }, prices = { v = 1, houses = { K = { items = { [10] = { price = 2, day = 20261120, hist = { [20261120] = 2, [20261121] = 2, [20261122] = 2, [20261123] = 2, [20261124] = 2, [20261125] = 2, [20261126] = 2 } } } } } } }
            ns.PricesMigrate(root4, "K")
            local nh = 0
            for _ in pairs(root4.prices.houses.K.items[10].hist) do nh = nh + 1 end
            if nh ~= 14 or root4.prices.houses.K.items[10].price ~= 1 then error("merged histories keep 14 days: " .. nh) end
            -- a hidden realm is no key
            env.GetRealmName = function() return setmetatable({ __secret = true }, secretmt) end
            ns.PriceHouseKeyReset()
            if ns.PriceHouseKey() ~= nil then error("a hidden realm is no key") end
            -- the move happens where you first open the auction house, never for a neutral character
            local keepSeen, keepPrices = ns.root.auctionSeen, ns.root.prices
            local okM, errM = pcall(function()
                -- before the first auction house visit, the old prices are still read (never written)
                ns.root.auctionSeen = { [30] = { price = 70, day = ns.Today(), hist = { [1] = 70, [2] = 70 } }, [31] = "odd" }
                ns.root.prices = nil
                HouseAs("Stormreach", "Alliance")
                if not ns.PriceEntry(30) or ns.PriceEntry(30).price ~= 70 or ns.PriceEntry(31) then error("before the move: the old prices are read") end
                local ft = ns.FarmTotals({ elapsed = 60, gold = 0, items = { [30] = { n = 2, vendor = 1 } } }, 0, nil)
                if ft.value ~= 140 then error("before the move: farming totals count the old price: " .. tostring(ft.value)) end
                local zones = {}
                ns.FarmZonesSave({ zones = { Elwynn = { secs = 120, gold = 0, items = { [30] = { n = 3, vendor = 1 } } } } }, zones, 100)
                if not zones.Elwynn or zones.Elwynn[1].value ~= 210 then error("before the move: saved zone values keep auction prices") end
                local keepMem, keepTipG = ns.db.auctionMemory, env.GameTooltip
                local got = {}
                local t0 = setmetatable({ AddDoubleLine = function(_, l) got[#got + 1] = l end }, { __index = function() return function() end end })
                env.GameTooltip = t0
                ns.db.auctionMemory = true
                ns.PriceTooltip(t0, { id = 30 })
                env.GameTooltip, ns.db.auctionMemory = keepTipG, keepMem
                if not got[1] or not tostring(got[1]):find(ns:Tr("Auction house"), 1, true) then error("before the move: the tooltip shows the old price") end
                if not ns.PriceNote(30, 50) or ns.root.auctionSeen[30].price ~= 70 then error("the old prices are never written") end
                ns.root.prices = nil
                HouseAs("Stormreach", "Neutral")
                if ns.PriceEntry(30) then error("a neutral character reads nothing") end
                fireEvent("AUCTION_HOUSE_SHOW")
                if not ns.root.auctionSeen or (ns.root.prices and ns.root.prices.migrated) then error("a neutral character moves nothing") end
                HouseAs("Stormreach", "Alliance")
                fireEvent("AUCTION_HOUSE_SHOW")
                if ns.root.auctionSeen or not ns.PriceEntry(30) or ns.PriceEntry(30).price ~= 70 then error("moved when the auction house opens") end
            end)
            ns.root.auctionSeen, ns.root.prices = keepSeen, keepPrices
            if not okM then error(errM, 0) end
            HouseAs("Stormreach", "Alliance")
            -- old characters' odd entries: skipped or forgotten, every reader still works
            ns.root.auctionSeen = { [20] = { price = 300, day = ns.Today(), hist = { [ns.Today()] = 300, [1] = "odd" } }, [21] = 5, [22] = { price = "x", day = "y" },
                [23] = { day = 1 }, x = { price = 1, day = 1 } }
            ns.root.prices = nil
            local okR, errR = pcall(function()
                ns.PricesStart(ns.root, ns.PriceHouseKey(), ns.Today())
                if ns.root.auctionSeen ~= nil or not ns.PriceEntry(20) or ns.PriceEntry(20).price ~= 300 or ns.PriceEntry(21) or ns.PriceEntry(22) or ns.PriceEntry(23) then error("odd entries") end
                if not ns.PriceNote(20, 250) or ns.PriceEntry(20).price ~= 250 or ns.PriceEntry(20).listed ~= nil or ns.PriceEntry(20).seenDay ~= ns.Today() then error("browsing tops the store up, never the listed count") end
                if ns.PriceNote(20, setmetatable({ __secret = true }, secretmt)) or ns.PriceNote(20, 0) then error("hidden or no price is ignored") end
                local t = ns.FarmTotals({ elapsed = 60, gold = 0, items = { [20] = { n = 2, vendor = 1 } } }, 0, nil)
                if t.value ~= 500 then error("farming totals read the store: " .. tostring(t.value)) end
                ns:ShowWorthSelling()
                local lines = ns:CheckNew(true)
                for _, l in ipairs(lines) do if l:find("Auction", 1, true) and l:find("error:", 1, true) then error("/fgui check: " .. l) end end
                if not table.concat(ns:SelfCheck(true), "\n"):find("prices kept here: 1", 1, true) then error("the self-check counts the store") end
                HouseAs("Stormreach", "Horde")
                if ns.PriceEntry(20) ~= nil then error("prices never cross factions") end
                -- at login the current house is cleaned a slice at a time (200 entries a frame with no clock)
                local items = {}
                for i = 1, 500 do items[i] = { price = 1, day = (i % 2 == 0) and 20261125 or 20260101 } end
                ns.PricesForget(items, 20261125)
                local calls = 1
                while ns.PricesForgetStep() do calls = calls + 1 end
                local left = 0
                for _ in pairs(items) do left = left + 1 end
                if calls < 3 or left ~= 250 then error("the cleaning is sliced: " .. calls .. " calls, " .. left .. " left") end
            end)
            ns.root.auctionSeen, ns.root.prices = keepSeen, keepPrices
            if not okR then error(errR, 0) end
            HouseAs("Stormreach", "Horde")
            if ns.PriceEntry(10) ~= nil then error("prices never cross factions") end
            HouseAs("Stormreach", nil)
            if ns.PriceNote(10, 100) or next(ns.PriceItems()) ~= nil then error("no key: nothing noted, nothing read") end
        end)
        env.GetRealmName, env.UnitFactionGroup = oldRealm, oldFaction
        ns.PriceHouseKeyReset()
        if not okP then error(errP, 0) end
        if ns.PriceFreshText(nil, env.time()) ~= ns:Tr("Never scanned") then error("never scanned") end
        if ns.PriceFreshText({ scanAt = env.time() }, env.time()) ~= ns:Tr("Scanned today") then error("today") end
        if ns.PriceFreshText({ scanAt = env.time() - 86400 }, env.time()) ~= ns:Tr("Scanned yesterday") then error("yesterday") end
        if ns.PriceFreshText({ scanAt = env.time() - 3 * 86400 }, env.time()) ~= string.format(ns:Tr("Scanned %d days ago"), 3) then error("days ago") end
    end
    -- Scan prices: the rows, the write, the cooldown, and whole reads (a fight, a closed auction house, rows read again)
    do
        local hidden = {}
        local rows = { [0] = { 1, 1000, 5 }, [1] = { 4, 2000, 5 }, [2] = { 2, 0, 6 }, [3] = { 1, 300, nil }, [4] = { 1, hidden, 8 }, [5] = { 0, 50, 9 } }
        local function read(i) local r = rows[i]; return r[1], r[2], r[3] end
        local realIsSecret = ns.IsSecret
        ns.IsSecret = function(self, v) if rawequal(v, hidden) then return true end return realIsSecret(self, v) end
        local acc = {}
        local okS, retry, skipped = pcall(ns.PriceScanRows, read, 6, acc, 0, 99)
        ns.IsSecret = realIsSecret
        if not okS then error(retry, 0) end
        if acc[5].low ~= 500 or acc[5].listed ~= 5 then error("rows: the lowest unit price and the count") end
        if acc[6].low ~= nil or acc[6].listed ~= 2 then error("bid only: listed, no price") end
        if #retry ~= 1 or retry[1] ~= 3 then error("a row with no item is read again") end
        if acc[8] or skipped ~= 1 then error("a row with a hidden value is skipped, and counted") end
        if acc[9].low ~= 50 or acc[9].listed ~= 0 then error("count 0") end
        local house = { items = { [5] = { price = 900, day = 20261120, hist = { [20261120] = 900 } }, [7] = { price = 1234, day = 20261120, listed = 3 } } }
        local nw = ns.PriceScanWrite(house, { [5] = acc[5], [6] = acc[6] }, 20261125, 1800000000)
        if nw ~= 2 or house.items[5].price ~= 500 or house.items[5].listed ~= 5 or house.items[5].hist[20261125] ~= 500 or house.items[5].listedDay ~= 20261125 then error("write: a scanned item") end
        if house.items[7].listed ~= 0 or house.items[7].price ~= 1234 or house.items[7].listedDay ~= 20261125 then error("write: an item nobody lists keeps its price") end
        if house.scanAt ~= 1800000000 or house.scanItems ~= 2 or house.listedAt ~= 1800000000 then error("write: the scan's time") end
        if house.items[6].listed ~= 2 or house.items[6].price ~= nil then error("write: bid only") end
        local house2 = { items = { [7] = { price = 1234, day = 20261120, listed = 3 } } }
        ns.PriceScanWrite(house2, { [5] = acc[5] }, 20261125, 1800000000, false)
        if house2.items[7].listed ~= 3 or house2.listedAt ~= nil or house2.items[5].price ~= 500 then error("an incomplete scan leaves listed alone") end
        local keepPrices, keepSeenW = ns.root.prices, ns.root.auctionSeen
        ns.root.auctionSeen = nil
        local oldRealm, oldFaction, oldAH, oldCombat = env.GetRealmName, env.UnitFactionGroup, env.C_AuctionHouse, env.InCombatLockdown
        local okW, errW = pcall(function()
            ns.root.prices = { v = 1, lastScan = 1000 - 60 }
            local ready, left = ns.PriceScanReady(1000)
            if ready or left ~= 840 then error("the cooldown: " .. tostring(left)) end
            ns.root.prices = { v = 1 }
            if not ns.PriceScanReady(1000) then error("ready") end
            HouseAs("Stormreach", "Alliance")
            local calls, combat, total, missingOnce, readAt, distinct, hideHalf = 0, false, 3, {}, {}, false, false
            env.InCombatLockdown = function() return combat end
            env.C_AuctionHouse = { ReplicateItems = function() calls = calls + 1 end, GetNumReplicateItems = function() return total end,
                GetReplicateItemInfo = function(i)
                    readAt[i] = true
                    if type(i) ~= "number" or i < 0 or i >= total then error("row " .. tostring(i) .. " is outside the list") end
                    local id = distinct and (1000 + i) or (100 + (i % 3))
                    if missingOnce[i] then missingOnce[i] = nil; id = nil end
                    local count = 2
                    if hideHalf and i % 2 == 0 then count = setmetatable({ __secret = true }, secretmt) end
                    return "Name", 1, count, 1, true, 1, nil, 0, 0, 1000 * (1 + i % 3), 0, false, nil, "Owner", nil, 0, id, true
                end }
            local T = ns.priceScanTest
            local function Run(limit) for _ = 1, limit or 60 do if not T.state() then return end; T.Read() end end
            local function Fresh() ns.root.prices = { v = 1 } end
            local function Said(from, text) for i = from + 1, #printed do if tostring(printed[i]):find(text, 1, true) then return true end end return false end
            if ns.auctionScanTest.Label(1000) ~= ns:Tr("Scan prices") then error("the button when ready") end
            combat = true
            if ns:PriceScanStart() ~= false or calls ~= 0 then error("never in a fight") end
            combat = false
            if ns:PriceScanStart() ~= true or calls ~= 1 or ns.root.prices.lastScan ~= env.time() then error("the scan starts") end
            if ns:PriceScanStart() then error("one at a time") end
            if ns.auctionScanTest.Label() ~= ns:Tr("Waiting for the list…") then error("waiting: " .. ns.auctionScanTest.Label()) end
            fireEvent("REPLICATE_ITEM_LIST_UPDATE")
            Run()
            local h = ns.PriceHouse()
            if T.state() or not h or h.scanItems ~= 3 or ns.PriceEntry(100).price ~= 500 or ns.PriceEntry(101).price ~= 1000 or ns.PriceEntry(102).listed ~= 2 then error("a whole read is written") end
            if not readAt[0] or readAt[total] then error("the rows are counted from 0 to n - 1") end
            if h.listedAt == nil then error("a whole list is a full scan") end
            if ns.auctionScanTest.Label(env.time() + 60) ~= string.format(ns:Tr("Scan in %d:%02d"), 14, 0) then error("the countdown: " .. ns.auctionScanTest.Label(env.time() + 60)) end
            if ns:PriceScanStart() then error("not again within 15 minutes") end
            -- a complete scan marks what the house knew and nobody lists now
            ns.root.prices = { v = 1, houses = { ["Stormreach|Alliance"] = { items = { [7] = { price = 1234, day = 20261120, listed = 3 } } } } }
            ns:PriceScanStart(); fireEvent("REPLICATE_ITEM_LIST_UPDATE"); Run()
            if ns.PriceEntry(7).listed ~= 0 or ns.PriceEntry(7).price ~= 1234 then error("a full scan: listed 0 for the item it did not find") end
            -- a fight starts after the first slice: nothing is written until it ends
            total = 450
            Fresh()
            if not ns:PriceScanStart() then error("the second scan starts") end
            fireEvent("REPLICATE_ITEM_LIST_UPDATE")
            T.Read()
            if not T.state() or ns.PriceHouse() then error("450 rows take more than one slice") end
            combat = true
            T.Read(); T.Read()
            if ns.auctionScanTest.Label() ~= ns:Tr("Paused for combat") then error("paused: " .. ns.auctionScanTest.Label()) end
            combat = false
            T.Read()
            if ns.PriceHouse() or T.state().i ~= 200 then error("a fight pauses the read") end
            fireEvent("PLAYER_REGEN_ENABLED")
            Run()
            if T.state() or not ns.PriceHouse() or ns.PriceEntry(100).listed ~= 300 then error("the read goes on after the fight") end
            -- the auction house closes mid-read: nothing written
            Fresh()
            local mark = #printed
            if not ns:PriceScanStart() then error("the third scan starts") end
            fireEvent("REPLICATE_ITEM_LIST_UPDATE")
            T.Read()
            fireEvent("AUCTION_HOUSE_CLOSED")
            T.Read()
            if T.state() or ns.PriceHouse() or not Said(mark, "closed before the scan") then error("closed mid-read: thrown away") end
            -- no list within a minute
            Fresh()
            mark = #printed
            ns:PriceScanStart()
            runTimers()
            if T.state() or not Said(mark, "did not send its list") then error("no list: given up") end
            -- a row whose item isn't loaded yet is read again
            total = 3
            Fresh()
            missingOnce[1] = true
            ns:PriceScanStart()
            fireEvent("REPLICATE_ITEM_LIST_UPDATE")
            T.Read()
            if not T.state() or ns.PriceHouse() then error("waits to read a row again") end
            runTimers()
            Run()
            if T.state() or ns.PriceEntry(101) == nil then error("the row read again is written") end
            -- a big list: the entries are built in slices too, and the house is untouched until the last one
            total, distinct = 5000, true
            Fresh()
            ns:PriceScanStart(); fireEvent("REPLICATE_ITEM_LIST_UPDATE")
            for _ = 1, 100 do if not T.state() or T.state().phase == "writing" then break end; T.Read() end
            if not T.state() or T.state().phase ~= "writing" or ns.PriceHouse() then error("the read is done, nothing written yet") end
            local writes = 0
            while T.state() and writes < 100 do
                if ns.PriceHouse() then error("the house changed before the write was done") end
                T.Read(); writes = writes + 1
            end
            if writes < 2 or ns.PriceHouse().scanItems ~= 5000 or ns.PriceEntry(1000).price ~= 500 then error("the write is sliced: " .. writes .. " calls") end
            -- a price browsed while the entries are being built: its day low is kept, and its price when it is lower
            total, distinct = 450, true
            ns.root.prices = { v = 1, houses = { ["Stormreach|Alliance"] = { items = { [1000] = { price = 900, day = 20261120, hist = { [20261120] = 900 } } } } } }
            ns:PriceScanStart(); fireEvent("REPLICATE_ITEM_LIST_UPDATE")
            for _ = 1, 20 do if T.state().phase == "writing" then break end; T.Read() end
            T.Read()
            local stagedFirst = T.state() and T.state().staged[1000] ~= nil
            if not T.state() or not ns.PriceNote(1000, 1) then error("(the browse during the write)") end
            Run()
            local e1000 = ns.PriceEntry(1000)
            if T.state() or e1000.hist[ns.Today()] ~= 1 or e1000.seenDay ~= ns.Today() then error("the browse's day low is kept") end
            if (stagedFirst and e1000.price ~= 1) or (not stagedFirst and e1000.price ~= 500) then error("the browse's price: " .. tostring(e1000.price)) end
            -- an empty reply where the house knew more than 50 items: a failed scan, nothing written
            distinct = false
            local many = {}
            for i = 1, 60 do many[i] = { price = 10, day = 20261120, listed = 1 } end
            ns.root.prices = { v = 1, houses = { ["Stormreach|Alliance"] = { items = many } } }
            total = 0
            mark = #printed
            ns:PriceScanStart(); fireEvent("REPLICATE_ITEM_LIST_UPDATE"); Run()
            if T.state() or ns.PriceHouse().scanAt or many[1].listed ~= 1 or not Said(mark, "came back empty") then error("an empty scan is a failed scan") end
            Fresh()
            mark = #printed
            ns:PriceScanStart(); fireEvent("REPLICATE_ITEM_LIST_UPDATE"); Run()
            if T.state() or ns.PriceHouse() or not ns.root.prices.lastScan or not Said(mark, "came back empty") then error("an empty reply is never a scan, even into an empty house; the cooldown runs") end
            -- half the rows hidden: prices are written, but nothing is said about what nobody lists
            total, hideHalf = 40, true
            ns.root.prices = { v = 1, houses = { ["Stormreach|Alliance"] = { items = { [7] = { price = 1234, day = 20261120, listed = 3 } } } } }
            ns:PriceScanStart(); fireEvent("REPLICATE_ITEM_LIST_UPDATE"); Run()
            local hh = ns.PriceHouse()
            if T.state() or not hh.scanAt or hh.listedAt or ns.PriceEntry(7).listed ~= 3 or not ns.PriceEntry(101) then error("too many rows unread: prices only") end
            if not tostring(ns.priceScanState):find("20 of 40 rows unread", 1, true) then error("the unread rows are counted: " .. tostring(ns.priceScanState)) end
            hideHalf, total = false, 3
            -- hidden values in the list: no error, nothing stored
            Fresh()
            env.C_AuctionHouse.GetReplicateItemInfo = function() local x = setmetatable({ __secret = true }, secretmt); return "N", 1, x, 1, true, 1, nil, 0, 0, x, 0, false, nil, "O", nil, 0, x, true end
            ns:PriceScanStart()
            fireEvent("REPLICATE_ITEM_LIST_UPDATE")
            Run()
            if T.state() or next(ns.PriceItems()) ~= nil then error("hidden rows are skipped") end
        end)
        ns.root.prices, ns.root.auctionSeen = keepPrices, keepSeenW
        env.GetRealmName, env.UnitFactionGroup, env.C_AuctionHouse, env.InCombatLockdown = oldRealm, oldFaction, oldAH, oldCombat
        ns.PriceHouseKeyReset()
        if not okW then error(errW, 0) end
        ns.auctionScanTest.Dress()
    end
    -- Sell now, Hold, Vendor it
    do
        local today = 20261125
        local hist = { [20261120] = 1000, [20261121] = 1000, [20261122] = 1000, [20261123] = 950, [20261124] = 1050 }
        local function E(price, day, extra) local e = { price = price, day = day or today, hist = hist }; for k, v in pairs(extra or {}) do e[k] = v end; return e end
        local H = ns.SellHint
        local k, pct = H(E(1200), 0, 2, false, today, nil)
        if k ~= "sell" or pct ~= 20 then error("sell now: " .. tostring(k) .. " " .. tostring(pct)) end
        k, pct = H(E(700), 0, 2, false, today, nil)
        if k ~= "hold" or pct ~= 30 then error("hold: " .. tostring(k) .. " " .. tostring(pct)) end
        if H(E(700), 650, 2, false, today, nil) ~= "vendor" then error("a vendor pays about as much (700 <= 747.5)") end
        if H(E(700), 650, 3, false, today, nil) ~= "hold" then error("a rare cheap today: hold, never vendor it") end
        if H(E(700, today - 8), 900, 3, false, today, nil) ~= nil or H(E(700, today - 8), 900, 4, false, today, nil) ~= nil then error("a rare or epic near a vendor's price gets no hint, never vendor it") end
        if H(E(700, today - 8), 900, 2, false, today, nil) ~= "vendor" then error("(the same, uncommon: vendor it)") end
        if H(E(700, today - 8), 900, nil, false, today, nil) ~= nil then error("quality not known yet: no vendor it") end
        if H(E(700), 900, 3, false, today, nil) ~= nil then error("hold needs a usual price above what a vendor pays") end
        if H(E(1200, today - 8), 0, 2, false, today, nil) ~= nil then error("an old price gives no sell or hold") end
        if H(nil, 50, 1, false, today, today - 1) ~= "vendor" then error("nobody lists it: uncommon or lower") end
        if H(nil, 50, 3, false, today, today - 1) ~= nil then error("a rare nobody lists is never vendor it") end
        if H(nil, 50, 1, false, today, today - 5) ~= nil then error("an old scan says nothing about who lists it") end
        if H(nil, 50, 1, false, today, nil) ~= nil then error("never scanned: nothing about who lists it") end
        if H(E(1200, nil, { listed = 0 }), 50, 2, false, today, today) ~= "vendor" then error("listed 0, uncommon: vendor it") end
        if H(E(1200, nil, { listed = 0, seenDay = today }), 50, 2, false, today, today) ~= "sell" then error("seen listed since the scan: not nobody lists it") end
        if H(E(1200), 50, 2, true, today, today) ~= nil then error("bound: no hint") end
        if H(nil, 0, 1, false, today, today) ~= nil then error("no vendor price, never seen: no hint") end
        if H({ price = 1200, day = today, hist = { [1] = 1000, [2] = 1000 } }, 0, 2, false, today, nil) ~= nil then error("two days of history are not enough") end
        if H({ day = today, listed = 2 }, 50, 1, false, today, today) ~= nil then error("bid only, listed: no hint") end
        -- the tooltip lines (prices first, then the hint), bound items, and the bag window
        local oldRealm, oldFaction, keepPrices, realGII, keepTip = env.GetRealmName, env.UnitFactionGroup, ns.root.prices, ns.GetItemInfo, env.GameTooltip
        local realFor, keepOn, keepMem, keepShould = ns.SellHintFor, ns.db.sellHints, ns.db.auctionMemory, ns.ShouldSell
        local I = env.C_Item
        local keepLoc, keepBound, keepSoul = rawget(I, "GetItemLocation"), rawget(I, "IsBound"), rawget(env, "ITEM_SOULBOUND")
        local C = env.C_Container
        local keepSlots, keepInfo = C.GetContainerNumSlots, C.GetContainerItemInfo
        local keepSeenT = ns.root.auctionSeen
        ns.root.auctionSeen = nil
        local keepDate, keepTime = env.date, env.time
        local okT, errT = pcall(function()
            HouseAs("Stormreach", "Alliance")
            -- "nobody lists it" is as fresh as the last full scan, not the last scan
            env.date, env.time = function(f, t) return os.date(f, t) end, function() return os.time() end
            ns.root.prices = { v = 1, houses = { ["Stormreach|Alliance"] = { items = {}, scanAt = os.time(), listedAt = os.time() - 2 * 86400 } } }
            local realGII0 = ns.GetItemInfo
            ns.GetItemInfo = function(self, id) if id == 4244 then return "Cloth", "|Hitem:4244|h[Cloth]|h", 1, 10, 1, "Trade Goods", "", 20, "", 1, 50, 7, 0, 0 end return realGII0(self, id) end
            local text, fresh = ns.SellHintLine(4244)
            ns.GetItemInfo = realGII0
            env.date, env.time = keepDate, keepTime
            if text ~= ns:Tr("Vendor it: nobody lists it here") or fresh ~= string.format(ns:Tr("Scanned %d days ago"), 2) then error("nobody lists it, and how fresh: " .. tostring(text) .. " | " .. tostring(fresh)) end
            ns.root.prices = { v = 1, houses = { ["Stormreach|Alliance"] = { items = { [4242] = { price = 1200, day = ns.Today(), hist = hist, listed = 3, listedDay = ns.Today() },
                [4243] = { price = 1200, day = ns.Today(), hist = hist } }, scanAt = env.time() } } }
            ns.GetItemInfo = function(self, id)
                if id == 4242 then return "Thing", "|Hitem:4242|h[Thing]|h", 2, 10, 1, "Trade Goods", "", 20, "", 1, 50, 7, 0, 0 end
                if id == 4243 then return "Heirloom", "|Hitem:4243|h[Heirloom]|h", 2, 10, 1, "Armor", "", 1, "", 1, 50, 4, 0, 7 end
                return realGII(self, id)
            end
            local lines = {}
            local tip = setmetatable({ AddDoubleLine = function(_, l, r) lines[#lines + 1] = { l, r } end }, { __index = function() return function() end end })
            env.GameTooltip = tip
            local sell = string.format(ns:Tr("Sell now: %d%% above its usual price"), 20)
            ns.db.auctionMemory, ns.db.sellHints = true, true
            ns.sellHintsTest.Tip(tip, { id = 4242 })
            if #lines ~= 3 or not tostring(lines[1][1]):find(ns:Tr("Auction house"), 1, true) or not tostring(lines[2][1]):find(string.format(ns:Tr("Usual price (%d days)"), 5), 1, true)
                or lines[3][1] ~= sell or lines[3][2] ~= ns:Tr("Scanned today") then error("the tooltip: the prices, then the hint: " .. tostring(lines[3] and lines[3][1])) end
            lines = {}
            ns.db.auctionMemory = false
            ns.sellHintsTest.Tip(tip, { id = 4242 })
            if #lines ~= 1 or lines[1][1] ~= sell then error("prices off: the hint alone") end
            lines = {}
            ns.db.auctionMemory, ns.db.sellHints = true, false
            ns.sellHintsTest.Tip(tip, { id = 4242 })
            if #lines ~= 2 then error("hints off: the prices alone") end
            ns.db.sellHints = true
            -- a bound item: from its place in the bags, or from the game's Soulbound line
            rawset(I, "GetItemLocation", function(guid) if guid == "G1" then return { guid = guid } end end)
            rawset(I, "IsBound", function(loc) return loc.guid == "G1" end)
            lines = {}
            ns.db.auctionMemory = false
            ns.sellHintsTest.Tip(tip, { id = 4242, guid = "G1" })
            if #lines ~= 0 then error("a soulbound item (from its bag place) gets no hint") end
            rawset(I, "GetItemLocation", nil)
            rawset(env, "ITEM_SOULBOUND", "Soulbound")
            ns.sellHintsTest.Tip(tip, { id = 4242, lines = { { leftText = "Thing" }, { leftText = "Soulbound" } } })
            if #lines ~= 0 then error("a soulbound item (from its tooltip line) gets no hint") end
            ns.sellHintsTest.Tip(tip, { id = 4242, lines = { { leftText = setmetatable({ __secret = true }, secretmt) } } })
            if #lines ~= 1 then error("an unbound item still gets its hint") end
            if ns.SellHintFor(4243) ~= nil then error("bound to the account (bind type 7): no hint") end
            ns.root.prices.houses["Stormreach|Alliance"].items[4242].listedDay = nil
            lines = {}
            ns.sellHintsTest.Tip(tip, { id = 4242 })
            if not lines[1] or lines[1][2] ~= ns:Tr("today") then error("browsed only: when it was seen") end
            ns.sellHintsTest.Tip(tip, { id = setmetatable({ __secret = true }, secretmt) })
            HouseAs("Stormreach", nil)
            lines = {}
            ns.sellHintsTest.Tip(tip, { id = 4242 })
            if #lines ~= 0 then error("no house: no hint") end
            -- the bag window draws the square: green for Sell now; hidden when off, and under the junk coin
            local bag = ns.bagTest and ns.bagTest.FantasyGlassUIBags
            if not bag then error("no bag window to test") end
            local first
            C.GetContainerNumSlots = function(id) if first == nil then first = id end; return id == first and 2 or 0 end
            C.GetContainerItemInfo = function(_, slot) return { iconFileID = 1, stackCount = 1, quality = 1, itemID = 100 + slot, hyperlink = "item:" .. slot } end
            ns.SellHintFor = function(id) if id == 101 then return "sell", 20 end end
            ns.ShouldSell = function() return false end
            local function each(fn) for _, list in pairs(bag.slots()) do for _, b in pairs(list) do fn(b) end end end
            local okL, eL = pcall(bag.Layout)
            if not okL then error("the bag window could not be arranged: " .. tostring(eL)) end
            local marks = {}
            each(function(b)
                local sq = rawget(b, "sellHint")
                if sq then
                    local m = { shown = false }
                    marks[b] = m
                    rawset(sq, "SetColorTexture", function(_, r, g, bl) m.color = { r, g, bl } end)
                    rawset(sq, "Show", function() m.shown = true end)
                    rawset(sq, "Hide", function() m.shown = false end)
                end
            end)
            local function Seen()
                local shown, color = 0, nil
                for _, m in pairs(marks) do if m.shown then shown = shown + 1; color = m.color end end
                return shown, color
            end
            bag.Layout()
            local shown, color = Seen()
            if shown ~= 1 or not color or color[1] ~= 0.30 or color[2] ~= 0.85 or color[3] ~= 0.40 then error("the bag square: one green square, got " .. shown) end
            ns.db.sellHints = false
            bag.Layout()
            if Seen() ~= 0 then error("the bag square with the hints off") end
            ns.db.sellHints = true
            local keepJunk = ns.db.bagJunkIcon
            ns.db.bagJunkIcon = true
            ns.ShouldSell = function() return true end
            bag.Layout()
            ns.db.bagJunkIcon = keepJunk
            if Seen() ~= 0 then error("the bag square under the junk coin") end
        end)
        env.GetRealmName, env.UnitFactionGroup, ns.root.prices, ns.GetItemInfo, env.GameTooltip = oldRealm, oldFaction, keepPrices, realGII, keepTip
        ns.root.auctionSeen, env.date, env.time = keepSeenT, keepDate, keepTime
        ns.SellHintFor, ns.db.sellHints, ns.db.auctionMemory, ns.ShouldSell = realFor, keepOn, keepMem, keepShould
        rawset(I, "GetItemLocation", keepLoc); rawset(I, "IsBound", keepBound); rawset(env, "ITEM_SOULBOUND", keepSoul)
        C.GetContainerNumSlots, C.GetContainerItemInfo = keepSlots, keepInfo
        ns.PriceHouseKeyReset()
        if not okT then error(errT, 0) end
        ns:RefreshBagWindow()
    end
    -- home key
    local ways = { { kind = "spell", id = 3561 }, { kind = "spell", id = 556 }, { kind = "item", id = 6948 }, { kind = "item", id = 64488 } }
    local best, ready = ns.BestWayHome(ways, function() return true end)
    if best.id ~= 6948 or not ready then error("the hearthstone first") end
    best = ns.BestWayHome(ways, function(w) return w.id ~= 6948 and w.id ~= 64488 end)
    if best.id ~= 556 then error("then Astral Recall") end
    best, ready = ns.BestWayHome(ways, function() return false end)
    if best.id ~= 6948 or ready then error("nothing ready: the hearthstone anyway") end
    if ns.BestWayHome({}) ~= nil then error("no way home") end
    if ns.homeKeyTest then ns.homeKeyTest.Assign() end
    ns:HomeCommand()
    -- coming from another UI
    local found = ns.OtherUIsFound(function(name) return name == "ElvUI" end)
    if #found ~= 1 or found[1].ui.gallery ~= "minimal" then error("ElvUI players get the minimal setup") end
    for _, ui in ipairs(ns.OTHER_UIS) do
        local ok = false
        for _, g in ipairs(ns.GALLERY) do if g.key == ui.gallery then ok = true end end
        if not ok then error("each points at a gallery setup: " .. ui.key) end
    end
    -- what each feature costs, and the fight report
    local rows = ns.CostRows({ a = { ms = 1, kb = 5 }, b = { ms = 3, kb = -2 } })
    if rows[1].key ~= "b" or #rows ~= 2 then error("heaviest first") end
    if ns:ShowLoadCost() < 1 then error("the costs window: modules were measured") end
    local text = ns.PerfReportText({ { label = "Raid frames", perSec = 0.5, calls = 10, worst = 1.2 } }, 61, { what = "a fight", group = 20, fps = 60, fpsLow = 40, fpsHigh = 80, mem = 10240 })
    if not text:find("group of 20") or not text:find("Raid frames") or not text:find("10.0 MB") then error("the report text") end
end)
try("11.11: celestial themes (in place of runic) and language names", function()
    local keepTheme, keepAccent = ns.db.theme, ns.db.accent
    for _, key in ipairs({ "C_POLARIS", "CCLASS" }) do
        ns.db.theme = key; ns.db.accent = ns.themes[key].accent
        ns:Retheme()
        if ns.style ~= "CELESTIAL" then error(key .. " is a celestial theme") end
        local f = env.CreateFrame("Frame", nil, env.UIParent, ns.template)
        f:SetSize(300, 200)
        ns:Dress(f)
        if not rawget(f, "suiGrain") then error("a celestial panel has its stars") end
        local p = env.CreateFrame("Frame", nil, env.UIParent, ns.template)
        ns:Dress(p, true)
        ns:Corners(f, f, 16, 1)
        ns:Divider(f)
        ns:CreateButton(f, "Celestial", 80, 22, function() end)
    end
    local own = ns.themes[ns:SaveCustomTheme("Sky test", { panel = { 0.03, 0.03, 0.07 }, rim = { 0.4, 0.4, 0.45 }, accent = { 0.5, 0.8, 1 }, style = "CELESTIAL" })]
    if own.style ~= "CELESTIAL" then error("a celestial theme of your own") end
    ns:DeleteCustomTheme("Sky test")
    -- Runic is gone: a theme of your own saved as Runic becomes Celestial, and so do the Runic themes
    if ns:CleanThemeDef({ style = "RUNIC" }).style ~= "CELESTIAL" then error("an old Runic theme of your own becomes Celestial") end
    local old = ns:FillDefaults({ design = 4, theme = "R_GRANITE", placeThemes = { raid = "R_EMBER", city = "SMOKE" }, customThemes = { Mine = { style = "RUNIC" } } })
    if old.theme ~= "C_POLARIS" or old.placeThemes.raid ~= "C_COMET" or old.placeThemes.city ~= "SMOKE" or old.customThemes.Mine.style ~= "CELESTIAL" then
        error("a Runic player moves to the Celestial theme made from theirs: " .. tostring(old.theme) .. ", " .. tostring(old.placeThemes.raid))
    end
    -- the sun and the moon: by day the sun, along the top from the left at 6:00; at night the moon; noon at the top of the ring
    local day, along, angle = ns.SkyBody(6)
    if not day or math.abs(along) > 0.001 then error("6:00: the sun at the left of the top edge") end
    day, along, angle = ns.SkyBody(12)
    if not day or math.abs(along - 0.5) > 0.001 or math.abs(angle) > 0.001 then error("noon: the sun in the middle, at the top of the ring") end
    day, along, angle = ns.SkyBody(0)
    if day or math.abs(along - 0.5) > 0.001 or math.abs(angle + math.pi) > 0.001 then error("midnight: the moon, at the foot of the ring") end
    if ns.SkyBody(18) then error("18:00 is night") end
    -- a Celestial window: a constellation on a large one, none on a small one
    ns.db.theme = "C_POLARIS"; ns:Retheme()
    local seenTex = {}
    local big = env.CreateFrame("Frame", nil, env.UIParent, ns.template)
    big:SetSize(420, 300)
    ns:Dress(big)
    local small = env.CreateFrame("Frame", nil, env.UIParent, ns.template)
    small:SetSize(120, 30)
    ns:Dress(small)
    if not rawget(big, "suiGrain") or not rawget(small, "suiGrain") then error("both have their stars") end
    -- it moves: loops are made and playing, a shooting star can cross the large window, Reduce motion holds still
    if #ns.skyLoops < 5 then error("the celestial windows' loops: " .. #ns.skyLoops) end
    if not ns.ShootingStar(big) or not rawget(big, "suiShooting") then error("a shooting star across a large window") end
    if #(rawget(big, "suiMotes") or {}) ~= 6 then error("motes of starlight on a large window") end
    -- nothing that is a SetGradient fade is animated (some game clients then draw it white: the white band of 11.11's first build)
    local fade = env.CreateFrame("Frame", nil, env.UIParent):CreateTexture()
    fade.suiGradient = true
    if ns:SkyLoop(fade, "Alpha", 1, function(x) x:SetFromAlpha(0); x:SetToAlpha(1) end) then error("an animation on a gradient fade") end
    local keepMotion = ns.db.reduceMotion
    ns.db.reduceMotion = true
    if ns:Motion() then error("reduce motion") end
    ns.db.reduceMotion = keepMotion
    for rk, ck in pairs(ns.RUNIC_TO_CELESTIAL) do
        if not ns.themes[ck] then error("no Celestial theme for " .. rk .. ": " .. ck) end
        if rk ~= "RCLASS" and ns.themes[ck].style ~= "CELESTIAL" then error(ck .. " is not Celestial") end
    end
    ns.db.theme, ns.db.accent = keepTheme, keepAccent; ns:Retheme()
    -- Korean and Chinese names in a face that has their letters
    local fs = env.UIParent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 12)
    local family = newmock(); env.GameFontHighlight = family
    local usedFamily
    rawset(fs, "SetFontObject", function(_, obj) usedFamily = obj end)
    ns:LanguageFont(fs, "koKR")
    if usedFamily ~= family or not rawget(fs, "suiFamily") then error("Korean uses the game's font family") end
    local setTo
    rawset(fs, "SetFont", function(_, path) setTo = path end)
    ns:Font(fs, 12)
    if setTo ~= nil then error("the family is not overwritten by the add-on's lettering") end
    ns:LanguageFont(fs, "deDE")
    if rawget(fs, "suiFamily") or setTo == nil then error("German goes back to the add-on's lettering") end
    rawset(fs, "SetFontObject", function() error("no font families on this client") end)
    ns:LanguageFont(fs, "zhCN")
    if setTo ~= "Fonts\\ARKai_T.ttf" then error("without font families, the Chinese face by name: " .. tostring(setTo)) end
end)
try("11.9: check of the new features, celestial art, theme previews", function()
    local out, counts = ns:CheckNew()
    if type(out) ~= "table" or #out < 25 then error("the report") end
    if counts.CHECK > 0 then
        local bad = {}
        for _, l in ipairs(out) do if l:find("^  CHECK") then bad[#bad + 1] = l end end
        error("lines to look at in the harness: " .. table.concat(bad, " | "))
    end
    -- celestial art
    local keepStyle = ns.style
    ns.style = "CELESTIAL"
    local host = env.CreateFrame("Frame", nil, env.UIParent)
    local btn = env.CreateFrame("Button", nil, env.UIParent)
    ns:AddBorder(btn, 0, 0, 0, 1)
    if not ns:CelestialButtonEdge(btn) or ns:CelestialButtonEdge(btn) then error("a fine star frame, once") end
    local m = ns:CreateEmblem(host)
    local tex
    rawset(m.ring, "SetTexture", function(_, p) tex = p end)
    m:Restyle()
    if not tostring(tex):find("ring_celestial") then error("the celestial emblem ring: " .. tostring(tex)) end
    local div = ns:Divider(host)
    if not rawget(div, "suiStar") then error("a star on the celestial divider") end
    ns.style = "GLASS"
    if ns:CelestialButtonEdge(env.CreateFrame("Button", nil, env.UIParent)) then error("no star frame on glass") end
    ns.style = keepStyle
    -- theme previews
    for _, key in ipairs({ "SMOKE", "CLASS", "GCLASS", "CCLASS", "C_POLARIS" }) do
        local c = ns:ThemeColors(key)
        if not c or not c.bg or not c.accent or not c.border then error("colors of " .. key) end
    end
    if ns:ThemeColors("NOPE") then error("no such theme") end
    if ns:ThemeColors("CCLASS").style ~= "CELESTIAL" or ns:ThemeColors("GCLASS").style ~= "GLASS" then error("family of the class themes") end
    local page = ns.lookPage
    if not (page and page.themePicker and page.ShowSwatch) then error("the Look page") end
    local pk = page.themePicker
    pk.family = "CELESTIAL"; pk.Draw()
    local b = pk.tiles[1]
    if not b or not b.swatch then error("each theme tile has its picture") end
    pk.Pick("C_POLARIS")
    page.ShowSwatch(b.swatch, "CCLASS")
end)
try("Chat bubbles: the look sleeps until someone speaks", function()
    if type(ns.BubblePoll) ~= "function" then error("no bubble poll") end
    local realTime, realGet = env.GetTime, known.C_ChatBubbles.GetAllChatBubbles
    local asked = 0
    known.C_ChatBubbles.GetAllChatBubbles = function() asked = asked + 1; return {} end
    env.GetTime = function() return 5000 end
    ns.BubblePoll()
    if asked ~= 0 then error("looked for bubbles with nobody talking") end
    fireEvent("CHAT_MSG_SAY", "hi", "Bob-Realm")
    ns.BubblePoll()
    if asked ~= 1 then error("did not look after a line was heard: " .. asked) end
    env.GetTime = function() return 5020 end
    ns.BubblePoll()
    if asked ~= 1 then error("still looking 20 seconds after the last line") end
    env.GetTime, known.C_ChatBubbles.GetAllChatBubbles = realTime, realGet
end)
try("Class resource: a new design table is read at once", function()
    if not ns.resourceTest then return end
    local f = ns.resourceTest.frame
    local w
    rawset(f, "SetSize", function(_, a) w = a end)
    ns.db.resourceDesign = { width = 250 }
    ns.resourceTest.Update()
    ns.db.resourceDesign = nil
    if w ~= 250 then error("the resource bar kept its old width: " .. tostring(w)) end
    rawset(f, "SetSize", nil)
    ns.resourceTest.Update()
end)
try("Lists: a list with no new rows is not walked again", function()
    if type(ns.StyleList) ~= "function" then error("no list styler") end
    local list, walks, count = newmock(), 0, 3
    local rows = { newmock(), newmock(), newmock(), newmock() }
    rawset(list, "IsVisible", function() return true end)
    rawset(list, "GetNumChildren", function() return count end)
    rawset(list, "GetChildren", function() walks = walks + 1; return table.unpack(rows, 1, count) end)
    ns.StyleList(list); ns.StyleList(list)
    if walks ~= 1 then error("walked an unchanged list again: " .. walks) end
    count = 4
    ns.StyleList(list)
    if walks ~= 2 then error("a new row was not styled") end
    if not rawget(rows[4], "suiRow") then error("the new row has no style") end
end)
try("Starcut frames: the style, switching to Classic and back", function()
    if type(ns.StarcutOn) ~= "function" then error("no frame style") end
    local P, T
    for _, f in ipairs(ns.unitFrameList or {}) do
        if f.designKey == "Player" then P = f elseif f.designKey == "Target" then T = f end
    end
    if not (P and T) then error("no player or target frame") end
    local keep = ns.db.ufStyle
    ns.db.ufStyle = nil
    if not ns.StarcutOn() then error("Starcut is the style a new install starts with") end
    ns:RefreshUnitFrames()
    if not rawget(P, "scLaidOut") or not rawget(P.health, "sc") or not rawget(P, "scParts") or not rawget(P.scParts, "line") then error("the player frame was not laid out as Starcut") end
    if not rawget(P.health.bg, "scMasked") then error("the health bar is not cut to points") end
    if not rawget(P, "scNameMax") then error("the player's name is not set above the bars") end
    if rawget(T.scParts, "line") == nil or rawget(T.scParts, "endStar") == nil then error("the target has no line and end star") end
    -- the target is mirrored: its bars fill from the right, its health text sits at the left
    local rev
    rawset(T.health, "SetReverseFill", function(_, v) rev = v end)
    local pctAt
    rawset(T.pct, "SetPoint", function(_, point) pctAt = pctAt or point end)
    ns.db.ufStyle = "CLASSIC"; ns:RefreshUnitFrames()
    if rev ~= false then error("Classic: the target fills from the left again") end
    if rawget(T, "scLaidOut") then error("Classic: the target is still laid out as Starcut") end
    if rawget(P.health.bg, "scMasked") then error("Classic: the health bar is still cut") end
    pctAt = nil
    ns.db.ufStyle = "STARCUT"; ns:RefreshUnitFrames()
    if rev ~= true then error("Starcut: the target fills from the right") end
    if pctAt ~= "LEFT" then error("Starcut: the target's health text sits at its left, not " .. tostring(pctAt)) end
    rawset(T.health, "SetReverseFill", nil); rawset(T.pct, "SetPoint", nil)
    -- combat on the outer point
    local state = rawget(P.scParts, "state")
    if not state then error("the player frame has no combat / resting sign") end
    local shown
    rawset(state, "Show", function() shown = true end)
    rawset(state, "Hide", function() shown = false end)
    local realCombat = env.UnitAffectingCombat
    env.UnitAffectingCombat = function() return true end
    for i = 1, #handlers do local h = handlers[i]; if h.self == P and h.name == "OnEvent" then h.fn(P, "PLAYER_REGEN_DISABLED") end end
    env.UnitAffectingCombat = realCombat
    rawset(state, "Show", nil); rawset(state, "Hide", nil)
    if shown ~= true then error("in combat: the swords on the outer point") end
    -- auras below the frame by default, above when chosen (and then above the name)
    local row = T.auras
    ns.db.auraDesign = ns.db.auraDesign or {}
    local keepAura = ns.db.auraDesign.target
    ns.db.auraDesign.target = nil
    local sides = {}
    rawset(row, "SetPoint", function(_, point, _, _, _, y) sides[#sides + 1] = { point, y } end)
    ns:ApplyAuraDesign()
    if not sides[1] or sides[1][1] ~= "TOPLEFT" then error("Starcut: the target's auras sit below it") end
    ns.db.auraDesign = ns.db.auraDesign or {}
    ns.db.auraDesign.target = { side = "above" }
    sides = {}
    ns:ApplyAuraDesign()
    if not sides[1] or sides[1][1] ~= "BOTTOMLEFT" or (tonumber(sides[1][2]) or 0) < 20 then error("auras chosen above sit above the name") end
    ns.db.auraDesign.target = keepAura
    rawset(row, "SetPoint", nil)
    ns:ApplyAuraDesign()
    ns.db.ufStyle = keep
    ns:RefreshUnitFrames()
end)
try("Look tab: the frame style buttons", function()
    local page = ns.lookPage
    local bs = page and rawget(page, "frameStyleButtons")
    if not bs or not bs.CLASSIC or not bs.STARCUT then error("no Starcut / Classic buttons on the Look tab") end
    local function click(b) for i = 1, #handlers do local h = handlers[i]; if h.self == b and h.name == "OnClick" then h.fn(b, "LeftButton") end end end
    local keep = ns.db.ufStyle
    click(bs.CLASSIC)
    if ns.db.ufStyle ~= "CLASSIC" or ns.StarcutOn() then error("Classic was not chosen") end
    click(bs.STARCUT)
    if ns.db.ufStyle ~= "STARCUT" or not ns.StarcutOn() then error("Starcut was not chosen") end
    ns.db.ufStyle = keep
end)
try("Starcut reaches every bar: cut, back to the box, and after a fight", function()
    if type(ns.StarcutStyleBar) ~= "function" or type(ns.ApplyFrameStyle) ~= "function" then error("no shared frame style") end
    local keep = ns.db.ufStyle
    ns.db.ufStyle = "STARCUT"
    -- any bar made with NewStatusBar
    local bar = ns:NewStatusBar(UIParent, true)
    local styled
    bar.scOnStyle = function(_, on) styled = on end
    local borderShown
    rawset(bar.suiBorder, "SetShown", function(_, v) borderShown = v end)
    ns:StarcutStyleBar(bar, true)
    if not rawget(bar.bg, "scMasked") or styled ~= true or borderShown ~= false then error("a bar is not cut under Starcut") end
    ns.db.ufStyle = "CLASSIC"; ns:ApplyFrameStyle()
    if rawget(bar.bg, "scMasked") or styled ~= false or borderShown ~= true then error("Classic: a bar is not back in its box") end
    -- asked for during a fight: it waits for the fight to end
    local realLock = env.InCombatLockdown
    env.InCombatLockdown = function() return true end
    ns.db.ufStyle = "STARCUT"; ns:ApplyFrameStyle()
    env.InCombatLockdown = realLock
    if rawget(bar.bg, "scMasked") then error("the style changed during a fight") end
    ns:RunFrameStyleHooks()
    if not rawget(bar.bg, "scMasked") then error("the style did not change once the fight was over") end
    -- a raid cell
    local cell = newmock()
    ns.RaidStyle(cell)
    if not rawget(rawget(cell, "health"), "sc") then error("a raid cell's health bar is not cut") end
    local bgShown
    rawset(cell.bg, "SetShown", function(_, v) bgShown = v end)
    ns.db.ufStyle = "CLASSIC"; ns:ApplyFrameStyle()
    if bgShown ~= true then error("Classic: the raid cell's box is not back") end
    ns.db.ufStyle = "STARCUT"; ns:ApplyFrameStyle()
    if bgShown ~= false then error("Starcut: the raid cell's box is still there") end
    -- the class resource's dots are diamonds
    local rt = ns.resourceTest
    if rt and rt.frame and rt.frame.dots then
        for _, d in ipairs(rt.frame.dots) do
            if rawget(d, "scMaskFile") ~= "diamond" then error("a resource dot is not a diamond") end
        end
    end
    -- totem slots are diamonds
    local tt = ns.totemTest
    if tt and tt.icons and tt.icons[1] and not rawget(tt.icons[1], "scMask") then error("a totem slot is not a diamond") end
    ns.db.ufStyle = keep; ns:ApplyFrameStyle()
end)
try("Screenshot mode: samples on, the frames handed back, and a fight ends it", function()
    if type(ns.ToggleShowcase) ~= "function" then error("no screenshot mode") end
    local T, A
    for _, f in ipairs(ns.unitFrameList or {}) do
        if f.realUnit == "target" then T = f elseif f.realUnit == "arena1" then A = f end
    end
    if not T then error("no target frame") end
    local said
    rawset(T.name, "SetText", function(_, v) said = v end)
    local hidden
    if A then rawset(A, "Hide", function() hidden = true end) end
    ns:ToggleShowcase(true)
    if not ns.showcasing or rawget(T, "showcase") ~= true then error("screenshot mode did not start") end
    if said ~= "Onyxia" then error("the target does not show the sample boss: " .. tostring(said)) end
    if A and not hidden then error("the arena frames were not put away") end
    ns:ToggleShowcase(false)
    if ns.showcasing or rawget(T, "showcase") == true then error("the target was not handed back") end
    if ns.previewing then error("the preview is still on") end
    ns:ToggleShowcase(true)
    fireEvent("PLAYER_REGEN_DISABLED")
    if ns.showcasing or rawget(T, "showcase") == true then error("a fight did not end screenshot mode") end
    rawset(T.name, "SetText", nil); if A then rawset(A, "Hide", nil) end
end)
try("Loot browser: a kill, its drops from three places, and the browser", function()
    if type(ns.ShowDrops) ~= "function" or not ns.lootBookTest then error("no loot browser") end
    local realInst, realNum, realLink, realRoll = env.GetInstanceInfo, env.GetNumLootItems, env.GetLootSlotLink, env.GetLootRollItemLink
    env.GetInstanceInfo = function() return "Onyxia's Lair", "raid" end
    env.GetNumLootItems = function() return 2 end
    local A = "|cffa335ee|Hitem:17078::::::::60:::::|h[Sapphiron Drape]|h|r"
    local B = "|cffa335ee|Hitem:17068::::::::60:::::|h[Deathbringer]|h|r"
    local C = "|cff0070dd|Hitem:18205::::::::60:::::|h[Eskhandar's Collar]|h|r"
    env.GetLootSlotLink = function(slot) return slot == 1 and A or B end
    env.GetLootRollItemLink = function() return C end
    fireEvent("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    fireEvent("LOOT_OPENED")
    fireEvent("START_LOOT_ROLL", 7)
    fireEvent("CHAT_MSG_LOOT", "Brannoc receives loot: " .. A .. ".")      -- (the same drape again: once per kill)
    -- (the harness loads the add-on twice, so each kill may be heard twice: compare counts with each other)
    local rec = ns.root.lootBook["Onyxia's Lair"] and ns.root.lootBook["Onyxia's Lair"]["Onyxia"]
    if not rec or (rec.kills or 0) < 1 then error("the kill was not noted") end
    if not rec.items[17078] or rec.items[17078].n ~= rec.kills then error("the drape was not noted once per kill") end
    if not rec.items[17068] or not rec.items[18205] then error("the other drops were not noted") end
    local kills = rec.kills
    -- a wipe is not a kill
    fireEvent("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 0)
    if rec.kills ~= kills then error("a wipe counted as a kill") end
    -- the browser: raids, bosses, loot
    local lines = ns.LootBookLines({ level = 0 })
    local found
    for _, l in ipairs(lines) do if l.left == "Onyxia's Lair" then found = true end end
    if not found then error("the raid is not listed") end
    lines = ns.LootBookLines({ level = 2, instance = "Onyxia's Lair", boss = "Onyxia" })
    local items = 0
    for _, l in ipairs(lines) do if l.link then items = items + 1 end end
    if items ~= 3 then error("the boss shows " .. items .. " items, not 3") end
    if ns:ShowDrops("onyx") < 2 then error("/fgui drops onyx did not open the raid") end
    env.GetInstanceInfo, env.GetNumLootItems, env.GetLootSlotLink, env.GetLootRollItemLink = realInst, realNum, realLink, realRoll
end)
try("Threat meter: rows from the group, your row's colors, hidden when there is nothing", function()
    local t = ns.threatMeterTest
    if not t then error("no threat meter") end
    if ns.ThreatRowColor(120, true) ~= "bad" or ns.ThreatRowColor(85, true) ~= "warn" or ns.ThreatRowColor(40, false) ~= "@accent" then
        error("row colors wrong") end
    if ns.previewing then ns:TogglePreview(true) end            -- (the preview shows its own sample rows)
    ns.db.threatHidden = nil                                     -- (the run of every command hid it)
    local realThreat = ns.ThreatOnTarget
    ns.ThreatOnTarget = function(_, most)
        if most ~= 5 then error("asked for " .. tostring(most) .. " rows, not 5") end
        return { { unit = "party1", pct = 100 }, { unit = "player", pct = 90 } }
    end
    t.Update()
    local shown = 0
    for _, b in ipairs(t.frame.rows) do if rawget(b, "inUse") == true then shown = shown + 1 end end
    if shown ~= 2 then error(shown .. " rows shown, not 2") end
    ns.ThreatOnTarget = function() return nil end
    t.Update()
    if rawget(t.frame, "inUse") == true then error("still shown with no target") end
    ns.ThreatOnTarget = realThreat
end)
try("Farming: a session's loot, its value an hour, a reload, and the weekly recap", function()
    if type(ns.Farm) ~= "function" then error("no farming") end
    -- values: the auction price when it beats the vendor's
    local seen = { [100] = { price = 5000, hist = { [1] = 5000 } } }
    if ns.FarmItemValue(100, 200, seen) ~= 5000 or ns.FarmItemValue(101, 200, seen) ~= 200 then error("item values wrong") end
    local s = { elapsed = 1800, gold = 10000, items = {} }
    ns.FarmAdd(s, "|cffffffff|Hitem:101::::::::60:::::|h[Linen Cloth]|h|r", 4, 50)
    ns.FarmAdd(s, "|cffffffff|Hitem:101::::::::60:::::|h[Linen Cloth]|h|r", 2, 50)
    if s.items[101].n ~= 6 then error("counts not added up") end
    local t = ns.FarmTotals(s, 0, nil)
    if t.value ~= 300 or math.abs(t.goldHour - 20000) > 1 or math.abs(t.totalHour - 20600) > 1 then error("totals wrong: " .. t.value .. " " .. t.goldHour) end
    -- a real session
    local key = ns:CharKey()
    ns.root.farming[key] = nil
    ns:Farm("")
    local cur = ns.root.farming[key]
    if type(cur) ~= "table" then error("no session started") end
    fireEvent("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2589::::::::60:::::|h[Linen Cloth]|h|rx3.")
    if not cur.items[2589] then error("loot not counted") end
    fireEvent("PLAYER_LOGOUT")
    if cur.resumed ~= nil then error("the clock did not stop at logout") end
    fireEvent("PLAYER_ENTERING_WORLD")
    if not cur.resumed then error("the clock did not start again") end
    ns:Farm("")                                                  -- (the window)
    local done = ns:Farm("stop")
    if type(done) ~= "table" or ns.root.farming[key] ~= nil then error("stop did not end it") end
    local lines = ns.RecapLines({ chars = { [key] = { farm = { secs = 3600, gold = 50000, value = 10000, n = 1 }, played = 0 } } }, {})
    local found
    for _, l in ipairs(lines) do if tostring(l.left):find("Farmed", 1, true) then found = true end end
    if not found then error("the recap has no farming line") end
end)
try("Gear sets: /fgui set by name, the set keys, and the name over the player frame", function()
    if type(ns.SetCommand) ~= "function" or type(ns.FindSet) ~= "function" then error("no set command") end
    local sets = { { name = "Healing" }, { name = "Heroic Tank" }, { name = "PvP" } }
    if ns.FindSet(sets, "heal").name ~= "Healing" or ns.FindSet(sets, "tank").name ~= "Heroic Tank" or ns.FindSet(sets, "pvp").name ~= "PvP" then
        error("names not matched") end
    if ns.FindSet(sets, "dps") ~= nil then error("a set that is not there was matched") end
    local E = env.C_EquipmentSet
    local realE = E
    local used
    env.C_EquipmentSet = {
        GetEquipmentSetIDs = function() return { 7, 9 } end,
        GetEquipmentSetInfo = function(id)
            if id == 7 then return "Healing", 134, 7, true, 16, 16, 0, 0 end
            return "Heroic Tank", 135, 9, false, 16, 4, 0, 0
        end,
        UseEquipmentSet = function(id) used = id; return true end,
    }
    local realLock = env.InCombatLockdown
    env.InCombatLockdown = function() return false end
    local set = ns:SetCommand("tank")
    if not set or used ~= 9 then error("/fgui set tank did not put the tank set on: " .. tostring(used)) end
    used = nil
    env.FantasyGlassUI_Binding("GEARSET1", "down")
    if used ~= nil then error("the key for a set already worn changed gear") end
    env.FantasyGlassUI_Binding("GEARSET2", "down")
    if used ~= 9 then error("the second set's key did not put it on") end
    ns:SetCommand("")                                            -- (the list)
    if ns.setOnFrameTest then
        ns.setOnFrameTest.Update()
        local label = ns.setOnFrameTest.Label()
        if label and rawget(label, "setName") ~= "Healing" then error("the frame does not name the worn set: " .. tostring(rawget(label, "setName"))) end
    end
    env.C_EquipmentSet, env.InCombatLockdown = realE, realLock
end)
try("Starcut 11.14: buttons and bag slots cut like gems, a diamond minimap", function()
    if type(ns.StarcutFacet) ~= "function" then error("no facet style") end
    local realStyle = ns.db.ufStyle
    local b = env.CreateFrame("Button")
    local icon, cd = b:CreateTexture(), newmock()
    ns.db.ufStyle = "STARCUT"
    ns:StarcutFacet(b, { icon = icon, cooldown = cd })
    if rawget(b, "scFacetOn") ~= true or not rawget(b, "scFacet") then error("the button was not cut") end
    ns.db.ufStyle = "CLASSIC"; ns:ApplyFrameStyle()
    if rawget(b, "scFacetOn") ~= nil then error("Classic did not put the square back") end
    ns.db.ufStyle = realStyle; ns:ApplyFrameStyle()
    if type(ns.ApplyMinimapShape) == "function" then
        ns.db.minimapDiamond = true
        if ns:ApplyMinimapShape() ~= "DIAMOND" then error("the minimap did not turn diamond") end
        ns.db.minimapDiamond = nil
        if ns:ApplyMinimapShape() == "DIAMOND" then error("the diamond minimap stuck") end
    end
end)
try("Nameplates 11.14: threat on the edge, and the target's accent first", function()
    if type(ns.PlateEdge) ~= "function" then return end
    local bar = { suiBorder = newmock(), sc = { edge = newmock() } }
    ns.PlateEdge(bar, nil, false)
    if bar.scEdgeShown ~= "plain" then error("a plain plate's edge: " .. tostring(bar.scEdgeShown)) end
    bar.scThreat = { 1, 0.5, 0 }
    ns.PlateEdge(bar, nil, false)
    if bar.scEdgeShown ~= "threat" then error("the threat color is not on the edge") end
    ns.PlateEdge(bar, nil, true)
    if bar.scEdgeShown ~= "target" then error("your target's accent should come first") end
end)
try("Farming by zone: time, gold and loot zone by zone, and the best spots", function()
    if type(ns.FarmZonesSave) ~= "function" then error("no zones") end
    local s = {}
    ns.FarmZoneSwitch(s, "Elwynn Forest", 0)
    ns.FarmZoneGold(s, 50000)
    ns.FarmZoneItem(s, 101, 4, 50)
    ns.FarmZoneSwitch(s, "Westfall", 1800)
    ns.FarmZoneGold(s, 10000)
    ns.FarmZoneSwitch(s, "Stormwind City", 3600)                -- (passing through: under a minute)
    local hist = {}
    local n = ns.FarmZonesSave(s, hist, 3630)
    if n ~= 2 or not hist["Elwynn Forest"] or hist["Stormwind City"] then error("zones saved: " .. tostring(n)) end
    if hist["Elwynn Forest"][1].secs ~= 1800 or hist["Elwynn Forest"][1].value ~= 200 then error("Elwynn's share is wrong") end
    local rank = ns.FarmZoneRanking(hist)
    if rank[1].zone ~= "Elwynn Forest" or math.abs(rank[1].perHour - 100400) > 1 then error("best spot wrong: " .. tostring(rank[1].zone) .. " " .. tostring(rank[1].perHour)) end
    hist["Elwynn Forest"][2] = { secs = 1800, gold = 100000, value = 0 }
    rank = ns.FarmZoneRanking(hist)
    if not rank[1].before or rank[1].last <= rank[1].before then error("the latest time there should be up on the ones before") end
    ns:FarmZones()
end)
try("Run log: kills, wipes, deaths, loot and the best time", function()
    if type(ns.RunNew) ~= "function" then error("no run log") end
    local log = {}
    local a = ns.RunNew("Deadmines", "Normal", 1000, "Me - Realm")
    ns.RunEncounter(a, "Rhahk'Zor", true, 1300)
    ns.RunEncounter(a, "Sneed", false, 1500)
    ns.RunEncounter(a, "Sneed", true, 1700)
    a.deaths = 1
    ns.RunLoot(a, "|cff0070dd|Hitem:5187::::::::20:::::|h[Rhahk'Zor's Hammer]|h|r", 3)
    if not ns.RunFinish(log, a) then error("a run with kills was not kept") end
    local b = ns.RunNew("Deadmines", "Normal", 5000, "Me - Realm")
    ns.RunEncounter(b, "Rhahk'Zor", true, 5200)
    ns.RunEncounter(b, "Sneed", true, 5500)
    ns.RunFinish(log, b)
    if ns.RunFinish(log, ns.RunNew("Deadmines", nil, 9000)) then error("an empty run was kept") end
    local places = ns.RunPlaces(log)
    if #places ~= 1 or places[1].runs ~= 2 or places[1].best ~= b or ns.RunLength(b) ~= 500 then error("best time wrong") end
    if a.wipes["Sneed"] ~= 1 or a.kills["Sneed"] ~= 700 then error("wipes or kill times wrong") end
    local realRoot = ns.root.runs
    ns.root.runs = log
    if #ns.RunLines({ level = 0 }) ~= 1 or #ns.RunLines({ level = 1, instance = "Deadmines" }) ~= 3 then error("run window lines wrong") end
    if #ns.RunLines({ level = 2, run = 1 }) < 5 then error("a run's own lines are missing") end
    ns:ShowRuns()
    ns.root.runs = realRoot
end)
try("Goals 11.14: gold on all characters, a level, a mount, and where a drop drops", function()
    if type(ns.GoalProgress) ~= "function" then error("no goals") end
    local d, t = ns.GoalProgress({ kind = "gold", need = 1000 }, { gold = function() return 5000000 end })
    if math.abs(d - 0.5) > 0.001 or type(t) ~= "string" then error("gold progress: " .. tostring(d)) end
    if ns.GoalProgress({ kind = "level", need = 60 }, { level = function() return 30 end }) ~= 0.5 then error("level progress") end
    if ns.GoalProgress({ kind = "mount", id = 1, name = "x" }, { mount = function() return true end }) ~= 1 then error("mount progress") end
    ns.root.lootBook = ns.root.lootBook or {}
    ns.root.lootBook["Test Keep"] = { ["Test Boss"] = { kills = 4, items = { [424242] = { n = 1, link = "x" } } } }
    local from, seen, kills = ns.GoalDropsFrom(424242)
    if from ~= "Test Boss (Test Keep)" or seen ~= 1 or kills ~= 4 then error("drops from: " .. tostring(from)) end
    ns.root.lootBook["Test Keep"] = nil
    local goals = ns.db.goals
    ns.db.goals = {}
    ns:GoalCommand("gold 10000")
    ns:GoalCommand("level 60")
    if #ns.db.goals ~= 2 or ns.db.goals[1].kind ~= "gold" or ns.db.goals[2].kind ~= "level" then error("goals not added") end
    if ns.goalsTest then ns.goalsTest.Update() end
    ns.db.goals = goals
end)
try("Whose upgrade: answers in, biggest upgrade first", function()
    if type(ns.GroupLootParse) ~= "function" then error("no group loot helper") end
    local k, ids = ns.GroupLootParse("GLQ:100,200")
    if k ~= "ask" or ids[2] ~= 200 then error("ask not read") end
    local k2, id, lv = ns.GroupLootParse("GLU:300:12")
    if k2 ~= "answer" or id ~= 300 or lv ~= 12 then error("answer not read") end
    if ns.GroupLootParse("GCQ") ~= nil then error("another message was read as loot") end
    ns.GroupLootHear(777, "item:777", "Kaelith", 12, 0)
    ns.GroupLootHear(777, nil, "Sylvae", 4, 0)
    local e = ns.GroupLootHear(777, nil, "Brannoc", 0, 0)
    local list, answered = ns.GroupLootWho(e)
    if answered ~= 3 or #list ~= 2 or list[1].name ~= "Kaelith" then error("order wrong") end
    if ns.groupLootTest then
        e.at = env.GetTime()
        if ns.groupLootTest.Draw() < 1 then error("the panel shows nothing") end
    end
    ns.groupLootHeard[777] = nil
end)
try("Nameplates: our own bar stands in for the game's, and takes what the game puts on it", function()
    if type(ns.PlateOwnBar) ~= "function" then return end
    local uf = env.CreateFrame("Frame")
    local bar = env.CreateStatusBar and env.CreateStatusBar() or env.CreateFrame("StatusBar")
    local own = ns.PlateOwnBar(uf, bar)
    if not own or rawget(bar, "suiOwn") ~= own then error("no bar of our own") end
    if ns.PlateOwnBar(uf, bar) ~= own then error("a second bar was made for the same plate") end
    if rawget(bar, "suiKilled") ~= true then error("the game's bar is still in sight") end
    local got
    rawset(own, "SetStatusBarColor", function(_, r) got = r end)
    bar:SetStatusBarColor(0.9, 0.1, 0.1)
    if env.hooksecurefunc and got ~= nil and got ~= 0.9 then error("the color was not passed on") end
end)
try("Loot wishlist: star, call out, where it drops, and the boss's own tooltip", function()
    if type(ns.LootWishToggle) ~= "function" then error("no wishlist") end
    local link = "|cffa335ee|Hitem:424243::::::::60:::::|h[Sapphiron Drape]|h|r"
    ns.root.lootWish = {}
    if ns.LootWishToggle(link) ~= true or not ns.LootWished(424243) then error("not starred") end
    ns.root.lootBook = ns.root.lootBook or {}
    ns.root.lootBook["Test Lair"] = { ["Test Dragon"] = { kills = 3, items = { [424243] = { n = 2, link = link } } } }
    local where = ns.LootWhereFrom(424243)
    if not where[1] or where[1].boss ~= "Test Dragon" or where[1].n ~= 2 then error("where it drops is wrong") end
    local forBoss = ns.LootForBoss("Test Dragon", true)
    if not forBoss[1] or not forBoss[1].wish then error("the boss does not list the wished item") end
    if ns:ShowWishlist() ~= 1 then error("the wishlist window is wrong") end
    if ns.lootBookTest and ns.lootBookTest.CallOut then ns.lootBookTest.CallOut(link, "drop") end
    if ns.lootBookTest and ns.lootBookTest.OnUnit then
        local added = 0
        local tip = { GetUnit = function() return "Test Dragon", "target" end, AddLine = function() added = added + 1 end,
                      AddDoubleLine = function() added = added + 1 end, Show = function() end }
        local realName, realAtt = env.UnitName, env.UnitCanAttack
        env.UnitName = function() return "Test Dragon" end
        env.UnitCanAttack = function() return true end
        ns.lootBookTest.OnUnit(tip)
        env.UnitName, env.UnitCanAttack = realName, realAtt
        if added < 2 then error("the boss tooltip added " .. added .. " lines") end
    end
    if ns.LootWishToggle(link) ~= false then error("not let go") end
    ns.root.lootBook["Test Lair"] = nil
end)
try("Nameplates: quest mobs counted from their objectives", function()
    if type(ns.PlateQuestLeft) ~= "function" then return end
    if ns.PlateQuestLeft({ "Defias Thug", "Level 10", " - Defias Thug slain: 3/8" }) ~= 5 then error("3/8 should leave 5") end
    if ns.PlateQuestLeft({ " - Thugs slain: 8/8" }) ~= 0 then error("a finished objective should leave 0") end
    if ns.PlateQuestLeft({ "Kobold Miner", "Level 4" }) ~= nil then error("a mob with no objective was marked") end
    if ns.PlateQuestLeft({ " - Explore the mine (40%)" }) ~= 1 then error("a percent objective should count") end
end)
try("Starcut windows: corners cut where masks slice, the rim along the cut, put back by Classic", function()
    if type(ns.StarcutWindow) ~= "function" then error("no window cut") end
    local realStyle = ns.db.ufStyle
    ns.db.ufStyle = "STARCUT"
    local f = env.CreateFrame("Frame", nil, env.UIParent)
    f:SetSize(400, 300)
    rawset(f, "CreateMaskTexture", function() local m = newmock(); rawset(m, "SetTextureSliceMargins", function() end); return m end)
    local bg = f:CreateTexture(nil, "BACKGROUND")
    rawset(bg, "GetObjectType", function() return "Texture" end)
    rawset(bg, "GetDrawLayer", function() return "BACKGROUND" end)
    local masked = 0
    rawset(bg, "AddMaskTexture", function() masked = masked + 1 end)
    rawset(f, "GetRegions", function() return bg end)
    local was = ns.StarcutCanSlice()
    ns.StarcutCanSlice(true)
    ns.StarcutWindow(f)
    if rawget(f, "scCut") ~= true or masked ~= 1 then error("the window was not cut (" .. masked .. ")") end
    ns.db.ufStyle = "CLASSIC"; ns:ApplyFrameStyle()
    if rawget(f, "scCut") ~= nil then error("Classic did not put the corners back") end
    ns.StarcutCanSlice(true)
    if was ~= nil then ns.StarcutWindow(env.CreateFrame("Frame")) end     -- (back to what this client says)
    ns.db.ufStyle = realStyle; ns:ApplyFrameStyle()
end)
try("Roll advice: need on a wish or an upgrade, pass on gear you can't use, greed for the rest", function()
    if type(ns.RollAdvice) ~= "function" then error("no roll advice") end
    local link = "|cff0070dd|Hitem:424250::::::::60:::::|h[Test Blade]|h|r"
    ns.root.lootWish = { [424250] = { link = link } }
    local k, why = ns.RollAdvice(link, true)
    if k ~= "need" or type(why) ~= "string" then error("a wished item should be need: " .. tostring(k)) end
    if ns.RollAdvice(link, false) == "need" then error("need was advised where the game does not allow it") end
    ns.root.lootWish = {}
    local realUp = ns.UpgradeAmount
    ns.UpgradeAmount = function() return 12 end
    local k2, why2 = ns.RollAdvice(link, true)
    if k2 ~= "need" or not tostring(why2):find("12") then error("an upgrade should be need +12") end
    ns.UpgradeAmount = function() return nil end
    local k3 = ns.RollAdvice(link, true)
    if k3 ~= "greed" and k3 ~= "pass" then error("the rest should be greed or pass: " .. tostring(k3)) end
    ns.UpgradeAmount = realUp
end)
try("Group gear: levels lowest first, the average, and who is still to come", function()
    if type(ns.GearLines) ~= "function" then error("no gear check") end
    ns.gearKnown["g2"] = { level = 58, at = 100 }
    local rows, avg, n = ns.GearLines({ { name = "Me", level = 62 }, { name = "Tank", guid = "g2" }, { name = "Far", guid = "g3", state = "far" } }, 120)
    if rows[1].name ~= "Tank" or rows[2].name ~= "Me" or rows[3].name ~= "Far" then error("order wrong") end
    if n ~= 2 or math.abs(avg - 60) > 0.01 then error("average wrong") end
    local stale = ns.GearLines({ { name = "Tank", guid = "g2" } }, 100 + 601)
    if stale[1].level ~= nil then error("a level older than ten minutes was used") end
    ns.gearKnown["g2"] = nil
    local lines = ns:ShowGear()
    if type(lines) ~= "table" or #lines < 2 then error("the window has no lines") end
end)
try("Lifetime stats: counts, the run log's bosses and runs, and the page", function()
    if type(ns.LifetimeRows) ~= "function" then error("no lifetime stats") end
    local store = { ["A - R"] = { since = 10, kills = 5, deaths = 1, goldMade = 50000 }, ["B - R"] = { since = 5, kills = 3 } }
    local runs = { { char = "A - R", kills = { x = 1, y = 2 } }, { char = "B - R", kills = { z = 1 } } }
    local rows, since = ns.LifetimeRows(store, "A - R", runs, { Zone = { { secs = 600 } } })
    local by = {}
    for _, r in ipairs(rows) do by[r[1]] = r end
    if by.kills[2] ~= 5 or by.kills[3] ~= 8 or by.bosses[2] ~= 2 or by.bosses[3] ~= 3 or by.runs[3] ~= 2 or by.farmed[3] ~= 600 or since ~= 5 then
        error("rows wrong") end
    local before = ns.root.lifetime and ns.root.lifetime[ns:CharKey()] and ns.root.lifetime[ns:CharKey()].deaths or 0
    ns.LifetimeCount("deaths", 1)
    if ns.db.lifetimeStats and (ns.root.lifetime[ns:CharKey()].deaths or 0) ~= before + 1 then error("a death was not counted") end
    ns:ShowLifetime()
end)
try("Best times: one record, kept by the run log", function()
    if type(ns.RunBossBest) ~= "function" then error("no run log bests") end
    local r = ns.RunNew("Deadmines", "Normal", 1000)
    ns.RunPull(r, "Sneed", 1100)
    ns.RunEncounter(r, "Sneed", true, 1190)
    if r.fights["Sneed"] ~= 90 then error("the fight's length was not kept") end
    local log = { r, { instance = "Deadmines", fights = { Sneed = 80 }, kills = { Sneed = 50 }, start = 0, wipes = {}, loot = {} } }
    if ns.RunBossBest(log, "Deadmines", "Sneed") ~= 80 then error("the boss best is wrong") end
    if ns.RunPlaceBest(log, "Deadmines") == nil then error("no place best") end
end)
try("Equip prompt: the slots to choose from, and the notice", function()
    if type(ns.EquipChoices) ~= "function" then error("no equip prompt") end
    local worn = { [11] = { ilvl = 50 }, [12] = { ilvl = 40 }, [5] = { ilvl = 30 } }
    local ring = ns.EquipChoices("INVTYPE_FINGER", worn)
    if #ring ~= 2 or ring[1].slot ~= 11 or ring[2].slot ~= 12 then error("a ring should offer both ring slots") end
    local chest = ns.EquipChoices("INVTYPE_CHEST", worn)
    if #chest ~= 1 or chest[1].slot ~= 5 then error("a chest should offer its one slot") end
    if #ns.EquipChoices("INVTYPE_BAG", worn) ~= 0 then error("a bag is not gear") end
    if ns.upgradePromptTest then
        local realW = env.GetInventoryItemLink
        ns.upgradePromptTest.Show("|cff0070dd|Hitem:424260::::::::60:::::|h[Test Ring]|h|r", 7)
        env.GetInventoryItemLink = realW
    end
end)
try("Milestones: crossed once, written down, shown on the stats page", function()
    if type(ns.MilestonesCrossed) ~= "function" then error("no milestones") end
    local c = ns.MilestonesCrossed("kills", 95, 1005)
    if #c ~= 3 or c[1] ~= 100 or c[3] ~= 1000 then error("crossed wrong") end
    if #ns.MilestonesCrossed("kills", 1000, 1001) ~= 0 then error("a milestone was crossed twice") end
    if ns.MilestoneText("bosses", 1) == ns.MilestoneText("bosses", 10) then error("the first boss should read differently") end
    if not tostring(ns.MilestoneText("goldMade", 10000000)):find("1") then error("gold milestone text wrong") end
    if ns.db.lifetimeStats then
        local me = ns.root.lifetime[ns:CharKey()]
        me.quests = 9
        local before = type(me.milestones) == "table" and #me.milestones or 0
        ns.LifetimeCount("quests", 1)
        if #(me.milestones or {}) ~= before + 1 then error("10 quests was not noted") end
        ns.LifetimeCount("quests", 0)
        if ns.MilestoneReach(me, "quests", 10) ~= false then error("the same milestone was noted twice") end
        ns:ShowLifetime()
    end
end)
try("Boss guide: a short line for each ability", function()
    if type(ns.GuideShort) ~= "function" then error("no boss guide") end
    local s = ns.GuideShort("|cffff0000Deep Breath|r: Onyxia takes a deep breath. Everyone burns. More text here.", 90)
    if s ~= "Deep Breath: Onyxia takes a deep breath." then error("short line wrong: " .. s) end
    if #ns.GuideShort(string.rep("word ", 50), 40) > 40 then error("too long") end
    ns.BossGuide("Nobody Here")
end)
try("Polish 11.17.1: upgrades wait their turn, and a goal already reached says so", function()
    local t = ns.upgradePromptTest
    if t then
        local f = t.frame
        rawset(f, "IsShown", function() return true end)
        local q = t.Queue()
        for i = #q, 1, -1 do q[i] = nil end
        f.link = "|cff0070dd|Hitem:424270::::::::60:::::|h[First]|h|r"
        t.Show("|cff0070dd|Hitem:424271::::::::60:::::|h[Second]|h|r", 5)
        if #t.Queue() ~= 1 then error("the second upgrade did not wait its turn: " .. tostring(f:IsShown()) .. " " .. tostring(f.link) .. " " .. #t.Queue()) end
        t.Show("|cff0070dd|Hitem:424271::::::::60:::::|h[Second]|h|r", 5)
        if #t.Queue() ~= 1 then error("the same upgrade waited twice") end
        rawset(f, "IsShown", nil)
        t.Next()
    end
    local goals = ns.db.goals
    ns.db.goals = {}
    ns:GoalCommand("level 2")
    if ns.db.goals[1] and ns.db.goals[1].reached ~= true then error("a level already reached was not marked so") end
    ns.db.goals = goals
end)
try("13.0 planner: step kinds", function()
    local g = ns.GuideParse("guide: Kinds\nfly 23 | Southshore\nfly | Take the bat\nlearnflight 24 | Tarren Mill\nsail menethil-theramore | Theramore\nbind | Southshore\n")
    local s = g.steps
    if #s ~= 5 or s[1].node ~= 23 or s[2].node ~= nil or s[3].node ~= 24 or s[4].crossing ~= "menethil-theramore" or s[5].text ~= "Southshore" then error("the new kinds parse") end
    local again = ns.GuideParse(ns.GuideText(g))
    for i = 1, 5 do if ns.GuideLine(again.steps[i]) ~= ns.GuideLine(s[i]) then error("round trip " .. i) end end
    local w = { knownFlight = function(n) return n == 24 end, landedAt = function(n) return n == 23 end,
                crossed = function(c) return c == "menethil-theramore" end, bind = "Southshore", near = function() return false end }
    if not ns.GuideStepDone(s[1], w) or ns.GuideStepDone(s[2], w) or not ns.GuideStepDone(s[3], w) or not ns.GuideStepDone(s[4], w) or not ns.GuideStepDone(s[5], w) then error("done") end
    w.bind = "Booty Bay"; if ns.GuideStepDone(s[5], w) then error("bound elsewhere") end
    if ns.GuideParseLine("learnflight | x") ~= nil then error("learnflight needs a node number") end
end)
try("13.0 planner: reading Questie", function()
    local realLoaded, realMeta, realQ, realLoader = env.C_AddOns.IsAddOnLoaded, rawget(env.C_AddOns, "GetAddOnMetadata"), rawget(env, "Questie"), rawget(env, "QuestieLoader")
    local loaded, meta, ready = true, "4", nil
    local npcs = {
        [9] = { spawns = { [40] = { { 30, 40 } } }, minLevel = 9, maxLevel = 9, rank = 0, npcFlags = 65536 + 2, name = "Innkeeper Nine" },
        [11] = { minLevel = 5, maxLevel = 5, rank = 0 },
        [20] = { spawns = { [40] = { { 50, 60 } } }, minLevel = 10, maxLevel = 10, rank = 0 },
        [21] = { spawns = { [40] = { { 55, 65 } } }, minLevel = 12, maxLevel = 12, rank = 1 },
    }
    local quests = {
        [101] = { name = "Wolves", questLevel = 10, level = 10, requiredLevel = 8, startedBy = { { 9 } }, finishedBy = { { 9 }, },
                  objectives = { { { 20, "Wolf slain", 0 } } }, specialFlags = 0 },
        [102] = { name = "From an item", startedBy = { nil, nil, { 5 } }, finishedBy = { { 9 } } },
        [103] = { name = "Lost giver", startedBy = { { 11 } }, finishedBy = { { 9 } } },
        [105] = { name = "Scaling", questLevel = -1, level = 12, requiredLevel = 7, startedBy = { { 9 } }, finishedBy = { { 9 } } },
        [106] = { name = "Grouped", questLevel = 10, level = 10, startedBy = { { 9 } }, finishedBy = { { 9 } } },
        [104] = { name = "Elite", startedBy = { { 9 } }, finishedBy = { { 9 } }, objectives = { { { 21, "Boss slain" } } } },
    }
    local fakes = {
        QuestieDB = { QuestPointers = { [101] = 5432, [102] = true, [103] = true, [104] = true, [105] = true, [106] = true },
            NPCPointers = { [9] = 777, [20] = 3, [21] = true }, npcFlags = { INNKEEPER = 65536 },
            IsGroupQuest = function(id) return id == 106 end,
            GetQuest = function(id) return quests[id] end, IsDoable = function() return true end,
            QueryNPCSingle = function(id, key) return npcs[id] and npcs[id][key] end },
        QuestXP = { GetQuestLogRewardXP = function() return 450 end },
        ZoneDB = { GetUiMapIdByAreaId = function(_, area) return area == 40 and 1436 or nil end },
    }
    env.Questie = { API = { isReady = true, RegisterOnReady = function(f) ready = f end } }
    env.QuestieLoader = { ImportModule = function(_, name) return fakes[name] end }
    env.C_AddOns.IsAddOnLoaded = function() return loaded end
    rawset(env.C_AddOns, "GetAddOnMetadata", function() return meta end)
    local ok, err = pcall(function()
        local src, why = ns.PlannerSource()
        if not src or src.kind ~= "questie" then error("questie source: " .. tostring(why)) end
        local q = src.quest(101)
        if q.starts[1].map ~= 1436 or q.starts[1].x ~= 30 or q.objectives[1].kind ~= "kill" or q.objectives[1].mobLevel ~= 10 or q.xp ~= 450 then error("record 101") end
        if q.objectives[1].spots[1].y ~= 60 or q.ends[1].map ~= 1436 then error("spots and ends") end
        if src.quest(102) ~= nil or src.quest(103) ~= nil then error("no giver on a map: skipped") end
        if not src.quest(104).elite then error("elite from the objective's rank") end
        if #src.ids() ~= 6 then error("ids") end
        local has101 = false
        for _, id in ipairs(src.ids()) do if id == 101 then has101 = true end if id == 5432 then error("a pointer's offset is not an id") end end
        if not has101 then error("ids are the pointer map's keys") end
        local inns = src.inns()
        if #inns ~= 1 or inns[1].name ~= "Innkeeper Nine" or inns[1].map ~= 1436 or inns[1].x ~= 30 then error("innkeepers from the npc flags") end
        if src.quest(105).level ~= 12 or src.quest(105).minLevel ~= 7 then error("effective level, not the raw -1") end
        if not src.quest(106).group or src.quest(101).group then error("group from Questie's IsGroupQuest") end
        if q.objectives[1].count ~= nil or q.objectives[1].countKnown ~= false then error("Questie has no kill counts") end
        local QL, realObj, realTag, realEnum = env.C_QuestLog, env.C_QuestLog.GetQuestObjectives, rawget(env.C_QuestLog, "GetQuestTagInfo"), env.Enum
        local realOnQ = QL.IsOnQuest
        QL.IsOnQuest = function() return true end                 -- (a quest in the log is rebuilt, not read from the cache)
        QL.GetQuestObjectives = function() return { { numRequired = 8 } } end
        local counted = src.quest(101).objectives[1]
        QL.GetQuestObjectives = realObj
        if counted.count ~= 8 or counted.countKnown ~= true then error("the quest log's count") end
        env.Enum = setmetatable({ QuestTag = { Group = 1, Dungeon = 81, Raid = 62, Raid10 = 88, Raid25 = 89 } }, { __index = realEnum })
        QL.GetQuestTagInfo = function(id) return { tagID = id == 101 and 81 or 88 } end
        local d, g = src.quest(101), src.quest(106)
        QL.IsOnQuest = realOnQ
        QL.GetQuestTagInfo = realTag; env.Enum = realEnum
        if not d.dungeon or d.group or not g.group or g.dungeon then error("tags from the log through Enum.QuestTag") end
        meta = "5"; src, why = ns.PlannerSource(); if src or why ~= "changed" then error("another contract is a change") end
        meta = "4"; fakes.QuestieDB.GetQuest = function() error("boom") end
        src, why = ns.PlannerSource(); local okQ = src and pcall(src.quest, 999); if src and (not okQ) then error("errors inside Questie are caught") end
        src, why = ns.PlannerSource(); if src or why ~= "changed" then error("an error inside Questie is a change") end
        env.Questie.API.isReady = false; src, why = ns.PlannerSource(); if src or why ~= "waiting" then error("waits for Questie") end
        if not ready then error("registers for ready") end
        local replans, realReplan = {}, ns.PlannerReplan
        ns.PlannerReplan = function(_, why2) replans[#replans + 1] = why2 end
        ready(); ns.PlannerReplan = realReplan
        if replans[1] ~= "questie" then error("ready callback replans") end
        env.Questie.API.isReady = true; src, why = ns.PlannerSource(); if not src then error("ready clears waiting: " .. tostring(why)) end
        env.Questie.API.isReady = false
        loaded = false; src, why = ns.PlannerSource(); if src or why ~= "missing" then error("no Questie") end
        local log = ns.PlannerLogSource(); if log.kind ~= "log" or type(log.ids()) ~= "table" then error("log source") end
    end)
    ns.PlannerSourceReset()
    env.C_AddOns.IsAddOnLoaded = realLoaded; rawset(env.C_AddOns, "GetAddOnMetadata", realMeta)
    rawset(env, "Questie", realQ); rawset(env, "QuestieLoader", realLoader)
    if not ok then error(err, 0) end
end)
try("13.0 planner: a cheap level check, a record cache, and quests in the log", function()
    local realLoaded, realMeta, realQ, realLoader = env.C_AddOns.IsAddOnLoaded, rawget(env.C_AddOns, "GetAddOnMetadata"), rawget(env, "Questie"), rawget(env, "QuestieLoader")
    local realOn = env.C_QuestLog.IsOnQuest
    local inlog, built = {}, 0
    local npcs = { [9] = { spawns = { [40] = { { 30, 40 } } }, minLevel = 9, maxLevel = 9, rank = 0 }, [11] = { minLevel = 5, maxLevel = 5, rank = 0 } }
    local quests = {
        [101] = { name = "Wolves", questLevel = 10, level = 10, startedBy = { { 9 } }, finishedBy = { { 9 } } },
        [500] = { name = "From a drop", questLevel = 10, level = 10, startedBy = { { 11 } }, finishedBy = { { 9 } } },
        [501] = { name = "Also from a drop", questLevel = 10, level = 10, startedBy = { { 11 } }, finishedBy = { { 9 } } },
    }
    local pointers = { [101] = true, [500] = true, [501] = true }
    for id = 1000, 3999 do quests[id] = { name = "Far", questLevel = 40, level = 40, startedBy = { { 9 } }, finishedBy = { { 9 } } }; pointers[id] = true end
    local fakes = {
        QuestieDB = { QuestPointers = pointers,
            GetQuest = function(id) built = built + 1; return quests[id] end, IsDoable = function() return true end,
            QueryQuestSingle = function(id, key) return quests[id] and quests[id][key] end,
            QueryNPCSingle = function(id, key) return npcs[id] and npcs[id][key] end },
        QuestXP = { GetQuestLogRewardXP = function() return 100 end },
        ZoneDB = { GetUiMapIdByAreaId = function(_, area) return area == 40 and 1436 or nil end },
    }
    env.Questie = { API = { isReady = true, RegisterOnReady = function() end } }
    env.QuestieLoader = { ImportModule = function(_, name) return fakes[name] end }
    env.C_AddOns.IsAddOnLoaded = function() return true end
    rawset(env.C_AddOns, "GetAddOnMetadata", function() return "4" end)
    env.C_QuestLog.IsOnQuest = function(id) return inlog[id] or false end
    ns.PlannerSourceReset()
    local ok, err = pcall(function()
        local src = ns.PlannerSource()
        if not src then error("questie source") end
        local ctx = { level = 10, done = function() return false end, onQuest = function(id) return inlog[id] or false end }
        local function ids(list) local o = {}; for _, r in ipairs(list) do o[r.id] = true end; return o end
        local list = ns.PlannerCandidates(src, ctx)
        local got = ids(list)
        if not got[101] or got[500] or got[501] or #list ~= 1 then error("a quest with no placeable giver, not in the log, is skipped") end
        if built ~= 3 then error("a record was built for a quest outside the level window: " .. built .. " builds") end
        built = 0
        ns.PlannerCandidates(src, ctx)
        if built ~= 0 then error("cached records were rebuilt: " .. built) end
        inlog[500] = true
        list = ns.PlannerCandidates(src, ctx)
        got = ids(list)
        if not got[500] or not got[101] or #list ~= 2 then error("a quest in the log with no placeable giver is kept") end
        if built ~= 1 then error("only the quest in the log is rebuilt: " .. built) end
        built = 0
        ctx.level = 11
        ns.PlannerCandidates(src, ctx)
        if built < 2 then error("a new level empties the cache: " .. built) end
        built = 0
        ns.PlannerSourceReset()
        src = ns.PlannerSource()
        ns.PlannerCandidates(src, ctx)
        if built < 2 then error("a source reset empties the cache: " .. built) end
    end)
    ns.PlannerSourceReset()
    env.C_QuestLog.IsOnQuest = realOn
    env.C_AddOns.IsAddOnLoaded = realLoaded; rawset(env.C_AddOns, "GetAddOnMetadata", realMeta)
    rawset(env, "Questie", realQ); rawset(env, "QuestieLoader", realLoader)
    if not ok then error(err, 0) end
end)
try("13.0 planner: travel", function()
    local real = { map = env.C_Map, vec = rawget(env, "CreateVector2D"), taxi = rawget(env, "C_TaxiMap"), nodeType = rawget(env, "TaxiNodeGetType"),
                   num = rawget(env, "NumTaxiNodes"), onTaxi = rawget(env, "UnitOnTaxi"), time = env.GetTime, bind = rawget(env, "GetTaxiMapID") }
    local savedRoot, savedKey = ns.root.planner, ns.root.guideKey
    local saved = { nodes = ns.root.plannerNodes, ft = ns.root.plannerFlightTimes, ct = ns.root.plannerCrossTimes, smp = ns.root.plannerTimeSamples }
    local pos, clock, taxi = { 1, 10, 10 }, 1000, false
    local at = function(map, x, y) pos = { map, x, y } end
    local cm = {}
    for k, v in pairs(real.map) do cm[k] = v end
    cm.GetWorldPosFromMapPos = function(map, v)
        local x, y = v.x * 1000, v.y * 1000
        if map == 1 then return 0, { x = x, y = y } end
        if map == 2 then return 0, { x = x + 3000, y = y } end
        if map == 3 then return 1, { x = x, y = y } end
    end
    cm.GetBestMapForUnit = function() return pos[1] end
    cm.GetPlayerMapPosition = function() return { GetXY = function() return pos[2] / 100, pos[3] / 100 end } end
    env.C_Map = cm
    env.CreateVector2D = function(x, y) return { x = x, y = y } end
    env.GetTime = function() return clock end
    env.UnitOnTaxi = function() return taxi end
    env.GetTaxiMapID = function() return 1 end
    env.C_TaxiMap = { GetAllTaxiNodes = function() return {
        { nodeID = 5, slotIndex = 1, name = "Five", position = { x = 0.10, y = 0.10 } },
        { nodeID = 6, slotIndex = 2, name = "Six", position = { x = 0.0, y = 0.0 } },
        { nodeID = 7, slotIndex = 3, name = "Seven", position = { x = 0.9, y = 0.9 } } } end }
    env.NumTaxiNodes = function() return 3 end
    env.TaxiNodeGetType = function(i) return i == 3 and "UNREACHABLE" or (i == 1 and "CURRENT" or "REACHABLE") end
    ns.root.guideKey = tonumber(sources["Guide.lua"]:match("local GUIDE_KEY = (%d+)"))
    local ok, err = pcall(function()
        local c, wx, wy = ns.PlannerWorldPos(2, 50, 50)
        if c ~= 0 or wx ~= 3500 or wy ~= 500 then error("world position") end
        if ns.PlannerWorldPos(9, 1, 1) ~= nil then error("an unplaceable map is nil") end
        local crossings = { { id = "fake", a = { map = 1, x = 90, y = 90 }, b = { map = 3, x = 10, y = 10 }, faction = "Alliance", seconds = 100 } }
        local ctx = { speed = 7, faction = "Alliance", crossings = crossings,
            flights = { { node = 1, map = 1, x = 12, y = 10, known = true }, { node = 2, map = 2, x = 50, y = 50, known = true } },
            flightTime = function() return 60 end }
        local A, B = { map = 1, x = 10, y = 10 }, { map = 1, x = 20, y = 10 }
        local s, legs = ns.PlannerTravel(A, B, ctx); if math.abs(s - 100 / 7) > 0.5 or legs[1].kind ~= "run" then error("a short run") end
        local far = { map = 2, x = 50, y = 50 }
        s, legs = ns.PlannerTravel(A, far, ctx); if legs[2] == nil or legs[2].kind ~= "fly" then error("far: a known flight is used") end
        ctx.flights[2].known = false
        s, legs = ns.PlannerTravel(A, far, ctx); for _, l in ipairs(legs) do if l.kind == "fly" then error("never an unknown flight") end end
        ctx.hearth = { map = 2, x = 50, y = 49 }; s, legs = ns.PlannerTravel(A, far, ctx); if legs[1].kind ~= "hearth" then error("hearth when faster") end
        ctx.hearth = nil; ctx.flights[2].known = true
        if #ns.PlannerFlightPoints() ~= 0 then error("a plain read creates nothing") end
        ctx.hearth = { map = 3, x = 50, y = 49 }
        s, legs = ns.PlannerTravel(A, { map = 3, x = 50, y = 50 }, ctx); if legs[1].kind ~= "hearth" or legs[1].to.map ~= 3 then error("the hearth across the sea when faster than the boat") end
        ctx.hearth = nil
        for _, l in ipairs(legs) do if l.kind == "run" and l.seconds * 7 < 1 then error("no zero-length runs") end end
        if select(2, ns.PlannerTravel(A, A, ctx))[1] ~= nil then error("nowhere to go") end
        s, legs = ns.PlannerTravel(A, { map = 3, x = 50, y = 50 }, ctx); local sailed = false; for _, l in ipairs(legs) do sailed = sailed or (l.kind == "sail" and l.crossing == "fake") end
        if not sailed then error("the other continent: by boat") end
        ctx.faction = "Horde"; s = ns.PlannerTravel(A, { map = 3, x = 50, y = 50 }, ctx); if s ~= math.huge then error("no crossing for this faction") end
        -- flights are learned at the flight master, and timed
        fireEvent("TAXIMAP_OPENED")
        if not ns.PlannerKnownFlight(5) or not ns.PlannerKnownFlight(6) or ns.PlannerKnownFlight(7) then error("known flight points") end
        at(1, 10, 10); taxi = true; fireEvent("PLAYER_CONTROL_LOST")
        clock = clock + 60; at(1, 0, 0); fireEvent("PLAYER_CONTROL_GAINED"); taxi = false
        if ns.root.plannerFlightTimes["5-6"] ~= 60 then error("flight time recorded: " .. tostring(ns.root.plannerFlightTimes and ns.root.plannerFlightTimes["5-6"])) end
        if not ns.PlannerLandedAt(6) or ns.PlannerLandedAt(5) then error("landed at") end
        at(1, 10, 10); fireEvent("PLAYER_CONTROL_GAINED")
        if ns.PlannerLandedAt(5) or not ns.PlannerLandedAt(6) then error("control regained without a takeoff is no landing") end
        local pts = ns.PlannerFlightPoints()
        if #pts ~= 3 then error("flight points for the planner") end
        -- a boat ride: standing at one dock, waiting and riding, then a loading screen at the other
        local real2 = ns.PLANNER_CROSSINGS
        ns.PLANNER_CROSSINGS = crossings
        at(3, 10, 10); ns.PlannerDockTick(); clock = clock + 5; at(1, 90, 90); fireEvent("PLAYER_ENTERING_WORLD")
        if ns.PlannerCrossed("fake") or (ns.root.plannerCrossTimes and ns.root.plannerCrossTimes.fake) then error("a short loading screen is no crossing") end
        at(1, 90, 90); ns.PlannerDockTick()
        clock = clock + 200; at(3, 10, 10); fireEvent("PLAYER_ENTERING_WORLD")
        if not ns.PlannerCrossed("fake") then error("crossed") end
        if math.abs(ns.root.plannerCrossTimes.fake - 200) > 1 then error("crossing time recorded") end
        ns.root.plannerTimeSamples = nil
        at(1, 10, 10); taxi = true; fireEvent("PLAYER_CONTROL_LOST"); clock = clock + 120; at(1, 0, 0); fireEvent("PLAYER_CONTROL_GAINED"); taxi = false
        if ns.root.plannerFlightTimes["5-6"] ~= 120 then error("fresh samples: " .. tostring(ns.root.plannerFlightTimes["5-6"])) end
        at(1, 10, 10); taxi = true; fireEvent("PLAYER_CONTROL_LOST"); clock = clock + 60; at(1, 0, 0); fireEvent("PLAYER_CONTROL_GAINED"); taxi = false
        if ns.root.plannerFlightTimes["5-6"] ~= 90 then error("the average of the recordings") end
        ns.PLANNER_CROSSINGS = real2
        if #ns.PLANNER_CROSSINGS ~= 7 then error("seven crossings") end
    end)
    env.C_Map = real.map; rawset(env, "CreateVector2D", real.vec); rawset(env, "C_TaxiMap", real.taxi); rawset(env, "TaxiNodeGetType", real.nodeType)
    rawset(env, "NumTaxiNodes", real.num); rawset(env, "UnitOnTaxi", real.onTaxi); env.GetTime = real.time; rawset(env, "GetTaxiMapID", real.bind)
    ns.root.planner, ns.root.guideKey = savedRoot, savedKey
    ns.root.plannerNodes, ns.root.plannerFlightTimes, ns.root.plannerCrossTimes, ns.root.plannerTimeSamples = saved.nodes, saved.ft, saved.ct, saved.smp
    if not ok then error(err, 0) end
end)
try("13.0 planner: what a quest is worth", function()
    local function rec(id, t)
        local r = { id = id, name = "Q" .. id, level = 9, minLevel = 1, xp = 300, starts = {}, ends = {}, objectives = {},
            pre = {}, preAny = {}, exclusive = {}, elite = false, group = false, dungeon = false, repeatable = false, doable = true }
        for k, v in pairs(t or {}) do r[k] = v end
        return r
    end
    local recs = {
        [201] = rec(201, { objectives = { { kind = "kill", count = 6, countKnown = true, mobLevel = 9, spots = {} } } }),
        [202] = rec(202, { level = 3 }),
        [203] = rec(203, { level = 10, elite = true }),
        [204] = rec(204, { level = 10, group = true }),
        [205] = rec(205, { level = 11, pre = { 201 } }),
        [206] = rec(206, { repeatable = true }),
    }
    local fakeSource = { kind = "questie", ids = function() return { 201, 202, 203, 204, 205, 206 } end, quest = function(id) return recs[id] end }
    if ns.PlannerKillXP(10, 10) ~= 95 or ns.PlannerKillXP(10, 12) ~= 104 or ns.PlannerKillXP(10, 4) ~= 0 or ns.PlannerKillXP(10, 10, true) ~= 190 then error("kill xp") end
    local list, skipped = ns.PlannerCandidates(fakeSource, { level = 10, group = "solo", inGroup = false, done = function() return false end, onQuest = function() return false end })
    local ids = {}; for _, r in ipairs(list) do ids[r.id] = true end
    if not ids[201] or ids[202] or ids[203] or ids[204] or ids[205] or ids[206] or skipped.group ~= 2 then error("solo candidates") end
    list = ns.PlannerCandidates(fakeSource, { level = 10, group = "grouped", inGroup = true, done = function(id) return id == 201 end, onQuest = function() return false end })
    ids = {}; for _, r in ipairs(list) do ids[r.id] = true end
    if not (ids[203] and ids[204] and ids[205]) or ids[201] then error("grouped, with 201 done") end
    list = ns.PlannerCandidates(fakeSource, { level = 10, group = "solo", inGroup = false, done = function() return false end, onQuest = function(id) return id == 202 end })
    ids = {}; for _, r in ipairs(list) do ids[r.id] = true end
    if not ids[202] then error("a quest in the log is always kept") end
    if ns.PlannerQuestXP(fakeSource.quest(201), { level = 10 }) <= fakeSource.quest(201).xp then error("kills add experience") end
    -- unknown kill count counts as 8
    local unk = rec(300, { objectives = { { kind = "kill", mobLevel = 10, spots = {} }, { kind = "item", spots = {} }, { kind = "other", spots = {} }, { kind = "place", spots = {} } } })
    if ns.PlannerQuestTime(unk, {}) ~= 8 * 25 + 8 * 25 / 0.5 + 60 then error("quest time " .. ns.PlannerQuestTime(unk, {})) end
    if ns.PlannerQuestTime(unk, { pace = 2 }) ~= 2 * (8 * 25 + 8 * 25 / 0.5 + 60) then error("pace scales time") end
    if ns.PlannerQuestXP(unk, { level = 10 }) ~= 300 + 8 * 95 then error("unknown kill count xp") end
    -- the follow-up counts half when it is a candidate
    local chain = rec(301, { nextQuest = 302 })
    if ns.PlannerQuestXP(chain, { level = 10, candidate = function(id) return id == 302 and rec(302) or nil end }) ~= 450 then error("next quest half") end
    -- pace
    local savedRoot = ns.root.planner
    ns.root.planner = nil
    if ns.PlannerPace() ~= 1 or ns.root.planner ~= nil then error("a read creates nothing") end
    ns.PlannerRecordPace(200, 100)
    if ns.PlannerPace() ~= 2 then error("first sample") end
    ns.PlannerRecordPace(100, 100)
    if math.abs(ns.PlannerPace() - 1.5) > 1e-9 then error("average") end
    for _ = 1, 10 do ns.PlannerRecordPace(1000, 100) end
    if ns.PlannerPace() ~= 3 then error("clamped high") end
    for _ = 1, 10 do ns.PlannerRecordPace(1, 100) end
    if ns.PlannerPace() ~= 0.5 then error("clamped low, last 10 only") end
    ns.root.planner = savedRoot
end)
try("13.0 planner: hubs and the route", function()
    local real = { map = env.C_Map, vec = rawget(env, "CreateVector2D") }
    local cm = {}
    for k, v in pairs(real.map) do cm[k] = v end
    cm.GetWorldPosFromMapPos = function(map, v)
        local x, y = v.x * 1000, v.y * 1000
        if map == 1 then return 0, { x = x, y = y } end
        if map == 2 then return 0, { x = x + 1000, y = y } end
        if map == 3 then return 1, { x = x, y = y } end
    end
    env.C_Map = cm
    env.CreateVector2D = function(x, y) return { x = x, y = y } end
    local function rec(id, map, x, y, xp, ox, oy)
        return { id = id, name = "Quest " .. id, level = 10, minLevel = 1, xp = xp,
            starts = { { map = map, x = x, y = y } }, ends = { { map = map, x = x, y = y } },
            objectives = { { kind = "kill", count = 4, countKnown = true, mobLevel = 10, spots = { { map = map, x = ox, y = oy } } } },
            pre = {}, preAny = {}, exclusive = {}, elite = false, group = false, dungeon = false, repeatable = false, doable = true }
    end
    local recs = {
        [401] = rec(401, 1, 30, 40, 300, 35, 45), [402] = rec(402, 1, 31, 40, 300, 36, 45), [403] = rec(403, 1, 30, 41, 300, 34, 46),
        [404] = rec(404, 1, 80, 80, 300, 82, 82),
        [411] = rec(411, 2, 20, 40, 3000, 25, 45), [412] = rec(412, 2, 21, 40, 3000, 25, 46), [413] = rec(413, 2, 20, 41, 3000, 24, 45),
        [421] = rec(421, 3, 50, 50, 99999, 52, 52),
    }
    local ids = { 401, 402, 403, 404, 411, 412, 413, 421 }
    local inns = { { name = "Bluebell Inn", map = 2, x = 21, y = 41 } }
    local source = { kind = "questie", ids = function() return ids end, quest = function(id) return recs[id] end, inns = function() return inns end }
    local doneSet = {}
    local ctx = { source = source, level = 10, group = "solo", inGroup = false, speed = 7, faction = "Alliance",
        done = function(id) return doneSet[id] == true end, onQuest = function() return false end,
        here = { map = 1, x = 30, y = 40 }, crossings = {}, learnFlights = true, bind = "Elsewhere", bindSpot = { map = 1, x = 30, y = 40 }, pace = 1,
        flights = { { node = 5, map = 1, x = 30, y = 42, known = true, name = "Five" }, { node = 6, map = 1, x = 70, y = 40, known = false, name = "Six" } },
        flightTime = function() return nil end }
    local ok, err = pcall(function()
        if ns.GUIDE_PLANNED ~= "\1planned" then error("the planned guide's name") end
        local cands = ns.PlannerCandidates(source, ctx)
        local zoneA = {}
        for _, r in ipairs(cands) do if r.starts[1].map == 1 then zoneA[#zoneA + 1] = r end end
        local hubs = ns.PlannerHubs(zoneA, ctx)
        if #hubs ~= 2 then error("zone A has two hubs: " .. #hubs) end
        local three
        for _, h in ipairs(hubs) do if #h.quests == 3 then three = h end end
        if not three or three.map ~= 1 or not (three.xp > 0 and three.seconds > 0) then error("the three-quest hub") end
        if ns.PlannerPickZone(cands, ctx) ~= 2 then error("zone B is worth the trip") end
        ctx.lastZone, ctx.lastZoneLevel = 1, 8
        if ns.PlannerPickZone(cands, ctx) ~= 1 then error("the last zone stays within three levels") end
        ctx.lastZoneLevel = 7
        if ns.PlannerPickZone(cands, ctx) ~= 2 then error("three levels on, the zone is picked again") end
        ctx.lastZone, ctx.lastZoneLevel = 3, 10
        if ns.PlannerPickZone(cands, ctx) ~= 2 then error("a last zone out of reach is picked again") end
        ctx.lastZone, ctx.lastZoneLevel = nil, nil
        -- the route into zone B: learn flight 6 on the way, accept all, bind, do, hand in
        local guide, summary = ns.PlannerRoute(ctx)
        if guide.name ~= ns.GUIDE_PLANNED or summary.zone ~= 2 or summary.empty or summary.fromLevel ~= 10 or not (summary.xp > 0 and summary.seconds > 0) then error("summary") end
        local at = { accept = {}, ["do"] = {}, turnin = {} }
        local learned, binds = 0, 0
        for i, s in ipairs(guide.steps) do
            if at[s.kind] then at[s.kind][s.quest] = i end
            if s.kind == "learnflight" and s.node == 6 then learned = learned + 1 end
            if s.kind == "bind" then binds = binds + 1 end
            if s.kind == "accept" and not (s.why and s.why.xp and s.why.xp > 0) then error("an accept says what it is worth") end
        end
        local lastAccept, firstDo = 0, math.huge
        for _, id in ipairs({ 411, 412, 413 }) do
            if not (at.accept[id] and at["do"][id] and at.turnin[id]) then error("steps for " .. id) end
            lastAccept = math.max(lastAccept, at.accept[id]); firstDo = math.min(firstDo, at["do"][id])
            if at.turnin[id] < at["do"][id] then error("hand in after doing " .. id) end
        end
        if lastAccept > firstDo then error("every accept before any do") end
        if learned ~= 1 then error("learn flight 6 on the way: " .. learned) end
        if binds ~= 1 then error("one bind in the new zone: " .. binds) end
        local again = ns.GuideParse(ns.GuideText(guide))
        if #again.steps ~= #guide.steps then error("round trip count") end
        for i, s in ipairs(guide.steps) do
            local p = again.steps[i]
            if ns.GuideLine(p) ~= ns.GuideLine(s) or p.kind ~= s.kind or p.quest ~= s.quest or p.node ~= s.node or p.map ~= s.map or p.x ~= s.x or p.y ~= s.y then
                error("round trip step " .. i .. ": " .. ns.GuideLine(s) .. " / " .. ns.GuideLine(p)) end
        end
        ctx.learnFlights = false
        guide = ns.PlannerRoute(ctx)
        for _, s in ipairs(guide.steps) do if s.kind == "learnflight" then error("no flights learned when that is off") end end
        ctx.bindSpot = { map = 2, x = 21.2, y = 41.1 }
        guide = ns.PlannerRoute(ctx)
        for _, s in ipairs(guide.steps) do if s.kind == "bind" then error("already bound there") end end
        -- zone B done: back to zone A, two hubs
        for _, id in ipairs({ 411, 412, 413 }) do doneSet[id] = true end
        cands = ns.PlannerCandidates(source, ctx)
        if ns.PlannerPickZone(cands, ctx) ~= 1 then error("zone A once B is done") end
        guide, summary = ns.PlannerRoute(ctx)
        if summary.zone ~= 1 then error("route in zone A") end
        local n = 0
        for _, s in ipairs(guide.steps) do if s.kind == "turnin" then n = n + 1 end end
        if n ~= 4 then error("two hubs in zone A: " .. n) end
        -- a zone stays picked until three levels have passed or it runs dry
        ctx.lastZone, ctx.lastZoneLevel = 1, 10
        if ns.PlannerPickZone(cands, ctx) ~= 1 then error("the zone stays") end
        ctx.lastZone, ctx.lastZoneLevel = nil, nil
        -- nothing left
        for _, id in ipairs(ids) do doneSet[id] = true end
        guide, summary = ns.PlannerRoute(ctx)
        if not summary.empty or #guide.steps ~= 0 then error("nothing left: empty") end
        -- fly, hearth and sail, each saying what it saves; a flight point learned because the plan uses it
        local function solo(extra)
            local one = { [501] = rec(501, 2, 80, 80, 3000, 81, 81) }
            local c = { source = { kind = "questie", ids = function() return { 501 } end, quest = function(id) return one[id] end },
                level = 10, group = "solo", speed = 7, faction = "Alliance", done = function() return false end, onQuest = function() return false end,
                here = { map = 1, x = 10, y = 10 }, crossings = {}, flights = {}, learnFlights = false, pace = 1, flightTime = function() return nil end }
            for k, v in pairs(extra) do c[k] = v end
            local g = ns.PlannerRoute(c)
            local back = ns.GuideParse(ns.GuideText(g))
            for i, st in ipairs(g.steps) do
                local b = back.steps[i]
                for _, f in ipairs({ "kind", "node", "crossing", "quest", "title", "text", "map", "x", "y" }) do
                    if not b or b[f] ~= st[f] then error("round trip " .. ns.GuideLine(st) .. " field " .. f) end
                end
            end
            return g.steps
        end
        local function find(steps, kind)
            for _, st in ipairs(steps) do if st.kind == kind then return st end end
        end
        local st = find(solo({ flights = { { node = 7, map = 1, x = 11, y = 10, known = true, name = "Seven" }, { node = 8, map = 2, x = 80, y = 79, known = true, name = "Eight" } } }), "fly")
        if not st or st.node ~= 8 or not (st.why and st.why.saves and st.why.saves > 0) then error("a fly step that saves time") end
        st = find(solo({ hearth = { map = 2, x = 80, y = 80 } }), "hearth")
        if not st or not (st.why and st.why.saves and st.why.saves > 0) then error("a hearth step that saves time") end
        st = find(solo({ crossings = { { id = "ferry", a = { map = 1, x = 11, y = 10 }, b = { map = 2, x = 80, y = 79 }, seconds = 20 } } }), "sail")
        if not st or st.crossing ~= "ferry" or not (st.why and st.why.saves and st.why.saves > 0) then error("a sail step that saves time") end
        local steps = solo({ learnFlights = true, flights = { { node = 9, map = 1, x = 0, y = 100, known = false, name = "Nine" }, { node = 8, map = 2, x = 80, y = 79, known = true, name = "Eight" } } })
        st = find(steps, "learnflight")
        if not st or st.node ~= 9 or not find(steps, "fly") then error("flight 9 is learned because the route flies from it") end
        -- the live context builds without error
        local live = ns.PlannerContext()
        if type(live) ~= "table" or not live.source or type(live.done) ~= "function" or not live.speed or type(live.flights) ~= "table" then error("live context") end
        if live.bindSpot ~= nil and type(live.bindSpot) ~= "table" then error("bindSpot") end
    end)
    env.C_Map = real.map; rawset(env, "CreateVector2D", real.vec)
    if not ok then error(err, 0) end
end)
try("13.0 planner: running it", function()
    local real = { map = env.C_Map, vec = rawget(env, "CreateVector2D"), ql = env.C_QuestLog, level = env.UnitLevel, time = env.GetTime,
                   loaded = env.C_AddOns.IsAddOnLoaded, source = ns.PlannerSource, combat = env.InCombatLockdown, budget = ns.PLANNER_BUDGET_MS }
    local saved = { key = ns.root.guideKey, guides = ns.root.guides, state = ns.root.guideState, planner = ns.root.planner }
    local pos, clock = { 1, 30, 40 }, 5000
    local cm = {}
    for k, v in pairs(real.map) do cm[k] = v end
    cm.GetWorldPosFromMapPos = function(map, v) if map == 1 then return 0, { x = v.x * 1000, y = v.y * 1000 } end end
    cm.GetBestMapForUnit = function() return pos and pos[1] or nil end
    cm.GetPlayerMapPosition = function() return pos and { GetXY = function() return pos[2] / 100, pos[3] / 100 end } or nil end
    cm.GetMapInfo = function(map) return map == 1 and { name = "Testshire" } or nil end
    env.C_Map = cm
    env.CreateVector2D = function(x, y) return { x = x, y = y } end
    env.UnitLevel = function() return 10 end
    env.GetTime = function() return clock end
    local accepted, handed, logged = {}, {}, {}
    env.C_QuestLog = { IsOnQuest = function(id) return accepted[id] or false end, IsQuestFlaggedCompleted = function(id) return handed[id] or false end,
        IsComplete = function() return false end, ReadyForTurnIn = function() return false end,
        GetTitleForQuestID = function(id) return "Quest " .. id end,
        GetNumQuestLogEntries = function() return #logged end,
        GetInfo = function(i) return logged[i] and { questID = logged[i], title = "Logged " .. logged[i], questLevel = 10 } or nil end,
        GetLogIndexForQuestID = function(id) for i, q in ipairs(logged) do if q == id then return i end end end,
        GetNextWaypoint = function() return 1, 0.31, 0.41 end }
    local function rec(id, x, y, extra)
        local r = { id = id, name = "Quest " .. id, level = 10, minLevel = 1, xp = 400,
            starts = { { map = 1, x = x, y = y } }, ends = { { map = 1, x = x, y = y } },
            objectives = { { kind = "kill", count = 4, countKnown = true, mobLevel = 10, spots = { { map = 1, x = x + 4, y = y + 4 } } } },
            pre = {}, preAny = {}, exclusive = {}, elite = false, group = false, dungeon = false, repeatable = false, doable = true }
        for k, v in pairs(extra or {}) do r[k] = v end
        return r
    end
    local recs = { [101] = rec(101, 30, 40), [102] = rec(102, 31, 40), [103] = rec(103, 30, 41), [104] = rec(104, 31, 41, { group = true }) }
    local ids = { 101, 102, 103, 104 }
    local world = { kind = "questie", ids = function() return ids end, quest = function(id) return recs[id] end, inns = function() return {} end }
    ns.PlannerSource = function() return world end
    ns.root.guides, ns.root.guideState, ns.root.planner = nil, nil, nil
    fireEvent("PLAYER_REGEN_ENABLED")                        -- (out of any fight an earlier test left the game in)
    ns.root.guideKey = tonumber(sources["Guide.lua"]:match("local GUIDE_KEY = (%d+)"))
    local function frame()
        for i = 1, #handlers do local h = handlers[i]; if h.name == "OnUpdate" then pcall(h.fn, h.self, 0.02) end end
        runTimers()
    end
    local function settle()
        for _ = 1, 3000 do
            if not ns.plannerBusy and not ns.plannerQueued then return end
            frame()
        end
        error("the planner never finished: busy " .. tostring(ns.plannerBusy) .. ", queued " .. tostring(ns.plannerQueued) .. ", " .. tostring(ns.plannerReason) .. ", steps " .. tostring(ns.plannerSteps) .. ", here " .. table.concat({ tostring(ns.GuideHere()) }, ",") .. ", placed " .. tostring(ns.PlannerWorldPos(ns.GuideHere())))
    end
    local function planned() return ns:GuideGet(ns.GUIDE_PLANNED) end
    local ok, err = pcall(function()
        -- a plan, followed
        local panel, said = nil, {}
        if ns:PlannerStart() ~= true then error("PlannerStart") end
        settle()
        if ns.GuideState().name ~= ns.GUIDE_PLANNED or not planned() or #planned().steps == 0 then error("following the planned guide") end
        panel = ns:GuideShowPanel()
        for _, k in ipairs({ "title", "now", "skipped" }) do
            if not panel[k] then error("the panel has no " .. k) end
            rawset(panel[k], "SetText", function(_, t) said[k] = t end)
        end
        ns:GuideAdvance()
        if not tostring(said.title):find(string.format(ns:Tr("Planned: %s, level %s → %s"), "Testshire", "10", ""), 1, true) then error("the panel's title: " .. tostring(said.title)) end
        if said.skipped ~= string.format(ns:Tr("Skipped: %d group quests (Solo is on)"), 1) then error("the skipped line: " .. tostring(said.skipped)) end
        if not (planned().estimates and (planned().estimates[101] or 0) > 0) then error("each quest's estimate is kept with the plan") end
        local text = ns.GuideText(planned())
        -- the same plan, a little at a time
        ns.PLANNER_BUDGET_MS = 0
        local before = ns.plannerSteps
        ns:PlannerReplan("test"); settle()
        if ns.plannerSteps - before < 5 then error("planned in slices: " .. (ns.plannerSteps - before)) end
        if ns.GuideText(planned()) ~= text then error("sliced and unsliced plans differ") end
        -- never in a fight
        ns:PlannerReplan("test"); frame(); frame()
        if not ns.plannerBusy then error("the plan should be under way") end
        env.InCombatLockdown = function() return true end
        before = ns.plannerSteps
        for _ = 1, 10 do frame() end
        if ns.plannerSteps ~= before then error("planned in combat") end
        env.InCombatLockdown = real.combat
        fireEvent("PLAYER_REGEN_DISABLED")
        for _ = 1, 10 do frame() end
        if ns.plannerSteps ~= before then error("planned after the fight started") end
        fireEvent("PLAYER_REGEN_ENABLED")
        settle()
        if ns.GuideText(planned()) ~= text then error("a fight changed the plan") end
        -- nowhere in the world: wait, quietly
        local quiet = #printed
        pos = nil
        ns:PlannerReplan("test")
        before = ns.plannerSteps
        for _ = 1, 10 do frame() end
        if ns.plannerSteps ~= before or not (ns.plannerBusy or ns.plannerQueued) then error("planned with no position") end
        if #printed ~= quiet then error("said something with no position: " .. printed[#printed]) end
        pos = { 1, 30, 40 }
        settle()
        ns.PLANNER_BUDGET_MS = real.budget
        -- a step ticked off by hand stays ticked in the next plan
        ns:GuideSkip(false)
        if not ns.GuideState().ticked[1] then error("ticked") end
        ns:PlannerReplan("test"); settle()
        if not ns.GuideState().ticked[1] or ns.GuideState().at ~= 2 then error("a replan keeps the steps you ticked off") end
        -- a plan that fails keeps the last good one, and the panel says so
        local realRoute, nerr = ns.PlannerRoute, #ns.errors
        ns.PlannerRoute = function() error("boom") end
        ns:PlannerReplan("test"); settle()
        ns.PlannerRoute = realRoute
        if ns.GuideText(planned()) ~= text then error("a failed plan keeps the last good one") end
        ns:GuideAdvance()
        local note = ns:Tr("Couldn't plan the route; trying again after your next quest")
        if said.skipped ~= note then error("the failed plan's note: " .. tostring(said.skipped)) end
        if #ns.errors ~= nerr + 1 then error("a failed plan is listed for /fgui check") end
        for i = #ns.errors, nerr + 1, -1 do table.remove(ns.errors, i) end
        ns:PlannerReplan("test"); settle()
        if said.skipped == note then error("a good plan clears the note") end
        -- a quest in the log that no giver is placed for still gets its do and turn-in steps
        recs[105] = rec(105, 32, 40, { starts = {} }); accepted[105] = true
        ids = { 101, 102, 103, 104, 105 }
        ns:PlannerReplan("test"); settle()
        local kinds105 = {}
        for _, s in ipairs(planned().steps) do if s.quest == 105 then kinds105[s.kind] = true end end
        if not (kinds105["do"] and kinds105.turnin) or kinds105.accept then error("a logged quest without a giver is routed: do and turn-in only") end
        accepted[105] = nil; recs[105] = nil; ids = { 101, 102, 103, 104 }
        -- a replan queued mid-run: the stale run is dropped, never applied
        local applied, realSet = 0, ns.GuideSetPlan
        ns.GuideSetPlan = function(...) applied = applied + 1; return realSet(...) end
        ns.PLANNER_BUDGET_MS = 0
        ns:PlannerReplan("stale"); frame(); frame()
        if not ns.plannerBusy then error("the run should be under way") end
        ids = { 101 }
        ns:PlannerReplan("fresh"); settle()
        ns.GuideSetPlan = realSet
        ns.PLANNER_BUDGET_MS = real.budget
        if applied ~= 1 then error("the plan was applied " .. applied .. " times") end
        for _, s in ipairs(planned().steps) do if s.quest == 102 or s.quest == 103 then error("the stale plan was applied") end end
        ids = { 101, 102, 103, 104 }
        ns:PlannerReplan("test"); settle()
        -- logging in (or a /reload) plans again
        fireEvent("PLAYER_ENTERING_WORLD")
        if ns.plannerQueued ~= true then error("entering the world replans") end
        settle()
        -- pace, between marks: one hub of three quests (100 s each), all handed in 330 s after the mark
        if ns.PlannerPace() ~= 1 then error("no pace yet") end
        ns:PlannerStart(); settle()
        local plan = planned()
        plan.estimates, plan.travelShare = { [101] = 100, [102] = 100, [103] = 100 }, 0
        clock = clock + 330
        for _, id in ipairs({ 101, 102, 103 }) do handed[id] = true; fireEvent("QUEST_TURNED_IN", id, 400, 0) end
        if ns.plannerQueued ~= true then error("a hand-in queues a replan") end
        if ns.PlannerPace() ~= 1 then error("a run of hand-ins is measured once it is over") end
        clock = clock + 61; frame()
        if math.abs(ns.PlannerPace() - 1.1) > 0.01 then error("one hub of three quests: pace " .. ns.PlannerPace()) end
        settle()
        for _, s in ipairs(planned().steps) do if s.quest == 101 then error("the handed-in quest is still planned") end end
        -- the same hub with a chain's follow-up accepted between the hand-ins: still one run
        ns.root.planner = nil
        ns:PlannerStart(); settle()
        plan = planned()
        plan.estimates, plan.travelShare = { [111] = 100, [112] = 100, [113] = 100 }, 0
        clock = clock + 330
        fireEvent("QUEST_TURNED_IN", 111, 400, 0)
        accepted[121] = true; fireEvent("QUEST_ACCEPTED", 121); frame()
        planned().estimates = { [112] = 100, [113] = 100 }          -- (the fake world has no 112 or 113; in the game the new plan still holds them)
        clock = clock + 5
        fireEvent("QUEST_TURNED_IN", 112, 400, 0); fireEvent("QUEST_TURNED_IN", 113, 400, 0)
        if ns.PlannerPace() ~= 1 then error("an accept between hand-ins does not end the run") end
        clock = clock + 61; frame()
        if math.abs(ns.PlannerPace() - 335 / 300) > 0.01 then error("a follow-up accepted mid-run: pace " .. ns.PlannerPace()) end
        accepted[121] = nil
        settle()
        -- away for over half an hour: no sample
        clock = clock + 1900
        planned().estimates = { [105] = 100 }
        fireEvent("QUEST_TURNED_IN", 105, 0, 0)
        clock = clock + 61; frame()
        if math.abs(ns.PlannerPace() - 335 / 300) > 0.01 then error("time away is no sample: " .. ns.PlannerPace()) end
        settle()
        fireEvent("PLAYER_LEVEL_UP", 11)
        if ns.plannerQueued ~= true then error("a level replans") end
        settle()
        -- the hearthstone set at a bind step ticks it off
        local st = ns.GuideState()
        st.plan = { name = ns.GUIDE_PLANNED, steps = { { kind = "bind", text = "Bluebell Inn" }, { kind = "note", text = "after" } } }
        st.at, st.ticked, st.finished = 1, {}, nil
        fireEvent("HEARTHSTONE_BOUND")
        if ns.GuideState().at ~= 2 or not ns.plannerQueued then error("bound: the bind step is ticked off and a replan queued") end
        settle()
        -- no Questie: the quest log, and the install line once
        ns.PlannerSource = real.source
        env.C_AddOns.IsAddOnLoaded = function() return false end
        logged = { 701 }; accepted[701] = true
        local told = 0
        quiet = #printed
        ns:PlannerReplan("test"); settle()
        ns:PlannerReplan("test"); settle()
        for i = quiet + 1, #printed do if printed[i]:find(ns:Tr("Install Questie to plan new quests too."), 1, true) then told = told + 1 end end
        if told ~= 1 then error("the install line once: " .. told) end
        local fromLog = false
        for _, s in ipairs(planned().steps) do if s.kind == "turnin" and s.quest == 701 then fromLog = true end end
        if not fromLog then error("the plan comes from the quest log") end
        -- nothing worth the trip
        ns.PlannerSource = function() return { kind = "questie", ids = function() return {} end, quest = function() end, inns = function() return {} end } end
        logged = {}
        ns:PlannerReplan("test"); settle()
        ns:GuideAdvance()
        if said.now ~= ns:Tr("No quests left worth the trip; grinding or a dungeon may be faster") then error("the empty plan's line: " .. tostring(said.now)) end
        for _, k in ipairs({ "title", "now", "skipped" }) do rawset(panel[k], "SetText", nil) end
        -- /fgui guide plan, and off
        if ns:GuideCommand("plan") ~= true then error("/fgui guide plan") end
        ns:GuideCommand("off")
        if ns.plannerBusy or ns.plannerQueued then error("off stops the planner") end
        -- locked: nothing
        ns.root.guideKey = nil
        if ns:PlannerStart() ~= false or ns.plannerBusy or ns.plannerQueued then error("locked: no planning") end
    end)
    ns:PlannerStop()
    env.C_Map = real.map; rawset(env, "CreateVector2D", real.vec); env.C_QuestLog = real.ql; env.UnitLevel = real.level; env.GetTime = real.time
    env.C_AddOns.IsAddOnLoaded = real.loaded; ns.PlannerSource = real.source; env.InCombatLockdown = real.combat; ns.PLANNER_BUDGET_MS = real.budget
    ns.PlannerSourceReset()
    ns.root.guideKey, ns.root.guides, ns.root.guideState, ns.root.planner = saved.key, saved.guides, saved.state, saved.planner
    if not ok then error(err, 0) end
end)
try("13.0 planner: settings", function()
    local saved = { key = ns.root.guideKey, guides = ns.root.guides, state = ns.root.guideState, planner = ns.root.planner,
                    group = ns.db.plannerGroup, flights = ns.db.plannerLearnFlights, why = ns.db.plannerWhy }
    local ok, err = pcall(function()
        ns.root.guideKey = tonumber((sources["Guide.lua"] or ""):match("local GUIDE_KEY = (%d+)"))
        ns.root.guides, ns.root.guideState = nil, nil
        ns.db.plannerGroup, ns.db.plannerLearnFlights, ns.db.plannerWhy = "solo", true, true
        ns:ToggleConfig("guide")
        local P = ns.guidePage
        if not P or P.unlocked ~= true then error("unlocked: the Guide tab shows the controls") end
        if not (P.planButton and P.groupButton and P.flightsBox and P.whyBox) then error("the planner controls exist") end
        local function click(b)
            local f = b:GetScript("OnClick")
            if type(f) ~= "function" then for _, h in ipairs(handlers) do if h.self == b and h.name == "OnClick" then f = h.fn end end end
            f(b)
        end
        if not P.planButton.text:GetText():find(ns:Tr("Plan my route"), 1, true) then error("the button's words: " .. tostring(P.planButton.text:GetText())) end
        click(P.planButton)
        if ns.GuideState().name ~= ns.GUIDE_PLANNED then error("the button plans") end
        ns.plannerQueued = false
        click(P.groupButton)
        if ns.db.plannerGroup ~= "grouped" or not ns.plannerQueued then error("the group choice replans: " .. tostring(ns.db.plannerGroup)) end
        click(P.groupButton)
        if ns.db.plannerGroup ~= "all" then error("then everything") end
        click(P.groupButton)
        if ns.db.plannerGroup ~= "solo" then error("and round again") end
        ns.plannerQueued = false
        click(P.flightsBox)
        if ns.db.plannerLearnFlights ~= false then error("flights setting off") end
        if not ns.plannerQueued then error("flights setting replans") end
        ns.plannerQueued = false
        click(P.whyBox)
        if ns.db.plannerWhy ~= false or not ns.plannerQueued then error("why setting replans") end
        click(P.whyBox)
        -- show why
        local acc = { kind = "accept", quest = 5, title = "Q", why = { xp = 4100 } }
        local fly = { kind = "fly", text = "Fly", why = { saves = 200 } }
        local plain = ns.GuideStepText({ kind = "accept", quest = 5, title = "Q" })
        local planned = { name = ns.GUIDE_PLANNED, steps = { acc, fly } }
        local withWhy = ns.GuideStepText(acc, planned)
        if withWhy == plain or not withWhy:find("4", 1, true) or not withWhy:find("xp", 1, true) then error("xp why: " .. withWhy) end
        if not ns.GuideStepText(fly, planned):find("~3", 1, true) then error("saves why: " .. ns.GuideStepText(fly, planned)) end
        if not ns.GuideStepText({ kind = "fly", text = "Fly", why = { saves = 10 } }, planned):find("~1", 1, true) then error("at least a minute") end
        if ns.GuideStepText(acc) ~= plain then error("not on the planned guide: no why") end
        ns.db.plannerWhy = false
        if ns.GuideStepText(acc, planned) ~= plain then error("switched off: no why") end
        -- not running: no replan
        ns:GuideStop(); ns:PlannerStop(); ns.plannerQueued = false
        click(P.groupButton)
        if ns.plannerQueued then error("planner not running: no replan") end
        -- locked
        ns:GuideLock()
        ns:ToggleConfig("guide")
        if ns.guidePage.unlocked ~= false then error("locked: coming soon") end
    end)
    ns:PlannerStop()
    ns:ToggleConfig()
    ns.root.guideKey, ns.root.guides, ns.root.guideState, ns.root.planner = saved.key, saved.guides, saved.state, saved.planner
    ns.db.plannerGroup, ns.db.plannerLearnFlights, ns.db.plannerWhy = saved.group, saved.flights, saved.why
    if not ok then error(err, 0) end
end)
try("12.3 settings look: palette, accent, contrast, lettering", function()
    local keep = { theme = ns.db.theme, accent = ns.db.accent, lang = ns.root.language, style = ns.db.fontStyle }
    local function hex(r, g, b) return string.format("%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)) end
    local ok, err = pcall(function()
        ns.db.theme, ns.db.accent, ns.root.language, ns.db.fontStyle = "MIDNIGHT", "VIOLET", "enUS", "GLASS"     -- (Smoke's own ground is #12141a)
        ns:Retheme()
        if hex(ns:T("window")) == "12141a" then error("the test needs a theme whose ground differs") end
        ns:ToggleConfig("home")
        local win = ns.configFrame
        if rawget(win, "suiLook") ~= "settings" then error("the settings window is marked with its look") end
        if type(ns.LOOKS) ~= "table" or type(ns.LOOKS.settings) ~= "table" or type(ns.LOOKS.settingsContrast) ~= "table" then error("the two looks") end
        for _, look in pairs(ns.LOOKS) do
            if look["@accent"] or look.accent then error("a look never holds the accent") end
            for _, role in ipairs({ "window", "@bg", "bg", "field", "@border", "@rim", "@light", "@btn", "text", "dim", "faint" }) do
                if type(look[role]) ~= "table" then error("a look holds " .. role) end
            end
        end
        local parents = 0
        local function under(parent)
            local t = newmock()
            rawset(t, "GetParent", function() parents = parents + 1; return parent end)
            rawset(t, "SetVertexColor", function(self, r, g, b) rawset(self, "rgb", { r, g, b }) end)
            rawset(t, "SetTextColor", function(self, r, g, b) rawset(self, "rgb", { r, g, b }) end)
            rawset(t, "SetFont", function(self, path, size, flags) rawset(self, "face", path); rawset(self, "size", size); rawset(self, "flags", flags) end)
            return t
        end
        local function reads(t) local c = rawget(t, "rgb"); return c and hex(c[1], c[2], c[3]) or "nothing" end
        local row = newmock(); rawset(row, "GetParent", function() return win end)          -- (two levels down)
        local elsewhere = newmock(); rawset(elsewhere, "GetParent", function() return env.UIParent end)
        -- the ground: the look's own under the window, the theme's anywhere else
        local ground = under(row); ns:Paint(ground, "SetVertexColor", "window", 0.97)
        if reads(ground) ~= "12141a" then error("the window's ground is #12141a, got " .. reads(ground)) end
        local outside = under(elsewhere); ns:Paint(outside, "SetVertexColor", "window", 0.97)
        if reads(outside) ~= hex(ns:T("window")) then error("another window keeps the theme's ground, got " .. reads(outside)) end
        local text = under(row); ns:Paint(text, "SetTextColor", "text")
        if reads(text) ~= "e9ecf3" then error("text in the window is #e9ecf3, got " .. reads(text)) end
        -- the look is looked up once per object, not on every paint
        local before = parents
        for _ = 1, 5 do ns:Paint(ground, "SetVertexColor", "window", 0.97) end
        if parents ~= before then error("painting again walks the parents again") end
        -- a frame marked later is found on the next repaint (and unmarked, lets go)
        ns:SetLook(elsewhere, "settings"); ns:Repaint()
        if reads(outside) ~= "12141a" then error("a frame marked later takes the look on the next repaint") end
        before = parents
        ns:Repaint()
        if parents ~= before then error("a repaint with no new look does not walk the parents") end
        ns:SetLook(elsewhere, nil); ns:Repaint()
        if reads(outside) ~= hex(ns:T("window")) then error("unmarked, it wears the theme again") end
        -- the accent is the theme's, live
        local acc = under(row); ns:Paint(acc, "SetVertexColor", "@accent", 1)
        local a = ns.theme.accent
        if reads(acc) ~= hex(a[1], a[2], a[3]) then error("the accent under the window is the theme's") end
        local was = reads(acc)
        ns.db.accent = "CRIMSON"; ns:ApplyAccent(); ns:Repaint()
        if reads(acc) ~= hex(ns:AccentColor("CRIMSON")) or reads(acc) == was then error("a new accent repaints at once, got " .. reads(acc)) end
        if reads(ground) ~= "12141a" or reads(text) ~= "e9ecf3" then error("nothing else in the window changes with the accent") end
        -- high contrast: black ground, white text, without a reload
        if ns:IsHighContrast() then error("Smoke is not high contrast") end
        ns.db.theme = "C_CONTRAST"; ns:Retheme()
        if not ns:IsHighContrast() then error("C_CONTRAST is high contrast") end
        if reads(ground) ~= "000000" or reads(text) ~= "ffffff" then error("high contrast: black ground and white text, got " .. reads(ground) .. " / " .. reads(text)) end
        local a2 = ns.theme.accent
        if reads(acc) ~= hex(a2[1], a2[2], a2[3]) then error("high contrast keeps the theme's accent") end
        for _, k in ipairs({ "CONTRAST", "FCONTRAST" }) do
            ns.db.theme = k
            if not ns:IsHighContrast() then error(k .. " is high contrast") end
        end
        ns.db.theme = "MIDNIGHT"; ns:Retheme()
        if reads(ground) ~= "12141a" then error("back to the calm look") end
        -- lettering: Barlow in Latin-script languages; Korean, Chinese, Russian and the reading styles keep theirs
        local fs = under(row); ns:Font(fs, 14)
        local title = under(row); ns:Font(title, 24, true)
        local out = under(elsewhere); ns:Font(out, 14)
        local function face(t) return tostring(rawget(t, "face")) end
        if not face(fs):find("Barlow%-Medium%.ttf$") then error("body text in the window is Barlow Medium, got " .. face(fs)) end
        if not face(title):find("Barlow%-SemiBold%.ttf$") then error("titles in the window are Barlow SemiBold, got " .. face(title)) end
        if face(out) ~= ns.FONT or face(out):find("Barlow") then error("other windows keep the chosen lettering, got " .. face(out)) end
        if math.abs((rawget(fs, "size") or 0) - 14 * (ns.fontScale or 1)) > 0.001 then error("the text size still applies") end
        local keepOutline = ns.db.textOutline
        ns.db.textOutline = "thick"; ns:Retheme()
        if rawget(fs, "flags") ~= "THICKOUTLINE" then error("the outline choice still applies to Barlow") end
        ns.db.textOutline = keepOutline; ns:Retheme()
        for _, code in ipairs({ "koKR", "zhCN", "ruRU" }) do
            ns.root.language = code; ns:Retheme()
            if face(fs):find("Barlow") or face(fs) ~= ns.FONT then error(code .. " keeps its own face, got " .. face(fs)) end
            if face(title) ~= ns.TITLEFONT then error(code .. " titles keep their own face") end
        end
        ns.root.language = "enUS"; ns:Retheme()
        if not face(fs):find("Barlow") then error("back in English, Barlow again") end
        for _, st in ipairs({ "DYSLEXIC", "READABLE" }) do
            ns.db.fontStyle = st; ns:Retheme()
            if face(fs):find("Barlow") or face(fs) ~= ns.FONT then error(st .. " lettering wins over Barlow, got " .. face(fs)) end
        end
        ns.db.fontStyle = "GLASS"; ns:Retheme()
        ns:ToggleConfig()
    end)
    ns.db.theme, ns.db.accent, ns.root.language, ns.db.fontStyle = keep.theme, keep.accent, keep.lang, keep.style
    ns:Retheme()
    if not ok then error(err, 0) end
end)
try("12.3 settings look: buttons and the window's corners", function()
    local keep = { theme = ns.db.theme, accent = ns.db.accent, lang = ns.root.language, style = ns.db.fontStyle, uf = ns.db.ufStyle }
    local realCF = env.CreateFrame
    local made = {}
    local function hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    -- frames that know their parent, and the textures and strings made on them
    local function Region(owner)
        local t = newmock()
        rawset(t, "GetParent", function() return owner end)
        rawset(t, "SetVertexColor", function(x, r, g, b, a) rawset(x, "rgba", { r, g, b, a or 1 }) end)
        rawset(t, "SetTexture", function(x, path) rawset(x, "tex", path) end)
        rawset(t, "SetGradient", function(x) rawset(x, "gradient", true) end)
        rawset(t, "SetFont", function(x, path) rawset(x, "face", path) end)
        rawset(t, "GetStringWidth", function() return 10 end)
        made[#made + 1] = t
        return t
    end
    local function Real(f, parent)
        rawset(f, "GetParent", function() return parent end)
        rawset(f, "CreateTexture", function(self) return Region(self) end)
        rawset(f, "CreateFontString", function(self) return Region(self) end)
        rawset(f, "SetBackdropColor", function(x, r, g, b, a) rawset(x, "bg", { r, g, b, a or 1 }) end)
        rawset(f, "GetBackdropColor", false)                 -- (left square: the plain backdrop is what is read)
        rawset(f, "GetWidth", function() return 120 end)
        return f
    end
    local ok, err = pcall(function()
        ns.db.theme, ns.db.accent, ns.root.language, ns.db.fontStyle = "MIDNIGHT", "VIOLET", "enUS", "GLASS"
        ns:Retheme()
        ns:ToggleConfig("home")
        local win = ns.configFrame
        env.CreateFrame = function(kind, name, parent, ...) return Real(realCF(kind, name, parent, ...), parent) end
        local holder = env.CreateFrame("Frame", nil, win)
        local away = env.CreateFrame("Frame", nil, env.UIParent)
        -- a button in the window is lettered in Barlow: made, given new text, repainted
        local b1 = ns:CreateButton(holder, "Run setup again", 132, 24)
        local out = ns:CreateButton(away, "Run setup again", 132, 24)
        local function face(b) return tostring(rawget(b.text, "face")) end
        if not face(b1):find("Barlow%-Medium%.ttf$") then error("a button in the window is lettered in Barlow, got " .. face(b1)) end
        if face(out) ~= ns.FONT then error("a button elsewhere keeps the theme's lettering, got " .. face(out)) end
        b1.text:SetText("Something much longer than before")
        b1.text.suiFit()                                    -- (what the SetText hook runs)
        if not face(b1):find("Barlow") then error("after SetText, still Barlow, got " .. face(b1)) end
        ns:Repaint()
        if not face(b1):find("Barlow") then error("after a repaint, still Barlow, got " .. face(b1)) end
        if face(out) ~= ns.FONT then error("after a repaint, the button elsewhere keeps the theme's lettering") end
        -- its plate: the look's, opaque, flat; the same on a Glass and a Fantasy theme
        local function plate(b) local c = rawget(b, "bg"); return hex(c) .. "/" .. tostring(c[4]) end
        if plate(b1) ~= "1e222b/1" then error("a button in the window is a flat #1e222b plate, got " .. plate(b1)) end
        if rawget(b1.plate, "gradient") then error("no lit top edge in the window") end
        local wash = rawget(b1.wash, "rgba")
        if hex(wash) ~= "262b36" or wash[4] ~= 1 then error("under the mouse a lighter plate, got " .. hex(wash) .. "/" .. tostring(wash[4])) end
        if not rawget(out.plate, "gradient") then error("a button elsewhere keeps its lit edge") end
        -- under the mouse its label is the look's text colour (#e9ecf3), not white; elsewhere white as before
        local function Hovered(b)
            rawset(b.text, "SetTextColor", function(x, r, g, bl) rawset(x, "rgb", { r, g, bl }) end)
            for _, h in ipairs(handlers) do if h.self == b and h.name == "OnEnter" then h.fn(b); break end end
            return rawget(b.text, "rgb") and hex(rawget(b.text, "rgb")) or "none"
        end
        if Hovered(b1) ~= "e9ecf3" then error("a hovered button's label in the window is #e9ecf3, got " .. Hovered(b1)) end
        if Hovered(out) ~= "ffffff" then error("a hovered button's label elsewhere stays white, got " .. Hovered(out)) end
        local glassPlate, glassWash, glassOut = plate(b1), hex(wash) .. tostring(wash[4]), plate(out)
        ns.db.theme = "WARM"; ns:Retheme()
        if ns.style ~= "FANTASY" then error("WARM is a Fantasy theme") end
        local b2 = ns:CreateButton(holder, "Discord", 96, 24)
        local w2 = rawget(b2.wash, "rgba")
        if plate(b2) ~= glassPlate or plate(b1) ~= glassPlate then error("the plate is the same on Fantasy as on Glass, got " .. plate(b2) .. " / " .. plate(b1)) end
        if hex(w2) .. tostring(w2[4]) ~= glassWash then error("the hover is the same on Fantasy as on Glass") end
        if rawget(b2.plate, "gradient") then error("no lit top edge on Fantasy either") end
        local out2 = ns:CreateButton(away, "Discord", 96, 24)
        if plate(out2) == glassOut then error("(the check needs the themes' own plates to differ)") end
        -- the window's corners: the cut, its lines in the rim color, no stars, on every family
        ns.db.ufStyle = "STARCUT"
        local was = ns.StarcutCanSlice()
        ns.StarcutCanSlice(true)
        local function Window(marked)
            local f = env.CreateFrame("Frame", nil, env.UIParent)
            if marked then ns:SetLook(f, "settings") end
            rawset(f, "GetWidth", function() return 1000 end); rawset(f, "GetHeight", function() return 680 end)
            rawset(f, "CreateMaskTexture", function() local m = newmock(); rawset(m, "SetTextureSliceMargins", function() end); return m end)
            rawset(f, "GetRegions", function() end)
            local from = #made
            ns.StarcutWindow(f)
            local lines, stars = {}, 0
            for i = from + 1, #made do
                local t = made[i]
                if rawget(t, "scCutLine") then lines[#lines + 1] = t
                elseif tostring(rawget(t, "tex")):find("\\star$") then stars = stars + 1 end
            end
            return f, lines, stars
        end
        local plain, _, plainStars = Window(false)
        if plainStars == 0 then error("(the check needs a Fantasy window elsewhere to get its stars)") end
        local look, lines, stars = Window(true)
        if rawget(look, "scCut") ~= true then error("the settings window keeps the Starcut cut") end
        if stars ~= 0 then error("no Starcut stars on the settings window, got " .. stars) end
        if #lines == 0 then error("the cut has its lines") end
        for _, l in ipairs(lines) do
            if hex(rawget(l, "rgba")) ~= "262b36" then error("the cut lines are the window's rim, got " .. hex(rawget(l, "rgba"))) end
        end
        ns:SetLook(look, nil); ns:SetLook(plain, nil)
        ns.StarcutCanSlice(true)
        if was ~= nil then ns.StarcutWindow(realCF("Frame")) end
        ns:ToggleConfig()
    end)
    env.CreateFrame = realCF
    ns.db.theme, ns.db.accent, ns.root.language, ns.db.fontStyle, ns.db.ufStyle = keep.theme, keep.accent, keep.lang, keep.style, keep.uf
    ns:Retheme()
    if ns.ApplyFrameStyle then ns:ApplyFrameStyle() end
    if not ok then error(err, 0) end
end)
try("12.3 reload: every reload button hands the click to the game", function()
    -- the game refuses a reload asked for by add-on code, even inside a click: a reload button's
    -- OnClick is the game's own ReloadUI itself, and the add-on's saving goes in PreClick
    local function Last(b, name)
        local fn
        for i = 1, #handlers do local h = handlers[i]; if h.self == b and h.name == name then fn = h.fn end end
        return fn
    end
    ns:ShowSetup(); ns:HideSetup()
    if ns.safeBanner then ns.safeBanner:Hide() else ns:ShowSafeBanner():Hide() end
    ns:ToggleConfig("profiles"); ns:ToggleConfig("profiles")
    local list = {}
    for b in pairs(ns.reloadButtons) do list[#list + 1] = b end
    if #list < #ns.languages + 3 then error("too few reload buttons: " .. #list) end
    for _, b in ipairs(list) do
        if Last(b, "OnClick") ~= env.ReloadUI then error("a reload button's OnClick is not the game's own ReloadUI") end
        if type(Last(b, "PreClick")) ~= "function" then error("a reload button has no PreClick") end
        if type(Last(b, "PostClick")) ~= "function" then error("a reload button lost its click sound") end
    end
    -- the setup's Finish & reload: the choices are kept before the game reloads
    local fin = ns.setupFrame and ns.setupFrame.finish
    if not (fin and ns.reloadButtons[fin]) then error("the setup's Finish & reload is not a reload button") end
    -- nothing may be hidden in a reload button's PreClick (the button or its window): a button hidden
    -- before its OnClick might not get one, and the reload would fail as before
    local hidden = {}
    local realCall = mockmt.__call
    local function Watch() mockmt.__call = function(fn, obj, ...) if type(obj) == "table" and rawget(obj, "Hide") == fn then hidden[#hidden + 1] = obj end return newmock() end end
    local function Unwatch() mockmt.__call = realCall end
    local keep = { done = ns.db.setupDone, just = ns.root.setupJustFinished, role = ns.db.role }
    ns.db.setupDone, ns.root.setupJustFinished = nil, nil
    local before = reloadCount
    Watch()
    local okF, errF = pcall(Last(fin, "PreClick"), fin, "LeftButton")
    Unwatch()
    if not okF then error(errF, 0) end
    if #hidden > 0 then error("Finish & reload's PreClick hides something before the reload") end
    if ns.db.setupDone ~= true or ns.root.setupJustFinished ~= true then error("Finish & reload should keep the setup as done before the reload") end
    if reloadCount ~= before then error("the PreClick must not reload by itself") end
    if Last(fin, "OnClick") ~= env.ReloadUI then error("after its PreClick, Finish's click should still be the game's ReloadUI") end
    ns.db.setupDone, ns.root.setupJustFinished, ns.db.role = keep.done, keep.just, keep.role
    -- the other buttons: each does its own saving in PreClick (language, profile, safe mode)
    local spy = { lang = 0, profile = 0, safe = 0 }
    local real = { lang = ns.SetupPickLanguage, profile = ns.UseProfile, safe = ns.SetSafeMode }
    ns.SetupPickLanguage = function() spy.lang = spy.lang + 1; return true end
    ns.UseProfile = function() spy.profile = spy.profile + 1; return true end
    ns.SetSafeMode = function() spy.safe = spy.safe + 1; return true end
    Watch()
    local okP, errP = pcall(function() for _, b in ipairs(list) do if b ~= fin then Last(b, "PreClick")(b, "LeftButton") end end end)
    Unwatch()
    ns.SetupPickLanguage, ns.UseProfile, ns.SetSafeMode = real.lang, real.profile, real.safe
    if not okP then error(errP, 0) end
    if #hidden > 0 then error("a reload button's PreClick hides something before the reload (" .. #hidden .. ")") end
    if spy.lang ~= #ns.languages then error("each setup language button should pick its language first: " .. spy.lang) end
    if spy.safe < 1 then error("Leave safe mode should switch safe mode off first") end
    if spy.profile < 1 then error("a profile's Use should switch the profile first") end
    if reloadCount ~= before then error("no PreClick may reload by itself") end
    -- Reset positions: the first click only asks; the confirming one keeps the change and is the
    -- game's reload; left alone for 4 seconds it goes back to asking
    runTimers()                                                        -- (any earlier ask has gone back)
    local reset
    for _, e in ipairs(ns.optionIndex) do if e.label == "Reset positions" then reset = e.frame end end
    if not reset then error("the Reset positions button was not found") end
    local arm = Last(reset, "OnClick")
    if type(arm) ~= "function" or arm == env.ReloadUI or ns.reloadButtons[reset] then
        error("Reset positions should start by asking, not reloading (" .. type(arm) .. ", " .. tostring(arm == env.ReloadUI) .. ", " .. tostring(ns.reloadButtons[reset]) .. ", armed " .. tostring(reset.armed) .. ")")
    end
    arm(reset)
    if reloadCount ~= before or not reset.armed then error("the first click on Reset positions should only arm it") end
    if not ns.reloadButtons[reset] or Last(reset, "OnClick") ~= env.ReloadUI then error("once armed, Reset positions' click should be the game's ReloadUI") end
    local keepPos, keepScale = ns.db.pos, ns.db.scale
    ns.db.pos, ns.db.scale = { probe = { 1, 2 } }, { probe = 2 }
    Last(reset, "PreClick")(reset, "LeftButton")
    if next(ns.db.pos) ~= nil or next(ns.db.scale) ~= nil then error("the confirming click should clear the positions before the reload") end
    if reloadCount ~= before or Last(reset, "OnClick") ~= env.ReloadUI then error("the confirming click's reload should be the game's own, in OnClick") end
    ns.db.pos, ns.db.scale = keepPos, keepScale
    arm(reset); runTimers()                                            -- (asked, then left alone)
    if reset.armed or ns.reloadButtons[reset] or Last(reset, "OnClick") ~= arm then error("after 4 seconds Reset positions should go back to asking") end
    arm(reset)
    if not (reset.armed and ns.reloadButtons[reset]) then error("after the disarm the next click should arm it again") end
    runTimers()
    -- /rl: the game's own /reload handler where there is one, otherwise ours
    local shortCommands
    for _, m in ipairs(ns.modules) do if m.key == "shortCommands" then shortCommands = m.fn end end
    if not shortCommands then error("the short commands module is missing") end
    local SL = env.SlashCmdList
    local keepRL, keepReload, keepKey = SL.FANTASYGLASSUIRL, SL.RELOAD, env.SLASH_FANTASYGLASSUIRL1
    local own = function() end
    SL.RELOAD = own; SL.FANTASYGLASSUIRL = nil
    shortCommands()
    if SL.FANTASYGLASSUIRL ~= own then error("/rl should be the game's own /reload handler when it has one") end
    SL.RELOAD = nil; SL.FANTASYGLASSUIRL = nil
    shortCommands()
    local rl = SL.FANTASYGLASSUIRL
    if type(rl) ~= "function" or rl == own then error("without the game's handler /rl should still be made") end
    rl("")
    if reloadCount ~= before + 1 then error("without the game's handler /rl should call ReloadUI") end
    before = reloadCount
    SL.FANTASYGLASSUIRL, SL.RELOAD, env.SLASH_FANTASYGLASSUIRL1 = keepRL, keepReload, keepKey
    -- a PreClick that says no: that click stops before the reload
    local b = ns:CreateButton(env.UIParent, "Probe", 80, 24)
    ns:ReloadButton(b, function() return false end)
    local cleared = false
    rawset(b, "SetScript", function(_, name, fn) if name == "OnClick" and fn == nil then cleared = true end end)
    Last(b, "PreClick")(b)
    if not cleared then error("a PreClick that says no should take the reload off that click") end
    ns.reloadButtons[b] = nil
    -- where a refused action came from: past Blocked.lua's handler and ns:Guard's wrapper
    local guardLine = "[Interface/AddOns/FantasyGlassUI/Skin.lua]:306: in function <Interface/AddOns/FantasyGlassUI/Skin.lua:299>"
    local probe = "[C]: in function 'pcall'\n[Interface/AddOns/FantasyGlassUI/Skin.lua]:322: in function <Interface/AddOns/FantasyGlassUI/Skin.lua:322>\n"
               .. "[C]: in function 'pcall'\n" .. guardLine .. "\n[Interface/AddOns/FantasyGlassUI/Skin.lua]:322: in main chunk"
    if ns.GuardFrameOf(probe) ~= "Skin.lua:299" then error("ns:Guard's wrapper was not found in a stack: " .. tostring(ns.GuardFrameOf(probe))) end
    local stack = "[Interface/AddOns/FantasyGlassUI/Blocked.lua]:120: in function <Interface/AddOns/FantasyGlassUI/Blocked.lua:118>\n"
               .. "[C]: in function 'pcall'\n" .. guardLine .. "\n[C]: in function 'Reload'\n"
               .. "[Interface/AddOns/Blizzard_SharedXML/InterfaceUtil.lua]:30: in function 'ReloadUI'\n"
               .. "[Interface/AddOns/FantasyGlassUI_Options/Setup.lua]:710: in function <Interface/AddOns/FantasyGlassUI_Options/Setup.lua:699>"
    local keepAt = ns.guardAt
    for _, at in ipairs({ "Skin.lua:299", false }) do                 -- (the wrapper known, and not known)
        ns.guardAt = at or nil
        local where = ns.BlockedWhere(stack)
        if where ~= "options: Setup.lua:710" then error("a refused reload should be put on Setup.lua:710, not " .. tostring(where)) end
    end
    ns.guardAt = keepAt
    -- a refused reload: the player is told the game's own /reload finishes it
    local keepB, keepSaved = ns.blocked, ns.root.blockedNow
    ns.blocked = { total = 0, list = {}, byKey = {} }
    local n = #printed
    ns:NoteBlocked("ADDON_ACTION_BLOCKED", "FantasyGlassUI_Options", "Reload()", stack)
    local said = false
    for i = n + 1, #printed do if tostring(printed[i]):find("/reload", 1, true) then said = true end end
    if not said then error("a refused reload should say to type /reload") end
    n = #printed
    ns:NoteBlocked("ADDON_ACTION_BLOCKED", "FantasyGlassUI", "Frame:Show()", stack)
    for i = n + 1, #printed do if tostring(printed[i]):find("/reload", 1, true) then error("only a refused reload should mention /reload") end end
    ns.blocked, ns.root.blockedNow = keepB, keepSaved
end)
try("12.3 settings look: rows and switches", function()
    local keep = { theme = ns.db.theme, accent = ns.db.accent, lang = ns.root.language, scale = ns.fontScale, big = ns.db.bigControls }
    local realCF = env.CreateFrame
    local function hex(c) return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
    local O = ns.optUI
    local function Fn(b, name)
        local f = b:GetScript(name)
        if type(f) ~= "function" then for _, h in ipairs(handlers) do if h.self == b and h.name == name then f = h.fn end end end
        return f
    end
    local function Press(b) local f = Fn(b, "OnClick"); if f then f(b) end end
    local ok, err = pcall(function()
        ns.db.theme, ns.db.accent, ns.root.language, ns.db.bigControls = "MIDNIGHT", "VIOLET", "enUS", false
        ns.fontScale = 1
        ns:Retheme()
        ns:ToggleConfig("combat:Alerts and warnings")
        local page = ns.featuresPage
        if not (O.current and O.current.id == "combat:Alerts and warnings") then error("Combat > Alerts and warnings is open") end
        if #(page.shownKeys or {}) < 3 then error("the section shows its settings") end
        -- every row is laid out one under the next: record where and how tall
        local at, tall = {}, {}
        local function Watch(row)
            rawset(row, "SetPoint", function(r, point, rel, _, _, y) if point == "TOPLEFT" then at[r] = y end end)
            rawset(row, "SetHeight", function(r, h) tall[r] = h end)
            rawset(row, "SetAlpha", function(r, a) rawset(r, "alpha", a) end)
        end
        for _, row in pairs(page.rows) do Watch(row) end
        local function Layout()
            page.Show(page.section)
            local list, last = {}, nil
            for _, name in ipairs(page.shownKeys) do
                local row = page.rows[name]
                if last then
                    local want = at[last] - tall[last]
                    if math.abs(at[row] - want) > 0.01 then error(name .. " overlaps or leaves a gap after the row above: " .. at[row] .. " vs " .. want) end
                end
                if tall[row] < 56 then error(name .. " is at least 56 high, got " .. tall[row]) end
                list[#list + 1] = row
                last = row
            end
            return list
        end
        local rows = Layout()
        -- each switch row: a title, a description, a switch showing the saved setting
        local first
        for _, name in ipairs(page.shownKeys) do
            local row = page.rows[name]
            if row.switch and row.switch.key == name then
                first = first or name
                if not (row.title and row.desc) then error(name .. " has a title and a description") end
                if row.switch.checked ~= (ns.db[name] and true or false) then error(name .. ": the switch shows the saved setting") end
            end
        end
        if not first then error("the section has switch rows") end
        -- clicking flips it, the tooltip shows
        local row, before = page.rows[first], ns.db[first]
        Press(row.switch)
        if ns.db[first] == before or row.switch.checked ~= (ns.db[first] and true or false) then error("clicking the switch flips the setting") end
        local enter = Fn(row, "OnEnter")
        if type(enter) ~= "function" then error("the row has its tooltip") end
        local realGT, tipShown = env.GameTooltip, false
        local gt = newmock()
        rawset(gt, "Show", function() tipShown = true end)
        env.GameTooltip = gt
        local okTip, errTip = pcall(enter, row)
        env.GameTooltip = realGT
        if not okTip then error(errTip, 0) end
        if not tipShown then error("hovering the row shows its tooltip") end
        Press(row.switch)
        if ns.db[first] ~= before then error("clicking again puts it back") end
        -- a dependent setting is dimmed while its parent is off
        local child, parent
        for key in pairs(page.boxes) do
            if ns.featureNeeds[key] and page.boxes[key].row then child, parent = key, ns.featureNeeds[key]; break end
        end
        if not child then error("(the check needs a setting that depends on another)") end
        local was = ns.db[parent]
        ns.db[parent] = false; page.Dim()
        if rawget(page.rows[child], "alpha") ~= 0.5 then error("a dependent setting is dimmed while its parent is off") end
        ns.db[parent] = true; page.Dim()
        if rawget(page.rows[child], "alpha") ~= 1 then error("and not when it is on") end
        ns.db[parent] = was
        -- the All / On / Off filter
        local all = #page.shownKeys
        local function Count(want)
            local n = 0
            for _, name in ipairs(page.shownKeys) do
                local r = page.rows[name]
                if r.switch and r.switch.key == name then
                    n = n + 1
                    if want ~= nil and (ns.db[name] and true or false) ~= want then error(name .. " is in the wrong filter") end
                end
            end
            return n
        end
        Press(page.filterButtons.on)
        local nOn = Count(true)
        Press(page.filterButtons.off)
        local nOff = Count(false)
        Press(page.filterButtons.all)
        if #page.shownKeys ~= all then error("All shows every row again") end
        if nOn == 0 or nOff == 0 then error("(the check needs both on and off settings here) " .. nOn .. "/" .. nOff) end
        -- a long description grows the row at a bigger text size and in German, and nothing overlaps
        local name = first
        local r = page.rows[name]
        rawset(r.desc, "GetText", function() return string.rep("Eine lange Beschreibung auf Deutsch. ", 9) end)
        ns.root.language = "deDE"
        ns.fontScale = 1
        Layout()
        local h1 = tall[r]
        ns.fontScale = 1.3
        Layout()
        local h2 = tall[r]
        if h2 <= h1 then error("at text size 1.3 the long row is taller: " .. h1 .. " -> " .. h2) end
        -- slider and button rows grow and wrap too (a long German description at text size 1.3)
        ns:ToggleConfig("access:Seeing")
        if not (O.current and O.current.id == "access:Seeing") then error("Accessibility > Seeing is open") end
        for _, row in pairs(page.rows) do Watch(row) end
        local sliderName, buttonName
        for _, n in ipairs(page.section.rows) do
            local r = page.rows[n]
            if rawget(r, "slider") and not sliderName then sliderName = n end
            if rawget(r, "button") and not buttonName then buttonName = n end
        end
        if not (sliderName and buttonName) then error("(the check needs a slider row and a button row here)") end
        ns.root.language, ns.fontScale = "deDE", 1
        Layout()
        local sh1, bh1 = tall[page.rows[sliderName]], tall[page.rows[buttonName]]
        for _, n in ipairs({ sliderName, buttonName }) do
            rawset(page.rows[n].desc, "GetText", function() return string.rep("Eine sehr lange Beschreibung auf Deutsch. ", 12) end)
        end
        Layout()
        local sh2, bh2 = tall[page.rows[sliderName]], tall[page.rows[buttonName]]
        if sh2 <= sh1 then error("a long slider description makes its row taller: " .. sh1 .. " -> " .. sh2) end
        if bh2 <= bh1 then error("a long button description makes its row taller: " .. bh1 .. " -> " .. bh2) end
        ns.fontScale = 1.3
        Layout()
        if tall[page.rows[sliderName]] <= sh2 or tall[page.rows[buttonName]] <= bh2 then error("and taller still at text size 1.3") end
        ns.fontScale = 1
        -- a section from each of the other pages sits on cards of its own
        ns.root.language = "enUS"
        local hosts = { ["combat:Alerts and warnings"] = "combat", ["layout:Moving and scale"] = "layout", ["frames:Nameplates"] = "bars", ["tools:Tools"] = "tools" }
        for _, id in ipairs({ "combat:Alerts and warnings", "layout:Moving and scale", "frames:Nameplates", "tools:Tools" }) do
            ns:ToggleConfig(id)
            if not (O.current and O.current.id == id) then error(id .. " opens") end
            if (page.blockUsed or 0) < 1 or not page.blockCards[1] then error(id .. " shows its settings on a card") end
            -- the page's content frame sits 18 inside the card at each side and 14 below its top
            local inner = O.pages[hosts[id]].area
            local cx, cy, ix, iy, iw
            rawset(page.blockCards[1], "SetPoint", function(_, pt, _, _, x, y) if pt == "TOPLEFT" then cx, cy = x, y end end)
            rawset(inner, "SetPoint", function(_, pt, _, _, x, y) if pt == "TOPLEFT" then ix, iy = x, y end end)
            rawset(inner, "SetWidth", function(_, w) iw = w end)
            ns:ToggleConfig(id); ns:ToggleConfig(id)
            rawset(page.blockCards[1], "SetPoint", nil); rawset(inner, "SetPoint", nil); rawset(inner, "SetWidth", nil)
            if not ix then error(id .. ": the content frame was placed") end
            if ix - cx < 18 then error(id .. ": 18 inside the card at the left, got " .. (ix - cx)) end
            if cy - iy < 14 then error(id .. ": 14 inside the card at the top, got " .. (cy - iy)) end
            local cardW = O.LEGACY_W + 2 * O.BLOCK_PAD                   -- (the card a page with no width of its own is laid out for)
            if iw and ix + iw > cardW - 18 then error(id .. ": 18 inside the card at the right: " .. (ix + iw) .. " of " .. cardW) end
            if iw and iw < O.LEGACY_W then error(id .. ": the content gets the 736 it is laid out for, got " .. iw) end
        end
        ns:ToggleConfig("access:Hearing")
        if page.blockUsed ~= 0 then error("a section with no block has no block card") end
        ns:ToggleConfig("combat:Alerts and warnings")
        -- the reset button is in the footer
        if not O.resetButton or not O.resetButton:IsShown() then error("Reset <category> is in the window's footer") end
        -- the switch: 38 x 22 with a 16 knob, accent with a dark knob when on, grey when off, only in the window
        ns.fontScale = 1
        local sizes, colors = {}, {}
        env.CreateFrame = function(kind, nm, parent, ...)
            local f = realCF(kind, nm, parent, ...)
            rawset(f, "GetParent", function() return parent end)
            rawset(f, "SetSize", function(x, w, h) rawset(x, "sz", { w, h }) end)
            rawset(f, "SetBackdropColor", function(x, a, b, c, d) rawset(x, "bg", { a, b, c, d or 1 }) end)
            rawset(f, "CreateTexture", function(self)
                local t = newmock()
                rawset(t, "GetParent", function() return self end)
                rawset(t, "SetSize", function(x, w, h) rawset(x, "sz", { w, h }) end)
                rawset(t, "SetVertexColor", function(x, a, b, c, d) rawset(x, "rgba", { a, b, c, d or 1 }) end)
                return t
            end)
            return f
        end
        local holder = env.CreateFrame("Frame", nil, O.frame)
        local away = env.CreateFrame("Frame", nil, env.UIParent)
        local inWin = ns:CreateCheckbox(holder, "x", true)
        local outWin = ns:CreateCheckbox(away, "x", true)
        if rawget(inWin.box, "sz")[1] ~= 38 or rawget(inWin.box, "sz")[2] ~= 22 then error("the switch track is 38 x 22") end
        if rawget(inWin.tick, "sz")[1] ~= 16 then error("the knob is 16") end
        if rawget(outWin.box, "sz")[1] ~= 28 then error("a switch outside the window keeps its size") end
        local function Track(c) local t = c.fill and rawget(c.fill, "rgba") or rawget(c.box, "bg"); return hex(t) end
        local function Knob(c) return hex(rawget(c.tick, "rgba")) end
        local acc = { ns:Role("@accent") }
        if Track(inWin) ~= hex(acc) then error("on: the track is the accent, got " .. Track(inWin)) end
        if Knob(inWin) ~= "12141a" then error("on: a dark knob, got " .. Knob(inWin)) end
        inWin:SetChecked(false)
        if Track(inWin) ~= "2c313c" then error("off: the track is #2c313c, got " .. Track(inWin)) end
        if Knob(inWin) ~= "9aa3b5" then error("off: a grey knob, got " .. Knob(inWin)) end
        -- a labelled switch keeps its text inside its own width: track 38, gap 12
        local function LabelWidth(c)
            local got
            rawset(c.label, "SetWidth", function(_, w) got = w end)
            local f = Fn(c, "OnSizeChanged")
            f(c, 300)
            return got
        end
        local lw = LabelWidth(inWin)
        if not lw or 38 + 12 + lw > 300 then error("a labelled switch's text ends inside its row: " .. tostring(lw)) end
        local lo = LabelWidth(outWin)
        if not lo or 28 + 8 + lo > 300 then error("outside the window too: " .. tostring(lo)) end
        -- a section label is upper-case in English only; every other language keeps the label's own case
        local function Label(text)
            local box = env.CreateFrame("Frame", nil, O.frame)
            local fs
            rawset(box, "CreateFontString", function() fs = newmock(); rawset(fs, "SetText", function(x, t) rawset(x, "txt", t) end); return fs end)
            O.Header(box, text, 0, 0)
            return rawget(fs, "txt")
        end
        ns.root.language = "enUS"
        if Label("Alerts and warnings") ~= "ALERTS AND WARNINGS" then error("English labels are upper-case") end
        ns.root.language = "deDE"
        if Label("Größe ändern") ~= "Größe ändern" then error("German labels keep their own case") end
        if Label("Alerts and warnings") ~= "Alerts and warnings" then error("(and a plain German label too)") end
    end)
    env.CreateFrame = realCF
    pcall(function()
        for _, row in pairs(ns.featuresPage.rows) do
            for _, k in ipairs({ "SetPoint", "SetHeight", "SetAlpha" }) do rawset(row, k, nil) end
            if row.desc then rawset(row.desc, "GetText", nil) end
        end
    end)
    ns.root.language, ns.fontScale, ns.db.bigControls = keep.lang, keep.scale, keep.big
    ns.db.theme, ns.db.accent = keep.theme, keep.accent
    ns:Retheme()
    pcall(ns.ToggleConfig, ns)
    if not ok then error(err, 0) end
end)
try("12.3 settings look: sidebar and Home", function()
    local keep = { scale = ns.fontScale, theme = ns.db.theme, lang = ns.root.language, uf = ns.db.ufStyle, sec = ns.root.optionsSection, mode = ns.root.settingsMode }
    local keepSwitch = {}
    for _, k in ipairs(ns.homeQuick) do keepSwitch[k] = ns.db[k] end
    local realCF, realTime, realClass = env.CreateFrame, env.GetGameTime, env.UnitClass
    local made = {}
    local function Region(owner)
        local t = newmock()
        rawset(t, "GetParent", function() return owner end)
        rawset(t, "SetText", function(x, v) rawset(x, "text", v) end)
        rawset(t, "GetText", function(x) return rawget(x, "text") end)
        rawset(t, "GetStringWidth", function() return 10 end)
        rawset(t, "GetStringHeight", function(x) return rawget(x, "fakeH") or 16 end)
        rawset(t, "SetWordWrap", function(x, v) rawset(x, "wrap", v) end)
        rawset(t, "SetMaxLines", function(x, v) rawset(x, "maxLines", v) end)
        rawset(t, "SetTexture", function(x, v) rawset(x, "tex", v) end)
        made[#made + 1] = t
        return t
    end
    local function Real(f, parent)
        rawset(f, "GetParent", function() return parent end)
        rawset(f, "SetParent", function(_, p) parent = p end)
        local shown = true
        rawset(f, "Show", function() shown = true end)
        rawset(f, "Hide", function() shown = false end)
        rawset(f, "SetShown", function(_, v) shown = v and true or false end)
        rawset(f, "IsShown", function() return shown end)
        local height
        rawset(f, "SetSize", function(_, _, h) height = h end)
        rawset(f, "SetHeight", function(_, h) height = h end)
        rawset(f, "GetHeight", function() return height or 0 end)
        rawset(f, "CreateTexture", function(self) return Region(self) end)
        rawset(f, "CreateFontString", function(self) return Region(self) end)
        rawset(f, "SetChecked", nil)
        local scripts = {}
        rawset(f, "SetScript", function(_, name, fn) scripts[name] = fn end)
        rawset(f, "HookScript", function(_, name, fn) local old = scripts[name]; scripts[name] = old and function(...) old(...); fn(...) end or fn end)
        rawset(f, "GetScript", function(_, name) return scripts[name] end)
        return f
    end
    local ok, err = pcall(function()
        ns.db.theme, ns.root.language = "MIDNIGHT", "enUS"
        ns.root.settingsMode = "all"
        ns:Retheme()
        ns:ToggleConfig()                                       -- (shut)
        local O = ns.optUI
        O.frame = nil
        env.CreateFrame = function(kind, name, parent, ...) return Real(realCF(kind, name, parent, ...), parent) end
        env.GetGameTime = function() return 9, 30 end
        env.UnitClass = function() return "Rogue", "ROGUE" end
        ns:ToggleConfig("home")
        if not O.current or not O.current.home then error("the window opens on Home") end
        local page = O.home
        -- the greeting, by the game's clock, with the class name
        local function title() return rawget(page.title, "text") end
        if title() ~= "Good morning, Rogue" then error("morning greeting, got " .. tostring(title())) end
        env.GetGameTime = function() return 11, 59 end; page.Refresh()
        if title() ~= "Good morning, Rogue" then error("11:59 is still morning") end
        env.GetGameTime = function() return 12, 0 end; page.Refresh()
        if title() ~= "Good afternoon, Rogue" then error("noon is afternoon, got " .. tostring(title())) end
        env.GetGameTime = function() return 17, 59 end; page.Refresh()
        if title() ~= "Good afternoon, Rogue" then error("17:59 is still afternoon") end
        env.GetGameTime = function() return 18, 0 end; page.Refresh()
        if title() ~= "Good evening, Rogue" then error("18:00 is evening, got " .. tostring(title())) end
        env.UnitClass = function() return "Death Knight", "DEATHKNIGHT" end; page.Refresh()
        if title() ~= "Good evening, Death Knight" then error("the class name as the game gives it, got " .. tostring(title())) end
        -- the line under it: theme, frames, counts
        local on, total = ns:CountFeatures()
        local want = ns:ThemeName(ns.db.theme, "plain") .. " · Starcut frames · " .. total .. " settings, " .. (total - on) .. " switched off"
        ns.db.ufStyle = "STARCUT"; page.Refresh()
        if rawget(page.intro, "text") ~= want then error("the theme line, wanted '" .. want .. "' got '" .. tostring(rawget(page.intro, "text")) .. "'") end
        ns.db.ufStyle = "CLASSIC"; page.Refresh()
        if not tostring(rawget(page.intro, "text")):find("· Classic frames ·", 1, true) then error("Classic frames, got " .. tostring(rawget(page.intro, "text"))) end
        ns.db.ufStyle = "STARCUT"
        -- a switch changed elsewhere moves the counts
        local flip = nil
        for key in pairs(ns.defaults) do if type(ns.defaults[key]) == "boolean" and ns.featureDesc[key] and not ns:FeatureHidden(key) and not page.quick[key] then flip = key; break end end
        local before = ns.db[flip]
        ns.db[flip] = not before; page.Refresh()
        local on2, total2 = ns:CountFeatures()
        if on2 == on or not tostring(rawget(page.intro, "text")):find(" " .. (total2 - on2) .. " switched off", 1, true) then error("the counts follow the switches") end
        ns.db[flip] = before; page.Refresh()
        -- one card per quick switch, and its switch flips the setting
        local cards = 0
        for _, key in ipairs(ns.homeQuick) do
            if not ns:FeatureHidden(key) and O.RowLabel(key) then
                cards = cards + 1
                local cb = page.quick[key]
                if not cb then error("a card for " .. key) end
                local card
                for _, c in ipairs(page.quickCards) do if c.key == key then card = c end end
                if not card or rawget(card.name, "text") ~= ns:Tr(O.RowLabel(key)) then error(key .. "'s card is titled with its name") end
                if (rawget(card.hint, "text") or "") == "" then error(key .. "'s card has a line on what it does") end
                local was = ns.db[key] and true or false
                cb:GetScript("OnClick")(cb)
                if (ns.db[key] and true or false) == was then error(key .. "'s switch flips the setting") end
                if cb.checked ~= ns.db[key] then error(key .. "'s switch shows the setting") end
                cb:GetScript("OnClick")(cb)
                if (ns.db[key] and true or false) ~= was then error(key .. "'s switch flips back") end
            end
        end
        if cards ~= #page.quickCards or cards < 3 then error("a card for each quick switch, got " .. cards) end
        -- the titles in German, a long one at fontScale 1.3: translated, wrapped, nothing cut off, no overlap
        ns.root.language = "deDE"; ns:LoadLocale()
        local keepScale = ns.fontScale
        ns.fontScale = 1.3
        for _, c in ipairs(page.quickCards) do rawset(c.name, "fakeH", 44) end      -- (two lines at that size)
        page.Refresh()
        local sawGerman = false
        for _, c in ipairs(page.quickCards) do
            local de = ns:Tr(O.RowLabel(c.key))
            if rawget(c.name, "text") ~= de then error(c.key .. "'s title is the German text, got " .. tostring(rawget(c.name, "text"))) end
            if de ~= O.RowLabel(c.key) then sawGerman = true end
            if rawget(c.name, "wrap") ~= true or rawget(c.name, "maxLines") ~= 2 then error(c.key .. "'s title wraps to two lines") end
            if c:GetHeight() < 13 + 44 + 4 + 16 + 14 then error(c.key .. "'s card grows to hold a two-line title, got " .. c:GetHeight()) end
        end
        if not sawGerman then error("at least one quick card has a German title") end
        for r, row in ipairs(page.quickRows) do
            local tallest = 0
            for i, c in ipairs(page.quickCards) do if math.floor((i - 1) / 3) + 1 == r then tallest = math.max(tallest, c:GetHeight()) end end
            if row.height ~= tallest then error("row " .. r .. " is as tall as its tallest card") end
            local nextRow = page.quickRows[r + 1]
            if nextRow and nextRow.top > row.top - row.height then error("row " .. (r + 1) .. " overlaps row " .. r) end
        end
        local lastRow = page.quickRows[#page.quickRows]
        if page.contentHeight < -lastRow.top + lastRow.height then error("the page is as tall as its cards") end
        for _, c in ipairs(page.quickCards) do rawset(c.name, "fakeH", nil) end
        ns.fontScale = keepScale
        ns.root.language = "enUS"; ns:LoadLocale()
        page.Refresh()
        -- "Changed lately" lives in the Undo button's tooltip: the last five changes, most recent first
        local savedChanges = {}
        for i, ch in ipairs(O.changes) do savedChanges[i] = ch end
        for i = #O.changes, 1, -1 do O.changes[i] = nil end
        local keys = { "bagWindow", "damageMeter", "autoSell", "autoRepair", "questTracker", "plateQuest", "bagWindow" }
        for i, key in ipairs(keys) do O.changes[#O.changes + 1] = { key = key, old = (i % 2 == 0), new = (i % 2 == 1) } end
        local lines = O.LatelyLines()
        if #lines ~= 5 then error("the last five changes, got " .. #lines) end
        for n = 1, 5 do
            local ch = O.changes[#O.changes + 1 - n]
            local want = ns:Tr(O.ChangeLabel(ch.key)) .. ": " .. O.ChangeValue(ch.key, ch.new)
            if lines[n] ~= want then error("change " .. n .. " newest first: wanted '" .. want .. "' got '" .. tostring(lines[n]) .. "'") end
        end
        local realTip, shown = env.GameTooltip, {}
        local tip = newmock()
        rawset(tip, "AddLine", function(_, text) shown[#shown + 1] = tostring(text) end)
        rawset(tip, "SetOwner", function() end)
        env.GameTooltip = tip
        O.frame.undoButton:GetScript("OnEnter")(O.frame.undoButton)
        env.GameTooltip = realTip
        local joined = "\n" .. table.concat(shown, "\n") .. "\n"
        if not joined:find("\nChanged lately\n", 1, true) then error("the Undo tooltip has a Changed lately heading, got " .. joined) end
        for n = 1, 5 do if not joined:find("\n" .. lines[n] .. "\n", 1, true) then error("the Undo tooltip lists change " .. n) end end
        for i = #O.changes, 1, -1 do O.changes[i] = nil end
        for i, ch in ipairs(savedChanges) do O.changes[i] = ch end
        -- "New in 12.x": the current what's new lines, a diamond each
        local entry = ns.whatsNew[1]
        for _, e in ipairs(ns.whatsNew) do if tostring(e[1]):match("^(%d+%.%d+)") == tostring(ns.version):match("^(%d+%.%d+)") then entry = e; break end end
        local ver = entry[1]:match("^(%d+%.%d+)")
        if rawget(page.newTitle, "text") ~= "New in " .. ver then error("the card is titled New in " .. ver .. ", got " .. tostring(rawget(page.newTitle, "text"))) end
        if #page.newLines ~= math.min(#entry[2], 5) or #page.newDots ~= #page.newLines then error("a line and a diamond for each of the what's new lines") end
        for i, fs in ipairs(page.newLines) do
            local first = entry[2][i]:match("^(.-[%.!?])%s") or entry[2][i]
            if rawget(fs, "text") ~= first then error("what's new line " .. i .. ": " .. tostring(rawget(fs, "text"))) end
        end
        if not page.askCard or ns.toolsPage.askFrame:GetParent() ~= page.askCard then error("the guide's question box sits in the Ask the guide card") end
        if ns.toolsPage.suggestFrame:GetParent() ~= page.askCard then error("the class suggestions sit in the same card") end
        -- the sidebar: no counts; only the picked row is selected
        local function rows()
            local list = {}
            for _, b in ipairs(O.catButtons) do if b:IsShown() and rawget(b, "cat") then list[#list + 1] = b end end
            for _, b in ipairs(O.secButtons) do if b:IsShown() and rawget(b, "sec") then list[#list + 1] = b end end
            return list
        end
        local sideKids = {}
        for _, b in ipairs(O.catButtons) do sideKids[b] = true end
        for _, b in ipairs(O.secButtons) do sideKids[b] = true end
        for _, t in ipairs(made) do
            local owner = t:GetParent()
            local text = rawget(t, "text")
            if sideKids[owner] and type(text) == "string" and text:find("^%d+/%d+$") then error("the sidebar shows no counts, found " .. text) end
        end
        for _, b in ipairs(rows()) do if rawget(b, "count") or rawget(b, "bar") then error("no count and no accent bar on a sidebar row") end end
        local function picked()
            local list = {}
            for _, b in ipairs(rows()) do if rawget(b, "picked") then list[#list + 1] = b end end
            return list
        end
        local p = picked()
        if #p ~= 1 or not rawget(p[1], "cat") or not p[1].cat.home then error("on Home only Home is selected, got " .. #p) end
        O.Open("items:Vendors")
        p = picked()
        if #p ~= 1 or rawget(p[1], "sec") ~= O.current or p[1].sec.id ~= "items:Vendors" then error("opening a section selects only its row, got " .. #p) end
        local items = 0
        for _, b in ipairs(rows()) do if rawget(b, "sec") then items = items + 1 end end
        if items ~= #ns:SettingsCategory("items").sections then error("the open category's sections are indented under it, got " .. items .. " of " .. #O.secButtons .. " buttons, " .. #ns:SettingsCategory("items").sections .. " sections") end
        for _, b in ipairs(rows()) do
            local h = b:GetHeight()
            if rawget(b, "sec") and h ~= 32 then error("a section row is 32 px, got " .. tostring(h)) end
            if rawget(b, "cat") and h ~= 36 then error("a category row is 36 px, got " .. tostring(h) .. " " .. tostring(rawget(b, "GetHeight")) .. " " .. tostring(rawget(b, "cat").id)) end
        end
        O.Open("home")
        p = picked()
        if #p ~= 1 or not rawget(p[1], "cat") or not p[1].cat.home then error("back on Home, only Home is selected, got " .. #p .. " " .. tostring(rawget(p[1], "cat") and p[1].cat.id) .. " " .. tostring(rawget(p[2], "cat") and p[2].cat.id) .. tostring(p[2] and rawget(p[2], "sec") and p[2].sec.id)) end
        for _, b in ipairs(O.secButtons) do if b:IsShown() then error("Home has no sections under it") end end
        -- Simple / All options stay at the top of the sidebar
        local modes = O.frame.modeButtons
        if modes.simple:GetParent() ~= O.side or modes.all:GetParent() ~= O.side then error("the mode buttons are at the top of the sidebar") end
        ns:ToggleConfig()
    end)
    env.CreateFrame, env.GetGameTime, env.UnitClass = realCF, realTime, realClass
    ns.db.theme, ns.root.language, ns.db.ufStyle, ns.root.optionsSection, ns.root.settingsMode = keep.theme, keep.lang, keep.uf, keep.sec, keep.mode
    for k, v in pairs(keepSwitch) do ns.db[k] = v end
    ns.fontScale = keep.scale
    ns:LoadLocale()
    ns:Retheme()
    if not ok then error(err, 0) end
end)
try("12.3 settings look: themes page", function()
    local keep = { theme = ns.db.theme, accent = ns.db.accent }
    local ok, err = pcall(function()
        for name in pairs(ns.db.customThemes) do ns:DeleteCustomTheme(name) end
        ns.db.theme, ns.db.accent = "MIDNIGHT", "VIOLET"
        ns:Retheme()
        ns:ToggleConfig("look")
        local page = ns.lookPage
        local pk = page and page.themePicker
        if not pk then error("the Themes page has no picker") end
        page.Refresh()
        -- the family control: three families (a fourth only once you have your own themes), the current one first selected
        local shownFamilies = 0
        for _, fam in ipairs({ "GLASS", "FANTASY", "CELESTIAL" }) do if pk.familyButtons[fam] then shownFamilies = shownFamilies + 1 end end
        if shownFamilies ~= 3 then error("the family control lists three families, got " .. shownFamilies) end
        if pk.family ~= "GLASS" then error("MIDNIGHT is Glass, so Glass is the family shown, got " .. tostring(pk.family)) end
        -- Glass shows every Glass theme as a tile
        local want = 0
        for _, key in ipairs(ns.themeOrder) do if ns.themes[key].style == "GLASS" and not ns.themes[key].custom then want = want + 1 end end
        local shown, tileOf = 0, {}
        for i, key in ipairs(pk.list) do
            local b = pk.tiles[i]
            if not (b and b.key == key and b.swatch and b.swatch.tile) then error("a tile for " .. tostring(key)) end
            shown = shown + 1
            tileOf[key] = b
        end
        if shown ~= want or want < 10 then error("Glass shows " .. shown .. " of " .. want .. " Glass themes") end
        -- the tile of the theme in use is the ringed one, and the preview names it
        local function ringed()
            local list = {}
            for i, key in ipairs(pk.list) do if pk.tiles[i].picked then list[#list + 1] = key end end
            return list
        end
        local r = ringed()
        if #r ~= 1 or r[1] ~= "MIDNIGHT" then error("the theme in use is the one ringed, got " .. table.concat(r, ",")) end
        local famName = ns:Tr("Glass") .. ": " .. ns:ThemeName("MIDNIGHT", "short")
        if pk.nameText ~= famName then error("the preview names '" .. famName .. "', got " .. tostring(pk.nameText)) end
        if pk.descText ~= ns:Tr("See-through panes with soft shadows and a bright top edge.") then error("the preview gives the family's line") end
        -- clicking a tile previews: the name changes, the theme does not
        local before = ns.db.theme
        tileOf.SMOKE:suiClick()
        if ns.db.theme ~= before then error("a click on a tile must not change the theme") end
        if pk.picked ~= "SMOKE" then error("the click picks the tile") end
        if pk.nameText ~= ns:Tr("Glass") .. ": " .. ns:ThemeName("SMOKE", "short") then error("the preview names the picked theme, got " .. tostring(pk.nameText)) end
        r = ringed()
        if #r ~= 1 or r[1] ~= "SMOKE" then error("the picked tile is ringed, got " .. table.concat(r, ",")) end
        -- the preview carries the picked theme's own colours, not the window's
        local c = ns:ThemeColors("SMOKE")
        local function hex(t) return string.format("%02x%02x%02x", math.floor(t[1] * 255 + 0.5), math.floor(t[2] * 255 + 0.5), math.floor(t[3] * 255 + 0.5)) end
        local sw = tileOf.SMOKE.swatch
        if sw.key ~= "SMOKE" or hex(sw.panel) ~= hex(c.bg) or hex(sw.rim) ~= hex(c.border) then error("the tile carries the theme's own panel and rim colours") end
        if pk.sample.key ~= "SMOKE" or hex(pk.sample.panel) ~= hex(c.bg) or hex(pk.sample.rim) ~= hex(c.border) then error("the sample frame is in the picked theme's colours") end
        -- "Use this theme" applies it, as a click on a theme did before
        pk.Apply(pk.picked)
        if ns.db.theme ~= "SMOKE" then error("Use this theme puts the picked theme on, got " .. tostring(ns.db.theme)) end
        r = ringed()
        if #r ~= 1 or r[1] ~= "SMOKE" then error("after using it, its tile is the ringed one") end
        -- between families the reload note still comes
        local noted = false
        local realRetheme = ns.Retheme
        ns.Retheme = function(self) noted = true; return realRetheme(self) end
        pk.family = "CELESTIAL"; pk.Draw()
        pk.Pick(pk.list[1])
        pk.Apply(pk.picked)
        ns.Retheme = realRetheme
        if not noted then error("applying a theme goes through Retheme (it says when a reload is needed)") end
        if ns.themes[ns.db.theme].style ~= "CELESTIAL" then error("the Celestial theme is on") end
        -- your own theme and the class-colour themes are tiles too
        local mineKey = ns:SaveCustomTheme("Tile Test", { panel = { 0.1, 0.2, 0.3 }, rim = { 0.5, 0.5, 0.5 }, accent = { 1, 0.5, 0 }, style = "FANTASY" })
        page.Refresh()
        pk.family = "MINE"; pk.Draw()
        if pk.list[1] ~= mineKey or not pk.familyButtons.MINE then error("your own theme is a tile under Your themes") end
        ns:DeleteCustomTheme("Tile Test")
        page.Refresh()
        local classTile = false
        for _, fam in ipairs({ "GLASS", "FANTASY", "CELESTIAL" }) do
            pk.family = fam; pk.Draw()
            for _, k in ipairs(pk.list) do if k == "CLASS" or k == "GCLASS" or k == "CCLASS" then classTile = true end end
        end
        if not classTile then error("the class-colour themes are tiles") end
        for _, key in ipairs({ "CONTRAST", "FCONTRAST", "C_CONTRAST" }) do
            local found
            for _, fam in ipairs({ "GLASS", "FANTASY", "CELESTIAL" }) do
                pk.family = fam; pk.Draw()
                for _, k in ipairs(pk.list) do if k == key then found = true end end
            end
            if not found then error("the high-contrast theme " .. key .. " is a tile in its family") end
        end
        -- (the grid's reflow at the window's real widths: "12.3 settings look: pages follow the window's width")
        pk.family = "GLASS"; pk.Draw()
        pk.Layout(736)
        ns:ToggleConfig()
    end)
    for name in pairs(ns.db.customThemes) do ns:DeleteCustomTheme(name) end
    ns.db.theme, ns.db.accent = keep.theme, keep.accent
    ns:Retheme()
    if not ok then error(err, 0) end
end)
try("12.3 settings look: pages follow the window's width", function()
    local keep = { accent = ns.db.accent, theme = ns.db.theme, lang = ns.root.language, size = ns.root.optionsSize, sec = ns.root.optionsSection, mode = ns.root.settingsMode, scale = ns.fontScale, dbScale = ns.db.fontScale }
    local realCF, realHook = env.CreateFrame, env.hooksecurefunc
    -- stand-in frames that keep their width, height, anchors, scripts and text, so a layout can be measured
    local function Adopt(parent, f)                         -- (each frame and region is listed under its parent, so a block's parts can be walked)
        local pst = type(parent) == "table" and rawget(parent, "geo")
        if pst then pst.kids[#pst.kids + 1] = f end
    end
    local function Disown(parent, f)
        local pst = type(parent) == "table" and rawget(parent, "geo")
        if not pst then return end
        for i = #pst.kids, 1, -1 do if pst.kids[i] == f then table.remove(pst.kids, i) end end
    end
    local function Geo(f, parent)
        local st = { w = nil, h = nil, pts = {}, shown = true, scripts = {}, kids = {} }
        rawset(f, "geo", st)
        Adopt(parent, f)
        rawset(f, "GetParent", function() return parent end)
        rawset(f, "SetParent", function(_, p) Disown(parent, f); parent = p; Adopt(p, f) end)
        rawset(f, "SetSize", function(_, w, h) st.w, st.h = w, h end)
        rawset(f, "SetWidth", function(_, w) st.w = w end)
        rawset(f, "SetHeight", function(_, h) st.h = h end)
        rawset(f, "GetWidth", function() return st.w or 0 end)
        rawset(f, "GetHeight", function() return st.h or 0 end)
        rawset(f, "ClearAllPoints", function() st.pts = {}; st.all = nil end)
        rawset(f, "SetPoint", function(_, point, a, b, c, d)
            local rel, rp, x, y = a, point, b, c
            if type(a) ~= "table" then rel, x, y = parent, a, b end
            if type(a) == "string" then rel, rp, x, y = parent, a, b, c end
            if type(b) == "string" then rp, x, y = b, c, d end
            st.pts[point] = { rel = rel, rp = rp, x = tonumber(x) or 0, y = tonumber(y) or 0 }
        end)
        rawset(f, "SetAllPoints", function(_, to) st.pts = {}; st.all = (type(to) == "table") and to or parent end)
        rawset(f, "SetScrollChild", function(_, c) local cst = type(c) == "table" and rawget(c, "geo"); if cst then cst.scrollParent = f end end)
        rawset(f, "Show", function() st.shown = true end)
        rawset(f, "Hide", function() st.shown = false end)
        rawset(f, "SetShown", function(_, v) st.shown = v and true or false end)
        rawset(f, "IsShown", function() return st.shown end)
        rawset(f, "SetScript", function(_, name, fn) st.scripts[name] = fn end)
        rawset(f, "HookScript", function(_, name, fn) local old = st.scripts[name]; st.scripts[name] = old and function(...) old(...); fn(...) end or fn end)
        rawset(f, "GetScript", function(_, name) return st.scripts[name] end)
        rawset(f, "SetResizeBounds", function(_, ...) st.bounds = { ... } end)
        rawset(f, "EnableMouse", function(_, v) st.mouse = v and true or false end)
        return f
    end
    local function Region(owner)
        local t = Geo(newmock(), owner)
        local st = rawget(t, "geo")
        rawset(t, "SetText", function(_, v) st.text = v end)
        rawset(t, "GetText", function() return st.text end)
        rawset(t, "SetFont", function(_, _, size) st.size = tonumber(size) end)
        rawset(t, "SetTextColor", function(_, r, g, b) st.color = { r, g, b } end)
        local function CharW() return (st.size or 11) * 0.55 end         -- (a letter: about half its size wide, 6 px at 11)
        local function Plain() return (tostring(st.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
        rawset(t, "GetStringWidth", function() return #Plain() * CharW() end)
        rawset(t, "GetStringHeight", function()                  -- (as many lines as the text takes at its width)
            local text = Plain()
            if text == "" then return 0 end
            local w = (st.w and st.w > 0) and st.w or 400
            return math.max(1, math.ceil(#text * CharW() / w)) * (st.size or 11) * 1.25
        end)
        return t
    end
    local function W(f) return rawget(f, "geo").w or 0 end
    local function Pt(f, p) return rawget(f, "geo").pts[p] end
    -- Where a frame or region lies across, in `root`'s coordinates: its anchors followed to `root`
    -- (nil where they lead elsewhere, or it has none). A text with no width set is as wide as its text.
    local function Span(f, root, memo)
        local m = memo[f]
        if m ~= nil then if m then return m[1], m[2] end; return nil end
        memo[f] = false                                      -- (a loop of anchors places nothing)
        local st = type(f) == "table" and rawget(f, "geo")
        if not st then return nil end
        if f == root then memo[f] = { 0, st.w or 0 }; return 0, st.w or 0 end
        local L, R, C
        local function X(rel, rp)
            local l, r = Span(rel, root, memo)
            if not l then return nil end
            if rp:find("LEFT") then return l elseif rp:find("RIGHT") then return r end
            return (l + r) / 2
        end
        if st.all then L, R = Span(st.all, root, memo) end
        for point, p in pairs(st.pts) do
            local x = X(p.rel, p.rp or point)
            if x then
                x = x + p.x
                if point:find("LEFT") then L = x elseif point:find("RIGHT") then R = x else C = x end
            else
                return nil
            end
        end
        if not (L or R or C) and st.scrollParent then L = Span(st.scrollParent, root, memo) end
        if not (L or R or C) then return nil end
        local w = st.w or 0
        if w <= 0 and rawget(f, "GetStringWidth") then w = f:GetStringWidth() end
        if not (L and R) then
            if L then R = L + w elseif R then L = R - w else L, R = C - w / 2, C + w / 2 end
        end
        memo[f] = { L, R }
        return L, R
    end
    -- every part of a frame that shows, the frame included
    local function Shown(f, list, seen)
        local st = type(f) == "table" and rawget(f, "geo")
        if not st or not st.shown or seen[f] then return list end
        seen[f] = true
        list[#list + 1] = f
        for _, k in ipairs(st.kids) do Shown(k, list, seen) end
        return list
    end
    local ok, err = pcall(function()
        ns.db.theme, ns.root.language, ns.root.optionsSize, ns.root.settingsMode = "MIDNIGHT", "enUS", nil, "all"
        ns:Retheme()
        local O = ns.optUI
        if O.frame and O.frame:IsShown() then ns:ToggleConfig() end
        O.frame = nil
        env.hooksecurefunc = function(a, b, c)                   -- (a frame's own method hooked as the game does: a switch's label follows its width)
            if type(a) == "table" and type(b) == "string" and type(c) == "function" and type(rawget(a, b)) == "function" then
                local was = rawget(a, b)
                rawset(a, b, function(...) local r = table.pack(was(...)); c(...); return table.unpack(r, 1, r.n) end)
                return
            end
            return realHook(a, b, c)
        end
        env.CreateFrame = function(kind, name, parent, ...)
            local f = Geo(realCF(kind, name, parent, ...), parent)
            rawset(f, "CreateFontString", function(self) return Region(self) end)
            rawset(f, "CreateTexture", function(self) return Region(self) end)
            return f
        end
        ns:ToggleConfig("home")
        -- the window: it starts, and goes no narrower than, the width at which a block laid out for 736
        -- fits inside its card (its padding at both sides, the card's gap, the sidebar and the margins)
        local MIN = 736 + 2 * 18 + 12 + (14 + 216 + 14) + 16 + 10
        local bounds = rawget(O.frame, "geo").bounds
        if MIN ~= 1054 or not bounds or bounds[1] ~= MIN or O.MIN_W ~= MIN or bounds[3] ~= 1600 then error("the window's width goes from " .. MIN .. " to 1600, got " .. tostring(bounds and bounds[1]) .. " to " .. tostring(bounds and bounds[3])) end
        if W(O.frame) ~= MIN or O.W ~= MIN then error("the window starts " .. MIN .. " wide, got " .. W(O.frame)) end
        if O.PageWidth(MIN) - 12 - 2 * 18 ~= 736 then error("at its least width a block's card is 736 inside, got " .. (O.PageWidth(MIN) - 48)) end
        if O.PageWidth(900) ~= O.PageWidth(MIN) then error("the pages are never laid out narrower than the window's least width") end
        local function Size(w)
            O.frame:SetSize(w, 680)
            local f = O.frame:GetScript("OnSizeChanged")
            if type(f) ~= "function" then error("the window follows its size") end
            f(O.frame, w, 680)
            runTimers()
            if O.pageWidth ~= O.PageWidth(w) or W(O.sections) ~= O.pageWidth or W(O.home) ~= O.pageWidth then error("at " .. w .. " the pages are as wide as the window gives them") end
            return O.pageWidth
        end
        local function Inside(what, left, width, pw)
            if left < 0 or left + width > pw + 0.5 then error(what .. " leaves the page: " .. left .. " + " .. width .. " of " .. pw) end
        end
        -- every section's blocks, at the window's width: each shown part of what is lent to the page lies
        -- inside its card's inner edge (the walk follows the real frames and their anchors)
        local function LentInside(edge)
            local bad, most, seen = {}, 0, 0
            for _, cat in ipairs(ns.settingsCategories) do
                for _, sec in ipairs(cat.sections or {}) do
                    if sec.blocks and #sec.blocks > 0 then
                        O.Open(sec.id)
                        local page = O.sections
                        local pw = W(page)
                        local left, right = 18, edge or (pw - 12 - 18)
                        local memo = {}
                        for _, f in ipairs(page.lentFrames or {}) do
                            for _, part in ipairs(Shown(f, {}, {})) do
                                local l, r = Span(part, page, memo)
                                if l and r > l then
                                    seen = seen + 1
                                    if r - left > most then most = r - left end
                                    if l < left - 0.5 or r > right + 0.5 then
                                        local st = rawget(part, "geo")
                                        bad[#bad + 1] = sec.id .. ": " .. (st.text and ("'" .. tostring(st.text) .. "'") or "a part") .. " at " .. l .. ".." .. r
                                    end
                                end
                            end
                        end
                    end
                end
            end
            return bad, most, seen
        end
        for _, w in ipairs({ MIN, 1600 }) do                      -- (at the least width, which is where it starts, and the widest)
            Size(w)
            local bad, most, seen = LentInside()
            if seen < 1000 then error("the walk found the blocks' parts at " .. w .. ": " .. seen) end
            if #bad > 0 then error(#bad .. " parts of the blocks leave their card at " .. w .. ":\n" .. table.concat(bad, "\n", 1, math.min(#bad, 20))) end
            if w == MIN and most ~= 736 then error("the widest block is laid out for 736, got " .. most) end
        end
        -- and the walk does see a part that is cut: the window made narrower than it may be
        do
            O.sections:SetWidth(O.PageWidth(MIN) - 60)
            local bad = LentInside()
            O.sections:SetWidth(O.pageWidth)
            if #bad == 0 then error("the walk finds a block's part past its card") end
        end
        local cols = {}
        for _, w in ipairs({ MIN, 1300 }) do
            -- Home: the quick cards, New and Ask the guide inside the page
            O.Open("home")
            local pw = Size(w)
            local home = O.home
            if home.width ~= pw then error("Home is laid out for the page's width at " .. w) end
            for _, c in ipairs(home.quickCards) do
                local at = Pt(c, "TOPLEFT")
                Inside("a quick card at " .. w, at.x, W(c), pw)
                -- pointing at the card, not only its switch, shows what it does
                if rawget(c, "geo").mouse ~= true or type(c:GetScript("OnEnter")) ~= "function" then error("a quick card takes the mouse and has a tooltip: " .. tostring(c.label)) end
            end
            Inside("the New card at " .. w, 0, W(home.newCard), pw)
            Inside("the Ask card at " .. w, 0, W(home.askCard), pw)
            local T = ns.toolsPage
            -- the guide's answer stops short of "Show me" (it was ~10 px under it)
            local af = W(T.askFrame)
            if 16 + af > W(home.askCard) then error("the question box is inside its card at " .. w) end
            if 2 + W(T.answer) + 12 > af - W(T.showButton) then error("at " .. w .. " the answer runs under Show me: " .. W(T.answer) .. " of " .. af) end
            if Pt(T.showButton, "TOPRIGHT").rel ~= T.askFrame then error("Show me sits at the box's right") end
            -- the Ask card is as tall as what is in it: a long answer makes it taller
            T.answer:SetText("short")
            home.Layout()
            local short = home.askCardHeight
            T.answer:SetText(string.rep("A long answer from the guide. ", 30))
            home.Layout()
            local long = home.askCardHeight
            if not (long > short) or rawget(home.askCard, "geo").h ~= long then error("the Ask card grows with its answer: " .. tostring(short) .. " -> " .. tostring(long)) end
            if long == 290 or short == 290 then error("the Ask card is not a fixed 290") end
            T.answer:SetText("")
            home.Layout()
            local empty = home.askCardHeight
            T.Ask("how do I move the action bars")                   -- (asking lays Home out again for the answer)
            if not (home.askCardHeight > empty) then error("the Ask card follows a new answer: " .. empty .. " -> " .. home.askCardHeight) end
            T.answer:SetText("")
            home.Layout()
            cols["home" .. w] = home.cols
            -- a section: the card, the rows and the blocks inside the page
            O.Open("frames:Your frames")
            local page = O.sections
            if W(page) ~= pw then error("the section page is as wide as the window gives it") end
            local rowW = pw - 12
            local c = Pt(page.card, "TOPRIGHT")
            if not page.card:IsShown() or Pt(page.card, "TOPLEFT").x ~= 0 or not c or c.rel ~= page or c.x ~= -12 then error("the rows' card spans the page at " .. w) end
            local n = 0
            for _, name in ipairs(page.shownKeys) do
                local row = page.rows[name]
                n = n + 1
                local r = Pt(row, "RIGHT")
                if Pt(row, "TOPLEFT").x ~= 0 or not r or r.x ~= -12 then error(name .. "'s row spans the card at " .. w) end
                for _, part in ipairs({ "title", "desc" }) do
                    local fs = row[part]
                    if fs and rawget(fs, "geo") and W(fs) > 0 then
                        local at = Pt(fs, "TOPLEFT")
                        Inside(name .. "'s " .. part .. " at " .. w, at and at.x or 0, W(fs), rowW - ((part == "title" or row.switch and row.switch.key == name) and (row.reserve or 0) or 0))
                    end
                end
            end
            if n == 0 then error("rows shown") end
            local blocks = 0
            for i = 1, page.blockUsed do
                local bc = page.blockCards[i]
                local r = Pt(bc, "TOPRIGHT")
                if not r or r.x ~= -12 then error("a block's card spans the page at " .. w) end
                blocks = blocks + 1
            end
            if blocks == 0 or page.blockInner.left + page.blockInner.width > rowW - 18 + 0.5 then error("a block's content sits inside its card at " .. w) end
            if page.sampleButton:IsShown() and page.introWidth + 170 + 24 > rowW then error("the line under the title runs under Show sample frames at " .. w) end
            -- the footer: its two ends do not meet
            local foot = O.footer
            if not O.resetButton:IsShown() or not foot or foot.left + foot.right + 24 > w then error("the footer fits at " .. w .. ": " .. tostring(foot and foot.left) .. " + " .. tostring(foot and foot.right)) end
            -- the Themes section: the grid's columns, and no tile under the preview column
            O.Open("look:Themes")
            local pk = O.pages.look.sheet.themePicker
            local inner = page.blockInner.width
            if pk.width ~= inner then error("the theme grid is laid out for its card's width at " .. w .. ": " .. tostring(pk.width) .. " vs " .. inner) end
            cols[w] = pk.cols
            if pk.gridW + 8 + 8 > pk.previewX then error("at " .. w .. " the grid reaches the preview column: " .. pk.gridW .. " vs " .. pk.previewX) end
            if pk.previewX + pk.pvW > pk.width or W(pk.pv) ~= pk.pvW or W(pk.use) ~= pk.pvW then error("the preview column fits at " .. w) end
            for i = 1, #pk.list do
                local b = pk.tiles[i]
                if b.px + W(b) > pk.gridW then error("a tile sticks out of the grid at " .. w) end
                if W(pk.grid) + 8 > pk.previewX then error("the grid's scroll track reaches the preview at " .. w) end
            end
        end
        if cols[MIN] ~= 4 or cols[1300] ~= 7 then error("the theme grid has 4 columns at " .. MIN .. " and more as it widens (7 at 1300), got " .. tostring(cols[MIN]) .. " and " .. tostring(cols[1300])) end
        if cols["home" .. MIN] ~= 3 or cols.home1300 ~= 3 then error("Home's quick cards: 3 to a row") end
        if ns.homeCards ~= nil then error("the old Home cards list is gone (Home shows the quick switches)") end
        Size(1600)
        O.Open("look:Themes")
        if O.pages.look.sheet.themePicker.cols ~= 10 then error("at 1600 the theme grid has 10 columns, got " .. tostring(O.pages.look.sheet.themePicker.cols)) end

        -- the footer at the least width: its two ends do not meet, with a reload waiting too; made
        -- narrower than the window can be, the version gives way first, then "Reset ..." is cut to "Reset"
        Size(MIN)
        O.Open("frames:Your frames")
        local rb = O.resetButton
        local function Label() return rawget(rb.text, "geo").text end
        local foot = O.footer
        if foot.left + foot.right + 24 > MIN then error("the footer fits at " .. MIN .. ": " .. foot.left .. " + " .. foot.right) end
        if foot.stage < 3 and Label() ~= rb.suiFull then error("at " .. MIN .. " the Reset label is whole, got " .. tostring(Label())) end
        if not tostring(rb.suiFull):find("Frames and bars", 1, true) then error("Reset names its category: " .. tostring(rb.suiFull)) end
        O.NeedReload("testA"); O.NeedReload("testB")
        foot = O.footer
        if foot.left + foot.right + 24 > MIN then error("with the reload note the footer still fits at " .. MIN .. ": " .. foot.left .. " + " .. foot.right) end
        if O.frame.version:IsShown() ~= (foot.stage == 0) then error("the version shows only when everything else has room") end
        O.LayoutFooter(760)
        if O.footer.stage < 3 or O.frame.version:IsShown() or Label() ~= ns:Tr("Reset") then error("in a footer too narrow the version goes, then Reset is cut short: stage " .. O.footer.stage .. ", " .. tostring(Label())) end
        O.LayoutFooter()
        if O.footer.width ~= MIN then error("the footer is laid out for the window again") end
        -- arming "Reset ..." ("Click to confirm") and its running out lay the footer out again
        local whole = rb:GetWidth()
        O.footer = nil
        rb:GetScript("OnClick")(rb)
        if not rb.suiArmed or not tostring(Label()):find(ns:Tr("Click to confirm"), 1, true) then error("one click arms Reset: " .. tostring(Label())) end
        if not O.footer or O.footer.left + O.footer.right + 24 > MIN then error("the footer is laid out again for the armed label") end
        if rb:GetWidth() == whole then error("the armed Reset button is fitted to its new label") end
        O.footer = nil
        runTimers()                                              -- (it runs out)
        if rb.suiArmed or not O.footer or Label() ~= rb.suiFull and Label() ~= ns:Tr("Reset") then error("Reset disarms and the footer is laid out again: " .. tostring(Label())) end

        -- a tile being previewed stays when the window is resized or the page refreshed; "Use this theme" wears it
        O.Open("look:Themes")
        local pk = O.pages.look.sheet.themePicker
        local other
        for _, key in ipairs(pk.list) do if key ~= ns.db.theme then other = key; break end end
        pk.Pick(other)
        Size(1300)
        if pk.picked ~= other then error("a resize keeps the previewed tile, got " .. tostring(pk.picked)) end
        if O.RefreshAll then O.RefreshAll() end
        if pk.picked ~= other or pk.nameText == nil or not pk.nameText:find(ns:ThemeName(other, "short"), 1, true) then error("a refresh keeps the previewed tile, got " .. tostring(pk.picked)) end
        pk.use:GetScript("OnClick")(pk.use)
        if ns.db.theme ~= other or pk.picked ~= other then error("Use this theme wears the previewed one") end
        Size(MIN)
        -- its label: dark on a light accent, white on a dark one, after hovering it and after the
        -- accent is changed from somewhere else (a repaint puts no button colour back over it)
        local light, dark, most, least = nil, nil, 0, 1
        for _, key in ipairs(ns.accentOrder) do                  -- (the lightest accent and the darkest)
            local r, g, b = ns:AccentColor(key)
            local lum = r * 0.299 + g * 0.587 + b * 0.114
            if lum > most then light, most = key, lum end
            if lum < least then dark, least = key, lum end
        end
        if not (most > 0.55 and least < 0.55) then error("(the check needs a light accent and a dark one: " .. most .. ", " .. least .. ")") end
        local function UseColor() return rawget(pk.use.text, "geo").color or {} end
        ns.db.accent = light
        ns:Retheme()
        if (UseColor()[1] or 1) > 0.2 then error("on a light accent (" .. tostring(light) .. ") the label is dark") end
        pk.use:GetScript("OnEnter")(pk.use)
        pk.use:GetScript("OnLeave")(pk.use)
        ns:Repaint()
        if (UseColor()[1] or 1) > 0.2 then error("after a hover and a repaint the label is still dark, got " .. tostring(UseColor()[1])) end
        ns.db.accent = dark
        ns:Retheme()
        if UseColor()[1] ~= 1 then error("on a dark accent (" .. tostring(dark) .. ") the label is white") end

        -- a long section title wraps clear of the All / On / Off filter, and what is under it moves down
        -- (French, lettering at 130%), at the window's least width (where it starts) and wider
        ns:SetLanguage("frFR")
        ns.db.fontScale = 130
        ns:Retheme()
        local queues
        for _, cat in ipairs(ns.settingsCategories) do
            for _, sec in ipairs(cat.sections or {}) do if sec.title == "Queues and battlegrounds" then queues = sec end end
        end
        for _, w in ipairs({ MIN, 1300 }) do
            Size(w)
            O.Open(queues.id)
            local page = O.sections
            local hd = page.heading
            local hst = rawget(hd, "geo")
            if hst.text ~= "Files d'attente et champs de bataille" or math.abs((hst.size or 0) - 24 * 1.3) > 0.01 then error("the French title at 130%: " .. tostring(hst.text) .. " " .. tostring(hst.size)) end
            if not page.filterButtons.all:IsShown() then error("the section has the filter") end
            local memo = {}
            local fl = Span(page.filterButtons.off, page, memo)
            local fr = select(2, Span(page.filterButtons.all, page, memo))
            local hl, hr = Span(hd, page, memo)
            if not (fl and hl) or fr > W(page) - 12 + 0.5 then error("the filter and title are placed") end
            if hr > fl - 8 then error("at " .. w .. " the title runs into the filter: " .. hr .. " vs " .. fl) end
            if page.newTag:IsShown() then
                local _, tr = Span(page.newTag, page, memo)
                if tr > fl - 4 then error("the NEW tag runs into the filter at " .. w) end
            end
            local natural = #hst.text * hst.size * 0.55
            if w == MIN and natural <= page.headWidth then error("the test's title is long enough to wrap at " .. w) end
            local lines = math.ceil(natural / page.headWidth)
            if math.abs(hd:GetStringHeight() - page.headHeight) > 0.5 or (lines > 1 and page.headHeight < lines * hst.size) then error("the title's height is what it wraps to") end
            local introTop = Pt(page.intro, "TOPLEFT").y
            if -introTop < 18 + page.headHeight then error("at " .. w .. " the line under the title starts under it: " .. introTop .. " vs " .. page.headHeight) end
            local cardTop = Pt(page.card, "TOPLEFT").y
            if cardTop > introTop - page.intro:GetStringHeight() then error("the card starts under the line under the title at " .. w) end
        end
        -- and on a section with no switches (no filter) but the sample frames button, a long title
        -- stops short of that button (still French at 130%, at the least width)
        Size(MIN)
        -- (every section of Frames and bars has switches now: one is given none for the check)
        local plain = ns:SettingsSection("frames:Nameplates")
        local rows = plain.rows
        plain.rows = {}
        local title = plain.title
        plain.title = "Files d'attente et champs de bataille et cadres de raid"
        local okT, errT = pcall(function()
            O.Open(plain.id)
            local page = O.sections
            if page.filterButtons.all:IsShown() or not page.sampleButton:IsShown() then error("(the section shows the sample frames button and no filter)") end
            local memo = {}
            local sl = Span(page.sampleButton, page, memo)
            local _, hr = Span(page.heading, page, memo)
            local hst = rawget(page.heading, "geo")
            if #hst.text * hst.size * 0.55 <= page.headWidth then error("the long title wraps") end
            if not (sl and hr) or hr > sl - 8 then error("a long title runs under Show sample frames: " .. tostring(hr) .. " vs " .. tostring(sl)) end
        end)
        plain.title, plain.rows = title, rows
        if not okT then error(errT, 0) end
        -- Home's section labels: in capitals in English only, as the section pages' labels
        ns:ToggleConfig()
        O.frame = nil
        ns:ToggleConfig("home")
        local fr = ns:Tr("Quick switches")
        local found
        for _, part in ipairs(Shown(O.home, {}, {})) do
            local t = rawget(part, "geo").text
            if t == fr then found = true end
            if t == fr:upper() and fr ~= fr:upper() then error("a French Home label is upper-cased: " .. t) end
        end
        if fr == "Quick switches" or not found then error("Home's Quick switches label in French: " .. tostring(fr)) end
        if O.LabelCase("Quick switches") ~= "Quick switches" then error("labels keep their case outside English") end
        ns:SetLanguage("enUS")
        if O.LabelCase("Quick switches") ~= "QUICK SWITCHES" then error("English labels are in capitals") end
        ns:ToggleConfig()
    end)
    env.CreateFrame, env.hooksecurefunc = realCF, realHook
    ns.db.theme, ns.root.language, ns.root.optionsSize, ns.root.optionsSection, ns.root.settingsMode, ns.fontScale = keep.theme, keep.lang, keep.size, keep.sec, keep.mode, keep.scale
    ns.db.fontScale, ns.db.accent = keep.dbScale, keep.accent
    pcall(ns.LoadLocale, ns)
    ns:Retheme()
    if ns.optUI.frame and ns.optUI.frame:IsShown() then ns:ToggleConfig() end
    if not ok then error(err, 0) end
end)
-- gold tests seams: begin
try("gold seams: ideas, jobs and ranking", function()
    local keep = { unlocked = ns.GuideUnlocked, combat = env.InCombatLockdown, clock = env.debugprofilestop, secret = ns.IsSecret,
        errors = ns.errors, weights = ns.root.goldWeights, chars = ns.root.goldChars, vendor = ns.root.goldVendor,
        entry = ns.PriceEntry, info = ns.GetItemInfo, today = ns.Today, travel = ns.GoldTravel, map = env.C_Map, sources = nil }
    local ok, err = pcall(function()
        if type(ns.GoldIdeaValid) ~= "function" then error("ns.GoldIdeaValid is nil") end
        keep.sources = ns.GoldSources()
        for key in pairs(keep.sources) do ns.GoldRegister(key, nil) end
        ns.GuideUnlocked = function() return true end
        ns.errors = {}
        fireEvent("PLAYER_REGEN_ENABLED")
        local today = 20261125
        ns.Today = function() return today end
        local function Idea(t)
            local i = { kind = "sell", ease = 50, safety = 50, basis = "prices", where = "window", oneOff = false }
            for k, v in pairs(t) do i[k] = v end
            return i
        end
        local function PerHour(id, ph, ease, safety) return Idea({ id = id, title = id, kind = "farm", basis = "guess", perHour = ph, ease = ease, safety = safety }) end
        local function OneOff(id, total, minutes) return Idea({ id = id, title = id, oneOff = true, total = total, minutes = minutes, ease = 90, safety = 75 }) end
        -- validation
        local V = ns.GoldIdeaValid
        if not V(PerHour("v:p", 5000, 30, 40)) then error("a full per-hour idea is valid: " .. tostring(select(2, V(PerHour("v:p", 5000, 30, 40))))) end
        if not V(OneOff("v:o", 3000, 5)) then error("a full one-off is valid: " .. tostring(select(2, V(OneOff("v:o", 3000, 5))))) end
        local hidden = {}
        ns.IsSecret = function(self, v) if rawequal(v, hidden) then return true end return keep.secret(self, v) end
        local nan = 0 / 0
        local bad = {
            { "no title", (function() local i = PerHour("v:a", 5000, 30, 40); i.title = nil; return i end)() },
            { "NaN", PerHour("v:b", nan, 30, 40) },
            { "math.huge", PerHour("v:c", math.huge, 30, 40) },
            { "negative", OneOff("v:d", -5, 5) },
            { "ease 120", PerHour("v:e", 5000, 120, 40) },
            { "unknown kind", (function() local i = PerHour("v:f", 5000, 30, 40); i.kind = "rob"; return i end)() },
            { "no minutes", OneOff("v:g", 3000, nil) },
            { "secret total", OneOff("v:h", hidden, 5) },
        }
        for _, b in ipairs(bad) do
            local good, why = V(b[2])
            if good or type(why) ~= "string" or why == "" then error("rejected, with a reason: " .. b[1]) end
        end
        if select(2, V(OneOff("v:h", hidden, 5))):find("secret", 1, true) == nil then error("a hidden total is turned away as hidden") end
        ns.IsSecret = keep.secret
        -- registry: bad ideas dropped and counted, an erroring source leaves the others alone
        local ctx = ns.GoldContext("window")
        if type(ctx) ~= "table" or ctx.where ~= "window" or ctx.today ~= today or type(ctx.charKey) ~= "string" then error("the context") end
        ns.GoldRegister("t:a", function(c, add)
            if c.where ~= "window" then error("the source gets the context") end
            add(OneOff("t:g1", 1000, 2)); add(OneOff("t:g2", 2000, 2)); add(OneOff("t:g3", 3000, 2))
            add({ title = "bad" }); add(PerHour("t:bad", nan, 10, 10))
        end)
        local ideas = ns.GoldCollectNow(ctx)
        if #ideas ~= 3 or ns.goldDropped ~= 2 then error("3 good ideas, 2 dropped: " .. #ideas .. ", " .. tostring(ns.goldDropped)) end
        ns.GoldRegister("t:b", function(c, add) add(OneOff("t:b1", 5000, 2)); error("boom") end)
        ideas = ns.GoldCollectNow(ctx)
        ns.GoldCollectNow(ctx)
        local said = 0
        for _, line in ipairs(ns.errors) do if tostring(line):sub(1, 6) == "Gold: " then said = said + 1 end end
        if #ideas ~= 3 or said ~= 1 then error("a source's error drops its ideas only, said once: " .. #ideas .. " ideas, " .. said .. " lines") end
        ns.GoldRegister("t:b", nil)
        if ns.GoldSources()["t:b"] ~= nil or ns.GoldSources()["t:a"] == nil then error("a source is taken away") end
        ns.GoldRegister("t:a", nil)
        -- jobs: sliced on the clock, never in a fight
        local t = 0
        env.debugprofilestop = function() t = t + 0.01; return t end
        local at, doneCalls, got = 0, 0, nil
        ns.GoldRegister("t:loop", function(c, add) for n = 1, 3000 do at = n; ns.GoldYield() end; add(OneOff("t:l1", 1000, 2)) end)
        local function Done(list) doneCalls = doneCalls + 1; got = list end
        if not ns.GoldCollect(ctx, Done) then error("collecting is queued") end
        local slices = 0
        while ns.GoldBusy() and slices < 200 do ns.GoldRunSlice(); slices = slices + 1 end
        if slices < 2 or doneCalls ~= 1 or type(got) ~= "table" or #got ~= 1 then error("sliced: " .. slices .. " slices, done " .. doneCalls .. " times") end
        at, doneCalls = 0, 0
        ns.GoldCollect(ctx, Done)
        ns.GoldRunSlice()
        local after1 = at
        if after1 == 0 or after1 >= 3000 then error("one slice does part of it: " .. after1) end
        env.InCombatLockdown = function() return true end
        for _ = 1, 5 do ns.GoldRunSlice() end
        if at ~= after1 then error("nothing runs in a fight") end
        env.InCombatLockdown = keep.combat
        fireEvent("PLAYER_REGEN_DISABLED")
        for _ = 1, 5 do ns.GoldRunSlice() end
        if at ~= after1 or doneCalls ~= 0 then error("nothing runs between the fight's start and its end") end
        fireEvent("PLAYER_REGEN_ENABLED")
        slices = 0
        while ns.GoldBusy() and slices < 200 do ns.GoldRunSlice(); slices = slices + 1 end
        if doneCalls ~= 1 or at ~= 3000 then error("the collection finishes after the fight") end
        ns.GoldRegister("t:loop", nil)
        env.debugprofilestop = keep.clock
        if not ns.GoldJob(function() coroutine.yield() end, "k") or ns.GoldJob(function() end, "k") then error("one job a key") end
        local before = #ns.errors
        ns.GoldJob(function() error("bad job") end, "e")
        for _ = 1, 10 do ns.GoldRunSlice() end
        if ns.GoldBusy() or #ns.errors ~= before + 1 or tostring(ns.errors[#ns.errors]):sub(1, 6) ~= "Gold: " then error("a job's error is noted and the next one runs") end
        -- the value of an item, and how fresh
        local entries, vendors = { [1] = { price = 1000, day = today } }, { [1] = 300, [2] = 2000 }
        entries[2] = entries[1]
        ns.PriceEntry = function(id) return entries[id] end
        ns.GetItemInfo = function(self, id) return "Item", nil, 1, nil, nil, nil, nil, nil, nil, nil, vendors[id] end
        local v, from, day = ns.GoldItemValue(1, today)
        if v ~= 950 or from ~= "ah" or day ~= today then error("auction value net of the cut: " .. tostring(v) .. " " .. tostring(from)) end
        v, from, day = ns.GoldItemValue(2, today)
        if v ~= 2000 or from ~= "vendor" or day ~= nil then error("a vendor pays more: " .. tostring(v) .. " " .. tostring(from)) end
        local F = ns.GoldFreshFactor
        if F(nil, today) ~= 1 or F(20261124, today) ~= 1 or F(20261122, today) ~= 0.85 or F(20261119, today) ~= 0.6 or F(20261026, today) ~= 0.4 then error("freshness") end
        if ns.GoldFreshText({ basis = "guess", priceDay = 20261123 }, today) ~= "guess · prices from 2 days ago" then error("fresh text: " .. ns.GoldFreshText({ basis = "guess", priceDay = 20261123 }, today)) end
        local ft = ns.GoldFreshText({ basis = "guess" }, today)
        if ft:sub(-#"vendor prices") ~= "vendor prices" then error("no auction price: " .. ft) end
        -- ranking
        local P1, P2 = PerHour("t:p1", 10000, 20, 80), PerHour("t:p2", 5000, 90, 50)
        local O1, O2 = OneOff("t:o1", 3000, 5), OneOff("t:o2", 3000, 2)
        local all = { P1, P2, O1, O2 }
        local r = ns.GoldRank(all, { 100, 0, 0 }, nil, today)
        if r.ranked[1] ~= P1 or r.ranked[2] ~= P2 or #r.ranked ~= 2 or r.now[1] ~= O2 or r.now[2] ~= O1 or #r.now ~= 2 or r.merged ~= nil then error("most gold") end
        if P1.score ~= 100 or P2.score ~= 50 then error("scores: " .. tostring(P1.score) .. " " .. tostring(P2.score)) end
        r = ns.GoldRank(all, { 30, 70, 0 }, nil, today)
        if r.ranked[1] ~= P2 then error("easy money puts the easy one first") end
        if ns.GoldPresetOf(30, 70, 0) ~= "easy" or ns.GoldPresetOf(40, 60, 0) ~= "custom" or ns.GoldPresetOf(100, 0, 0) ~= "most" or ns.GoldPresetOf(30, 0, 70) ~= "safe" then error("presets") end
        r = ns.GoldRank(all, { 0, 0, 0 }, nil, today)
        if r.ranked[1] ~= P1 or P1.score ~= 100 then error("no weights at all ranks like Most gold") end
        P1.priceDay = 20261115
        ns.GoldRank(all, { 100, 0, 0 }, nil, today)
        if P1.safetyNow ~= 32 then error("ten-day-old prices: " .. tostring(P1.safetyNow)) end
        P1.priceDay = nil
        r = ns.GoldRank(all, { 100, 0, 0 }, 20000, today)
        if P1.toGoal ~= 120 or P2.toGoal ~= 240 or O1.toGoal ~= 107 or O2.toGoal ~= 104 then error("time to the goal: " .. tostring(P1.toGoal) .. " " .. tostring(P2.toGoal) .. " " .. tostring(O1.toGoal) .. " " .. tostring(O2.toGoal)) end
        local m = r.merged
        if type(m) ~= "table" or m[1] ~= O2 or m[2] ~= O1 or m[3] ~= P1 or m[4] ~= P2 or #m ~= 4 then error("one list by time to the goal") end
        -- outside the sliders comes last, whatever its time; a one-off counts on the top-scored idea
        local P3 = PerHour("t:p3", 9000, 0, 0)
        r = ns.GoldRank({ P1, P2, P3, O1, O2 }, { 30, 70, 0 }, 20000, today)
        m = r.merged
        if m[1] ~= P1 or m[2] ~= O2 or m[3] ~= O1 or m[4] ~= P2 or m[5] ~= P3 or O2.toGoal ~= 206 then error("within the sliders first: " .. tostring(O2.toGoal)) end
        if ns.GoldRank(all, { 100, 0, 0 }, 0, today).merged ~= nil or ns.GoldRank(all, { 100, 0, 0 }, -5, today).merged ~= nil then error("a goal reached: no merge") end
        local big = OneOff("t:o3", 30000, 4)
        ns.GoldRank({ O1, big }, { 100, 0, 0 }, 20000, today)
        if O1.toGoal ~= math.huge or big.toGoal ~= 4 or ns.GoldTimeText(math.huge) ~= "—" then error("no per-hour idea: no time, never an error") end
        -- words
        if ns.GoldEaseWord(70) ~= "Easy" or ns.GoldEaseWord(69) ~= "Some effort" or ns.GoldEaseWord(39) ~= "Hard" then error("ease words") end
        if ns.GoldSafetyWord(75) ~= "Sure" or ns.GoldSafetyWord(74) ~= "Fairly sure" or ns.GoldSafetyWord(44) ~= "A gamble" then error("safety words") end
        if ns.GoldTimeText(0.5) ~= "under a minute" or ns.GoldTimeText(12) ~= "12 min" or ns.GoldTimeText(75) ~= "1 h 15 min" or ns.GoldTimeText(3000) ~= "2 days" then error("times: " .. ns.GoldTimeText(75) .. " " .. ns.GoldTimeText(3000)) end
        -- saved settings, the goal and the vendor reader
        ns.root.goldWeights = nil
        local g, e, s = ns.GoldWeights()
        if g ~= 100 or e ~= 0 or s ~= 0 then error("the default is Most gold") end
        ns.GoldSetWeight("ease", 70)
        if type(ns.root.goldWeights) ~= "table" or ns.root.goldWeights.ease ~= 70 or select(2, ns.GoldWeights()) ~= 70 then error("a slider is kept") end
        ns.GoldSetPreset("safe")
        g, e, s = ns.GoldWeights()
        if g ~= 30 or e ~= 0 or s ~= 70 then error("a preset sets all three") end
        ns.root.goldChars = nil
        if ns.GoldGoal() ~= nil then error("no goal") end
        ns.GoldSetGoal(10000000, "epic")
        local goal, name = ns.GoldGoal()
        if goal ~= 10000000 or name ~= "epic" or ns.root.goldChars[ns:CharKey()].goal ~= 10000000 then error("the goal is kept per character") end
        ns.GoldSetGoal(nil)
        if ns.GoldGoal() ~= nil then error("the goal is cleared") end
        ns.root.goldVendor = { v = 1, items = { [5] = { buy = 10, stack = 20, day = 20260509 }, [6] = { buy = 7, stack = 1, day = 20261120 }, [7] = "odd" } }
        if ns.GoldVendorBuy(5) ~= nil or ns.GoldVendorBuy(7) ~= nil or ns.GoldVendorBuy(8) ~= nil then error("200 days old reads as nothing") end
        local buy, bday, entry = ns.GoldVendorBuy(6)
        if buy ~= 7 or bday ~= 20261120 or type(entry) ~= "table" then error("a vendor price") end
        -- Go: the planner's travel when it is there, else the steps
        local maps = { GetMapInfo = function(id) if id == 1436 then return { name = "Westfall" } end end }
        env.C_Map = setmetatable(maps, { __index = keep.map })
        ns.GoldTravel = nil
        local idea = { title = "T", steps = { { text = "Go", map = 1436, x = 50.04, y = 40 } } }
        if ns.GoldGo(idea) ~= "list" then error("Go with no travel lists the steps") end
        local line = ns:ListWindow("GoldSteps").lines[1]
        if not line or line.left ~= "1. Go" or not tostring(line.right):find("Westfall", 1, true) or not tostring(line.right):find("50.0, 40.0", 1, true) then error("the steps list: " .. tostring(line and line.left) .. " | " .. tostring(line and line.right)) end
        ns:ListWindow("GoldSteps"):Hide()
        local went
        ns.GoldTravel = function(i) went = i end
        if ns.GoldGo(idea) ~= "travel" or went ~= idea then error("Go hands the idea to the travel") end
        env.InCombatLockdown = function() return true end
        if ns.GoldGo(idea) ~= false then error("not during a fight") end
    end)
    ns.GuideUnlocked, env.InCombatLockdown, env.debugprofilestop, ns.IsSecret = keep.unlocked, keep.combat, keep.clock, keep.secret
    ns.errors, ns.root.goldWeights, ns.root.goldChars, ns.root.goldVendor = keep.errors, keep.weights, keep.chars, keep.vendor
    ns.PriceEntry, ns.GetItemInfo, ns.Today, ns.GoldTravel, env.C_Map = keep.entry, keep.info, keep.today, keep.travel, keep.map
    if ns.GoldRegister then
        for _, key in ipairs({ "t:a", "t:b", "t:loop" }) do ns.GoldRegister(key, nil) end
        for key, fn in pairs(keep.sources or {}) do ns.GoldRegister(key, fn) end
    end
    if not ok then error(err, 0) end
end)
try("gold seams: the window, the panel, hidden while locked", function()
    local keep = { key = ns.root.guideKey, unlocked = ns.GuideUnlocked, ctrl = env.IsControlKeyDown, combat = env.InCombatLockdown, money = env.GetMoney,
        ahf = rawget(env, "AuctionHouseFrame"), house = ns.PriceHouse, chars = ns.root.goldChars, weights = ns.root.goldWeights, vendor = ns.root.goldVendor,
        mobs = ns.root.goldMobs, gather = ns.root.goldGather, guides = ns.root.guides, state = ns.root.guideState, today = ns.Today }
    local ok, err = pcall(function()
        if type(ns.GoldOpen) ~= "function" then error("ns:GoldOpen is nil") end
        keep.sources = ns.GoldSources()
        for key in pairs(keep.sources) do ns.GoldRegister(key, nil) end
        fireEvent("PLAYER_REGEN_ENABLED")
        local function Handler(obj, name) for i = #handlers, 1, -1 do local h = handlers[i]; if h.self == obj and h.name == name then return h.fn end end end
        local function Click(b, button) local f = Handler(b, "OnClick"); if not f then error("nothing to click") end; f(b, button or "LeftButton") end
        local function Settle() local n = 0; while ns.GoldBusy() and n < 200 do ns.GoldRunSlice(); n = n + 1 end end
        local function Said(from, text) for i = from + 1, #printed do if tostring(printed[i]):find(text, 1, true) then return true end end return false end
        -- locked: no way in, nothing made, nothing translated
        ns.root.guideKey = nil
        if ns:GoldOpen() ~= nil then error("locked: no window") end
        local added = 0
        local tip = { AddLine = function() added = added + 1 end, AddDoubleLine = function() added = added + 1 end }
        ns.LauncherTipExtra(tip)
        if added ~= 0 then error("locked: no launcher line") end
        env.IsControlKeyDown = function() return true end
        if ns.LauncherClickExtra("LeftButton") ~= false then error("locked: Ctrl-click is the usual click") end
        local mark = #printed
        env.SlashCmdList["FANTASYGLASSUI"]("guide gold")
        if not Said(mark, "Quest guides are coming soon.") then error("locked: /fgui guide gold is the usual answer") end
        fireEvent("AUCTION_HOUSE_SHOW")
        if ns.goldPanel ~= nil or rawget(env, "FantasyGlassUIGoldAH") ~= nil then error("locked: no auction house panel") end
        fireEvent("PLAYER_ENTERING_WORLD"); runTimers()
        if ns.goldWindow ~= nil or rawget(env, "FantasyGlassUIGold") ~= nil then error("locked: nothing made at login") end
        for _, s in ipairs({ "Ways to make gold", "Ctrl-click: ways to make gold", "Gold ideas here", "Gold an hour" }) do
            if ns.seenStrings[s] ~= nil then error("locked: never translated: " .. s) end
        end
        -- unlocked: the launcher, with no sources (and old records forgotten on the first open)
        ns.GuideUnlocked = function() return true end
        local today = 20261125
        ns.Today = function() return today end
        ns.root.goldVendor = { v = 1, items = { [5] = { buy = 1, day = 20260509 }, [6] = { buy = 1, day = today } } }
        ns.root.goldMobs = { [1] = { last = 20260817 }, [2] = { last = today } }
        ns.root.goldGather = { [1429] = { day = 20260817 }, [1411] = { day = today } }
        ns.root.goldChars, ns.root.goldWeights = nil, nil
        ns.LauncherTipExtra(tip)
        if added ~= 1 then error("unlocked: the launcher says Ctrl-click") end
        ns.LauncherClick("LeftButton")
        local w = ns.goldWindow
        if not w or rawget(w, "suiLook") ~= "settings" or ns.goldOpens ~= 1 then error("Ctrl-click opens the window, in the settings look") end
        env.IsControlKeyDown = keep.ctrl
        Settle()
        local L = ns.GoldWindowLines()
        if #L.ranked ~= 1 or not L.ranked[1]:find("No ideas yet", 1, true) or #L.now ~= 1 or L.now[1] ~= "Nothing right now." then error("empty: " .. tostring(L.ranked[1]) .. " | " .. tostring(L.now[1])) end
        if L.preset ~= "Most gold" or L.goal ~= nil then error("Most gold, no goal") end
        if ns.root.goldVendor.items[5] or not ns.root.goldVendor.items[6] or ns.root.goldMobs[1] or not ns.root.goldMobs[2] or ns.root.goldGather[1429] or not ns.root.goldGather[1411] then error("old records are forgotten") end
        -- the guide panel's button, and /fgui guide gold
        ns.root.guides, ns.root.guideState = nil, nil
        ns:GuideSave(ns.GuideParse("guide: Gold test\nnote Sell and repair\n"))
        ns:GuideFollow("Gold test")
        local panel = ns:GuideShowPanel()
        local b = panel and rawget(panel, "suiGoldButton")
        if not b or rawget(b, "suiGoldOn") ~= true then error("the guide panel has a Gold button") end
        Click(b)
        if ns.goldOpens ~= 2 then error("the Gold button opens the window") end
        env.SlashCmdList["FANTASYGLASSUI"]("guide gold")
        if ns.goldOpens ~= 3 then error("/fgui guide gold opens it") end
        Settle()
        -- two sources
        local function Idea(t)
            local i = { kind = "sell", ease = 90, safety = 75, basis = "prices", where = "window", oneOff = false }
            for k, v in pairs(t) do i[k] = v end
            return i
        end
        ns.GoldRegister("t:per", function(ctx, add)
            add(Idea({ id = "t:p1", kind = "farm", title = "P1", perHour = 10000, ease = 20, safety = 80, basis = "guess", steps = { { text = "Go" } } }))
            add(Idea({ id = "t:p2", kind = "farm", title = "P2", perHour = 5000, ease = 90, safety = 50, basis = "measured" }))
        end)
        local calls = 0
        ns.GoldRegister("t:one", function(ctx, add)
            calls = calls + 1
            add(Idea({ id = "t:o1", title = "O1", oneOff = true, total = 3000, minutes = 5, where = "both" }))
            add(Idea({ id = "t:o2", title = "O2", oneOff = true, total = 3000, minutes = 2 }))
            if ctx.where == "auction" then add(Idea({ id = "t:flip", kind = "flip", title = "Flip it", oneOff = true, total = 4500, minutes = 3, where = "auction" })) end
        end)
        ns:GoldRefresh(); Settle()
        L = ns.GoldWindowLines()
        if not (L.ranked[1] and L.ranked[1]:find("P1", 1, true) and L.ranked[1]:find("an hour", 1, true) and L.ranked[1]:find("guess", 1, true)) then error("the top idea: " .. tostring(L.ranked[1])) end
        if not (L.now[1] and L.now[1]:find("O2", 1, true) and L.now[1]:find("in about 2 min", 1, true)) then error("right now: " .. tostring(L.now[1])) end
        for _, row in ipairs(L.ranked) do if row:find("Flip it", 1, true) then error("auction-only ideas stay at the auction house") end end
        Click(w.presetButton)
        L = ns.GoldWindowLines()
        if L.preset ~= "Easy money" or not L.ranked[1]:find("P2", 1, true) then error("the preset button: " .. tostring(L.preset)) end
        Handler(w.sliders.gold.slider, "OnValueChanged")(w.sliders.gold.slider, 50)
        L = ns.GoldWindowLines()
        if L.preset ~= "Custom" or select(1, ns.GoldWeights()) ~= 50 then error("a moved slider: " .. tostring(L.preset)) end
        env.GetMoney = function() return 0 end
        rawset(w.goalBox, "GetText", function() return "2" end)
        Handler(w.goalBox, "OnTextChanged")(w.goalBox, true)
        L = ns.GoldWindowLines()
        if ns.GoldGoal() ~= 20000 or L.bar ~= 0 or #L.ranked ~= 4 then error("a goal of 2 gold: " .. tostring(ns.GoldGoal()) .. " " .. tostring(L.bar)) end
        for _, row in ipairs(L.ranked) do if not row:find(" · goal in ", 1, true) then error("every row has its time to the goal: " .. row) end end
        if not L.goal:find("about", 1, true) then error("the goal line: " .. tostring(L.goal)) end
        Click(w.goalCycle)
        if ns.GoldGoal() ~= 1200000 or ns.GoldWindowLines().goalName ~= "Riding at 40" then error("Riding at 40: " .. tostring(ns.GoldGoal())) end
        local realClass = env.UnitClass
        env.UnitClass = function() return "Paladin", "PALADIN" end
        local paladin = ns.GoldGoalAmount("mount")
        env.UnitClass = realClass
        if paladin ~= 1000000 or ns.GoldGoalAmount("epic") ~= 10000000 then error("riding by class: " .. tostring(paladin)) end
        Click(w.goalCycle)
        if ns.GoldGoal() ~= 10000000 or select(2, ns.GoldGoal()) ~= "epic" then error("Epic riding at 60") end
        if ns.GoldWindowLines().goalName ~= "Epic riding at 60" then error("the named goal shows its name") end
        env.GetMoney = function() return 20000000 end
        ns:GoldRefresh(); Settle()
        L = ns.GoldWindowLines()
        if L.goal ~= "Goal reached" or L.bar ~= 1 or #L.now ~= 2 or #L.ranked ~= 2 then error("goal reached: two sections again") end
        ns.GoldSetGoal(nil)
        -- opened in a fight: it waits for the fight to end
        env.InCombatLockdown = function() return true end
        ns:GoldOpen(); Settle()
        if ns.GoldWindowLines().ranked[1] ~= "Waiting for the fight to end." then error("in a fight: " .. tostring(ns.GoldWindowLines().ranked[1])) end
        env.InCombatLockdown = keep.combat
        fireEvent("PLAYER_REGEN_ENABLED"); Settle()
        if #ns.GoldWindowLines().ranked ~= 2 then error("the list fills after the fight") end
        -- the auction house panel
        local scan = 1
        ns.PriceHouse = function() return { scanAt = scan } end
        env.AuctionHouseFrame = newmock()
        fireEvent("AUCTION_HOUSE_SHOW"); Settle()
        local p = ns.goldPanel
        if not p or rawget(p, "suiGoldOn") ~= true or rawget(p, "suiLook") ~= "settings" then error("the auction house panel shows") end
        local A = ns.GoldWindowLines().auction
        if not (A and A[1] and A[1]:find("Flip it", 1, true)) or #A ~= 2 then error("the panel's ideas: " .. tostring(A and A[1])) end
        local c0 = calls
        local tick = Handler(p, "OnUpdate")
        tick(p, 5); Settle()
        if calls ~= c0 then error("the same scan: nothing collected") end
        scan = 2
        tick(p, 2); Settle()
        if calls ~= c0 then error("checked every 5 s") end
        tick(p, 3); Settle()
        if calls ~= c0 + 1 then error("a new scan collects again") end
        fireEvent("AUCTION_HOUSE_CLOSED")
        if rawget(p, "suiGoldOn") ~= false then error("closed with the auction house") end
    end)
    ns.root.guideKey, ns.GuideUnlocked, env.IsControlKeyDown, env.InCombatLockdown, env.GetMoney = keep.key, keep.unlocked, keep.ctrl, keep.combat, keep.money
    env.AuctionHouseFrame, ns.PriceHouse, ns.Today = keep.ahf, keep.house, keep.today
    ns.root.goldChars, ns.root.goldWeights, ns.root.goldVendor, ns.root.goldMobs, ns.root.goldGather = keep.chars, keep.weights, keep.vendor, keep.mobs, keep.gather
    ns.root.guides, ns.root.guideState = keep.guides, keep.state
    if ns.goldWindow then ns.goldWindow:Hide() end
    if ns.GoldRegister then
        for _, key in ipairs({ "t:per", "t:one" }) do ns.GoldRegister(key, nil) end
        for key, fn in pairs(keep.sources or {}) do ns.GoldRegister(key, fn) end
    end
    if not ok then error(err, 0) end
end)
-- gold tests seams: end
-- gold tests A (sell): begin
try("gold A: bags, junk and vendor flips", function()
    local keep = { unlocked = ns.GuideUnlocked, today = ns.Today, vendor = ns.root.goldVendor, info = ns.GetItemInfo, hint = ns.SellHintFor,
        priceItems = ns.PriceItems, bagItems = ns.AuctionBagItems, clock = env.debugprofilestop, inv = ns.root.inventory, passes = ns.goldVendorPasses,
        num = rawget(env, "GetMerchantNumItems"), mid = rawget(env, "GetMerchantItemID"), mf = rawget(env, "C_MerchantFrame"), merchant = rawget(env, "MerchantFrame"),
        cost = rawget(env, "GetMerchantItemCostInfo"), citem = rawget(env, "C_Item"), combat = env.InCombatLockdown, date = env.date }
    local ok, err = pcall(function()
        if type(ns.GoldVendorNote) ~= "function" or type(ns.GoldSellIdeas) ~= "function" or type(ns.GoldFlipIdeas) ~= "function" then error("ns.GoldVendorNote is nil") end
        keep.sources = ns.GoldSources()
        if type(keep.sources.sell) ~= "function" or type(keep.sources.vflip) ~= "function" then error("the sell and vflip sources are registered") end
        for key in pairs(keep.sources) do ns.GoldRegister(key, nil) end
        fireEvent("PLAYER_REGEN_ENABLED")
        local today = 20261125
        ns.Today = function() return today end
        local function Settle() local n = 0; while ns.GoldBusy() and n < 2000 do ns.GoldRunSlice(); n = n + 1 end; return n end
        local hidden = setmetatable({ __secret = true }, {})
        local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
        -- the items: name, link, quality, ..., vendor (11th), ..., bindType (14th)
        local infos = {
            [5] = { "Wool Cloth", 1, 50 }, [6] = { "Broken Fang", 0, 30 }, [7] = { "Linen Cloth", 1, 200 }, [11] = { "Wool Bolt", 1, 200 },
            [12] = { "Fine Sword", 2, 100, 2 }, [13] = { "Worn Belt", 0, 100, 3 }, [14] = { "Soul Gem", 2, 10, 1 }, [8] = { "Silk Cloth", 1, 10 },
            [9] = { "Bound Ring", 2, 500, 1 }, [10] = { "Grey Rag", 0, 200 }, [2320] = { "Coarse Thread", 1, 2 }, [4470] = { "Simple Wood", 1, 9 },
        }
        ns.GetItemInfo = function(self, id)
            local i = infos[id] or (type(id) == "number" and id >= 100000 and { "Thing " .. id, 1, 1 }) or nil
            if not i then return nil end
            return i[1], "|Hitem:" .. id .. "|h[" .. i[1] .. "]|h", i[2], 10, 1, "Trade", "Cloth", 20, "", 0, i[3], 7, 5, i[4] or 0
        end
        ns.SellHintFor = function(id) if id == 5 then return "sell" end end
        -- merchant recording: locked does nothing; then debounced, read once, the rules kept
        local slots = {
            { 2320, { price = 10, stackCount = 1, numAvailable = -1, extendedCost = false } },
            { 4470, { price = 40, stackCount = 5, numAvailable = 3, extendedCost = false } },
            { 4471, { price = 50, stackCount = 1, numAvailable = -1, extendedCost = true } },
            { 4473, { price = 50, stackCount = 1, numAvailable = -1, hasExtendedCost = true } },
            { 4474, { price = 50, stackCount = 1, numAvailable = -1 } },
        }
        env.GetMerchantItemCostInfo = function(i) return (i == 5) and 1 or 0 end
        env.GetMerchantNumItems = function() return #slots end
        env.GetMerchantItemID = function(i) return slots[i] and slots[i][1] end
        env.C_MerchantFrame = { GetItemInfo = function(i) return slots[i] and slots[i][2] end }
        ns.root.goldVendor = nil
        ns.goldVendorPasses = 0
        ns.GuideUnlocked = function() return false end
        fireEvent("MERCHANT_SHOW"); runTimers()
        if ns.root.goldVendor ~= nil or ns.goldVendorPasses ~= 0 then error("locked: nothing recorded") end
        ns.GuideUnlocked = function() return true end
        env.InCombatLockdown = function() return true end
        fireEvent("MERCHANT_SHOW"); runTimers(); Settle()
        if ns.root.goldVendor ~= nil or ns.goldVendorPasses ~= 0 then error("in a fight: nothing recorded") end
        env.InCombatLockdown = keep.combat
        fireEvent("MERCHANT_SHOW"); fireEvent("MERCHANT_UPDATE")
        if ns.root.goldVendor ~= nil then error("recorded only after the half second") end
        runTimers(); Settle()
        if ns.goldVendorPasses ~= 1 then error("debounced: one pass, not " .. tostring(ns.goldVendorPasses)) end
        local buy, day, entry = ns.GoldVendorBuy(2320)
        if buy ~= 10 or day ~= today or entry.stack ~= 1 or entry.limited ~= nil then error("a vendor's price: " .. tostring(buy)) end
        buy, day, entry = ns.GoldVendorBuy(4470)
        if buy ~= 8 or entry.stack ~= 5 or entry.limited ~= 3 then error("a price for five, and limited: " .. tostring(buy) .. " " .. tostring(entry and entry.limited)) end
        if ns.root.goldVendor.items[4471] ~= nil or ns.root.goldVendor.items[4473] ~= nil or ns.root.goldVendor.v ~= 1 then error("a price in tokens is not kept, either spelling") end
        if ns.root.goldVendor.items[4474] ~= nil then error("a slot that also costs tokens is not kept") end
        if ns.GoldVendorNote(4472, { price = hidden, stackCount = 1, numAvailable = -1 }, today) ~= false or ns.root.goldVendor.items[4472] ~= nil then error("a hidden price is not kept") end
        if ns.GoldVendorNote(4472, { price = 10, stackCount = hidden, numAvailable = -1 }, today) ~= false then error("a hidden stack is not kept") end
        if ns.GoldVendorNote(hidden, { price = 10, stackCount = 1 }, today) ~= false then error("a hidden id is not kept") end
        if ns.GoldVendorNote(4472, { price = 0, stackCount = 1 }, today) ~= false or ns.GoldVendorNote(4472, "odd", today) ~= false then error("no price, nothing kept") end
        if ns.GoldVendorNote(4472, { price = 30, stackCount = 2 }, today) ~= true or ns.root.goldVendor.items[4472].buy ~= 15 then error("a plain price is kept") end
        -- a full store: the oldest goes
        local items = {}
        for i = 1, 3000 do items[100000 + i] = { buy = 10, stack = 1, day = 20261001 } end
        items[100001].day = 20260601
        ns.root.goldVendor = { v = 1, items = items }
        fireEvent("MERCHANT_SHOW"); runTimers(); Settle()
        if Count(items) ~= 3000 or items[100001] ~= nil or not items[2320] or not items[4470] then error("at most 3000, the oldest gone: " .. Count(items)) end
        -- bags: sell at the auction house, vendor the junk
        local prices = { [5] = { price = 500, day = today }, [8] = { price = 1000, day = 20261124 } }
        prices[14] = { price = 5000, day = today }
        local bags = { { id = 5, count = 1, vendor = 50 }, { id = 5, count = 1, vendor = 50 }, { id = 6, count = 1, vendor = 30 }, { id = 9, count = 1, vendor = 500, bound = true },
            { id = 14, count = 1, vendor = 10 } }
        local got = {}
        local function Add(i) got[#got + 1] = i; got[i.id] = i end
        local ctx = { today = today, where = "window" }
        env.MerchantFrame = { IsShown = function() return false end }
        ns.GoldSellIdeas(ctx, Add, bags, prices)
        if ctx.today ~= today then error("the context is left as it was") end
        local plain = { where = "window" }
        ns.GoldSellIdeas(plain, function() end, bags, prices)
        if plain.today ~= nil then error("the context is copied, not changed") end
        local s, j = got["sell:bags"], got["sell:junk"]
        if not s or s.total ~= 950 or s.minutes ~= 3.5 or s.kind ~= "sell" or s.where ~= "both" or s.basis ~= "prices" or s.priceDay ~= today or s.oneOff ~= true then error("sell your bags: " .. tostring(s and s.total) .. " " .. tostring(s and s.minutes)) end
        if not ns.GoldIdeaValid(s) then error("sell your bags is a good idea: " .. tostring(select(2, ns.GoldIdeaValid(s)))) end
        if #s.detail ~= 1 or not (tostring(s.detail[1].left) .. tostring(s.detail[1].right)):find("Sell now", 1, true) or not s.detail[1].left:find("Wool Cloth", 1, true) then error("one line an item, Sell now marked") end
        if not s.steps or s.steps[1].text ~= "Go to the auction house" then error("the steps") end
        if not j or j.kind ~= "junk" or j.total ~= 30 or j.minutes ~= 3 or j.where ~= "window" or j.priceDay ~= nil then error("vendor your junk: " .. tostring(j and j.total)) end
        if #got ~= 2 then error("two ideas from the bags") end
        got = {}
        ns.GoldSellIdeas(ctx, Add, { { id = 5, count = 2, vendor = 50 }, { id = 6, count = 1, vendor = 30 } }, prices)
        if got["sell:junk"].total ~= 30 or got["sell:bags"].total ~= 950 then error("junk: grey items with a vendor price") end
        env.MerchantFrame = { IsShown = function() return true end }
        got = {}
        ns.GoldSellIdeas(ctx, Add, { { id = 6, count = 2, vendor = 30 }, { id = 10, count = 1, vendor = 200, bound = true } }, prices)
        if got["sell:junk"].minutes ~= 1 or got["sell:junk"].total ~= 260 or got["sell:bags"] ~= nil then error("at a vendor, a minute: " .. tostring(got["sell:junk"].minutes)) end
        env.MerchantFrame = { IsShown = function() return false end }
        -- the bank, when it has been seen: marked so the player fetches them first
        got = {}
        ns.GoldSellIdeas(ctx, Add, {}, prices, { { id = 8, count = 3, vendor = 10 }, { id = 6, count = 4, vendor = 30 } })
        local b, bj = got["sell:bank"], got["sell:bankjunk"]
        if not b or b.total ~= 2850 or b.minutes ~= 5.5 or b.priceDay ~= 20261124 or not b.title:find("in your bank", 1, true) then error("sell from the bank: " .. tostring(b and b.total) .. " " .. tostring(b and b.minutes)) end
        if not b.detail[1].left:find("in your bank", 1, true) or b.steps[1].text ~= "Take the marked items out of your bank" or b.steps[2].text ~= "Go to the auction house" then error("bank items are marked") end
        if not bj or bj.total ~= 120 or bj.minutes ~= 5 or not bj.title:find("in your bank", 1, true) then error("the bank's junk: " .. tostring(bj and bj.total)) end
        got = {}
        local many = { seen = 20261122 }
        for i = 1, 20 do many[i] = { id = 100000 + i, count = 1, vendor = 1 }; prices[100000 + i] = { price = 1000, day = today } end
        ns.GoldSellIdeas(ctx, Add, {}, prices, many)
        if got["sell:bank"].minutes ~= 10 then error("bank minutes stop at 10: " .. tostring(got["sell:bank"].minutes)) end
        if not got["sell:bank"].detail[1].left:find("in your bank, seen 3 days ago", 1, true) then error("the bank's age: " .. got["sell:bank"].detail[1].left) end
        -- the source reads the bank the storage window remembers, and only once it has been seen
        local myKey = ns:CharKey()
        ns.root.inventory = { chars = { [myKey] = { bank = { { "|Hitem:8::::|h[Silk Cloth]|h", 3, 1 }, { "|Hitem:9::::|h[Bound Ring]|h", 1, 2 },
            { "|Hitem:12::::|h[Fine Sword]|h", 1, 2 }, { "|Hitem:13::::|h[Worn Belt]|h", 1, 0 } } } } }
        ns.PriceItems = function() return { [8] = prices[8], [9] = { price = 90000, day = today }, [12] = { price = 90000, day = today } } end
        local counts = nil
        env.C_Item = setmetatable({ GetItemCount = function(id, bank) if counts then return bank and counts[1] or counts[2] end end }, { __index = keep.citem })
        ns.AuctionBagItems = function() return { { id = 5, count = 2, vendor = 50 } } end
        ns.GoldRegister("sell", keep.sources.sell)
        local ideas = ns.GoldCollectNow(ctx)
        for _, i in ipairs(ideas) do if i.id == "sell:bank" then error("a bank never seen is not read") end end
        ns.root.inventory.chars[myKey].bankTime = os.time({ year = 2026, month = 11, day = 22, hour = 12 })
        env.date = function(f, t) return os.date(f, t) end
        ideas = ns.GoldCollectNow(ctx)
        local fromBank
        for _, i in ipairs(ideas) do if i.id == "sell:bank" then fromBank = i end end
        if not fromBank or fromBank.total ~= 2850 or #fromBank.detail ~= 1 then error("the remembered bank is read, a bound ring and a bind-on-equip sword left out") end
        if not fromBank.detail[1].left:find("in your bank, seen 3 days ago", 1, true) then error("the bank's age shows: " .. fromBank.detail[1].left) end
        for _, i in ipairs(ideas) do if i.id == "sell:bankjunk" then error("a bind-on-use grey in the bank is never suggested") end end
        local function BankIdea()
            for _, i in ipairs(ns.GoldCollectNow(ctx)) do if i.id == "sell:bank" then return i end end
        end
        counts = { 5, 3 }
        if not BankIdea() or BankIdea().total ~= 1900 then error("no more than the game says is in the bank: " .. tostring(BankIdea() and BankIdea().total)) end
        counts = { 3, 3 }
        if BankIdea() then error("all taken out: no bank idea") end
        counts = { hidden, 3 }
        if not BankIdea() or BankIdea().total ~= 2850 then error("a hidden count: the list as it was") end
        counts = nil
        ns.GoldRegister("sell", nil)
        -- vendor -> auction
        local hist = { [20261122] = 200, [20261123] = 200, [20261124] = 200, [20261125] = 200 }
        ns.root.goldVendor = { v = 1, items = { [2320] = { buy = 10, stack = 20, day = today } } }
        prices = { [2320] = { price = 210, day = today, listed = 6, hist = hist }, [7] = { price = 40, day = today }, [5] = { price = 500, day = today } }
        got = {}
        ns.GoldFlipIdeas(ctx, Add, prices)
        local v = got["vflip:2320"]
        if not v or v.total ~= 3600 or v.minutes ~= 8 or v.kind ~= "vflip" or v.where ~= "both" or v.priceDay ~= today then error("vendor flip: " .. tostring(v and v.total)) end
        if v.title ~= "Buy Coarse Thread from a vendor, sell at the auction house" or not ns.GoldIdeaValid(v) then error("the vendor flip's title: " .. tostring(v.title)) end
        if got["aflip:7"] ~= nil then error("auction flips only at the auction house") end
        ns.GoldRank({ v }, { 100, 0, 0 }, nil, today)
        if v.safetyNow ~= 55 then error("fresh prices: " .. tostring(v.safetyNow)) end
        prices[2320].day = 20261115
        got = {}
        ns.GoldFlipIdeas(ctx, Add, prices)
        ns.GoldRank({ got["vflip:2320"] }, { 100, 0, 0 }, nil, today)
        if got["vflip:2320"].safetyNow ~= 22 then error("ten-day-old prices are less sure: " .. tostring(got["vflip:2320"].safetyNow)) end
        prices[2320].day = today
        ns.root.goldVendor.items[2320].limited = 3
        got = {}
        ns.GoldFlipIdeas(ctx, Add, prices)
        if got["vflip:2320"].total ~= 540 then error("limited stock: " .. tostring(got["vflip:2320"].total)) end
        ns.root.goldVendor.items[2320].limited = nil
        for _, case in ipairs({
            { "nobody lists it", function() prices[2320].listed = 0 end, function() prices[2320].listed = 6 end },
            { "two days of history", function() prices[2320].hist = { [20261124] = 200, [20261125] = 200 } end, function() prices[2320].hist = hist end },
            { "a vendor price 31 days old", function() ns.root.goldVendor.items[2320].day = 20261025 end, function() ns.root.goldVendor.items[2320].day = today end },
            { "under 1.3 times", function() prices[2320].hist = { [20261123] = 1000, [20261124] = 1000, [20261125] = 1000 }; ns.root.goldVendor.items[2320].buy = 800 end, function() prices[2320].hist = hist; ns.root.goldVendor.items[2320].buy = 10 end },
            { "under 1 silver a flip", function() ns.root.goldVendor.items[2320].buy = 91 end, function() ns.root.goldVendor.items[2320].buy = 10 end },
        }) do
            case[2](); got = {}
            ns.GoldFlipIdeas(ctx, Add, prices)
            if got["vflip:2320"] then error("no vendor flip: " .. case[1]) end
            case[3]()
        end
        -- auction -> vendor, at the auction house, from today's lowest only
        local actx = { today = today, where = "auction" }
        got = {}
        ns.GoldFlipIdeas(actx, Add, prices)
        local a = got["aflip:7"]
        if not a or a.total ~= 160 or a.minutes ~= 3 or a.kind ~= "aflip" or a.where ~= "auction" or a.title ~= "Buy Linen Cloth at the auction house, a vendor pays more" then error("auction flip: " .. tostring(a and a.total)) end
        if got["aflip:5"] or not got["vflip:2320"] then error("only where a vendor pays more") end
        prices[11] = { price = 101, day = today }
        got = {}
        ns.GoldFlipIdeas(actx, Add, prices)
        if got["aflip:11"] or not got["aflip:7"] then error("under 1 silver is no flip") end
        prices[11] = nil
        prices[7].day = 20261124
        got = {}
        ns.GoldFlipIdeas(actx, Add, prices)
        if got["aflip:7"] then error("yesterday's lowest is no flip") end
        -- a big store: collected in slices, at most 10 flips, the best first
        items = {}
        prices = {}
        for i = 1, 3000 do items[100000 + i] = { buy = 10, stack = 1, day = today } end
        for i = 1, 12 do prices[100000 + i] = { price = 1000 + i * 100, day = today, listed = 1, hist = { [20261123] = 1000 + i * 100, [20261124] = 1000 + i * 100, [20261125] = 1000 + i * 100 } } end
        ns.root.goldVendor = { v = 1, items = items }
        ns.PriceItems = function() return prices end
        ns.GoldRegister("vflip", keep.sources.vflip)
        local t = 0
        env.debugprofilestop = function() t = t + 0.01; return t end
        local done
        if not ns.GoldCollect(ctx, function(list) done = list end) then error("collecting is queued") end
        local slices = Settle()
        env.debugprofilestop = keep.clock
        if slices < 3 or type(done) ~= "table" or #done ~= 10 then error("a big store in slices: " .. slices .. " slices, " .. tostring(done and #done) .. " ideas") end
        if done[1].id ~= "vflip:100012" then error("the best flip first: " .. tostring(done[1].id)) end
        local keptBest = false
        for _, i in ipairs(done) do if i.id == "vflip:100012" then keptBest = true end; if i.id == "vflip:100001" then error("the smallest flip goes") end end
        if not keptBest then error("the biggest flip is kept") end
        ns.GoldRegister("vflip", nil)
    end)
    ns.GuideUnlocked, ns.Today, ns.root.goldVendor, ns.GetItemInfo, ns.SellHintFor = keep.unlocked, keep.today, keep.vendor, keep.info, keep.hint
    ns.PriceItems, ns.AuctionBagItems, env.debugprofilestop, ns.root.inventory, ns.goldVendorPasses = keep.priceItems, keep.bagItems, keep.clock, keep.inv, keep.passes
    env.GetMerchantNumItems, env.GetMerchantItemID, env.C_MerchantFrame, env.MerchantFrame = keep.num, keep.mid, keep.mf, keep.merchant
    env.GetMerchantItemCostInfo, env.C_Item, env.InCombatLockdown, env.date = keep.cost, keep.citem, keep.combat, keep.date
    if ns.GoldRegister then
        for _, key in ipairs({ "sell", "vflip" }) do ns.GoldRegister(key, nil) end
        for key, fn in pairs(keep.sources or {}) do ns.GoldRegister(key, fn) end
    end
    local n = 0
    while ns.GoldBusy and ns.GoldBusy() and n < 2000 do ns.GoldRunSlice(); n = n + 1 end
    if not ok then error(err, 0) end
end)
-- gold tests A (sell): end
-- gold tests B (farm): begin
-- gold tests B (farm): end
-- gold tests C (gather): begin
-- gold tests C (gather): end
-- gold tests D (craft): begin
-- gold tests D (craft): end
-- gold tests together: begin
-- gold tests together: end
try("Delayed calls", function() runTimers(); fireEvent("PLAYER_ENTERING_WORLD"); runTimers() end)
try("Preview off", function() ns:TogglePreview(true); if ns.previewing then error("preview stuck on") end end)
fire()
local seen, uniq = {}, {}
for _, l in ipairs(out) do if not seen[l] then seen[l] = true; uniq[#uniq+1] = l end end
local pseen, puniq = {}, {}
for _, l in ipairs(printed) do if l:find("ff4444") and l:sub(1, 2) ~= "  " and not pseen[l] then pseen[l] = true; puniq[#puniq+1] = l end end
return (#uniq == 0 and "no errors" or table.concat(uniq, "\n")), (#puniq == 0 and "none" or table.concat(puniq, "\n")), #handlers, #ns.modules
'''
run = lua.eval('function(code, ...) return load(code)(...) end')
for secret in (False, True):
    sources = lua.table_from({**{f: open(f).read() for f in toc}, **{'options/' + f: open(OPT + f).read() for f in opt_toc},
                              'locales/Locales.lua': open('../FantasyGlassUI_Locales/Locales.lua').read()})
    missing = lua.table()
    errs, warns, nh, nm = run(harness, lua.table_from(toc), sources, missing, secret, lua.table_from(['options/' + f for f in opt_toc]))
    print(f"\n=== combat values {'SECRET' if secret else 'readable'}: {nm} modules, {nh} scripts/hooks fired ===")
    # A name the add-on declares as a file-level local, read as a global: used above its declaration
    # (in the game that is nil and an error; the harness would quietly hand back a stand-in).
    import re as _re
    declared = set()
    for f in toc + ['../FantasyGlassUI_Options/' + o for o in opt_toc]:
        for m in _re.finditer(r'^local\s+(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*(?:\s*,\s*[A-Za-z_][A-Za-z0-9_]*)*)', open(f).read(), _re.M):
            for n in m.group(1).split(','): declared.add(n.strip())
    early = sorted(k for k in missing.keys() if isinstance(k, str) and k in declared and k[0].islower())
    if early:
        errs = (errs if errs != "no errors" else "") + "\nUSED BEFORE ITS DECLARATION (a global in the game): " + ", ".join(early)
    print("errors:", errs)
    print("in-game error messages that would print:", warns)
