# Quest Planner, Batch 4 (seeing and feel) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This plan is built for parallel execution**: Task 1 runs first and alone; Tasks 2–8 run in four groups (A, B, C, D), each in its own git worktree at the same time; Task 9 merges them and checks everything. Read "Parallel build and merge" before starting.

**Goal:** You can see the plan and it fits how you play: the route and the hubs on the world map, the time to your next level, why a step is there, a preview of the next hour, a zone to finish, a plan for the time you have, a speed/safety/story balance, break reminders, a catch-up page after a long break, where you left off, level times and a race against your best, the plan saved as a guide, the route read aloud, and a caption with the step chime.

**Architecture:** One short sequential task adds *seams*: hook lists in the planner (context, level window, experience term, zone pick, hub ranking, route pass, plan applied), data the route already computes kept on the summary (every hub's rate, each taken hub's rate and the hub it beat), and registries on the guide panel (extra lines, a title suffix, step and panel menu entries, a hook when the step changes, `/fgui guide` words). Each group then builds its features in **its own new file** that only registers with those seams, so the four groups touch disjoint files except for marked regions of four shared files.

**Tech Stack:** Lua 5.1 (WoW Forever, interface 16001), the add-on's helpers (ns:ShowList, ns:CreateCheckbox, ns:CreateSlider, ns:Speak, ns:Caption, ns.MapDotOffset, ns:ColorVision), Questie internals through `QuestieLoader:ImportModule` (pcall'd), tests in `tests/smoke.py`.

**Spec:** `specs/2026-11-21-quest-planner-design.md`, **Build order, batch 4**: items #5, #8, #9, #15, #16, #17, #18, #28, #29, #30, #32, #33, #34, #37, #38, #39, #43. Earlier plans and notes in `specs/plans/` (`*-core*`, `*-stops*`, `*-choices*`).

## Global Constraints

