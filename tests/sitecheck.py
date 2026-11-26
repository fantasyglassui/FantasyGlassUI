"""The website's pages, and the plan page that is built only on request and never shows up on the public site.
usage: python3 tests/sitecheck.py   ->   "site: 72 pages in 9 languages; plan page hidden"   (exit 0)

Builds the site twice into temporary folders (a plain build, and one with --plan) and checks:
- every page in site-src/lang_meta.py's PAGES exists in all 9 languages at its address (English at /<slug>/, the
  others at /<code>/<slug>/), in its own language, with its own title, description, canonical address, link
  preview (OpenGraph and Twitter), all 9 languages as alternates, a skip link, the header and footer (with the
  contact address and the status line), and no script or tracker from another site;
- the sitemap lists every page in every language, and nothing else;
- the plain build knows nothing of the plan page, the two builds differ only by that page, and the page carries
  no trace of the site."""
import html
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "site-src"))
from lang_meta import PAGES  # noqa: E402
BUILD = os.path.join(ROOT, "site-src", "build_site.py")
LANGS = ["en", "de", "fr", "es", "ru", "pt", "it", "ko", "zh"]
WORD = "plan" + "ner"            # (never spelled out in a source file)


def fail(msg):
    print("site: " + msg)
    sys.exit(1)


def files(top):
    found = {}
    for base, _, names in os.walk(top):
        for n in names:
            p = os.path.join(base, n)
            found[os.path.relpath(p, top).replace(os.sep, "/")] = p
    return found


def text(p):
    return open(p, "rb").read().decode("utf-8", "replace")


def build(out, *flags):
    r = subprocess.run([sys.executable, BUILD, "--out", out, *flags], capture_output=True, text=True, timeout=300)
    if r.returncode != 0:
        fail("the build failed: " + (r.stdout + r.stderr)[-400:])


def status():
    r = subprocess.run(["git", "status", "--porcelain", "docs", "site-src/site"], cwd=ROOT, capture_output=True, text=True)
    return r.stdout.strip()


