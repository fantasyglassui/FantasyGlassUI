# The plan page (<out>/plan/index.html): one page that reads a plan code in the browser and draws it.
# Built by every run of build_site.py, linked from Guide and Gold and listed in the sitemap (from 13.0).
# No counter, no network requests, no structured data; the font and every language are inline.
import json, os, re, sys

S = os.path.dirname(os.path.abspath(__file__))
P = S + '/plan'
LANGS = ['de', 'fr', 'es', 'ru', 'pt', 'it', 'ko', 'zh']
# the zone maps' words (plan/map.js), kept in site_tr.py with the example route that uses them too
MAP_WORDS = ['Map of the stops in %s', 'Step %d: %s', 'Steps %s: %s', 'N', 'North is up', 'Show step %d on the map']
# light or dark as the reader chose on the site (site.js keeps it), else the system's choice
THEME = ('<script>try{var t=localStorage.getItem("fg-theme");'
         'if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}catch(e){}</script>\n')


def build(out_dir):
    page = open(P + '/page.html', encoding='utf-8').read()
    reader = open(P + '/reader.js', encoding='utf-8').read()
    words = json.load(open(P + '/words.json', encoding='utf-8'))
    sys.path.insert(0, S)
    from site_tr import SITE
    for k in MAP_WORDS:
        words[k] = dict(en=k, **dict(zip(LANGS, SITE[k])))
    mapjs = open(P + '/map.js', encoding='utf-8').read()
    font = open(S + '/site/marcellus.b64').read().strip()
    blob = json.dumps(words, ensure_ascii=False, separators=(',', ':')).replace('</', '<\\/')
    page = page.replace('@@FONT@@', font).replace('/*@WORDS@*/', blob).replace('/*@READER@*/', reader.replace('</', '<\\/'))
    page = page.replace('/*@MAP@*/', mapjs.replace('</', '<\\/'))
    html = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            '<meta name="description" content="Paste a plan code from Fantasy Glass UI and follow the route on any screen, a phone too. Nothing leaves your browser.">\n'
            '<meta name="referrer" content="no-referrer">\n'
            '<title>Your route · Fantasy Glass UI</title>\n' + THEME + '</head>\n<body>\n' + page + '</body>\n</html>\n')
    assert re.search(r'\bfetch\(|XMLHttpRequest|sendBeacon|WebSocket|<script src|<link|https?://', html) is None
    os.makedirs(out_dir + '/plan', exist_ok=True)
    open(out_dir + '/plan/index.html', 'w', encoding='utf-8').write(html)


if __name__ == '__main__':
    build(sys.argv[1])
