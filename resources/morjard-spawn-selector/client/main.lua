local QBCore = exports['qb-core']:GetCoreObject()

-- Hybrid style (Morjard / DDCZ, see ../morjard-settings). Safe no-op if that
-- resource isn't present/started -- the UI then keeps its own Ember default.
-- Retries: both resources start via the same `ensure [category]` line in
-- server.cfg with no guaranteed order, so a single immediate attempt could
-- silently give up forever if morjard-settings happens to start a moment
-- later (found 2026-10-01).
CreateThread(function()
    for _ = 1, 10 do
        local ok, style = pcall(function()
            return exports['morjard-settings']:GetStyle()
        end)
        if ok and style then
            SendNUIMessage({ type = 'applyMorjardStyle', style = style })
            return
        end
        Wait(250)
    end
end)

local cam = nil
local cam2 = nil
local isOpen = false
local selectedLoc = nil
local allLocations = {}

-- ============================================================
-- COORDINATE CONVERSION: GTA world coords -> screen percentage
-- ============================================================
-- Maps GTA V world coordinates to approximate screen percentages
-- GTA V map bounds: X = -4000 to 8000, Y = -4000 to 8500
-- We convert to 0-100% range for CSS positioning

local function worldToScreen(x, y)
    local mapMinX = -4000.0
    local mapMaxX = 8000.0
    local mapMinY = -4000.0
    local mapMaxY = 8500.0
    local percX = ((x - mapMinX) / (mapMaxX - mapMinX)) * 100.0
    local percY = (1.0 - ((y - mapMinY) / (mapMaxY - mapMinY))) * 100.0
    return percX, percY
end

-- ============================================================
-- BUILD LOCATION LIST
-- ============================================================

local function buildLocationList(lastLoc)
    local locs = {}

    -- Add last location if available
    if Config.EnableLastLocation and lastLoc then
        local lx, ly = worldToScreen(lastLoc.x, lastLoc.y)
        locs[#locs + 1] = {
            id = 'last_location',
            name = 'LAST LOCATION',
            description = 'Return to where you left off',
            category = 'last',
            icon = 'clock-rotate-left',
            cssTop = ly .. '%',
            cssLeft = lx .. '%',
            pos = lastLoc,
        }
    end

    -- Add config locations
    for _, loc in ipairs(Config.Locations) do
        local lx, ly = worldToScreen(loc.pos.x, loc.pos.y)
        locs[#locs + 1] = {
            id = loc.id,
            name = loc.name,
            description = loc.description,
            category = loc.category,
            icon = loc.icon,
            cssTop = ly .. '%',
            cssLeft = lx .. '%',
            pos = loc.pos,
            heading = loc.heading,
        }
    end

    return locs
end

-- ============================================================
-- CAMERA SYSTEM
-- ============================================================

local function killCamera()
    if DoesCamExist(cam) then
        SetCamActive(cam, false)
        DestroyCam(cam, false)
        cam = nil
    end
    if DoesCamExist(cam2) then
        SetCamActive(cam2, false)
        DestroyCam(cam2, false)
        cam2 = nil
    end
    RenderScriptCams(false, true, 800, true, false)
end

local function createTopDownCamera()
    if DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    SetCamCoord(cam, pos.x, pos.y, pos.z + Config.Camera.topHeight)
    SetCamRot(cam, -90.0, 0.0, 0.0, 2)
    SetCamFov(cam, 80.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, false)
end

local function transitionCameraToPreview(x, y, z)
    if not DoesCamExist(cam) then return end

    -- Create second camera for smooth interpolation
    if DoesCamExist(cam2) then
        DestroyCam(cam2, false)
    end
    cam2 = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)

    local height = z + Config.Camera.previewHeight
    local offset = Config.Camera.previewOffset
    SetCamCoord(cam2, x - offset * 0.5, y - offset * 0.5, height)
    SetCamRot(cam2, Config.Camera.previewAngle, 0.0, 0.0, 2)
    SetCamFov(cam2, 60.0)
    SetCamActive(cam2, true)

    SetCamActiveWithInterp(cam2, cam, Config.Camera.transitionTime, true, true)

    -- Swap references so next transition uses cam2 as source
    local temp = cam
    cam = cam2
    cam2 = temp
