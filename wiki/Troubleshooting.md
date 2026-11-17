# Troubleshooting

## Something looks wrong or an error appears
1. Type `/fgui check` for a report on what is running.
2. Open `/fgui` and press **Report a Problem**: it gathers what is needed into text you can copy.
3. [Open an issue](../../../issues/new/choose) and paste it in.

## I can't get into the options / the screen is broken
`/fgui safe` reloads with every feature off. Fix what you need in `/fgui`, then `/fgui safe` again to leave safe mode.

## I want my old settings back
`/fgui backup` lists the backups made before each update and once a day. `/fgui backup restore daily` (or `update`) puts one back and reloads; what you had is kept as "before the last restore".

## I changed one setting and want it undone
`/fgui history` lists what you changed in this profile and when; click a change to undo it.

## Panels won't move during a fight
The game does not let any add-on move or resize frames in combat. Wait for the fight to end.

## Buffs look different in combat
On WoW Forever, buffs and debuffs are hidden from add-ons during combat, so the game's own buff frames are restyled and used instead.

## "Interface action failed"
Type `/fgui blocked` and add what it says to an issue.

## A new feature doesn't seem to work
`/fgui check new` tries each feature added since 11.6 and says what works, what is switched off, and what needs a place or a moment.
