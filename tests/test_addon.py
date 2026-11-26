"""The add-on's checks, run on every push and pull request (see .github/workflows/Testing.yml).

These are the same checks run before each build:
  * the test harness: the add-on loads in a stand-in for the game and every part is exercised, once
    with combat values readable and once with them hidden as the game does in a fight;
  * the hidden-value audit: no value the game hides in combat is ever compared;
  * the combat audit: nothing the game locks in a fight is shown, hidden, moved or resized then;
  * the WoW: Forever audit: every function, event, frame and setting the add-on uses is one Forever has;
  * the version numbers of the three folders agree, and the README is up to date.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS = os.path.join(ROOT, "tests")


def run(script, cwd, timeout):
    p = subprocess.run([sys.executable, os.path.join(TESTS, script)], cwd=cwd,
                       capture_output=True, text=True, timeout=timeout)
    return p.stdout + p.stderr


def toc_version(folder):
    text = open(os.path.join(ROOT, folder, folder + ".toc"), encoding="utf-8").read()
    return re.search(r"^## Version:\s*(\S+)", text, re.M).group(1)


def test_versions_agree():
    main = toc_version("FantasyGlassUI")
    core = re.search(r'^ns\.version = "([^"]+)"', open(os.path.join(ROOT, "FantasyGlassUI", "Core.lua"), encoding="utf-8").read(), re.M).group(1)
    assert core == main, f"Core.lua says {core}, the TOC says {main}"
    assert toc_version("FantasyGlassUI_Options") == main
    assert toc_version("FantasyGlassUI_Locales") == main
    assert toc_version("FantasyGlassUI_Planner") == main
    assert toc_version("FantasyGlassUI_Gold") == main


# The two load-on-demand folders (the folders plan, rulings 1-6): what their TOCs say, what is in them,
# and what the main add-on may call in them.
FOLDER_KEYS = {"planner": "FantasyGlassUI_Planner", "gold": "FantasyGlassUI_Gold"}


def folders_lua():
    return open(os.path.join(ROOT, "FantasyGlassUI", "Folders.lua"), encoding="utf-8").read()


def folder_files(key):
    """ns.FOLDERS[key].files, as Folders.lua lists them."""
    text = folders_lua()
    m = re.search(r"^\s*%s\s*=\s*\{\s*addon\s*=\s*\"(\w+)\",\s*files\s*=\s*\{(.*?)\}" % key, text, re.M | re.S)
    assert m, f"ns.FOLDERS.{key} not found in Folders.lua"
    assert m.group(1) == FOLDER_KEYS[key]
    return re.findall(r'"([\w.]+\.lua)"', m.group(2))


def toc_lines(folder):
    return [l.rstrip("\r\n") for l in open(os.path.join(ROOT, folder, folder + ".toc"), encoding="utf-8")]


def test_folder_tocs():
    main = toc_version("FantasyGlassUI")
    for key, folder in FOLDER_KEYS.items():
        lines = toc_lines(folder)
        meta = [l for l in lines if l.startswith("## ")]
        want = ["## Interface: 16001", "## Author: DustyMouse", f"## Version: {main}", "## LoadOnDemand: 1",
                "## RequiredDeps: FantasyGlassUI", "## Category: User Interface", "## X-License: All Rights Reserved",
                "## X-Curse-Project-ID: 1798626", "## IconTexture: Interface\\AddOns\\FantasyGlassUI\\Media\\icon.tga",
                "## OptionalDeps: Questie" if key == "planner" else "## OptionalDeps: Questie, FantasyGlassUI_Planner"]
        for w in want:
            assert w in meta, f"{folder}.toc lacks {w!r}"
        names = sorted(l.split(":")[0] for l in meta)
        assert names == sorted([w.split(":")[0] for w in want] + ["## Notes", "## Title"]), f"{folder}.toc: {names}"
        files = [l.strip() for l in lines if l.strip().endswith(".lua")]
        assert files == folder_files(key), f"{folder}.toc and ns.FOLDERS.{key}.files disagree"
        for f in files:
            assert os.path.isfile(os.path.join(ROOT, folder, f)), f"{folder}.toc lists a missing file {f}"
        on_disk = sorted(f for f in os.listdir(os.path.join(ROOT, folder)) if f.endswith(".lua"))
        assert on_disk == sorted(files), f"{folder}: files not in its TOC: {sorted(set(on_disk) - set(files))}"


def test_folder_titles_neutral():
    """Until 13.0 the add-on list names nothing: "extras 1" and "extras 2", with neutral notes (ruling 3)."""
    titles = {}
    for key, folder in FOLDER_KEYS.items():
        for line in toc_lines(folder):
            m = re.match(r"^## (Title|Notes):\s*(.*)$", line)
            if m:
                text = m.group(2).lower()
                for word in ("plan", "gold", "guide", "advis"):
                    assert word not in text, f"{folder}.toc's {m.group(1)} says {word!r}"
                if m.group(1) == "Title":
                    titles[key] = m.group(2)
    assert titles == {"planner": "|cff33ccffFantasy Glass|r UI - extras 1", "gold": "|cff33ccffFantasy Glass|r UI - extras 2"}, titles


def test_folder_files():
    for key, folder in FOLDER_KEYS.items():
        for f in folder_files(key):
            lines = open(os.path.join(ROOT, folder, f), encoding="utf-8").read().rstrip("\n").split("\n")
            assert lines[0] == "local ns = _G.FantasyGlassUI", f"{folder}/{f}: first line {lines[0]!r}"
            assert lines[1] == "if type(ns) ~= \"table\" then return end", f"{folder}/{f}: second line {lines[1]!r}"
            assert lines[-1] == f'ns.FolderFileDone("{key}", "{f}")', f"{folder}/{f}: last line {lines[-1]!r}"
            assert '"PLAYER_LOGIN"' not in "\n".join(lines), f"{folder}/{f} registers PLAYER_LOGIN (use ns.FolderLate)"
    main = os.listdir(os.path.join(ROOT, "FantasyGlassUI"))
    left = sorted(f for f in main if f.endswith(".lua") and f.startswith("Planner")
                  and f not in ("PlannerTravel.lua", "PlannerKills.lua", "PlannerRecorders.lua"))
    assert not left, f"planner files left in the main add-on: {left}"
    left = sorted(f for f in main if f.endswith(".lua") and f.startswith("Gold") and f != "GoldRecorders.lua")
    assert not left, f"gold files left in the main add-on: {left}"


def test_folder_seams_listed():
    """Folders.lua's seam list holds exactly the planner and gold names the main add-on uses but does not
    define, and each is defined in a folder file."""
    defs = lambda text: {a or b for a, b in re.findall(r"^\s*(?:function ns[.:](\w+)|ns\.(\w+)\s*=(?!=))", text, re.M)}
    main_dir, opt_dir = os.path.join(ROOT, "FantasyGlassUI"), os.path.join(ROOT, "FantasyGlassUI_Options")
    main_texts = {f: open(os.path.join(main_dir, f), encoding="utf-8").read() for f in os.listdir(main_dir) if f.endswith(".lua")}
    opt_texts = {f: open(os.path.join(opt_dir, f), encoding="utf-8").read() for f in os.listdir(opt_dir) if f.endswith(".lua")}
    defined_main = set().union(*(defs(t) for t in main_texts.values()))
    used = set()
    for t in list(main_texts.values()) + list(opt_texts.values()):
        used |= set(re.findall(r"ns[.:]((?:Planner|Gold)\w+)", t))
    want = used - defined_main
    block = re.search(r"^-- Folder seams \(what the main add-on calls in the folders\):\n(.*?)^-- end of folder seams$", folders_lua(), re.M | re.S)
    assert block, "Folders.lua has no folder seam list"
    listed = set(re.findall(r"^--\s+(\w+)\s*$", block.group(1), re.M))
    assert listed == want, f"not listed: {sorted(want - listed)}; listed but not used: {sorted(listed - want)}"
    defined_folders = set()
    for key, folder in FOLDER_KEYS.items():
        for f in folder_files(key):
            defined_folders |= defs(open(os.path.join(ROOT, folder, f), encoding="utf-8").read())
    sys.path.insert(0, TESTS)
    from folder_stubs import stub_names
    stubs = stub_names(folders_lua())
    assert {"PlannerStart", "PlannerOpen", "PlannerCatchUp", "GoldOpen", "GoldAuctionShow"} <= stubs, stubs
    # (a stand-in may come before its folder function: the planner window's PlannerOpen is group C's)
    assert not sorted(listed - defined_folders - stubs), f"listed but defined in no folder file: {sorted(listed - defined_folders - stubs)}"


# The planner's recorders (the folders plan's Task 4): moved to the main add-on, defined there only.
PLANNER_RECORDERS = ["PlannerCharRecord", "PlannerKillXP", "PlannerRecordQuestTime", "PlannerRecordSoloElite", "PlannerClassToken",
                     "PlannerRecordDeath", "PlannerMountSeen", "PlannerBestChoice", "PlannerGatherSkill", "PlannerRecordNode", "PlannerSeen",
                     "PlannerRecordTimed", "PlannerLevelTick", "PlannerRecordLevel", "PlannerLevelSummary", "PlannerLevelLines",
                     "PlannerLevelRunLines", "PlannerSeenSave", "PlannerDuoRegister", "PLANNER_CATCHUP_DAYS", "PLANNER_SEEN_CAP",
                     "PLANNER_QUEST_TIMES_CAP", "PLANNER_NODE_CAP", "PLANNER_TIMED_CAP", "PLANNER_DUO_PREFIX", "plannerSessionStart"]


def test_recorders_in_main():
    defs = lambda text: {a or b for a, b in re.findall(r"^\s*(?:function ns[.:](\w+)|ns\.(\w+)\s*=(?!=))", text, re.M)}
    main = open(os.path.join(ROOT, "FantasyGlassUI", "PlannerRecorders.lua"), encoding="utf-8").read()
    missing = sorted(set(PLANNER_RECORDERS) - defs(main))
    assert not missing, f"not defined in PlannerRecorders.lua: {missing}"
    for f in folder_files("planner"):
        text = open(os.path.join(ROOT, "FantasyGlassUI_Planner", f), encoding="utf-8").read()
        copied = sorted(set(PLANNER_RECORDERS) & defs(text))
        assert not copied, f"FantasyGlassUI_Planner/{f} defines a recorder of the main add-on's: {copied}"
    toc = [l.strip() for l in open(os.path.join(ROOT, "FantasyGlassUI", "FantasyGlassUI.toc"), encoding="utf-8")]
    assert toc.index("PlannerTravel.lua") < toc.index("PlannerRecorders.lua") < toc.index("PlannerKills.lua"), "PlannerRecorders.lua's place in the TOC"


def test_packaging():
    pkg = open(os.path.join(ROOT, ".pkgmeta"), encoding="utf-8").read()
    for folder in FOLDER_KEYS.values():
        assert re.search(r"^\s+FantasyGlassUI/%s: %s$" % (folder, folder), pkg, re.M), f".pkgmeta does not move {folder}"
    rel = open(os.path.join(ROOT, ".github", "workflows", "release.yml"), encoding="utf-8").read()
    loop = re.search(r"^\s*for f in (.*?); do$", rel, re.M)
    assert loop, "release.yml has no version loop"
    for folder in FOLDER_KEYS.values():
        assert f"{folder}/{folder}.toc" in loop.group(1).split(), f"release.yml's version loop does not check {folder}"


SEAMS = "36be49a"     # the folders plan's seams commit: the Guide tab before group C moved its planner switches


def test_planner_switches_moved():
    """The planner's switches left the Guide tab for the planner window (the folders plan, ruling 10): no
    ns.db.planner key is read on the Guide tab, and every planner key the tab had at SEAMS is in the window."""
    bars = open(os.path.join(ROOT, "FantasyGlassUI_Options", "Bars.lua"), encoding="utf-8").read()
    assert bars.count("ns.db.planner") == 0, "the Guide tab still reads a planner setting"
    old = subprocess.run(["git", "show", SEAMS + ":FantasyGlassUI_Options/Bars.lua"], cwd=ROOT, capture_output=True, text=True).stdout
    keys = set(re.findall(r"ns\.db\.(planner\w+)", old)) | set(re.findall(r'"(planner[A-Z]\w*)"', old))
    assert len(keys) >= 30, f"the Guide tab at {SEAMS} read only {sorted(keys)}"
    window = open(os.path.join(ROOT, "FantasyGlassUI_Planner", "PlannerWindow.lua"), encoding="utf-8").read()
    missing = sorted(k for k in keys if not re.search(r"\b%s\b" % k, window))
    assert not missing, f"not in PlannerWindow.lua: {missing}"

def test_readme_current():
    """The README that ships in the add-on folder: this version, and every command /fgui help lists."""
    readme = open(os.path.join(ROOT, "FantasyGlassUI", "README.md"), encoding="utf-8").read()
    main = toc_version("FantasyGlassUI")
    assert f"Version {main}" in readme, f"FantasyGlassUI/README.md should say Version {main}"
    core = open(os.path.join(ROOT, "FantasyGlassUI", "Core.lua"), encoding="utf-8").read()
    block = core[core.index("ns.helpLines = {"):core.index("ns.toolCommands = {")]
    section = readme[readme.index("## Commands"):readme.index("## Features")]
    missing = [c for c in re.findall(r'\{ "(/fgui [a-z]+)', block) if c not in section]
    assert not missing, "README.md's Commands table lacks: " + ", ".join(sorted(set(missing)))


def test_harness():
    out = run("smoke.py", os.path.join(ROOT, "FantasyGlassUI"), 900)
    lines = out.splitlines()
    assert any(l.startswith("syntax: all") for l in lines), "a file does not load:\n" + out[-3000:]
    errors = [l for l in lines if l.startswith("errors:")]
    passed = [l for l in errors if l.strip() == "errors: no errors"]
    assert len(passed) == 2, "in one or both modes (combat values readable / hidden):\n" + "\n".join(errors or [out[-3000:]])


def test_hidden_values():
    out = run("secretaudit.py", ROOT, 1500)
    first = out.splitlines()[0] if out else ""
    assert "; 0 lines compared a hidden value" in first, out[-4000:]


def test_combat_locks():
    out = run("lockaudit.py", ROOT, 900)
    blocked = [l for l in out.splitlines() if re.match(r"^ +[0-9]+  [A-Za-z_/]+\.lua:[0-9]+", l)]
    assert out.strip(), "the combat audit printed nothing"
    assert not blocked, "the add-on would be blocked here:\n" + "\n".join(blocked)


def test_forever_api():
    """Only what the WoW: Forever client offers: see tests/forever_audit.py."""
    p = subprocess.run([sys.executable, os.path.join(TESTS, "forever_audit.py")], cwd=ROOT, capture_output=True, text=True, timeout=300)
    assert p.returncode == 0, p.stdout + p.stderr


def test_plan_page_hidden():
    """The plan page is built only with --plan, and a plain build knows nothing of it (tests/sitecheck.py)."""
    p = subprocess.run([sys.executable, os.path.join(TESTS, "sitecheck.py")], cwd=ROOT, capture_output=True, text=True, timeout=600)
    assert p.returncode == 0, p.stdout + p.stderr


def test_plan_reader():
    """The website's plan reader reads every code in tests/plan_codes.txt as the add-on's reader does."""
    p = subprocess.run(["node", os.path.join(TESTS, "plan_reader_check.js")], cwd=ROOT, capture_output=True, text=True, timeout=120)
    assert p.returncode == 0, p.stdout + p.stderr


def test_guide_seams_listed():
    """Every ns.Guide* and ns.GUIDE_* a Planner*.lua or Gold*.lua file uses is in Guide.lua's seam list, every name
    there is defined in Guide.lua, and no planner or gold file wraps, assigns or defines a ns.Guide* function: they
    use the guide's registries instead."""
    folder = os.path.join(ROOT, "FantasyGlassUI")
    guide = open(os.path.join(folder, "Guide.lua"), encoding="utf-8").read()
    block = re.search(r"^-- Seams \(what the planner uses of the guide\):\n(.*?)^-- end of seams$", guide, re.M | re.S)
    assert block, "Guide.lua has no seam list"
    listed = set(re.findall(r"^--\s+(\w+)\s*$", block.group(1), re.M))
    used, wrappers, assigned, scanned = set(), [], [], []
    paths = [os.path.join(d, n) for d in (folder, os.path.join(ROOT, "FantasyGlassUI_Planner"), os.path.join(ROOT, "FantasyGlassUI_Gold"))
             if os.path.isdir(d) for n in sorted(os.listdir(d))]
    for path in paths:
        name = os.path.basename(path)
        if not (name.startswith(("Planner", "Gold")) and name.endswith(".lua")):
            continue
        scanned.append(name)
        text = open(path, encoding="utf-8").read()
        used |= set(re.findall(r"ns[.:](Guide\w+)", text)) | set(re.findall(r"ns\.(GUIDE_\w+)", text))
        wrappers += [f"{name}:{i}" for i, line in enumerate(text.splitlines(), 1) if "local original = ns[" in line]
        for i, line in enumerate(text.splitlines(), 1):
            if re.search(r"\bfunction ns[.:]Guide\w+", line) or re.search(r"\bns\.Guide\w+\s*=(?!=)", line):
                assigned.append(f"{name}:{i}: {line.strip()}")
    assert "Gold.lua" in scanned and "PlannerPath.lua" in scanned, scanned
    missing = sorted(used - listed)
    assert not missing, f"used by the planner but not in the seam list: {missing}"
    undefined = sorted(n for n in listed if not re.search(r"^(?:function ns[.:]%s\b|ns\.%s\s*=)" % (n, n), guide, re.M))
    assert not undefined, f"in the seam list but not defined in Guide.lua: {undefined}"
    assert not wrappers, f"a planner file wraps a guide function: {wrappers}"
    assert not assigned, f"a planner or gold file sets a guide function (only Guide.lua defines them): {assigned}"


