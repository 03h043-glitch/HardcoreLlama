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
    reset = "|r",
}

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function classText(className, classFile)
    if ns.ClassColorize then
        return ns:ClassColorize(className, classFile)
    end
    return tostring(className or classFile or "Unknown")
end

local function vendorValue(session)
    if ns.Grinding and ns.Grinding.GetVendorValue then
        return ns.Grinding:GetVendorValue(session)
    end
    return tonumber(session and session.lootVendorCopper or 0) or 0
end

local function meter(percent, width)
    width = width or 18
    percent = math.max(0, math.min(1, tonumber(percent) or 0))
    local filled = math.floor((percent * width) + 0.5)
    return "[" .. string.rep("#", filled) .. string.rep("-", width - filled) .. "]"
end

local function sourceLabel(source)
    return (ns.SOURCE_LABELS and ns.SOURCE_LABELS[source]) or tostring(source or "Other")
end

function UI:MetricLine(label, value, note)
    local line = color(C.muted, string.format("%-16s", tostring(label))) .. color(C.white, tostring(value))
    if note and note ~= "" then
        line = line .. color(C.dim, "  " .. tostring(note))
    end
    return line
end

function UI:AddActiveGrindSources(lines, active)
    self:Section(lines, "XP Breakdown")
    local total = tonumber(active.xpGained) or 0
    local sourceXP = active.sourceXP or {}
    local shown = false

    for _, source in ipairs(ns.SOURCE_ORDER or {}) do
        local amount = tonumber(sourceXP[source]) or 0
        if amount > 0 then
            shown = true
            local pct = total > 0 and amount / total or 0
            table.insert(lines, color(C.white, string.format("%-12s", sourceLabel(source))) .. " " .. color(C.accent, meter(pct, 16)) .. color(C.muted, "  " .. ns:FormatNumber(amount) .. "  " .. ns:Percent(amount, total)))
        end
    end

    for source, amount in pairs(sourceXP) do
        local known = false
        for _, ordered in ipairs(ns.SOURCE_ORDER or {}) do
            if ordered == source then
                known = true
                break
            end
        end
        if not known and (tonumber(amount) or 0) > 0 then
            shown = true
            local pct = total > 0 and amount / total or 0
            table.insert(lines, color(C.white, string.format("%-12s", sourceLabel(source))) .. " " .. color(C.accent, meter(pct, 16)) .. color(C.muted, "  " .. ns:FormatNumber(amount) .. "  " .. ns:Percent(amount, total)))
        end
    end

    if not shown then
        table.insert(lines, color(C.muted, "No XP recorded yet."))
    end
end

function UI:BuildActiveGrindLines(active)
    local lines = {}
    if not ns.Grinding then
        table.insert(lines, color(C.warning, "Grinding module is not loaded."))
        return lines
    end

    ns.Grinding:UpdateRates(active)
    local topMob = ns.Grinding:UpdateTopMob(active)
    local idleRemaining = ns.Grinding:GetIdleRemaining(active)

    self:Section(lines, "Active Grind")
    table.insert(lines, color(C.accent, tostring(active.name or "Grinding Session")) .. color(C.muted, "  ") .. classText(active.class, active.classFile) .. color(C.muted, " L" .. tostring(active.levelStart or "?")))
    if active.zoneStart then
        table.insert(lines, color(C.dim, "Zone: " .. tostring(active.zoneStart)))
    end
    if topMob then
        table.insert(lines, color(C.dim, "Most common mob: " .. tostring(ns.Grinding:FormatPrimaryMob(topMob))))
    end

    self:Section(lines, "Live Metrics")
    table.insert(lines, self:MetricLine("XP/hour", ns:FormatNumber(active.xpPerHour or 0)))
    table.insert(lines, self:MetricLine("Total XP", ns:FormatNumber(active.xpGained or 0)))
    table.insert(lines, self:MetricLine("Mob kills", ns:FormatNumber(active.mobCount or 0)))
    table.insert(lines, self:MetricLine("Average XP/mob", ns:FormatNumber(active.averageXPPerMob or 0)))
    table.insert(lines, self:MetricLine("Rested XP", ns:FormatNumber(active.restedXP or 0)))
    table.insert(lines, self:MetricLine("Vendor value", ns:FormatMoney(vendorValue(active)), "looted items only"))
    table.insert(lines, self:MetricLine("Duration", ns:FormatDuration(active.duration or 0)))
    table.insert(lines, self:MetricLine("Idle stop in", ns:FormatDuration(idleRemaining), "resets on XP or loot"))

    self:AddActiveGrindSources(lines, active)

    self:Section(lines, "Controls")
    table.insert(lines, color(C.muted, "Use the Stop button or /hcl grind stop to save this session now."))
    return lines
