# Gold Advisor, Batches 2–5 (the hidden advisor) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **This plan is built for parallel execution**: Tasks 1 and 2 (the seams) run first, in order, alone. Tasks 3–8 then run in four groups (A, B, C, D), each in its own git worktree at the same time. Task 9 merges them and checks everything. Read "Parallel build and merge" before you start.

**Goal:** A hidden "Ways to make gold" window. It is reachable only when the guide is unlocked, and it is built in the 12.3 settings look. It has a "Right now" section of one-off ideas, a list of per-hour ideas ranked by three sliders, presets, an optional goal, and Go. There is also a panel on the auction house. Four kinds of ideas plug into it: bags and selling with vendor flips (batch 2), farming and dungeon drops (batch 3), gathering (batch 4), and crafting for profit with auction flipping (batch 5). Every number says how sure it is.

**Architecture:** `FantasyGlassUI/Gold.lua` is the core, built by the seams. It holds the idea record, the registry, a sliced job runner, the ranking and merging, the window, the auction-house panel, the Go seam, the shared value and freshness helpers, the vendor-price reader, and the entry points. Each group writes only its own file and plugs in through `ns.GoldRegister`:
- A: `GoldSell.lua`
- B: `GoldFarm.lua`
- C: `GoldGather.lua`
- D: `GoldCraft.lua`

The five files link to the rest of the add-on only through `ns.*` functions and game APIs, and they keep their data under `ns.root.gold*`. A later task can then move them into a load-on-demand `FantasyGlassUI_Gold` folder without changing any logic (see "Later: the folder move").

**Tech Stack:** Lua 5.1 (WoW Forever, interface 16001). The add-on's helpers used here:
- prices: `ns.PriceItems`, `ns.PriceEntry`, `ns.PriceHouse`, `ns.PriceFreshText`, `ns.AuctionUsual`, `ns.WorthSelling`, `ns.SellHintFor`
- farming and dungeons: `ns.FarmZoneRanking`, `ns.RunLogged`, `ns.RunPlaces`, `ns.RunLength`, `ns.LootBookKill`
- items and text: `ns.ShoppingLines`, `ns:ItemOwners`, `ns:GetItemInfo`, `ns:Coins`, `ns:Tr`, `ns.Today`, `ns.DaysBetween`
- the guide: `ns:GuideUnlocked`, `ns.GuideShowPanel`, `ns.GuideCommand`
- the window: `ns:ShowList`, `ns:SetLook`, `ns:CreateSlider`, `ns:CreateButton`, `ns:CreateEditBox`, `ns:NewStatusBar`, `ns:ScrollArea`, `ns:NewText`, `ns:KeepPlace`, `ns:Guard`, `ns:Every`, `ns:After`, `ns:IsSecret`, `ns:CharKey`

Tests go in `tests/smoke.py`.

**Spec:** `specs/2026-11-25-gold-advisor-design.md`, every section: What it covers 1–7, Estimates, Ranking, Where it shows, Build order 2–5, Non-goals, Left to the builder, and Answers 1, 2, 4 and 5. Batch 1, which this builds on: `specs/plans/2026-11-25-gold-core.md` and `-rulings.md`.

## Global Constraints

**Where the work happens**
- Base: `gold-core` after batch 1's fix wave. Branch `gold-advisor` in the worktree `/home/claude/fantasyglassui-gold2`, which the controller creates. Commits are by DustyMouse (`git -c user.name=DustyMouse -c user.email=fantasyglassui@users.noreply.github.com commit`) with no attribution lines. Implementers never push.

