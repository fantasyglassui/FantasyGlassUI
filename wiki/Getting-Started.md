# Getting started with Fantasy Glass UI

Five minutes from install to a screen that feels like yours.

## 1. Install

The download holds **five folders**: `FantasyGlassUI`, `FantasyGlassUI_Options`, `FantasyGlassUI_Locales`, `FantasyGlassUI_Planner` and `FantasyGlassUI_Gold`. All five go side by side in `World of Warcraft/_forever_/Interface/AddOns/`. The CurseForge app does this for you.

- **Installing by hand:** each folder's `.toc` file must sit directly inside that folder, not one level deeper.
- **In the game's add-on list** you'll see five entries: the add-on itself, "options", "translations", "planner" and "gold". Leave all five enabled. The other four load only when they are needed.

## 2. The setup (first login)

The setup opens by itself the first time you log in. It takes four short steps:

- **Welcome:** your language, and how much the add-on should take over: the whole interface, only a new look for the game's own frames, or everything.
- **How you play:** your role (this places your frames where a tank, healer or damage player wants them), and what you enjoy: questing, groups, PvP, collecting, being social. Each switches on what suits it.
- **Your look:** pick a family, Glass, Fantasy or Celestial, then one of its themes, an accent and a text size.
- **Ready:** a summary of what you chose, and a layout to start from.

**Coming from another UI?** On the last step, one click puts your frames in a layout like that of ElvUI or Tukui, RealUI, GW2 UI or the game's own interface.

Press **Finish and reload** at the end. You can run the setup again any time with `/fgui setup`.

**A new character** doesn't need the setup. It starts from your main's setup, fitted to its class. `/fgui main` chooses which character is your main.

## 3. Move things where you want them

Type `/fgui move`. Every panel shows a handle, and you can drag it anywhere.

- **Snapping:** panels snap to a grid and to each other. Hold **Shift** to place one freely.
- **Per-panel settings:** right-click a panel to set its size and when it shows.
- **Undo:** `/fgui undo` takes back the last move.
- **Sample frames:** `/fgui test` shows sample frames (target, party, raid, bosses and more) so you can place them alone.
- **Whole-screen layouts:** `/fgui gallery` has six to start from, each with a picture.

## 4. Choose your look

Open the settings with `/fgui` and choose **Look and themes** in the list on the left.

- **Themes:** 116 of them, in three families.
  - **Glass:** see-through panes with soft shadows.
  - **Fantasy:** solid panels with gold ornaments.
  - **Celestial:** a night sky with stars and constellations.
- **Previews:** each theme shows a small picture in the grid. Click one to preview it beside the grid (a sample frame in its colors, its name and family), then **Use this theme** to wear it.
- **Make your own:** set three colors in Look and themes › Your own theme.
- **A theme for each kind of place** is in Look and themes › Theme by place: cities, dungeons, raids and battlegrounds.

Switching to another family finishes after a `/reload`.

