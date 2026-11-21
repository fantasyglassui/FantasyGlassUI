# Quest Planner, Batch 1 (the core) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The quest guide plans its own leveling route (most experience per hour, travel counted) from your quest log and Questie's data, across both continents, with flights, the hearthstone and boats, and replans after each hand-in and level.

**Architecture:** Three new files of mostly pure functions that take a `ctx` table describing the game (so smoke.py can test them with fakes): `PlannerSource.lua` reads Questie (or, failing that, the quest log) into plain quest records; `PlannerTravel.lua` works out travel time between two places; `Planner.lua` scores quests, makes hubs, picks the zone, builds the route as ordinary guide steps, and runs the work a slice per frame. Guide.lua learns four step kinds and shows a planned route as a guide.

**Tech Stack:** Lua 5.1 (WoW Forever, interface 16001), the add-on's own helpers (ns:Every, ns:Tr, ns:Print, ns.MapPosition), Questie internals read through `QuestieLoader:ImportModule`, tests in `tests/smoke.py` (lupa).

**Spec:** `specs/2026-11-21-quest-planner-design.md`: this plan covers its **Build order, batch 1** only.

## Global Constraints

- WoW Forever only; every function and event used must pass `tests/forever_audit.py` (pytest `test_forever_api`).
- `luacheck . -q` at the repository root: 0 warnings. New globals the add-on reads go into `.luacheckrc` via `python3 site-src/tools/regen_rc.py`.
- `cd FantasyGlassUI && python3 ../tests/smoke.py` prints `errors: no errors` twice (both modes).
- No planning in combat: pause at `PLAYER_REGEN_DISABLED`, resume at `PLAYER_REGEN_ENABLED`. Nothing uses `COMBAT_LOG_EVENT_UNFILTERED`.
- Planning runs in slices of at most `ns.PLANNER_BUDGET_MS = 4` milliseconds per frame (`debugprofilestop`).
- Every player-facing phrase is translated in all 9 languages (`python3 site-src/tools/add_tr.py phrases.json`; `python3 site-src/tools/missing_tr.py <files>` lists none missing).
- Questie is optional: `## OptionalDeps: Questie` in `FantasyGlassUI.toc`. Questie data is read only, through `pcall`; nothing of Questie's is copied into the add-on.
- Contract: Questie's TOC `## X-QuestieDB-Contract:` must be `"4"`; anything else means "changed" and the quest-log fallback.
- Everything stays behind `ns:GuideUnlocked()`/`ns:GuideOn()`; `/fgui help`, the README, the site and the changelog say nothing about the planner. The unlock phrase never appears in any file this plan touches.
- Values from the spec: level window **player level − 4 to + 2**; hub radius **150 yards** on the same map; horizon **2 hubs**; learn a flight point when the detour is **under 120 seconds** or the plan uses it; group setting default **Solo**.
- Commits: author `DustyMouse <fantasyglassui@users.noreply.github.com>`, no attribution lines. Never push.

## Review Focus

- **Questie loaded but not ready yet** (login): the planner must wait for `Questie.API.RegisterOnReady`, not plan from an empty database or error. → test in Task 2.
- **A quest that starts from an item or an object, or whose giver has no spawn on a known map**: it must be skipped quietly, not crash or place a step at 0,0. → test in Task 2.
- **The player where there is no world position** (an instance, a flight, a loading screen, a map C_Map cannot place): planning waits and says nothing wrong. → test in Task 6.
- **A fight starting mid-plan**: the slice runner stops at once and resumes after, with the same result as an unbroken run. → test in Task 6.
- **Nothing worth doing** (every candidate filtered out): the panel shows the "no quests left worth the trip" line, not an empty guide or an error. → test in Task 5.

---

## File Structure

