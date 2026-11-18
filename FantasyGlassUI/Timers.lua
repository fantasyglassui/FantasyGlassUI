local _, ns = ...

------------------------------------------------------------------------------------------
-- Timers: /fgui timer 5m bread puts a small countdown bar on screen and tells you when it ends.
--   /fgui timer 90s        /fgui timer 1h30m raid       /fgui timer 2:30 pull       /fgui timer 10 tea
-- (a bare number is minutes). Click a bar to cancel it; /fgui timer off cancels them all. Up to six
-- at once. They survive a reload: what is kept is when each one ends.
------------------------------------------------------------------------------------------
local MAX = 6

-- "5m bread" -> 300, "bread". Nil when there is no time at the front.
function ns.ParseDuration(text)
    if type(text) ~= "string" then return nil end
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    local first, rest = text:match("^(%S+)%s*(.*)$")
    if not first then return nil end
    local seconds
    local m, s = first:match("^(%d+):(%d%d?)$")
    if m then
        seconds = tonumber(m) * 60 + tonumber(s)
    elseif first:match("^%d+%.?%d*$") then
        seconds = tonumber(first) * 60
    else
        local total, used = 0, 0
        for number, unit in first:lower():gmatch("(%d+%.?%d*)([hms])") do
            total = total + tonumber(number) * ((unit == "h" and 3600) or (unit == "m" and 60) or 1)
            used = used + #number + 1
        end
        if used == #first and used > 0 then seconds = total end
    end
    if not seconds or seconds <= 0 or seconds > 24 * 3600 then return nil end
    return math.floor(seconds + 0.5), rest
end
-- 754 -> "12:34", 4000 -> "1:06:40"
function ns.TimerText(seconds)
    seconds = math.max(0, math.ceil(seconds))
    if seconds >= 3600 then return format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60) end
    return format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local holder
local timers = {}                                             -- { label, ends (clock time), length, bar }
local bars = {}

local function Saved()
    if type(ns.root) ~= "table" then return nil end
    if type(ns.root.timers) ~= "table" then ns.root.timers = {} end
    return ns.root.timers
end
local function Store()
    local saved = Saved()
    if not saved then return end
    local out = {}
    for i, t in ipairs(timers) do out[i] = { label = t.label, ends = t.ends, length = t.length } end
    saved[ns:CharKey()] = (#out > 0) and out or nil
end

local function Layout()
    for i, bar in ipairs(bars) do
        local t = timers[i]
        if t then
            bar.timer = t
            bar.name:SetText(t.label ~= "" and t.label or ns:Tr("Timer"))
            bar:SetMinMaxValues(0, math.max(1, t.length))
            bar:Show()
        else
            bar.timer = nil
            bar:Hide()
        end
    end
end
local function Remove(t)
    for i = #timers, 1, -1 do if timers[i] == t then table.remove(timers, i) end end
    Layout()
    Store()
end
local function Build()
    if holder then return end
    holder = CreateFrame("Frame", "FantasyGlassUITimers", UIParent)
    holder:SetSize(200, 20)
    holder:SetPoint("TOP", UIParent, "TOP", 0, -150)
    for i = 1, MAX do
        local bar = ns:NewStatusBar(holder, true)
        bar:SetSize(200, 18)
        bar:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * 21)
        ns:Paint(bar, "SetStatusBarColor", "@accent")
        bar.name = ns:NewText(bar, 11, "LEFT")
        bar.name:SetPoint("LEFT", 6, 0)
        bar.time = ns:NewText(bar, 11, "RIGHT")
        bar.time:SetPoint("RIGHT", -6, 0)
        bar.name:SetPoint("RIGHT", bar.time, "LEFT", -6, 0)
        bar:EnableMouse(true)
        bar:SetScript("OnMouseUp", function(self) if self.timer then Remove(self.timer) end end)
        bar:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(ns:Tr("Click to cancel this timer"))
            GameTooltip:Show()
        end)
        bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
        bar:Hide()
        bars[i] = bar
    end
    local idle = false
    holder:SetScript("OnUpdate", ns:Guard("Timers", function()
        if idle and #timers == 0 then return end              -- (nothing running: nothing to do, every frame)
        local now = time and time() or 0
        for i = #timers, 1, -1 do
            local t = timers[i]
            local left = t.ends - now
            if left <= 0 then
                table.remove(timers, i)
                ns:TimerDone(t)
            end
        end
        if #timers == 0 then Layout(); idle = true; return end
        idle = false
        local fine = GetTime and GetTime() or 0               -- (the clock counts whole seconds: smooth the bar between them)
        for _, bar in ipairs(bars) do
            local t = bar.timer
            if t then
                local left = (t.ends - now) - (fine % 1)
                bar:SetValue(math.max(0, left))
                bar.time:SetText(ns.TimerText(t.ends - now))
            end
        end
    end))
    ns:RegisterMovable(holder, "timers", "Timers")