- **Frame style:** in **Frames and bars › Your frames**. **Starcut** (new in 11.12) cuts health and power bars to points that glow in their own color, beside a diamond portrait with stars on its points, and since 11.13 it reaches every bar: your cast bar, the crafting bar, the class resource, raid frames, nameplates, timers, experience and totems. Since 11.14 action buttons and bag slots are cut like gems too (bag slots with their rim in the item's quality color), and `/fgui` has **Minimap: diamond**. Since 11.15 windows and tooltips have their corners cut too, with a fine rim along each cut and stars on big windows. **Classic** brings back the box everywhere at once (chosen during a fight, it changes when the fight is over).

- **Text and interface size:** in **Look and themes › Accessibility**, three text sizes for the add-on's lettering and **Interface size** (50 to 150%) for the whole interface. From chat: `/fgui textsize 120` (any size from 70 to 150) and `/fgui uisize 90` (`reset` puts either back). The slider takes effect when you let go.

## 5. Pick your features

Every part of the add-on is a switch, in the category and section it belongs to: Frames and bars, Combat, Bags and items, Quests and map and the rest, listed down the left of `/fgui`. **Home** greets you with the theme you wear, has the quick switches as cards with the three presets, what is new and *Ask the guide*. At the top of the list on the left, **Simple** shows the settings most players look for and **All options** shows every one.

- **Descriptions:** every setting says what it does under its name; point at it for the whole story.
- **Undo:** **Undo last change** in the window's footer takes back what you changed, one step at a time; point at it to see your last few changes. **Reset <category> to how it came**, beside it, puts the open category's switches and sliders back (click twice).
- **Safe defaults:** helpers that act for you (auto-accept, auto-sell and so on) are off until you choose them.
- **Search:** the box in the window's header finds any setting and says where it lives.

## 6. Action bars

- **Frames and bars › Action bars** (`/fgui bars`): set each bar's buttons, rows, size, spacing, and when it shows (always, when pointed at, in combat and so on).
- **Fantasy Glass action bars:** switch these on to get eight bars of the add-on's own, plus a stance bar, without Edit Mode.
- **Keybind mode** (`/fgui bind`): hover a button and press a key.
- **Key binding sheet** (`/fgui keys`): every bar and its keys on one screen.

## 7. Tools at your fingertips

The **Tools** button on the menu bar (or `/fgui tools`) opens a button for every tool window, so you don't need to remember commands. Some of the most used:

| Command | What it does |
|---|---|
| `/fgui ready me` | Am I ready for the raid? Food, flask, repairs, reagents, bag space |
| `/fgui bossnote` | Read or write your target's boss note |
| `/fgui death` | What hit you before you died |
| `/fgui alts` | All your characters, their gold and more |
| `/fgui crafts` | What all your characters can craft |
| `/fgui briefing` | What is waiting for you: crafts ready, mail, lockouts reset, jobs left |
| `/fgui recap` | Your last week on every character: gold, time, levels, raids, best loot |
| `/fgui skillups` | With a profession window open: the recipes that still give skill points |
| `/fgui equipbest` | Put on every upgrade in your bags |
| `/fgui testgroup` | Practice the group panels alone |
| `/fgui quiet` | Hide chat and names for screenshots and streaming |
| `/fgui showcase` | Screenshot mode: every frame with sample data, nothing in the way |
| `/fgui drops` | The loot browser: what each boss dropped, your upgrades first |
| `/fgui farm` | A farming session: gold and item value an hour (`stop` ends it, `zones` for your best spots) |
| `/fgui wish` | Your loot wishlist: the items you starred in the loot browser, and where each drops |
| `/fgui gear` | Everyone in your group with their item level, the lowest first, and the average |
| `/fgui stats` | Lifetime stats for this character and all of them |
| `/fgui runs` | Your dungeon and raid runs, with a best time for each place |
| `/fgui goal` | Goals: `rep <faction>`, `gold 10000`, `level 60`, `mount <name>`, or an item and a number |
| `/fgui set <name>` | Put on a gear set by name; on its own, the list of your sets |
| `/fgui threat` | Show or hide the threat meter |

- **Every command:** `/fgui help` opens all of them in a window you can search (`/fgui help bags`). Click one to put it in the chat box. See [Commands](Commands).
- **Without typing:** Shift-click the minimap button for the Tools menu, or set key bindings for the most used tools. See [Keys and Shortcuts](Keys-and-Shortcuts).
- **Mistyped a command?** The add-on suggests the right one.
- **Login briefing:** a few seconds after you log in, one small window says what is waiting. Click a line to open the window it comes from. It only shows when something is waiting.
- **Weekly recap:** each character's week is noted as you play it. When a new week starts, the login briefing says the recap is ready.
- **Screenshot mode:** `/fgui showcase` gives every frame a sample worth a picture (a boss as your target mid-cast, a party of four) and clears away the options, movers, tooltip and busier samples. The same command or a fight ends it.
- **Loot browser:** what each boss drops is noted as you kill it, from your loot window, the loot rolls and your group's loot lines, and shared by all your characters. `/fgui drops` lists it raid by raid and boss by boss; `/fgui drops <name>` goes straight to one raid or dungeon.
- **Threat meter:** in a group with a hostile target, a small panel shows the top five on threat. Your row turns the warning color near the top and the danger color when you would pull. Move it with `/fgui move`.
- **Farming sessions:** `/fgui farm` starts one; a small panel shows the time and what you make an hour, in gold and in looted items (the auction price you have seen, or the vendor's). A `/reload` keeps it going, and each finished session counts in your weekly recap.
- **Equip prompt:** loot an upgrade and a small notice offers to put it on; for a ring or a trinket you choose which one it replaces.
- **Milestones:** your 1,000th kill, 100th quest, first boss and more get a short notice, and `/fgui stats` lists them with the day.
- **Boss guide:** when you target or pull a boss, its abilities from the dungeon journal show under your boss note.
- **Roll advice:** the loot roll window lights the button to press and says why: Need for a wish or an upgrade, Pass for gear you can't use, Greed for the rest. Nothing is rolled for you.
- **Group gear check:** `/fgui gear` lists everyone in your group with their item level, filling in as the game sends each player's gear.
- **Lifetime stats:** `/fgui stats` gives totals for this character and all of them, with your best run times.
- **Nameplates of our own:** the health bar on a nameplate is the add-on's own, on a black backing, with the level in its difficulty color beside the name.
- **Loot wishlist:** click an item in the loot browser to star it. You are told when it drops, comes up in a roll, or a boss that drops it becomes your target; `/fgui wish` lists them with where each drops.
- **Boss drops on the boss:** point at a boss and its tooltip lists what it drops that is on your wishlist or would be an upgrade for you.
- **Quest mobs on nameplates:** the plate of a mob you still need for a quest gets a small quest mark with how many are left (Nameplates designer, "Quest mobs").
- **Farming by zone:** each session also notes where you farmed. `/fgui farm zones` lists your best spots by what they make an hour, and whether your latest time there was up or down.
- **Run log:** each dungeon and raid you go into is a run: its time, the bosses killed and when, wipes, your deaths and your rare and better loot. `/fgui runs` lists them place by place with a best time each (the quickest of the runs that killed the most bosses).
- **Whose upgrade:** in a group, when a boss drops something rare or better, players with the add-on quietly tell each other whether it is an upgrade, and a small panel shows whose upgrade it is and by how many item levels, before anyone rolls.
- **Goals panel:** gold on all your characters, a level and a mount join reputations, items, achievements and your own goals. An item counts on every character, and its tooltip says which boss drops it.
- **Nameplates:** the threat color can sit on the plate's edge too (Nameplates designer, "Threat on the plate's edge"), so a tank sees which mob is slipping.
- **Gear sets:** the set you are wearing is named over your player frame. `/fgui set <name>` puts one on (part of the name will do), and the first five sets can have keys.
- **Skill-ups:** the profession window gets a Skill-ups button listing the recipes that still give skill points, best first: what you can make now, then what needs the least.

## 8. Tooltips your way

- **Player tooltips:** every line of a player's tooltip can be hidden or shown: title, realm, guild, level line, faction, PvP and health bar.
- **New lines:** you can also add their role, "Your friend" / "In your guild", and their health in numbers.
- **During fights:** player tooltips can be put away while you fight.
- **Where:** Chat and people › Player tooltips. See [Player Tooltips](Player-Tooltips).

## 9. Keep your setup safe and share it

- **Backups** are made by themselves before each update and once a day. `/fgui backup` lists them.
- **History:** each profile remembers your changes. `/fgui history` lists them; click one to undo it.
- **Reset:** `/fgui reset` starts a profile over. Type it twice; a backup is kept first. See [Backups and Undo](Backups-and-Undo).
- **Layout and profiles › Profiles:** a profile per character, Tank, Healer and Damage templates, and **Copy my whole UI**. That button gives one string with your profile, layout, theme, bars and rules, for a friend or your guild to paste in.

## 10. Quest guides, the planner and gold

- **Quest guides:** the Guide tab in `/fgui` has the switch and your guides. A panel shows the step you are on, and an arrow points the way. `/fgui guide` lists your guides, and `/fgui guide record My route` records one as you play.
- **Plan my route:** on the Guide tab, or `/fgui guide plan`. The planner works out a route of quests for your level and plans again as you play. It finds quests through Questie when Questie is loaded.
- **The planner window:** `/fgui plan`, or **Planner** on the guide panel. It has every setting for what the planner plans, and **How the planner works**, a short tour. **Keep my route** there leaves your route as it is until you press Plan my route or Plan again.
- **With a friend:** **Plan with a friend**, in the panel's "..." menu, plans one route for you both. **Share plan** gives a plan code to read on the website's plan page.
- **Ways to make gold:** Ctrl-click the minimap button, or `/fgui guide gold`. Pick an idea and press **Go**: the trip goes on the guide panel, and your levelling route comes back after it.

## 11. If something goes wrong

- **Safe mode:** `/fgui safe` reloads with every feature off, so you can always get back to the options.
- **Self-check:** `/fgui check` writes a report on what is running.
- **Report a problem:** the button in `/fgui` gathers what is needed into text you can copy. Save it as a text file and upload it with the form on the add-on's page.

Enjoy the game.
