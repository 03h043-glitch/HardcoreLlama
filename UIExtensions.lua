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
    death = "|cffff6b6b",
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

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 72, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function formatDate(timestamp)
    if timestamp and type(date) == "function" then
        return date("%Y-%m-%d %H:%M", timestamp)
    end
    return "Unknown time"
end

local function addTooltipLines(tooltip, lines)
    for _, line in ipairs(lines or {}) do
        tooltip:AddLine(line, 0.86, 0.86, 0.86, false)
    end
end

local originalBuildFrame = UI.BuildFrame
function UI:BuildFrame()
    local frame = originalBuildFrame(self)
    if frame.dungeonButton then
        return frame
    end

    frame.overviewButton:SetText("Stats")
    frame.overviewButton:SetSize(52, 22)
    frame.grindButton:SetSize(54, 22)
    frame.grindButton:ClearAllPoints()
    frame.grindButton:SetPoint("LEFT", frame.overviewButton, "RIGHT", 5, 0)

    frame.dungeonButton = makeButton(frame, "Dungeons", 78, function()
        ns.UI:SetView("dungeons")
    end)
    frame.dungeonButton:SetPoint("LEFT", frame.grindButton, "RIGHT", 5, 0)

    frame.reminderButton:SetText("Train")
    frame.reminderButton:SetSize(54, 22)
    frame.reminderButton:ClearAllPoints()
    frame.reminderButton:SetPoint("LEFT", frame.dungeonButton, "RIGHT", 5, 0)

    frame.fallenButton:SetSize(58, 22)
    frame.fallenButton:ClearAllPoints()
    frame.fallenButton:SetPoint("LEFT", frame.reminderButton, "RIGHT", 5, 0)

    return frame
end

function UI:ShowTooltip(row)
    if not row or not row.button or not GameTooltip then
        return
    end

    GameTooltip:SetOwner(row.button, "ANCHOR_RIGHT")
    if row.itemID and GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink("item:" .. tostring(row.itemID))
        if row.extraItemText and row.extraItemText ~= "" then
            GameTooltip:AddLine(" ", 1, 1, 1, false)
            GameTooltip:AddLine(row.extraItemText, 0.86, 0.86, 0.86, false)
        end
        addTooltipLines(GameTooltip, row.lines)
        GameTooltip:Show()
        return
    end

    GameTooltip:AddLine(row.title or "Details", 1, 0.82, 0, false)
    addTooltipLines(GameTooltip, row.lines)
    GameTooltip:Show()
end

function UI:LayoutHoverRows()
    if not self.content or not self.body then
        return
    end

    self.hoverButtons = self.hoverButtons or {}
    local rows = self.hoverRows or {}
    local width = self.body:GetWidth() or 300
    local lineHeight = math.max(14, (self:GetSettings().fontSize or 12) + 4)

    for index, row in ipairs(rows) do
        local button = self.hoverButtons[index]
        if not button then
            button = CreateFrame("Button", nil, self.content)
            button:SetFrameLevel((self.content:GetFrameLevel() or 0) + 5)
            button:EnableMouse(true)
            button:SetScript("OnEnter", function(owner)
                ns.UI:ShowTooltip(owner.tooltipRow)
            end)
            button:SetScript("OnLeave", function()
                if GameTooltip then
                    GameTooltip:Hide()
                end
            end)
            self.hoverButtons[index] = button
        end

        row.button = button
        button.tooltipRow = row
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -((row.line or 1) - 1) * lineHeight)
        button:SetSize(width, lineHeight)
        button:Show()
    end

    for index = #rows + 1, #self.hoverButtons do
        self.hoverButtons[index]:Hide()
        self.hoverButtons[index].tooltipRow = nil
    end
end

local originalUpdateLayout = UI.UpdateLayout
function UI:UpdateLayout()
    originalUpdateLayout(self)
    self:LayoutHoverRows()
end

function UI:SetLines(lines, hoverRows)
    self.hoverRows = hoverRows or {}
    self:ApplyFont()
    self.body:SetText(table.concat(lines, "\n"))
    self:UpdateLayout()
end

function UI:SessionClassLine(session)
    return color(C.muted, "  ") .. classText(session.class, session.classFile) .. color(C.muted, " L" .. tostring(session.levelStart))
