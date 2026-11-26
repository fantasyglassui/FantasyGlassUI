local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner, batch 5 group B: plan with a friend, the duo (#35) (Tasks 3 and 4).
-- Built on the seams: ns.PlannerHook (Planner.lua, with "candidate" and "replan"), the panel's
-- registries (Guide.lua) and its section of the Guide tab (Bars.lua). Everything here is behind ns:GuideUnlocked().
--
-- The two add-ons talk only by add-on message, prefix ns.PLANNER_DUO_PREFIX, always a WHISPER to the one
-- partner, through one queue (one message every 0.25 s at most, each 255 bytes at most), held in a fight and
-- inside an instance. Nothing is ever said in public chat, nothing secret is sent, nothing received is run:
-- every text is read by patterns. A locked guide (or a friend who switched asking off) sends nothing at all.
-- Messages ("D1:" lines, fields split by ":"; <s> is the session, 4 to 8 hex digits):
--   ASK:<s>:<level>   YES:<s>   NO:<s>   AT:<s>:<planId>:<at>:<n>   HI:<s>   END:<s>
-- and the friend's state and the leader's plan as pieces, "SS:<s>z<count>:<i>:<n>:<state|plan>:<piece>".
-- The "D1:" messages go ahead of waiting pieces; a new state or plan drops the unsent pieces of the one before,
-- and a new AT the unsent AT before it.
-- The duo lives in memory only: a /reload or logout ends it.
------------------------------------------------------------------------------------------
ns.PLANNER_DUO_PREFIX = "FGUIPlan"
local PREFIX, WHISPER = ns.PLANNER_DUO_PREFIX, "WHISPER"
local MAX_BYTES = 255                -- one message
local RETRY_AFTER, TRIES = 2, 3      -- a throttled message: again after 2 s, 3 tries in all
local ASK_WAIT = 30                  -- seconds the leader waits for YES (once the question has gone)
local STATE_WAIT = 30                -- ... and then 30 s for the friend's state
local ANSWER_WAIT = 30               -- the friend's ask page: no choice in this long is no answer (the leader's wait)
local LEVEL_RETRY, LEVEL_TRIES = 5, 6    -- the friend's level could not be read: again every 5 s, 6 times
local LEVELS_APART = 6
local CAP = { log = 25, can = 300, flights = 200 }
local PIECES = { state = 20, plan = 60 }  -- the most pieces each may come in

local format, floor, max, min, abs, sqrt = string.format, math.floor, math.max, math.min, math.abs, math.sqrt
local ipairs, pairs, type, tonumber, tostring = ipairs, pairs, type, tonumber, tostring

