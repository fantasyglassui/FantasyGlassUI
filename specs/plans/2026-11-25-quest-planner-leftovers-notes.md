# Quest planner batch 6 (spec gaps and leftovers): build notes

Branch `quest-planner`. Task 1 started from b85a595 (BASE); Task 2 is c05b7a0 (SEAMS). The four groups were merged
`--no-ff` in order A (79bdad0), B (0f1f40e), C (1857c4c), D (0419371), then Task 13's fixes, translations and the
integration test were committed on top.

## Check in the game before release

One list, built from the brief and every group report. Tick each one off on a real Forever client.

Kills and experience (group A):
- [ ] `CHAT_MSG_COMBAT_XP_GAIN` arrives once per kill, before or after `PLAYER_XP_UPDATE`, within 1 s.
- [ ] Two kills less than a second apart, each with its own XP change, give no `killXP` sample (ruling R8: a burst of exactly one line and one change is the only sample). Check that ordinary solo pulls still give samples.
- [ ] The kill line's text in combat: is it hidden? A hidden line still counts as a kill (R9). Quest and exploration lines (`COMBATLOG_XPGAIN_QUEST`, `COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED`) never count.
- [ ] `UnitCanAttack("player", "target")` on a corpse: `Victim` needs it to be true; if a corpse reads false, no `killXP` sample is ever taken.
- [ ] The dead target's `UnitLevel` and `UnitClassification` read in combat, and what is hidden there. Hidden target values mean "no such target": the kill counts for the rate only (R2).
- [ ] A DoT or pet kill with an older corpse still targeted: the older corpse's level is used (review M-7, a known limit).
- [ ] `GetXPExhaustion` drops by the rested bonus on a rested kill, and `UPDATE_EXHAUSTION` order against `PLAYER_XP_UPDATE` (R4).
- [ ] A few real kills against `ns.PlannerKillXP` at level differences −3…+3 (the spec's check of the formula).
- [ ] A kill that levels you up is scored at the old level, even when `UnitLevel` lags (R10).
- [ ] `UnitIsAFK` and `PLAYER_FLAGS_CHANGED` when you go away and come back.
- [ ] `IsResting` in an inn, a capital and a village; the away state read at `PLAYER_LOGIN` and at every unlock (R6).

Questie's data (group B):
- [ ] Whether Questie's Forever data has the herb and ore objects and their spawns: the ids and minimum skill ranks in `ns.PLANNER_GATHER_OBJECTS` (40 primary ids, 18 alternate ore ids).
- [ ] Which Ooze Covered vein each of 123308, 123309 and 123310 is; whether herbs have alternate ids (1766xx).
- [ ] Memory: `collectgarbage("count")` before and after the first plan with gathering on (the cache keeps at most 6 maps).
- [ ] The walk's frames on a real Questie: no hitch at the first plan after login (Questie's pointer tables walked a slice at a time).
- [ ] Questie rebinding its tables after login: a replaced table is walked again (a table grown in place is caught almost always, not always).
- [ ] A timed quest's `C_QuestLog.GetTimeAllowed` at `QUEST_ACCEPTED` (both argument forms), and that an alt plans it as a timed run before taking it.

The route's words, docks and the panel (group C):
- [ ] The dock area ids (150, 513, 442, 702, 35, 392, 1637, 1497, 117) and their names from `C_Map.GetAreaInfo`; the zeppelin crossings.
- [ ] The Undercity zeppelin dock: it is stored as `{ map = 1458, x = 60.5, y = 58.5 }` on the city map, while the tower stands in Tirisfal Glades (1420). Does the 300 yd look ever see you there?
- [ ] Crossing times (Task 13 ruling): timed from the first look within 300 yd of the departure dock, so the wait is included. Check one boat and one zeppelin: is 300 yd enough to see you at both docks; does a normal wait plus ride stay under 900 s; are the recorded times near the defaults (270/240)?
- [ ] `C_Map.GetMapInfoAtPosition` on the taxi continent map ("Go to Arathi Highlands: fly to Refuge Pointe").
- [ ] "Plan again" fitting on the panel in all nine languages.
- [ ] The first line of the Guides list ("Plan my route", "following").
- [ ] The Guide tab: the new TomTom switch moves the later batch 4 and 5 sections down 26 px; check nothing overlaps.

