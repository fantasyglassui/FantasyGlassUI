# Changelog

The releases published on CurseForge. Each lists what changed since the release before it.

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
  rather not be asked.
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
- The **Gold**, **Ease** and **Safety** sliders, or the Most gold, Easy money and Safe choices, set
  how the ideas are ranked.
- **Save for** a goal (Riding at 40, Epic riding at 60, or an amount of your own), and the window
  says how long it will take.
- At the auction house, **Gold ideas here** sits beside it, with auction flips. A risky flip says "A
  gamble".
- It learns as you play: what merchants sell, what monsters drop, what gathering gives and the
  recipes you know.
- **Go** plans the trip, with flights, the hearthstone and boats, and puts it on the guide panel. Your
  levelling route waits and comes back when the trip ends. **Stop this trip** is in the panel's "..."
  menu.

**Changed: the add-on is five folders**
- The planner and the gold ideas are in two new folders, `FantasyGlassUI_Planner` and
  `FantasyGlassUI_Gold`. The game loads each one only the first time you use it, so they cost no
  memory until then.
- Keep all five folders side by side in `Interface/AddOns`, and leave them enabled. The CurseForge app
  does this for you.

**Fixed**
- Some of WoW: Forever's own quests have numbers that Questie does not know. They are now matched to
  your quest log by name and level. Their steps tick off, and the panel shows the log's own words and
  counts, such as "3/8". A quest you have handed in is never planned again.

## 12.4.1

**New: another add-on's scan is read too**
- When another add-on, such as Auctionator, scans the whole auction house, Fantasy Glass UI reads
  the same list for its own prices. It is read the same way as with Scan prices: in small
  pieces, and never in a fight.
- The auction house allows one such scan about every 15 minutes, shared by every add-on, so the
  Scan prices button counts down from that scan.
- If you press the button while that list is being read, it shows how far the reading has got, and
  the chat says "Another add-on scanned just now: its prices are being read."

**New: prices from Auctionator and TSM**
- When Fantasy Glass UI has no price for an item, the tooltip shows Auctionator's price, or else
  TSM's, marked "Auction house (Auctionator)" or "Auction house (TSM)". This needs that add-on to
  be loaded.
- They show in tooltips while Auction prices in tooltips is on. These prices are only shown, never
  kept. They can give Vendor it, when a vendor pays about as much, but never Sell now or Hold.
- The setting is Prices from Auctionator and TSM, in Bags and items › Auction and trade. It is on by
  default.

**Changed**
- The description of the Sell now, Hold and Vendor it hints now says that every Vendor it hint is
  for common and uncommon items only.

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

## 12.3.0

**New: a new look for the settings window**
- The settings window (`/fgui`) has a look of its own: calm and dark whatever your theme, with
  only your theme's accent color showing through, and clear lettering.
- Settings sit in cards with room between them, and every on/off setting is a switch.
- A tidier list of categories down the left, with the open one's sections under it.
- Themes are shown as a grid of pictures, with a large preview beside it.
- High-contrast themes give the window a black-and-white version, so nothing gets harder to read.
- The Readable and Dyslexia-friendly lettering still apply in the window, and so do the text size
  and outline choices.
- Only the settings window changes: every other window still wears your theme, and every setting
  is where it was.

**Changed: where the window's own controls are**
- Search every option is in the window's header.
- Simple / All options is at the top of the list on the left.
- "Reset <category> to how it came" is in the footer, beside Undo last change.
- What you changed lately is in Undo last change's tooltip: point at the button.
- Click a theme to preview it beside the grid; "Use this theme" wears it.
- The window starts wide enough for everything in it to show whole. Drag its corner to make it
  wider: the pages and the theme grid follow.

**Fixed**
- The buttons that reload the interface work again: the setup's Finish & reload and its language
  list, Use on a profile, Reset positions, Leave safe mode, and `/rl`. Where the game refuses, the
  add-on says "Type /reload to finish."

## 12.2.0

**New: more accessibility**
- Read talk and quests aloud: what an NPC says (and the choices it offers), a quest's text when you
  are offered it, its progress and its reward, and a book or letter are read with the game's voice
  as soon as they open; the reading stops when you close them.
- Read what I point at: when the mouse rests on something for half a second, its tooltip is read
  aloud. (The game's own screen narrator only works before you log in.)
- Move through the game's windows with the keyboard: with an NPC's talk, a quest, a vendor, the
  mailbox, loot, a trainer, a flight master, the bank or a question box open, Tab or Down goes to the
  next thing to press, Shift+Tab or Up to the one before, and Enter or Space presses it. A ring shows
  where you are, and each choice can be said aloud with where it is in the list. Never while you
  type, and not in a fight.
- Keys for one hand: one button binds moving, jumping, targeting, interacting and the first action
  buttons round W, A, S and D for the left hand, another puts them all on the number pad for the
  right. The keys they take are noted, and "Put my keys back" returns every one (`/fgui keys left`,
  `numpad` or `back`).
- Celestial: High contrast, a black sky with white stars and rims, the third high-contrast theme
  beside Glass and Fantasy. "Use the high-contrast theme" (and `/fgui contrast`) picks the one for
  the family you use.
- Still sky: the celestial sky keeps its stars but holds still, while everything else moves as usual.
- Wait before a tooltip shows: up to two seconds of rest before a tooltip appears.
- All of these travel in the one line of accessibility settings you can share.

## 12.1.0

**New: accessibility**
- Accessibility is a category of its own in `/fgui`, with seven sections: Seeing, Hearing,
  Flashing and motion, Focus and calm, Reading aloud, Hands and keys, and Share. The setup has a
  Comfort step for the same things.
- Color vision for each kind: red-green (blue and orange), blue-yellow (teal, pink and red), or no
  color at all, where brightness and marks carry the meaning. With any of them, threat on
  nameplates gets a mark ("!" when it is slipping, "!!" when it is lost or on you), as debuffs get
  a letter and item quality gets dots.
- Outline round my target: a thick ring, 1 to 8 pixels, round your target's nameplate.
- Captions for sounds: a line on screen, with a mark for its kind, for ready checks, whispers,
  dungeon and battleground queues, group invites, duels, resurrections, summons, boss emotes,
  raid warnings, loot rolls, the aggro warning and your own alerts that play a sound. Movable in
  move mode; click one to put it away.
- Read aloud: a key binding (and `/fgui read`) that says the tooltip under the mouse, the quest you
  are reading, or the last whisper, with the game's own voice.
- Two lettering styles made to be read: Readable (Atkinson Hyperlegible, made for low vision) and
  Dyslexia-friendly (OpenDyslexic). An outline round letters (thin or thick) and a dark band
  behind messages in the middle of the screen.
- Safe flashing: nothing flashes more than three times a second, flashes are gentle, pulsing
  warnings hold still, and the game's red low-health flash is off where this client allows it.
- Calm mode: one notification at a time, held for fifteen seconds and put away with a click;
  messages in the middle of the screen stay up longer; captions wait their turn.
- Bigger controls in the settings, and "click twice" buttons wait ten seconds for the second click.
- Move through the settings with the keyboard (off until chosen): Tab and the arrow keys go from
  setting to setting, Space and Enter use one, Left and Right move a slider or step a choice, Page
  Up and Page Down change section.
- Share: `/fgui access copy` gives all your accessibility settings as one line of text, and
  `/fgui access paste` (or the setup's Comfort step) takes one back.

**Changed**
- The ring round the mouse pointer and the quieter red error line are in Accessibility now.

**Changed: made for WoW: Forever only**
- Every function, event, frame and setting the add-on uses was checked against what the WoW: Forever
  client actually has (its own interface code and the lists taken from the live client). Calls kept
  for older game clients, and the older names Blizzard keeps only for backwards compatibility, are
  gone: the add-on now calls Forever's own functions directly.
- Talent builds (`/fgui talents`) work on Forever's talent trees: a build is the game's own loadout
  code, and putting one back fills in the talent window's Import box (press Import and it joins
  your loadouts). The older builds, from three talent tabs, were never usable here and are dropped.
- Inside instances, where Forever stops add-ons messaging other players, sending a layout, a build
  or a whisper from the add-on says so instead of failing without a word; the version check and the
  pull timer's message wait until you are outside (the game's own pull countdown still runs).

**Fixed**
- The talent set buttons (1 and 2) on the character window never appeared: the number of talent sets
  was asked for under names Forever does not have.
- Hunter pet happiness was never shown: it is asked for where Forever keeps it now.
- Debuffs on frames were all red: the colors for magic, curse, poison and disease come from where
  Forever keeps them.
- The typing bar's rim did not take the channel's color, and short key names on the game's action
  buttons could be rewritten by the game: both followed functions the game no longer calls.
- An item shift-clicked while typing in the restock list now goes into it.

## 12.0.0

**New**
- A new settings window. The categories are listed down the left (Look and themes, Frames and
  bars, Combat, Groups and raids, Bags and items, Quests and map, Chat and people, Done for you,
  Layout and profiles, Tools), and the one that is open lists its sections under it. Each section
  shows its settings one to a line, with what each does under its name and "after /reload" where
  it needs one, then the larger pieces that go with them: the theme grid, the frame and bar
  designers, the cooldown list, your lists and rules. Every setting was moved to the section it
  belongs to: the behavior switches, size sliders and numbers that were on the Combat, Layout and
  Tools tabs now sit with what they change, and settings that were in two places are in one.
- Home: a card for each category, quick switches, what you changed lately, the presets, the guide's
  question box and suggestions for your class.
