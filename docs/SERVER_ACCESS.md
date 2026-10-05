# Morjard FiveM — Server & Repo Access

Jak sahat na server, co kam patří, jak nasazovat.

## Repo layout vs. live volume mapping

| Lokální | Live OVH |
|---------|----------|
| `~/Plocha/morjard-fivem/resources/<name>/` | `/var/lib/pelican/volumes/a3fc644c-.../txData/QBCore_96E3CF.base/resources/[morjard]/<name>/` |
| `~/Plocha/morjard-fivem/tebex-suite/<name>/` | `.../resources/[morjard-suite]/<name>/` |
| `~/Plocha/morjard-fivem/morjard-inventory-devtest/` | `.../resources/[morjard]/morjard-inventory-devtest/` |

`tebex-suite/` je **vlastní git submodule** (má svůj .git). Commituj v něm separately.

## GitHub

- `github.com/Morjard/morjard-fivem` — hlavní FiveM repo (master = jediná branch)
- Push: `git push origin master`
- Když origin zpředbíhne: `git fetch && git merge origin/master --allow-unrelated-histories --no-edit`
- Credentials: v `~/.claude/.../memory/servers.md` (gh token + user)

## Deploy workflow

### Jeden resource (plugin)

```bash
NAME=morjard-phone  # or whatever
LOCAL=~/Plocha/morjard-fivem/tebex-suite/$NAME
REMOTE="/var/lib/pelican/volumes/a3fc644c-2049-4be7-8e7c-23f28a5ee40b/txData/QBCore_96E3CF.base/resources/[morjard-suite]/$NAME"

# 1) rsync CELÉ složky (s trailing slash) — zachová strukturu
sshpass -p 'PASS' rsync -av --delete \
  -e "ssh -i ~/.ssh/ovh_ed25519 -o IdentitiesOnly=yes -p 64337" \
  --rsync-path='sudo rsync' \
  "$LOCAL/" ubuntu@57.129.114.181:"$REMOTE/"

# 2) restart resource bez full container restart
curl -s -X POST -H "X-MCP-Key: KEY" -H "Content-Type: application/json" \
  -d "{\"side\":\"server\",\"code\":\"ExecuteCommand(\\\"refresh\\\") Wait(500) ExecuteCommand(\\\"ensure $NAME\\\") return \\\"ok\\\"\"}" \
  http://57.129.114.181:30120/morjard-connector/mcp/exec-lua

# 3) ověř že změna je LIVE — čti source přímo ze serveru
curl -s -X POST -H "X-MCP-Key: KEY" -H "Content-Type: application/json" \
  -d "{\"side\":\"server\",\"code\":\"local f=io.open(GetResourcePath('$NAME')..'/html/index.html','r') local s=f:read('*a') f:close() return #s..'|hash='..(string.sub(s,1,80))\"}" \
  http://57.129.114.181:30120/morjard-connector/mcp/exec-lua
```

**NIKDY** nedělej `rsync FILE FILE2 FILE3 dest/` bez složky — rsync hodí všechny do dest root.

### Cache gotchy (KRITICKÉ)

- `restart <resource>` **NEreloaduje client-side `resource.rpf` cache** — klient drží starou verzi některých věcí
- Pro změny v `client/*.lua` + některé `html/*` nutný **full `docker restart`** z panelu
- `docker restart` při hráčích = ztracený unsaved inventory — používej **txAdmin graceful restart** (10s countdown s notify) pokud real players
- "server restart" (txAdmin) ≠ "docker restart" — txAdmin je rychlejší, docker clearuje víc caches

### Full server restart z CLI

```bash
# txAdmin graceful (preferuj)
curl -s -X POST -H "X-MCP-Key: KEY" -H "Content-Type: application/json" \
  -d '{"side":"server","code":"ExecuteCommand(\"quit scheduled-restart\") return \"ok\""}' \
  http://57.129.114.181:30120/morjard-connector/mcp/exec-lua
# Container Pelican restartne automaticky po 1-2s, boot ~45s

# docker/panel restart (když graceful selže)
# → přes panel UI https://panel.1337key.click/server/a3fc644c/console → "Restart"
```

