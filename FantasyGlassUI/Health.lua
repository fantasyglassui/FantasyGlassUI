local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: the check after a game update. At login, when the game's build has changed, every part whose needs
-- (HealthNeeds.lua) are missing is left off for the session (ns.healthOff), and /fgui health runs it on demand.
-- (A stand-in for now: its task replaces it.)
------------------------------------------------------------------------------------------
function ns:HealthLogin() end
function ns:HealthCommand(text) return 0 end
