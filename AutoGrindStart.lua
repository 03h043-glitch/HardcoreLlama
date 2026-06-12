local _, ns = ...

local Grinding = ns.Grinding
if not Grinding then
    return
end

local WINDOW_SECONDS = 180
local REQUIRED_KILLS = 3
local TARGET_TIMEOUT_SECONDS = 180

local previousOnInitialize = Grinding.OnInitialize or function() end
local previousStart = Grinding.Start or function() end
local previousRecordXPGain = Grinding.RecordXPGain or function() end

local function normalizedSource(source)
    if ns.Database and ns.Database.NormalizeSource then
        return ns.Database:NormalizeSource(source)
    end
    return string.upper(tostring(source or "OTHER"))
end

local function copyContext(context)
    local copy = {}
    for key, value in pairs(context or {}) do
        copy[key] = value
    end
    return copy
end

local function normalizeMobName(name)
    return string.lower(ns.Trim(name))
end

local function autoGrindName(mobName)
    local zone = ns.Trim((GetZoneText and GetZoneText()) or "")
    if zone ~= "" then
        return zone
    end
    return tostring(mobName or "Auto Grind") .. " Grind"
end

function Grinding:ClearAutoStartKills()
    self.autoStartKills = {}
end

function Grinding:IsDungeonTrackingActive()
    return ns.Dungeons and ns.Dungeons.GetActive and ns.Dungeons:GetActive() ~= nil
end

function Grinding:PruneAutoStartKills(now)
    self.autoStartKills = self.autoStartKills or {}
    for mobName, kills in pairs(self.autoStartKills) do
        for index = #kills, 1, -1 do
            if now - (kills[index].time or 0) > WINDOW_SECONDS then
                table.remove(kills, index)
            end
        end
        if #kills == 0 then
            self.autoStartKills[mobName] = nil
        end
    end
end

function Grinding:RememberAutoStartKill(amount, source, restedAmount, context)
    local mobName = ns.Trim(context and context.mobName)
    if mobName == "" then
        return nil
    end

    local now = ns:Now()
    self:PruneAutoStartKills(now)
    self.autoStartKills = self.autoStartKills or {}
    local kills = self.autoStartKills[mobName] or {}
    self.autoStartKills[mobName] = kills

    table.insert(kills, {
        time = now,
        amount = math.floor(tonumber(amount) or 0),
        source = source,
        rested = math.floor(tonumber(restedAmount) or 0),
        context = copyContext(context),
    })

    return kills, mobName
end

function Grinding:GetAutoStartTargetRemaining(active)
    active = active or self:GetActive()
    if not active or not active.autoStarted or ns.Trim(active.autoStartMob) == "" then
        return 0
    end

    local now = ns:Now()
    local lastKill = tonumber(active.lastAutoStartMobKillAt or active.startedAt or now) or now
    return math.max(0, TARGET_TIMEOUT_SECONDS - (now - lastKill))
end

function Grinding:MarkAutoStartMobKill(active, mobName, timestamp)
    active = active or self:GetActive()
    if not active or not active.autoStarted or ns.Trim(active.autoStartMob) == "" then
        return false
    end

    if normalizeMobName(mobName) ~= normalizeMobName(active.autoStartMob) then
        return false
    end

    active.lastAutoStartMobKillAt = timestamp or ns:Now()
    active.autoStartTargetTimeout = TARGET_TIMEOUT_SECONDS
    active.autoStartTargetRemaining = TARGET_TIMEOUT_SECONDS
    return true
end

function Grinding:EnsureAutoStartWatcher()
    if self.autoStartFrame then
        return
    end

    local frame = CreateFrame("Frame")
    frame.elapsed = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        Grinding:OnAutoStartUpdate(elapsed)
    end)
    frame:Show()
    self.autoStartFrame = frame
end

function Grinding:OnAutoStartUpdate(elapsed)
    local frame = self.autoStartFrame
    if not frame then
        return
    end

    frame.elapsed = (frame.elapsed or 0) + (elapsed or 0)
    if frame.elapsed < 1 then
        return
    end
    frame.elapsed = 0

    local active = self:GetActive()
    if not active then
        if ns.AutoGrindWindow then
            ns.AutoGrindWindow:Hide()
        end
        return
    end

    if active.autoStarted and ns.Trim(active.autoStartMob) ~= "" then
        active.autoStartTargetRemaining = self:GetAutoStartTargetRemaining(active)
        if active.autoStartTargetRemaining <= 0 then
            self:Stop("no " .. tostring(active.autoStartMob) .. " kills for 3 minutes")
            return
        end
    end

    if active.autoStarted and ns.AutoGrindWindow and ns.AutoGrindWindow.IsShown and ns.AutoGrindWindow:IsShown() then
        ns.AutoGrindWindow:Update(active)
    end
end

function Grinding:OnInitialize(...)
    previousOnInitialize(self, ...)
    self:EnsureAutoStartWatcher()
end

function Grinding:TryAutoStartFromKill(amount, source, restedAmount, context)
    if self:GetActive() or self:IsDungeonTrackingActive() then
        return false
    end

    if normalizedSource(source) ~= "KILL" or (tonumber(amount) or 0) <= 0 then
        return false
    end

    local kills, mobName = self:RememberAutoStartKill(amount, source, restedAmount, context)
    if not kills or #kills < REQUIRED_KILLS then
        return false
    end

    local replay = {}
    for index = math.max(1, #kills - REQUIRED_KILLS + 1), #kills do
        table.insert(replay, kills[index])
    end

    self:ClearAutoStartKills()
    self.suppressNextStartWindow = true
    self:Start(autoGrindName(mobName))

    local active = self:GetActive()
    if not active then
        self.suppressNextStartWindow = nil
        return false
    end

    active.autoStarted = true
    active.autoStartMob = mobName
    active.autoStartKillCount = #replay
    active.autoStartWindowSeconds = WINDOW_SECONDS
    active.autoStartTargetTimeout = TARGET_TIMEOUT_SECONDS
    active.startedAt = replay[1] and replay[1].time or active.startedAt

    for _, kill in ipairs(replay) do
        previousRecordXPGain(self, kill.amount, kill.source, kill.rested, kill.context)
    end

    local lastReplay = replay[#replay]
    self:MarkAutoStartMobKill(active, mobName, lastReplay and lastReplay.time or ns:Now())

    if self.UpdateRates then
        self:UpdateRates(active)
    end
    if ns.AutoGrindWindow then
        ns.AutoGrindWindow:Show(active)
    elseif self.RefreshActiveView then
        self:RefreshActiveView()
    end

    ns:Print("Auto-started grind after " .. tostring(REQUIRED_KILLS) .. " " .. tostring(mobName) .. " kills in 3 minutes.")
    return true
end

function Grinding:Start(...)
    self:ClearAutoStartKills()
    return previousStart(self, ...)
end

function Grinding:RecordXPGain(amount, source, restedAmount, context)
    if self:TryAutoStartFromKill(amount, source, restedAmount, context) then
        return
    end

    local result = previousRecordXPGain(self, amount, source, restedAmount, context)
    local active = self:GetActive()
    if active and active.autoStarted and normalizedSource(source) == "KILL" and (tonumber(amount) or 0) > 0 then
        self:MarkAutoStartMobKill(active, context and context.mobName, ns:Now())
    end
    return result
end
