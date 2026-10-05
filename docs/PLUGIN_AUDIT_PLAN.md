# Plugin audit plan — Morjard FiveM Suite

Systematický průchod každého nasazeného resource s cílem **najít a opravit skutečně nefunkční věci**. Fundamental rule:

> **"Když není chyba v logu, neznamená to že kód funguje nebo je logicky správný."**
> Hledat také UX bugy, dead-ends, missing feedback, chybějící validace, data races, race conditions, hidden assumptions, špatné happy-path výsledky.

## Zásady

1. **Testuj in-game**, ne jen source read. Minimálně:
   - UI opens (NUI focus, cursor, close)
   - Golden path (nejčastější použití)
   - Edge cases (žádné peníze, žádný item, špatná role, network drop)
   - State persistence (restart resource → zůstává stav?)
2. **Vždy backup před risk edit** — git tag `pre-audit-NAZEV-YYYYMMDD` nebo `.bak.YYYYMMDD`
3. **Jeden plugin = jeden commit** (reader PR message dřív)
4. **Všechno zapsat** — notes do `docs/audit/NAZEV.md` + záznam do memory
5. **Fix na source + deploy + verify live** (ne jen local), per [[server-access]] §deploy
6. **Live log tail při testech** — chytni silent SCRIPT ERRORy a invariant breaks

## Audit template (per plugin)

Pro každý plugin vyplnit `docs/audit/<name>.md`:

```markdown
# <name> — audit

- **Rozsah**: client/server/html změny
- **Verze při auditu**: commit SHA, deploy time
- **Dependencies**: qb-core, oxmysql, morjard-bridge, ...

## Co to má dělat
<Krátký popis účelu z user POV>

## Golden path test
- [ ] 1. Otevření (jak)
- [ ] 2. Hlavní akce
- [ ] 3. Zavření / cleanup

## Edge cases
- [ ] Žádné peníze: `AddMoney` fail refund
- [ ] Žádný item: `RemoveItem` fail refund
- [ ] Permission denied: správná notify, žádný state leak
- [ ] Resource restart s otevřeným UI → `SetNuiFocus(false)` + state revert
- [ ] Opakovaný klik během async op → lock / debounce
- [ ] Race: dva players na stejnou věc najednou (shop/stash/mission)

## Security
- [ ] Trust-but-verify: client-sent args validovány server-side (whitelist, GetItemBySlot, GetPlayerIdentifier)
- [ ] isBoss/isAdmin check uvnitř handleru, ne jen UI gate
- [ ] Money / inventory operace: check return value před compensation
- [ ] SQL: parametrized (?,?), žádný string concat

## Bugs found
1. **<krátký popis>** — file:line
   - Repro: ...
   - Fix: ...
   - Deployed: commit SHA

## Known limitations
<Co není bug ale user by měl vědět>

## Logs seen during test
<SCRIPT ERROR, warnings, suspicious prints>
```

## Pořadí auditu — priority groups

### Group A — kritická infra (nejvyšší priorita)
1. **morjard-bridge** — všechno jde přes něj (notify, inventory, money) → bugy mají multiplicitní dopad
2. **morjard-connector** — remote exec endpoint; security
3. **morjard-inventory** (FLOW) + morjard-consumables — item flow
4. **qb-core, qb-inventory** — upstream deps (jen monkey-patch spots audit, ne přepis)

### Group B — ekonomické plugins (money loss = user anger)
5. **morjard-banking**
6. **morjard-dealership** / **morjard-marinedealer**
7. **morjard-businesses**
8. **morjard-realestate**
9. **morjard-insurance**
10. **morjard-crypto**

### Group C — social / interactive (hraje se často)
11. **morjard-phone** (v3 wallpapers hotové, HUD/mapping ne) ⚠️ redesign in progress
12. **morjard-radio**
13. **rp-chat**
14. **morjard-admin**
15. **morjard-mdt**

