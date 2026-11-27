local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: Help improve time estimates (the planner window). While it is on, the planner's level, quest, flight and
-- boat times are kept in a separate list, class only and with no names, for Share my times. Nothing is sent by
-- itself: Share my times only shows a code to copy. (The shared averages that come back: PlannerShare.lua, the
-- planner's folder.)
--
-- An entry is { k = kind, id = key, s = seconds, c = class token, f = faction, d = day }: the quest's id, the level
-- left, the flight's "from-to" node numbers or the crossing's id. Never a name: a key that is text must be lower-case
-- letters, digits and dashes, and the class and faction are the game's tokens.
------------------------------------------------------------------------------------------
local type, ipairs, pcall, tonumber, floor, format = type, ipairs, pcall, tonumber, math.floor, string.format

ns.PLANNER_LEARN_MAX = 500
ns.PLANNER_TIMES_HEADER = "FGT1!"
ns.PLANNER_SHARE_LINK = "https://fantasyglassui.com/get-started/#share-times"

local KINDS = { level = true, quest = true, flight = true, boat = true }
local FACTIONS = { Alliance = true, Horde = true }
local CLEAR_LIST = "PlannerLearnClear"

local function Faction()
    local ok, f = pcall(UnitFactionGroup, "player")
    if ok and not ns:IsSecret(f) and type(f) == "string" and FACTIONS[f] then return f end
end

local function Key(key)
    if ns:IsSecret(key) then return nil end
    if type(key) == "number" then
        if key == key and key >= 1 and key < 1e9 and key == floor(key) then return key end
        return nil
    end
    if type(key) == "string" and #key <= 40 and key:find("^[%l%d]+[%l%d%-]*$") then return key end
end

local function List(create)
    local root = ns.root
    if type(root) ~= "table" then return nil end
    local t = root.learnTimes
    if type(t) ~= "table" or type(t.list) ~= "table" then
        if not create then return nil end
        t = { list = {} }
        root.learnTimes = t
    end
    return t.list
end

-- Keep one time, only while the switch is on. `seconds`: a plain number over 0 (kept to the second).
function ns.PlannerLearnNote(kind, key, seconds)
    if type(ns.db) ~= "table" or ns.db.plannerLearnTimes ~= true then return end
    if ns:IsSecret(kind) or not KINDS[kind] or ns:IsSecret(seconds) or type(seconds) ~= "number" then return end
    if seconds ~= seconds or seconds <= 0 or seconds >= 1e9 then return end
    key = Key(key)
    if key == nil then return end
    local list = List(true)
    if not list then return end
    local okT, now = pcall(time)
    local day = okT and not ns:IsSecret(now) and type(now) == "number" and floor(now / 86400) or nil
    list[#list + 1] = { k = kind, id = key, s = floor(seconds + 0.5), c = ns.PlannerClassToken and ns.PlannerClassToken() or nil, f = Faction(), d = day }
    while #list > ns.PLANNER_LEARN_MAX do table.remove(list, 1) end
end

-- total, { level = n, quest = n, flight = n, boat = n }
function ns.PlannerLearnCount()
    local by = { level = 0, quest = 0, flight = 0, boat = 0 }
    local total = 0
    for _, e in ipairs(List(false) or {}) do
        if type(e) == "table" and by[e.k] then by[e.k], total = by[e.k] + 1, total + 1 end
    end
    return total, by
end

function ns.PlannerLearnClear()
    if type(ns.root) == "table" then ns.root.learnTimes = nil end
end

-- The code to share: the header, then the add-on's version, this character's class and faction, and the
-- entries without their day. nil with none kept.
function ns.PlannerTimesCode()
    local e = {}
    for _, x in ipairs(List(false) or {}) do
        if type(x) == "table" and KINDS[x.k] and tonumber(x.s) then e[#e + 1] = { x.k, x.id, x.s, x.c, x.f } end
    end
    if #e == 0 then return nil end
    return ns.PLANNER_TIMES_HEADER .. ns.ShareEncode({ v = ns.version, c = ns.PlannerClassToken and ns.PlannerClassToken() or nil, f = Faction(), e = e })
end

-- Share my times: what the code holds, where to send it, and the code.
function ns:PlannerShareTimes()
    local code = ns.PlannerTimesCode()
    if not code then
        ns:Print("No times kept yet. Turn on Help improve time estimates in the planner window, then play.")
        return
    end
    local total, by = ns.PlannerLearnCount()
    local text = table.concat({
        format(ns:Tr("What this code holds: the add-on's version, this character's class and faction, and %d times (%d levels, %d quests, %d flights, %d boat crossings). No names."),
            total, by.level, by.quest, by.flight, by.boat),
        format(ns:Tr("Nothing is sent by itself. To send it in, see %s"), ns.PLANNER_SHARE_LINK),
        "",
        code,
    }, "\n")
    ns:ShowTextWindow("Share my times", text)
end

-- The switch turned off with times kept: say how many, and offer to clear them (click twice). Closing keeps them.
function ns:PlannerLearnSwitch(on)
    if on then return end
    local n = ns.PlannerLearnCount()
    if n < 1 then return end
    local function Redraw()
        local w = ns:ListWindow(CLEAR_LIST)
        if not w then return end
        if ns.PlannerLearnCount() < 1 then w:Hide() else w:SetLines(w.lines) end
    end
    ns:ShowList(CLEAR_LIST, "Help improve time estimates", {
        { left = format(ns:Tr("%d times are kept. Nothing new is kept now."), n) },
        ns.ConfirmLine(ns:Tr("Clear them (click twice)"), ns:Tr("Click again within 10 seconds to clear them"), ns.PlannerLearnClear, Redraw),
    })
end
