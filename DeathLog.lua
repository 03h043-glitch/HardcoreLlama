local _, ns = ...

local DeathLog = ns:RegisterModule("DeathLog", {})
ns.DeathLog = DeathLog

function DeathLog:OnInitialize()
    ns:RegisterEvent("PLAYER_DEAD", self, "OnPlayerDead")
    ns:RegisterEvent("TIME_PLAYED_MSG", self, "OnTimePlayed")
end

function DeathLog:OnPlayerLogin()
    self.deathRecorded = false
    self.pendingDeathId = nil
end

function DeathLog:OnPlayerDead()
    if self.deathRecorded or not ns.Database then
        return
    end

    local id, record = ns.Database:RecordDeath()
    self.pendingDeathId = id
    self.deathRecorded = true

    if type(RequestTimePlayed) == "function" then
        RequestTimePlayed()
    end

    if record then
        ns:PrintAlert("fallen hero recorded: " .. tostring(record.name) .. " level " .. tostring(record.level) .. " " .. tostring(record.class))
    end
    ns:MaybeRefreshUI()
end

function DeathLog:OnTimePlayed(event, totalTime, levelTime)
    if not self.pendingDeathId or not ns.Database then
        return
    end

    ns.Database:UpdateDeathPlayed(self.pendingDeathId, totalTime, levelTime)
    self.pendingDeathId = nil
    ns:MaybeRefreshUI()
end
