local addonName, ns = ...

ns.name = addonName
ns.version = "0.1.0"
ns.events = ns.events or {}
ns.modules = ns.modules or {}
ns.unsupportedEvents = ns.unsupportedEvents or {}
ns.frame = ns.frame or CreateFrame("Frame")

local function trim(value)
    value = tostring(value or "")
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

ns.Trim = trim

function ns:RegisterModule(name, module)
    module = module or {}
    module.name = name
    self.modules[name] = module
    return module
end

function ns:RegisterEvent(event, owner, method)
    if type(owner) == "function" then
        method = owner
        owner = nil
    end

    if not self.events[event] then
        local ok = pcall(self.frame.RegisterEvent, self.frame, event)
        if not ok then
            self.unsupportedEvents[event] = true
            return false
        end
        self.events[event] = {}
    end

    table.insert(self.events[event], { owner = owner, method = method })
    return true
end

function ns:ForEachModule(methodName, ...)
    for _, module in pairs(self.modules) do
        local method = module and module[methodName]
        if type(method) == "function" then
            local ok, err = pcall(method, module, ...)
            if not ok then
                self:Print("Error in " .. methodName .. ": " .. tostring(err))
            end
        end
    end
end

ns.frame:SetScript("OnEvent", function(_, event, ...)
    local handlers = ns.events[event]
    if not handlers then
        return
    end

    for _, handler in ipairs(handlers) do
        local method = handler.method
        local owner = handler.owner
        local ok, err

        if type(method) == "function" then
            ok, err = pcall(method, owner, event, ...)
        elseif owner and type(owner[method]) == "function" then
            ok, err = pcall(owner[method], owner, event, ...)
        end

        if ok == false then
            ns:Print("Error handling " .. event .. ": " .. tostring(err))
        end
    end
end)

function ns:Now()
    if type(time) == "function" then
        return time()
    end
    return math.floor(GetTime() or 0)
end

function ns:Print(message)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then
        frame:AddMessage("|cff33ff99HardcoreLlama|r: " .. tostring(message))
    end
end

function ns:FormatNumber(value)
    value = math.floor(tonumber(value) or 0)
    local left, num, right = tostring(value):match("^([^%d]*%d)(%d*)(.-)$")
    if not left then
        return tostring(value)
    end
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function ns:FormatMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    local sign = ""
    if copper < 0 then
        sign = "-"
        copper = math.abs(copper)
    end

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    local parts = {}

    if gold > 0 then
        table.insert(parts, gold .. "g")
    end
    if silver > 0 or gold > 0 then
        table.insert(parts, silver .. "s")
    end
    table.insert(parts, copperOnly .. "c")

    return sign .. table.concat(parts, " ")
end

function ns:FormatDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    if type(SecondsToTime) == "function" then
        return SecondsToTime(seconds, false, false, 2)
    end

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60

    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    if minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    end
    return secs .. "s"
end

function ns:Percent(part, total)
    part = tonumber(part) or 0
    total = tonumber(total) or 0
    if total <= 0 then
        return "0%"
    end
    return string.format("%.1f%%", (part / total) * 100)
end

function ns:MaybeRefreshUI()
    if self.UI and self.UI.frame and self.UI.frame:IsShown() then
        self.UI:Refresh()
    end
end

function ns:PrintHelp()
    self:Print("/hcl - toggle the tracker window")
    self:Print("/hcl stats - print the current character summary")
    self:Print("/hcl reminders - list due and upcoming training")
    self:Print("/hcl font [9-18|up|down|reset] - adjust window text size")
    self:Print("/hcl grind start [name] - start a grind session")
    self:Print("/hcl grind stop - stop and save the active grind session")
    self:Print("/hcl grind status - show active grind-session rates")
    self:Print("/hcl grind best - show the best saved grind sessions by XP/hour")
end

function ns:HandleFontCommand(rest)
    if not self.UI then
        self:Print("UI module is not loaded.")
        return
    end

    rest = trim(rest)
    if rest == "" then
        local settings = self.Database and self.Database:GetDB().settings.ui
        self:Print("window text size is " .. tostring(settings and settings.fontSize or 12) .. ".")
    elseif rest == "up" or rest == "+" then
        self.UI:AdjustFont(1)
    elseif rest == "down" or rest == "-" then
        self.UI:AdjustFont(-1)
    elseif rest == "reset" then
        self.UI:ResetWindow()
    else
        self.UI:SetFontSize(tonumber(rest) or 12)
    end
end

function ns:HandleSlash(input)
    input = trim(input)
    if input == "" then
        if self.UI then
            self.UI:Toggle()
        else
            self:PrintHelp()
        end
        return
    end

    local command, rest = input:match("^(%S+)%s*(.-)$")
    command = string.lower(command or "")
    rest = trim(rest)

    if command == "help" then
        self:PrintHelp()
    elseif command == "stats" then
        if self.Database then
            self.Database:PrintSummary()
        end
    elseif command == "reminders" then
        if self.Reminders then
            self.Reminders:PrintReminders()
        end
    elseif command == "font" or command == "text" then
        self:HandleFontCommand(rest)
    elseif command == "grind" then
        local subCommand, subRest = rest:match("^(%S+)%s*(.-)$")
        subCommand = string.lower(subCommand or "status")
        subRest = trim(subRest)

        if not self.Grinding then
            self:Print("Grinding module is not loaded.")
        elseif subCommand == "start" then
            self.Grinding:Start(subRest)
        elseif subCommand == "stop" then
            self.Grinding:Stop()
        elseif subCommand == "status" then
            self.Grinding:PrintStatus()
        elseif subCommand == "best" then
            self.Grinding:PrintBest()
        else
            self:Print("Unknown grind command. Try /hcl grind start, stop, status, or best.")
        end
    else
        self:Print("Unknown command: " .. command)
        self:PrintHelp()
    end
end

function ns:OnAddonLoaded(event, loadedName)
    if loadedName ~= addonName then
        return
    end

    if self.Database then
        self.Database:Initialize()
    end
    self.addonLoaded = true
    self:ForEachModule("OnInitialize")
end

function ns:OnPlayerLogin()
    if self.Database then
        self.Database:Initialize()
        self.Database:TouchCharacter()
    end

    self.playerLoggedIn = true
    self:ForEachModule("OnPlayerLogin")
    self:Print("loaded. Type /hcl to open the tracker.")
end

function ns:OnPlayerLogout()
    if self.Database then
        self.Database:TouchCharacter()
    end
    self:ForEachModule("OnPlayerLogout")
end

ns:RegisterEvent("ADDON_LOADED", ns, "OnAddonLoaded")
ns:RegisterEvent("PLAYER_LOGIN", ns, "OnPlayerLogin")
ns:RegisterEvent("PLAYER_LOGOUT", ns, "OnPlayerLogout")

SLASH_HARDCORELLAMA1 = "/hcl"
SLASH_HARDCORELLAMA2 = "/hardcorellama"
SlashCmdList.HARDCORELLAMA = function(input)
    ns:HandleSlash(input)
end
