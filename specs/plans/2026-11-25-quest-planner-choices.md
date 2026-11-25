# Quest Planner, Batch 3 (smarter choices) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The planner chooses better for this character: it counts rested experience, upgrades and reputation you want, learns from your alts' quest times and your deaths, never suggests quests you skipped, trusts elites your class has soloed, plans class, timed, escort and loot-started quests sensibly, helps at hand-in and with a full quest log, suggests an inn when you stop, and says what to do when quests run dry.

**Architecture:** Scoring changes go into `Planner.lua` (`ns.PlannerQuestXP`, `ns.PlannerQuestTime`, `ns.PlannerCandidates`) as extra terms and filters fed from `ctx`; the live `ctx` gains the inputs in `ns.PlannerContext()` (PlannerRoute.lua). Records gain the few fields the choices need in `PlannerSource.lua`. Things that are not scoring (hand-in reward pick, quest-log advice, the inn line, dry-zone suggestions) live in a new `FantasyGlassUI/PlannerAdvice.lua` and show as faint panel lines like batch 2's talent and riding lines.

**Tech Stack:** Lua 5.1 (WoW Forever, interface 16001), the add-on's helpers, Questie internals read through `QuestieLoader:ImportModule` (pcall'd), tests in `tests/smoke.py`.

**Spec:** `specs/2026-11-21-quest-planner-design.md`, **Build order, batch 3**: items #4, #6, #7, #10, #11, #12, #13, #14, #19, #20, #21, #22, #36. Earlier plans and notes in `specs/plans/` (`*-core*`, `*-stops*`).

## Global Constraints

- Everything in batches 1–2's Global Constraints still binds: Forever audit; `luacheck . -q` 0 warnings; smoke.py `errors: no errors` twice; never plan in combat; 4 ms slices; `ns.PlannerYield()` only in plain loops (never inside `pcall`/`Try`, a sort comparator or a gsub callback, since WoW runs Lua 5.1); all phrases in 9 languages; Questie read-only through pcall; everything behind `ns:GuideUnlocked()`; nothing in /fgui help, README, site or changelog; unlock phrase never in any file; commits by DustyMouse with no attribution lines.
- Branch `quest-planner` in `/home/claude/fantasyglassui-planner`. The controller pushes that branch after each reviewed task; implementers never push.
- Saved data: per character through `ns.PlannerCharRecord(true)`; per account under `ns.root.planner*` tables; created only when writing.
- Every new behaviour has a switch on the Guide tab, on by default unless stated: "Count rested experience" (`plannerRested`), "Count upgrades in rewards" (`plannerRewards`), "Pick the best quest reward" (`plannerPickReward`), "Learn from my deaths" (`plannerDeaths`), "Include elites my class has soloed" (`plannerSoloElites`), "Plan class quests" (`plannerClassQuests`), "Suggest an inn when you stop" (`plannerInn`), "Quest log advice" (`plannerLogAdvice`), "Suggest what to do when quests run dry" (`plannerDry`). Reputation goals and the skip list are lists, not switches. Changing any of them replans (only when the planner is following).
- Values from the spec: deaths — **two** deaths in one hub within a level mark it too hard; the mark clears after **two** levels. Quest log holds **25**; advice when **3 or fewer** places are free. Inn suggestion after **an hour or more** of play. Grinding spots: monsters **0–2 levels above** you.
- Rulings (the spec leaves these to the builder):
  - Rested: kills earn double while rested; along the plan, each kill's extra equals its own experience until the rested pool (`GetXPExhaustion()`) is used up. Quest rewards are not doubled.
  - Upgrade value: `bonus xp = item levels gained × 0.02 × UnitXPMax("player")`, at most `0.25 × UnitXPMax`, for the best upgrade among a quest's rewards; only for quests in the log (the game's reward info); Questie has no reward items.
  - Reputation value: `bonus xp = min(reputation the quest gives, reputation still needed) × 0.0002 × UnitXPMax`, per wanted faction.
  - Alts: per account `ns.root.plannerQuestTimes[questID] = { n, avg }` from accept to hand-in while the planner was following, skipping samples over 2 hours; the estimate is `(formula + avg × min(n, 3)) / (1 + min(n, 3))`.
  - Deaths: a hub is "too hard" while the player's level is below `deathLevel + 2`, where two deaths at that level or the one before lie within the hub radius (150 yd) of the hub.
  - Soloed elites: recorded per account by class and `questLevel − playerLevel` when an elite quest is handed in with the player not in a group at accept and at hand-in; in Solo an elite is allowed when a record for the class has a difference at least as high.
  - Inn "close" means `ns.PlannerTravel` to it is at most 120 seconds.
  - Escorts: our own table `ns.PLANNER_ESCORTS = { [questID] = true }` (classic escort ids, comment: check in game), since the data does not mark them.
  - Class quests: our own table `ns.PLANNER_CLASS_QUESTS = { [classFile] = { { id = questID, level = n, kind = "always"|"fit", parts = n }, ... } }` (comment: check in game).
  - Dungeons: our own table `ns.PLANNER_DUNGEONS = { { name, minLevel, maxLevel, map, x, y, zone = areaID }, ... }` (classic dungeons; comment: check in game).

