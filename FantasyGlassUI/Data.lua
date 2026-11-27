local _, ns = ...

------------------------------------------------------------------------------------------
-- 13.5: /fgui data, what each part of the add-on keeps and roughly how big, and /fgui data tidy, a tidy-up
-- that lists the old records it would remove and removes them only when the list's last line is clicked
-- twice. Nothing here ever removes anything by itself (no login, no timer). Long work runs as gold jobs
-- (ns.GoldJob: 4 ms slices, never in a fight).
------------------------------------------------------------------------------------------
local floor = math.floor
local Yield = function() ns.GoldYield() end

ns.DATA_PARTS = {
    { id = "settings", label = "Settings and profiles", keys = { "profiles", "chars", "history" } },
    { id = "guides", label = "Guides", keys = { "guides", "guideState" } },
    { id = "planner", label = "Route planner", prefix = "planner" },
    { id = "gold", label = "Ways to make gold", prefix = "gold" },
    { id = "prices", label = "Auction prices", keys = { "prices" } },
    { id = "backups", label = "Backups", keys = { "backups" } },
    { id = "other", label = "Everything else", rest = true },
}
ns.DATA_CHAR_DAYS = 180
ns.DATA_PRICE_DAYS = 30
ns.DATA_CONFIRM_SECONDS = 10

