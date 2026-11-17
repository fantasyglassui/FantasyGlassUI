# Fantasy Glass UI 11.10.0

**New: player tooltips, every line your choice**
- A new group of switches on the Features tab, under "Player tooltips: choose the lines".
- Hide any of the game's lines on a player's tooltip: their title, their realm, the guild line,
  the level/race/class line, the faction line, the PvP line, and the health bar.
- Turn the add-on's own lines on or off: who they are targeting, and their guild rank. (Your note
  on a player keeps its own switch, "Notes on players".)
- New lines to turn on:
  - their role in your group (tank, healer or damage), while you are in a group;
  - "Your friend" or "In your guild" under players you know;
  - their health in numbers: 12,345 / 20,000 (62%). Off at first.
- Put player tooltips away during fights, so they don't cover the action; hold Shift to see
  one anyway. Off at first.
- Every switch takes effect at once, without a reload, and presets never change them.
- Anything the game keeps hidden from add-ons is left exactly as it is.

**New: tooltips wear your theme**
- Every tooltip (players, creatures, items, comparisons, linked items) now has your theme's own
  panel instead of a plain dark box: glass with its sheen on Glass themes, leather grain with small
  gold corners on Fantasy, carved stone with small glowing rune-studs on Runic.
- An item's quality still colors the tooltip's edge.
- The health bar under a unit's tooltip is slimmer, in your bar style, with a dark backing. It
  takes the player's class color, or green, yellow or red for a friendly, neutral or hostile
  creature.

**New: a one-line vendor summary**
- When you close a vendor, one line in chat says what the visit came to:
  "At the vendor: sold 12 items for 3g 20s, bought 3 items for 40s, repaired for 1g 5s. In all: +1g 75s."
- It counts every change in your gold while the vendor is open, so it is exact, buy-backs and
  restock purchases included; guild-paid repairs are named as such.
- It takes the place of the junk seller's, auto-repair's and restock list's own lines. A visit
  where nothing changed hands says nothing. Switch: "Vendors: one-line summary" (on at first).

**New: right-click hands items over in the bag window**
- At a vendor, right-clicking an item in the one-window bags sells it, gear and items with a
  "Use:" effect too. Before, gear could be equipped instead, or needed a second click.
- The same at the bank and guild bank (stores it), a trade and the auction house, as in the
  game's own bags.

**Polish**
- The add-on's buttons and switches make the game's own click sounds.
- Buttons that delete or reset ask first: click once and it turns red ("Click to confirm"), click
  again within four seconds to do it. Now on deleting a profile, deleting a theme you made,
  resetting all class colors and resetting window positions.
- More windows stay where you drag them, for all your characters: the options, the notepad, the
  whisper window, the quest log, the layout gallery, the share preview, the boss note editor and
  the copy-text window.
- Hover help on more buttons: the menu, Sort, the quest log's Track, Show on Map, Share and Abandon,
  the minimap add-on buttons, Raid Tools, the share preview, the safe mode banner, and a panel's
  Center and Reset in move mode.
- Counts read right when there is one: "1 skill", "1 piece missing", "Seen once", "1 match",
  "in 1 day" and the rest, in every language.
- Searching the options says so when nothing matches, on the Features tab and in the search across
  every tab.
- Twelve more messages are translated, among them the home key's, keybind mode's and the layout
  gallery's.
- Every event the add-on listens for is now handled inside its error guard, so a fault in one shows
  once in chat instead of as a game error, and `/fgui perf` measures them all.
- Still class emblems cost nothing between frames.

**Changed**
- What's new is translated, in all eight other languages.
- Switches that only work while another is on are dimmed while it is off, and their card says
  which one they need: the player tooltip lines, the quest tracker's rewards, names on chat
  bubbles, and the bag sections.
- `/fgui help` is sorted into proper groups: Everyday, Groups and raids, Your characters,
  Bags, gear and trade, People and notes, The world, Handy tools, Settings and backups, and
  If something is wrong. (Most newer commands had ended up under "If something is wrong".)
- `/fgui help` lists itself.
- The help's command descriptions and headings are translated into all eight other languages.

**Fixed**
- The spellbook's section headings ("Retribution" and the rest) had their words squeezed into the
  top-left corner of a big box. They now sit on a thin accent line, with room around them.
- "Level, race and class" in player tooltips also hides the class when the game puts it on a
  line of its own, as WoW Forever does.
- Your session's loot count counted a stack of several items ("x5") as one.
- The session's experience count could stop with an error when experience was gained during a
  fight.
- The experience bar's "kills or quests to level" line was not translated.