## Live logs

```bash
# Živý tail
sshpass -p 'PASS' ssh -i ~/.ssh/ovh_ed25519 -p 64337 ubuntu@57.129.114.181 \
  "sudo tail -F /var/lib/pelican/volumes/a3fc644c-2049-4be7-8e7c-23f28a5ee40b/txData/default/logs/fxserver.log"

# Dnešní SCRIPT ERROR
sshpass ... "sudo tail -3000 .../logs/fxserver.log | grep -iE 'script error|invalid|warning' | tail -40"

# Dnešní log soubory (po date rollover)
sshpass ... "sudo ls -1t .../logs/fxserver*.log | head -3"
```

## MCP exec-lua endpoint (hlavní debugging surface)

- URL: `http://57.129.114.181:30120/morjard-connector/mcp/exec-lua`
- Header: `X-MCP-Key: <256-bit hex key>` (v servers.md jako `mcp_api_key`)
- Body: `{"side":"server"|"client","code":"LUA ..."}`
- Returns: `{"ok":true,"result":<string>}` nebo `{"ok":false,"error":"..."}`

### Co funguje

| Call | Funguje? |
|------|----------|
| `io.open(path, "r")` v scope `morjard-connector` | ✅ |
| `io.open(GetResourcePath('other-resource')..'/...', 'r')` | ✅ (čtení) |
| `GetResourcePath(name)` | ✅ |
| `GetConvar(key, default)` | ✅ |
| `ExecuteCommand("refresh")`, `ExecuteCommand("ensure NAME")` | ✅ |
| `QBCore.Functions.GetPlayer(src)` | ✅ |
| `TriggerEvent`, `TriggerClientEvent` | ✅ |
| `io.popen` | ❌ sandbox |
| `_G.openUI` z jiného resource | ❌ scope limitation |
| `MorjardTools.X` z morjard-editor shared | ❌ shared není visible |
| `MySQL.query(...)` | ✅ (přes oxmysql export) |

### Verifikace deploye

**"restart nevyhodil SCRIPT ERROR" ≠ "deploy je live"** — vždy čti source přímo přes exec-lua:

```lua
local f = io.open(GetResourcePath('morjard-bridge') .. '/server/bridge.lua', 'r')
return f and f:read('*a'):match('RemoveItem[^\n]+morjard%-bridge[^\n]+') or 'NOT_FOUND'
```

Pokud vrátí tvůj patched řádek, deploy je skutečně live.

## txAdmin console (přes exec-lua)

```lua
-- Spustit libovolný console command
ExecuteCommand("quit scheduled-restart")  -- graceful quit
ExecuteCommand("players")                   -- list players
ExecuteCommand("stop RESOURCE")             -- stop one
ExecuteCommand("start RESOURCE")            -- start one
ExecuteCommand("restart RESOURCE")          -- restart one (prefer refresh+ensure)
```

## Když mcp exec-lua nefunguje

Fallback — přímé SSH + console:

```bash
# Pošli command do FXServer console přes txAdmin HTTP API
# (vyžaduje txAdmin login + CSRF; raději přes exec-lua)
```

## Co je kam

- **FiveM resources** (všechno nasazené) → `tebex-suite/` nebo `resources/`
- **Dokumentace projektu** → `docs/*.md` v morjard-fivem (sdílí s teamem)
- **Osobní poznámky** → `~/.claude/.../memory/*.md` (Claude memory, nejde na GitHub)
- **Backup pre risky edit** → `.bak.YYYYMMDD` suffix nebo git tag
- **Scratchpad** → `/tmp/claude-1000/.../scratchpad/` (session only)
