local _, ns = ...

local Reminders = ns:RegisterModule("Reminders", {})
ns.Reminders = Reminders

local function costText(row)
    if row.cost then
        return row.cost
    end
    if row.costCopper then
        return ns:FormatMoney(row.costCopper)
    end
    return nil
end

local function rankText(row)
    if row.rankText and row.rankText ~= "" then
        return row.rankText
    end
    if row.rank then
        return "Rank " .. tostring(row.rank)
    end
    return nil
end

local function spellLabel(row)
    local rank = rankText(row)
    if rank then
        return tostring(row.name) .. " " .. rank
    end
    return tostring(row.name)
end

function Reminders:OnInitialize()
    ns:RegisterEvent("PLAYER_LEVEL_UP", self, "OnLevelUp")
    ns:RegisterEvent("SKILL_LINES_CHANGED", self, "OnSkillLinesChanged")
    ns:RegisterEvent("TRAINER_SHOW", self, "OnTrainerEvent")
    ns:RegisterEvent("TRAINER_UPDATE", self, "OnTrainerEvent")
end

function Reminders:OnPlayerLogin()
    local snapshot = self:GetSkillSnapshot()
    self:ScanSkills(snapshot)
    self.lastSkillSnapshot = snapshot
end

function Reminders:OnLevelUp(event, newLevel)
    local snapshot = self:GetSkillSnapshot()
    self:ScanSkills(snapshot)
    self.lastSkillSnapshot = snapshot
    self:PrintLevelUpReminders(newLevel)
    ns:MaybeRefreshUI()
end

function Reminders:OnSkillLinesChanged()
    local previous = self.lastSkillSnapshot
    local current = self:GetSkillSnapshot()

    self:ScanSkills(current)

    if previous then
        for skillName, skill in pairs(current.skills) do
            local oldSkill = previous.skills and previous.skills[skillName]
            if oldSkill and (skill.rank or 0) > (oldSkill.rank or 0) and (skill.category == "primary" or skill.category == "secondary") then
                self:AnnounceProfessionSkillGain(skillName, skill)
            end
        end
    end

    self.lastSkillSnapshot = current
    ns:MaybeRefreshUI()
end

function Reminders:OnTrainerEvent()
    self:ScanTrainer()
    local snapshot = self:GetSkillSnapshot()
    self:ScanSkills(snapshot)
    self.lastSkillSnapshot = snapshot
    ns:MaybeRefreshUI()
end

function Reminders:IsPrimaryProfession(name)
    return ns.TrainingData.primaryProfessions and ns.TrainingData.primaryProfessions[name]
end

function Reminders:IsSecondarySkill(name)
    return ns.TrainingData.secondarySkills and ns.TrainingData.secondarySkills[name]
end

function Reminders:GetSkillSnapshot()
    local snapshot = { skills = {}, primaryCount = 0, secondaryCount = 0 }
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return snapshot
    end

    for index = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(index)
        if name and not isHeader then
            local category = "other"
            if self:IsPrimaryProfession(name) then
                category = "primary"
                snapshot.primaryCount = snapshot.primaryCount + 1
            elseif self:IsSecondarySkill(name) then
                category = "secondary"
                snapshot.secondaryCount = snapshot.secondaryCount + 1
            end

            snapshot.skills[name] = {
                name = name,
                rank = rank or 0,
                maxRank = maxRank or 0,
                category = category,
            }
        end
    end

    return snapshot
end

function Reminders:GetSkill(skillName)
    return self:GetSkillSnapshot().skills[skillName]
end

function Reminders:ScanSkills(snapshot)
    if not ns.Database then
        return
    end

    snapshot = snapshot or self:GetSkillSnapshot()
    for name, skill in pairs(snapshot.skills) do
        if skill.category == "primary" or skill.category == "secondary" then
            ns.Database:RecordProfession(name, skill.rank, skill.maxRank, skill.category)
        end
    end
