# Folders and Joining (planner and gold in their own folders, merged on one branch) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This plan is built for parallel execution**: Tasks 1, 2 and 3 run first, one after the other, by the controller. Tasks 4–8 then run in four groups (A, B, C, D), each in its own git worktree at the same time. Task 9 merges them and checks everything. Read "Parallel build and merge" before starting.

**Goal:** One branch that holds both hidden features: the gold advisor merged into the quest planner without wrappers or duplicates; each feature in its own load-on-demand folder that a locked player never loads; a small always-on recording layer in the main add-on so nothing goes deaf while the folders are unloaded; the planner's own window, button, Tools-menu entry and `/fgui plan`; and Go, which pauses the levelling plan, puts the gold trip on the guide panel as steps, and resumes the plan afterwards.

**Architecture:**
- Task 1 merges `gold-advisor` into `quest-planner` and settles the known clashes while every file is still in the main add-on.
- Task 2 moves the files: `FantasyGlassUI_Planner/` and `FantasyGlassUI_Gold/` are new load-on-demand folders. The main add-on gets `Folders.lua`, which holds the loader, the stubs, the entry points that must stay, and the "file done" handshake. The test harness, the audits and the packaging are updated in the same task.
- Task 3 adds every seam the groups need.
- The groups then own disjoint files:
  - A puts the planner's recorders back into the main add-on (`PlannerRecorders.lua`).
  - B does the same for gold's recorders (`GoldRecorders.lua`).
  - C builds the planner window (`PlannerWindow.lua`, `Bars.lua`).
  - D builds the trip in `Guide.lua` and Go in `PlannerGo.lua`.
- The folders reach the main add-on only through `ns` (the shared table `_G.FantasyGlassUI`, as `FantasyGlassUI_Options` does) and through two documented seam lists: Guide.lua's, and a new one in Folders.lua.

**Tech Stack:** Lua 5.1 (WoW Forever, interface 16001). APIs used: `C_AddOns.LoadAddOn`, `EnableAddOn`, `IsAddOnLoaded`, `GetAddOnInfo`, `IsLoggedIn`, `InCombatLockdown`, and the recorders' events (listed under Game APIs). Tests are in `tests/smoke.py` (lupa harness) and `tests/test_addon.py` (pytest). The site is not touched.

**Spec:**
- `specs/2026-11-21-quest-planner-design.md`: "Settings (Guide tab)", including "Later: own button and settings window", "Final step after batch 5" and "Decided with the player"; the anti-goals.
- `specs/2026-11-25-gold-advisor-design.md`: "Where it shows", "Packaging and release", answers 2, 4 and 5.
- Sources:
  - the gold plan's "Later: the folder move" (`specs/plans/2026-11-25-gold-advisor.md`)
  - the gold group reports (`.superpowers/sdd/2026-11-25-gold-advisor/task-*-report.md`; task-6 for the node fold)
  - the missed-items audit (A1, A2, A4, A5, A13, A15, B12, B14)
  - roadmap step 6
  - batch 6's plan (`2026-11-25-quest-planner-leftovers.md`: `ns.GuideRegisterLock`, the seam list, `PlannerKills.lua`)
  - the loader model, `ns:LoadOptions` (`FantasyGlassUI/Core.lua:14-47`)

**Base:** `quest-planner` in `/home/claude/fantasyglassui-planner`, after batch 6 (Task 13 and its notes), the polish check and its fix wave, with `main` merged in. `gold-advisor` must be after its Task 9: the notes have been committed and the final fix wave is done. Task 1 Step 1 checks all of this and stops if any part is missing.

## Global Constraints

**Carried from earlier plans**
- Everything in the planner batches 1–6 and gold batches 1–5 Global Constraints still binds:
  - the Forever audit
  - `luacheck . -q` → 0 warnings
  - smoke.py `errors: no errors` twice
  - never plan or collect in combat
  - slices of at most 4 ms (`ns.PLANNER_BUDGET_MS`, `ns.GOLD_BUDGET_MS`)
  - `ns.PlannerYield()` / `ns.GoldYield()` only in plain loops (never inside `pcall`/`Try`, a sort comparator or a gsub callback)
  - every value through `ns:IsSecret` before it is compared, stored or used in arithmetic
  - all phrases in 9 languages
  - Questie read-only, through pcall
- **Commits** are made by DustyMouse (`git -c user.name=DustyMouse -c user.email=fantasyglassui@users.noreply.github.com commit`) with **no attribution lines**. **Nobody pushes.**
- **The unlock phrase is never written anywhere.** Tests unlock with `ns.GuideUnlocked = function() return true end` and restore it afterwards.
- **Nothing public.** None of these change, and no line in them mentions the planner, the advisor, the new folders or `/fgui plan`: `/fgui help`, the `/fgui guide` usage line, README, wiki, `docs/`, `site-src/`, any CHANGELOG, RELEASE.md, `FeatureList`, `Categories`, the setup and `ns.TOOL_MENU`.
- **No `ReloadUI`, no posting/buying/crafting, no `SendChatMessage`.** This grep stays empty: `grep -rnE "ReloadUI|SendChatMessage|PostItem|PostCommodity|PlaceBid|StartCommoditiesPurchase|ConfirmCommoditiesPurchase|BuyMerchantItem|CraftRecipe" FantasyGlassUI_Planner FantasyGlassUI_Gold FantasyGlassUI/PlannerRecorders.lua FantasyGlassUI/GoldRecorders.lua FantasyGlassUI/Folders.lua`.

