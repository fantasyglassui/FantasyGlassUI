"""Every page of the website in a real browser (Playwright's Chromium), at a phone's width (390 px) and a desktop's (1280 px).
usage: python3 tests/sitebrowser.py [--shots DIR] [--quick]   ->   "site browser: N pages checked"   (exit 0)

The site is built into a temporary folder and served from this computer. Every page, in English (dark and light) and
in German, is checked for: a skip link that shows when it gets focus; a header, navigation, main part and footer, and
one h1; a visible focus ring; AA contrast for every piece of text on a plain background (4.5:1, or 3:1 for large text;
text over a screenshot is left to the eye); no page wider than the screen; no script from another site; and no
script error. The other languages are checked at 390 px for width. The plan page (/plan/) is checked at 390 px: a
plan code pasted shows its steps, in German too, with no script error and nothing wider than the screen. --shots DIR
saves Home and Get started, dark and light, at both widths. --quick checks English only. Needs Python's playwright with its Chromium; when that is
missing it says so and exits 0 (the other site checks still run)."""
import functools
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
  document.querySelectorAll("img").forEach(i => { if (!i.hasAttribute("alt")) bad.push("an image with no alt: " + i.src); if (!i.getAttribute("width") && !i.closest(".thumb")) bad.push("an image with no size: " + i.src); });
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
            if page.evaluate("document.getElementById('title').textContent") in ("", "Quest guide"):
                problems.append("/plan/: the page's language switch does nothing")
            problems += [f"/plan/: script error: {e}" for e in errors]
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
