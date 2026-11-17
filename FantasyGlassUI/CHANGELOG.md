# Changelog

The releases published on CurseForge. Each lists what changed since the release before it.

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
