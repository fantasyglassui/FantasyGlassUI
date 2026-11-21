local ADDON, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- 10.9: a first-run tour, "What's this?" mode, where to level next, profession cooldowns across your
-- characters, and a performance view.
------------------------------------------------------------------------------------------
local function Clock(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local d, h, m = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    if d > 0 then return format(ns:Tr("%dd %dh"), d, h) end
    if h > 0 then return format(ns:Tr("%dh %02dm"), h, m) end
    return format(ns:Tr("%dm"), math.max(1, m))
end
ns.LongClock = Clock

-- The label of a feature switch, from the options (when they are loaded) or nil.
local function SwitchLabel(key)
    for _, group in ipairs(ns.featureGroups or {}) do
        for _, opt in ipairs(group[2] or {}) do if opt[1] == key then return opt[2] end end
    end
end
-- Open the options at a feature's switch.
function ns:ShowSwitch(key)
    if not ns:LoadOptions() then return false end
    local label = SwitchLabel(key)
    if label and ns.GuideShow then return ns:GuideShow({ tab = "sections", find = label }) end
    ns:ToggleConfig("features")
    return "tab"
end

------------------------------------------------------------------------------------------
-- A callout: a glass card pointing at something on screen, with a ring round it.
------------------------------------------------------------------------------------------
local callout
local function Callout()
    if callout then return callout end
    local c = CreateFrame("Frame", "FantasyGlassUICallout", UIParent, ns.template)
    c:SetSize(300, 130)
    c:SetFrameStrata("FULLSCREEN_DIALOG")
    if c.SetClampedToScreen then c:SetClampedToScreen(true) end       -- (a panel near the screen's edge: the card stays in sight)
    c:SetBackdrop(ns.BACKDROP)
    ns:Paint(c, "SetBackdropColor", "window", 0.97)
    ns:Paint(c, "SetBackdropBorderColor", "@accent", 1)
    ns:Dress(c)
    c:EnableMouse(true)
    c.step = ns:NewText(c, 10, "LEFT")
    c.step:SetPoint("TOPLEFT", 12, -10)
    ns:Paint(c.step, "SetTextColor", "faint")
    c.title = c:CreateFontString(nil, "OVERLAY")
    ns:Font(c.title, 15, true)
    c.title:SetPoint("TOPLEFT", 12, -24)
    ns:Paint(c.title, "SetTextColor", "@accent")
    c.text = ns:NewText(c, 12, "LEFT")
    c.text:SetPoint("TOPLEFT", 12, -46)
    c.text:SetWidth(276)
    c.text:SetJustifyV("TOP")
    c.next = ns:CreateButton(c, "Next", 80, 22, function() if c.onNext then c.onNext() end end)
    c.next:SetPoint("BOTTOMRIGHT", -10, 10)
    c.back = ns:CreateButton(c, "Back", 70, 22, function() if c.onBack then c.onBack() end end)
    c.back:SetPoint("RIGHT", c.next, "LEFT", -6, 0)
    c.close = ns:CreateButton(c, "Close", 70, 22, function() if c.onClose then c.onClose() end end)
    c.close:SetPoint("BOTTOMLEFT", 10, 10)
    c.ring = CreateFrame("Frame", nil, UIParent, ns.template)
    c.ring:SetFrameStrata("FULLSCREEN_DIALOG")
    c.ring:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = 2 })
    ns:Paint(c.ring, "SetBackdropBorderColor", "@accent", 1)
    c.ring:Hide()
    local pulse = c.ring.CreateAnimationGroup and c.ring:CreateAnimationGroup()
    if pulse then
        pulse:SetLooping("BOUNCE")
        local a = pulse:CreateAnimation("Alpha")
        a:SetFromAlpha(1); a:SetToAlpha(0.35); a:SetDuration(0.7)
        c.pulse = pulse
    end
    c:Hide()
    callout = c
    return c