- Everything in batches 1–3's Global Constraints still binds: Forever audit; `luacheck . -q` 0 warnings; smoke.py `errors: no errors` twice; never plan in combat; 4 ms slices; `ns.PlannerYield()` only in plain loops (never inside `pcall`/`Try`, a sort comparator or a gsub callback: WoW runs Lua 5.1, which cannot yield across them); all phrases in 9 languages; Questie read-only through pcall; everything behind `ns:GuideUnlocked()`; nothing about the planner in /fgui help, README, site, wiki or changelog; the unlock phrase never in any file (tests unlock with `ns.GuideUnlocked = function() return true end`); commits by DustyMouse (`git -c user.name=DustyMouse -c user.email=fantasyglassui@users.noreply.github.com commit`) with no attribution lines; implementers never push.
- Branch `quest-planner` in `/home/claude/fantasyglassui-planner`; group branches `feel-a` … `feel-d` in their own worktrees (below).
- Saved data: per character through `ns.PlannerCharRecord(true)`; per account under `ns.root.planner*`; created only when writing. The spec puts the time-to-play choice, the slider values, the zone goal and the last login time **per character** (`ns.PlannerCharRecord`), not in `ns.db`.
- Settings stay on the Guide tab (the player's ruling of 25 Nov: the planner's own button and window come once it is finished). Each switch: on by default unless stated. Changing one that changes the route calls `ns:PlannerReplan("settings")` (it only acts while following).
- Values from the spec: the map line covers **the current hub loop and the trip to the next**; Speed preset **100/0/0**, Story preset **40/0/100** (speed/safety/story; the preset keeps your safety value); story **at 100 is a rule**, below 100 a weight; catch-up after **14 days or more** away; break reminders **off** by default, default **2 hours**, **at most once an hour**, never in combat, never mid-hub; race your best **off** by default; read aloud **on** by default but only while `ns.db.readDialog` is on; the chime: on by default (it is the existing "A sound when a step is done", `guideSound`).
- Per-task checks (each task's last step before the commit): `luacheck . -q` → 0 warnings; `cd FantasyGlassUI && python3 ../tests/smoke.py` → `errors: no errors` twice; `python3 tests/forever_audit.py` → exit 0; `python3 tests/secretaudit.py` → `0 lines compared a hidden value`. pytest and lockaudit run in Task 9 only.
- Translations: groups do **not** run `add_tr.py` (it inserts every phrase at the top of each language table, so four groups would always conflict). Each group writes its phrases, in add_tr's format (`{ "English": [de, fr, es, ru, pt, it, ko, zh] }`), to its own file `specs/plans/phrases/feel-<a|b|c|d>.json`; Task 9 applies them.

### Rulings (the spec leaves these open)

- **Seams first.** One sequential task (Task 1) adds every hook the groups need, so no group edits Planner.lua, PlannerRoute.lua or Guide.lua; the groups' own code lives in four new files.
- **Time to level (#5):** `minutes = (UnitXPMax − UnitXP) ÷ (summary.xp ÷ summary.seconds) ÷ 60` (the summary's seconds are already at your pace). Shown only when the pace has **3 or more** samples (`ns.PlannerCharRecord().pace.samples`), `summary.xp > 0`, `summary.seconds > 0` and both experience values readable.
- **Why this (#33):** the numbers of the step's hub (`summary.taken[step.hub]`); "the best thing it beat" is the runner-up hub in the round that picked it, named by its first quest; a stop step (no hub) shows its own `why` (saves, detour).
- **Preview (#29):** the plan is applied at once (no second "not yet followed" state); on the first plan after `ns:PlannerStart()` the preview page opens over it. "Follow" closes the page; "Plan again" opens the Guide tab (style, group quests, time you have).
- **Finish the zone (#37):** the goal is one uiMapID (the zone-level map you are in when you pick it: `ns.GuideHere()`'s map walked up through `C_Map.GetMapInfo(...).parentMapID` to `mapType == 3`). In that zone the level window's lower end drops to 1 (the upper end stays level + 2). Progress counts the zone's non-repeatable quests that are doable or done. When no hub is left on the goal map, the goal clears, "Zone done: %s" is said once, and the planner goes back to leveling.
- **Time you have (#18):** a deadline per character (`time()` + minutes × 60). While set, the horizon is **6** hubs and a hub is taken only if `seconds so far + its travel + its seconds ≤ time left`. The plan then ends with a `goto` to the nearest innkeeper or known flight point reachable in what is left (at most 300 s of travel), then `note | Good place to stop`. Time already up: the plan is just that stop place and the note. `/fgui guide plan 30` sets 30 minutes, `plan 0` clears it, plain `plan` uses the Guide tab default (none, 30, 60, 90, 120 min). The deadline clears when the note step ticks.
- **A stopping place** (for #18 and #39): `steps[at]` is the first step of a new hub (`steps[at - 1].hub ~= steps[at].hub`) after a hand-in, or the step just done was `fly`, `sail`, `hearth` or `bind`, or the plan is at its end.
- **Speed / Safety / Story (#28, #34):** each round's hub score becomes `S × rate / bestRate + T × story(hub) − F × danger(hub)` with S, F, T = slider ÷ 100 and `bestRate` the best rate of that round (Speed 100/0/0 gives the old choice exactly). `story(hub)` = mean over its quests of 1 (in the zone's main chain), 0.5 (in another chain: `rec.nextQuest` or a non-empty `rec.pre`), 0 otherwise; the main chain is the largest set of the zone's candidates linked by `nextQuest`/`pre`. `danger(hub)` = min(1, (elite quests + 0.5 × kill objectives whose `mobLevel ≥ level + 3` + 0.5 × escorts + deaths recorded within 150 yd at this level or the one before) ÷ 2). Story **at 100** also lowers the level window to **level − 10** for chain quests. The style picker sets the presets; moving a slider makes it "Custom".
- **Break reminders (#39):** the switch lives on the Guide tab only, not in Accessibility's Calm part, because that page is public and the planner must not show there. Play time is the session's (`ns.plannerSessionStart`, which survives reloads).
- **Catch me up (#38):** "away" is measured from the per-character `lastSeen` (`time()`, saved every 60 s and at PLAYER_LOGOUT); only at an initial login (`PLAYER_ENTERING_WORLD` with isInitialLogin), never a reload, never on a character's first login. "What is new" lists the first line of each `ns.whatsNew` entry newer than the version saved at logout (at most 3).
- **Level times (#17):** a play clock per character (seconds while logged in, added by a 10 s ticker; never `RequestTimePlayed`, which prints in chat). At PLAYER_LEVEL_UP the old level's `{ s = seconds, xph = xpMax ÷ seconds × 3600 }` is saved per account under `ns.root.plannerLevels[charKey][level]` (account-wide so #43 can compare characters); the first level seen after install is marked `partial` and left out of fastest, slowest, average and the race. The "Levels" part of `/fgui stats` and the run log's levels only show while the guide is unlocked.
- **Race your best (#43):** the fastest other character's non-partial time at your level; `expected = best.s × UnitXP ÷ UnitXPMax`; `ahead = expected − clock`; within 60 s either way the line says "level with your best".
- **Where you left off (#15):** initial login only, with a planned guide and steps; one chat line and a panel line for 120 s.
- **Read aloud and keys (#16):** every guide the panel follows is read (it is the panel's step). The step's base text (`ns.GuideStepBase`, no "why") is spoken when the panel's step changes. Keyboard use: the guide's menu and its pages join `ns.WINDOW_KEYS_FRAMES` (Tab and Enter work there as in the game's windows), and `/fgui guide keys` opens the panel's menu with all its buttons. No key binding: Bindings.xml shows in the game's key bindings list, which is public.
- **The chime (#30):** it already exists (`guideSound`, `SOUNDKIT.IG_QUEST_LIST_SELECT`, on each step done). Batch 4 adds the caption when captions are on (kind `"alert"`), only when a step is done (not on a new plan or Back).
- **Hubs on the map (#32):** a hub's rate on the map is its own xp ÷ seconds (no travel from you); at most 80 hubs (best first); brightness from the map's worst to best; with `ns:ColorVision()` on, each mark also carries its tier "1", "2" or "3" (best third is 1). "Plan from here" is one-shot and wins over a zone goal for that plan.
- **The map line (#8):** stops are drawn only when their step's map is the map shown (a continent view shows no line); steps with no place are skipped.

## Review Focus

- **The world map shows another zone or a continent**, or the plan's steps lie on several maps: only stops and hubs of the shown map are drawn, nothing at 0,0, and changing the map redraws. → Task 2 test.
- **Experience or time unreadable or zero** (`UnitXPMax` 0 or secret, `summary.seconds` 0, an empty plan): no time-to-level, no race line, no level time recorded, no division by zero. → Task 3 and Task 7 tests.
- **A /reload instead of a login**: no catch-up page, no "where you left off" line, and the play clock is not counted twice. → Task 5 and Task 7 tests.
- **Time already up, or less time than any hub needs**: the plan is the stop place and "Good place to stop", not "No quests left worth the trip" and not an error. → Task 5 test.
- **A guide name that already exists** when saving the plan: a new name ("… (2)"), never overwriting your guide. → Task 8 test.

---

## File Structure

- Task 1 only: `FantasyGlassUI/Planner.lua` (hook lists, the applied hook), `FantasyGlassUI/PlannerRoute.lua` (hooks in `ns.PlannerContext`, `ns.PlannerPickZone`, `Build`; summary data), `FantasyGlassUI/PlannerSource.lua` (`src.inRange` bounds), `FantasyGlassUI/Guide.lua` (panel registries, menu, step-change hook, command words), `FantasyGlassUI/FantasyGlassUI.toc`, and the regions below.
- Create (Task 1, as empty files with a header and `local _, ns = ...`; TOC after `PlannerAdvice.lua` in this order): `FantasyGlassUI/PlannerMap.lua` (group A), `FantasyGlassUI/PlannerPages.lua` (group B), `FantasyGlassUI/PlannerPace.lua` (group C), `FantasyGlassUI/PlannerRecords.lua` (group D).
- Shared, by region (Task 1 creates the regions; each group writes only inside its own):
  - `FantasyGlassUI_Options/Bars.lua`: four local functions above `ns.BuildGuidePage`: `FeelMapSection`, `FeelPanelSection`, `FeelPaceSection`, `FeelRecordsSection`.
  - `FantasyGlassUI/Core.lua`: four comment-fenced regions at the end of the planner defaults: `-- batch 4 A (map): begin` / `-- batch 4 A (map): end`, and the same for B (panel), C (pace), D (records).
  - `tests/smoke.py`: four comment-fenced regions just before `try("Delayed calls", ...)`: `-- batch 4 tests A (map): begin` / `... end`, and B, C, D.
  - `.luacheckrc`: regenerated by `python3 site-src/tools/regen_rc.py` (sorted, so a conflict is resolved by running it again).
- Group-only files: B also `FantasyGlassUI/PlannerSource.lua` (Task 4, after Task 1); D also `FantasyGlassUI/Lifetime.lua`, `FantasyGlassUI/RunLog.lua`.

## Parallel build and merge

1. The controller runs **Task 1** on `quest-planner`, reviews and commits it. Call that commit `SEAMS`.
2. Four worktrees from `SEAMS`, built at the same time, one implementer each:
   `git worktree add ../fgui-feel-a -b feel-a SEAMS` (and `-b feel-b`, `feel-c`, `feel-d` in `../fgui-feel-b` …). Group A: Task 2. Group B: Tasks 3 then 4. Group C: Tasks 5 then 6. Group D: Tasks 7 then 8.
3. Rules for every group, so the merge is mechanical:
   - Touch only the files its task lists. In a shared file, write only between its own region's two fence lines (Core.lua, smoke.py) or inside its own section function's body (Bars.lua). Never move, reword or delete a fence or another group's lines.
   - New phrases go to the group's own `specs/plans/phrases/feel-<x>.json`, not Locales.lua.
   - Use another group's function only through a guarded call (`if ns.PlannerTimeToLevel then ... end`) and stub it in your own test; Task 9 checks the real pairing.
   - Every smoke test restores every global and `ns` field it changes (the existing `saved = {...}` / `pcall` / restore pattern), so the four regions can run in any order.
4. **Task 9** (controller, on `quest-planner`): `git merge --no-ff feel-a`, then `feel-b`, `feel-c`, `feel-d`. A conflict in `.luacheckrc` is resolved by `python3 site-src/tools/regen_rc.py`; a conflict anywhere else means a group wrote outside its region: resolve by keeping both sides in region order (A, B, C, D) and note it in the batch notes. Then `git worktree remove` the four worktrees and delete the branches.

---

### Task 1: The seams (sequential, before the groups)

**Files:** Modify `Planner.lua`, `PlannerRoute.lua`, `PlannerSource.lua`, `Guide.lua`, `FantasyGlassUI.toc`, `Bars.lua`, `Core.lua`; create the four empty group files; test `tests/smoke.py`.

**Interfaces:**
- Produces (planner, in `Planner.lua` near the top):
  - `ns.PlannerHook(point, key, fn)` (a second fn with the same key replaces the first; `fn = nil` removes it; order = first registration) and `ns.PlannerHookList(point) -> { { key = k, fn = f }, ... }`. Hooks are called **directly, never through pcall** (they run inside the planning coroutine and may call `ns.PlannerYield()`). Points and their call sites:
    - `"context"` `fn(ctx)` — at the end of `ns.PlannerContext()` (the table is built in a local, hooks run, then it is returned). Default fields added by Task 1: `ctx.windowLo = level − 4`, `ctx.windowHi = level + 2`, `ctx.horizon = ns.PLANNER_HORIZON`; hooks may widen the window bounds (they are the cheap pre-filter's bounds) and raise the horizon.
    - `"window"` `fn(rec, ctx, lo, hi) -> lo, hi` — `ns.PlannerWindow(rec, ctx) -> lo, hi` starts from `level − 4, level + 2` and folds every hook; `ns.PlannerCandidates` uses it instead of the fixed `rec.level >= level - 4 and rec.level <= level + 2`, and calls `source.inRange(id, level, ctx.windowLo, ctx.windowHi)`.
    - `"xp"` `fn(rec, ctx) -> number` — each result added in `ns.PlannerQuestXP` (after the reputation bonus).
    - `"zone"` `fn(maps, order, ctx) -> map|nil` — in `ns.PlannerPickZone` before the forced-hub check; the first non-nil map that has hubs is returned as `map, map ~= last, hubs`.
    - `"rank"` `fn(ranked, c, info)` — in `Build`'s hub loop, which first builds `ranked = { { hub = h, index = i, travel = secs, rate = xp ÷ (seconds + travel) (−1 when the hub can't be reached), score = same, first = h.first or 0 } }` for every hub left, runs the hooks (they may change `score` and `first`; a negative score excludes the hub), then takes the entry with the highest `first`, then `score`. `info = { n = round, seconds = so far, xp = so far, horizon = c.horizon }`. The loop runs `for n = 1, tonumber(c.horizon) or ns.PLANNER_HORIZON`.
    - `"route"` `fn(guide, summary, ctx, c)` — at the end of `Build`, after `ns.PlannerPathExtras` and before `summary.empty` is set.
    - `"applied"` `fn(guide, summary, ctx, reason)` — in `Apply` after `ns:GuideSetPlan`; `reason` is the `ns.plannerReason` captured when that run's coroutine was created ("start" for `ns:PlannerStart()`).
  - `src.inRange(id, level, lo, hi)` (PlannerSource.lua, Questie source): `lo`, `hi` default to `level − 4`, `level + 2`.
  - Summary data (PlannerRoute.lua `Build`): `summary.hubs = { { map, x, y, xp, seconds, rate = xp ÷ seconds, quests = n, taken = round|nil } }` from every hub `ns.PlannerPickZone` made (all maps), best rate first, at most `ns.PLANNER_MAP_HUBS = 80`; `summary.taken[n] = { xp, seconds, travel, rate, score, beat = { rate, name = runner-up's first quest name (Clean'd), map, x, y } | nil }`.
- Produces (guide panel, `Guide.lua`):
  - `ns.GuideRegisterLine(key, fn(st, steps, at) -> string|nil)` — drawn in registration order, one faint 10-pt line each, in one new fontstring `panel.extra` under `panel.advice`; the panel's height grows 13 per line.
  - `ns.GuideRegisterTitle(key, fn(st) -> string|nil)` — each non-nil result appended to the title as `" · " .. text`.
  - `ns.GuideRegisterAction(where, key, label, fn, shown)` — `where = "step"`: an entry in the right-click menu of the step (`fn(step)`, `shown(step)`), after the built-in "Never suggest this quest" (that one stays for quest steps only); `where = "panel"`: an entry in the panel menu opened by a new 22×18 `"..."` button `panel.more` (left of "Guides"), shown only while following the planned guide and some panel entry's `shown()` is true. Both menus are one frame, `FantasyGlassUIGuideMenu` (the batch 3 frame grown to N 192×20 buttons): `ns:GuideMenu(entries)` with `entries = { { label, fn } }`; Escape and a click elsewhere close it as today.
  - `ns.GuideRegisterAdvance(key, fn(st, guide, step, at, moved))` — called from `ns:GuideAdvance()` whenever the current step's StepKey differs from the last one the hooks saw (`moved` = `st.at ~= before`, i.e. a step was done or skipped; false for a new plan's first step); each through pcall, a failure added to `ns.errors` as `"Guide hook <key>: <error>"`.
  - `ns.GuideRegisterCommand(word, fn(rest))` — `ns:GuideCommand` tries registered words first (so a registered `"plan"` takes over plain `plan`).
  - `ns:GuideRedraw()` — redraws the panel if it exists.
- Produces (settings): in `Bars.lua`, `local function FeelMapSection(live, y, Replan, T) return y, function() end end` and the same for `FeelPanelSection`, `FeelPaceSection`, `FeelRecordsSection`, each above `ns.BuildGuidePage` with a comment naming its group; `ns.BuildGuidePage` calls them in that order from `y = -892` after the "dry" box, keeps each returned refresh function in a list that `page.Refresh` runs, and sets `LIVE_HEIGHT = -y + 4` (live frame size and `page.contentHeight`) after them. Core.lua and smoke.py fences as in File Structure.
- [ ] **Step 1: Failing test** `try("13.4 feel: seams", ...)`: a `"context"` hook adds `ctx.seen = true` → `ns.PlannerContext().seen`; a `"window"` hook returning `1, hi` lets a doable level-3 quest through `ns.PlannerCandidates` at level 12 and the fake source's `inRange` receives lo 1 when the context hook also sets `ctx.windowLo = 1`; an `"xp"` hook returning 100 raises `ns.PlannerQuestXP` by 100; a `"zone"` hook returning the second map makes `ns.PlannerPickZone` pick it; a `"rank"` hook that sets the best hub's score to −1 makes `ns.PlannerRoute` take the other first, and `summary.taken[1].beat` is nil or names a hub that is not the one taken; with no hooks `summary.taken[1].beat.rate < summary.taken[1].rate` and `summary.hubs` lists every hub with `rate = xp / seconds`, best first; a `"route"` hook sees the guide; an `"applied"` hook gets reason `"start"` after `ns:PlannerStart()` and a run of the runner. Guide: a registered line shows in `panel.extra` and the panel is 13 taller; a title part appends `" · x"`; a step action appears in `ns:GuideStepMenu(step)`'s buttons and its click calls `fn(step)`; `panel.more` is hidden with no panel action, shown with one while following the planned guide; an advance hook is called once with `moved = true` on `ns:GuideSkip(false)`, not on `ns:GuideSkip(true)`, and once with `moved = false` after `ns:GuideSetPlan` with a different first step; `ns:GuideCommand("plan 30")` calls a registered `"plan"` with `"30"`. Bars: the guide page builds with four sections and `page.contentHeight` ≥ 896. Remove every hook the test registered (`ns.PlannerHook(point, key, nil)` removes) and restore.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: seams for batch 4 (hooks, panel lines and menus, settings sections)"`.

---

### Task 2 (group A): The route and the hubs on the map

**Files:** `FantasyGlassUI/PlannerMap.lua`; `Bars.lua` (`FeelMapSection` body only); `Core.lua` (region A); `tests/smoke.py` (region A); `specs/plans/phrases/feel-a.json`; `.luacheckrc` (regenerated).

**Interfaces:**
- Consumes: `summary.hubs`, `step.hub`, `ns.PlannerHook("context"|"zone"|"rank"|"applied", ...)`, `ns.MapDotOffset`, `ns:ColorVision()`, `ns:ShowList`.
- Produces:
  - Settings `plannerMapLine` "The route on the map" and `plannerMapHubs` "Hubs on the map" (Core defaults true; switches in `FeelMapSection`; changing one redraws, no replan).
  - `ns.PlannerMapStops(steps, at) -> { { map, x, y, n } }`: from step `at`, every step of that step's hub, then steps up to and including the first placed step of the next hub; only steps with map, x, y; `n` numbers them 1, 2, …; at most 30.
  - `ns.PlannerMapDraw(mapID) -> lines, marks` (counts drawn): on `WorldMapFrame`'s canvas (the same canvas lookup as MapExtras.lua's `mapGroup`), one `CreateLine` per segment between consecutive stops on `mapID` (thickness 3, accent colour) and a small numbered dot per stop; hub marks for `summary.hubs` on `mapID`: alpha `0.35 + 0.65 × (rate − worst) ÷ (best − worst)` (1 when all equal), the tier text "1"/"2"/"3" when `ns:ColorVision()` is not nil; tooltip "%s xp an hour" (BreakUpLargeNumbers of rate × 3600) and "%d quests" and "Click: plan from here". Nothing drawn unless unlocked, following the planned guide, out of combat, and the switch on. Redrawn on the `"applied"` hook, on `ns:GuideRegisterAdvance`, and every 0.5 s while the map is shown when its map id changed.
  - Plan from here: clicking a mark opens `ns:ShowList("PlanHere", "Plan from here?", { "Plan from here", "Cancel" })`; "Plan from here" sets `ns.plannerFromHere = { map, x, y }` and calls `ns:PlannerReplan("from here")` (or `ns:PlannerStart()` when not following). Its `"zone"` hook returns that map; its `"rank"` hook, in round 1, sets `first = 3` on entries whose hub lies within `ns.PLANNER_HUB_YARDS` of the spot on that map; its `"applied"` hook clears `ns.plannerFromHere`.
- [ ] **Step 1: Failing test** `try("13.4 feel A: the route and hubs on the map", ...)`: steps on map 1436 with hubs 1,1,1,2,2 and one `note` without a place, at = 2 → `PlannerMapStops` gives the two remaining hub-1 steps and the first hub-2 step, numbered 1–3, no note; a stop on map 1429 is left out when map 1436 is shown. With a fake canvas: `PlannerMapDraw(1436)` → 2 lines, 3 stop dots; switch off → 0 lines; locked → nothing. Hubs: three hubs on 1436 with rates 1, 2, 3 and one on 1429 → 3 marks, alphas 0.35, 0.675, 1.0; colour vision on → tiers "3", "2", "1"; tooltip text contains "10,800 xp an hour" for rate 3. Clicking the dimmest mark and choosing "Plan from here" → the next `ns.PlannerRoute` takes that hub first even though it has the worst rate; the plan after that does not.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: the route and its hubs on the world map, plan from a hub you pick"`.

---

### Task 3 (group B): Time to level, "Why this?" and the preview

**Files:** `FantasyGlassUI/PlannerPages.lua`; `tests/smoke.py` (region B); `specs/plans/phrases/feel-b.json`.

**Interfaces:**
- Consumes: `summary.taken`, `summary.xp`, `summary.seconds`, `summary.skipped`, `summary.moved`, `ns.PlannerCharRecord`, `ns.GuideRegisterTitle`, `ns.GuideRegisterAction`, `ns.PlannerHook("applied", ...)`.
- Produces:
  - `ns.PlannerTimeToLevel(summary) -> minutes|nil` per the ruling (rounded, at least 1); title part `format("level %d in ~%d min", level + 1, minutes)` on the planned guide.
  - `ns.PlannerWhyLines(step, summary) -> { {left, right} }`: "Experience" (step.why.xp, else the hub's xp), "Travel" and "Time to do" (minutes, from the hub's travel and seconds), "Experience an hour" (rate × 3600), and "Beat %s at %s an hour (%d%% better)" from `beat` (`(rate ÷ beat.rate − 1) × 100`, floored), or "Nothing else was worth the trip" with no beat; a stop step without a hub: "A stop on the way" plus "Saves about %d min" / "About %d min out of the way" from its `why`. Step action "Why this?" (`shown`: planned guide and the step has a hub or a why) opens `ns:ShowList("PlanWhy", "Why this?", lines)`.
  - `ns.PlannerPreviewLines(guide, summary) -> lines`: the steps in order ("%d. %s" with `ns.GuideStepBase`), then "Experience: %s", "Level %s → %s", "Flights: %d, crossings: %d" (counts of `fly` and `sail` steps), the skipped line (same words as the panel's) and the moved line when present, then the clickable lines "Follow" (hides the page) and "Plan again" (hides it; opens the Guide tab with the add-on's config opener). `ns:PlannerPreview()` shows `ns:ShowList("PlanPreview", "Preview the next hour", lines)`. Panel action "Preview". The `"applied"` hook opens it when `reason == "start"`.
- [ ] **Step 1: Failing test** `try("13.4 feel B: time to level, why this, preview", ...)`: summary `{ xp = 6000, seconds = 3600 }`, UnitXP 2000, UnitXPMax 10000, level 25, pace samples {1,1,1} → 80 and the title ends "level 26 in ~80 min"; two samples → nil; UnitXPMax 0 → nil; seconds 0 → nil. Why: a hub with xp 1200, seconds 480, travel 120, rate 2, beat rate 1.5 named "Wolves" → lines carry "1,200", "2 min", "8 min", "7,200", "Beat Wolves at 5,400 an hour (33% better)"; no beat → "Nothing else was worth the trip"; a vendor step with `why = { detour = 90 }` → "A stop on the way" and "About 2 min out of the way" (rounded). The step menu of a planned step lists "Why this?". Preview: a plan with 2 fly and 1 sail step lists every step in order (the same `GuideStepBase` texts as the plan), "Flights: 2, crossings: 1", the skipped line; `ns:PlannerStart()` plus a runner pass opens the page once; a replan after a hand-in does not; "Follow" hides it.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: time to your next level, why each step is there, a preview of the plan"`.

---

### Task 4 (group B): Finish the zone

**Files:** `FantasyGlassUI/PlannerPages.lua`; `FantasyGlassUI/PlannerSource.lua` (`src.mapQuests`); `Bars.lua` (`FeelPanelSection` body); `tests/smoke.py` (region B); `specs/plans/phrases/feel-b.json`.

**Interfaces:**
- Consumes: `ns.PlannerHook("context"|"window"|"zone"|"route", ...)`, `ns.GuideRegisterLine`, `ctx.done`, `ctx.source`.
- Produces:
  - Per character `rec.zoneGoal = uiMapID|nil`; `ns.PlannerZoneGoal() -> map|nil`, `ns.PlannerSetZoneGoal(map|nil)` (replans); `ns.PlannerGoalZone() -> map|nil` (the zone-level map you are in, per the ruling).
  - `src.mapQuests(map) -> { questID }` on the Questie source: quests whose `zoneOrSort` area maps (`zones:GetUiMapIdByAreaId`, cached per area) to `map`; one scan of `src.ids()` per session (cached per map), `ns.PlannerYield()` per id outside pcall; the log source returns the logged quests whose `GetNextWaypoint` map is `map`.
  - Hooks while a goal is set: `"context"` sets `ctx.windowLo = 1`; `"window"` returns `1, hi` for a record whose first start lies on the goal map; `"zone"` returns the goal map; `"route"` sets `summary.zoneGoal = { map, done = n, total = n }` (total = the map's non-repeatable quests that are doable or done; done = those `ctx.done` says are done), and when no taken hub lies on the goal map it clears the goal, prints "Zone done: %s" once, and calls `ns:PlannerReplan("zone done")`.
  - Panel line "Zone: %d of %d quests" from `summary.zoneGoal`. Guide tab, in `FeelPanelSection`: a button "Goal: Level up" / "Goal: Finish %s" that cycles between leveling and the zone you are in.
- [ ] **Step 1: Failing test** `try("13.4 feel B: finish the zone", ...)`: a fake Questie with map 1429 quests at levels 2, 5 and 11 (the level-11 one done) and map 1436 quests at 12 → with the goal 1429 at level 12 the plan plans the level-2 and level-5 quests on 1429 and none on 1436, the panel shows "Zone: 1 of 3 quests"; the done quest is not planned; a group quest added on 1429 is left out in Solo (and counted: "Zone: 1 of 4 quests"); `src.mapQuests(1429)` is cached (a second call reads nothing). All 1429 quests done → the goal clears, "Zone done: Elwynn Forest" printed once, and the next plan goes back to leveling (1436). Goal off → the old window (level-2 quest not planned). The button cycles and stores the goal per character.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: a goal to finish a zone"`.

---

### Task 5 (group C): The time you have, break reminders, catch me up

**Files:** `FantasyGlassUI/PlannerPace.lua`; `Bars.lua` (`FeelPaceSection` body); `Core.lua` (region C); `tests/smoke.py` (region C); `specs/plans/phrases/feel-c.json`.

**Interfaces:**
- Consumes: `ns.PlannerHook("context"|"rank"|"route", ...)`, `ns.GuideRegisterCommand`, `ns.GuideRegisterAction`, `ns.GuideRegisterAdvance`, `ns.GuideRegisterLine`, `ns.PlannerPlaces(ctx, "innkeeper")`, `ctx.flights`, `ns.PlannerTravel`, `ns.plannerSessionStart`, `ns.whatsNew`, `ns.version`.
- Produces:
  - Time: per character `rec.playUntil` (`time()` seconds) and `rec.playDefault` (minutes: 0, 30, 60, 90, 120); `ns.PlannerSetPlayTime(minutes)` (0 clears); `ns.PlannerTimeLeft() -> seconds|nil`. Command word `"plan"`: a number → set it, then `ns:PlannerStart()`; none → the default (if any), then `ns:PlannerStart()`. `"context"` hook: with a deadline, `ctx.timeLeft` and `ctx.horizon = 6`. `"rank"` hook: score −1 for entries with `info.seconds + travel + hub.seconds > ctx.timeLeft` (sets `c.timeCut = true` when any was cut or the horizon was reached). `"route"` hook: when `c.timeCut` (or time is up), append the stop place `goto` (nearest innkeeper or known flight point within min(300, time left − summary.seconds) s) and `note | Good place to stop`; the advance hook clears the deadline when that note step is done. Panel action "How long can you play?" opens `ns:ShowList("PlanTime", ...)` with "No limit", "30 min", "1 hour", "1 hour 30", "2 hours". Guide tab: "How long can you play" cycle button (the default) in `FeelPaceSection`.
  - `ns.PlannerStoppingPlace(steps, at) -> boolean` per the ruling.
  - Breaks: settings `plannerBreaks` (Core default **false**) and `plannerBreakMinutes` (default **120**); advance hook: at a stopping place, out of combat, session play ≥ the minutes and ≥ 3600 s since the last reminder → chat and panel line (600 s) `format("You've been playing %s; this is a good place to stop", hours text)`.
  - Catch me up: per character `rec.lastSeen`, `rec.lastVersion` (ticker 60 s and PLAYER_LOGOUT); at an initial login away ≥ `ns.PLANNER_CATCHUP_DAYS = 14` days → `ns:PlannerCatchUp()` shows `ns:ShowList("PlanCatchUp", "Catch me up", lines)`: "Away for %d days", where you were (the saved plan's zone and step), "%d quests in your log, %d of them in the plan", "Level %d, pace %.1f× the estimate", up to 3 "New: %s" lines, and the clickable "Plan my route" (`ns:PlannerStart()`). Only when unlocked and the guide is on.
- [ ] **Step 1: Failing test** `try("13.4 feel C: time you have, breaks, catch-up", ...)`: three hubs of 900 s each with 60 s travel, `/fgui guide plan 30` (1800 s) → hub 1 only (960 s; hub 2 would make 1920), then a `goto` to a fake inn 40 s away and the last step `note` "Good place to stop"; no time → the usual two hubs and no note; `plan 0` clears; time already up → the plan is the inn `goto` and the note only, `summary.empty` false; ticking the note clears the deadline. `PlannerStoppingPlace`: after a turnin into a new hub → true, mid-hub → false, after a fly → true, at the end → true. Breaks: on, session 2 h 10 min, advance to a stopping place → the line once; again 30 min later → none; mid-hub → none; in combat → none; switch off (default) → none. Catch-up: lastSeen 15 days ago + initial login → the page with "Away for 15 days" and "Plan my route"; 13 days → none; a reload → none; no lastSeen → none.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: plan for the time you have, break reminders, catch me up"`.

---

### Task 6 (group C): Speed or story, and the three sliders

**Files:** `FantasyGlassUI/PlannerPace.lua`; `Bars.lua` (`FeelPaceSection` body); `tests/smoke.py` (region C); `specs/plans/phrases/feel-c.json`.

**Interfaces:**
- Consumes: `ns.PlannerHook("context"|"window"|"rank", ...)`, `ns.GuideRegisterLine`, `ctx.deaths`, `ns.PLANNER_ESCORTS`.
- Produces:
  - Per character `rec.style = "speed"|"story"|"custom"` and `rec.weights = { speed, safety, story }` (0–100); `ns.PlannerWeights() -> speed, safety, story` (default 100, 0, 0); `ns.PlannerSetStyle(style)` (presets per the Global Constraints, safety kept); `ns.PlannerSetWeight(name, value)` (style becomes "custom"; replans).
  - `ns.PlannerStoryScore(hub, chains) -> 0..1`, `ns.PlannerDanger(hub, ctx) -> 0..1`, `ns.PlannerChains(candidates) -> { main = { [id] = true }, any = { [id] = true } }` per the ruling. `"context"` hook puts the weights in `ctx.weights` and, with story 100, `ctx.windowLo = level − 10`; `"window"` hook (story 100) returns `level − 10, hi` for chain quests; `"rank"` hook applies the score formula (skipped entirely at 100/0/0 so Speed is unchanged).
  - Guide tab (`FeelPaceSection`): "Style: Speed / Story / Custom" cycle button and three `ns:CreateSlider` "Speed", "Safety", "Story" (0–100, step 10), kept in step with the style. Panel line "Style: Story" / "Style: Custom" when the style is not Speed.
- [ ] **Step 1: Failing test** `try("13.4 feel C: speed, safety, story", ...)`: hub A (rate 3, no chains) and hub B (rate 2, three quests of the zone's main chain): Speed → A first; Story preset → B first, weights 40/0/100; moving Safety makes style "custom". Safety: hub A with an elite quest and a death at this level, hub B safe at rate 2.5 → Safety 100 takes B, Safety 0 takes A. Story 100: a chain quest at level − 6 is a candidate, a lone quest at level − 6 is not; story 90 → neither. At 100/0/0 the plan equals the plan with the hooks removed (same step list). The panel shows "Style: Story" and nothing for Speed.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: speed or story, and sliders for speed, safety and story"`.

---

### Task 7 (group D): Level times, race your best, where you left off

**Files:** `FantasyGlassUI/PlannerRecords.lua`; `FantasyGlassUI/Lifetime.lua` (the Levels part); `FantasyGlassUI/RunLog.lua` (the levels entry); `Bars.lua` (`FeelRecordsSection` body); `Core.lua` (region D); `tests/smoke.py` (region D); `specs/plans/phrases/feel-d.json`.

**Interfaces:**
- Consumes: `ns.GuideRegisterLine`, `ns.PlannerTimeToLevel` (group B; guarded), `ns.GuideState`, `ns:GuideGet`.
- Produces:
  - Play clock per character: `rec.levelClock = { level, seconds, xpMax, partial }`; `ns.PlannerLevelTick(elapsed)` (the 10 s ticker calls it; skips when the level or xp max is unreadable), and on `PLAYER_LEVEL_UP` `ns.PlannerRecordLevel(oldLevel)` writes `ns.root.plannerLevels[charKey][oldLevel] = { s, xph, partial }` and restarts the clock. Recorded only while unlocked. The clock is saved per character, and each tick adds only the `GetTime()` elapsed since the last tick, at most 30 s, so a reload or a loading screen adds nothing extra.
  - `ns.PlannerLevelSummary(charKey) -> { fastest = {level, s}, slowest = {level, s}, average = s, count }` (non-partial only). `/fgui stats` (`ns:ShowLifetime`) gains, while unlocked and with any level recorded, a "Levels" heading and "Fastest level: %d (%s)", "Slowest level: %d (%s)", "Average level: %s"; the run log's first list (`ns.RunLines` level 0) gains, while unlocked, one line per recorded level of this character, "Level %d: %s, %s xp an hour", newest first, at most 20.
  - Race: setting `plannerRace` (Core default **false**), panel line "Race your best: ahead by %d min" / "behind by %d min" / "level with your best" per the ruling; no line when no other character has a non-partial time at this level.
  - Where you left off: setting `plannerLeftOff` (default true); at an initial login, when the planned guide has steps: chat `format("Where you left off: step %d of %d, %s", at, n, ns.GuideStepBase(step))` plus `format(", level %d in ~%d min", ...)` when `ns.PlannerTimeToLevel` gives minutes; the same as a panel line for 120 s.
  - Guide tab (`FeelRecordsSection`): "Race your best" and "Where you left off, at login" switches.
- [ ] **Step 1: Failing test** `try("13.4 feel D: level times, race, where you left off", ...)`: level 10, xpMax 5000, ticks of 600 s, level up → `plannerLevels[me][10] = { s = 600, xph = 30000 }`; the first level after install is partial and not in the summary; UnitXPMax 0 → no tick counted; locked → nothing recorded. Stats: levels 10, 11, 12 at 600/1200/900 s → "Fastest level: 10 (10m)", "Slowest level: 11 (20m)", "Average level: 15m"; locked → no Levels part. Run log level 0 shows "Level 10: 10m, 30,000 xp an hour". Race on: another character's level 11 = 1200 s, here 300 s at 50% → "ahead by 5 min"; 900 s at 50% → "behind by 5 min"; 620 s → "level with your best"; off → no line; no other character → no line. Left off: initial login with the planned guide at step 3 of 8 and `ns.PlannerTimeToLevel` stubbed to 48 → chat line contains "step 3 of 8" and "level 26 in ~48 min"; stub absent → no time part; reload → no line; switch off → none.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: level times in your stats, race your best, where you left off"`.

---

### Task 8 (group D): Save as guide, read aloud, the chime's caption

**Files:** `FantasyGlassUI/PlannerRecords.lua`; `Bars.lua` (`FeelRecordsSection` body); `Core.lua` (region D); `tests/smoke.py` (region D); `specs/plans/phrases/feel-d.json`.

**Interfaces:**
- Consumes: `ns.GuideRegisterAction`, `ns.GuideRegisterAdvance`, `ns.GuideRegisterCommand`, `ns:GuideMenu`, `ns.GuideLine`, `ns.GuideParseLine`, `ns:GuideSave`, `ns:GuideGet`, `ns:Speak`, `ns:Caption`, `ns.WINDOW_KEYS_FRAMES`.
- Produces:
  - `ns.PlannerSaveAsGuide() -> name|nil`: the planned guide's steps, each passed through `ns.GuideParseLine(ns.GuideLine(step))` (so only what the text format keeps), saved with `ns:GuideSave` under `format("%s %d-%d", zone name, floor(fromLevel), ceil(toLevel))`, then " (2)", " (3)" … when the name is taken; prints `"Saved as guide \"%s\": %d steps."`. Panel action "Save as guide".
  - Read aloud: setting `plannerSpeak` "Read the route aloud" (default true; its switch is greyed with the hint "Needs reading aloud on in Accessibility" while `ns.db.readDialog` is off); advance hook speaks `ns.GuideStepBase(step)` when `ns.db.readDialog` and `plannerSpeak ~= false` and the step exists.
  - Keys: at PLAYER_LOGIN, adds `"FantasyGlassUIGuideMenu"`, `"FantasyGlassUIListPlanPreview"`, `"FantasyGlassUIListPlanWhy"`, `"FantasyGlassUIListPlanTime"`, `"FantasyGlassUIListPlanCatchUp"`, `"FantasyGlassUIListPlanHere"` to `ns.WINDOW_KEYS_FRAMES` (once each). Command word `"keys"`: `ns:GuideMenu` with Back, Next, Guides and every shown panel action.
  - Chime caption: advance hook, when `moved` and `ns.db.guideSound ~= false`: `ns:Caption("alert", ns:Tr("Step done"))` (Caption itself checks that captions are on).
- [ ] **Step 1: Failing test** `try("13.4 feel D: save as guide, read aloud, chime", ...)`: a planned guide in "Elwynn Forest" from level 8 to 9.6 with `fly 41`, `learnflight`, `sail`, `bind`, `train`, `vendor` steps (each with `why` and `hub`) → saved as "Elwynn Forest 8-10"; `ns.GuideParse(ns.GuideText(saved))` gives the same kinds, nodes and crossings in order, and no `why`; saving again → "Elwynn Forest 8-10 (2)" and the first is unchanged. Read aloud: readDialog off → `ns:Speak` not called; on → called once with the next step's base text when the step changes (no "why" text in it); `plannerSpeak = false` → not called; a written guide's step is read too. Keys: after PLAYER_LOGIN the six names are in `ns.WINDOW_KEYS_FRAMES` once (twice PLAYER_LOGIN → still once); `/fgui guide keys` shows the menu with "Save as guide" among its buttons. Chime: captions on, a step done → one caption "Step done"; `ns:GuideSkip(true)` → none; guideSound off → none; a new plan's first step → none.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, and the per-task checks.**
- [ ] **Step 5: Commit** `"Planner: save the plan as a guide, read the route aloud, a caption with the chime"`.

---

### Task 9: Merge and check everything (controller, on `quest-planner`)

- [ ] **Step 1:** Merge `feel-a`, `feel-b`, `feel-c`, `feel-d` (`--no-ff`) per "Parallel build and merge"; regenerate `.luacheckrc` if it conflicted.
- [ ] **Step 2:** Translations: `python3 site-src/tools/add_tr.py specs/plans/phrases/feel-a.json` (then b, c, d); `git rm -r specs/plans/phrases`.
- [ ] **Step 3:** One integration test in a new block after region D, `try("13.4 feel: together", ...)`: with the real `ns.PlannerTimeToLevel` (B), the left-off line (D) carries the time; a 30-minute plan (C) with Story (C) and a zone goal (B) plans without error and the map line (A) draws its stops; "Plan from here" (A) overrides the zone goal (B) for one plan.
- [ ] **Step 4:** `cd FantasyGlassUI && python3 ../tests/smoke.py` → `syntax: all ... OK`, `errors: no errors` twice.
- [ ] **Step 5:** `luacheck . -q` 0 warnings; `python3 tests/forever_audit.py`, `python3 tests/lockaudit.py` (`(no protected calls in combat)`), `python3 tests/secretaudit.py` clean.
- [ ] **Step 6:** `python3 -m pytest tests -q` → 6 passed.
- [ ] **Step 7:** `python3 site-src/tools/missing_tr.py FantasyGlassUI/Planner*.lua FantasyGlassUI/Guide.lua FantasyGlassUI/Lifetime.lua FantasyGlassUI/RunLog.lua FantasyGlassUI_Options/Bars.lua` → nothing new except internal value strings.
- [ ] **Step 8:** `grep -ril planner README.md CHANGELOG.md RELEASE.md FantasyGlassUI/*.md docs site-src wiki` → nothing; `/fgui help` text unchanged.
- [ ] **Step 9:** `specs/plans/2026-11-25-quest-planner-feel-notes.md`: in-game checks (CreateLine on the world map canvas at its scale; map ids of steps against the shown map; hub marks and clicks under the game's own pins; `ns:Speak` timing with step changes; WindowKeys on the guide menu and the ShowList pages; the caption; the zone-level parent walk and `GetUiMapIdByAreaId` for zone quests; the play clock against /played; `PLAYER_ENTERING_WORLD` login flags for catch-up and left-off; the preview opening on "Plan my route"), the rulings above as made or changed during the build, any merge conflict outside a region, and the deferred minors from the ledger. Commit `"Quest planner batch 4: build notes (in-game checks, rulings, deferred findings)"`.
