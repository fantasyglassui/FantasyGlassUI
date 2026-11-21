local _, ns = ...

------------------------------------------------------------------------------------------
-- Layout gallery (11.0): whole screen setups, each drawn as a small picture of the screen, and put in
-- place with one click. A setup places the frames, the raid frames, the cast bar and the role display,
-- and may set when the action bars show and how strong the info bar's background is. One undo step
-- (/fgui undo) takes it back. /fgui gallery, or the Layout tab.
------------------------------------------------------------------------------------------
ns.GALLERY = {
    { key = "classic", name = "Classic", text = "Frames either side of the middle, raid frames at the top left. How the add-on comes.",
      pos = { ufPlayer = { "CENTER", -250, -180 }, ufTarget = { "CENTER", 250, -180 }, ufToT = { "CENTER", 440, -168 }, ufFocus = { "CENTER", -430, -60 },
              ufPet = { "CENTER", -200, -230 }, roleHUD = { "CENTER", 0, -170 }, raid = { "TOPLEFT", 20, -160 }, playerCast = { "CENTER", 0, -260 },
              ufParty1 = { "LEFT", 30, 140 }, ufParty2 = { "LEFT", 30, 84 }, ufParty3 = { "LEFT", 30, 28 }, ufParty4 = { "LEFT", 30, -28 } } },
    { key = "healer", name = "Healer raid", text = "Raid and party frames under the middle of the screen, where your eyes are; your own frames low and to the sides.",
      pos = { ufPlayer = { "CENTER", -340, -250 }, ufTarget = { "CENTER", 340, -250 }, ufToT = { "CENTER", 500, -238 }, ufFocus = { "CENTER", -500, -150 },
              ufPet = { "CENTER", -340, -300 }, roleHUD = { "CENTER", 0, -330 }, raid = { "CENTER", 0, -190 }, playerCast = { "CENTER", 0, -110 },
              ufParty1 = { "CENTER", -440, 60 }, ufParty2 = { "CENTER", -440, 4 }, ufParty3 = { "CENTER", -440, -52 }, ufParty4 = { "CENTER", -440, -108 } } },
    { key = "tank", name = "Tank", text = "Your frame and your target's close to the middle, threat display just above them; party to the left.",
      pos = { ufPlayer = { "CENTER", -200, -150 }, ufTarget = { "CENTER", 200, -150 }, ufToT = { "CENTER", 370, -138 }, ufFocus = { "CENTER", 0, 120 },
              ufPet = { "CENTER", -200, -200 }, roleHUD = { "CENTER", 0, -95 }, raid = { "TOPLEFT", 20, -160 }, playerCast = { "CENTER", 0, -220 },
              ufParty1 = { "LEFT", 40, 120 }, ufParty2 = { "LEFT", 40, 64 }, ufParty3 = { "LEFT", 40, 8 }, ufParty4 = { "LEFT", 40, -48 } } },
    { key = "wide", name = "Wide screen", text = "For wide monitors: everything pulled in towards the middle, so you do not look to the edges.",
      pos = { ufPlayer = { "CENTER", -290, -200 }, ufTarget = { "CENTER", 290, -200 }, ufToT = { "CENTER", 470, -188 }, ufFocus = { "CENTER", -470, -90 },
              ufPet = { "CENTER", -290, -250 }, roleHUD = { "CENTER", 0, -190 }, raid = { "CENTER", -560, 60 }, playerCast = { "CENTER", 0, -280 },
              ufParty1 = { "CENTER", -560, 120 }, ufParty2 = { "CENTER", -560, 64 }, ufParty3 = { "CENTER", -560, 8 }, ufParty4 = { "CENTER", -560, -48 } } },
    { key = "minimal", name = "Minimal", text = "A quiet screen: frames low, action bars only in combat, no background behind the info bar.",
      pos = { ufPlayer = { "BOTTOM", -230, 150 }, ufTarget = { "BOTTOM", 230, 150 }, ufToT = { "BOTTOM", 410, 162 }, ufFocus = { "BOTTOM", -430, 230 },
              ufPet = { "BOTTOM", -230, 110 }, roleHUD = { "CENTER", 0, -170 }, raid = { "TOPLEFT", 20, -160 }, playerCast = { "BOTTOM", 0, 200 },
              ufParty1 = { "LEFT", 30, 140 }, ufParty2 = { "LEFT", 30, 84 }, ufParty3 = { "LEFT", 30, 28 }, ufParty4 = { "LEFT", 30, -28 } },
      bars = "combat", db = { infobarBg = 0 } },
    { key = "streamer", name = "Streamer", text = "The middle and bottom of the screen kept clear for a camera or overlay: frames up and to the sides, bars when pointed at.",
      pos = { ufPlayer = { "LEFT", 40, 60 }, ufTarget = { "RIGHT", -40, 60 }, ufToT = { "RIGHT", -40, 16 }, ufFocus = { "LEFT", 40, 140 },
              ufPet = { "LEFT", 40, 16 }, roleHUD = { "TOP", 0, -120 }, raid = { "TOPLEFT", 20, -200 }, playerCast = { "TOP", 0, -160 },
              ufParty1 = { "LEFT", 40, -60 }, ufParty2 = { "LEFT", 40, -116 }, ufParty3 = { "LEFT", 40, -172 }, ufParty4 = { "LEFT", 40, -228 } },
      bars = "hover" },
}

