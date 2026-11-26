## 12.4.0

**New: Scan prices**
- A **Scan prices** button on the auction house, left of Worth selling, reads the whole auction
  house in one click. The auction house allows it about every 15 minutes; the button counts down
  to the next one ("Scan in m:ss").
- The list is read in small pieces, so the game doesn't freeze, and the reading pauses in a fight
  ("Paused for combat") and goes on after it. It never posts, buys or bids.
- The prices it reads go into the tooltips and the sell hints, like the prices you see while you
  browse.

**New: prices for each auction house**
- Prices are kept for each realm and faction: a character on another realm or faction has its own.
- Your old prices move in once, into the auction house you first open after the update. Until
  then, your tooltips keep showing them.

**New: Sell now / Hold / Vendor it**
- Item tooltips say **Sell now** when an item is well above its usual price, **Hold** when it is
  cheap today, and **Vendor it** when a vendor pays about as much or nobody lists it, with how fresh
  the prices are.
- On the bag window, a small coloured square says the same: green for Sell now, amber for Hold,
  grey for Vendor it.
- Vendor it is for common and uncommon items only. Bound items get no hint.
- Both are in Bags and items › Auction and trade, and on by default.

**Known limits**
- A neutral auction house shares its faction's prices.
- Connected realms keep separate prices: each realm of a connected group has its own.

**Fixed**
- `/fgui shop` counts what your other characters hold again.
