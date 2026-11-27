# 13.0.1: mob names on enemy nameplates

Branch `plate-names` (from `quest-planner`), worktree `/home/claude/fgui-plates`.

The player asked for "mob names to appear when near them along with the hp bar". In their screenshot
the enemy plate shows the bar, the health "71", the level "3" at the left and the mana "74" at the
right, but no name.

## Cause

I checked this against the Forever interface code (wow-ui-source `forever`, 1.60.1 (71037), the same
build as `tests/forever_api.json.gz`).

1. **Our own bar covers the game's name.** In Forever's Modern and Block nameplate styles
   (`nameplateStyle`), the game anchors `uf.name` *inside* the health bar, on the left
   (`NAME_ANCHOR_STYLES.InsideHealthBar` in `Blizzard_NamePlateUnitFrame.lua` `UpdateAnchors`).
   Since 11.16, `ns.PlateOwnBar` puts our own opaque bar over the game's bar, one frame level higher.
   So the name is drawn under our bar.
   - The zoomed screenshot shows this: the name is faintly visible through the dark bar, at its left.
   - This also explains where the level is. `PlateLevel` anchored the level to `uf.name`'s LEFT,
     and that point is at the bar's left edge, halfway up the bar.
2. **The game hides the name anyway for many players.** The game's `ShouldShowName`
   (`CompactUnitFrame.lua`) shows an NPC's name only when `UnitShouldDisplayName` allows it. That
   follows the "NPC Names" setting (`UnitNameNPC`, `UnitNameHostleNPC`, ...). Forever's default for
   it (`Camelot/NameplatesOverrides.lua`) is "None" in the Classic experience preset. With that
   setting the name only shows while you target the unit (`UnitNameFocused`), unless
   `nameplateForceShowUnitName` is set.
3. **Our code did not cause it.** `uf.name:SetAlpha` was 1, because `nameShow` defaults to true. The
   "lift" offset only applies when the name has one anchor point, and the inside-bar name has two, so
   it did nothing here.

## Fix

- **Our own name on every enemy or neutral plate.** "Enemy or neutral" means `UnitCanAttack` is true,
  or `UnitReaction` is 4 or less. The name comes from `UnitName` and sits on its own small frame on
  the plate.
  - It is centred above the bar and exactly as wide as the bar, so a long name is cut short instead
    of running into the level or the quest marks.
  - It sits 3 px above the bar, plus the width of the "Outline round my target" ring, so the ring
    never covers it.
  - It uses the designer's `nameSize` and is shown whenever the plate is visible.
  - It updates on `UNIT_NAME_UPDATE`.
- **The game's own name is faded out (alpha 0) on those plates,** so it never shows twice (in the
  Thin style it would sit above the bar).
- **Friendly plates keep the game's own name as before.** That includes the name-only plates of
  friendly players.
- **No CVar is needed or touched.** Our name does not depend on the game's NPC-names setting, so no
  hint to the player was needed either.
- **"Names on nameplates" (`nameShow`) still works.** When it is off, our name is hidden and the game's
  name stays faded out. Changing it in the designer applies at once (`ApplyPlateDesign`), and so do
  changes to the name size.
- **Secret names are never compared.** If `ns:IsSecret(name)` is true, the name is passed straight to
  `SetText`, which is allowed. Otherwise only `type(name) == "string"` is checked. Nothing measures
  the text.
