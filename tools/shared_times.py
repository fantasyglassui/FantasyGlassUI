#!/usr/bin/env python3
"""Turn a folder of Share my times codes into the planner's shared averages (for the maintainer).

    python3 tools/shared_times.py <folder> [-o FantasyGlassUI_Planner/PlannerSharedTimes.lua]

Every file in the folder is read and each FGT1! code in it is found (text around the codes is fine: a pasted
message, an email). A code sent twice counts once. Each code gives at most one vote per quest, level, flight
and crossing (its own times for that one, averaged), so one player who sends a long list cannot outweigh the
rest. Times outside sensible bounds are not votes. An average needs 3 votes, and drops the votes far from
their middle (under half or over twice the median). Levels are kept per class; the rest ignore the class.

The codes hold no names (the add-on keeps none); this script keeps only the kind, the quest, level, flight or
crossing, the seconds and, for a level, the class token. Anything else in a code is ignored.
"""
import argparse
import datetime
import os
import re
import sys

HEADER = "FGT1!"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_OUT = os.path.join(ROOT, "FantasyGlassUI_Planner", "PlannerSharedTimes.lua")

# The data file's tables, by the kind of time an entry is.
TABLE_OF = {"quest": "quests", "level": "levels", "flight": "flights", "boat": "crossings"}
# What counts as a vote, in seconds (the add-on's own limits: a quest over 2 hours is away, a crossing
# over 15 minutes is not one).
BOUNDS = {"quest": (10, 7200), "level": (30, 172800), "flight": (10, 1800), "boat": (60, 900)}
KEY_TEXT = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")        # a flight "12-34", a crossing "menethil-theramore"
CLASS_TEXT = re.compile(r"^[A-Z]{2,20}$")
MIN_VOTES = 3


class Damaged(Exception):
    pass


def _value(s, i, depth):
    """The share encoding (Profiles.lua): T, F, N<number>;, S<len>:<text>, { key value ... }."""
    if depth > 20:
        raise Damaged("too deep")
    c = s[i:i + 1]
    if c == "T":
        return True, i + 1
    if c == "F":
        return False, i + 1
    if c == "N":
        j = s.find(";", i)
        if j < 0:
            raise Damaged("bad number")
        try:
            n = float(s[i + 1:j])
        except ValueError:
            raise Damaged("bad number")
        if n != n or n in (float("inf"), float("-inf")):
            raise Damaged("bad number")
        return (int(n) if n == int(n) else n), j + 1
    if c == "S":
        j = s.find(":", i)
        if j < 0 or not s[i + 1:j].isdigit():
            raise Damaged("bad text")
        n = int(s[i + 1:j])
        if n > 4096:
            raise Damaged("bad text")
        raw = s[j + 1:j + 1 + n].encode("utf-8")[:n]           # (the length is in bytes, as Lua counts)
        if len(raw) != n:
            raise Damaged("text cut short")
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            raise Damaged("bad text")
        return text, j + 1 + len(text)
    if c == "{":
        t, i = {}, i + 1
        while s[i:i + 1] != "}":
            if i >= len(s):
                raise Damaged("unfinished")
            k, i = _value(s, i, depth + 1)
            v, i = _value(s, i, depth + 1)
            if isinstance(k, bool) or not isinstance(k, (str, int, float)):
                raise Damaged("bad key")
            t[k] = v
        return t, i + 1
    raise Damaged("unexpected character")


def decode_at(text, start):
    """The value of the code whose header begins at `start`, and where it ends; raises Damaged."""
    value, stop = _value(text, start + len(HEADER), 0)
    if not isinstance(value, dict) or not isinstance(value.get("e"), dict):
        raise Damaged("not a times code")
    return value, stop


def decode(code):
    """A code (with or without its header) as a dict, or None when it is damaged."""
    if not isinstance(code, str):
        return None
    if not code.startswith(HEADER):
        code = HEADER + code
    try:
        return decode_at(code, 0)[0]
    except (Damaged, IndexError, RecursionError):
        return None


def _entry(e):
    """(kind, key, class or None, seconds) of one entry, or None when it is not a time this script keeps."""
    if not isinstance(e, dict):
        return None
    kind, key, secs, cls = e.get(1), e.get(2), e.get(3), e.get(4)
    if kind not in TABLE_OF or isinstance(secs, bool) or not isinstance(secs, (int, float)):
        return None
    low, high = BOUNDS[kind]
    if not (low <= secs <= high):
        return None
    if kind in ("quest", "level"):
        if isinstance(key, bool) or not isinstance(key, int) or key < 1:
            return None
    elif not (isinstance(key, str) and len(key) <= 40 and KEY_TEXT.match(key)):
        return None
    if kind == "level":
        if not (isinstance(cls, str) and CLASS_TEXT.match(cls)) or key > 100:
            return None
        return kind, key, cls, secs
    return kind, key, None, secs


