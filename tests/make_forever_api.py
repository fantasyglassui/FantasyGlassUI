"""Make tests/forever_api.json.gz: every name the WoW: Forever client offers add-ons.

The add-on is checked against this list (tests/forever_audit.py), so it calls only what the game has.
Make it again when Forever updates:

    git clone --depth 1 -b forever https://github.com/Ketho/BlizzardInterfaceResources.git bir
    git clone --depth 1 -b forever https://github.com/Gethe/wow-ui-source.git uisrc
    python3 tests/make_forever_api.py bir uisrc

Sources: BlizzardInterfaceResources holds dumps taken from the live client (its functions, events,
widget methods, enums, settings and art); wow-ui-source holds the client's own interface code, read
here only for the files Forever loads (game type "camelot", in the Mainline family). The fallbacks in
Blizzard_Deprecated* are left out on purpose: Blizzard removes them, so the add-on must not lean on them.
"""
import glob
import gzip
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
BIR, UI = sys.argv[1], sys.argv[2]
R = os.path.join(BIR, "Resources")
ADDONS = os.path.join(UI, "Interface", "AddOns")
FOREVER = {"camelot", "mainline"}          # the game type and its family


def read(path):
    return open(path, encoding="utf-8", errors="replace").read()


def quoted(path):
    return set(re.findall(r'^\s*"([^"]+)",', read(path), re.M))


# ---- which interface files Forever loads ---------------------------------------------------------
def words(text):
    return [w for w in re.split(r"[,\s]+", text) if w]


def allowed(allow, exclude):
    if allow is not None and not set(allow) & FOREVER:
        return False
    if exclude is not None and set(exclude) & FOREVER:
        return False
    return True


def follow(path, out):
    real = path if os.path.exists(path) else None
    if not real:
        folder, base = os.path.split(path)
        if os.path.isdir(folder):
            for f in os.listdir(folder):
                if f.lower() == base.lower():
                    real = os.path.join(folder, f)
    if not real or real in out:
        return
    out.add(real)
    if real.endswith(".xml"):
        for m in re.finditer(r'<(?:Include|Script)\s+file="([^"]+)"', read(real)):
            follow(os.path.join(os.path.dirname(real), m.group(1).replace("\\", "/")), out)


def loaded_files():
    out = set()
    for toc in glob.glob(os.path.join(ADDONS, "*", "*.toc")):
        folder = os.path.dirname(toc)
        if os.path.basename(toc)[:-4] != os.path.basename(folder):
            continue
        if "Deprecated" in os.path.basename(folder):
            continue
        text = read(toc)
        a = re.search(r"^## AllowLoadGameType:\s*(.+)$", text, re.M)
        e = re.search(r"^## ExcludeLoadGameType:\s*(.+)$", text, re.M)
        if not allowed(words(a.group(1)) if a else None, words(e.group(1)) if e else None):
            continue
        for line in text.split("\n"):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            a = re.search(r"\[AllowLoadGameType ([^\]]+)\]", s)
            e = re.search(r"\[ExcludeLoadGameType ([^\]]+)\]", s)
            if not allowed(words(a.group(1)) if a else None, words(e.group(1)) if e else None):
                continue
            p = re.sub(r"(?:\s+\[[^\]]*\])+\s*$", "", s).replace("[Family]", "Mainline").replace("[Game]", "Camelot")
            follow(os.path.join(folder, p.replace("\\", "/").strip()), out)
    return out


# ---- names the loaded XML creates (with $parent worked out, and template children carried over) ----
def xml_names(files):
    def tag(el):
        return el.tag.split("}")[-1]
    templates, concrete, names, fonts = {}, [], set(), set()
    for f in files:
        txt = read(f)
        txt = re.sub(r"<Script[^>]*>.*?</Script>", "", txt, flags=re.S)
        try:
            root = ET.fromstring(txt)
        except ET.ParseError:
            continue

        def walk(el, top):
            nm = el.get("name")
            if nm is not None and tag(el) in ("Font", "FontFamily"):
                fonts.add(nm)                                   # (a font object is global even when "virtual")
            if nm is not None and el.get("virtual") == "true":
                templates[nm] = el
            elif top and nm is not None:
                concrete.append(el)
            for ch in el:
                walk(ch, top and nm is None)
        walk(root, True)

    def inherits(el):
        return [x.strip() for x in (el.get("inherits") or "").split(",") if x.strip()]

    def expand(el, full, depth):
        if depth > 12:
            return
        if full:
            names.add(full)
        for t in inherits(el):
            if t in templates:
                expand(templates[t], full, depth + 1)
        for ch in el:
            if tag(ch) in ("Frames", "Layers", "Layer", "Animations"):
                expand(ch, full, depth + 1)
                continue
            nm = ch.get("name")
            child = None
            if nm and (full is not None or "$" not in nm):
                child = nm.replace("$parent", full or "").replace("$Parent", full or "")
            if child and "$" not in child:
                names.add(child)
            expand(ch, child, depth + 1)
    for el in concrete:
        expand(el, el.get("name"), 0)
    return names | fonts


# ---- put it together ------------------------------------------------------------------------------
files = loaded_files()
lua = sorted(f for f in files if f.endswith(".lua"))
xml = sorted(f for f in files if f.endswith(".xml"))

