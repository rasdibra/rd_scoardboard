local VorpCore = nil
local RedEM = nil

local Playtime = {}
local DiscordCache = {}
local DiscordPending = {}
local SteamAvatarCache = {}
local SteamAvatarPending = {}

-- Cache global: scoreboard nuk ndërton listën e gjithë lojtarëve sa herë dikush shtyp Z.
-- Kjo e bën hapjen/reagimin shumë më të shpejtë dhe ul lag-un në servera me shumë lojtarë.
local CachedPayload = nil
local CachedPayloadAt = 0
local CacheBuilding = false

local function trimString(value, maxLen)
    value = tostring(value or '')
    value = value:gsub('[\r\n\t]', ' ')
    value = value:gsub('%s+', ' ')
    value = value:gsub('^%s*(.-)%s*$', '%1')
    if #value > maxLen then
        value = value:sub(1, maxLen) .. '...'
    end
    return value
end

local function tryLoadFrameworks()
    if GetResourceState('vorp_core') == 'started' then
        if exports and exports.vorp_core then
            local ok, core = pcall(function()
                return exports.vorp_core:GetCore()
            end)
            if ok and core then VorpCore = core end
        end

        if not VorpCore then
            pcall(function()
                TriggerEvent('getCore', function(core)
                    VorpCore = core
                end)
            end)
        end
    end

    if GetResourceState('redem_roleplay') == 'started' then
        pcall(function()
            TriggerEvent('redemrp:getSharedObject', function(obj)
                RedEM = obj
            end)
        end)
    end
end

CreateThread(function()
    Wait(500)
    tryLoadFrameworks()
end)

