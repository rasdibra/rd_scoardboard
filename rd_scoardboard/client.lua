local isOpen = false
local lastToggle = 0

local function nowMs()
    return GetGameTimer()
end

local function SendOpenMessage()
    local selectedLanguage = Config.Language or 'albanian'
    local selectedLocale = (Locales and Locales[selectedLanguage]) or (Locales and Locales['albanian']) or {}
    SendNUIMessage({
        action = 'open',
        language = selectedLanguage,
        locale = selectedLocale,
        serverName = Config.ServerName,
        playersPerPage = Config.PlayersPerPage,
        refreshMs = Config.RefreshMs,
        showJobs = Config.ShowJobs,
        showPing = Config.ShowPing,
        showDiscord = Config.ShowDiscord,
        showPlaytime = Config.ShowPlaytime
    })
end

local function OpenScoreboard()
    if isOpen then return end
    isOpen = true

    -- UI hapet direkt te faqet e lojtarëve. Lista kërkohet nga NUI menjëherë
    -- dhe rifreskohet automatikisht kur scoreboard është hapur.
    SendOpenMessage()
    SetNuiFocus(true, true)
end

local function CloseScoreboard()
    if not isOpen then return end
    isOpen = false
    SendNUIMessage({ action = 'hide' })
    SetNuiFocus(false, false)
end

local function ToggleScoreboard()
    local t = nowMs()
    if t - lastToggle < (Config.ToggleCooldownMs or 160) then return end
    lastToggle = t

    if isOpen then
        CloseScoreboard()
    else
        OpenScoreboard()
    end
end

RegisterNetEvent('rd_scoardboard:open', function()
    OpenScoreboard()
end)

RegisterNetEvent('rd_scoardboard:receivePlayers', function(payload)
    if not isOpen then return end
    SendNUIMessage({
        action = 'players',
        payload = payload
    })
end)

RegisterCommand(Config.Command, function()
    ToggleScoreboard()
end, false)

RegisterCommand(Config.CommandAlias, function()
    ToggleScoreboard()
end, false)

RegisterCommand(Config.CommandAlias2, function()
    ToggleScoreboard()
end, false)

-- Z HASH: hap/mbyll librin pa RegisterKeyMapping.
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustReleased(0, Config.OpenKeyHash) and not IsPauseMenuActive() then
            ToggleScoreboard()
        end
    end
end)

RegisterNUICallback('close', function(_, cb)
    CloseScoreboard()
    cb({ ok = true })
end)

RegisterNUICallback('requestPlayers', function(_, cb)
    TriggerServerEvent('rd_scoardboard:requestPlayers')
    cb({ ok = true })
end)
