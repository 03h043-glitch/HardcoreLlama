local _, ns = ...

local Experience = ns:RegisterModule("Experience", {})
Experience.pending = {}

local function parseNumber(value)
    if not value then
        return nil
    end
    value = tostring(value):gsub(",", "")
    return tonumber(value)
end

local function currentState()
    local rested = nil
    if type(GetXPExhaustion) == "function" then
        rested = GetXPExhaustion()
    end

    return UnitLevel("player") or 0, UnitXP("player") or 0, UnitXPMax("player") or 0, rested
end

local function questRewardMoney()
    if type(GetRewardMoney) == "function" then
        return tonumber(GetRewardMoney()) or 0
    end
    return 0
end

local function visibleMobLevel(mobName)
    mobName = ns.Trim(mobName)
    if mobName == "" or type(UnitName) ~= "function" or type(UnitLevel) ~= "function" then
        return nil
    end

    local units = { "target", "mouseover", "focus", "targettarget" }
    for _, unit in ipairs(units) do
        if (type(UnitExists) ~= "function" or UnitExists(unit)) and UnitName(unit) == mobName then
            local level = tonumber(UnitLevel(unit))
            if level and level > 0 then
                return level
            end
        end
    end

    return nil
end

function Experience:OnInitialize()
    ns:RegisterEvent("PLAYER_XP_UPDATE", self, "OnPlayerXPUpdate")
    ns:RegisterEvent("PLAYER_LEVEL_UP", self, "OnPlayerLevelUp")
    ns:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN", self, "OnCombatXPGain")
    ns:RegisterEvent("QUEST_COMPLETE", self, "OnQuestComplete")
    ns:RegisterEvent("QUEST_TURNED_IN", self, "OnQuestTurnedIn")
    ns:RegisterEvent("TIME_PLAYED_MSG", self, "OnTimePlayed")
    self:HookQuestCompleteButton()
end

function Experience:OnPlayerLogin()
    self:Snapshot()
    self:HookQuestCompleteButton()
    if type(RequestTimePlayed) == "function" then
        RequestTimePlayed()
    end
end

function Experience:HookQuestCompleteButton()
    if self.questButtonHooked then
        return
    end
    if QuestFrameCompleteButton and QuestFrameCompleteButton.HookScript then
        QuestFrameCompleteButton:HookScript("OnClick", function()
            local rewardXP = nil
            if type(GetRewardXP) == "function" then
                rewardXP = GetRewardXP()
            end
            Experience:AddPending("QUEST", rewardXP, 0, { message = "Quest completion button", questMoney = questRewardMoney() })
        end)
        self.questButtonHooked = true
    end
end

function Experience:Snapshot()
    self.lastLevel, self.lastXP, self.lastXPMax, self.lastRested = currentState()
end

function Experience:AddPending(source, amount, restedAmount, context)
    source = source or "OTHER"

    if source == "QUEST" then
        for index = #self.pending, 1, -1 do
            if self.pending[index].source == "QUEST" then
                table.remove(self.pending, index)
            end
        end
    end

    table.insert(self.pending, {
        source = source,
        amount = amount and math.floor(amount) or nil,
        rested = restedAmount and math.floor(restedAmount) or nil,
        context = context,
        time = GetTime() or 0,
    })
end

function Experience:PrunePending(now)
    for index = #self.pending, 1, -1 do
        if now - (self.pending[index].time or 0) > 6 then
            table.remove(self.pending, index)
        end
    end
end

function Experience:ConsumePending(delta)
    local now = GetTime() or 0
    self:PrunePending(now)

    for index = #self.pending, 1, -1 do
        local pending = self.pending[index]
        if pending.amount and math.abs(pending.amount - delta) <= math.max(2, math.floor(delta * 0.02)) then
            table.remove(self.pending, index)
            return pending
        end
    end

    for index = #self.pending, 1, -1 do
        local pending = self.pending[index]
        if not pending.amount and now - (pending.time or 0) <= 3 then
            table.remove(self.pending, index)
            return pending
        end
    end

    return nil
end

function Experience:ParseCombatXP(message)
    message = tostring(message or "")
    local lower = string.lower(message)
    local amount = parseNumber(message:match("([%d,]+)%s+experience"))
    local rested = parseNumber(message:match("%+([%d,]+)%s+exp%s+Rested"))
    local source = "OTHER"
    local mobName = nil
    local mobLevel = nil

    if lower:find(" dies", 1, true) or lower:find(" slain", 1, true) then
        source = "KILL"
        mobName = ns.Trim(message:match("^(.-)%s+dies") or message:match("^(.-)%s+is slain"))
        if mobName == "" then
            mobName = nil
        else
            mobLevel = visibleMobLevel(mobName)
        end
    elseif lower:find("discovered", 1, true) or lower:find("discover", 1, true) then
        source = "EXPLORATION"
    end

    return source, amount, rested, { message = message, mobName = mobName, mobLevel = mobLevel }
end

function Experience:OnCombatXPGain(event, message)
    local source, amount, rested, context = self:ParseCombatXP(message)
    if amount and amount > 0 then
        self:AddPending(source, amount, rested, context)
    end
end

function Experience:OnQuestComplete()
    local rewardXP = nil
    if type(GetRewardXP) == "function" then
        rewardXP = GetRewardXP()
    end
    self:AddPending("QUEST", rewardXP, 0, { message = "Quest completion", questMoney = questRewardMoney() })
end

function Experience:OnQuestTurnedIn(event, questID, xpReward, moneyReward)
    xpReward = tonumber(xpReward)
    if xpReward and xpReward > 0 then
        self:AddPending("QUEST", xpReward, 0, { questID = questID, questMoney = tonumber(moneyReward) or 0 })
    end
end

function Experience:OnPlayerLevelUp(event, newLevel)
    newLevel = tonumber(newLevel)
    if newLevel and ns.Database then
        ns.Database:RecordLevelTransition(newLevel - 1, newLevel)
    end
end

function Experience:OnTimePlayed(event, totalTime, levelTime)
    if ns.Database then
        ns.Database:SetPlayedTime(totalTime, levelTime)
    end
end

function Experience:OnPlayerXPUpdate(event, unit)
    if unit and unit ~= "player" then
        return
    end

    local level, xp, xpMax, rested = currentState()
    if not self.lastLevel then
        self:Snapshot()
        return
    end

    local delta = 0
    if level == self.lastLevel then
        delta = xp - (self.lastXP or 0)
    elseif level > self.lastLevel then
        delta = ((self.lastXPMax or 0) - (self.lastXP or 0)) + xp
    else
        self:Snapshot()
        return
    end

    if delta > 0 then
        local pending = self:ConsumePending(delta)
        local source = pending and pending.source or "OTHER"
        local restedAmount = pending and pending.rested or nil

        if not restedAmount and self.lastRested and rested then
            restedAmount = math.max(0, (self.lastRested or 0) - rested)
        end

        if ns.Database then
            ns.Database:RecordXPGain(delta, source, restedAmount or 0, pending and pending.context or nil)
        end
    end

    self.lastLevel = level
    self.lastXP = xp
    self.lastXPMax = xpMax
    self.lastRested = rested
end
