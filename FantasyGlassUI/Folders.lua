local _, ns = ...

------------------------------------------------------------------------------------------
-- Folders: the route planner and the gold advisor live in two load-on-demand folders,
-- FantasyGlassUI_Planner and FantasyGlassUI_Gold, which the game loads only when one is first used,
-- and never while the guide is locked. A locked player never loads either, sees no new text anywhere,
-- and has the Tools menu, launcher tooltip, /fgui replies and guide panel of before.
--
-- Here, in the main add-on: the loader (ns:LoadFolder), the stand-ins that load a folder and hand the
-- call on (as ns.optionsStubs do for the options folder), the ways in that must answer before a folder
-- is loaded (the launcher, the auction house, /fgui guide gold and the planner's command words), the
-- login load while you follow the plan, and the "file done" handshake that tells a folder that loaded
-- whole from one where a file stopped part way.
--
-- Each folder file starts with `local ns = _G.FantasyGlassUI` and ends with
-- ns.FolderFileDone("<key>", "<File>.lua"). A folder file never registers PLAYER_LOGIN: it may be loaded
-- long after it. Its login work is ns.FolderLate(key, name, fn), run once right after the load.
------------------------------------------------------------------------------------------
local type, pairs, ipairs, tostring, pcall = type, pairs, ipairs, tostring, pcall

-- Folder seams (what the main add-on calls in the folders):
--   GoldAuctionShow
--   GoldLockedNow
--   GoldOpen
--   PlannerAdviceLines
--   PlannerCatchUp
--   PlannerDuoEvent
--   PlannerDuoPartner
--   PlannerDuoRole
--   PlannerExploreReached
--   PlannerGoldText
--   PlannerInnSuggest
--   PlannerIntro
--   PlannerIntroDue
--   PlannerKnownFactions
--   PlannerNoteFailed
--   PlannerOpen
--   PlannerPlaces
--   PlannerPlanCommand
--   PlannerRepGoals
--   PlannerRepName
--   PlannerRepNeeded
--   PlannerRepStandingName
--   PlannerReplan
--   PlannerRiding
--   PlannerSailText
--   PlannerSessionSkip
--   PlannerSetRepGoal
--   PlannerSkip
--   PlannerSkipList
--   PlannerSource
--   PlannerStart
--   PlannerStop
--   PlannerUnspentTalents
--   PlannerYield
-- end of folder seams
-- (Every ns.Planner* and ns.Gold* that a file of FantasyGlassUI/ or FantasyGlassUI_Options/ uses and that is not
-- defined in FantasyGlassUI/ by name: each is defined in a folder file. A call site checks it is there first, or it
-- is one of the stand-ins below, which load the folder: GoldAuctionShow, GoldOpen, PlannerOpen, PlannerStart. A stand-in
-- whose folder function is still to come (PlannerOpen: the planner window, group C) hands back nil until then.
-- tests/test_addon.py::test_folder_seams_listed keeps this list true.)

ns.FOLDERS = {
    planner = { addon = "FantasyGlassUI_Planner", files = {
        "PlannerSource.lua", "Planner.lua", "PlannerRoute.lua", "PlannerStops.lua", "PlannerPath.lua", "PlannerAdvice.lua",
        "PlannerMap.lua", "PlannerPages.lua", "PlannerPace.lua", "PlannerRecords.lua", "PlannerGroup.lua", "PlannerDuo.lua",
        "PlannerCode.lua", "PlannerIntro.lua", "PlannerWindow.lua", "PlannerGo.lua",
    },
        broken = "The planner could not start: /fgui check lists why.",
        missing = "The planner could not be opened (%s). It is in a folder, FantasyGlassUI_Planner, which must sit beside FantasyGlassUI in Interface/AddOns and be enabled." },
    gold = { addon = "FantasyGlassUI_Gold", files = {
        "Gold.lua", "GoldSell.lua", "GoldFarm.lua", "GoldGather.lua", "GoldCraft.lua",
    },
        broken = "Ways to make gold could not start: /fgui check lists why.",
        missing = "Ways to make gold could not be opened (%s). It is in a folder, FantasyGlassUI_Gold, which must sit beside FantasyGlassUI in Interface/AddOns and be enabled." },
}
ns.folderReady, ns.folderBroken = {}, {}

local done, late, loading, said = {}, {}, {}, {}
local WARN_EVERY = 10                  -- seconds between two of a folder's messages

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function Now()
    local ok, t = pcall(GetTime)
    return (ok and type(t) == "number" and not ns:IsSecret(t)) and t or 0
end
local function Note(text)
    if type(ns.errors) == "table" and #ns.errors < 60 then ns.errors[#ns.errors + 1] = text end
end
-- A folder's message: once, then at most every 10 s (only an unlocked player ever gets this far).
local function Say(key, text, ...)
    local at = said[key]
    if at and Now() - at < WARN_EVERY then return end
    said[key] = Now()
    ns:Print("|cffff4444" .. ns:Tr(text) .. "|r", ...)
end

-- A folder file finished (its last line).
function ns.FolderFileDone(key, file)
    if type(key) ~= "string" or type(file) ~= "string" then return end
    done[key] = done[key] or {}
    done[key][file] = true
end
-- Work a folder file did at login: run once, through pcall, right after the folder loaded (at once when it already has).
function ns.FolderLate(key, name, fn)
    if type(key) ~= "string" or type(fn) ~= "function" then return end
    if ns.folderReady[key] then
        local ok, err = pcall(fn)
        if not ok then Note("Folder " .. key .. " " .. tostring(name) .. ": " .. tostring(err)) end
        return
    end
    late[key] = late[key] or {}
    local list = late[key]
    list[#list + 1] = { name = name, fn = fn }
end
local function RunLate(key)
    local list = late[key] or {}
    late[key] = nil
    for _, e in ipairs(list) do
        local ok, err = pcall(e.fn)
        if not ok then Note("Folder " .. key .. " " .. tostring(e.name) .. ": " .. tostring(err)) end
    end
end

-- Load a folder ("planner" or "gold"). True when it is ready. Never while the guide is locked, before the
-- login, or in a fight ("Not during a fight.", unless `quiet`: an automatic load says nothing).
function ns:LoadFolder(key, quiet)
    local f = ns.FOLDERS[key]
    if type(f) ~= "table" then return false end
    if ns.folderReady[key] then return true end
    if not Unlocked() then return false end
    if type(IsLoggedIn) == "function" then
        local ok, v = pcall(IsLoggedIn)
        if not (ok and ns.Yes(v)) then return false end
    end
    if ns.Yes(InCombatLockdown()) then
        if not quiet then ns:Print("Not during a fight.") end
        return false
    end
    if ns.folderBroken[key] then Say(key, f.broken or "It could not start: /fgui check lists why."); return false end
    if loading[key] then return false end
    loading[key] = true
    local load = C_AddOns and C_AddOns.LoadAddOn
    local reason, loaded = "this game client cannot load an add-on on request", false
    if type(load) == "function" then
        local ok, yes, why = pcall(load, f.addon)
        if ok and not yes and why == "DISABLED" then          -- switched off in the add-on list: switch it on and try again
            local enable = C_AddOns.EnableAddOn
            if type(enable) == "function" then
                pcall(enable, f.addon)
                ok, yes, why = pcall(load, f.addon)
            end
        end
        loaded = ok and yes and true or false
        reason = ok and (type(why) == "string" and why or "it did not finish loading") or tostring(yes)
    end
    loading[key] = nil
    if not loaded then
        Say(key, f.missing or ("It could not be opened (%s). It is in a folder, " .. tostring(f.addon) .. ", which must sit beside FantasyGlassUI in Interface/AddOns and be enabled."), reason)
        return false
    end
    local stopped = {}
    for _, file in ipairs(f.files or {}) do
        if not (done[key] and done[key][file]) then stopped[#stopped + 1] = file end
    end
    if #stopped > 0 then                                       -- (a file stopped part way: the folder is not used, the guide works as before)
        ns.folderBroken[key] = stopped
        Note("Folder " .. key .. ": " .. table.concat(stopped, ", ") .. " did not load")
        Say(key, f.broken or "It could not start: /fgui check lists why.")
        return false
    end
    ns.folderReady[key] = true
    RunLate(key)
    -- (the game may load another folder with it, an optional dependency: every folder whose files all finished is
    -- ready now, and does its late work at once, not at its first use)
    for other, g in pairs(ns.FOLDERS) do
        if not ns.folderReady[other] and not ns.folderBroken[other] and type(g) == "table" and type(g.files) == "table" and #g.files > 0 then
            local all = true
            for _, file in ipairs(g.files) do if not (done[other] and done[other][file]) then all = false end end
            if all then ns.folderReady[other] = true; RunLate(other) end
        end
    end
    return true
end
function ns:LoadPlanner(quiet) return ns:LoadFolder("planner", quiet) end
function ns:LoadGold(quiet) return ns:LoadFolder("gold", quiet) end

-- Stand-ins: each loads its folder and hands the call on (nil when the folder is not there). (FOLDER_STUBS is read by
-- tests/folder_stubs.py, for forever_audit.py and the seam test: keep it one table of quoted names.)
local FOLDER_STUBS = {
    planner = { "PlannerStart", "PlannerOpen", "PlannerCatchUp" },
    gold = { "GoldOpen", "GoldAuctionShow" },
}
ns.folderStubs = {}
for key, names in pairs(FOLDER_STUBS) do
    for _, name in ipairs(names) do
        local stub
        stub = function(self, ...)
            if not ns:LoadFolder(key) or ns[name] == stub then return nil end
            return ns[name](self, ...)
        end
        ns[name], ns.folderStubs[name] = stub, stub
    end
end

-- The planner's /fgui guide words: the first one loads the folder, whose own command then takes the word
-- over (it registers it as it loads) and gets the call. A word the folder does not take returns false.
do
    local busy = {}
    for _, word in ipairs({ "duo", "share", "keys", "plan" }) do
        ns.GuideRegisterCommand(word, function(rest)
            if busy[word] or not ns:LoadPlanner() then return false end
            busy[word] = true
            local ok, v = pcall(ns.GuideCommand, ns, word .. ((type(rest) == "string" and rest ~= "") and (" " .. rest) or ""))
            busy[word] = nil
            return ok and v or false
        end)
    end
end

------------------------------------------------------------------------------------------
-- Gold's ways in (they answer before the gold folder is loaded; each does nothing while locked):
-- the launcher's tooltip line and Ctrl-click, the guide panel's "..." entry, /fgui guide gold, the
-- auction house's panel.
------------------------------------------------------------------------------------------
local ahWaiting = false                -- (the auction house opened in a fight, the gold folder not loaded yet)
do
    local prevTip, prevClick = ns.LauncherTipExtra, ns.LauncherClickExtra
    function ns.LauncherTipExtra(tooltip)
        if prevTip then prevTip(tooltip) end
        if Unlocked() and type(tooltip) == "table" and tooltip.AddLine then tooltip:AddLine(ns:Tr("Ctrl-click: ways to make gold"), 1, 1, 1) end
    end
    function ns.LauncherClickExtra(button)
        if prevClick and prevClick(button) then return true end
        if not Unlocked() then return false end
        if not (IsControlKeyDown and ns.Yes(IsControlKeyDown())) then return false end
        ns:GoldOpen()
        return true
    end

    ns.GuideRegisterAction("panel", "gold", "Ways to make gold", function() ns:GoldOpen() end, function() return Unlocked() end, true)   -- (whatever guide you follow)
    ns.GuideRegisterCommand("gold", function() ns:GoldOpen(); return true end)
    ns.GuideRegisterLock("gold", function(unlocked)                -- (locked again: the window and the auction-house panel hide at once)
        if not unlocked and type(ns.GoldLockedNow) == "function" then ns.GoldLockedNow() end
    end)

    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
    pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_CLOSED")
    -- (a plain handler: while locked it returns at once, so nothing named Gold is timed by /fgui perf)
    local guarded, ahOpen
    ev:SetScript("OnEvent", function(_, event)
        if event == "AUCTION_HOUSE_SHOW" then ahOpen = true elseif event == "AUCTION_HOUSE_CLOSED" then ahOpen, ahWaiting = false, false end
        if event == "PLAYER_REGEN_ENABLED" then                  -- (the auction house opened in a fight: loaded now, if it is still open)
            pcall(ev.UnregisterEvent, ev, "PLAYER_REGEN_ENABLED")
            local was = ahWaiting
            ahWaiting = false
            if was and ahOpen and Unlocked() and ns:LoadGold(true) then ns:GoldAuctionShow() end
            return
        end
        if event ~= "AUCTION_HOUSE_SHOW" and event ~= "AUCTION_HOUSE_CLOSED" then return end
        local p = ns.goldPanel
        if not Unlocked() then
            if type(p) == "table" and event == "AUCTION_HOUSE_CLOSED" then p.suiGoldOn = false; p:Hide() end
            return
        end
        guarded = guarded or ns:Guard("Gold", function(e)
            local panelNow = ns.goldPanel
            if e == "AUCTION_HOUSE_SHOW" then
                if ns.Yes(InCombatLockdown()) and not ns.folderReady.gold then   -- (an automatic load: after the fight, quietly)
                    ahWaiting = true
                    pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
                    return
                end
                if ns:LoadGold(true) then ns:GoldAuctionShow() end
            elseif type(panelNow) == "table" then panelNow.suiGoldOn = false; panelNow:Hide() end
        end)
        guarded(event)
    end)
end

------------------------------------------------------------------------------------------
-- The login load: following the planned guide (or a trip) means the planner is loaded, which every
-- "if ns.Planner... then" in Guide.lua relies on. It runs behind the loading screen.
------------------------------------------------------------------------------------------
local LoginLoad
local function Following()
    if not Unlocked() or not ns:GuideOn() then return false end
    local st = ns.GuideState and ns.GuideState()
    local name = type(st) == "table" and st.name or nil
    return name ~= nil and (name == ns.GUIDE_PLANNED or name == ns.GUIDE_TRIP)
end
-- In a fight (a /reload in one): when it ends, the same checks again, then the load.
function LoginLoad()
    if ns.Yes(InCombatLockdown()) then
        ns:AfterFight("Planner", function() if Following() then LoginLoad() end end)
        return
    end
    if ns:LoadPlanner(true) and ns.PlannerReplan then ns:PlannerReplan("loading screen") end
end
do
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_LOGIN")
    ev:SetScript("OnEvent", function(_, event)                 -- (plain: while locked it returns at once)
        if event ~= "PLAYER_LOGIN" or not Unlocked() or not ns:GuideOn() then return end
        local st = ns.GuideState and ns.GuideState()
        local name = type(st) == "table" and st.name or nil
        if name == nil or not (name == ns.GUIDE_PLANNED or name == ns.GUIDE_TRIP) then return end
        LoginLoad()
    end)
end

------------------------------------------------------------------------------------------
-- The planner's own ways in: /fgui plan (in no help list: answered only while unlocked; locked, it is the
-- usual "not a command"), and the Tools menu's "Guide" entries.
------------------------------------------------------------------------------------------
function ns.HiddenCommand(msg)
    if not Unlocked() or type(msg) ~= "string" or ns:IsSecret(msg) then return false end
    if msg ~= "plan" and msg:sub(1, 5) ~= "plan " then return false end
    ns:PlannerOpen()
    return true
end
do
    local entries = {
        { "planner", "Planner", "/fgui plan", function() ns:PlannerOpen() end, Unlocked },
        { "gold", "Ways to make gold", "/fgui guide gold", function() ns:GoldOpen() end, Unlocked },
    }
    if ns.RegisterToolExtra then
        for _, e in ipairs(entries) do ns.RegisterToolExtra(e[1], e[2], e[3], e[4], e[5]) end
    else                                                        -- (Companion.lua loads after this file: it takes them as it loads)
        ns.toolExtrasWaiting = ns.toolExtrasWaiting or {}
        for _, e in ipairs(entries) do ns.toolExtrasWaiting[#ns.toolExtrasWaiting + 1] = e end
    end
end
