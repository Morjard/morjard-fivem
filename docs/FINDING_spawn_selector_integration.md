# Nález: nedokončené propojení multicharacter → spawn-selector

**2026-10-01**, zjištěno při rozhodování, zda aktivovat `morjard-spawn-selector` na serveru.

## Co jsem našel

`morjard-multicharacter` (aktivní na serveru) má **svůj vlastní vestavěný** krok výběru spawn pozice — funkce `openSpawnSelector()`/`closeSpawnSelector()` přímo v `html/app.js` (řádky 269, 506, 526, 622, 633).

`morjard-spawn-selector` (zatím neaktivní, jen nahraný) je **samostatný, propracovanější** resource se stejným účelem — výběr spawn pozice na mapě ("Ember Design", vlastní CSS, konfigurovatelné lokace). Jeho `client/main.lua` má přímo komentář:

```lua
-- Triggered by morjard-multicharacter or any resource after character selection
RegisterNetEvent('morjard-spawnselector:open', function()
```

Tohle jasně říká, že `morjard-spawn-selector` měl **nahradit** vestavěný krok v multicharacteru — multicharacter měl po výběru postavy zavolat `TriggerEvent('morjard-spawnselector:open')` místo svého interního `openSpawnSelector()`.

**To propojení ale nikdy nedokončili.** `morjard-multicharacter` nikde nevolá `morjard-spawnselector:open` ani žádný jiný event tohoto resource — pořád používá jen svůj starý vestavěný výběr.

## Proč jsem to neopravil rovnou

Tohle je jiná kategorie zásahu než dosavadní doplňkové úpravy (hybridní styl, přejmenování). Jde o **core flow vytváření/výběru postavy** — pokud bych propojení udělal špatně, hráč se při připojení nemusí dostat do hry vůbec. Server teď nemá žádné hráče, takže to nejde živě otestovat kliknutím skrz UI, a slepě nasadit změnu v tak citlivém místě bez ověření nepovažuju za zodpovědné.

## Možnosti (na tvoje rozhodnutí)

1. **Dokončit propojení** — v `morjard-multicharacter/client/main.lua` (nebo `html/app.js`) nahradit interní `openSpawnSelector()` voláním `TriggerEvent('morjard-spawnselector:open')`, aktivovat `morjard-spawn-selector` na serveru, a **otestovat živě** (ty nebo někdo z hráčů) než to necháš běžet na ostrém serveru.
2. **Nechat jak je** — multicharacter má svůj vestavěný výběr, funguje, `morjard-spawn-selector` zůstane nevyužitý/rozpracovaný projekt na později.
3. **Smazat `morjard-spawn-selector`** ze serveru i ze složky, pokud je to zastaralá rozdělaná práce, kterou už nechcete dokončovat.

Soubory `morjard-spawn-selector` jsou nahrané na serveru (`[standalone]/`... ne, mimo kategorie, v kořeni `resources/morjard-spawn-selector/`), ale **neaktivované** (`ensure` neproběhlo), takže teď nemá žádný vliv na běžící hru.
