-- The settings window: the profile in use along the top, categories on the left, the chosen category's lines in the middle,
-- the chosen line's Short and Full on the right, button options along the bottom.
local _, ns = ...
local L = ns.L

local WIDTH, HEIGHT = 760, 532
local TOP = 32 -- room for the profile row
local ROW_HEIGHT = 22
local SHORT_MAX = 40
local FULL_MAX = 2000

local frame
local categoryList, entryList
local categoryPanel, entryPanel, noEntryText
local nameBox, iconPreview
local shortBox, fullBox, statusText
local lockCheck, minimapCheck
local profileButton, profileMenu, deleteProfileButton

local selectedCategory, selectedEntry
local dirty = false
local loading = false

local function Categories() return ns.Categories() end
local function CurrentCategory() return selectedCategory and Categories()[selectedCategory] end
local function CurrentEntry()
    local category = CurrentCategory()
    return category and selectedEntry and category.entries[selectedEntry]
end

-- Small builders --------------------------------------------------------------------------------

local INSET_BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local function Inset(parent, width, height)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    box:SetBackdrop(INSET_BACKDROP)
    box:SetBackdropColor(0, 0, 0, 0.5)
    box:SetBackdropBorderColor(0.5, 0.5, 0.5)
    return box
end

local function Label(parent, text, template)
    local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    return label
end

local function Button(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function Input(parent, width, maxLetters)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(maxLetters or 0)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

local function MultiLineInput(parent, width, height)
    local box = Inset(parent, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 7, -7)
    scroll:SetPoint("BOTTOMRIGHT", -28, 7)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(width - 38)
    edit:SetHeight(height - 14)
    edit:SetMaxLetters(FULL_MAX)
    edit:SetTextInsets(0, 0, 2, 2)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    -- Keep the cursor in view while typing.
    edit:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
        local offset, visible = scroll:GetVerticalScroll(), scroll:GetHeight()
        y = -y
        if y < offset then
            scroll:SetVerticalScroll(y)
        elseif y + cursorHeight > offset + visible then
            scroll:SetVerticalScroll(y + cursorHeight - visible)
        end
    end)
    scroll:SetScrollChild(edit)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    box.edit = edit
    return box
end

