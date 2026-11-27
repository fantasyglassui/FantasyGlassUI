local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
------------------------------------------------------------------------------------------
-- Go: the planner's travel for a gold idea, as a trip on the guide panel (the folders plan's group D,
-- ruling 9). The trip is laid as a planner job ("goldTrip": a slice a frame, never in a fight, only while
-- the planner has no plan to make), with the same flights, hearthstone, boats and flight points learned on
-- the way as a plan's. It is handed to the guide (ns:GuideStartTrip) on the main thread, outside the job, so
-- nothing the guide does then runs inside the planner's coroutine. The plan you follow waits for it.
------------------------------------------------------------------------------------------
local type, ipairs, tonumber, format, floor, huge = type, ipairs, tonumber, string.format, math.floor, math.huge

local function Num(v)
    if ns:IsSecret(v) then return nil end
    v = tonumber(v)
    if not v or v ~= v or v == huge or v == -huge then return nil end
    return v
end
local function Text(v)
    if ns:IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end
local function Fighting() return InCombatLockdown() and true or false end
local function Minutes(m)
    if ns.GoldTimeText then return ns.GoldTimeText(m) end   -- (gold's words for a time: the gold folder is in when Go is pressed)
    return format(ns:Tr("%d min"), floor(m))
end

-- A timed quest's run under way on the plan you follow (or the plan a trip has paused): never split, so no
-- trip starts in it (its accept step not yet taken is no run yet).
local function TimedRun()
    local st = ns.GuideState and ns.GuideState()
    if ns.GuideOnTrip and ns.GuideOnTrip() then st = st.resume end
    if not (type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED and type(st.plan) == "table" and type(st.plan.steps) == "table") then return false end
    local step = st.plan.steps[tonumber(st.at) or 1]
    return type(step) == "table" and step.timed == true and step.kind ~= "accept"
end

-- An idea step's place: map, x, y (percent), or nil. A step with a map and no spot is the map's middle (a zone
-- to go to); a spot with no map is on the map you are on.
local function Place(s, ctx)
    local map, x, y = Num(s.map), Num(s.x), Num(s.y)
    if x and y and (x < 0 or x > 100 or y < 0 or y > 100) then x, y = nil, nil end
    if map and not (x and y) then return map, 50, 50 end
    if x and y and not map then
        local here = type(ctx.here) == "table" and ctx.here or nil
        map = here and Num(here.map)
    end
    if map and x and y then return map, x, y end
    return nil
end

-- The trip's steps and its travel in seconds; nil when a place can't be reached. In the job only (it yields).
-- A trip is laid to the first placed step, and again before each step on another map than the one before it;
-- each idea step is a goto (its words and place) or, with no place, a note.
local function Build(idea)
    local ctx = ns.PlannerContext()
    local state = ns.PlannerTripState(ctx)
    local steps, secs, lastMap, middle = {}, 0, nil, false
    for _, s in ipairs(type(idea.steps) == "table" and idea.steps or {}) do
        ns.PlannerYield()
        if type(s) == "table" then
            local text = Text(s.text)
            local map, x, y = Place(s, ctx)
            if map then
                local dest = { map = map, x = x, y = y }
                if lastMap == nil or map ~= lastMap then
                    local t = ns.PlannerTrip(state, dest, steps, false)
                    if not t then return nil end
                    secs = secs + t
                else                                                    -- (on the same map: a walk, counted in the time)
                    local t = state.pos and Num((ns.PlannerTravel(state.pos, dest, state.tctx)))
                    if t then secs = secs + t end
                    state.pos = dest
                end
                lastMap = map
                steps[#steps + 1] = { kind = "goto", text = text, map = map, x = x, y = y }
                middle = not (Num(s.x) and Num(s.y))
            elseif text then
                steps[#steps + 1] = { kind = "note", text = text }
                middle = false
            end
        end
    end
    -- (the last step only a zone to go to, as a farm's: the trip does not end on arrival, so the plan does not come back
    -- while you farm; a note waits for you to stop it)
    if middle then steps[#steps + 1] = { kind = "note", text = ns:Tr("Stay as long as you like, then Stop this trip.") } end
    return steps, secs
end

-- What the job laid, waiting for the main thread: { idea, steps, secs } or { idea, none = true }.
local ready
local function Apply(r)
    local idea = r.idea
    if r.none or #r.steps == 0 then
        ns:Print("No way there was found: here are the steps.")
        if ns.GoldStepsList then ns.GoldStepsList(idea) end
        return false
    end
    if TimedRun() then ns:Print("Not now: a timed quest is under way. Go again once it is handed in."); return false end
    local steps = r.steps
    local left = ns.PlannerTimeLeft and Num(ns.PlannerTimeLeft())
    if left then                                                  -- (a time limit: the trip runs whatever it is, and says how it fits)
        local minutes = r.secs / 60 + (Num(idea.minutes) or 0)
        table.insert(steps, 1, { kind = "note", text = format(ns:Tr("This trip takes about %s; you have %s left."), Minutes(minutes), Minutes(left / 60)) })
    end
    if ns.plannerDuo and ns.PlannerDuoEnd then ns:PlannerDuoEnd("guide", true) end   -- (planning together ends: you plan alone after the trip)
    local title = Text(idea.title) or ns:Tr("Go")
    return ns:GuideStartTrip({ name = ns.GUIDE_TRIP, steps = steps }, { title = title, id = idea.id, minutes = Num(idea.minutes) })
end
local building                                                  -- (the idea whose trip the job is laying, while it runs)
ns:Every(0, "Planner go", function()
    if building and ns.plannerJobKey ~= "goldTrip" then           -- (the job stopped with an error: said, and the steps listed)
        ready, building = { idea = building, none = true }, nil
    end
    if not ready or Fighting() then return end
    local r = ready
    ready = nil
    if ns:GuideOn() then Apply(r)
    elseif ns.GoldStepsList then ns.GoldStepsList(r.idea) end   -- (the guide switched off meanwhile: the steps in a list)
end)

-- Go for a gold idea: true when its trip is being laid (a planner job; the trip starts when it is done).
function ns.GoldTravel(idea)
    if type(idea) ~= "table" then return false end
    if Fighting() then ns:Print("Not during a fight."); return false end
    if not ns:GuideOn() then                                      -- (no guide to follow it with: the steps in a list)
        if ns.GoldStepsList then ns.GoldStepsList(idea) end
        return false
    end
    if TimedRun() then ns:Print("Not now: a timed quest is under way. Go again once it is handed in."); return false end
    return ns.PlannerJob(function()
        building = idea
        local steps, secs = Build(idea)
        building = nil
        ready = steps and { idea = idea, steps = steps, secs = secs } or { idea = idea, none = true }
    end, "goldTrip")
end
ns.FolderFileDone("planner", "PlannerGo.lua")
