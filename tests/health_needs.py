"""Makes FantasyGlassUI/HealthNeeds.lua: what each part of the add-on needs from the game, for the check after a
game update (FantasyGlassUI/Health.lua).

The names come from the WoW: Forever audit (tests/forever_audit.py, scan()): the game's globals each file reads, the
game's table fields it uses (C_Timer.After, Enum.BagIndex.Bank) and the templates it builds frames from (t:<name>).
A part is a module (ns:NewModule("<key>", ...)): every name a FantasyGlassUI/*.lua file reads belongs to every module
that file defines. The planner folder is the part "planner", the gold folder "gold"; files with no module, the options
folder and the locales folder are "core" (reported, never turned off). Labels come from the options' FeatureList.lua.

    python3 tests/health_needs.py           writes the file
    python3 tests/health_needs.py --check   exits 1 when the file is out of date
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import forever_audit  # noqa: E402

ROOT = forever_audit.ROOT
OUT = ROOT + "FantasyGlassUI/HealthNeeds.lua"
FOLDER_PARTS = {"FantasyGlassUI_Planner": "planner", "FantasyGlassUI_Gold": "gold"}
LABELS = {"planner": "Route planner", "gold": "Ways to make gold", "core": "Fantasy Glass UI",
          # (modules with no switch on the Features tab)
          "fallbacks": "Blizzard's own frames, restyled", "microMenu": "The game's menu buttons",
          "groupWatch": "Who is in your group"}
HEADER = """local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: what each part of the add-on needs from the game (APIs, fields, templates), for the check after a game
-- update (Health.lua). Made by tests/health_needs.py from the WoW: Forever audit's data, so it never drifts.
-- Do not edit it by hand: run python3 tests/health_needs.py.
--   HEALTH_NAMES: every name, sorted ("t:<name>" is a template). HEALTH_NEEDS: [part] = { label = ..., index, ... }.
------------------------------------------------------------------------------------------
"""


def parts_of(path):
    """The parts a file's names belong to."""
    folder = path.split("/", 1)[0]
    if folder in FOLDER_PARTS:
        return [FOLDER_PARTS[folder]]
    if folder == "FantasyGlassUI":
        keys = re.findall(r'ns:NewModule\("(\w+)"', open(ROOT + path, encoding="utf-8").read())
        if keys:
            return sorted(set(keys))
    return ["core"]


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
        names = u["globals"] | u["fields"] | {"t:" + t for t in u["templates"]}
        for part in parts_of(path):
            need.setdefault(part, set()).update(names)
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
