"""The Changelog page's 13.0 entry and the feed of releases (site-src/pages/changelog/body.py).
Until CHANGELOG.md has a 13.0 heading, the page shows a marked stand-in badged "Coming soon" and the feed leaves it
out; once CHANGELOG.md has it, the real notes take its place on the page and in the feed.
Run alone with: python3 -m pytest tests -q -k site_changelog"""
import importlib.util
import os
import re
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BODY = os.path.join(ROOT, "site-src", "pages", "changelog", "body.py")
OLD = "# Changelog\n\nThe releases.\n\n## 12.4.1\n\n**Fixed**\n- A fix.\n\n## 12.4.0\n\n- Scan prices.\n"
NEW = "# Changelog\n\nThe releases.\n\n## 13.0.0\n\n**New: Guide and Gold**\n- The route planner.\n\n" + OLD.split("\n\n", 2)[2]


def module():
    spec = importlib.util.spec_from_file_location("changelog_body", BODY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class Ctx:
    def __init__(self, repo, lang="en"):
        self.repo, self.lang = repo, lang


def repo(tmp_path, text):
    (tmp_path / "CHANGELOG.md").write_text(text, encoding="utf-8")
    return str(tmp_path)


def test_site_changelog_13_stand_in(tmp_path):
    """Without 13.0 in CHANGELOG.md: the marked stand-in at the top, 12.4.1 still "Current"."""
    html = module().body(Ctx(repo(tmp_path, OLD)))
    secs = re.findall(r'<section class="([^"]+)" id="(v[\w-]+)"', html)
    assert secs[0] == ("ver card pending", "v13-0-0"), secs
    assert secs[1] == ("ver card", "v12-4-1"), secs
    first = html.split('id="v12-4-1"')[0]
    assert "[[Coming soon]]" in first and "[[Current]]" not in first
    assert "[[Current]]" in html.split('id="v12-4-1"')[1].split('id="v12-4-0"')[0]


def test_site_changelog_13_from_changelog(tmp_path):
    """With 13.0.0 in CHANGELOG.md: no stand-in, the real notes, 13.0.0 "Current"."""
    html = module().body(Ctx(repo(tmp_path, NEW)))
    assert "pending" not in html and "[[Coming soon]]" not in html
    assert html.count('id="v13-0-0"') == 1 and "The route planner." in html
    assert "[[Current]]" in html.split('id="v13-0-0"')[1].split('id="v12-4-1"')[0]


def test_site_changelog_feed(tmp_path):
    """The feed is RSS, newest first, each item linking its place on the Changelog; the stand-in is never in it."""
    mod = module()
    for text, first in ((OLD, "12.4.1"), (NEW, "13.0.0")):
        rss = ET.fromstring(mod.feed(repo(tmp_path, text)).encode("utf-8"))
        items = rss.findall("./channel/item")
        assert items[0].findtext("title") == "Fantasy Glass UI " + first
        assert [i.findtext("link") for i in items] == [i.findtext("guid") for i in items]
        assert all(re.fullmatch(r"https://fantasyglassui\.com/changelog/#v[\d-]+", i.findtext("link")) for i in items)
        assert len(items) == text.count("\n## ")
