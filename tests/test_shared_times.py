"""tools/shared_times.py: the maintainer's script that turns a folder of Share my times codes (13.5, the planner
window) into FantasyGlassUI_Planner/PlannerSharedTimes.lua, as averages with outliers dropped."""
import importlib.util
import os

from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("shared_times", os.path.join(ROOT, "tools", "shared_times.py"))
st = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(st)

# The code of three entries, as the add-on makes it (tests/smoke.py, "13.5 H: the code", holds the same literal).
GOLDEN = ("FGT1!{S1:cS4:MAGES1:e{N1;{N1;S5:questN2;N901;N3;N600;N4;S4:MAGEN5;S5:Horde}N2;{N1;S5:levelN2;N20;N3;N3600;N4;"
          "S4:MAGEN5;S5:Horde}N3;{N1;S6:flightN2;S5:12-34N3;N95;N4;S4:MAGEN5;S5:Horde}}S1:fS5:HordeS1:vS6:13.5.0}")


def enc(v):
    """The add-on's share encoding (Profiles.lua), for making test codes."""
    if v is True:
        return "T"
    if v is False:
        return "F"
    if isinstance(v, (int, float)):
        return "N%s;" % ("%.10g" % v)
    if isinstance(v, str):
        return "S%d:%s" % (len(v.encode("utf-8")), v)
    keys = sorted(v, key=str)
    return "{" + "".join(enc(k) + enc(v[k]) for k in keys) + "}"


def code(entries, cls="MAGE", faction="Horde", version="13.5.0"):
    e = {i + 1: {1: k, 2: key, 3: s, 4: c, 5: faction} for i, (k, key, s, c) in enumerate(entries)}
    return "FGT1!" + enc({"v": version, "c": cls, "f": faction, "e": e})


def tables_of(codes):
    return st.tables(st.votes(codes))


def test_encoder_matches_golden():
    assert code([("quest", 901, 600, "MAGE"), ("level", 20, 3600, "MAGE"), ("flight", "12-34", 95, "MAGE")]) == GOLDEN


def test_decode_golden():
    assert st.decode(GOLDEN) == {"v": "13.5.0", "c": "MAGE", "f": "Horde", "e": {
        1: {1: "quest", 2: 901, 3: 600, 4: "MAGE", 5: "Horde"},
        2: {1: "level", 2: 20, 3: 3600, 4: "MAGE", 5: "Horde"},
        3: {1: "flight", 2: "12-34", 3: 95, 4: "MAGE", 5: "Horde"}}}
    assert st.decode("FGT1!{S9:abc") is None
    assert st.decode("not a code") is None


def test_outliers_dropped():
    assert st.average([100, 102, 104, 106, 1000], "quest") == 103


def test_needs_three_votes():
    two = [code([("quest", 901, 600, "MAGE")]), code([("quest", 901, 610, "WARRIOR")])]
    assert 901 not in tables_of(two)["quests"]
    assert st.average([600, 610], "quest") is None


def test_one_vote_per_code():
    many = code([("quest", 901, 600, "MAGE")] * 50)
    codes = [many, code([("quest", 901, 610, "MAGE")]), code([("quest", 901, 620, "MAGE")])]
    v = st.votes(codes)
    assert len(v[("quest", 901, None)]) == 3
    assert tables_of(codes)["quests"][901] == 610


def test_identical_codes_once(tmp_path):
    one = code([("quest", 901, 600, "MAGE")])
    for i in range(3):
        (tmp_path / ("c%d.txt" % i)).write_text("here it is: " + one + "\nthanks", encoding="utf-8")
    assert st.read_codes(str(tmp_path)) == [one]
    out = tmp_path / "out.lua"
    assert st.main([str(tmp_path), "-o", str(out)]) == 0
    assert run_lua(str(out)).eval("FantasyGlassUI.PLANNER_SHARED_TIMES.codes") == 1


def test_bounds():
    codes = [code([("flight", "12-34", 5000, "MAGE"), ("quest", 902, 5, "MAGE")]) for _ in range(3)]
    v = st.votes(codes)
    assert ("flight", "12-34", None) not in v and ("quest", 902, None) not in v


def test_levels_by_class():
    codes = [code([("level", 20, 3600 + i, "MAGE")], cls="MAGE") for i in range(3)]
    codes += [code([("level", 20, 7200 + i, "WARRIOR")], cls="WARRIOR") for i in range(3)]
    t = tables_of(codes)
    assert t["levels"]["MAGE"][20] == 3601 and t["levels"]["WARRIOR"][20] == 7201


def test_names_never_kept():
    """A code made by hand with a name in it: the name is not a vote and never reaches the data file."""
    codes = [code([("flight", "Someone of Realm", 95, "MAGE"), ("quest", "Someone", 600, "Someone")]) for _ in range(3)]
    text = st.lua(tables_of(codes), "2026-11-27", 3)
    assert "Someone" not in text and "Realm" not in text


def test_damaged_code_skipped(tmp_path, capsys):
    (tmp_path / "bad.txt").write_text("FGT1!{S9:abc", encoding="utf-8")
    for i in range(3):
        (tmp_path / ("good%d.txt" % i)).write_text(code([("quest", 901, 600 + i, "MAGE")]), encoding="utf-8")
    out = tmp_path / "out.lua"
    assert st.main([str(tmp_path), "-o", str(out)]) == 0
    err = capsys.readouterr().err
    assert "skipped bad.txt: a damaged code" in err
    assert "[901] = 601" in out.read_text(encoding="utf-8")


def run_lua(path):
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("FantasyGlassUI = { done = {} }; function FantasyGlassUI.FolderFileDone(a, b) FantasyGlassUI.done[#FantasyGlassUI.done + 1] = a .. '/' .. b end")
    lua.execute(open(path, encoding="utf-8").read())
    return lua


def test_writes_lua(tmp_path):
    folder = tmp_path / "codes"
    folder.mkdir()
    for i in range(3):
        (folder / ("p%d.txt" % i)).write_text(code([("quest", 901, 600, "MAGE"), ("level", 20, 3600, "MAGE"),
                                                    ("flight", "12-34", 95 + i, "MAGE"), ("boat", "menethil-theramore", 200, "MAGE")],
                                                   version="13.5.%d" % i), encoding="utf-8")
    out = tmp_path / "PlannerSharedTimes.lua"
    assert st.main([str(folder), "-o", str(out)]) == 0
    lua = run_lua(str(out))
    t = lua.eval("FantasyGlassUI.PLANNER_SHARED_TIMES")
    assert t.quests[901] == 600 and t.codes == 3 and t.levels["MAGE"][20] == 3600
    assert t.flights["12-34"] == 96 and t.crossings["menethil-theramore"] == 200
    assert lua.eval("FantasyGlassUI.done[1]") == "planner/PlannerSharedTimes.lua" and lua.eval("#FantasyGlassUI.done") == 1


def test_empty_folder_as_shipped(tmp_path):
    """No codes: the same file Task 1 made, apart from the day."""
    out = tmp_path / "out.lua"
    assert st.main([str(tmp_path), "-o", str(out)]) == 0
    shipped = open(os.path.join(ROOT, "FantasyGlassUI_Planner", "PlannerSharedTimes.lua"), encoding="utf-8").read()
    made = out.read_text(encoding="utf-8")
    assert made.replace('made = "%s"' % st.today(), 'made = ""') == shipped
