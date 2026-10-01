# Bezpečnost: morjard-connector (MCP debug/exec API)

**2026-10-01, nalezeno a opraveno.**

## Co to je a proč je to vážné

`morjard-connector` vystavuje HTTP API pro MCP vývojářské nástroje (`SetHttpHandler`, cesta `/<resourcename>/mcp/...`). Vlastní komentář v kódu to popisuje přesně: *"This connector exposes administrative and code-execution endpoints."* Mimo jiné `POST /mcp/exec-lua` — **vzdálené spuštění libovolného Lua kódu na serveru**.

## Nález

- Endpoint je **dostupný z celého internetu** — `SetHttpHandler` se multiplexuje na stejný port jako samotná hra (`30120`), takže ho nejde vyfiltrovat firewallem bez zablokování hry samotné.
- Chráněn jen jedním statickým klíčem v `server.cfg` (hlavička `X-MCP-Key`), **bez rate limitu, bez omezení na IP**.
- Klíč byl `morjard-mcp-secret-2026` — čitelná, uhodnutelná fráze, ne náhodný token.
- Ověřeno živě z internetu: `curl -H "X-MCP-Key: morjard-mcp-secret-2026" http://57.129.114.181:30120/morjard-connector/mcp/status` → `200 OK` s reálnými daty serveru.

## Oprava (provedeno)

Klíč nahrazen 256bitovým náhodným hex řetězcem (`openssl rand -hex 32`) v `server.cfg` (`set mcp_api_key ...`, záloha `server.cfg.bak-*` uložena vedle). Živé přenastavení přes konzolový `set` se neprojevilo (stejná nespolehlivost jako u `ensure`/`refresh` příkazů přes websocket API), takže aplikováno přes restart serveru (0 hráčů online, bezpečné).

Nový klíč je uložen v `~/.claude/projects/-home-morfeus/memory/` (ne v tomto repu — nepatří do gitu).

## Co ještě zvážit (neudělané, doporučení)

- **IP allowlist** uvnitř `SetHttpHandler` (`server/main.lua` kolem řádku 649) jako druhá vrstva — nedořešeno, protože přesný název pole s IP klienta v `req` objektu FXServer HTTP handleru jsem nemohl ověřit bez živého testu (server zrovna restartoval). Než to přidáš, ověř v FXServer dokumentaci/changelogu přesné jméno pole (pravděpodobně `req.address`), otestuj na serveru a teprve pak nasaď — špatně implementovaná kontrola by mohla buď tiše nefungovat, nebo zablokovat legitimní přístup.
- Zvážit, jestli `exec-lua` endpoint vůbec potřebuješ trvale aktivní na produkčním serveru, nebo jestli by šlo `morjard-connector` zapínat jen při aktivním vývoji (`ensure`/`stop` podle potřeby) místo nepřetržitého běhu.
- 256bitový náhodný klíč sám o sobě dělá brute-force prakticky nemožný (2^256 kombinací) — i bez IP allowlistu je tohle teď v pořádku zabezpečené, IP allowlist je jen bonus obrana do hloubky.

## Jak klíč znovu otočit, kdyby bylo potřeba

```bash
NEWKEY=$(openssl rand -hex 32)
# na serveru: sed -i "s/set mcp_api_key .*/set mcp_api_key $NEWKEY/" server.cfg
# pak restart serveru (set convar se čte jen při startu, resource restart nestačí)
```
