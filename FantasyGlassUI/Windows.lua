local _, ns = ...

-- Windows we know by name (some need an extra piece hidden). Anything else the game opens as a
-- panel is caught automatically the first time it is shown.
local WINDOWS = {
    { "CharacterFrame" }, { "MerchantFrame" }, { "FriendsFrame" }, { "TradeFrame" }, { "MailFrame" },
    { "LootFrame" }, { "GossipFrame" }, { "QuestFrame" }, { "AddonList" }, { "ItemTextFrame" },
    { "GameMenuFrame", { "Border" } },
    { "StaticPopup1", { "Border" } }, { "StaticPopup2", { "Border" } },
    { "StaticPopup3", { "Border" } }, { "StaticPopup4", { "Border" } },
    { "WorldMapFrame" },
    { "InspectFrame" }, { "SpellBookFrame" }, { "PlayerSpellsFrame" }, { "PlayerTalentFrame" }, { "ClassTalentFrame" },
    { "CollectionsJournal" }, { "PVEFrame" }, { "ChannelFrame" }, { "ProfessionsFrame" }, { "AuctionHouseFrame" },
    -- (the game's roll frames are not in this list: each is far wider than its artwork, so a panel
    --  painted on one showed as a long dark box. With our roll frames on, they are kept out of sight.)
    { "LootHistoryFrame" }, { "MasterLooterFrame" }, { "BonusRollFrame" },
    { "ClassTrainerFrame" }, { "TaxiFrame" }, { "BankFrame" }, { "GuildFrame" },
    -- guild and communities
    { "CommunitiesFrame" }, { "CommunitiesGuildLogFrame" }, { "CommunitiesGuildTextEditFrame" },
    { "CommunitiesGuildNewsFiltersFrame" }, { "CommunitiesSettingsDialog" }, { "CommunitiesAvatarPickerDialog" },
    { "CommunitiesTicketManagerDialog" }, { "ClubFinderGuildFinderFrame" }, { "ClubFinderCommunityAndGuildFinderFrame" },
    { "GuildRegistrarFrame" }, { "GuildControlUI" }, { "GuildBankFrame" }, { "PetitionFrame" }, { "TabardFrame" },
    -- the rest of the usual suspects
    { "SettingsPanel" }, { "HelpFrame" }, { "MacroFrame" }, { "KeyBindingFrame" }, { "TradeSkillFrame" },
    { "CraftFrame" }, { "DressUpFrame" }, { "PetStableFrame" }, { "ReputationFrame" }, { "TimeManagerFrame" },
    { "RaidInfoFrame" }, { "ReadyCheckFrame" }, { "RolePollPopup" }, { "LFGListFrame" }, { "CalendarFrame" },
}

ns.windowNames = WINDOWS                                   -- (also the windows that can be dragged: see Extras.lua)

