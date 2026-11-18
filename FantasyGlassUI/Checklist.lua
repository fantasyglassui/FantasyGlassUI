local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Weekly checklist (11.0.1): your own daily and weekly jobs, ticked per character and cleared by
-- themselves when the game's daily or weekly reset comes round, with each character's lockouts and
-- once-a-day crafts in the same window.
--   /fgui checklist                      the checklist (also the Tools tab)
--   /fgui checklist add daily <job>      /fgui checklist add weekly <job>      /fgui checklist remove 2
-- In the window: click a job to tick it for this character, right-click to remove it.
------------------------------------------------------------------------------------------
local function Store()
    if type(ns.root) ~= "table" then return { items = {}, done = {}, nextId = 1 } end
    local c = ns.root.checklist
    if type(c) ~= "table" then c = {}; ns.root.checklist = c end
    if type(c.items) ~= "table" then c.items = {} end
    if type(c.done) ~= "table" then c.done = {} end
    c.nextId = tonumber(c.nextId) or 1
    return c
end
ns.ChecklistStore = Store

-- Seconds to the next daily and weekly reset (nil where the game does not say).
local function Untils()
    local D = C_DateAndTime
    local daily, weekly
    if D and D.GetSecondsUntilDailyReset then local ok, v = pcall(D.GetSecondsUntilDailyReset); if ok and type(v) == "number" and not Secret(v) then daily = v end end
    if D and D.GetSecondsUntilWeeklyReset then local ok, v = pcall(D.GetSecondsUntilWeeklyReset); if ok and type(v) == "number" and not Secret(v) then weekly = v end end
    return daily, weekly
end
-- A name for the reset period we are in: the minute the next reset falls on. The same all period long,
-- different after the reset.
function ns.ChecklistStamp(now, untilReset)
    if type(untilReset) ~= "number" then return nil end
    return math.floor(((tonumber(now) or 0) + untilReset + 30) / 60)
end
function ns.ChecklistDone(store, char, item, stamps)
    local mine = store.done[char]
    local at = type(mine) == "table" and mine[item.id]
    local now = stamps[item.period]
    return at ~= nil and now ~= nil and at == now
end
function ns.ChecklistToggle(store, char, item, stamps)
    store.done[char] = store.done[char] or {}
    if ns.ChecklistDone(store, char, item, stamps) then store.done[char][item.id] = nil; return false end
    store.done[char][item.id] = stamps[item.period]
    return true
