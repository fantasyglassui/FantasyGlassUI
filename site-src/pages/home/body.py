# Home (W2): body.html, with the trailer slot filled in from site-src/site/video/ (see PAGES.md, "The trailer").
#
#   video/trailer.webm, video/trailer.mp4   the loop (either or both; webm is offered first)
#   video/poster.jpg                        its first frame, shown until the video plays (and instead of it)
#   video/captions.json                     the captions: cue times and English lines, translated through
#                                           site_tr.py; the build writes /video/captions-<lang>.vtt for all 9
#                                           languages from it (none while its cue list is empty)
#
# With a video: a muted loop that is fetched only when it scrolls into view, plays by itself unless the reader asks
# for less motion, and has a pause button. With only the poster: the poster. With neither: the drawn Starcut frames.
import hashlib, json, os, re, shutil, sys

HERE = os.path.dirname(os.path.abspath(__file__))
VIDEO = os.path.normpath(HERE + '/../../site/video')
LANGS = ['en', 'de', 'fr', 'es', 'ru', 'pt', 'it', 'ko', 'zh']
SRCLANG = {'zh': 'zh-Hans'}
sys.path.insert(0, os.path.normpath(HERE + '/../..'))     # (site_tr.py and lang_meta.py, when this file is loaded alone)


def _have(name):
    return os.path.isfile(os.path.join(VIDEO, name))


def _v(name):
    # a cache-buster from the file's content, so a new cut is fetched at once
    return '/video/' + name + '?v=' + hashlib.sha1(open(os.path.join(VIDEO, name), 'rb').read()).hexdigest()[:10]


def _jpeg_size(path):
    b = open(path, 'rb').read()
    i = 2
    while i < len(b) - 9:
        if b[i] != 0xFF: i += 1; continue
        m = b[i + 1]
        if m in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):
            return int.from_bytes(b[i + 7:i + 9], 'big'), int.from_bytes(b[i + 5:i + 7], 'big')
        i += 2 + int.from_bytes(b[i + 2:i + 4], 'big')
    return 1280, 720


STAGE = '''<div class="stage cut" role="img" aria-label="[[The Starcut unit frames, drawn]]">
        <span class="label">[[Starcut frames]]</span>
        <div class="uf">
          <div class="portrait" aria-hidden="true"><i>K</i></div>
          <div>
            <div class="who"><span>Kaelith</span><span>60</span></div>
            <div class="glow" style="--c:#3fcf7a"><div class="bar" style="--v:94%"><div class="fill"></div><div class="num">94%</div></div></div>
            <div class="glow" style="--c:#4f8dff"><div class="bar thin" style="--v:71%"><div class="fill"></div></div></div>
          </div>
        </div>
        <div class="uf">
          <div class="portrait foe" aria-hidden="true"><i>O</i></div>
          <div>
            <div class="who"><span>Onyxia</span><span>??</span></div>
            <div class="glow" style="--c:#e2574c"><div class="bar" style="--c:#e2574c;--v:72%"><div class="fill"></div><div class="num">72%</div></div></div>
            <div class="glow" style="--c:#f0a24b"><div class="bar cast" style="--v:42%"><div class="fill"></div><div class="num">Flame Breath</div></div></div>
          </div>
        </div>
      </div>'''

PLAY = '<svg class="i-play" viewBox="0 0 16 16" aria-hidden="true"><path d="M4 2.5v11l9.5-5.5z" fill="currentColor"/></svg>'
PAUSE = '<svg class="i-pause" viewBox="0 0 16 16" aria-hidden="true"><rect x="3" y="2" width="3.5" height="12" fill="currentColor"/><rect x="9.5" y="2" width="3.5" height="12" fill="currentColor"/></svg>'


# ---- the captions: one source (video/captions.json), a WebVTT file per language ----------------------------------
#   {"_translate": ["text"], "cues": [{"start": 0.0, "end": 3.2, "text": "English words"}, ...]}
# Times are seconds from the start of the trailer. Each "text" is translated through site_tr.py like every other
# phrase (keys_all.py lists them); a line break in a cue is written "\n".
def cues(path=None):
    path = path or os.path.join(VIDEO, 'captions.json')
    if not os.path.isfile(path): return []
    d = json.load(open(path, encoding='utf-8'))
    out, last = [], 0.0
    for n, c in enumerate(d.get('cues') or [], 1):
        a, b, t = c.get('start'), c.get('end'), c.get('text')
        if not all(isinstance(x, (int, float)) and not isinstance(x, bool) for x in (a, b)) or not (0 <= a < b):
            raise SystemExit(f'captions.json: cue {n} needs a start and an end in seconds, the end after the start')
        if a < last:
            raise SystemExit(f'captions.json: cue {n} starts before the cue above it ends')
        if not isinstance(t, str) or not t.strip() or '-->' in t or '[' '[' in t or ']' ']' in t:     # (the markers written apart, so keys_all.py does not take them for a phrase)
            raise SystemExit(f'captions.json: cue {n} needs a "text" (with no "-->" in it)')
        out.append({'start': float(a), 'end': float(b), 'text': t.strip()})
        last = float(b)
    return out