**Where the code lives (the player's change of 25 Nov)**
- Everything is in the main add-on: `FantasyGlassUI/Gold.lua`, `GoldSell.lua`, `GoldFarm.lua`, `GoldGather.lua` and `GoldCraft.lua`, in that order in `FantasyGlassUI.toc`, right after `SellHints.lua`.
- No `FantasyGlassUI_Gold` folder in these batches. The planner's own-folder move also waits until after them.

**Hidden**
- Every entry point exists only while `ns:GuideUnlocked()` is true: the launcher line and Ctrl-click, the guide-panel button, `/fgui guide gold`, and the auction-house panel.
- Nothing about the advisor goes into any public text: `/fgui help`, the `/fgui guide` usage line, README, wiki, `docs/`, `site-src/`, any CHANGELOG, RELEASE.md, FeatureList, Categories or the setup.
- No `ns:NewModule` in the Gold files, because modules appear in feature lists and the self-check. They use plain event frames that do nothing while the guide is locked.
- No `ns:Tr` call at file load. Strings are translated only when they are drawn, so a locked player's `ns.seenStrings` and `/fgui strings` never hold them.
- **The unlock phrase is never written anywhere**: not in code, tests, plan, notes or commit messages. Tests unlock with `ns.GuideUnlocked = function() return true end` and restore it afterwards.

**Lazy**
- Nothing is built at login. The window, the panel and any idea collection happen only when the window or the auction house opens.
- The recorders (merchant prices, loot, gathering, recipes) are light event handlers that write a few table fields. Anything that walks a list goes through `ns.GoldJob`.

**Fights, slices and hidden values**
- Never in combat: no job slice and no collection while `InCombatLockdown()` is true or between `PLAYER_REGEN_DISABLED` and `PLAYER_REGEN_ENABLED`.
- Slices are at most 4 ms (`ns.GOLD_BUDGET_MS = 4`, measured with `debugprofilestop`). `ns.GoldYield()` goes only in plain loops, never inside `pcall`, a sort comparator or a gsub callback.
- Every value read from the game goes through `ns:IsSecret` before it is compared, stored or used in arithmetic. A secret value is skipped.

**No posting, buying, crafting or reloading**
- The add-on never posts, buys, bids or crafts. `grep -nE "PostItem|PostCommodity|PlaceBid|StartCommoditiesPurchase|ConfirmCommoditiesPurchase|BuyMerchantItem|CraftRecipe|ReloadUI" FantasyGlassUI/Gold*.lua` stays empty.

**Game APIs**
- Every game API comes from `tests/forever_api.json.gz`. Check a name with:

  ```
  python3 -c "import gzip,json,sys;d=json.load(gzip.open('tests/forever_api.json.gz'));S=set(d['globals'])|set(d['fields'])|set(d['events']);[print(n,n in S) for n in sys.argv[1:]]" NAMES…
  ```

- Checked and present:
  - merchant: `GetMerchantNumItems`, `GetMerchantItemID`, `GetMerchantItemLink`, `C_MerchantFrame.GetItemInfo`
  - trade skills: `C_TradeSkillUI.GetAllRecipeIDs`, `C_TradeSkillUI.GetRecipeInfo`, `C_TradeSkillUI.GetRecipeSchematic`, `C_TradeSkillUI.IsTradeSkillReady`, `C_TradeSkillUI.GetBaseProfessionInfo`, `GetProfessions`, `GetProfessionInfo`
  - loot: `GetNumLootItems`, `GetLootSlotInfo`, `GetLootSlotLink`, `GetLootSlotType`, `Enum.LootSlotType.Money`, `GetLootSourceInfo`
  - units and spells: `UnitGUID`, `UnitLevel`, `UnitName`, `C_Spell.GetSpellInfo`
  - quests: `GetQuestLogRewardMoney`, `C_QuestLog.GetNumQuestLogEntries`, `C_QuestLog.GetInfo`, `C_QuestLog.IsComplete`
  - maps: `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`, `C_Map.GetMapInfo`, `GetRealZoneText`
  - items: `C_Item.GetItemCount`, `C_Item.GetItemInfo` (through `ns:GetItemInfo`)
  - add-ons: `C_AddOns.IsAddOnLoaded`
  - input and the rest: `IsControlKeyDown`, `GetMoney`, `InCombatLockdown`, `debugprofilestop`, `time`, `date`
  - events: `MERCHANT_SHOW`, `MERCHANT_UPDATE`, `LOOT_OPENED`, `LOOT_CLOSED`, `UNIT_SPELLCAST_SENT`, `UNIT_SPELLCAST_SUCCEEDED`, `TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`, `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`, `BAG_UPDATE_DELAYED`, `PLAYER_MONEY`, `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED`, `QUEST_LOG_UPDATE`
- **Not in the client, never used:** `GetMerchantItemInfo`, `GetItemInfo`, `GetItemCount`, `GetSpellInfo`, every `GetTradeSkill*` and `GetCraft*` function, `TRADE_SKILL_UPDATE`, `CRAFT_SHOW`. Use the replacements listed above.

**Saved data**
- Account-wide: `ns.root.goldVendor`, `goldMobs`, `goldNodesSeen`, `goldNodeItems` and `goldGather`.
- Per character: `ns.root.goldChars[ns:CharKey()]`, which holds goal, pace and recipes.
- Tables are created only when something is written. No `ns.db` defaults, so `Core.lua` does not change.

**Phrases**
- Seam tasks (1–2) run `python3 site-src/tools/add_tr.py` themselves.
- Groups do not run it. They write their phrases in add_tr's format to `specs/plans/phrases/gold-<a|b|c|d>.json`, and Task 9 applies them.
- Phrases go only into `FantasyGlassUI_Locales/Locales.lua`, never into `site_tr.py`, `keys_*.json` or `docs/i18n`.

**Per-task checks** (the last step before each commit)
- `luacheck . -q` → 0 warnings (run `python3 site-src/tools/regen_rc.py` after adding globals)
- `cd FantasyGlassUI && python3 ../tests/smoke.py` → `errors: no errors` twice
- `python3 tests/forever_audit.py` → exit 0
- `python3 tests/secretaudit.py` → `0 lines compared a hidden value`
- `lockaudit` and `pytest` run in Task 9.

### Rulings (what the spec leaves to the builder, and calls made against the code)

**The idea record, registry and job runner**
- **The idea record** (every source produces exactly this; `ns.GoldIdeaValid` enforces it):
  `{ id = string (unique, e.g. "sell:bags", "farm:1436:589"), kind = "sell"|"junk"|"vflip"|"aflip"|"flip"|"farm"|"dungeon"|"gather"|"craft", title = string, oneOff = boolean, perHour = copper (per-hour ideas), total = copper and minutes = number (one-offs), ease = 0..100, safety = 0..100 (before freshness), basis = "guess"|"measured"|"prices", priceDay = yyyymmdd|nil (the oldest auction price used; nil = no auction price), where = "window"|"auction"|"both", go = function(idea)|nil, steps = { { text, map?, x?, y? } }|nil, detail = { list lines for ns:ShowList }|nil, tip = { strings }|nil, map = uiMapID|nil }`.
  - Invalid ideas are dropped and counted in `ns.goldDropped`:
    - no `id` or `title` string
    - a missing, secret, negative or non-finite number (NaN or ±math.huge)
    - a one-off without both `total` and `minutes`
    - `ease` or `safety` outside 0..100
    - an unknown `kind`, `basis` or `where`
  - A one-off with `total < 100` (under 1s) and a per-hour idea with `perHour < 100` are dropped as noise.
- **Registration.** `ns.GoldRegister(key, fn)`. The function is called as `fn(ctx, add)` and calls `add(idea)` for each idea; `add` validates. Registering the same key again replaces the old function. The keys are `"sell"` and `"vflip"` (A), `"farm"` and `"dungeon"` (B), `"gather"` (C), and `"craft"` and `"auction"` (D). The context:

  ```
  ctx = { today, now, level, money, charKey, map, zone, houseKey, house, where = "window"|"auction" }
  ```

  It is built by `ns.GoldContext(where)` from the game, with every value checked with `IsSecret`.
- **Jobs.** `ns.GoldJob(fn, key) -> boolean` queues a coroutine. A key that is already queued or running is refused. `ns:Every(0, "Gold", …)` resumes one job per frame for at most 4 ms. Nothing runs in a fight.
  - A job's error goes into `ns.errors` as `"Gold: " .. err` (at most 60 entries), and the next job runs.
  - Collecting runs one coroutine per source, in turn. One source's error drops that source's ideas only and is noted once a session per key.
- **Value of an item.** `ns.GoldItemValue(id, today) -> copper, from ("ah"|"vendor"|nil), priceDay`:
  - Auction net = `floor(p × 0.95)`, where `p` is `entry.price` when `entry.day == today`, else `ns.AuctionUsual(entry)`, else `entry.price`. The 5% is the house's cut. Deposits are ignored.
  - Vendor = the 11th return of `ns:GetItemInfo(id)`.
  - It returns the larger of the two. `priceDay` is `entry.day` when the auction value wins.
- **Freshness.**
  - `ns.GoldFreshFactor(priceDay, today)`: nil → 1. Otherwise by the price's age in days: ≤ 1 → 1.0, 2–3 → 0.85, 4–7 → 0.6, more than 7 → 0.4.
  - Safety now = `floor(safety × factor + 0.5)`.
  - `ns.GoldFreshText(idea, today)` gives the basis word followed by the price age, for example "guess · prices from 2 days ago":
    - basis words: "guess", "measured", "from prices"
    - price age: "prices from today", "prices from yesterday", "prices from %d days ago", or "vendor prices" when `priceDay` is nil

**Ranking**
- **Ease scores** (base, by kind): junk 100, sell 95, vflip 70, aflip 60, flip 60, craft 50, gather 40, farm 35, dungeon 20. Farm and gather each subtract 10 when `idea.map ~= ctx.map`. The groups' rulings give their other changes. Clamp to 0..100.
- **Safety scores** (base, before freshness):

  | Kind | Guess | Measured | From prices |
  |---|---|---|---|
  | junk | | | 100 |
  | aflip (AH → vendor) | | | 90 |
  | sell | | | 75 |
  | vflip (vendor → AH) | | | 55 |
  | craft | | | 50 |
  | flip (auction flip) | | | 40 |
  | farm | 50 | 80 | |
  | gather | 45 | 80 | |
  | dungeon | 35 | 60 | |

  `aflip` is auction → vendor (A). `flip` is buying at the auction house to list again (D).
- **Sliders and presets.**
  - Weights are `{ gold, ease, safety }`, 0..100 in steps of 10, kept account-wide in `ns.root.goldWeights`. The default is `{100, 0, 0}`.
  - `ns.GOLD_PRESETS = { most = {100,0,0}, easy = {30,70,0}, safe = {30,0,70} }`, named "Most gold", "Easy money" and "Safe".
  - `ns.GoldPresetOf(g, e, s)` returns the matching key, or `"custom"` ("Custom").
  - The preset button cycles Most gold → Easy money → Safe → Most gold. Moving a slider shows the preset name again when the values match one.
- **Score** (per-hour ideas): `g = 100 × perHour / max perHour among them` (0 when that max is 0), then `score = (wg·g + we·ease + ws·safetyNow) / (wg + we + ws)`. When all three weights are 0, `{100,0,0}` is used.
  - Ties go to the higher `perHour`, then the lower `id`.
- **"Right now".** One-offs are sorted by `total` (highest first), then `minutes` (lowest first). The window shows the first 4; "%d more" opens the rest in `ns:ShowList("GoldNow", …)`.
- **Goal** (answer 5). `ns.root.goldChars[key].goal` is in copper (nil = no goal), and `goalName` is nil or `"mount"` / `"epic"`. Named targets fill in the amount: "Mount at 40" = 100g, "Epic mount at 60" = 1000g. The amount stays editable.
  - Remaining = `goal − GetMoney()` (this character).
  - Time to goal in minutes:
    - per-hour idea: `remaining / perHour × 60`
    - one-off: `minutes` when `total ≥ remaining`, else `minutes + (remaining − total) / best × 60`, where `best` is the per-hour of the top-scored per-hour idea; with no such idea, `math.huge` (shown as "—")
  - With a goal set, the two lists merge into one:
    1. First, every idea "within your sliders", sorted by time to goal (ascending). These are all one-offs, plus the per-hour ideas whose score is at least 0.5 × the top score.
    2. Then the rest, by score.
  - Remaining ≤ 0 shows "Goal reached", a full bar, and the two sections without the merge.
- **Words.**
  - Ease ≥ 70 "Easy", 40–69 "Some effort", < 40 "Hard".
  - Safety now ≥ 75 "Sure", 45–74 "Fairly sure", < 45 "A gamble".
  - Time (`ns.GoldTimeText(min)`): < 1 "under a minute", < 60 "%d min", < 48 h "%d h %d min", otherwise "%d days".

**Window layout and entry points**
- **The window.**
  - Frame: `FantasyGlassUIGold`, 600×640, `ns:SetLook(frame, "settings")`, strata `DIALOG`, `ns:KeepPlace(frame, "Gold")`, in `UISpecialFrames`, draggable.
  - Header (0 to −56): title "Ways to make gold" (16, TOPLEFT 18,−18); "Refresh" (80×24) and "X" (28×28) at the top right.
  - "Right now" heading at y −64, then 4 rows of 22 px from y −84.
  - The mix row at y −186: a preset button (130×24), then three sliders 130 wide, "Gold an hour", "Ease" and "Safety", from x 150, 140 apart.
  - The goal row at y −236:
    - "Save for:" with an edit box 90 wide, in gold
    - a cycle button (130) for "Your own amount" / "Mount at 40" / "Epic mount at 60"
    - a bar (200×10)
    - the text "%s of %s" and "about %s with the top idea"
  - "Ways to make gold now" heading at y −286. Below it, a scroll area from −306 to 40 px above the bottom, with rows 40 px tall:
    - line 1: the title on the left; on the right "%s an hour", or "%s in about %s" for a one-off
    - line 2 (faint): ease word · safety word · `GoldFreshText`, plus " · goal in %s" when a goal is set
    - a "Go" button (44×20) on the right when `steps` are given
    - clicking the row opens `detail` in `ns:ShowList("GoldDetail", title, detail)`
  - Footer: `ns.PriceFreshText(ns.PriceHouse(), time())`.
- **Collecting.** The window collects when it opens, when Refresh is clicked, and (while it is shown) 2 s after the last `BAG_UPDATE_DELAYED` or `PLAYER_MONEY`, coalesced. Moving a slider or changing the goal only re-ranks.
  - When the window is opened in a fight, the list says "Waiting for the fight to end." and collects after it.
  - An empty list says "No ideas yet. Scan prices at the auction house, farm or gather a while, or open your professions, and ideas show up here."
- **The auction-house panel.**
  - `FantasyGlassUIGoldAH`, 280×440, docked TOPLEFT to `AuctionHouseFrame` TOPRIGHT (+6, 0), in the settings look.
  - Title "Gold ideas here". It lists the ideas whose `where` is `"auction"` or `"both"`, sorted like "Right now", up to 12 rows of 22 px. Clicking a row opens its detail. The footer is `ns.PriceFreshText`.
  - It is made on the first `AUCTION_HOUSE_SHOW` while unlocked, collects with `ctx.where = "auction"`, and hides on `AUCTION_HOUSE_CLOSED`.
  - While shown, it checks `ns.PriceHouse().scanAt` every 5 s and collects again when the value changes, so `PriceScan.lua` is not changed.
- **Entry points.**
  - **Launcher.** `Launcher.lua` gets two generic hooks, `ns.LauncherTipExtra(tooltip)` (after the Shift line) and `ns.LauncherClickExtra(button) -> true` when handled (first in `Click`). Gold sets them:
    - while unlocked, a tooltip line "Ctrl-click: ways to make gold"
    - with Ctrl held, a click opens the window and returns true
    - while locked, neither does anything.
  - **Guide panel.** Gold wraps `ns.GuideShowPanel` and `ns.GuideCommand`, so `Guide.lua` is not changed. The results:
    - a "Gold" button (48×18) at the panel's BOTTOMRIGHT (−76, 6), made once and shown only while unlocked
    - `/fgui guide gold` opens the window. Any other word, or a locked guide, goes to the original. The usage line does not change.
- **Go seam.** `ns.GoldGo(idea) -> "travel"|"list"|false`:
  - In a fight → false and "Not during a fight."
  - When `ns.GoldTravel` is a function → it is called with the idea → `"travel"`. It stays nil in these batches: real travel and answer 4's pause of the levelling plan come after the planner's folder move.
  - Otherwise it prints "Going there needs the planner's travel, which is not in yet. Here are the steps." and opens `ns:ShowList("GoldSteps", title, lines)` → `"list"`. Each line is "%d. %s" on the left; on the right the zone name (from `C_Map.GetMapInfo`) and "x, y" to one decimal.
- **Vendor-price store** (the reader is a seam; A writes the store):
  - `ns.root.goldVendor = { v = 1, items = { [itemID] = { buy = copper for one, stack = n, limited = n|nil, day = yyyymmdd } } }`
  - `ns.GoldVendorBuy(id) -> buy|nil, day|nil, entry|nil`. Entries older than 180 days read as nil.

**How much history is kept**

| Store | Cap | Forgotten after | Notes |
|---|---|---|---|
| `goldVendor` | 3000 items | 180 days | |
| `goldMobs` | 400 monsters | 90 days | 12 items each, the most looted |
| `goldNodesSeen` | 300 per map | | one node per 10 yards per skill and name |
| `goldNodeItems` | 200 node names | | |
| `goldGather` | | 90 days | per map |
| recipes | 600 per character | | rewritten at each profession open |
| pace | | | halved when loots > 400 |

Forgetting runs as a `GoldJob` when the window first opens in a session.

## Review Focus

- **A brand-new character with no scans, no Questie, no loot and no professions**: both sections and the panel show their empty lines, with no error and no division by zero. → Task 2 test.
- **A fight starts mid-collection, or the window opens in a fight**: no source runs during the fight, and the collection finishes after `PLAYER_REGEN_ENABLED`. → Task 1 test.
- **A source that errors or yields bad ideas** (nil title, NaN, `math.huge`, negative, secret, an unknown kind): only those are dropped, the rest rank, and there is one `ns.errors` line. → Task 1 test.
- **A big store** (3000 vendor items, 400 monsters, 600 recipes) on a slow frame: collection takes several slices and never runs over the budget on a stubbed clock. → Tasks 1 and 3 tests.
- **A goal already reached, a goal of 0, or no per-hour idea at all**: "Goal reached", or a time of "—", never an error or a negative time. → Task 1 test.

---

## File Structure

- **Task 1** (core logic):
  - Create `FantasyGlassUI/Gold.lua`.
  - Create `GoldSell.lua`, `GoldFarm.lua`, `GoldGather.lua` and `GoldCraft.lua` as empty files, each with a one-line header and `local _, ns = ...`.
  - Modify the TOC (the five files after `SellHints.lua`), `tests/smoke.py` (the fences) and `.luacheckrc` (regenerated).
- **Task 2** (window, panel, entry points):
  - `Gold.lua`
  - `FantasyGlassUI/Launcher.lua` (the two hooks)
  - `FantasyGlassUI/Auction.lua` (export `ns.AuctionBagItems = BagItems`, nothing else)
  - `tests/smoke.py` (the seams region)
- **Groups:** A writes `GoldSell.lua`, B `GoldFarm.lua`, C `GoldGather.lua` and D `GoldCraft.lua`. Each also writes its own smoke region and `specs/plans/phrases/gold-<x>.json`.
- **Fences in `tests/smoke.py`**, placed just before `try("Delayed calls"`:
  - `-- gold tests seams: begin` / `end`
  - `-- gold tests A (sell): begin` / `end`
  - `-- gold tests B (farm): begin` / `end`
  - `-- gold tests C (gather): begin` / `end`
  - `-- gold tests D (craft): begin` / `end`
  - `-- gold tests together: begin` / `end` (Task 9 fills it)
  - Task 1 writes all six fence pairs.
- **Layout inside `Gold.lua` and every group file:** a block marked `-- recorders (light; may stay in the main add-on when the folder moves)` comes before the rest. In `Gold.lua`, the entry points sit at the end, under `-- entry points (stay in the main add-on when the folder moves)`.

## Parallel build and merge

1. **The seams.** The controller creates `/home/claude/fantasyglassui-gold2` on the new branch `gold-advisor` from `gold-core`. It runs Task 1, then Task 2, reviews both, makes one fix round, and commits. That commit is `SEAMS`.
2. **The groups.** Four worktrees are made from `SEAMS`: `git worktree add /home/claude/fgui-gold-a -b gold-a SEAMS`, and the same for b, c and d. Each gets one implementer:
   - Group A: Task 3
   - Group B: Tasks 4 and 5
   - Group C: Task 6
   - Group D: Tasks 7 and 8
3. **Review.** Each group gets one review of the whole group (`git diff SEAMS..gold-<x>`). Its implementer then makes one combined fix commit, `"Gold: batch <n> review fixes"`.
4. **Rules for every group:**
   - Touch only your own file, your own smoke region, your own phrase file, and `.luacheckrc` (regenerated only).
   - Never edit `Gold.lua`. A missing seam is reported to the controller, not added.
   - Use another group's function only through a guarded call (`if ns.GoldVendorNote then … end`), and stub it in your own test.
   - Every test restores every global and `ns` field it changes, and unregisters its sources (`ns.GoldRegister(key, nil)`).
5. **Task 9** (controller): `git merge --no-ff gold-a`, then `gold-b`, `gold-c` and `gold-d`.
   - A conflict in `.luacheckrc` is fixed by `regen_rc.py`.
   - Any other conflict means a group wrote outside its region: keep both sides in A–D order and note it in the notes.
   - Then remove the worktrees and delete the branches.

---

### Task 1: The core: ideas, registry, jobs, ranking, value and freshness

**Files:**
- Create: `FantasyGlassUI/Gold.lua`, plus the four empty group files.
- Modify: `FantasyGlassUI/FantasyGlassUI.toc`, `tests/smoke.py` (fences plus the seams region), `.luacheckrc`.

**Interfaces:**
- Consumes: `ns.PriceEntry`, `ns.AuctionUsual`, `ns:GetItemInfo`, `ns.DaysBetween`, `ns.Today`, `ns:Every`, `ns:IsSecret`, `ns:CharKey`, `ns.PriceHouseKey`, `ns.PriceHouse`.
- Produces:
  - Constants: `ns.GOLD_BUDGET_MS = 4`, `ns.GOLD_KINDS` (the 9 kinds), `ns.GOLD_EASE`, `ns.GOLD_SAFETY` (as in the rulings), `ns.GOLD_PRESETS`.
  - Registry: `ns.GoldRegister(key: string, fn: function|nil)`, `ns.GoldSources() -> { [key] = fn }`, `ns.GoldIdeaValid(idea) -> boolean, why`.
  - Jobs: `ns.GoldJob(fn, key) -> boolean`, `ns.GoldYield()`, `ns.GoldBusy() -> boolean`.
  - Collecting: `ns.GoldContext(where) -> ctx`, `ns.GoldCollect(ctx, done: function(ideas))` (as a job), `ns.GoldCollectNow(ctx) -> ideas` (in one go, for tests).
  - Value and freshness: `ns.GoldItemValue(id, today) -> copper, from, priceDay`, `ns.GoldFreshFactor(priceDay, today) -> number`, `ns.GoldFreshText(idea, today) -> string`.
  - Ranking: `ns.GoldPresetOf(g, e, s) -> key`, `ns.GoldWeights() -> g, e, s`, `ns.GoldSetWeight(which: "gold"|"ease"|"safety", v)`, `ns.GoldSetPreset(key)`, `ns.GoldRank(ideas, weights: {g,e,s}, goalLeft: copper|nil, today) -> { now = {…}, ranked = {…}, merged = {…}|nil }`. Each idea gets `.safetyNow`, `.score` (per-hour ideas) and `.toGoal` (with a goal).
  - Words: `ns.GoldEaseWord(n)`, `ns.GoldSafetyWord(n)`, `ns.GoldTimeText(min)`.
  - Goal: `ns.GoldGoal() -> copper|nil, name|nil`, `ns.GoldSetGoal(copper|nil, name|nil)`.
  - Vendor prices: `ns.GoldVendorBuy(id) -> buy, day, entry`.
  - Go: `ns.GoldGo(idea) -> "travel"|"list"|false`.

- [ ] **Step 1: Write the failing test** `try("gold seams: ideas, jobs and ranking", …)` in the seams region. Unlock and stub the clock and combat. Assert:
  - **Validation**
    - `ns.GoldIdeaValid` accepts a full per-hour idea and a full one-off.
    - It rejects, each with a `why`: no title; `perHour = 0/0`; `perHour = math.huge`; `total = -5`; `ease = 120`; `kind = "rob"`; a one-off without minutes; a secret `total` (stub `ns.IsSecret` for that value).
  - **Registry**
    - A source that `add`s 3 good ideas and 2 bad ones gives 3 ideas from `ns.GoldCollectNow`, and `ns.goldDropped == 2`.
    - A second source that `error("boom")`s leaves the first one's 3 ideas, and exactly one `ns.errors` line starts with "Gold: ".
    - `ns.GoldRegister("x", nil)` removes a source.
  - **Jobs**
    - `ns.GoldCollect` with a source that loops 3000 times calling `ns.GoldYield()`, with a stub clock that advances 0.01 ms a call, resumes more than once and calls `done` once.
    - With `InCombatLockdown` true after the first slice: no further progress across 5 frames, then done after `PLAYER_REGEN_ENABLED`.
    - `ns.GoldJob(f, "k")` twice → the second returns false.
  - **Value and freshness**
    - An entry `{ price = 1000, day = today }` with vendor 300 → `GoldItemValue` = 950, `"ah"`, today.
    - Vendor 2000 → 2000, `"vendor"`, nil.
    - `GoldFreshFactor(nil) == 1`; age 1 → 1; 3 → 0.85; 6 → 0.6; 30 → 0.4.
    - `GoldFreshText({ basis = "guess", priceDay = today − 2 }, today) == "guess · prices from 2 days ago"`; with `priceDay = nil` it ends "vendor prices".
  - **Ranking**
    - Per-hour ideas P1 (perHour 10000, ease 20, safety 80) and P2 (5000, 90, 50), and one-offs O1 (total 3000, 5 min) and O2 (total 3000, 2 min).
    - With `{100,0,0}`: `ranked = {P1, P2}`, `now = {O2, O1}`.
    - With `{30,70,0}`: P2 first. `GoldPresetOf(30,70,0) == "easy"`; `(40,60,0) == "custom"`; `(0,0,0)` ranks like most.
    - A priceDay 10 days old makes `safetyNow = floor(80×0.4+0.5) = 32`.
    - Goal left 20000 with `{100,0,0}`:
      - P1 `toGoal = 120`, P2 240
      - O1 `toGoal = 5 + 17000/10000×60 = 107`
      - `merged` order: O2 (104), O1 (107), P1 (120), P2 (240). P2 is in "within your sliders" because 100·g gives it 50 ≥ 0.5×100.
    - Goal left ≤ 0 → `merged == nil`.
    - No per-hour ideas → a one-off below its goal has `toGoal == math.huge`, and `GoldTimeText(math.huge) == "—"`.
  - **Words**
    - `GoldEaseWord(70) == "Easy"`, `(69) == "Some effort"`, `(39) == "Hard"`.
    - `GoldSafetyWord(75) == "Sure"`, `(44) == "A gamble"`.
    - `GoldTimeText(0.5) == "under a minute"`, `(75) == "1 h 15 min"`, `(3000) == "2 days"`.
  - **Saved settings and the vendor reader**
    - `ns.GoldSetWeight("ease", 70)` persists in `ns.root.goldWeights`.
    - `ns.GoldVendorBuy` of an entry 200 days old → nil.
  - **Go**
    - With `ns.GoldTravel` nil, `ns.GoldGo({ title = "T", steps = { { text = "Go", map = 1436, x = 50.04, y = 40 } } }) == "list"`, and the "GoldSteps" list's first line is "1. Go" with "Westfall" (stubbed `C_Map.GetMapInfo`) and "50.0, 40.0" on the right.
    - With `ns.GoldTravel` stubbed → `"travel"`.
    - In combat → false.

  Restore everything.
- [ ] **Step 2: Run the smoke and confirm it fails** (`GoldIdeaValid` is nil).
- [ ] **Step 3: Implement `Gold.lua`'s core**, with the signatures and rulings above. Collection runs each source in its own coroutine inside the job, so a source's error ends only that coroutine.
- [ ] **Step 4: Run the per-task checks and confirm they pass.** Also run `grep -c "ns:NewModule" FantasyGlassUI/Gold*.lua` → 0 for every file.
- [ ] **Step 5: Commit** `"Gold: the core (ideas, sources, sliced jobs, ranking, goal, Go seam)"`.

### Task 2: The window, the auction-house panel and the hidden entry points

**Files:** `FantasyGlassUI/Gold.lua`, `FantasyGlassUI/Launcher.lua`, `FantasyGlassUI/Auction.lua`, `tests/smoke.py` (the seams region), the phrases through `add_tr.py`.

**Interfaces:**
- Consumes: Task 1, `ns:SetLook`, `ns:CreateSlider`, `ns:CreateButton`, `ns:CreateEditBox`, `ns:NewStatusBar`, `ns:ScrollArea`, `ns:ShowList`, `ns.PriceFreshText`, `ns.GuideShowPanel`, `ns.GuideCommand`.
- Produces:
  - `ns:GoldOpen() -> frame|nil` (nil while locked), `ns:GoldRefresh()`, `ns.GoldWindowLines() -> { now = { text rows }, ranked = { text rows } }` (the drawn texts, for tests).
  - The auction panel: `ns:GoldAuctionShow() -> frame|nil`.
  - In Launcher: the hooks `ns.LauncherTipExtra(tooltip)` and `ns.LauncherClickExtra(button) -> boolean`.
  - In Auction: `ns.AuctionBagItems() -> { { id, count, vendor, bound, link, bag, slot } }`.

- [ ] **Step 1: Write the failing test** `try("gold seams: the window, the panel, hidden while locked", …)`:
  - **Locked** (the real `ns.GuideUnlocked`, guide locked):
    - `ns:GoldOpen() == nil`.
    - The launcher tooltip (call `ns.LauncherTipExtra` on a spy tooltip) adds no line.
    - `ns.LauncherClickExtra("LeftButton")` with Ctrl stubbed down → false.
    - `env.SlashCmdList["FANTASYGLASSUI"]("guide gold")` prints "Quest guides are coming soon.".
    - `fireEvent("AUCTION_HOUSE_SHOW")` → `_G.FantasyGlassUIGoldAH == nil`.
    - `ns.seenStrings["Ways to make gold"] == nil`.
    - `_G.FantasyGlassUIGold == nil` after `PLAYER_ENTERING_WORLD`.
  - **Unlocked:**
    - Ctrl-click opens the window, which has `suiLook == "settings"`.
    - With no sources, the ranked list's only row is the "No ideas yet" line, and "Right now" shows "Nothing right now.".
    - The guide panel (`ns:GuideShowPanel()` with a followed guide) has a shown "Gold" button, and clicking it opens the window.
    - `/fgui guide gold` opens it.
  - **With two stub sources** (the four ideas of Task 1):
    - `GoldWindowLines().ranked[1]` contains "an hour" and "guess".
    - `now[1]` contains "in about 2 min".
    - Clicking the preset button gives "Easy money", and P2 is first.
    - Moving the gold slider to 50 shows "Custom".
    - Typing 2 (gold) into "Save for:" with `GetMoney` 0 shows a bar at 0 and every row has " · goal in ".
    - "Epic mount at 60" sets the goal to 10000000.
  - **In a fight:** opening it shows "Waiting for the fight to end.", and the list fills after `PLAYER_REGEN_ENABLED`.
  - **The auction house:** with a stub `AuctionHouseFrame` and an idea with `where = "auction"`, `AUCTION_HOUSE_SHOW` makes the panel show that idea's row. A changed `scanAt` plus a 5 s timer tick collects again (count the source's calls). `AUCTION_HOUSE_CLOSED` hides it.

  Restore everything.
