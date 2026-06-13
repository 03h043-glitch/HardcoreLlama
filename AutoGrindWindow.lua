local _, ns = ...

local AutoGrindWindow = {}
ns.AutoGrindWindow = AutoGrindWindow

local C = {
    title = "|cffffd100",
    green = "|cff33ff99",
    blue = "|cff69ccf0",
    purple = "|cffd6a9ff",
    orange = "|cffff9f40",
    red = "|cffff5a5a",
    white = "|cffffffff",
    muted = "|cff9d9d9d",
    dim = "|cff666666",
    reset = "|r",
}

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function setTextureColor(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

local function getSettings()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        return { autoGrindWindowWidth = 300, autoGrindWindowHeight = 200 }
    end

    db.settings.ui = db.settings.ui or {}
    db.settings.ui.autoGrindWindowWidth = db.settings.ui.autoGrindWindowWidth or 300
    db.settings.ui.autoGrindWindowHeight = db.settings.ui.autoGrindWindowHeight or 200
    return db.settings.ui
end

local function makeFont(parent, template)
    local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    font:SetJustifyH("LEFT")
    font:SetJustifyV("TOP")
    return font
end

local function classText(className, classFile)
    if ns.ClassColorize then
        return ns:ClassColorize(className, classFile)
    end
    return tostring(className or classFile or "Unknown")
end

local function vendorValue(active)
    if ns.Grinding and ns.Grinding.GetVendorValue then
        return ns.Grinding:GetVendorValue(active)
    end
    return tonumber(active and active.lootVendorCopper or 0) or 0
end

function AutoGrindWindow:SaveSize(width, height)
    local settings = getSettings()
    settings.autoGrindWindowWidth = math.floor(width or settings.autoGrindWindowWidth or 300)
    settings.autoGrindWindowHeight = math.floor(height or settings.autoGrindWindowHeight or 200)
end

function AutoGrindWindow:BuildFrame()
    if self.frame then
        return self.frame
    end

    local settings = getSettings()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "HardcoreLlamaAutoGrindWindow", UIParent, template)
    frame:SetSize(settings.autoGrindWindowWidth or 300, settings.autoGrindWindowHeight or 200)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(260, 185, 460, 320)
    else
        frame:SetMinResize(260, 185)
        frame:SetMaxResize(460, 320)
    end

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.02, 0.07, 0.06, 0.96)
        frame:SetBackdropBorderColor(0.2, 0.95, 0.55, 0.95)
    end

    frame.tint = frame:CreateTexture(nil, "BACKGROUND")
    frame.tint:SetPoint("TOPLEFT", 6, -6)
    frame.tint:SetPoint("BOTTOMRIGHT", -6, 6)
    setTextureColor(frame.tint, 0.02, 0.18, 0.14, 0.62)

    frame.title = makeFont(frame, "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.title:SetText(color(C.green, "AUTO GRIND"))

    frame.subtitle = makeFont(frame, "GameFontHighlightSmall")
    frame.subtitle:SetPoint("TOPLEFT", 14, -34)
    frame.subtitle:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    frame.subtitle:SetText(color(C.muted, "Waiting for grind data..."))

    frame.metrics = {}
    for index = 1, 6 do
        local metric = {}
        metric.label = makeFont(frame, "GameFontDisableSmall")
        metric.value = makeFont(frame, "GameFontHighlightSmall")
        metric.value:SetTextColor(1, 1, 1, 1)
        frame.metrics[index] = metric
    end

    frame.targetLabel = makeFont(frame, "GameFontHighlightSmall")
    frame.targetLabel:SetText(color(C.blue, "Target timer"))

    frame.targetBg = frame:CreateTexture(nil, "ARTWORK")
    setTextureColor(frame.targetBg, 0.04, 0.04, 0.04, 0.85)

    frame.targetFill = frame:CreateTexture(nil, "OVERLAY")
    setTextureColor(frame.targetFill, 0.2, 0.95, 0.55, 0.9)

    frame.stopButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.stopButton:SetSize(92, 22)
    frame.stopButton:SetText("End Grind")
    frame.stopButton:SetScript("OnClick", function()
        if ns.Grinding then
            ns.Grinding:Stop()
        end
    end)

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(18, 18)
    resize:SetPoint("BOTTOMRIGHT", -8, 8)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        AutoGrindWindow:SaveSize(frame:GetWidth(), frame:GetHeight())
        AutoGrindWindow:UpdateLayout()
    end)
    frame.resize = resize

    frame:SetScript("OnSizeChanged", function(_, width, height)
        AutoGrindWindow:SaveSize(width, height)
        AutoGrindWindow:UpdateLayout()
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        AutoGrindWindow:OnUpdate(elapsed)
    end)

    frame:Hide()
    self.frame = frame
    self:UpdateLayout()
    return frame
end

