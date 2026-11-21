local _, ns = ...

------------------------------------------------------------------------------------------
-- Our own action bars (11.0). Eight bars of real, secure action buttons made by this add-on, in
-- place of the game's: each with its own number of buttons, rows, button size, spacing and direction,
-- set at once without the game's Edit Mode. Bar 1 changes page with your stance or form, stealth,
-- a vehicle or a possess, as the game's main bar does. The game's key bindings (Action Button 1,
-- Bottom Left Action Bar 1 ...) press our buttons. Everything else a bar has on the Bars tab (when it
-- shows, size, opacity, key text, macro names) works on these too.
-- Off until chosen ("Fantasy Glass action bars", Features tab); a /reload to switch either way.
------------------------------------------------------------------------------------------
ns.ENGINE_BARS = {
    -- page of action slots, the game binding its buttons answer to, label
    { page = 1,  bind = "ACTIONBUTTON",           label = "Bar 1" },
    { page = 6,  bind = "MULTIACTIONBAR1BUTTON",  label = "Bar 2" },
    { page = 5,  bind = "MULTIACTIONBAR2BUTTON",  label = "Bar 3" },
    { page = 3,  bind = "MULTIACTIONBAR3BUTTON",  label = "Bar 4" },
    { page = 4,  bind = "MULTIACTIONBAR4BUTTON",  label = "Bar 5" },
    { page = 13, bind = "MULTIACTIONBAR5BUTTON",  label = "Bar 6" },
    { page = 14, bind = "MULTIACTIONBAR6BUTTON",  label = "Bar 7" },
    { page = 15, bind = "MULTIACTIONBAR7BUTTON",  label = "Bar 8" },
}
-- Bar 1's page, chosen by the game's own macro conditions (the order matters: the first that fits wins).
ns.ENGINE_PAGING = "[vehicleui] 12; [possessbar] 12; [overridebar] 14; [shapeshift] 13; [bonusbar:5] 11; "
    .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; "
    .. "[bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; 1"
ns.ENGINE_DEFAULT = { buttons = 12, rows = 1, size = 38, padding = 4, vertical = 0 }
-- where each bar starts, before it is moved: three across the bottom, two up the right
local HOME = {
    { "BOTTOM", 0, 40 }, { "BOTTOM", 0, 84 }, { "BOTTOM", 0, 128 },
    { "RIGHT", -6, 0 }, { "RIGHT", -50, 0 }, { "BOTTOM", 0, 172 }, { "BOTTOM", 0, 216 }, { "BOTTOM", 0, 260 },
}

-- A bar's own layout: what it has saved, filled in from the defaults and kept in bounds.
function ns.EngineSettings(saved)
    local d = ns.ENGINE_DEFAULT
    saved = type(saved) == "table" and saved or {}
    local function n(v, lo, hi, def) v = tonumber(v) or def; return math.max(lo, math.min(hi, math.floor(v + 0.5))) end
    local out = {
        buttons = n(saved.buttons, 1, 12, d.buttons),
        rows = n(saved.rows, 1, 12, d.rows),
        size = n(saved.size, 20, 72, d.size),
        padding = n(saved.padding, 0, 20, d.padding),
        vertical = (tonumber(saved.vertical) == 1) and 1 or 0,
    }
    out.rows = math.min(out.rows, out.buttons)
    return out
