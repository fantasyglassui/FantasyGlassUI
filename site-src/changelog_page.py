# Make the site's changelog page (docs/changelog/index.html) from CHANGELOG.md.
# usage: python3 changelog_page.py <CHANGELOG.md> <out.html>
import html, re, sys

src, out = sys.argv[1], sys.argv[2]
lines = open(src, encoding='utf-8').read().split('\n')

def inline(t):
    t = html.escape(t, quote=False)
    t = re.sub(r'`([^`]+)`', r'<code>\1</code>', t)
    t = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', t)
    t = re.sub(r'\[([^\]]+)\]\((https?://[^)\s]+)\)', r'<a href="\2">\1</a>', t)
    return t

# --- read it: an intro, then one block per "## version"
intro, versions, cur = [], [], None
for ln in lines:
    if ln.startswith('# '): continue
    m = re.match(r'^## (\S+)\s*$', ln)
    if m:
        cur = {'v': m.group(1), 'lines': []}; versions.append(cur); continue
    (cur['lines'] if cur else intro).append(ln)

# bullets nest by depth (two spaces a level)
def ul(items):
    h, stack = [], []
    for d, t in items:
        d = min(d, len(stack))                       # (no jumping two levels at once)
        while len(stack) > d + 1: h.append('</li></ul>'); stack.pop()
        if len(stack) == d + 1: h.append('</li>')
        else: h.append('<ul>'); stack.append(d)
        h.append('<li>' + inline(t))
    while stack: h.append('</li></ul>'); stack.pop()
    return ''.join(h)

