# Add phrases to every language table of Locales.lua.   python3 add_tr.py phrases.json
# phrases.json: { "English": ["de", "fr", "es", "ru", "pt", "it", "ko", "zh"], ... }
import sys, json, re
import os
LOC = os.path.normpath(os.path.dirname(os.path.abspath(__file__)) + '/../../FantasyGlassUI_Locales/Locales.lua')
ORDER = ['deDE', 'frFR', 'esES', 'ruRU', 'ptBR', 'itIT', 'koKR', 'zhCN']
data = json.load(open(sys.argv[1], encoding='utf-8'))
src = open(LOC, encoding='utf-8').read()
def esc(t): return t.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
for i, code in enumerate(ORDER):
    head = f'ns.locales.{code} = {{'
    at = src.index(head) + len(head)
    # the table's own keys, so a phrase is not added twice
    end = src.index('\n}', at)
    have = set(re.findall(r'^    \["((?:[^"\\]|\\.)*)"\]', src[at:end], re.M))
    lines = []
    for en, tr in data.items():
        assert len(tr) == 8, en
        if esc(en) in have: continue
        lines.append(f'    ["{esc(en)}"] = "{esc(tr[i])}",')
    if lines: src = src[:at] + '\n' + '\n'.join(lines) + src[at:]
open(LOC, 'w', encoding='utf-8').write(src)
print('added', len(data), 'phrases')
