local _, ns = ...

local UI = ns.UI
if not UI then
    return
end

local C = {
    title = "|cffffd100",
    accent = "|cff33ff99",
    white = "|cffffffff",
    muted = "|cff9d9d9d",
    dim = "|cff666666",
    warning = "|cffffb347",
    xp = "|cff69ccf0",
    value = "|cffffd100",
    combined = "|cffd6a9ff",
    reset = "|r",
}

local TIER_COLORS = {
    S = "|cffff4d4d",
    A = "|cffff9f40",
    B = "|cffffff66",
    C = "|cff33ff99",
    D = "|cff9d9d9d",
}

local METRIC_COLORS = {
    xp = C.xp,
    value = C.value,
    combined = C.combined,
}

local TABS = {
    { scope = "world", label = "World", width = 54 },
    { scope = "dungeon", label = "Dungeon", width = 66 },
    { scope = "combined", label = "All", width = 44 },
}

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

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

local function classText(className, classFile)
    if ns.ClassColorize then
        return ns:ClassColorize(className, classFile)
    end
    return tostring(className or classFile or "Unknown")
end

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 54, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function divider(char, width)
    return string.rep(char or "-", width or 38)
end

function UI:GetGrindTierSettings()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        self.grindTierScope = self.grindTierScope or "world"
        return self
    end

    db.settings.ui = db.settings.ui or {}
    db.settings.ui.grindTierScope = db.settings.ui.grindTierScope or "world"
    return db.settings.ui
end

function UI:GetGrindTierScope()
    local settings = self:GetGrindTierSettings()
    local scope = settings.grindTierScope or "world"
    if scope ~= "world" and scope ~= "dungeon" and scope ~= "combined" then
        scope = "world"
        settings.grindTierScope = scope
    end
    return scope
end

function UI:SetGrindTierScope(scope)
    local settings = self:GetGrindTierSettings()
    settings.grindTierScope = scope or "world"
    self:Refresh()
end

local originalBuildFrame = UI.BuildFrame
function UI:BuildFrame()
    local frame = originalBuildFrame(self)
    if frame.grindTierTabs then
        return frame
    end

    frame.grindTierTabs = {}
    local previous = frame.startButton
    for _, tab in ipairs(TABS) do
        local button = makeButton(frame, tab.label, tab.width, function()
            ns.UI:SetGrindTierScope(tab.scope)
        end)
        button.scope = tab.scope
        button.baseLabel = tab.label
        if previous == frame.startButton then
            button:SetPoint("LEFT", frame.startButton, "RIGHT", 6, 0)
        else
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        end
        button:Hide()
        table.insert(frame.grindTierTabs, button)
        previous = button
    end

    return frame
end

local function sortedForMetric(records, rankField)
    local sorted = {}
    for _, record in ipairs(records or {}) do
        table.insert(sorted, record)
    end
    table.sort(sorted, function(left, right)
        if (left[rankField] or 9999) == (right[rankField] or 9999) then
            return tostring(left.title or "") < tostring(right.title or "")
        end
        return (left[rankField] or 9999) < (right[rankField] or 9999)
    end)
    return sorted
end

function UI:TierMetricHeader(lines, title, metric)
    table.insert(lines, "")
    table.insert(lines, color(METRIC_COLORS[metric] or C.title, "== " .. tostring(title) .. " =="))
    table.insert(lines, color(C.dim, divider("-", 42)))
end

