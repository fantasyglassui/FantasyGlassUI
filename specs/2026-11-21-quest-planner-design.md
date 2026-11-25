# Quest planner: the guide plans your leveling route

Date: 2026-11-21 · Status: approved 2026-11-21 (reviewed twice by a builder) · Part of the quest guide, which is not released yet.

## Intent

Today the quest guide (FantasyGlassUI/Guide.lua) follows a route someone wrote, recorded or pasted: a fixed
list of steps (accept, do, turn in, goto, note, level). The planner makes the guide work the route out for
you. It looks at your quest log, asks Questie about every quest you could take, and picks the route that
gets you the most experience per hour of play. After every quest you hand in and every level you gain it
plans again, so the route stays right for where you are and what you have.

**What matters most: efficiency**, meaning the most experience per hour, with the travel counted.

## Goals

- Plan a route from: the quests in your log, the quests Questie says you can take, your level, where you
  are, and the flight points you know.
- Work hub by hub: pick up everything worth doing at a hub, do it in one sweep, hand it in, move on.
- Use flight paths when flying beats running, and route you to learn new flight points when that pays off.
- Look across both continents: move you to the best zone for your level, using flights, your hearthstone,
  and boats and zeppelins.
- Let the player choose how group content is treated (Solo / When grouped / Everything).
- Replan after each quest handed in and each level gained.
- Show the plan in the guide's existing panel, with its arrow and auto-advance.

## Non-goals

- Building the gold farming advisor now: it is Part 2 below, designed in its own conversation first.
- Shipping our own quest database.
- Copying any of Questie's code or data into Fantasy Glass UI (its license is mixed: GPLv3 for some
  contributors, "all rights reserved" otherwise). We only read Questie's data in the game while it runs.
- Dungeon routes inside instances (a dungeon can be suggested, with its quests; what to do
  inside is out of scope).
- Replacing written guides: they keep working as they do today.

## Anti-goals (would make this a failure even if it works)

- A stutter or freeze while planning.
- Lua errors when Questie is missing, old, or changed by an update.
- Sending a solo player to elite or group quests while Solo is chosen (the one exception is #36, elites
  your class has already soloed, behind its own switch).
- Routing through a flight path the character does not know, or to a quest it cannot take
  (wrong faction, class, profession, reputation, or prerequisites not done).
- Presenting the quest guide as available to the public. Everything stays behind the existing unlock
  (ns:GuideUnlocked) and its "coming soon" page.

## Constraints

- WoW Forever only (interface 16001, game type "camelot"). Every function and event used must pass
  tests/forever_audit.py (the test_forever_api test); `luacheck . -q` must stay at 0 warnings;
  tests/smoke.py must say "errors: no errors" in both modes.
- Add-ons are restricted in combat on Forever: no planning in combat (pause at PLAYER_REGEN_DISABLED,
  resume after), and nothing that needs COMBAT_LOG_EVENT_UNFILTERED.
- Planning work is spread across frames with a small time budget per frame (ns:Every / OnUpdate slices),
  never one long loop.
