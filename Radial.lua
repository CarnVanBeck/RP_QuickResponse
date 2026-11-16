-- The main button (draggable, shows the player's portrait) and the ring of categories around it.
-- Left-click a category: a random line. Right-click: its lines (Short) fan out next to it to pick one.
--
-- Everything that posts is a secure macro button (WoW Forever blocks addon chat), and the ring
-- also works in combat. In combat only secure code may show, hide or change those buttons, so:
--   * the ring is laid out beforehand (on opening out of combat, as combat starts, after changes);
--   * the main button, the slots, the lines and Escape show and hide it through secure snippets;
--   * out of combat a left-click picks at random (PreClick); in combat the slot steps through its
--     lines in an order shuffled beforehand, because PreClick may not change secure buttons then.
local _, ns = ...
local L = ns.L

local MAIN_SIZE = 56
local SLOT_SIZE = 46
local MIN_RADIUS = 80
local SLOT_SPACING = SLOT_SIZE + 30 -- room for a slot and its label along the circle
local OPEN_TIME = 0.14
local PILL_HEIGHT, PILL_GAP = 22, 3
local PILL_MIN_WIDTH, PILL_MAX_WIDTH = 70, 200
local TOOLTIP_LINES = 8
local RING_LEVEL, MAIN_LEVEL = 5, 80

local main, ring, closer
local slots = {}
local dirty = true

-- Secure snippets ---------------------------------------------------------------------------------
-- In wrapped click handlers `self` is the clicked button and `owner` the ring.

local MAIN_CLICK = [[
    if button ~= "LeftButton" then return end
    local ring = self:GetFrameRef("ring")
    if ring:IsShown() then
        ring:Hide()
    elseif (ring:GetAttribute("rpqr-count") or 0) > 0 then
        ring:Show()
    end
]]

local CLOSE_CLICK = [[ self:GetFrameRef("ring"):Hide() ]]

-- While the ring is open, Escape closes it (and only it).
local RING_SHOW = [[ self:SetBindingClick(true, "ESCAPE", "RPQuickResponseRingClose") ]]
local RING_HIDE = [[
    self:ClearBindings()
    for i = 1, self:GetAttribute("rpqr-count") or 0 do
        local group = self:GetFrameRef("rpqr-group" .. i)
        if group then group:Hide() end
    end
]]

-- Buttons get both press and release (the macro runs on one of them, see Widgets.lua);
-- our own work happens once, on release.
local CLICK_PRE = [[ if not down then return nil, button end ]]

local SLOT_POST = [[
    if message == "RightButton" then
        local group = self:GetFrameRef("rpqr-group")
        local wasShown = group:IsShown()
        for i = 1, owner:GetAttribute("rpqr-count") or 0 do
            local other = owner:GetFrameRef("rpqr-group" .. i)
            if other then other:Hide() end
        end
        if not wasShown and (self:GetAttribute("rpqr-count") or 0) > 0 then
            group:Show()
        end
    elseif message == "LeftButton" then
        if PlayerInCombat() then
            local count = self:GetAttribute("rpqr-count") or 0
            if count > 1 then
                local nextLine = (self:GetAttribute("rpqr-next") or 1) % count + 1
                self:SetAttribute("rpqr-next", nextLine)
                self:SetAttribute("macrotext", self:GetAttribute("rpqr-macro" .. nextLine))
            end
        end
        owner:Hide()
    end
]]

local PILL_POST = [[ if message == "LeftButton" then owner:Hide() end ]]

local function Sound(kit)
    if SOUNDKIT and SOUNDKIT[kit] then
        PlaySound(SOUNDKIT[kit])
    end
end

local function Shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- Pills: one line of a category, shown by its Short ------------------------------------------------

local function EntryOf(pill)
    local category = ns.Categories()[pill.category]
    return category and category.entries[pill.entry]
end

local function PillOnEnter(self)
    self:SetBackdropBorderColor(unpack(ns.COLOR.rimHot))
    local entry = EntryOf(self)
    if not entry then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.short, unpack(ns.COLOR.labelHot))
    for line in (entry.full .. "\n"):gmatch("(.-)\r?\n") do
        if line ~= "" then
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
    end
    GameTooltip:Show()