- Create `FantasyGlassUI/PlannerSource.lua`: Questie adapter and quest-log fallback → plain quest records.
- Create `FantasyGlassUI/PlannerTravel.lua`: world positions, flight points (known, recorded times), hearthstone, crossings table, travel time.
- Create `FantasyGlassUI/Planner.lua`: kill experience, candidates, scoring, pace, hubs, zone pick, route → steps, the slice runner, events, `/fgui guide plan`.
- Modify `FantasyGlassUI/Guide.lua`: step kinds `fly <node>`, `learnflight`, `sail`, `bind`; world answers for them; the planned route as a guide; the panel's "Skipped" line.
- Modify `FantasyGlassUI/FantasyGlassUI.toc`: `## OptionalDeps: Questie`; the three files after `GuideEditor.lua`, in the order Source, Travel, Planner.
- Modify `FantasyGlassUI/Core.lua`: defaults `plannerGroup = "solo"`, `plannerLearnFlights = true`, `plannerWhy = true`.
- Modify `FantasyGlassUI_Options/Bars.lua` (`ns.BuildGuidePage`): "Plan my route" button and the three settings.
- Modify `FantasyGlassUI_Locales/Locales.lua`: translations.
- Modify `tests/smoke.py`: a fake Questie and the `13.0 planner:` tests, inserted just before `try("Delayed calls", ...)`.
- Modify `.luacheckrc`: read_globals for what is new.

---

### Task 1: Four step kinds in the guide

**Files:**
- Modify: `FantasyGlassUI/Guide.lua` (`ns.guideKinds`, `ns.GuideParseLine`, `ns.GuideLine`, `ns.GuideStepText`, `ns.GuideStepDone`, `ns:GuideWorld`)
- Test: `tests/smoke.py`

