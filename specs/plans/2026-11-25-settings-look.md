# A Sleek, Modern Settings Window — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The `/fgui` settings window gets one fixed, calm dark look of its own (Barlow lettering, grouped cards, switches, a filled sidebar, a picture grid of themes), taking only the accent colour from the player's theme, and ships as 12.3.0.

**Architecture:** A "look" is a fixed palette that `ns:Paint` and `ns:Font` use for anything inside a frame marked `suiLook` (the settings window and its own pop-ups); every other window keeps resolving roles through the theme exactly as today. Pages then restyle their layout (rows in cards, sidebar, Home, Themes) on top of that.

**Tech Stack:** WoW Forever (interface 16001) add-on Lua 5.1; tests in `tests/smoke.py` (Lua run under stubs, two modes); luacheck; `tests/forever_audit.py`, `tests/secretaudit.py`, `tests/lockaudit.py`.

**Spec:** `specs/2026-11-25-settings-look-design.md` (approved mock-ups: the "Settings window redesign" design canvas: Home, Combat › Alerts and reminders, Look and themes › Themes).

## Global Constraints

- Branch `settings-look` in `/home/claude/fantasyglassui-settings`. Implementers never push; the controller pushes to main with `[release]` only at the end.
- Commits authored `DustyMouse <fantasyglassui@users.noreply.github.com>`, no attribution lines.
- Checks before every commit: `luacheck . -q` 0 warnings; `python3 tests/smoke.py` prints `errors: no errors` in both modes (as for every earlier release); forever_audit, secretaudit, lockaudit clean.
- Every new phrase in all 9 languages (`FantasyGlassUI_Locales/Locales.lua`).
- Look palette (normal): ground `#12141a`, cards `#181b22`, selection/buttons `#1e222b`/`#1f232d`, fields `#1a1d25`, rules `#22262f`, window rim `#262b36`, text `#e9ecf3`, secondary `#9aa3b5`/`#8b94a6`, faint `#6f7889`. Accent = the theme's `@accent`, live.
- Look palette (high contrast, when the theme is `CONTRAST`, `FCONTRAST` or `C_CONTRAST`): ground and cards `#000000`, fields `#0a0a0a`, rules and rim `#ffffff`, text `#ffffff`, secondary `#e6e6e6`, faint `#cccccc`; accent as the theme's.
- Lettering in the window: `Barlow-Medium.ttf` body, `Barlow-SemiBold.ttf` titles (both in `FantasyGlassUI/Media`), only for Latin-script locales; Korean, Chinese and Russian keep the faces `ns.FONT`/`ns.TITLEFONT` pick today; the lettering styles `READABLE` and `DYSLEXIC` win over Barlow; `ns.fontScale` and `ns.FONTFLAGS` outline choices still apply.
- Sizes: body 14, descriptions 12–13, page titles 24, section labels 13 upper-case.
- Only the settings window changes. Setup, help, bags, frames, the game's windows and every other add-on window keep wearing the theme.
- No setting is added, removed or moved; no "modern / themed" switch.
- The quest planner stays out of every public text (changelog, release notes, site, help, wiki).

## Review Focus

