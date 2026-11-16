-- Saved data, turning "Full" into a macro, slash commands, start-up.
local addonName, ns = ...
local L = ns.L

ns.MAX_CATEGORIES = 12

-- Two saved tables:
--   RPQuickResponseDB      (account) the minimap button; the profiles (named sets of
--                          categories any character can use); the 1.0.0 button and categories
--                          as the starting point for characters that have not logged in since;
--   RPQuickResponseCharDB  (character) that character's own categories and lines, the profile
--                          it uses instead (if any), its button's position and lock.
-- Migrations: STEPS[n] turns a version n-1 table into version n.
-- Players' saved data must survive every update: never drop or reinterpret a field
-- without bumping the version and adding a step here.
ns.DB_VERSION = 2
ns.CHAR_DB_VERSION = 2

local STEPS = {
    -- 1.0.0 kept the categories account-wide. They become the starting set every character
    -- copies on its first login since (see InitCharDB), so nobody loses their lines.
    [2] = function(db)
        if type(db.categories) == "table" then
            db.legacyCategories = db.categories
        end
        db.categories = nil
    end,
}
local function CopyButton(button)
    local copy = {}
    for _, key in ipairs({ "point", "relativePoint", "x", "y", "locked" }) do
        copy[key] = type(button) == "table" and button[key] or nil
    end
    return copy
end

local CHAR_STEPS = {
    -- The button became per character: start where the account-wide button was.
    [2] = function(char)
        if type(char.button) ~= "table" then
            char.button = CopyButton(RPQuickResponseDB and RPQuickResponseDB.button)
        end
    end,
}

-- A chat message holds 255 bytes, and so does a macro line; "/s " takes three of them.
local MAX_MESSAGE_LENGTH = 250
local MAX_MACRO_LINE = 255
-- Chat commands whose text is split into several lines when it is too long.
local CHAT_COMMANDS = { s = true, say = true, e = true, em = true, emote = true, me = true, y = true, yell = true }

local function Trim(s)
    return (s:match("^%s*(.-)%s*$"))
end
ns.Trim = Trim

function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd19a4dRP - Quick Response|r: " .. tostring(msg))
end

