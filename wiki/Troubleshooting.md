# Troubleshooting

## Something looks wrong or an error appears
1. Type `/fgui check` for a report on what is running.
2. Open `/fgui` and press **Report a problem**: it gathers what is needed into text you can copy.
3. [Open an issue](../../../issues/new/choose) and paste it in.

## I can't get into the options / the screen is broken
`/fgui safe` reloads with every feature off. Fix what you need in `/fgui`, then `/fgui safe` again to leave safe mode.

## I want my old settings back
`/fgui backup` lists the backups made before each update, once a day and before a reset. `/fgui backup restore daily` (or `update`, or `reset`) puts one back and reloads; what you had is kept as "Before the last restore". See [Backups and Undo](Backups-and-Undo).

## I changed one setting and want it undone
`/fgui history` lists what you changed in this profile and when; click a change to undo it.

## Panels won't move during a fight
The game does not let any add-on move or resize frames in combat. Wait for the fight to end. Equip best, Sort bags and talent builds asked for during a fight happen by themselves when it ends.

## Sending to another player does nothing in a dungeon
Inside dungeons and raids, WoW Forever does not let add-ons send messages to other players. Sending a layout, a theme or a talent build, and the add-on's own whisper box, say so there; try again outside. The pull timer still starts the game's own countdown for the group.

## A command did nothing / I don't remember a command
`/fgui help` lists every command in a window you can search. If you mistype one, the add-on suggests the nearest.

## A player's tooltip is missing a line
Check the **Player tooltips** switches in `/fgui` ([Player Tooltips](Player-Tooltips)). The game also keeps some things hidden from add-ons, and those lines are left as the game writes them.

## Buffs look different in combat
On WoW Forever, buffs and debuffs are hidden from add-ons during combat, so the game's own buff frames are restyled and used instead.

## "Interface action failed"
Type `/fgui blocked` and add what it says to an issue.

## A new feature doesn't seem to work
`/fgui check new` tries each feature added since 11.6 and says what works, what is switched off, and what needs a place or a moment.