end
function ns.ChecklistAdd(store, period, text)
    period = (period == "weekly") and "weekly" or "daily"
    text = ns.Trim(text)
    if text == "" then return nil end
    local item = { id = store.nextId, period = period, text = text }
    store.nextId = store.nextId + 1
    store.items[#store.items + 1] = item
    return item
end
local function Stamps()
    local now = time and time() or 0
    local daily, weekly = Untils()
    return { daily = ns.ChecklistStamp(now, daily), weekly = ns.ChecklistStamp(now, weekly) }, daily, weekly
end
ns.ChecklistStamps = Stamps
-- How many of a period's jobs a character has done: done, total.
function ns.ChecklistCount(store, char, period, stamps)
    local done, total = 0, 0
    for _, item in ipairs(store.items) do
        if item.period == period then
            total = total + 1
            if ns.ChecklistDone(store, char, item, stamps) then done = done + 1 end
        end
    end
    return done, total
end

function ns:ShowChecklist()
    local store = Store()
    local stamps, daily, weekly = Stamps()
    local me = ns:CharKey()
    local short = ns.ShortTime or function(s) return tostring(math.floor((s or 0) / 60)) .. "m" end
    local lines = {}
    local head = {}
    if daily then head[#head + 1] = ns:Tr("Daily reset in") .. " " .. short(daily) end
    if weekly then head[#head + 1] = ns:Tr("Weekly reset in") .. " " .. ((weekly >= 86400) and format(ns:Tr("%dd %dh"), math.floor(weekly / 86400), math.floor(weekly % 86400 / 3600)) or short(weekly)) end
    lines[#lines + 1] = { left = "|cff9aa4b4" .. table.concat(head, "   ") .. "|r" }
    for _, period in ipairs({ "daily", "weekly" }) do
        local done, total = ns.ChecklistCount(store, me, period, stamps)
        lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr(period == "daily" and "Daily" or "Weekly") .. "|r", right = total > 0 and format("%d / %d", done, total) or "" }
        for i, item in ipairs(store.items) do
            if item.period == period then
                local ok = ns.ChecklistDone(store, me, item, stamps)
                lines[#lines + 1] = { left = (ok and "|cff33ff66[x]|r  |cff9aa4b4" or "[ ]  |cffffffff") .. item.text .. "|r",
                    click = function(button)
                        if button == "RightButton" then
                            for k, it in ipairs(store.items) do if it.id == item.id then table.remove(store.items, k) end end
                        else
                            ns.ChecklistToggle(store, me, item, stamps)
                        end
                        ns:ShowChecklist()
                    end,
                    tip = { item.text, ns:Tr("Click: done or not, for this character. Right-click: remove it.") } }
            end
        end
        if total == 0 then lines[#lines + 1] = { left = "|cff9aa4b4    " .. format(ns:Tr("None yet: /fgui checklist add %s <job>"), period) .. "|r" } end
    end
    -- this character's lockouts, and once-a-day crafts that are ready on any character
    if ns.RecordLockouts then pcall(ns.RecordLockouts, ns) end
    local alts = type(ns.root) == "table" and ns.root.alts or {}
    local mine = alts[me]
    local locked = 0
    local now = time and time() or 0
    for _, l in ipairs(type(mine) == "table" and type(mine.lockouts) == "table" and mine.lockouts or {}) do
        if (l.ends or 0) > now then
            if locked == 0 then lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Lockouts") .. "|r" } end
            locked = locked + 1
            lines[#lines + 1] = { left = "    " .. l.name, right = format("%d/%d", l.done or 0, l.bosses or 0) }
        end
    end
    if ns.ProfCDLines and type(ns.root) == "table" and type(ns.root.profCD) == "table" then
        local ready = {}
        for _, l in ipairs(ns.ProfCDLines(ns.root.profCD, now)) do if l.left <= 0 then ready[#ready + 1] = l end end
        if #ready > 0 then
            lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Ready to craft") .. "|r" }
            for _, l in ipairs(ready) do lines[#lines + 1] = { left = "    " .. tostring(l.name), right = "|cff9aa4b4" .. tostring(l.char):gsub(" %- .*$", "") .. "|r" } end
        end
    end
    -- the other characters, in a line each
    local others = {}
    for char in pairs(store.done) do if char ~= me then others[#others + 1] = char end end
    table.sort(others)
    if #others > 0 and #store.items > 0 then
        lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Your other characters") .. "|r" }
        for _, char in ipairs(others) do
            local d1, t1 = ns.ChecklistCount(store, char, "daily", stamps)
            local d2, t2 = ns.ChecklistCount(store, char, "weekly", stamps)
            lines[#lines + 1] = { left = "    " .. char:gsub(" %- .*$", ""), right = format("%s %d/%d   %s %d/%d", ns:Tr("daily"), d1, t1, ns:Tr("weekly"), d2, t2) }
        end
    end
    return ns:ShowList("Checklist", "Checklist", lines, "Ticks clear themselves at the game's daily and weekly resets.", 460, 420)
end

function ns:ChecklistCommand(text)
    text = ns.Trim(text)
    local word, rest = text:match("^(%S+)%s*(.*)$")
    word = word and word:lower()
    local store = Store()
    if word == "add" then
        local period, job = rest:match("^(%S+)%s+(.+)$")
        period = period and period:lower()
        if period ~= "daily" and period ~= "weekly" then job, period = rest, "daily" end
        local item = ns.ChecklistAdd(store, period, job or "")
        if item then ns:Print("Added to the %s checklist: %s", ns:Tr(item.period), item.text) else ns:Print("What is the job? /fgui checklist add daily Cooking quest") end
    elseif word == "remove" then
        local n = tonumber(rest)
        if n and store.items[n] then local gone = table.remove(store.items, n); ns:Print("Removed: %s", gone.text)
        else ns:Print("There is no job %s on the checklist. Right-click a job in the window to remove it.", rest ~= "" and rest or "?") end
    elseif word == "clear" then
        store.done[ns:CharKey()] = {}
        ns:Print("This character's ticks are cleared.")
    end
    return ns:ShowChecklist()
end