end
-- Point the card at `target` (a frame), or put it in the middle when there is nothing to point at.
local function PointAt(c, target)
    c:ClearAllPoints()
    c.ring:Hide()
    local shown = type(target) == "table" and target.IsVisible and ns.Yes(select(2, pcall(target.IsVisible, target)))
    if not shown then c:SetPoint("CENTER", UIParent, "CENTER", 0, 60); return false end
    c.ring:ClearAllPoints()
    c.ring:SetPoint("TOPLEFT", target, "TOPLEFT", -5, 5)
    c.ring:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 5, -5)
    c.ring:Show()
    if c.pulse and ns:Motion() then c.pulse:Play() end
    -- the card goes on whichever side of the target has room
    local okX, x = pcall(target.GetCenter, target)
    local okY, _, y = pcall(target.GetCenter, target)
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if not (okX and okY and type(x) == "number" and type(y) == "number") or Secret(x) then c:SetPoint("CENTER", UIParent, "CENTER", 0, 60); return true end
    if y > h * 0.6 then c:SetPoint("TOP", target, "BOTTOM", 0, -16)
    elseif y < h * 0.4 then c:SetPoint("BOTTOM", target, "TOP", 0, 16)
    elseif x > w / 2 then c:SetPoint("RIGHT", target, "LEFT", -16, 0)
    else c:SetPoint("LEFT", target, "RIGHT", 16, 0) end
    return true
end

------------------------------------------------------------------------------------------
-- First-run tour: once, after the setup, a few cards pointing at the main parts of the interface.
-- /fgui tour plays it again.
------------------------------------------------------------------------------------------
ns.TOUR = {
    { frame = "FantasyGlassUI_Player", title = "Your frames", text = "Your health, power and buffs, with your target's beside them. Right-click a frame for its menu. /fgui move lets you drag any panel." },
    { frame = "FantasyGlassUIInfoBar", title = "The info bar", text = "Time, gold, bags, durability, friends and more. Click a piece for its window; right-click the bar to choose the pieces." },
    { frame = "FantasyGlassUIMinimap", title = "Minimap and add-ons", text = "Other add-ons' minimap buttons are gathered into one Add-ons button here. Right-click the minimap for tracking." },
    { frame = "FantasyGlassUITracker", title = "Quests", text = "Your quests, with the experience and gold each one gives. Click a quest to open it; the + and - fold the list." },
    { frame = "ChatFrame1", title = "Chat", text = "Links, a copy button and your name picked out in chat. Alt-click a name to invite." },
    { title = "Options", text = "Type /fgui for the settings: every feature by category, themes under Look and themes, and a search that finds any setting." },
    { title = "Ask the guide", text = "Not sure where something is? On the Home page of /fgui, ask the guide in plain words, such as how do I make the bars bigger, and it shows you." },
    { title = "What's this?", text = "Type /fgui whatsthis (or set a key for it) and point at any panel: it tells you which feature made it, and takes you to its switch." },
}
local tourAt   -- luacheck: ignore
function ns:TourStep(i)
    local c = Callout()
    local steps = ns.TOUR
    if not i or i < 1 or i > #steps then
        c:Hide(); c.ring:Hide(); tourAt = nil
        if ns.db then ns.db.tourDone = true end
        return false
    end
    tourAt = i
    local s = steps[i]
    c.step:SetText(format("%d / %d", i, #steps))
    c.title:SetText(ns:Tr(s.title))
    c.text:SetText(ns:Tr(s.text))
    c:SetHeight(math.max(130, 76 + (c.text:GetStringHeight() or 40)))
    c.next.text:SetText(ns:Tr(i < #steps and "Next" or "Done"))
    c.back:SetShown(i > 1)
    c.onNext = function() ns:TourStep(i + 1) end
    c.onBack = function() ns:TourStep(i - 1) end
    c.onClose = function() ns:TourStep(nil) end
    PointAt(c, s.frame and _G[s.frame])
    c:Show()
    return i
end
function ns:StartTour()
    if ns.Yes(InCombatLockdown()) then ns:Print("The tour waits until the fight is over."); return false end
    return ns:TourStep(1)
end
do  -- the first time, after the setup is done
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Tour", function()
        if not ns.db or ns.db.tourDone or not ns.db.setupDone then return end
        ns:After(4, function() if not ns.db.tourDone and not ns.Yes(InCombatLockdown()) then ns:StartTour() end end)
    end))
end

------------------------------------------------------------------------------------------
-- What's this? Every panel of this add-on on screen gets a frame with its name; point at one to see
-- which feature made it, click it to go to that feature's switch, right-click to switch it off.
-- /fgui whatsthis (or its key) turns it on and off; Esc or the same key closes it.
------------------------------------------------------------------------------------------
local boxes, whatOn = {}, false
local banner
local function Box(i)
    local b = CreateFrame("Button", nil, UIParent, ns.template)
    b:SetFrameStrata("FULLSCREEN")
    b:SetBackdrop({ bgFile = ns.FLAT, edgeFile = ns.FLAT, edgeSize = 1 })
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.label = ns:NewText(b, 11, "CENTER")
    b.label:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self)
        ns:Paint(self, "SetBackdropColor", "@accent", 0.35)
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine(ns:Tr(self.entry.label), 1, 0.82, 0.2)
        local key = self.entry.feature
        local label = key and SwitchLabel(key)
        if key then
            GameTooltip:AddLine(ns:Tr("Made by") .. ": " .. ns:Tr(label or key), 1, 1, 1)
            local desc = ns.featureDesc and ns.featureDesc[key]
            if desc then GameTooltip:AddLine(ns:Tr(desc), 0.8, 0.8, 0.8, true) end
            GameTooltip:AddLine(ns:Tr("Click: go to its switch.  Right-click: switch it off."), 0.55, 0.85, 1, true)
        else
            GameTooltip:AddLine(ns:Tr("Part of the add-on's core: always on."), 0.8, 0.8, 0.8, true)
        end
        GameTooltip:AddLine(ns:Tr("/fgui move drags it; right-click it there for its scale."), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) ns:Paint(self, "SetBackdropColor", "@accent", 0.15); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, button)
        local key = self.entry.feature
        if not key then return end
        if button == "RightButton" then
            ns.db[key] = false
            ns:Print("%s is switched off; it goes after a /reload.", ns:Tr(SwitchLabel(key) or key))
            self:Hide()
        else
            ns:WhatsThis(false)
            ns:ShowSwitch(key)
        end
    end)
    boxes[i] = b
    return b