## Review Focus

- **A quest the player skipped, then accepted anyway**: it stays in the plan while it is in the log (the skip list only stops suggestions). → Task 3 test.
- **Rested pool unreadable or zero**: no doubling and no error. → Task 1 test.
- **Reward info not loaded yet** (`GetQuestLogItemLink` nil for a fresh quest): no upgrade bonus that plan, no error; a later plan picks it up. → Task 1 test.
- **The hand-in window shows rewards the add-on can't judge** (no links, secret values, a single reward): nothing is selected. → Task 5 test.
- **A death in a dungeon or battleground**: it doesn't mark an outdoor hub (no world position or a different map ⇒ not counted). → Task 3 test.

---

## File Structure

- Modify `FantasyGlassUI/Planner.lua`: rested, upgrade, reputation and alts' terms; the skip, deaths and soloed-elite filters; the events that record deaths, quest times and soloed elites.
- Modify `FantasyGlassUI/PlannerSource.lua`: record fields `reputation = { {factionID, value} }`, `fromItem = { id, name }` (item-started quests), `escort`, `classQuest`.
- Modify `FantasyGlassUI/PlannerRoute.lua`: `ns.PlannerContext()` inputs; class, timed and escort ordering in the hub loop.
- Create `FantasyGlassUI/PlannerAdvice.lua` (TOC after `PlannerPath.lua`): reward pick at hand-in, quest-log advice, the inn line, dry-zone suggestions, and the three own tables' companions (`ns.PLANNER_DUNGEONS`).
- Modify `FantasyGlassUI/Guide.lua`: panel lines; right-click menu on a quest step.
- Modify `FantasyGlassUI_Options/Bars.lua`, `FantasyGlassUI/Core.lua`, `FantasyGlassUI_Locales/Locales.lua`, `tests/smoke.py`, `.luacheckrc`.

---

### Task 1: Rested experience, upgrades and alts' times in the score

**Files:** Modify `Planner.lua`, `PlannerRoute.lua` (context), `Core.lua`, `Bars.lua`, `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces:
  - `ctx.rested` (number, the rested pool left; nil/0 when none or unreadable), consumed in order by `ns.PlannerQuestXP` through `ctx.restedLeft` (a copy the route decrements as it lays out hubs, so later hubs get less).
  - `ns.PlannerRewardBonus(rec, ctx) -> xp` using the game's reward info for a quest in the log (`GetNumQuestLogChoices(questID)`, `GetQuestLogItemLink("choice"|"reward", i, questID)`, each pcall'd) and `ns.UpgradeAmount(link)`; 0 when not in the log, unreadable, or `plannerRewards` is off. Added in `ns.PlannerQuestXP`.
  - Quest times: `ns.PlannerRecordQuestTime(questID, seconds)` and the blend in `ns.PlannerQuestTime`; `QUEST_ACCEPTED`/`QUEST_TURNED_IN` while following record accept times in memory and samples on hand-in.
  - Settings `plannerRested`, `plannerRewards` with switches.
- [ ] **Step 1: Failing test** `try("13.3 choices: rested, upgrades, alts", ...)`: a kill quest with 8 kills of 95 xp each at level 10 and `ctx.rested = 400` → `PlannerQuestXP` is its base plus 760 plus 400 (only 400 extra); `rested = 0` and `rested = nil` → no extra; two kill hubs laid out by `ns.PlannerRoute` with 500 rested → the first hub gets the extra, the second only what is left. Upgrades: a logged quest whose choice 2 is 6 item levels better, `UnitXPMax` 10,000 → +1,200; 20 levels better → capped at +2,500; `GetQuestLogItemLink` returning nil → 0, no error; setting off → 0. Alts: record 600 s twice for quest 101 whose formula says 200 → estimate (200 + 600×2)/3 ≈ 467; a 3-hour sample is ignored.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: rested experience, upgrades and your alts' quest times"`.

