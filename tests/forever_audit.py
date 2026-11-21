"""WoW: Forever audit: the add-on uses only what the Forever client has.

Every game name the add-on reaches for is looked up in tests/forever_api.json.gz (made from the live
client by tests/make_forever_api.py):
  * the game's globals it reads (found by luacheck), and those it reads through _G.Name or _G["Name"];
  * the functions and fields of the game's tables it calls: C_Spell.GetSpellInfo, Enum.BagIndex.Bank,
    SOUNDKIT.READY_CHECK, Constants..., and the same through a local name (local T = C_TradeSkillUI);
  * the events it registers for or compares against, and none Forever keeps from add-ons (the combat log);
  * the game settings (CVars) it reads or sets, the templates it builds frames from, the built-in art
    (atlases) it shows, and the methods it calls on frames.
Each name Forever lacks is listed with where it is used, and the script fails. A few names are not the
game's at all and are allowed below, each with the reason.
"""
import collections
import glob
import gzip
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + "/"
API = json.load(gzip.open(ROOT + "tests/forever_api.json.gz", "rt", encoding="utf-8"))
GLOBALS, FIELDS = set(API["globals"]), set(API["fields"])
ENUM = {k: set(v) for k, v in API["enum"].items()}
EVENTS, CVARS, TEMPLATES = set(API["events"]), set(API["cvars"]), set(API["templates"])
RESTRICTED = set(API["restricted_events"])
METHODS, ATLASES = set(API["methods"]), set(API["atlases"])
LUA51 = set("assert collectgarbage dofile error getfenv getmetatable ipairs load loadfile loadstring module next pairs pcall "
            "print rawequal rawget rawset require select setfenv setmetatable tonumber tostring type unpack xpcall _G _VERSION "
            "coroutine debug io math os package string table".split())
# Not the game's: names other add-ons provide, and ones this add-on makes itself.
NOT_THE_GAMES = {
    "LibStub": "the library loader other add-ons share; looked for, never required",
    "GetMinimapShape": "a function other add-ons ask the minimap for; this add-on sets it",
    "StylishUIDB": "the add-on's settings under its former name, read once to bring them over",
}
LAYERS = {"BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT"}

FOLDERS = ["FantasyGlassUI", "FantasyGlassUI_Options", "FantasyGlassUI_Locales"]
files = sorted(f for d in FOLDERS for f in glob.glob(ROOT + d + "/**/*.lua", recursive=True))
src = {f: open(f, encoding="utf-8").read() for f in files}


def blank(text):
    """The code with comments and the insides of strings blanked out (line numbers kept)."""
    out, i, n = [], 0, len(text)
    while i < n:
        m = re.compile(r"--\[(=*)\[").match(text, i) if text.startswith("--[", i) else None
        if m or (text.startswith("[", i) and re.compile(r"\[(=*)\[").match(text, i)):
            m = m or re.compile(r"\[(=*)\[").match(text, i)
            end = text.find("]" + m.group(1) + "]", m.end())
            end = n if end < 0 else end + len(m.group(1)) + 2
            out.append(re.sub(r"[^\n]", " ", text[i:end]))
            i = end
            continue
        if text.startswith("--", i):
            end = text.find("\n", i)
            end = n if end < 0 else end
            out.append(" " * (end - i))
            i = end
            continue
        c = text[i]
        if c in "\"'":
            j = i + 1
            while j < n and text[j] != c and text[j] != "\n":
                j += 2 if text[j] == "\\" else 1
            out.append(c + re.sub(r"[^\n]", " ", text[i + 1:j]) + c)
            i = j + 1
            continue
        out.append(c)
        i += 1
    return "".join(out)


code = {f: blank(s) for f, s in src.items()}
found = collections.OrderedDict()


def where(f, pos):
    return f.replace(ROOT, "") + ":" + str(src[f].count("\n", 0, pos) + 1)


def note(kind, name, loc):
    found.setdefault(kind, collections.OrderedDict()).setdefault(name, []).append(loc)


