"""Every page of the website in a real browser (Playwright's Chromium), at a phone's width (390 px) and a desktop's (1280 px).
usage: python3 tests/sitebrowser.py [--shots DIR] [--quick]   ->   "site browser: N pages checked"   (exit 0)

The site is built into a temporary folder and served from this computer. Every page, in English (dark and light) and
in German, is checked for: a skip link that shows when it gets focus; a header, navigation, main part and footer, and
one h1; a visible focus ring; AA contrast for every piece of text on a plain background (4.5:1, or 3:1 for large text;
text over a screenshot is left to the eye); no page wider than the screen; no script from another site; and no
script error. The other languages are checked at 390 px for width. The plan page (/plan/) is checked at 390 px: a
plan code pasted shows its steps, in German too, with no script error and nothing wider than the screen; a sample plan's route
is pinned on the world map at the expected pixels (390 and 1280 px, light and dark), asking only this site, and once a plan is
shown; without tiles the zone sketches show instead. The world map (/map/)
draws its tiles from this site, its places file is valid and ?pins shows the pin helper. On Guide and
Gold (English and German, 390 px), the example route is drawn and the short tour opens, steps on and closes by keyboard. --shots DIR
saves Home and Get started, dark and light, at both widths (and the plan page's route, plan-route-*.png). --quick checks English only. Needs Python's playwright with its Chromium; when that is
missing it says so and exits 0 (the other site checks still run)."""
import functools
import json
import http.server
import os
import socketserver
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "site-src"))
from lang_meta import PAGES  # noqa: E402

LANGS = ["en", "de", "fr", "es", "ru", "pt", "it", "ko", "zh"]
args = sys.argv[1:]
SHOTS = args[args.index("--shots") + 1] if "--shots" in args else None
QUICK = "--quick" in args

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("site browser: skipped (no playwright)")
    sys.exit(0)