def _stamp(sec):
    ms = int(round(sec * 1000))
    return '%02d:%02d:%02d.%03d' % (ms // 3600000, ms // 60000 % 60, ms // 1000 % 60, ms % 1000)


def vtt(cue_list, tr):
    """The WebVTT file for one language: tr(english) gives the words in it."""
    def clean(t):
        t = t.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        return '\n'.join(x.strip() for x in t.split('\n') if x.strip())
    lines = ['WEBVTT', '']
    for n, c in enumerate(cue_list, 1):
        lines += [str(n), f'{_stamp(c["start"])} --> {_stamp(c["end"])}', clean(tr(c['text'])), '']
    return '\n'.join(lines)


def translator(lang):
    # the words of site_tr.py in one language (English as written); stops on a line that has no translation
    if lang == 'en': return lambda t: t
    from site_tr import SITE
    i = LANGS.index(lang) - 1
    def tr(t):
        key = re.sub(r'\s+', ' ', t).strip()
        if key not in SITE: raise SystemExit(f'captions.json: no translation in site_tr.py for {key!r}')
        return SITE[key][i]
    return tr


def caption_files(path=None):
    """{lang: the text of captions-<lang>.vtt} for all 9 languages, or {} while the cue list is empty."""
    c = cues(path)
    return {lang: vtt(c, translator(lang)) for lang in LANGS} if c else {}


def tracks(lang, files):
    # one <track> per language, the page's own language shown by default
    from lang_meta import LANG_NAMES
    return ''.join(f'<track kind="captions" srclang="{SRCLANG.get(c, c)}" label="{LANG_NAMES[c]}" '
                   f'src="/video/captions-{c}.vtt?v={hashlib.sha1(files[c].encode("utf-8")).hexdigest()[:10]}"'
                   + (' default' if c == lang else '') + '>' for c in LANGS if c in files)


def trailer(lang):
    webm, mp4, poster = _have('trailer.webm'), _have('trailer.mp4'), _have('poster.jpg')
    if not (webm or mp4):
        if not poster:
            return STAGE
        w, h = _jpeg_size(os.path.join(VIDEO, 'poster.jpg'))
        return (f'<figure class="trailer"><div class="tv cut"><img src="{_v("poster.jpg")}" width="{w}" height="{h}" '
                f'alt="[[A still from the 13.0 trailer]]" fetchpriority="high"></div></figure>')
    w, h = _jpeg_size(os.path.join(VIDEO, 'poster.jpg')) if poster else (1280, 720)
    sources = ''.join(f' data-{kind}="{_v("trailer." + kind)}"' for kind, ok in (('webm', webm), ('mp4', mp4)) if ok)
    track = tracks(lang, caption_files())
    return (f'<figure class="trailer" id="trailer">\n'
            f'        <div class="tv cut" style="aspect-ratio:{w}/{h}">\n'
            f'          <video id="tv" muted loop playsinline preload="none" width="{w}" height="{h}"'
            + (f' poster="{_v("poster.jpg")}"' if poster else '') + f'{sources} aria-label="[[The 13.0 trailer, without sound]]">{track}</video>\n'
            f'          <button class="tv-btn" id="tvbtn" type="button" data-play="[[Play the trailer]]" data-pause="[[Pause the trailer]]">'
            f'{PLAY}{PAUSE}<span class="sr-only" id="tvword">[[Play the trailer]]</span></button>\n'
            f'        </div>\n'
            f'        <figcaption>[[The 13.0 trailer: a short loop without sound.]]</figcaption>\n'
            f'      </figure>')


def body(ctx):
    # (the build translates the marked words in what this returns, the slot's among them)
    return open(HERE + '/body.html', encoding='utf-8').read().replace('<!--TRAILER-->', trailer(ctx.lang))


def extra(out_dir, values):
    # the video's files, at /video/, and the captions made from captions.json (nothing while there is none)
    if not os.path.isdir(VIDEO): return
    names = [n for n in os.listdir(VIDEO) if n.endswith(('.webm', '.mp4', '.jpg'))]
    files = caption_files()
    if not names and not files: return
    os.makedirs(out_dir + '/video', exist_ok=True)
    for n in names: shutil.copy(os.path.join(VIDEO, n), out_dir + '/video/' + n)
    for lang, text in files.items(): open(f'{out_dir}/video/captions-{lang}.vtt', 'w', encoding='utf-8').write(text)