---

### Task 2: Reputation goals

**Files:** Modify `PlannerSource.lua` (record `reputation` from Questie's `reputationReward`), `Planner.lua` (bonus), `Guide.lua` (panel line), `Bars.lua` (picker), `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces:
  - Per character `rec.repGoals = { [factionID] = standingID }` (standing 5 Honored, 6 Revered, 7 Exalted); `ns.PlannerRepNeeded(factionID, standingID) -> number|nil` from `C_Reputation.GetFactionDataByID` (pcall; nil when unreadable or already reached).
  - The bonus (ruling above) inside `ns.PlannerQuestXP`.
  - Guide tab: "Reputation I want" — a button opening a list of the character's known factions (`C_Reputation.GetNumFactions` / `GetFactionDataByIndex`, headers skipped), each with a cycle Honored → Revered → Exalted → off.
  - Panel: when a planned quest gives a wanted faction's reputation, a faint line "%s: %s to %s" (faction, amount with the add-on's number formatting, standing name).
- [ ] **Step 1: Failing test** `try("13.3 choices: reputation goals", ...)`: a fake Questie quest with `reputationReward = { {72, 250} }` → record `reputation[1]` is `{72, 250}`; goal Honored with 2,300 needed and `UnitXPMax` 10,000 → 2 xp per point → +500 (250 × 0.0002 × 10,000); 100 needed → +200; goal reached (needed nil) → 0; the panel line reads "Stormwind: 2,300 to Honored"; the picker lists two fake factions and cycling one stores the standing.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: quests for the reputation you want"`.

---

### Task 3: Skip list, deaths and soloed elites

**Files:** Modify `Planner.lua` (filters, recorders), `PlannerRoute.lua` (deaths at hub level), `Guide.lua` (right-click menu; panel line), `Bars.lua` (skip list, two switches), `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces:
  - Skip list: per character `rec.skip = { [questID] = true }`; right-clicking a planned step with a quest opens a small menu with "Never suggest this quest" (uses the add-on's existing menu helper if there is one, else a minimal dropdown); `ns.PlannerSkip(questID, on)` adds/removes and replans at once. `ns.PlannerCandidates` drops skipped quests unless they are in the log. Guide tab: "Quests you skipped" lists them with a remove button each.
  - Deaths: on `PLAYER_DEAD` (unlocked only) record `{ level, map, x, y }` per character (at most 50, oldest dropped); `ns.PlannerHubTooHard(hub, ctx) -> deathLevel|nil` per the ruling; the route skips such hubs and the panel shows "Moved: you died twice here (back at level %d)" once per plan.
  - Soloed elites: `ns.PlannerRecordSoloElite(class, diff)`, `ns.PlannerSoloEliteOK(class, diff) -> boolean` per the ruling; `ns.PlannerCandidates` lets such elites through in Solo when `plannerSoloElites` is on (they still count in "Skipped" otherwise).
  - Settings `plannerDeaths`, `plannerSoloElites` with switches.
- [ ] **Step 1: Failing test** `try("13.3 choices: skip list, deaths, soloed elites", ...)`: skip 201 → not a candidate; 201 also in the log → still a candidate; unskip → back. The right-click menu entry calls `ns.PlannerSkip` (drive it through the step button's handler). Deaths: two `PLAYER_DEAD` at level 12 inside a hub → that hub is not planned at 12 or 13, planned again at 14; one death → planned; a death with no world position (stub `ns.PlannerWorldPos` nil) → not recorded; setting off → planned. Elites: hand in an elite quest of level 13 at level 12 while not grouped → recorded diff 1 for the class; an elite of diff 1 is now a Solo candidate, diff 2 is not; grouped at hand-in → not recorded; setting off → no elites in Solo.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: a skip list, hubs where you died, and elites your class has soloed"`.

