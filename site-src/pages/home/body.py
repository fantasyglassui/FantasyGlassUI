# Home (W2): body.html, with the trailer slot filled in from site-src/site/video/ (see PAGES.md, "The trailer").
#
#   video/trailer.webm, video/trailer.mp4   the loop (either or both; webm is offered first)
#   video/poster.jpg                        its first frame, shown until the video plays (and instead of it)
#   video/captions-<lang>.vtt               optional captions, one file per language
#
# With a video: a muted loop that is fetched only when it scrolls into view, plays by itself unless the reader asks
# for less motion, and has a pause button. With only the poster: the poster. With neither: the drawn Starcut frames.
import hashlib, os, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
VIDEO = os.path.normpath(HERE + '/../../site/video')


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
    track = ''
    if _have(f'captions-{lang}.vtt'):
        track = f'<track kind="captions" srclang="{lang}" src="{_v("captions-" + lang + ".vtt")}" label="[[Captions]]" default>'
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
    # the video's files, at /video/ (nothing is copied while the folder is empty or missing)
    if not os.path.isdir(VIDEO): return
    names = [n for n in os.listdir(VIDEO) if n.endswith(('.webm', '.mp4', '.jpg', '.vtt'))]
    if not names: return
    os.makedirs(out_dir + '/video', exist_ok=True)
    for n in names: shutil.copy(os.path.join(VIDEO, n), out_dir + '/video/' + n)
