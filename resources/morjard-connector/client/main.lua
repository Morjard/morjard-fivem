-- morjard-connector: Client Telemetry + MCP Event Handlers
-- Collects player state and handles MCP commands from server

---------------------------------------------------------------------------
-- Telemetry (existing)
---------------------------------------------------------------------------

-- Main telemetry loop (every 2 seconds)
CreateThread(function()
    while true do
        Wait(2000)

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        local data = {
            fps = math.floor(1.0 / GetFrameTime()),
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = GetEntityHeading(ped),
            health = GetEntityHealth(ped),
            armor = GetPedArmour(ped),
            speed = GetEntitySpeed(ped),
            inVehicle = IsPedInAnyVehicle(ped, false),
            isDead = IsEntityDead(ped),
            isSwimming = IsPedSwimming(ped),
            isFalling = IsPedFalling(ped),
            isRagdoll = IsPedRagdoll(ped),
            zoneName = GetNameOfZone(coords.x, coords.y, coords.z),
        }

        if data.inVehicle then
            local veh = GetVehiclePedIsIn(ped, false)
            data.vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
            data.vehicleSpeed = math.floor(GetEntitySpeed(veh) * 3.6) -- km/h
            data.vehicleHealth = GetVehicleEngineHealth(veh)
        end

        TriggerServerEvent('morjard-connector:telemetry', data)
    end
end)

-- Entity count reporting (every 10 seconds)
CreateThread(function()
    while true do
        Wait(10000)

        local vehicleCount = 0
        local pedCount = 0
        local objectCount = 0

        local vehicles = GetGamePool('CVehicle')
        if vehicles then vehicleCount = #vehicles end

        local peds = GetGamePool('CPed')
        if peds then pedCount = #peds end

        local objects = GetGamePool('CObject')
        if objects then objectCount = #objects end

        local entityData = {
            nearbyVehicles = vehicleCount,
            nearbyPeds = pedCount,
            nearbyObjects = objectCount,
            totalEntities = vehicleCount + pedCount + objectCount,
        }

        TriggerServerEvent('morjard-connector:entityCount', entityData)
    end
end)

---------------------------------------------------------------------------
-- MCP: Client Lua Exec
---------------------------------------------------------------------------

RegisterNetEvent('morjard-connector:execClient')
AddEventHandler('morjard-connector:execClient', function(requestId, code)
    -- Try with return wrapper first
    local fn, err = load('return (function() ' .. code .. ' end)()', 'mcp-exec', 't')
    if not fn then
        fn, err = load(code, 'mcp-exec', 't')
    end
    if not fn then
        TriggerServerEvent('morjard-connector:asyncResult', requestId, { ok = false, error = err })
        return
    end
    local ok, result = pcall(fn)
    if ok then
        local resultStr
        if type(result) == 'table' then
            resultStr = json.encode(result)
        else
            resultStr = tostring(result or '')
        end
        TriggerServerEvent('morjard-connector:asyncResult', requestId, { ok = true, result = resultStr })
    else
        TriggerServerEvent('morjard-connector:asyncResult', requestId, { ok = false, error = tostring(result) })
    end
end)

---------------------------------------------------------------------------
-- MCP: Entity Inspector
---------------------------------------------------------------------------