- Every phrase the player sees is translated into all 9 languages (add_tr.py), like the rest of the add-on.
- Questie is an optional dependency (## OptionalDeps: Questie in the TOC).

### What Questie gives us (checked against Questie's source, Questie_Forever.toc, v12.11.1)

- Questie ships a Forever build. Its official API (Questie.API) only offers RegisterOnReady,
  RegisterForQuestUpdates and nameplate icons; it does **not** expose the quest database.
- So we read its internals, read-only, through its module loader:
  - `QuestieLoader:ImportModule("QuestieDB")`: `QuestieDB.GetQuest(id)` returns name, level,
    requiredLevel, startedBy / finishedBy (NPC, object, item), objectives, preQuestSingle / preQuestGroup,
    exclusiveTo, nextQuestInChain, requiredRaces / Classes / Skill / MinRep, specialFlags (repeatable,
    event), zoneOrSort, and so on. `QuestieDB.IsDoable(id)` says whether this character can take it.
    `QuestieDB.QueryNPCSingle(id, key)` gives NPC spawns (zone and coordinates).
  - `QuestieLoader:ImportModule("QuestXP")`: `QuestXP:GetQuestLogRewardXP(questId)` gives the
    experience a quest gives at your level.
  - Wait for `Questie.API.RegisterOnReady` before reading anything.
- The TOC carries `## X-QuestieDB-Contract: 4`. The planner reads it (C_AddOns.GetAddOnMetadata) and
  every internal call goes through pcall. If the contract is not one we know, or a call fails, the
  planner says "Questie changed; planning from your quest log only" and falls back (below).

## Approaches considered

- **A. A live planner in the game that reads Questie. Chosen.** Always current, every zone, nothing
  to ship, no license problem. Costs: needs Questie installed, and a Questie update can move what we read
  (handled by the contract check and fallback).
- **B. Ship our own quest data.** Works without Questie, but the data cannot be taken from Questie, so it
  means gathering it for every zone and keeping it current, and several MB more to download. Rejected.
- **C. Pre-planned routes shipped as written guides.** Simplest, but cannot adapt to your quest log,
  flight points or group choice, which is the point. Rejected.

## The design

### Starting it

- `/fgui guide plan` and a "Plan my route" button on the guide list start the planner; the panel title
  says "planned" instead of a guide's name. Following a written guide (`/fgui guide <name>`) stops it,
  and the reverse.
- The plan is turned into ordinary guide steps (accept / do / turnin / goto / note / level / hearth / fly,
  which Guide.lua already has) plus new kinds, so the panel, arrow and auto-advance in Guide.lua do the
  following. Every stop the planner makes is a step kind, so it round-trips through ns:GuideSave (#9).
  Old guide lines keep parsing as they do today (`fly | text` stays valid; `fly <node> | <name>` adds the
  node, from which "done" is worked out).
  - `fly <node> | <destination name>`: done when you land there (or are near it).
  - `learnflight <node> | <name>`: done when that flight point becomes known.
  - `sail <crossing> | <name>`, `bind <inn> | <name>`: see "How far it looks".
  - `train | <trainer>` (class, profession and riding trainers), `vendor | <vendor>` (sell, repair,
    supplies, the mount vendor), `mail | <mailbox>`: done when that window closes.
  - `explore | <area>`, `gather | <node>`: done when the area is discovered / the node gathered or passed.

### What it can choose from

- Quests in your log (always candidates; already "picked up").
- Quests Questie says you can take now: IsDoable, not repeatable, not an event, not hidden, and within
  a level window round you (proposal: quest level from your level − 4 to your level + 2; quests lower
  than that give little experience and are dropped; a field the builder may tune).
- Quests whose prerequisites you would finish on this route (chains), so a follow-up can be planned.

### Group content (the player decides)

A setting on the Guide tab, "Group quests": **Solo** (default) leaves out elite quests, group quests and
dungeon quests; **When grouped** includes them while you are in a party; **Everything** always includes
them. Which quests count comes from the game's quest tags when the quest is in the log
(C_QuestLog.GetQuestTagInfo) and from Questie's data otherwise. When something is left out, the panel
shows one line: "Skipped: 2 group quests (Solo is on)".

### How it judges a route: experience per hour

- **Experience**: QuestXP:GetQuestLogRewardXP for each quest; for quests in the log without Questie data,
  the game's GetQuestLogRewardXP.
- **Time** = travel + doing the objectives.
  - Travel within a continent: straight-line distance between points on the world map, at the character's run speed
    (mounted speed when the character has a mount), or a flight or the hearthstone when that is faster.
    Between continents: a boat or zeppelin crossing (see "How far it looks").
  - Doing: an estimate per objective (kills, items to collect, places to go), based on its count and how
    spread out its spawn points are. The constants are the builder's call.
  - **It learns from you**: it records how long each objective and each quest actually took you, and
    after a few quests scales its estimates to your pace (saved per character).
- **Chains** add the value of the follow-up quests a quest unlocks, discounted because they are later.
- **Hubs**: quest givers and hand-ins close together (proposal: within ~150 yards on the same map) form
  a hub. A route is a sequence of hub loops: pick up at the hub, do the objectives in a sweep ordered to
  cut travel, hand in, go on.
- **Horizon**: it plans about two hubs ahead, then plans again; it never tries to plan the whole level
  range at once.

### How far it looks: both continents (the player's choice)

The planner may send you anywhere in the world, using running, flights, your hearthstone, and boats and
zeppelins.

- **Two levels of planning**, to keep the work small:
  1. **Pick the zone.** Every few levels, or when the current zone runs dry, it scores each zone suited to
     your level (on both continents) by the experience per hour its quests offer, and subtracts the time
     to get there. The zone list and its quests are gathered once per level and cached.
  2. **Plan hubs inside the chosen zone**, as below. Only this step looks at quests one by one.
- **Moving zones** becomes steps: "Go to Arathi Highlands: fly to Refuge Pointe" or "Take the boat from
  Menethil Harbor to Theramore".
- **Boats and zeppelins**: a small table of our own (written by us, not taken from Questie) holds each
  crossing: its two docks (map and coordinates), the faction(s) that can use it, and an expected time
  that includes waiting for the ship. Like flights, the real time of each crossing you take replaces the
  estimate (saved per account). A new step kind, `sail <crossing> | <name>`, is done when you arrive on
  the far side.
- **Hearthstone**: the planner knows where you are bound (GetBindLocation, plus the inn you last set it
  at, saved per character) and its cooldown (the item's cooldown). It uses the existing `hearth` step
  when that is faster than running or flying, and may add "Set your hearthstone at <inn>" (a new step kind,
  `bind <inn> | <name>`, done when the bind location changes to it) when the plan will come back there.
- When nothing worth doing is left anywhere suited to your level, the panel says so
  ("No quests left worth the trip; grinding or a dungeon may be faster") instead of a route.

### Flight paths

- All flight points on a map come from C_TaxiMap.GetTaxiNodesForMap, readable anywhere.
- Which ones this character knows is learned when a flight master's map opens (TAXIMAP_OPENED,
  TaxiNodeGetType) and saved per character.
- Flight times: estimated from distance at first, then replaced by the real time of each flight you take
  (recorded from take-off to landing, saved per account since routes are the same for everyone of a faction).
- A trip uses a flight only when flying (with the run to the flight master and from the landing) beats
  running.
- **Learning new flight points**: when an unknown flight point is near the route, or on the way to the
  next hub, the route stops there to learn it, even when that costs a minute or two, because later
  trips get faster. Proposal: the guide takes the detour when it is under 2 minutes, or when the planner
  expects to use that point later in its horizon.

### When it plans again

After QUEST_TURNED_IN and PLAYER_LEVEL_UP (what was asked), also when a flight point is learned, when you
abandon a quest, and on "Plan again" (a button and `/fgui guide plan`). Never in combat; it waits until
the fight ends.

### Without Questie (or when Questie changed)

The planner plans from your quest log alone: it orders the quests you already have into hub loops using
the game's own quest positions (C_QuestLog / quest POIs and the waypoint the game gives), with flights.
It cannot add new quests, and the panel says so once: "Install Questie to plan new quests too."

### What the panel shows

```
Quest guide ── planned ─ Hillsbrad, level 24 → 26
▸ Fly to Southshore                (saves ~3 min)
  Accept 3 quests at Southshore    (+4,100 xp)
  Do: Crushridge Bounty, Syndicate Assassins …
  Hand in at Southshore, then run to Tarren Mill
Skipped: 2 group quests (Solo is on)
```

The first line says where the plan is and the level it expects to reach by its end. Each step can show
why it is there (xp gained, minutes saved).

### More that it does (added 2026-11-21, items 1–9)

1. **Experience from kills along the way.** A kill objective is worth its quest reward plus the
   experience of the monsters it takes, and the monsters you meet on the way. Monster levels come from
   Questie's NPC data (minLevel / maxLevel); experience per kill uses the game's usual formula by level
   difference (the builder writes it from the known formula and checks it against a few real kills, then
   it learns: actual experience per kill at each level difference is recorded per character, from
   PLAYER_XP_UPDATE outside quest hand-ins). This is part of "experience per hour" for every hub.
2. **Trainer visits.** At each level where your class has new spells (every two levels), the route adds
   "Train at <trainer>" at a hub or town it already passes that has your class trainer, or the nearest
   one if none is on the way. Trainers are found from Questie's NPC data (trainer flag and their title).
   Done when the trainer window closes. Setting to switch off.
3. **Selling and repairing.** When your bags are nearly full (proposal: 3 or fewer free slots, the same
   check "Am I ready?" uses) or your gear is under 30% durability, the next hub with a vendor (or a repair
   vendor) gets a "Sell and repair at <vendor>" step. Vendors come from Questie's NPC data (vendor / repair
   flags). Done when the merchant window closes.
4. **When quests run dry**, instead of only saying so, it suggests the best option:
   - a **dungeon** for your level, when the group setting allows (When grouped while in a party, or
     Everything), with the number of its quests you can take and where to pick them up. Dungeons come from
     a small table of our own (name, level range, entrance map and coordinates); their quests from Questie
     (quests whose zone is that dungeon).
   - a **grinding spot**: the nearest place with many monsters 0–2 levels above you, from Questie's NPC
     spawn data, with the experience per hour expected from your recorded kill rate.
   It shows the better of the two first, and both when both apply.
5. **Time to your next level**: the panel's first line adds "level 26 in ~48 min", worked out from the
   plan and your learned pace. It shows only once the pace has a few quests behind it.
6. **The best quest reward for you.** When a quest hand-in offers a choice, the reward with the upgrade
   arrow is selected for you (the arrows already exist); when none is an upgrade, the one that sells for
   the most. It only selects: you still press Complete yourself. Setting to switch off.
7. **A skip list.** Right-click a step in the panel → "Never suggest this quest". Kept per character,
   listed on the Guide tab where a quest can be taken off the list. Skipped quests are never planned and
   the plan is made again at once.
8. **The route on the map.** On the world map, a line joins the next stops of the plan (proposal: up to the
   end of the current hub loop and the trip to the next), with a small number at each stop. Drawn with the
   map tools MapExtras.lua already uses. Setting to switch off.
9. **Save as a guide.** A "Save as guide" button turns the steps planned so far into an ordinary written
   guide (ns:GuideSave, the existing text format), named by zone and levels, to follow again on another
   character or share. The new step kinds (fly, learnflight, sail, bind, train, vendor) are written in
   the same one-line format, so a pasted guide keeps them.

### Still more (added 2026-11-21, second round)

Faster leveling:

10. **Rested experience.** While you are rested (GetXPExhaustion), kills are worth double, so kill-heavy
    hubs score higher until it runs out (the planner works out where in the plan it runs out). At the end
    of a session (when you open the game menu after an hour or more of play, or `/fgui guide stop`), the
    panel suggests the nearest inn to log out at, if one is close.
11. **A tidy quest log.** The log holds 25 quests. When it has 3 or fewer free places, or a quest the plan
    wants would not fit, the panel lists the quests worth abandoning, worst first: gray quests, quests the
    planner would never pick, quests far off the route. It only suggests: you abandon them yourself.
12. **Quests that start from loot.** When Questie says a monster on the route drops an item that starts a
    quest (startedBy item, and the item's drop sources), that quest counts in the plan and the step says
    "Keep the <item> that drops here". When the item is in your bags, the step says to use it.
13. **Class quests at the right level.** Quests for your class (requiredClasses) that give something
    lasting, such as a pet, a form, a totem or a key ability, are always planned when you reach their
    level, whatever their experience, and marked as class quests in the panel. Which class quests count
    is a small table of our own (quest ids per class), because their value is not in the data.
    **When to do them**: at the level they open, the panel says "Class quest ready: <name>". Ones that
    give something you use in every fight (a pet, a form, a totem) go into the plan straight away; the
    rest are fitted in when the route passes near their start, within the next level. Long chains are
    shown with their length ("4 parts, about 25 min") so you can choose to do them now or later. The
    table marks which kind each one is.
14. **Timed and escort quests.** A timed quest (the game's quest timer, or Questie's data) is planned so
    you do it straight after accepting it, with nothing else in between. An escort quest is flagged in the
    panel ("Escort: start it when you are ready; it fails if the NPC dies") and planned as its own step.

Keeping you informed:

15. **Where you left off.** When you log in with a plan going, one line in chat (and on the panel): where
    you are in the plan, the next step, and the time to your next level. Setting to switch off.
16. **The route read aloud.** Each new step the panel moves to is said aloud in the game's voice
    (ns:Speak), and the panel can be used by keyboard like the game's windows (WindowKeys.lua: Tab between
    its buttons, Enter to press). **It only works when reading aloud is on in the Accessibility settings**
    (readDialog); a setting on the Guide tab, "Read the route aloud", on by default, lets someone who has
    reading aloud on switch it off just for the guide.
17. **Level times in your stats.** Each level gained records the time it took (played time) and the
    experience per hour, per character. `/fgui stats` (Lifetime.lua) gets a "Levels" part: your fastest and
    slowest levels, and the average; the run log gets a line per level.

Smarter about you (third round):

18. **Plan for the time you have.** "How long can you play?" (a button on the panel, or
    `/fgui guide plan 30` for 30 minutes). The plan is cut so it ends on time somewhere useful (an inn,
    a flight point or a town), never halfway through a hub, and the last step says "Good place to stop".
    Without a time, it plans as before.
19. **Learn from deaths.** Two deaths in the same hub (within a level) mark that hub too hard for now:
    it is planned a level or two later instead, and the panel says why ("Moved: you died twice here").
    Deaths are recorded with where they happened (PLAYER_DEAD); the mark clears after two levels.
20. **Learn from your alts.** The real time of each quest (accept to hand-in, less time away from the
    keyboard and in towns) is kept for the whole account. A quest's time estimate blends that record with
    the formula, so a quest that took your first character far longer than expected scores lower for the
    next one. Per-account, keyed by quest id.
21. **Rewards count as value.** A quest whose reward is an upgrade for you (the existing upgrade arrows'
    test, run on Questie's reward items or the game's reward info once the quest is in the log) scores
    higher: an upgrade is worth a share of experience equal to the time it is expected to save (proposal:
    a fixed bonus per item level gained; the builder tunes it).

Goals and gathering:

22. **Reputation goals.** On the Guide tab, pick factions you want ("Reputation I want: Stormwind,
    Argent Dawn ..."), optionally with the standing you are aiming for. Quests that give that reputation
    (Questie's reputationReward) get extra weight until you reach it. The panel shows progress
    ("Argent Dawn: 2,300 to Honored") when such a quest is in the plan.
23. **Gather on the way.** With Herbalism or Mining (and Skinning for monsters you kill anyway), the route
    notes nodes near the path it already takes that your skill can gather ("3 Peacebloom on the way"),
    from Questie's object spawn data where it has them, otherwise from nodes the add-on has seen you
    gather (recorded per account). It never makes a detour of more than ~20 seconds for a node. What you
    gather is recorded, which the gold advisor (Part 2) can build on.

More speed (fourth round):

24. **Save hand-ins to level in town.** When a hand-in would take you to a level where your class trains
    new spells, and the plan reaches a town with your trainer soon (proposal: within ~5 minutes), the
    planner holds that hand-in (or one or two) and hands them in at the town, so the level and the
    training happen in one stop. Only when holding costs no extra trip.
25. **Experience from exploring.** Unexplored areas within a few seconds of the path (the game's map
    exploration info, readable for each map) are put on the path, since discovering them gives experience.
26. **Supplies at the vendor stop.** Hunters (arrows or bullets for their weapon) and classes that drink
    (mana users) and everyone who eats: when the plan's next hour would run you low (counted from your
    bags and how fast you have used them), the existing vendor stop adds "Buy 400 arrows" or "Buy 20 water",
    choosing the best your level can use. The vendor stop is added for this alone when none is planned.
27. **Talent points.** At each level with an unspent talent point, the panel says "1 talent point to spend"
    with a button that opens your build (the add-on's talent builds).

Choice and feel:

28. **Speed or story.** A setting with two styles. **Speed** is everything above. **Story** keeps each
    zone's quest chains whole and in order (it does not drop a chain's low-experience parts, and plans
    a zone's main chain before side quests), while still planning the travel, flights and hubs well. The
    panel says which style is on.
29. **Preview the next hour.** Before following a plan (and on a "Preview" button any time), one page
    shows: the stops in order, the experience, the level you would reach, the flights and crossings, and
    anything skipped and why. "Follow" starts it; "Plan again" goes back to the settings that change it
    (style, group quests, time you have).
30. **A sound when a step is done.** A soft chime (a game sound, PlaySound) as each step completes.
    Setting: on (default) / off. Also shown as a caption when captions are on (Accessibility).

Groups (nothing sent for you):

31. **Find a group.** When the plan reaches a group or elite quest (and the group setting allows it), a
    button puts a ready-made line in your chat box ("LFG <quest name>, <zone>") for you to send yourself,
    in the channel you pick. The add-on never sends it.

Seeing the plan (fifth round):

32. **Zones scored on the map.** On the world map, each hub has a mark coloured by its experience per hour
    for you now (bright for the best, dim for the worst; with marks as well as colour when a colour-vision
    setting is on), and its number on hover. Clicking a hub asks "Plan from here?" so you can pick a spot
    yourself. Setting to switch off.
33. **"Why this?"** Right-click a step → "Why this?": a small page with the numbers behind it (experience,
    travel, time to do, experience per hour, and the best thing it beat and by how much).
34. **Your own balance.** Three sliders on the Guide tab: **Speed**, **Safety** and **Story**. The two styles
    (#28) become presets of these (Speed: 100/0/0, Story: 40/0/100, with safety at your choice); moving a
    slider makes the style "Custom". **Story as a rule and a weight**: at 100 the #28 rules apply in full
    (chains kept whole and in order); below 100 it is a weight, a bonus for keeping chains together and
    for a zone's main chain, growing with the slider. The Settings line "Style: Speed / Story" is the
    preset picker for these sliders, not a separate setting. Safety weighs: monsters above your level near the path, elites near
    the path, escort quests, and hubs where you died (#19): with Safety up, the plan goes round them even
    when it costs time.

Playing with others:

35. **Duo mode.** "Plan with a friend": the two add-ons talk by add-on message (the same way talent
    builds are sent; outside instances only, as the game requires). **The plan fits both of you**: the
    friend's add-on sends their level, quest log (ids and progress), known flight points, hearthstone inn
    and what they can take (faction, class; Questie's IsDoable answered on their side), and the leader's
    planner uses only quests and travel both can do. The plan is sent to the friend; both follow the same
    steps and each sees the other's progress on the panel ("Mira: done"). The plan waits at hand-ins and
    flights until both are ready. Replans happen on the leader's side after either player's hand-in or
    level, with the friend's latest state. If the friend has no add-on, or no answer comes, it says so and
    plans for you alone.

Goals:

37. **Finish the zone.** A goal on the Guide tab: "Finish <zone>". The planner plans every quest in it that
    you can do (still with the best order and travel), and shows "Zone: 34 of 52 quests". Group quests
    follow the group setting. When the zone is done, it says so and goes back to leveling.
38. **Catch me up.** When you log in after 14 days or more away (proposal), a short page before the plan:
    where you were, what is in your log (and which quests the plan still wants), your level and pace,
    what is new in the add-on since then, and "Plan my route".

Wellbeing:

39. **Break reminders.** Off by default (Guide tab, or the Calm part of Accessibility). After a time you
    choose (default 2 hours), a gentle line when the plan reaches its next stopping place ("You've been
    playing 2 hours; this is a good place to stop"). Never in combat, never mid-hub, at most once an hour.

Sixth round:

40. **Profession training on the way.** When a profession's skill reaches its current cap (for example
    75/75), the route adds a stop at that profession's trainer when it passes a town with one (Questie's
    NPC data: trainer flag and title), or says where the nearest is. Done when the trainer window closes.
41. **Mail on the way.** When mail is waiting (HasNewMail) and the route passes a mailbox (Questie's object
    data, or mailboxes the add-on has seen you use), a quick "Check your mail" stop is added, only when it
    costs under ~20 seconds.
42. **Mount reminder.** At the level your character can ride, a stop at your race's mount vendor (and the
    riding trainer) is added. If you can't afford it yet, the panel shows how much gold you are short
    ("Riding: 38g to go"), and later the gold advisor (Part 2) can take it from there.
43. **Race your best.** The panel shows how you are doing against your fastest character at the same level
    ("ahead by 4 min" / "behind by 2 min"), from the level times (#17). Setting: on / off (default off, so
    it never pressures anyone who didn't ask).

Your plan on the website:

44. **A plan code.** "Share plan" turns the plan (its steps, the places on them, and your level range) into
    a line of text, like the theme codes. Pasting it on a new page of fantasyglassui.com (/plan/) shows:
    - **the route drawn as a map**: each zone as a labelled panel with the stops placed by their
      coordinates, numbered, joined by the path, flights and crossings marked. The site draws this itself;
      it does not show Blizzard's map art.
    - **a checklist** of the steps you can tick off on your phone while you play (kept in that browser only).
    - the totals: experience, time, levels, flights.
    Nothing is sent anywhere: the code is copied and pasted by you, and the page reads it in the browser.
    The page is built and translated like the rest of the site (site-src/build_site.py, the 9 languages) and is
    marked as part of the quest guide, so it is not linked from the site until the guide is released.

### Part 2: the gold farming advisor (to be designed before it is built)

Wanted, and to be built after the planner; it needs its own design conversation first, since only the idea
is settled. What is known:

- It suggests where and how to make gold, the way the planner suggests where to level. It cannot use an
  online AI (add-ons have no internet); it is "smart" by using what the add-on already knows about you.
- It can build on: farming sessions and "farming by zone" (Farming.lua: gold and loot per hour, by zone),
  auction prices seen at the auction house (Economy.lua), your professions and skill, your level, and
  Questie's data on where monsters and gathering spots are.
- It reuses the planner's travel model (flights, hearthstone, boats and zeppelins) to plan a farming run
  and the trip to it.
- Open, for that conversation: what it optimizes (gold per hour, or something else), whether it covers
  gathering, crafting for profit and auction flipping or only farming, and how it shows its suggestion.

### Settings (Guide tab)

**Later (the player, 25 Nov):** once the planner is finished it gets its own button and its own
settings window, and these switches move there, out of the add-on's settings window. Until then
they stay on the Guide tab.

**Final step after batch 5 (the player, 25 Nov: "we are trying to make it run great"):** the planner
moves into its own folder, `FantasyGlassUI_Planner`, shipped in the same package like
`FantasyGlassUI_Options`: `## LoadOnDemand: 1`, `## RequiredDeps: FantasyGlassUI`, `## OptionalDeps:
Questie`. The game loads it only when the planner is first used (its button, the guide panel's plan
button or `/fgui plan`), so players who never use it pay no memory and no Questie reading. It brings
its own button and its own settings window (in the settings window's look); its switches leave the
Guide tab. The quest guide panel itself stays in the main add-on; the planner reaches it, the theme
painting, translations and settings through the shared namespace or a small documented API. A
failure inside the planner never breaks the rest of the UI. Its own plan and a full re-test (both
smoke modes, every audit, pytest) come with it.

Decided with the player (25 Nov, 15:50–15:54):
- **Still hidden.** The folder ships in the package but stays behind the guide's unlock: no button,
  no settings, nothing loaded and nothing on the site until someone unlocks it.
- **Its button in two places:** a small "Planner" button on the quest guide panel, and one more entry
  in the add-on's minimap launcher menu. No separate floating button.
- **Its window** wears the settings window's look: the current plan's summary at the top, then the
  planner's switches grouped (group setting; stops on the way; exploring and gathering; rewards, the
  log and the inn; time, style and sliders; map; records; reading aloud). The switches leave the
  Guide tab.
- **Going public later, in its own release (13.0):** after the player and a few trusted testers have
  played it and the in-game checklists of all five batch notes are worked through and fixed. That
  release takes the unlock off and adds the changelog, a site section, CurseForge screenshots and an
  announcement.

- Group quests: Solo / When grouped / Everything.
- Learn new flight points on the way: on (default) / off.
- Show why each step is there: on (default) / off.
- Visit your trainer on the way: on (default) / off.
- Sell and repair stops: on (default) / off.
- Pick the best quest reward: on (default) / off.
- The route on the map: on (default) / off.
- Never suggest these quests: the skip list, with a way to take one off.
- Suggest an inn when you stop while rested: on (default) / off.
- Where you left off, at login: on (default) / off.
- Read the route aloud: on (default), working only while reading aloud is on in Accessibility.
- How long can you play: none (default), or a time.
- Reputation I want: a list of factions, each with the standing to reach.
- Gather on the way: on (default) / off.
- Save hand-ins to level in town: on (default) / off.
- Explore on the way: on (default) / off.
- Buy supplies at the vendor stop: on (default) / off.
- Style: Speed (default) / Story.
- Sound when a step is done: on (default) / off.
- Hubs on the map: on (default) / off.
- Speed / Safety / Story sliders (set by the style presets).
- Goal: level up (default) / finish a zone.
- Break reminders: off (default) / after a time you choose.
- Profession training stops, mail stops, mount reminder: on (default) / off each.
- Race your best: off (default) / on.

### Tests

- smoke.py gets a fake Questie (QuestieLoader, QuestieDB, QuestXP, Questie.API) with a small world:
  a few hubs in two zones on two continents, a chain, an elite quest, a group quest, two flight points and
  a boat. It checks the route picked, that Solo leaves out group quests, that a known flight is used and
  an unknown one is learned, that the hearthstone and the boat are used when faster, that
  replanning happens after a hand-in, and that a missing or changed Questie falls back without errors.
- The extras: kill experience changes which hub wins; a trainer step appears at a training level; a
  vendor step appears with full bags; a dungeon or grinding spot is suggested when quests run dry; the
  upgrade reward is selected; a skipped quest is never planned; the map line is drawn; a saved guide
  parses back into the same steps.
- The second round: rested experience changes the winning hub; abandon suggestions appear with a full log;
  a quest from loot is counted; a class quest is planned regardless of experience; a timed quest is done
  straight after accepting; the login line appears; a step is spoken only when reading aloud is on; a level
  time is recorded and shows in /fgui stats.
- The third round: a 30-minute plan ends at a stopping place; two deaths move a hub later; an account
  quest time changes a score; an upgrade reward raises a quest; a chosen reputation raises its quests;
  a gathering note appears for a node near the path and none for one far off it.
- The fourth round: a held hand-in is handed in at the trainer town; an unexplored spot near the path is
  added; a supply line appears when arrows run low; the talent line appears; Story keeps a chain whole;
  the preview lists the same stops the plan follows; the chime plays; the group line goes into the chat
  box and nothing is sent.
- The fifth round: hubs on the map carry the planner's numbers; "Why this?" shows the step's numbers;
  Safety up routes round a dangerous hub; a duo plan arrives and progress shows both ways (and nothing is
  sent inside an instance); a solo elite is recorded and then planned; a zone goal plans every quest in
  the zone; the catch-up page shows after a long break; the break line waits for a stopping place.
- The sixth round: a capped profession adds a trainer stop; waiting mail adds a mailbox stop only when it
  is cheap; the mount stop and the gold-short line appear at riding level; the race line compares with the
  best character's level time; a plan code round-trips (made in the game, read back by the same parser the
  website uses, checked in tests with a fixed code).
- The site is built by site-src/ (make_i18n.py, build_site.py) into docs/; its plan reader is
  JavaScript. The same fixed plan codes are tested on both sides: by smoke.py in the add-on, and by a
  small Node check of the page's reader.
- The planner runs in both smoke modes (combat values readable and secret) with no errors.

## Build order (the player's choice: core first, then batches)

Each batch is its own release, built and tested (smoke.py both modes, luacheck, the Forever audit) before
the next starts. Everything stays behind the guide's unlock.

1. **The core planner**: Questie reading with the contract check and fallback; candidates; experience per
   hour with kill experience (#1) and learned pace; hubs; zone picking on both continents; flights and
   learning flight points; hearthstone and bind; boats and zeppelins; the group setting; replanning; the
   panel with the new step kinds; the basic settings. Built so later batches plug in: a scoring term per
   feature, a stop maker per stop kind, a hook per event.
2. **Stops on the way**: trainers (#2), selling and repairing (#3), supplies (#26), talent points (#27),
   held hand-ins (#24), exploring (#25), gathering (#23), profession training (#40), mail (#41), the mount
   reminder (#42).
3. **Smarter choices**: dry-zone suggestions (#4), rewards (#6, #21), skip list (#7), rested experience
   (#10), the quest log (#11), quests from loot (#12), class quests (#13), timed and escort quests (#14),
   deaths (#19), alts (#20), reputation goals (#22), soloed elites (#36).
4. **Seeing and feel**: time to level (#5), the map line (#8), save as guide (#9), where you left off
   (#15), read aloud (#16), level times (#17), the time you have (#18), speed or story and the sliders
   (#28, #34), preview (#29), the chime (#30), hubs on the map (#32), why this (#33), finish the zone (#37),
   catch me up (#38), break reminders (#39), race your best (#43).
5. **With others and outside the game**: find a group (#31), duo mode (#35), the plan on the website (#44).

Then Part 2, the gold farming advisor, designed first.

## Left to the builder

- The file layout (proposal: a new Planner.lua after Guide.lua in the TOC), and how the steps are made.
- The hub clustering method and the route search (for example: greedy by experience per hour, then a
  little local improvement), within the frame budget.
- The time constants for objectives and the frame budget.
- Exactly how a "fly" or "learnflight" step is detected as done.

## Saved data

- Per character: known flight points, the inn your hearthstone is set at, the learned pace factor,
  experience per kill by level difference, the skip list, the time and experience per hour of each level,
  the planner's settings.
- Per account: recorded flight and crossing times, real quest times, gathering nodes seen.
- Per character also: deaths by hub, reputation goals, the time-to-play choice, the slider values,
  the zone goal, the last login time.
- Per account also: elites soloed, by class and level difference.

## Calls made in writing this up (the builder's or Claude's, not the player's)

- Level window for candidates: your level − 4 to + 2.
- Hub size: givers within ~150 yards on the same map.
- Planning horizon: about two hubs ahead inside a zone; the zone is re-picked every few levels or when it
  runs dry.
- Learn a new flight point when the detour is under 2 minutes, or when the plan will use it.
- Default group setting: Solo.
- Crossing times include an average wait for the ship.
- Sell and repair when 3 or fewer bag slots are free or gear is under 30%.
- Grinding spots: monsters 0–2 levels above you.
- The map line covers the current hub loop and the trip to the next.
- Reward picking only selects; it never presses Complete.
- Abandon suggestions show at 3 or fewer free log places; the add-on never abandons a quest itself.
- Class quests that count come from a small table of our own.
- The inn suggestion shows after an hour or more of play.
- Two deaths in one hub within a level make it "too hard for now"; the mark clears after two levels.
- Gathering detours are at most ~20 seconds.
- "Catch me up" shows after 14 days or more away; break reminders default to 2 hours, at most once an hour.
- Race your best is off by default.
- The website draws its own zone panels instead of using Blizzard's map art, and the /plan/ page stays
  unlinked until the quest guide is released.
- Hand-ins are held only when the trainer town is within ~5 minutes on the plan and no extra trip is needed.