end
function ns:WhatsThis(on)
    if on == nil then on = not whatOn end
    if on and ns.Yes(InCombatLockdown()) then ns:Print("Not during a fight."); return false end
    whatOn = on
    if not banner then
        banner = CreateFrame("Frame", "FantasyGlassUIWhatsThis", UIParent, ns.template)
        banner:SetSize(420, 34)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -60)
        banner:SetFrameStrata("FULLSCREEN_DIALOG")
        banner:SetBackdrop(ns.BACKDROP)
        ns:Paint(banner, "SetBackdropColor", "window", 0.95)
        ns:Paint(banner, "SetBackdropBorderColor", "@accent", 1)
        banner.text = ns:NewText(banner, 12, "CENTER")
        banner.text:SetPoint("CENTER")
        banner:EnableKeyboard(true)
        banner:SetPropagateKeyboardInput(true)
        banner:SetScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" then pcall(self.SetPropagateKeyboardInput, self, false); ns:WhatsThis(false)
            else pcall(self.SetPropagateKeyboardInput, self, true) end
        end)
        banner:RegisterEvent("PLAYER_REGEN_DISABLED")       -- (a fight closes it)
        banner:SetScript("OnEvent", ns:Guard("Insight events", function() if whatOn then ns:WhatsThis(false) end end))
    end
    local n = 0
    if on then
        for _, entry in ipairs(ns.movables or {}) do
            local f = entry.frame
            local okV, vis = pcall(f.IsVisible, f)
            if okV and ns.Yes(vis) then
                n = n + 1
                local b = boxes[n] or Box(n)
                b.entry = entry
                b:ClearAllPoints()
                b:SetAllPoints(f)
                ns:Paint(b, "SetBackdropColor", "@accent", 0.15)
                ns:Paint(b, "SetBackdropBorderColor", "@accent", 0.9)
                b.label:SetText(ns:Tr(entry.label))
                b:Show()
            end
        end
        banner.text:SetText(ns:Tr("What's this? Point at a panel. Esc or /fgui whatsthis to finish."))
        banner:Show()
    else
        banner:Hide()
        GameTooltip:Hide()
    end
    for i = n + 1, #boxes do boxes[i]:Hide() end
    ns.whatsThisCount = n
    return n
