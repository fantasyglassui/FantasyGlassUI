# Player tooltips

New in 11.10.0. Every line of a player's tooltip is your choice. The switches are in **Chat and people › Player tooltips** in `/fgui`. Every switch works at once, with no reload, and presets never change them.

## The game's own lines

Each of these is on at first. Turn one off to hide that line.

| Switch | The line it controls |
|---|---|
| Title in the name | Their title in front of their name ("Champion of the Frozen Wastes" and the like) |
| Realm in the name | The realm after the name of a player from another realm |
| Guild | The line with their guild's name |
| Level, race and class | The "Level 60 Human" line, and the class line when the game puts it on a line of its own |
| Faction | The line saying Alliance or Horde |
| PvP | The line saying they are flagged for PvP |
| Health bar | The health bar under the tooltip |

Tags like `<Away>` and `<Busy>` stay on the name whatever you choose.

## The add-on's lines

| Switch | Starts | What it adds |
|---|---|---|
| Guild rank | on | Their rank, under the guild's name |
| Who they target | on | "Targeting: YOU" when it is you, or the name of their target |
| Role in your group | on | Tank, healer or damage, as chosen in your group. Only while you are in a group |
| Friend or guild mate | on | "Your friend" or "In your guild" under players you know |
| Health in numbers | off | Their health as 12,345 / 20,000 (62%) |

Your own note on a player has its own switch, **Notes on players** (Chat and people section). Add one with `/fgui note <text>` while they are targeted.

## Their look

All tooltips wear your theme's panel:
- **Glass:** the glass sheen and bright top edge.
- **Fantasy:** leather grain with small gold corners.
- **Celestial:** a night sky with small star points.

An item's quality colors the edge. The health bar under a player's tooltip takes their class color; under a creature's, green, yellow or red for friendly, neutral or hostile.

## During fights

**Hide during fights** (off at first) puts player tooltips away while you are fighting, so they don't cover the action. Hold **Shift** to see one anyway.

## Good to know

- **Players only:** these switches change player tooltips. Creature and item tooltips are not affected.
- **The master switch:** with **Player tooltips: choose the lines** off, the game's lines stay exactly as the game writes them.
- **Hidden information:** anything the game keeps hidden from add-ons is left exactly as it is, so a tooltip may sometimes keep a line you have hidden. That is the game, not a fault.
- **Other tooltip switches:** **Tooltips**, **Item counts in tooltips**, **Item level & price in tooltips** and **Item & spell IDs in tooltips** are listed beside these in `/fgui`. **Tooltips follow the mouse** is in the options too.
