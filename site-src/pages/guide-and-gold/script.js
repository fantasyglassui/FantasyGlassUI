// Guide and Gold: the short tour (#tour, its steps in #tour-steps) and the example route (#ex), which the plan
// page's own reader (window.FGPlan, /assets/plan-reader.js) reads from a sample plan code, and its map
// (window.FGPlanMap, /assets/plan-map.js) draws. The words are in the
// page already (the build translated them); the route's own steps are the game's words, in English.
(function () {
  "use strict";
  var $ = function (id) { return document.getElementById(id); };
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
    // a zone's small map (the plan page's own, /assets/plan-map.js): its stops numbered by step, fitted to where they
    // are, joined in route order; a marker and its step in the list lead to each other
    var A = function (name) { return ex.getAttribute(name) || ""; };
    function stepLabel(i) { return A("data-step").replace("%d", i + 1).replace("%s", plan.st[i].t); }
    function groupLabel(steps) {
      return A("data-steps").replace("%s", steps.map(function (i) { return i + 1; }).join(", ")).replace("%s", steps.map(function (i) { return plan.st[i].t; }).join("; "));
    }
    function current() { for (var i = 0; i < plan.st.length; i++) { var b = $("ex-s" + i); if (b && !b.checked) return i; } return -1; }
    var maps = [];
    function drawMaps() {
      var now = current();
      maps.forEach(function (m) {
        FGPlanMap.draw(m.holder, m.panel, { name: A("data-map").replace("%s", m.panel.name), north: A("data-north"), northTitle: A("data-north-t"),
          label: stepLabel, group: groupLabel, current: now, done: function (i) { var b = $("ex-s" + i); return !!(b && b.checked); }, pick: toStep });
      });
      [].forEach.call(ex.querySelectorAll("ol.ex-steps li"), function (li) { li.classList.toggle("now", li.getAttribute("data-i") === String(now)); });
    }
    function toStep(i) {
      var box = $("ex-s" + i);
      if (!box) return;
      box.closest("li").scrollIntoView({ block: "nearest", behavior: reduce ? "auto" : "smooth" });
      try { box.focus({ preventScroll: true }); } catch (e) { box.focus(); }
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
      var placed = {};
      if (gr.zone && panels[gr.zone] && panels[gr.zone].stops.length && window.FGPlanMap) {
        var holder = el("div", "ex-map");
        card.appendChild(holder);
        maps.push({ holder: holder, panel: panels[gr.zone] });
        panels[gr.zone].stops.forEach(function (st) { placed[st.step] = true; });
      }
      var ol = el("ol", "ex-steps");
      ol.start = gr.steps[0] + 1;
      gr.steps.forEach(function (i) {
        var s = plan.st[i], li = el("li"), box = el("input"), lab = el("label", "", s.t);
        li.setAttribute("data-i", String(i));
        box.type = "checkbox"; box.id = "ex-s" + i;
        lab.htmlFor = box.id;
        if (english) lab.lang = "en";
        box.addEventListener("change", function () { li.classList.toggle("done", box.checked); drawMaps(); });
        if (placed[i]) {                                           // the number: a button to its marker on the map
          var pin = el("button", "n", String(i + 1));
          pin.type = "button";
          pin.setAttribute("aria-label", A("data-pin").replace("%d", i + 1));
          pin.addEventListener("click", function () { FGPlanMap.show(card.querySelector(".fgmap") ? card : ex, i, reduce); });
          li.appendChild(pin);
        } else li.appendChild(el("span", "n", String(i + 1)));
        li.appendChild(box); li.appendChild(lab);
        ol.appendChild(li);
      });
      card.appendChild(ol);
      box.appendChild(card);
    });
    ex.hidden = false;
    drawMaps();                                                    // (once shown: a map takes its width from the page)
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
