local _, ns = ...

local Info = ns:RegisterModule("Info", {})
ns.Info = Info

local DATA = {
    WARRIOR = {
        label = "Warrior Weapon Progression",
        dualWield = true,
        defaultDualWield = false,
        twohand = {
            { level = 6, name = "Current slow 2H green", where = "Weapon vendors, quest rewards, or Auction House.", note = "Use the highest DPS slow 2H you can safely obtain." },
            { level = 18, name = "Smite's Mighty Hammer", where = "Mr. Smite in The Deadmines.", note = "Strong early dungeon 2H if you have a safe group." },
            { level = 29, name = "Corpsemaker", where = "Overlord Ramtusk in Razorfen Kraul.", note = "Very realistic pre-Whirlwind 2H target." },
            { level = 30, name = "Whirlwind Axe", where = "Warrior class quest chain from the Cyclonian questline.", note = "Excellent if you can get help safely; skip if the risk is not worth it." },
            { level = 37, name = "Ravager", where = "Herod in Scarlet Monastery Armory.", note = "Reliable dungeon upgrade and strong cleave proc." },
            { level = 44, name = "Executioner's Cleaver", where = "BoE world drop or Auction House.", note = "Good AH checkpoint if dungeon drops do not happen." },
            { level = 51, name = "Ice Barbed Spear", where = "Alterac Valley quest reward.", note = "Excellent late leveling 2H if battleground access fits your route." },
        },
        dual = {
            { level = 20, name = "Slow main hand + fast offhand greens", where = "Train Dual Wield, then use weapon vendors, quests, or Auction House.", note = "Only swap from 2H if the 1H pair is actually stronger." },
            { level = 19, name = "Cruel Barb", where = "Edwin VanCleef in The Deadmines.", note = "Great early main hand if available." },
            { level = 30, name = "Sword of Omen / Vanquisher's Sword", where = "Scarlet Monastery or Razorfen Downs quest rewards, depending on faction/route.", note = "Solid midgame 1H choices." },
            { level = 45, name = "Thrash Blade", where = "Maraudon quest reward from Corruption of Earth and Seed.", note = "One of the best leveling 1H targets." },
            { level = 52, name = "Mirah's Song", where = "Scholomance quest chain reward.", note = "Excellent late leveling main hand if you are running endgame dungeons." },
        },
    },

    ROGUE = {
        label = "Rogue Weapon Progression",
        dualWield = true,
        defaultDualWield = true,
        single = {
            { level = 6, name = "Highest DPS 1H green", where = "Weapon vendors, quest rewards, or Auction House.", note = "Main-hand damage matters heavily while leveling." },
            { level = 19, name = "Cruel Barb", where = "Edwin VanCleef in The Deadmines.", note = "Excellent sword main hand for Combat leveling." },
            { level = 21, name = "Stinging Viper", where = "Lord Pythas in Wailing Caverns.", note = "Good dagger route option if you are using dagger skills." },
            { level = 26, name = "Meteor Shard", where = "Shadowfang Keep dungeon drop.", note = "Strong dagger but less predictable than quest rewards." },
            { level = 35, name = "Sword of Omen / Vanquisher's Sword", where = "Scarlet Monastery or Razorfen Downs quest rewards, depending on faction/route.", note = "Good realistic midgame main hand targets." },
            { level = 45, name = "Thrash Blade", where = "Maraudon quest reward from Corruption of Earth and Seed.", note = "High-value main hand that can last a long time." },
        },
        dual = {
            { level = 10, name = "Main hand upgrade + fast offhand", where = "Rogue trainers unlock Dual Wield; fill slots from vendors, quests, or Auction House.", note = "Use your best damage weapon in main hand." },
            { level = 19, name = "Cruel Barb + offhand green", where = "Cruel Barb from The Deadmines, offhand from quest/AH/vendor.", note = "Very strong early dual-wield setup." },
            { level = 24, name = "Wingblade / Stinging Viper pair", where = "Wailing Caverns quest and boss drops.", note = "Efficient if WC fits your route." },
            { level = 35, name = "Sword of Omen / Vanquisher's Sword", where = "Scarlet Monastery or Razorfen Downs quest rewards, depending on faction/route.", note = "Pair with the best offhand you can safely get." },
            { level = 45, name = "Thrash Blade + fast offhand", where = "Maraudon quest reward plus dungeon/AH offhand.", note = "Core late leveling Combat setup." },
        },
    },

    HUNTER = {
        label = "Hunter Weapon Progression",
        dualWield = true,
        defaultDualWield = false,
        always = {
            { level = 10, name = "Best current bow/gun", where = "Class quests, vendors, Auction House, or early dungeon drops.", note = "Ranged weapon DPS is your real weapon upgrade priority." },
            { level = 19, name = "Venomstrike", where = "Lord Serpentis in Wailing Caverns.", note = "Excellent early ranged target if your group can safely run WC." },
            { level = 37, name = "Bow of Searing Arrows", where = "BoE world drop or Auction House.", note = "Great if affordable; do not overpay in Hardcore." },
            { level = 43, name = "Maraudon / Uldaman ranged upgrades", where = "Midgame dungeon drops and quest rewards.", note = "Take any clear ranged DPS upgrade rather than waiting for perfection." },
        },
        twohand = {
            { level = 20, name = "Agility 2H stat stick", where = "Weapon trainer, Auction House, quest rewards, or dungeon drops.", note = "Use 2H if it gives better stats than two 1H weapons." },
            { level = 29, name = "Corpsemaker", where = "Overlord Ramtusk in Razorfen Kraul.", note = "Useful melee stat stick if it does not steal from a melee who needs it." },
            { level = 37, name = "Ravager", where = "Herod in Scarlet Monastery Armory.", note = "Good stats/damage, but ranged weapon still matters more." },
            { level = 51, name = "Ice Barbed Spear", where = "Alterac Valley quest reward.", note = "Very strong late leveling hunter stat stick." },
        },
        dual = {
            { level = 20, name = "Two agility 1H weapons", where = "Train Dual Wield, then use AH, quests, or dungeon drops.", note = "Dual wield is mainly for stats while leveling." },
            { level = 35, name = "Quest sword + agility offhand", where = "Scarlet Monastery/Razorfen Downs quest rewards plus best available offhand.", note = "Use if the combined stats beat your 2H." },
            { level = 45, name = "Thrash Blade + stat offhand", where = "Maraudon quest reward plus AH/dungeon offhand.", note = "Good if uncontested and your ranged slot is already current." },
            { level = 52, name = "Mirah's Song + stat offhand", where = "Scholomance quest chain reward plus late dungeon/AH offhand.", note = "Late-game option, not required for leveling pace." },
        },
    },

    PALADIN = {
        label = "Paladin Weapon Progression",
        twohand = {
            { level = 6, name = "Current slow 2H green", where = "Vendors, quests, or Auction House.", note = "Prioritize weapon DPS for solo leveling." },
            { level = 20, name = "Verigan's Fist", where = "Paladin class quest chain.", note = "Outstanding if you can complete the chain safely." },
            { level = 18, name = "Smite's Mighty Hammer", where = "Mr. Smite in The Deadmines.", note = "Good backup if Verigan's Fist is delayed." },
            { level = 37, name = "Ravager", where = "Herod in Scarlet Monastery Armory.", note = "Strong midgame 2H dungeon target." },
            { level = 44, name = "Executioner's Cleaver or strong 2H green", where = "BoE world drop, Auction House, or dungeon upgrades.", note = "AH greens are often safer than forcing risky farms." },
        },
    },

    SHAMAN = {
        label = "Shaman Weapon Progression",
        twohand = {
            { level = 6, name = "Current slow 1H + shield", where = "Vendors, quests, or Auction House.", note = "Use a shield early for safety unless a 2H path is already trained." },
            { level = 20, name = "Crescent Staff", where = "Wailing Caverns quest reward.", note = "Excellent early 2H option if WC is realistic." },
            { level = 29, name = "Corpsemaker", where = "Overlord Ramtusk in Razorfen Kraul.", note = "Strong Enhancement upgrade if you have 2H weapon talents." },
            { level = 37, name = "Ravager", where = "Herod in Scarlet Monastery Armory.", note = "Good dungeon target for 2H Enhancement." },
            { level = 44, name = "Strong slow 2H mace/axe green", where = "Auction House, quests, or dungeon drops.", note = "Keep weapon skill and safety in mind before swapping." },
        },
    },

    PRIEST = {
        label = "Priest Wand Progression",
        wand = {
            { level = 5, name = "Lesser Magic Wand", where = "Crafted by Enchanting or bought from the Auction House.", note = "Huge early power spike; get this as soon as realistic." },
            { level = 13, name = "Greater Magic Wand", where = "Crafted by Enchanting or bought from the Auction House.", note = "The most important early wand upgrade." },
            { level = 18, name = "Gravestone Scepter", where = "Blackfathom Deeps quest Blackfathom Villainy.", note = "Excellent wand that can carry many levels." },
            { level = 30, name = "Rod of Sorrow / strong quest wand", where = "Quest rewards or Auction House, depending on faction and route.", note = "Take a safe upgrade if BFD wand is falling behind." },
            { level = 41, name = "Blackbone Wand", where = "Wand vendors when available or Auction House.", note = "Reliable vendor-style checkpoint if dungeon drops are not happening." },
            { level = 50, name = "Late dungeon wand upgrade", where = "Maraudon, Blackrock Depths, Scholomance, or Auction House.", note = "At this point spell power and spirit gear may matter as much as wand DPS." },
        },
    },

    MAGE = {
        label = "Mage Weapon Progression",
        caster = {
            { level = 5, name = "Lesser Magic Wand", where = "Crafted by Enchanting or bought from the Auction House.", note = "Great early damage while mana regenerates." },
            { level = 13, name = "Greater Magic Wand", where = "Crafted by Enchanting or bought from the Auction House.", note = "Reliable early upgrade for all casters." },
            { level = 18, name = "Emberstone Staff / Crescent Staff", where = "The Deadmines or Wailing Caverns quest routes.", note = "Take whichever safe dungeon/quest staff fits your faction and route." },
            { level = 34, name = "Illusionary Rod", where = "Arcanist Doan in Scarlet Monastery Library.", note = "Classic midgame caster staff target." },
            { level = 44, name = "Zum'rah's Vexing Cane", where = "Zul'Farrak dungeon drop.", note = "Good caster staff if your group is safe and level-appropriate." },
        },
    },

    WARLOCK = {
        label = "Warlock Weapon Progression",
        caster = {
            { level = 5, name = "Lesser Magic Wand", where = "Crafted by Enchanting or bought from the Auction House.", note = "Strong early filler damage." },
            { level = 13, name = "Greater Magic Wand", where = "Crafted by Enchanting or bought from the Auction House.", note = "Excellent early wand checkpoint." },
            { level = 18, name = "Emberstone Staff / Crescent Staff", where = "The Deadmines or Wailing Caverns quest routes.", note = "Safe dungeon staff upgrade if available." },
            { level = 34, name = "Illusionary Rod", where = "Arcanist Doan in Scarlet Monastery Library.", note = "Reliable midgame caster weapon." },
            { level = 44, name = "Zum'rah's Vexing Cane", where = "Zul'Farrak dungeon drop.", note = "Solid late leveling staff target." },
        },
    },

    DRUID = {
        label = "Druid Weapon Progression",
        caster = {
            { level = 10, name = "Best stat staff or mace", where = "Quest rewards, vendors, or Auction House.", note = "For Feral, weapon DPS does not drive form damage; stats matter more." },
            { level = 20, name = "Crescent Staff", where = "Wailing Caverns quest reward.", note = "Excellent early all-purpose stat stick." },
            { level = 29, name = "Manual Crowd Pummeler", where = "Crowd Pummeler 9-60 in Gnomeregan.", note = "Powerful on-use for Feral, but farming it repeatedly is optional and risky." },
            { level = 40, name = "Warden Staff", where = "BoE world drop or Auction House.", note = "Great Feral defensive stat stick if affordable." },
            { level = 47, name = "Princess Theradras' Scepter", where = "Princess Theradras in Maraudon.", note = "Strong realistic dungeon target for later leveling." },
        },
    },

    DEFAULT = {
        label = "Weapon Progression",
        caster = {
            { level = 1, name = "Best safe weapon upgrade", where = "Quest rewards, vendors, Auction House, or level-appropriate dungeons.", note = "This class does not have a tuned guide yet." },
        },
    },
}