- The search at the top of the list says where each setting lives ("Auto-repair · Bags and items ›
  Vendors"), and Enter goes to the first result.
- Undo last change, at the foot of the window, takes back what you changed, one step at a time.
  Each category can be reset to how it came (its switches and sliders; lists, rules, designs and
  positions are kept).
- Simple / All options, at the top: Simple shows the settings most players look for, and is where
  a new player starts. The search always finds every setting.
- A new setup in four steps: how much to take over (the whole interface, only restyle the game's
  own frames, or everything), how you play (your role, and what you enjoy: questing, groups, PvP,
  collecting, being social), your look, and a summary.
- Accessibility in one place (Look and themes › Accessibility): color-blind safe colors, now with
  dots for item quality in bags, on gear and on loot rolls; reduce motion; two high-contrast themes,
  with a new fantasy one in black, gold and white; and three text sizes.
- NEW tags on what is new in this version, Show sample frames in Frames and bars, the profile you
  are changing in the header, and a window you can resize from its corner.

**Changed**
- Settings saved before profiles existed (versions before 9.0), and the old StylishUI settings, are
  no longer read: they start afresh, and the setup opens.
- `/fgui look`, `/fgui layout`, `/fgui bars`, `/fgui combat`, `/fgui colors`, `/fgui clickcast`,
  `/fgui profiles` and `/fgui tools` open the matching place in the new window.

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

## 11.17.4

**New**
- Discord: Fantasy Glass UI has a Discord server for help, ideas, bug reports and sharing themes.
  A Discord button at the foot of the settings window, or `/fgui discord`, shows the invite in a
  box to copy (add-ons cannot open web pages themselves).

## 11.17.3

**New**
- Website: Fantasy Glass UI has its own site at [fantasyglassui.com](https://fantasyglassui.com), with every
  theme to try on the page, every switch and command, answers to common questions, and a theme maker
  whose code you paste into `/fgui sharepreview` to use the theme in the game. `/fgui website` shows
  the address in a box to copy.

**Polish**
- The add-on's description in the game's add-on list now says glass, fantasy and celestial themes
  (it still said runic, which became Celestial).

## 11.17.2

**Fixes**
- Nameplates: our health bar now sits in the same place as the game's, so where the game hides the
  whole health area (friendly plates that show only a name) ours goes too. If the game fades its own
  bar back in, it is put straight back out, with no flicker of the old bar.
- Group gear check: it no longer clears what your own inspect window is showing if you open it while
  the check is asking someone. A player whose gear arrives before the game has looked it all up
  gets a second look a moment later, instead of being asked over and over.
- Goals: an item goal counted this character's bags twice over (once from the last snapshot, once as
  they are now) when the item was also on another character. Each character is now counted once,
  this one as it is now.
- Upgrade notice: with two copies of the same item in your bags, it puts on the very one you looted,
  not whichever comes first.
- Lifetime stats: the page now says that kills are counted from the experience they give, so they do
  not go up at the level cap.

## 11.17.1

**Polish**
- Upgrade notice: several upgrades looted at once now wait their turn ("2 more" says how many), the
  next one coming up as you put one on or close it. A notice goes by itself once the item is worn,
  however it was put on (Equip best, dragging it), or is no longer an upgrade.
- Goals: a gold, level or mount goal that is already reached when you set it says so at once, rather
  than announcing "Goal reached" a moment later.
- Group gear check: on your own, the window says you are not in a group instead of listing only you
  without a word.
- Lifetime stats: the "This character / All characters" heading sits over the numbers it names.

## 11.17.0

**New: put on an upgrade as you loot it**
- Loot something that is an upgrade and a small notice shows it, with by how many item levels it
  beats what you wear and an **Equip** button.
- For a ring or a trinket there is a button for each of the two you wear, so you choose which one it
  replaces.
- In a fight the click waits until the fight is over. An item not yet bound to you is put on the same
  way, and the game asks you first, as it always does. The notice goes after a minute, or with its
  cross; move it with `/fgui move`. Features tab: "Looted an upgrade: a button to put it on".

**New: milestones**
- Your 100th, 1,000th and 10,000th kill, 10th and 100th quest, first boss and 100th, first dungeon or
  raid run, 1,000 gold made, items looted and more each get a short notice and a sound when reached.
- `/fgui stats` lists the milestones each character has reached, with the day.
- Bosses and runs already in your run log when this version first runs are counted as reached
  quietly, so you are not greeted with a pile of old ones.

**New: boss guide**
- When you target or pull a boss, its abilities from the game's dungeon journal show one line each,
  with their icons, under your boss note. A boss without a note of yours now opens the panel for the
  guide alone.
- Only on game clients with the journal, and never while you have the journal open yourself.
  Features tab: "Boss guide: abilities from the journal".

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

## 11.15.0

**New: a loot wishlist**
- In the loot browser (`/fgui drops`), click an item to star it; click it again to let it go.
- A starred item dropping, coming up in a loot roll, or a boss that drops it becoming your target is
  called out, with a sound and a line in chat (a boss once a day).
- `/fgui wish` lists your wishlist, each item with the boss and place it drops from and how often you
  have seen it drop. Starred items carry their star in the whose-upgrade list too.

**New: boss drops on the boss**
- Point at a boss and its tooltip lists what it drops that is on your wishlist or would be an upgrade
  for you, with by how many item levels and in how many of your kills it dropped. From the loot
  browser's book, and the dungeon journal where the game has one (Features tab, "Boss tooltips").

**New: quest mobs on nameplates**
- The plate of a mob you still need for a quest gets a small quest mark at its left, with how many
  are left ("Defias Thug slain: 3/8" shows 5). Read from the mob's own tooltip, so it follows your
  quest log as it changes.
- Nameplates designer: "Quest mobs: a mark and how many are left". Where the game hides those
  tooltip lines (in some instances), plates are left unmarked.

**Starcut windows and tooltips**
- Under the Starcut frame style, windows and tooltips have their corners cut away, with a fine rim
  along each cut. Big windows carry a star on their two top cuts (not on Glass, which wears no
  ornament). The corner brackets step aside for the cut.
- The cut keeps its size on any window. On a game client that cannot draw it that way, windows keep
  their square corners and only the stars are added.
- Frame style: Classic puts the square corners back.

## 11.14.1

**Performance**
- The add-on does less work while you play, most of all in a fight, and makes less to tidy up
  afterwards (measured: 2.0 to 1.9 ms a second at rest, 2.1 to 1.8 in a fight, and about a sixth
  less memory churn at rest).
- Action button labels were looked at every second to catch a change; they now change when you
  change the setting, with a slow look in case the game reset one.
- The cooldown tracker only checks its icons while one of them is counting down.
- The pieces of the game's own frames that are kept out of sight every frame (its cast bars, mirror
  timers and loot rolls) are now checked in one sweep instead of one guarded call each.

**Polish**
- Farming panel: for the first two minutes it shows what you have made so far. One early coin used to
  make the hourly figure look like a fortune.
- Whose upgrade: right-click the list to put it away until the next drop; its tooltip says so.

## 11.14.0

**Starcut for the rest of the screen**
- Action buttons are cut like gems: their corners cut away, a fine rim in your theme, and the cooldown
  sweep cut to the same shape. The add-on's own bars and the game's bars alike.
- Bag and bank slots take the same cut, the rim in the item's quality color.
- A diamond minimap (Features tab, "Minimap: diamond"): cut like the Starcut portrait, with a fine rim
  and a star on each point. The zone, coordinates and clock stay on it.
- Frame style: Classic still puts the square box back on all of them at once.

**New: whose upgrade**
- In a group, when a boss drops something rare or better, the players who use Fantasy Glass UI each
  work out whether it is an upgrade for them and quietly tell the others.
- A small panel says, item by item, whose upgrade it is and by how many item levels, biggest first,
  before anyone rolls. It hears of an item from a loot roll or from whoever opens the loot window.
- Nothing is said in chat; players without the add-on are simply not on the list. Move it with
  `/fgui move`.

**New: a run log**
- Each dungeon and raid you go into is a run: how long it took, the bosses killed and when, the wipes
  on each, your deaths and your rare and better loot.
- `/fgui runs` lists them place by place, each with its best time: the quickest of the runs that
  killed the most bosses. Click a place for its runs, and a run for its bosses and loot.
- Stepping out to repair is still the same run; 15 minutes away, or going in somewhere else, ends it.
  Shared by all your characters, the last 100 runs.

**Farming by zone**
- Each farming session now notes where you farmed: the time, gold and loot zone by zone.
- `/fgui farm zones` (or "Best farming spots" in the session window) lists the places you have
  farmed by what they make an hour, with whether your latest time there was up or down on the
  ones before.

**Goals**
- Three new kinds on the goals panel: gold on all your characters (`/fgui goal gold 10000`), a level
  (`/fgui goal level 60`) and a mount (`/fgui goal mount <name>`).
- An item goal now counts the item on all your characters, and its tooltip says which boss it drops
  from and in how many of your kills, from the loot browser.
- The bars take the Starcut cut, and a goal reached says so once.

**Nameplates**
- The threat color is on the plate's edge too (Nameplates designer, "Threat on the plate's edge"):
  a tank sees at a glance which mob is slipping, while the bar keeps its usual color if you switch
  threat colors off. Your target's accent still comes first.
- The background behind a plate's health is black now. The game tinted it in the bar's own color, so
  on an enemy the red bar and its red background ran together.

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

## 11.12.0

**New: Starcut, a new look for your unit frames**
- The unit frames leave the plain box behind. Health and power are bars cut to points at both ends,
  each glowing softly in its own color, with no panel around them; a thin dark edge keeps them clear
  on bright ground such as snow.
- The portrait is a diamond with a soft halo. The 2D picture and the class emblem fill it; the 3D
  model, which the game can't cut to a shape, sits in the square inside it.
- On your frame and your target's: small stars on the diamond's points, a fine line from the
  portrait past the end of the bars to a star, and the name and level above the bars, cut short with
  "..." before they run into anything. The target mirrors your frame: its portrait on the right, its
  bars filling from the right, its numbers at the left.
- The raid mark sits on the diamond's top point, the leader's crown on its bottom point, and on your
  frame crossed swords in a fight, or the resting sign, on its outer point.
