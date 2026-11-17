local _, ns = ...

-- Spellbook in our style: the parchment pages are removed, the book sits on one of our panels,
-- spell icons get our rims and the lettering is recolored so it reads on the dark background.
-- Handles both the classic two-page book (SpellBookFrame) and the modern one inside
-- PlayerSpellsFrame. The game rewrites text colors whenever a page turns, so while the book is
-- open the lettering is re-applied a few times a second.
ns:NewModule("spellbook", function()
    local th = ns.theme
    local LAYERS = { BACKGROUND = true, BORDER = true, ARTWORK = true }

    local function Color(fs, role)
        if type(fs) == "table" and fs.SetTextColor then fs:SetTextColor(ns:T(role)) end
    end
    local function Icon(btn, tex)
        if type(btn) ~= "table" or btn.suiSpell then return end
        btn.suiSpell = true
        if type(tex) == "table" and tex.SetTexCoord then tex:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        pcall(ns.AddBorder, ns, btn, 0, 0, 0, 1)
    end
    local function Hide(o) if type(o) == "table" and o.SetAlpha then o:SetAlpha(0) end end

    -- Classic book ---------------------------------------------------------------------------------
    local function Classic()
        local book = _G.SpellBookFrame
        if type(book) ~= "table" or not book.IsShown or not book:IsShown() then return end
        if not book.suiBook then
            book.suiBook = true
            ns:StripArt(book, LAYERS)                 -- the parchment and the ornate frame pieces
            ns:SkinWindow(book)
            ns:PaintPanel(book)
            for i = 1, 8 do                            -- school tabs down the side
                local tab = _G["SpellBookSkillLineTab" .. i]
                if type(tab) == "table" then
                    ns:StripArt(tab, { BACKGROUND = true })
                    local icon = tab.GetNormalTexture and tab:GetNormalTexture()
                    if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                    pcall(ns.AddBorder, ns, tab, 0, 0, 0, 1)
                end
            end
        end
        for i = 1, 12 do
            local name = "SpellButton" .. i
            local btn = _G[name]
            if type(btn) == "table" then
                Icon(btn, _G[name .. "IconTexture"])
                Hide(_G[name .. "SlotFrame"]); Hide(_G[name .. "Background"]); Hide(btn.SlotFrame); Hide(btn.EmptySlot)
                Color(_G[name .. "SubSpellName"] or btn.SpellSubName, "dim")
                Color(btn.RequiredLevelString, "faint")
            end
        end
        Color(_G.SpellBookPageText, "text")
    end

    -- Modern book -----------------------------------------------------------------------------------
    local function Modern()
        local host = _G.PlayerSpellsFrame
        local book = type(host) == "table" and host.SpellBookFrame
        if type(book) ~= "table" or not book.IsVisible or not book:IsVisible() then return end
        if not book.suiBook then
            book.suiBook = true
            for _, k in ipairs({ "BookBGLeft", "BookBGRight", "BookBGHalved", "BookCornerFlipbook", "Bookmark", "TopBar", "Background", "Bg" }) do
                Hide(book[k])
            end
            ns:StripArt(book, LAYERS)
            ns:SkinWindow(host)
            pcall(ns.AutoSkin, ns, book)
        end
        local paged = book.PagedSpellsFrame
        if type(paged) == "table" and paged.EnumerateFrames then
            local n = 0
            for _, item in paged:EnumerateFrames() do
                n = n + 1
                if n > 400 then break end                       -- never loop forever on an unexpected iterator
                if type(item) == "table" then
                    Color(item.Name, "text"); Color(item.SubName, "dim"); Color(item.RequiredLevel, "faint")
                    Color(item.Text, "text")                     -- section headers
                    local btn = item.Button
                    if type(btn) == "table" then
                        if not btn.suiSpell then
                            -- the ornate rim is two nine-slice child frames plus Border / shadow / sheen,
                            -- and the icon is cut round by a mask
                            ns.kit.HideNineSliceChildren(btn)
                            if type(btn.IconMask) == "table" and type(btn.Icon) == "table" and btn.Icon.RemoveMaskTexture then
                                pcall(btn.Icon.RemoveMaskTexture, btn.Icon, btn.IconMask)
                            end
                        end
                        Icon(btn, btn.Icon)
                        Hide(btn.Border); Hide(btn.BorderShadow); Hide(btn.BorderSheen); Hide(item.Backplate)
                    elseif type(item.Text) == "table" and type(item.Border) == "table" then      -- a section heading
                        Hide(item.Border); Hide(item.Backplate)
                        if not item.suiSection then
                            -- The heading's frame is much taller than its words, which the game pins to the
                            -- top-left corner: a panel round it all leaves them squeezed in that corner. So
                            -- the words get room from the edge, and only a thin accent line runs under them.
                            item.suiSection = true
                            ns:Font(item.Text, 14, true)
                            item.Text:ClearAllPoints()
                            item.Text:SetPoint("BOTTOMLEFT", item, "BOTTOMLEFT", 8, 8)
                            local line = item:CreateTexture(nil, "BORDER")
                            line:SetHeight(1)
                            line:SetPoint("TOPLEFT", item.Text, "BOTTOMLEFT", -2, -3)
                            line:SetPoint("RIGHT", item, "RIGHT", -8, 0)
                            line:SetTexture(ns.FLAT)
                            line.sui = true
                            if line.SetGradient and CreateColor then
                                local a = ns.theme.accent
                                line:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], 0.9), CreateColor(a[1], a[2], a[3], 0))
                            else
                                ns:Paint(line, "SetVertexColor", "@accent", 0.6)
                            end
                        end
                    end
                end
            end
        end
    end

    local acc = 0
    local poll = CreateFrame("Frame")
    poll:SetScript("OnUpdate", ns:Guard("Spellbook", function(_, e)
        acc = acc + e
        if acc < 0.25 then return end
        acc = 0
        pcall(Classic)
        pcall(Modern)
    end))
end)
