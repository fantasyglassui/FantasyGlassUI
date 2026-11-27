// Roadmap: the status chips show every idea, or only the ideas with one status (a group with none left is hidden;
// the "Coming in" preview shows under All and In progress, and its cards are not counted twice).
(function () {
  "use strict";
  var chips = [].slice.call(document.querySelectorAll(".rm .chip[data-show]")), say = document.getElementById("rm-count");
  if (!chips.length) return;
  function show(which) {
    var n = 0;
    chips.forEach(function (c) { c.setAttribute("aria-pressed", String(c.dataset.show === which)); });
    [].forEach.call(document.querySelectorAll(".rm-group"), function (g) {
      var any = false;
      [].forEach.call(g.querySelectorAll(".idea"), function (i) {
        var on = which === "all" || i.dataset.status === which;
        i.hidden = !on; if (on) { any = true; n++; }
      });
      g.hidden = !any && !(g.dataset.keep && (which === "all" || which === g.dataset.keep));   // (the Ready section stays, with its empty line, under All and Ready)
    });
    [].forEach.call(document.querySelectorAll(".rm-coming"), function (c) { c.hidden = !(which === "all" || which === "progress"); });   // (the 13.5 preview: under All and In progress)
    if (say) say.textContent = String(n);
  }
  chips.forEach(function (c) { c.addEventListener("click", function () { show(c.dataset.show); }); });
})();
