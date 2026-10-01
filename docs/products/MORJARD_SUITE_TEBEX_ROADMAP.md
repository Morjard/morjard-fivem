# Morjard Suite — Tebex produktový plán

**2026-10-01, aktualizováno** po nálezu existující přípravné práce v `~/Plocha/morjard/prompts/` (23 hotových generačních promptů) a `~/Plocha/morjard/morjard-studio/` (vlastní AI IDE + asset pipeline). Tenhle plán teď vychází primárně z TOHO, ne z nápadů odvozených jen z GitHub průzkumu — viz [`../reference/COMMUNITY_RESOURCES_2026.md`](../reference/COMMUNITY_RESOURCES_2026.md) pro ten průzkum, používá se už jen jako doplněk na chybějící kategorie (sekce 5).

## 📦 Stav implementace (2026-10-02, finální)

Repo: `~/Plocha/morjard-fivem/tebex-suite/` (vlastní git repo), **37 resources celkem**, všechny commitnuté samostatně s vysvětlujícím message + master `README.md` + konsolidovaný install bundle (`tools/build-install-bundle.sh`). **Všech 21 z 23 promptů ze sekce 2 hotovo** + `morjard-bridge` (sekce 3) + **všech 14 doplňkových produktů** ze sekce 5 bez hotového promptu (navrženo od nuly). Zbylé 2 z 23: `spawn-selector` už žije samostatně (viz sekce 0), `storm-system` záměrně odloženo jako rozšíření `morjard-weathersystem`, ne nový resource (viz sekce 7, bod 8).

Hotovo ze sekce 2 (21/21 dostupných): admin-alert, admin-menu, banking, bodycam, delivery, diving, drug-business, emotes, gym, helicam, house-robbery, hud, jobs-system, mdt, multijob, outfit-bag, pause-menu, radio, telefon (phone), towing, vehicle-keys.

Hotovo ze sekce 5 (14/14 bez Hydry, bez hotového promptu, navrženo od nuly): Scoreboard, Impound, Garages, Crypto, Marriage, Perf Dashboard, Dealership, Gang Territories, Businesses, Dispatch, EMS, Bank/Store Heist (odlišný od house-robbery), Housing (exteriérové vlastnictví + stash, vědomě bez custom MLO interiérů — chybí assety), **Inventory** (Ember NUI nad ox_inventory jako reálným enginem — drop-in reskin technicky nejde kvůli per-resource NUI scoping ve FXServer, takže je to tenký wrapper nad reálnými ox_inventory exporty, ne konkurenční engine).

Jediné, co zbývá: **Hydra jako produkt** — reálný, už nasazený kernel-level anti-cheat (`~/Plocha/morjard/hydra/`, `~/Plocha/fivem-ovh-resources/hydra/`), vědomě neřešeno bez přímého vstupu uživatele — licencování a co z toho ukázat zákazníkům je rozhodnutí majitele, ne něco k odhadu při balení živého security softwaru.

Metodika u každého resource: syntax ověřen (`luac -p` / `node --check`), u resources postavených subagenty nezávisle re-ověřeny klíčové tvrzení přímým grepem do kódu (ne jen převzaty z reportu), vizuálně otestováno přes headless Chrome screenshot kde má NUI, README dokumentuje odchylky od promptu/designová rozhodnutí/reálné nalezené bugy, nic nefalšováno tam, kde FXServer nemá reálný nativ (viz např. perfdash's tick-drift místo fiktivního CPU%, gym/ems's "buffs actually implemented" sekce).

Hotovo ze sekce 5 (5/14, bez hotového promptu, menší rozsah): Scoreboard, Impound (export API pro MDT), Garages (sdílí `player_vehicles` s vehiclekeys/MDT), Crypto (simulovaný trh, export pro Phone), Marriage (export API pro budoucí Biography integraci). Zbývá: Inventory, Housing, Dealership, EMS, Dispatch, Bank/Store Robbery, Gang Territories, Businesses, Perf Dashboard, Hydra-jako-produkt — všechno Flagship-scale, srovnatelné rozsahem s Banking/Jobs, žádné zatím nezačaté.

Každý hotový resource: syntax ověřen (`luac -p` / `node --check`), vizuálně otestován přes headless Chrome screenshot kde má NUI, README dokumentuje odchylky od promptu a reálné nalezené bugy, commitnuto samostatně do `tebex-suite` repa s vysvětlujícím commit message.

