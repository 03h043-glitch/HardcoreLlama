local _, ns = ...

local Reminders = ns.Reminders
if not Reminders then
    return
end

local originalBuildList = Reminders.BuildList

local function defenseSkill()
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return nil
    end

    for index = 1, GetNumSkillLines() do
        local name, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(index)
        if name == "Defense" and not isHeader then
            return tonumber(rank) or 0, tonumber(maxRank) or 0
        end
    end

    return nil
end

function Reminders:ProfessionBehindReminder(skillName, skill, level)
    local maxRank = tonumber(skill.maxRank) or 0
    local target = math.max(0, (tonumber(level) or 1) * 5)
    if maxRank > 0 then
        target = math.min(target, maxRank)
    end

    return {
        kind = "profession",
        id = "profession-behind-" .. tostring(skillName),
        title = tostring(skillName) .. " is falling behind",
        detail = tostring(skill.rank or 0) .. "/" .. tostring(skill.maxRank or 0) .. " skill. Aim for " .. tostring(target) .. " at level " .. tostring(level) .. ".",
        status = "due",
    }
end

function Reminders:DefenseBehindReminder(rank, maxRank)
    return {
        kind = "class",
        id = "defense-behind",
        title = "Defense skill is falling behind",
        detail = "Defense is " .. tostring(rank or 0) .. "/" .. tostring(maxRank or 0) .. ". Get hit by safe green mobs until you are within 5 of cap.",
        status = "due",
    }
end

function Reminders:AddSkillProgressReminders(list, level, snapshot)
    snapshot = snapshot or self:GetSkillSnapshot()
    level = tonumber(level) or UnitLevel("player") or 1
    local target = level * 5

    for skillName, skill in pairs(snapshot.skills or {}) do
        if skill.category == "primary" or skill.category == "secondary" then
            local cap = tonumber(skill.maxRank) or 0
            local expected = cap > 0 and math.min(target, cap) or target
            if (tonumber(skill.rank) or 0) < expected then
                table.insert(list.due, self:ProfessionBehindReminder(skillName, skill, level))
            end
        end
    end

    local _, classFile = UnitClass("player")
    if classFile == "ROGUE" or classFile == "WARRIOR" then
        local rank, maxRank = defenseSkill()
        if rank and maxRank and maxRank - rank > 5 then
            table.insert(list.due, self:DefenseBehindReminder(rank, maxRank))
        end
    end
end

function Reminders:BuildList(level, snapshot)
    local list = originalBuildList(self, level, snapshot)
    self:AddSkillProgressReminders(list, level or UnitLevel("player") or 1, snapshot or self:GetSkillSnapshot())
    return list
end
