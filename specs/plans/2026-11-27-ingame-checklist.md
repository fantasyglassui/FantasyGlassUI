# 13.0 in-game checklist (test session, 27 Nov)

One list for the test session on a real WoW: Forever client. It gathers every "check in game" item from the
build reports (`.superpowers/sdd/`, every batch folder and the polish-* files) and the batch notes
(`specs/plans/*notes*`). Duplicates are merged. Items that only made sense while the guide was locked are left out
or turned into their 13.0 form. Each group is ordered most important first.

Have ready: one character on a fresh install with no saved file, one tester's character with a saved file from
before 13.0, Questie loaded (and once without it), TomTom for one check, and a second account for the duo.

## 1. The 13.0 basics (no lock)
- [ ] A tester's saved file from before 13.0 loads with everything kept: profiles, written guides, the guide's
      place in a route (guideState), the planner's records, the gold records, the quest-id pairs
      (`plannerQuestIds`, `plannerQuestIdTitles`) and the hand-ins.
- [ ] A fresh character: no error at login; the Guide tab shows its controls (no "Coming soon" page); the guide's
      settings are in the profile like every other setting.
- [ ] `/fgui unlock` and `/fgui lock` give the usual "not a command" reply.
- [ ] The game's add-on list shows "Fantasy Glass UI - planner" and "Fantasy Glass UI - gold", with their
      tooltips; both load on demand. Does the list show the gold folder's OptionalDeps (the planner's folder
      name)?
- [ ] Key Bindings (Esc, Key Bindings, AddOns): the three keys read "Guide: next step / skip step / plan again",
      translated, from the first login. Keys bound to them before 13.0 still work. Nothing happens in combat.
- [ ] `/fgui new` shows the 13.0 note; `/fgui help` lists the "Quest guides and gold" group, and clicking a line
      puts it in the chat box.
- [ ] The first-time tour ("How the planner works"): it shows once for the account, the first time the Guide tab
      or the planner window opens, on a fresh account and on a tester's. Its four pages in the settings look, with
      the page dots, Skip, Back, Next/Done and the X; it sits over the settings window without hiding what it
      explains; with reading aloud on, each page is read; Left/Right, Enter/Space and Esc work; a fight closes it.

## 2. Quest ids: Forever's own quests ("Agitator")
- [ ] With the plan running and Questie loaded, accept "Agitator" (in the Sky Elf territory):
  - the Accept step ticks;
  - the panel shows the log's own words, e.g. "Agitators slain: 3/8";
  - after the hand-in the planner never offers it again, after a `/reload` too.
- [ ] The pair, with its title, is in `FantasyGlassUIDB.plannerQuestIds` and `plannerQuestIdTitles`.
- [ ] Accept a quest in the first seconds after login, before Questie is ready: no pair is saved.
- [ ] A finished objective on the panel shows the game's ready-check tick (not a box); read aloud says "done", in
      your language. Does the 4-line "now" text fit the panel with a long step text?
- [ ] A daily: after its hand-in, `handedIn[id].repeatable` is true (needs `C_QuestLog.IsRepeatableQuest` to answer
      while the quest is in the log).
- [ ] Do any of Forever's server ids collide with a Questie id of another quest? (Those are never matched, by
      design.)

## 3. Keep my route
- [ ] With Keep my route on: a level-up and a loading screen leave the route as it is.
- [ ] Abandoning a quest skips its steps; failing or skipping one does too.
- [ ] The end-of-route message appears once.
- [ ] Keep my route on, press Plan my route straight after login: the route comes once Questie is ready.
- [ ] The map's Plan from here still plans again while the route is kept.

## 4. Go trips (ways to make gold)
- [ ] Go from Elwynn to an Ashenvale herb idea: the flight, the boat, the nodes, then the levelling plan comes back
      and is planned again.
- [ ] The trip ticks step by step on the panel.
- [ ] Stop this trip from the panel's "...": the trip ends and the plan comes back.
- [ ] `/reload` in the middle of a trip: the trip is still there, and still resumes the plan after.
- [ ] Go during a duo: the friend's side says the duo ended.
- [ ] Go with "How long can you play?" set (30 minutes): the note.
- [ ] Go on a timed quest: refused.
- [ ] A trip whose last step is only a zone ends with "Stay as long as you like, then Stop this trip."; arriving
      does not end it.
