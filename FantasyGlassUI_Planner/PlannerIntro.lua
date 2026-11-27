local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

------------------------------------------------------------------------------------------
-- The planner's first-time tour: four short pages on what the route planner does, shown once for the
-- account the first time the planner window is opened (or the Guide tab, once this folder is loaded: the tab does not
-- load it), and again whenever "How the planner works" is pressed in the planner window. It wears the settings window's look. It can be
-- skipped at once, read aloud (with "Read talk and quests aloud" on), and used from the keyboard:
-- Left and Right go between pages, Enter or Space goes on, Esc closes.
------------------------------------------------------------------------------------------
local PAGES = {
    { "What the planner does", "The planner works out a route of quests for your level: which to take, in what order, and when to fly, train or hand in. As you play it plans again, so the route keeps up with you. It finds quests through Questie; without Questie it plans the quests in your log." },
    { "Following a route", "The panel shows the step you are on, and the arrow points the way. Steps tick off by themselves as you do them. Press > to move past a step, Plan again to plan from where you are now, and right-click a step for more." },
    { "Your pace", "In Planner settings, the Speed, Safety and Story sliders set what the route goes for. Say how long you can play, and the route takes only what fits and ends at a good place to stop." },
    { "With a friend", "Plan with a friend, and one route suits you both: the same quests, in the same order. Share plan turns your route into a plan code to copy." },
}
ns.PLANNER_INTRO_PAGES = PAGES
local NAME = "FantasyGlassUIPlannerIntro"
local W, PAD = 480, 22
local win

-- Is the tour still to be shown on this account?
function ns:PlannerIntroDue()
    return type(ns.root) == "table" and not ns.root.plannerIntroSeen
end

local function Height(fs, size, width)
    local h = fs.GetStringHeight and fs:GetStringHeight()
    if type(h) == "number" and h > 0 and not ns:IsSecret(h) then return h end
    local text = fs.GetText and fs:GetText()
    local chars = (type(text) == "string") and #text or 0
    local scale = ns.fontScale or 1
    return math.max(1, math.ceil(chars * 0.5 * size * scale / width)) * size * scale * 1.25
end

local function ShowPage(i)
    local n = #PAGES
    i = math.max(1, math.min(n, tonumber(i) or 1))
    win.at = i
    local page = PAGES[i]
    win.count:SetText(format(ns:Tr("%d of %d"), i, n))
    win.title:SetText(ns:Tr(page[1]))
    win.body:SetText(ns:Tr(page[2]))
    win.back:SetShown(i > 1)
    win.next.text:SetText(ns:Tr(i < n and "Next" or "Done"))
    win.skip:SetShown(i < n)
    for k, dot in ipairs(win.dots) do ns:Paint(dot, "SetVertexColor", (k == i) and "@accent" or "rule", 1) end
    -- as tall as the page's text needs, at any text size
    local textW = W - 2 * PAD
    local h = 18 + 14 + 8 + Height(win.title, 20, textW) + 12 + Height(win.body, 14, textW) + 18 + Height(win.hint, 12, textW) + 14 + 28 + 18
    win:SetHeight(math.ceil(math.max(240, h)))
    if ns.db and ns.db.readDialog then win.spoke = ns:Speak(ns:Tr(page[1]) .. ". " .. ns:Tr(page[2])) or win.spoke end
    return i
end

