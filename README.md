# Fantasy Glass UI

[![Tests](https://github.com/fantasyglassui/FantasyGlassUI/actions/workflows/Testing.yml/badge.svg)](https://github.com/fantasyglassui/FantasyGlassUI/actions/workflows/Testing.yml)

A complete interface in one add-on for **WoW Forever** (interface 16001): unit frames, action bars,
raid frames, nameplates, bags, quests, minimap, chat and every one of the game's own windows, in one
look you choose from **116 glass, fantasy and celestial themes**.

**[Website](https://fantasyglassui.com)** · **[Discord](https://discord.gg/qeSMwQWyPR)** · **[Download on CurseForge](https://www.curseforge.com/wow/addons/fantasy-glass-ui)** ·
**[Wiki](../../wiki)** ([also here](wiki/README.md)) · **[Report a bug or suggest an idea](../../issues/new/choose)** ·
**[What's changed](CHANGELOG.md)**

## Install

Use the CurseForge app, or download the zip and put its **five folders** (`FantasyGlassUI`,
`FantasyGlassUI_Options`, `FantasyGlassUI_Locales`, `FantasyGlassUI_Planner`, `FantasyGlassUI_Gold`)
side by side in `World of Warcraft/_forever_/Interface/AddOns/`. A guided setup opens the first time you log in.
More on the wiki's [Installation](../../wiki/Installation) and
[Getting Started](../../wiki/Getting-Started) pages.

## What's in this repository

| Folder | What it is |
|---|---|
| `FantasyGlassUI/` | The add-on itself: every feature, the themes, the art in `Media/` |
| `FantasyGlassUI_Options/` | The options window, the setup and the self-check, loaded only when opened |
| `FantasyGlassUI_Locales/` | The translations, loaded only for languages other than English |
| `FantasyGlassUI_Planner/` | The route planner for the quest guides, loaded the first time it is used |
| `FantasyGlassUI_Gold/` | Ways to make gold, loaded the first time it is opened or the auction house is visited |
| `CHANGELOG.md` | Every release and what it changed |

Release zips are on CurseForge; this repository holds the same files as the latest release.

## Releasing

A release: raise the version in all five TOCs and `ns.version` in `FantasyGlassUI/Core.lua`
(for example `13.5.0`), then commit to `main` with `[release]` in the message. The workflow tags
the version and the packager uploads it to CurseForge and GitHub.

A beta: set every TOC and `Core.lua` to `13.5.0-beta.1` (the next beta is `-beta.2`), then commit
with `[beta]` in the message, on `main` or on a branch named `beta/<name>`. CurseForge files it as
Beta and GitHub as a prerelease. A commit cannot say both `[release]` and `[beta]`.
`.github/release-version.sh <release|beta>` runs the same version check on your own computer.

Players get a beta by setting the add-on to **Beta** in the CurseForge app. Nobody gets one by
accident: the default is Release.

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
