# Gold advisor, batches 2–5: build notes

The hidden advisor ("Ways to make gold") as merged on `gold-advisor`: the seams (Gold.lua), then group A
(GoldSell.lua), B (GoldFarm.lua), C (GoldGather.lua) and D (GoldCraft.lua), then `main` with the 12.4.0
release. Everything stays behind `ns:GuideUnlocked()`, and nothing about it is in any public text.

## What was merged

- `gold-a` (e29a717), `gold-b` (30a860f), `gold-c` (3d14f59) and `gold-d` (51b39a2), each with `--no-ff`. None of them conflicted in git.
- `main` (e3de6e1, the 12.4.0 release). One conflict: `FantasyGlassUI_Locales/Locales.lua`, where the seams' phrases and the release's phrases were added at the same place in all 8 tables. Both sides were kept; no key is in a table twice.
- The phrase files `specs/plans/phrases/gold-a…d.json` were applied with `add_tr.py` (22, 21, 10 and 17 phrases) and removed. Three phrases were in two files ("Go to %s" in B and C, "Sell them at the auction house" and "Listed in the last scan" in A and D). The first file's wording was kept. "Usual price (%d days)" was already in the tables. Every `ns:Tr("…")` literal in the five Gold files is in every table.

## Conflicts outside a region (found after the merge, fixed in the merge-fix commit)

These did not show up as git conflicts. They broke the merged smoke or the rules.

1. **`ns.GoldFlipIdeas` was defined twice.** Group A named its vendor-flip function `ns.GoldFlipIdeas(ctx, add, items)`. The plan gives that name to group D (`ns.GoldFlipIdeas(ctx, add, items, today)`, the auction flips). GoldCraft.lua loads last, so A's `"vflip"` source and A's tests were calling D's function. **Fix:** A's function is now `ns.GoldVendorFlipIdeas`, in GoldSell.lua and in smoke region A. D keeps the plan's name.
2. **The recorders were timed in `/fgui perf` while locked.** The seams' review fix (2400a93, "quiet while locked") came after the groups had branched. Each group's recorder was a `ns:Guard("Gold…")` handler, so while locked a merchant, loot, cast or profession event still made rows named "Gold", "Gold loot", "Gold gather" and "Gold recipes" in `/fgui perf`. That would name the hidden feature. It also failed the seams test, because the harness fires every event at every handler. **Fix:** in all four group files, a plain handler checks `Unlocked()` first and only then calls the guarded one, as Gold.lua's auction-house frame does. The integration test now fires every recorder event while locked with `/fgui perf` on, and checks that no Gold label is timed.
3. **The gathering spell ids were in two places.** Group B copied group C's 12 skinning, herb and ore ids into GoldFarm.lua. **Fix:** GoldGather.lua owns the one table and exports it as `ns.GOLD_GATHER_SPELLS`. GoldFarm.lua's `NOT_A_KILL` keeps only Pick Pocket (921) and reads gathering through `ns.GoldGatherSkill`, at the time of the cast, so load order does not matter. A new step in smoke region B checks that a mining cast (10248) is skipped. It also checks that, with `ns.GoldGatherSkill` stubbed to know nothing, the same loot window counts as a kill, so the farm has no copy of its own.

So smoke regions A and B were also changed by the merge fixes, for items 1 and 3.

## Rulings as built

Every ruling is in the group reports (`.superpowers/sdd/2026-11-25-gold-advisor/task-*-report.md`). These are the ones that change the plan or that a player can notice.

**Changed during the build**
- **Named goals.** These are "Riding at 40" (120g, or 100g for Paladins and Warlocks) and "Epic riding at 60" (1000g), in `ns.GOLD_GOALS`. They replace the plan's "Mount at 40" at 100g. This was the coordinator's ruling.
- **Gathering time.** Each gathering adds 30 s, plus the gap since the last gathering on the same map in this session, when that gap is 300 s or less. A measured map is labelled herbs or ore by its larger share of listed items. A map with no listed herbs or ores is labelled skinning. These are the coordinator's rulings.
- **The auction → vendor flip's floor** is 100c, as the core's noise floor, not the brief's 50c.
- **The window shows only "window" and "both" ideas.** Auction-only ideas (`aflip`, `flip`) show only on the panel. So the integration test checks the flip on the panel, not in the window's "Right now" (see below).
- **Sources added beyond the plan:**
  - the bank, from Storage's saved list, as `sell:bank` and `sell:bankjunk`
  - Questie spawn loops for monsters
  - quest money, capped at what the quests still pay

