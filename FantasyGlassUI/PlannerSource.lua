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

-- How many of a thing a quest wants: a count in the entry, or "slain: 3/8" / "Kill 8 ..." in its text.
local function CountOf(entry, countAt)
    local n = tonumber(entry.count or entry[countAt])
    if n and n > 0 then return n end
    local text = entry[2]
    if type(text) == "string" then
        n = tonumber(text:match("%d+%s*/%s*(%d+)")) or tonumber(text:match("^%D-(%d+)"))
        if n and n > 0 then return n end
    end
    return 1
end

local function Level(db, id)
    local lv = db.QueryNPCSingle(id, "maxLevel") or db.QueryNPCSingle(id, "minLevel")
    return tonumber(lv)
end

-- One objective from an NPC list (kill credit) or the NPCs that drop an item.
local function NpcObjective(db, zones, ids, count, state)
    local o = { kind = "kill", count = count, spots = {} }
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
            out[#out + 1] = NpcObjective(db, zones, { e[1] }, CountOf(e, 4), state)
        end
        for _, e in ipairs(type(raw[5]) == "table" and raw[5] or {}) do
            local ids = type(e[1]) == "table" and e[1] or { e[2] }
            out[#out + 1] = NpcObjective(db, zones, ids, CountOf(e, 5), state)
        end
        for _, e in ipairs(type(raw[3]) == "table" and raw[3] or {}) do
            local drops = db.QueryItemSingle and db.QueryItemSingle(e[1], "npcDrops")
            local o = NpcObjective(db, zones, type(drops) == "table" and drops or {}, CountOf(e, 4), state)
            o.kind = "item"
            out[#out + 1] = o
        end
        for _, e in ipairs(type(raw[2]) == "table" and raw[2] or {}) do
            out[#out + 1] = { kind = "other", count = CountOf(e, 4), spots = {} }
        end
    end
    local trig = quest.triggerEnd
    if type(trig) == "table" then
        local o = { kind = "place", count = 1, spots = {} }
        for area, list in pairs(type(trig[2]) == "table" and trig[2] or {}) do
            local map = zones:GetUiMapIdByAreaId(area)
            if map and type(list) == "table" then
                for _, p in ipairs(list) do o.spots[#o.spots + 1] = { map = map, x = p[1], y = p[2] } end
            end
        end
        out[#out + 1] = o
    end
    return out
end

local function Ids(list) return type(list) == "table" and list or {} end

local function Tags(id, quest, zones, state)
    local elite, group, dungeon = state.elite, false, false -- group: only the quest log says
    local info = C_QuestLog and C_QuestLog.GetQuestTagInfo and C_QuestLog.GetLogIndexForQuestID
        and C_QuestLog.GetLogIndexForQuestID(id) and C_QuestLog.GetQuestTagInfo(id)
    if type(info) == "table" then
        elite = elite or info.isElite or false
        group = info.tagID == 1 or false
        dungeon = info.tagID == 81 or false
    else
        local sort = tonumber(quest.zoneOrSort)
        if sort and sort > 0 and zones.IsDungeonZone then
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
    local elite, group, dungeon = Tags(id, quest, zones, state)
    local repeatable = tonumber(quest.specialFlags) and tonumber(quest.specialFlags) % 2 == 1 or false
    return {
        id = id, name = quest.name or ("Quest " .. id),
        level = tonumber(quest.questLevel or quest.level) or 1,
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

-- Questie as a source, or nil and why: "missing", "waiting" (not ready yet), "changed".
function ns.PlannerSource()
    if not IsLoaded() then return nil, "missing" end
    local Q = _G.Questie
    local api = type(Q) == "table" and Q.API
    if type(api) ~= "table" or type(api.RegisterOnReady) ~= "function" then return nil, "changed" end
    if not api.isReady then
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
    local meta = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("Questie", "X-QuestieDB-Contract")
    if meta ~= ns.PLANNER_CONTRACT then return nil, "changed" end
    local env = { db = Import("QuestieDB"), xp = Import("QuestXP"), zones = Import("ZoneDB") }
    if not (env.db and env.xp and env.zones) then return nil, "changed" end
    if type(env.db.QuestPointers) ~= "table" or type(env.db.GetQuest) ~= "function"
        or type(env.db.IsDoable) ~= "function" or type(env.db.QueryNPCSingle) ~= "function"
        or type(env.xp.GetQuestLogRewardXP) ~= "function" or type(env.zones.GetUiMapIdByAreaId) ~= "function" then
        return nil, "changed"
    end
    if changed then return nil, "changed" end
    local src = { kind = "questie" }
    function src.ids()
        local out = {}
        for k, v in pairs(env.db.QuestPointers) do
            local id = type(v) == "number" and v or k
            if type(id) == "number" then out[#out + 1] = id end
        end
        return out
    end
    function src.quest(id)
        local ok, rec = Try(Record, env, id)
        if ok then return rec end
        changed = true
        return nil
    end
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
        return {
            id = id, name = (QL.GetTitleForQuestID and QL.GetTitleForQuestID(id)) or (info and info.title) or ("Quest " .. id),
            level = info and info.questLevel or 1, minLevel = 1, xp = 0,
            starts = {}, ends = ends, objectives = {}, pre = {}, preAny = {}, exclusive = {},
            elite = type(tag) == "table" and tag.isElite or false, group = type(tag) == "table" and tag.tagID == 1 or false,
            dungeon = type(tag) == "table" and tag.tagID == 81 or false,
            repeatable = false, doable = true,
        }
    end
    return src
end