- [ ] Go against the real planner context (the tests stub it): flights, the hearthstone and boats as expected.

## 5. The planner window
- [ ] `/fgui plan`, the panel's Planner button and the Tools menu's Planner all open it; `/fgui plan something`
      opens it too.
- [ ] Its look: the settings look, the Starcut corners; the 556 px rows (button and slider descriptions are
      narrower than they were on the tab: 208 and 188 px); Bigger controls on the top buttons (4 buttons at 31 px
      still fit the row).
- [ ] The keys in the window: Tab, the arrows, Space and Enter.
- [ ] The load hitch: the time from the first Planner click to the window (`/fgui perf`).
- [ ] The Speed, Safety and Story sliders' feel (step 10), and Style: Speed / Story / Custom.

## 6. The keyboard in a fight
- [ ] The planner window open: press a key it uses, then pull a mob. Your keybinds and Esc still work in the fight.
- [ ] The same with the settings window (`/fgui`).
- [ ] Are `EnableKeyboard` and `SetPropagateKeyboardInput` allowed in a fight on Forever? (Both are pcall'd; a stale
      "false" would keep the keys.)
- [ ] Tab and Enter on the guide's menu and its pages; `/fgui guide keys` opens the panel's menu with Back, Next,
      Guides and the panel actions.

## 7. The panel and the arrow
- [ ] The panel's bottom row in all nine languages: Plan again, Planner, "..." and Guides do not touch; Plan again
      is sized and cut.
- [ ] The panel's measured layout at every font scale: secondary lines wrap to two, the tooltip shows the whole
      text, the talent button is centred. Default place TOPRIGHT −290, −300, growing down; a dragged place stays.
- [ ] The motion-only hover frame does not hide the Talents button's tooltip.
- [ ] The riding line's click area ("Save for riding" opens gold with the riding goal).
- [ ] The "..." button: where it sits, the menu's size, and a click elsewhere (GLOBAL_MOUSE_DOWN) closes it.
- [ ] The step menu (right click on a planned quest step) closes on Esc and on a click elsewhere; the right-click
      area is there only on a planned quest step, so world clicks under the panel's other lines go through.
- [ ] The arrow: stacked from the top with its band and dim label at TOP 0, −345, overlapping nothing; the accent
      tint in each theme, brighter within 30 yd, one pulse on arrival, no pulse with reduced motion.
- [ ] The public arrow (`/fgui way 45 62`, a Journey waypoint) in each theme: 0.85 alpha beyond 30 yd, 1 within.
- [ ] Standing a few yards from a dock or flight master: the arrow points once with the leg's words, never pulses,
      and does not point again; with TomTom, no new waypoint every second.
- [ ] Another map: the arrow points at the flight master, the dock or the map's edge; is the edge a sensible exit
      where mountains block the way? No repeated pulse at the edge.
- [ ] TomTom on Forever: `AddWaypoint` returns a uid, `RemoveWaypoint` clears it, its arrow shows.
- [ ] Glyphs in the game's fonts (default, every lettering choice, koKR, zhCN): "→" in "Level %s → %s" and
      "Planned: %s, level %s → %s", "…" in " · planning…", "×" in "pace %.1f× the estimate". A box means the key
      must change in all 8 languages.
- [ ] The step sound when a replan resets the guide to step 1; the chime's caption ("Step done") with captions on.

## 8. A /reload, logins and the clocks
- [ ] A `/reload` in a fight while following the plan: the planner's folder loads after the fight, quietly.
      (Is `InCombatLockdown()` true at PLAYER_LOGIN after a /reload in combat? Is `IsLoggedIn()` true inside the
      PLAYER_LOGIN handler?)
- [ ] The login while following: the folder loads behind the loading screen, no hitch.
- [ ] `PLAYER_ENTERING_WORLD`'s isInitialLogin / isReloadingUi on Forever: catch-up and where-you-left-off only at
      an initial login, never a reload or a loading screen, never a character's first login; the session start
      kept across a /reload.
- [ ] The planned guide's saved name (a control character) survives SavedVariables.
- [ ] Level times: the 10 s play clock against /played across a login, a /reload and a loading screen;
      PLAYER_LEVEL_UP saves the old level; the first level after install is marked partly timed; the Levels part of
      `/fgui stats` and the run log. Race your best moves with the clock.
