# Installation

## With the CurseForge app
Search for **Fantasy Glass UI** and install. The app puts everything in the right place. [The add-on on CurseForge](https://www.curseforge.com/wow/addons/fantasy-glass-ui).

## By hand
1. Download the zip from [CurseForge](https://www.curseforge.com/wow/addons/fantasy-glass-ui).
2. It holds **three folders**: `FantasyGlassUI`, `FantasyGlassUI_Options` and `FantasyGlassUI_Locales`.
3. Put all three, side by side, in `World of Warcraft/_forever_/Interface/AddOns/`.
4. Check that each folder's `.toc` file sits directly inside it (`AddOns/FantasyGlassUI/FantasyGlassUI.toc`), not one level deeper.
5. Start the game, or type `/reload`.

In the game's add-on list there are three entries: the add-on, **options** and **translations**. Leave all three enabled. The options load the first time you open them, and the translations only for a language other than English, so neither costs memory until it is needed.

## Updating
Install over the old version. Your settings are kept, and a backup of them is made before each update (`/fgui backup`).

## Other add-ons
Fantasy Glass UI replaces the unit frames, bags, action bars and more. If you also run an add-on that does one of those jobs (another bag or bar add-on, another UI suite), Fantasy Glass UI leaves that job to it and says so; or switch the matching feature off in `/fgui`.
