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
        var t = { s: Object.create(null), n: Object.create(null) };      // (string keys and number keys apart, as in the game)
        while (i >= bytes.length ? fail() : bytes[i] !== 125) {
          var k = one(depth + 1), v = one(depth + 1);
          if (typeof k === "string") t.s[k] = v; else if (typeof k === "number") t.n[String(k)] = v; else fail();
        }
        i++; return t;
      }
      fail();
    }
    var v = one(0);
    if (i !== bytes.length) fail();
    return v;
  }

  // The reader and the add-on's own refuse exactly the same codes (tests/plan_codes.txt): a list is a table
  // keyed 1..n and nothing else; a field that is there must have its type; text after the code is damage.
  function isTable(t) { return !!t && typeof t === "object" && !!t.s && !!t.n; }
  function list(t) {
    if (!isTable(t) || Object.keys(t.s).length > 0) return undefined;
    var n = Object.keys(t.n).length, out = [];
    for (var k = 1; k <= n; k++) { if (!(String(k) in t.n)) return undefined; out.push(t.n[String(k)]); }
    return out;
  }
  // A number that may be left out (dflt); undefined when it is there and not a number.
  function opt(v, dflt) {
    if (v === undefined) return dflt;
    return typeof v === "number" && isFinite(v) ? v : undefined;
  }
  var BAD = { ok: false, why: "damaged" };

  function read(code) {
    if (typeof code !== "string") return { ok: false, why: "empty" };
    code = code.replace(/^[ \t\r\n\f\v]+|[ \t\r\n\f\v]+$/g, "");
    if (code === "") return { ok: false, why: "empty" };
    if (code.slice(0, HEADER.length) !== HEADER) {
      var newer = /^SUIP([0-9]+)!/.exec(code);
      if (newer && parseInt(newer[1], 10) > 1) return { ok: false, why: "version" };
      return { ok: false, why: "kind", other: !newer && /^[A-Za-z]+[0-9]+!/.test(code) };      // (other: a theme or layout code)
    }
    var data;
    try { data = decode(new TextEncoder().encode(code), HEADER.length); } catch (e) { return BAD; }
    if (!isTable(data) || typeof data.s.v !== "number") return BAD;
    if (data.s.v > 1) return { ok: false, why: "version" };
    if (data.s.v !== 1) return BAD;
    var lv = list(data.s.lv), z = list(data.s.z), st = list(data.s.st);
    if (!lv || lv.length !== 2 || !z || !st) return BAD;
    if (!isFinite(lv[0]) || !isFinite(lv[1]) || typeof lv[0] !== "number" || typeof lv[1] !== "number") return BAD;
    var plan = { v: 1, lv: [lv[0], lv[1]], xp: opt(data.s.xp, 0), s: opt(data.s.s, 0), fl: opt(data.s.fl, 0), cr: opt(data.s.cr, 0),
                 more: opt(data.s.more, 0), z: [], st: [] };
    if (plan.xp === undefined || plan.s === undefined || plan.fl === undefined || plan.cr === undefined || plan.more === undefined) return BAD;
    for (var a = 0; a < z.length; a++) {
      if (!isTable(z[a]) || typeof z[a].s.n !== "string") return BAD;
      var m = opt(z[a].s.m, null);
      if (m === undefined) return BAD;
      plan.z.push({ m: m, n: z[a].s.n });
    }
    for (var b = 0; b < st.length; b++) {
      var s = st[b];
      if (!isTable(s) || typeof s.s.k !== "string" || !Object.prototype.hasOwnProperty.call(KINDS, s.s.k) || typeof s.s.t !== "string") return BAD;
      var zi = s.s.z === undefined ? null : s.s.z, x = opt(s.s.x, null), y = opt(s.s.y, null);
      if (x === undefined || y === undefined) return BAD;
      if (zi !== null && (typeof zi !== "number" || zi < 1 || zi > plan.z.length || zi % 1 !== 0)) return BAD;
      plan.st.push({ k: s.s.k, t: s.s.t, z: zi, x: x, y: y });
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
