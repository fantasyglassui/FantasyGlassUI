// Get started (W2): one search across the questions (#faq) and the commands (#commands, from /features.json), a copy
// button on each command, and the whole list to copy. Plain script, nothing from another site.
(function () {
  "use strict";
  var FG = window.FG, $ = FG.$, esc = FG.esc, L = FG.L, F = FG.F;
  var DATA = null, all = false;
  var QS = [].slice.call(document.querySelectorAll("#faq details.q"));
  QS.forEach(function (d) { d.setAttribute("data-text", d.textContent.toLowerCase()); });
  function fold(s) { return String(s).toLowerCase(); }
  function mark(text, q) {
    var t = esc(text); if (!q) return t;
    var i = t.toLowerCase().indexOf(esc(q).toLowerCase()); if (i < 0) return t;
    return t.slice(0, i) + "<mark>" + t.slice(i, i + esc(q).length) + "</mark>" + t.slice(i + esc(q).length);
  }
  function short(cmd) { var p = cmd.split(" "); return p[0] + (p[1] && p[1].charAt(0) !== "[" && p[1].charAt(0) !== "<" ? " " + p[1] : ""); }
  function draw() {
    var q = fold($("asearch").value.trim());
    // the questions: those that match stay, and open while there is a search
    var qn = 0;
    QS.forEach(function (d) {
      var hit = !q || d.getAttribute("data-text").indexOf(q) !== -1;
      d.hidden = !hit; if (hit) qn++;
      if (q && hit) d.open = true;
      else if (!q && d.hasAttribute("data-opened-by-search")) d.open = false;
      if (q && hit) d.setAttribute("data-opened-by-search", ""); else d.removeAttribute("data-opened-by-search");
    });
    $("faq").hidden = !qn;
    // the commands
    var cn = 0;
    if (DATA) {
      var rows = DATA.commands.filter(function (c) { return !q || fold(c.cmd + " " + c.desc + " " + L(c.desc)).indexOf(q) !== -1; });
      cn = rows.length;
      var cut = !q && !all;
      if (cut) rows = rows.slice(0, 10);                         // the everyday ones first
      $("cmore").hidden = !cut; $("cmore").textContent = F("Show all %d commands", DATA.commands.length);
      $("clist").innerHTML = rows.map(function (c) {
        return '<tr><th scope="row"><code>' + mark(c.cmd, q) + "</code></th><td>" + mark(L(c.desc), q) + '</td><td><button class="btn line small copy" type="button" data-c="' + esc(short(c.cmd)) + '">' + L("Copy") + '<span class="sr-only"> ' + esc(short(c.cmd)) + "</span></button></td></tr>";
      }).join("");
      $("commands").hidden = !cn;
    }
    $("anone").hidden = !q || qn + cn > 0;
    $("acount").textContent = q ? F("%d questions and %d commands", qn, cn) : "";
  }
  $("asearch").addEventListener("input", draw);
  $("cmore").addEventListener("click", function () { all = true; draw(); });
  $("copyall").addEventListener("click", function () {
    if (!DATA) return;
    var b = this, text = DATA.commands.map(function (c) { return c.cmd + "  -  " + L(c.desc); }).join("\n");
    FG.copy(text, function (ok) { b.textContent = ok ? F("Copied %d commands", DATA.commands.length) : L("Copy did not work here: select the table instead"); setTimeout(function () { b.textContent = L("Copy the whole list"); }, 2200); });
  });
  $("clist").addEventListener("click", function (ev) {
    var b = ev.target.closest("[data-c]"); if (!b) return;
    var text = b.getAttribute("data-c");
    FG.copy(text, function (ok) { b.textContent = ok ? L("Copied") : text; setTimeout(function () { b.innerHTML = esc(L("Copy")) + '<span class="sr-only"> ' + esc(text) + "</span>"; }, 1600); });
  });
  var got = fetch("/features.json").then(function (r) { if (!r.ok) throw 0; return r.json(); });
  draw();
  FG.ready(function () { got.then(function (d) { DATA = d; draw(); }, function () {}); });
})();
