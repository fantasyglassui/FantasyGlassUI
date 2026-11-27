# Build the public site (docs/, served by GitHub Pages) from site-src/.
#
# Every page in lang_meta.PAGES is built in every language: English at /<slug>/ (Home at /), the others at
# /<code>/<slug>/. Each page is the shared shell (head, header, footer: this file) around the page's own body
# (site-src/pages/<slug>/). The build translates the body and fills in the shared values; see site-src/PAGES.md.
#
#   python3 site-src/build_site.py              -> docs/
#   python3 site-src/build_site.py --out DIR    -> DIR (docs and site-src/site are left alone)
#   (the plan page, /plan/, is built every time by plan_page.py; --plan is still accepted and changes nothing)
import glob, gzip, hashlib, html, importlib.util, json, os, re, shutil, subprocess, sys

S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
REPO = os.path.normpath(S + '/..')
D = S + '/site'
PAGES_DIR = S + '/pages'
_args = sys.argv[1:]
OUT = None
if '--out' in _args:
    _i = _args.index('--out')
    if _i + 1 >= len(_args) or _args[_i + 1].startswith('--'): sys.exit('build_site.py: --out needs a folder: --out DIR')
    OUT = os.path.abspath(_args[_i + 1])
R = OUT or os.path.normpath(S + '/../docs')

from lang_meta import META, OG_LOCALE, PAGES, LANG_NAMES, LD
from site_tr import SITE

SITE_URL = 'https://fantasyglassui.com/'
CODES = ['en', 'de', 'fr', 'es', 'ru', 'pt', 'it', 'ko', 'zh']
HREFLANG = {'zh': 'zh-Hans'}
CURSEFORGE = 'https://www.curseforge.com/wow/addons/fantasy-glass-ui'
DISCORD = 'https://discord.gg/qeSMwQWyPR'
GITHUB = 'https://github.com/fantasyglassui/FantasyGlassUI'
CONTACT = 'email-forwarding@fantasyglassui.com'
SLUGS = [p['slug'] for p in PAGES]
e = lambda x: html.escape(str(x), quote=True)


def read(p): return open(p, encoding='utf-8').read()


# ---- the shared values: read from the add-on and the repository, never typed in --------------------------------
def addon_version():
    m = re.search(r'^## Version: *(\S+)', read(REPO + '/FantasyGlassUI/FantasyGlassUI.toc'), re.M)
    return m.group(1)


def last_update():
    # the day the releases file (CHANGELOG.md) last changed, from git; None when git cannot say
    try:
        r = subprocess.run(['git', 'log', '-1', '--format=%cs', '--', 'CHANGELOG.md'], cwd=REPO, capture_output=True, text=True, timeout=30)
        d = r.stdout.strip()
        return d if re.fullmatch(r'\d{4}-\d\d-\d\d', d) else None
    except Exception:
        return None


def forever_build():
    # the client the add-on is checked against (tests/forever_api.json.gz: "1.60.1 (70938) dumps, ...")
    b = json.load(gzip.open(REPO + '/tests/forever_api.json.gz')).get('build', '')
    m = re.match(r'(\d+(?:\.\d+)+) \((\d+)\)', b)
    return f'{m.group(1)} ({m.group(2)})' if m else None


FEATURES = json.load(open(D + '/features.json', encoding='utf-8'))
DATA_JS = read(D + '/data.js')
THEMES = json.loads(re.search(r'window.FG_THEMES=(\[.*?\]);', DATA_JS, re.S).group(1))
VERSION = addon_version()
VALUES = {
    'version': VERSION,
    'version_short': '.'.join(VERSION.split('.')[:2]),
    'themes': str(len(THEMES)),
    'switches': str(sum(len(s['items']) for s in FEATURES['sections'])),
    'commands': str(len(FEATURES['commands'])),
    'updated': last_update() or '',
    'forever': forever_build() or '',
    'curseforge': CURSEFORGE, 'discord': DISCORD, 'github': GITHUB, 'contact': CONTACT,
}


# ---- words -------------------------------------------------------------------------------------------------------
MISSING = set()


def T(s, code):
    """The site's words in a language: site_tr.py (English as written)."""
    s = re.sub(r'\s+', ' ', s).strip()
    if code == 'en': return s
    v = SITE.get(s)
    if not v:
        MISSING.add(s); return s
    return v[CODES.index(code) - 1]