end

local function PillOnLeave(self)
    self:SetBackdropBorderColor(unpack(ns.COLOR.rim))
    GameTooltip:Hide()
end

local function GetPill(slot, i)
    if slot.pills[i] then
        return slot.pills[i]
    end
    local pill = CreateFrame("Button", nil, slot.group, "BackdropTemplate, SecureActionButtonTemplate")
    pill:RegisterForClicks("AnyUp", "AnyDown")
    pill:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    pill:SetBackdropColor(0.06, 0.05, 0.04, 0.92)
    pill:SetBackdropBorderColor(unpack(ns.COLOR.rim))
    pill.text = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pill.text:SetPoint("LEFT", 10, 0)
    pill.text:SetPoint("RIGHT", -10, 0)
    pill.text:SetJustifyH("LEFT")
    pill.text:SetWordWrap(false)
    pill:SetScript("OnEnter", PillOnEnter)
    pill:SetScript("OnLeave", PillOnLeave)
    SecureHandlerWrapScript(pill, "OnClick", ring, CLICK_PRE, PILL_POST)
    slot.pills[i] = pill
    return pill
end

-- A column beside the slot, on the side facing away from the centre.
local function LayoutPills(slot, category, usable)
    local toRight = slot.fx >= -1
    local total = #usable * (PILL_HEIGHT + PILL_GAP) - PILL_GAP
    local top = slot.fy + total / 2
    for i, entryIndex in ipairs(usable) do
        local pill = GetPill(slot, i)
        local entry = category.entries[entryIndex]
        pill.category, pill.entry = slot.index, entryIndex
        pill.text:SetText(entry.short)
        ns.SetMacro(pill, (ns.MacroText(entry)))
        local textWidth = pill.text.GetUnboundedStringWidth and pill.text:GetUnboundedStringWidth()
            or pill.text:GetStringWidth()
        pill:SetSize(math.min(math.max(textWidth + 22, PILL_MIN_WIDTH), PILL_MAX_WIDTH), PILL_HEIGHT)
        pill:ClearAllPoints()
        local y = top - (i - 1) * (PILL_HEIGHT + PILL_GAP) - PILL_HEIGHT / 2
        if toRight then
            pill:SetPoint("LEFT", ring, "CENTER", slot.fx + SLOT_SIZE / 2 + 12, y)
        else
            pill:SetPoint("RIGHT", ring, "CENTER", slot.fx - SLOT_SIZE / 2 - 12, y)
        end
        pill:Show()
    end
    for i = #usable + 1, #slot.pills do
        slot.pills[i]:Hide()
    end
end

-- Slots: one category each ---------------------------------------------------------------------------

local function SlotOnEnter(self)
    self.label:SetTextColor(unpack(ns.COLOR.labelHot))
    local category = ns.Categories()[self.index]
    if self.group:IsShown() or not category then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(category.name, unpack(ns.COLOR.labelHot))
    local count = #category.entries
    if count == 0 then
        GameTooltip:AddLine(L.TOOLTIP_EMPTY, 0.6, 0.6, 0.6, true)
    else
        for i = 1, math.min(count, TOOLTIP_LINES) do
            GameTooltip:AddLine("- " .. category.entries[i].short, 1, 1, 1)
        end
        if count > TOOLTIP_LINES then
            GameTooltip:AddLine(L.TOOLTIP_MORE:format(count - TOOLTIP_LINES), 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.TOOLTIP_SLOT_LEFT, 0.5, 0.8, 1)
        GameTooltip:AddLine(L.TOOLTIP_SLOT_RIGHT, 0.5, 0.8, 1)
    end
    GameTooltip:Show()
end

local function SlotOnLeave(self)
    self.label:SetTextColor(unpack(ns.COLOR.label))
    GameTooltip:Hide()
end

-- Out of combat: put a random line into the macro just before the secure template runs it.
local function PickInto(slot)
    local entry, message = ns.PickRandom(slot.index)
    ns.SetMacro(slot, entry and (ns.MacroText(entry)))
    slot.message = message
end

