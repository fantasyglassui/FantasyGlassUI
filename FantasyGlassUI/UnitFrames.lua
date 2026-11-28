local _, ns = ...
-- "Offline" and "Dead" on a frame: the game's own word in its language, or ours.
function ns.OfflineWord() return (type(_G.PLAYER_OFFLINE) == "string" and _G.PLAYER_OFFLINE ~= "") and _G.PLAYER_OFFLINE or ns:Tr("Offline") end
function ns.DeadWord() return (type(_G.DEAD) == "string" and _G.DEAD ~= "") and _G.DEAD or ns:Tr("Dead") end

-- Fantasy Glass UI unit frames: player, target, target-of-target, focus, pet, party.
-- Written for the modern engine: frames are secure (click to target, right-click menu),
-- and health / power / cast values are handed straight to the bars, because the client
-- may hide ("secret") those numbers from addons during combat.

local frames = {}
local Secret = function(v) return ns:IsSecret(v) end

-- A debuff's frame color: the game's color for what can remove it (magic, curse, poison, disease),
-- red for the rest and whenever the game keeps the kind to itself.
function ns:DebuffColor(kind)
    local okT, info = pcall(AuraUtil.GetDebuffDisplayInfoTable)
    local d = (not Secret(kind)) and type(kind) == "string" and okT and type(info) == "table" and info[kind]
    local c = type(d) == "table" and d.color
    if kind ~= "None" and type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b, 1 end
    return 0.85, 0.18, 0.18, 1
end

------------------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------------------
local function SetPct(fs, unit)
    local hp, max = UnitHealth(unit), UnitHealthMax(unit)
    if not Secret(hp) and not Secret(max) then
        if hp and max and max > 0 then fs:SetText(floor(hp / max * 100) .. "%") else fs:SetText("") end
        return
    end
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        if pcall(function() fs:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)) end) then return end
    end
    fs:SetText("")
end

-- 950 -> "950", 12400 -> "12.4k", 1250000 -> "1.25m"
local function Short(n)
    if n >= 1000000 then return format("%.2fm", n / 1000000) end
    if n >= 10000 then return format("%.1fk", n / 1000) end
    return format("%d", n)
end
ns.ShortNumber = Short

-- The health text on a frame: a percentage (as it has always been) or the amount itself, by the
-- "Health as numbers" option. In combat this client hides the amount from add-ons, but the game will
-- still write a hidden number into a label when asked the right way; each way is tried in turn, and
-- if none is allowed the percentage is shown, so the label is never left empty.
local function SetHealthText(fs, unit)
    if not ns.db.healthNumbers then return SetPct(fs, unit) end
    local hp = UnitHealth(unit)
    if not Secret(hp) then
        if type(hp) == "number" then fs:SetText(Short(hp)) else fs:SetText("") end
        return "number"
    end
    if AbbreviateNumbers and pcall(function() fs:SetText(AbbreviateNumbers(hp)) end) then return "hidden, shortened by the game" end
    if pcall(function() fs:SetFormattedText("%d", hp) end) then return "hidden, written in full" end
    SetPct(fs, unit)
    return "percentage instead (the game would not write the hidden amount)"
end

local function UnitColor(unit)
    local r, g, b = ns:ClassColor(unit)
    if r then return r, g, b end
    local ok, rr, gg, bb = pcall(function()
        if UnitIsTapDenied and ns.Yes(UnitIsTapDenied(unit)) then return 0.55, 0.55, 0.55 end
        local reaction = UnitReaction(unit, "player")
        if Secret(reaction) or reaction == nil then return 0.35, 0.75, 0.35 end
        if reaction >= 5 then return 0.30, 0.80, 0.35 end
        if reaction == 4 then return 0.95, 0.80, 0.25 end
        return 0.90, 0.30, 0.25
    end)
    if ok and rr then return rr, gg, bb end
    return 0.35, 0.75, 0.35
end

local function NewBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(ns.BAR or ns.FLAT)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetTexture(ns.FLAT)
    ns:Paint(bar.bg, "SetVertexColor", "trough", 0.95)
    -- glassy sheen: light at the top, shaded at the bottom
    local sheen = bar:CreateTexture(nil, "ARTWORK", nil, 2)
    sheen:SetAllPoints()
    sheen:SetTexture(ns.FLAT)
    if sheen.SetGradient and CreateColor then
        sheen:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.28), CreateColor(1, 1, 1, 0.14))
    else
        sheen:SetVertexColor(1, 1, 1, 0.05)
    end
    bar.sheen = sheen                                         -- (Starcut cuts it to the bar's shape too)
    return bar
end

local function Text(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, size)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

------------------------------------------------------------------------------------------
-- Starcut (11.12): the frame style that leaves the plain box behind. Bars are cut to points at both
-- ends and glow in their own color, with no panel around them; the portrait is a diamond with a
-- soft halo, and on the player and target small stars sit on its points, a fine line runs from it
-- past the end of the bars to a star, and the name sits above the bars. The raid mark takes the
-- diamond's top point, the leader's crown its bottom point, and combat or resting its outer point.
--
-- Only the look changes: the same bars, texts and updates are used, so hidden combat values work
-- exactly as before. Every shape is a mask on the game's own textures. "Classic" (ns.db.ufStyle) is
-- the box the frames had before; the two can be swapped at any time out of a fight.
------------------------------------------------------------------------------------------
local SC = ns.MEDIA .. "starcut\\"
-- (the bar shape itself is shared with the other bars of the add-on: Skin.lua)
local ScMask, ScMasked, ScBar, ScGlowFit, ScTint = ns.StarcutMask, ns.StarcutMasked, ns.StarcutBar, ns.StarcutGlowFit, ns.StarcutTint

local function ScTex(host, layer, sub, file, role, alpha)
    local t = host:CreateTexture(nil, layer, nil, sub)
    t:SetTexture(file)
    if role then ns:Paint(t, "SetVertexColor", role, alpha or 1) end
    return t
end

-- The diamond portrait and, on the player and target, its stars, the line and the end star.
local function ScParts(f)
    if f.scParts then return f.scParts end
    local s = {}
    local p = f.portrait
    if p then
        s.halo = ScTex(p, "BACKGROUND", -8, SC .. "halo", "@accent", 0.30)
        s.fill = ScTex(p, "BACKGROUND", -7, SC .. "diamond", "bg", 0.95)
        s.ring = ScTex(p, "OVERLAY", 5, SC .. "ring", "@rim", 1)
        s.ring:SetAllPoints(p)
        s.fill:SetAllPoints(p)
        s.mask = ScMask(p, "diamond", p, -2)
    end
    if f.opt.stars then
        s.line = ScTex(f, "BACKGROUND", -8, ns.FLAT, "@border", 0.55)
        s.line:SetHeight(1)
        s.endStar = ScTex(f, "ARTWORK", 0, SC .. "star", "@accent", 1)
        s.endStar:SetSize(16, 16)
        local layer = f.textLayer
        s.top = ScTex(layer, "OVERLAY", 1, SC .. "star", "@rim", 1)
        s.bottom = ScTex(layer, "OVERLAY", 1, SC .. "star", "@rim", 1)
        s.outer = ScTex(layer, "OVERLAY", 1, SC .. "star", "@rim", 1)
        for _, t in ipairs({ s.top, s.bottom, s.outer }) do t:SetSize(11, 11) end
        if f.opt.status then                                  -- combat swords or resting, on the outer point
            s.state = layer:CreateTexture(nil, "OVERLAY", nil, 2)
            s.state:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
            s.state:SetSize(20, 20)
            s.state:Hide()
        end
    end
    f.scParts = s
    return s
end
local function ScShow(s, on)
    for _, k in ipairs({ "halo", "fill", "ring", "line", "endStar", "top", "bottom", "outer" }) do
        if s[k] then s[k]:SetShown(on) end
    end
    if s.state and not on then s.state:Hide() end
end

-- The class emblem stands in for the portrait: under Starcut it fills the whole diamond and is cut to
-- it, in Classic it fills the box. Called whenever the emblem shows and whenever the frame is laid out.
-- The medallion is a plain frame of our own, so this is the same in a fight as out of one.
local function EmblemFill(f)
    local p = f.portrait
    local m = p and p.emblem
    if not m then return end
    if ns.StarcutOn() and p.scSize then m:FillShape(p, "diamond", p.scSize) else m:FillShape(nil, nil, nil, 1) end
end
-- (made before it is needed, at layout, so it is already the right size and shape when it first shows)
local function EmblemMake(f)
    local p = f.portrait
    if p and not p.emblem then p.emblem = ns:CreateEmblem(p, 1); p.emblem:Hide() end
    EmblemFill(f)
    return p and p.emblem
end

-- the diamond is S across; the line and stars hang off it; `mirror` puts it on the right
local function ScPortrait(f, S, mirror)
    local p, s = f.portrait, ScParts(f)
    if not p then return end
    p:ClearAllPoints()
    p:SetSize(S, S)
    p.scSize = S
    if mirror then p:SetPoint("CENTER", f, "RIGHT", S / 2 + 6, 0) else p:SetPoint("CENTER", f, "LEFT", -(S / 2 + 6), 0) end
    if p.bg then p.bg:Hide() end
    if p.sep then p.sep:Hide() end
    s.halo:ClearAllPoints()
    s.halo:SetPoint("CENTER", p, "CENTER", 0, 0)
    s.halo:SetSize(S * 1.35, S * 1.35)
    -- the picture fills the diamond; the 3D model, which can't be cut to shape, sits in the square inside it
    p.tex:ClearAllPoints()
    p.tex:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -2); p.tex:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -2, 2)
    ScMasked(p.tex, s.mask, true)
    p.model:ClearAllPoints()
    p.model:SetPoint("TOPLEFT", p, "TOPLEFT", S / 4 + 1, -(S / 4 + 1)); p.model:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -(S / 4 + 1), S / 4 + 1)
    if (ns.db.ufPortrait or "3D") == "CLASS" then EmblemMake(f) else EmblemFill(f) end   -- the emblem fills the whole diamond
    if s.top then
        local side = mirror and "RIGHT" or "LEFT"
        s.top:ClearAllPoints(); s.top:SetPoint("CENTER", p, "TOP", 0, 2)
        s.bottom:ClearAllPoints(); s.bottom:SetPoint("CENTER", p, "BOTTOM", 0, -2)
        s.outer:ClearAllPoints(); s.outer:SetPoint("CENTER", p, side, mirror and 2 or -2, 0)
        if s.state then s.state:ClearAllPoints(); s.state:SetPoint("CENTER", p, side, mirror and 4 or -4, 0) end
    end
    -- the raid mark on the top point, the leader's crown on the bottom one
    if f.raidIcon then f.raidIcon:ClearAllPoints(); f.raidIcon:SetPoint("CENTER", p, "TOP", 0, 1); f.raidIcon:SetSize(18, 18) end
    if f.leader then f.leader:ClearAllPoints(); f.leader:SetPoint("CENTER", p, "BOTTOM", 0, -1); f.leader:SetSize(13, 13) end
