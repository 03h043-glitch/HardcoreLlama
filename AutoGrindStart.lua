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

local function tokenLabel(token)
    token = tostring(token or "")
    return (token:gsub("^%l", string.upper))
end

local function getMobTokens(name)
    local normalized = normalizeMobName(name)
    local tokens = {}
    local tokenSet = {}

    for word in string.gmatch(normalized, "[%a%d']+") do
        word = word:gsub("^'+", ""):gsub("'+$", "")
        if string.len(word) >= 3 and not LOW_SIGNAL_WORDS[word] and not tokenSet[word] then
            table.insert(tokens, word)
            tokenSet[word] = true
        end
    end

    if #tokens == 0 and normalized ~= "" then
        tokens[1] = normalized
        tokenSet[normalized] = true
    end

    return tokens, tokenSet
end

local function autoGrindName(mobName, sharedToken)
    local zone = ns.Trim((GetZoneText and GetZoneText()) or "")
    if zone ~= "" then
        return zone
    end
    if sharedToken and sharedToken ~= "" then
        return tokenLabel(sharedToken) .. " Grind"
    end
    return tostring(mobName or "Auto Grind") .. " Grind"
end

local function uniqueMobNames(kills)
    local names = {}
    local seen = {}
    for _, kill in ipairs(kills or {}) do
        local name = ns.Trim(kill.mobName)
        if name ~= "" and not seen[name] then
            table.insert(names, name)
            seen[name] = true
        end
    end
    return names
end

function Grinding:ClearAutoStartKills()
    self.autoStartKills = {}
end

function Grinding:IsDungeonTrackingActive()
    return ns.Dungeons and ns.Dungeons.GetActive and ns.Dungeons:GetActive() ~= nil
end

function Grinding:PruneAutoStartKills(now)
    self.autoStartKills = self.autoStartKills or {}
    for index = #self.autoStartKills, 1, -1 do
        if now - (self.autoStartKills[index].time or 0) > WINDOW_SECONDS then
            table.remove(self.autoStartKills, index)
        end
    end
end

function Grinding:RememberAutoStartKill(amount, source, restedAmount, context)
    local mobName = ns.Trim(context and context.mobName)
    if mobName == "" then
        return nil
    end

    local now = ns:Now()
    local tokens, tokenSet = getMobTokens(mobName)
    self:PruneAutoStartKills(now)
    self.autoStartKills = self.autoStartKills or {}

    local record = {
        time = now,
        amount = math.floor(tonumber(amount) or 0),
        source = source,
        rested = math.floor(tonumber(restedAmount) or 0),
        context = copyContext(context),
        mobName = mobName,
        tokens = tokens,
        tokenSet = tokenSet,
    }

    table.insert(self.autoStartKills, record)
    return record, mobName
end

function Grinding:FindAutoStartGroup(record)
    if not record then
        return nil
    end

    local bestToken
    local bestMatches
    for _, token in ipairs(record.tokens or {}) do
        local matches = {}
        for _, kill in ipairs(self.autoStartKills or {}) do
            if kill.tokenSet and kill.tokenSet[token] then
                table.insert(matches, kill)
            end
        end

        if #matches >= REQUIRED_KILLS and (not bestMatches or #matches > #bestMatches) then
            bestToken = token
            bestMatches = matches
        end
    end

    if not bestMatches then
        return nil
    end

    while #bestMatches > REQUIRED_KILLS do
        table.remove(bestMatches, 1)
    end
    return bestMatches, bestToken
end

function Grinding:GetAutoStartTargetRemaining(active)
    active = active or self:GetActive()
    if not active or not active.autoStarted or (not active.autoStartMobToken and ns.Trim(active.autoStartMob) == "") then
        return 0
    end

    local now = ns:Now()
    local lastKill = tonumber(active.lastAutoStartMobKillAt or active.startedAt or now) or now
    return math.max(0, TARGET_TIMEOUT_SECONDS - (now - lastKill))
end

function Grinding:MobMatchesAutoStartTarget(active, mobName)
    active = active or self:GetActive()
    if not active or not active.autoStarted then
        return false
    end

    local token = active.autoStartMobToken
    if token and token ~= "" then
        local _, tokenSet = getMobTokens(mobName)
        return tokenSet[token] == true
    end

    return normalizeMobName(mobName) == normalizeMobName(active.autoStartMob)
end

function Grinding:MarkAutoStartMobKill(active, mobName, timestamp)
    active = active or self:GetActive()
    if not active or not active.autoStarted or not self:MobMatchesAutoStartTarget(active, mobName) then
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

    if active.autoStarted and (active.autoStartMobToken or ns.Trim(active.autoStartMob) ~= "") then
        active.autoStartTargetRemaining = self:GetAutoStartTargetRemaining(active)
        if active.autoStartTargetRemaining <= 0 then
            local label = active.autoStartMobLabel or active.autoStartMob or "similar mob"
            self:Stop("no " .. tostring(label) .. " kills for 3 minutes")
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

    local record, mobName = self:RememberAutoStartKill(amount, source, restedAmount, context)
    local replay, sharedToken = self:FindAutoStartGroup(record)
    if not replay or not sharedToken then
        return false
    end

    self:ClearAutoStartKills()
    self.suppressNextStartWindow = true
    self:Start(autoGrindName(mobName, sharedToken))

    local active = self:GetActive()
    if not active then
        self.suppressNextStartWindow = nil
        return false
    end

    local label = tokenLabel(sharedToken) .. " mobs"
    active.autoStarted = true
    active.autoStartMob = label
    active.autoStartMobLabel = label
    active.autoStartMobToken = sharedToken
    active.autoStartExampleMob = mobName
    active.autoStartMatchedMobNames = uniqueMobNames(replay)
    active.autoStartKillCount = #replay
    active.autoStartWindowSeconds = WINDOW_SECONDS
    active.autoStartTargetTimeout = TARGET_TIMEOUT_SECONDS
    active.startedAt = replay[1] and replay[1].time or active.startedAt

    for _, kill in ipairs(replay) do
        previousRecordXPGain(self, kill.amount, kill.source, kill.rested, kill.context)
    end

    local lastReplay = replay[#replay]
    self:MarkAutoStartMobKill(active, lastReplay and lastReplay.mobName or mobName, lastReplay and lastReplay.time or ns:Now())

    if self.UpdateRates then
        self:UpdateRates(active)
    end
    if ns.AutoGrindWindow then
        ns.AutoGrindWindow:Show(active)
    elseif self.RefreshActiveView then
        self:RefreshActiveView()
    end

    ns:Print("Auto-started grind after " .. tostring(REQUIRED_KILLS) .. " similar " .. tokenLabel(sharedToken) .. " kills in 3 minutes.")
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
