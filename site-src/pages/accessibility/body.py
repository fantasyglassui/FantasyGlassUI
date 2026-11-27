# The Accessibility page's body (W3): what Fantasy Glass UI does, need by need, in all 9 languages (every phrase is in
# double square brackets, translated from site_tr.py's Accessibility block). The build calls body(ctx); see site-src/PAGES.md.
# The anchors (#seeing-color and so on) stay as they were; #guide is new in 13.0.

NEEDS = [
    ("seeing-color", "[[Color vision]]", "[[For red-green or blue-yellow color blindness, or seeing no color at all.]]", [
        ("[[Colors for your kind of color vision]]", "[[Red-green (blue and orange), blue-yellow (teal, pink and red), or no color at all, where brightness and marks carry the meaning.]]"),
        ("[[Marks as well as colors]]", '[[Debuffs get a letter, item quality gets dots, and threat on nameplates gets a mark ("!" when it is slipping, "!!" when it is lost).]]'),
    ]),
    ("seeing-low", "[[Low vision]]", "[[For seeing the screen more easily.]]", [
        ("[[High-contrast themes]]", "[[Pure black panels, white lettering and the strongest rims, in all three families: glass, fantasy and celestial. One button picks the one for the family you use.]]"),
        ("[[Lettering made to be read]]", "[[Readable (Atkinson Hyperlegible, made for low vision) and Dyslexia-friendly (OpenDyslexic). A thicker outline round every letter, and a dark band behind messages in the middle of the screen.]]"),
        ("[[Bigger text and a bigger interface]]", "[[Text size and interface scale of their own, separate from the game's.]]"),
        ("[[A ring round your target]]", "[[A thick outline, 1 to 8 pixels, round your target's nameplate, so it stands out in a crowd. A ring round the mouse pointer too.]]"),
    ]),
    ("reading", "[[Reading aloud]]", "[[For blind and low-vision players, and for anyone who would rather listen. In the game's own voice.]]", [
        ("[[Talk and quests read as they open]]", "[[What an NPC says and the choices it offers, a quest's text, its progress and its reward, and books and letters. The reading stops when you close the window.]]"),
        ("[[What you point at]]", "[[When the mouse rests on something, its tooltip is read aloud. (The game's own screen narrator only works before you log in.)]]"),
        ("[[A key that reads]]", "[[One key reads the tooltip under the mouse, the quest you are reading, or the last whisper.]]"),
        ("[[Spoken alerts]]", "[[Ready checks, whispers, missing buffs, loss of control and your own alerts, said aloud.]]"),
    ]),
    ("hearing", "[[Hearing]]", "[[For deaf and hard-of-hearing players, and for playing with the sound off.]]", [
        ("[[Captions for sounds]]", "[[A line on screen, with a mark for its kind, for ready checks, whispers, queues, invites, duels, resurrections, summons, boss emotes, raid warnings, loot rolls, the aggro warning and your own alerts.]]"),
    ]),
    ("motion", "[[Flashing and motion]]", "[[For players sensitive to flashing light or movement.]]", [
        ("[[Safe flashing]]", "[[Nothing flashes more than three times a second, flashes are gentle, pulsing warnings hold still, and the game's red low-health flash is off.]]"),
        ("[[Reduce motion]]", "[[No fades, pulses, gliding bars or camera drift: things appear and change at once.]]"),
        ("[[A still sky]]", "[[The celestial themes keep their stars but hold still: no twinkling and no shooting stars, while everything else moves as usual.]]"),
    ]),
    ("hands", "[[Hands and keys]]", "[[For playing with one hand, or with the keyboard alone.]]", [
        ("[[Keys for one hand]]", "[[One button puts moving, jumping, targeting, interacting and the first action buttons round W, A, S and D for the left hand, or all on the number pad for the right. Another puts every key back as it was.]]"),
        ("[[The game's windows by keyboard]]", "[[With an NPC's talk, a quest, a vendor, the mailbox, loot, a trainer, a flight master or a question box open, Tab moves from button to button and Enter presses it, with a ring to show where you are and each choice said aloud if you like.]]"),
        ("[[The settings by keyboard]]", "[[Tab and the arrow keys go from setting to setting, Space switches one, Left and Right move a slider.]]"),
        ("[[Bigger controls]]", '[[Larger switches in the settings, and "click twice" buttons wait ten seconds for the second click.]]'),
    ]),
    ("guide", "[[The route planner and gold]]", "[[New in 13.0: following a route and making gold in the way that suits you.]]", [
        ("[[The planner by keyboard]]", "[[With <b>Move through the settings with the keyboard</b> on, Tab and the arrow keys go through the planner window, Space or Enter press a button or a switch, and Left and Right change a choice or a slider. In a fight, every key goes back to the game.]]"),
        ("[[Keys for the route]]", "[[Next step, skip step and plan again can each be bound to a key in the game's key bindings, so a route can be followed without the mouse.]]"),
        ("[[The route read aloud]]", "[[With <b>Read talk and quests aloud</b> on, each new step is read as you reach it. The first-time tour, and a friend's question to plan together, are read aloud too.]]"),
        ("[[Colors for your eyes]]", "[[The planner's lists take their colors from your theme and your color-vision setting. The sell hints say Sell now, Hold or Vendor it in words, so color is never the only sign.]]"),
        ("[[Bigger buttons]]", "[[With <b>Bigger controls in the settings</b> on, the buttons of the planner window, the guide panel and its menus are taller too.]]"),
        ("[[A tour you can skip]]", "[[The first time, four short pages explain the planner. Skip closes them at once, Left, Right, Enter and Esc work too, and <b>How the planner works</b> opens them again.]]"),
        ("[[The arrow, your way]]", "[[The planner window's <b>Stop</b> puts the route and its arrow away until you plan again. <code>/fgui move</code> moves the arrow, TomTom's arrow can take its place, and with <b>Reduce motion</b> on it does not pulse when you arrive.]]"),
        ("[[Breaks]]", "[[With <b>Remind me to take a break at a stopping place</b> on, the route tells you when you reach a good place to stop after a long stretch of play, from 1 to 3 hours as you choose.]]"),
    ]),
    ("calm", "[[Focus and calm]]", "[[For a quieter screen.]]", [
        ("[[Calm mode]]", "[[One notification at a time, held for fifteen seconds and put away with a click, and messages that stay up longer.]]"),
        ("[[A wait before tooltips]]", "[[Tooltips show only when the mouse rests a moment, so sweeping across the screen does not throw one up after another.]]"),
    ]),
    ("share", "[[Share it]]", "[[For helping a friend, or setting up a new character.]]", [
        ("[[One line of text]]", "[[All your accessibility settings as one line to copy, keep or give to someone; pasting it back sets them all at once.]]"),
        ("[[A Comfort step in the setup]]", "[[The first-time setup has a step for seeing, hearing and calm, so it is ready before you play.]]"),
    ]),
]

