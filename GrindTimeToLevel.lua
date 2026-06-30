local _, ns = ...

local Grinding = ns.Grinding
local UI = ns.UI
local AutoGrindWindow = ns.AutoGrindWindow

local BUFFER_SECONDS = 180

local C = {
    title = "|cffffd100",
    accent = "|cff33ff99",
    xp = "|cff69ccf0",
    value = "|cffffd100",
    combined = "|cffd6a9ff",
    white = "|cffffffff",
    muted = "|cff9d9d9d",
    dim = "|cff666666",
    reset = "|r",
}

local function color(code, text)
    return code .. tostring(text or "") .. C.reset
end

local function parseLootMessage(message)
    message = tostring(message or "")
    local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
    if not itemLink then
        return nil
    end

    local quantity = tonumber(message:match("x(%d+)")) or 1
    local itemID = tonumber(itemLink:match("item:(%d+)"))
    local name = itemLink:match("%[(.-)%]") or itemLink
    local sellPrice = 0
    if type(GetItemInfo) == "function" then
        local value = select(11, GetItemInfo(itemLink))
        sellPrice = tonumber(value) or 0
    end

    return {
        time = ns:Now(),
        id = itemID,
        key = itemID and ("item:" .. tostring(itemID)) or name,
        link = itemLink,
        name = name,
        quantity = quantity,
        vendorCopper = sellPrice * quantity,
    }
end

local function recordLootItem(session, loot)
    if not session or not loot then
        return
    end

    session.lootItems = session.lootItems or {}
    local item = session.lootItems[loot.key]
    if not item then
        item = {
            id = loot.id,
            key = loot.key,
            name = loot.name,
            link = loot.link,
            count = 0,
            vendorCopper = 0,
        }
        session.lootItems[loot.key] = item
    end

    item.name = loot.name or item.name
    item.link = loot.link or item.link
    item.count = (item.count or 0) + (loot.quantity or 1)
    item.vendorCopper = (item.vendorCopper or 0) + (loot.vendorCopper or 0)
end

local function pruneTimedEvents(events, now)
    now = now or ns:Now()
    for index = #(events or {}), 1, -1 do
        if now - (events[index].time or 0) > BUFFER_SECONDS then
            table.remove(events, index)
        end
    end
end

local function ratePerHour(value, duration)
    duration = math.max(1, tonumber(duration) or 0)
    return math.floor((tonumber(value) or 0) * 3600 / duration)
end

local function vendorValue(session)
    if Grinding and Grinding.GetVendorValue then
        return Grinding:GetVendorValue(session)
    end
    return tonumber(session and (session.lootVendorCopper or session.vendorValueCopper) or 0) or 0
end

local function getLevelXP()
    if type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then
        return nil, nil
    end

    local current = math.max(0, tonumber(UnitXP("player")) or 0)
    local maximum = math.max(0, tonumber(UnitXPMax("player")) or 0)
    if maximum <= 0 then
        return nil, nil
    end
    current = math.min(current, maximum)
    return current, maximum
end

local function getTimeToLevel(active)
    local xpPerHour = tonumber(active and active.xpPerHour) or 0
    if xpPerHour <= 0 then
        return nil, nil
    end

    local current, maximum = getLevelXP()
    if not current or not maximum then
        return nil, nil
    end

    local remaining = math.max(0, maximum - current)
    return math.floor((remaining * 3600 / xpPerHour) + 0.5), math.floor((maximum * 3600 / xpPerHour) + 0.5)
end

local function formatTimeToLevel(active)
    local remaining, full = getTimeToLevel(active)
    if not remaining or not full then
        return color(C.muted, "--") .. color(C.dim, "  full level: --")
    end
    return color(C.white, ns:FormatDuration(remaining)) .. color(C.dim, "  full level: " .. ns:FormatDuration(full))
end

local function timeToLevelPlain(active)
    local remaining, full = getTimeToLevel(active)
    if not remaining or not full then
        return "--  full level: --"
    end
    return ns:FormatDuration(remaining) .. "  full level: " .. ns:FormatDuration(full)
end

local function hasDungeonActive()
    return ns.Dungeons and ns.Dungeons.GetActive and ns.Dungeons:GetActive() ~= nil
end

