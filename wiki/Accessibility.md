# Accessibility

New in 12.1, with more in 12.2. Everything that makes the game easier to see, hear, follow or use
has a category of its own in `/fgui`: **Accessibility** (`/fgui access` opens it). The setup has a
**Comfort** step with the most used ones, so a new player can set them before anything else. The
website lists it all [need by need](https://fantasyglassui.com/accessibility/).

## Seeing

- **Color-blind safe colors**, for your kind of color vision:
  - **Red-green** (red-weak and green-weak, the most common): good is blue, bad is orange.
  - **Blue-yellow** (blue-weak): good is teal, caution pink, bad red.
  - **No color**: brightness alone, with bad the brightest, and every mark switched on.
  With any of them, debuffs get a letter for their type, item quality gets dots (one for
  uncommon up to four for legendary) in bags, on your gear and on loot rolls, raid members you can
  dispel get a "!", and threat on nameplates gets a mark: "!" when it is slipping, "!!" when it
  is lost (for a tank) or on you (for anyone else).
- **Readable lettering**: **Readable** (Atkinson Hyperlegible, made for low vision) or
  **Dyslexia-friendly** (OpenDyslexic, with weighted letters that are hard to flip). Western
  European letters only; other languages keep the game's fonts.
- **Outline round letters**: thin or thick, on every letter of the add-on.
- **Dark band behind messages** in the middle of the screen.
- **Outline round my target**: a thick ring, 1 to 8 pixels, round your target's nameplate.
- **High contrast**: three themes of pure black panels, one in each family: glass (white rims),
  fantasy (gold) and celestial (a black sky with white stars). **Use the high-contrast theme** (or
  `/fgui contrast`) picks the one for the family you use.
- **Text size** (100, 120 or 140%, or any size from 70 to 150 with `/fgui textsize`), and the
  **interface size**.
- **Ring round the mouse pointer**, so it is easy to find in a fight.

## Hearing

- **Captions for sounds**: a line on screen, with a mark for its kind, for whatever gets your
  attention with a sound: a ready check, a whisper, a dungeon or battleground queue that is ready,
  a group invite, a duel, a resurrection or summon, a boss emote, a raid warning, a roll on loot,
  the aggro warning and your own alerts that play a sound. Up to four at once, the newest at the
  foot; click one to put it away; move them in move mode.
- **Spoken alerts** (in Combat › Alerts and warnings): the game's own voice says ready checks,
  whispers, missing buffs, loss of control and your own alerts.

## Flashing and motion

- **Reduce motion**: no fades, pulses, gliding bars or camera drift.
- **Still sky**: the celestial themes keep their stars but hold still: no twinkling, no breathing
  light, no shooting stars, while everything else moves as usual.
- **Safe flashing**: nothing flashes more than three times a second, flashes are gentle, pulsing
  warnings hold still, and the game's red low-health flash at the screen's edge is off where this
  client allows it (switching it off puts back what the game had).

## Focus and calm

- **Calm mode**: one notification at a time, held for fifteen seconds and put away with a click;
  messages in the middle of the screen stay up longer; captions wait their turn.
- **Quieter red error line**: drops the lines that repeat constantly in a fight.
- **Wait before a tooltip shows**: up to two seconds of rest before a tooltip appears, so sweeping
  the mouse across the screen does not throw one up after another.

## Reading aloud

- **Read talk and quests aloud**: what an NPC says (and the choices it offers), a quest's text when
  you are offered it, its progress and its reward, and a book or letter are read as soon as they
  open. Closing the window stops the reading.
- **Read what I point at**: when the mouse rests on something for half a second, its tooltip is read
  aloud, once. (The game's own screen narrator works only before you log in.)

A key (Key Bindings, AddOns, Fantasy Glass UI: "Read aloud"), the **Read aloud now** button, or
`/fgui read` says what is under the mouse with the game's text-to-speech voice: the tooltip if one
is showing, otherwise the quest you are reading, otherwise the last whisper. `/fgui read tooltip`,
`quest` or `whisper` picks one.

## Hands and keys

- **Bigger controls in the settings**: larger switches and lines, and "click twice" buttons wait
  ten seconds for the second click.
- **The game's windows by keyboard**: with an NPC's talk, a quest, a vendor, the mailbox, loot, a
  trainer, a flight master, the bank or a question box open, Tab or Down goes to the next thing to
  press, Shift+Tab or Up to the one before, and Enter or Space presses it. A ring shows where you
  are; **Say each choice as I reach it** says each one aloud, with where it is in the list
  ("Accept, 1 of 2"). Never while you type, and not in a fight (the game keeps the keys then).
- **Keys for one hand**: **Keys for the left hand only** binds moving to W, A, S and D, strafing to
  Q and E, jumping to Space, auto-run to R, the first twelve action buttons to 1 to 5 and G, T, Z,
  X, C, V and B, Tab to target and F to interact. **Keys for the number pad only** puts moving and
  turning on 8, 5, 4 and 6, strafing on 7 and 9, jumping on 0, the first six action buttons on 1,
  2, 3, /, * and -, targeting on + and interacting on the decimal point. The keys a set takes are
  noted first, and **Put my keys back** (or `/fgui keys back`) returns every one as it was. Not in a
  fight.
- **Move through the settings with the keyboard** (off until chosen, as it takes those keys while
  the window is open): Tab or the arrow keys go from setting to setting, Space or Enter switches
  one, Left and Right move a slider or step a choice, Page Up and Page Down change section. In a
  fight every key goes to the game.

## Share

`/fgui access copy` (or **Copy my accessibility settings**) gives all of these as one line of
text, to keep or give to someone. `/fgui access paste`, the **Paste accessibility settings**
button, or **Paste shared settings** in the setup's Comfort step takes one and sets everything in
it at once. Only these settings travel, nothing else of your profile.
