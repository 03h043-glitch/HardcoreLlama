local _, ns = ...

local DungeonBossXP = ns:RegisterModule("DungeonBossXP", {})
ns.DungeonBossXP = DungeonBossXP

local UI = ns.UI

local C = {
    title = "|cffffd100",
    accent = "|cff33ff99",
    xp = "|cff69ccf0",
    white = "|cffffffff",
    muted = "|cff9d9d9d",
    dim = "|cff666666",
    warning = "|cffffb347",
    reset = "|r",
}

local GROUP_MODIFIER = {
    [1] = 1.0,
    [2] = 1.0,
    [3] = 1.166,
    [4] = 1.3,
    [5] = 1.4,
}

local DUNGEONS = {
    rfc = {
        name = "Ragefire Chasm",
        aliases = { "ragefire", "ragefirechasm" },
        bosses = {
            { name = "Oggleflint", level = 16 },
            { name = "Taragaman the Hungerer", level = 16 },
            { name = "Jergosh the Invoker", level = 16 },
            { name = "Bazzalan", level = 16 },
        },
    },
    wc = {
        name = "Wailing Caverns",
        aliases = { "wailing", "wailingcaverns" },
        bosses = {
            { name = "Lady Anacondra", level = 20 },
            { name = "Kresh", level = 20 },
            { name = "Lord Cobrahn", level = 20 },
            { name = "Lord Pythas", level = 21 },
            { name = "Skum", level = 21 },
            { name = "Lord Serpentis", level = 21 },
            { name = "Verdan the Everliving", level = 21 },
            { name = "Mutanus the Devourer", level = 22 },
        },
    },
    dm = {
        name = "The Deadmines",
        aliases = { "deadmines", "vc" },
        bosses = {
            { name = "Rhahk'Zor", level = 19 },
            { name = "Sneed's Shredder", level = 20 },
            { name = "Sneed", level = 20 },
            { name = "Gilnid", level = 20 },
            { name = "Mr. Smite", level = 20 },
            { name = "Captain Greenskin", level = 20 },
            { name = "Edwin VanCleef", level = 21 },
            { name = "Cookie", level = 20 },
        },
    },
    sfk = {
        name = "Shadowfang Keep",
        aliases = { "shadowfang", "shadowfangkeep" },
        bosses = {
            { name = "Rethilgore", level = 20 },
            { name = "Razorclaw the Butcher", level = 22 },
            { name = "Baron Silverlaine", level = 24 },
            { name = "Commander Springvale", level = 24 },
            { name = "Odo the Blindwatcher", level = 24 },
            { name = "Deathsworn Captain", level = 25, note = "rare" },
            { name = "Fenrus the Devourer", level = 25 },
            { name = "Wolf Master Nandos", level = 25 },
            { name = "Archmage Arugal", level = 26 },
        },
    },
    bfd = {
        name = "Blackfathom Deeps",
        aliases = { "blackfathom", "blackfathomdeeps" },
        bosses = {
            { name = "Ghamoo-ra", level = 25 },
            { name = "Lady Sarevess", level = 25 },
            { name = "Gelihast", level = 25 },
            { name = "Lorgus Jett", level = 26 },
            { name = "Baron Aquanis", level = 28, note = "summoned" },
            { name = "Twilight Lord Kelris", level = 27 },
            { name = "Aku'mai", level = 28 },
        },
    },
    stocks = {
        name = "The Stockade",
        aliases = { "stockade", "stockades" },
        bosses = {
            { name = "Targorr the Dread", level = 24 },
            { name = "Dextren Ward", level = 26 },
            { name = "Kam Deepfury", level = 27 },
            { name = "Hamhock", level = 28 },
            { name = "Bazil Thredd", level = 29 },
            { name = "Bruegal Ironknuckle", level = 26, note = "rare" },
        },
    },
    gnomer = {
        name = "Gnomeregan",
        aliases = { "gnomeregan", "gnome" },
        bosses = {
            { name = "Grubbis", level = 32 },
            { name = "Viscous Fallout", level = 30 },
            { name = "Electrocutioner 6000", level = 32 },
            { name = "Crowd Pummeler 9-60", level = 32 },
            { name = "Mekgineer Thermaplugg", level = 34 },
        },
    },
    rfk = {
        name = "Razorfen Kraul",
        aliases = { "razorfenkraul" },
        bosses = {
            { name = "Roogug", level = 28 },
            { name = "Aggem Thorncurse", level = 30 },
            { name = "Death Speaker Jargba", level = 30 },
            { name = "Overlord Ramtusk", level = 32 },
            { name = "Agathelos the Raging", level = 33 },
            { name = "Charlga Razorflank", level = 33 },
            { name = "Blind Hunter", level = 32, note = "rare" },
            { name = "Earthcaller Halmgar", level = 32, note = "rare" },
        },
    },
    smgy = {
        name = "Scarlet Monastery: Graveyard",
        aliases = { "smg", "smgy", "graveyard" },
        bosses = {
            { name = "Interrogator Vishas", level = 32 },
            { name = "Bloodmage Thalnos", level = 34 },
            { name = "Azshir the Sleepless", level = 33, note = "rare" },
            { name = "Fallen Champion", level = 33, note = "rare" },
            { name = "Ironspine", level = 33, note = "rare" },
        },
    },
    smlib = {
        name = "Scarlet Monastery: Library",
        aliases = { "sml", "smlib", "library" },
        bosses = {
            { name = "Houndmaster Loksey", level = 34 },
            { name = "Arcanist Doan", level = 37 },
        },
    },
    smarm = {
        name = "Scarlet Monastery: Armory",
        aliases = { "sma", "smarm", "armory" },
        bosses = {
            { name = "Herod", level = 40 },
        },
    },
    smcath = {
        name = "Scarlet Monastery: Cathedral",
        aliases = { "smc", "smcath", "cath", "cathedral" },
        bosses = {
            { name = "Scarlet Commander Mograine", level = 42 },
            { name = "High Inquisitor Whitemane", level = 42 },
        },
    },
    rfd = {
        name = "Razorfen Downs",
        aliases = { "razorfendowns" },
        bosses = {
            { name = "Tuten'kash", level = 40 },
            { name = "Mordresh Fire Eye", level = 39 },
            { name = "Glutton", level = 40 },
            { name = "Ragglesnout", level = 40, note = "rare" },
            { name = "Amnennar the Coldbringer", level = 41 },
        },
    },
    uld = {
        name = "Uldaman",
        aliases = { "uldaman" },
        bosses = {
            { name = "Revelosh", level = 40 },
            { name = "Ironaya", level = 40 },
            { name = "Obsidian Sentinel", level = 42 },
            { name = "Ancient Stone Keeper", level = 44 },
            { name = "Galgann Firehammer", level = 44 },
            { name = "Grimlok", level = 45 },
            { name = "Archaedas", level = 47 },
        },
    },
    zf = {
        name = "Zul'Farrak",
        aliases = { "zulfarrak", "zul'farrak" },
        bosses = {
            { name = "Antu'sul", level = 48 },
            { name = "Theka the Martyr", level = 45 },
            { name = "Witch Doctor Zum'rah", level = 46 },
            { name = "Nekrum Gutchewer", level = 46 },
            { name = "Shadowpriest Sezz'ziz", level = 47 },
            { name = "Gahz'rilla", level = 46 },
            { name = "Hydromancer Velratha", level = 46 },
            { name = "Chief Ukorz Sandscalp", level = 48 },
            { name = "Ruuzlu", level = 46 },
            { name = "Zerillis", level = 45, note = "rare" },
        },
    },
    mara = {
        name = "Maraudon",
        aliases = { "maraudon" },
        bosses = {
            { name = "Noxxion", level = 48 },
            { name = "Razorlash", level = 48 },
            { name = "Celebras the Cursed", level = 49 },
            { name = "Landslide", level = 50 },
            { name = "Tinkerer Gizlock", level = 50 },
            { name = "Rotgrip", level = 50 },
            { name = "Princess Theradras", level = 51 },
        },
    },
    st = {
        name = "Sunken Temple",
        aliases = { "sunkentemple", "temple", "atalhakkar", "hakkar" },
        bosses = {
            { name = "Atal'alarion", level = 50 },
            { name = "Dreamscythe", level = 53 },
            { name = "Weaver", level = 53 },
            { name = "Jammal'an the Prophet", level = 53 },
            { name = "Ogom the Wretched", level = 53 },
            { name = "Morphaz", level = 52 },
            { name = "Hazzas", level = 53 },
            { name = "Shade of Eranikus", level = 55 },
        },
    },
}

