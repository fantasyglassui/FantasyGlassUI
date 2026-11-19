local ADDON, ns = ...
_G.FantasyGlassUI = ns
ns.version = "11.14.0"
ns.author = "DustyMouse"

ns.modules = {}
ns.loaded = {}
ns.errors = {}          -- everything that went wrong this session, for /fgui check

-- The options window, the guided setup and the self-check are about a seventh of the add-on's code,
-- and most sessions never open any of them. They live in a second folder, FantasyGlassUI_Options,
-- which the game loads only on request: the first time one of them is asked for. Until then the
-- functions below stand in for the real ones; each loads that folder and hands the call on.
local OPTIONS = "FantasyGlassUI_Options"
ns.optionsAddon = OPTIONS
function ns:LoadOptions()
    if ns.optionsLoaded then return true end
    local C = C_AddOns
    local load = (type(C) == "table" and C.LoadAddOn) or LoadAddOn
    local reason = "this game client cannot load an add-on on request"
    if type(load) == "function" then
        local ok, loaded, why = pcall(load, OPTIONS)
        if ok and not loaded and why == "DISABLED" then      -- switched off in the add-on list: switch it on and try again
            local enable = (type(C) == "table" and C.EnableAddOn) or EnableAddOn
            if type(enable) == "function" then
                pcall(enable, OPTIONS)
                ok, loaded, why = pcall(load, OPTIONS)
            end
        end
        reason = ok and (type(why) == "string" and why or "it did not finish loading") or tostring(loaded)
    end
    if ns.optionsLoaded then return true end
    if not ns.optionsWarned or GetTime() - ns.optionsWarned > 10 then
        ns.optionsWarned = GetTime()
        ns:PrintRaw("|cffff4444The options could not be opened|r (" .. reason .. "). They are in a second folder, "
            .. OPTIONS .. ", which must sit beside FantasyGlassUI in Interface/AddOns and be enabled. Installing the add-on again puts it back.")
    end
    return false
end
ns.optionsStubs = {}
for _, name in ipairs({ "ToggleConfig", "ShowSetup", "SelfCheck", "CheckNew", "ProblemReport", "DumpTree", "ExportStrings" }) do
    local stub
    stub = function(self, ...)
        if not ns:LoadOptions() or ns[name] == stub then return nil end
        return ns[name](self, ...)
    end
    ns[name], ns.optionsStubs[name] = stub, stub
