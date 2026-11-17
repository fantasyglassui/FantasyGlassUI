# Getting started with Fantasy Glass UI

Five minutes from install to a screen that feels like yours.

## 1. Install

The download holds **three folders**: `FantasyGlassUI`, `FantasyGlassUI_Options` and `FantasyGlassUI_Locales`. All three go side by side in `World of Warcraft/_forever_/Interface/AddOns/`. The CurseForge app does this for you.

- **Installing by hand:** each folder's `.toc` file must sit directly inside that folder, not one level deeper.
- **In the game's add-on list** you'll see three entries: the add-on itself, "options" and "translations". Leave all three enabled. The options and translations load only when they are needed.

## 2. The setup (first login)

The setup opens by itself the first time you log in. It takes nine short steps:

- **Language:** your game's own, or any of the nine the add-on speaks.
- **Role:** this places your frames where a tank, healer or damage player wants them.
- **Look:** pick a family, Glass, Fantasy or Runic, then one of its 38 themes.
- **Lettering:** the style of text across the whole interface.
- **Features:** how much the add-on should take over.
- **Layout:** where your panels go.

**Coming from another UI?** On the layout step, one click puts your frames where ElvUI or Tukui, RealUI, GW2 UI or the game's own interface had them.

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

Open the options with `/fgui` and go to the **Look** tab.

- **Themes:** 114 of them, in three families.
  - **Glass:** see-through panes with soft shadows.
  - **Fantasy:** solid panels with gold ornaments.
  - **Runic:** carved stone with glowing runes.
- **Previews:** each theme button shows a small picture. Point at one to see a larger card, and click it to wear it.
- **Make your own:** set three colors at the bottom of the Look tab.
- **A theme for each kind of place** is also on the Look tab: cities, dungeons, raids and battlegrounds.

Switching to another family finishes after a `/reload`.

## 5. Pick your features

The **Features** tab has every part of the add-on as a switch, in eleven sections.

- **Descriptions:** point at a switch to read what it does.
- **Safe defaults:** helpers that act for you (auto-accept, auto-sell and so on) are off until you choose them.
- **Search:** the box at the top finds any setting.

## 6. Action bars

- **Bars and frames tab** (`/fgui bars`): set each bar's buttons, rows, size, spacing, and when it shows (always, when pointed at, in combat and so on).
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
| `/fgui equipbest` | Put on every upgrade in your bags |
| `/fgui testgroup` | Practice the group panels alone |
| `/fgui quiet` | Hide chat and names for screenshots and streaming |

- **Every command:** `/fgui help` opens all of them in a window you can search (`/fgui help bags`). Click one to put it in the chat box. See [Commands](Commands.md).
- **Without typing:** Shift-click the minimap button for the Tools menu, or set key bindings for the most used tools. See [Keys and Shortcuts](Keys-and-Shortcuts.md).
- **Mistyped a command?** The add-on suggests the right one.

## 8. Tooltips your way

- **Player tooltips:** every line of a player's tooltip can be hidden or shown: title, realm, guild, level line, faction, PvP and health bar.
- **New lines:** you can also add their role, "Your friend" / "In your guild", and their health in numbers.
- **During fights:** player tooltips can be put away while you fight.
- **Where:** the Features tab, under **Player tooltips: choose the lines**. See [Player Tooltips](Player-Tooltips.md).

## 9. Keep your setup safe and share it

- **Backups** are made by themselves before each update and once a day. `/fgui backup` lists them.
- **History:** each profile remembers your changes. `/fgui history` lists them; click one to undo it.
- **Reset:** `/fgui reset` starts a profile over. Type it twice; a backup is kept first. See [Backups and Undo](Backups-and-Undo.md).
- **Profiles tab:** a profile per character, Tank, Healer and Damage templates, and **Copy my whole UI**. That button gives one string with your profile, layout, theme, bars and rules, for a friend or your guild to paste in.

## 10. If something goes wrong

- **Safe mode:** `/fgui safe` reloads with every feature off, so you can always get back to the options.
- **Self-check:** `/fgui check` writes a report on what is running.
- **Report a Problem:** the button in `/fgui` gathers what is needed into text you can copy. Save it as a text file and upload it with the form on the add-on's page.

Enjoy the game.