---

### Task 4: Class, timed, escort and loot-started quests

**Files:** Modify `PlannerSource.lua` (record fields), `Planner.lua` (candidates), `PlannerRoute.lua` (hub loop order), `Guide.lua` (panel lines), `Bars.lua` (switch), `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces:
  - Class quests (`plannerClassQuests`): from `ns.PLANNER_CLASS_QUESTS` for the player's class. A class quest at or below the player's level and not done is a candidate regardless of the level window. `kind = "always"`: its hub is planned first. `kind = "fit"`: planned when its start lies within the hub radius of a hub the route already takes, or within 300 s of travel of the route, while the player is below `level + 1`; otherwise not. Not in the plan and available: the panel shows "Class quest ready: %s" and, with `parts > 1`, " (%d parts, about %d min)" from `ns.PlannerQuestTime` × parts.
  - Timed: a logged quest with `C_QuestLog.GetTimeAllowed(questID)` > 0 is laid out as its own run — accept (if not yet), do, hand in — before anything else in its hub.
  - Escort: `ns.PLANNER_ESCORTS[id]` → `rec.escort = true`; its `do` step is never merged with others and its text adds "Escort: start it when you are ready; it fails if the NPC dies".
  - Loot-started quests: Questie `startedBy[3]` (items) with `QueryItemSingle(item, "npcDrops")`; a quest whose starting item drops from an NPC with a spawn within the hub radius of a route spot becomes a candidate with `rec.fromItem = { id, name }` and that NPC's spawn as its start; its accept step text is "Keep the %s that drops here"; when `C_Item.GetItemCount(item) > 0` the text is "Use the %s to start it" and the start is the player's next step.
- [ ] **Step 1: Failing test** `try("13.3 choices: class, timed, escort and loot quests", ...)`: an "always" class quest two levels below → planned first even though out of the window; a "fit" one near the route → planned, far → not, and the panel shows "Class quest ready: …"; a 3-part chain shows "(3 parts, about …)". Timed: a logged quest with 900 s allowed → accept/do/turnin consecutive, first in its hub. Escort: step text carries the escort note. Loot: a quest started by item 5000 dropped by NPC 77 near a planned hub → its accept reads "Keep the Bloody Note that drops here"; with the item in bags → "Use the Bloody Note to start it"; the drop NPC far from the route → not planned.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: class quests at the right time, timed and escort quests, quests from loot"`.

---

### Task 5: At the hand-in, the quest log, and when you stop