def votes(codes):
    """{ (kind, key, class or None): [seconds, ...] }: one vote a code (the average of its own times for it)."""
    out = {}
    for c in codes:
        d = decode(c) if isinstance(c, str) else c
        if not isinstance(d, dict) or not isinstance(d.get("e"), dict):
            continue
        mine = {}
        for e in d["e"].values():
            got = _entry(e)
            if got:
                mine.setdefault(got[:3], []).append(got[3])
        for k, v in mine.items():
            out.setdefault(k, []).append(sum(v) / len(v))
    return out


def average(values, kind):
    """The average of the votes, with those under half or over twice their median dropped; None under 3 votes."""
    low, high = BOUNDS.get(kind, (0, float("inf")))
    vals = sorted(v for v in values if low <= v <= high)
    if len(vals) < MIN_VOTES:
        return None
    n = len(vals)
    median = vals[n // 2] if n % 2 else (vals[n // 2 - 1] + vals[n // 2]) / 2
    kept = [v for v in vals if median / 2 <= v <= median * 2]
    if len(kept) < MIN_VOTES:
        return None
    return int(sum(kept) / len(kept) + 0.5)


def tables(vote_map):
    """The data file's four tables from the votes."""
    t = {"quests": {}, "levels": {}, "flights": {}, "crossings": {}}
    for (kind, key, cls), vals in vote_map.items():
        avg = average(vals, kind)
        if avg is None:
            continue
        if kind == "level":
            t["levels"].setdefault(cls, {})[key] = avg
        else:
            t[TABLE_OF[kind]][key] = avg
    return t


def _lua_key(k):
    if isinstance(k, int):
        return "[%d]" % k
    return '["%s"]' % k.replace("\\", "\\\\").replace('"', '\\"')


def _sorted_keys(d):
    return sorted(d, key=lambda k: (isinstance(k, str), k))


def lua(t, made, count):
    """The text of PlannerSharedTimes.lua."""
    head = ('local ns = _G.FantasyGlassUI\n'
            'if type(ns) ~= "table" then return end\n'
            '\n'
            '------------------------------------------------------------------------------------------\n'
            '-- 13.5: the averages of the times players shared (Share my times), made by the maintainer\'s script in tools/.\n'
            '-- Empty until codes come in. (Read through ns.PlannerSharedTime, PlannerShare.lua.)\n'
            '------------------------------------------------------------------------------------------\n')
    foot = 'ns.FolderFileDone("planner", "PlannerSharedTimes.lua")\n'
    names = ("quests", "levels", "flights", "crossings")
    start = 'ns.PLANNER_SHARED_TIMES = { made = "%s", codes = %d' % (made, count)
    if not any(t.get(n) for n in names):
        return head + start + ", " + ", ".join("%s = {}" % n for n in names) + " }\n" + foot
    lines = [start + ","]
    for n in names:
        d = t.get(n) or {}
        if not d:
            lines.append("    %s = {}," % n)
            continue
        lines.append("    %s = {" % n)
        for k in _sorted_keys(d):
            v = d[k]
            if isinstance(v, dict):
                inner = ", ".join("%s = %d" % (_lua_key(x), v[x]) for x in _sorted_keys(v))
                lines.append("        %s = { %s }," % (_lua_key(k), inner))
            else:
                lines.append("        %s = %d," % (_lua_key(k), v))
        lines.append("    },")
    lines.append("}")
    return head + "\n".join(lines) + "\n" + foot


def read_codes(folder, err=None):
    """Every distinct code in the folder's files, in the order found. A damaged one is skipped and said."""
    err = err or sys.stderr
    found, seen = [], set()
    for name in sorted(os.listdir(folder)):
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            continue
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read()
        at = text.find(HEADER)
        while at >= 0:
            try:
                _, stop = decode_at(text, at)
            except (Damaged, IndexError, RecursionError):
                print("skipped %s: a damaged code" % name, file=err)
                at = text.find(HEADER, at + len(HEADER))
                continue
            c = text[at:stop]
            if c not in seen:
                seen.add(c)
                found.append(c)
            at = text.find(HEADER, stop)
    return found


def today():
    return datetime.date.today().isoformat()


def main(argv=None):
    p = argparse.ArgumentParser(description="Turn a folder of Share my times codes into PlannerSharedTimes.lua.")
    p.add_argument("folder")
    p.add_argument("-o", "--out", default=DEFAULT_OUT)
    a = p.parse_args(argv)
    codes = read_codes(a.folder)
    text = lua(tables(votes(codes)), today(), len(codes))
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("%d codes -> %s" % (len(codes), a.out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
