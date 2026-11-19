local _, ns = ...

-- The breath bar (and its relatives: fatigue when you swim too far out, feign death). The game shows
-- these as "mirror timers"; this replaces its bars with ours. The game tells add-ons when one starts,
-- pauses and stops, and how much is left, so nothing here is guessed.
ns:NewModule("mirrorBars", function()
    if type(GetMirrorTimerInfo) ~= "function" then return end      -- this game has no such timers
    local MAX = 3
    local COLORS = { BREATH = { 0.30, 0.62, 1.00 }, EXHAUSTION = { 1.00, 0.85, 0.20 }, FEIGNDEATH = { 0.90, 0.60, 0.25 } }

    local holder = CreateFrame("Frame", "FantasyGlassUIMirror", UIParent)
    holder:SetSize(220, MAX * 22)
    holder:SetPoint("TOP", UIParent, "TOP", 0, -150)

    local bars, active = {}, {}                            -- active[timer name] = { max =, label =, paused = }
    local function Bar(i)
        if bars[i] then return bars[i] end
        local bar = CreateFrame("StatusBar", nil, holder)
        bar:SetStatusBarTexture(ns.BAR or ns.FLAT)
        bar:SetSize(220, 16)
        bar:SetPoint("TOP", holder, "TOP", 0, -(i - 1) * 22)
        bar.bg = bar:CreateTexture(nil, "BACKGROUND")
        bar.bg:SetAllPoints()
        bar.bg:SetTexture(ns.FLAT)
        ns:Paint(bar.bg, "SetVertexColor", "trough", 0.95)
        ns:AddBorder(bar, 0, 0, 0, 1)
        bar.label = ns:NewText(bar, 11, "LEFT")
        bar.label:SetPoint("LEFT", 6, 0)
        bar.time = ns:NewText(bar, 11, "RIGHT")
        bar.time:SetPoint("RIGHT", -6, 0)
        bar.scOnStyle = function(self, on)                     -- the frame style: text in from the points
            local inset = ns.StarcutInset(on, 6)
            self.label:ClearAllPoints(); self.label:SetPoint("LEFT", inset, 0)
            self.time:ClearAllPoints(); self.time:SetPoint("RIGHT", -inset, 0)
        end
        ns:StarcutStyleBar(bar, true)
        bar:Hide()
        bars[i] = bar
        return bar
    end

    -- scale: how fast it runs (-1 drains a second a second); used only when the game will not say how much is left
    local function Show(name, value, max, scale, paused, label)
        if type(name) ~= "string" or name == "UNKNOWN" then return end
        active[name] = { max = (tonumber(max) or 1) / 1000, label = label, paused = paused and paused ~= 0, value = (tonumber(value) or 0) / 1000,
            scale = tonumber(scale) or -1, since = GetTime() }
    end
    local function Left(t)                                  -- worked out from the start, for a game without GetMirrorTimerProgress
        if t.paused then return t.value end
        return math.max(0, math.min(t.max, t.value + t.scale * (GetTime() - t.since)))
    end

    local preview = false
    local function Draw()
        local i = 0
        if preview then
            i = 1
            local bar = Bar(1)
            bar:SetMinMaxValues(0, 60); bar:SetValue(38)
            bar:SetStatusBarColor(COLORS.BREATH[1], COLORS.BREATH[2], COLORS.BREATH[3])
            bar.label:SetText(ns:Tr("Breath")); bar.time:SetText("38")
            bar:Show()
        else
            for name, t in pairs(active) do
                if i >= MAX then break end
                i = i + 1
                local bar = Bar(i)
                local c = COLORS[name]
                if c then bar:SetStatusBarColor(c[1], c[2], c[3]) else ns:Paint(bar, "SetStatusBarColor", "@accent") end
                bar.label:SetText(type(t.label) == "string" and t.label or name)
                bar:SetMinMaxValues(0, t.max > 0 and t.max or 1)
                local value = Left(t)                      -- how much is left: straight from the game when it will say
                if GetMirrorTimerProgress then
                    local ok, ms = pcall(GetMirrorTimerProgress, name)
                    if ok and ms ~= nil then
                        if ns:IsSecret(ms) then value = nil; bar:SetValue(ms)        -- a hidden number still fills a bar
                        elseif type(ms) == "number" then value = ms / 1000 end
                    end
                end
                if value then
                    bar:SetValue(value)
                    bar.time:SetText(format("%d", math.max(0, value)))
                else
                    bar.time:SetText("")
                end
                bar:Show()
            end
        end
        for j = i + 1, #bars do bars[j]:Hide() end
        return i
    end
    ns.MirrorDraw, ns.mirrorBars = Draw, bars

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "MIRROR_TIMER_PAUSE", "PLAYER_ENTERING_WORLD" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Breath bar", function(_, event, name, value, max, scale, paused, label)
        if event == "MIRROR_TIMER_START" then
            Show(name, value, max, scale, paused, label)
        elseif event == "MIRROR_TIMER_STOP" then
            if type(name) == "string" then active[name] = nil end
        elseif event == "MIRROR_TIMER_PAUSE" then
            local t = type(name) == "string" and active[name]
            if t then
                t.value, t.since = Left(t), GetTime()       -- (frozen where it stood, and running on from there)
                t.paused = (value and value ~= 0) and true or false
            end
        else                                                -- logging in or changing zone mid-swim: ask what is running
            for k in pairs(active) do active[k] = nil end
            for i = 1, MAX do
                local ok, n, v, m, sc, p, l = pcall(GetMirrorTimerInfo, i)
                if ok then Show(n, v, m, sc, p, l) end
            end
        end
        Draw()
    end))
    ns:Every(0.1, "Breath bar", function()
        if preview or next(active) then Draw() end
    end)

    -- the game's own bars are kept out of sight (never hidden or hooked)
    local function Quiet()
        local names = { "MirrorTimerContainer" }
        for i = 1, MAX do names[#names + 1] = "MirrorTimer" .. i end
        for _, n in ipairs(names) do
            local f = _G[n]
            if type(f) == "table" and f.SetAlpha and not f.suiKilled and ns:Usable(f) then
                ns:Kill(f, true)
                ns:Silence(f)
            end
        end
    end
    Quiet()
    ns:After(2, Quiet)

    ns:RegisterPreview(function(on) preview = on and true or false; Draw() end)
    ns:RegisterMovable(holder, "mirror", "Breath bar")
end)
