local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Scan prices: a button on the auction house that asks for the whole list of auctions at once (the
-- game's own full-list call; the server allows it about every 15 minutes, for the whole account) and
-- reads it a few milliseconds a frame, never in a fight. The finished entries are built beside the store,
-- also in slices, then put into this auction house's prices (Prices.lua) in one short step, so nothing
-- ever sees half a scan. It never posts, buys or
-- bids: those stay your own clicks.
------------------------------------------------------------------------------------------
local COOLDOWN = 15 * 60                     -- (seconds between scans, as the server allows)
local WAIT = 60                              -- (seconds to wait for the list before giving up)
local RETRIES, RETRY_GAP = 3, 0.5            -- (rows whose item isn't loaded yet are read again)
local BUDGET_MS, ROWS_NO_CLOCK, CHUNK = 4, 200, 25

-- Ready to scan? Returns ready, and the seconds left when not.
function ns.PriceScanReady(now)
    local p = type(ns.root) == "table" and ns.root.prices
    local last = type(p) == "table" and p.lastScan
    if type(last) ~= "number" or type(now) ~= "number" then return true, 0 end
    local left = last + COOLDOWN - now
    if left <= 0 then return true, 0 end
    return false, left
end

-- Rows `from`..`to` of a list of `n` (counted from 0) into acc[itemID] = { low, listed }. read(i) gives
-- count, buyout, itemID. A row whose item can't be read yet is returned, to be read again; a row with a
-- hidden value is skipped and counted (the second return). A row with no buyout (bid only) counts as
-- listed but gives no price.
function ns.PriceScanRows(read, n, acc, from, to)
    local retry, skipped = {}, 0
    to = math.min(to, n - 1)
    for i = from, to do
        local ok, count, buyout, id = pcall(read, i)
        if not ok then
            retry[#retry + 1] = i
        elseif Secret(id) or Secret(count) or Secret(buyout) then
            skipped = skipped + 1                              -- (a hidden value is never stored)
        elseif type(id) ~= "number" then
            retry[#retry + 1] = i
        else
            count = (type(count) == "number" and count > 0) and count or 0
            buyout = (type(buyout) == "number" and buyout > 0) and buyout or 0
            local a = acc[id]
            if not a then a = { listed = 0 }; acc[id] = a end
            a.listed = a.listed + count
            if buyout > 0 then
                local unit = math.floor(buyout / math.max(1, count))
                if not a.low or unit < a.low then a.low = unit end
            end
        end
    end
    return retry, skipped
end

-- One item's finished entry, built beside the store (a copy: the store is not touched yet).
local function Stage(cur, a, today)
    local e = {}
    if type(cur) == "table" then
        for k, v in pairs(cur) do e[k] = v end
        if type(cur.hist) == "table" then
            e.hist = {}
            for d, p in pairs(cur.hist) do e.hist[d] = p end
        end
    end
    if a.low then
        e.price, e.day = a.low, today
        ns.AuctionHistoryAdd(e, today, a.low)
    elseif type(e.day) ~= "number" then
        e.day = today                                  -- (bid only, and new: kept as long as a price would be)
    end
    e.listed, e.listedDay = a.listed, today
    return e
end
-- Into the store, in one short pass that only assigns. A price noted while the entries were being built
-- (it differs from `bases`, the prices they were built from) is kept when it is lower. With `markUnlisted`, what the house knew that the scan did not list gets a
-- count of 0, and the house remembers this as a full scan (listedAt).
local function Commit(house, staged, today, now, n, markUnlisted, bases)
    if type(house.items) ~= "table" then house.items = {} end
    local items = house.items
    for id, e in pairs(staged) do
        local cur = items[id]
        if bases and type(cur) == "table" and cur.price ~= bases[id] then
            e.seenDay = cur.seenDay
            if cur.day == today and type(cur.price) == "number" and (type(e.price) ~= "number" or cur.price < e.price) then e.price, e.day = cur.price, today end
        end
        items[id] = e
    end
    if markUnlisted then
        for id, e in pairs(items) do
            if not staged[id] and type(e) == "table" then e.listed, e.listedDay = 0, today end
        end
        house.listedAt = now
    end
    house.scanAt, house.scanItems = now, n
end

-- The whole read into a house, at once (the scan itself does the same in slices): the lowest price and
-- the count for each item listed, and with `markUnlisted` (the default) a count of 0 for what it already
-- knew that nobody lists now. Returns how many items were read.
function ns.PriceScanWrite(house, acc, today, now, markUnlisted)
    local staged, n = {}, 0
    local items = type(house.items) == "table" and house.items or {}
    for id, a in pairs(acc) do staged[id] = Stage(items[id], a, today); n = n + 1 end
    Commit(house, staged, today, now, n, markUnlisted ~= false)
    return n
end

-- One row of the game's list: count (3rd), buyout (10th), item (17th).
local function GameRow(i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = C_AuctionHouse.GetReplicateItemInfo(i)
    return count, buyout, id
end

-- the read under way: { phase = waiting | reading | gap | writing, n, i, acc, retry, skipped, queue, qi,
--   tries, paused, staged, stageKey, count }
local scan
local button
local function Now() return (time and time()) or 0 end

local function Label(now)
    if scan then
        if scan.paused then return ns:Tr("Paused for combat") end
        if scan.phase == "waiting" then return ns:Tr("Waiting for the list…") end
        local done = (scan.n > 0) and math.floor(100 * math.min(scan.i, scan.n) / scan.n) or 100
        if scan.phase == "writing" then done = 100 end
        return format(ns:Tr("Reading %d%%"), done)
    end
    local ready, left = ns.PriceScanReady(now or Now())
    if ready then return ns:Tr("Scan prices") end
    left = math.ceil(left)
    return format(ns:Tr("Scan in %d:%02d"), math.floor(left / 60), left % 60)
end
local function Show()
    if button and button.text then button.text:SetText(Label()) end
end

local function Stop(message)
    scan = nil
    if message then ns:Print(message) end
    ns.priceScanState = message and ("stopped: " .. message) or "idle"
    Show()
end

-- Did the house hold more than `limit` items?
local function MoreThan(house, limit)
    local n = 0
    for _ in pairs(type(house) == "table" and type(house.items) == "table" and house.items or {}) do
        n = n + 1
        if n > limit then return true end
    end
    return false
end

-- The read is done: decide whether to trust it, then build the entries (in slices, from Read).
local function StartWriting(s)
    local house = ns.PriceHouse(false)
    if next(s.acc) == nil and MoreThan(house, 50) then
        Stop("The scan came back empty: try again later.")
        return
    end
    s.unread = s.skipped + #s.retry
    s.full = s.n > 0 and s.unread <= s.n * 0.01            -- (only a nearly whole list can say what nobody lists)
    s.staged, s.bases, s.count, s.stageKey, s.phase = {}, {}, 0, nil, "writing"
end

local function Finish()
    local s = scan
    scan = nil
    local house = ns.PriceHouse(true)
    if not house then Stop(); return 0 end
    Commit(house, s.staged, ns.Today(), Now(), s.count, s.full, s.bases)
    ns.priceScanState = format("last scan: %d items, %d of %d rows unread%s", s.count, s.unread, s.n, s.full and "" or " (too many to say what nobody lists)")
    ns:Print("Prices scanned: %d items.", s.count)
    if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end
    Show()
    return s.count
end

-- One slice: at most 4 ms (or 200 rows or entries where there is no clock). Never in a fight.
local function Read()
    local s = scan
    if not s or s.paused or (s.phase ~= "reading" and s.phase ~= "writing") then return end
    if InCombatLockdown() then s.paused = true; Show(); return end
    local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
    local start = clock and clock()
    local work = 0
    local function Spent() return (clock and clock() - start >= BUDGET_MS) or (not clock and work >= ROWS_NO_CLOCK) end
    if s.phase == "writing" then
        local house = ns.PriceHouse(false)
        local items = (house and type(house.items) == "table") and house.items or {}
        local today = ns.Today()
        repeat
            local id, a = next(s.acc, s.stageKey)              -- (acc is not changed while it is walked)
            if id == nil then Finish(); return end
            s.stageKey = id
            local cur = items[id]
            s.bases[id] = type(cur) == "table" and cur.price or false
            s.staged[id] = Stage(cur, a, today)
            s.count, work = s.count + 1, work + 1
        until Spent()
        return
    end
    repeat
        if s.queue then                                          -- (a pass over the rows to read again)
            local idx = s.queue[s.qi]
            if idx == nil then break end
            local again, skipped = ns.PriceScanRows(GameRow, s.n, s.acc, idx, idx)
            for _, r in ipairs(again) do s.retry[#s.retry + 1] = r end
            s.skipped = s.skipped + skipped
            s.qi, work = s.qi + 1, work + 1
        else
            if s.i >= s.n then break end
            local to = math.min(s.i + CHUNK - 1, s.n - 1)
            local again, skipped = ns.PriceScanRows(GameRow, s.n, s.acc, s.i, to)
            for _, r in ipairs(again) do s.retry[#s.retry + 1] = r end
            s.skipped = s.skipped + skipped
            work = work + (to - s.i + 1)
            s.i = to + 1
        end
    until Spent()
    local passDone = (s.queue and s.queue[s.qi] == nil) or (not s.queue and s.i >= s.n)
    if not passDone then return end
    if #s.retry > 0 and s.tries < RETRIES then
        s.tries = s.tries + 1
        s.queue, s.qi, s.retry = s.retry, 1, {}
        s.phase = "gap"
        ns:After(RETRY_GAP, function() if scan == s and s.phase == "gap" then s.phase = "reading" end end)
        return
    end
    StartWriting(s)
end

-- The list has arrived: how many rows, then read it.
local function Arrived()
    local s = scan
    if not s or s.phase ~= "waiting" then return end
    local ok, n = pcall(C_AuctionHouse.GetNumReplicateItems)
    if not ok or Secret(n) or type(n) ~= "number" then Stop("The auction house did not send its list: try again later."); return end
    s.n, s.i, s.phase = math.max(0, n), 0, "reading"
    Show()
end

function ns:PriceScanStart()
    if scan or InCombatLockdown() then return false end
    local A = C_AuctionHouse
    if type(A) ~= "table" or type(A.ReplicateItems) ~= "function" or type(A.GetReplicateItemInfo) ~= "function" then return false end
    local now = Now()
    if not ns.PriceScanReady(now) or not ns.PriceHouseKey() or type(ns.root) ~= "table" then return false end
    if not pcall(A.ReplicateItems) then return false end
    if type(ns.root.prices) ~= "table" then ns.root.prices = { v = 1 } end
    ns.root.prices.lastScan = now                             -- (the server counts the call, read or not)
    local s = { phase = "waiting", n = 0, i = 0, acc = {}, retry = {}, skipped = 0, tries = 0 }
    scan = s
    ns.priceScanState = "waiting for the list"
    ns:After(WAIT, function()
        if scan == s and s.phase == "waiting" then Stop("The auction house did not send its list: try again later.") end
    end)
    Show()
    return true
end

ns:NewModule("auctionScan", function()
    ns.PricesBegin()
    ns.priceScanState = "on; waiting for the auction house"
    local done = false
    local function Dress()
        local ahf = _G.AuctionHouseFrame
        if done or type(ahf) ~= "table" then return false end
        done = true
        button = ns:CreateButton(ahf, "Scan prices", 150, 22, function()
            if InCombatLockdown() then return end
            ns:PriceScanStart()
        end)
        button:SetPoint("TOPRIGHT", ahf, "TOPRIGHT", -186, -30)        -- (left of Worth selling)
        ns:ButtonTip(button, function()
            return ns:Tr("Reads every auction at once for the prices in tooltips. The auction house allows this about every 15 minutes.")
                .. "\n" .. ns.PriceFreshText(ns.PriceHouse(), Now())
        end)
        local tick = 0
        button:SetScript("OnUpdate", function(_, elapsed)                -- (only while the auction house is shown)
            tick = tick + (tonumber(elapsed) or 0)
            if tick >= 1 then tick = 0; Show() end
        end)
        Show()
        return true
    end
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", ns:Guard("Scan prices", function() if scan then Read() end end))
    ns.auctionScanTest = { Dress = Dress, Label = Label }
    ns.priceScanTest = { Read = Read, state = function() return scan end }
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "ADDON_LOADED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "REPLICATE_ITEM_LIST_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Scan prices", function(_, event, name)
        if event == "ADDON_LOADED" then
            if not Secret(name) and name == "Blizzard_AuctionHouseUI" then pcall(Dress) end
        elseif event == "AUCTION_HOUSE_SHOW" then
            pcall(Dress)
            Show()
        elseif event == "AUCTION_HOUSE_CLOSED" then
            if scan then Stop("The auction house closed before the scan was read: scan again when it allows.") end
        elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
            Arrived()
        elseif event == "PLAYER_REGEN_DISABLED" then
            if scan then scan.paused = true; Show() end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if scan then scan.paused = nil; Show() end
        end
    end))
end)
