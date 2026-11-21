local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner source: where the route planner learns which quests exist. Questie (when it is loaded,
-- ready and still speaks the contract this was written for) is read through pcall; otherwise the
-- quest log alone is used. Either way the planner receives plain records and never sees Questie.
------------------------------------------------------------------------------------------
ns.PLANNER_CONTRACT = "4"

local pcall, type, pairs, ipairs, tonumber = pcall, type, pairs, ipairs, tonumber
local waiting = false

-- Run f; true plus its results, or false.
local function Try(f, ...) return pcall(f, ...) end

local function Import(name)
    local L = _G.QuestieLoader
    if not (L and L.ImportModule) then return nil end
    local ok, mod = Try(L.ImportModule, L, name)
    if ok and type(mod) == "table" then return mod end
end

local function IsLoaded()
    return C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Questie") and true or false
end

local function Spots(db, zones, npcId)
    local out = {}
    local spawns = db.QueryNPCSingle(npcId, "spawns")
    if type(spawns) ~= "table" then return out end
    for area, list in pairs(spawns) do
        local map = zones:GetUiMapIdByAreaId(area)
        if map and type(list) == "table" then
            for _, p in ipairs(list) do
                if type(p) == "table" and tonumber(p[1]) and tonumber(p[2]) and not (p[1] == -1 and p[2] == -1) then
                    out[#out + 1] = { map = map, x = p[1], y = p[2] }
                end
            end
        end
    end
    return out
end

local function Merge(into, from) for _, s in ipairs(from) do into[#into + 1] = s end end

local function Level(db, id)
    local lv = db.QueryNPCSingle(id, "maxLevel") or db.QueryNPCSingle(id, "minLevel")
    return tonumber(lv)
end

-- One objective from an NPC list (kill credit) or the NPCs that drop an item.
local function NpcObjective(db, zones, ids, state)
    local o = { kind = "kill", spots = {} }
    for _, npc in ipairs(ids) do
        Merge(o.spots, Spots(db, zones, npc))
        local lv = Level(db, npc)
        if lv and (not o.mobLevel or lv > o.mobLevel) then o.mobLevel = lv end
        local rank = tonumber(db.QueryNPCSingle(npc, "rank"))
        if rank == 1 or rank == 2 then state.elite = true end
    end
    return o
end

local function Objectives(db, zones, quest, state)
    local out, raw = {}, quest.objectives
    if type(raw) == "table" then
        for _, e in ipairs(type(raw[1]) == "table" and raw[1] or {}) do
            out[#out + 1] = NpcObjective(db, zones, { e[1] }, state)
        end
        for _, e in ipairs(type(raw[5]) == "table" and raw[5] or {}) do
            local ids = type(e[1]) == "table" and e[1] or { e[2] }
            out[#out + 1] = NpcObjective(db, zones, ids, state)
        end
        for _, e in ipairs(type(raw[3]) == "table" and raw[3] or {}) do
            local drops = db.QueryItemSingle and db.QueryItemSingle(e[1], "npcDrops")
            local o = NpcObjective(db, zones, type(drops) == "table" and drops or {}, state)
            o.kind = "item"
            out[#out + 1] = o
        end
        for _, e in ipairs(type(raw[2]) == "table" and raw[2] or {}) do
            out[#out + 1] = { kind = "other", spots = {} }
        end
    end
    local trig = quest.triggerEnd
    if type(trig) == "table" then
        local o = { kind = "place", count = 1, countKnown = true, spots = {} }
        for area, list in pairs(type(trig[2]) == "table" and trig[2] or {}) do
            local map = zones:GetUiMapIdByAreaId(area)
            if map and type(list) == "table" then
                for _, p in ipairs(list) do o.spots[#o.spots + 1] = { map = map, x = p[1], y = p[2] } end
            end
        end
        out[#out + 1] = o
    end
    -- Questie has no kill counts: the quest log has them, for a quest being worked on.
    local logged = C_QuestLog and C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(quest.Id or 0)
        and C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(quest.Id)
    for i, o in ipairs(out) do
        local n = o.kind ~= "place" and type(logged) == "table" and type(logged[i]) == "table" and tonumber(logged[i].numRequired)
        if n and n > 0 then o.count, o.countKnown = n, true
        elseif o.kind ~= "place" then o.count, o.countKnown = nil, false end
    end
    return out
end

local function Ids(list) return type(list) == "table" and list or {} end

-- Group and dungeon from a quest-log tag (Enum.QuestTag names; the client supplies the numbers).
local function TagKinds(tagID)
    local T = Enum and Enum.QuestTag
    if type(T) ~= "table" or tagID == nil then return false, false end
    local group = tagID == T.Group or tagID == T.Raid or tagID == T.Raid10 or tagID == T.Raid25
    return group and true or false, (T.Dungeon ~= nil and tagID == T.Dungeon) or false
end

local function Tags(id, quest, db, zones, state)
    local elite, group, dungeon = state.elite
    local info = C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetLogIndexForQuestID
        and C_QuestLog.GetLogIndexForQuestID(id) and C_QuestLog.GetQuestTagInfo(id)
    if type(info) == "table" then
        elite = elite or info.isElite or false
        group, dungeon = TagKinds(info.tagID)
    else
        local function Ask(name)
            if type(db[name]) ~= "function" then return false end
            local ok, v = Try(db[name], id)
            return ok and v and true or false
        end
        group = Ask("IsGroupQuest") or Ask("IsRaidQuest")
        dungeon = Ask("IsDungeonQuest")
        local sort = tonumber(quest.zoneOrSort)
        if not dungeon and sort and sort > 0 and zones.IsDungeonZone then
            local ok, d = Try(zones.IsDungeonZone, sort)
            dungeon = ok and d and true or false
        end
    end
    return elite and true or false, group, dungeon
end

-- A Questie quest as a plain record, or nil when it cannot be placed on a known map.
local function Record(env, id)
    local db, zones, xpMod = env.db, env.zones, env.xp
    local quest = db.GetQuest(id)
    if type(quest) ~= "table" then return nil end
    local by = type(quest.startedBy) == "table" and quest.startedBy or {}
    local fin = type(quest.finishedBy) == "table" and quest.finishedBy or {}
    local starts, ends = {}, {}
    for _, npc in ipairs(Ids(by[1])) do Merge(starts, Spots(db, zones, npc)) end
    if #starts == 0 then return nil end
    for _, npc in ipairs(Ids(fin[1])) do Merge(ends, Spots(db, zones, npc)) end
    local state = {}
    local objectives = Objectives(db, zones, quest, state)
    local elite, group, dungeon = Tags(id, quest, db, zones, state)
    local repeatable = tonumber(quest.specialFlags) and tonumber(quest.specialFlags) % 2 == 1 or false
    return {
        id = id, name = quest.name or ("Quest " .. id),
        level = tonumber(quest.level) or tonumber(quest.questLevel) or 1,
        minLevel = tonumber(quest.requiredLevel) or 1,
        xp = tonumber(xpMod:GetQuestLogRewardXP(id)) or 0,
        starts = starts, ends = ends, objectives = objectives,
        pre = Ids(quest.preQuestGroup), preAny = Ids(quest.preQuestSingle), exclusive = Ids(quest.exclusiveTo),
        nextQuest = tonumber(quest.nextQuestInChain) and quest.nextQuestInChain > 0 and quest.nextQuestInChain or nil,
        elite = elite, group = group, dungeon = dungeon, repeatable = repeatable,
        doable = db.IsDoable(id) and true or false,
    }
end

local changed = false

-- Has `flags` the single bit `mask`? (bit.band when the client has it, else plain arithmetic.)
local function HasFlag(flags, mask)
    flags, mask = tonumber(flags), tonumber(mask)
    if not (flags and mask and mask > 0) then return false end
    local band = type(bit) == "table" and bit.band
    if type(band) == "function" then
        local ok, r = pcall(band, flags, mask)
        if ok and type(r) == "number" then return r == mask end
    end
    return math.floor(flags / mask) % 2 == 1
end

-- The ids in one of Questie's pointer tables. They are maps keyed by id (the values may be offsets
-- into its data, not ids); only a plain sequence of numbers is read as a list of ids.
local function PointerIds(t)
    local out, n = {}, #t
    if n > 0 and t[1] ~= nil then
        local count, numbers = 0, true
        for _, v in pairs(t) do
            count = count + 1
            if type(v) ~= "number" then numbers = false end
        end
        if count == n and numbers then
            for i = 1, n do out[i] = t[i] end
            return out
        end
    end
    for k in pairs(t) do if type(k) == "number" then out[#out + 1] = k end end
    return out
end

-- Every innkeeper Questie knows, { name, map, x, y } per spawn; gathered once per session.
local innCache
local function Inns(env)
    if innCache then return innCache end
    local db, zones, out = env.db, env.zones, {}
    local flagsOk, flags = Try(function() return db.npcFlags end)
    local mask = flagsOk and type(flags) == "table" and tonumber(flags.INNKEEPER)
    local okP, pointers = Try(function() return db.NPCPointers end)
    if not (mask and okP and type(pointers) == "table") then innCache = out; return out end
    local okI, ids = Try(PointerIds, pointers)
    for _, id in ipairs(okI and ids or {}) do
        ns.PlannerYield()
        local ok, f = Try(db.QueryNPCSingle, id, "npcFlags")
        if ok and HasFlag(f, mask) then
            local okN, name = Try(db.QueryNPCSingle, id, "name")
            local okS, spots = Try(Spots, db, zones, id)
            if okN and type(name) == "string" and okS then
                for _, sp in ipairs(spots) do out[#out + 1] = { name = name, map = sp.map, x = sp.x, y = sp.y } end
            end
        end
    end
    innCache = out
    return out
end

-- Questie as a source, or nil and why: "missing", "waiting" (not ready yet), "changed".
function ns.PlannerSource()
    if not IsLoaded() then return nil, "missing" end
    local Q = _G.Questie
    local api = type(Q) == "table" and Q.API
    if type(api) ~= "table" or type(api.RegisterOnReady) ~= "function" then return nil, "changed" end
    if api.isReady then waiting = false else
        if not waiting then
            waiting = true
            local ok = Try(api.RegisterOnReady, function()
                waiting = false
                if ns.PlannerReplan then ns.PlannerReplan(ns, "questie") end
            end)
            if not ok then waiting = false; return nil, "changed" end
        end
        return nil, "waiting"
    end
    if changed then changed = false; return nil, "changed" end -- told once; the next check starts fresh
    local meta = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Questie", "X-QuestieDB-Contract")
    if meta ~= ns.PLANNER_CONTRACT then return nil, "changed" end
    local env = { db = Import("QuestieDB"), xp = Import("QuestXP"), zones = Import("ZoneDB") }
    if not (env.db and env.xp and env.zones) then return nil, "changed" end
    if type(env.db.QuestPointers) ~= "table" or type(env.db.GetQuest) ~= "function"
        or type(env.db.IsDoable) ~= "function" or type(env.db.QueryNPCSingle) ~= "function"
        or type(env.xp.GetQuestLogRewardXP) ~= "function" or type(env.zones.GetUiMapIdByAreaId) ~= "function" then
        return nil, "changed"
    end
    local src = { kind = "questie" }
    function src.ids()
        local ok, out = Try(PointerIds, env.db.QuestPointers)
        if ok then return out end
        changed = true
        return {}
    end
    function src.quest(id)
        local ok, rec = Try(Record, env, id)
        if ok then return rec end
        changed = true
        return nil
    end
    function src.inns() return Inns(env) end
    return src
end

-- The quest log alone: only quests being worked on, with where each ends.
function ns.PlannerLogSource()
    local src = { kind = "log" }
    function src.ids()
        local out = {}
        local QL = C_QuestLog
        if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo) then return out end
        for i = 1, (QL.GetNumQuestLogEntries()) do
            local info = QL.GetInfo(i)
            if type(info) == "table" and not info.isHeader and info.questID then out[#out + 1] = info.questID end
        end
        return out
    end
    function src.quest(id)
        local QL = C_QuestLog
        if not (QL and QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(id)) then return nil end
        local info = QL.GetInfo and QL.GetInfo(QL.GetLogIndexForQuestID(id))
        local ends = {}
        if QL.GetNextWaypoint then
            local map, x, y = QL.GetNextWaypoint(id)
            if map and x and y then ends[1] = { map = map, x = x * 100, y = y * 100 } end
        end
        local tag = QL.GetQuestTagInfo and QL.GetQuestTagInfo(id)
        local group, dungeon = TagKinds(type(tag) == "table" and tag.tagID or nil)
        return {
            id = id, name = (QL.GetTitleForQuestID and QL.GetTitleForQuestID(id)) or (info and info.title) or ("Quest " .. id),
            level = info and info.questLevel or 1, minLevel = 1, xp = 0,
            starts = {}, ends = ends, objectives = {}, pre = {}, preAny = {}, exclusive = {},
            elite = type(tag) == "table" and tag.isElite or false, group = group,
            dungeon = dungeon,
            repeatable = false, doable = true,
        }
    end
    function src.inns() return {} end
    return src
end

function ns.PlannerSourceReset() changed, waiting, innCache = false, false, nil end