def F(s, code, *args):
    out, it = T(s, code), iter(args)
    return re.sub(r'%[sd]', lambda m: str(next(it)), out)


def quote_text(t):
    # a " in a translation's words is written &quot; (the phrase may sit in an attribute); a " inside one of its own
    # tags (<a href="...">) is left as it is, so the tag keeps its attributes
    return re.sub(r'"(?![^<>]*>)', '&quot;', t)


def translate(text, code):
    # [[English words]] -> the words in this language (quote_text: the quotes of its words, not of its tags)
    return re.sub(r'\[\[(.+?)\]\]', lambda m: quote_text(T(m.group(1), code)), text, flags=re.S)


def page_url(slug, code):
    p = '' if slug == 'home' else slug + '/'
    return '/' + p if code == 'en' else f'/{code}/{p}'


def fill(text, code, slug):
    # {{name}}: a shared value; {{url:slug}}: a page's address in this language; {{status}}: the status line
    def one(m):
        k = m.group(1)
        if k.startswith('url:'):
            t = k[4:]
            if t not in SLUGS: raise SystemExit(f'build_site.py: pages/{slug}: no page called {t!r} in {{{{{k}}}}}')
            return page_url(t, code)
        if k == 'status': return status_line(code)
        if k == 'lang': return code
        if k in VALUES: return e(VALUES[k])
        raise SystemExit(f'build_site.py: pages/{slug}: unknown value {{{{{k}}}}}')
    return re.sub(r'\{\{([a-z_:-]+)\}\}', one, text)


# ---- screenshots: <fg-shot name="glass-bags" alt="..." sizes="..."> -> a responsive <img> -----------------------
def webp_size(path):
    b = open(path, 'rb').read(32)
    assert b[:4] == b'RIFF' and b[8:12] == b'WEBP', path
    kind = b[12:16]
    if kind == b'VP8X': return 1 + int.from_bytes(b[24:27], 'little'), 1 + int.from_bytes(b[27:30], 'little')
    if kind == b'VP8 ': return int.from_bytes(b[26:28], 'little') & 0x3fff, int.from_bytes(b[28:30], 'little') & 0x3fff
    if kind == b'VP8L':
        bits = int.from_bytes(b[21:25], 'little'); return (bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1
    raise ValueError(path)


def shot_files(name):
    full = f'{D}/shots/{name}.webp'
    if not os.path.exists(full): return None
    w, h = webp_size(full)
    sizes = {w: f'/shots/{name}.webp'}
    for f in glob.glob(f'{D}/shots/{name}-*.webp'):
        m = re.fullmatch(re.escape(name) + r'-(\d+)\.webp', os.path.basename(f))
        if m:
            vw, _ = webp_size(f)
            if vw < w: sizes[vw] = f'/shots/{os.path.basename(f)}'
    return w, h, sizes


def shots(text, slug):
    def one(m):
        a = dict((k, v if v is not None else '') for k, v in re.findall(r'([a-z][a-z-]*)(?:="([^"]*)")?', m.group(1)))
        name = a.pop('name', None)
        if not name or 'alt' not in a: raise SystemExit(f'build_site.py: pages/{slug}: <fg-shot> needs name="..." and alt="..."')
        got = shot_files(name)
        if not got: raise SystemExit(f'build_site.py: pages/{slug}: no screenshot site-src/site/shots/{name}.webp')
        w, h, sizes = got
        eager = 'eager' in a; a.pop('eager', None)
        attrs = {'src': sizes[w], 'srcset': ', '.join(f'{u} {k}w' for k, u in sorted(sizes.items())), 'sizes': a.pop('sizes', '100vw'),
                 'width': str(w), 'height': str(h), 'alt': a.pop('alt')}
        attrs.update(a)
        attrs.update({'fetchpriority': 'high'} if eager else {'loading': 'lazy', 'decoding': 'async'})
        return '<img ' + ' '.join(f'{k}="{v}"' for k, v in attrs.items()) + '>'
    return re.sub(r'<fg-shot\s([^>]*?)/?>', one, text)


# ---- the pages' own parts ----------------------------------------------------------------------------------------
class Ctx:
    """What a body.py gets: the language, its words and the shared values."""
    def __init__(self, code, slug):
        self.lang, self.slug, self.repo, self.values = code, slug, REPO, VALUES
        self.version = VERSION
    def T(self, s): return T(s, self.lang)
    def F(self, s, *a): return F(s, self.lang, *a)
    def url(self, slug): return page_url(slug, self.lang)
    esc = staticmethod(lambda s: html.escape(s, quote=True))


_mods = {}


def body_of(slug, code):
    d = f'{PAGES_DIR}/{slug}'
    if os.path.exists(d + '/body.py'):
        if slug not in _mods:
            spec = importlib.util.spec_from_file_location(f'page_{slug.replace("-", "_")}', d + '/body.py')
            mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod); _mods[slug] = mod
        text = _mods[slug].body(Ctx(code, slug))
    else:
        text = read(d + '/body.html')
    return shots(localize(fill(translate(text, code), code, slug), code), slug)


