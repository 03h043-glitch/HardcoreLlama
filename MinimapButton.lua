local _, ns = ...

local MinimapButton = ns:RegisterModule("MinimapButton", {})
ns.MinimapButton = MinimapButton

local DEFAULT_ANGLE = 225
local DEFAULT_RADIUS = 78

local function getSettings()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        return { angle = DEFAULT_ANGLE, radius = DEFAULT_RADIUS }
    end

    db.settings.minimap = db.settings.minimap or {}
    local settings = db.settings.minimap
    settings.angle = tonumber(settings.angle) or DEFAULT_ANGLE
    settings.radius = tonumber(settings.radius) or DEFAULT_RADIUS
    return settings
end

local function atan2(y, x)
    if math.atan2 then
        return math.atan2(y, x)
    end

    if x > 0 then
        return math.atan(y / x)
    elseif x < 0 and y >= 0 then
        return math.atan(y / x) + math.pi
    elseif x < 0 and y < 0 then
        return math.atan(y / x) - math.pi
    elseif x == 0 and y > 0 then
        return math.pi / 2
    elseif x == 0 and y < 0 then
        return -math.pi / 2
    end
    return 0
end

function MinimapButton:UpdatePosition()
    if not self.button or not Minimap then
        return
    end

    local settings = getSettings()
    local angle = math.rad(settings.angle or DEFAULT_ANGLE)
    local radius = settings.radius or DEFAULT_RADIUS
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius

    self.button:ClearAllPoints()
    self.button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function MinimapButton:UpdateDragPosition()
    if not self.button or not Minimap or type(GetCursorPosition) ~= "function" then
        return
    end

    local scale = Minimap:GetEffectiveScale() or 1
    local cursorX, cursorY = GetCursorPosition()
    local centerX, centerY = Minimap:GetCenter()
    if not cursorX or not cursorY or not centerX or not centerY then
        return
    end

    cursorX = cursorX / scale
    cursorY = cursorY / scale

    local settings = getSettings()
    settings.angle = math.deg(atan2(cursorY - centerY, cursorX - centerX))
    self:UpdatePosition()
end

function MinimapButton:ShowTooltip()
    if not GameTooltip or not self.button then
        return
    end

    GameTooltip:SetOwner(self.button, "ANCHOR_LEFT")
    GameTooltip:AddLine("HardcoreLlama", 0.2, 1, 0.6, false)
    GameTooltip:AddLine("Left-click to open the tracker.", 1, 1, 1, false)
    GameTooltip:AddLine("Drag to move this button.", 0.65, 0.65, 0.65, false)
    GameTooltip:Show()
end

function MinimapButton:ToggleWindow()
    if ns.UI then
        ns.UI:Toggle()
    else
        ns:Print("UI module is not loaded.")
    end
end

function MinimapButton:BuildButton()
    if self.button or not Minimap then
        return self.button
    end

    local button = CreateFrame("Button", "HardcoreLlamaMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetClampedToScreen(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    button.background = button:CreateTexture(nil, "BACKGROUND")
    button.background:SetSize(24, 24)
    button.background:SetPoint("CENTER", 0, 0)
    button.background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("CENTER", 0, 0)
    button.icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
    if button.icon.SetTexCoord then
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(54, 54)
    button.border:SetPoint("TOPLEFT", 0, 0)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")
    button.highlight:SetAllPoints(button)

    button:SetScript("OnEnter", function()
        MinimapButton:ShowTooltip()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    button:SetScript("OnClick", function()
        if button.wasDragged then
            button.wasDragged = nil
            return
        end
        MinimapButton:ToggleWindow()
    end)
    button:SetScript("OnDragStart", function()
        button.wasDragged = true
        button:SetScript("OnUpdate", function()
            MinimapButton:UpdateDragPosition()
        end)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
        MinimapButton:UpdateDragPosition()
    end)

    self.button = button
    self:UpdatePosition()
    return button
end

function MinimapButton:OnPlayerLogin()
    self:BuildButton()
end
