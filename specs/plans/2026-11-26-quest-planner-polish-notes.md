# Quest planner polish fix wave: merge notes

Branch `quest-planner`, from 1023912. The four groups were merged `--no-ff` in this order: P1 (1cf9ab7), P2 (2055c34),
P3 (f968f4d) and P4 (c22ee85). The cross-group fixes, the translations, the removal of unused keys and the integration
test were then committed on top. The group reports in `.superpowers/sdd/polish-p1-report.md` to `polish-p4-report.md`
list every finding ID with its outcome. This file covers the merge.

## What changed

- **P1, planning and speed:**
  - Questie reading no longer gives up on one bad record (F1). Logged quests that Questie does not list are planned (F2).
  - While Questie loads, planning waits, then falls back to the quest log after 30 s (F3).
  - No plan is made in the air, as a ghost or away from the outdoor world, and the panel says why (F4, F11).
  - Two lines ask you to set a hearthstone and to open a flight map (F5).
  - Skips (F7, F8, F24):
    - A skip also applies for the session.
    - An abandoned quest stays out of plans for the session.
    - A /reload keeps the session's skips.
  - Time limits (F14, F15):
    - Plan my route starts the Guide tab's default limit.
    - The break note reads "Good place to take a break".
    - "Keep playing" appears when the limit runs out.
  - The speed work:
    - Spread is O(n) past 48 spots.
    - Positions are cached.
    - Grind spots keep the top 3.
    - Bursts settle before a plan.
    - Game values are guarded.
    - Quest times and nodes are capped.
  - The best reward is marked and named in chat ("Best reward for you: %s"), never clicked.
- **P2, panel, guide, arrow and windows:**
  - The panel's layout is measured and follows the font scale. The panel now starts at TOPRIGHT −290, −300 and grows down.
  - The arrow: stacked, banded, placed at TOP 0, −345.
  - List rows and notes scale and wrap. List colours come from the theme, including the colour-vision palette.
  - The duo ask can be used from the keyboard. It is read aloud, counts down and closes at 0.
  - Flows:
    - ">" on a quest step is a session skip.
    - A failed "do" step says what to do.
    - Hearth, fly and sail steps tick where they land.
    - At the end of a route, the planner plans again.
    - Preview entries, the copy caption and the duo replies (F6–F40, as listed in the report).
  - Key bindings: the tokens are now neutral (`FANTASYGLASSUI_EXTRA1`–`3`). While the guide is locked their names read "Fantasy Glass UI: extra 1/2/3"; once unlocked they read "Guide: …".
  - `Store()` creates nothing on reads.
- **P3, the Guide tab and the tour:**
  - The Guide tab is rebuilt in the 12.3 row format: ten sections, descriptions, switches on the right, keyboard reachable, and Bigger controls applied.
  - While locked, the gated `planner*` defaults are not written to profiles, and empty guide stores are dropped at logout.
  - New `PlannerIntro.lua`: a four-page first-time tour, shown once per account. "How the planner works" reopens it.
- **P4, words:**
  - German: du, dein and "Anleitung" throughout (G1–G365).
  - Russian: "гайд", the count forms and "Перенесено".
  - I-7 "Train" in all 8 languages, I-8 option names inside translations, and the other Locales findings.
