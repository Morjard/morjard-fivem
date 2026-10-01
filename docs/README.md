# morjard-fivem — konsolidovaný, vyčištěný FiveM balíček

Nová čistá složka (`~/Plocha/morjard-fivem/`), oddělená od rozházeného `~/Plocha/morjard/`. Vzniklo 2026-10-01 na základě projetí `~/Plocha/morjard` a živého FiveM serveru na OVH (`a3fc644c`).

## Co je uvnitř (`resources/`) — stav k 2026-10-01

| Resource | Stav |
|---|---|
| `rp-chat` | ✅ nasazeno, propojeno s hybridním stylem |
| `morjard_target` | ✅ nasazeno, přejmenováno z interního `ddcz_target` (manifest, exporty, eventy) |
| `morjard-weathersystem` | ✅ beze změny, obsahuje dřívější optimalizace (viz níž) |
| `morjard-multicharacter` | ✅ nasazeno, **propojení na `morjard-spawn-selector` dokončeno** (viz níž) |
| `morjard-loadingscreen` | ✅ nasazeno, hybridní styl přes `GetConvar` (jiný vzor, viz `HYBRID_STYLE.md`) |
| `morjard-spawn-selector` | nahráno na server, **neaktivováno** (`ensure` nikdy neproběhlo — viz "Propojení" níže) |
| `morjard-connector` | ✅ nasazeno — **bezpečnostní oprava 2026-10-01**: `mcp_api_key` byl slabý/uhodnutelný, otočen na 256bitový náhodný klíč, viz `SECURITY_morjard_connector.md` |
| `morjard-settings` | ✅ nasazeno, hybridní přepínač stylu Morjard/DDCZ, viz `HYBRID_STYLE.md` |
| `morjard-biography` | ✅ nasazeno — **bezpečnostní oprava 2026-10-01**: `/biography <id>` a NUI požadavek šly zavolat na kohokoliv bez omezení (žádný distance/permission check), navíc samostatná díra v `GetByCitizen` QBCore callbacku (dosažitelný síťově přímo podle citizenid, i na offline hráče). Opraveno, viz commit `626ddfd`. |

**DDCZ loading screen ani jiný DDCZ-brandovaný obsah sem záměrně nešel** — jediné, co bylo „psáno jako ddcz" a přesto patří dovnitř, byl `morjard_target` (interně `ddcz_target`), a ten je přejmenovaný.

## Hybridní styl (Morjard / DDCZ)

Viz [`HYBRID_STYLE.md`](HYBRID_STYLE.md). `resources/morjard-settings/shared/settings.lua` → `Config.ActiveStyle = 'morjard' | 'ddcz'`. Zapojeno a nasazeno ve `rp-chat`, `morjard-multicharacter`, `morjard-spawn-selector`, `morjard-loadingscreen`.

**Slovo „ddcz" v `morjard-settings` a v téhle dokumentaci je záměrné** — je to jméno jednoho ze dvou volitelných stylů. To je jiná věc než DDCZ branding uvnitř resource metadat (ten je odstraněný z `morjard_target`).

## Propojení multicharacter → spawn-selector (2026-10-01, dokončeno)

Viz [`FINDING_spawn_selector_integration.md`](FINDING_spawn_selector_integration.md) pro historii nálezu. Řešení: `morjard-multicharacter/config.lua` → `Config.UseSpawnSelector` (**default `false`** — zero dopad na současné hráče). Když zapnuto:
- `html/app.js`: tlačítko „Play" přeskočí vestavěný spawn modal, pošle `selectCharacter` s `spawnLocation: null`.
- `client/main.lua`: po načtení postavy (`QBCore:Client:OnPlayerLoaded`, jednorázový listener) spustí `TriggerEvent('morjard-spawnselector:open')` — `morjard-spawn-selector` sám dokončí pozicování (vlastní kamera/fade, nepotřebuje nic dalšího od multicharacteru).