def field_ok(full):
    parts = full.split(".")
    if parts[0] == "Enum":
        return len(parts) < 2 or (parts[1] in ENUM and (len(parts) < 3 or parts[2] in ENUM[parts[1]]))
    if parts[0] == "Constants":
        return ".".join(parts[:3]) in FIELDS
    return ".".join(parts[:2]) in FIELDS


# 1. globals (luacheck lists every global read; the add-on's own come from .luacheckrc's "globals")
rc = open(ROOT + ".luacheckrc", encoding="utf-8").read()
own = set(re.findall(r'"([^"]+)"', rc[rc.index("globals = {"):rc.index("}", rc.index("globals = {"))]))
cfg = ROOT + "tests/.cache/forever.luacheckrc"
os.makedirs(os.path.dirname(cfg), exist_ok=True)
open(cfg, "w").write('std = "lua51"\nmax_line_length = false\nignore = { "2", "4", "5", "6" }\nglobals = {'
                     + ", ".join(f'"{g}"' for g in sorted(own)) + "}\n")
lc = subprocess.run(["luacheck", *FOLDERS, "--config", cfg, "--formatter", "plain", "--codes", "--no-color", "-q"],
                    cwd=ROOT, capture_output=True, text=True).stdout
read = collections.defaultdict(list)
for line in lc.splitlines():
    m = re.match(r"(.+?):(\d+):\d+: \(W113\) accessing undefined variable '(.+)'", line)
    if m:
        read[m.group(3)].append(f"{m.group(1)}:{m.group(2)}")
for g, locs in read.items():
    if g not in LUA51 and g not in GLOBALS and g not in NOT_THE_GAMES:
        for loc in locs:
            note("Globals Forever does not have", g, loc)
for g in own:
    if not g.startswith(("FantasyGlassUI", "SLASH_", "BINDING_")) and g not in GLOBALS and g not in NOT_THE_GAMES:
        note("Game globals the add-on writes that Forever does not have", g, ".luacheckrc")
for f in files:
    for m in re.finditer(r'_G\.([A-Za-z_]\w*)|_G\["([A-Za-z_]\w*)"\]', src[f]):
        g = m.group(1) or m.group(2)
        if g in LUA51 or g in GLOBALS or g in own or g in NOT_THE_GAMES or g.startswith(("FantasyGlassUI", "SLASH_", "BINDING_")):
            continue
        note("Globals read through _G that Forever does not have", g, where(f, m.start()))

# 2. the game's tables: Name.Field[.Field], directly and through a local name
game_tables = {g for g in set(read) | own if g in GLOBALS and g not in LUA51}
for f in files:
    for m in re.finditer(r"(?<![\w.:])([A-Za-z_]\w*)\s*\.\s*([A-Za-z_]\w*)(?:\s*\.\s*([A-Za-z_]\w*))?", code[f]):
        a, b, c = m.groups()
        if a not in game_tables or not (a.startswith("C_") or a in ("Enum", "Settings", "Menu", "MenuUtil", "Constants", "ChatFrameUtil", "AuraUtil", "bit")):
            continue
        full = a + "." + b + ("." + c if c and a in ("Enum", "Constants") else "")
        if not field_ok(full):
            note("Game functions and fields Forever does not have", full, where(f, m.start()))
    for m in re.finditer(r'local\s+(\w+)\s*=\s*(?:type\((?:C_\w+)\)\s*==\s*"table"\s*and\s*)?(C_\w+)\b(?=[ \t]*(?:\n|;|\)|or\b|--))', code[f]):
        alias, table = m.group(1), m.group(2)
        for k in re.finditer(r"(?<![\w.:])" + alias + r"\s*\.\s*([A-Za-z_]\w*)", code[f][m.end():m.end() + 6000]):
            if not field_ok(table + "." + k.group(1)):
                note("Game functions and fields Forever does not have", f"{table}.{k.group(1)} (as {alias})", where(f, m.end() + k.start()))

