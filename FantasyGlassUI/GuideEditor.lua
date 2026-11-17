local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Quest guide, 11.0: a route editor and the route on the world map. Part of the guide, so only
-- where guides are unlocked (see Guide.lua).
--
-- Route editor (/fgui guide route <name>, or "Edit the route" on the Guide tab): the steps in order;
-- choose one to change its line, move it up or down, delete it, or put a new step after it. "Here"
-- writes a step for the place you are standing. Nothing is kept until Save.
--
-- On the map: while you follow a guide, its next steps are numbered on the world map.
------------------------------------------------------------------------------------------

-- Pure edits on a list of steps (each returns the list and the step now chosen).
function ns.RouteMove(steps, i, by)
    local j = i + by
    if not steps[i] or j < 1 or j > #steps then return steps, i end
    steps[i], steps[j] = steps[j], steps[i]
    return steps, j
end
function ns.RouteDelete(steps, i)
    if not steps[i] then return steps, i end
    table.remove(steps, i)
    return steps, math.min(i, #steps)
end
function ns.RouteInsert(steps, i, step)
    local at = math.max(0, math.min(#steps, i or #steps)) + 1
    table.insert(steps, at, step)
    return steps, at
end
local function Copy(guide)
    local out = { name = guide.name, steps = {} }
    for i, s in ipairs(guide.steps or {}) do
        local c = {}
        for k, v in pairs(s) do c[k] = v end
        out.steps[i] = c
    end
    return out
end

local win
function ns:GuideRouteEditor(name)
    if not (ns.GuideUnlocked and ns:GuideUnlocked()) then ns:Print("Quest guides are coming soon."); return false end
    local source = name and ns:GuideGet(name)
    if not source then
        local st = ns.GuideState and ns.GuideState()
        source = st and ns:GuideGet(st.name)
    end
    if not source then ns:Print("Which guide? /fgui guide route <name> (/fgui guide lists them)."); return false end
    local work = Copy(source)
    local at = 1
    if not win then
        win = CreateFrame("Frame", "FantasyGlassUIRouteEditor", UIParent, ns.template)
        win:SetSize(620, 470)
        win:SetPoint("CENTER")
        win:SetFrameStrata("DIALOG")
        win:SetBackdrop(ns.BACKDROP)
        ns:Paint(win, "SetBackdropColor", "window", 0.97)
        ns:Paint(win, "SetBackdropBorderColor", "@accent", 1)
        ns:Dress(win)
        win:EnableMouse(true)
        win:SetMovable(true); if win.SetClampedToScreen then win:SetClampedToScreen(true) end
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", win.StopMovingOrSizing)
        tinsert(UISpecialFrames, "FantasyGlassUIRouteEditor")
        win.title = win:CreateFontString(nil, "OVERLAY")
        ns:Font(win.title, 15, true)
        win.title:SetPoint("TOPLEFT", 14, -12)
        ns:Paint(win.title, "SetTextColor", "@accent")
        local close = ns:CreateButton(win, "X", 22, 20, function() win:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        win.area, win.sheet = ns:ScrollArea(win, 592, 280)
        win.area:SetPoint("TOPLEFT", 14, -40)
        win.rows = {}
        win.line = ns:CreateEditBox(win, 592, 24, "accept 123 Title | note @ 45.2,61.8")
        win.line:SetPoint("TOPLEFT", 14, -330)
        win.msg = ns:NewText(win, 11, "LEFT")
        win.msg:SetPoint("TOPLEFT", 14, -360)
        win.msg:SetWidth(592)
        local function B(label, w, x, y, fn) local b = ns:CreateButton(win, label, w, 22, fn); b:SetPoint("TOPLEFT", x, y); return b end
        win.B = B
    end
    local Draw
    local function Pick(i) at = math.max(1, math.min(#work.steps, i)); Draw() end
    Draw = function()
        win.title:SetText(ns:Tr("Route") .. ": " .. tostring(work.name) .. "  |cff9aa4b4(" .. #work.steps .. ")|r")
        for i, step in ipairs(work.steps) do
            local r = win.rows[i]
            if not r then
                r = CreateFrame("Button", nil, win.sheet)
                r:SetSize(580, 18)
                r:SetPoint("TOPLEFT", 0, -(i - 1) * 18)
                r.bg = r:CreateTexture(nil, "BACKGROUND")
                r.bg:SetAllPoints()
                r.bg:SetTexture(ns.FLAT)
                r.text = ns:NewText(r, 11, "LEFT")
                r.text:SetPoint("LEFT", 4, 0)
                r.text:SetWidth(572)
                r.text:SetWordWrap(false)
                r:SetScript("OnClick", function(self) Pick(self.index) end)
                win.rows[i] = r
            end
            r.index = i
            r.text:SetText(format("|cff9aa4b4%d|r  %s", i, ns.GuideLine(step)))
            if i == at then ns:Paint(r.bg, "SetVertexColor", "@accent", 0.25) else r.bg:SetVertexColor(1, 1, 1, 0) end
            r:Show()
        end
        for i = #work.steps + 1, #win.rows do win.rows[i]:Hide() end
        if win.area.SetContentHeight then win.area:SetContentHeight(#work.steps * 18) end
        local step = work.steps[at]
        win.line:SetText(step and ns.GuideLine(step) or "")
    end
    local function Parse()
        local text = win.line:GetText()
        if type(text) ~= "string" then return nil, "nothing written" end
        return ns.GuideParseLine(text)
    end
    local function Say(t, good) win.msg:SetText((good and "|cff33ff66" or "|cffff5555") .. ns:Tr(t) .. "|r") end
    -- the buttons are made once; each time the editor opens, Rebind points them at this guide's list
    if not win.buttons then
        win.buttons = {}
        local y1, y2 = -386, -416
        win.buttons.up = win.B("Up", 70, 14, y1)
        win.buttons.down = win.B("Down", 70, 90, y1)
        win.buttons.del = win.B("Delete", 80, 166, y1)
        win.buttons.change = win.B("Change this step", 140, 252, y1)
        win.buttons.add = win.B("Add after it", 120, 398, y1)
        win.buttons.here = win.B("Here", 70, 524, y1, function()
            local map, x, y = ns.GuideHere and ns.GuideHere()
            if not x then win.msg:SetText("|cffff5555" .. ns:Tr("The game does not say where you are here.") .. "|r"); return end
            win.line:SetText(format("goto | %s @ %d:%.1f,%.1f", ns:Tr("Go here"), map, x, y))
        end)
        win.buttons.save = win.B("Save", 100, 14, y2)
        win.buttons.follow = win.B("Save and follow", 140, 120, y2)
        win.buttons.text = win.B("As text", 100, 266, y2)
    end
    local function Rebind()                                  -- point the shared buttons at this guide's list
        win.buttons.up:SetScript("OnClick", function() work.steps, at = ns.RouteMove(work.steps, at, -1); Draw() end)
        win.buttons.down:SetScript("OnClick", function() work.steps, at = ns.RouteMove(work.steps, at, 1); Draw() end)
        win.buttons.del:SetScript("OnClick", function() work.steps, at = ns.RouteDelete(work.steps, at); Draw() end)
        win.buttons.change:SetScript("OnClick", function()
            local step, why = Parse()
            if not step then Say(why or "not a step"); return end
            work.steps[at] = step; Say("Changed.", true); Draw()
        end)
        win.buttons.add:SetScript("OnClick", function()
            local step, why = Parse()
            if not step then Say(why or "not a step"); return end
            work.steps, at = ns.RouteInsert(work.steps, at, step); Say("Added.", true); Draw()
        end)
        win.buttons.save:SetScript("OnClick", function()
            local ok, why = ns:GuideSave(work)
            if ok then Say(format(ns:Tr("Saved: %d steps."), #work.steps), true) else Say(why or "not saved") end
        end)
        win.buttons.follow:SetScript("OnClick", function() if ns:GuideSave(work) then win:Hide(); ns:GuideFollow(work.name) end end)
        win.buttons.text:SetScript("OnClick", function() ns:GuideEdit(work.name) end)
    end
    Rebind()
    win.msg:SetText("")
    Draw()
    win:Show()
    ns.routeEditorTest = { win = win, work = function() return work end, pick = Pick, at = function() return at end }
    return win
end

------------------------------------------------------------------------------------------
-- The route on the world map: the next steps of the guide you follow, numbered, on the map they are in.
------------------------------------------------------------------------------------------
ns.GUIDE_MAP_STEPS = 6
-- The steps to show from the one you are on: { index, step } for those that have a place on `mapID`.
function ns.RouteAhead(steps, from, mapID, count)
    local out = {}
    for i = from or 1, #steps do
        local s = steps[i]
        if s.x and s.y and (s.map == nil or s.map == mapID) then out[#out + 1] = { index = i, step = s } end
        if #out >= (count or ns.GUIDE_MAP_STEPS) then break end
    end
    return out
end
do
    local pins = {}
    local function Pin(canvas, i)
        local p = CreateFrame("Frame", nil, canvas)
        p:SetSize(20, 20)
        p:SetFrameLevel((canvas:GetFrameLevel() or 1) + 21)
        p.tex = p:CreateTexture(nil, "ARTWORK")
        p.tex:SetAllPoints()
        p.tex:SetTexture(ns.MEDIA .. "dot.tga")
        p.num = p:CreateFontString(nil, "OVERLAY")
        ns:Font(p.num, 10, true)
        p.num:SetPoint("CENTER")
        p.num:SetTextColor(0, 0, 0)
        p:EnableMouse(true)
        p:SetScript("OnEnter", function(self)
            if not self.step then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(format("%d. %s", self.index, ns.GuideStepText(self.step)), 1, 0.82, 0.2, true)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        pins[i] = p
        return p
    end
    local function Update()
        local map = _G.WorldMapFrame
        local canvas = type(map) == "table" and ((map.ScrollContainer and map.ScrollContainer.Child) or (map.GetCanvas and map:GetCanvas()))
        local n = 0
        local st = ns.GuideState and ns.GuideState()
        local guide = st and ns.GuideOn and ns:GuideOn() and ns:GuideGet(st.name)
        local mapID = canvas and map.GetMapID and map:GetMapID()
        if guide and type(mapID) == "number" and not Secret(mapID) and canvas.GetWidth then
            local w, h = canvas:GetWidth(), canvas:GetHeight()
            local scale = canvas.GetScale and canvas:GetScale() or 1
            local size = (type(scale) == "number" and scale > 0) and (1 / scale) or 1
            for k, item in ipairs(ns.RouteAhead(guide.steps, st.at, mapID)) do
                n = k
                local p = pins[k] or Pin(canvas, k)
                p.step, p.index = item.step, item.index
                p:SetScale(size)
                p:ClearAllPoints()
                local px, py = ns.MapDotOffset(item.step.x / 100, item.step.y / 100, w, h, size)
                p:SetPoint("CENTER", canvas, "TOPLEFT", px, py)
                p.num:SetText(item.index)
                if k == 1 then ns:Paint(p.tex, "SetVertexColor", "@accent", 1) else p.tex:SetVertexColor(1, 0.82, 0.2, 0.85) end
                p:Show()
            end
        end
        for i = n + 1, #pins do pins[i]:Hide() end
        return n
    end
    ns.routeMapUpdate = Update
    ns:Every(0.5, "Guide on the map", function()
        local map = _G.WorldMapFrame
        if type(map) == "table" and map.IsShown and ns.Yes(map:IsShown()) and ns.MapDotOffset then Update() end
    end)
end
