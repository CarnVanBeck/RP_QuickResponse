-- A small medallion on the minimap's edge that opens the settings; drag it around the rim.
local _, ns = ...
local L = ns.L

local SIZE = 30
local RIM_OFFSET = 10
local button

local function UpdatePosition()
    local angle = math.rad(ns.db.minimap.angle or 225)
    local radius = Minimap:GetWidth() / 2 + RIM_OFFSET
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function FollowCursor()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    ns.db.minimap.angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
    UpdatePosition()
end

function ns.CreateMinimapButton()
    button = ns.CreateRoundButton(Minimap, SIZE, "RPQuickResponseMinimapButton")
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button.icon:SetTexture(ns.IconPath("Spell_Holy_Renew"))
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", FollowCursor)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.movedAt = GetTime()
    end)
    button:SetScript("OnClick", function(self)
        if self.movedAt and GetTime() - self.movedAt < 0.2 then
            return
        end
        ns.ToggleConfig()
    end)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("RP - Quick Response", unpack(ns.COLOR.labelHot))
        GameTooltip:AddLine(L.TOOLTIP_MINIMAP_LEFT, 1, 1, 1)
        GameTooltip:AddLine(L.TOOLTIP_MINIMAP_DRAG, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function() GameTooltip:Hide() end)

    ns.UpdateMinimapButton()
end

function ns.UpdateMinimapButton()
    if not button then
        return
    end
    if ns.db.minimap.hide then
        button:Hide()
    else
        button:Show()
        UpdatePosition()
    end
end
