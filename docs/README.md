# morjard-fivem — konsolidovaný, vyčištěný FiveM balíček

Nová čistá složka (`~/Plocha/morjard-fivem/`), oddělená od rozházeného `~/Plocha/morjard/`. Vzniklo 2026-10-01 na základě projetí `~/Plocha/morjard` a živého FiveM serveru na OVH (`a3fc644c`, read-only — žádný zápis na server v tomto kroku).

## Co je uvnitř (`resources/`)

| Resource | Zdroj (novější verze) | Stav |
|---|---|---|
| `rp-chat` | OVH server (24.9., novější než lokál 21.3.) | ✅ čistý, propojen s hybridním stylem (viz níž) |
| `morjard_target` | OVH server (23.9.) | ✅ **opraveno**: interně byl pořád `ddcz_target` (manifest „DDCZ Dev Team", exporty/eventy `ddcz_target:...`) — přejmenováno na `morjard_target` všude |
| `morjard-weathersystem` | OVH server | beze změny, obsahuje už dřívější optimalizace (viz níž) |
| `morjard-multicharacter` | shodné na obou stranách | beze změny, čistý |
| `morjard-loadingscreen` | OVH server (skutečně nasazená verze z `[standalone]`) | beze změny, čistý |
| `morjard-spawn-selector` | pouze lokálně, na serveru vůbec není | beze změny, čistý |
| `morjard-connector` | lokálně | beze změny, čistý (1 starý `.b64` screenshot se slovem „ddcz" uvnitř obrázku, neškodné) |
| **`morjard-settings`** | nově vytvořeno | hybridní přepínač stylu Morjard/DDCZ, viz `docs/HYBRID_STYLE.md` |

**DDCZ loading screen ani jiný DDCZ-brandovaný obsah sem záměrně nešel** — jediné, co bylo „psáno jako ddcz" a přesto patří dovnitř, byl `morjard_target` (interně `ddcz_target`), a ten je teď přejmenovaný.

## Hybridní styl (Morjard / DDCZ)

Viz [`HYBRID_STYLE.md`](HYBRID_STYLE.md). V kostce: `resources/morjard-settings/shared/settings.lua` → `Config.ActiveStyle = 'morjard' | 'ddcz'`, reálné palety z vašich vlastních starších (DDCZ) a současných (Morjard) zdrojů. Zapojeno a funkčně ověřeno v `rp-chat`. Čeká na zapojení do `morjard-loadingscreen`, `morjard-multicharacter`, `morjard-spawn-selector` (stejný vzor, viz docs).

**Slovo „ddcz" v `morjard-settings` a v téhle dokumentaci je záměrné** — je to jméno jednoho ze dvou volitelných stylů, přesně jak jsi chtěl. To je jiná věc než DDCZ branding uvnitř resource metadat (ten jsem odstranil z `morjard_target`).

## Nasazení na server (zatím NEUDĚLÁNO)

Nic z tohohle jsem na OVH server nezapsal — jen jsem z něj četl/stahoval. Až budeš chtít nasadit (hlavně přejmenovaný `morjard_target` a nový `morjard-settings`), řekni a udělám to s zálohou a bez restartu běžící hry, pokud to půjde za chodu (resource restart `morjard_target` ano, `ensure morjard-settings` přidat do `server.cfg`).

## Další krok: optimalizace (probíhá průběžně)

Rychlý první průzkum už něco ukázal:
- `morjard-weathersystem` **už má** dřívější optimalizace zdokumentované přímo v kódu (komentáře „FIX: Was Wait(0)… now Wait(200)" na 5 místech) — zbývají 2 aktivní `Wait(0)` smyčky k prověření (řádky 460, 897).
- `morjard_target` má 2 aktivní `Wait(0)` smyčky (`utils.lua:20`, `main.lua:167`) — kandidáti na snížení zátěže, potřebují prověřit logiku každé zvlášť (ne slepě zvýšit interval).

Pokračuju v tomhle průchodu přes JS/Lua napříč resources (latence, zbytečné natives ve smyčkách, zbytné výpočty) bez čekání na další pokyn.