# run in the page: every problem found, as text
CHECK = r"""
() => {
  const bad = [];
  const parse = (c) => {
    let m = c.match(/^rgba?\(([\d.]+),\s*([\d.]+),\s*([\d.]+)(?:,\s*([\d.]+))?\)$/);
    if (m) return [+m[1], +m[2], +m[3], m[4] === undefined ? 1 : +m[4]];
    m = c.match(/^color\(srgb ([\d.e-]+) ([\d.e-]+) ([\d.e-]+)(?: \/ ([\d.]+))?\)$/);
    if (m) return [m[1] * 255, m[2] * 255, m[3] * 255, m[4] === undefined ? 1 : +m[4]];
    return null;
  };
  const over = (top, under) => { const a = top[3]; return [0, 1, 2].map(i => top[i] * a + under[i] * (1 - a)).concat(1); };
  const lum = (c) => { const v = c.slice(0, 3).map(x => { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); }); return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]; };
  const ratio = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };
  // the colour behind an element, or null when a picture or a gradient is behind it
  const behind = (el) => {
    const layers = [];
    for (let e = el; e; e = e.parentElement) {
      const s = getComputedStyle(e);
      if (e !== el && (e.tagName === "IMG" || e.tagName === "VIDEO" || e.tagName === "CANVAS")) return null;
      if (s.backgroundImage && s.backgroundImage !== "none" && !e.classList.contains("card") && !e.classList.contains("btn")) return null;
      if (e.querySelector(":scope > img.shot-bg, :scope > video")) return null;
      const c = parse(s.backgroundColor);
      if (c && c[3] > 0) { layers.push(c); if (c[3] >= 1) break; }
    }
    let base = [255, 255, 255, 1];
    for (let i = layers.length - 1; i >= 0; i--) base = over(layers[i], base);
    return base;
  };
  const seen = new Set();
  document.querySelectorAll("body *").forEach((el) => {
    if (["SCRIPT", "STYLE", "OPTION", "SVG", "PATH", "TEXTAREA", "INPUT", "SELECT"].includes(el.tagName.toUpperCase())) return;
    const own = [...el.childNodes].some(n => n.nodeType === 3 && n.textContent.trim());
    if (!own) return;
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return;                               // (hidden, or for screen readers only)
    const s = getComputedStyle(el);
    if (s.visibility === "hidden" || s.display === "none") return;
    if (el.closest("[hidden], .skip, [aria-hidden='true']")) return;
    let op = 1; for (let e = el; e; e = e.parentElement) op *= +getComputedStyle(e).opacity;
    if (op < 0.99) return;                                                  // (still fading in)
    const fg = parse(s.color); if (!fg || fg[3] === 0) return;              // (text drawn with a gradient)
    const bg = behind(el); if (!bg) return;
    const size = parseFloat(s.fontSize), w = +s.fontWeight;
    const need = (size >= 24 || (size >= 18.66 && w >= 700)) ? 3 : 4.5;
    const got = ratio(fg[3] < 1 ? over(fg, bg) : fg, bg);
    if (got + 0.005 < need) {
      const key = el.tagName + "." + el.className + ":" + el.textContent.trim().slice(0, 40);
      if (!seen.has(key)) { seen.add(key); bad.push(`contrast ${got.toFixed(2)} < ${need}: <${el.tagName.toLowerCase()} class="${el.className}"> "${el.textContent.trim().slice(0, 50)}" (${s.color} on rgb(${bg.slice(0, 3).map(Math.round)}))`); }
    }
  });
  const d = document.documentElement;
  if (d.scrollWidth > d.clientWidth + 1) {
    let widest = null, wmax = d.clientWidth;
    document.querySelectorAll("body *").forEach(e => { const r = e.getBoundingClientRect(); if (r.right > wmax + 1 && getComputedStyle(e).position !== "fixed") { wmax = r.right; widest = e; } });
    bad.push(`wider than the screen: ${d.scrollWidth} > ${d.clientWidth}` + (widest ? ` (<${widest.tagName.toLowerCase()} class="${widest.className}">)` : ""));
  }
  for (const sel of ["header.site-head", "nav", "main#main", "footer.site-foot", "a.skip[href='#main']"]) if (!document.querySelector(sel)) bad.push("missing " + sel);
  const h1 = document.querySelectorAll("h1").length; if (h1 !== 1) bad.push(h1 + " h1 elements");
  document.querySelectorAll("script[src]").forEach(s => { if (new URL(s.src).origin !== location.origin) bad.push("a script from " + s.src); });
  document.querySelectorAll("img").forEach(i => { if (!i.hasAttribute("alt")) bad.push("an image with no alt: " + i.src); if (!i.getAttribute("width") && !i.closest(".thumb, .leaflet-container")) bad.push("an image with no size: " + i.src); });
  return bad;
}
"""
FOCUS = r"""
() => { const a = document.activeElement; if (!a || a === document.body) return "nothing";
  const s = getComputedStyle(a), r = a.getBoundingClientRect();
  const ring = (s.outlineStyle !== "none" && parseFloat(s.outlineWidth) > 0) || s.boxShadow !== "none";
  return (a.className || a.tagName) + "|" + ring + "|" + (r.top >= 0 && r.bottom <= innerHeight + 1); }
"""


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


class Server(socketserver.ThreadingTCPServer):
    daemon_threads = True

    def handle_error(self, *a):                # (a page left before a file finished loading)
        pass