RegisterNetEvent('morjard-connector:getEntities')
AddEventHandler('morjard-connector:getEntities', function(requestId, options)
    local entities = {}
    local maxDist = options and options.radius or 100.0
    local myCoords = GetEntityCoords(PlayerPedId())
    local typeFilter = options and options.types

    local function shouldScan(typeName)
        if not typeFilter then return true end
        for _, t in ipairs(typeFilter) do
            if t == typeName then return true end
        end
        return false
    end

    -- CVehicle pool
    if shouldScan('vehicle') then
        local pool = GetGamePool('CVehicle')
        if pool then
            for _, veh in ipairs(pool) do
                local coords = GetEntityCoords(veh)
                if #(myCoords - coords) <= maxDist then
                    local primary, secondary = GetVehicleColours(veh)
                    local netId = 0
                    if NetworkGetEntityIsNetworked(veh) then
                        netId = NetworkGetNetworkIdFromEntity(veh)
                    end
                    entities[#entities + 1] = {
                        handle = veh,
                        type = 'vehicle',
                        networkId = netId,
                        archName = GetEntityArchetypeName(veh) or '',
                        modelHash = string.format('0x%X', GetEntityModel(veh)),
                        coords = { x = coords.x, y = coords.y, z = coords.z },
                        heading = GetEntityHeading(veh),
                        health = GetVehicleEngineHealth(veh),
                        bodyHealth = GetVehicleBodyHealth(veh),
                        speed = math.floor(GetEntitySpeed(veh) * 3.6),
                        colors = { primary = primary, secondary = secondary },
                        livery = GetVehicleLivery(veh),
                        isNetworked = NetworkGetEntityIsNetworked(veh),
                    }
                end
            end
        end
    end

    -- CPed pool
    if shouldScan('ped') then
        local pool = GetGamePool('CPed')
        if pool then
            for _, p in ipairs(pool) do
                local coords = GetEntityCoords(p)
                if #(myCoords - coords) <= maxDist then
                    local netId = 0
                    if NetworkGetEntityIsNetworked(p) then
                        netId = NetworkGetNetworkIdFromEntity(p)
                    end
                    local _, weaponHash = GetCurrentPedWeapon(p)
                    entities[#entities + 1] = {
                        handle = p,
                        type = 'ped',
                        networkId = netId,
                        archName = GetEntityArchetypeName(p) or '',
                        modelHash = string.format('0x%X', GetEntityModel(p)),
                        coords = { x = coords.x, y = coords.y, z = coords.z },
                        heading = GetEntityHeading(p),
                        health = GetEntityHealth(p),
                        armor = GetPedArmour(p),
                        isDead = IsEntityDead(p),
                        isPlayer = IsPedAPlayer(p),
                        weapon = string.format('0x%X', weaponHash),
                        isNetworked = NetworkGetEntityIsNetworked(p),
                    }
                end
            end
        end
    end

    -- CObject pool
    if shouldScan('object') then
        local pool = GetGamePool('CObject')
        if pool then
            for _, obj in ipairs(pool) do
                local coords = GetEntityCoords(obj)
                if #(myCoords - coords) <= maxDist then
                    local netId = 0
                    if NetworkGetEntityIsNetworked(obj) then
                        netId = NetworkGetNetworkIdFromEntity(obj)
                    end
                    entities[#entities + 1] = {
                        handle = obj,
                        type = 'object',
                        networkId = netId,
                        archName = GetEntityArchetypeName(obj) or '',
                        modelHash = string.format('0x%X', GetEntityModel(obj)),
                        coords = { x = coords.x, y = coords.y, z = coords.z },
                        heading = GetEntityHeading(obj),
                        health = GetEntityHealth(obj),
                        isNetworked = NetworkGetEntityIsNetworked(obj),
                    }
                end
            end
        end
    end

    TriggerServerEvent('morjard-connector:asyncResult', requestId, entities)
end)

---------------------------------------------------------------------------
-- MCP: Camera Control
---------------------------------------------------------------------------

local _mcpCamera = nil

