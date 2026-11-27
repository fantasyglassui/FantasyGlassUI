# Lists every phrase the site needs translated (keys_all.json): the [[...]] words in each page's body, the words
# the build writes in the shared header and footer, and the words the pages' scripts write (L("...") and F("...")).
# make_i18n.py prints those that site_tr.py lacks; build_site.py stops on any it meets that has no translation.
import glob, json, os, re
S = os.path.dirname(os.path.abspath(__file__)) + '/'
keys = []
def add(k):
    k = re.sub(r'\s+', ' ', k).strip()
    if k and k not in keys: keys.append(k)
for f in sorted(glob.glob(S + 'pages/**/body.html', recursive=True) + glob.glob(S + 'pages/**/body.py', recursive=True)):
    for k in re.findall(r'\[\[(.+?)\]\]', open(f, encoding='utf-8').read(), re.S): add(k)
# a page's data file (pages/<slug>/*.json) names the fields its body.py translates: {"_translate": ["title", "text"], ...}
def data_words(v, fields):
    if isinstance(v, dict):
        for k, x in v.items():
            if k in fields and isinstance(x, str): add(x)
            else: data_words(x, fields)
    elif isinstance(v, list):
        for x in v: data_words(x, fields)
# (and the trailer's captions, site/video/captions.json, made the same way)
for f in sorted(glob.glob(S + 'pages/**/*.json', recursive=True)) + sorted(glob.glob(S + 'site/video/*.json')):
    d = json.load(open(f, encoding='utf-8'))
    if isinstance(d, dict) and isinstance(d.get('_translate'), list): data_words(d, set(d['_translate']))
b = open(S + 'build_site.py', encoding='utf-8').read()
for k in re.findall(r'\bt\("((?:[^"\\]|\\.)*)"\)|\bT\("((?:[^"\\]|\\.)*)", code\)|\bF\("((?:[^"\\]|\\.)*)", code', b):
    add(next(x for x in k if x))
from lang_meta import PAGES
for p in PAGES:
    for f in ('nav', 'desc', 'og_title', 'og_desc'):
        if p.get(f): add(p[f])
add('Wearing <b id="wearname"></b>: back to the site\'s colors')
for f in sorted(glob.glob(S + 'pages/*/script.js') + [S + 'site/site.js']):
    s = open(f, encoding='utf-8').read()
    for k in re.findall(r'\b[LF]\("((?:[^"\\]|\\.)*)"', s): add(k.replace('\\"', '"'))
    # the screenshot captions and theme families the home and themes scripts translate
    for m in re.finditer(r'\["[a-z-]+", "([^"]+)", "([^"]+)"\]', s): add(m.group(1)); add(m.group(2))
    about = re.search(r'var about = \{(.*?)\}\[t\.f\]', s)
    if about: [add(x) for x in re.findall(r': "([^"]+)"', about.group(1))]
for k in ("All", "Glass", "Fantasy", "Celestial"): add(k)
json.dump(keys, open(S + 'keys_all.json', 'w'), indent=1, ensure_ascii=False)
print(len(keys), 'phrases')
