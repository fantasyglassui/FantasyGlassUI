local _, ns = ...
local Secret = function(v) return ns:IsSecret(v) end

-- Nameplate designer (11.0.1): what a nameplate shows and how big, from the Bars and frames tab.
-- Width and height are the game's own nameplate scale (plateW, plateH); the rest is ns.db.plateDesign.
ns.PLATE_DEFAULT = { nameSize = 10, nameShow = true, healthPos = "CENTER", healthSize = 9, castHeight = 8, castTextSize = 8,
                     auraSize = 18, auraMax = 5, auraMine = true, threat = true, threatEdge = true, highlight = true, questMarks = true }
function ns.PlateDesign()
    local d = type(ns.db and ns.db.plateDesign) == "table" and ns.db.plateDesign or {}
    local out = {}
    for k, v in pairs(ns.PLATE_DEFAULT) do
        if d[k] == nil then out[k] = v else out[k] = d[k] end
    end
    local function clamp(k, lo, hi) out[k] = math.max(lo, math.min(hi, tonumber(out[k]) or ns.PLATE_DEFAULT[k])) end
    clamp("nameSize", 6, 18); clamp("healthSize", 6, 18); clamp("castHeight", 4, 20); clamp("castTextSize", 6, 14)
    clamp("auraSize", 10, 32); clamp("auraMax", 0, 8)
    return out
end
-- (13.0.1) Where things sit round an enemy's bar, so none covers another:
--   the name over the bar, clear of the ring round your target;
--   the debuffs over the name;
--   at the bar's left, the level first, then the quest marks further out.
function ns.PlateNameGap()
    return 3 + math.max(0, math.min(8, tonumber(ns.db and ns.db.targetOutline) or 0))
end
function ns.PlateAuraLift()
    local pd = ns.PlateDesign()
    if not pd.nameShow then return 16 end
    return math.max(16, ns.PlateNameGap() + math.ceil(pd.nameSize * 1.25) + 2)
end
function ns.PlateLevelSlot()                                  -- room for "60" or "??", and the gap before the bar
    return 3 + math.ceil(ns.PlateDesign().nameSize * 1.3)
end

