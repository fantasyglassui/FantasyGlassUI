-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- Where every setting lives (12.0). The settings window lists these categories down its left side,
-- and under the one that is open, its sections. A section shows:
--   rows    switches and sliders, one to a line with what each does: a key of ns.featureGroups is a
--           feature's switch; any other name is one of ns.settingRows below
--   blocks  the larger pieces under them: a slice of one of the pages the window builds (from one
--           heading to another), a set of frame or bar designers to choose between, one of your
--           lists or rules, or a few boxes of their own
-- simple = true: shown in simple settings even with none of the everyday switches in it.

-- Settings that are not a feature's switch: a box, a slider, a button that steps through choices or
-- does something. Each says what it does (shown under its name and, in full, on pointing at it).
local function After(name) return function() if ns[name] then pcall(ns[name], ns) end end end
local function Settle(name)                                  -- (applied once the slider stops: these redraw everything)
    local waiting = 0
    return function()
        waiting = waiting + 1
        local mine = waiting
        ns:After(0.6, function() if waiting == mine and ns[name] then pcall(ns[name], ns) end end)
    end
end
local function Volume()
    local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local ok, v = pcall(Get, "Sound_MasterVolume")
    return math.floor(((ok and tonumber(v)) or 1) * 100 + 0.5)
end
ns.settingRows = {
    -- switches that take effect at once
    smoothBars    = { kind = "check", label = "Bars glide to their new value", desc = "Health and power bars slide to a new value instead of jumping." },
    fades         = { kind = "check", label = "Windows fade in, alerts pop", desc = "Windows fade in as they open, and alerts pop up instead of appearing." },
    hitFlash      = { kind = "check", label = "Flash on critical hits and heals", desc = "Your frame flashes for a moment on a critical hit or heal." },
    idleFade      = { kind = "check", label = "Dim my frame when idle", desc = "Your own frame fades out while you are at full health and out of combat." },
    imbueCombatOnly = { kind = "check", label = "Imbue reminder only in combat", desc = "The weapon imbue reminder shows only while you fight." },
    combatFocus   = { kind = "check", label = "Dim tracker and info bar in fights", desc = "The quest tracker and the info bar fade back while you fight." },
    tooltipCursor = { kind = "check", label = "Tooltips follow the mouse", desc = "Tooltips sit by the mouse pointer instead of in the corner." },
    emblemAnim    = { kind = "check", label = "Animated class emblems", desc = "The class emblems on portraits shimmer gently." },
    -- sliders
    ufW       = { kind = "slider", label = "Player / Target width", min = 160, max = 340, step = 4, apply = After("ResizeUnitFrames"), desc = "How wide the player and target frames are." },
    ufH       = { kind = "slider", label = "Player / Target height", min = 32, max = 72, step = 2, apply = After("ResizeUnitFrames"), desc = "How tall the player and target frames are." },
    partyW    = { kind = "slider", label = "Party width", min = 120, max = 260, step = 4, apply = After("ResizeUnitFrames"), desc = "How wide each party frame is." },
    partyH    = { kind = "slider", label = "Party height", min = 24, max = 56, step = 2, apply = After("ResizeUnitFrames"), desc = "How tall each party frame is." },
    barScale  = { kind = "slider", label = "Action bar size %", min = 70, max = 140, step = 5, apply = After("ApplyBarScale"), desc = "The size of every action bar. Each bar can be sized again on its own, below." },
    chatBg    = { kind = "slider", label = "Chat background %", min = 0, max = 80, step = 5, apply = After("ApplyChatBackground"), desc = "How dark the chat background is. 0 is none." },
    bubbleFont = { kind = "slider", label = "Chat bubble text size", min = 9, max = 20, step = 1, desc = "The size of the text in chat bubbles." },
    infobarBg = { kind = "slider", label = "Info bar background %", min = 0, max = 100, step = 5, apply = After("ApplyInfoBarBg"), desc = "How dark the info bar's background is. 0 is none." },
    panelAlpha = { kind = "slider", label = "HUD panel opacity %", min = 40, max = 100, step = 2, apply = After("Retheme"), desc = "How solid the panels on your screen are: unit frames, bars, minimap." },
    windowAlpha = { kind = "slider", label = "Window opacity %", min = 60, max = 100, step = 1, apply = After("Retheme"), desc = "How solid windows are: bags, these settings, lists." },
    uiScale   = { kind = "slider", label = "Interface size %", min = 50, max = 150, step = 5, apply = Settle("ApplyPixelScale"), desc = "The size of the whole interface, as a share of the game's own scale. 100 is as it came. Takes effect when you let go." },
    fontScale = { kind = "slider", label = "Text size %", min = 70, max = 150, step = 5, apply = Settle("Retheme"), desc = "The size of all the add-on's lettering. 100 is as it came. Takes effect when you let go." },
    executePct = { kind = "slider", label = "Execute line at %", min = 5, max = 50, step = 5, default = 20,
                   apply = function() if ns.executeTest then pcall(ns.executeTest.Place) end end, desc = "Where the execute line sits on the target's health bar." },
    mapSize   = { kind = "slider", label = "Smaller world map %", min = 40, max = 100, step = 5, default = 75,
                  apply = function() if ns.smallMapTest then pcall(ns.smallMapTest.Apply) end end, desc = "How big the smaller world map is." },
    volume    = { kind = "slider", label = "Master volume %", min = 0, max = 100, step = 5, get = Volume,
                  set = function(v) local Set = (C_CVar and C_CVar.SetCVar) or SetCVar; if type(Set) == "function" then pcall(Set, "Sound_MasterVolume", tostring(v / 100)) end end,
                  desc = "The game's master volume, without opening its sound settings." },
    -- accessibility (12.1)
    colorblind    = { kind = "check", label = "Color-blind safe colors", apply = After("Retheme"),
                      desc = "Good and bad are shown in colors chosen for your kind of color vision (below), debuffs get a letter, item quality gets dots, and threat gets a mark." },
    colorVision   = { kind = "cycle", label = "Color vision", choices = { "redgreen", "blueyellow", "none" }, default = "redgreen", apply = After("Retheme"),
                      names = { redgreen = "Red-green", blueyellow = "Blue-yellow", none = "No color" },
                      desc = "Red-green: the most common, blue and orange. Blue-yellow: teal, pink and red. No color: brightness and marks only." },
    readableFont  = { kind = "cycle", label = "Readable lettering", choices = { "off", "READABLE", "DYSLEXIC" },
                      names = { off = "As chosen", READABLE = "Readable", DYSLEXIC = "Dyslexia-friendly" },
                      get = function() return ns:ReadableFont() end, set = function(v) ns:SetReadableFont(v) end,
                      desc = "Readable: Atkinson Hyperlegible, made for low vision. Dyslexia-friendly: OpenDyslexic, with weighted letters that are hard to flip. Western European letters only." },
    textOutline   = { kind = "cycle", label = "Outline round letters", choices = { "normal", "thin", "thick" }, default = "normal", apply = After("Retheme"),
                      names = { normal = "As the lettering has it", thin = "Thin", thick = "Thick" },
                      desc = "A dark outline round every letter, so text stands out from what is behind it." },
    textBands     = { kind = "check", label = "Dark band behind messages", desc = "Messages in the middle of the screen sit on a dark band, so they read over anything." },
    targetOutline = { kind = "slider", label = "Outline round my target (pixels)", min = 0, max = 8, step = 1,
                      desc = "A thick ring round your target's nameplate, so it stands out in a crowd. 0 is off. Shows on the next target you pick." },
    reduceMotion  = { kind = "check", label = "Reduce motion", apply = After("Retheme"), desc = "No fades, pulses, gliding bars or camera drift: things appear and change at once." },
    safeFlash     = { kind = "check", label = "Safe flashing", apply = After("ApplySafeFlash"),
                      desc = "Nothing flashes more than three times a second, flashes are gentle, pulsing warnings hold still, and the game's red low-health flash is off where this client allows it." },
    calmMode      = { kind = "check", label = "Calm mode", desc = "One notification at a time, held for fifteen seconds and put away with a click; messages stay up longer; captions wait their turn." },
    bigControls   = { kind = "check", label = "Bigger controls in the settings", desc = "Larger switches and lines in this window, and \"click twice\" buttons wait ten seconds for the second click." },
    keyNav        = { kind = "check", label = "Move through the settings with the keyboard",
                      desc = "Tab or the arrow keys go from setting to setting, Space or Enter switches one, Left and Right move a slider, Page Up and Page Down change section. While this window is open, those keys do nothing else." },
    readNow       = { kind = "button", label = "Read aloud now", run = function() ns:ReadAloud() end,
                      desc = "Reads what is under the mouse, the quest you are reading, or the last whisper. Give it a key in the game's Key Bindings (AddOns, Fantasy Glass UI), or type /fgui read." },
    spokenAlerts  = { kind = "button", label = "Spoken alerts", run = function() ns:ToggleConfig("combat:Alerts and warnings") end,
                      desc = "Ready checks, whispers, missing buffs and your own alerts said aloud. They are with the other alerts, in Combat." },
    -- accessibility (12.2)
    highContrast  = { kind = "button", label = "Use the high-contrast theme", run = function() ns:UseHighContrast() end,
                      desc = "Pure black panels, white lettering and the strongest rims, in the family you use: glass, fantasy or celestial." },
    stillSky      = { kind = "check", label = "Still sky", desc = "The celestial sky keeps its stars but holds still: no twinkling, no breathing light, no shooting stars. Everything else moves as usual." },
    tooltipDelay  = { kind = "slider", label = "Wait before a tooltip shows (ms)", min = 0, max = 2000, step = 250, default = 0,
                      desc = "How long the mouse must rest on something before its tooltip shows, so sweeping across the screen does not throw one up after another. 0 shows them at once." },
    readDialog    = { kind = "check", label = "Read talk and quests aloud",
                      desc = "What an NPC says (and the choices), a quest's text and a book or letter are read as soon as they open, and the reading stops when you close them." },
    readHover     = { kind = "check", label = "Read what I point at",
                      desc = "When the mouse rests on something for half a second, its tooltip is read aloud. The game's own screen narrator only works before you log in." },
    windowKeys    = { kind = "check", label = "Move through the game's windows with the keyboard",
                      desc = "With an NPC's talk, a quest, a vendor, the mailbox, loot, a trainer, a flight master or a question box open: Tab or Down goes to the next thing to press, Shift+Tab or Up to the one before, Enter or Space presses it. A ring shows where you are. Never while you type, and not in a fight." },
    windowKeysSay = { kind = "check", label = "Say each choice as I reach it", desc = "With the keyboard in the game's windows: each button is said aloud as the ring reaches it, with where it is in the list." },
    keysLeft      = { kind = "button", label = "Keys for the left hand only", run = function() ns:UseKeyPreset("left") end,
                      desc = "Moving on W, A, S and D, strafing on Q and E, jumping on Space, the first twelve action buttons on 1 to 5 and the keys round them, Tab to target and F to interact. The keys these take are noted, to be put back." },
    keysNumpad    = { kind = "button", label = "Keys for the number pad only", run = function() ns:UseKeyPreset("numpad") end,
                      desc = "Everything on the number pad, for the right hand: 8, 5, 4 and 6 move and turn, 7 and 9 strafe, 0 jumps, 1, 2, 3, / , * and - are the first six action buttons, + targets and . interacts." },
    keysBack      = { kind = "button", label = "Put my keys back", run = function() ns:RestoreKeys() end,
                      desc = "Every key a one-hand set took goes back to what it did before." },
    accessCopy    = { kind = "button", label = "Copy my accessibility settings", run = function() ns:AccessCommand("copy") end,
                      desc = "All of these settings in one line of text, to keep or give to someone." },
    accessPaste   = { kind = "button", label = "Paste accessibility settings", run = function() ns:ShowAccessPaste() end,
                      desc = "Takes a line someone gave you and sets everything in it at once." },
    -- buttons that step through choices, or do something
    raidSort  = { kind = "cycle", label = "Raid frames ordered by", choices = { "group", "role", "name" }, default = "group", apply = After("ApplyRaidSort"),
                  desc = "Click for the next order: by group, by role, or by name." },
    sharedFont = { kind = "media", label = "Font", media = "font", desc = "A font another add-on brings (LibSharedMedia). Click to step through them, right-click to step back. /reload shows it everywhere." },
    sharedBar  = { kind = "media", label = "Bar texture", media = "statusbar", desc = "A bar texture another add-on brings (LibSharedMedia). Click to step through them, right-click to step back." },
    infoPieces = { kind = "button", label = "Info bar pieces", run = function(self) ns:ToggleInfoBarPieces(self) end, desc = "Choose what the info bar shows, and in what order." },
}