def localize(text, code):
    # a link to a page, such as href="/changelog/" in a translated sentence, stays in this language
    if code == 'en': return text
    pages = '|'.join(re.escape(s) for s in SLUGS if s != 'home')
    return re.sub(r'href="/((?:' + pages + r')/)?(#[^"]*)?"', lambda m: f'href="/{code}/{m.group(1) or ""}{m.group(2) or ""}"', text)


def page_opts(slug):
    p = f'{PAGES_DIR}/{slug}/page.json'
    return json.load(open(p)) if os.path.exists(p) else {}


def stamp(data):
    return hashlib.sha1(data if isinstance(data, bytes) else data.encode('utf-8')).hexdigest()[:10]


# ---- the shell ---------------------------------------------------------------------------------------------------
def status_line(code):
    v = VALUES
    parts = [F('Version %s', code, f'<b>{e(v["version"])}</b>')]
    if v['updated']: parts.append(F('Updated %s', code, f'<time datetime="{v["updated"]}">{v["updated"]}</time>'))
    if v['forever']: parts.append(F('Checked against WoW: Forever %s', code, f'<b>{e(v["forever"])}</b>'))
    parts.append(f'<a href="{GITHUB}">{T("Source code", code)}</a>')
    return '<p class="status">' + '<span class="sep" aria-hidden="true">·</span>'.join(f'<span>{p}</span>' for p in parts) + '</p>'


ICON_MOON = '<svg class="moon" viewBox="0 0 24 24" aria-hidden="true"><path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linejoin="round"/></svg>'
ICON_SUN = '<svg class="sun" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="4.2" fill="none" stroke="currentColor" stroke-width="1.8"/><path d="M12 2.5v2.4M12 19.1v2.4M2.5 12h2.4M19.1 12h2.4M5.3 5.3l1.7 1.7M17 17l1.7 1.7M5.3 18.7 7 17M17 7l1.7-1.7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>'
ICON_GLOBE = '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18" fill="none" stroke="currentColor" stroke-width="1.6"/></svg>'
ICON_MENU = '<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M3 5h14M3 10h14M3 15h14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>'


WEARING = 'Wearing <b id="wearname"></b>: back to the site' + "'" + 's colors'


def header(slug, code):
    t = lambda s: T(s, code)
    links = ''.join(f'<li><a href="{page_url(p["slug"], code)}"' + (' aria-current="page"' if p['slug'] == slug else '') + f'>{t(p["nav"])}</a></li>'
                    for p in PAGES if p.get('top', True))
    opts = ''.join(f'<option value="{page_url(slug, c)}" data-code="{c}" lang="{HREFLANG.get(c, c)}"' + (' selected' if c == code else '') + f'>{LANG_NAMES[c]}</option>' for c in CODES)
    return f'''<header class="site-head">
  <div class="wrap">
    <a class="brand" href="{page_url("home", code)}"><img src="/logo-64.webp" alt="" width="32" height="32">Fantasy Glass UI</a>
    <nav class="site-nav" id="site-nav" aria-label="{e(t("Pages"))}">
      <ul>{links}</ul>
      <div class="head-tools">
        <label class="lang">{ICON_GLOBE}<span class="sr-only">{t("Language")}</span><select id="lang">{opts}</select></label>
        <button class="icon-btn mode" id="mode" type="button" aria-pressed="true" title="{e(t("Dark mode"))}"><span class="sr-only">{t("Dark mode")}</span>{ICON_MOON}{ICON_SUN}</button>
      </div>
    </nav>
    <a class="btn small head-dl" href="{CURSEFORGE}">{t("Download")}</a>
    <button class="icon-btn menu-btn" id="menu-btn" type="button" aria-expanded="false" aria-controls="site-nav"><span class="sr-only">{t("Menu")}</span>{ICON_MENU}</button>
    <button class="chip wearing" id="unwear" type="button" hidden>{t(WEARING)}</button>
  </div>
</header>
'''


