local _, ns = ...

------------------------------------------------------------------------------------------
-- Shared pieces for the smaller tools: a window that shows a list, a line that flashes in the
-- middle of the screen, an alert that is hard to miss, and lists of names kept with the settings.
------------------------------------------------------------------------------------------
local ROW = 18
local windows = {}

-- A window holding a list of lines. Each line: { left, right, color = {r,g,b}, click = fn(button), tip = { ... } }.
-- Made once for each key; ask again to get the same one.
function ns:ListWindow(key, title, note, width, height)
    local w = windows[key]
    if not w then
        width, height = width or 380, height or 320
        local name = "FantasyGlassUIList" .. key
        w = CreateFrame("Frame", name, UIParent, ns.template)
        w:SetSize(width, height)
        w:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        w:SetFrameStrata("DIALOG")
        w:SetBackdrop(ns.BACKDROP)
        ns:Paint(w, "SetBackdropColor", "window", 0.97)
        ns:Paint(w, "SetBackdropBorderColor", "@border", 1)
        ns:Dress(w)
        w:EnableMouse(true)
        w:SetMovable(true)
        if w.SetClampedToScreen then w:SetClampedToScreen(true) end        -- (a kept place can never leave it off the screen)
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", function(self) self:StartMoving() end)
        w:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, rel, x, y = self:GetPoint()                -- (kept for next time, for every character)
            if type(ns.root) == "table" and point then
                ns.root.listPos = type(ns.root.listPos) == "table" and ns.root.listPos or {}
                ns.root.listPos[key] = { point, rel or point, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5) }
            end
        end)
        local saved = type(ns.root) == "table" and type(ns.root.listPos) == "table" and ns.root.listPos[key]
        if type(saved) == "table" and type(saved[1]) == "string" then
            w:ClearAllPoints()
            w:SetPoint(saved[1], UIParent, saved[2] or saved[1], tonumber(saved[3]) or 0, tonumber(saved[4]) or 0)
        end
        if type(UISpecialFrames) == "table" then tinsert(UISpecialFrames, name) end
        w.title = ns:NewText(w, 14, "LEFT")
        w.title:SetPoint("TOPLEFT", 14, -12)
        ns:Paint(w.title, "SetTextColor", "@accent")
        local close = ns:CreateButton(w, "X", 22, 20, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
        w.rowWidth = width - 34
        w.area, w.sheet = ns:ScrollArea(w, width - 28, height - 40 - 30)
        w.area:SetPoint("TOPLEFT", 14, -40)
        w.note = ns:NewText(w, 10, "LEFT")
        w.note:SetPoint("BOTTOMLEFT", 14, 9)
        w.note:SetPoint("BOTTOMRIGHT", -14, 9)
        w.note:SetTextColor(0.6, 0.6, 0.6)
        w.rows, w.lines = {}, {}
        function w:SetLines(lines)
            self.lines = lines or {}
            for i, line in ipairs(self.lines) do
                local row = self.rows[i]
                if not row then
                    row = CreateFrame("Button", nil, self.sheet)
                    row:SetSize(self.rowWidth, ROW)
                    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW)
                    row.right = ns:NewText(row, 12, "RIGHT")
                    row.right:SetPoint("RIGHT", -4, 0)
                    row.left = ns:NewText(row, 12, "LEFT")
                    row.left:SetPoint("LEFT", 2, 0)
                    row.left:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
                    if row.left.SetWordWrap then row.left:SetWordWrap(false) end
                    row.bar = row:CreateTexture(nil, "BACKGROUND")       -- (a line may carry a bar: line.bar from 0 to 1)
                    row.bar:SetPoint("TOPLEFT", 0, -1)
                    row.bar:SetPoint("BOTTOMLEFT", 0, 1)
                    row.bar:SetTexture(ns.FLAT)
                    ns:Paint(row.bar, "SetVertexColor", "@accent", 0.3)
                    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
                    row.hl:SetAllPoints()
                    row.hl:SetTexture(ns.FLAT)
                    row.hl:SetVertexColor(1, 1, 1, 0.08)
                    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    row:SetScript("OnClick", ns:Guard("List", function(r, button) if r.line and r.line.click then r.line.click(button) end end))
                    row:SetScript("OnEnter", function(r)
                        local tip = r.line and r.line.tip
                        if type(tip) ~= "table" or #tip == 0 then return end
                        GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
                        for n, text in ipairs(tip) do
                            if n == 1 then GameTooltip:AddLine(ns:AccentHex() .. tostring(text) .. "|r") else GameTooltip:AddLine(tostring(text), 1, 1, 1, true) end
                        end
                        GameTooltip:Show()
                    end)
                    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    self.rows[i] = row
                end
                row.line = line
                if type(line.bar) == "number" and line.bar > 0 then
                    row.bar:SetWidth(math.max(1, self.rowWidth * math.min(1, line.bar)))
                    row.bar:Show()
                else
                    row.bar:Hide()
                end
                row.left:SetText(line.left or line[1] or "")
                if line.hasSecret then row.right:SetText(line.secretRight)      -- (a value the game hides: shown as it is, never tested)
                else row.right:SetText(line.right or line[2] or "") end
                local c = line.color
                if type(c) == "table" then row.left:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1) else row.left:SetTextColor(1, 1, 1) end
                row:Show()
            end
            for i = #self.lines + 1, #self.rows do self.rows[i].line = nil; self.rows[i]:Hide() end
            if self.area.SetContentHeight then self.area:SetContentHeight(#self.lines * ROW) end
        end
        windows[key] = w
    end
    w.title:SetText(ns:Tr(title or ""))
    w.note:SetText(note and ns:Tr(note) or "")
    return w
end
-- Close every list window (the self-test opens many).
function ns:HideLists()
    local n = 0
    for key, w in pairs(windows) do if key ~= "SelfTest" and w:IsShown() then w:Hide(); n = n + 1 end end
    return n
end
-- Open a list window with these lines (the usual case).
function ns:ShowList(key, title, lines, note, width, height)
    local w = ns:ListWindow(key, title, note, width, height)
    w:SetLines(lines)
    w:Show()
    return w
end

------------------------------------------------------------------------------------------
-- A line in the middle of the screen for a moment. `arg`, when given, is put into `text` by the
-- game itself (so a value the game hides can still be shown).
------------------------------------------------------------------------------------------
local flash
ns.FLASH_TIME = 1.8
function ns:Flash(text, r, g, b, arg)
    if not flash then
        flash = CreateFrame("Frame", "FantasyGlassUIFlash", UIParent)
        flash:SetSize(360, 30)
        flash:SetPoint("CENTER", UIParent, "CENTER", 0, 170)
        flash.text = ns:NewText(flash, 22, "CENTER")
        flash.text:SetPoint("CENTER")
        if flash.text.SetShadowOffset then flash.text:SetShadowOffset(1, -1); flash.text:SetShadowColor(0, 0, 0, 1) end
        flash.left = 0
        flash:SetScript("OnUpdate", function(self, elapsed)
            if ns.moving then self:SetAlpha(1) return end
            self.left = self.left - (elapsed or 0)
            if self.left <= 0 then self:SetAlpha(0) else self:SetAlpha(math.min(1, self.left / 0.5)) end
        end)
        local entry = ns:RegisterMovable(flash, "flash", "Alerts")
        if type(entry) == "table" then entry.offPage = true end        -- (scaled from its own right-click menu in move mode)
    end
    if arg ~= nil then
        if not pcall(flash.text.SetFormattedText, flash.text, text, arg) then flash.text:SetText(text) end
    else
        flash.text:SetText(text)
    end
    flash.text:SetTextColor(r or 1, g or 0.82, b or 0.2)
    flash.left = ns.FLASH_TIME
    flash:SetAlpha(1)
    ns.flashCount = (ns.flashCount or 0) + 1
    ns.flashLast = text
    return true
end

-- Something the game does not allow during a fight: done when the fight ends instead (once, however
-- many times it was asked for). Returns true when it was put off.
local afterFight, afterFrame = {}, nil
function ns:AfterFight(label, fn)
    if not InCombatLockdown() then return false end
    if not afterFrame then
        afterFrame = CreateFrame("Frame")
        pcall(afterFrame.RegisterEvent, afterFrame, "PLAYER_REGEN_ENABLED")
        afterFrame:SetScript("OnEvent", function()
            local list = afterFight
            afterFight = {}
            for _, job in ipairs(list) do pcall(job.fn) end
        end)
    end
    for _, job in ipairs(afterFight) do if job.label == label then return true end end
    afterFight[#afterFight + 1] = { label = label, fn = fn }
    ns:Print("%s: not during a fight, so it happens as soon as the fight ends.", ns:Tr(label))
    return true
end
function ns.AfterFightCount() return #afterFight end

-- Something you must not miss: a sound that plays with the game in another window, the game's
-- icon flashing in the taskbar, and a notice.
function ns:LoudAlert(title, text, sound)
    if PlaySound and SOUNDKIT then pcall(PlaySound, sound or SOUNDKIT.READY_CHECK or 8960, "Master") end
    if FlashClientIcon then pcall(FlashClientIcon) end
    if ns.Toast then pcall(ns.Toast, ns, nil, ns:Tr(title), text and ns:Tr(text) or "", "!") end
    ns.loudAlertLast = title
    return true
end

------------------------------------------------------------------------------------------
-- Lists of names kept with the settings, changed from chat:
--   /fgui remind Lightning Shield      adds it, or removes it if it is there already
--   /fgui remind add X   /fgui remind remove X   /fgui remind (shows the list)
------------------------------------------------------------------------------------------
local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
ns.Trim = Trim

-- Change `list` as `text` asks. Returns "added" / "removed" / "list" / "missing", and the name.
function ns.ListEdit(list, text)
    text = Trim(text)
    if text == "" or text:lower() == "list" then return "list" end
    local want
    local first, rest = text:match("^(%S+)%s+(.+)$")
    if first then
        local f = first:lower()
        if f == "add" then want, text = "add", Trim(rest)
        elseif f == "remove" or f == "del" or f == "delete" then want, text = "remove", Trim(rest) end
    end
    local at
    for i, name in ipairs(list) do if tostring(name):lower() == text:lower() then at = i end end
    if at and want ~= "add" then
        table.remove(list, at)
        return "removed", text
    elseif at then
        return "added", list[at]
    elseif want == "remove" then
        return "missing", text
    end
    list[#list + 1] = text
    return "added", text
end
-- The list saved under this setting (made if it is not there).
function ns:SavedList(key, account)
    local home = account and ns.root or ns.db
    if type(home) ~= "table" then return {} end
    if type(home[key]) ~= "table" then home[key] = {} end
    return home[key]
end
-- A chat command that edits one of those lists and says what it did.
function ns:ListCommand(key, text, what, account)
    local list = ns:SavedList(key, account)
    local did, name = ns.ListEdit(list, text)
    if did == "added" then ns:Print("%s: added \"%s\".", ns:Tr(what), name)
    elseif did == "removed" then ns:Print("%s: removed \"%s\".", ns:Tr(what), name)
    elseif did == "missing" then ns:Print("%s: \"%s\" is not on the list.", ns:Tr(what), name)
    elseif #list == 0 then ns:Print("%s: the list is empty.", ns:Tr(what))
    else ns:PrintRaw("|cff33ccffFantasy Glass UI|r: " .. ns:Tr(what) .. ": " .. table.concat(list, ", ")) end
    ns.listChanged = (ns.listChanged or 0) + 1
    return did, name
end

-- "3:41" from seconds.
function ns.Clock(seconds)
    seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
    if seconds >= 3600 then return format("%d:%02d:%02d", math.floor(seconds / 3600), math.floor(seconds % 3600 / 60), seconds % 60) end
    return format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
-- Today as a number that sorts: 20261115.
function ns.Today()
    local ok, d = pcall(date, "%Y%m%d")
    return (ok and tonumber(d)) or 0
end

-- One of the game's own sentences ("%s rolls %d (%d-%d)") as a pattern that takes it apart again.
function ns.GamePattern(template)
    if type(template) ~= "string" then return nil end
    local p = template:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)"):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
    return "^" .. p .. "$"
end
