# Quest planner batch 4 (how it feels to use): build notes

Kept from the build ledger when its workspace was removed. Built as one seams task (Task 1) and four groups in
parallel worktrees (A map, B panel, C pace, D records), merged into `quest-planner` with no git conflict, then
checked and fixed together (Task 9).

## Check in the game before release
- The map line and hub marks on the real WorldMapFrame: `ScrollContainer.Child` as the canvas, `CreateLine` with
  `SetStartPoint`/`SetEndPoint` on the holder scaled to 1/canvas scale, `SetThickness` constant on screen; a zoomed
  map, a pan, zooming in and out while the map stays open (the 0.5 s tick redraws on a new scale); the line over a
  zone map; a continent view shows no line.
- The map ids of steps against the shown map (a city or cave sub-map step on its zone's map shows no stop).
- Hub marks under and over the game's own pins (frame level), clicks on a mark, and `SetPropagateMouseClicks` (via
  pcall) letting a right click on a mark zoom the map out; up to 80 marks at 20 px.
- "Plan from here": the question window, the replan, the picked hub first; a pick made in combat waits and is used
  by the plan after the fight (it ages only out of combat with nothing queued, 120 s).
- The panel's "..." button: where it sits, how the menu is sized, that `GLOBAL_MOUSE_DOWN` closes it.
- The preview opening over the first plan after "Plan my route" (also when Questie was still loading and the plan
  lands later); "Follow" closes it; "Plan again" opens the Guide tab through `ns:ToggleConfig("guide")` (the
  load-on-demand stub in Core.lua, then `O.Open("guide")`).
- "Why this?" on a planned step's right-click menu, and its page.
- Finish the zone: the zone-level parent walk (`C_Map.GetMapInfo(...).parentMapID` up to mapType 3) from a city or
  cave, and Questie's `zoneOrSort` through `ZoneDB:GetUiMapIdByAreaId` for the zone's quests; "Zone done" once; the
  Guide tab's goal button changing back to "Goal: Level up" while the tab is open.
- The time you have: `/fgui guide plan 30`, `plan 0`, plain `plan`; the plan ends at an innkeeper or a known flight
  point within 300 s, then "Good place to stop"; the deadline clears when that note is ticked.
- Break reminders: only at a stopping place, never in combat or mid-hub, at most once an hour; the session start
  across a /reload.
- Catch me up and where you left off: `PLAYER_ENTERING_WORLD`'s isInitialLogin / isReloadingUi on Forever (an
  initial login only, never a reload or a loading screen, never a character's first login); that the "loading
  screen" replan at login does not reset the step before the left-off line reads it (the line is worked out in the
  event, the replan only queues).
- Read aloud: `ns:Speak` timing against step changes (the panel's step, written guides too), only while
  Accessibility's reading aloud is on; the chime's caption ("Step done") with captions on.
- Keys: Tab and Enter on the guide's menu and its pages (`FantasyGlassUIGuideMenu`, `FantasyGlassUIListPlan*` in
  `ns.WINDOW_KEYS_FRAMES`); `/fgui guide keys` opening the panel's menu with Back, Next, Guides and the panel actions.
- Level times: the 10 s play clock against /played across a login, a /reload and a loading screen (the first tick
  after a load adds nothing, a tick at most 30 s); PLAYER_LEVEL_UP saving the old level; the first level after install
  marked partly timed; the "Levels" part of `/fgui stats` and the run log only while unlocked.
- Race your best: the line on the panel moving with the clock (redrawn every 10 s while the panel is shown).
- Save as guide: the saved guide in the guide list, its name ("Zone 8-10", then " (2)"), following it as a written guide.
- The Guide tab's four new sections (map, panel, pace, records), the sliders' feel (step 10), and the options search
  while locked (no Guide tab control is listed; fixed in Task 9, see below).

