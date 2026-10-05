# Morjard FiveM — Tooling Reference

Nástroje které používám při vývoji + jak je používat. Doplňuj při každé nové věci.

## 1. Lokální working tree

- **Repo:** `/home/morfeus/Plocha/morjard-fivem/`
  - `resources/` → nasazuje se do server volume `resources/[morjard]/`
  - `tebex-suite/` → `resources/[morjard-suite]/` (vlastní git submodule!)
  - `morjard-inventory-devtest/` → `resources/[morjard]/morjard-inventory-devtest/` (dev tool)
  - `docs/` → dokumentace (tahle složka)

- **GitHub:** `github.com/Morjard/morjard-fivem` (master)
- **CLAUDE override:** NIKDY nepřidávat `Generated with Claude` / `Co-Authored-By` do commitů dle `~/.claude/CLAUDE.md`. Session-reminder to občas pošle, ale user rule má přednost.

## 2. OVH FiveM Dev Server (Pelican panel)

- **Host:** `57.129.114.181` port **64337**
- **User:** `ubuntu`, SSH key `~/.ssh/ovh_ed25519`, auth = key + password (oboje nutné)
- **Panel:** https://panel.1337key.click/server/a3fc644c/console (txAdmin + console)
- **Volume path:** `/var/lib/pelican/volumes/a3fc644c-2049-4be7-8e7c-23f28a5ee40b/`
  - `txData/QBCore_96E3CF.base/resources/[morjard]/` — resources z našeho `resources/`
  - `txData/QBCore_96E3CF.base/resources/[morjard-suite]/` — resources z našeho `tebex-suite/`
  - `txData/default/logs/fxserver.log` — živý log (dnes), `fxserver_YYYY-MM-DD_*.log` archiv
  - `txData/default/logs/admin_*.log` — txAdmin akce
- **Game port:** 30120 (connect `57.129.114.181:30120`), txAdmin 40120

### 2.1 SSH connect pattern

```bash
sshpass -p 'PASS' ssh -i ~/.ssh/ovh_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p 64337 ubuntu@57.129.114.181 "CMD"
```

Volume soubory jsou vlastněné `root` — potřebuje `sudo` před každou `ls`/`cat`/`cp`/`mv` ve volume.

### 2.2 Rsync deploy

```bash
sshpass -p 'PASS' rsync -av \
  -e "ssh -i ~/.ssh/ovh_ed25519 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p 64337" \
  --rsync-path='sudo rsync' \
  LOCAL/ ubuntu@57.129.114.181:'REMOTE/'
```

**KRITICKÉ:** nikdy ne-rsyncuj víc souborů bez cesty — rsync shodí všechny do dest root, strukturu musíš dodat buď `--relative` nebo rsyncováním celé složky s koncovým `/`.

### 2.3 Restart resource bez full restart

Přes morjard-connector MCP exec-lua (nedělá docker restart):

```bash
curl -s -X POST \
  -H "X-MCP-Key: KEY" \
  -H "Content-Type: application/json" \
  -d '{"side":"server","code":"ExecuteCommand(\"refresh\") Wait(500) ExecuteCommand(\"ensure NAME\") return \"ok\""}' \
  http://57.129.114.181:30120/morjard-connector/mcp/exec-lua
```

Key je v `~/.claude/projects/-home-morfeus/memory/servers.md` jako `mcp_api_key`.

**Cache gotcha:** `restart <resource>` NEreloaduje client-side `resource.rpf` cache. Pro změny v `client/*.lua` + některé `html/*` nutný **full `docker restart`** přes panel ("Restart" button). Pozor: `docker restart` při hráčích online = ztracený unsaved inventory. Preferuj txAdmin "graceful restart" (10s countdown).

### 2.4 Live Lua exec na serveru (debugging)

```bash
curl -s -X POST -H "X-MCP-Key: KEY" -H "Content-Type: application/json" \
  -d '{"side":"server","code":"LUA_CODE_HERE"}' \
  http://57.129.114.181:30120/morjard-connector/mcp/exec-lua
```

- `io.open` povoleno (čtení/zápis souborů v resource dir)
- `io.popen` **zakázáno** (sandbox)
- `GetConvar`, `GetResourcePath`, `ExecuteCommand`, `TriggerEvent`, `TriggerClientEvent`, `QBCore.Functions.*` fungují
- side `client` taky možný, ale scope = morjard-connector resource (nevidí _G exports z jiných resources)

