local _, ns = ...

-- How worn a piece of gear is: "62%" and how bad that is, or nothing for a piece that is whole (or
-- has no durability at all).
function ns.DurabilityText(cur, max)
    if type(cur) ~= "number" or type(max) ~= "number" or ns:IsSecret(cur) or ns:IsSecret(max) or max <= 0 or cur >= max then return nil end
    local pct = math.floor(cur / max * 100)
    return pct .. "%", (pct <= 25) and "bad" or (pct <= 60) and "warn" or "good"
end
function ns.AverageItemLevel(levels)
    if type(levels) ~= "table" or #levels == 0 then return nil end
    local sum = 0
    for _, level in ipairs(levels) do sum = sum + level end
    return sum / #levels
end

-- The character window in our style, written against how this client actually builds it
-- (see /fgui tree CharacterFrame):
--   * Equipment slots  - the ornate rim is a pair of child frames (BorderFrame and a second
--     nine-slice); those go, the icon loses its rounded mask, and we add a flat slot with a rim in
--     the item's quality color and the item level in the corner.
--   * Mode tabs        - the six big tabs down the right (CharacterFrameModeTab1..6). Their plate and
--     gold "selected" ring are replaced by our plate; the ring is still read to know which is selected.
--   * Stats pane       - section headers lose their bronze plate for ours; rows get our lettering.
--   * The rest         - stone backdrop behind the stats removed, title strip and remaining gold art
--     drained and tinted to the theme, model control buttons flattened.
-- The window builds parts of itself as you click around, so it is re-checked while it is open.
ns:NewModule("characterWindow", function()
    local SLOTS = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist", "Legs", "Feet",
                    "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }
    local NO_LEVEL = { [4] = true, [19] = true }           -- shirt and tabard
    local MODELS = { PlayerModel = true, ModelScene = true, DressUpModel = true, CinematicModel = true }
    local EDGE_LAYERS = { BORDER = true, OVERLAY = true }
    local slots = {}

    local function IsTexture(o)
        return type(o) == "table" and o.GetObjectType and o:GetObjectType() == "Texture"
    end
    local function Alpha0(o)
        if type(o) == "table" and o.SetAlpha then o:SetAlpha(0) end
    end
    local function Unmask(icon, mask)
        if IsTexture(icon) and type(mask) == "table" and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, mask) end
    end

    -- Keep the shape, lose the gold: gray it out and tint it with a theme color.
    local function Tint(tex, role, alpha)
        if not IsTexture(tex) or tex.sui or tex.suiTinted then return end
        tex.suiTinted = true
        if tex.SetDesaturated then pcall(tex.SetDesaturated, tex, true) end
        ns:Paint(tex, "SetVertexColor", role or "@btn", alpha)
    end

    -- A flat plate drawn on the frame itself (so its own icon stays on top), with our rim set in by `inset`.
    local function Plate(frame, inset, role, alpha)
        local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetPoint("TOPLEFT", inset, -inset)
        fill:SetPoint("BOTTOMRIGHT", -inset, inset)
        fill:SetTexture(ns.FLAT)
        ns:Paint(fill, "SetVertexColor", role or "bg3", alpha or 0.9)
        fill.sui = true
        ns:AddBorder(frame, 0, 0, 0, 1, -inset)
        return fill
    end

    -- Equipment slots ---------------------------------------------------------------------------
    local KEEP = { "IconOverlay", "IconOverlay2", "ignoreTexture", "searchOverlay", "ItemContextOverlay" }
    local function StyleSlot(slot)
        if slot.suiSlot then return end
        slot.suiSlot, slot.suiChar = true, true
        local name = slot.GetName and slot:GetName() or ""
        local icon = slot.icon or slot.Icon or _G[name .. "IconTexture"]
        local keep = {}
        if icon then keep[icon] = true end
        for _, k in ipairs(KEEP) do
            if slot[k] then keep[slot[k]] = true end
        end
        local hl = slot.HighlightTexture or (slot.GetHighlightTexture and slot:GetHighlightTexture())
        local pushed = slot.PushedTexture or (slot.GetPushedTexture and slot:GetPushedTexture())
        if hl then keep[hl] = true end
        if pushed then keep[pushed] = true end
        for _, r in ipairs({ slot:GetRegions() }) do          -- slot art, quality glow and other trim
            if IsTexture(r) and not keep[r] and not r.sui then r:SetAlpha(0) end
        end
        -- the ornate rim: BorderFrame, plus any other child built from nine-slice pieces
        Alpha0(slot.BorderFrame)
        for _, child in ipairs({ slot:GetChildren() }) do
            if type(child) == "table" and IsTexture(child.TopLeftCorner) and IsTexture(child.Center) then Alpha0(child) end
        end
        Unmask(icon, slot.Mask)
        if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

        Plate(slot, 0, "bg3", 0.9)
        ns:ColorTex(hl, 1, 1, 1, 0.22)
        ns:ColorTex(pushed, 1, 0.85, 0.2, 0.30)

        local layer = CreateFrame("Frame", nil, slot)
        layer:SetAllPoints()
        layer:SetFrameLevel(slot:GetFrameLevel() + 6)
        slot.suiLevel = ns:NewText(layer, 10, "RIGHT")
        slot.suiLevel:SetPoint("BOTTOMRIGHT", -1, 2)
        slot.suiLevel:SetTextColor(1, 0.82, 0)
        slot.suiDur = ns:NewText(layer, 9, "LEFT")           -- how worn it is, shown only once it has taken damage
        slot.suiDur:SetPoint("TOPLEFT", 2, -2)
        if slot.suiDur.SetShadowOffset then slot.suiDur:SetShadowOffset(1, -1); slot.suiDur:SetShadowColor(0, 0, 0, 1) end
        slots[#slots + 1] = slot
    end

    local function RefreshSlot(slot)
        local id = slot.GetID and slot:GetID()
        if type(id) ~= "number" then return end
        local quality = GetInventoryItemQuality and GetInventoryItemQuality("player", id)
        local c = type(quality) == "number" and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if c and quality > 1 then
            slot.suiBorder:SetBackdropBorderColor(c.r, c.g, c.b, 1)
        else
            ns:Paint(slot.suiBorder, "SetBackdropBorderColor", "@border", 1)
        end
        local text, level = "", nil
        local link = GetInventoryItemLink and GetInventoryItemLink("player", id)
        if type(link) == "string" and not NO_LEVEL[id] and C_Item and C_Item.GetDetailedItemLevelInfo then
            local lvl = C_Item.GetDetailedItemLevelInfo(link)
            if type(lvl) == "number" and lvl > 1 then text, level = lvl, lvl end
        end
        slot.suiLevel:SetText(text)
        local worn = ""
        if slot.suiDur and type(GetInventoryItemDurability) == "function" then
            local ok, cur, max = pcall(GetInventoryItemDurability, id)
            local pct, state = ns.DurabilityText(ok and cur, ok and max)
            if pct then worn = ns:SignalHex(state) .. pct .. "|r" end
        end
        if slot.suiDur then slot.suiDur:SetText(worn) end
        return level
    end

    -- the average item level of what you are wearing, above the head slot
    local avgText
    local function ShowAverage(win, levels)
        if not avgText then
            local head = _G.CharacterHeadSlot
            local onSlot = type(head) == "table" and head.GetObjectType
            -- (it hangs on the head slot, so it leaves with the gear page: on the reputation or skills
            --  page there is no head slot showing, and no item level floating over the list)
            local layer = CreateFrame("Frame", nil, onSlot and head or win)
            layer:SetAllPoints(onSlot and head or win)
            layer:SetFrameLevel(((onSlot and head or win):GetFrameLevel() or 1) + 20)
            avgText = ns:NewText(layer, 11, "LEFT")
            if onSlot then avgText:SetPoint("BOTTOMLEFT", head, "TOPLEFT", 0, 4)
            else avgText:SetPoint("TOPLEFT", win, "TOPLEFT", 70, -36) end
            ns:Paint(avgText, "SetTextColor", "@accent")
        end
        local avg = ns.AverageItemLevel(levels)
        avgText:SetText(avg and (ns:Tr("Item level") .. "  " .. format("%.1f", avg)) or "")
    end

    -- Mode tabs (character, reputation, skills, PvP, currency, statistics) use the shared icon tab.

    -- Stats pane ---------------------------------------------------------------------------------------
    local function StyleCategory(f)                       -- "General", "Primary Attributes", "Weapons" ...
        ns:StripArt(f)                                     -- the bronze plate is several pieces
        local fill = f:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", 4, -3)
        fill:SetPoint("BOTTOMRIGHT", -4, 3)
        fill:SetTexture(ns.FLAT)
        ns:Paint(fill, "SetVertexColor", "plate", 0.6)
        fill.sui = true
        local line = f:CreateTexture(nil, "BORDER")
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT", 0, 0)
        line:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 0)
        line:SetTexture(ns.FLAT)
        ns:Paint(line, "SetVertexColor", "@accent", 0.9)
        line.sui = true
        ns:Font(f.Title, 13, true)
    end

    local function StyleStatRow(f)                         -- "Health:  243"
        if IsTexture(f.Background) then
            if f.Background.SetDesaturated then pcall(f.Background.SetDesaturated, f.Background, true) end
            f.Background:SetAlpha(0.35)
        end
        ns:Font(f.Label, 12)
        ns:Paint(f.Label, "SetTextColor", "dim")
        ns:Font(f.Value, 12)
    end

    -- Buttons that have no precise treatment: sidebar tabs, the pane toggle arrow --------------------
    local function TintButton(btn)
        local icon = btn.Icon or btn.icon or btn.Portrait or btn.portrait
        local backs = {}
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetCheckedTexture" }) do
            local t = btn[getter] and btn[getter](btn)
            if t then backs[t] = true; Tint(t) end
        end
        for _, r in ipairs({ btn:GetRegions() }) do
            if IsTexture(r) and r ~= icon and not backs[r] and EDGE_LAYERS[r:GetDrawLayer()] then Tint(r) end
        end
    end

    -- Model controls (zoom, rotate, reset): flat plates, icon tinted
    local function StyleControl(btn)
        if btn.suiChar then return end
        btn.suiChar = true
        Alpha0(btn.NormalTexture); Alpha0(btn.PushedTexture)
        Plate(btn, 2, "plate", 0.8)
        Tint(btn.Icon)
        ns:ColorTex(btn.HighlightTexture, 1, 1, 1, 0.18)
    end

    -- One-off pieces known by name ----------------------------------------------------------------------
    local function StyleFixed(win)
        if win.suiCharFixed then return end
        win.suiCharFixed = true
        local right = _G.CharacterFrameRightPaneHost
        if type(right) == "table" then
            Alpha0(right.StoneBg)                          -- stone behind the stats: our window shows through instead
            for _, r in ipairs({ right:GetRegions() }) do Tint(r, "@border") end
            for _, child in ipairs({ right:GetChildren() }) do
                if type(child) == "table" and child.GetRegions then
                    for _, r in ipairs({ child:GetRegions() }) do Tint(r, "@border") end      -- the divider beside the model
                end
            end
        end
        local stats = _G.CharacterStatsPaneScrollBox
        if type(stats) == "table" then
            Alpha0(stats.Border)
            if IsTexture(stats.ClassBackground) then stats.ClassBackground:SetAlpha(0.25) end
        end
        local doll = _G.PaperDollFrame
        local strip = type(doll) == "table" and doll.TopBackgroundStripHost
        if type(strip) == "table" then                     -- the band behind "Level 9 Shaman"
            Tint(strip.TopBackgroundStrip, "plate", 0.85)
            Tint(strip.TopBackgroundStripBottomEdge, "@border", 1)
        end
        if type(_G.CharacterLevelText) == "table" then ns:Font(_G.CharacterLevelText, 13) end
        local scene = _G.CharacterModelScene
        local controls = type(scene) == "table" and scene.ControlFrame
        if type(controls) == "table" and controls.GetChildren then
            for _, b in ipairs({ controls:GetChildren() }) do
                if type(b) == "table" and b.GetObjectType and b:GetObjectType() == "Button" then pcall(StyleControl, b) end
            end
        end
    end

    -- The other pages (reputation, skills, PvP, statistics, currency): their backdrop and trim are
    -- drained of gold and darkened to the theme; each page's detail pane loses its ornate divider.
    local PAGES = { "ReputationFrame", "SkillsFrame", "PVPRankFrame", "StatisticsFrame", "TokenFrame" }
    local DETAILS = { "ReputationDetailFrame", "SkillDetailFrame", "DetailFrame" }
    local function StylePages()
        for _, name in ipairs(PAGES) do
            local page = _G[name]
            if type(page) == "table" and page.GetRegions and not page.suiPage then
                page.suiPage = true
                for _, r in ipairs({ page:GetRegions() }) do
                    if IsTexture(r) and r:GetDrawLayer() ~= "HIGHLIGHT" then Tint(r, "dim") end
                end
                for _, key in ipairs(DETAILS) do
                    local detail = page[key]
                    if type(detail) == "table" then
                        Tint(detail.Divider, "@border")
                        if type(detail.Title) == "table" and detail.Title.SetFont then ns:Font(detail.Title, 14, true) end
                    end
                end
            end
        end
    end

    -- Bars built as Fill / FillArea / Mask (reputation standing, skill rank, and the same bars in the
    -- detail panes). The decorative frame and backdrop go; the fill and its mask are left exactly as
    -- the game drives them, on a flat trough with our rim.
    local function FlatBar(bar)
        if type(bar) ~= "table" or bar.suiBar or not IsTexture(bar.Fill) or not bar.GetRegions then return end
        bar.suiBar = true
        local own = bar.GetStatusBarTexture and bar:GetStatusBarTexture()       -- some of these are real status bars
        for _, r in ipairs({ bar:GetRegions() }) do
            if IsTexture(r) and r ~= bar.Fill and r ~= own and not r.sui then r:SetAlpha(0) end
        end
        local area = (type(bar.FillArea) == "table" and bar.FillArea.GetObjectType) and bar.FillArea or bar
        local trough = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        trough:SetAllPoints(area)
        trough:SetTexture(ns.FLAT)
        ns:Paint(trough, "SetVertexColor", "trough", 0.9)
        trough.sui = true
        local th = ns.theme
        if area.CreateTexture then ns:Outline(area, -1, th.border[1], th.border[2], th.border[3], 1, "OVERLAY") end
        if type(bar.Text) == "table" and bar.Text.SetFont then ns:Font(bar.Text, 11) end
    end

    -- Every named piece of a frame that is such a bar or a check box, whatever the page calls it
    -- (ReputationBar, SkillsBar, StandingBar, RankBar, AtWarCheckbox ...).
    local TintCheck
    local function PiecesOf(holder)
        if type(holder) ~= "table" then return end
        for key, piece in pairs(holder) do
            if type(key) == "string" and type(piece) == "table" and key:sub(1, 3) ~= "sui" then
                pcall(function()
                    if IsTexture(piece.Fill) then
                        FlatBar(piece)
                    elseif piece.GetObjectType and piece:GetObjectType() == "CheckButton" then
                        TintCheck(piece)
                    end
                end)
            end
        end
    end

    -- A gold check box: keep its shape and its check mark, lose the gold.
    TintCheck = function(box)
        if type(box) ~= "table" or box.suiCheck or not box.GetNormalTexture then return end
        box.suiCheck = true
        Tint(box:GetNormalTexture()); Tint(box.GetPushedTexture and box:GetPushedTexture())
        Tint(box.GetDisabledTexture and box:GetDisabledTexture())
        if type(box.Label) == "table" and box.Label.SetFont then ns:Font(box.Label, 12) end
    end

    -- The list pages (reputation, skills, and any other built the same way). Their lists are made of
    -- header buttons { Name, StateIcon } and entry buttons { Content = { Name, <a bar>, BackgroundHighlight } },
    -- and beside the list sits a detail pane with a title, a divider and the same kind of bar.
    local function ListRow(row)
        if type(row) ~= "table" or row.suiRep or not row.GetRegions then return end
        if type(row.Name) == "table" and IsTexture(row.StateIcon) then                     -- a header ("Alliance", "Professions")
            row.suiRep, row.suiChar = true, true
            for _, r in ipairs({ row:GetRegions() }) do
                if IsTexture(r) and r ~= row.StateIcon and r:GetDrawLayer() ~= "HIGHLIGHT" then r:SetAlpha(0) end
            end
            ns.kit.Heading(row, row.Name, 13)
            Tint(row.StateIcon)
        elseif type(row.Content) == "table" then                                             -- an entry
            row.suiRep, row.suiChar = true, true
            local c = row.Content
            PiecesOf(c)
            if type(c.Name) == "table" and c.Name.SetFont then ns:Font(c.Name, 12) end
            if type(c.Value) == "table" and c.Value.SetFont then                             -- a statistic: "name  value", like the stats pane
                ns:Font(c.Value, 12)
                if type(c.Name) == "table" then ns:Paint(c.Name, "SetTextColor", "dim") end
            end
            if type(row.ToggleCollapseButton) == "table" and row.ToggleCollapseButton.GetRegions then
                pcall(TintButton, row.ToggleCollapseButton)                                   -- the small expand arrow on some entries
            end
            local glow = c.BackgroundHighlight                                                -- shown by the game on hover / selection
            if type(glow) == "table" then
                Tint(glow.Left, "@accent", 0.55); Tint(glow.Middle, "@accent", 0.55); Tint(glow.Right, "@accent", 0.55)
            end
        end
    end

    local LIST_PAGES = {
        { "ReputationFrame", "ReputationDetailFrame" }, { "SkillsFrame", "SkillDetailFrame" },
        { "TokenFrame", "DetailFrame" }, { "PVPRankFrame", "DetailFrame" }, { "StatisticsFrame", "DetailFrame" },
    }
    local function ListPages()
        for _, def in ipairs(LIST_PAGES) do
            local page = _G[def[1]]
            if type(page) == "table" and page.IsVisible and page:IsVisible() then
                local box = page.ScrollBox
                local target = type(box) == "table" and box.ScrollTarget
                if type(target) == "table" and target.GetChildren then
                    for _, row in ipairs({ target:GetChildren() }) do pcall(ListRow, row) end
                end
                -- Each list also carries two small frames of one texture each (its top and bottom trim).
                -- They are there even when the list is empty, as on a character with no currencies.
                if type(box) == "table" and box.GetChildren and not box.suiTrim then
                    box.suiTrim = true
                    for _, child in ipairs({ box:GetChildren() }) do
                        if type(child) == "table" and child ~= target and child ~= box.DragDelegate and child ~= box.Shadows
                           and child.GetRegions and child.GetObjectType and child:GetObjectType() == "Frame" then
                            for _, r in ipairs({ child:GetRegions() }) do Tint(r, "@border") end
                        end
                    end
                end
                local detail = page[def[2]]
                if type(detail) == "table" then
                    PiecesOf(detail)
                    if not detail.suiRep then
                        detail.suiRep = true
                        Tint(detail.Divider, "@border")
                        if type(detail.Title) == "table" and detail.Title.SetFont then ns:Font(detail.Title, 14, true) end
                        if type(detail.Subtitle) == "table" and detail.Subtitle.SetFont then ns:Font(detail.Subtitle, 12) end
                    end
                end
            end
        end
    end

    -- PvP page. Its centrepiece is a round rank emblem with a progress ring (a Cooldown widget); that
    -- is artwork carrying information and is left alone. Around it: a divider line, the gold ring on
    -- the next-reward icon, and in the detail pane a sub-heading plate and a gold item slot.
    local function PvP()
        local page = _G.PVPRankFrame
        if type(page) ~= "table" or not page.IsVisible or not page:IsVisible() then return end
        local main = page.MainInfoFrame
        if type(main) == "table" and not main.suiPvp then
            main.suiPvp = true
            Tint(main.Line, "@border")
            local ring = main.RankProgressBarDisplay
            local reward = type(ring) == "table" and ring.NextRewardLevel
            if type(reward) == "table" then Tint(reward.RingBorder) end
        end
        local detail = page.DetailFrame
        local content = type(detail) == "table" and detail.Content
        if type(content) == "table" and content.GetChildren then
            for _, line in ipairs({ content:GetChildren() }) do
                if type(line) == "table" and not line.suiPvp then
                    line.suiPvp, line.suiChar = true, true
                    if IsTexture(line.Background) and type(line.Label) == "table" then      -- a sub-heading
                        line.Background:SetAlpha(0)
                        ns.kit.Heading(line, line.Label, 12)
                    end
                    Tint(line.IconSlot)                                                      -- the slot behind a reward icon
                end
            end
        end
    end

    -- The three small tabs above the stats. Nothing on them is named except the icon, but the game
    -- hides one of their pieces on the selected tab. So: count the pieces each tab is showing; if the
    -- counts differ, the tab showing the fewest is the selected one, and the tabs can safely take our
    -- plate with an accent on it. If the counts never differ they simply stay tinted, as before.
    local function SidebarTabs()
        local tabs, counts, lo, hi = {}, {}, math.huge, -1
        for i = 1, 4 do
            local tab = _G["PaperDollSidebarTab" .. i]
            if type(tab) == "table" and tab.GetRegions and tab.IsShown and tab:IsShown() then
                local n = 0
                for _, r in ipairs({ tab:GetRegions() }) do
                    if IsTexture(r) and r ~= tab.Icon and not r.sui and r.IsShown and r:IsShown() then n = n + 1 end
                end
                tabs[#tabs + 1] = tab
                counts[tab] = n
                lo, hi = math.min(lo, n), math.max(hi, n)
            end
        end
        if #tabs < 2 or lo == hi then return end
        for _, tab in ipairs(tabs) do
            if not tab.suiPlate then
                tab.suiPlate = true
                for _, r in ipairs({ tab:GetRegions() }) do
                    if IsTexture(r) and r ~= tab.Icon and not r.sui then r:SetAlpha(0) end
                end
                tab.suiFill = ns.kit.Plate(tab, 2, "plate", 0.75)
            end
            local selected = counts[tab] == lo
            if selected ~= tab.suiSelected then
                tab.suiSelected = selected
                if selected then
                    ns:Paint(tab.suiBorder, "SetBackdropBorderColor", "@accent", 1)
                    ns:Paint(tab.suiFill, "SetVertexColor", "@accent", 0.28)
                else
                    ns:Paint(tab.suiBorder, "SetBackdropBorderColor", "@border", 1)
                    ns:Paint(tab.suiFill, "SetVertexColor", "plate", 0.75)
                end
            end
        end
    end

    -- Everything else: walk the window and treat what we recognise ---------------------------------------
    local budget
    local function Walk(f, depth)
        if depth > 7 or type(f) ~= "table" or not f.GetChildren then return end
        for _, child in ipairs({ f:GetChildren() }) do
            budget = budget - 1
            if budget <= 0 then return end
            if type(child) == "table" and child.GetObjectType and not (child.IsForbidden and child:IsForbidden()) then
                local kind = child:GetObjectType()
                if not child.suiChar then
                    child.suiChar = true
                    local hasBg = IsTexture(child.Background)
                    if hasBg and type(child.Title) == "table" and child.Title.SetFont then
                        StyleCategory(child)
                    elseif hasBg and type(child.Label) == "table" and type(child.Value) == "table" then
                        StyleStatRow(child)
                    elseif (kind == "Button" or kind == "CheckButton") and not child.suiControl then
                        TintButton(child)
                    elseif not MODELS[kind] and child.GetRegions then
                        for _, r in ipairs({ child:GetRegions() }) do      -- dividers and trim, not backdrops
                            if IsTexture(r) and EDGE_LAYERS[r:GetDrawLayer()] then Tint(r) end
                        end
                    end
                end
                if not MODELS[kind] and not child.suiSlot and not child.suiTab and not child.suiRep then Walk(child, depth + 1) end
            end
        end
    end

    local dirty = true
    local ev = CreateFrame("Frame")
    pcall(ev.RegisterEvent, ev, "PLAYER_EQUIPMENT_CHANGED")
    pcall(ev.RegisterUnitEvent, ev, "UNIT_INVENTORY_CHANGED", "player")
    pcall(ev.RegisterEvent, ev, "UPDATE_INVENTORY_DURABILITY")
    ev:SetScript("OnEvent", ns:Guard("Character events", function() dirty = true end))

    local function Open()
        local win = _G.CharacterFrame
        return type(win) == "table" and win.IsShown and win:IsShown() and win or nil
    end

    local wasShown = false
    ns:Every(0.5, "Character window", function()
        local win = Open()
        if not win then wasShown = false; return end
        for _, name in ipairs(SLOTS) do
            local slot = _G["Character" .. name .. "Slot"]
            if type(slot) == "table" and slot.GetRegions then pcall(StyleSlot, slot) end
        end
        for i = 1, 8 do
            local tab = _G["CharacterFrameModeTab" .. i]
            if type(tab) == "table" and tab.GetRegions then pcall(ns.kit.IconTab, tab) end
        end
        pcall(StyleFixed, win)
        pcall(StylePages)
        pcall(ListPages)
        pcall(PvP)
        budget = 1500
        Walk(win, 0)
        if dirty or not wasShown then
            dirty = false
            local levels = {}
            for _, slot in ipairs(slots) do
                local ok, level = pcall(RefreshSlot, slot)
                if ok and type(level) == "number" then levels[#levels + 1] = level end
            end
            pcall(ShowAverage, win, levels)
        end
        wasShown = true
    end)

    ns:Every(0.2, "Character tabs", function()
        if Open() then SidebarTabs() end
    end)

end)