api = quoted(os.path.join(R, "GlobalAPI.lua")) | quoted(os.path.join(R, "FrameXML.lua"))
globals_ = {n for n in api if "." not in n} | {n.split(".")[0] for n in api if "." in n}
globals_ |= quoted(os.path.join(R, "Frames.lua")) | quoted(os.path.join(R, "Mixins.lua"))
globals_ |= set(re.findall(r"^([A-Za-z0-9_]+) = ", read(os.path.join(R, "GlobalStrings", "enUS.lua")), re.M))
fields = {n for n in api if "." in n}

for f in lua:
    t = read(f)
    globals_ |= set(re.findall(r"^([A-Za-z_]\w*)\s*=[^=]", t, re.M))
    globals_ |= set(re.findall(r"^function\s+([A-Za-z_]\w*)\s*\(", t, re.M))
    globals_ |= set(re.findall(r'_G\["([A-Za-z_]\w*)"\]\s*=', t)) | set(re.findall(r"_G\.([A-Za-z_]\w*)\s*=[^=]", t))
    for a, b in re.findall(r"^\s*(?:function\s+)?([A-Za-z_]\w*)\.([A-Za-z_]\w*)\s*[=(]", t, re.M):
        fields.add(a + "." + b)
    for name, body in re.findall(r"^([A-Z][A-Za-z0-9_]+)\s*=\s*\{(.*?)^\}", t, re.M | re.S):
        for k in re.findall(r'^\s*\[?"?([A-Za-z_]\w*)"?\]?\s*=', body, re.M):
            fields.add(name + "." + k)
for f in xml:
    for m in re.finditer(r"<Script[^>]*>(.*?)</Script>", read(f), re.S):
        globals_ |= set(re.findall(r"^\s*([A-Za-z_]\w*)\s*=[^=]", m.group(1), re.M))
globals_ |= xml_names(xml)

enum = {}
current = None
for line in read(os.path.join(R, "LuaEnum.lua")).split("\n"):
    m = re.match(r"^\t([A-Za-z0-9_]+) = \{", line)
    if m:
        current = m.group(1)
        enum[current] = []
        continue
    m = re.match(r"^\t\t([A-Za-z0-9_]+) = ", line)
    if m and current:
        enum[current].append(m.group(1))
globals_ |= set(re.findall(r"^([A-Za-z0-9_]+) = ", read(os.path.join(R, "LuaEnum.lua")), re.M))

events = set(re.findall(r'^\t\t"([A-Z0-9_]+)",', read(os.path.join(R, "Events.lua")), re.M))
cvars = {k.lower() for k in re.findall(r'\["([^"]+)"\] = \{', read(os.path.join(R, "CVars.lua")))}
templates = set(re.findall(r'^\t\["([^"]+)"\] = \{', read(os.path.join(R, "Templates.lua")), re.M))
methods = set(re.findall(r'^\t\t\t?"([A-Za-z0-9_]+)",', read(os.path.join(R, "WidgetAPI.lua")) + read(os.path.join(R, "ScriptObjectAPI.lua")), re.M))
for f in lua:
    methods |= set(re.findall(r"function\s+[A-Za-z_][\w.]*[:.]([A-Za-z_]\w*)\s*\(", read(f)))
    methods |= set(re.findall(r"\bself\.([A-Z]\w*)\s*=\s*\w", read(f)))                 # (methods set on a frame: SetFrameRef)
    methods |= set(re.findall(r'^\s*(Set\w+)\s*=\s*"Get\w+",', read(f), re.M))       # (the tooltip's SetBagItem and kin)
for f in xml:
    methods |= set(re.findall(r'method="(\w+)"', read(f)))
# events the client documents as restricted: add-ons cannot have them (the combat log among them)
restricted = set()
for f in glob.glob(os.path.join(ADDONS, "Blizzard_APIDocumentationGenerated", "*.lua")):
    for m in re.finditer(r'LiteralName = "([A-Z0-9_]+)",\s*HasRestrictions = true', read(f)):
        restricted.add(m.group(1))
# Constants.X (from the client's own documentation of its constant tables)
for f in glob.glob(os.path.join(ADDONS, "Blizzard_APIDocumentationGenerated", "*.lua")):
    for m in re.finditer(r'Name = "(\w+)",\s*Type = "Constants",\s*Values\s*=\s*\{(.*?)\n\t\t\t\}', read(f), re.S):
        fields.add("Constants." + m.group(1))
        fields |= {"Constants." + m.group(1) + "." + v for v in re.findall(r'\{ Name = "(\w+)"', m.group(2))}
atlases = {k.lower() for k in re.findall(r'\["([^"]+)"\]', read(os.path.join(R, "AtlasInfo.lua")))}

def subject(repo):
    return os.popen(f"git -C {repo} log -1 --format=%s").read().strip()
build = f"{subject(BIR)} dumps, interface code {subject(UI)}"
snapshot = {
    "build": build,
    "globals": sorted(globals_),
    "fields": sorted(fields),
    "enum": {k: sorted(v) for k, v in sorted(enum.items())},
    "events": sorted(events),
    "restricted_events": sorted(restricted),
    "cvars": sorted(cvars),
    "templates": sorted(templates),
    "methods": sorted(methods),
    "atlases": sorted(atlases),
}
with open(os.path.join(HERE, "forever_api.json.gz"), "wb") as raw:              # (mtime 0: the same input makes the same file)
    with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as out:
        out.write(json.dumps(snapshot, separators=(",", ":")).encode("utf-8"))
print(f"WoW: Forever {build}: {len(globals_)} globals, {len(fields)} fields, {len(events)} events ({len(restricted)} restricted), "
      f"{len(cvars)} settings, {len(templates)} templates, {len(methods)} methods, {len(atlases)} atlases")
