# Batch 1 (prices for everyone): rulings made while building

Calls the implementer made where the plan was silent or could be read two ways. Each fits the spec's
Prices section, the public-early exception and answer 3.

## Task 1: the price store

- Ruling (amended in the review fixes): the one-time migration runs on the first `AUCTION_HOUSE_SHOW` that has a key, not at login. The 60-day forgetting runs from `ns.PricesBegin()` at login (called by both `auctionMemory` and `auctionScan`), on the current house only, in slices — the old account-wide prices go to the house where the player actually trades, not to whichever alt logs in first; the slices keep a big store from costing a long login.
- Ruling: `ns.PricesStart(root, key, today)` is the pure form (migrate, then forget in that house at once) that the tests call; `ns.PricesBegin()` is its once-a-session wrapper on `ns.root` — the plan's "Old characters' odd entries" review point needs a start that can be run on a test root.
- Ruling: an old entry moves only when its key is a number and its `price` and `day` are numbers; its `hist` keeps only number-to-number pairs — an entry that is not a table, has no `day`, or has a string price (the plan's review focus) is skipped without an error, and a string inside `hist` would otherwise break `AuctionHistoryAdd`'s `<` later.
- Ruling (amended): when the house already has the item, the later `day` gives `price` and `day`, and the two histories are merged, keeping the lower price each day and at most 14 days; every valid old entry counts as moved — the plan's "later day wins" would otherwise throw a usual price away.
- Ruling: `ns.PriceFreshText(house, now)` counts days from `date("%Y%m%d", scanAt)` against `date("%Y%m%d", now)` (the same day as `ns.Today()` in the game), and falls back to whole 24-hour periods when the date can't be read — this keeps `now` meaningful and the function testable where `date` is a stand-in.
- Ruling: the self-check's "Auction prices" line gains "prices kept here: n" (the plan says Check.lua line ~229 counts `ns.PriceItems()`; that line had no count before).

## Task 2: Scan prices

- Ruling: `auctionScan`'s start calls `ns.PricesBegin()` too — the scan writes into the store, so the old prices must already be in it even with the tooltip prices switched off.
- Ruling: a bid-only item the house didn't know yet gets an entry with `listed`, `listedDay` and `day = today` but no `price` — without a `day`, `AuctionForget` would drop it at the next start, and the hints would then read it as "nobody lists it". Every reader already checks that `price` is a number.
- Ruling: a row whose `GetReplicateItemInfo` call raises an error goes on the retry list like a row with no readable `itemID`; a row with any hidden value (count, buyout or itemID) is skipped and never retried — the plan says a secret value "is skipped", and reading it again would give the same hidden value.
- Ruling: a fight pauses the read both on `PLAYER_REGEN_DISABLED` and when a slice finds `InCombatLockdown()`; only `PLAYER_REGEN_ENABLED` resumes it — the plan's "pauses and resumes on PLAYER_REGEN_ENABLED".
- Ruling: a slice reads 25 rows between clock checks (stopping at 4 ms), or 200 rows with no clock; the 0.5 s gap before each retry pass uses `ns:After`, and the retry pass is sliced the same way — a large list of unloaded items must not freeze a frame either.
- Ruling: rows still unread after the retries are counted in `ns.priceScanState` ("last scan: n items, m rows unread"), shown on the self-check's auction line — the plan says they are "dropped and counted" but names no place.
- Ruling: the button sits at `TOPRIGHT -186, -30` of `AuctionHouseFrame`, 6 px left of Worth selling (`-60`, 120 wide), and stays there when the helper is off.

## Task 3: Sell now, Hold, Vendor it

- Ruling: `ns.SellHint` returns a third value for "vendor", `"pays"` or `"unlisted"`, which picks the tooltip's line ("a vendor pays about as much" or "nobody lists it here") — the plan has two Vendor it lines but one kind.
- Ruling: `ns.SellHintFor(id, bound)` counts an item as bound when the bag slot or the tooltip says so, or when its bind type is 1 (binds when picked up), 4 (quest item), 7 or 8 (bound to the account) — such items can never be sold at the auction house.
- Ruling: rule 4's "`u > vendor × 1.15`" applies only to Hold, as written; Sell needs `u > 0` and at least 3 days of history. Percentages are rounded to the nearest whole number.
- Ruling: the tooltip line's right side is `ns.AuctionSeenText` when the entry was never listed by a scan (`listedDay` unset: browsed only), otherwise `ns.PriceFreshText` of the house — the plan's "for browsed-only prices the existing AuctionSeenText".
- Ruling: the bag marker sits at `BOTTOMLEFT 2, 2`, and is hidden when the junk coin shows (as the plan says) and also when the green upgrade arrow shows, which uses the same corner — gear better than what you wear is not for selling, and the tooltip still gives the hint.
- Ruling (superseded in the review fixes, see below): the tooltip line was first hooked by the `sellHints` module on its own; it now comes from the one shared hook, after the price lines.

## Review fixes (final whole-branch review, coordinator's rulings)

- Ruling: **the plan's rule 2 is amended** — "vendor" when `vendor > 0`, the item's quality is 2 (uncommon) or lower, and `p ≤ vendor × 1.15`. An item whose quality isn't known yet gets no Vendor it. A rare or epic near a vendor's price gets no hint (it may still get Hold or Sell now from rule 4) — one dumped listing must never tell a player to vendor an epic.
- Ruling: `ns.PriceHouseKey` is nil unless the faction is exactly "Alliance" or "Horde": a neutral character (a pandaren before choosing) notes nothing, reads nothing and migrates nothing. The key is cached for the session and let go on `PLAYER_LOGIN`, `NEUTRAL_FACTION_SELECT_RESULT` and the player's `UNIT_FACTION`; `ns.PriceHouseKeyReset()` lets the tests do the same.
- Ruling: connected realms are a known limit — `GetAutoCompleteRealms` is not in the Forever dump, so each realm of a connected group keeps its own store. Nothing is merged.
- Ruling: the scan's write is sliced. When the read is done, the finished entries are built beside the store (`staged`, copies with their own history) under the same 4 ms / 200-a-frame budget. Then one pass assigns them into the house and, for a full scan, sets `listed = 0` on what it didn't find. A price noted while the entries were being built (it differs from the one the entry was built from) is kept when it is lower.
- Ruling: rows skipped for a hidden value are counted. A scan that read 0 items is a failed scan (amended in the re-review fixes: whatever the house size, where the first fix wave said "into a house that held more than 50"): nothing is written, and the message is "The scan came back empty: try again later." Unreadable rows are the hidden ones plus those still missing after the retries. Missed items are marked `listed = 0`, and the house gets `listedAt`, only when these are 1% of all rows or fewer. Otherwise the prices, counts and `scanAt` are written, but nothing is said about what nobody lists. Rule 3 reads `listedAt`, not `scanAt`, as its scan day.
- Ruling: `PriceNote` stores `seenDay`. Rule 3 ("nobody lists it") is skipped when `seenDay` is on or after the full scan's day — browsing still never changes `listed`.
- Ruling: the tooltip finds out whether the item is bound from `data.guid` (`C_Item.GetItemLocation`, then `C_Item.IsBound`, both in pcall), falling back to a line whose text is `ITEM_SOULBOUND`, `ITEM_ACCOUNTBOUND` or `ITEM_BNETACCOUNTBOUND`. Bind types 7 and 8 count as bound too.
- Ruling: one tooltip hook, `ns.PriceTooltip`, put in place by whichever of `auctionMemory` and `sellHints` starts. It draws the price lines when `auctionMemory` is on, then the hint when `sellHints` is on.
- Ruling: the scan button reads "Waiting for the list…" until the list arrives and "Paused for combat" during a fight, and is 150 wide to fit them. The feature texts use the hint names Sell now, Hold and Vendor it everywhere. The sellHints text names the bag window's coloured square and says "nobody lists it" is for common and uncommon items only. The auctionMemory text says "saw or scanned". The replaced phrases were taken out of Locales.lua.

## Re-review fixes

- Ruling: before the one-time move, `ns.PriceItems` and `ns.PriceEntry` read the old `ns.root.auctionSeen`, read-only. This applies only while a key exists and `prices.migrated` is not set, and `ns.PriceEntry` skips odd entries. `ns.PriceNote` still writes only into the house. Moving the migration to the first auction house visit must not hide the prices players already had from login.
- Ruling: an empty reply (no item read) is never a scan. Nothing is written, `scanAt` doesn't move, and the message is "The scan came back empty: try again later." `lastScan` stays set, because the server counts the call.
- Ruling: a price browsed during the write is merged at commit. The day's low always goes into the history (the lower wins). The price is taken when it changed since the entry was built and is lower. An earlier browse that the scan already saw does not override the scan's lowest.
- Ruling: the Prices event frame returns at once in safe mode (`ns.safeMode`, as VendorSummary checks it). The sliced login cleaning runs from a frame that is shown only while there is cleaning to do.
- Ruling: the right side of "Vendor it: nobody lists it here" is the freshness of `listedAt`, the last full scan.