RegisterNetEvent('morjard-connector:cameraControl')
AddEventHandler('morjard-connector:cameraControl', function(requestId, opts)
    local action = opts.action
    local ped = PlayerPedId()
    local result = {}

    if action == 'teleport' then
        local x = tonumber(opts.x) or 0
        local y = tonumber(opts.y) or 0
        local z = tonumber(opts.z) or 0
        local heading = tonumber(opts.heading)
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        if heading then SetEntityHeading(ped, heading) end
        result = { ok = true, action = 'teleport', coords = { x = x, y = y, z = z } }

    elseif action == 'freecam' then
        local coords = GetEntityCoords(ped)
        local rot = GetEntityRotation(ped)
        if _mcpCamera then DestroyCam(_mcpCamera, false) end
        _mcpCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(_mcpCamera, opts.x or coords.x, opts.y or coords.y, opts.z or (coords.z + 2.0))
        SetCamRot(_mcpCamera, rot.x, rot.y, opts.heading or rot.z, 2)
        SetCamFov(_mcpCamera, 50.0)
        RenderScriptCams(true, false, 0, true, true)
        FreezeEntityPosition(ped, true)
        SetEntityVisible(ped, false, false)
        result = { ok = true, action = 'freecam', active = true }

    elseif action == 'look_at' then
        local x = tonumber(opts.x) or 0
        local y = tonumber(opts.y) or 0
        local z = tonumber(opts.z) or 0
        if _mcpCamera then
            PointCamAtCoord(_mcpCamera, x, y, z)
            result = { ok = true, action = 'look_at', target = { x = x, y = y, z = z } }
        else
            -- Create temp cam at current ped position
            local coords = GetEntityCoords(ped)
            _mcpCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
            SetCamCoord(_mcpCamera, coords.x, coords.y, coords.z + 2.0)
            PointCamAtCoord(_mcpCamera, x, y, z)
            RenderScriptCams(true, false, 0, true, true)
            result = { ok = true, action = 'look_at', target = { x = x, y = y, z = z } }
        end

    elseif action == 'reset' then
        if _mcpCamera then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(_mcpCamera, false)
            _mcpCamera = nil
        end
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        result = { ok = true, action = 'reset' }

    else
        result = { ok = false, error = 'Unknown action: ' .. tostring(action) }
    end

    TriggerServerEvent('morjard-connector:asyncResult', requestId, result)
end)

---------------------------------------------------------------------------
-- MCP: Ped Control
---------------------------------------------------------------------------

RegisterNetEvent('morjard-connector:pedControl')
AddEventHandler('morjard-connector:pedControl', function(requestId, opts)
    local action = opts.action
    local ped = PlayerPedId()
    local result = {}

    if action == 'model' then
        local modelName = opts.model
        if not modelName then
            TriggerServerEvent('morjard-connector:asyncResult', requestId, { ok = false, error = 'Missing model name' })
            return
        end
        local hash = joaat(modelName)
        RequestModel(hash)
        local timeout = 50
        while not HasModelLoaded(hash) and timeout > 0 do
            Wait(100)
            timeout = timeout - 1
        end
        if HasModelLoaded(hash) then
            SetPlayerModel(PlayerId(), hash)
            SetModelAsNoLongerNeeded(hash)
            result = { ok = true, action = 'model', model = modelName }
        else
            result = { ok = false, error = 'Model failed to load: ' .. modelName }
        end

    elseif action == 'anim' then
        local dict = opts.animDict
        local name = opts.animName
        if not dict or not name then
            TriggerServerEvent('morjard-connector:asyncResult', requestId, { ok = false, error = 'Missing animDict or animName' })
            return
        end
        RequestAnimDict(dict)
        local timeout = 50
        while not HasAnimDictLoaded(dict) and timeout > 0 do
            Wait(100)
            timeout = timeout - 1
        end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, name, 8.0, -8.0, -1, 0, 0.0, false, false, false)
            result = { ok = true, action = 'anim', dict = dict, name = name }
        else
            result = { ok = false, error = 'Anim dict failed to load: ' .. dict }
        end

    elseif action == 'freeze' then
        local freeze = opts.freeze
        if freeze == nil then freeze = true end
        FreezeEntityPosition(ped, freeze)
        result = { ok = true, action = 'freeze', frozen = freeze }

    elseif action == 'weapon' then
        local weapon = opts.weapon or 'WEAPON_PISTOL'
        local ammo = tonumber(opts.ammo) or 250
        local hash = joaat(weapon)
        GiveWeaponToPed(ped, hash, ammo, false, true)
        result = { ok = true, action = 'weapon', weapon = weapon, ammo = ammo }

    elseif action == 'teleport' then
        local x = tonumber(opts.x) or 0
        local y = tonumber(opts.y) or 0
        local z = tonumber(opts.z) or 0
        local heading = tonumber(opts.heading)
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        if heading then SetEntityHeading(ped, heading) end
        result = { ok = true, action = 'teleport', coords = { x = x, y = y, z = z } }

    else
        result = { ok = false, error = 'Unknown action: ' .. tostring(action) }
    end

    TriggerServerEvent('morjard-connector:asyncResult', requestId, result)
end)

---------------------------------------------------------------------------
-- MCP: Interior Debug
---------------------------------------------------------------------------