def footer(slug, code):
    t = lambda s: T(s, code)
    langs = ''.join(f'<li><a href="{page_url(slug, c)}" hreflang="{HREFLANG.get(c, c)}" lang="{HREFLANG.get(c, c)}" data-code="{c}"'
                    + (' aria-current="true"' if c == code else '') + f'>{LANG_NAMES[c]}</a></li>' for c in CODES)
    foot_pages = ''.join(f'        <li><a href="{page_url(p["slug"], code)}">{t(p["nav"])}</a></li>\n' for p in PAGES if p.get('foot')).rstrip('\n')
    note = '' if code == 'en' else '<p class="trnote">' + t("This page was translated without a native speaker's check. Corrections are welcome.") + '</p>'
    return f'''<footer class="site-foot">
  <div class="wrap">
    <div class="foot-row">
      <span>{t("Fantasy Glass UI by DustyMouse. Free, for WoW Forever.")}</span>
      <ul>
        <li><a href="{CURSEFORGE}">CurseForge</a></li>
        <li><a href="{DISCORD}">{t("Discord")}</a></li>
        <li><a href="{GITHUB}">GitHub</a></li>
        <li><a href="{GITHUB}/wiki">Wiki</a></li>
        <li><a href="{GITHUB}/issues/new/choose">{t("Report a bug")}</a></li>
{foot_pages}
        <li><a href="/feed.xml" type="application/rss+xml">RSS</a></li>
      </ul>
    </div>
    <div class="foot-row">
      <span>{t("Contact")}: <a href="mailto:{CONTACT}">{CONTACT}</a></span>
      {status_line(code)}
    </div>
    <nav class="foot-row foot-langs" aria-label="{e(t("Language"))}"><ul>{langs}</ul></nav>
    {note}
  </div>
</footer>
'''


def boot(slug, code):
    # runs before the page is drawn: the remembered light or dark, an English page opening the reader's language,
    # and on Home, a link into the old long page (/#faq, /?theme=...#themes) opening the page that now has that part
    old = {'themes': 'themes/', 'maker': 'themes/#maker', 'features': 'features/', 'commands': 'get-started/#commands',
           'faq': 'get-started/#faq', 'start': 'get-started/'}
    js = ('(function(){var d=document.documentElement;d.classList.add("js");'
          'try{var t=localStorage.getItem("fg-theme");if(t==="light"||t==="dark")d.setAttribute("data-theme",t)}catch(e){}'
          f'var here="{code}",page="{"" if slug == "home" else slug + "/"}",to=here,q=location.search,h=location.hash;'
          'var m=/[?&]lang=([a-z]{2})\\b/.exec(q);if(m){to=m[1];q=q.replace(/([?&])lang=[a-z]{2}&?/,"$1").replace(/[?&]$/,"")}'
          'else if(here==="en"){var c=null;try{c=localStorage.getItem("fg-lang")}catch(e){}'
          'if(!c)c=String(navigator.language||"en").slice(0,2).toLowerCase();to=c}'
          f'if({json.dumps(CODES)}.indexOf(to)<0)to=here;')
    if slug == 'home':
        js += (f'var O={json.dumps(old)},k=h.slice(1);'
               'if(/[?&](theme|code)=/.test(q)){page="themes/";if(k!=="maker")h=""}'
               'else if(O[k]){var p=O[k].split("#");page=p[0];h=p[1]?"#"+p[1]:""}')
    js += ('var u=(to==="en"?"/":"/"+to+"/")+page;'
           'if(u!==location.pathname||q!==location.search)location.replace(u+q+h)})();')
    return '<script>' + js + '</script>'


# the two fonts every page shows at once (headings and text), fetched early; Russian's text is Cyrillic
PRELOAD_FONTS = {c: ['marcellus-latin-400-normal.woff2', 'source-sans-3-latin-400-normal.woff2'] for c in CODES}
PRELOAD_FONTS['ru'] = ['source-sans-3-cyrillic-400-normal.woff2']