end
-- Where button i sits (offsets from the bar's top left) and the bar's whole size.
function ns.EngineGrid(s, i)
    local perLine = math.ceil(s.buttons / s.rows)
    local line, pos = math.floor((i - 1) / perLine), (i - 1) % perLine
    local col, row = pos, line
    if s.vertical == 1 then col, row = line, pos end
    local step = s.size + s.padding
    local cols = (s.vertical == 1) and s.rows or perLine
    local rows = (s.vertical == 1) and perLine or s.rows
    return col * step, -row * step, cols * step - s.padding, rows * step - s.padding
end

local engine = {}
ns.engine = engine
-- Is this bar in use? All eight are on until one is switched off on the Bars and frames tab. A bar that
-- is off is hidden altogether; its keys still press its buttons, so a bar of keys only is possible.
function ns:EngineBarOn(k)
    local saved = type(ns.db.engineBars) == "table" and ns.db.engineBars[k]
    return not (type(saved) == "table" and saved.off)
end
function engine.Visible(bar)
    if InCombatLockdown() then engine.pending = true; return false end
    local on = ns:EngineBarOn(bar.index)
    RegisterStateDriver(bar, "visibility", on and (bar.baseVis or "show") or "hide")
    bar.suiOn = on
    return on
end
function ns:SetEngineBarOn(k, on)
    if type(ns.db.engineBars) ~= "table" then ns.db.engineBars = {} end
    if type(ns.db.engineBars[k]) ~= "table" then ns.db.engineBars[k] = {} end
    ns.db.engineBars[k].off = (not on) or nil
    local bar = engine.bars and engine.bars[k]
    if bar then engine.Visible(bar) end
    return on
end
-- The forms the game lists now: { { icon, active, castable, spellID } ... }.
function ns.StanceForms()
    local out = {}
    if type(GetNumShapeshiftForms) ~= "function" or type(GetShapeshiftFormInfo) ~= "function" then return out end
    local okN, n = pcall(GetNumShapeshiftForms)
    for i = 1, math.min(10, (okN and tonumber(n)) or 0) do
        local ok, icon, active, castable, spellID = pcall(GetShapeshiftFormInfo, i)
        if ok then out[#out + 1] = { icon = icon, active = active, castable = castable, spellID = spellID } end
    end
    return out
end
function engine.BuildStance()
    if engine.stance or type(GetNumShapeshiftForms) ~= "function" then return end
    local game = _G.StanceBar
    if game then ns:Silence(game) end
    for i = #ns.barHandles, 1, -1 do if ns.barHandles[i].key == "bar_StanceBar" then table.remove(ns.barHandles, i) end end
    local SIZE = 32
    local st = CreateFrame("Frame", "FantasyGlassUIStance", UIParent, "SecureHandlerStateTemplate")
    st:SetSize(SIZE, SIZE)
    st:SetPoint("BOTTOM", UIParent, "BOTTOM", -200, 304)
    st.buttons = {}
    for i = 1, 10 do
        local b = CreateFrame("Button", "FantasyGlassUIStanceButton" .. i, st, "SecureActionButtonTemplate")
        b:SetSize(SIZE, SIZE)
        b:SetPoint("LEFT", (i - 1) * (SIZE + 4), 0)
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type", "spell")
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local okC, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if okC and cd then cd:SetAllPoints(); b.cd = cd end
        ns:AddBorder(b, 0, 0, 0, 1)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetAllPoints(); b.hl:SetTexture(ns.FLAT); b.hl:SetVertexColor(1, 1, 1, 0.2)
        b:SetScript("OnEnter", function(self)
            if not self.spellID then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if GameTooltip.SetSpellByID then pcall(GameTooltip.SetSpellByID, GameTooltip, self.spellID) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        st.buttons[i] = b
    end
    -- what each button shows (any time) and casts (out of a fight)
    local function Draw()
        local forms = ns.StanceForms()
        for i, b in ipairs(st.buttons) do
            local f = forms[i]
            if f then
                pcall(b.icon.SetTexture, b.icon, f.icon)
                local active = f.active and not ns:IsSecret(f.active)
                if b.suiBorder then
                    if active then ns:Paint(b.suiBorder, "SetBackdropBorderColor", "@accent", 1) else ns:Paint(b.suiBorder, "SetBackdropBorderColor", "@border", 1) end
                end
                b.icon:SetDesaturated((f.castable == false) and true or false)
                if b.cd and GetShapeshiftFormCooldown then
                    local ok, start, dur = pcall(GetShapeshiftFormCooldown, i)
                    if ok then pcall(b.cd.SetCooldown, b.cd, start, dur) end
                end
            end
        end
        return #forms
    end
    function st.Refresh()
        if InCombatLockdown() then st.pending = true; Draw(); return false end
        st.pending = nil
        local forms = ns.StanceForms()
        for i, b in ipairs(st.buttons) do
            local f = forms[i]
            if f and f.spellID and not ns:IsSecret(f.spellID) then
                b.spellID = f.spellID
                b:SetAttribute("spell", f.spellID)
                b:Show()
            else
                b.spellID = nil
                b:SetAttribute("spell", nil)
                b:Hide()
            end
        end
        st:SetWidth(math.max(1, #forms) * (SIZE + 4) - 4)
        Draw()
        return #forms
    end
    st.Draw = Draw
    engine.stance = st
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_COOLDOWN", "UPDATE_SHAPESHIFT_USABLE", "SPELLS_CHANGED" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", ns:Guard("Stance bar", function(_, event)
        if event == "UPDATE_SHAPESHIFT_FORMS" or event == "SPELLS_CHANGED" then st.Refresh() else Draw() end
    end))
    RegisterStateDriver(st, "visibility", "[petbattle][vehicleui][overridebar] hide; show")
    local entry = ns:RegisterMovable(st, "fgstance", "Stance bar")
    if type(entry) == "table" then entry.fadeKey = "fgstance"; entry.noScale = "Sized with the action bars." end
    table.insert(ns.barHandles, math.min(#engine.bars + 1, #ns.barHandles + 1), { key = "fgstance", bar = st, holder = st, entry = entry, label = "Stance bar", layout = false })
    st.Refresh()
end
-- Our buttons: what each shows, kept up to date here (the template gives only the look).
engine.all = {}
local function ActionOf(b)
    local a = b:GetAttribute("action")
    if type(a) ~= "number" then a = b.suiAction end
    return a
end
engine.ActionOf = ActionOf
-- (one of each handler, shared by every button)
local function ButtonEnter(self)
    local a = ActionOf(self)
    if not a then return end
    if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self) else GameTooltip:SetOwner(self, "ANCHOR_RIGHT") end
    if pcall(GameTooltip.SetAction, GameTooltip, a) then GameTooltip:Show() end
end
local function ButtonLeave() GameTooltip:Hide() end
local function ButtonDragStart(self)                         -- (not in a fight)
    if InCombatLockdown() then return end
    local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local okL, locked = pcall(Get, "lockActionBars")
    if okL and locked == "1" and not (IsModifiedClick and IsModifiedClick("PICKUPACTION")) then return end
    local a = ActionOf(self)
    if a and PickupAction then pcall(PickupAction, a); pcall(engine.UpdateButton, self) end
end
local function ButtonReceiveDrag(self)
    if InCombatLockdown() then return end
    local a = ActionOf(self)
    if a and PlaceAction then pcall(PlaceAction, a); pcall(engine.UpdateButton, self) end
end
function engine.Dress(b)
    b.icon = b.icon or b.Icon or _G[(b:GetName() or "") .. "Icon"]
    if not b.icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
    end
    b.Count = b.Count or _G[(b:GetName() or "") .. "Count"]
    if not b.Count then b.Count = ns:NewText(b, 12, "RIGHT"); b.Count:SetPoint("BOTTOMRIGHT", -2, 2) end
    b.HotKey = b.HotKey or _G[(b:GetName() or "") .. "HotKey"]
    if not b.HotKey then b.HotKey = ns:NewText(b, 11, "RIGHT"); b.HotKey:SetPoint("TOPRIGHT", -2, -3) end
    b.Name = b.Name or _G[(b:GetName() or "") .. "Name"]
    if not b.Name then b.Name = ns:NewText(b, 10, "CENTER"); b.Name:SetPoint("BOTTOM", 0, 2) end
    if not b.suiLit then                                     -- lit while it is the current or repeating action
        b.suiLit = b:CreateTexture(nil, "OVERLAY")
        b.suiLit:SetAllPoints()
        b.suiLit:SetTexture(ns.FLAT)
        b.suiLit:SetVertexColor(1, 0.82, 0.4, 0.35)
        b.suiLit:Hide()
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetTexture(ns.FLAT); hl:SetVertexColor(1, 1, 1, 0.2)
        local pushed = b:CreateTexture(nil, "OVERLAY")
        pushed:SetAllPoints(); pushed:SetTexture(ns.FLAT); pushed:SetVertexColor(1, 0.85, 0.2, 0.3)
        if b.SetPushedTexture then pcall(b.SetPushedTexture, b, pushed) end
    end
    b.cooldown = b.cooldown or _G[(b:GetName() or "") .. "Cooldown"]
    if not b.cooldown then
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, b, "CooldownFrameTemplate")
        if ok and cd then cd:SetAllPoints(); b.cooldown = cd end
    end
    if b.RegisterForDrag then b:RegisterForDrag("LeftButton", "RightButton") end
    b:SetScript("OnEnter", ButtonEnter)
    b:SetScript("OnLeave", ButtonLeave)
    b:SetScript("OnDragStart", ButtonDragStart)               -- dragging abilities on and off, as on the game's bars
    b:SetScript("OnReceiveDrag", ButtonReceiveDrag)
end
local function Num(v) return type(v) == "number" and not ns:IsSecret(v) and v or nil end
-- What changes without any event: usable (dimmed when not, blue when short of mana), in range (red
-- when not), and lit while it is the current or repeating action. The timer checks only this; the
-- icon, count, name and cooldown come with events (and a full look once a second besides).
local function ApplyState(b, a)
    local okU, usable, noMana = pcall(IsUsableAction, a)
    local okR, inRange = pcall(IsActionInRange, a)
    if okR and inRange == false and not ns:IsSecret(inRange) then b.icon:SetVertexColor(0.85, 0.25, 0.25)
    elseif okU and not ns:IsSecret(usable) and usable then b.icon:SetVertexColor(1, 1, 1)
    elseif okU and not ns:IsSecret(noMana) and noMana then b.icon:SetVertexColor(0.35, 0.45, 1)
    elseif okU and not ns:IsSecret(usable) then b.icon:SetVertexColor(0.4, 0.4, 0.4)
    else b.icon:SetVertexColor(1, 1, 1) end
    local cur = (IsCurrentAction and IsCurrentAction(a)) or (IsAutoRepeatAction and IsAutoRepeatAction(a))
    if b.suiLit and not ns:IsSecret(cur) then b.suiLit:SetShown(cur and true or false) end
end
function engine.UpdateState(b)
    local a = b.suiHas and ActionOf(b)
    if a then ApplyState(b, a) end
end
function engine.UpdateButton(b)
    local a = ActionOf(b)
    if not a then return end
    local has = HasAction and HasAction(a)
    if ns:IsSecret(has) then has = true end
    if has then
        local ok, tex = pcall(GetActionTexture, a)
        b.icon:SetTexture(ok and tex or nil)
        b.icon:Show()
        b.icon:SetAlpha(1)
        -- count (consumables, stacks), macro name
        local text = ""
        if (IsConsumableAction and ns.Yes(IsConsumableAction(a))) or (IsStackableAction and ns.Yes(IsStackableAction(a))) then
            local okC, n = pcall(GetActionCount, a)
            n = okC and Num(n)
            text = n and ((n > 9999) and "*" or tostring(n)) or ""
        end
        b.Count:SetText(text)
        if b.Name and GetActionText then
            local okN, nm = pcall(GetActionText, a)
            b.Name:SetText((okN and type(nm) == "string" and not ns:IsSecret(nm)) and nm or "")
        end
        -- cooldown (the game's own figures, whether or not they can be read)
        if b.cooldown then
            local start, dur, enable   -- luacheck: ignore
            if C_ActionBar and C_ActionBar.GetActionCooldown then
                local okI, info = pcall(C_ActionBar.GetActionCooldown, a)
                if okI and type(info) == "table" then start, dur, enable = info.startTime, info.duration, info.isEnabled end
            elseif GetActionCooldown then
                local okI, s, d, e = pcall(GetActionCooldown, a)
                if okI then start, dur, enable = s, d, e end
            end
            if start ~= nil and dur ~= nil then pcall(b.cooldown.SetCooldown, b.cooldown, start, dur) else pcall(b.cooldown.Clear, b.cooldown) end
        end
        ApplyState(b, a)
    else
        b.icon:SetTexture(nil)
        b.Count:SetText("")
        if b.Name then b.Name:SetText("") end
        if b.cooldown then pcall(b.cooldown.Clear, b.cooldown) end
        if b.suiLit then b.suiLit:Hide() end
    end
    b.suiHas = has and true or false
    return b.suiHas
end
-- the key a button answers to, shortened ("S-1", "M4")
function engine.UpdateHotkey(b)
    if not b.HotKey then return end
    local key = b.suiCommand and GetBindingKey(b.suiCommand)
    local text = ""
    if type(key) == "string" and key ~= "" then
        text = (GetBindingText and GetBindingText(key, "KEY_", true)) or key
    end
    b.HotKey:SetText(text)
    if ns.AbbrevHotkey then pcall(ns.AbbrevHotkey, b) end
end
-- (only the buttons on screen: a bar that is off or hidden by its visibility rules is brought up to
-- date the moment it shows)
local function UpdateAllButtons()
    for _, b in ipairs(engine.all) do
        if b:IsVisible() then pcall(engine.UpdateButton, b) end
    end
end
local function UpdateAllStates()
    for _, b in ipairs(engine.all) do
        if b.suiHas and b:IsVisible() then pcall(engine.UpdateState, b) end
    end
end
engine.UpdateAll = UpdateAllButtons
do
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_STATE", "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_COOLDOWN",
                         "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_CHARGES", "UPDATE_SHAPESHIFT_FORM", "PLAYER_TARGET_CHANGED",
                         "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS", "UNIT_INVENTORY_CHANGED", "LEARNED_SPELL_IN_TAB",
                         "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "UPDATE_MACROS", "MODIFIER_STATE_CHANGED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    local dirty, acc, ticks = true, 0, 0
    ev:SetScript("OnEvent", ns:Guard("BarEngine events", function(_, event, arg)
        if #engine.all == 0 then return end
        if event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
            for _, b in ipairs(engine.all) do pcall(engine.UpdateHotkey, b) end
        end
        if event == "ACTIONBAR_SLOT_CHANGED" and type(arg) == "number" and arg > 0 then
            for _, b in ipairs(engine.all) do if ActionOf(b) == arg then pcall(engine.UpdateButton, b) end end
            return
        end
        dirty = true
    end))
    -- (and a few times a second: range and usability change without any event. Everything else is
    -- looked at again only after an event, and once a second in case one never came.)
    ev:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < (dirty and 0.05 or 0.25) then return end
        acc, ticks = 0, ticks + 1
        if dirty or ticks >= 4 then
            dirty, ticks = false, 0
            UpdateAllButtons()
        else
            UpdateAllStates()
        end
    end)
    ev:Hide()                                                -- (until there are bars: see Bind)
    engine.events = ev
end
local function ButtonAttribute(self, attr)
    if attr == "action" then pcall(engine.UpdateButton, self) end
end
local function ButtonShown(self) pcall(engine.UpdateButton, self) end
local function Saved(k)
    if type(ns.db.engineBars) ~= "table" then ns.db.engineBars = {} end
    return ns.db.engineBars[k]
end
-- the button methods that set attributes, put off until a fight is over
ns.ENGINE_DEFER = { "UpdatePressAndHoldAction", "UpdatePingAttributes" }
local function Lay(bar)
    if InCombatLockdown() then engine.pending = true; return false end
    local s = ns.EngineSettings(Saved(bar.index))
    local w, h = 0, 0
    for i, b in ipairs(bar.buttons) do
        if i <= s.buttons then
            local x, y, bw, bh = ns.EngineGrid(s, i)
            w, h = bw, bh
            b:SetSize(s.size, s.size)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", bar, "TOPLEFT", x, y)
            b:Show()
            b:SetAttribute("statehidden", nil)
        else
            b:Hide()
            b:SetAttribute("statehidden", true)
        end
    end
    bar:SetSize(math.max(1, w), math.max(1, h))
    return true
end
engine.Lay = Lay

-- Our buttons answer to the game's key bindings: whatever key is set for "Action Button 3" presses
-- bar 1's third button. (Done again whenever bindings change; never in combat.)
local function Bind()
    if InCombatLockdown() then engine.bindPending = true; return false end
    engine.bindPending = nil
    local n = 0
    for _, bar in ipairs(engine.bars or {}) do
        ClearOverrideBindings(bar)
        for i, b in ipairs(bar.buttons) do
            local command = bar.def.bind .. i
            for _, key in ipairs({ GetBindingKey(command) }) do
                if type(key) == "string" and key ~= "" then
                    SetOverrideBindingClick(bar, false, key, b.suiName)
                    n = n + 1
                end
            end
        end
    end
    local st = engine.stance
    if st then
        ClearOverrideBindings(st)
        for i, b in ipairs(st.buttons) do
            for _, key in ipairs({ GetBindingKey("SHAPESHIFTBUTTON" .. i) }) do
                if type(key) == "string" and key ~= "" then SetOverrideBindingClick(st, false, key, b:GetName()); n = n + 1 end
            end
        end
    end
    engine.bound = n
    return n
end
engine.Bind = Bind

ns:NewModule("barEngine", function()
    if not ns.barHandles then ns.barEngineState = "needs \"Action bars\" switched on too"; return end
    engine.bars = {}
    -- the game's own bars step aside: unseen, unclickable, and out of the Bars tab's list
    local GAME = { "MainActionBar", "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft", "MultiBar5", "MultiBar6", "MultiBar7" }
    for _, name in ipairs(GAME) do
        local f = _G[name] or (name == "MainActionBar" and _G.MainMenuBar) or nil
        if f then ns:Silence(f) end
        for i = #ns.barHandles, 1, -1 do
            if ns.barHandles[i].key == "bar_" .. name then table.remove(ns.barHandles, i) end
        end
    end
    for k, def in ipairs(ns.ENGINE_BARS) do
        local name = "FantasyGlassUIBar" .. k
        local bar = CreateFrame("Frame", name, UIParent, "SecureHandlerStateTemplate")
        bar.index, bar.def, bar.suiEngine, bar.buttons = k, def, k, {}
        bar:SetPoint(HOME[k][1], UIParent, HOME[k][1], HOME[k][2], HOME[k][3])
        for i = 1, 12 do
            -- (11.4.3) The game's own action button template signs every button made from it into a list
            -- the game's bars share; a button an add-on made, in that list, left the game's stance bar
            -- "touched by an add-on" and refused in fights. So ours are made from the plain button look
            -- (ActionButtonTemplate) and kept up to date by the add-on itself (engine.UpdateButton).
            -- (11.4.4) a plain secure button, as the add-on's other working buttons are (the consumables bar,
            -- quick keys): the button look in 11.4.3 brought its own click handling, and clicks did nothing
            local b = CreateFrame("Button", name .. "Button" .. i, bar, "SecureActionButtonTemplate")
            engine.Dress(b)
            b:SetAttribute("type", "action")
            b:SetAttribute("action", (def.page - 1) * 12 + i)
            -- The game uses an ability on the key or button going down when "ActionButtonUseKeyDown" is
            -- on (it is, unless changed), and on it coming up when it is off. A button made from the
            -- template hears only the mouse coming up, so with the setting on nothing was ever used:
            -- it must hear both, as the game's own buttons do. (The game picks the one that counts.)
            b:RegisterForClicks("AnyUp", "AnyDown")
            b.suiClicks = "AnyUp AnyDown"
            -- The button's own code sets attributes whenever its ability changes or the mouse comes
            -- over it ("press and hold" spells, pings), which the game refuses during a fight for a
            -- button an add-on made - each time counting as a failed action. In a fight those are left
            -- until the fight is over. (Neither changes what a click or a key does.)
            b.suiPending = {}
            for _, method in ipairs(ns.ENGINE_DEFER) do
                if type(b[method]) == "function" then
                    local own = b[method]
                    b[method] = function(self, ...)
                        if InCombatLockdown() then self.suiPending[method] = true; return end
                        self.suiPending[method] = nil
                        return own(self, ...)
                    end
                end
            end
            b.suiAction = (def.page - 1) * 12 + i                -- (the action it starts with, for /fgui selftest)
            b.suiCommand = def.bind .. i                     -- (for keybind mode: which binding this button is)
            b.suiName = name .. "Button" .. i
            b.suiBarKey = "fgbar" .. k
            b:HookScript("OnAttributeChanged", ButtonAttribute)
            engine.all[#engine.all + 1] = b
            b:HookScript("OnShow", ButtonShown)
            bar:SetFrameRef("b" .. i, b)
            if ns.SkinActionButton then pcall(ns.SkinActionButton, b) end
            bar.buttons[i] = b
        end
        if k == 1 then                                       -- bar 1 follows stance, form, stealth and vehicles
            bar:SetAttribute("_onstate-page", [[
                local page = tonumber(newstate) or 1
                for i = 1, 12 do
                    local b = self:GetFrameRef("b" .. i)
                    if b then b:SetAttribute("action", (page - 1) * 12 + i) end
                end
            ]])
            RegisterStateDriver(bar, "page", ns.ENGINE_PAGING)
            bar.baseVis = "[petbattle] hide; show"
        else
            bar.baseVis = "[petbattle][vehicleui][overridebar] hide; show"
        end
        engine.Visible(bar)
        Lay(bar)
        local key = "fgbar" .. k
        local entry = ns:RegisterMovable(bar, key, def.label)
        if type(entry) == "table" then entry.fadeKey = key; entry.noScale = "Sized in Frames and bars › Action bars." end
        local info = { key = key, bar = bar, holder = bar, entry = entry, label = def.label, layout = true, engine = k }
        table.insert(ns.barHandles, math.min(k, #ns.barHandles + 1), info)       -- (before the stance and pet bars)
        engine.bars[k] = bar
    end
    if engine.events then engine.events:Show() end           -- (the bars' own timer runs from now on)
    -- (11.4.2) A stance bar of our own too: the game's, laid out by its own code, was refused in fights
    -- as long as the add-on had anything to do with it. Ours has a secure button for each form the
    -- game lists; the game's own is put out of sight like its other bars and otherwise left alone.
    pcall(engine.BuildStance)
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do ev:RegisterEvent(e) end
    ev:SetScript("OnEvent", ns:Guard("Fantasy Glass action bars", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if engine.pending then engine.pending = nil; for _, bar in ipairs(engine.bars) do engine.Visible(bar); Lay(bar) end end
            if engine.bindPending then Bind() end
            if engine.stance and engine.stance.pending then pcall(engine.stance.Refresh) end
            for _, bar in ipairs(engine.bars) do
                for _, b in ipairs(bar.buttons) do
                    for method in pairs(b.suiPending or {}) do if b[method] then pcall(b[method], b) end end
                end
            end
            return
        end
        Bind()
        if engine.stance then pcall(engine.stance.Refresh) end
        for _, b in ipairs(engine.all) do pcall(engine.UpdateHotkey, b) end
    end))
    Bind()
    -- size: the size for every bar (Layout tab) times the bar's own (Bars tab), as for the game's bars
    local function Scale()
        if InCombatLockdown() then return false end
        local all = math.max(70, math.min(140, tonumber(ns.db.barScale) or 100))
        for _, bar in ipairs(engine.bars) do
            local mine = math.max(50, math.min(150, tonumber(ns:BarSetting("fgbar" .. bar.index, "scale")) or 100))
            bar:SetScale(all / 100 * mine / 100)
        end
        return true
    end
    engine.Scale = Scale
    if ns.ApplyBarScale and hooksecurefunc then hooksecurefunc(ns, "ApplyBarScale", function() pcall(Scale) end) end
    Scale()
    ns.barEngineState = format("on: %d bars", #engine.bars)
end)

-- The Bars tab's "Rows and buttons" reads and writes these for our bars (see BarLayoutRead in
-- ActionBars.lua): rows, icons (buttons shown), size (button size %), padding, vertical.
function ns:EngineLayoutRead(bar)
    local s = ns.EngineSettings(Saved(bar.index))
    return { rows = s.rows, icons = s.buttons, size = math.floor(s.size / 38 * 100 + 0.5), padding = s.padding, vertical = s.vertical, sizeIsPercent = true }
end
function ns:EngineLayoutWrite(bar, values)
    if InCombatLockdown() then return nil, "Not during a fight." end
    if type(ns.db.engineBars) ~= "table" then ns.db.engineBars = {} end
    local s = ns.EngineSettings(Saved(bar.index))
    local before = format("%d %d %d %d %d", s.buttons, s.rows, s.size, s.padding, s.vertical)
    if values.rows then s.rows = tonumber(values.rows) end
    if values.icons then s.buttons = tonumber(values.icons) end
    if values.size then s.size = math.floor((tonumber(values.size) or 100) * 38 / 100 + 0.5) end
    if values.padding then s.padding = tonumber(values.padding) end
    if values.vertical then s.vertical = tonumber(values.vertical) end
    s = ns.EngineSettings(s)
    s.off = (type(ns.db.engineBars[bar.index]) == "table" and ns.db.engineBars[bar.index].off) or nil
    ns.db.engineBars[bar.index] = s
    Lay(bar)
    if before == format("%d %d %d %d %d", s.buttons, s.rows, s.size, s.padding, s.vertical) then return true, "nothing to change" end
    return true
end
