// The site's shared script, on every page: the menu on a phone, the language switcher, light and dark,
// a worn theme, and the helpers a page's own script uses (window.FG). A page's own script runs after this.
(function () {
  "use strict";
  var root = document.documentElement, $ = function (id) { return document.getElementById(id); };
  var lang = root.getAttribute("data-lang") || "en";
  var FG = window.FG = {
    lang: lang,
    base: lang === "en" ? "/" : "/" + lang + "/",          // this language's home, so links stay in it
    site: "https://fantasyglassui.com/",
    words: {},
    reduce: !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches),
    $: $,
    esc: function (s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); },
    // a page's own words, in this page's language (the build translates the page itself; this is for what a script writes)
    L: function (s) { return (FG.words && FG.words[s]) || s; },
    F: function (s) { var a = arguments, i = 1; return FG.L(s).replace(/%[sd]/g, function () { return a[i++]; }); },
    url: function (path) { return FG.base + (path || ""); },
    copy: function (text, done) {
      try { navigator.clipboard.writeText(text).then(function () { done(true); }, function () { done(false); }); } catch (e) { done(false); }
    }
  };
  // FG.ready(fn): fn runs once this language's words are loaded (at once in English)
  var waiting = [], loaded = lang === "en";
  FG.ready = function (fn) { if (loaded) fn(); else waiting.push(fn); };
  if (!loaded) {
    fetch("/i18n/" + lang + ".json").then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (w) { FG.words = w; }, function () {})
      .then(function () { loaded = true; waiting.splice(0).forEach(function (fn) { fn(); }); });
  }

  // the menu on a phone
  var menu = $("menu-btn"), nav = $("site-nav");
  if (menu && nav) {
    menu.addEventListener("click", function () {
      var open = !nav.classList.contains("open");
      nav.classList.toggle("open", open); menu.setAttribute("aria-expanded", String(open));
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && nav.classList.contains("open")) { nav.classList.remove("open"); menu.setAttribute("aria-expanded", "false"); menu.focus(); }
    });
  }

  // the language switcher: the same page in another language; the choice is remembered
  var sel = $("lang");
  if (sel) sel.addEventListener("change", function () {
    try { localStorage.setItem("fg-lang", sel.options[sel.selectedIndex].getAttribute("data-code")); } catch (e) {}
    location.href = sel.value + location.search + location.hash;
  });
  document.querySelectorAll(".foot-langs a[data-code]").forEach(function (a) {
    a.addEventListener("click", function () { try { localStorage.setItem("fg-lang", a.getAttribute("data-code")); } catch (e) {} });
  });

  // light and dark: the system's choice until the button is pressed, then the button's
  var mode = $("mode");
  function isDark() {
    var t = root.getAttribute("data-theme");
    if (t) return t === "dark";
    return !(window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches);
  }
  function showMode() { if (mode) mode.setAttribute("aria-pressed", String(isDark())); }
  if (mode) mode.addEventListener("click", function () {
    if (worn) FG.unwear();
    var next = isDark() ? "light" : "dark";
    root.setAttribute("data-theme", next);
    try { localStorage.setItem("fg-theme", next); } catch (e) {}
    showMode();
  });
  if (window.matchMedia) { var mq = window.matchMedia("(prefers-color-scheme: light)"); if (mq.addEventListener) mq.addEventListener("change", showMode); }

  // a worn theme (from the Themes page): the whole site takes its colours, in dark mode, until it is put away
  var TOKENS = ["--ground", "--bar", "--band", "--card", "--shot", "--raised", "--rule", "--line", "--text", "--dim", "--faint", "--nav", "--gold", "--gold-hover", "--eyebrow", "--frost", "--frost-hover"];
  var worn = null, before = null;
  function mix(a, b, f) {
    var x = parseInt(a.slice(1), 16), y = parseInt(b.slice(1), 16);
    return "rgb(" + [16, 8, 0].map(function (sh) { var p = (x >> sh) & 255, q = (y >> sh) & 255; return Math.round(p + (q - p) * f); }).join(",") + ")";
  }
  var hex = /^#[0-9a-f]{6}$/i;
  FG.wear = function (t) {
    if (!t || !hex.test(t.bg || "") || !hex.test(t.tx || "") || !hex.test(t.ac || "") || !hex.test(t.bd || "")) return;
    if (before === null) before = root.getAttribute("data-theme") || "";
    root.setAttribute("data-theme", "dark");
    var pl = hex.test(t.pl || "") ? t.pl : t.bg, ground = mix(t.bg, "#000000", .45);
    var v = { "--ground": ground, "--bar": mix(t.bg, "#000000", .3), "--band": mix(t.bg, "#000000", .2), "--card": t.bg, "--shot": t.bg, "--raised": pl,
      "--rule": mix(t.bd, t.bg, .5), "--line": t.bd, "--text": t.tx, "--dim": mix(t.tx, t.bg, .3), "--faint": mix(t.tx, t.bg, .45), "--nav": mix(t.tx, t.bg, .2),
      "--gold": t.ac, "--gold-hover": mix(t.ac, "#ffffff", .25), "--eyebrow": t.ac, "--frost": mix(t.ac, "#ffffff", .35), "--frost-hover": mix(t.ac, "#ffffff", .6) };
    for (var k in v) root.style.setProperty(k, v[k]);
    worn = t; showMode();
    var b = $("unwear"); if (b) { $("wearname").textContent = t.n || ""; b.hidden = false; }
    try { localStorage.setItem("fg-wear", "custom:" + JSON.stringify({ f: t.f, n: t.n, bg: t.bg, bd: t.bd, ac: t.ac, tx: t.tx, pl: pl })); } catch (e) {}
  };
  FG.unwear = function () {
    TOKENS.forEach(function (k) { root.style.removeProperty(k); });
    if (before !== null) { if (before) root.setAttribute("data-theme", before); else root.removeAttribute("data-theme"); }
    before = null; worn = null; showMode();
    var b = $("unwear"); if (b) b.hidden = true;
    try { localStorage.removeItem("fg-wear"); } catch (e) {}
  };
  FG.worn = function () { return worn; };
  var un = $("unwear"); if (un) un.addEventListener("click", function () { FG.unwear(); });
  try {
    var w = localStorage.getItem("fg-wear");
    if (w && w.indexOf("custom:") === 0) FG.wear(JSON.parse(w.slice(7)));
  } catch (e) {}
  showMode();
})();
