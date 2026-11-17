local _, ns = ...

-- Minimap button collector: the buttons other add-ons hang on the minimap are gathered into one
-- fold-out panel, opened with a small "Add-ons" button.
ns:NewModule("buttonBag", function()
    local th = ns.theme
    local SIZE, GAP, PER = 32, 4, 6
    local found, order = {}, {}

    local toggle, panel
    toggle = ns:CreateButton(UIParent, "Add-ons", 66, 18, function()
        if panel:IsShown() then panel:Hide() else panel:Show() end
    end)
    ns:Font(toggle.text, 10)
    local home = _G.FantasyGlassUIMinimap
    if type(home) == "table" then toggle:SetPoint("TOPLEFT", home, "BOTTOMLEFT", 0, -4)
    else toggle:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -150, -210) end
    toggle:Hide()

    panel = CreateFrame("Frame", "FantasyGlassUIButtonBag", UIParent, ns.template)
    panel:SetFrameStrata("HIGH")
    panel:SetBackdrop(ns.BACKDROP)
    ns:Paint(panel, "SetBackdropColor", "window", 0.95)
    ns:Paint(panel, "SetBackdropBorderColor", "@border", 1)
    ns:Dress(panel, true)
    panel:SetPoint("TOPRIGHT", toggle, "BOTTOMRIGHT", 0, -4)
    panel:Hide()
    tinsert(UISpecialFrames, "FantasyGlassUIButtonBag")

    local function IsAddonButton(f)
        if type(f) ~= "table" or found[f] or not f.GetName then return false end
        if f.IsForbidden and f:IsForbidden() then return false end
        local name = f:GetName()
        if type(name) ~= "string" then return false end
        -- the standard library names its buttons this way; a few add-ons use "...MinimapButton"
        return name:find("^LibDBIcon10_") ~= nil or (name:find("MinimapButton$") ~= nil and not name:find("^MiniMap") and not name:find("LandingPage"))
    end

    -- A gathered button must be seen as its add-on drew it: in front of the panel (a button keeps the
    -- level it had on the minimap, which can be behind the panel's dark backing and so looks greyed
    -- out), and solid (some fade themselves until the minimap is pointed at).
    -- (Many buttons - every one made by the usual minimap-button library - "fix" their layer so that the
    -- minimap cannot change it. A fixed layer ignores being set, so it is unfixed, set, and fixed again.
    -- The game's own method is used, in case an add-on has replaced the button's.)
    local function Raw(f, method, ...)
        local mt = getmetatable(f)
        local fn = (mt and type(mt.__index) == "table" and mt.__index[method]) or f[method]
        if type(fn) ~= "function" then return false end
        return pcall(fn, f, ...)
    end
    local function Bright(f)
        local level = (panel.GetFrameLevel and tonumber(panel:GetFrameLevel()) or 1) + 5
        Raw(f, "SetFixedFrameStrata", false)
        Raw(f, "SetFixedFrameLevel", false)
        Raw(f, "SetFrameStrata", panel.GetFrameStrata and panel:GetFrameStrata() or "HIGH")
        Raw(f, "SetFrameLevel", level)
        Raw(f, "SetFixedFrameStrata", true)
        Raw(f, "SetFixedFrameLevel", true)
        if type(f.fadeOut) == "table" and f.fadeOut.Stop then pcall(f.fadeOut.Stop, f.fadeOut) end
        if rawget(f, "showOnMouseover") then f.showOnMouseover = nil end
        if f.SetAlpha then pcall(f.SetAlpha, f, 1) end
    end
    -- Is this one meant to be seen? (An add-on whose own "hide the minimap button" is ticked hides it.)
    local function Wanted(f)
        if not f.IsShown then return true end
        local ok, shown = pcall(f.IsShown, f)
        return (not ok) or ns.Is(shown, true) or (type(shown) ~= "boolean")
    end
    local lastShown = -1
    local function Arrange()
        local n = 0
        for _, f in ipairs(order) do
            if Wanted(f) then                                -- (a hidden one leaves no gap)
                n = n + 1
                local col, row = (n - 1) % PER, math.floor((n - 1) / PER)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", panel, "TOPLEFT", 8 + col * (SIZE + GAP), -8 - row * (SIZE + GAP))
                Bright(f)
            end
        end
        lastShown = n
        -- If a button still would not come forward, the panel goes behind it instead: onto that
        -- button's layer, a little below the lowest of them.
        local stuckStrata, lowest
        for _, f in ipairs(order) do
            if Wanted(f) and f.GetFrameStrata and f.GetFrameLevel then
                local okS, strata = pcall(f.GetFrameStrata, f)
                local okL, level = pcall(f.GetFrameLevel, f)
                local mine = panel.GetFrameStrata and panel:GetFrameStrata()
                if okS and okL and type(strata) == "string" and type(mine) == "string" and strata ~= mine and type(level) == "number" then
                    stuckStrata = strata
                    lowest = math.min(lowest or level, level)
                end
            end
        end
        if stuckStrata then
            Raw(panel, "SetFrameStrata", stuckStrata)
            Raw(panel, "SetFrameLevel", math.max(0, lowest - 3))
            ns.buttonBagState = "the panel was put behind buttons that would not come forward (" .. stuckStrata .. ")"
        else
            ns.buttonBagState = "every button is in front of the panel"
        end
        local cols = math.max(1, math.min(n, PER))
        local rowsN = math.max(1, math.ceil(n / PER))
        panel:SetSize(16 + cols * (SIZE + GAP) - GAP, 16 + rowsN * (SIZE + GAP) - GAP)
        if n > 0 then toggle:Show() else toggle:Hide(); panel:Hide() end
        toggle.text:SetText("Add-ons  " .. n)
        return n
    end
    -- What each gathered button looks like to the game, for finding out why one is dim: /fgui buttons.
    local function Say(fn, obj, ...)
        if type(fn) ~= "function" then return "?" end
        local ok, a, b, c = pcall(fn, obj, ...)
        if not ok then return "?" end
        if type(a) == "number" and type(b) == "number" and type(c) == "number" then return format("%.2f,%.2f,%.2f", a, b, c) end
        if b ~= nil then return tostring(a) .. " " .. tostring(b) end
        if type(a) == "number" then return (a == math.floor(a)) and tostring(a) or format("%.2f", a) end
        return tostring(a)
    end
    function ns:ButtonBagLines()
        local lines = { format("Gathered minimap buttons: %d (panel level %s, strata %s; %s)", #order, Say(panel.GetFrameLevel, panel), Say(panel.GetFrameStrata, panel), tostring(ns.buttonBagState or "not arranged yet")) }
        for i, f in ipairs(order) do
            lines[#lines + 1] = format("%d. %s | shown %s | alpha %s (seen as %s) | enabled %s | level %s %s | type %s", i, Say(f.GetName, f), Say(f.IsShown, f),
                Say(f.GetAlpha, f), Say(f.GetEffectiveAlpha, f), Say(f.IsEnabled, f), Say(f.GetFrameLevel, f), Say(f.GetFrameStrata, f), Say(f.GetObjectType, f))
            local n = 0
            for _, region in ipairs({ f:GetRegions() }) do
                if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" and n < 6 then
                    n = n + 1
                    lines[#lines + 1] = format("     texture %s | atlas %s | layer %s | shown %s | alpha %s | grey %s | color %s", Say(region.GetTexture, region), Say(region.GetAtlas, region),
                        Say(region.GetDrawLayer, region), Say(region.IsShown, region), Say(region.GetAlpha, region), Say(region.IsDesaturated, region), Say(region.GetVertexColor, region))
                end
            end
        end
        return lines
    end
    ns.buttonBagTest = { order = order, Arrange = function() return Arrange() end, Bright = Bright, Wanted = Wanted, panel = panel }

    local function Scan()
        if InCombatLockdown() then return end                    -- (a button may be a secure one: it can't be moved in a fight)
        local changed = false
        for _, parent in ipairs({ _G.Minimap, _G.MinimapCluster, _G.MinimapBackdrop }) do
            if type(parent) == "table" and parent.GetChildren then
                for _, f in ipairs({ parent:GetChildren() }) do
                    if IsAddonButton(f) then
                        found[f] = true
                        order[#order + 1] = f
                        f:SetParent(panel)
                        f:SetSize(SIZE, SIZE)
                        if f.SetFrameStrata then f:SetFrameStrata("HIGH") end
                        if f.RegisterForDrag then pcall(f.RegisterForDrag, f) end      -- no dragging back onto the map's rim
                        changed = true
                    end
                end
            end
        end
        if not changed then                                      -- (one may have been hidden or shown by its add-on since)
            local n = 0
            for _, f in ipairs(order) do if Wanted(f) then n = n + 1 end end
            changed = (n ~= lastShown)
        end
        if changed then Arrange() end
    end
    -- each time the panel opens, and while it is open: nothing behind the backing, nothing faded
    panel:HookScript("OnShow", function() if not InCombatLockdown() then pcall(Arrange) end end)
    ns:Every(0.5, "Minimap buttons shown", function()
        if InCombatLockdown() or not ns.Yes(panel:IsShown()) then return end
        for _, f in ipairs(order) do if Wanted(f) then Bright(f) end end
    end)

    -- add-ons create their buttons at different moments: look often at first, then now and then
    local age = 0
    ns:Every(2, "Minimap buttons", function(step)
        age = age + step
        if age <= 40 or age % 20 < 2 then Scan() end
    end)
    Scan()
    ns:RegisterMovable(toggle, "buttonBag", "Add-on Buttons")
end)
