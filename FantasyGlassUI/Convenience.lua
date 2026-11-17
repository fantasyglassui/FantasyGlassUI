local _, ns = ...

------------------------------------------------------------------------------------------
-- Quick keybind mode (/fgui bind): hover an action button, press a key, done.
-- Backspace or Delete clears that button's keys; Escape finishes. Not available in combat (the game
-- doesn't allow key changes then), and it ends by itself if a fight starts.
------------------------------------------------------------------------------------------
do
    local COMMANDS = {
        ActionButton = "ACTIONBUTTON",
        MultiBarBottomLeftButton = "MULTIACTIONBAR1BUTTON", MultiBarBottomRightButton = "MULTIACTIONBAR2BUTTON",
        MultiBarRightButton = "MULTIACTIONBAR3BUTTON", MultiBarLeftButton = "MULTIACTIONBAR4BUTTON",
        MultiBar5Button = "MULTIACTIONBAR5BUTTON", MultiBar6Button = "MULTIACTIONBAR6BUTTON", MultiBar7Button = "MULTIACTIONBAR7BUTTON",
        PetActionButton = "BONUSACTIONBUTTON", StanceButton = "SHAPESHIFTBUTTON",
    }
    local IGNORE = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true, LMETA = true, RMETA = true,
                     UNKNOWN = true, PRINTSCREEN = true }

    -- The binding command behind whatever the mouse is over, e.g. "ACTIONBUTTON3", and a label for it.
    local function Target()
        local f
        if GetMouseFoci then
            local list = GetMouseFoci()
            f = type(list) == "table" and list[1] or nil
        end
        if not f and GetMouseFocus then f = GetMouseFocus() end
        for _ = 1, 4 do                                        -- the button itself, or a piece sitting on it
            if not ns:Usable(f) then return nil end
            local name = f.GetName and f:GetName()
            if type(f.suiCommand) == "string" then return f.suiCommand, name end      -- one of the add-on's own bar buttons
            if type(name) == "string" then
                local prefix, n = name:match("^(.-)(%d+)$")
                if prefix and COMMANDS[prefix] then return COMMANDS[prefix] .. n, name end
            end
            f = f.GetParent and f:GetParent()
        end
    end

    local binder, panel, status
    local active, changed = false, false

    local function Keys(command)
        local keys = { GetBindingKey(command) }
        return #keys > 0 and table.concat(keys, ", ") or ns:Tr("no key")
    end

    local function Stop(reason)
        if not active then return end
        active = false
        ns.keybinding = nil
        binder:Hide()
        panel:Hide()
        if changed and SaveBindings and GetCurrentBindingSet then pcall(function() SaveBindings(GetCurrentBindingSet()) end) end
        ns:Print(reason or (changed and "Keybind mode finished. Your keys are saved." or "Keybind mode finished."))
    end

    local function Build()
        binder = CreateFrame("Frame", "FantasyGlassUIBinder", UIParent)
        binder:SetFrameStrata("DIALOG")
        binder:EnableKeyboard(true)
        if binder.SetPropagateKeyboardInput then binder:SetPropagateKeyboardInput(true) end

        panel = CreateFrame("Frame", nil, UIParent, ns.template)
        panel:SetSize(520, 54)
        panel:SetPoint("TOP", UIParent, "TOP", 0, -60)
        panel:SetFrameStrata("DIALOG")
        panel:SetBackdrop(ns.BACKDROP)
        ns:Paint(panel, "SetBackdropColor", "window", 0.95)
        ns:Paint(panel, "SetBackdropBorderColor", "@accent", 1)
        ns:Dress(panel, true)
        local head = ns:NewText(panel, 13, "CENTER", true)
        head:SetPoint("TOP", 0, -8)
        head:SetText(ns:Tr("Keybind mode: hover an action button and press a key. Backspace clears, Esc finishes."))
        status = ns:NewText(panel, 12, "CENTER")
        status:SetPoint("BOTTOM", 0, 9)

        binder:SetScript("OnKeyDown", function(self, key)
            local command, name = Target()
            local consume = (key == "ESCAPE") or (command ~= nil and not IGNORE[key])
            if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(not consume) end
            if not consume then return end
            if key == "ESCAPE" then Stop() return end
            if InCombatLockdown() then Stop("Keybind mode stopped: keys can't be changed in combat.") return end
            if key == "BACKSPACE" or key == "DELETE" then
                for _, k in ipairs({ GetBindingKey(command) }) do pcall(SetBinding, k) end
                changed = true
                status:SetText(format(ns:Tr("%s: keys cleared"), name))
                return
            end
            local full = (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
            local ok, done = pcall(SetBinding, full, command)
            if ok and done ~= false then
                changed = true
                status:SetText(format("|cff66dd77" .. ns:Tr("%s is now on %s") .. "|r", name, full))
            else
                status:SetText("|cffff5555" .. format(ns:Tr("The game refused %s for that button."), full) .. "|r")
            end
        end)

        local acc, last = 0, nil
        binder:SetScript("OnUpdate", function(_, e)
            acc = acc + e
            if acc < 0.08 then return end
            acc = 0
            local command, name = Target()
            if command ~= last then
                last = command
                if command then status:SetText(format("%s  -  %s", name, Keys(command)))
                else status:SetText("|cff999999" .. ns:Tr("(not over an action button)") .. "|r") end
            end
        end)

        local ev = CreateFrame("Frame")
        ev:RegisterEvent("PLAYER_REGEN_DISABLED")
        ev:SetScript("OnEvent", ns:Guard("Convenience events", function() Stop("Keybind mode stopped: keys can't be changed in combat.") end))
    end

    function ns:ToggleKeybindMode()
        if active then Stop() return end
        if InCombatLockdown() then ns:Print("Keys can't be changed in combat.") return end
        if not (SetBinding and GetBindingKey) then ns:Print("This client doesn't let add-ons set keys.") return end
        if not binder then Build() end
        active, changed = true, false
        ns.keybinding = true                                 -- (fading action bars stay visible while you set keys)
        status:SetText("")
        binder:Show()
        panel:Show()
    end
    function ns:KeybindCommandFor(name)            -- for tests: "ActionButton3" -> "ACTIONBUTTON3"
        local prefix, n = tostring(name):match("^(.-)(%d+)$")
        return prefix and COMMANDS[prefix] and (COMMANDS[prefix] .. n) or nil
    end
end

------------------------------------------------------------------------------------------
-- AFK screen: while you are away the interface fades out, the camera drifts around your character
-- and a small panel shows how long you have been gone. It ends the moment you come back or a fight
-- starts. The interface is faded, never hidden, so it can always be brought back, even in combat.
------------------------------------------------------------------------------------------
ns:NewModule("afkScreen", function()
    if not UnitIsAFK then return end
    local ROWS, ROW_H = 7, 20
    local panel = CreateFrame("Frame", "FantasyGlassUIAFK", WorldFrame, ns.template)      -- not under UIParent: it stays when the UI fades
    panel:SetSize(400, 84 + ROWS * ROW_H)
    panel:SetPoint("BOTTOM", WorldFrame, "BOTTOM", 0, 90)
    panel:SetFrameStrata("FULLSCREEN")
    panel:SetBackdrop(ns.BACKDROP)
    ns:Paint(panel, "SetBackdropColor", "window", 0.9)
    ns:Paint(panel, "SetBackdropBorderColor", "@accent", 1)
    local name = ns:NewText(panel, 18, "CENTER", true)
    name:SetPoint("TOP", 0, -12)
    local timer = ns:NewText(panel, 13, "CENTER")
    timer:SetPoint("TOP", 0, -38)
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetTexture(ns.FLAT)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", 20, -62)
    line:SetPoint("TOPRIGHT", -20, -62)
    ns:Paint(line, "SetVertexColor", "@border", 1)
    -- session figures: label on the left, value on the right
    local rows = {}
    for i = 1, ROWS do
        local label = ns:NewText(panel, 12, "LEFT")
        label:SetPoint("TOPLEFT", 24, -72 - (i - 1) * ROW_H)
        ns:Paint(label, "SetTextColor", "dim")
        local value = ns:NewText(panel, 12, "RIGHT")
        value:SetPoint("TOPRIGHT", -24, -72 - (i - 1) * ROW_H)
        rows[i] = { label = label, value = value }
    end
    local function FillStats()
        local stats = ns.SessionStats and ns:SessionStats() or {}
        for i, row in ipairs(rows) do
            local s = stats[i]
            row.label:SetText(s and s[1] or "")
            row.value:SetText(s and s[2] or "")
        end
        panel:SetHeight(84 + math.max(1, math.min(#stats, ROWS)) * ROW_H)
    end
    panel:Hide()

    local away, since = false, 0
    local function Leave()
        if not away then return end
        away = false
        pcall(UIParent.SetAlpha, UIParent, 1)
        if MoveViewLeftStop then pcall(MoveViewLeftStop) end
        panel:Hide()
    end
    local function Enter()
        if away or InCombatLockdown() then return end
        away, since = true, GetTime()
        local scale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
        if type(scale) == "number" and scale > 0 then panel:SetScale(scale) end
        name:SetText(UnitName("player") or "")
        pcall(UIParent.SetAlpha, UIParent, 0)
        if MoveViewLeftStart and ns:Motion() then pcall(MoveViewLeftStart, 0.04) end
        pcall(FillStats)
        panel:Show()
    end
    -- When to show it. By default: when the game marks you away (its own timer, about five minutes,
    -- which add-ons cannot change). With "afkDelay" set, Fantasy Glass UI keeps its own idle clock instead and
    -- shows the screen after that many minutes without you moving, casting, targeting or moving the
    -- mouse. Optionally it also marks the character away at that moment (the same as typing /afk);
    -- that can only make "away" come sooner, never later than the game's own timer.
    local lastActive, lastX, lastY = GetTime(), 0, 0
    local function Active() lastActive = GetTime() end
    ns.AFKActive = Active
    local function Delay() return math.max(0, math.min(60, tonumber(ns.db.afkDelay) or 0)) * 60 end

    local function Check()
        if not ns.db.afkScreen or InCombatLockdown() then Leave() return end
        local delay = Delay()
        if delay > 0 then                                    -- our own clock
            if GetTime() - lastActive >= delay then
                if not away and ns.db.afkFlag then
                    local ok, afk = pcall(UnitIsAFK, "player")
                    if ok and ns.Is(afk, false) and SendChatMessage then pcall(SendChatMessage, "", "AFK") end
                end
                Enter()
            else
                Leave()
            end
            return
        end
        -- (the game can hide even whether you yourself are away, around the start of a fight: then you are not)
        local ok, afk = pcall(UnitIsAFK, "player")
        if ok and ns.Yes(afk) then Enter() else Leave() end
    end

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_FLAGS_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    for _, e in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_START",
                         "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_STARTED_TURNING", "PLAYER_STOPPED_TURNING", "LOOT_OPENED", "MERCHANT_SHOW",
                         "CHAT_MSG_WHISPER_INFORM" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", ns:Guard("Convenience events", function(_, event, unit)
        if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_LEAVING_WORLD" then Active(); Leave() return end
        if event == "PLAYER_FLAGS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then Check() return end
        if event:sub(1, 15) == "UNIT_SPELLCAST_" and unit ~= "player" then return end
        Active()
        if Delay() > 0 then Check() end
    end))
    -- a safety net: whatever happens, the interface is never left faded while you are not away
    ns:Every(1, "AFK screen", function()
        if GetCursorPosition then                           -- the mouse moving counts as you being here
            local ok, x, y = pcall(GetCursorPosition)
            if ok and type(x) == "number" and type(y) == "number" and (x ~= lastX or y ~= lastY) then
                lastX, lastY = x, y
                Active()
            end
        end
        if away then
            local s = math.floor(GetTime() - since)
            timer:SetText(format(ns:Tr("Away for %d:%02d  -  move to return"), math.floor(s / 60), s % 60))
            pcall(FillStats)
        end
        Check()
    end)
    ns.LeaveAFKScreen = Leave
end)

------------------------------------------------------------------------------------------
-- A screenshot each time you gain a level.
------------------------------------------------------------------------------------------
ns:NewModule("levelShot", function()
    if not Screenshot then return end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LEVEL_UP")
    ev:SetScript("OnEvent", ns:Guard("Convenience events", function()
        ns:After(1.5, function() pcall(Screenshot) end)        -- after the level-up banner has appeared
    end))
end)