end

function UI:BuildSavedGrindLines()
    local lines = {}
    if not ns.Grinding then
        table.insert(lines, color(C.warning, "Grinding module is not loaded."))
        return lines
    end

    self:Section(lines, "Recent Sessions")
    local sessions = ns.Grinding:GetRecentSessions(6)
    if #sessions == 0 then
        table.insert(lines, color(C.muted, "No saved grind sessions yet."))
    else
        for _, session in ipairs(sessions) do
            table.insert(lines, color(C.accent, ns.Grinding:FormatSessionTitle(session)) .. self:SessionClassLine(session))
            table.insert(lines, color(C.muted, "  " .. ns:FormatNumber(session.xpGained or 0) .. " XP  |  " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatMoney(vendorValue(session)) .. " vendor value"))
        end
    end

    self:Section(lines, "Best XP/Hour")
    local best = ns.Grinding:GetBestSessions(6)
    if #best == 0 then
        table.insert(lines, color(C.muted, "No best-session comparisons yet."))
    else
        for index, session in ipairs(best) do
            table.insert(lines, color(C.title, tostring(index) .. ". ") .. color(C.accent, ns.Grinding:FormatSessionTitle(session)) .. self:SessionClassLine(session))
            table.insert(lines, color(C.muted, "  " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatNumber(session.xpGained or 0) .. " XP  |  " .. ns:FormatMoney(vendorValue(session)) .. " vendor value"))
        end
    end

    return lines
end

function UI:BuildGrindLines()
    local active = ns.Grinding and ns.Grinding:GetActive()
    if active then
        return self:BuildActiveGrindLines(active)
    end
    return self:BuildSavedGrindLines()
end

function UI:UpdateGrindControls()
    local frame = self.frame
    if not frame or self.view == "info" then
        return
    end

    local active = ns.Grinding and ns.Grinding:GetActive()
    local isActiveGrind = self.view == "grind" and active ~= nil

    if frame.startButton then
        if isActiveGrind then
            frame.startButton:Hide()
        else
            frame.startButton:Show()
        end
    end
    if frame.stopButton then
        frame.stopButton:Show()
    end
    if frame.resetButton then
        if isActiveGrind then
            frame.resetButton:Hide()
        else
            frame.resetButton:Show()
        end
    end
    if frame.refreshButton then
        frame.refreshButton:Show()
    end
end

local originalRefresh = UI.Refresh
function UI:Refresh()
    originalRefresh(self)
    self:UpdateGrindControls()
end

if ns.Grinding then
    function ns.Grinding:PrintBest()
        local sessions = self:GetBestSessions(5)
        if #sessions == 0 then
            ns:Print("No saved grind sessions to compare yet.")
            return
        end

        ns:Print("Best saved grind sessions by XP/hour:")
        for index, session in ipairs(sessions) do
            ns:Print(index .. ". " .. self:FormatSessionTitle(session) .. " - " .. classText(session.class, session.classFile) .. " level " .. tostring(session.levelStart) .. ": " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour, " .. ns:FormatNumber(session.xpGained or 0) .. " XP, " .. ns:FormatMoney(vendorValue(session)) .. " vendor value")
        end
    end
end
