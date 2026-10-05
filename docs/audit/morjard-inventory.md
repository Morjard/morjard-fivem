# morjard-inventory (FLOW) — audit

- **Rozsah**: config/flow.lua, client/flow.lua, server/flow.lua, web/src (React NUI → html-flow)
- **Testováno**: 2026-10-05, Morjard.DEV (57.129.114.181:30120), klient na WarMachine přes WmAgent, b3570
- **Commity**: tebex-suite `1fc4fc1` (+ dřívější fix SetResourceKvpString)

## Golden path (in-game)
- [x] Otevření `morjardinv` / TAB → UI, NUI focus, 109–143 fps
- [x] Živá synchronizace: předměty přidané ze serveru (`exports['qb-inventory']:AddItem`) se objeví v otevřeném UI
- [x] Kontextové menu (pravý klik): Použít / Rozdělit / Rychlý slot 1 / Zařadit do AUTO / Odhodit
- [x] Použít obvaz: 5 → 4, server potvrdí
- [x] Tooltip, detail předmětu, výběr
- [x] Drag&drop levá kapsa → vnější kapsa bundy, Access Score reaguje (100 % → 0 % když jediný léčebný předmět opustí QUICK zónu)
- [x] Kontext menu → Rychlý slot 1: odznak „1“, tlačítko „POUŽÍT (1)“
- [x] `slot_1` se zavřeným UI použije obvaz (4 → 3); přiřazení `quick {"1":"s1"}` přežije restart resource
- [ ] Rozdělit, Odhodit — netestováno tento průchod
- [ ] Kufr / přihrádka / skrýš (`/testinvtrunk` atd. z morjard-inventory-devtest) — netestováno

## Bugs found + fixed
1. **`SetResourceKvpString` nil na serveru** — `server/flow.lua` crashoval při ukládání layoutu (API na tomto FXServer buildu neexistuje). Fallback `SetResourceKvp`. Ověřeno: po bootu 0 SCRIPT ERROR.
2. **Zaseknutý `inv_busy` po restartu resource** — restart při otevřeném UI nechal `Player(src).state.inv_busy = true`, qb-inventory pak odmítal otevřít až do reloginu. Fix: `onResourceStart` vynuluje `inv_busy` všem online hráčům. Ověřeno: restart → `inv_busy=false` → otevře se.
3. **Prázdný plovoucí box dole uprostřed** — `.info-bar.access` v panelu detailu kolidoval s globálním `.access { position: fixed … }` (overlay pro access delay). Overlay přejmenován na `.access-pop`. Ověřeno ve hře.
4. **Angličtina v UI** přes tvrzení v memory "CZ locale FULL" — sloty (VEST/CHEST…), zbraně (PRIMARY…, "DRAG WEAPON HERE"), kapsy (Inner/Outer/Left/Right pocket), štítky kontejnerů (JACKET/PANTS), detail/tooltip/inspect (Weight/Volume/Access/Condition, MEDICAL/COMMON, FAVORITE, INSPECT). Vše přeloženo; `CATEGORY_LABELS` + `RARITY_LABELS` v `types/item.ts`.
5. **Panel detailu překrýval statistiky v hlavičce** (OBJEM/PŘÍSTUP useknuté) a tlačítko PROZKOUMAT se zalamovalo. Panel přesunut vpravo dolů, `white-space: nowrap`.

## Known limitations / open
- Názvy a popisy předmětů (`Bandage`, "Can be directly used…") jsou z `qb-core/shared/items.lua` — EN. Překlad zasáhne celý server, samostatný úkol.
- `bandage` má váhu 0 g v items.lua → detail ukazuje 0.00 kg.
- `docker restart` smaže neuložený inventář hráčů (známá věc) — preferuj `restart morjard-inventory` (teď funkční díky ACE pro morjard-connector).
- Po restartu resource je nutné znovu `ensure morjard-inventory-devtest` (závislost se zastaví s ním).

## Tooling note
- WmAgent `/input/keyboard {"key":"1"}` se do hry nedostal (slot_1 přes DevCon funguje) — klávesové zkratky ve hře testovat přes DevCon příkaz, nebo opravit keyboard route ve WmAgent.

## Logs seen during test
- Žádný SCRIPT ERROR po bootu ani během testu
- `[FLOW] result txId=… ok=true` pro všechny operace
