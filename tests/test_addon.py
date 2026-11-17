"""The add-on's checks, run on every push and pull request (see .github/workflows/Testing.yml).

These are the same checks run before each build:
  * the test harness: the add-on loads in a stand-in for the game and every part is exercised, once
    with combat values readable and once with them hidden as the game does in a fight;
  * the hidden-value audit: no value the game hides in combat is ever compared;
  * the combat audit: nothing the game locks in a fight is shown, hidden, moved or resized then;
  * the version numbers of the three folders agree.
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
