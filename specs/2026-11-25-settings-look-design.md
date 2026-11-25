# A sleek, modern settings window (12.3.0)

Approved mock-ups: the "Settings window redesign" design canvas (Home, Combat › Alerts and
reminders, Look and themes › Themes). The user: "I love it." Option 1 chosen; ship it in a release.

## Intent

The 12.0 redesign changed how the settings window is organised, not how it looks. It still wears
the player's theme (a moving star field behind the text in Celestial, serif theme lettering, an
outlined box round every option, small dim text, tight rows) and reads as busy and old-fashioned.
The window should look calm, sleek and modern, like a current desktop app, while staying
recognisably Fantasy Glass UI.

## Goals

- The settings window (`/fgui`, every category and section, Home, search results, the header and
  footer) gets one fixed look of its own:
  - ground `#12141a`, cards `#181b22`, sidebar selection and buttons `#1e222b`/`#1f232d`, fields
    `#1a1d25`, rules `#22262f`, window rim `#262b36`;
  - text `#e9ecf3`, secondary text `#9aa3b5`/`#8b94a6`, faint text `#6f7889`;
  - one highlight colour: the current theme's accent (`@accent`), and nothing else from the theme.
- Lettering: Barlow (Medium/SemiBold, already in `FantasyGlassUI/Media`) for every text in the
  window, about 14 px body, 24 px page titles, 12–13 px descriptions. Korean and Chinese keep
  `ns.LANGUAGE_FONTS`. The accessibility lettering choices (low vision, dyslexia) and the font
  scale still win over Barlow.
- Settings sit in grouped cards with room between rows; a row is title, description under it, the
  control on the right. No outline round each option.
- On/off settings are switches (a track with a knob, accent when on, grey when off), not
  checkboxes. Same behaviour, tooltips, dimming of dependent settings and keyboard use as today.
- The sidebar: Home and the categories (icons where the mock-up has them), the open category's
  sections indented under it, the selected one on a filled rounded background. No setting counts.
- Home: greeting line with the current theme and counts, quick switches as cards, "New in …" and
  "Ask the guide" cards, as in the mock-up, filled from what Home shows today.
- Themes page: a family control (Glass / Fantasy / Celestial), a grid of tiles showing each
  theme's real panel and rim colours (Celestial tiles with a few stars), the picked tile ringed in
  the accent, and a preview column on the right (a sample frame in that theme, its name and family
  description, "Use this theme" and "Make my own").
- The window's own corners keep the Starcut cut; the diamond stays in the logo.
- High contrast: when a high-contrast theme is in use, the window uses a high-contrast version of
  its fixed look (pure black ground, white text and rims), so nothing gets less readable.

## Non-goals

- Every other window keeps wearing the theme: bags, frames, the game's own windows, the setup,
  help, loot browser and the rest are untouched.
- No new settings and no moved settings; the 12.0 organisation stays.
- No "themed / modern" switch for the settings window (option 2, not chosen).

## Anti-goals

- A window that is harder to read than today in any language, at any font scale, or with any
  accessibility setting.
- Text that no longer fits (German and Russian run long): rows wrap rather than clip.

## Approaches considered

1. Its own look for the settings window only, accent from the theme. Chosen: smallest, least
   risky, exactly what the mock-ups show; themes still cover the rest of the screen.
2. The same plus a "modern / themed" setting. Not chosen: two looks to maintain.
3. The modern look on every add-on window. Not chosen: much bigger, works against the themes.

## Release

12.3.0, pushed to main with `[release]` (the user asked for the release). Version in the three
TOCs, CHANGELOG.md (both copies), RELEASE.md, the site's news and What's new, the wiki if it
describes the window's look. The quest planner stays out of every public text.

## Left to the builder

How the fixed palette is applied (for example a settings-only palette that `ns:Paint` uses for
objects under the settings frame, with `@accent` passed through); how the switch widget is drawn
(flat textures, a rounded track if art exists, otherwise the Starcut cut); exact spacing, within the
mock-ups' proportions.

## Later (recorded here, not in this release)

The quest planner gets its own button and its own settings window when it is finished, instead of
its switches on the Guide tab of these settings (user, 25 Nov).
