"""Folders.lua's stand-in names (its `local FOLDER_STUBS = { key = { "Name", ... }, ... }` table), read the one way
both tests/forever_audit.py and tests/test_addon.py need them."""
import re


def stub_names(folders_lua_text):
    """The quoted names in Folders.lua's FOLDER_STUBS table; an error when the table is not there."""
    m = re.search(r"^local FOLDER_STUBS = \{\n(.*?)^\}", folders_lua_text, re.M | re.S)
    if not m:
        raise ValueError("Folders.lua has no `local FOLDER_STUBS = {` table")
    names = set(re.findall(r'"(\w+)"', m.group(1)))
    if not names:
        raise ValueError("Folders.lua's FOLDER_STUBS table names nothing")
    return names
