local _, ns = ...

local Grinding = ns.Grinding
if not Grinding then
    return
end

local MIN_COMPLETED_MOBS = 10

local previousOnInitialize = Grinding.OnInitialize or function() end
local previousStop = Grinding.Stop or function() end

local function hasActiveGrind()
    return Grinding:GetActive() ~= nil
end

local function hearthstoneSpellName(...)
    if select("#", ...) == 0 then
        return nil
    end

    local unit = select(1, ...)
    if unit and unit ~= "player" then
        return nil
    end

    for index = 2, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" and type(GetSpellInfo) == "function" then
            local name = GetSpellInfo(value)
            if name and string.find(string.lower(name), "hearthstone", 1, true) then
                return name
            end
        elseif type(value) == "string" and string.find(string.lower(value), "hearthstone", 1, true) then
            return value
        end
    end

    if type(UnitCastingInfo) == "function" then
        local name = UnitCastingInfo("player")
        if name and string.find(string.lower(name), "hearthstone", 1, true) then
            return name
        end
    end

    return nil
end

function Grinding:ShouldDiscardCompletedGrind(active)
    return active ~= nil and (tonumber(active.mobCount) or 0) < MIN_COMPLETED_MOBS
end

function Grinding:DiscardActiveGrind(reason)
    local db = ns.Database and ns.Database:GetDB()
    local active = db and db.activeSession
    if not active then
        return
    end

    if self.UpdateRates then
        self:UpdateRates(active)
    end
    if self.UpdateTopMob then
        self:UpdateTopMob(active)
    end

    active.discarded = true
    active.discardReason = reason or "fewer than 10 mobs"
    active.endedAt = ns:Now()
    active.duration = math.max(1, active.endedAt - (active.startedAt or active.endedAt))
    active.levelEnd = UnitLevel("player") or active.levelStart
    active.zoneEnd = GetZoneText and GetZoneText() or active.zoneStart

    db.activeSession = nil

    if self.SetIdleWatcher then
        self:SetIdleWatcher(false)
    end
    if ns.AutoGrindWindow then
        ns.AutoGrindWindow:Hide()
    end

    local suffix = reason and (" (" .. tostring(reason) .. ")") or ""
    ns:Print("Discarded grind session: fewer than " .. tostring(MIN_COMPLETED_MOBS) .. " mob kills recorded" .. suffix .. ".")
    ns:MaybeRefreshUI()
end

function Grinding:Stop(reason)
    local active = self:GetActive()
    if active and self:ShouldDiscardCompletedGrind(active) then
        return self:DiscardActiveGrind(reason)
    end

    local result = previousStop(self, reason)
    if not self:GetActive() and ns.AutoGrindWindow then
        ns.AutoGrindWindow:Hide()
    end
    return result
end

function Grinding:OnMerchantShow()
    if hasActiveGrind() then
        self:Stop("vendor opened")
    end
end

function Grinding:OnHearthstoneCast(event, ...)
    if hasActiveGrind() and hearthstoneSpellName(...) then
        self:Stop("hearthstone cast")
    end
end

function Grinding:OnInitialize(...)
    previousOnInitialize(self, ...)
    ns:RegisterEvent("MERCHANT_SHOW", self, "OnMerchantShow")
    ns:RegisterEvent("UNIT_SPELLCAST_SENT", self, "OnHearthstoneCast")
    ns:RegisterEvent("UNIT_SPELLCAST_START", self, "OnHearthstoneCast")
    ns:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", self, "OnHearthstoneCast")
end
