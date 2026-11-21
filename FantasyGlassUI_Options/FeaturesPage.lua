-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end
local O = ns.optUI
local DESC, INSTANT = ns.featureDesc, ns.featureInstant
local LOCKED_HIDE, LOCKED_LABEL = O.LOCKED_HIDE, O.LOCKED_LABEL

-- The page a section of the settings window is shown on (12.0). At the top, where it is and a line on
-- what is in it; then its rows, one setting to a line with what it does and its switch or slider;
-- then its larger pieces (see Categories.lua): slices of the other pages, the frame and bar designers,
-- your lists and rules.

-- The "Send to" boxes of the mail section: a character's name for each kind of material.
local EXTRAS = {}
EXTRAS.mailTargets = function(parent)
    local f = CreateFrame("Frame", nil, parent)
    local title = f:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 12, true)
    title:SetPoint("TOPLEFT", 0, 0)
    title:SetText(ns:Tr("Send to"))
    ns:Paint(title, "SetTextColor", "@accent")
    local LABEL = { cloth = "Cloth", leather = "Leather", ore = "Ore and stone", herbs = "Herbs", cooking = "Cooking ingredients",
        elemental = "Elemental", enchanting = "Enchanting materials", gems = "Gems", potions = "Potions and food" }
    f.boxes = {}
    local targets = ns.MailTargets and ns.MailTargets() or {}
    for i, sw in ipairs(ns.MAIL_SWITCHES or {}) do
        local kind = sw[2]
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        local x, y = col * 245, -22 - row * 46
        local label = f:CreateFontString(nil, "OVERLAY")
        ns:Font(label, 11)
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(ns:Tr(LABEL[kind]))
        ns:Paint(label, "SetTextColor", "dim")
        local box = ns:CreateEditBox(f, 230, 22, "a character's name")
        box:SetPoint("TOPLEFT", x, y - 16)
        box:SetText(targets[kind] or "")
        local function Save()
            local t = ns.MailTargets()
            local v = strtrim(box:GetText() or "")
            t[kind] = (v ~= "") and v or nil
        end
        box:HookScript("OnTextChanged", function(_, user) if user ~= false then Save() end end)
        box:HookScript("OnEditFocusLost", Save)
        box.kind = kind
        f.boxes[kind] = box
    end
    local h = 22 + math.ceil(#(ns.MAIL_SWITCHES or {}) / 3) * 46
    f.Refresh = function()
        local t = ns.MailTargets()
        for kind, box in pairs(f.boxes) do if not box:HasFocus() then box:SetText(t[kind] or "") end end
    end
    f:SetSize(736, h)
    return f, h
end
ns.FeatureExtras = EXTRAS

-- A setting's name, whichever kind it is.
function O.RowLabel(name)
    local def = ns.settingRows[name]
    if def then return def.label end
    local label = ns.featureLabels and ns.featureLabels[name]
    return label and ((ns.aurasLocked and LOCKED_LABEL[name]) or label) or nil
end
function O.RowDesc(name)
    local def = ns.settingRows[name]
    return def and def.desc or DESC[name] or ""
end

local ROW_H, SLIDER_H, BUTTON_H = 42, 48, 36
local function BuildSections(page)
    page.rows = {}                                            -- every row, made once: { [name] = frame }
    page.boxes = {}                                           -- a feature's switch, by its key
    local area = page.area

    -- the top: where this is, its name, a line on what is in it, and two buttons
    local crumb = page:CreateFontString(nil, "OVERLAY")
    ns:Font(crumb, 11)
    crumb:SetPoint("TOPLEFT", 0, 0)
    ns:Paint(crumb, "SetTextColor", "faint")
    local heading = page:CreateFontString(nil, "OVERLAY")
    ns:Font(heading, 18, true)
    heading:SetPoint("TOPLEFT", 0, -16)
    ns:Paint(heading, "SetTextColor", "@accent")
    local newTag = ns.NewTag(page)
    newTag:SetPoint("LEFT", heading, "RIGHT", 10, 0)
    local intro = page:CreateFontString(nil, "OVERLAY")
    ns:Font(intro, 11)
    intro:SetPoint("TOPLEFT", 0, -42)
    intro:SetWidth(520)
    intro:SetJustifyH("LEFT")
    ns:Paint(intro, "SetTextColor", "dim")
    page.heading, page.crumb, page.intro = heading, crumb, intro

    local resetBtn = ns:CreateButton(page, "", 220, 22, ns:ConfirmClick(function() O.ResetCategory(page.category) end))
    resetBtn:SetPoint("TOPRIGHT", page, "TOPRIGHT", -12, -14)
    resetBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(self.text:GetText())
        GameTooltip:AddLine(ns:Tr("Every switch and slider of this category goes back to how Fantasy Glass UI comes. Your lists, rules, designs and positions are kept."), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    resetBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    page.resetButton = resetBtn
    local sampleBtn = ns:CreateButton(page, "", 170, 22, function()
        if ns.TogglePreview then ns:TogglePreview() end
        page.DrawSamples()
    end)
    sampleBtn:SetPoint("RIGHT", resetBtn, "LEFT", -8, 0)
    O.Tip(sampleBtn, "Show sample frames", "Made-up party, raid and boss frames, bars and alerts, so you can see what you change. Click again to put them away.")
    local sampleNote = page:CreateFontString(nil, "OVERLAY")
    ns:Font(sampleNote, 10)
    sampleNote:SetPoint("TOPRIGHT", sampleBtn, "BOTTOMRIGHT", 0, -4)
    ns:Paint(sampleNote, "SetTextColor", "@accent")
    page.sampleButton = sampleBtn
    function page.DrawSamples()
        sampleBtn.text:SetText(ns:Tr(ns.previewing and "Hide sample frames" or "Show sample frames"))
        sampleNote:SetText(ns.previewing and ns:Tr("Showing sample frames") or "")
    end

    -- Rows ---------------------------------------------------------------------------------------
    local function Hover(row, on)
        if on then row.wash:Show() else row.wash:Hide() end
    end
    local function Explain(row)
        local name = row.name
        GameTooltip:SetOwner(row, "ANCHOR_NONE")
        GameTooltip:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 4)
        GameTooltip:AddLine(ns:Tr(O.RowLabel(name) or name))
        local desc = O.RowDesc(name)
        if desc ~= "" then GameTooltip:AddLine(ns:Tr(desc), 1, 1, 1, true) end
        if row.feature then
            local needs = ns.featureNeeds and ns.featureNeeds[name]
            if needs and not ns.db[needs] then
                GameTooltip:AddLine(format(ns:Tr("Needs \"%s\" switched on."), ns:Tr(O.RowLabel(needs) or needs)), 1, 0.82, 0, true)
            end
            GameTooltip:AddLine(ns:Tr(INSTANT[name] and "Takes effect at once." or "Takes effect after a /reload."), 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end
    local function Base(name, h)
        local row = CreateFrame("Button", nil, page)
        row:SetHeight(h)
        row.name = name
        row.wash = row:CreateTexture(nil, "BACKGROUND")
        row.wash:SetAllPoints()
        row.wash:SetTexture(ns.FLAT)
        ns:Paint(row.wash, "SetVertexColor", "@accent", 0.08)
        row.wash:Hide()
        row.line = row:CreateTexture(nil, "BORDER")
        row.line:SetTexture(ns.FLAT)
        row.line:SetHeight(1)
        row.line:SetPoint("TOPLEFT", 0, 0)
        row.line:SetPoint("TOPRIGHT", 0, 0)
        ns:Paint(row.line, "SetVertexColor", "@border", 0.45)
        row:SetScript("OnEnter", function(self) Hover(self, true); Explain(self) end)
        row:SetScript("OnLeave", function(self) Hover(self, false); GameTooltip:Hide() end)
        row:Hide()
        page.rows[name] = row
        return row
    end
    local function Words(row, name)
        row.words = strlower(ns:Tr(O.RowLabel(name) or name) .. " " .. ns:Tr(O.RowDesc(name)) .. " " .. name)
    end
    local function MakeSwitchRow(name, feature)
        local row = Base(name, ROW_H)
        row.feature = feature
        row.title = row:CreateFontString(nil, "OVERLAY")
        ns:Font(row.title, 12)
        row.title:SetPoint("TOPLEFT", 10, -6)
        row.title:SetJustifyH("LEFT")
        if row.title.SetWordWrap then row.title:SetWordWrap(false) end
        row.title:SetText(ns:Tr(O.RowLabel(name)))
        row.tag = row:CreateFontString(nil, "OVERLAY")
        ns:Font(row.tag, 10)
        row.tag:SetPoint("LEFT", row.title, "RIGHT", 8, 0)
        ns:Paint(row.tag, "SetTextColor", "faint")
        row.tag:SetText((feature and not INSTANT[name]) and ns:Tr("after /reload") or "")
        row.desc = row:CreateFontString(nil, "OVERLAY")
        ns:Font(row.desc, 11)
        row.desc:SetPoint("TOPLEFT", 10, -23)
        row.desc:SetPoint("RIGHT", row, "RIGHT", -64, 0)
        row.desc:SetJustifyH("LEFT")
        if row.desc.SetWordWrap then row.desc:SetWordWrap(false) end
        ns:Paint(row.desc, "SetTextColor", "dim")
        row.desc:SetText(ns:Tr(O.RowDesc(name)))
        local sw = ns:CreateCheckbox(row, O.RowLabel(name), ns.db[name], function(v)
            ns.db[name] = v
            if feature then
                if INSTANT[name] then ns:ApplyInstant() else O.NeedReload(name) end
                if page.Dim then page.Dim() end
                if O.RefreshCounts then O.RefreshCounts() end
            elseif ns.ApplyInstant then pcall(ns.ApplyInstant, ns) end
            O.NoteChange()
        end)
        sw:SetWidth(36)
        sw.label:Hide()
        sw:ClearAllPoints()
        sw:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        sw.key, sw.row = name, row
        sw:HookScript("OnEnter", function() Hover(row, true); Explain(row) end)
        sw:HookScript("OnLeave", function() Hover(row, false); GameTooltip:Hide() end)
        row.switch = sw
        row:SetScript("OnClick", function() sw:Click() end)
        Words(row, name)
        sw.words = row.words
        if feature then page.boxes[name] = sw end
        return row
    end
    local function MakeSliderRow(name, def)
        local row = Base(name, SLIDER_H)
        local value = def.get and def.get() or tonumber(ns.db[name]) or def.default or def.min
        local syncing = false
        local s = ns:CreateSlider(row, def.label, def.min, def.max, def.step, value, "%d", function(v)
            if syncing then return end
            if def.set then def.set(v) else ns.db[name] = v end
            if def.apply then def.apply(v) end
            O.NoteChange()
        end, 300)
        s:SetPoint("TOPLEFT", 10, -7)
        row.slider = s
        row.Sync = function()
            local v = def.get and def.get() or tonumber(ns.db[name]) or def.default or def.min
            syncing = true; pcall(s.SetValue, s, v); syncing = false
        end
        row.desc = row:CreateFontString(nil, "OVERLAY")
        ns:Font(row.desc, 11)
        row.desc:SetPoint("TOPLEFT", 336, -8)
        row.desc:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        row.desc:SetJustifyH("LEFT")
        ns:Paint(row.desc, "SetTextColor", "dim")
        row.desc:SetText(ns:Tr(def.desc or ""))
        if s.slider then s.slider:HookScript("OnEnter", function() Hover(row, true); Explain(row) end); s.slider:HookScript("OnLeave", function() Hover(row, false); GameTooltip:Hide() end) end
        s.row = row
        Words(row, name)
        s.words = row.words
        return row
    end
    local function MediaNames(kind)
        local lib = ns.SharedMedia and ns.SharedMedia()
        if not lib then return nil end
        local ok, names = pcall(lib.List, lib, kind)
        return (ok and type(names) == "table") and names or {}
    end
    local function MakeButtonRow(name, def)
        local row = Base(name, BUTTON_H)
        local b
        local function Draw()
            if def.kind == "cycle" then
                b.text:SetText(ns:Tr(def.label) .. ":  " .. ns:Tr(ns.db[name] or def.default))
            elseif def.kind == "media" then
                b.text:SetText(ns:Tr(def.label) .. ":  " .. (ns.db[name] and tostring(ns.db[name]) or ns:Tr("ours")))
            else
                b.text:SetText(ns:Tr(def.label))
            end
        end
        b = ns:CreateButton(row, def.label, 290, 24, function(self, button)
            if def.kind == "cycle" then
                local at = 1
                for i, c in ipairs(def.choices) do if c == (ns.db[name] or def.default) then at = i end end
                at = (button == "RightButton") and ((at - 2) % #def.choices + 1) or (at % #def.choices + 1)
                ns.db[name] = def.choices[at]
                if def.apply then def.apply() end
            elseif def.kind == "media" then
                local names = MediaNames(def.media)
                if names then
                    ns.db[name] = ns.NextChoice and ns.NextChoice(names, ns.db[name], button == "RightButton") or names[1]
                    if ns.Retheme then pcall(ns.Retheme, ns) end
                end
            elseif def.run then
                def.run(self)
            end
            Draw()
            O.NoteChange()
        end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetPoint("TOPLEFT", 10, -6)
        ns:Font(b.text, 11)
        b:HookScript("OnEnter", function() Hover(row, true); Explain(row) end)
        b:HookScript("OnLeave", function() Hover(row, false); GameTooltip:Hide() end)
        b.row = row
        row.button, row.Sync = b, Draw
        row.desc = row:CreateFontString(nil, "OVERLAY")
        ns:Font(row.desc, 11)
        row.desc:SetPoint("TOPLEFT", 316, -11)
        row.desc:SetPoint("RIGHT", row, "RIGHT", -14, 0)
        row.desc:SetJustifyH("LEFT")
        if row.desc.SetWordWrap then row.desc:SetWordWrap(false) end
        ns:Paint(row.desc, "SetTextColor", "dim")
        local desc = def.desc or ""
        if def.kind == "media" and not (ns.SharedMedia and ns.SharedMedia()) then desc = "No add-on here brings LibSharedMedia, so there is nothing to choose from yet." end
        row.desc:SetText(ns:Tr(desc))
        Draw()
        Words(row, name)
        b.words = row.words
        return row
    end

    -- every row of every section, made now, so the search finds them all
    ns.indexingTab = "sections"
    for _, cat in ipairs(ns.settingsCategories) do
        for _, sec in ipairs(cat.sections or {}) do
            for _, name in ipairs(sec.rows) do
                local row = page.rows[name]
                if not row then
                    local def = ns.settingRows[name]
                    if not def then
                        if not (ns.aurasLocked and LOCKED_HIDE[name]) and ns.featureLabels[name] then row = MakeSwitchRow(name, true) end
                    elseif def.kind == "check" then row = MakeSwitchRow(name, false)
                    elseif def.kind == "slider" then row = MakeSliderRow(name, def)
                    else row = MakeButtonRow(name, def) end
                end
                if row then
                    row.section = row.section or sec
                    local control = row.switch or row.slider or row.button
                    if control then control.section = sec end
                end
            end
        end
    end
    ns.indexingTab = nil

    -- a switch whose parent is off is dimmed (it can still be set, ready for when the parent is on)
    function page.Dim()
        local needs = ns.featureNeeds or {}
        for key, sw in pairs(page.boxes) do
            local parent = needs[key]
            if sw.row and sw.row.SetAlpha then sw.row:SetAlpha((parent and not ns.db[parent]) and 0.5 or 1) end
        end
    end

    -- Blocks -------------------------------------------------------------------------------------
    -- Each block is lent to the section while it shows, and given back when another is chosen.
    local lent = {}
    local function GiveBack()
        for i = #lent, 1, -1 do pcall(lent[i]); lent[i] = nil end
    end
    local function Wheel(inner)                               -- (the wheel over a block scrolls the whole section)
        if not inner.suiOwnWheel then inner.suiOwnWheel = inner:GetScript("OnMouseWheel") or false end
        inner:SetScript("OnMouseWheel", function(_, delta) area:Scroll(-(tonumber(delta) or 0) * 42) end)
        return function() inner:SetScript("OnMouseWheel", inner.suiOwnWheel or nil) end
    end
    local function Lend(frame, y, height)
        local parent = frame:GetParent()
        local points = {}
        local n = tonumber(frame.GetNumPoints and frame:GetNumPoints()) or 0
        for i = 1, n do points[i] = { frame:GetPoint(i) } end
        local shown = frame.IsShown and frame:IsShown()
        local w0, h0 = frame.GetWidth and frame:GetWidth(), frame.GetHeight and frame:GetHeight()
        frame:SetParent(page)
        frame.lentTo = page
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
        if height and frame.SetHeight then frame:SetHeight(height) end
        frame:Show()
        lent[#lent + 1] = function()
            frame.lentTo = nil
            frame:SetParent(parent)
            frame:ClearAllPoints()
            for _, p in ipairs(points) do frame:SetPoint(unpack(p)) end
            if type(w0) == "number" and type(h0) == "number" and w0 > 0 and h0 > 0 and frame.SetSize then frame:SetSize(w0, h0) end
            if not shown then frame:Hide() end
        end
    end
    local hidden = {}                                         -- headings hidden while the section shows (its own name)
    local function HideHead(sheet, title)
        for _, h in ipairs(rawget(sheet, "allHeads") or {}) do
            if h.text == title and h.fs and h.fs.Hide then
                h.fs:Hide()
                hidden[#hidden + 1] = h.fs
            end
        end
    end
    local function HostBlock(block, y, sec)
        local host = O.pages[block.host]
        if not host or not host.area then return 0 end
        local sheet = host.sheet
        local top, height = O.Band(sheet, block.from, block.to)
        if not top then return 0 end
        if block.from == sec.title then HideHead(sheet, block.from) end
        local inner = host.area
        Lend(inner, y, height)
        inner:SetWidth(736)
        inner:SetBand(top, height)
        lent[#lent + 1] = Wheel(inner)
        lent[#lent + 1] = function() inner:SetBand(nil) end
        if host.Refresh then pcall(host.Refresh) end
        page.shownHosts[block.host] = true
        return height
    end
    -- the frame and bar designers: a row of buttons to choose between them, then the one chosen
    local chips = {}
    local function Chip(i)
        local b = chips[i]
        if not b then
            b = ns:CreateButton(page, "", 100, 22, function(self) if self.pick then self.pick() end end)
            ns:Font(b.text, 11)
            chips[i] = b
        end
        return b
    end
    local function BarsBlock(block, y)
        local host = O.pages.bars
        local T = ns.barsPage
        if not (host and host.area and T) then return 0 end
        local items, at = host.sheet.navItems or {}, {}
        local nBars = (type(ns.barHandles) == "table") and #ns.barHandles or 0
        if T.empty then nBars = 0 end
        for i, item in ipairs(items) do
            local t = item.title
            if block.bars == "bars" then if i <= nBars then at[#at + 1] = i end
            elseif block.bars == "frames" then
                if i > nBars and t ~= "Nameplates" and t ~= "Raid frames" then at[#at + 1] = i end
            elseif t == block.bars then at[#at + 1] = i end
        end
        if #at == 0 then return 0 end
        local h = 0
        if #at > 1 then
            local x, row = 0, 0
            for n, i in ipairs(at) do
                local b = Chip(n)
                b.text:SetText(ns:Tr(items[i].title))
                local w = b.text.GetStringWidth and b.text:GetStringWidth()
                if type(w) ~= "number" or w <= 0 then w = #ns:Tr(items[i].title) * 7 end
                w = math.floor(w + 20)
                if x + w > 736 then x = 0; row = row + 1 end
                b:SetWidth(w)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - row * 26)
                b:Show()
                b.pick = function()
                    host.sheet.NavSelect(i)
                    for k = 1, #at do
                        local c = chips[k]
                        if k == n then ns:Paint(c, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(c, "SetBackdropBorderColor", "@border", 1) end
                    end
                end
                x = x + w + 6
                lent[#lent + 1] = function() b:Hide() end
            end
            h = (row + 1) * 26 + 8
            page.chipCount = #at
            chips[1].pick()
        else
            host.sheet.NavSelect(at[1])
        end
        local inner = host.area
        Lend(inner, y - h, 540)
        inner:SetWidth(736)
        inner:SetBand(0, 540)
        lent[#lent + 1] = Wheel(inner)
        page.shownHosts.bars = true
        return h + 540
    end
    local extras = {}
    page.extras = extras
    local function ToolBlock(frame, y)
        if not frame then return 0 end
        Lend(frame, y)
        if frame.Refresh then pcall(frame.Refresh) end
        local h = frame.GetHeight and frame:GetHeight()
        return (type(h) == "number" and h > 0) and h or 200
    end
    local function Block(block, y, sec)
        if block.host then return HostBlock(block, y, sec)
        elseif block.bars then return BarsBlock(block, y)
        elseif block.list then return ToolBlock(ns.toolsPage and ns.toolsPage.listBlocks[block.list], y)
        elseif block.rule then return ToolBlock(ns.toolsPage and ns.toolsPage.ruleBlocks[block.rule], y)
        elseif block.extra and EXTRAS[block.extra] then
            local e = extras[block.extra]
            if not e then
                local f, h = EXTRAS[block.extra](page)
                e = { frame = f, height = h }
                extras[block.extra] = e
            end
            e.frame:ClearAllPoints()
            e.frame:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
            if e.frame.Refresh then e.frame.Refresh() end
            e.frame:Show()
            lent[#lent + 1] = function() e.frame:Hide() end
            return e.height
        end
        return 0
    end

    -- Showing a section ----------------------------------------------------------------------------
    -- Simple settings: a section's everyday switches, and its other rows.
    function page.RowShown(name)
        if ns:FeatureHidden(name) then return false end
        if ns.settingRows[name] then return true end
        return not ns:SettingsSimple() or ns.simpleFeatures[name] == true
    end
    function page.Show(sec)
        GiveBack()
        for _, fs in ipairs(hidden) do fs:Show() end
        hidden = {}
        for _, row in pairs(page.rows) do row:Hide() end
        page.shownHosts, page.chipCount = {}, 0
        page.section, page.category = sec, sec.category
        crumb:SetText(ns:Tr(sec.category.title))
        heading:SetText(ns:Tr(sec.title))
        newTag:SetShown(ns:SectionIsNew(sec))
        ns:SeeSection(sec)
        intro:SetText(ns:Tr(sec.category.desc or ""))
        resetBtn.text:SetText(format(ns:Tr("Reset %s to how it came"), ns:Tr(sec.category.title)))
        resetBtn.suiArmed, resetBtn.suiLabel = false, nil
        local w = resetBtn.text.GetStringWidth and resetBtn.text:GetStringWidth()
        if type(w) == "number" and w > 0 then resetBtn:SetWidth(math.min(300, math.floor(w + 24))) end
        resetBtn:SetShown(not sec.category.noReset and #(sec.category.sections or {}) > 0 and O.CategoryHasSettings(sec.category))
        sampleBtn:SetShown(sec.category.samples and ns.TogglePreview ~= nil)
        page.DrawSamples()
        local y = -70
        local shown = {}
        for _, name in ipairs(sec.rows) do
            local row = page.rows[name]
            if row and page.RowShown(name) then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, y)
                row:SetPoint("RIGHT", page, "RIGHT", -12, 0)
                if row.switch then row.switch:SetChecked(ns.db[name]) end
                if row.Sync then row.Sync() end
                row:Show()
                y = y - row:GetHeight()
                shown[#shown + 1] = name
            end
        end
        page.shownKeys = shown
        if #shown > 0 then y = y - 18 end
        for _, block in ipairs(sec.blocks or {}) do
            local h = Block(block, y, sec)
            if h and h > 0 then y = y - h - 18 end
        end
        if #shown == 0 and #(sec.blocks or {}) == 0 then
            y = y - 10
        end
        page.Dim()
        page.contentHeight = -y + 20
        area:SetContentHeight(page.contentHeight)
        area:ScrollTo(0)
        return #shown
    end
    page.GiveBack = GiveBack
    page.Refresh = function()
        for name, row in pairs(page.rows) do
            if row.switch then row.switch:SetChecked(ns.db[name]) end
            if row.Sync and row:IsShown() then row.Sync() end
        end
        page.Dim()
        page.DrawSamples()
        for id in pairs(page.shownHosts or {}) do
            local host = O.pages[id]
            if host and host.Refresh then pcall(host.Refresh) end
        end
    end
    ns.featuresPage = page
end
O.BuildSections = BuildSections

-- A small NEW pill.
function ns.NewTag(parent)
    local f = CreateFrame("Frame", nil, parent, ns.template)
    f:SetSize(34, 14)
    f:SetBackdrop(ns.BACKDROP)
    ns:Paint(f, "SetBackdropColor", "@accent", 0.25)
    ns:Paint(f, "SetBackdropBorderColor", "@accent", 0.9)
    f.text = f:CreateFontString(nil, "OVERLAY")
    ns:Font(f.text, 9, true)
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetText(ns:Tr("NEW"))
    ns:Paint(f.text, "SetTextColor", "@accent")
    local w = f.text.GetStringWidth and f.text:GetStringWidth()
    if type(w) == "number" and w > 0 then f:SetWidth(math.floor(w + 12)) end
    f:Hide()
    return f
end