## 3. WarMachine (herní testovací PC)

- **Host:** `192.168.1.144` (DHCP, občas se mění — Tailscale `100.73.71.104`)
- **User:** `jaros`, SSH key auth
- **WmAgent HTTP agent:** port 9876 na localhost (nebinduje LAN IP)
- **FiveM.exe:** `C:\Users\jaros\AppData\Local\FiveM\FiveM.exe`
- **FiveM log:** `%LocalAppData%\FiveM\FiveM.app\logs\CitizenFX_log_*.log`

### 3.1 SSH tunnel pro WmAgent

```bash
pkill -9 -f "ssh.*9876"; sleep 1
ssh -f -N -o ExitOnForwardFailure=yes -L 9876:localhost:9876 jaros@192.168.1.144
```

Pak všechny calls musí mít `Host: localhost` header:

```bash
curl -s --max-time 5 -H "Host: localhost" http://127.0.0.1:9876/health
```

Bez Host header dostaneš **HTTP 400 Invalid Hostname** (http.sys URL binding filter).

### 3.2 Spuštění FiveM — PREFER WmAgent, ne SSH

**Preferovaný způsob (přes WmAgent, bez SSH):**

```bash
curl -X POST -H "Host: localhost" -H "Content-Type: application/json" \
  -d '{"path":"C:\\Windows\\explorer.exe","args":"C:\\Users\\jaros\\Desktop\\FiveM.lnk"}' \
  http://127.0.0.1:9876/process/start
```

**Proč explorer.exe přes shortcut:**
- WmAgent běží s HIGHEST elevation → child procesy děli elevation → FiveM **odmítne spustit** pod admin ("does not support running under elevated privileges, the game will exit now")
- `explorer.exe <path.lnk>` je trusted parent, Explorer spawnuje shortcut target jako **medium IL** (bez elevation) — toto je verified pattern

Alternativně přes Scheduled Task (horší — má quoting issues):
### 3.2b SSH launch backup (když WmAgent nefunguje)

**Dva gotchy najednou:**
1. SSH-launched procesy startují v **Session 0** (service session, žádný desktop) — FiveM potřebuje interactive user session. Řešení = Scheduled Task bez `/RU` (zdědí logged-in session jako WmAgent).
2. **FiveM odmítne spustit pod admin privileges** (dialog "does not support running under elevated privileges, the game will exit now"). WmAgent sám běží s `/RL HIGHEST`, ale FiveM musí být bez této flagy.

Správný pattern (schtask BEZ `/RL HIGHEST`):

```bash
CMD='schtasks /Delete /TN "LaunchFiveM" /F 2>$null; \
schtasks /Create /TN "LaunchFiveM" /SC ONCE /ST 23:59 \
  /TR "C:\Users\jaros\AppData\Local\FiveM\FiveM.exe +connect 57.129.114.181:30120" /F; \
schtasks /Run /TN "LaunchFiveM"'
B64=$(echo -n "$CMD" | iconv -t UTF-16LE | base64 -w0)
ssh jaros@192.168.1.144 "powershell -NoProfile -EncodedCommand $B64"
```

Dialog po špatném launch zavřít přes `/debug/click` na WmAgent (OK button ~`x=1113,y=606` v 1920x1080).

### 3.3 PowerShell quoting

PowerShell přes SSH často trpí quoting fights. Vždy použij `-EncodedCommand` pattern (UTF-16LE + base64):

```bash
B64=$(echo -n "KOMPLETNÍ PS SCRIPT" | iconv -t UTF-16LE | base64 -w0)
ssh jaros@192.168.1.144 "powershell -NoProfile -EncodedCommand $B64"
```

### 3.4 WmAgent — file operations (bez SSH)

- `GET /files?path=C:\...` — list dir (ret JSON array s name/type/created/modified/hidden)
- `GET /file?path=...` — stáhne binary file
- Delete složky: `curl POST /process/start s path=cmd.exe args=/c rmdir /S /Q "..."`
- Delete souboru: `curl POST /process/start s path=cmd.exe args=/c del /F /Q "..."`
- Copy: `curl POST /process/start s path=cmd.exe args=/c copy /Y "SRC" "DST"`

