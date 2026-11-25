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
-- The duo lives in memory only: a /reload or logout ends it.
------------------------------------------------------------------------------------------
ns.PLANNER_DUO_PREFIX = "FGUIPlan"
local PREFIX, WHISPER = ns.PLANNER_DUO_PREFIX, "WHISPER"
local MAX_BYTES = 255                -- one message
local RETRY_AFTER, TRIES = 2, 3      -- a throttled message: again after 2 s, 3 tries in all
local ASK_WAIT = 30                  -- seconds the leader waits for YES (once the question has gone)
local STATE_WAIT = 60                -- ... and then for the friend's state
local ANSWER_WAIT = 60               -- the friend's ask page: no choice in this long is no answer
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

local Sync                           -- (the planner hooks, registered while they are in use)
local queue = {}                     -- { text, to, tries, after }
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
    queue[#queue + 1] = { text = text, to = to, tries = 0 }
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
    if d and (d.to == to or d.partner == to) then
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
        table.insert(queue, 1, m)                      -- (locked after all: it goes once messaging is allowed again)
    end
    return false
end

-- A state or a plan, in pieces of 200 characters: "SS:<id>:<i>:<n>:<kind>:<piece>".
function ns.PlannerDuoSendChunks(kind, text)
    local d = ns.plannerDuo
    if not (d and PIECES[kind]) or ns:IsSecret(text) or type(text) ~= "string" or text == "" then return false end
    local parts = ns.ShareChunks(text)
    if #parts > PIECES[kind] then return false end
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
    noanswer = "No answer from %s: planning for you alone.",
    offline = "%s is offline: planning for you alone.",
    throttle = "Could not reach %s: planning for you alone.",
    declined = "%s would rather not plan together: planning for you alone.",
    level = "Could not read your level: try again out of combat.",
    lost = "Lost touch with %s: planning for you alone.",
    guide = "You follow another guide now: no longer planning with %s.",
    start = "Planning for you alone now: no longer planning with %s.",
}

-- End the duo: END to the partner (unless noSend), the line for `why`, and a plan of your own (unless
-- noReplan, or why is "guide": the guide you chose stays): the leader plans again, the friend plans from scratch.
function ns:PlannerDuoEnd(why, noReplan, noSend)
    local d = ns.plannerDuo
    if not d then return false end
    queue = {}
    if not noSend then ns.PlannerDuoSend("D1:END:" .. d.session, d.to or d.partner) end
    ns.plannerDuo = nil
    Sync()
    local line = why and LINES[why]
    if line then ns:Print(line, d.partner) end
    if ns.GuideRedraw then ns:GuideRedraw() end
    if noReplan or why == "guide" then return true end
    if d.role == "lead" then ns:PlannerReplan("duo end") else ns:PlannerStart() end
    return true
end

-- Your target when it is a friendly player, else your only party member, else the name given.
local function PickPartner(name)
    local function From(unit)
        local n, realm = Call(UnitName, unit)
        n, realm = Str(n), Str(realm)
        if not n or n == "" then return nil end
        return ns.GroupShortName(n) or n, (realm and realm ~= "") and (n .. "-" .. realm) or n
    end
    if ns.Yes(Call(UnitIsPlayer, "target")) and ns.Yes(Call(UnitIsFriend, "player", "target")) and not ns.Yes(Call(UnitIsUnit, "target", "player")) then
        local short, full = From("target")
        if short then return short, full end
    end
    if not ns.Yes(Call(IsInRaid)) and Num(Call(GetNumGroupMembers)) == 2 then
        local short, full = From("party1")
        if short then return short, full end
    end
    name = Str(name) and ns.Trim(name) or nil
    if name and name ~= "" and not name:find("[%s:|]") then return ns.GroupShortName(name) or name, name end
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
    if me and ns.Is(me, partner) then ns:Print("That is you."); return false end
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

