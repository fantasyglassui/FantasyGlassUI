# Writes site/features.json from the add-on: every switch and every command, as the game shows them.
#   python3 site-src/tools/make_features.py      (then make_i18n.py and build_site.py)
# - sections: the Features tab's switches in its order (FantasyGlassUI_Options/FeatureList.lua: the groups, their
#   headings in SECTIONS and their words in DESC), then "Quest guides": the Guide tab's switches
#   (FantasyGlassUI_Options/Bars.lua) and the planner window's (FantasyGlassUI_Planner/PlannerWindow.lua);
# - commands: /fgui help's list (ns.helpLines in FantasyGlassUI/Core.lua), headings left out.
# Each label and description is the add-on's English; make_i18n.py takes their translations from Locales.lua.
import json
import os
import re

S = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(S)
STR = r'"((?:[^"\\]|\\.)*)"'


def read(rel): return open(os.path.join(REPO, rel), encoding='utf-8').read()


def unq(s): return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t'}.get(m.group(1), m.group(1)), s)


def between(src, start, end):
    a = src.index(start)
    return src[a:src.index(end, a + len(start))]


def features():
    src = read('FantasyGlassUI_Options/FeatureList.lua')
    groups = between(src, 'local groups = {', '-- Section headings')
    order = [(k, unq(v)) for k, v in re.findall(r'\{\s*"(\w+)",\s*' + STR + r'\s*\}', groups)]
    heads = {k: unq(v) for k, v in re.findall(r'^\s*(\w+)\s*=\s*' + STR, between(src, 'local SECTIONS = {', '\n}'), re.M)}
    desc = {k: unq(v) for k, v in re.findall(r'^\s*(\w+)\s*=\s*' + STR + r',?\s*$', between(src, 'local DESC = {', '\n}\n'), re.M)}
    sections = []
    for key, label in order:
        if key in heads: sections.append({'title': heads[key], 'items': []})
        if not sections: raise SystemExit(f'make_features.py: {key} comes before the first heading')
        if key not in desc: raise SystemExit(f'make_features.py: no DESC for {key}')
        sections[-1]['items'].append({'key': key, 'label': label, 'desc': desc[key]})
    return sections


def guide_switches():
    items = []
    bars = read('FantasyGlassUI_Options/Bars.lua')
    for key, label, d in re.findall(r'SwitchRow\(G, "\w+", "(\w+)", ' + STR + r', ' + STR, bars):
        items.append({'key': key, 'label': unq(label), 'desc': unq(d)})
    win = read('FantasyGlassUI_Planner/PlannerWindow.lua')
    consts = {k: unq(v) for k, v in re.findall(r'^\s*local (\w+) = ' + STR + r'\s*$', win, re.M)}
    pat = r'(?:Include|Advice|K\.SwitchRow)\((?:G,\s*)?"\w+",\s*"(\w+)",\s*' + STR + r',\s*(?:' + STR + r'|(\w+))'
    for key, label, d, name in re.findall(pat, win):
        text = unq(d) if d else consts.get(name)
        if text is None: raise SystemExit(f'make_features.py: the planner window\'s {key}: no words for {name}')
        items.append({'key': key, 'label': unq(label), 'desc': text})
    return items


def commands():
    src = read('FantasyGlassUI/Core.lua')
    block = between(src, 'ns.helpLines = {', '\n}')
    return [{'cmd': unq(c), 'desc': unq(d)} for c, d in re.findall(r'^\s*\{\s*' + STR + r',\s*' + STR + r'\s*\}', block, re.M)]


if __name__ == '__main__':
    sections = features()
    sections.append({'title': 'Quest guides', 'items': guide_switches()})
    keys = [i['key'] for s in sections for i in s['items']]
    dup = sorted({k for k in keys if keys.count(k) > 1})
    if dup: raise SystemExit(f'make_features.py: listed twice: {dup}')
    out = {'sections': sections, 'commands': commands()}
    path = os.path.join(S, 'site', 'features.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print(f'features.json: {len(keys)} switches in {len(sections)} sections, {len(out["commands"])} commands')
