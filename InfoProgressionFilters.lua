local _, ns = ...

local Info = ns.Info
if not Info then
    return
end

local C = {
    accent = "|cff33ff99",
    white = "|cffffffff",
    muted = "|cff9d9d9d",
    warning = "|cffffb347",
    reset = "|r",
}

local SOURCE_FILTERS = {
    { key = "quest", label = "Quest", fullLabel = "Quest" },
    { key = "drop", label = "Drop", fullLabel = "Drop" },
    { key = "vendor", label = "Vend", fullLabel = "Vendor" },
    { key = "auction", label = "AH", fullLabel = "Auction House" },
    { key = "crafted", label = "Craft", fullLabel = "Crafted" },
}

local SOURCE_LABELS = {
    quest = "Quest",
    drop = "Drop",
    vendor = "Vendor",
    auction = "AH",
    crafted = "Crafted",
}

local ROW_META = {
    ["Current slow 2H green"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Smite's Mighty Hammer"] = { itemIDs = { 7230 }, sources = { "drop" } },
    ["Corpsemaker"] = { itemIDs = { 6687 }, sources = { "drop" } },
    ["Whirlwind Axe"] = { itemIDs = { 6975 }, sources = { "quest" }, sourceLabel = "Class Quest" },
    ["Ravager"] = { itemIDs = { 7717 }, sources = { "drop" } },
    ["Executioner's Cleaver"] = { itemIDs = { 13018 }, sources = { "drop", "auction" }, sourceLabel = "Drop/AH" },
    ["Ice Barbed Spear"] = { itemIDs = { 19106 }, sources = { "quest" } },
    ["Slow main hand + fast offhand greens"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Cruel Barb"] = { itemIDs = { 5191 }, sources = { "drop" } },
    ["Sword of Omen / Vanquisher's Sword"] = { itemIDs = { 6802, 10823 }, sources = { "quest" } },
    ["Thrash Blade"] = { itemIDs = { 17705 }, sources = { "quest" } },
    ["Mirah's Song"] = { itemIDs = { 15806 }, sources = { "quest" } },
    ["Highest DPS 1H green"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Stinging Viper"] = { itemIDs = { 6472 }, sources = { "drop" } },
    ["Meteor Shard"] = { itemIDs = { 6220 }, sources = { "drop" } },
    ["Main hand upgrade + fast offhand"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Cruel Barb + offhand green"] = { itemIDs = { 5191 }, sources = { "drop", "vendor", "quest", "auction" }, sourceLabel = "Mixed" },
    ["Wingblade / Stinging Viper pair"] = { itemIDs = { 6504, 6472 }, sources = { "quest", "drop" }, sourceLabel = "Quest/Drop" },
    ["Best current bow/gun"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Venomstrike"] = { itemIDs = { 6469 }, sources = { "drop" } },
    ["Bow of Searing Arrows"] = { itemIDs = { 2825 }, sources = { "drop", "auction" }, sourceLabel = "Drop/AH" },
    ["Maraudon / Uldaman ranged upgrades"] = { sources = { "quest", "drop" }, sourceLabel = "Quest/Drop" },
    ["Agility 2H stat stick"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Two agility 1H weapons"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Quest sword + agility offhand"] = { sources = { "quest", "drop", "auction" }, sourceLabel = "Mixed" },
    ["Thrash Blade + stat offhand"] = { itemIDs = { 17705 }, sources = { "quest", "drop", "auction" }, sourceLabel = "Mixed" },
    ["Mirah's Song + stat offhand"] = { itemIDs = { 15806 }, sources = { "quest", "drop", "auction" }, sourceLabel = "Mixed" },
    ["Verigan's Fist"] = { itemIDs = { 6953 }, sources = { "quest" }, sourceLabel = "Class Quest" },
    ["Current slow 1H + shield"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Crescent Staff"] = { itemIDs = { 6505 }, sources = { "quest" } },
    ["Strong slow 2H mace/axe green"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Lesser Magic Wand"] = { itemIDs = { 11287 }, sources = { "crafted" }, profession = "Enchanting" },
    ["Greater Magic Wand"] = { itemIDs = { 11288 }, sources = { "crafted" }, profession = "Enchanting" },
    ["Gravestone Scepter"] = { itemIDs = { 7001 }, sources = { "quest" } },
    ["Rod of Sorrow / strong quest wand"] = { sources = { "quest", "auction" }, sourceLabel = "Quest/AH" },
    ["Blackbone Wand"] = { itemIDs = { 5239 }, sources = { "vendor", "auction" }, sourceLabel = "Vendor/AH" },
    ["Late dungeon wand upgrade"] = { sources = { "drop", "auction" }, sourceLabel = "Drop/AH" },
    ["Emberstone Staff / Crescent Staff"] = { itemIDs = { 5201, 6505 }, sources = { "drop", "quest" }, sourceLabel = "Drop/Quest" },
    ["Illusionary Rod"] = { itemIDs = { 7713 }, sources = { "drop" } },
    ["Zum'rah's Vexing Cane"] = { itemIDs = { 18082 }, sources = { "drop" } },
    ["Best stat staff or mace"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
    ["Manual Crowd Pummeler"] = { itemIDs = { 9449 }, sources = { "drop" } },
    ["Warden Staff"] = { itemIDs = { 943 }, sources = { "drop", "auction" }, sourceLabel = "Drop/AH" },
    ["Princess Theradras' Scepter"] = { itemIDs = { 17766 }, sources = { "drop" } },
    ["Best safe weapon upgrade"] = { sources = { "vendor", "quest", "drop", "auction" }, sourceLabel = "Any" },
}

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

local function addUnique(list, value)
    if not contains(list, value) then
        table.insert(list, value)
    end
end

local function inferSources(row)
    local text = string.lower(tostring(row.name or "") .. " " .. tostring(row.where or "") .. " " .. tostring(row.note or ""))
    local sources = {}

    if text:find("quest", 1, true) or text:find("reward", 1, true) then
        addUnique(sources, "quest")
    end
    if text:find("drop", 1, true) or text:find("dungeon", 1, true) or text:find("boss", 1, true) then
        addUnique(sources, "drop")
    end
    if text:find("vendor", 1, true) or text:find("trainer", 1, true) then
        addUnique(sources, "vendor")
    end
    if text:find("auction", 1, true) or text:find("boe", 1, true) then
        addUnique(sources, "auction")
    end
    if text:find("crafted", 1, true) or text:find("craft", 1, true) or text:find("enchanting", 1, true) then
        addUnique(sources, "crafted")
    end
    if #sources == 0 then
        addUnique(sources, "drop")
    end

    return sources
end

function Info:GetSourceFilters()
    return SOURCE_FILTERS
end

function Info:GetSourceSettings()
    local settings = self:GetSettings()
    settings.sources = settings.sources or {}
    for _, source in ipairs(SOURCE_FILTERS) do
        if settings.sources[source.key] == nil then
            settings.sources[source.key] = true
        end
    end
    return settings.sources
end

function Info:IsSourceEnabled(source)
    return self:GetSourceSettings()[source] ~= false
end

function Info:SetSourceEnabled(source, enabled)
    if not source then
        return
    end
    self:GetSourceSettings()[source] = enabled == true
end

function Info:HasProfession(professionName)
    if not professionName or professionName == "" then
        return true
    end

    if type(GetNumSkillLines) == "function" and type(GetSkillLineInfo) == "function" then
        for index = 1, GetNumSkillLines() do
            local name, isHeader = GetSkillLineInfo(index)
            if name == professionName and not isHeader then
                return true
            end
        end
    end

    local character = ns.Database and ns.Database:TouchCharacter()
    local professions = character and character.professions
    return professions and professions[professionName] ~= nil
end

function Info:SourceText(sources)
    local labels = {}
    for _, source in ipairs(sources or {}) do
        table.insert(labels, SOURCE_LABELS[source] or tostring(source))
    end
    return table.concat(labels, "/")
end

function Info:ApplyProgressionMetadata(row)
    if not row then
        return nil
    end

    if row.__hclProgressionMetadata then
        return row
    end

    local meta = ROW_META[row.name]
    if meta then
        row.itemIDs = meta.itemIDs or row.itemIDs
        row.sources = meta.sources or row.sources
        row.profession = meta.profession or row.profession
        row.sourceLabel = meta.sourceLabel or row.sourceLabel
    end

    row.sources = row.sources or inferSources(row)
    row.sourceLabel = row.sourceLabel or self:SourceText(row.sources)
    row.__hclProgressionMetadata = true
    return row
end

function Info:HasEnabledSource(row)
    for _, source in ipairs(row.sources or {}) do
        if self:IsSourceEnabled(source) then
            return true
        end
    end
    return false
end

function Info:ShouldIncludeRow(row)
    row = self:ApplyProgressionMetadata(row)
    if not row then
        return false
    end

    if row.profession and not self:HasProfession(row.profession) then
        return false
    end

    return self:HasEnabledSource(row)
end

function Info:GetRows(data, mode)
    local rows = {}
    local function addRow(row)
        if self:ShouldIncludeRow(row) then
            table.insert(rows, row)
        end
    end

    for _, row in ipairs(data.always or {}) do
        addRow(row)
    end
    for _, row in ipairs(data[mode] or data.caster or {}) do
        addRow(row)
    end

    table.sort(rows, function(left, right)
        if (left.level or 0) == (right.level or 0) then
            return tostring(left.name or "") < tostring(right.name or "")
        end
        return (left.level or 0) < (right.level or 0)
    end)
    return rows
end

function Info:GetItemIconTexture(itemID)
    if not itemID then
        return nil
    end

    if type(GetItemIcon) == "function" then
        local icon = GetItemIcon(itemID)
        if icon then
            return icon
        end
    end

    if type(GetItemInfoInstant) == "function" then
        local icon = select(5, GetItemInfoInstant(itemID))
        if icon then
            return icon
        end
    end

    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function Info:IconText(row)
    row = self:ApplyProgressionMetadata(row)
    local itemIDs = row and row.itemIDs
    if not itemIDs or #itemIDs == 0 then
        return ""
    end

    local icons = {}
    for _, itemID in ipairs(itemIDs) do
        local texture = self:GetItemIconTexture(itemID)
        if texture then
            table.insert(icons, "|T" .. tostring(texture) .. ":16:16:0:0|t")
        end
    end

    if #icons == 0 then
        return ""
    end
    return table.concat(icons, "") .. " "
end

function Info:AddRow(lines, row, prefix)
    if not row then
        return
    end

    row = self:ApplyProgressionMetadata(row)
    local sourceText = row.sourceLabel or self:SourceText(row.sources)
    local sourceSuffix = sourceText ~= "" and color(C.muted, " [" .. sourceText .. "]") or ""

    table.insert(lines, prefix .. self:IconText(row) .. "L" .. tostring(row.level or "?") .. "  " .. color(C.white, row.name) .. sourceSuffix)
    table.insert(lines, color(C.muted, "  Where: ") .. tostring(row.where or "Unknown"))
    if row.note then
        table.insert(lines, color(C.muted, "  Note: ") .. tostring(row.note))
    end
    if row.profession then
        table.insert(lines, color(C.muted, "  Requires: ") .. tostring(row.profession) .. " trained.")
    end
end

function Info:GetEnabledSourceSummary()
    local enabled = {}
    for _, source in ipairs(SOURCE_FILTERS) do
        if self:IsSourceEnabled(source.key) then
            table.insert(enabled, source.fullLabel)
        end
    end

    if #enabled == 0 then
        return "None"
    end
    return table.concat(enabled, ", ")
end

function Info:BuildLines()
    local _, classFile = UnitClass("player")
    local level = UnitLevel("player") or 1
    local data = self:GetClassData(classFile)
    local mode = self:GetMode(data, classFile)
    local rows = self:GetRows(data, mode)
    local current, nextRow = self:FindTargets(rows, level)
    local className = select(1, UnitClass("player")) or classFile or "Unknown"
    local classLabel = ns.ClassColorize and ns:ClassColorize(className, classFile) or tostring(className)
    local modeLabel = mode == "dual" and "Dual wield" or mode == "twohand" and "2H" or mode == "wand" and "Wands" or mode == "single" and "Main hand" or "Caster"

    local lines = {}
    table.insert(lines, color(C.accent, "WEAPON PROGRESSION"))
    table.insert(lines, "--------------------------------")
    table.insert(lines, classLabel .. color(C.muted, "  Level ") .. color(C.white, level) .. color(C.muted, "  " .. modeLabel))
    table.insert(lines, color(C.muted, "Sources: ") .. self:GetEnabledSourceSummary())
    table.insert(lines, "")

    if #rows == 0 then
        table.insert(lines, color(C.warning, "No weapon rows match the selected sources and trained professions."))
        return lines
    end

    if current then
        self:AddRow(lines, current, "Target now: ")
    else
        table.insert(lines, "Target now: " .. color(C.muted, "No matching option at or below your level."))
    end

    table.insert(lines, "")
    if nextRow then
        self:AddRow(lines, nextRow, "Next upgrade: ")
    else
        table.insert(lines, "Next upgrade: " .. color(C.muted, "You are near the end of this rough progression path."))
    end

    table.insert(lines, "")
    table.insert(lines, color(C.accent, "UPCOMING PATH"))
    table.insert(lines, "--------------------------------")

    local shown = 0
    for _, row in ipairs(rows) do
        if (row.level or 0) >= level - 8 then
            self:AddRow(lines, row, "")
            shown = shown + 1
            if shown >= 6 then
                break
            end
        end
    end

    if shown == 0 then
        for index, row in ipairs(rows) do
            self:AddRow(lines, row, "")
            if index >= 6 then
                break
            end
        end
    end

    return lines
end