local function colorText(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function normalizeKey(value)
    value = string.lower(tostring(value or ""))
    return (value:gsub("[^%a%d']", ""))
end

local function sameLevelMobXP(level)
    return (math.floor(tonumber(level) or 1) * 5) + 45
end

local function zeroDifference(level)
    level = math.floor(tonumber(level) or 1)
    if level <= 7 then
        return 5
    elseif level <= 9 then
        return 6
    elseif level <= 11 then
        return 7
    elseif level <= 15 then
        return 8
    elseif level <= 19 then
        return 9
    elseif level <= 29 then
        return 11
    elseif level <= 39 then
        return 12
    elseif level <= 44 then
        return 13
    elseif level <= 49 then
        return 14
    elseif level <= 54 then
        return 15
    elseif level <= 59 then
        return 16
    end
    return 17
end

local function bossBaseXP(bossLevel)
    return sameLevelMobXP(bossLevel) * 2
end

local function soloBossXP(playerLevel, bossLevel)
    playerLevel = math.floor(tonumber(playerLevel) or 1)
    bossLevel = math.floor(tonumber(bossLevel) or 1)

    local xp = sameLevelMobXP(playerLevel)
    if bossLevel > playerLevel then
        xp = xp * (1 + (0.05 * (bossLevel - playerLevel)))
    elseif bossLevel < playerLevel then
        local difference = playerLevel - bossLevel
        local zd = zeroDifference(playerLevel)
        if difference >= zd then
            return 0
        end
        xp = xp * (1 - (difference / zd))
    end

    return math.max(0, math.floor((xp * 2) + 0.5))
end

local function groupShare(levels, playerLevel)
    local count = math.max(1, #levels)
    if count <= 1 then
        return 1
    end

    local sum = 0
    for _, level in ipairs(levels) do
        sum = sum + (tonumber(level) or 0)
    end
    if sum <= 0 then
        return 0
    end

    return (GROUP_MODIFIER[count] or GROUP_MODIFIER[5]) * ((tonumber(playerLevel) or 0) / sum)
end

local function playerBossXP(playerLevel, bossLevel, levels)
    local solo = soloBossXP(playerLevel, bossLevel)
    return math.max(0, math.floor((solo * groupShare(levels, playerLevel)) + 0.5))
end

local function parseLevels(text)
    local levels = {}
    for value in string.gmatch(tostring(text or ""), "%d+") do
        local level = tonumber(value)
        if level and level >= 1 and level <= 60 then
            table.insert(levels, level)
            if #levels >= 5 then
                break
            end
        end
    end
    return levels
end

local function levelsText(levels)
    local parts = {}
    for index, level in ipairs(levels or {}) do
        table.insert(parts, "P" .. tostring(index) .. " L" .. tostring(level))
    end
    return table.concat(parts, ", ")
end

function DungeonBossXP:GetDungeon(key)
    key = normalizeKey(key)
    if key == "" then
        key = "sfk"
    end

    if DUNGEONS[key] then
        return key, DUNGEONS[key]
    end

    for dungeonKey, dungeon in pairs(DUNGEONS) do
        for _, alias in ipairs(dungeon.aliases or {}) do
            if normalizeKey(alias) == key then
                return dungeonKey, dungeon
            end
        end
    end
    return nil, nil
end

function DungeonBossXP:GetSettings()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        return { dungeon = "sfk", levels = { UnitLevel and UnitLevel("player") or 30 } }
    end

    db.settings.dungeonBossXP = db.settings.dungeonBossXP or {}
    local settings = db.settings.dungeonBossXP
    settings.dungeon = settings.dungeon or "sfk"
    settings.levels = settings.levels or { UnitLevel and UnitLevel("player") or 30 }
    return settings
end

function DungeonBossXP:SetScenario(dungeonKey, levels)
    local key, dungeon = self:GetDungeon(dungeonKey)
    if not dungeon then
        ns:Print("Unknown dungeon for boss XP: " .. tostring(dungeonKey or ""))
        return false
    end

    if not levels or #levels == 0 then
        levels = { UnitLevel and UnitLevel("player") or 1 }
    end

    local settings = self:GetSettings()
    settings.dungeon = key
    settings.levels = levels
    return true
end

function DungeonBossXP:EstimateDungeon(dungeon, levels)
    local rows = {}
    local totals = {}
    for index = 1, #levels do
        totals[index] = 0
    end

    for _, boss in ipairs(dungeon.bosses or {}) do
        local row = {
            boss = boss,
            baseXP = bossBaseXP(boss.level),
            playerXP = {},
        }
        for index, level in ipairs(levels) do
            local xp = playerBossXP(level, boss.level, levels)
            row.playerXP[index] = xp
            totals[index] = totals[index] + xp
        end
        table.insert(rows, row)
    end

    return rows, totals
end

function DungeonBossXP:BuildScenarioLines(lines, title, dungeonKey, levels)
    local key, dungeon = self:GetDungeon(dungeonKey)
    if not dungeon then
        table.insert(lines, colorText(C.warning, "Unknown dungeon: " .. tostring(dungeonKey)))
        return
    end

    local rows, totals = self:EstimateDungeon(dungeon, levels)
    table.insert(lines, "")
    table.insert(lines, colorText(C.title, string.upper(title or dungeon.name)))
    table.insert(lines, colorText(C.dim, "--------------------------------"))
    table.insert(lines, colorText(C.muted, dungeon.name .. "  |  " .. levelsText(levels)))

    for _, row in ipairs(rows) do
        local boss = row.boss
        local suffix = boss.note and colorText(C.dim, "  " .. boss.note) or ""
        table.insert(lines, colorText(C.white, boss.name) .. colorText(C.muted, " L" .. tostring(boss.level) .. " base " .. ns:FormatNumber(row.baseXP)) .. suffix)
        local xpParts = {}
        for index, xp in ipairs(row.playerXP) do
            table.insert(xpParts, "P" .. tostring(index) .. " " .. ns:FormatNumber(xp))
        end
        table.insert(lines, colorText(C.xp, "  " .. table.concat(xpParts, "  |  ")))
    end

    local totalParts = {}
    for index, total in ipairs(totals) do
        table.insert(totalParts, "P" .. tostring(index) .. " " .. ns:FormatNumber(total))
    end
    table.insert(lines, colorText(C.accent, "Full boss clear: " .. table.concat(totalParts, "  |  ")))
end

function DungeonBossXP:BuildLines()
    local lines = {}
    local settings = self:GetSettings()
    local key, dungeon = self:GetDungeon(settings.dungeon)
    local levels = settings.levels or { UnitLevel and UnitLevel("player") or 1 }

    table.insert(lines, colorText(C.title, "DUNGEON BOSS XP ESTIMATOR"))
    table.insert(lines, colorText(C.dim, "--------------------------------"))
    table.insert(lines, colorText(C.muted, "Formula estimates Classic elite boss kill XP before rested/quest XP."))
    table.insert(lines, colorText(C.dim, "Commands: /hcl bossxp sfk 30 | /hcl bossxp sfk 30,26,28"))

    if dungeon then
        self:BuildScenarioLines(lines, "Selected", key, levels)
    end

    local currentLevel = UnitLevel and UnitLevel("player") or 30
    if key == "sfk" then
        self:BuildScenarioLines(lines, "SFK Solo Current", "sfk", { currentLevel })
        self:BuildScenarioLines(lines, "SFK 3-Man Example", "sfk", { 30, 26, 28 })
        self:BuildScenarioLines(lines, "SFK Typical 5-Man", "sfk", { 22, 23, 24, 24, 25 })
    end

    return lines
end

function DungeonBossXP:PrintEstimate(dungeonKey, levels)
    local key, dungeon = self:GetDungeon(dungeonKey)
    if not dungeon then
        ns:Print("Unknown dungeon. Try sfk, dm, wc, bfd, gnomer, rfk, smgy, smlib, smarm, smcath, rfd, uld, zf, mara, or st.")
        return
    end

    levels = levels and #levels > 0 and levels or { UnitLevel and UnitLevel("player") or 1 }
    self:SetScenario(key, levels)
    local _, totals = self:EstimateDungeon(dungeon, levels)
    local totalParts = {}
    for index, total in ipairs(totals) do
        table.insert(totalParts, "P" .. tostring(index) .. " " .. ns:FormatNumber(total))
    end
    ns:Print(dungeon.name .. " boss XP estimate for " .. levelsText(levels) .. ": " .. table.concat(totalParts, " | "))

    if ns.UI then
        ns.UI:Show()
        ns.UI:SetView("bossxp")
    end
end

if ns.HandleSlash then
    local previousHandleSlash = ns.HandleSlash
    function ns:HandleSlash(input)
        input = ns.Trim(input)
        local command, rest = input:match("^(%S+)%s*(.-)$")
        command = string.lower(command or "")
        rest = ns.Trim(rest)

        if command == "bossxp" or command == "boss" or command == "bosses" then
            local dungeonKey, levelText = rest:match("^(%S+)%s*(.-)$")
            dungeonKey = dungeonKey or "sfk"
            local levels = parseLevels(levelText)
            if #levels == 0 then
                levels = { UnitLevel and UnitLevel("player") or 1 }
            end
            DungeonBossXP:PrintEstimate(dungeonKey, levels)
            return
        end

        return previousHandleSlash(self, input)
    end
end

if ns.PrintHelp then
    local previousPrintHelp = ns.PrintHelp
    function ns:PrintHelp()
        previousPrintHelp(self)
        self:Print("/hcl bossxp [dungeon] [levels] - estimate boss XP, e.g. /hcl bossxp sfk 30,26,28")
    end
end

if UI then
    local previousBuildFrame = UI.BuildFrame
    function UI:BuildFrame()
        local frame = previousBuildFrame(self)
        if frame.bossXPButton then
            return frame
        end

        frame.bossXPButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.bossXPButton:SetSize(72, 22)
        frame.bossXPButton:SetText("Boss XP")
        frame.bossXPButton:SetPoint("RIGHT", frame.refreshButton, "LEFT", -6, 0)
        frame.bossXPButton:SetScript("OnClick", function()
            ns.UI:SetView("bossxp")
        end)
        return frame
    end

    local previousRefresh = UI.Refresh
    function UI:Refresh()
        if self.frame and self.view == "bossxp" then
            self:SetLines(DungeonBossXP:BuildLines(), {})
            if self.UpdateInfoControls then
                self:UpdateInfoControls()
            end
            if self.UpdateGrindControls then
                self:UpdateGrindControls()
            end
            if self.UpdateGrindTierControls then
                self:UpdateGrindTierControls()
            end
            if self.UpdateGrindRemovalControls then
                self:UpdateGrindRemovalControls()
            end
            return
        end
        return previousRefresh(self)
    end
end
