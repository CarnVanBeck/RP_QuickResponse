-- Saved data, turning "Full" into a macro, slash commands, start-up.
local addonName, ns = ...
local L = ns.L

ns.MAX_CATEGORIES = 12
ns.DB_VERSION = 1

-- Migrations: STEPS[n] turns a version n-1 table into version n.
-- Players' saved data must survive every update: never drop or reinterpret a field
-- without bumping DB_VERSION and adding a step here.
local STEPS = {}

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
    local category = ns.db.categories[categoryIndex]
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

local function Sanitize(db)
    local categories = {}
    for _, category in ipairs(db.categories) do
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
    db.categories = categories
end

local function InitDB()
    local db = RPQuickResponseDB
    if type(db) ~= "table" then
        db = {}
    end
    if type(db.categories) ~= "table" then
        db.categories = ns.DefaultCategories()
    end
    db.version = db.version or ns.DB_VERSION
    for version = db.version + 1, ns.DB_VERSION do
        if STEPS[version] then
            STEPS[version](db)
        end
        db.version = version
    end
    Sanitize(db)
    db.button = type(db.button) == "table" and db.button or {}
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    if db.minimap.angle == nil then
        db.minimap.angle = 225
    end
    RPQuickResponseDB = db
    ns.db = db
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