end
ns.whatsThisTest = { boxes = boxes, label = SwitchLabel }

------------------------------------------------------------------------------------------
-- Where to level next: the zones whose level range suits you, read from the game's own map
-- information (so the new zones are there too). Click one to open it on the world map.
------------------------------------------------------------------------------------------
-- How well a zone's range suits a level: "now" (in range), "soon" (just above you), "past" or nil.
function ns.ZoneFit(level, lo, hi)
    if type(lo) ~= "number" or type(hi) ~= "number" or lo <= 0 or hi <= 0 then return nil end
    if level >= lo and level <= hi then return "now" end
    if lo > level and lo <= level + 4 then return "soon" end
    if hi < level and hi >= level - 2 then return "past" end
    return nil
end
local function Zones()
    local M = C_Map
    if type(M) ~= "table" or not (M.GetMapChildrenInfo and M.GetMapLevels) then return nil end
    local T = Enum and Enum.UIMapType or {}
    local roots = {}
    local world = M.GetFallbackWorldMapID and select(2, pcall(M.GetFallbackWorldMapID))
    for _, id in ipairs({ world, 947, 946 }) do if type(id) == "number" then roots[#roots + 1] = id end end
    local out, seen = {}, {}
    for _, root in ipairs(roots) do
        local okC, continents = pcall(M.GetMapChildrenInfo, root, T.Continent or 2, true)
        for _, c in ipairs(okC and type(continents) == "table" and continents or {}) do
            local okZ, zones = pcall(M.GetMapChildrenInfo, c.mapID, T.Zone or 3, true)
            for _, z in ipairs(okZ and type(zones) == "table" and zones or {}) do
                if not seen[z.mapID] then
                    seen[z.mapID] = true
                    local okL, lo, hi = pcall(M.GetMapLevels, z.mapID)
                    if okL and type(lo) == "number" and lo > 0 then
                        out[#out + 1] = { id = z.mapID, name = z.name, lo = lo, hi = hi, continent = c.name }
                    end
                end
            end
        end
        if #out > 0 then break end
    end
    return out
end
function ns:ShowLevelZones()
    local level = UnitLevel("player") or 1
    local zones = Zones()
    local lines = {}
    if not zones then
        lines[1] = { left = ns:Tr("This game client does not tell add-ons the level of each zone.") }
    else
        local order = { now = 1, soon = 2, past = 3 }
        local picked = {}
        for _, z in ipairs(zones) do
            local fit = ns.ZoneFit(level, z.lo, z.hi)
            if fit then z.fit = fit; picked[#picked + 1] = z end
        end
        table.sort(picked, function(a, b)
            if order[a.fit] ~= order[b.fit] then return order[a.fit] < order[b.fit] end
            if a.lo ~= b.lo then return a.lo < b.lo end
            return tostring(a.name) < tostring(b.name)
        end)
        local colors = { now = ns:SignalHex("good"), soon = "|cffffd100", past = "|cff9aa4b4" }
        for _, z in ipairs(picked) do
            lines[#lines + 1] = { left = colors[z.fit] .. tostring(z.name) .. "|r", right = format("%d-%d  |cff9aa4b4%s|r", z.lo, z.hi, tostring(z.continent or "")),
                click = function() if OpenWorldMap then pcall(OpenWorldMap, z.id) elseif WorldMapFrame and WorldMapFrame.SetMapID then ShowUIPanel(WorldMapFrame); WorldMapFrame:SetMapID(z.id) end end,
                tip = { tostring(z.name), ns:Tr("Click to open it on the world map.") } }
        end
        if #lines == 0 then lines[1] = { left = ns:Tr("No zone's level range is near yours.") } end
    end
    return ns:ShowList("LevelZones", format(ns:Tr("Where to level at %d"), level), lines,
        (ns.db and ns.db.colorblind) and "Blue: your level now. Yellow: next. Gray: nearly done. From the game's own map."
            or "Green: your level now. Yellow: next. Gray: nearly done. From the game's own map.", 440, 340)
end

------------------------------------------------------------------------------------------
-- Profession cooldowns: crafts that can be made once a day (transmutes, special cloth and the like),
-- remembered for each character, with when each is ready again. Seen whenever a profession window
-- is open. /fgui profcd lists them; when one becomes ready on this character, a notice says so.
------------------------------------------------------------------------------------------
local function CDStore()
    if type(ns.root) ~= "table" then return {} end
    if type(ns.root.profCD) ~= "table" then ns.root.profCD = {} end
    return ns.root.profCD
end
-- Record what a scan saw: { [recipeID] = { name, seconds } } for one character at time `now`.
function ns.ProfCDRecord(store, char, seen, now)
    store[char] = store[char] or {}
    local mine = store[char]
    for id, s in pairs(seen) do
        mine[id] = { name = s.name, readyAt = now + math.max(0, s.seconds or 0), told = (s.seconds or 0) <= 0 }
    end
    return mine
end
-- Lines for the list: ready ones first, then the soonest.
function ns.ProfCDLines(store, now)
    local out = {}
    for char, list in pairs(store) do
        for _, s in pairs(list) do
            local left = s.readyAt - now
            out[#out + 1] = { char = char, name = s.name, left = left }
        end
    end
    table.sort(out, function(a, b)
        if (a.left <= 0) ~= (b.left <= 0) then return a.left <= 0 end
        if a.left ~= b.left then return a.left < b.left end
        return a.char < b.char
    end)
    return out
end
local function ScanProfession()
    local T = C_TradeSkillUI
    if type(T) ~= "table" or not (T.GetAllRecipeIDs and T.GetRecipeCooldown) then return 0 end
    local ok, ids = pcall(T.GetAllRecipeIDs)
    if not ok or type(ids) ~= "table" then return 0 end
    local seen, n = {}, 0
    local mine = CDStore()[ns:CharKey()] or {}
    for _, id in ipairs(ids) do
        local okC, cd, isDay = pcall(T.GetRecipeCooldown, id)
        if okC and ((type(cd) == "number" and cd > 0) or isDay or mine[id]) then
            local okI, info = pcall(T.GetRecipeInfo, id)
            local name = okI and type(info) == "table" and info.name or (mine[id] and mine[id].name) or (ns:Tr("Recipe") .. " " .. id)
            if not (okI and type(info) == "table" and info.learned == false) then
                seen[id] = { name = name, seconds = type(cd) == "number" and cd or 0 }
                n = n + 1
            end
        end
    end
    if n > 0 then ns.ProfCDRecord(CDStore(), ns:CharKey(), seen, time()) end
    return n
end
ns.ScanProfession = ScanProfession
function ns:ShowProfCooldowns()
    local lines = {}
    local me = ns:CharKey()
    for _, l in ipairs(ns.ProfCDLines(CDStore(), time())) do
        lines[#lines + 1] = { left = tostring(l.name) .. "  |cff9aa4b4" .. tostring(l.char):gsub(" %- .*$", "") .. "|r",
            right = l.left <= 0 and (ns:SignalHex("good") .. ns:Tr("ready") .. "|r") or Clock(l.left),
            color = (l.char == me) and { 1, 1, 1 } or { 0.8, 0.8, 0.8 } }
    end
    if #lines == 0 then lines[1] = { left = ns:Tr("None yet. Open each profession window once on each character.") } end
    return ns:ShowList("ProfCD", "Profession cooldowns", lines, "Every character's once-a-day crafts. Seen when a profession window is open.", 440, 300)
end
ns:NewModule("profCooldowns", function()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_CLOSE" }) do pcall(ev.RegisterEvent, ev, e) end
    local waiting = false
    ev:SetScript("OnEvent", ns:Guard("Profession cooldowns", function()
        if waiting then return end
        waiting = true
        ns:After(1, function() waiting = false; pcall(ScanProfession) end)
    end))
    ns:Every(60, "Profession cooldowns", function()
        local mine = CDStore()[ns:CharKey()]
        if type(mine) ~= "table" then return end
        local now = time()
        for _, s in pairs(mine) do
            if not s.told and s.readyAt <= now then
                s.told = true
                if ns.Toast then pcall(ns.Toast, ns, nil, ns:Tr("Ready to craft"), tostring(s.name), "!") end
                ns:PrintRaw(ns:Tr("Ready to craft") .. ": |cffffd100" .. tostring(s.name) .. "|r")
            end
        end
    end)
end)

------------------------------------------------------------------------------------------
-- Performance view: /fgui perf measures for 20 seconds how much time each part of the add-on takes
-- (everything that runs on a timer or answers an event), then lists them, heaviest first, with the
-- add-on's memory. Click a line to go to that feature's switch, where there is one.
------------------------------------------------------------------------------------------
ns.perfData = {}
function ns:PerfAdd(label, ms)
    local p = ns.perfData[label]
    if not p then p = { ms = 0, calls = 0, worst = 0 }; ns.perfData[label] = p end
    p.ms, p.calls = p.ms + ms, p.calls + 1
    if ms > p.worst then p.worst = ms end
end
-- The figures as rows, heaviest first: { label, msPerSec, calls, worst }.
function ns.PerfRows(data, seconds)
    local out = {}
    seconds = math.max(0.001, seconds or 1)
    for label, p in pairs(data) do out[#out + 1] = { label = label, perSec = p.ms / seconds, calls = p.calls, worst = p.worst } end
    table.sort(out, function(a, b) return a.perSec > b.perSec end)
    return out
end
local function FeatureFor(label)
    for _, group in ipairs(ns.featureGroups or {}) do
        for _, opt in ipairs(group[2] or {}) do if opt[2] == label then return opt[1] end end
    end
end
-- A fight in a raid (/fgui perf fight): measuring starts when the next fight does and stops when it
-- ends, with the group's size and the frame rate; then the report, and a copy of it as text to send.
function ns.PerfReportText(rows, took, info)
    local out = { format("Fantasy Glass UI %s performance: %s, %d seconds%s", ns.version, info.what or "measured",
        math.floor(took + 0.5), info.group and format(", group of %d", info.group) or "") }
    if info.fps then out[#out + 1] = format("Frame rate: %d to %d (average %d)", info.fpsLow or 0, info.fpsHigh or 0, info.fps) end
    if info.mem then out[#out + 1] = format("Memory: %.1f MB", info.mem / 1024) end
    local total = 0
    for _, r in ipairs(rows) do total = total + r.perSec end
    out[#out + 1] = format("Whole add-on: %.2f ms each second", total)
    for i, r in ipairs(rows) do
        if i > 25 then break end
        out[#out + 1] = format("%s: %.3f ms/s, %d times, longest %.1f ms", r.label, r.perSec, r.calls, r.worst)
    end
    return table.concat(out, "\n")
end
local fight
function ns:PerfFight()
    if type(debugprofilestop) ~= "function" then ns:Print("This game client cannot time add-ons."); return false end
    if fight then ns:Print("Already waiting for a fight."); return false end
    fight = { armed = true, fps = {} }
    ns:Print("Measuring starts when your next fight does, and stops when it ends. Then you get a report to send.")
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED")
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    local ticker = CreateFrame("Frame")
    local acc = 0
    ticker:SetScript("OnUpdate", function(_, e)
        acc = acc + (e or 0)
        if acc < 1 or not ns.perfOn then return end
        acc = 0
        local f = GetFramerate and GetFramerate()
        if type(f) == "number" then fight.fps[#fight.fps + 1] = f end
    end)
    ev:SetScript("OnEvent", ns:Guard("Insight events", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" and fight.armed then
            fight.armed = false
            wipe(ns.perfData)
            ns.perfOn, ns.perfStart = true, GetTime()
        elseif event == "PLAYER_REGEN_ENABLED" and ns.perfOn and not fight.armed and GetTime() - ns.perfStart < 10 then
            ns.perfOn = false                                -- (a few seconds says nothing: wait for a real fight)
            fight.armed, fight.fps = true, {}
            ns:Print("That fight was too short to measure. Waiting for the next one.")
        elseif event == "PLAYER_REGEN_ENABLED" and ns.perfOn and not fight.armed then
            ns.perfOn = false
            self:UnregisterAllEvents(); ticker:SetScript("OnUpdate", nil)
            local took = GetTime() - ns.perfStart
            local f = fight
            fight = nil
            local info = { what = "a fight" }
            local n = GetNumGroupMembers and GetNumGroupMembers()
            if type(n) == "number" and n > 0 then info.group = n end
            if #f.fps > 0 then
                local sum, lo, hi = 0, math.huge, 0
                for _, v in ipairs(f.fps) do sum = sum + v; lo = math.min(lo, v); hi = math.max(hi, v) end
                info.fps, info.fpsLow, info.fpsHigh = math.floor(sum / #f.fps + 0.5), math.floor(lo + 0.5), math.floor(hi + 0.5)
            end
            ns:PerfShow(took, info)
        end
    end))
    return true
end
function ns:PerfCommand(text)
    if type(debugprofilestop) ~= "function" then ns:Print("This game client cannot time add-ons."); return false end
    local word = ns.Trim(text or ""):lower()
    if word == "fight" then return ns:PerfFight() end
    if word == "load" then return ns.ShowLoadCost and ns:ShowLoadCost() end
    local seconds = math.max(5, math.min(120, tonumber(word) or 20))
    if ns.perfOn then ns:Print("Already measuring."); return false end
    wipe(ns.perfData)
    ns.perfOn, ns.perfStart = true, GetTime()
    ns:Print("Measuring for %d seconds; play as usual.", seconds)
    ns:After(seconds, function()
        ns.perfOn = false
        ns:PerfShow(GetTime() - ns.perfStart, { what = "play as usual" })
    end)
    return true
end
function ns:PerfShow(took, info)
    ns:LoadOptions()                                         -- (for the feature names)
    do
        local rows = ns.PerfRows(ns.perfData, took)
        local lines = {}
        local mem
        local C = C_AddOns
        local update = (C and C.UpdateAddOnMemoryUsage) or UpdateAddOnMemoryUsage
        local get = (C and C.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
        if update and get then pcall(update); local ok, kb = pcall(get, ADDON); if ok and type(kb) == "number" then mem = kb end end
        local total = 0
        for _, r in ipairs(rows) do total = total + r.perSec end
        lines[#lines + 1] = { left = ns:AccentHex() .. ns:Tr("Whole add-on") .. "|r", right = format("%.2f ms/s%s", total, mem and format("  |cff9aa4b4%.1f MB|r", mem / 1024) or "") }
        for _, r in ipairs(rows) do
            local key = FeatureFor(r.label)
            lines[#lines + 1] = { left = ns:Tr(r.label), right = format("%.3f ms/s  |cff9aa4b4%d  (%.1f)|r", r.perSec, r.calls, r.worst),
                bar = total > 0 and (r.perSec / total) or 0,
                click = key and function() ns:ShowSwitch(key) end or nil,
                tip = { ns:Tr(r.label), format(ns:Tr("%d times; the longest took %.1f ms."), r.calls, r.worst), key and ns:Tr("Click: go to its switch.") or nil } }
        end
        ns:ShowList("Performance", format(ns:Tr("Performance over %d seconds"), math.floor(took + 0.5)), lines,
            "Milliseconds each second it took; how many times it ran, and the longest once.", 460, 360)
        info = info or {}
        info.mem = mem
        ns.perfLastText = ns.PerfReportText(rows, took, info)
        if info.what == "a fight" and ns.ShowCopyBox then
            ns:After(0.3, function() ns:ShowCopyBox(ns.perfLastText, ns:Tr("The fight's performance report: Ctrl+C to copy it and send it on.")) end)
        end
        return rows
    end
end