local function Num(v) if not ns:IsSecret(v) and type(v) == "number" then return v end end
local function Str(v) if not ns:IsSecret(v) and type(v) == "string" then return v end end
local function Word(v) v = Str(v); return v and v:match("^%a+$") or nil end
local function Call(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, a, b = pcall(f, ...)
    if ok then return a, b end
end
local function Now() return Num(Call(GetTime)) end
local function MyLevel() return Num(Call(UnitLevel, "player")) end
local function Session(s) s = Str(s); return (s and #s >= 4 and #s <= 8 and s:match("^%x+$")) and s or nil end
-- The same player? Names as the game gives them ("Mira", "Mira-OtherRealm"), whatever their case.
local function Same(a, b)
    a, b = Str(a), Str(b)
    return a ~= nil and b ~= nil and a:lower() == b:lower()
end

local Sync                           -- (the planner hooks, registered while they are in use)
local syncLater = false              -- (the hooks change on the next tick: a hook that ends the duo is still being run)
local queue = {}                     -- { text, to, tries, after, pkind (a piece: "state"|"plan") }
local QUEUE_MAX = 200                -- the most messages that wait (the oldest plan pieces go first)
local pendingAsk                     -- the friend's side: { from, to, session, at } while the ask page waits
local askWindow
local pieceCount = 0                 -- (each state or plan sent gets its own piece id)

------------------------------------------------------------------------------------------
-- The queue
------------------------------------------------------------------------------------------
-- Queue one message to the partner (or `to`): false when it is too long, holds a secret, or there is no one.
function ns.PlannerDuoSend(text, to)
    if not ns:GuideUnlocked() then return false end
    if ns:IsSecret(text) or type(text) ~= "string" or text == "" or #text > MAX_BYTES then return false end
    local d = ns.plannerDuo
    to = Str(to) or (d and (d.to or d.partner))
    if type(to) ~= "string" or to == "" then return false end
    local _, _, _, pkind = ns.ParseSharePiece(text)
    local m = { text = text, to = to, tries = 0, pkind = pkind }
    if not pkind and text:find("^D1:AT:") then          -- (only the newest step matters: an unsent older AT goes, so ATs held in an instance never fill the cap)
        for i = #queue, 1, -1 do local q = queue[i]; if q.to == to and not q.pkind and q.text:find("^D1:AT:") then table.remove(queue, i) end end
    end
    if #queue >= QUEUE_MAX then                        -- (full: the oldest plan piece goes, else the oldest piece, else the oldest message)
        local drop
        for i, q in ipairs(queue) do if q.pkind == "plan" then drop = i; break end end
        if not drop then for i, q in ipairs(queue) do if q.pkind then drop = i; break end end end
        table.remove(queue, drop or 1)
    end
    if pkind then
        queue[#queue + 1] = m
    else                                               -- (a "D1:" message: ahead of the waiting pieces, after the other messages)
        local at = #queue + 1
        for i, q in ipairs(queue) do if q.pkind then at = i; break end end
        table.insert(queue, at, m)
    end
    return true
end
-- How many messages wait.
function ns.PlannerDuoPending() return #queue end

local FALLBACK = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, AddOnMessageLockdown = 11, TargetOffline = 12 }
local function Result(name)
    local E = type(Enum) == "table" and type(Enum.SendAddonMessageResult) == "table" and Enum.SendAddonMessageResult or nil
    local v = E and E[name]
    if v == nil then v = FALLBACK[name] end
    return v
end

-- A partner the game will not reach: the duo ends (without an END: it would not reach them either).
local function Gone(to, why)
    local d = ns.plannerDuo
    if d and (Same(d.to, to) or Same(d.partner, to)) then
        ns:PlannerDuoEnd(why, false, true)
    else
        for i = #queue, 1, -1 do if queue[i].to == to then table.remove(queue, i) end end
    end
end

-- The 0.25 s ticker's body: send the next message, unless in a fight or where messaging is locked.
function ns.PlannerDuoFlush()
    local m = queue[1]
    if not m then return false end
    if InCombatLockdown() or ns:MessagingLocked() then return false end
    local now = Now() or 0
    if m.after and now < m.after then return false end
    table.remove(queue, 1)
    local chat = C_ChatInfo
    if not (type(chat) == "table" and chat.SendAddonMessage) then return false end
    local ok, result = pcall(chat.SendAddonMessage, PREFIX, m.text, WHISPER, m.to)
    if not ok then return false end
    if ns:IsSecret(result) then return true end
    if result == nil or result == true or result == Result("Success") then return true end
    if result == Result("AddonMessageThrottle") or result == Result("ChannelThrottle") then
        m.tries = m.tries + 1
        if m.tries >= TRIES then
            Gone(m.to, "throttle")
        else
            m.after = now + RETRY_AFTER
            table.insert(queue, 1, m)
        end
    elseif result == Result("TargetOffline") then
        Gone(m.to, "offline")
    elseif result == Result("AddOnMessageLockdown") then
        m.after = now + RETRY_AFTER                    -- (locked after all: again in a moment, not on every tick)
        table.insert(queue, 1, m)
    end
    return false
end

-- A state or a plan, in pieces of 200 characters: "SS:<id>:<i>:<n>:<kind>:<piece>".
function ns.PlannerDuoSendChunks(kind, text)
    local d = ns.plannerDuo
    if not (d and PIECES[kind]) or ns:IsSecret(text) or type(text) ~= "string" or text == "" then return false end
    local parts = ns.ShareChunks(text)
    if #parts > PIECES[kind] then return false end
    for i = #queue, 1, -1 do if queue[i].pkind == kind then table.remove(queue, i) end end   -- (the older one's unsent pieces: this one replaces it)
    pieceCount = pieceCount + 1
    local id = d.session .. "z" .. pieceCount
    for i, piece in ipairs(parts) do ns.PlannerDuoSend(format("SS:%s:%d:%d:%s:%s", id, i, #parts, kind, piece)) end
    return #parts
end

------------------------------------------------------------------------------------------
-- Who is in it
------------------------------------------------------------------------------------------
function ns.PlannerDuoRole() local d = ns.plannerDuo; return d and d.role or nil end
function ns.PlannerDuoPartner() local d = ns.plannerDuo; return d and d.partner or nil end

local function Lead()
    local d = ns.plannerDuo
    return (d and d.role == "lead" and type(d.state) == "table") and d or nil
end
local function Friend()
    local d = ns.plannerDuo
    return (d and d.role == "friend") and d or nil
end

local LINES = {
    off = "You stopped planning together: planning for you alone.",
    noanswer = "No answer from %s (offline, or no Fantasy Glass UI): planning for you alone.",
    offline = "%s is offline: planning for you alone.",
    throttle = "Could not reach %s: planning for you alone.",
    declined = "%s would rather not plan together: planning for you alone.",
    level = "Could not read your level: try again out of combat.",
    lost = "Lost touch with %s: planning for you alone.",
    guide = "You follow another guide now: no longer planning with %s.",
    guideoff = "Planning together ended.",
    toolong = "This plan is too long to share: following it together needs a shorter plan.",
    start = "Planning for you alone now: no longer planning with %s.",
}

-- End the duo: END to the partner (unless noSend), the line for `why`, and a plan of your own (unless
-- noReplan, or why is "guide"/"guideoff": the guide you chose stays): the leader plans again, the friend
-- plans from scratch. From inside a planner hook (`later`), the hooks are taken away on the next tick.
function ns:PlannerDuoEnd(why, noReplan, noSend, later)
    local d = ns.plannerDuo
    if not d then return false end
    queue = {}
    if not noSend then ns.PlannerDuoSend("D1:END:" .. d.session, d.to or d.partner) end
    ns.plannerDuo = nil
    if later then syncLater = true else Sync() end
    local line = why and LINES[why]
    if line then ns:Print(line, d.partner) end
    if ns.GuideRedraw then ns:GuideRedraw() end
    if noReplan or why == "guide" or why == "guideoff" then return true end
    if d.role == "lead" then ns:PlannerReplan("duo end") else ns:PlannerStart() end
    return true
end

-- The name given, else your target when it is a friendly player, else your only party member.
local function PickPartner(name)
    name = Str(name) and ns.Trim(name) or nil
    if name and name ~= "" and not name:find("[%s:|]") then return ns.GroupShortName(name) or name, name end
    local function From(unit)
        local n, realm = Call(UnitName, unit)
        n, realm = Str(n), Str(realm)
        if not n or n == "" then return nil end
        local full = (realm and realm ~= "") and (n .. "-" .. realm) or n
        return ns.GroupShortName(full) or n, full          -- (the name the game will give their messages: with a realm when it is another)
    end
    if ns.Yes(Call(UnitIsPlayer, "target")) and ns.Yes(Call(UnitIsFriend, "player", "target")) and not ns.Yes(Call(UnitIsUnit, "target", "player")) then
        local short, full = From("target")
        if short then return short, full end
    end
    if not ns.Yes(Call(IsInRaid)) and Num(Call(GetNumGroupMembers)) == 2 then
        local short, full = From("party1")
        if short then return short, full end
    end
end

-- Ask a friend to plan together (you lead): ASK, then 30 s for YES and the friend's state.
function ns:PlannerDuoStart(name)
    if not ns:GuideUnlocked() then return false end
    local d = ns.plannerDuo
    if d then ns:Print("You are already planning with %s. /fgui guide duo off stops it.", d.partner); return false end
    if ns:SayMessagingLocked() then return false end
    local partner, to = PickPartner(name)
    if not partner then ns:Print("Target your friend or group with them, or type /fgui guide duo <name>."); return false end
    local me = ns.GroupShortName(Call(UnitName, "player"))
    if me and Same(me, partner) then ns:Print("That is you."); return false end
    local level = MyLevel()
    if not level then ns:Print("Could not read your level: try again out of combat."); return false end
    ns.PlannerDuoRegister()
    local now = Now() or 0
    local session = format("%06x", math.random(0, 16777215))
    ns.plannerDuo = { role = "lead", partner = partner, to = to, session = session, state = nil, heard = now, asked = now }
    ns.PlannerDuoSend(format("D1:ASK:%s:%d", session, floor(level)))
    ns:Print("Asking %s to plan your route together...", partner)
    return true
end

------------------------------------------------------------------------------------------
-- The friend's state: what they can do, read on their side
------------------------------------------------------------------------------------------
local function Sorted(t)
    local ids = {}
    for id in pairs(type(t) == "table" and t or {}) do if Num(id) then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids
end
local function Int(v) v = Num(v); return v and floor(v) or nil end

-- Your state for the leader (in a job: it yields), or nil when your level can't be read, or nil, "waiting"
-- while the quest source is still loading (unless `anyway`: then the state says what there is).
function ns.PlannerDuoMyState(anyway)
    local level = MyLevel()
    if not level then return nil end
    local ctx = ns.PlannerContext()
    if type(ctx) ~= "table" then return nil end
    if ctx.sourceWhy == "waiting" and not anyway then return nil, "waiting" end
    local st = { level = floor(level), log = {}, can = {}, flights = {} }
    st.faction = Word(Call(UnitFactionGroup, "player"))
    st.class = Word(ns.PlannerClassToken and ns.PlannerClassToken())
    local src = ctx.source
    st.questie = (type(src) == "table" and src.kind ~= "log") and true or false
    -- the quest log: ids and progress
    local QL = C_QuestLog
    local num = type(QL) == "table" and Num(Call(QL.GetNumQuestLogEntries)) or 0
    local n = 0
    for i = 1, min(num, 100) do
        ns.PlannerYield()
        local info = Call(QL.GetInfo, i)
        local id = type(info) == "table" and not ns.Yes(info.isHeader) and Int(info.questID) or nil
        if id and n < CAP.log and not st.log[id] then
            local done, total = 0, 0
            local objs = Call(QL.GetQuestObjectives, id)
            for _, o in ipairs(type(objs) == "table" and objs or {}) do
                local a = type(o) == "table" and Int(o.numFulfilled)
                local b = type(o) == "table" and Int(o.numRequired)
                if a and b and a >= 0 and b >= 0 then done, total = done + a, total + b end
            end
            st.log[id] = { done, total }
            n = n + 1
        end
    end
    -- what you could take: your own candidates, whatever the group setting (the leader's decides)
    if st.questie then
        ctx.group, ctx.allExclusive = "all", true            -- (every member of an exclusive set you could take: the leader picks one)
        local list, _, later = ns.PlannerCandidates(src, ctx)
        ctx.allExclusive = nil
        local count = 0
        for _, part in ipairs({ list or {}, later or {} }) do
            for _, rec in ipairs(part) do
                ns.PlannerYield()
                local id = type(rec) == "table" and Int(rec.id) or nil
                if id and count < CAP.can and not st.log[id] and not st.can[id] then st.can[id] = true; count = count + 1 end
            end
        end
    end
    local nf = 0
    for _, f in ipairs(type(ctx.flights) == "table" and ctx.flights or {}) do
        ns.PlannerYield()
        local node = type(f) == "table" and f.known == true and Int(f.node) or nil
        if node and nf < CAP.flights and not st.flights[node] then st.flights[node] = true; nf = nf + 1 end
    end
    local b = type(ctx.bindSpot) == "table" and ctx.bindSpot or nil
    if b and Int(b.map) and Num(b.x) and Num(b.y) then st.hearth = { map = Int(b.map), x = b.x, y = b.y, ready = ctx.hearth ~= nil } end
    return st
end

-- The state as lines of text ("level 24", "faction Alliance", "class MAGE", "questie 1", "log 123=1/8 456=2/2",
-- "can 11 12 13", "flights 2 6 12", "hearth 1453 60.1 75.3 1"), ids in order.
function ns.PlannerDuoStateText(s)
    if type(s) ~= "table" or not Int(s.level) then return nil end
    local lines = { "level " .. Int(s.level) }
    if Word(s.faction) then lines[#lines + 1] = "faction " .. s.faction end
    if Word(s.class) then lines[#lines + 1] = "class " .. s.class end
    lines[#lines + 1] = "questie " .. (s.questie and "1" or "0")
    local parts = {}
    for _, id in ipairs(Sorted(s.log)) do
        local e = s.log[id]
        local done, total = type(e) == "table" and Int(e[1]), type(e) == "table" and Int(e[2])
        if done and total and #parts < CAP.log then parts[#parts + 1] = format("%d=%d/%d", floor(id), done, total) end
    end
    if #parts > 0 then lines[#lines + 1] = "log " .. table.concat(parts, " ") end
    for _, key in ipairs({ "can", "flights" }) do
        parts = {}
        for _, id in ipairs(Sorted(s[key])) do
            if #parts < CAP[key] then parts[#parts + 1] = tostring(floor(id)) end
        end
        if #parts > 0 then lines[#lines + 1] = key .. " " .. table.concat(parts, " ") end
    end
    local h = type(s.hearth) == "table" and s.hearth or nil
    if h and Int(h.map) and Num(h.x) and Num(h.y) then
        lines[#lines + 1] = format("hearth %d %.1f %.1f %d", Int(h.map), h.x, h.y, h.ready and 1 or 0)
    end
    return table.concat(lines, "\n")
end

-- The state back from its text, or nil (no level). Every number through tonumber, words letters only,
-- lines it does not know left out, at most 25 log, 300 can and 200 flight entries.
function ns.PlannerDuoParseState(text)
    if ns:IsSecret(text) or type(text) ~= "string" then return nil end
    local s = { log = {}, can = {}, flights = {}, questie = false }
    local counts = { log = 0, can = 0, flights = 0 }
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        local key, rest = line:match("^(%a+)%s*(.-)%s*$")
        if key == "level" then
            local v = tonumber(rest:match("^(%d+)$") or "")
            if v and v >= 1 and v <= 200 then s.level = v end
        elseif key == "faction" or key == "class" then
            if rest:match("^%a+$") then s[key] = rest end
        elseif key == "questie" then
            s.questie = rest == "1"
        elseif key == "log" then
            for a, b, c in rest:gmatch("(%d+)=(%d+)/(%d+)") do
                local id, done, total = tonumber(a), tonumber(b), tonumber(c)
                if id and done and total and counts.log < CAP.log and not s.log[id] then
                    s.log[id] = { done, total }
                    counts.log = counts.log + 1
                end
            end
        elseif key == "can" or key == "flights" then
            for word in rest:gmatch("%d+") do
                local id = tonumber(word)
                if id and counts[key] < CAP[key] and not s[key][id] then
                    s[key][id] = true
                    counts[key] = counts[key] + 1
                end
            end
        elseif key == "hearth" then
            local m, x, y, r = rest:match("^(%d+) (%d+%.?%d*) (%d+%.?%d*) ([01])$")
            m, x, y = tonumber(m or ""), tonumber(x or ""), tonumber(y or "")
            if m and x and y and x <= 100 and y <= 100 then s.hearth = { map = m, x = x, y = y, ready = r == "1" } end
        end
    end
    if not s.level then return nil end
    return s
end

------------------------------------------------------------------------------------------
-- The leader's planning, fitted to both: the level window, the quests the friend can do, the flight
-- points both know, the hearthstone only when the friend's goes to the same place and is ready
------------------------------------------------------------------------------------------
local function Yards(a, b)
    local ca, xa, ya = ns.PlannerWorldPos(a.map, a.x, a.y)
    local cb, xb, yb = ns.PlannerWorldPos(b.map, b.x, b.y)
    if not (ca and cb) or ca ~= cb then return nil end
    return sqrt((xa - xb) ^ 2 + (ya - yb) ^ 2)
end

local function DuoContext(ctx)
    local d = Lead()
    local s = d and d.state
    if not (s and tonumber(s.level)) then return end
    local mine = tonumber(ctx.level) or 1
    -- the window of both is a shift of whatever the other hooks make (applied after all of them, in any order:
    -- ns.PlannerShiftWindow): with no other hook, [max(level, friend) - 4, min(level, friend) + 2]
    ctx.windowShift = { lo = max(0, s.level - mine), hi = min(0, s.level - mine) }
    local both = {}
    for _, f in ipairs(type(ctx.flights) == "table" and ctx.flights or {}) do
        ns.PlannerYield()
        if type(f) == "table" then
            local copy = {}
            for k, v in pairs(f) do copy[k] = v end
            copy.known = (f.known and f.node ~= nil and s.flights[f.node]) and true or false
            both[#both + 1] = copy
        end
    end
    ctx.flights = both
    local h = s.hearth
    local near = type(ctx.hearth) == "table" and type(h) == "table" and h.ready and Yards(ctx.hearth, h) or nil
    if not (near and near <= ns.PLANNER_HUB_YARDS) then ctx.hearth = nil end
    ctx.duo = s
end

-- Kept only when it is in the friend's log or what they can take (without Questie: in both logs).
local function DuoCandidate(rec, ctx, logged)
    local s = type(ctx) == "table" and ctx.duo
    if type(s) ~= "table" or type(rec) ~= "table" then return nil end
    local id = rec.id
    if s.questie == false then return (logged and s.log[id]) and true or false end
    return (s.log[id] or s.can[id]) and true or false
end

------------------------------------------------------------------------------------------
-- Messages in
------------------------------------------------------------------------------------------
local function HideAsk()
    if askWindow and askWindow.Hide then askWindow:Hide() end
end

local LevelLater
local stateQueued = false            -- (a "duoState" job waits in the planner's job list)
-- Work out your state (a job, sliced) and send it. Asked for while it is being worked out: once more, after it.
local function QueueState()
    local d = Friend()
    if d and ns.plannerJobKey == "duoState" then d.stateAgain = true; return end
    if ns.PlannerJob(function()
        stateQueued = false
        local mine = Friend()
        if not mine then return end
        mine.stateAgain = nil                             -- (a "once more" left by a state job that died or stopped is stale: this one is it)
        local st, why = ns.PlannerDuoMyState((mine.sourceTries or 0) >= LEVEL_TRIES)
        d = Friend()                                      -- (it may have ended meanwhile)
        if not d then return end
        if d.stateAgain then d.stateAgain, d.stateAt = nil, Now() or 0 end   -- (the next tick, once this job is over)
        if why == "waiting" then                          -- (Questie still loading: again in 5 s, 6 times, then what there is)
            d.sourceTries = (d.sourceTries or 0) + 1
            d.retryAt = (Now() or 0) + LEVEL_RETRY
            return
        end
        if not st then LevelLater(d); return end
        d.levelTries = 0
        ns.PlannerDuoSendChunks("state", ns.PlannerDuoStateText(st))
    end, "duoState") then stateQueued = true end
end
-- A "once more" whose job died or was stopped (no state job waits or runs): stale, dropped.
local function StaleState(d)
    if d.stateAgain and not stateQueued and ns.plannerJobKey ~= "duoState" then d.stateAgain = nil end
end
ns.PlannerDuoQueueState = QueueState
LevelLater = function(d)
    d.levelTries = (d.levelTries or 0) + 1
    if d.levelTries > LEVEL_TRIES then
        d.retryAt = nil
        ns:PlannerDuoEnd("level", true)
        return
    end
    d.retryAt = (Now() or 0) + LEVEL_RETRY
end

local function Accept()
    local a = pendingAsk
    pendingAsk = nil
    HideAsk()
    if not a or ns.plannerDuo or not ns:GuideUnlocked() or ns.db.plannerDuoAsk == false then return end
    if a.held or (Now() or 0) - a.at > ANSWER_WAIT then return end   -- (too late: the leader has given up)
    local now = Now() or 0
    ns.plannerDuo = { role = "friend", partner = a.from, to = a.to, session = a.session, heard = now, asked = now }
    ns.PlannerDuoSend("D1:YES:" .. a.session)
    Sync()
    ns:Print("Planning together with %s: they plan the route, you follow it.", a.from)
    QueueState()
end
local function Decline()
    local a = pendingAsk
    pendingAsk = nil
    HideAsk()
    if a and ns:GuideUnlocked() then ns.PlannerDuoSend("D1:NO:" .. a.session, a.to) end
end

-- The ask page: the question (on two lines when it is long), the two answers, and how long is left to answer.
local function AskLines(a)
    return {
        { left = format(ns:Tr("%s asks to plan your route together."), a.from), wrap = true },
        { left = "" },
        { left = ns:Tr("Plan together"), action = true, click = Accept },
        { left = ns:Tr("No thanks"), action = true, click = Decline },
    }
end
local function AskNote(left) return format(ns:Tr("Answer within %d s"), max(0, math.ceil(left))) end
-- Show the page and say so: a caption, the game's invite sound, and the question read aloud with reading aloud on.
local function PresentAsk(a)
    a.held, a.at = nil, Now() or 0                      -- (the time to answer counts from when you see it)
    a.left = ANSWER_WAIT
    askWindow = ns:ShowList("PlanDuoAsk", "Plan with a friend", AskLines(a), AskNote(ANSWER_WAIT), 380, 190)
    if ns.PlannerKeyFrames then ns.PlannerKeyFrames() end   -- (Tab and Enter answer it)
    local text = format(ns:Tr("%s asks to plan your route together."), a.from)
    ns:Caption("alert", text)
    ns.UISound("IG_PLAYER_INVITE")
    if ns.db and ns.db.readDialog then ns:Speak(text) end
end
local function Ask(from, to, session)
    if pendingAsk and Same(pendingAsk.from, from) then       -- (the same friend again: the page already up is kept, not shown twice)
        pendingAsk.to, pendingAsk.session = to, session
        return
    end
    pendingAsk = { from = from, to = to, session = session, at = Now() or 0 }
    if InCombatLockdown() then pendingAsk.held = true; return end   -- (not in the middle of a fight: shown once it is over)
    PresentAsk(pendingAsk)
end
-- Each tick while the page waits: a held page shown after the fight, the seconds left counted down, closed at 0.
local function AskTick(now)
    local a = pendingAsk
    if not a then return end
    if a.held then
        if not InCombatLockdown() then PresentAsk(a) end
        return
    end
    local left = ANSWER_WAIT - (now - a.at)
    if left <= 0 then pendingAsk = nil; HideAsk(); return end   -- (no choice: no answer)
    local whole = math.ceil(left)
    if whole ~= a.left then
        a.left = whole
        if askWindow and askWindow.note and askWindow.IsShown and ns.Yes(askWindow:IsShown()) then askWindow.note:SetText(AskNote(whole)) end
    end
end
ns.PlannerDuoAskTick = AskTick

-- The friend's state arrived (the leader's side).
local function StateIn(text)
    local d = ns.plannerDuo
    local s = ns.PlannerDuoParseState(text)
    if not (d and d.role == "lead" and s) then return end
    local mine = MyLevel()
    if mine and abs(mine - s.level) > LEVELS_APART then
        ns:Print("You are %d levels apart: planning together needs 6 or fewer. Planning for you alone.", floor(abs(mine - s.level)))
        ns:PlannerDuoEnd("levels")
        return
    end
    local first = d.state == nil
    d.state, d.accepted, d.heard = s, true, Now() or d.heard
    if s.questie == false and not d.toldQuestie then
        d.toldQuestie = true
        ns:Print("%s has no Questie: planning the quests you both have.", d.partner)
    end
    Sync()
    local ok = ns:PlannerReplan("duo")
    if not ok and first then ns:PlannerStart() end
end

------------------------------------------------------------------------------------------
-- One plan, followed together: the leader sends each plan it follows, the friend follows it; each
-- tells the other its step; the friend's replans become its state, sent for the leader to plan with
------------------------------------------------------------------------------------------
local PLAN_STEPS = 80                -- the most steps a shared plan has
local HI_EVERY, SILENCE = 60, 300    -- a word every minute; five minutes without one (outside instances) is lost touch
local STATE_AFTER = 2                -- the friend's replans: one state, 2 s after the first
local WAIT_KINDS = { turnin = true, fly = true, sail = true, hearth = true }
local planCount = 0

local function LevelWord(v)
    v = Num(tonumber(v))
    if not v or v < 0 then return "0" end
    return (v == floor(v)) and tostring(floor(v)) or format("%.1f", v)
end

-- The plan as text: "# duo <session> <planId> <zone> <fromLevel> <toLevel> <xp> <seconds>" (the last two only when
-- the summary has them), then the guide's own lines.
function ns.PlannerDuoPlanText(guide, summary, planId)
    local d = ns.plannerDuo
    if not (d and type(guide) == "table" and type(guide.steps) == "table") then return nil end
    local s = type(summary) == "table" and summary or {}
    local steps = {}
    for i = 1, min(#guide.steps, PLAN_STEPS) do steps[i] = guide.steps[i] end
    local head = format("# duo %s %d %d %s %s", d.session, floor(Num(tonumber(planId)) or 0), floor(Num(tonumber(s.zone)) or 0), LevelWord(s.fromLevel), LevelWord(s.toLevel))
    local xp, secs = Num(tonumber(s.xp)), Num(tonumber(s.seconds))
    if xp and secs and xp >= 0 and secs >= 0 then head = head .. format(" %d %d", floor(xp + 0.5), floor(secs + 0.5)) end
    return head .. "\n" .. ns.GuideText({ name = "duo", steps = steps })
end

-- A plan's text back: the guide and its header, or nil (another session, more than 80 steps, or a line
-- that does not read as a step: the whole plan is thrown away).
function ns.PlannerDuoReadPlan(text)
    local d = ns.plannerDuo
    if not d or ns:IsSecret(text) or type(text) ~= "string" then return nil end
    local first, rest = text:match("^([^\n]*)\n?(.*)$")
    first = first or ""
    local session, planId, zone, from, to, xp, secs = first:match("^# duo (%x+) (%d+) (%d+) (%d+%.?%d*) (%d+%.?%d*) (%d+) (%d+)$")
    if not session then session, planId, zone, from, to = first:match("^# duo (%x+) (%d+) (%d+) (%d+%.?%d*) (%d+%.?%d*)$") end   -- (no totals)
    if not session or session ~= d.session then return nil end
    local header = { session = session, planId = tonumber(planId), zone = tonumber(zone), fromLevel = tonumber(from), toLevel = tonumber(to),
                     xp = tonumber(xp or ""), seconds = tonumber(secs or "") }
    if not (header.planId and header.zone and header.fromLevel and header.toLevel) then return nil end
    local steps = {}
    for line in (rest .. "\n"):gmatch("(.-)\r?\n") do
        if not line:match("^%s*[Gg]uide:") then
            local step, why = ns.GuideParseLine(line)
            if why then return nil end
            if step then
                if #steps >= PLAN_STEPS then return nil end
                steps[#steps + 1] = step
            end
        end
    end
    return { name = ns.GUIDE_PLANNED, steps = steps }, header
end

local function Planned()
    local st = ns.GuideState and ns.GuideState()
    return type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED, st
end

-- Tell the partner the step you are on (once per step of a plan).
local function SendAt(d)
    local on, st = Planned()
    if not (on and d.planId) then return end
    local plan = type(st.plan) == "table" and type(st.plan.steps) == "table" and st.plan or nil
    local n = min(plan and #plan.steps or 0, PLAN_STEPS)             -- (the steps both have: at most the 80 sent)
    local at = min(floor(Num(st.at) or 1), n + 1)
    local key = d.planId .. ":" .. at
    if key == d.atKey then return end
    d.atKey = key
    ns.PlannerDuoSend(format("D1:AT:%s:%d:%d:%d", d.session, d.planId, at, n))
end

-- The leader: each plan applied goes to the friend, with a new planId.
local function DuoApplied(guide, summary)
    local d = Lead()
    if not d then return end
    planCount = planCount + 1
    local text = ns.PlannerDuoPlanText(guide, summary, planCount)
    if not text then return end
    if not ns.PlannerDuoSendChunks("plan", text) then             -- (over 60 pieces: it cannot be shared)
        ns:PlannerDuoEnd("toolong", true, false, true)
        return
    end
    d.planId, d.atKey = planCount, nil
    SendAt(d)
end

-- The friend: follow the leader's plan (after the fight when one is on), and say where you are at once.
-- Your level unreadable: the plan is held and tried again every 5 s, 6 times (as the state), then dropped quietly.
local function ApplyPlan(d, guide, header)
    local held = d.waiting
    d.waiting = nil
    local level = MyLevel()
    if not level then
        local tries = ((held and held.at and held.header.planId == header.planId) and held.tries or 0) + 1
        if tries <= LEVEL_TRIES then d.waiting = { guide = guide, header = header, tries = tries, at = (Now() or 0) + LEVEL_RETRY } end
        return
    end
    d.planId, d.atKey = header.planId, nil
    ns:PlannerStop()
    local toLevel = level + max(0, header.toLevel - header.fromLevel)    -- (the leader's gain, from your own level)
    ns:GuideSetPlan(guide, { zone = header.zone ~= 0 and header.zone or nil, fromLevel = level, toLevel = toLevel, duo = true,
                             xp = header.xp, seconds = header.seconds })     -- (the leader's totals: a code shared from here adds them up)
    SendAt(d)
end
local function PlanIn(d, text)
    local guide, header = ns.PlannerDuoReadPlan(text)
    if not guide then return end
    local newest = max(d.planId or 0, d.waiting and d.waiting.header.planId or 0)
    if header.planId < newest then return end                     -- (an older plan than the one you have)
    if InCombatLockdown() then d.waiting = { guide = guide, header = header }; return end
    ApplyPlan(d, guide, header)
end
function ns.PlannerDuoAfterFight()
    local d = Friend()
    if d and d.waiting and not d.waiting.at and not InCombatLockdown() then ApplyPlan(d, d.waiting.guide, d.waiting.header) end   -- (a plan held for your level: the ticker)
end

-- The friend's replans: refused, and its state sent instead (once, 2 s after the first); its own
-- "Plan my route" ends the duo and plans alone.
local function DuoReplan(reason)
    local d = Friend()
    if not d then return nil end
    if reason == "start" then ns:PlannerDuoEnd("start", true, false, true); return nil end   -- (the hooks go on the next tick)
    if not d.stateAt then d.stateAt = (Now() or 0) + STATE_AFTER end
    return false
end
local function AtIn(d, more)
    local planId, at, n = more:match("^:(%d+):(%d+):(%d+)$")
    planId, at, n = tonumber(planId or ""), tonumber(at or ""), tonumber(n or "")
    if not (planId and at and n) or n > 1000 or at < 1 or at > n + 1 then return end
    local was = d.partnerAt
    d.partnerAt = { planId = planId, at = at, n = n }
    if was and was.planId == planId and was.at == at and was.n == n then return end   -- (nothing new: no redraw)
    if ns.GuideRedraw then ns:GuideRedraw() end
end
local function EndIn(d)
    ns:Print("%s stopped planning together.", d.partner)
    ns:PlannerDuoEnd(nil, false, true)
end

-- The panel's line: the partner's progress, or wait for them here, or paused inside an instance.
function ns.PlannerDuoLine(st, steps, at)
    local d = ns.plannerDuo
    if not (d and type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED) then return nil end
    if ns:MessagingLocked() then return ns:Tr("Planning together is paused inside an instance.") end
    local p = d.partnerAt
    if not (p and d.planId and p.planId == d.planId) then return nil end
    at = tonumber(at) or 1
    local step = type(steps) == "table" and steps[at] or nil
    if type(step) == "table" and WAIT_KINDS[step.kind] and p.at < at then return format(ns:Tr("%s is behind: wait for them here before you go on"), d.partner) end
    if p.at > at then return format(ns:Tr("%s: done"), d.partner) end
    if p.at == at then return format(ns:Tr("%s: on this step"), d.partner) end
    if at - p.at == 1 then return format(ns:Tr("%s: 1 step behind"), d.partner) end
    return format(ns:Tr("%s: %d steps behind"), d.partner, at - p.at)
end

-- Staying in touch, each tick: the friend's state when due, a word every minute, lost touch after five
-- minutes of silence (counted only while messaging is allowed), and the end once you follow another guide.
local function StayInTouch(d, now)
    if d.stateAt and now >= d.stateAt then d.stateAt = nil; QueueState() end
    local last = d.lastTick or now
    d.lastTick = now
    if not ns:MessagingLocked() then
        d.silent = (d.silent or 0) + max(0, now - last)
        if d.silent > SILENCE then ns:PlannerDuoEnd("lost"); return end
        d.hiAt = d.hiAt or now
        if now - d.hiAt >= HI_EVERY and not InCombatLockdown() then
            d.hiAt = now
            ns.PlannerDuoSend("D1:HI:" .. d.session)
        end
    end
    if d.planId and now >= (d.guideAt or 0) then           -- (once a second: still following the plan?)
        d.guideAt = now + 1
        if not ns:GuideOn() then ns:PlannerDuoEnd("guideoff")
        elseif not Planned() then ns:PlannerDuoEnd("guide") end
    end
end

local duoHooks = { context = DuoContext, candidate = DuoCandidate, applied = DuoApplied, replan = DuoReplan }
Sync = function()
    syncLater = false
    local lead = ns:GuideUnlocked() and Lead() ~= nil
    local h = duoHooks
    ns.PlannerHook("context", "duo", lead and h.context or nil)
    ns.PlannerHook("window", "duo", nil)                -- (the window of both: ctx.windowShift, see DuoContext)
    ns.PlannerHook("candidate", "duo", lead and h.candidate or nil)
    ns.PlannerHook("applied", "duo", lead and h.applied or nil)
    ns.PlannerHook("replan", "duo", (ns:GuideUnlocked() and Friend() ~= nil) and h.replan or nil)
end
ns.PlannerDuoSync = function() Sync() end             -- (the tests: a duo set up by hand)

-- The sessions already told "no" or "ended" (once each; a handful at most, forgotten when there are many).
local told, toldCount = {}, 0
local function Tell(session)
    if toldCount >= 50 then told, toldCount = {}, 0 end
    told[session], toldCount = true, toldCount + 1
end
local function Receive(from, msg, sender)
    local d = ns.plannerDuo
    local kind, rest = msg:match("^D1:(%u+):(.*)$")
    if kind then
        local session, more = rest:match("^(%x+)(.*)$")
        session = Session(session)
        if not session then return end
        if kind == "ASK" then
            if d or not more:match("^:%d+$") then return end
            if ns.db.plannerDuoAsk == false or not ns:GuideOn() then     -- (asking switched off, or the guide: a plain no, said once)
                if not told[session] then Tell(session); ns.PlannerDuoSend("D1:NO:" .. session, Str(sender) or from) end
                return
            end
            if pendingAsk and not Same(pendingAsk.from, from) then return end   -- (one question at a time: the other one times out)
            Ask(from, Str(sender) or from, session)
            return
        end
        if kind == "END" and pendingAsk and Same(from, pendingAsk.from) and session == pendingAsk.session then
            pendingAsk = nil                                  -- (the leader gave up: the question is gone)
            HideAsk()
            return
        end
        if not (d and Same(from, d.partner) and session == d.session) then
            -- a session you do not have (you reloaded, or it ended here): tell them once, so they stop at once
            -- instead of waiting five minutes for silence
            if kind ~= "END" and kind ~= "NO" and not (d and session == d.session) and not told[session] then   -- (your own session from a stranger: ignored)
                Tell(session)
                ns.PlannerDuoSend("D1:END:" .. session, Str(sender) or from)
            end
            return
        end
        d.heard, d.silent = Now() or d.heard, 0
        if kind == "YES" and d.role == "lead" and not d.accepted then
            d.accepted, d.yesAt = true, Now() or 0
            d.partner = from                                  -- (their name as the game spells it, from now on)
            ns:Print("%s will plan with you: waiting for what they can do...", d.partner)
        elseif kind == "NO" and d.role == "lead" and not d.accepted then
            ns:PlannerDuoEnd("declined", false, true)
        elseif kind == "AT" then AtIn(d, more)
        elseif kind == "END" then EndIn(d)
        end                                                   -- (HI: heard, and that is all it says)
        return
    end
    local id, i, n, pkind, piece = ns.ParseSharePiece(msg)
    if not (id and PIECES[pkind]) then return end
    local theirs = Session(id:match("^(%x+)z%d+$"))
    if not (d and Same(from, d.partner) and theirs == d.session) then           -- (a piece of a session you do not have: as above)
        if theirs and not (d and theirs == d.session) and not told[theirs] then Tell(theirs); ns.PlannerDuoSend("D1:END:" .. theirs, Str(sender) or from) end
        return
    end
    if not (i and n) or n < 1 or n > PIECES[pkind] or i < 1 or i > n then return end
    d.heard, d.silent = Now() or d.heard, 0
    local text = ns.ShareReceive(from, id, i, n, pkind, piece, Now() or 0)
    if not text then return end
    if pkind == "state" and d.role == "lead" then StateIn(text)
    elseif pkind == "plan" and d.role == "friend" then PlanIn(d, text) end
end

------------------------------------------------------------------------------------------
-- The ticker, the prefix, the panel's entry and the command
------------------------------------------------------------------------------------------
local Listen                         -- (CHAT_MSG_ADDON, only while the guide is unlocked)
local function Reset()
    if Listen and not ns:GuideUnlocked() then Listen(false) end
    queue, pendingAsk = {}, nil
    HideAsk()
    if ns.plannerDuo then ns.plannerDuo = nil end
    Sync()
end

local function Tick()
    if not ns:GuideUnlocked() then
        if ns.plannerDuo or #queue > 0 or pendingAsk then Reset() end
        if Listen then Listen(false) end
        return
    end
    if Listen then Listen(true) end
    if syncLater then Sync() end
    ns.PlannerDuoFlush()
    local now = Now()
    if not now then return end
    AskTick(now)
    local d = ns.plannerDuo
    if not d then return end
    if d.role == "lead" and not d.accepted then
        if #queue > 0 then d.asked = now                                   -- (the 30 s count once the question has gone)
        elseif now - d.asked > ASK_WAIT then ns:PlannerDuoEnd("noanswer") end
        return
    end
    if d.role == "lead" and not d.state then
        if now - (d.yesAt or now) > STATE_WAIT then ns:PlannerDuoEnd("noanswer") end
        return
    end
    if d.role == "friend" then StaleState(d) end
    local w = d.role == "friend" and d.waiting
    if w and w.at and now >= w.at and not InCombatLockdown() then ApplyPlan(d, w.guide, w.header) end
    if d.role == "friend" and d.retryAt and now >= d.retryAt then d.retryAt = nil; QueueState() end
    StayInTouch(d, now)
end
ns.PlannerDuoTick = Tick
ns:Every(0.25, "Planner duo", Tick)

-- The prefix, registered once, when the guide is unlocked; the add-on messages listened to from then on.
local registered = false
function ns.PlannerDuoRegister()
    if not ns:GuideUnlocked() then return end
    if Listen then Listen(true) end
    if registered then return end
    local chat = C_ChatInfo
    if type(chat) == "table" and chat.RegisterAddonMessagePrefix then registered = pcall(chat.RegisterAddonMessagePrefix, PREFIX) end
end

do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
    local listening = false
    Listen = function(on)                                -- (a locked player does not even hear add-on messages)
        on = on and true or false
        if on == listening then return end
        listening = on
        if on then pcall(ev.RegisterEvent, ev, "CHAT_MSG_ADDON") else pcall(ev.UnregisterEvent, ev, "CHAT_MSG_ADDON") end
    end
    ns.PlannerDuoListening = function() return listening end
    local OnEvent = ns:Guard("Planner duo", function(_, event, prefix, msg, channel, sender)
        if event == "PLAYER_LOGIN" then ns.PlannerDuoRegister(); return end
        if event == "PLAYER_REGEN_ENABLED" then                      -- (a plan that came in a fight: followed now)
            if ns:GuideUnlocked() and ns.PlannerDuoAfterFight then ns.PlannerDuoAfterFight() end
            return
        end
        if event ~= "CHAT_MSG_ADDON" or not ns:GuideUnlocked() then return end
        if ns:IsSecret(prefix) or ns:IsSecret(msg) or ns:IsSecret(channel) or ns:IsSecret(sender) then return end
        if type(prefix) ~= "string" or type(msg) ~= "string" or type(channel) ~= "string" then return end
        if prefix ~= PREFIX or channel ~= WHISPER or #msg > MAX_BYTES then return end
        local from = ns.GroupShortName(sender)
        if type(from) ~= "string" or from == "" then return end
        Receive(from, msg, sender)
    end)
    ev:SetScript("OnEvent", OnEvent)
    ns.PlannerDuoEvent = function(...) return OnEvent(ev, ...) end    -- (the same, called directly: the tests)
end

-- Unlocking registers the prefix; locking ends the duo at once, sending nothing (and the next unlock registers
-- the prefix again: the game takes a second registration of the same prefix without harm).
ns.GuideRegisterLock("duo", function(unlocked)
    if unlocked and ns:GuideUnlocked() then ns.PlannerDuoRegister() else registered = false; Reset() end
end)

ns.GuideRegisterAction("panel", "duo", function() return ns.plannerDuo and "Stop planning together" or "Plan with a friend" end, function()
    if ns.plannerDuo then ns:PlannerDuoEnd("off") else ns:PlannerDuoStart() end
end, function() return ns:GuideUnlocked() and (Planned()) end)
ns.GuideRegisterAdvance("duo", function(st)
    local d = ns.plannerDuo
    if d and d.planId and type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED then SendAt(d) end
end)
ns.GuideRegisterLine("duo", function(st, steps, at) return ns.PlannerDuoLine(st, steps, at) end)
ns.GuideRegisterTitle("duo", function(st)
    local d = ns.plannerDuo
    if not (d and (d.role == "friend" or d.state) and type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED) then return nil end
    return format(ns:Tr("with %s"), d.partner)
end)
ns.GuideRegisterCommand("duo", function(rest)
    rest = ns.Trim(Str(rest) or "")
    if rest:lower() == "off" then
        if not ns:PlannerDuoEnd("off") then ns:Print("You are not planning with a friend.") end
        return true
    end
    return ns:PlannerDuoStart(rest ~= "" and rest or nil)
end)
