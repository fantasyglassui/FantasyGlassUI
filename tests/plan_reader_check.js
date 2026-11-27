// The website's plan reader against tests/plan_codes.txt (the same file the add-on's test reads), and the page's rules.
// usage: node tests/plan_reader_check.js   ->   "plan reader: <n> codes OK"
var fs = require("fs"), path = require("path");
var ROOT = path.join(__dirname, "..");
var FGPlan = require(path.join(ROOT, "site-src", "plan", "reader.js"));
function fail(msg) { console.error("plan reader: " + msg); process.exit(1); }
function eq(a, b, what) { if (JSON.stringify(a) !== JSON.stringify(b)) fail(what + ": " + JSON.stringify(a) + " is not " + JSON.stringify(b)); }

var lines = fs.readFileSync(path.join(ROOT, "tests", "plan_codes.txt"), "utf8").split(/\r?\n/).filter(function (l) { return l !== ""; });
var oks = [], seenWhy = {};
lines.forEach(function (line) {
  var f = line.split("\t");
  if (f[0] === "ok") {
    var r = FGPlan.read(f[5]);
    if (!r.ok) fail("an ok line reads: " + f[5] + " (" + r.why + ")");
    eq(r.plan.st.length, Number(f[1]), "steps");
    eq(r.plan.z.length, Number(f[2]), "zones");
    eq(r.plan.xp, f[3] === "-" ? null : Number(f[3]), "xp");
    eq(r.plan.st.map(function (s) { return s.k; }).join(","), f[4], "kinds");
    oks.push(r.plan);
  } else if (f[0] === "bad") {
    var b = FGPlan.read(f[2] || "");
    if (b.ok || b.why !== f[1]) fail("a bad line reads as " + f[1] + ": " + JSON.stringify(b));
    seenWhy[f[1]] = true;
  } else fail("a line is ok or bad: " + line);
});
["empty", "kind", "damaged", "version"].forEach(function (w) { if (!seenWhy[w]) fail("no bad line for " + w); });
if (oks.length < 2) fail("two ok lines");

var bare = lines.map(function (l) { return l.split("\t"); }).filter(function (f) { return f[0] === "ok" && f[3] === "-"; });
if (bare.length < 1) fail("an ok line without experience");
var tb = FGPlan.totals(FGPlan.read(bare[0][5]).plan);
eq([tb.xp, tb.seconds], [null, null], "no experience or time in the code: none, not 0");
var plan = oks[0], t = FGPlan.totals(plan);
eq([t.xp, t.seconds, t.from, t.to, t.flights, t.crossings, t.steps], [4100, 1800, 8, 10, 1, 0, 5], "totals");
var ps = FGPlan.panels(plan);
eq(ps.length, 2, "two panels");
eq(ps.map(function (p) { return p.name; }), ["Elwynn Forest", "Stormwind City"], "panel names");
eq(ps.reduce(function (a, p) { return a.concat(p.stops.map(function (s) { return s.n; })); }, []), [1, 2, 3], "three stops numbered 1 to 3");
eq(ps.reduce(function (a, p) { return a.concat(p.stops.map(function (s) { return s.kind; })); }, []), ["accept", "turnin", "fly"], "no stop for do or note");
eq(ps[1].legs.map(function (l) { return [l.from, l.to, l.kind]; }), [[1, 2, "fly"]], "the fly leg between the panels");
eq(ps[0].legs.length, 0, "no leg in the first panel");
var p2 = FGPlan.panels(oks[1]);
eq(p2.map(function (p) { return p.legs.map(function (l) { return l.kind; }).join(); }), ["", "hearth,sail"], "the second plan's legs");
eq(FGPlan.hash("a") === FGPlan.hash("a") && FGPlan.hash("a") !== FGPlan.hash("b"), true, "hash");
eq(/^[0-9a-f]{8}$/.test(FGPlan.hash("SUIP1!")), true, "hash is 8 hex digits");

// a few more refusals the add-on's reader makes too
var first = lines.filter(function (l) { return l.indexOf("ok\t") === 0; })[0].split("\t")[5];
eq(FGPlan.read(first + "x").why, "damaged", "text after the code");
eq(FGPlan.read("  " + first + "\n").ok, true, "spaces around the code");
eq(FGPlan.read("SUIP1!{S1:vN1;S2:lv{N1;N1;N2;N2;}S1:z{}S2:st{N1;{S1:kS4:warpS1:tS1:x}}}").why, "damaged", "a step with a kind that is not a guide kind");
eq(FGPlan.read("SUIP1!{S1:vN1;S2:lv{N1;N1;N2;N2;}S1:z{}S2:st{N1;{S1:tS1:x}}}").why, "damaged", "a step without a kind");
eq(FGPlan.read("SUIT1!{S4:nameS1:x}").other, true, "a theme code is told apart");
eq(FGPlan.read("hello").other, false, "other text is not");
eq(FGPlan.read(null).why, "empty", "nothing");

// the page and the reader: nothing leaves the browser
var banned = /fetch\(|XMLHttpRequest|sendBeacon|WebSocket|<script src|<link|https?:\/\//;
["reader.js", "page.html"].forEach(function (name) {
  var text = fs.readFileSync(path.join(ROOT, "site-src", "plan", name), "utf8").replace(/fantasyglassui\.com/g, "");
  var m = banned.exec(text);
  if (m) fail(name + " contains " + m[0]);
});
console.log("plan reader: " + lines.length + " codes OK");