end
-- (back to the box: the pieces Starcut moved go home)
local function ClassicPortrait(f)
    local p, s = f.portrait, f.scParts
    if p then
        if p.bg then p.bg:Show() end
        if p.sep then p.sep:Show() end
        p.tex:ClearAllPoints(); p.tex:SetPoint("TOPLEFT", 1, -1); p.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        p.model:ClearAllPoints(); p.model:SetPoint("TOPLEFT", 1, -1); p.model:SetPoint("BOTTOMRIGHT", -1, 1)
        p.scSize = nil
        EmblemFill(f)
        if s then ScMasked(p.tex, s.mask, false) end
    end
    if s then ScShow(s, false) end
    if f.raidIcon then f.raidIcon:ClearAllPoints(); f.raidIcon:SetPoint("CENTER", f, "TOP", 0, 0); f.raidIcon:SetSize(16, 16) end
    if f.leader then f.leader:ClearAllPoints(); f.leader:SetPoint("CENTER", f, "TOPLEFT", 8, 0); f.leader:SetSize(12, 12) end
end

-- The point stars give way to what stands on their point (a raid mark, the crown, combat or rest).
local function ScPoints(f)
    local s = f.scParts
    if not (s and s.top and ns.StarcutOn()) then return end
    s.top:SetShown(not (f.raidIcon and f.raidIcon:IsShown()))
    s.bottom:SetShown(not (f.leader and f.leader:IsShown()))
    s.outer:SetShown(not (s.state and s.state:IsShown()))
end

-- name (and level) above the bars, on the player and target; it is cut short with "..." before it
-- reaches the far end
local function ScName(f, mirror, d)
    if not (f.name and f.opt.stars) then return end
    local where = d and d.name
    f.name:SetAlpha(where == "OFF" and 0 or 1)
    f.name:ClearAllPoints()
    f.name:SetJustifyH(mirror and "RIGHT" or "LEFT")
    if mirror then f.name:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -14, 5) else f.name:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 14, 5) end
    f.scNameMax = math.max(60, (f:GetWidth() or 200) - 70)
    if f.level then
        f.level:ClearAllPoints()
        if mirror then f.level:SetPoint("RIGHT", f.name, "LEFT", -8, 0) else f.level:SetPoint("LEFT", f.name, "RIGHT", 8, 0) end
    end
end
-- (the name's width follows its text, up to the room there is; set after each new name)
local function ScNameFit(f)
    if not f.scNameMax or not ns.StarcutOn() or not f.opt.stars then return end
    local ok, w = pcall(function() return (f.name.GetUnboundedStringWidth and f.name:GetUnboundedStringWidth()) or f.name:GetStringWidth() end)
    if ok and type(w) == "number" and not Secret(w) then f.name:SetWidth(math.min(w + 2, f.scNameMax)) else f.name:SetWidth(f.scNameMax) end
end

local function ScLayout(f)
    local o = f.opt
    local mirror = o.portrait == "RIGHT"
    local W, H = f:GetWidth(), f:GetHeight()
    ScName(f, mirror, f.designKey and ns.FrameDesign(f.designKey) or {})
    local style = ns.db.ufPortrait or "3D"
    if f.bg then f.bg:Hide() end
    if f.suiBorder then f.suiBorder:Hide(); if f.suiBorder.outer then f.suiBorder.outer:Hide() end end
    for _, t in ipairs(f.corners or {}) do t:Hide() end
    -- bars: health on top, power under it, set in from the points
    local ph = o.power or 0
    if ph > 0 and o.stars then ph = math.max(ph, 12) end
    local gap = ph > 0 and 5 or 0
    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, ph + gap)
    if f.health.SetReverseFill then f.health:SetReverseFill(mirror) end
    ScBar(f.health, true)
    ScGlowFit(f.health, W, H - ph - gap)
    if f.power then
        f.power:SetShown(ph > 0)
        if ph > 0 then
            f.power:ClearAllPoints()
            f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 0)
            f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 0)
            f.power:SetHeight(ph)
            if f.power.SetReverseFill then f.power:SetReverseFill(mirror) end
            ScBar(f.power, true)
            ScGlowFit(f.power, W - 32, ph)
        end
        -- a power bar tall enough carries its own text, at the same end as the health text
        if f.ppct and ph >= 10 then
            f.ppct:ClearAllPoints()
            if mirror then f.ppct:SetPoint("LEFT", f.power, "LEFT", 12, 0); f.ppct:SetJustifyH("LEFT")
            else f.ppct:SetPoint("RIGHT", f.power, "RIGHT", -12, 0); f.ppct:SetJustifyH("RIGHT") end
            f.ppct:SetTextColor(1, 1, 1)
            f.ppctInline = false
        end
    end
    -- the portrait diamond
    local s = ScParts(f)
    if f.portrait then
        if style == "OFF" or f.portraitOff then
            f.portrait:Hide()
            ScShow(s, false)
        else
            f.portrait:Show()
            ScShow(s, true)
            ScPortrait(f, math.floor(H * (o.stars and 1.7 or 1.3) + 0.5), mirror)        -- (smaller off the player and target: party frames sit close)
        end
    end
    -- the line from the diamond past the bars to a star
    if s.line then
        local hy = -(H - ph - gap) / 2
        s.line:ClearAllPoints(); s.endStar:ClearAllPoints()
        if mirror then
            s.line:SetPoint("LEFT", f, "TOPLEFT", -16, hy); s.line:SetPoint("RIGHT", f, "TOPRIGHT", 6, hy)
            s.endStar:SetPoint("CENTER", f, "TOPLEFT", -20, hy)
        else
            s.line:SetPoint("LEFT", f, "TOPLEFT", -6, hy); s.line:SetPoint("RIGHT", f, "TOPRIGHT", 16, hy)
            s.endStar:SetPoint("CENTER", f, "TOPRIGHT", 20, hy)
        end
        s.line:SetShown(true); s.endStar:SetShown(true)
    end
    if f.level and not o.stars and f.textLayer then         -- (inside the bar: clear of its point)
        f.level:ClearAllPoints(); f.level:SetPoint("LEFT", f.textLayer, "LEFT", 14, 0)
    end
    if f.combo then ScBar(f.combo, true, false) end           -- combo points: the same cut, no glow
    if f.combat then f.combat:Hide() end                      -- (the red line over the box: the swords take its place)
    if f.rest then f.rest:Hide() end
    -- the cast bar under the frame, cut to points, its icon a small diamond
    local bar = f.cast
    if bar then
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 26, -8)
        bar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", -16, -8)
        bar:SetHeight(14)
        ScBar(bar, true)
        ScGlowFit(bar, W - 42, 14)
        if bar.suiBorder then bar.suiBorder:Hide(); if bar.suiBorder.outer then bar.suiBorder.outer:Hide() end end
        if not bar.scIconMask then bar.scIconMask = ScMask(bar, "diamond", bar.icon, 0) end
        ScMasked(bar.icon, bar.scIconMask, true)
        bar.icon:SetSize(20, 20)
        bar.icon:ClearAllPoints(); bar.icon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    end
    -- clicks reach the diamond and the name too
    if not InCombatLockdown() and f.SetHitRectInsets then
        local reach = (f.portrait and f.portrait:IsShown()) and -(f.portrait:GetWidth() + 8) or 0
        local top = o.stars and -20 or 0
        if mirror then pcall(f.SetHitRectInsets, f, 0, reach, top, 0) else pcall(f.SetHitRectInsets, f, reach, 0, top, 0) end
    end