end

function Reminders:BuildClassSpellNameCache(classFile)
    self.classSpellNameCache = self.classSpellNameCache or {}
    if self.classSpellNameCache[classFile] then
        return self.classSpellNameCache[classFile]
    end

    local names = {}
    for _, row in ipairs((ns.TrainingData.classSpells and ns.TrainingData.classSpells[classFile]) or {}) do
        names[row.name] = true
    end
    self.classSpellNameCache[classFile] = names
    return names
end

function Reminders:IsClassSpellName(name, classFile)
    local names = self:BuildClassSpellNameCache(classFile)
    return names[name]
end

function Reminders:PlayerKnowsSpell(row)
    if type(GetNumSpellTabs) ~= "function" or type(GetSpellTabInfo) ~= "function" or type(GetSpellName) ~= "function" then
        return false
    end

    local wantedRank = rankText(row)
    local bookType = BOOKTYPE_SPELL or "spell"
    for tab = 1, GetNumSpellTabs() do
        local _, _, offset, numSpells = GetSpellTabInfo(tab)
        offset = offset or 0
        numSpells = numSpells or 0
        for spellIndex = offset + 1, offset + numSpells do
            local spellName, spellRank = GetSpellName(spellIndex, bookType)
            if spellName == row.name then
                if not wantedRank or wantedRank == spellRank or spellRank == "" then
                    return true
                end
            end
        end
    end

    return false
end

function Reminders:ScanTrainer()
    if not ns.Database or type(GetNumTrainerServices) ~= "function" or type(GetTrainerServiceInfo) ~= "function" then
        return
    end

    local _, classFile = UnitClass("player")
    if not classFile then
        return
    end

    local cached = {}
    for index = 1, GetNumTrainerServices() do
        local name, subText, serviceType = GetTrainerServiceInfo(index)
        if name and self:IsClassSpellName(name, classFile) and serviceType ~= "used" then
            local levelReq = 0
            local cost = nil
            if type(GetTrainerServiceLevelReq) == "function" then
                levelReq = GetTrainerServiceLevelReq(index) or 0
            end
            if type(GetTrainerServiceCost) == "function" then
                cost = GetTrainerServiceCost(index)
            end

            table.insert(cached, {
                name = name,
                rankText = subText,
                level = levelReq > 0 and levelReq or UnitLevel("player") or 1,
                costCopper = cost,
                serviceType = serviceType,
                scannedAt = ns:Now(),
            })
        end
    end

    if #cached > 0 then
        table.sort(cached, function(left, right)
            if (left.level or 0) == (right.level or 0) then
                return spellLabel(left) < spellLabel(right)
            end
            return (left.level or 0) < (right.level or 0)
        end)

        local db = ns.Database:GetDB()
        db.trainerCache.classSpells[classFile] = cached
    end
end

function Reminders:ClassSpellReminder(row, status, cached)
    local label = spellLabel(row)
    local detail
    if status == "due" then
        detail = "Train now at level " .. tostring(row.level or "?") .. "."
    else
        detail = "Available at level " .. tostring(row.level or "?") .. "."
    end
    if cached then
        detail = detail .. " Cached from your trainer."
    end

    return {
        kind = "class",
        id = "class-" .. label,
        title = label,
        detail = detail,
        status = status,
    }
end

function Reminders:AddClassReminders(list, level)
    local _, classFile = UnitClass("player")
    local db = ns.Database and ns.Database:GetDB()
    local cachedRows = db and db.trainerCache and db.trainerCache.classSpells and db.trainerCache.classSpells[classFile]
    local rows = cachedRows
    local cached = true

    if not rows or #rows == 0 then
        rows = ns.TrainingData.classSpells and ns.TrainingData.classSpells[classFile]
        cached = false
    end

    if not rows then
        return
    end

    for _, row in ipairs(rows) do
        local rowLevel = row.level or 1
        if rowLevel <= level and rowLevel >= level - 4 and not self:PlayerKnowsSpell(row) then
            table.insert(list.due, self:ClassSpellReminder(row, "due", cached))
        elseif rowLevel > level and rowLevel <= level + 2 then
            table.insert(list.upcoming, self:ClassSpellReminder(row, "upcoming", cached))
        end
    end
