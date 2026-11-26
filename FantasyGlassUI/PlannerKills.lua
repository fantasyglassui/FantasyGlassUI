local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner, batch 6 group A: what each kill gives and how fast you kill (the recorder).
-- A kill is the game's kill line (CHAT_MSG_COMBAT_XP_GAIN: one per kill, never a hand-in or exploring).
-- Its experience is the XP change paired with it (the first within ns.PLANNER_KILL_PAIR seconds before
-- or after), with a level rolled over added and the rested part taken off: the base the formula predicts.
-- Per character: killXP[diff] = { n, r } (r: what you get against ns.PlannerKillXP, the last 20),
-- killGaps (the last 50 gaps between solo kills of 180 s or less) and killsPerHour (from their median).
-- Nothing while grouped (split experience), while locked, or when a value is hidden. It only reads:
-- it runs in fights, and calls nothing protected.
------------------------------------------------------------------------------------------
local floor, min, max = math.floor, math.min, math.max

ns.PLANNER_KILL_PAIR = 1             -- seconds between the kill line and its XP change, either way
ns.PLANNER_KILL_GAP = 180            -- seconds: a longer gap between kills is a break, not your rate
ns.PLANNER_KILL_GAPS = 50            -- gaps kept
ns.PLANNER_KILL_MIN_GAPS = 10        -- gaps before the rate is saved
local DIFF_LOW, DIFF_HIGH = -10, 5   -- level differences kept (the formula is flat above +4)
local RATIO_LOW, RATIO_HIGH = 0.25, 4
local MEAN_OF, RATIO_WEIGHT = 20, 5
local ELITE = { elite = true, rareelite = true, worldboss = true }

local lastKill                       -- the time of the last solo kill line (memory only)

local function Diff(d) return max(DIFF_LOW, min(DIFF_HIGH, floor(d + 0.5))) end

local function Median(list)
    local s = {}
    for i, v in ipairs(list) do s[i] = v end
    table.sort(s)
    local n = #s
    if n % 2 == 1 then return s[(n + 1) / 2] end
    return (s[n / 2] + s[n / 2 + 1]) / 2
end