- [ ] Logging in at an inn stops the quest clock (PLAYER_UPDATE_RESTING); `IsResting` in an inn, a capital and a
      village; `UnitIsAFK` and PLAYER_FLAGS_CHANGED.

## 9. Planning: the route and its stops
- [ ] Questie's TOC has `X-QuestieDB-Contract: 4` (otherwise the planner always falls back to the quest log);
      Questie loading slowly gives the "still loading" line, then the quest-log plan after 30 s.
- [ ] The preview opening over the first plan after Plan my route (also when Questie was still loading); Follow
      closes it; Plan again.
- [ ] A hearth step ticks within 60 yd of where you land, and a fly step at its landing point (on a fresh plan).
- [ ] Landing from a taxi or reviving runs the queued replan; the end of a route plans again at most once a minute;
      an empty plan does not loop.
- [ ] Flights: `UnitOnTaxi` is true at PLAYER_CONTROL_LOST (otherwise flights are never timed);
      `C_TaxiMap.GetAllTaxiNodes` positions are accepted by `C_Map.GetWorldPosFromMapPos`;
      `C_Map.GetMapInfoAtPosition` on the taxi map ("Go to Arathi Highlands: fly to Refuge Pointe").
- [ ] Boats and zeppelins: the dock coordinates and area ids (150, 513, 442, 702, 35, 392, 1637, 1497, 117) and
      their names; the Undercity dock stored on the city map (1458) while the tower is in Tirisfal (1420); one boat
      and one zeppelin timed from 300 yd, under 900 s, near the defaults (270/240).
- [ ] Closing a trainer, merchant or mailbox window ticks the right step, only when it is the current one; a riding
      trainer is not your class trainer.
- [ ] Riding: 40, 100 gold, mount 20 gold; known after training, by the spell or once mounted; the mount vendor ids
      (the Skyborne races have none yet); riding skill line 633; does `GetProfessions` list riding on Forever?
- [ ] The supply item ids (arrows, bullets, water, food by level); profession caps 75/150/225/300 at 10/20/35.
- [ ] Talent points as the panel line expects (`C_ClassTalents`/`C_Traits`).
- [ ] Exploring: real unexplored spots, no map edges, reached spots stop coming back.
- [ ] Gathering: Mining and Herb Gathering casts recorded with the node's name; the herb and ore ids and ranks in
      Questie's Forever data (40 ids, 18 alternate ore ids); which Ooze Covered vein each of 123308–123310 is;
      herb alternates (1766xx)?
