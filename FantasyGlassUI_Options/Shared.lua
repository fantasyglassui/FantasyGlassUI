-- Part of Fantasy Glass UI, kept in a second folder that the game loads only when it is needed (the
-- first time the options, the setup or the self-check is asked for). The main add-on shares its
-- table as the global FantasyGlassUI; everything here hangs off that.
local ns = _G.FantasyGlassUI
if type(ns) ~= "table" then return end

-- What the options pages share: the window, its pages and tab buttons, headings and page switching.
-- The pages are built in their own files (Features, Look, Layout and Profiles, Combat); Config.lua
-- makes the window and puts them in it.
local O = { pages = {}, tabButtons = {} }
ns.optUI = O

-- opts.nav: the name this heading's section has in the list down the left (when it differs);
-- opts.sub: a heading inside a section, not a section of its own.
function O.Header(parent, text, x, y, opts)
    local th = ns.theme
    local fs = parent:CreateFontString(nil, "OVERLAY")
    ns:Font(fs, 14, true)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(ns:Tr(text))
    ns:Paint(fs, "SetTextColor", "@accent")
    ns:IndexOption(text, fs)                                 -- (section headings can be searched for too)
    if ns.NoteSection and not (opts and opts.sub) then ns.NoteSection(parent, (opts and opts.nav) or text, x, y, fs) end
    return fs
end

function O.ShowPage(id)
    local th = ns.theme
    for key, page in pairs(O.pages) do
        if key == id then page:Show() else page:Hide() end
    end
    for key, b in pairs(O.tabButtons) do b:SetSelected(key == id) end
    if O.frame then O.frame.currentPage = id end
    if O.pages[id] and O.pages[id].Refresh then O.pages[id].Refresh() end
    if O.pages[id] and O.pages[id].NavRefresh then O.pages[id].NavRefresh() end
end