function Info:GetClassData(classFile)
    classFile = classFile or select(2, UnitClass("player")) or "UNKNOWN"
    return DATA[classFile] or DATA.DEFAULT, classFile
end

function Info:GetSettings()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        return { dualWield = {} }
    end
    db.settings.info = db.settings.info or {}
    db.settings.info.dualWield = db.settings.info.dualWield or {}
    return db.settings.info
end

function Info:CanDualWieldChoice(classFile)
    local data = self:GetClassData(classFile)
    return data and data.dualWield == true
end

function Info:IsDualWield(classFile)
    local data, resolvedClass = self:GetClassData(classFile)
    local settings = self:GetSettings()
    if settings.dualWield[resolvedClass] == nil then
        return data.defaultDualWield == true
    end
    return settings.dualWield[resolvedClass] == true
end

function Info:SetDualWieldChoice(value, classFile)
    local _, resolvedClass = self:GetClassData(classFile)
    local settings = self:GetSettings()
    settings.dualWield[resolvedClass] = value == true
end

function Info:GetMode(data, classFile)
    if self:CanDualWieldChoice(classFile) then
        if self:IsDualWield(classFile) then
            return "dual"
        end
        return data.twohand and "twohand" or "single"
    end

    if data.wand then
        return "wand"
    end
    if data.twohand then
        return "twohand"
    end
    return "caster"
