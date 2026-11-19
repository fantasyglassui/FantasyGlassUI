## 11.13.0

**Starcut on every bar**
- 11.12.0 brought Starcut to the unit frames; now it reaches every bar of the add-on, so the whole
  screen matches:
  - your own cast bar and the crafting bar, their spell icon a small diamond;
  - the class resource: as a bar it is cut and glows; as dots, each dot is a small diamond, like a
    row of cut gems; and the class bar under your frame, set in from its points;
  - raid frames: cut bars with a fine edge and no box (no glow: a raid has forty of them), the
    incoming heals cut to match;
  - nameplates: the game's own bar is cut, with its heal prediction and absorbs; your target's
    plate lights its edge in your accent in place of the box;
  - breath and fatigue, the swing timer, pull and break timers, experience and reputation;
  - totems: each slot a small diamond, its cooldown sweep cut to match.
- Frame style: Classic on the Look tab puts the box back on all of them at once, as it does for the
  unit frames.

**New: screenshot mode**
- `/fgui showcase` (or `/fgui screenshot`) brings every frame up with sample data worth a picture:
  a boss as your target with a breath on its way, a party of four classes at different health, a
  focus casting, a pet with its own name, boss frames, all in your current look.
- Everything that would spoil the picture goes: the options window, the movers, the tooltip, and the
  busier samples (notifications, warnings, loot rolls). A short note says how to end it, then fades.
- The same command ends it, and so does a fight. Your frames go back to how they were.

**New: a loot browser**
- `/fgui drops` lists what each boss dropped while you were there: raid and dungeon, then boss, then
  its loot, with how many of your kills each piece came in.
- Drops are noted from your loot window, the loot rolls and the loot lines in chat, once per kill,
  and the book is shared by all your characters. Where the game has a dungeon journal, its loot lists
  fill in the bosses you have not killed yet.
- Upgrades for you are marked and come first; one click shows only those. `/fgui drops <name>` goes
  straight to a raid or dungeon.

**New: a threat meter of its own**
- In a group, with a hostile target, a small panel shows who has how much threat on it, most first,
  up to five of you, in class colors.
- Your row turns the warning color near the top and the danger color when you would pull; a tank
  reads it the other way round. It works without the damage meter, and with the values the game
  hides in some fights.
- Move it with `/fgui move`; `/fgui threat` hides it or shows it again.

**New: farming sessions**
- `/fgui farm` starts one. A small panel shows how long you have been at it and what it makes an
  hour: the gold you made and what the items you looted are worth (the auction price you have seen,
  or the vendor's, whichever is more).
- `/fgui farm` again lists every item with its count and value; `/fgui farm stop` ends it.
- A /reload keeps the session going, and the clock stops while you are logged out.
- Each finished session counts in that week's recap: how often you farmed, for how long, and what it
  made an hour.

**Gear sets**
- The set you are wearing is named, small, over the top right of your player frame.
- `/fgui set <name>` puts a set on; part of the name will do. `/fgui set` on its own lists your sets
  to click.
- Five new key bindings put on your first five sets (A to Z, as the buttons under the character
  window show them).
