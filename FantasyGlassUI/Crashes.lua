local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: crash reports, kept only while Keep crash reports (Accessibility, Help and problems) is on,
-- and /fgui crashes.
--
-- Nothing here is ever sent: the reports stay in the saved file on the player's own computer, and
-- leave it only as a code the player copies and shares themselves. Each report is scrubbed before it
-- is kept: your characters', realms' and guild's names in every form the game writes, the names of your group,
-- duo partner and friends, any other "Name-Realm", Player- and Pet- GUIDs, and paths outside the AddOns folder.
-- That is wherever the add-on can find a name, not every name a message could hold: the report says so. While
-- the switch is off nothing is kept at all.
--
-- What is caught: every line that reaches ns.errors (a metatable on it sees each append, from every
-- file), and every error ns:Guard and ns:Safe catch (Skin.lua), also after their first one, so the
-- count is true. No seterrorhandler: other add-ons' errors are not ours, and replacing the game's
-- handler can taint. Keeping a report can never raise an error itself: a failure in here is swallowed.
------------------------------------------------------------------------------------------
local find, sub, gsub, format = string.find, string.sub, string.gsub, string.format

ns.CRASH_MAX = 30                 -- distinct reports kept; the one first seen longest ago goes first
ns.CRASH_STACK_LINES = 4          -- the top lines of where it happened
ns.CRASH_TEXT_MAX = 300           -- bytes of each message and stack line
ns.CRASH_CODE_HEADER = "FGC1!"

function ns.CrashOn()
    return ns.db ~= nil and ns.db.crashReports == true
end

local function Plain(v)                                      -- a readable string, or nil (a hidden value is never used)
    if v == nil or ns:IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

