# The plan page (<out>/plan/index.html): one page that reads a plan code in the browser and draws it.
# Built by every run of build_site.py, linked from Guide and Gold and listed in the sitemap (from 13.0).
# No counter, no structured data; the font and every language are inline. Once a plan is shown, the route is drawn on
# the world map: the page then asks this site (never another) for /map/'s Leaflet, tiles and meta.json, and for
# /plan/zones.json, which build() writes from the game's map table (tools/plan_zones.py). The plan code never leaves the browser.
import json, os, re, sys

S = os.path.dirname(os.path.abspath(__file__))
P = S + '/plan'
OPENMAP = 'https://openmap.world/'
LANGS = ['de', 'fr', 'es', 'ru', 'pt', 'it', 'ko', 'zh']
# the zone maps' words (plan/map.js), kept in site_tr.py with the example route that uses them too
MAP_WORDS = ['Map of the stops in %s', 'Step %d: %s', 'Steps %s: %s', 'N', 'North is up', 'Show step %d on the map']
# the world map's own words for its buttons (World map block of site_tr.py)
ROUTE_WORDS = ['Zoom in', 'Zoom out', 'Close']
# the only addresses the page asks for (all on this site), and only once a plan is shown
SAME_SITE = ['/map/leaflet/leaflet.css', '/map/leaflet/leaflet.js', '/map/tiles/meta.json', '/map/tiles-have.json', '/plan/zones.json',
             '/map/tiles/{z}/{y}/{x}.webp']
# light or dark as the reader chose on the site (site.js keeps it), else the system's choice
# OpenMap (the plan page's "The real map"): its words come from site_tr.py too. The iframe is NOT in the page; plan/page.html
# inserts it only when the player presses the button.
OPENMAP_WORDS = ['The real map', "OpenMap shows WoW Forever's own zone maps. It's a separate site, made by other players.",
                 'Open OpenMap in a new tab',
                 'Open the world map',
                 'Map art \u00a9 Blizzard Entertainment, shown by OpenMap (openmap.world). Not part of Fantasy Glass UI.']
THEME = ('<script>try{var t=localStorage.getItem("fg-theme");'
         'if(t==="light"||t==="dark")document.documentElement.setAttribute("data-theme",t)}catch(e){}</script>\n')


def build(out_dir):
    page = open(P + '/page.html', encoding='utf-8').read()
    reader = open(P + '/reader.js', encoding='utf-8').read()
    words = json.load(open(P + '/words.json', encoding='utf-8'))
    sys.path.insert(0, S)
    from site_tr import SITE
    for k in MAP_WORDS + OPENMAP_WORDS + ROUTE_WORDS:
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
    # (the one outside address is OpenMap's plain link; the page asks only this site, through get(), which refuses any
    # other path, and for Leaflet's two files and the tiles)
    assert re.search(r'XMLHttpRequest|sendBeacon|WebSocket|<script src|<link|<iframe|https?://', html.replace(OPENMAP, '')) is None
    assert html.count(OPENMAP) == 1, 'OpenMap is named once: its link'
    assert html.count('fetch(') == 1 and 'if (!/^\\/(?:map|plan)\\/[\\w\\/.-]+$/.test(path)) return Promise.reject' in html, 'one fetch, for this site only'
    asked = set(re.findall(r'"(/(?:map|plan)/[^"]*)"', html))
    assert asked <= set(SAME_SITE + ['/map/']), sorted(asked - set(SAME_SITE))       # ('/map/': the credit's link)
    os.makedirs(out_dir + '/plan', exist_ok=True)
    open(out_dir + '/plan/index.html', 'w', encoding='utf-8').write(html)
    sys.path.insert(0, S + '/tools')
    import plan_zones
    open(out_dir + '/plan/zones.json', 'w', encoding='utf-8').write(plan_zones.text())


if __name__ == '__main__':
    build(sys.argv[1])