end

function Reminders:ProfessionUnlockReminder()
    return {
        kind = "profession",
        id = "primary-professions-unlocked",
        title = "Primary professions unlocked",
        detail = "You can now learn up to two primary professions. Pick routes that support your Hardcore plan, such as Mining/Engineering, Herbalism/Alchemy, or Skinning/Leatherworking.",
        cost = "Trainer cost is usually modest at Apprentice rank",
        status = "due",
    }
end

function Reminders:SecondaryLearnReminder(name, data, status)
    local detail = data.detail or "Secondary skills are optional, but they are useful on Hardcore characters."
    if status == "upcoming" then
        detail = detail .. " Available at level " .. tostring(data.learnLevel or 5) .. "."
    end

    return {
        kind = "profession",
        id = "learn-secondary-" .. name,
        title = "Learn " .. name,
        detail = detail,
        where = data.where,
        cost = costText(data),
        status = status,
    }
end

function Reminders:ProfessionRankReminder(skillName, skill, row, status)
    local detail
    if status == "due" then
        detail = "Your " .. skillName .. " is " .. tostring(skill.rank or 0) .. "/" .. tostring(skill.maxRank or 0) .. "; train " .. row.rank .. " to raise the cap."
    else
        detail = "Your " .. skillName .. " is " .. tostring(skill.rank or 0) .. "/" .. tostring(skill.maxRank or 0) .. "; " .. row.rank .. " is coming soon."
    end

    return {
        kind = "profession",
        id = "profession-" .. skillName .. "-" .. row.rank,
        title = skillName .. " - " .. row.rank,
        detail = detail,
        where = row.where,
        cost = costText(row),
        status = status,
    }
end

function Reminders:GetProfessionRankRows(skillName, skill)
    if skill.category == "secondary" then
        return ns.TrainingData.professionRanks and ns.TrainingData.professionRanks[skillName]
    end
    if skill.category == "primary" then
        return (ns.TrainingData.professionRanks and ns.TrainingData.professionRanks[skillName]) or ns.TrainingData.professionRanks.DEFAULT
    end
    return nil
end

function Reminders:GetDueProfessionRank(skillName, skill, level)
    local rows = self:GetProfessionRankRows(skillName, skill)
    for _, row in ipairs(rows or {}) do
        local capOK = not row.requiredCap or (skill.maxRank or 0) <= row.requiredCap
        local levelOK = not row.requiredLevel or level >= row.requiredLevel
        local alreadyPast = row.targetCap and (skill.maxRank or 0) >= row.targetCap
        local canTrain = capOK and levelOK and not alreadyPast and (skill.rank or 0) >= (row.requiredSkill or 0)
        if canTrain then
            return row
        end
    end
    return nil
end