-- Every name to take out, as { text, as } (plain strings of 2 bytes or more, longest first, so "Mal'Ganis" goes
-- before a character called "Mal"):
--   * your characters' names and realms (the saved character list's keys, "Name - Realm", and who is playing now),
--     each realm also as the game writes it in "Name-Realm" (no spaces; no spaces or apostrophes; GetNormalizedRealmName);
--   * your guild now, and the guilds already saved with your characters' guild banks (GetGuildInfo is often nil at login);
--   * the people in your group, your duo partner and your friends list (other players' names in plain text).
function ns.CrashNames()
    local out, seen = {}, {}
    local function add(text, as)
        text = Plain(text)
        if not text or #text < 2 then return end
        local key = text:lower()
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = { text, as }
    end
    local function realm(text)
        text = Plain(text)
        if not text then return end
        add(text, "<realm>")
        add((gsub(text, " ", "")), "<realm>")
        add((gsub(text, "[ ']", "")), "<realm>")
    end
    local function person(text, theirRealm)                    -- "Name" or "Name-Realm"
        text = Plain(text)
        if not text then return end
        local at = find(text, "-", 1, true)
        if at then add(sub(text, 1, at - 1), "<name>"); realm(sub(text, at + 1)) else add(text, "<name>") end
        realm(theirRealm)
    end
    local function call(fn, ...)
        if type(fn) ~= "function" then return nil end
        local ok, a, b = pcall(fn, ...)
        if not ok then return nil end
        return a, b
    end
    local root = ns.root
    local chars = type(root) == "table" and root.chars
    if type(chars) == "table" then
        for key in pairs(chars) do
            if type(key) == "string" then
                local at = find(key, " - ", 1, true)
                if at then add(sub(key, 1, at - 1), "<name>"); realm(sub(key, at + 3)) else add(key, "<name>") end
            end
        end
    end
    add((call(UnitName, "player")), "<name>")
    realm((call(GetRealmName)))
    realm((call(_G.GetNormalizedRealmName)))
    add((call(GetGuildInfo, "player")), "<guild>")
    local inv = type(root) == "table" and root.inventory
    if type(inv) == "table" and type(inv.guilds) == "table" then
        for key in pairs(inv.guilds) do
            if type(key) == "string" then
                local at = find(key, " - ", 1, true)
                add(at and sub(key, 1, at - 1) or key, "<guild>")
            end
        end
    end
    -- the group
    local n = call(GetNumGroupMembers)
    if type(n) == "number" and not ns:IsSecret(n) and n > 0 then
        local raid = ns.Yes((call(IsInRaid)))
        for i = 1, raid and math.min(n, 40) or math.min(n, 5) - 1 do
            person(call(UnitName, (raid and "raid" or "party") .. i))
        end
    end
    -- the duo partner and the friends list
    if type(ns.PlannerDuoPartner) == "function" then person((call(ns.PlannerDuoPartner))) end
    local F = _G.C_FriendList
    if type(F) == "table" and not ns:IsSecret(F) then
        local count = call(F.GetNumFriends)
        if type(count) == "number" and not ns:IsSecret(count) then
            for i = 1, math.min(count, 100) do
                local info = call(F.GetFriendInfoByIndex, i)
                if type(info) == "table" and not ns:IsSecret(info) then person(info.name) end
            end
        end
    end
    table.sort(out, function(a, b) if #a[1] ~= #b[1] then return #a[1] > #b[1] end return a[1] < b[1] end)
    return out
end

-- The realms the game can report, for "Name-Realm": yours (every form) and those of the realms joined to yours
-- (C_AutoComplete.GetAutoCompleteRealms). Lower case, longest first; `listed` is false when the game gave no list.
local function Realms(names)
    local out, seen, listed = {}, {}, false
    local function add(r)
        r = Plain(r)
        if r and #r >= 2 and not seen[r:lower()] then seen[r:lower()] = true; out[#out + 1] = r:lower() end
    end
    for _, e in ipairs(names) do if e[2] == "<realm>" then add(e[1]) end end
    local A = _G.C_AutoComplete
    local fn = type(A) == "table" and not ns:IsSecret(A) and A.GetAutoCompleteRealms or nil
    if type(fn) == "function" then
        local ok, list = pcall(fn)
        if ok and type(list) == "table" and not ns:IsSecret(list) then
            for _, r in ipairs(list) do
                if Plain(r) then listed = true; add(r); add((gsub(r, " ", ""))); add((gsub(r, "[ ']", ""))) end
            end
        end
    end
    table.sort(out, function(a, b) if #a ~= #b then return #a > #b end return a < b end)
    return out, listed
end

-- A byte that is part of a word (letters, digits, and every byte of a non-ASCII letter).
local function WordByte(b)
    return b ~= nil and ((b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b >= 128)
end

-- Each plain occurrence of `text` becomes `as` (no pattern is ever made from a name): in its own letter case
-- anywhere (so "Alt" goes from "Altitude" too, erring toward privacy), and in any other letter case where it
-- is a whole word ("mychar's bags", "MYCHAR"). Only ASCII changes case, so the lower-case copy keeps every offset.
local function ReplacePlain(s, text, as)
    local low, want = s:lower(), text:lower()
    local at = find(low, want, 1, true)
    if not at then return s end
    local parts, from = {}, 1
    while at do
        local stop = at + #text - 1
        local scan = at + 1
        if sub(s, at, stop) == text or (not WordByte(s:byte(at - 1)) and not WordByte(s:byte(stop + 1))) then
            parts[#parts + 1] = sub(s, from, at - 1)
            parts[#parts + 1] = as
            from = stop + 1
            scan = from
        end
        at = find(low, want, scan, true)
    end
    parts[#parts + 1] = sub(s, from)
    return table.concat(parts)
end

-- "Word-Realm" where Realm is a realm the game can report (any letter case) and Word a capitalised name:
-- <name>-<realm>. Found with plain finds; the word before the hyphen is checked byte by byte.
local function NameLike(w)
    if #w < 2 then return false end
    local b = w:byte(1)
    if not (b >= 65 and b <= 90) then return false end
    for i = 2, #w do
        local c = w:byte(i)
        if not ((c >= 97 and c <= 122) or c >= 128) then return false end
    end
    return true
end
local function OtherNames(s, realms)
    for _, r in ipairs(realms) do
        local from = 1
        while true do
            local low = s:lower()
            local at = find(low, "-" .. r, from, true)
            if not at then break end
            local ws = at
            while ws > 1 and WordByte(s:byte(ws - 1)) do ws = ws - 1 end
            local after = at + 1 + #r
            if NameLike(sub(s, ws, at - 1)) and not WordByte(s:byte(after)) and s:byte(ws - 1) ~= 95 then
                s = sub(s, 1, ws - 1) .. "<name>-<realm>" .. sub(s, after)
                from = ws + 14
            else
                from = at + 1
            end
        end
    end
    return s
end
-- With no list of realms from the game: any capitalised Word-Word, but a file (Skin-Old.lua), and the add-on's
-- and the game's own words (Player-?, Blizzard-..., the add-ons it knows).
local KNOWN = { blizzard = true, player = true, pet = true, creature = true, vehicle = true, gameobject = true, item = true,
                interface = true, addons = true, fantasyglassui = true, questie = true, tomtom = true, auctionator = true,
                unit = true, spell = true, quest = true, achievement = true, frame = true, beta = true }
local function AnyNames(s)
    return (gsub(s, "%f[%w_\128-\255](%u[%l\128-\255]+)%-(%u[%w'\128-\255]+)()", function(a, b, pos)
        if KNOWN[a:lower()] or KNOWN[b:lower()] then return nil end
        if find(s, "^%.%a", pos) then return nil end                            -- (a file name)
        return "<name>-<realm>"
    end))
end

-- At most `most` bytes, never ending in half a character.
local function Cut(s, most)
    if #s <= most then return s end
    s = sub(s, 1, most)
    local i = most
    while i > 1 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end    -- back to the last character's first byte
    local lead = s:byte(i)
    local size = (lead >= 0xF0 and 4) or (lead >= 0xE0 and 3) or (lead >= 0xC0 and 2) or 1
    if i + size - 1 > most then s = sub(s, 1, i - 1) end
    return s
end

-- The scrub, in order: links, then colour and texture codes, then paths (up to and including AddOns\
-- or AddOns/ goes, \ becomes /, a WTF\Account\ path or any other path is <path>), then GUIDs, then names
-- (yours and the ones the add-on knows, then any other "Name-Realm"); then the length. The add-on cannot know
-- every name in every message: the report says so, and asks the player to look it over.
local START = "[%s\"'<%(%[@=]"                                -- (what can stand just before a path)
function ns.CrashScrub(text, names)
    if ns:IsSecret(text) then return "<hidden>" end
    local s = tostring(text)
    s = gsub(s, "|H.-|h.-|h", "<link>")
    s = gsub(s, "|c%x%x%x%x%x%x%x%x", "")
    s = gsub(s, "|r", "")
    s = gsub(s, "|T.-|t", "")
    s = gsub(s, "|A.-|a", "")
    s = " " .. s                                             -- (so a path at the very start has something before it)
    s = gsub(s, "(" .. START .. ")%a:[\\/][^\n:\"'<>|]-[\\/][Aa][Dd][Dd][Oo][Nn][Ss][\\/]", "%1")     -- C:\...\AddOns\
    s = gsub(s, "(" .. START .. ")/[^\n:\"'<>|]-[\\/][Aa][Dd][Dd][Oo][Nn][Ss][\\/]", "%1")             -- /Applications/.../AddOns/
    s = gsub(s, "[%w_%-%.\\/]*[Aa][Dd][Dd][Oo][Nn][Ss][\\/]", "")                                      -- Interface\AddOns\
    s = gsub(s, "[%w_%-%.\\/]*[Ww][Tt][Ff][\\/][Aa][Cc][Cc][Oo][Uu][Nn][Tt][\\/][^\n:\"'<>|]*", "<path>")  -- WTF\Account\NAME\...
    s = gsub(s, "(" .. START .. ")%a:[\\/][^\n:\"'<>|]*", "%1<path>")                                    -- any other C:\...
    s = gsub(s, "(" .. START .. ")/[^\n:\"'<>|/]+/[^\n:\"'<>|]*", "%1<path>")                           -- /Users/..., /home/...
    s = sub(s, 2)
    s = gsub(s, "\\", "/")
    s = gsub(s, "Player%-[%w%-]+", "Player-?")
    s = gsub(s, "Pet%-[%w%-]+", "Pet-?")
    names = type(names) == "table" and names or ns.CrashNames()
    for _, e in ipairs(names) do
        if type(e) == "table" and type(e[1]) == "string" and e[1] ~= "" then s = ReplacePlain(s, e[1], tostring(e[2] or "")) end
    end
    local realms, listed = Realms(names)
    s = OtherNames(s, realms)
    if not listed then s = AnyNames(s) end
    return Cut(s, ns.CRASH_TEXT_MAX)
end

-- "Planner hook x: oops" -> "Planner hook x", "oops"; a line that starts with a file -> "add-on", all of it.
function ns.CrashPartOf(text)
    text = tostring(text)
    local at = find(text, ": ", 1, true)
    if at then
        local head = sub(text, 1, at - 1)
        if head ~= "" and not find(head, "[/\\]") and not find(head, ".lua", 1, true) then return head, sub(text, at + 2) end
    end
    return "add-on", text
end

local function Build()
    local ok, _, build = pcall(GetBuildInfo)
    return ok and build ~= nil and not ns:IsSecret(build) and tostring(build) or "?"
end
local function Now()
    local ok, t = pcall(time)
    return (ok and type(t) == "number") and t or 0
end
local function List()
    local root = ns.root
    if type(root) ~= "table" then return nil end
    if type(root.crashes) ~= "table" or type(root.crashes.list) ~= "table" then root.crashes = { list = {} } end
    return root.crashes.list
end
local function Kept()                                        -- the list, without making one
    local c = ns.root and ns.root.crashes
    return (type(c) == "table" and type(c.list) == "table") and c.list or {}
end

-- An error seen again is only counted: what it scrubbed to is remembered for the session (at most 100
-- of them), so an error every frame costs a lookup, not a scrub.
local seen, seenCount = {}, 0
local function Keep(part, message, stack)
    if not ns.CrashOn() then return nil end
    if ns:IsSecret(part) or ns:IsSecret(message) then return nil end
    local rawPart, rawMsg = tostring(part), tostring(message)
    local raw = rawPart .. "\0" .. rawMsg
    local known = seen[raw]
    if not known then
        local names = ns.CrashNames()
        local p, m = ns.CrashScrub(rawPart, names), ns.CrashScrub(rawMsg, names)
        known = { part = p, msg = m, key = p .. "\n" .. m }
        if seenCount >= 100 then seen, seenCount = {}, 0 end
        seen[raw], seenCount = known, seenCount + 1
    end
    local list = List()
    if not list then return nil end
    local now = Now()
    for _, r in ipairs(list) do
        if r.key == known.key then
            r.n = (tonumber(r.n) or 0) + 1
            r.last = now
            return r
        end
    end
    local lines = {}
    if type(stack) == "string" and not ns:IsSecret(stack) then
        local names = ns.CrashNames()
        for line in stack:gmatch("[^\n]+") do
            if #lines >= ns.CRASH_STACK_LINES then break end
            if find(line, "%S") then lines[#lines + 1] = ns.CrashScrub(line, names) end
        end
    end
    local record = { key = known.key, part = known.part, msg = known.msg, stack = lines, version = tostring(ns.version or "?"),
                     build = Build(), n = 1, first = now, last = now }
    while #list >= ns.CRASH_MAX do
        local oldest = 1
        for i, r in ipairs(list) do if (tonumber(r.first) or 0) < (tonumber(list[oldest].first) or 0) then oldest = i end end
        table.remove(list, oldest)
    end
    list[#list + 1] = record
    return record
end
-- When the names change (the group, the guild, the friends list), what the session remembered was scrubbed
-- without the new ones: it is forgotten, and the kept reports are scrubbed again (the same report twice is
-- then one, counted together). Only when there is something to scrub and the names really changed.
local lastNames
function ns.CrashRescrub()
    local list = Kept()
    if #list == 0 and seenCount == 0 then return false end
    local names = ns.CrashNames()
    local parts = {}
    for i, e in ipairs(names) do parts[i] = e[1] end
    local sig = table.concat(parts, "\1")
    if sig == lastNames then return false end
    lastNames = sig
    seen, seenCount = {}, 0
    local out, byKey = {}, {}
    for _, r in ipairs(list) do
        if type(r) == "table" then
            r.part, r.msg = ns.CrashScrub(r.part or "", names), ns.CrashScrub(r.msg or "", names)
            if type(r.stack) == "table" then
                for i, line in ipairs(r.stack) do r.stack[i] = ns.CrashScrub(line, names) end
            end
            r.key = r.part .. "\n" .. r.msg
            local same = byKey[r.key]
            if same then
                same.n = (tonumber(same.n) or 1) + (tonumber(r.n) or 1)
                same.first = math.min(tonumber(same.first) or 0, tonumber(r.first) or 0)
                same.last = math.max(tonumber(same.last) or 0, tonumber(r.last) or 0)
            else
                byKey[r.key] = r
                out[#out + 1] = r
            end
        end
    end
    for i = #list, 1, -1 do list[i] = nil end
    for i, r in ipairs(out) do list[i] = r end
    return true
end
do
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "FRIENDLIST_UPDATE" }) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", function() if ns.CrashOn() then pcall(ns.CrashRescrub) end end)
end

function ns.CrashKeep(part, message, stack)
    local ok, record = pcall(Keep, part, message, stack)
    if ok then return record end
    return nil
end

-- The handler ns:Guard and ns:Safe give xpcall while the switch is on: it notes where it happened.
function ns.CrashHandler(err)
    local ok, stack = pcall(debugstack, 2, 12, 0)
    ns.crashStack = ok and stack or nil
    return err
end

-- Every line added to ns.errors is kept too, while the switch is on (Guard and Safe add theirs with
-- rawset, having kept them already).
do
    local errors = ns.errors
    if type(errors) == "table" and getmetatable(errors) == nil then
        setmetatable(errors, { __newindex = function(t, k, v)
            rawset(t, k, v)
            if ns.CrashOn and ns.CrashOn() then pcall(function() ns.CrashKeep(ns.CrashPartOf(v)) end) end
        end })
    end
end

function ns.CrashIncluded()
    return ns:Tr("Each report holds the error's message with paths cut to the add-on's own files, the top lines of where it happened, the add-on's version, the game's build, the part it was in, how often it happened, and when it was first and last seen. Names are removed wherever the add-on can find them. Look over the report before you share it.")
end

local OFF_LINE = "Keep crash reports is off (Accessibility, Help and problems)."

function ns.CrashCode()
    local list = Kept()
    if #list == 0 then return nil end
    local r = {}
    for i, rec in ipairs(list) do
        r[i] = { tostring(rec.msg or ""), table.concat(type(rec.stack) == "table" and rec.stack or {}, "\n"), tostring(rec.part or ""),
                 tonumber(rec.n) or 1, tonumber(rec.first) or 0, tonumber(rec.last) or 0 }
    end
    return ns.CRASH_CODE_HEADER .. ns.ShareEncode({ v = tostring(ns.version or "?"), b = Build(), r = r })
end

-- Report a problem: the data lines in English (the maintainer reads them), the sentences translated.
if ns.AddReportSection then
    ns.AddReportSection("crashes", function()
        local n = #Kept()
        local out = { "CRASH REPORTS (" .. n .. ")" }
        if n > 0 then
            out[2] = "  " .. ns.CrashIncluded()
            out[3] = "  " .. (ns.CrashCode() or "")
        elseif ns.CrashOn() then
            out[2] = "  none kept"
        else
            out[2] = "  " .. ns:Tr(OFF_LINE)
        end
        return out
    end)
end

local function ClearAll() if ns.root then ns.root.crashes = nil end end

-- /fgui crashes (and /fgui crashes clear, which shows the same list: clearing always takes two clicks).
function ns:CrashCommand(text)
    local included = ns.CrashIncluded()
    local lines, w
    local function NoneLines()
        local out = { { left = ns:Tr("No crash reports kept."), tone = "dim" } }
        if not ns.CrashOn() then out[2] = { left = ns:Tr(OFF_LINE), tone = "dim" } end
        return out
    end
    local function redraw() if w and w.SetLines then w:SetLines(lines) end end
    local list = Kept()
    if #list == 0 then
        lines = NoneLines()
    else
        lines = {}
        for _, r in ipairs(list) do lines[#lines + 1] = { left = tostring(r.part) .. ": " .. tostring(r.msg), right = "x" .. tostring(r.n) } end
        lines[#lines + 1] = { left = ns:Tr("Copy them as one code"), action = true, click = function()
            ns:ShowTextWindow("Crash reports", included .. "\n\n" .. (ns.CrashCode() or ""))
        end }
        lines[#lines + 1] = ns.ConfirmLine(format(ns:Tr("Clear these %d reports (click twice)"), #list), ns:Tr("Click again within 10 seconds to clear them"),
            function() ClearAll(); lines = NoneLines() end, redraw)
    end
    w = ns:ShowList("Crashes", "Crash reports", lines, included, nil, nil, { rawNote = true })
    return #lines
end

-- The switch (Accessibility, Help and problems). Turning it off with reports kept asks first: the
-- switch stays on and a list offers to clear them and turn it off; closing that list changes nothing.
-- Returns false when the switch did not change as asked (the settings then show it as it is).
function ns:CrashSwitch(on)
    if not ns.db then return false end
    if on then ns.db.crashReports = true; return true end
    local n = #Kept()
    if n == 0 then ns.db.crashReports = false; return true end
    ns.db.crashReports = true
    local w
    local again = ns:Tr("Click again within 10 seconds to clear them")
    local lines
    lines = {
        { left = format(ns:Tr("%d crash reports are kept."), n) },
        ns.ConfirmLine(format(ns:Tr("Turn off and clear these %d reports (click twice)"), n), again, function()
            ClearAll()
            ns.db.crashReports = false
            if ns.optUI and ns.optUI.RefreshAll then pcall(ns.optUI.RefreshAll) end
            if w and w.Hide then w:Hide() end
        end, function() if w and w.SetLines and ns.db.crashReports then w:SetLines(lines) end end),
    }
    w = ns:ShowList("CrashesOff", "Keep crash reports", lines)
    return false
end