def head(slug, code, opts, css_url, page_css):
    p = next(x for x in PAGES if x['slug'] == slug)
    if slug == 'home':
        title, desc, ogt, ogd = (x.replace('{{themes}}', VALUES['themes']) for x in META[code])   # (the count from the theme data)
    else:
        title = T(p['nav'], code) + ' · Fantasy Glass UI'
        desc = T(p['desc'], code)
        ogt = T(p['og_title'], code) if p.get('og_title') else title
        ogd = T(p['og_desc'], code) if p.get('og_desc') else desc
    url = SITE_URL.rstrip('/') + page_url(slug, code)
    img = SITE_URL + p.get('image', 'og.jpg')
    alts = ''.join(f'<link rel="alternate" hreflang="{HREFLANG.get(c, c)}" href="{SITE_URL.rstrip("/") + page_url(slug, c)}">\n' for c in CODES)
    alts += f'<link rel="alternate" hreflang="x-default" href="{SITE_URL.rstrip("/") + page_url(slug, "en")}">\n'
    ld = ''
    if slug == 'home':
        d = dict(LD); d['description'] = d['description'] % len(THEMES)
        ld = '<script type="application/ld+json">' + json.dumps(d, ensure_ascii=False) + '</script>\n'
    robots = '<meta name="robots" content="noindex">\n' if opts.get('noindex') else ''
    robots += (opts['head'].rstrip('\n') + '\n') if opts.get('head') else ''
    return (f'<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            f'<title>{e(title)}</title>\n<meta name="description" content="{e(desc)}">\n{robots}<link rel="canonical" href="{url}">\n{alts}'
            f'<link rel="icon" type="image/png" href="/icon.png">\n'
            f'<link rel="alternate" type="application/rss+xml" title="Fantasy Glass UI releases" href="/feed.xml">\n'
            f'<meta property="og:type" content="website">\n<meta property="og:site_name" content="Fantasy Glass UI">\n'
            f'<meta property="og:locale" content="{OG_LOCALE[code]}">\n'
            + ''.join(f'<meta property="og:locale:alternate" content="{OG_LOCALE[c]}">\n' for c in CODES if c != code) +
            f'<meta property="og:title" content="{e(ogt)}">\n<meta property="og:description" content="{e(ogd)}">\n'
            f'<meta property="og:url" content="{url}">\n<meta property="og:image" content="{img}">\n'
            f'<meta property="og:image:width" content="1200">\n<meta property="og:image:height" content="630">\n'
            f'<meta property="og:image:alt" content="Fantasy Glass UI">\n'
            f'<meta name="twitter:card" content="summary_large_image">\n<meta name="twitter:title" content="{e(ogt)}">\n'
            f'<meta name="twitter:description" content="{e(ogd)}">\n<meta name="twitter:image" content="{img}">\n'
            f'<meta name="theme-color" content="#12141a" media="(prefers-color-scheme: dark)">\n'
            f'<meta name="theme-color" content="#f4f5f8" media="(prefers-color-scheme: light)">\n'
            f'{boot(slug, code)}\n'
            + ('' if code in ('ko', 'zh') else ''.join(f'<link rel="preload" href="/fonts/{f}" as="font" type="font/woff2" crossorigin>\n' for f in PRELOAD_FONTS[code])) +
            f'<link rel="stylesheet" href="{css_url}">\n'
            + (f'<style>\n{page_css}</style>\n' if page_css else '') + ld)


# ---- build -------------------------------------------------------------------------------------------------------
os.makedirs(R + '/assets', exist_ok=True)
assets = {}


def asset(name, data):
    open(f'{R}/assets/{name}', 'wb' if isinstance(data, bytes) else 'w', **({} if isinstance(data, bytes) else {'encoding': 'utf-8'})).write(data)
    assets[name] = f'/assets/{name}?v={stamp(data)}'
    return assets[name]


css_url = asset('site.css', read(D + '/base.css'))
site_js = asset('site.js', read(D + '/site.js'))
data_js = asset('data.js', DATA_JS)
# the fonts (site/fonts/, self-hosted with their licences): /fonts/<file>
os.makedirs(R + '/fonts', exist_ok=True)
for f in glob.glob(D + '/fonts/*'): shutil.copy(f, R + '/fonts/')