-- Where a frame of size w x h sits on a screen W x H when placed at `point` with offsets x, y:
-- its left and top, measured from the screen's top left (top grows downward).
function ns.GalleryRect(point, x, y, w, h, W, H)
    point = point or "CENTER"
    local ax = point:find("LEFT") and 0 or point:find("RIGHT") and W or W / 2
    local ay = point:find("TOP") and 0 or point:find("BOTTOM") and H or H / 2
    local px = ax + x                                       -- the frame's own anchor point on screen
    local py = ay - y
    local left = point:find("LEFT") and px or point:find("RIGHT") and (px - w) or (px - w / 2)
    local top = point:find("TOP") and py or point:find("BOTTOM") and (py - h) or (py - h / 2)
    return left, top
end

local function Movable(key)
    for _, m in ipairs(ns.movables or {}) do if m.key == key then return m end end
end
-- The size a panel has on screen now (with its scale), or a guess when it is not made.
local GUESS = { raid = { 300, 220 }, playerCast = { 260, 22 }, roleHUD = { 200, 40 } }
local function SizeOf(key)
    local m = Movable(key)
    if m and m.frame then
        local ok, w, h = pcall(m.frame.GetSize, m.frame)
        local okS, s = pcall(m.frame.GetScale, m.frame)
        if ok and type(w) == "number" and type(h) == "number" and not ns:IsSecret(w) and w > 0 then
            s = (okS and type(s) == "number") and s or 1
            return w * s, h * s
        end
    end
    local g = GUESS[key] or (key:find("^ufParty") and { 160, 32 }) or { 220, 44 }
    return g[1], g[2]
end

