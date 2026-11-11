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

local function fresh(locale, options)
    local M = dofile(root .. "/tests/mock.lua")
    M.Install(locale)
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
        for _, category in ipairs(ns.db.categories) do
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
    ns.db.categories[2].entries = {}
    local none, message = ns.PickRandom(2)
    check(none == nil and message, "an empty category says so")
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
    for _, entry in ipairs(ns.db.categories[index].entries) do
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
    check(pill and pill.text.text == ns.db.categories[3].entries[2].short, "a line shows its Short")
    M.Click(pill, "LeftButton")
    check(M.posted[1] == ns.MacroText(ns.db.categories[3].entries[2]), "the chosen line is posted")
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
    ns.db.categories[1].entries = { { short = "Hi", full = "/s Hi" } }
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
    ns.db.categories[2].entries = {}
    ns.CloseRing()
    M.Click(RPQuickResponseButton, "LeftButton")
    M.Click(slotsOf()[2], "LeftButton")
    check(#M.posted == 0, "nothing posted")
    check(M.printed[#M.printed] and M.printed[#M.printed]:find(ns.db.categories[2].name, 1, true), "a message names the category")
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
    check(ns.db.categories[1].icon == "Ability_Warrior_BattleShout", "icon applied: " .. tostring(ns.db.categories[1].icon))
    check(not browser:IsShown(), "browser closes")
end)

print(string.format("\n%d checks, %d failed", total, failures))
os.exit(failures == 0 and 0 or 1)
