## 13.0.1

**Bags**
- The bag window shows your bag slots when it opens, and the bank window its tabs. Slots (Tabs at the
  bank) still hides them, and that choice is remembered. New players get the ready-made bag sections
  (Upgrades, Gear sets, Bind on equip, materials, consumables and Recipes) switched on; if you switched
  one off, it stays off. With Baganator showing your bags, a one-time tip in chat says where to find
  your bag slots.

## 13.0.0

Guide and Gold: quest guides, a route planner and ways to make gold, for everyone.

**New: quest guides**
- Follow a quest route one step at a time. A panel shows the step you are on, and an arrow points
  the way. Each step ticks off by itself as you take a quest, finish it, hand it in, reach a place
  or gain a level. `<` and `>` move between steps, and a soft sound plays as each one is done.
- Everything is on the Guide tab in `/fgui`: the switch, your guides, and buttons to write one, edit
  the route you follow, or record a guide as you play (`/fgui guide record My route`).
- Paste a guide someone gave you, or copy yours out to share it.
- Three keys in the game's Key Bindings: Guide: next step, Guide: skip step and Guide: plan again.
- With "Read talk and quests aloud" on, each new step is read aloud. `/fgui guide keys` opens the
  panel's menu, for the keyboard.

**New: the route planner**
- **Plan my route**, on the Guide tab, in the guide list or with `/fgui guide plan`, works out a route
  of quests for your level. It picks which quests to take, in what order, and when to fly, take the
  boat, use your hearthstone, train or hand in. It plans again as you play, so the route keeps up
  with you.
- It finds quests through Questie when Questie is loaded. Without Questie it plans the quests in your
  quest log.
- Stops on the way, each with its own switch: your class trainer every two levels, selling and
  repairing when your bags are nearly full, ammunition, food and drink, a profession trainer when a
  skill reaches its cap, the mailbox when mail is waiting, riding at level 40, and unexplored places,
  herbs and ore close to the route.
- Choices it makes for you:
  - At a hand-in, the reward that is best for you is marked. It never hands in for you.
  - When your quest log is nearly full, the panel says which quests are worth dropping.
  - After a long stretch of play it suggests an inn.
  - When no quest is worth the trip, it suggests a dungeon or a place to grind.
- It also plans class quests at the right level, timed and escort quests, and quests that start from
  loot. It counts rested experience and quest rewards that are upgrades for you.
- It learns as you play. A hub where you died twice is left alone for two levels, and elites you
  have soloed count as solo quests. Your other characters' quest times sharpen the estimates.
- Right-click a quest step for **Never suggest this quest**, and **Why this?** for the numbers behind
  it.
- The panel shows the time to your next level and talent points to spend. **Preview** shows the next
  hour of the plan. **Save as guide** turns the plan into a written guide.
- How long can you play? Pick a time, and the route ends at a good place to stop.
- Reputation goals, and a goal to finish the zone you are in.
- **Speed**, **Safety** and **Story** sliders set what the route goes for.
- On the world map, a line shows the next stops, and quest areas are marked by how good they are.
  Click a mark for **Plan from here**. With TomTom loaded, the guide can use TomTom's arrow.
- Where you left off, in one line at login, and a short catch-up page after 14 days away.
- Break reminders at a stopping place (off by default).
- **Race your best**, against your fastest character at the same level (off by default). Level times
  are in `/fgui stats` and the run log.
- A **Find a group** button on group quests. It only fills your chat box, and never sends anything.

**New: the planner window**
- `/fgui plan`, the **Planner** button on the guide panel, or Planner in the Tools menu opens it. It
  shows the route you follow, with every setting for what the planner plans, in groups.
- **How the planner works**: a short tour in four pages. It shows once for your account, and again
  whenever you press it.
- **Keep my route** (off by default): levelling up, hand-ins and loading screens leave your route as
  it is. Only Plan my route and Plan again make a new one. A quest you abandon, fail or skip has its
  steps skipped, and the end of the route is said once.

**New: plan with a friend**
- **Plan with a friend**, in the panel's "..." menu or with `/fgui guide duo`: two players with Fantasy
  Glass UI get one route that suits you both, with the same quests in the same order.
- Your friend is asked first, and can say no. Turn off "Let friends ask to plan with you" if you would
  rather not be asked. Only your friends (in the game or on Battle.net), your guild and your group can
  ask you, each at most once in 5 minutes.
- Each panel says where the other player is: on this step, some steps behind, or done. On a hand-in
  or a flight, it says to wait for them.
- Inside an instance, planning together pauses, and it carries on when you leave.

**New: plan codes**
- **Share plan** (or `/fgui guide share`) turns your route into a plan code to copy. On the website's
  plan page, the code shows the route zone by zone, with a checklist you can tick, on a phone too.

**New: ways to make gold**
- Ctrl-click the minimap button, pick Ways to make gold in the guide panel's "..." menu or the Tools
  menu, or type `/fgui guide gold`. Its window gives ideas for this character:
  - selling what is in your bags and bank
  - items a vendor sells for less than the auction house pays, and the other way round
  - monsters worth killing, and dungeon drops
  - where to gather herbs and ore
  - what to craft for a profit
- Each idea says how much gold an hour it makes, how sure that is, and how much effort it takes.
- The **Gold an hour**, **Ease** and **Safety** sliders, or the **Most gold**, **Easy money** and
  **Safe** presets, set how the ideas are ranked.
- **Save for** a goal (Riding at 40, Epic riding at 60, or an amount of your own), and the window
  says how long it will take.
- At the auction house, **Gold ideas here** sits beside it, with auction flips. A risky flip says "A
  gamble". Opening the auction house loads the gold folder for it; **Gold ideas at the auction house**
  (Bags and items › Gold and farming in the settings) switches the panel off.
- It learns as you play: what merchants sell, what monsters drop, what gathering gives and the
  recipes you know.
- **Go** plans the trip, with flights, the hearthstone and boats, and puts it on the guide panel. Your
  levelling route waits and comes back when the trip ends. **Stop this trip** is in the panel's "..."
  menu.

**New: two minimap buttons**
- Two new minimap buttons open the route planner and ways to make gold (each can be hidden).

**Changed: the add-on is five folders**
- The planner and the gold ideas are in two new folders, `FantasyGlassUI_Planner` and
  `FantasyGlassUI_Gold`. The planner loads the first time you use it. The gold folder loads the
  first time you use it or open the auction house (switch off **Gold ideas at the auction house** and
  only using it loads it). Until then, neither costs any memory.
- Keep all five folders side by side in `Interface/AddOns`, and leave them enabled. The CurseForge app
  does this for you.

**Fixed**
- Some of WoW: Forever's own quests have numbers that Questie does not know. They are now matched to
  your quest log by name and level. Their steps tick off, and the panel shows the log's own words and
  counts, such as "3/8". A quest you have handed in is never planned again.
