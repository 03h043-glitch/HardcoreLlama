local _, ns = ...

local Grinding = ns.Grinding
local Dungeons = ns.Dungeons
local UI = ns.UI
local AutoGrindWindow = ns.AutoGrindWindow

local C = {
    title = "|cffffd100",
    accent = "|cff33ff99",
    xp = "|cff69ccf0",
    value = "|cffffd100",
    combined = "|cffd6a9ff",
    danger = "|cffff5a5a",
    white = "|cffffffff",
    muted = "|cff9d9d9d",
    dim = "|cff666666",
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

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function divider(char, width)
    return string.rep(char or "-", width or 38)
end

local function classText(className, classFile)
    if ns.ClassColorize then
        return ns:ClassColorize(className, classFile)
    end
    return tostring(className or classFile or "Unknown")
end

local function removeValue(list, value)
    if not list then
        return false
    end

    local removed = false
    for index = #list, 1, -1 do
        if list[index] == value then
            table.remove(list, index)
            removed = true
        end
    end
    return removed
end

local function refreshTierData()
    if ns.GrindTiers and ns.GrindTiers.RefreshAllTiers then
        ns.GrindTiers:RefreshAllTiers()
    end
    ns:MaybeRefreshUI()
end

local function effectiveXP(amount, restedAmount)
    amount = math.floor(tonumber(amount) or 0)
    restedAmount = math.max(0, math.floor(tonumber(restedAmount) or 0))
    restedAmount = math.min(restedAmount, amount)
    return math.max(0, amount - restedAmount), restedAmount
end

local function hiddenStopReason(reason)
    local text = string.lower(tostring(reason or ""))
    return text:find("90 seconds", 1, true) ~= nil or text:find("for 3 minutes", 1, true) ~= nil
end

local function parseLootMessage(message)
    message = tostring(message or "")
    local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then
        return nil
    end

    local quantity = tonumber(message:match("x(%d+)")) or 1
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    local name = itemLink:match("%[(.-)%]") or itemLink
    local sellPrice = 0
    if type(GetItemInfo) == "function" then
        sellPrice = tonumber(select(11, GetItemInfo(itemLink))) or 0
    end

    return {
        id = itemID,
        key = itemID and ("item:" .. tostring(itemID)) or name,
        link = itemLink,
        name = name,
        quantity = quantity,
        vendorCopper = sellPrice * quantity,
    }
end

local function recordLootItem(session, loot)
    if not session or not loot then
        return
    end

    session.lootItems = session.lootItems or {}
    local item = session.lootItems[loot.key]
    if not item then
        item = {
            id = loot.id,
            key = loot.key,
            name = loot.name,
            link = loot.link,
            count = 0,
            vendorCopper = 0,
        }
        session.lootItems[loot.key] = item
    end

    item.name = loot.name or item.name
    item.link = loot.link or item.link
    item.count = (item.count or 0) + (loot.quantity or 1)
    item.vendorCopper = (item.vendorCopper or 0) + (loot.vendorCopper or 0)
end

local function ratePerHour(value, duration)
    duration = math.max(1, tonumber(duration) or 0)
    return math.floor((tonumber(value) or 0) * 3600 / duration)
end

local function vendorValue(session)
    if Grinding and Grinding.GetVendorValue then
        return Grinding:GetVendorValue(session)
    end
    return tonumber(session and (session.lootVendorCopper or session.vendorValueCopper) or 0) or 0
end

local function makeButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 72, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

if Grinding then
    function Grinding:GetTopLootItems(session, limit)
        local items = {}
        for _, item in pairs((session and session.lootItems) or {}) do
            table.insert(items, item)
        end

        table.sort(items, function(left, right)
            if (left.count or 0) == (right.count or 0) then
                if (left.vendorCopper or 0) == (right.vendorCopper or 0) then
                    return tostring(left.name or "") < tostring(right.name or "")
                end
                return (left.vendorCopper or 0) > (right.vendorCopper or 0)
            end
            return (left.count or 0) > (right.count or 0)
        end)

        limit = limit or #items
        while #items > limit do
            table.remove(items)
        end
        return items
    end

    function Grinding:RemoveSession(sessionId)
        local db = ns.Database and ns.Database:GetDB()
        sessionId = tostring(sessionId or "")
        if not db or sessionId == "" or not db.grindSessions or not db.grindSessions[sessionId] then
            ns:Print("No saved grind session found for removal.")
            return false
        end

        local session = db.grindSessions[sessionId]
        db.grindSessions[sessionId] = nil
        removeValue(db.grindSessionOrder, sessionId)

        for _, character in pairs(db.characters or {}) do
            removeValue(character.grindSessionIds, sessionId)
        end

        refreshTierData()
        ns:Print("Removed grind session: " .. self:FormatSessionTitle(session))
        return true
    end

    function Grinding:ResolveSessionId(identifier)
        local db = ns.Database and ns.Database:GetDB()
        if not db then
            return nil
        end

        identifier = ns.Trim(identifier)
        if identifier == "" then
            identifier = "1"
        end
        if db.grindSessions and db.grindSessions[identifier] then
            return identifier
        end

        local index = tonumber(identifier)
        if index and db.grindSessionOrder then
            return db.grindSessionOrder[index]
        end
        return nil
    end

    function Grinding:RemoveSessionByReference(identifier)
        local sessionId = self:ResolveSessionId(identifier)
        if not sessionId then
            ns:Print("Could not find that saved grind. Use a recent-session number or session id.")
            return false
        end
        return self:RemoveSession(sessionId)
    end

    local previousGrindingRecordXPGain = Grinding.RecordXPGain
    function Grinding:RecordXPGain(amount, source, restedAmount, context)
        local effectiveAmount, rested = effectiveXP(amount, restedAmount)
        return previousGrindingRecordXPGain(self, effectiveAmount, source, rested, context)
    end

    local previousGrindingLoot = Grinding.OnLootMessage
    function Grinding:OnLootMessage(event, message)
        local active = self:GetActive()
        local loot = parseLootMessage(message)
        local result = previousGrindingLoot(self, event, message)
        active = self:GetActive() or active
        if active and loot then
            recordLootItem(active, loot)
            self:UpdateRates(active)
            self:RefreshActiveView()
        end
        return result
    end

    local previousGrindingStop = Grinding.Stop
    function Grinding:Stop(reason)
        if hiddenStopReason(reason) then
            return previousGrindingStop(self, nil)
        end
        return previousGrindingStop(self, reason)
    end

    function Grinding:BuildStatusLines(active)
        active = active or self:GetActive()
        local lines = {}
        if not active then
            table.insert(lines, "No active grind session.")
            return lines
        end

        self:UpdateRates(active)
        local duration = math.max(1, tonumber(active.duration) or 0)
        table.insert(lines, "Active: " .. tostring(active.name))
        table.insert(lines, "Duration: " .. ns:FormatDuration(active.duration or 0))
        table.insert(lines, "XP: " .. ns:FormatNumber(active.xpGained or 0) .. " | " .. ns:FormatNumber(active.xpPerHour or 0) .. "/hour")
        table.insert(lines, "Kill XP: " .. ns:FormatNumber(active.killXP or 0) .. " | " .. ns:FormatNumber(ratePerHour(active.killXP or 0, duration)) .. "/hour")
        table.insert(lines, "Mob kills: " .. ns:FormatNumber(active.mobCount or 0) .. " | " .. ns:FormatNumber(ratePerHour(active.mobCount or 0, duration)) .. "/hour")
        table.insert(lines, "Average XP/mob: " .. ns:FormatNumber(active.averageXPPerMob or 0))
        table.insert(lines, "Vendor value: " .. ns:FormatMoney(vendorValue(active)) .. " | " .. ns:FormatMoney(ratePerHour(vendorValue(active), duration)) .. "/hour")

        local topMob = self:UpdateTopMob(active)
        if topMob then
            table.insert(lines, "Top mob: " .. tostring(self:FormatPrimaryMob(topMob)))
        end

        local loot = self:GetTopLootItems(active, 3)
        for index, item in ipairs(loot) do
            table.insert(lines, "Loot #" .. tostring(index) .. ": " .. tostring(item.link or item.name or "Item") .. " x" .. ns:FormatNumber(item.count or 0))
        end
        return lines
    end
end

if Dungeons then
    function Dungeons:RemoveRun(runId)
        local db = ns.Database and ns.Database:GetDB()
        runId = tostring(runId or "")
        if not db or runId == "" or not db.dungeonRuns or not db.dungeonRuns[runId] then
            ns:Print("No saved dungeon run found for removal.")
            return false
        end

        local run = db.dungeonRuns[runId]
        db.dungeonRuns[runId] = nil
        removeValue(db.dungeonRunOrder, runId)

        for _, character in pairs(db.characters or {}) do
            removeValue(character.dungeonRunIds, runId)
        end

        refreshTierData()
        ns:Print("Removed dungeon run: " .. tostring(run.name or "Dungeon"))
        return true
    end

    function Dungeons:ResolveRunId(identifier)
        local db = ns.Database and ns.Database:GetDB()
        if not db then
            return nil
        end

        identifier = ns.Trim(identifier)
        if identifier == "" then
            identifier = "1"
        end
        if db.dungeonRuns and db.dungeonRuns[identifier] then
            return identifier
        end

        local index = tonumber(identifier)
        if index and db.dungeonRunOrder then
            return db.dungeonRunOrder[index]
        end
        return nil
    end

    function Dungeons:RemoveRunByReference(identifier)
        local runId = self:ResolveRunId(identifier)
        if not runId then
            ns:Print("Could not find that saved dungeon run. Use a recent-run number or run id.")
            return false
        end
        return self:RemoveRun(runId)
    end

    local previousDungeonRecordXPGain = Dungeons.RecordXPGain
    function Dungeons:RecordXPGain(amount, source, restedAmount, context)
        local effectiveAmount, rested = effectiveXP(amount, restedAmount)
        return previousDungeonRecordXPGain(self, effectiveAmount, source, rested, context)
    end

    local previousDungeonLoot = Dungeons.OnLootMessage
    function Dungeons:OnLootMessage(event, message)
        local active = self:GetActive()
        local loot = parseLootMessage(message)
        local result = previousDungeonLoot(self, event, message)
        active = self:GetActive() or active
        if active and loot then
            recordLootItem(active, loot)
        end
        return result
    end
end

if ns.HandleSlash then
    local previousHandleSlash = ns.HandleSlash
    function ns:HandleSlash(input)
        input = ns.Trim(input)
        local command, rest = input:match("^(%S+)%s*(.-)$")
        command = string.lower(command or "")
        rest = ns.Trim(rest)

        if command == "grind" then
            local subCommand, subRest = rest:match("^(%S+)%s*(.-)$")
            subCommand = string.lower(subCommand or "")
            subRest = ns.Trim(subRest)
            if (subCommand == "remove" or subCommand == "delete") and Grinding then
                Grinding:RemoveSessionByReference(subRest)
                return
            end
        elseif command == "dungeon" or command == "dungeons" or command == "instances" then
            local subCommand, subRest = rest:match("^(%S+)%s*(.-)$")
            subCommand = string.lower(subCommand or "")
            subRest = ns.Trim(subRest)
            if (subCommand == "remove" or subCommand == "delete") and Dungeons then
                Dungeons:RemoveRunByReference(subRest)
                return
            end
        end

        return previousHandleSlash(self, input)
    end
end

if ns.PrintHelp then
    local previousPrintHelp = ns.PrintHelp
    function ns:PrintHelp()
        previousPrintHelp(self)
        self:Print("/hcl grind remove [recent # or id] - remove a saved grind and recalculate tiers")
        self:Print("/hcl dungeon remove [recent # or id] - remove a saved dungeon run and recalculate tiers")
    end
end

if UI then
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
                button:RegisterForClicks("LeftButtonUp")
                button:SetScript("OnEnter", function(owner)
                    ns.UI:ShowTooltip(owner.tooltipRow)
                end)
                button:SetScript("OnLeave", function()
                    if GameTooltip then
                        GameTooltip:Hide()
                    end
                end)
                button:SetScript("OnClick", function(owner, mouseButton)
                    local tooltipRow = owner.tooltipRow
                    if tooltipRow and tooltipRow.onClick then
                        tooltipRow.onClick(tooltipRow, mouseButton)
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

    function UI:SelectGrindForRemoval(kind, id, title)
        if not id then
            return
        end
        self.grindRemovalSelection = { kind = kind or "world", id = id, title = title or id }
        self:Refresh()
    end

    function UI:ClearInvalidRemovalSelection()
        local selected = self.grindRemovalSelection
        if not selected then
            return
        end

        local db = ns.Database and ns.Database:GetDB()
        local exists = db and ((selected.kind == "dungeon" and db.dungeonRuns and db.dungeonRuns[selected.id]) or (selected.kind ~= "dungeon" and db.grindSessions and db.grindSessions[selected.id]))
        if not exists then
            self.grindRemovalSelection = nil
        end
    end

    function UI:RemoveSelectedGrind()
        local selected = self.grindRemovalSelection
        if not selected then
            return
        end

        local removed = false
        if selected.kind == "dungeon" and Dungeons then
            removed = Dungeons:RemoveRun(selected.id)
        elseif Grinding then
            removed = Grinding:RemoveSession(selected.id)
        end

        if removed then
            self.grindRemovalSelection = nil
            self:Refresh()
        end
    end

    local previousBuildFrame = UI.BuildFrame
    function UI:BuildFrame()
        local frame = previousBuildFrame(self)
        if frame.removeGrindButton then
            return frame
        end

        local anchor = frame.grindTierTabs and frame.grindTierTabs[#frame.grindTierTabs] or frame.startButton
        frame.removeGrindButton = makeButton(frame, "Remove", 68, function()
            ns.UI:RemoveSelectedGrind()
        end)
        frame.removeGrindButton:SetPoint("LEFT", anchor, "RIGHT", 4, 0)
        frame.removeGrindButton:Hide()
        return frame
    end

    function UI:UpdateGrindRemovalControls()
        local frame = self.frame
        if not frame or not frame.removeGrindButton then
            return
        end

        self:ClearInvalidRemovalSelection()
        local active = Grinding and Grinding:GetActive()
        local show = self.view == "grind" and not active
        local selected = self.grindRemovalSelection ~= nil
        if show then
            frame.removeGrindButton:Show()
            if frame.removeGrindButton.SetEnabled then
                frame.removeGrindButton:SetEnabled(selected)
            elseif selected then
                frame.removeGrindButton:Enable()
            else
                frame.removeGrindButton:Disable()
            end
        else
            frame.removeGrindButton:Hide()
        end
    end

    local function tierTooltip(record, metric)
        local lines = {
            "Click to select this run for removal.",
            "Kind: " .. (record.kind == "dungeon" and "Dungeon" or "Open World"),
            "Level: " .. tostring(record.grindLevel or "?"),
        }
        if metric == "xp" then
            table.insert(lines, string.format("XP rate: %.1f%% level/hour", record.xpLevelPercentPerHour or 0))
            table.insert(lines, "Raw XP/hour: " .. ns:FormatNumber(record.xpPerHour or 0))
        elseif metric == "value" then
            table.insert(lines, "Vendor/hour: " .. ns:FormatMoney(record.vendorPerHour or 0))
        else
            table.insert(lines, "Combined score: " .. string.format("%.0f", (record.combinedScore or 0) * 100))
        end
        return lines
    end

    function UI:AddTierMetric(lines, hoverRows, title, records, tierField, rankField, metric)
        table.insert(lines, "")
        table.insert(lines, color(METRIC_COLORS[metric] or C.title, "== " .. tostring(title) .. " =="))
        table.insert(lines, color(C.dim, divider("-", 42)))

        if #records == 0 then
            table.insert(lines, color(C.muted, "No sessions recorded yet."))
            return
        end

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
                    local lineIndex = #lines + 1
                    local headline, detail = self:TierRecordLine(record, rankField, metric, tierField)
                    table.insert(lines, headline)
                    table.insert(lines, detail)
                    table.insert(hoverRows, {
                        line = lineIndex,
                        title = tostring(record.title or "Session"),
                        lines = tierTooltip(record, metric),
                        kind = record.kind,
                        sessionId = record.id,
                        onClick = function(row)
                            ns.UI:SelectGrindForRemoval(row.kind, row.sessionId, row.title)
                        end,
                    })
                end
            end
        end

        if not shownAny then
            table.insert(lines, color(C.muted, "No scored sessions in this category."))
        end
    end

    function UI:BuildGrindTierLines()
        local lines = {}
        local hoverRows = {}
        if not ns.GrindTiers then
            table.insert(lines, color(C.danger, "Grind tier module is not loaded."))
            return lines, hoverRows
        end

        self:ClearInvalidRemovalSelection()
        local scope = self:GetGrindTierScope()
        local scopeLabel = ns.GrindTiers:GetScopeLabel(scope)
        local records = ns.GrindTiers:RankRecords(scope)

        table.insert(lines, color(C.title, "TIER LIST: " .. string.upper(scopeLabel)))
        table.insert(lines, color(C.dim, divider("=", 44)))
        table.insert(lines, color(C.muted, "XP and vendor value are scaled by XP needed at the highest mob level recorded in each run."))
        table.insert(lines, color(C.dim, "Combined score normalizes XP and vendor value within this tab, then averages them."))

        if self.grindRemovalSelection then
            table.insert(lines, color(C.danger, "Selected for removal: ") .. color(C.white, self.grindRemovalSelection.title or self.grindRemovalSelection.id))
        else
            table.insert(lines, color(C.dim, "Select a listed run, then press Remove to delete skewed data."))
        end

        self:AddTierMetric(lines, hoverRows, "XP / Hour", records, "xpTier", "xpRank", "xp")
        self:AddTierMetric(lines, hoverRows, "Vendor Value / Hour", records, "valueTier", "valueRank", "value")
        self:AddTierMetric(lines, hoverRows, "Combined Score", records, "combinedTier", "combinedRank", "combined")
        return lines, hoverRows
    end

    function UI:MetricPairLine(label, absoluteValue, hourlyValue, valueColor)
        return color(C.muted, string.format("%-13s", tostring(label))) .. color(valueColor or C.white, tostring(absoluteValue)) .. color(C.dim, "  |  ") .. color(C.accent, tostring(hourlyValue) .. "/hour")
    end

    function UI:AddTopLootLines(lines, active)
        self:Section(lines, "Top Loot")
        local items = Grinding and Grinding:GetTopLootItems(active, 3) or {}
        if #items == 0 then
            table.insert(lines, color(C.muted, "No looted items recorded yet."))
            return
        end

        for index, item in ipairs(items) do
            table.insert(lines, color(C.title, tostring(index) .. ". ") .. color(C.white, tostring(item.link or item.name or "Item")) .. color(C.muted, "  x" .. ns:FormatNumber(item.count or 0)))
        end
    end

    function UI:BuildActiveGrindLines(active)
        local lines = {}
        if not Grinding then
            table.insert(lines, color(C.danger, "Grinding module is not loaded."))
            return lines
        end

        Grinding:UpdateRates(active)
        local duration = math.max(1, tonumber(active.duration) or 0)
        local topMob = Grinding:UpdateTopMob(active)
        local totalVendor = vendorValue(active)

        self:Section(lines, "Active Grind")
        table.insert(lines, color(C.accent, tostring(active.name or "Grinding Session")) .. color(C.muted, "  ") .. classText(active.class, active.classFile) .. color(C.muted, " L" .. tostring(active.levelStart or "?")))
        if active.zoneStart then
            table.insert(lines, color(C.dim, "Zone: " .. tostring(active.zoneStart)))
        end
        if topMob then
            table.insert(lines, color(C.dim, "Most common mob: " .. tostring(Grinding:FormatPrimaryMob(topMob))))
        end

        self:Section(lines, "Live Metrics")
        table.insert(lines, self:MetricPairLine("XP", ns:FormatNumber(active.xpGained or 0), ns:FormatNumber(active.xpPerHour or 0), C.xp))
        table.insert(lines, self:MetricPairLine("Kill XP", ns:FormatNumber(active.killXP or 0), ns:FormatNumber(ratePerHour(active.killXP or 0, duration)), C.xp))
        table.insert(lines, self:MetricPairLine("Mob kills", ns:FormatNumber(active.mobCount or 0), ns:FormatNumber(ratePerHour(active.mobCount or 0, duration)), C.title))
        table.insert(lines, self:MetricPairLine("Vendor", ns:FormatMoney(totalVendor), ns:FormatMoney(ratePerHour(totalVendor, duration)), C.value))
        table.insert(lines, color(C.muted, string.format("%-13s", "Avg XP/mob")) .. color(C.white, ns:FormatNumber(active.averageXPPerMob or 0)))
        table.insert(lines, color(C.muted, string.format("%-13s", "Duration")) .. color(C.white, ns:FormatDuration(active.duration or 0)))

        self:AddTopLootLines(lines, active)
        self:AddActiveGrindSources(lines, active)
        return lines
    end

    local previousRefresh = UI.Refresh
    function UI:Refresh()
        if self.frame and self.view == "grind" and Grinding and not Grinding:GetActive() and ns.GrindTiers then
            local lines, hoverRows = self:BuildGrindTierLines()
            self:SetLines(lines, hoverRows)
            if self.UpdateGrindControls then
                self:UpdateGrindControls()
            end
            if self.UpdateGrindTierControls then
                self:UpdateGrindTierControls()
            end
            self:UpdateGrindRemovalControls()
            return
        end

        previousRefresh(self)
        self:UpdateGrindRemovalControls()
    end
end

if AutoGrindWindow then
    local function makeAutoFont(parent, template)
        local font = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
        font:SetJustifyH("LEFT")
        font:SetJustifyV("TOP")
        return font
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

    local previousAutoBuildFrame = AutoGrindWindow.BuildFrame
    function AutoGrindWindow:BuildFrame()
        local frame = previousAutoBuildFrame(self)
        if not frame.managementAdjusted then
            if frame.SetResizeBounds then
                frame:SetResizeBounds(280, 230, 500, 360)
            else
                frame:SetMinResize(280, 230)
                frame:SetMaxResize(500, 360)
            end
            if (frame:GetHeight() or 0) < 230 then
                frame:SetHeight(230)
            end

            frame.lootTitle = makeAutoFont(frame, "GameFontNormalSmall")
            frame.lootRows = {}
            for index = 1, 3 do
                frame.lootRows[index] = makeAutoFont(frame, "GameFontHighlightSmall")
            end
            frame.managementAdjusted = true
        end
        return frame
    end

    function AutoGrindWindow:UpdateLayout()
        local frame = self.frame
        if not frame then
            return
        end

        local width = frame:GetWidth() or 300
        local contentWidth = math.max(240, width - 28)
        local columnWidth = math.floor((contentWidth - 12) / 2)

        for index, metric in ipairs(frame.metrics or {}) do
            local column = (index - 1) % 2
            local row = math.floor((index - 1) / 2)
            local x = 14 + column * (columnWidth + 12)
            local y = -58 - row * 28

            metric.label:ClearAllPoints()
            metric.value:ClearAllPoints()
            metric.label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
            metric.label:SetWidth(columnWidth)
            metric.value:SetPoint("TOPLEFT", metric.label, "BOTTOMLEFT", 0, -1)
            metric.value:SetWidth(columnWidth)
        end

        setVisible(frame.targetLabel, false)
        setVisible(frame.targetBg, false)
        setVisible(frame.targetFill, false)

        if frame.lootTitle then
            frame.lootTitle:ClearAllPoints()
            frame.lootTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -145)
            frame.lootTitle:SetWidth(contentWidth)
        end
        for index, row in ipairs(frame.lootRows or {}) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -160 - ((index - 1) * 15))
            row:SetWidth(contentWidth)
        end

        frame.stopButton:ClearAllPoints()
        frame.stopButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 10)
    end

    function AutoGrindWindow:UpdateLootRows(active)
        local frame = self.frame
        if not frame or not frame.lootRows then
            return
        end

        local items = Grinding and Grinding:GetTopLootItems(active, 3) or {}
        frame.lootTitle:SetText(color(C.title, "TOP LOOT"))
        for index = 1, 3 do
            local item = items[index]
            if item then
                frame.lootRows[index]:SetText(color(C.white, tostring(item.link or item.name or "Item")) .. color(C.muted, " x" .. ns:FormatNumber(item.count or 0)))
            else
                frame.lootRows[index]:SetText(color(C.dim, "-"))
            end
        end
    end

    function AutoGrindWindow:Update(active)
        local frame = self:BuildFrame()
        active = active or (Grinding and Grinding:GetActive())
        if not active then
            frame:Hide()
            return
        end

        if Grinding and Grinding.UpdateRates then
            Grinding:UpdateRates(active)
        end

        local duration = math.max(1, tonumber(active.duration) or 0)
        local topMob = Grinding and Grinding.UpdateTopMob and Grinding:UpdateTopMob(active)
        local title = tostring(active.name or "Grinding Session")
        local classLine = classText(active.class, active.classFile) .. color(C.muted, " L" .. tostring(active.levelStart or "?"))
        local mobLine = topMob and ("  " .. tostring(Grinding:FormatPrimaryMob(topMob))) or ""
        local totalVendor = vendorValue(active)

        frame.subtitle:SetText(color(C.white, title) .. color(C.muted, "  ") .. classLine .. color(C.dim, mobLine))
        self:SetMetric(1, "XP", ns:FormatNumber(active.xpGained or 0) .. " | " .. ns:FormatNumber(active.xpPerHour or 0) .. "/hr", C.xp)
        self:SetMetric(2, "Kill XP", ns:FormatNumber(active.killXP or 0) .. " | " .. ns:FormatNumber(ratePerHour(active.killXP or 0, duration)) .. "/hr", C.xp)
        self:SetMetric(3, "Kills", ns:FormatNumber(active.mobCount or 0) .. " | " .. ns:FormatNumber(ratePerHour(active.mobCount or 0, duration)) .. "/hr", C.title)
        self:SetMetric(4, "Vendor", ns:FormatMoney(totalVendor) .. " | " .. ns:FormatMoney(ratePerHour(totalVendor, duration)) .. "/hr", C.value)
        self:SetMetric(5, "Avg/mob", ns:FormatNumber(active.averageXPPerMob or 0), C.combined)
        self:SetMetric(6, "Duration", ns:FormatDuration(active.duration or 0), C.white)
        self:UpdateLootRows(active)
        self:UpdateLayout()
    end
end