function Reminders:AddProfessionReminders(list, level, snapshot)
    if level >= 5 and snapshot.primaryCount == 0 then
        table.insert(list.due, self:ProfessionUnlockReminder())
    elseif level == 4 and snapshot.primaryCount == 0 then
        table.insert(list.upcoming, self:ProfessionUnlockReminder())
    end

    for name, data in pairs(ns.TrainingData.secondarySkills or {}) do
        local learnLevel = data.learnLevel or 5
        if not snapshot.skills[name] then
            if level >= learnLevel then
                table.insert(list.due, self:SecondaryLearnReminder(name, data, "due"))
            elseif level + 1 >= learnLevel then
                table.insert(list.upcoming, self:SecondaryLearnReminder(name, data, "upcoming"))
            end
        end
    end

    for skillName, skill in pairs(snapshot.skills) do
        local rows = self:GetProfessionRankRows(skillName, skill)
        for _, row in ipairs(rows or {}) do
            local capOK = not row.requiredCap or (skill.maxRank or 0) <= row.requiredCap
            local levelOK = not row.requiredLevel or level >= row.requiredLevel
            local alreadyPast = row.targetCap and (skill.maxRank or 0) >= row.targetCap
            local canTrain = capOK and levelOK and not alreadyPast and (skill.rank or 0) >= (row.requiredSkill or 0)
            local upcoming = capOK and not alreadyPast and (skill.rank or 0) >= (row.upcomingSkill or row.requiredSkill or 0)

            if canTrain then
                table.insert(list.due, self:ProfessionRankReminder(skillName, skill, row, "due"))
            elseif upcoming then
                table.insert(list.upcoming, self:ProfessionRankReminder(skillName, skill, row, "upcoming"))
            end
        end
    end
end

function Reminders:BuildList(level, snapshot)
    local list = { due = {}, upcoming = {} }
    level = level or UnitLevel("player") or 1
    snapshot = snapshot or self:GetSkillSnapshot()

    self:AddClassReminders(list, level)
    self:AddProfessionReminders(list, level, snapshot)

    return list
end

function Reminders:PrintChatItem(prefix, item)
    local message = prefix .. ": " .. item.title .. " - " .. tostring(item.detail or "")
    if item.kind ~= "class" and item.cost then
        message = message .. " Cost: " .. tostring(item.cost)
    end
    ns:Print(message)
end

function Reminders:PrintLevelUpReminders(newLevel)
    if not ns.Database then
        return
    end

    local db = ns.Database:GetDB()
    if not db.settings.notifyTrainingReminders then
        return
    end

    local level = tonumber(newLevel) or UnitLevel("player") or 1
    local snapshot = self.lastSkillSnapshot or self:GetSkillSnapshot()
    local list = self:BuildList(level, snapshot)

    for _, item in ipairs(list.due) do
        self:PrintChatItem("DUE", item)
    end
    for _, item in ipairs(list.upcoming) do
        self:PrintChatItem("UPCOMING", item)
    end
end

function Reminders:AnnounceProfessionSkillGain(skillName, skill)
    if not ns.Database then
        return
    end

    local db = ns.Database:GetDB()
    if not db.settings.notifyTrainingReminders then
        return
    end

    local level = UnitLevel("player") or 1
    local row = self:GetDueProfessionRank(skillName, skill, level)
    if not row then
        return
    end

    local rank = skill.rank or 0
    local maxRank = skill.maxRank or 0
    local remaining = maxRank - rank
    if maxRank > 0 and remaining <= 5 then
        ns:PrintAlert(skillName .. " " .. tostring(rank) .. "/" .. tostring(maxRank) .. " - train " .. row.rank .. " now before you cap")
    else
        ns:Print(skillName .. " " .. tostring(rank) .. "/" .. tostring(maxRank) .. " - train " .. row.rank .. " to raise the cap.")
    end
end

function Reminders:PrintGroup(title, items)
    if #items == 0 then
        return
    end

    ns:Print(title)
    for _, item in ipairs(items) do
        ns:Print(item.title .. " - " .. item.detail)
        if item.where then
            ns:Print("Where: " .. tostring(item.where))
        end
        if item.kind ~= "class" and item.cost then
            ns:Print("Cost: " .. tostring(item.cost))
        end
    end
end

function Reminders:PrintReminders()
    local snapshot = self:GetSkillSnapshot()
    self:ScanSkills(snapshot)
    self.lastSkillSnapshot = snapshot
    local list = self:BuildList(UnitLevel("player") or 1, snapshot)

    if #list.due == 0 and #list.upcoming == 0 then
        ns:Print("No training reminders right now.")
        return
    end

    self:PrintGroup("Due now:", list.due)
    self:PrintGroup("Upcoming:", list.upcoming)
end