**Never in combat**
- Nothing loads a folder while `InCombatLockdown()` is true.
- A load that the player clicked prints "Not during a fight." and does nothing.
- An automatic load (login, a friend's ask, the catch-up page) waits for `ns:AfterFight(label, fn)`.

**Hidden**
- `ns:LoadFolder` returns false without calling `LoadAddOn` while `ns:GuideUnlocked()` is not true. A locked player therefore never loads either folder, sees no new text anywhere, and their Tools menu, launcher tooltip, `/fgui` replies and guide panel are exactly what they are today.
- Recorders keep batch 1–6's rule: they record nothing while locked.

**Saved data**
- Every recorder that moves keeps its saved-data shape and keys exactly.
- The only change is the node fold (Task 1). `ns.root.goldNodesSeen` is merged into `ns.root.plannerNodesSeen` and then set to nil.
- New, and only while a trip is on: the fields `trip` and `resume` in a character's `ns.root.guideState[key]` (Task 7).
- No `ns.db` default changes.

**Game APIs**
- Every game API comes from `tests/forever_api.json.gz`. Check names with the gold plan's one-liner:

  ```
  python3 -c "import gzip,json,sys;d=json.load(gzip.open('tests/forever_api.json.gz'));S=set(d['globals'])|set(d['fields'])|set(d['events']);[print(n,n in S) for n in sys.argv[1:]]" NAMES…
  ```

- Checked present, and not a restricted event:
  - add-ons: `C_AddOns.LoadAddOn`, `C_AddOns.EnableAddOn`, `C_AddOns.IsAddOnLoaded`, `C_AddOns.GetAddOnInfo`, `C_AddOns.IsAddOnLoadOnDemand`, `IsLoggedIn`, `ADDON_LOADED`
  - input and timing: `InCombatLockdown`, `IsControlKeyDown`, `IsShiftKeyDown`, `GetTime`, `debugprofilestop`, `C_Timer.After`
  - addon messages: `C_ChatInfo.RegisterAddonMessagePrefix`, `CHAT_MSG_ADDON`
  - login and fights: `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, `PLAYER_LOGOUT`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`
  - quests: `QUEST_ACCEPTED`, `QUEST_TURNED_IN`, `QUEST_REMOVED`, `QUEST_COMPLETE`, `C_QuestLog.GetTimeAllowed`
  - level and experience: `PLAYER_LEVEL_UP`, `PLAYER_XP_UPDATE`, `CHAT_MSG_COMBAT_XP_GAIN`, `UPDATE_EXHAUSTION`, `UnitXP`, `UnitXPMax`, `GetXPExhaustion`
  - away and resting: `PLAYER_FLAGS_CHANGED`, `PLAYER_UPDATE_RESTING`, `UnitIsAFK`, `IsResting`
  - deaths and mounts: `PLAYER_DEAD`, `PLAYER_MOUNT_DISPLAY_CHANGED`, `IsMounted`
  - flights and the hearthstone: `TAXIMAP_OPENED`, `C_TaxiMap.GetAllTaxiNodes`, `TaxiNodeGetType`, `UnitOnTaxi`, `PLAYER_CONTROL_LOST`, `PLAYER_CONTROL_GAINED`, `HEARTHSTONE_BOUND`
  - windows: `MAIL_SHOW`, `MERCHANT_SHOW`, `MERCHANT_UPDATE`, `TRAINER_SHOW`, `TRAINER_CLOSED`, `MERCHANT_CLOSED`, `MAIL_CLOSED`
  - casting, loot and professions: `UNIT_SPELLCAST_SENT`, `UNIT_SPELLCAST_SUCCEEDED`, `LOOT_OPENED`, `LOOT_CLOSED`, `TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`
  - the auction house: `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`
  - maps and groups: `C_Map.GetWorldPosFromMapPos`, `CreateVector2D`, `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`, `C_Map.GetMapInfo`, `IsInGroup`, `GetNumGroupMembers`, `UISpecialFrames`
- Every other name a recorder uses already passes the audit, because it moves without change.

**Phrases**
- Groups do not run `add_tr.py`. Each group writes its phrases in add_tr's format to `specs/plans/phrases/folders-<a|b|c|d>.json`, using "du" in German. Task 9 applies them.
- Tasks 1–3 run add_tr themselves.

**Per-task checks** (the last step before each commit)
- `luacheck . -q` → 0 warnings (run `python3 site-src/tools/regen_rc.py` after adding globals)
- `cd FantasyGlassUI && python3 ../tests/smoke.py` → `syntax: all … OK` and `errors: no errors` twice
- `python3 tests/forever_audit.py` → exit 0
- `python3 tests/secretaudit.py` → `0 lines compared a hidden value`
- From Task 2 on: `python3 -m pytest tests/test_addon.py -q -k "folder or seams or versions"` → pass
- The full pytest and `python3 tests/lockaudit.py` (`(no protected calls in combat)`) run in Tasks 1, 2, 3 and 9.

### Rulings (the specs leave these open, or this plan narrows them)

**1. What stays in the main add-on**
- `PlannerTravel.lua` stays whole. Most of it is recording: known flights, flight and crossing times, docks and take-offs, and `ns.PlannerWorldPos`. Its travel model (`ns.PlannerTravel`) is pure and short, has shipped on `main` since 12.x, and is what Go and the node recorder need.
- Batch 6's `PlannerKills.lua` stays whole, because it is a recorder.
- Everything else named `Planner*.lua` moves to `FantasyGlassUI_Planner/`, and all five `Gold*.lua` move to `FantasyGlassUI_Gold/`.
- The recorders those files contain come back to the main add-on in Tasks 4 and 5, moved verbatim (see ruling 5). Their files are `FantasyGlassUI/PlannerRecorders.lua` and `FantasyGlassUI/GoldRecorders.lua`.
- The loader, the stubs and the entry points go in `FantasyGlassUI/Folders.lua`. That makes three small files, not one: each has one owner and one job.

**2. The folders' TOCs (exact)**
- Both folders have these lines:
  - `## Interface: 16001`
  - `## Author: DustyMouse`
  - `## Version:` the same value as the main TOC
  - `## LoadOnDemand: 1`
  - `## RequiredDeps: FantasyGlassUI`
  - `## Category: User Interface`
  - `## X-License: All Rights Reserved`
  - `## X-Curse-Project-ID: 1798626`
  - `## IconTexture: Interface\AddOns\FantasyGlassUI\Media\icon.tga`
- The planner's folder: `## OptionalDeps: Questie`.
- The gold folder: `## OptionalDeps: Questie, FantasyGlassUI_Planner`.
- On Forever, OptionalDeps only orders loading. So Go loads the planner itself (ruling 9), and the gold folder never needs it at load.

**3. What the add-on list shows (decided)**
- Until 13.0 the titles and notes name nothing:
  - `## Title: |cff33ccffFantasy Glass|r UI - extras 1` (planner) and `… - extras 2` (gold)
  - `## Notes: Part of Fantasy Glass UI. The game loads it only when it is needed, so it uses no memory until then. Leave it enabled.`
- A player, locked or not, sees two more Fantasy Glass UI lines in the game's add-on list, marked load-on-demand and never loaded while locked. Hovering one shows the neutral notes and "FantasyGlassUI" as its dependency.
- The folder names (`FantasyGlassUI_Planner`, `FantasyGlassUI_Gold`, as the specs fix them) are visible only on disk.
- Until 13.0 no public package holds these folders, because hidden work reaches `main` only at 13.0 (the roadmap's ruling). Only the player and trusted testers have them.
- The 13.0 release plan renames the titles to "- planner" / "- gold" and gives them real notes. A pytest keeps the words "plan", "gold", "guide" and "advis" out of both TOCs' Title and Notes until then.

**4. When a folder loads** (`ns:LoadFolder(key)`; key is `"planner"` or `"gold"`)
- Never while locked, before `IsLoggedIn()`, or in combat (see Global Constraints).
- The planner loads:
  - on its button, its Tools-menu entry or `/fgui plan`
  - on any planner stub: `ns:PlannerStart` (the panel's and the list's "Plan my route", `/fgui guide plan`), `ns:PlannerOpen`, `ns:PlannerCatchUp`
  - on a planner command word (`duo`, `share`, `keys`)
  - on Go
  - on a friend's duo ask (Task 4)
  - on the catch-up page being due (Task 4)
  - **at PLAYER_LOGIN when you are following the planned guide or a trip** (`GuideState().name` is `ns.GUIDE_PLANNED` or `ns.GUIDE_TRIP`). This keeps the invariant "following the plan ⇒ the planner is loaded", which every `if ns.Planner… then` in Guide.lua relies on. The login load runs behind the loading screen.
- Gold loads on:
  - `ns:GoldOpen`
  - `AUCTION_HOUSE_SHOW` while unlocked
  - `/fgui guide gold`
  - the launcher's Ctrl-click
  - its Tools-menu entry
- This stretches the planner spec, which says "only when the planner is first used". The login and duo-ask loads are uses that were already under way.

**5. Late login work**
- A folder loaded after login never sees `PLAYER_LOGIN`. So no file in either folder registers `PLAYER_LOGIN`; a pytest enforces it.
- Instead, work that ran at login is registered with `ns.FolderLate(key, name, fn)`. The loader runs it once through pcall right after a successful load.
- Today that work is PlannerPace's `Sync`, PlannerRecords' `PlannerKeyFrames`, and anything Task 2's grep finds.

**6. Isolation ("a failure inside never breaks the UI")**
- Each folder file ends with `ns.FolderFileDone("<key>", "<File>.lua")`. After `LoadAddOn` returns, the folder is ready only when every file in `ns.FOLDERS[key].files` reported done.
- Otherwise the folder is broken:
  - `ns.folderBroken[key]` lists the files that did not finish
  - one line goes into `ns.errors`: `"Folder " .. key .. ": " .. files .. " did not load"`
  - every stub prints once, at most every 10 s, "The planner could not start: /fgui check lists why." (or "Ways to make gold could not start: …")
  - the guide panel and written guides work as before
- A folder that is missing or switched off is handled as `ns:LoadOptions` handles one:
  - when `LoadAddOn` answers DISABLED, the loader calls `EnableAddOn` and tries again
  - otherwise it prints "The planner could not be opened (<reason>). It is in a folder, FantasyGlassUI_Planner, which must sit beside FantasyGlassUI in Interface/AddOns and be enabled.", once every 10 s
  - that message reaches unlocked players only

**7. Gold's guide-panel button goes**
- Gold's own plan put a "Gold" button at the panel's BOTTOMRIGHT (−76, 6), right on top of the planner's "..." button. It is removed.
- Gold opens from:
  - the Planner window ("Ways to make gold")
  - the Tools menu
  - Ctrl-click on the launcher
  - `/fgui guide gold`
  - a "..." panel action, "Ways to make gold"
  - the riding line
- The gold spec asks only for "the minimap launcher and the Planner window".
- **The panel's bottom row**, from the left: `<` (8–30), `>` (34–56), batch 6's "Plan again" (60–132, shown while following the plan). From the right: "Guides" (208–272), "..." (182–204), and the new **"Planner"** button (44 wide, at BOTTOMRIGHT −98, 6, so 134–178), shown while unlocked.
- Its translations are fixed short so that they fit: de "Planer", fr "Plan", es "Plan", ru "План", pt "Plano", it "Piano", ko "계획", zh "规划".

**8. Folding the two node memories into one (gold answer 2; the audit's A4)**
- **One recorder.** The one `UNIT_SPELLCAST_SENT` handler is the planner's. It records herb and ore nodes into `plannerNodesSeen`, only while `plannerGather ~= false`, as today. Then, for every gathering skill including skinning, it calls `ns.GoldGatherSent(name, skill, spellID)` when that exists.
- **Gold's side.** Gold keeps its own `UNIT_SPELLCAST_SUCCEEDED` / `LOOT_OPENED` handler, which records what a node gave (`goldNodeItems`, `goldGather`). It no longer registers `UNIT_SPELLCAST_SENT` and no longer writes `goldNodesSeen`.
- **One skill function**, `ns.PlannerGatherSkill`, with gold's extra `IsSecret(info)` check added. `ns.GoldGatherSkill` and gold's spell tables are deleted, and every caller uses `ns.PlannerGatherSkill`.
- **The one-time migration**, `ns.GoldFoldNodes()`, is a `GoldJob` keyed `"nodeFold"`. It is queued at the first `PLAYER_ENTERING_WORLD` while unlocked when `ns.root.goldNodesSeen` is a table:
  - It takes the map keys first, then walks each map's entries with `ns.GoldYield()` per entry.
  - An entry equal in name, skill, x and y to one already in `plannerNodesSeen[map]` is skipped.
  - Every other entry goes through `ns.PlannerRecordNode(map, x, y, name, skill)`, which applies the 10-yard rule and the 300 cap.
  - `goldNodesSeen` is set to nil only after the last map.
  - An interrupted fold runs again next session. It is idempotent, because folded entries are skipped as equal.
- **Gold's reader** (`Stores()`) stays as it is. It reads whichever memories exist.

**9. Go (gold answer 4)**
- **Loading the travel.** Go loads the planner (`ns:LoadPlanner()`) before it looks for `ns.GoldTravel`. `PlannerGo.lua` (planner folder) defines `ns.GoldTravel`.
- **Planning the trip.** The trip is planned as a `PlannerJob` keyed `"goldTrip"`:
  - It uses `ns.PlannerContext()` and `ns.PlannerTripState(ctx)` (Task 3).
  - It calls `ns.PlannerTrip(state, dest, steps, false)` to the idea's first placed step. It adds a trip again before any later idea step that is on a different map from the one before it.
  - Each idea step becomes a guide step: `goto` (text, map, x, y) when it has a place, `note` otherwise.
  - It learns flights on the way when `plannerLearnFlights ~= false`, as a plan does.
- **No way there.** When the destination cannot be reached, it says "No way there was found: here are the steps." and shows `ns.GoldStepsList(idea)`. The levelling plan is left untouched.
- **Pause and resume** (Guide.lua):
  - The trip is followed under the name `ns.GUIDE_TRIP = "\1trip"`. The state you were in (planned, written or none) is kept in `resume`, one level deep: a trip started during a trip replaces the trip and keeps the first `resume`.
  - The trip ends and `resume` comes back when its last step is done, on the panel action "Stop this trip", or on `/fgui guide stop` / `off`. A second `stop` stops the guide as today.
  - Following another guide during a trip drops both the trip and `resume`.
  - On resuming the planned guide: "Back to your levelling plan." and `ns:PlannerReplan("trip over")`.
  - A plan arriving during a trip (`ns:GuideSetPlan`, or a queued replan finishing) goes into `resume`, never over the trip. The planner's `Following()` is false during a trip, so it starts no replans of its own.
- **Go during a duo:**
  - The duo ends first: `ns:PlannerDuoEnd("guide", true)` says "You follow another guide now: no longer planning with %s." and sends END.
  - You plan alone after the trip. Starting the duo again is your click.
  - This rules the audit's "end it or pause it" as end. Pausing would need a new message kind.
- **Go with a time limit:**
  - The trip runs whatever the limit.
  - When `ns.PlannerTimeLeft()` is a number, the first step is a note "This trip takes about %s; you have %s left." (`ns.GoldTimeText`).
  - The resumed plan is replanned with the time then left, so batch 4's limit rules apply.
- **Go with a zone goal:** the goal is per character and is unchanged, so the resumed plan keeps it.

**10. The planner window**
- Frame `FantasyGlassUIPlanner`, 600×640, in the gold window's frame rules:
  - `ns:SetLook(frame, "settings")`, plus `ns.StarcutWindow(frame)` when it exists
  - strata `DIALOG`
  - `ns:KeepPlace(frame, "Planner")`
  - in `UISpecialFrames`, draggable
  - built at its first open, never at login
- Title "Route planner" (16, TOPLEFT 18, −18) and "X" (28×28).
- **The summary** (y −56 to −176) is `ns.PlannerWindowSummary() -> { strings }`, at most 5 lines:
  - **Following the plan:** the first 4 lines of `ns.PlannerPreviewLines(plan, st.summary)`, then "Step %d of %d: %s" with `ns.GuideStepBase`.
  - **On a trip:** "On a trip: %s, step %d of %d", then "Your levelling plan waits."
  - **Otherwise:** "You are not following a plan."
  - Then the riding line "Riding: %s to go" when `ns.PlannerRiding(level).short > 0`.
- **The button row** (y −186):
  - "Plan my route", or "Plan again" while following → `ns:PlannerStart()` / `ns:PlannerReplan("again")`
  - "Stop" while following or on a trip → `ns:GuideStop()`
  - "Ways to make gold" → `ns:GoldOpen()`
  - "Save for riding", shown with the riding line → `ns:GoldOpen({ goalName = "mount" })`
- **The switches** are below, in `ns:ScrollArea` from y −222, under these headings in this order:
  1. "Group quests": the group cycle, `plannerSoloElites`, `plannerClassQuests`
  2. "Stops on the way": `plannerLearnFlights`, `plannerTrainer`, `plannerHold`, `plannerVendor`, `plannerSupplies`, `plannerProfession`, `plannerMount`, `plannerMail`
  3. "Exploring and gathering": `plannerExplore`, `plannerGather`
  4. "Rewards, the log and the inn": `plannerPickReward`, `plannerRewards`, `plannerLogAdvice`, `plannerInn`, `plannerRested`, `plannerDry`, and the buttons "Reputation I want" and "Quests you skipped"
  5. "Time, style and sliders": batch 4's pace section, the zone goal button, `plannerDeaths`
  6. "Map": batch 4's map section
  7. "Records": `plannerRace`, `plannerLeftOff`, `plannerWhy`
  8. "Reading aloud": `plannerSpeak` and its hint
  9. "With others": batch 5's three sections
- The ninth group is added: batch 5's switches came after the player's list.
- Every control keeps its label, its `ns.db` key, its callback and its field name in `T`: `ns.plannerWindow.T.flightsBox` is what `ns.guidePage.flightsBox` was.
- **The Guide tab** keeps:
  - "Quest guides" and "A sound when a step is done" (`guideSound` belongs to the guide, written guides included)
  - Your guides, Write, Edit the route, Record
  - a "Plan my route" heading with two buttons: "Plan my route" and "Planner settings" (`ns.HideConfig()`, then `ns:PlannerOpen()`)

**11. The gold goal and the riding line agree (A13)**
- `ns.GOLD_GOALS.mount` (already 120g, or 100g for Paladins and Warlocks) must equal `PLANNER_RIDING_COPPER + PLANNER_MOUNT_COPPER`, and `PLANNER_RIDING_COPPER` for those two classes. A smoke assertion pins it.
- `ns:GoldOpen({ goalName = "mount" })` sets that goal. With it set, gold's "remaining" equals the planner's `short`.

**12. `/fgui plan` is hidden**
- It is not in `ns.toolCommands`, so `ns.ClosestCommand` and help never see it.
- Core.lua's last `else` first asks `ns.HiddenCommand(msg, raw)`. Folders.lua answers true only while unlocked, for `plan` and `plan <anything>`, and opens the window.
- While locked, `/fgui plan` gives the same reply as today.

**13. Trainer recording while the planner is unloaded**
- The class-trainer test needs Questie's trainer lists, which live in the folder (`ns.PlannerPlaces`).
- While unloaded, it takes batch 2's existing fallback: any trainer that is not a profession trainer counts as yours. Riding at the riding trainer is then learned at the next mount seen.

**14. The duo ask while unloaded (A1)**
- `PlannerRecorders.lua` registers the prefix at login and on unlock (`ns.GuideRegisterLock("duoPrefix", …)`) and listens to `CHAT_MSG_ADDON`.
- It acts only on a message of the form `D1:ASK:<hex session>:<digits>`, and only when all of these hold:
  - the planner folder is not ready
  - you are unlocked and `plannerDuoAsk ~= false`
  - the prefix is ours and the channel is `"WHISPER"`
  - every value is readable
- Then it loads the planner and hands the same arguments to `ns.PlannerDuoEvent("CHAT_MSG_ADDON", …)` exactly once.
- In a fight it keeps the latest ask (one at most) and hands it over through `ns:AfterFight("duoAsk", …)` if it is under 60 s old.
- It sends nothing itself. Once the planner is loaded it forwards nothing.

---

## Review Focus

- **A locked player:** opening the auction house, flying, an incoming `D1:ASK`, Shift-click Tools, Ctrl-click on the launcher, `/fgui plan`, `/fgui guide gold`, a quest hand-in. Expected: `LoadAddOn` is never called for either folder, the Tools menu and launcher tooltip have the same lines as before, `/fgui plan` replies as it does today, and nothing is sent. → Task 2 and 3 tests.
- **A friend's ask while the planner is unloaded, in a fight, or after 70 s in a fight.** Expected: the ask page shows after the fight only when under 60 s; nothing shows and nothing is sent when locked or `plannerDuoAsk == false`; one hand-over, never two. → Task 4 test.
- **Login while following the plan, with the planner folder disabled, missing, or with one file that errors.** Expected: one message (unlocked only), the panel and written guides still work, no Lua error, `ns.folderBroken` names the file. → Task 2 test.
- **The node fold:** interrupted half-way, run twice, a gold node equal to a planner node, a map already at 300. Expected: no duplicates, the cap kept, `goldNodesSeen` cleared only at the end, routes still built while the fold is pending. → Task 1 test.
- **Go while a replan is queued or running, a trip whose destination can't be reached, or a /reload in the middle of a trip.** Expected: the levelling plan is never overwritten (a plan landing during the trip goes into `resume`); an unreachable trip shows the list and leaves the plan; after a reload the trip continues and still resumes afterwards. → Task 7 and 8 tests.

---

## File Structure

- **Task 1** (merge; all files still in the main add-on):
  - conflicts in `FantasyGlassUI_Locales/Locales.lua`, `tests/smoke.py`, `FantasyGlassUI/FantasyGlassUI.toc`, `.luacheckrc`, and any other file the merge reports
  - `FantasyGlassUI/Gold.lua` (wrappers replaced by registries)
  - `FantasyGlassUI/GoldGather.lua` (no SENT, no own node memory, `ns.GoldGatherSent`, `ns.GoldFoldNodes`)
  - `FantasyGlassUI/PlannerPath.lua` (the one SENT handler, `ns.PlannerGatherSkill`)
  - `tests/test_addon.py` (the seam test widened)
- **Task 2** (the move):
  - `git mv` `FantasyGlassUI/Planner{Source,,Route,Stops,Path,Advice,Map,Pages,Pace,Records,Group,Duo,Code}.lua` → `FantasyGlassUI_Planner/`
  - `git mv` `FantasyGlassUI/Gold{,Sell,Farm,Gather,Craft}.lua` → `FantasyGlassUI_Gold/`
  - create `FantasyGlassUI_Planner/FantasyGlassUI_Planner.toc`, `FantasyGlassUI_Gold/FantasyGlassUI_Gold.toc` and `FantasyGlassUI/Folders.lua`
  - modify:
    - `FantasyGlassUI/FantasyGlassUI.toc`
    - `FantasyGlassUI/Guide.lua` (`ns.GUIDE_PLANNED` moves here)
    - `FantasyGlassUI/PlannerRoute.lua` (now in the folder: the constant goes)
    - `tests/smoke.py` (the harness)
    - `tests/secretaudit.py`, `tests/lockaudit.py`, `tests/forever_audit.py`, `tests/test_addon.py`
    - `.pkgmeta`, `.github/workflows/release.yml`, `/home/claude/build.sh` (outside the repo)
    - `.luacheckrc` (regenerated)
- **Task 3** (seams):
  - `FantasyGlassUI/Guide.lua`, `Core.lua`, `Companion.lua`, `Folders.lua`
  - `FantasyGlassUI_Planner/PlannerRoute.lua` (two exports), `FantasyGlassUI_Gold/Gold.lua` (`GoldOpen` options, `GoldGo` loads the planner, `GoldStepsList`)
  - new empty files: `FantasyGlassUI/PlannerRecorders.lua`, `FantasyGlassUI/GoldRecorders.lua`, `FantasyGlassUI_Planner/PlannerWindow.lua`, `FantasyGlassUI_Planner/PlannerGo.lua`, with TOC lines and `ns.FOLDERS` lists
  - fences in `tests/smoke.py`
- **Group A (Task 4):**
  - `FantasyGlassUI/PlannerRecorders.lua`
  - in `FantasyGlassUI_Planner/`: `Planner.lua`, `PlannerAdvice.lua`, `PlannerPath.lua`, `PlannerSource.lua`, `PlannerRoute.lua` (the bind recorder only), `PlannerRecords.lua`, `PlannerPace.lua`, `PlannerDuo.lua`, `PlannerStops.lua`
- **Group B (Task 5):**
  - `FantasyGlassUI/GoldRecorders.lua`
  - in `FantasyGlassUI_Gold/`: `Gold.lua` (the job runner only), `GoldSell.lua`, `GoldFarm.lua`, `GoldGather.lua`, `GoldCraft.lua`
- **Group C (Task 6):**
  - `FantasyGlassUI_Planner/PlannerWindow.lua`, `FantasyGlassUI_Options/Bars.lua`
  - in `tests/smoke.py`, the existing lines that read `ns.guidePage.<field>` for a moved control. This is the only edit allowed outside a region.
- **Group D (Tasks 7, 8):** `FantasyGlassUI/Guide.lua` and `FantasyGlassUI_Planner/PlannerGo.lua`.
- **Shared, by region.** In `tests/smoke.py`, Task 3 writes these fences:
  1. **Unloaded regions**, immediately before Task 2's fixture `try("folders: load for the tests", …)`:
     - `-- folders tests unloaded A (planner recorders): begin` / `end`
     - the same for `B (gold recorders)`
  2. **Group regions**, after the gold `together` region:
     - `-- folders tests A (planner recorders): begin` / `end`
     - the same for `B (gold recorders)`, `C (window)` and `D (go)`
     - `-- folders tests together: begin` / `end`

  `.luacheckrc` is regenerated only.

## Parallel build and merge

1. **The seams.** The controller runs Task 1, then Task 2, then Task 3 on `quest-planner`, one fix round each after a review. Task 3's commit is `SEAMS`.
2. **The groups.** Four worktrees are made from `SEAMS`: `git worktree add /home/claude/fgui-folders-a -b folders-a SEAMS`, and the same for b, c and d. Each gets one implementer:
   - Group A: Task 4
   - Group B: Task 5
   - Group C: Task 6
   - Group D: Tasks 7 then 8
3. **Review.** One reviewer per group reviews `git diff SEAMS..folders-<x>`. The implementer then makes one combined fix commit, `"Folders: <x> review fixes"`.
4. **Rules for every group:**
   - Touch only your files and your smoke regions (C also has its listed exception).
   - Never edit `Folders.lua`, the TOCs or another group's file. A missing seam is reported to the controller.
   - Use another group's function only through a guarded call, and stub it in your test.
   - Every test restores every global and `ns` field it changes, and removes every hook and registration it adds.
   - Tests in an unloaded region must not call a stub or `ns:LoadFolder`.
5. **Task 9** merges `--no-ff` in the order A, B, C, D.
   - A `.luacheckrc` conflict is fixed by regenerating it.
   - Any other conflict is kept in region order and noted.
   - Then the worktrees are removed and the branches deleted.

---

### Task 1: Merge gold-advisor into quest-planner, and settle the clashes (controller)

**Files:** see File Structure. Test: `tests/smoke.py` (a new `try` right after the gold `together` region), `tests/test_addon.py`.

**Interfaces:**
- Produces:
  - `ns.GoldGatherSent(name, skill, spellID)` (GoldGather.lua): the pending gathering for gold's SUCCEEDED/LOOT_OPENED recorder
  - `ns.GoldFoldNodes() -> boolean` (queued or not)
  - `ns.PlannerGatherSkill(spellID) -> 182|186|393|nil`, the only skill function
  - gold registered through Guide.lua's registries:
    - `GuideRegisterCommand("gold", …)`
    - `GuideRegisterAction("panel", "gold", "Ways to make gold", …, shown = unlocked)`
    - `GuideRegisterLock("gold", fn(unlocked))`, which hides the window and the auction-house panel on lock
- Removed: `ns.GoldGatherSkill`, gold's spell tables, gold's `UNIT_SPELLCAST_SENT` registration, the `ns.GuideShowPanel` / `ns.GuideCommand` wrappers, `p.suiGoldButton`.

- [ ] **Step 1: Check the base.** Stop and report if any of these fail:
  - `git -C /home/claude/fantasyglassui-planner status --short` is empty, and HEAD's log shows batch 6's notes commit and the polish fix wave
  - `git merge-base --is-ancestor main quest-planner` passes
  - `git log -1 gold-advisor` is after its notes commit, and `/home/claude/fantasyglassui-gold2` is clean
  - `grep -n "function ns.GuideRegisterLock" FantasyGlassUI/Guide.lua` finds the function, and `ls FantasyGlassUI/PlannerKills.lua` finds the file

  Write `BASE=$(git rev-parse HEAD)` into the notes.
- [ ] **Step 2: Merge.** `git merge --no-ff gold-advisor`. Resolve:
  - **`.luacheckrc`:** regenerate it with `regen_rc.py`.
  - **`FantasyGlassUI.toc`:** keep quest-planner's order, and put `Gold.lua … GoldCraft.lua` right after `SellHints.lua`, as gold had them.
  - **`tests/smoke.py`:** keep both. The planner's batch fences and tests come first. Then gold's six fence pairs and tests, in gold's order. All of it sits before `try("Delayed calls"`, and each fence line appears exactly once.
  - **`Locales.lua`:** take quest-planner's side (`git checkout --ours`). Then write a throwaway script in the scratchpad (not committed):
    - it reads `git show gold-advisor:FantasyGlassUI_Locales/Locales.lua`
    - for every key in gold's eight tables that ours lacks, it writes one add_tr entry
    - keys on both sides with different values keep ours and are listed in the notes

    Run `add_tr.py` on that file.
  - **Anything else:** keep both sides, and note it.
- [ ] **Step 3: Write the failing test** `try("folders 0: one branch, one node memory", …)`. Restore everything afterwards. Cases:
  - **The panel.** With the guide unlocked and the plan followed:
    - the panel has no `suiGoldButton`
    - `ns.GuidePanelEntries(step)` holds an entry labelled "Ways to make gold", and clicking it calls a stubbed `ns.GoldOpen` once
    - `ns:GuideCommand("gold")` calls it too
    - locked: no entry, and `ns:GuideCommand("gold")` prints "Quest guides are coming soon."
  - **One SENT recorder.** `UNIT_SPELLCAST_SENT("player", "Peacebloom", nil, 2366)` at map 1429 (50, 50) with a world position:
    - exactly one new entry in `plannerNodesSeen[1429]`
    - `goldNodesSeen` stays nil
    - `ns.GoldGatherSent` was called with ("Peacebloom", 182, 2366)
  - **Gold's loot without nodes.** With `plannerGather = false`: no node is recorded, but SUCCEEDED then `LOOT_OPENED` with 2× item 2447 still gives `goldNodeItems.Peacebloom.items[2447] == 2`.
  - **Skinning.** Spell 8613 records no node and calls `GoldGatherSent` with skill 393.
  - **One skill function.** `ns.PlannerGatherSkill(2575) == 186`, `ns.GoldGatherSkill == nil`, and a secret `C_Spell.GetSpellInfo` result gives nil.
  - **The fold.** `goldNodesSeen = { [1429] = { A, B, C } }`, where A equals a planner node and C is within 5 yd of B:
    - after the job, `plannerNodesSeen[1429]` gained exactly B
    - `goldNodesSeen == nil`
    - running it again does nothing
    - a fold stopped after the first entry (stub `ns.GoldYield` to raise once; the job errors) leaves `goldNodesSeen` intact, and the next run finishes with no duplicate
    - with `plannerNodesSeen[1429]` already at 300, nothing is added and the store is still cleared
    - while `goldNodesSeen` is pending, `ns.GoldGatherIdeas` still sees both
  - **Locked.** The fold job is not queued at `PLAYER_ENTERING_WORLD`.
- [ ] **Step 4:** Widen batch 6's `tests/test_addon.py::test_guide_seams_listed`:
  - it scans `FantasyGlassUI/Gold*.lua` as well as `Planner*.lua`
  - a new assertion: no file other than Guide.lua assigns `ns.Guide\w+` or defines `function ns[.:]Guide\w+`

  Run both new tests and confirm they fail.
- [ ] **Step 5: Implement** per rulings 7 and 8.
- [ ] **Step 6:** Run the per-task checks, the full `pytest`, `lockaudit`, and the guards:
  - `grep -rn '"UNIT_SPELLCAST_SENT"' FantasyGlassUI --include=*.lua` → exactly one registration
  - `grep -rn "GoldGatherSkill\|suiGoldButton" FantasyGlassUI tests` → nothing
- [ ] **Step 7: Commit.** The merge commit is `"Merge gold-advisor: the gold advisor joins the quest planner"`. The fixes go in a second commit, `"Gold and planner: one node memory, one gathering recorder, the guide's registries instead of wrappers"`.

---

### Task 2: The two folders: loader, stubs, the move, the harness, the audits and packaging (controller)

**Files:** see File Structure.

**Interfaces:**
- Produces, in `FantasyGlassUI/Folders.lua` (TOC: right after `Guide.lua` and `GuideEditor.lua`):
  - `ns.FOLDERS = { planner = { addon = "FantasyGlassUI_Planner", files = {…TOC order…} }, gold = { addon = "FantasyGlassUI_Gold", files = {…} } }`
  - `ns.folderReady = {}`, `ns.folderBroken = {}`
  - `ns:LoadFolder(key, quiet) -> boolean`, per rulings 4 and 6
    - `quiet` means no "Not during a fight." message (for automatic loads)
    - the folder's last `ns.FolderFileDone` and the late functions run inside it
  - `ns:LoadPlanner(quiet)` and `ns:LoadGold(quiet)`, the same call with the key filled in
  - `ns.FolderFileDone(key, file)` and `ns.FolderLate(key, name, fn)`
  - **Stubs.** They are made as `ns.optionsStubs` are, kept in `ns.folderStubs[name] = stub`, and each loads its folder and hands the call on. A broken or refused load returns nil.
    - planner: `PlannerStart`, `PlannerOpen`, `PlannerCatchUp`
    - gold: `GoldOpen`, `GoldAuctionShow`
  - **Command words.** For `duo`, `share` and `keys`: `ns.GuideRegisterCommand(word, Loader)`. When the folder registers the same word on load, its own command replaces the loader. A re-entry guard stops a loop when it does not, and the call then returns false.
  - **Gold's entry points**, moved here from Gold.lua's "entry points" block:
    - the launcher hooks `LauncherTipExtra` (the "Ctrl-click: ways to make gold" line) and `LauncherClickExtra` (Ctrl → `ns:GoldOpen()`)
    - `AUCTION_HOUSE_SHOW` → `ns:GoldAuctionShow()`; `AUCTION_HOUSE_CLOSED` hides `ns.goldPanel` when it is there
    - Task 1's `GuideRegisterCommand("gold")`, panel action and lock registration
    - all of them silent while locked
  - **The login load.** At `PLAYER_LOGIN`, when unlocked, `ns:GuideOn()`, and following `ns.GUIDE_PLANNED` or `ns.GUIDE_TRIP`: `ns:LoadPlanner(true)`, then `ns:PlannerReplan("loading screen")` when ready.
  - A seam-list comment block in Folders.lua, between `-- Folder seams (what the main add-on calls in the folders):` and `-- end of folder seams`, one name per line. It holds every `ns[.:](Planner|Gold)\w+` that a file of `FantasyGlassUI/` or `FantasyGlassUI_Options/` uses, is not defined in `FantasyGlassUI/`, and is called from the main add-on.
- Guide.lua gets `ns.GUIDE_PLANNED = "\1planned"`, which is removed from PlannerRoute.lua.
- **Each moved file:**
  - its first line `local _, ns = ...` becomes `local ns = _G.FantasyGlassUI` followed by `if type(ns) ~= "table" then return end`
  - its last line is `ns.FolderFileDone("<key>", "<File>.lua")`
  - its `PLAYER_LOGIN` work becomes `ns.FolderLate(...)`

- [ ] **Step 1: Write the failing tests.** Restore everything afterwards. **`tests/test_addon.py`:**
  - `test_versions_agree`: all five TOCs say the same version.
  - `test_folder_tocs`: both new TOCs have exactly ruling 2's lines and the files of `ns.FOLDERS[key].files` in that order, and every listed file exists.
  - `test_folder_titles_neutral`: no "plan", "gold", "guide" or "advis" in either TOC's Title or Notes.
  - `test_folder_files`:
    - each folder file starts with the two header lines and ends with its `FolderFileDone` line
    - no folder file has `"PLAYER_LOGIN"`
    - no `Planner*.lua` other than `PlannerTravel.lua`, `PlannerKills.lua` and `PlannerRecorders.lua` is left in `FantasyGlassUI/`
    - no `Gold*.lua` other than `GoldRecorders.lua` is left there
  - `test_folder_seams_listed`: the Folders.lua block holds exactly the names its rule above gives, and each one is defined in a folder file.
  - `test_packaging`: `.pkgmeta` moves both folders, and `release.yml`'s version loop names both TOCs.

  **Smoke:**
  - `try("folders: nothing loads while locked", …)`:
    - locked: `ns:LoadPlanner()`, `ns:LoadGold()`, `ns:PlannerStart()`, `ns:GoldOpen()`, `AUCTION_HOUSE_SHOW`, Ctrl-click on the launcher, and `PLAYER_LOGIN` with a planned guide state each leave the `LoadAddOn` spy at 0 calls for both folders
    - the launcher tooltip has the same lines as with `LauncherTipExtra` nil
  - `try("folders: load for the tests", …)`: unlocked, both load, `ns.folderReady.planner` and `.gold` are true, and the spy counts one load each. This is the fixture that later tests rely on.
  - `try("folders: a folder that will not load", …)`, with a fake key `test` (`files = { "A.lua", "B.lua" }`) and the `LoadAddOn` stub answering per case:
    - "MISSING" → false, one message naming the folder, a second call within 10 s silent
    - "DISABLED" → `EnableAddOn` called, then loaded
    - only A reports done → not ready, `ns.folderBroken.test == { "B.lua" }`, one `ns.errors` line, and the stub message printed
    - in combat → false, "Not during a fight." (not with `quiet`), and `LoadAddOn` never called
    - before `IsLoggedIn()` → false
  - `try("folders: following the plan loads the planner at login", …)`, with `ns.LoadFolder` spied (the fixture has already loaded the folder): with a planned state, `PLAYER_LOGIN` calls it once with ("planner", true) and replans with "loading screen"; with a written guide, no call.
  - `try("folders: late login work", …)`: a `FolderLate` function runs once after the load; one that errors adds an `ns.errors` line and the next still runs.
- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement the loader, stubs and entry points** in Folders.lua.
- [ ] **Step 4: Move the files.** `git mv` the files, write the TOCs, edit the headers and last lines, and move the `PLAYER_LOGIN` work to `FolderLate`. Edit the main TOC.
- [ ] **Step 5: The harness** (`tests/smoke.py`):
  - The syntax check and the TOC/folder agreement cover `../FantasyGlassUI_Planner/` and `../FantasyGlassUI_Gold/`.
  - Their sources go in as `planner/<f>` and `gold/<f>`.
  - The `LoadAddOn` mock loads each folder's files in TOC order with `pcall(fn, "<addon>", {})`, a private table as in the game, once.
  - `C_AddOns.IsAddOnLoaded(addon)` is true after that.
  - Place `try("folders: load for the tests", …)` immediately before the first test that calls a function defined in a folder file:
    - run the smoke once without the fixture
    - the first `CALL ERROR … is nil` naming a folder function marks the spot
    - the "nothing loads while locked" test goes right before it
- [ ] **Step 6: The audits.**
  - `secretaudit.py` and `lockaudit.py` load both folders' files right after the main add-on and the options, so every handler is audited.
  - `forever_audit.py`'s `FOLDERS` gains both.
  - Regenerate `.luacheckrc`.
- [ ] **Step 7: Packaging.**
  - **`.pkgmeta` `move-folders`:** add `FantasyGlassUI/FantasyGlassUI_Planner: FantasyGlassUI_Planner` and `FantasyGlassUI/FantasyGlassUI_Gold: FantasyGlassUI_Gold`.
  - **`release.yml`:** the version loop lists `FantasyGlassUI_Planner/FantasyGlassUI_Planner.toc` and `FantasyGlassUI_Gold/FantasyGlassUI_Gold.toc`.
  - **`/home/claude/build.sh`**, edited so that every 12.x build stays as it is. Each new line acts only when its folder exists (`[ -d FantasyGlassUI_Planner ]`):
    - the version and LoadOnDemand checks
    - the "TOC lists a missing file" loop
    - the folder in the `zip` and in the `unzip -l` grep
    - the folder in the luacheck line

    Do not run build.sh (see Risks).
- [ ] **Step 8:** Run the tests and confirm they pass. Run the per-task checks, the full `pytest` and `lockaudit`.
- [ ] **Step 9: Commit** `"Planner and gold in their own folders, loaded only when used and never while locked"`.

---

### Task 3: The seams for the groups (controller)

**Files:** see File Structure.

**Interfaces:**
- **PlannerRoute.lua:**
  - `ns.PlannerTripState(ctx) -> state`: the state table `Build` makes (lines 746–755 today), factored out. `Build` calls it.
  - `ns.PlannerTrip(state, dest, steps, between) -> seconds|nil`: the local `Trip`.
- **Guide.lua:**
  - `ns.GUIDE_TRIP = "\1trip"`
  - `panel.planner`: `ns:CreateButton(panel, "Planner", 44, 18, fn)` at BOTTOMRIGHT (−98, 6). It is shown while unlocked, calls `ns:PlannerOpen()`, and its tooltip is "Your route planner: the plan and its settings".
  - `panel.ridingButton`: an invisible Button over `panel.riding`, shown with it. A click calls `ns:GoldOpen({ goalName = "mount" })`; the tooltip is "Save for riding: ways to make gold".
  - The seam list gains `GUIDE_TRIP` and every new name.
- **Core.lua:** in the slash handler's final `else`, first `if ns.HiddenCommand and ns.HiddenCommand(msg, raw) then return end`.
- **Companion.lua:**
  - `ns.RegisterToolExtra(key, label, typed, fn, shown)`: the same key replaces, `fn` nil removes.
  - `ToggleToolsMenu` builds the extras' buttons once, after the static ones, under a heading "Guide". At every open it shows only the extras whose `shown()` is true, and the heading only when any is. The palette's height is set from what is shown, so a locked player's palette is today's.
  - The tooltip is `typed`.
- **Folders.lua:**
  - `ns.HiddenCommand` per ruling 12
  - `ns.RegisterToolExtra("planner", "Planner", "/fgui plan", PlannerOpen, Unlocked)`
  - `ns.RegisterToolExtra("gold", "Ways to make gold", "/fgui guide gold", GoldOpen, Unlocked)`
- **Gold.lua:**
  - `ns:GoldOpen(opts)`: `opts.goalName` ∈ {"mount", "epic"} sets `goalName` and the class-aware `goal` before drawing.
  - `ns.GoldGo` calls `ns:LoadPlanner()` (guarded) before it looks for `ns.GoldTravel`.
  - `ns.GoldStepsList(idea) -> window`: the list branch of `GoldGo`, exported.
- **The four empty files** have a header and their done line (main files: `local _, ns = ...`). TOC places:
  - `PlannerRecorders.lua`: after `PlannerTravel.lua`
  - `GoldRecorders.lua`: after `SellHints.lua`
  - `PlannerWindow.lua` and `PlannerGo.lua`: last in the planner TOC
- **The fences** as in File Structure.

- [ ] **Step 1: Write the failing test** `try("folders: seams", …)`. Restore everything afterwards. Cases:
  - **Locked:**
    - the panel has no shown `planner` button
    - Tools menu buttons and height are equal to a palette built with no extras registered
    - `/fgui plan` prints the same lines as `ns.ClosestCommand`'s path gives for "plan" with `ns.HiddenCommand` nil
    - `ns.toolCommands.plan == nil`
  - **Unlocked:**
    - the panel's `planner` button is shown, sits at (−98, 6), and its click calls a stubbed `PlannerOpen` once
    - the Tools menu shows the "Guide" heading and two extras, and a click on "Planner" calls `PlannerOpen`
    - `/fgui plan` calls `PlannerOpen`
  - **Riding line.** At level 40 with 30g, a Warrior: `panel.ridingButton` is shown, and its click calls `GoldOpen` with `{ goalName = "mount" }`.
  - **GoldOpen.** `ns:GoldOpen({ goalName = "mount" })` gives `goldChars[key].goal == 1200000` (a Paladin: 1000000).
  - **The trip exports.** `ns.PlannerTrip(ns.PlannerTripState(ctx), dest, steps, false)` gives the same steps as batch 1's known-flight test route.
  - **GoldGo.** With `ns.GoldTravel` nil and `LoadPlanner` stubbed to define it, `ns.GoldGo(idea) == "travel"`.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run it and confirm it passes.** Run the per-task checks, the full `pytest` and `lockaudit`.
- [ ] **Step 5: Phrases.** Run `add_tr.py` on a json of "Planner" (with the ruling 7 translations), "Your route planner: the plan and its settings", "Save for riding: ways to make gold", "Guide" and "Ways to make gold". Do not commit that file.
- [ ] **Step 6: Commit** `"Folders: seams for the groups (the panel's Planner button, the Tools extras, /fgui plan, the trip exports, the fences)"`. This commit is `SEAMS`.

---

### Task 4 (group A): The planner's recorders back in the main add-on

**Files:** see File Structure. Tests: smoke regions "unloaded A" and "A".

**Interfaces:**
- **Consumes:**
  - `ns.GuideRegisterLock`, `ns.GuideState`, `ns.GUIDE_PLANNED`, `ns.GuideHere`
  - `ns.PlannerWorldPos` (PlannerTravel.lua)
  - `ns:LoadPlanner`, `ns.folderReady`, `ns:AfterFight`
  - `ns.GoldGatherSent` (guarded)
- **Produces:** in `PlannerRecorders.lua`, moved verbatim with their saved keys:

  | Recorder | Moved from | What it writes or does |
  |---|---|---|
  | `ns.PlannerCharRecord` (`PaceRecord`) | Planner.lua | the per-character record |
  | `ns.PlannerKillXP` and its gray/zero-difference helpers | Planner.lua | none: `PlannerKills.lua` needs the formula while unloaded |
  | quest times (`open`, `since`, `Share`, `Close`, batch 6's away and resting sharing, `ns.PlannerRecordQuestTime`) | Planner.lua | `plannerQuestTimes`; only while following, as today |
  | solo elites (`soloAt`, `ns.PlannerRecordSoloElite`, `ns.PlannerClassToken`) | Planner.lua | `soloAt`, `plannerSoloElites` |
  | deaths (`ns.PlannerRecordDeath`) | Planner.lua | `deaths` |
  | the trainer flags and `TrainerClosed` | Planner.lua | `trainerLevel`, `ridingKnown` (ruling 13) |
  | `ns.PlannerMountSeen` | PlannerStops.lua | `mountSeen`, `ridingKnown` |
  | the reward pick (`ns.PlannerBestChoice`, `PickReward`, `QUEST_COMPLETE`) | PlannerAdvice.lua | selects the reward |
  | the session start | PlannerAdvice.lua | `plannerSessionAt` |
  | the one gathering SENT handler, `ns.PlannerGatherSkill`, `ns.PlannerRecordNode` | PlannerPath.lua | `plannerNodesSeen` |
  | places seen (`ns.PlannerSeen`, `MAIL_SHOW` / `MERCHANT_SHOW`) | PlannerSource.lua | `plannerSeen` |
  | the timed-quest memory | PlannerSource.lua (batch 6) | `plannerTimed` |
  | the bind place (`HEARTHSTONE_BOUND`) | PlannerRoute.lua | `bindAt` |
  | the level clock (`ns.PlannerLevelTick`, `ns.PlannerRecordLevel`, `ns.PlannerLevelSummary`, `ns.PlannerLevelLines`, `ns.PlannerLevelRunLines`, the 10 s ticker) | PlannerRecords.lua | `levelClock`, `plannerLevels`; Lifetime and RunLog need the readers |
  | last seen (`ns.PlannerSeenSave`, every 60 s and at logout) | PlannerPace.lua | `lastSeen`, `lastVersion` |
  | the catch-up check | PlannerPace.lua | at initial PEW, when away ≥ `ns.PLANNER_CATCHUP_DAYS` days and the guide is on: `ns:LoadPlanner(true)`, then `ns:PlannerCatchUp(away, lastVersion)`, before last seen is saved |
  | the duo prefix and the ask hand-over (`ns.PlannerDuoRegister`) | PlannerDuo.lua | ruling 14 |

  `ns.PLANNER_CATCHUP_DAYS` and `ns.PLANNER_SEEN_CAP` move with their recorders.
- **What the folder keeps:**
  - Planner.lua's second event frame: replans, window-closed ticks, `CountHandIn`, and the vendor/mail visit counters, which tick only while following
  - PlannerPace's display and limit hooks
  - PlannerDuo's `Receive`, the session and the ask page (`ns.PlannerDuoEvent` stays its entry)
  - PlannerRecords' `PlannerLeftOff`, which only shows while following, and following means loaded

- [ ] **Step 1: Write the failing tests.** Restore everything afterwards.
  - **`try("folders unloaded A: the planner records while unloaded", …)`**, in the unloaded region, unlocked, with `ns.folderReady.planner` not true and the `LoadAddOn` spy at 0:
    - `TAXIMAP_OPENED` with two reachable nodes → `planner[key].flights` holds both
    - a take-off then a landing 90 s later → `plannerFlightTimes`
    - `PLAYER_DEAD` at a world spot → `deaths` +1
    - `MERCHANT_SHOW` with an npc name → `plannerSeen.vendor` +1
    - `HEARTHSTONE_BOUND` → `bindAt`
    - `UNIT_SPELLCAST_SENT` on Peacebloom → one node
    - `PLAYER_LEVEL_UP(12)` → `plannerLevels` for level 11
    - a solo elite accepted and handed in → `plannerSoloElites`
    - `QUEST_ACCEPTED` with `GetTimeAllowed` 900 → `plannerTimed`
    - a kill line paired with +145 XP → `killXP[0]`
    - `QUEST_COMPLETE` with two choices → the better one selected, one frame later
    - two `ns.PlannerLevelTick(10)` calls → `levelClock.seconds == 20` (the first one makes the clock)
    - `ns.PlannerLevelLines()` is not empty
    - the `LoadAddOn` spy is still at 0
  - **The duo ask**, in the same region:
    - a valid `CHAT_MSG_ADDON` ask → one `LoadAddOn("FantasyGlassUI_Planner")` and one `ns.PlannerDuoEvent` call with the same five arguments. Stub both, so the region stays unloaded.
    - the same ask in combat → nothing until `PLAYER_REGEN_ENABLED`, then once
    - in combat for 70 s → never
    - locked, `plannerDuoAsk = false`, a party channel, a secret sender, or `D1:HI` → nothing
    - a second identical ask while the stub says loaded → no second hand-over
  - **`try("folders A: recorders moved, not copied", …)`** (after the fixture): each produced name above is defined by `PlannerRecorders.lua` (check with `debug.getinfo(fn).source`) and appears in no folder file. Add `tests/test_addon.py::test_recorders_in_main` for the source check.
  - **The catch-up.** `lastSeen` 15 days ago → `PlannerCatchUp` is called once before `lastSeen` is rewritten. 13 days → not called.
- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement.** Cut the listed code from the folder files and paste it into `PlannerRecorders.lua` in the order of the table, each behind one `do … end` event frame per old frame, with the same `ns:Guard` labels. Delete the moved lines from the folder. PlannerDuo's `GuideRegisterLock("duo")` keeps only `Reset` on lock. Nothing else changes: batch 1–6 tests must pass untouched.
- [ ] **Step 4: Run them and confirm they pass**, along with every earlier planner test. Run the per-task checks.
- [ ] **Step 5: Commit** `"Planner: what it learns is recorded by the main add-on, so nothing goes deaf while the planner is not loaded"`.

---

### Task 5 (group B): Gold's recorders back in the main add-on

**Files:** see File Structure. Tests: smoke regions "unloaded B" and "B".

**Interfaces:**
- Produces, in `GoldRecorders.lua`, moved verbatim (each file's block marked `-- recorders (light; may stay in the main add-on when the folder moves)`, plus what those blocks call):
  - the job runner: `ns.GoldJob`, `ns.GoldYield`, `ns.GoldRunSlice`, the fight flag frame and the `ns.errors` note, with `ns.GOLD_BUDGET_MS`
  - the merchant prices: `ns.GoldVendorNote`, `ns.GoldVendorBuy`, the `"goldVendorRecord"` and `"goldVendorTrim"` jobs → `goldVendor`
  - the monster loot: the `LOOT_OPENED` / `LOOT_CLOSED` / `UNIT_SPELLCAST_SUCCEEDED` frame → `goldMobs` and the pace in `goldChars`
  - what gathering gave: `ns.GoldGatherSent`, the SUCCEEDED / `LOOT_OPENED` frame → `goldNodeItems`, `goldGather`
  - `ns.GoldFoldNodes` and its `PLAYER_ENTERING_WORLD` trigger
  - the recipes: `ns.GoldRecipesRead` and the `TRADE_SKILL_SHOW` / `TRADE_SKILL_LIST_UPDATE` frame → `goldChars[key].recipes`
- The gold folder keeps everything else. `ns.GoldVendorBuy` is a reader that the folder and crafting both use; it moves with its store.

- [ ] **Step 1: Write the failing tests.** Restore everything afterwards.
  - **`try("folders unloaded B: gold records while unloaded", …)`**, unloaded and unlocked:
    - a merchant with 3 items → after the job, `goldVendor.items` holds 3
    - a kill's loot window with one creature and 2 items → `goldMobs[npc]`
    - an herb gathering, then `LOOT_OPENED` → `goldNodeItems`
    - `TRADE_SKILL_SHOW` with the stub `C_TradeSkillUI` → after 1 s and the job, one recipe
    - a pending `goldNodesSeen` → folded at PEW
    - in combat, no job slice runs; after `PLAYER_REGEN_ENABLED` the jobs finish
    - the `LoadAddOn` spy is at 0
  - **`try("folders B: recorders moved, not copied", …)`** and `test_recorders_in_main` cover each name above.
- [ ] **Step 2: Run them and confirm they fail. Step 3: Implement** as Task 4 Step 3 does. **Step 4: Run them and confirm they pass**, along with every gold test. Run the per-task checks.
- [ ] **Step 5: Commit** `"Gold: prices, loot, gathering and recipes are recorded by the main add-on, so nothing goes deaf while gold is not loaded"`.

---

### Task 6 (group C): The planner's own window, with its switches off the Guide tab

**Files:** see File Structure. Test: smoke region "C"; `specs/plans/phrases/folders-c.json`.

**Interfaces:**
- **Consumes:**
  - `ns.PlannerPreviewLines`, `ns.PlannerRiding`, `ns.PlannerGoldText`, `ns.GuideState`, `ns.GuideStepBase`
  - `ns:GoldOpen(opts)`, `ns:PlannerStart`, `ns:PlannerReplan`, `ns:GuideStop`, `ns.GUIDE_TRIP`
  - Bars.lua's section bodies, moved here
- **Produces:**
  - `ns:PlannerOpen() -> frame`, which replaces the stub
  - `ns.PlannerWindowSummary() -> { strings }`
  - `ns.plannerWindow` (the frame) with `.T`
  - all per ruling 10
- **Bars.lua:** no `ns.db.planner` left, and the Guide tab per ruling 10.

- [ ] **Step 1: Write the failing test** `try("folders C: the planner window", …)`. Restore everything afterwards. Cases:
  - **Locked:** `ns:PlannerOpen()` returns nil and makes no frame.
  - **The look.** Unlocked, it opens `FantasyGlassUIPlanner` in the settings look. `ns:SetLook` is called with `"settings"`, and the frame is in `UISpecialFrames`.
  - **Not following.** The summary is `{ "You are not following a plan." }`, and the button reads "Plan my route".
  - **Following.** With the batch 4 preview fixture, the summary holds its first 4 preview lines and "Step 1 of N: …", and the button reads "Plan again". Its click sets `ns.plannerReason == "again"`.
  - **On a trip.** With a trip state, the summary is "On a trip: Gather Peacebloom in Elwynn Forest, step 2 of 5" and "Your levelling plan waits."
  - **The riding line.** At level 40, a Warrior with 30g:
    - the summary ends "Riding: 90g to go"
    - "Save for riding" calls `GoldOpen({ goalName = "mount" })`
    - with the real gold window, its remaining amount equals 900000
    - `ns.GOLD_GOALS.mount.copper == ns.PLANNER_RIDING_COPPER + ns.PLANNER_MOUNT_COPPER` and `byClass.PALADIN == ns.PLANNER_RIDING_COPPER`
  - **Gold.** "Ways to make gold" calls `ns:GoldOpen()` once.
  - **The groups.** The nine group headings are present in order. Each `ns.db.planner*` key that `git show SEAMS:FantasyGlassUI_Options/Bars.lua` reads has a control in `T`, and toggling it writes the key and replans while following (as the Guide tab did).
  - **The Guide tab.** It has no planner control, and its "Planner settings" calls `PlannerOpen`.

  Then pytest `test_planner_switches_moved`: `grep -c "ns.db.planner" FantasyGlassUI_Options/Bars.lua` is 0, and every key `SEAMS`'s Bars.lua had appears in `PlannerWindow.lua`.
- [ ] **Step 2: Run them and confirm they fail.**
- [ ] **Step 3: Implement.**
  - Move the sections and the controls from Bars.lua's `BuildGuidePage` into the window, keeping their callbacks.
  - Change the existing smoke lines that read `ns.guidePage.<moved field>` to open the window and read `ns.plannerWindow.T.<field>`.
  - Write the new phrases to `folders-c.json`: "Route planner", "You are not following a plan.", "Step %d of %d: %s", "On a trip: %s, step %d of %d", "Your levelling plan waits.", "Plan again" (if batch 6 did not add it), "Stop", "Save for riding", "Planner settings", and the 9 headings.
- [ ] **Step 4: Run them and confirm they pass.** Run the per-task checks.
- [ ] **Step 5: Commit** `"Planner: its own window, the plan at the top and its switches grouped below, with the way to gold and riding"`.

---

### Task 7 (group D): The trip on the guide panel: pause, steps, resume

**Files:** `FantasyGlassUI/Guide.lua`; smoke region "D"; `specs/plans/phrases/folders-d.json`.

**Interfaces:**
- **Consumes:** `ns.GUIDE_TRIP`, `ns:PlannerReplan` (guarded).
- **Produces** (Guide.lua; added to the seam list):
  - `ns:GuideStartTrip(guide, info) -> boolean`, where `info = { title, id, minutes|nil }`
  - `ns:GuideEndTrip(why) -> boolean`, where `why` ∈ "done", "stop", "other"
  - `ns.GuideOnTrip() -> boolean`
  - The panel title while on a trip is "Gold trip: %s".
  - "..." shows while following the plan **or** on a trip. A built-in entry, "Stop this trip", shows only on a trip.
  - Ruling 9's pause and resume rules, including `ns:GuideSetPlan` and `ns:GuidePlanFailed` writing into `resume` while on a trip.

- [ ] **Step 1: Write the failing test** `try("folders D: a trip pauses the plan and resumes it", …)`. Restore everything afterwards. Cases:
  - **Start.** Following the plan at step 3 with 2 ticks, `GuideStartTrip({ name = GUIDE_TRIP, steps = { goto A, goto B } }, { title = "T" })`:
    - the state name is `GUIDE_TRIP`
    - `resume.name == GUIDE_PLANNED`, `resume.at == 3`, and the ticks are kept
    - the panel title is "Gold trip: T"
  - **Finish.** Reaching A and then B (`GuideWorld` stubbed) ends the trip:
    - the state is the old plan at step 3
    - "Back to your levelling plan." was printed
    - `PlannerReplan` was called with "trip over"
  - **Stop.** "Stop this trip" resumes the plan. `/fgui guide stop` on a trip resumes; a second stop clears.
  - **A plan during a trip.** `ns:GuideSetPlan(newPlan, sum)` during a trip leaves the trip followed, and `resume.plan == newPlan`. Ending the trip then follows `newPlan`.
  - **A trip during a trip** keeps the first `resume`.
  - **Another guide.** `GuideFollow("written")` during a trip drops both.
  - **A trip from a written guide** resumes that guide at its step. **A trip from no guide** ends with no guide and no replan.
  - **Reload.** A copy of the saved state through the harness's "reload" (re-run `ns:GuideAdvance()` with `resumed`) still resumes at the end.
  - **Locked.** The trip state stays saved, and the panel hides as today.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run it and confirm it passes.** Run the per-task checks.
- [ ] **Step 5: Commit** `"Quest guide: a trip pauses the plan you follow and gives it back when it is done or stopped"`.

### Task 8 (group D): Go: the planner's travel for a gold idea, with a duo or a time limit

**Files:** `FantasyGlassUI_Planner/PlannerGo.lua`; smoke region "D"; `folders-d.json`.

**Interfaces:**
- **Consumes:**
  - `ns.PlannerContext`, `ns.PlannerTripState`, `ns.PlannerTrip`, `ns.PlannerJob`
  - `ns:PlannerDuoEnd`, `ns.plannerDuo`, `ns.PlannerTimeLeft`
  - `ns.GoldTimeText`, `ns.GoldStepsList`
  - Task 7's `ns:GuideStartTrip`
- **Produces:** `ns.GoldTravel(idea) -> boolean` (true when the job was queued), per ruling 9.

- [ ] **Step 1: Write the failing test** `try("folders D: Go", …)`. Use the planner's fake world: Stormwind and Elwynn, a known flight, the boat. Restore everything afterwards. Cases:
  - **An idea on another continent.** A gather idea with steps at Ashenvale nodes 1–3 → after the job:
    - the guide follows `GUIDE_TRIP`
    - its steps are the planner's trip to node 1 (a `fly`, a `sail`, a `goto`, as `ns.PlannerTravel` gives), then `goto` nodes 2 and 3 with their names
    - the levelling plan is in `resume`
  - **Unreachable.** A step on a map with no way there → "No way there was found: here are the steps.", `GoldStepsList` was called, and the state is unchanged.
  - **An idea on two maps.** The trip is added before the first step of the second map.
  - **Placeless steps** become `note` steps.
  - **Duo.** As leader, with a duo stubbed: `PlannerDuoEnd` was called with ("guide", true) before the trip starts.
  - **A time limit.** `PlannerTimeLeft` = 1800 and the trip takes about 600 s of travel plus a one-off's 10 min → the first step is a note "This trip takes about 20 min; you have 30 min left."
  - **No time limit.** No such note.
  - **Combat.** `ns.GoldGo` refuses as before.
  - **A running replan.** With a replan queued, Go waits its turn in the planner's job queue. The replan's result lands in `resume`, never over the trip (through Task 7).
  - **The end.** Ending the trip resumes and replans.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run it and confirm it passes.** Run the per-task checks.
- [ ] **Step 5: Commit** `"Gold: Go plans the trip with the planner's flights, hearthstone and boats, and the levelling plan waits for it"`.

---

### Task 9: Merge, check everything, the combined in-game checklist, the final review (controller, on `quest-planner`)

- [ ] **Step 1: Merge** `folders-a`, `-b`, `-c` and `-d` with `--no-ff`, as in "Parallel build and merge". Remove the worktrees and branches.
- [ ] **Step 2: Translations.** Run `add_tr.py` for each `specs/plans/phrases/folders-<x>.json`, then `git rm -r specs/plans/phrases`.
- [ ] **Step 3: The integration test** `try("folders together: one session", …)`, in the together region. Restore everything afterwards. Cases:
  - Unlocked:
    1. the panel's Planner button opens the window
    2. "Ways to make gold" opens gold
    3. Go on a gather idea puts the trip on the panel, with the levelling plan in `resume`
    4. walking the steps ends the trip, and the plan is followed again and replanned
  - `/fgui plan` opens the window.
  - Locked again: the Tools menu has no extras, `/fgui plan` gives the unknown-word reply, `AUCTION_HOUSE_SHOW` opens nothing, and the panel shows no Planner button.
  - No Lua error lands in `ns.errors` during the test.
- [ ] **Step 4: Run the smoke.** `cd FantasyGlassUI && python3 ../tests/smoke.py` → `syntax: all … OK` and `errors: no errors` twice.
- [ ] **Step 5: Run the other checks.**
  - `luacheck . -q` → 0 warnings
  - `python3 tests/forever_audit.py` → exit 0
  - `python3 tests/secretaudit.py` → `0 lines compared a hidden value`
  - `python3 tests/lockaudit.py` → `(no protected calls in combat)`
  - `node tests/plan_reader_check.js` and `python3 tests/sitecheck.py` → pass
  - `python3 -m pytest tests -q` → all pass (batch 6's 9 tests plus this plan's new ones)
- [ ] **Step 6: Run the guards.**
  - The Global Constraints grep → empty.
  - `git diff --stat $BASE -- docs wiki site-src README.md CHANGELOG.md RELEASE.md FantasyGlassUI/*.md FantasyGlassUI_Options/FeatureList.lua FantasyGlassUI_Options/Categories.lua` → empty.
  - `grep -rniE "planner|make gold|ways to make|FantasyGlassUI_(Planner|Gold)|/fgui plan" README.md CHANGELOG.md RELEASE.md FantasyGlassUI/*.md wiki docs site-src` → nothing.
  - `/fgui help` text is unchanged. Check by diffing `ns.helpLines` against `$BASE`'s in a smoke assertion.
- [ ] **Step 7: The notes.** Write `specs/plans/2026-11-26-folders-and-joining-notes.md`:
  - the rulings as built
  - any conflict outside a region
  - the Locales keys that differed
  - the deferred findings
- [ ] **Step 8: The combined in-game checklist.** Write `specs/plans/2026-11-26-in-game-checklist.md`, the one list the 13.0 release works through.
  - **Copied checks.** Every unticked check from these notes files, copied word for word under a heading naming its source:
    - planner: `*-core-notes`, `*-stops-notes`, `*-choices-notes`, `*-feel-notes`, `*-together-notes`, `*-leftovers-notes`, and the polish check's notes
    - gold: `2026-11-25-gold-core-notes.md`, `2026-11-25-gold-advisor-notes.md`
    - this plan's notes
  - **Duplicates** are merged into one line that names every source.
  - **New for this plan:**
    - the add-on list: both "extras" lines, their tooltips, load-on-demand, locked and unlocked
    - the load hitch: time from the Planner button click to the window (`/fgui perf`), and the login while following
    - recording while unloaded, on a fresh login with neither folder loaded:
      - a flight and a boat, then their times
      - a death
      - a merchant (`goldVendor`)
      - a kill's loot (`goldMobs`)
      - an herb (one node, its loot)
      - a recipe window
      - a level-up
      - a kill's experience (`killXP`)
      - a timed quest (`plannerTimed`)
    - a friend asks while your planner is unloaded: the page shows; in a fight it shows after the fight
    - the node fold on a real saved file: node counts before and after, and no duplicates on the map
    - the panel's bottom row in all nine languages: Plan again, Planner, "..." and Guides do not touch
    - the Tools menu's "Guide" group, the Ctrl-click, `/fgui plan`, and the auction-house panel after the folder load
    - Go:
      - a gathering trip with a flight and a boat
      - the trip ticking on the panel
      - the plan resumed and replanned
      - Go during a duo (the friend's side says it ended)
      - Go with a 30-minute limit
      - a /reload in the middle of a trip
    - a broken folder (rename one planner file): one message, `/fgui check` names it, written guides still work
  - Commit `"Folders and joining: build notes and the combined in-game checklist"`.
- [ ] **Step 9: Final review and fixes.** One final whole-branch review on the most capable model, of `git diff $BASE..HEAD` against this plan and both specs. Then one fix wave, one commit, `"Folders and joining: the final review's fixes"`. Re-run Steps 4–6 after it.

---

## Risks to watch (for the reviewer and the player)

- **The load hitch.**
  - `LoadAddOn` runs a whole folder (about 9,000 lines for the planner) in one go. It cannot be sliced, so the first click on the planner can stall one frame far past 4 ms.
  - The login load is hidden behind the loading screen. The click and the duo-ask loads are not.
  - The in-game checklist measures it. Splitting the planner folder further would be the fix.
- **Forever's add-on list.**
  - Whether its tooltip shows OptionalDeps, and so the name "FantasyGlassUI_Planner" on the gold line, is not known.
  - Whether `LoadAddOn` answers "DISABLED" exactly as for the options folder is assumed from `ns:LoadOptions`.
- **Missed login work.** A folder file that did its work at login and is missed by the `FolderLate` sweep fails silently. The pytest bans `PLAYER_LOGIN` in the folders. It cannot see work done at a first `PLAYER_ENTERING_WORLD` that a late load misses. The reviewer checks each `PLAYER_ENTERING_WORLD` handler left in the folders.
- **build.sh.**
  - build.sh runs its own copies of the tests in `/home/claude`.
  - `tools/sync_tests.py` copies those over the repository's `tests/`, so running build.sh on this branch would overwrite this branch's harness.
  - The 13.0 release plan must refresh the `/home/claude` copies from the branch before its first build. This plan does not run build.sh.
- **The plan rests on batch 6 and the polish check, which are not built yet.**
  - It assumes batch 6's exact names: `ns.GuideRegisterLock`, the seam list markers, `PlannerKills.lua`, `plannerTimed`, `panel.again` at 60–132.
  - Task 1 Step 1 stops if one is missing, and the controller then re-greps and renames here before going on.
- **The Step 0 merge.** Both branches have grown `tests/smoke.py` past 16,000 lines and inserted fences at the same spot. The Locales union is scripted, not resolved by hand. The merge is the largest single conflict of the project, and its review deserves a careful reader.

## Addition (controller, 22:38): "Report a problem"
- In the planner window and the gold window, a "Report a problem" button opens `ns:ShowCopyBox` with a code: "FGUIR1!" plus the share encoding of `{ v, version, client build, class, level, map, plan summary (zone, steps, at), the current gold idea's kind and key, the last 5 entries of ns.errors trimmed to 200 bytes each, settings that differ from defaults (planner/gold keys only) }`. Nothing else goes in: no names, no realm, no guild, no chat.
- The caption reads: "Copy this and paste it with your report in Discord." It is hidden while the guide is locked.
- Test that the code never contains the character or realm name.