The arrow and the keys (group C additions):
- [ ] TomTom's API on Forever: `TomTom:AddWaypoint(map, x, y, opts)` returns a uid, `RemoveWaypoint(uid)` clears it, `crazy = true` shows its arrow.
- [ ] How the accent arrow reads in each theme (tint through `ns:Paint`, desaturated texture), brighter within 30 yd, one pulse on arrival; reduced motion skips the pulse.
- [ ] The public arrow too (`/fgui way 45 62`, and a Journey waypoint), in each theme: 0.85 alpha beyond 30 yd and 1 within; still easy to see for every player.
- [ ] Standing a few yards from a dock or a flight master (waiting for the boat): the arrow points once at where you stand with the leg's words, never pulses, and does not point again; with TomTom, no new waypoint every second.
- [ ] Another map: the arrow points at the flight master, the dock, or the edge of the map on the straight way. Where mountains block the straight way, is the edge point a sensible "exit"? Standing at the edge gives no repeated pulse.
- [ ] Key bindings: the three "Guide: …" names translated in the key bindings window; nothing happens while locked or in combat.

Batch 5 files and the audit (group D):
- [ ] "Find a group" with a title cut to nothing: "LFG <record name>, Zone" or "LFG #id, Zone", never "LFG , Zone".
- [ ] Two accounts: a duo plan received while your level can't be read is held and tried again every 5 s, then dropped quietly after 6 tries.
- [ ] Two accounts: many steps inside an instance while messaging is held: only the newest AT is sent afterwards, the plan arrives whole.

Carried from earlier batches (still open):
- [ ] Mount vendor ids, riding skill line 633 (batch 2).

## Release: the public changes this batch brings