function AutoGrindWindow:UpdateLayout()
    local frame = self.frame
    if not frame then
        return
    end

    local width = frame:GetWidth() or 300
    local contentWidth = math.max(220, width - 28)
    local columnWidth = math.floor((contentWidth - 12) / 2)

    for index, metric in ipairs(frame.metrics or {}) do
        local column = (index - 1) % 2
        local row = math.floor((index - 1) / 2)
        local x = 14 + column * (columnWidth + 12)
        local y = -60 - row * 30

        metric.label:ClearAllPoints()
        metric.value:ClearAllPoints()
        metric.label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        metric.label:SetWidth(columnWidth)
        metric.value:SetPoint("TOPLEFT", metric.label, "BOTTOMLEFT", 0, -1)
        metric.value:SetWidth(columnWidth)
    end

    frame.targetLabel:ClearAllPoints()
    frame.targetLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 48)
    frame.targetLabel:SetPoint("RIGHT", frame, "RIGHT", -14, 0)

    frame.targetBg:ClearAllPoints()
    frame.targetBg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 38)
    frame.targetBg:SetSize(math.max(120, width - 28), 8)

    frame.targetFill:ClearAllPoints()
    frame.targetFill:SetPoint("LEFT", frame.targetBg, "LEFT", 0, 0)
    frame.targetFill:SetHeight(8)

    frame.stopButton:ClearAllPoints()
    frame.stopButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 10)
end

function AutoGrindWindow:SetMetric(index, label, value, valueColor)
    local metric = self.frame and self.frame.metrics and self.frame.metrics[index]
    if not metric then
        return
    end

    metric.label:SetText(color(C.dim, string.upper(tostring(label or ""))))
    metric.value:SetText(color(valueColor or C.white, value or "0"))
end

function AutoGrindWindow:UpdateTargetBar(active)
    local frame = self.frame
    if not frame then
        return
    end

    local remaining = ns.Grinding and ns.Grinding.GetAutoStartTargetRemaining and ns.Grinding:GetAutoStartTargetRemaining(active) or 0
    local total = tonumber(active and active.autoStartTargetTimeout) or 180
    local fraction = total > 0 and math.max(0, math.min(1, remaining / total)) or 0
    local width = (frame.targetBg:GetWidth() or 0) * fraction

    frame.targetFill:SetWidth(math.max(1, width))
    if fraction > 0.66 then
        setTextureColor(frame.targetFill, 0.2, 0.95, 0.55, 0.9)
    elseif fraction > 0.33 then
        setTextureColor(frame.targetFill, 1.0, 0.72, 0.2, 0.9)
    else
        setTextureColor(frame.targetFill, 1.0, 0.22, 0.22, 0.9)
    end

    if active and active.autoStartMob then
        local prefix = active.autoStartMobToken and "Target group: " or "Target mob: "
        frame.targetLabel:SetText(color(C.blue, prefix) .. color(C.white, active.autoStartMob) .. color(C.muted, "  " .. ns:FormatDuration(remaining)))
    else
        frame.targetLabel:SetText(color(C.dim, "Target timer inactive"))
    end
end

function AutoGrindWindow:Update(active)
    local frame = self:BuildFrame()
    active = active or (ns.Grinding and ns.Grinding:GetActive())
    if not active then
        frame:Hide()
        return
    end

    if ns.Grinding and ns.Grinding.UpdateRates then
        ns.Grinding:UpdateRates(active)
    end

    local topMob = ns.Grinding and ns.Grinding.UpdateTopMob and ns.Grinding:UpdateTopMob(active)
    local title = tostring(active.name or "Grinding Session")
    local classLine = classText(active.class, active.classFile) .. color(C.muted, " L" .. tostring(active.levelStart or "?"))
    local mobLine = topMob and ("  " .. tostring(ns.Grinding:FormatPrimaryMob(topMob))) or ""

    frame.subtitle:SetText(color(C.white, title) .. color(C.muted, "  ") .. classLine .. color(C.dim, mobLine))
    self:SetMetric(1, "XP/hr", ns:FormatNumber(active.xpPerHour or 0), C.green)
    self:SetMetric(2, "Kills", ns:FormatNumber(active.mobCount or 0), C.orange)
    self:SetMetric(3, "Total XP", ns:FormatNumber(active.xpGained or 0), C.blue)
    self:SetMetric(4, "Avg/mob", ns:FormatNumber(active.averageXPPerMob or 0), C.purple)
    self:SetMetric(5, "Vendor", ns:FormatMoney(vendorValue(active)), C.title)
    self:SetMetric(6, "Idle", ns:FormatDuration(active.idleRemaining or (ns.Grinding and ns.Grinding:GetIdleRemaining(active)) or 0), C.red)
    self:UpdateTargetBar(active)
end

function AutoGrindWindow:OnUpdate(elapsed)
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < 0.5 then
        return
    end
    self.elapsed = 0

    if self.frame and self.frame:IsShown() then
        self:Update()
    end
end

function AutoGrindWindow:Show(active)
    local frame = self:BuildFrame()
    frame:Show()
    self:Update(active)
end

function AutoGrindWindow:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function AutoGrindWindow:IsShown()
    return self.frame and self.frame:IsShown()
end
