# Komunitní FiveM/QBCore resources — referenční průzkum (2026-10-01)

Čistě referenční seznam z GitHubu a `forum.cfx.re`, ne kód k okopírování. Účel: vidět, co trh už nabízí, jaký je standard funkcí, a kde je prostor pro lepší/jinou verzi pod značkou Morjard. Viz [`../products/MORJARD_SUITE_TEBEX_ROADMAP.md`](../products/MORJARD_SUITE_TEBEX_ROADMAP.md) pro skutečný produktový plán odvozený z tohohle průzkumu.

Hvězdy/popularita jsou orientační k říjnu 2026.

## Inventář & core UI
- [ox_inventory](https://github.com/overextended/ox_inventory) — de facto standard, drag&drop, crafting, weapon attachments
- [ox_lib](https://github.com/overextended/ox_lib) — sdílené UI/notifikace/zones, závislost tisíců resources
- [ps-hud](https://github.com/Project-Sloth/ps-hud) — nejpopulárnější free HUD, QBCore i Qbox
- [hyper_scoreboard](https://github.com/hyper0939/hyper_scoreboard) — ESX/QBCore/standalone

## Telefon
- [sd-phone](https://github.com/Samuels-Development/sd-phone) — QBOX/QBCORE/ESX/ox_core/ND
- [relay_phone](https://github.com/techit-oss/relay_phone) — modulární, framework-agnostic
- [sky_phone](https://github.com/sky-systems/sky_phone) — 41 appek, LB Phone migrace
- [lsfive-phone](https://github.com/Krigsexe/lsfive-phone) — React/TypeScript, framework-agnostic
- [v-phone-fivem](https://github.com/laforetbrut/v-phone-fivem) — 37 appek, qb-core/qbx_core/ox_core/ESX/Quasar

## Bydlení & garáže
- [qb-houses](https://github.com/qbcore-fivem/qb-houses) — oficiální, GPL
- [ps-housing](https://github.com/Project-Sloth/ps-housing) — gizmo nábytek, per-property stash (archivováno, funkční)
- qb-apartments — lehčí alternativa, dobrá kombinace s multicharem

## Policie / MDT / Dispatch
- [ps-mdt](https://github.com/Project-Sloth/ps-mdt) — nejpoužívanější, Svelte 5 + Lua
- [qb-policejob](https://github.com/qbcore-fivem/qb-policejob) — oficiální
- [SolidCore MDT & Dispatch](https://github.com/SolidCoreStudios/SolidCore_Studios_Police_MDT_with_Dispatch) — MDT+dispatch, CCTV, bodycam

## EMS
- [qb-ambulancejob](https://github.com/qbcore-fivem/qb-ambulancejob) — oficiální
- [ars_ambulancejob](https://github.com/Arius-Scripts/ars_ambulancejob) — ox_target/ox_inventory
- [ak47_ambulancejob](https://github.com/MenanAk47/ak47_ambulancejob) — anatomický injury systém

## Mechanik & vozidla
- [qb-vehicleshop](https://github.com/qbcore-fivem/qb-vehicleshop) — test drive, financování
- [qb-carboosting](https://github.com/fivemsmostwanted/qb-carboosting) — aktivně udržovaný
- cc-chipeo — tuning s UI (FiveM Script Creator)

## Ekonomika
- [qb-banking](https://github.com/qbcore-fivem/qb-banking) / [as-banking](https://github.com/Adyan-Scripts/as-banking)
- [qb-crypto](https://github.com/qbcore-framework/qb-crypto) — kryptoměny
- [BadgerStockMarket](https://github.com/JaredScar/BadgerStockMarket) — napojeno na reálný trh
- [ren-businesses](https://github.com/Rencikas/ren-businesses) — hráči vlastněné podniky

## Ilegální aktivity
- [md-drugs](https://github.com/Mustachedom/md-drugs)
- [qb-drugs](https://github.com/qbcore-framework/qb-drugs) — oficiální
- [QBCore-Druglabs](https://github.com/Lionh34rt/QBCore-Druglabs) — key-based laby
- [lab-Fields](https://github.com/LabScripts/lab-Fields)

## Loupeže
- [qb-bankrobbery](https://github.com/qbcore-fivem/qb-bankrobbery) / [qb-storerobbery](https://github.com/qbcore-fivem/qb-storerobbery)
- [lation_247robbery](https://github.com/IamLation/lation_247robbery) — nejpopulárnější 24/7
- [qb-bankrobbery-target](https://github.com/DafkeDD/qb-bankrobbery-target) — na target systému

## Gangy & teritoria
- [qb-territories](https://github.com/Ademo93/qb-territories) — lehké zóny
- [xex_gangwars](https://github.com/JGCdev/xex_gangwars) — dobývání zón
- dh-gangwar-qbcore-fivem — NPC gang warfare, AI

## Legální joby
- [wasabi_fishing](https://github.com/wasabirobby/wasabi_fishing)
- qb-mining, XS-Trucking, qb-truckerjob

## Admin & bezpečnost
- [EasyAdmin](https://github.com/Blumlaut/EasyAdmin)
- [el_bwh-QBCore](https://github.com/sacrefi/el_bwh-QBCore)
- [FiveM-BanSql](https://github.com/RedAlex/FiveM-BanSql)

## Sociální RP
- [sqrl-nightclubs](https://github.com/Sqrl34/sqrl-nightclubs)
- uniqers-marriage (placené)

## Minihry
- SM Hunting, F5 Safezones (forum.cfx.re, free)
- justevy/shootingrange

## Výkon / framework
- [qbcore-advanced](https://github.com/Chummbis20/qbcore-advanced) — optimalizovaný fork, 15–30 % zisk (cache proměnných, smart wait loops)
- Qbox (`qbx_core` + ox stack) — nástupce QBCore, nativně na ox_lib/ox_inventory/ox_target; player data a většina QBCore resources zůstávají kompatibilní