Cíl: produkty prodávané na Tebexu, co fungují **jak na QBCore, tak na Qbox (qbx_core)** ze stejného kódu, v Morjard designu, s výkonem/stabilitou jako hlavní odlišovací hodnotou.

## ⚠️ Stáří zdrojového materiálu

Vše v sekci 0–3 pochází z `~/Plocha/morjard/prompts/` a `~/Plocha/morjard/morjard-studio/`, poslední commit/úprava **2026-03-19 až 2026-03-22** — přes půl roku staré, bez jediné novější úpravy od té doby (potvrzeno `git log`). Ani jeden z 23 promptů kromě spawn-selectoru nebyl za tu dobu zjevně realizovaný. Používat jako **směrový startovní bod, ne hotovou pravdu** — než se pipeline znovu rozjede, stojí za rychlou kontrolu:
- jestli Morjard Studio (`morjard-studio/`) vůbec ještě naběhne (závislosti, Tauri build) po půl roce ladem
- jestli se QBCore/Qbox ekosystém od března nezměnil natolik, že by to ovlivnilo Bridge vrstvu (sekce 3)
- jestli design jazyk (Ember) pořád sedí s tím, co dnes reálně běží v `morjard-fivem` (spot-checkem to sedí — fonty i clip-path styl jsou shodné, viz sekce 1)

Je tam ještě `~/Plocha/morjard/ingame-editor/prompts` — nekontrolováno, jiný nástroj (mapový editor, ne generování scriptů), pravděpodobně nesouvisí.

## 0. Co už existuje a na co navazujeme

- **23 hotových generačních promptů** v `~/Plocha/morjard/prompts/` (15–32 KB každý, viz tabulka v sekci 2) — detailní specifikace resource podle sebe (features, DB schéma, NUI popis), všechny už psané v **Morjard Ember Design** jazyce. Tohle je ten skutečný backlog, ne nápady z GitHubu.
- **`morjard-spawn-selector`** je živý důkaz, že pipeline prompt → reálný resource funguje — `spawn-selector_prompt.txt` je prakticky identická specifikace toho, co jsme dnes v `morjard-fivem` auditovali, opravovali a napojovali na multicharacter.
- **Morjard Studio** (`~/Plocha/morjard/morjard-studio/`) — vlastní Tauri/Vue AI IDE pro generování těchhle resources: 14 AI providerů, 16 specializovaných microagentů (mj. QBCore, ESX, Qbox, ox_lib, NUI, Tebex/Escrow, Anti-Cheat, **Morjard Design System** agent), hook pipeline se 4 FiveM bezpečnostními hooky (SQL guard, file guard, event validator, dangerous command) — část dnešního inženýrského checklistu (sekce 3) je tam možná už automatizovaná.
- **AI Asset Pipeline** (`morjard-ai` server, popsaný v `morjard-studio/ROADMAP.md`) — text → kompletní FiveM resource VČETNĚ 3D modelů: Z-Image-Turbo (concept art), Hunyuan3D-2.1 (3D model), MeshAnything V2 (retopologie), TangoFlux (zvuk), Blender+Sollumz (export do YDR/YDD/YFT/YBN). Tohle je **konkurenční výhoda, co nikdo na Tebexu nemá** — vlastní nábytek/rekvizity/modely pro každý produkt místo placeholder MLO assetů.
- **`design-preview/`** — živý náhled design systému a button lab (1000 kombinací) — použít jako referenci při QA každého nového produktu, ne znovu vymýšlet styl.

## 1. Oprava: skutečný design systém je „Morjard Ember Design", ne emerald

Moje první verze téhle roadmapy (viz git historie) špatně odhadla paletu z `morjard-settings.lua` (emerald/oranžová — to je paleta ŽIVÉHO RP serveru, ne prodejních produktů). Produktové prompty jednotně používají **Ember**:

```css
--accent:         #F97316;  /* primární oranžová */
--accent2:        #FBBF24;  /* amber/zlatá sekundární */
--accent-glow:    rgba(249,115,22,0.35);
--accent-dim:     rgba(249,115,22,0.12);
--danger:         #EF4444;
--success:        #22C55E;
--bg-darkest:     #060504;
--bg-dark:        #0F0D0B;
--bg-medium:      #1A1714;
--bg-light:       #24201C;
--border:         rgba(249,115,22,0.15);
--glass:          rgba(15,13,11,0.85);
--glass-blur:     blur(12px);
--text-bright:    #FAFAF9;
--text-dim:       #A8A29E;
--text-muted:     #78716C;
```

