# Hybridní styl: Morjard / DDCZ

Server běží pod dvěma vizuálními identitami postavenými na stejném kódu — **Morjard** (aktuální brand) a **DDCZ** (původní, pořád naše). Přepínání řeší jediný soubor, ne ruční hledání/nahrazování po resourcech.

## Jak to funguje

```
resources/morjard-settings/shared/settings.lua   <- Config.ActiveStyle = 'morjard' | 'ddcz'
                 │
                 ├── export GetStyle() (client i server)
                 │
                 ▼
    kterýkoliv resource si o styl řekne a pošle ho do NUI
```

**Změna stylu celého serveru** = jeden řádek v `morjard-settings/shared/settings.lua`:
```lua
Config.ActiveStyle = 'ddcz'   -- nebo 'morjard'
```

Nebo bez zásahu do kódu, přes `server.cfg`:
```
set morjard_active_style "ddcz"
```

## Palety (reálné hodnoty, ne placeholder)

| | Morjard | DDCZ |
|---|---|---|
| Accent | `#10b981` (emerald) | `#00b0ff` (světle modrá) |
| Accent alt | `#ff9a1f` (oranžová, "cyberpunk") | `#ffd700` (zlatá) |
| Sekundární | `#3b82f6` | `#4caf50` |

Zdroj: Morjard paleta je z `rp-chat/STYLE_GUIDE.txt` (aktuální live brand), DDCZ paleta je z původního `ddcz-loadingscreen` (`html/js/config.js` + `html/css/style.css`).

## Jak napojit další resource

1. `fxmanifest.lua`: `dependency 'morjard-settings'`
2. V `client.lua` (co nejdřív po startu):
   ```lua
   CreateThread(function()
       local ok, style = pcall(function()
           return exports['morjard-settings']:GetStyle()
       end)
       if ok and style then
           SendNUIMessage({ action = 'applyMorjardStyle', style = style })
       end
   end)
   ```
3. V HTML/JS straně reaguj na `action === 'applyMorjardStyle'` a nastav CSS proměnné přes `document.documentElement.style.setProperty(...)`.

**Hotovo (zapojeno a nasazeno na živý server 2026-10-01):**
- `rp-chat` — `html/assets/morjard-style-bridge.js` (samostatný soubor navíc, bundle `index.js`/`index.css` nedotčen)
- `morjard-multicharacter` — `html/morjard-style-bridge.js`
- `morjard-spawn-selector` — `html/js/morjard-style-bridge.js`
- `morjard-loadingscreen` — **jiný vzor**: loadscreen resource běží ještě před tím, než mají ostatní resources jistotu, že běží, takže `exports['morjard-settings']` by bylo nespolehlivé (závod při startu). Čte se přímo přes `GetConvar('morjard_active_style', 'morjard')`, který je dostupný okamžitě z `server.cfg` (`set morjard_active_style "ddcz"`) bez ohledu na pořadí startu resources. Palety jsou pro jistotu zdvojené přímo v `client.lua` (malá, stabilní tabulka, žádná závislost).

Všechny čtyři UI mají každý svou vlastní výchozí paletu (cyan/oranžová/apod.) — hybridní styl ji jen PŘEPÍŠE, pokud `morjard-settings` běží / convar je nastaven; jinak zůstane původní vzhled beze změny (bezpečný fallback).

## Pozor

- `morjard-settings` musí v `server.cfg` startovat **před** resourcy, co ho používají (`ensure morjard-settings` nad `ensure rp-chat` atd.).
- Pokud `morjard-settings` neběží, `pcall` to tiše přeskočí — chat pak jen použije svůj vlastní vestavěný výchozí vzhled, nic nespadne.
