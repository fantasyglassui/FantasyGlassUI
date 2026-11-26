# Batch 1 (prices for everyone): notes

The public part of batch 1, for a 12.x update: a price store per auction house, a **Scan prices** button
on the auction house, and **Sell now / Hold / Vendor it** in item tooltips and on the bag window.
Nothing in it mentions the advisor or the planner, and nothing goes into a `FantasyGlassUI_Gold` folder.
Release texts (version, both changelogs, RELEASE.md, site news, the wiki) come with the release, after the
player says yes.

## What was built

- **FantasyGlassUI/Prices.lua: the store.**
  - `ns.root.prices` keeps one house per `"Realm|Faction"`. Each entry is `{ price, day, hist, listed, listedDay, seenDay }`.
  - The accessors: `ns.PriceHouseKey`, `ns.PriceHouse`, `ns.PriceItems`, `ns.PriceEntry`, `ns.PriceNote` and `ns.PriceFreshText`.
  - Migration: the old `auctionSeen` moves in once, on the first opening of an auction house. Odd entries are skipped. When the house already has an item, the histories are merged.
  - At login, prices more than 60 days old are let go, in slices, for the current house only.
  - The one item tooltip hook, `ns.PriceTooltip`, draws the price lines, then the hint.
  - Every reader goes through the accessors: Economy, Auction.lua, Farming.lua and Check.lua. `auctionSeen` is now named only in Prices.lua.
- **FantasyGlassUI/PriceScan.lua (`auctionScan`, on by default): Scan prices.**
  - The button sits on the auction house, left of Worth selling. It reads "Scan prices", then "Waiting for the list…", "Reading n%", "Paused for combat", and "Scan in m:ss" while it waits for the next allowed scan.
  - `C_AuctionHouse.ReplicateItems` is called once per 15 minutes, a limit shared by the whole account.
  - The list is read in slices of 4 ms (200 rows with no clock), never in a fight. Rows not loaded yet are read again up to 3 times, 0.5 s apart.
  - The finished entries are then built in slices and put into the store in one short pass.
  - It never posts, buys or bids.
- **FantasyGlassUI/SellHints.lua (`sellHints`, on by default): the hints.**
  - `ns.SellHint`, `ns.SellHintFor` and `ns.SellHintLine` give the hint and its tooltip line.
  - The tooltip line is coloured, and says how fresh the prices are.
  - On the bag window, a 10×10 square: green for Sell now, amber for Hold, grey for Vendor it. It is hidden under the junk coin and the upgrade arrow.
- **Settings**: both features are in Bags and items › Auction and trade and in the "Collecting and crafting" setup choice. They are listed in the feature list, with every phrase in all 9 languages.

## Rulings

Every ruling is in `2026-11-25-gold-core-rulings.md`. The ones a player can notice:

- **Neutral auction houses.** The Forever API can't tell that a neutral auction house is open, so a neutral one shares its faction's prices. A neutral *character* (a pandaren before choosing a faction) has no house at all: it notes nothing, reads nothing, and the one-time migration waits for a character of Alliance or Horde.
- **Where the old prices go.** They move into the house where the player first opens an auction house after the update, not into whichever character logs in first.
- **Connected realms (a known limit).** `GetAutoCompleteRealms` is not in the Forever dump, so the add-on can't tell which realms share an auction house. Each realm of a connected group keeps its own prices, and two characters there build separate stores. Merging them would need a way to read the connected realms.
- **How much of a scan must be read.** A row with a hidden value is skipped and counted. These thresholds apply:
  - A scan that read 0 items into a house that held more than 50 is a failed scan. Nothing is written, and the message is "The scan came back empty: try again later."
  - "Nobody lists it" is only learned from a scan where the unreadable rows (hidden, plus those still missing after the retries) are 1% of all rows or fewer. Only that scan sets `listed = 0` on what it didn't find, and only that scan is the "scan day" for Vendor it: nobody lists it.
  - A less complete scan still writes its prices and counts.
- **Vendor it.** It is never given for rare or better. Both reasons need quality 2 or lower: a vendor pays about as much, and nobody lists it. That amends the plan's rule 2, at the coordinator's call. It is also never given for a bound item: soulbound (from the item's bag place or its tooltip line), bind on pick-up, quest, or account-bound (bind types 7 and 8).
- **Browsing.** Prices seen while browsing top up the store, but never change the listed count. An item seen listed on or after the scan day is no longer "nobody lists it".

## Fixed after the final review

- **Prices before the first auction house visit (N1).** Until the old prices move in, `ns.PriceItems` and `ns.PriceEntry` read the old account-wide `auctionSeen` as this house's, read-only (odd entries skipped). They do this only while a key exists and `migrated` isn't set. Tooltips, Farming totals and the saved zone values keep their auction prices from the first login after the update. New prices still go only into the house.
- **A price browsed while a scan's entries are being built (N2).** It is kept: the day's low in the history always, and the price when it changed since the entry was built and is lower.
- **An empty reply (N3).** It is never a scan, whatever the house size. Nothing is written and `scanAt` doesn't move. The message is "The scan came back empty: try again later." `lastScan` is still set, because the server's cooldown applies.
- **Safe mode (N4).** The Prices event frame does nothing in safe mode. The login cleaning runs from a frame that is shown only while there is cleaning to do.
- **Freshness of "nobody lists it" (N6).** The line says how old the last full scan is (`listedAt`), not the last scan.

## In-game checklist

- [ ] Scan prices on a live auction house:
  - how long the read takes, and the item count printed
  - any freeze, at the end of the scan above all, where the entries are written
  - the button's texts: Waiting for the list…, Reading n%, then Scan in m:ss
- [ ] The Scan prices button (150 wide, at TOPRIGHT −186, −30, reaching to about −336) doesn't overlap the Browse tab's search bar, and the longest translations of "Waiting for the list…" and "Paused for combat" fit.
- [ ] Prices before the first auction house visit after the update: on an old character, right after logging in, tooltips still show "Auction house (…)" and "Usual price", and a farming session counts auction values.
- [ ] A fight started in the middle of a read: the button says "Paused for combat", and the read goes on after the fight.
- [ ] Closing the auction house mid-read: the message, and the store unchanged.
- [ ] The cooldown text after /reload: it still counts down from the last scan.
- [ ] One migration on an old character: the old prices show in tooltips after opening the auction house once, and a character on another realm or faction does not get them.
- [ ] A pandaren before choosing a faction: no prices, no hints, no migration, no error.
- [ ] A soulbound BoE's tooltip has no Sell now / Hold / Vendor it line; an unbound one in the bags does.
- [ ] The tooltip order: "Auction house (…)", "Usual price", then the hint line.
- [ ] The hint squares on the bag window with each theme: visible, and clear of the gold/green list line, the junk coin and the upgrade arrow.
- [ ] **SavedVariables size:** the size of `WTF/Account/<account>/SavedVariables/FantasyGlassUI.lua` before and after a full scan, and after scans on two houses. Also note the add-on's memory after a scan (`/fgui perf` or the game's add-on memory) and the login time with two or more houses. Each scanned item keeps up to 14 days of history.