- [ ] **Step 2: Run the smoke and confirm it fails.**
- [ ] **Step 3: Implement** to the layout, collecting and entry-point rulings. Run `add_tr.py` on the new phrases (9 languages) from a scratch JSON file that is not committed.
- [ ] **Step 4: Run the per-task checks and confirm they pass.** Also run `git diff --stat gold-core -- FantasyGlassUI/Guide.lua FantasyGlassUI/Core.lua FantasyGlassUI_Options` → empty.
- [ ] **Step 5: Commit** `"Gold: the window, the auction house panel and the hidden ways in"`. The controller tags this commit as `SEAMS`.

---

### Task 3 (group A, batch 2): Bags and selling, vendor flips

**Files:** `FantasyGlassUI/GoldSell.lua`, the smoke region A, `specs/plans/phrases/gold-a.json`, `.luacheckrc`.

**Interfaces:**
- Consumes:
  - from the seams: `ns.GoldRegister`, `ns.GoldItemValue`, `ns.GoldVendorBuy`, `ns.GoldJob`, `ns.GoldYield`, `ns.AuctionBagItems`
  - from batch 1: `ns.WorthSelling`, `ns.PriceItems`, `ns.PriceEntry`, `ns.SellHintFor`, `ns.AuctionUsual`
  - from the game: `GetMerchantNumItems`, `GetMerchantItemID`, `C_MerchantFrame.GetItemInfo` (`price`, `stackCount`, `numAvailable`, `extendedCost`)