Everything else in this batch is behind the guide's lock. These three reach every player:
- The waypoint arrow (`MapExtras.lua`): tinted with the theme's accent, 0.85 alpha beyond 30 yd and 1 within, one short pulse on arrival (none with reduced motion); a plain waypoint clears after the pulse and still says "You have arrived.".
- Three key bindings (`Bindings.xml`, names set in `Guide.lua`): "Guide: next step", "Guide: skip step" and "Guide: refresh the route", under the add-on's header. They show in every player's Key Bindings window and do nothing while the guide is locked, off, or in combat. Kept, with this wording (controller's ruling).
- One saved default (`Core.lua`): `plannerTomTom = true`. Nothing reads it while the guide is locked.

## Rulings as made or changed

The plan's rulings stand, with these additions and changes.

Task 13 (merge):
- **Crossing time (changes group C's I4).** A crossing is timed from the FIRST tick within 300 yd of the departure dock, not the last, so the recorded seconds hold the wait at the dock, the same as the defaults in `PLANNER_CROSSINGS`. A stay at a dock ends at a tick away from every dock; coming back starts a new stay. The 60…900 s bounds stay, so a long wait plus the ride is not timed (it still counts as crossed).
- **Session skips.** `ns.PlannerSessionSkipReset()` runs at `PLAYER_LOGIN` (a frame in PlannerRoute.lua) and inside `ns:PlannerStart()`. `PlannerStart` is the one fresh start, so this covers "Plan my route" in the Guides list and in the catch-up list, `/fgui guide plan`, and the duo's fallback to planning alone. `ns:PlannerReplan` (the skip key, "Plan again") keeps them.
- **A done member (changes Task 1's ruling 2).** A done id no longer drops its whole exclusive set. A record whose own `exclusive` list names a done quest (or that is itself done) is dropped; one is still chosen from the rest of the set by the usual order. A member joined only through another quest's list stays takeable. Logged members still keep only the logged ones.
- **The group-only count.** It runs `PlannerExclusiveKeep` over the group-only records plus the logged planned records, and counts only group-only ids. A group-only quest that one of your logged quests names is not counted. An unlogged solo partner is still not compared, so Task 1's ruling 1 example (9601 solo, 9602 group: count 1) holds.
- **`ns.PlannerTimedQuest` errors.** The route still treats the quest as not timed, and writes the first error of each plan to `ns.errors` ("Planner timed quest: …"). The function must neither yield nor error.
- **German (final review, M9).** The guide and planner screens are in one register: "du", "dein", and "Anleitung" as the one word for a guide ("Questanleitung", "Anleitungen"). Changed: the usage lines, the Guides list and its title, the editor's help, the recording lines, "Du folgst keiner Anleitung (mehr)", the Guide tab's name and switch lines, the coming-soon lines, the step labels "Geh zu" and "Erreiche Stufe", and the three binding names ("Anleitung: …"). Left for the polish check: the rest of the public add-on, and "That is you." (shared with Group.lua). "Boss guide" (the boss journal) and the Home page's "ask the guide" are other features and keep their words.
- **German (Task 13).** Planner phrases use "du": the formal-singular ones were changed (the LFG chat line, "You stopped planning together", the hearthstone, flight, boat and sail step labels). "Ihr"/"euch" stay where they are the plural of "du" (two players planning together: "%s möchte eure Route gemeinsam planen", "Zwischen euch liegen %d Stufen"). Phrases shared with public code ("That is you.", used by Group.lua too) and the written-guide UI were left as they are.
- **The batch 5 carried items** (`paceTimed`/`paceStyled` frozen in ctx; the 0.051 map-mark test) were already fixed in batch 5's merge (its notes, "Fixed during the merge"), so Task 13 adds nothing for them.
- **Integration test.** The real runner and the real `ns.PlannerContext`, reading a fake Questie, with only travel and the log overridden. Between the first plan and "Plan again" the test forgets the remembered zone (`rec.zone`), because a planned zone is kept until you gain levels and the ratio could not move it otherwise. It also sets `ns.PLANNER_BUDGET_MS = 0` for the lock part so the plan is mid-run when the guide is locked.

Group A (Tasks 3–5), from its report: R1 two calls per kill (rate at the line, xp at the pair); R2 hidden target values are "no such target"; R3 the player level read before the XP change; R4 rested rises taken at once, falls at the next XP change; R5 a grouped or hidden line breaks the rate chain, a lock forgets the recorder state; R6 (replaced) the away state read at `PLAYER_LOGIN` and at every unlock (`GuideRegisterLock("questclock")`), then kept by the events; R7 `PlannerKillRatio` takes `elite` only for the formula; R8 drop, don't split, a burst of lines and changes; R9 quest and exploration lines are not kills, a hidden line is; R10 a rollover is a fall in XP or a rise in level, the stored level at least the old one + 1. The seams-test line `ns.PlannerRecordKill ~= nil` is removed (kept removed in the merge).

Group B (Tasks 6–8): a walk gives "not ready" on a `next` error, a repeated key, a changed `#t`, a replaced table or a missing one; table identity by `==`; a failed walk does not mark the source changed; bad triggerEnd spots are dropped and the objective kept; gathering is not cached while Questie is not ready, a failing object is left out, Questie nodes are not merged with each other; `src.ids()` hands out a copy; `gatherCache` keeps at most `PLANNER_GATHER_MAPS = 6` maps; the timed memory is `ns.root.plannerTimed[id] = { secs, seen = day }` (an older plain number reads as never seen), capped at 500, the oldest day first, then the lower id. Accepted: this replaces the plan's `plannerTimed[id] = seconds` shape, and `plannerTimedOrder` is gone.

Group C (Tasks 9–11 and the additions): "Go to" needs both zones known and different; a dock with no readable name gives no text (the panel's "Take the boat"); an unreachable hand-in drops only the hand-in, its experience and time (`HandedInAway`); a crossing not timed still counts as crossed; `Trip` restores the hearth on failure; the arrow points at a plan's own travel steps as they are, and at a worked-out leg (flight master, dock, or the map's edge) for a walk between maps; the keys: next = `>`, skip = passed over plus a replan on the plan (`ns.PlannerSessionSkip`), plan again = the panel button, none in combat; the panel height reset on show; "Plan again" goes through `ns:GuidePlanAgain`, not a seam. TomTom is read as plain `TomTom`, listed in `NOT_THE_GAMES`.

Group D (Task 12): the vendor stop with supplies whose vendors never meet gives one `vendor` step (at the first supply's vendor), not two, as the code has always done; "queued or running" is tracked in PlannerDuo (`stateQueued`); N3 deduplicates AT only; the `#id` fallback is never cut. `ApplyPlan` holds a plan while your level can't be read and retries every 5 s, at most 6 times.

## Deferred minors: the ledger as built

**Batch 1**
- triggerEnd spots skip validation: Fixed, Task 6 (same check as `Spots`; tested).
- Tests miss `ready()`, Tags, triggerEnd, npcDrops, the log `quest()`: triggerEnd tested in Task 6; the rest Keep (covered by batch 3–5 tests).
- Tags looked up per record: Keep.
- Audit allowances add-on wide: Fixed, Task 12 (`FILE_METHODS`: two methods allowed only in PlannerSource.lua).
- Log counts matched by objective index: Keep.
- `real.bind` naming nit: Keep.
- Stale dock `since`; take-off not cleared: Fixed, Task 11 (`ControlLost` clears the take-off; the dock tick rewritten), and Task 13 (timed from the first look at the dock).
- `PaceRecord` duplicated in Travel: Fixed, Task 11 (`CharData`, a guarded call to `ns.PlannerCharRecord`).
- `rec.level` not nil-guarded: Fixed, Task 1.
- `Spread()` untested: Fixed, Task 4 (through the way kills; `o.spread` cached once placed).
- Unreachable turn-in counted; `first` cleared on a failed Go; leftover learnflight steps: Fixed, Task 11.
- O(P²) in `LearnOnWay` and `PlannerHubs`: Keep.
- A sail has no `why.saves`: Keep.
- A turned-in quest shows briefly before `QUEST_REMOVED`: Keep.
- `SetHeight` every Draw: Fixed, Task 10 (only on a change; reset when the panel is shown).
- No end-to-end "why" panel test: Fixed, Task 9 (the panel's step text with "(saves ~3 min)").
- Unused usage-line keys: Fixed, Task 13 (the old "Quest guide: /fgui guide … next, back, off." usage line, without "plan", removed from all 8 tables; no other `/fgui guide` key is unused).
- `DockTick` runs whenever unlocked: Keep.
- German mixes du and Sie: Fixed, Task 13 (see the ruling).

**Batch 2**
- An empty flag scan stays cached: Fixed, Task 6.
- Mount vendor ids, skill line 633: Keep, in-game checks.
- `TRAINER_SHOW` reads places outside the coroutine: Keep.
- Detour not shown under Show why: already fixed (`WhyText` shows "(+N s detour)", Guide.lua).
- A plan with no quests gets no stops: Keep.
- Any `do` between a hand-in and `train` stops holding: Keep.
- `summary.seconds` not adjusted for held hand-ins: Keep.
- Stray `unspent = 1 + 0`: Fixed, Task 13 (the test sets `unspent = 1` and keeps its own currency stub, which reads it).
- Disjoint-places branch untested: Fixed, Task 12 (tested; one vendor step, group D's ruling).
- Any mount seen marks riding known: Keep.
- `ridingTrainer` not cleared on close: Fixed, Task 1.
- Nodes have no respawn memory: Keep.
- Mail "gone" seen only at plan time: Keep.
- Legs over 8000 yd sampled for 8000 yd: Keep.

**Batch 3**
- Grinding leaves elites out for a party: Keep.
- A timed quest not yet in the log: Fixed, Task 8 (with Task 2's `IsTimed`).
- A fit class quest costs a second route build: Keep.
- Hub scoring sees the whole rested pool: Keep.

**Batch 4**
- "Read the route aloud" greyed by alpha only: Keep.
- PlannerPace wraps `GuideUnlock` / `GuideLock`: Fixed, Task 2 (lock registry).

**Batch 5**
- "LFG , Zone" from an empty title: Fixed, Task 12.
- `stateAgain` not cleared when the job dies: Fixed, Task 12.
- PlannerDuo wraps `GuideUnlock` / `GuideLock`: Fixed, Task 2.
- The friend's ask page counted from receipt: Keep.
- `|n` to a space and a dead test assignment: already fixed (eccc6b5).
- Seams-test cosmetics: Keep.
- `paceTimed`/`paceStyled` in ctx; the 0.051 map-mark test: already fixed in batch 5's merge; nothing added.
- From group D's sweep of the batch 5 notes: N3 (the 200-message cap dropping plan pieces): Fixed, Task 12 (AT deduplicated). N2 ("Levels 24 → 24"): already fixed. N1 (`pos.questGuide` in a locked player's code): already fixed (6368c66). The friend's "questie 0" while Questie loads: already fixed (batch 5 M1). "%s: done" for a partner ahead: a batch 5 ruling, Keep. The hidden-text duo test calling `PlannerDuoEvent` directly: Keep (test wording). `ApplyPlan` with an unreadable level: Fixed, Task 12 review.

**Batch 6 reviews**
- Task 1–2 Minor 1 (a set member linked only through another's list dropped by a done member): Fixed, Task 13.
- Task 1–2 Minor 2 (`PlannerTimedQuest` errors swallowed): Fixed, Task 13 (logged once a plan).
- Task 1–2 Minor 3 (the group-only count reads only group-only lists): Fixed, Task 13.
- Group A M-1 (the seams-test line outside region A): accepted; kept removed.
- Group A M-7 (an earlier corpse can supply the level): Keep, a known limit, noted at `Victim` and in the in-game list.
- Group B Minor 1 (in-place growth caught only by heuristic): Keep, stated in a comment above `IdList`.
- Group B Minor 2 (alternate object ids): ore alternates added; Ooze Covered ids and herb alternates in the in-game list.
- Group B Minor 3 (`gatherCache` size): Fixed in B's review round (6 maps); memory in the in-game list.
- Group B Minors 4–7: Fixed in B's review round.
- Group C Minors 1–6 and Important 1–5: Fixed in C's review round; Important 4 (crossing time) changed again in Task 13. Important 1 (the arrow re-pointing): the map-edge case was fixed in C's round; the dock and flight master case in the final review round (I1).
- Group D Minors 1–3: Fixed in D's review round.

**Final review** (0 Critical, 3 Important, 10 Minor), all fixed in one round, each with a test in "13.6 leftovers: final review fixes" where it can be tested:
- I1: a first run leg shorter than `GUIDE_NEAR` counts as arrived (the arrow points where you stand, with the leg's words, as a spot you pass through), and `LegReached` remembers the spot it reached, so it is not pointed at again on that map. Test: 8 yd from the dock and from the flight master, 10 ticks: no re-point, no pulse, no new TomTom waypoint.
- I2: `HubSlots` skips a timed run's accepts and dos (with only those, the slot is after the run's last hand-in), and no slot inside a timed run is used, by the hub match or by the least-travel search. Test: a stop near the hub, beside the run, and off the route.
- I3: reaching the far dock always sets `crossed`; the 60…900 s window only decides whether the time is recorded. Test: 1000 s, crossed and not timed.
- M1: the arrow's leg is not worked out in a fight (the arrow keeps what it shows; the 1 s look points once the fight is over), and it is kept per step and map (worked out again after a leg is reached).
- M2: logged records a hook dropped (a session skip) go to `PlannerExclusiveKeep` as blockers: they block their partners and are never kept.
- M3: the duo friend's list holds every member of an exclusive set it could take (`ctx.allExclusive`); the leader picks one.
- M4: on a duo friend, "skip step" only passes the step over here and says "Skipped here; %s plans the route."; no session skip, no replan. The leader's skips are unchanged.
- M5: an untaken timed quest whose hand-in can't be reached from its hub is not taken there at all.
- M6: the two kill-line patterns are made once per format string.
- M7: kept, listed under "Release" above.
- M8: 0.85 alpha beyond 30 yd; the public arrow added to the theme checks.
- M9: the German register pass (see the ruling).
- M10: the three in-game checks added.

## Merge conflicts outside a region

- None. All four merges auto-merged with no conflict.
- `tests/forever_audit.py`: group C's `"TomTom"` line in `NOT_THE_GAMES` and group D's `LIBRARY_METHODS` / `FILE_METHODS` change both kept (they touch different lines).
- `.luacheckrc`: only group C changed it (four names in `globals`, `TomTom` in `read_globals`). `regen_rc.py` after the merges: no change.
- `tests/smoke.py`: regions A, B, C, D in order before `try("Delayed calls"`; group A's removal of the seams-test line kept. Task 13's tests ("13.6 leftovers: merge fixes" and "13.6 leftovers: together") sit after region D. Outside the regions Task 13 changed: the seams test now expects the logged `PlannerTimedQuest` error (and removes it); group C's crossing test comment (a stale duplicate comment and its dead assignment removed); batch 2's talent test (`unspent = 1`).
- Group C touched shared files the plan gave no group: `FantasyGlassUI/Core.lua` (the `plannerTomTom` default), `FantasyGlassUI_Options/Bars.lua` (the switch), `FantasyGlassUI/Bindings.xml`, `FantasyGlassUI/MapExtras.lua` (the arrow's look). No other group touched them.

## Checks (Task 13, final tree)

- `luacheck . -q`: 0 warnings / 0 errors.
- smoke: `syntax: all 137 files OK`, `errors: no errors` twice.
- `forever_audit.py`: exit 0, "Everything the add-on uses is in Forever."
- `secretaudit.py`: 0 lines compared a hidden value.
- `lockaudit.py`: no protected call in combat (the report lists only our protected frames).
- `node tests/plan_reader_check.js`: 20 codes OK. `python3 tests/sitecheck.py`: exit 0.
- pytest: 9 passed (batch 5's 8 and `test_guide_seams_listed`), run last.
- Release guards: `docs/` unchanged since BASE; no "planner" in the tracked README, CHANGELOG, RELEASE, add-on .md, docs, site-src or wiki (the only hits are ignored `site-src/__pycache__` files that hold the worktree's path); no `ReloadUI` / `SendChatMessage` and no `local original = ns[` in `Planner*.lua`; `/fgui help` unchanged.
- `missing_tr.py`: two new untranslated literals over SEAMS, neither shown to players ("again", a replan reason; "ore", from a comment).

## Checks (final review round)

- `luacheck . -q`: 0 warnings / 0 errors. smoke: `syntax: all 137 files OK`, `errors: no errors` twice. `forever_audit.py`: exit 0.
- `secretaudit.py`: 0 lines compared a hidden value. `lockaudit.py`: no protected call in combat.
- `node tests/plan_reader_check.js`: 20 codes OK. `python3 tests/sitecheck.py`: exit 0. pytest (last): 9 passed.
- Batch 2's travel test now expects a 5 s loading screen between the docks to count as crossed (not timed), by the I3 ruling.
