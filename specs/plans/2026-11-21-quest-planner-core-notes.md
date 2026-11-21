# Quest planner batch 1: build notes

Kept from the build ledger when its workspace was removed.

## Check in the game before release
- Questie's shipped TOC has `X-QuestieDB-Contract: 4` (otherwise the planner always falls back to the quest log).
- The boat and zeppelin docks in PLANNER_CROSSINGS (map ids and coordinates are from memory).
- UnitOnTaxi is true at PLAYER_CONTROL_LOST (otherwise flights are never timed).
- C_TaxiMap.GetAllTaxiNodes positions are accepted by C_Map.GetWorldPosFromMapPos.
- The step sound when a replan resets the guide to step 1.
- The planned guide's saved name (a control character) survives SavedVariables.

## Rulings made during the build
- Ruling: T2/T3 call ns:PlannerReplan only `if ns.PlannerReplan` — T6 defines it later — costs nothing if wrong.
- Ruling: T4 defines `ns.PlannerYield = function() end` (no-op); T4/T5 call it in loops; T6 replaces it with the yielding version — keeps T4/T5 testable before the runner exists.
- Ruling: tests unlock with the stored number read from Guide.lua, never a phrase — the user's rule that the phrase is never in any file.
- Ruling: Questie has no kill counts → record objective.count from the quest log (C_QuestLog.GetQuestObjectives numRequired) when in the log, else count nil with countKnown=false; Task 4 uses 8 for unknown kill/item counts — why: real data has no counts; costs: estimates off for Questie-only quests until accepted.
- Ruling: ctx.hearth (bind place + hearthstone cooldown) and ctx.flights (from ns.PlannerFlightPoints) are built by the planner in Task 5 — the brief defines the ctx shape, not who builds it — costs: none.
- Ruling: Task 5 gets innkeepers via a new optional source.inns() in PlannerSource (Questie: QuestieDB.NPCPointers + QuestieDB.npcFlags.INNKEEPER mask on npcFlags, built once per session, PlannerYield per NPC; log source returns {}) — the plan needs inns for bind steps but no task produced them — costs: one extra scan per session.
- Ruling: bind steps — GetBindLocation returns a place name, not the innkeeper's; Task 6 ticks the current bind step when HEARTHSTONE_BOUND fires (and keeps the text-equality check as a fallback) — costs: a bind done outside the step's turn isn't noticed.
- Ruling: split the route into FantasyGlassUI/PlannerRoute.lua now — Planner.lua at 711 lines before Task 6's runner — costs: one more TOC line.
- Ruling: Task 6 must not plan while ctx.sourceWhy == "waiting" (spec: wait for RegisterOnReady).
- Ruling: step.why lives only in the in-memory planned guide (not in guide text); Task 7 reads it from there.

## Minor findings deferred
- Task 2: minor (deferred): triggerEnd spots skip tonumber/-1 validation; test misses ready() callback, Tags, triggerEnd, npcDrops, log quest(); Tags per-record C_QuestLog lookup (cache in planner); audit allowances exempt GetQuestLogRewardXP/GetUiMapIdByAreaId add-on wide.
- Task 2: minor (deferred): log counts matched by objective index (order may differ); count test fake lacks quest Id.
- Task 3: minor (deferred): real.bind naming nit in test.
- Task 3: minor (deferred): stale dock `since` after leaving and reloading at the far dock; takeoff not cleared when UnitOnTaxi false.
- Task 4: minor (deferred): PaceRecord duplicates Travel's CharData accessor; rec.level not nil-guarded; Spread() path untested; RED by mutation only.
- Task 5: minor (deferred): unreachable turn-in still counted in summary; `first` cleared when first Go fails; Trip may leave learnflight steps when final leg unreachable; LearnOnWay/PlannerHubs cost O(P²); sail across continents has no why.saves.
- Task 6: minor (deferred): turned-in quest may reappear briefly before QUEST_REMOVED replan; SetHeight every Draw.
- Task 7: minor (deferred): no end-to-end panel test of "why" text; unused old usage-line translation keys.
- Final review: unsliced one-time scans of QuestPointers/NPCPointers; rec.exclusive unused; DockTick runs whenever unlocked; German mixes formal and informal address.