- Produces:
  - `ns.GoldVendorNote(id, info, today) -> boolean`: writes `ns.root.goldVendor` per the rulings.
  - `ns.GoldSellIdeas(ctx, add, bags, items)` (pure, for tests).
  - Sources `"sell"` (bags, junk) and `"vflip"` (the vendor flips both ways).

**Rulings (A)**
- **Recording merchant prices.** On `MERCHANT_SHOW` and `MERCHANT_UPDATE` (debounced 0.5 s, unlocked only), each merchant slot `i` is read: `GetMerchantItemID(i)` and `C_MerchantFrame.GetItemInfo(i)`.
  - Skipped: `extendedCost` true, `price ≤ 0`, or any secret value.
  - Written: `buy = floor(price / max(1, stackCount))`, `stack`, `limited = numAvailable` when it is ≥ 0, otherwise nil, and `day`.
  - At most 3000 entries. When the store is full, the entry with the oldest `day` goes.
- **"Right now: sell your bags"** (kind `sell`, `where = "both"`):
  - `total = Σ floor(w.total × 0.95)` over `ns.WorthSelling(bags, ns.PriceItems(), today)`, and `minutes = min(15, 3 + 0.5 × #list)`.
  - `priceDay` = the oldest `entry.day` used. Basis `prices`.
  - `detail` = one line per item, marked "Sell now" when `ns.SellHintFor(id)` gives `"sell"`.
  - `steps = { { text = "Go to the auction house" } }`.
