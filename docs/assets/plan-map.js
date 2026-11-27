// A zone's small map for a plan code: the stops of one zone (FGPlan.panels), numbered by step, fitted to where
// they are, joined in route order, over a faint grid with north up. No game map art (it is Blizzard's).
// Used by the plan page (inline, by plan_page.py) and by Guide and Gold's example route (/assets/plan-map.js).
//
//   FGPlanMap.layout(stops, width, opts)   numbers only (no DOM): the fitted view and where each marker goes
//   FGPlanMap.draw(holder, panel, opts)    draws into holder (an element), and again when its width changes
//   FGPlanMap.show(root, step)             brings a step's marker into view and gives it the focus
//
// opts for draw: { label(step) -> "Step 4: Accept: Agitators", group(steps) -> label for a marker of several steps,
//   name: the map's label, north: "N", northTitle: "North is up", current: a step index or -1,
//   done(step) -> true when ticked, pick(step): a marker was pressed }. Steps are 0-based indexes into plan.st;
//   a marker shows step + 1, as the step list does.
var FGPlanMap = (function () {
  var NS = null;           // the SVG namespace, from the browser (the plan page names no address, not even this one)
  var TRAVEL = { fly: 1, sail: 1, hearth: 1 };
  var R = 11;              // a marker's radius (px)
  var GAP = 3;             // the least room between two markers (px)
  var PAD = 30;            // room around the stops (px), so a marker at the edge is whole
  var ZOOM = 48;           // the most px per map unit (a unit is 1% of the zone's map): stops close together stay close
  var FAN = 6;             // up to this many markers fan out around a shared spot; more are grouped by runs of steps
  var DIGIT = 6.4;         // the width of a digit at 11px (px), for a marker's size

  // a marker's text: "4"; "3–6" for stops that follow each other (a step with no place may be between them);
  // "2, 5" or "1–3, 8" for a few that do not; "1…18" when that is too long (its label names every step)
  function rangeText(ns, run) {
    if (ns.length === 1) return String(ns[0]);
    if (run) return ns[0] + "\u2013" + ns[ns.length - 1];
    var parts = [], a = ns[0], b = ns[0];
    for (var i = 1; i <= ns.length; i++) {
      if (i < ns.length && ns[i] === b + 1) { b = ns[i]; continue; }
      parts.push(a === b ? String(a) : a + (b === a + 1 ? ", " : "\u2013") + b);
      if (i < ns.length) { a = b = ns[i]; }
    }
    var t = parts.join(", ");
    return t.length > 6 ? ns[0] + "\u2026" + ns[ns.length - 1] : t;
  }
  // two markers (pills: a circle drawn wide) closer than gap px
  function touch(p, q, gap) {
    var dy = Math.abs(p.my - q.my), d = 2 * R + gap;
    if (dy >= d) return false;
    var dx = Math.max(0, Math.abs(p.mx - q.mx) - (p.hw - R) - (q.hw - R));
    return dx * dx + dy * dy < d * d;
  }
  function halfWidth(text) { return Math.max(R, text.length * DIGIT / 2 + 6); }

  function layout(stops, width, opts) {
    opts = opts || {};
    var W = Math.max(160, width || 320);
    var maxH = opts.maxH || Math.round(Math.min(420, Math.max(240, W * 0.85)));
    var minH = Math.min(opts.minH || 150, maxH);
    var xs = stops.map(function (s) { return s.x; }), ys = stops.map(function (s) { return s.y; });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
    var bw = Math.max(x1 - x0, 0.01), bh = Math.max(y1 - y0, 0.01);
    // one scale for x and y (a unit across is a unit down); the box's height follows the stops, within limits
    var s = Math.min((W - 2 * PAD) / bw, (maxH - 2 * PAD) / bh, ZOOM), H, view, pts, marks, fits;
    // when the markers of a crowded spot would not fit in the box, zoom out a little and place them again
    for (var tries = 0; tries < 10; tries++) {
      fits = attempt();
      if (fits) break;
      s *= 0.8;
    }
    function attempt() {
      H = Math.round(Math.min(maxH, Math.max(minH, bh * s + 2 * PAD)));
      view = { x: (x0 + x1) / 2 - W / s / 2, y: (y0 + y1) / 2 - H / s / 2, w: W / s, h: H / s };
      pts = stops.map(function (st, i) {
        return { i: i, step: st.step, kind: st.kind, x: st.x, y: st.y, px: (st.x - view.x) * s, py: (st.y - view.y) * s };
      });

      // markers: stops closer than two markers share a spot; a spot's markers fan out, or group into runs ("3–6")
      var group = pts.map(function (p, i) { return i; });
      function top(i) { while (group[i] !== i) i = group[i] = group[group[i]]; return i; }
      function join(a, b) { a = top(a); b = top(b); if (a !== b) group[Math.max(a, b)] = Math.min(a, b); }
      var D = 2 * R + GAP;
      for (var a = 0; a < pts.length; a++)
        for (var b = a + 1; b < pts.length; b++)
          if (Math.hypot(pts[a].px - pts[b].px, pts[a].py - pts[b].py) < D) join(a, b);

      marks = [];
      for (var round = 0; round < 12; round++) {
        var spots = {};
        pts.forEach(function (p, i) { (spots[top(i)] = spots[top(i)] || []).push(p); });
        marks = [];
        Object.keys(spots).forEach(function (k) { place(spots[k], +k); });
        // two spots whose markers now touch become one spot, and are placed again
        var clash = false;
        for (var m = 0; m < marks.length && !clash; m++)
          for (var n = m + 1; n < marks.length; n++)
            if (marks[m].spot !== marks[n].spot && hits(marks[m], marks[n])) { join(marks[m].spot, marks[n].spot); clash = true; break; }
        if (!clash) break;
      }
      function hits(p, q) { return touch(p, q, GAP); }
      function place(ps, spot) {
        var items;
        if (ps.length <= Math.min(4, FAN)) items = ps.map(function (p) { return [p]; });
        else {                                                   // runs of steps that follow each other
          items = [];
          ps.forEach(function (p) {
            var last = items[items.length - 1];
            if (last && last[last.length - 1].i === p.i - 1) last.push(p); else items.push([p]);
          });
          while (items.length > FAN) {                           // too many runs: join the two nearest in step order
            var best = 1;
            for (var j = 2; j < items.length; j++)
              if (items[j][0].i - items[j - 1][items[j - 1].length - 1].i < items[best][0].i - items[best - 1][items[best - 1].length - 1].i) best = j;
            items.splice(best - 1, 2, items[best - 1].concat(items[best]));
          }
        }
        var cx = 0, cy = 0;
        ps.forEach(function (p) { cx += p.px; cy += p.py; });
        cx /= ps.length; cy /= ps.length;
        var made = items.map(function (it) {
          var run = it.every(function (p, j) { return !j || p.i === it[j - 1].i + 1; });
          var ns = it.map(function (p) { return p.step + 1; }), text = rangeText(ns, run), ax = 0, ay = 0;
          it.forEach(function (p) { ax += p.px; ay += p.py; });
          return { spot: spot, steps: it.map(function (p) { return p.step; }), text: text, hw: halfWidth(text),
                   ax: ax / it.length, ay: ay / it.length, mx: 0, my: 0, fan: items.length > 1 };
        });
        if (made.length === 1) { made[0].mx = made[0].ax; made[0].my = made[0].ay; }
        else if (made.length === 2) {                            // side by side, in step order
          var left = cx - (2 * made[0].hw + GAP + 2 * made[1].hw) / 2;
          made[0].mx = left + made[0].hw; made[1].mx = left + 2 * made[0].hw + GAP + made[1].hw;
          made[0].my = made[1].my = cy;
        } else {                                                 // around the spot, clockwise from the top
          var hw = Math.max.apply(null, made.map(function (q) { return q.hw; }));
          var ring = (Math.max(hw, R) + GAP / 2 + 1) / Math.sin(Math.PI / made.length);
          ring = Math.max(ring, (2 * R + GAP) / (2 * Math.sin(Math.PI / made.length)) * 1.08);
          made.forEach(function (q, k) {
            var ang = -Math.PI / 2 + k * 2 * Math.PI / made.length;
            q.mx = cx + ring * Math.cos(ang) * Math.max(1, hw / R * 0.9); q.my = cy + ring * Math.sin(ang);
          });
        }
        made.forEach(function (q) { marks.push(q); });
      }

      // keep every marker inside the box: move the view (only when a fan reaches out of it)
      var dx = 0, dy = 0, lo, hi;
      lo = Math.min.apply(null, marks.map(function (q) { return q.mx - q.hw - 4; }));
      hi = Math.max.apply(null, marks.map(function (q) { return q.mx + q.hw + 4; }));
      if (lo < 0) dx = -lo; else if (hi > W) dx = W - hi;
      lo = Math.min.apply(null, marks.map(function (q) { return q.my - R - 4; }));
      hi = Math.max.apply(null, marks.map(function (q) { return q.my + R + 4; }));
      if (hi - lo > H - 8 && H < maxH) H = Math.min(maxH, Math.ceil(hi - lo + 8));
      if (lo < 0) dy = -lo; else if (hi > H) dy = H - hi;
      if (dx || dy) {
        view.x -= dx / s; view.y -= dy / s;
        pts.forEach(function (p) { p.px += dx; p.py += dy; });
        marks.forEach(function (q) { q.mx += dx; q.ax += dx; q.my += dy; q.ay += dy; });
      }
      return hi - lo <= H + 0.5 && Math.max.apply(null, marks.map(function (q) { return q.mx + q.hw + 4; })) <= W + 0.5 &&
             Math.min.apply(null, marks.map(function (q) { return q.mx - q.hw - 4; })) >= -0.5;
    }
    view.h = H / s;
    marks.sort(function (p, q) { return p.steps[0] - q.steps[0]; });
    marks.forEach(function (q, k) { q.steps.forEach(function (st) { pts.forEach(function (p) { if (p.step === st) p.mark = k; }); }); });
    return { width: W, height: H, scale: s, view: view, points: pts, marks: marks };
  }

  // ---- drawing ------------------------------------------------------------------------------------------------
  var CSS =
    ".fgmap{display:block;width:100%;height:auto;background:var(--shot);border:1px solid var(--line);border-radius:var(--map-radius,6px);color:var(--text);overflow:hidden}" +
    ".fgmap .grid{stroke:var(--line);stroke-width:1;opacity:.55}" +
    ".fgmap .route{fill:none;stroke:var(--gold);stroke-width:1.5;opacity:.6;stroke-linejoin:round;stroke-linecap:round}" +
    ".fgmap .route.travel{stroke:var(--frost);stroke-dasharray:4 4;opacity:.8}" +
    ".fgmap .lead{stroke:var(--faint);stroke-width:1}" +
    ".fgmap .spot{fill:var(--faint)}" +
    ".fgmap .north text{fill:var(--faint);font:700 11px var(--body,sans-serif)}" +
    ".fgmap .north path{fill:var(--faint)}" +
    ".fgmap .mk{cursor:pointer;outline:none}" +
    ".fgmap .mk .dot{fill:var(--raised);stroke:var(--gold);stroke-width:1.5}" +
    ".fgmap .mk text{fill:var(--text);font:700 11px var(--body,sans-serif);font-variant-numeric:tabular-nums;pointer-events:none}" +
    ".fgmap .mk .hit{fill:transparent}" +
    ".fgmap .mk .ring{fill:none;stroke:none;stroke-width:2}" +
    ".fgmap .mk.done .dot{stroke:var(--faint);stroke-dasharray:2 2}" +
    ".fgmap .mk.done text{fill:var(--dim)}" +
    ".fgmap .mk.now .dot{fill:var(--gold);stroke:var(--gold)}" +
    ".fgmap .mk.now text{fill:var(--on-gold)}" +
    ".fgmap .mk.now .ring{stroke:var(--gold);opacity:.45}" +
    ".fgmap .mk:hover .dot{stroke-width:2.5}" +
    ".fgmap .mk:focus-visible .ring,.fgmap .mk.sel .ring{stroke:var(--focus);opacity:1}";

  function sv(tag, attrs, text) {
    if (!NS) { var d = document.createElement("div"); d.innerHTML = "<svg></svg>"; NS = d.firstChild.namespaceURI; }
    var e = document.createElementNS(NS, tag);
    for (var k in attrs) e.setAttribute(k, attrs[k]);
    if (text !== undefined) e.textContent = text;
    return e;
  }
  function r1(v) { return Math.round(v * 10) / 10; }
  function nice(unitsPer60px) {                       // a grid step in map units: 1, 2, 5, 10, 20 ...
    var steps = [0.5, 1, 2, 5, 10, 20, 25, 50];
    for (var i = 0; i < steps.length; i++) if (steps[i] >= unitsPer60px) return steps[i];
    return 50;
  }

  function render(holder) {
    var panel = holder._fgPanel, o = holder._fgOpts;
    var width = holder.clientWidth || 320;
    holder._fgWidth = width;
    var stops = panel.stops.map(function (s) { return { x: s.x, y: s.y, step: s.step, kind: s.kind }; });
    var L = layout(stops, width, o);
    var W = L.width, H = L.height, s = L.scale, v = L.view;
    var svg = sv("svg", { viewBox: "0 0 " + W + " " + H, width: W, height: H, "class": "fgmap", role: "group", "aria-label": o.name || panel.name });
    var deco = sv("g", { "aria-hidden": "true" });
    // the faint grid
    var g = nice(60 / s), k;
    for (k = Math.ceil(v.x / g) * g; k <= v.x + v.w; k += g) deco.appendChild(sv("line", { x1: r1((k - v.x) * s), y1: 0, x2: r1((k - v.x) * s), y2: H, "class": "grid" }));
    for (k = Math.ceil(v.y / g) * g; k <= v.y + v.h; k += g) deco.appendChild(sv("line", { x1: 0, y1: r1((k - v.y) * s), x2: W, y2: r1((k - v.y) * s), "class": "grid" }));
    // the route in step order, from marker to marker (a flight, a boat or the hearthstone dashed); steps with no
    // place are not in it, and steps that share a marker make no line
    var pts = L.points, d = "", dt = "";
    for (k = 1; k < pts.length; k++) {
      var a = L.marks[pts[k - 1].mark], b = L.marks[pts[k].mark];
      if (a === b) continue;
      var seg = "M" + r1(a.mx) + " " + r1(a.my) + "L" + r1(b.mx) + " " + r1(b.my);
      if (TRAVEL[pts[k].kind]) dt += seg; else d += seg;
    }
    if (d) deco.appendChild(sv("path", { d: d, "class": "route" }));
    if (dt) deco.appendChild(sv("path", { d: dt, "class": "route travel" }));
    // a fanned marker: a thin line to where it really is, and a dot there
    L.marks.forEach(function (q) {
      if (!q.fan) return;
      deco.appendChild(sv("line", { x1: r1(q.ax), y1: r1(q.ay), x2: r1(q.mx), y2: r1(q.my), "class": "lead" }));
    });
    L.marks.forEach(function (q) { if (q.fan) deco.appendChild(sv("circle", { cx: r1(q.ax), cy: r1(q.ay), r: 2.2, "class": "spot" })); });
    // north is up
    var north = sv("g", { "class": "north", transform: "translate(" + (W - 16) + " 8)" });
    north.appendChild(sv("title", {}, o.northTitle || "North is up"));
    north.appendChild(sv("path", { d: "M0 0 L4 7 L0 5.5 L-4 7 Z" }));
    north.appendChild(sv("text", { x: 0, y: 19, "text-anchor": "middle" }, o.north || "N"));
    deco.appendChild(north);
    svg.appendChild(deco);
    // the markers, in step order (the order Tab takes)
    L.marks.forEach(function (q) {
      var now = o.current !== undefined && q.steps.indexOf(o.current) >= 0;
      var done = !now && o.done && q.steps.every(function (st) { return o.done(st); });
      var label = q.steps.length === 1 ? o.label(q.steps[0]) : o.group(q.steps);
      var m = sv("g", { "class": "mk" + (now ? " now" : "") + (done ? " done" : ""), tabindex: 0, role: "button", "aria-label": label,
                        "data-steps": q.steps.join(" ") });
      if (now) m.setAttribute("aria-current", "step");
      var x = r1(q.mx), y = r1(q.my), hw = q.hw;
      m.appendChild(sv("rect", { x: r1(x - hw - 2), y: r1(y - R - 2), width: r1(2 * hw + 4), height: 2 * R + 4, rx: R + 2, "class": "hit" }));
      m.appendChild(sv("rect", { x: r1(x - hw - 3.5), y: r1(y - R - 3.5), width: r1(2 * hw + 7), height: 2 * R + 7, rx: R + 3.5, "class": "ring" }));
      m.appendChild(sv("rect", { x: r1(x - hw), y: y - R, width: r1(2 * hw), height: 2 * R, rx: R, "class": "dot" }));
      m.appendChild(sv("text", { x: x, y: r1(y + 3.9), "text-anchor": "middle" }, q.text));
      function go(e) { if (o.pick) { e.preventDefault(); o.pick(q.steps[0], m); } }
      m.addEventListener("click", go);
      m.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") go(e); });
      svg.appendChild(m);
    });
    holder.textContent = "";
    holder.appendChild(svg);
  }

  function draw(holder, panel, opts) {
    if (!document.getElementById("fgmap-css")) {
      var st = document.createElement("style");
      st.id = "fgmap-css"; st.textContent = CSS;
      document.head.appendChild(st);
    }
    holder._fgPanel = panel; holder._fgOpts = opts || {};
    render(holder);
    if (!holder._fgWatch && typeof ResizeObserver !== "undefined") {     // (a phone turned, a window resized)
      holder._fgWatch = new ResizeObserver(function () {
        if (holder.isConnected && Math.abs((holder.clientWidth || 0) - holder._fgWidth) > 1) render(holder);
      });
      holder._fgWatch.observe(holder);
    }
  }

  function show(root, step, reduce) {
    var m = root.querySelector('.fgmap .mk[data-steps~="' + step + '"]');
    if (!m) return false;
    var svg = m.ownerSVGElement;
    svg.scrollIntoView({ block: "nearest", behavior: reduce ? "auto" : "smooth" });
    [].forEach.call(root.querySelectorAll(".fgmap .mk.sel"), function (e) { e.classList.remove("sel"); });
    m.classList.add("sel");
    m.addEventListener("blur", function off() { m.classList.remove("sel"); m.removeEventListener("blur", off); });
    try { m.focus({ preventScroll: true }); } catch (e) { m.focus(); }
    return true;
  }

  return { layout: layout, draw: draw, show: show, rangeText: rangeText, touch: touch };
})();
if (typeof module !== "undefined") module.exports = FGPlanMap;
