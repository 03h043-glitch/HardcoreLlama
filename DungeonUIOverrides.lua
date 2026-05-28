local _, ns = ...

local UI = ns.UI
if not UI then
    return
end

local C = {
    accent = "|cff33ff99",
    muted = "|cff9d9d9d",
    title = "|cffffd100",
    reset = "|r",
}

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function classText(className, classFile)
    if ns.ClassColorize then
        return ns:ClassColorize(className, classFile)
    end
    return tostring(className or classFile or "Unknown")
end

function UI:DungeonSummaryLine(run)
    return color(C.muted, "  ") .. classText(run.class, run.classFile) .. color(C.muted, " L" .. tostring(run.levelStart) .. "  |  " .. ns:FormatNumber(run.xpGained or 0) .. " XP  |  " .. ns:FormatNumber(run.xpPerHour or 0) .. " XP/hour  |  " .. ns:FormatMoney(run.totalValueCopper or 0))
end

function UI:AddDungeonRun(lines, hoverRows, run, prefix)
    local lineIndex = #lines + 1
    table.insert(lines, (prefix or "") .. color(C.accent, tostring(run.name or "Dungeon")))
    table.insert(lines, self:DungeonSummaryLine(run))
    table.insert(hoverRows, {
        line = lineIndex,
        title = tostring(run.name or "Dungeon") .. " - Including Quests",
        lines = ns.Dungeons and ns.Dungeons:BuildTooltipLines(run) or {},
    })
end