local function getIdentifiers(src)
    local identifiers = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(src)) do
        identifiers[#identifiers + 1] = identifier
    end
    return identifiers
end

local function findIdentifierByPrefix(src, prefix)
    for _, identifier in ipairs(getIdentifiers(src)) do
        if identifier:sub(1, #prefix) == prefix then
            return identifier
        end
    end
    return nil
end

local function getBestIdentifier(src)
    local priority = (ServerConfig and ServerConfig.IdentifierPriority) or { 'license:', 'steam:', 'discord:', 'fivem:' }
    for _, prefix in ipairs(priority) do
        local identifier = findIdentifierByPrefix(src, prefix)
        if identifier then return identifier end
    end

    local ids = getIdentifiers(src)
    if ids[1] then return ids[1] end
    return ('temporary:%s'):format(src)
end

local function kvpKey(identifier)
    return ('playtime:%s'):format(identifier)
end

local function loadStoredSeconds(identifier)
    local raw = GetResourceKvpString(kvpKey(identifier))
    local value = tonumber(raw)
    if not value or value < 0 then return 0 end
    return math.floor(value)
end

local function setStoredSeconds(identifier, seconds)
    SetResourceKvp(kvpKey(identifier), tostring(math.max(0, math.floor(tonumber(seconds) or 0))))
end

local function ensurePlaytime(src)
    src = tonumber(src)
    if not src then return nil end

    local identifier = getBestIdentifier(src)
    if not Playtime[src] or Playtime[src].identifier ~= identifier then
        Playtime[src] = {
            identifier = identifier,
            baseSeconds = loadStoredSeconds(identifier),
            sessionStarted = os.time()
        }
    end

    return Playtime[src]
end

local function getPlaytimeSeconds(src)
    local data = ensurePlaytime(src)
    if not data then return 0 end

    local onlineSeconds = os.time() - (data.sessionStarted or os.time())
    if onlineSeconds < 0 then onlineSeconds = 0 end
    return math.floor((data.baseSeconds or 0) + onlineSeconds)
end

local function savePlaytime(src, keepSession)
    src = tonumber(src)
    local data = Playtime[src]
    if not data then return end

    local onlineSeconds = os.time() - (data.sessionStarted or os.time())
    if onlineSeconds < 0 then onlineSeconds = 0 end
    local total = math.floor((data.baseSeconds or 0) + onlineSeconds)

    setStoredSeconds(data.identifier, total)

    if keepSession then
        data.baseSeconds = total
        data.sessionStarted = os.time()
    else
        Playtime[src] = nil
    end
end

local function formatPlaytime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)

    if days > 0 then
        return ('%dd %dh %dm'):format(days, hours, minutes)
    end

    if hours > 0 then
        return ('%dh %dm'):format(hours, minutes)
    end

    if minutes > 0 then
        return ('%dm'):format(minutes)
    end

    return '0m'
end

local function normalizeCharacter(character)
    if type(character) ~= 'table' then return nil end

    local first = character.firstname
        or character.firstName
        or character.Firstname
        or character.FirstName
        or character.first_name
        or character.name
        or ''

    local last = character.lastname
        or character.lastName
        or character.Lastname
        or character.LastName
        or character.last_name
        or character.surname
        or ''

    return {
        firstname = trimString(first, 32),
        lastname = trimString(last, 32),
        job = character.job or character.Job or character.jobLabel or character.joblabel or '',
        jobGrade = character.jobGrade or character.grade or character.jobgrade or character.jobGradeLabel or '',
        charIdentifier = character.charIdentifier or character.charidentifier or character.charId or character.charid
    }
end

local function getVorpCharacter(src)
    if not VorpCore then return nil end

    local ok, user = pcall(function()
        if VorpCore.getUser then
            return VorpCore.getUser(src)
        elseif VorpCore.GetUser then
            return VorpCore.GetUser(src)
        end
        return nil
    end)

    if not ok or not user then return nil end

    local character = nil

    -- VORP përdor versione të ndryshme: në disa është table, në disa është function.
    -- Marrim gjithmonë used/current character për source-in aktual, jo emrin e Steam/Game.
    if type(user.getUsedCharacter) == 'table' then
        character = user.getUsedCharacter
    elseif type(user.getUsedCharacter) == 'function' then
        local okChar, char = pcall(function()
            return user.getUsedCharacter()
        end)
        if okChar then character = char end
    elseif type(user.GetUsedCharacter) == 'function' then
        local okChar, char = pcall(function()
            return user.GetUsedCharacter()
        end)
        if okChar then character = char end
    elseif type(user.Character) == 'table' then
        character = user.Character
    elseif type(user.character) == 'table' then
        character = user.character
    end

    return normalizeCharacter(character)
end

local function getRedemCharacter(src)
    if not RedEM then return nil end

    local character = nil
    pcall(function()
        if RedEM.GetPlayer then
            local player = RedEM.GetPlayer(src)
            if player then
                character = normalizeCharacter({
                    firstname = player.firstname or player.firstName,
                    lastname = player.lastname or player.lastName,
                    job = player.job,
                    jobGrade = player.jobGrade or player.grade
                })
            end
        end
    end)

    return character
end

local function getDiscordId(src)
    local identifier = findIdentifierByPrefix(src, 'discord:')
    if not identifier then return nil end
    return identifier:gsub('discord:', '')
end

local function getSteamHex(src)
    local identifier = findIdentifierByPrefix(src, 'steam:')
    if not identifier then return nil end
    return identifier:gsub('steam:', '')
end

local function maskDiscordId(discordId)
    discordId = tostring(discordId or '')
    if discordId == '' then return 'Pa Discord' end
    return 'Discord ID ' .. discordId
end

local function decimalStringMultiplyAdd(decimal, multiplier, add)
    local carry = tonumber(add) or 0
    local out = {}

    for i = #decimal, 1, -1 do
        local digit = tonumber(decimal:sub(i, i)) or 0
        local value = digit * multiplier + carry
        out[#out + 1] = tostring(value % 10)
        carry = math.floor(value / 10)
    end

    while carry > 0 do
        out[#out + 1] = tostring(carry % 10)
        carry = math.floor(carry / 10)
    end

    local result = table.concat(out):reverse():gsub('^0+', '')
    if result == '' then result = '0' end
    return result
end

local function hexToDecimalString(hex)
    hex = tostring(hex or ''):gsub('[^0-9a-fA-F]', '')
    if hex == '' then return nil end

    local decimal = '0'
    for i = 1, #hex do
        local value = tonumber(hex:sub(i, i), 16)
        if value == nil then return nil end
        decimal = decimalStringMultiplyAdd(decimal, 16, value)
    end
    return decimal
end

local function canFetchSteamAvatars()
    return not (ServerConfig and ServerConfig.SteamAvatars and ServerConfig.SteamAvatars.Enabled == false)
        and type(PerformHttpRequest) == 'function'
end

local function fetchSteamAvatar(src)
    if not canFetchSteamAvatars() then return end

    local steamHex = getSteamHex(src)
    if not steamHex then return end

    local cached = SteamAvatarCache[steamHex]
    local cacheSeconds = tonumber(ServerConfig and ServerConfig.SteamAvatars and ServerConfig.SteamAvatars.CacheSeconds) or 3600
    if cached and cached.expiresAt and cached.expiresAt > os.time() then return end
    if SteamAvatarPending[steamHex] then return end

    local steam64 = hexToDecimalString(steamHex)
    if not steam64 then return end

    SteamAvatarPending[steamHex] = true
    local url = ('https://steamcommunity.com/profiles/%s/?xml=1'):format(steam64)

    PerformHttpRequest(url, function(statusCode, body)
        SteamAvatarPending[steamHex] = nil

        if statusCode ~= 200 or not body or body == '' then
            SteamAvatarCache[steamHex] = { avatar = '', expiresAt = os.time() + 300 }
            return
        end

        local avatar = body:match('<avatarFull><!%[CDATA%[(.-)%]%]></avatarFull>')
            or body:match('<avatarFull>(.-)</avatarFull>')
            or ''

        avatar = tostring(avatar or ''):gsub('&amp;', '&')
        if not avatar:match('^https?://') then avatar = '' end

        SteamAvatarCache[steamHex] = {
            avatar = avatar,
            expiresAt = os.time() + cacheSeconds
        }
    end, 'GET', '', {})
end

local function getSteamAvatar(src)
    local steamHex = getSteamHex(src)
    if not steamHex then return '' end

    local cached = SteamAvatarCache[steamHex]
    if cached and cached.avatar and (not cached.expiresAt or cached.expiresAt > os.time()) then
        return cached.avatar
    end

    fetchSteamAvatar(src)
    return ''
end

local function canFetchDiscordNames()
    return ServerConfig
        and ServerConfig.DiscordNames
        and ServerConfig.DiscordNames.Enabled == true
        and tostring(ServerConfig.DiscordNames.BotToken or '') ~= ''
        and tostring(ServerConfig.DiscordNames.GuildId or '') ~= ''
        and type(PerformHttpRequest) == 'function'
end

local function fetchDiscordName(discordId)
    if not canFetchDiscordNames() or not discordId then return end
    if DiscordPending[discordId] then return end

    local cached = DiscordCache[discordId]
    local cacheSeconds = tonumber(ServerConfig.DiscordNames.CacheSeconds) or 3600
    if cached and cached.expiresAt and cached.expiresAt > os.time() then return end

    DiscordPending[discordId] = true

    local guildId = tostring(ServerConfig.DiscordNames.GuildId)
    local token = tostring(ServerConfig.DiscordNames.BotToken)
    local url = ('https://discord.com/api/v10/guilds/%s/members/%s'):format(guildId, discordId)

    PerformHttpRequest(url, function(statusCode, body)
        DiscordPending[discordId] = nil

        if statusCode ~= 200 or not body or body == '' then
            DiscordCache[discordId] = {
                name = maskDiscordId(discordId),
                expiresAt = os.time() + 300
            }
            return
        end

        local ok, decoded = pcall(function()
            return json.decode(body)
        end)

        if not ok or type(decoded) ~= 'table' then
            DiscordCache[discordId] = {
                name = maskDiscordId(discordId),
                expiresAt = os.time() + 300
            }
            return
        end

        local user = decoded.user or {}
        local displayName = decoded.nick or user.global_name or user.username or maskDiscordId(discordId)
        if user.discriminator and user.discriminator ~= '0' and user.username and not decoded.nick then
            displayName = ('%s#%s'):format(user.username, user.discriminator)
        end

        DiscordCache[discordId] = {
            name = trimString(displayName, 80),
            expiresAt = os.time() + cacheSeconds
        }
    end, 'GET', '', {
        ['Authorization'] = 'Bot ' .. token,
        ['Content-Type'] = 'application/json'
    })
end

local function getDiscordDisplay(src)
    local discordId = getDiscordId(src)
    if not discordId then return 'Pa Discord' end

    local cached = DiscordCache[discordId]
    if cached and cached.name and (not cached.expiresAt or cached.expiresAt > os.time()) then
        return cached.name
    end

    fetchDiscordName(discordId)
    return maskDiscordId(discordId)
end

local function buildPlayerData(src)
    src = tonumber(src)
    ensurePlaytime(src)

    local gameName = trimString(GetPlayerName(src) or ('Player ' .. src), 40)
    local character = getVorpCharacter(src) or getRedemCharacter(src)

    local rpName = ''
    local job = ''
    local grade = ''

    if character then
        local first = character.firstname or character.firstName or ''
        local last = character.lastname or character.lastName or ''
        if first ~= '' or last ~= '' then
            rpName = trimString((tostring(first) .. ' ' .. tostring(last)):gsub('^%s*(.-)%s*$', '%1'), 42)
        end

        job = trimString(character.job or character.jobLabel or character.joblabel or '', 28)
        grade = trimString(character.jobGrade or character.grade or character.jobgrade or '', 12)
    end

    local seconds = getPlaytimeSeconds(src)

    return {
        id = src,
        name = gameName,
        gameName = gameName,
        character = rpName,
        discordName = getDiscordDisplay(src),
        steamAvatar = getSteamAvatar(src),
        job = job,
        grade = grade,
        ping = tonumber(GetPlayerPing(src)) or 0,
        playtimeSeconds = seconds,
        playtime = formatPlaytime(seconds)
    }
end


local fakeFirstNames = {
    'Arben', 'Dardan', 'Ilir', 'Besnik', 'Florian', 'Leon', 'Adrian', 'Ardit', 'Erion', 'Gent',
    'Noah', 'Liam', 'Oliver', 'Jack', 'Thomas', 'Arthur', 'George', 'Henry', 'Charlie', 'William'
}

local fakeLastNames = {
    'Dibra', 'Krasniqi', 'Berisha', 'Hoxha', 'Gashi', 'Kelmendi', 'Bytyqi', 'Shala', 'Hasani', 'Leka',
    'Smith', 'Brown', 'Wilson', 'Taylor', 'Walker', 'Cooper', 'Morgan', 'Bennett', 'Carter', 'Reed'
}

local fakeJobs = {
    'farmer', 'miner', 'lumberjack', 'doctor', 'sheriff', 'hunter', 'rancher', 'trader', 'blacksmith', 'citizen'
}

local function fakeCfg()
    return (Config and Config.FakePlayers) or {}
end

local function fakePlayersEnabled()
    return fakeCfg().Enabled == true
end

local function fakePlayersCount()
    local count = tonumber(fakeCfg().Count) or 0
    count = math.floor(count)
    if count < 0 then count = 0 end
    if count > 200 then count = 200 end -- safety për mos me rënduar NUI gjatë testit
    return count
end

local function shouldIncludeRealPlayers()
    return fakeCfg().IncludeRealPlayers ~= false
end

local function buildFakePlayerData(index)
    local cfg = fakeCfg()
    local startId = tonumber(cfg.StartId) or 9000
    local first = fakeFirstNames[((index - 1) % #fakeFirstNames) + 1]
    local last = fakeLastNames[((index - 1) % #fakeLastNames) + 1]
    local job = fakeJobs[((index - 1) % #fakeJobs) + 1]
    local seconds = 600 + (index * 1375)
    local discord = ('FakeDiscord%02d'):format(index)

    if cfg.ShowTestTag ~= false then
        discord = ('[TEST] %s'):format(discord)
    end

    return {
        id = startId + index,
        name = ('Fake Player %02d'):format(index),
        gameName = ('Fake Player %02d'):format(index),
        character = trimString(('%s %s'):format(first, last), 42),
        discordName = discord,
        steamAvatar = '',
        job = job,
        grade = tostring((index - 1) % 5),
        ping = 22 + ((index * 9) % 88),
        playtimeSeconds = seconds,
        playtime = formatPlaytime(seconds),
        isFake = true
    }
end

local function appendFakePlayers(players)
    if not fakePlayersEnabled() then return end

    local count = fakePlayersCount()
    for i = 1, count do
        players[#players + 1] = buildFakePlayerData(i)
    end
end

local function buildOnlinePayload()
    local players = {}

    if shouldIncludeRealPlayers() then
        for _, src in ipairs(GetPlayers()) do
            players[#players + 1] = buildPlayerData(src)
        end
    end

    appendFakePlayers(players)

    table.sort(players, function(a, b)
        return tonumber(a.id) < tonumber(b.id)
    end)

    return {
        players = players,
        count = #players,
        max = math.max(GetConvarInt('sv_maxclients', 48), #players),
        updated = os.date('%H:%M:%S')
    }
end

local function refreshCachedPayload()
    if CacheBuilding then return CachedPayload end
    CacheBuilding = true

    local ok, payload = pcall(buildOnlinePayload)
    if ok and type(payload) == 'table' then
        CachedPayload = payload
        CachedPayloadAt = GetGameTimer()
    else
        print(('[rd_scoardboard] Failed to build scoreboard payload: %s'):format(tostring(payload)))
        CachedPayload = CachedPayload or {
            players = {},
            count = 0,
            max = GetConvarInt('sv_maxclients', 48),
            updated = os.date('%H:%M:%S')
        }
    end

    CacheBuilding = false
    return CachedPayload
end

local function getOnlinePayload(force)
    local now = GetGameTimer()
    local cacheMs = math.max(500, (tonumber(ServerConfig and ServerConfig.PayloadCacheMilliseconds) or 2000))

    if force or not CachedPayload or (now - CachedPayloadAt) > cacheMs then
        return refreshCachedPayload()
    end

    return CachedPayload
end

RegisterNetEvent('rd_scoardboard:requestPlayers', function()
    local src = source
    -- Kur lojtari hap scoreboard-in, rindërtohet lista që të mos mbetet emri i karakterit të vjetër.
    TriggerClientEvent('rd_scoardboard:receivePlayers', src, getOnlinePayload(true))
end)

AddEventHandler('playerJoining', function()
    ensurePlaytime(source)
    CachedPayloadAt = 0
end)

local function invalidateScoreboardCache()
    CachedPayloadAt = 0
end

-- Disa versione të VORP i thërrasin këto event-e kur zgjidhet/spawnohet karakteri.
-- I përdorim vetëm për të pastruar cache-in, që character 2 të mos shfaqë emrin e character 1.
RegisterNetEvent('vorp:SelectedCharacter', invalidateScoreboardCache)
RegisterNetEvent('vorp:playerSpawn', invalidateScoreboardCache)
RegisterNetEvent('vorp:PlayerLoaded', invalidateScoreboardCache)

AddEventHandler('playerDropped', function()
    savePlaytime(source, false)
    CachedPayloadAt = 0
end)

CreateThread(function()
    Wait(1200)
    refreshCachedPayload()

    local interval = tonumber(ServerConfig and ServerConfig.PayloadCacheMilliseconds) or 2000
    interval = math.max(500, interval)

    while true do
        Wait(interval)
        refreshCachedPayload()
    end
end)

CreateThread(function()
    Wait(2500)
    for _, src in ipairs(GetPlayers()) do
        ensurePlaytime(src)
    end

    local interval = tonumber(ServerConfig and ServerConfig.PlaytimeSaveIntervalSeconds) or 60
    interval = math.max(20, interval)

    while true do
        Wait(interval * 1000)
        for _, src in ipairs(GetPlayers()) do
            savePlaytime(src, true)
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for _, src in ipairs(GetPlayers()) do
        savePlaytime(src, true)
    end
end)

RegisterCommand('refresh_scoardboard_framework', function(source)
    if source ~= 0 then return end
    tryLoadFrameworks()
    print('[rd_scoardboard] Framework cache refreshed.')
end, true)

RegisterCommand('rd_scoardboard_playtime_save', function(source)
    if source ~= 0 then return end
    for _, src in ipairs(GetPlayers()) do
        savePlaytime(src, true)
    end
    print('[rd_scoardboard] Playtime saved for online players.')
end, true)