end

function UI:BuildOverviewLines()
    local lines = {}
    if not ns.Database then
        table.insert(lines, color(C.warning, "Database module is not loaded."))
        return lines
    end

    local character = ns.Database:TouchCharacter()
    local db = ns.Database:GetDB()
    local xp = character.xp or {}

    self:Section(lines, "Character")
    table.insert(lines, color(C.accent, character.name .. "-" .. character.realm) .. color(C.muted, "  Level ") .. color(C.white, tostring(character.level) .. " ") .. classText(character.class, character.classFile))
    self:KV(lines, "Tracked XP", ns:FormatNumber(xp.total or 0))
    self:KV(lines, "Rested XP", ns:FormatNumber(xp.rested or 0))

    self:Section(lines, "XP Sources")
    local hasSource = false
    for _, source in ipairs(ns.SOURCE_ORDER or {}) do
        local amount = xp.bySource and xp.bySource[source] or 0
        if amount > 0 then
            hasSource = true
            table.insert(lines, color(C.white, ns.SOURCE_LABELS[source] or source) .. color(C.muted, "  " .. ns:FormatNumber(amount) .. "  " .. ns:Percent(amount, xp.total or 0)))
        end
    end
    if not hasSource then
        table.insert(lines, color(C.muted, "No XP gains tracked yet on this character."))
    end

    self:Section(lines, "Class Highs")
    local hasHigh = false
    for classFile, record in pairs(db.classHighs or {}) do
        hasHigh = true
        table.insert(lines, classText(record.class or classFile, classFile) .. color(C.muted, "  level ") .. color(C.accent, tostring(record.level or 0)) .. color(C.muted, "  " .. tostring(record.character or "Unknown")))
    end
    if not hasHigh then
        table.insert(lines, color(C.muted, "No class highs recorded yet."))
    end

    self:Section(lines, "Fastest Levels")
    local fastest = {}
    for levelKey, record in pairs(db.fastestLevelTimes or {}) do
        local level = tonumber(levelKey) or tonumber(record and record.level)
        if level and record then
            table.insert(fastest, { level = level, record = record })
        end
    end

    table.sort(fastest, function(left, right)
        if left.level == right.level then
            return (left.record.seconds or math.huge) < (right.record.seconds or math.huge)
        end
        return left.level > right.level
    end)

    if #fastest == 0 then
        table.insert(lines, color(C.muted, "No completed level timing yet."))
    else
        for _, entry in ipairs(fastest) do
            local record = entry.record
            local source = record.source and record.source ~= "" and color(C.dim, "  " .. tostring(record.source)) or ""
            table.insert(lines, color(C.white, "Level " .. tostring(entry.level)) .. color(C.muted, "  " .. ns:FormatDuration(record.seconds or 0) .. "  " .. tostring(record.character or "Unknown") .. "  ") .. classText(record.class, record.classFile) .. source)
        end
    end

    return lines
end

function UI:BuildGrindLines()
    local lines = {}
    if not ns.Grinding then
        table.insert(lines, color(C.warning, "Grinding module is not loaded."))
        return lines
    end

    self:Section(lines, "Active Grind")
    for _, line in ipairs(ns.Grinding:BuildStatusLines()) do
        table.insert(lines, color(C.white, line))
    end

    self:Section(lines, "Recent Sessions")
    local sessions = ns.Grinding:GetRecentSessions(6)
    if #sessions == 0 then
        table.insert(lines, color(C.muted, "No saved grind sessions yet."))
    else
        for _, session in ipairs(sessions) do
            table.insert(lines, color(C.accent, ns.Grinding:FormatSessionTitle(session)) .. self:SessionClassLine(session))
            table.insert(lines, color(C.muted, "  " .. ns:FormatNumber(session.xpGained or 0) .. " XP  |  " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatMoney(session.totalValueCopper or 0)))
        end
    end

    self:Section(lines, "Best XP/Hour")
    local best = ns.Grinding:GetBestSessions(6)
    if #best == 0 then
        table.insert(lines, color(C.muted, "No best-session comparisons yet."))
    else
        for index, session in ipairs(best) do
            table.insert(lines, color(C.title, tostring(index) .. ". ") .. color(C.accent, ns.Grinding:FormatSessionTitle(session)) .. self:SessionClassLine(session))
            table.insert(lines, color(C.muted, "  " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatNumber(session.xpGained or 0) .. " XP  |  " .. ns:FormatMoney(session.totalValueCopper or 0)))
        end
    end

    return lines
