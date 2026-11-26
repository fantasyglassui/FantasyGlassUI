// Themes: the gallery, the chosen theme, wearing one on the site, and the theme maker (moved from the old long page).
// Links: /themes/?theme=celestial-polaris opens a theme, /themes/?code=SUIT1!...#maker opens a made one.
(function () {
  "use strict";
  var FG = window.FG, $ = FG.$, esc = FG.esc, L = FG.L, F = FG.F, reduce = FG.reduce;
  var THEMES = window.FG_THEMES || [];
  var fam = "All", chosenIdx = 0;
  var CLASS = "linear-gradient(135deg,#c79c6e,#f58cba,#abd473,#3fc7eb,#8787ed,#fff569,#ff7d0a,#0070de)";
  function pane(t) {
    var bg = t.bg || "#151a2c", bd = t.bd || "#4a4f63", ac = t.ac || "#f0c66b", tx = t.tx || "#e7e9f4";
    var ground, extra = "";
    if (t.f === "Glass") ground = "background:linear-gradient(160deg,#2c4a6e,#5b3a64 55%,#1d2b3b);";
    else ground = "background:" + bg + ";";
    var face;
    if (!t.bg) face = "background:" + CLASS + ";";
    else if (t.f === "Glass") face = "background:linear-gradient(180deg," + hexA(tx, .14) + "," + hexA(bg, .55) + " 30%," + hexA(bg, .72) + ");box-shadow:inset 0 1px 0 " + hexA("#ffffff", .55) + ",inset 0 0 0 1px " + hexA(bd, .8) + ";";
    else if (t.f === "Celestial") face = "background:radial-gradient(1px 1px at 20% 30%," + tx + ",transparent),radial-gradient(1px 1px at 70% 20%," + tx + ",transparent),radial-gradient(1.5px 1.5px at 85% 60%," + ac + ",transparent),radial-gradient(1px 1px at 40% 75%," + tx + ",transparent),linear-gradient(0deg," + hexA(ac, .22) + "," + bg + " 45%," + shade(bg, -.4) + ");box-shadow:inset 0 0 0 1px " + hexA(bd, .9) + ";";
    else face = "background:repeating-linear-gradient(45deg," + hexA("#ffffff", .025) + " 0 2px,transparent 2px 5px)," + bg + ";box-shadow:inset 0 0 0 1px " + bd + ",inset 0 0 0 2px #000;";
    if (t.f === "Fantasy" && t.bg) extra = '<span style="position:absolute;top:4px;left:4px;width:8px;height:8px;border-top:2px solid ' + ac + ';border-left:2px solid ' + ac + '"></span><span style="position:absolute;bottom:4px;right:4px;width:8px;height:8px;border-bottom:2px solid ' + ac + ';border-right:2px solid ' + ac + '"></span>';
    return '<div class="mini cut" style="' + ground + '"><div class="pane" style="' + face + 'color:' + tx + '"><b style="color:' + ac + '">' + esc(t.n) + '</b><i style="background:' + ac + ';box-shadow:0 0 8px ' + ac + '"></i><u style="background:' + tx + '"></u></div>' + extra + "</div>";
  }
  function hexA(hex, a) { var n = parseInt(hex.slice(1), 16); return "rgba(" + (n >> 16) + "," + ((n >> 8) & 255) + "," + (n & 255) + "," + a + ")"; }
  function shade(hex, f) { var n = parseInt(hex.slice(1), 16), r = n >> 16, g = (n >> 8) & 255, b = n & 255; var k = 1 + f; return "rgb(" + Math.round(r * k) + "," + Math.round(g * k) + "," + Math.round(b * k) + ")"; }
  var themesAll = false, PER = (window.matchMedia && window.matchMedia("(max-width: 600px)").matches) ? 4 : 6;
  function list() {
    var seen = {};
    return THEMES.map(function (t, i) { return { t: t, i: i }; }).filter(function (e) {
      if (fam !== "All" && e.t.f !== fam) return false;
      if (themesAll || fam !== "All") return true;
      seen[e.t.f] = (seen[e.t.f] || 0) + 1;                     // a row from each family to start
      return seen[e.t.f] <= PER || e.i === chosenIdx;
    });
  }
  function drawChosen() {
    var t = THEMES[chosenIdx]; if (!t) return;
    var about = { Glass: "See-through panes with soft shadows and a bright top edge.", Fantasy: "Solid panels with a dark rim, a grain and gold corner ornaments.", Celestial: "A moving night sky with twinkling stars, a breathing horizon and now and then a shooting star." }[t.f];
    var d = t.d ? L(t.d) : "";
    $("chosen").innerHTML = pane(t) + '<div><div class="eyebrow">' + esc(L(t.f)) + '</div><h3>' + esc(t.n) + '</h3><p>' + esc(d ? d.charAt(0).toUpperCase() + d.slice(1) + ". " : "") + esc(L(about)) + '</p><p>' + F("In the game: %s, then the %s row.", "<code>/fgui look</code>", esc(L(t.f))) + '</p>' +
      (t.bg ? '<div class="acts"><button class="btn" type="button" id="wear">' + L("Wear it on this page") + '</button><button class="btn line" type="button" id="tweak">' + L("Change its colors") + '</button><button class="btn line" type="button" id="tlink">' + L("Copy a link") + '</button></div>' : '<p>' + L("This one takes your class color, so it looks different for every class.") + '</p>') + '</div>';
  }
  function drawGallery() {
    var fams = ["All", "Glass", "Fantasy", "Celestial"];
    $("tfilters").innerHTML = fams.map(function (f) {
      var n = f === "All" ? THEMES.length : THEMES.filter(function (t) { return t.f === f; }).length;
      return '<button class="chip cut" type="button" data-f="' + f + '" aria-pressed="' + (f === fam) + '">' + esc(L(f)) + '<span>' + n + '</span></button>';
    }).join("");
    $("gallery").innerHTML = list().map(function (e) {
      return '<button class="tcard" type="button" data-i="' + e.i + '" aria-pressed="' + (e.i === chosenIdx) + '">' + pane(e.t) + '<span class="tn">' + esc(e.t.n) + '</span><span class="td">' + esc(L(e.t.d || e.t.f)) + "</span></button>";
    }).join("");
    $("tmore").hidden = themesAll || fam !== "All";
    $("tmore").textContent = F("Show all %d themes", THEMES.length);
  }
  $("tfilters").addEventListener("click", function (ev) { var b = ev.target.closest("[data-f]"); if (!b) return; fam = b.getAttribute("data-f"); drawGallery(); });
  $("gallery").addEventListener("click", function (ev) {
    var b = ev.target.closest("[data-i]"); if (!b) return;
    chosenIdx = +b.getAttribute("data-i"); drawChosen(); drawGallery();
    var c = $("chosen"); if (c.getBoundingClientRect().top < 60) c.scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" });
  });
  // wear a theme: the whole site takes its colors (and goes dark, as every theme is); site.js keeps it on every page
  function wear(t) { FG.wear(t); }
  $("chosen").addEventListener("click", function (ev) { if (ev.target.closest("#wear")) wear(THEMES[chosenIdx]); });
  // theme maker: three colors and a family, worked out the way the add-on's ThemeFromDef does it ----------
  var mk = { name: "My theme", f: "Celestial", panel: "#121a33", rim: "#5a6a9a", accent: "#f0c66b" };
  var STYLE = { Glass: "GLASS", Fantasy: "FANTASY", Celestial: "CELESTIAL" };
  function rgb01(hex) { var n = parseInt(hex.slice(1), 16); return [(n >> 16) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255]; }
  function hex01(c) { return "#" + c.map(function (v) { var x = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16); return x.length < 2 ? "0" + x : x; }).join(""); }
  function lift(c, f, add) { return c.map(function (v) { return Math.min(1, v * f + add); }); }
  function makerTheme() {
    var p = rgb01(mk.panel), pale = (p[0] * .30 + p[1] * .59 + p[2] * .11) > .55, fan = mk.f === "Fantasy";
    var text = fan ? (pale ? [.12, .10, .08] : [.90, .87, .80]) : (pale ? [.08, .09, .11] : [.93, .95, .98]);
    var plate = pale ? lift(p, .82, 0) : (fan ? lift(p, 2.25, .01) : lift(p, 2.6, .02));
    return { f: mk.f, n: mk.name || "My theme", d: "", bg: mk.panel, bd: mk.rim, ac: mk.accent, tx: hex01(text), pl: hex01(plate) };
  }
  function cleanName(n) {
    n = String(n || "").replace(/[|:\u0000-\u001f]/g, "").trim();
    var enc = window.TextEncoder ? new TextEncoder() : null;
    while (enc && enc.encode(n).length > 24) n = n.slice(0, -1);     // the add-on keeps 24 bytes
    return n || "My theme";
  }
  // the add-on's share format: S<bytes>:text, N<number>; and { key value ... } with the keys sorted
  function encode(v) {
    if (typeof v === "number") return "N" + String(Math.round(v * 10000) / 10000) + ";";
    if (typeof v === "string") return "S" + (window.TextEncoder ? new TextEncoder().encode(v).length : v.length) + ":" + v;
    var keys = Array.isArray(v) ? v.map(function (_, i) { return i + 1; }) : Object.keys(v);
    keys.sort(function (a, b) { a = String(a); b = String(b); return a < b ? -1 : a > b ? 1 : 0; });
    return "{" + keys.map(function (k) { return encode(k) + encode(Array.isArray(v) ? v[k - 1] : v[k]); }).join("") + "}";
  }
  function decode(s) {
    var i = 0;
    function one() {
      var c = s.charAt(i), j, n;
      if (c === "T") { i++; return true; } if (c === "F") { i++; return false; }
      if (c === "N") { j = s.indexOf(";", i); n = parseFloat(s.slice(i + 1, j)); if (j < 0 || isNaN(n)) throw 0; i = j + 1; return n; }
      if (c === "S") {
        j = s.indexOf(":", i); n = parseInt(s.slice(i + 1, j), 10); if (j < 0 || isNaN(n)) throw 0;
        var bytes = new TextEncoder().encode(s.slice(j + 1)), str = new TextDecoder().decode(bytes.slice(0, n));
        i = j + 1 + str.length; return str;
      }
      if (c === "{") { i++; var t = {}; while (s.charAt(i) !== "}") { if (i >= s.length) throw 0; var k = one(); t[k] = one(); } i++; return t; }
      throw 0;
    }
    var v = one(); if (i !== s.length) throw 0; return v;
  }
  function triple(t) { return t && typeof t[1] === "number" && typeof t[2] === "number" && typeof t[3] === "number" ? hex01([t[1], t[2], t[3]]) : null; }
  function makerCode() {
    var round = function (c) { return c.map(function (v) { return Math.round(v * 10000) / 10000; }); };
    return "SUIT1!" + encode({ name: cleanName(mk.name), panel: round(rgb01(mk.panel)), rim: round(rgb01(mk.rim)), accent: round(rgb01(mk.accent)), style: STYLE[mk.f] });
  }
  function drawMaker() {
    $("mkpane").innerHTML = pane(makerTheme());
    $("mkfam").innerHTML = ["Glass", "Fantasy", "Celestial"].map(function (f) { return '<button class="chip cut" type="button" data-mf="' + f + '" aria-pressed="' + (f === mk.f) + '">' + L(f) + "</button>"; }).join("");
    ["panel", "rim", "accent"].forEach(function (k) { $("mk" + k).value = mk[k]; $("mk" + k + "hex").textContent = mk[k].toUpperCase(); });
    $("mkcode").value = makerCode();
  }
  ["panel", "rim", "accent"].forEach(function (k) { $("mk" + k).addEventListener("input", function () { mk[k] = this.value; drawMaker(); }); });
  $("mkname").addEventListener("input", function () { mk.name = this.value; drawMaker(); });
  $("mkfam").addEventListener("click", function (ev) { var b = ev.target.closest("[data-mf]"); if (!b) return; mk.f = b.getAttribute("data-mf"); drawMaker(); });
  $("mkwear").addEventListener("click", function () { var t = makerTheme(); t.n = cleanName(mk.name); wear(t); });
  $("mkrandom").addEventListener("click", function () {
    var h = Math.random() * 360, hsl = function (h, s, l) { var c = document.createElement("canvas").getContext("2d"); c.fillStyle = "hsl(" + h + "," + s + "%," + l + "%)"; return c.fillStyle; };
    mk.panel = hsl(h, 30 + Math.random() * 30, 6 + Math.random() * 8); mk.rim = hsl(h + (Math.random() * 40 - 20), 25 + Math.random() * 30, 35 + Math.random() * 20);
    mk.accent = hsl(h + 120 + Math.random() * 120, 70 + Math.random() * 25, 55 + Math.random() * 15);
    mk.f = ["Glass", "Fantasy", "Celestial"][Math.floor(Math.random() * 3)]; drawMaker();
  });
  $("mkcopy").addEventListener("click", function () {
    var b = this, code = makerCode();
    FG.copy(code, function (ok) { if (!ok) $("mkcode").select(); b.textContent = ok ? L("Copied") : L("Select the code and copy it"); setTimeout(function () { b.textContent = L("Copy the code"); }, 2000); });
  });
  function loadCode(txt) {
    var msg = $("mkinmsg");
    if (!txt) { msg.textContent = ""; return false; }
    try {
      if (txt.indexOf("SUIT1!") !== 0) throw 0;
      var d = decode(txt.slice(6)), p = triple(d.panel), r = triple(d.rim), a = triple(d.accent);
      if (!p || !r || !a) throw 0;
      mk.panel = p; mk.rim = r; mk.accent = a; mk.f = d.style === "FANTASY" ? "Fantasy" : d.style === "GLASS" ? "Glass" : "Celestial";
      mk.name = typeof d.name === "string" ? d.name : "My theme"; $("mkname").value = mk.name;
      drawMaker(); msg.textContent = L("Loaded. Change it as you like."); return true;
    } catch (e) { msg.textContent = L("That isn't a theme code (they start with SUIT1!)."); return false; }
  }
  $("mkin").addEventListener("input", function () { loadCode(this.value.trim()); });
  // links to a theme or to a made theme: fantasyglassui.com/themes/?theme=celestial-polaris, ?code=SUIT1!...#maker
  function slug(t) { return (t.f + "-" + t.n).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }
  function pageUrl() { return FG.site.replace(/\/$/, "") + FG.url("themes/"); }
  function copyLink(btn, url, label) {
    FG.copy(url, function (ok) { btn.textContent = ok ? L("Link copied") : url; setTimeout(function () { btn.textContent = L(label); }, 2200); });
  }
  $("chosen").addEventListener("click", function (ev) {
    var b = ev.target.closest("#tlink"); if (!b) return;
    copyLink(b, pageUrl() + "?theme=" + slug(THEMES[chosenIdx]), "Copy a link");
  });
  $("mklink").addEventListener("click", function () { copyLink(this, pageUrl() + "?code=" + encodeURIComponent(makerCode()) + "#maker", "Copy a link to it"); });
  // "Change its colors" on the chosen theme starts the maker from it
  $("chosen").addEventListener("click", function (ev) {
    if (!ev.target.closest("#tweak")) return;
    var t = THEMES[chosenIdx]; if (!t.bg) return;
    mk = { name: cleanName(t.n + " (mine)"), f: t.f, panel: t.bg, rim: t.bd, accent: t.ac };
    $("mkname").value = mk.name; drawMaker();
    $("maker").scrollIntoView({ behavior: reduce ? "auto" : "smooth", block: "start" }); $("mkname").focus({ preventScroll: true });
  });
  drawMaker();
  for (var k = 0; k < THEMES.length; k++) if (THEMES[k].n === "Polaris") chosenIdx = k;
  try {                                  // a theme worn before 13.0 was kept by its name: wear it again by its colors
    var worn = localStorage.getItem("fg-wear");
    if (worn && worn.indexOf("custom:") !== 0) for (var j = 0; j < THEMES.length; j++) if (THEMES[j].f + ":" + THEMES[j].n === worn) { chosenIdx = j; wear(THEMES[j]); }
    var w = FG.worn(); if (w) for (var k2 = 0; k2 < THEMES.length; k2++) if (THEMES[k2].n === w.n && THEMES[k2].f === w.f) chosenIdx = k2;
  } catch (e) {}
  drawChosen(); drawGallery();

  (function openLink() {
    var q = location.search, m = /[?&]theme=([a-z0-9-]+)/.exec(q), c = /[?&]code=([^&#]+)/.exec(q), go = null;
    if (m) for (var i = 0; i < THEMES.length; i++) if (slug(THEMES[i]) === m[1]) { chosenIdx = i; fam = "All"; go = "themes"; }
    if (c) { var code = ""; try { code = decodeURIComponent(c[1]); } catch (e) {} if (code) { $("mkin").value = code; if (loadCode(code)) go = "maker"; } }
    if (go) { drawChosen(); drawGallery(); if (go === "maker") setTimeout(function () { var el = $(go); if (el) el.scrollIntoView({ block: "start" }); }, 60); }
  })();
  $("tmore").addEventListener("click", function () { themesAll = true; drawGallery(); });
  FG.ready(function () { drawChosen(); drawGallery(); drawMaker(); });
})();
