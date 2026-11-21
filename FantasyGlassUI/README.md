# Fantasy Glass UI

by DustyMouse

A complete interface replacement for **WoW Forever** (interface 16001): unit frames, raid frames, cast
bars, action bars, bags and bank, quest tracker and quest log, minimap, buffs, nameplates, chat and
the game's own windows, in one look that you choose from 115 glass, fantasy and celestial themes.

Version 12.1.0

## Install

1. The zip holds **three folders**: `FantasyGlassUI`, `FantasyGlassUI_Options` and
   `FantasyGlassUI_Locales`. Put all three in `World of Warcraft/_forever_/Interface/AddOns/`,
   side by side (each folder's `.toc` file must be directly inside it, not one level deeper). The
   CurseForge app does this for you.
   The second folder is the options window, the setup and the self-check. The game loads it only
   the first time you open one of them, so it costs no memory until then. The third holds the
   translations, and loads only when the add-on is shown in a language other than English. In the
   game's add-on list they appear as "Fantasy Glass UI - options" and "Fantasy Glass UI -
   translations": leave both enabled.
2. Start the game, or type `/reload` if you are already logged in.
3. On first login a setup opens, in four steps: how much of the interface to take over (the whole
   interface, only restyle the game's own frames, or everything), how you play (your role and what
   you enjoy: questing, groups, PvP, collecting, being social), your look (theme family, theme,
   accent and text size), and a summary with a layout to start from. Choices apply as you click
   where they can; if any need the interface to reload, the last button does that once. Everything
   can be changed later in `/fgui`.

Fantasy Glass UI replaces the bags, unit frames and buff bars. Turn off other add-ons that do the same
(for example Baganator or another UI suite), or untick the matching feature in `/fgui`, so you don't
get two of everything.

## Commands

| Command | What it does |
|---|---|
| `/fgui` | Open the options window |
| `/fgui setup` | Run the first-run setup again (also the "Run setup again" button in `/fgui`) |
| `/fgui move` | Unlock every panel for dragging; type it again to lock |
| `/fgui test` | Preview mode: sample unit frames, raid frames, casts and swings |
| `/fgui layout` | Open Layout and profiles › Moving and scale (move panels, a scale slider for each) |
| `/fgui colors` | Open Look and themes › Class colors |
| `/fgui look` | Open Look and themes (themes, accent, lettering, your own theme, accessibility) |
| `/fgui tools` | Open Tools (a button for every window, and things to do once) |
| `/fgui buttons` | A copyable list of the buttons gathered into the Add-ons panel and how the game is drawing each |
| `/fgui bars` | Open Frames and bars › Action bars (each action bar's own settings) |
| `/fgui ask <question>` | Ask the guide where something is: `/fgui ask how do I move the bars` |
| `/fgui clickcast` | Open Frames and bars › Raid frames, where click casting is |
| `/fgui combat` | Open Combat (the cooldown tracker, alerts, timers, meters) |
| `/fgui memory` | How much memory the add-on is using, and whether the options have been loaded |
| `/fgui check` | Self-check: a copyable report of what the client supports and any errors |
| `/fgui report` | Everything needed to report a problem, as text to copy (also the Report a problem button) |
| `/fgui windows reset` | The game's windows open in their usual places again |
| `/fgui sell [item]`, `/fgui keep [item]` | Always or never sell an item with your junk (shift-click the item in). `/fgui sell list` shows both lists |
| `/fgui undo` | Put back the last panel move, nudge, resize or reset |
| `/fgui safe` | Safe mode: reload with every feature off. Type it again to leave |
| `/fgui language` | List the languages; `/fgui language deutsch` (or english, français, español, auto) picks one |
| `/fgui demo` | Fill the screen with sample frames, a sample raid and notifications; again to end |
| `/fgui clean` | Hide the whole interface for 5 seconds, for a screenshot (`/fgui clean 10` for ten) |
| `/fgui conflicts off` | Run every feature even beside other add-ons that do the same job (`on` to undo) |
| `/fgui bind` | Keybind mode: hover an action button and press a key (also Menu > Keybind Mode) |
| `/fgui session` | This session as a card (time, XP an hour, gold, loot, quests, deaths), with your last session under it |
| `/fgui rares` | The rares and treasures you have seen, by zone; click one for a waypoint |
| `/fgui tour` | The short tour of the interface |
| `/fgui gallery` | Whole screen setups to choose from, each with a picture |
| `/fgui checklist`, `/fgui checklist add daily <job>` | Your daily and weekly jobs for each character |
| `/fgui toolmenu` | Every tool window in one small panel (also "Tools" on the Menu button) |
| `/fgui pull 10`, `/fgui break 5` | A pull countdown (seconds) or a break (minutes) for the group |
| `/fgui comp` | Your group's roles, classes and who covers each buff |
| `/fgui bgscore` | The battleground's score |
| `/fgui bagrules add ilvl 50 = Upgrades` | A bag section by rule (`ilvl`, `boe`, `set`, `quality`, `type`, `name`); `/fgui bagrules` lists them |
| `/fgui mailrules add <character> cloth` | Mail rules; "Send by my rules" at the mailbox sends them |
| `/fgui events` | Holidays and events, now and in the next two weeks |
| `/fgui talents`, `/fgui talents save <name>` | Your saved talent builds; click one to import it |
| `/fgui sharepreview` | Look at a shared profile, layout or theme string before taking it |
| `/fgui selftest` | Work through the add-on and list what passed and what did not |
| `/fgui speak [text]` | Try the spoken alerts' voice |
| `/fgui guide route <name>` | The route editor for a quest guide (where guides are unlocked) |
| `/fgui whatsthis` | Point at any panel to see which feature made it (also a key binding) |
| `/fgui level` | The zones that suit your level; click one to open it on the map |
| `/fgui profcd` | Once-a-day crafts on all your characters, and when each is ready |
| `/fgui perf [seconds]` | How much time each part of the add-on takes, heaviest first |
| `/fgui queue [n]`, `/fgui queue list` | Add the selected recipe to the crafting queue; show the queue and its shopping list |
| `/fgui goal rep <name>`, `/fgui goal [item] 20`, `/fgui goal remove 2` | Reputation and item goals in a small panel with a bar each |
| `/fgui ready` | Who in the group is missing food, a flask or elixir, or a class buff (also shown when a ready check starts) |
| `/fgui alts` | Your characters, with level and gold, and the total (also `/fgui characters`) |
| `/fgui timer 5m tea` | A countdown bar that tells you when it ends (also `90s`, `1h30m`, `2:30`; a bare number is minutes). `/fgui timer` lists them, `/fgui timer off` cancels them all |
| `/fgui remind <buff>`, `/fgui hidebuff <buff>` | An icon while that buff is missing; leave a buff out of your buff row (the same again undoes it) |
| `/fgui note <text>`, `/fgui recent`, `/fgui missing`, `/fgui rolls`, `/fgui lockouts` | A note on your target, recent group mates, who is not here, the /roll list, raid lockouts |
| `/fgui raidsort group\|role\|name`, `/fgui resetinstances` | Order of the raid frames; reset your instances |
| `/fgui way 45 62`, `/fgui mount`, `/fgui mapsize 70` | A waypoint (alone, it clears), a random favorite mount, the size of the smaller world map |
| `/fgui restock [item] 5`, `/fgui gold`, `/fgui shop`, `/fgui trades`, `/fgui loot`, `/fgui deposit` | Restock list, gold history, shopping list for the selected recipe, trade log, loot log, deposit crafting materials |
| `/fgui keyword <word>`, `/fgui whispers`, `/fgui chattabs` | Keyword alerts, the whisper window, a Loot and a Whispers tab |
| `/fgui notepad`, `/fgui todo <text>`, `/fgui calc 20*45` | Notepad, to-do list ("daily ..." comes back each day), calculator |
| `/fgui execute 20`, `/fgui spec`, `/fgui volume 60`, `/fgui currency <id>` | Execute line, talent set, master volume, the info bar's currency |
| `/fgui media`, `/fgui font <name>`, `/fgui bartexture <name>`, `/fgui mute <number>`, `/fgui addons` | Fonts and textures from other add-ons, mute a sound file, add-on memory |
| `/fgui new` | Show the "what's new" note again |
| `/fgui strings` | Every label shown so far, laid out for translating (see Translating) |
| `/fgui tree` | How the window under your mouse is built, as copyable text (`/fgui tree FrameName` by name, `/fgui tree target` for your target's nameplate) |
| `/fgui profiles` | Open Layout and profiles › Profiles |
| `/fgui access` | Open Accessibility (`copy`: all its settings as one line to share; `paste`: take one) |
| `/fgui read` | Read aloud the tooltip under the mouse, the quest you are reading, or the last whisper |
| `/fgui status` | List every feature and whether it loaded |
| `/fgui reset` | Reset the current profile to defaults |
| `/ql` | Open the quest log |
| `/storage` | Open the storage viewer (bags, bank and guild bank of any character) |
| `/fgui help [word]` | Every command in a window you can search; click one to put it in the chat box |
| `/fgui keys` | Every action bar with its keys (or hold the key you bind for it) |
| `/fgui quiet` | Quiet mode: no chat, names or info bar, for screenshots and streaming (again to undo) |
| `/fgui bossnote` | Your target's boss note, to read or write (/fgui bossnote send: to the group; list: all of them) |
| `/fgui death` | What hit you before you last died |
| `/fgui kicks <name> <name> ...` | The order your group takes turns interrupting (empty: everyone, A to Z) |
| `/fgui testgroup` | Group practice: made-up group mates, to see group cooldowns, the interrupt rotation and buff coverage alone |
| `/fgui showcase` | Screenshot mode: every frame with sample data and nothing in the way; again to end |
| `/fgui drops [raid]` | The loot browser: what each boss dropped, with the upgrades for you first |
| `/fgui wish` | Your wishlist: the items you starred in the loot browser, and where each drops |
| `/fgui farm [stop|zones]` | A farming session: time, and gold and item value an hour; again to see it, stop to end it, zones for your best spots |
| `/fgui threat` | Show or hide the threat meter |
| `/fgui stats` | Lifetime stats: time played, quests, kills, deaths, gold, loot, bosses and runs, for this character and all of them |
| `/fgui gear` | Everyone in your group with their item level, the lowest first, and the group's average |
| `/fgui runs` | Your dungeon and raid runs: times, bosses, wipes, deaths and loot, with the best time for each place |
| `/fgui meter` | Tuck the damage meter drawer away, or bring it out |
| `/fgui meter reset` | Clear the damage meter |
| `/fgui hideonframe <aura>` | Never show that buff or debuff on the unit frames, raid frames or nameplates (again to show it) |
| `/fgui briefing` | What is waiting for you: crafts ready, mail on your other characters, lockouts reset, rested experience, jobs left |
| `/fgui main` | Make this character your main: new characters copy its setup |
| `/fgui skillups` | With a profession window open: the recipes that still give skill points, best first, with what each needs |
| `/fgui crafts <search>` | What all your characters can craft; search their recipes |
| `/fgui reps` | Reputations and currencies on all your characters; click one to pin it |
| `/fgui equipbest` | Put on every upgrade in your bags (higher item level, already bound to you) |
| `/fgui sort` | Sort your bags in the order of your bag sections (again to stop) |
| `/fgui ah` | What in your bags is worth more at the auction house than at a vendor |
| `/fgui send <name> layout` | Send your layout (or profile, or theme) to another player who has the add-on |
| `/fgui pack` | Your whole UI (profile, layout, theme, bars, mail rules) in one string to share |
| `/fgui website` | The add-on's website, to copy: every theme, switch and command, and a theme maker |
| `/fgui discord` | The invite to the Discord server, to copy: help, ideas, themes and other players |
| `/fgui home` | Which way home the home key would use |
| `/fgui pet` | A random favorite pet (/fgui mount for a mount) |
| `/fgui backup` | The backups of your settings, made before each update, once a day and before a reset; click one to see how to put it back |
| `/fgui history` | What you changed in this profile, and when; click a change to undo it |
| `/fgui blocked` | Anything the game refused to let the add-on do, and where |
| `/fgui recap` | Your last week on every character: gold, time played, levels, raids and dungeons, best loot ("this": this week so far) |
| `/fgui invword <word>` | The word a whisper must be for an invite (see "Invite by whisper") |
| `/fgui textsize 120` | All the add-on's lettering at that size, in percent (70 to 150; "reset" is as it came) |
| `/fgui uisize 90` | The whole interface at that size, in percent of the game's (50 to 150; "reset" is as it came) |

## Features

Every feature has its own switch in `/fgui`, in the category and section it belongs to (see
Options, below). The list here is grouped a little differently. Point at a switch to read what it does.

**Frames**
- Player, target, target-of-target, focus, pet and party frames, with a live 3D portrait, a 2D
  picture, a class emblem, or no portrait. The class emblem is the add-on's own medallion: the
  class's animated sigil (a loop drawn for each class: swords meeting, a bow drawn and loosed, a
  bolt crackling, the warlock's flickering flame) on a glass disc over a glow that breathes, a ring in your accent color that turns
  slowly (a clean line in the Glass themes, runes in the Fantasy ones), motes of light circling
  it. Reduce motion, or "Animated class emblems" off,
  holds it still.
- Raid frames for up to 40: role tag, leader, raid marker, ready check, range dimming, a debuff
  icon, an outline on players you can dispel, heals on their way, and your own heal-over-time
  effects.
- Click-casting: bind a mouse button, with or without a modifier, to a spell and click any unit
  frame to cast it on that player.
- Player cast bar, cast bars on target and focus, swing timers for main hand, off hand and ranged.
- While you craft, the progress bar in the profession window is in the same style, with the
  profession's own icon; the cast bar shows that icon too.
- Buff and debuff rows, including temporary weapon enchants.
- Nameplates with enemy cast bars and the debuffs you applied, and a yellow "!" beside anything you
  still need for a quest.
- A role HUD: threat for tanks, party health and mana for healers, target health and a combat
  timer for damage dealers.
- A cooldown tracker for abilities you choose, and buff alerts that pop up when a chosen buff is
  on you. When a tracked ability comes off cooldown, its icon pulses in the middle of the screen
  for a moment (place it in move mode).
- A ready check alert: a sound you hear even with the game in another window, the game's icon
  flashing in the taskbar, and a notice saying who asked.
- A consumables bar (off until chosen) that fills itself with the potions, bandages, food and
  drink, flasks, elixirs and scrolls in your bags, one button each, with how many you have. It is
  laid out again between fights.
- Totem timers, and a reminder when a shaman's weapon imbue (or a rogue's poison) is missing or
  about to run out. The reminder fades away outside combat (a switch in Combat keeps it
  showing).
- An aggro warning in groups, and an
  "out of range" note on the swing timer.
- Bars glide to their new value, windows fade in, and a frame flashes on a critical hit or heal.

**Interface**
- Action bars with Blizzard's art removed, shortened keybind text and cooldown numbers.
- A square minimap with zone name, coordinates and clock.
- Quest tracker with usable quest-item buttons, and a quest log window.
- XP and reputation bars; hover them for current, remaining and rested values.
- An info bar with FPS, latency, durability, gold and time.
- A Menu button in place of the game's micro menu, and a raid tools panel when grouped: ready
  check, role check, pull timer, target markers and ground markers. It opens in combat too.
- A damage and healing meter, on clients that share those totals with add-ons (see `/fgui check`).
  It is a drawer that comes out of the side of the chat box; the tab on its edge, or `/fgui meter`,
  tucks it away, and it can open itself for a fight. Views: damage and healing per second, damage
  and healing done, damage taken, absorbs, interrupts, dispels, deaths (click the heading or roll
  the mouse wheel over it; Shift-right-click resets). Right-click goes through this fight, overall
  and earlier fights. Point at a row for that player's abilities. Your own row has a white edge. Under the bars is the threat on
  your target for the three highest in your group. "Damage meter: drawer on the chat box" switched
  off makes it a window of its own instead.
- Loot-roll frames with Need, Greed and Pass and a countdown bar.
- A collector that gathers other add-ons' minimap buttons into one fold-out panel.
- Item level and vendor price in item tooltips, when the game's tooltip doesn't already show them.
- The info bar shows free bag slots, friends and guild members online and unread mail; hovering it
  lists gold on all your characters, the session's gain or loss, and who is online.
- The XP bar's tooltip adds experience per hour, time to level, and kills or quests remaining.
- Class extras under your own frame: a segmented bar for your class's second resource (holy power,
  soul shards, chi, arcane charges, essence), rune cooldowns for death knights, your mana while your
  main bar shows something else (a druid in a form), and a hunter's pet happiness beside the pet
  frame. Only what your class and this game have is shown. Rogues and druids have combo points.

**Windows and tooltips**
- **Item levels when inspecting.** The inspect window shows the item level of each piece the other
  player is wearing and their average, like your own character window. The numbers fill in over a
  second or two as the game sends the gear.
- **Tooltips.** A player's tooltip shows their guild rank. "Item & spell IDs in tooltips" (off until
  chosen) adds the ID number, for writing macros.