**Aby to fungovalo živě, potřeba ještě**: aktivovat `morjard-spawn-selector` v `server.cfg` (`ensure morjard-spawn-selector`) a přepnout `Config.UseSpawnSelector = true`. Oboje záměrně NEUDĚLÁNO — žádní hráči online k živému otestování celého průchodu výběr postavy → spawn, a `ensure` nového resource má historii zaseknutí serveru (viz níže), takže chce opatrný test s hráčem, ne slepé nasazení.

## Bezpečnost

- [`SECURITY_morjard_connector.md`](SECURITY_morjard_connector.md) — slabý klíč chránící endpoint se vzdáleným spouštěním Lua kódu, dostupný z internetu. Opraveno.
- `morjard-biography` — chybějící autorizace na `/biography <id>` + NUI request + `GetByCitizen` callback (viz tabulka výše). Opraveno.
- Prošlé a v pořádku: `morjard-whitelist` (server-side `playerConnecting`/`deferrals`, nejde obejít z klienta), `morjard-doorlock` (plná autorizační logika — ACE/skupina/předmět/passcode, žádné slepé důvěřování klientovi).
- `QBCore:Server:TriggerCallback` je plný `RegisterNetEvent` — **jakýkoliv** `QBCore.Functions.CreateCallback`-registrovaný název je síťově dosažitelný přímo od libovolného klienta, ne jen z důvěryhodného server kódu. Při psaní nového callbacku v libovolném morjard resource na tohle myslet a validovat `source`/vlastnictví dat uvnitř callbacku samotného, ne spoléhat na to, že ho "volá jen server".

## Provozní poznámky (zjištěno 2026-10-01)

- **`ensure <nový-resource>` přes websocket konzoli je nespolehlivé** — command se часто „odešle", ale nic se nestane (potvrzeno opakovaně: `morjard-settings` při prvním nasazení, `hardcap` nyní). Funguje jistě jen **plný restart serveru** (power signal), ne jednotlivý `ensure`/`refresh` příkaz. `restart <existující-resource>` naopak funguje spolehlivě.
- **Restart serveru se občas zasekne ve stavu "stopping"** (pozorováno 2×) — řeší se `kill` signálem přes Pelican API (bezpečné při 0 hráčích, ověřeno bez ztráty dat).
- `hardcap` (stock Cfx.re resource, limituje hráče dle `sv_maxclients`) je v `server.cfg` `ensure`ovaný, ale aktuálně neběží — `sv_maxclients` samotné ale vynucuje už jádro FXServer, takže to není bezpečnostní díra, jen chybějící vedlejší resource. Needs plný restart k opravě, ne prioritní.
- `nn_lib`/`nn_interaction`/`0r_lib`/`es-antibackdoor` jsou v `server.cfg` záměrně zakomentované (licence/false positivy) — není to chyba.

## Optimalizace (průběžný sweep, 2026-10-01)

- `morjard-weathersystem` — už má dřívější optimalizace v kódu (komentáře „FIX: Was Wait(0)…"), zbylé 2 `Wait(0)` smyčky prověřeny a jsou legitimní (earthquake shake, zombie spawn — obě krátké/podmíněné, ne trvalý busy-loop).
- `morjard_target` — 2 `Wait(0)` smyčky prověřeny, obě standardní vzory (raycast polling, aktivní target-UI smyčka) — žádná oprava potřeba.
- DB dotazy: žádný skutečný N+1 vzor nenalezen (`GeneratePhoneNumber`/`GenerateBankAccount` mají omezenou retry smyčku max 20×, jen při vzniku postavy — v pořádku). `players` tabulka má zatím jen 3 řádky (dev server), takže JSON_EXTRACT bez indexu teď není problém — zmíněno jako „hlídat při růstu", ne řešit teď.
- TODO/FIXME sweep přes celý projekt — nic nedokončeného nenalezeno mimo již vyřešené.