written = []
for p in PAGES:
    slug = p['slug']
    d = f'{PAGES_DIR}/{slug}'
    if not os.path.isdir(d) or not (os.path.exists(d + '/body.html') or os.path.exists(d + '/body.py')):
        sys.exit(f'build_site.py: site-src/pages/{slug}/ needs a body.html or a body.py')
    opts = page_opts(slug)
    page_css = read(d + '/style.css') if os.path.exists(d + '/style.css') else ''
    scripts = [site_js]
    if opts.get('data'): scripts.append(data_js)
    if os.path.exists(d + '/script.js'): scripts.append(asset(f'{slug}.js', read(d + '/script.js')))
    if os.path.isdir(d + '/files'):                 # a page's own files, served beside its English address
        shutil.copytree(d + '/files', R + page_url(slug, 'en') + ('files/' if slug == 'home' else ''), dirs_exist_ok=True)
    for code in CODES:
        body = body_of(slug, code)
        if re.search(r'\[\[|\]\]|\{\{|\}\}|<fg-shot', body): sys.exit(f'build_site.py: pages/{slug} ({code}) has a marker the build did not fill')
        page = (f'<!doctype html>\n<html lang="{HREFLANG.get(code, code)}" data-lang="{code}" data-page="{slug}">\n<head>\n'
                + head(slug, code, opts, css_url, page_css) + '</head>\n<body>\n'
                f'<a class="skip" href="#main">{T("Skip to the content", code)}</a>\n'
                + header(slug, code) + f'<main id="main" tabindex="-1">\n{body}</main>\n' + footer(slug, code)
                + ''.join(f'<script src="{s}" defer></script>\n' for s in scripts) + '</body>\n</html>\n')
        if re.search(r'<script[^>]+src="(?!/)', page): sys.exit(f'build_site.py: pages/{slug} loads a script from another site')
        out = R + page_url(slug, code) + 'index.html'
        os.makedirs(os.path.dirname(out), exist_ok=True)
        open(out, 'w', encoding='utf-8').write(page)
        written.append(out)

# a page's body.py may also write files of its own, once: def extra(out_dir, values) (a feed, for example)
for slug, mod in _mods.items():
    if hasattr(mod, 'extra'): mod.extra(R, dict(VALUES))

if MISSING:
    sys.exit('build_site.py: words with no translation in site_tr.py (add them in all 8 languages):\n  ' + '\n  '.join(sorted(MISSING)))

# the sitemap: every page in every language, each listing the others as alternates
xs = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
for p in PAGES:
    for c in CODES:
        pr = ('1.0' if p['slug'] == 'home' else '0.8') if c == 'en' else ('0.8' if p['slug'] == 'home' else '0.6')
        xs.append(f'  <url><loc>{SITE_URL.rstrip("/") + page_url(p["slug"], c)}</loc><changefreq>weekly</changefreq><priority>{pr}</priority>')
        xs += [f'    <xhtml:link rel="alternate" hreflang="{HREFLANG.get(o, o)}" href="{SITE_URL.rstrip("/") + page_url(p["slug"], o)}"/>' for o in CODES]
        xs.append(f'    <xhtml:link rel="alternate" hreflang="x-default" href="{SITE_URL.rstrip("/") + page_url(p["slug"], "en")}"/>')
        xs.append('  </url>')
# the plan page: one address, every language inside it
xs.append(f'  <url><loc>{SITE_URL}plan/</loc><changefreq>monthly</changefreq><priority>0.5</priority></url>')
xs.append('</urlset>')
open(R + '/sitemap.xml', 'w').write('\n'.join(xs) + '\n')

# the files the pages share
os.makedirs(R + '/shots', exist_ok=True)
for f in ['features.json', 'logo.webp', 'logo-64.webp', 'icon.png']: shutil.copy(D + '/' + f, R)
for f in glob.glob(D + '/shots/*.webp'): shutil.copy(f, R + '/shots/')
os.makedirs(R + '/i18n', exist_ok=True)
if not glob.glob(D + '/i18n/*.json'): sys.exit('build_site.py: no site/i18n/: run python3 site-src/make_i18n.py first')
for f in glob.glob(D + '/i18n/*.json'): shutil.copy(f, R + '/i18n/')
if OUT:                                   # (a build elsewhere carries the files docs/ keeps by hand)
    for f in ['404.html', 'CNAME', 'robots.txt', 'og.jpg', 'og.png']:
        if os.path.exists(REPO + '/docs/' + f): shutil.copy(REPO + '/docs/' + f, R)
import plan_page                          # the plan page, /plan/: linked from Guide and Gold, in the sitemap
plan_page.build(R)
print(f'built {len(written)} pages ({len(PAGES)} in {len(CODES)} languages)')
