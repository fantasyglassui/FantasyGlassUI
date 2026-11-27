// Changelog: a search through every release; "/" puts the cursor in it.
(function () {
  "use strict";
  var q = document.getElementById("q"), none = document.getElementById("none");
  if (!q) return;
  var secs = [].slice.call(document.querySelectorAll(".ver")), chips = {};
  [].forEach.call(document.querySelectorAll("nav.jump a"), function (a) { chips[a.getAttribute("href").slice(1)] = a; });
  secs.forEach(function (s) { [].forEach.call(s.querySelectorAll("li, p"), function (e) { e.dataset.html = e.innerHTML; }); });
  function esc(t) { return t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
  function mark(e, re) {                       // highlight in the text only, never inside a tag
    e.innerHTML = e.dataset.html.replace(/(<[^>]+>)|([^<]+)/g, function (m, tag, txt) { return tag || txt.replace(re, "<mark>$&</mark>"); });
  }
  var timer;
  function run() {
    var t = q.value.trim().toLowerCase(), re = t && new RegExp(esc(t), "gi"), any = false;
    secs.forEach(function (s) {
      var hit = !t || s.dataset.v.indexOf(t) === 0, own;
      [].forEach.call(s.querySelectorAll("li, p"), function (e) {
        own = !t || e.textContent.toLowerCase().indexOf(t) >= 0;
        if (t && own) hit = true;
        e.innerHTML = e.dataset.html; if (t && own) mark(e, re);
      });
      var box = s.querySelector("div");
      [].forEach.call(box.querySelectorAll(":scope > ul > li, :scope > p"), function (e) {
        e.hidden = !!t && s.dataset.v.indexOf(t) !== 0 && e.textContent.toLowerCase().indexOf(t) < 0;
      });
      [].forEach.call(box.querySelectorAll(":scope > h3"), function (h) {        // a subhead with nothing left under it goes too
        var n = h.nextElementSibling, keep = false;
        while (n && n.tagName !== "H3") { if (!n.hidden && (n.tagName !== "UL" || n.querySelector(":scope > li:not([hidden])"))) keep = true; n = n.nextElementSibling; }
        h.hidden = !!t && !keep;
      });
      [].forEach.call(box.querySelectorAll(":scope > ul"), function (u) { u.hidden = !!t && !u.querySelector(":scope > li:not([hidden])"); });
      s.hidden = !hit; if (hit) any = true;
      var ch = chips[s.id]; if (ch) ch.classList.toggle("gone", !hit);
    });
    none.hidden = any;
  }
  q.addEventListener("input", function () { clearTimeout(timer); timer = setTimeout(run, 120); });
  addEventListener("keydown", function (e) {
    if (e.key === "/" && document.activeElement !== q && !/^(INPUT|TEXTAREA|SELECT)$/.test(document.activeElement.tagName)) { e.preventDefault(); q.focus(); }
  });
})();
