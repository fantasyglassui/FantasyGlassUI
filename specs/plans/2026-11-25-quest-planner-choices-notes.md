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
- The step menu (right click on a planned quest step) closes on Escape and on a click elsewhere.

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

## Minor findings deferred
- Task 1: no test drives the Estimates call site with an alts' record (removing noAlts there would still pass); GetQuestLogItemLink with a quest id unverified.
- Task 2: reputation field shapes unverified; two quests of the same faction each get min(given, needed) when scored before the route; the panel shows one faction.
- Task 3: marked-hub anchor x/y stale; an empty plan's Moved uses the maximum across maps; a quest accepted before login is never recorded as a soloed elite.
- Task 4: HUNTER 6064 level; RouteSpots counts vendor, explore and gather spots; a kept drop quest is not re-checked after the rebuild; a held-item accept precedes a timed run in the same hub; a timed quest not yet logged cannot be known as timed; stops or explore extras may land between a timed run's steps; a fit quest costs a second route build.
- Task 5: gray = 8 levels below is a guess; a test assigns the global clock before the local; QUEST_COMPLETE timing unverified; inn panel line stays 10 minutes.
- Task 6: 60 kills an hour flat; elites skipped in grind spots; dungeon ids and coordinates from memory.
