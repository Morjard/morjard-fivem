morjard-biography
================

Simple QBCore resource that records worked minutes per player and per job and exposes a small UI to view a player's "biography" (name, surname, total hours/days, job breakdown and job history).

Features
- Saves minutes automatically every minute while the player is online
- Stores per-job minutes and job history in MySQL (requires oxmysql)
- Command: /biography [serverID] — opens UI for yourself or specified online player's server ID
- UI supports multiple languages (English, Czech, Italian, Spanish)

Installation
1. Copy `morjard-biography` folder to your `resources` directory.
2. Add `ensure morjard-biography` to your server.cfg.
3. Import SQL `sql/morjard-biography.sql` into your database.

Usage
- /biography — open your own biography
- /biography <serverId> — open another player's biography (player must be online)

Notes
- The resource uses the player's `citizenid` (QBCore PlayerData.citizenid) to store data.
- The script increments minutes on the server side; the client notifies the server every minute.

Localization
- UI translations are in `html/locales/*.json`.

Customization
- Edit `Config.TickInterval` in `config.lua` to change how often minutes are saved (default is 60000 ms = 1 minute).

License
- Provided as-is. Modify to your needs.