"""Makes FantasyGlassUI/HealthNeeds.lua: what each part of the add-on needs from the game, for the check after a
game update (FantasyGlassUI/Health.lua).

The names come from the WoW: Forever audit (tests/forever_audit.py, scan()): the game's globals each file reads and
the game's table fields it uses (C_Timer.After, Enum.BagIndex.Bank), with the lines they are used on. Only plain API
functions and globals from the game's core count as needs (13.5 part two, P2-I4): the client's own functions and C_
tables, its enums, constants and global strings, and what its always-loaded interface code defines that is not a
frame (tests/make_forever_api.py's core_globals and core_fields). Frames, templates and anything only a
load-on-demand or optional Blizzard add-on makes are never needs: whether they are there at login depends on what
is loaded, not on the game's build.

A part is a module (ns:NewModule("<key>", function() ... end)): a name is that module's need when it is used inside
the module's own function. A name used anywhere else in a FantasyGlassUI/*.lua file (code the file's modules share,
or code no module runs) cannot be tied to one module: it goes to "core", reported by /fgui health and never turned
off. The planner folder is the part "planner", the gold folder "gold"; the options folder and the locales folder are
"core". Labels come from the options' FeatureList.lua.

    python3 tests/health_needs.py           writes the file
    python3 tests/health_needs.py --check   exits 1 when the file is out of date
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import forever_audit  # noqa: E402

ROOT = forever_audit.ROOT
CORE_GLOBALS = set(forever_audit.API.get("core_globals", []))
CORE_FIELDS = set(forever_audit.API.get("core_fields", []))
OUT = ROOT + "FantasyGlassUI/HealthNeeds.lua"
FOLDER_PARTS = {"FantasyGlassUI_Planner": "planner", "FantasyGlassUI_Gold": "gold"}
LABELS = {"planner": "Route planner", "gold": "Ways to make gold", "core": "Fantasy Glass UI",
          # (modules with no switch on the Features tab)
          "fallbacks": "Blizzard's own frames, restyled", "microMenu": "The game's menu buttons",
          "groupWatch": "Who is in your group"}
HEADER = """local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: what each part of the add-on needs from the game, for the check after a game update (Health.lua). Made by
-- tests/health_needs.py from the WoW: Forever audit's data, so it never drifts. Do not edit it by hand: run
-- python3 tests/health_needs.py. Only the game's own functions and globals (no frames, no templates, nothing an
-- optional Blizzard add-on makes), each under the module whose own code uses it; the rest is "core" (never off).
--   HEALTH_NAMES: every name, sorted. HEALTH_NEEDS: [part] = { label = ..., index, ... }.
------------------------------------------------------------------------------------------
"""


def is_core(name):
    """A plain API function or global from the game's core (never a template, a frame, or what an optional add-on makes)."""
    if name.startswith("t:"):
        return False
    if "." in name:
        return name.split(".")[0] in ("Enum", "Constants") or name in CORE_FIELDS
    return name in CORE_GLOBALS


BLOCK = re.compile(r"\b(function|do|if|repeat|end|until)\b")
MODULE = re.compile(r'ns:NewModule\(\s*"([^"\n]*)"\s*,\s*(?=function\b)')       # (in the blanked code: the key is read from the source)


def module_spans(path):
    """[(first line, last line, key)] of each module's own function in a file (comments and strings blanked)."""
    code, src = forever_audit.code[ROOT + path], forever_audit.src[ROOT + path]
    spans = []
    for m in MODULE.finditer(code):
        key = src[m.start(1):m.end(1)]
        depth, end = 0, None
        for t in BLOCK.finditer(code, m.end()):
            depth += 1 if t.group(1) in ("function", "do", "if", "repeat") else -1
            if depth == 0:
                end = t.end()
                break
        if end is None:
            raise SystemExit(f"{path}: the module {key} has no end")
        spans.append((code.count("\n", 0, m.start()) + 1, code.count("\n", 0, end) + 1, key))
    return spans


def part_of_line(spans, line):
    """The module whose own function holds this line (the innermost), or "core"."""
    best = None
    for first, last, key in spans:
        if first <= line <= last and (best is None or last - first < best[1] - best[0]):
            best = (first, last, key)
    return best[2] if best else "core"


def parts_of(path, name, lines):
    """The parts a name used on these lines of a file belongs to."""
    folder = path.split("/", 1)[0]
    if folder in FOLDER_PARTS:
        return {FOLDER_PARTS[folder]}
    if folder == "FantasyGlassUI":
        spans = module_spans(path)
        return {part_of_line(spans, line) for line in lines} if lines else {"core"}
    return {"core"}


def labels():
    out = dict(LABELS)
    text = open(ROOT + "FantasyGlassUI_Options/FeatureList.lua", encoding="utf-8").read()
    for key, label in re.findall(r'\{\s*"(\w+)"\s*,\s*"([^"\\]+)"\s*\}', text):
        out.setdefault(key, label)
    return out


def lua_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def make():
    found, uses = forever_audit.scan()
    need = {"core": set(), "planner": set(), "gold": set()}
    for path, u in uses.items():
        for name in u["globals"] | u["fields"]:
            if is_core(name):
                for part in parts_of(path, name, u["at"].get(name, ())):
                    need.setdefault(part, set()).add(name)
    names = sorted(set().union(*need.values()))
    index = {n: i + 1 for i, n in enumerate(names)}
    label = labels()
    out = [HEADER, "ns.HEALTH_BUILD = " + lua_string(forever_audit.API["build"]) + "\n", "ns.HEALTH_NAMES = {\n"]
    for i in range(0, len(names), 6):
        out.append("    " + " ".join(lua_string(n) + "," for n in names[i:i + 6]) + "\n")
    out.append("}\nns.HEALTH_NEEDS = {\n")
    for part in sorted(need):
        if not need[part] and part not in ("core", "planner", "gold"):
            continue
        idx = sorted(index[n] for n in need[part])
        out.append(f"    [{lua_string(part)}] = {{ label = {lua_string(label.get(part, part))},")
        for i in range(0, len(idx), 20):
            out.append("\n        " + " ".join(f"{n}," for n in idx[i:i + 20]))
        out.append("\n    },\n")
    out.append("}\n")
    return "".join(out)


def main():
    text = make()
    if "--check" in sys.argv[1:]:
        old = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if old != text:
            print("HealthNeeds.lua is out of date: run python3 tests/health_needs.py")
            sys.exit(1)
        sys.exit(0)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print(f"wrote {OUT.replace(ROOT, '')}")


if __name__ == "__main__":
    main()