-- A table's keys, read in one pass: a job that waits between slices then walks this list, never the table
-- itself, so a table changed meanwhile (a recorder adding to it) is read as it is.
local function Keys(t)
    local list = {}
    for k in pairs(t) do list[#list + 1] = k end
    return list
end
ns.DataKeys = Keys

-- How many bytes a value takes, roughly: a string its length and its quotes, a number 8, a boolean 4,
-- a table 16 and its keys and values. Yields in a job.
local function Size(v, depth)
    local t = type(v)
    if t == "string" then return #v + 2 end
    if t == "number" then return 8 end
    if t == "boolean" then return 4 end
    if t ~= "table" or depth > 40 then return 0 end
    local n = 16
    for _, k in ipairs(Keys(v)) do
        n = n + Size(k, depth + 1) + Size(v[k], depth + 1)
        Yield()
    end
    return n
end
function ns.DataSize(v) return Size(v, 0) end

-- Which part a root key belongs to.
local function PartOf(key)
    if type(key) ~= "string" then return "other" end
    for _, p in ipairs(ns.DATA_PARTS) do
        for _, k in ipairs(p.keys or {}) do if k == key then return p.id end end
        if p.prefix and key:sub(1, #p.prefix) == p.prefix then return p.id end
    end
    return "other"
end
ns.DataPartOf = PartOf
function ns.DataSizes(root)
    local out = {}
    for _, p in ipairs(ns.DATA_PARTS) do out[p.id] = 0 end
    if type(root) ~= "table" then return out end
    for _, k in ipairs(Keys(root)) do
        local id = PartOf(k)
        out[id] = out[id] + Size(k, 0) + Size(root[k], 0)
    end
    return out
end
function ns.DataSizeText(bytes)
    bytes = tonumber(bytes) or 0
    if bytes < 1024 then return ns:Tr("under 1 KB") end
    if bytes < 1048576 then return format(ns:Tr("about %d KB"), floor(bytes / 1024 + 0.5)) end
    return format(ns:Tr("about %.1f MB"), bytes / 1048576)
end

------------------------------------------------------------------------------------------
-- What the tidy-up finds (nothing is changed while it looks):
--   char:    a character (never the one you are on) not played for DATA_CHAR_DAYS: every record kept for it
--            alone (any root store, or a store's sub-table, under its key), shown in groups. Its settings
--            profile stays (profiles are settings, kept in the backups, and deleted on the Profiles page).
--   prices:  an auction house's prices whose newest day (day, listedDay, seenDay) is over DATA_PRICE_DAYS old,
--            and the house itself when that leaves it empty and its last scan is as old.
--   trip:    another character's finished trip: what it paused takes its place.
--   guide:   another character following a written guide that no longer exists.
--   written: another character's places kept in written guides that no longer exist.
------------------------------------------------------------------------------------------
-- (stores never searched for a character's records: settings, their own backups, and the prices)
local NOT_CHAR_STORES = { profiles = true, backups = true, history = true, prices = true }
local CHAR_GROUPS = {
    { id = "planner", label = "Route planner" }, { id = "gold", label = "Ways to make gold" }, { id = "guides", label = "Guides" },
    { id = "alts", label = "Character list" }, { id = "inventory", label = "Bags and bank" }, { id = "other", label = "Everything else" },
}
local function GroupOf(store)
    if store:sub(1, 7) == "planner" then return "planner" end
    if store:sub(1, 4) == "gold" then return "gold" end
    if store == "guideState" or store == "guides" then return "guides" end
    if store == "alts" then return "alts" end
    if store == "inventory" then return "inventory" end
    return "other"
end
local function Num(v) return (type(v) == "number" and v == v) and v or nil end
-- When a character was last played (seconds), or nil when nothing says.
local function LastPlayed(root, key)
    local best
    local function Take(t) t = Num(t); if t and (not best or t > best) then best = t end end
    local info = type(root.charInfo) == "table" and root.charInfo[key]
    if type(info) == "table" then Take(info.last) end
    local alt = type(root.alts) == "table" and root.alts[key]
    if type(alt) == "table" then Take(alt.at) end
    local rec = type(root.planner) == "table" and root.planner[key]
    if type(rec) == "table" then Take(rec.lastSeen) end
    return best
end
-- Every character the saved data knows.
local function Characters(root)
    local seen, list = {}, {}
    for _, store in ipairs({ "chars", "charInfo", "alts", "planner", "guideState", "goldChars" }) do
        if type(root[store]) == "table" then
            for _, k in ipairs(Keys(root[store])) do
                if type(k) == "string" and k:find(" - ", 1, true) and not seen[k] then seen[k] = true; list[#list + 1] = k end
            end
        end
    end
    table.sort(list)
    return list, seen
end
-- Every record kept for `key` alone: { { store, sub|nil, group } }.
local function CharRecords(root, key, isChar)
    local out = {}
    local stores = Keys(root)
    table.sort(stores, function(a, b) return tostring(a) < tostring(b) end)
    for _, store in ipairs(stores) do
        local t = root[store]
        if type(store) == "string" and not NOT_CHAR_STORES[store] and type(t) == "table" then
            if t[key] ~= nil then out[#out + 1] = { store = store, group = GroupOf(store) } end
            for _, sub in ipairs(Keys(t)) do          -- (one level down: inventory.chars, checklist.done)
                local s = t[sub]
                if not isChar[sub] and type(s) == "table" and s[key] ~= nil then out[#out + 1] = { store = store, sub = sub, group = GroupOf(store) } end
                Yield()
            end
        end
    end
    return out
end
local function RecordValue(root, r)
    local t = root[r.store]
    if r.sub ~= nil then t = type(t) == "table" and t[r.sub] or nil end
    return type(t) == "table" and t or nil
end
local function GuideExists(root, name)
    return type(name) == "string" and ((type(root.guides) == "table" and type(root.guides[name]) == "table") or ns.builtinGuides[name] ~= nil)
end
local function Hidden(name) return type(name) == "string" and name:sub(1, 1) == "\1" end
local function FinishedTrip(st)
    return type(st) == "table" and st.name == ns.GUIDE_TRIP and type(st.trip) == "table" and type(st.trip.steps) == "table"
        and (Num(st.at) or 1) > #st.trip.steps
end
local function HouseName(key)
    local realm, faction = tostring(key):match("^(.*)|(.*)$")
    if not realm then return tostring(key) end
    faction = (faction == "Alliance" and ns:Tr("Alliance")) or (faction == "Horde" and ns:Tr("Horde")) or faction
    return realm .. " (" .. faction .. ")"
end

function ns.DataTidyFind(root, now, today, me)
    local finds = {}
    if type(root) ~= "table" then return finds end
    now, today = Num(now) or 0, Num(today) or 0
    local list, isChar = Characters(root)
    local old = {}
    -- characters not played for a long while
    for _, key in ipairs(list) do
        local last = key ~= me and LastPlayed(root, key)
        local days = last and floor((now - last) / 86400) or 0
        if last and days > ns.DATA_CHAR_DAYS then
            local records = CharRecords(root, key, isChar)
            local groups, byId, bytes = {}, {}, 0
            for _, g in ipairs(CHAR_GROUPS) do byId[g.id] = { id = g.id, label = g.label, bytes = 0, count = 0 } end
            for _, r in ipairs(records) do
                local t = RecordValue(root, r)
                local b = t and (Size(key, 0) + Size(t[key], 0)) or 0
                local g = byId[r.group]
                g.bytes, g.count = g.bytes + b, g.count + 1
                bytes = bytes + b
            end
            for _, g in ipairs(CHAR_GROUPS) do if byId[g.id].count > 0 then groups[#groups + 1] = byId[g.id] end end
            if #records > 0 then
                old[key] = true
                finds[#finds + 1] = { kind = "char", key = key, days = days, records = records, groups = groups, bytes = bytes, count = #records,
                    label = format(ns:Tr("%s, not played for %d days"), key, days) }
            end
        end
    end
    -- old auction prices, house by house
    local houses = type(root.prices) == "table" and type(root.prices.houses) == "table" and root.prices.houses or {}
    local houseKeys = Keys(houses)
    table.sort(houseKeys, function(a, b) return tostring(a) < tostring(b) end)
    for _, hk in ipairs(houseKeys) do
        local h = houses[hk]
        local items = type(h) == "table" and type(h.items) == "table" and h.items or nil
        if items then
            local ids, bytes, left = {}, 0, 0
            for _, id in ipairs(Keys(items)) do
                local e = items[id]
                local newest
                if type(e) == "table" then
                    for _, f in ipairs({ "day", "listedDay", "seenDay" }) do
                        local d = Num(e[f]); if d and (not newest or d > newest) then newest = d end
                    end
                end
                if newest and ns.DaysBetween(newest, today) > ns.DATA_PRICE_DAYS then
                    ids[#ids + 1] = id
                    bytes = bytes + Size(id, 0) + Size(e, 0)
                else
                    left = left + 1
                end
                Yield()
            end
            local scanAt = Num(h.scanAt)
            local house = left == 0 and scanAt ~= nil and (now - scanAt) > ns.DATA_PRICE_DAYS * 86400
            if #ids > 0 or house then
                table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)
                if house then bytes = Size(hk, 0) + Size(h, 0) end
                finds[#finds + 1] = { kind = "prices", key = hk, ids = ids, house = house or nil, bytes = bytes, count = #ids + (house and 1 or 0),
                    label = format(ns:Tr("Auction prices at %s older than %d days: %d"), HouseName(hk), ns.DATA_PRICE_DAYS, #ids) }
            end
        end
    end
    -- what guides left behind, for other characters
    local state = type(root.guideState) == "table" and root.guideState or {}
    local stateKeys = Keys(state)
    table.sort(stateKeys, function(a, b) return tostring(a) < tostring(b) end)
    for _, key in ipairs(stateKeys) do
        local st = state[key]
        if key ~= me and not old[key] and type(st) == "table" then
            local b = Size(key, 0) + Size(st, 0)
            if FinishedTrip(st) then
                finds[#finds + 1] = { kind = "trip", key = key, bytes = b, count = 1, label = format(ns:Tr("%s: a finished trip"), tostring(key)) }
            elseif type(st.name) == "string" and not Hidden(st.name) and not GuideExists(root, st.name) then
                finds[#finds + 1] = { kind = "guide", key = key, bytes = b, count = 1, guide = st.name,
                    label = format(ns:Tr("%s: follows a guide that no longer exists (%s)"), tostring(key), st.name) }
            end
            if type(st.written) == "table" and not (finds[#finds] and finds[#finds].kind == "guide" and finds[#finds].key == key) then
                local names, wb = {}, 0
                for _, name in ipairs(Keys(st.written)) do
                    if not GuideExists(root, name) then names[#names + 1] = name; wb = wb + Size(name, 0) + Size(st.written[name], 0) end
                end
                if #names > 0 then
                    table.sort(names, function(a, c) return tostring(a) < tostring(c) end)
                    local shown = {}
                    for i, n in ipairs(names) do shown[i] = tostring(n) end
                    finds[#finds + 1] = { kind = "written", key = key, names = names, bytes = wb, count = #names,
                        label = format(ns:Tr("%s: places kept in deleted guides (%s)"), tostring(key), table.concat(shown, ", ")) }
                end
            end
        end
    end
    return finds
end

-- Remove what the finds name, and nothing else. Returns how many records went.
function ns.DataTidyRemove(root, finds)
    local removed = 0
    if type(root) ~= "table" or type(finds) ~= "table" then return 0 end
    local mine = ns:CharKey()
    for _, f in ipairs(finds) do
        local key = type(f) == "table" and f.key
        if key == nil or (f.kind ~= "prices" and key == mine) then
            -- (never the character you are on)
        elseif f.kind == "char" then
            for _, r in ipairs(type(f.records) == "table" and f.records or {}) do
                local t = RecordValue(root, r)
                if t and t[key] ~= nil then t[key] = nil; removed = removed + 1 end
            end
        elseif f.kind == "prices" then
            local houses = type(root.prices) == "table" and type(root.prices.houses) == "table" and root.prices.houses or {}
            local h = houses[key]
            local items = type(h) == "table" and type(h.items) == "table" and h.items or nil
            if items then
                for _, id in ipairs(type(f.ids) == "table" and f.ids or {}) do
                    if items[id] ~= nil then items[id] = nil; removed = removed + 1 end
                    Yield()
                end
                if f.house and next(items) == nil then houses[key] = nil; removed = removed + 1 end
            end
        else
            local state = type(root.guideState) == "table" and root.guideState or {}
            local st = state[key]
            if type(st) == "table" then
                if f.kind == "trip" and FinishedTrip(st) then
                    state[key] = type(st.resume) == "table" and st.resume or nil
                    removed = removed + 1
                elseif f.kind == "guide" and st.name == f.guide then
                    state[key] = nil
                    removed = removed + 1
                elseif f.kind == "written" and type(st.written) == "table" then
                    for _, name in ipairs(type(f.names) == "table" and f.names or {}) do
                        if st.written[name] ~= nil then st.written[name] = nil; removed = removed + 1 end
                    end
                end
            end
        end
        Yield()
    end
    return removed
end

------------------------------------------------------------------------------------------
-- The windows. The tidy list's last line removes what it lists: a first click asks, a second within
-- DATA_CONFIRM_SECONDS does it (a later one starts over). `now`: when the list was shown (GetTime).
------------------------------------------------------------------------------------------
local function Grey(text) return "|cff9aa4b4" .. text .. "|r" end

function ns:DataTidyShow(finds, now)
    finds = type(finds) == "table" and finds or {}
    local lines = {}
    local total = 0
    for _, f in ipairs(finds) do
        total = total + (Num(f.bytes) or 0)
        lines[#lines + 1] = { left = f.label, right = Grey(ns.DataSizeText(f.bytes)) }
        for _, g in ipairs(f.groups or {}) do
            lines[#lines + 1] = { left = ns:Tr(g.label), right = Grey(ns.DataSizeText(g.bytes)), indent = 16, tone = "dim" }
        end
    end
    if #finds == 0 then
        lines[1] = { left = ns:Tr("Nothing to tidy up.") }
        ns:ShowList("DataTidy", "Tidy up saved data", lines, "Nothing is removed until you click the last line twice.", 520, 120)
        return #lines
    end
    local asked
    local w
    local remove = { action = true, right = Grey(ns.DataSizeText(total)) }
    local function Ask() remove.left = format(ns:Tr("Remove these %d (click twice)"), #finds) end
    remove.click = function(_, at)
        at = Num(at) or Num(GetTime and GetTime()) or Num(now) or 0
        if asked and at >= asked and at - asked <= ns.DATA_CONFIRM_SECONDS then
            asked = nil
            ns.GoldJob(function()
                local n = ns.DataTidyRemove(ns.root, finds)
                local size = ns.DataSizeText(total)
                ns:Print("Removed %d old records (about %s).", n, size)
                if w then w:SetLines({ { left = format(ns:Tr("Removed %d old records (about %s)."), n, size) } }) end
            end, "data tidy remove")
            return
        end
        if asked then asked = nil; Ask()                       -- (too late: it starts over)
        else asked = at; remove.left = ns:Tr("Click again within 10 seconds to remove them") end
        if w then w:SetLines(lines) end
    end
    Ask()
    lines[#lines + 1] = remove
    w = ns:ShowList("DataTidy", "Tidy up saved data", lines, "Nothing is removed until you click the last line twice.", 520, math.min(420, 80 + #lines * 18))
    return #lines
end

local function SizeLines(sizes)
    local lines = {}
    for _, p in ipairs(ns.DATA_PARTS) do
        lines[#lines + 1] = { left = ns:Tr(p.label), right = sizes and ns.DataSizeText(sizes[p.id]) or ns:Tr("Counting...") }
    end
    lines[#lines + 1] = { left = ns:Tr("Tidy up old records"), action = true, click = function() ns:DataCommand("tidy") end,
        tip = { ns:Tr("Tidy up old records"), ns:Tr("Lists characters not played in 180 days, old auction prices and what deleted guides left behind. Nothing is removed until you confirm.") } }
    return lines
end
function ns:DataCommand(text)
    local what = ns.Trim(text or ""):lower()
    if what == "tidy" then
        ns.GoldJob(function()
            local root = ns.root
            local finds = ns.DataTidyFind(root, time and time() or 0, ns.Today(), ns:CharKey())
            ns:DataTidyShow(finds, GetTime and GetTime() or 0)
        end, "data tidy")
        local lines = { { left = ns:Tr("Looking for old records..."), tone = "dim" } }
        ns:ShowList("DataTidy", "Tidy up saved data", lines, "Nothing is removed until you click the last line twice.", 520, 120)
        return #lines
    end
    local lines = SizeLines(nil)
    local w = ns:ShowList("SavedData", "Saved data", lines, "Roughly what each part keeps in the saved file, for every character.", 420, math.min(300, 80 + #lines * 18))
    ns.GoldJob(function()
        local sizes = ns.DataSizes(ns.root)
        if w then w:SetLines(SizeLines(sizes)) end
    end, "data sizes")
    return #lines
end