def body(ls):
    out, para, items = [], [], []
    def fp():
        if para: out.append('<p>' + inline(' '.join(para)) + '</p>'); para.clear()
    def fi():
        if items: out.append(ul(items)); items.clear()
    for ln in ls:
        if not ln.strip(): fp(); continue
        m = re.match(r'^( *)- (.*)$', ln)
        if m: fp(); items.append([len(m.group(1)) // 2, m.group(2)]); continue
        if items and ln.startswith(' '): items[-1][1] += ' ' + ln.strip(); continue
        sub = re.match(r'^\*\*(.+)\*\*\s*$', ln)
        if sub and '**' not in sub.group(1):
            fp(); fi(); out.append('<h3>' + inline(sub.group(1)) + '</h3>'); continue
        fi(); para.append(ln.strip())
    fp(); fi()
    return '\n'.join(out)

anchor = lambda v: 'v' + v.replace('.', '-')
intro_html = body(intro)
newest = versions[0]['v']

chips = ''.join(f'<a href="#{anchor(x["v"])}">{x["v"]}</a>' for x in versions)
secs = []
for i, x in enumerate(versions):
    badge = ' <span class="now">Current</span>' if i == 0 else ''
    first = ' <span class="first">First release</span>' if i == len(versions) - 1 else ''
    secs.append(f'<section class="ver" id="{anchor(x["v"])}" data-v="{x["v"]}">\n'
                f'<h2><a href="#{anchor(x["v"])}">{x["v"]}</a>{badge}{first}</h2>\n{body(x["lines"])}\n</section>')

page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Changelog · Fantasy Glass UI</title>
<meta name="description" content="Every release of Fantasy Glass UI, the WoW Forever add-on, from the first to {newest}: what is new, what was fixed and what changed.">
<link rel="canonical" href="https://fantasyglassui.com/changelog/">
<link rel="icon" type="image/png" href="/icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="Fantasy Glass UI">
<meta property="og:title" content="Fantasy Glass UI changelog">
<meta property="og:description" content="Every release, from the first to {newest}.">
<meta property="og:url" content="https://fantasyglassui.com/changelog/">
<meta property="og:image" content="https://fantasyglassui.com/og.jpg">
<meta name="theme-color" content="#06070d">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Marcellus&family=Source+Sans+3:wght@400;600&display=swap">
<style>
  :root {{ --ink: #06070d; --panel: rgba(16,19,34,.78); --line: rgba(170,179,210,.18); --text: #eef0f8; --dim: #aab3d2; --gold: #f0c66b; }}
  * {{ box-sizing: border-box; }}
  html {{ scroll-behavior: smooth; scroll-padding-top: 84px; }}
  @media (prefers-reduced-motion: reduce) {{ html {{ scroll-behavior: auto; }} }}
  body {{ margin: 0; background: var(--ink); color: var(--text); font: 400 1.05rem/1.6 "Source Sans 3", system-ui, sans-serif; }}
  canvas {{ position: fixed; inset: 0; width: 100%; height: 100%; z-index: 0; }}
  a {{ color: var(--gold); }}
  a:focus-visible, input:focus-visible {{ outline: 2px solid #fff; outline-offset: 3px; }}
  .skip {{ position: absolute; left: -999px; top: 8px; background: var(--gold); color: #1a1408; padding: 8px 14px; z-index: 5; }}
  .skip:focus {{ left: 16px; }}
  header {{ position: sticky; top: 0; z-index: 3; background: rgba(6,7,13,.86); backdrop-filter: blur(8px); border-bottom: 1px solid var(--line); }}
  .bar {{ max-width: 860px; margin: 0 auto; padding: 12px 16px; display: flex; align-items: center; gap: 16px; }}
  .home {{ display: flex; align-items: center; gap: 10px; color: var(--text); text-decoration: none; font: 400 1.15rem Marcellus, Georgia, serif; }}
  .home img {{ width: 32px; height: 32px; }}
  .bar input {{ margin-left: auto; width: min(320px, 50vw); padding: 8px 12px; border: 1px solid var(--line); background: rgba(255,255,255,.05); color: var(--text); font: inherit; font-size: .95rem; }}
  .bar input::placeholder {{ color: var(--dim); }}
  main {{ position: relative; z-index: 1; max-width: 860px; margin: 0 auto; padding: 40px 16px 80px; }}
  h1 {{ font: 400 clamp(2.2rem, 7vw, 3.4rem)/1.1 Marcellus, Georgia, serif; margin: 0 0 10px; letter-spacing: .02em; }}
  .intro {{ color: var(--dim); margin-bottom: 22px; }}
  .intro p {{ margin: 0; }}
  nav.jump {{ display: flex; flex-wrap: wrap; gap: 6px; margin: 0 0 34px; }}
  nav.jump a {{ padding: 4px 10px; border: 1px solid var(--line); color: var(--dim); text-decoration: none; font-size: .9rem; font-variant-numeric: tabular-nums; }}
  nav.jump a:first-child {{ border-color: var(--gold); color: var(--gold); }}
  nav.jump a:hover {{ color: var(--text); border-color: var(--dim); }}
  nav.jump a.gone {{ opacity: .3; }}
  .ver {{ background: var(--panel); border: 1px solid var(--line); padding: 22px 26px 12px; margin: 0 0 22px;
          clip-path: polygon(14px 0, calc(100% - 14px) 0, 100% 14px, 100% calc(100% - 14px), calc(100% - 14px) 100%, 14px 100%, 0 calc(100% - 14px), 0 14px); }}
  .ver:first-of-type {{ border-color: rgba(240,198,107,.5); }}
  h2 {{ font: 400 1.9rem/1.2 Marcellus, Georgia, serif; margin: 0 0 6px; display: flex; flex-wrap: wrap; align-items: center; gap: 12px; }}
  h2 a {{ color: var(--text); text-decoration: none; font-variant-numeric: tabular-nums; }}
  h2 a:hover {{ color: var(--gold); }}
  .now, .first {{ font: 600 .75rem/1 "Source Sans 3", sans-serif; letter-spacing: .08em; text-transform: uppercase; padding: 5px 9px; }}
  .now {{ background: var(--gold); color: #1a1408; }}
  .first {{ border: 1px solid var(--dim); color: var(--dim); }}
  h3 {{ font: 600 .82rem/1.3 "Source Sans 3", sans-serif; letter-spacing: .1em; text-transform: uppercase; color: var(--gold); margin: 20px 0 6px; }}
  .ver p {{ color: var(--dim); margin: 8px 0 12px; }}
  ul {{ margin: 0 0 12px; padding-left: 1.3em; }}
  ul ul {{ margin: 4px 0 4px; }}
  li {{ margin: 0 0 7px; }}
  li::marker {{ color: var(--gold); }}
  code {{ font: .9em ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; background: rgba(255,255,255,.07); padding: 1px 5px; overflow-wrap: anywhere; }}
  mark {{ background: rgba(240,198,107,.35); color: inherit; padding: 0 1px; }}
  .none {{ display: none; color: var(--dim); text-align: center; padding: 30px 0; }}
  .top {{ display: block; text-align: center; margin-top: 30px; }}
  footer {{ position: relative; z-index: 1; text-align: center; color: var(--dim); font-size: .9rem; padding: 0 16px 40px; }}
  @media (max-width: 560px) {{ .ver {{ padding: 18px 16px 8px; }} .home span {{ display: none; }} .bar input {{ width: 100%; }} }}
</style>
</head>
<body>
<a class="skip" href="#log">Skip to the changes</a>
<canvas id="sky" aria-hidden="true"></canvas>
<header><div class="bar">
  <a class="home" href="/"><img src="/logo-64.webp" alt="" width="32" height="32"><span>Fantasy Glass UI</span></a>
  <input id="q" type="search" placeholder="Search the changes" aria-label="Search the changes">
</div></header>
<main>
  <h1>Changelog</h1>
  <div class="intro">{intro_html}</div>
  <nav class="jump" aria-label="Versions">{chips}</nav>
  <div id="log">
{chr(10).join(secs)}
  </div>
  <p class="none" id="none" role="status">Nothing in the changelog matches that.</p>
  <a class="top" href="#">Back to the top</a>
</main>
<footer>Fantasy Glass UI by DustyMouse. Free, for WoW Forever. <a href="/">Back to the site</a></footer>
<script>
(function () {{
  var c = document.getElementById("sky"), x = c.getContext && c.getContext("2d"); if (!x) return;
  var still = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches, s = [], w, h;
  function size() {{ w = c.width = innerWidth; h = c.height = innerHeight; s = []; for (var i = 0; i < w * h / 7000; i++) s.push([Math.random() * w, Math.random() * h, Math.random() * 1.2 + .2, Math.random() * 6]); if (still) draw(0); }}
  function draw(t) {{ x.clearRect(0, 0, w, h); s.forEach(function (p) {{ x.fillStyle = "rgba(220,230,255," + (still ? .6 : .35 + .35 * Math.sin(p[3] + t / 900)) + ")"; x.beginPath(); x.arc(p[0], p[1], p[2], 0, 6.3); x.fill(); }}); if (!still) requestAnimationFrame(draw); }}
  size(); addEventListener("resize", size); requestAnimationFrame(draw);
}})();
(function () {{
  var q = document.getElementById("q"), secs = [].slice.call(document.querySelectorAll(".ver")), none = document.getElementById("none");
  var chips = {{}}; [].forEach.call(document.querySelectorAll("nav.jump a"), function (a) {{ chips[a.getAttribute("href").slice(1)] = a; }});
  secs.forEach(function (s) {{ [].forEach.call(s.querySelectorAll("li, p"), function (e) {{ e.dataset.html = e.innerHTML; }}); }});
  function esc(t) {{ return t.replace(/[.*+?^${{}}()|[\\]\\\\]/g, "\\\\$&"); }}
  function mark(e, re) {{                       // highlight in the text only, never inside a tag
    e.innerHTML = e.dataset.html.replace(/(<[^>]+>)|([^<]+)/g, function (m, tag, txt) {{ return tag || txt.replace(re, "<mark>$&</mark>"); }});
  }}
  var timer;
  function run() {{
    var t = q.value.trim().toLowerCase(), re = t && new RegExp(esc(t), "gi"), any = false;
    secs.forEach(function (s) {{
      var hit = !t || s.dataset.v.indexOf(t) === 0, own;
      [].forEach.call(s.querySelectorAll("li, p"), function (e) {{
        own = !t || e.textContent.toLowerCase().indexOf(t) >= 0;
        if (t && own) hit = true;
        e.innerHTML = e.dataset.html; if (t && own) mark(e, re);
      }});
      [].forEach.call(s.querySelectorAll(":scope > ul > li, :scope > p"), function (e) {{
        e.hidden = !!t && s.dataset.v.indexOf(t) !== 0 && e.textContent.toLowerCase().indexOf(t) < 0;
      }});
      [].forEach.call(s.querySelectorAll("h3"), function (h) {{        // a subhead with nothing left under it goes too
        var n = h.nextElementSibling, keep = false;
        while (n && n.tagName !== "H3") {{ if (!n.hidden && (n.tagName !== "UL" || n.querySelector(":scope > li:not([hidden])"))) keep = true; n = n.nextElementSibling; }}
        h.hidden = !!t && !keep;
      }});
      [].forEach.call(s.querySelectorAll(":scope > ul"), function (u) {{ u.hidden = !!t && !u.querySelector(":scope > li:not([hidden])"); }});
      s.hidden = !hit; if (hit) any = true;
      var ch = chips[s.id]; if (ch) ch.classList.toggle("gone", !hit);
    }});
    none.style.display = any ? "none" : "block";
  }}
  q.addEventListener("input", function () {{ clearTimeout(timer); timer = setTimeout(run, 120); }});
  addEventListener("keydown", function (e) {{ if (e.key === "/" && document.activeElement !== q) {{ e.preventDefault(); q.focus(); }} }});
}})();
</script>
</body>
</html>
'''
open(out, 'w', encoding='utf-8').write(page)
print(f'{len(versions)} versions, newest {newest} -> {out}')
