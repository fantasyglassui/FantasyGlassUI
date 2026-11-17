local ADDON, ns = ...

------------------------------------------------------------------------------------------
-- Blocked actions.
--
-- During combat the game does not let an add-on show, hide, move or resize a "protected" frame:
-- one that can cast or target (an action button, a unit frame), or anything such a frame is
-- parented to or anchored to. When an add-on tries, nothing happens on screen, no error is raised,
-- and the game adds one to "Interface actions failed because of this AddOn" in its add-on list.
--
-- So nothing tells you where it happened. This keeps count, by the game function that was refused
-- and the line of this add-on that called it, so that /fgui blocked and the self-check can say.
-- It costs nothing unless the game refuses something.
------------------------------------------------------------------------------------------
local MAX_KINDS = 30                                         -- distinct places remembered per session
local THIS_FILE = "Blocked.lua"

ns.blocked = { total = 0, list = {}, byKey = {} }

-- The first line of this add-on in a call stack (not this file's own): "Tracker.lua:213".
function ns.BlockedWhere(stack)
    if type(stack) ~= "string" then return nil end
    for folder, file, line in stack:gmatch("(FantasyGlassUI[%w_]*)[/\\]([%w_]+%.lua)%]?:(%d+)") do
        if file ~= THIS_FILE then
            return (folder == ADDON and "" or "options: ") .. file .. ":" .. line
        end
    end
    return nil
end

function ns:NoteBlocked(event, addon, func, stack)
    if type(addon) ~= "string" or addon:sub(1, #ADDON) ~= ADDON then return false end      -- (this add-on, or its options folder)
    local b = ns.blocked
    b.total = b.total + 1
    local what = type(func) == "string" and func or "?"
    if event == "ADDON_ACTION_FORBIDDEN" then what = what .. " (never allowed for add-ons)" end
    local key = what .. "|" .. (ns.BlockedWhere(stack) or "?")
    local entry = b.byKey[key]
    if not entry then
        if #b.list >= MAX_KINDS then key = "other|?"; entry = b.byKey[key] end
        if not entry then
            entry = { what = (key == "other|?") and "other" or what, where = (key ~= "other|?") and ns.BlockedWhere(stack) or nil, count = 0, combat = 0 }
            b.byKey[key] = entry
            b.list[#b.list + 1] = entry
        end
    end
    entry.count = entry.count + 1
    if InCombatLockdown and InCombatLockdown() then entry.combat = entry.combat + 1 end
    -- kept with your settings too, so the count survives the reload you do before reporting it
    if ns.root then
        local saved = {}
        for i, e in ipairs(b.list) do saved[i] = { what = e.what, where = e.where, count = e.count, combat = e.combat } end
        ns.root.blockedNow = { version = ns.version, total = b.total, list = saved }
    end
    return true
end

-- Readable lines: the most frequent first.
local function Lines(total, list, limit)
    local sorted = {}
    for i, e in ipairs(list or {}) do sorted[i] = e end
    table.sort(sorted, function(a, b) return (a.count or 0) > (b.count or 0) end)
    local out = {}
    for i, e in ipairs(sorted) do
        if limit and i > limit then out[#out + 1] = format("  ... and %d more places", #sorted - limit); break end
        out[#out + 1] = format("  %5d x  %s   from %s%s", e.count or 0, tostring(e.what), tostring(e.where or "an unknown line"),
            (e.combat or 0) < (e.count or 0) and format("   (%d of them outside combat)", (e.count or 0) - (e.combat or 0)) or "")
    end
    return out
end
function ns:BlockedLines(limit)
    local out = {}
    local b = ns.blocked
    if b.total == 0 then
        out[#out + 1] = "Blocked actions this session: none."
    else
        out[#out + 1] = format("Blocked actions this session: %d.", b.total)
        for _, l in ipairs(Lines(b.total, b.list, limit)) do out[#out + 1] = l end
    end
    local before = ns.blockedBefore
    if type(before) == "table" and (tonumber(before.total) or 0) > 0 then
        out[#out + 1] = format("Before the last reload or login (version %s): %d.", tostring(before.version or "?"), before.total)
        for _, l in ipairs(Lines(before.total, before.list, limit)) do out[#out + 1] = l end
    end
    return out
end

-- At login: what the last session counted becomes "before", and this session starts clean.
function ns:BlockedCarryOver()
    if not ns.root and ns.InitDB then pcall(ns.InitDB, ns) end
    if not ns.root or ns.blockedCarried then return end
    ns.blockedCarried = true
    ns.blockedBefore = ns.root.blockedNow
    ns.root.blockedNow = nil
end

do
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN", "PLAYER_LOGIN" }) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", ns:Guard("Blocked events", function(_, event, addon, func)
        if event == "PLAYER_LOGIN" then pcall(ns.BlockedCarryOver, ns); return end
        local ok, stack = pcall(function() return debugstack and debugstack(2, 14, 0) or nil end)
        pcall(ns.NoteBlocked, ns, event, addon, func, ok and stack or nil)
    end))
end

-- May this frame be shown, hidden, moved or resized right now? (Always yes outside combat.)
function ns:Locked(frame)
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    if type(frame) ~= "table" or not frame.IsProtected then return false end
    local ok, protected = pcall(frame.IsProtected, frame)
    return (not ok) or (protected and true or false)
end
