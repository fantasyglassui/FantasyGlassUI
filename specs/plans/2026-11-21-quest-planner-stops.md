# Quest Planner, Batch 2 (stops on the way) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The planned route also stops where you need to: your class trainer, a vendor to sell, repair and restock, your profession and riding trainers, the mailbox, a few unexplored spots and gathering nodes, and it holds a hand-in so you level where you train; the panel tells you when a talent point is waiting.

**Architecture:** One general mechanism, built first: a *stop* is a kind of place (from Questie's townsfolk lists, or places the add-on has seen you use), a reason it is wanted now, and a step kind. After `ns.PlannerRoute` lays out the hubs, a stops pass inserts each wanted stop at a hub the route already passes (within the hub radius) or, if none, as the cheapest detour, and adds the detour's time to the summary. Each later task registers one or more stops with that mechanism. Path extras (exploring, gathering) are small detours on legs the route already has.

**Tech Stack:** Lua 5.1 (WoW Forever, interface 16001), the add-on's helpers, Questie internals read through `QuestieLoader:ImportModule` (all pcall'd), tests in `tests/smoke.py`.

**Spec:** `specs/2026-11-21-quest-planner-design.md`: **Build order, batch 2**: items #2, #3, #23, #24, #25, #26, #27, #40, #41, #42. Batch 1's plan and notes: `specs/plans/2026-11-21-quest-planner-core.md`, `specs/plans/2026-11-21-quest-planner-core-notes.md`.

## Global Constraints

- Everything in batch 1's Global Constraints still binds (Forever audit, `luacheck . -q` 0 warnings, smoke.py `errors: no errors` twice, never plan in combat, 4 ms slices with `ns.PlannerYield()` only in plain loops — never inside `pcall`/`Try`, a sort comparator or a gsub callback, since WoW runs Lua 5.1 — all phrases in 9 languages, Questie read-only through pcall, everything behind `ns:GuideUnlocked()`, nothing in /fgui help, README, site or changelog, unlock phrase never in any file, commits by DustyMouse with no attribution lines, never push).
- Work on branch `quest-planner` in the worktree `/home/claude/fantasyglassui-planner`.
- Values from the spec: class trainer every **2** levels; sell and repair when **3 or fewer** free bag slots or any equipped item under **30%** durability; gathering detour at most **20 seconds**; mail stop only when it costs under **20 seconds**; held hand-ins only when the trainer town is within **5 minutes** on the plan and holding costs no extra trip.
- Values from WoW Forever (checked 2026-11-21, warcrafttavern.com/forever/guides/riding): riding at level **40**; Apprentice Riding **100 gold** to train, mount **20 gold**; Paladins and Warlocks get their mounts from class quests (no mount vendor stop for them, still the riding trainer).
- Ruling, "explore within a few seconds": a detour of at most **15 seconds**.
- Ruling, gathering nodes: only nodes the add-on has seen you gather (recorded per account). Questie's object data does not say which objects are herbs or ore, so the spec's "from Questie where it has them" is left for later.
- Every stop is a step kind that round-trips through `ns.GuideParse(ns.GuideText(guide))`; `step.why` stays in memory only.
- Each stop has its own setting on the Guide tab, on by default: "Visit your trainer on the way" (`plannerTrainer`), "Sell and repair stops" (`plannerVendor`), "Buy supplies at the vendor stop" (`plannerSupplies`), "Save hand-ins to level in town" (`plannerHold`), "Explore on the way" (`plannerExplore`), "Gather on the way" (`plannerGather`), "Profession training stops" (`plannerProfession`), "Mail stops" (`plannerMail`), "Mount reminder" (`plannerMount`). Changing one replans (only when the planner is following).

## Review Focus

