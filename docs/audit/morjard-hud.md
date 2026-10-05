# morjard-hud — audit

- **Testováno**: 2026-10-05 in-game, okno 1600×900 (16:9)

## Bugs found + fixed
1. **Kruhy stavu přes minimapu** (jídlo/pití/stres zakrývaly ulice a ikony) a **rámeček minimapy nesedí** (napevno 180×180 px). Fix: klient měří minimapu `GetScriptGfxPosition` se zarovnáním L/B (bere safezone), posílá `minimapRect`; rámeček obepíná mapu, kruhy jsou ve sloupcích vpravo vedle mapy. Ověřeno ve hře.
2. **Po restartu resource zmizel název ulice** — zprávy se posílají jen při změně a první zpráva po startu přišla dřív, než se NUI stránka načetla (zahozena). Fix: stránka po načtení volá `hudReady`, klient vynuluje cache (`hudVisible`, `lastStreet`, `lastMinimapKey`) a pošle znovu vše vč. peněz.
3. **CEF cache** servíroval starý `app.js` po restartu → `?v=` cache-bust na JS i CSS.

## Pattern k prohledání v ostatních pluginech
„Pošli NUI zprávu jen při změně + první odeslání hned při startu“ = data se po restartu resource neobjeví. Hledat v ostatních NUI pluginech (radio, phone status bar, dispatch, weathersystem tablet…).

## Open
- Netestováno ve vozidle (rychloměr, palivo, pás), stres, kyslík pod vodou.
- Netestováno na ultrawide (21:9) — minimapa je tam jinak.
