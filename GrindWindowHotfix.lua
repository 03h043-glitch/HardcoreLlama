local _, ns = ...

local Grinding = ns.Grinding
local Dungeons = ns.Dungeons
local AutoGrindWindow = ns.AutoGrindWindow

local function getUISettings()
    local db = ns.Database and ns.Database:GetDB()
    if not db then
        return {}
    end
    db.settings.ui = db.settings.ui or {}
    return db.settings.ui
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

if Grinding then
    function Grinding:OnLootMessage(event, message)
        local active = self:GetActive()
        if not active then
            return
        end

        local loot = parseLootMessage(message)
        if not loot then
            return
        end

        if (loot.vendorCopper or 0) > 0 then
            active.lootVendorCopper = (active.lootVendorCopper or 0) + loot.vendorCopper
        end
        recordLootItem(active, loot)

        if self.MarkActivity then
            self:MarkActivity(active, "loot")
        end
        if self.UpdateRates then
            self:UpdateRates(active)
        end
        if self.RefreshActiveView then
            self:RefreshActiveView()
        else
            ns:MaybeRefreshUI()
        end
    end

    local previousStart = Grinding.Start
    function Grinding:Start(name)
        local alreadyActive = self:GetActive()
        self.suppressNextStartWindow = true
        local result = previousStart(self, name)
        local active = self:GetActive()
        if active and active ~= alreadyActive then
            active.compactWindowStarted = true
        end
        if active and AutoGrindWindow then
            AutoGrindWindow:Show(active)
        end
        return result
    end
end

if Dungeons then
    function Dungeons:OnLootMessage(event, message)
        local active = self:GetActive()
        if not active then
            return
        end

        local loot = parseLootMessage(message)
        if not loot then
            return
        end

        if (loot.vendorCopper or 0) > 0 then
            active.lootVendorCopper = (active.lootVendorCopper or 0) + loot.vendorCopper
        end
        recordLootItem(active, loot)

        if self.UpdateRates then
            self:UpdateRates(active)
        end
        ns:MaybeRefreshUI()
    end
end

if AutoGrindWindow then
    function AutoGrindWindow:SavePosition()
        local frame = self.frame
        if not frame then
            return
        end

        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
        local settings = getUISettings()
        settings.autoGrindWindowPoint = point or "CENTER"
        settings.autoGrindWindowRelativePoint = relativePoint or point or "CENTER"
        settings.autoGrindWindowX = math.floor(tonumber(xOfs) or 0)
        settings.autoGrindWindowY = math.floor(tonumber(yOfs) or 0)
    end

    function AutoGrindWindow:RestorePosition(frame)
        local settings = getUISettings()
        frame:ClearAllPoints()
        frame:SetPoint(
            settings.autoGrindWindowPoint or "CENTER",
            UIParent,
            settings.autoGrindWindowRelativePoint or settings.autoGrindWindowPoint or "CENTER",
            settings.autoGrindWindowX or 0,
            settings.autoGrindWindowY or -120
        )
    end

    local previousBuildFrame = AutoGrindWindow.BuildFrame
    function AutoGrindWindow:BuildFrame()
        local frame = previousBuildFrame(self)
        if not frame.positionMemoryEnabled then
            self:RestorePosition(frame)
            frame:SetScript("OnDragStop", function(owner)
                owner:StopMovingOrSizing()
                AutoGrindWindow:SavePosition()
            end)
            frame.positionMemoryEnabled = true
        end
        return frame
    end
end