LEDE = '[[Fantasy Glass UI has accessibility built into every part of the interface: colors for each kind of color vision, high-contrast themes, lettering made to be read, captions, reading aloud, safe flashing, and keys for one hand. All of it is free, and every part can be switched on or off.]]'
START = '[[In the game: <code>/fgui access</code> opens the Accessibility settings, and the first-time setup has a Comfort step.]]'
HONEST = ('<section class="honest" aria-labelledby="h-honest">\n    <h2 id="h-honest">[[What it does not do (yet)]]</h2>\n'
          "    <p>[[It is not a screen reader: reading aloud covers talk, quests, books, tooltips, whispers and the buttons of the game's main windows, but not every part of every window.]] "
          '[[The gold window has no keys of its own yet, and is not read aloud.]] '
          '[[The two readable lettering styles have Western European letters only. Reading aloud uses the voices your computer gives the game.]] '
          '[[Ideas and problems are welcome on <a href="{{discord}}">Discord</a>.]]</p>\n  </section>')


def body(ctx):
    cards = []
    for anchor, title, who, items in NEEDS:
        lis = "".join(f'<li><b>{h}.</b> {d}</li>' for h, d in items)
        new = ' new' if anchor == 'guide' else ''
        cards.append(f'<section class="need card{new}" id="{anchor}" aria-labelledby="h-{anchor}"><h2 id="h-{anchor}">{title}</h2><p class="who">{who}</p><ul>{lis}</ul></section>')
    jump = "".join(f'<a href="#{a}">{t}</a>' for a, t, _, _ in NEEDS)
    return f'''<!-- Accessibility (W3). pages/accessibility/body.py; see site-src/PAGES.md. -->
<div class="wrap narrow page-head">
  <h1>[[Accessibility]]</h1>
  <p class="lede">{LEDE}</p>
  <p class="start">{START} {ctx.F("Version %s", ctx.esc(ctx.version))}.</p>
</div>
<div class="wrap narrow acc">
  <nav class="jump" aria-label="[[Needs]]">{jump}</nav>
  <div id="needs">
{chr(10).join(cards)}
  </div>
  {HONEST}
</div>
'''