function ns:ApplyGallery(key)
    local def
    for _, g in ipairs(ns.GALLERY) do if g.key == key then def = g end end
    if not def then return false end
    if ns.AfterFight and ns:AfterFight("Layout gallery", function() ns:ApplyGallery(key) end) then return true end   -- (panels cannot move in a fight)
    local combat = InCombatLockdown()
    local keys = {}
    for k in pairs(def.pos) do keys[#keys + 1] = k end
    table.sort(keys)
    if ns.PushUndo then ns:PushUndo(keys, nil, def.name) end
    for k, p in pairs(def.pos) do
        ns.db.pos[k] = { p[1], p[1], p[2], p[3] }
        local m = Movable(k)
        if m and not combat then
            m.frame:ClearAllPoints()
            m.frame:SetPoint(p[1], UIParent, p[1], p[2], p[3])
        end
    end
    if def.bars then
        if type(ns.db.bars) ~= "table" then ns.db.bars = {} end
        for _, info in ipairs(ns.barHandles or {}) do
            if ns.SetBarSetting then ns:SetBarSetting(info.key, "show", def.bars) end
        end
    else
        for _, info in ipairs(ns.barHandles or {}) do
            if ns.SetBarSetting and ns.BarSetting and ns:BarSetting(info.key, "show") ~= "always" then ns:SetBarSetting(info.key, "show", "always") end
        end
    end
    for k, v in pairs(def.db or {}) do ns.db[k] = v end
    if def.db and def.db.infobarBg ~= nil and ns.SetInfoBarBackground then ns:SetInfoBarBackground(ns.db.infobarBg) end
    ns.lastGallery = key
    ns:Print(combat and "%s saved; it takes its place after the fight (or a /reload)." or "%s in place. /fgui move to fine-tune, /fgui undo to go back.", ns:Tr(def.name))
    return true
end

-- The gallery window: a card for each setup, with a picture of where everything goes.
local win
function ns:ShowGallery()
    if win then win:SetShown(not win:IsShown()); return win end
    local CW, CH, PW, PH = 236, 196, 216, 122
    win = CreateFrame("Frame", "FantasyGlassUIGallery", UIParent, ns.template)
    win:SetSize(CW * 3 + 40, CH * 2 + 70)
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
    ns:KeepPlace(win, "Gallery")
    tinsert(UISpecialFrames, "FantasyGlassUIGallery")
    local title = win:CreateFontString(nil, "OVERLAY")
    ns:Font(title, 16, true)
    title:SetPoint("TOPLEFT", 16, -12)
    title:SetText(ns:Tr("Layout gallery"))
    ns:Paint(title, "SetTextColor", "@accent")
    local close = ns:CreateButton(win, "X", 22, 20, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -8, -8)
    win.cards = {}
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    if type(W) ~= "number" or W <= 0 then W, H = 1920, 1080 end
    for i, def in ipairs(ns.GALLERY) do
        local card = CreateFrame("Frame", nil, win, ns.template)
        card:SetSize(CW - 8, CH - 8)
        card:SetPoint("TOPLEFT", 16 + ((i - 1) % 3) * CW, -44 - math.floor((i - 1) / 3) * CH)
        card:SetBackdrop(ns.BACKDROP)
        ns:Paint(card, "SetBackdropColor", "bg", 0.6)
        ns:Paint(card, "SetBackdropBorderColor", "@border", 1)
        -- the picture: the screen, and a box for each panel where this setup puts it
        local screen = CreateFrame("Frame", nil, card)
        screen:SetSize(PW, PH)
        screen:SetPoint("TOP", 0, -8)
        local sbg = screen:CreateTexture(nil, "BACKGROUND")
        sbg:SetAllPoints()
        sbg:SetTexture(ns.FLAT)
        sbg:SetVertexColor(0.04, 0.05, 0.08, 0.9)
        local fx, fy = PW / W, PH / H
        card.boxes = 0
        for k, p in pairs(def.pos) do
            local w, h = SizeOf(k)
            local left, top = ns.GalleryRect(p[1], p[2], p[3], w, h, W, H)
            local b = screen:CreateTexture(nil, "ARTWORK")
            b:SetTexture(ns.FLAT)
            b:SetPoint("TOPLEFT", screen, "TOPLEFT", math.max(0, math.min(PW - 2, left * fx)), -math.max(0, math.min(PH - 2, top * fy)))
            b:SetSize(math.max(2, w * fx), math.max(2, h * fy))
            if k == "ufPlayer" or k == "ufTarget" then ns:Paint(b, "SetVertexColor", "@accent", 0.9)
            elseif k == "raid" or k:find("^ufParty") then b:SetVertexColor(0.35, 0.75, 0.45, 0.8)
            else b:SetVertexColor(0.7, 0.72, 0.78, 0.6) end
            card.boxes = card.boxes + 1
        end
        local name = card:CreateFontString(nil, "OVERLAY")
        ns:Font(name, 13, true)
        name:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 0, -6)
        name:SetWidth(PW - 66)                              -- (stops short of the Use button)
        name:SetJustifyH("LEFT")
        if name.SetWordWrap then name:SetWordWrap(false) end
        name:SetText(ns:Tr(def.name))
        local text = ns:NewText(card, 10, "LEFT")
        text:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
        text:SetWidth(PW)
        text:SetWordWrap(true)
        text:SetText(ns:Tr(def.text))
        ns:Paint(text, "SetTextColor", "dim")
        local use = ns:CreateButton(card, "Use", 60, 20, function() ns:ApplyGallery(def.key) end)
        use:SetPoint("TOPRIGHT", screen, "BOTTOMRIGHT", 0, -4)
        ns:ButtonTip(use, "Move your panels to this layout. /fgui undo puts them back.")
        win.cards[i] = card
    end
    local note = ns:NewText(win, 10, "LEFT")
    note:SetPoint("BOTTOMLEFT", 16, 10)
    note:SetText(ns:Tr("Accent color: your frames. Green: party and raid. Gray: the rest. /fgui undo takes a setup back."))
    ns:Paint(note, "SetTextColor", "faint")
    win:Show()
    return win
end

------------------------------------------------------------------------------------------
-- Coming from another UI (11.7): the gallery setup that is closest to how another interface
-- add-on lays out the screen, so its players feel at home at once. Shown in the setup's layout
-- step; any of these add-ons found in your add-on list is named there.
------------------------------------------------------------------------------------------
ns.OTHER_UIS = {
    { key = "elv", label = "ElvUI, Tukui or NDui", gallery = "minimal", addons = { "ElvUI", "Tukui", "NDui", "LUI", "KkthnxUI" } },
    { key = "real", label = "RealUI", gallery = "tank", addons = { "nibRealUI", "RealUI" } },
    { key = "gw2", label = "GW2 UI", gallery = "wide", addons = { "GW2_UI" } },
    { key = "blizzard", label = "The game's own", gallery = "classic", addons = { "ShadowedUnitFrames", "PitBull4", "ZPerl", "XPerl", "SpartanUI", "Bartender4", "Dominos" } },
}
-- Which of them are in your add-on list (enabled or not). isThere(name) -> true when installed.
function ns.OtherUIsFound(isThere)
    if not isThere then
        local info = C_AddOns.GetAddOnInfo
        isThere = function(name)
            if type(info) ~= "function" then return false end
            local ok, _, title, _, _, reason = pcall(info, name)
            return ok and type(title) == "string" and reason ~= "MISSING"
        end
    end
    local found = {}
    for _, ui in ipairs(ns.OTHER_UIS) do
        for _, a in ipairs(ui.addons) do if isThere(a) then found[#found + 1] = { ui = ui, addon = a }; break end end
    end
    return found
end
