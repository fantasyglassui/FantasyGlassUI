local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- 13.5: the averages of the times players shared (Share my times), made by the maintainer's script in tools/.
-- Empty until codes come in. (Read through ns.PlannerSharedTime, PlannerShare.lua.)
------------------------------------------------------------------------------------------
ns.PLANNER_SHARED_TIMES = { made = "", codes = 0, quests = {}, levels = {}, flights = {}, crossings = {} }
ns.FolderFileDone("planner", "PlannerSharedTimes.lua")
