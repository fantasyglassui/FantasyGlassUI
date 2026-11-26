"""The plan page is built only on request and never shows up on the public site.
usage: python3 tests/sitecheck.py   ->   "site: plan page hidden"   (exit 0)

Builds the site twice into temporary folders (a plain build, and one with --plan) and checks that the plain one
knows nothing of the page, the two differ only by the page itself, and the page carries no trace of the site."""
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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
print("site: plan page hidden")
