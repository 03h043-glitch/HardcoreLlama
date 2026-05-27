local _, ns = ...

local Database = {}
ns.Database = Database

ns.SOURCE_LABELS = {
    QUEST = "Quests",
    KILL = "Kills",
    EXPLORATION = "Exploration",
    BONUS = "Bonuses",
    OTHER = "Other",
}

local SOURCE_ALIASES = {
    DISCOVERY = "EXPLORATION",
    EXPLORE = "EXPLORATION",
    MOB = "KILL",
    KILLS = "KILL",
    QUESTS = "QUEST",
}

local SOURCE_ORDER = { "QUEST", "KILL", "EXPLORATION", "BONUS", "OTHER" }
ns.SOURCE_ORDER = SOURCE_ORDER

function Database:Initialize()
    HardcoreLlamaDB = HardcoreLlamaDB or {}
    local db = HardcoreLlamaDB

    db.schemaVersion = 1
    db.createdAt = db.createdAt or ns:Now()
    db.characters = db.characters or {}
    db.classHighs = db.classHighs or {}
    db.fastestLevelTimes = db.fastestLevelTimes or {}
    db.fastestLevelTimesByClass = db.fastestLevelTimesByClass or {}
    db.grindSessions = db.grindSessions or {}
    db.grindSessionOrder = db.grindSessionOrder or {}
    db.trainerCache = db.trainerCache or { classSpells = {} }
    db.trainerCache.classSpells = db.trainerCache.classSpells or {}
    db.reminders = db.reminders or { dismissed = {} }
    db.settings = db.settings or {}
    db.settings.maxGrindSessions = db.settings.maxGrindSessions or 100
    db.settings.ui = db.settings.ui or {}
    db.settings.ui.fontSize = db.settings.ui.fontSize or 12
    db.settings.ui.windowWidth = db.settings.ui.windowWidth or 430
    db.settings.ui.windowHeight = db.settings.ui.windowHeight or 330
    if db.settings.notifyTrainingReminders == nil then
        db.settings.notifyTrainingReminders = true
    end

    self.db = db
    return db
end

function Database:GetDB()
    if not self.db then
        return self:Initialize()
    end
    return self.db
end

function Database:GetCharacterKey()
    local name = UnitName("player") or "Unknown"
    local realm = GetRealmName() or "UnknownRealm"
    return realm .. "-" .. name
end

function Database:NormalizeSource(source)
    source = string.upper(tostring(source or "OTHER"))
    return SOURCE_ALIASES[source] or source
end

function Database:EnsureCharacterTables(character)
    character.xp = character.xp or {}
    character.xp.total = character.xp.total or 0
    character.xp.rested = character.xp.rested or 0
    character.xp.bySource = character.xp.bySource or {}
    character.xp.restedBySource = character.xp.restedBySource or {}
    character.xp.days = character.xp.days or {}
    character.levelHistory = character.levelHistory or {}
    character.levelTimes = character.levelTimes or {}
    character.grindSessionIds = character.grindSessionIds or {}
    character.professions = character.professions or {}
end

function Database:GetCharacter()
    local db = self:GetDB()
    local key = self:GetCharacterKey()
    local character = db.characters[key]

    if not character then
        local localizedClass, classFile = UnitClass("player")
        character = {
            key = key,
            name = UnitName("player") or "Unknown",
            realm = GetRealmName() or "UnknownRealm",
            class = localizedClass or "Unknown",
            classFile = classFile or "UNKNOWN",
            firstSeen = ns:Now(),
            maxLevel = 0,
        }
        db.characters[key] = character
    end

    self:EnsureCharacterTables(character)
    return character, key
end

function Database:EnsureLevelEntry(character, level, enteredAt)
    if not level or level <= 0 then
        return nil
    end

    self:EnsureCharacterTables(character)
    local entry = character.levelHistory[level]
    if not entry then
        entry = {
            level = level,
            enteredAt = enteredAt or ns:Now(),
            enteredXP = UnitXP("player") or 0,
        }
        character.levelHistory[level] = entry
    end
    return entry
end

function Database:UpdateClassHigh(character)
    local db = self:GetDB()
    local classFile = character.classFile or "UNKNOWN"
    local level = character.level or 0
    local current = db.classHighs[classFile]

    if not current or level > (current.level or 0) then
        db.classHighs[classFile] = {
            class = character.class,
            classFile = classFile,
            level = level,
            character = character.name,
            realm = character.realm,
            recordedAt = ns:Now(),
        }
    end
end

function Database:TouchCharacter()
    local character = self:GetCharacter()
    local localizedClass, classFile = UnitClass("player")
    local race = UnitRace("player")
    local faction = UnitFactionGroup("player")
    local level = UnitLevel("player") or character.level or 1

    character.name = UnitName("player") or character.name
    character.realm = GetRealmName() or character.realm
    character.class = localizedClass or character.class
    character.classFile = classFile or character.classFile
    character.race = race or character.race
    character.faction = faction or character.faction
    character.level = level
    character.maxLevel = math.max(character.maxLevel or 0, level)
    character.lastSeen = ns:Now()
    character.zone = GetZoneText and GetZoneText() or character.zone
    character.xp.current = UnitXP("player") or 0
    character.xp.max = UnitXPMax("player") or 0

    self:EnsureLevelEntry(character, level)
    self:UpdateClassHigh(character)
    return character, character.key
end

