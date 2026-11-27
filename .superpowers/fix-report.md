# 13.0 final-review fixes (release-13-fix, from quest-planner @ 2ec4de2)

Every finding in .superpowers/sdd/2026-11-26-release-13/final-review.md, with its outcome and its test.
New smoke tests sit in tests/smoke.py between "-- release 13 fix tests: begin" and "-- release 13 fix tests: end".
Each was seen failing first: the new smoke.py run against the unchanged 2ec4de2 Lua printed six CALL ERRORs, one
for each new test plus the changed "folders: a folder that will not load" test. The site test failed with
"108 broken" before the build_site.py fix. Nothing touches MinimapButtons.lua and no minimap code was added.

## Critical

**F13-C1: fixed.**
- `ns:GuideSave` refuses any name that starts with "\1" and returns "Give the guide a name of its own."
- Route editor, on the plan or a trip:
  - Save becomes **Save as guide**. It saves a new guide named the way the planner's Save as guide names one:
    "Planned route", then "(2)" and so on, or the trip's title for a trip.
  - The message says `Saved as guide "<name>": n steps.` The route being followed is not changed.
  - Save and follow and As text are hidden, and their clicks do nothing.
  - The title shows "Plan my route" or "Gold trip: <title>", never the hidden name.
- Of the two options in the ruling, this is the simpler and safer one. Writing back into st.plan / st.trip would have
  to re-index `ticked` and `at`, and a replan can overwrite it.
- `GuideNames` skips "\1" names and records that are not a table with steps. `GuideList` skips a nil guide.
- `ns.GuideForgetHidden()` runs at PLAYER_LOGIN and deletes every "\1…" key from `root.guides`. It runs at each
  login, since it is idempotent and costs one pass; no flag was added to the saved variables.
- Test: smoke "13.0 fix C1: the route editor on the plan or a trip saves a guide of its own, and hidden names heal".
  It covers GuideSave refusals, Save on the plan (no "\1" key, the "Planned route" copy, the plan untouched, no plain
  "Saved:"), a second copy "(2)", a trip, and old records (GuideNames, GuideList opening, the login clean-up).

**F13-C2: fixed.**
- build_site.py `quote_text` writes `&quot;` only for quotes outside a phrase's own tags.
- The site is rebuilt, and no `href=&quot;` / `src=&quot;` remains in docs/.
- Test: tests/test_site.py::test_site_links_keep_their_quotes. It scans every .html and .xml file in docs/.

## Important

**F13-I1: fixed.**
- `LoadFolder` never calls EnableAddOn.
- A quiet load (the auction house, the login, a duo ask, catch-up) returns false silently when the folder is
  disabled, missing or broken.
- A load the player asked for prints one line:
  - for a disabled folder, the new `disabled` text: `The planner folder / The gold folder is switched off: tick
    "Fantasy Glass UI - planner/gold" in the AddOns list, then try again.`;
  - for a missing one, the existing line naming the folder.
- The old smoke test "disabled: switched on and loaded" now asserts the opposite.
- Test: smoke "13.0 fix I1: an automatic load never switches a folder on, and says nothing".

**F13-I2: fixed.**
- New feature switch `goldAuctionPanel`, "Gold ideas at the auction house":
  - on by default, and takes effect at once;
  - in the settings window under Bags and items › Gold and farming, beside Farming sessions;
  - on the Features tab next to Auction house helper.
- When it is off, the auction house loads nothing and shows no panel, during and after a fight.
- `ns:GoldAuctionApplySwitch` hides the panel when the switch goes off. When it goes on with the auction house open,
  it shows the panel.
- Rewording that says the gold folder loads when you use it or open the auction house:
  - RELEASE.md, CHANGELOG.md and FantasyGlassUI/CHANGELOG.md;
  - FantasyGlassUI/README.md;
  - the 13.0 what's-new line in the add-on;
  - the site: the Guide and Gold lede, the "At the auction house" card, and the switch's own description on the
    Features page.
- Test: smoke "13.0 fix I2: Gold ideas at the auction house, a switch".
- Not done: an X on the panel. The switch covers the ruling.

**F13-I3: fixed.**
- No generator was in the repo or its history. git log shows the 12.4.x commits hand-editing features.json to mirror
  FeatureList.lua. I added site-src/tools/make_features.py, which reads the add-on itself:
  - the Features tab (groups, SECTIONS, DESC);
  - the Guide tab's and the planner window's switches, as a new "Quest guides" section;
  - `/fgui help`'s list (ns.helpLines).
- Check: it reproduces the 260 existing entries of the 12.4.1 file exactly.
- Result: 293 switches in 12 sections (260 + Gold ideas at the auction house + 32 guide/planner switches), and
  137 commands, the same as Core.lua and DESCRIPTION.md.
- The Features page has a blurb line for the new section.
- Home now says 293 switches and 137 commands.
- docs/og.png and og.jpg were re-shot as the ruling describes: Playwright, docs/ served locally, 1200×630, dark
  colour scheme, reduced motion, `body>header` and `a.skip` removed. og.jpg is saved at quality 88.
  The script is at <scratchpad>/fix13/og_shot.py.