**As built (short)**
- Ideas: a duplicate `id` keeps the first. Sources run in sorted key order. A source's error drops that source's ideas, and is noted once a session as `"Gold: <key>: <err>"`, never printed.
- Value: a tie between auction and vendor goes to the vendor. Sales and flips are worked out in whole copper.
- Farming:
  - It records nothing in a group, nothing after Pick Pocket or a gathering cast, nothing from a living target, and never the same corpse twice.
  - Monsters in an instance are never farm ideas.
  - The pace is halved when loots go over 400.
- Gathering: the node rule and node shape are the same as the planner's. With no world position, no node is recorded. `ns.db.plannerGather == false` stops node recording.
- Crafting:
  - Only your own profession window is read.
  - A recipe with a slot that cannot be read is "unpriced".
  - The other characters' counts are read in slices from `ns.root.inventory`, never through `ns:ItemOwners`.
- Auction flips: they need today's price, a listing count no more than 1 day old, and at least 4 of the last 14 days before today. The price must be at most 0.6 × the median, and the quality must be known. A flip reads "A gamble" and has no Go button.

## The integration test

`try("gold together: one window from every source", …)`, in the "together" region. It sets up one world of stub data and runs all seven real sources (`sell`, `vflip`, `farm`, `dungeon`, `gather`, `craft`, `auction`):
- bags and junk
- vendor and auction prices
- a measured farming zone
- two dungeon runs
- a measured gathering map
- a known recipe with cloth on an alt
- a listing well under its usual price

It checks the following:
- **Right now** holds `vflip:2320`, `sell:junk`, `sell:bags` and `craft:1`, ordered by total. It shows four rows, with no "more".
  - The flip (`flip:8`) is auction-only, so by the window ruling it ranks among the panel's one-offs instead. This is the one deviation from the brief's wording, and it is deliberate.
- **The ranked list** holds the farm, dungeon and gather ideas, each "an hour", best first.
- **The auction panel** shows exactly `flip`, `vflip`, `sell`, `craft` and `aflip`, sorted like Right now. Junk, farm, dungeon and gather never reach it.
- **Freshness.** Every window row carries its `GoldFreshText`. Every panel row's tooltip carries it too, because the panel shows the words there. The texts are checked: "from prices · prices from today", "from prices · vendor prices" and "measured…".
- **A goal** (50g) merges the two lists into one. Right now points to it. All seven ideas are in the one list, each with its " · goal in" and its freshness.
- **Locked again**, nothing opens:
  - not the window
  - not Ctrl-click
  - not the launcher line
  - not the panel on `AUCTION_HOUSE_SHOW` or `ns:GoldAuctionShow`
- **No Gold label in `/fgui perf`** while locked, from any recorder event.
- Everything it changes is restored, and the real sources are registered again.

## Node memories: the fold for when the branches meet

`ns.root.goldNodesSeen` (GoldGather.lua) and the planner's `ns.root.plannerNodesSeen` (PlannerPath.lua, on `quest-planner`) have the same shape. Both are account-wide and keyed by uiMapID:

```
[map] = { { name = string, x = number (map %, 1 decimal), y = number, skill = 182|186 }, ... }
```

They follow the same rule: one node per 10 world yards (`ns.PLANNER_NODE_YARDS`) per name and skill, at most 300 per map, and herbs and ore only.

