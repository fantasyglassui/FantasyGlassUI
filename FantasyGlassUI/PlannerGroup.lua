local _, ns = ...

------------------------------------------------------------------------------------------
-- Planner, batch 5 group A: find a group for a group quest (#31) (Task 2).
-- Built on the seams: ns.PlannerHook (Planner.lua, with "candidate" and "replan"), the panel's
-- registries (Guide.lua) and its section of the Guide tab (Bars.lua). Everything here is behind ns:GuideUnlocked().
-- The add-on never sends the line: it only puts it in your chat box (ChatFrameUtil.OpenChat) and you press Enter.
------------------------------------------------------------------------------------------
local format, floor = string.format, math.floor

local function Unlocked() return ns.GuideUnlocked ~= nil and ns:GuideUnlocked() == true end
local function Clean(s)                                   -- (text from a quest: a string we can show, without |-escapes or control characters)
    if type(s) ~= "string" or ns:IsSecret(s) then return nil end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h", ""):gsub("|h", "")
    s = s:gsub("|", ""):gsub("%c", " ")
    s = ns.Trim and ns.Trim(s) or s:match("^%s*(.-)%s*$")
    if s == "" then return nil end
    return s
end

-- What kind of group a quest needs: "dungeon", "group" or "elite" (nil: none, or no record). Kept for the session by id
-- (only when the record was found, so a source that is still loading is asked again).
local needs = {}
function ns.PlannerNeedsGroup(questID)
    if type(questID) ~= "number" then return nil end
    local c = needs[questID]
    if c ~= nil then return c or nil end
    if not ns.PlannerSource then return nil end
    local okSource, src = pcall(ns.PlannerSource)
    if not okSource or type(src) ~= "table" or type(src.quest) ~= "function" then return nil end
    local ok, rec = pcall(src.quest, questID)
    if not ok or type(rec) ~= "table" then return nil end
    local kind = (rec.dungeon and "dungeon") or (rec.group and "group") or (rec.elite and "elite") or false
    needs[questID] = kind
    return kind or nil
end
function ns.PlannerNeedsGroupReset() needs = {} end

local function RecordName(questID)
    if not ns.PlannerSource then return nil end
    local okSource, src = pcall(ns.PlannerSource)
    if not okSource or type(src) ~= "table" or type(src.quest) ~= "function" then return nil end
    local ok, rec = pcall(src.quest, questID)
    return ok and type(rec) == "table" and Clean(rec.name) or nil
end

-- Does the button apply now, apart from which step you are on: the switch, the planned guide, the group setting
-- (not Solo, unless you are the duo friend), and no full party or raid.
local function Allowed(st)
    if not Unlocked() or not (ns.GuideOn and ns:GuideOn()) then return false end
    if type(st) ~= "table" or st.name == nil or st.name ~= ns.GUIDE_PLANNED then return false end
    if not ns.db or ns.db.plannerFindGroup == false then return false end
    if (ns.db.plannerGroup or "solo") == "solo" then
        local friend = ns.PlannerDuoRole and ns.PlannerDuoRole() == "friend"
        if not friend then return false end
    end
    if type(IsInRaid) == "function" and IsInRaid() then return false end
    if type(GetNumGroupMembers) == "function" and (tonumber(GetNumGroupMembers()) or 0) >= 5 then return false end
    return true
end
local function Qualifies(step)
    return type(step) == "table" and (step.kind == "accept" or step.kind == "do" or step.kind == "turnin")
        and type(step.quest) == "number" and ns.PlannerNeedsGroup(step.quest) ~= nil
end

-- The step you are on, when the button applies to it.
function ns.PlannerFindGroupStep(st, steps, at)
    if not Allowed(st) or type(steps) ~= "table" then return nil end
    local step = steps[tonumber(at) or 1]
    if Qualifies(step) then return step end
    return nil
end

local function Title(step)
    return Clean(step.title) or RecordName(step.quest) or (type(step.quest) == "number" and ("#" .. step.quest)) or nil
end
local function Cut(s, n)                                 -- (at most n bytes, cut before a whole character)
    if #s <= n then return s end
    n = math.max(0, n)
    while n > 0 do
        local c = s:byte(n + 1)
        if c and c >= 128 and c < 192 then n = n - 1 else break end
    end
    return s:sub(1, n)
end
local ZONE_MAX, MAX_LINE = 60, 200
local function ZoneName(map)
    if type(map) ~= "number" or not (C_Map and C_Map.GetMapInfo) then return nil end
    local ok, info = pcall(C_Map.GetMapInfo, map)
    local name = ok and type(info) == "table" and Clean(info.name) or nil
    return name and Cut(name, ZONE_MAX) or nil
end

-- "LFG <title>, <zone>" (no zone: "LFG <title>"), at most 200 bytes with `reserve` bytes more in front of it
-- (a "/4 " channel): the title is cut short, on a whole character, to fit. Never "LFG , <zone>": a title cut to
-- nothing gives way to the record's name (cut too), then "#<id>" (whole, never cut).
function ns.PlannerLFGText(step, reserve)
    if type(step) ~= "table" or type(step.quest) ~= "number" then return "" end   -- (no quest: no line at all, never "#nil")
    local title, zone = Title(step), ZoneName(step.map)
    local pattern = ns:Tr(zone and "LFG %s, %s" or "LFG %s")
    local fixed = #(zone and format(pattern, "", zone) or format(pattern, ""))
    local room, id = MAX_LINE - (tonumber(reserve) or 0) - fixed, "#" .. step.quest
    title = Cut(title, room)
    if title == "" then title = Cut(RecordName(step.quest) or "", room) end
    if title == "" then title = id end                 -- (a few bytes over the 200 only when nothing fits at all)
    return zone and format(pattern, title, zone) or format(pattern, title)
end

-- The channels you have joined, by name.
function ns.PlannerLFGChannels()
    local out = {}
    if type(GetChannelList) ~= "function" then return out end
    local ok, list = pcall(function() return { GetChannelList() } end)
    if not ok then return out end
    for i = 1, #list, 3 do
        local name = list[i + 1]
        if type(name) == "string" and not ns:IsSecret(name) and name ~= "" then out[#out + 1] = name end
    end
    return out
end

-- Put the line in your chat box (true), or print it for you to copy when the chat box can't be opened (false).
function ns.PlannerFindGroup(step)
    if not Unlocked() or type(step) ~= "table" then return false end
    local prefix = ""
    local channel = ns.db and ns.db.plannerLFGChannel
    if type(channel) == "string" and channel ~= "" then
        local n = 0
        if type(GetChannelName) == "function" then
            local ok, id = pcall(GetChannelName, channel)
            n = ok and floor(tonumber(id) or 0) or 0
        end
        if n > 0 then prefix = "/" .. n .. " "
        else ns:Print("You are not in %s: the line is in your chat box for its current channel.", channel) end
    end
    local text = ns.PlannerLFGText(step, #prefix)
    if text == "" then return false end
    text = prefix .. text
    local opener = type(ChatFrameUtil) == "table" and ChatFrameUtil.OpenChat
    local opened = false
    if type(opener) == "function" then opened = pcall(opener, text) and true or false end
    if not opened then ns:Print("Copy this line into your chat: %s", text) end
    return opened
end

local function Current()
    local st = ns.GuideState and ns.GuideState()
    if type(st) ~= "table" then return nil end
    local guide = type(st.plan) == "table" and st.plan or (ns.GuideGet and ns:GuideGet(st.name))
    return st, type(guide) == "table" and guide.steps or nil, tonumber(st.at) or 1
end

local function GroupLine(st, steps, at)
    local step = ns.PlannerFindGroupStep(st, steps, at)
    if not step then return nil end
    return format(ns:Tr("Group quest: %s"), Title(step))
end
ns.PlannerGroupLine = GroupLine
ns.GuideRegisterLine("findGroup", GroupLine)

-- (the panel's entry: the step you are on; a step's entry: that step's quest, when the button applies at all)
ns.GuideRegisterAction("panel", "findGroup", "Find a group", function(step) ns.PlannerFindGroup(step) end, function(step)
    local st, steps, at = Current()
    return step ~= nil and ns.PlannerFindGroupStep(st, steps, at) == step
end)
ns.GuideRegisterAction("step", "findGroup", "Find a group", function(step) ns.PlannerFindGroup(step) end, function(step)
    local st = Current()
    return Allowed(st) and Qualifies(step)
end)
