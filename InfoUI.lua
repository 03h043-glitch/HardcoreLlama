local _, ns = ...

local UI = ns.UI
if not UI then
    return
end

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 72, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local originalBuildFrame = UI.BuildFrame
function UI:BuildFrame()
    local frame = originalBuildFrame(self)
    if frame.infoButton then
        return frame
    end

    frame.overviewButton:SetSize(48, 22)
    frame.grindButton:SetSize(50, 22)
    frame.grindButton:ClearAllPoints()
    frame.grindButton:SetPoint("LEFT", frame.overviewButton, "RIGHT", 5, 0)

    if frame.dungeonButton then
        frame.dungeonButton:SetSize(70, 22)
        frame.dungeonButton:ClearAllPoints()
        frame.dungeonButton:SetPoint("LEFT", frame.grindButton, "RIGHT", 5, 0)
    end

    frame.reminderButton:SetSize(48, 22)
    frame.reminderButton:ClearAllPoints()
    frame.reminderButton:SetPoint("LEFT", frame.dungeonButton or frame.grindButton, "RIGHT", 5, 0)

    frame.infoButton = makeButton(frame, "Info", 44, function()
        ns.UI:SetView("info")
    end)
    frame.infoButton:SetPoint("LEFT", frame.reminderButton, "RIGHT", 5, 0)

    frame.fallenButton:SetSize(54, 22)
    frame.fallenButton:ClearAllPoints()
    frame.fallenButton:SetPoint("LEFT", frame.infoButton, "RIGHT", 5, 0)

    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("LEFT", frame.resetButton, "RIGHT", 12, 0)
    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.label:SetPoint("LEFT", check, "RIGHT", 0, 1)
    check.label:SetText("Dual wield")
    check:SetScript("OnClick", function(owner)
        if ns.Info then
            ns.Info:SetDualWieldChoice(owner:GetChecked() == true)
            ns.UI:Refresh()
        end
    end)
    check:Hide()
    frame.infoDualWield = check

    return frame
end

function UI:UpdateInfoControls()
    local frame = self.frame
    if not frame or not frame.infoDualWield then
        return
    end

    local check = frame.infoDualWield
    if self.view == "info" and ns.Info and ns.Info:CanDualWieldChoice() then
        check:SetChecked(ns.Info:IsDualWield())
        check:Show()
        if check.label then
            check.label:Show()
        end
    else
        check:Hide()
        if check.label then
            check.label:Hide()
        end
    end
end

local originalRefresh = UI.Refresh
function UI:Refresh()
    if not self.frame then
        return
    end

    if self.view == "info" then
        local lines
        local hoverRows
        if ns.Info then
            lines, hoverRows = ns.Info:BuildLines()
        else
            lines = { "WEAPON PROGRESSION", "--------------------------------", "Info module is not loaded." }
            hoverRows = {}
        end
        self:SetLines(lines, hoverRows)
        self:UpdateInfoControls()
        return
    end

    originalRefresh(self)
    self:UpdateInfoControls()
end
