"""The website (site-src/ -> docs/). Run alone with: python3 -m pytest tests -q -k site"""
import os
import re
import subprocess
import sys

TESTS = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(TESTS)
SRC = os.path.join(ROOT, "site-src")
sys.path.insert(0, SRC)


def run(*args, timeout=900):
    p = subprocess.run([sys.executable, *args], cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout + p.stderr


def test_site_words():
    """Every word the site needs is in site_tr.py in all 8 other languages, with the same markup (make_i18n.py)."""
    code, out = run(os.path.join(SRC, "make_i18n.py"))
    assert code == 0, out[-3000:]
    assert "site phrases without a translation: []" in out, out[-3000:]


def test_site_german_says_du():
    """The site's German speaks to the player as "du", never "Sie" or "Ihr"."""
    from site_tr import SITE, THEMES
    formal = [v[0] for v in list(SITE.values()) + list(THEMES.values())
              if re.search(r"\b(Sie|Ihnen|Ihr|Ihre|Ihren|Ihrem|Ihrer|Euer|Eure|Euch)\b", v[0])]
    assert not formal, formal[:5]


def test_site_pages():
    """Every page in every language, its cards, the sitemap, no outside scripts, and the plan page hidden (tests/sitecheck.py)."""
    code, out = run(os.path.join(TESTS, "sitecheck.py"))
    assert code == 0, out[-3000:]


def test_site_in_a_browser():
    """Every page at 390 and 1280 px: contrast, focus, landmarks, width, old links and the shared controls (tests/sitebrowser.py)."""
    code, out = run(os.path.join(TESTS, "sitebrowser.py"))
    assert code == 0, out[-4000:]


def test_site_links_keep_their_quotes():
    """No link or image in docs/ has its address written &quot;...&quot; (a translated phrase's own HTML escaped as text)."""
    docs = os.path.join(ROOT, "docs")
    bad = []
    for base, _, names in os.walk(docs):
        for n in names:
            if not n.endswith((".html", ".xml")):
                continue
            p = os.path.join(base, n)
            text = open(p, encoding="utf-8").read()
            for m in re.finditer(r'\b(?:href|src)=&quot;', text):
                bad.append(os.path.relpath(p, docs) + ": " + text[m.start():m.start() + 60])
    assert not bad, f"{len(bad)} broken: " + " | ".join(bad[:5])