def test_gold_recorders_in_main():
    """Gold's recorders (merchant prices, loot, gathering, recipes, the node fold and the job runner) are the main
    add-on's GoldRecorders.lua, moved there, not copied: no gold folder file defines them again (the folders plan, Task 5)."""
    names = ["GoldJob", "GoldYield", "GoldRunSlice", "GoldBusy", "GoldInFight", "GoldTickOn", "GoldItemValue", "GoldVendorNote",
             "GoldVendorBuy", "GoldMobNote", "GoldGatherSent", "GoldFoldNodes", "GoldRecipesRead"]
    defs = lambda text: {a or b for a, b in re.findall(r"^\s*(?:function ns[.:](\w+)|ns\.(\w+)\s*=(?!=))", text, re.M)}
    main = open(os.path.join(ROOT, "FantasyGlassUI", "GoldRecorders.lua"), encoding="utf-8").read()
    missing = sorted(set(names + ["GOLD_BUDGET_MS"]) - defs(main))
    assert not missing, f"not defined in GoldRecorders.lua: {missing}"
    events = ["PLAYER_REGEN_DISABLED", "MERCHANT_SHOW", "MERCHANT_UPDATE", "LOOT_OPENED", "LOOT_CLOSED", "UNIT_SPELLCAST_SUCCEEDED",
              "PLAYER_ENTERING_WORLD", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE"]
    for ev in events:
        assert f'"{ev}"' in main, f"GoldRecorders.lua does not listen for {ev}"
    for f in folder_files("gold"):
        text = open(os.path.join(ROOT, FOLDER_KEYS["gold"], f), encoding="utf-8").read()
        again = sorted(set(names + ["GOLD_BUDGET_MS"]) & defs(text))
        assert not again, f"{FOLDER_KEYS['gold']}/{f} defines {again} too"
        heard = [ev for ev in events + ["PLAYER_REGEN_ENABLED"] if f'"{ev}"' in text]
        assert not heard, f"{FOLDER_KEYS['gold']}/{f} still listens for {heard}"
