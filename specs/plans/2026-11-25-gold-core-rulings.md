# Batch 1 (prices for everyone): rulings made while building

Calls the implementer made where the plan was silent or could be read two ways. Each fits the spec's
Prices section, the public-early exception and answer 3.

## Task 1: the price store

- Ruling: migration and the 60-day forgetting run from `ns.PricesBegin()`, once a session, called from `auctionMemory`'s start as the plan says, and from the start of any later module that keeps prices — so a player who turned the tooltip prices off still gets the old prices moved in, and the forgetting still keeps the store from growing.
- Ruling: `ns.PricesStart(root, key, today)` is the pure form (migrate, then forget in every house) that the tests call; `ns.PricesBegin()` is its once-a-session wrapper on `ns.root` — the plan's "Old characters' odd entries" review point needs a start that can be run on a test root.
- Ruling: an old entry moves only when its key is a number and its `price` and `day` are numbers; its `hist` keeps only number-to-number pairs — an entry that is not a table, has no `day`, or has a string price (the plan's review focus) is skipped without an error, and a string inside `hist` would otherwise break `AuctionHistoryAdd`'s `<` later.
- Ruling: `PricesMigrate` returns how many entries were written into the house; an old entry that loses to a later one already in the house is not counted — "how many entries moved".
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

