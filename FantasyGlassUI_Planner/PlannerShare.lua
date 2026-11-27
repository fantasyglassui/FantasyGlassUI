local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- 13.5: Share my times (the planner window), and the shared averages (PlannerSharedTimes.lua) for a quest,
-- a level, a flight or a crossing the player has no record of yet.
-- (A stand-in for now: its task replaces it.)
------------------------------------------------------------------------------------------
function ns.PlannerSharedTime(kind, key, class) return nil end
ns.FolderFileDone("planner", "PlannerShare.lua")