### Group D — jobs (každý má vlastní economy loops)
16. **morjard-ems**
17. **morjard-garages**
18. **morjard-dispatch**
19. **morjard-jobs**
20. **morjard-multijob**
21. **morjard-cooking** / **mining** / **fishing** / **hunting**
22. **morjard-delivery** / **towing** / **taxi**
23. **morjard-bountyhunter** / **lawyer** / **newspaper** / **paparazzi**

### Group E — world / interaction (lower priority)
24. **morjard-housing**
25. **morjard-nightclub** / **casino** / **fightclub** / **gym**
26. **morjard-pawnshop** / **gunstore** / **clothingstore** / **barbershop**
27. **morjard-pets** / **marriage**
28. **morjard-territories** / **drugbusiness** / **heist** / **houserobbery**
29. **morjard-racing**
30. **morjard-emotes** / **helicam** / **vehiclekeys** / **outfitbag**

### Group F — nice-to-have / less-used
31. **morjard-impound** / **scrapyard** / **jail**
32. **morjard-auctionhouse**
33. **morjard-perfdash** / **biography** / **creditbureau** / **alert**
34. **morjard-tuningshop**
35. **morjard-diving**

### Group G — out-of-scope (user řekl ne)
- `morjard-multicharacter` ❌ nedotýkat (user Ember reference)
- `morjard-spawn-selector` ❌ nedotýkat

## Known issues (snapshot 2026-10-05 18:00)

1. ✅ **FLOW SetResourceKvpString nil** — FIXED (fallback `_G.SetResourceKvp or no-op`), deployed, verified live
2. ✅ **weathersystem invalid data_file types** — FIXED (odstraněno z fxmanifest.lua), deployed, pending ensure
3. 🔍 **qb-inventory AddItem: Invalid item (unknown caller)** — patched v source + live hook; čeká na restart aby loadnul patched file
4. 🔧 **FiveM na WarMachine nebootuje bez user interaction** — Rockstar Social Club login screen; nelze autotest bez user přihlášení
5. 🔧 **morjard-phone v3 — ne-wallpaper části** — DESIGN_SPEC_V3.md má 9 sekcí, implementováno zřejmě ~70%: lock screen HTML ✅, island pill ✅, wallpaper picker ✅. Chybí: audit chování Dynamic Islandu (incoming call pill), 4-row grid room, home-clock textshadow, settings sections hierarchy. **Potřebuje in-game test**.

## Workflow každého auditu

```
1. git status check — žádné pending changes
2. Vybrat plugin z A→F
3. Backup: git tag audit-<name>-$(date +%Y%m%d)
4. Zkontroluj source:
   - fxmanifest dependencies validní?
   - client ↔ server event handlers paired?
   - RegisterNetEvent před AddEventHandler?
   - onResourceStop cleanup?
   - Žádné hardcoded Discord webhooky / API keys v public plugins?
5. Pro UI:
   - Otevření/zavření v game (přes WmAgent `/input/mouse` click + screenshot)
   - F8 console errors? NUI console errors? (potřeba manuálně — F8 → right panel)
6. Test golden path + 2-3 edge cases
7. Fix nalezené bugs
8. Deploy: rsync + exec-lua restart (viz [[server-access]])
9. Verify live: exec-lua source-read grep na patched řádek
10. Commit s referencí na audit doc
11. Memory update: záznam co se našlo + opravilo
```

## Progress tracker

| # | Group | Plugin | Stav | Audit doc | Commit |
|---|-------|--------|------|-----------|--------|
| 1 | A | morjard-bridge | todo | - | - |
| 2 | A | morjard-connector | todo | - | - |
| 3 | A | morjard-inventory | in-progress (FLOW crash fixed) | - | 55f34ed+fix |
| 4 | B | morjard-banking | todo | - | - |
| ... | | | | | |

Pozn.: tabulku updatuj při každém auditu.