-- Turns the text of a "Full" field into macro lines. Any command works (/s, /e, /y, /wave,
-- /p, ...), since a click runs them like the player's own macro; a line without a command is said.
-- Returns { { command = "/e", text = "...", chat = true } | { line = "/wave" }, ... },
-- or nil and a readable error.
function ns.ParseFull(full)
    if type(full) ~= "string" then
        return nil, L.ERR_NO_TEXT
    end
    local lines = {}
    local lineNumber = 0
    for raw in (full .. "\n"):gmatch("(.-)\r?\n") do
        lineNumber = lineNumber + 1
        local line = Trim(raw)
        if line ~= "" then
            if line:sub(1, 1) == "/" then
                local command, rest = line:match("^(/%S*)%s*(.*)$")
                if command == "/" then
                    return nil, L.ERR_NO_COMMAND:format(lineNumber)
                end
                if CHAT_COMMANDS[command:sub(2):lower()] then
                    local text = Trim(rest)
                    if text == "" then
                        return nil, L.ERR_EMPTY_LINE:format(lineNumber)
                    end
                    lines[#lines + 1] = { command = command, text = text, chat = true }
                elseif #line > MAX_MACRO_LINE then
                    return nil, L.ERR_LINE_TOO_LONG:format(lineNumber, MAX_MACRO_LINE)
                else
                    lines[#lines + 1] = { line = line }
                end
            else
                lines[#lines + 1] = { command = "/s", text = line, chat = true }
            end
        end
    end
    if #lines == 0 then
        return nil, L.ERR_NO_TEXT
    end
    return lines
end

-- Longer text is split at a space,
-- or, if there is none, before a UTF-8 character so umlauts never break.
function ns.SplitMessage(text, maxLength)
    maxLength = math.min(maxLength or MAX_MESSAGE_LENGTH, MAX_MESSAGE_LENGTH)
    local parts = {}
    while #text > maxLength do
        local cut = text:sub(1, maxLength + 1):match("^.*()%s")
        if not cut or cut < 2 then
            cut = maxLength + 1
            while cut > 2 do
                local byte = text:byte(cut)
                if byte < 0x80 or byte >= 0xC0 then
                    break
                end
                cut = cut - 1
            end
        end
        parts[#parts + 1] = Trim(text:sub(1, cut - 1))
        text = Trim(text:sub(cut))
    end
    if text ~= "" then
        parts[#parts + 1] = text
    end
    return parts
end

-- The macro that posts an entry. Lines are never sent by the addon itself: WoW Forever blocks
-- addon chat to /s, /e and /y, so the ring's buttons are secure macro buttons, and a click runs
-- this text exactly like one of the player's own macros. Long chat lines are split.
function ns.MacroText(entry)
    local messages, err = ns.ParseFull(entry and entry.full)
    if not messages then
        return nil, err
    end
    local lines = {}
    for _, message in ipairs(messages) do
        if message.chat then
            for _, part in ipairs(ns.SplitMessage(message.text, MAX_MACRO_LINE - #message.command - 1)) do
                lines[#lines + 1] = message.command .. " " .. part
            end
        else
            lines[#lines + 1] = message.line
        end
    end
    return table.concat(lines, "\n")
end

function ns.UsableEntries(category)
    local usable = {}
    for index, entry in ipairs(category.entries) do
        if ns.ParseFull(entry.full) then
            usable[#usable + 1] = index
        end
    end
    return usable
end

-- A random line from the category, never the same one twice in a row when there is a choice.
local lastPick = setmetatable({}, { __mode = "k" })

-- Returns the entry, or nil and the message to show.
function ns.PickRandom(categoryIndex)
    local category = ns.Categories()[categoryIndex]
    if not category then
        return nil
    end
    local pool = ns.UsableEntries(category)
    if #pool == 0 then
        return nil, L.MSG_CATEGORY_EMPTY:format(category.name)
    end
    local pick = pool[1]
    if #pool > 1 then
        repeat
            pick = pool[math.random(#pool)]
        until pick ~= lastPick[category]
    end
    lastPick[category] = pick
    return category.entries[pick]
end

-- Saved data -------------------------------------------------------------------------------

-- A clean copy of a list of categories: only the fields we know, in the types we expect.
local function CleanCategories(list)
    local categories = {}
    for _, category in ipairs(type(list) == "table" and list or {}) do
        if type(category) == "table" then
            local entries = {}
            for _, entry in ipairs(type(category.entries) == "table" and category.entries or {}) do
                if type(entry) == "table" then
                    entries[#entries + 1] = { short = tostring(entry.short or ""), full = tostring(entry.full or "") }
                end
            end
            categories[#categories + 1] = {
                name = tostring(category.name or L.NEW_CATEGORY),
                icon = category.icon,
                entries = entries,
            }
        end
    end
    return categories
end
ns.CleanCategories = CleanCategories

local function Migrate(db, steps, target)
    db.version = db.version or target -- a new table starts at the current shape
    for version = db.version + 1, target do
        if steps[version] then
            steps[version](db)
        end
        db.version = version
    end
end

local function InitDB()
    local db = RPQuickResponseDB
    if type(db) ~= "table" then
        db = {}
    end
    Migrate(db, STEPS, ns.DB_VERSION)
    db.button = type(db.button) == "table" and db.button or {}
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    -- Profiles came in 1.2.0 as a new field: older tables simply have none yet.
    local profiles = {}
    for name, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
        if type(name) == "string" and type(profile) == "table" then
            profiles[name] = { categories = CleanCategories(profile.categories) }
        end
    end
    db.profiles = profiles
    if db.minimap.angle == nil then
        db.minimap.angle = 225
    end
    RPQuickResponseDB = db
    ns.db = db
end

-- This character's categories: its own; on its first login a copy of the 1.0.0 account-wide set
-- if there is one, otherwise the examples in the player's language.
local function InitCharDB()
    local char = RPQuickResponseCharDB
    if type(char) ~= "table" then
        char = {}
    end
    Migrate(char, CHAR_STEPS, ns.CHAR_DB_VERSION)
    if type(char.categories) ~= "table" then
        if type(ns.db.legacyCategories) == "table" then
            char.categories = CleanCategories(ns.db.legacyCategories)
        else
            char.categories = ns.DefaultCategories()
        end
    end
    char.categories = CleanCategories(char.categories)
    -- A character new since the button moved: start where the account-wide button was.
    if type(char.button) ~= "table" then
        char.button = CopyButton(ns.db.button)
    end
    -- A profile deleted on another character: back to this character's own lines.
    if type(char.profile) ~= "string" or not ns.db.profiles[char.profile] then
        char.profile = nil
    end
    RPQuickResponseCharDB = char
    ns.char = char
end

-- Profiles ---------------------------------------------------------------------------------
-- A profile is an account-wide set of categories. A character uses either its own categories
-- (char.categories, always kept) or one profile (char.profile names it); edits go to whichever
-- is in use, so every character on that profile sees them.

local PROFILE_NAME_MAX = 40

-- The categories in use: the profile's, or the character's own.
function ns.Categories()
    local profile = ns.char.profile and ns.db.profiles[ns.char.profile]
    return profile and profile.categories or ns.char.categories
end

-- The name of the profile in use, or nil for the character's own lines.
function ns.ActiveProfile()
    return ns.char.profile
end

function ns.ProfileNames()
    local names = {}
    for name in pairs(ns.db.profiles) do
        names[#names + 1] = name
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

-- The character's name, or "Name 2", "Name 3", ... when that profile already exists.
function ns.DefaultProfileName()
    local base = UnitName and UnitName("player") or nil
    if not base or base == "" then
        base = L.PROFILE_DEFAULT_NAME
    end
    local name, n = base, 1
    while ns.db.profiles[name] do
        n = n + 1
        name = base .. " " .. n
    end
    return name
end

-- nil: the character's own lines.
function ns.UseProfile(name)
    if name ~= nil and not ns.db.profiles[name] then
        return false
    end
    ns.char.profile = name
    return true
end

-- A new profile starts as a copy of the lines in use, and the character switches to it.
-- Returns the name, or nil and why not.
function ns.CreateProfile(name)
    name = Trim(tostring(name or ""))
    if name == "" then
        return nil, L.ERR_PROFILE_NO_NAME
    end
    if #name > PROFILE_NAME_MAX then
        return nil, L.ERR_PROFILE_TOO_LONG:format(PROFILE_NAME_MAX)
    end
    if ns.db.profiles[name] then
        return nil, L.ERR_PROFILE_EXISTS:format(name)
    end
    ns.db.profiles[name] = { categories = CleanCategories(ns.Categories()) }
    ns.char.profile = name
    return name
end

-- Characters on a deleted profile go back to their own lines (this one now, others at login).
function ns.DeleteProfile(name)
    if not ns.db.profiles[name] then
        return false
    end
    ns.db.profiles[name] = nil
    if ns.char.profile == name then
        ns.char.profile = nil
    end
    return true
end

-- Start-up, slash commands, the AddOns compartment ------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
-- If the game ever blocks something of ours, say which call it was, so it can be fixed.
events:RegisterEvent("ADDON_ACTION_BLOCKED")
events:RegisterEvent("ADDON_ACTION_FORBIDDEN")
events:SetScript("OnEvent", function(self, event, name, blockedCall)
    if name ~= addonName then
        return
    end
    if event ~= "ADDON_LOADED" then
        ns.Print(L.MSG_BLOCKED:format(tostring(blockedCall)))
        return
    end
    self:UnregisterEvent("ADDON_LOADED")
    InitDB()
    InitCharDB()
    ns.CreateMainButton()
    ns.CreateMinimapButton()
end)

SLASH_RPQUICKRESPONSE1 = "/rpqr"
SLASH_RPQUICKRESPONSE2 = "/quickresponse"
SlashCmdList.RPQUICKRESPONSE = function(msg)
    msg = Trim(msg or ""):lower()
    if msg == "reset" then
        ns.ResetButtonPosition()
        ns.Print(L.MSG_POSITION_RESET)
    elseif msg == "help" or msg == "?" then
        ns.Print(L.MSG_HELP)
    else
        ns.ToggleConfig()
    end
end

function RPQuickResponse_OnAddonCompartmentClick()
    ns.ToggleConfig()
end