- [ ] A vendor or mailbox seen on one faction never shows for the other.
- [ ] Memory and frames: `collectgarbage("count")` before and after the first plan with gathering on; no hitch at
      the first plan after login (Questie's tables walked a slice at a time; a replaced table walked again).

## 10. Planning: the choices it makes
- [ ] The best reward on the real hand-in window: QUEST_COMPLETE timing, the deferred pick, the overlay on the
      reward button and the chat line; one reward, no links or hidden values select nothing.
- [ ] QUEST_REMOVED before QUEST_TURNED_IN on Forever: a hand-in is told by `IsQuestFlaggedCompleted` at
      QUEST_REMOVED (an abandoned quest is not flagged). Alts' times and soloed elites rely on it.
- [ ] A timed or escort quest that fails: the panel says to abandon it; after abandoning, the plan takes it again.
- [ ] Timed quests: `C_QuestLog.GetTimeAllowed` at QUEST_ACCEPTED (its return shape), and an alt plans it as a timed
      run before taking it.
- [ ] The starter tables, from memory: escort ids (219, 1222), class quests for all nine classes (HUNTER 6064 is
      probably level 10, not 20), the dungeon table (names, levels, maps, area ids) and its quests by zoneOrSort.
- [ ] `GetXPExhaustion` gives the rested pool in experience (nil/0 when none) and drops by the rested bonus.
- [ ] Reputation reads: `C_Reputation.GetFactionDataByID` fields, the standing ids (Honored 6, Revered 7, Exalted 8),
      Questie's reputationReward shape.
- [ ] Upgrade bonus: `GetQuestLogItemLink(kind, i, questID)` and `GetNumQuestLogRewards`; a quest whose reward is not
      loaded yet.
- [ ] Item-started quests (Questie startedBy[3], npcDrops); the gray gap of 8 levels; the quest log of 25.
- [ ] The inn suggestion a few frames after Esc opens the game menu, never in a fight; the chat and panel lines
      come promptly; an innkeeper on the same continent is found.
- [ ] Soloed elites recorded alone, not in a group; deaths counted on a cave or town map; does a party want elite
      grinding spots?
- [ ] The skip list shows a quest's name after it has left your log.
- [ ] Kills: `CHAT_MSG_COMBAT_XP_GAIN` once per kill within 1 s of PLAYER_XP_UPDATE; two kills under a second apart
      give no sample, ordinary pulls do; an AoE pull's coalesced XP update; the kill line hidden in combat still
      counts; `UnitCanAttack` on a corpse; the dead target's level and classification in combat; a DoT or pet kill
      with an older corpse targeted; a few kills against `ns.PlannerKillXP` at −3…+3; a kill that levels you is
      scored at the old level.

## 11. The world map
- [ ] The route line and hub marks on the real world map: a zoomed map, a pan, zooming while it stays open, the line
      over a zone map, none on a continent view; a city or cave step on its zone's map shows no stop.
- [ ] Hub marks under and over the game's pins; clicks on a mark; a right click zooms out; up to 80 marks; the 24 px
      hit area, the alpha floor 0.55 and the tier digit.
- [ ] Plan from here: the question, the replan, the picked hub first; a pick made in combat waits for the fight.
- [ ] Finish the zone from a city or cave (the parent walk); "Zone done" once; the goal button changes back.

## 12. Plan with a friend (two accounts)
- [ ] The prefix registers at login; whispers reach a friend on the same realm; a cross-realm friend; a cross-faction
      friend gets nothing and the leader sees "No answer from …" after 30 s.
- [ ] A friend's ask while your planner folder is not loaded: the ask page shows; in a fight it shows after.
- [ ] The ask page: "… asks to plan your route together.", Plan together / No thanks, Tab and Enter, the caption
      sound, reading aloud, the countdown, closing at 0 after 30 s.
- [ ] Both panels' progress lines during a real hand-in and a flight ("on this step", "steps behind", "done", "Wait
      for … here"), the title's "with …".
- [ ] Inside an instance: the queue holds, "Planning together is paused inside an instance.", the rest goes out in
      order after; only the newest step is sent.
- [ ] A plan received while your level can't be read: tried every 5 s, dropped quietly after 6 tries.
- [ ] The real throttle and `SendAddonMessageResult` values on Forever; a friend who logs out mid-duo; texts with
      newlines and cut UTF-8 arrive unchanged; the sender's name shape (`Ambiguate`) on your realm, a connected
      realm and another realm.

## 13. Plan codes and find a group
- [ ] Share plan: the copy box with a long code (60 steps) holds it all and Ctrl+C copies it; its height at text
      sizes 70/100/150; the X closes it; the caption names fantasyglassui.com/plan/.
- [ ] The plan page on a phone with a real code: the zone panels, the dashed legs, the ticks kept across a reload,
      Clear the ticks, the language picker.
- [ ] Find a group: `ChatFrameUtil.OpenChat` with a `/4 ` line sends to channel 4 on Enter (no prefix: the chat
      box's channel); `GetChannelList` and `GetChannelName` on Forever; a title cut to nothing gives "LFG <name>,
      Zone", never "LFG , Zone".

## 14. Ways to make gold
- [ ] The window and the auction-house panel in the settings look, in a normal and a high-contrast theme: the rows'
      faint second line, the sliders, the goal bar, the Starcut corner.
- [ ] The panel docked beside the auction house (TOPRIGHT +6) with Scan prices, clear of the Browse tab.
- [ ] Ctrl-click on the minimap button opens it, and the tooltip says "Ctrl-click: ways to make gold"; the panel's
      "..." entry and `/fgui guide gold` open it too.
- [ ] Frame times while collecting with thousands of prices: no hitch over a frame or two; each slice at most 4 ms in
      `/fgui perf`.
- [ ] Recording while the gold folder is not loaded, on a fresh login: a merchant (`goldVendor`), a kill's loot
      (`goldMobs`), an herb (one node and its loot), a recipe window, a level-up, a kill's experience, a timed quest.
- [ ] The node fold on a real saved file: node counts before and after, no duplicates on the map.
- [ ] Merchants: `C_MerchantFrame.GetItemInfo` (price for the whole stack, stackCount, numAvailable −1 for
      unlimited, extendedCost); `GetMerchantItemCostInfo` above 0 for a token item.
- [ ] Loot: `GetLootSourceInfo` creature guids and per-source quantities, the coin; the coin from GetMoney around one
      creature's loot; Pick Pocket then the corpse: only the corpse counts; `GetQuestLogRewardMoney(questID)`;
      `Questie.API.isReady`.
- [ ] Gathering: the spell ids and names (herbs 2366/2368/3570/11993, mining 2575/2576/3564/10248, skinning
      8613/8617/8618/10768); skinning loot in `goldGather`, not counted as a kill; `GetLootSlotInfo`'s stack count;
      UNIT_SPELLCAST_SUCCEEDED before LOOT_OPENED.
- [ ] Crafting: `C_TradeSkillUI.GetRecipeSchematic` fields; a linked, guild or NPC profession is not read.
- [ ] An auction flip's tips make sense on a live auction house; `/fgui shop` counts your other characters.
- [ ] Guesses to tune: the farming copper-a-loot bands, the gathering zone bands and skills, and the riding costs
      (Riding at 40, Epic riding at 60).

## 15. Folders and failures
- [ ] A broken folder (rename one planner file): one message, `/fgui check` names it, written guides still work.
- [ ] The Tools menu's "Guide" group, Ctrl-click, `/fgui plan` and the auction-house panel after the folder load.
- [ ] Opening the auction house in a fight before the gold folder is loaded: it loads quietly after the fight.

## 16. Scan prices and the price store (12.4, still open)
- [ ] Scan prices on a live auction house: the time, the item count, no freeze at the end; the button's texts and
      that the longest translations fit beside the Browse tab.
- [ ] A fight mid-read ("Paused for combat"), closing the auction house mid-read, the countdown after /reload.
- [ ] One migration on an old character; another realm or faction does not get the prices; a pandaren before
      choosing a faction.
- [ ] Bound BoEs get no hint; the tooltip order; the hint squares on the bag window in each theme.
- [ ] The saved file's size before and after full scans on two houses, the memory after a scan, the login time.

## 17. Guide tab, lists and other looks
- [ ] The Guide tab's row heights at text sizes 70, 100 and 150 and with Bigger controls: no overlap or gaps; the
      layout runs again for a new width. Contrast: descriptions dim at 13, the followed guide's name, the focus ring.
- [ ] List rows at every font scale, the note wrapping to two lines, colours from the theme and the colour-vision
      palette; the Guides list's first line ("Plan my route", "following").
- [ ] Save as guide: the guide in the list, its name ("Zone 8-10", then " (2)"), followed as a written guide.
- [ ] Break reminders: only at a stopping place, never in combat or mid-hub, at most once an hour.
- [ ] The time you have: `/fgui guide plan 30`, `plan 0`, plain `plan`; the route ends at an innkeeper or a known
      flight point, then "Good place to stop", and the deadline clears when it is ticked.
- [ ] "Why this?" on a planned step's menu, and its page.
- [ ] Read aloud: `ns:Speak` timing against step changes, written guides too, only with reading aloud on.

## 18. 13.5: dungeon runs, class quests on time, speed, saved data
Gathered from the 13.5 reports (`.superpowers/sdd/2026-11-26-13.5/task-2` to `task-5`) and the `-- check in game`
notes in PlannerSource.lua and PlannerClass.lua. Have ready: Questie loaded, a character at 15-25 near the Deadmines
or Wailing Caverns, a character a level below a class quest, and a copy of a real saved file with an old alt in it.

Dungeon runs ("Dungeon runs in my route", on by default):
- [ ] Questie's real `ZoneDB:GetDungeonLocation(area)`: what it returns for 1581 (Deadmines) and 718 (Wailing
      Caverns). The code expects `[1] = { area, x, y }`, all numbers, with `GetUiMapIdByAreaId(area)` giving a map.
      If the shape differs, the table's entrance is used silently: check the run step's arrow points at the
      real entrance either way.
- [ ] Every row of `ns.PLANNER_DUNGEONS` (written from memory): inside each dungeon, `select(8, GetInstanceInfo())`
      equals its `instance`, and the boss count matches `bosses`. Expected: Ragefire Chasm 389 / 4, Wailing Caverns
      43 / 8, The Deadmines 36 / 6, Shadowfang Keep 33 / 8, Blackfathom Deeps 48 / 8, The Stockade 34 / 5,
      Gnomeregan 90 / 6, Razorfen Kraul 47 / 6, Scarlet Monastery 189 / 4, Razorfen Downs 129 / 5, Uldaman 70 / 9,
      Zul'Farrak 209 / 8, Maraudon 349 / 7, The Temple of Atal'Hakkar 109 / 8. Also the entrances and Questie area
      ids (`zone`). Ragefire Chasm's entrance in the table is on Durotar (1411); in the game it is inside Orgrimmar
      (1454, the Cleft of Shadow): check Questie's entrance puts the arrow there.
- [ ] The level ranges (13.5 fix I3). The table holds the Classic-era recommended ranges: Ragefire Chasm 13-18,
      Wailing Caverns 17-24, The Deadmines 17-26, Shadowfang Keep 22-30, Blackfathom Deeps 24-32, The Stockade
      24-32, Gnomeregan 29-38, Razorfen Kraul 29-38, Scarlet Monastery 26-45, Razorfen Downs 37-46, Uldaman 41-51,
      Zul'Farrak 44-54, Maraudon 46-55, The Temple of Atal'Hakkar 50-60. These win with Questie loaded too: its meeting
      stones' lower ranges (`/dump QuestieLoader:ImportModule("MeetingStones"):GetLocalizedDungeonNameAndLevelRangeByObjectId(179555)`
      gives Gnomeregan and "(24-32)") only fill in a dungeon the table has no range for. Check that a character below a
      dungeon's lowest level in this table is never sent there: a level 24 character is not planned into Gnomeregan.
