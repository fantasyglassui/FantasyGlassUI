// Guide and Gold: the short tour (#tour, its steps in #tour-steps) and the example route (#ex), which the plan
// page's own reader (window.FGPlan, /assets/plan-reader.js) reads from a sample plan code. The words are in the
// page already (the build translated them); the route's own steps are the game's words, in English.
(function () {
  "use strict";
  var $ = function (id) { return document.getElementById(id); };
  var NS = "http://www.w3.org/2000/svg";
  var reduce = !!(window.FG && FG.reduce);

  // ---- the example route --------------------------------------------------------------------------------------
  function example() {
    var ex = $("ex");
    if (!ex || !window.FGPlan) return;
    var r = FGPlan.read(ex.getAttribute("data-code") || "");
    if (!r.ok) return;                                           // (stays hidden: nothing half drawn)
    var plan = r.plan, t = FGPlan.totals(plan), lang = document.documentElement.lang || "en";
    var english = !/^en\b/.test(lang);
    function num(n) {
      if (n === null || n === undefined) return "—";
      try { return new Intl.NumberFormat(lang).format(n); } catch (e) { return String(n); }
    }
    function time(s) {
      if (s === null || s === undefined) return "—";        // (not in the code: a dash, never a made-up 0)
      var m = Math.round(s / 60), h = Math.floor(m / 60);
      return h > 0 ? ex.getAttribute("data-hmin").replace("%d", h).replace("%d", m % 60) : ex.getAttribute("data-min").replace("%d", m);
    }
    var vals = { xp: num(t.xp), time: time(t.seconds), levels: t.from + " → " + t.to, flights: String(t.flights), steps: String(t.steps) };
    [].forEach.call(ex.querySelectorAll("dd[data-t]"), function (dd) { dd.textContent = vals[dd.getAttribute("data-t")]; });

    function el(tag, cls, text) { var e = document.createElement(tag); if (cls) e.className = cls; if (text !== undefined) e.textContent = text; return e; }
    function sv(tag, attrs, text) {
      var e = document.createElementNS(NS, tag);
      for (var k in attrs) e.setAttribute(k, attrs[k]);
      if (text !== undefined) e.textContent = text;
      return e;
    }
    // a zone's small map: its stops, numbered by step, joined in route order (a flight, a boat or the hearthstone dashed)
    var ICON = { fly: "F", sail: "S", hearth: "H" };
    function map(p) {
      var svg = sv("svg", { viewBox: "0 0 100 100", role: "img", "class": "ex-map", "aria-label": ex.getAttribute("data-map").replace("%s", p.name) });
      var g = sv("g", { "aria-hidden": "true" });
      for (var i = 1; i < p.stops.length; i++) {
        var a = p.stops[i - 1], b = p.stops[i];
        g.appendChild(sv("line", { x1: a.x, y1: a.y, x2: b.x, y2: b.y, "class": ICON[b.kind] ? "leg travel" : "leg" }));   // (under the marks)
      }
      for (var k = 25; k < 100; k += 25) {                        // (a faint grid, so the square reads as a map)
        g.appendChild(sv("line", { x1: k, y1: 0, x2: k, y2: 100, "class": "grid" }));
        g.appendChild(sv("line", { x1: 0, y1: k, x2: 100, y2: k, "class": "grid" }));
      }
      var spots = [];                                              // (stops at almost the same place share one mark: "1,3")
      p.stops.forEach(function (s) {
        var near = null;
        spots.forEach(function (q) { if (Math.abs(q.x - s.x) < 4 && Math.abs(q.y - s.y) < 4) near = q; });
        if (near) { near.n.push(s.step + 1); if (ICON[s.kind]) near.k = ICON[s.kind]; }
        else spots.push({ x: s.x, y: s.y, n: [s.step + 1], k: ICON[s.kind] || "" });
      });
      spots.forEach(function (q) {
        var label = q.n.join(","), r = label.length > 1 ? 3 + label.length * 1.9 : 6;
        g.appendChild(sv("circle", { cx: q.x, cy: q.y, r: r, "class": "stop" }));
        g.appendChild(sv("text", { x: q.x, y: q.y + 2.2, "text-anchor": "middle", "class": "stop-n" }, label));
        if (q.k) g.appendChild(sv("text", { x: q.x + r + 1.2, y: q.y - r + 0.6, "class": "stop-k" }, q.k));
      });
      svg.appendChild(g);
      return svg;
    }
    // the steps, zone by zone in route order: a step with no place stays with the zone before it
    var panels = {}, groups = [], cur = null, early = [];
    FGPlan.panels(plan).forEach(function (p) { panels[p.zone] = p; });
    plan.st.forEach(function (s, i) {
      if (s.z !== null && (!cur || cur.zone !== s.z)) { cur = { zone: s.z, steps: [] }; groups.push(cur); if (early.length) { cur.steps = early; early = []; } }
      (cur ? cur.steps : early).push(i);
    });
    if (!groups.length) groups.push({ zone: null, steps: early });
    var box = $("ex-zones");
    box.textContent = "";
    groups.forEach(function (gr) {
      var card = el("section", "card ex-zone"), name = gr.zone ? plan.z[gr.zone - 1].n : "";
      var h = el("h3", "", name);
      if (english) h.lang = "en";
      if (name) card.appendChild(h);
      if (gr.zone && panels[gr.zone] && panels[gr.zone].stops.length) card.appendChild(map(panels[gr.zone]));
      var ol = el("ol", "ex-steps");
      ol.start = gr.steps[0] + 1;
      gr.steps.forEach(function (i) {
        var s = plan.st[i], li = el("li"), box = el("input"), lab = el("label", "", s.t);
        box.type = "checkbox"; box.id = "ex-s" + i;
        lab.htmlFor = box.id;
        if (english) lab.lang = "en";
        box.addEventListener("change", function () { li.classList.toggle("done", box.checked); });
        li.appendChild(el("span", "n", String(i + 1)));
        li.appendChild(box); li.appendChild(lab);
        ol.appendChild(li);
      });
      card.appendChild(ol);
      box.appendChild(card);
    });
    ex.hidden = false;
  }

  // ---- the short tour -----------------------------------------------------------------------------------------
  function tour() {
    var go = $("tour-go"), dlg = $("tour"), list = $("tour-steps");
    if (!go || !dlg || !list) return;
    var steps = [].map.call(list.children, function (li) {
      return { target: li.getAttribute("data-target"), h: li.querySelector("h3").innerHTML, p: li.querySelector("p").innerHTML };
    });
    var count = $("tour-count"), head = $("tour-h"), text = $("tour-text"), back = $("tour-back"), next = $("tour-next"), say = $("tour-say");
    var of = dlg.getAttribute("data-of"), at = -1, lit = null;
    function place(target) {
      var bar = document.querySelector(".site-head"), top = target.getBoundingClientRect().top + window.pageYOffset - (bar ? bar.offsetHeight : 0) - 20;
      window.scrollTo({ top: Math.max(0, top), behavior: reduce ? "auto" : "smooth" });
    }
    function show(i, announce) {
      at = i;
      var s = steps[i], last = i === steps.length - 1;
      count.textContent = of.replace("%d", i + 1).replace("%d", steps.length);
      head.innerHTML = s.h;
      text.innerHTML = s.p;
      if (document.activeElement === back && i === 0) next.focus();      // (Back is about to be switched off)
      back.disabled = i === 0;
      next.textContent = next.getAttribute(last ? "data-done" : "data-next");
      if (lit) lit.classList.remove("tour-on");
      lit = $(s.target);
      if (lit && lit.hidden) lit = lit.parentElement;                      // (the example, if it could not be drawn)
      if (lit) { lit.classList.add("tour-on"); place(lit); }
      document.body.style.paddingBottom = (dlg.offsetHeight + 24) + "px";  // (room to bring the last part above the box)
      if (announce) say.textContent = count.textContent + ". " + head.textContent + ". " + text.textContent;
    }
    function open() {
      dlg.hidden = false;
      go.setAttribute("aria-expanded", "true");
      say.textContent = "";
      show(0, false);
      dlg.focus();
    }
    function close() {
      dlg.hidden = true;
      go.setAttribute("aria-expanded", "false");
      if (lit) lit.classList.remove("tour-on");
      lit = null; at = -1; say.textContent = "";
      document.body.style.paddingBottom = "";
      go.focus();
    }
    go.addEventListener("click", function () { if (dlg.hidden) open(); else dlg.focus(); });
    back.addEventListener("click", function () { if (at > 0) show(at - 1, true); });
    next.addEventListener("click", function () { if (at < steps.length - 1) show(at + 1, true); else close(); });
    $("tour-x").addEventListener("click", close);
    document.addEventListener("keydown", function (e) {
      if (dlg.hidden) return;
      if (e.key === "Escape") { e.preventDefault(); close(); return; }
      if (!dlg.contains(document.activeElement)) return;
      if (e.key === "ArrowRight" && at < steps.length - 1) { e.preventDefault(); show(at + 1, true); }
      else if (e.key === "ArrowLeft" && at > 0) { e.preventDefault(); show(at - 1, true); }
    });
    go.setAttribute("aria-expanded", "false");
    go.setAttribute("aria-controls", "tour");
    $("tour-start").hidden = false;
  }

  example();
  tour();
})();
