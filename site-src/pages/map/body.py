# The world map's body (W3): Kalimdor and the Eastern Kingdoms in one map to drag and zoom (Leaflet, served from this
# site), the places marked on it by kind, the credits, and a hidden helper for adding places (?pins). The build calls
# body(ctx) and, once, extra(out_dir, values); see site-src/PAGES.md ("The world map").
#
# Its files, served at /map/ (pages/map/files/):
#   tiles/{z}/{y}/{x}.webp, tiles/meta.json   the map art, cut into 256 px tiles (zoom 0..maxZoom); meta.json gives
#                                             the whole map's width and height at maxZoom, the tile size and the sea colour
#   markers.json                              the places: [{"name", "category", "coords": [x, y], "description"}]
#   leaflet/                                  Leaflet 1.9.4 from npm (leaflet.js, leaflet.css, images/, its licence)
# extra() writes /map/tiles-have.json: which tiles exist (open sea has none), so the page never asks for a missing one.
import json
import os

FILES = os.path.dirname(os.path.abspath(__file__)) + '/files'
EXT = 'target="_blank" rel="noopener noreferrer"'


def body(ctx):
    return f'''<!-- World map (W3). pages/map/body.py, with the tiles, the places and Leaflet in pages/map/files/; see site-src/PAGES.md. -->
<div class="wrap page-head">
  <span class="eyebrow">Azeroth</span>
  <h1>[[World map]]</h1>
  <p class="lede">[[Kalimdor and the Eastern Kingdoms side by side, from the game's own zone maps. Drag to move around; scroll, pinch or use the buttons to zoom.]]</p>
</div>
<div class="wrap worldmap">
  <div class="map-frame">
    <div id="worldmap" class="map" role="region" aria-label="[[The world map of Azeroth]]"></div>
    <p class="map-wait" id="map-wait">[[The map needs JavaScript to show.]]</p>
  </div>
  <div class="map-tools">
    <div class="filters" id="map-cats" role="group" aria-label="[[Show on the map]]" hidden></div>
    <p class="faint" id="map-none" hidden>[[No places are marked on the map yet.]]</p>
  </div>
  <section class="pins card filled" id="pins" aria-labelledby="h-pins" hidden>
    <h2 id="h-pins">[[Pin helper]]</h2>
    <p>[[Click the map to read a spot's coordinates: pixels from the top left of the whole map, as markers.json takes them.]]</p>
    <pre id="pins-out" class="pins-out"></pre>
    <button class="btn small line" id="pins-copy" type="button" disabled>[[Copy]]</button>
  </section>
  <section class="credits" aria-labelledby="h-credits">
    <h2 id="h-credits">[[Credits]]</h2>
    <ul>
      <li>[[Map art © Blizzard Entertainment. This site is not made or endorsed by Blizzard.]]</li>
      <li>[[The zone pieces come from <a href="https://openmap.world/" target="_blank" rel="noopener noreferrer">OpenMap</a>, made by other players for WoW Forever (its source on GitHub, MIT license).]]
        <a href="https://ko-fi.com/jigrobbulus" {EXT}>[[Support OpenMap on Ko-fi]]</a></li>
      <li>[[The places on the map (dungeon and raid entrances, flight masters, boats, zeppelins and zones) come from OpenMap's data, placed with the game's own map tables.]]</li>
      <li>[[The painted pieces that fill the gaps between zones are by Santiago Reyes, used by OpenMap with his permission.]]</li>
      <li>[[The map is drawn with <a href="https://leafletjs.com/" target="_blank" rel="noopener noreferrer">Leaflet</a> (BSD 2-clause license), served from this site: the page loads nothing from anywhere else.]]</li>
    </ul>
  </section>
</div>
'''


def extra(out_dir, values):
    # which tiles exist, by zoom: {"6": ["12/30", ...]} as "y/x"
    have = {}
    top = FILES + '/tiles'
    for z in sorted(os.listdir(top)):
        if not z.isdigit(): continue
        for y in os.listdir(f'{top}/{z}'):
            for f in os.listdir(f'{top}/{z}/{y}'):
                if f.endswith('.webp'): have.setdefault(z, []).append(f'{y}/{f[:-5]}')
    for z in have: have[z].sort(key=lambda s: tuple(int(n) for n in s.split('/')))
    os.makedirs(out_dir + '/map', exist_ok=True)
    json.dump(have, open(out_dir + '/map/tiles-have.json', 'w'), separators=(',', ':'))