end

local function createCameraAbove(x, y, z)
    if DoesCamExist(cam) then
        DestroyCam(cam, false)
    end
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
    SetCamCoord(cam, x, y, z + Config.Camera.topHeight)
    SetCamRot(cam, -90.0, 0.0, 0.0, 2)
    SetCamFov(cam, 80.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, false)
end

local function descendCamera(x, y, z)
    if not DoesCamExist(cam) then return end

    local height = Config.Camera.topHeight
    local targetHeight = z + 5.0
    local ped = PlayerPedId()

    while height > targetHeight do
        SetEntityCoords(ped, x, y, z, false, false, false, false)
        local step
        if height > 400.0 then
            step = 8.0
        elseif height > 200.0 then
            step = 5.0
        elseif height > 50.0 then
            step = 3.0
        else
            step = 1.5
        end
        step = step * Config.Camera.descentSpeed
        height = height - step
        if height < targetHeight then height = targetHeight end
        SetCamCoord(cam, x, y, height)
        Wait(10)
    end
end

local function fadeOut()
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do
        Wait(10)
    end
end

local function fadeIn()
    DoScreenFadeIn(500)
    while not IsScreenFadedIn() do
        Wait(10)
    end
end

-- ============================================================
-- SPAWN FINALIZATION
-- ============================================================

local function finalizeSpawn(x, y, z, heading)
    local ped = PlayerPedId()

    SetEntityCoords(ped, x, y, z, false, false, false, false)
    SetEntityHeading(ped, heading or 0.0)

    -- Wait for collision to load
    RequestCollisionAtCoord(x, y, z)
    local timeout = 0
    while not HasCollisionLoadedAroundEntity(ped) and timeout < 2000 do
        Wait(10)
        timeout = timeout + 10
    end

    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)

    killCamera()
    DisplayRadar(true)
    DisplayHud(true)

    -- Save last location
    if Config.SaveLastLocation then
        TriggerServerEvent('morjard-spawnselector:saveLastLocation', x, y, z, heading or 0.0)
    end

    -- Notify other resources that spawn is complete
    TriggerEvent('morjard-spawnselector:spawnComplete', x, y, z, heading)
    TriggerServerEvent('morjard-spawnselector:spawnComplete')

    isOpen = false
end

-- ============================================================
-- GET LOCATION POSITION BY ID
-- ============================================================

local function getLocationPos(locId)
    for _, loc in ipairs(allLocations) do
        if loc.id == locId then
            return loc.pos, loc.heading
        end
    end
    return nil, nil
end

-- ============================================================
-- OPEN SPAWN SELECTOR
-- ============================================================

local function openSpawnSelector(lastLoc)
    if isOpen then return end
    isOpen = true

    -- Hide HUD
    DisplayRadar(false)
    DisplayHud(false)

    -- Build locations
    allLocations = buildLocationList(lastLoc)

    -- Prepare NUI data
    local nuiLocs = {}
    for _, loc in ipairs(allLocations) do
        nuiLocs[#nuiLocs + 1] = {
            id = loc.id,
            name = loc.name,
            description = loc.description,
            category = loc.category,
            icon = loc.icon,
            cssTop = loc.cssTop,
            cssLeft = loc.cssLeft,
        }
    end

    -- Create top-down camera
    createTopDownCamera()

    -- Open NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showSpawnSelector',
        locations = nuiLocs,
        enableLastLocation = Config.EnableLastLocation and lastLoc ~= nil,
    })
end

-- ============================================================
-- NET EVENTS
-- ============================================================

-- Triggered by morjard-multicharacter or any resource after character selection
RegisterNetEvent('morjard-spawnselector:open', function()
    -- Request last location from server
    if Config.EnableLastLocation then
        QBCore.Functions.TriggerCallback('morjard-spawnselector:getLastLocation', function(lastLoc)
            openSpawnSelector(lastLoc)
        end)
    else
        openSpawnSelector(nil)
    end
end)