local function SlotPreClick(self, mouseButton, down)
    if mouseButton == "LeftButton" and ns.IsActionPhase(down) and not InCombatLockdown() then
        PickInto(self)
    end
end

local function SlotPostClick(self, mouseButton, down)
    if not down and mouseButton == "LeftButton" and self.message then
        ns.Print(self.message)
    end
end

local function GetSlot(i)
    if slots[i] then
        return slots[i]
    end
    local slot = ns.CreateRoundButton(ring, SLOT_SIZE, nil, "SecureActionButtonTemplate")
    slot:RegisterForClicks("AnyUp", "AnyDown")
    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    slot.label = slot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slot.label:SetPoint("TOP", slot, "BOTTOM", 0, -2)
    slot.label:SetWidth(SLOT_SPACING + 10)
    slot.label:SetWordWrap(false)
    slot.label:SetTextColor(unpack(ns.COLOR.label))
    slot.label:SetShadowColor(0, 0, 0, 1)
    slot.label:SetShadowOffset(1, -1)
    slot:HookScript("OnEnter", SlotOnEnter)
    slot:HookScript("OnLeave", SlotOnLeave)
    slot:SetScript("PreClick", SlotPreClick)
    slot:SetScript("PostClick", SlotPostClick)

    -- Its lines, shown and hidden by secure code.
    slot.pills = {}
    slot.group = CreateFrame("Frame", nil, ring, "SecureFrameTemplate")
    slot.group:SetAllPoints(ring)
    slot.group:SetFrameLevel(RING_LEVEL + 20)
    slot.group:Hide()
    slot.group:SetScript("OnShow", function()
        slot.keepHot = true
        slot:SetHot(true)
        GameTooltip:Hide()
        Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    end)
    slot.group:SetScript("OnHide", function()
        slot.keepHot = false
        slot:SetHot(slot:IsMouseOver())
    end)
    SecureHandlerSetFrameRef(slot, "rpqr-group", slot.group)
    ring:SetFrameRef("rpqr-group" .. i, slot.group)
    SecureHandlerWrapScript(slot, "OnClick", ring, CLICK_PRE, SLOT_POST)

    slots[i] = slot
    return slot
end

-- The ring -----------------------------------------------------------------------------------------

-- Points a slot at the start of its combat order (out of combat only), so that a fight
-- never begins with the line that was just posted.
local function RewindSlot(slot)
    slot:SetAttribute("rpqr-next", 1)
    ns.SetMacro(slot, slot:GetAttribute("rpqr-macro1"))
end

local function RewindAll()
    for i = 1, ring:GetAttribute("rpqr-count") or 0 do
        RewindSlot(slots[i])
    end
end

