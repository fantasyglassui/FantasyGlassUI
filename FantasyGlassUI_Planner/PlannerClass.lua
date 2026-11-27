local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- Class quests on time (13.5): a heads-up a level or two before an "always" class quest's level, once in chat
-- and on the panel while it applies, and the hold: in that window, while you stand on the start's continent,
-- the route does not fly away from it. (The trip itself, at the quest's level, is the route's lead-in:
-- PlannerRoute.lua, hub.classDue; the quests it needs first: Planner.lua, ctx.classPre.)

local ipairs, type, tonumber, pcall = ipairs, type, tonumber, pcall
local huge = math.huge

ns.PLANNER_CLASS_LEAD_NEAR = 1           -- levels of heads-up when the start is near
ns.PLANNER_CLASS_LEAD_FAR = 2            -- ... when it is on another continent, or farther than:
ns.PLANNER_CLASS_FAR_SECONDS = 600       -- seconds of travel (R11)

local function NO() return false end

-- A number from the game that can be compared (nil when hidden).
local function Num(v)
    if v == nil or ns:IsSecret(v) then return nil end
    return tonumber(v)
end

-- The start map's name (C_Map.GetMapInfo, pcall'd), or nil.
local function MapName(map)
    local get = C_Map and C_Map.GetMapInfo
    if type(get) ~= "function" or type(map) ~= "number" then return nil end
    local ok, info = pcall(get, map)
    if not ok or type(info) ~= "table" then return nil end
    local name = info.name
    if ns:IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
    return name
end

-- The first start of a record that can be placed: spot, continent.
local function Start(rec)
    for _, s in ipairs(type(rec.starts) == "table" and rec.starts or {}) do
        if type(s) == "table" then
            local c = Num((ns.PlannerWorldPos(s.map, s.x, s.y)))
            if c ~= nil then return s, c end
        end
    end
end

-- Where you stand: the spot and its continent, or nil.
local function Here(ctx)
    local h = ctx.here
    if type(h) ~= "table" or not (h.map and h.x and h.y) then return nil end
    return h, Num((ns.PlannerWorldPos(h.map, h.x, h.y)))
end

-- The heads-up: the lowest-level "always" class quest with level < its level <= level + lead (lead 2 when its start
-- is on another continent, farther than PLANNER_CLASS_FAR_SECONDS or where you stand is unknown; else 1), not done,
-- not in your log, not on the skip list, whose record exists, is doable and has a start that can be placed and named.
-- { id, level, name, start, lead, c, map, x, y } or nil. (Ties of level: the lower id.)
-- check in game: Questie's IsDoable for a class quest below its level (the heads-up needs rec.doable then).
function ns.PlannerClassSoon(ctx)
    if type(ctx) ~= "table" or type(ctx.classQuests) ~= "table" then return nil end
    local src = ctx.source
    if type(src) ~= "table" or type(src.quest) ~= "function" then return nil end
    local level = tonumber(ctx.level) or 1
    local done = type(ctx.done) == "function" and ctx.done or NO
    local onQuest = type(ctx.onQuest) == "function" and ctx.onQuest or NO
    local skip = type(ctx.skip) == "table" and ctx.skip or {}
    local list = {}
    for _, e in ipairs(ctx.classQuests) do
        local lv = type(e) == "table" and tonumber(e.level)
        if lv and type(e.id) == "number" and e.kind == "always" and lv > level and lv <= level + ns.PLANNER_CLASS_LEAD_FAR then list[#list + 1] = e end
    end
    if #list == 0 then return nil end
    table.sort(list, function(a, b)
        local la, lb = tonumber(a.level), tonumber(b.level)
        if la ~= lb then return la < lb end
        return a.id < b.id
    end)
    local here, hc
    for _, e in ipairs(list) do
        ns.PlannerYield()
        local id = e.id
        if not skip[id] and not done(id) and not onQuest(id) then
            local rec = src.quest(id)
            if type(rec) == "table" and rec.doable then
                local spot, c = Start(rec)
                local start = spot and MapName(spot.map)
                if spot and start then
                    if here == nil then here, hc = Here(ctx); here = here or false end
                    local lead = ns.PLANNER_CLASS_LEAD_FAR
                    if here and hc ~= nil and hc == c then
                        local secs = ns.PlannerTravel(here, spot, ctx)
                        secs = type(secs) == "number" and secs or huge
                        if secs <= ns.PLANNER_CLASS_FAR_SECONDS then lead = ns.PLANNER_CLASS_LEAD_NEAR end
                    end
                    local lv = tonumber(e.level)
                    if lv <= level + lead then
                        local name = rec.name
                        if ns:IsSecret(name) or type(name) ~= "string" then name = nil end
                        return { id = id, level = lv, name = name, start = start, lead = lead, c = c, map = spot.map, x = spot.x, y = spot.y }
                    end
                end
            end
        end
    end
    return nil
end

-- "context": the heads-up, and the hold while you stand on its start's continent (R12).
ns.PlannerHook("context", "classSoon", function(ctx)
    ctx.classSoon = ns.PlannerClassSoon(ctx)
    ctx.classHold = nil
    local s = ctx.classSoon
    if s then
        local _, hc = Here(ctx)
        if hc ~= nil and hc == s.c then ctx.classHold = { c = s.c, id = s.id, level = s.level } end
    end
end)

-- "route": the summary carries it (the panel's line and the chat line read it).
ns.PlannerHook("route", "classSoon", function(_, summary, ctx)
    local s = type(ctx) == "table" and ctx.classSoon or nil
    if type(summary) == "table" and type(s) == "table" then summary.classSoon = { id = s.id, level = s.level, start = s.start } end
end)

-- "rank": during the hold a hub on another continent (a dungeon too) is left out, unless it holds the quest held for.
ns.PlannerHook("rank", "classHold", function(ranked, c)
    local hold = type(c) == "table" and type(c.classHold) == "table" and c.classHold or nil
    if not hold then return end
    for _, e in ipairs(ranked) do
        ns.PlannerYield()
        local hub = type(e) == "table" and e.hub or nil
        if type(hub) == "table" then
            local hc = Num((ns.PlannerWorldPos(hub.map, hub.x, hub.y)))
            if hc ~= nil and hc ~= hold.c then
                local holds = false
                for _, q in ipairs(type(hub.quests) == "table" and hub.quests or {}) do
                    if type(q) == "table" and q.id == hold.id then holds = true; break end
                end
                if not holds then e.score = -1 end
            end
        end
    end
end)

-- "applied": said in chat once per character and quest (root.planner[key].classTold[id]). Added once the folder has
-- loaded, so it runs after the earlier files' hooks (the map's drawing comes first).
local function Told(_, summary)
    local s = type(summary) == "table" and summary.classSoon or nil
    if type(s) ~= "table" or type(s.id) ~= "number" then return end
    if ns.db and ns.db.plannerClassQuests == false then return end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
    if type(rec) ~= "table" then return end
    if type(rec.classTold) ~= "table" then rec.classTold = {} end
    if rec.classTold[s.id] then return end
    ns:Print("Your level %d class quest is coming: it starts in %s.", s.level, s.start)
    rec.classTold[s.id] = true
end
if ns.FolderLate then
    ns.FolderLate("planner", "classSoon", function() ns.PlannerHook("applied", "classSoon", Told) end)
else
    ns.PlannerHook("applied", "classSoon", Told)
end

ns.FolderFileDone("planner", "PlannerClass.lua")
