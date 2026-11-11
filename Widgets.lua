-- The look shared by the main button, the ring's slots and the minimap button:
-- a round, bronze-rimmed medallion with a masked icon.
local _, ns = ...

ns.COLOR = {
    rim = { 0.55, 0.38, 0.18 },
    rimHot = { 0.95, 0.75, 0.45 },
    label = { 0.82, 0.58, 0.30 },
    labelHot = { 1.00, 0.84, 0.60 },
}

-- A white disc with soft edges; tinted it draws circles, as a mask it rounds icons.
ns.DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Accepts an icon name ("Spell_Holy_Renew"), a full path or a file ID.
function ns.IconPath(icon)
    if icon == nil or icon == "" then
        return DEFAULT_ICON
    end
    local fileID = tonumber(icon)
    if fileID then
        return fileID
    end
    if tostring(icon):find("\\", 1, true) then
        return icon
    end
    return "Interface\\Icons\\" .. icon
end

local function Disc(owner, layer, sublevel, size, r, g, b, a)
    local texture = owner:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(ns.DISC)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER")
    texture:SetVertexColor(r, g, b, a or 1)
    return texture
end

-- Secure macro buttons --------------------------------------------------------------------------
-- A secure button registered for both press and release runs its macro on one of them,
-- depending on the "ActionButtonUseKeyDown" setting. IsActionPhase tells which one that is.
local GetCVarBool = GetCVarBool or (C_CVar and C_CVar.GetCVarBool)

function ns.IsActionPhase(down)
    local useKeyDown = GetCVarBool and GetCVarBool("ActionButtonUseKeyDown") or false
    return (down and true or false) == (useKeyDown and true or false)
end

-- Sets what a left-click posts (nil: nothing). Only possible out of combat.
function ns.SetMacro(button, text)
    if InCombatLockdown() then
        return false
    end
    button:SetAttribute("type1", text and "macro" or nil)
    button:SetAttribute("macrotext", text)
    return true
end

function ns.CreateRoundButton(parent, size, name, template)
    local button = CreateFrame("Button", name, parent, template)
    button:SetSize(size, size)

    button.shadow = Disc(button, "BACKGROUND", -3, size + 6, 0, 0, 0, 0.55)
    button.shadow:SetPoint("CENTER", 1, -2)
    button.rim = Disc(button, "BACKGROUND", -2, size, unpack(ns.COLOR.rim))
    button.rimInner = Disc(button, "BACKGROUND", -1, size - 3, 0.30, 0.20, 0.09)
    button.well = Disc(button, "BACKGROUND", 0, size - 5, 0.04, 0.03, 0.02)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size - 7, size - 7)
    icon:SetPoint("CENTER")
    local mask = button:CreateMaskTexture()
    mask:SetTexture(ns.DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    button.icon = icon

    local glow = Disc(button, "OVERLAY", 0, size - 7, 1, 0.85, 0.6)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0)
    button.glow = glow

    function button:SetHot(hot)
        self.rim:SetVertexColor(unpack(hot and ns.COLOR.rimHot or ns.COLOR.rim))
        self.glow:SetAlpha(hot and 0.15 or 0)
    end

    button:SetScript("OnEnter", function(self) self:SetHot(true) end)
    button:SetScript("OnLeave", function(self) self:SetHot(self.keepHot or false) end)
    button:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
    button:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)

    return button
end