end
ns.defaults = {
    actionBars       = true,
    microMenu        = true,
    microMode        = "HIDE",
    minimap          = true,
    questTracker     = true,
    questLog         = true,
    windows          = true,
    tooltip          = true,
    chat             = true,
    chatSkin         = true,
    nameplates       = true,
    quests           = true,
    autoQuest        = false,   -- opt-in
    infobar          = true,
    roleHUD          = true,
    autoSell         = true,
    autoRepair       = true,
    vendorSummary    = true,        -- one line in chat after each vendor visit (11.10)
    loginBriefing    = true,        -- what is waiting, a few seconds after you log in (11.11)
    skillUps         = true,        -- "Skill-ups" on the profession window (11.11)
    weeklyRecap      = true,        -- each character's week, noted as you play (11.11)
    lootBook         = true,        -- what bosses drop, noted as you kill them; /fgui drops (11.13)
    groupLoot        = true,        -- in a group: whose upgrade a boss drop is, among players with the add-on (11.14)
    runLog           = true,        -- dungeon and raid runs: times, kills, wipes, deaths, loot; /fgui runs (11.14)
    farming          = true,        -- farming sessions: /fgui farm, gold and item value an hour (11.13)
    threatMeter      = true,        -- who has how much threat on your target, in a group (11.13)
    accent           = "AZURE",
    theme            = "SMOKE",
    panelAlpha       = 78,          -- glass HUD panel opacity, percent
    windowAlpha      = 95,          -- glass window opacity, percent
    chatBg           = 25,          -- chat background strength, percent
    unitFrames       = true,
    ufParty          = true,
    ufBoss           = true,        -- boss frames
    ufArena          = false,       -- arena enemy frames (UnitFrames.lua)
    enemyCDs         = true,        -- enemy trinket, interrupt and dispel cooldowns, in arenas and battlegrounds (Arena.lua)
    upgradeArrows    = true,        -- upgrade arrows on loot rolls, quest rewards and the game's bags (Upgrades.lua)
    loginLine        = true,        -- the "loaded" line in chat at login
    bossNotes        = true,        -- a note for each boss, opened on target or pull (Raid.lua)
    deathRecap       = true,        -- what hit you before you died (Raid.lua)
    homeKey          = true,        -- one key for the best way home (QuickKeys.lua)
    auctionHelper    = true,        -- auction house: lowest -1c and worth selling (Auction.lua)
    launcher         = true,        -- a minimap button that opens the options
    versionNotice    = true,        -- say once when someone in your guild or group has a newer version
    autoInvite       = false,       -- accept group invitations from friends and guildmates
    autoStand        = false,       -- stand up when an action fails because you are sitting
    autoDismount     = false,       -- get off your mount when an action fails because you are mounted (never in the air)
    autoRes          = false,       -- accept a resurrection, unless whoever cast it is in a fight
    autoSummon       = false,       -- accept a summon after a few seconds
    equipSets        = true,        -- a button for each saved gear set, under the character window
    setOnFrame       = true,        -- the gear set you are wearing, named over your player frame (11.13)
    autoGreed        = false,       -- roll Greed on green items (not on bind-on-pickup ones or upgrades)
    chatEditTop      = false,       -- the typing bar above the chat box (it covers the chat tabs there) rather than under it
    chatStampsOffered = false,      -- chat timestamps were switched on once (a later "None" in the game's settings is kept)
    chatHistory      = true,        -- the last lines of each chat tab come back after a reload
    tweakCamera      = false,       -- game settings as switches: zoom the camera out further,
    tweakErrorVoice  = false,       --   mute the "Not enough mana" voice,
    tweakBgSound     = false,       --   keep sound on while the game is in the background,
    tweakScreenshot  = false,       --   best-quality screenshots
    tweakAutoLoot    = false,
    tweakLootMouse   = false,
    tweakSelfCast    = false,
    tweakPlateRange  = false,
    tweakPlateStack  = false,
    tweakCameraFollow = false,
    tweakWeather     = false,
    tweakBgFps       = false,
    tweakTutorials   = false,
    tweakProfanity   = false,
    tweakMusic       = false,
    tweakAmbience    = false,
    tweakDeathGrey   = false,
    tweakGlow        = false,
    fastLoot         = false,       -- with auto-loot on, take everything at once
    deleteFill       = false,       -- type DELETE for you when destroying a good item
    skipCinematics   = false,       -- skip cutscenes already seen once
    mapCoords        = true,        -- your and the cursor's coordinates on the world map
    bagBoE           = true,        -- a "BoE" tag on gear in the bags that is not yet bound to you
    plateW           = 100,         -- nameplate width and height, percent of the game's own
    plateH           = 100,
    bagCombatUse     = false,       -- every bag slot carries its own secure button, so items can be used in combat (new; off until tried)
    mirrorBars       = true,        -- our breath / fatigue bar in place of the game's
    ufPortrait       = "3D",
    ufStyle          = "STARCUT",     -- unit frame style: "STARCUT" (cut bars, a diamond portrait) or "CLASSIC" (the box)
    raidFrames       = true,
    playerCast       = true,
    swingTimer       = true,
    bagWindow        = true,
    auraBars         = true,
    xpBar            = true,
    plateExtras      = true,
    chatExtras       = true,
    raidTools        = true,
    cooldownText     = true,
    fontStyle        = "GLASS",
    infobarBg        = 0,           -- info bar background strength, percent (0 = text only)
    barTexture       = true,
    bankWindow       = true,
    storage          = true,
    itemCounts       = true,
    craftBar         = true,        -- the crafting bar in our style, with the profession's icon
    damageMeter      = true,
    meterDock        = true,        -- the damage meter is a drawer on the side of the chat box (off: a window of its own)
    meterOpen        = true,        -- that drawer is out (remembered as you click its tab)
    meterAuto        = false,       -- the drawer comes out for a fight and tucks itself away after
    meterView        = "dps",       -- what the meter shows (remembered as you step through its views)
    setsFollowSpec   = false,       -- each talent set puts on the gear set last worn in it
    whisperInvite    = false,       -- invite friends and guildmates who whisper the invite word
    whisperInviteAll = false,       --   ...or anyone who does
    whisperInviteWord = "inv",      --   the word (/fgui invword)
    declineDuels     = false,       -- turn down duel requests
    vendorKnown      = true,        -- at a vendor, mark what you have already learned
    lootBindSolo     = false,       -- answer "this will bind to you" yourself when looting alone
    autoRoleCheck    = false,       -- confirm your role when the group finder asks
    combatAlert      = false,       -- a word on screen as a fight starts and ends
    plateQuest       = true,        -- a ! beside the nameplate of anything you need for a quest
    cooldownPulse    = true,        -- a tracked ability's icon flashes mid-screen as it comes off cooldown
    readyAlert       = true,        -- a ready check is hard to miss, even from another window
    consumeBar       = false,       -- a bar that fills itself with the consumables in your bags
    -- 10.0.0: what only adds information is on; what puts something new on screen, makes a sound or acts for you is off
    buffMissing      = true,        -- an icon while a buff you chose is missing (nothing until you choose one)
    focusCastAlert   = false,       -- a sound and a line when your focus starts a cast
    executeLine      = false,       -- a tick on the target's health bar
    executePct       = 20,
    locAlert         = false,       -- a large icon while you are stunned, silenced, feared
    quickKeys        = true,        -- key bindings for your best healing potion and your best food and drink
    openAll          = false,       -- a button that opens the lockboxes and clams in your bags
    travelBar        = false,       -- hearthstone, teleports and portals on one bar
    bossTimer        = false,       -- time per boss and for the run, with your best
    queueAlert       = true,        -- a dungeon finder or battleground invitation is hard to miss
    autoCombatLog    = false,       -- the combat log file is started in raids
    combatLogDungeons = false,      --   and in dungeons too
    bossShot         = false,       -- a screenshot on boss kills and achievements
    auraFilter       = true,        -- buffs you chose are left out of your buff row; your own debuffs are rimmed
    questGuide       = true,        -- step-by-step quest guides (nothing shows until you follow one)
    guideSound       = true,
    groupWatch       = true,        -- (internal: watches who is in your group for the three below)
    playerNotes      = true,        -- your own note on a player, in their tooltip
    recentMates      = true,        -- the people you grouped with lately
    groupNotices     = false,       -- a line and a sound when someone joins or leaves
    rollTracker      = true,        -- /fgui rolls
    raidSort         = "group",     -- raid frames by group, role or name
    flightTimer      = true,        -- a bar for the time left on a flight path
    fishingMode      = false,       -- louder splash, auto-loot, while a fishing pole is equipped
    smallMap         = false,       -- a smaller world map that fades while you move
    mapSize          = 75,
    mapGroup         = true,        -- your group as class-colored dots on the world map
    mapTracking      = true,        -- right-click the minimap for the tracking menu
    mapPing          = true,        -- who pinged the minimap
    restockOn        = true,        -- buy what is on the restock list (nothing until you add to it)
    bagSetMark       = true,        -- gear set items say "Set" in the bags and are never sold
    tradeLog         = true,        -- what changed hands, with whom
    auctionMemory    = true,        -- the last auction price you saw, in tooltips
    lootLog          = true,        -- /fgui loot
    chatKeywords     = true,        -- words you chose are picked out (nothing until you choose one)
    chatSpam         = false,       -- the same line repeated within seconds is hidden
    chatNames        = true,        -- Alt-click a name to invite; more in the right-click menu
    whisperWindow    = false,       -- whisper conversations in a window of their own
    shortCommands    = true,        -- /rl, /rc, /tt
    guildNotices     = false,       -- the guild message of the day and who came online, as notices
    friendColors     = true,        -- friends list names in class colors
    specButtons      = true,        -- talent set buttons on the character window
    enchantCheck     = false,       -- a mark on gear with no enchant or an empty socket
    raidGraphics     = false,       -- lower graphics settings while in a raid
    talkingHeadHide  = false,
    talkingHeadMove  = false,
    chatBubbles      = true,
    bubbleNames      = true,        -- speaker's name above each chat bubble
    bubbleFont       = 13,
    fontScale        = 100,         -- all lettering, percent
    uiScale          = 100,         -- the whole interface, percent of the game's (or pixel-perfect) scale
    smoothBars       = true,
    fades            = true,
    idleFade         = false,       -- dim the player frame when nothing is happening
    hitFlash         = true,
    myDebuffsOnly    = false,       -- target frame: only the debuffs you applied
    colorblind       = false,       -- color-blind safe signal colors, plus letters and marks where we can
    reduceMotion     = false,       -- no fades, pulses, gliding bars or camera drift
    combatFocus      = false,       -- dim the quest tracker and info bar during a fight
    tooltipCursor    = false,       -- tooltips follow the mouse instead of sitting in the corner
    xpNumbers        = false,       -- the XP and reputation bars' text as amounts ("4,520 / 10,000") instead of a percentage
    powerNumbers     = false,       -- resource text as an amount instead of a percentage
    powerText        = true,        -- mana / rage / energy as a percentage, on unit frames and nameplates
    plateHealth      = true,        -- health text on nameplates (a percentage, or the amount with healthNumbers)
    healthNumbers    = false,       -- unit frames show health as an amount (12.4k) instead of a percentage
    emblemAnim       = true,        -- class emblems move: sigil, glow, ring, sparks (off, or Reduce motion: held still)
    barPanel         = false,       -- a framed panel behind each action bar
    inspectLevels    = true,        -- item levels and their average on the inspect window
    questSounds      = true,        -- a chime for a finished objective, another for a finished quest
    bagJunkIcon      = true,        -- a coin on what "sell junk" would sell
    tooltipIDs       = false,       -- item and spell ID numbers in tooltips
    moveWindows      = true,        -- the game's own windows can be dragged, and open where they were left
    windowPos        = {},          -- where: [window name] = { point, relative point, x, y }
    chatClassColors  = true,        -- player names in chat take their class color
    repFollow        = false,       -- the reputation bar follows the faction you last gained with
    trainAll         = true,        -- a "Learn all" button at trainers
    vendorStack      = true,        -- Alt-click at a vendor buys a stack
    repairGuild      = false,       -- auto-repair pays from guild funds when they cover it
    gossipOne        = false,       -- a conversation with one choice: choose it
    clock12          = false,       -- clocks read 3:05pm
    clockServer      = false,       -- clocks show the server's time
    rareAlert        = true,        -- say so when the game marks a rare creature or treasure nearby
    profCooldowns    = true,
    barEngine        = false,       -- our own action bars in place of the game's (BarEngine.lua)
    pixelPerfect     = false,       -- the interface at the screen's own pixel scale (Companion.lua)
    minimapRound     = false,       -- a round minimap
    minimapDiamond   = false,       -- a diamond minimap, cut like the Starcut portrait (11.14)
    bgHelper         = true,        -- battleground queue timer and start countdown
    holidayJobs      = true,        -- holidays that are on go on the checklist
    kickRotation     = false,       -- interrupt rotation (More.lua)
    classResource    = false,       -- class resource you design
    buffCoverage     = false,       -- marks on raid frames for missing buffs you can give
    madeByTip        = true,        -- "Made by" on item tooltips
    mountButtons     = false,       -- mount and pet buttons (Collections.lua)
    groupCDs         = false,       -- the group cooldowns panel (Group.lua)
    totemBar         = true,        -- a totem bar (Shamans only)
    acceptShared     = true,        -- setups other players send you open in the preview
    hideRaidManager  = false,       -- the game's raid manager on the left edge, hidden (Companion.lua)
    bagSecMine       = true,        -- bag rules: your own (Tools tab)            (Companion.lua)
    bagSecUpgrades   = false,       -- bag rules: ready-made sections
    bagSecSets       = false,
    bagSecBoE        = false,
    bagSecMats       = false,
    bagSecConsumables = false,
    bagSecRecipes    = false,
    mailButton       = true,        -- mail rules: the "Send by my rules" button
    mailRulesOn      = true,        -- mail rules: your own (Tools tab)
    mailCloth        = false,       -- mail rules: materials, each to the character typed beside it
    mailLeather      = false,
    mailOre          = false,
    mailHerbs        = false,
    mailCooking      = false,
    mailElemental    = false,
    mailEnchanting   = false,
    mailGems         = false,
    mailPotions      = false,
    customAlerts     = true,        -- alerts you make yourself (Combat tab); nothing shows until you make one
    speakAlerts      = false,       -- spoken alerts, with the game's text-to-speech voice
    cdTimeline       = false,
    readyReport      = true,
    rareMemory       = true,
    questRewards     = true,
    goalsPanel       = true,
    combatTextFont   = false,
    loginSplash      = false,
    themeByPlace     = false,
    ufFocusTarget    = true,        -- a small frame for what your focus is targeting
    chatHighlight    = true,        -- pick out your name when someone else says it in chat
    chatNameSound    = false,       -- and play a sound
    infobarParts     = {},          -- info bar pieces switched off: [piece] = false (absent = shown)
    combatTimer      = false,       -- a small timer that counts how long the fight has lasted
    mailAlts         = true,        -- your other characters listed beside the mail window, to send to with a click
    snapPanels       = true,        -- in move mode, a dragged panel snaps to the edges of other panels
    barHotkeys       = true,        -- key text on action buttons
    barMacroNames    = false,       -- macro names on action buttons
    quietErrors      = false,       -- hide the commonest red error lines ("Not enough mana", "Not ready yet")
    cursorRing       = false,       -- a ring round the mouse pointer
    panelShow        = {},          -- when each panel shows: [panel key] = "COMBAT" | "NOCOMBAT" | "TARGET" (absent = always)
    bars             = {},          -- each action bar's own settings: [handle key] = { scale, alpha, show, hotkeys, names }
    barFade          = {},          -- action bars set to fade when not in use: [handle key] = true
    stepAside        = true,        -- leave a job to another add-on that already does it
    specLayouts      = false,       -- keep a separate panel layout for each talent set
    groupLayouts     = false,       -- keep a separate panel layout for solo, party and raid
    screenLayouts    = false,       -- and for each screen size (a laptop and a desktop, say)
    cooldowns        = true,
    buffAlerts       = true,
    totems           = true,
    imbueReminder    = true,
    imbueCombatOnly  = true,        -- the imbue reminder fades away outside combat
    aggroWarn        = false,       -- (the four that flash, pop up or act on their own start switched off)
    afkScreen        = false,
    afkDelay         = 0,           -- minutes idle before the AFK screen; 0 = when the game marks you away
    afkFlag          = false,       -- with a delay: also mark the character as away at that moment
    levelShot        = false,
    barScale         = 100,         -- action bar size, percent (100 leaves the game's own size alone)
    infobarExtras    = true,        -- bag space, friends, guild and mail on the info bar
    lootRoll         = true,
    classBar         = true,        -- class extras: second resource, runes, mana in forms, pet happiness
    toasts           = false,       -- notifications: loot, level, mail, whispers
    toastQuality     = 2,           -- loot toasts from this quality up (2 = uncommon)
    infobarPlugins   = true,        -- other add-ons' data (LibDataBroker) under the info bar
    mailTools        = true,
    buttonBag        = true,
    tooltipExtras    = true,        -- item level and vendor price lines
    playerTips       = true,        -- player tooltips: every line your choice (11.10)
    tipTitle = true, tipRealm = true, tipGuild = true, tipGuildRank = true, tipLevel = true, tipFaction = true, tipPvP = true,
    tipHealthBar = true, tipTarget = true, tipRole = true, tipFriend = true, tipHealth = false, tipCombatHide = false,
    rounded          = true,        -- rounded corners on glass themes (when the client supports it)
    fallbacks        = true,        -- internal: restyles a Blizzard piece whenever our replacement for it is off
    spellbook        = true,
    characterWindow  = true,
    ufW = 240, ufH = 48,          -- player / target frame size
    partyW = 180, partyH = 36,
    raidW = 78, raidH = 38,
}

-- Roles -----------------------------------------------------------------------
ns.roles = {
    TANK   = { label = "Tank",   color = { 0.30, 0.60, 1.00 },
               desc = "Threat bar for your target, aggro status and \"LOST AGGRO\" alerts, and who your target is attacking." },
    HEALER = { label = "Healer", color = { 0.30, 1.00, 0.50 },
               desc = "Compact health bars for your party plus a mana bar, with a low-mana alert." },
    DAMAGE = { label = "Damage", color = { 1.00, 0.35, 0.25 },
               desc = "Big target health %, execute-range alert (under 20%), and a combat timer." },
}
ns.roleOrder = { "TANK", "HEALER", "DAMAGE" }

function ns:RoleHex(key)
    local r = self.roles[key]
    if not r then return "|cffffffff" end
    return format("|cff%02x%02x%02x", floor(r.color[1] * 255 + 0.5), floor(r.color[2] * 255 + 0.5), floor(r.color[3] * 255 + 0.5))
end

-- Accent colors ----------------------------------------------------------------
ns.accents = {
    AZURE   = { 0.36, 0.72, 1.00 },
    MINT    = { 0.36, 0.92, 0.72 },
    VIOLET  = { 0.68, 0.54, 1.00 },
    ROSE    = { 1.00, 0.48, 0.60 },
    AMBER   = { 1.00, 0.74, 0.30 },
    GOLD    = { 1.00, 0.82, 0.40 },
    EMBER   = { 0.95, 0.42, 0.22 },
    ARCANE  = { 0.68, 0.48, 0.98 },
    VERDANT = { 0.45, 0.85, 0.45 },
    FROST   = { 0.50, 0.78, 1.00 },
    TEAL     = { 0.25, 0.86, 0.84 },
    SCARLET  = { 0.98, 0.20, 0.22 },
    CRIMSON  = { 1.00, 0.34, 0.38 },
    CORAL    = { 1.00, 0.57, 0.45 },
    ORCHID   = { 0.87, 0.53, 1.00 },
    FEL      = { 0.62, 0.96, 0.26 },
    BONE     = { 0.93, 0.89, 0.76 },
    PLATINUM = { 0.84, 0.88, 0.94 },
    -- 11.11: twelve more
    MIDNIGHT   = { 0.36, 0.46, 0.96 },
    ICE        = { 0.72, 0.93, 1.00 },
    TURQUOISE  = { 0.16, 0.72, 0.90 },
    EMERALD    = { 0.18, 0.80, 0.46 },
    CHARTREUSE = { 0.80, 0.95, 0.26 },
    OLIVE      = { 0.70, 0.72, 0.36 },
    INDIGO     = { 0.48, 0.44, 1.00 },
    LAVENDER   = { 0.80, 0.72, 1.00 },
    MAGENTA    = { 1.00, 0.32, 0.86 },
    BLUSH      = { 1.00, 0.70, 0.79 },
    PEACH      = { 1.00, 0.73, 0.56 },
    BRONZE     = { 0.82, 0.57, 0.31 },
    CLASS   = false,   -- resolved from your class at login
}
ns.accentOrder = { "MIDNIGHT", "AZURE", "FROST", "ICE", "TURQUOISE", "TEAL", "MINT", "EMERALD", "VERDANT", "FEL", "CHARTREUSE", "OLIVE",
                   "GOLD", "AMBER", "BRONZE", "PEACH", "CORAL", "EMBER", "SCARLET", "CRIMSON", "ROSE", "BLUSH", "MAGENTA",
                   "ORCHID", "LAVENDER", "VIOLET", "INDIGO", "ARCANE", "BONE", "PLATINUM", "CLASS" }
-- An accent's name, as the Look tab and the setup show it.
ns.accentNames = {
    MIDNIGHT = "Midnight blue", AZURE = "Azure", FROST = "Frost", ICE = "Ice", TURQUOISE = "Turquoise", TEAL = "Teal", MINT = "Mint",
    EMERALD = "Emerald", VERDANT = "Verdant", FEL = "Fel green", CHARTREUSE = "Chartreuse", OLIVE = "Olive", GOLD = "Gold",
    AMBER = "Amber", BRONZE = "Bronze", PEACH = "Peach", CORAL = "Coral", EMBER = "Ember", SCARLET = "Scarlet", CRIMSON = "Crimson",
    ROSE = "Rose", BLUSH = "Blush pink", MAGENTA = "Magenta", ORCHID = "Orchid", LAVENDER = "Lavender", VIOLET = "Violet",
    INDIGO = "Indigo", ARCANE = "Arcane", BONE = "Bone", PLATINUM = "Platinum", CLASS = "Your class color",
}
function ns:AccentName(key)
    local name = ns.accentNames[key] or (tostring(key):sub(1, 1) .. tostring(key):sub(2):lower())
    return ns:Tr(name)
end

function ns:AccentColor(key)
    local c = ns.accents[key]
    if key == "CUSTOM" then                              -- your own color (Look tab)
        local mine = ns.db and ns.db.customAccent
        if type(mine) == "table" and type(mine[1]) == "number" and type(mine[2]) == "number" and type(mine[3]) == "number" then
            return mine[1], mine[2], mine[3]
        end
    end
    if key == "CLASS" then
        local _, class = UnitClass("player")
        local r, g, b = ns:ClassRGB(class)
        if r then return r, g, b end
    end
    c = c or ns.accents.AZURE
    return c[1], c[2], c[3]
end

function ns:ApplyAccent()
    local r, g, b = ns:AccentColor(ns.db.accent or "AZURE")
    local a = ns.theme.accent
    a[1], a[2], a[3] = r, g, b
    local base = ns.celestialEdge                            -- Celestial: the one fine line round a panel leans to the accent
    if ns.style == "CELESTIAL" and base then
        local e = ns.theme.border
        for i = 1, 3 do e[i] = base[i] * 0.55 + a[i] * 0.45 end
    end
end

-- Themes: the whole palette in one place. Every panel, button and bar reads its colors from here.
ns.themes = {
    -- Glass: translucent panes, soft shadows, a bright top edge, no ornament.
    SMOKE    = { name = "Glass: Smoke", style = "GLASS", accent = "AZURE",
                 bg = { 0.070, 0.080, 0.100 }, border = { 0.34, 0.38, 0.44 }, rim = { 0, 0, 0 },
                 grain = { 1, 1, 1, 0 }, light = { 1.00, 1.00, 1.00 }, plate = { 0.20, 0.23, 0.28 },
                 text = { 0.93, 0.95, 0.98 }, dim = { 0.72, 0.76, 0.82 }, faint = { 0.50, 0.54, 0.60 }, btn = { 0.94, 0.97, 1.00 } },
    FROSTED  = { name = "Glass: Frost", style = "GLASS", accent = "AZURE",
                 bg = { 0.055, 0.095, 0.145 }, border = { 0.38, 0.50, 0.64 }, rim = { 0, 0.01, 0.03 },
                 grain = { 1, 1, 1, 0 }, light = { 0.85, 0.94, 1.00 }, plate = { 0.16, 0.25, 0.36 },
                 text = { 0.90, 0.95, 1.00 }, dim = { 0.68, 0.78, 0.90 }, faint = { 0.46, 0.56, 0.68 }, btn = { 0.88, 0.95, 1.00 } },
    MIDNIGHT = { name = "Glass: Midnight", style = "GLASS", accent = "VIOLET",
                 bg = { 0.070, 0.060, 0.140 }, border = { 0.42, 0.38, 0.60 }, rim = { 0.01, 0, 0.03 },
                 grain = { 1, 1, 1, 0 }, light = { 0.92, 0.88, 1.00 }, plate = { 0.20, 0.17, 0.34 },
                 text = { 0.94, 0.92, 1.00 }, dim = { 0.76, 0.72, 0.90 }, faint = { 0.54, 0.50, 0.68 }, btn = { 0.94, 0.90, 1.00 } },
    AURORA   = { name = "Glass: Aurora", style = "GLASS", accent = "MINT",
                 bg = { 0.045, 0.100, 0.105 }, border = { 0.34, 0.54, 0.52 }, rim = { 0, 0.02, 0.02 },
                 grain = { 1, 1, 1, 0 }, light = { 0.86, 1.00, 0.96 }, plate = { 0.13, 0.27, 0.27 },
                 text = { 0.90, 0.98, 0.96 }, dim = { 0.68, 0.84, 0.80 }, faint = { 0.46, 0.60, 0.58 }, btn = { 0.88, 1.00, 0.96 } },
    BLUSH    = { name = "Glass: Rose", style = "GLASS", accent = "ROSE",
                 bg = { 0.120, 0.065, 0.085 }, border = { 0.58, 0.40, 0.46 }, rim = { 0.03, 0, 0.01 },
                 grain = { 1, 1, 1, 0 }, light = { 1.00, 0.90, 0.93 }, plate = { 0.32, 0.17, 0.22 },
                 text = { 1.00, 0.93, 0.95 }, dim = { 0.88, 0.72, 0.77 }, faint = { 0.66, 0.50, 0.55 }, btn = { 1.00, 0.92, 0.94 } },
    EMERALD  = { name = "Glass: Emerald", style = "GLASS", accent = "MINT",
                 bg = { 0.040, 0.095, 0.075 }, border = { 0.30, 0.56, 0.46 }, rim = { 0, 0.02, 0.01 },
                 grain = { 1, 1, 1, 0 }, light = { 0.86, 1.00, 0.94 }, plate = { 0.12, 0.27, 0.21 },
                 text = { 0.90, 0.98, 0.94 }, dim = { 0.66, 0.84, 0.76 }, faint = { 0.44, 0.62, 0.54 }, btn = { 0.88, 1.00, 0.95 } },
    OCEAN    = { name = "Glass: Ocean", style = "GLASS", accent = "TEAL",
                 bg = { 0.030, 0.085, 0.120 }, border = { 0.26, 0.52, 0.62 }, rim = { 0, 0.01, 0.02 },
                 grain = { 1, 1, 1, 0 }, light = { 0.84, 0.97, 1.00 }, plate = { 0.09, 0.24, 0.31 },
                 text = { 0.90, 0.97, 1.00 }, dim = { 0.66, 0.82, 0.90 }, faint = { 0.44, 0.60, 0.68 }, btn = { 0.86, 0.97, 1.00 } },
    SUNSET   = { name = "Glass: Sunset", style = "GLASS", accent = "AMBER",
                 bg = { 0.120, 0.060, 0.045 }, border = { 0.66, 0.42, 0.30 }, rim = { 0.02, 0.01, 0 },
                 grain = { 1, 1, 1, 0 }, light = { 1.00, 0.92, 0.84 }, plate = { 0.32, 0.17, 0.12 },
                 text = { 1.00, 0.95, 0.90 }, dim = { 0.90, 0.76, 0.66 }, faint = { 0.68, 0.54, 0.46 }, btn = { 1.00, 0.93, 0.86 } },
    CRIMSON  = { name = "Glass: Crimson", style = "GLASS", accent = "CRIMSON",
                 bg = { 0.115, 0.035, 0.045 }, border = { 0.62, 0.30, 0.34 }, rim = { 0.02, 0, 0 },
                 grain = { 1, 1, 1, 0 }, light = { 1.00, 0.88, 0.88 }, plate = { 0.30, 0.11, 0.13 },
                 text = { 1.00, 0.93, 0.93 }, dim = { 0.90, 0.72, 0.74 }, faint = { 0.66, 0.50, 0.52 }, btn = { 1.00, 0.90, 0.90 } },
    ORCHID   = { name = "Glass: Orchid", style = "GLASS", accent = "ORCHID",
                 bg = { 0.095, 0.050, 0.115 }, border = { 0.58, 0.40, 0.66 }, rim = { 0.02, 0, 0.02 },
                 grain = { 1, 1, 1, 0 }, light = { 0.98, 0.90, 1.00 }, plate = { 0.26, 0.15, 0.31 },
                 text = { 0.97, 0.93, 1.00 }, dim = { 0.84, 0.74, 0.90 }, faint = { 0.62, 0.52, 0.68 }, btn = { 0.97, 0.90, 1.00 } },
    GILDED   = { name = "Glass: Gilded", style = "GLASS", accent = "GOLD",
                 bg = { 0.085, 0.070, 0.035 }, border = { 0.62, 0.52, 0.28 }, rim = { 0.02, 0.015, 0 },
                 grain = { 1, 1, 1, 0 }, light = { 1.00, 0.95, 0.80 }, plate = { 0.24, 0.20, 0.10 },
                 text = { 1.00, 0.97, 0.88 }, dim = { 0.88, 0.80, 0.62 }, faint = { 0.64, 0.58, 0.44 }, btn = { 1.00, 0.94, 0.78 } },
    GRAPHITE = { name = "Glass: Graphite", style = "GLASS", accent = "PLATINUM",
                 bg = { 0.045, 0.045, 0.048 }, border = { 0.30, 0.30, 0.32 }, rim = { 0, 0, 0 },
                 grain = { 1, 1, 1, 0 }, light = { 1.00, 1.00, 1.00 }, plate = { 0.15, 0.15, 0.16 },
                 text = { 0.94, 0.94, 0.95 }, dim = { 0.72, 0.72, 0.74 }, faint = { 0.50, 0.50, 0.52 }, btn = { 0.96, 0.96, 0.97 } },
    NOIR     = { name = "Glass: Noir (black and red)", style = "GLASS", accent = "SCARLET",
                 bg = { 0.035, 0.030, 0.032 }, border = { 0.62, 0.16, 0.18 }, rim = { 0, 0, 0 },
                 grain = { 1, 1, 1, 0 }, light = { 1.00, 0.92, 0.92 }, plate = { 0.16, 0.10, 0.11 },
                 text = { 0.96, 0.93, 0.93 }, dim = { 0.78, 0.70, 0.70 }, faint = { 0.56, 0.48, 0.48 }, btn = { 1.00, 0.92, 0.92 } },
    CONTRAST = { name = "Glass: High contrast", style = "GLASS", accent = "GOLD",
                 bg = { 0, 0, 0 }, border = { 1, 1, 1 }, rim = { 0, 0, 0 },
                 grain = { 1, 1, 1, 0 }, light = { 1, 1, 1 }, plate = { 0.22, 0.22, 0.22 },
                 text = { 1, 1, 1 }, dim = { 0.92, 0.92, 0.92 }, faint = { 0.78, 0.78, 0.78 }, btn = { 1, 1, 1 } },
    GLACIER = { name = "Glass: Glacier", style = "GLASS", accent = "FROST",
                bg = { 0.075, 0.105, 0.13 }, border = { 0.52, 0.66, 0.76 }, rim = { 0, 0.01, 0.02 },
                grain = { 1, 1, 1, 0 }, light = { 0.92, 0.98, 1 }, plate = { 0.2, 0.29, 0.36 },
                text = { 0.94, 0.98, 1 }, dim = { 0.74, 0.84, 0.92 }, faint = { 0.52, 0.62, 0.7 }, btn = { 0.92, 0.98, 1 } },
    AMETHYST = { name = "Glass: Amethyst", style = "GLASS", accent = "ORCHID",
                 bg = { 0.09, 0.05, 0.13 }, border = { 0.52, 0.36, 0.68 }, rim = { 0.02, 0, 0.03 },
                 grain = { 1, 1, 1, 0 }, light = { 0.96, 0.88, 1 }, plate = { 0.25, 0.14, 0.36 },
                 text = { 0.97, 0.92, 1 }, dim = { 0.82, 0.72, 0.92 }, faint = { 0.6, 0.5, 0.7 }, btn = { 0.96, 0.9, 1 } },
    LAGOON = { name = "Glass: Lagoon", style = "GLASS", accent = "TEAL",
               bg = { 0.03, 0.095, 0.12 }, border = { 0.26, 0.56, 0.62 }, rim = { 0, 0.02, 0.03 },
               grain = { 1, 1, 1, 0 }, light = { 0.84, 1, 1 }, plate = { 0.09, 0.26, 0.31 },
               text = { 0.9, 0.98, 1 }, dim = { 0.66, 0.84, 0.88 }, faint = { 0.44, 0.62, 0.66 }, btn = { 0.86, 1, 1 } },
    HONEY = { name = "Glass: Honey", style = "GLASS", accent = "AMBER",
              bg = { 0.115, 0.085, 0.035 }, border = { 0.66, 0.52, 0.26 }, rim = { 0.03, 0.02, 0 },
              grain = { 1, 1, 1, 0 }, light = { 1, 0.95, 0.8 }, plate = { 0.31, 0.23, 0.1 },
              text = { 1, 0.97, 0.9 }, dim = { 0.9, 0.82, 0.64 }, faint = { 0.68, 0.6, 0.44 }, btn = { 1, 0.95, 0.82 } },
    STORM = { name = "Glass: Storm", style = "GLASS", accent = "PLATINUM",
              bg = { 0.07, 0.085, 0.11 }, border = { 0.42, 0.48, 0.58 }, rim = { 0, 0.005, 0.015 },
              grain = { 1, 1, 1, 0 }, light = { 0.92, 0.95, 1 }, plate = { 0.19, 0.23, 0.3 },
              text = { 0.93, 0.95, 0.99 }, dim = { 0.72, 0.77, 0.85 }, faint = { 0.5, 0.55, 0.63 }, btn = { 0.92, 0.95, 1 } },
    CORALREEF = { name = "Glass: Coral", style = "GLASS", accent = "CORAL",
                  bg = { 0.125, 0.07, 0.06 }, border = { 0.64, 0.42, 0.36 }, rim = { 0.03, 0.01, 0 },
                  grain = { 1, 1, 1, 0 }, light = { 1, 0.92, 0.88 }, plate = { 0.33, 0.19, 0.16 },
                  text = { 1, 0.95, 0.93 }, dim = { 0.9, 0.76, 0.72 }, faint = { 0.68, 0.54, 0.5 }, btn = { 1, 0.93, 0.9 } },
    JADE = { name = "Glass: Jade", style = "GLASS", accent = "VERDANT",
             bg = { 0.045, 0.1, 0.055 }, border = { 0.34, 0.58, 0.36 }, rim = { 0, 0.02, 0 },
             grain = { 1, 1, 1, 0 }, light = { 0.9, 1, 0.9 }, plate = { 0.13, 0.28, 0.15 },
             text = { 0.93, 0.99, 0.93 }, dim = { 0.72, 0.86, 0.72 }, faint = { 0.5, 0.64, 0.5 }, btn = { 0.9, 1, 0.9 } },
    NEBULA = { name = "Glass: Nebula", style = "GLASS", accent = "ROSE",
               bg = { 0.085, 0.045, 0.115 }, border = { 0.56, 0.34, 0.58 }, rim = { 0.02, 0, 0.03 },
               grain = { 1, 1, 1, 0 }, light = { 1, 0.88, 0.98 }, plate = { 0.24, 0.13, 0.31 },
               text = { 0.98, 0.92, 0.99 }, dim = { 0.84, 0.72, 0.86 }, faint = { 0.62, 0.5, 0.64 }, btn = { 1, 0.9, 0.98 } },
    -- 10.0.0: fifteen more glass themes
    SAPPHIRE = { name = "Glass: Sapphire", style = "GLASS", accent = "AZURE",
        bg = { 0.042, 0.07, 0.135 }, border = { 0.331, 0.424, 0.64 }, rim = { 0, 0.009, 0.03 },
        grain = { 1, 1, 1, 0 }, light = { 0.839, 0.887, 1 }, plate = { 0.125, 0.189, 0.34 },
        text = { 0.879, 0.909, 0.98 }, dim = { 0.657, 0.724, 0.88 }, faint = { 0.445, 0.516, 0.68 }, btn = { 0.862, 0.903, 1 } },
    RUBY = { name = "Glass: Ruby", style = "GLASS", accent = "SCARLET",
        bg = { 0.135, 0.05, 0.061 }, border = { 0.64, 0.358, 0.395 }, rim = { 0.03, 0.002, 0.005 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.853, 0.873 }, plate = { 0.34, 0.144, 0.17 },
        text = { 0.98, 0.887, 0.9 }, dim = { 0.88, 0.677, 0.704 }, faint = { 0.68, 0.466, 0.494 }, btn = { 1, 0.874, 0.891 } },
    TOPAZ = { name = "Glass: Topaz", style = "GLASS", accent = "AMBER",
        bg = { 0.135, 0.097, 0.054 }, border = { 0.64, 0.515, 0.371 }, rim = { 0.03, 0.017, 0.003 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.935, 0.86 }, plate = { 0.34, 0.253, 0.153 },
        text = { 0.98, 0.939, 0.892 }, dim = { 0.88, 0.79, 0.686 }, faint = { 0.66, 0.568, 0.462 }, btn = { 1, 0.944, 0.88 } },
    PEARL = { name = "Glass: Pearl", style = "GLASS", accent = "BONE",
        bg = { 0.135, 0.128, 0.111 }, border = { 0.64, 0.616, 0.559 }, rim = { 0.03, 0.028, 0.022 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.987, 0.958 }, plate = { 0.34, 0.323, 0.284 },
        text = { 0.98, 0.972, 0.954 }, dim = { 0.88, 0.863, 0.822 }, faint = { 0.66, 0.642, 0.601 }, btn = { 1, 0.989, 0.964 } },
    OBSIDIAN = { name = "Glass: Obsidian", style = "GLASS", accent = "PLATINUM",
        bg = { 0.078, 0.079, 0.084 }, border = { 0.608, 0.613, 0.64 }, rim = { 0.017, 0.017, 0.019 },
        grain = { 1, 1, 1, 0 }, light = { 0.983, 0.986, 1 }, plate = { 0.197, 0.199, 0.211 },
        text = { 0.969, 0.971, 0.98 }, dim = { 0.857, 0.861, 0.88 }, faint = { 0.636, 0.64, 0.66 }, btn = { 0.986, 0.988, 1 } },
    MINTLEAF = { name = "Glass: Mint", style = "GLASS", accent = "MINT",
        bg = { 0.066, 0.135, 0.107 }, border = { 0.412, 0.64, 0.549 }, rim = { 0.007, 0.03, 0.021 },
        grain = { 1, 1, 1, 0 }, light = { 0.881, 1, 0.952 }, plate = { 0.181, 0.34, 0.276 },
        text = { 0.905, 0.98, 0.95 }, dim = { 0.715, 0.88, 0.814 }, faint = { 0.492, 0.66, 0.593 }, btn = { 0.898, 1, 0.959 } },
    LAVENDER = { name = "Glass: Lavender", style = "GLASS", accent = "VIOLET",
        bg = { 0.099, 0.078, 0.135 }, border = { 0.521, 0.452, 0.64 }, rim = { 0.018, 0.011, 0.03 },
        grain = { 1, 1, 1, 0 }, light = { 0.938, 0.902, 1 }, plate = { 0.257, 0.209, 0.34 },
        text = { 0.941, 0.918, 0.98 }, dim = { 0.794, 0.744, 0.88 }, faint = { 0.572, 0.521, 0.66 }, btn = { 0.947, 0.916, 1 } },
    COPPER = { name = "Glass: Copper", style = "GLASS", accent = "EMBER",
        bg = { 0.135, 0.089, 0.066 }, border = { 0.64, 0.488, 0.412 }, rim = { 0.03, 0.015, 0.007 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.921, 0.881 }, plate = { 0.34, 0.234, 0.181 },
        text = { 0.98, 0.93, 0.905 }, dim = { 0.88, 0.77, 0.715 }, faint = { 0.66, 0.548, 0.492 }, btn = { 1, 0.932, 0.898 } },
    DEEPSEA = { name = "Glass: Deep sea", style = "GLASS", accent = "TEAL",
        bg = { 0.032, 0.101, 0.115 }, border = { 0.317, 0.586, 0.64 }, rim = { 0, 0.021, 0.025 },
        grain = { 1, 1, 1, 0 }, light = { 0.832, 0.972, 1 }, plate = { 0.098, 0.257, 0.289 },
        text = { 0.874, 0.962, 0.98 }, dim = { 0.648, 0.841, 0.88 }, faint = { 0.422, 0.62, 0.66 }, btn = { 0.856, 0.976, 1 } },
    BLOSSOM = { name = "Glass: Cherry blossom", style = "GLASS", accent = "ROSE",
        bg = { 0.135, 0.085, 0.105 }, border = { 0.64, 0.473, 0.54 }, rim = { 0.03, 0.013, 0.02 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.913, 0.948 }, plate = { 0.34, 0.224, 0.27 },
        text = { 0.98, 0.925, 0.947 }, dim = { 0.88, 0.76, 0.808 }, faint = { 0.66, 0.537, 0.586 }, btn = { 1, 0.926, 0.955 } },
    LIME = { name = "Glass: Lime", style = "GLASS", accent = "FEL",
        bg = { 0.103, 0.135, 0.066 }, border = { 0.533, 0.64, 0.412 }, rim = { 0.019, 0.03, 0.007 },
        grain = { 1, 1, 1, 0 }, light = { 0.944, 1, 0.881 }, plate = { 0.266, 0.34, 0.181 },
        text = { 0.945, 0.98, 0.905 }, dim = { 0.803, 0.88, 0.715 }, faint = { 0.581, 0.66, 0.492 }, btn = { 0.952, 1, 0.898 } },
    INDIGO = { name = "Glass: Indigo", style = "GLASS", accent = "ARCANE",
        bg = { 0.051, 0.042, 0.135 }, border = { 0.362, 0.331, 0.64 }, rim = { 0.003, 0, 0.03 },
        grain = { 1, 1, 1, 0 }, light = { 0.855, 0.839, 1 }, plate = { 0.146, 0.125, 0.34 },
        text = { 0.889, 0.879, 0.98 }, dim = { 0.68, 0.657, 0.88 }, faint = { 0.496, 0.472, 0.72 }, btn = { 0.876, 0.862, 1 } },
    STEELBLUE = { name = "Glass: Steel blue", style = "GLASS", accent = "FROST",
        bg = { 0.09, 0.114, 0.135 }, border = { 0.492, 0.571, 0.64 }, rim = { 0.015, 0.023, 0.03 },
        grain = { 1, 1, 1, 0 }, light = { 0.923, 0.964, 1 }, plate = { 0.237, 0.292, 0.34 },
        text = { 0.931, 0.957, 0.98 }, dim = { 0.774, 0.83, 0.88 }, faint = { 0.551, 0.609, 0.66 }, btn = { 0.934, 0.969, 1 } },
    MOCHA = { name = "Glass: Mocha", style = "GLASS", accent = "GOLD",
        bg = { 0.135, 0.11, 0.09 }, border = { 0.64, 0.556, 0.492 }, rim = { 0.03, 0.022, 0.015 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.956, 0.923 }, plate = { 0.34, 0.282, 0.237 },
        text = { 0.98, 0.953, 0.931 }, dim = { 0.88, 0.82, 0.774 }, faint = { 0.66, 0.598, 0.551 }, btn = { 1, 0.963, 0.934 } },
    VOID = { name = "Glass: Void (black and purple)", style = "GLASS", accent = "ORCHID",
        bg = { 0.06, 0.045, 0.068 }, border = { 0.546, 0.237, 0.64 }, rim = { 0.013, 0.008, 0.015 },
        grain = { 1, 1, 1, 0 }, light = { 0.951, 0.79, 1 }, plate = { 0.153, 0.119, 0.17 },
        text = { 0.964, 0.931, 0.98 }, dim = { 0.845, 0.774, 0.88 }, faint = { 0.624, 0.551, 0.66 }, btn = { 0.958, 0.82, 1 } },
    GCLASS   = { name = "Glass: your class color", style = "GLASS", accent = "CLASS" },      -- built at login

    WARM   = { name = "Fantasy: Warm (tavern leather)", accent = "GOLD",
               bg = { 0.075, 0.060, 0.045 }, border = { 0.42, 0.32, 0.17 }, rim = { 0.03, 0.025, 0.015 },
               grain = { 0.62, 0.47, 0.29, 0.13 }, light = { 1.00, 0.88, 0.62 }, plate = { 0.17, 0.13, 0.08 },
               text = { 0.90, 0.86, 0.76 }, dim = { 0.80, 0.74, 0.60 }, faint = { 0.60, 0.54, 0.42 }, btn = { 1.00, 0.88, 0.62 } },
    DARK   = { name = "Fantasy: Dark (obsidian)", accent = "GOLD",
               bg = { 0.035, 0.035, 0.040 }, border = { 0.27, 0.27, 0.30 }, rim = { 0.00, 0.00, 0.00 },
               grain = { 0.50, 0.50, 0.56, 0.08 }, light = { 0.90, 0.92, 1.00 }, plate = { 0.10, 0.10, 0.115 },
               text = { 0.88, 0.88, 0.90 }, dim = { 0.72, 0.72, 0.76 }, faint = { 0.50, 0.50, 0.54 }, btn = { 0.92, 0.92, 0.95 } },
    COLD   = { name = "Fantasy: Cold (frost slate)", accent = "FROST",
               bg = { 0.045, 0.062, 0.085 }, border = { 0.36, 0.46, 0.58 }, rim = { 0.01, 0.02, 0.035 },
               grain = { 0.40, 0.55, 0.75, 0.12 }, light = { 0.75, 0.90, 1.00 }, plate = { 0.09, 0.13, 0.18 },
               text = { 0.86, 0.91, 0.96 }, dim = { 0.68, 0.77, 0.86 }, faint = { 0.46, 0.55, 0.65 }, btn = { 0.82, 0.92, 1.00 } },
    FOREST = { name = "Fantasy: Forest (moss and brass)", accent = "VERDANT",
               bg = { 0.045, 0.065, 0.045 }, border = { 0.38, 0.40, 0.20 }, rim = { 0.015, 0.025, 0.015 },
               grain = { 0.42, 0.58, 0.32, 0.12 }, light = { 0.85, 1.00, 0.70 }, plate = { 0.10, 0.14, 0.085 },
               text = { 0.88, 0.92, 0.80 }, dim = { 0.72, 0.80, 0.62 }, faint = { 0.50, 0.58, 0.42 }, btn = { 0.90, 0.96, 0.70 } },
    BLOOD  = { name = "Fantasy: Blood (crimson iron)", accent = "EMBER",
               bg = { 0.085, 0.040, 0.040 }, border = { 0.46, 0.22, 0.18 }, rim = { 0.03, 0.01, 0.01 },
               grain = { 0.70, 0.30, 0.26, 0.12 }, light = { 1.00, 0.70, 0.60 }, plate = { 0.18, 0.08, 0.075 },
               text = { 0.94, 0.86, 0.82 }, dim = { 0.84, 0.70, 0.66 }, faint = { 0.62, 0.46, 0.44 }, btn = { 1.00, 0.82, 0.72 } },
    ARCANE = { name = "Fantasy: Arcane (violet dusk)", accent = "ARCANE",
               bg = { 0.060, 0.045, 0.085 }, border = { 0.42, 0.34, 0.56 }, rim = { 0.02, 0.012, 0.035 },
               grain = { 0.52, 0.40, 0.78, 0.12 }, light = { 0.85, 0.75, 1.00 }, plate = { 0.13, 0.095, 0.185 },
               text = { 0.91, 0.87, 0.96 }, dim = { 0.78, 0.71, 0.88 }, faint = { 0.56, 0.49, 0.66 }, btn = { 0.92, 0.84, 1.00 } },
    SAND   = { name = "Fantasy: Sand (desert stone)", accent = "AMBER",
               bg = { 0.105, 0.090, 0.065 }, border = { 0.58, 0.48, 0.30 }, rim = { 0.04, 0.035, 0.02 },
               grain = { 0.80, 0.68, 0.44, 0.13 }, light = { 1.00, 0.93, 0.74 }, plate = { 0.23, 0.20, 0.14 },
               text = { 0.94, 0.90, 0.80 }, dim = { 0.84, 0.78, 0.64 }, faint = { 0.64, 0.58, 0.46 }, btn = { 1.00, 0.93, 0.74 } },
    FORGE  = { name = "Fantasy: Forge (ember and iron)", accent = "EMBER",
               bg = { 0.080, 0.045, 0.030 }, border = { 0.56, 0.30, 0.14 }, rim = { 0.03, 0.015, 0.01 },
               grain = { 0.78, 0.42, 0.20, 0.14 }, light = { 1.00, 0.80, 0.52 }, plate = { 0.19, 0.10, 0.06 },
               text = { 0.94, 0.86, 0.78 }, dim = { 0.84, 0.70, 0.58 }, faint = { 0.62, 0.50, 0.40 }, btn = { 1.00, 0.80, 0.52 } },
    ROYAL  = { name = "Fantasy: Royal (purple and gold)", accent = "GOLD",
               bg = { 0.060, 0.040, 0.085 }, border = { 0.50, 0.40, 0.22 }, rim = { 0.02, 0.012, 0.03 },
               grain = { 0.52, 0.38, 0.70, 0.12 }, light = { 1.00, 0.90, 0.66 }, plate = { 0.15, 0.10, 0.21 },
               text = { 0.92, 0.88, 0.94 }, dim = { 0.80, 0.74, 0.84 }, faint = { 0.60, 0.54, 0.64 }, btn = { 1.00, 0.90, 0.66 } },
    ABYSS  = { name = "Fantasy: Abyss (deep sea)", accent = "TEAL",
               bg = { 0.030, 0.060, 0.070 }, border = { 0.20, 0.42, 0.44 }, rim = { 0.01, 0.02, 0.025 },
               grain = { 0.30, 0.60, 0.62, 0.12 }, light = { 0.74, 1.00, 0.98 }, plate = { 0.07, 0.15, 0.17 },
               text = { 0.84, 0.94, 0.94 }, dim = { 0.66, 0.82, 0.82 }, faint = { 0.46, 0.60, 0.60 }, btn = { 0.74, 1.00, 0.98 } },
    FEL    = { name = "Fantasy: Fel (sickly green)", accent = "FEL",
               bg = { 0.045, 0.065, 0.030 }, border = { 0.34, 0.50, 0.16 }, rim = { 0.015, 0.025, 0.01 },
               grain = { 0.46, 0.70, 0.22, 0.13 }, light = { 0.84, 1.00, 0.56 }, plate = { 0.10, 0.16, 0.07 },
               text = { 0.88, 0.94, 0.80 }, dim = { 0.74, 0.84, 0.62 }, faint = { 0.54, 0.62, 0.44 }, btn = { 0.84, 1.00, 0.56 } },
    BONE   = { name = "Fantasy: Bone (ivory)", accent = "BONE",
               bg = { 0.090, 0.085, 0.075 }, border = { 0.62, 0.58, 0.48 }, rim = { 0.03, 0.03, 0.025 },
               grain = { 0.86, 0.82, 0.70, 0.10 }, light = { 1.00, 0.98, 0.90 }, plate = { 0.21, 0.20, 0.17 },
               text = { 0.94, 0.93, 0.88 }, dim = { 0.82, 0.80, 0.72 }, faint = { 0.62, 0.60, 0.54 }, btn = { 1.00, 0.98, 0.90 } },
    ONYX   = { name = "Fantasy: Onyx (black and red)", accent = "SCARLET",
               bg = { 0.030, 0.028, 0.030 }, border = { 0.55, 0.13, 0.14 }, rim = { 0.005, 0.005, 0.005 },
               grain = { 0.60, 0.14, 0.14, 0.12 }, light = { 1.00, 0.62, 0.56 }, plate = { 0.13, 0.07, 0.07 },
               text = { 0.93, 0.90, 0.89 }, dim = { 0.80, 0.70, 0.68 }, faint = { 0.58, 0.48, 0.47 }, btn = { 1.00, 0.80, 0.76 } },
    DRAGON = { name = "Fantasy: Dragonfire (red and gold)", accent = "GOLD",
               bg = { 0.085, 0.03, 0.025 }, border = { 0.62, 0.4, 0.16 }, rim = { 0.03, 0.01, 0.008 },
               grain = { 0.8, 0.3, 0.18, 0.13 }, light = { 1, 0.84, 0.52 }, plate = { 0.21, 0.08, 0.06 },
               text = { 0.96, 0.88, 0.82 }, dim = { 0.86, 0.72, 0.62 }, faint = { 0.64, 0.5, 0.42 }, btn = { 1, 0.86, 0.58 } },
    MOON = { name = "Fantasy: Moonlit (silver night)", accent = "PLATINUM",
             bg = { 0.04, 0.05, 0.08 }, border = { 0.46, 0.5, 0.6 }, rim = { 0.012, 0.015, 0.03 },
             grain = { 0.6, 0.66, 0.84, 0.11 }, light = { 0.9, 0.94, 1 }, plate = { 0.1, 0.13, 0.2 },
             text = { 0.9, 0.92, 0.97 }, dim = { 0.72, 0.76, 0.86 }, faint = { 0.52, 0.56, 0.66 }, btn = { 0.9, 0.94, 1 } },
    VERDIGRIS = { name = "Fantasy: Verdigris (aged copper)", accent = "TEAL",
                  bg = { 0.045, 0.07, 0.06 }, border = { 0.42, 0.52, 0.4 }, rim = { 0.015, 0.025, 0.02 },
                  grain = { 0.4, 0.7, 0.6, 0.12 }, light = { 0.8, 1, 0.9 }, plate = { 0.11, 0.17, 0.15 },
                  text = { 0.88, 0.94, 0.9 }, dim = { 0.7, 0.82, 0.76 }, faint = { 0.5, 0.6, 0.56 }, btn = { 0.8, 1, 0.9 } },
    AUTUMN = { name = "Fantasy: Autumn (rust and amber)", accent = "AMBER",
               bg = { 0.085, 0.05, 0.025 }, border = { 0.58, 0.36, 0.16 }, rim = { 0.03, 0.018, 0.008 },
               grain = { 0.84, 0.5, 0.2, 0.13 }, light = { 1, 0.84, 0.56 }, plate = { 0.2, 0.12, 0.06 },
               text = { 0.95, 0.88, 0.78 }, dim = { 0.84, 0.72, 0.56 }, faint = { 0.62, 0.52, 0.4 }, btn = { 1, 0.84, 0.56 } },
    TWILIGHT = { name = "Fantasy: Twilight (violet and steel)", accent = "ORCHID",
                 bg = { 0.05, 0.04, 0.08 }, border = { 0.36, 0.44, 0.56 }, rim = { 0.015, 0.012, 0.03 },
                 grain = { 0.5, 0.44, 0.8, 0.12 }, light = { 0.88, 0.92, 1 }, plate = { 0.12, 0.1, 0.2 },
                 text = { 0.91, 0.9, 0.96 }, dim = { 0.74, 0.74, 0.86 }, faint = { 0.54, 0.54, 0.66 }, btn = { 0.92, 0.88, 1 } },
    PLAGUE = { name = "Fantasy: Plague (sallow yellow)", accent = "FEL",
               bg = { 0.07, 0.068, 0.03 }, border = { 0.52, 0.5, 0.2 }, rim = { 0.025, 0.025, 0.01 },
               grain = { 0.72, 0.7, 0.28, 0.12 }, light = { 0.98, 0.98, 0.62 }, plate = { 0.17, 0.16, 0.07 },
               text = { 0.93, 0.93, 0.82 }, dim = { 0.8, 0.8, 0.62 }, faint = { 0.6, 0.6, 0.44 }, btn = { 0.98, 0.98, 0.66 } },
    STEEL = { name = "Fantasy: Steel (cold iron)", accent = "FROST",
              bg = { 0.055, 0.06, 0.068 }, border = { 0.44, 0.48, 0.54 }, rim = { 0.018, 0.02, 0.024 },
              grain = { 0.7, 0.76, 0.84, 0.1 }, light = { 0.92, 0.96, 1 }, plate = { 0.14, 0.15, 0.17 },
              text = { 0.92, 0.93, 0.95 }, dim = { 0.76, 0.78, 0.82 }, faint = { 0.56, 0.58, 0.62 }, btn = { 0.92, 0.96, 1 } },
    SUNWELL = { name = "Fantasy: Sunwell (white gold)", accent = "GOLD",
                bg = { 0.1, 0.085, 0.05 }, border = { 0.78, 0.66, 0.36 }, rim = { 0.035, 0.03, 0.015 },
                grain = { 1, 0.9, 0.6, 0.11 }, light = { 1, 0.97, 0.82 }, plate = { 0.24, 0.2, 0.11 },
                text = { 0.98, 0.95, 0.86 }, dim = { 0.88, 0.82, 0.66 }, faint = { 0.66, 0.6, 0.46 }, btn = { 1, 0.96, 0.8 } },
    ROSEWOOD = { name = "Fantasy: Rosewood (dark red wood)", accent = "ROSE",
                 bg = { 0.075, 0.035, 0.04 }, border = { 0.52, 0.28, 0.3 }, rim = { 0.028, 0.012, 0.014 },
                 grain = { 0.7, 0.32, 0.36, 0.13 }, light = { 1, 0.8, 0.8 }, plate = { 0.18, 0.09, 0.1 },
                 text = { 0.95, 0.88, 0.88 }, dim = { 0.84, 0.7, 0.7 }, faint = { 0.62, 0.5, 0.5 }, btn = { 1, 0.82, 0.82 } },
    -- 10.0.0: fifteen more fantasy themes
    FROSTFIRE = { name = "Fantasy: Frostfire (ice and ember)", accent = "EMBER",
        bg = { 0.028, 0.055, 0.085 }, border = { 0.6, 0.306, 0.159 }, rim = { 0.01, 0.019, 0.03 },
        grain = { 0.23, 0.496, 0.8, 0.12 }, light = { 1, 0.706, 0.559 }, plate = { 0.071, 0.131, 0.2 },
        text = { 0.833, 0.887, 0.95 }, dim = { 0.64, 0.738, 0.85 }, faint = { 0.438, 0.528, 0.63 }, btn = { 1, 0.72, 0.58 } },
    DREAM = { name = "Fantasy: Emerald Dream (deep green and gold)", accent = "GOLD",
        bg = { 0.026, 0.085, 0.045 }, border = { 0.6, 0.507, 0.201 }, rim = { 0.009, 0.03, 0.016 },
        grain = { 0.2, 0.8, 0.4, 0.12 }, light = { 1, 0.907, 0.601 }, plate = { 0.064, 0.2, 0.109 },
        text = { 0.827, 0.95, 0.868 }, dim = { 0.629, 0.85, 0.703 }, faint = { 0.428, 0.63, 0.496 }, btn = { 1, 0.911, 0.62 } },
    SHADOW = { name = "Fantasy: Shadow (violet black)", accent = "ARCANE",
        bg = { 0.044, 0.026, 0.064 }, border = { 0.422, 0.285, 0.6 }, rim = { 0.015, 0.009, 0.022 },
        grain = { 0.528, 0.29, 0.8, 0.12 }, light = { 0.822, 0.685, 1 }, plate = { 0.104, 0.063, 0.15 },
        text = { 0.894, 0.845, 0.95 }, dim = { 0.75, 0.662, 0.85 }, faint = { 0.539, 0.459, 0.63 }, btn = { 0.83, 0.7, 1 } },
    TITAN = { name = "Fantasy: Titan (bronze and blue)", accent = "AZURE",
        bg = { 0.085, 0.06, 0.034 }, border = { 0.264, 0.432, 0.6 }, rim = { 0.03, 0.021, 0.012 },
        grain = { 0.8, 0.545, 0.29, 0.12 }, light = { 0.664, 0.832, 1 }, plate = { 0.2, 0.142, 0.084 },
        text = { 0.95, 0.898, 0.845 }, dim = { 0.85, 0.756, 0.662 }, faint = { 0.63, 0.544, 0.459 }, btn = { 0.68, 0.84, 1 } },
    LIGHTFORGED = { name = "Fantasy: Lightforged (gold and white)", accent = "GOLD",
        bg = { 0.106, 0.095, 0.05 }, border = { 0.6, 0.561, 0.369 }, rim = { 0.037, 0.034, 0.018 },
        grain = { 0.8, 0.71, 0.35, 0.12 }, light = { 1, 0.962, 0.769 }, plate = { 0.25, 0.225, 0.122 },
        text = { 0.95, 0.931, 0.857 }, dim = { 0.85, 0.817, 0.684 }, faint = { 0.63, 0.6, 0.479 }, btn = { 1, 0.963, 0.78 } },
    NETHER = { name = "Fantasy: Nether (magenta storm)", accent = "ORCHID",
        bg = { 0.085, 0.028, 0.085 }, border = { 0.552, 0.243, 0.6 }, rim = { 0.03, 0.01, 0.03 },
        grain = { 0.8, 0.23, 0.8, 0.12 }, light = { 0.952, 0.643, 1 }, plate = { 0.2, 0.071, 0.2 },
        text = { 0.95, 0.833, 0.95 }, dim = { 0.85, 0.64, 0.85 }, faint = { 0.63, 0.438, 0.63 }, btn = { 0.955, 0.66, 1 } },
    TUNDRA = { name = "Fantasy: Tundra (pale ice)", accent = "FROST",
        bg = { 0.066, 0.09, 0.102 }, border = { 0.411, 0.543, 0.6 }, rim = { 0.023, 0.032, 0.036 },
        grain = { 0.5, 0.7, 0.8, 0.12 }, light = { 0.811, 0.943, 1 }, plate = { 0.158, 0.213, 0.24 },
        text = { 0.888, 0.929, 0.95 }, dim = { 0.739, 0.813, 0.85 }, faint = { 0.529, 0.596, 0.63 }, btn = { 0.82, 0.946, 1 } },
    JUNGLE = { name = "Fantasy: Jungle (green and amber)", accent = "AMBER",
        bg = { 0.04, 0.085, 0.031 }, border = { 0.6, 0.432, 0.18 }, rim = { 0.014, 0.03, 0.011 },
        grain = { 0.35, 0.8, 0.26, 0.12 }, light = { 1, 0.832, 0.58 }, plate = { 0.098, 0.2, 0.078 },
        text = { 0.857, 0.95, 0.839 }, dim = { 0.684, 0.85, 0.651 }, faint = { 0.479, 0.63, 0.449 }, btn = { 1, 0.84, 0.6 } },
    MOLTEN = { name = "Fantasy: Molten (black and orange)", accent = "EMBER",
        bg = { 0.051, 0.037, 0.031 }, border = { 0.6, 0.267, 0.075 }, rim = { 0.018, 0.013, 0.011 },
        grain = { 0.8, 0.558, 0.47, 0.12 }, light = { 1, 0.667, 0.475 }, plate = { 0.12, 0.087, 0.075 },
        text = { 0.95, 0.9, 0.882 }, dim = { 0.85, 0.761, 0.728 }, faint = { 0.63, 0.549, 0.519 }, btn = { 1, 0.683, 0.5 } },
    TIDAL = { name = "Fantasy: Tidal (teal and coral)", accent = "CORAL",
        bg = { 0.026, 0.081, 0.085 }, border = { 0.6, 0.314, 0.243 }, rim = { 0.009, 0.029, 0.03 },
        grain = { 0.2, 0.76, 0.8, 0.12 }, light = { 1, 0.714, 0.643 }, plate = { 0.064, 0.191, 0.2 },
        text = { 0.827, 0.942, 0.95 }, dim = { 0.629, 0.835, 0.85 }, faint = { 0.428, 0.617, 0.63 }, btn = { 1, 0.728, 0.66 } },
    WINE = { name = "Fantasy: Wine (burgundy and gold)", accent = "GOLD",
        bg = { 0.085, 0.026, 0.047 }, border = { 0.6, 0.499, 0.222 }, rim = { 0.03, 0.009, 0.017 },
        grain = { 0.8, 0.2, 0.42, 0.12 }, light = { 1, 0.899, 0.622 }, plate = { 0.2, 0.064, 0.114 },
        text = { 0.95, 0.827, 0.872 }, dim = { 0.85, 0.629, 0.71 }, faint = { 0.65, 0.442, 0.518 }, btn = { 1, 0.904, 0.64 } },
    ASHEN = { name = "Fantasy: Ashen (ash gray and scarlet)", accent = "SCARLET",
        bg = { 0.085, 0.08, 0.078 }, border = { 0.6, 0.117, 0.133 }, rim = { 0.03, 0.028, 0.027 },
        grain = { 0.8, 0.752, 0.728, 0.12 }, light = { 1, 0.517, 0.533 }, plate = { 0.2, 0.189, 0.184 },
        text = { 0.95, 0.94, 0.935 }, dim = { 0.85, 0.832, 0.823 }, faint = { 0.63, 0.614, 0.606 }, btn = { 1, 0.7, 0.71 } },
    OAK = { name = "Fantasy: Oak (pale wood)", accent = "AMBER",
        bg = { 0.111, 0.085, 0.052 }, border = { 0.6, 0.492, 0.306 }, rim = { 0.039, 0.03, 0.019 },
        grain = { 0.8, 0.605, 0.35, 0.12 }, light = { 1, 0.892, 0.706 }, plate = { 0.26, 0.203, 0.127 },
        text = { 0.95, 0.91, 0.857 }, dim = { 0.85, 0.778, 0.684 }, faint = { 0.63, 0.564, 0.479 }, btn = { 1, 0.897, 0.72 } },
    STORMCALLER = { name = "Fantasy: Stormcaller (storm blue and lightning)", accent = "AZURE",
        bg = { 0.026, 0.045, 0.085 }, border = { 0.285, 0.516, 0.6 }, rim = { 0.009, 0.016, 0.03 },
        grain = { 0.2, 0.4, 0.8, 0.12 }, light = { 0.685, 0.916, 1 }, plate = { 0.064, 0.109, 0.2 },
        text = { 0.827, 0.868, 0.95 }, dim = { 0.629, 0.703, 0.85 }, faint = { 0.428, 0.496, 0.63 }, btn = { 0.7, 0.92, 1 } },
    STARLIGHT = { name = "Fantasy: Starlight (night purple and silver)", accent = "PLATINUM",
        bg = { 0.044, 0.028, 0.085 }, border = { 0.508, 0.529, 0.6 }, rim = { 0.015, 0.01, 0.03 },
        grain = { 0.382, 0.23, 0.8, 0.12 }, light = { 0.908, 0.929, 1 }, plate = { 0.105, 0.071, 0.2 },
        text = { 0.864, 0.833, 0.95 }, dim = { 0.696, 0.64, 0.85 }, faint = { 0.521, 0.466, 0.67 }, btn = { 0.912, 0.933, 1 } },
    CLASS  = { name = "Fantasy: Class (your class color)", accent = "CLASS" },      -- built from your class color at login
    -- Celestial (11.11, in place of Runic): a night sky deepening toward the top with a horizon glow
    -- at its foot, sparse stars and a faint Milky Way, one fine line round each panel, and on large
    -- windows one constellation and an orbit. Each was made from the Runic theme it replaces (the same accent).
    C_POLARIS = { name = "Celestial: Polaris (silver night, frost stars)", style = "CELESTIAL", accent = "FROST",
        bg = { 0.055, 0.057, 0.074 }, border = { 0.374, 0.399, 0.447 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.775, 0.901, 1 }, plate = { 0.153, 0.159, 0.201 },
        text = { 0.89, 0.907, 0.92 }, dim = { 0.73, 0.747, 0.76 }, faint = { 0.525, 0.539, 0.55 }, btn = { 0.775, 0.901, 1 } },
    C_ECLIPSE = { name = "Celestial: Eclipse (black sky, ember corona)", style = "CELESTIAL", accent = "EMBER",
        bg = { 0.036, 0.037, 0.055 }, border = { 0.352, 0.32, 0.338 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.978, 0.739, 0.649 }, plate = { 0.113, 0.117, 0.161 },
        text = { 0.917, 0.885, 0.873 }, dim = { 0.757, 0.725, 0.713 }, faint = { 0.547, 0.521, 0.511 }, btn = { 0.978, 0.739, 0.649 } },
    C_BLUEHOUR = { name = "Celestial: Blue Hour (slate sky, azure stars)", style = "CELESTIAL", accent = "AZURE",
        bg = { 0.041, 0.051, 0.074 }, border = { 0.326, 0.38, 0.447 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.712, 0.874, 1 }, plate = { 0.124, 0.146, 0.201 },
        text = { 0.882, 0.903, 0.92 }, dim = { 0.722, 0.743, 0.76 }, faint = { 0.518, 0.536, 0.55 }, btn = { 0.712, 0.874, 1 } },
    C_ZENITH = { name = "Celestial: Zenith (pale night, gold stars)", style = "CELESTIAL", accent = "GOLD",
        bg = { 0.074, 0.073, 0.085 }, border = { 0.463, 0.449, 0.435 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.919, 0.73 }, plate = { 0.193, 0.193, 0.225 },
        text = { 0.92, 0.909, 0.884 }, dim = { 0.76, 0.749, 0.724 }, faint = { 0.55, 0.541, 0.52 }, btn = { 1, 0.919, 0.73 } },
    C_DESERT = { name = "Celestial: Desert Sky (warm dusk, amber stars)", style = "CELESTIAL", accent = "AMBER",
        bg = { 0.069, 0.054, 0.052 }, border = { 0.447, 0.389, 0.336 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.883, 0.685 }, plate = { 0.183, 0.153, 0.155 },
        text = { 0.92, 0.904, 0.878 }, dim = { 0.76, 0.744, 0.718 }, faint = { 0.55, 0.537, 0.515 }, btn = { 1, 0.883, 0.685 } },
    C_MOON = { name = "Celestial: Moonlight (cool night, silver stars)", style = "CELESTIAL", accent = "PLATINUM",
        bg = { 0.052, 0.057, 0.085 }, border = { 0.39, 0.406, 0.473 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.928, 0.946, 0.973 }, plate = { 0.147, 0.159, 0.225 },
        text = { 0.91, 0.913, 0.916 }, dim = { 0.75, 0.753, 0.756 }, faint = { 0.542, 0.544, 0.547 }, btn = { 0.928, 0.946, 0.973 } },
    C_BLOODMOON = { name = "Celestial: Blood Moon (dark red sky, scarlet stars)", style = "CELESTIAL", accent = "SCARLET",
        bg = { 0.058, 0.029, 0.044 }, border = { 0.415, 0.282, 0.307 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.991, 0.64, 0.649 }, plate = { 0.16, 0.1, 0.138 },
        text = { 0.919, 0.872, 0.873 }, dim = { 0.759, 0.712, 0.713 }, faint = { 0.549, 0.51, 0.511 }, btn = { 0.991, 0.64, 0.649 } },
    C_AURORA = { name = "Celestial: Aurora (green night, mint lights)", style = "CELESTIAL", accent = "MINT",
        bg = { 0.03, 0.054, 0.058 }, border = { 0.295, 0.402, 0.381 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.712, 0.964, 0.874 }, plate = { 0.1, 0.153, 0.168 },
        text = { 0.882, 0.915, 0.903 }, dim = { 0.722, 0.755, 0.743 }, faint = { 0.518, 0.546, 0.536 }, btn = { 0.712, 0.964, 0.874 } },
    C_WINTER = { name = "Celestial: Winter Sky (ice blue, frost stars)", style = "CELESTIAL", accent = "FROST",
        bg = { 0.041, 0.054, 0.085 }, border = { 0.335, 0.392, 0.477 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.775, 0.901, 1 }, plate = { 0.124, 0.153, 0.225 },
        text = { 0.89, 0.907, 0.92 }, dim = { 0.73, 0.747, 0.76 }, faint = { 0.525, 0.539, 0.55 }, btn = { 0.775, 0.901, 1 } },
    C_COMET = { name = "Celestial: Comet (scorched sky, a fiery tail)", style = "CELESTIAL", accent = "EMBER",
        bg = { 0.058, 0.037, 0.044 }, border = { 0.413, 0.32, 0.307 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.978, 0.739, 0.649 }, plate = { 0.16, 0.117, 0.138 },
        text = { 0.917, 0.885, 0.873 }, dim = { 0.757, 0.725, 0.713 }, faint = { 0.547, 0.521, 0.511 }, btn = { 0.978, 0.739, 0.649 } },
    C_STARSTORM = { name = "Celestial: Starstorm (thunder gray, teal stars)", style = "CELESTIAL", accent = "TEAL",
        bg = { 0.041, 0.046, 0.074 }, border = { 0.318, 0.374, 0.435 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.663, 0.937, 0.928 }, plate = { 0.124, 0.136, 0.201 },
        text = { 0.875, 0.912, 0.91 }, dim = { 0.715, 0.752, 0.75 }, faint = { 0.512, 0.543, 0.542 }, btn = { 0.663, 0.937, 0.928 } },
    C_SOLSTICE = { name = "Celestial: Solstice (golden dusk, gold stars)", style = "CELESTIAL", accent = "GOLD",
        bg = { 0.063, 0.054, 0.047 }, border = { 0.432, 0.395, 0.328 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.919, 0.73 }, plate = { 0.17, 0.153, 0.144 },
        text = { 0.92, 0.909, 0.884 }, dim = { 0.76, 0.749, 0.724 }, faint = { 0.55, 0.541, 0.52 }, btn = { 1, 0.919, 0.73 } },
    C_VOID = { name = "Celestial: Void (deep violet, void stars)", style = "CELESTIAL", accent = "VIOLET",
        bg = { 0.036, 0.026, 0.069 }, border = { 0.333, 0.298, 0.431 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.856, 0.793, 1 }, plate = { 0.113, 0.093, 0.191 },
        text = { 0.901, 0.892, 0.92 }, dim = { 0.741, 0.732, 0.76 }, faint = { 0.534, 0.527, 0.55 }, btn = { 0.856, 0.793, 1 } },
    C_GROVE = { name = "Celestial: Moonlit Grove (forest night, green stars)", style = "CELESTIAL", accent = "VERDANT",
        bg = { 0.036, 0.048, 0.047 }, border = { 0.317, 0.381, 0.331 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.753, 0.932, 0.753 }, plate = { 0.113, 0.14, 0.144 },
        text = { 0.887, 0.911, 0.887 }, dim = { 0.727, 0.751, 0.727 }, faint = { 0.522, 0.542, 0.522 }, btn = { 0.753, 0.933, 0.753 } },
    C_TIDES = { name = "Celestial: Tides (sea night, teal stars)", style = "CELESTIAL", accent = "TEAL",
        bg = { 0.025, 0.048, 0.069 }, border = { 0.272, 0.382, 0.42 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.663, 0.937, 0.928 }, plate = { 0.09, 0.14, 0.191 },
        text = { 0.875, 0.912, 0.91 }, dim = { 0.715, 0.752, 0.75 }, faint = { 0.512, 0.543, 0.542 }, btn = { 0.663, 0.937, 0.928 } },
    C_HARVEST = { name = "Celestial: Harvest Moon (brown dusk, amber stars)", style = "CELESTIAL", accent = "AMBER",
        bg = { 0.052, 0.046, 0.05 }, border = { 0.401, 0.366, 0.328 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.883, 0.685 }, plate = { 0.147, 0.136, 0.151 },
        text = { 0.92, 0.904, 0.878 }, dim = { 0.76, 0.744, 0.718 }, faint = { 0.55, 0.537, 0.515 }, btn = { 1, 0.883, 0.685 } },
    C_CLEAR = { name = "Celestial: Clear Night (pale blue, azure stars)", style = "CELESTIAL", accent = "AZURE",
        bg = { 0.047, 0.059, 0.091 }, border = { 0.341, 0.403, 0.493 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.712, 0.874, 1 }, plate = { 0.136, 0.163, 0.237 },
        text = { 0.882, 0.903, 0.92 }, dim = { 0.722, 0.743, 0.76 }, faint = { 0.518, 0.536, 0.55 }, btn = { 0.712, 0.874, 1 } },
    C_DAWN = { name = "Celestial: Dawn (rose sky, coral stars)", style = "CELESTIAL", accent = "CORAL",
        bg = { 0.069, 0.048, 0.063 }, border = { 0.447, 0.362, 0.377 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.806, 0.753 }, plate = { 0.183, 0.14, 0.178 },
        text = { 0.92, 0.894, 0.887 }, dim = { 0.76, 0.734, 0.727 }, faint = { 0.55, 0.528, 0.522 }, btn = { 1, 0.806, 0.753 } },
    C_DUSK = { name = "Celestial: Dusk (plum sky, orchid stars)", style = "CELESTIAL", accent = "ORCHID",
        bg = { 0.052, 0.037, 0.069 }, border = { 0.392, 0.328, 0.431 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.942, 0.788, 1 }, plate = { 0.147, 0.117, 0.191 },
        text = { 0.912, 0.892, 0.92 }, dim = { 0.752, 0.732, 0.76 }, faint = { 0.543, 0.526, 0.55 }, btn = { 0.942, 0.789, 1 } },
    C_STARLIGHT = { name = "Celestial: Starlight (night blue, silver stars)", style = "CELESTIAL", accent = "PLATINUM",
        bg = { 0.03, 0.035, 0.069 }, border = { 0.328, 0.345, 0.427 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.928, 0.946, 0.973 }, plate = { 0.1, 0.112, 0.191 },
        text = { 0.91, 0.913, 0.916 }, dim = { 0.75, 0.753, 0.756 }, faint = { 0.542, 0.544, 0.547 }, btn = { 0.928, 0.946, 0.973 } },
    C_REDPLANET = { name = "Celestial: Red Planet (dark sky, red stars)", style = "CELESTIAL", accent = "SCARLET",
        bg = { 0.047, 0.048, 0.066 }, border = { 0.384, 0.336, 0.369 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.991, 0.64, 0.649 }, plate = { 0.136, 0.14, 0.184 },
        text = { 0.919, 0.872, 0.873 }, dim = { 0.759, 0.712, 0.713 }, faint = { 0.549, 0.51, 0.511 }, btn = { 0.991, 0.64, 0.649 } },
    C_GILDED = { name = "Celestial: Gilded Sky (dark bronze, gold stars)", style = "CELESTIAL", accent = "GOLD",
        bg = { 0.052, 0.046, 0.044 }, border = { 0.401, 0.371, 0.32 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.919, 0.73 }, plate = { 0.147, 0.136, 0.138 },
        text = { 0.92, 0.909, 0.884 }, dim = { 0.76, 0.749, 0.724 }, faint = { 0.55, 0.541, 0.52 }, btn = { 1, 0.919, 0.73 } },
    C_SILVERMIST = { name = "Celestial: Silver Mist (gray night, silver stars)", style = "CELESTIAL", accent = "PLATINUM",
        bg = { 0.055, 0.059, 0.077 }, border = { 0.398, 0.414, 0.45 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.928, 0.946, 0.973 }, plate = { 0.153, 0.163, 0.208 },
        text = { 0.91, 0.913, 0.916 }, dim = { 0.75, 0.753, 0.756 }, faint = { 0.542, 0.544, 0.547 }, btn = { 0.928, 0.946, 0.973 } },
    C_EVENINGSTAR = { name = "Celestial: Evening Star (copper dusk, coral stars)", style = "CELESTIAL", accent = "CORAL",
        bg = { 0.058, 0.04, 0.047 }, border = { 0.417, 0.339, 0.331 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.806, 0.753 }, plate = { 0.16, 0.123, 0.144 },
        text = { 0.92, 0.894, 0.887 }, dim = { 0.76, 0.734, 0.727 }, faint = { 0.55, 0.528, 0.522 }, btn = { 1, 0.806, 0.753 } },
    C_HONEYMOON = { name = "Celestial: Honey Moon (amber dusk, amber stars)", style = "CELESTIAL", accent = "AMBER",
        bg = { 0.063, 0.046, 0.039 }, border = { 0.432, 0.366, 0.297 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.883, 0.685 }, plate = { 0.17, 0.136, 0.127 },
        text = { 0.92, 0.904, 0.878 }, dim = { 0.76, 0.744, 0.718 }, faint = { 0.55, 0.537, 0.515 }, btn = { 1, 0.883, 0.685 } },
    C_OPALINE = { name = "Celestial: Opaline (milky night, rose stars)", style = "CELESTIAL", accent = "ROSE",
        bg = { 0.052, 0.059, 0.08 }, border = { 0.401, 0.386, 0.434 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.766, 0.82 }, plate = { 0.147, 0.163, 0.214 },
        text = { 0.92, 0.889, 0.896 }, dim = { 0.76, 0.729, 0.736 }, faint = { 0.55, 0.524, 0.53 }, btn = { 1, 0.766, 0.82 } },
    C_DEEPSPACE = { name = "Celestial: Deep Space (black, arcane stars)", style = "CELESTIAL", accent = "ARCANE",
        bg = { 0.022, 0.024, 0.041 }, border = { 0.294, 0.286, 0.353 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.856, 0.766, 0.991 }, plate = { 0.083, 0.089, 0.132 },
        text = { 0.901, 0.889, 0.919 }, dim = { 0.741, 0.729, 0.759 }, faint = { 0.534, 0.524, 0.549 }, btn = { 0.856, 0.766, 0.991 } },
    C_FELSKY = { name = "Celestial: Fel Sky (tainted night, fel stars)", style = "CELESTIAL", accent = "FEL",
        bg = { 0.03, 0.043, 0.041 }, border = { 0.313, 0.374, 0.302 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.829, 0.982, 0.667 }, plate = { 0.1, 0.129, 0.132 },
        text = { 0.897, 0.918, 0.876 }, dim = { 0.737, 0.758, 0.716 }, faint = { 0.531, 0.548, 0.513 }, btn = { 0.829, 0.982, 0.667 } },
    C_ASHENSKY = { name = "Celestial: Ashen Sky (smoke gray, ember stars)", style = "CELESTIAL", accent = "EMBER",
        bg = { 0.049, 0.048, 0.061 }, border = { 0.39, 0.351, 0.354 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.978, 0.739, 0.649 }, plate = { 0.14, 0.14, 0.174 },
        text = { 0.917, 0.885, 0.873 }, dim = { 0.757, 0.725, 0.713 }, faint = { 0.547, 0.521, 0.511 }, btn = { 0.978, 0.739, 0.649 } },
    C_PEARLMOON = { name = "Celestial: Pearl Moon (pale night, ivory stars)", style = "CELESTIAL", accent = "BONE",
        bg = { 0.063, 0.062, 0.069 }, border = { 0.427, 0.423, 0.414 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.968, 0.951, 0.892 }, plate = { 0.17, 0.17, 0.191 },
        text = { 0.916, 0.913, 0.906 }, dim = { 0.756, 0.753, 0.746 }, faint = { 0.546, 0.544, 0.538 }, btn = { 0.969, 0.951, 0.892 } },
    C_SPIRIT = { name = "Celestial: Spirit Lights (ghostly night, mint stars)", style = "CELESTIAL", accent = "MINT",
        bg = { 0.036, 0.054, 0.074 }, border = { 0.31, 0.402, 0.427 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.712, 0.964, 0.874 }, plate = { 0.113, 0.153, 0.201 },
        text = { 0.882, 0.915, 0.903 }, dim = { 0.722, 0.755, 0.743 }, faint = { 0.518, 0.546, 0.536 }, btn = { 0.712, 0.964, 0.874 } },
    C_ARCANE = { name = "Celestial: Arcane Sky (violet night, arcane stars)", style = "CELESTIAL", accent = "ARCANE",
        bg = { 0.041, 0.032, 0.074 }, border = { 0.348, 0.309, 0.445 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.856, 0.766, 0.991 }, plate = { 0.124, 0.106, 0.201 },
        text = { 0.901, 0.889, 0.919 }, dim = { 0.741, 0.729, 0.759 }, faint = { 0.534, 0.524, 0.549 }, btn = { 0.856, 0.766, 0.991 } },
    C_NEBULA = { name = "Celestial: Crimson Nebula (wine night, crimson stars)", style = "CELESTIAL", accent = "CRIMSON",
        bg = { 0.058, 0.026, 0.052 }, border = { 0.417, 0.284, 0.342 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.703, 0.721 }, plate = { 0.16, 0.093, 0.155 },
        text = { 0.92, 0.88, 0.883 }, dim = { 0.76, 0.72, 0.723 }, faint = { 0.55, 0.517, 0.519 }, btn = { 1, 0.703, 0.721 } },
    C_SAPPHIRE = { name = "Celestial: Sapphire Night (deep blue, azure stars)", style = "CELESTIAL", accent = "AZURE",
        bg = { 0.025, 0.037, 0.08 }, border = { 0.279, 0.341, 0.462 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.712, 0.874, 1 }, plate = { 0.09, 0.117, 0.214 },
        text = { 0.882, 0.903, 0.92 }, dim = { 0.722, 0.743, 0.76 }, faint = { 0.518, 0.536, 0.55 }, btn = { 0.712, 0.874, 1 } },
    C_EMERALD = { name = "Celestial: Emerald Night (deep green, green stars)", style = "CELESTIAL", accent = "VERDANT",
        bg = { 0.025, 0.054, 0.052 }, border = { 0.286, 0.397, 0.347 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.753, 0.932, 0.753 }, plate = { 0.09, 0.153, 0.155 },
        text = { 0.887, 0.911, 0.887 }, dim = { 0.727, 0.751, 0.727 }, faint = { 0.522, 0.542, 0.522 }, btn = { 0.753, 0.933, 0.753 } },
    C_CRYSTAL = { name = "Celestial: Crystal Sky (clear night, frost stars)", style = "CELESTIAL", accent = "FROST",
        bg = { 0.047, 0.054, 0.074 }, border = { 0.351, 0.392, 0.447 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 0.775, 0.901, 1 }, plate = { 0.136, 0.153, 0.201 },
        text = { 0.89, 0.907, 0.92 }, dim = { 0.73, 0.747, 0.76 }, faint = { 0.525, 0.539, 0.55 }, btn = { 0.775, 0.901, 1 } },
    C_ASTROLABE = { name = "Celestial: Astrolabe (old brass, gold stars)", style = "CELESTIAL", accent = "GOLD",
        bg = { 0.047, 0.046, 0.052 }, border = { 0.386, 0.371, 0.343 }, rim = { 0, 0, 0.01 },
        grain = { 1, 1, 1, 0 }, light = { 1, 0.919, 0.73 }, plate = { 0.136, 0.136, 0.155 },
        text = { 0.92, 0.909, 0.884 }, dim = { 0.76, 0.749, 0.724 }, faint = { 0.55, 0.541, 0.52 }, btn = { 1, 0.919, 0.73 } },
    CCLASS = { name = "Celestial: your class color", style = "CELESTIAL", accent = "CLASS" },      -- built from your class color at login
}
-- Lettering styles. body / title are files in Media (left out = the game's own face).
-- wide = the face also has Cyrillic, so it is used for every language except Chinese, Japanese, Korean;
-- without it the face is Latin-only and other languages fall back to the game's fonts.
ns.fontStyles = {
    GLASS     = { name = "Modern",         face = "Exo 2",                body = "Exo2-Medium.ttf", title = "Exo2-SemiBold.ttf", wide = true },
    TITILLIUM = { name = "Sharp",          face = "Titillium Web",        body = "TitilliumWeb-Regular.ttf", title = "TitilliumWeb-SemiBold.ttf" },
    RAJDHANI  = { name = "Squared",        face = "Rajdhani",             body = "Rajdhani-Medium.ttf", title = "Rajdhani-SemiBold.ttf" },
    PLAY      = { name = "Rounded",        face = "Play",                 body = "Play-Regular.ttf", title = "Play-Bold.ttf" },
    CLEAN     = { name = "Condensed",      face = "Fira Sans Condensed",  body = "FiraSansCondensed-SemiBold.ttf", flags = "OUTLINE", wide = true },
    ELEGANT   = { name = "Fantasy titles", face = "Marcellus",            title = "Marcellus-Regular.ttf" },
    STORYBOOK = { name = "Storybook",      face = "Almendra",             body = "AlegreyaSans-Medium.ttf", title = "Almendra-Bold.ttf" },
    RUNIC     = { name = "Engraved",          face = "Metamorphous",         body = "AlegreyaSans-Medium.ttf", title = "Metamorphous-Regular.ttf" },
    BARLOW    = { name = "Clean",          face = "Barlow",               body = "Barlow-Medium.ttf", title = "Barlow-SemiBold.ttf" },
    CHAKRA    = { name = "Tech",           face = "Chakra Petch",         body = "ChakraPetch-Medium.ttf", title = "ChakraPetch-SemiBold.ttf" },
    MONO      = { name = "Terminal",       face = "Share Tech Mono",      body = "ShareTechMono-Regular.ttf", title = "ShareTechMono-Regular.ttf" },
    SCHOLAR   = { name = "Scholar",        face = "Philosopher",          body = "Philosopher-Regular.ttf", title = "Philosopher-Bold.ttf", wide = true },
    SLAB      = { name = "Slab",           face = "Kelly Slab",           body = "KellySlab-Regular.ttf", title = "KellySlab-Regular.ttf", wide = true },
    CAUDEX    = { name = "Manuscript",     face = "Caudex",               body = "Caudex-Regular.ttf", title = "Caudex-Bold.ttf" },
    UNCIAL    = { name = "Celtic",         face = "Uncial Antiqua",       body = "AlegreyaSans-Medium.ttf", title = "UncialAntiqua-Regular.ttf" },
    PIRATA    = { name = "Gothic",         face = "Pirata One",           body = "AlegreyaSans-Medium.ttf", title = "PirataOne-Regular.ttf" },
    FONDA     = { name = "Calligraphy",    face = "Fondamento",           body = "AlegreyaSans-Medium.ttf", title = "Fondamento-Regular.ttf" },
    POSTER    = { name = "Poster",         face = "Staatliches",          body = "Barlow-Medium.ttf", title = "Staatliches-Regular.ttf" },
    -- 10.0.0: fifteen more
    SAIRA     = { name = "Narrow",         face = "Saira Condensed",      body = "SairaCondensed-Medium.ttf", title = "SairaCondensed-SemiBold.ttf" },
    TOMORROW  = { name = "Future",         face = "Tomorrow",             body = "Tomorrow-Medium.ttf", title = "Tomorrow-SemiBold.ttf" },
    BAI       = { name = "Soft",           face = "Bai Jamjuree",         body = "BaiJamjuree-Medium.ttf", title = "BaiJamjuree-SemiBold.ttf" },
    QUANTICO  = { name = "Military",       face = "Quantico",             body = "Quantico-Regular.ttf", title = "Quantico-Bold.ttf" },
    ELECTRO   = { name = "Circuit",        face = "Electrolize",          body = "Electrolize-Regular.ttf", title = "Electrolize-Regular.ttf" },
    ALDRICH   = { name = "Blocky",         face = "Aldrich",              body = "Aldrich-Regular.ttf", title = "Aldrich-Regular.ttf" },
    RUSSO     = { name = "Heavy titles",   face = "Russo One",            body = "Barlow-Medium.ttf", title = "RussoOne-Regular.ttf" },
    AUDIO     = { name = "Arcade",         face = "Audiowide",            body = "Barlow-Medium.ttf", title = "Audiowide-Regular.ttf" },
    IMPERIAL  = { name = "Imperial",       face = "Cinzel Decorative",    body = "AlegreyaSans-Medium.ttf", title = "CinzelDecorative-Bold.ttf" },
    CHRONICLE = { name = "Chronicle",      face = "Spectral",             body = "Spectral-Medium.ttf", title = "Spectral-SemiBold.ttf", wide = true },
    ROMAN     = { name = "Roman",          face = "Forum",                body = "Forum-Regular.ttf", title = "Forum-Regular.ttf", wide = true },
    MEDIEVAL  = { name = "Medieval",       face = "MedievalSharp",        body = "AlegreyaSans-Medium.ttf", title = "MedievalSharp-Regular.ttf" },
    ILLUMINED = { name = "Illuminated",    face = "Eagle Lake",           body = "AlegreyaSans-Medium.ttf", title = "EagleLake-Regular.ttf" },
    WARBAND   = { name = "Warband",        face = "New Rocker",           body = "AlegreyaSans-Medium.ttf", title = "NewRocker-Regular.ttf" },
    KNIGHTLY  = { name = "Knightly",       face = "Lancelot",             body = "AlegreyaSans-Medium.ttf", title = "Lancelot-Regular.ttf" },
    CLASSIC   = { name = "Game fonts",     face = "the game's own" },
}
ns.fontOrder = { "GLASS", "BARLOW", "TITILLIUM", "RAJDHANI", "CHAKRA", "PLAY", "CLEAN", "MONO", "SLAB",
                 "SAIRA", "TOMORROW", "BAI", "QUANTICO", "ELECTRO", "ALDRICH", "RUSSO", "AUDIO",
                 "ELEGANT", "SCHOLAR", "CAUDEX", "STORYBOOK", "FONDA", "UNCIAL", "PIRATA", "RUNIC", "POSTER",
                 "IMPERIAL", "CHRONICLE", "ROMAN", "MEDIEVAL", "ILLUMINED", "WARBAND", "KNIGHTLY", "CLASSIC" }

ns.themeOrder = { "SMOKE", "FROSTED", "MIDNIGHT", "AURORA", "BLUSH", "EMERALD", "OCEAN", "SUNSET", "CRIMSON", "ORCHID", "GILDED",
                  "GLACIER", "AMETHYST", "LAGOON", "HONEY", "STORM", "CORALREEF", "JADE", "NEBULA",
                  "SAPPHIRE", "RUBY", "TOPAZ", "PEARL", "OBSIDIAN", "MINTLEAF", "LAVENDER", "COPPER",
                  "DEEPSEA", "BLOSSOM", "LIME", "INDIGO", "STEELBLUE", "MOCHA", "VOID",
                  "GRAPHITE", "NOIR", "CONTRAST", "GCLASS",
                  "WARM", "DARK", "COLD", "FOREST", "BLOOD", "ARCANE", "SAND", "FORGE", "ROYAL", "ABYSS", "FEL", "BONE", "ONYX",
                  "DRAGON", "MOON", "VERDIGRIS", "AUTUMN", "TWILIGHT", "PLAGUE", "STEEL", "SUNWELL", "ROSEWOOD",
                  "FROSTFIRE", "DREAM", "SHADOW", "TITAN", "LIGHTFORGED", "NETHER", "TUNDRA", "JUNGLE",
                  "MOLTEN", "TIDAL", "WINE", "ASHEN", "OAK", "STORMCALLER", "STARLIGHT", "CLASS",
                  "C_POLARIS", "C_ECLIPSE", "C_BLUEHOUR", "C_ZENITH", "C_DESERT", "C_MOON", "C_BLOODMOON",
                  "C_AURORA", "C_WINTER", "C_COMET", "C_STARSTORM", "C_SOLSTICE", "C_VOID", "C_GROVE",
                  "C_TIDES", "C_HARVEST", "C_CLEAR", "C_DAWN", "C_DUSK", "C_STARLIGHT", "C_REDPLANET",
                  "C_GILDED", "C_SILVERMIST", "C_EVENINGSTAR", "C_HONEYMOON", "C_OPALINE", "C_DEEPSPACE", "C_FELSKY",
                  "C_ASHENSKY", "C_PEARLMOON", "C_SPIRIT", "C_ARCANE", "C_NEBULA", "C_SAPPHIRE", "C_EMERALD",
                  "C_CRYSTAL", "C_ASTROLABE", "CCLASS" }
ns.colors = {}

-- A theme derived from the player's class color: dark panels tinted with it, rims in a muted version of it.
local function ClassTheme()
    local r, g, b = 0.78, 0.61, 0.43
    local _, class = UnitClass("player")
    local cr, cg, cb = ns:ClassRGB(class)
    if cr then r, g, b = cr, cg, cb end
    return {
        bg = { r * 0.07 + 0.02, g * 0.07 + 0.02, b * 0.07 + 0.02 },
        border = { r * 0.55 + 0.05, g * 0.55 + 0.05, b * 0.55 + 0.05 },
        rim = { r * 0.02, g * 0.02, b * 0.02 },
        grain = { r * 0.6 + 0.15, g * 0.6 + 0.15, b * 0.6 + 0.15, 0.12 },
        light = { r * 0.5 + 0.5, g * 0.5 + 0.5, b * 0.5 + 0.5 },
        plate = { r * 0.14 + 0.04, g * 0.14 + 0.04, b * 0.14 + 0.04 },
        text = { 0.92, 0.90, 0.86 }, dim = { 0.78, 0.76, 0.72 }, faint = { 0.56, 0.54, 0.50 },
        btn = { r * 0.4 + 0.6, g * 0.4 + 0.6, b * 0.4 + 0.6 },
    }
end

-- The Celestial family's class theme: a night sky, its stars and lines in your class color.
local function CelestialClassTheme()
    local r, g, b = 0.6, 0.7, 1
    local _, class = UnitClass("player")
    local cr, cg, cb = ns:ClassRGB(class)
    if cr then r, g, b = cr, cg, cb end
    return { style = "CELESTIAL",
        bg = { r * 0.05 + 0.018, g * 0.05 + 0.022, b * 0.05 + 0.05 }, border = { r * 0.35 + 0.3, g * 0.35 + 0.3, b * 0.35 + 0.34 },
        rim = { 0, 0, 0.01 }, grain = { 1, 1, 1, 0 }, light = { r * 0.5 + 0.5, g * 0.5 + 0.5, b * 0.5 + 0.5 },
        plate = { r * 0.08 + 0.06, g * 0.08 + 0.065, b * 0.08 + 0.11 },
        text = { 0.92, 0.93, 0.96 }, dim = { 0.74, 0.76, 0.82 }, faint = { 0.52, 0.54, 0.6 }, btn = { r * 0.4 + 0.6, g * 0.4 + 0.6, b * 0.4 + 0.6 } }
end
-- Runic themes (11.8 to 11.10) and the Celestial theme that took each one's place in 11.11.
ns.RUNIC_TO_CELESTIAL = { R_GRANITE = "C_POLARIS", R_BASALT = "C_ECLIPSE", R_SLATE = "C_BLUEHOUR", R_MARBLE = "C_ZENITH", R_SANDSTONE = "C_DESERT", R_MOONSTONE = "C_MOON", R_BLOODSTONE = "C_BLOODMOON", R_JADE = "C_AURORA", R_FROST = "C_WINTER", R_EMBER = "C_COMET", R_STORM = "C_STARSTORM", R_SUN = "C_SOLSTICE", R_VOID = "C_VOID", R_THORN = "C_GROVE", R_TIDE = "C_TIDES", R_EARTH = "C_HARVEST", R_SKY = "C_CLEAR", R_DAWN = "C_DAWN", R_DUSK = "C_DUSK", R_STAR = "C_STARLIGHT", R_IRON = "C_REDPLANET", R_GOLD = "C_GILDED", R_SILVER = "C_SILVERMIST", R_COPPER = "C_EVENINGSTAR", R_AMBER = "C_HONEYMOON", R_OPAL = "C_OPALINE", R_OBSIDIAN = "C_DEEPSPACE", R_FEL = "C_FELSKY", R_ASH = "C_ASHENSKY", R_BONE = "C_PEARLMOON", R_SPIRIT = "C_SPIRIT", R_ARCANE = "C_ARCANE", R_RUBY = "C_NEBULA", R_SAPPHIRE = "C_SAPPHIRE", R_EMERALD = "C_EMERALD", R_CRYSTAL = "C_CRYSTAL", R_ANCIENT = "C_ASTROLABE", RCLASS = "CCLASS" }
function ns.CelestialFor(key) return ns.RUNIC_TO_CELESTIAL[key] or key end

-- Color for a role ("bg", "border", "text", ...). With alpha it returns four values, so use it as the LAST argument.
local PANES = { bg = true, bg2 = true, bg3 = true, bg4 = true }
function ns:T(role, alpha)
    local c = ns.colors[role] or ns.colors.bg or ns.themes.SMOKE.bg
    if alpha ~= nil then
        if PANES[role] then alpha = alpha * (ns.panelAlpha or 1)           -- HUD panel fills thin out on glass themes
        elseif role == "window" then alpha = alpha * (ns.windowAlpha or 1) end
        return c[1], c[2], c[3], alpha
    end
    return c[1], c[2], c[3]
end

-- Themes you made yourself (Look tab). Each is three colors - panel, rim, accent - from which a full
-- glass theme is worked out. They live in the profile as ns.db.customThemes[name] and are registered
-- as ordinary themes under the key "U:" .. name, so everything else treats them like the built-in ones.
local function Triple(c, fallback)
    if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then
        return { math.max(0, math.min(1, c[1])), math.max(0, math.min(1, c[2])), math.max(0, math.min(1, c[3])) }
    end
    return { fallback[1], fallback[2], fallback[3] }
end
function ns:CleanThemeDef(def)
    if type(def) ~= "table" then def = {} end
    return { panel = Triple(def.panel, { 0.07, 0.08, 0.10 }), rim = Triple(def.rim, { 0.34, 0.38, 0.44 }), accent = Triple(def.accent, { 0.36, 0.72, 1.00 }),
             style = (def.style == "FANTASY" or def.style == "CELESTIAL") and def.style or (def.style == "RUNIC") and "CELESTIAL" or "GLASS" }    -- (Runic is gone: its own themes became Celestial)
end
local function ThemeFromDef(name, def)
    local p, r = def.panel, def.rim
    local pale = (p[1] * 0.30 + p[2] * 0.59 + p[3] * 0.11) > 0.55            -- a pale panel needs dark lettering
    local function lift(c, f, add) return { math.min(1, c[1] * f + add), math.min(1, c[2] * f + add), math.min(1, c[3] * f + add) } end
    local t = { name = (name == "*") and "Custom (unsaved)" or name, accent = "CUSTOM", custom = def, customName = name,
                style = def.style, bg = { p[1], p[2], p[3] }, border = { r[1], r[2], r[3] } }
    if def.style == "FANTASY" then
        -- ornamented panels: a dark outer rim, a grain washed with the rim color, warm highlights,
        -- worked out the way the built-in fantasy themes relate their colors to each other
        local glow = lift(r, 1.9, 0.10)
        local grain = lift(r, 1.45, 0)
        t.rim = lift(p, 0.4, 0)
        t.grain = { grain[1], grain[2], grain[3], 0.13 }
        t.light, t.btn = glow, (pale and { 0.14, 0.11, 0.08 } or glow)
        t.plate = pale and lift(p, 0.82, 0) or lift(p, 2.25, 0.01)
        t.text  = pale and { 0.12, 0.10, 0.08 } or { 0.90, 0.87, 0.80 }
        t.dim   = pale and { 0.28, 0.25, 0.21 } or { 0.78, 0.74, 0.66 }
        t.faint = pale and { 0.44, 0.41, 0.36 } or { 0.58, 0.55, 0.48 }
    else
        t.rim, t.grain, t.light = { 0, 0, 0 }, { 1, 1, 1, 0 }, { 1, 1, 1 }
        t.plate = pale and lift(p, 0.82, 0) or lift(p, 2.6, 0.02)
        t.text  = pale and { 0.08, 0.09, 0.11 } or { 0.93, 0.95, 0.98 }
        t.dim   = pale and { 0.25, 0.27, 0.31 } or { 0.72, 0.76, 0.82 }
        t.faint = pale and { 0.42, 0.44, 0.48 } or { 0.50, 0.54, 0.60 }
        t.btn   = pale and { 0.10, 0.11, 0.13 } or { 0.94, 0.97, 1.00 }
        if def.style == "CELESTIAL" then t.rim, t.light = { 0, 0, 0.01 }, lift(def.accent, 0.75, 0.25) end    -- (starlight in the accent)
    end
    return t
end
ns.ThemeFromDef = function(name, def) return ThemeFromDef(name, def) end      -- (for themes other add-ons register: API.lua)
function ns:RegisterCustomThemes()
    local mine = ns.db and ns.db.customThemes
    if type(mine) ~= "table" then return end
    for i = #ns.themeOrder, 1, -1 do                       -- drop registrations whose theme is gone
        local key = ns.themeOrder[i]
        local t = ns.themes[key]
        if t and t.custom and mine[t.customName] == nil then
            ns.themes[key] = nil
            table.remove(ns.themeOrder, i)
        end
    end
    local names = {}
    for name in pairs(mine) do if type(name) == "string" then names[#names + 1] = name end end
    table.sort(names)
    for _, name in ipairs(names) do
        mine[name] = ns:CleanThemeDef(mine[name])
        local key = "U:" .. name
        if not ns.themes[key] then ns.themeOrder[#ns.themeOrder + 1] = key end
        ns.themes[key] = ThemeFromDef(name, mine[name])
    end
end
function ns:SaveCustomTheme(name, def)
    if type(name) ~= "string" or name == "" then return nil end
    ns.db.customThemes[name] = ns:CleanThemeDef(def)
    ns:RegisterCustomThemes()
    return "U:" .. name
end
function ns:DeleteCustomTheme(name)
    ns.db.customThemes[name] = nil
    ns:RegisterCustomThemes()
end

-- A theme's name in your language. how: nil, the whole name ("Glass: Smoke (dark gray)"); "plain",
-- without the description in brackets; "short", without the family as well (where a heading says it).
-- Your own themes keep the names you gave them.
function ns:ThemeName(key, how)
    local t = ns.themes[key]
    if not t then return tostring(key) end
    if t.custom then return tostring(t.name) end
    local name = ns:Tr(t.name)
    if how == "plain" or how == "short" then
        name = name:gsub("%s*%(.-%)%s*$", ""):gsub("%s*（.-）%s*$", "")
    end
    if how == "short" then
        local rest = name:match("^[^:]-:%s*(.+)$") or name:match("^.-：%s*(.+)$")
        if rest and rest ~= "" then name = rest end
    end
    return name
end

-- A theme's colors without putting it on (11.9: the previews on the Look tab). Returns
-- { style, bg, border, text, plate, btn, accent }, or nil for a theme that does not exist.
function ns:ThemeColors(key)
    local t = ns.themes[key]
    if not t then return nil end
    if key == "CCLASS" then
        local c = CelestialClassTheme()
        t = { style = "CELESTIAL", bg = c.bg, border = c.border, text = c.text, plate = c.plate, btn = c.btn }
    elseif key == "CLASS" or key == "GCLASS" then
        local c = ClassTheme()
        t = { style = (key == "GCLASS") and "GLASS" or "FANTASY",
              bg = c.bg, border = c.border, text = c.text, plate = c.plate, btn = c.btn }
        if key == "GCLASS" then                            -- (as BuildPalette makes it, so the preview matches)
            local b = c.border
            t.bg = { b[1] * 0.16 + 0.03, b[2] * 0.16 + 0.03, b[3] * 0.16 + 0.03 }
            t.border = { b[1] * 0.7 + 0.14, b[2] * 0.7 + 0.14, b[3] * 0.7 + 0.14 }
            t.plate = { b[1] * 0.4 + 0.08, b[2] * 0.4 + 0.08, b[3] * 0.4 + 0.08 }
            t.text = { 0.95, 0.95, 0.96 }
        end
    end
    local accent
    if t.custom then accent = t.custom.accent
    elseif t.accent == "CLASS" then
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        accent = cc and { cc.r, cc.g, cc.b } or { 1, 0.82, 0.4 }
    else accent = ns.accents[t.accent or "AZURE"] or ns.accents.AZURE end
    return { style = t.style or "FANTASY", bg = t.bg, border = t.border, text = t.text or { 0.95, 0.95, 0.95 },
             plate = t.plate or t.bg, btn = t.btn or t.text or { 1, 1, 1 }, accent = accent }
end

function ns:BuildPalette()
    ns:RegisterCustomThemes()
    local key = ns.CelestialFor(ns.db.theme)
    local t = ns.themes[key] or ns.themes.SMOKE
    if t.custom and ns.db.accent == "CUSTOM" then ns.db.customAccent = { t.custom.accent[1], t.custom.accent[2], t.custom.accent[3] } end
    if key == "CLASS" then
        t = ClassTheme()
    elseif key == "CCLASS" then                   -- a night sky lit with your class color
        t = CelestialClassTheme()
    elseif key == "GCLASS" then                   -- glass tinted with your class color
        local c = ClassTheme()
        local base = c.border                      -- a muted version of the class color
        t = { style = "GLASS",
              bg = { base[1] * 0.16 + 0.03, base[2] * 0.16 + 0.03, base[3] * 0.16 + 0.03 },
              border = { base[1] * 0.7 + 0.14, base[2] * 0.7 + 0.14, base[3] * 0.7 + 0.14 }, rim = { 0, 0, 0 },
              grain = { 1, 1, 1, 0 }, light = c.light, plate = { base[1] * 0.4 + 0.08, base[2] * 0.4 + 0.08, base[3] * 0.4 + 0.08 },
              text = { 0.95, 0.95, 0.96 }, dim = { 0.76, 0.76, 0.80 }, faint = { 0.54, 0.54, 0.58 }, btn = c.btn }
    end
    ns.style = t.style or "FANTASY"
    -- glass panes are see-through; how much is the player's choice (Layout tab)
    ns.panelAlpha = (ns.style == "GLASS") and math.max(0.3, math.min(1, (tonumber(ns.db.panelAlpha) or 78) / 100)) or 1
    -- full windows (options, bags, quest log, and the game's own windows) carry a lot of text, so they
    -- get their own, much higher opacity instead of the see-through HUD setting
    ns.windowAlpha = (ns.style == "GLASS") and math.max(0.5, math.min(1, (tonumber(ns.db.windowAlpha) or 95) / 100)) or 1
    local function scaled(c, f) return { math.min(1, c[1] * f), math.min(1, c[2] * f), math.min(1, c[3] * f) } end
    local th = ns.theme
    th.bg[1], th.bg[2], th.bg[3] = t.bg[1], t.bg[2], t.bg[3]
    th.border[1], th.border[2], th.border[3] = t.border[1], t.border[2], t.border[3]
    ns.celestialEdge = (ns.style == "CELESTIAL") and { t.border[1], t.border[2], t.border[3] } or nil
    th.rim[1], th.rim[2], th.rim[3] = t.rim[1], t.rim[2], t.rim[3]
    th.grain, th.light, th.btn = t.grain, t.light, t.btn
    ns.colors = {
        bg = t.bg, bg2 = scaled(t.bg, 0.80), bg3 = scaled(t.bg, 0.67), bg4 = scaled(t.bg, 0.53),
        window = t.bg, inset = scaled(t.bg, 0.55),
        field = scaled(t.bg, 1.45), trough = scaled(t.bg, 1.30),
        plate = t.plate, plate2 = scaled(t.plate, 0.82), border = t.border,
        text = t.text, dim = t.dim, faint = t.faint,
    }
end

-- Font and bar texture: ours (in Media) or the game's
ns.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
-- The game reads a font file from disk only while a loading screen is up; a face first asked for
-- later (a lettering style picked on the Look tab) draws nothing new until a /reload. So every
-- bundled face is put to use once now, while the add-on loads, on strings nobody sees; after that
-- any lettering can be switched to on the spot.
function ns:PreloadFonts()
    if ns.fontsPreloaded or not CreateFrame then return end
    ns.fontsPreloaded = true
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -200, 200)      -- (off the screen, but shown, so the text is drawn)
    holder:SetAlpha(0)
    holder.strings = {}
    local seen = {}
    for _, style in pairs(ns.fontStyles) do
        for _, file in ipairs({ style.body or false, style.title or false }) do
            if file and not seen[file] then
                seen[file] = true
                local fs = holder:CreateFontString(nil, "OVERLAY")
                if pcall(fs.SetFont, fs, ns.MEDIA .. file, 12, "") then
                    fs:SetPoint("TOPLEFT")
                    fs:SetText("Aa")
                    holder.strings[#holder.strings + 1] = fs
                end
            end
        end
    end
    ns.fontHolder = holder                                          -- (kept: an unseen "Aa" per face costs nothing)
end

function ns:ApplyTheme()
    ns:PreloadFonts()
    ns.fontScale = math.max(0.7, math.min(1.5, (tonumber(ns.db.fontScale) or 100) / 100))
    if not ns.localeLoaded then
        ns.localeLoaded = true
        ns:LoadLocale()
        ns:TranslateBindings()
        ns:After(20, function() ns:TrimLocales() end)       -- (after the setup, if it is going to open, has been built)
    end
    if ns.roundOK == nil then                           -- can this client slice textures (needed for rounded corners)?
        local probe = ns.hidden:CreateTexture()
        ns.roundOK = (probe.SetTextureSliceMargins ~= nil)
    end
    ns:BuildPalette()
    ns:ApplyAccent()
    local gameLocale = GetLocale and GetLocale() or "enUS"
    local chosen = ns.Language and ns:Language() or "auto"
    local locale = (chosen ~= "auto" and chosen ~= "enUS") and chosen or gameLocale      -- the language the text will be in
    local cjk = locale == "koKR" or locale == "zhCN" or locale == "zhTW"   -- our font has no CJK glyphs
    local function GameFont(object, fallback)        -- the game's own face, correct for the player's language
        local o = _G[object]
        if type(o) == "table" and o.GetFont then
            local ok, path = pcall(o.GetFont, o)
            if ok and type(path) == "string" and path ~= "" then return path end
        end
        return fallback
    end
    -- Lettering. A style names a body face and a heading face from the Media folder; a face left out
    -- means "the game's own". Bundled faces are only used where they have the letters the language
    -- needs (ns.fontStyles says which); otherwise the game's fonts stand in, so text is never missing.
    local style = ns.fontStyles[ns.db.fontStyle or "GLASS"] or ns.fontStyles.GLASS
    local latin = { enUS = 1, enGB = 1, deDE = 1, frFR = 1, esES = 1, esMX = 1, itIT = 1, ptBR = 1, ptPT = 1 }
    local usable = (style.wide and not cjk) or latin[locale]
    local gameBody = GameFont("GameFontNormal", "Fonts\\FRIZQT__.TTF")
    local gameTitle = GameFont("QuestTitleFont", "Fonts\\MORPHEUS.TTF")
    if locale ~= gameLocale then                         -- a language chosen by hand that the game's own face may lack
        if locale == "koKR" then gameBody, gameTitle = "Fonts\\2002.TTF", "Fonts\\2002B.TTF"
        elseif locale == "ruRU" then gameBody, gameTitle = "Fonts\\FRIZQT___CYR.TTF", "Fonts\\MORPHEUS_CYR.TTF"
        elseif locale == "zhCN" then gameBody, gameTitle = "Fonts\\ARKai_T.ttf", "Fonts\\ARKai_T.ttf" end
    end
    local ownBody = usable and style.body
    ns.FONT = ownBody and (ns.MEDIA .. style.body) or gameBody
    if usable and style.title then
        ns.TITLEFONT = ns.MEDIA .. style.title
    elseif ownBody then
        ns.TITLEFONT = ns.FONT                              -- one face for everything
    else
        ns.TITLEFONT = gameTitle
    end
    ns.FONTFLAGS = (ownBody and style.flags) or ""
    ns.BAR = ns.db.barTexture and (ns.MEDIA .. ((ns.style == "GLASS") and "bar_glass.tga" or "bar.tga")) or ns.FLAT
    if ns.ApplySharedMedia then pcall(ns.ApplySharedMedia, ns) end        -- (a font or bar texture chosen from another add-on)
end

-- Change theme, accent or lettering on the spot. Returns false when a reload is still needed
-- (switching between the glass and fantasy families rebuilds panels differently).
function ns:Retheme()
    local before = ns.style
    ns:ApplyTheme()
    ns:Repaint()
    if before ~= ns.style then
        ns:Print("Switching between glass, fantasy and celestial themes finishes after a |cffffff00/reload|r.")
        return false
    end
    return true
end

-- Role layouts: where the main frames sit for each role. { anchor point, x, y }
ns.layouts = {
    DAMAGE = { ufPlayer = { "CENTER", -250, -180 }, ufTarget = { "CENTER", 250, -180 }, roleHUD = { "CENTER", 0, -170 },
               raid = { "TOPLEFT", 20, -160 },
               ufParty1 = { "LEFT", 30, 140 }, ufParty2 = { "LEFT", 30, 84 }, ufParty3 = { "LEFT", 30, 28 }, ufParty4 = { "LEFT", 30, -28 } },
    TANK   = { ufPlayer = { "CENTER", -270, -205 }, ufTarget = { "CENTER", 270, -205 }, roleHUD = { "CENTER", 0, -135 },
               raid = { "TOPLEFT", 20, -160 },
               ufParty1 = { "LEFT", 30, 140 }, ufParty2 = { "LEFT", 30, 84 }, ufParty3 = { "LEFT", 30, 28 }, ufParty4 = { "LEFT", 30, -28 } },
    HEALER = { ufPlayer = { "CENTER", -340, -250 }, ufTarget = { "CENTER", 340, -250 }, roleHUD = { "CENTER", 0, -330 },
               raid = { "CENTER", 0, -190 },           -- raid frames just under the middle of the screen
               ufParty1 = { "CENTER", -440, 60 }, ufParty2 = { "CENTER", -440, 4 }, ufParty3 = { "CENTER", -440, -52 }, ufParty4 = { "CENTER", -440, -108 } },
}

function ns:ApplyRoleLayout(role)
    local layout = ns.layouts[role or ns.db.role]
    if not layout then
        ns:Print("Choose a role first (|cffffff00/fgui setup|r).")
        return
    end
    if ns.AfterFight and ns:AfterFight("Role layout", function() ns:ApplyRoleLayout(role) end) then return end   -- (frames cannot move in a fight)
    local combat = InCombatLockdown()
    do                                                       -- one undo step for the whole layout
        local keys = {}
        for key in pairs(layout) do keys[#keys + 1] = key end
        table.sort(keys)
        if ns.PushUndo and #keys > 0 then ns:PushUndo(keys, nil, "the role layout") end
    end
    for key, p in pairs(layout) do
        ns.db.pos[key] = { p[1], p[1], p[2], p[3] }
        if not combat then
            for _, m in ipairs(ns.movables or {}) do
                if m.key == key then
                    m.frame:ClearAllPoints()
                    m.frame:SetPoint(p[1], UIParent, p[1], p[2], p[3])
                end
            end
        end
    end
    ns:Print(combat and "Layout saved; it applies after combat with a /reload." or "Layout applied. Use |cffffff00/fgui move|r to fine-tune.")
end

function ns:ApplyInfoBarBg()
    if ns.SetInfoBarBackground then ns:SetInfoBarBackground(ns.db.infobarBg) end
end

function ns:ApplyChatBackground()
    if ns.SetChatBackground then ns:SetChatBackground(ns.db.chatBg) end
end

function ns:AccentHex()
    local a = ns.theme.accent
    return format("|cff%02x%02x%02x", floor(a[1] * 255 + 0.5), floor(a[2] * 255 + 0.5), floor(a[3] * 255 + 0.5))
end

-- Secret values: in combat this client hides health, threat etc. from addons.
-- A secret value may be handed to SetValue/SetText but never compared or used in math.
function ns:IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) == true
end
-- Is this value plainly equal to that one? In combat the game hands add-ons values they may hold but
-- not look at, and comparing one of those is an error - even after a pcall that fetched it. So anything
-- the game returns about a unit, a spell or an item is compared through here: a hidden value is
-- simply "not equal".
function ns.Is(v, want)
    if issecretvalue ~= nil and (issecretvalue(v) == true or issecretvalue(want) == true) then return false end
    return v == want
end
-- Is this plainly a "yes"? A hidden yes/no cannot even be tested ("if afk then" is an error when the
-- game is hiding afk), so an answer from the game about a unit is tested through here: hidden is "no".
function ns.Yes(v)
    if issecretvalue ~= nil and issecretvalue(v) == true then return false end
    return v and true or false
end

-- Shared helpers ------------------------------------------------------------
ns.FLAT = "Interface\\Buttons\\WHITE8X8"
ns.BACKDROP = {
    bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
ns.template = BackdropTemplateMixin and "BackdropTemplate" or nil

-- Invisible parking spot for things we never want to see again
ns.hidden = CreateFrame("Frame")
ns.hidden:Hide()

-- ns:Print("Sold junk for %s.", coins) - the message is looked up in the translation table first, then
-- any extra values are filled in. ns:PrintRaw is for text that should stay exactly as it is (errors).
function ns:PrintRaw(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd166Fantasy Glass UI|r: " .. tostring(msg))
end
function ns:Print(msg, ...)
    if type(msg) == "string" and ns.Tr then msg = ns:Tr(msg) end
    if select("#", ...) > 0 then
        local ok, text = pcall(format, msg, ...)
        if ok then msg = text end
    end
    ns:PrintRaw(msg)
end

-- Settings live in named profiles; each character remembers which profile it uses.
--   FantasyGlassUIDB = { profiles = { Default = {...} }, chars = { ["Name - Realm"] = "Default" } }
function ns:CharKey()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    return (type(name) == "string" and name or "Unknown") .. " - " .. (type(realm) == "string" and realm or "")
end

function ns:FillDefaults(profile)
    -- Settings from older versions: carry over the ones that still mean something, drop the rest.
    if profile.microMode == nil and profile.fadeMicro == false then profile.microMode = "SHOW" end
    if profile.design ~= 4 then                    -- version 4 of the look is the glass design: move onto it once
        profile.design = 4
        profile.theme, profile.accent, profile.fontStyle = "SMOKE", "AZURE", "GLASS"
    end
    for _, stale in ipairs({ "fadeMicro", "ownFont", "modernFont", "hideGryphons", "squareMinimap", "hudPos", "bagGrid",
                             "classColorHealth", "darkFrames", "castBar", "buffs", "bags" }) do
        profile[stale] = nil
    end
    if type(profile.classColors) ~= "table" then profile.classColors = {} end
    if type(profile.clickCast) ~= "table" then profile.clickCast = {} end
    if type(profile.bagAssign) ~= "table" then profile.bagAssign = {} end
    if type(profile.cooldownSpells) ~= "table" then profile.cooldownSpells = {} end
    if type(profile.placeThemes) ~= "table" then profile.placeThemes = {} end      -- theme by place: { city = , dungeon = , raid = , world = }
    if type(profile.layouts) ~= "table" then profile.layouts = {} end
    if type(profile.customThemes) ~= "table" then profile.customThemes = {} end
    -- Runic is gone (11.11): a Runic theme becomes the Celestial one made from it, here and by place
    if type(profile.theme) == "string" then profile.theme = ns.CelestialFor(profile.theme) end
    for where, key in pairs(profile.placeThemes) do if type(key) == "string" then profile.placeThemes[where] = ns.CelestialFor(key) end end
    for _, def in pairs(profile.customThemes) do if type(def) == "table" and def.style == "RUNIC" then def.style = "CELESTIAL" end end
    if type(profile.alertBuffs) ~= "table" then profile.alertBuffs = {} end
    for k, v in pairs(ns.defaults) do
        if profile[k] == nil then
            if type(v) == "table" then                       -- (a table of its own: never the defaults' table, shared by every profile)
                local copy = {}
                for kk, vv in pairs(v) do copy[kk] = vv end
                v = copy
            end
            profile[k] = v
        end
    end
    if type(profile.pos) ~= "table" then profile.pos = {} end
    if type(profile.scale) ~= "table" then profile.scale = {} end
    return profile
end

function ns:InitDB()
    if ns.db then return ns.db end
    -- Settings saved under this add-on's former name (StylishUI). They are loaded only if the saved
    -- file was carried over (README, "Coming from StylishUI"); if so they become ours, once.
    if type(FantasyGlassUIDB) ~= "table" and type(StylishUIDB) == "table" then
        FantasyGlassUIDB = StylishUIDB
        ns.migrated = true
    end
    StylishUIDB = nil
    if type(FantasyGlassUIDB) ~= "table" then FantasyGlassUIDB = {} end
    local root = FantasyGlassUIDB
    ns.freshInstall = type(root.profiles) ~= "table" and next(root) == nil      -- nothing saved yet: a first run
    if type(root.profiles) ~= "table" then
        -- first run of this version: the old flat settings become the "Default" profile
        local old = {}
        for k, v in pairs(root) do old[k] = v end
        for k in pairs(old) do root[k] = nil end
        root.profiles = { Default = old }
    end
    if type(root.chars) ~= "table" then root.chars = {} end
    if type(root.profiles.Default) ~= "table" then root.profiles.Default = {} end

    local key = ns:CharKey()
    local name = root.chars[key]
    if type(name) ~= "string" or type(root.profiles[name]) ~= "table" then
        local own = (name == nil) and ns.NewCharacterProfile and ns:NewCharacterProfile(root, key)     -- a new character: a copy of your main's (AltSetup.lua)
        name = own or "Default"
        root.chars[key] = name
    end
    if ns.NoteCharacter then ns:NoteCharacter(root, key) end
    if ns.TakeBackups then pcall(ns.TakeBackups, ns, root) end       -- (Safety.lua: before anything of this session changes them)
    ns.root, ns.profile = root, name
    ns.db = ns:FillDefaults(root.profiles[name])
    -- Does this client refuse add-ons any buff/debuff data during combat? Remembered once found out.
    if root.aurasLocked == nil then
        local ok, _, _, _, toc = pcall(GetBuildInfo)
        if ok and toc == 16001 then root.aurasLocked = true end        -- WoW Forever: confirmed in game
    end
    ns.aurasLocked = root.aurasLocked and true or false
    return ns.db
end

function ns:After(sec, fn)
    if C_Timer and C_Timer.After then C_Timer.After(sec, fn) return end
    local f, t = CreateFrame("Frame"), 0
    f:SetScript("OnUpdate", function(self, e)
        t = t + e
        if t >= sec then self:SetScript("OnUpdate", nil); fn() end
    end)
end

-- Class colors. A player's own choice (Class Colors tab) wins over the game's color. The game's
-- RAID_CLASS_COLORS table is only ever read, never changed, so nothing else is affected.
ns.classOrder = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
                  "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER" }

function ns:DefaultClassRGB(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
end

function ns:ClassRGB(class)
    local custom = class and ns.db and ns.db.classColors and ns.db.classColors[class]
    if type(custom) == "table" and type(custom[1]) == "number" and type(custom[2]) == "number" and type(custom[3]) == "number" then
        return custom[1], custom[2], custom[3]
    end
    return ns:DefaultClassRGB(class)
end

-- A unit's class color, or nothing. The game sometimes hands add-ons a unit it will not let them ask
-- about (a "hidden" unit, as a tooltip can carry): asking would raise an error, so such a unit simply
-- has no color as far as we are concerned.
function ns:ClassColor(unit)
    if ns:IsSecret(unit) or not unit then return end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or not ns.Yes(isPlayer) then return end
    local okC, _, class = pcall(UnitClass, unit)
    if okC and type(class) == "string" and not ns:IsSecret(class) then return ns:ClassRGB(class) end
end

-- Color-blind aid: one letter for a debuff's type, when the game lets us read it.
function ns:DispelLetter(kind)
    if ns:IsSecret(kind) or type(kind) ~= "string" then return "" end
    return ({ Magic = "M", Curse = "C", Poison = "P", Disease = "D" })[kind] or ""
end

-- Reading buffs and debuffs ---------------------------------------------------------------------------
-- Some clients refuse add-ons any aura data while in combat ("Auras cannot be accessed when secret
-- while tainted"). ns.GetAura never raises that error: it returns nil instead, stops asking until
-- combat ends, and remembers that this client behaves that way so the add-on can adapt at next login.
ns.auraLock = false
local auraLockAt = 0
local auraBack = {}
function ns:OnAurasBack(fn) auraBack[#auraBack + 1] = fn end

function ns.GetAura(unit, index, filter)
    local read = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if not read then return nil end
    if ns.auraLock then
        if InCombatLockdown() or GetTime() - auraLockAt < 2 then return nil end
        ns.auraLock = false
    end
    local ok, aura = pcall(read, unit, index, filter)
    if ok then return aura end
    ns.auraLock, auraLockAt = true, GetTime()
    if type(FantasyGlassUIDB) == "table" and not FantasyGlassUIDB.aurasLocked then
        FantasyGlassUIDB.aurasLocked = true
        ns:Print("This game client hides buffs and debuffs from add-ons during combat. After this fight, type |cffffff00/reload|r and Fantasy Glass UI will use the game's own buff frames (restyled) instead of its own.")
    end
    return nil
end

do  -- combat over: aura data is readable again, let the frames catch up
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function()
        if not ns.auraLock then return end
        ns.auraLock = false
        for _, fn in ipairs(auraBack) do pcall(fn) end
    end)
end

-- What's new: shown once after an update (never on a first install, where the setup opens instead).
ns.whatsNew = {
    { "11.14.0", { "Starcut reaches the rest of the screen: action buttons and bag slots are cut like gems, their cooldowns to match, and the minimap can be a diamond (Features tab).",
                   "Whose upgrade: in a group, a boss drop shows whose upgrade it is, and by how much, among players with the add-on - before anyone rolls.",
                   "A run log: /fgui runs keeps your dungeon and raid times, kills, wipes, deaths and loot, with a best time for each place.",
                   "Farming by zone: /fgui farm zones lists your best farming spots by gold an hour, and whether your latest time there was up or down.",
                   "Goals: gold on all your characters, a level and a mount join the goals panel; an item counts on every character and says where it drops.",
                   "Nameplates: the threat color is on the plate's edge too, so a tank sees which mob is slipping." } },
    { "11.13.0", { "Starcut reaches every bar: your cast bar, the class resource (its dots become small diamonds), raid frames, nameplates, timers, experience and totems.",
                   "Screenshot mode: /fgui showcase fills every frame with a picture-worthy sample (a boss with a breath on its way, a party of four) and clears the screen of everything else.",
                   "A loot browser: /fgui drops lists what each boss dropped while you were there, raid by raid, with the upgrades for you first.",
                   "A threat meter of its own: in a group, who has how much threat on your target, and a warning color as you near the top.",
                   "Farming sessions: /fgui farm shows the time and what you make an hour, in gold and in loot, and each session counts in your weekly recap.",
                   "Gear sets: the set you wear is named over your player frame, /fgui set <name> puts one on, and the first five sets can have keys." } },
    { "11.12.0", { "A new look for your unit frames, Starcut: bars cut to points that glow in their own color, a diamond portrait with stars on its points, and the name above the bars.",
                   "Prefer the box? Look tab, Frame style: Classic brings it back at once.",
                   "Open windows do far less work: the character window, vendor, mailbox, auction house, collections and every scrolling list are looked over more cheaply while they are open." } },
    { "11.11.0", { "A login briefing: a few seconds after you log in, one small window says what is waiting: crafts ready, mail on your other characters, lockouts reset, rested experience, jobs left. /fgui briefing shows it again.",
                   "Skill-ups on the profession window: the recipes that still give skill points, best first, with what each needs.",
                   "Your weekly recap: what each character did last week, gold, time, levels, raids and best loot (/fgui recap).",
                   "Celestial themes take the place of Runic: 38 night skies with twinkling stars, constellations and shooting stars. A Runic theme you use becomes the Celestial one made from it.",
                   "The minimap is a star chart on Celestial themes, with the sun or moon by the game's clock; and twelve more accent colors, 31 in all.",
                   "An Interface size slider beside Text size on the Layout tab, and /fgui uisize and /fgui textsize.",
                   "Polish: tooltips on the option buttons and size sliders, the new tools in the Tools menu and as key bindings, and long list lines shown in full under the mouse.",
                   "The whole add-on polished, file by file: everything it shows is translated, every message is a full sentence, and commands say what they did or why not." } },
    { "11.10.0", { "Player tooltips are yours to choose: hide the title, realm, guild, level line, faction, PvP or health bar, and add their role, whether they are your friend or guild mate, and their health in numbers. Features tab, under Player tooltips.",
                   "Player tooltips can also be put away during fights; hold Shift to see one anyway.",
                   "Every tooltip now wears your theme: glass, leather and gold, or carved stone with rune-studs. The health bar under it takes the player's class color.",
                   "The spellbook's section headings are tidied, and the help (/fgui help) is sorted into proper groups.",
                   "After each vendor visit, one line in chat says what you sold, bought and repaired, and what it came to.",
                   "In the bag window, right-clicking at a vendor sells the item, gear too; at the bank it stores it." } },
    { "11.9.1", { "Polish: the setup's themes show their pictures too, and Runic themes no longer carry their family's name there; the home key works less while you cast.", "/fgui help opens a window you can search, and the Tools menu is sorted into groups.", "The death recap names the kind of damage; boss notes can be deleted from the list; group practice shows a banner.", "Asked for during a fight, Equip best, Sort bags and talent builds happen when it ends; a mistyped command suggests the right one.", "Every message is now translated; /fgui reset asks first and keeps a backup; five new key bindings." } },
    { "11.9.0", { "Runic themes now carry runes everywhere: carved class emblems on stone, a band of runes round the minimap, and carved edges on the action buttons.",
                  "The Look tab shows a small picture of each theme; point at one for a larger card.",
                  "/fgui check new tries each feature added since 11.6 and reports what works." } },
    { "11.8.1", { "Fixed: the language list showed only one language's name (11.8.0)." } },
    { "11.8.0", { "A third family of themes: Runic. 38 themes of carved stone with an engraved edge and runes glowing in the accent color (Look tab, or the setup).",
                  "Fixed: Korean and Chinese showed as empty boxes in the language list." } },
    { "11.7.0", { "Am I ready? (/fgui ready me), boss notes (/fgui bossnote), a death recap (/fgui death), and a home key for the best way home.",
                  "Your settings are backed up before each update and once a day (/fgui backup), and each profile keeps a list of your changes to undo (/fgui history).",
                  "Whole-UI packs to share (/fgui pack), Tank, Healer and Damage templates on the Profiles tab, and an auction house helper.",
                  "The setup has \"Coming from another UI?\", /fgui perf fight measures a whole fight, and /fgui perf load shows what each feature costs." } },
    { "11.6.0", { "Group practice (/fgui testgroup): made-up group mates, to see group cooldowns, the interrupt rotation and buff coverage on your own.",
                  "Arena enemy frames with their trinket, interrupt and dispel cooldowns; upgrade arrows on loot rolls, quest rewards and the game's bags; Equip best (/fgui equipbest).",
                  "A new character gets its own copy of your main's setup, fitted to its class (/fgui main chooses your main).",
                  "The execute line only shows on enemies, and the translations load only for players who use another language than English." } },
    { "11.5.0", { "Interrupt rotation, a class resource you design, professions on all your characters (/fgui crafts), a key binding sheet (/fgui keys) and buff coverage on raid frames.",
                  "A layout for each screen size, quiet mode (/fgui quiet), Simplified Chinese, and a tidier Features tab with 11 sections." } },
    { "11.4.5", { "Fixed: cutscenes were covered by a dark window frame." } },
    { "11.4.4", { "Fixed: the Fantasy Glass action bar buttons did nothing when clicked or pressed in 11.4.3." } },
    { "11.4.3", { "Fixed: the game's stance bar refused in fights (\"Interface action failed\") while the Fantasy Glass action bars are on. Their buttons now keep themselves up to date." } },
    { "11.4.2", { "With the Fantasy Glass action bars on, the stance bar is one of ours too, and the game's own is no longer refused in fights (\"Interface action failed\")." } },
    { "11.4.1", { "Fixed: pointing at a Fantasy Glass action bar button during a fight counted as a failed action (\"Interface action failed\")." } },
    { "11.4.0", { "Sort bags by your bag sections (/fgui sort), reputations and currencies on all your characters (/fgui reps), and mount and pet buttons.",
                  "Send a talent build to another player (/fgui talents send), and goals of your own and achievements on the goals panel (/fgui goal add)." } },
    { "11.3.1", { "Fixed: more \"Interface action failed\" messages in fights, from the game's stance bar, action bars and buff rows that you have moved." } },
    { "11.3.0", { "Group cooldowns: who in your group has a battle res, an interrupt or a big cooldown ready (Features tab).",
                  "Send your layout, profile or theme to another player: /fgui send <name>, or the Profiles tab.",
                  "A totem bar for Shamans, and an aura designer on the Bars and frames tab (Auras)." } },
    { "11.2.8", { "Finishing the setup always reloads the interface, so everything you chose is in place at once." } },
    { "11.2.7", { "Fixed: \"Interface action failed because of an AddOn\" during fights and reloads, from the game's bars and buttons the add-on hides." } },
    { "11.2.6", { "New switch: hide the game's raid manager, the panel on the left edge of the screen in a group (Features tab, Combat and groups)." } },
    { "11.2.5", { "Health, mana and XP as numbers are switches on the Features tab (Frames) now.",
                  "Fixed: the buttons along the top of the Layout tab overlapping." } },
    { "11.2.4", { "Bag rules and Mail rules are sections of the Features tab: ready-made bag sections to switch on, and a switch for each material to mail, with who it goes to." } },
    { "11.2.2", { "Your rules on the Tools tab: bag rules, mail rules, checklist jobs and talent builds, made and changed without typing commands.",
                  "The Profiles tab is one page again." } },
    { "11.2.3", { "Fixed: abilities on the Fantasy Glass action bars could not be used, by click or by key.",
                  "Player tooltips are back to how they were before 11.1." } },
    { "11.2.0", { "\"Tools\" on the Menu button: every tool window in one small panel, without opening the options.",
                  "Pull and break timers for the group (/fgui pull, /fgui break), a battleground helper, a raid composition panel (/fgui comp) and holidays on your checklist (/fgui events).",
                  "Bag rules (/fgui bagrules), mail rules (/fgui mailrules), talent builds (/fgui talents), a preview of shared strings, pixel-perfect scale and a round minimap." } },
    { "11.1.0", { "Choose which of the add-on's own action bars you use: \"Use this bar\" on the Bars and frames tab.",
                  "A nameplate designer and a raid frame designer, on the Bars and frames tab.",
                  "A checklist of your own daily and weekly jobs for each character, cleared at the resets (/fgui checklist)." } },
    { "11.0.0", { "Fantasy Glass action bars: eight bars of our own, each with its own buttons, rows, size and spacing, set without the game's Edit Mode (Features tab, off until you choose them).",
                  "A frame designer for every unit frame, and the Bars tab is now Bars and frames.",
                  "Layout gallery (/fgui gallery), custom alerts and spoken alerts (Combat tab), a live self-test (/fgui selftest), and an API for other add-ons." } },
    { "10.9.0", { "A short tour of the interface (/fgui tour), and What's this? mode: point at any panel to see which feature made it (/fgui whatsthis, or set a key).",
                  "New: where to level next (/fgui level), profession cooldowns on all your characters (/fgui profcd), and a performance view (/fgui perf).",
                  "Four more languages: Italian, Portuguese, Russian and Korean." } },
    { "10.8.0", { "The Look tab is shorter: accent, lettering, the game menu and bars, your own theme and the new Theme by place are one section, Accent and style.",
                  "New: a session card (/fgui session), quest rewards on the tracker, a ready-check report, rares remembered on the world map (/fgui rares), a crafting queue (/fgui queue) and a goals panel (/fgui goal).",
                  "New, off until you choose them (Features tab): a cooldown timeline, combat text in your lettering and a login splash." } },
    { "10.7.0", { "Fourteen more game settings as switches (Features tab, Game settings): auto loot, loot window at the mouse, auto self-cast, nameplates from further away, stacking nameplates, a camera that stays where you turn it, clear weather, a lower frame rate when tabbed out, no tutorial pop-ups, profanity filter off, mute the music or ambient sounds, no gray screen when dead, and less screen glow. Switching one off puts the game's setting back." } },
    { "10.6.2", { "The white streak of light that passed over the class emblems is gone." } },
    { "10.6.1", { "The class sigils inside the medallions are animated again, each with its own loop: swords meeting, a bow drawn and loosed, a lightning bolt crackling, and the rest.",
                  "The Hunter's arrow has real feathers now, and the Warlock's flame is back as it was." } },
    { "10.6.0", { "New class emblems, made for Fantasy Glass UI: each class's sigil on a glass disc, with a glow that breathes, a ring in your accent color that turns, motes of light circling it and a shine passing over. They are moved by the game itself, so they no longer stop on one frame.",
                  "Class colors are now part of the Look tab, together with the portrait choice, in one section: Portraits and class colors. /fgui colors still opens it." } },
    { "10.5.1", { "The Layout and Tools tabs are back to how they were: everything on one page, without a list of sections. The other tabs keep the list down the left." } },
    { "10.5.0", { "Every tab of /fgui now works like the Features tab: its sections are listed down the left, and the one you choose is shown by itself. The window is a little wider to make room.",
                  "Click casting has moved into the Combat tab, as its own section. /fgui clickcast still takes you straight there.",
                  "Fixed: the animated class emblems on portraits stopping after a while. /fgui check has a line that says whether they are running." } },
    { "10.4.3", { "Fixed, this time for good: buttons in the Add-ons panel that looked grayed out. Most minimap buttons lock the layer they are drawn on, so they stayed behind the panel; they are now unlocked, brought forward and locked again." } },
    { "10.4.2", { "/fgui buttons lists the buttons gathered into the Add-ons panel and how the game is drawing each, for tracking down one that looks grayed out." } },
    { "10.4.1", { "Fixed: some of the buttons in the Add-ons panel under the minimap looked grayed out. They were sitting behind the panel's dark backing; every gathered button is now in front of it and solid." } },
    { "10.4.0", { "A Bars tab in /fgui: each action bar has its own size, opacity and rule for when it shows (always, when pointed at, in or out of combat, with a target, never), its own key text and macro names, and its rows, buttons, button size and spacing.",
                  "A Guide tab: quest guides are coming soon." } },
    { "10.2.0", { "The options window has a new, lighter look: the Features tab shows one section at a time, with the sections listed down the left and a card that says what the switch under the mouse does. Tabs are plain names with a line under the open one, and every tick box is now a switch.",
                  "Fixed: a piece unticked in the info bar's list (gold, frame rate, the clock...) stayed on the bar." } },
    { "10.1.0", { "A Tools tab in /fgui: a button for every window, your lists (buff reminders, hidden buffs, keywords, restock) with Add and remove, fonts and textures from other add-ons, and suggestions for your class.",
                  "Ask the guide: type a question at the top of the Tools tab, or /fgui ask how do I move the bars, and it points you to the switch or command." } },
    { "10.0.0", { "Fifty-eight additions. On the Features tab: a missing buff reminder, a travel bar, a boss timer, a flight timer, fishing mode, a whisper window, keyword alerts and more - most are off until chosen.",
                  "New commands, all listed by /fgui help: /fgui way 45 62, /fgui note, /fgui recent, /fgui rolls, /fgui gold, /fgui loot, /fgui restock, /fgui notepad, /fgui todo, /fgui calc. Bind a key to your best healing potion, your food or a mount in the game's key bindings.",
                  "Thirty more themes - fifteen glass and fifteen fantasy - and fifteen more lettering styles, on the Look tab (/fgui look)." } },
    { "9.8.0", { "Quest marks on nameplates, a ready check alert, and a pulse when a tracked ability comes off cooldown.",
                 "/fgui alts lists your characters with their gold; /fgui timer 5m tea starts a countdown. A consumables bar that fills itself from your bags is on the Features tab, off until chosen." } },
    { "9.7.0", { "Damage meter: point at a row for that player's abilities, and right-click the heading through earlier fights too.",
                 "Vendors mark what you already know. New, off until chosen: combat start and end alerts, bind-on-pickup loot confirmed when alone, role checks accepted, and a movement speed piece for the info bar." } },
    { "9.6.0", { "The damage meter has more views: damage taken, absorbs, interrupts, dispels, deaths and plain totals. Click its heading, or roll the mouse wheel over it. Your own row is marked, and Shift-right-click resets it.",
                 "The raid tools have ground markers. New, each off until chosen (Features tab): the meter opening itself in combat, gear sets that follow your talent set, invites by whisper, declining duels." } },
    { "9.5.6", { "An action bar you have moved now stays where you put it during a fight, instead of jumping to the game's default place until the fight ends.",
                 "Target markers in the raid tools work again (the game had started blocking them), and the panel opens in combat.",
                 "The chat typing bar is back under the chat box, so the chat tabs can be clicked while you type. (\"Chat: typing bar above the chat\" puts it back on top.)",
                 "The crafting bar in the profession window is now in our style, and shows the profession's own icon (so does the cast bar while you craft)." } },
    { "9.4.2", { "The damage meter is now a drawer that comes out of the side of the chat box: bars reading damage per second, and under them who has threat on your target. The small tab on its edge (or /fgui meter) tucks it away.",
                 "To have it as a window of its own again, switch off \"Damage meter: drawer on the chat box\" on the Features tab." } },
    { "9.3.0", { "Chat history now covers every chat tab (it was the main tab only) and has its own switch.",
                 "New on the Features tab, each off until chosen: Greed on green items, and a \"Game settings\" section (camera distance, error voice, sound when tabbed out, screenshot quality)." } },
    { "9.2.0", { "A button for each of your saved gear sets, under the character window: one click puts a set on.",
                 "Off until chosen, on the Features tab under \"Done for you\": stand up or dismount when an action needs it, accept resurrections, accept summons." } },
    { "9.1.1", { "Fixed: the quest tracker and the bag window tried to resize or reopen themselves during combat, which the game refuses and counts against the add-on (\"Interface actions failed\" in the add-on list).",
                 "/fgui blocked lists anything the game has refused, and where it came from. The self-check shows it too." } },
    { "9.1.0", { "The options, the setup and the self-check now load only when you open one of them, so the add-on uses less memory the rest of the time.",
                 "The add-on is now two folders: FantasyGlassUI and FantasyGlassUI_Options. Keep both.",
                 "/fgui memory shows how much memory is in use." } },
    { "9.0.0", { "A release about finish. The Features tab is organized into sections under headings.",
                 "Leftover English text (tooltips, the XP bar's tooltip, the quest log) follows your language.",
                 "/fgui help lists every command; /fgui check no longer shows older game functions as missing." } },
    { "8.12.0", { "Inspecting someone shows the item level of each piece and their average.",
                  "Player tooltips show guild rank; a switch adds item and spell IDs.",
                  "A chime when a quest objective is finished, and a coin on junk in the bag window." } },
    { "8.11.0", { "Drag the game's own windows; each opens where you left it.",
                  "Character window: how worn each piece is, and your average item level.",
                  "New switches on the Features tab: class-colored names in chat, a Learn all button at trainers, Alt-click to buy a stack, a rare spawn alert, 12-hour and server-time clocks.",
                  "Off until chosen: follow the reputation you earn, repair from guild funds, pick the only choice in a conversation." } },
    { "8.10.0", { "A small frame for what your focus is targeting.",
                  "Your name is picked out in chat when someone else says it, with an optional sound." } },
    { "8.9.0", { "Choose what the info bar shows: right-click it, or \"Info bar pieces\" on the Layout tab.",
                 "Keep and sell lists for selling junk: Alt-click an item in the bags, or /fgui sell and /fgui keep.",
                 "Your other characters are listed beside the mail window: click one to address a letter to it.",
                 "A combat timer for every role (Features tab, off until chosen)." } },
    { "8.8.0", { "Undo in move mode: the Undo button on the bar at the top, Ctrl+Z, or /fgui undo.",
                 "Dragged panels snap to the edges of other panels.",
                 "New switches on the Features tab: key text and macro names on action buttons, a ring round the mouse pointer, and a quieter red error line." } },
    { "8.7.0", { "The group finder is restyled to match the other windows.",
                 "Each panel can show always, only in combat, only out of combat, or only with a target: right-click it in move mode.",
                 "A search box at the bottom of the options finds a setting on any tab.",
                 "You are told when someone in your guild or group has a newer version." } },
    { "8.6.0", { "Helpers, each off until you choose it (Features tab): accept invitations from friends and guildmates, faster looting, type DELETE for you, skip cutscenes you have seen.",
                 "Coordinates on the world map, a \"BoE\" tag on unbound gear in your bags, and nameplate size sliders on the Layout tab.",
                 "Safe mode: /fgui safe reloads with every feature off, for when something has gone wrong." } },
    { "8.5.0", { "Seventeen more themes: eight glass (Glacier, Amethyst, Lagoon, Honey, Storm, Coral, Jade, Nebula) and nine fantasy (Dragonfire, Moonlit, Verdigris, Autumn, Twilight, Plague, Steel, Sunwell, Rosewood).",
                 "Ten more lettering styles: Clean, Tech, Terminal, Scholar, Slab, Manuscript, Celtic, Gothic, Calligraphy, Poster.",
                 "The Look tab scrolls with the mouse wheel, so everything has its own button." } },
    { "8.4.9", { "The XP bar shows how far through the level you are: a percentage, or the amounts with \"XP as numbers, not %\" on the Combat tab." } },
    { "8.4.7", { "Mana and other resources can be shown as amounts: \"Mana & resources as numbers, not %\" on the Combat tab.",
                 "Fixed: resource text was blank on clients that hide the amounts all the time.",
                 "Fixed: the Layout tab ran into the buttons at the bottom, and the Language button covered the profile name." } },
    { "8.4.5", { "The resource percentage now shows on every unit frame with a power bar, and on nameplates." } },
    { "8.4.4", { "Your frame and your target's show mana, rage, energy and other resources as a percentage on the power bar." } },
    { "8.4.3", { "Nameplates show health on their bar, and the role HUD follows the \"Health as numbers\" choice too." } },
    { "8.4.2", { "Unit frames can show health as an amount instead of a percentage: \"Health as numbers, not %\" on the Combat tab." } },
    { "8.4.1", { "Choose the language yourself: on the setup's first step, with the Language button at the top of the options, or with /fgui language." } },
    { "8.4.0", { "A minimap button opens these options (left-click) or starts moving panels (right-click).",
                 "Boss frames, and our own breath and fatigue bar.",
                 "New, and off until you choose it: use items from the bag window in combat (Features tab).",
                 "German, French and Spanish for the main labels." } },
    { "8.3.0", { "Chat bubbles redrawn in the theme's own style: glass panes or fantasy panels, each with a proper tail and a name tab.",
                 "Fixed chat bubbles showing as a flat block of the rim color on fantasy themes." } },
}
local function VersionNumber(v)
    local a, b, c = tostring(v or ""):match("^(%d+)%.(%d+)%.?(%d*)")
    return (tonumber(a) or 0) * 10000 + (tonumber(b) or 0) * 100 + (tonumber(c) or 0)
end
-- Returns the text that would be shown, or nil when there is nothing new for this player.
function ns:WhatsNew(force)
    local root = FantasyGlassUIDB
    if type(root) ~= "table" then return nil end
    local seen = root.seenVersion
    root.seenVersion = ns.version
    if not force and (ns.freshInstall or seen == ns.version) then return nil end
    local since = VersionNumber(seen)
    local out, shown, more = {}, 0, 0
    for i, entry in ipairs(ns.whatsNew) do
        if (force and i <= 4) or (not force and VersionNumber(entry[1]) > since) then     -- (asked for: the last four releases)
            if seen == nil and not force and i > 1 then break end        -- unknown previous version: just the latest
            if shown >= 5 then                                -- (after a long break, five releases and a count of the rest)
                more = more + 1
            else
                shown = shown + 1
                out[#out + 1] = ns:Tr("Version") .. " " .. entry[1]
                for _, line in ipairs(entry[2]) do out[#out + 1] = "  - " .. ns:Tr(line) end
                out[#out + 1] = ""
            end
        end
    end
    if #out == 0 then return nil end
    if more > 0 then out[#out + 1] = format(ns:Tr("And %d earlier updates since yours: the full list is in the changelog on CurseForge and GitHub."), more); out[#out + 1] = "" end
    out[#out + 1] = ns:Tr("Everything is in /fgui. This note appears once per update; /fgui new shows it again.")
    return table.concat(out, "\n")
end

-- Is this piece of gear a higher item level than what is worn in its slot?
-- A plain item-level comparison: it knows nothing about stats, so treat the arrow as "worth a look".
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
function ns:IsUpgrade(link, level)
    if type(link) ~= "string" or type(level) ~= "number" then return false end
    local GetInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not GetInstant then return false end
    local ok, _, _, _, equipLoc = pcall(GetInstant, link)
    local slots = ok and EQUIP_SLOTS[equipLoc]
    if not slots then return false end
    local needLevel = select(5, ns:GetItemInfo(link))
    local myLevel = UnitLevel("player")
    if type(needLevel) == "number" and type(myLevel) == "number" and needLevel > myLevel then return false end     -- can't wear it yet
    local IsUsable = (C_Item and C_Item.IsUsableItem) or IsUsableItem
    if IsUsable then
        local okU, usable = pcall(IsUsable, link)
        if okU and ns.Is(usable, false) then return false end                -- wrong armor or weapon type for your class
    end
    local lowest
    for _, slot in ipairs(slots) do
        local worn = GetInventoryItemLink and GetInventoryItemLink("player", slot)
        local wornLevel = 0
        if type(worn) == "string" and C_Item and C_Item.GetDetailedItemLevelInfo then
            wornLevel = C_Item.GetDetailedItemLevelInfo(worn) or 0
        end
        if not lowest or wornLevel < lowest then lowest = wornLevel end
    end
    if lowest == nil then return false end
    return level > lowest, level - lowest                    -- (and by how much)
end
ns.EQUIP_SLOTS = EQUIP_SLOTS

-- Abilities on your action bars that have a real cooldown, in bar order: names for the cooldown tracker.
function ns:CooldownCandidates(max)
    local out, seen = {}, {}
    if not GetActionInfo then return out end
    for slot = 1, 120 do
        local ok, kind, id = pcall(GetActionInfo, slot)
        if ok and kind == "spell" and type(id) == "number" then
            local base
            if GetSpellBaseCooldown then
                local okB, ms = pcall(GetSpellBaseCooldown, id)
                if okB and type(ms) == "number" then base = ms end
            end
            if base == nil or base >= 6000 then                        -- unknown, or longer than the global cooldown
                local name
                if C_Spell and C_Spell.GetSpellName then name = C_Spell.GetSpellName(id)
                elseif C_Spell and C_Spell.GetSpellInfo then local info = C_Spell.GetSpellInfo(id); name = info and info.name
                elseif GetSpellInfo then name = GetSpellInfo(id) end
                if type(name) == "string" and name ~= "" and not seen[name] then
                    seen[name] = true
                    out[#out + 1] = name
                    if #out >= (max or 9) then break end
                end
            end
        end
    end
    return out
end

-- Other add-ons that do the same job as one of our features. When one is loaded, that feature stands
-- aside instead of fighting over the same part of the screen. { add-on folder name, our feature keys }
ns.steppedAside = {}
local CONFLICTS = {
    { "ElvUI",               { "unitFrames", "ufParty", "raidFrames", "actionBars", "nameplates", "bagWindow", "bankWindow", "minimap", "chat", "chatSkin", "tooltip", "auraBars", "playerCast", "xpBar", "infobar" } },
    { "Tukui",               { "unitFrames", "ufParty", "raidFrames", "actionBars", "nameplates", "bagWindow", "bankWindow", "minimap", "chat", "chatSkin", "tooltip", "auraBars", "playerCast", "xpBar" } },
    { "Bartender4",          { "actionBars" } }, { "Dominos", { "actionBars" } },
    { "ShadowedUnitFrames",  { "unitFrames", "ufParty", "raidFrames" } }, { "PitBull4", { "unitFrames", "ufParty", "raidFrames" } },
    { "ZPerl",               { "unitFrames", "ufParty", "raidFrames" } }, { "Grid2", { "raidFrames" } }, { "VuhDo", { "raidFrames" } }, { "Cell", { "raidFrames" } },
    { "Plater",              { "nameplates" } }, { "Kui_Nameplates", { "nameplates" } }, { "TidyPlates_ThreatPlates", { "nameplates" } }, { "NeatPlates", { "nameplates" } },
    { "Baganator",           { "bagWindow", "bankWindow" } }, { "Bagnon", { "bagWindow", "bankWindow" } }, { "AdiBags", { "bagWindow", "bankWindow" } },
    { "ArkInventory",        { "bagWindow", "bankWindow" } }, { "OneBag3", { "bagWindow" } },
    { "Prat-3.0",            { "chat", "chatExtras" } }, { "Chatter", { "chat", "chatExtras" } },
    { "SexyMap",             { "minimap" } }, { "BasicMinimap", { "minimap" } },
    { "TipTac",              { "tooltip" } },
    { "Quartz",              { "playerCast" } },
    { "!KalielsTracker",     { "questTracker" } },
    { "XLoot",               { "lootRoll" } },
    { "Postal",              { "mailTools" } },
    { "MinimapButtonButton", { "buttonBag" } }, { "MBB", { "buttonBag" } },
    { "OmniCC",              { "cooldownText" } },
}
function ns:ConflictFor(key)
    if ns.db and ns.db.stepAside == false then return nil end
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if not isLoaded then return nil end
    for _, c in ipairs(CONFLICTS) do
        for _, k in ipairs(c[2]) do
            if k == key then
                local ok, loaded = pcall(isLoaded, c[1])
                if ok and loaded then return c[1] end
            end
        end
    end
end

-- Meaning carried by color: good, caution, bad. With the color-blind option these change from
-- green / yellow / red to blue / yellow / orange, which stay apart for the common kinds of color
-- blindness. Everything that signals with color asks here.
function ns:Signal(kind)
    local safe = ns.db and ns.db.colorblind
    if kind == "good" then if safe then return 0.30, 0.62, 1.00 end return 0.30, 0.90, 0.40 end
    if kind == "bad"  then if safe then return 1.00, 0.55, 0.10 end return 1.00, 0.25, 0.25 end
    return 1.00, 0.85, 0.20
end
function ns:SignalHex(kind)
    local r, g, b = ns:Signal(kind)
    return format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end
-- Is movement allowed? (fades, pulses, gliding bars, the AFK camera). Off with "Reduce motion".
function ns:Motion() return not (ns.db and ns.db.reduceMotion) end

-- Clean screen: the whole interface fades away for a few seconds, for a screenshot, then comes back
-- by itself. (The game's own Alt+Z hides the interface until you press it again; this one returns
-- on its own and can be put on a key.)
local cleanUntil = 0
function ns:CleanScreen(seconds)
    seconds = math.max(1, math.min(30, tonumber(seconds) or 5))
    if cleanUntil > 0 then                                   -- pressed again: come back now
        cleanUntil = 0
        pcall(UIParent.SetAlpha, UIParent, 1)
        return false
    end
    cleanUntil = GetTime() + seconds
    pcall(UIParent.SetAlpha, UIParent, 0)
    return true
end
do
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function() if cleanUntil > 0 then cleanUntil = 0; pcall(UIParent.SetAlpha, UIParent, 1) end end)
    f:SetScript("OnUpdate", function()
        if cleanUntil > 0 and GetTime() >= cleanUntil then cleanUntil = 0; pcall(UIParent.SetAlpha, UIParent, 1) end
    end)
end
do                                                          -- the demo's notifications, and ending it when a fight starts
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function() if ns.demo and ns.ToggleDemo then ns:ToggleDemo(true) end end)
    local t = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        if not ns.demo then t = 3 return end                -- (so the first sample appears soon after starting)
        t = t + (elapsed or 0)
        if t >= 3.5 then t = 0; if ns.DemoTick then pcall(ns.DemoTick, ns) end end
    end)
end

-- Combat focus: in a fight, the panels you are not fighting with (quest tracker, info bar and the
-- strip of other add-ons' data under it) dim right down, and come back when the fight ends.
do
    local NAMES = { "FantasyGlassUITracker", "FantasyGlassUIInfoBar", "FantasyGlassUIBrokers" }
    local level = 1
    function ns:CombatFocusTick(step)
        local on = ns.db and ns.db.combatFocus and InCombatLockdown() and not ns.moving
        local target = on and 0.12 or 1
        if level == target then return end
        if ns:Motion() then
            level = (target > level) and math.min(target, level + step) or math.max(target, level - step)
        else
            level = target
        end
        for _, name in ipairs(NAMES) do
            local f = _G[name]
            if type(f) == "table" and f.SetAlpha then pcall(f.SetAlpha, f, level) end
        end
        return level
    end
    local f, t = CreateFrame("Frame"), 0
    f:SetScript("OnUpdate", function(_, elapsed)
        t = t + (elapsed or 0)
        if t >= 0.05 then t = 0; if ns.db then ns:CombatFocusTick(0.1) end end
    end)
end

-- Key bindings (Bindings.xml): names shown in the game's Key Bindings window, and what each does.
BINDING_HEADER_FANTASYGLASSUI = "Fantasy Glass UI"
BINDING_NAME_FANTASYGLASSUI_OPTIONS = "Open options"
BINDING_NAME_FANTASYGLASSUI_MOVE = "Move panels"
BINDING_NAME_FANTASYGLASSUI_KEYBIND = "Keybind mode"
BINDING_NAME_FANTASYGLASSUI_CLEAN = "Clean screen (5 seconds)"
BINDING_NAME_FANTASYGLASSUI_METER = "Damage meter drawer"
BINDING_NAME_FANTASYGLASSUI_ALTS = "Your characters"
BINDING_NAME_FANTASYGLASSUI_MOUNT = "Mount (random favorite)"
BINDING_NAME_FANTASYGLASSUI_NOTEPAD = "Notepad"
BINDING_NAME_FANTASYGLASSUI_WHISPERS = "Whisper window"
BINDING_NAME_FANTASYGLASSUI_TODO = "To-do list"
BINDING_NAME_FANTASYGLASSUI_SORT = "Sort bags"
BINDING_NAME_FANTASYGLASSUI_KEYS = "Key binding sheet (hold)"
BINDING_NAME_FANTASYGLASSUI_QUIET = "Quiet mode"
BINDING_NAME_FANTASYGLASSUI_WHATSTHIS = "What's this? (point at a panel)"
BINDING_NAME_FANTASYGLASSUI_TOOLS = "Tools menu"
BINDING_NAME_FANTASYGLASSUI_EQUIPBEST = "Equip best (put on the upgrades in your bags)"
BINDING_NAME_FANTASYGLASSUI_DEATH = "Death recap (your last death)"
BINDING_NAME_FANTASYGLASSUI_BOSSNOTE = "Boss note (for your target)"
BINDING_NAME_FANTASYGLASSUI_HELP = "Every command (/fgui help)"
BINDING_NAME_FANTASYGLASSUI_BRIEFING = "Login briefing (what is waiting)"
BINDING_NAME_FANTASYGLASSUI_RECAP = "Weekly recap"
BINDING_NAME_FANTASYGLASSUI_SKILLUPS = "Skill-ups (profession window open)"
for i = 1, 5 do _G["BINDING_NAME_FANTASYGLASSUI_GEARSET" .. i] = format("Gear set %d (A to Z)", i) end
for i = 1, 4 do _G["BINDING_NAME_CLICK FantasyGlassUIConsumable" .. i .. ":LeftButton"] = format("Consumables bar: button %d", i) end
-- The names above in the player's language, once the translations are loaded (the game's Key
-- Bindings window reads them only when it opens, so this is in time).
function ns:TranslateBindings()
    for _, k in ipairs({ "OPTIONS", "MOVE", "KEYBIND", "CLEAN", "METER", "ALTS", "MOUNT", "PET", "NOTEPAD", "WHISPERS", "TODO", "SORT",
                         "KEYS", "QUIET", "WHATSTHIS", "TOOLS", "EQUIPBEST", "DEATH", "BOSSNOTE", "HELP", "BRIEFING", "RECAP", "SKILLUPS" }) do
        local g = "BINDING_NAME_FANTASYGLASSUI_" .. k
        if type(_G[g]) == "string" then _G[g] = ns:Tr(_G[g]) end
    end
    for i = 1, 4 do _G["BINDING_NAME_CLICK FantasyGlassUIConsumable" .. i .. ":LeftButton"] = format(ns:Tr("Consumables bar: button %d"), i) end
    for i = 1, 5 do _G["BINDING_NAME_FANTASYGLASSUI_GEARSET" .. i] = format(ns:Tr("Gear set %d (A to Z)"), i) end
end
function FantasyGlassUI_Binding(which, keystate)
    if not ns.db then return end
    if which == "KEYS" then if ns.ShowKeySheet then ns:ShowKeySheet(keystate ~= "up") end; return end
    local setNumber = tonumber(tostring(which):match("^GEARSET(%d)$"))
    if setNumber then if ns.WearSetNumber then ns:WearSetNumber(setNumber) end; return end
    if which == "OPTIONS" then ns:ToggleConfig()
    elseif which == "MOVE" then ns:ToggleMove()
    elseif which == "KEYBIND" then ns:ToggleKeybindMode()
    elseif which == "CLEAN" then ns:CleanScreen(5)
    elseif which == "METER" then if ns.ToggleMeter then ns:ToggleMeter() end
    elseif which == "ALTS" then if ns.ShowCharacters then ns:ShowCharacters() end
    elseif which == "MOUNT" then if ns.MountUp then ns:MountUp() end
    elseif which == "PET" then if ns.SummonPet then ns:SummonPet() end
    elseif which == "SORT" then if ns.SortBags then ns:SortBags() end
    elseif which == "QUIET" then if ns.ToggleQuiet then ns:ToggleQuiet() end
    elseif which == "NOTEPAD" then if ns.ShowNotepad then ns:ShowNotepad() end
    elseif which == "WHISPERS" then if ns.ShowWhispers then ns:ShowWhispers() end
    elseif which == "TODO" then if ns.TodoCommand then ns:TodoCommand("") end
    elseif which == "WHATSTHIS" then if ns.WhatsThis then ns:WhatsThis() end
    elseif which == "TOOLS" then if ns.ToggleToolsMenu then ns:ToggleToolsMenu() end
    elseif which == "EQUIPBEST" then if ns.EquipBest then ns:EquipBest() end
    elseif which == "DEATH" then if ns.ShowDeathRecap then ns:ShowDeathRecap() end
    elseif which == "BOSSNOTE" then if ns.BossNoteCommand then ns:BossNoteCommand(ns.Yes(UnitExists("target")) and "" or "list") end
    elseif which == "HELP" then if ns.ShowHelp then ns:ShowHelp("") end
    elseif which == "BRIEFING" then if ns.ShowBriefing then ns:ShowBriefing() end
    elseif which == "RECAP" then if ns.ShowRecap then ns:ShowRecap("") end
    elseif which == "SKILLUPS" then if ns.ShowSkillUps then ns:ShowSkillUps() end end
end

function ns:LowestDurability()
    local lowest = 100
    for slot = 1, 18 do
        local cur, max = GetInventoryItemDurability(slot)
        if cur and max and max > 0 then lowest = math.min(lowest, cur / max * 100) end
    end
    return lowest
end

-- Money as coins. Uses the client's formatter when it has one, our own text otherwise.
function ns:Coins(copper)
    copper = tonumber(copper) or 0
    local fn = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    if fn then
        local ok, s = pcall(fn, copper)
        if ok and type(s) == "string" and s ~= "" then return s end
    end
    local g, s, c = floor(copper / 10000), floor((copper % 10000) / 100), copper % 100
    local out = {}
    if g > 0 then out[#out + 1] = "|cffffd700" .. g .. "g|r" end
    if s > 0 or g > 0 then out[#out + 1] = "|cffc7c7cf" .. s .. "s|r" end
    out[#out + 1] = "|cffeda55f" .. c .. "c|r"
    return table.concat(out, " ")
end

function ns:GetItemInfo(link)
    if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(link) end
    return GetItemInfo(link)
end

function ns:NewModule(key, fn)
    table.insert(self.modules, { key = key, fn = fn })
end

-- Bag helpers (modern C_Container API with old-global fallback) ---------------
function ns:NumSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag)
    end
    return GetContainerNumSlots(bag)
end

function ns:BagItem(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bag, slot)
        if info then return info.hyperlink, info.stackCount, info.quality end
        return nil
    end
    return GetContainerItemLink(bag, slot), select(2, GetContainerItemInfo(bag, slot))
end

function ns:UseBagItem(bag, slot)
    if C_Container and C_Container.UseContainerItem then
        C_Container.UseContainerItem(bag, slot)
    else
        UseContainerItem(bag, slot)
    end
end

-- Bootstrapping ---------------------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        ns:InitDB()
        -- The same add-on under its former name cannot run alongside this one: two full interfaces
        -- would fight over every frame. If the old folder is still there, this one stands down.
        do
            local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
            local ok, old = pcall(function() return isLoaded and isLoaded("StylishUI") end)
            if ok and old == true then
                ns.oldCopy = true
                ns:PrintRaw("|cffff4444The old StylishUI folder is still installed.|r Fantasy Glass UI is the same add-on under its new name, and the two cannot run together. Delete Interface/AddOns/StylishUI (or untick it in the AddOns list), then /reload.")
                return
            end
        end
        if ns.migrated then ns:Print("Your settings from StylishUI have been carried over.") end
        ns:ApplyTheme()
        -- Safe mode: nothing is started. The options, the setup and every /fgui command still work, so
        -- whatever was wrong can be switched off, and then safe mode left.
        if ns.root and ns.root.safeMode then
            ns.safeMode = true
            ns:PrintRaw("|cffffd100Safe mode:|r every feature is off. |cffffff00/fgui|r opens the options; |cffffff00/fgui safe|r leaves safe mode.")
            ns:After(1, function() if ns.ShowSafeBanner then ns:ShowSafeBanner() end end)
            return
        end
        local count = 0
        local stepped = {}
        for _, m in ipairs(ns.modules) do
            local other = ns.db[m.key] and ns:ConflictFor(m.key)
            if other then                                     -- another add-on does this job: leave it to that one
                if not ns.steppedAside[m.key] then stepped[#stepped + 1] = other end
                ns.steppedAside[m.key] = other
            elseif ns.db[m.key] then
                ns.startingModule = m.key                    -- (panels made now belong to this feature: see "What's this?")
                local t0 = debugprofilestop and debugprofilestop()
                local kb0 = collectgarbage and collectgarbage("count")
                local ok, err = pcall(m.fn)
                if ns.moduleCost and t0 and kb0 then                         -- what it cost to start (Safety.lua)
                    ns.moduleCost[m.key] = { ms = debugprofilestop() - t0, kb = collectgarbage("count") - kb0 }
                end
                ns.startingModule = nil
                if ok then
                    ns.loaded[m.key] = true
                    count = count + 1
                else
                    ns.errors[#ns.errors + 1] = "module " .. m.key .. ": " .. tostring(err)
                    ns:PrintRaw("|cffff4444module '" .. m.key .. "' failed:|r " .. tostring(err))
                end
            end
        end
        if ns.db.loginLine ~= false then ns:Print("v%s loaded (%d modules). Type |cffffff00/fgui|r for options.", ns.version, count) end
        if #stepped > 0 then
            local seen, names = {}, {}
            for _, name in ipairs(stepped) do if not seen[name] then seen[name] = true; names[#names + 1] = name end end
            ns:Print("Leaving some jobs to your other add-ons (%s). |cffffff00/fgui check|r lists which; |cffffff00/fgui conflicts off|r makes Fantasy Glass UI do them anyway.", table.concat(names, ", "))
        end
        -- swing timers switched off again: give Blizzard's own swing bars back
        if not ns.db.swingTimer and ns.db.swingCVarWasOn then
            ns.db.swingCVarWasOn = nil
            pcall(SetCVar, "showSwingTimer", "1")
        end
        if ns.root and ns.root.resumeSetup then              -- a language was just picked in the setup: carry on there
            ns.root.resumeSetup = nil
            ns:After(1.5, function() if ns.ShowSetup then ns:ShowSetup() end end)
        elseif ns.root and ns.root.setupJustFinished then    -- the setup's Finish reloaded the interface: say so, then the tour
            ns.root.setupJustFinished = nil
            if FantasyGlassUIDB then FantasyGlassUIDB.seenVersion = ns.version end
            ns:After(2, function()
                ns:Print("Setup finished. Everything is in |cffffff00/fgui|r whenever you want to change it.")
                if ns.StartTour and not ns.db.tourDone and not InCombatLockdown() then ns:StartTour() end
            end)
        elseif not ns.db.role then
            ns:After(2, function() if ns.ShowSetup then ns:ShowSetup() end end)
            if FantasyGlassUIDB then FantasyGlassUIDB.seenVersion = ns.version end          -- a first run gets the setup, not release notes
        else
            ns:After(4, function()
                local text = ns:WhatsNew()
                if text and ns.ShowTextWindow and not InCombatLockdown() then ns:ShowTextWindow("What's new in Fantasy Glass UI", text) end
            end)
        end
    end
end)

-- Slash commands --------------------------------------------------------------
-- /fgui help. A line with one entry is a heading.
-- Every command in one window (11.9.1), not a hundred lines of chat: grouped under headings,
-- /fgui help <word> keeps the ones that mention it, and clicking one puts it in the chat box.
function ns.HelpMatches(lines, word)
    word = ns.Trim(word or ""):lower()
    local out, heading = {}, nil
    for _, line in ipairs(lines) do
        if not line[2] then
            heading = line
        elseif word == "" or line[1]:lower():find(word, 1, true) or ns:Tr(line[2]):lower():find(word, 1, true) or line[2]:lower():find(word, 1, true) then
            if heading then out[#out + 1] = heading; heading = nil end
            out[#out + 1] = line
        end
    end
    return out
end
function ns:ShowHelp(word)
    local found = ns.HelpMatches(ns.helpLines, word)
    local rows = {}
    for _, line in ipairs(found) do
        if line[2] then
            local cmd = line[1]:gsub("%s*[%[<].*$", "")             -- (what to type: the part before any <...> or [...])
            rows[#rows + 1] = {
                left = "|cffffd100" .. line[1] .. "|r  " .. ns:Tr(line[2]),
                click = function()
                    local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
                    if type(open) == "function" then pcall(open, cmd .. " ") end
                end,
            }
        else
            rows[#rows + 1] = { left = ns:AccentHex() .. ns:Tr(line[1]) .. "|r" }
        end
    end
    if #rows == 0 then rows[1] = { left = format(ns:Tr("No command mentions \"%s\"."), ns.Trim(word)) } end
    local what = ns.Trim(word or "") == "" and ns:Tr("commands") or format(ns:Tr("commands about \"%s\""), ns.Trim(word))
    ns:ShowList("Help", format("Fantasy Glass UI %s: %s", ns.version, what), rows,
        "Click one to put it in the chat box. /fgui help bags shows only the ones about bags.", 620, 440)
    return #found
end

-- What the help says of a command: "/fgui death" → its line. With `arg`, a line naming it is preferred.
local HELP_ALIAS = { checknew = { "check", "new" } }            -- (a word the menu uses for a two-word command)
function ns.HelpAbout(word, arg)
    if HELP_ALIAS[word] and not arg then word, arg = HELP_ALIAS[word][1], HELP_ALIAS[word][2] end
    local plain
    for _, line in ipairs(ns.helpLines or {}) do
        local cmd = line[2] and line[1]:lower()
        if cmd then
            local w, rest = cmd:match("^/fgui%s+([%a]+)(.*)$")
            if w == word then
                if arg and rest:find(arg, 1, true) then return line[2] end
                plain = plain or line[2]
            end
        end
    end
    return plain
end
-- The command closest to a mistyped word (two letters off at most), from the help: "equipbets" → "equipbest".
local function Distance(a, b)
    local prev = {}
    for j = 0, #b do prev[j] = j end
    for i = 1, #a do
        local cur = { [0] = i }
        for j = 1, #b do
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + ((a:sub(i, i) == b:sub(j, j)) and 0 or 1))
        end
        prev = cur
    end
    return prev[#b]
end
function ns.ClosestCommand(word, lines)
    word = ns.Trim(word):lower():match("^(%S+)") or ""
    if word == "" then return nil end
    local best, bestD
    for _, line in ipairs(lines or ns.helpLines) do
        local w = line[2] and line[1]:lower():match("^/fgui%s+([%a]+)")
        if w then
            local d = Distance(word, w)
            if d <= math.min(2, math.floor(#w / 3)) and (not bestD or d < bestD) then best, bestD = w, d end
        end
    end
    return best
end

ns.helpLines = {
    { "Everyday" },
    { "/fgui", "open the options (or use the minimap button)" },
    { "/fgui help [word]", "every command in a window you can search; click one to put it in the chat box" },
    { "/fgui move", "arrange your panels; right-click one for its own settings" },
    { "/fgui undo", "put back the last panel move, nudge, resize or reset" },
    { "/fgui setup", "run the guided setup again" },
    { "/fgui tools", "the Tools tab: every window, your lists, and the guide" },
    { "/fgui toolmenu", "every tool window in one small panel (also \"Tools\" on the Menu button)" },
    { "/fgui bars", "the Bars tab: each action bar's size, opacity, when it shows, rows and spacing" },
    { "/fgui bind", "keybind mode: hover an action button and press a key" },
    { "/fgui keys", "every action bar with its keys (or hold the key you bind for it)" },
    { "/fgui gallery", "whole screen layouts to choose from, each with a picture" },
    { "/fgui tour", "the short tour of the interface" },
    { "/fgui whatsthis", "point at any panel to see which feature made it" },
    { "/fgui ask <question>", "ask the guide where something is, in a few words" },
    { "/fgui demo", "fill the screen with samples, to see everything at once" },
    { "/fgui clean", "hide the interface for a few seconds (for screenshots)" },
    { "/fgui quiet", "quiet mode: no chat, names or info bar, for screenshots and streaming (again to undo)" },
    { "/fgui language", "choose the add-on's language" },
    { "/fgui new", "what changed in this version" },
    { "Groups and raids" },
    { "/fgui ready", "who in your group is missing food, a flask or a class buff" },
    { "/fgui ready me", "are you ready for the raid: food, flask, weapon, repairs, reagents, bag space, talents and gear" },
    { "/fgui bossnote", "your target's boss note, to read or write (/fgui bossnote send: to the group; list: all of them)" },
    { "/fgui death", "what hit you before you last died" },
    { "/fgui comp", "your group's roles, classes and who covers each buff" },
    { "/fgui missing", "who in your group is not here" },
    { "/fgui rolls", "everyone's /roll, highest first (\"clear\" starts a new round)" },
    { "/fgui pull 10", "a pull countdown for everyone in the group (/fgui break 5 is a break, in minutes)" },
    { "/fgui kicks <name> <name> ...", "the order your group takes turns interrupting (empty: everyone, A to Z)" },
    { "/fgui testgroup", "group practice: made-up group mates, to see group cooldowns, the interrupt rotation and buff coverage alone" },
    { "/fgui showcase", "screenshot mode: every frame with sample data and nothing in the way; again to end" },
    { "/fgui drops [raid]", "the loot browser: what each boss dropped, with the upgrades for you first" },
    { "/fgui farm [stop|zones]", "a farming session: time, and gold and item value an hour; again to see it, stop to end it, zones for your best spots" },
    { "/fgui threat", "show or hide the threat meter" },
    { "/fgui runs", "your dungeon and raid runs: times, bosses, wipes, deaths and loot, with the best time for each place" },
    { "/fgui set [name]", "put on a gear set by name (part of the name will do); on its own, the list of your sets" },
    { "/fgui raidsort role", "order the raid frames by group, role or name" },
    { "/fgui resetinstances", "reset your instances and tell the group" },
    { "/fgui meter", "tuck the damage meter drawer away, or bring it out" },
    { "/fgui meter reset", "clear the damage meter" },
    { "/fgui bgscore", "the battleground's score" },
    { "/fgui execute 20", "where the execute line sits on the target's health bar" },
    { "/fgui remind <buff>", "an icon while that buff is missing (again to stop)" },
    { "/fgui hidebuff <buff>", "leave that buff out of your buff row (again to show it)" },
    { "/fgui hideonframe <aura>", "never show that buff or debuff on the unit frames, raid frames or nameplates (again to show it)" },
    { "Your characters" },
    { "/fgui recap", "your last week on every character: gold, time played, levels, raids and dungeons, best loot (\"this\": this week so far)" },
    { "/fgui briefing", "what is waiting for you: crafts ready, mail on your other characters, lockouts reset, rested experience, jobs left" },
    { "/fgui alts", "your characters, with level and gold, and the total" },
    { "/fgui main", "make this character your main: new characters copy its setup" },
    { "/fgui session", "this session's statistics and time played, with your last session" },
    { "/fgui gold", "your gold day by day, and where this session's went" },
    { "/fgui checklist", "your daily and weekly jobs for each character; /fgui checklist add daily <job>" },
    { "/fgui lockouts", "which raids and dungeons each character is saved to" },
    { "/fgui profcd", "once-a-day crafts on all your characters, and when each is ready" },
    { "/fgui skillups", "with a profession window open: the recipes that still give skill points, best first, with what each needs" },
    { "/fgui crafts <search>", "what all your characters can craft; search their recipes" },
    { "/fgui reps", "reputations and currencies on all your characters; click one to pin it" },
    { "/fgui spec", "change talent set" },
    { "/fgui talents save <name>", "keep your talents as a build; /fgui talents lists them, click one to learn it" },
    { "/fgui talents send <player> <build>", "send a saved talent build to another player of your class" },
    { "Bags, gear and trade" },
    { "/fgui equipbest", "put on every upgrade in your bags (higher item level, already bound to you)" },
    { "/fgui sort", "sort your bags in the order of your bag sections (again to stop)" },
    { "/fgui bagrules add ilvl 50 = Upgrades", "a bag section by rule (ilvl, boe, set, quality, type, name)" },
    { "/fgui sell [item]", "always sell that item with your junk (shift-click the item in)" },
    { "/fgui keep [item]", "never sell it;  /fgui sell list shows both lists" },
    { "/fgui restock [item] 5", "always keep that many: bought at any vendor who sells it" },
    { "/fgui ah", "what in your bags is worth more at the auction house than at a vendor" },
    { "/fgui deposit", "put every crafting material in the bank (bank open)" },
    { "/fgui queue [n]", "add the selected recipe to the crafting queue; /fgui queue list shows it" },
    { "/fgui shop", "what the selected recipe still needs, counting bank and alts" },
    { "/fgui loot", "everything looted this session and its vendor value" },
    { "/fgui trades", "the trades on record" },
    { "/fgui mailrules add <character> cloth", "mail rules; \"Send by my rules\" at the mailbox sends them" },
    { "/fgui goal", "goals: /fgui goal rep <name>, gold 10000, level 60, mount <name>, or an item and a number" },
    { "/fgui goal add 50 <goal>", "a goal of your own on the goals panel (click it to count); /fgui goal ach <achievement> too" },
    { "People and notes" },
    { "/fgui note <text>", "a note on the player you have targeted (\"list\" shows them all)" },
    { "/fgui recent", "the people you grouped with lately: whisper or invite" },
    { "/fgui whispers", "the whisper window" },
    { "/fgui chattabs", "make a Loot tab and a Whispers tab" },
    { "/fgui keyword <word>", "pick that word out in chat, with a sound (again to stop)" },
    { "/fgui invword <word>", "the word a whisper must be for an invite (see \"Invite by whisper\")" },
    { "/fgui send <name> layout", "send your layout (or profile, or theme) to another player who has the add-on" },
    { "/fgui pack", "your whole UI (profile, layout, theme, bars, mail rules) in one string to share" },
    { "/fgui sharepreview", "look at a shared profile, layout or theme string before taking it" },
    { "The world" },
    { "/fgui way 45 62", "a waypoint with an arrow and the distance (alone, it clears)" },
    { "/fgui mapsize 70", "how large the smaller world map is" },
    { "/fgui rares", "the rares and treasures you have seen, and where" },
    { "/fgui level", "the zones that suit your level" },
    { "/fgui events", "holidays and events, now and in the next two weeks" },
    { "/fgui home", "which way home the home key would use" },
    { "/fgui mount", "a random favorite mount, or off the one you are on" },
    { "/fgui pet", "a random favorite pet (/fgui mount for a mount)" },
    { "Handy tools" },
    { "/fgui notepad", "a notepad for this character and one for all" },
    { "/fgui todo <text>", "a to-do list (\"daily ...\" comes back each day)" },
    { "/fgui calc 20*45", "a calculator" },
    { "/fgui timer 5m tea", "a countdown bar (also 90s, 1h30m, 2:30; \"off\" cancels them all)" },
    { "/fgui speak [text]", "try the spoken alerts' voice" },
    { "/fgui volume 60", "the master volume" },
    { "/fgui currency <id>", "the currency shown on the info bar" },
    { "/fgui mute <number>", "never play that sound file again" },
    { "/fgui media", "fonts and bar textures other add-ons offer (/fgui font, /fgui bartexture)" },
    { "Settings and backups" },
    { "/fgui textsize 120", "all the add-on's lettering at that size, in percent (70 to 150; \"reset\" is as it came)" },
    { "/fgui uisize 90", "the whole interface at that size, in percent of the game's (50 to 150; \"reset\" is as it came)" },
    { "/fgui backup", "the backups of your settings, made before each update, once a day and before a reset; click one to see how to put it back" },
    { "/fgui history", "what you changed in this profile, and when; click a change to undo it" },
    { "/fgui reset", "put this profile back to how it came (type it twice; a backup is kept)" },
    { "/fgui safe", "safe mode: reload with every feature off (again to leave it)" },
    { "/fgui windows reset", "the game's windows open in their usual places again" },
    { "/fgui conflicts on|off", "stand aside for other add-ons that do the same job, or not" },
    { "If something is wrong" },
    { "/fgui check", "a report on what is running and what the game allows" },
    { "/fgui check new", "try each feature added since 11.6 and report what works, to copy and send" },
    { "/fgui selftest", "work through the add-on and list what passed and what did not" },
    { "/fgui report", "everything needed to report a problem, ready to copy" },
    { "/fgui blocked", "anything the game refused to let the add-on do, and where" },
    { "/fgui memory", "how much memory the add-on is using" },
    { "/fgui addons", "every add-on by the memory it uses" },
    { "/fgui perf [seconds]", "how much time each part of the add-on takes" },
    { "/fgui perf fight", "measure the add-on through your next fight, then a report to send" },
    { "/fgui tree", "how the window under your mouse is built (for restyling requests)" },
    { "/fgui strings", "every label shown so far, laid out for translators" },
}

SLASH_FANTASYGLASSUI1 = "/fgui"
SLASH_FANTASYGLASSUI2 = "/fantasyglass"
SLASH_FANTASYGLASSUI3 = "/sui"                              -- the command from when this was called StylishUI still works
-- The smaller tools, by the word after /fgui. Each is given whatever follows the word, as typed.
ns.toolCommands = {
    alts = function() if ns.ShowCharacters then ns:ShowCharacters() end end,
    send = function(t) ns:SendCommand(t) end,
    sort = function() ns:SortBags() end,
    kicks = function(t) ns:KickCommand(t) end,
    crafts = function(t) ns:ShowCrafts(t) end,
    keys = function() ns:ShowKeySheet() end,
    quiet = function() ns:ToggleQuiet() end,
    testgroup = function() ns:ToggleTestGroup() end,
    showcase = function() ns:ToggleShowcase() end,
    drops = function(t) ns:ShowDrops(t) end,
    farm = function(t) ns:Farm(t) end,
    runs = function() ns:ShowRuns() end,
    set = function(t) ns:SetCommand(t) end,
    threat = function() if ns.ToggleThreatMeter then ns:ToggleThreatMeter() else ns:Print("The threat meter is switched off (Features tab).") end end,
    screenshot = function() ns:ToggleShowcase() end,
    checknew = function() ns:CheckNew() end,
    bossnote = function(t) ns:BossNoteCommand(t) end,
    death = function() ns:ShowDeathRecap() end,
    ah = function() ns:ShowWorthSelling() end,
    home = function() ns:HomeCommand() end,
    backup = function(t) ns:BackupCommand(t) end,
    history = function() ns:ShowSettingHistory() end,
    pack = function() ns:ShowCopyBox(ns:ExportPack(), ns:Tr("Your whole UI in one string: Ctrl+C to copy. Anyone with Fantasy Glass UI can paste it in Profiles, Preview a shared string.")) end,
    equipbest = function() ns:EquipBest() end,
    main = function(t) ns:MainCommand(t) end,
    pet = function() ns:SummonPet() end,
    reps = function() ns:ShowReps() end,
    hideonframe = function(t) ns:ListCommand("auraBlock", t, "Hidden on frames") end,
    talents = function(t) ns:TalentCommand(t) end,
    events = function() ns:ShowEvents() end,
    comp = function() ns:ShowComposition() end,
    bgscore = function() ns:ShowBattlegroundScore() end,
    bagrules = function(t) ns:BagRulesCommand(t) end,
    mailrules = function(t) ns:MailRulesCommand(t) end,
    sharepreview = function(t) if ns.Trim(t) ~= "" then ns:PreviewShared(t) else ns:ShowSharePreview() end end,
    pull = function(t) ns:CountdownCommand("pull", t) end,
    ["break"] = function(t) ns:CountdownCommand("break", t) end,
    toolmenu = function() ns:ToggleToolsMenu() end,
    checklist = function(t) ns:ChecklistCommand(t) end,
    gallery = function() ns:ShowGallery() end,
    selftest = function() ns:SelfTest() end,
    speak = function(t) if ns:Speak(ns.Trim(t) ~= "" and ns.Trim(t) or ns:Tr("Fantasy Glass UI is speaking.")) then return end
        ns:Print("Nothing was said: %s", tostring(ns.speakState or "spoken alerts are not available")) end,
    tour = function() ns:StartTour() end,
    whatsthis = function() ns:WhatsThis() end,
    level = function() ns:ShowLevelZones() end,
    profcd = function() ns:ShowProfCooldowns() end,
    briefing = function() ns:ShowBriefing() end,
    recap = function(t) ns:ShowRecap(t) end,
    skillups = function() ns:ShowSkillUps() end,
    textsize = function(t) ns:SizeCommand("fontScale", t, 70, 150) end,
    uisize = function(t) ns:SizeCommand("uiScale", t, 50, 150) end,
    perf = function(t) ns:PerfCommand(t) end,
    session = function() if ns.ShowSession then ns:ShowSession() else ns:PrintSession() end end,
    rares = function() ns:ShowRares() end,
    queue = function(t) ns:QueueCommand(t) end,
    goal = function(t) ns:GoalCommand(t) end,
    ready = function(t)
        if ns.Trim(t or ""):lower() == "me" then return ns:ReadyMe() end
        if not ns:ReadyReport() then ns:Print("Not during a fight: the game hides buffs from add-ons until it is over.") end end,
    remind = function(t) ns:ListCommand("remindBuffs", t, "Missing buff reminder") end,
    hidebuff = function(t) ns:ListCommand("auraHide", t, "Hidden buffs") end,
    keyword = function(t) ns:ListCommand("keywords", t, "Chat keywords") end,
    execute = function(t) ns:ExecuteCommand(t) end,
    mount = function() ns:MountUp() end,
    note = function(t) ns:NoteCommand(t) end,
    recent = function() ns:ShowRecent() end,
    missing = function() ns:ShowMissing() end,
    rolls = function(t) ns:ShowRolls(t) end,
    lockouts = function() ns:ShowLockouts() end,
    raidsort = function(t) ns:RaidSortCommand(t) end,
    resetinstances = function() ns:ResetInstancesNow() end,
    way = function(t) ns:WayCommand(t) end,
    mapsize = function(t) ns:MapSizeCommand(t) end,
    restock = function(t) ns:RestockCommand(t) end,
    gold = function() ns:ShowGold() end,
    shop = function(t) ns:ShowShopping(t) end,
    trades = function() ns:ShowTrades() end,
    deposit = function() ns:DepositMaterials() end,
    loot = function(t) ns:ShowLoot(t) end,
    whispers = function() ns:ShowWhispers() end,
    chattabs = function() ns:SetupChatTabs() end,
    spec = function(t) ns:SwitchTalentSet(tonumber(t)) end,
    volume = function(t) ns:VolumeCommand(t) end,
    currency = function(t) ns:CurrencyCommand(t) end,
    notepad = function() ns:ShowNotepad() end,
    todo = function(t) ns:TodoCommand(t) end,
    calc = function(t) ns:CalcCommand(t) end,
    media = function() ns:MediaCommand("list", "") end,
    font = function(t) ns:MediaCommand("font", t) end,
    bartexture = function(t) ns:MediaCommand("bar", t) end,
    mute = function(t) ns:MuteCommand(t) end,
    unmute = function(t) ns:MuteCommand("remove " .. t) end,
    addons = function() ns:ShowAddons() end,
    tools = function() ns:ToggleConfig("tools") end,
    guide = function(t) ns:GuideCommand(t) end,
    guides = function(t) ns:GuideCommand(t) end,
    bars = function() ns:ToggleConfig("bars") end,
    buttons = function()
        if not ns.ButtonBagLines then ns:Print("The minimap button collector is switched off."); return end
        ns:ShowTextWindow("Minimap buttons", table.concat(ns:ButtonBagLines(), "\n"))
    end,
    unlock = function(t)
        if ns:GuideUnlock(t) then ns:Print("Quest guides are unlocked on this account. They are on the Guide tab of /fgui.")
        else ns:Print("That is not the phrase.") end
    end,
    lock = function() ns:GuideLock(); ns:Print("Quest guides are locked again.") end,
    ask = function(t) if ns:LoadOptions() and ns.GuidePrint then ns:GuidePrint(t) end end,
}
-- Runs one of them if `msg` starts with its word. Returns true when it did.
function ns:ToolCommand(msg, raw)
    local word = msg:match("^(%S+)")
    local fn = word and ns.toolCommands[word]
    if not fn then return false end
    local rest = (raw or msg):gsub("^%s*%S+%s*", "", 1)
    local ok, err = pcall(fn, rest)
    if not ok then ns:PrintRaw("|cffff4444/fgui " .. word .. ":|r " .. tostring(err)) end
    return true
end

SlashCmdList["FANTASYGLASSUI"] = function(msg)
    local raw = strtrim(msg or "")
    msg = strlower(raw)
    ns:InitDB()
    if msg == "reset" then
        ns:ResetProfileCommand()
    elseif msg == "setup" or msg == "role" then
        ns:ShowSetup()
    elseif msg == "move" then
        ns:ToggleMove()
    elseif msg == "test" or msg == "preview" then
        ns:TogglePreview()
    elseif msg == "profile" or msg == "profiles" then
        ns:ToggleConfig("profiles")
    elseif msg == "layout" then
        ns:ToggleConfig("layout")
    elseif msg == "colors" then
        ns:ToggleConfig("colors")
    elseif msg == "look" or msg == "theme" then
        ns:ToggleConfig("look")
    elseif msg == "clickcast" then
        ns:ToggleConfig("clickcast")
    elseif msg == "combat" then
        ns:ToggleConfig("combat")
    elseif msg == "check new" then
        ns:CheckNew()
    elseif msg == "check" then
        ns:SelfCheck()
    elseif msg == "language" or msg:sub(1, 9) == "language " then
        -- /fgui language            lists the choices
        -- /fgui language deutsch    (or: de, german, english, en, français, fr, español, es, auto)
        local want = msg:sub(10):gsub("^%s+", ""):gsub("%s+$", "")
        local ALIAS = { auto = "auto", game = "auto", en = "enUS", english = "enUS", enus = "enUS",
                        de = "deDE", deutsch = "deDE", german = "deDE", dede = "deDE",
                        fr = "frFR", ["français"] = "frFR", francais = "frFR", french = "frFR", frfr = "frFR",
                        es = "esES", ["español"] = "esES", espanol = "esES", spanish = "esES", eses = "esES",
                        it = "itIT", italiano = "itIT", italian = "itIT", itit = "itIT",
                        pt = "ptBR", ["português"] = "ptBR", portugues = "ptBR", portuguese = "ptBR", ptbr = "ptBR",
                        ru = "ruRU", ["русский"] = "ruRU", russian = "ruRU", ruru = "ruRU",
                        ko = "koKR", ["한국어"] = "koKR", korean = "koKR", kokr = "koKR",
                        zh = "zhCN", cn = "zhCN", ["简体中文"] = "zhCN", ["中文"] = "zhCN", chinese = "zhCN", zhcn = "zhCN" }
        local code = ALIAS[want]
        if code then
            if ns:SetLanguage(code) then
                ns:PrintRaw(ns:LanguageName(code) .. ". /reload")
            else
                ns:PrintRaw(ns:LanguageName(ns:Language()))
            end
        else
            ns:PrintRaw("/fgui language  auto | english | deutsch | français | español | italiano | português | russian | korean | chinese")
        end
    elseif msg:sub(1, 5) == "sell " or msg:sub(1, 5) == "keep " or msg == "sell" or msg == "keep" then
        -- /fgui sell [item]   put an item on the "always sell" list, or take it off (shift-click it into the chat line)
        -- /fgui keep [item]   the same for the "never sell" list
        -- /fgui sell list     what is on each list
        local kind, rest = msg:sub(1, 4), msg:sub(6)
        local id = ns:ItemIDOf(rest)
        if id then
            local now = (ns:ItemListState(id) ~= kind) and kind or nil
            ns:SetItemList(id, now)
            local name = (ns:GetItemInfo(id)) or (ns:Tr("Item") .. " " .. id)
            ns:Print(now == "sell" and "%s will always be sold with your junk." or now == "keep" and "%s will never be sold with your junk." or "%s is off both lists.", tostring(name))
        else
            for _, which in ipairs({ "sell", "keep" }) do
                local names = {}
                for itemID in pairs(ns.root and ns.root[which .. "List"] or {}) do names[#names + 1] = tostring((ns:GetItemInfo(itemID)) or (ns:Tr("Item") .. " " .. itemID)) end
                table.sort(names)
                ns:Print(which == "sell" and "Always sold: %s" or "Never sold: %s", #names > 0 and table.concat(names, ", ") or ns:Tr("nothing"))
            end
            ns:Print("To change a list: /fgui sell or /fgui keep, a space, then shift-click the item.")
        end
    elseif msg == "windows reset" or msg == "windows" then
        if msg == "windows" then ns:Print("/fgui windows reset - the game's windows open in their usual places again") else ns:ResetWindowPositions() end
    elseif msg == "memory" then
        -- how much memory the add-on is using, without loading the options to find out
        if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            UpdateAddOnMemoryUsage()
            local text = format("%.0f KB.", tonumber(GetAddOnMemoryUsage(ADDON)) or 0)
            if ns.optionsLoaded then
                text = text .. "  " .. format(ns:Tr("Options, setup and self-check: %.0f KB more (opened this session)."), tonumber(GetAddOnMemoryUsage(OPTIONS)) or 0)
            else
                text = text .. "  " .. ns:Tr("Options, setup and self-check: not loaded (they load the first time one is opened).")
            end
            ns:PrintRaw(text)
        else
            ns:Print("This game client does not report add-on memory.")
        end
    elseif ns:ToolCommand(msg, raw) then
        -- (one of the smaller tools: see ns.toolCommands)
    elseif msg == "alts" or msg == "characters" then
        if ns.ShowCharacters then ns:ShowCharacters() end
    elseif msg == "timer" or msg:sub(1, 6) == "timer " then
        if ns.TimerCommand then ns:TimerCommand(raw:gsub("^%s+", ""):sub(7)) end
    elseif msg == "meter reset" then
        if not (ns.ResetMeter and ns:ResetMeter()) then ns:Print("The damage meter could not be reset from here.") end
    elseif msg == "invword" or msg:sub(1, 8) == "invword " then
        -- /fgui invword           says the word
        -- /fgui invword invite    changes it
        local want = msg:sub(9):gsub("^%s+", ""):gsub("%s+$", "")
        if want:find("%s") then ns:Print("The invite word is one word, with no spaces."); return end
        if want ~= "" then ns.db.whisperInviteWord = want end
        ns:Print("Whisper invites answer to the word \"%s\".", ns.InviteWord and ns:InviteWord() or "inv")
        if not ns.db.whisperInvite then ns:Print("They are switched off: see \"Invite by whisper\" on the Features tab.") end
    elseif msg == "meter" then
        if ns.ToggleMeter then ns:ToggleMeter() else ns:Print("The damage meter is not a drawer right now (see \"Damage meter: drawer on the chat box\" on the Features tab).") end
    elseif msg == "blocked" then
        -- what the game counts as "Interface actions failed because of this AddOn", with the place each came from
        local lines = ns.BlockedLines and ns:BlockedLines(8) or { "Blocked actions: not being counted." }
        for i, line in ipairs(lines) do
            if i == 1 then ns:PrintRaw(line) else ns:PrintRaw(line) end
        end
        if ns.blocked and ns.blocked.total > 0 then ns:PrintRaw("  /fgui report puts this in a form you can send.") end
    elseif msg == "undo" then
        ns:Undo()
    elseif msg == "safe" or msg == "safe on" or msg == "safe off" then
        -- /fgui safe       into safe mode (every feature off), or out of it again
        local want = (msg == "safe on") or (msg == "safe" and not ns.safeMode)
        if ns:SetSafeMode(want) then ReloadUI() end
    elseif msg == "demo" then
        ns:ToggleDemo()
    elseif msg == "report" then
        ns:ProblemReport()
    elseif msg == "clean" or msg:sub(1, 6) == "clean " then
        ns:CleanScreen(tonumber(msg:sub(7)))
    elseif msg == "conflicts on" or msg == "conflicts off" then
        ns.db.stepAside = (msg == "conflicts on")
        ns:Print(ns.db.stepAside and "Fantasy Glass UI will leave jobs to other add-ons that do them. /reload to apply."
            or "Fantasy Glass UI will run all its features even beside add-ons that do the same job. /reload to apply.")
    elseif msg == "bind" then
        ns:ToggleKeybindMode()
    elseif msg == "session" then
        if ns.ShowSession then ns:ShowSession() else ns:PrintSession() end
    elseif msg == "new" then
        ns:ShowTextWindow("What's new in Fantasy Glass UI", ns:WhatsNew(true))
    elseif msg == "strings" then
        ns:ExportStrings()
    elseif msg == "tree" then
        ns:DumpTree()                                   -- the window under the mouse
    elseif msg:sub(1, 5) == "tree " then
        ns:DumpTree(strtrim(raw:sub(6)))
    elseif msg == "status" then
        local role = ns.roles[ns.db.role] and ns.roles[ns.db.role].label or "none"
        ns:PrintRaw("role: " .. role)
        local listed = {}
        for _, m in ipairs(ns.modules) do
            if not listed[m.key] and m.key ~= "fallbacks" then
                listed[m.key] = true
                ns:PrintRaw(format("  %s: %s", m.key, ns.loaded[m.key] and "|cff33ff66on|r" or "|cffff4444off|r"))     -- (feature keys: not for translating)
            end
        end
    elseif msg == "help" or msg:sub(1, 5) == "help " then
        ns:ShowHelp(msg:sub(6))
    elseif msg == "" or msg == "options" or msg == "config" or msg == "show" then
        ns:ToggleConfig()
    else
        local near = ns.ClosestCommand(msg)
        if near then
            ns:Print("\"%s\" is not a command. Did you mean |cffffff00/fgui %s|r?", raw, near)
        elseif #ns.HelpMatches(ns.helpLines, msg) > 0 then
            ns:Print("\"%s\" is not a command. These mention it:", raw)
            ns:ShowHelp(msg)
        else
            ns:Print("\"%s\" is not a command. |cffffff00/fgui help|r lists them all.", raw)
        end
    end
end