- **A stop whose window closes while it is not the current step** (you visit a vendor early, or between steps): the step must not tick; it ticks only when it is current, or when the reason went away (bags no longer full). → Task 2 test.
- **No place of that kind known** (Questie missing, or none friendly to your faction): no stop and no error; a "nearest" line is not invented. → Task 2 test.
- **The reason changes between plans** (you sold everything at a vendor not on the route): the next replan drops the stop. → Task 4 test.
- **Unreadable game values** (bags not loaded at login, an empty slot's durability is nil, a secret value in a fight): the stop is simply not wanted; nothing errors. → Task 4 test.
- **You can't afford riding yet**: no riding stop, only the "Riding: 38g to go" line; and never a mount vendor stop for a Paladin or Warlock. → Task 5 test.

---

## File Structure

- Create `FantasyGlassUI/PlannerStops.lua` (TOC after `PlannerRoute.lua`): the stop registry, the places reader, the stops pass, and every stop's want/find/step rules. If it passes ~600 lines, the path extras (Task 6) go in `FantasyGlassUI/PlannerPath.lua` instead.
- Modify `FantasyGlassUI/PlannerSource.lua`: `places(kind, arg)` on both sources; `inns()` becomes `places("innkeeper")` (keep `inns()` as a thin alias).
- Modify `FantasyGlassUI/PlannerRoute.lua`: call the stops pass at the end of `ns.PlannerRoute`; the held hand-ins hook in `HubSteps`.
- Modify `FantasyGlassUI/Guide.lua`: step kinds `train`, `vendor`, `mail`, `explore`, `gather`; ticking on window close; the talent and riding panel lines.
- Modify `FantasyGlassUI/Planner.lua`: register the window-close events with the runner's event frame.
- Modify `FantasyGlassUI/Core.lua` (defaults), `FantasyGlassUI_Options/Bars.lua` (the nine switches), `FantasyGlassUI_Locales/Locales.lua`, `tests/smoke.py`, `.luacheckrc`.

---

### Task 1: Places: trainers, vendors, mailboxes and more

**Files:** Modify `FantasyGlassUI/PlannerSource.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces `source.places(kind, arg) -> { {name, map, x, y, id} ... }` (empty list when unknown), on both sources. Kinds:
  - `"innkeeper"`, `"repair"`, `"classTrainer"`, `"mailbox"`: from Questie's `Questie.db.char.townsfolk` (`["Innkeeper"]`, `["Repair"]`, `["Class Trainer"]`, `["Mailbox"]`: NPC ids, mailboxes are object ids), falling back to the `npcFlags` scan batch 1 uses for inns.
  - `"vendor"` with `arg` `"Food"`, `"Drink"` or `"Ammo"`: `Questie.db.char.vendorList[arg]` (NPC ids).
  - `"professionTrainer"` with `arg` a skill line id (e.g. 186 Mining, 762 Riding): `QuestieLoader:ImportModule("Townsfolk").professionTrainers[arg]` (NPC ids).
  - `"mountVendor"`: our own table `ns.PLANNER_MOUNT_VENDORS = { [raceFile] = {npcId, ...} }` (filled with best-known ids, comment: check in game), resolved through Questie spawns.
  - Positions from NPC `spawns` (or object spawns via `QueryObjectSingle(id, "spawns")`), converted like quest givers; every spawn on a known map is a separate place; NPCs not friendly to the player's faction (`friendlyToFaction` not nil, `"AH"` or the player's) are left out.
  - Places the add-on has seen you use are added too: on `MAIL_SHOW`, `MERCHANT_SHOW` and `TRAINER_SHOW`, the player's position is saved per account in `ns.root.plannerSeen[kind]` (kinds `mailbox`, `vendor`, `trainer`), unique within 30 yards, with the NPC's name (`UnitName("npc")`, pcall, skip secret). The log source returns only these.
  - Resolved lists are cached per session per `(kind, arg)`; `ns.PlannerSourceReset()` clears them; the NPC id scans call `ns.PlannerYield()` per entry outside any `Try`.

- [ ] **Step 1: Failing test** `try("13.1 stops: places", ...)`. A fake Questie with `Questie.db.char.townsfolk = { ["Class Trainer"] = {31}, ["Repair"] = {32}, ["Mailbox"] = {901} }`, `vendorList = { Drink = {33} }`, a Townsfolk module with `professionTrainers = { [186] = {34} }`, NPC 35 hostile (`friendlyToFaction = "H"` for an Alliance player). Assertions: `places("classTrainer")[1]` is NPC 31 at its spawn's map and x,y; `places("mailbox")` resolves object 901 through object spawns; `places("vendor", "Drink")[1].id == 33`; `places("professionTrainer", 186)[1].id == 34`; a hostile NPC is never returned; `places("repair")` with no townsfolk table and no flags is `{}`; firing `MAIL_SHOW` at a stubbed position adds a `mailbox` place to both sources, and a second `MAIL_SHOW` within 30 yards adds none; `inns()` still returns the innkeepers.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass** (smoke both modes, luacheck, audit). **Step 5: Commit** `"Planner: where trainers, vendors and mailboxes are"`.

---

### Task 2: Stops: the mechanism, the step kinds, and the class trainer

**Files:** Create `FantasyGlassUI/PlannerStops.lua`; modify `PlannerRoute.lua`, `Guide.lua`, `Planner.lua`, `Core.lua`, `Bars.lua`, `Locales.lua`, `FantasyGlassUI.toc`; test `tests/smoke.py`.

**Interfaces:**
- Produces:
  - `ns.PlannerStop(def)` registers a stop: `def = { id = string, setting = "plannerTrainer", kind = "train"|"vendor"|"mail", want = function(ctx, summary) -> reason|nil, places = function(ctx, reason) -> places, text = function(place, reason) -> string, why = function(reason) -> table|nil }`.
  - `ns.PlannerAddStops(guide, summary, ctx)`: for each registered stop whose setting is not false and whose `want` returns a reason: take its places; if one is within `ns.PLANNER_HUB_YARDS` of a step place on the route, insert the stop step right after the last accept at that hub (or before the hub's first `do` when it has no accepts); otherwise insert it where it adds the least travel (`ns.PlannerTravel` from the step before to the place and from the place to the step after, minus the direct trip), add that detour to `summary.seconds`, and mark `step.why = { detour = seconds }`. No places, or every place unreachable: no step. Called at the end of `ns.PlannerRoute` before it returns (with `ns.PlannerYield()` in its loops).
  - `ctx` gains `ctx.stopsWanted = { [id] = reason }` filled by the pass (for panel lines and tests).
  - Step kinds in Guide.lua: `train | <trainer>`, `vendor | <vendor>`, `mail | <mailbox>`, `explore | <area>`, `gather | <node>` (all text-only steps with a place: `@ map:x,y`). Labels: "Train", "Visit the vendor", "Check your mail", "Explore", "Gather". Done rules: a `train`/`vendor`/`mail` step ticks when `TRAINER_CLOSED`/`MERCHANT_CLOSED`/`MAIL_CLOSED` fires while it is the current planned step; `explore`/`gather` are done when `world.near(step)` (passing it is enough); all of them also tick on the next replan if their stop is no longer wanted (the replan simply doesn't include them).
  - Class trainer stop (`id = "classTrainer"`, setting `plannerTrainer`, kind `train`): wanted when the player's level is even and at least 2, and the trainer has not been visited since reaching that level (remember the level of the last `TRAINER_CLOSED` per character), or when `summary.toLevel` crosses an even level (then the stop goes at the first hub the route reaches after that level, as far as the plan can tell, else at the end); places `places("classTrainer")`; text = trainer name. Not wanted below level 2 or while no trainer is known.
  - Setting `plannerTrainer` (default true) in Core.lua and its switch "Visit your trainer on the way" on the Guide tab, translated.
- [ ] **Step 1: Failing test** `try("13.1 stops: the mechanism and the class trainer", ...)`:
  - Parse round trip for one line of each new kind.
  - A fake stop with a place 20 yards from a planned hub's accept: one step of its kind, right after that hub's last accept, no detour added.
  - The same fake stop with its only place 600 yards off the route: one step, `why.detour > 0`, and `summary.seconds` grew by that detour.
  - A stop with no places, and one whose only place is on a continent with no crossing: no step, no error.
  - Class trainer: level 10, no trainer visit recorded → a `train` step; after firing `TRAINER_CLOSED` at level 10 and replanning → none; level 11 → none; setting off → none.
  - Ticking: with a `vendor` step current, `MERCHANT_CLOSED` ticks it; with a `vendor` step later in the plan and an `accept` current, `MERCHANT_CLOSED` ticks nothing.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: stops on the way, starting with your class trainer"`.

---

### Task 3: Levels: held hand-ins and talent points

**Files:** Modify `PlannerRoute.lua` (`HubSteps`), `PlannerStops.lua`, `Guide.lua` (panel line), `Core.lua`, `Bars.lua`, `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Consumes the class trainer stop (Task 2).
- Produces:
  - Held hand-ins (setting `plannerHold`): when a `turnin` would take the player to a level where the class trainer stop becomes wanted (an even level, by the plan's running xp), and a hub with a class trainer comes up within 300 seconds of plan time later in the route, and that hub is visited anyway, the turnin step (and any other turnins at that hub that would also cross the level) is moved to that later hub, placed before the `train` step there. Never when it would add a trip (the turnin NPC must be reachable at no cost: the later hub is the same hub, or the quest's hand-in NPC is within the hub radius of the trainer's hub). `step.why = { held = true }` on a moved turnin.
  - Talent points: `ns.PlannerUnspentTalents() -> number|nil` (Forever uses the modern talent API: `C_ClassTalents.GetActiveConfigID`, `C_ClassTalents.GetTraitTreeForSpec`/the config's tree, `C_Traits.GetTreeCurrencyInfo`; all pcall'd; nil when the game can't say). When it is greater than 0, the panel shows a faint line "%d talent point(s) to spend" with a small button "Build" that opens the add-on's talent builds (the existing talent-build window or `/fgui talents` handler; find it in Companion.lua/CharMore.lua). Shown on the planned guide only.
- [ ] **Step 1: Failing test** `try("13.1 stops: held hand-ins and talents", ...)`: a plan where hub A's turnin takes the player from 11 to 12 and hub B (next, 200 s later) has a class trainer → the turnin is in hub B, before `train`; the same with hub B 400 s later → not moved; hub B not on the route → not moved; setting off → not moved. Talents: stub the traits API to report 2 unspent → the panel line reads "2 talent points to spend"; the API missing or erroring → no line, no error.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: hand-ins held to level where you train, and talent points waiting"`.

---

### Task 4: The vendor: sell, repair, supplies

**Files:** Modify `PlannerStops.lua`, `Core.lua`, `Bars.lua`, `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Consumes `ns.PlannerStop` (Task 2), `places("repair")`, `places("vendor", ...)` (Task 1).
- Produces:
  - `ns.PlannerBagFree() -> number|nil` (sum of `C_Container.GetContainerNumFreeSlots(bag)` over bags 0–4; nil if any reads fail or are secret) and `ns.PlannerLowestDurability() -> number|nil` (lowest `cur/max` over equipped slots 1–19 that have durability; nil when none can be read).
  - Sell and repair stop (`id = "vendor"`, setting `plannerVendor`, kind `vendor`): wanted when free slots are 3 or fewer or lowest durability is under 0.30; places `places("repair")` when durability is the reason, else `places("repair")` plus every `places("vendor", ...)` list (any vendor can buy). Text "Sell and repair at <name>" (or "Sell at <name>").
  - Supplies (setting `plannerSupplies`), folded into the same vendor step's text, or a vendor stop of its own when no vendor stop is wanted: our own table `ns.PLANNER_SUPPLIES = { ammo = { arrow = { {1, 2512}, {10, 2515}, {25, 3030}, {40, 11285} }, bullet = { {1, 2516}, {10, 2519}, {25, 3033}, {40, 11284} } }, drink = { {1, 159}, {5, 1179}, {15, 1205}, {25, 1708}, {35, 1645}, {45, 8766} }, food = { {1, 4540}, {5, 4541}, {15, 4542}, {25, 4544}, {35, 4601}, {45, 8950} } }` (`{minLevel, itemID}`; best entry at or below the player's level). Ammo only when the ranged slot holds a bow/crossbow (arrows) or gun (bullets) by `C_Item.GetItemInfoInstant` subclass; drink only for classes with mana (`UnitPowerType("player") == Enum.PowerType.Mana` or class in a small list); food for everyone. Count in bags by `C_Item.GetItemCount`. Use rate: per character, the drop in count per hour played, measured between plans (default until measured: ammo 600/h, drink 12/h, food 8/h). Wanted when count < rate × the plan's hours (`summary.seconds / 3600`, at least 0.5). Text adds "; buy 400 arrows" / "; buy 20 water" (amounts: enough for one hour, rounded up to 20 for food/drink and 200 for ammo). Places: `places("vendor", "Ammo"|"Drink"|"Food")`, intersected with the sell/repair places when both are wanted and one place serves both; otherwise the supplies vendor.
  - Settings `plannerVendor`, `plannerSupplies` and their switches, translated.
- [ ] **Step 1: Failing test** `try("13.1 stops: the vendor", ...)`: 2 free slots → one `vendor` step "Sell at …"; 20 free and a chest at 25% → "Sell and repair at …" at a repair NPC; 20 free, all at 90% → none; bags unreadable (stub returns nil) → none, no error; a hunter with a bow and 50 arrows on a 1-hour plan → "; buy 600 arrows" or the 200-rounded amount; a warrior → no drink; replan after bags freed → the stop is gone.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: sell, repair and restock at a vendor on the way"`.

---

### Task 5: Professions, riding and your mount

**Files:** Modify `PlannerStops.lua`, `Guide.lua` (riding line), `Core.lua`, `Bars.lua`, `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Consumes `ns.PlannerStop`, `places("professionTrainer", id)`, `places("mountVendor")`.
- Produces:
  - Profession training (setting `plannerProfession`, kind `train`): `GetProfessions()` then `GetProfessionInfo(index)` (pcall) gives `rank`, `maxRank`, `skillLine`; wanted per profession when `rank >= maxRank` and `maxRank` is below the game's top for that line (300 in Forever's classic skills; until a trainer says otherwise) — one stop per such profession; places `places("professionTrainer", skillLine)`; text "Train <profession> at <name>".
  - Riding (setting `plannerMount`): at level 40 or higher with no riding skill (`GetProfessions` has no riding line, or riding rank 0), wanted when `GetMoney()` covers 100 gold (plus 20 gold for the mount unless the class is PALADIN or WARLOCK) — then a riding trainer stop (`places("professionTrainer", 762)`) and, for other classes, a mount vendor stop (`places("mountVendor")`) after it. Not affordable: no stops, and the panel shows "Riding: %s to go" with the gold short (formatted with the add-on's gold formatter if it has one).
  - Settings `plannerProfession`, `plannerMount`, switches, translations.
- [ ] **Step 1: Failing test** `try("13.1 stops: professions and riding", ...)`: Mining 75/75 → a `train` step "Train Mining at …"; Mining 74/75 → none; level 40 warrior with 130 gold → riding trainer step then mount vendor step; with 80 gold → no stops, line "Riding: 40g to go" (or the formatter's text for 40 gold); a level 40 paladin with 110 gold → riding trainer only, no mount vendor; level 39 → nothing.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: profession and riding trainers, and your mount"`.

---

### Task 6: On the way: mail, exploring, gathering

**Files:** Modify (or create, see File Structure) `PlannerStops.lua`/`PlannerPath.lua`, `Planner.lua` (gather recording events), `Core.lua`, `Bars.lua`, `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces:
  - Mail (setting `plannerMail`, kind `mail`): wanted when `HasNewMail()` is true; only placed at a hub the route passes, or as a detour under 20 seconds (never further); places `places("mailbox")`.
  - Exploring (setting `plannerExplore`): along each run leg of the plan, sample points every 40 yards on the leg and 40 yards either side of it; a sample where `C_MapExplorationInfo.GetExploredAreaIDsAtPosition(map, CreateVector2D(x/100, y/100))` returns nothing (and the map supports exploration: the same call returns areas somewhere on that map) is an unexplored spot; if a spot adds at most 15 seconds of detour, insert `explore | Unexplored area @ map:x,y` before the leg's destination step. At most 3 per plan. Each call pcall'd, `ns.PlannerYield()` per sample outside the pcall.
  - Gathering (setting `plannerGather`): record nodes per account in `ns.root.plannerNodesSeen = { [map] = { {name, x, y, skill} ... } }` when `UNIT_SPELLCAST_SENT` for the player names a target while casting a gathering spell (Herb Gathering, Mining or Skinning by spell name from `C_Spell.GetSpellInfo`, pcall), with the player's position; unique within 10 yards. When the player has Herbalism or Mining (by `GetProfessions` skill lines 182/186), nodes of that skill within a 20-second detour of a run leg become `gather | <name> @ map:x,y` steps on that leg (at most 5 per plan), and the panel's first `do` step at a hub on such a leg gets the text note "N <name> on the way" only via the steps themselves (no extra line). Skinning: when the player has Skinning (393), a `do` step whose objective is a kill gets " (skin them)" appended through `step.why = { skin = true }` and the Show why text.
  - Settings `plannerMail`, `plannerExplore`, `plannerGather`, switches, translations.
- [ ] **Step 1: Failing test** `try("13.1 stops: mail, exploring and gathering", ...)`: mail waiting and a mailbox 10 yards from a hub → `mail` step; mailbox 300 yards off → none; no mail → none. Exploring: stub the exploration call to report nothing for x in 40–45 on map 1 and areas elsewhere → one `explore` step on the leg crossing it; stub it to report nothing anywhere on the map (no exploration data) → none; more than 3 spots → 3 steps. Gathering: fire `UNIT_SPELLCAST_SENT` for Mining on "Copper Vein" at a position → recorded once (twice within 10 yards → still one); a miner's plan with a run leg passing 30 yards from it → `gather | Copper Vein` step; a herbalist without Mining → none; a node 200 yards off → none.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: mail, unexplored spots and gathering nodes on the way"`.

---

### Task 7: Check everything

- [ ] **Step 1:** `cd FantasyGlassUI && python3 ../tests/smoke.py 2>&1 | grep -E "^syntax|^errors:"` → `syntax: all ... OK`, `errors: no errors` twice.
- [ ] **Step 2:** from the root: `luacheck . -q` → 0 warnings; `python3 tests/forever_audit.py` exits 0; `python3 tests/lockaudit.py` and `python3 tests/secretaudit.py` as tests/test_addon.py expects.
- [ ] **Step 3:** `python3 -m pytest tests -q` → 6 passed.
- [ ] **Step 4:** `python3 site-src/tools/missing_tr.py FantasyGlassUI/Planner*.lua FantasyGlassUI/Guide.lua FantasyGlassUI_Options/Bars.lua` lists nothing new (only the known "solo" and "My route").
- [ ] **Step 5:** `grep -rln -i "planner" FantasyGlassUI/README.md README.md CHANGELOG.md FantasyGlassUI/CHANGELOG.md docs wiki site-src/site` → nothing.
- [ ] **Step 6:** Append to `specs/plans/2026-11-21-quest-planner-core-notes.md` (or a new `-stops-notes.md`) what to check in the game: the mount vendor ids in `ns.PLANNER_MOUNT_VENDORS`, the supply item ids, profession caps, that window-close events tick the right steps, that exploration sampling finds real unexplored spots, and that gathering casts are recorded.