end

-- back to the box
local function ClassicRestore(f)
    if not f.scLaidOut then return end
    f.scLaidOut = nil
    if f.bg then f.bg:Show() end
    if f.suiBorder then f.suiBorder:Show(); if f.suiBorder.outer then f.suiBorder.outer:Show() end end
    for _, t in ipairs(f.corners or {}) do t:Show() end
    ScBar(f.health, false); ScBar(f.power, false); ScBar(f.combo, false)
    if f.health.SetReverseFill then f.health:SetReverseFill(false) end
    if f.power and f.power.SetReverseFill then f.power:SetReverseFill(false) end
    ClassicPortrait(f)
    if f.ppct then
        f.ppct:ClearAllPoints()
        if f.ppctInlineBase then
            f.ppct:SetPoint("RIGHT", f.pct, "LEFT", -6, 0)
        else
            f.ppct:SetPoint("RIGHT", f.power, "RIGHT", -4, 0)
            f.ppct:SetTextColor(1, 1, 1)
        end
        f.ppct:SetJustifyH("RIGHT")
        f.ppctInline = f.ppctInlineBase
    end
    if f.level and f.textLayer then
        f.level:ClearAllPoints(); f.level:SetPoint("LEFT", f.textLayer, "LEFT", 6, 0)
    end
    if f.name then f.name:SetWidth(0); f.scNameMax = nil end
    local bar = f.cast
    if bar then
        ScBar(bar, false)
        if bar.scIconMask then ScMasked(bar.icon, bar.scIconMask, false) end
        if bar.suiBorder then bar.suiBorder:Show(); if bar.suiBorder.outer then bar.suiBorder.outer:Show() end end
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 16, -5)
        bar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -5)
        bar:SetHeight(14)
        bar.icon:SetSize(14, 14)
        bar.icon:ClearAllPoints(); bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
    end
    if not InCombatLockdown() and f.SetHitRectInsets then pcall(f.SetHitRectInsets, f, 0, 0, 0, 0) end
end

------------------------------------------------------------------------------------------
-- Portrait: live 3D model, 2D picture, class icon, or off
------------------------------------------------------------------------------------------
-- Our own class emblems (Media\emblem): a medallion in the theme, tinted in the class color (see ns:CreateEmblem).
local OUR_CLASSES = { WARRIOR = 1, PALADIN = 1, HUNTER = 1, ROGUE = 1, PRIEST = 1, SHAMAN = 1, MAGE = 1, WARLOCK = 1,
                      DRUID = 1, DEATHKNIGHT = 1, MONK = 1, DEMONHUNTER = 1, EVOKER = 1 }

local function UpdatePortrait(f)
    local p = f.portrait
    if not p or not p:IsShown() or f.showcase == true then return end           -- (screenshot mode keeps its sample)
    local unit, style = f.unit, ns.db.ufPortrait or "3D"
    p.model:Hide()
    p.tex:Hide()
    if p.emblem then p.emblem:Hide() end
    if not UnitExists(unit) then return end

    if style == "3D" and UnitIsVisible(unit) then
        p.model:Show()
        p.model:ClearModel()
        p.model:SetUnit(unit)
        p.model:SetPortraitZoom(1)
        p.model:SetCamDistanceScale(1)
        p.model:SetPosition(0, 0, 0)
        return
    end
    if style == "CLASS" and ns.Yes(UnitIsPlayer(unit)) then
        local _, class = UnitClass(unit)
        if type(class) == "string" and not ns:IsSecret(class) and OUR_CLASSES[class] then
            local r, g, b = ns:ClassColor(unit)
            EmblemMake(f)                                    -- (its full size and shape, every time it shows: in a fight too)
            p.emblem:SetClass(class, r, g, b)
            p.emblem:Show()
            return
        end
    end
    SetPortraitTexture(p.tex, unit)
    p.tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
    p.tex:SetVertexColor(1, 1, 1)
    p.tex:Show()
end

------------------------------------------------------------------------------------------
-- Updates
------------------------------------------------------------------------------------------
local function UpdateHealth(f)
    if f.showcase == true then return end
    local u = f.unit
    pcall(function()
        f.health:SetMinMaxValues(0, UnitHealthMax(u))
        ns:SetBar(f.health, UnitHealth(u))
    end)
    if not f.pct then return end
    local ok, state = pcall(function()
        if ns.Is(UnitIsConnected(u), false) then return ns.OfflineWord() end
        if ns.Yes(UnitIsDeadOrGhost(u)) then return ns.DeadWord() end
    end)
    if ok and state then f.pct:SetText(state) else ns.healthTextMode = SetHealthText(f.pct, u) or ns.healthTextMode end
end

-- (the option was just changed: rewrite the text on every frame that is showing)
local UpdatePower                                           -- (made below; named here so this can reach it)
function ns:RefreshHealthText()
    for _, f in ipairs(frames) do
        if f.pct and f:IsShown() then pcall(UpdateHealth, f) end
        if f.ppct and f:IsShown() then pcall(UpdatePower, f) end
    end
    if ns.RefreshPlateHealth then ns:RefreshPlateHealth() end               -- nameplates follow the same choice
    if ns.RefreshRoleHUD then pcall(ns.RefreshRoleHUD) end                  -- and the role HUD
end
ns.SetHealthText = SetHealthText

-- Mana, rage, energy and the rest, written as text: a percentage, or the amount itself with the
-- "Mana & resources as numbers" option.
--
-- When the amounts can be read, this is simple arithmetic. On some clients they are hidden from
-- add-ons, in combat or all the time, and then the game has to do the writing:
--   * an amount can be handed to the game to shorten and write (the same way hidden health is shown);
--   * a percentage has to come from the game's UnitPowerPercent. An add-on cannot look up exactly how
--     that function wants to be called. If a real percentage has ever been readable, each likely way
--     is tried once and the one that agrees is kept. If nothing has ever been readable, the likeliest
--     way is used unchecked. And if a way was tested and none agreed, the amount is shown instead:
--     a number that is right beats a percentage that might not be.
local powerCall                                             -- nil: never checked.  false: checked, none agreed.  else: the call that agreed
local powerGuess                                            -- when unchecked: the first call the game accepted
local POWER_CALLS = {
    function(u, curve) return UnitPowerPercent(u, nil, false, curve) end,
    function(u, curve) return UnitPowerPercent(u, nil, curve) end,
    function(u, curve) return UnitPowerPercent(u, false, curve) end,
    function(u, curve) return UnitPowerPercent(u, curve) end,
}
local function LearnPowerCall(unit, truth)
    local curve = CurveConstants and CurveConstants.ScaleTo100
    if not UnitPowerPercent or not curve then powerCall = false; return end
    for _, call in ipairs(POWER_CALLS) do
        local ok, v = pcall(call, unit, curve)
        if ok and type(v) == "number" and not Secret(v) and math.abs(v - truth) <= 1.5 then powerCall = call; return end
    end
    powerCall = false
end
local function WriteHiddenAmount(fs, p)
    if AbbreviateNumbers and pcall(function() fs:SetText(AbbreviateNumbers(p)) end) then return "hidden amount, shortened by the game" end
    if pcall(function() fs:SetFormattedText("%d", p) end) then return "hidden amount, written in full" end
end
local function SetPowerText(fs, unit)
    local p, max = UnitPower(unit), UnitPowerMax(unit)
    if not Secret(p) and not Secret(max) then
        if type(p) ~= "number" or type(max) ~= "number" or max <= 0 then
            fs:SetText("")
            return "nothing (this unit has no resource)"
        end
        local pct = p / max * 100
        if powerCall == nil and pct >= 5 then LearnPowerCall(unit, pct) end         -- (at 0% every answer looks right)
        if ns.db.powerNumbers then fs:SetText(Short(p)); return "amount" end
        fs:SetText(floor(pct + 0.5) .. "%")
        return "percentage, worked out"
    end
    -- hidden from add-ons
    if ns.db.powerNumbers then
        local how = WriteHiddenAmount(fs, p)
        if how then return how end
    end
    local curve = CurveConstants and CurveConstants.ScaleTo100
    if UnitPowerPercent and curve and powerCall ~= false then
        if powerCall then
            if pcall(function() fs:SetFormattedText("%.0f%%", powerCall(unit, curve)) end) then return "percentage, written by the game" end
        else
            for i = powerGuess or 1, #POWER_CALLS do                                -- unchecked: the first the game accepts
                if pcall(function() fs:SetFormattedText("%.0f%%", POWER_CALLS[i](unit, curve)) end) then
                    powerGuess = i
                    return "percentage, written by the game (way " .. i .. ", unchecked: the amounts have never been readable)"
                end
            end
        end
    end
    local how = WriteHiddenAmount(fs, p)                     -- no percentage to be had: the amount instead
    if how then return how .. " (no percentage available)" end
    fs:SetText("")
    return "nothing (the game would not write it)"
end
ns.SetPowerPct = SetPowerText                               -- (the name nameplates and older code use)
ns.SetPowerText = SetPowerText
function ns:PowerTextState()
    if not ns.db.powerText then return "off" end
    return (ns.db.powerNumbers and "amounts" or "percentages") .. "; on your frame: " .. tostring(ns.powerTextMode or "not drawn yet")