- On your frame and your target's, health and power each carry their own number, on their own bar.
- Cast bars on the target, focus, boss and arena frames are cut the same way, with the spell's icon as a small
  diamond; buffs and debuffs sit below the frame unless you have chosen above (then they clear the
  name). Combo points take the same cut.
- The smaller frames (target's target, focus, pet, party, bosses, arena) get the cut bars and the
  glow; the stars and the line are kept for your frame and your target's, so a party stays tidy.
- It follows your theme: glass, fantasy and celestial colors, accents and lettering.
- Prefer the box? Look tab, Portraits and class colors, Frame style: Classic brings it back at once
  (asked for during a fight, it changes when the fight is over).

**A new icon**
- The gem keeps its gold and its clear glass, and the blue half of the icon is now a night sky with
  stars and a small constellation, so the icon shows all three families of themes. It is the same
  in the add-on list, on the minimap button, in the options and setup, and on CurseForge.

**Performance: open windows**
- The windows the add-on restyles are looked over twice a second while they are open, to catch the
  parts the game builds as you click around. That look now does much less: about a third less work
  for every window open at once, and a quarter of what it was for the vendor, mailbox, guild, group
  finder, collections, auction house, professions and talent windows.
- The character window: its reputation, skills and currency lists are passed over when no rows have
  been added, and its side tabs no longer make new lists five times a second (about a fifth of the
  work it did).
- Scrolling lists in any window: rows are styled once, so a list with as many rows as at its last
  look is passed over without a walk.
- Deep windows (collections, auction house, group finder, professions) are walked without making a
  new list or function for every frame on the way.

## 11.11.0

**New: a login briefing**
- A few seconds after you log in, one small window says what is waiting: once-a-day crafts that are
  ready, mail on your other characters, raid and dungeon lockouts that reset since you last played,
  rested experience, and the daily and weekly jobs left on your checklist.
- Click a line to open the window it comes from. Nothing waiting, no briefing; a /reload does not
  bring it back. `/fgui briefing` shows it at any time. Switch: "Login briefing: what is waiting".

**New: profession leveling helper**
- A Skill-ups button on the profession window (or `/fgui skillups`): the recipes you know that
  still give skill points, best first. What you can make now comes first, then what needs the fewest
  materials, orange before yellow before green.
- Each line says how many you can make, or what is missing and whether another character holds it.
  Click one to bring it up.

**New: weekly recap**
- Each character's week is noted as you play it: gold made or spent, time played, levels gained,
  raids and dungeons, and its best loot (rare and better). The last eight weeks are kept.
- `/fgui recap` shows last week for all your characters; `/fgui recap this` shows this week so far.
  The login briefing says when a new recap is ready.

**New: Celestial themes, in place of Runic**
- Runic is gone. The third family of themes is now Celestial: 38 night skies. Each window's sky
  deepens toward the top and glows along its foot like a horizon; its stars are sparse and uneven,
  and each window sees a different part of the sky, with a faint Milky Way across it.
- One fine line round each window with a soft glow inside it, and a small star at the top. Large
  windows carry one real constellation (the Big Dipper, Orion, Cassiopeia, Cygnus, Lyra or the
  Southern Cross; a different one per window) and an orbit sweeping across a corner.
- The sky is alive: three layers of bright stars twinkle out of step, motes of starlight drift up
  through each large window, the horizon and the Milky Way breathe, the constellation and the orbit
  glow and fade, the star at the top turns, and every ten seconds or so a shooting star crosses one
  of the large windows that are open. On the minimap the four direction stars twinkle and turn, the
  sun's rays turn, and the round map's outer orbit goes round once in a minute and a half. It is the
  game's own animation, runs only on windows that are showing, and "Reduce motion" holds it all still.
- Action buttons are lit from inside; the divider is a line of light with a star at its middle;
  the class emblems sit on a small night sky inside a ring of star-chart marks.
- The minimap becomes a star chart. Square, as it comes: degree marks along its edges, a star point
  at north, east, south and west, and the sun by day or the moon by night riding along the top by
  the game's clock. Round (the minimap's round switch): a ring of degree marks with the four
  directions, an outer orbit that turns slowly (held still with Reduce motion), and the sun or moon
  on it, noon at the top and midnight at the foot.
- Anyone using a Runic theme is moved to the Celestial theme made from it, with the same accent:
  Granite becomes Polaris, Emberrune becomes Comet, Jadestone becomes Aurora, and so on. Themes by
  place and themes of your own made as Runic move too. The Look tab and the setup list them under
  Celestial.
- The lettering style that was called Runic keeps its face and is now called Engraved.

**New: twelve more accent colors**
- Midnight blue, Ice, Turquoise, Emerald, Chartreuse, Olive, Bronze, Peach, Blush pink, Magenta,
  Lavender and Indigo: 31 in all, in two rows on the Look tab and in the setup, ordered round the
  color wheel. Each accent's name is shown in your language when you point at it.

**New: interface size**
- An Interface size slider beside Text size on the Layout tab (50 to 150%), and Text size now goes
  from 70 to 150%.
- `/fgui uisize 90` and `/fgui textsize 120` set them from chat; asked for during a fight, they wait
  for it to end.

**Polish**
- The option buttons explain themselves: point at one for what it does. The Layout tab's size
  sliders do too.
- Text size and Interface size take effect when you let go of the slider, so the window no longer
  moves under the mouse while you drag.
- If you change the game's own UI scale while Interface size is set, the add-on takes the new scale
  as its base instead of the old one.
- The login briefing waits for What's new, the setup and the login splash to close, waits out a
  fight, and is put away when a fight starts. A raid saved on two difficulties is named once.
- Skill-ups: recipes that need no materials count as ready to make; recipes worth more than one
  point show "+2" and come first among equals; a part of what is missing held by another character
  is counted; the list updates as you craft, buy or learn, and closes with the profession window.
- Weekly recap: loot the game had not described yet is still kept, and a week with no change in gold
  shows it in gray rather than as a gain.
- Login briefing, Weekly recap and Skill-ups are in the Tools menu, on the Tools tab, and have key
  bindings of their own.
- List windows: a line too long to fit is shown in full under the mouse, and the right-hand side no
  longer squeezes out the left.
- The whisper window closes with Escape, like every other window.
- The login briefing also says when your gear needs a repair (below 30%) or your bags have fewer than
  five free slots; click that line to open your bags.
- Skill-ups shows the profession and your skill in its title, such as "Tailoring 125/150".
- Weekly recap: most played character first; a character you only logged in on is left out.
- `/fgui textsize reset` and `/fgui uisize reset` put the size back to how it came.
- Quiet mode asked for during a fight comes on as soon as the fight ends.
- Buttons are named the same way everywhere: "Move panels", "Reset positions", "Role layout",
  "Share layout", "Run setup again", "Report a problem", "Raid tools", "Reset instances", "Show on map".
- Button labels fit their buttons in every language: a label too long is drawn a little smaller, and
  one still too long is cut short with "...", the whole of it in the tooltip. The chat's Copy button
  and the boss note's Edit button are as wide as their label needs.
- `/fgui pull` and `/fgui break` say what they take when given a word instead of a number, and keep to
  1 to 60 (seconds for a pull, minutes for a break).
- Depositing materials with none in your bags says so, instead of "Depositing 0 stacks".
- Mount and the talent-set switch say "Not during a fight" like everything else (the Korean and
  Chinese wording of the old message read as "you are not in combat").
- `/fgui spec` says so when the set does not exist or is the one you are in, instead of nothing.
- A recipe with no materials says so in the shopping list, instead of an empty window.
- Enter makes the profile in the New profile box, and previews a string in the share preview.
- The profile "Use" button and "Turn these on" have tooltips.
- The cursor ring does less work while the mouse is still.
- Fixed: most lettering styles changed nothing when picked on the Look tab until a /reload. The game
  opens a font file only while a loading screen is up, so every bundled face is now loaded with the
  add-on, and any lettering takes effect the moment you click it.
- Fixed: the bag window's Equip best button stood outside the window. The search box now takes the
  room the buttons leave, so the row ends inside the window (the bank's row too).
- The message after switching between theme families names Celestial instead of Runic.

**Polish: the whole add-on, file by file**
- Everything the add-on shows is now translated, in all eight languages: switch descriptions, theme
  names, option texts, the tour, the guide's answers (and the guide understands questions asked in
  your language), the report steps, the shopping and loot windows, the item counts in tooltips,
  boss and run times, times in days, hours and minutes, the info bar's durability and role, and
  the names of the add-on's key bindings in the game's Key Bindings window.
- Every message is a full sentence, and every panel's name is written the same way ("Cast bar",
  "Quest tracker", "Damage meter").
- Commands that take a number say so when it is wrong, and say what they did: removing a bag rule,
  mail rule, goal or talent build, `/fgui talents save` without a name, `/fgui send` with something
  that cannot be sent, `/fgui invword` with two words, `/fgui main` with a word it does not know.
- Forgetting a character in the Characters window takes two right-clicks, so it cannot happen by
  accident; the window can be dragged, and shows who has mail.
- Keybind mode says what a key did before, when you give it to something else.
- A click-cast change made in a fight says when it has been put in place; a summon held back by a
  fight says it will be taken when the fight ends; quiet mode says when it is off.
- The damage meter says it fills during a fight instead of being an empty panel, and
  `/fgui meter reset` works when it is a window of its own too.
- Your characters beside the mail window have tooltips, keep their class colors under the mouse, and
  explain the * on a character from another realm.
- The layout gallery's picture key says "accent color", as the pictures are drawn.
- Reputations at the top of their standing no longer show "0 / 0"; a web address in chat followed by
  a full stop no longer takes the full stop into the link.
- The friends list on the info bar says how many more are online when the list is cut short.
- Fixed: a new profile could share some of its settings (window places, info bar pieces, panel
  rules, bar settings) with every other profile made in the same session.