-- The categories, in the order they are listed. `desc` is the line under the category's name.
ns.settingsCategories = {
    { id = "home", title = "Home", home = true },
    { id = "look", title = "Look and themes", desc = "Themes, accent, lettering, the game's windows and sounds.", sections = {
        { title = "Themes", simple = true, blocks = { { host = "look", from = "Glass", to = "Your themes" } } },
        { title = "Accent and lettering", simple = true, rows = { "sharedFont", "sharedBar" }, blocks = { { host = "look", from = "Accent", to = "Lettering" } } },
        { title = "Your own theme", blocks = { { host = "look", from = "Make your own theme" } } },
        { title = "Theme by place", blocks = { { host = "look", from = "Theme by place" } } },
        { title = "Class colors", rows = { "emblemAnim" }, blocks = { { host = "look", from = "Class colors" } } },
        { title = "Game windows" , rows = { "fades", "panelAlpha", "windowAlpha" } },
        { title = "Sounds and notifications" },
        { title = "Away and screenshots", blocks = { { host = "combat", from = "AFK screen" } } },
    } },
    { id = "access", title = "Accessibility", desc = "Seeing, hearing, flashing, calm, reading aloud and the keyboard.", new = true, sections = {
        { title = "Seeing", simple = true, new = true, rows = { "highContrast", "colorblind", "colorVision", "readableFont", "textOutline", "textBands", "targetOutline", "uiScale" },
          blocks = { { host = "look", from = "Contrast and text size" } } },
        { title = "Hearing", simple = true, new = true, rows = { "spokenAlerts" } },
        { title = "Flashing and motion", simple = true, new = true, rows = { "reduceMotion", "stillSky", "safeFlash" } },
        { title = "Focus and calm", new = true, rows = { "calmMode", "tooltipDelay" } },
        { title = "Reading aloud", simple = true, new = true, rows = { "readDialog", "readHover", "readNow" } },
        { title = "Hands and keys", new = true, rows = { "bigControls", "keyNav", "windowKeys", "windowKeysSay", "keysLeft", "keysNumpad", "keysBack" } },
        { title = "Share", new = true, rows = { "accessCopy", "accessPaste" } },
    } },
    { id = "frames", title = "Frames and bars", desc = "Unit frames, raid frames, action bars and nameplates.", samples = true, sections = {
        { title = "Your frames", simple = true, rows = { "ufW", "ufH", "smoothBars", "hitFlash", "idleFade" },
          blocks = { { host = "look", from = "Frame style" }, { bars = "frames" }, { list = "auraHide" }, { list = "auraBlock" } } },
        { title = "Party, boss and arena", rows = { "partyW", "partyH" } },
        { title = "Raid frames", rows = { "raidSort" }, blocks = { { bars = "Raid frames" }, { host = "combat", from = "Click casting" } } },
        { title = "Numbers on frames" },
        { title = "Action bars", simple = true, rows = { "barScale" }, blocks = { { host = "look", from = "Menu and bars" }, { bars = "bars" } } },
        { title = "Nameplates", blocks = { { bars = "Nameplates" } } },
    } },
    { id = "combat", title = "Combat", desc = "Cooldowns, alerts, timers, meters and threat.", sections = {
        { title = "Cooldowns", simple = true, blocks = { { host = "combat", from = "Cooldown tracker" } } },
        { title = "Alerts and warnings", rows = { "executePct", "combatFocus", "imbueCombatOnly" },
          blocks = { { list = "remindBuffs" }, { host = "combat", from = "Custom alerts", to = "Buff alerts" } } },
        { title = "Timers" },
        { title = "Damage and threat" },
        { title = "Against other players" },
    } },
    { id = "groups", title = "Groups and raids", desc = "Raid tools, bosses, loot, dungeons and queues.", sections = {
        { title = "Raid tools" }, { title = "Bosses" }, { title = "Loot" }, { title = "Dungeons and runs" }, { title = "Queues and battlegrounds" },
    } },
    { id = "items", title = "Bags and items", desc = "Bags, bank, gear, tooltips, vendors, mail and gold.", sections = {
        { title = "Bags and bank" },
        { title = "Bag sections", blocks = { { rule = "bagRules" } } },
        { title = "Gear and upgrades", blocks = { { rule = "talents" } } },
        { title = "Item tooltips", rows = { "tooltipCursor" } },
        { title = "Vendors", blocks = { { list = "restock" } } },
        { title = "Mail", blocks = { { extra = "mailTargets" }, { rule = "mailRules" } } },
        { title = "Auction and trade" }, { title = "Professions" }, { title = "Gold and farming" },
    } },
    { id = "quests", title = "Quests and map", desc = "Quests, the minimap, the info bar, the world map and your progress.", sections = {
        { title = "Quests" }, { title = "Minimap" },
        { title = "Info bar", rows = { "infobarBg", "infoPieces" } },
        { title = "World map and travel", rows = { "mapSize" } },
        { title = "Progress", blocks = { { rule = "checklist" } } },
    } },
    { id = "chat", title = "Chat and people", desc = "Chat, whispers, what tooltips say about players, and the people you meet.", sections = {
        { title = "Chat", rows = { "chatBg", "bubbleFont" }, blocks = { { list = "keywords" } } },
        { title = "Whispers and invites" }, { title = "Player tooltips" }, { title = "People" },
    } },
    { id = "auto", title = "Done for you", desc = "Small jobs done by themselves, and the game's own settings set for you.", sections = {
        { title = "Around the game" }, { title = "Game settings", rows = { "volume" } },
    } },
    { id = "layout", title = "Layout and profiles", desc = "Move and size panels, profiles, sharing and backups.", sections = {
        { title = "Moving and scale", simple = true, blocks = { { host = "layout" } } },
        { title = "Profiles", simple = true, blocks = { { host = "profiles" } } },
    } },
    { id = "tools", title = "Tools", desc = "Windows to open and things to do once.", allOnly = true, sections = {
        { title = "Tools", blocks = { { host = "tools" } } },
    } },
    { id = "guide", title = "Guide", desc = "Quest guides.", guide = true, sections = {
        { title = "Guide", blocks = { { host = "guide" } } },
    } },
}

