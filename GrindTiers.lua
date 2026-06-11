local _, ns = ...

local GrindTiers = ns:RegisterModule("GrindTiers", {})
ns.GrindTiers = GrindTiers

local TIER_ORDER = { "S", "A", "B", "C", "D" }
local SCOPE_LABELS = {
    world = "Open World",
    dungeon = "Dungeon",
    combined = "Combined",
}

local function clampLevel(level)
    level = math.floor(tonumber(level) or 1)
    return math.max(1, math.min(59, level))
end

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

local function tierFor(score, bestScore)
    score = tonumber(score) or 0
    bestScore = tonumber(bestScore) or 0
    if score <= 0 or bestScore <= 0 then
        return "D"
    end

    local ratio = score / bestScore
    if ratio >= 0.90 then
        return "S"
    elseif ratio >= 0.75 then
        return "A"
    elseif ratio >= 0.55 then
        return "B"
    elseif ratio >= 0.35 then
        return "C"
    end
    return "D"
end

function GrindTiers:GetVendorValue(session)
    if not session then
        return 0
    end
    return tonumber(session.lootVendorCopper or session.vendorValueCopper or 0) or 0
end

function GrindTiers:GetHighestMobLevel(session)
    local highest

    local function remember(level)
        level = tonumber(level)
        if level and level > 0 then
            highest = highest and math.max(highest, level) or level
        end
    end

    for _, mob in pairs((session and session.mobKills) or {}) do
        remember(mob.maxLevel)
        remember(mob.minLevel)
    end

    if session and session.primaryMob then
        remember(session.primaryMob.maxLevel)
        remember(session.primaryMob.minLevel)
    end

    remember(session and session.levelStart)
    return clampLevel(highest or 1)
end

function GrindTiers:GetTitle(session, kind)
    if kind == "dungeon" then
        return tostring(session.name or "Dungeon")
    end
    if ns.Grinding and ns.Grinding.FormatSessionTitle then
        return ns.Grinding:FormatSessionTitle(session)
    end
    return tostring(session.name or "Grinding Session")
end

function GrindTiers:AnalyzeSession(session, kind)
    local grindLevel = self:GetHighestMobLevel(session)
    local xpRequired = ns.GetXPToNextLevel and ns:GetXPToNextLevel(grindLevel) or 1
    local xpPerHour = math.max(0, tonumber(session.xpPerHour) or 0)
    local duration = safeDuration(session, kind)
    local vendorValue = self:GetVendorValue(session)
    local vendorPerHour = duration > 0 and math.floor(vendorValue * 3600 / duration) or 0
    local xpLevelRate = xpPerHour / xpRequired
    local valueLevelRate = vendorPerHour / xpRequired

    return {
        id = session.id,
        kind = kind,
        session = session,
        title = self:GetTitle(session, kind),
        class = session.class,
        classFile = session.classFile,
        levelStart = session.levelStart,
        grindLevel = grindLevel,
        xpRequired = xpRequired,
        xpPerHour = xpPerHour,
        xpLevelRate = xpLevelRate,
        xpLevelPercentPerHour = xpLevelRate * 100,
        vendorValue = vendorValue,
        vendorPerHour = vendorPerHour,
        valueLevelRate = valueLevelRate,
        combinedScore = 0,
    }
end

function GrindTiers:CollectRecords(scope)
    local db = ns.Database and ns.Database:GetDB()
    local records = {}
    if not db then
        return records
    end

    if scope == "world" or scope == "combined" then
        for _, session in pairs(db.grindSessions or {}) do
            if (tonumber(session.xpPerHour) or 0) > 0 or self:GetVendorValue(session) > 0 then
                table.insert(records, self:AnalyzeSession(session, "world"))
            end
        end
    end

    if scope == "dungeon" or scope == "combined" then
        for _, run in pairs(db.dungeonRuns or {}) do
            if (tonumber(run.xpPerHour) or 0) > 0 or self:GetVendorValue(run) > 0 then
                table.insert(records, self:AnalyzeSession(run, "dungeon"))
            end
        end
    end

    return records
end

local function sortBy(records, field)
    table.sort(records, function(left, right)
        if (left[field] or 0) == (right[field] or 0) then
            return tostring(left.title or "") < tostring(right.title or "")
        end
        return (left[field] or 0) > (right[field] or 0)
    end)
end

