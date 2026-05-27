local _, ns = ...

local UI = {}
ns.UI = UI

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 96, 24)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function UI:BuildFrame()
    if self.frame then
        return self.frame
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "HardcoreLlamaFrame", UIParent, template)
    frame:SetSize(560, 430)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetText("HardcoreLlama")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -6, -6)

    frame.overviewButton = makeButton(frame, "Overview", 92, function()
        ns.UI:SetView("overview")
    end)
    frame.overviewButton:SetPoint("TOPLEFT", 18, -48)

    frame.grindButton = makeButton(frame, "Grind", 92, function()
        ns.UI:SetView("grind")
    end)
    frame.grindButton:SetPoint("LEFT", frame.overviewButton, "RIGHT", 6, 0)

    frame.reminderButton = makeButton(frame, "Reminders", 104, function()
        ns.UI:SetView("reminders")
    end)
    frame.reminderButton:SetPoint("LEFT", frame.grindButton, "RIGHT", 6, 0)

    frame.startButton = makeButton(frame, "Start Grind", 104, function()
        if ns.Grinding then
            ns.Grinding:Start((GetZoneText and GetZoneText()) or "Grinding Session")
            ns.UI:SetView("grind")
        end
    end)
    frame.startButton:SetPoint("BOTTOMLEFT", 18, 18)

    frame.stopButton = makeButton(frame, "Stop Grind", 104, function()
        if ns.Grinding then
            ns.Grinding:Stop()
            ns.UI:SetView("grind")
        end
    end)
    frame.stopButton:SetPoint("LEFT", frame.startButton, "RIGHT", 8, 0)

    frame.refreshButton = makeButton(frame, "Refresh", 88, function()
        ns.UI:Refresh()
    end)
    frame.refreshButton:SetPoint("BOTTOMRIGHT", -18, 18)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -82)
    scroll:SetPoint("BOTTOMRIGHT", -36, 52)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(500, 300)
    scroll:SetScrollChild(content)

    local body = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 0, 0)
    body:SetWidth(486)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText("")

    self.frame = frame
    self.scroll = scroll
    self.content = content
    self.body = body
    self.view = "overview"

    return frame
end

function UI:Show()
    local frame = self:BuildFrame()
    frame:Show()
    self:Refresh()
end

function UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function UI:Toggle()
    local frame = self:BuildFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        self:Refresh()
    end
end

function UI:SetView(view)
    self.view = view or "overview"
    self:Refresh()
end

function UI:SetLines(lines)
    self.body:SetText(table.concat(lines, "\n"))
    local height = self.body:GetStringHeight() + 24
    self.content:SetHeight(math.max(300, height))
    self.content:SetWidth(500)
end

function UI:BuildOverviewLines()
    local lines = {}
    if not ns.Database then
        table.insert(lines, "Database module is not loaded.")
        return lines
    end

    local character = ns.Database:TouchCharacter()
    local db = ns.Database:GetDB()
    local xp = character.xp or {}

    table.insert(lines, "Character")
    table.insert(lines, character.name .. "-" .. character.realm .. " | Level " .. tostring(character.level) .. " " .. tostring(character.class))
    table.insert(lines, "Tracked XP: " .. ns:FormatNumber(xp.total or 0))
    table.insert(lines, "Rested XP: " .. ns:FormatNumber(xp.rested or 0))
    table.insert(lines, "")
    table.insert(lines, "XP by source")

    local hasSource = false
    for _, source in ipairs(ns.SOURCE_ORDER or {}) do
        local amount = xp.bySource and xp.bySource[source] or 0
        if amount > 0 then
            hasSource = true
            table.insert(lines, (ns.SOURCE_LABELS[source] or source) .. ": " .. ns:FormatNumber(amount) .. " (" .. ns:Percent(amount, xp.total or 0) .. ")")
        end
    end
    if not hasSource then
        table.insert(lines, "No XP gains tracked yet on this character.")
    end

    table.insert(lines, "")
    table.insert(lines, "Highest level by class")
    local hasHigh = false
    for classFile, record in pairs(db.classHighs or {}) do
        hasHigh = true
        table.insert(lines, tostring(record.class or classFile) .. ": level " .. tostring(record.level or 0) .. " by " .. tostring(record.character or "Unknown"))
    end
    if not hasHigh then
        table.insert(lines, "No class highs recorded yet.")
    end

    table.insert(lines, "")
    table.insert(lines, "Fastest level times")
    local count = 0
    for level = 1, 60 do
        local record = db.fastestLevelTimes and db.fastestLevelTimes[level]
        if record then
            count = count + 1
            table.insert(lines, "Level " .. tostring(level) .. ": " .. ns:FormatDuration(record.seconds or 0) .. " by " .. tostring(record.character or "Unknown") .. " (" .. tostring(record.class or "") .. ")")
            if count >= 8 then
                break
            end
        end
    end
    if count == 0 then
        table.insert(lines, "No completed level timing yet.")
    end

    return lines
end

function UI:BuildGrindLines()
    local lines = {}
    if not ns.Grinding then
        table.insert(lines, "Grinding module is not loaded.")
        return lines
    end

    for _, line in ipairs(ns.Grinding:BuildStatusLines()) do
        table.insert(lines, line)
    end

    table.insert(lines, "")
    table.insert(lines, "Recent saved sessions")
    local sessions = ns.Grinding:GetRecentSessions(8)
    if #sessions == 0 then
        table.insert(lines, "No saved grind sessions yet.")
    else
        for _, session in ipairs(sessions) do
            table.insert(lines, tostring(session.name) .. " | " .. tostring(session.class) .. " level " .. tostring(session.levelStart) .. " | " .. ns:FormatNumber(session.xpGained or 0) .. " XP | " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour | " .. ns:FormatMoney(session.totalValueCopper or 0))
        end
    end

    return lines
end

function UI:BuildReminderLines()
    local lines = {}
    if not ns.Reminders then
        table.insert(lines, "Reminder module is not loaded.")
        return lines
    end

    ns.Reminders:ScanSkills()
    local reminders = ns.Reminders:BuildList()

    table.insert(lines, "Due now")
    if #reminders.due == 0 then
        table.insert(lines, "No due training reminders.")
    else
        for _, item in ipairs(reminders.due) do
            table.insert(lines, item.title)
            table.insert(lines, "  " .. item.detail)
            table.insert(lines, "  Where: " .. tostring(item.where))
            table.insert(lines, "  Cost: " .. tostring(item.cost))
            table.insert(lines, "")
        end
    end

    table.insert(lines, "")
    table.insert(lines, "Upcoming")
    if #reminders.upcoming == 0 then
        table.insert(lines, "No upcoming training reminders.")
    else
        for _, item in ipairs(reminders.upcoming) do
            table.insert(lines, item.title)
            table.insert(lines, "  " .. item.detail)
            table.insert(lines, "  Where: " .. tostring(item.where))
            table.insert(lines, "  Cost: " .. tostring(item.cost))
            table.insert(lines, "")
        end
    end

    return lines
end

function UI:Refresh()
    if not self.frame then
        return
    end

    local lines
    if self.view == "grind" then
        lines = self:BuildGrindLines()
    elseif self.view == "reminders" then
        lines = self:BuildReminderLines()
    else
        lines = self:BuildOverviewLines()
    end

    self:SetLines(lines)
end