ns:NewModule("nameplates", function()
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    local th = ns.theme
    local extrasOn = ns.db.plateExtras
    local getAura = ns.GetAura

    local function HealthBar(uf)
        return uf.healthBar or uf.healthbar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
    end

    local function Usable(frame)
        return type(frame) == "table" and not (frame.IsForbidden and frame:IsForbidden())
    end
    local function IsTexture(o)
        return type(o) == "table" and o.GetObjectType and o:GetObjectType() == "Texture"
    end

    -- "This is your target": the game marks it with a thick yellow box around the health bar and
    -- another around the level badge (both called selectedBorder). Those are hidden; the game still
    -- shows and hides them, so we read that and turn our own thin rims to the accent color instead.
    local plates = setmetatable({}, { __mode = "k" })        -- unit frame -> was it selected last time we looked
    -- The rim round the bar (Starcut: its edge line): the accent on your target; otherwise, with
    -- "threat on the edge" on, the threat color (11.14: a tank sees which mob is slipping); otherwise plain.
    function ns.PlateEdge(bar, badge, selected)
        if not bar then return end
        local t = rawget(bar, "scThreat")
        bar = rawget(bar, "suiOwn") or bar                   -- (our own bar wears the colors)
        for _, rim in ipairs({ bar.suiBorder, badge and badge.suiBorder }) do
            if selected then ns:Paint(rim, "SetBackdropBorderColor", "@accent", 1)
            elseif t and rim == bar.suiBorder then ns:Unpaint(rim, "SetBackdropBorderColor"); rim:SetBackdropBorderColor(t[1], t[2], t[3], 1)
            else ns:Paint(rim, "SetBackdropBorderColor", "@border", 1) end           -- back to the rim every plate has
        end
        local edge = bar.sc and bar.sc.edge                  -- (Starcut has no box: its edge line takes the color)
        if edge then
            if selected then ns:Paint(edge, "SetVertexColor", "@accent", 1)
            elseif t then ns:Unpaint(edge, "SetVertexColor"); edge:SetVertexColor(t[1], t[2], t[3], 1)
            else ns:Paint(edge, "SetVertexColor", "@rim", 0.55) end
        end
        bar.scEdgeShown = selected and "target" or (t and "threat") or "plain"
        -- (12.1) "Outline round my target": a thick ring of its own, as wide as chosen, so the target
        -- stands out from a crowd of plates even at a glance
        local width = tonumber(ns.db and ns.db.targetOutline) or 0
        local ring = rawget(bar, "suiTargetRing")
        if selected and width > 0 then
            if not ring then
                ring = CreateFrame("Frame", nil, bar, ns.template)
                ring:SetFrameLevel((bar:GetFrameLevel() or 1) + 4)
                bar.suiTargetRing = ring
            end
            if ring.suiWidth ~= width then
                ring:SetBackdrop({ edgeFile = ns.FLAT, edgeSize = width })
                ring:ClearAllPoints()
                ring:SetPoint("TOPLEFT", bar, "TOPLEFT", -width - 1, width + 1)
                ring:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", width + 1, -width - 1)
                ring.suiWidth = width
            end
            if ns:ColorVision() == "none" then ns:Unpaint(ring, "SetBackdropBorderColor"); ring:SetBackdropBorderColor(1, 1, 1, 1)
            else ns:Paint(ring, "SetBackdropBorderColor", "@accent", 1) end
            ring:Show()
        elseif ring then
            ring:Hide()
        end
        return bar
    end
    local function Marks(uf)
        local bar = uf.healthBar or uf.healthbar or (uf.HealthBarsContainer and uf.HealthBarsContainer.healthBar)
        local badge = uf.PlayerLevelDiffFrame
        return bar, (type(badge) == "table") and badge or nil
    end
    local function ShowSelection(uf)
        local bar, badge = Marks(uf)
        local mark = bar and bar.selectedBorder
        if not IsTexture(mark) then return end
        local badgeMark = badge and badge.selectedBorder
        if mark:GetAlpha() ~= 0 then mark:SetAlpha(0) end
        if IsTexture(badgeMark) and badgeMark:GetAlpha() ~= 0 then badgeMark:SetAlpha(0) end
        local selected = mark:IsShown() and true or false
        if not ns.PlateDesign().highlight then selected = false end
        if plates[uf] == selected then return end
        plates[uf] = selected
        ns.PlateEdge(bar, badge, selected)
    end

    -- (11.16) Our own nameplate: the game's health bar is kept running but out of sight, and a bar of
    -- our own stands in its place - our texture, a black backing (the game's tinted its backing in the
    -- bar's own color, so a red bar sat on red), our rim or the Starcut cut. Whatever the game puts on
    -- its bar - the health, its color - is passed straight on to ours, hidden values included.
    function ns.PlateOwnBar(uf, bar)
        if type(bar) ~= "table" or rawget(bar, "suiOwn") then return rawget(bar, "suiOwn") end
        -- (in the bar's own parent: where the game hides the whole health area for a name-only plate, ours goes too)
        local holder = (bar.GetParent and bar:GetParent()) or uf
        if type(holder) ~= "table" or not holder.CreateTexture or holder.suiKilled then holder = uf end
        local own = ns:NewStatusBar(holder, true)
        own:SetAllPoints(bar)
        own:SetFrameLevel((bar.GetFrameLevel and bar:GetFrameLevel() or 1) + 1)
        if own.bg then own.bg:SetVertexColor(0.04, 0.04, 0.05, 0.9) end
        ns:AddBorder(own, 0, 0, 0, 1)
        ns:StarcutStyleBar(own, false)
        bar.suiOwn = own
        local okMM, lo, hi = pcall(bar.GetMinMaxValues, bar)
        if okMM then pcall(own.SetMinMaxValues, own, lo, hi) end
        local okV, v = pcall(bar.GetValue, bar)
        if okV then pcall(own.SetValue, own, v) end
        local okC, r, g, b = pcall(bar.GetStatusBarColor, bar)
        if okC and type(r) == "number" then pcall(own.SetStatusBarColor, own, r, g, b) end
        if hooksecurefunc then
            hooksecurefunc(bar, "SetMinMaxValues", function(_, a, z) pcall(own.SetMinMaxValues, own, a, z) end)
            hooksecurefunc(bar, "SetValue", function(_, x) pcall(own.SetValue, own, x) end)
            hooksecurefunc(bar, "SetStatusBarColor", function(_, cr, cg, cb) pcall(own.SetStatusBarColor, own, cr, cg, cb) end)
            -- where the game shows only a name (friendly plates), its bar is hidden: ours goes with it
            hooksecurefunc(bar, "Show", function() own:Show() end)
            hooksecurefunc(bar, "Hide", function() own:Hide() end)
            if bar.SetShown then hooksecurefunc(bar, "SetShown", function(_, on) own:SetShown(on and true or false) end) end
        end
        local okS, shown = pcall(bar.IsShown, bar)
        if okS and shown == false then own:Hide() end
        ns:Kill(bar)                                           -- (the game's bar: out of sight, still running)
        if hooksecurefunc then                                 -- (and if the game fades it back in, straight back out)
            hooksecurefunc(bar, "SetAlpha", function(self, a)
                if a ~= 0 and not self.suiZeroing then self.suiZeroing = true; pcall(self.SetAlpha, self, 0); self.suiZeroing = nil end
            end)
        end
        return own
    end
    -- (13.0.1) An enemy or a neutral unit: one you could attack, or one that is not friendly to you.
    -- Its plate carries our own name over the bar; a friendly plate keeps the game's name.
    local function Foe(unit)
        if type(unit) ~= "string" then return false end
        local okA, can = pcall(UnitCanAttack, "player", unit)
        if okA and ns.Yes(can) then return true end
        local okR, reaction = pcall(UnitReaction, unit, "player")
        return okR and type(reaction) == "number" and not Secret(reaction) and reaction <= 4 or false
    end
    -- The game's own name on the plate: out of sight on an enemy's plate (ours is drawn instead), and
    -- on a friendly one as the designer's "Names on nameplates" says.
    local function GameName(uf)
        if not (uf and uf.name and uf.name.SetAlpha) then return end
        local on = ns.PlateDesign().nameShow and not rawget(uf, "suiFoe")
        uf.name:SetAlpha(on and 1 or 0)
    end
    -- Our level, in the game's difficulty color ("??" for a boss): on an enemy's plate just left of the
    -- bar, at its middle (the name is over the bar); on a friendly plate just left of the game's name.
    local function PlateLevel(uf, unit)
        if not (uf.name and uf.name.GetParent) then return end
        local t = rawget(uf, "suiLevel")
        if not t then
            t = ns:NewText(uf, ns.PlateDesign().nameSize, "RIGHT", true)
            if t.SetShadowOffset then t:SetShadowOffset(1, -1); t:SetShadowColor(0, 0, 0, 1) end
            uf.suiLevel = t
        end
        local bar = HealthBar(uf)
        bar = bar and (rawget(bar, "suiOwn") or bar)
        t:ClearAllPoints()
        if bar and rawget(uf, "suiFoe") then t:SetPoint("RIGHT", bar, "LEFT", -3, 0)
        else t:SetPoint("RIGHT", uf.name, "LEFT", -3, 0) end
        local ok, lvl = pcall(UnitLevel, unit)
        if not ok or type(lvl) ~= "number" or Secret(lvl) or not ns.PlateDesign().nameShow then t:SetText(""); return end
        if lvl < 0 then t:SetText("??"); t:SetTextColor(1, 0.25, 0.2); return end
        t:SetText(lvl)
        local c = GetCreatureDifficultyColor and select(2, pcall(GetCreatureDifficultyColor, lvl))
        if type(c) == "table" and c.r then t:SetTextColor(c.r, c.g, c.b) else t:SetTextColor(1, 0.82, 0.3) end
    end
    ns.PlateLevel = PlateLevel

    local function Skin(uf)
        if not Usable(uf) then return end
        local bar = HealthBar(uf)
        if bar and not bar.suiSkinned then
            bar.suiSkinned = true
            ns.PlateOwnBar(uf, bar)
        end
        local badge = uf.PlayerLevelDiffFrame                  -- the game's level badge: ours is beside the name
        if type(badge) == "table" and badge.SetAlpha and not badge.suiKilled then ns:Kill(badge) end
        if bar then
            plates[uf] = nil                                   -- a reused plate: look at its selection afresh
            pcall(ShowSelection, uf)
        end
        if uf.name and uf.name.SetFont then
            local pd = ns.PlateDesign()
            ns:Font(uf.name, pd.nameSize)
            GameName(uf)
            -- our rim makes the bar a little taller than Blizzard's, which put the name's lower edge
            -- behind it: lift the name by that much, once, keeping whatever anchor the game chose
            if not uf.name.suiLifted then
                uf.name.suiLifted = true
                pcall(function()
                    if uf.name:GetNumPoints() == 1 then
                        local point, rel, relPoint, x, y = uf.name:GetPoint(1)
                        if type(y) == "number" and not ns:IsSecret(y) then
                            uf.name:SetPoint(point, rel, relPoint, x, y + 3)
                        end
                    end
                end)
            end
        end
        if extrasOn then          -- runs on every plate (re)use          -- ours replace Blizzard's cast bar and aura icons on the plate
            local cb = uf.castBar or uf.CastBar
            if type(cb) == "table" then
                if cb.UnregisterAllEvents then cb:UnregisterAllEvents() end
                ns:Kill(cb, true)
            end
            ns:Kill(uf.BuffFrame); ns:Kill(uf.AurasFrame)
        end
    end

    local function Color(frame)
        if not Usable(frame) then return end
        local unit = frame.unit
        if type(unit) ~= "string" or not unit:find("^nameplate") then return end
        local bar = HealthBar(frame)
        if not bar then return end

        local r, g, b = ns:ClassColor(unit)
        local pd = ns.PlateDesign()
        local tr, tg, tb                                       -- the threat color, if any
        if not r and (pd.threat or pd.threatEdge) and UnitCanAttack("player", unit) and UnitThreatSituation then
            local s = UnitThreatSituation("player", unit)
            if not ns:IsSecret(s) and s ~= nil then
                if ns.db.role == "TANK" then
                    if s == 3 then tr, tg, tb = ns:Signal("good")
                    elseif s == 2 then tr, tg, tb = ns:Signal("warn")
                    else tr, tg, tb = ns:Signal("bad") end
                elseif s == 3 then tr, tg, tb = ns:Signal("bad")
                elseif s == 2 then tr, tg, tb = ns:Signal("warn") end
            end
        end
        if tr and pd.threat then r, g, b = tr, tg, tb end
        if r then bar:SetStatusBarColor(r, g, b) end
        -- (12.1) with the color-blind option the threat has a mark too, not only a color: "!" when it is
        -- slipping, "!!" when it is lost (for a tank) or when it is on you (for anyone else)
        local mark = rawget(bar, "suiThreatMark")
        local level
        if tr and ns.db.colorblind then
            local s3 = UnitThreatSituation("player", unit)
            if not ns:IsSecret(s3) then
                if ns.db.role == "TANK" then level = (s3 == 2 and "!") or ((s3 == 0 or s3 == 1) and "!!") or nil
                else level = (s3 == 2 and "!") or (s3 == 3 and "!!") or nil end
            end
        end
        if level then
            if not mark then
                mark = bar:CreateFontString(nil, "OVERLAY")
                ns:Font(mark, 13, true)
                mark:SetPoint("LEFT", bar, "RIGHT", 3, 0)
                bar.suiThreatMark = mark
            end
            mark:SetText(level)
            mark:SetTextColor(tr, tg, tb)
            mark:Show()
        elseif mark then
            mark:Hide()
        end
        -- the edge: a tank's "good" (holding it) stays plain, so only the mobs slipping away stand out
        local edgeColor = (tr and pd.threatEdge and not (ns.db.role == "TANK" and tr == (ns:Signal("good")))) and { tr, tg, tb } or nil
        local old = rawget(bar, "scThreat")
        if (old == nil) ~= (edgeColor == nil) or (old and edgeColor and (old[1] ~= edgeColor[1] or old[2] ~= edgeColor[2])) then
            bar.scThreat = edgeColor
            local _, badge = Marks(frame)
            ns.PlateEdge(bar, badge, plates[frame] == true)
        end
    end

    -- Extras: enemy cast bar + your own debuffs ----------------------------------------------------
    local extras = {}

    local function PlateCast(x)
        local bar, unit = x.cast, x.unit
        if not unit then bar.active = false; bar:Hide(); return end
        local name, _, texture, startMS, endMS, _, _, locked = UnitCastingInfo(unit)
        local channel = false
        if not Secret(name) and name == nil then
            name, _, texture, startMS, endMS, _, locked = UnitChannelInfo(unit)
            channel = true
        end
        if not Secret(name) and name == nil then bar.active = false; bar:Hide(); return end

        pcall(function() bar:SetMinMaxValues(startMS, endMS) end)
        bar.text:SetText(name)
        pcall(bar.icon.SetTexture, bar.icon, texture)
        if channel then bar:SetStatusBarColor(0.35, 0.85, 0.45) else ns:Paint(bar, "SetStatusBarColor", "@accent") end
        -- casts you cannot interrupt are grayed out
        if Secret(locked) then
            if not (bar.lock.SetAlphaFromBoolean and pcall(bar.lock.SetAlphaFromBoolean, bar.lock, locked, 0.8, 0)) then bar.lock:SetAlpha(0) end
        else
            bar.lock:SetAlpha(locked and 0.8 or 0)
        end
        bar.endsAt = (not Secret(endMS) and endMS) and (endMS / 1000) or nil
        bar.active = true
        bar:Show()
    end

    local function AuraIcon(x, i)
        local b = CreateFrame("Frame", nil, x)
        local size = ns.PlateDesign().auraSize
        b:SetSize(size, size)
        b:SetPoint("BOTTOMLEFT", x.auraRow, "BOTTOMLEFT", (i - 1) * (size + 3), 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if ok and cd then
            cd:SetAllPoints()
            if cd.SetReverse then cd:SetReverse(true) end
            if cd.SetDrawEdge then cd:SetDrawEdge(false) end
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
            b.cd = cd
        end
        ns:AddBorder(b, 0, 0, 0, 1)
        x.auras[i] = b
        return b
    end

    local function PlateAuras(x)
        local n = 0
        if getAura and x.unit and not ns.aurasLocked then       -- locked clients keep the game's own nameplate debuffs
            local pd = ns.PlateDesign()
            local most = pd.auraMax
            local filter = (pd.auraMine ~= false) and "HARMFUL|PLAYER" or "HARMFUL"      -- only the debuffs you applied, unless the designer says all
            for i = 1, 20 do
                if n >= most then break end
                local a = getAura(x.unit, i, filter)
                if not a then break end
                if ns.AuraBlocked and ns.AuraBlocked(a.name) then a = nil end
                if a then
                n = n + 1
                local b = x.auras[n] or AuraIcon(x, n)
                pcall(b.icon.SetTexture, b.icon, a.icon)
                if b.cd then
                    local shown = false
                    if b.cd.SetCooldownFromExpirationTime then
                        shown = pcall(b.cd.SetCooldownFromExpirationTime, b.cd, a.expirationTime, a.duration)
                    end
                    if not shown then shown = pcall(function() b.cd:SetCooldown(a.expirationTime - a.duration, a.duration) end) end
                    if shown then b.cd:Show() else b.cd:Hide() end
                end
                b:Show()
                end
            end
        end
        for i = n + 1, #x.auras do x.auras[i]:Hide() end
    end
    function ns:RefreshPlateAuras()
        local n = 0
        for _, x in pairs(extras) do if x.unit then pcall(PlateAuras, x); n = n + 1 end end
        return n
    end

    local function GetExtra(plate, uf)
        local x = extras[plate]
        if x then return x end
        local hb = HealthBar(uf)
        if not hb then return nil end
        x = CreateFrame("Frame", nil, plate)
        x:SetAllPoints(hb)
        x.auras = {}

        local bar = ns:NewStatusBar(x, true)
        bar:SetHeight(ns.PlateDesign().castHeight)
        bar:SetPoint("TOPLEFT", hb, "BOTTOMLEFT", 0, -4)
        bar:SetPoint("TOPRIGHT", hb, "BOTTOMRIGHT", 0, -4)
        bar.lock = bar:CreateTexture(nil, "ARTWORK", nil, 3)
        bar.lock:SetAllPoints()
        bar.lock:SetTexture(ns.FLAT)
        bar.lock:SetVertexColor(0.45, 0.45, 0.5, 1)
        bar.lock:SetAlpha(0)
        bar.icon = bar:CreateTexture(nil, "ARTWORK")
        bar.icon:SetSize(12, 12)
        bar.icon:SetPoint("RIGHT", bar, "LEFT", -2, 0)
        bar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        bar.text = ns:NewText(bar, ns.PlateDesign().castTextSize, "CENTER")
        bar.text:SetPoint("TOP", bar, "BOTTOM", 0, -1)
        local iconMask                                         -- the frame style: cut, its icon a small diamond
        bar.scAlso = { bar.lock }
        bar.scOnStyle = function(self, on)
            if on and not iconMask then iconMask = ns.StarcutMask(self, "diamond", self.icon, 0) end
            ns.StarcutMasked(self.icon, iconMask, on)
            self.icon:SetSize(on and 15 or 12, on and 15 or 12)
        end
        ns:StarcutStyleBar(bar, false)
        bar:Hide()
        bar:SetScript("OnUpdate", ns:Guard("Nameplate casts", function(self)
            if not self.active then return end
            local now = GetTime()
            self:SetValue(now * 1000)
            if self.endsAt and now > self.endsAt + 0.3 then self.active = false; self:Hide() end
        end))
        x.cast = bar

        x.auraRow = CreateFrame("Frame", nil, x)
        x.auraRow:SetSize(105, 18)
        x.auraRow:SetPoint("BOTTOMLEFT", hb, "TOPLEFT", 0, ns.PlateAuraLift())

        x:SetScript("OnEvent", ns:Guard("Nameplate extras", function(self, event)
            if event == "UNIT_AURA" then PlateAuras(self) else PlateCast(self) end
        end))
        extras[plate] = x
        return x
    end

    -- Nameplate size: width and height as a percentage of the game's own (Layout tab). The game sizes
    -- its nameplates through two settings of its own; these sliders set those. They are only touched
    -- once you have moved a slider, and cannot be changed during combat (the change waits).
    local SIZE_CVARS = { w = "NamePlateHorizontalScale", h = "NamePlateVerticalScale" }
    local function HasCVar(name)
        if C_CVar and C_CVar.GetCVar then
            local ok, v = pcall(C_CVar.GetCVar, name)
            return ok and v ~= nil
        end
        if GetCVar then
            local ok, v = pcall(GetCVar, name)
            return ok and v ~= nil
        end
        return false
    end
    ns.plateSizeSupport = (HasCVar(SIZE_CVARS.w) and HasCVar(SIZE_CVARS.h)) and "the game's nameplate scale settings" or nil
    local sizePending = false
    function ns:ApplyNameplateSize()
        if not ns.plateSizeSupport or not ns.db.plateSized then return false end
        if InCombatLockdown() then sizePending = true; return false end
        sizePending = false
        local w = math.max(60, math.min(180, tonumber(ns.db.plateW) or 100)) / 100
        local h = math.max(60, math.min(270, tonumber(ns.db.plateH) or 100)) / 100
        local set = (C_CVar and C_CVar.SetCVar) or SetCVar
        local okW = pcall(set, SIZE_CVARS.w, tostring(w))
        local okH = pcall(set, SIZE_CVARS.h, tostring(h))
        return okW and okH
    end
    function ns:NameplateSizeChanged() ns.db.plateSized = true; return ns:ApplyNameplateSize() end
    do
        local sizer = CreateFrame("Frame")
        sizer:RegisterEvent("PLAYER_REGEN_ENABLED")
        sizer:RegisterEvent("PLAYER_ENTERING_WORLD")
        sizer:SetScript("OnEvent", ns:Guard("Nameplates events", function(_, event)
            if event == "PLAYER_ENTERING_WORLD" or sizePending then pcall(ns.ApplyNameplateSize, ns) end
        end))
    end

    -- Health text on the plate's bar: a percentage, or the amount when "Health as numbers" is on (the
    -- same choice the unit frames follow). It has its own small frame on each plate, so it works
    -- whether or not casts and debuffs on plates are switched on, and on friendly plates too.
    local healthTexts = setmetatable({}, { __mode = "k" })
    local function WriteHealth(h)
        if not h.suiUnit or not ns.db.plateHealth then h.text:SetText(""); return end
        local ok, gone = pcall(function() return UnitIsDeadOrGhost(h.suiUnit) end)
        if ok and ns.Is(gone, true) then h.text:SetText(""); return end
        if ns.SetHealthText then ns.SetHealthText(h.text, h.suiUnit) end
    end
    -- Resource percentage beside the bar, for units that have a resource (most beasts have none). Whether
    -- a unit has one can only be told while its amounts are readable. A plate that first appears in
    -- the middle of a fight, when they are hidden, is left blank: showing "0%" on every creature that
    -- has no mana at all would be worse than showing nothing.
    local function WritePower(h)
        local fs, unit = h.power, h.suiUnit
        if not unit or not ns.db.powerText or not ns.SetPowerPct then fs:SetText(""); return end
        local ok, max = pcall(UnitPowerMax, unit)
        if ok and not ns:IsSecret(max) then
            h.suiHasPower = (type(max) == "number" and max > 0)
        elseif h.suiHasPower == nil then
            -- The maximum is hidden, so it can't be asked directly. What can be told: players always
            -- have a resource, and among creatures it is the spell-casting kinds that carry mana.
            local okP, isPlayer = pcall(UnitIsPlayer, unit)
            local okC, _, class = pcall(UnitClass, unit)
            if okP and ns.Is(isPlayer, true) then
                h.suiHasPower = true
            elseif okC and not ns:IsSecret(class) then
                h.suiHasPower = (class == "MAGE" or class == "PALADIN")
            end
            -- (if the game hides the class as well, nothing is decided: it is asked again next time)
        end
        if not h.suiHasPower then fs:SetText(""); return end
        ns.SetPowerPct(fs, unit)
        fs:SetTextColor(ns:PowerTextColor(unit))
    end

    -- where the health text sits on a plate's bar, and how big
    function ns.PlaceHealthText(h)
        local pd = ns.PlateDesign()
        ns:Font(h.text, pd.healthSize)
        h.text:ClearAllPoints()
        h.text:SetAlpha(pd.healthPos == "OFF" and 0 or 1)
        if pd.healthPos == "LEFT" then h.text:SetPoint("LEFT", h, "LEFT", 3, 0); h.text:SetJustifyH("LEFT")
        elseif pd.healthPos == "RIGHT" then h.text:SetPoint("RIGHT", h, "RIGHT", -3, 0); h.text:SetJustifyH("RIGHT")
        else h.text:SetPoint("CENTER", h, "CENTER", 0, 0); h.text:SetJustifyH("CENTER") end
    end
    -- Quest mobs (11.15): a small mark at the left of the plate of a mob you still need for a quest,
    -- with how many are left. Read from the unit's tooltip, where the game lists the objectives it
    -- counts toward ("Defias Thug slain: 3/8"); where the game hides those lines, nothing is shown.
    local questMarks = {}
    local scanTip
    local function TooltipLines(unit)
        local out = {}
        if C_TooltipInfo and C_TooltipInfo.GetUnit then
            local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
            if ok and type(data) == "table" and type(data.lines) == "table" then
                for _, l in ipairs(data.lines) do
                    if type(l) == "table" and type(l.leftText) == "string" and not ns:IsSecret(l.leftText) then out[#out + 1] = l.leftText end
                end
                return out
            end
        end
        if not scanTip then
            scanTip = CreateFrame("GameTooltip", "FantasyGlassUIQuestScan", nil, "GameTooltipTemplate")
        end
        if not (scanTip.SetOwner and scanTip.SetUnit) then return out end
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        if not pcall(scanTip.SetUnit, scanTip, unit) then return out end
        for i = 2, math.min(12, scanTip:NumLines() or 0) do
            local fs = _G["FantasyGlassUIQuestScanTextLeft" .. i]
            local t = fs and fs.GetText and fs:GetText()
            if type(t) == "string" and not ns:IsSecret(t) then out[#out + 1] = t end
        end
        scanTip:Hide()
        return out
    end
    -- How many are still needed, from the lines: "3/8" counts 5; a "40%" counts as 1 until it is done.
    function ns.PlateQuestLeft(lines)
        local left, any = 0, false
        for _, t in ipairs(lines or {}) do
            local have, need = t:match("(%d+)%s*/%s*(%d+)")
            have, need = tonumber(have), tonumber(need)
            if have and need and need > 0 and need <= 250 then
                any = true
                if have < need then left = left + (need - have) end
            else
                local pct = tonumber(t:match("(%d+)%%%s*$") or t:match("%((%d+)%%%)"))
                if pct and t:find("^%s*%-") then any = true; if pct < 100 then left = left + 1 end end
            end
        end
        return any and left or nil
    end
    local function PlateQuest(plate, uf, unit)
        if not Usable(plate) then return end
        local q = questMarks[plate]
        if not unit or not ns.PlateDesign().questMarks then if q then q:Hide() end return end
        local okA, attackable = pcall(UnitCanAttack, "player", unit)
        local okP, isPlayer = pcall(UnitIsPlayer, unit)
        if not (okA and attackable == true) or (okP and isPlayer == true) then if q then q:Hide() end return end
        local left = ns.PlateQuestLeft(TooltipLines(unit))
        if not left or left <= 0 then if q then q:Hide() end return end
        if not q then
            local hb = HealthBar(uf)
            if not hb then return end
            q = CreateFrame("Frame", nil, plate)
            q:SetSize(30, 14)
            q.suiBar = hb
            q:SetFrameLevel((hb:GetFrameLevel() or 1) + 4)
            q.icon = q:CreateTexture(nil, "OVERLAY")
            q.icon:SetSize(12, 12)
            q.icon:SetPoint("RIGHT")
            if not pcall(q.icon.SetAtlas, q.icon, "QuestNormal") then q.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon") end
            q.text = ns:NewText(q, 10, "RIGHT", true)
            q.text:SetPoint("RIGHT", q.icon, "LEFT", -1, 0)
            q.text:SetTextColor(1, 0.82, 0.25)
            if q.text.SetShadowOffset then q.text:SetShadowOffset(1, -1); q.text:SetShadowColor(0, 0, 0, 1) end
            questMarks[plate] = q
        end
        -- (13.0.1) out past the level and the quest "!" (QuestMarks.lua), so the three stand side by side
        q:ClearAllPoints()
        q:SetPoint("RIGHT", q.suiBar, "LEFT", -(ns.PlateLevelSlot() + 16), 0)
        q.text:SetText(tostring(left))
        q.left = left
        q:Show()
    end
    ns.plateQuestTest = { PlateQuest = PlateQuest, marks = questMarks }
    local questDirty = false
    local qev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_WATCH_UPDATE" }) do pcall(qev.RegisterEvent, qev, e) end
    qev:SetScript("OnEvent", function() questDirty = true end)
    ns:Every(0.5, "Nameplate quest mobs", function()          -- (the log changes in bursts: one look after them)
        if not questDirty or not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
        questDirty = false
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local uf = plate.UnitFrame
            local unit = uf and (rawget(uf, "unit") or uf.unit)
            if type(unit) == "string" and not ns:IsSecret(unit) then pcall(PlateQuest, plate, uf, unit) end
        end
    end)

    local function PlateHealth(plate, uf, unit)
        if not Usable(plate) then return end
        local h = healthTexts[plate]
        if not h then
            local hb = HealthBar(uf)
            if not hb then return end
            h = CreateFrame("Frame", nil, plate)
            h:SetAllPoints(hb)
            h:SetFrameLevel((hb:GetFrameLevel() or 1) + 4)
            h.text = ns:NewText(h, 9, "CENTER")
            h.text:SetPoint("CENTER", h, "CENTER", 0, 0)
            h.suiPlaced = nil
            h.text:SetTextColor(1, 1, 1)
            if h.text.SetShadowOffset then h.text:SetShadowOffset(1, -1); h.text:SetShadowColor(0, 0, 0, 1) end
            h.power = ns:NewText(h, 8, "LEFT")               -- just outside the bar's right end
            h.power:SetPoint("LEFT", h, "RIGHT", 3, 0)
            if h.power.SetShadowOffset then h.power:SetShadowOffset(1, -1); h.power:SetShadowColor(0, 0, 0, 1) end
            h:SetScript("OnEvent", ns:Guard("Nameplate health", function(self, event)
                if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then WriteHealth(self) else WritePower(self) end
            end))
            healthTexts[plate] = h
        end
        if not h.suiPlaced then ns.PlaceHealthText(h); h.suiPlaced = true end
        h:UnregisterAllEvents()
        h.suiUnit = unit
        h.suiHasPower = nil                                  -- a plate is reused for different units: learn afresh
        if unit then
            for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
                pcall(h.RegisterUnitEvent, h, e, unit)
            end
            h:Show()
        else
            h:Hide()
        end
        WriteHealth(h)
        WritePower(h)
        return h
    end
    ns.PlateHealth = PlateHealth

    -- (13.0.1) The name over an enemy's or a neutral unit's bar, in the designer's name size, whenever
    -- its plate is up (the game shows a plate once you are near). The game's own name could not do it:
    -- in its Modern and Block styles the name sits inside the bar, under ours, and its "NPC names"
    -- setting hides it (in the Classic preset, until you target the unit). The name may be hidden from
    -- add-ons in a fight: it is then handed to the game to draw, never looked at.
    local plateNames = setmetatable({}, { __mode = "k" })
    local function WriteName(n)
        local fs, unit = n.text, n.suiUnit
        if not unit or not ns.PlateDesign().nameShow then fs:SetText(""); fs:Hide(); return end
        local ok, name = pcall(UnitName, unit)
        if ok and Secret(name) then fs:SetText(name)
        elseif ok and type(name) == "string" then fs:SetText(name)
        else fs:SetText("") end
        fs:Show()
    end
    local function PlaceName(n)
        local pd = ns.PlateDesign()
        local gap = ns.PlateNameGap()
        ns:Font(n.text, pd.nameSize)
        n.text:ClearAllPoints()
        n.text:SetPoint("BOTTOMLEFT", n, "TOPLEFT", 0, gap)       -- (as wide as the bar: a long name is cut short)
        n.text:SetPoint("BOTTOMRIGHT", n, "TOPRIGHT", 0, gap)
    end
    local function PlateName(plate, uf, unit)
        if not Usable(plate) then return end
        local foe = unit ~= nil and Foe(unit)
        if Usable(uf) then uf.suiFoe = foe or nil; GameName(uf) end
        local n = plateNames[plate]
        if not n then
            if not foe then return end
            local hb = HealthBar(uf)
            if not hb then return end
            n = CreateFrame("Frame", nil, plate)
            n:SetAllPoints(hb)
            n:SetFrameLevel((hb:GetFrameLevel() or 1) + 4)
            n.text = ns:NewText(n, ns.PlateDesign().nameSize, "CENTER")
            n.text:SetTextColor(1, 1, 1)
            n:SetScript("OnEvent", ns:Guard("Nameplate names", function(self) WriteName(self) end))
            plateNames[plate] = n
        end
        PlaceName(n)
        if n.text.SetShadowOffset then n.text:SetShadowOffset(1, -1); n.text:SetShadowColor(0, 0, 0, 1) end
        n:UnregisterAllEvents()
        n.suiUnit = foe and unit or nil
        if n.suiUnit then
            pcall(n.RegisterUnitEvent, n, "UNIT_NAME_UPDATE", unit)
            n:Show()
        else
            n:Hide()
        end
        WriteName(n)
        return n
    end
    ns.PlateName = PlateName

    function ns:RefreshPlateHealth()                        -- the option changed: rewrite every plate showing
        for _, h in pairs(healthTexts) do pcall(WriteHealth, h); pcall(WritePower, h) end
    end
    -- the designer's changes, on every plate there is (new plates take them as they are made)
    function ns:ApplyPlateDesign()
        local pd = ns.PlateDesign()
        local n = 0
        for _, h in pairs(healthTexts) do ns.PlaceHealthText(h); n = n + 1 end
        for _, nm in pairs(plateNames) do PlaceName(nm); WriteName(nm) end
        for _, x in pairs(extras) do
            x.cast:SetHeight(pd.castHeight)
            ns:Font(x.cast.text, pd.castTextSize)
            x.auraRow:ClearAllPoints()
            x.auraRow:SetPoint("BOTTOMLEFT", x, "TOPLEFT", 0, ns.PlateAuraLift())
            for i, b in ipairs(x.auras) do
                b:SetSize(pd.auraSize, pd.auraSize)
                b:ClearAllPoints()
                b:SetPoint("BOTTOMLEFT", x.auraRow, "BOTTOMLEFT", (i - 1) * (pd.auraSize + 3), 0)
                if i > pd.auraMax then b:Hide() end
            end
        end
        for uf in pairs(plates) do
            if Usable(uf) and uf.name and uf.name.SetFont then
                ns:Font(uf.name, pd.nameSize)
                GameName(uf)
            end
            local lv = Usable(uf) and rawget(uf, "suiLevel")
            if lv then ns:Font(lv, pd.nameSize, true) end
            plates[uf] = "again"                             -- (selection looked at afresh; kept in the list so it is still watched)
        end
        if ns.RefreshPlateAuras then pcall(ns.RefreshPlateAuras, ns) end     -- (more or fewer debuffs allowed: shown at once)
        ns.plateDesignApplied = n
        return n
    end

    local CAST_EVENTS = { "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
                          "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
                          "UNIT_SPELLCAST_CHANNEL_UPDATE" }

    local function Attach(plate, uf, unit)
        if not Usable(plate) then return end
        local x = GetExtra(plate, uf)
        if not x then return end
        x:UnregisterAllEvents()
        if UnitCanAttack("player", unit) then
            x.unit = unit
            for _, e in ipairs(CAST_EVENTS) do pcall(x.RegisterUnitEvent, x, e, unit) end
            pcall(x.RegisterUnitEvent, x, "UNIT_AURA", unit)
            x:Show()
            PlateCast(x)
            PlateAuras(x)
        else
            x.unit = nil
            x:Hide()
        end
    end

    local function Detach(plate)
        local x = plate and extras[plate]
        if not x then return end
        x:UnregisterAllEvents()
        x.unit = nil
        x.cast.active = false
        x.cast:Hide()
        for _, b in ipairs(x.auras) do b:Hide() end
    end

    if CompactUnitFrame_UpdateHealthColor then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ns:Guard("Nameplates", Color))
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    f:SetScript("OnEvent", ns:Guard("Nameplates", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            local uf = plate and plate.UnitFrame
            if uf then
                if Usable(uf) then uf.suiFoe = Foe(unit) or nil end     -- (first: the name and the level go by it)
                Skin(uf); Color(uf)
                pcall(PlateLevel, uf, unit)
                if extrasOn then Attach(plate, uf, unit) end
                PlateHealth(plate, uf, unit)
                pcall(PlateName, plate, uf, unit)
                pcall(PlateQuest, plate, uf, unit)
            end
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            Detach(plate)
            if plate and healthTexts[plate] then PlateHealth(plate, plate.UnitFrame, nil) end
            if plate and plateNames[plate] then pcall(PlateName, plate, plate.UnitFrame, nil) end
            if plate and questMarks[plate] then questMarks[plate]:Hide() end
        elseif C_NamePlate.GetNamePlates then
            for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                if plate.UnitFrame then Color(plate.UnitFrame) end
            end
        end
    end))
    -- which plate is your target: at once when you change target, and three times a second as well
    -- (for the moments the game moves a plate to another unit without saying so)
    local function Selection()
        for uf in pairs(plates) do
            if Usable(uf) and uf.IsVisible and uf:IsVisible() then pcall(ShowSelection, uf) end
        end
    end
    local sel = CreateFrame("Frame")
    sel:RegisterEvent("PLAYER_TARGET_CHANGED")
    sel:SetScript("OnEvent", ns:Guard("Nameplates events", function() Selection() end))
    ns:Every(0.3, "Nameplate selection", function()
        for uf in pairs(plates) do
            if Usable(uf) and uf.IsVisible and uf:IsVisible() then pcall(ShowSelection, uf) end
        end
    end)
end)