- **The merge:**
  - Hearth and fly steps carry `to`, their landing place (PlannerRoute `Legs`). P2's 60 yd tick (F10, F36) now works without the bind zone's text.
  - `summary.source` is set by `ns.PlannerRoute` itself ("questie" or "log"), so P2's EndText (F18) and the "Zone goal needs Questie" line (F30) read it for every plan. Planner.lua sets `sourceWhy`, and `source` only when a route left it unset.
  - F9, candidate side:
    - The live context's `onQuest` counts a quest the game marks failed as not taken, so the plan takes it again from its giver.
    - Guide side: an accept step for a failed quest is not done while it stays in your log, and it reads "Accept: … (failed: abandon it and take it again)".
    - Abandoning a quest that was seen failed (`ns.PlannerWasFailed`, set by the context and by the guide's FailedCheck) does not skip it for the session.
  - F25: `ns.PlannerSkip(id, on, name)` keeps the quest's name with a skip. The name comes from the step's title, else the game's title, else `true`. The skip list shows it after the quest has left your log.
  - I13: `Following()` already tested `GuideOn()` before `GuideState()` (P1); the merge adds the test.
  - I19, Skin.lua copy box:
    - Its height grows with the font scale: the caption's measured height (two lines at most) above a field 18 × scale + 6 px tall, never under 74.
    - It has a real X close button. The caption is narrowed so it never runs under the X.
  - Translations: the three phrase files (23 + 57 + 71 phrases) were applied with add_tr and then removed. 23 English keys that nothing uses any more were removed from all 8 tables (list below).

## Rulings

1. **smoke.py conflicts.** The only conflicts were the three fenced regions, which P1, P2 and P3 each added before `try("Delayed calls"`. Both sides were kept (keepboth.py), and every block is closed: the fences are P1, P2, P3 and then the merge's, each begin with its end. P1's and P2's edits to older tests touch separate hunks; no old test was changed by two groups. P3 edited no old test.
2. **`.luacheckrc`.** P2's edit merged cleanly: the three old `BINDING_NAME_FANTASYGLASSUI_GUIDE*` globals are gone, and `FantasyGlassUI_GuideBinding` is replaced by `FantasyGlassUI_ExtraBinding`. `regen_rc.py` then reported no change ("removed: [] added: []").
3. **A phrase in two files.** "Install Questie to plan new quests; your quest log has none to plan" is in both polish-p1.json and polish-p2.json, with slightly different wording. P1's was applied first, and add_tr does not add a key twice, so P1's wording stands.
4. **German "Learn %s at %s".** P1's phrase file said "%s lernen bei %s". It is now "Lerne %s bei %s", P4's imperative form for the old "Train %s at %s" (M-21/M-29), so the trainer step reads like the other step verbs.
5. **summary.source** belongs to the route (PlannerRoute), not to Planner.lua's caller. Every plan carries it, including direct `ns.PlannerRoute` calls.
6. **F9: a failed quest is "not taken".** This is decided in the live context, not in `PlannerCandidates`, so every route step (anchor, accept, timed check) sees one consistent answer. Fake contexts in the tests are unchanged.
7. **The skip list's entries** are now a name string or `true`. Every reader checks only that the entry is set, so saved skips (`true`) still work. The old 13.3 test that asserted `== true` now asserts that the entry is set.
8. **Unused keys.** Only keys that became unused in this wave were removed. Each one was checked with `git grep -F` over the whole repository (FantasyGlassUI, FantasyGlassUI_Options, tests, site-src, docs, wiki, specs; the untracked `tests/.cache` excluded). The only hits were specs and comments, or longer strings that contain the key. Kept:
   - "Build": Companion.lua still uses it for a received build's name.
   - "1 hour 30": the Guide tab's break-length list in Bars.lua still uses it. P1 listed it as unused.
   - Nine keys were already unused before this wave. They are not this wave's to remove.
9. **Removed keys (23):**
   - "%s will plan with you: waiting for what they can do..."
   - "%s: %s to %s"
   - "Average level: %s"
   - "Copy this plan code and paste it on fantasyglassui.com/plan/"
   - "Couldn't plan the route; trying again after your next quest"
   - "Follow"
   - "Guide: refresh the route"
   - "How long can you play"
   - "Hubs on the map"
   - "Learn the flight path"
   - "Moved: you died twice here (back at level %d)"
   - "No more quests in %s at your level"
   - "Pick the best quest reward"
   - "Questie changed; planning from your quest log only."
   - "Race your best: level with your best"
   - the old Speed/Story/Safety paragraph
   - "Target your friend or group with them, or type /fgui guide duo <name>."
   - "Train"
   - "Train %s at %s"
   - the old "Used by /fgui guide plan with no number…" line
   - "Wait for %s here"
   - "You are not in %s: the line is in your chat box for its current channel."
   - "another hub"
10. **Placeholders.** All 8 tables have 3,661 keys each. The script compares the order and kind of every `%` conversion in the key and its translation, and finds 0 mismatches. The English key "Resource % on frames & nameplates" holds "% o", which is not a conversion; it is never formatted.
11. **lockaudit ran out of memory after the merge (killed, exit 137).** The merge of the four groups alone, with none of the merge's own work, does the same: 1023912 peaks at 2.7 GB, while 13f1764 was killed at about 6 GB.
    - The cause is in the audit's own frame model. It added an anchor to a frame's list on every `SetPoint`, with no limit. The rebuilt Guide tab and the measured panel lay their frames out again on every refresh, so the lists grew without end (4.5 GB of Lua before the combat pass).
    - The audit now keeps each anchor frame once. That is the same set of frames, so protection is unchanged; the result lists the same frames as at 1023912, with no protected call in combat (a few secure keys and raid marks are counted 3 times instead of 4 because the tests build them once less). Lua memory before the combat pass is now 3.0 GB, and the run completes.
    - The integration test opens the Guide tab without throwing the settings window away (no `O.frame = nil`), which saves about 7,000 handlers.

## Findings left, with reasons

- **P1:**
  - I3(c) travel memo: LearnOnWay changes `f.known` mid-plan, and the legs are shared.
  - M11: documentation only.
  - M18: planner events stay registered while locked. The handlers return at once, and the tests unlock by stub.
  - M20: a Sync change-cache risks stale registrations.
  - M21: thinning spots costs route quality.
- **P2:**
  - F20: step verbs come from route texts; prefixing them would double the verbs on written guides.
  - M12: "→" needs an in-game font check, and changing it changes the key.
  - M-2: the reviewer called it acceptable.
  - I11: real footer buttons were not added; there is a single action style instead.
- **P3:**
  - The All/On/Off filter belongs to FeaturesPage feature switches.
  - Separate sidebar entries per Guide sub-section would need Categories.lua.
  - M-14: "Reputation I want" must match its window's title.
- **P4:**
  - M-42: the prose "сборка талантов" lines are unambiguous, and re-gendering them is not worth the risk.
  - The Russian help search stays "помощник", not "гайд", so it is not taken for the quest guide (4 lines if wanted).
  - The German boss guide stays "Boss-Anleitung", as the review wrote it (2 lines if "Boss-Guide" was meant).
- **Merge:**
  - M-19 (missing_tr's patterns) is a tools change and was not made. missing_tr over all code files gives the same 321 heuristic lines as on base, and none of the new ones are shown to players ("waiting", "ended", "rule", "log" are internal ids).

## Check in the game before release

One list, from the four reports and the merge.

Keys and bindings:
- [ ] **Bind the three guide keys again.** The old tokens (`FANTASYGLASSUI_GUIDENEXT/SKIP/AGAIN`) are gone. The new ones are `FANTASYGLASSUI_EXTRA1`–`3`.
- [ ] While locked, the key bindings window shows "Fantasy Glass UI: extra 1/2/3". After the unlock, at the next PLAYER_LOGIN or straight after the unlock, it shows "Guide: next step / skip step / plan again", in every language.

Fonts and look:
- [ ] The "→" glyph in "Level %s → %s" and in "Planned: %s, level %s → %s" draws in the game's fonts (default, every lettering choice, koKR and zhCN). If it shows as a box, change the key in all 8 languages (P2's M12).
- [ ] **The Guide tab's row heights:** the measured heights after the first draw, at text sizes 70, 100 and 150 and with Bigger controls. Rows must not overlap or leave gaps. The layout runs again when the width changes.
- [ ] Guide tab contrast: the descriptions are `dim` at 13 (6.79:1 on the card). The followed guide's name is a lightened accent at 4.5:1 or better, and the keyboard focus ring is visible on every row.
- [ ] **The explainer's look:**
  - The tour's four pages in the settings look, with the page dots, Skip, Back, Next/Done and the X.
  - It sits over the settings window the first time the Guide tab opens after an unlock, and does not cover the controls in a way that confuses.
  - With reading aloud on, each page is read. Left/Right, Enter/Space and Esc work, and a fight closes it.
- [ ] The panel: its measured layout at every font scale. Secondary lines wrap to two, the tooltip shows the whole text, Plan again is sized and cut, and the talent button is centred. Its default place is TOPRIGHT −290, −300 and it grows down; a dragged place stays put.
- [ ] The arrow: stacked from the top, with its band and its dim label, at TOP 0, −345, overlapping nothing.
- [ ] List rows at every font scale, and the note wrapping to two lines above the list.
- [ ] List colours from the theme and the colour-vision palette.
- [ ] Hub marks: the 24 px hit area, the alpha floor 0.55, and the tier digit.
- [ ] The copy box: its height at text sizes 70/100/150 (a two-line caption never overlaps the field), and the X closes it.
- [ ] The duo ask: its caption sound, reading aloud, the countdown, closing at 0, and the keyboard.
- [ ] The best-reward mark: the overlay sits on the reward button, and the chat line names the item.

Flows:
- [ ] A hearth step ticks within 60 yd of where you land, and a fly step at its landing point. This needs the new `to`: test it on a fresh plan.
- [ ] A timed or escort quest that fails:
  - The panel says to abandon it.
  - After abandoning, the plan takes it again from its giver; it is not left out for the session.
- [ ] The skip list shows a quest's name after the quest has left your log.
- [ ] Questie loading slowly: the "still loading" line, then the quest-log plan after 30 s.
- [ ] Landing from a taxi or reviving runs the queued replan.
- [ ] The end of a route plans again (at most once a minute), and an empty plan does not loop.
- [ ] Stored data while locked: a fresh locked character's SavedVariables hold no `guides`, `guideState`, `planner` or gated `planner*` keys after a logout.