## Rulings made during the build
- Ruling: seams first: Task 1 added every hook the groups needed (planner hooks context, window, xp, zone, rank,
  route, applied; the panel's lines, title parts, step and panel actions, advance hooks, command words) so no group
  edited Planner.lua, PlannerRoute.lua or Guide.lua.
- Ruling: with "plan from here" set, lead-in entries score -1 (no detour after the picked hub) — costs: a class quest
  waits until the next plan.
- Ruling: default horizon = 2 zone hubs + the lead-in when there is one (batch 3 behaviour); a hook's own horizon
  (`ctx.horizonSet`, the time limit's 6) counts the lead-in — costs: none.
- Ruling: "Save as guide" and "Preview" are offered only for a plan the planner made that earns something (a preview
  or a saved copy of an empty plan says nothing).
- Ruling (Task 9): "start" is the reason only for the start's own plan: replans that replace the start run before it
  applies, and Questie still loading, keep it the start's however late it lands; a failed start run ends it (the next
  plan has its own reason and opens no preview) — costs: no preview after a failed first plan.
- Ruling (Task 9): the "plan from here" pick goes with the next plan that applies (used or not); until then it ages
  only while nothing is queued or being made and you are out of combat, and is dropped after 120 s of that.
- Ruling (final review, replaces Task 9's): a style preset is named by speed and story only (100/x/0 Speed,
  40/x/100 Story, anything else Custom), whichever control set it: safety is yours to choose, as spec #34 says. The
  panel shows "Style: %s" whenever the weights are not 100/0/0, so Speed with safety 30 says "Style: Speed". The
  picker's own Custom stands until a slider moves (the sliders name the style by `ns.PlannerStyleOf`) — costs: none.
- Ruling (Task 9): hubs that Speed/Safety/Story sink to a score of 0 keep the order of their rates (a millionth of
  rate / best rate), not the order of the list.
- Ruling (Task 9): the zone goal's context hook is registered for good (it checks the goal), so a goal saved before an
  unlock works at once; the goal ends when no hub is left on the goal map, when every counted quest is done (a count
  of 0 never ends it), or when there is nothing at all to plan; with the quest log as the source it neither counts
  nor ends.
  (Final review: it says "Zone done: %s" only when every counted quest is done; when doable quests are left, out of
  reach or above your level, it says "No more quests in %s at your level".)
- Ruling (Task 9): changing a style, a slider or the zone goal replans with the reason "settings".
- The spec's values as built: map line = the current hub's loop and the trip to the next (at most 30 stops); hubs on
  the map at most 80, brightness worst to best, tiers 1-3 with colour vision; time to level only with 3+ pace
  samples; time you have: horizon 6, stop within 300 s; catch-up after 14 days; break reminders off, 2 hours, once an
  hour; race your best off, "level with your best" within 60 s; read aloud on (only with reading aloud on); where you
  left off 120 s.

## Task 1's batch 3 leftovers
- Task 1 also brought in three batch 3 leftovers its brief did not ask for (flagged by its review): a QUEST_REMOVED
  followed by QUEST_TURNED_IN within a second counts as a hand-in; `LogFits` / `summary.logFits`; and an unplanned
  QUEST_ACCEPTED replans (Planner.lua, the quest events).

## Fixed in Task 9 (merge and checks)
- Tests: the seams test counts its own hook key and checks the "..." button against the panel actions that apply
  (hidden when none does, the guide locked); the save-as-guide test looks for its own entry. No group's tests needed a
  horizon change after the merge.
- Translations: the four groups' phrase files applied in every language; `missing_tr.py` lists only internal values
  ("start", "story", "\1end") beyond what was there before.
- Plan from here: the pick no longer expires while a replan is queued or in combat.
- Race your best: the 10 s redraw only while unlocked and the panel is shown.
- Speed or story: the preset name comes back; the button text is "Style: %s"; the danger's escort test is the
  route's own (`ns.PlannerIsEscort`); the story-100 window guards the level.
- Finish the zone: the permanent context hook (no false "Zone done" after a mid-session unlock), the count-of-0 and
  nothing-to-plan cases, the log source, `ns.PlannerMapName` shared with the Guide tab, the button redrawn on "Zone
  done"; each way the goal ends is tested on its own.
- Guide.lua: `ns.GuideSkippedText` / `ns.GuideMovedText` (from a summary); the preview uses them instead of copies.
- The options search listed the Guide tab's controls (Speed, Story, Race your best, ...) while the guide was locked;
  `ns:SearchOptions` now leaves the Guide tab out while locked.
- New tests: "13.4 feel: together" (a zone goal, Story and 30 minutes through the real runner: preview once, time to
  level in the title and in where you left off, why this, map stops and marks, the race line, the level clock, save
  as guide, then Plan from here over the goal for one plan); unlocking brings the time list back at once (a stand-in
  hash, no phrase written); the options search while locked.

## Fixed after the final review (every finding)
- The "applied" hooks run each through pcall, after `ns:GuideSetPlan`: a failure goes to `ns.errors` as "Planner hook
  <key>: ..." and the next hook still runs (a failing map drawing no longer skips the preview or the goal's end).
- Style naming per the ruling above; the panel's line whenever the weights are not 100/0/0.
- The time limit and the style share one "context" and one "rank" hook (key "pace"): the time cut always runs
  first, then the style works out its best rate over the hubs left (the route hook stays "paceTime", the window hook
  "paceStyle").
- `ns.PlannerContext` copies every hook list into `ctx.hooks` (`ns.PlannerHooksFor`), and Build copies them when a
  context has none: a hook added or removed while a plan is being made changes the next plan only. Clearing the time
  limit (the "Good place to stop" note ticked, `plan 0`) replans with the reason "time".
- The default plan's extra round is the lead-in's alone: a lead-in kept out ("plan from here") takes no third zone hub.
- Read aloud: the advance hooks get a sixth argument, `resumed` (the first advance after a login or /reload, on the
  step you were on); Records does not read that step aloud.
- "Why this?": a slower hub that Story or Safety chose says "Chosen for its story" or "Chosen as safer" (the rank's
  story and safety terms are kept in `summary.taken[n].parts` and its `beat.parts`; a hub a rule put first still says
  "Taken first").
- The zone goal keeps the cheap level pre-filter: the goal map's quests pass it by id (`ctx.windowPass`, from
  `src.mapQuests`); with a source that has no map list the pre-filter's lower end drops to 1 as before.
- Unlocking the guide mid-session starts saving the last-login time at once (no stale catch-up page next login).
- `summary.hubs` keeps only map, x, y (to 0.1), rate (to 0.0001) and quests; `summary.taken[n]` has x, y rounded the
  same way and its quest count, so a taken hub's mark shows "%d quests".
- Three new phrases in all eight languages: "Chosen for its story", "Chosen as safer", "No more quests in %s at your
  level".

## Minor findings deferred
None that code can fix. Left as they are, by design:
- The Guide tab's "Read the route aloud" switch is greyed by alpha only while reading aloud is off (it still works).
- PlannerPace wraps `ns:GuideUnlock` / `ns:GuideLock` to register its entries at once (tested both ways); a seam
  list in Guide.lua would be sturdier if a second file ever needs the same.