- **Character window.** Each worn piece shows how damaged it is (top left of its slot, only once it
  has taken damage), and your average item level is written above the head slot.
- **Gear set buttons.** A row under the character window with a button for each set saved in the
  game's equipment manager. One click puts a set on (not in combat). The set you are wearing is
  underlined; a set with pieces you no longer have is gray, and its tooltip says how many.
- **Every tooltip matches.** The side-by-side comparison tooltips, and the one that opens when you
  click an item link in chat, are covered along with the main tooltip.
- **Drag the game's windows.** The character window, spellbook, vendor, mailbox, trainer and the
  game's other windows can be dragged by any empty part of them (the title bar is easiest), and each
  opens where you left it. "Reset window positions" in Layout and profiles, or `/fgui windows reset`,
  puts them all back. A protected window cannot be moved during combat. Left to the game: the world
  map, the small question boxes, the loot window and the game menu.
- The group finder window is restyled like the other windows.
- Blizzard's windows, dropdown menus, tooltips and spellbook restyled to match. The character
  window gets flat equipment slots with quality-colored rims and item levels.

**Arranging the screen**
- **Undo.** While you are moving panels a bar at the top has an Undo button; Ctrl+Z and `/fgui undo`
  do the same. It puts back the last move, nudge, resize, Center, Reset or role layout, thirty steps
  deep. A run of nudges, or one drag of a size slider, counts as one step.
