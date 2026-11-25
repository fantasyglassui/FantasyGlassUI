# The gold advisor (Part 2 of the quest planner design)

Decided with the player on 25 Nov (17:28–17:36). The player: "all of the above", "do everything you
suggest", "from now on do only what you suggest". Where a line below says *call*, it is Claude's
proposal that the player accepted without changing it.

## Intent

The planner's sister: where the planner says where to level, the gold advisor says how to make gold,
using only what the add-on can know inside the game (no internet, no online AI). It must be honest
about how sure it is: a number it guessed says so, a number you earned replaces the guess.

## What it covers

1. Farming: monsters worth killing for their drops, where they are, the route there and round them.
2. Gathering: herb, ore and skinning routes for your skills and level.
3. Crafting for profit: recipes you know whose product sells for more than its materials, with a
   shopping list.
4. Auction flipping: items listed well below their usual price, worth buying to sell again.
5. Vendor flips: things a vendor sells that go for more at the auction house, and auction items worth
   less than a vendor pays for them.
6. Selling dungeon drops: what your dungeon loot is worth, and which runs pay best (from the run log
   and farming history).
7. Knowing when to sell: for bags and bank, "Sell now" (above its usual price), "Hold" (cheap today),
   "Vendor it" (nobody buys it).

## Prices

- A **Scan prices** button on the auction house window uses the game's own full-list call
  (`C_AuctionHouse.ReplicateItems`, `REPLICATE_ITEM_LIST_UPDATE`, `GetNumReplicateItems`,
  `GetReplicateItemInfo`, `GetReplicateItemLink`, all in the Forever API dump). One click lists every
  auction; the server allows it about once every 15 minutes, so the button counts down to the next.
- The list is read in slices of a few milliseconds a frame; items whose details aren't loaded yet are
  filled in as they arrive. Never in combat.
- Per item it keeps today's lowest price, the usual price over recent days and how many are listed
  (whether it sells). One store shared by all your characters on the realm.
- The prices you see while browsing (already noted by Economy.lua) top it up between scans.
- Freshness is always shown ("prices from 2 days ago", "never scanned"); fresh prices weigh more.
- Not possible: prices from a website or service (no internet). Sharing scans with friends or the
  guild through the add-on can come later; not in the first version.

## Estimates (call: approach 3, mixed)

- For a place or method you have not tried, the advisor makes an honest **guess** from what it knows:
  Questie's which-monster-drops-what and where they spawn (how dense), your kill speed (from your
  farming history, else a level-based default), and the prices above. Gathering likewise from node
  counts and prices. A guess is marked "guess".
- Once you farm or gather there, your real numbers (farming sessions, "farming by zone") replace the
  guess and it says "measured".
- Crafting and flipping margins are computed from prices, marked by their prices' freshness.

## Ranking

- Three sliders, like the planner's: **Gold an hour** (how much), **Ease** (how little effort; selling
  your bags is easy, a long route is hard), **Safety** (how sure the money is; vendoring is certain, a
  flip can lose gold, stale prices count as less sure).
- Presets: **Most gold** (100/0/0, the default), **Easy money**, **Safe**; moved sliders read
  "Custom" unless they match a preset.
- An optional **goal** ("Save for: 900g", or a named target such as the epic mount): each idea also
  shows the time to reach it, the list leads with the fastest within your sliders, and a bar shows how
  close you are.
- Every idea always shows its gold an hour (or total), its ease and how sure the money is, whatever the
  sort.

## Where it shows

- **Its own window** in the settings window's look (12.3), from the minimap launcher and the Planner
  window: the ranked "Ways to make gold now" list, the sliders, the goal. Each idea has **Go**, which
  plans the trip with the planner's travel model (flights, hearthstone, boats).
- **A panel on the auction house**: the scan button and the ideas that live there (flips, crafting
  margins, sell now).
- **Hints in item tooltips and on the bag window**: Sell now / Hold / Vendor it.

## Packaging and release (calls)

- The advisor lives in its own load-on-demand folder, `FantasyGlassUI_Gold` (`## LoadOnDemand: 1`,
  `## RequiredDeps: FantasyGlassUI`, `## OptionalDeps: Questie`), loaded only when used.
- It stays behind the guide's unlock and goes public **with the planner in 13.0** ("Guide and Gold").
- **Exception, public early in a 12.x update:** the Scan prices button, the price store and the
  Sell now / Hold / Vendor it hints (tooltips and bags). They are self-contained, useful to everyone
  and start collecting price history before the advisor needs it. They belong to the main add-on
  (Economy/Auction), not the Gold folder, and their texts may be public; nothing in them mentions the
  advisor or the planner.

## Build order (call: batches, each usable on its own)

1. The shared core, plus the public scan and sell hints (the 12.x part ships from this).
2. Bags and selling: when to sell, vendor flips.
3. Farming and selling dungeon drops.
4. Gathering.
5. Crafting for profit and auction flipping.

## Non-goals and anti-goals

- No posting, buying or bidding by the add-on: every auction action stays the player's own click (the
  game allows nothing else).
- Never a number without its freshness and whether it is a guess.
- Never heavy work in combat or a freeze while reading a scan.
- Nothing about the advisor or the planner in public texts until 13.0.

## Left to the builder

The exact guess formulas and defaults (stated in the plan and tested), the size of the price history
kept per item, the ease scores per kind of idea, the window's layout within the 12.3 look.

## Answers to the builder check (Claude's calls, per the player's "do only what you suggest")

1. **Farming guesses without drop rates.** No bundled drop table (the data would have to be copied from
   sites that don't allow it). A guess for an untried monster = a per-level default value per kill
   (vendor trash and cloth, by level band; built-in, small, marked "guess") plus the quest-item drops
   Questie knows. Every monster you loot teaches the advisor: it records monster → items and counts
   for all your characters, and the learned value replaces the default once a monster has been looted
   10 times. Your farming sessions still give the "measured" gold an hour.
2. **Gathering nodes.** Routes use only nodes your characters have gathered (the planner's
   `plannerNodesSeen`, shared across characters). For untried zones it suggests by skill level from a
   small built-in list of zone → herbs/ores by skill range (well known, short), marked "guess", without
   a route until you have gathered there.
3. **Prices.** The new price store wraps and replaces `ns.root.auctionSeen`: keyed by auction house
   (realm + faction; a neutral auction house gets its own key where the game says which one is open),
   with one accessor every reader uses (tooltips, Auction.lua, Farming.lua). Old prices migrate once to
   the current realm and faction. Prices are never mixed between factions.
4. **Go and the levelling plan.** Go pauses the levelling plan and puts the gold trip on the guide
   panel as steps; finishing or cancelling it resumes the levelling plan where it was. Travel comes
   from the planner: the planner's own-folder move is done before gold batch 3 (the first with Go);
   the Gold folder loads the Planner folder when Go is used (`## OptionalDeps: FantasyGlassUI_Planner`
   plus a load on demand). Batches 1–2 need no travel.
5. **One-off ideas vs per-hour ideas.** The window shows one-offs (sell your bags, vendor junk, a single
   flip) in their own top section, "Right now", by total gold and minutes; the per-hour ideas are
   ranked below by the sliders. With a goal set, both merge into one list by time to the goal.