function GrindTiers:AssignMetric(records, field, rankKey, tierKey)
    local sorted = {}
    local best = 0
    for _, record in ipairs(records) do
        table.insert(sorted, record)
        best = math.max(best, tonumber(record[field]) or 0)
    end

    sortBy(sorted, field)
    for index, record in ipairs(sorted) do
        record[rankKey] = index
        record[tierKey] = tierFor(record[field], best)
    end
end

function GrindTiers:RankRecords(scope)
    local records = self:CollectRecords(scope)
    local bestXP = 0
    local bestValue = 0
    for _, record in ipairs(records) do
        bestXP = math.max(bestXP, record.xpLevelRate or 0)
        bestValue = math.max(bestValue, record.valueLevelRate or 0)
    end

    for _, record in ipairs(records) do
        local xpPart = bestXP > 0 and (record.xpLevelRate or 0) / bestXP or 0
        local valuePart = bestValue > 0 and (record.valueLevelRate or 0) / bestValue or 0
        record.combinedScore = (xpPart + valuePart) / 2
    end

    self:AssignMetric(records, "xpLevelRate", "xpRank", "xpTier")
    self:AssignMetric(records, "valueLevelRate", "valueRank", "valueTier")
    self:AssignMetric(records, "combinedScore", "combinedRank", "combinedTier")
    sortBy(records, "combinedScore")
    return records
end

function GrindTiers:StoreRecord(scope, record)
    local session = record.session
    if not session then
        return
    end

    session.tiers = session.tiers or {}
    session.tiers[scope] = {
        scope = scope,
        kind = record.kind,
        grindLevel = record.grindLevel,
        xpRequired = record.xpRequired,
        xpTier = record.xpTier,
        xpRank = record.xpRank,
        xpLevelPercentPerHour = record.xpLevelPercentPerHour,
        valueTier = record.valueTier,
        valueRank = record.valueRank,
        vendorPerHour = record.vendorPerHour,
        valueLevelRate = record.valueLevelRate,
        combinedTier = record.combinedTier,
        combinedRank = record.combinedRank,
        combinedScore = record.combinedScore,
        updatedAt = ns:Now(),
    }
end

function GrindTiers:RefreshScope(scope)
    local records = self:RankRecords(scope)
    for _, record in ipairs(records) do
        self:StoreRecord(scope, record)
    end
    return records
end

function GrindTiers:RefreshAllTiers()
    self:RefreshScope("world")
    self:RefreshScope("dungeon")
    self:RefreshScope("combined")
end

function GrindTiers:GetSessionScope(kind)
    return kind == "dungeon" and "dungeon" or "world"
end

function GrindTiers:FormatTierSet(label, data)
    if not data then
        return label .. " tiers unavailable"
    end
    return label .. " XP " .. tostring(data.xpTier or "?") .. " (#" .. tostring(data.xpRank or "?") .. "), Value " .. tostring(data.valueTier or "?") .. " (#" .. tostring(data.valueRank or "?") .. "), Combo " .. tostring(data.combinedTier or "?") .. " (#" .. tostring(data.combinedRank or "?") .. ")"
end

function GrindTiers:AnnounceSessionTiers(session, kind)
    if not session then
        return
    end

    local scope = self:GetSessionScope(kind)
    local tiers = session.tiers or {}
    local primary = tiers[scope]
    local combined = tiers.combined
    local message = self:FormatTierSet(SCOPE_LABELS[scope] or scope, primary)
    if combined and scope ~= "combined" then
        message = message .. " | " .. self:FormatTierSet("Combined", combined)
    end
    ns:Print("Tier rankings: " .. message)
end

function GrindTiers:OnPlayerLogin()
    self:RefreshAllTiers()
end

if ns.Grinding then
    local previousStop = ns.Grinding.Stop
    function ns.Grinding:Stop(...)
        local active = self:GetActive()
        local result = previousStop(self, ...)
        if active and not self:GetActive() then
            ns.GrindTiers:RefreshAllTiers()
            ns.GrindTiers:AnnounceSessionTiers(active, "world")
        end
        return result
    end
end

if ns.Dungeons then
    local previousDungeonStop = ns.Dungeons.Stop
    function ns.Dungeons:Stop(...)
        local active = self:GetActive()
        local result = previousDungeonStop(self, ...)
        if active and not self:GetActive() then
            ns.GrindTiers:RefreshAllTiers()
            ns.GrindTiers:AnnounceSessionTiers(active, "dungeon")
        end
        return result
    end
end

function GrindTiers:GetScopeLabel(scope)
    return SCOPE_LABELS[scope] or tostring(scope)
end

function GrindTiers:GetTierOrder()
    return TIER_ORDER
end
