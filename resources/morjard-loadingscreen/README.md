# Morjard Loading Screen

Custom FiveM loading screen for **Morjard Roleplay** server.  
Tactical HUD design system — matches the Morjard Weather System aesthetic.

---

## 📁 Structure

```
morjard-loadingscreen/
├── fxmanifest.lua          ← FiveM resource manifest
├── client.lua              ← Client-side Lua (shutdown hooks)
├── html/
│   ├── index.html          ← Loading screen HTML
│   ├── css/
│   │   └── style.css       ← All styles
│   └── js/
│       └── app.js          ← Logic, locales, NUI events
└── locales/
    ├── en.json             ← English
    ├── cs.json             ← Czech
    ├── sk.json             ← Slovak
    └── de.json             ← German
```

---

## 🚀 Installation

1. Copy the `morjard-loadingscreen` folder into your server's `resources/` directory.
2. Add to `server.cfg`:
   ```
   ensure morjard-loadingscreen
   ```
3. Restart your server.

---

## ⚙️ Configuration

All main options are at the **top of `html/js/app.js`** in the `CONFIG` object:

| Key                | Default              | Description                                  |
|--------------------|----------------------|----------------------------------------------|
| `defaultLang`      | `'en'`               | Language shown on first load                 |
| `availableLangs`   | `['en','cs','sk','de']` | Languages shown in the switcher           |
| `tipInterval`      | `6000`               | Milliseconds between tip rotations           |
| `stepMinDelay`     | `500`                | Min delay between simulated loading steps    |
| `stepMaxDelay`     | `1100`               | Max delay between simulated loading steps    |
| `progressSegments` | `12`                 | Number of segments in the progress indicator |
| `logMaxLines`      | `8`                  | Max lines visible in the live log            |
| `serverSlots`      | `256`                | Max player slots shown in server stats       |
| `discordUrl`       | `'https://discord.gg/morjard'` | Discord invite link               |
| `webUrl`           | `'https://morjard.cz'` | Website URL                                  |

---

## 🌐 Localization

### Changing the default language
In `html/js/app.js`, change:
```js
defaultLang: 'cs',   // 'en' | 'cs' | 'sk' | 'de'
```

### Adding a new language
1. Copy `locales/en.json` → `locales/XX.json` (replace XX with the ISO code, e.g. `pl`).
2. Translate all values (keep the keys identical).
3. Add the language code to `availableLangs` in `app.js`:
   ```js
   availableLangs: ['en', 'cs', 'sk', 'de', 'pl'],
   ```
4. Add the file path to `files` in `fxmanifest.lua` — the wildcard `'locales/*.json'` covers it automatically.

---

## 📡 NUI Events (from Lua → HTML)

You can send real loading progress from your Lua scripts:

### Real progress percentage
```lua
SendNUIMessage({ type = 'loadingProgress', pct = 75 })
-- pct: 0–100 integer
```

### Custom step + log line
```lua
SendNUIMessage({
    type    = 'loadingStep',
    label   = 'LOADING DATABASE',
    log     = 'DB    player records fetched',
    logType = 'ok'   -- 'ok' | 'warn' | 'err'
})
```

### Update player count
```lua
SendNUIMessage({ type = 'serverInfo', players = GetNumberOfPlayers() })
```

### Force language
```lua
SendNUIMessage({ type = 'setLang', lang = 'cs' })
```

### Signal loading complete
```lua
-- This is called automatically in client.lua on playerSpawned,
-- but you can call it manually too:
SendNUIMessage({ type = 'loadingDone' })
Citizen.Wait(1200)
ShutdownLoadingScreen()
ShutdownLoadingScreenNui()
```

---

## 🛠️ Customization Tips

- **Colors** — all defined as CSS variables in `style.css` under `:root`.
- **Server name** — change `server_name` in each locale JSON file.
- **Rules** — edit the `rules` array in each locale JSON file.
- **Stats row** — the four stats (slots, uptime, lang, mode) are hardcoded in HTML; values come from locales.
- **Background grid animation** — controlled by `@keyframes gridDrift` in `style.css`.

---

## 📋 Requirements

- FiveM server (any recent artifact)
- No external dependencies beyond CDN (Google Fonts + Font Awesome) — both load from the internet on first display.

---

*Morjard Development Team — v2.0*
