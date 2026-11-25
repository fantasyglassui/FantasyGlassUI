// Reads a plan code (the text "Share plan" gives in the game). No DOM here: the page draws, this only reads.
// The code is "SUIP1!" and the add-on's share encoding: S<bytes>:text, N<number>; and { key value ... }.
var FGPlan = (function () {
  var HEADER = "SUIP1!";
  var KINDS = { accept: 1, turnin: 1, "do": 1, "goto": 1, note: 1, level: 1, hearth: 1, fly: 1, learnflight: 1, sail: 1, bind: 1,
                train: 1, vendor: 1, mail: 1, explore: 1, gather: 1 };
  var TRAVEL = { fly: 1, sail: 1, hearth: 1 };

  // The add-on's decoding, on bytes (text lengths are bytes, as the game counts them).
  function decode(bytes, start) {
    var i = start, dec = new TextDecoder();
    function fail() { throw new Error("bad"); }
    function ascii(a, b) { var s = ""; for (var k = a; k < b; k++) s += String.fromCharCode(bytes[k]); return s; }
    function find(ch, from) { for (var k = from; k < bytes.length; k++) if (bytes[k] === ch.charCodeAt(0)) return k; return -1; }
    function one(depth) {
      if (depth > 20 || i >= bytes.length) fail();
      var c = String.fromCharCode(bytes[i]), j, n;
      if (c === "T") { i++; return true; }
      if (c === "F") { i++; return false; }
      if (c === "N") {
        j = find(";", i); if (j < 0) fail();
        var txt = ascii(i + 1, j);
        n = txt === "" ? NaN : Number(txt);
        if (isNaN(n)) fail();
        i = j + 1; return n;
      }
      if (c === "S") {
        j = find(":", i); if (j < 0) fail();
        var len = ascii(i + 1, j);
        if (!/^[0-9]+$/.test(len)) fail();
        n = parseInt(len, 10);
        if (n > 4096 || j + 1 + n > bytes.length) fail();
        var str = dec.decode(bytes.subarray(j + 1, j + 1 + n));
        i = j + 1 + n; return str;
      }
      if (c === "{") {
        i++;
        var t = Object.create(null);
        while (i >= bytes.length ? fail() : bytes[i] !== 125) {
          var k = one(depth + 1), v = one(depth + 1);
          if (typeof k !== "string" && typeof k !== "number") fail();
          t[k] = v;
        }
        i++; return t;
      }
      fail();
    }
    var v = one(0);
    if (i !== bytes.length) fail();
    return v;
  }

  // A table keyed 1..n becomes an array in key order; anything else is not a list (undefined).
  function list(t) {
    if (!t || typeof t !== "object") return undefined;
    var keys = Object.keys(t), out = [], n = keys.length;
    for (var k = 1; k <= n; k++) { if (!(String(k) in t)) return undefined; out.push(t[String(k)]); }
    return out;
  }
  function num(v, dflt) { return typeof v === "number" && isFinite(v) ? v : dflt; }

  function read(code) {
    if (typeof code !== "string") return { ok: false, why: "empty" };
    code = code.replace(/^\s+|\s+$/g, "");
    if (code === "") return { ok: false, why: "empty" };
    if (code.slice(0, HEADER.length) !== HEADER) {
      return { ok: false, why: "kind", other: /^[A-Za-z]+[0-9]+!/.test(code) };      // (other: a theme or layout code)
    }
    var data, bad = { ok: false, why: "damaged" };
    try { data = decode(new TextEncoder().encode(code), new TextEncoder().encode(HEADER).length); } catch (e) { return bad; }
    if (!data || typeof data !== "object" || typeof data.v !== "number") return bad;
    if (data.v > 1) return { ok: false, why: "version" };
    if (data.v !== 1) return bad;
    var lv = list(data.lv), z = list(data.z), st = list(data.st);
    if (!lv || lv.length !== 2 || !z || !st) return bad;
    var plan = { v: 1, lv: [num(lv[0], 0), num(lv[1], 0)], xp: num(data.xp, 0), s: num(data.s, 0), fl: num(data.fl, 0), cr: num(data.cr, 0),
                 more: num(data.more, 0), z: [], st: [] };
    for (var a = 0; a < z.length; a++) {
      if (!z[a] || typeof z[a] !== "object" || typeof z[a].n !== "string") return bad;
      plan.z.push({ m: num(z[a].m, null), n: z[a].n });
    }
    for (var b = 0; b < st.length; b++) {
      var s = st[b];
      if (!s || typeof s !== "object" || typeof s.k !== "string" || !Object.prototype.hasOwnProperty.call(KINDS, s.k) || typeof s.t !== "string") return bad;
      var zi = s.z === undefined ? null : s.z;
      if (zi !== null && (typeof zi !== "number" || zi < 1 || zi > plan.z.length || zi % 1 !== 0)) return bad;
      plan.st.push({ k: s.k, t: s.t, z: zi, x: num(s.x, null), y: num(s.y, null) });
    }
    return { ok: true, plan: plan };
  }

  function totals(plan) {
    return { xp: plan.xp, seconds: plan.s, from: plan.lv[0], to: plan.lv[1], flights: plan.fl, crossings: plan.cr, steps: plan.st.length + (plan.more || 0) };
  }

  // One panel per zone that has stops: the stops (numbered over the whole plan, a step with no place has none)
  // and the legs a fly, sail or hearth step makes from the stop before it: { from, to } are zone numbers (1..).
  function panels(plan) {
    var byZone = {}, order = [], n = 0, prev = null;
    plan.st.forEach(function (s, i) {
      if (s.z === null || s.x === null || s.y === null) return;
      n++;
      var p = byZone[s.z];
      if (!p) { p = byZone[s.z] = { zone: s.z, name: plan.z[s.z - 1].n, stops: [], legs: [] }; order.push(p); }
      var stop = { n: n, x: s.x, y: s.y, kind: s.k, step: i };
      p.stops.push(stop);
      if (TRAVEL[s.k] && prev) p.legs.push({ from: prev.zone, to: s.z, kind: s.k, a: prev.n, b: n });
      prev = { zone: s.z, n: n };
    });
    order.sort(function (p, q) { return p.zone - q.zone; });
    return order;
  }

  // A short key for the ticks kept in this browser (FNV-1a over the code's characters).
  function hash(code) {
    var h = 0x811c9dc5;
    for (var i = 0; i < code.length; i++) { h ^= code.charCodeAt(i); h = Math.imul(h, 0x01000193) >>> 0; }
    return ("00000000" + h.toString(16)).slice(-8);
  }

  return { read: read, totals: totals, panels: panels, hash: hash };
})();
if (typeof module !== "undefined") module.exports = FGPlan;