before = status()
with tempfile.TemporaryDirectory() as tmp:
    A, B = os.path.join(tmp, "A"), os.path.join(tmp, "B")
    build(A)
    build(B, "--plan")
    fa, fb = files(A), files(B)

    # ---- the pages
    SITE = "https://fantasyglassui.com"
    addr = lambda slug, c: ("/" if c == "en" else f"/{c}/") + ("" if slug == "home" else slug + "/")
    titles = {}
    for pg in PAGES:
        for c in LANGS:
            name = addr(pg["slug"], c).lstrip("/") + "index.html"
            if name not in fa:
                fail("no page " + name)
            t = text(fa[name])
            where = name + ": "
            hl = {"zh": "zh-Hans"}.get(c, c)
            if f'<html lang="{hl}"' not in t:
                fail(where + "not marked as " + hl)
            title = re.search(r"<title>([^<]+)</title>", t)
            desc = re.search(r'<meta name="description" content="([^"]+)">', t)
            if not title or not desc:
                fail(where + "no title or description")
            titles.setdefault(pg["slug"], set()).add(html.unescape(desc.group(1)))
            if f'<link rel="canonical" href="{SITE}{addr(pg["slug"], c)}">' not in t:
                fail(where + "its canonical address is not its own")
            for prop in ("og:title", "og:description", "og:image", "og:url", "og:locale"):
                if f'<meta property="{prop}" content="' not in t:
                    fail(where + "no " + prop)
            for n in ("twitter:card", "twitter:title", "twitter:description", "twitter:image"):
                if f'<meta name="{n}" content="' not in t:
                    fail(where + "no " + n)
            alts = re.findall(r'<link rel="alternate" hreflang="([^"]+)" href="([^"]+)">', t)
            if sorted(h for h, _ in alts) != sorted([{"zh": "zh-Hans"}.get(x, x) for x in LANGS] + ["x-default"]):
                fail(where + "its alternates are not the 9 languages and x-default")
            if any(u != SITE + addr(pg["slug"], {"zh-Hans": "zh"}.get(h, "en" if h == "x-default" else h)) for h, u in alts):
                fail(where + "an alternate points at another page")
            for need in ('<a class="skip" href="#main">', '<header class="site-head">', '<main id="main"', '<footer class="site-foot">',
                         'mailto:email-forwarding@fantasyglassui.com', 'class="status"', 'aria-current="page"' if pg.get("top", True) else "<nav"):
                if need not in t:
                    fail(where + "lacks " + need)
            for src in re.findall(r'<script[^>]* src="([^"]+)"', t):
                if not src.startswith("/"):
                    fail(where + "loads a script from " + src)
            for bad in ("goatcounter", "zgo.at", "google-analytics", "googletagmanager", "[[", "{{"):
                if bad in t:
                    fail(where + "contains " + bad)
    for slug, ts in titles.items():
        if len(ts) != len(LANGS):
            fail(slug + ": the languages share one description (" + str(sorted(ts)) + ")")
    sm = text(fa["sitemap.xml"])
    locs = re.findall(r"<loc>([^<]+)</loc>", sm)
    want = [SITE + addr(pg["slug"], c) for pg in PAGES for c in LANGS]
    if sorted(locs) != sorted(want):
        fail("the sitemap lists " + str(sorted(set(locs) ^ set(want))[:6]))
    for name, p in fa.items():
        if name.endswith((".html", ".js")) and re.search(r"goatcounter|zgo\.at", text(p)):
            fail(name + " counts visits")

    words = json.load(open(os.path.join(ROOT, "site-src", "plan", "words.json"), encoding="utf-8"))
    for phrase, tr in words.items():
        if sorted(tr) != sorted(LANGS) or any(not isinstance(v, str) or not v.strip() for v in tr.values()):
            fail("words.json: all 9 languages for " + phrase)
    # a plain build: no plan folder, no code header, no link to it, none of the page's own words
    if any(n.startswith("plan/") for n in fa):
        fail("a plain build has a plan/ folder")
    # The scan is of whole English phrases of words.json. Three are single everyday words that the public site already uses
    # for its own reasons (so they prove nothing about the page); every other phrase must be absent from a plain build.
    COMMON = {"Time", "Levels", "Language"}
    english = [tr["en"] for tr in words.values() if tr["en"] not in COMMON]
    for name, p in fa.items():
        t = text(p)
        for bad in ["SUIP1", "/plan/"] + english:
            if bad in t:
                fail("a plain build's " + name + " contains " + repr(bad))
    # the docs folder's own files (the i18n tables among them) are checked the same way
    docs = files(os.path.join(ROOT, "docs"))
    for name, p in docs.items():
        if name.lower().endswith((".webp", ".png", ".jpg", ".ico")):
            continue
        t = text(p)
        for bad in ["SUIP1", "/plan/"] + english:
            if bad in t:
                fail("docs/" + name + " contains " + repr(bad))
    # the two builds differ by the page alone
    if sorted(set(fb) - set(fa)) != ["plan/index.html"] or set(fa) - set(fb):
        fail("the --plan build adds only plan/index.html: " + str(sorted(set(fb) ^ set(fa))))
    for name in fa:
        if open(fa[name], "rb").read() != open(fb[name], "rb").read():
            fail(name + " differs between the builds")
    # the page
    page = text(fb["plan/index.html"])
    if not re.search(r'<meta name="robots" content="noindex, nofollow">', page):
        fail("the page has no noindex meta")
    for bad in ["ld+json", "hreflang", "canonical", "goatcounter", "zgo.at", "<script src", "<link", "sendBeacon", "fetch(", "XMLHttpRequest", "WebSocket"]:
        if bad in page:
            fail("the page contains " + bad)
    if "https://" in page.replace("fantasyglassui.com", ""):
        fail("the page names an address")
    # nothing links to it, and nothing lists it
    for name, p in fb.items():
        if name == "plan/index.html":
            continue
        t = text(p)
        if re.search(r'["\'(=]/?plan/?["\')> ]|/plan/', t) and name.endswith((".html", ".xml", ".txt")):
            fail(name + " links to the page")
    for name in ("sitemap.xml",):
        if "plan" in text(fb[name]):
            fail(name + " lists the page")
    robots = os.path.join(ROOT, "docs", "robots.txt")
    if os.path.exists(robots) and "plan" in text(robots):
        fail("robots.txt mentions the page")
# the page's own source never says the other word
for name, p in files(os.path.join(ROOT, "site-src", "plan")).items():
    if WORD in text(p).lower():
        fail("site-src/plan/" + name + " says " + WORD)
if WORD in text(os.path.join(ROOT, "site-src", "plan_page.py")).lower():
    fail("plan_page.py says " + WORD)
if status() != before or before:
    fail("docs or site-src/site changed: " + (status() or before))
print("site: %d pages in %d languages; plan page hidden" % (len(PAGES) * len(LANGS), len(LANGS)))