ns:NewModule("windows", function()
    local pending = {}
    local function Try(def)
        local f = _G[def[1]]
        if not f then return false end
        ns:SkinWindow(f, def[2])
        return true
    end
    for _, def in ipairs(WINDOWS) do
        if not Try(def) then pending[#pending + 1] = def end
    end

    -- Load-on-demand windows get skinned the moment their addon loads
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", ns:Guard("Windows", function()
        for i = #pending, 1, -1 do
            if Try(pending[i]) then table.remove(pending, i) end
        end
    end))

    -- Dropdown and right-click menus -----------------------------------------------------------
    -- Nothing is hooked here on purpose: hooking the menu system taints it, and tainted menus can't
    -- run protected entries such as "Set Focus". Instead the open menu is looked up a few times a
    -- second and painted.
    local seen = setmetatable({}, { __mode = "k" })
    local MENU_ART = { "NineSlice", "Background", "Bg", "Border", "Backdrop", "MenuBackdrop" }
    local function PaintMenu(menu)
        if type(menu) ~= "table" or not menu.GetRegions or (menu.IsForbidden and menu:IsForbidden()) then return end
        for _, k in ipairs(MENU_ART) do
            local o = menu[k]
            if type(o) == "table" and not o.sui and o.SetAlpha then o:SetAlpha(0) end
        end
        ns:StripArt(menu)                    -- any art drawn straight on the menu (ours is tagged and kept)
        if not seen[menu] then
            seen[menu] = true
            ns:PaintPanel(menu, 0.98, true)
        end
    end

    -- older dropdown lists
    for i = 1, 3 do
        local list = _G["DropDownList" .. i]
        if type(list) == "table" then
            for _, suffix in ipairs({ "Backdrop", "MenuBackdrop" }) do
                local f = _G["DropDownList" .. i .. suffix]
                if type(f) == "table" and f.SetAlpha then f:SetAlpha(0) end
            end
            pcall(ns.PaintPanel, ns, list, 0.97, true)
        end
    end

    -- the modern menu system: the open menu, plus any submenus (frames built from the same mixin)
    local function OpenMenu()
        if not (Menu and Menu.GetManager) then return nil end
        local ok, mgr = pcall(Menu.GetManager)
        if not ok or type(mgr) ~= "table" or not mgr.GetOpenMenu then return nil end
        local ok2, menu = pcall(mgr.GetOpenMenu, mgr)
        return ok2 and type(menu) == "table" and menu or nil
    end
    -- A menu frame carries the functions its mixin copied onto it. Another frame is a submenu only if
    -- it is built the same way in every respect that can be checked:
    --   * it carries (nearly) ALL of the menu's functions, not just a few. Many of the game's frames
    --     share a handful of general layout functions with menus; a container down the side of the
    --     screen was once taken for a menu on the strength of three of them, and painted as one.
    --   * it has no name. The game's menus are made on demand and are anonymous; its fixed containers
    --     all have names.
    --   * it sits on the same layer of the screen as the menu itself.
    local function Signature(root)
        local sig, n = {}, 0
        for k, v in pairs(root) do
            if type(k) == "string" and k:sub(1, 3) ~= "sui" and type(v) == "function" then
                sig[k] = v
                n = n + 1
                if n >= 80 then break end
            end
        end
        return sig, n
    end
    local function IsMenu(f, sig, n, root)
        if n < 4 then return false end                       -- too little to recognise anything by
        local okN, name = pcall(f.GetName, f)
        if not okN or name ~= nil then return false end
        if root and root.GetFrameStrata and f.GetFrameStrata then
            local okA, a = pcall(root.GetFrameStrata, root)
            local okB, b = pcall(f.GetFrameStrata, f)
            if okA and okB and a ~= b then return false end
        end
        local same = 0
        for k, v in pairs(sig) do
            if rawget(f, k) == v then same = same + 1 end
        end
        return same >= math.ceil(n * 0.9)
    end
    ns.IsMenuFrame = IsMenu
    -- Frames that cover the whole screen (cutscenes, movies, the game's full-screen panels): never
    -- given a window's look. They are shown the same way as windows, so they are told apart by name
    -- and by size.
    local FULL = { CinematicFrame = true, MovieFrame = true, WorldMapFrame = false }
    function ns.FullScreenFrame(frame)
        local okN, name = pcall(frame.GetName, frame)
        if okN and type(name) == "string" and FULL[name] then return true end
        local okW, w = pcall(frame.GetWidth, frame)
        local okH, h = pcall(frame.GetHeight, frame)
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        if okW and okH and type(w) == "number" and type(h) == "number" and not ns:IsSecret(w) and not ns:IsSecret(h)
            and type(sw) == "number" and sw > 0 and w >= sw * 0.9 and h >= sh * 0.9 then
            return true
        end
        return false
    end
    ns.MenuSignature = Signature
    -- Looked at 20 times a second while a menu is open (and once per tick otherwise, to see that none
    -- is): a new menu is painted at once; the same menu is painted again, and the screen searched for
    -- its submenus, ten times a second. A menu's signature is worked out once.
    local macc, sacc, lastRoot = 0, 0, nil
    local sigs = setmetatable({}, { __mode = "k" })
    local function PaintKin(sig, n, root, pool)
        for _, f in ipairs(pool) do
            -- the screen's children include frames add-ons may not touch: ask before anything else
            if f ~= root and ns:Usable(f) and f.IsShown and f:IsShown() and IsMenu(f, sig, n, root) then PaintMenu(f) end
        end
    end
    local mpoll = CreateFrame("Frame")
    mpoll:SetScript("OnUpdate", ns:Guard("Menus", function(_, e)
        macc = macc + e
        if macc < 0.05 then return end
        sacc = sacc + macc
        macc = 0
        local root = OpenMenu()
        if not root or not ns:Usable(root) then lastRoot = nil; return end   -- (a menu the game has locked away is left alone)
        if root == lastRoot and sacc < 0.1 then return end
        lastRoot, sacc = root, 0
        PaintMenu(root)
        local known = sigs[root]
        if known == nil then
            local ok, sig, n = pcall(Signature, root)
            known = (ok and type(sig) == "table" and n and n > 0) and { sig, n } or false
            sigs[root] = known
        end
        if known then
            local sig, n = known[1], known[2]
            PaintKin(sig, n, root, { UIParent:GetChildren() })
            PaintKin(sig, n, root, { root:GetChildren() })
            local parent = root.GetParent and root:GetParent()
            if type(parent) == "table" and parent ~= UIParent and parent.GetChildren then PaintKin(sig, n, root, { parent:GetChildren() }) end
        end
    end))

    -- Catch-all: whatever panel the game opens gets our look the first time it appears.
    -- (ShowUIPanel is a global function, not a method on one of the game's frames, so hooking it is safe.)
    if ShowUIPanel then
        hooksecurefunc("ShowUIPanel", ns:Guard("Windows", function(frame)
            if type(frame) ~= "table" or frame.suiWindow or not frame.GetObjectType then return end
            if frame.IsForbidden and frame:IsForbidden() then return end
            if ns.FullScreenFrame(frame) then return end      -- cutscenes and movies are left as the game shows them
            ns:SkinWindow(frame)
        end))
    end
end)
