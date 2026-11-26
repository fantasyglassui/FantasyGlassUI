# Quest Planner, Batch 6 (spec gaps and leftovers) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This plan is built for parallel execution**: Tasks 1 and 2 run first, one after the other; Tasks 3–12 run in four groups (A, B, C, D), each in its own git worktree at the same time; Task 13 merges them and checks everything. Read "Parallel build and merge" before starting.

**Goal:** Close what batches 1–5 left open against the spec: never plan two quests that exclude each other; learn what a kill is really worth and how fast you kill; time alts' quests without the time you were away or in town; plan again from the panel and start from the guide list; say "Go to Arathi Highlands: fly to Refuge Pointe"; gather from Questie's object spawns; know a timed quest before it is taken; walk Questie's big id tables a slice at a time; replace two wrappers with a seam in Guide.lua; and settle every deferred minor from batches 1–5.

**Architecture:** Task 1 is the anti-goal fix (`exclusiveTo`) in `Planner.lua`, alone and first. Task 2 adds the seams: a lock registry and a seam list in `Guide.lua`, the timed-quest test in the route reading a guarded `ns.PlannerTimedQuest`, a new empty recorder file `PlannerKills.lua`, and the test fences. The groups then own disjoint files: A the learning (`PlannerKills.lua`, `Planner.lua`, `PlannerAdvice.lua`), B Questie's data (`PlannerSource.lua`, `PlannerPath.lua`), C the route's words and the panel (`PlannerRoute.lua`, `PlannerTravel.lua`, `Guide.lua`), D the batch 5 files and the audit (`PlannerGroup.lua`, `PlannerDuo.lua`, `PlannerCode.lua`, `tests/forever_audit.py`). No group adds a setting, so `Core.lua` and `Bars.lua` get no regions.