- Test: none new. Counts are checked by eye on docs/index.html and og.png; sitecheck and sitebrowser pass.

**F13-I4: fixed.**
- Main add-on (PlannerRecorders.lua):
  - `ns.PlannerDuoKnown(sender)` is true for: a group or raid member (by unit names); a friend or guildmate
    (`ns:IsKnownPerson` by name); a Battle.net friend playing that character (`C_BattleNet.GetFriendAccountInfo`).
  - `ns.PlannerDuoAskAllowed(sender, peek)` adds one ask per sender per 300 s.
  - Every value is checked with ns:IsSecret.
- The main add-on's listener only peeks before it loads the folder. The folder's `Receive` (ASK) checks and counts.
- Anyone else, and any repeat within 5 minutes, is dropped silently, with not even a NO.
- The "Let friends ask to plan with you" switch stays. Its description now says who can ask, in 9 languages.
- The duo how-to on the site and RELEASE/CHANGELOG say the same.
- The harness puts in a permissive stand-in for the older duo tests, whose senders are not friends. The new test
  uses the real check.
- Test: smoke "13.0 fix I4 and M4: only friends, guildmates and your group may ask, once in 5 minutes".

**F13-I5: done as ruled. The list is kept; the player decides tonight.**
- The paragraph is one phrase in site_tr.py, marked with a comment. It is `EMAIL_LIST` in
  site-src/pages/changelog/body.py.
- It now says: "Your address is kept only in our mailbox, it is used only to send you a note when a big update comes
  out, and writing again stops it."
- To drop the list, set `EMAIL_LIST = ''`, delete that one site_tr.py entry, then run keys_all.py, make_i18n.py and
  build_site.py.
- Test: none of its own. The link works now through C2's test, and sitecheck passes.

## Minor

- **M1: fixed.** The two "(where guides are unlocked)" are gone from FantasyGlassUI/README.md.
- **M2: fixed.** release.yml says "five add-on folders".
- **M3: fixed.** `/fgui check` prints `following "Plan my route"` or `following "trip: <title>"`.
  Test: smoke "13.0 fix M3".
- **M4: fixed.** The main listener ignores asks while quest guides are off, so nothing loads.
  Test: part of the I4/M4 smoke test.
- **M5: fixed.** docs/404.html uses /fonts/ with @font-face. No Google Fonts request remains.
- **M6: fixed.** "puts your frames in a layout like that interface's", in all 9 languages, in three phrases:
  Features compare, the Get started setup step, and Home's "Coming from ElvUI?". wiki/Getting-Started.md was
  reworded the same way.
- **M7: fixed.** /plan/ is titled "Your route · Fantasy Glass UI", with "Your route" in its 9-language word list.
  sitebrowser's language check accepts it.
- **M8: fixed.** "**Gold an hour**, **Ease** and **Safety** sliders, or the **Most gold**, **Easy money** and
  **Safe** presets" is in RELEASE.md and both CHANGELOGs.
- **M9: fixed.** The two unlock strings are removed from site-src/words/words.py, words_more.py and words_zh.py.
- **M10: reworded, not changed in behaviour.** The PlannerIntro.lua header and the Bars.lua comment now say the
  tour comes with the planner window, or with the Guide tab only once the folder is loaded. Making the tab load the
  folder would add another automatic load, against I1's spirit. The site's text already says "the first time" you
  open the planner, which is true.

## Translations
- Add-on: specs/plans/phrases/release-13-fix.json (7 phrases), applied with add_tr.py. German uses du.
- Site: site_tr.py:
  - 8 changed entries: lede, auction house card, duo requirement, 3 compare lines, the email list;
  - 1 new entry: the Quest guides section blurb.
- Then keys_all.py and make_i18n.py: "site phrases without a translation: []".

## Concerns for the controller
- FantasyGlassUI/DESCRIPTION.md (the CurseForge text, Track C) still says "257 switches". The add-on's Features tab
  now has 261, and the site counts 293 with the guide and planner switches. Left alone because the player approves
  that text separately.
- The old English keys of the reworded add-on phrases (the what's-new line and the duo switch description) stay in
  Locales.lua, unused.

## Checks (on the final commits)
- luacheck: 0 warnings / 0 errors in 147 files.
- smoke, run twice (output in the scratchpad, smoke-final1.txt and smoke-final2.txt): `errors: no errors` in both the readable and SECRET passes of both runs; no in-game error messages.
- forever_audit: "Everything the add-on uses is in Forever." secretaudit: "0 lines compared a hidden value". (Both run before the last commit, which changed only one German translation value.)
- make_i18n: no phrase without a translation; build_site: 126 pages; docs/ committed.
- sitecheck: 126 pages in 9 languages; plan page published; feed of 20 releases. sitebrowser: 194 pages checked. plan_reader_check: 20 codes OK.
- pytest -k "site or plan or seams or folder or recorders or toc": 18 passed.