**Files:** Create `FantasyGlassUI/PlannerAdvice.lua` (TOC after `PlannerPath.lua`); modify `Guide.lua` (panel lines), `Bars.lua` (three switches), `Core.lua`, `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces:
  - Reward pick (`plannerPickReward`): on `QUEST_COMPLETE` with `GetNumQuestChoices() > 1`, score each choice by `ns.UpgradeAmount(GetQuestItemLink("choice", i))`, else by sell price (`C_Item.GetItemInfo` 11th return × count); select the best with `QuestInfoItem_OnClick(QuestInfo_GetRewardButton(QuestInfoFrame.rewardsFrame, i))` (each pcall'd). Never calls `GetQuestReward`. Nothing selected when no choice can be judged. Works whenever the guide is unlocked and the setting is on.
  - Quest-log advice (`plannerLogAdvice`): free = `C_QuestLog.GetMaxNumQuestsCanAccept()` (25 when unreadable) minus quests in the log (headers excluded); when free ≤ 3, or the plan's accept steps exceed free, the panel lists up to 3 "Worth abandoning: %s (%s)" with the reason "gray", "never planned" or "off the route", in that order of preference. Only advice.
  - Inn (`plannerInn`): when the game menu opens (`GameMenuFrame` OnShow hook) or `/fgui guide stop`, after at least 3600 s of play this session (`GetTime` since login), while rested is not full, the nearest innkeeper (`places("innkeeper")`) within 120 s of travel → panel line and chat line "Log out at %s for rested experience (about %d min away)".
  - Settings `plannerPickReward`, `plannerLogAdvice`, `plannerInn` with switches.
- [ ] **Step 1: Failing test** `try("13.3 choices: hand-in, quest log, inn", ...)`: three choices where choice 2 is an upgrade → button 2 clicked, `GetQuestReward` never called; no upgrades, sell prices 10/50/20 → button 2; one choice → nothing; links nil → nothing; setting off → nothing. Log: 23 quests of 25 and one gray → "Worth abandoning: … (gray)"; 10 quests → no line. Inn: menu opened after 4000 s with an inn 60 s away → the line; after 1000 s → none; inn 300 s away → none.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: picks the best reward, tidies your quest log, finds you an inn"`.

---

### Task 6: When quests run dry

**Files:** Modify `PlannerAdvice.lua`, `PlannerSource.lua` (NPC level scan for grinding), `Guide.lua` (panel lines), `Bars.lua` (switch), `Locales.lua`; test `tests/smoke.py`.

**Interfaces:**
- Produces (`plannerDry`), used when `summary.empty`:
  - Dungeon: from `ns.PLANNER_DUNGEONS` where `minLevel ≤ level ≤ maxLevel` and the group setting allows (When grouped while in a party, or Everything): count Questie quests the player can take whose `zoneOrSort` is the dungeon's area id; line "Try %s: %d quests, start at %s" (the start hub's zone name).
  - Grinding: `source.grindSpots(level) -> { {map, x, y, count, name} }` — Questie NPCs with `minLevel..maxLevel` overlapping `level..level+2`, not friendly to the player, spawns grouped on a 200-yard grid on the player's continent, best by count; cached per level per session; `ns.PlannerYield()` per NPC outside pcall. Line "Or grind %s at %s (about %s xp an hour)" with experience per hour = 60 kills an hour (or the character's measured kills an hour if batch 1 records it) × `ns.PlannerKillXP(level, mobLevel)`.
  - The better of the two first (dungeon: its quests' total xp over 1 hour; grinding: its xp an hour); both when both apply.
- [ ] **Step 1: Failing test** `try("13.3 choices: when quests run dry", ...)`: an empty plan at level 18, Everything, a fake dungeon 17–24 with 4 fake Questie quests → "Try Deadmines: 4 quests, …"; Solo → no dungeon line; a fake NPC cluster of 30 level-19 spawns → a grind line with the name; nothing found → the old "No quests left worth the trip" line only; setting off → old line only.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass. Step 5: Commit** `"Planner: what to do when quests run dry"`.

---

### Task 7: Check everything

- [ ] **Step 1:** smoke.py → `syntax: all ... OK`, `errors: no errors` twice.
- [ ] **Step 2:** `luacheck . -q` 0 warnings; Forever, lock and secret audits clean.
- [ ] **Step 3:** `python3 -m pytest tests -q` → 6 passed.
- [ ] **Step 4:** `missing_tr.py` over the planner files, Guide.lua and Bars.lua → nothing new except internal value strings.
- [ ] **Step 5:** no "planner" in public docs.
- [ ] **Step 6:** `specs/plans/2026-11-25-quest-planner-choices-notes.md`: in-game checks (escort ids, class quest ids and kinds, dungeon table, reward selection on the real hand-in window, `GetXPExhaustion` behaviour, `C_QuestLog.GetTimeAllowed`, reputation reads), rulings and deferred minors from the ledger.
