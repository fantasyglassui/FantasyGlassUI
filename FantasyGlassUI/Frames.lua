local _, ns = ...

local function Path(root, ...)
    local o = root
    for i = 1, select("#", ...) do
        if type(o) ~= "table" then return nil end
        o = o[select(i, ...)]
    end
    return o
end

local function HealthBars()
    return {
        { Path(PlayerFrame, "PlayerFrameContent", "PlayerFrameContentMain", "HealthBarsContainer", "HealthBar") or _G.PlayerFrameHealthBar, "player" },
        { Path(TargetFrame, "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar") or _G.TargetFrameHealthBar, "target" },
        { Path(FocusFrame, "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar") or _G.FocusFrameHealthBar, "focus" },
    }
end

-- Class-colored health bars ------------------------------------------------------
-- (The four modules in this file restyle a Blizzard piece only while our own replacement for it is off.)
ns:NewModule("fallbacks", function()
    if ns.db.unitFrames then return end
    local function Color(bar, unit)
        if type(bar) ~= "table" or not bar.SetStatusBarColor then return end
        unit = unit or bar.unit or bar.displayedUnit
        if type(unit) ~= "string" then return end
        local r, g, b = ns:ClassColor(unit)
        if r then bar:SetStatusBarColor(r, g, b) end
    end
    if UnitFrameHealthBar_Update then
        hooksecurefunc("UnitFrameHealthBar_Update", ns:Safe("Class colors", Color))
    end
    if HealthBar_OnValueChanged then
        hooksecurefunc("HealthBar_OnValueChanged", ns:Safe("Class colors", function(self) Color(self) end))
    end
    for _, e in ipairs(HealthBars()) do
        if e[1] then Color(e[1], e[2]) end
    end
end)

-- Dark steel unit-frame borders ----------------------------------------------------
ns:NewModule("fallbacks", function()
    if ns.db.unitFrames then return end
    local tex = {
        Path(PlayerFrame, "PlayerFrameContainer", "FrameTexture"),
        Path(TargetFrame, "TargetFrameContainer", "FrameTexture"),
        Path(FocusFrame, "TargetFrameContainer", "FrameTexture"),
        Path(TargetFrame, "totFrame", "FrameTexture"),
        Path(FocusFrame, "totFrame", "FrameTexture"),
        _G.PetFrameTexture, _G.PlayerFrameTexture, _G.TargetFrameTextureFrameTexture,
    }
    for i = 1, 4 do
        tex[#tex + 1] = Path(PartyFrame, "MemberFrame" .. i, "Texture")
    end
    for _, t in pairs(tex) do
        if type(t) == "table" and t.SetVertexColor then t:SetVertexColor(0.30, 0.30, 0.36) end
    end
end)

-- Cast bar with countdown --------------------------------------------------------------
ns:NewModule("fallbacks", function()
    if ns.db.playerCast then return end      -- our own cast bar replaces it
    local cb = PlayerCastingBarFrame or CastingBarFrame
    if not cb then return end
    for _, k in ipairs({ "Border", "TextBorder", "BorderShield", "Flash" }) do ns:Kill(cb[k]) end
    if cb.Text and cb.Text.SetFont then ns:Font(cb.Text, 11) end

    ns:NewBackdrop(cb, { ns:T("bg2", 0.85) }, nil, -1, 2)

    cb.suiTimer = cb:CreateFontString(nil, "OVERLAY")
    ns:Font(cb.suiTimer, 11)
    cb.suiTimer:SetPoint("RIGHT", cb, "RIGHT", -4, 0)

    -- Our own driver reads the bar's state; nothing is hooked on the game's cast bar
    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", ns:Guard("Cast bar", function()
        local v, m, t = cb.value, cb.maxValue, nil
        if not ns:IsSecret(v) and not ns:IsSecret(m) then
            if cb.casting then t = (m or 0) - (v or 0)
            elseif cb.channeling then t = v or 0 end
        end
        cb.suiTimer:SetText((t and t > 0) and format("%.1f", t) or "")
    end))
end)

-- Buffs / debuffs ----------------------------------------------------------------------
local function StyleAura(btn, noBox)
    if btn.suiSkinned then return end
    btn.suiSkinned = true
    local icon = btn.Icon or btn.icon
    if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    if not noBox then ns:AddBorder(btn, 0, 0, 0, 1) end
    if btn.Duration and btn.Duration.SetFont then ns:Font(btn.Duration, 10) end
    if btn.Count and btn.Count.SetFont then ns:Font(btn.Count, 11) end
end

local function RecolorAura(btn)
    local border = btn.Border or btn.DebuffBorder
    if border and btn.suiBorder and border.GetVertexColor then
        local r, g, b = border:GetVertexColor()
        if ns:IsSecret(r) then return end
        border:SetAlpha(0)
        btn.suiBorder:SetBackdropBorderColor(r or 0.8, g or 0, b or 0, 1)
    end