-- Your state for the leader (in a job: it yields), or nil when your level can't be read.
function ns.PlannerDuoMyState()
    local level = MyLevel()
    if not level then return nil end
    local ctx = ns.PlannerContext()
    if type(ctx) ~= "table" then return nil end
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
        ctx.group = "all"
        local list, _, later = ns.PlannerCandidates(src, ctx)
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

local function DuoWindow(rec, ctx, lo, hi)
    local s = type(ctx) == "table" and ctx.duo
    if type(s) ~= "table" or not tonumber(s.level) then return lo, hi end
    local mine = tonumber(ctx.level) or 1
    return max(mine, s.level) - 4, min(mine, s.level) + 2
end

local function DuoContext(ctx)
    local d = Lead()
    local s = d and d.state
    if not (s and tonumber(s.level)) then return end
    local mine = tonumber(ctx.level) or 1
    ctx.windowLo, ctx.windowHi = max(mine, s.level) - 4, min(mine, s.level) + 2
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

ns.PlannerDuoHooks = { context = DuoContext, window = DuoWindow, candidate = DuoCandidate }
Sync = function()
    local lead = ns:GuideUnlocked() and Lead() ~= nil
    local h = ns.PlannerDuoHooks
    ns.PlannerHook("context", "duo", lead and h.context or nil)
    ns.PlannerHook("window", "duo", lead and h.window or nil)
    ns.PlannerHook("candidate", "duo", lead and h.candidate or nil)
end

------------------------------------------------------------------------------------------
-- Messages in
------------------------------------------------------------------------------------------
local function HideAsk()
    if askWindow and askWindow.Hide then askWindow:Hide() end
end

local LevelLater
-- Work out your state (a job, sliced) and send it.
local function QueueState()
    ns.PlannerJob(function()
        if not Friend() then return end
        local st = ns.PlannerDuoMyState()
        local d = Friend()                                -- (it may have ended meanwhile)
        if not d then return end
        if not st then LevelLater(d); return end
        d.levelTries = 0
        ns.PlannerDuoSendChunks("state", ns.PlannerDuoStateText(st))
    end, "duoState")
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
    local now = Now() or 0
    ns.plannerDuo = { role = "friend", partner = a.from, to = a.to, session = a.session, heard = now, asked = now }
    ns.PlannerDuoSend("D1:YES:" .. a.session)
    ns:Print("Planning together with %s: they plan the route, you follow it.", a.from)
    QueueState()
end
local function Decline()
    local a = pendingAsk
    pendingAsk = nil
    HideAsk()
    if a and ns:GuideUnlocked() then ns.PlannerDuoSend("D1:NO:" .. a.session, a.to) end
end

local function Ask(from, to, session)
    pendingAsk = { from = from, to = to, session = session, at = Now() or 0 }
    local lines = {
        { left = format(ns:Tr("%s asks to plan your route together."), from) },
        { left = "" },
        { left = "|cff33ff66" .. ns:Tr("Plan together") .. "|r", click = Accept },
        { left = "|cff9aa4b4" .. ns:Tr("No thanks") .. "|r", click = Decline },
    }
    askWindow = ns:ShowList("PlanDuoAsk", "Plan with a friend", lines, nil, 380, 170)
end

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

local handlers = {}                   -- D1 kinds the duo's later parts add: kind -> fn(d, rest, from)
ns.PlannerDuoHandlers = handlers