RegisterNetEvent('morjard-connector:getInterior')
AddEventHandler('morjard-connector:getInterior', function(requestId)
    local ped = PlayerPedId()
    local intId = GetInteriorFromEntity(ped)

    if intId == 0 then
        TriggerServerEvent('morjard-connector:asyncResult', requestId, {
            interiorId = 0,
            note = 'Player is not inside any interior',
        })
        return
    end

    -- Rooms
    local rooms = {}
    local roomCount = GetInteriorRoomCount(intId)
    for i = 0, roomCount - 1 do
        rooms[#rooms + 1] = {
            index = i,
            name = GetInteriorRoomName(intId, i) or '',
            timecycle = GetInteriorRoomTimecycle(intId, i),
            flag = GetInteriorRoomFlag(intId, i),
        }
    end

    -- Portals
    local portals = {}
    local portalCount = GetInteriorPortalCount(intId)
    for i = 0, portalCount - 1 do
        local roomFrom = GetInteriorPortalRoomFrom(intId, i)
        local roomTo = GetInteriorPortalRoomTo(intId, i)
        local flag = GetInteriorPortalFlag(intId, i)
        portals[#portals + 1] = {
            index = i,
            roomFrom = roomFrom,
            roomTo = roomTo,
            flag = flag,
        }
    end

    -- Interior position and rotation
    local pos = GetInteriorPosition(intId)
    local rot = GetInteriorRotation(intId)

    TriggerServerEvent('morjard-connector:asyncResult', requestId, {
        interiorId = intId,
        roomCount = roomCount,
        rooms = rooms,
        portalCount = portalCount,
        portals = portals,
        position = { x = pos.x, y = pos.y, z = pos.z },
        rotation = { x = rot.x, y = rot.y, z = rot.z, w = rot.w },
    })
end)

---------------------------------------------------------------------------
-- MCP: Screenshot (via screenshot-basic)
---------------------------------------------------------------------------

RegisterNetEvent('morjard-connector:requestScreenshot')
AddEventHandler('morjard-connector:requestScreenshot', function(requestId, opts)
    local encoding = opts and opts.encoding or 'png'
    local quality = opts and opts.quality or 0.85

    -- Check if screenshot-basic is available
    local screenshotExport = exports['screenshot-basic']
    if not screenshotExport then
        TriggerServerEvent('morjard-connector:asyncResult', requestId, {
            ok = false,
            error = 'screenshot-basic resource not available',
        })
        return
    end

    screenshotExport:requestScreenshot({
        encoding = encoding,
        quality = quality,
    }, function(data)
        -- data is base64 encoded image (without data URI prefix)
        TriggerServerEvent('morjard-connector:asyncResult', requestId, {
            data = data,
        })
    end)
end)

---------------------------------------------------------------------------
-- MCP: Client-side Hot Reload
---------------------------------------------------------------------------

RegisterNetEvent('morjard-connector:reloadClient')
AddEventHandler('morjard-connector:reloadClient', function(requestId, resource, file)
    local code = LoadResourceFile(resource, file)
    if not code then
        TriggerServerEvent('morjard-connector:asyncResult', requestId, {
            ok = false,
            error = 'File not found: ' .. resource .. '/' .. file,
        })
        return
    end

    -- Handler cleanup (client-side registry)
    _G._mcpHandlers = _G._mcpHandlers or {}
    local key = resource .. ':' .. file

    if _G._mcpHandlers[key] then
        for _, h in ipairs(_G._mcpHandlers[key]) do
            RemoveEventHandler(h)
        end
    end
    _G._mcpHandlers[key] = {}

    -- Managed environment
    local env = setmetatable({
        AddEventHandler = function(name, cb)
            local h = AddEventHandler(name, cb)
            table.insert(_G._mcpHandlers[key], h)
            return h
        end,
        RegisterNetEvent = RegisterNetEvent,
    }, { __index = _G })

    local fn, err = load(code, file, 't', env)
    if not fn then
        TriggerServerEvent('morjard-connector:asyncResult', requestId, {
            ok = false,
            error = err,
        })
        return
    end

    local ok, result = pcall(fn)
    TriggerServerEvent('morjard-connector:asyncResult', requestId, {
        ok = ok,
        result = tostring(result or ''),
        error = not ok and result or nil,
        handlers = #_G._mcpHandlers[key],
    })
end)
