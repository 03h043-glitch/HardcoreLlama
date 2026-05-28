local _, ns = ...

local UI = ns.UI
if not UI then
    return
end

local SOURCE_LAYOUT = {
    { key = "quest", label = "Quest", x = 14 },
    { key = "drop", label = "Drop", x = 68 },
    { key = "vendor", label = "Vend", x = 122 },
    { key = "auction", label = "AH", x = 174 },
    { key = "crafted", label = "Craft", x = 214 },
}

local function setVisible(widget, shown)
    if not widget then
        return
    end
    if shown then
        widget:Show()
    else
        widget:Hide()
    end
end

local function createSourceCheck(frame, option)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetSize(22, 22)
    check:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", option.x, 11)
    check.sourceKey = option.key

    check.label = check:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    check.label:SetPoint("LEFT", check, "RIGHT", -1, 1)
    check.label:SetText(option.label)

    check:SetScript("OnClick", function(owner)
        if ns.Info then
            ns.Info:SetSourceEnabled(owner.sourceKey, owner:GetChecked() == true)
            ns.UI:Refresh()
        end
    end)

    check:Hide()
    check.label:Hide()
    return check
end

local originalBuildFrame = UI.BuildFrame
function UI:BuildFrame()
    local frame = originalBuildFrame(self)
    if frame.infoSourceChecks then
        return frame
    end

    frame.infoSourceChecks = {}
    for _, option in ipairs(SOURCE_LAYOUT) do
        table.insert(frame.infoSourceChecks, createSourceCheck(frame, option))
    end

    return frame
end

local originalUpdateInfoControls = UI.UpdateInfoControls or function() end
function UI:UpdateInfoControls()
    originalUpdateInfoControls(self)

    local frame = self.frame
    if not frame then
        return
    end

    local isInfo = self.view == "info"
    setVisible(frame.startButton, not isInfo)
    setVisible(frame.stopButton, not isInfo)
    setVisible(frame.resetButton, not isInfo)
    setVisible(frame.refreshButton, not isInfo)

    if frame.infoSourceChecks then
        for _, check in ipairs(frame.infoSourceChecks) do
            local shown = isInfo and ns.Info ~= nil
            if shown then
                check:SetChecked(ns.Info:IsSourceEnabled(check.sourceKey))
            end
            setVisible(check, shown)
            setVisible(check.label, shown)
        end
    end

    local dual = frame.infoDualWield
    if dual then
        dual:ClearAllPoints()
        dual:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 278, 11)
        if dual.label then
            dual.label:SetText("Dual")
        end

        local showDual = isInfo and ns.Info and ns.Info:CanDualWieldChoice()
        if showDual then
            dual:SetChecked(ns.Info:IsDualWield())
        end
        setVisible(dual, showDual)
        setVisible(dual and dual.label, showDual)
    end
end