end
-- For the self-check: what the game's percentage function answers on this client, each way of calling it.
function ns:PowerPercentProbe()
    local curve = CurveConstants and CurveConstants.ScaleTo100
    if not UnitPowerPercent then return "this client has no UnitPowerPercent" end
    if not curve then return "this client has no ScaleTo100 curve" end
    local parts = {}
    for i, call in ipairs(POWER_CALLS) do
        local ok, v = pcall(call, "player", curve)
        parts[i] = i .. "=" .. ((not ok) and "refused" or Secret(v) and "hidden" or (type(v) == "number" and format("%.2f", v)) or type(v))
    end
    local kept = powerCall and "one agreed with a real percentage" or (powerCall == false and "none agreed with a real percentage") or "never checked against a real percentage"
    return table.concat(parts, "  ") .. "  (" .. kept .. ")"
end
function ns:ForgetPowerCall() powerCall, powerGuess = nil, nil end       -- (for tests)

UpdatePower = function(f)
    if f.showcase == true then return end
    if not f.power then return end
    local u = f.unit
    local ptype, token = UnitPowerType(u)
    local c = PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])
    if c and c.r then f.power:SetStatusBarColor(c.r, c.g, c.b) else f.power:SetStatusBarColor(0.25, 0.5, 1) end
    if f.power.sc then ScTint(f.power, 0.6) end
    pcall(function()
        f.power:SetMinMaxValues(0, UnitPowerMax(u))
        ns:SetBar(f.power, UnitPower(u))
    end)
    if f.ppct then
        if ns.db.powerText then
            local ok, how = pcall(SetPowerText, f.ppct, u)
            if f.realUnit == "player" and u == "player" then ns.powerTextMode = ok and how or ("an error: " .. tostring(how)) end
        else
            f.ppct:SetText("")
        end
        if f.ppctInline then                                 -- the resource's color, lightened so it reads on a dark frame
            local r, g, b = 0.25, 0.5, 1
            if c and c.r then r, g, b = c.r, c.g, c.b end
            f.ppct:SetTextColor(r + (1 - r) * 0.45, g + (1 - g) * 0.45, b + (1 - b) * 0.45)
        end
    end
end
-- The same lightened resource color, for anything else that writes a resource percentage (nameplates).
function ns:PowerTextColor(unit)
    local r, g, b = 0.25, 0.5, 1
    local ok, ptype, token = pcall(UnitPowerType, unit)
    local c = ok and PowerBarColor and (PowerBarColor[token] or PowerBarColor[ptype])
    if type(c) == "table" and c.r then r, g, b = c.r, c.g, c.b end
    return r + (1 - r) * 0.45, g + (1 - g) * 0.45, b + (1 - b) * 0.45
end

local function UpdateInfo(f)
    if f.showcase == true then return end
    local u = f.unit
    f.health:SetStatusBarColor(UnitColor(u))
    f.name:SetText(UnitName(u) or "")
    if f.level then
        local lvl = UnitLevel(u)
        if Secret(lvl) then
            f.level:SetText(lvl)
        else
            local class = UnitClassification and UnitClassification(u)
            local tag = (ns.Is(class, "elite") or ns.Is(class, "rareelite") or ns.Is(class, "worldboss")) and "+" or ""
            f.level:SetText((lvl and lvl > 0) and (lvl .. tag) or "??")
            local c = (lvl and lvl > 0 and GetCreatureDifficultyColor) and GetCreatureDifficultyColor(lvl)
            if c and UnitCanAttack("player", u) then f.level:SetTextColor(c.r, c.g, c.b) else f.level:SetTextColor(1, 0.82, 0) end
        end
    end
    if f.raidIcon then
        local idx = GetRaidTargetIndex and GetRaidTargetIndex(u)
        if not Secret(idx) and idx and SetRaidTargetIconTexture then
            SetRaidTargetIconTexture(f.raidIcon, idx)
            f.raidIcon:Show()
        else
            f.raidIcon:Hide()
        end
    end
    if f.leader then
        if UnitIsGroupLeader and UnitIsGroupLeader(u) then f.leader:Show() else f.leader:Hide() end
    end
    if f.health.sc then ScTint(f.health, 0.5) end
    if f.scNameMax then ScNameFit(f) end
    if f.scParts then ScPoints(f) end
end

local function UpdateStatus(f)   -- player only: combat edge + resting mark
    local state = f.scParts and f.scParts.state
    if state and ns.StarcutOn() then                          -- Starcut: crossed swords or a resting sign on the outer point
        local fighting, resting = UnitAffectingCombat("player"), IsResting and IsResting()
        if ns.Yes(fighting) then state:SetTexCoord(0.5, 1, 0, 0.484375); state:Show()
        elseif ns.Yes(resting) then state:SetTexCoord(0, 0.5, 0, 0.421875); state:Show()
        else state:Hide() end
        ScPoints(f)
        return
    end
    if f.combat then
        if UnitAffectingCombat("player") then f.combat:Show() else f.combat:Hide() end
    end
    if f.rest then
        if IsResting and IsResting() then f.rest:Show() else f.rest:Hide() end
    end
end

-- Buffs / debuffs on the target, focus and player frames --------------------------------------
-- Aura designer (11.3, Bars and frames tab, Auras): for each frame what shows (buffs and debuffs,
-- debuffs, buffs, nothing), only your own debuffs or all, how many, how big, above or below the
-- frame, and growing right or left. ns.db.auraDesign[kind]; anything not set is as it came.
ns.AURA_DEFAULT = {
    target = { show = "both", mine = false, max = 10, size = 22, side = "above", grow = "right" },
    focus  = { show = "none", mine = true,  max = 6,  size = 20, side = "above", grow = "right" },
    player = { show = "none", mine = false, max = 8,  size = 22, side = "above", grow = "right" },
    raid   = { hots = 3, debuff = true, dispel = true },
}
function ns.AuraDesign(kind)
    local base = ns.AURA_DEFAULT[kind] or ns.AURA_DEFAULT.target
    local saved = type(ns.db and ns.db.auraDesign) == "table" and type(ns.db.auraDesign[kind]) == "table" and ns.db.auraDesign[kind] or {}
    local out = {}
    for k, v in pairs(base) do if saved[k] == nil then out[k] = v else out[k] = saved[k] end end
    if out.max then out.max = math.max(0, math.min(16, math.floor(tonumber(out.max) or base.max))) end
    if out.size then out.size = math.max(14, math.min(36, math.floor(tonumber(out.size) or base.size))) end
    if out.hots then out.hots = math.max(0, math.min(3, math.floor(tonumber(out.hots) or 3))) end
    if out.show and not ({ both = true, debuffs = true, buffs = true, none = true })[out.show] then out.show = base.show end
    if kind == "target" and saved.mine == nil and ns.db and ns.db.myDebuffsOnly then out.mine = true end      -- (the old Combat tab switch)
    return out
end
-- Auras you never want on a frame (the "Hidden on frames" list on the Tools tab): names in lower case.
local blockSet, blockAt
function ns.AuraBlocked(name)
    if type(name) ~= "string" or ns:IsSecret(name) then return false end
    local list = ns.db and ns.db.auraBlock
    if type(list) ~= "table" or #list == 0 then return false end
    if blockAt ~= list or (blockSet and blockSet.n ~= #list) then
        blockSet = { n = #list }
        for _, v in ipairs(list) do if type(v) == "string" then blockSet[v:lower()] = true end end
        blockAt = list
    end
    return blockSet[name:lower()] == true
end
-- Where each icon of a row sits: x for the i-th icon, the anchor point on the row.
function ns.AuraSlot(i, size, grow)
    local step = (i - 1) * (size + 3)
    if grow == "left" then return "BOTTOMRIGHT", -step end
    return "BOTTOMLEFT", step
end
local function AuraRowLayout(row)
    local f = row.unitFrame
    local d = ns.AuraDesign(row.kind)
    row.size, row.max = d.size, (d.show == "none") and 0 or d.max
    row:ClearAllPoints()
    row:SetHeight(d.size)
    local pad = 6
    local side = d.side
    local sc = ns.StarcutOn()
    if sc then
        local saved = type(ns.db.auraDesign) == "table" and type(ns.db.auraDesign[row.kind]) == "table" and ns.db.auraDesign[row.kind].side
        if not saved then side = "below" end                         -- (no side chosen yet)
        if side == "above" and f.opt.stars then pad = pad + 20 end     -- (above the name)
        if side == "below" and f.cast then pad = pad + 6 end           -- (Starcut's cast bar sits a little lower)
    end
    if side == "below" then
        row:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -(pad + ((row.kind ~= "player" and f.cast) and 22 or 0)))
        row:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -(pad + ((row.kind ~= "player" and f.cast) and 22 or 0)))
    else
        row:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, pad)
        row:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, pad)
    end
    for i, b in ipairs(row.buttons) do
        local point, x = ns.AuraSlot(i, d.size, d.grow)
        b:SetSize(d.size, d.size)
        b:ClearAllPoints()
        b:SetPoint(point, row, point, x, 0)
    end