local function Check(parent, text, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    local label = Label(check, text, "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 2, 1)
    check:SetScript("OnClick", function(self) onClick(self:GetChecked()) end)
    return check
end

-- A scrolling list of rows; onSelect(index) when one is clicked.
local function List(parent, width, height, onSelect)
    local box = Inset(parent, width, height)
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", -27, 5)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width - 34, 1)
    scroll:SetScrollChild(child)
    box.rows = {}

    function box:SetItems(items, selected, labelOf)
        for i, item in ipairs(items) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, child)
                row:SetSize(width - 34, ROW_HEIGHT)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                row.selected = row:CreateTexture(nil, "BACKGROUND")
                row.selected:SetAllPoints()
                row.selected:SetColorTexture(0.82, 0.58, 0.30, 0.3)
                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", 6, 0)
                row.text:SetPoint("RIGHT", -4, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetWordWrap(false)
                row:SetScript("OnClick", function(r) onSelect(r.index) end)
                self.rows[i] = row
            end
            row.index = i
            row.text:SetText(labelOf(item))
            row.selected:SetShown(i == selected)
            row:Show()
        end
        for i = #items + 1, #self.rows do
            self.rows[i]:Hide()
        end
        child:SetHeight(math.max(1, #items * ROW_HEIGHT))
    end

    return box
end

-- Showing the data -------------------------------------------------------------------------------

local function SetStatus(text, good)
    statusText:SetText(text or "")
    if good then
        statusText:SetTextColor(0.4, 0.9, 0.4)
    else
        statusText:SetTextColor(1, 0.35, 0.3)
    end
end

local function EntryLabel(entry)
    if ns.ParseFull(entry.full) then
        return entry.short
    end
    return "|cff888888" .. entry.short .. "|r"
end

local function RefreshLists()
    local categories = Categories()
    if selectedCategory and selectedCategory > #categories then
        selectedCategory = #categories > 0 and #categories or nil
    end
    if not selectedCategory and #categories > 0 then
        selectedCategory = 1
    end
    categoryList:SetItems(categories, selectedCategory, function(category) return category.name end)

    local category = CurrentCategory()
    categoryPanel:SetShown(category ~= nil)
    if not category then
        return
    end
    if selectedEntry and selectedEntry > #category.entries then
        selectedEntry = nil
    end
    entryList:SetItems(category.entries, selectedEntry, EntryLabel)
end

local function LoadCategory()
    local category = CurrentCategory()
    if not category then
        return
    end
    nameBox:SetText(category.name)
    nameBox:SetCursorPosition(0)
    iconPreview:SetTexture(ns.IconPath(category.icon))
end

local function LoadEntry()
    local entry = CurrentEntry()
    entryPanel:SetShown(entry ~= nil)
    noEntryText:SetShown(entry == nil)
    SetStatus(nil)
    dirty = false
    if not entry then
        return
    end
    loading = true
    shortBox:SetText(entry.short)
    shortBox:SetCursorPosition(0)
    fullBox.edit:SetText(entry.full)
    fullBox.edit:SetCursorPosition(0)
    loading = false
    local _, err = ns.ParseFull(entry.full)
    if err and entry.full ~= "" then
        SetStatus(err)
    end
end

-- Saving -----------------------------------------------------------------------------------------

-- Writes the editor back into the chosen line. Returns false (and shows why) when it breaks the rules.
local function CommitEntry()
    local entry = CurrentEntry()
    if not entry or not dirty then
        return true
    end
    local short = ns.Trim(shortBox:GetText())
    if short == "" then
        SetStatus(L.ERR_NO_SHORT)
        return false
    end
    local full = fullBox.edit:GetText():gsub("%s+$", "")
    local ok, err = ns.ParseFull(full)
    if not ok then
        SetStatus(err)
        return false
    end
    entry.short, entry.full = short, full
    dirty = false
    SetStatus(L.CONFIG_SAVED, true)
    ns.CloseRing()
    RefreshLists()
    return true
end

local function SaveCategoryName()
    local category = CurrentCategory()
    if not category then
        return
    end
    local name = ns.Trim(nameBox:GetText())
    if name ~= "" and name ~= category.name then
        category.name = name
        ns.CloseRing()
        RefreshLists()
    end
    nameBox:SetText(category.name)
end

-- Actions ----------------------------------------------------------------------------------------

local function BrowseIcons()
    local category = CurrentCategory()
    if not category then
        return
    end
    ns.OpenIconBrowser(frame, category.icon, function(icon)
        category.icon = icon
        ns.CloseRing()
        if CurrentCategory() == category then
            LoadCategory()
        end
    end)
end

local function SelectCategory(index)
    if index == selectedCategory or not CommitEntry() then
        return
    end
    ns.CloseIconBrowser()
    selectedCategory, selectedEntry = index, nil
    RefreshLists()
    LoadCategory()
    LoadEntry()
end

local function SelectEntry(index)
    if index == selectedEntry or not CommitEntry() then
        return
    end
    selectedEntry = index
    RefreshLists()
    LoadEntry()
end

local function NewCategory()
    if not CommitEntry() then
        return
    end
    local categories = Categories()
    if #categories >= ns.MAX_CATEGORIES then
        ns.Print(L.MSG_MAX_CATEGORIES:format(ns.MAX_CATEGORIES))
        return
    end
    categories[#categories + 1] = { name = L.NEW_CATEGORY, icon = "INV_Misc_QuestionMark", entries = {} }
    selectedCategory, selectedEntry = #categories, nil
    ns.CloseRing()
    RefreshLists()
    LoadCategory()
    LoadEntry()
    nameBox:SetFocus()
    nameBox:HighlightText()
end

local function DeleteCategory(index)
    ns.CloseIconBrowser()
    table.remove(Categories(), index)
    selectedEntry = nil
    dirty = false
    ns.CloseRing()
    RefreshLists()
    LoadCategory()
    LoadEntry()
end

StaticPopupDialogs["RPQR_DELETE_CATEGORY"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, index) DeleteCategory(index) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function AskDeleteCategory()
    local category = CurrentCategory()
    if category then
        StaticPopup_Show("RPQR_DELETE_CATEGORY", L.CONFIRM_DELETE_CATEGORY:format(category.name), nil, selectedCategory)
    end
end

local function MoveCategory(step)
    local categories = Categories()
    local from = selectedCategory
    local to = from and from + step
    if not to or to < 1 or to > #categories then
        return
    end
    categories[from], categories[to] = categories[to], categories[from]
    selectedCategory = to
    ns.CloseRing()
    RefreshLists()
end

local function NewEntry()
    local category = CurrentCategory()
    if not category or not CommitEntry() then
        return
    end
    category.entries[#category.entries + 1] = { short = L.NEW_ENTRY, full = "" }
    selectedEntry = #category.entries
    RefreshLists()
    LoadEntry()
    shortBox:SetFocus()
    shortBox:HighlightText()
end

local function DeleteEntry()
    local category = CurrentCategory()
    if not category or not selectedEntry then
        return
    end
    table.remove(category.entries, selectedEntry)
    selectedEntry = nil
    dirty = false
    ns.CloseRing()
    RefreshLists()
    LoadEntry()
end

-- Profiles ---------------------------------------------------------------------------------------

local function OwnLabel()
    return L.PROFILE_OWN:format(UnitName and UnitName("player") or "")
end

local function RefreshProfile()
    local active = ns.ActiveProfile()
    profileButton:SetText(active or OwnLabel())
    deleteProfileButton:SetEnabled(active ~= nil)
end

-- Shows another set of lines: the editor starts over on its first category.
local function ProfileChanged()
    ns.CloseIconBrowser()
    selectedCategory, selectedEntry = nil, nil
    dirty = false
    ns.CloseRing()
    RefreshProfile()
    RefreshLists()
    LoadCategory()
    LoadEntry()
end

local function SwitchProfile(name)
    profileMenu:Hide()
    if name == ns.ActiveProfile() or not CommitEntry() then
        return
    end
    ns.UseProfile(name)
    ProfileChanged()
end

-- A small drop-down: the character's own lines, then every profile on the account.
local MENU_ROW = 20
local function CreateProfileMenu()
    profileMenu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    profileMenu:SetBackdrop(INSET_BACKDROP)
    profileMenu:SetBackdropColor(0.05, 0.04, 0.03, 0.97)
    profileMenu:SetBackdropBorderColor(unpack(ns.COLOR.rim))
    profileMenu:SetFrameLevel(frame:GetFrameLevel() + 60)
    profileMenu:SetPoint("TOPLEFT", profileButton, "BOTTOMLEFT", 0, -2)
    profileMenu:EnableMouse(true)
    profileMenu:Hide()
    profileMenu.rows = {}
end

local function ShowProfileMenu()
    if profileMenu:IsShown() then
        profileMenu:Hide()
        return
    end
    local items = { { label = OwnLabel() } }
    for _, name in ipairs(ns.ProfileNames()) do
        items[#items + 1] = { name = name, label = name }
    end
    local active = ns.ActiveProfile()
    local width = profileButton:GetWidth()
    for i, item in ipairs(items) do
        local row = profileMenu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, profileMenu)
            row:SetHeight(MENU_ROW)
            row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * MENU_ROW)
            row:SetPoint("TOPRIGHT", -5, -5 - (i - 1) * MENU_ROW)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            row.check = row:CreateTexture(nil, "OVERLAY")
            row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            row.check:SetSize(16, 16)
            row.check:SetPoint("LEFT", 2, 0)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 20, 0)
            row.text:SetPoint("RIGHT", -4, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetScript("OnClick", function(r) SwitchProfile(r.profile) end)
            profileMenu.rows[i] = row
        end
        row.profile = item.name
        row.text:SetText(item.label)
        row.check:SetShown(item.name == active)
        row:Show()
    end
    for i = #items + 1, #profileMenu.rows do
        profileMenu.rows[i]:Hide()
    end
    profileMenu:SetSize(width, #items * MENU_ROW + 10)
    profileMenu:Show()
end

local function ProfileEditBox(popup)
    return popup.EditBox or popup.editBox
end

local function AcceptNewProfile(popup)
    local name, err = ns.CreateProfile(ProfileEditBox(popup):GetText())
    if not name then
        ns.Print(err)
        return
    end
    ns.Print(L.MSG_PROFILE_CREATED:format(name))
    ProfileChanged()
end

StaticPopupDialogs["RPQR_NEW_PROFILE"] = {
    text = "%s",
    button1 = ACCEPT or OKAY,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
        local box = ProfileEditBox(self)
        box:SetText(ns.DefaultProfileName())
        box:HighlightText()
        box:SetFocus()
    end,
    OnAccept = function(self) AcceptNewProfile(self) end,
    EditBoxOnEnterPressed = function(self)
        local popup = self:GetParent()
        AcceptNewProfile(popup)
        popup:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function AskNewProfile()
    profileMenu:Hide()
    if CommitEntry() then
        StaticPopup_Show("RPQR_NEW_PROFILE", L.CONFIRM_NEW_PROFILE)
    end
end

StaticPopupDialogs["RPQR_DELETE_PROFILE"] = {
    text = "%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, name)
        if ns.DeleteProfile(name) then
            ProfileChanged()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function AskDeleteProfile()
    profileMenu:Hide()
    local name = ns.ActiveProfile()
    if name then
        StaticPopup_Show("RPQR_DELETE_PROFILE", L.CONFIRM_DELETE_PROFILE:format(name), nil, name)
    end
end

-- "Post now" is a secure macro button like the ring's. It hangs off UIParent rather than the
-- window, so the window itself stays free to open, close and move during combat; the button
-- is put away as combat starts and comes back after.
local testButton, revertButton

local function SyncTestButton()
    if not testButton or InCombatLockdown() then
        return
    end
    if entryPanel:IsVisible() then
        testButton:ClearAllPoints()
        testButton:SetPoint("LEFT", revertButton, "RIGHT", 4, 0)
        testButton:SetFrameStrata(frame:GetFrameStrata())
        testButton:SetFrameLevel(frame:GetFrameLevel() + 50)
        testButton:Show()
    else
        testButton:Hide()
        testButton:ClearAllPoints()
    end
end

local function CreateTestButton()
    testButton = CreateFrame("Button", nil, UIParent, "UIPanelButtonTemplate, SecureActionButtonTemplate")
    testButton:SetSize(104, 22)
    testButton:SetText(L.BTN_TEST)
    testButton:RegisterForClicks("AnyUp", "AnyDown")
    testButton:Hide()
    testButton:SetScript("PreClick", function(self, _, down)
        if ns.IsActionPhase(down) then
            local text, err
            if CommitEntry() then
                text, err = ns.MacroText(CurrentEntry())
                if err then
                    SetStatus(err)
                end
            end
            ns.SetMacro(self, text)
        end
    end)
    testButton:RegisterEvent("PLAYER_REGEN_DISABLED")
    testButton:RegisterEvent("PLAYER_REGEN_ENABLED")
    testButton:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            self:Hide()
            self:ClearAllPoints()
        else
            SyncTestButton()
        end
    end)
end

-- The window -------------------------------------------------------------------------------------

local function OnEdited(_, userInput)
    if userInput and not loading then
        dirty = true
        SetStatus(nil)
    end
end

local function CreateConfig()
    frame = CreateFrame("Frame", "RPQuickResponseConfig", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    tinsert(UISpecialFrames, "RPQuickResponseConfig")

    local title = frame.TitleText or frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:ClearAllPoints()
    title:SetPoint("TOP", 0, -5)
    title:SetText(L.CONFIG_TITLE)

    -- The profile in use
    Label(frame, L.CONFIG_PROFILE):SetPoint("TOPLEFT", 18, -34)
    profileButton = Button(frame, "", 240, ShowProfileMenu)
    profileButton:SetPoint("TOPLEFT", 90, -30)
    profileButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.CONFIG_PROFILE, 1, 1, 1)
        GameTooltip:AddLine(L.TOOLTIP_PROFILE, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    profileButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local newProfile = Button(frame, L.BTN_NEW_PROFILE, 120, AskNewProfile)
    newProfile:SetPoint("LEFT", profileButton, "RIGHT", 6, 0)
    deleteProfileButton = Button(frame, L.BTN_DELETE_PROFILE, 120, AskDeleteProfile)
    deleteProfileButton:SetPoint("LEFT", newProfile, "RIGHT", 4, 0)
    CreateProfileMenu()

    -- Categories
    Label(frame, L.CONFIG_CATEGORIES):SetPoint("TOPLEFT", 18, -34 - TOP)
    categoryList = List(frame, 200, 340, SelectCategory)
    categoryList:SetPoint("TOPLEFT", 14, -52 - TOP)
    local newCategory = Button(frame, L.BTN_NEW, 98, NewCategory)
    newCategory:SetPoint("TOPLEFT", categoryList, "BOTTOMLEFT", 0, -6)
    local deleteCategory = Button(frame, L.BTN_DELETE, 98, AskDeleteCategory)
    deleteCategory:SetPoint("LEFT", newCategory, "RIGHT", 4, 0)
    local up = Button(frame, L.BTN_UP, 98, function() MoveCategory(-1) end)
    up:SetPoint("TOPLEFT", newCategory, "BOTTOMLEFT", 0, -4)
    local down = Button(frame, L.BTN_DOWN, 98, function() MoveCategory(1) end)
    down:SetPoint("LEFT", up, "RIGHT", 4, 0)

    -- The chosen category
    categoryPanel = CreateFrame("Frame", nil, frame)
    categoryPanel:SetPoint("TOPLEFT", 228, -28 - TOP)
    categoryPanel:SetPoint("BOTTOMRIGHT", -10, 40)

    Label(categoryPanel, L.CONFIG_NAME):SetPoint("TOPLEFT", 4, -6)
    nameBox = Input(categoryPanel, 220, 30)
    nameBox:SetPoint("TOPLEFT", 10, -22)
    nameBox:SetScript("OnEditFocusLost", SaveCategoryName)

    -- The icon itself is the button: a click opens the icon browser.
    Label(categoryPanel, L.CONFIG_ICON):SetPoint("TOPLEFT", 252, -6)
    local iconButton = CreateFrame("Button", nil, categoryPanel)
    iconButton:SetSize(30, 30)
    iconButton:SetPoint("TOPLEFT", 254, -20)
    iconButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    iconButton:SetScript("OnClick", BrowseIcons)
    iconButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.TOOLTIP_ICON_CHOOSE, 1, 1, 1)
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    iconPreview = iconButton:CreateTexture(nil, "ARTWORK")
    iconPreview:SetAllPoints()
    iconPreview:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local divider = categoryPanel:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.82, 0.58, 0.30, 0.35)
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", 0, -52)
    divider:SetPoint("TOPRIGHT", 0, -52)

    -- Its lines
    Label(categoryPanel, L.CONFIG_ENTRIES):SetPoint("TOPLEFT", 4, -62)
    entryList = List(categoryPanel, 180, 284, SelectEntry)
    entryList:SetPoint("TOPLEFT", 0, -80)
    local newEntry = Button(categoryPanel, L.BTN_NEW_ENTRY, 88, NewEntry)
    newEntry:SetPoint("TOPLEFT", entryList, "BOTTOMLEFT", 0, -6)
    local deleteEntry = Button(categoryPanel, L.BTN_DELETE, 88, DeleteEntry)
    deleteEntry:SetPoint("LEFT", newEntry, "RIGHT", 4, 0)

    -- The chosen line
    noEntryText = Label(categoryPanel, L.CONFIG_NO_ENTRY, "GameFontDisable")
    noEntryText:SetPoint("TOPLEFT", 200, -90)
    noEntryText:SetWidth(310)

    entryPanel = CreateFrame("Frame", nil, categoryPanel)
    entryPanel:SetPoint("TOPLEFT", 196, -58)
    entryPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    -- Also fires when the whole window opens or closes.
    entryPanel:SetScript("OnShow", function() SyncTestButton() end)
    entryPanel:SetScript("OnHide", function() SyncTestButton() end)

    Label(entryPanel, L.CONFIG_SHORT):SetPoint("TOPLEFT", 4, -4)
    shortBox = Input(entryPanel, 310, SHORT_MAX)
    shortBox:SetPoint("TOPLEFT", 10, -20)
    shortBox:SetScript("OnTextChanged", OnEdited)

    Label(entryPanel, L.CONFIG_FULL):SetPoint("TOPLEFT", 4, -48)
    fullBox = MultiLineInput(entryPanel, 320, 170)
    fullBox:SetPoint("TOPLEFT", 0, -64)
    fullBox.edit:SetScript("OnTextChanged", OnEdited)

    local hint = Label(entryPanel, L.CONFIG_HINT, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", fullBox, "BOTTOMLEFT", 4, -6)
    hint:SetWidth(312)
    hint:SetTextColor(0.75, 0.75, 0.75)

    statusText = Label(entryPanel, "", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -6)
    statusText:SetWidth(312)

    local save = Button(entryPanel, L.BTN_SAVE, 100, CommitEntry)
    save:SetPoint("TOPLEFT", entryList, "BOTTOMRIGHT", 16, -6)
    revertButton = Button(entryPanel, L.BTN_REVERT, 100, LoadEntry)
    revertButton:SetPoint("LEFT", save, "RIGHT", 4, 0)
    CreateTestButton()

    -- Button options
    lockCheck = Check(frame, L.CHECK_LOCK, function(checked) ns.char.button.locked = checked end)
    lockCheck:SetPoint("BOTTOMLEFT", 14, 10)
    minimapCheck = Check(frame, L.CHECK_MINIMAP, function(checked)
        ns.db.minimap.hide = not checked
        ns.UpdateMinimapButton()
    end)
    minimapCheck:SetPoint("BOTTOMLEFT", 230, 10)
    local reset = Button(frame, L.BTN_RESET_POSITION, 160, function()
        ns.ResetButtonPosition()
        ns.Print(L.MSG_POSITION_RESET)
    end)
    reset:SetPoint("BOTTOMRIGHT", -14, 12)

    frame:SetScript("OnShow", function()
        lockCheck:SetChecked(ns.char.button.locked and true or false)
        minimapCheck:SetChecked(not ns.db.minimap.hide)
        RefreshProfile()
        RefreshLists()
        LoadCategory()
        LoadEntry()
    end)
    frame:SetScript("OnHide", function()
        profileMenu:Hide()
        if not CommitEntry() then
            ns.Print(L.MSG_DISCARDED)
            dirty = false
        end
    end)
end

function ns.OpenConfig()
    if not frame then
        CreateConfig()
    end
    frame:Show()
    frame:Raise()
end

function ns.ToggleConfig()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ns.OpenConfig()
    end
end