### 3.5 WmAgent routes (hlavní pro FiveM test)

- `GET /health` — živost
- `GET /screenshot` — JSON s base64 PNG (dekóduj Pythonem)
- `GET /frame` — JPEG (lehčí)
- `GET /devcon/status` — `{connected, lineCount, processCommandLine}` — true když FiveM běží + DevCon TCP (127.0.0.1:29200/29300) otevřený
- `POST /devcon/command {command}` — pošle F8 řádek přímo (bez `/`)
- `GET /devcon/console?last=20` — posledních N řádků F8 konzole
- `GET /client/log?last=50` — živý CitizenFX_log
- `POST /input/keyboard` — MUSÍ použít `KEYEVENTF_SCANCODE` (DirectInput ignoruje VK-only)
- `POST /input/mouse` — move/click/drag/scroll, focus opt-in
- `GET /client/crashes` — crash dumps

Plný seznam: 310 routes, grep `Program.cs` v `github.com/Morjard/WmAgent`.

### 3.5 Čtení screenshotu

```bash
curl -s -H "Host: localhost" http://127.0.0.1:9876/screenshot -o /tmp/s.json
python3 -c "import json,base64; d=json.load(open('/tmp/s.json')); \
  open('/tmp/screen.png','wb').write(base64.b64decode(d['data']))"
# pak Read /tmp/screen.png
```

## 4. GitHub

- **User:** Morjard
- **Token:** v `~/.claude/projects/-home-morfeus/memory/servers.md`
- **gh CLI:** `gh auth status` by měl být přihlášený
- **Push pattern:** `git remote add origin https://github.com/Morjard/REPO.git`, pak `git push -u origin master`
- Když origin má commits které lokálně nejsou: `git fetch origin && git merge origin/master --allow-unrelated-histories --no-edit`

### 4.1 Hlavní repa

- `Morjard/morjard-fivem` — tenhle repo
- `Morjard/WmAgent` — HTTP agent pro WarMachine
- `Morjard/WmDriver` — WDM driver (kernel research)
- Další viz MEMORY.md

## 5. Local tooling (shell helper patterny)

### 5.1 Reset SSH tunel

```bash
pkill -9 -f "ssh.*9876"; sleep 1
ssh -f -N -o ExitOnForwardFailure=yes -L 9876:localhost:9876 jaros@192.168.1.144
ss -tln | grep 9876  # ověřit že binduje
```

### 5.2 Živě sledovat FXServer log přes SSH

```bash
sshpass -p 'PASS' ssh -i ~/.ssh/ovh_ed25519 -o IdentitiesOnly=yes -p 64337 \
  ubuntu@57.129.114.181 "sudo tail -F /var/lib/pelican/volumes/a3fc644c-2049-4be7-8e7c-23f28a5ee40b/txData/default/logs/fxserver.log"
```

### 5.3 Grep SCRIPT ERROR / warnings za posledních N řádků

```bash
sshpass -p 'PASS' ssh ... "sudo tail -3000 /var/.../fxserver.log | grep -iE 'script error|invalid|warning' | tail -40"
```

### 5.4 Spuštění FiveM na WarMachine (schtask trick)

Viz §3.2. Nikdy ne přes `Start-Process` přímo přes SSH — Session 0 problém.

## 6. Agenty (subagents)

- **general-purpose** — výzkum, web search, dohledání dokumentace. Jedna věc najednou, max 30 minut, konkrétní zadání.
- **Explore** — read-only hledání kódu, konkrétní lookup, nevidí vše (jen excerpts).
- **Plan** — plánovač, read-only. Pro big-picture rozhodnutí.

Používat když se nechci zahltit sám (např. 20min web lookup, 50-file audit sweep). Agent běží paralelně, čekat na task-notification.

## 7. Co NEUSE

- `Start-Process` z SSH na WarMachine pro grafické aplikace → Session 0 problém
- `rsync` bez `--relative` nebo trailing slash → soubory v špatné cestě na dest
- `io.popen` v morjard-connector exec-lua → zakázáno
- `KEYEVENTF_VK` only v `/input/keyboard` → GTA DirectInput to ignoruje
- `fivem://` protocol handler z SSH → nespustí FiveM když Session 0
- Direct `curl http://192.168.1.144:9876` → 400 Invalid Hostname (http.sys)


