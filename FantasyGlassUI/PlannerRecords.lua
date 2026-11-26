local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner, batch 4 group D: level times, race your best, where you left off, save as guide, read aloud (Tasks 7 and 8).
-- Built on the seams: ns.PlannerHook (Planner.lua), the panel's registries (Guide.lua) and its
-- section of the Guide tab (Bars.lua). Everything here is behind ns:GuideUnlocked().
------------------------------------------------------------------------------------------
local floor, min, max, abs = math.floor, math.min, math.max, math.abs

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
-- A number the game gave (nil when unreadable or hidden).
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok and type(v) == "number" and not ns:IsSecret(v) then return v end
    return nil
end

------------------------------------------------------------------------------------------
-- Level times: a play clock per character (seconds while logged in, added by a 10 second ticker;
-- never RequestTimePlayed, which prints in chat). At a level-up the old level's time is kept per
-- account, ns.root.plannerLevels[charKey][level] = { s, xph, partial }, so characters can be
-- compared. The first level seen after install is partial (some of it was not timed): it is kept
-- but left out of fastest, slowest, average and the race.
------------------------------------------------------------------------------------------
local TICK, TICK_MAX = 10, 30

-- Add a tick to this character's clock. `elapsed` is the GetTime() time since the last tick, at most
-- 30 s, so a reload or a loading screen adds nothing extra. Skips when the level or the xp max is unreadable.
function ns.PlannerLevelTick(elapsed)
    if not Unlocked() then return false end
    elapsed = tonumber(elapsed) or 0
    if elapsed ~= elapsed or elapsed < 0 then elapsed = 0 end
    elapsed = min(elapsed, TICK_MAX)
    local level, xpMax = Read(UnitLevel, "player"), Read(UnitXPMax, "player")
    if not level or level < 1 or not xpMax or xpMax <= 0 then return false end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
    if type(rec) ~= "table" then return false end
    local c = rec.levelClock
    if type(c) ~= "table" or c.level ~= level then          -- (first tick, or a level gained while not timed: only part of it is known)
        rec.levelClock = { level = level, seconds = elapsed, xpMax = xpMax, partial = true }
    else
        c.seconds = (tonumber(c.seconds) or 0) + elapsed
        c.xpMax = xpMax
    end
    return true
end

-- PLAYER_LEVEL_UP: keep the level you left, then start a clock for the new one.
function ns.PlannerRecordLevel(oldLevel)
    if not Unlocked() or type(oldLevel) ~= "number" then return false end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(true)
    if type(rec) ~= "table" or type(ns.root) ~= "table" then return false end
    local c = rec.levelClock
    local seconds, xpMax = type(c) == "table" and tonumber(c.seconds), type(c) == "table" and tonumber(c.xpMax)
    if type(c) == "table" and c.level == oldLevel and seconds and seconds > 0 and xpMax and xpMax > 0 then
        if type(ns.root.plannerLevels) ~= "table" then ns.root.plannerLevels = {} end
        local key = ns:CharKey()
        if type(ns.root.plannerLevels[key]) ~= "table" then ns.root.plannerLevels[key] = {} end
        local s = floor(seconds + 0.5)
        ns.root.plannerLevels[key][oldLevel] = { s = s, xph = floor(xpMax * 3600 / max(1, s) + 0.5), partial = c.partial and true or nil }
    end
    rec.levelClock = { level = oldLevel + 1, seconds = 0, xpMax = Read(UnitXPMax, "player") or 0, partial = false }   -- (a level begun at the level-up is whole)
    return true
end

-- The recorded levels of one character, whole ones only: { fastest = { level, s }, slowest = { level, s }, average, count }.
function ns.PlannerLevelSummary(charKey)
    local root = ns.root
    local list = type(root) == "table" and type(root.plannerLevels) == "table" and root.plannerLevels[charKey or ns:CharKey()]
    local out, total = { count = 0 }, 0
    if type(list) ~= "table" then return out end
    for level, e in pairs(list) do
        local s = type(e) == "table" and not e.partial and tonumber(e.s)
        if type(level) == "number" and s and s > 0 then
            out.count, total = out.count + 1, total + s
            local f, sl = out.fastest, out.slowest
            if not f or s < f.s or (s == f.s and level < f.level) then out.fastest = { level = level, s = s } end
            if not sl or s > sl.s or (s == sl.s and level < sl.level) then out.slowest = { level = level, s = s } end
        end
    end
    if out.count > 0 then out.average = total / out.count end
    return out