- **Panels snap to each other.** A panel you drag lines up with the edges of nearby panels as well as
  with the grid. Hold Shift to place it freely. ("Panels snap to each other" in `/fgui`.)
- **When each panel shows.** In move mode, right-click a panel and click the "Show:" button to step
  through: always, only in combat, only out of combat, only with a target. An ordinary panel is
  really hidden. A unit frame cannot be hidden by an add-on during combat, so it is made see-through
  instead (it can still be clicked where it was). While you are moving panels everything shows.
- **Info bar pieces.** Right-click the info bar, or press "Info bar pieces" in Layout and profiles, for a
  list of tick boxes: role, frame rate, latency, durability, gold, free bag slots, friends, guild,
  mail, clock. The bar shrinks to fit what is left.
- Action bars that fade when not in use (per bar: right-click its handle in move mode), a combat
  focus that dims the quest tracker and info bar during fights, and tooltips that follow the mouse.
- Nameplate width and height sliders in Layout and profiles (where the game allows its nameplates to be sized).
- **Search all options.** The box at the top of the options window finds a setting on any tab, by
  a word from its label or, for the Features switches, from its description. Choosing a result opens
  its tab, scrolls to it and rings it for a moment.
- **Action bar text.** Two switches in `/fgui`: the key text on each button, and macro names.

**Frames and combat**
- **Focus's target.** A small frame for whatever your focus is targeting, under the focus frame. It
  shows only while your focus has a target, and moves like any panel.
- Boss frames: up to five, down the right side, shown during boss fights. Click one to target it.
- **Combat timer.** A small movable timer counting how long the fight has lasted, for any role. The
  final time stays up for a few seconds afterwards. Off until chosen, in `/fgui`.
- Our own breath and fatigue bar in place of the game's.
- **A ring round the mouse pointer,** in the accent color, to find it in a fight. Off until chosen.
- **A quieter red error line.** Drops the lines that repeat constantly in a fight (not enough mana,
  not ready yet, out of range, wrong facing, no target) and keeps everything else. Off until chosen.

**Quests, map and minimap**
- **Quest sounds.** A chime when one of a quest's objectives is finished, and the quest-complete
  sound when the whole quest is ready to hand in. Nothing plays for a quest you have just accepted.
- **Rare spawn alert.** Told once, with a sound, when the game marks a rare creature, treasure or
  event on your minimap. `/fgui check` says whether your client marks them at all.
- **Clock.** Two switches: 12-hour, and server time. They apply to the info bar and the minimap.
- Coordinates on the world map: where you are and where the mouse is pointing, bottom left of the map.
- A minimap button with the add-on's icon: left-click opens the options, right-click starts moving
  panels, and it can be dragged along the minimap.

**Chat**
- **Class-colored names in chat.** Switches on the game's own setting for it, and puts the game's
  setting back if you turn the switch off.
- **Your name in chat.** When someone else says your character's name in say, yell, party, raid,
  guild or a channel, the name is picked out in a bright color. A second switch plays the whisper
  sound as well. Whispers and your own messages are left alone, and so is any text inside a link.

**Vendors, trainers and mail**
- **At vendors and trainers.** Alt-click a vendor's item to buy a full stack (or as many as you can
  afford). Trainers get a "Learn all" button that buys every skill you can learn and afford.
- **Keep and sell lists.** "Sell junk" goes by color: gray is sold. Two lists correct it: *Always
  sell* (sold whatever its color) and *Never sell* (kept even if gray). In the bag window, Alt-click
  an item and use the two buttons at the bottom; a gold or green line along the bottom of the slot
  marks a listed item, and its tooltip says so. Without the bag window: `/fgui sell` or `/fgui keep`,
  a space, then shift-click the item. `/fgui sell list` shows both lists. The lists are shared by
  all your characters. Nothing without a vendor price is ever sold.
- **A coin on junk.** In the bag window, a small coin marks everything "Sell junk" would sell: gray
  items and your always-sell list, less your never-sell list.
- **Mail to your other characters.** While you are writing a letter, your other characters are listed
  beside the mail window. Click one to address the letter to it. ("Mail: list my other characters".)
- A "BoE" tag on gear in your bags that binds when equipped and is not bound to you yet.

**Notifications and time away**
- Notifications for an item you looted (uncommon or better), a new level, new mail, whispers, bags
  that are almost full and gear that needs repair.