end
local function AuraButton(row, i)
    local b = CreateFrame("Frame", nil, row)
    local d = ns.AuraDesign(row.kind)
    local point, x = ns.AuraSlot(i, d.size, d.grow)
    b:SetSize(d.size, d.size)
    b:SetPoint(point, row, point, x, 0)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints()
        -- a buff or debuff starts in full color and darkens as it runs out (the other way round is
        -- for an ability coming off cooldown)
        if cd.SetReverse then cd:SetReverse(true) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        b.cd = cd
    end
    b.count = Text(b, 10, "RIGHT")
    b.count:SetPoint("BOTTOMRIGHT", 1, 0)
    b.kind = Text(b, 9, "LEFT")                       -- color-blind aid: M / C / P / D for the debuff type
    b.kind:SetPoint("TOPLEFT", 1, -1)
    ns:AddBorder(b, 0, 0, 0, 1)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if not pcall(GameTooltip.SetUnitAura, GameTooltip, row.unitFrame.unit, self.index, self.filter) then GameTooltip:Hide() return end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.buttons[i] = b
    return b
end

local function UpdateAuras(f)
    local row = f.auras
    if not row then return end
    local n = 0
    local get = ns.GetAura
    local function add(filter, debuff)
        for i = 1, 40 do
            if n >= row.max then return end
            local a = get(f.unit, i, filter)
            if not a then return end
            if not ns.AuraBlocked(a.name) then
            n = n + 1
            local b = row.buttons[n] or AuraButton(row, n)
            b.index, b.filter = i, filter
            pcall(b.icon.SetTexture, b.icon, a.icon)
            if b.cd then
                -- prefer the call that takes the raw (possibly hidden) times
                if not (b.cd.SetCooldownFromExpirationTime and pcall(b.cd.SetCooldownFromExpirationTime, b.cd, a.expirationTime, a.duration)) then
                    if not pcall(function() b.cd:SetCooldown(a.expirationTime - a.duration, a.duration) end) then b.cd:Hide() end
                end
            end
            local apps = a.applications
            if not Secret(apps) and apps and apps > 1 then b.count:SetText(apps) else b.count:SetText("") end
            b.kind:SetText((debuff and ns.db.colorblind) and ns:DispelLetter(a.dispelName) or "")
            if debuff and ns.db.auraFilter and f.unit ~= "player" and ns.Is(a.isFromPlayerOrPlayerPet, true) then
                ns:Paint(b.suiBorder, "SetBackdropBorderColor", "@accent", 1)          -- your own debuff: rimmed in the accent color
            elseif debuff then b.suiBorder:SetBackdropBorderColor(ns:DebuffColor(a.dispelName))     -- (magic blue, curse purple ...)
            else b.suiBorder:SetBackdropBorderColor(0, 0, 0, 1) end
            b:Show()
            end
        end
    end
    local d = ns.AuraDesign(row.kind)
    row.max = (d.show == "none") and 0 or d.max
    if get and UnitExists(f.unit) and row.max > 0 then
        if d.show == "both" or d.show == "debuffs" then add(d.mine and "HARMFUL|PLAYER" or "HARMFUL", true) end
        if d.show == "both" or d.show == "buffs" then add("HELPFUL", false) end
    end
    for i = n + 1, #row.buttons do row.buttons[i]:Hide() end
end

-- Cast bar (target / focus) -----------------------------------------------------------------
local function CastCheck(f)
    if f.cast and f.cast.showcase == true then return end
    local bar = f.cast
    if not bar or bar.preview then return end
    local unit = f.unit
    local name, _, texture, startMS, endMS = UnitCastingInfo(unit)
    local channel = false
    if not Secret(name) and name == nil then
        name, _, texture, startMS, endMS = UnitChannelInfo(unit)
        channel = true
    end
    if not Secret(name) and name == nil then
        bar.active = false
        bar:Hide()
        return
    end
    pcall(function() bar:SetMinMaxValues(startMS, endMS) end)
    bar.text:SetText(name)
    pcall(bar.icon.SetTexture, bar.icon, texture)
    local a = ns.theme.accent
    if channel then bar:SetStatusBarColor(0.35, 0.85, 0.45) else bar:SetStatusBarColor(a[1], a[2], a[3]) end
    if bar.sc then ScTint(bar, 0.55) end
    -- remember the end time only when the client lets us read it (used as a safety net)
    bar.endsAt = (not Secret(endMS) and endMS) and (endMS / 1000) or nil
    bar.active = true
    bar:Show()
end

-- Screenshot mode (/fgui showcase): a frame shows made-up data and stops listening to its unit until
-- the mode ends. d = { name, level, levelColor, class (for color and picture), color {r,g,b},
-- hp, pp, powerColor {r,g,b}, cast = { name, icon, done } }.
local CLASS_FALLBACK = { WARRIOR = { 0.78, 0.61, 0.43 }, PALADIN = { 0.96, 0.55, 0.73 }, HUNTER = { 0.67, 0.83, 0.45 }, ROGUE = { 1, 0.96, 0.41 },
                         PRIEST = { 1, 1, 1 }, SHAMAN = { 0, 0.44, 0.87 }, MAGE = { 0.25, 0.78, 0.92 }, WARLOCK = { 0.53, 0.53, 0.93 }, DRUID = { 1, 0.49, 0.04 } }
function ns.UnitFrameSample(f, d)
    if not d then
        f.showcase = nil
        if f.cast and f.cast.showcase == true then f.cast.showcase = nil; f.cast.active = false; f.cast:Hide() end
        return
    end
    f.showcase = true
    local c = d.color
    if not c and d.class then
        local rc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.class]
        c = rc and { rc.r, rc.g, rc.b } or CLASS_FALLBACK[d.class] or { 0.2, 0.6, 1 }
    end
    c = c or { 0.2, 0.6, 1 }
    f.health:SetMinMaxValues(0, 100); f.health:SetValue(d.hp or 100)
    f.health:SetStatusBarColor(c[1], c[2], c[3])
    if f.health.sc then ScTint(f.health, 0.5) end
    if f.pct then f.pct:SetText((d.hp or 100) .. "%") end
    if f.power then
        local pc = d.powerColor or { 0.25, 0.5, 1 }
        f.power:SetMinMaxValues(0, 100); f.power:SetValue(d.pp or 0)
        f.power:SetStatusBarColor(pc[1], pc[2], pc[3])
        if f.power.sc then ScTint(f.power, 0.6) end
        if f.ppct then f.ppct:SetText(d.pp and (d.pp .. "%") or "") end
    end
    if f.name then f.name:SetText(d.name or ""); f.name:SetTextColor(1, 1, 1) end
    if f.level then
        f.level:SetText(d.level or "")
        local lc = d.levelColor or { 1, 0.82, 0 }
        f.level:SetTextColor(lc[1], lc[2], lc[3])
    end
    if f.scNameMax then ScNameFit(f) end
    local p = f.portrait
    if p and p:IsShown() then                                      -- a class picture, or the one given
        p.model:Hide(); if p.emblem then p.emblem:Hide() end
        if d.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[d.class] then
            p.tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            local t = CLASS_ICON_TCOORDS[d.class]
            p.tex:SetTexCoord(t[1], t[2], t[3], t[4])
        elseif d.icon then
            p.tex:SetTexture(d.icon); p.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        p.tex:SetVertexColor(1, 1, 1); p.tex:Show()
    end
    if f.cast then
        if d.cast then
            f.cast.showcase = true; f.cast.preview = true
            f.cast:SetMinMaxValues(0, 100); f.cast:SetValue(d.cast.done or 60)
            f.cast.text:SetText(d.cast.name); f.cast.icon:SetTexture(d.cast.icon or 136243)
            f.cast:SetStatusBarColor(0.95, 0.55, 0.2)
            f.cast:Show()
        else
            f.cast.showcase = nil; f.cast:Hide()
        end
    end
end

local UpdateAll
function UpdateAll(f)
    if f.showcase == true or not UnitExists(f.unit) then return end
    -- each step on its own: if the client refuses one read, the rest still update
    pcall(UpdateHealth, f)
    pcall(UpdatePower, f)
    pcall(UpdateInfo, f)
    pcall(UpdatePortrait, f)
    pcall(UpdateAuras, f)
    pcall(UpdateStatus, f)
    pcall(CastCheck, f)
end
ns.UnitFrameUpdate = UpdateAll                                 -- (screenshot mode hands a frame back to its unit)

------------------------------------------------------------------------------------------
-- Layout (portrait side / hidden)
------------------------------------------------------------------------------------------
local function Layout(f)
    local want = ns.StarcutOn()
    local switched = f.scStyleWas ~= nil and f.scStyleWas ~= want
    f.scStyleWas = want
    if want then
        if switched then pcall(ns.ApplyDesign, f) end         -- (the name moves above the bars, the target's text to its left)
        f.scLaidOut = true
        return ScLayout(f)
    end
    ClassicRestore(f)
    if switched then pcall(ns.ApplyDesign, f) end
    local o = f.opt
    local style = ns.db.ufPortrait or "3D"
    local h = f:GetHeight()
    local left, right = 1, -1
    if f.portrait then
        f.portrait:SetSize(h, h)
        if style == "OFF" or f.portraitOff then
            f.portrait:Hide()
        else
            f.portrait:Show()
            f.portrait:ClearAllPoints()
            if o.portrait == "RIGHT" then
                f.portrait:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
                right = -(h + 1)
            else
                f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
                left = h + 1
            end
        end
    end
    local ph = o.power or 0
    f.health:ClearAllPoints()
    f.health:SetPoint("TOPLEFT", f, "TOPLEFT", left, -1)
    f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", right, 1 + (ph > 0 and (ph + 1) or 0))
    if f.power and ph <= 0 then f.power:Hide() elseif f.power then f.power:Show() end
    if f.power and ph > 0 then
        f.power:ClearAllPoints()
        f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, 1)
        f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", right, 1)
        f.power:SetHeight(ph)
    end