function Database:SetPlayedTime(totalTime, levelTime)
    local character = self:TouchCharacter()
    local now = ns:Now()
    local level = UnitLevel("player") or character.level or 1
    totalTime = tonumber(totalTime) or 0
    levelTime = tonumber(levelTime) or 0

    character.playedTotal = totalTime
    character.playedLevel = levelTime
    character.playedUpdatedAt = now

    local currentEntry = self:EnsureLevelEntry(character, level, now)
    if currentEntry and not currentEntry.enteredPlayed then
        currentEntry.enteredPlayed = math.max(0, totalTime - levelTime)
    end

    if self.pendingLevelTransition then
        local pending = self.pendingLevelTransition
        local fromEntry = character.levelHistory[pending.fromLevel]
        local completedPlayed = math.max(0, totalTime - levelTime)

        if fromEntry and fromEntry.enteredPlayed then
            local duration = completedPlayed - fromEntry.enteredPlayed
            if duration > 0 then
                self:StoreLevelTime(pending.fromLevel, duration, character, "played")
            end
        end

        self.pendingLevelTransition = nil
    end
end

function Database:RecordLevelTransition(fromLevel, toLevel)
    local character = self:TouchCharacter()
    local now = ns:Now()
    fromLevel = tonumber(fromLevel)
    toLevel = tonumber(toLevel)

    if not fromLevel or fromLevel <= 0 then
        return
    end

    local fromEntry = self:EnsureLevelEntry(character, fromLevel)
    if fromEntry and fromEntry.enteredAt then
        local fallbackDuration = now - fromEntry.enteredAt
        if fallbackDuration > 0 then
            self:StoreLevelTime(fromLevel, fallbackDuration, character, "wall")
        end
        fromEntry.completedAt = now
    end

    if toLevel and toLevel > 0 then
        local toEntry = self:EnsureLevelEntry(character, toLevel, now)
        if toEntry then
            toEntry.enteredAt = toEntry.enteredAt or now
        end
    end

    self.pendingLevelTransition = {
        fromLevel = fromLevel,
        toLevel = toLevel,
        recordedAt = now,
    }

    if type(RequestTimePlayed) == "function" then
        RequestTimePlayed()
    end
end

function Database:StoreLevelTime(level, seconds, character, timingSource)
    local db = self:GetDB()
    level = tonumber(level)
    seconds = math.floor(tonumber(seconds) or 0)
    if not level or level <= 0 or seconds <= 0 then
        return
    end

    character = character or self:TouchCharacter()
    character.levelTimes[level] = {
        seconds = seconds,
        source = timingSource or "unknown",
        completedAt = ns:Now(),
    }

    local record = {
        level = level,
        seconds = seconds,
        source = timingSource or "unknown",
        character = character.name,
        realm = character.realm,
        class = character.class,
        classFile = character.classFile,
        recordedAt = ns:Now(),
    }

    local current = db.fastestLevelTimes[level]
    if not current or seconds < (current.seconds or math.huge) or current.source == "wall" then
        db.fastestLevelTimes[level] = record
    end

    local classFile = character.classFile or "UNKNOWN"
    db.fastestLevelTimesByClass[classFile] = db.fastestLevelTimesByClass[classFile] or {}
    local classCurrent = db.fastestLevelTimesByClass[classFile][level]
    if not classCurrent or seconds < (classCurrent.seconds or math.huge) or classCurrent.source == "wall" then
        db.fastestLevelTimesByClass[classFile][level] = record
    end
end

function Database:RecordProfession(skillName, rank, maxRank, category)
    local character = self:TouchCharacter()
    character.professions[skillName] = {
        rank = rank or 0,
        maxRank = maxRank or 0,
        category = category,
        updatedAt = ns:Now(),
    }
end

function Database:RecordXPGain(amount, source, restedAmount, context)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then
        return
    end

    source = self:NormalizeSource(source)
    restedAmount = math.max(0, math.floor(tonumber(restedAmount) or 0))
    restedAmount = math.min(restedAmount, amount)

    local character = self:TouchCharacter()
    local xp = character.xp
    xp.total = (xp.total or 0) + amount
    xp.rested = (xp.rested or 0) + restedAmount
    xp.bySource[source] = (xp.bySource[source] or 0) + amount
    xp.restedBySource[source] = (xp.restedBySource[source] or 0) + restedAmount

    local day = type(date) == "function" and date("%Y-%m-%d") or tostring(math.floor(ns:Now() / 86400))
    xp.days[day] = xp.days[day] or { total = 0, rested = 0, bySource = {} }
    xp.days[day].total = xp.days[day].total + amount
    xp.days[day].rested = xp.days[day].rested + restedAmount
    xp.days[day].bySource[source] = (xp.days[day].bySource[source] or 0) + amount

    if ns.Grinding then
        ns.Grinding:RecordXPGain(amount, source, restedAmount, context)
    end

    ns:MaybeRefreshUI()
end

function Database:GetHighestCharacter()
    local db = self:GetDB()
    local highest
    for _, character in pairs(db.characters) do
        if not highest or (character.maxLevel or character.level or 0) > (highest.maxLevel or highest.level or 0) then
            highest = character
        end
    end
    return highest
end

function Database:PrintSummary()
    local character = self:TouchCharacter()
    local xp = character.xp

    ns:Print(character.name .. "-" .. character.realm .. " level " .. tostring(character.level) .. " " .. tostring(character.class))
    ns:Print("Tracked XP: " .. ns:FormatNumber(xp.total or 0) .. " total, " .. ns:FormatNumber(xp.rested or 0) .. " rested")

    for _, source in ipairs(SOURCE_ORDER) do
        local amount = xp.bySource[source] or 0
        if amount > 0 then
            ns:Print((ns.SOURCE_LABELS[source] or source) .. ": " .. ns:FormatNumber(amount) .. " (" .. ns:Percent(amount, xp.total) .. ")")
        end
    end

    local highest = self:GetHighestCharacter()
    if highest then
        ns:Print("Highest seen: " .. tostring(highest.name) .. " level " .. tostring(highest.maxLevel or highest.level or 0) .. " " .. tostring(highest.class))
    end
end
