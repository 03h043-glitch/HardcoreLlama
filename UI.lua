local _, ns = ...

local UI = {}
ns.UI = UI

local C = {
    title = "|cffffd100",
    accent = "|cff33ff99",
    class = "|cff8ab4ff",
    profession = "|cffd6a9ff",
    death = "|cffff6b6b",
    white = "|cffffffff",
    muted = "|cff9d9d9d",
    dim = "|cff666666",
    warning = "|cffffb347",
    reset = "|r",
}

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function formatDate(timestamp)
    if timestamp and type(date) == "function" then
        return date("%Y-%m-%d %H:%M", timestamp)
    end
    return "Unknown time"
end

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 72, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function UI:GetSettings()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        return { fontSize = 12, windowWidth = 430, windowHeight = 330 }
    end
    db.settings.ui = db.settings.ui or {}
    db.settings.ui.fontSize = db.settings.ui.fontSize or 12
    db.settings.ui.windowWidth = db.settings.ui.windowWidth or 430
    db.settings.ui.windowHeight = db.settings.ui.windowHeight or 330
    return db.settings.ui
end

function UI:ApplyFont()
    if not self.body then
        return
    end

    local settings = self:GetSettings()
    local font, _, flags = GameFontHighlightSmall:GetFont()
    self.body:SetFont(font, settings.fontSize or 12, flags)
end

function UI:SetFontSize(size, quiet)
    size = math.floor(tonumber(size) or self:GetSettings().fontSize or 12)
    size = math.max(9, math.min(18, size))
    self:GetSettings().fontSize = size
    self:ApplyFont()
    self:Refresh()
    if not quiet then
        ns:Print("window text size set to " .. tostring(size) .. ".")
    end
end

function UI:AdjustFont(delta)
    self:SetFontSize((self:GetSettings().fontSize or 12) + delta)
end

function UI:SaveSize(width, height)
    local settings = self:GetSettings()
    settings.windowWidth = math.floor(width or settings.windowWidth or 430)
    settings.windowHeight = math.floor(height or settings.windowHeight or 330)
end

function UI:ResetWindow()
    local settings = self:GetSettings()
    settings.windowWidth = 430
    settings.windowHeight = 330
    settings.fontSize = 12
    if self.frame then
        self.frame:SetSize(settings.windowWidth, settings.windowHeight)
    end
    self:SetFontSize(settings.fontSize, true)
    ns:Print("window size and text size reset.")
end