- **"Vendor your junk"** (kind `junk`, `where = "window"`):
  - Bag items of quality 0 with a vendor price, plus items for which `ns.SellHintFor` gives `"vendor"`.
  - `total = Σ vendor × count`; `minutes = 1` while `MerchantFrame` is shown, otherwise 3. Basis `prices`, `priceDay` nil.
- **Vendor → auction flip** (kind `vflip`, `where = "both"`), one idea per item, with `b = GoldVendorBuy(id)` within 30 days:
  - Needs a usual price `u` with ≥ 3 days of history, and `listed > 0` in the last scan.
  - `profit = floor(u × 0.95) − b`. The idea needs `profit ≥ 100` and `u ≥ 1.3 × b`.
  - `count` = `limited` if set, else `stack` (at least 1). `total = profit × count`, `minutes = 8`.
  - Title: "Buy %s from a vendor, sell at the auction house".
- **Auction → vendor flip** (kind `aflip`, `where = "auction"`):
  - Needs an entry with `day == today` and lowest price `p`, and a vendor sell price `v` with `p ≤ 0.9 × v` and `v − p ≥ 50`.
  - `total = v − p` (one item: only the lowest listing is known), `minutes = 3`.
  - Title: "Buy %s at the auction house, a vendor pays more".
- **Caps:** at most 10 flip ideas, by total. The flip source walks the store with `ns.GoldYield()` every item.

- [ ] **Step 1: Write the failing test** `try("gold A: bags, junk and vendor flips", …)`:
  - **Merchant recording.** A stub merchant with 3 slots:
    - item 2320 (price 10, stack 1)
    - item 4470 (price 40, stack 5, numAvailable 3)
    - a slot with `extendedCost` true

    After `MERCHANT_SHOW` and a 0.5 s timer:
    - `GoldVendorBuy(2320) == 10`
    - `GoldVendorBuy(4470) == 8` with `limited == 3`
    - the extended-cost item is not stored
    - locked → nothing stored
    - a secret price → not stored
  - **Bags.** With fake bags of 2× item 5 (AH today 500, vendor 50) and 1× junk item 6 (quality 0, vendor 30), `GoldSellIdeas` gives:
    - `sell:bags` with total 950 and minutes 3.5
    - `junk` with total 30
  - **Vendor flip.** `goldVendor[2320] = { buy = 10, stack = 20, day = today }` and a price entry for 2320 with usual 200 over 4 days and `listed = 6` give `vflip` with total `(190 − 10) × 20 = 3600`.
  - **Auction flip.** Entry 7 (`price = 40`, `day = today`) with vendor 100 → `aflip` total 60. The same entry with `day = today − 1` → no idea.
  - **Big store.** 3000 vendor entries collect across several slices with the stub clock.
  - **Freshness.** `vflip`'s safety now drops when its price day is 10 days old.

  Restore everything.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run the per-task checks and confirm they pass.**
- [ ] **Step 5: Commit** `"Gold: sell your bags, vendor your junk, vendor flips both ways"`.

---

### Task 4 (group B, batch 3): Monsters worth killing

**Files:** `FantasyGlassUI/GoldFarm.lua`, the smoke region B, `specs/plans/phrases/gold-b.json`, `.luacheckrc`.

**Interfaces:**
- Consumes:
  - from the seams: `ns.GoldRegister`, `ns.GoldItemValue`, `ns.GoldJob`, `ns.GoldYield`
  - from the add-on: `ns.FarmZoneRanking` (Farming.lua, with `ns.root.farmZones` keyed by zone name)
  - Questie, read-only through pcall: `QuestieLoader:ImportModule("QuestieDB")` with `QueryNPCSingle(id, "spawns"|"name"|"minLevel"|"maxLevel")`, `QueryItemSingle(id, "npcDrops")`, `QueryQuestSingle(id, "objectives")`, and `ZoneDB:GetUiMapIdByAreaId`, the same calls `PlannerSource.lua` makes
  - from the game: `GetNumLootItems`, `GetLootSlotType`, `GetLootSlotLink`, `GetLootSlotInfo` (quantity), `GetLootSourceInfo`, `GetMoney`, `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`, `GetRealZoneText`, `GetQuestLogRewardMoney`, `C_QuestLog.GetNumQuestLogEntries`, `C_QuestLog.GetInfo`, `C_QuestLog.IsComplete`
- Produces:
  - `ns.GoldMobNote(npcID, name, level, map, zone, x, y, items: {[id]=count}, copper, now) -> boolean`
  - `ns.GoldMobValue(rec, today) -> copper per loot, priceDay, learned: boolean`
  - `ns.GoldKillDefault(level) -> copper`
  - `ns.GoldKillSeconds(spawnsInZone|nil) -> seconds`
  - `ns.GoldFarmIdeas(ctx, add, mobs, zones, questie)` (pure)
  - The source `"farm"`.

