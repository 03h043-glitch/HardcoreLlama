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
    return "Varies"
end

function Reminders:OnInitialize()
    ns:RegisterEvent("PLAYER_LEVEL_UP", self, "OnReminderEvent")
    ns:RegisterEvent("SKILL_LINES_CHANGED", self, "OnReminderEvent")
end

function Reminders:OnPlayerLogin()
    self.notifiedLogin = false
    self:ScanSkills()

    local function notify()
        if ns.Reminders then
            ns.Reminders:NotifyDue()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(4, notify)
    else
        notify()
    end
end

function Reminders:OnReminderEvent()
    self:ScanSkills()
    self:NotifyDue(true)
    ns:MaybeRefreshUI()
end

function Reminders:GetSkill(skillName)
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return nil
    end

    for index = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(index)
        if name == skillName and not isHeader then
            return { name = name, rank = rank or 0, maxRank = maxRank or 0 }
        end
    end

    return nil
end

function Reminders:ScanSkills()
    if not ns.Database then
        return
    end

    local firstAid = self:GetSkill("First Aid")
    if firstAid then
        ns.Database:RecordProfession("First Aid", firstAid.rank, firstAid.maxRank)
    end
end

function Reminders:ClassReminder(status, level)
    local _, classFile = UnitClass("player")
    local data = ns.TrainingData.classTraining[classFile or "DEFAULT"] or ns.TrainingData.classTraining.DEFAULT
    local targetLevel = level
    local detail

    if status == "due" then
        detail = "Level " .. tostring(targetLevel) .. " class training is available."
    else
        detail = "Level " .. tostring(targetLevel) .. " class training is coming soon."
    end

    return {
        id = "class-training-" .. tostring(targetLevel),
        title = data.title or "Class training available",
        detail = detail,
        where = data.where or ns.TrainingData.classTraining.DEFAULT.where,
        cost = data.cost or ns.TrainingData.classTraining.DEFAULT.cost,
        status = status,
    }
end

function Reminders:FirstAidReminder(row, status, skill)
    local detail = row.details or "Recommended First Aid training is available."
    if skill then
        detail = detail .. " Current First Aid: " .. tostring(skill.rank or 0) .. "/" .. tostring(skill.maxRank or 0) .. "."
    end

    return {
        id = row.id,
        title = row.title,
        detail = detail,
        where = row.where,
        cost = costText(row),
        status = status,
    }
end

function Reminders:BuildList()
    local list = { due = {}, upcoming = {} }
    local level = UnitLevel("player") or 1

    if level >= 2 and level <= 60 then
        if level % 2 == 0 then
            table.insert(list.due, self:ClassReminder("due", level))
        elseif level < 60 then
            table.insert(list.upcoming, self:ClassReminder("upcoming", level + 1))
        end
    end

    local firstAid = self:GetSkill("First Aid")
    if not firstAid then
        for _, row in ipairs(ns.TrainingData.firstAid) do
            if row.learnIfMissing then
                local requiredLevel = row.requiredLevel or 1
                if level >= requiredLevel then
                    table.insert(list.due, self:FirstAidReminder(row, "due", nil))
                elseif level + 2 >= requiredLevel then
                    table.insert(list.upcoming, self:FirstAidReminder(row, "upcoming", nil))
                end
                break
            end
        end
        return list
    end

    for _, row in ipairs(ns.TrainingData.firstAid) do
        if not row.learnIfMissing then
            local capOK = not row.requiredCap or (firstAid.maxRank or 0) <= row.requiredCap
            local levelOK = not row.requiredLevel or level >= row.requiredLevel
            local canTrain = capOK and levelOK and firstAid.rank >= (row.requiredSkill or 0)
            local upcoming = capOK and firstAid.rank >= (row.upcomingSkill or row.requiredSkill or 0)

            if row.targetCap and firstAid.maxRank >= row.targetCap then
                canTrain = false
                upcoming = false
            end

            if canTrain then
                table.insert(list.due, self:FirstAidReminder(row, "due", firstAid))
            elseif upcoming then
                table.insert(list.upcoming, self:FirstAidReminder(row, "upcoming", firstAid))
            end
        end
    end

    return list
end

function Reminders:NotifyDue(force)
    if not ns.Database then
        return
    end

    local db = ns.Database:GetDB()
    if not db.settings.notifyTrainingReminders then
        return
    end
    if self.notifiedLogin and not force then
        return
    end

    local list = self:BuildList()
    if #list.due > 0 then
        ns:Print("Training reminders available. Type /hcl reminders for details.")
        for index = 1, math.min(3, #list.due) do
            ns:Print(list.due[index].title .. " - " .. list.due[index].where .. " Cost: " .. list.due[index].cost)
        end
    end

    self.notifiedLogin = true
end

function Reminders:PrintGroup(title, items)
    if #items == 0 then
        return
    end

    ns:Print(title)
    for _, item in ipairs(items) do
        ns:Print(item.title .. " - " .. item.detail)
        ns:Print("Where: " .. tostring(item.where) .. " Cost: " .. tostring(item.cost))
    end
end

function Reminders:PrintReminders()
    self:ScanSkills()
    local list = self:BuildList()

    if #list.due == 0 and #list.upcoming == 0 then
        ns:Print("No training reminders right now.")
        return
    end

    self:PrintGroup("Due now:", list.due)
    self:PrintGroup("Upcoming:", list.upcoming)
end