- Translations corrected: the tab names in every language now match the real tabs, the Chinese
  word for a gear set, and the German "your rules". The accent colors, the theme names, the tour,
  the problem report's steps, the profile messages (made, deleted, imported, why not), the click-cast
  buttons' names, the class color note on the Look tab and the "Done" mark in the quest log follow
  your language too.
- Messages that were English whatever your language now follow it: the login line, the self-test,
  the panel names of party and boss frames in move mode, the quest tracker's "Ready to turn in", the
  raid preview's players, the loot roll sample, and the Language button's tooltip.
- Action bars: the right-click menu is translated, the game's bars are named "Bar 1" to "Bar 8",
  "Pet bar" and "Stance bar", and when Edit Mode cannot be used the reason is a whole sentence.
- Custom alerts say plainly why one cannot be made (no such alert, needs a number, needs a buff or
  an ability, twenty is the most).
- Selling junk and repairing show the game's coin icons in their messages.
- Bag window: its title, the Grid and Categories button, the section headings, the free-slot count and
  the empty-slot tips follow your language; the bank's Tabs, Deposit and Blizzard bank buttons and
  Sell junk have tooltips; the bank tabs' tooltips are translated.
- The whisper window's reply box looks like the rest of the add-on and says what to type; friends'
  class colors in the friends list are exact.
- The notepad: clicking anywhere on the page puts the cursor in it. When the calculator cannot work
  something out, it says why in your language.
- Chat bubbles do far less work: their lettering is set only when its size changes.
- Buttons with a label color of their own (talent set buttons, the notepad's pages, your characters
  beside the mail window) keep it when the mouse leaves them.
- `/fgui language` lists Chinese among the choices; the quest log and tracker say in plain words when
  this game client cannot hand them its quests.
- The bags and characters windows' "nothing recorded yet" and "nothing matches" notes are translated.
- Fixed: a Health text option in the raid frame designer could show "table: 0x..." instead of its
  choice.

**Polish: a second look at every file**
- Fixed: chat messages from the add-on could start with its name twice ("Fantasy Glass UI: Fantasy
  Glass UI: ...").
- Fixed: the names in the game's Key Bindings window stayed English although their translations were
  there. They now follow your language, and change with it.
- Fixed: choosing "None" for chat timestamps in the game's settings was undone at every login. The
  add-on now switches timestamps on once, and leaves your choice alone after that.
- Fixed: on a game that does not report how much breath is left, the breath bar stood still. It now
  counts down by itself, and holds while the timer is paused.
- Fixed: the loss-of-control sample shown in move mode stayed on screen afterwards.
- Talent builds are learned one point at a time, lowest tier first, so a build is never refused for
  asking too much at once; a fight puts the rest on hold, and it says so.
- The storage window scrolls when a character has more than fits on the screen; its title and tabs
  are translated.
- The role display's alerts (execute range, aggro, low mana, low durability, who your target is
  attacking) are translated, and follow the color-blind setting.
- The color-blind setting now reaches every "good" and "bad" color: messages in the options, the
  raid check, the quest log, ready and missing marks, the cast bar's "Interrupted", the aggro and
  loss-of-control alerts, the swing timer's "out of range", the enchant check and the upgrade line
  on tooltips.
- Debuffs on you are framed in the game's color for what can remove them (magic, curse, poison,
  disease), red for the rest.
- A change of theme now reaches the options window's heading, the bag window's title, the swing
  timer bars and the buff alerts at once, without a /reload.
- The dividers on your class resource bar move with the player frame when you resize it.
- Switches and sliders keep their label inside the row in every language (cut short with "..." and
  shown whole under the mouse); search boxes and their hints fit their window.
- The quest log is translated throughout (levels, rewards, experience, choose one, track) and drawn
  in your theme's colors.
- "Objective complete", the raid tools' "To party" button, the options row of the action bar menu,
  the arena enemy names, the undo messages in move mode and the item and spell numbers on tooltips
  follow your language.
