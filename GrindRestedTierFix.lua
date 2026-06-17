local _, ns = ...

local Grinding = ns.Grinding
local Dungeons = ns.Dungeons
local GrindTiers = ns.GrindTiers

local function safeDuration(session, kind)
    if not session then
        return 0
    end

    local duration = tonumber(session.duration) or 0
    if kind == "dungeon" and duration <= 0 then
        duration = tonumber(session.totalDuration) or 0
    end
    if duration <= 0 and session.startedAt and session.endedAt then
        duration = math.max(1, (session.endedAt or 0) - (session.startedAt or 0))
    end
    return math.max(0, duration)
end

local function markRestedExcluded(session)
    if session then
        session.restedExcludedFromXP = true
    end
end

if Grinding then
    local previousRecordXPGain = Grinding.RecordXPGain
    function Grinding:RecordXPGain(...)
        local result = previousRecordXPGain(self, ...)
        markRestedExcluded(self:GetActive())
        return result
    end
end

if Dungeons then
    local previousRecordXPGain = Dungeons.RecordXPGain
    function Dungeons:RecordXPGain(...)
        local result = previousRecordXPGain(self, ...)
        markRestedExcluded(self:GetActive())
        return result
    end
end

if GrindTiers then
    local previousAnalyzeSession = GrindTiers.AnalyzeSession
    function GrindTiers:AnalyzeSession(session, kind)
        local record = previousAnalyzeSession(self, session, kind)
        if not session or session.restedExcludedFromXP then
            return record
        end

        local rested = tonumber(session.restedXP) or 0
        if rested <= 0 then
            return record
        end

        local adjustedXP = math.max(0, (tonumber(session.xpGained) or 0) - rested)
        local duration = safeDuration(session, kind)
        local xpRequired = tonumber(record and record.xpRequired) or 1
        local xpPerHour = duration > 0 and math.floor(adjustedXP * 3600 / duration) or 0

        record.xpPerHour = xpPerHour
        record.xpLevelRate = xpPerHour / xpRequired
        record.xpLevelPercentPerHour = record.xpLevelRate * 100
        return record
    end
end
