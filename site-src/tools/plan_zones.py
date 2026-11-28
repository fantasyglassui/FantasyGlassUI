# The plan page's zones (served at /plan/zones.json): where a spot on a zone's own map lands on the world map (/map/).
# A step in a plan code has its zone (a UiMapID, or only the zone's name) and x, y on that zone's map (0-100, as the
# game shows them). From the game's UiMapAssignment table (tools/mapdata/), the same sums as tools/map_markers.py:
#   pixel x = ax + bx * x / 100,   pixel y = ay + by * y / 100      (pixels from the top left at the map's maxZoom)
#   {"ids": {"1411": [ax, bx, ay, by], ...}, "names": {"Durotar": 1411, ...}}
# Only zones on Kalimdor and the Eastern Kingdoms (the two continents the world map shows) are in "ids".
# A zone off the world map (an island on its own game map, such as Zephras Isle) can have its own map art instead:
# drop the game's zone map (the standard 1002 x 668 layout) in as site-src/pages/map/files/zones/<UiMapID>.webp, served
# at /map/zones/<UiMapID>.webp, and it is listed here; the plan page then draws that zone's steps on it (x, y 0-100
# straight across and down the picture):   "images": {"2521": {"src": "/map/zones/2521.webp", "size": [1002, 668]}}
# plan_page.py writes it on every build; run this to see it:   python3 site-src/tools/plan_zones.py
import json
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_markers as mm  # noqa: E402

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'pages', 'map', 'files', 'zones')
# the English names of the zones off the world map, so a code that names one without its UiMapID still finds its art
OFF_NAMES = {2521: 'Zephras Isle'}


def webp_size(path):
    b = open(path, 'rb').read(30)
    if b[:4] != b'RIFF' or b[8:12] != b'WEBP':
        raise SystemExit(path + ': not a WebP picture')
    kind = b[12:16]
    if kind == b'VP8X':
        return [int.from_bytes(b[24:27], 'little') + 1, int.from_bytes(b[27:30], 'little') + 1]
    if kind == b'VP8 ':
        w, h = struct.unpack('<HH', b[26:30])
        return [w & 0x3fff, h & 0x3fff]
    if kind == b'VP8L':
        n = int.from_bytes(b[21:25], 'little')
        return [(n & 0x3fff) + 1, ((n >> 14) & 0x3fff) + 1]
    raise SystemExit(path + ': an unknown kind of WebP')


def zones():
    ids = {}
    for ui in sorted(mm.zone):
        a, b = mm.zone_xy(ui, 0, 0), mm.zone_xy(ui, 1, 1)
        if not a:
            continue                                     # (a map that is not on either continent)
        ids[str(ui)] = [round(a[0], 3), round(b[0] - a[0], 3), round(a[1], 3), round(b[1] - a[1], 3)]
    images = {}
    for f in sorted(os.listdir(ART)) if os.path.isdir(ART) else []:
        if f.endswith('.webp') and f[:-5].isdigit():
            images[str(int(f[:-5]))] = {'src': '/map/zones/' + f, 'size': webp_size(os.path.join(ART, f))}
    names = {nm: ui for ui, nm in mm.ZONES.items() if str(ui) in ids}
    names.update({nm: ui for ui, nm in OFF_NAMES.items() if str(ui) in images})
    return {'ids': ids, 'names': names, 'images': images}


def text():
    return json.dumps(zones(), separators=(',', ':'), sort_keys=True)


if __name__ == '__main__':
    z = zones()
    print(text())
    print(len(z['ids']), 'zones,', len(z['names']), 'names,', len(z['images']), 'zone maps of their own', file=sys.stderr)
