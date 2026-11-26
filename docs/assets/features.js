// Features: every switch in the add-on, from /features.json, one section at a time or one search across all.
(function () {
  "use strict";
  var FG = window.FG, $ = FG.$, esc = FG.esc, L = FG.L, F = FG.F;
  var DATA = null, sec = null, opened = {}, FIRST = 8;
  function mark(text, q) {
    var t = esc(text); if (!q) return t;
    var i = t.toLowerCase().indexOf(esc(q).toLowerCase()); if (i < 0) return t;
    return t.slice(0, i) + "<mark>" + t.slice(i, i + esc(q).length) + "</mark>" + t.slice(i + esc(q).length);
  }
  function draw() {
    if (!DATA) return;
    var q = $("fsearch").value.trim().toLowerCase(), shown = 0, total = 0, html = "";
    if (!sec) sec = DATA.sections[0].title;
    $("ffilters").innerHTML = DATA.sections.map(function (s) {
      return '<button class="chip" type="button" data-s="' + esc(s.title) + '" aria-pressed="' + (!q && s.title === sec) + '">' + esc(L(s.title)) + "<span>" + s.items.length + "</span></button>";
    }).join("");
    DATA.sections.forEach(function (s) {
      total += s.items.length;
      if (!q && s.title !== sec) return;                       // one section at a time; a search looks through all
      var items = s.items.filter(function (it) { return !q || (it.label + " " + it.desc + " " + L(it.label) + " " + L(it.desc)).toLowerCase().indexOf(q) !== -1; });
      if (!items.length) return;
      shown += items.length;
      var all = q || opened[s.title] || items.length <= FIRST + 2;
      var show = all ? items : items.slice(0, FIRST);
      html += '<div class="fsec">' + (q ? "<h3>" + esc(L(s.title)) + "<small>" + items.length + "</small></h3>" : "") + '<div class="flist">' + show.map(function (it) {
        return '<div class="fitem"><b>' + mark(L(it.label), q) + "</b>" + (it.desc ? "<span>" + mark(L(it.desc), q) + "</span>" : "") + "</div>";
      }).join("") + "</div>" + (all ? "" : '<button class="btn line more" type="button" data-open="' + esc(s.title) + '">' + F("Show all %d", items.length) + "</button>") + "</div>";
    });
    $("flist").innerHTML = html || '<p class="count">' + L("No switch matches that. Try a shorter word.") + "</p>";
    $("fcount").textContent = F("%d of %d switches", shown, total);
  }
  $("ffilters").addEventListener("click", function (ev) { var b = ev.target.closest("[data-s]"); if (!b) return; sec = b.getAttribute("data-s"); $("fsearch").value = ""; draw(); var again = $("ffilters").querySelector('[aria-pressed="true"]'); if (again) again.focus(); });
  $("fsearch").addEventListener("input", draw);
  $("flist").addEventListener("click", function (ev) { var b = ev.target.closest("[data-open]"); if (!b) return; opened[b.getAttribute("data-open")] = true; draw(); });
  var got = fetch("/features.json").then(function (r) { if (!r.ok) throw 0; return r.json(); });
  FG.ready(function () {
    got.then(function (d) { DATA = d; draw(); }, function () { $("flist").innerHTML = '<p class="count">' + L("The list of switches could not be loaded. Reload the page to try again.") + "</p>"; });
  });
})();
