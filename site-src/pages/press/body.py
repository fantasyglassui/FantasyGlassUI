# The press kit's body (W3): the logo files (pages/press/files/, from the site's own icons), four screenshots from
# site/shots/, the facts, and a one-paragraph description in every language (site_tr.py's press block).
# The build calls body(ctx); see site-src/PAGES.md.
from lang_meta import LANG_NAMES
from site_tr import SITE

CODES = ['en', 'de', 'fr', 'es', 'ru', 'pt', 'it', 'ko', 'zh']
HREFLANG = {'zh': 'zh-Hans'}
ABOUT = ("Fantasy Glass UI is a free add-on for World of Warcraft, made for WoW Forever by DustyMouse. It gives the whole "
         "interface one look, cut like a gem: unit frames, action bars, raid frames, nameplates, bags and every window, with "
         "{{themes}} themes in three families, Glass, Fantasy and Celestial. Version 13.0, Guide and Gold, adds a route planner "
         "that works out your quests as you level, and Ways to make gold, which lists what is worth your time. It comes in "
         "nine languages and has accessibility built in, from color-vision palettes to reading aloud.")
# (the screenshot, its words: one already translated for Home, the others in the press block)
SHOTS = [
    ("celestial-screen", "[[A whole screen in a Celestial theme: party, player and target, cast bar, action bars and the minimap.]]"),
    ("glass-overview", "[[A whole screen in a Glass theme.]]"),
    ("fantasy-overview", "[[A whole screen in a Fantasy theme.]]"),
    ("celestial-frames", "[[The player and target frames up close, with the pet, the cast bar, buffs and the target's target.]]"),
]
LOGOS = [
    ("fantasy-glass-ui-logo-256.png", "PNG", "256 × 256"),
    ("fantasy-glass-ui-logo-256.webp", "WebP", "256 × 256"),
    ("fantasy-glass-ui-icon-64.png", "PNG", "64 × 64"),
]


def about(code):
    return ABOUT if code == 'en' else SITE[' '.join(ABOUT.split())][CODES.index(code) - 1]


def body(ctx):
    here = ctx.lang
    others = ''.join(f'<div class="about-lang" lang="{HREFLANG.get(c, c)}"><h3>{LANG_NAMES[c]}</h3><p>{about(c)}</p></div>'
                     for c in CODES if c != here)
    logos = ''.join(f'<li><a href="/press/{f}" download>{kind}, {size}</a></li>' for f, kind, size in LOGOS)
    shots = ''.join(f'<figure class="shot"><a href="/shots/{name}.webp"><fg-shot name="{name}" class="cut" sizes="(max-width: 700px) 100vw, 560px" alt="{alt}"></a>'
                    f'<figcaption>{alt} <a href="/shots/{name}.webp" download>[[Full size]]</a></figcaption></figure>' for name, alt in SHOTS)
    return f'''<!-- Press kit (W3). pages/press/body.py, with the logo files in pages/press/files/; see site-src/PAGES.md. -->
<div class="wrap page-head">
  <span class="eyebrow">[[For writers and video makers]]</span>
  <h1>[[Press kit]]</h1>
  <p class="lede">[[The logo, screenshots and a short description, for writing about Fantasy Glass UI or showing it in a video.]]</p>
</div>
<div class="wrap press">
  <section class="about card filled" aria-labelledby="h-about">
    <h2 id="h-about">[[In one paragraph]]</h2>
    <p class="para">{about(here)}</p>
    <details>
      <summary>[[The same paragraph in the other languages]]</summary>
      {others}
    </details>
  </section>

  <section aria-labelledby="h-facts">
    <h2 id="h-facts">[[The facts]]</h2>
    <dl class="facts">
      <div><dt>[[Name]]</dt><dd>Fantasy Glass UI</dd></div>
      <div><dt>[[Made by]]</dt><dd>DustyMouse</dd></div>
      <div><dt>[[For]]</dt><dd>World of Warcraft: WoW Forever</dd></div>
      <div><dt>[[Price]]</dt><dd>[[Free]]</dd></div>
      <div><dt>[[Version]]</dt><dd>{{{{version}}}}</dd></div>
      <div><dt>[[Languages]]</dt><dd>9</dd></div>
      <div><dt>[[Download]]</dt><dd><a href="{{{{curseforge}}}}">CurseForge</a></dd></div>
      <div><dt>[[Source code]]</dt><dd><a href="{{{{github}}}}">GitHub</a></dd></div>
    </dl>
  </section>

  <section class="logo-sec" aria-labelledby="h-logo">
    <h2 id="h-logo">[[The logo]]</h2>
    <div class="logo-row">
      <img src="/press/fantasy-glass-ui-logo-256.png" width="128" height="128" alt="[[The Fantasy Glass UI logo]]">
      <ul class="files">{logos}</ul>
    </div>
  </section>

  <section aria-labelledby="h-shots">
    <h2 id="h-shots">[[Screenshots]]</h2>
    <p class="dim">[[Taken in the game. Press a picture for the full size.]]</p>
    <div class="shots">{shots}</div>
  </section>

  <p class="ask">@@ASK@@</p>
</div>
'''.replace('@@ASK@@', ASK)


ASK = '[[Need something else, or a question answered? Write to <a href="mailto:email-forwarding@fantasyglassui.com">email-forwarding@fantasyglassui.com</a>.]]'
