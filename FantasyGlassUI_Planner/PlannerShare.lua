local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- 13.5: the shared averages (PlannerSharedTimes.lua, made from the codes players sent with Share my times) for a
-- quest, a level, a flight or a crossing the player has no record of yet. The planner asks here only when its own
-- record is missing. (Share my times itself, and what is kept for it: PlannerLearn.lua, in the main add-on.)
------------------------------------------------------------------------------------------
local type, tonumber = type, tonumber
local TABLE_OF = { quest = "quests", flight = "flights", boat = "crossings" }

-- seconds, or nil. kind: "quest" (key: the quest's id), "level" (the level, for `class`, a class token),
-- "flight" (key: "from-to" node numbers) or "boat" (the crossing's id).
function ns.PlannerSharedTime(kind, key, class)
    local S = ns.PLANNER_SHARED_TIMES
    if type(S) ~= "table" or key == nil then return nil end
    local t
    if kind == "level" then
        t = type(class) == "string" and type(S.levels) == "table" and S.levels[class]
    else
        t = TABLE_OF[kind] and S[TABLE_OF[kind]]
    end
    local v = type(t) == "table" and tonumber(t[key])
    if v and v > 0 and v < 1e9 then return v end
    return nil
end
ns.FolderFileDone("planner", "PlannerShare.lua")