**Tech Stack:** Lua 5.1 (WoW Forever, interface 16001); `PLAYER_XP_UPDATE`, `CHAT_MSG_COMBAT_XP_GAIN`, `PLAYER_FLAGS_CHANGED`, `PLAYER_UPDATE_RESTING`, `UnitXP`, `UnitXPMax`, `GetXPExhaustion`, `UnitIsAFK`, `IsResting`, `UnitIsDead`, `UnitCanAttack`, `UnitClassification`, `C_QuestLog.GetTimeAllowed`, `C_Map.GetAreaInfo`, `C_Map.GetMapInfoAtPosition` (each checked present in `tests/forever_api.json.gz`; none is a restricted event); Questie internals through `QuestieLoader:ImportModule` (pcall'd); tests in `tests/smoke.py` and `tests/test_addon.py`.

**Spec:** `specs/2026-11-21-quest-planner-design.md`: items #1, #4, #14, #20, #23, "Starting it", "When it plans again", "How far it looks" (moving zones), the anti-goals ("a stutter or freeze while planning", "a quest it cannot take"). Earlier plans and notes in `specs/plans/` (`*-core*`, `*-stops*`, `*-choices*`, `*-feel*`, `*-together*`). Source of the gaps: the 25 Nov missed-items audit (A8–A12, A19, B1–B4, B9–B12).

**Base:** `quest-planner` after batch 5's merge (Task 7 of `-together`, with its notes file) and after `main` 12.3.0 is merged in. Nothing in this batch calls 12.3 code. It touches two things 12.3 changed: `tests/smoke.py` (the fences sit before `try("Delayed calls"` wherever the merge left it) and `ns:Guard`'s error text (12.3 added `ns.GuardFrameOf`): no test may match a guarded handler's error text exactly. If 12.3 is not merged when this runs, stop: Task 2's fences and Task 13's Locales step assume the merged files.

## Global Constraints

- Everything in batches 1–5's Global Constraints still binds: Forever audit; `luacheck . -q` 0 warnings; smoke.py `errors: no errors` twice; never plan in combat; 4 ms slices; `ns.PlannerYield()` only in plain loops (never inside `pcall`/`Try`, a sort comparator or a gsub callback); all phrases in 9 languages; Questie read-only through pcall; everything behind `ns:GuideUnlocked()`; nothing about the planner in /fgui help, README, site, wiki or changelog; `docs/` unchanged; commits by DustyMouse (`git -c user.name=DustyMouse -c user.email=fantasyglassui@users.noreply.github.com commit`) with no attribution lines; implementers never push.
- **The unlock phrase is never written anywhere.** Tests unlock with `ns.GuideUnlocked = function() return true end`; a test that must run `ns:GuideUnlock` stubs `ns.GuideHash` to return the number read from Guide.lua.
- **No `ReloadUI`, no `SendChatMessage` in planner code** (`grep -n "ReloadUI\|SendChatMessage" FantasyGlassUI/Planner*.lua` stays empty). Duo messages keep batch 5's rules.
- **Recorders read, never act, in combat.** The kill and quest-time recorders run on events during fights. They read values only after `ns:IsSecret` says each is readable, compare nothing hidden (secretaudit), call no protected function, and record nothing while locked.
- Saved data: per character through `ns.PlannerCharRecord(true)`; per account under `ns.root.planner*`; created only when writing. New this batch: per character `killXP`, `killGaps`, `killsPerHour` (the spec's "experience per kill by level difference"); per account `plannerTimed`.
- Per-task checks (each task's last step before the commit): `luacheck . -q` → 0 warnings; `cd FantasyGlassUI && python3 ../tests/smoke.py` → `errors: no errors` twice; `python3 tests/forever_audit.py` → exit 0; `python3 tests/secretaudit.py` → `0 lines compared a hidden value`. pytest, lockaudit, the Node check and sitecheck run in Task 13 only.
- Translations: groups do **not** run `add_tr.py`. Each group writes new phrases, in add_tr's format (`{ "English": [de, fr, es, ru, pt, it, ko, zh] }`), to `specs/plans/phrases/leftovers-<a|b|c|d>.json`. German uses "du" (the add-on's address everywhere else). Task 13 applies them.

### Rulings (the spec leaves these open)

- **Exclusive quests (`exclusiveTo`).** Questie's list is read as symmetric: two candidates are in one group when either names the other, and groups join through shared members. From each group only one is kept: a quest in your log first (then all others of its group go); else a class quest (`ctx.classQuests`); else the most real experience (`ns.PlannerQuestXP(rec, ctx)`'s third value), then the lower id. It applies across all three lists `ns.PlannerCandidates` returns (kept, and item quests waiting for the route) and to the dungeon advice's quest count. A quest dropped this way is not counted in `skipped.group`. A `pre` entry below 0 means "this quest done" in Questie (`-id`), so `AllDone` reads it as `math.abs(id)`.
- **What a kill is worth (#1), recording.** A kill is the game's kill line `CHAT_MSG_COMBAT_XP_GAIN` (one per kill; nothing else gives one, so hand-ins and exploring never count). Its experience is the `PLAYER_XP_UPDATE` change paired with it: the first XP change within `ns.PLANNER_KILL_PAIR = 1` s before or after the line. The change is `UnitXP` now minus before, plus `UnitXPMax` before when the level rolled over. The rested part is `GetXPExhaustion` before minus after, taken off (the base is what the formula predicts). The level difference is `UnitLevel("target") − UnitLevel("player")` when the target exists, is dead, can be attacked and has a readable level above 0. Elite is `UnitClassification("target")` ∈ `elite`, `rareelite`, `worldboss`. With no such target the kill counts for the kill rate only. No sample at all while in a group (`IsInGroup()`: split experience), while locked, or when any value is hidden or unreadable. Per character `killXP[diff] = { n, r }`, with diff clamped to −10…5 and `r` the running mean of actual ÷ `ns.PlannerKillXP(level, mob, elite)` over the last 20 (`r = r + (s − r) / min(n, 20)`). A sample is dropped when the formula gives 0 (gray) or the ratio is outside 0.25…4.
- **What a kill is worth, using it.** `ns.PlannerKillRatio(diff, elite)` is `(1 + r × m) ÷ (1 + m)` with `m = min(n, 5)`, and 1 with no samples. Every kill the planner counts is `formula × ratio`.
- **The monsters you meet on the way (#1).** These are the monsters met while walking between a kill objective's spawn points (the walk `ns.PlannerQuestTime` already times: spread ÷ speed). Extra kills = `spread ÷ speed ÷ 60 × ns.PLANNER_WAY_KILLS` (0.5 a minute), each at the objective's monster level. They are real experience: they count in scoring, the forecast, Show why and the rested draw-down. The route's own legs between hubs add none: they follow roads and cross unknown ground, and the route keeps no run steps to learn a rate from (batch 2's legs ruling).
- **Kill rate (#4).** The gaps between consecutive solo kill lines of 180 s or less (`ns.PLANNER_KILL_GAP`), the last 50 per character in `killGaps`. Once there are 10 or more, `killsPerHour = floor(3600 ÷ median gap + 0.5)` is saved. The grinding advice uses it (batch 3 already honours a saved value) and its kills × ratio. Objective times keep 25 s a kill: the pace factor already scales them to you, and the kill rate would count your speed twice.
- **Alts' quest times (#20).** Time is shared out among open quests only while you are present and out of town: `UnitIsAFK("player")` is not true and `IsResting()` is not true (both readable). `PLAYER_FLAGS_CHANGED` (unit `"player"`) and `PLAYER_UPDATE_RESTING` first share out the time so far, then set the new state. The 2-hour cap stays on the time since accepting (a quest left open overnight still gives no sample).
- **Plan again (spec "When it plans again").** A panel button "Plan again", shown only while following the planned guide. It calls `ns:PlannerReplan("again")`: no preview, and your pace mark is kept (batch 4's preview is for `ns:PlannerStart()`). On a duo friend the batch 5 `"replan"` hook refuses it and sends your state, so the leader plans again. `/fgui guide plan` stays as batch 4 made it (a fresh start).
- **Plan my route (spec "Starting it").** The first line of the Guides list is "Plan my route" (`ns:GuideFollow(ns.GUIDE_PLANNED)`, then the list redraws). It is marked "following" while you follow the plan, and shown only while the guide is unlocked and `ns.PlannerStart` exists.
- **Moving zones (spec "How far it looks").** A `fly` step whose landing lies in another zone than its take-off says `"Go to %s: fly to %s"` (zone, flight point). With no flight name it says `"Go to %s: take the flight"`. A flight within one zone keeps the flight point's name. The zone is the `mapType` 3 map above the spot: `C_Map.GetMapInfoAtPosition` for a continent map (flight points are stored on the taxi map), then up through `parentMapID`. A `sail` step says `"Take the boat from %s to %s"` or `"Take the zeppelin from %s to %s"` with the two docks' names. Each dock in `ns.PLANNER_CROSSINGS` gets an `area` id (from memory, checked in game) named by `C_Map.GetAreaInfo`, else the dock's map name; each crossing gets `ship = "boat"|"zeppelin"`. A name that can't be read falls back as said, never to "nil".
- **Gathering from Questie (#23).** Questie has no "herb" or "ore" flag, so the nodes are our own table `ns.PLANNER_GATHER_OBJECTS = { [objectID] = { skill = 182|186, min = n } }` (from memory, checked in game; ids and values listed in Task 7). Their spawns come from `QueryObjectSingle(id, "spawns")` when `QuestieDB.ObjectPointers[id]` is set. A node counts when your skill's rank ≥ `min`. A Questie node within `ns.PLANNER_NODE_YARDS` of a recorded node of the same skill is the same node (the recorded one is kept). The batch 2 limits stay: at most 20 s of detour, 5 nodes a plan. Recording what you gather is unchanged.
- **Timed quests not yet taken (#14).** Questie has no timer data: Questie v12.11.1's quest keys 1–32 have no time limit, and only its tracker reads the game's clock, for quests already in the log. So the "Questie's data" half of #14 becomes two sources of our own. `ns.PLANNER_TIMED = { [questID] = seconds }` starts empty (no id is known well enough to write from memory). A per-account memory `ns.root.plannerTimed[questID] = seconds` is written whenever a quest is accepted with `C_QuestLog.GetTimeAllowed` > 0 while unlocked. `ns.PlannerTimedQuest(id) -> seconds|nil` reads both. The route treats such a quest as timed before you take it.
- **Slicing Questie's id tables (anti-goal "a stutter").** `QuestPointers` and `NPCPointers` are walked once per table, a slice at a time, and the id list is kept for the session against that table. Questie replaces the table when it rebinds, and a new table is walked again. Each step is `pcall(next, t, k)` and the yield sits outside it. A failed step (the table changed under the walk) gives "not ready yet": nothing is cached, nothing is said, the next call starts over. A flag scan that ran before Questie had flags or pointers is not cached either.
- **The seam list (B12).** `ns.GuideRegisterLock(key, fn(unlocked))` is called through `Hook` after a successful `ns:GuideUnlock` (with `true`) and after `ns:GuideLock` clears the key (with `false`, before `GuideApplySwitch`). PlannerPace and PlannerDuo move to it, and no file wraps a `ns.Guide*` function any more. The comment block above the registries becomes the seam list: every `ns.Guide*` name and `ns.GUIDE_*` value a `Planner*.lua` file uses, one per line, between `-- Seams (what the planner uses of the guide):` and `-- end of seams`. A pytest keeps it true. This is the "small documented API" the folder move will need.
- **Deferred minors.** Each gets a verdict in "Deferred minors: triage" below. A minor listed in the batch 5 notes but not below is fixed by group D when it is in a group D file and takes 10 lines or fewer. Otherwise Task 13 records why not.

## Review Focus

- **A kill while grouped, an area kill with no dead target, or a kill line and XP change more than a second apart** → no level-difference sample (the kill still counts for the rate when solo), never a sample from a hand-in. → Task 3 test.
- **A kill that levels you up, or a kill while rested** → the base is the right number (rollover added, rested part taken off), never a negative or doubled sample. → Task 3 test.
- **Questie rebinding its pointer table in the middle of the walk** (a table that grows under `next`) → no Lua error, no ids mixed from two tables, the next call returns the new table's ids. → Task 6 test.
- **Two exclusive quests where one is in your log, or where only one names the other** → only one is ever planned (the logged one), and the panel's Skipped count does not change. → Task 1 test.
- **A flight into a zone whose name can't be read, or a dock whose area name is unknown** → the flight point's name or the map's name, never "Go to nil" or an error. → Task 9 test.

---

## File Structure

- Task 1: `FantasyGlassUI/Planner.lua` (candidates), `FantasyGlassUI/PlannerAdvice.lua` (dungeon count).
- Task 2: `FantasyGlassUI/Guide.lua` (lock registry, seam list), `FantasyGlassUI/PlannerPace.lua`, `FantasyGlassUI/PlannerDuo.lua` (wrappers out), `FantasyGlassUI/PlannerRoute.lua` (`IsTimed`), `FantasyGlassUI/FantasyGlassUI.toc`, new empty `FantasyGlassUI/PlannerKills.lua` (header and `local _, ns = ...`; TOC after `PlannerCode.lua`), `tests/smoke.py` (fences), `tests/test_addon.py` (seam test).
- Group A: `PlannerKills.lua`, `Planner.lua`, `PlannerAdvice.lua`. Group B: `PlannerSource.lua`, `PlannerPath.lua`. Group C: `PlannerRoute.lua`, `PlannerTravel.lua`, `Guide.lua`. Group D: `PlannerGroup.lua`, `PlannerDuo.lua`, `PlannerCode.lua`, `tests/forever_audit.py`.
- Shared, by region: `tests/smoke.py`, after `-- batch 5 tests C (code): end` (and batch 5's integration test): `-- batch 6 tests A (learning): begin` / `... end`, then B (questie), C (route), D (leftovers). `.luacheckrc` is regenerated by `python3 site-src/tools/regen_rc.py`.

## Parallel build and merge

1. The controller runs **Task 1**, reviews it, then **Task 2**, reviews it, one fix round each, and commits. Call Task 2's commit `SEAMS`.
2. Four worktrees from `SEAMS`: `git worktree add ../fgui-leftovers-a -b leftovers-a SEAMS` (and `-b leftovers-b`, `-c`, `-d` in `../fgui-leftovers-b` …). Group A: Tasks 3, 4, 5. Group B: Tasks 6, 7, 8. Group C: Tasks 9, 10, 11. Group D: Task 12.
3. One reviewer per group reviews `git diff SEAMS..leftovers-<x>` against this plan; the implementer makes one combined fix round (`"Planner: batch 6 <x> review fixes"`).
4. Group rules (as batch 5): touch only your files; in `smoke.py` write only inside your region; phrases to your own json; another group's function only through a guarded call, stubbed in your test; every test restores every global and `ns` field it changes and removes every hook it registers.
5. **Task 13** merges `--no-ff` in order A, B, C, D; a `.luacheckrc` conflict is resolved by regenerating it; any other conflict is kept in region order and noted. Then the worktrees and branches are removed.

---

### Task 1: Never plan two quests that exclude each other (sequential, first)

**Files:** Modify `FantasyGlassUI/Planner.lua` (`ns.PlannerCandidates`, `AllDone`, `InWindow`, `TrainerClosed`), `FantasyGlassUI/PlannerAdvice.lua` (`DungeonAdvice`); test `tests/smoke.py` (before the batch 6 fences, which Task 2 adds after it).

**Interfaces:**
- Consumes: `rec.exclusive` (PlannerSource: Questie's `exclusiveTo`, `{}` from the log source), `ns.PlannerQuestXP`, `ctx.onQuest`, `ctx.classQuests`.
- Produces: `ns.PlannerExclusiveKeep(recs, ctx) -> { [questID] = true }`: of the records given, the ids that stay per the ruling. `ns.PlannerCandidates` applies it once over kept, class and item records together, before returning. `DungeonAdvice` counts only kept ids.

- [ ] **Step 1: Failing test** `try("13.6 leftovers: exclusive quests", ...)`. Fake source, level 20, all doable at level 20:
  - 9601 `{ xp = 900, exclusive = { 9602 } }` and 9602 `{ xp = 1200, exclusive = {} }` → candidates hold 9602, not 9601.
  - Same with 9601 in the log (`onQuest(9601)`) → 9601 kept, 9602 dropped.
  - 9603 ↔ 9604 ↔ 9605 (9603 names 9604, 9605 names 9604; xp 500, 700, 600) → only 9604.
  - 9606 a class quest in `ctx.classQuests` exclusive with 9607 (xp 5000) → 9606 kept.
  - 9608 an item-started quest exclusive with 9609 (more xp) → 9608 not in the third list.
  - With Solo on and 9602 a group quest, `skipped.group` is 1, not 2.
  - `pre = { -9610 }` with 9610 done → the quest is a candidate.
  - A record with `level = nil` → no error, left out.
  - `DungeonAdvice` with two exclusive dungeon quests → count 1.
  - `TrainerClosed` at a riding trainer, then a class trainer opened → `ridingKnown` not set again by the second close.
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement** (union of groups by a small id → group map built in one plain loop with `ns.PlannerYield()`; the riding flag cleared in `TrainerClosed`). **Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: never plan two quests that exclude each other"`.

---

### Task 2: The seams (sequential, before the groups)

**Files:** Modify `Guide.lua`, `PlannerPace.lua`, `PlannerDuo.lua`, `PlannerRoute.lua`, `FantasyGlassUI.toc`, `tests/smoke.py`, `tests/test_addon.py`; create `PlannerKills.lua`.

**Interfaces:**
- Produces (Guide.lua): `ns.GuideRegisterLock(key, fn(unlocked))` per the ruling (same key replaces; `fn = nil` removes; each called through `Hook`). The seam list block per the ruling, listing at least `GuideRegisterLine`, `GuideRegisterTitle`, `GuideRegisterAction`, `GuideRegisterAdvance`, `GuideRegisterCommand`, `GuideRegisterLock`, `GuideRedraw`, `GuideMenu`, `GuideState`, `GuideGet`, `GuideSetPlan`, `GuidePlanFailed`, `GuideShowPanel`, `GuideOn`, `GuideUnlocked`, `GuideHere`, `GuideStepBase`, `GuideText`, `GuideParse`, `GuideParseLine`, `GuideFollow`, `GuideSkip`, `GUIDE_PLANNED`, `GUIDE_WINDOW_KINDS`, and every other name the grep finds.
- PlannerPace: its unlock/lock work moves to `ns.GuideRegisterLock("pace", ...)`. PlannerDuo: to `ns.GuideRegisterLock("duo", ...)`. Behaviour is unchanged (batch 4 and 5 tests still pass).
- PlannerRoute `IsTimed(ctx, q)`: true when the quest is in the log and `ctx.timed(q.id)`, or when it is not in the log and `ns.PlannerTimedQuest` exists and returns a number > 0 for `q.id` (group B defines it).
- `tests/test_addon.py::test_guide_seams_listed`: every `ns[.:](Guide\w+)` and `ns\.(GUIDE_\w+)` in `FantasyGlassUI/Planner*.lua` appears in the block; every name in the block is defined in Guide.lua (`function ns[.:]Name` or `ns.Name =`); `grep -n "local original = ns\[" FantasyGlassUI/Planner*.lua` finds nothing.
- Fences in smoke.py per File Structure.

- [ ] **Step 1: Failing test** `try("13.6 leftovers: seams", ...)`. A registered lock fn:
  - with `ns.GuideHash` stubbed to the stored number, `ns:GuideUnlock("x")` → called once with `true`;
  - `ns:GuideLock()` → called once with `false`, and `ns.root.guideKey` is already nil when it runs;
  - a failing fn → an entry `"Guide hook <key>: ..."` in `ns.errors`, and the next fn still runs.
  With a duo stubbed and the Story style set first, after a lock `ns.plannerDuo == nil` and the pace hooks are gone (`ns.PlannerHookList("rank")` holds no `"pace"`). After an unlock, `C_ChatInfo.RegisterAddonMessagePrefix` was called with `"FGUIPlan"`.
  `ns.PlannerTimedQuest` stubbed to give 600 for a not-logged quest 9620 in a hub with 9621 → the route plans 9620 as a run (accept, do, turnin with `.timed`) before 9621; with the stub nil, the normal order. `ns.PlannerRecordKill == nil`. Restore.
- [ ] **Step 2: Fail** (and `pytest tests/test_addon.py::test_guide_seams_listed` fails). **Step 3: Implement. Step 4: Pass**, the per-task checks, and that pytest test.
- [ ] **Step 5: Commit** `"Planner: seams for batch 6 (lock registry, seam list, timed hook, recorder file, fences)"`.

---

### Task 3 (group A): Record what each kill gives and how fast you kill

**Files:** `FantasyGlassUI/PlannerKills.lua`; `tests/smoke.py` (region A); `specs/plans/phrases/leftovers-a.json` (only if a phrase is added).

**Interfaces:**
- Consumes: `ns.PlannerKillXP`, `ns.PlannerCharRecord`, `ns:IsSecret`, `ns:GuideUnlocked`.
- Produces:
  - `ns.PLANNER_KILL_PAIR = 1`, `ns.PLANNER_KILL_GAP = 180`, `ns.PLANNER_KILL_GAPS = 50`, `ns.PLANNER_KILL_MIN_GAPS = 10`.
  - `ns.PlannerRecordKill(sample)` with `sample = { xp = base, level, mobLevel|nil, elite, t }`: updates `killXP` (when `mobLevel`) and `killGaps` / `killsPerHour` per the rulings.
  - `ns.PlannerKillRatio(diff, elite) -> number` per the ruling (`elite` is passed for the formula only; one table for both).
  - One event frame (`PLAYER_XP_UPDATE` for `"player"`, `CHAT_MSG_COMBAT_XP_GAIN`, `UPDATE_EXHAUSTION`, `PLAYER_ENTERING_WORLD` to read the starting values) under `ns:Guard("Planner kills", ...)`, pairing per the ruling; `ns.PlannerKillsEvent(event, ...)` calls the same handler (tests).

- [ ] **Step 1: Failing test** `try("13.6 leftovers A: recording kills", ...)`. A fake clock, `UnitXP` / `UnitXPMax` / `GetXPExhaustion` / target values set per case, solo, level 20 (formula at diff 0 = 145):
  - Line then XP +174 within 0.5 s, target dead, level 20 → `killXP[0]` is `{ n = 1, r = 1.2 }`.
  - XP first, then the line 0.8 s later → same.
  - Line, then XP 1.5 s later → no `killXP` sample, one kill counted.
  - XP change with no line (a hand-in) → nothing.
  - Rested: exhaustion 1000 → 855, XP +290 → base 145, r 1.0.
  - Rollover: XP from 9900 of max 10000 to 45 → delta 145.
  - Grouped → nothing at all.
  - Target alive, or not attackable, or level −1 → no `killXP` sample, the gap still counted.
  - A gray mob, or a ratio of 5 → dropped.
  - Elite target, XP +290 → r 1.0 against the elite formula.
  - 11 kills 30 s apart → `killsPerHour == 120`; a 400 s gap is not added; 9 gaps → no `killsPerHour` yet.
  - `ns.PlannerKillRatio(0)` with `{ n = 1, r = 1.2 }` → 1.1; with 30 samples at 1.2 → `(1 + 1.2 × 5) / 6`; no samples → 1.
  - Locked → nothing written.
  - Secret mode, `UnitXP` hidden → nothing written, no error.
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: learn what each kill gives at each level difference, and your kill rate"`.

---

### Task 4 (group A): Use them: kills as you really get them, monsters on the way, your grinding rate

**Files:** `FantasyGlassUI/Planner.lua` (`KillPart`, `Spread` cached on the objective), `FantasyGlassUI/PlannerAdvice.lua` (`GrindAdvice`); `tests/smoke.py` (region A).

**Interfaces:**
- Consumes: Task 3's `ns.PlannerKillRatio`; `ctx.speed`; `rec.killsPerHour`.
- Produces: `ns.PLANNER_WAY_KILLS = 0.5`. `KillPart(rec, ctx)` counts each kill objective's `count × xp` plus the way kills (per the ruling), with `xp = ns.PlannerKillXP(level, mob, rec.elite) × ns.PlannerKillRatio(mob − level, rec.elite)`. The objective's spread is kept on the objective table (`o.spread`) the first time it is worked out; `ns.PlannerQuestTime` reads the same value. `GrindAdvice` xp an hour = kills an hour × formula × ratio at the spot's level.

- [ ] **Step 1: Failing test** `try("13.6 leftovers A: kills in the plan", ...)`, level 20, speed 7:
  - A quest with one kill objective of 8 at level 20, two spots 420 yd apart: with no ratio, `ns.PlannerQuestXP(rec, ctx)`'s third value = reward + 8 × 145 + (420 ÷ 7 ÷ 60 × 0.5) × 145.
  - With `killXP[0] = { n = 5, r = 1.5 }` → both kill parts × `(1 + 7.5) ÷ 6`.
  - Speed 0 → no way kills.
  - The rested extra uses the same kill part.
  - Two hubs: a kill hub that lost before wins once the ratio is 1.5 (the spec's "kill experience changes which hub wins", now with what you really get).
  - `o.spread` is set after one call, and `ns.PlannerQuestTime` gives the same time as before this change.
  - Grinding with `killsPerHour = 90` and no samples → "about 13050 xp an hour" at a level-20 spot; with `ns.PlannerKillRatio` stubbed to return 1.5 → 19575 (the number as the advice line prints it).
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: kills count as you really get them, with the monsters on the way, and grinding at your own rate"`.

---

### Task 5 (group A): Alts' quest times without the time away or in town

**Files:** `FantasyGlassUI/Planner.lua` (the quest-time block of the event frame); `tests/smoke.py` (region A).

**Interfaces:**
- Consumes: `UnitIsAFK`, `IsResting`, `PLAYER_FLAGS_CHANGED`, `PLAYER_UPDATE_RESTING`.
- Produces: the sharing per the ruling. `ns.PlannerQuestClock() -> { open = n, away = bool }` (read only, for tests). `ns.PlannerRecordQuestTime` is unchanged.

- [ ] **Step 1: Failing test** `try("13.6 leftovers A: quest times without away and town", ...)`. Fake clock, following a plan:
  - Accept 9650 at 0; AFK at 100 (`UnitIsAFK` true, then `PLAYER_FLAGS_CHANGED "player"`); back at 400; resting from 500 to 600 (`PLAYER_UPDATE_RESTING` each time); hand in at 700 → `ns.root.plannerQuestTimes[9650].avg == 300`.
  - Two quests open from 0, AFK from 50 to 150, both handed in at 250 → 75 each.
  - Accepted while resting, never left town, handed in at 300 → no sample (0 s).
  - `UnitIsAFK` secret → counted as present (no pause), no error.
  - Accepted at 0, AFK for 7000 s, handed in at 7300 → no sample (over 2 h since accepting).
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: your alts' quest times leave out time away and in town"`.

---

### Task 6 (group B): Walk Questie's id tables a slice at a time, once

**Files:** `FantasyGlassUI/PlannerSource.lua`; `tests/smoke.py` (region B).

**Interfaces:**
- Consumes: `ns.PlannerYield`.
- Produces: a local `IdList(name) -> list|nil` (`name` ∈ `"QuestPointers"`, `"NPCPointers"`), per the ruling: one pass collects keys, values and whether the values are a 1..n sequence of numbers (then the values are the ids, as `PointerIds` read them), yielding every 64 steps. Callers: `src.ids()` (nil → `{}`, no `changed`), `FlagIds` (nil → not ready: `scans[kind]` stays unset), `src.grindSpots` (nil → `{}`, not cached). `PointerIds` stays for the small saved lists. `ns.PlannerSourceReset` clears the lists. Also (batch 1 minor) `triggerEnd` spots go through the same `tonumber` / `-1,-1` check as `Spots`.

- [ ] **Step 1: Failing test** `try("13.6 leftovers B: Questie's ids a slice at a time", ...)`:
  - A fake `QuestPointers` of 6000 keys and a `debugprofilestop` that moves 1 ms per call → the planning coroutine resumes 3 or more times before its first `GetQuest` call; `src.ids()` equals what `PointerIds` gives for the same table (sorted compare); a second `src.ids()` returns the same list object (`rawequal`).
  - A replaced `QuestPointers` → a new list.
  - A table that grows by 4000 keys between two resumes of the walk → no error, `src.ids()` returns `{}` that time and the full new list on the next call, never ids from both.
  - `npcFlags` missing on the first flag scan, present later → the second scan finds the innkeeper.
  - A `triggerEnd` spot `{ -1, -1 }` or `{ "x", 5 }` → not a place.
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: Questie's quest and NPC lists are read once, a slice at a time"`.

---

### Task 7 (group B): Gathering spots from Questie's objects

**Files:** `FantasyGlassUI/PlannerSource.lua` (the table, `src.gatherNodes`), `FantasyGlassUI/PlannerPath.lua` (`GatherSteps`); `tests/smoke.py` (region B).

**Interfaces:**
- Consumes: `QuestieDB.ObjectPointers`, `QuestieDB.QueryObjectSingle(id, "spawns"|"name")`, `ZoneDB:GetUiMapIdByAreaId`, `ns.PlannerProfessions()` (`rank`).
- Produces:
  - `ns.PLANNER_GATHER_OBJECTS` (check in game; `min` is the skill needed). Herbalism 182: 1617 Silverleaf 1, 1618 Peacebloom 1, 1619 Earthroot 15, 1620 Mageroyal 50, 1621 Briarthorn 70, 2045 Stranglekelp 85, 1622 Bruiseweed 100, 1623 Wild Steelbloom 115, 1628 Grave Moss 120, 1624 Kingsblood 125, 2041 Liferoot 150, 2042 Fadeleaf 160, 2046 Goldthorn 170, 2043 Khadgar's Whisker 185, 2044 Wintersbite 195, 2866 Firebloom 205, 142140 Purple Lotus 210, 142141 Arthas' Tears 220, 142142 Sungrass 230, 142143 Blindweed 235, 142144 Ghost Mushroom 245, 142145 Gromsblood 250, 176583 Golden Sansam 260, 176584 Dreamfoil 270, 176586 Mountain Silversage 280, 176587 Plaguebloom 285, 176588 Icecap 290, 176589 Black Lotus 300. Mining 186: 1731 Copper Vein 1, 1610 Incendicite Mineral Vein 65, 1732 Tin Vein 65, 2653 Lesser Bloodstone Deposit 75, 1733 Silver Vein 75, 1735 Iron Deposit 125, 1734 Gold Vein 155, 2040 Mithril Deposit 175, 165658 Dark Iron Deposit 230, 2047 Truesilver Deposit 230, 324 Small Thorium Vein 245, 175404 Rich Thorium Vein 275.
  - `src.gatherNodes(map) -> { { name, map, x, y, skill, min } }` (Questie source only; the log source returns `{}`): every table id's spawns are read once a session (each read through `Try`, the walk over the spawns in a plain loop with `ns.PlannerYield()`, areas → maps cached), kept by map.
  - `GatherSteps` adds, for each leg's map, the Questie nodes your rank allows to the recorded ones, deduplicated per the ruling. A Questie node's step text is its Questie name, and its `stopKey` is as for recorded nodes.

- [ ] **Step 1: Failing test** `try("13.6 leftovers B: gathering from Questie", ...)`. Fake Questie objects 1618 (Peacebloom, two spawns on map 1429: one 15 yd off a leg, one 400 yd off it) and 1735 (Iron Deposit, one spawn 10 yd off it). Herbalism 50, Mining 100:
  - Planned guide → one `gather` step "Peacebloom" before that leg's destination, no step for the far one, none for Iron (rank 100 < 125).
  - Mining 130 → Iron too.
  - A recorded Peacebloom 5 yd from Questie's → one step.
  - `plannerGather = false` → none.
  - `ObjectPointers[1618]` nil → none, no error.
  - `QueryObjectSingle` raising → none, no error, the plan still made.
  - The log source → `src.gatherNodes` returns `{}`.
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: gathering spots on the way from Questie's object data"`.

---

### Task 8 (group B): Timed quests known before you take them

**Files:** `FantasyGlassUI/PlannerSource.lua` (the table, the memory, its event); `tests/smoke.py` (region B).

**Interfaces:**
- Consumes: `C_QuestLog.GetTimeAllowed`, `QUEST_ACCEPTED`; Task 2's `IsTimed`.
- Produces: `ns.PLANNER_TIMED = {}` (with a comment: fill from the in-game checks); `ns.PlannerTimedQuest(id) -> seconds|nil` (`ns.PLANNER_TIMED[id]`, else `ns.root.plannerTimed[id]`; numbers > 0 only); at `QUEST_ACCEPTED` while unlocked, `GetTimeAllowed(id)` readable and > 0 → `ns.root.plannerTimed[id] = floor(seconds)` (at most 500 entries; the oldest go first).

- [ ] **Step 1: Failing test** `try("13.6 leftovers B: timed quests before you take them", ...)`:
  - `QUEST_ACCEPTED` for 9680 with `GetTimeAllowed` 900 → `ns.root.plannerTimed[9680] == 900`.
  - Locked, or the value hidden (secret mode), or 0 → nothing written.
  - Then, 9680 not in the log, in a hub with 9681 → the plan has accept 9680, do 9680, turnin 9680 in a row, each `.timed`, before 9681's accept, and no `explore` or `gather` step between them (a node placed beside that leg).
  - `ns.PLANNER_TIMED[9682] = 600` → the same for 9682.
  - Unknown 9683 → the normal hub order.
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: a quest any of your characters found timed is planned as a timed run before you take it"`.

---

### Task 9 (group C): "Go to <zone>: fly to …" and the boat's docks

**Files:** `FantasyGlassUI/PlannerRoute.lua` (`Legs`, `ns.PlannerZoneAt`), `FantasyGlassUI/PlannerTravel.lua` (`area` per dock, `ship` per crossing); `tests/smoke.py` (region C); `specs/plans/phrases/leftovers-c.json`.

**Interfaces:**
- Consumes: `C_Map.GetMapInfo`, `C_Map.GetMapInfoAtPosition`, `C_Map.GetAreaInfo`, `ns.PLANNER_CROSSINGS`.
- Produces: `ns.PlannerZoneAt(map, x, y) -> zoneMapID|nil` per the ruling. Fly and sail step texts per the ruling. Dock areas (check in game): Menethil Harbor 150, Theramore Isle 513, Auberdine 442, Rut'theran Village 702, Booty Bay 35, Ratchet 392, Orgrimmar's zeppelin tower 1637, Undercity's 1497, Grom'gol Base Camp 117. `ship = "zeppelin"` for the three Horde crossings, `"boat"` for the rest. Phrases: "Go to %s: fly to %s", "Go to %s: take the flight", "Take the boat from %s to %s", "Take the zeppelin from %s to %s".

- [ ] **Step 1: Failing test** `try("13.6 leftovers C: moving zones in words", ...)`. Fake maps: Wetlands 1437 and Arathi Highlands 1417 under continent 1415; a known flight point "Refuge Pointe" on 1415 at Arathi's spot; `GetMapInfoAtPosition(1415, …)` gives 1417.
  - A route from Wetlands to an Arathi hub → its `fly` step text is "Go to Arathi Highlands: fly to Refuge Pointe".
  - A flight within Arathi → "Refuge Pointe".
  - No flight name → "Go to Arathi Highlands: take the flight".
  - `GetMapInfo(1417)` nil → "Refuge Pointe".
  - A Menethil to Theramore crossing → "Take the boat from Menethil Harbor to Theramore Isle".
  - `GetAreaInfo` nil → "Take the boat from Wetlands to Dustwallow Marsh".
  - Orgrimmar to Undercity → "Take the zeppelin from …".
  - `ns.GuideParseLine(ns.GuideLine(step))` keeps each text.
  - With Show why on, the panel's `now` text is the step's text plus "  (saves ~3 min)" (batch 1's missing end-to-end "why" test).
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: moving zones says where you are going and how"`.

---

### Task 10 (group C): "Plan again" on the panel, "Plan my route" in the guide list

**Files:** `FantasyGlassUI/Guide.lua` (panel, `ns:GuideList`, `Draw`); `tests/smoke.py` (region C); `specs/plans/phrases/leftovers-c.json`.

**Interfaces:**
- Consumes: `ns:PlannerReplan`, `ns:PlannerStart` (guarded), `ns.GUIDE_PLANNED`.
- Produces:
  - `panel.again`: `ns:CreateButton(panel, "Plan again", 72, 18, ...)` at `LEFT` of the `>` button + 4. Shown only while following the planned guide. Click per the ruling. Tooltip "Plan the route again from where you are now".
  - The Guides list's first line, per the ruling.
  - `Draw` calls `panel:SetHeight(h)` only when `h` differs from the last height it set (batch 1 minor).

- [ ] **Step 1: Failing test** `try("13.6 leftovers C: plan again and plan my route", ...)`:
  - Following the planned guide → `panel.again` shown; its click → `ns.plannerQueued` true with `ns.plannerReason == "again"`, and the preview page not opened.
  - A written guide → hidden.
  - A `"replan"` hook returning false → the click changes nothing and gives no error.
  - `ns:GuideList()` → its first line's left text contains "Plan my route"; clicking it calls `ns:PlannerStart()` once and the list redraws; while following the plan the line says "following".
  - Locked → `ns:GuideList()` has no such line.
  - Two `Draw`s at one height → one `SetHeight` call (spy).
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Quest guide: Plan again on the panel, Plan my route in the guide list"`.

---

### Task 11 (group C): Route and travel leftovers

**Files:** `FantasyGlassUI/PlannerRoute.lua` (`Trip`, `HubSteps`), `FantasyGlassUI/PlannerTravel.lua` (`ControlLost`, `EnteringWorld`, `DockTick`, `CharData`); `tests/smoke.py` (region C).

**Interfaces:**
- Produces:
  - `Trip` puts back the steps it added, the flight points it marked known and `state.pos` when its last leg can't be reached.
  - `HubSteps` marks a quest gone when its hand-in can't be reached (its experience and time leave the summary), and `first` turns false only after a trip that worked.
  - `ControlLost` clears `takeoff` when not on a taxi.
  - A crossing is timed only when the dock was `inside` at the last tick before the loading screen and the wait plus crossing is at most 900 s.
  - `CharData` is `ns.PlannerCharRecord`.

- [ ] **Step 1: Failing test** `try("13.6 leftovers C: route and travel leftovers", ...)`:
  - A hub whose hand-in NPC is on an unreachable map → `summary.xp` leaves out that quest's experience and no `turnin` step for it.
  - A trip that learns a flight point and then can't reach its end → no `learnflight` step left and `f.known` false again.
  - A first trip that fails, then one that works → the second may take a learn detour (between hubs).
  - `PLAYER_CONTROL_LOST` with `UnitOnTaxi` false after a taxi take-off → no flight time recorded at the next `PLAYER_CONTROL_GAINED`.
  - Left the dock area (a tick away), then a loading screen at the far dock → no crossing time.
  - 1000 s at the dock → none.
  - 300 s → recorded.
  Restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: route and travel leftovers (unreachable hand-ins, learn steps put back, stale docks and take-offs)"`.

---

### Task 12 (group D): Leftovers in the batch 5 files and the audit

**Files:** `FantasyGlassUI/PlannerGroup.lua`, `FantasyGlassUI/PlannerDuo.lua`, `FantasyGlassUI/PlannerCode.lua` (only for batch 5 notes minors), `tests/forever_audit.py`; `tests/smoke.py` (region D).

**Interfaces:**
- Produces:
  - `ns.PlannerLFGText` never makes "LFG , Zone": a title that cleans to empty uses the quest's record name, else `"#" .. id`.
  - PlannerDuo clears `d.stateAgain` when no `"duoState"` job is queued or running.
  - In `forever_audit.py`, `GetQuestLogRewardXP` and `GetUiMapIdByAreaId` as methods are allowed only in `FantasyGlassUI/PlannerSource.lua` (a per-file allowance); LibDataBroker's two stay add-on wide.
  - The batch 5 notes' minors per the deferred-minors rule.
- Tests: the stops test for the disjoint-places safety branch (batch 2 minor) lives here because no code changes.

- [ ] **Step 1: Failing test** `try("13.6 leftovers D: leftovers", ...)`:
  - A title `"|cff00ff00|r"` with record name "Hogger" → "LFG Hogger, Elwynn Forest"; no record → "LFG #7001, Elwynn Forest".
  - A `duoState` job that errors → the next state job sends one state, not two.
  - The vendor stop's disjoint-places branch (sell and supplies at places that never meet) → two `vendor` steps.
  - Plus the batch 5 notes' fixes.
  Audit: with a line `x:GetUiMapIdByAreaId(1)` added to `FantasyGlassUI/Journey.lua` in the worktree (never committed) → `python3 tests/forever_audit.py` reports it and exits non-zero; with the line removed → exit 0.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: batch 5 leftovers and a narrower audit allowance"`.

---

### Task 13: Merge and check everything (controller, on `quest-planner`)

- [ ] **Step 1:** Merge `leftovers-a` … `-d` (`--no-ff`) per "Parallel build and merge"; regenerate `.luacheckrc` on a conflict.
- [ ] **Step 2:** Translations: `python3 site-src/tools/add_tr.py specs/plans/phrases/leftovers-<x>.json` for each; `git rm -r specs/plans/phrases`. Then the batch 1 minors:
  - German: every planner phrase in `FantasyGlassUI_Locales/Locales.lua` that says "Sie" / "Ihr" / "Ihre" is changed to "du" / "dein".
  - The old `/fgui guide` usage-line keys that no code uses any more are removed. They are listed by `site-src/tools/missing_tr.py`'s reverse check, or a grep of each key against `FantasyGlassUI*/*.lua`.
  - The stray `unspent = 1 + 0` in the batch 2 talent test is fixed.
- [ ] **Step 3:** Integration test after region D, `try("13.6 leftovers: together", ...)`, through the real runner with a fake Questie:
  - Two exclusive quests in one hub → one planned.
  - A recorded ratio of 1.5 changes the hub taken.
  - A Questie Peacebloom on the way gives a `gather` step.
  - A remembered timed quest runs first.
  - The trip into the next zone says "Go to …: fly to …".
  - "Plan again" from the panel replans without a preview.
  - Locking the guide mid-plan runs the lock registry once.
  - During the whole test no Lua error lands in `ns.errors`.
- [ ] **Step 4:** `cd FantasyGlassUI && python3 ../tests/smoke.py` → `syntax: all ... OK`, `errors: no errors` twice.
- [ ] **Step 5:** `luacheck . -q` 0 warnings; `python3 tests/forever_audit.py`, `python3 tests/lockaudit.py` (`(no protected calls in combat)`), `python3 tests/secretaudit.py` clean; `node tests/plan_reader_check.js`; `python3 tests/sitecheck.py`.
- [ ] **Step 6:** `python3 -m pytest tests -q` → 9 passed (batch 5's 8 and `test_guide_seams_listed`).
- [ ] **Step 7:** Release guards: `git diff --stat BASE -- docs` empty (`BASE` = the `quest-planner` commit Task 1 started from); `grep -ril planner README.md CHANGELOG.md RELEASE.md FantasyGlassUI/*.md docs site-src wiki` nothing; `grep -n "ReloadUI\|SendChatMessage" FantasyGlassUI/Planner*.lua` nothing; `grep -n "local original = ns\[" FantasyGlassUI/Planner*.lua` nothing; `/fgui help` text unchanged.
- [ ] **Step 8:** `specs/plans/2026-11-25-quest-planner-leftovers-notes.md`. It holds:
  - In-game checks:
    - `CHAT_MSG_COMBAT_XP_GAIN` arrives once per kill, before or after `PLAYER_XP_UPDATE` and within 1 s;
    - the dead target's `UnitLevel` and `UnitClassification` read in combat, and what is hidden there;
    - `GetXPExhaustion` drops by the rested bonus;
    - a few real kills against `ns.PlannerKillXP` at diffs −3…+3 (the spec's check of the formula);
    - `UnitIsAFK` and `PLAYER_FLAGS_CHANGED` when you go away and come back;
    - `IsResting` in an inn, a capital and a village;
    - whether Questie's Forever data has the herb and ore objects and their spawns (and the ids and skill levels of the table);
    - the dock area ids and their names, and the zeppelin crossings;
    - `GetMapInfoAtPosition` on the taxi continent map;
    - "Plan again" fitting on the panel in all nine languages;
    - the first line of the Guides list;
    - the walk's frames on a real Questie (no hitch at the first plan after login).
  - The rulings as made or changed.
  - The deferred-minors ledger below with each verdict as built.
  - Any conflict outside a region.
  Commit `"Quest planner batch 6: build notes (in-game checks, rulings, the deferred-minors ledger)"`.

---

## Deferred minors: triage

"Fix" names the task that does it; "Keep" says why not.

**Batch 1**
- triggerEnd spots skip validation: Fix, Task 6.
- Tests miss `ready()`, Tags, triggerEnd, npcDrops and the log `quest()`: Fix only triggerEnd (Task 6). Keep the rest: `ready()` is exercised by every batch 4–5 runner test, and Tags, npcDrops and the log source by batch 3's tests.
- Tags looked up per record: Keep. It is only for quests in the log (`GetLogIndexForQuestID` first), at most 25 calls a plan.
- Audit allowances add-on wide: Fix, Task 12.
- Log counts matched by objective index: Keep. Questie's objectives carry no index to match on, and a wrong count only shifts an estimate until the quest is taken.
- `real.bind` naming nit in a test: Keep (a name in a test).
- Stale dock `since`; take-off not cleared: Fix, Task 11.
- `PaceRecord` duplicated in Travel: Fix, Task 11.
- `rec.level` not nil-guarded: Fix, Task 1.
- `Spread()` untested: Fix, Task 4 (tested through the way kills).
- Unreachable turn-in counted; `first` cleared on a failed Go; leftover learnflight steps: Fix, Task 11.
- O(P²) in `LearnOnWay` and `PlannerHubs`: Keep. Sliced, and bounded by the flight points and hubs of one map.
- A sail has no `why.saves`: Keep. There is no running way across an ocean to save against.
- A turned-in quest shows briefly before `QUEST_REMOVED`: Keep. One replan later it is gone.
- `SetHeight` every Draw: Fix, Task 10.
- No end-to-end "why" panel test: Fix, Task 9.
- Unused usage-line keys: Fix, Task 13.
- `DockTick` runs whenever unlocked: Keep. It is a recorder: crossing times are learned whether or not you follow a plan (audit A1 wants recorders always on). It costs one distance test per crossing every 2 s.
- German mixes du and Sie: Fix, Task 13.

**Batch 2**
- An empty flag scan stays cached: Fix, Task 6.
- Mount vendor ids, skill line 633: Keep, in-game checks.
- `TRAINER_SHOW` reads places outside the coroutine: Keep. They are saved lists, cached, no flag scan.
- Detour not shown under Show why: already fixed (`WhyText` shows "(+N s detour)"). Task 13 notes it.
- A plan with no quests gets no stops: Keep. There is no hub to put a vendor at, and the dry-zone advice shows instead.
- Any `do` between a hand-in and `train` stops holding: Keep (holding is only safe with no extra trip).
- `summary.seconds` not adjusted for held hand-ins: Keep. It moves one hand-in within a 300 s window.
- Stray `unspent = 1 + 0`: Fix, Task 13.
- Disjoint-places branch untested: Fix, Task 12.
- Any mount seen marks riding known: Keep. In classic nobody mounts without riding.
- `ridingTrainer` not cleared on close: Fix, Task 1.
- Nodes have no respawn memory: Keep. It needs timers per node; the gold advisor may add them.
- Mail "gone" seen only at plan time: Keep (the 10-minute fallback).
- Legs over 8000 yd sampled for 8000 yd: Keep. It is the slice bound, and a node far along a long run is past the 20 s limit anyway.

**Batch 3**
- Grinding leaves elites out for a party: Keep. It is a design choice: you grind alone.
- A timed quest not yet in the log: Fix, Task 8.
- A fit class quest costs a second route build: Keep (sliced, planning time only).
- Hub scoring sees the whole rested pool: Keep (as documented).

**Batch 4**
- "Read the route aloud" greyed by alpha only: Keep. A disabled switch could not be set before turning reading aloud on, and the switch only narrows it.
- PlannerPace wraps `GuideUnlock` / `GuideLock`: Fix, Task 2.

**Batch 5** (from the reviews; the notes may add more, see the ruling)
- "LFG , Zone" from an empty title: Fix, Task 12.
- `stateAgain` not cleared when the job dies: Fix, Task 12.
- PlannerDuo wraps `GuideUnlock` / `GuideLock`: Fix, Task 2.
- The friend's ask page counted from receipt: Keep. The END and the age check cover it.
- `|n` to a space and a dead test assignment: already fixed (eccc6b5).
- Seams-test cosmetics (the `>= 896` check, the `13.4` prefix, fence placement): Keep (test wording only).
- Carried into batch 5 Task 7 (freeze `paceTimed` / `paceStyled` in ctx; a test for the 0.051 map-mark tolerance): if the batch 5 notes still list them, Fix in Task 13 after the merge (PlannerPace and PlannerMap belong to no group), with one assertion each in the integration test.

## Addition (controller, 22:36): the waypoint arrow, in group C with Task 10
- Another map: when the step is on another map, the arrow points at the next leg of the planned route (the zone exit, flight master, dock or hearth). It does not just say "another map". The leg comes from the plan's own steps, and from PlannerTravel's crossing points for a walk between maps. Test: a step two maps away points at the crossing on the current map.
- TomTom: when TomTom is loaded (`TomTom and TomTom.AddWaypoint`, through pcall) and the new switch `plannerTomTom` is on (default true), the guide sets a TomTom waypoint per step and hides its own arrow. The previous TomTom waypoint is removed with `TomTom:RemoveWaypoint(uid)`. With TomTom off or missing, nothing changes. Test with a stub TomTom.
- Look: the arrow is tinted with the theme's `@accent` via `ns:Paint`, goes brighter within 30 yd, and gives one short pulse on arrival. The minimap arrow texture stays. Reduced motion (the accessibility setting) skips the pulse.
- In-game checks: TomTom's API on Forever, and how the arrow reads in each theme.

## Addition (controller, 22:38): keybinds, in group C
- Bindings.xml entries, under the add-on's existing binding header, for "Guide: next step", "Guide: skip step" and "Guide: plan again". Each calls a guarded global function that does nothing while the guide is locked. The binding names are translated, but stay neutral ("Guide …") so a locked player sees nothing about the planner. Never in combat for anything that builds frames. Test the three functions.
