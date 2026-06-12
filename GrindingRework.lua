local _, ns = ...

local Grinding = ns.Grinding
if not Grinding then
    return
end

local IDLE_TIMEOUT = 90

local originalOnInitialize = Grinding.OnInitialize or function() end
local originalOnPlayerLogin = Grinding.OnPlayerLogin or function() end
local originalStart = Grinding.Start or function() end
local originalStop = Grinding.Stop or function() end
local originalRecordXPGain = Grinding.RecordXPGain or function() end
local originalOnLootMessage = Grinding.OnLootMessage or function() end

function Grinding:GetVendorValue(session)
    session = session or self:GetActive()
    if not session then
        return 0
    end
    return tonumber(session.lootVendorCopper or session.vendorValueCopper or 0) or 0
end

function Grinding:MarkActivity(active, activityType)
    active = active or self:GetActive()
    if not active then
        return
    end

    active.lastActivityAt = ns:Now()
    active.lastActivityType = activityType or "activity"
    active.idleRemaining = IDLE_TIMEOUT
end

function Grinding:GetIdleRemaining(active)
    active = active or self:GetActive()
    if not active then
        return 0
    end

    local now = ns:Now()
    local lastActivity = tonumber(active.lastActivityAt or active.startedAt or now) or now
    return math.max(0, IDLE_TIMEOUT - (now - lastActivity))
end

function Grinding:EnsureIdleFrame()
    if self.idleFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        Grinding:OnIdleUpdate(elapsed)
    end)
    frame:Hide()
    self.idleFrame = frame
end

function Grinding:SetIdleWatcher(enabled)
    self:EnsureIdleFrame()
    if enabled then
        self.idleFrame:Show()
    else
        self.idleFrame:Hide()
        self.idleFrame.elapsed = 0
    end
end

function Grinding:RefreshActiveView()
    if ns.UI and ns.UI.frame and ns.UI.frame:IsShown() and ns.UI.view == "grind" then
        ns.UI:Refresh()
    end
    if ns.AutoGrindWindow and ns.AutoGrindWindow.IsShown and ns.AutoGrindWindow:IsShown() then
        ns.AutoGrindWindow:Update(self:GetActive())
    end
end

function Grinding:OnIdleUpdate(elapsed)
    local active = self:GetActive()
    if not active then
        self:SetIdleWatcher(false)
        return
    end

    local frame = self.idleFrame
    if not frame then
        return
    end

    frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
    if frame.elapsed < 1 then
        return
    end
    frame.elapsed = 0

    self:CheckIdleTimeout(active)
    if self:GetActive() then
        self:UpdateRates(active)
        self:RefreshActiveView()
    end
end

function Grinding:CheckIdleTimeout(active)
    active = active or self:GetActive()
    if not active then
        return
    end

    active.idleRemaining = self:GetIdleRemaining(active)
    if active.idleRemaining <= 0 then
        self:Stop("no XP or loot for 90 seconds")
    end
end

function Grinding:OnInitialize(...)
    originalOnInitialize(self, ...)
    ns:RegisterEvent("PLAYER_DEAD", self, "OnPlayerDead")
    self:EnsureIdleFrame()
end

function Grinding:OnPlayerLogin(...)
    originalOnPlayerLogin(self, ...)
    local active = self:GetActive()
    if active then
        self:MarkActivity(active, "login")
        self:SetIdleWatcher(true)
        if active.autoStarted and ns.AutoGrindWindow then
            ns.AutoGrindWindow:Show(active)
        end
    end
end

function Grinding:Start(name)
    local alreadyActive = self:GetActive()
    local suppressWindow = self.suppressNextStartWindow
    self.suppressNextStartWindow = nil

    originalStart(self, name)

    local active = self:GetActive()
    if not active then
        return
    end

    if active ~= alreadyActive then
        active.rawCopper = 0
        active.vendorValueCopper = self:GetVendorValue(active)
        active.totalValueCopper = active.vendorValueCopper
        self:MarkActivity(active, "start")
        self:SetIdleWatcher(true)
    end

    if suppressWindow then
        if ns.AutoGrindWindow then
            ns.AutoGrindWindow:Show(active)
        end
        return
    end

    if ns.ShowView then
        ns:ShowView("grind")
    elseif ns.UI then
        ns.UI:Show()
        ns.UI:SetView("grind")
    end
end