**Rulings (B)** (answer 1)
- **Learning from loot.** On `LOOT_OPENED` (unlocked only, at most `GetNumLootItems()` slots, one pass, no job), each slot's sources (`GetLootSourceInfo` gives guid, quantity pairs) are read.
  - The npcID is the 6th `-`-field of a `"Creature-…"` guid. Other guid types are ignored.
  - With exactly one creature source in the window, coin is `GetMoney()` at `LOOT_CLOSED` minus `GetMoney()` at `LOOT_OPENED` (0 when either is secret).
  - Name and level come from `UnitName("target")` and `UnitLevel("target")` when `UnitGUID("target")` equals the guid. Otherwise they are kept from before, or left nil.
  - Store: `ns.root.goldMobs[npcID] = { name, level, map, zone, x, y, loots, copper, items = { [id] = count }, last = today }`. Caps as in the rulings.
- **Value per loot.**
  - Learned (`loots ≥ 10`): `(copper + Σ count × GoldItemValue(id)) / loots`, and `learned = true`.
  - Otherwise: `ns.GoldKillDefault(level)` = 30 / 150 / 400 / 800 / 1300 / 2000 / 2600 copper for levels ≤ 9 / ≤ 19 / ≤ 29 / ≤ 39 / ≤ 49 / ≤ 59 / 60+. This is vendor trash and cloth by level band, built in, marked guess. A nil level counts as the player's level.
  - **Quest items.** Questie's quest items are added for every incomplete quest in the log: for each item objective `{ itemID, need }` whose `npcDrops` include the monster, add `floor(GetQuestLogRewardMoney(questID) / max(1, need) × 0.5)`. The 0.5 is a guessed drop chance. The idea's `tip` says "Includes the reward of %s.". Quest money that can't be read counts as 0.
- **Kill speed.**
  - Per character, `pace = { loots, secs }`: each creature loot within 120 s of the last adds the gap.
  - With `loots ≥ 20`, the kill time is `clamp(secs / loots, 10, 120)`.
  - Otherwise it is `ns.GoldKillSeconds(spawns)`: 30 s when Questie lists ≥ 30 spawn points in that zone, 40 s for 10–29, 60 s for 1–9, and 40 s with no Questie.
- **Ideas.**
  - The candidates are the learned monsters with `level ≤ player + 2`, plus Questie's droppers of quest items for incomplete log quests (zone = the map with the most spawns, level = `maxLevel`). At most 40, by value per loot.
  - `perHour = floor(3600 / killSeconds × valuePerLoot)`. Kind `farm`; basis `guess`; title "Kill %s in %s".
  - `ease = 35`, +15 when `level ≤ player − 5`, −15 when `level ≥ player + 1`, −10 off-map.
  - `steps`: { "Go to %s" (map), "Kill %s around here" (map, x, y = the recorded loot place, or the densest Questie spawn) }.
  - **Measured** (answer 1, "farming by zone"): for each zone in `ns.FarmZoneRanking(ns.root.farmZones)` with `secs ≥ 600`, one idea `farm:zone:<name>` with `perHour = floor(z.perHour)`, basis `measured`, title "Farm in %s (your own times)".
    - Monster ideas in the same zone become lines in its `detail` and are not separate ideas.
    - The matching is by `zone` name, as Farming.lua keys it.
  - At most 8 farm ideas register, by `perHour`.

- [ ] **Step 1: Write the failing test** `try("gold B: monsters worth killing", …)`:
  - **Loot recording.** Stub a loot window: one source `"Creature-0-1-2-3-589-0000AAAA"` with 2× item 2589 (linen, vendor 13) and money going from 1000 to 1150 across `LOOT_OPENED`/`LOOT_CLOSED` → `goldMobs[589] = { loots = 1, copper = 150, items = { [2589] = 2 } }`. Also:
    - a `"Player-…"` guid → nothing stored
    - two creature sources → items stored, copper 0
    - locked → nothing
  - **The default.** With 9 loots, `GoldMobValue` uses `ns.GoldKillDefault(18) == 150` (`learned == false`). The 10th loot switches it to learned.
  - **Questie.** A fake `QuestieLoader` with quest 100 needing item 900 ×5, dropped by npc 589, and `GetQuestLogRewardMoney(100) = 2000` adds 200 per loot. Questie missing → no error and no quest part.
  - **Kill speed.** 20 loots 30 s apart → `killSeconds == 30`. No pace, 12 Questie spawns → 40.
  - **Measured beats guess.** `farmZones = { Westfall = { { secs = 1200, gold = 5000, value = 5000 } } }` gives a `measured` idea at perHour 30000, and npc 589 (zone "Westfall") shows in its detail, not as an idea.
  - **Pure function.** `ns.GoldFarmIdeas` with 400 mobs finishes across slices.

  Restore everything.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run the per-task checks and confirm they pass.**
- [ ] **Step 5: Commit** `"Gold: monsters worth killing, learned from your loot, measured from your farming"`.

### Task 5 (group B, batch 3): Dungeon drops

**Files:** `GoldFarm.lua`, the smoke region B, `gold-b.json`.

**Interfaces:**
- Consumes: from RunLog.lua, `ns.RunLogged()`, `ns.RunPlaces(log)` and `ns.RunLength(r)` (runs are `{ instance, start, loot = { links of quality ≥ 3 }, kills }`); `ns.root.lootBook` (`[instance][boss] = { kills, items = { [id] = { n, link } } }`, from LootBook.lua); `ns.GoldItemValue`; `ns:GetItemInfo` (bind type, the 14th return).
- Produces: `ns.GoldRunValue(run, today) -> copper, priceDay` and the source `"dungeon"`.

**Rulings (B, dungeons)**
- Both the run log and the loot book are on gold-core (`RunLog.lua`, `LootBook.lua`), so nothing comes from the planner branch.
- **Run value.** Each loot link counts `GoldItemValue`, but an item that binds when picked up (bind type 1) counts only its vendor price.
- **One idea per instance**, from runs in the last 90 days that last at least 300 s:
  - `perHour = floor(Σ value / Σ RunLength × 3600)`
  - basis `measured` with ≥ 2 runs, otherwise `guess`
  - title "Run %s (rare drops)"; ease 20; `where = "window"`
  - `detail`: the instance's loot-book bosses, each with the expected worth of one kill, `Σ (n / kills) × value`, then the items from your runs with their values (this is "what your dungeon loot is worth")
  - `tip`: "Counts rare and better drops only; coin and trash are not in it."
  - `steps = { { text = "Go to %s" } }`
- At most 5 dungeon ideas, by `perHour`.

- [ ] **Step 1: Write the failing test** `try("gold B: dungeon drops", …)`:
  - Two runs of "Deadmines", each 1800 s, with loot worth 5000 and 3000 → perHour `floor(8000 / 3600 × 3600) = 8000`, basis measured.
  - One run → guess.
  - A run of 200 s → ignored.
  - A BoP link with AH price 90000 and vendor 500 → counts 500.
  - A loot-book boss with 4 kills and item ×2 worth 1000 → the detail line shows "500".
  - An empty run log → no ideas, no error.

  Restore everything.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run the per-task checks and confirm they pass.**
- [ ] **Step 5: Commit** `"Gold: which dungeon runs pay best, and what their drops are worth"`.

---

### Task 6 (group C, batch 4): Gathering

**Files:** `FantasyGlassUI/GoldGather.lua`, the smoke region C, `specs/plans/phrases/gold-c.json`, `.luacheckrc`.

**Interfaces:**
- Consumes:
  - from the seams: `ns.GoldRegister`, `ns.GoldItemValue`, `ns.GoldYield`
  - `ns.PlannerWorldPos` (guarded; it exists on gold-core in PlannerTravel.lua)
  - from the game: `UNIT_SPELLCAST_SENT` (unit, target, castGUID, spellID), `UNIT_SPELLCAST_SUCCEEDED`, `LOOT_OPENED` plus `GetLootSlotLink`, `GetProfessions`, `GetProfessionInfo` (skillLevel 3rd, skillLine 7th), `C_Spell.GetSpellInfo`, `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`
- Produces:
  - `ns.GoldRecordNode(map, x, y, name, skill) -> boolean`, with the same shape and rule as the planner's `ns.PlannerRecordNode`
  - `ns.GoldGatherSkill(spellID) -> 182|186|393|nil`
  - `ns.GOLD_GATHER_ZONES`, `ns.GOLD_GATHER_ITEMS`
  - `ns.GoldGatherRoute(nodes) -> order, yards`
  - `ns.GoldGatherIdeas(ctx, add, skills)` (pure)
  - The source `"gather"`

