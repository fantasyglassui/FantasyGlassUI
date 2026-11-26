// Get started: the commands, from /features.json, with a search and a copy button on each.
(function () {
  "use strict";
  var FG = window.FG, $ = FG.$, esc = FG.esc, L = FG.L, F = FG.F;
  var DATA = null, all = false;
  function mark(text, q) {
    var t = esc(text); if (!q) return t;
    var i = t.toLowerCase().indexOf(esc(q).toLowerCase()); if (i < 0) return t;
    return t.slice(0, i) + "<mark>" + t.slice(i, i + esc(q).length) + "</mark>" + t.slice(i + esc(q).length);
  }
  function short(cmd) { var p = cmd.split(" "); return p[0] + (p[1] && p[1].charAt(0) !== "[" && p[1].charAt(0) !== "<" ? " " + p[1] : ""); }
  function draw() {
    if (!DATA) return;
    var q = $("csearch").value.trim().toLowerCase();
    var rows = DATA.commands.filter(function (c) { return !q || (c.cmd + " " + c.desc + " " + L(c.desc)).toLowerCase().indexOf(q) !== -1; });
    var cut = !q && !all;
    if (cut) rows = rows.slice(0, 10);                           // the everyday ones first
    $("cmore").hidden = !cut; $("cmore").textContent = F("Show all %d commands", DATA.commands.length);
    $("clist").innerHTML = rows.map(function (c) {
      return '<tr><th scope="row"><code>' + mark(c.cmd, q) + "</code></th><td>" + mark(L(c.desc), q) + '</td><td><button class="btn line copy" type="button" data-c="' + esc(short(c.cmd)) + '">' + L("Copy") + "</button></td></tr>";
    }).join("") || '<tr><td colspan="3" class="count">' + L("No command matches that.") + "</td></tr>";
    $("ccount").textContent = F("%d of %d commands", rows.length, DATA.commands.length);
  }
  $("csearch").addEventListener("input", draw);
  $("cmore").addEventListener("click", function () { all = true; draw(); });
  $("copyall").addEventListener("click", function () {
    if (!DATA) return;
    var b = this, text = DATA.commands.map(function (c) { return c.cmd + "  -  " + L(c.desc); }).join("\n");
    FG.copy(text, function (ok) { b.textContent = ok ? F("Copied %d commands", DATA.commands.length) : L("Copy did not work here: select the table instead"); setTimeout(function () { b.textContent = L("Copy the whole list"); }, 2200); });
  });
  $("clist").addEventListener("click", function (ev) {
    var b = ev.target.closest("[data-c]"); if (!b) return;
    var text = b.getAttribute("data-c");
    FG.copy(text, function (ok) { b.textContent = ok ? L("Copied") : text; setTimeout(function () { b.textContent = L("Copy"); }, 1600); });
  });
  var got = fetch("/features.json").then(function (r) { if (!r.ok) throw 0; return r.json(); });
  FG.ready(function () { got.then(function (d) { DATA = d; draw(); }, function () {}); });
})();
