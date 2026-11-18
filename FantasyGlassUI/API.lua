local ADDON, ns = ...

------------------------------------------------------------------------------------------
-- The public API (11.0): what other add-ons may use. Everything here is stable within one API
-- version; anything else in this add-on may change between releases. API.md describes it.
--
--   local FG = FantasyGlassUI_API
--   if FG and FG.version >= 1 then
--       FG.RegisterInfoPiece("myaddon:gold", "My add-on", function() return "42 things" end)
--   end
------------------------------------------------------------------------------------------
local API = { version = 1 }
_G.FantasyGlassUI_API = API
ns.api = API
API.addonVersion = ns.version

local function Check(cond, msg, level) if not cond then error("FantasyGlassUI_API: " .. msg, (level or 2) + 1) end end
local function Clean(key) return tostring(key):gsub("[^%w_:%-]", "") end

-- A piece of text on the info bar. text() is called about once a second and returns a string (or nil
-- to show nothing). opts: defaultOff = true to start switched off. The piece appears in the bar's
-- right-click list under `label`, where it can be switched on and off.
ns.apiInfoPieces = ns.apiInfoPieces or {}
function API.RegisterInfoPiece(key, label, text, opts)
    Check(type(key) == "string" and key ~= "", "RegisterInfoPiece: key must be a string")
    Check(type(text) == "function", "RegisterInfoPiece: text must be a function")
    key = "api_" .. Clean(key)
    for _, p in ipairs(ns.apiInfoPieces) do if p.key == key then p.text, p.label = text, label or p.label; return key end end
    local piece = { key = key, label = tostring(label or key), text = text, defaultOff = opts and opts.defaultOff and true or false }
    ns.apiInfoPieces[#ns.apiInfoPieces + 1] = piece
    if ns.infobarPieces then                                 -- the bar is up already
        ns.infobarPieces[#ns.infobarPieces + 1] = { key, piece.label }
        if piece.defaultOff and ns.infobarDefaultOff then ns.infobarDefaultOff[key] = true end
        if ns.RefreshInfoBar then ns:RefreshInfoBar() end
    end
    return key
end

-- A theme on the Look tab. def = { style = "GLASS", "FANTASY" or "CELESTIAL", panel = { r, g, b }, rim = { r, g, b },
-- accent = { r, g, b } } with colors from 0 to 1. It is listed with the others of its family.
function API.RegisterTheme(key, name, def)
    Check(type(key) == "string" and key ~= "", "RegisterTheme: key must be a string")
    Check(type(def) == "table", "RegisterTheme: def must be a table")
    local id = "P:" .. Clean(key)
    local clean = ns.CleanThemeDef and ns:CleanThemeDef(def) or def
    local t = ns.ThemeFromDef(tostring(name or key), clean)
    t.custom, t.plugin = nil, true
    if not ns.themes[id] then ns.themeOrder[#ns.themeOrder + 1] = id end
    ns.themes[id] = t
    return id
end

-- A chat command: /fgui <word> ... runs fn(rest of the line). help: a line for /fgui help.
function API.RegisterCommand(word, fn, help)
    Check(type(word) == "string" and word:match("^%w+$"), "RegisterCommand: word must be letters and numbers")
    Check(type(fn) == "function", "RegisterCommand: fn must be a function")
    word = word:lower()
    Check(not ns.toolCommands[word], "RegisterCommand: /fgui " .. word .. " is taken")
    ns.toolCommands[word] = fn
    if help and ns.helpLines then ns.helpLines[#ns.helpLines + 1] = { "/fgui " .. word, tostring(help) } end
    return word
end

-- A button on the Tools tab that opens your window: fn() is called when it is pressed.
function API.RegisterToolWindow(label, fn)
    Check(type(label) == "string" and label ~= "", "RegisterToolWindow: label must be a string")
    Check(type(fn) == "function", "RegisterToolWindow: fn must be a function")
    ns.apiToolCount = (ns.apiToolCount or 0) + 1
    local word = "plugin" .. ns.apiToolCount
    ns.toolCommands[word] = fn
    ns.apiToolWindows = ns.apiToolWindows or {}
    ns.apiToolWindows[#ns.apiToolWindows + 1] = { label, word }
    if ns.toolWindows then ns.toolWindows[#ns.toolWindows + 1] = { label, word } end
    return word
end

-- An answer for the Tools tab's "Ask the guide". topic = { title, text, keys = "words to match", command }.
ns.apiGuideTopics = ns.apiGuideTopics or {}
function API.RegisterGuideTopic(topic)
    Check(type(topic) == "table" and type(topic.title) == "string" and type(topic.text) == "string", "RegisterGuideTopic: title and text are needed")
    ns.apiGuideTopics[#ns.apiGuideTopics + 1] = { title = topic.title, text = topic.text, keys = tostring(topic.keys or topic.title):lower(), command = topic.command }
    return #ns.apiGuideTopics
end

-- A frame of yours that moves with /fgui move (its place is saved with the player's layout).
function API.RegisterPanel(frame, key, label)
    Check(type(frame) == "table" and frame.SetPoint, "RegisterPanel: frame must be a frame")
    Check(type(key) == "string" and key ~= "", "RegisterPanel: key must be a string")
    local entry = ns:RegisterMovable(frame, "api_" .. Clean(key), tostring(label or key))
    if type(entry) == "table" then entry.offPage = true end
    return entry ~= nil
end

-- Look: the theme's colors ("accent", "border", "bg", "text", "dim", "faint"), its fonts, and a way to
-- dress a frame of yours as this add-on dresses its own (a frame made with BackdropTemplate).
function API.GetColor(role)
    local r, g, b = ns:Role((role == "accent" or role == "border" or role == "bg") and ("@" .. role) or tostring(role or "text"))
    return r, g, b
end
function API.GetFonts() return ns.FONT, ns.TITLEFONT end
function API.GetStyle() return ns.style, ns.db and ns.db.theme end
function API.Style(frame, alpha)
    Check(type(frame) == "table", "Style: frame must be a frame")
    if not frame.SetBackdrop then return false end
    frame:SetBackdrop(ns.BACKDROP)
    ns:Paint(frame, "SetBackdropColor", "window", alpha or 0.95)
    ns:Paint(frame, "SetBackdropBorderColor", "@border", 1)
    if ns.Dress then ns:Dress(frame) end
    return true
end
function API.StyleText(fontString, size, title)
    Check(type(fontString) == "table" and fontString.SetFont, "StyleText: a font string is needed")
    ns:Font(fontString, size or 12, title)
    return true
end
-- fn() runs after every change of theme or accent.
function API.OnThemeChanged(fn)
    Check(type(fn) == "function", "OnThemeChanged: fn must be a function")
    ns:OnTheme(function() pcall(fn) end)
    return true
end

-- Messages: a notice in the corner, a line in the middle of the screen, a spoken line (if the player
-- has spoken alerts on), and chat with this add-on's name.
function API.Toast(title, text, icon) if ns.Toast then return pcall(ns.Toast, ns, icon, tostring(title or ""), tostring(text or "")) end end
function API.Flash(text, r, g, b) if ns.Flash then return ns:Flash(tostring(text or ""), r, g, b) end end
function API.Speak(text) if ns.Speak and ns.db and ns.db.speakAlerts then return ns:Speak(tostring(text or "")) end return false end

-- Is one of this add-on's features switched on? (The keys are the ones in /fgui check.)
function API.IsFeatureOn(key) return (ns.db and ns.db[key] and ns.loaded and ns.loaded[key]) and true or false end
-- The player's role as chosen in the setup: "TANK", "HEALER", "DAMAGE" or nil.
function API.GetRole() return ns.db and ns.db.role or nil end