- [ ] A run's time is learnt only from runs by a character within the dungeon's range: run a dungeon on a level 60
      alt, and the low character's plan keeps the default time.
- [ ] A planned run: the pick-ups, then "Find a group for <dungeon>" ticks when you join a group, the wait line
      counts up, "Skip this dungeon" shows on the group step only from 15 minutes on and replans without it.
- [ ] "Run <dungeon>" ticks only once you are back in the open world, alive, after being inside; then the
      hand-ins follow. A run with a kill and a length goes into the run log with the instance id.
- [ ] Wiping and releasing at the graveyard: the run step does not tick while you are a ghost.
- [ ] The wrong-portal ghost case: release, run the ghost into a different portal (Blackrock Mountain or the wrong
      Scarlet Monastery wing) and come back to life inside it. The run step must not tick there; it ticks once you
      leave to the open world.
- [ ] Find a group's text for a dungeon group step names the dungeon, with no "#nil".
- [ ] A new session (logout, or `/fgui plan` start) clears the dungeon skips with the other session skips. A dungeon
      run this session stays out of every plan until the next login, `/fgui plan` start or not; a /reload keeps both.
- [ ] Leaving the dungeon with a replan queued (the loading screen's): the new route has no group or run step for it,
      and it does not come back later that session. Going in while a pick-up is still open: after the run, skipping
      the pick-up ticks the group and run steps.
- [ ] A written guide's `dungeon 36 | Run The Deadmines` ticks after the run, the same way.
- [ ] Planning together with a friend on 13.0: the friend gets the run steps as notes and keeps getting plans; with a
      friend on 13.5 the friend's group step has Find a group and Skip this dungeon.
- [ ] A dungeon quest of a dungeon not in the table (Blackrock Depths) still shows up in its quest hub.

Class quests on time:
- [ ] Questie's `IsDoable` for a class quest one or two levels above you (below its level): the heads-up needs the
      record to count as doable then. If it says no, there is no heads-up at all.
- [ ] The heads-up: chat prints "Your level %d class quest is coming: it starts in %s." once per quest per
      character (not again after /reload), and the planner panel line stays on every plan while it applies, in
      German too ("du"). Neither shows with "Plan class quests" off. With Keep my route on, the panel line goes at
      the level-up to the quest's level, and once the quest is in your log.
- [ ] The hold on its continent: a level before the class quest, standing on its continent, the route stays on that
      continent (no boat or zeppelin away). Standing on another continent, the hold is lifted and the route still plans.
- [ ] A due "always" class quest across the sea is planned as a lead-in when a crossing reaches it, and its missing
      prerequisite you could take now goes into the route.

Speed:
- [ ] Planning in game: `/fgui plan` on a full Questie install at 20 and at 50, with dungeon runs on: no visible
      stutter, the plan arrives in a second or two, and the frame rate holds during it (planner slices stay near 4 ms).
- [ ] The first open of the planner window, the gold window and the settings after a login: no hitch you can feel.
      The login itself is no slower than 13.0.

Saved data:
- [ ] The settings' "Saved data" button and `/fgui data`: one line per part with a size, then "Tidy up old records".
- [ ] The tidy-up on a copy of a real saved file: characters unseen 180 days are listed with every record (planner,
      gold, guides, character list, bags and bank, everything else) and sizes. The character you are on is never
      offered, even when its own times are old.
- [ ] The tidy-up confirmation: nothing goes on one click; "Remove these %d (click twice)" needs a second click
      within 10 seconds, a late second click resets it. Then "Removed %d old records (about %s).", and after a
      /reload the records are really gone and nothing else is.
- [ ] Nothing is removed by a login, a /reload or a timer with old records in place.
- [ ] Set the computer's clock a few days wrong and run `/fgui data tidy`: no character is offered, and the line says
      the clock is off. Your main character is never offered.
- [ ] The backup restore on a copy of real saved data: after an update and a day's play, `/fgui backup` shows
      ", with guides, routes and gold"; `/fgui backup restore daily` brings back the guide state, the planner and
      gold records as well as the settings; "before restore" puts them back again. Check the saved file's size
      with the records in the backups, and a large gold store left out past 4 MB is named.
- [ ] A logout mid-copy (right after login on a big file): that backup is never restored with half its records.

## 19. 13.5 part two: beta, the check after a patch, crash reports, times
Gathered from the 13.5 part two reports (`.superpowers/sdd/2026-11-27-13.5-behind/task-1` to `task-5`). Have ready:
the GitHub repository with push rights to a `beta/test` branch, the CurseForge app, a copy of a real saved file, and
a character who can finish a quest, gain a level, fly and take a boat in one session.

Beta:
- [ ] A `[beta]` commit on a `beta/test` branch makes a CurseForge Beta file and a GitHub prerelease, and a
      `[release]` commit (on main) still makes a release.
- [ ] The CurseForge app, set to Beta for Fantasy Glass UI, installs the beta file.
- [ ] The beta line shows once at login (not again after a /reload), and Report a problem names the beta.

The check after a patch:
- [ ] `/fgui health` on a normal login lists nothing missing.
- [ ] At the first login after a real Forever patch (or with `root.lastBuild` edited in the saved file), no part is
      turned off that works, and the line names only real losses.
- [ ] The talent, auction and guild windows' frames (loaded on demand) are not reported missing.
- [ ] A /reload in a fight waits: the check runs after the fight.
- [ ] `C_XMLUtil.GetTemplateInfo` answers on Forever (`/dump C_XMLUtil.GetTemplateInfo("BackdropTemplate")`). If it
      does not, templates are never judged.

Crash reports ("Keep crash reports", off by default):
- [ ] Switch on, cause an error (`/run FantasyGlassUI:Guard("Test", function() error("x") end)()`): `/fgui crashes`
      lists it, with no character, realm, guild or alt names and no path above AddOns.
- [ ] Report a problem has the crash code.
- [ ] Switching off asks first (one click clears nothing; the second click within 10 seconds clears and switches off).
- [ ] A profile switch keeps the old reports.

Times ("Help improve time estimates", off by default):
- [ ] Switch on, finish a quest, gain a level, take a flight and take a boat: Share my times shows four entries and a
      code.
- [ ] Switching off offers to clear (closing the list keeps them).

At the 13.5 release (website and CurseForge, not before):
- [ ] The Get started line on switching to Beta in the CurseForge app.
- [ ] The "send it in" note at `https://fantasyglassui.com/get-started/#share-times`, naming the Discord channel or the
      contact address.
- [ ] Run `tools/shared_times.py` on the codes sent in, and ship the data file it writes.
