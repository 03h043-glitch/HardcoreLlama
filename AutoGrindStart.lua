local _, ns = ...

local Grinding = ns.Grinding
if not Grinding then
    return
end

local WINDOW_SECONDS = 180
local REQUIRED_KILLS = 3

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
    self:Start(autoGrindName(mobName))

    local active = self:GetActive()
    if not active then
        return false
    end

    active.autoStarted = true
    active.autoStartMob = mobName
    active.autoStartKillCount = #replay
    active.autoStartWindowSeconds = WINDOW_SECONDS
    active.startedAt = replay[1] and replay[1].time or active.startedAt

    for _, kill in ipairs(replay) do
        previousRecordXPGain(self, kill.amount, kill.source, kill.rested, kill.context)
    end

    if self.UpdateRates then
        self:UpdateRates(active)
    end
    if self.RefreshActiveView then
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

    return previousRecordXPGain(self, amount, source, restedAmount, context)
end
