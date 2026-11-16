-- Offline tests: luajit tests/run.lua   (from the addon folder)
local root = (arg[0]:match("^(.*)/tests/run%.lua$")) or "."
local failures, total = 0, 0

local function check(cond, message)
    total = total + 1
    if not cond then
        failures = failures + 1
        print("  FAIL: " .. message)
    end
end

-- options.account / options.character: saved tables as the game would hand them over.
local function fresh(locale, options)
    local M = dofile(root .. "/tests/mock.lua")
    M.Install(locale)
    M.playerName = options and options.player
    _G.RPQuickResponseDB = options and options.account
    _G.RPQuickResponseCharDB = options and options.character
    local ns = M.LoadAddon(root, options)
    return M, ns
end

local function test(name, fn)
    print(name)
    local ok, err = pcall(fn)
    if not ok then
        failures = failures + 1
        total = total + 1
        print("  ERROR: " .. tostring(err))
    end
end

-- Core ---------------------------------------------------------------------------------------------

for _, locale in ipairs({ "enUS", "deDE", "frFR" }) do
    test("defaults and translations (" .. locale .. ")", function()
        local _, ns = fresh(locale)
        for _, category in ipairs(ns.char.categories) do
            check(not category.name:find("^DEFAULT_"), "name resolves: " .. category.name)
            check(#category.entries == 3, "three lines in " .. category.name)
            for _, entry in ipairs(category.entries) do
                check(ns.ParseFull(entry.full), "default parses: " .. entry.short)
                check(not entry.full:find("/y ", 1, true), "defaults do not yell: " .. entry.short)
            end
        end
    end)
end

test("Full: any command, a line without one is said", function()
    local _, ns = fresh()
    check(ns.MacroText({ full = "Grüße\n/e winkt.\r\n/Y LAUT" }) == "/s Grüße\n/e winkt.\n/Y LAUT", "chat lines")
    check(ns.MacroText({ full = "/wave\n/winken\n/p Hallo\n/g Hi" }) == "/wave\n/winken\n/p Hallo\n/g Hi", "other commands")
    check(ns.MacroText({ full = "/s Grüße" }) == "/s Grüße", "a single /s line")
    check(not ns.ParseFull("/e   "), "chat command without text")
    check(not ns.ParseFull("/ hi"), "a / without command")
    check(not ns.ParseFull("  \n "), "nothing at all")
    check(not ns.ParseFull("/p " .. string.rep("x", 300)), "an other command longer than a macro line")
    check(ns.ParseFull("/dance"), "an emote without text")
end)

test("long chat lines are split under 255 per macro line", function()
    local _, ns = fresh()
    for _, command in ipairs({ "/e", "/emote" }) do
        local macro = ns.MacroText({ full = command .. " " .. string.rep("wort ", 120) })
        for line in (macro .. "\n"):gmatch("(.-)\n") do
            check(#line <= 255 and line:sub(1, #command + 1) == command .. " ", command .. " line of " .. #line)
        end
    end
    local umlauts = string.rep("ä", 200)
    local parts = ns.SplitMessage(umlauts)
    check(#parts == 2 and parts[1] .. parts[2] == umlauts, "UTF-8 is never cut in half")
end)

test("random pick never repeats", function()
    local _, ns = fresh()
    local last
    for _ = 1, 30 do
        local entry = ns.PickRandom(1)
        check(entry and entry ~= last, "a different line each time")
        last = entry
    end
    ns.char.categories[2].entries = {}
    local none, message = ns.PickRandom(2)
    check(none == nil and message, "an empty category says so")
end)

-- Saved data per character ---------------------------------------------------------------------------

-- What 1.0.0 saved: one account-wide set of categories.
local function oldAccount()
    return {
        version = 1,
        categories = {
            { name = "Grüße", icon = "Spell_Holy_Renew", entries = { { short = "Hallo", full = "/s Hallo!" } } },
            { name = "Tanz", entries = { { short = "Tanzen", full = "/dance" } } },
        },
        button = { point = "TOP", relativePoint = "TOP", x = 10, y = -20, locked = true },
        minimap = { angle = 90, hide = true },
    }
end

test("a new player: example categories for each character", function()
    local _, ns = fresh("deDE")
    check(RPQuickResponseDB.version == 2 and RPQuickResponseDB.categories == nil, "the account holds no categories")
    check(RPQuickResponseDB.legacyCategories == nil, "and no 1.0.0 set")
    check(RPQuickResponseCharDB.version == 2 and #RPQuickResponseCharDB.categories == 4, "four examples for this character")
    check(type(RPQuickResponseCharDB.button) == "table" and RPQuickResponseCharDB.button.point == nil, "the button starts in the middle")
    check(ns.char.categories[1].name == "Begrüßung", "in the player's language")
end)

test("1.0.0 data: the first character keeps the lines, the account keeps the rest", function()
    local account = oldAccount()
    local _, ns = fresh("deDE", { account = account })
    check(account.version == 2, "account migrated to version 2")
    check(account.categories == nil, "categories moved off the account")
    check(type(account.legacyCategories) == "table" and #account.legacyCategories == 2, "the old set is kept as the starting set")
    check(#ns.char.categories == 2 and ns.char.categories[1].name == "Grüße", "this character got the old categories")
    check(ns.char.categories[1].entries[1].full == "/s Hallo!", "with their lines")
    check(ns.char.categories[1] ~= account.legacyCategories[1], "as a copy, not the same table")
    check(ns.char.button.point == "TOP" and ns.char.button.x == 10 and ns.char.button.locked == true, "the button stays where it was, locked")
    check(ns.char.button ~= account.button, "as the character's own copy")
    check(account.minimap.angle == 90 and account.minimap.hide == true, "minimap settings kept")
end)

test("1.0.0 data: every character gets its own copy, and they stay apart", function()
    local account = oldAccount()
    local _, first = fresh("deDE", { account = account })
    first.char.categories[1].entries[1].full = "/s Nur für den ersten."
    table.remove(first.char.categories, 2)
    local firstChar = RPQuickResponseCharDB

    -- Another character logs in later: same account table, no character table yet.
    local _, second = fresh("deDE", { account = account })
    check(#second.char.categories == 2, "the second character starts with the full old set")
    check(second.char.categories[1].entries[1].full == "/s Hallo!", "untouched by the first character's edits")
    second.char.categories[1].name = "Anders"
    check(firstChar.categories[1].name == "Grüße", "the second character's edits do not reach the first")

    first.char.button.x, first.char.button.locked = 300, false
    check(second.char.button.x == 10 and second.char.button.locked == true, "the second character's button starts where the 1.0.0 button was")
    second.char.button.y = -400
    check(firstChar.button.x == 300 and firstChar.button.y == -20, "moving one character's button leaves the other's alone")

    -- The first character logs in again with its own table.
    local _, again = fresh("deDE", { account = account, character = firstChar })
    check(#again.char.categories == 1 and again.char.categories[1].entries[1].full == "/s Nur für den ersten.", "the first character keeps its own")
    check(again.char.button.x == 300 and again.char.button.locked == false, "and its own button")
end)

test("a character table from before the button moved gets the account's button", function()
    local _, ns = fresh("enUS", {
        account = { version = 2, button = { point = "LEFT", relativePoint = "LEFT", x = 5, y = 6, locked = true } },
        character = { version = 1, categories = { { name = "Mine", entries = {} } } },
    })
    check(RPQuickResponseCharDB.version == 2, "character table migrated to version 2")
    check(ns.char.button.point == "LEFT" and ns.char.button.locked == true, "button copied from the account")
    check(ns.char.categories[1].name == "Mine", "its categories untouched")
end)

test("the drag saves to this character; reset clears only this character", function()
    local _, ns = fresh("enUS", { account = { version = 2, button = { point = "TOP", x = 1, y = 2 } } })
    local main = RPQuickResponseButton
    main.points = { { "BOTTOM", UIParent, "BOTTOM", 40, 50 } }
    main:Fire("OnDragStop")
    check(ns.char.button.point == "BOTTOM" and ns.char.button.x == 40, "drag saved on the character")
    check(RPQuickResponseDB.button.point == "TOP", "the account's starting point untouched")
    ns.ResetButtonPosition()
    check(ns.char.button.point == nil and RPQuickResponseDB.button.point == "TOP", "reset clears only the character's")
end)

test("a character's own lines drive the ring", function()
    local M, ns = fresh("enUS", { account = { version = 2 }, character = { version = 1, categories = {
        { name = "Only", entries = { { short = "Hi", full = "/s Hi from me" } } },
    } } })
    M.Click(RPQuickResponseButton, "LeftButton")
    local slots = {}
    for _, child in ipairs(RPQuickResponseRing.children) do
        if child.template:find("SecureActionButtonTemplate", 1, true) and child.group then slots[#slots + 1] = child end
    end
    check(RPQuickResponseRing:GetAttribute("rpqr-count") == 1, "one slot")
    M.Click(slots[1], "LeftButton")
    check(M.posted[1] == "/s Hi from me", "posts this character's line")
end)

-- The ring -------------------------------------------------------------------------------------------

local function slotsOf()
    local list = {}
    for _, child in ipairs(RPQuickResponseRing.children) do
        if child.template:find("SecureActionButtonTemplate", 1, true) and child.group then
            list[#list + 1] = child
        end
    end
    return list
end

local function macrosOf(ns, index)
    local set = {}
    for _, entry in ipairs(ns.char.categories[index].entries) do
        set[ns.MacroText(entry)] = true
    end
    return set
end

test("ring out of combat: open, random line, close", function()
    local M, ns = fresh()
    local main, ring = RPQuickResponseButton, RPQuickResponseRing
    check(not ring:IsShown(), "starts closed")
    M.Click(main, "LeftButton")
    check(ring:IsShown(), "left-click opens")
    check(M.bindings.ESCAPE == "RPQuickResponseRingClose", "Escape is bound while open")
    local slots = slotsOf()
    check(#slots == 4, "four slots")
    M.Click(slots[1], "LeftButton")
    check(#M.posted == 1 and macrosOf(ns, 1)[M.posted[1]], "one line of the category posted: " .. tostring(M.posted[1]))
    check(not ring:IsShown(), "the ring closes after posting")
    check(M.bindings.ESCAPE == nil, "Escape is free again")
    M.Click(main, "LeftButton")
    M.Click(main, "LeftButton")
    check(not ring:IsShown(), "the main button closes it again")
end)

test("ring: right-click shows the lines, one at a time", function()
    local M, ns = fresh()
    M.Click(RPQuickResponseButton, "LeftButton")
    local slots = slotsOf()
    M.Click(slots[2], "RightButton")
    check(slots[2].group:IsShown(), "lines of slot 2 shown")
    check(#M.posted == 0, "right-click posts nothing")
    M.Click(slots[3], "RightButton")
    check(not slots[2].group:IsShown() and slots[3].group:IsShown(), "switching closes the other list")
    local pill = slots[3].pills[2]
    check(pill and pill.text.text == ns.char.categories[3].entries[2].short, "a line shows its Short")
    M.Click(pill, "LeftButton")
    check(M.posted[1] == ns.MacroText(ns.char.categories[3].entries[2]), "the chosen line is posted")
    check(not RPQuickResponseRing:IsShown() and not slots[3].group:IsShown(), "ring and list close")
end)

test("ring in combat: opens, steps through every line, Escape closes", function()
    local M, ns = fresh()
    M.FireEvent("PLAYER_REGEN_DISABLED") -- still allowed to prepare
    M.inCombat = true
    local slots = slotsOf()
    local seen = {}
    for round = 1, 3 do
        M.Click(RPQuickResponseButton, "LeftButton")
        check(RPQuickResponseRing:IsShown(), "opens in combat (round " .. round .. ")")
        M.Click(slots[1], "LeftButton")
        check(not RPQuickResponseRing:IsShown(), "closes after posting in combat")
        seen[M.posted[#M.posted]] = true
    end
    local count = 0
    for macro in pairs(seen) do
        count = count + 1
        check(macrosOf(ns, 1)[macro], "a line of the category")
    end
    check(count == 3, "three clicks, three different lines")
    M.Click(RPQuickResponseButton, "LeftButton")
    M.Click(slots[4], "RightButton")
    check(slots[4].group:IsShown(), "the line list works in combat")
    M.PressBinding("ESCAPE")
    check(not RPQuickResponseRing:IsShown() and not slots[4].group:IsShown(), "Escape closes in combat")
end)

test("changes during combat wait for its end", function()
    local M, ns = fresh()
    M.FireEvent("PLAYER_REGEN_DISABLED")
    M.inCombat = true
    ns.char.categories[1].entries = { { short = "Hi", full = "/s Hi" } }
    ns.CloseRing() -- what the settings call after a change; must not touch secure frames now
    RPQuickResponseButton:Fire("OnDragStart") -- moving is refused quietly in combat
    M.inCombat = false
    M.FireEvent("PLAYER_REGEN_ENABLED")
    M.Click(RPQuickResponseButton, "LeftButton")
    M.Click(slotsOf()[1], "LeftButton")
    check(M.posted[1] == "/s Hi", "the new line after combat: " .. tostring(M.posted[1]))
end)

test("press-to-act setting posts once", function()
    local M = fresh()
    M.useKeyDown = true
    M.Click(RPQuickResponseButton, "LeftButton")
    M.Click(slotsOf()[1], "LeftButton")
    check(#M.posted == 1, "exactly one post")
end)

test("an empty category says so and posts nothing", function()
    local M, ns = fresh()
    ns.char.categories[2].entries = {}
    ns.CloseRing()
    M.Click(RPQuickResponseButton, "LeftButton")
    M.Click(slotsOf()[2], "LeftButton")
    check(#M.posted == 0, "nothing posted")
    check(M.printed[#M.printed] and M.printed[#M.printed]:find(ns.char.categories[2].name, 1, true), "a message names the category")
end)

-- Settings and icon browser ------------------------------------------------------------------------

test("settings window opens and the icon browser sets the icon", function()
    local M, ns = fresh("deDE", { iconData = root .. "/tests/icon_names.lua" })
    _G.GetMacroIcons = function(t) for _, id in ipairs({ 135953, 132333, 999999 }) do t[#t + 1] = id end end
    ns.OpenConfig()
    check(RPQuickResponseConfig:IsShown(), "settings open")
    -- The category's icon is the only way in: no name field, no extra button.
    local iconButtons = {}
    local function walk(frame)
        for _, child in ipairs(frame.children) do
            if child.kind == "Button" and child.hooks.OnClick == nil and child.scripts.OnClick and child.scripts.OnEnter
                and child.points[1] and child.points[1][2] == 254 then
                iconButtons[#iconButtons + 1] = child
            end
            if child.kind == "EditBox" and child.points[1] and child.points[1][2] == 258 then
                check(false, "no icon name field")
            end
            walk(child)
        end
    end
    walk(RPQuickResponseConfig)
    check(#iconButtons == 1, "one clickable icon")
    M.Click(iconButtons[1], "LeftButton")
    local browser = RPQuickResponseIconBrowser
    check(browser and browser:IsShown(), "clicking the icon opens the browser")
    browser.search.text = "battle shout"
    browser.search:Fire("OnTextChanged")
    check(browser.count.text == "1 Symbole", "search finds one: " .. tostring(browser.count.text))
    M.Click(browser.cells[1], "LeftButton")
    check(ns.char.categories[1].icon == "Ability_Warrior_BattleShout", "icon applied: " .. tostring(ns.char.categories[1].icon))
    check(not browser:IsShown(), "browser closes")
end)

-- Profiles -----------------------------------------------------------------------------------------

test("profiles: create, switch, edit, share between characters", function()
    local M, ns = fresh("enUS", { player = "Aldric" })
    check(ns.ActiveProfile() == nil and ns.Categories() == ns.char.categories, "starts on its own lines")
    check(ns.DefaultProfileName() == "Aldric", "default name is the character's")
    local name = ns.CreateProfile(ns.DefaultProfileName())
    check(name == "Aldric" and ns.ActiveProfile() == "Aldric", "created and in use")
    check(ns.Categories() ~= ns.char.categories and #ns.Categories() == #ns.char.categories, "a copy of the lines")
    check(ns.DefaultProfileName() == "Aldric 2", "next default gets a number: " .. ns.DefaultProfileName())
    local _, err = ns.CreateProfile("Aldric")
    check(err == 'A profile named "Aldric" already exists.', "no duplicates: " .. tostring(err))
    check(select(2, ns.CreateProfile("   ")) ~= nil, "no empty name")
    check(select(2, ns.CreateProfile(string.rep("x", 41))) ~= nil, "no overlong name")

    ns.Categories()[1].name = "Shared"
    check(ns.char.categories[1].name ~= "Shared", "edits go to the profile, not the own lines")
    check(ns.PickRandom(1) ~= nil, "the ring picks from the profile")

    -- Another character on the same account.
    local account, own = RPQuickResponseDB, RPQuickResponseCharDB
    local _, ns2 = fresh("enUS", { player = "Brenna", account = account })
    check(ns2.ActiveProfile() == nil, "another character keeps its own lines")
    check(ns2.ProfileNames()[1] == "Aldric", "and sees the profile")
    check(ns2.UseProfile("Aldric") and ns2.Categories()[1].name == "Shared", "it can switch to it")
    check(not ns2.UseProfile("Nobody"), "not to a profile that does not exist")
    check(ns2.UseProfile(nil) and ns2.Categories() == ns2.char.categories, "and back to its own")

    -- Brenna deletes the profile; Aldric is back on his own lines at the next login.
    check(ns2.DeleteProfile("Aldric") and #ns2.ProfileNames() == 0, "deleted")
    local _, ns3 = fresh("enUS", { player = "Aldric", account = account, character = own })
    check(ns3.ActiveProfile() == nil and ns3.char.categories[1].name ~= "Shared", "a deleted profile falls back to own lines")
end)

test("profiles: old saved tables load", function()
    local _, ns = fresh("enUS", { account = { version = 2, minimap = {}, button = {} },
        character = { version = 2, categories = { { name = "Mine", entries = {} } }, button = {} } })
    check(type(ns.db.profiles) == "table" and next(ns.db.profiles) == nil, "no profiles yet")
    check(ns.Categories()[1].name == "Mine", "own lines kept")
    local _, ns2 = fresh("enUS", { account = { version = 2, profiles = { Bad = "x", Good = { categories = { { name = "G" } } } } },
        character = { version = 2, profile = "Bad" } })
    check(ns2.db.profiles.Bad == nil and ns2.db.profiles.Good.categories[1].name == "G", "profiles cleaned")
    check(ns2.ActiveProfile() == nil, "a broken profile reference is dropped")
end)

test("profiles in the settings window", function()
    local M, ns = fresh("enUS", { player = "Aldric" })
    ns.OpenConfig()
    local dialog = StaticPopupDialogs.RPQR_NEW_PROFILE
    local box = setmetatable({}, { __index = function() return function() end end })
    box.GetText = function() return box.text end
    box.SetText = function(_, text) box.text = text end
    local popup = { EditBox = box }
    dialog.OnShow(popup)
    check(box.text == "Aldric", "the name box starts with the character's name")
    dialog.OnAccept(popup)
    check(ns.ActiveProfile() == "Aldric", "accepting creates the profile and switches")

    -- Find the profile button by its text, open the menu, pick the own lines.
    local profileButton
    local function walk(frame)
        if frame.kind == "Button" and frame.text == "Aldric" and frame.parent == RPQuickResponseConfig then
            profileButton = frame
        end
        for _, child in ipairs(frame.children) do walk(child) end
    end
    walk(RPQuickResponseConfig)
    check(profileButton ~= nil, "the profile button shows the profile")
    M.Click(profileButton, "LeftButton")
    local rows = {}
    local function rowsOf(frame)
        if frame.kind == "Button" and frame.text and frame.text.text and frame:IsVisible() and frame.check then
            rows[#rows + 1] = frame
        end
        for _, child in ipairs(frame.children) do rowsOf(child) end
    end
    rowsOf(RPQuickResponseConfig)
    check(#rows == 2 and rows[1].text.text == "Own lines (Aldric)" and rows[2].text.text == "Aldric", "menu lists own lines and the profile")
    M.Click(rows[1], "LeftButton")
    check(ns.ActiveProfile() == nil and profileButton.text == "Own lines (Aldric)", "switched back to own lines")

    StaticPopupDialogs.RPQR_DELETE_PROFILE.OnAccept(nil, "Aldric")
    check(#ns.ProfileNames() == 0, "deleted from the window")
end)

print(string.format("\n%d checks, %d failed", total, failures))
os.exit(failures == 0 and 0 or 1)