-- sample = { xp = base, level, mobLevel|nil, elite, t|nil }: t counts the kill for the rate (the kill
-- line), mobLevel with xp and level is a sample of what the kill gave (its XP change, paired).
function ns.PlannerRecordKill(sample)
    if type(sample) ~= "table" or not ns:GuideUnlocked() then return end
    local t = tonumber(sample.t)
    if t then
        local gap = lastKill and t - lastKill
        lastKill = t
        if gap and gap > 0 and gap <= ns.PLANNER_KILL_GAP then
            local rec = ns.PlannerCharRecord(true)
            if not rec then return end
            if type(rec.killGaps) ~= "table" then rec.killGaps = {} end
            local gaps = rec.killGaps
            for i = #gaps, 1, -1 do if type(gaps[i]) ~= "number" or gaps[i] <= 0 then table.remove(gaps, i) end end
            gaps[#gaps + 1] = gap
            while #gaps > ns.PLANNER_KILL_GAPS do table.remove(gaps, 1) end
            if #gaps >= ns.PLANNER_KILL_MIN_GAPS then rec.killsPerHour = floor(3600 / Median(gaps) + 0.5) end
        end
    end
    local xp, level, mob = tonumber(sample.xp), tonumber(sample.level), tonumber(sample.mobLevel)
    if not (xp and level and mob) then return end
    local f = ns.PlannerKillXP(level, mob, sample.elite)
    if not f or f <= 0 then return end                  -- (a gray monster gives nothing to compare)
    local s = xp / f
    if s < RATIO_LOW or s > RATIO_HIGH then return end  -- (not this kill's experience)
    local rec = ns.PlannerCharRecord(true)
    if not rec then return end
    if type(rec.killXP) ~= "table" then rec.killXP = {} end
    local d = Diff(mob - level)
    local e = rec.killXP[d]
    if type(e) ~= "table" or not tonumber(e.n) or not tonumber(e.r) or e.n < 0 then e = { n = 0, r = 0 }; rec.killXP[d] = e end
    e.n = e.n + 1
    e.r = e.r + (s - e.r) / min(e.n, MEAN_OF)
end

-- What a kill at this level difference really gives against the formula: (1 + r × m) ÷ (1 + m), with
-- m = min(n, 5) (a few samples move it a little); 1 with none. One table for elites and the rest: the
-- formula already doubles an elite.
function ns.PlannerKillRatio(diff, elite)
    diff = tonumber(diff)
    if not diff then return 1 end
    local rec = ns.PlannerCharRecord and ns.PlannerCharRecord(false)
    local t = type(rec) == "table" and rec.killXP
    local e = type(t) == "table" and t[Diff(diff)]
    local n, r = type(e) == "table" and tonumber(e.n), type(e) == "table" and tonumber(e.r)
    if not (n and r) or n <= 0 then return 1 end
    local m = min(n, RATIO_WEIGHT)
    return (1 + r * m) / (1 + m)
end

do
    -- A value from the game: (value, hidden); hidden when the call fails or the value is secret.
    local function Read(fn, ...)
        if type(fn) ~= "function" then return nil, true end
        local ok, v = pcall(fn, ...)
        if not ok or ns:IsSecret(v) then return nil, true end
        return v, false
    end
    local function Now()
        local t, hidden = Read(GetTime)
        if not hidden and type(t) == "number" then return t end
    end
    local function Solo()
        local g, hidden = Read(IsInGroup)
        return not hidden and not g
    end
    -- Your experience now: { xp, max, rest, level }, or nil when any of it can't be read.
    local function Snapshot()
        local xp, h1 = Read(UnitXP, "player")
        local most, h2 = Read(UnitXPMax, "player")
        local rest, h3 = Read(GetXPExhaustion)
        local level, h4 = Read(UnitLevel, "player")
        if h1 or h2 or h3 or h4 or type(xp) ~= "number" or type(most) ~= "number" or type(level) ~= "number" then return nil end
        return { xp = xp, max = most, rest = tonumber(rest) or 0, level = level }
    end
    -- The monster just killed: { mobLevel, elite } when the target exists, is dead, can be attacked and
    -- has a level above 0; nil otherwise, or when any of it is hidden (the kill then counts for the rate only).
    local function Victim()
        local exists, h1 = Read(UnitExists, "target")
        if h1 or not exists then return nil end
        local dead, h2 = Read(UnitIsDead, "target")
        local attack, h3 = Read(UnitCanAttack, "player", "target")
        local mob, h4 = Read(UnitLevel, "target")
        local class, h5 = Read(UnitClassification, "target")
        if h2 or h3 or h4 or h5 or not dead or not attack or type(mob) ~= "number" or mob <= 0 then return nil end
        return { mobLevel = mob, elite = type(class) == "string" and ELITE[class] == true }
    end

    local last                       -- your experience before the next change
    local line                       -- a kill line waiting for its XP change: { t, mobLevel, elite }
    local gain                       -- an XP change waiting for its kill line: { t, xp, level }
    local function Forget() last, line, gain, lastKill = nil, nil, nil, nil end
    local function Pair(g, l)
        if l.mobLevel then ns.PlannerRecordKill({ xp = g.xp, level = g.level, mobLevel = l.mobLevel, elite = l.elite }) end
    end
    local function Fresh(e, t) return e and t >= e.t and t - e.t <= ns.PLANNER_KILL_PAIR end

    local function OnLine()
        local t = Now()
        if not t or not Snapshot() or not Solo() then line, gain, lastKill = nil, nil, nil; return end   -- (grouped or hidden: nothing at all)
        ns.PlannerRecordKill({ t = t })
        local v = Victim()
        local l = { t = t, mobLevel = v and v.mobLevel, elite = v and v.elite }
        if Fresh(gain, t) then
            local g = gain
            line, gain = nil, nil
            Pair(g, l)
        else
            line, gain = l, nil
        end
    end

    local function OnXP()
        local now, t = Snapshot(), Now()
        if not (now and t) then last, line, gain = nil, nil, nil; return end
        local before = last
        last = now
        if not before then return end
        local d = now.xp - before.xp
        if now.xp < before.xp then d = d + before.max end          -- (a level rolled over)
        if d <= 0 then return end
        local g = { t = t, xp = d - max(0, before.rest - now.rest), level = before.level }   -- (the rested part off: the base)
        if Fresh(line, t) then
            local l = line
            line, gain = nil, nil
            Pair(g, l)
        else
            line, gain = nil, g
        end
    end

    local function OnEvent(_, event, unit)
        if not ns:GuideUnlocked() then Forget(); return end
        if event == "PLAYER_ENTERING_WORLD" then
            last, line, gain = Snapshot(), nil, nil
        elseif event == "PLAYER_XP_UPDATE" then
            if unit == "player" then OnXP() end
        elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
            OnLine()
        elseif event == "UPDATE_EXHAUSTION" then
            -- rest gained (at an inn, logged out) is not a kill's: kept at once; rest used is a kill's,
            -- left for the XP change to take off (this can come first)
            local rest, hidden = Read(GetXPExhaustion)
            if hidden then last = nil
            elseif last and (tonumber(rest) or 0) > last.rest then last.rest = tonumber(rest) or 0 end
        end
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_XP_UPDATE", "CHAT_MSG_COMBAT_XP_GAIN", "UPDATE_EXHAUSTION", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
    local handler = ns:Guard("Planner kills", OnEvent)
    ev:SetScript("OnEvent", handler)
    ns.PlannerKillsEvent = function(...) return handler(ev, ...) end   -- (the same, called directly: the tests)
end