- **Update notice.** If someone in your guild or group runs a newer version, you are told once. Only
  the version number is exchanged, and nothing during combat. ("Tell me when an update is out" in
  `/fgui`.)
- The data other add-ons publish through LibDataBroker, shown in a strip under the info bar.
- The AFK screen can start when the game marks you away, or after an idle time you set (Combat).
- Keybind mode, an AFK screen (the interface fades and the camera drifts while you are away, with
  a panel of the session's statistics and your time played), and a screenshot each time you level up.

**Off until you choose them**
- **Off until you choose them** (each acts for you, and no preset changes them):
  - *Follow the reputation I earn*: the reputation bar switches to the faction you last gained with.
  - *Repair from guild funds first*: auto-repair uses your guild allowance when it covers the bill.
  - *Pick the only choice when talking*: a character with exactly one thing to say and no quests.
    Never inside a dungeon or raid; hold Shift to choose for yourself.
- Helpers, each its own switch in `/fgui` and each off until you choose it. Presets never
  change them.
  - **Accept invites from friends & guild.** Invitations from anyone else are left for you.
  - **Faster auto-loot.** With auto-loot in effect, takes everything from a corpse at once.
  - **Type DELETE for me.** Fills in the word when you destroy a good item. You still confirm.
  - **Skip cutscenes I have seen.** One plays the first time and is skipped after. Hold Ctrl as it
    starts to watch it again.
  - **Stand up when an action needs it**, and **Dismount when an action needs it.** When something
    fails because you are sitting or mounted, that is put right and the next press works. Never
    off a mount in the air or on a flight path.
  - **Accept resurrections.** One cast by someone who is in a fight is left for you to time.
  - **Accept summons.** After five seconds, with a line in chat saying who and where; decline it
    in that time to stay. Hold Shift as either offer arrives to answer it yourself.
  - **Gear sets follow my talent set.** Each talent set remembers the gear set you last put on in
    it; switch talent sets and that gear set goes on.
  - **Invite by whisper.** A friend or guildmate who whispers "inv" is invited (`/fgui invword`
    changes the word; "from anyone" widens it).
  - **Decline duels.** Turned down for you, with a line in chat saying who asked.
  - **Confirm bind-on-pickup loot when alone.** In a group it stays a question.
  - **Accept role checks.** Your role is confirmed as you last set it.
  - **Greed on green items.** Rolls Greed for you on uncommon items. Blue or better, anything
    that binds when picked up, and gear better than what you wear are left for you.
- **Game settings**, a section of `/fgui`: maximum camera distance, mute the error
  voice, sound when tabbed out, best-quality screenshots, auto loot, loot window at the mouse,
  auto self-cast, nameplates from further away (41 yards), stacking nameplates, a camera that stays
  where you turn it, clear weather, a lower frame rate when tabbed out (30), no tutorial pop-ups,
  profanity filter off, mute the music, mute ambient sounds, no gray screen when dead and less
  screen glow. Each is one of the game's own settings; switching it off puts back what it was
  (unless you have changed it yourself since). None is changed during a fight, and the presets
  never touch them.
**Bags and bank**
- One window for all bags, and one for the bank: categories or grid, search, sort, item-quality
  borders, item level on gear, a row of bag slots, shift-click to split a stack.
- A green arrow marks gear in your bags with a higher item level than what you are wearing in
  that slot. It compares item level only, so treat it as "worth a look".
- Alt-click an item to put it in a category of your own. New items carry a small mark until you
  hover them. A "Sell junk" button appears while a vendor is open.
- Bank tabs can be bought and filled from the bank window.
- Storage: the bags, bank and guild bank of every character, viewable from anywhere, and item
  counts in tooltips ("12 in bags, 40 in bank, 5 on an alt").

**Helpers**
- Sell gray items and repair automatically at vendors.
- At the mailbox: Collect gold, and Open all on clients that don't have their own.
- Optional automatic quest accept and turn-in (hold Shift to skip; it never picks a reward).
- Clickable web links in chat, and a Copy button on each chat tab. The last lines of every
  chat tab come back, dimmed, after a reload or a relog within half an hour (it has its own
  switch; the combat log is not kept).
- Chat bubbles in the same style, with the speaker's name in their class color. Inside dungeons
  and raids the game locks bubbles away from add-ons, so there they keep Blizzard's look.

**Added in 10.0** (each has its own switch; `/fgui help` lists the commands)
- Combat: a missing buff reminder, focus cast alert, execute line, loss-of-control alert, key bindings
  for your best healing potion and your best food, a boss and dungeon timer, a queue alert, automatic
  combat logging, a buff filter, screenshots on boss kills.
- Groups: your own notes on players, recent group mates, a roll tracker, raid frames ordered by
  group, role or name, who is missing, raid lockouts for every character, join and leave notices, a
  Reset instances button.
- Map and travel: waypoints with an arrow, a travel bar, a mount key, a flight timer that learns each
  route, fishing mode, a smaller world map, your group on the map in class colors, the tracking menu
  on a right-click of the minimap, and who pinged it.
- Bags and gold: a restock list, gold history, a shopping list for the selected recipe, a "Set" mark
  on gear set items (never sold), an open-all button, a trade log, a Deposit button in the bank,
  auction prices in tooltips, a loot log.
- Chat: keyword alerts, repeated lines hidden, Alt-click a name to invite, a whisper window, a Loot
  and a Whispers tab made for you, /rl /rc /tt, guild and friend notices, the friends list in class
  colors.
- Characters and tools: more about each character in `/fgui alts`, talent set buttons, missing
  enchants, more info bar pieces, a notepad, a to-do list, a calculator, fonts and bar textures from
  other add-ons (LibSharedMedia), muted sounds, lower graphics in raids, add-on memory, the talking
  head hidden or moved.

**Action bars, bar by bar**
- Frames and bars › Action bars in `/fgui` lists every action bar, with the stance and pet bars. Each has its own:
  size; opacity; rule for when it shows (always, when pointed at, in combat, out of combat, with a
  target, never); key text; and macro names. These apply as you change them.
- Rows, buttons shown, button size, spacing and direction are set there too. They belong to the
  game's Edit Mode, so "Apply to the bar" writes them into the Edit Mode layout you are using, and
  the game lays the bar out. This needs a layout of your own: the game's two presets cannot be
  changed (Esc, Edit Mode, Layout, New Layout makes one).
- A bar that is not showing is see-through; its buttons can still be pressed where they were.

**Added in 12.1**
- Accessibility as a category of its own: color vision for each kind, captions for sounds, read
  aloud, readable and dyslexia-friendly lettering, safe flashing, calm mode, bigger controls,
  keyboard moving through the settings, a target outline, and sharing it all as one line.

**Added in 12.0**
- A new settings window: categories down the left with their sections, Home, a search that says
  where each setting lives, Simple / All options, Undo last change, Reset a category, NEW tags,
  sample frames, and a window you can resize.
- A new setup in four steps, with a way to keep the game's own frames and only restyle them.
- Accessibility in one place, with dots for item quality and a fantasy high-contrast theme.

**Added in 11.18**
- Report a problem also gives the Discord invite, to attach the saved report in #bug-reports.
- The add-on's own action bars do far less work while you stand still.

**Added in 11.17**
- An upgrade notice when you loot something better, with a button to put it on (it waits until a fight is over).
- Milestones for kills, quests, bosses and runs; `/fgui stats` lists them by character, with the day.
- A boss's abilities from the game's dungeon journal, one line each, when you target or pull it.
- `/fgui website` and `/fgui discord` give the website and the Discord invite to copy. The Discord
  button at the foot of the settings window does the same.

**Added in 11.16**
- Loot rolls: the button to press lights up, with the reason beside the item. Nothing is rolled for you.
- `/fgui gear`: everyone in your group by item level, lowest first. `/fgui stats`: lifetime totals.
- Nameplates have the add-on's own health bar, and the level in its difficulty color beside the name.

**Added in 11.15**
- A wishlist: star items in `/fgui drops`, see them with `/fgui wish`, and get a notice when one drops or its boss is your target.
- Nameplates mark the mobs you still need for a quest, with how many are left.
- Starcut windows and tooltips: their corners cut away, with a fine rim.

**Added in 11.14**
- Gem-cut action buttons and bag slots, and a diamond minimap.
- In a group, a panel says whose upgrade a boss's drop is (between players who use Fantasy Glass UI).
- A run log: `/fgui runs` lists every dungeon and raid run, with best times.
- `/fgui farm zones` lists your best farming spots. Goals for gold on all characters, a level and a mount.

**Added in 11.13**
- `/fgui showcase` (or `/fgui screenshot`): every frame with sample data, ready for a picture.
- `/fgui drops`: what each boss dropped while you were there, upgrades first.
- A threat panel in groups (`/fgui threat` hides or shows it).
- Farming sessions: `/fgui farm` starts one, shows what it makes an hour, and `/fgui farm stop` ends it.
- Equipment sets: the set you wear is named over your player frame; `/fgui set <name>` puts one on.

**Added in 11.12**
- Starcut unit frames: bars cut to points and a diamond portrait. Frame style: Classic brings the box back.

**Added in 11.11**
- **Celestial themes** take the place of Runic: a third family of 38, night-sky panels with a fine
  starfield, a faint nebula in the accent color, constellations and star points. A Runic theme in use
  becomes the Celestial theme made from it, with the same accent.

**Added in 11.9**
- Art for the third family for emblems, the minimap and the action bars; **theme previews** in Look and themes;
  `/fgui check new` reports on every feature added since 11.6.

**Added in 11.8**
- A third family of 38 themes (Runic; replaced by Celestial in 11.11).
- Korean and Chinese names in the language list no longer show as boxes.

**Added in 11.7**
- **Am I ready?** (`/fgui ready me`): food, flask, weapon, repairs, reagents, bag space, talents and
  gear before a raid.
- **Boss notes** (`/fgui bossnote`, `list`, `send`): open on target, fight start or a pull timer;
  the leader can send theirs to the group.
- **Death recap** (`/fgui death`), a **home key** (Key Bindings, AddOns; `/fgui home`), and an
  **auction house helper** ("Lowest -1c", "Worth selling", `/fgui ah`).
- **Backups** before each update and daily (`/fgui backup`, `/fgui backup restore daily|update`), and
  **changes to this profile** with undo (`/fgui history`).
- **Whole-UI packs** (`/fgui pack`, Layout and profiles › Profiles), **role templates** (Layout and profiles › Profiles), "Coming from
  another UI?" in the setup, `/fgui perf fight` and `/fgui perf load`.

**Added in 11.6**
- **Group practice** (`/fgui testgroup`, Tools or the Tools menu): five made-up group mates
  for five minutes, to see and place the group cooldowns, the interrupt rotation and buff coverage
  alone. They take turns to interrupt; on your turn use your own. Nothing is sent to anyone.
- **Arena enemy frames** (off): up to five, in place of the game's. Left-click
  targets, right-click sets focus.
- **Enemy cooldowns** (a switch in `/fgui`): in arenas and battlegrounds, an enemy
  player's PvP trinket, interrupt and dispel, beside the arena frames and under your target and
  focus frames, counting down once used.
- **Upgrade arrows** on loot rolls, quest rewards and the game's bags, and "Upgrade: +N item level"
  on item tooltips. **Equip best** (`/fgui equipbest`, or the button on the bags) puts on every
  upgrade already bound to you.
- **New characters** get their own copy of your main's setup, fitted to their class. `/fgui main`
  or Layout and profiles › Profiles chooses your main (otherwise the character you played last).
- The execute line shows only on enemies; the translations are a third folder, loaded only when
  needed.

**Added in 11.5**
- **Interrupt rotation** (off): who is next to interrupt, and a
  warning (on screen, and aloud with spoken alerts) when it is you. `/fgui kicks <name> <name>` sets
  the order; the group leader's order is shared with everyone who has the add-on.
- **Class resource designer** (Frames and bars, Class resource; switch "Class resource you
  design" in `/fgui`): dots, one bar or a number, with width, height, gap and number size.
- **Professions** (`/fgui crafts`, `/fgui crafts <search>`): every character's recipes, noted when a
  profession window is open; item tooltips say "Made by" (switch in `/fgui`).
- **Key binding sheet** (`/fgui keys`, or a key in Key Bindings, AddOns: shown while held).
- **Buff coverage** (in `/fgui`, off): a mark on raid and party frames of anyone missing the buff
  you can give. Checked out of fights.
- **A layout for each screen size** (Layout and profiles, Share layout, third switch).
- **Quiet mode** (`/fgui quiet`, Tools, or a key): no chat, names over heads or info bar,
  then everything back as it was (names come back even after a reload).
- **Simplified Chinese** (简体中文) as a language for the add-on's labels; every language now covers
  the whole options window.
- The Features tab has 11 sections instead of 18.

**Added in 11.4**
- **Sort bags** (`/fgui sort`, Tools or menu, or a key binding): your bags in the order of
  your bag sections - your own rules, the ready-made sections switched on, then gear, consumables,
  quest items, trade goods, the rest and junk - best quality first inside each. One move at a time,
  never in a fight; special bags and the reagent bag are left alone. Again to stop.
- **Reputations and currencies** (`/fgui reps`): each character's are noted as you play it. Click a
  line to pin it, and it is listed first for every character.
- **Mount and pet buttons** (in `/fgui`, off): a random favorite mount and pet, as two movable
  buttons and as key bindings (Key Bindings, AddOns).
- **Send a talent build** (`/fgui talents send <player> <build>`): kept with their builds, for their
  class only, and never learned until they choose it.
- **Goals panel:** goals of your own (`/fgui goal add 50 Kill raptors`, click to count up,
  right-click to count down, `/fgui goal + 1 5` to add five) and achievements
  (`/fgui goal ach <name or number>`) where the game client has them.

**Added in 11.3**
- **Group cooldowns** (off): a panel listing who in your group has
  a battle resurrection, an interrupt, a big defensive or a raid cooldown, and whether it is ready
  or how long until it is. Group members with Fantasy Glass UI tell each other whenever they use one.
- **Send your setup** (`/fgui send <name> layout|profile|theme`, or Layout and profiles › Profiles): it goes
  straight to the other player and opens in their preview, where they choose whether to take it.
  "Accept setups other players send me" (a switch in `/fgui`) turns receiving off.
- **Totem bar** (Shamans, on): left-click drops the totem chosen for each element, right-click
  takes it away, the mouse wheel chooses another out of a fight.
- **Aura designer** (Frames and bars, Auras): what shows on the target, focus and player frames
  and where; heals over time, debuff icon and cleanse highlight on raid frames; all or only your
  debuffs on nameplates. "Hidden on frames" (Tools, `/fgui hideonframe <name>`) keeps an aura
  off every frame.

**Added in 11.2**
- **Your rules in Tools:** bag rules, mail rules, checklist jobs and talent builds have an
  editor under "Your lists". Choose the kind with the button above the box (click for the next,
  right-click to step back), type, and Add. ^ moves a bag rule up; Use learns a talent build.
- **Tools on the Menu button**: "Tools" in the Menu button's list opens a small panel with a button
  for every tool window, so they open without going to the options (`/fgui toolmenu` too).
- **Pull and break timers** (`/fgui pull 10`, `/fgui break 5`, or Tools): a big countdown for
  everyone in the group who has the add-on. A pull also starts the game's own countdown. Group
  leaders and assistants.
- **Battleground helper** (in `/fgui`, on): while you wait, how long you have waited and the
  game's estimate; with an invitation, how long it has left; inside, a countdown to the start.
  `/fgui bgscore` shows the score.
- **Raid composition** (`/fgui comp`): your group's tanks, healers and damage, its classes, and who
  covers each group buff, dispel and battle resurrection (or that nobody does).
- **Bag rules** (a switch in `/fgui`): ready-made sections you switch on one by one:
  Upgrades, Gear sets, Bind on equip, materials by kind (Cloth, Leather, Ore and stone, Herbs,
  Cooking ingredients, Elemental, Enchanting materials, Gems), potions, food, scrolls and bandages
  apart, and Recipes. Your own rules (Tools, or `/fgui bagrules add ilvl 50 = Upgrades`) come
  first: by item level, bind on equip, gear set, quality, kind of item or name, in the order you set.
- **Mail rules** (a switch in `/fgui`): a switch for each material (cloth, leather, ore and
  stone, herbs, cooking ingredients, elemental, enchanting materials, gems, potions and food), and a
  box beside each for the character it goes to. "Send by my rules" above the mail window sends it
  all, one character at a time, twelve items to a letter. Your own rules (Tools, or
  `/fgui mailrules add Mytailor cloth`) are sent too. Soulbound items are never sent.
- **Events and holidays** (`/fgui events`): what the game's calendar has on now and in the next two
  weeks. A holiday that is on is added to your checklist, and taken off when it ends.
- **Talent builds** (`/fgui talents`): keep your talents under a name, as the game's own loadout code.
  A click puts a build in the talent window's Import box; press Import and it joins your loadouts.
- **Preview a shared string** (Tools, `/fgui sharepreview`): paste a profile, layout or theme
  string and see where its panels go and its colors before taking it.
- **Hide the game's raid manager** (off): the panel that slides
  out from the left edge in a group. The Raid tools panel has ready checks, markers and role polls;
  leaving a group is in the game menu or on your portrait.
- **Pixel-perfect scale** and **a round minimap** (in `/fgui`, both off until you choose them).

**Added in 11.1**
- **Choose which of the add-on's own bars you use**: "Use this bar" in Frames and bars. A bar
  that is off is hidden altogether; its keys still press its buttons.
- **Nameplate designer** (Frames and bars, Nameplates): width and height, name size or no
  names, where the health text sits and its size, cast bar height and text size, debuff icon size
  and how many show, threat colors, and the mark on your target's plate.
- **Raid frame designer** (Frames and bars, Raid frames): size, space between frames, players
  in each column, down or across, order (group, role, name), and name and status text sizes. Where
  the game's own raid frames are used (clients that hide buffs from add-ons in a fight), their size
  is in the game's Edit Mode; here are their lettering and the game's raid frame settings (power
  bars, class colors, pets, only debuffs you can remove, aggro highlight, health text).
- **Checklist** (`/fgui checklist`, or Tools): your own daily and weekly jobs, ticked per
  character and cleared by themselves at the game's resets, with this character's lockouts,
  once-a-day crafts that are ready, and how far your other characters have got.
  `/fgui checklist add daily <job>`, `/fgui checklist add weekly <job>`.

**Added in 11.0**
- **Fantasy Glass action bars** (in `/fgui`, off until chosen; a `/reload` either way): eight bars
  of real action buttons made by the add-on, in place of the game's. Each has its own number of
  buttons (1 to 12), rows, button size, spacing and direction, set at once on the Bars and frames
  tab without the game's Edit Mode. Bar 1 changes page with your stance, form, stealth, a vehicle or
  a possess, as the game's main bar does. Your key bindings press them (Action Button 1-12 press
  bar 1, Bottom Left Action Bar presses bar 2, and so on), keybind mode binds them, and they hide
  in pet battles and vehicles. Everything else a bar has (when it shows, size, opacity, key text,
  macro names, moving it with `/fgui move`) works on them too. The stance and pet bars stay the
  game's.
- **Frame designer**: in Frames and bars, below the bars, each unit frame (player, target,
  target's target, focus, focus's target, pet) has its own width, height, power bar height (0
  hides it), text size, portrait side (left, right or none), and where its name and health text
  sit (left, middle, right, or hidden). Changes show at once; a size waits until a fight is over.
- **Layout gallery**: `/fgui gallery` (or Layout and profiles, or Tools) shows six whole screen
  setups - Classic, Healer raid, Tank, Wide screen, Minimal and Streamer - each drawn as a small
  picture of the screen. One click puts it in place; `/fgui undo` takes it back.
- **Custom alerts** (Combat): when your health, your target's health or your mana is below a
  number, a buff is missing or on you, an ability is ready, your target is casting, you are in
  combat, your bags are nearly full or your gear is worn: show a line, play a sound, and say it.
  While the game hides a value from add-ons (health and buffs in a fight, on this client), an
  alert that needs it keeps what it last knew rather than guessing.
- **Spoken alerts** (in `/fgui`, off until chosen): the game's own text-to-speech voice reads out
  ready checks, whispers (with who sent them), missing buffs, loss of control and your custom
  alerts. Choose which in Combat. `/fgui speak` tries the voice.
- **Live self-test**: `/fgui selftest` works through the add-on in the real game (every options tab,
  every window, the preview, move mode, What's this?, the gallery, the bars, the alerts) and lists
  what passed and what did not, with the error. Not during a fight.
- **Route editor** for quest guides (where guides are unlocked): the steps in order, to move up or
  down, change, delete or add after; Here writes a step for where you stand. While you follow a
  guide its next steps are numbered on the world map.
- **API for other add-ons**: `FantasyGlassUI_API` lets other add-ons add info bar pieces, themes,
  commands, Tools windows, guide answers and movable panels, and dress their windows in this
  add-on's look. `API.md` in the add-on's folder describes it.

**Added in 10.8**
- **Session card**: `/fgui session` (or Session in Tools) shows time this session, XP an
  hour, gold, items looted, quests, kills and deaths, with your last session on this character.
- **Cooldown timeline** (off until chosen): the abilities on your cooldown tracker list slide along
  one slim bar towards ready, the last seconds stretched out. In a fight the game may hide
  cooldowns from add-ons; those wait at the right end with the game's own sweep.
- **Quest rewards on the tracker**: each quest's experience and money beside its name, in gold once
  it is ready to turn in.
- **Ready-check report**: when a ready check starts (outside a fight), who is missing food, a flask
  or elixir, or a class buff someone in the group can give. `/fgui ready` any time.
- **Rare spawn memory**: where the rare alert saw each rare or treasure, marked on the world map.
  Only what you have found yourself. `/fgui rares` lists them; click one for a waypoint.
- **Theme by place**: in Look and themes › Theme by place.
- **Combat text in your lettering** (off until chosen): the floating combat numbers use the
  add-on's lettering; a change shows after a relog.
- **Crafting queue**: `/fgui queue` adds the recipe selected in your profession window (`/fgui
  queue 5` for five); `/fgui queue list` shows the queue: click a line to make it, right-click to
  remove, and one shopping list for the whole queue.
- **Goals panel**: reputations and items you are working towards, with a bar each:
  `/fgui goal rep <name>`, `/fgui goal` + a shift-clicked item + a number, `/fgui goal remove 2`.
- **Login splash** (off until chosen): the add-on's emblem, your character and your zone for a
  moment as you log in. The loading screen itself belongs to the game; add-ons cannot draw on it.

**Added in 10.9**
- **Tour**: once, after the setup, a few cards point at the main parts of the interface: your
  frames, the info bar, the minimap and Add-ons button, the quest tracker, chat, the options, the
  guide and What's this. `/fgui tour` (or Tour in Tools) plays it again.
- **What's this?**: `/fgui whatsthis` (or its key binding) covers every panel of this add-on on
  screen with its name. Point at one to see which feature made it and what it does; click it to go
  to that feature's switch, right-click to switch it off. Esc finishes.
- **Where to level**: `/fgui level` lists the zones that suit your level, from the game's own map
  information, so the new zones are there too. Green: your level now; yellow: next; gray: nearly
  done. Click one to open it on the world map.
- **Profession cooldowns**: each character's once-a-day crafts are remembered whenever a profession
  window is open, with a notice when one is ready again. `/fgui profcd` lists them for all your
  characters.
- **Performance**: `/fgui perf` measures for 20 seconds (or `/fgui perf 60`) how much time each part
  of the add-on takes, then lists them heaviest first with the add-on's memory. Click a line to go
  to that feature's switch.
- **Languages**: Italian, Portuguese, Russian and Korean, besides German, French and Spanish.

**Quest guide**
- Coming soon. The Guide tab of `/fgui` says so.

## Options

`/fgui` lists its categories down the left: **Home**, **Look and themes**, **Frames and bars**,
**Combat**, **Groups and raids**, **Bags and items**, **Quests and map**, **Chat and people**,
**Done for you**, **Layout and profiles** and **Tools**. The category that is open lists its
sections under it, each with how many of its switches are on; choosing one shows it on the right.
Every setting there has a line of its own, with what it does under its name and its switch or
slider at the end, and "after /reload" where it needs one. Point at a line for the whole story.
Under the lines come the larger pieces that go with them: the theme grid, the frame and bar
designers, the cooldown list, your lists and rules, and so on.

- **Home**: a card for each category, a few quick switches, what you changed lately, the three
  presets (Standard, Everything, Minimal: click twice), *Ask the guide* - type a question in plain
  words ("how do I make the bars bigger") and it names the feature or command, with a Show me
  button that takes you to it - and a few switches suggested for your class.
- **Search every option**, at the top of the list: it finds any setting, says where it lives
  ("Auto-repair · Bags and items › Vendors"), and Enter goes to the first one.
- **Simple / All options**, at the top: Simple shows the settings most players look for (it starts
  that way for a new player); All options shows every one. The search always finds them all.
- **Undo last change**, at the foot, takes back what you changed, one step at a time, and each
  category has **Reset to how it came** for its switches and sliders (your lists, rules, designs
  and positions are kept). Frames and bars has **Show sample frames**.
- The header names the profile you are changing; click it for Layout and profiles › Profiles. Drag
  the window's bottom right corner to make it bigger or smaller.
- **Look and themes**: themes, accent and lettering (and fonts and bar textures from other
  add-ons), your own theme from three colors, theme by place, class colors, the game's windows,
  sounds and notifications, the AFK screen and screenshots, and Accessibility.
- **Frames and bars**: your frames (frame style, portrait, sizes and a designer for each frame,
  auras, class resource), party, boss and arena, raid frames (with click casting), numbers on
  frames, the action bars (each with its own size, opacity, when it shows, rows, buttons and
  spacing), and nameplates.
- **Combat**: cooldowns, alerts and warnings (custom and spoken alerts, buff alerts and reminders),
  timers, damage and threat, and against other players.
- **Layout and profiles**: move panels, preview, share layout, role layout, the layout gallery and a
  scale slider for every panel; and profiles: create, switch, copy and share them, role
  templates, what new characters copy, backups and changes to the profile.
- **Tools**: a button for every window that otherwise needs a command, and things to do once.

## Themes

Thirty-eight glass themes (Smoke, Frost, Midnight, Aurora, Rose, Emerald, Ocean, Sunset, Crimson,
Orchid, Gilded, Glacier, Amethyst, Lagoon, Honey, Storm, Coral, Jade, Nebula, Sapphire, Ruby, Topaz, Pearl, Obsidian, Mint, Lavender, Copper,
Deep sea, Cherry blossom, Lime, Indigo, Steel blue, Mocha, Void, Graphite, Noir, High
contrast, and one tinted with your class color) and thirty-nine fantasy themes with rims, grain and
ornament (Warm, Dark, Cold, Forest, Blood, Arcane, Sand, Forge, Royal, Abyss, Fel, Bone, Onyx, High contrast,
Dragonfire, Moonlit, Verdigris, Autumn, Twilight, Plague, Steel, Sunwell, Rosewood, Frostfire, Emerald
Dream, Shadow, Titan, Lightforged, Nether, Tundra, Jungle, Molten, Tidal, Wine, Ashen, Oak,
Stormcaller, Starlight, and one in your class color), and thirty-eight celestial themes, night skies
with a fine starfield, constellations and star points (Polaris, Eclipse, Blue Hour, Zenith, Desert Sky, Moonlight, Blood Moon, Aurora, Winter Sky, Comet, Starstorm, Solstice, Void, Moonlit Grove, Tides, Harvest Moon, Clear Night, Dawn, Dusk, Starlight, Red Planet, Gilded Sky, Silver Mist, Evening Star, Honey Moon, Opaline, Deep Space, Fel Sky, Ashen Sky, Pearl Moon, Spirit Lights, Arcane Sky, Crimson Nebula, Sapphire Night, Emerald Night, Crystal Sky, Astrolabe, and one in your class color). Noir and Onyx are black and red. There are thirty-one accent colors. Picking a theme also
picks a matching accent, which you can change afterwards.

Lettering is a separate choice, with thirty-six styles (two of them, Readable and Dyslexia-friendly, made to be read easily). Plain: Modern, Clean, Sharp, Squared, Tech,
Rounded, Condensed, Terminal, Slab, Narrow, Future, Soft, Military, Circuit, Blocky, Heavy titles,
Arcade. With character: Fantasy titles, Scholar, Manuscript, Storybook, Calligraphy, Celtic, Gothic,
Engraved, Poster, Imperial, Chronicle, Roman, Medieval, Illuminated, Warband, Knightly. And the game's own fonts. You can also
make your own theme in Look and themes, as a glass, fantasy or celestial theme, and share it as a text
string with Export and Import. Look and themes › Themes lists themes under four headings: Glass, Fantasy,
Celestial and Your themes, every one with its own button; so do the theme and lettering grids in the
setup. Frames and bars › Action bars has a switch for a framed panel behind the action bars (off by default). Theme, accent and lettering
change on the spot; switching between the glass, fantasy and celestial families finishes after a `/reload`.
Glass panels have rounded corners on clients that support it.

## If something goes wrong

Type `/fgui safe`. The interface reloads with every feature left unstarted, and a banner at the top
says so. The options, the setup and every `/fgui` command still work, so you can switch off whatever
was causing trouble. Then press **Leave safe mode** on the banner, or type `/fgui safe` again. Safe
mode stays on through reloads and relogging until you leave it.

## Good to know

- **Using items from the bag window in combat.** The game only lets add-ons use an item through a
  special secure button. By default the bag window has one such button that follows the mouse, and
  it cannot be moved during a fight: so in combat, right-clicking an item with a "Use:" effect only
  prints a reminder. Keep potions and the like on an action bar.
  There is an option that removes this limit: **"Bags: use items in combat"** in Bags and
  items › Bags and bank. It gives every slot its own secure button. The price is that the bag window's
  arrangement is frozen while you fight (icons and counts still update) and re-sorts afterwards. It
  is off until you choose it, and if your client cannot support it, it switches itself back off and
  says so in `/fgui check`.

- **Combat.** This game client hides some values from add-ons during combat (health, power, threat,
  some cast times). Bars always fill correctly, because the game draws them. Numbers that would
  have to be calculated, such as health percent, may go blank until the fight ends. Panels cannot
  be moved or resized in combat, and the Menu button does not open then.
- **Buffs and debuffs in combat.** WoW Forever does not let add-ons read buffs or debuffs while you
  are in combat. On such clients Fantasy Glass UI restyles the game's own buff frames instead of drawing
  its own, and uses the game's own raid frames (restyled) because those are allowed to show
  debuffs, dispels and heals during a fight. Debuffs on our target frame only update out of combat.
  Options that would have nothing to work with there (buff alerts, "only my debuffs", color-blind
  debuff letters, raid cell sizes) are left out of `/fgui`, and "Buff frames" and "Raid frames" are
  labelled as the game's own, restyled.
- **Storage is recorded when seen.** A bank is saved when you visit a banker on that character; a
  guild bank is saved one tab at a time as you click through it.
- **If something breaks,** the affected feature switches itself off and prints one line in chat
  naming it. `/fgui check` opens a report you can copy: which features are running, every error
  this session, and which game functions this client has. To see every error as it happens, type
  `/console scriptErrors 1`.
- **Turning a feature off** in `/fgui` gives you Blizzard's version of it back after a reload.

## Accessibility

A category of its own in `/fgui` (`/fgui access`), and the Comfort step of the setup:

- **Seeing.** Color-blind safe colors for your kind of color vision: red-green (blue and orange),
  blue-yellow (teal, pink and red), or no color at all (brightness and marks only). Debuffs get a
  letter, item quality gets dots, and threat on nameplates gets a mark. Readable lettering
  (Atkinson Hyperlegible) or Dyslexia-friendly (OpenDyslexic); an outline round letters; a dark
  band behind messages; a thick outline round your target's nameplate; two high-contrast themes;
  text sizes and the interface size; the ring round the mouse pointer.
- **Hearing.** Captions for sounds: ready checks, whispers, queues, invites, duels, boss emotes,
  raid warnings, loot rolls, the aggro warning and your own alerts, each with a mark for its kind.
  Spoken alerts are with the other alerts, in Combat.
- **Flashing and motion.** Reduce motion, and Safe flashing: at most three flashes a second, all
  gentle, and the game's low-health flash off where the client allows it.
- **Focus and calm.** Calm mode (one notification at a time, until clicked), and the quieter red
  error line.
- **Reading aloud.** A key (and `/fgui read`) that reads the tooltip, the quest or the last whisper.
- **Hands and keys.** Bigger controls in the settings, and moving through them with the keyboard.
- **Share.** `/fgui access copy` and `/fgui access paste`: all of it as one line of text.

## Other add-ons

When another add-on that does the same job is running (a bar, bag, nameplate, unit frame, chat,
minimap or tooltip add-on, among others), Fantasy Glass UI leaves that job to it and says so once at login.
`/fgui check` lists which features stood aside and for what. `/fgui conflicts off` makes Fantasy Glass UI run
everything regardless.

## Key bindings

The game's Key Bindings window has a Fantasy Glass UI section: open options, move panels, keybind mode, and
clean screen.

## Coming from StylishUI

Fantasy Glass UI is StylishUI under a new name. Delete the old `Interface/AddOns/StylishUI` folder
and put `FantasyGlassUI` in its place: the two cannot run together, and if both are present, Fantasy
Glass UI stands down and says so in chat. Since 12.0, settings saved by StylishUI are not carried
over; the setup opens on your first login instead.

The command is now `/fgui`. `/sui` still works, as does `/fantasyglass`. Profile, layout and theme
strings exported from StylishUI still import.

## Where problem reports go

"Report a problem" gathers a report as text. It cannot send it: the game gives add-ons no access to
the internet. To tell people where to send it, open `Contact.lua` in a text editor and put one
address between the quotes: a web page (a form, an issues page, a Discord invite) or an email
address. The report window then shows that address in a box to copy, with short instructions.
A second setting in the same file chooses what people are asked to do: save the report as a text
file and upload it (for a form with a file-upload question), or paste it straight into the page.

## Languages

German, French, Spanish, Italian, Portuguese, Russian and Korean are included for the labels you
see most: the options, the setup, panel names and common messages. Longer explanations still show in English. The translations have not
been checked by native speakers; `Locales.lua` says how to correct or add one.

The add-on follows the game's language unless you choose one yourself. There are three places:

- **The setup's first step** has a Language button that lists them all. Picking a language reloads
  the interface and brings you back to the setup in that language.
- **The options window** has a Language button at the top right of every tab. The word "Language" on
  it is never translated, so it can always be found.
- **`/fgui language deutsch`** (or `english`, `français`, `español`, `italiano`, `português`,
  `russian`, `korean`, `auto`) does the same by typing.

Russian and Korean chosen on a client in another language use the game's own Cyrillic and Korean
fonts, since the add-on's lettering has no letters for them.

The choice is kept for your whole account. A change shows everywhere once the interface reloads.

## Translating

All button, checkbox, slider and heading labels go through one lookup table. To add a language, open
each options tab once, type `/fgui strings`, paste the result into `Locales.lua`, change `xxXX` to
your language code and fill in the right-hand sides. Lines left empty stay in English. The add-on's
chat messages are covered too; keep any `%s` or `%d` in a message, since that is where a value goes.
Error reports stay in English on purpose, so they can be looked up.

## Files

- `Core.lua`, `Skin.lua`: settings, themes and the shared drawing helpers.
- One file per feature: `UnitFrames.lua`, `RaidFrames.lua`, `BagWindow.lua`, `Tracker.lua`, and so on.
- `Media/`: fonts, textures and class emblems.

## Credits and licenses

- **Fantasy Glass UI itself** was designed and written by DustyMouse, all rights reserved; see `LICENSE.txt`. You may use it for your own play,
  but not redistribute it, share modified versions, or reuse its code or art without permission.
- **The logo** (`Media/icon.tga`) is original art made for this add-on: a tile split between a
  gold-rimmed fantasy half and an azure glass half, with a gem cut across both.
- **Class emblems** in `Media/emblem/` are original art made for this add-on: thirteen animated
  class sigils of sixteen frames each (crossing swords, a hammer under a halo, a bow drawn and
  loosed, and so on) and the disc, glow,
  rings and sparks they are built from.
- **Fonts** in `Media/` are under the SIL Open Font License 1.1; each license file sits beside its
  font (`<Name>-OFL.txt`): Exo 2, Marcellus, Fira Sans Condensed, Titillium Web, Rajdhani, Play,
  Almendra, Metamorphous, Alegreya Sans, Barlow, Chakra Petch, Share Tech Mono, Philosopher, Kelly
  Slab, Caudex, Uncial Antiqua, Pirata One, Fondamento, Staatliches, Saira Condensed, Tomorrow, Bai
  Jamjuree, Quantico, Electrolize, Aldrich, Russo One, Audiowide, Cinzel Decorative, Spectral, Forum,
  MedievalSharp, Eagle Lake, New Rocker and Lancelot. The two Exo 2 files are fixed-weight copies
  made from the original variable font; every other font file is exactly as its authors published
  it (the MedievalSharp file is only named `MedievalSharp-Regular.ttf` here, to match the others).
- **Textures and class emblems** in `Media/` were made for this add-on.
- This add-on contains no code or art from any other add-on.