- **Layout, so nothing overlaps:**
  - **Level:** on enemy plates it is now anchored to the bar, just left of it and halfway up
    (`RIGHT` to the bar's `LEFT`, -3). It is no longer anchored to the game's name, so it stays at
    the left in every game nameplate style. On friendly plates it stays beside the game's name.
    Its font now also follows a change of name size.
  - **Quest marks:** both move out past the level, using `ns.PlateLevelSlot()`, which leaves room for
    "60" or "??" at the name size. The order from the bar outwards is level, then the "!"
    (QuestMarks.lua), then the count and icon (Nameplates.lua `PlateQuest`). Both marks are
    re-placed each time they are shown, so a name-size change catches up. In the screenshot these
    three sat on top of one another.
  - **Our debuff row** moves up, using `ns.PlateAuraLift()`, so it sits above the name. With the
    default size 10, that is 17 px instead of 16.
  - **The cast bar** stays below the bar, so it is nowhere near the name.
- **Nothing protected is touched.** There is no ReloadUI and no protected call. Only our own frames
  and font strings are created and anchored. On the game's frames we only call `SetAlpha` on its
  name, as the code already did, and add our own level text.

Files: `FantasyGlassUI/Nameplates.lua`, `FantasyGlassUI/QuestMarks.lua`, `tests/smoke.py`,
`RELEASE.md` and `CHANGELOG.md` (a new `## 13.0.1` section with **Fixed** and one line, in the same
form as earlier patch releases such as 12.4.1).

**No new words.** The fix adds no visible text: the name is the game's own, and the switch is the
existing "Names on nameplates". So there is no `specs/plans/phrases/plates-1301.json` and no
`add_tr.py` run.

## Tests (smoke.py, next to "Nameplates: quest mobs counted from their objectives")

Each of these failed before the fix ("no name of our own on the plate"), in both the readable and the
hidden pass, and passes after it:

- **"Nameplates 13.0.1: the plate name shows the unit's name over the bar".** It checks that:
  - an enemy plate shows `UnitName`;
  - the name is at the designer's size;
  - the name is anchored `BOTTOM*` to the bar's `TOP*` with a gap above 0;
  - the game's name is at alpha 0;
  - once the same plate is reused for a friendly unit, our name is hidden and the game's name is back
    at alpha 1.
- **"Nameplates 13.0.1: "Names on nameplates" off hides the plate name".** It checks that with
  `nameShow = false` (through `ApplyPlateDesign`, and again when the plate is attached) no name is
  shown and the game's name stays hidden, and that the name comes back when the switch is on again.
- **"Nameplates 13.0.1: a hidden (secret) plate name is shown without being looked at".** It uses a
  secret value that raises an error on any arithmetic, concatenation, length or indexing, and checks
  that the very same value is handed to `SetText` and that no error is logged.

## Checks

These were run one at a time:

- `luacheck .` gave 0 warnings and 0 errors in 148 files.
- The full smoke run (`cd FantasyGlassUI && python3 ../tests/smoke.py`) gave `errors: no errors` in both
  the readable and the SECRET pass, both times (scratchpad `plates/smoke1.txt` and `plates/smoke2.txt`).
- `tests/forever_audit.py` passed: "Everything the add-on uses is in Forever". `UnitName`,
  `UnitReaction` and `UNIT_NAME_UPDATE` are all in the dump.
- `tests/secretaudit.py`: "0 lines compared a hidden value".
- `tests/lockaudit.py`: no protected calls in combat (only its usual list of our protected frames).

## What to check in game

1. **Modern or Block style** (Options > Nameplates > Style), next to a hostile mob such as a kobold
   in Elwynn: the name is white, centred above the red bar, with the level just left of the bar. No
   faint name shows inside the bar.
2. **Thin style:** there is only one name above the bar, not two.
3. **Classic experience preset with "NPC Names: None":** enemy names still show without targeting.
4. **A neutral (yellow) mob,** for example a boar: the name shows.
5. **A friendly NPC or player:** the game's own name, as before.
6. **A quest mob:** from the bar outwards, the level, the "!" and the count with its icon, with none
   overlapping.
7. **Bars and frames > Nameplates:**
   - untick "Names on nameplates": the enemy names disappear at once and come back when ticked;
   - move "Name size": the name, the level and the gap all follow.
8. **"Outline round my target" set to 3 or more:** the ring does not cover the target's name.
9. **A caster mob that has your debuffs on it:** the debuff icons sit above the name, and the cast
   bar and its text below the bar.
10. **In a fight:** names stay on the plates (hidden names are drawn by the game), and no Lua errors
    or blocked-action messages appear.
11. **With plate casts and debuffs off,** on a client that keeps the game's own nameplate debuffs:
    check whether the game's debuff row (in the Modern style it sits just above the bar) touches our
    name. We may not move the game's frames, so if it does, that is a follow-up.

## Concerns / notes

- The TOC still says `## Version: 13.0.0`. I left the version bump to the release step.
- Running only the nameplate tests in a cut-down copy of smoke.py (my own quick loop) shows "Quest
  marks on nameplates" failing, at baseline too. Both modules write `ns.plateQuestTest`. The full
  run is clean.