-- Places everything for the current categories. Only possible out of combat; otherwise it waits.
local function Layout()
    if InCombatLockdown() then
        dirty = true
        return
    end
    dirty = false
    local categories = ns.Categories()
    local count = #categories
    local radius = math.max(MIN_RADIUS, count * SLOT_SPACING / (2 * math.pi))
    local diameter = 2 * radius + SLOT_SIZE + 50
    ring:SetSize(diameter, diameter)
    ring.halo:SetSize(2 * radius + SLOT_SIZE, 2 * radius + SLOT_SIZE)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", main, "CENTER")
    ring:SetAttribute("rpqr-count", count)

    for i, category in ipairs(categories) do
        local slot = GetSlot(i)
        slot.index = i
        local angle = math.rad(90 - (i - 1) * 360 / count) -- clockwise from the top
        slot.fx, slot.fy = radius * math.cos(angle), radius * math.sin(angle)
        slot.icon:SetTexture(ns.IconPath(category.icon))
        slot.label:SetText(category.name)
        local usable = ns.UsableEntries(category)
        slot.icon:SetDesaturated(#usable == 0)
        slot:SetAlpha(#usable > 0 and 1 or 0.6)
        slot:ClearAllPoints()
        slot:SetPoint("CENTER", ring, "CENTER", slot.fx, slot.fy)
        slot:Show()

        -- The order a slot steps through its lines in combat.
        local order = Shuffle({ unpack(usable) })
        slot:SetAttribute("rpqr-count", #order)
        for k, entryIndex in ipairs(order) do
            slot:SetAttribute("rpqr-macro" .. k, (ns.MacroText(category.entries[entryIndex])))
        end
        slot.message = #order == 0 and L.MSG_CATEGORY_EMPTY:format(category.name) or nil
        RewindSlot(slot)

        slot.group:Hide()
        LayoutPills(slot, category, usable)
    end
    for i = count + 1, #slots do
        slots[i]:Hide()
        slots[i].group:Hide()
    end
end

local function SetSlotOffsets(scale)
    for i = 1, ring:GetAttribute("rpqr-count") or 0 do
        local slot = slots[i]
        slot:SetPoint("CENTER", ring, "CENTER", slot.fx * scale, slot.fy * scale)
    end
end

-- The opening animation moves secure buttons, so it only plays out of combat and is finished at once
-- when combat starts.
local function FinishAnimation()
    if ring:GetScript("OnUpdate") then
        ring:SetScript("OnUpdate", nil)
        SetSlotOffsets(1)
        ring:SetAlpha(1)
    end
end

local function Animate(self, elapsed)
    if InCombatLockdown() then
        self:SetScript("OnUpdate", nil)
        return
    end
    self.elapsed = self.elapsed + elapsed
    local progress = math.min(1, self.elapsed / OPEN_TIME)
    local eased = 1 - (1 - progress) ^ 3
    SetSlotOffsets(eased)
    self:SetAlpha(eased)
    if progress >= 1 then
        self:SetScript("OnUpdate", nil)
    end
end

local function MouseIsOverRing()
    if main:IsMouseOver() then
        return true
    end
    for _, slot in ipairs(slots) do
        if slot:IsShown() and slot:IsMouseOver() then
            return true
        end
        for _, pill in ipairs(slot.pills) do
            if pill:IsVisible() and pill:IsMouseOver() then
                return true
            end
        end
    end
    return false
end

local function RingOnShow(self)
    self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    main.keepHot = true
    main:SetHot(true)
    GameTooltip:Hide()
    Sound("IG_MAINMENU_OPEN")
    if not InCombatLockdown() then
        if dirty then
            Layout()
        end
        self.elapsed = 0
        self:SetAlpha(0)
        SetSlotOffsets(0)
        self:SetScript("OnUpdate", Animate)
    end
end

local function RingOnHide(self)
    self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    if not InCombatLockdown() then
        FinishAnimation()
    end
    GameTooltip:Hide()
    main.keepHot = false
    main:SetHot(main:IsMouseOver())
    Sound("IG_MAINMENU_CLOSE")
end

local function RingOnEvent(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        FinishAnimation()
        if dirty then
            Layout()
        else
            RewindAll()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if dirty then
            Layout()
        end
    elseif event == "GLOBAL_MOUSE_DOWN" then
        -- A click anywhere else closes it (out of combat; in combat use the button or Escape).
        if not InCombatLockdown() and not MouseIsOverRing() then
            self:Hide()
        end
    end
end

local function CreateRing()
    ring = CreateFrame("Frame", "RPQuickResponseRing", UIParent, "SecureHandlerShowHideTemplate")
    ring:SetFrameStrata("HIGH")
    ring:SetFrameLevel(RING_LEVEL)
    ring:Hide()
    ring.disc = ring:CreateTexture(nil, "BACKGROUND")
    ring.disc:SetTexture(ns.DISC)
    ring.disc:SetAllPoints()
    ring.disc:SetVertexColor(0, 0, 0, 0.5)
    ring.halo = ring:CreateTexture(nil, "BACKGROUND", nil, 1)
    ring.halo:SetTexture(ns.DISC)
    ring.halo:SetPoint("CENTER")
    ring.halo:SetVertexColor(0.82, 0.58, 0.30, 0.08)
    ring.halo:SetBlendMode("ADD")
    ring:SetAttribute("_onshow", RING_SHOW)
    ring:SetAttribute("_onhide", RING_HIDE)
    ring:HookScript("OnShow", RingOnShow)
    ring:HookScript("OnHide", RingOnHide)
    ring:RegisterEvent("PLAYER_REGEN_DISABLED")
    ring:RegisterEvent("PLAYER_REGEN_ENABLED")
    ring:SetScript("OnEvent", RingOnEvent)

    -- What Escape clicks while the ring is open.
    closer = CreateFrame("Button", "RPQuickResponseRingClose", UIParent, "SecureHandlerClickTemplate")
    closer:RegisterForClicks("AnyDown", "AnyUp")
    closer:SetFrameRef("ring", ring)
    closer:SetAttribute("_onclick", CLOSE_CLICK)
end

-- After a change in the settings: close the ring and lay it out anew (now, or after combat).
function ns.CloseRing()
    dirty = true
    if not ring or InCombatLockdown() then
        return
    end
    ring:Hide()
    Layout()
end

-- The main button ----------------------------------------------------------------------------------

local function UpdatePortrait()
    SetPortraitTexture(main.icon, "player")
end

function ns.RestoreButtonPosition()
    if InCombatLockdown() then
        return
    end
    local saved = ns.char.button
    main:ClearAllPoints()
    main:SetPoint(saved.point or "CENTER", UIParent, saved.relativePoint or "CENTER", saved.x or 0, saved.y or -150)
end

function ns.ResetButtonPosition()
    local saved = ns.char.button
    saved.point, saved.relativePoint, saved.x, saved.y = nil, nil, nil, nil
    ns.CloseRing()
    ns.RestoreButtonPosition()
end

local function MainOnEnter(self)
    if ring:IsShown() then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("RP - Quick Response", unpack(ns.COLOR.labelHot))
    GameTooltip:AddLine(L.TOOLTIP_MAIN_LEFT, 1, 1, 1)
    GameTooltip:AddLine(L.TOOLTIP_MAIN_RIGHT, 1, 1, 1)
    if ns.char.button.locked then
        GameTooltip:AddLine(L.TOOLTIP_MAIN_LOCKED, 0.6, 0.6, 0.6)
    else
        GameTooltip:AddLine(L.TOOLTIP_MAIN_DRAG, 1, 1, 1)
    end
    GameTooltip:Show()
end

-- Runs after the secure snippet (which opens or closes the ring on a left-click).
local function MainOnClick(self, mouseButton)
    if self.movedAt and GetTime() - self.movedAt < 0.2 then
        return -- the end of a drag, not a click
    end
    GameTooltip:Hide()
    if mouseButton == "RightButton" then
        ns.CloseRing()
        ns.ToggleConfig()
    elseif #ns.Categories() == 0 then
        ns.Print(L.MSG_NO_CATEGORIES)
        ns.OpenConfig()
    end
end

function ns.CreateMainButton()
    main = ns.CreateRoundButton(UIParent, MAIN_SIZE, "RPQuickResponseButton", "SecureHandlerClickTemplate")
    main:SetFrameStrata("HIGH")
    main:SetFrameLevel(MAIN_LEVEL) -- above the ring's dark disc
    main:SetMovable(true)
    main:SetClampedToScreen(true)
    main:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    main:RegisterForDrag("LeftButton")

    CreateRing()
    main:SetFrameRef("ring", ring)
    main:SetAttribute("_onclick", MAIN_CLICK)
    main:HookScript("OnClick", MainOnClick)

    -- The button is secure, so it only moves out of combat.
    main:SetScript("OnDragStart", function(self)
        if ns.char.button.locked or InCombatLockdown() then
            return
        end
        ring:Hide()
        GameTooltip:Hide()
        self:StartMoving()
    end)
    main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(false) -- our own saved position, not the client's layout cache
        local point, _, relativePoint, x, y = self:GetPoint()
        local saved = ns.char.button
        saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
        self.movedAt = GetTime()
    end)
    main:HookScript("OnEnter", MainOnEnter)
    main:HookScript("OnLeave", function() GameTooltip:Hide() end)

    main:RegisterEvent("PLAYER_ENTERING_WORLD")
    main:RegisterUnitEvent("UNIT_PORTRAIT_UPDATE", "player")
    main:SetScript("OnEvent", UpdatePortrait)
    UpdatePortrait()

    ns.RestoreButtonPosition()
    Layout()
end