**Rulings (C)** (answer 2)
- **Node memory.** `plannerNodesSeen` exists only on quest-planner (in `PlannerPath.lua`), not on gold-core.
  - C keeps its own account-wide `ns.root.goldNodesSeen[map] = { { name, x, y, skill } }`, which is exactly the planner's shape (one decimal; 10 yards; 300 per map; herbalism 182 and mining 186 only).
  - The gathering spells are the planner's: 2366, 2368, 3570 and 11993 (herbalism); 2575, 2576, 3564 and 10248 (mining); 8613, 8617, 8618 and 10768 (skinning). A spell's name is also matched against the base spells' names.
  - The reader takes the union of `goldNodesSeen` and `plannerNodesSeen` when both exist, so the merge with the planner needs only to fold one into the other (Task 9 notes it).
- **What a node gives.** After a gathering `UNIT_SPELLCAST_SUCCEEDED`, the next `LOOT_OPENED` within 5 s is that node's loot.
  - `goldNodeItems[name] = { n, items = { [id] = count } }`.
  - The same loot adds to `goldGather[map] = { secs, n, items = { [id] = count }, day }`. The `secs` grows by the gap since the last gathering when that gap is ≤ 300 s. Skinning counts here too.
- **The built-in list** (`ns.GOLD_GATHER_ITEMS`): item ID = skill needed.
  - Herbs: Peacebloom 2447 = 1, Silverleaf 765 = 1, Earthroot 2449 = 15, Mageroyal 785 = 50, Briarthorn 2450 = 70, Stranglekelp 3820 = 85, Bruiseweed 2453 = 100, Wild Steelbloom 3355 = 115, Grave Moss 3369 = 120, Kingsblood 3356 = 125, Liferoot 3357 = 150, Fadeleaf 3818 = 160, Goldthorn 3821 = 170, Khadgar's Whisker 3358 = 185, Wintersbite 3819 = 195, Firebloom 4625 = 205, Purple Lotus 8831 = 210, Arthas' Tears 8836 = 220, Sungrass 8838 = 230, Blindweed 8839 = 235, Ghost Mushroom 8845 = 245, Gromsblood 8846 = 250, Golden Sansam 13464 = 260, Dreamfoil 13463 = 270, Mountain Silversage 13465 = 280, Plaguebloom 13466 = 285, Icecap 13467 = 290, Black Lotus 13468 = 300.
  - Ores: Copper 2770 = 1, Tin 2771 = 65, Silver 2775 = 75, Iron 2772 = 125, Gold 2776 = 155, Mithril 3858 = 175, Truesilver 7911 = 230, Thorium 10620 = 245.
- **The zones** (`ns.GOLD_GATHER_ZONES`): uiMapID → skill band.
  - 1–70: 1429, 1411, 1412, 1438, 1426, 1420
  - 1–115: 1436, 1432, 1413, 1439, 1421
  - 50–170: 1433, 1431, 1437, 1440, 1442, 1424
  - 115–230: 1441, 1416, 1417, 1443, 1434
  - 160–260: 1445, 1418, 1435, 1444, 1425, 1446
  - 205–300: 1427, 1447, 1419, 1449, 1448, 1428, 1422
  - 245–300: 1423, 1452, 1451

  A zone fits a skill when `min ≤ skill ≤ max`. Its items are those with `need ≤ skill` and `need` within the band.
- **Value of a node.**
  - Learned (`goldNodeItems[name].n ≥ 3`): `Σ count × GoldItemValue / n`.
  - Otherwise, the built-in average of the zone's items for your skill × 1.5 for herbs, or × 2 for ore.
- **Per hour with a route.** A route needs ≥ 5 recorded nodes of your skill on the map.
  - `GoldGatherRoute` is a nearest-neighbour closed tour. It uses world yards from `ns.PlannerWorldPos`, or with no world position, map-percent distance × 10.
  - Speed is 11.2 yd/s at level ≥ 40, otherwise 7.
  - `loop = yards / speed + n × 5`; `perHour = floor(n × 3600 / max(loop, 300) × 0.6 × nodeValue)`. The 300 s floor is the respawn wait, and the 0.6 is for other gatherers.
  - Title "Gather %s in %s"; basis `guess`. Ease is 40, −10 off-map, −10 when the route is longer than 3000 yd.
  - `steps` = the nodes in tour order, at most 30, "%s" (the node name) at x, y.
- **Without nodes** (a guess, with no route): `perHour = floor(30 × nodeValue)`, title "Try gathering in %s", `steps = { { text = "Go to %s", map } }`.
- **Measured.** `goldGather[map]` with `n ≥ 20` and `secs ≥ 600` gives `perHour = floor(Σ count × GoldItemValue / secs × 3600)` and basis `measured`. It replaces the guess for that map and skill. Skinning ideas are measured only.
- At most 6 gather ideas, by `perHour`.

- [ ] **Step 1: Write the failing test** `try("gold C: gathering", …)`:
  - **Node recording.** `UNIT_SPELLCAST_SENT("player", "Peacebloom", nil, 2366)` at map 1429 (50, 50) records one node; the same spot again does not; locked does not.
  - **Node loot.** `UNIT_SPELLCAST_SUCCEEDED` then `LOOT_OPENED` with 2× item 2447 gives `goldNodeItems.Peacebloom.items[2447] == 2`.
  - **Skill and zone.** `GoldGatherSkill(2575) == 186`. With skill 60 herbalism, Elwynn (1429) fits and Tanaris (1446) does not.
  - **The route.** Nodes (0,0), (10,0), (10,10), (0,10) and (5,5) in map percent (no world position). The tour starts at the first node and breaks ties by the lower index. It gives the order 1, 5, 2, 3, 4 and `yards ≈ 441.4` (to within 1).
  - **Per hour.** Those 5 nodes with a node value of 100 at level 20 → `loop = 441.4 / 7 + 25 ≈ 88`, floored to 300 → `perHour = floor(5 × 3600 / 300 × 0.6 × 100) = 3600`.
  - **Measured.** `goldGather[1429] = { n = 25, secs = 1200, items = { [2447] = 40 } }` with a value of 50 each → measured, perHour 6000.
  - **No nodes.** A fitting zone with no nodes gives "Try gathering in …" with only a "Go to" step.
  - **Both node memories.** With both `plannerNodesSeen` and `goldNodesSeen` set, the nodes of both are used.

  Restore everything.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run the per-task checks and confirm they pass.**
- [ ] **Step 5: Commit** `"Gold: gathering routes from the nodes you have gathered, and where to try next"`.

---

### Task 7 (group D, batch 5): Crafting for profit, with a shopping list

**Files:** `FantasyGlassUI/GoldCraft.lua`, the smoke region D, `specs/plans/phrases/gold-d.json`, `.luacheckrc`.

**Interfaces:**
- Consumes:
  - from the seams: `ns.GoldRegister`, `ns.GoldItemValue`, `ns.GoldVendorBuy`, `ns.GoldJob`, `ns.GoldYield`
  - `ns.PriceEntry`, `ns.AuctionUsual`, `ns.ShoppingLines(reagents, times, have)`, `ns:ItemOwners(id)`
  - from the game: `C_TradeSkillUI.IsTradeSkillReady`, `GetAllRecipeIDs`, `GetRecipeInfo` (`learned`, `name`), `GetRecipeSchematic(id, false)` (`outputItemID`, `quantityMin`, `quantityMax`, `reagentSlotSchematics[i].reagents[1].itemID`, `quantityRequired`, `reagentType`, `required`; the basic-reagent rule from `ns:SelectedRecipe`), `GetBaseProfessionInfo`, `C_Item.GetItemCount(id, true)`, `TRADE_SKILL_SHOW`, `TRADE_SKILL_LIST_UPDATE`
- Produces:
  - `ns.GoldRecipesRead() -> boolean` (queues the job)
  - `ns.GoldCraftMargin(rec, today) -> margin, cost, sale, priceDay | nil, why`
  - `ns.GoldCraftIdeas(ctx, add, recipes)` (pure)
  - The source `"craft"`

**Rulings (D, crafting)**
- **Recording recipes.** On `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE` (debounced 1 s, unlocked, `IsTradeSkillReady()`), a `GoldJob` keyed `"recipes"` walks `GetAllRecipeIDs()`.
  - Each learned recipe with an `outputItemID` becomes `goldChars[key].recipes[recipeID] = { name, out, nMin, nMax, reagents = { { id, need } }, prof = GetBaseProfessionInfo().professionName, day }`.
  - The profession's old entries are replaced. At most 600.
- **Reagent cost.** The cheaper of the auction price and the vendor buy price:
  - auction: today's price, else the usual, else `entry.price`, with no cut (you buy)
  - vendor: `GoldVendorBuy(id)`, through a guarded call (group A writes it)

  A reagent with neither makes the recipe `nil, "unpriced"`.
- **Margin.** `sale = floor(p × 0.95 × (nMin + nMax) / 2)`, from the product's auction price. With no auction price, the recipe is `nil, "no price"`.
  - `margin = sale − cost`. The idea needs `margin ≥ max(50, 0.1 × cost)`.
