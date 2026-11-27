local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: crash reports, kept only while Keep crash reports (Accessibility, Help and problems) is on,
-- and /fgui crashes.
--
-- Nothing here is ever sent: the reports stay in the saved file on the player's own computer, and
-- leave it only as a code the player copies and shares themselves. Each report is scrubbed before it
-- is kept: no player, character, realm or guild names, no Player- or Pet- GUIDs, no paths outside the
-- AddOns folder. While the switch is off nothing is kept at all.
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

-- Every name to take out: each character's name and realm (the saved character list's keys, "Name -
-- Realm", and who is playing now), and the guild. Plain strings of 2 bytes or more, longest first, so
-- "Mal'Ganis" goes before a character called "Mal".
function ns.CrashNames()
    local out, seen = {}, {}
    local function add(text, as)
        text = Plain(text)
        if text and #text >= 2 and not seen[text] then seen[text] = true; out[#out + 1] = { text, as } end
    end
    local chars = ns.root and ns.root.chars
    if type(chars) == "table" then
        for key in pairs(chars) do
            if type(key) == "string" then
                local at = find(key, " - ", 1, true)
                if at then add(sub(key, 1, at - 1), "<name>"); add(sub(key, at + 3), "<realm>") else add(key, "<name>") end
            end
        end
    end
    if UnitName then local ok, name = pcall(UnitName, "player"); if ok then add(name, "<name>") end end
    if GetRealmName then local ok, realm = pcall(GetRealmName); if ok then add(realm, "<realm>") end end
    if GetGuildInfo then local ok, guild = pcall(GetGuildInfo, "player"); if ok then add(guild, "<guild>") end end
    table.sort(out, function(a, b) if #a[1] ~= #b[1] then return #a[1] > #b[1] end return a[1] < b[1] end)
    return out
end

-- Each plain occurrence of `text` becomes `as` (no pattern is ever made from a name).
local function ReplacePlain(s, text, as)
    local at = find(s, text, 1, true)
    if not at then return s end
    local parts, from = {}, 1
    while at do
        parts[#parts + 1] = sub(s, from, at - 1)
        parts[#parts + 1] = as
        from = at + #text
        at = find(s, text, from, true)
    end
    parts[#parts + 1] = sub(s, from)
    return table.concat(parts)
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
-- or AddOns/ goes, \ becomes /, any other path is <path>), then GUIDs, then names; then the length.
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
    s = gsub(s, "(" .. START .. ")%a:[\\/][^\n:\"'<>|]*", "%1<path>")                                    -- any other C:\...
    s = gsub(s, "(" .. START .. ")/[^\n:\"'<>|/]+/[^\n:\"'<>|]*", "%1<path>")                           -- /Users/..., /home/...
    s = sub(s, 2)
    s = gsub(s, "\\", "/")
    s = gsub(s, "Player%-[%w%-]+", "Player-?")
    s = gsub(s, "Pet%-[%w%-]+", "Pet-?")
    for _, e in ipairs(type(names) == "table" and names or ns.CrashNames()) do
        if type(e) == "table" and type(e[1]) == "string" and e[1] ~= "" then s = ReplacePlain(s, e[1], tostring(e[2] or "")) end
    end
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
    return ns:Tr("Each report holds the error's message with paths cut to the add-on's own files, the top lines of where it happened, the add-on's version, the game's build, the part it was in, how often it happened, and when it was first and last seen. No player, character, realm or guild names.")
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
