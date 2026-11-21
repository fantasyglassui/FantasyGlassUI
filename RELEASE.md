## 12.1.0

**New: accessibility**
- Accessibility is a category of its own in `/fgui`, with seven sections: Seeing, Hearing,
  Flashing and motion, Focus and calm, Reading aloud, Hands and keys, and Share. The setup has a
  Comfort step for the same things.
- Color vision for each kind: red-green (blue and orange), blue-yellow (teal, pink and red), or no
  color at all, where brightness and marks carry the meaning. With any of them, threat on
  nameplates gets a mark ("!" when it is slipping, "!!" when it is lost or on you), as debuffs get
  a letter and item quality gets dots.
- Outline round my target: a thick ring, 1 to 8 pixels, round your target's nameplate.
- Captions for sounds: a line on screen, with a mark for its kind, for ready checks, whispers,
  dungeon and battleground queues, group invites, duels, resurrections, summons, boss emotes,
  raid warnings, loot rolls, the aggro warning and your own alerts that play a sound. Movable in
  move mode; click one to put it away.
- Read aloud: a key binding (and `/fgui read`) that says the tooltip under the mouse, the quest you
  are reading, or the last whisper, with the game's own voice.
- Two lettering styles made to be read: Readable (Atkinson Hyperlegible, made for low vision) and
  Dyslexia-friendly (OpenDyslexic). An outline round letters (thin or thick) and a dark band
  behind messages in the middle of the screen.
- Safe flashing: nothing flashes more than three times a second, flashes are gentle, pulsing
  warnings hold still, and the game's red low-health flash is off where this client allows it.
- Calm mode: one notification at a time, held for fifteen seconds and put away with a click;
  messages in the middle of the screen stay up longer; captions wait their turn.
- Bigger controls in the settings, and "click twice" buttons wait ten seconds for the second click.
- Move through the settings with the keyboard (off until chosen): Tab and the arrow keys go from
  setting to setting, Space and Enter use one, Left and Right move a slider or step a choice, Page
  Up and Page Down change section.
- Share: `/fgui access copy` gives all your accessibility settings as one line of text, and
  `/fgui access paste` (or the setup's Comfort step) takes one back.

**Changed**
- The ring round the mouse pointer and the quieter red error line are in Accessibility now.