- On the Celestial minimap, the sun and moon ride inside the top edge instead of on it.
- Hiding the talking head also stops its voice; quest sounds play at your sound-effects volume.
- The keybind panel names buttons the way the game's Key Bindings window does.
- Raid and party frames say "Offline" and "Dead" in your language (the game's own words).
- The list of changes to a profile names each setting the way the options do ("Panel positions:
  Cast bar", "Fade when not in use: Bar 2"), with on and off in words, instead of its stored name.
- Nameplates: after a change in the nameplate designer, the target highlight kept working only on
  new plates; it now follows your target on every plate. More or fewer debuffs allowed show at once.
- Click-cast bindings saved without a modifier are no longer skipped.
- The boss note editor looks like the add-on's other text boxes, and a click anywhere in it puts
  the cursor in the note.
- The tour's cards stay on the screen beside a panel near its edge.
- "Where to level" says blue instead of green for your level when the color-blind setting is on.
- The group cooldowns panel keeps long names inside it, and uses the color-blind setting for
  cooldowns still running.
- The demo banner and the characters window's note fit in every language.
- The guide finds the answer about languages when asked in Italian, Portuguese, Russian, Korean or
  Chinese too.
- Chat bubbles have a Celestial look of their own: a small piece of night sky with a few stars, a
  fine line with a soft glow, and the small star at the top. (They were dressed as Fantasy bubbles.)
- The weapon imbue reminder appears and goes without fading when "Reduce motion" is on, and uses
  the color-blind setting.
- The role display shows a sample while you move panels, so it can be seen and placed.
- A layout kept for a screen whose size the game would not give is named "this screen" in the
  messages, instead of nothing.
- Fixed: opening the Combat tab emptied the buff alert boxes, so pressing Apply afterwards cleared
  your buff alerts. The boxes now show the list you saved.
- Fixed: in the custom alert editor, the box for the number or name always said "value"; it now says
  "a number" or "a name", whichever the alert needs.
- The Tools tab's sliders (master volume and the rest) show what is set each time the tab opens,
  so a volume changed in the game's own settings is shown right; showing it never changes it.
- The role names in the setup are translated, and so is "by" in the setup's and the options'
  headings, and the "custom" mark on class colors.
- After a preset on the Features tab, switches whose parent is now off are dimmed at once.
- A section name cut short in the list down the left of the options shows whole under the mouse.
- Clearing a place's theme under Theme by place puts the right theme back at once when you are
  standing there.
- The Reset positions button goes back to its name as soon as it has done its job.
- The theme card beside the Look tab's buttons stays on the screen.
- More good and bad colors in the options follow the color-blind setting (profile messages, "in use",
  layout import, the class suggestions on the Tools tab).
- The login briefing says "Only 1 bag slot free" rather than "1 bag slots".
- Fixed: switching "Mana & resources as numbers" changed the text on your frames only at the next
  change of mana; it now changes at once, as the health option always did.
- Debuffs on the player, target and focus frames and on the add-on's raid frames are framed in the
  game's color for what can remove them (magic, curse, poison, disease), red for the rest.
- The tank and healer marks on raid frames use the first letter of the game's own word for the
  role, in your language.
- Raid frames: a new ready check straight after another keeps its marks (the old one's timer no
  longer clears them); the sample players while previewing are laid out as the raid frame designer
  says (across or down, so many to a column, with its spacing).
- A new width from the frame designer moves the combo point dividers with it.
- With "Reduce motion" on, your frame's idle dimming and the login splash change at once, without
  fading.
- The ready-check report and finished goals follow the color-blind setting.
- The options row in the game menu list takes the current accent color after a theme change.

**Performance**
Every job the add-on repeats while you play was measured, with windows open and closed, in and out
of combat. With every window closed, the add-on now makes about a third of the garbage it made
before while you stand about, and well under half of it in a fight, so the game has less to
clean up after it.
- Chat bubbles are only looked for in the few seconds after someone speaks, rather than ten times a
  second all the time.
- The class resource (combo points, holy power, chi and the rest) now changes the moment the game
  says it has, and no longer rebuilds its settings ten times a second.
- The buff row is redrawn once a second only while a weapon enchant is ticking down. Everything
  else on it is redrawn when your buffs change.
- An open right-click menu is cheaper: its submenus are found by a signature worked out once per
  menu, and the screen is searched for them ten times a second rather than twenty.
- An open quest dialog is relit without making new lists ten times a second.
- Fixed: after a profile switch, the class resource kept the old profile's width and spacing until
  you changed one of them.

## 11.10.0

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

## 11.9.1

**Changed**
- The setup's theme buttons show a small picture of each theme, as the Look tab does.
- The home key now rechecks your cooldowns at most every ten seconds instead of after every cast;
  new spells and items are still picked up at once.
- After a long break, What's new shows the five newest releases and how many more there were,
  not a wall of every update since.
- The boss note closes with Escape, and puts itself away when the boss fight ends.
- Hover help on the Profiles tab's newer buttons: Copy my whole UI, Send whole UI, Backups,
  Changes to this profile, and the new-character settings.
- The death recap writes big numbers with separators (12,345).
- Auction prices you have not seen for two months are let go, so the saved list stays small.
- Spelling is American English throughout (gray, favorite), as in the game.
- `/fgui help` opens a window you can search: `/fgui help bags` shows only the commands about
  bags, and clicking one puts it in chat for you.
- The Tools menu (and the palette) is sorted into groups with headings: groups and raids, your
  characters, bags and gear, people and notes, the world, and the add-on itself.
- A new switch on the Features tab turns off the "loaded" line in chat at login.
- The death recap says what kind of damage each hit was (fire, shadow, physical…).
- The ready check reads "ready" in every language the add-on speaks.
- Boss notes can be deleted from the list: right-click one twice.
- Equip best says what it put on.
- Group practice shows a banner with the time left; click it to end practice.
- Performance notes skip fights shorter than ten seconds.
- Worth selling shows what everything on the list comes to.
- Weapon imbues, the cooldown timeline and the nameplate target mark do less work when nothing
  is changing; the target mark follows a new target at once.
- Equip best, Sort bags and switching talent builds, asked for during a fight, now happen as soon
  as the fight ends instead of just saying no.
- A mistyped command no longer opens the options: `/fgui equipbets` asks "Did you mean
  /fgui equipbest?", and a word that is not a command shows the commands that mention it.
- List windows (help, boss notes, worth selling and the rest) stay where you drag them, for all
  your characters, and can't be dragged off the screen.
- Hover help on the add-on's buttons in the game's windows: the bag window's Slots, Bank, Guild,
  Chars and Equip best; the auction house's Worth selling and Lowest -1c; Send by my rules on
  the mailbox; the boss note's Edit and Send to my group.
- `/fgui help bags` names the word in the window's title.
- The waypoint arrow's distance is rounded to the nearest yard.
- **Every message is translated.** The chat messages, hints and window notes that were still in
  English (about 330 of them) now come in all eight other languages, so a German, French,
  Spanish, Russian, Portuguese, Italian, Korean or Chinese game no longer mixes languages.
- `/fgui reset` asks first: type it twice within ten seconds. A backup is kept before it
  ("Before the last reset"), so `/fgui backup restore reset` undoes it.
- Five new key bindings (Esc, Key Bindings, AddOns): the Tools menu, Equip best, the death recap,
  the boss note for your target, and every command.
- The minimap button: Shift-click opens the Tools menu, the tooltip shows the version and says it
  can be dragged, and it says when safe mode is on.
- Hover help on every Tools menu button, taken from the help, with the command to type.
- More hover help: Collect gold and Open all on the mailbox, Reset Instances, a gallery
  layout's Use, and the notepad's two pages.
- Windows that were empty now say why, and what to do: player notes, recent group mates, rolls,
  gold history and the loot log.
- Times read the same everywhere, in your language: "just now", "12 min ago", "3 days ago",
  "1 d 4 h" (backups, setting history, recent group mates, lockouts, the bank's "recorded").
- The death recap starts with the damage you took in its last seconds.
- Worth selling shows what a whole stack comes to, with the price each beside it, and hover
  help with the auction and vendor prices.
- Equip best says once which upgrades it left for you because they aren't bound yet, instead of
  a line for each.
- The options open on the tab you used last.
- List windows make the game's open and close sounds, and every window of ours that can be
  dragged stays on the screen, the Tools menu too.
- The quest log's Share says what is wrong: you are not in a group, or the quest can't be shared.
- Clearer wording: "1 letter emptied" / "3 letters emptied" (no more "letter(s)"), click-cast and
  buff alert counts, and the message when the quest tracker falls back to the game's.
- `/fgui help` describes `/fgui backup` and `/fgui reset` as they work now.

**Fixed**
- In the setup, Runic themes showed "Runic:" in front of their names.
- A boss note that never finished arriving from the group was kept until you logged out.

## 11.9.0

**New**
- **Runic art:** with a Runic theme, the class emblems are carved on a stone disc inside a broad
  band of runes, the minimap sits in a band of runes (a ring of them when it is round), the action
  buttons have carved edges with cut corners, and runes run along the foot of each action bar.
- **Theme previews** on the Look tab: each theme's button shows a small picture of it (its panel,
  edge, accent and family mark), and pointing at one shows a larger card with a title, text and a
  button in that theme's colors.
- **Check of the new features** (`/fgui check new`, the Tools tab or the Tools menu): tries each
  feature added since 11.6 and reports, line by line, what works, what is switched off, what needs
  a place or a moment (the auction house, a fight) and what to look at, as text to copy and send.

## 11.8.1

**Fixed**
- The language list showed only one language's name, with the rest of the buttons empty
  (in 11.8.0, with any theme).

## 11.8.0

**New**
- **Runic themes**, a third family beside Glass and Fantasy: 38 themes of carved stone, from
  Granite and Basalt to Bloodstone, Voidrune and Felstone, plus one in your class color. Each panel
  has a stone grain, an engraved edge, runes glowing in the accent color from its foot, and a
  glowing rune-stud in each corner; buttons are carved keys. On the Look tab and in the setup, and
  your own themes can be runic too. That makes 114 themes.

**Fixed**
- Korean (한국어) and Simplified Chinese (简体中文) showed as empty boxes in the language list. They
  are now written in the game's own font, which has their letters.

## 11.7.0

**New**
- **Am I ready?** (`/fgui ready me`, the Tools tab or the Tools menu): one panel before a raid with
  food, flask or elixir, weapon oil or imbue, repairs, your class's reagents, bag space, and your
  talent set and gear set. Out of fights only, as the game hides buffs in them.
- **Boss notes** (`/fgui bossnote`): a note of your own for each boss. It opens when you target the
  boss, when the fight starts, or with a pull timer. The group's leader or an assistant can send
  theirs to the group; a note sent to you sits beside your own. `/fgui bossnote list` shows them all.
- **Death recap** (`/fgui death`): the hits and heals you took in the seconds before you died.
- **Auction house helper:** "Lowest -1c" on the sell page, and "Worth selling" (`/fgui ah`), what in
  your bags sells for more there than at a vendor; click one to put it on the sell page. Tooltips
  add the usual price over the days you looked. Posting is still your own click.
- **Home key** (Key Bindings, AddOns): the best way home that is ready: your hearthstone, then Astral
  Recall, then a teleport. `/fgui home` says which it would use.
- **Backups of your settings**, made by themselves before each update and once a day. `/fgui backup`
  lists them; `/fgui backup restore daily` (or `update`) puts one back, keeping what you had first.
- **Changes to this profile** (`/fgui history`, or the Profiles tab): what you changed and when.
  Click a change to undo it.
- **Whole-UI packs** (`/fgui pack`, "Copy my whole UI" or "Send whole UI" on the Profiles tab): the
  profile, layout, theme, bar setups, frame designs, bag rules, mail rules and the game's Edit Mode
  layout in one string. Pasted into the preview, it becomes a profile of its own.
- **Role templates** on the Profiles tab: a new Tank, Healer or Damage profile with your look kept,
  the frames placed for the role, and the switches that suit it on.
- **Coming from another UI?** in the setup's layout step: one click for the setup closest to ElvUI
  or Tukui, RealUI, GW2 UI or the game's own. An add-on of those found in your list is marked.
- **Measure a fight** (`/fgui perf fight`): measures the add-on through your next fight, with the
  group's size and your frame rate, then gives a report to copy and send.
- **What each feature costs at login** (`/fgui perf load`, and in the self-check): the time each
  feature took to start and the memory it took then.

## 11.6.0

**New**
- **Group practice** (`/fgui testgroup`, the Tools tab or the Tools menu): five made-up group mates
  for five minutes, so the group cooldowns panel, the interrupt rotation and buff coverage on raid
  frames can be seen, placed and tried on your own. They take turns to interrupt; on your turn use
  your own interrupt. Nothing is sent to anyone. Ends when a fight starts or you join a group.
- **Arena enemy frames** (Features tab, off until you choose them): up to five, in place of the
  game's own. Left-click targets, right-click sets focus.
- **Enemy cooldowns** (Features tab): in arenas and battlegrounds, an enemy player's PvP trinket,
  interrupt and dispel, counting down once used. Beside the arena frames, and under your target and
  focus frames.
- **Upgrade arrows** on loot rolls, quest rewards and the game's own bags (the one-window bags
  already had them), and "Upgrade: +N item level" on item tooltips.
- **Equip best** (`/fgui equipbest`, or the button on the one-window bags): puts on every upgrade in
  your bags. Only gear already bound to you, so nothing gets bound; weapons only for the same kind.
- **New characters get their own setup**: a copy of your main's, fitted to their class (a role the
  class can play, that role's layout, the switches suggested for the class). `/fgui main` or the
  Profiles tab chooses your main; the Profiles tab can switch it off.

**Changed**
- The execute line only shows on a target you can attack.
- The translations are a third folder, `FantasyGlassUI_Locales`, loaded only for players who use a
  language other than English. Keep all three folders together in `Interface/AddOns`.
- The options code is split into smaller files, so the options window is easier to keep working.

## 11.5.0

Everything since 10.0.0, in one list.

**New**
- **Fantasy Glass action bars** (off until you switch them on on the Features tab; a `/reload`
  either way): eight bars of real action buttons made by the add-on in place of the game's.
  - Each bar has its own number of buttons, rows, button size, spacing and direction, set at once
    without the game's Edit Mode.
  - Bar 1 changes page with stance, form, stealth, vehicles and possession.
  - Your key bindings press them and keybind mode binds them. When a bar shows, its size, opacity,
    key text, macro names and moving all work as for the game's bars.
  - Choose which bars you use: "Use this bar" on the Bars and frames tab. A bar that is off is
    hidden altogether; its keys still press its buttons.
  - A stance bar of their own too, with a button for each stance, form or aura you have. Your
    stance bar key bindings press it.
- **Bars and frames tab** (`/fgui bars`): every action bar, every unit frame, the nameplates and the
  raid frames, listed down the left.
  - **Each bar** has its own size, opacity, key text, macro names, and when it shows: always, when
    pointed at, in combat, out of combat, with a target, or never.
  - **Rows, buttons shown, button size, spacing and direction** are set here too. For the game's
    own bars, "Apply to the bar" writes them into your Edit Mode layout. That needs a layout of
    your own, because the game's two presets cannot be changed.
  - **Frame designer:** each unit frame's width, height, power bar height, text size, portrait
    side, and where its name and health text sit.
  - **Nameplate designer:** width and height, name size or no names, where the health text sits
    and its size, cast bar height and text size, debuff icon size and how many show, threat colors,
    and the mark on your target's plate.
  - **Raid frame designer:** size, space between frames, players in each column, down or across,
    order, and name and status text sizes. Where the game's own raid frames are used, their
    lettering and the game's raid frame settings (power bars, class colors, pets, only debuffs you
    can remove, aggro highlight, health text).
