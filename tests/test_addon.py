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
    """Every ns.Guide* and ns.GUIDE_* a Planner*.lua file uses is in Guide.lua's seam list, every name there is
    defined in Guide.lua, and no planner file wraps a ns.Guide* function any more."""
    folder = os.path.join(ROOT, "FantasyGlassUI")
    guide = open(os.path.join(folder, "Guide.lua"), encoding="utf-8").read()
    block = re.search(r"^-- Seams \(what the planner uses of the guide\):\n(.*?)^-- end of seams$", guide, re.M | re.S)
    assert block, "Guide.lua has no seam list"
    listed = set(re.findall(r"^--\s+(\w+)\s*$", block.group(1), re.M))
    used, wrappers = set(), []
    for name in sorted(os.listdir(folder)):
        if not (name.startswith("Planner") and name.endswith(".lua")):
            continue
        text = open(os.path.join(folder, name), encoding="utf-8").read()
        used |= set(re.findall(r"ns[.:](Guide\w+)", text)) | set(re.findall(r"ns\.(GUIDE_\w+)", text))
        wrappers += [f"{name}:{i}" for i, line in enumerate(text.splitlines(), 1) if "local original = ns[" in line]
    missing = sorted(used - listed)
    assert not missing, f"used by the planner but not in the seam list: {missing}"
    undefined = sorted(n for n in listed if not re.search(r"^(?:function ns[.:]%s\b|ns\.%s\s*=)" % (n, n), guide, re.M))
    assert not undefined, f"in the seam list but not defined in Guide.lua: {undefined}"
    assert not wrappers, f"a planner file wraps a guide function: {wrappers}"
