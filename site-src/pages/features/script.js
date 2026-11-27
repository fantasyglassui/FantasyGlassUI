// Features (W2): every switch in the add-on, from /features.json. One section at a time (picked in the list on the
// left, remembered in the address: /features/#s-bags-and-bag-rules), or one search across all of them.
(function () {
  "use strict";
  var FG = window.FG, $ = FG.$, esc = FG.esc, L = FG.L, F = FG.F;
  var DATA = null, sec = null, opened = {}, FIRST = 12;
  // what each section is for (the section's title in features.json -> a line under its heading)
  function about(title) { return {
    "Frames, bars and nameplates": L("Frames of its own for you, your target, your party, raids and bosses, nameplates of its own, and every bar cut to match."),
    "Action bars": L("The game's action bars restyled, or eight bars of the add-on's own, with cooldown numbers and key text."),
    "Combat and groups": L("What helps in a fight and in a group: threat, boss notes, cooldowns, loot, gear checks, runs and farming sessions."),
    "Minimap and info bar": L("The minimap in three shapes, its buttons gathered up, the world map, and a thin bar of numbers along the top."),
    "Windows, tooltips and quests": L("The game's own windows and tooltips in your theme, and help with gear, quests and goals."),
    "Look, sounds and notifications": L("Textures, lettering and sounds, and the small notices: the login briefing, milestones and the weekly recap."),
    "Chat and people": L("A cleaner chat, and what you see and keep about other players."),
    "Bags and bag rules": L("All your bags in one window, sorted into sections by rules you can change."),
    "Vendors, trainers and mail": L("Selling, repairs, the auction house and its prices, trainers and the mailbox."),
    "Done for you": L("Small jobs it can do for you. Each one has its own switch."),
    "Game settings": L("The game's own settings as switches. Switching one off puts back what it was."),
    "Quest guides": L("The Guide tab's switches and the planner window's: what the route takes in, its stops, the map, and planning with a friend.")
  }[title]; }
  function slug(t) { return "s-" + t.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, ""); }
  function mark(text, q) {
    var t = esc(text); if (!q) return t;
    var i = t.toLowerCase().indexOf(esc(q).toLowerCase()); if (i < 0) return t;
    return t.slice(0, i) + "<mark>" + t.slice(i, i + esc(q).length) + "</mark>" + t.slice(i + esc(q).length);
  }
  function rows(items, q) {
    return '<ul class="frows">' + items.map(function (it) {
      return "<li><b>" + mark(L(it.label), q) + "</b>" + (it.desc ? "<span>" + mark(L(it.desc), q) + "</span>" : "") + "</li>";
    }).join("") + "</ul>";
  }
  function shot(title) {
    var f = document.querySelector('#fshots [data-s="' + title.replace(/"/g, "") + '"]');
    return f ? f.outerHTML : "";
  }
  function draw() {
    if (!DATA) return;
    var q = $("fsearch").value.trim().toLowerCase(), total = 0, shown = 0, html = "";
    var secs = DATA.sections;
    if (!sec) sec = secs[0].title;
    $("fnav").innerHTML = secs.map(function (s) {
      return '<li><button type="button" data-s="' + esc(s.title) + '"' + (!q && s.title === sec ? ' aria-current="true"' : "") + ">" + esc(L(s.title)) + '<span class="n">' + s.items.length + "</span></button></li>";
    }).join("");
    secs.forEach(function (s) { total += s.items.length; });
    if (q) {
      secs.forEach(function (s) {
        var items = s.items.filter(function (it) { return (it.label + " " + it.desc + " " + L(it.label) + " " + L(it.desc)).toLowerCase().indexOf(q) !== -1; });
        if (!items.length) return;
        shown += items.length;
        html += '<section class="fsec"><h2 class="fh">' + esc(L(s.title)) + " <small>" + items.length + "</small></h2>" + rows(items, q) + "</section>";
      });
      html = html || '<p class="count">' + L("No switch matches that. Try a shorter word.") + "</p>";
    } else {
      var i = 0; secs.forEach(function (s, n) { if (s.title === sec) i = n; });
      var s = secs[i], all = opened[s.title] || s.items.length <= FIRST + 3, next = secs[(i + 1) % secs.length];
      shown = s.items.length;
      html = '<section class="fsec" aria-labelledby="fh"><h2 class="fh" id="fh" tabindex="-1">' + esc(L(s.title)) + "</h2>" +
        (about(s.title) ? '<p class="lede">' + esc(about(s.title)) + "</p>" : "") + shot(s.title) +
        rows(all ? s.items : s.items.slice(0, FIRST), "") +
        (all ? "" : '<button class="btn line small more" type="button" data-open="' + esc(s.title) + '">' + F("Show all %d", s.items.length) + "</button>") + "</section>" +
        '<div class="fnext card filled"><p>' + F("Next: %s", "<b>" + esc(L(next.title)) + "</b>") + '</p><button class="btn line small" type="button" data-s="' + esc(next.title) + '">' + esc(L(next.title)) + ' <span aria-hidden="true">→</span></button></div>';
    }
    $("fbody").innerHTML = html;
    $("fcount").textContent = q ? F("%d of %d switches", shown, total) : F("%d switches", total);
  }
  function go(title, focus) {
    sec = title; $("fsearch").value = ""; draw();
    try { history.replaceState(null, "", "#" + slug(title)); } catch (e) {}
    if (focus) { var h = $("fh"); if (h) { h.focus({ preventScroll: true }); h.scrollIntoView({ block: "start", behavior: FG.reduce ? "auto" : "smooth" }); } }
  }
  document.addEventListener("click", function (ev) {
    var b = ev.target.closest("#fnav [data-s], .fnext [data-s]"); if (b) { go(b.getAttribute("data-s"), true); return; }
    var o = ev.target.closest("[data-open]"); if (o) { opened[o.getAttribute("data-open")] = true; draw(); }
  });
  $("fsearch").addEventListener("input", draw);
  var got = fetch("/features.json").then(function (r) { if (!r.ok) throw 0; return r.json(); });
  FG.ready(function () {
    got.then(function (d) {
      DATA = d;
      var h = location.hash.slice(1);
      d.sections.forEach(function (s) { if (slug(s.title) === h) sec = s.title; });
      draw();
    }, function () { $("fbody").innerHTML = '<p class="count">' + L("The list of switches could not be loaded. Reload the page to try again.") + "</p>"; });
  });
})();