- **New class emblems**, made for Fantasy Glass UI.
  - Each class has its own animated sigil on a glass disc in the class color, over a glow that
    breathes.
  - A ring in your accent color turns slowly around it: a clean line in the Glass themes, a ring of
    runes in the Fantasy ones. Motes of light circle it.
  - The animations: swords meeting, a bow drawn and loosed (with proper feathers on the arrow), a
    crackling lightning bolt, the Warlock's original flickering flame, and more.
  - The class color editor shows the same medallion.
- **Tools tab** (`/fgui tools`):
  - A button for every window that otherwise needs a command.
  - Editors for your lists (buff reminders, hidden buffs, chat keywords, restock).
  - A font and a bar texture from other add-ons.
  - Sliders for the execute line, the smaller world map and the master volume, and the raid frame
    order.
  - Switches suggested for your class.
  - **Your rules:** bag rules, mail rules, checklist jobs and talent builds, each made, reordered,
    used or removed right there, without typing a command.
- **Ask the guide:** type a question in plain words, at the top of the Tools tab or with
  `/fgui ask`. It names the feature or command, and "Show me" takes you to it.
- **Layout gallery:** six whole-screen setups, each drawn as a picture of the screen and put in
  place with one click: Classic, Healer raid, Tank, Wide screen, Minimal and Streamer. Open it with
  `/fgui gallery`, the Layout tab or the Tools tab; `/fgui undo` takes one back.
- **Custom alerts** (Combat tab, under Behavior): low health, low target health, low mana, a buff
  missing or on you, an ability ready, your target casting, combat, bags nearly full or worn gear.
  Each can show a line, play a sound and say it.
- **Spoken alerts** (off until you switch them on): the game's text-to-speech voice reads out ready
  checks, whispers, missing buffs, loss of control and your custom alerts. Choose which on the
  Combat tab, under Behavior. `/fgui speak` tries the voice.
- **Fourteen more game settings as switches** (Features tab, Game settings):
  - Auto loot, loot window at the mouse, auto self-cast.
  - Nameplates from further away, stacking nameplates.
  - A camera that stays where you turn it, clear weather, no gray screen when dead, less screen glow.
  - A lower frame rate when tabbed out.
  - No tutorial pop-ups, profanity filter off, mute the music, mute ambient sounds.
  - Each remembers what the setting was and puts it back when switched off. None changes during a
    fight, and the presets leave them alone.
- **Theme by place:** a theme for cities and inns, dungeons, raids and everywhere else, switched to
  by itself as you travel.
- **Checklist** (`/fgui checklist`, or the Tools tab): your own daily and weekly jobs, ticked per
  character and cleared by themselves at the game's resets, with your lockouts, once-a-day crafts
  that are ready, and how far your other characters have got.
- **Session card** (`/fgui session`): time played, XP an hour, gold, items looted, quests, kills and
  deaths, with your last session underneath.
- **Quest rewards on the tracker:** each quest's experience and gold beside its name.
- **Ready-check report:** who is missing food, a flask or elixir, or a class buff. It appears when
  a ready check starts, or any time with `/fgui ready`.
- **Rare spawn memory:** rares and treasures the rare alert spots are marked on the world map.
  `/fgui rares` lists them; click one for a waypoint.
- **Crafting queue** (`/fgui queue`): queue recipes and get one shopping list for everything.
- **Goals panel** (`/fgui goal`): reputations and items you are working towards, each with a bar.
- **Where to level** (`/fgui level`): the zones that suit your level, new zones included.
- **Profession cooldowns** (`/fgui profcd`): once-a-day crafts on all your characters, with a
  notice when one is ready.
- **Cooldown timeline** (off until you switch it on): your tracked abilities slide along one bar
  towards ready.
- **Combat text in your lettering** and a **login splash** (both off until you switch them on).
- **Tour:** a short tour of the interface after the setup. `/fgui tour` plays it again.
- **What's this?** (`/fgui whatsthis`, or its own key binding): point at any panel to see which
  feature made it. Click to go to its switch, or right-click to switch it off.
- **Performance view** (`/fgui perf`): how much time each part of the add-on takes, heaviest first.
- **Live self-test** (`/fgui selftest`): works through the add-on in the game and lists what passed
  and what did not.
- **Four more languages:** Italian, Portuguese, Russian and Korean, besides German, French and
  Spanish.
- **API for other add-ons:** `FantasyGlassUI_API` lets other add-ons add info bar pieces, themes,
  commands, Tools tab windows, guide answers and movable panels, and dress their windows in this
  add-on's look. See `API.md`.
- **Tools on the Menu button:** "Tools" in the Menu button's list opens a small panel with a button
  for every tool window, so they open without going to the options. `/fgui toolmenu` too.
- **Pull and break timers** (`/fgui pull 10`, `/fgui break 5`, or the Tools tab): a big countdown
  for everyone in the group who has the add-on. A pull also starts the game's own countdown.
- **Battleground helper** (Features tab): your time in the queue and the game's estimate, how long
  an invitation has left, and a countdown to the start of the battle. `/fgui bgscore` shows the score.
- **Interrupt rotation** (Features tab, off until you choose it): a small bar in a group saying
  who is next to interrupt, and telling you on screen (and aloud, with spoken alerts on) when it is
  you. `/fgui kicks <name> <name>` sets the order; the group leader's order is shared.
- **Class resource designer** (Bars and frames tab, Class resource): combo points, holy power, soul
  shards, chi, arcane charges, essence or runes as dots, one bar or a number, any size, anywhere.
- **Professions on all your characters** (`/fgui crafts`, Tools tab): what each character can make,
  searchable, and "Made by" on item tooltips.
- **Key binding sheet** (`/fgui keys`, or hold its key): every action bar with each button's key
  and what it does, on one screen.
- **Buff coverage on raid frames** (Features tab, off until you choose it): a small mark on anyone
  missing the buff you can give (Fortitude, Mark of the Wild, Arcane Intellect, Battle Shout).
- **A layout for each screen size** (Layout tab, Share Layout): laptop and desktop each keep their
  own panel layout, switched by themselves.
- **Quiet mode** (`/fgui quiet`, the Tools tab, or a key): chat, names over heads and the info bar
  out of sight for screenshots and streaming, and back as they were.
- **Simplified Chinese** (简体中文), and every language now covers the whole options window.
- **Group cooldowns** (Features tab, off until you choose it): a panel listing who in your group
  has a battle resurrection, an interrupt, a big defensive or a raid cooldown, and whether it is
  ready. Group members with Fantasy Glass UI tell each other; nothing the game hides in a fight is
  needed.
- **Send your setup to another player** (`/fgui send <name> layout`, or the Profiles tab): your
  layout, profile or theme goes straight to them in game, and opens in their preview, where they
  choose whether to take it.
- **Totem bar for Shamans:** a button for each element. Left-click drops the totem chosen for it,
  right-click takes it away, the mouse wheel chooses another; the totem that is down shows its time.
- **Aura designer** (Bars and frames tab, Auras): for the target, focus and player frames, what
  shows (buffs and debuffs, debuffs, buffs or nothing), only your own debuffs, how many, how big,
  above or below, growing right or left. For raid frames, your heals over time, the debuff icon and
  the cleanse highlight; for nameplates, all debuffs or only yours. Auras you never want to see go
  on the "Hidden on frames" list (Tools tab, or `/fgui hideonframe <name>`).
- **Sort bags** (`/fgui sort`, the Tools tab or menu, or a key): your bags in the order of your bag
  sections, your own rules first, best quality first inside each. Special bags are left alone.
- **Reputations and currencies on all your characters** (`/fgui reps`): pin the ones you care about
  and see every character's standing or amount side by side.
- **Mount and pet buttons** (Features tab, off until you choose them): a random favorite mount and
  a random favorite pet, as two small movable buttons and as key bindings.
- **Send a talent build** (`/fgui talents send <player> <build>`): it arrives with their builds,
  for their class only, and nothing is learned until they choose it.
- **Goals of your own and achievements on the goals panel:** `/fgui goal add 50 <goal>` (click it
  to count up, right-click to count down), and `/fgui goal ach <achievement>` where the game has
  achievements.
- **Raid composition** (`/fgui comp`): tanks, healers and damage, the group's classes, and who covers
  each group buff, dispel and battle resurrection.
- **Bag rules** (Features tab): ready-made bag sections to switch on: Upgrades, Gear sets, Bind on
  equip, materials by kind, potions, food and scrolls apart, and Recipes. Your own rules (by item
  level, bind on equip, gear set, quality, kind of item or name) come first, in the order you choose.
- **Mail rules** (Features tab): switch on each material to send (cloth, leather, ore, herbs, cooking,
  elemental, enchanting, gems, potions and food) and type who it goes to. One button at the mailbox
  sends it all. Your own rules ("all silk to my tailor") are sent too.
- **Events and holidays** (`/fgui events`): the game's calendar for the next two weeks. Holidays that
  are on go on your checklist by themselves and come off when they end.
- **Talent builds** (`/fgui talents`): save your talents under a name and learn them again with a click.
- **Preview a shared string** (Tools tab): see a profile, layout or theme string's panels and colors
  before you take it.
- **Hide the game's raid manager** (Features tab, Combat and groups, off until you choose it): the
  panel that slides out from the left edge of the screen in a group.
- **Pixel-perfect scale** and **a round minimap** (Features tab, off until you choose them).
- `/fgui buttons` lists the buttons gathered into the Add-ons panel and how the game draws each one.
- A **Guide** tab: quest guides are coming soon.

**Changed**
- **A lighter, more modern options window.**
  - Tabs are plain names with a line under the open one. Every tick box is now a sliding switch.
  - The search box is at the top, and your role and profile are in the footer. Searching opens the
    section a setting is in.
  - The window is a little wider.