function UI:BuildFrame()
    if self.frame then
        return self.frame
    end

    local settings = self:GetSettings()
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local frame = CreateFrame("Frame", "HardcoreLlamaFrame", UIParent, template)
    frame:SetSize(settings.windowWidth or 430, settings.windowHeight or 330)
    frame:SetPoint("CENTER")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(360, 260, 820, 680)
    else
        frame:SetMinResize(360, 260)
        frame:SetMaxResize(820, 680)
    end
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        frame:SetBackdropColor(0.04, 0.05, 0.05, 0.94)
        frame:SetBackdropBorderColor(0.32, 0.55, 0.45, 0.95)
    end

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.title:SetText(color(C.accent, "HardcoreLlama"))

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -4, -4)

    frame.fontDown = makeButton(frame, "A-", 34, function()
        ns.UI:AdjustFont(-1)
    end)
    frame.fontDown:SetPoint("RIGHT", frame.close, "LEFT", -38, -1)

    frame.fontUp = makeButton(frame, "A+", 34, function()
        ns.UI:AdjustFont(1)
    end)
    frame.fontUp:SetPoint("LEFT", frame.fontDown, "RIGHT", 4, 0)

    frame.overviewButton = makeButton(frame, "Overview", 70, function()
        ns.UI:SetView("overview")
    end)
    frame.overviewButton:SetPoint("TOPLEFT", 14, -40)

    frame.grindButton = makeButton(frame, "Grind", 56, function()
        ns.UI:SetView("grind")
    end)
    frame.grindButton:SetPoint("LEFT", frame.overviewButton, "RIGHT", 5, 0)

    frame.reminderButton = makeButton(frame, "Reminders", 84, function()
        ns.UI:SetView("reminders")
    end)
    frame.reminderButton:SetPoint("LEFT", frame.grindButton, "RIGHT", 5, 0)

    frame.fallenButton = makeButton(frame, "Fallen", 68, function()
        ns.UI:SetView("fallen")
    end)
    frame.fallenButton:SetPoint("LEFT", frame.reminderButton, "RIGHT", 5, 0)

    frame.startButton = makeButton(frame, "Start Grind", 92, function()
        if ns.Grinding then
            ns.Grinding:Start((GetZoneText and GetZoneText()) or "Grinding Session")
            ns.UI:SetView("grind")
        end
    end)
    frame.startButton:SetPoint("BOTTOMLEFT", 14, 12)

    frame.stopButton = makeButton(frame, "Stop", 56, function()
        if ns.Grinding then
            ns.Grinding:Stop()
            ns.UI:SetView("grind")
        end
    end)
    frame.stopButton:SetPoint("LEFT", frame.startButton, "RIGHT", 6, 0)

    frame.resetButton = makeButton(frame, "Reset", 56, function()
        ns.UI:ResetWindow()
    end)
    frame.resetButton:SetPoint("LEFT", frame.stopButton, "RIGHT", 6, 0)

    frame.refreshButton = makeButton(frame, "Refresh", 70, function()
        ns.UI:Refresh()
    end)
    frame.refreshButton:SetPoint("BOTTOMRIGHT", -32, 12)

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
        ns.UI:SaveSize(frame:GetWidth(), frame:GetHeight())
        ns.UI:UpdateLayout()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -68)
    scroll:SetPoint("BOTTOMRIGHT", -30, 42)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(360, 220)
    scroll:SetScrollChild(content)

    local body = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    body:SetPoint("TOPLEFT", 0, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    if body.SetWordWrap then
        body:SetWordWrap(true)
    end
    body:SetText("")

    self.frame = frame
    self.scroll = scroll
    self.content = content
    self.body = body
    self.view = "overview"

    frame:SetScript("OnSizeChanged", function(_, width, height)
        ns.UI:SaveSize(width, height)
        ns.UI:UpdateLayout()
    end)

    self:ApplyFont()
    self:UpdateLayout()
    return frame
end

function UI:UpdateLayout()
    if not self.scroll or not self.body or not self.content then
        return
    end

    local width = math.max(260, self.scroll:GetWidth() - 18)
    self.body:SetWidth(width)
    self.content:SetWidth(width)
    local height = (self.body:GetStringHeight() or 0) + 20
    self.content:SetHeight(math.max(self.scroll:GetHeight(), height))
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

function UI:Section(lines, title)
    if #lines > 0 then
        table.insert(lines, "")
    end
    table.insert(lines, color(C.title, string.upper(title)))
    table.insert(lines, color(C.dim, "--------------------------------"))
end

function UI:KV(lines, label, value)
    table.insert(lines, color(C.muted, label) .. "  " .. color(C.white, value))
end

function UI:SetLines(lines)
    self:ApplyFont()
    self.body:SetText(table.concat(lines, "\n"))
    self:UpdateLayout()
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
    table.insert(lines, color(C.accent, character.name .. "-" .. character.realm) .. color(C.muted, "  Level ") .. color(C.white, tostring(character.level) .. " " .. tostring(character.class)))
    self:KV(lines, "Tracked XP", ns:FormatNumber(xp.total or 0))
    self:KV(lines, "Rested XP", ns:FormatNumber(xp.rested or 0))

    self:Section(lines, "XP Sources")
    local hasSource = false
    for _, source in ipairs(ns.SOURCE_ORDER or {}) do
        local amount = xp.bySource and xp.bySource[source] or 0
        if amount > 0 then
            hasSource = true
            local label = ns.SOURCE_LABELS[source] or source
            table.insert(lines, color(C.white, label) .. color(C.muted, "  " .. ns:FormatNumber(amount) .. "  " .. ns:Percent(amount, xp.total or 0)))
        end
    end
    if not hasSource then
        table.insert(lines, color(C.muted, "No XP gains tracked yet on this character."))
    end

    self:Section(lines, "Class Highs")
    local hasHigh = false
    for classFile, record in pairs(db.classHighs or {}) do
        hasHigh = true
        table.insert(lines, color(C.white, tostring(record.class or classFile)) .. color(C.muted, "  level ") .. color(C.accent, tostring(record.level or 0)) .. color(C.muted, "  " .. tostring(record.character or "Unknown")))
    end
    if not hasHigh then
        table.insert(lines, color(C.muted, "No class highs recorded yet."))
    end

    self:Section(lines, "Fastest Levels")
    local count = 0
    for level = 1, 60 do
        local record = db.fastestLevelTimes and db.fastestLevelTimes[level]
        if record then
            count = count + 1
            table.insert(lines, color(C.white, "Level " .. tostring(level)) .. color(C.muted, "  " .. ns:FormatDuration(record.seconds or 0) .. "  " .. tostring(record.character or "Unknown") .. "  " .. tostring(record.class or "")))
            if count >= 6 then
                break
            end
        end
    end
    if count == 0 then
        table.insert(lines, color(C.muted, "No completed level timing yet."))
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
            local title = ns.Grinding:FormatSessionTitle(session)
            table.insert(lines, color(C.accent, title) .. color(C.muted, "  " .. tostring(session.class) .. " L" .. tostring(session.levelStart)))
            table.insert(lines, color(C.muted, "  " .. ns:FormatNumber(session.xpGained or 0) .. " XP  |  " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatMoney(session.totalValueCopper or 0)))
        end
    end

    self:Section(lines, "Best XP/Hour")
    local best = ns.Grinding:GetBestSessions(6)
    if #best == 0 then
        table.insert(lines, color(C.muted, "No best-session comparisons yet."))
    else
        for index, session in ipairs(best) do
            local title = ns.Grinding:FormatSessionTitle(session)
            table.insert(lines, color(C.title, tostring(index) .. ". ") .. color(C.accent, title) .. color(C.muted, "  " .. tostring(session.class) .. " L" .. tostring(session.levelStart)))
            table.insert(lines, color(C.muted, "  " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatNumber(session.xpGained or 0) .. " XP  |  " .. ns:FormatMoney(session.totalValueCopper or 0)))
        end
    end

    return lines
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
        table.insert(lines, color(C.death, name) .. color(C.muted, "  Level ") .. color(C.white, tostring(record.level or "?") .. " " .. tostring(record.race or "") .. " " .. tostring(record.class or "")))
        table.insert(lines, color(C.muted, "  /played " .. played .. "  |  " .. formatDate(record.diedAt)))
        if record.zone then
            table.insert(lines, color(C.dim, "  Zone: " .. tostring(record.zone)))
        end
    end

    return lines
end

function UI:AddReminderGroup(lines, title, items)
    self:Section(lines, title)
    if #items == 0 then
        table.insert(lines, color(C.muted, "Nothing here right now."))
        return
    end

    for _, item in ipairs(items) do
        local tint = item.kind == "class" and C.class or C.profession
        table.insert(lines, color(tint, item.title))
        table.insert(lines, color(C.muted, "  " .. tostring(item.detail or "")))
        local meta = {}
        if item.where then
            table.insert(meta, "Where: " .. tostring(item.where))
        end
        if item.kind ~= "class" and item.cost then
            table.insert(meta, "Cost: " .. tostring(item.cost))
        end
        if #meta > 0 then
            table.insert(lines, color(C.dim, "  " .. table.concat(meta, "  |  ")))
        end
    end
end

function UI:BuildReminderLines()
    local lines = {}
    if not ns.Reminders then
        table.insert(lines, color(C.warning, "Reminder module is not loaded."))
        return lines
    end

    ns.Reminders:ScanSkills()
    local reminders = ns.Reminders:BuildList()
    self:AddReminderGroup(lines, "Due Now", reminders.due)
    self:AddReminderGroup(lines, "Upcoming", reminders.upcoming)
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
    elseif self.view == "fallen" then
        lines = self:BuildFallenLines()
    else
        lines = self:BuildOverviewLines()
    end

    self:SetLines(lines)
end