**The fold is one step**, run once where both are loaded (at login, or when the planner's folder loads):

```lua
local gold = ns.root.goldNodesSeen
if type(gold) == "table" and type(ns.PlannerRecordNode) == "function" then
    for map, list in pairs(gold) do
        for _, n in ipairs(list) do ns.PlannerRecordNode(map, n.x, n.y, n.name, n.skill) end   -- (its 10-yard rule and cap)
    end
    ns.root.goldNodesSeen = nil
end
```

After the fold:
- `ns.GoldRecordNode` can call `ns.PlannerRecordNode`, or simply stop recording.
- The gather reader's union of both memories (`Stores()` in GoldGather.lua) can read only `plannerNodesSeen`. It already works with `goldNodesSeen` nil.
- `goldNodeItems` (what each node name gave) stays the advisor's own, so it does not fold.

## Deferred findings

- **`/fgui shop` and other characters' items.** Group D found that `ns:ShowShopping` (Economy.lua) passed a number to `ns:ItemOwners`, which matched only `"item:N"` links, so it never counted alts. **12.4.0 fixed this** in Storage.lua: a whole-number id is taken as `"item:N"`, and smoke's "Item counts" test covers it. GoldCraft still reads `ns.root.inventory` directly in slices by its own ruling, so that it never builds the index inside a job. No change is needed.
- **The bank is a snapshot (A).** An item moved from the bank to the bags since the last bank visit can be counted twice. This is capped by `C_Item.GetItemCount(id, true) − C_Item.GetItemCount(id)` when both are readable.
- **Guesses to tune in game:**
  - B's default copper-a-loot bands
  - C's zone bands and item skills
  - the riding costs in `ns.GOLD_GOALS`
- **Korean and Chinese "%s in about %s"** put the time in brackets after the amount. Lua 5.1 has no positional format arguments.
- **`steps[i].text`** is not checked by `GoldIdeaValid`. It is checked in `GoldGo`, which is enough.
- **`ns.goldTest`** (the tests' reset) ships in the add-on. It is harmless.
- **Stale pending state.** A recorder's pending loot or gathering state, set while unlocked, can outlive a lock that happens in the middle of a loot window. It is cleared at the next unlocked event. This is harmless.
- **Smoke runtime.** The full smoke takes about 7–9 minutes a run on this machine.
- **Clean-up.** The worktrees `/home/claude/fgui-gold-a…d` and the branches `gold-a…d` are still there. The plan's step 5 removes them after the final review.

## In-game checklist

**The window and the panel**
- [ ] The window and the auction-house panel in the settings look, in a normal theme and in a high-contrast one. Check:
  - the rows' faint second line
  - the sliders
  - the goal bar
  - the Starcut corner
- [ ] The panel docked beside the auction house (TOPRIGHT +6), with the Scan prices button, and no overlap with the Browse tab.
- [ ] Frame times while collecting with a full price store (thousands of items): no hitch over a frame or two. Each slice is at most 4 ms in `/fgui perf` while unlocked.
- [ ] While locked, `/fgui perf` lists no Gold, Gold loot, Gold gather or Gold recipes row after visiting a merchant, looting, gathering and opening a profession.

**The ways in**
- [ ] Ctrl-click on the launcher opens the window, and the tooltip says "Ctrl-click: ways to make gold" only while unlocked.
- [ ] The guide panel's Gold button (BOTTOMRIGHT −76, 6) opens the window, and `/fgui guide gold` does too.
- [ ] While locked: none of these, and `/fgui guide gold` gives the usual answer.

**Merchants (A)**
- [ ] `C_MerchantFrame.GetItemInfo` on Forever:
  - `price` is for the whole stack
  - `stackCount`
  - `numAvailable` is −1 for unlimited stock
  - `extendedCost` / `hasExtendedCost` for token items
- [ ] `GetMerchantItemCostInfo(i)` is above 0 for a token item.
- [ ] Riding and mount costs, to update `ns.GOLD_GOALS` if needed.

**Loot and farming (B)**
- [ ] `GetLootSourceInfo` returns creature guids in the form `Creature-0-…-npcID-…`, with per-source quantities, and the coin on the money slot.
- [ ] The coin read from `GetMoney` around a loot (LOOT_OPENED → LOOT_CLOSED) for a single creature.
- [ ] `GetQuestLogRewardMoney(questID)` takes a quest ID on Forever, and `C_QuestLog.GetQuestObjectives` gives `numRequired`.
- [ ] `Questie.API.isReady` exists on the Questie build there, and the spawn loops match the map.
- [ ] Pick Pocket, then the corpse loot: only the corpse counts.

**Gathering (C)**
- [ ] The gathering spell IDs and names: herbs 2366/2368/3570/11993, mining 2575/2576/3564/10248, skinning 8613/8617/8618/10768. A rank not listed is still found by its name.
- [ ] Gather one herb and one ore: one node is recorded for each, and the loot lands under the node's name.
- [ ] Skin a beast: the loot counts in `goldGather` for the map, not in `goldNodeItems`, and the loot window is not counted as a kill.
- [ ] `GetLootSlotInfo`'s 3rd return is the stack count.
- [ ] `UNIT_SPELLCAST_SUCCEEDED` arrives before `LOOT_OPENED`. Otherwise no loot is recorded under the node's name, and nothing shows that it failed.

**Crafting and flips (D)**
- [ ] `C_TradeSkillUI.GetRecipeSchematic` for a real recipe:
  - `quantityMin` and `quantityMax`
  - `reagentSlotSchematics` with `quantityRequired`, `reagentType` and `required`
  - `outputItemID`
- [ ] A linked profession, a guild's or an NPC's crafting is not read.
- [ ] `/fgui shop` now counts what your other characters hold (the 12.4.0 fix).
- [ ] An auction flip's tips and detail make sense on a live auction house.
