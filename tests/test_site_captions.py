"""The trailer's captions on Home (site-src/pages/home/body.py, from site-src/site/video/captions.json): one source of
cue times and English lines, translated through site_tr.py, makes a valid WebVTT file in each of the 9 languages, and
a <track> for each beside the video with the page's own language on by default. An empty cue list makes nothing.
Run alone with: python3 -m pytest tests -q -k site_captions"""
import importlib.util
import json
import os
import re

import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BODY = os.path.join(ROOT, "site-src", "pages", "home", "body.py")
LANGS = ["en", "de", "fr", "es", "ru", "pt", "it", "ko", "zh"]
# two lines the site already has in every language (any phrase in site_tr.py would do)
SAMPLE = {"_translate": ["text"], "cues": [
    {"start": 0, "end": 2.5, "text": "Pick a theme, see it change"},
    {"start": 2.5, "end": 61.25, "text": "Download on CurseForge"},
]}
TIME = r"(\d{2}):(\d{2}):(\d{2})\.(\d{3})"


def module():
    spec = importlib.util.spec_from_file_location("home_body", BODY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def write(tmp_path, data):
    p = tmp_path / "captions.json"
    p.write_text(json.dumps(data), encoding="utf-8")
    return str(p)


def seconds(m):
    h, mi, s, ms = (int(x) for x in m)
    return h * 3600 + mi * 60 + s + ms / 1000


def check_vtt(text, n):
    """A WebVTT file: the header, then n cues, each an id, a timing line and its words, in order and not overlapping."""
    assert text.startswith("WEBVTT\n\n"), text[:20]
    blocks = [b for b in text[len("WEBVTT\n\n"):].split("\n\n") if b.strip()]
    assert len(blocks) == n, blocks
    last = 0.0
    out = []
    for i, b in enumerate(blocks, 1):
        lines = b.strip("\n").split("\n")
        assert lines[0] == str(i)
        m = re.fullmatch(TIME + " --> " + TIME, lines[1])
        assert m, lines[1]
        a, z = seconds(m.groups()[:4]), seconds(m.groups()[4:])
        assert last <= a < z
        last = z
        assert len(lines) >= 3 and all(x.strip() and "-->" not in x for x in lines[2:]), lines
        out.append((a, z, "\n".join(lines[2:])))
    return out


def test_site_captions_all_languages(tmp_path):
    """A sample captions.json gives a valid WebVTT file in all 9 languages, with the same times and the words translated."""
    mod = module()
    files = mod.caption_files(write(tmp_path, SAMPLE))
    assert sorted(files) == sorted(LANGS)
    cues = {lang: check_vtt(files[lang], 2) for lang in LANGS}
    assert cues["en"] == [(0.0, 2.5, "Pick a theme, see it change"), (2.5, 61.25, "Download on CurseForge")]
    assert files["en"].split("\n")[3] == "00:00:00.000 --> 00:00:02.500"
    assert files["en"].split("\n")[7] == "00:00:02.500 --> 00:01:01.250"
    from site_tr import SITE
    for i, lang in enumerate(LANGS[1:]):
        assert [c[:2] for c in cues[lang]] == [c[:2] for c in cues["en"]]
        assert [c[2] for c in cues[lang]] == [SITE[x["text"]][i] for x in SAMPLE["cues"]]


def test_site_captions_tracks(tmp_path, monkeypatch):
    """With a trailer and captions, the video has a track per language, the page's own language on by default."""
    mod = module()
    (tmp_path / "trailer.webm").write_bytes(b"\x1a\x45\xdf\xa3")
    write(tmp_path, SAMPLE)
    monkeypatch.setattr(mod, "VIDEO", str(tmp_path))
    for lang in ("en", "de", "zh"):
        html = mod.trailer(lang)
        tracks = re.findall(r"<track ([^>]*)>", html)
        assert len(tracks) == 9, html
        assert all('kind="captions"' in t and re.search(r'src="/video/captions-[a-z]{2}\.vtt\?v=[0-9a-f]{10}"', t) for t in tracks)
        on = [t for t in tracks if t.endswith(" default")]
        assert len(on) == 1 and f'srclang="{"zh-Hans" if lang == "zh" else lang}"' in on[0], on
        assert html.index("<track") > html.index("<video")
    out = tmp_path / "out"
    mod.extra(str(out), {})
    assert sorted(os.listdir(out / "video")) == sorted([f"captions-{c}.vtt" for c in LANGS] + ["trailer.webm"])


def test_site_captions_empty(tmp_path, monkeypatch):
    """The cue list as it ships (empty): no caption files and no track; the real captions.json is valid and empty."""
    mod = module()
    assert mod.caption_files(write(tmp_path, {"_translate": ["text"], "cues": []})) == {}
    shipped = json.load(open(os.path.join(ROOT, "site-src", "site", "video", "captions.json"), encoding="utf-8"))
    assert shipped["cues"] == [] and shipped["_translate"] == ["text"]
    (tmp_path / "trailer.webm").write_bytes(b"\x1a\x45\xdf\xa3")
    monkeypatch.setattr(mod, "VIDEO", str(tmp_path))
    assert "<track" not in mod.trailer("en")


def test_site_captions_refuses_bad_cues(tmp_path):
    """A cue that ends before it starts, overlaps the one before, has no words or has no translation stops the build."""
    mod = module()
    for cue in ({"start": 3, "end": 2, "text": "Download on CurseForge"},
                {"start": 1, "end": 2, "text": ""},
                {"start": 1, "end": 2, "text": "A line nobody has translated yet"}):
        with pytest.raises(SystemExit):
            mod.caption_files(write(tmp_path, {"cues": [cue]}))
    with pytest.raises(SystemExit):
        mod.caption_files(write(tmp_path, {"cues": [{"start": 0, "end": 2, "text": "Download on CurseForge"},
                                                     {"start": 1, "end": 3, "text": "Pick a theme, see it change"}]}))