end

------------------------------------------------------------------------------------------
-- Building one frame
------------------------------------------------------------------------------------------
local UNIT_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_NAME_UPDATE", "UNIT_LEVEL", "UNIT_FACTION", "UNIT_CONNECTION",
    "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "UNIT_AURA",
}
local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_CHANNEL_UPDATE",
}

local function OnEvent(self, event, _, ...)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_CONNECTION" then
        UpdateHealth(self)
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        UpdatePower(self)
        if self.combo then self.combo.Update() end
    elseif event == "UNIT_AURA" then
        UpdateAuras(self)
    elseif event == "UNIT_COMBAT" then
        if self.flash and ns.db.hitFlash then self.flash(...) end
    elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        UpdatePortrait(self)
    elseif event:find("^UNIT_SPELLCAST") then
        CastCheck(self)
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_UPDATE_RESTING" then
        UpdateStatus(self)
    elseif event == "RAID_TARGET_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "UNIT_NAME_UPDATE"
        or event == "UNIT_LEVEL" or event == "UNIT_FACTION" then
        UpdateInfo(self)
    else
        UpdateAll(self)       -- target / focus / pet / roster changed, entering world
    end
end

------------------------------------------------------------------------------------------
-- Frame designer (11.0): each frame's own size, power bar height, portrait side, text size, and
-- where its name and health text sit, from the Bars and frames tab. Saved as ns.db.ufDesign[key];
-- anything not set there stays as the frame was made.
------------------------------------------------------------------------------------------
ns.DESIGN_FRAMES = {
    { key = "Player", label = "Player frame" }, { key = "Target", label = "Target frame" },
    { key = "TargetTarget", label = "Target's target" }, { key = "Focus", label = "Focus frame" },
    { key = "FocusTarget", label = "Focus's target frame" }, { key = "Pet", label = "Pet frame" },
}
function ns.FrameDesign(key)
    local all = ns.db and ns.db.ufDesign
    local d = type(all) == "table" and all[key]
    return type(d) == "table" and d or {}
