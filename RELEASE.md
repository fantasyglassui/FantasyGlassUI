## 11.16.0

**New: roll advice**
- On the loot roll window, the button to press lights up and the reason shows beside the item's
  name: Need for an item on your wishlist or an upgrade for you (with by how many item levels),
  Pass for gear you can't use, Greed for the rest.
- Nothing is ever rolled for you. Features tab: "Loot rolls: light the button to press".

**New: group gear check**
- `/fgui gear` lists everyone in your party or raid with their item level, the lowest first, and the
  group's average at the top.
- The game sends another player's gear one player at a time and only within reach, so the list fills
  in while it is open. Anyone too far away shows "out of reach" and is asked again later. Levels are
  kept for ten minutes, and it never asks during a fight or while your own inspect window is open.

**New: lifetime stats**
- `/fgui stats`: one page of totals for this character and for all of them together. Time played,
  levels, quests, kills, deaths, gold made and spent, items looted, bosses killed, dungeon and raid
  runs, time spent farming, and the best time for each place.
- The counts start the day this version first runs, and the page says since when. Bosses, runs and
  farming reach back as far as the run log and farming sessions do.

**Our own nameplates**
- The health bar on a nameplate is now the add-on's own: our bar texture on a black backing, with our
  rim or the Starcut cut. The game's bar keeps running out of sight and passes on its health and
  color, hidden values included. The red backing behind an enemy's bar is gone for good: it was the
  game's own, tinted to match the bar.
- The game's level badge is replaced by the level in its difficulty color just left of the name
  ("??" for a boss).

**One record of best times**
- The boss timer's "new best" lines, for a boss and for a finished dungeon, are now measured against
  the run log, so they always agree with `/fgui runs`. Best times from before the run log still
  count.
- Each kill in the run log also keeps how long the fight itself took. A run's page shows each fight
  with your best for that boss.
