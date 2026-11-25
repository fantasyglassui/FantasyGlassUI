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
