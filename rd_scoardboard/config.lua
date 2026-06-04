Config = {}

-- ============================================
-- RD SCOARDBOARD - CURRENT PLAYER PAGE VERSION
-- Nuk ka më cover/welcome page. Me Z hapet direkt lista e lojtarëve.
-- ============================================

-- Emri që shfaqet sipër faqeve të librit.
Config.ServerName = 'Eagle County RP'

-- Gjuha e UI. Zgjidh: 'albanian' ose 'english'
-- Tekstet janë te folderi languages/.
Config.Language = 'albanian'

-- Një faqe mban 5 lojtarë. Libri i hapur shfaq 2 faqe = 10 lojtarë për spread.
Config.PlayersPerPage = 5

-- Refresh automatik sa herë scoreboard është hapur.
Config.RefreshMs = 7000

-- Komandat backup. Hapja kryesore është me Z hash poshtë.
Config.Command = 'scoreboard'
Config.CommandAlias = 'scoardboard'
Config.CommandAlias2 = 'scb'

-- Z HASH për RedM. Hap/mbyll librin direkt me Z pa RegisterKeyMapping.
Config.OpenKeyHash = 0x26E9DC00
Config.ToggleCooldownMs = 160

-- Fushat që shfaqen te lista e lojtarëve.
Config.ShowJobs = true
Config.ShowPing = true
Config.ShowDiscord = true
Config.ShowPlaytime = true

-- TEST MODE: lojtarë fake vetëm për të testuar pamjen dhe Next/Previous pages.
-- Për live server vendose Enabled = false.
Config.FakePlayers = {
    Enabled = true,           -- true = aktivizo test fake players, false = fikur
    Count = 25,               -- sa fake player do të shtohen për test
    StartId = 9000,           -- ID fillestare për fake players që mos ngatërrohen me real players
    IncludeRealPlayers = true,-- true = real + fake, false = vetëm fake players për test UI
    ShowTestTag = true        -- vendos [TEST] te Discord që ta kuptosh që është fake
}
