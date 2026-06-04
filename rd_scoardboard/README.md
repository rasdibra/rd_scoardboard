# rd_scoardboard

Book-style RedM/VORP scoreboard for Eagle County RP.

## Current version

- Opens directly to the player pages with **Z**.
- Old cover/welcome page config is removed.
- Language system is in `languages/`.
- Fake player test mode is available in `config.lua` for checking Next/Previous pages.

## Language

Open `config.lua`:

```lua
Config.Language = 'albanian'
```

or:

```lua
Config.Language = 'english'
```

Files:

- `languages/albanian.lua`
- `languages/english.lua`

## Fake player test

Fake players are enabled in this update so you can immediately test page switching.
For live server, turn them off:

```lua
Config.FakePlayers = {
    Enabled = false,
    Count = 25,
    StartId = 9000,
    IncludeRealPlayers = true,
    ShowTestTag = true
}
```

For testing lots of pages:

```lua
Config.FakePlayers = {
    Enabled = true,
    Count = 50,
    StartId = 9000,
    IncludeRealPlayers = true,
    ShowTestTag = true
}
```

Restart the resource after changing config.

## Commands

- `/scoreboard`
- `/scoardboard`
- `/scb`
- Z key opens/closes directly.

## Notes

- `Config.PlayersPerPage = 5`: each book page shows 5 players. Two pages are visible, so 10 players per spread.
- Next/Previous works automatically based on how many real + fake players are in the payload.
- Playtime is saved in Resource KVP; no SQL required.