# 3. events: registered, compared against, or listed for registering
for f in files:
    s = src[f]
    used = [(m.group(1), m.start()) for m in re.finditer(r'(?:Register(?:Unit)?Event|UnregisterEvent|IsEventRegistered)\s*\(\s*[\w.]*\s*,?\s*"([A-Z0-9_]+)"', s)]
    used += [(m.group(1), m.start()) for m in re.finditer(r'\bevent\s*==\s*"([A-Z0-9_]+)"', s)]
    for m in re.finditer(r'\{((?:\s*"[A-Z][A-Z0-9_]+"\s*,?)+)\s*\}', s):
        names = re.findall(r'"([A-Z][A-Z0-9_]+)"', m.group(1))
        after = s[m.end():m.end() + 200]
        if "RegisterEvent" in after or "RegisterUnitEvent" in after or (len(names) > 1 and sum(n in EVENTS for n in names) > len(names) // 2):
            used += [(n, m.start()) for n in names]
    for name, pos in used:
        if name not in EVENTS:
            note("Events Forever does not send", name, where(f, pos))
        elif name in RESTRICTED:
            note("Events Forever keeps from add-ons", name, where(f, pos))

# 4. settings, templates, art, sounds, frame methods
own_methods = set()
for f in files:
    own_methods |= set(re.findall(r"function\s+[\w.]+[:.](\w+)\s*\(", code[f]))
    own_methods |= set(re.findall(r"[.:](\w+)\s*=\s*function", code[f]))
    own_methods |= set(re.findall(r"(?:^|[\s{,])(\w+)\s*=\s*function", code[f], re.M))
    own_methods |= set(re.findall(r"(?:^|[\s{,])(\w+)\s*=\s*[\w.]+\s*[,}\n]", code[f], re.M))
LIBRARY_METHODS = {"NewDataObject", "DataObjectIterator"}       # LibDataBroker's, when another add-on brings it
LUA_STRING = set("byte char find format gmatch gsub len lower match rep reverse sub upper".split())   # ("text":lower() and the like)
for f in files:
    s = src[f]
    for m in re.finditer(r'(?:GetCVar|SetCVar|GetCVarBool|GetCVarDefault|CVarGet|C_CVar\.\w+)\s*\(\s*"([^"]+)"', s):
        if m.group(1).lower() not in CVARS:
            note("Game settings (CVars) Forever does not have", m.group(1), where(f, m.start()))
    for m in re.finditer(r'CreateFrame\s*\(\s*"\w+"\s*,[^,()]*,[^,()]*,\s*"([^"]+)"', s):
        for t in m.group(1).split(","):
            if t.strip() and t.strip() not in TEMPLATES:
                note("Templates Forever does not have", t.strip(), where(f, m.start()))
    for m in re.finditer(r'(?:SetAtlas|CreateAtlasMarkup|GetAtlasInfo)\s*\(\s*"([^"]+)"', s):
        if m.group(1).lower() not in ATLASES:
            note("Built-in art (atlases) Forever does not have", m.group(1), where(f, m.start()))
    for m in re.finditer(r"SOUNDKIT\.(\w+)", code[f]):
        if "SOUNDKIT." + m.group(1) not in FIELDS:
            note("Sounds Forever does not have", "SOUNDKIT." + m.group(1), where(f, m.start()))
    for m in re.finditer(r":\s*([A-Za-z_]\w*)\s*\(", code[f]):
        name = m.group(1)
        if name not in METHODS and name not in own_methods and name not in LIBRARY_METHODS and name not in LUA_STRING:
            note("Frame methods Forever does not have", name, where(f, m.start()))

print(f"WoW: Forever {API['build']}: {len(files)} files checked")
if not found:
    print("Everything the add-on uses is in Forever.")
    sys.exit(0)
for kind, names in found.items():
    print(f"\n{kind}: {len(names)}")
    for name, locs in sorted(names.items()):
        print(f"  {name}   " + ", ".join(locs[:4]) + (f" (+{len(locs) - 4} more)" if len(locs) > 4 else ""))
sys.exit(1)
