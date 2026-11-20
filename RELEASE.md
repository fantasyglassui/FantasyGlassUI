## 11.18.0

**New**
- Report a problem: the window now also gives the Discord invite, so you can attach the saved
  report in #bug-reports there instead of using the form.

**Better**
- The add-on's own action bars do far less work while you stand still: four times a second they
  check only range, usability and whether a button is lit, and the icon, count, name and cooldown
  follow their own events (with a full look once a second besides). About 75% fewer questions to
  the game. Macro icons that change with Shift, Ctrl or Alt now change at once.
- Forgetting a deleted character (right-click it twice in the characters list) now clears
  everything else kept for it too: lifetime stats, farming, gold history, profession cooldowns,
  timers, its current run, last session, spec sets, checklist, profile choice and inventory.
- A farming session stopped with nothing made says so ("Farming ended after 0:12, with nothing
  made.") instead of "0c made, 0c in items", and one under a minute stays out of the weekly recap.
- `/fgui buttons` (the minimap buttons the collector has gathered) is listed in `/fgui help`.
- The README in the add-on folder lists every command and what each version since 11.12 added.
