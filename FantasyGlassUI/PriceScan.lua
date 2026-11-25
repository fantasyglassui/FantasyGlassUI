local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Scan prices: a button on the auction house that asks for the whole list of auctions at once (the
-- game's own full-list call; the server allows it about every 15 minutes, for the whole account) and
-- reads it a few milliseconds a frame, never in a fight. What it read goes into this auction house's
-- prices (Prices.lua) in one go at the end, so nothing ever sees half a scan. It never posts, buys or
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
-- hidden value is skipped. A row with no buyout (bid only) counts as listed but gives no price.
function ns.PriceScanRows(read, n, acc, from, to)
    local retry = {}
    to = math.min(to, n - 1)
    for i = from, to do
        local ok, count, buyout, id = pcall(read, i)
        if not ok then
            retry[#retry + 1] = i
        elseif Secret(id) or Secret(count) or Secret(buyout) then
            -- (a hidden value is never stored)
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
    return retry
end

-- The whole read into a house, at once: the lowest price and the count for each item listed, and a
-- count of 0 for what it already knew that nobody lists now. Returns how many items were read.
function ns.PriceScanWrite(house, acc, today, now)
    if type(house.items) ~= "table" then house.items = {} end
    local items, n = house.items, 0
    for id, a in pairs(acc) do
        local e = items[id]
        if type(e) ~= "table" then e = {}; items[id] = e end
        if a.low then
            e.price, e.day = a.low, today
            ns.AuctionHistoryAdd(e, today, a.low)
        elseif type(e.day) ~= "number" then
            e.day = today                                  -- (bid only, and new: kept as long as a price would be)
        end
        e.listed, e.listedDay = a.listed, today
        n = n + 1
    end
    for id, e in pairs(items) do
        if not acc[id] and type(e) == "table" then e.listed, e.listedDay = 0, today end
    end
    house.scanAt, house.scanItems = now, n
    return n
end

-- One row of the game's list: count (3rd), buyout (10th), item (17th).
local function GameRow(i)
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, id = C_AuctionHouse.GetReplicateItemInfo(i)
    return count, buyout, id
end

local scan                                   -- the read under way: { phase, n, i, acc, retry, queue, qi, tries, paused }
local button
local function Now() return (time and time()) or 0 end

local function Label(now)
    if scan then
        local done = 0
        if scan.phase == "reading" or scan.phase == "gap" then done = (scan.n > 0) and math.floor(100 * math.min(scan.i, scan.n) / scan.n) or 100 end
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

local function Finish()
    local s = scan
    scan = nil
    local house = ns.PriceHouse(true)
    if not house then Stop(); return 0 end
    local n = ns.PriceScanWrite(house, s.acc, ns.Today(), Now())
    ns.priceScanState = format("last scan: %d items, %d rows unread", n, #s.retry)
    ns:Print("Prices scanned: %d items.", n)
    if ns.RefreshBagWindow then pcall(ns.RefreshBagWindow, ns) end
    Show()
    return n
end

-- One slice of the read: at most 4 ms (or 200 rows where there is no clock). Never in a fight.
local function Read()
    local s = scan
    if not s or s.phase ~= "reading" or s.paused then return end
    if InCombatLockdown() then s.paused = true; return end
    local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
    local start = clock and clock()
    local rows = 0
    repeat
        if s.queue then                                          -- (a pass over the rows to read again)
            local idx = s.queue[s.qi]
            if idx == nil then break end
            for _, r in ipairs(ns.PriceScanRows(GameRow, s.n, s.acc, idx, idx)) do s.retry[#s.retry + 1] = r end
            s.qi, rows = s.qi + 1, rows + 1
        else
            if s.i >= s.n then break end
            local to = math.min(s.i + CHUNK - 1, s.n - 1)
            for _, r in ipairs(ns.PriceScanRows(GameRow, s.n, s.acc, s.i, to)) do s.retry[#s.retry + 1] = r end
            rows = rows + (to - s.i + 1)
            s.i = to + 1
        end
    until (clock and clock() - start >= BUDGET_MS) or (not clock and rows >= ROWS_NO_CLOCK)
    local passDone = (s.queue and s.queue[s.qi] == nil) or (not s.queue and s.i >= s.n)
    if not passDone then return end
    if #s.retry > 0 and s.tries < RETRIES then
        s.tries = s.tries + 1
        s.queue, s.qi, s.retry = s.retry, 1, {}
        s.phase = "gap"
        ns:After(RETRY_GAP, function() if scan == s and s.phase == "gap" then s.phase = "reading" end end)
        return
    end
    Finish()
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
    local s = { phase = "waiting", n = 0, i = 0, acc = {}, retry = {}, tries = 0 }
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
        button = ns:CreateButton(ahf, "Scan prices", 120, 22, function()
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
            if scan then scan.paused = true end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if scan then scan.paused = nil end
        end
    end))
end)
