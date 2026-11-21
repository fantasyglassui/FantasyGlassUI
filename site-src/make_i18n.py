# Writes site/i18n/<code>.json: the site's own words (site_tr.py) plus the add-on's translations of
# every switch, section, command and news line, so the lists read as they do in the game.
import json, os, re, sys
S = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, S); sys.path.insert(0, S + '/words')
from site_tr import SITE, THEMES
from words import T
from words_more import M
from words_zh import Z
d = json.load(open(S + '/site/features.json'))
js = open(S + '/site/data.js').read()
news = json.loads(re.search(r'window.FG_NEWS=(\[.*?\]);', js, re.S).group(1))
keys = set()
for s in d['sections']:
    keys.add(s['title'])
    for i in s['items']:
        keys.add(i['label']); keys.add(i['desc'])
for c in d['commands']: keys.add(c['desc'])
for v in news: keys.update(v['items'])
keys.discard('')
CODES = ['de', 'fr', 'es', 'ru', 'pt', 'it', 'ko', 'zh']
def game(k, n):
    if n < 3: return T.get(k, (None,) * 3)[n]
    if n < 7: return M.get(k, (None,) * 4)[n - 3]
    return Z.get(k)
_lua = open(S + '/../FantasyGlassUI_Locales/Locales.lua', encoding='utf-8').read()
_parts = re.split(r'\nns\.locales\.(\w+) = \{', _lua)
_map = dict(zip(['deDE','frFR','esES','ruRU','ptBR','itIT','koKR','zhCN'], CODES))
LUA = {c: {} for c in CODES}
for i in range(1, len(_parts), 2):
    if _parts[i] in _map:
        for k, v in re.findall(r'^    \["((?:[^"\\]|\\.)*)"\] = "((?:[^"\\]|\\.)*)",', _parts[i + 1], re.M):
            LUA[_map[_parts[i]]][k.replace('\\"', '"')] = v.replace('\\"', '"')
os.makedirs(S + '/site/i18n', exist_ok=True)
for n, code in enumerate(CODES):
    out = {}
    for k in keys:
        v = game(k, n)
        if v: out[k] = v
    for k in keys:                                    # newer lines: straight from the add-on's own Locales.lua
        if k not in out and k in LUA[code]: out[k] = LUA[code][k]
    for k, v in THEMES.items(): out[k] = v[n]
    for k, v in SITE.items(): out[k] = v[n]
    miss = [k for k in keys if k not in out]
    json.dump(out, open(f'{S}/site/i18n/{code}.json', 'w'), ensure_ascii=False, separators=(',', ':'))
    print(code, len(out), 'missing from the game tables:', len(miss))
# every site phrase has all eight
for k, v in list(SITE.items()) + list(THEMES.items()):
    assert len(v) == 8 and all(x.strip() for x in v), k
    tags = lambda s: sorted(re.findall(r'<[^>]+>|%[sd]', s))
    assert all(tags(x) == tags(k) for x in v), ('markup differs', k)
need = json.load(open(S + '/keys_all.json'))
skip = {'Fantasy Glass UI', 'accent', 'rim'}
missing = [k for k in need if k not in SITE and k not in skip]
print('site phrases without a translation:', missing)
