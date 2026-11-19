local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Threat meter (11.13): who has how much threat on your target, in a small panel of its own. In a
-- group, with a hostile target, it shows up to five of your group from most threat down; your own row
-- is marked, and turns the warning color near the top of the list and the danger color when you
-- would pull the target. A tank reads it the other way round: who is about to take it off them.
--
-- It works without the damage meter (whose own threat rows need a client that shares damage totals).
-- Hidden values, which the game uses in some fights, still fill the bars and print their numbers:
-- only the sorting and the colors need a plain value, and wait for one.
------------------------------------------------------------------------------------------
local ROWS, ROW_H, GAP, W = 5, 16, 3, 200

-- The color a row's bar takes: by its share of the top threat and whether it is you.
function ns.ThreatRowColor(pct, isMe)
    if type(pct) ~= "number" or Secret(pct) then return "@accent" end
    if isMe and pct >= 100 then return "bad" end
    if isMe and pct >= 80 then return "warn" end
    return isMe and "good" or "@accent"
end

ns:NewModule("threatMeter", function()
    local f = CreateFrame("Frame", "FantasyGlassUIThreat", UIParent)
    f:SetSize(W, 22 + ROWS * (ROW_H + GAP))
    f:SetPoint("CENTER", UIParent, "CENTER", 360, -40)
    f.title = ns:NewText(f, 12, "LEFT", true)
    f.title:SetPoint("TOPLEFT", 2, 0)
    f.title:SetText(ns:Tr("Threat"))
    ns:Paint(f.title, "SetTextColor", "@accent")
    f.rows = {}
    for i = 1, ROWS do
        local bar = ns:NewStatusBar(f, true)
        bar:SetSize(W, ROW_H)
        bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(20 + (i - 1) * (ROW_H + GAP)))
        bar:SetMinMaxValues(0, 100)
        bar.name = ns:NewText(bar, 11, "LEFT")
        bar.pct = ns:NewText(bar, 11, "RIGHT")
        bar.scOnStyle = function(self, on)
            local inset = ns.StarcutInset(on, 5)
            self.name:ClearAllPoints(); self.pct:ClearAllPoints()
            self.pct:SetPoint("RIGHT", -inset, 0)
            self.name:SetPoint("LEFT", inset, 0); self.name:SetPoint("RIGHT", self.pct, "LEFT", -6, 0)
        end
        ns:StarcutStyleBar(bar, true)
        bar:Hide()
        f.rows[i] = bar
    end
    f:Hide()

    local sample = false
    local function Draw(list)
        for i, bar in ipairs(f.rows) do
            local e = list and list[i]
            if e then
                local isMe = e.unit == "player" or e.me
                local okN, name = pcall(UnitName, e.unit)
                bar.name:SetText(e.name or ((okN and type(name) == "string") and name or e.unit))
                local r, g, b = ns:ClassColor(e.unit)
                if e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class] then
                    local c = RAID_CLASS_COLORS[e.class]; r, g, b = c.r, c.g, c.b
                end
                if r then bar.name:SetTextColor(r, g, b) else bar.name:SetTextColor(1, 1, 1) end
                pcall(bar.SetValue, bar, e.pct)                         -- (a hidden value still fills the bar)
                if not pcall(bar.pct.SetFormattedText, bar.pct, "%d%%", e.pct) then bar.pct:SetText("") end
                local role = ns.ThreatRowColor(e.pct, isMe)
                if role == "@accent" then ns:Paint(bar, "SetStatusBarColor", "@accent")
                else bar:SetStatusBarColor(ns:Signal(role)) end
                bar:SetAlpha(isMe and 1 or 0.85)
                bar:Show(); bar.inUse = true
            else
                bar:Hide(); bar.inUse = false
            end
        end
    end
    local function Update()
        if sample then return end
        if ns.db.threatHidden then f:Hide(); f.inUse = false return end
        local ok, list = pcall(ns.ThreatOnTarget, ns, ROWS)
        if ok and type(list) == "table" and #list > 0 then Draw(list); f:Show(); f.inUse = true else f:Hide(); f.inUse = false end
    end
    ns.threatMeterTest = { frame = f, Update = Update, Draw = Draw }
    function ns:ToggleThreatMeter()                               -- /fgui threat: hide it for now, or show it again
        ns.db.threatHidden = not ns.db.threatHidden or nil
        ns:Print(ns.db.threatHidden and "Threat meter hidden. /fgui threat shows it again." or "Threat meter shown (in a group, with a hostile target).")
        Update()
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Threat meter", Update))
    ns:Every(1, "Threat meter", function() if f:IsShown() then Update() end end)    -- (and once a second while it shows)

    local entry = ns:RegisterMovable(f, "threatMeter", "Threat meter")
    if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
    ns:RegisterPreview(function(on)
        sample = on and true or false
        if on then
            Draw({ { unit = "player", me = true, pct = 86, name = UnitName and UnitName("player") or "You" },
                   { unit = "party1", name = "Brannoc", class = "WARRIOR", pct = 100 },
                   { unit = "party2", name = "Sylvae", class = "MAGE", pct = 64 },
                   { unit = "party3", name = "Kaelith", class = "PRIEST", pct = 31 } })
            f:Show()
        else
            Update()
        end
    end)
end)