def main():
    problems, checked = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "site")
        r = subprocess.run([sys.executable, os.path.join(ROOT, "site-src", "build_site.py"), "--out", out], capture_output=True, text=True, timeout=300)
        if r.returncode:
            print("site browser: the build failed: " + (r.stdout + r.stderr)[-400:]); return 1
        httpd = Server(("127.0.0.1", 0), functools.partial(Quiet, directory=out))
        threading.Thread(target=httpd.serve_forever, daemon=True).start()
        base = "http://127.0.0.1:%d" % httpd.server_address[1]
        with sync_playwright() as p:
            try:
                browser = p.chromium.launch()
            except Exception as e:  # (no browser downloaded)
                print("site browser: skipped (" + str(e).splitlines()[0] + ")"); return 0
            runs = []
            for lang in (["en"] if QUICK else ["en", "de"]):
                for scheme in (["dark", "light"] if lang == "en" else ["dark"]):
                    for w in (390, 1280):
                        runs.append((lang, scheme, w, True))
            if not QUICK:
                runs += [(lang, "dark", 390, False) for lang in LANGS if lang not in ("en", "de")]
            for lang, scheme, w, full in runs:
                ctx = browser.new_context(viewport={"width": w, "height": 900}, device_scale_factor=1, color_scheme=scheme,
                                          reduced_motion="reduce", locale="en-US")
                ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) else route.continue_())
                page = ctx.new_page()
                errors = []
                page.on("pageerror", lambda e: errors.append(str(e)))
                page.on("console", lambda m: errors.append(m.text) if m.type == "error" and "net::ERR_FAILED" not in m.text and "Failed to load resource" not in m.text else None)
                for pg in PAGES:
                    path = ("/" if lang == "en" else f"/{lang}/") + ("" if pg["slug"] == "home" else pg["slug"] + "/")
                    where = f"{path} {w}px {scheme}"
                    page.goto(base + path, wait_until="load")
                    page.wait_for_timeout(250)
                    if page.url != base + path:
                        problems.append(f"{where}: went to {page.url}"); continue
                    if SHOTS and pg["slug"] in ("home", "get-started") and lang == "en":
                        os.makedirs(SHOTS, exist_ok=True)
                        page.evaluate("window.scrollTo(0, 0)")
                        page.screenshot(path=os.path.join(SHOTS, f"{pg['slug']}-{scheme}-{w}.png"), full_page=True)
                    found = page.evaluate(CHECK)
                    if not full:
                        found = [f for f in found if f.startswith("wider")]
                    problems += [f"{where}: {f}" for f in found]
                    if full:
                        page.keyboard.press("Tab")
                        f = page.evaluate(FOCUS).split("|")
                        if f[0] != "skip" or f[2] != "true": problems.append(f"{where}: the first Tab does not show the skip link ({f})")
                        for _ in range(3):
                            page.keyboard.press("Tab")
                            f = page.evaluate(FOCUS).split("|")
                            if len(f) < 2 or f[1] != "true": problems.append(f"{where}: no focus ring on {f[0]}")
                    checked += 1
                problems += [f"{lang} {w}px {scheme}: script error: {e}" for e in errors]
                ctx.close()
            # links into the old long page land on the page that now has that part, and the shared controls work
            ctx = browser.new_context(viewport={"width": 1280, "height": 900}, locale="en-US")
            ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) else route.continue_())
            page = ctx.new_page()
            for old, new in [("/#faq", "/get-started/#faq"), ("/#features", "/features/"), ("/#commands", "/get-started/#commands"),
                             ("/#themes", "/themes/"), ("/?theme=celestial-polaris#themes", "/themes/?theme=celestial-polaris"),
                             ("/?code=SUIT1!x#maker", "/themes/?code=SUIT1!x#maker"), ("/#start", "/get-started/"), ("/#look", "/#look"),
                             ("/de/#faq", "/de/get-started/#faq"), ("/?lang=fr", "/fr/"), ("/features/?lang=ko", "/ko/features/")]:
                page.goto(base + old, wait_until="load")
                if page.url != base + new:
                    problems.append(f"{old} went to {page.url[len(base):]}, not {new}")
                checked += 1
            page.goto(base + "/features/")
            page.select_option("#lang", "/de/features/")
            page.wait_for_url(base + "/de/features/")
            page.goto(base + "/features/")                     # (the choice is remembered: an English page opens German)
            if page.url != base + "/de/features/": problems.append("the chosen language is not remembered: " + page.url)
            page.evaluate("localStorage.setItem('fg-lang', 'en')")
            page.goto(base + "/get-started/")
            before = page.evaluate("document.documentElement.getAttribute('data-theme')")
            page.click("#mode")
            after = page.evaluate("[document.documentElement.getAttribute('data-theme'), document.getElementById('mode').getAttribute('aria-pressed')]")
            page.goto(base + "/")
            kept = page.evaluate("document.documentElement.getAttribute('data-theme')")
            if after[0] not in ("light", "dark") or after[0] == before or kept != after[0] or after[1] != str(after[0] == "dark").lower():
                problems.append(f"light and dark: {before} -> {after} -> {kept}")
            page.goto(base + "/themes/")
            page.click("#wear")
            page.goto(base + "/changelog/")
            if page.evaluate("document.getElementById('unwear').hidden"): problems.append("a worn theme is not kept on the other pages")
            page.click("#unwear")
            ctx.close()
            # the plan page on a phone: a code pasted draws its steps; the page's own language switch works
            code = next(l.split("\t")[5] for l in open(os.path.join(ROOT, "tests", "plan_codes.txt"), encoding="utf-8").read().splitlines() if l.startswith("ok\t"))
            ctx = browser.new_context(viewport={"width": 390, "height": 800}, locale="en-US")
            ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) else route.continue_())
            page = ctx.new_page()
            errors = []
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.goto(base + "/plan/", wait_until="load")
            page.fill("#code", code)
            page.wait_for_timeout(200)
            got = page.evaluate("[document.querySelectorAll('#steps li').length, document.getElementById('plan').hidden, document.documentElement.scrollWidth > document.documentElement.clientWidth + 1, document.getElementById('howto').textContent]")
            if got[0] < 1 or got[1] or got[2] or not got[3]:
                problems.append(f"/plan/ 390px: steps {got[0]}, hidden {got[1]}, too wide {got[2]}, how-to link {got[3]!r}")
            page.select_option("#lang", "de")
            if page.evaluate("document.getElementById('title').textContent") in ("", "Your route", "Quest guide"):
                problems.append("/plan/: the page's language switch does nothing")
            problems += [f"/plan/: script error: {e}" for e in errors]
            checked += 1
            ctx.close()
            # OpenMap on the plan page: nothing asks openmap.world on load (with a plan or without, and not on Guide and Gold);
            # OpenMap refuses to be framed, so it is only a link, opened in a new tab
            for w, scheme in ((390, "dark"), (390, "light"), (1280, "dark"), (1280, "light")):
                ctx = browser.new_context(viewport={"width": w, "height": 900}, locale="en-US", color_scheme=scheme)
                asked = []
                ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) else route.continue_())
                page = ctx.new_page()
                page.on("request", lambda r: asked.append(r.url) if not r.url.startswith(base) else None)
                errors = []
                page.on("pageerror", lambda e: errors.append(str(e)))
                where = f"/plan/ OpenMap {w}px {scheme}"
                page.goto(base + "/plan/#c=" + code, wait_until="load")
                page.wait_for_timeout(300)
                if asked or page.evaluate("document.querySelectorAll('iframe').length"):
                    problems.append(f"{where}: the page asks for an outside address or has an iframe before the button: {asked}")
                page.goto(base + "/guide-and-gold/", wait_until="load")
                page.wait_for_timeout(300)
                if asked or page.evaluate("document.querySelectorAll('iframe').length") or not page.evaluate("!!document.querySelector('#example a[href=\"https://openmap.world/\"][target=_blank][rel=\"noopener noreferrer\"]')"):
                    problems.append(f"{where}: Guide and Gold must only link OpenMap ({asked})")
                page.goto(base + "/plan/", wait_until="load")
                page.wait_for_timeout(200)
                link = page.evaluate("(() => { const a = document.getElementById('openmaptab'); return [a.href, a.target, a.rel, a.textContent, getComputedStyle(a).display]; })()")
                if link[:4] != ["https://openmap.world/", "_blank", "noopener noreferrer", "Open OpenMap in a new tab"]:
                    problems.append(f"{where}: the fallback link is wrong: {link}")
                page.focus("#openmaptab")
                f = page.evaluate(FOCUS).split("|")
                if f[1] != "true": problems.append(f"{where}: no focus ring on the OpenMap link")
                bad = [x for x in page.evaluate(CHECK) if x.startswith(("contrast", "wider"))]
                problems += [f"{where}: {x}" for x in bad]
                if SHOTS:
                    os.makedirs(SHOTS, exist_ok=True)
                    page.locator("section.real").screenshot(path=os.path.join(SHOTS, f"openmap-{scheme}-{w}.png"))
                if page.evaluate("document.querySelectorAll('iframe').length"):
                    problems.append(f"{where}: OpenMap refuses frames, so the page must only link it")
                problems += [f"{where}: script error: {e}" for e in errors]
                checked += 1
                ctx.close()
            # the route on the world map (/plan/): nothing of the map is asked for until a plan is shown; then a sample plan's
            # steps are pinned where tests/plan_map_points.json says (pixels of /map/ at maxZoom), the steps with no place are
            # listed in a note, the current step's pin moves on with a tick, the map is at least 300 px tall and never wider
            # than the screen, it asks this site only and no tile that isn't there, with no script error; the map does not
            # take the mouse wheel (or, on a phone, one finger) until it is clicked. Without tiles it falls back to the sketches.
            sample = json.load(open(os.path.join(ROOT, "tests", "plan_map_points.json"), encoding="utf-8"))
            for w, scheme in ((390, "dark"), (390, "light"), (1280, "dark"), (1280, "light")):
                phone = w == 390
                ctx = browser.new_context(viewport={"width": w, "height": 900}, locale="en-US", color_scheme=scheme, has_touch=phone, is_mobile=phone,
                                          reduced_motion="reduce")
                asked, mine, tiles, errors = [], [], [], []
                ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) else route.continue_())
                page = ctx.new_page()
                page.on("request", lambda r: asked.append(r.url) if not r.url.startswith(base) else mine.append(r.url[len(base):]))
                page.on("response", lambda r: tiles.append((r.url, r.status)) if "/map/tiles/" in r.url and r.url.endswith(".webp") else None)
                page.on("pageerror", lambda e: errors.append(str(e)))
                page.on("console", lambda m: errors.append(m.text) if m.type in ("error", "warning") else None)
                where = f"/plan/ route {w}px {scheme}"
                page.goto(base + "/plan/", wait_until="load")
                page.wait_for_timeout(300)
                early = [u for u in mine if u.startswith(("/map/", "/plan/zones"))]
                if early:
                    problems.append(f"{where}: the map is asked for before a plan is shown: {early[:3]}")
                page.fill("#code", sample["code"])
                try:
                    page.wait_for_selector("#routemap img.leaflet-tile-loaded", timeout=8000)
                    page.wait_for_selector("#routemap .rt-pin[data-steps]", timeout=4000)
                except Exception:
                    problems.append(f"{where}: the route map was not drawn")
                page.wait_for_timeout(400)
                got = page.evaluate("""(pts) => {
                  const box = document.getElementById('routemap'), m = box._fgMap, Z = m.getMaxZoom() - 1, out = [];
                  const before = [m.scrollWheelZoom.enabled(), m.dragging.enabled()];
                  for (const q of pts) {
                    const ll = m.unproject(q.px, Z);
                    m.setView(ll, Z, { animate: false });
                    const pin = [...box.querySelectorAll('.rt-pin[data-steps]')].find(e => e.dataset.steps.split(' ').includes(String(q.step)));
                    if (!pin) { out.push([q.step, null]); continue; }
                    const r = pin.getBoundingClientRect(), c = box.getBoundingClientRect(), want = m.latLngToContainerPoint(ll);
                    out.push([q.step, Math.round(Math.hypot(r.left + r.width / 2 - c.left - want.x, r.top + r.height / 2 - c.top - want.y))]);
                  }
                  return { off: out, before, height: box.offsetHeight, unplaced: document.getElementById('unplaced').textContent,
                           credit: !!document.querySelector('#mapcredit a[href="/map/"]') && document.getElementById('mapcredit').textContent.includes('Blizzard'),
                           sketch: !document.getElementById('panels').hidden, wide: document.documentElement.scrollWidth > document.documentElement.clientWidth + 1 };
                }""", sample["points"])
                far = [o for o in got["off"] if o[1] is None or o[1] > 4]
                if far:
                    problems.append(f"{where}: pins not where their steps are (step, px off): {far}")
                if got["before"] != [False, not phone]:
                    problems.append(f"{where}: the map takes the wheel or one finger before it is clicked: {got['before']}")
                if got["height"] < 300 or got["wide"] or got["sketch"] or not got["credit"]:
                    problems.append(f"{where}: height {got['height']}, too wide {got['wide']}, sketch shown {got['sketch']}, credit {got['credit']}")
                if got["unplaced"] != "Steps " + ", ".join(str(i + 1) for i in sample["unplaced"]) + " have no place on the map.":
                    problems.append(f"{where}: the steps with no place: {got['unplaced']!r}")
                page.locator("#views button").first.click()             # (the whole route again)
                now1 = page.evaluate("document.querySelector('#routemap [aria-current=step]').dataset.steps")
                page.check("#s0")
                page.wait_for_timeout(200)
                now2 = page.evaluate("document.querySelector('#routemap [aria-current=step]').dataset.steps")
                if "0" not in now1.split() or "1" not in now2.split():
                    problems.append(f"{where}: the current step's pin does not move on with a tick ({now1} -> {now2})")
                page.uncheck("#s0")
                page.locator("#steps button.n").nth(1).click()           # (a step's number: its pin, opened)
                pop = page.evaluate("(document.querySelector('#routemap .leaflet-popup-content') || {}).textContent || ''")
                if "Kill 8 Mottled Boars" not in pop:
                    problems.append(f"{where}: a step's number does not open its pin ({pop[:60]!r})")
                page.locator("#routemap a.leaflet-popup-close-button").click()
                page.locator("#views button").first.click()
                page.wait_for_timeout(300)
                problems += [f"{where}: {x}" for x in page.evaluate(CHECK) if x.startswith(("contrast", "wider"))]
                if SHOTS:
                    os.makedirs(SHOTS, exist_ok=True)
                    page.screenshot(path=os.path.join(SHOTS, f"plan-route-{scheme}-{w}.png"), full_page=True)
                if any(st != 200 for _, st in tiles) or not tiles:
                    problems.append(f"{where}: tiles asked for {[t for t in tiles if t[1] != 200][:3] or 'none'}")
                if asked:
                    problems.append(f"{where}: the page asks another site: {asked[:3]}")
                problems += [f"{where}: script error or warning: {e}" for e in errors]
                checked += 1
                ctx.close()
            # no tiles: the sketches instead, with no script error
            ctx = browser.new_context(viewport={"width": 390, "height": 900}, locale="en-US")
            ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) or "/map/tiles/" in route.request.url and route.request.url.endswith(".webp") else route.continue_())
            page = ctx.new_page()
            errors = []
            page.on("pageerror", lambda e: errors.append(str(e)))
            page.goto(base + "/plan/#c=" + sample["code"], wait_until="load")
            try:
                page.wait_for_selector("#panels svg.fgmap", timeout=8000)
            except Exception:
                pass
            fb = page.evaluate("[document.getElementById('panels').hidden, document.querySelectorAll('#panels svg.fgmap').length, document.getElementById('sketchnote').hidden, document.getElementById('mapframe').hidden]")
            if fb != [False, 4, False, True]:              # (Durotar, Elwynn Forest, Stormwind City and Nowhere)
                problems.append(f"/plan/ without tiles: the sketches do not show instead ({fb})")
            problems += [f"/plan/ without tiles: script error: {e}" for e in errors]
            checked += 1
            ctx.close()
            # the world map (/map/): the tiles load from this site (and none that isn't there is asked for), the places file
            # is valid, nothing outside is asked, no script error, nothing wider than the screen; ?pins shows the helper
            for w, scheme, lang in ((390, "dark", "en"), (390, "light", "de"), (1280, "light", "en"), (1280, "dark", "en")):
                ctx = browser.new_context(viewport={"width": w, "height": 900}, locale="en-US", color_scheme=scheme, reduced_motion="reduce")
                asked, tiles = [], []
                ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) else route.continue_())
                page = ctx.new_page()
                page.on("request", lambda r: asked.append(r.url) if not r.url.startswith(base) else None)
                page.on("response", lambda r: tiles.append((r.url, r.status)) if "/map/tiles/" in r.url and r.url.endswith(".webp") else None)
                errors = []
                page.on("pageerror", lambda e: errors.append(str(e)))
                page.on("console", lambda m: errors.append(m.text) if m.type in ("error", "warning") else None)
                path = ("/" if lang == "en" else f"/{lang}/") + "map/"
                where = f"{path} {w}px {scheme}"
                page.goto(base + path, wait_until="load")
                try:
                    page.wait_for_selector("#worldmap img.leaflet-tile-loaded", timeout=8000)
                except Exception:
                    problems.append(f"{where}: no map tile was drawn")
                page.wait_for_timeout(400)
                if not any(st == 200 for _, st in tiles):
                    problems.append(f"{where}: no tile request succeeded ({tiles[:3]})")
                if any(st != 200 for _, st in tiles):
                    problems.append(f"{where}: a tile that is not there was asked for: {[t for t in tiles if t[1] != 200][:3]}")
                got = page.evaluate("""async () => {
                  const meta = await (await fetch('/map/tiles/meta.json')).json();
                  const r = await fetch('/map/markers.json'); let list = null; try { list = await r.json(); } catch (e) {}
                  const ok = r.ok && Array.isArray(list) && list.every(m => m && typeof m.name === 'string' && m.name && typeof m.category === 'string'
                    && m.category && Array.isArray(m.coords) && m.coords.length === 2 && m.coords.every(Number.isFinite)
                    && m.coords[0] >= 0 && m.coords[1] >= 0 && m.coords[0] <= meta.width && m.coords[1] <= meta.height
                    && (m.description === undefined || typeof m.description === 'string'));
                  const shown = document.querySelectorAll('#worldmap .map-pin').length;
                  const on = [...document.querySelectorAll('#map-cats .chip[aria-pressed=true]')].map(b => b.dataset.kind);
                  const want = (list || []).filter(m => on.includes(m.category)).length;
                  document.querySelectorAll('#map-cats .chip[aria-pressed=false]').forEach(b => b.click());
                  return [ok, document.getElementById('pins').hidden, [shown, document.querySelectorAll('#worldmap .map-pin').length, on.sort().join('+')],
                          [want, (list || []).length, 'Dungeons+Zones'],
                          getComputedStyle(document.getElementById('map-wait')).display, !!document.querySelector('a[href="https://ko-fi.com/jigrobbulus"][target=_blank][rel="noopener noreferrer"]')];
                }""")
                if not got[0]: problems.append(f"{where}: markers.json is not a valid list of places")
                if not got[1]: problems.append(f"{where}: the pin helper shows without ?pins")
                if got[2] != got[3]: problems.append(f"{where}: places on the map (shown at first, with every kind on, kinds on at first) {got[2]}, wanted {got[3]}")
                if got[4] != "none": problems.append(f"{where}: the map's waiting line still shows")
                if not got[5]: problems.append(f"{where}: no Ko-fi link for OpenMap in the credits")
                problems += [f"{where}: {x}" for x in page.evaluate(CHECK) if x.startswith(("contrast", "wider"))]
                if w == 390:
                    page.goto(base + path + "?pins", wait_until="load")
                    page.wait_for_selector("#worldmap img.leaflet-tile-loaded", timeout=8000)
                    page.locator("#worldmap").click()                          # (its middle: inside the map art)
                    out = page.evaluate("[document.getElementById('pins').hidden, document.getElementById('pins-out').textContent, document.getElementById('pins-copy').disabled]")
                    if out[0] or '"coords": [' not in out[1] or out[2]:
                        problems.append(f"{where}?pins: the pin helper does not give a spot's coords ({out})")
                if SHOTS:
                    os.makedirs(SHOTS, exist_ok=True)
                    page.screenshot(path=os.path.join(SHOTS, f"map-{lang}-{scheme}-{w}.png"), full_page=True)
                if asked:
                    problems.append(f"{where}: the map asks another site: {asked[:3]}")
                problems += [f"{where}: script error or warning: {e}" for e in errors]
                checked += 1
                ctx.close()
            # Guide and Gold: the example route is drawn from its sample code, and the short tour works by keyboard
            for lang in ("en", "de"):
                ctx = browser.new_context(viewport={"width": 390, "height": 800}, locale="en-US", reduced_motion="reduce")
                ctx.route("**/*", lambda route: route.abort() if not route.request.url.startswith(base) else route.continue_())
                page = ctx.new_page()
                errors = []
                page.on("pageerror", lambda e: errors.append(str(e)))
                path = ("/" if lang == "en" else f"/{lang}/") + "guide-and-gold/"
                page.goto(base + path, wait_until="load")
                page.wait_for_timeout(200)
                ex = page.evaluate("[document.getElementById('ex').hidden, document.querySelectorAll('#ex-zones input[type=checkbox]').length, document.querySelectorAll('#ex-zones svg[aria-label] [role=button][aria-label]').length]")
                if ex[0] or ex[1] < 1 or ex[2] < 1:
                    problems.append(f"{path} 390px: the example route is not drawn ({ex})")
                page.focus("#tour-go")
                page.keyboard.press("Enter")
                t1 = page.evaluate("[document.getElementById('tour').hidden, document.activeElement.id, document.querySelectorAll('.tour-on').length, document.getElementById('tour-count').textContent]")
                page.keyboard.press("ArrowRight")
                t2 = page.evaluate("[document.getElementById('tour-say').textContent, document.getElementById('tour-count').textContent]")
                for _ in range(6):
                    page.keyboard.press("ArrowRight")
                last = page.evaluate("document.querySelector('.tour-on') && document.querySelector('.tour-on').id")
                page.keyboard.press("Escape")
                t3 = page.evaluate("[document.getElementById('tour').hidden, document.activeElement.id, document.querySelectorAll('.tour-on').length]")
                if t1[0] or t1[1] != "tour" or t1[2] != 1 or not t1[3] or not t2[0] or t2[1] == t1[3] or last != "ex" or t3 != [True, "tour-go", 0]:
                    problems.append(f"{path}: the tour by keyboard: open {t1}, next {t2}, last {last}, closed {t3}")
                problems += [f"{path}: script error: {e}" for e in errors]
                checked += 1
                ctx.close()
            browser.close()
        httpd.shutdown()
    if problems:
        print("site browser: %d problems" % len(problems))
        for x in problems:
            print("  " + x)
        return 1
    print("site browser: %d pages checked" % checked)
    return 0


sys.exit(main())
