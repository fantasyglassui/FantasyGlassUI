# Assemble the draft page (artifact) and the public site (docs/ for GitHub Pages) from the parts.
# The public site has the English page at / and one page per language at /de/, /fr/ and so on, each
# with its own title, description and hreflang links; the page itself then shows that language.
import os, shutil, glob, json, html, re, sys
S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S)
REPO = os.path.normpath(S + '/..')
# --out DIR: write the public site to DIR (not docs); the draft pages in site/ are then left alone.
# --plan: also write the plan page (plan_page.py) into the output; nothing links to it.
_args = sys.argv[1:]
OUT = None
if '--out' in _args:
    _i = _args.index('--out')
    if _i + 1 >= len(_args) or _args[_i + 1].startswith('--'): sys.exit('build_site.py: --out needs a folder: --out DIR')
    OUT = os.path.abspath(_args[_i + 1])
WITH_PLAN = '--plan' in _args
from lang_meta import META, OG_LOCALE
D = S + '/site'
os.chdir(D)
h = open('head.html').read(); b = open('body.html').read()
_v = re.search(r'window.FG_NEWS=\[\{"v": "([0-9.]+)"', open('data.js').read())          # (the version at the top: the newest What's new)
if _v: b = re.sub(r'<b id="f-version">[0-9.]+</b>', '<b id="f-version">' + '.'.join(_v.group(1).split('.')[:2]) + '</b>', b); s = open('script.html').read(); data = open('data.js').read()
if OUT is None: open('index.html', 'w').write(h + b + '<script>\n' + data + '</script>\n' + s)

SITE = 'https://fantasyglassui.com/'
CODES = ['en', 'de', 'fr', 'es', 'ru', 'pt', 'it', 'ko', 'zh']
HREFLANG = {'zh': 'zh-Hans'}
url = lambda c: SITE if c == 'en' else f'{SITE}{c}/'
ld = open('../public_meta.html').read()
ld = ld[ld.index('<script type="application/ld+json">'):]          # structured data and the visit counter

def head_for(code):
    t, desc, ogt, ogd = META[code]
    e = lambda x: html.escape(x, quote=True)
    alts = ''.join(f'<link rel="alternate" hreflang="{HREFLANG.get(c, c)}" href="{url(c)}">\n' for c in CODES)
    return (f'<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            f'<title>{e(t)}</title>\n<meta name="description" content="{e(desc)}">\n<link rel="canonical" href="{url(code)}">\n'
            f'{alts}<link rel="alternate" hreflang="x-default" href="{SITE}">\n'
            f'<link rel="icon" type="image/png" href="/icon.png">\n<meta property="og:type" content="website">\n'
            f'<meta property="og:site_name" content="Fantasy Glass UI">\n<meta property="og:locale" content="{OG_LOCALE[code]}">\n'
            f'<meta property="og:title" content="{e(ogt)}">\n<meta property="og:description" content="{e(ogd)}">\n'
            f'<meta property="og:url" content="{url(code)}">\n<meta property="og:image" content="{SITE}og.jpg">\n'
            f'<meta property="og:image:width" content="1200">\n<meta property="og:image:height" content="630">\n'
            f'<meta name="twitter:card" content="summary_large_image">\n<meta name="theme-color" content="#06070d">\n'
            f'<script>window.FG_BASE = "/";' + ('' if code == 'en' else f' window.FG_LANG = "{code}";') + '</script>\n' + ld)

bp = b.replace('    <span class="draft" title="This page is a draft and not public yet">Draft</span>\n', '', 1)
assert 'class="draft"' not in bp
bp = re.sub(r'(?<=[" ,])shots/', '/shots/', bp).replace('src="logo-64.webp"', 'src="/logo-64.webp"')
assert 'src="shots/' not in bp
R = OUT or os.path.normpath(S + '/../docs')
for code in CODES:
    hp = h.replace('<title>Fantasy Glass UI</title>\n<meta name="claude:viewport-fit-sides" content="cover">', head_for(code), 1)
    assert 'og:image' in hp
    page = (f'<!doctype html>\n<html lang="{HREFLANG.get(code, code)}" data-theme="dark">\n<head>\n' + hp.replace('</style>', '</style>\n</head>\n<body>', 1)
            + bp + '<script>\n' + data + '</script>\n' + s + '</body>\n</html>\n')
    out = R + ('/index.html' if code == 'en' else f'/{code}/index.html')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, 'w').write(page)
    if code == 'en' and OUT is None: open('public.html', 'w').write(page)

# sitemap with every language listed as an alternate of the others
xs = ['<?xml version="1.0" encoding="UTF-8"?>', '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">']
for c in CODES:
    xs.append(f'  <url><loc>{url(c)}</loc><changefreq>weekly</changefreq><priority>{"1.0" if c == "en" else "0.8"}</priority>')
    xs += [f'    <xhtml:link rel="alternate" hreflang="{HREFLANG.get(o, o)}" href="{url(o)}"/>' for o in CODES]
    xs.append(f'    <xhtml:link rel="alternate" hreflang="x-default" href="{SITE}"/>')
    xs.append('  </url>')
xs.append(f'  <url><loc>{SITE}accessibility/</loc><changefreq>monthly</changefreq><priority>0.7</priority></url>')
xs.append(f'  <url><loc>{SITE}changelog/</loc><changefreq>weekly</changefreq><priority>0.6</priority></url>')
xs.append('</urlset>')
open(R + '/sitemap.xml', 'w').write('\n'.join(xs) + '\n')

os.makedirs(R + '/shots', exist_ok=True)
for f in ['features.json', 'logo.webp', 'logo-64.webp', 'icon.png']: shutil.copy(f, R)
for f in glob.glob('shots/*.webp'): shutil.copy(f, R + '/shots/')
os.makedirs(R + '/i18n', exist_ok=True)
for f in glob.glob('i18n/*.json'): shutil.copy(f, R + '/i18n/')
# the changelog page, from the add-on's own CHANGELOG.md
import subprocess
os.makedirs(R + '/changelog', exist_ok=True)
subprocess.run([sys.executable, S + '/changelog_page.py', REPO + '/CHANGELOG.md', R + '/changelog/index.html'], check=True)
os.makedirs(R + '/accessibility', exist_ok=True)
subprocess.run([sys.executable, S + '/accessibility_page.py', R + '/accessibility/index.html', re.search(r'ns.version = "([^"]+)"', open(REPO + '/FantasyGlassUI/Core.lua').read()).group(1)], check=True)
if WITH_PLAN:
    import plan_page
    plan_page.build(R)
print('built')