end

-- A length of time as the stats page shows it: 1d 2h, 3h 5m, 12m.
local function Span(secs)
    secs = floor(tonumber(secs) or 0)
    local d, h, m = floor(secs / 86400), floor(secs % 86400 / 3600), floor(secs % 3600 / 60)
    if d > 0 then return format(ns:Tr("%dd %dh"), d, h) end
    if h > 0 then return format(ns:Tr("%dh %dm"), h, m) end
    return format(ns:Tr("%dm"), m)
end
local function Commas(n)
    local s = tostring(floor((tonumber(n) or 0) + 0.5))
    local k
    repeat s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
    return s
end

-- The Levels part of /fgui stats: lines for ShowLifetime (empty while locked or with nothing recorded).
function ns.PlannerLevelLines()
    local lines = {}
    if not Unlocked() then return lines end
    local sum = ns.PlannerLevelSummary()
    if sum.count < 1 then return lines end
    lines[1] = { left = " " }
    lines[2] = { left = ns:AccentHex() .. ns:Tr("Levels") .. "|r" }
    lines[3] = { left = format(ns:Tr("Fastest level: %d (%s)"), sum.fastest.level, Span(sum.fastest.s)), indent = 16 }
    lines[4] = { left = format(ns:Tr("Slowest level: %d (%s)"), sum.slowest.level, Span(sum.slowest.s)), indent = 16 }
    lines[5] = { left = format(ns:Tr("Average level: %s"), Span(sum.average)), indent = 16 }
    return lines
end

