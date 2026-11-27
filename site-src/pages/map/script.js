// The world map (pages/map/): Leaflet (served from /map/leaflet/) on a flat grid of pixels (L.CRS.Simple). The size of
// the whole map at its closest zoom, the tile size and the sea come from /map/tiles/meta.json; /map/tiles-have.json
// lists the tiles there are (open sea has none, so none is asked for); the places come from /map/markers.json:
//   [{"name": "...", "category": "...", "coords": [x, y], "description": "..."}]   (x, y: pixels from the top left)
// Every word of a place goes in with textContent, never as HTML. ?pins in the address shows the pin helper: a click on
// the map gives that spot's coords, ready to paste into markers.json.
(function () {
  "use strict";
  var box = FG.$("worldmap");
  if (!box || !window.L || !window.fetch) return;
  var pinsOn = /(?:^|&)pins(?:=|&|$)/.test(location.search.slice(1));
  var json = function (url) { return fetch(url).then(function (r) { if (!r.ok) throw new Error(url + ": " + r.status); return r.json(); }); };

  Promise.all([json("/map/tiles/meta.json"), json("/map/tiles-have.json").catch(function () { return null; })]).then(function (got) {
    var meta = got[0], haveList = got[1];
    var W = +meta.width, H = +meta.height, Z = +meta.maxZoom, TS = +meta.tileSize || 256;
    if (meta.sea) box.parentNode.style.setProperty("--sea", meta.sea);
    var have = null;
    if (haveList) { have = {}; Object.keys(haveList).forEach(function (z) { haveList[z].forEach(function (k) { have[z + "/" + k] = 1; }); }); }

    var map = L.map(box, { crs: L.CRS.Simple, minZoom: 0, maxZoom: Z + 1, zoomSnap: 0.5, zoomDelta: 0.5, wheelPxPerZoomLevel: 120,
                           attributionControl: false, zoomControl: false, maxBoundsViscosity: 1 });
    L.control.zoom({ zoomInTitle: FG.L("Zoom in"), zoomOutTitle: FG.L("Zoom out") }).addTo(map);
    var toLatLng = function (x, y) { return map.unproject([x, y], Z); };
    var bounds = L.latLngBounds(toLatLng(0, H), toLatLng(W, 0));
    map.setMaxBounds(bounds);

    // the tiles: none is asked for where the list says there is only sea
    var Tiles = L.TileLayer.extend({
      createTile: function (c, done) {
        if (have && !have[c.z + "/" + c.y + "/" + c.x]) {
          var sea = document.createElement("div");
          setTimeout(function () { done(null, sea); }, 0);
          return sea;
        }
        return L.TileLayer.prototype.createTile.call(this, c, done);
      }
    });
    new Tiles("/map/tiles/{z}/{y}/{x}.webp", { tileSize: TS, minZoom: 0, maxZoom: Z + 1, maxNativeZoom: Z, noWrap: true,
                                               bounds: bounds, keepBuffer: 3 }).addTo(map);

    // the whole map fits at first; you can't zoom out further than that
    var fit = function () {
      var z = map.getBoundsZoom(bounds, false);
      map.setMinZoom(Math.max(0, Math.floor(z * 2) / 2));
    };
    map.fitBounds(bounds);
    fit();
    map.on("resize", fit);

    // the places, by kind: Zones and Dungeons show at first, the others with their button. A kind's name is translated
    // (site_tr.py, World map block); a place's own words (name, description) are the game's English, as plain text.
    var ON = { "Zones": 1, "Dungeons": 1 };
    var kindName = function (k) {
      return ({ "Zones": FG.L("Zones"), "Dungeons": FG.L("Dungeons"), "Raids": FG.L("Raids"), "Flight masters": FG.L("Flight masters"),
                "Boats and zeppelins": FG.L("Boats and zeppelins"), "Other": FG.L("Other") })[k] || k;
    };
    json("/map/markers.json").then(function (list) { FG.ready(function () {
      if (!Array.isArray(list)) list = (list && list.markers) || [];
      var kinds = {}, order = [];
      list.forEach(function (m) {
        if (!m || typeof m.name !== "string" || !Array.isArray(m.coords) || m.coords.length !== 2) return;
        var x = +m.coords[0], y = +m.coords[1];
        if (!isFinite(x) || !isFinite(y) || x < 0 || y < 0 || x > W || y > H) return;
        var kind = typeof m.category === "string" && m.category ? m.category : "Other";
        if (!kinds[kind]) { kinds[kind] = { layer: L.layerGroup(), n: 0 }; order.push(kind); if (ON[kind]) kinds[kind].layer.addTo(map); }
        var pop = document.createElement("div");
        var name = document.createElement("strong"); name.textContent = m.name; pop.appendChild(name);
        var k = document.createElement("span"); k.className = "kind"; k.textContent = kindName(kind); pop.appendChild(k);
        if (typeof m.description === "string" && m.description) {
          var p = document.createElement("p"); p.textContent = m.description; pop.appendChild(p);
        }
        L.marker(toLatLng(x, y), { title: m.name, alt: m.name, riseOnHover: true,
                                   icon: L.divIcon({ className: "map-pin k-" + kind.toLowerCase().replace(/[^a-z]+/g, "-"), iconSize: [18, 18], iconAnchor: [9, 9], popupAnchor: [0, -10] }) })
          .bindPopup(pop, { maxWidth: 280 }).addTo(kinds[kind].layer);
        kinds[kind].n++;
      });
      if (!order.length) { FG.$("map-none").hidden = false; return; }
      var row = FG.$("map-cats");
      order.forEach(function (kind) {
        var b = document.createElement("button");
        b.type = "button"; b.className = "chip"; b.setAttribute("aria-pressed", ON[kind] ? "true" : "false");
        b.dataset.kind = kind;
        b.textContent = kindName(kind);
        var n = document.createElement("span"); n.textContent = String(kinds[kind].n); b.appendChild(n);
        b.addEventListener("click", function () {
          var on = b.getAttribute("aria-pressed") !== "true";
          b.setAttribute("aria-pressed", String(on));
          if (on) map.addLayer(kinds[kind].layer); else map.removeLayer(kinds[kind].layer);
        });
        row.appendChild(b);
      });
      row.hidden = false;
    }); }, function () {});

    map.on("popupopen", function (e) {
      var x = e.popup.getElement() && e.popup.getElement().querySelector(".leaflet-popup-close-button");
      if (x) x.setAttribute("aria-label", FG.L("Close"));
    });

    // the pin helper, only with ?pins
    if (pinsOn) {
      var out = FG.$("pins-out"), copy = FG.$("pins-copy"), text = "";
      FG.$("pins").hidden = false;
      map.on("click", function (e) {
        var p = map.project(e.latlng, Z), x = Math.round(p.x), y = Math.round(p.y);
        if (x < 0 || y < 0 || x > W || y > H) return;
        text = '{"name": "", "category": "", "coords": [' + x + ", " + y + '], "description": ""}';
        out.textContent = text;
        copy.disabled = false;
      });
      copy.addEventListener("click", function () {
        FG.copy(text, function (ok) { if (ok) { copy.textContent = FG.L("Copied"); setTimeout(function () { copy.textContent = FG.L("Copy"); }, 1500); } });
      });
    }
    FG.ready(function () {
      var c = box.querySelectorAll(".leaflet-control-zoom a");
      if (c[0]) { c[0].title = FG.L("Zoom in"); c[0].setAttribute("aria-label", FG.L("Zoom in")); }
      if (c[1]) { c[1].title = FG.L("Zoom out"); c[1].setAttribute("aria-label", FG.L("Zoom out")); }
    });
  }, function (e) {
    var w = FG.$("map-wait");
    w.textContent = FG.L("The map could not be loaded. Try again later.");
    w.style.display = "block";
    if (window.console) console.warn(e);
  });
})();
