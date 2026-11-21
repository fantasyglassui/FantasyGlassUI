# The site's accessibility page (docs/accessibility/index.html): what Fantasy Glass UI does, need by need.
# usage: python3 accessibility_page.py <out.html> <version>
import html, sys

out, version = sys.argv[1], sys.argv[2]

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

e = lambda t: html.escape(t, quote=False)
cards = []
for anchor, title, who, items in NEEDS:
    lis = "".join(f'<li><b>{e(h)}.</b> {e(d)}</li>' for h, d in items)
    cards.append(f'<section class="need" id="{anchor}"><h2>{e(title)}</h2><p class="who">{e(who)}</p><ul>{lis}</ul></section>')
jump = "".join(f'<a href="#{a}">{e(t)}</a>' for a, t, _, _ in NEEDS)

page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Accessibility · Fantasy Glass UI</title>
<meta name="description" content="What Fantasy Glass UI, the WoW Forever add-on, does for color blindness, low vision, blind players, deaf players, photosensitivity, one-handed play and more.">
<link rel="canonical" href="https://fantasyglassui.com/accessibility/">
<link rel="icon" type="image/png" href="/icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Fantasy Glass UI">
<meta property="og:title" content="Fantasy Glass UI: accessibility built into every part">
<meta property="og:description" content="Color vision, high contrast, reading aloud, captions, safe flashing, keys for one hand and more, free in one WoW Forever add-on.">
<meta property="og:url" content="https://fantasyglassui.com/accessibility/">
<meta property="og:image" content="https://fantasyglassui.com/og.jpg">
<meta name="theme-color" content="#06070d">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&family=Source+Sans+3:wght@400;600&display=swap">
<style>
  :root {{ --ink: #06070d; --panel: rgba(16,19,34,.82); --line: rgba(170,179,210,.22); --text: #eef0f8; --dim: #b8c0dc; --gold: #f0c66b; }}
  * {{ box-sizing: border-box; }}
  html {{ scroll-behavior: smooth; scroll-padding-top: 84px; }}
  @media (prefers-reduced-motion: reduce) {{ html {{ scroll-behavior: auto; }} }}
  body {{ margin: 0; background: var(--ink); color: var(--text); font: 400 1.1rem/1.65 "Source Sans 3", system-ui, sans-serif; }}
  a {{ color: var(--gold); }}
  a:focus-visible {{ outline: 3px solid #fff; outline-offset: 3px; }}
  .skip {{ position: absolute; left: -999px; top: 8px; background: var(--gold); color: #1a1408; padding: 8px 14px; z-index: 5; }}
  .skip:focus {{ left: 16px; }}
  header {{ position: sticky; top: 0; z-index: 3; background: rgba(6,7,13,.92); border-bottom: 1px solid var(--line); }}
  .bar {{ max-width: 900px; margin: 0 auto; padding: 12px 16px; display: flex; align-items: center; gap: 16px; }}
  .home {{ display: flex; align-items: center; gap: 10px; color: var(--text); text-decoration: none; font: 400 1.15rem Marcellus, Georgia, serif; }}
  .home img {{ width: 32px; height: 32px; }}
  .bar .site {{ margin-left: auto; font-size: .95rem; }}
  main {{ max-width: 900px; margin: 0 auto; padding: 40px 16px 80px; }}
  h1 {{ font: 400 clamp(2.2rem, 7vw, 3.4rem)/1.1 Marcellus, Georgia, serif; margin: 0 0 14px; letter-spacing: .02em; }}
  .lede {{ font-size: 1.25rem; color: var(--text); margin: 0 0 12px; max-width: 46em; }}
  .start {{ color: var(--dim); margin: 0 0 26px; }}
  code {{ font: .92em ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; background: rgba(255,255,255,.09); padding: 1px 6px; }}
  nav.jump {{ display: flex; flex-wrap: wrap; gap: 8px; margin: 0 0 34px; }}
  nav.jump a {{ padding: 6px 12px; border: 1px solid var(--line); color: var(--text); text-decoration: none; font-size: .98rem; }}
  nav.jump a:hover, nav.jump a:focus-visible {{ border-color: var(--gold); color: var(--gold); }}
  .need {{ background: var(--panel); border: 1px solid var(--line); padding: 22px 26px 10px; margin: 0 0 22px;
           clip-path: polygon(14px 0, calc(100% - 14px) 0, 100% 14px, 100% calc(100% - 14px), calc(100% - 14px) 100%, 14px 100%, 0 calc(100% - 14px), 0 14px); }}
  h2 {{ font: 400 1.9rem/1.2 Marcellus, Georgia, serif; margin: 0 0 4px; color: var(--gold); }}
  .who {{ color: var(--dim); margin: 0 0 12px; }}
  ul {{ margin: 0 0 12px; padding-left: 1.2em; }}
  li {{ margin: 0 0 10px; }}
  li::marker {{ color: var(--gold); }}
  li b {{ color: var(--text); }}
  .honest {{ border-left: 3px solid var(--gold); padding: 4px 0 4px 18px; margin: 34px 0 0; color: var(--dim); }}
  .honest h2 {{ font-size: 1.5rem; color: var(--text); }}
  footer {{ text-align: center; color: var(--dim); font-size: .95rem; padding: 0 16px 40px; }}
  @media (max-width: 560px) {{ .need {{ padding: 18px 16px 6px; }} .home span {{ display: none; }} }}
</style>
</head>
<body>
<a class="skip" href="#needs">Skip to what it does</a>
<header><div class="bar">
  <a class="home" href="/"><img src="/logo-64.webp" alt="" width="32" height="32"><span>Fantasy Glass UI</span></a>
  <a class="site" href="/">Back to the site</a>
</div></header>
<main>
  <h1>Accessibility</h1>
  <p class="lede">Fantasy Glass UI has accessibility built into every part of the interface: colors for each kind of color vision, high-contrast themes, lettering made to be read, captions, reading aloud, safe flashing, and keys for one hand. All of it is free, and every part can be switched on or off.</p>
  <p class="start">In the game: <code>/fgui access</code> opens the Accessibility settings, and the first-time setup has a Comfort step. Version {e(version)}.</p>
  <nav class="jump" aria-label="Needs">{jump}</nav>
  <div id="needs">
{chr(10).join(cards)}
  </div>
  <section class="honest">
    <h2>What it does not do (yet)</h2>
    <p>It is not a screen reader: reading aloud covers talk, quests, books, tooltips, whispers and the buttons of the game's main windows, but not every part of every window. The two readable lettering styles have Western European letters only. Reading aloud uses the voices your computer gives the game. Ideas and problems are welcome on <a href="https://discord.gg/qeSMwQWyPR">Discord</a>.</p>
  </section>
</main>
<footer>Fantasy Glass UI by DustyMouse. Free, for WoW Forever. <a href="/">Back to the site</a> · <a href="/changelog/">Changelog</a></footer>
</body>
</html>
'''
open(out, "w", encoding="utf-8").write(page)
print(f"{sum(len(n[3]) for n in NEEDS)} features in {len(NEEDS)} needs -> {out}")