local function Receive(from, msg, sender)
    local d = ns.plannerDuo
    local kind, rest = msg:match("^D1:(%u+):(.*)$")
    if kind then
        local session, more = rest:match("^(%x+)(.*)$")
        session = Session(session)
        if not session then return end
        if kind == "ASK" then
            if d or ns.db.plannerDuoAsk == false or not more:match("^:%d+$") then return end
            Ask(from, Str(sender) or from, session)
            return
        end
        if not (d and from == d.partner and session == d.session) then return end
        d.heard = Now() or d.heard
        if kind == "YES" and d.role == "lead" and not d.accepted then
            d.accepted, d.yesAt = true, Now() or 0
            ns:Print("%s will plan with you: waiting for what they can do...", d.partner)
        elseif kind == "NO" and d.role == "lead" and not d.accepted then
            ns:PlannerDuoEnd("declined", false, true)
        elseif handlers[kind] then
            handlers[kind](d, more, from)
        end
        return
    end
    local id, i, n, pkind, piece = ns.ParseSharePiece(msg)
    if not (id and d and from == d.partner and PIECES[pkind]) then return end
    if id:match("^(%x+)z%d+$") ~= d.session or not (i and n) or n < 1 or n > PIECES[pkind] or i < 1 or i > n then return end
    local text = ns.ShareReceive(from, id, i, n, pkind, piece, Now() or 0)
    if not text then return end
    if pkind == "state" and d.role == "lead" then StateIn(text)
    elseif pkind == "plan" and d.role == "friend" and handlers.plan then handlers.plan(d, text, from) end
end

------------------------------------------------------------------------------------------
-- The ticker, the prefix, the panel's entry and the command
------------------------------------------------------------------------------------------
local function Reset()
    queue, pendingAsk = {}, nil
    HideAsk()
    if ns.plannerDuo then ns.plannerDuo = nil end
    Sync()
end

local ticks = {}                      -- what the duo's later parts check each tick: fn(d, now)
ns.PlannerDuoTicks = ticks
local function Tick()
    if not ns:GuideUnlocked() then
        if ns.plannerDuo or #queue > 0 or pendingAsk then Reset() end
        return
    end
    ns.PlannerDuoFlush()
    local now = Now()
    if not now then return end
    if pendingAsk and now - pendingAsk.at > ANSWER_WAIT then pendingAsk = nil; HideAsk() end   -- (no choice: no answer)
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
    if d.role == "friend" and d.retryAt and now >= d.retryAt then d.retryAt = nil; QueueState() end
    for _, fn in ipairs(ticks) do
        if ns.plannerDuo ~= d then return end
        fn(d, now)
    end
end
ns.PlannerDuoTick = Tick
ns:Every(0.25, "Planner duo", Tick)

-- The prefix, registered once, when the guide is unlocked.
local registered = false
function ns.PlannerDuoRegister()
    if registered or not ns:GuideUnlocked() then return end
    local chat = C_ChatInfo
    if type(chat) == "table" and chat.RegisterAddonMessagePrefix then registered = pcall(chat.RegisterAddonMessagePrefix, PREFIX) end
end

do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "CHAT_MSG_ADDON", "PLAYER_LOGIN" }) do pcall(ev.RegisterEvent, ev, e) end
    local OnEvent = ns:Guard("Planner duo", function(_, event, prefix, msg, channel, sender)
        if event == "PLAYER_LOGIN" then ns.PlannerDuoRegister(); return end
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

-- Unlocking registers the prefix; locking ends the duo at once, sending nothing.
for _, name in ipairs({ "GuideUnlock", "GuideLock" }) do
    local original = ns[name]
    if type(original) == "function" then
        ns[name] = function(...)
            local a, b = original(...)
            if ns:GuideUnlocked() then ns.PlannerDuoRegister() else Reset() end
            return a, b
        end
    end
end

local function Planned()
    local st = ns.GuideState and ns.GuideState()
    return type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED
end
ns.GuideRegisterAction("panel", "duo", function() return ns.plannerDuo and "Stop planning together" or "Plan with a friend" end, function()
    if ns.plannerDuo then ns:PlannerDuoEnd("off") else ns:PlannerDuoStart() end
end, function() return ns:GuideUnlocked() and Planned() end)
ns.GuideRegisterCommand("duo", function(rest)
    rest = ns.Trim(Str(rest) or "")
    if rest:lower() == "off" then
        if not ns:PlannerDuoEnd("off") then ns:Print("You are not planning with a friend.") end
        return true
    end
    return ns:PlannerDuoStart(rest ~= "" and rest or nil)
end)