- **Fonty**: Inter (UI text), JetBrains Mono (čísla/data/monospace), Space Grotesk (nadpisy) — potvrzeno, stejné i v `morjard-fivem`'s skutečném NUI kódu (multicharacter, spawn-selector), takže konzistence mezi živým serverem a prodejními produkty je zachovaná.
- **Aesthetic**: ostré hrany, `clip-path` notched rohy, **žádný border-radius**, glass panely s `backdrop-filter: blur`, scanlines, zero-radius napříč celou sadou (Morjard Studio má 14 stylů tlačítek postavených na tomhle — notched, hexagon, terminal, bracket, slash, trapezoid, skew...).
- Morjard Studio má navíc 3 další témata (Aurora violet+emerald, Synthwave cyan+magenta, Sapphire blue+violet) — zvážit, jestli produkty nabídnout jen v Ember, nebo s přepínačem motivu jako prémiovou vlastnost (podobně jako `morjard-settings` dělá Morjard/DDCZ přepínač na živém serveru).

## 2. Existující backlog — 23 hotových promptů

Všechny v `~/Plocha/morjard/prompts/`, QBCore cílené (potřebují Bridge vrstvu níž pro Qbox). Sloupec **Shoda s dneškem** značí přímou vazbu na práci z `morjard-fivem`.

| Prompt soubor | Resource jméno | Co dělá | Tebex kategorie | Shoda s dneškem |
|---|---|---|---|---|
| `spawn-selector_prompt.txt` | morjard-spawnselector | Výběr spawn lokace po výběru postavy, mapa s diamantovými piny | Core/bundle s multicharem | **Už postavené, dnes auditované + napojené na multicharacter** |
| `telefon_prompt.txt` | morjard-phone | Plnohodnotný smartphone, appky, hovory, SMS, banking appka | Flagship | — |
| `banking_prompt.txt` | morjard-banking | Účty, převody, historie, ATM i pobočka | Flagship | — |
| `mdt_prompt.txt` | morjard-mdt | MDT pro policii/EMS, citizen/vehicle lookup, BOLO | Flagship | **Integrovatelné s `hydra` anticheatem** |
| `hud_prompt.txt` | morjard-hud | Hlavní HUD | Core/Flagship | — |
| `admin-menu_prompt.txt` | morjard-admin | Sidebar admin panel, hráči, reporty, bany | Flagship | **Integrovatelné s `hydra_detections.log`** |
| `admin-alert_prompt.txt` | morjard-alert | Fullwidth banner oznámení, fronta, auto-dismiss | Utility | — |
| `bodycam_prompt.txt` | morjard-bodycam | Bodycam overlay pro policii, cloud upload, MDT review panel | Doplněk k MDT | Bundluje se s MDT |
| `helicam_prompt.txt` | morjard-helicam | Vrtulníková kamera, night vision, plate reader | Doplněk k MDT | Bundluje se s MDT |
| `vehicle-keys_prompt.txt` | morjard-vehiclekeys | Key fob, 3 styly klíčů, lockpicking, sdílení klíčů | Core vozidla | — |
| `towing_prompt.txt` | morjard-towing | Odtahová služba, vizuální lano, NPC dispatch | Job/doplněk mechanika | — |
| `house-robbery_prompt.txt` | morjard-houserobbery | Vykrádání domů, lockpick minihra, loot tabulky | Ilegální | Odlišné od bank/store loupeží v sekci 5 |
| `drug-business_prompt.txt` | morjard-drugbusiness | Fullscreen dashboard pro sklady/výrobu/zaměstnance, police heat mechanika | Flagship ilegální | — |
| `jobs-system_prompt.txt` | morjard-jobs | Univerzální job board, XP/level progrese, aktivní job HUD | Core framework | Nosič pro Jobs Pack (sekce 5) |
| `multijob_prompt.txt` | morjard-multijob | Přepínání mezi joby, on/off duty, whitelist vs civilian | Doplněk k jobs-system | — |
| `delivery_prompt.txt` | morjard-delivery | Objednávky, trasy, minihra balíčků, hodnocení | Job | — |
| `diving_prompt.txt` | morjard-diving | Potápěčská mise, kyslík, sonar, odměny | Job/minihra | — |
| `gym_prompt.txt` | morjard-gym | Cvičení, minihry, staty ovlivňující gameplay, žebříček | Sociální/QoL | — |
| `emotes_prompt.txt` | morjard-emotes | Radiální menu emotek, 8 kategorií, oblíbené | QoL | — |
| `outfit-bag_prompt.txt` | morjard-outfitbag | Uložené outfity, grid náhled, VIP sloty | QoL, napojení na qb-clothing/illenium | — |
| `pause-menu_prompt.txt` | morjard-pausemenu | Vlastní ESC menu místo defaultního GTA | Core UI | — |
| `radio_prompt.txt` | morjard-radio | Handheld radio zařízení, kanály, volume, seznam uživatelů | Core komunikace | — |
| `storm-system_prompt.txt` | morjard-storm | Storm chasing dashboard, radar, tornádo/hurikán eventy, žebříček | Minihra/event | **Překryv s `morjard-weathersystem`** — viz poznámka níž |