- **The idea** (kind `craft`, one-off, `where = "both"`, basis `prices`):
  - `count = min(5, max(1, floor(listed / 4)))`, from the product's last-scan `listed`, else 1.
  - `total = margin × count`, `minutes = 5 + count`, `priceDay` = the oldest price day used.
  - Title "Make %d × %s and sell them".
- **The shopping list.**
  - `detail` = the reagent lines from `ns.ShoppingLines(reagents, count, have)`, where `have(id)` gives `C_Item.GetItemCount(id, true)` and the other characters' bags and bank from `ns:ItemOwners`. Each line shows "%d to buy, %s each" with its source ("auction" or "vendor").
  - `steps` = "Buy %d × %s" for each reagent short, then "Make %d × %s", then "Sell them at the auction house".
- With no recipes recorded, the source adds nothing. Task 2's empty line already says "open your professions".
- At most 8 craft ideas, by total.

- [ ] **Step 1: Write the failing test** `try("gold D: crafting for profit", …)`:
  - **Reading recipes.** A stub `C_TradeSkillUI` with recipes 1 (learned; out 2581, qty 1–1, reagents 2589 ×2) and 2 (not learned) → after `TRADE_SKILL_SHOW` and the job, only recipe 1 is stored. In combat, nothing runs.
  - **Margin.** Product AH 300 today, reagent AH 60, vendor buy 50 → `cost = 100`, `sale = 285`, `margin = 185`. `listed = 12` → count 3, total 555, minutes 8.
  - **Unpriced.** A reagent with no price → `nil, "unpriced"`.
  - **Too small.** `margin = 40` → no idea.
  - **The shopping list.** With 1 reagent in the bags and 2 on another character, the detail's first line says 3 to buy (needed 6).
  - **No vendor writer.** Without `ns.GoldVendorBuy` (stubbed nil), the auction cost is used and there is no error.

  Restore everything.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run the per-task checks and confirm they pass.**
- [ ] **Step 5: Commit** `"Gold: crafting for profit from the recipes you know, with a shopping list"`.

### Task 8 (group D, batch 5): Auction flipping

**Files:** `GoldCraft.lua`, the smoke region D, `gold-d.json`.

**Interfaces:**
- Consumes: `ns.PriceItems`, `ns.AuctionUsual`, `ns.GoldItemValue`, `ns.GoldYield`.
- Produces: `ns.GoldFlipIdeas(ctx, add, items, today)` and the source `"auction"`.

**Rulings (D, flips)** (kind `flip`, one-off, `where = "auction"`, basis `prices`, ease 60, safety 40)
- An item qualifies when all of these hold:
  - `entry.day == today` (lowest price `p`)
  - a usual price `u` with ≥ 5 days of history
  - `listed ≥ 3` in the last scan (it sells)
  - item quality ≥ 1
  - `p ≤ 0.6 × u`
  - `profit = floor(u × 0.95) − p ≥ 2000`
- `total = profit` (one item, the lowest listing), `minutes = 3`. Title "Buy %s at %s and list it again near %s". `tip`: "Only the cheapest one is known; buy one and look again."
- At most 10, by profit. The source walks `ns.PriceItems()` with `ns.GoldYield()`.

- [ ] **Step 1: Write the failing test** `try("gold D: auction flips", …)`:
  - Item 8 with a usual price of 10000 over 6 days, `p = 5000` today, and `listed = 4` → total 4500.
  - The same item with `listed = 2`, or `p = 7000`, or 4 days of history, or a price from yesterday → no idea.
  - 3000 items collect across several slices.

  Restore everything.
- [ ] **Step 2: Run it and confirm it fails. Step 3: Implement. Step 4: Run the per-task checks and confirm they pass.**
- [ ] **Step 5: Commit** `"Gold: auction flips, items listed well under their usual price"`.

---

### Task 9: Merge and check everything (controller, on `gold-advisor`)

- [ ] **Step 1: Merge.** Merge `gold-a`, `gold-b`, `gold-c` and `gold-d` with `--no-ff`, as in "Parallel build and merge". If `.luacheckrc` conflicts, regenerate it.
- [ ] **Step 2: Translations.** Run `python3 site-src/tools/add_tr.py specs/plans/phrases/gold-a.json`, then b, c and d. Then `git rm -r specs/plans/phrases`.
- [ ] **Step 3: One integration test** `try("gold together: one window from every source", …)` in the "together" region. With stub data for all four groups:
  - "Right now" holds sell:bags, junk, a vflip, a craft and a flip, ordered by total.
  - The ranked list holds farm, dungeon and gather ideas.
  - The auction panel shows only sell, vflip, aflip, flip and craft.
  - A goal merges the lists.
  - Every row carries its freshness text.
  - Locked again: nothing opens.
- [ ] **Step 4: Run the smoke.** `cd FantasyGlassUI && python3 ../tests/smoke.py` → `errors: no errors` twice.
- [ ] **Step 5: Run the other checks.** `luacheck . -q` → 0 warnings. `python3 tests/forever_audit.py`, `python3 tests/secretaudit.py` and `python3 tests/lockaudit.py` → `(no protected calls in combat)`. `python3 -m pytest tests -q` → all pass.
- [ ] **Step 6: Run the guards.**
  - The no-posting grep from the Global Constraints → empty.
  - `grep -c "ns:NewModule" FantasyGlassUI/Gold*.lua` → 0.
  - `git diff --stat gold-core -- docs wiki site-src README.md CHANGELOG.md RELEASE.md FantasyGlassUI/*.md FantasyGlassUI_Options FantasyGlassUI/Core.lua FantasyGlassUI/Guide.lua` → empty.
  - `grep -rniE "make gold|gold idea|ways to make" README.md CHANGELOG.md RELEASE.md FantasyGlassUI/*.md wiki docs site-src` → nothing.
  - `grep -rn "goldNodesSeen\|goldVendor" FantasyGlassUI --include=*.lua` → only the `Gold*.lua` files.
- [ ] **Step 7: Write the notes and commit them.** Write `specs/plans/2026-11-25-gold-advisor-notes.md` with:
  - the rulings as built, any changed during the build, and any conflict outside a region
  - the in-game checklist:
    - the window and the panel in the settings look, in a normal theme and a high-contrast one
    - Ctrl-click on the launcher, and the guide panel's Gold button
    - `C_MerchantFrame.GetItemInfo` fields on Forever (`price` for a stack, `numAvailable`)
    - `GetLootSourceInfo` guids and the coin read from `GetMoney` around a loot
    - whether `GetQuestLogRewardMoney(questID)` takes a quest ID on Forever
    - the gathering spell IDs and names
    - `C_TradeSkillUI.GetRecipeSchematic` output quantities for a real recipe
    - the panel docked beside the auction house with the scan button
    - frame times while collecting with a full price store
  - the reconciliation of `goldNodesSeen` with the planner's `plannerNodesSeen`, for when the branches meet (fold gold's into the planner's, same shape)
  - the deferred findings

  Commit `"Gold advisor batches 2–5: build notes (in-game checks, rulings, deferred findings)"`.
- [ ] **Step 8: Final review and fixes.** One final whole-branch review (most capable model), then one fix wave. Re-run Steps 4–6 after it.

---

## Later: the folder move (not in these batches)

When every gold batch is done, a separate task moves the advisor into a load-on-demand `FantasyGlassUI_Gold` folder. It will need:
- **The new folder and TOC.** Create `FantasyGlassUI_Gold/FantasyGlassUI_Gold.toc` with `## Interface: 16001`, `## LoadOnDemand: 1`, `## RequiredDeps: FantasyGlassUI` and `## OptionalDeps: Questie, FantasyGlassUI_Planner`. Move the five `Gold*.lua` files into it, except the blocks marked "stay in the main add-on".
- **What stays in the main add-on:**
  - The entry points.
  - A `ns:LoadGold()` loader modelled on `ns:LoadOptions` (enable the folder when it is DISABLED, warn once in 10 s). Stubs for `GoldOpen` and `GoldAuctionShow` hand the call on, as `ns.optionsStubs` do.
  - The recorders: merchant prices, loot, gathering and recipes. They must keep recording while the folder isn't loaded. Either they move into the main add-on as one small file, or the folder loads at login for unlocked players. That choice belongs to the move.
- **Saved data.** It stays in `ns.root` (`FantasyGlassUIDB`). Nothing to migrate.
- **Tests.** `tests/smoke.py`, `secretaudit.py` and `lockaudit.py` must load the new TOC as they load the options folder (`optionFiles`). `forever_audit.py` and `.luacheckrc` cover the new folder too.
- **Release.** The packaging and release steps (RELEASE.md) must ship the folder. Phrases stay in `FantasyGlassUI_Locales`.
- **The planner.** If the planner has moved into its own folder by then, `ns.PlannerWorldPos` may be missing until it loads. Gathering already falls back to map-percent distances. `ns.GoldTravel` gets wired to the planner's travel then (answer 4).