end

function ns:TimerDone(t)
    Layout()
    Store()
    local label = t.label ~= "" and t.label or ns:Tr("Timer")
    ns:Print("Timer finished: %s", label)
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.ALARM_CLOCK_WARNING_3 or SOUNDKIT.READY_CHECK or 8960, "Master") end
    if ns.Toast then pcall(ns.Toast, ns, nil, ns:Tr("Timer finished"), label, "!") end
end

-- Start one. Returns the timer, or nil and why not.
function ns:StartTimer(seconds, label)
    if type(seconds) ~= "number" or seconds <= 0 then return nil, "no time given" end      -- (reasons are in the translations: ns:Tr(why))
    if #timers >= MAX then return nil, "six timers are running already" end
    Build()
    local t = { label = tostring(label or ""), ends = (time and time() or 0) + seconds, length = seconds }
    timers[#timers + 1] = t
    table.sort(timers, function(a, b) return a.ends < b.ends end)
    Layout()
    Store()
    return t
end
function ns:ClearTimers()
    for i = #timers, 1, -1 do timers[i] = nil end
    if holder then Layout() end
    Store()
end
function ns:TimerList() return timers end

-- /fgui timer ...
function ns:TimerCommand(text)
    text = type(text) == "string" and text:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if text == "" then
        if #timers == 0 then
            ns:Print("No timers running. Start one with /fgui timer 5m bread (also 90s, 1h30m, 2:30; a bare number is minutes).")
        else
            local now = time and time() or 0
            for _, t in ipairs(timers) do ns:Print("%s: %s left", t.label ~= "" and t.label or ns:Tr("Timer"), ns.TimerText(t.ends - now)) end
        end
        return
    end
    if text:lower() == "off" or text:lower() == "clear" then
        ns:ClearTimers()
        ns:Print("Timers cleared.")
        return
    end
    local seconds, label = ns.ParseDuration(text)
    if not seconds then
        ns:Print("That is not a length of time. Try /fgui timer 5m bread (also 90s, 1h30m, 2:30; a bare number is minutes).")
        return
    end
    local t, why = ns:StartTimer(seconds, label)
    if t then ns:Print("Timer started: %s (%s).", (label ~= "" and label) or ns:Tr("Timer"), ns.TimerText(seconds))
    else ns:Print("No timer started: %s.", ns:Tr(tostring(why))) end
end

-- timers that were running when you last logged out or reloaded
do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:SetScript("OnEvent", ns:Guard("Timers", function()
        ns:After(2, function()
            local saved = Saved()
            local mine = saved and saved[ns:CharKey()]
            if type(mine) ~= "table" then return end
            local now = time and time() or 0
            for _, t in ipairs(mine) do
                if type(t) == "table" and type(t.ends) == "number" and t.ends > now and #timers < MAX then
                    Build()
                    timers[#timers + 1] = { label = tostring(t.label or ""), ends = t.ends, length = tonumber(t.length) or (t.ends - now) }
                end
            end
            if holder then table.sort(timers, function(a, b) return a.ends < b.ends end); Layout() end
            Store()
        end)
    end))
end
