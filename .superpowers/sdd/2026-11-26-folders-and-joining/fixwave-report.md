# Fix wave: the final review of folders and joining (base 109c506)

Status: DONE. All 4 Important and all 8 Minor findings are fixed. None was left.

Commit: 984173f (code, tests, phrases). This report is in the commit after it.

## Important

**F-I1 — fixed.** The switch and the unlock now load the planner while you follow the plan.
- What changed in Folders.lua:
  - New `ns.FolderFollowCheck()`. When the planner folder is not ready, you are unlocked, the guide is on, the state is `GUIDE_PLANNED` or `GUIDE_TRIP`, and the login has happened, it runs `LoginLoad()`. That is a quiet load and a "loading screen" replan, or a silent wait when you are in a fight.
  - A failed attempt is not repeated. The reason: `GuideApplySwitch` also runs from `ApplyInstant` whenever any instant switch changes, and each retry would print the folder's message again.
- Guide.lua: `GuideApplySwitch` calls the check when `GuideOn()`.
- Folders.lua: registers `GuideRegisterLock("plannerFollow")`, which runs the same check on unlock.
- Test: the smoke test "folders fix: the guide switched on, or unlocked, while following the plan loads the planner". It covers:
  - switch off, log in, switch on → one quiet load and a replan
  - no second load
  - on a trip → a load
  - a written guide → no load
  - in a fight → no load and nothing said, then the load and replan once the fight ends
  - locked → no load; unlock with a saved plan → one load and a replan
- Seen failing before the fix ("…loads once and replans: 0").

**F-I2 — fixed (test only).** The window test now uses the real trip shape.
- "folders C: the planner window" now builds the trip with `ns:GuideStartTrip` from a planned state, then `GuideSkip` takes it to `at = 2`. It then asserts:
  - the summary
  - Stop on a trip: the plan is back at step 3, "Back to your levelling plan." was printed, the replan is "trip over", and `GuideStop` was not called
  - Stop off a trip: `GuideStop`
- Seen failing with 6c270f2's Stop join reverted ("Stop on a trip: not GuideStop"). Passes with the join.

**F-I3 — fixed.** Automatic loads say nothing.
- `ns:AfterFight(label, fn, quiet)` has a new third argument. With `quiet`, it prints nothing. The notice stays for everything the player asked for.
- `LoginLoad` ("Planner") and the catch-up page ("Catch me up") pass `quiet = true`.
- Also: AfterFight's frame now runs its jobs only on `PLAYER_REGEN_ENABLED`.
  - In the game that frame only ever gets that event, so nothing changes there.
  - The harness's `fireEvent` hands every event to every frame. So a job queued during `PLAYER_ENTERING_WORLD` ran at once, still in the fight, and was lost.
- Test: the smoke test "folders fix: the automatic loads say nothing in a fight". The login load and the catch-up page in a fight say nothing, wait (AfterFightCount +1), and run after the fight.
- Seen failing before the fix: "Planner: not during a fight, so it happens…".

**F-I4 — fixed.** The planner window lets go of the keys in a fight.
- PlannerWindow.lua: the window registers `PLAYER_REGEN_DISABLED`/`ENABLED`.
  - When a fight starts, it sets propagation to true and calls `EnableKeyboard(false)`.
  - After the fight, it calls `EnableKeyboard(true)` and sets propagation to true.
- `OnKeyDown` in a fight now passes the key on and turns the keyboard off as a fallback, instead of returning with propagation left off.
- All calls are pcall'd.
- Test: in "folders C: the planner window", with keyboard navigation on:
  - a used key, then the fight starts → the window does not hold the keys
  - a key in the fight → still not held
  - after the fight → the keyboard is on with propagation on, and Tab works again
- Seen failing before the fix ("a fight starts after a used key: the window must not keep the keys").

## Minor

- **F-M1 — fixed.** The trip summary's second line now depends on what the trip paused:
  - for `GUIDE_PLANNED`: "Your levelling plan waits."
  - for a written guide: `"%s" waits.` (a new phrase)
  - for nothing: no second line
  - Covered in the window test.
- **F-M2 — fixed.** "Plan my route" on a trip goes through `ns:GuideFollow(ns.GUIDE_PLANNED)`, which ends the trip and plans. Covered in the window test.
- **F-M3 — fixed.** GoldGo uses `LoadPlanner`'s result and calls `GoldTravel` only when the load is true.
  - Otherwise it shows the steps list. The stale "…not in yet" line is gone, because the folder's own message already says why.
  - Its 8 old translations are still in Locales.lua, unused. Removing them is optional cleanup.
- **F-M4 — fixed.** The Guide tab's status line shows "Gold trip: <title>" for a trip and "Route planner" for the plan, instead of the raw `\1` names. Both phrases already existed.
- **F-M5 — fixed.** In PlannerGo:
  - When the guide was switched off before the apply, the steps list is shown, but only while unlocked.
  - A job that died with an error is noticed: its key is gone while `building` is still set. It then gets "No way there was found: here are the steps." and the list.
  - Both are covered in "folders D: Go".
- **F-M6 — fixed.** A trip whose last step is only a zone (no spot) now ends with the note "Stay as long as you like, then Stop this trip." (a new phrase). Arriving no longer ends the trip. Covered in "folders D: Go". The in-game check is still worth doing.
- **F-M7 — fixed.** The test gaps:
  - The duo-ask test now checks that a held ask prints nothing, and that a lock during the fight drops the held ask, even after an unlock before the fight ends.
  - The login silence is covered by the F-I3 test.
  - Go against the real `PlannerContext` stays on the in-game checklist, as the review accepted.
- **F-M8 — fixed.** The stale "still to come (group C)" sentence in Folders.lua is dropped. The comment's list of stand-ins now names PlannerCatchUp too.

## Phrases

- The file is specs/plans/phrases/folders-fix.json, applied with add_tr.py: 2 phrases, 8 languages each, plus the English key.
- German uses "du".

## Checks (before the commit)

- `luacheck .`: 0 warnings, 0 errors in 147 files.
- Full smoke: `errors: no errors` in both passes, and in-game error messages: none.
- `python3 tests/forever_audit.py`: "Everything the add-on uses is in Forever."
- `pytest -k "seams or recorders or folder"`: 7 passed.

## Concerns

- **Config.lua.** The settings window (Config.lua:670–675) still has the propagation pattern from F-I4. It was out of scope and is rarely left open.
- **The catch-up silence.** The catch-up half of the F-I3 test was not seen failing on its own. The login half failed first, and the harness's event handling then also needed the AfterFight frame change.
- **In-game checks.** Check in game whether `EnableKeyboard`/`SetPropagateKeyboardInput` are allowed in a fight on Forever. Both are pcall'd.