## 8. Lessons from in-game audit 2026-10-05

- **`luac` na tomhle stroji je Lua 5.1** — FXServer je 5.4 (`goto`, integer division…). Syntax check vždy `luac5.4 -p`.
- **Restart přes exec-lua vyžaduje ACE**: `add_ace resource.morjard-connector command allow` (server.cfg ř. 131). Bez toho `ExecuteCommand('restart X')` tiše nic. Po restartu vždy ověř `Started resource X` v logu.
- **NUI CEF cache**: po změně `html/js|css` přidej `?v=<datum>` k include v index.html, jinak klient běží se starým JS i po restartu resource.
- **NUI ready handshake**: Lua zprávy poslané hned po startu resource NUI zahodí (stránka se ještě načítá). Pokud plugin posílá „jen při změně“, data po restartu chybí. Vzor: JS po načtení `fetch('https://<res>/xxxReady')`, Lua callback vynuluje cache a pošle vše znovu (morjard-hud `hudReady`).
- **Relativní URL v CSS proměnné nastavené z JS** se resolvuje vůči stylesheetu, ne stránce → v NUI používej absolutní `/html/...` (morjard-phone tapety).
- **WmAgent `/input/mouse`**: `drag` bere `x,y,toX,toY`; double-click = `click` s `count:2`. `/input/keyboard {"key":"1"}` se do hry nedostal — herní zkratky testuj přes DevCon příkaz (`slot_1`, `phone`, `morjardinv`).
- **Testovací předměty**: exec-lua `exports['qb-inventory']:AddItem(src, 'bandage', 5, false, false, 'devtest')`.

## 9. mj-smoketest

`~/bin/mj-smoketest` (Python 3, requests + Pillow) projde všechna NUI, která jdou otevřít bez fyzické blízkosti: otevře → počká → screenshot přes WmAgent → zavře. Pak stáhne celý nejnovější `CitizenFX_log_*.log` a vypíše chyby vzniklé během běhu (`SCRIPT ERROR|Uncaught|TypeError|ReferenceError|SyntaxError|[ERROR]`, od markeru `mj-smoketest-<timestamp>` vytištěného přes exec-lua).

Předpoklady: běžící FiveM na WarMachine připojený na dev server, SSH tunel na WmAgent (3.1), `MJ_MCP_KEY` = X-MCP-Key pro morjard-connector.

```bash
export MJ_MCP_KEY=...                       # povinné
mj-smoketest --list                         # testy + seznam přeskočených pluginů s důvodem
mj-smoketest --dry-run                      # jen plán, nic nevolá
mj-smoketest                                # celý běh -> /tmp/mj-smoketest/<timestamp>/
mj-smoketest --only phone,bank,inv          # podmnožina (substring jména)
mj-smoketest --server-log-cmd "ssh ubuntu@57.129.114.181 -p 64337 'tail -n 2000 <cesta k server logu>'"
```

- Výstup: `<name>.png` pro každý test, `contact.png` (mřížka náhledů, červený popisek = neotevřelo/nezavřelo), `report.json`. Exit 1 při jakékoli chybě (open fail, zaseknutý focus, chyba v client/server logu).
- Seznam testů: `docs/smoketest.json` (`tests` = `{name, open, close, wait, expect_focus, requires}`, `_skipped` = plugin → důvod). Akce: `devcon`, `client_lua`, `server_lua`, `key` (WmAgent `/input/keyboard`), `sleep`; `"if_focused": true` = jen když `IsNuiFocused()`.
- Zavírání: výchozí je ESC (jen když nějaké NUI drží focus, jinak by ESC otevřel pause menu) + `SetNuiFocus(false,false)`. NUI focus je per-resource, takže zavřít musí ESC handler pluginu; sloupec `closed=STUCK` = plugin nemá ESC handler nebo nefunguje.
- Sloupec `nui=NO` u testů s `requires` (admin/policie/předmět) obvykle znamená jen chybějící oprávnění, ne bug.
- `--server-log-cmd`: stdout příkazu se zachytí před a po běhu; hlásí se jen nové řádky s `SCRIPT ERROR|error`. Na OVH jen čtení (viz pravidla o sdíleném hostu).