**Interfaces:**
- Produces:
  - `ns.guideKinds.learnflight = { "L", {0.6,0.85,1}, "Learn the flight path" }`, `sail = { "S", {0.6,0.85,1}, "Sail" }`, `bind = { "B", {0.6,0.85,1}, "Set your hearthstone" }` (fly exists).
  - Line forms: `fly 23 | Southshore`, `learnflight 23 | Tarren Mill`, `sail menethil-theramore | Theramore`, `bind | Southshore`. Steps carry `step.node` (number, fly/learnflight), `step.crossing` (string, sail), `step.text` (bind: the inn's name as `GetBindLocation()` returns it). `fly | text` (no node) still parses.
  - World answers: `world.knownFlight(node) -> boolean`, `world.landedAt(node) -> boolean` (the last landing recorded by Task 3 was at `node`), `world.crossed(crossing) -> boolean` (you are on the crossing's far continent), `world.bind -> string|nil`.
  - Done: `fly` with node → `landedAt(node)`; `fly` without node → `near(step)` when it has a place, else false; `learnflight` → `knownFlight(node)`; `sail` → `crossed(crossing)`; `bind` → `world.bind == step.text`.

- [ ] **Step 1: Write the failing test** (new `try("13.0 planner: step kinds", function() ... end)`)

```lua
local g = ns.GuideParse("guide: Kinds\nfly 23 | Southshore\nfly | Take the bat\nlearnflight 24 | Tarren Mill\nsail menethil-theramore | Theramore\nbind | Southshore\n")
local s = g.steps
if #s ~= 5 or s[1].node ~= 23 or s[2].node ~= nil or s[3].node ~= 24 or s[4].crossing ~= "menethil-theramore" or s[5].text ~= "Southshore" then error("the new kinds parse") end
local again = ns.GuideParse(ns.GuideText(g))
for i = 1, 5 do if ns.GuideLine(again.steps[i]) ~= ns.GuideLine(s[i]) then error("round trip " .. i) end end
local w = { knownFlight = function(n) return n == 24 end, landedAt = function(n) return n == 23 end,
            crossed = function(c) return c == "menethil-theramore" end, bind = "Southshore", near = function() return false end }
if not ns.GuideStepDone(s[1], w) or ns.GuideStepDone(s[2], w) or not ns.GuideStepDone(s[3], w) or not ns.GuideStepDone(s[4], w) or not ns.GuideStepDone(s[5], w) then error("done") end
w.bind = "Booty Bay"; if ns.GuideStepDone(s[5], w) then error("bound elsewhere") end
if ns.GuideParseLine("learnflight | x") ~= nil then error("learnflight needs a node number") end
```

- [ ] **Step 2: Run it to see it fail**

Run: `cd FantasyGlassUI && python3 ../tests/smoke.py 2>&1 | grep -E "^errors:|13.0 planner"`
Expected: `CALL ERROR 13.0 planner: step kinds -> ... the new kinds parse` in both modes.

- [ ] **Step 3: Implement** in `Guide.lua`: the kinds above; in `GuideParseLine`, for `fly`/`learnflight` read a leading number into `step.node` (`learnflight` without one → `nil, "learnflight needs the flight point's number"`), for `sail` the leading word into `step.crossing` (required); `GuideLine` writes them back after the kind; `GuideStepText` for the new kinds uses `step.text` with fallbacks "Learn the flight path", "Take the boat", "Set your hearthstone here"; extend the parse error message list of kinds. In `ns:GuideWorld()` add `knownFlight`, `landedAt`, `crossed` (each calling `ns.PlannerKnownFlight`, `ns.PlannerLandedAt`, `ns.PlannerCrossed` when they exist, else false) and `bind` from `GetBindLocation()` (pcall, skip secret).

- [ ] **Step 4: Run to see it pass**

Run: same command. Expected: no `13.0 planner` line; `errors: no errors` twice.

- [ ] **Step 5: Commit**: `git add FantasyGlassUI/Guide.lua tests/smoke.py && git commit -m "Guide: fly to a flight point, learn a flight path, sail, set your hearthstone"`

---

### Task 2: Reading Questie (and the quest log when it can't)

**Files:**
- Create: `FantasyGlassUI/PlannerSource.lua`
- Modify: `FantasyGlassUI/FantasyGlassUI.toc` (OptionalDeps, the file after `GuideEditor.lua`)
- Test: `tests/smoke.py` (a fake Questie built inside the test)

**Interfaces:**
- Produces:
  - `ns.PLANNER_CONTRACT = "4"`
  - `ns.PlannerSource() -> source | nil, reason` with reason `"missing"` (Questie not loaded), `"waiting"` (not ready; it registers `Questie.API.RegisterOnReady` once and calls `ns:PlannerReplan("questie")` when ready), `"changed"` (contract differs, or a module/call is missing or errors).
  - `ns.PlannerLogSource() -> source` (always works; only quests in the log; starts empty, ends from `C_QuestLog.GetNextWaypoint`).
  - A source: `{ kind = "questie" | "log", ids = function() -> {questId...}, quest = function(id) -> record | nil }`.
  - A record: `{ id, name, level, minLevel, xp, starts = { {map,x,y} ... }, ends = { {map,x,y} ... }, objectives = { { kind = "kill"|"item"|"place"|"other", count, spots = { {map,x,y} ... }, mobLevel } ... }, pre = {ids}, preAny = {ids}, exclusive = {ids}, nextQuest = id|nil, elite = bool, group = bool, dungeon = bool, repeatable = bool, doable = bool }`. `map` is a uiMapID (Questie area ids converted with `ZoneDB:GetUiMapIdByAreaId`), `x,y` are 0–100.
- Questie internals used (all inside pcall): `QuestieLoader:ImportModule("QuestieDB")` (`QuestPointers`, `GetQuest(id)`, `IsDoable(id)`, `QueryNPCSingle(id, "spawns")`, `QueryNPCSingle(id, "minLevel")`, `QueryNPCSingle(id, "maxLevel")`, `QueryNPCSingle(id, "rank")`), `ImportModule("QuestXP")` (`:GetQuestLogRewardXP(id)`), `ImportModule("ZoneDB")` (`:GetUiMapIdByAreaId(areaId)`), `Questie.API.isReady`, `Questie.API.RegisterOnReady`, `C_AddOns.GetAddOnMetadata("Questie", "X-QuestieDB-Contract")`.
- Tags: elite/group/dungeon from `C_QuestLog.GetQuestTagInfo(id)` when the quest is in the log, else from the Questie quest's `questFlags`/`zoneOrSort` (dungeon when `zoneOrSort` is a dungeon area) and any objective NPC with `rank` 1 or 2 (elite).

- [ ] **Step 1: Write the failing test** `try("13.0 planner: reading Questie", ...)`. Build a fake: `env.Questie = { API = { isReady = true, RegisterOnReady = function(f) ready = f end } }`, `env.QuestieLoader = { ImportModule = function(_, name) return fakes[name] end }`, `C_AddOns.IsAddOnLoaded("Questie") -> true`, metadata `"4"`. `fakes.QuestieDB` holds quests 101 (giver NPC 9 at area 40 → uiMap 1436, 30,40; kill 8 of NPC 20, level 10), 102 (starts from an item, no NPC), 103 (giver NPC 11 with no spawns), 104 (elite: objective NPC rank 1). Assertions:

```lua
local src, why = ns.PlannerSource()
if not src or src.kind ~= "questie" then error("questie source: " .. tostring(why)) end
local q = src.quest(101)
if q.starts[1].map ~= 1436 or q.starts[1].x ~= 30 or q.objectives[1].kind ~= "kill" or q.objectives[1].count ~= 8 or q.objectives[1].mobLevel ~= 10 or q.xp ~= 450 then error("record 101") end
if src.quest(102) ~= nil or src.quest(103) ~= nil then error("no giver on a map: skipped") end
if not src.quest(104).elite then error("elite from the objective's rank") end
meta = "5"; src, why = ns.PlannerSource(); if src or why ~= "changed" then error("another contract is a change") end
meta = "4"; fakes.QuestieDB.GetQuest = function() error("boom") end
src, why = ns.PlannerSource(); local okQ = src and pcall(src.quest, 101); if src and (not okQ) then error("errors inside Questie are caught") end
env.Questie.API.isReady = false; src, why = ns.PlannerSource(); if src or why ~= "waiting" then error("waits for Questie") end
loaded = false; src, why = ns.PlannerSource(); if src or why ~= "missing" then error("no Questie") end
local log = ns.PlannerLogSource(); if log.kind ~= "log" or type(log.ids()) ~= "table" then error("log source") end
```

(When a call inside Questie errors, `quest(id)` returns nil and the next `ns.PlannerSource()` reports `"changed"`.)

- [ ] **Step 2: Run to see it fail**: same command; expected `CALL ERROR 13.0 planner: reading Questie`.
- [ ] **Step 3: Implement `PlannerSource.lua`** with the interfaces above; add the TOC lines.
- [ ] **Step 4: Run to see it pass**: `errors: no errors` twice; `python3 ../tests/forever_audit.py` from the root exits 0 (add any missing name to `.luacheckrc` with `regen_rc.py`).
- [ ] **Step 5: Commit**: `git commit -m "Planner: read quests from Questie, or from the quest log when it can't"`

---

### Task 3: Travel: running, flights, the hearthstone, boats and zeppelins

**Files:**
- Create: `FantasyGlassUI/PlannerTravel.lua`
- Modify: `FantasyGlassUI/FantasyGlassUI.toc`
- Test: `tests/smoke.py`

**Interfaces:**
- Produces:
  - `ns.PLANNER_SPEED = { run = 7, mount = 11.2, fastMount = 14, flight = 32 }` (yards per second); `ns.PLANNER_HEARTH_SECONDS = 30`.
  - `ns.PlannerWorldPos(map, x, y) -> continent, wx, wy` (yards) via `C_Map.GetWorldPosFromMapPos(map, CreateVector2D(x/100, y/100))`; nil when it can't.
  - Flight points, per character in `ns.root.planner[charKey].flights = { [node] = true }`, learned at `TAXIMAP_OPENED` (every node whose `TaxiNodeGetType(i)` is `"REACHABLE"` or `"CURRENT"`, node id from `C_TaxiMap.GetAllTaxiNodes`); `ns.PlannerKnownFlight(node) -> boolean`.
  - Flight times, per account in `ns.root.plannerFlightTimes["a-b"] = seconds`: take-off at `PLAYER_CONTROL_LOST` with `UnitOnTaxi("player")`, landing at `PLAYER_CONTROL_GAINED`; the landing node is the known node nearest the landing place. `ns.PlannerLandedAt(node) -> boolean` (the last landing).
  - `ns.PLANNER_CROSSINGS = { { id = "menethil-theramore", a = {map,x,y}, b = {map,x,y}, faction = "Alliance", seconds = 270 }, ... }`: our own table (Menethil–Theramore, Menethil–Auberdine, Auberdine–Rut'theran, Booty Bay–Ratchet, Orgrimmar–Undercity, Orgrimmar–Grom'gol, Undercity–Grom'gol). Each entry's map ids and coordinates are **checked in the game before batch 1 is released** (a task for the player; the test uses its own fake table). Real crossing times recorded like flights replace `seconds`. `ns.PlannerCrossed(id) -> boolean`.
  - `ns.PlannerTravel(from, to, ctx) -> seconds, legs`: `from`/`to` are `{map,x,y}`; `ctx = { speed = yardsPerSecond, faction = "Alliance"|"Horde", flights = { {node,map,x,y,known} ... }, flightTime = function(a, b) -> seconds, hearth = { map,x,y } | nil, crossings = ns.PLANNER_CROSSINGS }`. `hearth` is where `GetBindLocation()` is (the inn's place), nil while the hearthstone (item 6948) is on cooldown by `C_Container.GetItemCooldown`. `legs = { { kind = "run"|"fly"|"hearth"|"sail", to = {map,x,y}, node = n, crossing = id, seconds = s } ... }`. Same continent: the cheapest of running, run→fly→run (both nodes known; flight time recorded or distance ÷ flight speed), hearth→run. Other continent: through the cheapest crossing the faction can use, each side planned as on one continent. Returns `math.huge` when no way exists.

- [ ] **Step 1: Write the failing test** `try("13.0 planner: travel", ...)`: stub `C_Map.GetWorldPosFromMapPos` so map 1 and 2 are continent 0 (map 1 at origin, map 2 offset 3000 yards east, 1000×1000 yards each) and map 3 is continent 1. Assertions:

```lua
local A, B = { map = 1, x = 10, y = 10 }, { map = 1, x = 20, y = 10 }
local s, legs = ns.PlannerTravel(A, B, ctx); if math.abs(s - 100 / 7) > 0.5 or legs[1].kind ~= "run" then error("a short run") end
local far = { map = 2, x = 50, y = 50 }
s, legs = ns.PlannerTravel(A, far, ctx); if legs[2] == nil or legs[2].kind ~= "fly" then error("far: a known flight is used") end
ctx.flights[2].known = false
s, legs = ns.PlannerTravel(A, far, ctx); for _, l in ipairs(legs) do if l.kind == "fly" then error("never an unknown flight") end end
ctx.hearth = { map = 2, x = 50, y = 49 }; s, legs = ns.PlannerTravel(A, far, ctx); if legs[1].kind ~= "hearth" then error("hearth when faster") end
s, legs = ns.PlannerTravel(A, { map = 3, x = 50, y = 50 }, ctx); local sailed = false; for _, l in ipairs(legs) do sailed = sailed or l.kind == "sail" end
if not sailed then error("the other continent: by boat") end
ctx.faction = "Horde"; s = ns.PlannerTravel(A, { map = 3, x = 50, y = 50 }, ctx); if s ~= math.huge then error("no crossing for this faction") end
```

Plus a flight-record check: fire `TAXIMAP_OPENED` with stubbed taxi nodes → `ns.PlannerKnownFlight(5)` true; `PLAYER_CONTROL_LOST` with `UnitOnTaxi` true, advance `GetTime` 60, `PLAYER_CONTROL_GAINED` near node 6 → `ns.root.plannerFlightTimes["5-6"] == 60` and `ns.PlannerLandedAt(6)`.

- [ ] **Step 2: Run to see it fail.**
- [ ] **Step 3: Implement `PlannerTravel.lua`.**
- [ ] **Step 4: Run to see it pass** (both modes, audit, luacheck).
- [ ] **Step 5: Commit**: `git commit -m "Planner: travel by foot, flight, hearthstone and boat"`

---

### Task 4: What a quest is worth: candidates, experience (with kills), time, pace

**Files:**
- Create: `FantasyGlassUI/Planner.lua` (this task: the scoring half)
- Modify: `FantasyGlassUI/FantasyGlassUI.toc`, `FantasyGlassUI/Core.lua` (defaults `plannerGroup = "solo"`, `plannerLearnFlights = true`, `plannerWhy = true`)
- Test: `tests/smoke.py`

**Interfaces:**
- Consumes: records (Task 2), `ns.PlannerTravel` (Task 3).
- Produces:
  - `ns.PlannerKillXP(playerLevel, mobLevel, elite) -> xp`: the classic formula. Base `playerLevel * 5 + 45`. Mob at or above you: `base * (1 + 0.05 * min(mob - player, 4))`. Below: 0 at or under the gray level (player ≤ 5: 0; ≤ 39: `player - floor(player/10) - 5`; ≤ 59: `player - floor(player/5) - 1`; else `player - 9`), otherwise `base * (1 - (player - mob) / ZD)` with ZD = 5 (<8), 6 (<10), 7 (<12), 8 (<16), 9 (<20), 11 (<30), 12 (<40), 13 (<45), 14 (<50), 15 (<55), 16 (<60), else 17. Elite ×2. Rounded down.
  - `ns.PlannerCandidates(source, ctx) -> list, skipped` where `ctx.level`, `ctx.group` (`"solo"|"grouped"|"all"`), `ctx.inGroup` (boolean), `ctx.done(id) -> boolean`, `ctx.onQuest(id) -> boolean`. Keeps: quests in the log always; others when `doable`, not `repeatable`, `level` within `ctx.level - 4 .. ctx.level + 2`, not done, prerequisites done (`pre` all, `preAny` one), and allowed by the group setting (solo: no elite/group/dungeon; grouped: those only when `ctx.inGroup`; all: always). `skipped = { group = n }` counts the ones left out by the group setting.
  - `ns.PlannerQuestTime(rec, ctx) -> seconds`: per objective: kill `count * 25`, item `count * 25 / 0.5`, place `0`, other `60`; plus spread (the farthest two spots of the objective ÷ `ctx.speed`); times `ctx.pace` (default 1).
  - `ns.PlannerQuestXP(rec, ctx) -> xp`: `rec.xp` plus kill experience of kill objectives (`count * ns.PlannerKillXP(ctx.level, mobLevel, rec.elite)`) plus half the `xp` of `nextQuest` when it is a candidate.
  - Pace: `ns.PlannerPace() -> number`, stored per character in `ns.root.planner[charKey].pace`; after each hand-in of a planned quest, `actual / estimated` is folded in as an average of the last 10, kept between 0.5 and 3.

- [ ] **Step 1: Failing test** `try("13.0 planner: what a quest is worth", ...)`:

```lua
if ns.PlannerKillXP(10, 10) ~= 95 or ns.PlannerKillXP(10, 12) ~= 104 or ns.PlannerKillXP(10, 4) ~= 0 or ns.PlannerKillXP(10, 10, true) ~= 190 then error("kill xp") end
local list, skipped = ns.PlannerCandidates(fakeSource, { level = 10, group = "solo", inGroup = false, done = function() return false end, onQuest = function() return false end })
-- fakeSource: 201 level 9, 202 level 3 (too low), 203 level 10 elite, 204 level 10 group, 205 level 11 needing 201 first, 206 repeatable
local ids = {}; for _, r in ipairs(list) do ids[r.id] = true end
if not ids[201] or ids[202] or ids[203] or ids[204] or ids[205] or ids[206] or skipped.group ~= 2 then error("solo candidates") end
list = ns.PlannerCandidates(fakeSource, { level = 10, group = "grouped", inGroup = true, done = function(id) return id == 201 end, onQuest = function() return false end })
ids = {}; for _, r in ipairs(list) do ids[r.id] = true end
if not (ids[203] and ids[204] and ids[205]) or ids[201] then error("grouped, with 201 done") end
if ns.PlannerQuestXP(fakeSource.quest(201), { level = 10 }) <= fakeSource.quest(201).xp then error("kills add experience") end
```

- [ ] **Step 2: Run to see it fail.** **Step 3: Implement.** **Step 4: Pass** (both modes). **Step 5: Commit**: `"Planner: candidates and what each is worth, kills counted"`

---

### Task 5: Hubs, the zone and the route

**Files:**
- Modify: `FantasyGlassUI/Planner.lua`
- Test: `tests/smoke.py`

**Interfaces:**
- Consumes: Tasks 2–4.
- Produces:
  - `ns.PlannerHubs(candidates, ctx) -> hubs`: givers and hand-ins within 150 yards of each other on the same map form a hub (single-link clustering on world position). `hub = { map, x, y, quests = {records}, xp, seconds }` where `seconds` covers picking up, doing the objectives (ordered nearest-next from the hub), handing in, and the travel between them.
  - `ns.PlannerPickZone(candidates, ctx) -> map`: for each map with candidates, `(sum xp of its best hubs) / (their seconds + travel there)`; the best map. Re-picked when `ctx.level` has risen 3 since the last pick or the current zone has no hub left.
  - `ns.PlannerRoute(ctx) -> guide, summary`: picks the zone, then up to **2** hubs in order of experience per hour including travel from the previous one; turns them into steps (`fly`/`hearth`/`sail`/`goto` legs from `ns.PlannerTravel`, then `accept` for each quest, `do` per quest with the objective's spot, `turnin`). Learning flights: when `ctx.learnFlights` and an unknown flight point lies within 120 seconds of detour on a leg, or the next leg would use it, a `learnflight` step is inserted before passing it. `guide = { name = ns.GUIDE_PLANNED, steps = {...} }`; `summary = { zone = map, fromLevel, toLevel, xp, seconds, skipped = { group = n }, empty = boolean }`. When there are no candidates anywhere: `steps = {}`, `summary.empty = true`.
  - `ns.GUIDE_PLANNED = "\1planned"` (a name no saved guide can have).
  - Bind: when the zone is newly picked and its best hub has an innkeeper (Questie NPC data: `npcFlags` innkeeper bit) and you are bound elsewhere, a `bind | <inn name>` step goes after that hub's accepts, since the plan will hand in there.
  - Each step may carry `step.why = { xp = n }` or `{ saves = seconds }` for Task 7's "Show why".

- [ ] **Step 1: Failing test** `try("13.0 planner: hubs and the route", ...)` with a fake world: zone A (map 1) with a hub of three quests near (30,40) and a lone quest at (80,80); zone B (map 2, same continent) with a richer hub; zone C on the other continent; flight points 5 (known, map 1) and 6 (unknown, between). Assertions:
  - `#ns.PlannerHubs(cands, ctx)` for zone A is 2, and the three-quest hub has `#quests == 3`.
  - `ns.PlannerPickZone` returns map 2 when its hub's experience per hour is higher even with the travel; returns map 1 after zone B's quests are marked done.
  - The route's steps contain an `accept` for each quest of the first hub before any of its `do` steps, and every `turnin` after its `do`.
  - With `learnFlights = true`, a `learnflight 6` step appears; with `false`, none.
  - Every step parses back through `ns.GuideParse(ns.GuideText(guide))` unchanged.
  - A newly picked zone whose hub has an innkeeper adds one `bind` step when bound elsewhere, and none when already bound there.
  - With every quest done, `summary.empty == true` and `#guide.steps == 0`.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass.**
- [ ] **Step 5: Commit**: `"Planner: hubs, the best zone, and the route"`

---

### Task 6: Running it: slices, events, combat, following the plan

**Files:**
- Modify: `FantasyGlassUI/Planner.lua`, `FantasyGlassUI/Guide.lua` (`ns:GuideGet` returns the planned guide for `ns.GUIDE_PLANNED`; panel title "Planned: <zone>, level a → b"; a faint line "Skipped: n group quests (Solo is on)" when `summary.skipped.group > 0`; the empty-plan line), `GuideCommand` (`plan`)
- Test: `tests/smoke.py`

**Interfaces:**
- Consumes: Task 5's `ns.PlannerRoute`.
- Produces:
  - `ns:PlannerStart() -> boolean` (follows the planned guide, starts planning), `ns:PlannerStop()`, `ns:PlannerReplan(reason)` (queues a plan; `reason` for debugging only).
  - The work runs as a coroutine resumed by `ns:Every(0, "Planner", fn)` with `ns.PLANNER_BUDGET_MS = 4`: the planning functions call `ns.PlannerYield()` in their loops, which yields when the slice's time is used. Not resumed while `InCombatLockdown()`, or while the player has no world position (`ns.PlannerWorldPos` of `ns.GuideHere()` is nil).
  - Replans on `QUEST_TURNED_IN`, `PLAYER_LEVEL_UP`, `QUEST_REMOVED`, a newly learned flight point (Task 3 calls `ns:PlannerReplan("flight")`), Questie becoming ready, and `/fgui guide plan`. Each replan replaces the planned guide's steps and resets the guide state to step 1 (the panel advances past done steps itself).
  - Questie missing or changed: `ns.PlannerLogSource()` is used and the panel prints once per session "Install Questie to plan new quests too." (missing) or "Questie changed; planning from your quest log only." (changed).
  - `/fgui guide plan` → `ns:PlannerStart()`; `/fgui guide <name>` and `/fgui guide off` stop the planner.

- [ ] **Step 1: Failing test** `try("13.0 planner: running it", ...)`:
  - `ns:PlannerStart()`; run the fake frame loop (`runTimers()`) until `ns.plannerBusy` is false; `ns.GuideState().name == ns.GUIDE_PLANNED` and the planned guide has steps.
  - Same plan in slices: set `ns.PLANNER_BUDGET_MS = 0` (every loop yields), plan again, and compare `ns.GuideText` with the unsliced result: identical.
  - Combat: start a replan, set `InCombatLockdown` true, run timers 10 times: no progress (`ns.plannerSteps` unchanged); false again: it finishes.
  - No position: `C_Map.GetBestMapForUnit` returns nil: planning waits, no `CALL ERROR`, no print.
  - `fireEvent("QUEST_TURNED_IN", 101)` queues a replan (`ns.plannerQueued == true`).
  - Questie absent: the plan comes from the log source and the install line is printed once across two replans.
  - Empty world: the panel's line reads the translated "No quests left worth the trip; grinding or a dungeon may be faster".
  - Locked (`ns.root.guideKey = nil`): `ns:PlannerStart()` returns false and nothing is planned.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass.**
- [ ] **Step 5: Commit**: `"Planner: plans a slice at a time, never in a fight, and again after each hand-in and level"`

---

### Task 7: The settings, the button, translations

**Files:**
- Modify: `FantasyGlassUI_Options/Bars.lua` (`ns.BuildGuidePage`, below the existing buttons): button "Plan my route" (`ns:PlannerStart()`), a three-way choice "Group quests: Solo / When grouped / Everything" (`ns.db.plannerGroup` = `"solo"`/`"grouped"`/`"all"`), checkboxes "Learn new flight points on the way" (`plannerLearnFlights`) and "Show why each step is there" (`plannerWhy`; when on, a step's text gets "(+4,100 xp)" or "(saves ~3 min)"). Changing any of them calls `ns:PlannerReplan("settings")` when the planner is running.
- Modify: `FantasyGlassUI_Locales/Locales.lua` via `site-src/tools/add_tr.py` for every new phrase (button, choices, checkboxes, step texts, panel lines, the Questie lines).
- Test: `tests/smoke.py`

- [ ] **Step 1: Failing test** `try("13.0 planner: settings", ...)`: unlock, `ns:ToggleConfig("guide")`, find the "Plan my route" button on `ns.guidePage` and click it → `ns.GuideState().name == ns.GUIDE_PLANNED`; set the group choice to "grouped" → `ns.db.plannerGroup == "grouped"` and `ns.plannerQueued`; locked → the Guide tab shows "Coming soon" and no planner controls. Then: `python3 site-src/tools/missing_tr.py FantasyGlassUI/Planner*.lua FantasyGlassUI/Guide.lua FantasyGlassUI_Options/Bars.lua` (from the root) lists nothing.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass.**
- [ ] **Step 5: Commit**: `"Planner: its settings on the Guide tab, in nine languages"`

---

### Task 8: Check everything

- [ ] **Step 1:** `cd FantasyGlassUI && python3 ../tests/smoke.py 2>&1 | grep -E "^syntax|^errors:"` → `syntax: all ... OK` and `errors: no errors` twice.
- [ ] **Step 2:** from the root, `luacheck . -q` → 0 warnings; `python3 tests/forever_audit.py` exits 0.
- [ ] **Step 3:** `python3 -m pytest tests -q` → 6 passed.
- [ ] **Step 4:** `grep -rn "planner\|Plan my route" FantasyGlassUI/README.md README.md CHANGELOG.md FantasyGlassUI/CHANGELOG.md docs wiki site-src/site` → nothing (unreleased).
- [ ] **Step 5:** Tell the player what to check in the game before batch 1 counts as done: Questie installed and ready; the crossing table's docks (map and coordinates, one by one); one real plan followed for a hub; one flight learned and one taken.