- **Most tabs show one section at a time**, listed down the left. Features shows how many switches
  in each section are on, with a card that explains the switch under the mouse. Layout, Profiles
  and Tools stay single pages.
- **Fewer tabs:** Features, Look, Layout, Combat, Profiles, Bars and frames, Tools and Guide.
  - Click casting is now a section of the Combat tab. `/fgui clickcast` still opens it.
  - Class colors are on the Look tab, together with the portrait choice. `/fgui colors` still
    opens them.
  - Accent, lettering, the game menu and bars, making your own theme, and theme by place are one
    Look section: Accent and style.
  - The Combat tab's Behavior section also holds the AFK screen's timing, custom alerts and spoken
    alerts.
- The info bar's list of pieces is in two columns.
- Health, mana and XP as numbers instead of percentages are switches on the Features tab (Frames)
  now, not on the Combat tab, and take effect at once.
- The Profiles tab is one page: your profiles, a new profile and sharing all at once, with a button
  to preview a shared string before importing it.
- The Tools tab has buttons for the new windows, and pull and break timers under "Do something once".
- `/fgui alts` opens your characters from anywhere the tool commands work.
- "Target: only my debuffs" has moved from the Combat tab into the aura designer.
- The Features tab has 11 sections instead of 18: Frames, bars and nameplates; Action bars; Combat
  and groups; Minimap and info bar; Windows, tooltips and quests; Look, sounds and notifications;
  Chat and people; Bags and bag rules; Vendors, trainers and mail; Done for you; Game settings.
- Lighter on the game: the add-on's action bar buttons and class emblems are only brought up to
  date while they are on screen.
- The setup's language choice is one button that lists every language.
- Finishing the setup always reloads the interface, so everything you chose is in place at once.

**Fixed**
- Buttons in the Add-ons panel under the minimap looked grayed out (DBM, Questie, RestedXP and
  others). They now sit in front of the panel, and a hidden button no longer leaves a gap.
- Class emblems stopped animating or stuck on one frame. The game's own animation system now moves
  them, and `/fgui check` says how many are moving.
- A piece unticked in the info bar's list (gold, clock and others) stayed on the bar.
- Cutscenes were covered by a dark window frame with corners. Cutscenes, movies and anything else
  that fills the screen are now left exactly as the game shows them.
- "Interface action failed because of an AddOn" during fights and reloads. Parts of the game the
  add-on hides (its action bars, menu buttons and others) are now only made invisible and
  unclickable, never hidden by the add-on, so the game can still move and show them in a fight.
  The game's bars and buff rows you have moved are moved in a way the game's Edit Mode does not
  notice, so it can still show and place them in a fight (the stance bar's buttons, action bar 2,
  the totem bar). The Fantasy Glass action bars no longer count a failed action each time the
  mouse passes over a button during a fight, and the game's stance bar is no longer refused in
  fights while they are on: their buttons are no longer made from the game's own action button
  template, which signed them into a list the game's bars share.

## 10.0.0

Fifty-eight additions, thirty more themes and fifteen more lettering styles. What only adds information is on; anything that puts a new panel on screen, makes a sound or acts for you is off until you choose it on the Features tab. `/fgui help` lists every command.

**New: combat**
- **Missing buff reminder.** `/fgui remind Lightning Shield` and an icon shows while that buff is missing.
- **Focus cast alert** (off until chosen): a sound and a line on screen when your focus starts a cast.
- **Execute line** (off until chosen): a line on the target's health bar at 20%, or wherever `/fgui execute` puts it.
- **Loss-of-control alert** (off until chosen): a large icon and countdown while you are stunned, silenced or feared.
- **Keys for your best potion and food.** Two key bindings (Key Bindings > AddOns): one uses a healthstone or your best healing potion, the other eats and drinks your best food.
- **Boss and dungeon timer** (off until chosen): time on the boss and in the run, with your best times remembered.
- **Queue alert.** A dungeon finder or battleground invitation gets the same hard-to-miss alert as a ready check.
- **Combat log in raids** (off until chosen), with a second switch for dungeons.
- **Buff filter.** `/fgui hidebuff Well Fed` leaves a buff out of your buff row. Your own debuffs on other units are rimmed in the accent color.
- **Screenshot on boss kills and achievements** (off until chosen).

**New: groups**
- **Notes on players.** `/fgui note good tank` with a player targeted; the note shows in their tooltip and when they join your group.
- **Recent group mates.** `/fgui recent`: click to whisper, right-click to invite.
- **Roll tracker.** `/fgui rolls` lists everyone's /roll, highest first, and names the winner.
- **Raid frame order.** `/fgui raidsort group`, `role` or `name`.
- **Who is missing.** `/fgui missing` lists group members who are offline or somewhere else.
- **Lockouts.** `/fgui lockouts`: which raids and dungeons each of your characters is saved to.
- **Group notices** (off until chosen): a line and a sound when someone joins or leaves.
- **Reset Instances** button under the raid tools panel (also `/fgui resetinstances`).

**New: map and travel**
- **Waypoints.** `/fgui way 45 62 the cave`: an arrow with the distance.
- **Travel bar** (off until chosen): your hearthstone and every teleport or portal you know.
- **Mount key.** A key binding, or `/fgui mount`, for a random favorite mount.
- **Flight timer.** A bar for the time left on a flight path; each route is learned the first time you fly it.
- **Fishing mode** (off until chosen): loud splash, quiet music, auto-loot, while a fishing pole is equipped.
- **Smaller world map** (off until chosen) that fades while you move.
- **Your group on the world map** as dots in class colors.
- **Minimap:** right-click for the tracking menu, and the name of whoever pinged.

**New: bags, gold and trade**
- **Restock list.** `/fgui restock [item] 5`: bought whenever a vendor sells it and you have fewer.
- **Gold history.** `/fgui gold`: your gold day by day, and where this session's gold came from and went.
- **Shopping list.** `/fgui shop` with a recipe selected: what it still needs, counting bank and other characters.
- **Gear set mark.** Items in a saved gear set say "Set" in the bag window and are never sold as junk.
- **Open-all button** (off until chosen) for clams, lockboxes and bags of loot.
- **Trade log.** A line in chat after each trade; `/fgui trades` looks back.
- **Deposit** button in the bank window: every crafting material goes in.
- **Auction prices in tooltips:** the lowest price you last saw for the item.
- **Loot log.** `/fgui loot`: everything looted this session and its vendor value.

**New: chat**
- **Keyword alerts.** `/fgui keyword LFM` picks that word out in any channel, with a sound.
- **Hide repeated lines** (off until chosen).
- **Alt-click a name in chat to invite.** The right-click menu gains Copy name and Guild invite where the game allows.
- **Whisper window** (off until chosen): a tab for each conversation and a line to answer in.
- **Chat tabs.** `/fgui chattabs` makes a Loot tab and a Whispers tab.
- **Short commands:** `/rl`, `/rc`, `/tt`.
- **Guild and friend notices** (off until chosen).
- **Friends list in class colors,** with level and zone.

**New: characters and tools**
- **More about each character** in `/fgui alts`: point at a line for item level, rested experience, professions, mail and when it was last played.
- **Talent set buttons** on the character window (also `/fgui spec`).
- **Missing enchants** (off until chosen): an E or G on gear with no enchant or an empty socket.
- **More info bar pieces:** hearthstone cooldown, a currency, time to the daily reset, volume. Right-click the info bar.
- **Notepad** (`/fgui notepad`), **to-do list** (`/fgui todo`) and **calculator** (`/fgui calc 20*45`).
- **Fonts and bar textures from other add-ons** through LibSharedMedia: `/fgui media`, `/fgui font`, `/fgui bartexture`.
- **Mute a sound** by its file number: `/fgui mute`.
- **Lower graphics in raids** (off until chosen), put back when you leave.
- **Add-on memory.** `/fgui addons`.
- **Talking head:** hide it or move it (two switches, off until chosen).
- **More key bindings:** the damage meter, your characters, notepad, to-do list, whisper window and the first four consumables buttons.

**New: themes and lettering**
- **Fifteen more glass themes:** Sapphire, Ruby, Topaz, Pearl, Obsidian, Mint, Lavender, Copper, Deep sea, Cherry blossom, Lime, Indigo, Steel blue, Mocha and Void (black and purple).
- **Fifteen more fantasy themes:** Frostfire, Emerald Dream, Shadow, Titan, Lightforged, Nether, Tundra, Jungle, Molten, Tidal, Wine, Ashen, Oak, Stormcaller and Starlight.
- **Fifteen more lettering styles.** Plain: Narrow, Future, Soft, Military, Circuit, Blocky, Heavy titles, Arcade. With character: Imperial, Chronicle, Roman, Medieval, Illuminated, Warband, Knightly. Chronicle and Roman also have Cyrillic letters.
- That makes 76 themes and 34 lettering styles, all on the Look tab (`/fgui look`) and in the setup.

## 9.8.0

**New**
- **Quest marks on nameplates.** A yellow "!" beside the nameplate of anything you still need for
  a quest, so it can be picked out of a pack at a glance.
- **Cooldown pulse.** When an ability on the cooldown tracker comes off cooldown, its icon appears
  in the middle of the screen for a moment. Place it in move mode.
- **Ready check alert.** A sound that plays even with the game in another window, the game's icon
  flashing in the taskbar, and a notice saying who asked.
- **Consumables bar** (off until chosen): a small bar that fills itself with the potions,
  bandages, food and drink, flasks, elixirs and scrolls in your bags, one button each, with how
  many you have. It is laid out again between fights. Place it in move mode.
- **Your characters.** `/fgui alts` lists every character you have logged in with: level, class
  and gold, richest first, with the total. Right-click a line to forget a character.
- **Timers.** `/fgui timer 5m tea` puts a countdown bar on screen and tells you when it ends
  (also `90s`, `1h30m`, `2:30`; a bare number is minutes). Up to six at once; click a bar to
  cancel it. They carry on after a reload.

