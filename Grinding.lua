local _, ns = ...

local Grinding = ns:RegisterModule("Grinding", {})
ns.Grinding = Grinding

function Grinding:OnInitialize()
    ns:RegisterEvent("CHAT_MSG_LOOT", self, "OnLootMessage")
    ns:RegisterEvent("PLAYER_MONEY", self, "OnPlayerMoney")
end

function Grinding:OnPlayerLogin()
    self.lastMoney = GetMoney and GetMoney() or 0
    local active = self:GetActive()
    if active then
        ns:Print("resumed grind session: " .. tostring(active.name or active.id) .. ". Use /hcl grind stop when finished.")
    end
end

function Grinding:GetActive()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        return nil
    end
    return db.activeSession
end

function Grinding:Start(name)
    local db = ns.Database:GetDB()
    if db.activeSession then
        ns:Print("A grind session is already active. Use /hcl grind stop first.")
        return
    end

    local character, characterKey = ns.Database:TouchCharacter()
    name = ns.Trim(name)
    if name == "" then
        name = (GetZoneText and GetZoneText()) or "Grinding Session"
    end

    local now = ns:Now()
    db.activeSession = {
        id = characterKey .. "-" .. tostring(now),
        name = name,
        characterKey = characterKey,
        character = character.name,
        realm = character.realm,
        class = character.class,
        classFile = character.classFile,
        levelStart = UnitLevel("player") or character.level,
        zoneStart = GetZoneText and GetZoneText() or nil,
        startedAt = now,
        xpGained = 0,
        restedXP = 0,
        killXP = 0,
        mobCount = 0,
        rawCopper = 0,
        lootVendorCopper = 0,
        sourceXP = {},
    }

    self.lastMoney = GetMoney and GetMoney() or self.lastMoney or 0
    ns:Print("Started grind session: " .. name)
    ns:MaybeRefreshUI()
end

function Grinding:UpdateRates(active)
    active = active or self:GetActive()
    if not active then
        return
    end

    local duration = math.max(1, ns:Now() - (active.startedAt or ns:Now()))
    active.duration = duration
    active.xpPerHour = math.floor((active.xpGained or 0) * 3600 / duration)
    active.averageXPPerMob = active.mobCount and active.mobCount > 0 and math.floor((active.killXP or 0) / active.mobCount) or 0
    active.totalValueCopper = (active.rawCopper or 0) + (active.lootVendorCopper or 0)
end

function Grinding:RecordXPGain(amount, source, restedAmount, context)
    local active = self:GetActive()
    if not active then
        return
    end

    amount = math.floor(tonumber(amount) or 0)
    restedAmount = math.floor(tonumber(restedAmount) or 0)
    source = ns.Database:NormalizeSource(source)

    active.xpGained = (active.xpGained or 0) + amount
    active.restedXP = (active.restedXP or 0) + restedAmount
    active.sourceXP[source] = (active.sourceXP[source] or 0) + amount

    if source == "KILL" then
        active.mobCount = (active.mobCount or 0) + 1
        active.killXP = (active.killXP or 0) + amount
        if context and context.mobName then
            active.lastMob = context.mobName
        end
    end

    self:UpdateRates(active)
end

function Grinding:OnLootMessage(event, message)
    local active = self:GetActive()
    if not active then
        return
    end

    message = tostring(message or "")
    local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then
        return
    end

    local quantity = tonumber(message:match("x(%d+)")) or 1
    local sellPrice = select(11, GetItemInfo(itemLink))
    if sellPrice and sellPrice > 0 then
        active.lootVendorCopper = (active.lootVendorCopper or 0) + (sellPrice * quantity)
        self:UpdateRates(active)
        ns:MaybeRefreshUI()
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
        active.rawCopper = (active.rawCopper or 0) + delta
        self:UpdateRates(active)
        ns:MaybeRefreshUI()
    end
end

function Grinding:Stop()
    local db = ns.Database:GetDB()
    local active = db.activeSession
    if not active then
        ns:Print("No grind session is active.")
        return
    end

    self:UpdateRates(active)
    active.endedAt = ns:Now()
    active.duration = math.max(1, active.endedAt - (active.startedAt or active.endedAt))
    active.levelEnd = UnitLevel("player") or active.levelStart
    active.zoneEnd = GetZoneText and GetZoneText() or active.zoneStart

    db.grindSessions[active.id] = active
    table.insert(db.grindSessionOrder, 1, active.id)

    local character = ns.Database:TouchCharacter()
    table.insert(character.grindSessionIds, 1, active.id)

    while #db.grindSessionOrder > (db.settings.maxGrindSessions or 100) do
        local oldId = table.remove(db.grindSessionOrder)
        db.grindSessions[oldId] = nil
    end

    db.activeSession = nil
    ns:Print("Saved grind session: " .. tostring(active.name) .. " - " .. ns:FormatNumber(active.xpGained or 0) .. " XP at " .. ns:FormatNumber(active.xpPerHour or 0) .. " XP/hour.")
    ns:MaybeRefreshUI()
end

function Grinding:BuildStatusLines(active)
    active = active or self:GetActive()
    local lines = {}
    if not active then
        table.insert(lines, "No active grind session.")
        return lines
    end

    self:UpdateRates(active)
    table.insert(lines, "Active: " .. tostring(active.name))
    table.insert(lines, "Duration: " .. ns:FormatDuration(active.duration or 0))
    table.insert(lines, "XP gained: " .. ns:FormatNumber(active.xpGained or 0))
    table.insert(lines, "XP/hour: " .. ns:FormatNumber(active.xpPerHour or 0))
    table.insert(lines, "Mobs with XP: " .. ns:FormatNumber(active.mobCount or 0))
    table.insert(lines, "Average XP/mob: " .. ns:FormatNumber(active.averageXPPerMob or 0))
    table.insert(lines, "Rested XP: " .. ns:FormatNumber(active.restedXP or 0))
    table.insert(lines, "Raw money gained: " .. ns:FormatMoney(active.rawCopper or 0))
    table.insert(lines, "Loot vendor estimate: " .. ns:FormatMoney(active.lootVendorCopper or 0))
    table.insert(lines, "Total grind value: " .. ns:FormatMoney(active.totalValueCopper or 0))

    return lines
end

function Grinding:PrintStatus()
    local lines = self:BuildStatusLines()
    for _, line in ipairs(lines) do
        ns:Print(line)
    end
end

function Grinding:GetRecentSessions(limit)
    local db = ns.Database:GetDB()
    local sessions = {}
    limit = limit or 5

    for index = 1, math.min(limit, #db.grindSessionOrder) do
        local id = db.grindSessionOrder[index]
        if id and db.grindSessions[id] then
            table.insert(sessions, db.grindSessions[id])
        end
    end

    return sessions
end
