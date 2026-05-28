local _, ns = ...

local Dungeons = ns:RegisterModule("Dungeons", {})
ns.Dungeons = Dungeons

local function getDungeonName()
    if type(IsInInstance) ~= "function" then
        return nil
    end

    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" then
        return nil
    end

    local name = type(GetInstanceInfo) == "function" and select(1, GetInstanceInfo()) or nil
    name = ns.Trim(name or (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Dungeon")
    return name ~= "" and name or "Dungeon"
end

function Dungeons:OnInitialize()
    ns:RegisterEvent("PLAYER_ENTERING_WORLD", self, "OnWorldChanged")
    ns:RegisterEvent("ZONE_CHANGED_NEW_AREA", self, "OnWorldChanged")
    ns:RegisterEvent("CHAT_MSG_LOOT", self, "OnLootMessage")
    ns:RegisterEvent("PLAYER_MONEY", self, "OnPlayerMoney")
    ns:RegisterEvent("PLAYER_TARGET_CHANGED", self, "OnPlayerTargetChanged")
    ns:RegisterEvent("UPDATE_MOUSEOVER_UNIT", self, "OnMouseoverUnit")
end

function Dungeons:OnPlayerLogin()
    self.lastMoney = GetMoney and GetMoney() or 0
    self:CheckInstanceState()
end

function Dungeons:GetActive()
    local db = ns.Database and ns.Database:GetDB()
    return db and db.activeDungeonSession or nil
end

function Dungeons:OnWorldChanged()
    self:CheckInstanceState()
end

function Dungeons:CheckInstanceState()
    local dungeonName = getDungeonName()
    local active = self:GetActive()

    if dungeonName then
        if not active then
            self:Start(dungeonName)
        elseif active.name ~= dungeonName then
            self:Stop()
            self:Start(dungeonName)
        end
    elseif active then
        self:Stop()
    end
end

function Dungeons:Start(name)
    local db = ns.Database:GetDB()
    if db.activeDungeonSession then
        return
    end

    local character, characterKey = ns.Database:TouchCharacter()
    local now = ns:Now()
    db.activeDungeonSession = {
        id = characterKey .. "-dungeon-" .. tostring(now),
        name = ns.Trim(name) ~= "" and ns.Trim(name) or "Dungeon",
        characterKey = characterKey,
        character = character.name,
        realm = character.realm,
        class = character.class,
        classFile = character.classFile,
        levelStart = UnitLevel("player") or character.level,
        zoneStart = GetZoneText and GetZoneText() or nil,
        startedAt = now,
        xpGained = 0,
        totalXP = 0,
        questXP = 0,
        restedXP = 0,
        totalRestedXP = 0,
        killXP = 0,
        mobCount = 0,
        mobKills = {},
        mobLevelHints = {},
        rawCopper = 0,
        totalRawCopper = 0,
        questRewardCopper = 0,
        pendingQuestCopper = 0,
        lootVendorCopper = 0,
        sourceXP = {},
        allSourceXP = {},
    }

    self.lastMoney = GetMoney and GetMoney() or self.lastMoney or 0
    ns:Print("Started dungeon tracking: " .. tostring(db.activeDungeonSession.name))
    ns:MaybeRefreshUI()
end

function Dungeons:RememberUnit(unit)
    local active = self:GetActive()
    if not active or type(UnitName) ~= "function" or type(UnitLevel) ~= "function" then
        return
    end
    if type(UnitExists) == "function" and not UnitExists(unit) then
        return
    end
    if type(UnitCanAttack) == "function" and not UnitCanAttack("player", unit) then
        return
    end

    local mobName = ns.Trim(UnitName(unit))
    local mobLevel = tonumber(UnitLevel(unit))
    if mobName == "" or not mobLevel or mobLevel <= 0 then
        return
    end

    active.mobLevelHints = active.mobLevelHints or {}
    local hint = active.mobLevelHints[mobName] or { minLevel = mobLevel, maxLevel = mobLevel }
    hint.minLevel = math.min(hint.minLevel or mobLevel, mobLevel)
    hint.maxLevel = math.max(hint.maxLevel or mobLevel, mobLevel)
    active.mobLevelHints[mobName] = hint
end

function Dungeons:OnPlayerTargetChanged()
    self:RememberUnit("target")
end

function Dungeons:OnMouseoverUnit()
    self:RememberUnit("mouseover")
end

function Dungeons:EffectiveDuration(active, includeQuest)
    if not active then
        return 0
    end

    local first = includeQuest and active.firstXPAt or active.repeatableFirstXPAt
    local last = includeQuest and active.lastXPAt or active.repeatableLastXPAt
    if not first or not last then
        return 0
    end
    return math.max(1, last - first)
end

function Dungeons:UpdateRates(active)
    active = active or self:GetActive()
    if not active then
        return
    end

    active.duration = self:EffectiveDuration(active, false)
    active.totalDuration = self:EffectiveDuration(active, true)
    active.xpPerHour = active.duration > 0 and math.floor((active.xpGained or 0) * 3600 / active.duration) or 0
    active.totalXPPerHour = active.totalDuration > 0 and math.floor((active.totalXP or 0) * 3600 / active.totalDuration) or 0
    active.averageXPPerMob = (active.mobCount or 0) > 0 and math.floor((active.killXP or 0) / active.mobCount) or 0
    active.totalValueCopper = (active.rawCopper or 0) + (active.lootVendorCopper or 0)
    active.totalValueWithQuestCopper = (active.totalRawCopper or 0) + (active.lootVendorCopper or 0)
end

function Dungeons:RecordXPGain(amount, source, restedAmount, context)
    local active = self:GetActive()
    if not active then
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return
    end

    source = ns.Database:NormalizeSource(source)
    restedAmount = math.floor(tonumber(restedAmount) or 0)
    local now = ns:Now()

    active.totalXP = (active.totalXP or 0) + amount
    active.totalRestedXP = (active.totalRestedXP or 0) + restedAmount
    active.allSourceXP[source] = (active.allSourceXP[source] or 0) + amount
    active.firstXPAt = active.firstXPAt or now
    active.lastXPAt = now

    if source == "QUEST" then
        active.questXP = (active.questXP or 0) + amount
        local questMoney = context and tonumber(context.questMoney) or 0
        if questMoney > 0 then
            active.pendingQuestCopper = (active.pendingQuestCopper or 0) + questMoney
        end
        self:UpdateRates(active)
        return
    end

    active.xpGained = (active.xpGained or 0) + amount
    active.restedXP = (active.restedXP or 0) + restedAmount
    active.sourceXP[source] = (active.sourceXP[source] or 0) + amount
    active.repeatableFirstXPAt = active.repeatableFirstXPAt or now
    active.repeatableLastXPAt = now

    if source == "KILL" then
        active.mobCount = (active.mobCount or 0) + 1
        active.killXP = (active.killXP or 0) + amount
        if ns.Grinding then
            ns.Grinding:RecordMobKill(active, context, amount)
        end
    end

    self:UpdateRates(active)
end

function Dungeons:OnLootMessage(event, message)
    local active = self:GetActive()
    if not active then
        return
    end

    local itemLink = tostring(message or ""):match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then
        return
    end

    local quantity = tonumber(tostring(message):match("x(%d+)")) or 1
    local sellPrice = select(11, GetItemInfo(itemLink))
    if sellPrice and sellPrice > 0 then
        active.lootVendorCopper = (active.lootVendorCopper or 0) + (sellPrice * quantity)
        self:UpdateRates(active)
        ns:MaybeRefreshUI()
    end
end

function Dungeons:OnPlayerMoney()
    local currentMoney = GetMoney and GetMoney() or 0
    if not self.lastMoney then
        self.lastMoney = currentMoney
        return
    end

    local delta = currentMoney - self.lastMoney
    self.lastMoney = currentMoney

    local active = self:GetActive()
    if active and delta > 0 then
        active.totalRawCopper = (active.totalRawCopper or 0) + delta
        local questPart = 0
        if (active.pendingQuestCopper or 0) > 0 then
            questPart = math.min(delta, active.pendingQuestCopper)
            active.pendingQuestCopper = math.max(0, (active.pendingQuestCopper or 0) - questPart)
            active.questRewardCopper = (active.questRewardCopper or 0) + questPart
        end

        local repeatableCopper = delta - questPart
        if repeatableCopper > 0 then
            active.rawCopper = (active.rawCopper or 0) + repeatableCopper
        end
        self:UpdateRates(active)
        ns:MaybeRefreshUI()
    end
end

function Dungeons:Stop()
    local db = ns.Database:GetDB()
    local active = db.activeDungeonSession
    if not active then
        return
    end

    active.endedAt = ns:Now()
    active.levelEnd = UnitLevel("player") or active.levelStart
    active.zoneEnd = GetZoneText and GetZoneText() or active.zoneStart
    if ns.Grinding then
        ns.Grinding:UpdateTopMob(active)
    end
    self:UpdateRates(active)

    db.dungeonRuns[active.id] = active
    table.insert(db.dungeonRunOrder, 1, active.id)

    local character = ns.Database:TouchCharacter()
    character.dungeonRunIds = character.dungeonRunIds or {}
    table.insert(character.dungeonRunIds, 1, active.id)

    while #db.dungeonRunOrder > (db.settings.maxDungeonRuns or 100) do
        local oldId = table.remove(db.dungeonRunOrder)
        db.dungeonRuns[oldId] = nil
    end

    db.activeDungeonSession = nil
    ns:Print("Saved dungeon run: " .. tostring(active.name) .. " - " .. ns:FormatNumber(active.xpGained or 0) .. " repeatable XP at " .. ns:FormatNumber(active.xpPerHour or 0) .. " XP/hour.")
    ns:MaybeRefreshUI()
end

function Dungeons:BuildMetricLines(session, includeQuest)
    session = session or self:GetActive()
    if not session then
        return { "No active dungeon run." }
    end

    self:UpdateRates(session)
    local xp = includeQuest and (session.totalXP or 0) or (session.xpGained or 0)
    local xpPerHour = includeQuest and (session.totalXPPerHour or 0) or (session.xpPerHour or 0)
    local duration = includeQuest and (session.totalDuration or 0) or (session.duration or 0)
    local rested = includeQuest and (session.totalRestedXP or 0) or (session.restedXP or 0)
    local rawCopper = includeQuest and (session.totalRawCopper or 0) or (session.rawCopper or 0)
    local totalValue = includeQuest and (session.totalValueWithQuestCopper or 0) or (session.totalValueCopper or 0)
    local topMob = ns.Grinding and ns.Grinding:UpdateTopMob(session)

    local lines = {
        "Duration: " .. ns:FormatDuration(duration or 0),
        "XP gained: " .. ns:FormatNumber(xp or 0),
        "XP/hour: " .. ns:FormatNumber(xpPerHour or 0),
        "Mobs with XP: " .. ns:FormatNumber(session.mobCount or 0),
        "Average XP/mob: " .. ns:FormatNumber(session.averageXPPerMob or 0),
        "Rested XP: " .. ns:FormatNumber(rested or 0),
        "Raw money gained: " .. ns:FormatMoney(rawCopper or 0),
        "Loot vendor estimate: " .. ns:FormatMoney(session.lootVendorCopper or 0),
        "Total dungeon value: " .. ns:FormatMoney(totalValue or 0),
    }

    if topMob and ns.Grinding then
        table.insert(lines, "Top mob: " .. tostring(ns.Grinding:FormatPrimaryMob(topMob)))
    end
    if includeQuest then
        table.insert(lines, "Quest XP: " .. ns:FormatNumber(session.questXP or 0))
        table.insert(lines, "Quest rewards: " .. ns:FormatMoney(session.questRewardCopper or 0))
    end
    return lines
end

function Dungeons:BuildStatusLines(active)
    active = active or self:GetActive()
    if not active then
        return { "No active dungeon run." }
    end

    local lines = { "Active: " .. tostring(active.name) }
    for _, line in ipairs(self:BuildMetricLines(active, false)) do
        table.insert(lines, line)
    end
    return lines
end

function Dungeons:BuildTooltipLines(session)
    return self:BuildMetricLines(session, true)
end

function Dungeons:GetRecentRuns(limit)
    local db = ns.Database:GetDB()
    local runs = {}
    limit = limit or 5
    for index = 1, math.min(limit, #db.dungeonRunOrder) do
        local id = db.dungeonRunOrder[index]
        if id and db.dungeonRuns[id] then
            table.insert(runs, db.dungeonRuns[id])
        end
    end
    return runs
end

function Dungeons:GetBestRuns(limit, classFile)
    local db = ns.Database:GetDB()
    local runs = {}
    limit = limit or 5
    for _, run in pairs(db.dungeonRuns or {}) do
        if (not classFile or run.classFile == classFile) and (run.xpPerHour or 0) > 0 then
            table.insert(runs, run)
        end
    end

    table.sort(runs, function(left, right)
        if (left.xpPerHour or 0) == (right.xpPerHour or 0) then
            return (left.xpGained or 0) > (right.xpGained or 0)
        end
        return (left.xpPerHour or 0) > (right.xpPerHour or 0)
    end)

    while #runs > limit do
        table.remove(runs)
    end
    return runs
end