end

function UI:DungeonSummaryLine(run)
    return color(C.muted, "  " .. ns:FormatNumber(run.xpGained or 0) .. " XP  |  " .. ns:FormatNumber(run.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatMoney(run.totalValueCopper or 0))
end

function UI:AddDungeonRun(lines, hoverRows, run, prefix)
    local lineIndex = #lines + 1
    table.insert(lines, (prefix or "") .. color(C.accent, tostring(run.name or "Dungeon")) .. self:SessionClassLine(run))
    table.insert(lines, self:DungeonSummaryLine(run))
    table.insert(hoverRows, {
        line = lineIndex,
        title = tostring(run.name or "Dungeon") .. " - Including Quests",
        lines = ns.Dungeons and ns.Dungeons:BuildTooltipLines(run) or {},
    })
end

function UI:BuildDungeonLines()
    local lines = {}
    local hoverRows = {}
    if not ns.Dungeons then
        table.insert(lines, color(C.warning, "Dungeon module is not loaded."))
        return lines, hoverRows
    end

    self:Section(lines, "Active Dungeon")
    for _, line in ipairs(ns.Dungeons:BuildStatusLines()) do
        table.insert(lines, color(C.white, line))
    end

    self:Section(lines, "Recent Dungeons")
    local runs = ns.Dungeons:GetRecentRuns(6)
    if #runs == 0 then
        table.insert(lines, color(C.muted, "No saved dungeon runs yet."))
    else
        for _, run in ipairs(runs) do
            self:AddDungeonRun(lines, hoverRows, run)
        end
    end

    self:Section(lines, "Best XP/Hour")
    local best = ns.Dungeons:GetBestRuns(6)
    if #best == 0 then
        table.insert(lines, color(C.muted, "No dungeon comparisons yet."))
    else
        for index, run in ipairs(best) do
            self:AddDungeonRun(lines, hoverRows, run, color(C.title, tostring(index) .. ". "))
        end
    end

    return lines, hoverRows
end

function UI:BuildFallenLines()
    local lines = {}
    self:Section(lines, "Fallen Heroes")

    if not ns.Database then
        table.insert(lines, color(C.warning, "Database module is not loaded."))
        return lines
    end

    local heroes = ns.Database:GetFallenHeroes()
    if #heroes == 0 then
        table.insert(lines, color(C.muted, "No deaths recorded yet."))
        return lines
    end

    for index, record in ipairs(heroes) do
        if index > 30 then
            break
        end

        local played = record.playedTotal and ns:FormatDuration(record.playedTotal) or "Played time pending"
        local name = tostring(record.name or "Unknown") .. "-" .. tostring(record.realm or "UnknownRealm")
        table.insert(lines, color(C.death, name) .. color(C.muted, "  Level ") .. color(C.white, tostring(record.level or "?") .. " " .. tostring(record.race or "") .. " ") .. classText(record.class, record.classFile))
        table.insert(lines, color(C.muted, "  /played " .. played .. "  |  " .. formatDate(record.diedAt)))
        if record.zone then
            table.insert(lines, color(C.dim, "  Zone: " .. tostring(record.zone)))
        end
    end

    return lines
end

function UI:Refresh()
    if not self.frame then
        return
    end

    local lines
    local hoverRows
    if self.view == "grind" then
        lines = self:BuildGrindLines()
    elseif self.view == "dungeons" then
        lines, hoverRows = self:BuildDungeonLines()
    elseif self.view == "reminders" then
        lines = self:BuildReminderLines()
    elseif self.view == "fallen" then
        lines = self:BuildFallenLines()
    else
        lines = self:BuildOverviewLines()
    end

    self:SetLines(lines, hoverRows)
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
            ns:Print(index .. ". " .. self:FormatSessionTitle(session) .. " - " .. classText(session.class, session.classFile) .. " level " .. tostring(session.levelStart) .. ": " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour, " .. ns:FormatNumber(session.xpGained or 0) .. " XP, " .. ns:FormatMoney(session.totalValueCopper or 0))
        end
    end
end