-- The run log's first list: one line per recorded level of this character, newest first, at most 20.
function ns.PlannerLevelRunLines()
    local lines = {}
    if not Unlocked() then return lines end
    local root = ns.root
    local list = type(root) == "table" and type(root.plannerLevels) == "table" and root.plannerLevels[ns:CharKey()]
    if type(list) ~= "table" then return lines end
    local levels = {}
    for level, e in pairs(list) do
        if type(level) == "number" and type(e) == "table" and tonumber(e.s) then levels[#levels + 1] = level end
    end
    table.sort(levels, function(a, b) return a > b end)
    for i = 1, min(20, #levels) do
        local e = list[levels[i]]
        local text = format(ns:Tr("Level %d: %s, %s xp an hour"), levels[i], Span(e.s), Commas(e.xph))
        if e.partial then text = text .. "  " .. ns:ToneHex("dim") .. "(" .. ns:Tr("partly timed") .. ")|r" end     -- (not counted in fastest, slowest, average or the race)
        lines[#lines + 1] = { left = text }
    end
    return lines
end

------------------------------------------------------------------------------------------
-- Race your best: the fastest other character's whole time at your level, against the clock here.
-- expected = best.s x xp / xp max; within 60 s either way is "level with your best".
------------------------------------------------------------------------------------------
local function BestOther(level)
    local root, me, best = ns.root, ns:CharKey(), nil
    if type(root) ~= "table" or type(root.plannerLevels) ~= "table" then return nil end
    for key, list in pairs(root.plannerLevels) do
        local e = key ~= me and type(list) == "table" and list[level]
        local s = type(e) == "table" and not e.partial and tonumber(e.s)
        if s and s > 0 and (not best or s < best) then best = s end
    end
    return best
end

local function RaceLine()
    if not (Unlocked() and ns.db and ns.db.plannerRace == true) then return nil end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    local c = type(rec) == "table" and rec.levelClock
    if type(c) ~= "table" or c.partial or not tonumber(c.seconds) then return nil end
    local level, xp, xpMax = Read(UnitLevel, "player"), Read(UnitXP, "player"), Read(UnitXPMax, "player")
    if level ~= c.level or not xp or not xpMax or xpMax <= 0 then return nil end
    local best = BestOther(level)
    if not best then return nil end
    local ahead = best * min(1, max(0, xp / xpMax)) - c.seconds
    if abs(ahead) <= 60 then return ns:Tr("Race your best: level with your best") end
    local minutes = max(1, floor(abs(ahead) / 60 + 0.5))
    return format(ns:Tr(ahead > 0 and "Race your best: ahead by %d min" or "Race your best: behind by %d min"), minutes)
end
ns.PlannerRaceLine = RaceLine
ns.GuideRegisterLine("race", RaceLine)

------------------------------------------------------------------------------------------
-- Where you left off: at an initial login with a planned guide, one chat line and a panel line for 120 s.
------------------------------------------------------------------------------------------
local LEFT_OFF_SECONDS = 120
local leftOff                                    -- { text, till }
local leftOffWanted = false                      -- (an initial login: the line waits for the first plan)

function ns.PlannerLeftOff()
    leftOff = nil
    if not (Unlocked() and ns:GuideOn() and ns.db and ns.db.plannerLeftOff ~= false) then return nil end
    local st = ns.GuideState and ns.GuideState()
    if type(st) ~= "table" or st.name == nil or st.name ~= ns.GUIDE_PLANNED then return nil end
    local guide = type(st.plan) == "table" and st.plan or ns:GuideGet(st.name)
    local steps = type(guide) == "table" and guide.steps
    if type(steps) ~= "table" then return nil end
    local n, at = #steps, tonumber(st.at) or 1
    local step = steps[at]
    if n < 1 or type(step) ~= "table" then return nil end
    local text = format(ns:Tr("Where you left off: step %d of %d, %s"), at, n, ns.GuideStepBase(step))
    local level = Read(UnitLevel, "player")
    if ns.PlannerTimeToLevel and level then              -- (the time to the next level, when the pace is known)
        local ok, minutes = pcall(ns.PlannerTimeToLevel, st.summary)
        minutes = ok and tonumber(minutes)
        if minutes and minutes >= 1 then text = text .. format(ns:Tr(", level %d in ~%d min"), level + 1, floor(minutes + 0.5)) end
    end
    leftOff = { text = text, till = GetTime() + LEFT_OFF_SECONDS }
    ns:PrintRaw(text)
    if ns.GuideRedraw then ns:GuideRedraw() end
    ns:After(LEFT_OFF_SECONDS + 1, ns:Guard("Planner records", function() leftOff = nil; if ns.GuideRedraw then ns:GuideRedraw() end end))
    return text
end

-- The login's line, once: from the first plan applied after it, or after 20 s from the saved one.
function ns.PlannerLeftOffDue()
    if not leftOffWanted then return nil end
    leftOffWanted = false
    return ns.PlannerLeftOff()
end
if ns.PlannerHook then ns.PlannerHook("applied", "leftoff", function() ns.PlannerLeftOffDue() end) end
ns.GuideRegisterLine("leftoff", function()
    if not leftOff then return nil end
    if GetTime() >= leftOff.till or not Unlocked() or not (ns.db and ns.db.plannerLeftOff ~= false) then leftOff = nil; return nil end
    return leftOff.text
end)

------------------------------------------------------------------------------------------
-- Task 8: save the plan as a guide, read the route aloud, keys, and the chime's caption.
------------------------------------------------------------------------------------------
local function ZoneName(map)
    if not (map and C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, map)
    local name = ok and type(info) == "table" and info.name
    if type(name) == "string" and not ns:IsSecret(name) and name ~= "" then return name end
end

-- The planned guide as a saved one: each step through the text format (so only what it keeps), named
-- "Zone from-to" (the level rounded outwards), then " (2)", " (3)" ... when that name is taken.
function ns.PlannerSaveAsGuide()
    if not Unlocked() then return nil end
    local guide = ns:GuideGet(ns.GUIDE_PLANNED)
    local st = ns.GuideState and ns.GuideState()
    if type(guide) ~= "table" or type(guide.steps) ~= "table" or #guide.steps < 1 then return nil end
    local s = type(st) == "table" and type(st.summary) == "table" and st.summary or {}
    local steps = {}
    for _, step in ipairs(guide.steps) do
        local parsed = ns.GuideParseLine(ns.GuideLine(step))
        if parsed then steps[#steps + 1] = parsed end
    end
    if #steps < 1 then return nil end
    local base = format("%s %d-%d", ZoneName(s.zone) or ns:Tr("Planned route"),
        floor(tonumber(s.fromLevel) or 1), math.ceil(tonumber(s.toLevel) or tonumber(s.fromLevel) or 1))
    local name, n = base, 1
    while ns:GuideGet(name) and n < 99 do n = n + 1; name = format("%s (%d)", base, n) end
    if ns:GuideGet(name) then                              -- (every name to 99 is taken: nothing is overwritten)
        ns:Print("Too many guides called \"%s\": rename or delete one first.", base)
        return nil
    end
    local saved = ns:GuideSave({ name = name, steps = steps })
    if not saved then return nil end
    ns:Print("Saved as guide \"%s\": %d steps.", name, #steps)
    return name
end
-- (offered for a plan the planner made: it has a length, and is not the empty one)
local function PlanReady()
    if not Unlocked() then return false end
    local st = ns.GuideState and ns.GuideState()
    local sum = type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED and st.summary
    return type(sum) == "table" and (tonumber(sum.seconds) or 0) > 0 and not sum.empty
end
ns.GuideRegisterAction("panel", "saveAsGuide", "Save as guide", function() ns.PlannerSaveAsGuide() end, PlanReady)

-- The step you are on changed: read it aloud (only with reading aloud on; not the step a login or /reload
-- finds you on, which is not new), and caption the chime.
ns.GuideRegisterAdvance("records", function(_, _, step, _, moved, resumed)
    if not Unlocked() or not ns.db then return end
    ns.PlannerKeyFrames()                                  -- (unlocked in this session: the key windows join now, not at the next login)
    if ns.db.readDialog and ns.db.plannerSpeak ~= false and type(step) == "table" and not resumed then
        ns:Speak(ns.GuideStepBase(step))
    end
    if moved and ns.db.guideSound ~= false then ns:Caption("alert", ns:Tr("Step done")) end
end)

-- Keys: the guide's menu and its pages join the windows Tab and Enter work in.
local KEY_FRAMES = { "FantasyGlassUIGuideMenu", "FantasyGlassUIListPlanPreview", "FantasyGlassUIListPlanWhy", "FantasyGlassUIListPlanTime",
                     "FantasyGlassUIListPlanCatchUp", "FantasyGlassUIListPlanHere", "FantasyGlassUIListPlanDuoAsk", "FantasyGlassUIListGuides",
                     "FantasyGlassUIListReputation", "FantasyGlassUIListSkipped", "FantasyGlassUIGuideEditor", "FantasyGlassUIRouteEditor" }
function ns.PlannerKeyFrames()
    local list = ns.WINDOW_KEYS_FRAMES
    if type(list) ~= "table" then return end
    for _, name in ipairs(KEY_FRAMES) do
        local have = false
        for _, v in ipairs(list) do if v == name then have = true; break end end
        if not have then list[#list + 1] = name end
    end
end
-- /fgui guide keys: the panel's menu with every button on it (Back, Next, Guides and the shown panel actions).
ns.GuideRegisterCommand("keys", function()
    local st = ns.GuideState and ns.GuideState()
    local entries = { { "Back", function() ns:GuideSkip(true) end }, { "Next", function() ns:GuideSkip(false) end },
                      { "Guides", function() ns:GuideList() end } }
    if type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED then
        local guide = ns:GuideGet(st.name)
        for _, e in ipairs(ns.GuidePanelEntries(guide and guide.steps[st.at or 1] or nil)) do entries[#entries + 1] = e end
    end
    return ns:GuideMenu(entries)
end)

------------------------------------------------------------------------------------------
-- Events and the 10 second ticker
------------------------------------------------------------------------------------------
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Planner records", function(_, event, a)
        if not Unlocked() then return end
        if event == "PLAYER_LOGIN" then
            ns.PlannerKeyFrames()
        elseif event == "PLAYER_LEVEL_UP" then
            if type(a) == "number" and a > 1 then ns.PlannerRecordLevel(a - 1) end
        elseif event == "PLAYER_ENTERING_WORLD" and a == true then       -- (an initial login: not a reload, not a loading screen)
            -- said from the first plan made after the login (the saved one is replaced a moment later), or from the
            -- saved one when no plan comes within 20 s
            leftOffWanted = true
            ns:After(20, ns:Guard("Planner records", function() ns.PlannerLeftOffDue() end))
        end
    end))
    local acc, last = 0, nil
    ns.plannerRecordsFrame = ev
    function ns.PlannerLevelGapReset() acc, last = 0, nil end      -- (as after a reload: the next tick adds nothing)
    ev:SetScript("OnUpdate", ns:Guard("Planner records", function(_, elapsed)
        acc = acc + (tonumber(elapsed) or 0)
        if acc < TICK then return end
        acc = 0
        local now = GetTime()
        local gap = last and (now - last) or 0           -- (the first tick after a login or a reload adds nothing)
        last = now
        ns.PlannerLevelTick(gap)
        if ns.db and ns.db.plannerRace == true and Unlocked() and ns.GuideRedraw and not InCombatLockdown() then     -- (the race line follows the clock, on a panel you can see; not in a fight)
            local panel = _G.FantasyGlassUIGuide
            if type(panel) == "table" and panel.IsShown and panel:IsShown() then ns:GuideRedraw() end
        end
    end))
end