-- Every feature's switch, by section (the same order as the list in the setup).
local PLACE = {
    ["Look and themes › Game windows"] = { "windows", "spellbook", "characterWindow", "moveWindows", "rounded", "barTexture", "combatTextFont", "snapPanels" },
    ["Accessibility › Seeing"] = { "cursorRing" },
    ["Accessibility › Hearing"] = { "captions" },
    ["Accessibility › Focus and calm"] = { "quietErrors" },
    ["Look and themes › Sounds and notifications"] = { "toasts", "versionNotice", "questSounds", "loginSplash", "loginLine" },
    ["Look and themes › Away and screenshots"] = { "afkScreen", "levelShot", "bossShot" },
    ["Frames and bars › Your frames"] = { "unitFrames", "ufFocusTarget", "playerCast", "xpBar", "mirrorBars", "auraBars", "auraFilter", "classBar", "classResource", "consumeBar" },
    ["Frames and bars › Party, boss and arena"] = { "ufParty", "ufBoss", "ufArena" },
    ["Frames and bars › Raid frames"] = { "raidFrames", "buffCoverage" },
    ["Frames and bars › Numbers on frames"] = { "powerText", "healthNumbers", "powerNumbers", "xpNumbers", "plateHealth" },
    ["Frames and bars › Action bars"] = { "actionBars", "barEngine", "cooldownText", "barHotkeys", "barMacroNames", "mountButtons", "totemBar", "travelBar", "quickKeys", "homeKey" },
    ["Frames and bars › Nameplates"] = { "nameplates", "plateQuest", "plateExtras" },
    ["Combat › Cooldowns"] = { "cooldowns", "cdTimeline", "cooldownPulse", "roleHUD" },
    ["Combat › Alerts and warnings"] = { "buffAlerts", "buffMissing", "customAlerts", "speakAlerts", "combatAlert", "aggroWarn", "focusCastAlert", "executeLine", "locAlert", "imbueReminder", "totems" },
    ["Combat › Timers"] = { "swingTimer", "combatTimer", "bossTimer" },
    ["Combat › Damage and threat"] = { "damageMeter", "meterDock", "meterAuto", "threatMeter", "deathRecap" },
    ["Combat › Against other players"] = { "enemyCDs" },
    ["Groups and raids › Raid tools"] = { "raidTools", "hideRaidManager", "groupCDs", "kickRotation", "readyReport", "acceptShared" },
    ["Groups and raids › Bosses"] = { "bossGuide", "bossNotes", "lootBossTip" },
    ["Groups and raids › Loot"] = { "lootRoll", "rollAdvice", "groupLoot", "lootBook", "rollTracker", "autoGreed", "lootBindSolo" },
    ["Groups and raids › Dungeons and runs"] = { "runLog", "gearCheck", "autoCombatLog", "combatLogDungeons", "raidGraphics" },
    ["Groups and raids › Queues and battlegrounds"] = { "readyAlert", "queueAlert", "bgHelper", "autoRoleCheck" },
    ["Bags and items › Bags and bank"] = { "bagWindow", "bankWindow", "storage", "bagBoE", "bagJunkIcon", "bagCombatUse", "bagSetMark", "openAll", "lootLog" },
    ["Bags and items › Bag sections"] = { "bagSecMine", "bagSecUpgrades", "bagSecSets", "bagSecBoE", "bagSecMats", "bagSecConsumables", "bagSecRecipes" },
    ["Bags and items › Gear and upgrades"] = { "upgradeArrows", "upgradePrompt", "equipSets", "setOnFrame", "setsFollowSpec", "specButtons", "enchantCheck", "inspectLevels" },
    ["Bags and items › Item tooltips"] = { "tooltip", "itemCounts", "tooltipExtras", "tooltipIDs", "madeByTip" },
    ["Bags and items › Vendors"] = { "autoSell", "autoRepair", "repairGuild", "vendorSummary", "vendorStack", "vendorKnown", "trainAll", "restockOn" },
    ["Bags and items › Mail"] = { "mailTools", "mailAlts", "mailButton", "mailRulesOn", "mailCloth", "mailLeather", "mailOre", "mailHerbs", "mailCooking", "mailElemental", "mailEnchanting", "mailGems", "mailPotions" },
    ["Bags and items › Auction and trade"] = { "auctionMemory", "auctionScan", "sellHints", "otherAddonPrices", "auctionHelper", "tradeLog" },
    ["Bags and items › Professions"] = { "craftBar", "profCooldowns", "skillUps" },
    ["Bags and items › Gold and farming"] = { "farming" },
    ["Quests and map › Quests"] = { "questTracker", "questRewards", "questLog", "quests", "autoQuest", "gossipOne" },
    ["Quests and map › Minimap"] = { "minimap", "minimapRound", "minimapDiamond", "buttonBag", "launcher", "minimapPlanner", "minimapGold", "mapTracking", "mapPing", "rareAlert", "rareMemory" },
    ["Quests and map › Info bar"] = { "infobar", "infobarExtras", "infobarPlugins", "clock12", "clockServer" },
    ["Quests and map › World map and travel"] = { "mapCoords", "mapGroup", "smallMap", "flightTimer" },
    ["Quests and map › Progress"] = { "goalsPanel", "loginBriefing", "weeklyRecap", "milestones", "lifetimeStats", "holidayJobs", "repFollow" },
    ["Chat and people › Chat"] = { "chat", "chatSkin", "chatExtras", "chatClassColors", "chatHighlight", "chatNameSound", "chatHistory", "chatEditTop", "chatBubbles", "bubbleNames", "chatKeywords", "chatSpam", "shortCommands" },
    ["Chat and people › Whispers and invites"] = { "whisperWindow", "chatNames", "autoInvite", "whisperInvite", "whisperInviteAll", "declineDuels" },
    ["Chat and people › Player tooltips"] = { "playerTips", "tipTitle", "tipRealm", "tipGuild", "tipGuildRank", "tipLevel", "tipFaction", "tipPvP", "tipHealthBar", "tipTarget", "tipRole", "tipFriend", "tipHealth", "tipCombatHide" },
    ["Chat and people › People"] = { "friendColors", "playerNotes", "recentMates", "groupNotices", "guildNotices" },
    ["Done for you › Around the game"] = { "fastLoot", "deleteFill", "skipCinematics", "autoStand", "autoDismount", "autoRes", "autoSummon", "fishingMode" },
    ["Done for you › Game settings"] = { "tweakCamera", "tweakErrorVoice", "tweakBgSound", "tweakScreenshot", "tweakAutoLoot", "tweakLootMouse", "tweakSelfCast", "tweakPlateRange", "tweakPlateStack", "tweakCameraFollow", "tweakWeather", "tweakBgFps", "tweakTutorials", "tweakProfanity", "tweakMusic", "tweakAmbience", "tweakDeathGrey", "tweakGlow", "talkingHeadHide", "talkingHeadMove" },
    ["Layout and profiles › Moving and scale"] = { "pixelPerfect" },
}
-- (Theme by place's switch is on its own section, with the places: it is the same setting.)
ns.featurePlace = PLACE

-- Each section gets its feature switches in front of its other rows, and an id: "category:Section".
for _, cat in ipairs(ns.settingsCategories) do
    for _, sec in ipairs(cat.sections or {}) do
        sec.id = cat.id .. ":" .. sec.title
        sec.category = cat
        local keys = PLACE[cat.title .. " › " .. sec.title]
        local rows = {}
        for _, key in ipairs(keys or {}) do rows[#rows + 1] = key end
        for _, name in ipairs(sec.rows or {}) do rows[#rows + 1] = name end
        sec.rows = rows
        sec.keys = keys or {}
    end
end

-- Found by id ("look:Accessibility"), or by a page of the window and one of its headings.
function ns:SettingsSection(id)
    for _, cat in ipairs(ns.settingsCategories) do
        if cat.id == id and cat.home then return cat end
        for _, sec in ipairs(cat.sections or {}) do if sec.id == id then return sec end end
    end
end
function ns:SettingsCategory(id)
    for _, cat in ipairs(ns.settingsCategories) do if cat.id == id then return cat end end
end
-- The section a feature's switch, or one of the rows above, is in.
function ns:SectionOfRow(name)
    for _, cat in ipairs(ns.settingsCategories) do
        for _, sec in ipairs(cat.sections or {}) do
            for _, r in ipairs(sec.rows) do if r == name then return sec end end
        end
    end
end

-- What is new in this version: shown with a NEW tag until the section has been opened once.
ns.settingsNewIn = "12.2"
function ns:SectionIsNew(sec)
    if type(sec) ~= "table" or not sec.new then return false end
    if not tostring(ns.version or ""):find("^" .. ns.settingsNewIn:gsub("%.", "%%.")) then return false end
    local seen = type(ns.root) == "table" and ns.root.seenNew
    return not (type(seen) == "table" and seen[sec.id])
end
function ns:SeeSection(sec)
    if type(sec) ~= "table" or not sec.new or type(ns.root) ~= "table" then return end
    ns.root.seenNew = type(ns.root.seenNew) == "table" and ns.root.seenNew or {}
    ns.root.seenNew[sec.id] = true
end

-- Home: the quick switches, a card each.
ns.homeQuick = { "bagWindow", "damageMeter", "autoSell", "autoRepair", "questTracker", "plateQuest" }
