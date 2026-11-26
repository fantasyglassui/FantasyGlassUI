local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- Planner, batch 5 group C: the plan code for the website's plan page (#44) (Tasks 5 and 6).
-- Built on the seams: ns.PlannerHook (Planner.lua, with "candidate" and "replan"), the panel's
-- registries (Guide.lua) and its section of the Guide tab (Bars.lua). Everything here is behind ns:GuideUnlocked().
------------------------------------------------------------------------------------------

local floor = math.floor

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end

ns.PLANNER_CODE_HEADER = "SUIP1!"
local MAX_STEPS, MAX_TEXT, MAX_ZONE = 60, 80, 40

-- Text for the code: no |escapes (colors, textures, links), no control characters, at most `limit` bytes
-- (never in the middle of a UTF-8 character).
local function Clean(text, limit)
    text = tostring(text or "")
    text = text:gsub("|A.-|a", ""):gsub("|n", " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h", ""):gsub("|h", ""):gsub("|", "")
    text = text:gsub("[%z\1-\31\127]", " ")
    text = ns.Trim((text:gsub(" +", " ")))
    if #text > limit then
        local cut = limit
        while cut > 0 do                                  -- (back off a continuation byte so a character is not split)
            local b = text:byte(cut + 1)
            if b and b >= 128 and b < 192 then cut = cut - 1 else break end
        end
        text = text:sub(1, cut)
    end
    return text
end
local function Round(n) return floor((tonumber(n) or 0) + 0.5) end
local function Round1(n) return floor((tonumber(n) or 0) * 10 + 0.5) / 10 end

local function ZoneName(map)
    local ok, info = pcall(C_Map.GetMapInfo, map)
    local name = ok and type(info) == "table" and info.name
    if type(name) == "string" and not ns:IsSecret(name) and name ~= "" then return Clean(name, MAX_ZONE) end
    return "?"
end