function Grinding:Stop(reason)
    local active = self:GetActive()
    if active and reason then
        ns:Print("Ending grind session automatically: " .. tostring(reason) .. ".")
    end

    originalStop(self)

    if not self:GetActive() then
        self:SetIdleWatcher(false)
        if ns.AutoGrindWindow then
            ns.AutoGrindWindow:Hide()
        end
    end
end

function Grinding:OnPlayerDead()
    if self:GetActive() then
        self:Stop("player died")
    end
end

function Grinding:UpdateRates(active)
    active = active or self:GetActive()
    if not active then
        return
    end

    local duration = math.max(1, ns:Now() - (active.startedAt or ns:Now()))
    local vendorValue = self:GetVendorValue(active)

    active.duration = duration
    active.xpPerHour = math.floor((active.xpGained or 0) * 3600 / duration)
    active.averageXPPerMob = active.mobCount and active.mobCount > 0 and math.floor((active.killXP or 0) / active.mobCount) or 0
    active.vendorValueCopper = vendorValue
    active.totalValueCopper = vendorValue
    active.rawCopper = 0
    active.idleRemaining = self:GetIdleRemaining(active)
end

function Grinding:RecordXPGain(amount, source, restedAmount, context)
    originalRecordXPGain(self, amount, source, restedAmount, context)

    local active = self:GetActive()
    if active and (tonumber(amount) or 0) > 0 then
        self:MarkActivity(active, "experience")
        self:UpdateRates(active)
        self:RefreshActiveView()
    end
end

function Grinding:OnLootMessage(event, message)
    local active = self:GetActive()
    local hasLoot = active and tostring(message or ""):match("|Hitem:") ~= nil

    originalOnLootMessage(self, event, message)

    active = self:GetActive()
    if active and hasLoot then
        self:MarkActivity(active, "loot")
        self:UpdateRates(active)
        self:RefreshActiveView()
    end
end

function Grinding:OnPlayerMoney()
    local currentMoney = GetMoney and GetMoney() or 0
    if not self.lastMoney then
        self.lastMoney = currentMoney
        return
    end

    local delta = currentMoney - self.lastMoney
    self.lastMoney = currentMoney

    local active = self:GetActive()
    if active and delta > 0 then
        self:MarkActivity(active, "coin loot")
        self:UpdateRates(active)
        self:RefreshActiveView()
    end
end

function Grinding:BuildStatusLines(active)
    active = active or self:GetActive()
    local lines = {}
    if not active then
        table.insert(lines, "No active grind session.")
        return lines
    end

    self:UpdateRates(active)
    local topMob = self:UpdateTopMob(active)
    table.insert(lines, "Active: " .. tostring(active.name))
    if topMob then
        table.insert(lines, "Top mob: " .. tostring(self:FormatPrimaryMob(topMob)))
    end
    table.insert(lines, "Duration: " .. ns:FormatDuration(active.duration or 0))
    table.insert(lines, "XP gained: " .. ns:FormatNumber(active.xpGained or 0))
    table.insert(lines, "XP/hour: " .. ns:FormatNumber(active.xpPerHour or 0))
    table.insert(lines, "Mob kills: " .. ns:FormatNumber(active.mobCount or 0))
    table.insert(lines, "Average XP/mob: " .. ns:FormatNumber(active.averageXPPerMob or 0))
    table.insert(lines, "Rested XP: " .. ns:FormatNumber(active.restedXP or 0))
    table.insert(lines, "Loot vendor value: " .. ns:FormatMoney(self:GetVendorValue(active)))
    table.insert(lines, "Idle auto-stop: " .. ns:FormatDuration(active.idleRemaining or self:GetIdleRemaining(active)))

    return lines
end

function Grinding:PrintBest()
    local sessions = self:GetBestSessions(5)
    if #sessions == 0 then
        ns:Print("No saved grind sessions to compare yet.")
        return
    end

    ns:Print("Best saved grind sessions by XP/hour:")
    for index, session in ipairs(sessions) do
        local classText = ns.ClassColorize and ns:ClassColorize(session.class, session.classFile) or tostring(session.class)
        ns:Print(index .. ". " .. self:FormatSessionTitle(session) .. " - " .. classText .. " level " .. tostring(session.levelStart) .. ": " .. ns:FormatNumber(session.xpPerHour or 0) .. " XP/hour, " .. ns:FormatNumber(session.xpGained or 0) .. " XP, " .. ns:FormatMoney(self:GetVendorValue(session)) .. " vendor value")
    end
end
