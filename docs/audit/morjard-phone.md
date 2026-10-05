# morjard-phone — audit

- **Testováno**: 2026-10-05 in-game (Morjard.DEV, WarMachine klient přes WmAgent)
- **Otevření**: příkaz/klávesa `phone`

## Golden path
- [x] Otevření → zamykací obrazovka v3 (hodiny, datum, oznámení, „přejeď nahoru“)
- [x] Odemknutí klikem na šipku → domovská obrazovka
- [x] Nastavení → Tapeta → výběr Ember → tapeta na zamykací i domovské obrazovce, přežije zavření (localStorage)
- [x] Banka: zůstatek = HUD ($25 100), číslo účtu z charinfo
- [ ] Hovor, zprávy, kontakty, převod peněz, fotoaparát/galerie — netestováno tento průchod

## Bugs found + fixed
1. **Tapety se na celé obrazovce nevykreslily** (jen plochá barva). `url('img/…')` uložené v CSS proměnné se vyhodnotilo vůči `css/style.css` → 404. Náhledy fungovaly jen proto, že jsou inline v index.html. Fix: absolutní `/html/img/wallpapers/…`. Ověřeno ve hře.
2. **Celý telefon anglicky** (datum, popisky aplikací, nastavení, banka, prázdné stavy, hovor, notifikace). Přeloženo + `cs-CZ` formát čísel a času, datum „pondělí 5. října“.
3. **Falešné číslo karty `•••• 4821`** napevno v HTML, stejné pro všechny hráče. Teď poslední 4 znaky `charinfo.account` (server posílá `account` v `bankUpdate`).
4. Serverová notifikace „Payment received“ / popis „Transfer“ → „Přijatá platba“ / „Převod“.

## Open / design notes
- Dok s aplikacemi je vidět i na zamykací obrazovce a opakuje stejné 4 aplikace jako mřížka.
- Popisek „FOTOAPARÁT“ je širší než dlaždice.
- SVG tapety jsou hodně tmavé (Mono a Grid skoro k nerozeznání).
