local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
------------------------------------------------------------------------------------------
-- The route planner's own window (the folders plan, ruling 10). At the top, what you follow: the
-- plan's first lines and the step you are on, or the trip you are on, or that you follow no plan, and
-- how much gold riding still needs. Under it the buttons: Plan my route (Plan again while following),
-- Stop, Ways to make gold and Save for riding. Below, every setting for what the planner plans, in nine
-- groups, built with the Guide tab's 12.3 rows (ns.GuideRowKit, FantasyGlassUI_Options/Bars.lua): a
-- heading over each group, a row to a setting with its name and what it does, the switch at the right,
-- the keys of the settings window, and "Bigger controls". Every setting keeps its ns.db key and what
-- it did on the Guide tab, where these rows were before. Built at its first open, never at login.
------------------------------------------------------------------------------------------
local NAME, WIDTH, HEIGHT = "FantasyGlassUIPlanner", 600, 640
local SUMMARY_TOP, SUMMARY_LINES, SUMMARY_LINE_H = -56, 5, 24     -- (the summary: y -56 to -176)
local BUTTONS_Y, SWITCHES_Y, SHEET_W = -186, -222, 556
local W                                                     -- the window, once built

local function Shown(f, on) if f then if on then f:Show() else f:Hide() end end end
local function Num(v) if ns:IsSecret(v) or type(v) ~= "number" or v ~= v then return nil end return v end

