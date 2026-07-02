local _, ns = ...

local GrindTiers = ns.GrindTiers
if not GrindTiers then
    return
end

local TIER_ORDER = { "S", "A", "B", "C", "D" }

local LOW_SIGNAL_WORDS = {
    ["the"] = true,
    ["and"] = true,
    ["for"] = true,
    ["with"] = true,
    ["from"] = true,
    ["young"] = true,
    ["old"] = true,
    ["elder"] = true,
    ["greater"] = true,
    ["lesser"] = true,
    ["minor"] = true,
    ["major"] = true,
    ["small"] = true,
    ["large"] = true,
    ["ancient"] = true,
    ["mature"] = true,
    ["raging"] = true,
    ["enraged"] = true,
    ["frenzied"] = true,
    ["diseased"] = true,
    ["corrupted"] = true,
}

local function sortBy(records, field)
    table.sort(records, function(left, right)
        if (left[field] or 0) == (right[field] or 0) then
            return tostring(left.title or "") < tostring(right.title or "")
        end
        return (left[field] or 0) > (right[field] or 0)
    end)
end

local function dynamicTier(score, worstScore, bestScore)
    score = tonumber(score) or 0
    worstScore = tonumber(worstScore) or 0
    bestScore = tonumber(bestScore) or 0

    if bestScore <= 0 then
        return "D"
    end
    if bestScore <= worstScore then
        return "S"
    end

    local normalized = (score - worstScore) / (bestScore - worstScore)
    if normalized >= 0.80 then
        return "S"
    elseif normalized >= 0.60 then
        return "A"
    elseif normalized >= 0.40 then
        return "B"
    elseif normalized >= 0.20 then
        return "C"
    end
    return "D"
end

local function normalizeText(value)
    return string.lower(tostring(value or ""))
end

local function addToken(tokens, token, seen)
    token = tostring(token or ""):gsub("^'+", ""):gsub("'+$", "")
    if string.len(token) >= 3 and not LOW_SIGNAL_WORDS[token] and not seen[token] then
        table.insert(tokens, token)
        seen[token] = true
    end
end

local function tokensFromName(name)
    local tokens = {}
    local seen = {}
    for word in string.gmatch(normalizeText(name), "[%a%d']+") do
        addToken(tokens, word, seen)
    end
    return tokens
end

local function bestMobFromSession(session)
    local best
    for _, mob in pairs((session and session.mobKills) or {}) do
        if not best
            or (mob.count or 0) > (best.count or 0)
            or ((mob.count or 0) == (best.count or 0) and (mob.xp or 0) > (best.xp or 0)) then
            best = mob
        end
    end
    return best
end

local function recordMobName(record)
    local session = record and record.session
    local primary = session and session.primaryMob
    if primary and primary.name then
        return primary.name
    end

    local bestMob = bestMobFromSession(session)
    if bestMob and bestMob.name then
        return bestMob.name
    end

    return record and record.title or nil
end

local function recordTokens(record)
    if not record or record.kind ~= "world" then
        return nil
    end

    local tokens = tokensFromName(recordMobName(record))
    if #tokens == 0 then
        return nil
    end
    return tokens
end

local function makeParents(count)
    local parents = {}
    for index = 1, count do
        parents[index] = index
    end
    return parents
end

local function findParent(parents, index)
    local parent = parents[index]
    while parent and parent ~= parents[parent] do
        parent = parents[parent]
    end
    local root = parent or index
    while parents[index] and parents[index] ~= root do
        local nextIndex = parents[index]
        parents[index] = root
        index = nextIndex
    end
    return root
end

local function unionParents(parents, left, right)
    local leftRoot = findParent(parents, left)
    local rightRoot = findParent(parents, right)
    if leftRoot ~= rightRoot then
        parents[rightRoot] = leftRoot
    end
end

local function preferRecord(left, right)
    if not left then
        return right
    end
    if not right then
        return left
    end

    if (right.combinedScore or 0) ~= (left.combinedScore or 0) then
        return (right.combinedScore or 0) > (left.combinedScore or 0) and right or left
    end
    if (right.xpLevelRate or 0) ~= (left.xpLevelRate or 0) then
        return (right.xpLevelRate or 0) > (left.xpLevelRate or 0) and right or left
    end
    if (right.valueLevelRate or 0) ~= (left.valueLevelRate or 0) then
        return (right.valueLevelRate or 0) > (left.valueLevelRate or 0) and right or left
    end
    return tostring(right.title or "") < tostring(left.title or "") and right or left
end

function GrindTiers:AssignMetric(records, field, rankKey, tierKey)
    local sorted = {}
    local bestScore
    local worstScore

    for _, record in ipairs(records or {}) do
        local score = tonumber(record[field]) or 0
        table.insert(sorted, record)
        bestScore = bestScore and math.max(bestScore, score) or score
        worstScore = worstScore and math.min(worstScore, score) or score
    end

    sortBy(sorted, field)
    for index, record in ipairs(sorted) do
        record[rankKey] = index
        record[tierKey] = dynamicTier(record[field], worstScore or 0, bestScore or 0)
    end
end

function GrindTiers:ScoreRecords(records)
    local bestXP = 0
    local bestValue = 0
    for _, record in ipairs(records or {}) do
        bestXP = math.max(bestXP, record.xpLevelRate or 0)
        bestValue = math.max(bestValue, record.valueLevelRate or 0)
    end

    for _, record in ipairs(records or {}) do
        local xpPart = bestXP > 0 and (record.xpLevelRate or 0) / bestXP or 0
        local valuePart = bestValue > 0 and (record.valueLevelRate or 0) / bestValue or 0
        record.combinedScore = (xpPart + valuePart) / 2
    end
end

function GrindTiers:CollapseSimilarWorldGrinds(records)
    local parents = makeParents(#records)
    local tokenOwner = {}
    local recordTokenMap = {}

    for index, record in ipairs(records or {}) do
        local tokens = recordTokens(record)
        recordTokenMap[index] = tokens
        if tokens then
            for _, token in ipairs(tokens) do
                if tokenOwner[token] then
                    unionParents(parents, index, tokenOwner[token])
                else
                    tokenOwner[token] = index
                end
            end
        end
    end

    local bestByGroup = {}
    local passthrough = {}
    for index, record in ipairs(records or {}) do
        if record.kind ~= "world" or not recordTokenMap[index] then
            table.insert(passthrough, record)
        else
            local root = findParent(parents, index)
            bestByGroup[root] = preferRecord(bestByGroup[root], record)
        end
    end

    local collapsed = {}
    for _, record in pairs(bestByGroup) do
        record.similarGrindWinner = true
        table.insert(collapsed, record)
    end
    for _, record in ipairs(passthrough) do
        table.insert(collapsed, record)
    end

    return collapsed
end

function GrindTiers:RankRecords(scope)
    local records = self:CollectRecords(scope)

    self:ScoreRecords(records)
    records = self:CollapseSimilarWorldGrinds(records)
    self:ScoreRecords(records)

    self:AssignMetric(records, "xpLevelRate", "xpRank", "xpTier")
    self:AssignMetric(records, "valueLevelRate", "valueRank", "valueTier")
    self:AssignMetric(records, "combinedScore", "combinedRank", "combinedTier")
    sortBy(records, "combinedScore")
    return records
end

function GrindTiers:OnPlayerLogin()
    self:RefreshAllTiers()
end