end

function Info:GetRows(data, mode)
    local rows = {}
    for _, row in ipairs(data.always or {}) do
        table.insert(rows, row)
    end
    for _, row in ipairs(data[mode] or data.caster or {}) do
        table.insert(rows, row)
    end
    table.sort(rows, function(left, right)
        return (left.level or 0) < (right.level or 0)
    end)
    return rows
end

function Info:FindTargets(rows, level)
    local current
    local nextRow
    for _, row in ipairs(rows) do
        if (row.level or 0) <= level then
            current = row
        elseif not nextRow then
            nextRow = row
        end
    end
    return current, nextRow
end

function Info:AddRow(lines, row, prefix)
    if not row then
        return
    end
    table.insert(lines, prefix .. "L" .. tostring(row.level or "?") .. "  " .. tostring(row.name))
    table.insert(lines, "  Where: " .. tostring(row.where or "Unknown"))
    if row.note then
        table.insert(lines, "  Note: " .. tostring(row.note))
    end
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
    table.insert(lines, "WEAPON PROGRESSION")
    table.insert(lines, "--------------------------------")
    table.insert(lines, classLabel .. "  Level " .. tostring(level) .. "  " .. modeLabel)
    table.insert(lines, "")

    if current then
        self:AddRow(lines, current, "Target now: ")
    else
        table.insert(lines, "Target now: Use the best safe vendor, quest, or Auction House upgrade available.")
    end

    table.insert(lines, "")
    if nextRow then
        self:AddRow(lines, nextRow, "Next upgrade: ")
    else
        table.insert(lines, "Next upgrade: You are near the end of this rough progression path.")
    end

    table.insert(lines, "")
    table.insert(lines, "UPCOMING PATH")
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

local originalPrintHelp = ns.PrintHelp
function ns:PrintHelp()
    originalPrintHelp(self)
    self:Print("/hcl info - open weapon progression info")
end

local originalHandleSlash = ns.HandleSlash
function ns:HandleSlash(input)
    local command = ns.Trim(input):match("^(%S+)")
    command = string.lower(command or "")
    if command == "info" or command == "weapons" or command == "weapon" then
        self:ShowView("info")
        return
    end
    return originalHandleSlash(self, input)
end