-- Direct open with provided locations (for external resources)
RegisterNetEvent('morjard-spawnselector:openWithLocations', function(customLocations, lastLoc)
    if isOpen then return end
    isOpen = true

    DisplayRadar(false)
    DisplayHud(false)

    allLocations = customLocations or buildLocationList(lastLoc)

    local nuiLocs = {}
    for _, loc in ipairs(allLocations) do
        nuiLocs[#nuiLocs + 1] = {
            id = loc.id,
            name = loc.name,
            description = loc.description,
            category = loc.category,
            icon = loc.icon,
            cssTop = loc.cssTop,
            cssLeft = loc.cssLeft,
        }
    end

    createTopDownCamera()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showSpawnSelector',
        locations = nuiLocs,
        enableLastLocation = Config.EnableLastLocation and lastLoc ~= nil,
    })
end)

-- ============================================================
-- NUI CALLBACKS
-- ============================================================

RegisterNUICallback('spawn', function(data, cb)
    if not data.location then
        cb('error')
        return
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideSpawnSelector' })

    local pos, heading = getLocationPos(data.location)
    if pos then
        fadeOut()
        createCameraAbove(pos.x, pos.y, pos.z)
        Wait(200)
        fadeIn()
        descendCamera(pos.x, pos.y, pos.z)
        finalizeSpawn(pos.x, pos.y, pos.z, heading or 0.0)
    else
        -- Fallback: spawn at first config location
        local fallback = Config.Locations[1]
        if fallback then
            fadeOut()
            createCameraAbove(fallback.pos.x, fallback.pos.y, fallback.pos.z)
            Wait(200)
            fadeIn()
            descendCamera(fallback.pos.x, fallback.pos.y, fallback.pos.z)
            finalizeSpawn(fallback.pos.x, fallback.pos.y, fallback.pos.z, fallback.heading or 0.0)
        end
    end

    cb('ok')
end)

RegisterNUICallback('lastLocation', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideSpawnSelector' })

    QBCore.Functions.TriggerCallback('morjard-spawnselector:getLastLocation', function(lastLoc)
        if lastLoc then
            fadeOut()
            createCameraAbove(lastLoc.x, lastLoc.y, lastLoc.z)
            Wait(200)
            fadeIn()
            descendCamera(lastLoc.x, lastLoc.y, lastLoc.z)
            finalizeSpawn(lastLoc.x, lastLoc.y, lastLoc.z, lastLoc.heading or 0.0)
        else
            -- No last location, spawn at first default
            local fallback = Config.Locations[1]
            if fallback then
                fadeOut()
                createCameraAbove(fallback.pos.x, fallback.pos.y, fallback.pos.z)
                Wait(200)
                fadeIn()
                descendCamera(fallback.pos.x, fallback.pos.y, fallback.pos.z)
                finalizeSpawn(fallback.pos.x, fallback.pos.y, fallback.pos.z, fallback.heading or 0.0)
            end
        end
    end)

    cb('ok')
end)

RegisterNUICallback('previewLocation', function(data, cb)
    if not data.location then
        cb('ok')
        return
    end

    local pos = getLocationPos(data.location)
    if pos then
        transitionCameraToPreview(pos.x, pos.y, pos.z)
    end

    cb('ok')
end)

RegisterNUICallback('closeSelector', function(data, cb)
    -- Spawn selector should NOT be closeable without selecting
    -- This callback exists only for safety/cleanup
    cb('ok')
end)

-- ============================================================
-- EXPORTS (for other resources to trigger spawn selector)
-- ============================================================

exports('Open', function()
    TriggerEvent('morjard-spawnselector:open')
end)

exports('OpenWithLocations', function(locations, lastLoc)
    TriggerEvent('morjard-spawnselector:openWithLocations', locations, lastLoc)
end)