if Grinding then
    function Grinding:RememberAutoStartLoot(loot)
        if not loot then
            return
        end
        self.autoStartLootEvents = self.autoStartLootEvents or {}
        table.insert(self.autoStartLootEvents, loot)
        pruneTimedEvents(self.autoStartLootEvents, loot.time)
    end

    function Grinding:RememberAutoStartMoney(amount)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then
            return
        end
        local now = ns:Now()
        self.autoStartMoneyEvents = self.autoStartMoneyEvents or {}
        table.insert(self.autoStartMoneyEvents, { time = now, copper = amount })
        pruneTimedEvents(self.autoStartMoneyEvents, now)
    end

    function Grinding:ApplyAutoStartBufferedLoot(active)
        if not active then
            return
        end

        local now = ns:Now()
        local startedAt = tonumber(active.startedAt) or (now - BUFFER_SECONDS)
        local lootEvents = self.autoStartLootEvents or {}
        local moneyEvents = self.autoStartMoneyEvents or {}
        local seededVendor = 0
        local seededCoin = 0
        local seededItems = 0

        for _, loot in ipairs(lootEvents) do
            if (loot.time or 0) >= startedAt and (loot.time or 0) <= now then
                if (loot.vendorCopper or 0) > 0 then
                    active.lootVendorCopper = (active.lootVendorCopper or 0) + loot.vendorCopper
                    seededVendor = seededVendor + loot.vendorCopper
                end
                recordLootItem(active, loot)
                seededItems = seededItems + (loot.quantity or 1)
            end
        end

        for _, event in ipairs(moneyEvents) do
            if (event.time or 0) >= startedAt and (event.time or 0) <= now then
                seededCoin = seededCoin + (event.copper or 0)
            end
        end

        active.autoStartSeedVendorCopper = (active.autoStartSeedVendorCopper or 0) + seededVendor
        active.autoStartSeedCoinCopper = (active.autoStartSeedCoinCopper or 0) + seededCoin
        active.autoStartSeedItemCount = (active.autoStartSeedItemCount or 0) + seededItems
        active.coinLootCopper = (active.coinLootCopper or 0) + seededCoin

        pruneTimedEvents(lootEvents, now)
        pruneTimedEvents(moneyEvents, now)
        if self.UpdateRates then
            self:UpdateRates(active)
        end
    end

    local previousOnLootMessage = Grinding.OnLootMessage
    function Grinding:OnLootMessage(event, message)
        if not self:GetActive() and not hasDungeonActive() then
            self:RememberAutoStartLoot(parseLootMessage(message))
            return
        end
        return previousOnLootMessage(self, event, message)
    end

    local previousOnPlayerMoney = Grinding.OnPlayerMoney
    function Grinding:OnPlayerMoney(...)
        if self:GetActive() or hasDungeonActive() then
            return previousOnPlayerMoney(self, ...)
        end

        local currentMoney = GetMoney and GetMoney() or 0
        if not self.lastMoney then
            self.lastMoney = currentMoney
            return
        end

        local delta = currentMoney - self.lastMoney
        self.lastMoney = currentMoney
        if delta > 0 then
            self:RememberAutoStartMoney(delta)
        end
    end

    local previousTryAutoStartFromKill = Grinding.TryAutoStartFromKill
    if previousTryAutoStartFromKill then
        function Grinding:TryAutoStartFromKill(amount, source, restedAmount, context)
            local hadActive = self:GetActive() ~= nil
            local result = previousTryAutoStartFromKill(self, amount, source, restedAmount, context)
            local active = self:GetActive()
            if result and active and not hadActive then
                self:ApplyAutoStartBufferedLoot(active)
                if ns.AutoGrindWindow then
                    ns.AutoGrindWindow:Update(active)
                elseif self.RefreshActiveView then
                    self:RefreshActiveView()
                end
            end
            return result
        end
    end

    local previousBuildStatusLines = Grinding.BuildStatusLines
    function Grinding:BuildStatusLines(active)
        local lines = previousBuildStatusLines(self, active)
        active = active or self:GetActive()
        if active then
            table.insert(lines, 3, "Time to level: " .. timeToLevelPlain(active))
        end
        return lines
    end
end

if UI then
    local previousBuildActiveGrindLines = UI.BuildActiveGrindLines
    if previousBuildActiveGrindLines then
        function UI:BuildActiveGrindLines(active)
            local lines = previousBuildActiveGrindLines(self, active)
            for index, line in ipairs(lines) do
                if tostring(line):find("Vendor", 1, true) then
                    table.insert(lines, index + 1, color(C.muted, string.format("%-13s", "Time to level")) .. formatTimeToLevel(active))
                    return lines
                end
            end
            table.insert(lines, color(C.muted, string.format("%-13s", "Time to level")) .. formatTimeToLevel(active))
            return lines
        end
    end
end

if AutoGrindWindow then
    local previousUpdate = AutoGrindWindow.Update
    function AutoGrindWindow:Update(active)
        previousUpdate(self, active)
        active = active or (Grinding and Grinding:GetActive())
        local frame = self.frame
        if not frame or not active or not frame.metrics or not frame.metrics[6] then
            return
        end

        local metric = frame.metrics[6]
        metric.label:SetText(color(C.dim, "TIME TO LEVEL"))
        metric.value:SetText(formatTimeToLevel(active))
    end
end