end

-- Is there actually an icon in this button? The game keeps some buff and debuff buttons in place
-- with nothing in them; a border round one of those is just an empty square on the screen.
local function HasIcon(btn)
    local icon = btn.Icon or btn.icon
    if type(icon) ~= "table" then return false end
    local ok, shown = pcall(icon.IsShown, icon)
    if ok and shown == false then return false end
    local okA, alpha = pcall(icon.GetAlpha, icon)
    if okA and type(alpha) == "number" and not ns:IsSecret(alpha) and alpha <= 0 then return false end
    local okT, tex = pcall(icon.GetTexture, icon)
    if okT and tex == nil then return false end              -- nothing has been put in it
    return true                                              -- (an icon the game will not name still counts)
end
-- One of the game's buff or debuff buttons.
--
-- Buffs get our border, and only while the button holds something.
--
-- Debuffs (noBox) get no border of ours at all. On clients that hide debuffs from add-ons, the game
-- keeps a fixed row of debuff buttons on screen and shows or hides each icon itself, in a way an
-- add-on cannot see. A border of ours can't follow that, so it stayed up round every slot: a row
-- of empty boxes. The game's own colored edge is left alone, and comes and goes with the debuff.
function ns.StyleGameAura(btn, noBox)
    StyleAura(btn, noBox)
    if noBox then
        local old = btn.suiBorder                            -- (a box put on by an earlier version, this session)
        if old and btn.suiBoxed ~= false then
            btn.suiBoxed = false
            old:Hide()
            if old.outer then old.outer:Hide() end
        end
        return
    end
    RecolorAura(btn)
    local border = btn.suiBorder
    if border then
        local want = HasIcon(btn)
        if btn.suiBoxed ~= want then
            btn.suiBoxed = want
            if want then border:Show() else border:Hide() end
            if border.outer then
                if want then border.outer:Show() else border.outer:Hide() end
            end
        end
    end
end

ns:NewModule("fallbacks", function()
    -- Normally our own buff bars replace Blizzard's, and this restyle is the fallback when they are off.
    -- On clients that hide auras in combat, Blizzard's frames are always the ones in use, and the
    -- "Buff frames" switch decides whether they get restyled.
    -- Whenever the game's buff frames are the ones on screen, they can be moved: each gets a handle in
    -- move mode. They are pinned by the corner the game anchors them with, so as buffs come and go
    -- the row grows and shrinks from the same end it always did.
    if ns.aurasLocked or not ns.db.auraBars then
        local function Adopt()
            ns:AdoptGameFrame(_G.BuffFrame, "gameBuffs", "Buffs", "The game sets the size of its buff icons (see its Edit Mode).", true)
            ns:AdoptGameFrame(_G.DebuffFrame, "gameDebuffs", "Debuffs", "The game sets the size of its debuff icons (see its Edit Mode).", true)
        end
        Adopt()
        ns:After(2, Adopt)                                   -- (in case the frames were not there yet)
    end
    if ns.aurasLocked then
        if not ns.db.auraBars then return end
    elseif ns.db.auraBars then
        return
    end
    local function RefreshFrame(f, noBox)
        local list = f and f.auraFrames
        if type(list) ~= "table" then return end
        for _, btn in pairs(list) do
            if type(btn) == "table" and btn.GetObjectType then ns.StyleGameAura(btn, noBox) end
        end
    end
    -- For /fgui check: what the game's debuff row looks like from here.
    function ns:GameAuraReport()
        local function count(f)
            local list = f and f.auraFrames
            if type(list) ~= "table" then return nil end
            local made, showing, unreadable = 0, 0, 0
            for _, btn in pairs(list) do
                if type(btn) == "table" and btn.GetObjectType then
                    made = made + 1
                    local ok, shown = pcall(btn.IsShown, btn)
                    if ok and shown then showing = showing + 1 end
                    local icon = btn.Icon or btn.icon
                    if type(icon) == "table" then
                        local okA, alpha = pcall(icon.GetAlpha, icon)
                        if not okA or ns:IsSecret(alpha) then unreadable = unreadable + 1 end
                    end
                end
            end
            return made .. " buttons, " .. showing .. " on screen" .. (unreadable > 0 and (", " .. unreadable .. " whose icon the game shows and hides out of our sight") or "")
        end
        return "buffs: " .. (count(_G.BuffFrame) or "no list") .. "   debuffs: " .. (count(_G.DebuffFrame) or "no list")
    end
    -- Buttons are created on demand, and fill and empty as buffs come and go, so re-check twice a second
    -- (no hooks on the buff frame)
    local refresh = ns:Guard("Buffs", function()
        RefreshFrame(_G.BuffFrame)
        RefreshFrame(_G.DebuffFrame, true)                   -- debuffs: no boxes
    end)
    local function tick() refresh(); ns:After(0.5, tick) end
    tick()
end)
