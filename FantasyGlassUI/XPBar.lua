local _, ns = ...

-- Slim experience and reputation bars. These numbers are never hidden by the client.
ns:NewModule("xpBar", function()
    local th = ns.theme
    local W = 500
    local holder = CreateFrame("Frame", "FantasyGlassUIXP", UIParent)
    holder:SetSize(W, 22)
    holder:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 3)

    local xp = ns:NewStatusBar(holder, true)
    xp:SetSize(W, 8)
    xp:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
    ns:Paint(xp, "SetStatusBarColor", "@accent")
    -- rested experience shows as a paler stretch ahead of the fill
    local rested = xp:CreateTexture(nil, "ARTWORK", nil, 1)
    rested:SetTexture(ns.FLAT)
    ns:Paint(rested, "SetVertexColor", "@accent", 0.3)
    rested:SetPoint("TOPLEFT", xp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    rested:SetPoint("BOTTOMLEFT", xp:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    rested:Hide()
    xp.scAlso = { rested }                                   -- (cut to the bar's shape with it)
    ns:StarcutStyleBar(xp, true)

    -- how far through the level you are, written on the bar: a percentage, or the amounts with the
    -- "XP as numbers" option
    local xpText = ns:NewText(xp, 10, "CENTER")
    xpText:SetPoint("CENTER", xp, "CENTER", 0, 0)
    xpText:SetTextColor(1, 1, 1)
    if xpText.SetShadowOffset then xpText:SetShadowOffset(1, -1); xpText:SetShadowColor(0, 0, 0, 1) end

    local rep = ns:NewStatusBar(holder, true)
    rep:SetSize(W, 8)                                        -- the same height as the XP bar, so it can carry text too
    rep:SetPoint("BOTTOM", xp, "TOP", 0, 5)
    rep:Hide()
    ns:StarcutStyleBar(rep, true)
    -- how far through the current standing you are with the watched faction, written the same way as XP
    local repText = ns:NewText(rep, 10, "CENTER")
    repText:SetPoint("CENTER", rep, "CENTER", 0, 0)
    repText:SetTextColor(1, 1, 1)
    if repText.SetShadowOffset then repText:SetShadowOffset(1, -1); repText:SetShadowColor(0, 0, 0, 1) end

    -- what the tooltip shows; filled in by Update()
    local info = {}

    -- Pace: experience gained since login, and how big a typical kill and a typical quest have been.
    local pace = { since = GetTime(), gained = 0, kills = {}, quests = {}, questUntil = 0 }
    local function Average(list)
        if #list == 0 then return nil end
        local sum = 0
        for _, v in ipairs(list) do sum = sum + v end
        return sum / #list
    end
    local function TrackGain()
        local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 0
        if ns:IsSecret(cur) or ns:IsSecret(max) then return end       -- (hidden amounts can't be added up)
        if pace.last then
            local delta = cur - pace.last
            if delta < 0 then delta = (pace.lastMax - pace.last) + cur end      -- levelled up
            if delta > 0 then
                pace.gained = pace.gained + delta
                local list = (GetTime() < pace.questUntil) and pace.quests or pace.kills
                list[#list + 1] = delta
                if #list > 12 then table.remove(list, 1) end
            end
        end
        pace.last, pace.lastMax = cur, max
    end
    local function Duration(seconds)
        if seconds >= 3600 then return format(ns:Tr("%dh %02dm"), math.floor(seconds / 3600), math.floor(seconds % 3600 / 60)) end
        return format(ns:Tr("%dm"), math.max(1, math.floor(seconds / 60)))
    end
    local function Num(n) return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n) end

    local function AtMax()
        local lvl, max = UnitLevel("player"), GetMaxPlayerLevel()
        return type(lvl) == "number" and type(max) == "number" and lvl >= max
    end

    local function Watched()
        local d = C_Reputation.GetWatchedFactionData()
        if d and d.name then return d.name, d.reaction, d.currentReactionThreshold, d.nextReactionThreshold, d.currentStanding end
    end

    local function Update()
        info.xp, info.rep = nil, nil
        if AtMax() then
            xp:Hide()
        else
            local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 0
            if ns:IsSecret(cur) or ns:IsSecret(max) then
                -- A client that hides these: the bar can still be filled, but nothing can be worked out,
                -- so there is no text, no rested stretch and no tooltip figures.
                pcall(function() xp:SetMinMaxValues(0, max); xp:SetValue(cur) end)
                xp:Show()
                rested:Hide()
                xpText:SetText("")
                ns.xpBarText = ""
            elseif max > 0 then
                xp:SetMinMaxValues(0, max)
                xp:SetValue(cur)
                xp:Show()
                local text = ns.db.xpNumbers and (Num(cur) .. " / " .. Num(max)) or format("%.1f%%", math.floor(cur / max * 1000) / 10)
                xpText:SetText(text)
                ns.xpBarText = text
                local rest = GetXPExhaustion and GetXPExhaustion() or 0
                if rest and rest > 0 then
                    rested:SetWidth(math.max(1, math.min(rest, max - cur) / max * W))
                    rested:Show()
                else
                    rested:Hide()
                end
                info.xp = { cur = cur, max = max, left = max - cur, rest = rest or 0 }
            end
        end

        local name, reaction, lo, hi, value = Watched()
        ns.repBarText = ""
        if name and (ns:IsSecret(lo) or ns:IsSecret(hi) or ns:IsSecret(value)) then
            -- a client that hides these: the bar can still be filled, but nothing can be worked out
            pcall(function() rep:SetMinMaxValues(lo, hi); rep:SetValue(value) end)
            rep:ClearAllPoints()
            if xp:IsShown() then rep:SetPoint("BOTTOM", xp, "TOP", 0, 5) else rep:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0) end
            rep:Show()
            repText:SetText("")
        elseif name and lo and hi and value and hi > lo then
            rep:SetMinMaxValues(lo, hi)
            rep:SetValue(value)
            local cur, max = value - lo, hi - lo
            local text = ns.db.xpNumbers and (Num(cur) .. " / " .. Num(max)) or format("%.1f%%", math.floor(cur / max * 1000) / 10)
            repText:SetText(text)
            ns.repBarText = text
            local c = FACTION_BAR_COLORS and reaction and FACTION_BAR_COLORS[reaction]
            if c then rep:SetStatusBarColor(c.r, c.g, c.b) else rep:SetStatusBarColor(0.3, 0.8, 0.4) end
            rep:ClearAllPoints()
            if xp:IsShown() then rep:SetPoint("BOTTOM", xp, "TOP", 0, 5) else rep:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0) end
            rep:Show()
            local label = reaction and _G["FACTION_STANDING_LABEL" .. reaction]
            info.rep = { name = name, cur = value - lo, max = hi - lo, left = hi - value, standing = type(label) == "string" and label or nil }
        else
            rep:Hide()
        end
    end

    local function ShowTip()
        if not (info.xp or info.rep) then return end
        GameTooltip:SetOwner(holder, "ANCHOR_TOP", 0, 6)
        if info.xp then
            local x = info.xp
            GameTooltip:AddLine(ns:Tr("Experience"), th.accent[1], th.accent[2], th.accent[3])
            GameTooltip:AddDoubleLine(ns:Tr("Current"), format("%s / %s  (%d%%)", Num(x.cur), Num(x.max), math.floor(x.cur / x.max * 100)), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine(ns:Tr("Remaining"), format("%s  (%d%%)", Num(x.left), math.ceil(x.left / x.max * 100)), 1, 1, 1, 1, 0.82, 0)
            if x.rest > 0 then
                GameTooltip:AddDoubleLine(ns:Tr("Rested"), "+" .. Num(x.rest), 1, 1, 1, 0.55, 0.75, 1)
            end
            local elapsed = GetTime() - pace.since
            if pace.gained > 0 and elapsed > 60 then
                local perHour = pace.gained / elapsed * 3600
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(ns:Tr("This session"), th.accent[1], th.accent[2], th.accent[3])
                GameTooltip:AddDoubleLine(ns:Tr("Gained"), Num(pace.gained), 1, 1, 1, 1, 1, 1)
                GameTooltip:AddDoubleLine(ns:Tr("Per hour"), Num(math.floor(perHour)), 1, 1, 1, 1, 1, 1)
                if perHour > 0 then GameTooltip:AddDoubleLine(ns:Tr("Time to level"), Duration(x.left / perHour * 3600), 1, 1, 1, 1, 0.82, 0) end
            end
            local kill, quest = Average(pace.kills), Average(pace.quests)
            if kill or quest then
                local parts = {}
                if kill then local k = math.ceil(x.left / kill); parts[#parts + 1] = format(ns:TrN(k, "%d kill", "%d kills"), k) end
                if quest then local q = math.ceil(x.left / quest); parts[#parts + 1] = format(ns:TrN(q, "%d quest", "%d quests"), q) end
                GameTooltip:AddDoubleLine(ns:Tr("At recent sizes"), table.concat(parts, "  " .. ns:Tr("or") .. "  "), 1, 1, 1, 0.7, 0.7, 0.7)
            end
        end
        if info.rep then
            local r = info.rep
            if info.xp then GameTooltip:AddLine(" ") end
            GameTooltip:AddLine(r.name .. (r.standing and ("  (" .. r.standing .. ")") or ""), th.accent[1], th.accent[2], th.accent[3])
            GameTooltip:AddDoubleLine(ns:Tr("Current"), format("%s / %s", Num(r.cur), Num(r.max)), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine(ns:Tr("Remaining"), Num(r.left), 1, 1, 1, 1, 0.82, 0)
        end
        GameTooltip:Show()
    end

    -- hover is polled (nothing hooked); the tooltip follows the mouse entering and leaving the bars
    local acc, hovering = 0, false
    holder:SetScript("OnUpdate", ns:Guard("XP bar", function(self, e)
        acc = acc + e
        if acc < 0.1 then return end
        acc = 0
        local over = self:IsMouseOver(6, -2, -2, 2) and true or false
        if over and not hovering then
            hovering = true
            ShowTip()
        elseif hovering and not over then
            hovering = false
            if GameTooltip:IsOwned(holder) then GameTooltip:Hide() end
        end
    end))

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "UPDATE_FACTION", "PLAYER_ENTERING_WORLD", "QUEST_TURNED_IN" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("XP bar", function(_, event)
        if event == "QUEST_TURNED_IN" then
            pace.questUntil = GetTime() + 3                 -- the experience that follows is a quest's
        elseif event == "PLAYER_XP_UPDATE" then
            TrackGain()
        end
        Update()
        if hovering then ShowTip() end
    end))
    TrackGain()                                             -- remember where we started
    Update()

    -- Blizzard's experience / reputation bars
    ns:Silence(_G.StatusTrackingBarManager)
    ns:Silence(_G.MainStatusTrackingBarContainer)
    ns:Silence(_G.SecondaryStatusTrackingBarContainer)

    function ns:RefreshXPBar() Update() end                  -- (the percent-or-numbers choice changed)
    ns:RegisterMovable(holder, "xpBar", "XP / reputation")
end)
