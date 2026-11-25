# Quest planner batch 3 (choices it makes for you): build notes

Kept from the build ledger when its workspace was removed.

## Check in the game before release
- Escort quest ids in ns.PLANNER_ESCORTS (two ids from memory: 219, 1222; the data does not mark escorts).
- Class quest ids, levels, kinds ("always" or "fit") and parts in ns.PLANNER_CLASS_QUESTS (starter entries for all nine classes, from memory; wrong ids are only filtered by the doable check). Known doubt: HUNTER 6064 is probably level 10, not 20.
- The dungeon table ns.PLANNER_DUNGEONS (names, level ranges, maps, coordinates, area ids) and the dungeon quest ids read per area via QueryQuestSingle(zoneOrSort).
- Reward selection on the real hand-in window: QUEST_COMPLETE timing, the deferred pick (C_Timer.After(0)), a single reward or no links selects nothing, secret values select nothing.
- GetXPExhaustion: that it returns the rested pool in experience points on Forever, and nil/0 when none.
- C_QuestLog.GetTimeAllowed: return shape (the first value is used) and that a quest not yet in the log reports nothing.
- Reputation reads: C_Reputation.GetFactionDataByID fields (currentStanding absolute? nextReactionThreshold, reaction), the game's FACTION_STANDING_LABEL ids (Honored 6, Revered 7, Exalted 8), and Questie's reputationReward shape.
- GetQuestLogItemLink(kind, i, questID) with a quest id, and GetNumQuestLogRewards, for the upgrade bonus; a fresh quest whose reward info is not loaded yet.
- Questie startedBy[3] and QueryItemSingle(id, "npcDrops") for item-started quests.
- The gray gap ns.PLANNER_GRAY_GAP (8 levels; GetQuestGreenRange is not in the Forever dump) and the quest log size of 25.
- The inn suggestion: GameMenuFrame OnShow, the 120 s travel test, that an innkeeper on the same continent is found.
- PLAYER_ENTERING_WORLD payload (isInitialLogin, isReloadingUi) for the session start, and that a reload keeps it.
- Accepting and handing in an elite quest while grouped or alone is recorded as a soloed elite; deaths record only with a world position and the same map.
- The step menu (right click on a planned quest step) closes on Escape and on a click elsewhere; the right-click button is there only while a planned quest step is shown, so world clicks under the panel's other lines go through.
- QUEST_REMOVED before QUEST_TURNED_IN on Forever: a hand-in is told by IsQuestFlaggedCompleted at QUEST_REMOVED (an abandoned quest is not flagged). Alts' quest times and soloed elites rely on it.
- Deaths on a cave or town map (GuideHere's sub-map): C_Map.GetWorldPosFromMapPos places them in the same world coordinates as the zone's hub, so they count.
- Grouped elite grinding: grinding spots leave elites out (the advice assumes you grind alone); check whether a party wants elite spots.
- The inn search as a planner job: it runs a few frames after Escape opens the game menu, never in a fight; check that the chat line and the panel line still come promptly.

## Rulings made during the build
- Ruling: class quests still respect the skip list (the player chose to skip them) — costs: none.
- Ruling: standings are stored as the game's own ids (Honored 6, Revered 7, Exalted 8), not the plan's 5/6/7 — costs: none (unreleased).
- Ruling: deaths and soloed elites are recorded whenever the guide is unlocked; the switches only govern planning, so turning one on later has history — costs: a little saved data.
- Ruling: "off the route" = logged, not planned, all known spots beyond the hub radius of every route step; planned quests are never advised against — costs: little, advice only.
- Ruling: rested extra counts only kills (min(pool, kill xp)), the pool drawn down along the plan; quest rewards are not doubled.
- Ruling: upgrade bonus = item levels gained x 0.02 x UnitXPMax, capped at 0.25 x UnitXPMax, for quests in the log only (Questie has no reward items).
- Ruling: reputation bonus = min(given, still needed) x 0.0002 x UnitXPMax per wanted faction, the need drawn down per kept quest.
- Ruling: alts' times are per account, accept to hand-in while following, samples over 2 hours dropped; estimate (formula + avg x min(n,3)) / (1 + min(n,3)); pace estimates use the formula only.
- Ruling: a hub is too hard while level < deathLevel + 2 when two deaths at that level or the one before lie within 150 yd of it; a hub with a quest already in the log keeps only its logged quests.
- Ruling: a fit class quest is planned only at its own level ("below level + 1" read literally); above that it only shows on the panel.
- Ruling: grinding spots 60 kills an hour flat (a saved killsPerHour on the character record is honoured).
- Ruling: user (25 Nov): when the planner is finished it gets its own button and settings window, not switches on the Guide tab (in the design spec).

- Ruling (final review): upgrade and reputation "bonus xp" only score hubs, zones and the route. Forecasts (summary.xp, the panel's level), Show why's "(+N xp)", the class trainer stop and the held hand-ins use the real experience (reward + kills + rested), PlannerQuestXP's third value — costs: none.
- Ruling (final review): a hub planned first (an "always" class quest, also while logged, or a quest item in your bags) goes first but never chooses the zone, binds the hearthstone or sets lastZone; on another map it is a lead-in on top of the zone's two hubs, taken only when it is on the zone's continent and can be reached — costs: a class quest on another continent waits until the zone is near.
- Ruling (final review): "never planned" = a logged quest the planner's own filters would reject (skipped, above the level window, a group or elite quest the group setting leaves out) or whose hand-in can't be reached; a logged quest that passes and lies near the route (it may only be beyond the two hubs) is never named. The reasons are worked out in the planning coroutine (summary.logReasons); the panel only counts the log and looks them up (gray is still seen at draw time) — costs: fewer suggestions.
- Ruling (final review): a planned quest is never advised for abandoning, gray ones included (the planner chose to do it) — costs: a gray quest the plan still does is not named.
- Ruling (final review): a hand-in counts for the pace once, by whichever of QUEST_TURNED_IN and QUEST_REMOVED (of a quest flagged completed) comes first; the other event only clears the mark — costs: none.
- Ruling (final review): alts' samples split the elapsed time evenly among the quests open at once (accepted while following); a hand-in reported by QUEST_REMOVED first still counts, an abandoned quest gives none — costs: rougher per-quest times on unequal quests.
- Ruling (final review): a quest with a clock on it marks all its run's steps (accept, do, hand-in: step.timed); the path extras (unexplored spots, nodes) never go on a leg that ends at such a step (on the way to the run or between its steps), only after its hand-in; a quest item in your bags in the same hub is used where the run ends — costs: none.
- Ruling (final review): grinding advice leaves elites out (you grind alone); 60 kills an hour flat; the inn panel line stays 10 minutes; the reputation line names one faction (the spec's example) — design values, kept.

## Fixed in the final review
- Class quest pass: the group/elite setting and repeatable quests are checked as for any quest.
- Dungeon advice leaves out quests on the skip list and quests whose prerequisites are not done.
- A death counts by world position (same continent, within 150 yd), not by the map id, so a sub-map death near the hub counts.
- The marked hub keeps its place where the quests it keeps are (its anchor is recomputed).
- An empty plan's "Moved" line is for the map you are on ("here"), never another map's hub.
- Two quests of one faction in a hub share what is still needed when the hub is scored.
- Item-started quests are judged against quest steps only (stops, explore and gather spots are no reason), and checked again against the rebuilt route (built again without them when the route left their NPC, twice at most).
- A quest item in your bags no longer comes before a timed run in the same hub.
- Soloed elites: the solo accept is kept per character (a /reload or new session in between counts); QUEST_REMOVED of a handed-in quest counts as the hand-in.
- The inn suggestion runs as a planner job (ns.PlannerJob: a slice a frame, never in a fight, while the planner is idle); opening the game menu only does the cheap tests.
- The death filter loops yield.
- The right-click step button is shown only on a planned quest step.
- Tests: the Estimates call site with an alts' record; the Task 5 test's clock is local.

## Minor findings deferred
Only what needs the live game (all in "Check in the game" above), plus two notes:
- A timed quest not yet in the log can't be known as timed (the game only reports the clock once it is taken; Questie's timer data could come later).
- A fit class quest costs a second route build, and a drop quest up to two more (sliced; planning time only).
- Stops never land inside a timed run (a timed quest is always logged, so the stop goes after the hub's last plain accept or before the run); the path extras skip its legs (fixed above).
- Hub scoring sees the whole rested pool for each hub (the route draws it down as it lays hubs out), as documented.
