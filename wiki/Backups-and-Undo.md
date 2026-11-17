# Backups and undo

Your settings are hard to lose. These are all the ways back.

## Undo the last panel change

`/fgui undo` puts back the last panel move, nudge, resize or reset.

## Undo one setting

`/fgui history` lists what you changed in this profile and when. Click a change to undo it.

## Backups

Backups of all your settings are made by themselves, at three moments:

| Backup | Made |
|---|---|
| Before the last update | each time the add-on updates |
| Start of the last day you played | at your first login each day |
| Before the last reset | just before `/fgui reset` |

There is also **Before the last restore**, kept when you restore one of the others.

- **See them:** `/fgui backup` lists them, with when each was made. Click one to see how to put it back.
- **Restore one:** type `/fgui backup restore daily`, `update`, `reset` or `restore`. The interface reloads.

Restoring is typed on purpose, so it never happens by a stray click. What you had just before is kept as "Before the last restore", so a restore can be undone too.

## Start a profile over

`/fgui reset` puts every setting of the current profile back to how it came, then reloads.

- **It asks first:** type it twice within ten seconds.
- **It keeps a backup:** your settings are saved as "Before the last reset" first.
- **Changed your mind?** `/fgui backup restore reset` brings them back.

Your other profiles are not touched.

## Safe mode

If something is broken badly enough that you can't reach the options, type `/fgui safe`. It reloads with every feature off. Fix what you need in `/fgui`, then type `/fgui safe` again to leave safe mode.

## Profiles and sharing

- **Profiles tab** in `/fgui`:
  - **Profiles:** one per character, or shared between characters.
  - **Templates:** Tank, Healer and Damage, to start a profile from.
  - **Copy my whole UI:** one string with your profile, layout, theme, bars and rules.
- **Before taking a shared string:** `/fgui sharepreview` shows what it holds.
- **A new character** gets its own copy of your main's setup, fitted to its class. `/fgui main` chooses your main.