local function Build()
    local f = CreateFrame("Frame", NAME, UIParent, ns.template)
    ns:SetLook(f, "settings")                                    -- (the settings window's look: its grounds and lettering)
    f:SetSize(W, 260)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "window", 1)
    ns:Paint(f, "SetBackdropBorderColor", "@rim", 1)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:Hide()
    local function Text(size, role, title)
        local fs = f:CreateFontString(nil, "OVERLAY")
        ns:Font(fs, size, title)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        if fs.SetWordWrap then fs:SetWordWrap(true) end
        fs:SetWidth(W - 2 * PAD)
        ns:Paint(fs, "SetTextColor", role)
        return fs
    end
    f.count = Text(12, "dim")
    f.count:SetPoint("TOPLEFT", PAD, -18)
    f.title = Text(20, "text", true)
    f.title:SetPoint("TOPLEFT", f.count, "BOTTOMLEFT", 0, -8)
    f.body = Text(14, "text")
    f.body:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -12)
    f.hint = Text(12, "dim")
    f.hint:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", 0, -18)
    f.hint:SetText(ns:Tr("Left and Right go between pages, Enter goes on, Esc closes."))
    f.dots = {}
    for k = 1, #PAGES do
        local dot = f:CreateTexture(nil, "OVERLAY")
        dot:SetTexture(ns.MEDIA .. "dot.tga")
        dot:SetSize(8, 8)
        dot:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD - 26 - (#PAGES - k) * 14, -21)   -- (clear of the X)
        f.dots[k] = dot
    end
    local close = ns:CreateButton(f, "X", 22, 20, function() f:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -8)
    close.suiNavSkip = true
    f.next = ns:CreateButton(f, "Next", 110, 28, function()
        if f.at < #PAGES then ShowPage(f.at + 1) else f:Hide() end
    end)
    f.next:SetPoint("BOTTOMRIGHT", -PAD, 18)
    f.back = ns:CreateButton(f, "Back", 110, 28, function() ShowPage(f.at - 1) end)
    f.back:SetPoint("RIGHT", f.next, "LEFT", -8, 0)
    f.skip = ns:CreateButton(f, "Skip", 110, 28, function() f:Hide() end)
    f.skip:SetPoint("BOTTOMLEFT", PAD, 18)
    ns:ButtonTip(f.skip, "Close the tour. \"How the planner works\" in the planner window opens it again.")
    for _, b in ipairs({ f.next, f.back, f.skip }) do ns:SizeToLabel(b, 110) end
    -- The keys: Left and Right between pages, Enter or Space on, Esc closes. (With the keyboard in the
    -- game's windows on, Tab, Enter and Space are that feature's: the window is one of its windows.)
    f:EnableKeyboard(true)
    f:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end                    -- (the game owns the keys in a fight)
        local used = true
        if key == "RIGHT" then ShowPage(self.at + 1)
        elseif key == "LEFT" then ShowPage(self.at - 1)
        elseif (key == "ENTER" or key == "SPACE") and not (ns.db and ns.db.windowKeys) then self.next:Click()
        elseif key == "ESCAPE" then self:Hide()
        else used = false end
        pcall(self.SetPropagateKeyboardInput, self, not used)
    end)
    f:SetScript("OnShow", function(self)
        pcall(self.SetPropagateKeyboardInput, self, true)
        ns.UISound("IG_CHARACTER_INFO_OPEN")
    end)
    f:SetScript("OnHide", function(self)
        ns.UISound("IG_CHARACTER_INFO_CLOSE")
        if self.spoke and ns.StopReading then pcall(ns.StopReading, ns) end        -- (what it was reading stops with it)
        self.spoke = nil
    end)
    -- a fight closes it: the keys go back to the game at once
    f:RegisterEvent("PLAYER_REGEN_DISABLED")
    f:SetScript("OnEvent", function(self) self:Hide() end)
    if type(ns.WINDOW_KEYS_FRAMES) == "table" then              -- (Tab and Enter, with the keyboard in the game's windows on)
        local have = false
        for _, v in ipairs(ns.WINDOW_KEYS_FRAMES) do if v == NAME then have = true end end
        if not have then ns.WINDOW_KEYS_FRAMES[#ns.WINDOW_KEYS_FRAMES + 1] = NAME end
    end
    return f
end

-- Show the tour at page `at` (1 when not given). Seen once is seen for the account.
function ns:PlannerIntro(at)
    if InCombatLockdown() then return false end
    win = win or Build()
    ShowPage(at or 1)
    win:Show()
    if win.Raise then win:Raise() end
    if type(ns.root) == "table" then ns.root.plannerIntroSeen = true end
    return win
end
function ns:PlannerIntroWindow() return win end
ns.FolderFileDone("planner", "PlannerIntro.lua")