**Poznámka ke storm-system**: `morjard-weathersystem` (živě na serveru, dnes auditovaný) už má earthquake/tsunami/zombie speciální eventy s admin permission + rate limiting. `storm-system_prompt.txt` popisuje v podstatě rozšíření stejné kategorie (dashboard, radar, žebříček pro chasery) — dává smysl to postavit jako **rozšiřující modul nad `morjard-weathersystem`**, ne jako úplně nový nezávislý resource. Ušetří to duplicitní práci a zákazník dostane jednu integrovanou věc místo dvou.

## 3. Technický základ: `morjard-bridge`

Všech 23 promptů cílí čistě na QBCore (`qb-core`). Bez kompatibilní vrstvy nejde "funguje na QBCore i Qbox" tvrdit u jediného z nich. Tohle je jediná skutečně NOVÁ technická práce, co žádný z 23 promptů neřeší:

```lua
-- morjard-bridge/shared/detect.lua (koncept)
Bridge = {}

function Bridge.GetFramework()
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    return nil -- fail loudly, ne tiše spadnout
end

function Bridge.GetInventory()
    if GetResourceState('ox_inventory') == 'started' then return 'ox' end
    if GetResourceState('qb-inventory') == 'started' then return 'qb' end
    return nil
end
```

- **Framework vrstva**: `Bridge.Player.Get(src)`, `Bridge.Player.Notify(src, msg, type)`, `Bridge.Money.Add/Remove` — stejný vzor jaký už máte v `rp-chat/client.lua` (`Config.Framework = 'auto'`, retry+pcall) a `morjard-doorlock` (`server/framework/qb_core.lua` + sourozenci), jen zobecněný do jednoho sdíleného resource.
- **Target vrstva**: NENÍ potřeba zvlášť — `morjard_target` už dnes běží čistě na `ox_lib`/`ox_target`, žádná `qb-core` závislost. Funguje na obou frameworcích beze změny.
- **Praktický postup**: při generování z existujících promptů přidat jeden odstavec navíc — "use `Bridge.Player`/`Bridge.Money` instead of direct `QBCore.Functions`/`exports['qb-core']` calls" — a Morjard Studio AI agent (QBCore/Qbox microagent) by to měl umět vygenerovat rovnou správně, místo ručního portování 23 existujících promptů jeden po druhém.

## 4. Inženýrský checklist (povinný pro každý produkt před vydáním)

Odvozeno z dnešních 9 reálných chyb nalezených a opravených v `morjard-fivem` (viz `../README.md`):

- [ ] `fxmanifest.lua` deklaruje **všechny** skutečné závislosti (`qb-core`/`qbx_core` přes `morjard-bridge`, `oxmysql`, `ox_lib`) — žádné nechráněné `exports[...]:GetCoreObject()` na prvním řádku bez `dependency` nebo pcall+retry
- [ ] Žádný `setr`/`sets` na cokoliv tajného (API klíče, webhooky, connection stringy) — jen `set`
- [ ] Každý server event/callback, co bere `target`/cizí ID, má **server-side** ověření vlastnictví nebo vzdálenosti
- [ ] Žádné `Wait(0)` smyčky mimo skutečně nutné per-frame případy, zdokumentované proč
- [ ] DB sloupce s texty používají `utf8mb4`, connection string nastavený jen jednou
- [ ] Rate limiting na klientem spustitelném serverovém eventu, co stojí výkon
- [ ] NUI buildy testované vizuálně (headless screenshot nebo live), ne jen podle kódu
- [ ] Žádné hardcoded "DEV"/placeholder texty v `main`/`release` větvi

