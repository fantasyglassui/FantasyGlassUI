-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local ADDON = "FantasyGlassUI"                              -- (the main add-on's name: its memory, its place in the add-on list)

-- /fgui check: a report on what this game client offers and how the add-on is doing, in a window
-- you can copy from. It only looks; it changes nothing.

local function Resolve(path)            -- "C_Bank.PurchaseBankTab" -> the thing, or nil
    local o = _G
    for part in path:gmatch("[^%.]+") do
        if type(o) ~= "table" then return nil end
        o = o[part]
    end
    return o
end

-- Some of the names checked below are older ones. The game has replaced them with a newer function,
-- which the add-on uses whenever the older one is absent; the list looks for both so that it reads
-- the same on any client. An absent older name is therefore not a fault, and the report says what
-- is used in its place, or why it is not needed, rather than leaving a bare "MISSING".
--   { replacement }          the newer function used instead (a fault only if that is absent too)
--   { nil, "explanation" }   nothing replaces it, and here is what that means
local OLDER = {
    GetSpellCooldown           = { "C_Spell.GetSpellCooldown" },
    GetCoinTextureString       = { "C_CurrencyInfo.GetCoinTextureString" },
    GetActiveTalentGroup       = { "C_SpecializationInfo.GetActiveSpecGroup" },
    GetSpecialization          = { "C_SpecializationInfo.GetActiveSpecGroup" },
    SetWatchedFactionIndex     = { "C_Reputation.SetWatchedFactionByIndex" },
    ActionButton_UpdateHotkeys = { nil, "not needed (key text is kept short another way)" },
    GetPetHappiness            = { nil, "not in this game (hunter pet happiness cannot be shown)" },
    IsRaidMarkerActive         = { nil, "not in this game (no ground markers in the raid tools)" },
    ["C_LossOfControl.GetActiveLossOfControlData"] = { nil, "not in this game (the loss-of-control alert stays off)" },
    ["C_MountJournal.SummonByID"] = { nil, "not in this game (the mount key says so when pressed)" },
    ["C_Map.SetUserWaypoint"] = { nil, "not in this game (waypoints use our own arrow only)" },
    ["C_Map.GetMapWorldSize"] = { nil, "not in this game (waypoint distances are rough)" },
    ["C_AuctionHouse.GetBrowseResults"] = { "GetAuctionItemInfo", "the older auction house is used instead" },
    ["GetAuctionItemInfo"] = { "C_AuctionHouse.GetBrowseResults", "the newer auction house is used instead" },
    ["C_SpecializationInfo.SetActiveSpecGroup"] = { "SetActiveTalentGroup", "the older name is used instead" },
    ["SetActiveTalentGroup"] = { "C_SpecializationInfo.SetActiveSpecGroup", "the newer name is used instead" },
    ["Menu.ModifyMenu"] = { nil, "not in this game (Copy name and Guild invite are not added to the right-click menu)" },
    ["FriendsFrame_UpdateFriendButton"] = { nil, "not in this game (the friends list keeps the game's colors)" },
    ["C_Item.GetItemNumSockets"] = { nil, "not in this game (empty gem sockets are not marked)" },
    ["MuteSoundFile"] = { nil, "not in this game (/fgui mute says so)" },
    ["GetBattlefieldStatus"] = { nil, "not in this game (no battleground queue alert)" },
    ["C_DateAndTime.GetSecondsUntilDailyReset"] = { nil, "not in this game (daily to-dos come back at midnight)" },
    ["C_TradeSkillUI.GetRecipeSchematic"] = { nil, "not in this game (/fgui shop says so)" },
    ["C_EquipmentSet.GetItemIDs"] = { nil, "not in this game (gear set items are not marked in bags)" },
    ["C_Spell.GetSpellDescription"] = { nil, "not in this game (the potion and food keys cannot tell what an item does)" },
    ["C_QuestLog.UnitIsRelatedToActiveQuest"] = { nil, "not in this game (quest marks read the unit's tooltip instead)" },
    FlashClientIcon            = { nil, "not in this game (the ready check alert cannot flash the taskbar)" },
    CompleteLFGRoleCheck       = { nil, "not in this game (no role checks to accept)" },
    ["C_TooltipInfo.GetMerchantItem"] = { nil, "not in this game (vendor items are read another way)" },
    ["C_TradeSkillUI.GetBaseProfessionInfo"] = { nil, "not in this game (the open profession is found another way)" },
    ["C_TradeSkillUI.GetTradeSkillTexture"]  = { nil, "not in this game (a profession's icon is found another way)" },
    GetProfessions             = { nil, "not in this game (a profession's icon is found another way)" },
    GetTradeSkillLine          = { nil, "not in this game (the open profession is found another way)" },
    ["C_TradeSkillUI.GetRecipeInfo"] = { nil, "not in this game (a craft is recognized another way)" },
}
-- What to print beside a function's name, and whether it is a real fault.
function ns.CheckFunctionLine(path, exists)
    exists = exists or function(p) return Resolve(p) ~= nil end
    if exists(path) then return "ok", false end
    local older = OLDER[path]
    if not older then return "MISSING", true end
    if older[1] then
        if exists(older[1]) then return "older name; " .. older[1] .. " is used instead", false end
        return "MISSING, and so is " .. older[1], true
    end
    return older[2], false
end

local FUNCTIONS = {
    "issecretvalue", "UnitHealthPercent", "CurveConstants.ScaleTo100", "UnitGetIncomingHeals", "UnitDetailedThreatSituation",
    "C_UnitAuras.GetAuraDataByIndex", "C_UnitAuras.GetAuraDataBySpellName", "C_PaperDollInfo.GetTemporaryEnchantmentInfo", "C_ChatBubbles.GetAllChatBubbles",
    "C_Spell.GetSpellInfo", "C_Spell.GetSpellCooldown", "GetLootRollItemInfo", "RollOnLoot",
    "AutoLootMailItem", "TakeInboxMoney", "GetTotemInfo", "C_PetInfo.GetPetHappiness", "GetRuneCooldown", "TalentButtonUtil.BaseVisualState", "UnitPowerPercent", "UnitThreatSituation",
    "C_SwingTimer.IsTargetWithinSwingRange", "SetBinding", "MoveViewLeftStart", "Screenshot", "EditModeManagerFrame", "GetNumSpecGroups", "GetPaperDollSideBarFrame",
    "C_Container.GetContainerItemInfo", "C_Container.SortBags", "C_Container.SortBankBags", "C_Container.SplitContainerItem",
    "C_Container.ContainerIDToInventoryID", "C_NewItems.IsNewItem", "StackSplitFrame",
    "C_Bank.FetchNumPurchasedBankTabs", "C_Bank.PurchaseBankTab", "C_Bank.CanPurchaseBankTab",
    "C_QuestLog.GetNumQuestWatches", "C_QuestLog.GetQuestObjectives", "GetQuestLogSpecialItemInfo", "ToggleQuestLog",
    "C_NamePlate.GetNamePlateForUnit", "CompactUnitFrame_UpdateHealthColor", "UnitFrameHealthBar_Update",
    "C_Map.GetPlayerMapPosition", "C_Reputation.GetWatchedFactionData", "C_GossipInfo.GetOptions", "C_PartyInfo.DoCountdown",
    "C_DamageMeter.GetCombatSessionFromType", "C_Item.GetItemInfoInstant", "C_Item.GetDetailedItemLevelInfo",
    "C_CurrencyInfo.GetCoinTextureString", "AbbreviateNumbers",
    "Menu.GetManager", "TooltipDataProcessor.AddTooltipPostCall", "ShowUIPanel", "ColorPickerFrame",
    "RegisterUnitWatch", "RegisterStateDriver", "CreateColor", "ChatFrameUtil.InsertLink", "C_ActionBar.HasAction",
    "SetRaidTargetIconTexture", "C_PartyInfo.DoReadyCheck", "C_AddOns.IsAddOnLoaded", "C_AddOns.LoadAddOn",
    "C_VignetteInfo.GetVignetteInfo", "BuyTrainerService", "GetTrainerServiceInfo", "MerchantItemButton_OnModifiedClick", "GetMerchantItemMaxStack",
    "CanGuildBankRepair", "C_GossipInfo.SelectOption", "GetGameTime", "C_Reputation.SetWatchedFactionByIndex",
    "C_EquipmentSet.GetEquipmentSetIDs", "C_EquipmentSet.UseEquipmentSet", "C_ChatInfo.PerformEmote", "Dismount", "IsFlying",
    "C_TradeSkillUI.GetBaseProfessionInfo", "C_TradeSkillUI.GetTradeSkillTexture", "C_TradeSkillUI.GetRecipeInfo", "GetProfessions",
    "C_QuestLog.UnitIsRelatedToActiveQuest", "C_Container.GetContainerItemID", "FlashClientIcon",
    "C_QuestLog.IsOnQuest", "C_QuestLog.IsQuestFlaggedCompleted", "C_QuestLog.IsComplete", "C_QuestLog.GetNextWaypoint", "C_QuestLog.GetQuestObjectives", "C_QuestLog.GetTitleForQuestID",
    "C_LossOfControl.GetActiveLossOfControlData", "C_MountJournal.SummonByID", "C_Map.GetPlayerMapPosition", "C_Map.GetMapWorldSize", "C_Map.SetUserWaypoint",
    "LoggingCombat", "GetSavedInstanceInfo", "ResetInstances", "TakeTaxiNode", "MuteSoundFile", "C_AuctionHouse.GetBrowseResults",
    "C_TradeSkillUI.GetRecipeSchematic", "C_EquipmentSet.GetItemIDs", "FCF_OpenNewWindow", "Menu.ModifyMenu", "FriendsFrame_UpdateFriendButton",
    "C_SpecializationInfo.SetActiveSpecGroup", "C_ChatInfo.InChatMessagingLockdown", "C_Item.GetItemNumSockets", "C_DateAndTime.GetSecondsUntilDailyReset",
    "C_Spell.GetSpellDescription", "C_Item.GetItemSpell", "GetBattlefieldStatus", "C_Container.GetItemCooldown", "GetProfessions",
    "C_TooltipInfo.GetMerchantItem", "ConfirmLootSlot", "CompleteLFGRoleCheck", "GetUnitSpeed", "C_DamageMeter.GetCombatSessionSourceFromType",
    "IsRaidMarkerActive", "C_PartyInfo.InviteUnit", "CancelDuel", "C_DamageMeter.ResetAllCombatSessions",
    "GetLootRollItemLink", "AcceptResurrect", "ResurrectGetOfferer", "C_SummonInfo.ConfirmSummon", "C_SummonInfo.GetSummonConfirmSummoner",
}
local ENUMS = {
    "Enum.BagIndex.ReagentBag", "Enum.BagIndex.CharacterBankTab_1", "Enum.BagIndex.Characterbanktab", "Enum.BankType.Character",
    "Enum.PlayerSwingType", "Enum.DamageMeterType", "Enum.DamageMeterSessionType", "Enum.UITextureSliceMode",
    "Enum.StatusBarInterpolation",
}
local EVENTS = { "PLAYER_SWING", "UNIT_HEAL_PREDICTION", "PLAYERBANKSLOTS_CHANGED", "BANK_TABS_CHANGED",
                 "NAME_PLATE_UNIT_ADDED", "GUILDBANKBAGSLOTS_CHANGED", "UNIT_THREAT_LIST_UPDATE", "QUEST_WATCH_LIST_CHANGED" }
local FRAMES = {
    "PlayerFrame", "TargetFrame", "FocusFrame", "PetFrame", "PartyFrame", "CompactRaidFrameContainer", "TotemFrame",
    "MainActionBar", "MicroMenu", "BagsBar", "StatusTrackingBarManager",
    "MinimapCluster", "Minimap", "ObjectiveTrackerFrame", "WorldMapFrame",
    "ContainerFrameCombinedBags", "ContainerFrame1", "BankFrame", "GuildBankFrame", "MerchantFrame",
    "PlayerCastingBarFrame", "OverlayPlayerCastingBarFrame", "ProfessionsFrame", "BuffFrame", "DebuffFrame",
    "PlayerSpellsFrame", "CommunitiesFrame", "GameMenuFrame", "DropDownList1", "DamageMeter",
    "MailFrame", "OpenAllMail", "GroupLootFrame1", "CharacterFrame", "PaperDollItemsFrame", "CharacterStatsPane",
    "CharacterHeadSlot", "CharacterRangedSlot",
}
local LISTED = { "C_DamageMeter", "C_Bank", "C_SwingTimer", "C_NewItems", "C_TradeSkillUI", "Enum.Profession", "Enum.DamageMeterType", "Enum.DamageMeterSessionType",
                 "Enum.BagIndex", "Enum.PlayerSwingType", "Enum.BankType" }

function ns:SelfCheck(quiet)
    local out = {}
    local function add(s) out[#out + 1] = s end
    local function line(label, ok, yes, no) add(format("  %-46s %s", label, ok and (yes or "ok") or (no or "MISSING"))) end

    local ver, build, _, toc = "?", "?", nil, "?"
    pcall(function() ver, build, _, toc = GetBuildInfo() end)
    local theme = ns.themes[ns.db.theme]
    add("Fantasy Glass UI " .. ns.version .. " by " .. ns.author .. " - self-check")
    add(format("Client %s (build %s), interface %s, locale %s", tostring(ver), tostring(build), tostring(toc), tostring(GetLocale and GetLocale() or "?")))
    add(format("Profile: %s   Theme: %s   Lettering: %s   Role: %s", tostring(ns.profile), theme and theme.name or tostring(ns.db.theme),
        tostring(ns.db.fontStyle), tostring(ns.db.role or "not set")))
    add("Rounded corners: " .. (ns.roundOK and (ns.db.rounded and "supported, on" or "supported, off") or "not supported by this client"))
    if ns.safeMode then add("SAFE MODE: on. No feature has been started; /fgui safe leaves it.") end
    add("In combat: " .. (InCombatLockdown() and "yes (some lines below may differ in combat)" or "no"))
    add("Buffs and debuffs in combat: " .. (ns.aurasLocked and "hidden from add-ons on this client (the game's own buff frames are used, restyled)" or "readable, as far as seen"))
    local set, how = ns:TalentSet()
    add("Talent set in use: " .. set .. (how == "none" and " (this client doesn't report one)" or " (from " .. how .. ")")
        .. "   Separate layouts: " .. (ns.db.specLayouts and "on" or "off"))
    add("Talent tree: " .. tostring(ns.talentState or "not opened yet this session"))
    if ns.BagUseState and ns.BagUseState() then add("Using bag items in combat: " .. ns.BagUseState()) end
    if ns.db.rareAlert and ns.rareAlertState then add("Rare spawn alert: " .. ns.rareAlertState) end
    add("Damage meter: " .. (ns.db.damageMeter and (tostring(ns.meterState or "not started")
        .. ((ns.meterTest and ns.meterTest.docked) and (ns.meterTest.IsOpen() and ", out" or ", tucked away") or "")
        .. ((ns.meterTest and ns.meterTest.View) and ("; view: " .. tostring(ns.meterTest.View()) .. " of " .. #ns.meterTest.views) or "")
        .. (ns.db.meterAuto and "; opens itself in combat" or "")
        .. "; breakdown on pointing at a row: " .. tostring(ns.meterBreakdown or "not tried yet")
        .. "; reading: " .. tostring(ns.meterReading or "nothing measured yet this session")) or "feature off"))
    add("Crafting bar: " .. (ns.db.craftBar and (tostring(ns.craftState or "not started")
        .. (ns.craftIconFrom and ("; icon from " .. ns.craftIconFrom) or "")) or "feature off"))
    for _, line in ipairs(ns.craftLast or { "no craft seen yet this session (craft one item, then open this report again)" }) do add("  last craft - " .. line) end
    do
        local moved = ns.AdoptedReport and ns:AdoptedReport() or {}
        if #moved == 0 then add("Game frames you have moved: none") end
        for _, line in ipairs(moved) do add("Moved game frame - " .. line) end
    end
    add("Raid tools: " .. (ns.db.raidTools and tostring(ns.raidToolsState or "not started") or "feature off"))
    add("Chat typing bar: " .. (ns.db.chat and tostring(ns.chatEditState or "not placed") or "left where the game puts it"))
    add("Chat history: " .. (ns.db.chatExtras and tostring(ns.chatHistoryState or "not started") or "off (needs Chat links & copy button)"))
    add("Greed on greens: " .. (ns.db.autoGreed and (tostring(ns.greedState or "not started") .. (ns.greedLast and ("; last roll: " .. ns.greedLast) or "")) or "off"))
    do
        local parts = {}
        for _, t in ipairs(ns.TWEAKS or {}) do parts[#parts + 1] = t.cvar .. " " .. tostring(ns.tweakState and ns.tweakState[t.key] or "not checked") end
        add("Game settings: " .. table.concat(parts, "; "))
    end
    add("Vendors, already known: " .. (ns.db.vendorKnown and tostring(ns.vendorKnownState or "not started") or "off")
        .. "; bind-on-pickup alone: " .. (ns.db.lootBindSolo and tostring(ns.bindSoloState or "not started") or "off")
        .. "; role checks: " .. (ns.db.autoRoleCheck and tostring(ns.roleCheckState or "not started") or "off")
        .. "; combat alerts: " .. (ns.db.combatAlert and ("on" .. (ns.combatAlertLast and (", last: " .. ns.combatAlertLast) or "")) or "off"))
    add("Quest marks on nameplates: " .. (ns.db.plateQuest and tostring(ns.plateQuestState or "not started") or "off")
        .. "; ready check alert: " .. (ns.db.readyAlert and ("on" .. (ns.readyAlertLast and (", last from " .. ns.readyAlertLast) or "")) or "off")
        .. "; cooldown pulse: " .. (ns.db.cooldownPulse and ("on, " .. tostring(ns.pulseCount or 0) .. " shown") or "off"))
    add("Consumables bar: " .. (ns.db.consumeBar and tostring(ns.consumeState or "not started") or "off")
        .. "; timers running: " .. (ns.TimerList and #ns:TimerList() or 0)
        .. "; characters recorded: " .. (ns.Characters and #(ns:Characters()) or 0))
    do
        if ns.EmblemTick then pcall(ns.EmblemTick, ns) end
        local still = (ns.EmblemMoves and not ns.EmblemMoves()) and ((ns.db.reduceMotion and "held still by Reduce motion") or "held still (Animated class emblems is off)") or nil
        add("Class emblems: " .. tostring(ns.emblemCount or 0) .. " on screen, " .. tostring(ns.emblemMoving or 0) .. " moving"
            .. (still and ("; " .. still) or "") .. (ns.emblemError and ("; last problem: " .. ns.emblemError) or "; no problems"))
    end
    do
        local spots = 0
        for _, list in pairs(type(ns.root.rareSpots) == "table" and ns.root.rareSpots or {}) do spots = spots + #list end
        local q = ns.CraftQueue and #ns.CraftQueue() or 0
        add("Quest rewards on the tracker: " .. (ns.db.questRewards and "on" or "off")
            .. "; cooldown timeline: " .. (ns.db.cdTimeline and ("on, " .. tostring(ns.cdTimelineCount or 0) .. " shown") or "off")
            .. "; ready-check report: " .. (ns.db.readyReport and "on" or "off")
            .. "; rares remembered: " .. spots .. (ns.db.rareMemory and "" or " (memory off)"))
        add("Theme by place: " .. tostring(ns.db.themeByPlace and (ns.placeState or "on") or "off")
            .. "; combat text font: " .. tostring(ns.combatTextState or (ns.db.combatTextFont and "on" or "off"))
            .. "; crafting queue: " .. q .. "; goals: " .. (type(ns.db.goals) == "table" and #ns.db.goals or 0)
            .. "; login splash: " .. (ns.db.loginSplash and "on" or "off"))
    end
    add("Fantasy Glass action bars: " .. (ns.db.barEngine and tostring(ns.barEngineState or "switched on; starts after a /reload") or "off (the game's bars, restyled)")
        .. ((ns.engine and ns.engine.bound) and ("; keys bound: " .. ns.engine.bound) or ""))
    add("Custom alerts: " .. (ns.db.customAlerts and (#(ns.Alerts and ns:Alerts() or {}) .. " made, " .. tostring(ns.customAlertsShown or 0) .. " showing") or "off")
        .. "; spoken alerts: " .. (ns.db.speakAlerts and tostring(ns.speakState or "on, nothing said yet") or "off")
        .. "; other add-ons using the API: " .. (#(ns.apiInfoPieces or {}) + #(ns.apiToolWindows or {})) .. " additions"
        .. "; frame designs: " .. (function() local n = 0; for _ in pairs(type(ns.db.ufDesign) == "table" and ns.db.ufDesign or {}) do n = n + 1 end; return n end)())
    if ns.ButtonBagLines then
        local ok, lines = pcall(ns.ButtonBagLines, ns)
        if ok and type(lines) == "table" then for _, line in ipairs(lines) do add(line) end end
    end
    do
        local gs = ns.GuideState and ns.GuideState()
        add("Quest guide: " .. ((ns.GuideUnlocked and not ns:GuideUnlocked()) and "coming soon (locked)" or ns.db.questGuide == false and "off" or (gs and ("following \"" .. tostring(gs.name) .. "\", step " .. tostring(gs.at)) or "on, not following one"))
            .. "; guides saved: " .. (ns.GuideNames and #ns:GuideNames() or 0) .. (ns.guideRecording and "; recording" or ""))
    end
    -- 10.0.0
    local function st(key, state, extra) return ns.db[key] and (tostring(state or "on") .. (extra or "")) or "off" end
    add("Missing buff reminder: " .. st("buffMissing", ns.buffMissingState)
        .. "; focus cast alert: " .. st("focusCastAlert", nil, ", " .. tostring(ns.focusCastCount or 0) .. " seen")
        .. "; execute line: " .. st("executeLine", ns.executeState)
        .. "; loss of control: " .. st("locAlert", ns.locState, ", " .. tostring(ns.locCount or 0) .. " shown"))
    add("Quick keys: " .. st("quickKeys", ns.quickKeysState))
    add("Travel bar: " .. st("travelBar", ns.travelState) .. "; open-all button: " .. st("openAll", ns.openAllState)
        .. "; boss timer: " .. st("bossTimer", ns.bossTimerState) .. "; queue alerts: " .. st("queueAlert", nil, ", " .. tostring(ns.queueAlertCount or 0) .. " given")
        .. "; combat log: " .. st("autoCombatLog", ns.combatLogState))
    add("Flight timer: " .. st("flightTimer", ns.flightState) .. "; fishing mode: " .. st("fishingMode", ns.fishingState)
        .. "; smaller map: " .. st("smallMap", ns.smallMapState) .. "; group on map: " .. st("mapGroup", ns.mapGroupState)
        .. "; minimap pings named: " .. tostring(ns.pingCount or 0) .. "; tracking menu opened by: " .. tostring(ns.trackingOpened or "not tried"))
    local kept = 0
    for _ in pairs(ns.PriceItems()) do kept = kept + 1 end
    add("Auction prices: " .. st("auctionMemory", ns.auctionState) .. "; prices kept here: " .. kept .. "; scan prices: " .. st("auctionScan", ns.priceScanState) .. "; loot logged: " .. tostring(ns.lootLog and #ns.lootLog or 0)
        .. "; rolls seen: " .. tostring(ns.rolls and #ns.rolls or 0) .. "; chat names: " .. st("chatNames", ns.chatNamesState)
        .. "; keyword hits: " .. tostring(ns.keywordHits or 0) .. "; repeated lines hidden: " .. tostring(ns.spamHidden or 0))
    add("Short commands: " .. st("shortCommands", ns.shortCommandsState) .. "; friends list colors: " .. st("friendColors", ns.friendColorsState, ", " .. tostring(ns.friendColored or 0) .. " colored")
        .. "; talent set buttons: " .. st("specButtons", ns.specButtonsState) .. "; missing enchants: " .. st("enchantCheck", ns.enchantState)
        .. "; talking head: " .. st("talkingHeadHide", ns.talkingHeadState) .. "; raid graphics: " .. st("raidGraphics", ns.raidGraphicsState)
        .. "; shared media library: " .. ((ns.SharedMedia and ns.SharedMedia()) and "present" or "not present"))
    add("Gear sets follow talent set: " .. (ns.db.setsFollowSpec and tostring(ns.specSetState or "not started") or "off"))
    add("Whisper invites: " .. (ns.db.whisperInvite and (tostring(ns.whisperInviteState or "not started") .. ", word \"" .. (ns.InviteWord and ns:InviteWord() or "inv") .. "\", "
        .. (ns.db.whisperInviteAll and "from anyone" or "friends and guild only")) or "off") .. "; decline duels: " .. (ns.db.declineDuels and tostring(ns.duelState or "not started") or "off"))
    add("Gear set buttons: " .. (ns.db.equipSets and tostring(ns.setsState or "not started") or "feature off"))
    add("Done for you: stand up " .. (ns.db.autoStand and tostring(ns.standState or "not started") or "off")
        .. "; dismount " .. (ns.db.autoDismount and tostring(ns.dismountState or "not started") or "off")
        .. "; resurrections " .. (ns.db.autoRes and tostring(ns.resState or "not started") or "off")
        .. "; summons " .. (ns.db.autoSummon and tostring(ns.summonState or "not started") or "off"))
    if ns.db.vendorStack and ns.vendorStackState then add("Alt-click to buy a stack: " .. ns.vendorStackState) end
    if ns.db.chatClassColors and ns.chatClassState then add("Class-colored names in chat: " .. ns.chatClassState) end
    do
        local moved = 0
        for _ in pairs(type(ns.db.windowPos) == "table" and ns.db.windowPos or {}) do moved = moved + 1 end
        if moved > 0 then add("Game windows you have moved: " .. moved .. "  (/fgui windows reset puts them back)") end
    end
    if ns.newestSeen then add("A newer version has been seen from another player: " .. ns.newestSeen) end
    if ns.GameAuraReport then add("The game's buff rows: " .. ns:GameAuraReport()) end
    if ns.CooldownTrackerState then add("Cooldown tracker: " .. ns:CooldownTrackerState()) end
    add("Resource text on frames and nameplates: " .. (ns.PowerTextState and ns:PowerTextState() or "unit frames are off"))
    if ns.PowerPercentProbe then add("  what the game answers for a percentage, each way of asking: " .. ns:PowerPercentProbe()) end
    add("Health text: " .. (ns.db.healthNumbers and ("numbers (" .. tostring(ns.healthTextMode or "not drawn yet") .. ")") or "percentage"))
    add("Class extras: " .. tostring(ns.classBarState and ns.classBarState() or (ns.db.classBar and "not started" or "feature off")))
    add("Other add-ons' info-bar data: " .. tostring(ns.brokerState or (ns.db.infobarPlugins and "not started" or "feature off")))
    add("Totems: " .. tostring(ns.totemState or (ns.db.totems and "no totem seen yet" or "feature off")))
    add("Raid frames: " .. (ns.raidMode == "game" and "the game's own, restyled (they can show debuffs and heals in combat)" or ns.raidMode == "ours" and "Fantasy Glass UI's own" or "off"))
    -- what the game refused to let the add-on do (its add-on list calls these "Interface actions failed")
    for _, line in ipairs(ns.BlockedLines and ns:BlockedLines(12) or {}) do add(line) end
    pcall(function()
        if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            UpdateAddOnMemoryUsage()
            local before = GetAddOnMemoryUsage(ADDON)
            collectgarbage("collect")                              -- clear out short-lived working memory, then measure again
            UpdateAddOnMemoryUsage()
            local after = GetAddOnMemoryUsage(ADDON)
            add(format("Memory: %.0f KB in use, %.0f KB after a clean-up (the difference was short-lived working memory)", before, after))
            add(format("  plus %.0f KB for the options, setup and self-check, which load only when one is opened (as now, for this report)",
                tonumber(GetAddOnMemoryUsage(ns.optionsAddon or "FantasyGlassUI_Options")) or 0))
            local tr = tonumber(GetAddOnMemoryUsage(ns.localesAddon or "FantasyGlassUI_Locales")) or 0
            add(tr > 0 and format("  plus %.0f KB for the translations (loaded for a language other than English; the others are let go after login)", tr)
                or "  translations: not loaded (English needs none)")
        end
    end)
    if ns.CostRows and ns.moduleCost then                          -- what each feature took to start (Safety.lua)
        local rows = ns.CostRows(ns.moduleCost)
        local ms = 0
        for _, r in ipairs(rows) do ms = ms + r.ms end
        add(format("Starting the features at login took %.0f ms; the heaviest (time, memory then; /fgui perf load lists all):", ms))
        for i = 1, math.min(8, #rows) do add(format("  %s: %.1f ms, about %.0f KB", rows[i].key, rows[i].ms, math.max(0, rows[i].kb))) end
    end

    add("")
    add("ERRORS THIS SESSION")
    if #ns.errors == 0 then add("  none") end
    for _, e in ipairs(ns.errors) do add("  " .. e) end

    add("")
    add("FEATURES  (switched on in options / actually running)")
    local listed = {}
    for _, m in ipairs(ns.modules) do
        if not listed[m.key] and m.key ~= "fallbacks" then
            listed[m.key] = true
            local state = ns.loaded[m.key] and "running" or (ns.db[m.key] and "NOT RUNNING" or "")
            if ns.steppedAside[m.key] then state = "left to " .. ns.steppedAside[m.key] .. " (another add-on that does this)" end
            if ns.aurasLocked and ns.db[m.key] then
                if m.key == "auraBars" or m.key == "raidFrames" then state = "the game's own, restyled"
                elseif m.key == "buffAlerts" then state = "not available on this client" end
            end
            add(format("  %-20s %-4s %s", m.key, ns.db[m.key] and "on" or "off", state))
        end
    end

    add("")
    add("GAME FUNCTIONS")
    local faults = {}
    for _, path in ipairs(FUNCTIONS) do
        local text, fault = ns.CheckFunctionLine(path)
        add(format("  %-46s %s", path, text))
        if fault then faults[#faults + 1] = path end
    end
    add(#faults == 0 and "  => Nothing the add-on needs is missing." or ("  => Missing with nothing to use instead: " .. table.concat(faults, ", ")))
    add("")
    add("ENUMS")
    for _, path in ipairs(ENUMS) do line(path, Resolve(path) ~= nil) end

    add("")
    add("EVENTS")
    local probe = CreateFrame("Frame")
    for _, ev in ipairs(EVENTS) do
        local ok = pcall(probe.RegisterEvent, probe, ev)
        line(ev, ok, "ok", "not an event here")
    end
    probe:UnregisterAllEvents()

    add("")
    add("DRAWING")
    local tex = ns.hidden:CreateTexture()
    line("Texture:SetTextureSliceMargins (rounded corners)", tex.SetTextureSliceMargins ~= nil)
    line("Texture:SetGradient (sheen, shadows)", tex.SetGradient ~= nil)
    line("Texture:SetColorTexture", tex.SetColorTexture ~= nil)
    line("Frame:SetAlphaFromBoolean (range dimming in combat)", probe.SetAlphaFromBoolean ~= nil)
    line("Frame:SetClipsChildren (incoming heals)", probe.SetClipsChildren ~= nil)
    local okCd, cd = pcall(CreateFrame, "Cooldown", nil, ns.hidden, "CooldownFrameTemplate")
    line("Cooldown:SetCooldownFromExpirationTime (aura timers)", okCd and type(cd) == "table" and cd.SetCooldownFromExpirationTime ~= nil)

    add("")
    add("BLIZZARD FRAMES")
    for _, name in ipairs(FRAMES) do line(name, type(_G[name]) == "table", "present", "absent") end

    local micro = _G.MicroMenu
    if type(micro) == "table" and micro.GetChildren then
        add("")
        add("MICRO MENU BUTTONS")
        for _, child in ipairs({ micro:GetChildren() }) do
            local name = type(child) == "table" and child.GetName and child:GetName()
            if type(name) == "string" then add("  " .. name) end
        end
    end

    add("")
    add("WHAT THE CLIENT OFFERS  (names only)")
    for _, path in ipairs(LISTED) do
        local t = Resolve(path)
        if type(t) == "table" then
            local keys = {}
            for k in pairs(t) do if type(k) == "string" then keys[#keys + 1] = k end end
            table.sort(keys)
            if #keys > 60 then for i = #keys, 61, -1 do keys[i] = nil end; keys[#keys + 1] = "..." end
            add("  " .. path .. ": " .. (#keys > 0 and table.concat(keys, ", ") or "(empty)"))
        else
            add("  " .. path .. ": not present")
        end
    end

    if not quiet then ns:ShowTextWindow("Self-check", table.concat(out, "\n")) end
    return out
end


-- /fgui strings: every label the add-on has shown this session, laid out ready to paste into
-- Locales.lua and translate.
function ns:ExportStrings()
    local keys = {}
    for text in pairs(ns.seenStrings) do keys[#keys + 1] = text end
    table.sort(keys)
    local out = { "-- Paste into Locales.lua, change xxXX to your language code, fill in the right-hand side.",
                  "-- Open every options tab first so all labels are collected. " .. #keys .. " labels so far.", "",
                  "ns.locales.xxXX = {" }
    for _, text in ipairs(keys) do
        out[#out + 1] = format("    [%q] = \"\",", text)
    end
    out[#out + 1] = "}"
    ns:ShowTextWindow("Labels to translate", table.concat(out, "\n"))
    return #keys
end


-- /fgui tree            the window under the mouse
-- /fgui tree FrameName  a window by name
-- Shows how one of the game's windows is built: frames, their kind, name, and the named pieces each
-- carries. It reads only names and kinds, never values. Runs of look-alike siblings (twenty equipment
-- slots, a list's rows) are shown once and then counted, so the whole window fits.
local function UnderMouse()
    local f
    if GetMouseFoci then
        local list = GetMouseFoci()
        f = type(list) == "table" and list[1] or nil
    end
    if type(f) ~= "table" or f == _G.WorldFrame or f == UIParent or not ns:Usable(f) then return nil end
    local top = f
    for _ = 1, 40 do                                   -- climb to the window itself
        local p = top.GetParent and top:GetParent()
        if not p or p == UIParent or p == _G.WorldFrame then break end
        top = p
    end
    return top
end

function ns:DumpTree(root, maxDepth)
    local frame
    if root == nil or root == "" then
        frame = UnderMouse()
        if not frame then
            ns:Print("Put the mouse over the window first, then type /fgui tree (or name it: /fgui tree CharacterFrame).")
            return
        end
    elseif root == "target" or root == "nameplate" then      -- your target's nameplate (it can't be hovered like a window)
        frame = C_NamePlate and C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
        if not frame then
            ns:Print("Target something whose nameplate is on screen, then type /fgui tree target.")
            return
        end
    else
        frame = type(root) == "string" and _G[root] or root
    end
    if type(frame) ~= "table" or not frame.GetObjectType then
        ns:Print("No frame called '%s'. Put the mouse over the window and type /fgui tree instead.", tostring(root))
        return
    end
    maxDepth = maxDepth or 7
    local out, count = {}, 0

    local function pieces(f)                            -- named pieces that are themselves widgets
        local keys = {}
        for k, v in pairs(f) do
            if type(k) == "string" and k:sub(1, 3) ~= "sui" and type(v) == "table" and type(rawget(v, 0)) == "userdata" then
                local kind = "?"
                pcall(function() kind = v:GetObjectType() end)
                keys[#keys + 1] = k .. ":" .. kind
            end
        end
        table.sort(keys)
        if #keys > 30 then for i = #keys, 31, -1 do keys[i] = nil end; keys[#keys + 1] = "..." end
        return table.concat(keys, " ")
    end
    local function nameOf(f)
        local n = f.GetName and f:GetName()
        return type(n) == "string" and n or nil
    end
    local function shape(f)                             -- what makes two siblings "the same kind of thing"
        local ok, s = pcall(function()
            local regions = f.GetRegions and select("#", f:GetRegions()) or 0
            local kids = f.GetChildren and select("#", f:GetChildren()) or 0
            return f:GetObjectType() .. "|" .. pieces(f) .. "|" .. regions .. "|" .. kids
        end)
        return ok and s or tostring(f)
    end
    local function describe(f)
        local parts = { f:GetObjectType() }
        local name = nameOf(f)
        if name then parts[#parts + 1] = name end
        if f.IsShown and not f:IsShown() then parts[#parts + 1] = "(hidden)" end
        local keys = pieces(f)
        if keys ~= "" then parts[#parts + 1] = "{" .. keys .. "}" end
        return table.concat(parts, " ")
    end

    local function walk(f, depth)
        if count >= 700 then return end
        count = count + 1
        local ok, line = pcall(describe, f)
        out[#out + 1] = string.rep("  ", depth) .. (ok and line or "?")
        if depth >= maxDepth or not f.GetChildren then return end
        local unnamed = 0
        if f.GetRegions then
            for _, r in ipairs({ f:GetRegions() }) do
                local n = type(r) == "table" and nameOf(r)
                if n then
                    out[#out + 1] = string.rep("  ", depth + 1) .. "- " .. r:GetObjectType() .. " " .. n .. " [" .. tostring(r.GetDrawLayer and r:GetDrawLayer() or "") .. "]"
                else
                    unnamed = unnamed + 1
                end
            end
        end
        if unnamed > 0 then out[#out + 1] = string.rep("  ", depth + 1) .. "- " .. unnamed .. " unnamed texture/text piece(s)" end

        local last, repeats, names = nil, 0, {}
        local function flush()
            if repeats > 0 then
                local list = #names > 0 and (": " .. table.concat(names, ", ", 1, math.min(#names, 12)) .. (#names > 12 and ", ..." or "")) or ""
                out[#out + 1] = string.rep("  ", depth + 1) .. "(+" .. repeats .. " more built like the one above" .. list .. ")"
            end
            repeats, names = 0, {}
        end
        for _, child in ipairs({ f:GetChildren() }) do
            if type(child) == "table" and child.GetObjectType and not (child.IsForbidden and child:IsForbidden()) then
                local s = shape(child)
                if s == last then
                    repeats = repeats + 1
                    local n = nameOf(child)
                    if n then names[#names + 1] = n end
                else
                    flush()
                    last = s
                    walk(child, depth + 1)
                end
            end
        end
        flush()
    end
    walk(frame, 0)
    if count >= 700 then out[#out + 1] = "... (stopped at 700 frames)" end
    local title = nameOf(frame) or "(unnamed window)"
    table.insert(out, 1, "Window: " .. title)
    ns:ShowTextWindow("Structure of " .. title, table.concat(out, "\n"))
    return #out
end


-- /fgui report (and the "Report a problem" button): everything someone needs to see to help, in one
-- block of text to copy. It is the self-check, plus the settings that differ from how the add-on
-- comes, plus the other add-ons that are running. Nothing is sent anywhere; it is only shown.
-- The address reports should go to (Contact.lua), tidied: nothing that could be read as formatting
-- codes or run over several lines, and not absurdly long. nil when none is set.
function ns:ReportLink()
    local link = ns.reportLink
    if type(link) ~= "string" then return nil end
    link = link:gsub("[%c|]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if link == "" then return nil end
    return link:sub(1, 200)
end

function ns:ProblemReport()
    local out = {
        "WHAT WENT WRONG  (write a line or two here before you save or send this)",
        "",
        "",
        "----------------------------------------------------------------------",
    }
    for _, line in ipairs(ns:SelfCheck(true)) do out[#out + 1] = line end

    out[#out + 1] = ""
    out[#out + 1] = "SETTINGS CHANGED FROM THE DEFAULTS"
    local changed = {}
    for key, default in pairs(ns.defaults) do
        local value = ns.db[key]
        local kind = type(default)
        if (kind == "boolean" or kind == "number" or kind == "string") and value ~= default and type(value) == kind then
            changed[#changed + 1] = format("  %-18s %s  (default %s)", key, tostring(value), tostring(default))
        end
    end
    table.sort(changed)
    if #changed == 0 then changed[1] = "  none" end
    for _, line in ipairs(changed) do out[#out + 1] = line end
    local moved, scaled = 0, 0
    for _ in pairs(ns.db.pos or {}) do moved = moved + 1 end
    for _ in pairs(ns.db.scale or {}) do scaled = scaled + 1 end
    out[#out + 1] = format("  panels moved: %d   panels rescaled: %d", moved, scaled)

    out[#out + 1] = ""
    out[#out + 1] = "OTHER ADD-ONS RUNNING"
    local names = {}
    pcall(function()
        local count = C_AddOns.GetNumAddOns()
        local info = C_AddOns.GetAddOnInfo
        local loaded = C_AddOns.IsAddOnLoaded
        for i = 1, math.min(tonumber(count) or 0, 300) do
            local name = info(i)
            if type(name) == "string" and name ~= ADDON and loaded(i) then names[#names + 1] = name end
        end
    end)
    table.sort(names)
    if #names == 0 then
        out[#out + 1] = "  none found"
    else
        local row = "  "
        for _, name in ipairs(names) do
            if #row + #name > 96 then out[#out + 1] = row; row = "  " end
            row = row .. name .. "   "
        end
        out[#out + 1] = row
    end
    local alt = ns.discordInvite and { label = "Or attach the saved file in #bug-reports on Discord:", link = ns.discordInvite } or nil
    ns:ShowTextWindow("Report a problem", table.concat(out, "\n"), false, ns:ReportLink(), alt)
    return out
end

------------------------------------------------------------------------------------------
-- /fgui check new (11.9): each feature added since 11.6, tried once where that is safe, and a
-- report of what works. Nothing is changed: whatever a check makes (a pack, a template profile)
-- is made in memory and thrown away. Each line says OK, OFF (switched off), WAIT (needs a place or
-- a moment: the auction house, a fight) or CHECK (something to look at), with what was found.
------------------------------------------------------------------------------------------
function ns:CheckNew(quiet)
    local out, counts = {}, { OK = 0, OFF = 0, WAIT = 0, CHECK = 0 }
    local function add(s) out[#out + 1] = s end
    local function res(state, label, detail)
        counts[state] = counts[state] + 1
        add(format("  %-5s %-34s %s", state, label, detail or ""))
    end
    local function try(label, fn)
        local ok, state, detail = pcall(fn)
        if not ok then res("CHECK", label, "error: " .. tostring(state)) else res(state or "OK", label, detail) end
    end
    local function on(key) return ns.db[key] and true or false end
    add("Fantasy Glass UI " .. ns.version .. " - check of the new features (11.6 to 11.9)")
    add(format("Theme %s (%s)   Language %s   Group: %s", tostring(ns.db.theme), tostring(ns.style), tostring(ns.Language and ns:Language() or "?"),
        (ns.GroupChannel and ns.GroupChannel()) or "none"))
    add("")
    add("11.6")
    try("Execute line (enemies only)", function()
        if not on("executeLine") then return "OFF" end
        return "OK", tostring(ns.executeState or "waiting for a target")
    end)
    try("Group practice", function()
        if type(ns.ToggleTestGroup) ~= "function" then return "CHECK", "not loaded" end
        local off = {}
        for _, k in ipairs({ "groupCDs", "kickRotation", "buffCoverage" }) do if not on(k) then off[#off + 1] = k end end
        return "OK", (#off > 0) and ("ready; switched off, so not shown: " .. table.concat(off, ", ")) or "ready: /fgui testgroup"
    end)
    try("Translations folder", function()
        local lang = ns.Language and ns:Language()
        if lang == "enUS" or lang == "enGB" or (lang == "auto" and (GetLocale() == "enUS" or GetLocale() == "enGB")) then
            return "OK", "English: not needed, not loaded"
        end
        return (ns.localesState == "loaded" or ns.locales[GetLocale()]) and "OK" or "CHECK", tostring(ns.localesState or "not asked for")
    end)
    try("Arena enemy frames", function()
        if not on("ufArena") then return "OFF", "Frames and bars › Party, boss and arena" end
        local n = #(ns.arenaFrames or {})
        if n == 0 then return "WAIT", "switched on since you logged in: /reload to make them" end
        return (n == 5) and "OK" or "CHECK", format("%d frames made; they show in an arena (or with /fgui test)", n)
    end)
    try("Enemy cooldowns", function()
        if not on("enemyCDs") then return "OFF" end
        return "OK", tostring(ns.enemyCDState or "waiting for an arena or battleground")
    end)
    try("Upgrade arrows", function()
        if not on("upgradeArrows") then return "OFF" end
        return ns.upgradeTest and "OK" or "CHECK", ns.upgradeTest and "hooks in place (quest rewards, the game's bags, tooltips)" or "not started"
    end)
    try("Equip best", function()
        return type(ns.EquipBest) == "function" and "OK" or "CHECK", "/fgui equipbest or the bags' button"
    end)
    try("New characters copy your main", function()
        local root = ns.root
        local n = 0
        for _ in pairs(type(root.charInfo) == "table" and root.charInfo or {}) do n = n + 1 end
        return "OK", format("%s; main: %s; %d characters noted", root.altCopy == false and "switched off" or "on",
            tostring(root.mainChar or "the one played last"), n)
    end)
    add("")
    add("11.7")
    try("Am I ready?", function()
        local f = ns:ReadyMeFacts()
        local lines = ns.ReadyMeLines(f)
        local unread = 0
        for _, l in ipairs(lines) do if l.ok == nil and l.text == "could not be read" then unread = unread + 1 end end
        if InCombatLockdown() then return "WAIT", "out of a fight" end
        return (unread == 0) and "OK" or "CHECK", format("%d lines%s", #lines, unread > 0 and ", buffs could not be read" or "")
    end)
    try("Boss notes", function()
        if not on("bossNotes") then return "OFF" end
        local n = 0
        for _ in pairs(type(ns.root.bossNotes) == "table" and ns.root.bossNotes or {}) do n = n + 1 end
        return "OK", format("%d of your own; target a boss and /fgui bossnote", n)
    end)
    try("Death recap", function()
        if not on("deathRecap") then return "OFF" end
        local d = ns.deathRecap
        return "OK", (d and d.last) and format("last death: %d lines", #d.last.events) or format("listening (%d recent events)", d and #d.list or 0)
    end)
    try("Auction house helper", function()
        if not on("auctionHelper") then return "OFF" end
        local seen = 0
        for _ in pairs(ns.PriceItems()) do seen = seen + 1 end
        local ahf = _G.AuctionHouseFrame
        if type(ahf) ~= "table" then return "WAIT", format("open the auction house, then check again (%d prices seen)", seen) end
        local sf = ahf.ItemSellFrame or ahf.CommoditiesSellFrame
        local input = type(sf) == "table" and (sf.PriceInput or sf.UnitPriceInput)
        return (type(input) == "table" and input.SetAmount) and "OK" or "CHECK",
            format("sell page price box %s; %d prices seen", (type(input) == "table" and input.SetAmount) and "found" or "NOT found", seen)
    end)
    try("Home key", function()
        if not on("homeKey") then return "OFF" end
        local key = _G.FantasyGlassUIHomeKey
        if type(key) ~= "table" then return "CHECK", tostring(ns.homeKeyState or "no button") end
        local kind = key:GetAttribute("type")
        local bound = GetBindingKey and GetBindingKey("CLICK FantasyGlassUIHomeKey:LeftButton")
        return kind and "OK" or "CHECK", format("%s %s; key: %s", tostring(kind or "nothing set"),
            tostring(key:GetAttribute("spell") or key:GetAttribute("item") or ""), tostring(bound or "not bound (Key Bindings, AddOns)"))
    end)
    try("Backups", function()
        local lines = ns.BackupLines(ns.root.backups, time())
        local kinds = {}
        for _, l in ipairs(lines) do kinds[#kinds + 1] = l.kind .. " (" .. l.when .. ")" end
        return (#lines > 0) and "OK" or "CHECK", (#lines > 0) and table.concat(kinds, ", ") or "none yet"
    end)
    try("Changes to this profile", function()
        ns:NoteSettingChanges()
        local h = type(ns.root.history) == "table" and ns.root.history[ns.profile]
        return h and h.snapshot and "OK" or "CHECK", format("%d changes noted", h and #h.changes or 0)
    end)
    try("Whole-UI pack", function()
        local text = ns:ExportPack()
        local kind, data = ns:DecodeShared(text)
        if kind ~= "pack" then return "CHECK", "the pack did not read back: " .. tostring(data) end
        return "OK", format("%d characters%s", #text, data.editMode and ", with the game's Edit Mode layout" or ", no Edit Mode layout (the client gives none)")
    end)
    try("Role templates", function()
        local t = ns.TemplateProfile("HEALER", ns.db)
        return (t and t.role == "HEALER") and "OK" or "CHECK", "Tank, Healer and Damage in Layout and profiles › Profiles"
    end)
    try("Coming from another UI", function()
        local found = ns.OtherUIsFound()
        return "OK", (#found > 0) and ("found " .. found[1].addon .. ": the setup marks it") or "none of the others installed"
    end)
    try("Measure a fight", function() return "OK", "/fgui perf fight, then fight" end)
    try("Feature costs at login", function()
        local rows = ns.CostRows(ns.moduleCost)
        return (#rows > 0) and "OK" or "CHECK", format("%d features measured", #rows)
    end)
    add("")
    add("11.8 and 11.9 (Celestial since 11.11)")
    try("Celestial themes", function()
        local n = 0
        for _, key in ipairs(ns.themeOrder) do local t = ns.themes[key]; if t and t.style == "CELESTIAL" and not t.custom then n = n + 1 end end
        return (n == 39) and "OK" or "CHECK", format("%d celestial themes; this one is %s", n, tostring(ns.style))
    end)
    try("Celestial art", function()
        if ns.style ~= "CELESTIAL" then return "OK", "shown with a Celestial theme (pick one and /reload to see it)" end
        return ns.minimapRunes and "OK" or "CHECK", ns.minimapRunes and "minimap star frame in place" or "no minimap star frame (is the minimap switched off?)"
    end)
    try("Language names", function()
        local fam = _G.GameFontHighlight
        return "OK", (type(fam) == "table") and "Korean and Chinese use the game's font family" or "Korean and Chinese use the font files by name"
    end)
    try("Theme previews", function() return "OK", "a picture on each theme button in Look and themes › Themes" end)
    add("")
    add(format("%d OK, %d switched off, %d waiting for a place or moment, %d to look at.", counts.OK, counts.OFF, counts.WAIT, counts.CHECK))
    if not quiet then ns:ShowTextWindow("Check of the new features", table.concat(out, "\n")) end
    return out, counts
end
