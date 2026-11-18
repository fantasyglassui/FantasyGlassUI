local _, ns = ...

------------------------------------------------------------------------------------------
-- Live self-test (11.0): /fgui selftest works through the add-on in the real game - opens every tab
-- of the options and every window, switches the preview, move mode and What's this? on and off, and
-- asks each feature that is switched on whether it is running - then lists what passed and what did
-- not, with the error. Not during a fight. It takes a few seconds and puts everything back.
------------------------------------------------------------------------------------------
ns.SELFTEST_WINDOWS = { "checklist", "session", "rares", "level", "profcd", "gold", "loot", "rolls", "recent", "lockouts", "trades", "todo", "addons", "missing", "events", "comp", "bagrules", "mailrules", "talents", "crafts", "reps" }

local function Steps()
    local s = {}
    local function add(name, fn) s[#s + 1] = { name = name, fn = fn } end
    add("Features switched on are running", function()
        local off = {}
        for _, m in ipairs(ns.modules or {}) do
            if ns.db[m.key] and not ns.loaded[m.key] and not (ns.steppedAside and ns.steppedAside[m.key]) then off[#off + 1] = m.key end
        end
        if #off > 0 then error("not running: " .. table.concat(off, ", ")) end
    end)
    add("No errors so far this session", function()
        if #(ns.errors or {}) > 0 then error(tostring(ns.errors[1]) .. ((#ns.errors > 1) and (" (+" .. (#ns.errors - 1) .. " more)") or "")) end
    end)
    add("Options load", function() if not ns:LoadOptions() then error("the options folder could not be loaded") end end)
    for _, tab in ipairs({ "features", "look", "layout", "combat", "profiles", "bars", "tools", "guide" }) do
        add(format(ns:Tr("Options tab: %s"), tab), function()
            ns:ToggleConfig(tab)
            if not (ns.configFrame and ns.configFrame.currentPage == tab) then error("did not open") end
        end)
    end
    add("Options close", function() if ns.HideConfig then ns.HideConfig() end end)
    for _, word in ipairs(ns.SELFTEST_WINDOWS) do
        add(format(ns:Tr("Window: %s"), "/fgui " .. word), function()
            if not ns.toolCommands[word] then error("no such command") end
            ns:ToolCommand(word, word)
        end)
    end
    add("Windows close", function() if ns.HideLists then ns:HideLists() end end)
    add("Preview on and off", function() ns:TogglePreview(); ns:TogglePreview() end)
    add("Move mode on and off", function() ns:ToggleMove(); ns:ToggleMove() end)
    add("What's this? on and off", function() local n = ns:WhatsThis(true); ns:WhatsThis(false); if not n or n < 1 then error("no panels found") end end)
    add("Tools on the Menu button", function()
        if not ns:ToggleToolsMenu() then error("did not open") end
        if ns.toolPalette and #ns.toolPalette.buttons ~= #ns.TOOL_MENU then error("buttons missing") end
        ns:ToggleToolsMenu()
    end)
    add("Shared string preview", function()
        local kind = ns:PreviewShared(ns:ExportLayout())
        if kind ~= "layout" then error("could not read this layout's own string") end
        if ns.ShowSharePreview then ns:ShowSharePreview():Hide() end
    end)
    add("Layout gallery opens", function() local w = ns:ShowGallery(); if w and w.IsShown and w:IsShown() then w:Hide() end end)
    add("Theme applies", function() if not ns:Retheme() then error("needs a reload") end end)
    add("Info bar reads", function() if ns.InfoBarCompose then local line = ns.InfoBarCompose(); if type(line) ~= "string" then error("no text") end end end)
    add("Class emblems", function() if ns.EmblemTick then ns:EmblemTick() end; if ns.emblemError then error(ns.emblemError) end end)
    add("Frame designer", function() if ns.ApplyFrameDesign then ns:ApplyFrameDesign() end end)
    add("Fantasy Glass action bars", function()
        if ns.db.barEngine and not ns.loaded.barEngine then error(tostring(ns.barEngineState or "not running")) end
        if ns.engine and ns.engine.bars then
            for _, bar in ipairs(ns.engine.bars) do
                local b = bar.buttons[1]
                local action = b and b:GetAttribute("action")
                if type(action) ~= "number" then action = b and b.suiAction end
                if type(action) ~= "number" or action < 1 then error(bar.def.label .. " has no action on its first button") end
                if b and b.suiClicks ~= "AnyUp AnyDown" then error(bar.def.label .. " does not hear key and mouse presses going down") end
            end
        end
    end)
    add("Custom alerts", function() if ns.customAlertsTest then ns.customAlertsTest.Update() end end)
    add("Spoken alerts", function()
        if ns.db.speakAlerts and not (C_VoiceChat and C_VoiceChat.SpeakText) then error("this game client cannot speak") end
    end)
    add("Self-check report", function() if ns.SelfCheck then ns:SelfCheck(true) end end)
    return s
end
ns.SelfTestSteps = Steps

-- Run the steps one after another (a short pause between, so the game can draw), then report.
-- done(results) is called at the end; results = { { name, ok, err } ... }.
function ns:SelfTest(done, pause)
    if InCombatLockdown() then ns:Print("Not during a fight."); return false end
    if ns.selfTesting then return false end
    ns.selfTesting = true
    ns.selfTestRun = (ns.selfTestRun or 0) + 1
    local run = ns.selfTestRun
    local steps, results, i = Steps(), {}, 0
    local function Next()
        if run ~= ns.selfTestRun then return end             -- (a newer self-test has started)
        i = i + 1
        local step = steps[i]
        if not step or InCombatLockdown() then
            ns.selfTestStop = step and "combat" or "end"
            ns.selfTesting = false
            if ns.HideConfig then pcall(ns.HideConfig) end
            if ns.previewing then pcall(ns.TogglePreview, ns) end
            if ns.moving then pcall(ns.ToggleMove, ns) end
            ns.selfTestResults = results
            if done then done(results) else ns:ShowSelfTest(results, step ~= nil) end
            return
        end
        ns.selfTestAt = step.name
        local ok, err = pcall(step.fn)
        results[#results + 1] = { name = step.name, ok = ok, err = (not ok) and tostring(err):gsub("^[^:]*:%d+: ", "") or nil }
        if pause == false then return Next() end              -- (all at once: for tests)
        ns:After(pause or 0.15, Next)
    end
    ns:Print("Self-test: %d steps; a few seconds.", #steps)
    Next()
    return true
end
function ns:ShowSelfTest(results, cut)
    local lines, failed = {}, 0
    for _, r in ipairs(results) do
        if not r.ok then failed = failed + 1 end
        lines[#lines + 1] = { left = (r.ok and ns:SignalHex("good") .. ns:Tr("pass") or ns:SignalHex("bad") .. ns:Tr("FAIL")) .. "|r  " .. ns:Tr(r.name),
            right = r.err and ("|cffff9a8a" .. r.err .. "|r") or "", tip = r.err and { ns:Tr(r.name), r.err } or nil }
    end
    table.sort(lines, function(a, b) return (a.right ~= "" and 0 or 1) < (b.right ~= "" and 0 or 1) end)
    local title = failed == 0 and format(ns:Tr("Self-test: all %d passed"), #results) or format(ns:Tr("Self-test: %d of %d failed"), failed, #results)
    ns:ShowList("SelfTest", title, lines, cut and "Stopped early: a fight started." or "Point at a failed line for the whole error. /fgui check has more.", 560, 420)
    return failed
end
