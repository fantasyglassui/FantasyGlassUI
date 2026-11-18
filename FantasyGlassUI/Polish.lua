local _, ns = ...

-- Window-specific passes, written against how this client builds each window (/fgui tree).
-- These windows are loaded by the game on first use and build parts of themselves as you click
-- around, so each pass runs twice a second while its window is open and only touches new pieces.
--   * World map: the quest panel beside the map (tabs, headers, checkboxes, count plate, ornate rim).
--   * Guild / communities: filigree and inner borders, column headers, side tabs, watermark.
--   * Vendor: item cards, item buttons with quality rims, money plates.
--   * Mailbox: inbox rows and their item buttons, the Send Mail page's fields.
--   * Quest giver's dialog (and the quest details beside the map): parchment removed, text relit.
--   * Professions: side tabs, rank bars, ability buttons, gear slots.
--   * Collections: side tabs, list rows, count plates, icon grids, toy buttons, model controls.
--   * Auction house: every panel in turn, column headers, rows, categories, item displays, money boxes.
--   * Class trainer: rows, the money plate, the skill bar.
-- The spellbook has its own file (Spellbook.lua).
--   * Talent tree: squared icons whose rim color shows each talent's state, when that state can be read.
ns:NewModule("windows", function()
    local kit = ns.kit
    local IsTexture, Hide, Tint = kit.IsTexture, kit.Hide, kit.Tint

    local function Shown(f)
        return type(f) == "table" and f.IsVisible and f:IsVisible()
    end
    local function Each(frame, fn)                      -- direct children, safely
        if type(frame) ~= "table" or not frame.GetChildren then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            if type(child) == "table" and child.GetObjectType and not (child.IsForbidden and child:IsForbidden()) then
                pcall(fn, child, child:GetObjectType())
            end
        end
    end
    local function Once(f, key)                         -- true the first time only
        if type(f) ~= "table" or f[key] then return false end
        f[key] = true
        return true
    end
    -- the ornate rim most side panels carry: BorderFrame { Border, TopDetail, Shadow }
    local function PlainRim(panel)
        local bf = type(panel) == "table" and panel.BorderFrame
        if type(bf) == "table" and Once(bf, "suiRimDone") then
            Hide(bf.Border); Hide(bf.TopDetail)
        end
    end
    -- a gold push/check box: keep the shape and the check mark, lose the gold
    local function TintBox(box, keep)
        if type(box) ~= "table" or not box.GetRegions or not Once(box, "suiBoxDone") then return end
        for _, r in ipairs({ box:GetRegions() }) do
            if IsTexture(r) and r ~= keep then Tint(r) end
        end
    end

    -- Quest panel beside the world map -------------------------------------------------------------
    local function QuestRow(child, kind)
        if kind ~= "Button" or child.suiQuestRow then return end
        child.suiQuestRow = true
        if type(child.CollapseButton) == "table" and type(child.ButtonText) == "table" then      -- zone header
            for _, r in ipairs({ child:GetRegions() }) do
                if IsTexture(r) and r:GetDrawLayer() ~= "HIGHLIGHT" then r:SetAlpha(0) end
            end
            kit.Heading(child, child.ButtonText, 13)
        elseif type(child.Checkbox) == "table" then                                               -- a quest line
            TintBox(child.Checkbox, child.Checkbox.CheckMark)
        end
    end

    local function QuestPanel()
        local panel = _G.QuestMapFrame
        if not Shown(panel) then return end
        for _, key in ipairs({ "QuestsTab", "EventsTab", "MapLegendTab" }) do pcall(kit.IconTab, panel[key]) end
        if Once(panel, "suiPolish") then Tint(panel.VerticalSeparator, "@border") end

        local scroll = _G.QuestScrollFrame
        if type(scroll) == "table" then
            if Once(scroll, "suiPolish") then
                Hide(scroll.Background)                    -- the dark parchment: our window shows instead
                Tint(scroll.Edge, "@border")
                PlainRim(scroll)
            end
            Each(scroll.Contents, QuestRow)
        end
        local count = _G.QuestLogCount
        if type(count) == "table" and Once(count, "suiPolish") then
            Hide(count.Left); Hide(count.Middle); Hide(count.Right)
            kit.Plate(count, 1, "plate", 0.7)
            if type(_G.QuestLogQuestCount) == "table" then ns:Font(_G.QuestLogQuestCount, 11) end
        end
        -- the other pages of the panel lose the ornate rim (the quest details page is handled further
        -- down, together with the quest giver's dialog)
        local quests = panel.QuestsFrame
        if type(quests) == "table" then PlainRim(quests.DetailsFrame) end
        PlainRim(panel.DetailsFrame); PlainRim(panel.EventsFrame); PlainRim(panel.MapLegend)
    end

    -- Guild / communities ----------------------------------------------------------------------------
    local function SideTab(tab, kind)                    -- chat / roster / perks / info, down the side
        if kind ~= "CheckButton" or not IsTexture(tab.Icon) or not Once(tab, "suiPolish") then return end
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetCheckedTexture", "GetDisabledTexture" }) do
            local t = tab[getter] and tab[getter](tab)
            if t then Tint(t) end
        end
        for _, r in ipairs({ tab:GetRegions() }) do
            local layer = IsTexture(r) and r:GetDrawLayer()
            if layer and r ~= tab.Icon and r ~= tab.IconOverlay and layer ~= "HIGHLIGHT" and layer ~= "ARTWORK" then Tint(r) end
        end
    end

    local function ColumnHeaders(display)
        if type(display) ~= "table" then return end
        if Once(display, "suiPolish") then
            Hide(display.Background); Hide(display.TopTileStreaks)
            kit.HideKeys(display, "^InsetBorder")
        end
        Each(display, function(btn, kind)
            if kind == "Button" and IsTexture(btn.Left) and IsTexture(btn.Right) and Once(btn, "suiPolish") then
                Hide(btn.Left); Hide(btn.Middle); Hide(btn.Right)
                kit.Heading(btn, nil)
            end
        end)
    end

    local function Guild()
        local win = _G.CommunitiesFrame
        if not Shown(win) then return end
        Each(win, SideTab)
        local list = win.CommunitiesList
        if type(list) == "table" and Once(list, "suiPolish") then
            Hide(list.TopFiligree); Hide(list.BottomFiligree); Hide(list.FilligreeOverlay)
        end
        local members = win.MemberList
        if type(members) == "table" then
            ColumnHeaders(members.ColumnDisplay)
            local mark = type(members.WatermarkFrame) == "table" and members.WatermarkFrame.Watermark
            if IsTexture(mark) and Once(members, "suiPolish") then mark:SetAlpha(0.18) end
        end
        if type(win.ApplicantList) == "table" then ColumnHeaders(win.ApplicantList.ColumnDisplay) end
        for _, key in ipairs({ "GuildBenefitsFrame", "GuildDetailsFrame" }) do
            local f = win[key]
            if type(f) == "table" and Once(f, "suiPolish") then kit.HideKeys(f, "^InsetBorder") end
        end
    end

    -- A card behind an item and its name: the ornate name plate goes, a quiet plate takes its place.
    local function ItemCard(item)
        if type(item) ~= "table" or not item.CreateTexture or not Once(item, "suiCard") then return end
        local fill = item:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetAllPoints()
        fill:SetTexture(ns.FLAT)
        ns:Paint(fill, "SetVertexColor", "plate", 0.38)
        fill.sui = true
        local th = ns.theme
        ns:Outline(item, 0, th.border[1], th.border[2], th.border[3], 0.45, "BACKGROUND")
    end

    -- Vendor ---------------------------------------------------------------------------------------------
    local function MerchantItem(name)
        local item = _G[name]
        if type(item) ~= "table" then return end
        local btn = item.ItemButton or _G[name .. "ItemButton"]
        if Once(item, "suiPolish") then
            Hide(item.SlotTexture or _G[name .. "SlotTexture"])
            Hide(_G[name .. "NameFrame"])
            ItemCard(item)
            if type(item.Name) == "table" and item.Name.SetFont then ns:Font(item.Name, 12) end
        end
        if type(btn) == "table" then
            kit.ItemButton(btn)
            kit.ItemQuality(btn)
        end
    end

    local function Merchant()
        local win = _G.MerchantFrame
        if not Shown(win) then return end
        for i = 1, 12 do MerchantItem("MerchantItem" .. i) end
        MerchantItem("MerchantBuyBackItem")
        if Once(win, "suiPolish") then
            Hide(_G.BuybackBG); Hide(_G.MerchantFrameBottomLeftBorder)
            kit.HideNamed("MerchantMoneyBg"); kit.HideNamed("MerchantExtraCurrencyBg")
            for _, name in ipairs({ "MerchantPrevPageButton", "MerchantNextPageButton" }) do
                local b = _G[name]
                if type(b) == "table" and b.GetRegions then
                    for _, r in ipairs({ b:GetRegions() }) do Tint(r) end
                end
            end
            if type(_G.MerchantPageText) == "table" then ns:Font(_G.MerchantPageText, 12) end
        end
    end

    -- Mailbox --------------------------------------------------------------------------------------------
    local function NamedField(name)                       -- an edit box whose art is named <box>Left / Middle / Right
        local box = _G[name]
        if type(box) ~= "table" or not Once(box, "suiPolish") then return end
        kit.HideNamed(name)
        Hide(box.left); Hide(box.right); Hide(box.texture)          -- (the money boxes attach theirs in lower case)
        kit.Control(box, "field", 0)
    end

    local function Mail()
        local win = _G.MailFrame
        if not Shown(win) then return end
        if Once(win, "suiPolish") then
            Hide(_G.InboxFrameBg)                            -- the marbled backdrop: our window shows instead
            if type(_G.InboxCurrentPage) == "table" then ns:Font(_G.InboxCurrentPage, 12) end
        end
        for i = 1, 7 do
            local row = _G["MailItem" .. i]
            if type(row) == "table" then
                if Once(row, "suiPolish") and row.GetRegions then
                    for _, r in ipairs({ row:GetRegions() }) do
                        if IsTexture(r) and r:GetDrawLayer() ~= "HIGHLIGHT" then Tint(r, "plate", 0.55) end     -- the row's stripe
                    end
                end
                local btn = row.Button or _G["MailItem" .. i .. "Button"]
                if type(btn) == "table" then
                    if Once(btn, "suiSlotDone") then Hide(_G["MailItem" .. i .. "ButtonSlot"]) end
                    kit.ItemButton(btn, btn.Icon or _G["MailItem" .. i .. "ButtonIcon"])
                    kit.ItemQuality(btn)
                end
            end
        end
        local inbox = _G.InboxFrame
        if type(inbox) == "table" then
            for _, key in ipairs({ "PrevPageButton", "NextPageButton" }) do
                local b = inbox[key]
                if type(b) == "table" and b.GetRegions and Once(b, "suiPolish") then
                    for _, r in ipairs({ b:GetRegions() }) do Tint(r) end
                end
            end
        end
        -- the Send Mail page (its stationery and the attachment slots are left alone: the letter's text
        -- is dark and needs the pale paper, and an attached item is drawn as the slot's own art)
        if Shown(_G.SendMailFrame) then
            for _, name in ipairs({ "SendMailNameEditBox", "SendMailSubjectEditBox", "SendMailMoneyGold", "SendMailMoneySilver", "SendMailMoneyCopper" }) do
                NamedField(name)
            end
            if Once(_G.SendMailFrame, "suiPolish") then
                kit.HideNamed("SendMailMoneyBg")
                Tint(_G.SendMailHorizontalBarLeft, "@border"); Tint(_G.SendMailHorizontalBarLeft2, "@border")
            end
        end
    end

    -- Quest giver's dialog ---------------------------------------------------------------------------------
    -- The game writes quest text in dark ink on parchment, and puts the ink color back every time it
    -- shows a page. So: the parchment goes, and while the dialog is open every piece of dark lettering
    -- in it is relit to our text color (lettering that is already light is left alone).
    -- (this runs ten times a second while the dialog is open, so the regions and children are walked
    -- straight off the calls' results rather than gathered into new tables)
    local Relight
    local function RelightRegions(...)
        for i = 1, select("#", ...) do
            local r = select(i, ...)
            if type(r) == "table" and r.GetObjectType and r:GetObjectType() == "FontString" then
                local cr, cg, cb = r:GetTextColor()
                if type(cr) == "number" and not ns:IsSecret(cr) and (cr * 0.30 + cg * 0.59 + cb * 0.11) < 0.42 then
                    ns:Paint(r, "SetTextColor", "text")
                end
            end
        end
    end
    local function RelightKids(depth, ...)
        for i = 1, select("#", ...) do Relight((select(i, ...)), depth) end
    end
    function Relight(frame, depth)
        if depth > 6 or type(frame) ~= "table" or (frame.IsForbidden and frame:IsForbidden()) then return end
        if frame.GetRegions then RelightRegions(frame:GetRegions()) end
        if frame.GetChildren then RelightKids(depth + 1, frame:GetChildren()) end
    end

    local PARCHMENT = { "Bg", "MaterialTopLeft", "MaterialTopRight", "MaterialBotLeft", "MaterialBotRight", "SealMaterialBG" }
    local function Unparchment(panel)
        if type(panel) ~= "table" or not Once(panel, "suiPolish") then return end
        for _, key in ipairs(PARCHMENT) do Hide(panel[key]) end
    end

    -- reward and required-item buttons: an icon with a name plate beside it
    local function RewardButton(btn, kind)
        if kind ~= "Button" or not IsTexture(btn.NameFrame) or not Once(btn, "suiPolish") then return end
        Hide(btn.NameFrame)
        ItemCard(btn)
        if IsTexture(btn.Icon) then btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end
    local function RewardButtons(holder) Each(holder, RewardButton) end

    local QUEST_PANELS = { "QuestFrameRewardPanel", "QuestFrameProgressPanel", "QuestFrameDetailPanel", "QuestFrameGreetingPanel" }
    local QUEST_HEADINGS = { "QuestInfoTitleHeader", "QuestInfoObjectivesHeader", "QuestProgressTitleText", "CurrentQuestsText", "AvailableQuestsText" }

    local function Headings()
        for _, name in ipairs(QUEST_HEADINGS) do
            local fs = _G[name]
            if type(fs) == "table" and fs.SetTextColor and fs.IsVisible and fs:IsVisible() then ns:Paint(fs, "SetTextColor", "@accent") end
        end
        local rewards = _G.QuestInfoRewardsFrame
        if type(rewards) == "table" and type(rewards.Header) == "table" and rewards.Header.SetTextColor and rewards:IsVisible() then
            ns:Paint(rewards.Header, "SetTextColor", "@accent")
        end
    end

    local function QuestDialog()
        local win = _G.QuestFrame
        if not Shown(win) then return end
        for _, name in ipairs(QUEST_PANELS) do
            local panel = _G[name]
            if type(panel) == "table" then
                Unparchment(panel)
                if Shown(panel) then Relight(panel, 0) end
            end
        end
        Headings()
        RewardButtons(_G.QuestInfoRewardsFrame)
        RewardButtons(_G.QuestProgressScrollChildFrame)
        if Once(win, "suiQuestDialog") then
            Tint(_G.QuestGreetingFrameHorizontalBreak, "@border")
            local hl = _G.QuestInfoItemHighlight                   -- the glow on the reward you have picked
            if type(hl) == "table" and hl.GetRegions then
                for _, r in ipairs({ hl:GetRegions() }) do Tint(r, "@accent") end
            end
            local title = _G.QuestInfoPlayerTitleFrame
            if type(title) == "table" then Tint(title.FrameLeft); Tint(title.FrameCenter); Tint(title.FrameRight) end
        end
    end

    -- The quest details page beside the world map shows the same text the same way: same treatment.
    local function MapDetails(details)
        if type(details) ~= "table" then return end
        if Once(details, "suiUnparchment") then Hide(details.Bg); Hide(details.SealMaterialBG) end
        if Shown(details) then
            Relight(details, 0)
            Headings()
            RewardButtons(_G.QuestInfoRewardsFrame)
        end
    end
    local function MapQuestDetails()
        local panel = _G.QuestMapFrame
        if not Shown(panel) then return end
        MapDetails(panel.DetailsFrame)
        if type(panel.QuestsFrame) == "table" then MapDetails(panel.QuestsFrame.DetailsFrame) end
    end

    -- Professions ------------------------------------------------------------------------------------------
    -- Overview page: a panel per profession with a rank bar and its ability buttons.
    -- Crafting page: recipe list, the recipe itself, gear slots and a rank bar.
    local function AbilityButton(btn)                      -- built like the spellbook's: ornate ring, round mask
        if type(btn) ~= "table" or not Once(btn, "suiPolish") then return end
        Hide(btn.IconBorder); Hide(btn.BorderShadow)
        local icon = btn.IconTexture
        if IsTexture(icon) then
            if type(btn.OutlineMask) == "table" and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, btn.OutlineMask) end
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        if btn.CreateTexture then pcall(ns.AddBorder, ns, btn, 0, 0, 0, 1, 0) end
    end

    -- item-style buttons anywhere under a page (gear and tool slots, the item a recipe makes)
    local function ItemButtonsUnder(frame, depth, budget)
        if depth > 4 or budget.n <= 0 then return end
        Each(frame, function(child, kind)
            budget.n = budget.n - 1
            if kind == "Button" and IsTexture(child.icon) and IsTexture(child.IconBorder) and (child.NormalTexture or child.GetNormalTexture) then
                kit.ItemButton(child)
                kit.ItemQuality(child)
            elseif kind ~= "ModelScene" and kind ~= "PlayerModel" then
                ItemButtonsUnder(child, depth + 1, budget)
            end
        end)
    end

    local function Professions()
        local win = _G.ProfessionsFrame
        if not Shown(win) then return end
        -- the tabs down the side (and any an add-on has added in the same style)
        Each(win, function(child)
            if IsTexture(child.SelectedTexture) and IsTexture(child.Background) then pcall(kit.IconTab, child) end
        end)

        local book = win.BookPage
        local content = type(book) == "table" and book.ProfessionsContentFrame
        if Shown(content) then
            Each(content, function(panel)
                kit.FlatBar(panel.StatusBar)
                for i = 1, 6 do AbilityButton(panel["SpellButton" .. i]) end
                if Once(panel, "suiPolish") and type(panel.ProfessionName) == "table" and panel.ProfessionName.SetFont then
                    ns:Font(panel.ProfessionName, 15, true)
                end
            end)
        end

        local craft = win.CraftingPage
        if Shown(craft) then
            kit.FlatBar(craft.RankBar)
            local list = craft.RecipeList
            if type(list) == "table" and Once(list, "suiPolish") then
                Hide(list.BackgroundNineSlice)
                Tint(list.Background, "inset", 1)             -- keep a darker bed under the list
            end
            local form = craft.SchematicForm
            local details = type(form) == "table" and form.Details
            if type(details) == "table" and Once(details, "suiPolish") then
                for _, key in ipairs({ "BackgroundTop", "BackgroundMiddle", "BackgroundBottom", "BackgroundMinimized" }) do Tint(details[key]) end
                Tint(details.Line, "@border")
            end
            ItemButtonsUnder(craft, 0, { n = 300 })
        end
    end

    -- Collections (mounts, pets, toys, heirlooms, appearances) ------------------------------------------
    -- The five tabs share a handful of pieces. Each is recognized by how it is built, wherever it sits:
    --   list row      Button { background, icon, selectedTexture }       (mounts, pets)
    --   count plate   { BorderTopLeft ... BorderBottomRight, Bg }         ("Mounts: 12", toy progress)
    --   icon grid     { BackgroundTile, BGCornerTopLeft ... }             (toys, heirlooms, appearances)
    --   toy button    CheckButton { slotFrameCollected, slotFrameUncollected }
    --   model         DressUpModel { Border }  /  a model scene's zoom and rotate buttons
    local MODELS = { ModelScene = true, DressUpModel = true, PlayerModel = true, CinematicModel = true }

    local function ModelControls(scene)
        local controls = type(scene) == "table" and scene.ControlFrame
        if type(controls) ~= "table" then return end
        Each(controls, function(btn, kind)
            if kind ~= "Button" or not Once(btn, "suiPolish") then return end
            Hide(btn.NormalTexture); Hide(btn.PushedTexture)
            kit.Plate(btn, 2, "plate", 0.8)
            Tint(btn.Icon)
            ns:ColorTex(btn.HighlightTexture, 1, 1, 1, 0.18)
        end)
    end

    local function CollectionPiece(f, kind)
        if (kind == "Button" or kind == "CheckButton") and IsTexture(f.background) and IsTexture(f.icon) then        -- a list row
            if Once(f, "suiPolish") then
                Tint(f.background, "plate", 0.6)
                Tint(f.selectedTexture, "@accent", 0.7)
                f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                if type(f.name) == "table" and f.name.SetFont then ns:Font(f.name, 12) end
            end
            return true
        elseif IsTexture(f.BorderTopLeft) and IsTexture(f.BorderBottomRight) then                                    -- a count plate
            if Once(f, "suiPolish") then
                kit.HideKeys(f, "^Border")
                if kind == "StatusBar" then
                    Tint(f.Bg, "trough", 0.9)
                    pcall(ns.AddBorder, ns, f, 0, 0, 0, 1, 0)
                else
                    Hide(f.Bg)
                    kit.Plate(f, 0, "plate", 0.6)
                end
            end
            return true
        elseif IsTexture(f.BackgroundTile) then                                                                       -- an icon grid
            if Once(f, "suiPolish") then
                kit.HideKeys(f, "^BGCorner")
                Tint(f.BackgroundTile, "inset", 1)
            end
        elseif kind == "CheckButton" and IsTexture(f.slotFrameCollected) then                                         -- a toy
            if Once(f, "suiPolish") then
                Tint(f.slotFrameCollected); Tint(f.slotFrameUncollected)
                if IsTexture(f.iconTexture) then f.iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
            end
            return true
        elseif kind == "StatusBar" and IsTexture(f.border) then                                                       -- a plain progress bar
            if Once(f, "suiPolish") then
                Hide(f.border)
                pcall(ns.AddBorder, ns, f, 0, 0, 0, 1, 0)
            end
            return true
        elseif kind == "Button" and IsTexture(f.Border) and IsTexture(f.Icon) and IsTexture(f.BlackCover) then        -- "summon random favorite"
            if Once(f, "suiPolish") then
                Hide(f.Border)
                f.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                pcall(ns.AddBorder, ns, f, 0, 0, 0, 1, 0)
            end
            return true
        end
        return false
    end

    local function CollectionWalk(frame, depth, budget)
        if depth > 5 then return end
        Each(frame, function(child, kind)
            budget.n = budget.n - 1
            if budget.n <= 0 then return end
            if child.IsShown and not child:IsShown() then return end        -- hidden tabs wait until they are opened
            if MODELS[kind] then
                if kind == "DressUpModel" and Once(child, "suiPolish") then Tint(child.Border) end
                ModelControls(child)
                return
            end
            if not CollectionPiece(child, kind) then CollectionWalk(child, depth + 1, budget) end
        end)
    end

    local function Collections()
        local win = _G.CollectionsJournal
        if not Shown(win) then return end
        Each(win.TabContainer, function(tab) pcall(kit.IconTab, tab) end)
        CollectionWalk(win, 0, { n = 700 })
    end

    -- Auction house -----------------------------------------------------------------------------------------
    -- A very large window (more so with an auction add-on living inside it), far beyond what the general
    -- window pass will walk in one go. So each panel gets the general pass to itself the first time it
    -- is shown, and these pieces, which only the auction house has, are recognized by how they are built:
    --   panel          { Background, NineSlice }                         (every list and form)
    --   column header  Button { Arrow, Left, Middle, Right }             (click to sort)
    --   list row       { NormalTexture, SelectedHighlight }              (the striped rows)
    --   category       Button { Lines, NormalTexture, SelectedTexture }  (the list down the left)
    --   item display   Button { ItemButton, Name, Background }           (the item you are buying or selling)
    --   money box      EditBox { left, right, texture }                  (bid amount)
    local function AuctionPiece(f, kind)
        if type(f.NineSlice) == "table" and IsTexture(f.Background) and not f.ItemButton then                        -- a panel
            if Once(f, "suiPolish") then
                f.NineSlice:SetAlpha(0)
                Tint(f.Background, "inset", 1)
                Hide(f.CreateAuctionTabLeft); Hide(f.CreateAuctionTabMiddle); Hide(f.CreateAuctionTabRight)
            end
        elseif kind == "Button" and IsTexture(f.Arrow) and IsTexture(f.Left) and IsTexture(f.Right) then              -- a column header
            if Once(f, "suiPolish") then
                Hide(f.Left); Hide(f.Middle); Hide(f.Right)
                kit.Heading(f, nil)
                Tint(f.Arrow)
            end
            return true
        elseif kind == "Button" and IsTexture(f.Lines) and IsTexture(f.SelectedTexture) then                          -- a category
            if Once(f, "suiPolish") then
                Tint(f.NormalTexture, "plate", 0.6); Tint(f.SelectedTexture, "@accent", 0.7); Tint(f.Lines, "@border")
            end
            return true
        elseif IsTexture(f.SelectedHighlight) and IsTexture(f.NormalTexture) then                                     -- a list row
            if Once(f, "suiPolish") then
                Tint(f.NormalTexture, "plate", 0.5); Tint(f.SelectedHighlight, "@accent", 0.7)
            end
            return true
        elseif kind == "Button" and type(f.ItemButton) == "table" and type(f.Name) == "table" then                    -- an item display
            if Once(f, "suiPolish") then
                if type(f.NineSlice) == "table" then f.NineSlice:SetAlpha(0) end
                Tint(f.Background, "plate", 0.5)
            end
            kit.ItemButton(f.ItemButton, f.ItemButton.Icon)
            kit.ItemQuality(f.ItemButton)
            return true
        elseif kind == "EditBox" and IsTexture(f.left) and IsTexture(f.right) then                                    -- a money box
            if Once(f, "suiPolish") then
                Hide(f.left); Hide(f.right); Hide(f.texture)
                kit.Control(f, "field", 0)
            end
            return true
        elseif kind == "Button" and IsTexture(f.Arrow) and IsTexture(f.Background) and not f.Left then                -- a dropdown
            if Once(f, "suiPolish") then Tint(f.Background) end
            return true
        end
        return false
    end

    local function AuctionWalk(frame, depth, budget)
        if depth > 8 then return end
        Each(frame, function(child, kind)
            budget.n = budget.n - 1
            if budget.n <= 0 or MODELS[kind] then return end
            if child.IsShown and not child:IsShown() then return end        -- hidden pages wait until they are opened
            if not AuctionPiece(child, kind) then AuctionWalk(child, depth + 1, budget) end
        end)
    end

    local function AuctionHouse()
        local win = _G.AuctionHouseFrame
        if not Shown(win) then return end
        if Once(win, "suiPolish") then kit.HideNamed("AuctionHouseFrame") end        -- the money plate at the bottom
        Each(win, function(child)                           -- the general pass, one panel at a time
            if Shown(child) and Once(child, "suiAuto") then pcall(ns.AutoSkin, ns, child) end
        end)
        AuctionWalk(win, 0, { n = 1500 })
    end

    -- Confirmation boxes (StaticPopup1-4) -----------------------------------------------------------------
    -- "Do you want to destroy ...?" and every other question the game asks in a small box. Two things
    -- about them are not built the way the general pass expects, so it left them as they were:
    --   * the frame and fill are a separate piece laid over the box (called BG, Border or NineSlice
    --     depending on the client), which covered the panel painted underneath;
    --   * the red buttons carry their art as the button's own normal / pushed / disabled pictures,
    --     not as left / middle / right strips.
    -- The warning icon, the text, the edit box and the money display are the game's and are kept.
    local POPUP_ART = { "BG", "Border", "NineSlice", "Bg", "Background", "Backdrop" }
    local function PopupButton(b)
        if type(b) ~= "table" or not b.GetObjectType or b:GetObjectType() ~= "Button" or not Once(b, "suiPolish") then return end
        for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
            local t = b[getter] and b[getter](b)
            if IsTexture(t) then ns:Kill(t) end             -- (kept invisible: the game swaps between them as the button changes state)
        end
        for _, key in ipairs({ "Left", "Middle", "Right", "Center" }) do Hide(b[key]) end
        kit.Control(b, "plate", 0)
        local hl = b.GetHighlightTexture and b:GetHighlightTexture()
        if IsTexture(hl) then ns:ColorTex(hl, ns.theme.accent[1], ns.theme.accent[2], ns.theme.accent[3], 0.2) end
    end
    local POPUP_NAMES = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }
    local BUTTON_KEYS = { "button1", "button2", "button3", "button4", "Button1", "Button2", "Button3", "Button4" }
    local function PopupChild(child, kind) if kind == "Button" then PopupButton(child) end end
    local function Popup(popup, name)
        if type(popup) ~= "table" or not popup.GetObjectType then return end
        if Once(popup, "suiPopupDone") then
            for _, key in ipairs(POPUP_ART) do
                local piece = popup[key]
                if type(piece) == "table" and piece.SetAlpha then ns:Kill(piece) end
            end
            pcall(ns.PaintPanel, ns, popup)                 -- (if the window pass has not already)
            for _, fs in ipairs({ popup.Text, popup.text, _G[name .. "Text"] }) do
                if type(fs) == "table" and fs.SetFont then ns:Font(fs, 13) end
            end
        end
        -- the buttons: wherever this client keeps them, and however many this question shows
        -- (PopupButton does its work once per button, so a button reached two ways is no trouble)
        for i = 1, 4 do
            PopupButton(popup[BUTTON_KEYS[i]]); PopupButton(popup[BUTTON_KEYS[i + 4]]); PopupButton(_G[name .. BUTTON_KEYS[i + 4]])
        end
        PopupButton(popup.extraButton); PopupButton(popup.ExtraButton); PopupButton(_G[name .. "ExtraButton"])
        local holder = popup.ButtonContainer
        if type(holder) == "table" then
            for i = 1, 4 do PopupButton(holder[BUTTON_KEYS[i + 4]]) end
            Each(holder, PopupChild)
        end
        if type(popup.Buttons) == "table" then
            for _, b in ipairs(popup.Buttons) do PopupButton(b) end
        end
    end
    -- Every half second: only a box that is on screen is looked at, so four hidden boxes cost nothing.
    -- (`all`: the one pass at the start, so a box is already in style the first time it appears.)
    local function Popups(all)
        for i = 1, 4 do
            local popup = _G[POPUP_NAMES[i]]
            if all or Shown(popup) then pcall(Popup, popup, POPUP_NAMES[i]) end
        end
    end
    ns.PolishPopups = Popups
    Popups(true)

    -- Group finder ------------------------------------------------------------------------------------------
    -- (LFGParentFrame, from its outline.) It is a shell that holds three complete windows stacked in
    -- the same place - list yourself, the who list, browse groups - with three round icon tabs down
    -- its side and an animated eye where a portrait would be. So each of the three gets the standard
    -- window treatment to itself, the shell's own art goes, and these pieces are recognized by how
    -- they are built:
    --   side tab       { Background, SelectedTexture, Icon, Mask }      (the three round tabs)
    --   dropdown       Button { Arrow, Background }                     (category, activity, role, voice chat)
    --   role           Button { Background, CheckButton, cover }        (tank / healer / damage)
    --   tick box       Button { CheckButton }, Frame { Checkbox }       (new-player friendly, level ranges)
    --   category       Button { Cover, Icon, Label }                    (the four big choices)
    --   comment box    ScrollFrame { TopLeftTex ... }                   (the note on your listing)
    --   inset          { Border, CustomBG }                             (the framed area behind the lists)
    local FINDER_PAGES = { "LFGListingFrame", "LFGWhoListFrame", "LFGBrowseFrame" }
    local COMMENT_ART = { "TopLeftTex", "TopRightTex", "BottomLeftTex", "BottomRightTex", "TopTex", "BottomTex", "LeftTex", "RightTex", "MiddleTex" }
    local function FinderPiece(f, kind)
        if IsTexture(f.SelectedTexture) and IsTexture(f.Icon) and IsTexture(f.Background) then                 -- a side tab
            kit.IconTab(f)
            return true
        elseif kind == "Button" and IsTexture(f.Arrow) and IsTexture(f.Background) and not f.Left then        -- a dropdown
            if Once(f, "suiPolish") then Tint(f.Background); Tint(f.Arrow) end
            return true
        elseif kind == "Button" and type(f.CheckButton) == "table" then                                       -- a role, or a tick box with a label
            TintBox(f.CheckButton)
            return true
        elseif kind == "Button" and IsTexture(f.Cover) and IsTexture(f.Icon) and type(f.Label) == "table" then -- a category
            if Once(f, "suiPolish") then
                pcall(ns.AddBorder, ns, f, 0, 0, 0, 1, 0)
                if f.Label.SetFont then ns:Font(f.Label, 13, true) end
            end
            return true
        elseif kind == "ScrollFrame" and IsTexture(f.TopLeftTex) then                                         -- the comment box
            if Once(f, "suiPolish") then
                for _, key in ipairs(COMMENT_ART) do Hide(f[key]) end
                kit.Control(f, "field", 0)
            end
            return false                                    -- (its scroll bar is inside: keep walking)
        elseif type(f.Checkbox) == "table" and f.Checkbox.GetRegions then                                     -- a tick box in a frame
            TintBox(f.Checkbox)
            return true
        elseif IsTexture(f.Border) and IsTexture(f.CustomBG) then                                             -- an inset
            if Once(f, "suiPolish") then Hide(f.Border); Tint(f.CustomBG, "inset", 1) end
            return true
        end
        return false
    end
    local function FinderWalk(frame, depth, budget)
        if depth > 8 then return end
        Each(frame, function(child, kind)
            budget.n = budget.n - 1
            if budget.n <= 0 or MODELS[kind] then return end
            if child.IsShown and not child:IsShown() then return end        -- hidden pages wait until they are opened
            if not FinderPiece(child, kind) then FinderWalk(child, depth + 1, budget) end
        end)
    end
    local function GroupFinder()
        local win = _G.LFGParentFrame
        if not Shown(win) then return end
        if Once(win, "suiPolish") then
            -- each of the three pages is a window in its own right
            for _, name in ipairs(FINDER_PAGES) do
                local page = _G[name]
                if type(page) == "table" then
                    pcall(ns.SkinWindow, ns, page, { "BackgroundArt", "BarTop", "BarMiddle", "insideFrame", "headerBackground", "FrameGlow" })
                    ns:StripArt(page)                       -- (the loose art drawn straight on it; ours is tagged and kept)
                end
            end
            Hide(_G.LFGListingFrameRoleBackground)
            ns:StripArt(win)                                -- the shell's own art
            Hide(_G.LFGParentFramePortrait)                 -- the eye in the portrait corner
            pcall(ns.AutoSkin, ns, win)                     -- the shell's close button and bottom tabs
        end
        FinderWalk(win, 0, { n = 900 })
    end

    -- Talent tree -------------------------------------------------------------------------------------------
    -- The shaped border on each talent is not decoration: it is how the game shows whether a talent can
    -- be taken, has been taken, is full, or is locked. So it is only replaced when we can read that
    -- state ourselves (the game keeps it on each button as visualState). Then the icon is squared, our
    -- rim goes around it, and the rim's color carries the meaning:
    --     green  - can be taken now, or partly taken        gold - full
    --     red    - a problem (would have to be refunded)     gray - locked or out of reach
    -- If the state can't be read, the talent is left exactly as the game draws it.
    local TALENT_COLORS = {
        Selectable = { 0.30, 0.92, 0.42 }, Normal = { 0.30, 0.75, 0.40 }, Maxed = { 1.00, 0.82, 0.20 },
        RefundInvalid = { 1.00, 0.28, 0.28 }, DisplayError = { 1.00, 0.28, 0.28 },
    }
    local talentStateName                                  -- number -> name, built from the game's own list
    local function TalentStates()
        if talentStateName ~= nil then return talentStateName end
        talentStateName = false
        local util = _G.TalentButtonUtil
        local states = type(util) == "table" and util.BaseVisualState
        if type(states) == "table" then
            local map, n = {}, 0
            for name, value in pairs(states) do
                if type(name) == "string" and type(value) == "number" then map[value] = name; n = n + 1 end
            end
            if n >= 4 then talentStateName = map end
        end
        return talentStateName
    end

    local function TalentNode(btn)
        local names = TalentStates()
        local state = names and type(btn.visualState) == "number" and names[btn.visualState]
        if not state then return false end                  -- unreadable: leave this talent alone
        if Once(btn, "suiTalent") then
            local icon = btn.Icon
            if type(btn.IconMask) == "table" and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, btn.IconMask) end
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local dim = btn.DisabledOverlay                  -- the gray wash on talents you can't take: squared to match
            if IsTexture(dim) and type(btn.DisabledOverlayMask) == "table" and dim.RemoveMaskTexture then
                pcall(dim.RemoveMaskTexture, dim, btn.DisabledOverlayMask)
            end
            Hide(btn.StateBorder); Hide(btn.StateBorderHover); Hide(btn.Shadow); Hide(btn.BorderSheen)
            local holder = CreateFrame("Frame", nil, btn)     -- our rim sits exactly around the icon
            holder:SetAllPoints(icon)
            ns:AddBorder(holder, 0, 0, 0, 1, 0)
            btn.suiRim = holder.suiBorder
        end
        local safe = ns.db.colorblind and true or false       -- the color-blind option changes green and red
        if (btn.suiState ~= state or btn.suiSafe ~= safe) and btn.suiRim then
            btn.suiState, btn.suiSafe = state, safe
            local c = TALENT_COLORS[state]
            if state == "Selectable" or state == "Normal" then
                local r, g, b = ns:Signal("good")
                local k = (state == "Normal") and 0.82 or 1
                btn.suiRim:SetBackdropBorderColor(r * k, g * k, b * k, 1)
            elseif state == "RefundInvalid" or state == "DisplayError" then
                btn.suiRim:SetBackdropBorderColor(ns:Signal("bad"))
            elseif c then
                btn.suiRim:SetBackdropBorderColor(c[1], c[2], c[3], 1)
            else
                ns:Paint(btn.suiRim, "SetBackdropBorderColor", "@border", 1)
            end
        end
        return true
    end

    local function Talents()
        local host = _G.PlayerSpellsFrame
        local tree = type(host) == "table" and host.TalentsFrame
        if not Shown(tree) then return end
        if Once(tree, "suiPolish") then                      -- the trim around the tree
            for _, key in ipairs({ "DividerHorizontalLeft", "DividerHorizontalRight", "DividerVerticalLeft", "DividerVerticalRight" }) do
                Tint(tree[key], "@border")
            end
            Tint(tree.BackgroundBorder)
            local points = tree.ClassCurrencyDisplay
            if type(points) == "table" then Tint(points.Border) end
        end
        local restyled, kept = 0, 0
        Each(tree, function(child)
            if IsTexture(child.MainRing) and type(child.Name) == "table" then        -- one of the three tree headings
                if Once(child, "suiPolish") then
                    Tint(child.MainRing); Tint(child.Divider, "@border"); Tint(child.TextBackground, "plate", 0.7)
                    if child.Name.SetFont then ns:Font(child.Name, 14, true) end
                end
            else
                Each(child, function(btn, kind)                                       -- the talents themselves
                    if kind == "Button" and IsTexture(btn.StateBorder) and IsTexture(btn.Icon) then
                        if TalentNode(btn) then restyled = restyled + 1 else kept = kept + 1 end
                    end
                end)
            end
        end)
        if restyled + kept > 0 then
            ns.talentState = (kept == 0) and "restyled, rim colors show each talent's state"
                or (restyled == 0) and "left as the game draws them (their state could not be read)"
                or format("%d restyled, %d left as the game draws them", restyled, kept)
        end
    end
    ns:Every(0.3, "Talent tree", function() pcall(Talents) end)

    -- Class trainer -----------------------------------------------------------------------------------------
    -- A list of things to learn (icon, name, rank, cost), a detail row for the one selected, a Train
    -- button and your money. Rows keep their icon, lock, selection and "can't learn" wash; the ornate
    -- row plate is drained of color and the selection takes the accent.
    local function TrainerRow(row)
        if type(row) ~= "table" or not Once(row, "suiPolish") then return end
        local keep = { [row.icon or 0] = true, [row.selectedTex or 0] = true, [row.disabledBG or 0] = true, [row.lock or 0] = true }
        for _, region in ipairs({ row:GetRegions() }) do
            if IsTexture(region) and not keep[region] and region:GetDrawLayer() ~= "HIGHLIGHT" then Tint(region, "plate", 0.6) end
        end
        Tint(row.selectedTex, "@accent", 0.7)
        if IsTexture(row.icon) then row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        if type(row.name) == "table" and row.name.SetFont then ns:Font(row.name, 12) end
    end

    local function Trainer()
        local win = _G.ClassTrainerFrame
        if not Shown(win) then return end
        if Once(win, "suiPolish") then
            Hide(_G.ClassTrainerFrameMoneyBg)                -- the plate behind your money
            Tint(win.BG, "inset", 1)
            local bar = _G.ClassTrainerStatusBar             -- profession trainers: your skill rank
            if type(bar) == "table" then
                kit.HideNamed("ClassTrainerStatusBar")
                Tint(_G.ClassTrainerStatusBarBackground, "trough", 0.9)
                if bar.CreateTexture then pcall(ns.AddBorder, ns, bar, 0, 0, 0, 1, 0) end
            end
        end
        TrainerRow(win.skillStepButton)
        local box = win.ScrollBox
        local target = type(box) == "table" and box.ScrollTarget
        if type(target) == "table" then
            Each(target, function(row, kind)
                if kind == "Button" and IsTexture(row.icon) and type(row.name) == "table" then TrainerRow(row) end
            end)
        end
    end

    ns:Every(0.5, "Window polish", function()
        pcall(Trainer)
        pcall(QuestPanel)
        pcall(Guild)
        pcall(Merchant)
        pcall(Mail)
        pcall(Professions)
        pcall(Collections)
        pcall(AuctionHouse)
        pcall(GroupFinder)
        pcall(Popups)
    end)
    -- quest text is re-inked by the game whenever a page appears, so these two look more often
    ns:Every(0.1, "Quest text", function()
        pcall(QuestDialog)
        pcall(MapQuestDetails)
    end)
end)
