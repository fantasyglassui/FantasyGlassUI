# Builds site-src/pages/map/files/markers.json (served at /map/markers.json) (the website's world map pins) from OpenMap's data (MIT, openmap.world):
# dungeon and raid entrances (Places.lua), flight masters (FlightData.lua), boats, zeppelins and airships
# (Places.lua), and zone names with level ranges (Levels.lua), placed with the game's UiMapAssignment table
# (build 1.60.1.70245, from wago.tools). Pixel = world-map (947) position * 1002 x 668 * 16 (OpenMap ZoneArt.lua).
#   python3 site-src/tools/map_markers.py
import csv, json, os
from lupa.lua51 import LuaRuntime
HERE = os.path.dirname(os.path.abspath(__file__)); D = os.path.join(HERE, 'mapdata')
OUT = os.path.join(HERE, '..', 'pages', 'map', 'files', 'markers.json')
PX, WW, WH = 16, 1002, 668
rows = list(csv.DictReader(open(os.path.join(D, 'UiMapAssignment.csv'), encoding='utf-8')))
f = lambda r, k: float(r[k])
world = {int(r['MapID']): r for r in rows if r['UiMapID'] == '947'}
zone = {int(r['UiMapID']): r for r in rows if r['OrderIndex'] == '0' and r['UiMapID'] != '947'}

def to_px(cont, x, y):
    """world yards on continent 0 / 1 -> map pixels (from the top-left)"""
    r = world.get(cont)
    if not r: return None
    u = f(r, 'UiMin_0') + (f(r, 'Region_4') - y) / (f(r, 'Region_4') - f(r, 'Region_1')) * (f(r, 'UiMax_0') - f(r, 'UiMin_0'))
    v = f(r, 'UiMin_1') + (f(r, 'Region_3') - x) / (f(r, 'Region_3') - f(r, 'Region_0')) * (f(r, 'UiMax_1') - f(r, 'UiMin_1'))
    return [round(u * WW * PX), round(v * WH * PX)]

def zone_px(ui, u, v):
    """a spot on a zone's own map (0..1) -> map pixels"""
    r = zone.get(ui)
    if not r: return None
    y = f(r, 'Region_4') - u * (f(r, 'Region_4') - f(r, 'Region_1'))
    x = f(r, 'Region_3') - v * (f(r, 'Region_3') - f(r, 'Region_0'))
    return to_px(int(r['MapID']), x, y)

lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("function _load(src, ns) local fn = assert(loadstring(src)) fn('OpenMap', ns) end")
ns = lua.eval('{}')
for name in ('Places.lua', 'FlightData.lua', 'Levels.lua'):
    lua.globals()._load(open(os.path.join(D, name), encoding='utf-8').read(), ns)
def L(t): return [t[i] for i in range(1, len(t) + 1)] if t else []

out = []
places = ns.MapPlaces
for e in L(places.instances):
    at = zone_px(e.map, e[2], e[3]) if e.map else to_px(e[1], e[2], e[3])
    if not at: continue
    for i in L(e[4]):
        lv = (' Levels %d to %d.' % (i[4], i[5])) if i[4] else ''
        bosses = L(places.bosses[i[1]]) if places.bosses[i[1]] else []
        out.append({'name': i[2], 'category': 'Raids' if i[3] else 'Dungeons', 'coords': at,
                    'description': ('Raid.' if i[3] else 'Dungeon.') + lv + (' Bosses: ' + ', '.join(bosses) + '.' if bosses else '')})
KIND = {'boat': 'Boat', 'zeppelin': 'Zeppelin', 'airship': 'Airship'}
seen = set()
for t in L(places.transports):
    at = to_px(t[3], t[4], t[5])
    if not at: continue
    key = (t[2], tuple(at))
    if key in seen: continue
    seen.add(key)
    fac = (' (%s only)' % t.faction) if t.faction else ''
    out.append({'name': '%s: %s' % (KIND.get(t[1], t[1].title()), t[2]), 'category': 'Boats and zeppelins', 'coords': at,
                'description': '%s dock, %s route.%s' % (KIND.get(t[1], t[1].title()), t[2], fac)})
FAC = {1: 'Alliance', 2: 'Horde'}
nodes = ns.MapFlights.nodes
for nid in sorted(k for k in nodes.keys()):
    n = nodes[nid]
    at = to_px(n[2], n[3], n[4])
    if not at: continue
    who = FAC.get(n[5], 'Both factions')
    if n[6]: who += ', ' + str(n[6]) + ' only'
    out.append({'name': n[1], 'category': 'Flight masters', 'coords': at, 'description': 'Flight master. ' + who + '.'})
names = {int(r['UiMapID']): None for r in rows}
levels = ns.MapLevels
ZONES = {1411:'Durotar',1412:'Mulgore',1413:'The Barrens',1416:'Alterac Mountains',1417:'Arathi Highlands',1418:'Badlands',
 1419:'Blasted Lands',1420:'Tirisfal Glades',1421:'Silverpine Forest',1422:'Western Plaguelands',1423:'Eastern Plaguelands',
 1424:'Hillsbrad Foothills',1425:'The Hinterlands',1426:'Dun Morogh',1427:'Searing Gorge',1428:'Burning Steppes',1429:'Elwynn Forest',
 1430:'Deadwind Pass',1431:'Duskwood',1432:'Loch Modan',1433:'Redridge Mountains',1434:'Stranglethorn Vale',1435:'Swamp of Sorrows',
 1436:'Westfall',1437:'Wetlands',1438:'Teldrassil',1439:'Darkshore',1440:'Ashenvale',1441:'Thousand Needles',1442:'Stonetalon Mountains',
 1443:'Desolace',1444:'Feralas',1445:'Dustwallow Marsh',1446:'Tanaris',1447:'Azshara',1448:'Felwood',1449:"Un'Goro Crater",
 1450:'Moonglade',1451:'Silithus',1452:'Winterspring',1453:'Stormwind City',1454:'Orgrimmar',1455:'Ironforge',1456:'Thunder Bluff',
 1457:'Darnassus',1458:'Undercity',2482:'Mount Hyjal',2548:'Riverglades',2652:"Shen'dralas"}
for ui, nm in ZONES.items():
    at = zone_px(ui, 0.5, 0.5)
    if not at: continue
    lv = levels[ui]
    desc = ('Levels %d to %d.' % (lv[1], lv[2])) if lv else ('City.' if ui in (1453,1454,1455,1456,1457,1458) else 'Zone.')
    out.append({'name': nm, 'category': 'Zones', 'coords': at, 'description': desc})
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(out, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
from collections import Counter
print(len(out), 'markers', dict(Counter(m['category'] for m in out)), '->', os.path.relpath(OUT))
