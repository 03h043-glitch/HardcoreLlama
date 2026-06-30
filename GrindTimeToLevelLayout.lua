local _, ns = ...

local AutoGrindWindow = ns.AutoGrindWindow
if not AutoGrindWindow then
    return
end

local function setBounds(frame)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(300, 255, 540, 390)
    else
        frame:SetMinResize(300, 255)
        frame:SetMaxResize(540, 390)
    end
    if (frame:GetHeight() or 0) < 255 then
        frame:SetHeight(255)
    end
end

local previousBuildFrame = AutoGrindWindow.BuildFrame
function AutoGrindWindow:BuildFrame()
    local frame = previousBuildFrame(self)
    if not frame.timeToLevelLayoutEnabled then
        setBounds(frame)
        frame.timeToLevelLayoutEnabled = true
    end
    return frame
end

local previousUpdateLayout = AutoGrindWindow.UpdateLayout
function AutoGrindWindow:UpdateLayout()
    previousUpdateLayout(self)

    local frame = self.frame
    if not frame or not frame.metrics or not frame.metrics[6] then
        return
    end

    local width = frame:GetWidth() or 300
    local contentWidth = math.max(250, width - 28)
    local metric = frame.metrics[6]

    metric.label:ClearAllPoints()
    metric.value:ClearAllPoints()
    metric.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -140)
    metric.label:SetWidth(contentWidth)
    metric.value:SetPoint("TOPLEFT", metric.label, "BOTTOMLEFT", 0, -1)
    metric.value:SetWidth(contentWidth)

    if frame.lootTitle then
        frame.lootTitle:ClearAllPoints()
        frame.lootTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -172)
        frame.lootTitle:SetWidth(contentWidth)
    end

    for index, row in ipairs(frame.lootRows or {}) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -187 - ((index - 1) * 15))
        row:SetWidth(contentWidth)
    end

    if frame.stopButton then
        frame.stopButton:ClearAllPoints()
        frame.stopButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 10)
    end
end