end
function ns.ApplyDesign(f)
    if type(f) ~= "table" or not f.designKey or not f.baseOpt then return false end
    local d, o, base = ns.FrameDesign(f.designKey), f.opt, f.baseOpt
    if not InCombatLockdown() and (d.w or d.h) then f:SetSize(d.w or f:GetWidth(), d.h or f:GetHeight()) end
    if f.power then o.power = (d.power ~= nil) and math.max(0, math.min(20, tonumber(d.power) or 0)) or base.power end
    if f.portrait then
        f.portraitOff = (d.portrait == "OFF")
        o.portrait = (d.portrait == "LEFT" or d.portrait == "RIGHT") and d.portrait or base.portrait
    end
    local size = math.max(8, math.min(22, tonumber(d.font) or base.font))
    local layer = f.textLayer
    if f.name and layer and ns.StarcutOn() and f.opt.stars then
        ns:Font(f.name, size)
        ScName(f, f.opt.portrait == "RIGHT", d)
    elseif f.name and layer then
        ns:Font(f.name, size)
        f.name:ClearAllPoints()
        local where = d.name or "LEFT"
        f.name:SetAlpha(where == "OFF" and 0 or 1)
        if where == "CENTER" then
            f.name:SetPoint("CENTER", layer, "CENTER", 0, 0)
            f.name:SetWidth(math.max(40, (f:GetWidth() or 120) - 70))
            f.name:SetJustifyH("CENTER")
        else
            f.name:SetJustifyH("LEFT")
            local edge = ns.StarcutOn() and 14 or 6              -- (Starcut: clear of the bar's points)
            if f.level then f.name:SetPoint("LEFT", f.level, "RIGHT", 4, 0) else f.name:SetPoint("LEFT", layer, "LEFT", edge, 0) end
            local right = (d.health or "RIGHT") == "RIGHT" and (f.ppctInline and f.ppct or f.pct) or nil
            if right then f.name:SetPoint("RIGHT", right, "LEFT", -6, 0) else f.name:SetPoint("RIGHT", layer, "RIGHT", -edge, 0) end
        end
    end
    if f.pct and layer then
        ns:Font(f.pct, size)
        f.pct:ClearAllPoints()
        local where = d.health or ((ns.StarcutOn() and f.opt.portrait == "RIGHT") and "LEFT") or "RIGHT"
        f.pct:SetAlpha(where == "OFF" and 0 or 1)
        local inset = ns.StarcutOn() and 16 or 6                 -- (Starcut: clear of the bar's points)
        if where == "CENTER" then f.pct:SetPoint("CENTER", layer, "CENTER", 0, 0); f.pct:SetJustifyH("CENTER")
        elseif where == "LEFT" then f.pct:SetPoint("LEFT", layer, "LEFT", inset, 0); f.pct:SetJustifyH("LEFT")
        else f.pct:SetPoint("RIGHT", layer, "RIGHT", -inset, 0); f.pct:SetJustifyH("RIGHT") end
    end
    return true
end

local function CreateUnit(key, unit, w, h, opt)
    local th = ns.theme
    local f = CreateFrame("Button", "FantasyGlassUI_" .. key, UIParent, "SecureUnitButtonTemplate")
    f:SetSize(w, h)
    f.unit, f.realUnit, f.opt = unit, unit, opt
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    f:SetAttribute("*type2", "togglemenu")
    f:RegisterForClicks("AnyUp")

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetTexture(ns.FLAT)
    ns:Paint(f.bg, "SetVertexColor", "bg4", 0.92)
    ns:AddBorder(f, 0, 0, 0, 1)

    f.health = NewBar(f)
    if (opt.power or 0) > 0 then f.power = NewBar(f) end

    if opt.portrait then
        local p = CreateFrame("Frame", nil, f)
        p:SetSize(h, h)
        p.bg = p:CreateTexture(nil, "BACKGROUND")
        p.bg:SetAllPoints()
        p.bg:SetTexture(ns.FLAT)
        ns:Paint(p.bg, "SetVertexColor", "bg", 1)
        p.tex = p:CreateTexture(nil, "ARTWORK")
        p.tex:SetPoint("TOPLEFT", 1, -1)
        p.tex:SetPoint("BOTTOMRIGHT", -1, 1)
        p.model = CreateFrame("PlayerModel", nil, p)
        p.model:SetPoint("TOPLEFT", 1, -1)
        p.model:SetPoint("BOTTOMRIGHT", -1, 1)
        -- hairline between portrait and bars, in the accent color
        local sep = p:CreateTexture(nil, "OVERLAY")
        sep:SetTexture(ns.FLAT)
        ns:Paint(sep, "SetVertexColor", "@accent", 0.9)
        sep:SetWidth(1)
        if opt.portrait == "RIGHT" then
            sep:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0); sep:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
        else
            sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0); sep:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
        end
        p.sep = sep
        f.portrait = p
    end

    -- text sits on its own layer above bars and model
    local layer = CreateFrame("Frame", nil, f)
    f.textLayer = layer
    layer:SetAllPoints(f.health)
    layer:SetFrameLevel(f:GetFrameLevel() + 6)
    if opt.ornate then f.corners = ns:Corners(layer, f, opt.ornate, -3) end     -- gold filigree hugging the frame's corners
    local fs = opt.font or 12
    f.pct = Text(layer, fs, "RIGHT")
    f.pct:SetPoint("RIGHT", layer, "RIGHT", -6, 0)
    if f.power then
        if (opt.power or 0) >= 8 then                        -- a power bar tall enough to carry the text itself
            f.ppct = Text(layer, 9, "RIGHT")
            f.ppct:SetPoint("RIGHT", f.power, "RIGHT", -4, 0)
            f.ppct:SetTextColor(1, 1, 1)
        else                                                 -- a thin bar: the text sits left of the health text instead,
            f.ppct = Text(layer, math.max(9, fs - 2), "RIGHT")   -- in the resource's own color so the two can be told apart
            f.ppct:SetPoint("RIGHT", f.pct, "LEFT", -6, 0)
            f.ppctInline = true
        end
        f.ppctInlineBase = f.ppctInline
        if f.ppct.SetShadowOffset then f.ppct:SetShadowOffset(1, -1); f.ppct:SetShadowColor(0, 0, 0, 1) end   -- readable on any color
    end
    local anchor, ax = layer, 6
    if opt.level then
        f.level = Text(layer, fs - 1, "LEFT")
        f.level:SetPoint("LEFT", layer, "LEFT", 6, 0)
        f.level:SetTextColor(1, 0.82, 0)
        anchor, ax = f.level, 4
    end
    f.name = Text(layer, fs, "LEFT")
    if anchor == layer then f.name:SetPoint("LEFT", layer, "LEFT", ax, 0) else f.name:SetPoint("LEFT", anchor, "RIGHT", ax, 0) end
    f.name:SetPoint("RIGHT", f.ppctInline and f.ppct or f.pct, "LEFT", -6, 0)      -- the name gives way to whatever is at its right

    f.raidIcon = layer:CreateTexture(nil, "OVERLAY")
    f.raidIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    f.raidIcon:SetSize(16, 16)
    f.raidIcon:SetPoint("CENTER", f, "TOP", 0, 0)
    f.raidIcon:Hide()

    if opt.leader then
        f.leader = layer:CreateTexture(nil, "OVERLAY")
        f.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        f.leader:SetSize(12, 12)
        f.leader:SetPoint("CENTER", f, "TOPLEFT", 8, 0)
        f.leader:Hide()
    end

    if opt.status then
        f.combat = layer:CreateTexture(nil, "OVERLAY")
        f.combat:SetTexture(ns.FLAT)
        f.combat:SetVertexColor(1, 0.2, 0.2, 1)
        f.combat:SetHeight(2)
        f.combat:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 1)
        f.combat:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 1)
        f.combat:Hide()
        f.rest = Text(layer, 10, "RIGHT")
        f.rest:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -2, 3)
        f.rest:SetText("|cffffd100" .. ns:Tr("Resting") .. "|r")
        f.rest:Hide()
    end

    if opt.cast then
        local bar = NewBar(f)
        bar:SetHeight(14)
        bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 16, -5)
        bar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -5)
        ns:AddBorder(bar, 0, 0, 0, 1)
        bar.icon = bar:CreateTexture(nil, "ARTWORK")
        bar.icon:SetSize(14, 14)
        bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        bar.text = Text(bar, 10, "LEFT")
        bar.text:SetPoint("LEFT", 4, 0)
        bar.text:SetPoint("RIGHT", -4, 0)
        bar:Hide()
        bar:SetScript("OnUpdate", ns:Guard("Cast bars", function(self)
            if self.preview then                       -- sample cast that loops while previewing
                self:SetMinMaxValues(0, 2.5)
                self:SetValue(GetTime() % 2.5)
                return
            end
            if not self.active then return end
            local now = GetTime()
            self:SetValue(now * 1000)
            if self.endsAt and now > self.endsAt + 0.3 then self.active = false; self:Hide() end
        end))
        f.cast = bar
    end

    if opt.auraKind then
        local row = CreateFrame("Frame", nil, f)
        row.kind, row.buttons, row.unitFrame = opt.auraKind, {}, f
        row:SetSize(w, 22)
        f.auras = row
        AuraRowLayout(row)
    end

    f:SetScript("OnEnter", function(self)
        if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self)
        else GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT") end
        GameTooltip:SetUnit(self.unit)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    for _, e in ipairs(UNIT_EVENTS) do pcall(f.RegisterUnitEvent, f, e, unit) end
    if opt.flash then
        local flash = ns:Flasher(f.health)
        f.flash = function(action, descriptor)            -- red on a critical hit taken, green on a critical heal
            pcall(function()
                if descriptor ~= "CRITICAL" and descriptor ~= "CRUSHING" then return end
                if not ns:Motion() then return end
                if action == "WOUND" then flash(ns:Signal("bad")) elseif action == "HEAL" then flash(ns:Signal("good")) end
            end)
        end
        pcall(f.RegisterUnitEvent, f, "UNIT_COMBAT", unit)
    end
    if opt.cast then
        for _, e in ipairs(CAST_EVENTS) do pcall(f.RegisterUnitEvent, f, e, unit) end
    end
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("RAID_TARGET_UPDATE")
    for _, e in ipairs(opt.events or {}) do pcall(f.RegisterEvent, f, e) end
    f:SetScript("OnEvent", ns:Guard("Unit frames", OnEvent))
    f:SetScript("OnShow", ns:Guard("Unit frames", UpdateAll))

    f.designKey = key
    f.baseOpt = { power = opt.power or 0, portrait = opt.portrait, font = opt.font or 12, w = w, h = h }
    pcall(ns.ApplyDesign, f)
    Layout(f)
    frames[#frames + 1] = f
    if ns.RegisterClickCast then ns:RegisterClickCast(f) end
    return f
end

------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------
ns:NewModule("unitFrames", function()
    local th = ns.theme

    local player = CreateUnit("Player", "player", ns.db.ufW, ns.db.ufH,
        { portrait = "LEFT", power = 8, font = 13, level = true, leader = true, status = true, ornate = 16, flash = true, auraKind = "player", stars = true,
          events = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING", "PARTY_LEADER_CHANGED" } })
    player:SetPoint("CENTER", UIParent, "CENTER", -250, -180)

    local target = CreateUnit("Target", "target", ns.db.ufW, ns.db.ufH,
        { portrait = "RIGHT", power = 8, font = 13, level = true, cast = true, auraKind = "target", ornate = 16, flash = true, stars = true,
          events = { "PLAYER_TARGET_CHANGED" } })
    target:SetPoint("CENTER", UIParent, "CENTER", 250, -180)
    player.sizeKey, target.sizeKey = "main", "main"

    local tot = CreateUnit("TargetTarget", "targettarget", 120, 24, { font = 11 })
    tot:SetPoint("CENTER", UIParent, "CENTER", 440, -168)

    local focus = CreateUnit("Focus", "focus", 180, 34,
        { portrait = "LEFT", power = 5, font = 12, cast = true, ornate = 13, auraKind = "focus", events = { "PLAYER_FOCUS_CHANGED" } })
    focus:SetPoint("CENTER", UIParent, "CENTER", -430, -60)

    -- what your focus is targeting: a small frame like the target's target, under the focus frame
    local focusTarget
    if ns.db.ufFocusTarget then
        focusTarget = CreateUnit("FocusTarget", "focustarget", 120, 24, { font = 11 })
        focusTarget:SetPoint("CENTER", UIParent, "CENTER", -400, -98)
    end
    ns.focusTargetFrame = focusTarget

    local pet = CreateUnit("Pet", "pet", 140, 26, { power = 4, font = 11 })
    pet:SetPoint("CENTER", UIParent, "CENTER", -200, -230)
    pcall(pet.RegisterUnitEvent, pet, "UNIT_PET", "player")

    for _, f in ipairs({ target, tot, focus, pet }) do RegisterUnitWatch(f) end
    if focusTarget then RegisterUnitWatch(focusTarget) end

    -- target-of-target (and the focus's target) get no events of their own: refresh them a few times a second
    local tacc = 0
    local poll = CreateFrame("Frame")
    poll:SetScript("OnUpdate", ns:Guard("Unit frames", function(_, e)
        tacc = tacc + e
        if tacc < 0.25 then return end
        tacc = 0
        if tot:IsShown() then UpdateInfo(tot); UpdateHealth(tot) end
        if focusTarget and focusTarget:IsShown() then UpdateInfo(focusTarget); UpdateHealth(focusTarget) end
    end))

    -- Combo points: a five-segment bar that takes the raw value
    local _, class = UnitClass("player")
    if class == "ROGUE" or class == "DRUID" then
        local combo = NewBar(player)
        combo:SetHeight(6)
        combo:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -4)
        combo:SetPoint("TOPRIGHT", player, "BOTTOMRIGHT", 0, -4)
        combo:SetStatusBarColor(1, 0.75, 0.2)
        ns:AddBorder(combo, 0, 0, 0, 1)
        local ticks = {}
        for i = 1, 4 do
            local tick = combo:CreateTexture(nil, "OVERLAY")
            tick:SetTexture(ns.FLAT)
            tick:SetVertexColor(0, 0, 0, 1)
            tick:SetWidth(1)
            ticks[i] = tick
        end
        function combo.Ticks(w)                    -- re-space the dividers when the frame is resized
            for i, tick in ipairs(ticks) do
                tick:ClearAllPoints()
                tick:SetPoint("TOP", combo, "TOPLEFT", w * i / 5, 0)
                tick:SetPoint("BOTTOM", combo, "BOTTOMLEFT", w * i / 5, 0)
            end
        end
        combo.Ticks(ns.db.ufW)
        combo.Update = function()
            pcall(function()
                combo:SetMinMaxValues(0, 5)
                combo:SetValue(UnitPower("player", 4))
            end)
            if UnitPowerType("player") == 3 then combo:Show() else combo:Hide() end   -- energy users only
        end
        player.combo = combo
        combo.Update()
        Layout(player)                                        -- (so the combo bar takes the frame style too)
    end

    -- Party ------------------------------------------------------------------------------------
    local party = {}
    if ns.db.ufParty then
        for i = 1, 4 do
            local f = CreateUnit("Party" .. i, "party" .. i, ns.db.partyW, ns.db.partyH,
                { portrait = "LEFT", power = 5, font = 12, leader = true,
                  events = { "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" } })
            f:SetPoint("LEFT", UIParent, "LEFT", 30, 140 - (i - 1) * 56)
            -- shown for party members, hidden in raids (the raid frames take over there)
            f.sizeKey = "party"
            f.visDriver = "[group:raid] hide; [@party" .. i .. ",exists] show; hide"
            RegisterStateDriver(f, "visibility", f.visDriver)
            party[i] = f
        end
    end

    -- Bosses -----------------------------------------------------------------------------------
    -- Up to five, stacked down the right side. Each appears when the game says that boss exists and
    -- goes when it doesn't, like the target frame; click one to target it.
    local boss = {}
    if ns.db.ufBoss then
        for i = 1, 5 do
            local f = CreateUnit("Boss" .. i, "boss" .. i, 190, 30,
                { power = 4, font = 12, cast = true, level = true,
                  events = { "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "UNIT_TARGETABLE_CHANGED", "UNIT_NAME_UPDATE" } })
            f:SetPoint("RIGHT", UIParent, "RIGHT", -110, 150 - (i - 1) * 58)
            RegisterUnitWatch(f)
            boss[i] = f
        end
    end
    ns.bossFrames = boss

    -- Arena enemies (11.6) -----------------------------------------------------------------------
    -- Up to five, down the right side like the bosses: each appears while that enemy exists in the
    -- arena. Left-click targets, right-click sets focus. Their trinket, interrupt and dispel
    -- cooldowns are drawn beside them by Arena.lua.
    local arena = {}
    if ns.db.ufArena then
        for i = 1, 5 do
            local f = CreateUnit("Arena" .. i, "arena" .. i, 190, 34,
                { power = 4, font = 12, cast = true,
                  events = { "ARENA_OPPONENT_UPDATE", "UNIT_NAME_UPDATE", "PLAYER_ENTERING_WORLD" } })
            f:SetAttribute("*type2", "focus")
            f:SetPoint("RIGHT", UIParent, "RIGHT", -110, 230 - (i - 1) * 62)
            RegisterUnitWatch(f)
            arena[i] = f
        end
    end
    ns.arenaFrames = arena

    -- Put Blizzard's unit frames away (out of combat only; nothing is hooked) -------------------
    local function Park(frame, keepEvents)
        if type(frame) ~= "table" or not frame.SetParent then return end
        if not keepEvents and frame.UnregisterAllEvents then frame:UnregisterAllEvents() end
        frame:SetParent(ns.hidden)
    end
    local function ParkAll()
        Park(_G.PlayerFrame, true)      -- keeps its events so vehicle / class logic stays quiet but alive
        Park(_G.TargetFrame)
        Park(_G.FocusFrame)
        Park(_G.PetFrame)
        if ns.db.ufParty then
            local pf = _G.PartyFrame
            if type(pf) == "table" then
                for i = 1, 4 do Park(pf["MemberFrame" .. i]) end
                Park(pf)
            end
        end
        if ns.db.ufBoss then                              -- the game's boss frames, now that ours stand in for them
            for i = 1, 8 do Park(_G["Boss" .. i .. "TargetFrame"]) end
            Park(_G.BossTargetFrameContainer)
        end
        if ns.db.ufArena then                             -- the game's arena frames, now that ours stand in for them
            Park(_G.ArenaEnemyFramesContainer)
        end
        -- shaman totems live on Blizzard's player frame: bring them to ours
        local totems = _G.TotemFrame
        if type(totems) == "table" and totems.SetParent then
            pcall(function()
                totems:SetParent(player)
                totems:ClearAllPoints()
                totems:SetPoint("TOPLEFT", player, "BOTTOMLEFT", 0, -6)
            end)
        end
    end
    if InCombatLockdown() then
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", ns:Guard("UnitFrames events", function(self) self:UnregisterAllEvents(); pcall(ParkAll) end))
    else
        ParkAll()
    end

    -- Movers -------------------------------------------------------------------------------------
    ns:RegisterMovable(player, "ufPlayer", "Player")
    ns:RegisterMovable(target, "ufTarget", "Target")
    ns:RegisterMovable(tot, "ufToT", "Target's target")
    ns:RegisterMovable(focus, "ufFocus", "Focus")
    if focusTarget then ns:RegisterMovable(focusTarget, "ufFocusTarget", "Focus's target") end
    ns:RegisterMovable(pet, "ufPet", "Pet")
    for i, f in ipairs(party) do ns:RegisterMovable(f, "ufParty" .. i, format(ns:Tr("Party %d"), i)) end
    for i, f in ipairs(boss) do ns:RegisterMovable(f, "ufBoss" .. i, format(ns:Tr("Boss %d"), i)) end
    for i, f in ipairs(arena) do ns:RegisterMovable(f, "ufArena" .. i, format(ns:Tr("Arena enemy %d"), i)) end

    -- Live refresh (portrait style changed in options)
    function ns:RefreshUnitFrames()
        if InCombatLockdown() then
            ns:Print("Portrait style will apply after combat or a /reload.")
            return
        end
        for _, f in ipairs(frames) do
            Layout(f)
            if f:IsShown() then UpdateAll(f) end
        end
    end

    -- Idle fade: with nothing targeted, out of combat and at full health, the player and pet frames dim
    local idleFrames = { player, pet }
    ns:Every(0.2, "Idle fade", function()
        local want = 1
        if ns.db.idleFade and not ns.previewing and not ns.moving and not InCombatLockdown() and not UnitExists("target") then
            local hp, max = UnitHealth("player"), UnitHealthMax("player")
            local casting = UnitCastingInfo("player")
            if not Secret(hp) and not Secret(max) and hp == max and not Secret(casting) and casting == nil then want = 0.4 end
        end
        for _, f in ipairs(idleFrames) do
            local cur = f:GetAlpha()
            if type(cur) == "number" and math.abs(cur - want) > 0.01 then
                f:SetAlpha(ns:Motion() and (cur + (want - cur) * 0.3) or want)      -- (Reduce motion: no slow dimming)
            end
        end
    end)

    -- the frame designer's changes, at once (sizes wait for the end of a fight)
    function ns:ApplyFrameDesign()
        local n = 0
        for _, f in ipairs(frames) do
            if f.designKey then
                pcall(ns.ApplyDesign, f)
                Layout(f)
                if not InCombatLockdown() then
                    if f.auras then f.auras:SetWidth(f:GetWidth()) end
                    if f.combo then f.combo.Ticks(f:GetWidth()) end      -- (the combo point dividers follow a new width)
                end
                if f:IsShown() then pcall(UpdateAll, f) end
                n = n + 1
            end
        end
        if InCombatLockdown() then ns.designPending = true end
        return n
    end
    ns.unitFrameList = frames
    -- the aura designer's changes, at once
    function ns:ApplyAuraDesign()
        local n = 0
        for _, f in ipairs(frames) do
            if f.auras then
                pcall(AuraRowLayout, f.auras)
                if f:IsShown() then pcall(UpdateAuras, f) end
                n = n + 1
            end
        end
        if ns.RefreshRaidAuras then pcall(ns.RefreshRaidAuras, ns) end
        if ns.RefreshPlateAuras then pcall(ns.RefreshPlateAuras, ns) end
        return n
    end
    do
        local later = CreateFrame("Frame")
        later:RegisterEvent("PLAYER_REGEN_ENABLED")
        later:SetScript("OnEvent", ns:Guard("UnitFrames events", function()
            if ns.designPending then ns.designPending = nil; ns:ApplyFrameDesign() end
            if ns.RunFrameStyleHooks then ns:RunFrameStyleHooks() end
        end))
    end
    -- Live resize (size sliders in /fgui layout)
    function ns:ResizeUnitFrames()
        if InCombatLockdown() then
            ns:Print("Frame sizes will apply after combat or a /reload.")
            return
        end
        for _, f in ipairs(frames) do
            local w, h
            if f.sizeKey == "main" then w, h = ns.db.ufW, ns.db.ufH
            elseif f.sizeKey == "party" then w, h = ns.db.partyW, ns.db.partyH end
            local d = f.designKey and ns.FrameDesign(f.designKey) or {}
            if d.w or d.h then w, h = d.w or w or f:GetWidth(), d.h or h or f:GetHeight() end
            if w then
                f:SetSize(w, h)
                if f.auras then f.auras:SetWidth(w) end
                if f.combo then f.combo.Ticks(w) end
                Layout(f)
                if f:IsShown() then UpdateAll(f) end
            end
        end
    end

    -- Preview (/fgui test): every frame shows you, with a sample cast, so it can be placed and sized
    ns:RegisterPreview(function(on)
        for _, f in ipairs(frames) do
            if f.realUnit ~= "player" then
                if on then
                    if f.visDriver then UnregisterStateDriver(f, "visibility") else UnregisterUnitWatch(f) end
                    f:SetAttribute("unit", "player")
                    f.unit = "player"
                    f:Show()
                    UpdateAll(f)
                    if f.cast then
                        f.cast.preview = true
                        f.cast.text:SetText(ns:Tr("Sample Spell"))
                        f.cast.icon:SetTexture(136243)
                        ns:Paint(f.cast, "SetStatusBarColor", "@accent")
                        f.cast:Show()
                    end
                else
                    if f.cast then f.cast.preview = nil; f.cast.active = false; f.cast:Hide() end
                    f:SetAttribute("unit", f.realUnit)
                    f.unit = f.realUnit
                    if f.visDriver then RegisterStateDriver(f, "visibility", f.visDriver) else RegisterUnitWatch(f) end
                    if UnitExists(f.unit) then UpdateAll(f) end
                end
            end
        end
    end)

    ns:OnTheme(function() if not InCombatLockdown() then ns:RefreshUnitFrames() end end)
    ns:OnAurasBack(function() ns:RefreshUnitFrames() end)

    UpdateAll(player)
end)
