"""The website's pages, the plan page and the feed of releases.
usage: python3 tests/sitecheck.py   ->   "site: 126 pages in 9 languages; plan page published; feed of 20 releases"   (exit 0)

Builds the site into a temporary folder and checks:
- every page in site-src/lang_meta.py's PAGES exists in all 9 languages at its address (English at /<slug>/, the
  others at /<code>/<slug>/), in its own language, with its own title, description, canonical address, link
  preview (OpenGraph and Twitter), all 9 languages as alternates, a skip link, the header and footer (with the
  contact address and the status line), and no script or tracker from another site;
- the sitemap lists every page in every language and the plan page, and nothing else;
- the plan page (/plan/) is built, can be found (no noindex, in the sitemap, linked from Guide and Gold in every
  language), and makes no request to any other site;
- the feed of releases (/feed.xml) is RSS with every release's link pointing at its place on the Changelog, and
  every page names it in its head and links it in its footer."""
import html
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "site-src"))
from lang_meta import PAGES  # noqa: E402
BUILD = os.path.join(ROOT, "site-src", "build_site.py")
LANGS = ["en", "de", "fr", "es", "ru", "pt", "it", "ko", "zh"]


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
    A = os.path.join(tmp, "A")
    build(A)
    fa = files(A)

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
                         'mailto:email-forwarding@fantasyglassui.com', 'class="status"', 'aria-current="page"' if pg.get("top", True) else "<nav",
                         '<link rel="alternate" type="application/rss+xml" title="Fantasy Glass UI releases" href="/feed.xml">', '<a href="/feed.xml"'):
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
    want = [SITE + addr(pg["slug"], c) for pg in PAGES for c in LANGS] + [SITE + "/plan/"]
    if sorted(locs) != sorted(want):
        fail("the sitemap lists " + str(sorted(set(locs) ^ set(want))[:6]))
    for name, p in fa.items():
        if name.endswith((".html", ".js")) and re.search(r"goatcounter|zgo\.at", text(p)):
            fail(name + " counts visits")

    words = json.load(open(os.path.join(ROOT, "site-src", "plan", "words.json"), encoding="utf-8"))
    for phrase, tr in words.items():
        if sorted(tr) != sorted(LANGS) or any(not isinstance(v, str) or not v.strip() for v in tr.values()):
            fail("words.json: all 9 languages for " + phrase)

    # ---- the plan page: built, found, and private
    if "plan/index.html" not in fa:
        fail("no plan page (plan/index.html)")
    page = text(fa["plan/index.html"])
    if "noindex" in page:
        fail("the plan page is hidden from search engines")
    for bad in ["ld+json", "goatcounter", "zgo.at", "<script src", "<link", "sendBeacon", "fetch(", "XMLHttpRequest", "WebSocket"]:
        if bad in page:
            fail("the plan page contains " + bad)
    if "https://" in page.replace("fantasyglassui.com", "") or "http://" in page:
        fail("the plan page names another site")
    if '<meta name="referrer" content="no-referrer">' not in page:
        fail("the plan page sends a referrer")
    for c in LANGS:
        g = text(fa[addr("guide-and-gold", c).lstrip("/") + "index.html"])
        if 'href="/plan/"' not in g:
            fail(addr("guide-and-gold", c) + " does not link the plan page")
    robots = os.path.join(ROOT, "docs", "robots.txt")
    if os.path.exists(robots) and "plan" in text(robots):
        fail("robots.txt mentions the plan page")

    # ---- the feed of releases
    if "feed.xml" not in fa:
        fail("no feed.xml")
    try:
        rss = ET.parse(fa["feed.xml"]).getroot()
    except ET.ParseError as e:
        fail("feed.xml is not XML: " + str(e))
    items = rss.findall("./channel/item")
    if rss.tag != "rss" or not items or rss.find("./channel/title") is None:
        fail("feed.xml is not an RSS feed with releases")
    log = text(fa["changelog/index.html"])
    for it in items:
        link = it.findtext("link") or ""
        m = re.fullmatch(re.escape(SITE) + r"/changelog/#(v[\w-]+)", link)
        if not m or f'id="{m.group(1)}"' not in log or it.findtext("guid") != link or not it.findtext("title"):
            fail("feed.xml: an item does not point at its release on the Changelog: " + link)
    pend = re.search(r'class="ver card pending" id="(v[\w-]+)"', log)       # (the 13.0 stand-in, until CHANGELOG.md has 13.0)
    if pend and any((it.findtext("link") or "").endswith("#" + pend.group(1)) for it in items):
        fail("feed.xml lists a release that is not out yet")
if status() != before or before:
    fail("docs or site-src/site changed: " + (status() or before))
print("site: %d pages in %d languages; plan page published; feed of %d releases" % (len(PAGES) * len(LANGS), len(LANGS), len(items)))
