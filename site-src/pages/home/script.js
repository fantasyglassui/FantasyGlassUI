// Home (W2): the trailer, Try a theme, the hero's drawn frames (until there is a trailer), the before-and-after, the
// screenshots and the newest version.
(function () {
  "use strict";
  var FG = window.FG, $ = FG.$, esc = FG.esc, L = FG.L, reduce = FG.reduce;
  var NEWS = window.FG_NEWS || [], THEMES = window.FG_THEMES || [];

  // the hero bars fill in once the page is up
  requestAnimationFrame(function () { setTimeout(function () { var h = $("hero"); if (h) h.classList.remove("load"); }, 120); });
  // the frames tilt toward the pointer, like turning a gem in the light
  (function tilt() {
    var st = document.querySelector(".stage"); if (!st || reduce || !window.matchMedia("(hover: hover)").matches) return;
    var band = document.querySelector(".hero-band");
    band.addEventListener("pointermove", function (e) {
      var r = st.getBoundingClientRect(), x = (e.clientX - r.left - r.width / 2) / r.width, y = (e.clientY - r.top - r.height / 2) / r.height;
      st.style.setProperty("--ry", Math.max(-1, Math.min(1, x)) * 8 + "deg"); st.style.setProperty("--rx", Math.max(-1, Math.min(1, -y)) * 6 + "deg");
    });
    band.addEventListener("pointerleave", function () { st.style.setProperty("--ry", "0deg"); st.style.setProperty("--rx", "0deg"); });
  })();
  // sections rise into view
  (function reveal() {
    if (reduce || !("IntersectionObserver" in window)) return;
    var els = document.querySelectorAll("#why .grid, .gg, .fams, .latest, .compare, .thumbs");
    var io = new IntersectionObserver(function (es) { es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("in"); io.unobserve(e.target); } }); }, { rootMargin: "0px 0px -8% 0px" });
    els.forEach(function (el) { if (el.getBoundingClientRect().top > window.innerHeight) { el.classList.add("reveal"); io.observe(el); } });
  })();
  // the numbers in the hero count up
  (function count() {
    if (reduce) return;
    document.querySelectorAll("#facts b").forEach(function (b) {
      var end = parseFloat(b.textContent); if (!(end > 0) || b.textContent.indexOf(".") !== -1) return;
      var t0 = performance.now() + 500;
      (function step(t) { var f = Math.min(1, Math.max(0, (t - t0) / 1100)); b.textContent = Math.round(end * (1 - Math.pow(1 - f, 3))); if (f < 1) requestAnimationFrame(step); else b.textContent = end; })(t0);
    });
  })();
  // before and after: the line follows the slider, a drag, or the arrow keys
  (function compare() {
    var box = $("cmp"), r = $("cmprange"); if (!box || !r) return;
    function set(v) { v = Math.round(Math.max(0, Math.min(100, v)) * 2) / 2; r.value = v; box.style.setProperty("--x", v + "%"); }
    r.addEventListener("input", function () { set(+r.value); });
    r.addEventListener("keydown", function (e) {
      var d = { ArrowLeft: -2, ArrowDown: -2, ArrowRight: 2, ArrowUp: 2, PageDown: -10, PageUp: 10 }[e.key];
      if (e.key === "Home") d = -100; if (e.key === "End") d = 100;
      if (d) { e.preventDefault(); set(+r.value + d); }
    });
    var down = false;
    function at(e) { var b = box.getBoundingClientRect(); set((e.clientX - b.left) / b.width * 100); }
    box.addEventListener("pointerdown", function (e) { e.preventDefault(); down = true; box.setPointerCapture(e.pointerId); at(e); r.focus({ preventScroll: true }); });
    box.addEventListener("pointermove", function (e) { if (down) at(e); });
    box.addEventListener("pointerup", function () { down = false; });
    box.addEventListener("pointercancel", function () { down = false; });
  })();
  // and then keep moving, the way a fight does: health dips and is healed, the breath fills and goes off
  (function fight() {
    if (reduce) return;
    var stage = document.querySelector(".stage"); if (!stage) return;
    var bars = stage.querySelectorAll(".bar"), tick = 0;
    var hp = [94, 81, 66, 88, 94], boss = [72, 71, 69, 68, 66], cast = [42, 70, 100, 8, 25];
    setInterval(function () {
      tick = (tick + 1) % hp.length;
      var set = function (bar, v, label) { bar.style.setProperty("--v", v + "%"); var n = bar.querySelector(".num"); if (n && label !== undefined) n.textContent = label; };
      set(bars[0], hp[tick], hp[tick] + "%");
      set(bars[2], boss[tick], boss[tick] + "%");
      set(bars[3], cast[tick]);
    }, 1600);
  })();

  // screenshots: the first is the before-and-after slider
  var SHOTS = [
    ["celestial-live", "Before and after", "The same spot in Stormwind Harbor, before and after, in a Celestial theme."],
    ["celestial-screen", "Celestial", "A whole screen in a Celestial theme: party, player and target, cast bar, action bars and the minimap."],
    ["glass-overview", "Glass", "The same screen in a Glass theme."],
    ["fantasy-overview", "Fantasy", "The same screen in a Fantasy theme."],
    ["celestial-frames", "Unit frames", "The player and target frames up close, with the pet, the cast bar, buffs and the target's target."],
    ["glass-bags", "Bags", "The bags in one window, with item quality on every cut slot, and search, sort and equip best along the top."],
    ["glass-settings", "Options window", "The options window: every theme in one place, and every feature can be switched off."]
  ];
  var BIG = { "celestial-screen": 2400, "glass-overview": 2400, "fantasy-overview": 2400, "celestial-frames": 1500, "glass-bags": 540, "glass-settings": 1070 };
  var shotIdx = 0;
  function drawThumbs() {
    $("thumbs").innerHTML = SHOTS.map(function (s, i) {
      return '<button class="thumb" type="button" data-n="' + i + '" aria-pressed="' + (i === shotIdx) + '"><img class="cut" src="/shots/' + s[0] + '-480.webp" alt="" loading="lazy" decoding="async" width="320" height="180"><span>' + esc(L(s[1])) + "</span></button>";
    }).join("");
  }
  $("thumbs").addEventListener("click", function (ev) {
    var b = ev.target.closest("[data-n]"); if (!b) return;
    shotIdx = +b.getAttribute("data-n"); var s = SHOTS[shotIdx], img = $("shot-img");
    if (shotIdx) {
      var w = BIG[s[0]], set = ["/shots/" + s[0] + "-480.webp 480w", "/shots/" + s[0] + "-800.webp 800w"];
      if (w > 1600) set.push("/shots/" + s[0] + "-1600.webp 1600w");
      set.push("/shots/" + s[0] + ".webp " + w + "w");
      img.srcset = set.filter(function (x) { return parseInt(x.split(" ")[1], 10) <= w; }).join(", ");
      img.src = "/shots/" + s[0] + ".webp"; img.alt = L(s[2]);
    }
    $("shot-cap").textContent = L(s[2]);
    $("cmp").hidden = shotIdx !== 0; $("shot-big").hidden = shotIdx === 0;
    drawThumbs();
    var again = $("thumbs").querySelector('[data-n="' + shotIdx + '"]'); if (again) again.focus();
  });

  // the newest version: its number and what it brought
  function drawNews() {
    var v = NEWS[0]; if (!v) return;
    $("newv").textContent = v.v;
    $("news").innerHTML = v.items.slice(0, 4).map(function (x) { return "<li>" + esc(L(x)) + "</li>"; }).join("");
  }
  drawThumbs(); drawNews();
  FG.ready(function () { drawThumbs(); drawNews(); });

  // ---- the trailer: fetched only when it comes into view, playing by itself unless less motion is asked for
  (function trailer() {
    var v = $("tv"), b = $("tvbtn"); if (!v || !b) return;
    var loaded = false, wanted = !reduce, seen = false;   // wanted: the loop should play while it is in view
    function label() {
      var on = !v.paused;
      b.classList.toggle("playing", on);
      $("tvword").textContent = L(on ? b.getAttribute("data-pause") : b.getAttribute("data-play"));
    }
    function load() {
      if (loaded) return; loaded = true;
      ["webm", "mp4"].forEach(function (k) {
        var u = v.getAttribute("data-" + k); if (!u) return;
        var s = document.createElement("source"); s.src = u; s.type = "video/" + k; v.appendChild(s);
      });
      v.preload = "auto"; v.load();
    }
    function play() { load(); var p = v.play(); if (p && p.catch) p.catch(function () { wanted = false; label(); }); }
    v.addEventListener("play", label); v.addEventListener("pause", label);
    b.addEventListener("click", function () { if (v.paused) { wanted = true; play(); } else { wanted = false; v.pause(); } });
    label();
    if (!("IntersectionObserver" in window)) { if (wanted) play(); return; }
    new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        seen = e.isIntersecting;
        if (seen && wanted) play();
        else if (!seen && !v.paused) v.pause();
      });
    }, { threshold: 0.25 }).observe(v);
    FG.ready(label);
  })();

  // ---- try a theme: nine of them, three from each family, painted from their colors
  (function tryTheme() {
    var pick = $("trypick"), stage = $("trystage"); if (!pick || !stage) return;
    var NINE = { Glass: ["Smoke", "Frost", "Midnight"], Fantasy: ["Warm", "Dark", "Cold"], Celestial: ["Polaris", "Eclipse", "Blue Hour"] };
    var byName = {}, painted = [];
    THEMES.forEach(function (t) { if (t.bg) { byName[t.f + "|" + t.n] = t; painted.push(t); } });
    var cur = byName["Celestial|Polaris"] || painted[0]; if (!cur) return;
    function draw() {
      pick.innerHTML = Object.keys(NINE).map(function (f) {
        return '<fieldset><legend>' + esc(L(f)) + '</legend><div class="filters">' + NINE[f].map(function (n) {
          var t = byName[f + "|" + n]; if (!t) return "";
          return '<button class="chip" type="button" data-t="' + esc(f + "|" + n) + '" aria-pressed="' + (t === cur) + '"><i aria-hidden="true" style="background:' + t.bg + ';box-shadow:inset 0 0 0 3px ' + t.ac + ';border:1px solid ' + t.bd + '"></i>' + esc(L(t.n)) + "</button>";
        }).join("") + "</div></fieldset>";
      }).join("");
    }
    function paint() {
      var st = stage.style;
      st.setProperty("--bg", cur.bg); st.setProperty("--bd", cur.bd); st.setProperty("--ac", cur.ac); st.setProperty("--tx", cur.tx); st.setProperty("--pl", cur.pl || cur.bd);
      stage.classList.toggle("sky", cur.f === "Celestial"); stage.classList.toggle("pane", cur.f === "Glass"); stage.classList.toggle("gilt", cur.f === "Fantasy");
      $("trytitle").textContent = L(cur.n); $("tryname").textContent = L(cur.n); $("tryfam").textContent = L(cur.f);
      pick.querySelectorAll("[data-t]").forEach(function (b) { b.setAttribute("aria-pressed", String(b.getAttribute("data-t") === cur.f + "|" + cur.n)); });
    }
    pick.addEventListener("click", function (ev) { var b = ev.target.closest("[data-t]"); if (!b) return; cur = byName[b.getAttribute("data-t")] || cur; paint(); });
    $("tryany").addEventListener("click", function () {
      var next = cur; while (painted.length > 1 && next === cur) next = painted[Math.floor(Math.random() * painted.length)];
      cur = next; paint();
    });
    $("trywear").addEventListener("click", function () { FG.wear(cur); });
    draw(); paint();
    FG.ready(function () { draw(); paint(); });
  })();
})();
