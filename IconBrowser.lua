-- The icon browser: a scrolling grid of every icon the game offers for macros, searchable by
-- name (all words must appear, "holy heal" finds Spell_Holy_Heal) or by file ID.
-- Names come from IconData.lua (Dev/build_icons.lua); icons the list does not know still show, unnamed.
local _, ns = ...
local L = ns.L

local COLUMNS, ROWS = 10, 8
local CELL, GAP = 36, 4
local STEP = CELL + GAP
local GRID_WIDTH = COLUMNS * STEP - GAP
local GRID_HEIGHT = ROWS * STEP - GAP
local SEARCH_DELAY = 0.2

local browser
local allIcons -- { { id = fileID or nil, name = "Spell_Holy_Renew" or nil, search = "spell holy renew" }, ... }
local results = {}
local currentIcon
local onChoose
local offsetRow = 0
local pendingSearch

-- The index ---------------------------------------------------------------------------------------

local function BuildIndex()
    local names = {}
    if ns.ICON_NAMES then
        for id, name in ns.ICON_NAMES:gmatch("(%d+) ([^\n]+)") do
            names[tonumber(id)] = name
        end
        ns.ICON_NAMES = nil -- the names live on in the index
    end

    allIcons = {}
    local seen = {}
    local function Add(id, name)
        local key = id or (name and name:lower())
        if not key or seen[key] then
            return
        end
        seen[key] = true
        allIcons[#allIcons + 1] = { id = id, name = name, search = name and (name:lower():gsub("_", " ")) or "" }
    end

    local fromGame = {}
    if GetMacroIcons then
        GetMacroIcons(fromGame)
    end
    if GetMacroItemIcons then
        GetMacroItemIcons(fromGame)
    end
    for _, icon in ipairs(fromGame) do
        if type(icon) == "number" then
            Add(icon, names[icon])
        elseif type(icon) == "string" then
            Add(nil, (icon:match("([^\\/]+)$"):gsub("%.[Bb][Ll][Pp]$", "")))
        end
    end

    -- No macro icon list in this client: offer every icon the name list knows.
    if #allIcons == 0 then
        for id, name in pairs(names) do
            Add(id, name)
        end
        table.sort(allIcons, function(a, b) return a.search < b.search end)
    end
end

local function FindIcon(value)
    if value == nil or value == "" then
        return nil
    end
    local id = tonumber(value)
    local name = not id and tostring(value):match("([^\\/]+)$"):lower()
    for _, icon in ipairs(allIcons) do
        if (id and icon.id == id) or (name and icon.name and icon.name:lower() == name) then
            return icon
        end
    end
end

local function ValueOf(icon)
    return icon.name or tostring(icon.id)
end

local function TextureOf(icon)
    return icon.id or ns.IconPath(icon.name)
end

-- Searching ---------------------------------------------------------------------------------------

local function Matches(icon, words, number)
    if number and icon.id == number then
        return true
    end
    if icon.search == "" then
        return false
    end
    for _, word in ipairs(words) do
        if not icon.search:find(word, 1, true) then
            return false
        end
    end
    return true
end

local function UpdateGrid()
    local first = offsetRow * COLUMNS
    for i, cell in ipairs(browser.cells) do
        local icon = results[first + i]
        cell.data = icon
        if icon then
            cell.icon:SetTexture(TextureOf(icon))
            cell.selected:SetShown(icon == currentIcon)
            cell:Show()
        else
            cell:Hide()
        end
    end
end

local function RunSearch(query)
    query = ns.Trim(query or ""):lower()
    wipe(results)
    if query == "" then
        -- The category's current icon comes first.
        if currentIcon then
            results[1] = currentIcon
        end
        for _, icon in ipairs(allIcons) do
            if icon ~= currentIcon then
                results[#results + 1] = icon
            end
        end
    else
        local number = tonumber(query)
        local words = {}
        for word in (query:gsub("_", " ")):gmatch("%S+") do
            words[#words + 1] = word
        end
        for _, icon in ipairs(allIcons) do
            if Matches(icon, words, number) then
                results[#results + 1] = icon
            end
        end
    end

    browser.count:SetText(#results == 0 and L.ICON_NONE or L.ICON_COUNT:format(#results))
    browser.scrollChild:SetHeight(math.max(1, math.ceil(#results / COLUMNS) * STEP))
    browser.scroll:SetVerticalScroll(0)
    offsetRow = 0
    UpdateGrid()
end

-- Choosing ----------------------------------------------------------------------------------------

local function Choose(icon)
    -- Hiding clears onChoose (OnHide), so take it first.
    local choose = onChoose
    browser:Hide()
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
    if choose then
        choose(ValueOf(icon))
    end
end

local function CellOnEnter(self)
    local icon = self.data
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if icon.name then
        GameTooltip:SetText(icon.name, unpack(ns.COLOR.labelHot))
    else
        GameTooltip:SetText(L.ICON_UNNAMED, 0.6, 0.6, 0.6)
    end
    if icon.id then
        GameTooltip:AddLine(L.ICON_FILE_ID:format(icon.id), 1, 1, 1)
    end
    GameTooltip:Show()
end

local function Scroll(delta)
    local scroll = browser.scroll
    local target = scroll:GetVerticalScroll() - delta * STEP * 2
    scroll:SetVerticalScroll(math.max(0, math.min(target, scroll:GetVerticalScrollRange())))
end

-- The window --------------------------------------------------------------------------------------

local function CreateBrowser(parent)
    browser = CreateFrame("Frame", "RPQuickResponseIconBrowser", parent, "BasicFrameTemplateWithInset")
    browser:SetSize(GRID_WIDTH + 58, GRID_HEIGHT + 104)
    browser:SetFrameStrata("DIALOG")
    browser:SetToplevel(true)
    browser:SetClampedToScreen(true)
    browser:SetMovable(true)
    browser:EnableMouse(true)
    browser:RegisterForDrag("LeftButton")
    browser:SetScript("OnDragStart", browser.StartMoving)
    browser:SetScript("OnDragStop", browser.StopMovingOrSizing)
    browser:Hide()

    local title = browser.TitleText or browser:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, -5)
    title:SetText(L.ICON_BROWSER_TITLE)

    local search = CreateFrame("EditBox", nil, browser, "SearchBoxTemplate")
    search:SetSize(GRID_WIDTH - 110, 20)
    search:SetPoint("TOPLEFT", 20, -32)
    search:SetAutoFocus(false)
    if search.Instructions then
        search.Instructions:SetText(L.ICON_SEARCH)
    end
    search:HookScript("OnTextChanged", function(self)
        if pendingSearch then
            pendingSearch:Cancel()
        end
        local text = self:GetText()
        pendingSearch = C_Timer.NewTimer(SEARCH_DELAY, function()
            pendingSearch = nil
            RunSearch(text)
        end)
    end)
    search:SetScript("OnEnterPressed", function(self)
        if #results == 1 then
            Choose(results[1])
        else
            self:ClearFocus()
        end
    end)
    browser.search = search

    browser.count = browser:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    browser.count:SetPoint("LEFT", search, "RIGHT", 12, 0)
    browser.count:SetPoint("RIGHT", browser, "RIGHT", -16, 0)
    browser.count:SetJustifyH("RIGHT")

    -- The scroll frame only drives the scroll bar; the cells sit on top and show the visible rows.
    local scroll = CreateFrame("ScrollFrame", nil, browser, "UIPanelScrollFrameTemplate")
    scroll:SetSize(GRID_WIDTH, GRID_HEIGHT)
    scroll:SetPoint("TOPLEFT", 16, -62)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(GRID_WIDTH, 1)
    scroll:SetScrollChild(child)
    scroll:HookScript("OnVerticalScroll", function(self)
        local row = math.floor(self:GetVerticalScroll() / STEP + 0.5)
        if row ~= offsetRow then
            offsetRow = row
            UpdateGrid()
        end
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
    browser.scroll, browser.scrollChild = scroll, child

    browser.cells = {}
    for i = 1, COLUMNS * ROWS do
        local cell = CreateFrame("Button", nil, browser)
        cell:SetSize(CELL, CELL)
        local column, row = (i - 1) % COLUMNS, math.floor((i - 1) / COLUMNS)
        cell:SetPoint("TOPLEFT", scroll, "TOPLEFT", column * STEP, -row * STEP)
        cell:SetFrameLevel(scroll:GetFrameLevel() + 5)
        cell.icon = cell:CreateTexture(nil, "ARTWORK")
        cell.icon:SetAllPoints()
        cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        cell.selected = cell:CreateTexture(nil, "OVERLAY")
        cell.selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        cell.selected:SetBlendMode("ADD")
        cell.selected:SetAllPoints()
        cell:EnableMouseWheel(true)
        cell:SetScript("OnMouseWheel", function(_, delta) Scroll(delta) end)
        cell:SetScript("OnEnter", CellOnEnter)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cell:SetScript("OnClick", function(self) Choose(self.data) end)
        browser.cells[i] = cell
    end

    browser:SetScript("OnHide", function()
        if pendingSearch then
            pendingSearch:Cancel()
            pendingSearch = nil
        end
        onChoose = nil
        GameTooltip:Hide()
    end)
end

-- Opens the browser next to `anchor`. `current` is the icon in use (name, path or file ID);
-- `choose(value)` gets the picked icon's name, or its file ID when the name is unknown.
function ns.OpenIconBrowser(anchor, current, choose)
    if not browser then
        CreateBrowser(anchor)
    end
    if not allIcons then
        BuildIndex()
    end
    currentIcon = FindIcon(current)
    onChoose = choose
    browser:ClearAllPoints()
    browser:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    browser.search:SetText("")
    if pendingSearch then
        pendingSearch:Cancel()
        pendingSearch = nil
    end
    RunSearch("")
    browser:Show()
    browser:Raise()
end

function ns.CloseIconBrowser()
    if browser then
        browser:Hide()
    end
end
