# The plan page's zones (served at /plan/zones.json): where a spot on a zone's own map lands on the world map (/map/).
# A step in a plan code has its zone (a UiMapID, or only the zone's name) and x, y on that zone's map (0-100, as the
# game shows them). From the game's UiMapAssignment table (tools/mapdata/), the same sums as tools/map_markers.py:
#   pixel x = ax + bx * x / 100,   pixel y = ay + by * y / 100      (pixels from the top left at the map's maxZoom)
#   {"ids": {"1411": [ax, bx, ay, by], ...}, "names": {"Durotar": 1411, ...}}
# Only zones on Kalimdor and the Eastern Kingdoms (the two continents the world map shows) are in it.
# plan_page.py writes it on every build; run this to see it:   python3 site-src/tools/plan_zones.py
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_markers as mm  # noqa: E402


def zones():
    ids = {}
    for ui in sorted(mm.zone):
        a, b = mm.zone_xy(ui, 0, 0), mm.zone_xy(ui, 1, 1)
        if not a:
            continue                                     # (a map that is not on either continent)
        ids[str(ui)] = [round(a[0], 3), round(b[0] - a[0], 3), round(a[1], 3), round(b[1] - a[1], 3)]
    names = {nm: ui for ui, nm in mm.ZONES.items() if str(ui) in ids}
    return {'ids': ids, 'names': names}


def text():
    return json.dumps(zones(), separators=(',', ':'), sort_keys=True)


if __name__ == '__main__':
    z = zones()
    print(text())
    print(len(z['ids']), 'zones,', len(z['names']), 'names', file=sys.stderr)
