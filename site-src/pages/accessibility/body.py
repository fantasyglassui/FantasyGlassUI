# The Accessibility page's body (W3 updates it): what Fantasy Glass UI does, need by need. The text is in English
# in every language for now. The build calls body(ctx); see site-src/PAGES.md.
import html

NEEDS = [
    ("seeing-color", "Color vision", "For red-green or blue-yellow color blindness, or seeing no color at all.", [
        ("Colors for your kind of color vision", "Red-green (blue and orange), blue-yellow (teal, pink and red), or no color at all, where brightness and marks carry the meaning."),
        ("Marks as well as colors", "Debuffs get a letter, item quality gets dots, and threat on nameplates gets a mark (\"!\" when it is slipping, \"!!\" when it is lost)."),
    ]),
    ("seeing-low", "Low vision", "For seeing the screen more easily.", [
        ("High-contrast themes", "Pure black panels, white lettering and the strongest rims, in all three families: glass, fantasy and celestial. One button picks the one for the family you use."),
        ("Lettering made to be read", "Readable (Atkinson Hyperlegible, made for low vision) and Dyslexia-friendly (OpenDyslexic). A thicker outline round every letter, and a dark band behind messages in the middle of the screen."),
        ("Bigger text and a bigger interface", "Text size and interface scale of their own, separate from the game's."),
        ("A ring round your target", "A thick outline, 1 to 8 pixels, round your target's nameplate, so it stands out in a crowd. A ring round the mouse pointer too."),
    ]),
    ("reading", "Reading aloud", "For blind and low-vision players, and for anyone who would rather listen. In the game's own voice.", [
        ("Talk and quests read as they open", "What an NPC says and the choices it offers, a quest's text, its progress and its reward, and books and letters. The reading stops when you close the window."),
        ("What you point at", "When the mouse rests on something, its tooltip is read aloud. (The game's own screen narrator only works before you log in.)"),
        ("A key that reads", "One key reads the tooltip under the mouse, the quest you are reading, or the last whisper."),
        ("Spoken alerts", "Ready checks, whispers, missing buffs, loss of control and your own alerts, said aloud."),
    ]),
    ("hearing", "Hearing", "For deaf and hard-of-hearing players, and for playing with the sound off.", [
        ("Captions for sounds", "A line on screen, with a mark for its kind, for ready checks, whispers, queues, invites, duels, resurrections, summons, boss emotes, raid warnings, loot rolls, the aggro warning and your own alerts."),
    ]),
    ("motion", "Flashing and motion", "For players sensitive to flashing light or movement.", [
        ("Safe flashing", "Nothing flashes more than three times a second, flashes are gentle, pulsing warnings hold still, and the game's red low-health flash is off."),
        ("Reduce motion", "No fades, pulses, gliding bars or camera drift: things appear and change at once."),
        ("A still sky", "The celestial themes keep their stars but hold still: no twinkling and no shooting stars, while everything else moves as usual."),
    ]),
    ("hands", "Hands and keys", "For playing with one hand, or with the keyboard alone.", [
        ("Keys for one hand", "One button puts moving, jumping, targeting, interacting and the first action buttons round W, A, S and D for the left hand, or all on the number pad for the right. Another puts every key back as it was."),
        ("The game's windows by keyboard", "With an NPC's talk, a quest, a vendor, the mailbox, loot, a trainer, a flight master or a question box open, Tab moves from button to button and Enter presses it, with a ring to show where you are and each choice said aloud if you like."),
        ("The settings by keyboard", "Tab and the arrow keys go from setting to setting, Space switches one, Left and Right move a slider."),
        ("Bigger controls", "Larger switches in the settings, and \"click twice\" buttons wait ten seconds for the second click."),
    ]),
    ("calm", "Focus and calm", "For a quieter screen.", [
        ("Calm mode", "One notification at a time, held for fifteen seconds and put away with a click, and messages that stay up longer."),
        ("A wait before tooltips", "Tooltips show only when the mouse rests a moment, so sweeping across the screen does not throw one up after another."),
    ]),
    ("share", "Share it", "For helping a friend, or setting up a new character.", [
        ("One line of text", "All your accessibility settings as one line to copy, keep or give to someone; pasting it back sets them all at once."),
        ("A Comfort step in the setup", "The first-time setup has a step for seeing, hearing and calm, so it is ready before you play."),
    ]),
]


LEDE = 'Fantasy Glass UI has accessibility built into every part of the interface: colors for each kind of color vision, high-contrast themes, lettering made to be read, captions, reading aloud, safe flashing, and keys for one hand. All of it is free, and every part can be switched on or off.'
HONEST = '<section class="honest">\n    <h2>What it does not do (yet)</h2>\n    <p>It is not a screen reader: reading aloud covers talk, quests, books, tooltips, whispers and the buttons of the game\'s main windows, but not every part of every window. The two readable lettering styles have Western European letters only. Reading aloud uses the voices your computer gives the game. Ideas and problems are welcome on <a href="{{discord}}">Discord</a>.</p>\n  </section>'


def body(ctx):
    e = lambda t: html.escape(t, quote=False)
    en = '' if ctx.lang == 'en' else ' lang="en"'           # (the text is written in English)
    cards = []
    for anchor, title, who, items in NEEDS:
        lis = "".join(f'<li><b>{e(h)}.</b> {e(d)}</li>' for h, d in items)
        cards.append(f'<section class="need card" id="{anchor}" aria-labelledby="h-{anchor}"><h2 id="h-{anchor}">{e(title)}</h2><p class="who">{e(who)}</p><ul>{lis}</ul></section>')
    jump = "".join(f'<a href="#{a}">{e(t)}</a>' for a, t, _, _ in NEEDS)
    note = '' if ctx.lang == 'en' else '<p class="faint">[[This page is in English for now.]]</p>'
    return f'''<!-- Accessibility (W3). pages/accessibility/body.py; see site-src/PAGES.md. -->
<div class="wrap narrow page-head">
  <h1>[[Accessibility]]</h1>
  {note}
  <div{en}>
  <p class="lede">{LEDE}</p>
  <p class="start">In the game: <code>/fgui access</code> opens the Accessibility settings, and the first-time setup has a Comfort step. Version {e(ctx.version)}.</p>
  </div>
</div>
<div class="wrap narrow acc"{en}>
  <nav class="jump" aria-label="Needs">{jump}</nav>
  <div id="needs">
{chr(10).join(cards)}
  </div>
  {HONEST}
</div>
'''