1. Changing theme or accent with the window open: the accent repaints at once; nothing else in the window changes colour (test in Task 1).
2. A high-contrast theme picked while the window is open: the window switches to the high-contrast look without a reload (test in Task 1).
3. German/Russian text at the largest text size: rows grow and wrap, nothing clipped or overlapping (test in Task 2: a row's height grows with a long description at fontScale 1.3).
4. Korean, Chinese and Dyslexia-friendly lettering: never replaced by Barlow (test in Task 1).
5. The window resized to its minimum: theme grid drops to fewer columns, sidebar and preview stay usable (test in Task 4).

---

### Task 1: The look: palette, lettering and the window's ground

**Files:**
- Modify: `FantasyGlassUI/Skin.lua` (`ns:Role`, `ns:Paint`, `ns:Repaint`, `ns:Font`), `FantasyGlassUI_Options/Config.lua` (Build: window ground, header, footer)
- Test: `tests/smoke.py`

**Interfaces:**
- Produces:
  - `ns.LOOKS = { settings = {...}, settingsContrast = {...} }`: role → `{r,g,b}` for every non-accent role the Options files paint (grep `ns:Paint(` in `FantasyGlassUI_Options/*.lua` and `ns:CreateCheckbox`/`ns:CreateButton` in Skin.lua for the roles; at least `window`, `@bg`, `bg`, `field`, `@border`, `@rim`, `@light`, `@btn`, `text`, `dim`, `faint`), mapped onto the palette above. `@accent` and `accent` are never in a look.
  - `ns:LookOf(obj) -> table|nil`: the look for an object: walk `GetParent()` up to 30 levels; the first frame with `rawget(f, "suiLook")` gives `ns.LOOKS[f.suiLook]`, swapped for `settingsContrast` when `ns:IsHighContrast()`. Cached per painted entry; a frame marked later is found on the next repaint.
  - `ns:IsHighContrast() -> boolean`: the current theme key is `CONTRAST`, `FCONTRAST` or `C_CONTRAST`.
  - `ns:Role(role, alpha, obj)`: a look from `obj` wins for roles it holds; everything else as today. `ns:Paint` passes the object; `ns:Repaint` too.
  - `ns:Font(fs, size, title)`: inside a look, Barlow per the Global Constraints, else as today.
  - Config.lua: `O.frame.suiLook = "settings"`; the window no longer calls `ns:Dress` (no sky, grain or glass); it keeps the Starcut corner cut (`ns.StarcutWindow`) and gets a 1px rim; header 60 px (logo diamond, name, search field filling the middle, profile chip, close); footer 52 px (Run setup again, Report a problem, Discord on the left; version and Undo last change on the right), with `#22262f` rules between.
- [ ] **Step 1: Failing test** `try("12.3 settings look: palette, accent, contrast, lettering", ...)`: open the settings window; a texture painted `"window"` under it reads `#12141a` while one painted `"window"` on another frame reads the theme's; a texture painted `"@accent"` under it reads the theme's accent and, after `ns:SetAccent` to another accent and `ns:Repaint()`, the new one; switching the theme to `C_CONTRAST` and repainting turns the ground `#000000` and text `#ffffff`; a font string in the window is set to `Barlow-Medium.ttf` with `enUS`, keeps its old face with `koKR`, `zhCN`, `ruRU`, and with fontStyle `DYSLEXIC`.
- [ ] **Step 2: Run** `python3 tests/smoke.py` → the new test fails.
- [ ] **Step 3: Implement** as in Interfaces.
- [ ] **Step 4: Run** all checks → pass, both modes.
- [ ] **Step 5: Commit** `"Settings window: its own calm look, accent from the theme"`.

### Task 2: Settings rows in cards, and the switches

**Files:**
- Modify: `FantasyGlassUI_Options/FeaturesPage.lua`, `FantasyGlassUI_Options/Categories.lua`, `FantasyGlassUI_Options/Shared.lua` (`O.Header`, `O.Band`), `FantasyGlassUI/Skin.lua` (`ns:CreateCheckbox` sizes inside a look), plus the other pages' rows as they appear inside the settings window (CombatPage, LayoutPage, Bars, Tools slices)
- Test: `tests/smoke.py`

**Interfaces:**
- Consumes: Task 1's look (`ns:LookOf`, palette roles).
- Produces: a section page draws, under a breadcrumb (12 px, secondary) and a 24 px title, its settings in cards (`#181b22`, 10 px corner where `ns:CanRound()`, else the Starcut cut), one row per setting: title (14, medium), description under it (13, secondary, wrapping), the switch (38×22 track, 16 px knob; accent with a dark knob when on, `#2c313c` with a grey knob when off) on the right, an optional "Set up" button left of it for settings that open more, a `NEW` tag in the accent after the title where today's NEW tag shows; rows separated by `#22262f` rules, 14 px vertical padding; row height grows with the wrapped description. An All / On / Off filter at the title's right. Footer gains "Reset <category> to how it came" on section pages (that action exists today; it moves here).
- [ ] **Step 1: Failing test** `try("12.3 settings look: rows and switches", ...)`: open Combat › Alerts and reminders; each setting row has its title, description and a switch whose on/off matches the saved setting; clicking the switch flips the setting, the tooltip still shows, a dependent setting is still dimmed while its parent is off; the All/On/Off filter shows only on or only off rows; at `ns.fontScale = 1.3` with deDE text a row with a long description is taller than at 1.0 and no row overlaps the next.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, all checks. Step 5: Commit** `"Settings window: settings in cards, a switch on every row"`.

### Task 3: Sidebar and Home

**Files:**
- Modify: `FantasyGlassUI_Options/Config.lua` (sidebar draw ~lines 350-430; Home cards ~800-910), `FantasyGlassUI_Options/Categories.lua` (icons per category)
- Test: `tests/smoke.py`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  - Sidebar 216 px: Home and each category, 36 px rows, 14 px; the open category's sections indented 26 px, 32 px rows, 13 px; the selected row on a filled `#1f232d` background (rounded where `ns:CanRound()`), white text; others secondary. No counts, no accent bar. Icons (16 px, line art in the row's text colour) for Home and the categories: drawn from textures already in `FantasyGlassUI/Media` where one fits, else none (no new art is required for this release).
  - Home: "Good evening, <class>" style greeting (morning/afternoon/evening by `GetGameTime`, the player's class name), a line "<theme name> · <Starcut or Classic> frames · <n> settings, <m> switched off"; quick switches as a 3-column grid of cards (title, one-line hint, switch), from the quick switches Home shows today; two cards below: "New in <version>" (what changed lately, a diamond bullet in the accent) and "Ask the guide" (the guide's question box and the class suggestions with "Turn on").
