# Fantasy Glass UI

[![Tests](https://github.com/fantasyglassui/FantasyGlassUI/actions/workflows/Testing.yml/badge.svg)](https://github.com/fantasyglassui/FantasyGlassUI/actions/workflows/Testing.yml)

A complete interface in one add-on for **WoW Forever** (interface 16001): unit frames, action bars,
raid frames, nameplates, bags, quests, minimap, chat and every one of the game's own windows, in one
look you choose from **115 glass, fantasy and celestial themes**.

**[Website](https://fantasyglassui.com)** · **[Discord](https://discord.gg/qeSMwQWyPR)** · **[Download on CurseForge](https://www.curseforge.com/wow/addons/fantasy-glass-ui)** ·
**[Wiki](../../wiki)** ([also here](wiki/README.md)) · **[Report a bug or suggest an idea](../../issues/new/choose)** ·
**[What's changed](CHANGELOG.md)**

## Install

Use the CurseForge app, or download the zip and put its **three folders** (`FantasyGlassUI`,
`FantasyGlassUI_Options`, `FantasyGlassUI_Locales`) side by side in
`World of Warcraft/_forever_/Interface/AddOns/`. A guided setup opens the first time you log in.
More on the wiki's [Installation](../../wiki/Installation) and
[Getting Started](../../wiki/Getting-Started) pages.

## What's in this repository

| Folder | What it is |
|---|---|
| `FantasyGlassUI/` | The add-on itself: every feature, the themes, the art in `Media/` |
| `FantasyGlassUI_Options/` | The options window, the setup and the self-check, loaded only when opened |
| `FantasyGlassUI_Locales/` | The translations, loaded only for languages other than English |
| `CHANGELOG.md` | Every release and what it changed |

Release zips are on CurseForge; this repository holds the same files as the latest release.

## Reporting problems

Open an issue with the **Bug report** form. The most useful thing to include is the add-on's own
report: open `/fgui` in the game, press **Report a Problem**, and paste the text. `/fgui check new`
reports on the newest features.

## License

Copyright (c) 2026 DustyMouse. **All rights reserved.** The source is public so you can read it and
report problems, not to reuse: see [LICENSE](LICENSE). The bundled fonts are under the SIL Open Font
License; each one's license file sits beside it in `FantasyGlassUI/Media/`.

Ideas and bug reports are very welcome as issues. Pull requests can't be merged, as the code is not
open source; describe the change in an issue instead.
