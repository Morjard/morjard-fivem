-- morjard-connector: Server HTTP API + Event Hooking + Async Buffer
-- Provides external monitoring/debugging/dev endpoints for MCP

---------------------------------------------------------------------------
-- Ring Buffers
---------------------------------------------------------------------------

local MAX_EVENTS = 500
local MAX_LOGS = 1000

local eventBuffer = {}
local logBuffer = {}
local clientState = {}

--- Push an entry into a ring buffer, evicting oldest when full.
---@param buf table
---@param max number
---@param entry table
local function bufferPush(buf, max, entry)
    buf[#buf + 1] = entry
    if #buf > max then
        table.remove(buf, 1)
    end
end

--- Push an event into the event ring buffer.
---@param name string
---@param data table|nil
local function pushEvent(name, data)
    bufferPush(eventBuffer, MAX_EVENTS, {
        event = name,
        data = data or {},
        timestamp = os.time(),
        time = os.date('%Y-%m-%d %H:%M:%S'),
    })
end

--- Push a line into the log ring buffer.
---@param line string
local function pushLog(line)
    bufferPush(logBuffer, MAX_LOGS, {
        message = line,
        timestamp = os.time(),
        time = os.date('%Y-%m-%d %H:%M:%S'),
    })
end

--- Filter a buffer by a simple substring pattern on a given field.
---@param buf table
---@param last number
---@param filter string|nil
---@param field string
---@return table
local function filterBuffer(buf, last, filter, field)
    local results = {}
    local start = math.max(1, #buf - last + 1)
    for i = start, #buf do
        local entry = buf[i]
        if filter == nil or filter == '' then
            results[#results + 1] = entry
        else
            local value = entry[field]
            if value and string.find(tostring(value), filter, 1, true) then
                results[#results + 1] = entry
            end
        end
    end
    return results
end

---------------------------------------------------------------------------
-- Async Result Buffer (for trigger+poll pattern)
---------------------------------------------------------------------------

local asyncResults = {} -- [requestId] = {status='pending'|'done'|'error', data=..., ts=os.time()}

--- Generate a unique request ID
local function genRequestId()
    return tostring(GetGameTimer()) .. '-' .. math.random(100000, 999999)
end

--- Store async result
local function setAsyncResult(requestId, data, err)
    if err then
        asyncResults[requestId] = { status = 'error', error = tostring(err), ts = os.time() }
    else
        asyncResults[requestId] = { status = 'done', data = data, ts = os.time() }
    end
end

-- Cleanup old async results every 10s (older than 60s)
CreateThread(function()
    while true do
        Wait(10000)
        local now = os.time()
        for id, entry in pairs(asyncResults) do
            if now - entry.ts > 60 then
                asyncResults[id] = nil
            end
        end
    end
end)

-- Receive async results from clients
RegisterNetEvent('morjard-connector:asyncResult')
AddEventHandler('morjard-connector:asyncResult', function(requestId, data)
    if not requestId then return end
    setAsyncResult(requestId, data)
end)

---------------------------------------------------------------------------
-- Handler Registry (for hot-reload handler cleanup)
---------------------------------------------------------------------------

_G._mcpHandlers = _G._mcpHandlers or {}

--- Reload a server-side Lua script with handler cleanup
local function reloadScript(resource, file)
    local code = LoadResourceFile(resource, file)
    if not code then return { ok = false, error = 'File not found: ' .. resource .. '/' .. file } end

    local key = resource .. ':' .. file

    -- Cleanup old handlers
    if _G._mcpHandlers[key] then
        for _, h in ipairs(_G._mcpHandlers[key]) do
            RemoveEventHandler(h)
        end
    end
    _G._mcpHandlers[key] = {}

    -- Create managed environment with handler tracking
    local env = setmetatable({
        AddEventHandler = function(name, cb)
            local h = AddEventHandler(name, cb)
            table.insert(_G._mcpHandlers[key], h)
            return h
        end,
        RegisterNetEvent = RegisterNetEvent,
    }, { __index = _G })

    local fn, err = load(code, file, 't', env)
    if not fn then return { ok = false, error = err } end

    local ok, result = pcall(fn)
    return { ok = ok, result = tostring(result or ''), error = not ok and result or nil,
             handlers = #_G._mcpHandlers[key] }
end

---------------------------------------------------------------------------
-- Utility
---------------------------------------------------------------------------

--- Parse query string from path: /mcp/events?last=50&filter=player
---@param path string
---@return string basePath
---@return table params
local function parseQuery(path)
    local base, query = string.match(path, '^([^?]+)%??(.*)')
    if not base then
        return path, {}
    end
    local params = {}
    if query and query ~= '' then
        for k, v in string.gmatch(query, '([^&=]+)=([^&]*)') do
            params[k] = v
        end
    end
    return base, params
end

--- Clamp a number between min and max.
local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

--- Safe tonumber with default.
local function tonum(val, default)
    local n = tonumber(val)
    return n or default
end

--- Get first connected player ID (for default playerId)
local function getFirstPlayer()
    local count = GetNumPlayerIndices()
    if count > 0 then
        local idx = GetPlayerFromIndex(0)
        return tonumber(idx)
    end
    return nil
end

--- JSON respond helper
local function jsonResponse(res, code, data)
    res.writeHead(code, { ['Content-Type'] = 'application/json' })
    res.send(json.encode(data))
end

---------------------------------------------------------------------------
-- Command Whitelist
---------------------------------------------------------------------------

local ALLOWED_COMMANDS = {
    restart = true,
    ensure = true,
    start = true,
    stop = true,
    status = true,
    kick = true,
    mcam = true,
    mped = true,
    mlight = true,
}

--- Check if a command string starts with an allowed verb.
---@param cmd string
---@return boolean
local function isCommandAllowed(cmd)
    local verb = string.match(cmd, '^(%S+)')
    if not verb then return false end
    return ALLOWED_COMMANDS[string.lower(verb)] == true
end

---------------------------------------------------------------------------
-- Route Handlers (existing)
---------------------------------------------------------------------------

local function handleStatus()
    local playerCount = GetNumPlayerIndices()
    local resourceCount = GetNumResources()
    local uptime = GetGameTimer() -- milliseconds since server start
    local hostname = GetConvar('sv_hostname', 'Unknown')

    return json.encode({
        players = playerCount,
        resources = resourceCount,
        uptime = uptime,
        hostname = hostname,
    })
end

local function handlePlayers()
    local players = {}
    local count = GetNumPlayerIndices()

    for i = 0, count - 1 do
        local idx = GetPlayerFromIndex(i)
        if idx then
            local id = tonumber(idx)
            local name = GetPlayerName(idx)
            local ping = GetPlayerPing(idx)

            -- Gather identifiers
            local identifiers = {}
            local numIds = GetNumPlayerIdentifiers(idx)
            for j = 0, numIds - 1 do
                identifiers[#identifiers + 1] = GetPlayerIdentifier(idx, j)
            end

            -- Merge client telemetry if available
            local telemetry = clientState[id] or {}

            players[#players + 1] = {
                id = id,
                name = name,
                ping = ping,
                identifiers = identifiers,
                x = telemetry.x,
                y = telemetry.y,
                z = telemetry.z,
                heading = telemetry.heading,
                health = telemetry.health,
                armor = telemetry.armor,
                speed = telemetry.speed,
                inVehicle = telemetry.inVehicle,
                isDead = telemetry.isDead,
                fps = telemetry.fps,
                zoneName = telemetry.zoneName,
                lastUpdate = telemetry.lastUpdate,
            }
        end
    end

    return json.encode(players)
end

local function handleResources()
    local resources = {}
    local count = GetNumResources()

    for i = 0, count - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            local state = GetResourceState(name)
            local author = GetResourceMetadata(name, 'author', 0) or ''
            local version = GetResourceMetadata(name, 'version', 0) or ''
            local description = GetResourceMetadata(name, 'description', 0) or ''

            resources[#resources + 1] = {
                name = name,
                state = state,
                author = author,
                version = version,
                description = description,
            }
        end
    end

    return json.encode(resources)
end

local function handleEvents(params)
    local last = clamp(tonum(params.last, 100), 1, 500)
    local filter = params.filter
    local results = filterBuffer(eventBuffer, last, filter, 'event')
    return json.encode(results)
end

local function handleLogs(params)
    local last = clamp(tonum(params.last, 200), 1, 1000)
    local filter = params.filter
    local results = filterBuffer(logBuffer, last, filter, 'message')
    return json.encode(results)
end

local function handleClientState()
    -- Return telemetry keyed by player id (as string keys)
    local out = {}
    for id, data in pairs(clientState) do
        out[tostring(id)] = data
    end
    return json.encode(out)
end

local function handleCommand(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok or type(parsed) ~= 'table' or not parsed.command then
        res.writeHead(400, { ['Content-Type'] = 'application/json' })
        res.send(json.encode({ error = 'Invalid request body. Expected {"command": "..."}' }))
        return
    end

    local cmd = tostring(parsed.command)

    if not isCommandAllowed(cmd) then
        res.writeHead(403, { ['Content-Type'] = 'application/json' })
        res.send(json.encode({
            error = 'Command not allowed',
            allowed = { 'restart', 'ensure', 'start', 'stop', 'status', 'kick' },
        }))
        return
    end

    -- Execute the command
    ExecuteCommand(cmd)

    pushEvent('mcp:command', { command = cmd })

    res.writeHead(200, { ['Content-Type'] = 'application/json' })
    res.send(json.encode({
        success = true,
        command = cmd,
        executed = os.date('%Y-%m-%d %H:%M:%S'),
    }))
end

---------------------------------------------------------------------------
-- New Route Handlers (v2)
---------------------------------------------------------------------------

--- POST /mcp/exec-lua — Execute Lua code server-side or trigger client-side
local function handleExecLua(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok or type(parsed) ~= 'table' or not parsed.code then
        jsonResponse(res, 400, { ok = false, error = 'Expected {"code": "...", "side": "server|client"}' })
        return
    end

    local code = parsed.code
    local side = parsed.side or 'server'

    if side == 'server' then
        -- Sync server-side execution
        local fn, err = load('return (function() ' .. code .. ' end)()', 'mcp-exec', 't')
        if not fn then
            -- Try without return wrapper
            fn, err = load(code, 'mcp-exec', 't')
        end
        if not fn then
            jsonResponse(res, 200, { ok = false, error = err })
            return
        end
        local execOk, result = pcall(fn)
        if execOk then
            -- Try to JSON encode the result if it's a table
            local resultStr
            if type(result) == 'table' then
                resultStr = json.encode(result)
            else
                resultStr = tostring(result or '')
            end
            jsonResponse(res, 200, { ok = true, result = resultStr })
        else
            jsonResponse(res, 200, { ok = false, error = tostring(result) })
        end
    else
        -- Async client-side execution
        local playerId = parsed.playerId or getFirstPlayer()
        if not playerId then
            jsonResponse(res, 200, { ok = false, error = 'No players connected' })
            return
        end
        local requestId = genRequestId()
        asyncResults[requestId] = { status = 'pending', ts = os.time() }
        TriggerClientEvent('morjard-connector:execClient', playerId, requestId, code)
        jsonResponse(res, 200, { requestId = requestId })
    end
end

--- POST /mcp/reload-script — Hot-reload Lua script with handler cleanup
local function handleReloadScript(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok or type(parsed) ~= 'table' or not parsed.resource or not parsed.file then
        jsonResponse(res, 400, { ok = false, error = 'Expected {"resource": "...", "file": "..."}' })
        return
    end

    local side = parsed.side or 'server'

    if side == 'server' then
        local result = reloadScript(parsed.resource, parsed.file)
        jsonResponse(res, 200, result)
    else
        local playerId = parsed.playerId or getFirstPlayer()
        if not playerId then
            jsonResponse(res, 200, { ok = false, error = 'No players connected' })
            return
        end
        local requestId = genRequestId()
        asyncResults[requestId] = { status = 'pending', ts = os.time() }
        TriggerClientEvent('morjard-connector:reloadClient', playerId, requestId, parsed.resource, parsed.file)
        jsonResponse(res, 200, { requestId = requestId })
    end
end

--- POST /mcp/screenshot — Request game screenshot from client
local function handleScreenshot(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok then parsed = {} end

    local playerId = parsed.playerId or getFirstPlayer()
    if not playerId then
        jsonResponse(res, 200, { ok = false, error = 'No players connected' })
        return
    end

    local requestId = genRequestId()
    asyncResults[requestId] = { status = 'pending', ts = os.time() }
    TriggerClientEvent('morjard-connector:requestScreenshot', playerId, requestId, {
        encoding = parsed.encoding or 'png',
        quality = parsed.quality or 0.85,
    })
    jsonResponse(res, 200, { requestId = requestId })
end

--- POST /mcp/entities — Request entity scan from client
local function handleEntities(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok then parsed = {} end

    local playerId = parsed.playerId or getFirstPlayer()
    if not playerId then
        jsonResponse(res, 200, { ok = false, error = 'No players connected' })
        return
    end

    local requestId = genRequestId()
    asyncResults[requestId] = { status = 'pending', ts = os.time() }
    TriggerClientEvent('morjard-connector:getEntities', playerId, requestId, {
        radius = parsed.radius or 100,
        types = parsed.types,
    })
    jsonResponse(res, 200, { requestId = requestId })
end

--- POST /mcp/camera — Camera control on client
local function handleCamera(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok or type(parsed) ~= 'table' or not parsed.action then
        jsonResponse(res, 400, { ok = false, error = 'Expected {"action": "teleport|freecam|look_at|reset", ...}' })
        return
    end

    local playerId = parsed.playerId or getFirstPlayer()
    if not playerId then
        jsonResponse(res, 200, { ok = false, error = 'No players connected' })
        return
    end

    local requestId = genRequestId()
    asyncResults[requestId] = { status = 'pending', ts = os.time() }
    TriggerClientEvent('morjard-connector:cameraControl', playerId, requestId, parsed)
    jsonResponse(res, 200, { requestId = requestId })
end

--- POST /mcp/ped — Ped control on client
local function handlePed(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok or type(parsed) ~= 'table' or not parsed.action then
        jsonResponse(res, 400, { ok = false, error = 'Expected {"action": "model|anim|freeze|weapon|teleport", ...}' })
        return
    end

    local playerId = parsed.playerId or getFirstPlayer()
    if not playerId then
        jsonResponse(res, 200, { ok = false, error = 'No players connected' })
        return
    end

    local requestId = genRequestId()
    asyncResults[requestId] = { status = 'pending', ts = os.time() }
    TriggerClientEvent('morjard-connector:pedControl', playerId, requestId, parsed)
    jsonResponse(res, 200, { requestId = requestId })
end

--- POST /mcp/interior — Interior debug from client
local function handleInterior(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok then parsed = {} end

    local playerId = parsed.playerId or getFirstPlayer()
    if not playerId then
        jsonResponse(res, 200, { ok = false, error = 'No players connected' })
        return
    end

    local requestId = genRequestId()
    asyncResults[requestId] = { status = 'pending', ts = os.time() }
    TriggerClientEvent('morjard-connector:getInterior', playerId, requestId)
    jsonResponse(res, 200, { requestId = requestId })
end

--- GET /mcp/state-bag — Read state bags
local function handleStateBagRead(params)
    local target = params.target or 'global'
    local id = tonumber(params.id)
    local key = params.key

    if target == 'global' then
        if key and key ~= '' then
            return json.encode({ target = 'global', key = key, value = GlobalState[key] })
        else
            return json.encode({ target = 'global', note = 'Specify ?key=name to read a specific GlobalState key' })
        end
    elseif target == 'player' and id then
        if key and key ~= '' then
            return json.encode({ target = 'player', id = id, key = key, value = Player(id).state[key] })
        else
            return json.encode({ target = 'player', id = id, note = 'Specify ?key=name to read a specific player state key' })
        end
    elseif target == 'entity' and id then
        if key and key ~= '' then
            return json.encode({ target = 'entity', id = id, key = key, value = Entity(id).state[key] })
        else
            return json.encode({ target = 'entity', id = id, note = 'Specify ?key=name to read a specific entity state key' })
        end
    else
        return json.encode({ error = 'Invalid target or missing id', usage = '?target=global|player|entity&id=N&key=name' })
    end
end

--- POST /mcp/state-bag — Write state bags
local function handleStateBagWrite(body, res)
    local ok, parsed = pcall(json.decode, body)
    if not ok or type(parsed) ~= 'table' or not parsed.key then
        jsonResponse(res, 400, { ok = false, error = 'Expected {"target": "global|player|entity", "id": N, "key": "...", "value": ...}' })
        return
    end

    local target = parsed.target or 'global'
    local id = tonumber(parsed.id)
    local key = parsed.key
    local value = parsed.value

    if target == 'global' then
        GlobalState[key] = value
        jsonResponse(res, 200, { ok = true, target = 'global', key = key, value = value })
    elseif target == 'player' and id then
        Player(id).state:set(key, value, true)
        jsonResponse(res, 200, { ok = true, target = 'player', id = id, key = key, value = value })
    elseif target == 'entity' and id then
        Entity(id).state:set(key, value, true)
        jsonResponse(res, 200, { ok = true, target = 'entity', id = id, key = key, value = value })
    else
        jsonResponse(res, 400, { ok = false, error = 'Invalid target or missing id' })
    end
end

--- GET /mcp/metrics — Server performance metrics
local function handleMetrics()
    local uptime = GetGameTimer()
    local playerCount = GetNumPlayerIndices()
    local resourceCount = GetNumResources()

    -- Collect resource states
    local runningResources = 0
    for i = 0, resourceCount - 1 do
        local name = GetResourceByFindIndex(i)
        if name and GetResourceState(name) == 'started' then
            runningResources = runningResources + 1
        end
    end

    return json.encode({
        uptime = uptime,
        uptimeFormatted = string.format('%dd %02d:%02d:%02d',
            math.floor(uptime / 86400000),
            math.floor(uptime / 3600000) % 24,
            math.floor(uptime / 60000) % 60,
            math.floor(uptime / 1000) % 60),
        players = playerCount,
        resourcesTotal = resourceCount,
        resourcesRunning = runningResources,
        asyncPending = 0, -- count pending async operations
    })
end

--- GET /mcp/result — Poll async result
local function handleResult(params)
    local id = params.id
    if not id or id == '' then
        return json.encode({ error = 'Missing ?id= parameter' })
    end

    local entry = asyncResults[id]
    if not entry then
        return json.encode({ status = 'not_found' })
    end

    return json.encode(entry)
end

---------------------------------------------------------------------------
-- HTTP Handler
---------------------------------------------------------------------------

SetHttpHandler(function(req, res)
    -- Fail closed. This connector exposes administrative and code-execution
    -- endpoints, so an omitted key must never turn authentication off.
    local apiKey = GetConvar('mcp_api_key', '')
    if apiKey == '' then
        res.writeHead(503, { ['Content-Type'] = 'application/json' })
        res.send(json.encode({ error = 'Connector disabled: mcp_api_key is not configured' }))
        return
    end

    local reqKey = req.headers['X-MCP-Key'] or req.headers['x-mcp-key'] or ''
    if reqKey ~= apiKey then
        res.writeHead(401, { ['Content-Type'] = 'application/json' })
        res.send(json.encode({ error = 'Unauthorized' }))
        return
    end

    local path, params = parseQuery(req.path)
    local method = string.upper(req.method or 'GET')

    -- GET routes
    if method == 'GET' then
        if path == '/mcp/status' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleStatus())
            return

        elseif path == '/mcp/players' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handlePlayers())
            return

        elseif path == '/mcp/resources' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleResources())
            return

        elseif path == '/mcp/events' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleEvents(params))
            return

        elseif path == '/mcp/logs' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleLogs(params))
            return

        elseif path == '/mcp/client-state' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleClientState())
            return

        elseif path == '/mcp/result' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleResult(params))
            return

        elseif path == '/mcp/state-bag' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleStateBagRead(params))
            return

        elseif path == '/mcp/metrics' then
            res.writeHead(200, { ['Content-Type'] = 'application/json' })
            res.send(handleMetrics())
            return
        end
    end

    -- POST routes
    if method == 'POST' then
        if path == '/mcp/command' then
            req.setDataHandler(function(body) handleCommand(body, res) end)
            return

        elseif path == '/mcp/exec-lua' then
            req.setDataHandler(function(body) handleExecLua(body, res) end)
            return

        elseif path == '/mcp/reload-script' then
            req.setDataHandler(function(body) handleReloadScript(body, res) end)
            return

        elseif path == '/mcp/screenshot' then
            req.setDataHandler(function(body) handleScreenshot(body, res) end)
            return

        elseif path == '/mcp/entities' then
            req.setDataHandler(function(body) handleEntities(body, res) end)
            return

        elseif path == '/mcp/camera' then
            req.setDataHandler(function(body) handleCamera(body, res) end)
            return

        elseif path == '/mcp/ped' then
            req.setDataHandler(function(body) handlePed(body, res) end)
            return

        elseif path == '/mcp/interior' then
            req.setDataHandler(function(body) handleInterior(body, res) end)
            return

        elseif path == '/mcp/state-bag' then
            req.setDataHandler(function(body) handleStateBagWrite(body, res) end)
            return
        end
    end

    -- Not found
    res.writeHead(404, { ['Content-Type'] = 'application/json' })
    res.send(json.encode({
        error = 'Not found',
        endpoints = {
            'GET /mcp/status',
            'GET /mcp/players',
            'GET /mcp/resources',
            'GET /mcp/events?last=N&filter=pattern',
            'GET /mcp/logs?last=N&filter=pattern',
            'GET /mcp/client-state',
            'GET /mcp/result?id=requestId',
            'GET /mcp/state-bag?target=global&key=name',
            'GET /mcp/metrics',
            'POST /mcp/command',
            'POST /mcp/exec-lua',
            'POST /mcp/reload-script',
            'POST /mcp/screenshot',
            'POST /mcp/entities',
            'POST /mcp/camera',
            'POST /mcp/ped',
            'POST /mcp/interior',
            'POST /mcp/state-bag',
        },
    }))
end)

---------------------------------------------------------------------------
-- Event Hooking
---------------------------------------------------------------------------

-- Player connecting
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    pushEvent('playerConnecting', {
        source = src,
        name = name,
    })
end)

-- Player dropped
AddEventHandler('playerDropped', function(reason)
    local src = source
    local name = GetPlayerName(src)
    pushEvent('playerDropped', {
        source = src,
        name = name,
        reason = reason,
    })
    -- Clean up client telemetry
    clientState[src] = nil
end)

-- Resource start
AddEventHandler('onResourceStart', function(resourceName)
    pushEvent('onResourceStart', { resource = resourceName })
end)

-- Resource stop
AddEventHandler('onResourceStop', function(resourceName)
    pushEvent('onResourceStop', { resource = resourceName })
    -- Clean up telemetry if our own resource stops
    if resourceName == GetCurrentResourceName() then
        clientState = {}
    end
end)

-- QBCore player loaded
RegisterNetEvent('QBCore:Server:OnPlayerLoaded')
AddEventHandler('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local name = GetPlayerName(src)
    pushEvent('QBCore:Server:OnPlayerLoaded', {
        source = src,
        name = name,
    })
end)

-- QBCore player unload
RegisterNetEvent('QBCore:Server:OnPlayerUnload')
AddEventHandler('QBCore:Server:OnPlayerUnload', function()
    local src = source
    local name = GetPlayerName(src)
    pushEvent('QBCore:Server:OnPlayerUnload', {
        source = src,
        name = name,
    })
end)

-- Console output hooking
AddEventHandler('__cfx_internal:serverPrint', function(msg)
    pushLog(msg)
end)

---------------------------------------------------------------------------
-- Client Telemetry Receiver
---------------------------------------------------------------------------

RegisterNetEvent('morjard-connector:telemetry')
AddEventHandler('morjard-connector:telemetry', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    clientState[src] = data
    clientState[src].lastUpdate = os.time()
end)

RegisterNetEvent('morjard-connector:entityCount')
AddEventHandler('morjard-connector:entityCount', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if clientState[src] then
        clientState[src].nearbyVehicles = data.nearbyVehicles
        clientState[src].nearbyPeds = data.nearbyPeds
        clientState[src].nearbyObjects = data.nearbyObjects
        clientState[src].totalEntities = data.totalEntities
    end
end)

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

pushEvent('connectorStarted', {
    resource = GetCurrentResourceName(),
    version = '2.0.1',
})

local apiKey = GetConvar('mcp_api_key', '')
if apiKey == '' then
    print('^1[morjard-connector] DISABLED: mcp_api_key is not configured. All HTTP requests will be rejected.^0')
else
    print('^2[morjard-connector] API key configured. Endpoints are protected.^0')
end

print('^2[morjard-connector] v2.0.1 loaded. HTTP API ready on /mcp/* (18 endpoints)^0')
