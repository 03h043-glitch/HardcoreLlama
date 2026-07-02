local _, ns = ...

local GrindTiers = ns.GrindTiers
if not GrindTiers then
    return
end

local function sortBy(records, field)
    table.sort(records, function(left, right)
        if (left[field] or 0) == (right[field] or 0) then
            return tostring(left.title or "") < tostring(right.title or "")
        end
        return (left[field] or 0) > (right[field] or 0)
    end)
end

local function tierForPosition(index, count, worstScore, bestScore)
    bestScore = tonumber(bestScore) or 0
    worstScore = tonumber(worstScore) or 0
    if bestScore <= 0 then
        return "D"
    end
    if count <= 1 or bestScore <= worstScore then
        return "S"
    end

    local position = (index - 1) / math.max(1, count - 1)
    if position <= 0.20 then
        return "S"
    elseif position <= 0.40 then
        return "A"
    elseif position <= 0.60 then
        return "B"
    elseif position <= 0.80 then
        return "C"
    end
    return "D"
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
    local count = #sorted
    for index, record in ipairs(sorted) do
        record[rankKey] = index
        record[tierKey] = tierForPosition(index, count, worstScore or 0, bestScore or 0)
    end
end