-- The plan as a code: "SUIP1!" and the share encoding of the plan's short form. Nil with no steps.
function ns.PlannerPlanCode(guide, summary)
    local steps = type(guide) == "table" and type(guide.steps) == "table" and guide.steps or nil
    if not steps or #steps == 0 then return nil end
    summary = type(summary) == "table" and summary or {}
    local zones, index, st = {}, {}, {}
    local flights, crossings = 0, 0
    for i, step in ipairs(steps) do
        if step.kind == "fly" then flights = flights + 1 elseif step.kind == "sail" then crossings = crossings + 1 end
        if i <= MAX_STEPS then
            local e = { k = step.kind, t = Clean(ns.GuideStepBase(step), MAX_TEXT) }
            local map = tonumber(step.map)
            if map then
                if not index[map] then zones[#zones + 1] = { m = map, n = ZoneName(map) }; index[map] = #zones end
                e.z = index[map]
            end
            if tonumber(step.x) and tonumber(step.y) then e.x, e.y = Round1(step.x), Round1(step.y) end
            st[#st + 1] = e
        end
    end
    local data = { v = 1, lv = { Round(summary.fromLevel), Round(summary.toLevel) },
                   xp = tonumber(summary.xp) and Round(summary.xp) or nil, s = tonumber(summary.seconds) and Round(summary.seconds) or nil,
                   fl = flights, cr = crossings, z = zones, st = st }     -- (no experience or time known: left out, and the page shows "—")
    if #steps > MAX_STEPS then data.more = #steps - MAX_STEPS end
    return ns.PLANNER_CODE_HEADER .. ns.ShareEncode(data)
end

-- The reader and the website's reader (site-src/plan/reader.js) refuse exactly the same codes (tests/plan_codes.txt):
-- a list is a table keyed 1..n and nothing else; a field that is there must have its type; text after the code is damage.
local function ListSize(t)
    if type(t) ~= "table" then return nil end
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then return nil end
        n = n + 1
    end
    for i = 1, n do if t[i] == nil then return nil end end
    return n
end
local function Finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
-- A number that may be left out (default `d`); false when it is there and not a number.
local function Opt(v, d)
    if v == nil then return d end
    if Finite(v) then return v end
    return false
end

-- A code back into the plan (what the website's page does): plan, or nil and why: empty, kind, damaged, version.
function ns.PlannerReadPlanCode(code)
    if type(code) ~= "string" then return nil, "empty" end
    code = ns.Trim(code)
    if code == "" then return nil, "empty" end
    local head = ns.PLANNER_CODE_HEADER
    if code:sub(1, #head) ~= head then
        local newer = code:match("^SUIP(%d+)!")
        if newer and tonumber(newer) > 1 then return nil, "version" end
        return nil, "kind"
    end
    local data, stop = ns.ShareDecode(code, #head + 1)
    if type(data) ~= "table" or stop ~= #code + 1 then return nil, "damaged" end
    if type(data.v) ~= "number" then return nil, "damaged" end
    if data.v > 1 then return nil, "version" end
    if data.v ~= 1 then return nil, "damaged" end
    local nlv, nz, nst = ListSize(data.lv), ListSize(data.z), ListSize(data.st)
    if nlv ~= 2 or not nz or not nst then return nil, "damaged" end
    local plan = { v = 1, lv = { data.lv[1], data.lv[2] }, xp = Opt(data.xp, nil), s = Opt(data.s, nil), fl = Opt(data.fl, 0),
                   cr = Opt(data.cr, 0), more = Opt(data.more, 0), z = {}, st = {} }
    if not Finite(plan.lv[1]) or not Finite(plan.lv[2]) then return nil, "damaged" end
    if plan.xp == false or plan.s == false or plan.fl == false or plan.cr == false or plan.more == false then return nil, "damaged" end
    for i = 1, nz do
        local z = data.z[i]
        if type(z) ~= "table" or type(z.n) ~= "string" then return nil, "damaged" end
        local m = Opt(z.m, nil)
        if m == false then return nil, "damaged" end
        plan.z[i] = { m = m, n = z.n }
    end
    for i = 1, nst do
        local s = data.st[i]
        if type(s) ~= "table" or type(s.k) ~= "string" or not ns.guideKinds[s.k] or type(s.t) ~= "string" then return nil, "damaged" end
        local zi, x, y = s.z, Opt(s.x, nil), Opt(s.y, nil)
        if x == false or y == false then return nil, "damaged" end
        if zi ~= nil and (type(zi) ~= "number" or zi < 1 or zi > nz or zi % 1 ~= 0) then return nil, "damaged" end
        plan.st[i] = { k = s.k, t = s.t, z = zi, x = x, y = y }
    end
    return plan
end

-- Are you following the planned guide (with it unlocked)?
function ns.PlannerCodeFollowing()
    local st = Unlocked() and ns.GuideState and ns.GuideState()
    return type(st) == "table" and st.name ~= nil and st.name == ns.GUIDE_PLANNED
end

-- Share plan: the code in a box ready for Ctrl+C.
function ns:PlannerSharePlan()
    if not Unlocked() then return false end
    local st = ns.GuideState and ns.GuideState()
    local guide = ns.PlannerCodeFollowing() and ns:GuideGet(ns.GUIDE_PLANNED) or nil
    local code = guide and ns.PlannerPlanCode(guide, st.summary)
    if not code then
        ns:Print("There is no plan to share yet.")
        return false
    end
    -- (the plan page goes online with 13.0, whose release list puts the address back in this caption)
    ns:ShowCopyBox(code, ns:Tr("Copy this plan code. The plan page goes online with the next big update."))
    return true
end

ns.GuideRegisterAction("panel", "sharePlan", "Share plan", function() ns:PlannerSharePlan() end, ns.PlannerCodeFollowing)
ns.GuideRegisterCommand("share", function() ns:PlannerSharePlan() end)
ns.FolderFileDone("planner", "PlannerCode.lua")