- [ ] **Step 1: Failing test** `try("12.3 settings look: sidebar and Home", ...)`: the sidebar has no count text; picking a section marks only that row selected; Home shows the greeting with the class name, the theme name line with correct counts, one card per quick switch whose switch flips its setting, and the "New in 12.3" card lists the current What's new lines.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, all checks. Step 5: Commit** `"Settings window: a cleaner sidebar and Home"`.

### Task 4: The Themes page

**Files:**
- Modify: `FantasyGlassUI_Options/LookPage.lua` (the theme picker part), `FantasyGlassUI_Options/Shared.lua` (`O.ThemeSwatch`, `O.ShowThemeSwatch`)
- Test: `tests/smoke.py`

**Interfaces:**
- Consumes: Tasks 1–3; `ns.themes` (each theme's `panel`/`bg`, `rim`, `accent` colours and `style`).
- Produces: a family control (Glass / Fantasy / Celestial, the current theme's family first selected); a grid of tiles, 4 columns at the default width and 3 or 2 as the window narrows: each tile a 52 px swatch in that theme's panel colour with a top edge and two bars in its rim colour (Celestial tiles with three small star dots), its name under it; the current theme's tile ringed 2 px in the accent; a 250 px preview column on the right: a sample unit frame in the picked theme's colours, the name "<Family>: <Theme>", the family's one-line description (the existing ones), "Use this theme" (accent fill) and "Make my own" (opens today's theme maker). Picking a tile previews; "Use this theme" applies it exactly as clicking a theme does today (including the reload note between families). Class-colour and custom themes appear as tiles too; the high-contrast themes are tiles in their families.
- [ ] **Step 1: Failing test** `try("12.3 settings look: themes page", ...)`: the family control lists three families; Glass shows every Glass theme as a tile; clicking a tile changes the preview name but not the theme; "Use this theme" applies it; the current theme's tile is the ringed one; at the window's minimum width the grid has fewer columns than at the default and no tile overlaps the preview column.
- [ ] **Step 2: Fail. Step 3: Implement. Step 4: Pass, all checks. Step 5: Commit** `"Settings window: themes as a picture grid with a preview"`.

### Task 5: Release 12.3.0 texts

**Files:**
- Modify: the three TOCs (`## Version: 12.3.0`), `CHANGELOG.md` and `FantasyGlassUI/CHANGELOG.md` (new `## 12.3.0` at the top), `RELEASE.md` (12.3.0 only), the in-game What's new list (Core.lua, where 12.2's lines are), `site-src/site/data.js` news, the wiki page that describes the settings window if any; then `python3 site-src/make_i18n.py` and `python3 site-src/build_site.py`.
- Test: `tests/smoke.py` (existing version/changelog checks).

**Interfaces:**
- Produces: release notes in the add-on's voice, along these lines: "A new look for the settings window: calm and dark whatever your theme, with only your theme's accent colour, clear lettering, settings in cards with a switch on each, a tidier list of categories down the left, and the themes shown as a grid of pictures with a large preview. High-contrast themes give it a black-and-white version, and the readable and dyslexia-friendly lettering still apply." Translated in all 9 languages where the in-game What's new and site news need it. Nothing about the quest planner.
- [ ] **Step 1:** Write the texts and bump versions. **Step 2:** Run all checks and both site scripts. **Step 3: Commit** `"12.3.0: a new look for the settings window"` (no `[release]` here; the controller adds the release commit after the in-game check).