Zvážit automatizaci tohohle checklistu jako hook v Morjard Studiu (má už 4 FiveM security hooky — SQL guard, file guard, event validator, dangerous command — rozšířit o kontrolu `dependency`/`setr`/distance-check patternů).

## 5. Doplňkové kategorie (z GitHub/fórum průzkumu, chybí v 23 promptech)

Tyhle NEMAJÍ hotový prompt, potřebují napsat od začátku v Ember designu — ale pokrývají kategorie, co 23 existujících promptů nechává prázdné:

| Morjard produkt | Inspirace | Vrstva | Poznámka |
|---|---|---|---|
| **Morjard Inventory** | ox_inventory jako engine + Ember UI vrstva | Flagship | Nejviditelnější chybějící kus |
| **Morjard Housing** | ps-housing (archivované → prázdné místo na trhu) | Flagship | — |
| **Morjard Garages** | qb-apartments garáže | Utility | Bundl s Housing |
| **Morjard Dealership** | qb-vehicleshop | Flagship | — |
| **Morjard Impound** | vlastní nápad, chybí na trhu | Utility | Propojit s MDT (policie impounduje přímo odtamtud) |
| **Morjard EMS** | ak47_ambulancejob anatomický systém | Flagship | — |
| **Morjard Dispatch** | SolidCore dispatch | Flagship | Bundl s MDT |
| **Morjard Bank/Store Robbery** | lation_247robbery, qb-bankrobbery | Flagship | Odlišné od house-robbery (ten je v sekci 2) |
| **Morjard Gang Territories** | qb-territories, xex_gangwars | Flagship | — |
| **Morjard Businesses** | ren-businesses | Flagship | — |
| **Morjard Crypto/Stocks** | qb-crypto, BadgerStockMarket (reálná tržní data) | Utility, appka do Phone | — |
| **Morjard Marriage** | uniqers-marriage koncept | Utility | Napojit na `morjard-biography` |
| **Morjard Scoreboard** | hyper_scoreboard | Utility | — |
| **Morjard Perf Dashboard** | vlastní, nad `resmon`/`status` + `morjard-connector` | Diferenciátor | Nikdo na Tebexu tohle nenabízí |
| **Hydra Anti-Cheat jako produkt** | vlastní, už existuje a běží | Diferenciátor | Nejvyšší prodejní potenciál — nikdo jiný nemá vlastní anticheat v nabídce |

## 6. Tebex strategie

- **Free loss-leadery**: Morjard Bridge, Morjard Target (hotové) — nízké riziko, budují instalační základnu pro placené produkty na nich postavené.
- **Escrow**: ANO pro placené produkty, Bridge a Target zůstávají escrow-free (stejná logika jako `ox_lib` zdarma / `ox_inventory` placené varianty na něm postavené).
- **Bundly**: MDT+Dispatch+Bodycam+Helicam (celá policejní sada), Housing+Garages, Jobs Pack (jobs-system+multijob+delivery+diving jako 4v1), Dealership+Impound+Vehicle Keys.
- **Vlajkové produkty** (nejvyšší cena): Morjard Phone, Morjard MDT, Hydra Anti-Cheat, Morjard Inventory, Morjard Drug Business.

## 7. Doporučené pořadí vývoje

1. **Morjard Bridge** — bez něj nejde nic prodávat jako dual-framework
2. **Morjard Target** — potvrdit prodejnost samostatně, už hotové
3. **Spustit Morjard Studio pipeline na 3–4 nejmenší hotové prompty** (admin-alert, pause-menu, emotes, radio — nejkratší specs, rychlý první test celého prompt→produkt→QA→Tebex procesu)
4. **Morjard HUD** — viditelný, rychlý, dobrý marketingový first impression
5. **Morjard MDT + Bodycam + Helicam + Dispatch** — flagship policejní balíček, integrace s Hydra jako jasný diferenciátor
6. **Morjard Phone + Banking appka** — nejvyšší očekávaný revenue
7. **Hydra Anti-Cheat jako samostatný placený produkt** — existuje, potřeba hlavně admin UI a dokumentace pro cizí zákazníky
8. **Storm-system jako rozšíření `morjard-weathersystem`**, ne nový resource (sekce 2 poznámka)
9. zbytek 23 promptů + doplňkové kategorie (sekce 5) podle poptávky
