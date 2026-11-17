local _, ns = ...

-- A way into the options that doesn't need typing: a small button on the minimap, showing the
-- add-on's icon.   Left-click: options.   Right-click: move panels.   Drag: put it somewhere else
-- along the minimap.
--
-- It sits on our own minimap when that is in use, otherwise on the game's. If one of your other
-- add-ons brought the "data broker" library, the same thing is also published as a launcher, so bars
-- that show launchers can show it.
ns:NewModule("launcher", function()
    local function Tip(tooltip)
        tooltip:AddLine("Fantasy Glass UI  |cff9aa4b4" .. tostring(ns.version) .. "|r")
        tooltip:AddLine(ns:Tr("Left-click: options"), 1, 1, 1)
        tooltip:AddLine(ns:Tr("Right-click: move panels"), 1, 1, 1)
        tooltip:AddLine(ns:Tr("Shift-click: the Tools menu"), 1, 1, 1)
        tooltip:AddLine(ns:Tr("Drag: move this button around the minimap"), 0.6, 0.6, 0.6)
        if ns.safeMode then tooltip:AddLine(ns:Tr("Safe mode is on: every feature is off. /fgui safe leaves it."), 1, 0.82, 0.2, true) end
    end
    local function Click(button)
        if IsShiftKeyDown and IsShiftKeyDown() and ns.ToggleToolsMenu then ns:ToggleToolsMenu()
        elseif button == "RightButton" then ns:ToggleMove() else ns:ToggleConfig() end
    end

    ns.LauncherClick = Click

    local btn
    local function Build()
        if btn then return end
        local host = _G.FantasyGlassUIMinimap or _G.Minimap           -- ours if it is there, else the game's
        if type(host) ~= "table" or not host.GetWidth then return end
        btn = CreateFrame("Button", "FantasyGlassUILauncher", host, ns.template)
        btn:SetSize(22, 22)
        btn:SetFrameLevel((host:GetFrameLevel() or 1) + 8)
        btn:SetBackdrop(ns.BACKDROP)
        ns:Paint(btn, "SetBackdropColor", "window", 0.9)
        ns:Paint(btn, "SetBackdropBorderColor", "@border", 1)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetPoint("TOPLEFT", 2, -2)
        btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        btn.icon:SetTexture(ns.MEDIA .. "icon.tga")
        btn:RegisterForClicks("AnyUp")
        btn:RegisterForDrag("LeftButton")

        -- Where it sits: a spot measured from the minimap's bottom-left corner, kept on or just
        -- outside the minimap so it can't be dragged away and lost.
        local function Place(x, y)
            local w, h = host:GetWidth(), host:GetHeight()
            if type(w) ~= "number" or w <= 0 then w = 180 end
            if type(h) ~= "number" or h <= 0 then h = w end
            x = math.max(-8, math.min(w + 8, tonumber(x) or 0))
            y = math.max(-8, math.min(h + 8, tonumber(y) or 0))
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", host, "BOTTOMLEFT", x, y)
            return x, y
        end
        ns.PlaceLauncher = Place
        local pos = ns.db.launcherPos
        Place(type(pos) == "table" and pos[1] or 6, type(pos) == "table" and pos[2] or 6)

        local dragging = false
        btn:SetScript("OnDragStart", function() dragging = true; GameTooltip:Hide() end)
        btn:SetScript("OnDragStop", function()
            dragging = false
            local _, _, _, x, y = btn:GetPoint(1)
            if type(x) == "number" and type(y) == "number" then ns.db.launcherPos = { x, y } end
        end)
        btn:SetScript("OnUpdate", function()
            if not dragging then return end
            local cx, cy = GetCursorPosition()
            local scale, left, bottom = host:GetEffectiveScale(), host:GetLeft(), host:GetBottom()
            if type(cx) ~= "number" or type(scale) ~= "number" or scale <= 0 or type(left) ~= "number" or type(bottom) ~= "number" then return end
            Place(cx / scale - left, cy / scale - bottom)
        end)
        btn:SetScript("OnClick", function(_, button) Click(button) end)
        btn:SetScript("OnEnter", function(self)
            if dragging then return end
            ns:Paint(self, "SetBackdropBorderColor", "@accent", 1)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            Tip(GameTooltip)
            GameTooltip:AddLine(ns:Tr("Drag: move this button"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            ns:Paint(self, "SetBackdropBorderColor", "@border", 1)
            GameTooltip:Hide()
        end)
    end
    ns:After(1, Build)                                      -- after the minimap has been set up
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
    ev:SetScript("OnEvent", ns:Guard("Launcher events", function() ns:After(1, Build) end))
    ns.BuildLauncher = Build

    -- the same, published for bars that show launchers
    pcall(function()
        local stub = _G.LibStub
        local ldb = stub and stub("LibDataBroker-1.1", true)
        if type(ldb) == "table" and ldb.NewDataObject then
            ldb:NewDataObject("Fantasy Glass UI", {
                type = "launcher", label = "Fantasy Glass UI", icon = ns.MEDIA .. "icon.tga",
                OnClick = function(_, button) Click(button) end,
                OnTooltipShow = Tip,
            })
        end
    end)
end)
