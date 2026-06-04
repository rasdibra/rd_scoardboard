ServerConfig = ServerConfig or {}

-- Playtime ruhet automatikisht në Resource KVP.
-- Nuk kërkon SQL dhe nuk prishet kur restartohet resource/server.
ServerConfig.PlaytimeSaveIntervalSeconds = 60

-- Sa shpesh ndërtohet lista globale e scoreboard-it.
-- Request-et e lojtarëve marrin këtë cache direkt, prandaj hapja me Z reagon shumë më shpejt.
ServerConfig.PayloadCacheMilliseconds = 2000

-- Prioritet për identifier që ruan playtime.
-- license zakonisht është më stabil; pastaj steam/discord/fivem.
ServerConfig.IdentifierPriority = { 'license:', 'steam:', 'discord:', 'fivem:' }

-- Discord name real nuk merret dot vetëm nga identifier pa Discord Bot.
-- Nëse do Discord nickname/username real:
-- 1) krijo Discord bot në Discord Developer Portal
-- 2) fute botin në guild/serverin tënd Discord
-- 3) vendos token + guild id këtu
-- Pa këto, scoreboard shfaq Discord ID të maskuar.
ServerConfig.DiscordNames = {
    Enabled = true,
    BotToken = '',
    GuildId = '',
    CacheSeconds = 3600
}

-- Foto e Steam përdoret si background te kutia ID.
-- Nuk kërkon Steam API key; serveri lexon avatarin nga Steam profile XML.
ServerConfig.SteamAvatars = {
    Enabled = true,
    CacheSeconds = 3600
}