function UI:TierRecordLine(record, rankField, metric, tierField)
    local kindText = ""
    if self:GetGrindTierScope() == "combined" then
        kindText = record.kind == "dungeon" and " [Dungeon]" or " [World]"
    end

    local tierColor = TIER_COLORS[record[tierField] or ""] or C.title
    local line = color(tierColor, "#" .. tostring(record[rankField] or "?") .. " ") .. color(C.white, tostring(record.title or "Session")) .. color(C.muted, " L" .. tostring(record.grindLevel or "?") .. kindText)
    local detail
    if metric == "xp" then
        detail = color(C.xp, string.format("%.1f%% level/hr", record.xpLevelPercentPerHour or 0)) .. color(C.muted, "  |  " .. ns:FormatNumber(record.xpPerHour or 0) .. " XP/hr")
    elseif metric == "value" then
        detail = color(C.value, ns:FormatMoney(record.vendorPerHour or 0) .. "/hr vendor") .. color(C.muted, "  |  scaled " .. string.format("%.4f", record.valueLevelRate or 0))
    else
        detail = color(C.combined, "Score " .. string.format("%.0f", (record.combinedScore or 0) * 100)) .. color(C.muted, "  |  ") .. color(C.xp, string.format("%.1f%% level/hr", record.xpLevelPercentPerHour or 0)) .. color(C.muted, "  |  ") .. color(C.value, ns:FormatMoney(record.vendorPerHour or 0) .. "/hr")
    end
    return line, color(C.muted, "  " .. classText(record.class, record.classFile) .. "  ") .. detail
end

function UI:AddTierMetric(lines, title, records, tierField, rankField, metric)
    self:TierMetricHeader(lines, title, metric)
    if #records == 0 then
        table.insert(lines, color(C.muted, "No sessions recorded yet."))
        return
    end

    local sorted = sortedForMetric(records, rankField)
    local shownAny = false
    for _, tier in ipairs(ns.GrindTiers:GetTierOrder()) do
        local shownTier = false
        for _, record in ipairs(sorted) do
            if record[tierField] == tier then
                if not shownTier then
                    table.insert(lines, "")
                    table.insert(lines, color(TIER_COLORS[tier] or C.title, tier .. " TIER") .. color(C.dim, "  " .. divider("-", 32)))
                    shownTier = true
                end
                shownAny = true
                local headline, detail = self:TierRecordLine(record, rankField, metric, tierField)
                table.insert(lines, headline)
                table.insert(lines, detail)
            end
        end
    end

    if not shownAny then
        table.insert(lines, color(C.muted, "No scored sessions in this category."))
    end
end

function UI:BuildGrindTierLines()
    local lines = {}
    if not ns.GrindTiers then
        table.insert(lines, color(C.warning, "Grind tier module is not loaded."))
        return lines
    end

    local scope = self:GetGrindTierScope()
    local scopeLabel = ns.GrindTiers:GetScopeLabel(scope)
    local records = ns.GrindTiers:RankRecords(scope)

    table.insert(lines, color(C.title, "TIER LIST: " .. string.upper(scopeLabel)))
    table.insert(lines, color(C.dim, divider("=", 44)))
    table.insert(lines, color(C.muted, "XP and vendor value are scaled by XP needed at the highest mob level recorded in each run."))
    table.insert(lines, color(C.dim, "Combined score normalizes XP and vendor value within this tab, then averages them."))

    self:AddTierMetric(lines, "XP / Hour", records, "xpTier", "xpRank", "xp")
    self:AddTierMetric(lines, "Vendor Value / Hour", records, "valueTier", "valueRank", "value")
    self:AddTierMetric(lines, "Combined Score", records, "combinedTier", "combinedRank", "combined")
    return lines
end

local originalBuildGrindLines = UI.BuildGrindLines
function UI:BuildGrindLines()
    local active = ns.Grinding and ns.Grinding:GetActive()
    if active then
        return originalBuildGrindLines(self)
    end
    return self:BuildGrindTierLines()
end

function UI:UpdateGrindTierControls()
    local frame = self.frame
    if not frame or not frame.grindTierTabs or self.view == "info" then
        return
    end

    local active = ns.Grinding and ns.Grinding:GetActive()
    local showTabs = self.view == "grind" and not active
    local selected = self:GetGrindTierScope()

    for _, button in ipairs(frame.grindTierTabs) do
        setVisible(button, showTabs)
        if button.SetText then
            if button.scope == selected then
                button:SetText("*" .. button.baseLabel)
            else
                button:SetText(button.baseLabel)
            end
        end
    end

    if showTabs then
        setVisible(frame.stopButton, false)
        setVisible(frame.resetButton, false)
        setVisible(frame.startButton, true)
        setVisible(frame.refreshButton, false)
    end
end

local originalRefresh = UI.Refresh
function UI:Refresh()
    originalRefresh(self)
    self:UpdateGrindTierControls()
end