## 9.7.0

**New**
- **Damage meter: a player's abilities.** Point at a row to see what that player's damage (or
  healing, or whatever the view is) was made of.
- **Damage meter: earlier fights.** Right-clicking the heading now goes through this fight,
  overall, and the earlier fights the game still has.
- **Vendors mark what you already know.** A recipe, pattern, mount or pet on sale that you have
  already learned is washed in red.
- **Combat start and end alerts** (off until chosen): "+ Combat" and "- Combat" in the middle of
  the screen for a moment. Place it in move mode.
- **Movement speed on the info bar** (off until chosen): right-click the info bar and tick
  "Movement speed".
- Two more helpers under "Done for you" on the Features tab, each off until you choose it:
  - *Confirm bind-on-pickup loot when alone*: in a group it stays a question. Hold Shift as you
    loot to be asked all the same.
  - *Accept role checks*: when the group finder asks, your role is confirmed as you last set it.

## 9.6.0

**New**
- **More views for the damage meter**: damage taken, absorbs, interrupts, dispels, deaths, and
  plain damage and healing totals, alongside damage and healing per second. Click the heading or
  roll the mouse wheel over it to step through them; the view is remembered.
  - Your own row has a white edge.
  - Shift-right-click the heading, or `/fgui meter reset`, clears the meter.
  - "Damage meter: open in combat" (off until chosen): the drawer comes out as a fight starts and
    tucks itself away eight seconds after it ends.
- **Ground markers in the raid tools**: a second row with the eight world markers and an X that
  clears them all.
- Three more helpers under "Done for you" on the Features tab, each off until you choose it:
  - *Gear sets follow my talent set*: each talent set remembers the gear set you last put on while
    it was active, and puts it on when you switch back. Nothing to set up.
  - *Invite by whisper*: a friend or guildmate who whispers "inv" is invited to your group.
    `/fgui invword` changes the word; "Whisper invites: from anyone" widens it.
  - *Decline duels*: turned down for you, with a line in chat saying who asked. Hold Shift as one
    arrives to answer it yourself.

## 9.5.6

**New**
- **Crafting bar and profession icons.** While you craft, the progress bar in the profession
  window is in our style, and its icon is the profession's own (leatherworking, alchemy, cooking
  and the rest) instead of the game's placeholder. The ordinary cast bar shows the same icon while
  you craft.
- **The damage meter is a drawer on the chat box.** It comes out of the side of the chat box,
  as tall as the chat box, and the small tab on its edge tucks it away or brings it out
  (`/fgui meter` does the same). It comes out on whichever side faces the middle of the screen.
  - It now reads **damage per second** (and healing per second) instead of totals, as a whole
    number.
  - **Threat on your target** is listed under the bars: the three highest in your group, when
    you are in a group and fighting something.
  - Click the heading to switch between damage and healing; right-click for this fight or overall.
- **Gear set buttons.** A row under the character window with a button for each set saved in the
  game's equipment manager. One click puts a set on. The set you are wearing is underlined, and a
  set with missing pieces is gray.
- **Five more helpers under "Done for you"** on the Features tab, each off until you choose it:
  - *Stand up when an action needs it* and *Dismount when an action needs it*: when something
    fails because you are sitting or mounted, that is put right and the next press works. Never
    off a mount in the air or on a flight path.
  - *Accept resurrections*: one cast by someone who is in a fight is left for you to time.
  - *Accept summons*: after five seconds, with a line in chat saying who and where. Decline it in
    that time to stay. Hold Shift as a resurrection or summon arrives to answer it yourself.
  - *Greed on green items*: rolls Greed for you on uncommon items. Blue or better, anything that
    binds when picked up, and gear better than what you are wearing are left for you.
- **Game settings.** A new section on the Features tab with four of the game's own settings as
  switches, each off until you choose it: maximum camera distance, mute the error voice ("Not
  enough mana"), sound when tabbed out, best-quality screenshots. Switching one off puts the
  setting back as it was.
- `/fgui blocked` lists anything the game refused to let the add-on do, and where it came from.
  The self-check (`/fgui check`) shows the same.
- `/fgui memory` shows how much memory is in use.

**Changed**
- The options window, the guided setup and the self-check now load only when you open one of them,
  so the add-on uses less memory the rest of the time.
- The download is now two folders, `FantasyGlassUI` and `FantasyGlassUI_Options`. Keep both in
  your AddOns folder. If the second is missing or switched off, the add-on tells you.
- Chat history now covers every chat tab, not only the main one, and has its own switch
  ("Chat: keep lines across a reload"). The combat log is not kept.
- The chat typing bar now sits under the chat box, where the game puts it. Above the chat box it
  covered the chat tabs, which could not be clicked while you typed. "Chat: typing bar above the
  chat" on the Features tab puts it back on top.
- To keep the damage meter as a window of its own that you place in move mode, switch off "Damage
  meter: drawer on the chat box" on the Features tab.

**Fixed**
- "Interface actions failed because of this AddOn" in the game's add-on list was counting up
  during fights. The quest tracker no longer resizes its locked frame in combat, and the bag
  window opens and closes in combat again instead of retrying.
- The Menu button, the "Show on Map" button and the L key no longer try to move or close things
  the game has locked for the length of a fight.
- Right-clicking the info bar opened the options instead of the list of its pieces.
- Setting a target marker from the raid tools brought up "FantasyGlassUI has been blocked from an
  action only available to the Blizzard UI". The marker buttons now work the way the game
  requires, and the raid tools panel can be opened and closed during a fight.
- An action bar you had moved could jump to the game's default place during a fight (seen on a
  paladin, whose aura bar makes the game re-lay its bars) and only come back afterwards. A moved
  bar is now held where you put it through the fight.
- Buffs and debuffs on the target, focus and party frames ran their timer sweep backwards (gray
  first, brightening). They now start in full color and darken as they run out, like everywhere else.
- Three errors from details the game hides from add-ons around combat: the "Targeting" line in a
  unit's tooltip, the resource text on nameplates, and the AFK screen's check of whether you are
  away. Other places that could have failed the same way were hardened.

## 9.0.0

A release about finish: no new systems, a great many small ones, and a pass over everything for
consistency.

**New**
- Drag the game's own windows; each opens where you left it.
- Undo while moving panels: an Undo button on the bar at the top, Ctrl+Z, or `/fgui undo`.
- A panel you drag snaps to the edges of nearby panels.
- Item levels on the inspect window, and durability and average item level on your own.
- Choose what the info bar shows: right-click it.
- "Always sell" and "never sell" lists for selling junk, and a coin on everything that will be sold.
- Your other characters are listed beside the mail window: click one to address a letter to it.
- A "Learn all" button at trainers, and Alt-click to buy a full stack at vendors.
- A frame for what your focus is targeting, and a combat timer for every role.
- Your name is highlighted in chat when someone else says it, and names take their class color.
- Quest sounds: a chime when an objective is finished, another when the quest is ready to hand in.
- A rare spawn alert, and clock options (12-hour, server time).
- Player tooltips show guild rank. Optional: item and spell IDs.
- Switches for the key text and macro names on action buttons.
- Optional, off until you choose them: a ring round the mouse pointer, a quieter red error line,
  follow the reputation you earn, repair from guild funds, pick the only choice in a conversation.

**Changed**
- The Features tab is organized into fourteen sections under headings, in place of three long lists.
- Every options tab that can outgrow the window now scrolls.
- `/fgui help` is a grouped list of every command.
- Tooltip lines, the XP bar's tooltip, the quest log's headings and other leftover English text now
  follow the language you chose.
- `/fgui check` explains which game function is used in place of an older one, instead of listing
  it as missing.
- Less memory: only the language in use is kept after login, and the notification and
  confirmation-box checks build nothing while there is nothing on screen.

**Fixed**
- In the bags, the "BoE" tag could sit on top of the upgrade arrow.

## 8.7.1

**New**
- 17 more themes, for 46 in all, and 10 more lettering styles, for 19 in all.
- Each panel can show always, only in combat, only out of combat, or only with a target.
- A search box at the bottom of the options finds a setting on any tab.
- The XP and reputation bars show your progress as a percentage or as amounts.
- The game's buff and debuff frames can be moved.
- Coordinates on the world map, and a "BoE" tag on unbound gear in your bags.
- Nameplate width and height sliders, where the game allows it.
- Optional helpers: accept invites from friends and guildmates, faster auto-loot, type DELETE for
  you, skip cutscenes you have seen.
- You are told when someone in your guild or group has a newer version.
- Safe mode: `/fgui safe` reloads with every feature off if something goes wrong.

**Changed**
- The group finder window and the game's confirmation boxes are restyled to match.
- The Look and Features tabs scroll, so every theme, lettering style and switch has its own button.
- The game's debuff icons no longer get a border from the add-on.

**Fixed**
- The action bars could look grayed out, as if every ability were on cooldown.
- A tall dark panel could appear down the right side of the screen after opening a menu.
- Rows of empty boxes where the game's debuff icons and the totem timers go.
- An error could appear when a tooltip was shown for certain units.

## 8.4.7

**New**
- A minimap button for the options.
- Boss frames, and a breath and fatigue bar.
- Health and resources as percentages or amounts, on unit frames and nameplates.
- German, French and Spanish for the main labels, and a choice of language.
- An optional setting to use items from the bag window during combat.

**Changed**
- Chat bubbles are redrawn to match the rest of the interface.
- Report a Problem shows a form address and numbered steps for sending the report.

**Fixed**
- The game's own loot roll frame appeared alongside ours.
- Cooldown tracker: an icon stayed gray after its cooldown had finished.
- An error could appear while a menu was open.
- The report window opened behind the options window and was see-through.
- The Layout tab's last rows ran into the buttons at the bottom of the window.

## 8.2.1

The first release on CurseForge.
