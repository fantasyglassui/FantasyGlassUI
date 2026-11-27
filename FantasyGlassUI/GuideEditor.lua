local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

------------------------------------------------------------------------------------------
-- Quest guide, 11.0: a route editor and the route on the world map. Part of the guide (see Guide.lua).
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
    local source = name and ns:GuideGet(name)
    if not source then
        local st = ns.GuideState and ns.GuideState()
        source = st and ns:GuideGet(st.name)
    end
    if not source then ns:Print("Which guide? /fgui guide route <name> (/fgui guide lists them)."); return false end
    local work = Copy(source)
    local tripTitle = type(source.title) == "string" and not Secret(source.title) and source.title or nil
    -- The plan and a trip are not saved guides (their names are hidden): Save keeps the edit as a new guide of its
    -- own ("Save as guide"), and the route you follow stays as it is.
    local function Hidden() return ns.GuideHiddenName and ns.GuideHiddenName(work.name) end
    local function Shown()
        if work.name == ns.GUIDE_TRIP then return format(ns:Tr("Gold trip: %s"), tripTitle or "") end
        if Hidden() then return ns:Tr("Plan my route") end
        return tostring(work.name)
    end
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
    local Draw, Sync
    local function Pick(i) at = math.max(1, math.min(#work.steps, i)); Draw() end
    local rowH = math.max(20, math.ceil(11 * (tonumber(ns.fontScale) or 1)) + 6)   -- (a row as tall as its lettering needs)
    Draw = function()
        win.title:SetText(ns:Tr("Route") .. ": " .. Shown() .. "  " .. ns:ToneHex("dim") .. "(" .. #work.steps .. ")|r")
        for i, step in ipairs(work.steps) do
            local r = win.rows[i]
            if not r then
                r = CreateFrame("Button", nil, win.sheet)
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
            r:SetSize(580, rowH)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
            r.text:SetText(format("%s%d|r  %s", ns:ToneHex("dim"), i, ns.GuideLine(step)))
            if i == at then ns:Paint(r.bg, "SetVertexColor", "@accent", 0.25) else r.bg:SetVertexColor(1, 1, 1, 0) end
            r:Show()
        end
        for i = #work.steps + 1, #win.rows do win.rows[i]:Hide() end
        if win.area.SetContentHeight then win.area:SetContentHeight(#work.steps * rowH) end
        local step = work.steps[at]
        win.line:SetText(step and ns.GuideLine(step) or "")
    end
    local function Parse()
        local text = win.line:GetText()
        if type(text) ~= "string" then return nil, "Nothing written." end
        return ns.GuideParseLine(text)
    end
    local function Say(t, good, arg) win.msg:SetText((good and ns:SignalHex("good") or ns:SignalHex("bad")) .. ns.GuideParseWhy(t, arg) .. "|r") end
    -- the buttons are made once; each time the editor opens, Rebind points them at this guide's list
    if not win.buttons then
        win.buttons = {}
        local y1, y2 = -386, -416
        win.buttons.up = win.B("Move up", 70, 14, y1)
        win.buttons.down = win.B("Move down", 70, 90, y1)
        win.buttons.del = win.B("Delete", 80, 166, y1)
        win.buttons.change = win.B("Change this step", 140, 252, y1)
        win.buttons.add = win.B("Add after it", 120, 398, y1)
        win.buttons.here = win.B("Here", 70, 524, y1, function()
            local map, x, y
            if ns.GuideHere then map, x, y = ns.GuideHere() end       -- (all three: "a and f()" would keep only the first)
            if not x then win.msg:SetText(ns:SignalHex("bad") .. ns:Tr("The game does not say where you are here.") .. "|r"); return end
            win.line:SetText(format("goto | %s @ %d:%.1f,%.1f", ns:Tr("Go here"), map, x, y))
        end)
        win.buttons.save = win.B("Save", 100, 14, y2)
        win.buttons.follow = win.B("Save and follow", 140, 120, y2)
        win.buttons.text = win.B("As text", 100, 266, y2)
        -- each as wide as its label (a long word in another language), one after another along its row
        for _, row in ipairs({ { "up", "down", "del", "change", "add", "here" }, { "save", "follow", "text" } }) do
            local prev
            for _, key in ipairs(row) do
                local b = win.buttons[key]
                if ns.GuideFitButton then ns.GuideFitButton(b, b.suiW or 70) end
                if prev then b:ClearAllPoints(); b:SetPoint("LEFT", prev, "RIGHT", 6, 0) end
                prev = b
            end
        end
    end
    local function Rebind()                                  -- point the shared buttons at this guide's list
        win.buttons.up:SetScript("OnClick", function() work.steps, at = ns.RouteMove(work.steps, at, -1); Draw() end)
        win.buttons.down:SetScript("OnClick", function() work.steps, at = ns.RouteMove(work.steps, at, 1); Draw() end)
        win.buttons.del:SetScript("OnClick", function() work.steps, at = ns.RouteDelete(work.steps, at); Draw() end)
        win.buttons.change:SetScript("OnClick", function()
            local step, why, arg = Parse()
            if not step then Say(why or "Not a step.", false, arg); return end
            work.steps[at] = step; Say("Changed.", true); Draw()
        end)
        win.buttons.add:SetScript("OnClick", function()
            local step, why, arg = Parse()
            if not step then Say(why or "Not a step.", false, arg); return end
            work.steps, at = ns.RouteInsert(work.steps, at, step); Say("Added.", true); Draw()
        end)
        local function SaveAs()                              -- (the plan or a trip: a new guide, named as the planner's Save as guide does)
            local base = (work.name == ns.GUIDE_TRIP and tripTitle) or ns:Tr("Planned route")
            local name, n = base, 1
            while ns:GuideGet(name) and n < 99 do n = n + 1; name = format("%s (%d)", base, n) end
            if ns:GuideGet(name) then Say("Too many guides called \"%s\": rename or delete one first.", false, base); return end
            local ok, why = ns:GuideSave({ name = name, steps = work.steps })
            if not ok then Say(why or "Not saved."); return end
            work.name = name
            Sync()
            Draw()
            Say(format(ns:TrN(#work.steps, "Saved as guide \"%s\": %d step.", "Saved as guide \"%s\": %d steps."), name, #work.steps), true)
        end
        win.buttons.save:SetScript("OnClick", function()
            if Hidden() then SaveAs(); return end
            local ok, why = ns:GuideSave(work)
            if ok then Say(format(ns:TrN(#work.steps, "Saved: %d step.", "Saved: %d steps."), #work.steps), true) else Say(why or "Not saved.") end
        end)
        win.buttons.follow:SetScript("OnClick", function() if not Hidden() and ns:GuideSave(work) then win:Hide(); ns:GuideFollow(work.name) end end)
        win.buttons.text:SetScript("OnClick", function() if not Hidden() then ns:GuideEdit(work.name) end end)
    end
    -- The plan or a trip: one button, Save as guide; a saved guide: Save, Save and follow, As text.
    function Sync()
        local hidden = Hidden() and true or false
        local b = win.buttons
        if b.save.text then b.save.text:SetText(ns:Tr(hidden and "Save as guide" or "Save")) end
        if ns.GuideFitButton then ns.GuideFitButton(b.save, hidden and 140 or 100) end
        if hidden then b.follow:Hide(); b.text:Hide() else b.follow:Show(); b.text:Show() end
        win.saveAs = hidden
    end
    Rebind()
    Sync()
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
            GameTooltip:AddLine(ns:AccentHex() .. format("%d. %s", self.index, ns.GuideStepText(self.step)) .. "|r", 1, 1, 1, true)
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
                if k == 1 then ns:Paint(p.tex, "SetVertexColor", "@accent", 1) else ns:Paint(p.tex, "SetVertexColor", "@light", 0.85) end   -- (the next one in the accent, the rest in the theme's light)
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