-- The nine groups, in this order (ruling 10), each { id, heading }.
local GROUPS = {
    { "group", "Group quests" }, { "stops", "Stops on the way" }, { "explore", "Exploring and gathering" },
    { "rewards", "Rewards, the log and the inn" }, { "time", "Time, style and sliders" }, { "map", "Map" },
    { "records", "Records" }, { "speak", "Reading aloud" }, { "together", "With others" },
}
ns.PLANNER_WINDOW_GROUPS = GROUPS
-- What each group holds, top to bottom (the fields of the window's T).
local ORDER = {
    group = { "groupButton", "soloElitesBox", "classQuestsBox", "dungeonsBox" },
    stops = { "flightsBox", "trainerBox", "holdBox", "vendorBox", "suppliesBox", "professionBox", "mountBox", "mailBox" },
    explore = { "exploreBox", "gatherBox" },
    rewards = { "pickBox", "rewardsBox", "logAdviceBox", "innBox", "restedBox", "dryBox", "reputationButton", "skippedButton" },
    time = { "keepRouteBox", "playTimeButton", "breaksBox", "breakButton", "styleButton", "speedSlider", "safetySlider", "storySlider", "zoneGoalButton", "deathsBox" },
    map = { "mapLineBox", "mapHubsBox", "tomTomBox" },
    records = { "raceBox", "leftOffBox", "whyBox" },
    speak = { "speakBox" },
    together = { "findGroupBox", "findGroupChannel", "duoAskBox", "duoButton", "sharePlanButton" },
}

------------------------------------------------------------------------------------------
-- What you follow, in at most five lines
------------------------------------------------------------------------------------------
local function StepCount(st, guide)
    local steps = type(guide) == "table" and type(guide.steps) == "table" and guide.steps or {}
    local at = Num(st.at) or 1
    return at, #steps, steps[at]
end
local function RidingLine()
    if not (ns.PlannerRiding and ns.PlannerGoldText) then return nil end
    local level = UnitLevel and UnitLevel("player")
    level = Num(level)
    local r = level and ns.PlannerRiding(level)
    if not (type(r) == "table" and Num(r.short) and r.short > 0) then return nil end
    return format(ns:Tr("Riding: %s to go"), ns.PlannerGoldText(r.short))
end
function ns.PlannerWindowSummary()
    local out = {}
    local st = ns.GuideState and ns.GuideState()
    if type(st) == "table" and st.name == ns.GUIDE_PLANNED then
        local plan = ns:GuideGet(ns.GUIDE_PLANNED)
        if ns.PlannerPreviewLines then
            for _, line in ipairs(ns.PlannerPreviewLines(plan, st.summary)) do
                if #out >= 4 then break end
                if not line.action and type(line.left) == "string" and line.left ~= "" then out[#out + 1] = line.left end
            end
        end
        local at, total, step = StepCount(st, plan)
        if type(step) == "table" then
            local ok, text = pcall(ns.GuideStepBase, step)
            out[#out + 1] = format(ns:Tr("Step %d of %d: %s"), at, total, ok and type(text) == "string" and text or tostring(step.kind))
        end
    elseif type(st) == "table" and ns.GUIDE_TRIP ~= nil and st.name == ns.GUIDE_TRIP then
        -- (the trip, group D's: its guide is the state's plan or ns:GuideGet's; its title is the trip's)
        local trip = type(st.trip) == "table" and st.trip or {}
        local guide = ns:GuideGet(ns.GUIDE_TRIP)
        if type(guide) ~= "table" then guide = type(st.plan) == "table" and st.plan or trip end
        local at, total = StepCount(st, guide)
        local title = trip.title
        if type(title) ~= "string" or title == "" then title = type(guide) == "table" and type(guide.title) == "string" and guide.title or ns:Tr("Ways to make gold") end
        out[#out + 1] = format(ns:Tr("On a trip: %s, step %d of %d"), title, at, total)
        local back = type(st.resume) == "table" and st.resume.name or nil      -- (what the trip paused: the plan, a written guide, or nothing)
        if back ~= nil and back == ns.GUIDE_PLANNED then out[#out + 1] = ns:Tr("Your levelling plan waits.")
        elseif type(back) == "string" and not ns:IsSecret(back) and back ~= "" then out[#out + 1] = format(ns:Tr("\"%s\" waits."), back) end
    else
        out[#out + 1] = ns:Tr("You are not following a plan.")
    end
    local riding = RidingLine()
    if riding then
        while #out >= SUMMARY_LINES do table.remove(out, #out - 1) end   -- (five lines at most: the riding line takes a preview line's place)
        out[#out + 1] = riding
    end
    return out
end

------------------------------------------------------------------------------------------
-- The settings, in their groups. Each group's function adds its rows to T.rows and may hand back a
-- refresh (run by T.Refresh). Moved from the Guide tab with their labels, keys and callbacks.
------------------------------------------------------------------------------------------
local function GroupSection(K, G, Replan, T)
    local groups = { { "solo", "Solo" }, { "grouped", "When grouped" }, { "all", "Everything" } }
    local function DrawGroup(b)
        local now, gname = ns.db.plannerGroup or "solo", nil
        for _, g in ipairs(groups) do if g[1] == now then gname = g[2] end end
        b.text:SetText(ns:Tr("Group quests") .. ":  " .. ns:Tr(gname or "Solo"))
    end
    local group = K.ButtonRow(G, "group", "Group quests", "Solo plans only quests you can do alone. When grouped adds group quests while you are in a group, and Everything always does.", function(b, button)
        local now, at = ns.db.plannerGroup or "solo", 1
        for i, g in ipairs(groups) do if g[1] == now then at = i end end
        at = (button == "RightButton") and ((at - 2) % #groups + 1) or (at % #groups + 1)
        ns.db.plannerGroup = groups[at][1]
        DrawGroup(b)
        Replan()
    end, true)
    T.groupButton = group
    return function() DrawGroup(group) end
end

-- What the route includes, and the advice along the way: each a switch (most plan again)
local function SwitchesSection(K, G, Replan, T)
    local function Include(sec, key, label, desc)
        return K.SwitchRow(G, sec, key, label, desc, function() return ns.db[key] ~= false end, function(v)
            ns.db[key] = v
            Replan()
        end)
    end
    local function Advice(sec, key, label, desc, after)
        return K.SwitchRow(G, sec, key, label, desc, function() return ns.db[key] ~= false end, function(v)
            ns.db[key] = v
            after()
        end)
    end
    T.soloElitesBox = Include("group", "plannerSoloElites", "Include elites my class has soloed", "Elite quests that one of your characters of this class has done alone count as Solo quests.")
    T.classQuestsBox = Include("group", "plannerClassQuests", "Plan class quests", "Your class quests go on the route at the right level, and the panel says when one is ready.")
    T.dungeonsBox = Include("group", "plannerDungeons", "Dungeon runs in my route", "When a dungeon gives more experience an hour than the quests near you, the route picks up its quests, finds a group and runs it, solo players too.")
    T.flightsBox = Include("stops", "plannerLearnFlights", "Learn new flight points on the way", "A short way round to a flight master you do not know yet, when the route passes close.")
    T.trainerBox = Include("stops", "plannerTrainer", "Visit your trainer on the way", "A stop at your class trainer every two levels, for your new spells.")
    T.holdBox = Include("stops", "plannerHold", "Save hand-ins to level in town", "A hand-in that would take you up a level waits until the route reaches your trainer's town.")
    T.vendorBox = Include("stops", "plannerVendor", "Sell and repair stops", "A stop at a vendor when your bags are nearly full or your gear is worn.")
    T.suppliesBox = Include("stops", "plannerSupplies", "Buy supplies at the vendor stop", "At that stop, ammunition, food and drink are bought too.")
    T.professionBox = Include("stops", "plannerProfession", "Profession training stops", "A stop at a profession's trainer when your skill has reached what you can learn now.")
    T.mountBox = Include("stops", "plannerMount", "Mount reminder", "From level 40: the riding trainer, your mount, and how much gold is still to find.")
    T.mailBox = Include("stops", "plannerMail", "Mail stops", "A stop at a mailbox when mail is waiting and one is close.")
    T.exploreBox = Include("explore", "plannerExplore", "Explore on the way", "Places you have not discovered yet, when they are close to the route.")
    T.gatherBox = Include("explore", "plannerGather", "Gather on the way", "Herbs and ore you have gathered before, close to the route, and a note to skin what you kill.")
    T.pickBox = Advice("rewards", "plannerPickReward", "Show the best quest reward", "At a hand-in, the reward that suits you best is marked and named in chat. You choose it yourself.", function() end)
    T.rewardsBox = Include("rewards", "plannerRewards", "Count upgrades in rewards", "A quest whose reward is better than what you wear counts for more.")
    T.logAdviceBox = Advice("rewards", "plannerLogAdvice", "Quest log advice", "When your quest log is nearly full, the panel says which quests are worth abandoning.", function()
        if ns.GuideShowPanel and ns.GuidePanelShown and ns:GuidePanelShown() then ns:GuideShowPanel() end
    end)
    T.innBox = Advice("rewards", "plannerInn", "Suggest an inn when you stop", "After a long stretch of play, the panel points to an inn close by, to log out in for rested experience.", function() end)
    T.restedBox = Include("rewards", "plannerRested", "Count rested experience", "Kills are worth double while you are rested, and the route counts them so.")
    T.dryBox = Advice("rewards", "plannerDry", "Suggest what to do when quests run dry", "When no quest is worth the trip, a dungeon or a place to grind is suggested instead.", Replan)
    T.reputationButton = K.ButtonRow(G, "rewards", "Reputation I want", "For each faction, the standing you want to reach: quests that raise it count for more until you get there.", function()
        if ns.GuideReputation then ns:GuideReputation() end
    end)
    T.skippedButton = K.ButtonRow(G, "rewards", "Quests you skipped", "The quests you told the planner never to suggest. Click one there to have it suggested again.", function()
        if ns.GuideSkipped then ns:GuideSkipped() end
    end)
    T.deathsBox = Include("time", "plannerDeaths", "Learn from my deaths", "A place where you died twice is left alone until you are two levels higher.")
    T.whyBox = Advice("records", "plannerWhy", "Show why each step is there", "Each step on the panel says what it is worth: the experience, or the time it saves.", Replan)
end

-- Batch 4: the time you have, break reminders, speed or story, and the zone goal.
local function PaceSection(K, G, Replan, T)
    local refreshes = {}
    -- The time you have and break reminders
    local times = ns.PLANNER_PLAY_TIMES or { { 0, "No limit" } }
    local function DrawTime(b)
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        local now, name = tonumber(rec and rec.playDefault) or 0, times[1][2]
        for _, t in ipairs(times) do if t[1] == now then name = t[2] end end
        b.text:SetText(ns:Tr("How long can you play?") .. "  " .. ns:Tr(name))
    end
    local timeButton = K.ButtonRow(G, "time", "How long can you play?", "Plan my route then takes only what fits in this time, and ends at a good place to stop. /fgui guide plan with no number does the same.", function(b, button)
        local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
        local now, at = tonumber(rec and rec.playDefault) or 0, 1
        for i, t in ipairs(times) do if t[1] == now then at = i end end
        rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
        at = (button == "RightButton") and ((at - 2) % #times + 1) or (at % #times + 1)
        if rec then rec.playDefault = times[at][1] end
        DrawTime(b)
    end, true)
    local breaks = K.SwitchRow(G, "time", "plannerBreaks", "Remind me to take a break at a stopping place", "After a long stretch of play, the panel says so when you reach a good place to stop.",
        function() return ns.db.plannerBreaks == true end, function(v) ns.db.plannerBreaks = v end)
    local lengths = { { 60, "1 hour" }, { 90, "1 hour 30" }, { 120, "2 hours" }, { 180, "3 hours" } }
    local function DrawBreak(b)
        local now, name = tonumber(ns.db.plannerBreakMinutes) or 120, "2 hours"
        for _, t in ipairs(lengths) do if t[1] == now then name = t[2] end end
        b.text:SetText(ns:Tr("Break reminder after") .. ":  " .. ns:Tr(name))
    end
    local breakButton = K.ButtonRow(G, "time", "Break reminder after", "How long that stretch of play is.", function(b, button)
        local now, at = tonumber(ns.db.plannerBreakMinutes) or 120, 3
        for i, t in ipairs(lengths) do if t[1] == now then at = i end end
        at = (button == "RightButton") and ((at - 2) % #lengths + 1) or (at % #lengths + 1)
        ns.db.plannerBreakMinutes = lengths[at][1]
        DrawBreak(b)
    end, true)
    T.playTimeButton, T.breaksBox, T.breakButton = timeButton, breaks, breakButton
    -- Keep my route: no new plan by itself (no replan when it is switched, either)
    T.keepRouteBox = K.SwitchRow(G, "time", "plannerKeepRoute", "Keep my route",
        "Levelling up, hand-ins and loading screens leave the route as it is. Only Plan my route and Plan again make a new one.",
        function() return ns.db.plannerKeepRoute == true end, function(v) ns.db.plannerKeepRoute = v and true or false end)
    refreshes[#refreshes + 1] = function()
        DrawTime(timeButton)
        breaks:SetChecked(ns.db.plannerBreaks == true)
        DrawBreak(breakButton)
    end

    -- Speed or story: a style, and the three weights it sets (a slider moved makes it Custom)
    local styles = { { "speed", "Speed" }, { "story", "Story" }, { "custom", "Custom" } }
    local function DrawStyle(b)
        local now, name = ns.PlannerStyle and ns.PlannerStyle() or "speed", "Speed"
        for _, st in ipairs(styles) do if st[1] == now then name = st[2] end end
        b.text:SetText(string.format(ns:Tr("Style: %s"), ns:Tr(name)))
    end
    local sliders, syncing = {}, false
    local function SyncSliders()
        if not ns.PlannerWeights then return end
        local sp, sa, st = ns.PlannerWeights()
        syncing = true
        sliders.speed:SetValue(sp); sliders.safety:SetValue(sa); sliders.story:SetValue(st)
        syncing = false
    end
    local styleButton = K.ButtonRow(G, "time", "Style: %s", "Speed and Story each set the three sliders below. Set the sliders yourself for a style of your own.", function(b, button)
        local now, at = ns.PlannerStyle and ns.PlannerStyle() or "speed", 1
        for i, st in ipairs(styles) do if st[1] == now then at = i end end
        at = (button == "RightButton") and ((at - 2) % #styles + 1) or (at % #styles + 1)
        if ns.PlannerSetStyle then ns.PlannerSetStyle(styles[at][1]) end
        DrawStyle(b)
        SyncSliders()
    end, true)
    styleButton.row.tipTitle = "Speed or story"
    local means = { speed = "How much the route goes for the most experience in the time.",
                    safety = "How much it keeps away from elites, escorts and places where you died.",
                    story = "How much it goes for the zone's quest chains. At 100 it reaches back up to 10 levels for them." }
    for _, def in ipairs({ { "speed", "Speed" }, { "safety", "Safety" }, { "story", "Story" } }) do
        local slider = K.SliderRow(G, "time", def[2], means[def[1]], 0, 100, 10, def[1] == "speed" and 100 or 0, function(v)
            if syncing then return end
            if ns.PlannerSetWeight then ns.PlannerSetWeight(def[1], v) end
            DrawStyle(styleButton)
        end)
        sliders[def[1]] = slider
    end
    T.styleButton, T.speedSlider, T.safetySlider, T.storySlider = styleButton, sliders.speed, sliders.safety, sliders.story
    refreshes[#refreshes + 1] = function()
        DrawStyle(styleButton)
        SyncSliders()
    end

    -- The goal: leveling, or finishing the zone you are in (the planner plans again either way)
    local function DrawGoal(b)
        local goal = ns.PlannerZoneGoal and ns.PlannerZoneGoal()
        if not goal then b.text:SetText(ns:Tr("Goal: Level up")) return end
        local name = ns.PlannerMapName and ns.PlannerMapName(goal) or tostring(goal)
        b.text:SetText(string.format(ns:Tr("Goal: Finish %s"), name))
    end
    local goal = K.ButtonRow(G, "time", "", "Level up plans the most experience wherever it is. Finish the zone plans every quest left in the zone you are in, then goes back to levelling.", function(b)
        if ns.PlannerZoneGoal and ns.PlannerZoneGoal() then
            ns.PlannerSetZoneGoal(nil)
        elseif ns.PlannerGoalZone and ns.PlannerSetZoneGoal then
            local zone = ns.PlannerGoalZone()
            if zone then ns.PlannerSetZoneGoal(zone) end
        end
        DrawGoal(b)
    end, true)
    goal.row.tipTitle, goal.row.navKey = "Goal: Level up", "guide:goal"
    T.zoneGoalButton = goal
    T.zoneGoalDraw = function() DrawGoal(goal) end          -- (the goal can end by itself: "Zone done" redraws the label)
    refreshes[#refreshes + 1] = T.zoneGoalDraw
    return function() for _, r in ipairs(refreshes) do r() end end
end

-- Batch 4: the route and the quest areas on the map.
local function MapSection(K, G, Replan, T)
    local function Redraw() if ns.PlannerMapRedraw then ns.PlannerMapRedraw() end end
    local line = K.SwitchRow(G, "map", "plannerMapLine", "The route on the map", "The route's stops, numbered, and the line between them on the world map.",
        function() return ns.db.plannerMapLine ~= false end, function(v)
        ns.db.plannerMapLine = v
        Redraw()
    end)
    local hubs = K.SwitchRow(G, "map", "plannerMapHubs", "Quest areas on the map", "A mark on each area with quests the planner found, brighter where the experience comes faster.",
        function() return ns.db.plannerMapHubs ~= false end, function(v)
        ns.db.plannerMapHubs = v
        Redraw()
    end)
    local tomtom = K.SwitchRow(G, "map", "plannerTomTom", "Use TomTom's arrow when TomTom is loaded", "The step you are on goes to TomTom's arrow instead of this add-on's.",
        function() return ns.db.plannerTomTom ~= false end, function(v)
        ns.db.plannerTomTom = v
        if ns.GuideAdvance then ns:GuideAdvance() end
    end)
    T.mapLineBox, T.mapHubsBox, T.tomTomBox = line, hubs, tomtom
    return function()
        tomtom:SetChecked(ns.db.plannerTomTom ~= false)
        line:SetChecked(ns.db.plannerMapLine ~= false)
        hubs:SetChecked(ns.db.plannerMapHubs ~= false)
    end
end

-- Batch 4: race your best, where you left off; and reading the route aloud.
local function RecordsSection(K, G, Replan, T)
    local race = K.SwitchRow(G, "records", "plannerRace", "Race your best", "The panel says how far ahead or behind you are of your fastest character's time at this level.",
        function() return ns.db.plannerRace == true end, function(v) ns.db.plannerRace = v end)
    local leftOff = K.SwitchRow(G, "records", "plannerLeftOff", "Where you left off, at login", "When you log in, a line says where you were on the route and what comes next.",
        function() return ns.db.plannerLeftOff ~= false end, function(v) ns.db.plannerLeftOff = v end)
    local SPEAK = "Each new step is read aloud as you reach it."
    local speak = K.SwitchRow(G, "speak", "plannerSpeak", "Read the route aloud", SPEAK,
        function() return ns.db.plannerSpeak ~= false end, function(v) ns.db.plannerSpeak = v end)
    T.raceBox, T.leftOffBox, T.speakBox = race, leftOff, speak
    local function Refresh()
        race:SetChecked(ns.db.plannerRace == true)
        leftOff:SetChecked(ns.db.plannerLeftOff ~= false)
        speak:SetChecked(ns.db.plannerSpeak ~= false)
        local on = ns.db.readDialog and true or false      -- (reading aloud is one switch in Accessibility; this one only narrows it)
        speak.row:SetAlpha(on and 1 or 0.6)                -- (dimmed, as a 12.3 switch whose parent is off; it can still be set)
        speak.row.desc:SetText(ns:Tr(SPEAK) .. (on and "" or ("  " .. ns:Tr("Needs reading aloud on in Accessibility"))))
    end
    Refresh()                                              -- (right from the start, not only after the first refresh)
    return Refresh
end

-- Batch 5: find a group, plan with a friend, and the plan code.
local function TogetherSection(K, G, Replan, T)
    local find = K.SwitchRow(G, "together", "plannerFindGroup", "Find a group button", "A group quest on the panel gets a button that writes a line asking for a group. It only fills your chat box: you send it.",
        function() return ns.db.plannerFindGroup ~= false end, function(v)
        ns.db.plannerFindGroup = v
        if ns.GuideRedraw then ns:GuideRedraw() end
    end)
    local function DrawChannel(b)
        local name = ns.db.plannerLFGChannel
        if type(name) ~= "string" or name == "" then name = ns:Tr("Chat box") end
        b.text:SetText(string.format(ns:Tr("Find a group in: %s"), name))
    end
    local channel = K.ButtonRow(G, "together", "Find a group in: %s", "Where that line goes: your chat box's current channel, or a channel you have joined.", function(b, button)
        local list = { "" }
        for _, name in ipairs(ns.PlannerLFGChannels and ns.PlannerLFGChannels() or {}) do list[#list + 1] = name end
        local at = 1
        for i, name in ipairs(list) do if name == (ns.db.plannerLFGChannel or "") then at = i end end
        at = (button == "RightButton") and ((at - 2) % #list + 1) or (at % #list + 1)
        ns.db.plannerLFGChannel = list[at]
        DrawChannel(b)
    end, true)
    channel.row.tipTitle = "Find a group button"
    local ask = K.SwitchRow(G, "together", "plannerDuoAsk", "Let friends ask to plan with you", "A friend with Fantasy Glass UI can ask to plan one route for you both. You are always asked first. Only your friends, your guild and your group can ask, once in 5 minutes each.",
        function() return ns.db.plannerDuoAsk ~= false end, function(v) ns.db.plannerDuoAsk = v end)
    local start = K.ButtonRow(G, "together", "Plan with a friend", "One route for you and your target or the one other player in your party: the same quests, in the same order.", function()
        if ns.PlannerDuoStart then ns:PlannerDuoStart() end         -- (your target, your one party member, or it says how)
    end)
    local share = K.ButtonRow(G, "together", "Share plan", "Turns the route you are following into a plan code to copy.", function()
        if ns.PlannerCodeFollowing and ns.PlannerCodeFollowing() then ns:PlannerSharePlan() end
    end)
    T.findGroupBox, T.findGroupChannel, T.duoAskBox, T.duoButton, T.sharePlanButton = find, channel, ask, start, share
    return function()
        find:SetChecked(ns.db.plannerFindGroup ~= false)
        DrawChannel(channel)
        ask:SetChecked(ns.db.plannerDuoAsk ~= false)
        local can = ns.PlannerCodeFollowing and ns.PlannerCodeFollowing() and true or false   -- (greyed, and says why, while the planned guide is not the one you follow)
        share:SetAlpha(can and 1 or 0.45)
        if can then share:Enable() else share:Disable() end
        ns:ButtonTip(share, not can and "Follow the planned route to share it" or nil)
    end
end

-- The settings, built on `page` (a sheet, or any frame): returns T, with T.rows (its rows), T.Layout(w)
-- and T.Refresh (page.Refresh too); page.contentHeight is the height they take. nil when the options
-- folder, which holds the rows, cannot load.
function ns.BuildPlannerSwitches(page)
    if not ns.GuideRowKit and ns.LoadOptions then ns:LoadOptions() end
    local K = ns.GuideRowKit
    if type(K) ~= "table" then return nil end
    local T = {}
    local live = CreateFrame("Frame", nil, page)
    live:SetPoint("TOPLEFT", 0, 0)
    live:SetSize(SHEET_W, 400)
    T.live = live
    local G = K.NewRows(live, GROUPS, SHEET_W)
    T.rows = G
    -- Changing a setting plans again, while you follow the plan (PlannerReplan says no otherwise).
    local function Replan() if ns.PlannerReplan then ns:PlannerReplan("settings") end end
    local refreshes = {}
    for _, section in ipairs({ GroupSection, SwitchesSection, PaceSection, MapSection, RecordsSection, TogetherSection }) do
        local refresh = section(K, G, Replan, T)
        if type(refresh) == "function" then refreshes[#refreshes + 1] = refresh end
    end
    -- each row in its group, in the order the group lists them
    for sec, fields in pairs(ORDER) do
        for i, field in ipairs(fields) do
            local row = T[field] and T[field].row
            if row then row.sec, row.seq = sec, i end
        end
    end
    T.Layout = function(w)
        local height = K.LayRows(G, w, 0)
        page.contentHeight = height
        if page.area then page.area:SetContentHeight(height) end
        return height
    end
    T.Refresh = function()
        for _, row in ipairs(G.list) do if row.Sync then row.Sync() end end
        for _, refresh in ipairs(refreshes) do refresh() end
        T.Layout(G.width)
    end
    page.Refresh = T.Refresh
    T.Refresh()
    return T
end

------------------------------------------------------------------------------------------
-- The keys: with "Move through the settings with the keyboard" on, Tab and Down go to the next
-- button or row, Shift+Tab and Up to the one before, Space and Enter use it, Left and Right step a
-- choice or a slider (as in the settings window). Every other key goes on to the game (Esc closes
-- the window), and in a fight every key does.
------------------------------------------------------------------------------------------
local function KeyList(f)
    local list = {}
    for _, b in ipairs(f.topButtons) do
        if b:IsShown() ~= false then list[#list + 1] = { key = b.navKey, frame = b, button = b, noStep = true } end
    end
    for _, row in ipairs(f.T and f.T.rows.shown or {}) do
        if row.navKey and (row.switch or row.button) then
            list[#list + 1] = { key = row.navKey, frame = row, switch = row.switch or nil, button = row.button or nil, noStep = row.suiNoStep }
        end
    end
    return list
end
local function Focus(f, i)
    local list = KeyList(f)
    if #list == 0 then f.focusRing:Hide(); f.nav.at, f.focusedKey = nil, nil; return nil end
    i = ((i - 1) % #list) + 1
    local item = list[i]
    f.nav.at, f.focusedKey = i, item.key
    f.focusRing:ClearAllPoints()
    f.focusRing:SetPoint("TOPLEFT", item.frame, "TOPLEFT", -3, 3)
    f.focusRing:SetPoint("BOTTOMRIGHT", item.frame, "BOTTOMRIGHT", 3, -3)
    f.focusRing:Show()
    if item.frame ~= item.button or not item.noStep then                 -- (a row: scrolled to)
        local top, mine = f.sheet:GetTop(), item.frame:GetTop()
        if Num(top) and Num(mine) then f.area:ScrollToShow(top - mine - 12, (Num(item.frame:GetHeight()) or 40) + 24) end
    end
    return item.key
end
local function Use(f, step)
    local list = KeyList(f)
    local item = f.nav.at and list[f.nav.at]
    if not (item and item.key == f.focusedKey) then return false end
    if step then                                                         -- Left / Right
        if item.button and not item.noStep then
            local click = item.button:GetScript("OnClick")
            if click then click(item.button, step < 0 and "RightButton" or "LeftButton") end
            return true
        end
        return false
    end
    if item.switch then item.switch:Click(); return true end
    if item.button then
        local click = item.button:GetScript("OnClick")
        if click then click(item.button, "LeftButton") end
        return true
    end
    return false
end
local function KeyPress(f, key)
    if not (ns.db and ns.db.keyNav) then f.focusRing:Hide(); f.nav.at, f.focusedKey = nil, nil; return false end
    if key == "TAB" or key == "DOWN" or key == "UP" then
        local back = (key == "UP") or (key == "TAB" and IsShiftKeyDown and IsShiftKeyDown())
        Focus(f, (f.nav.at or (back and 1 or 0)) + (back and -1 or 1))
        return true
    elseif key == "SPACE" or key == "ENTER" then
        return Use(f)
    elseif key == "LEFT" or key == "RIGHT" then
        return Use(f, key == "LEFT" and -1 or 1)
    end
    return false
end

------------------------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------------------------
local Refresh
local function Build()
    if W then return W end
    local f = CreateFrame("Frame", NAME, UIParent, ns.template)
    ns:SetLook(f, "settings")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "window", 1)
    ns:Paint(f, "SetBackdropBorderColor", "@rim", 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    ns:KeepPlace(f, "Planner")
    local listed = false
    for _, n in ipairs(UISpecialFrames) do if n == NAME then listed = true end end
    if not listed then tinsert(UISpecialFrames, NAME) end
    if ns.After then ns:After(0, function() if ns.StarcutWindow then pcall(ns.StarcutWindow, f) end end) end   -- (the Starcut corner cut, as the settings window)
    W = f
    ns.plannerWindow = f
    f.nav = { at = nil }                                                    -- (the keys: the place in the list of what they reach; f.focusedKey is its key)
    f.drawn = { summary = {}, plan = "", stop = false, riding = false }    -- (what was drawn last: the summary's lines, the plan button's words, Stop and Save for riding shown)
    f.Refresh = function(light) Refresh(light) end
    -- the header: the title, How the planner works, and X
    local title = ns:NewText(f, 16, "LEFT", true)
    title:SetPoint("TOPLEFT", 18, -18)
    title:SetText(ns:Tr("Route planner"))
    ns:Paint(title, "SetTextColor", "text")
    local close = ns:CreateButton(f, "X", 28, 28, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -16, -16)
    f.introButton = ns:CreateButton(f, "How the planner works", 170, 24, function()
        if ns.PlannerIntro then ns:PlannerIntro(1) end
    end)
    f.introButton:SetPoint("RIGHT", close, "LEFT", -8, 0)
    f.introButton.navKey = "planner:intro"
    -- the summary
    f.lines = {}
    for i = 1, SUMMARY_LINES do
        local fs = ns:NewText(f, 13, "LEFT")
        fs:SetPoint("TOPLEFT", 18, SUMMARY_TOP - (i - 1) * SUMMARY_LINE_H)
        fs:SetWidth(WIDTH - 36)
        ns:Paint(fs, "SetTextColor", (i == 1) and "text" or "dim")
        f.lines[i] = fs
    end
    -- the buttons
    f.planButton = ns:CreateButton(f, "Plan my route", 130, 24, function()
        local st = ns.GuideState and ns.GuideState()
        if type(st) == "table" and st.name == ns.GUIDE_PLANNED then ns:PlannerReplan("again")
        elseif ns.GuideOnTrip and ns.GuideOnTrip() then ns:GuideFollow(ns.GUIDE_PLANNED)   -- (a trip: it ends, and the plan is made, as the Guides list does)
        elseif ns.PlannerStart then ns:PlannerStart() end
        Refresh()
    end)
    f.planButton:SetPoint("TOPLEFT", 18, BUTTONS_Y)
    f.stopButton = ns:CreateButton(f, "Stop", 80, 24, function()
        if ns.GuideOnTrip and ns.GuideOnTrip() and ns.GuideEndTrip then ns:GuideEndTrip("stop")   -- (a trip: Stop ends it and the
        elseif ns.GuideStop then ns:GuideStop() end                                              -- plan that waited comes back, as the panel's Stop this trip)
        Refresh()
    end)
    f.stopButton:SetPoint("LEFT", f.planButton, "RIGHT", 8, 0)
    f.goldButton = ns:CreateButton(f, "Ways to make gold", 150, 24, function()
        if ns.GoldOpen then ns:GoldOpen() end
    end)
    f.goldButton:SetPoint("LEFT", f.stopButton, "RIGHT", 8, 0)
    f.ridingButton = ns:CreateButton(f, "Save for riding", 140, 24, function()
        if ns.GoldOpen then ns:GoldOpen({ goalName = "mount" }) end
    end)
    f.ridingButton:SetPoint("LEFT", f.goldButton, "RIGHT", 8, 0)
    f.planButton.navKey, f.stopButton.navKey, f.goldButton.navKey, f.ridingButton.navKey = "planner:plan", "planner:stop", "planner:gold", "planner:riding"
    f.topButtons = { f.planButton, f.stopButton, f.goldButton, f.ridingButton, f.introButton }
    -- the settings
    f.area, f.sheet = ns:ScrollArea(f, SHEET_W, HEIGHT + SWITCHES_Y - 18)
    f.area:SetPoint("TOPLEFT", 18, SWITCHES_Y)
    f.T = ns.BuildPlannerSwitches(f.sheet) or { rows = { shown = {}, list = {} }, Layout = function() return 0 end, Refresh = function() end }
    local T = f.T
    T.planButton, T.stopButton, T.goldButton, T.ridingButton, T.introButton = f.planButton, f.stopButton, f.goldButton, f.ridingButton, f.introButton
    -- the keys
    f.focusRing = CreateFrame("Frame", nil, f, ns.template)
    f.focusRing:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 2 })
    ns:Paint(f.focusRing, "SetBackdropBorderColor", "@accent", 1)
    f.focusRing:SetFrameLevel((f:GetFrameLevel() or 1) + 20)
    f.focusRing:Hide()
    if f.EnableKeyboard then f:EnableKeyboard(true) end
    if f.SetPropagateKeyboardInput and not InCombatLockdown() then pcall(f.SetPropagateKeyboardInput, f, true) end
    f:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then                                       -- (the game owns the keys in a fight: the window lets go of them,
            pcall(self.SetPropagateKeyboardInput, self, true)            --  even when the key before the fight was one it used)
            if self.EnableKeyboard then pcall(self.EnableKeyboard, self, false) end
            return
        end
        local used = KeyPress(self, key)
        pcall(self.SetPropagateKeyboardInput, self, not used)
    end)
    -- A fight: the window stops taking keys as it starts (as the window keys do), and takes them again after it.
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            pcall(self.SetPropagateKeyboardInput, self, true)
            if self.EnableKeyboard then pcall(self.EnableKeyboard, self, false) end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if self.EnableKeyboard then pcall(self.EnableKeyboard, self, true) end
            pcall(self.SetPropagateKeyboardInput, self, true)
        end
    end)
    -- what you follow changes as you play: drawn again each second while the window shows
    local wait = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        wait = wait + (Num(elapsed) or 0)
        if wait < 1 then return end
        wait = 0
        Refresh(true)
    end)
    f:SetScript("OnHide", function(self) self.focusRing:Hide(); self.nav.at, self.focusedKey = nil, nil end)
    return f
end

-- Draw the summary and the buttons (and, unless `light`, the settings and their layout).
Refresh = function(light)
    local f = W
    if not f then return end
    local lines = ns.PlannerWindowSummary() or {}
    for i, fs in ipairs(f.lines) do fs:SetText(lines[i] or "") end
    local st = ns.GuideState and ns.GuideState()
    local following = type(st) == "table" and st.name == ns.GUIDE_PLANNED
    local onTrip = type(st) == "table" and ns.GUIDE_TRIP ~= nil and st.name == ns.GUIDE_TRIP
    local riding = RidingLine() ~= nil
    local plan = ns:Tr(following and "Plan again" or "Plan my route")
    f.planButton.text:SetText(plan)
    Shown(f.stopButton, following or onTrip)
    Shown(f.ridingButton, riding)
    f.goldButton:ClearAllPoints()                                       -- (no gap where Stop is not shown)
    if following or onTrip then f.goldButton:SetPoint("LEFT", f.stopButton, "RIGHT", 8, 0)
    else f.goldButton:SetPoint("LEFT", f.planButton, "RIGHT", 8, 0) end
    local bh = math.floor(24 * ((ns.db and ns.db.bigControls) and 1.3 or 1) + 0.5)   -- (Bigger controls: taller buttons, as on the guide panel)
    for _, b in ipairs(f.topButtons) do b:SetHeight(bh) end
    f.drawn = { summary = lines, plan = plan, stop = (following or onTrip) and true or false, riding = riding }
    if not light and f.T then f.T.Refresh()
    elseif f.T and f.T.zoneGoalDraw then f.T.zoneGoalDraw() end       -- (the zone goal can end by itself: "Zone done")
end
ns.PlannerWindowRefresh = function() if W then Refresh() end end

-- Open the window. The first open, while the tour is still to be seen,
-- shows "How the planner works" too.
function ns:PlannerOpen()
    local f = Build()
    Refresh()
    f:Show()
    if f.Raise then f:Raise() end
    if ns.PlannerIntroDue and ns:PlannerIntroDue() and ns.PlannerIntro then ns:PlannerIntro(1) end
    return f
end

ns.FolderFileDone("planner", "PlannerWindow.lua")
