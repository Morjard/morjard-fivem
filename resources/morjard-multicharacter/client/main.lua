local QBCore = exports['qb-core']:GetCoreObject()

-- Hybrid style (Morjard / DDCZ, see ../morjard-settings). Safe no-op if that
-- resource isn't present/started -- the UI then keeps its own default palette.
CreateThread(function()
    local ok, style = pcall(function()
        return exports['morjard-settings']:GetStyle()
    end)
    if ok and style then
        SendNUIMessage({ type = 'applyMorjardStyle', style = style })
    end
end)

local cam = nil
local previewPed = nil
local inSelection = false
local skinCache = {}
local skinGeneration = 0    -- Race condition guard for LoadCharacterSkin
local headshotHandles = {}  -- Track headshot handles for cleanup
local pedSpawnGeneration = 0 -- Race condition guard for SpawnPreviewPed
local lastPreviewTime = 0    -- Cooldown for preview requests (anti-spam)
local pendingExternalLogout = false  -- Guard against double OpenCharacterSelection

-- Holding position: far in ocean, valid Z to avoid ground clamp
local HOLDING_POS = vector3(500.0, 8000.0, 50.0)

-- ============================================================
-- HELPERS
-- ============================================================

local function MovePlayerToHolding(ped)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, HOLDING_POS.x, HOLDING_POS.y, HOLDING_POS.z, false, false, false)
end

local function RestorePlayer(ped)
    SetEntityVisible(ped, true, true)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
end

-- ============================================================
-- AMBIENT POPULATION CONTROL
-- ============================================================

local function DisableAmbientPopulation()
    local playerId = PlayerId()

    -- Kill all ped/vehicle spawning
    SetPedPopulationBudget(0)
    SetVehiclePopulationBudget(0)

    -- Disable random spawns
    SetCreateRandomCops(false)
    SetCreateRandomCopsNotOnScenarios(false)
    SetCreateRandomCopsOnScenarios(false)
    SetGarbageTrucks(false)
    SetRandomBoats(false)
    SetRandomTrains(false)

    -- Police ignore + dispatch off (must use playerId, not ped entity)
    SetPoliceIgnorePlayer(playerId, true)
    SetDispatchCopsForPlayer(playerId, false)

    -- Wanted level zero
    SetPlayerWantedLevel(playerId, 0, false)
    SetPlayerWantedLevelNow(playerId, false)

    -- Disable all dispatch services (police, ambulance, fire, etc.)
    for i = 1, 15 do
        EnableDispatchService(i, false)
    end
end

local function EnableAmbientPopulation()
    local playerId = PlayerId()

    SetPedPopulationBudget(3)
    SetVehiclePopulationBudget(3)
    SetCreateRandomCops(true)
    SetCreateRandomCopsNotOnScenarios(true)
    SetCreateRandomCopsOnScenarios(true)
    SetGarbageTrucks(true)
    SetRandomBoats(true)
    SetRandomTrains(true)

    SetPoliceIgnorePlayer(playerId, false)
    SetDispatchCopsForPlayer(playerId, true)

    for i = 1, 15 do
        EnableDispatchService(i, true)
    end
end

-- Per-frame density zeroing (must run every frame!)
local function DisableDensityThisFrame()
    SetPedDensityMultiplierThisFrame(0.0)
    SetScenarioPedDensityMultiplierThisFrame(0.0)
    SetVehicleDensityMultiplierThisFrame(0.0)
    SetRandomVehicleDensityMultiplierThisFrame(0.0)
    SetParkedVehicleDensityMultiplierThisFrame(0.0)
end

local function ClearPreviewArea(coords, radius)
    -- Protect preview ped from ClearAreaOfPeds by marking as mission entity
    if previewPed and DoesEntityExist(previewPed) then
        SetEntityAsMissionEntity(previewPed, true, true)
    end

    ClearAreaOfPeds(coords.x, coords.y, coords.z, radius, 0)
    ClearAreaOfVehicles(coords.x, coords.y, coords.z, radius, false, false, false, false, false)
    RemoveVehiclesFromGeneratorsInArea(
        coords.x - radius, coords.y - radius, coords.z - radius,
        coords.x + radius, coords.y + radius, coords.z + radius
    )

    -- Manual cleanup for any remaining peds (skip player and preview ped)
    local peds = GetGamePool('CPed')
    local playerPed = PlayerPedId()
    for _, ped in ipairs(peds) do
        if ped ~= playerPed and ped ~= previewPed then
            local pedCoords = GetEntityCoords(ped)
            if #(pedCoords - coords) < radius then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end
    end
end

-- ============================================================
-- WEATHER & ATMOSPHERE CONTROL
-- ============================================================

local function SetSelectionAtmosphere()
    -- Set initial time
    if Config.SelectionTime then
        NetworkOverrideClockTime(Config.SelectionTime, 0, 0)
    end

    -- Set initial weather (will be reinforced per-frame via SetOverrideWeather)
    if Config.SelectionWeather then
        SetWeatherTypeNowPersist(Config.SelectionWeather)
    end

    -- Blur effect
    if Config.BlurStrength and Config.BlurStrength > 0 then
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(Config.BlurStrength)
    end
end

local function RestoreAtmosphere()
    -- Clear per-frame weather override
    ClearOverrideWeather()
    ClearWeatherTypePersist()

    -- Clear blur
    ClearTimecycleModifier()
end

-- ============================================================
-- SKIN APPLICATION (with multiple fallbacks)
-- ============================================================

local function ApplySkinToPreviewPed(ped, skinData)
    if not ped or not DoesEntityExist(ped) then return end
    if not skinData then return end

    local skin = skinData
    if type(skin) == 'string' then
        local ok, decoded = pcall(json.decode, skin)
        if ok then skin = decoded else return end
    end

    -- Try exports first (these throw if resource doesn't exist)
    local ok = pcall(function()
        exports['qb-clothing']:ApplyClothes(ped, skin)
    end)
    if ok then return end

    ok = pcall(function()
        exports['illenium-appearance']:setPedAppearance(ped, skin)
    end)
    if ok then return end

    -- fivem-appearance export (use setPedAppearance with ped, not setPlayerAppearance)
    ok = pcall(function()
        exports['fivem-appearance']:setPedAppearance(ped, skin)
    end)
    if ok then return end

    -- Try qb-clothing event (fire-and-forget, can't detect failure)
    local eventOk = pcall(function()
        TriggerEvent('qb-clothing:client:loadPlayerClothing', skin, ped)
    end)
    if eventOk then return end

    -- Native fallback only if nothing else worked
    pcall(function()
        if skin.face then
            SetPedHeadBlendData(ped,
                skin.face.mom or 0, skin.face.dad or 0, 0,
                skin.face.mom or 0, skin.face.dad or 0, 0,
                skin.face.mix or 0.5, skin.face.skinmix or 0.5, 0.0,
                false)
        elseif skin.Mom ~= nil and skin.Dad ~= nil then
            SetPedHeadBlendData(ped,
                skin.Mom or 0, skin.Dad or 0, 0,
                skin.Mom or 0, skin.Dad or 0, 0,
                skin.ShapeMix or 0.5, skin.SkinMix or 0.5, 0.0,
                false)
        end

        local components = {
            {idx = 1,  key = 'mask',       keyD = 'mask_texture'},
            {idx = 3,  key = 'arms',       keyD = 'arms_texture'},
            {idx = 4,  key = 'pants',      keyD = 'pants_texture'},
            {idx = 5,  key = 'bag',        keyD = 'bag_texture'},
            {idx = 6,  key = 'shoes',      keyD = 'shoes_texture'},
            {idx = 7,  key = 'accessory',  keyD = 'accessory_texture'},
            {idx = 8,  key = 'tshirt',     keyD = 'tshirt_texture'},
            {idx = 9,  key = 'vest',       keyD = 'vest_texture'},
            {idx = 10, key = 'decals',     keyD = 'decals_texture'},
            {idx = 11, key = 'torso',      keyD = 'torso_texture'},
        }
        for _, comp in ipairs(components) do
            local draw = skin[comp.key]
            local tex = skin[comp.keyD] or 0
            if draw then
                SetPedComponentVariation(ped, comp.idx, draw, tex, 2)
            end
        end

        local props = {
            {idx = 0, key = 'hat',     keyD = 'hat_texture'},
            {idx = 1, key = 'glass',   keyD = 'glass_texture'},
            {idx = 2, key = 'ear',     keyD = 'ear_texture'},
            {idx = 6, key = 'watch',   keyD = 'watch_texture'},
            {idx = 7, key = 'bracelet', keyD = 'bracelet_texture'},
        }
        for _, prop in ipairs(props) do
            local draw = skin[prop.key]
            local tex = skin[prop.keyD] or 0
            if draw and draw >= 0 then
                SetPedPropIndex(ped, prop.idx, draw, tex, true)
            else
                ClearPedProp(ped, prop.idx)
            end
        end

        if skin.hair then
            SetPedComponentVariation(ped, 2, skin.hair, skin.hair_texture or 0, 2)
            if skin.hair_color ~= nil then
                SetPedHairColor(ped, skin.hair_color, skin.hair_highlight or 0)
            end
        end

        local overlays = {
            {idx = 0,  key = 'blemishes'}, {idx = 1,  key = 'facialhair'},
            {idx = 2,  key = 'eyebrows'},  {idx = 3,  key = 'ageing'},
            {idx = 4,  key = 'makeup'},    {idx = 5,  key = 'blush'},
            {idx = 6,  key = 'complexion'},{idx = 7,  key = 'sundamage'},
            {idx = 8,  key = 'lipstick'},  {idx = 9,  key = 'moles'},
            {idx = 10, key = 'chest'},     {idx = 11, key = 'bodyblemishes'},
        }
        for _, ov in ipairs(overlays) do
            local val = skin[ov.key]
            local opacity = skin[ov.key .. '_opacity'] or 1.0
            if val and val >= 0 then
                SetPedHeadOverlay(ped, ov.idx, val, opacity + 0.0)
            end
        end

        if skin.eye_color then
            SetPedEyeColor(ped, skin.eye_color)
        end
    end)
end

-- ============================================================
-- ENTRY POINT — wait for session, open character selection
-- ============================================================

CreateThread(function()
    while not NetworkIsSessionStarted() do
        Wait(100)
    end

    DoScreenFadeOut(0)
    Wait(500)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    Wait(200)

    DisableAmbientPopulation()

    -- Pre-load freemode models so metadata is streamed before character selection
    local maleModel = Config.StarterModel
    local femaleModel = Config.StarterModelFemale
    if type(maleModel) ~= 'number' then maleModel = GetHashKey(tostring(maleModel)) end
    if type(femaleModel) ~= 'number' then femaleModel = GetHashKey(tostring(femaleModel)) end
    RequestModel(maleModel)
    RequestModel(femaleModel)
    local modelTimeout = GetGameTimer() + 8000
    while (not HasModelLoaded(maleModel) or not HasModelLoaded(femaleModel)) and GetGameTimer() < modelTimeout do
        Wait(100)
    end

    local ped = PlayerPedId()
    MovePlayerToHolding(ped)

    -- Load interior for preview (request IPL for apartments that need explicit loading)
    if Config.Interior then
        if Config.InteriorIpl then
            RequestIpl(Config.InteriorIpl)
        end
        RequestCollisionAtCoord(Config.Interior.x, Config.Interior.y, Config.Interior.z)
        local interiorId = GetInteriorAtCoords(Config.Interior.x, Config.Interior.y, Config.Interior.z)
        if interiorId ~= 0 then
            PinInteriorInMemory(interiorId)
            LoadInterior(interiorId)
            local timeout = GetGameTimer() + 5000
            while not IsInteriorReady(interiorId) and GetGameTimer() < timeout do
                Wait(100)
            end
        end
        Wait(200)
        ClearPreviewArea(Config.Interior, 150.0)
    end

    Wait(500)
    OpenCharacterSelection()
end)

-- ============================================================
-- CONTINUOUS PED CLEARING THREAD (every 3 seconds)
-- ============================================================

-- Clock + blur thread (low frequency, per-frame overrides are in render loop)
CreateThread(function()
    while true do
        if inSelection then
            if Config.BlurStrength and Config.BlurStrength > 0 then
                SetTimecycleModifier('hud_def_blur')
                SetTimecycleModifierStrength(Config.BlurStrength)
            end
        end
        Wait(inSelection and 500 or 2000)
    end
end)

CreateThread(function()
    while true do
        if inSelection and Config.Interior then
            SetPedPopulationBudget(0)
            SetVehiclePopulationBudget(0)
            ClearPreviewArea(Config.Interior, 150.0)
        end
        Wait(inSelection and 15000 or 10000)
    end
end)

-- ============================================================
-- OPEN CHARACTER SELECTION
-- ============================================================

function OpenCharacterSelection()
    -- Clean up any leftover preview ped from previous session/failed login
    DeletePreviewPed()

    skinCache = {}
    skinGeneration = skinGeneration + 1
    pedSpawnGeneration = pedSpawnGeneration + 1
    CleanupHeadshots()
    inSelection = true

    -- Double isolation: tutorial session hides ALL other entities on client
    NetworkStartSoloTutorialSession()

    DisableAmbientPopulation()
    SetSelectionAtmosphere()

    local ped = PlayerPedId()
    MovePlayerToHolding(ped)

    if Config.Interior then
        ClearPreviewArea(Config.Interior, 150.0)
    end

    SetupCamera()

    -- Disable HUD
    DisplayRadar(false)
    DisplayHud(false)

    -- Fade in to reveal the scene
    DoScreenFadeIn(1000)

    -- Fetch characters from server
    QBCore.Functions.TriggerCallback('morjard-multicharacter:server:getCharacters', function(data)
        if not data then data = { maxSlots = Config.DefaultSlots or 4, characters = {} } end

        SendNUIMessage({
            action             = 'open',
            maxSlots           = data.maxSlots,
            characters         = data.characters,
            spawnLocations     = data.spawnLocations,
            enableLastLocation = data.enableLastLocation,
        })
        SetNuiFocus(true, true)

        -- Preview first character if exists
        local firstChar = nil
        if data.characters then
            for i = 1, (data.maxSlots or 4) do
                for _, ch in ipairs(data.characters) do
                    if ch.cid == i then firstChar = ch break end
                end
                if firstChar then break end
            end
        end

        if firstChar then
            LoadCharacterSkin(firstChar.citizenid)
        else
            SpawnPreviewPed(Config.StarterModel)
        end

        -- Background thread: generate headshots for ALL characters
        if data.characters and #data.characters > 0 then
            local charList = data.characters
            CreateThread(function()
                local myGen = pedSpawnGeneration
                Wait(2000) -- Let the first character fully load first

                for _, charData in ipairs(charList) do
                    if pedSpawnGeneration ~= myGen or not inSelection then return end

                    local cid = charData.citizenid
                    -- Skip if headshot already exists
                    if headshotHandles[cid] then goto nextChar end

                    -- We need skin data for this character
                    local skinData = skinCache[cid]
                    if not skinData then
                        local fetchDone = false
                        QBCore.Functions.TriggerCallback('morjard-multicharacter:server:getSkin', function(sd)
                            skinData = sd
                            if sd and sd.model then
                                skinCache[cid] = sd
                            end
                            fetchDone = true
                        end, cid)
                        local fetchTimeout = GetGameTimer() + 5000
                        while not fetchDone and GetGameTimer() < fetchTimeout do Wait(50) end
                        if not skinData or not skinData.model then goto nextChar end
                    end

                    if pedSpawnGeneration ~= myGen or not inSelection then return end

                    -- Spawn a temporary ped for headshot capture
                    local model = tonumber(skinData.model) or GetHashKey(skinData.model)
                    RequestModel(model)
                    local modelTimeout = GetGameTimer() + 8000
                    while not HasModelLoaded(model) and GetGameTimer() < modelTimeout do Wait(100) end
                    if not HasModelLoaded(model) then SetModelAsNoLongerNeeded(model) goto nextChar end

                    if pedSpawnGeneration ~= myGen or not inSelection then
                        SetModelAsNoLongerNeeded(model)
                        return
                    end

                    -- Create temp ped at holding position (off-screen)
                    local tempPed = CreatePed(2, model, HOLDING_POS.x, HOLDING_POS.y, HOLDING_POS.z - 5.0, 0.0, false, true)

                    if tempPed and tempPed ~= 0 then
                        SetEntityAsMissionEntity(tempPed, true, true)
                        FreezeEntityPosition(tempPed, true)
                        -- NOTE: Do NOT SetEntityVisible(false) — RegisterPedheadshot needs a visible ped
                        -- The ped is at HOLDING_POS (ocean) so players won't see it
                        SetEntityInvincible(tempPed, true)

                        -- Apply skin using the same logic as ApplySkinToPreviewPed
                        if skinData.skin then
                            ApplySkinToPreviewPed(tempPed, skinData.skin)
                        end

                        Wait(1500) -- Wait for textures to stream in (increased for headshot reliability)

                        if pedSpawnGeneration == myGen and inSelection then
                            GenerateHeadshot(cid, tempPed)
                            Wait(300) -- Let headshot texture be captured
                        end

                        -- Delete temp ped
                        SetEntityAsMissionEntity(tempPed, true, true)
                        DeleteEntity(tempPed)
                    end

                    SetModelAsNoLongerNeeded(model)
                    Wait(200) -- Small delay between characters

                    ::nextChar::
                end
            end)
        end
    end)
end

-- ============================================================
-- CAMERA
-- ============================================================

function SetupCamera()
    if cam then
        DestroyCam(cam, false)
    end

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        Config.CamCoords.x, Config.CamCoords.y, Config.CamCoords.z,
        Config.CamRot.x, Config.CamRot.y, Config.CamRot.z,
        Config.CameraFoV or 38.0, false, 0)

    -- Depth of Field for cinematic look
    SetCamUseShallowDofMode(cam, true)
    SetCamNearDof(cam, Config.CameraNearDof or 0.3)
    SetCamFarDof(cam, Config.CameraFarDof or 2.5)
    SetCamDofStrength(cam, Config.CameraDofStrength or 1.0)

    -- Subtle camera shake for realism
    if Config.CameraShake and Config.CameraShake > 0 then
        ShakeCam(cam, Config.CameraShakeType or 'HAND_SHAKE', Config.CameraShake)
    end

    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

function DestroyCamera()
    if cam then
        StopCamShaking(cam, true)
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

-- ============================================================
-- PED PREVIEW
-- ============================================================

function SpawnPreviewPed(model)
    -- Increment generation BEFORE anything else to invalidate concurrent calls
    pedSpawnGeneration = pedSpawnGeneration + 1
    local mySpawnGen = pedSpawnGeneration

    DeletePreviewPed()

    if type(model) == 'string' then
        model = GetHashKey(model)
    end

    -- Validate model, fallback to default if invalid
    if not IsModelValid(model) or not IsModelAPed(model) then
        print('[morjard-multicharacter] Model ' .. tostring(model) .. ' is not valid, using default')
        model = Config.StarterModel
        if type(model) == 'string' then
            model = GetHashKey(model)
        end
    end

    RequestModel(model)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(100)
    end

    -- After async wait: check if a newer SpawnPreviewPed call has started
    if pedSpawnGeneration ~= mySpawnGen then
        SetModelAsNoLongerNeeded(model)
        return
    end

    if not HasModelLoaded(model) then
        SetModelAsNoLongerNeeded(model)
        return
    end

    -- Delete again right before creating — catches any ped spawned by a concurrent call
    -- that finished between our first DeletePreviewPed and now
    DeletePreviewPed()

    local ped = CreatePed(2, model,
        Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z - 1.0,
        Config.PedCoords.w, false, true)

    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(model)
        previewPed = nil
        return
    end

    -- Final generation check: if another call started while CreatePed was processing,
    -- delete this ped immediately to avoid orphan
    if pedSpawnGeneration ~= mySpawnGen then
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
        SetModelAsNoLongerNeeded(model)
        return
    end

    previewPed = ped
    SetEntityHeading(previewPed, Config.PedCoords.w)
    FreezeEntityPosition(previewPed, true)
    SetEntityInvincible(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    PlaceObjectOnGroundProperly(previewPed)
    SetEntityCollision(previewPed, false, false)
    SetEntityAsMissionEntity(previewPed, true, true)
    SetModelAsNoLongerNeeded(model)

    -- Play random idle animation instead of standing still
    if Config.PreviewAnimations and #Config.PreviewAnimations > 0 then
        local anim = Config.PreviewAnimations[math.random(#Config.PreviewAnimations)]
        SetPedCanPlayAmbientAnims(previewPed, true)
        TaskStartScenarioInPlace(previewPed, anim, 0, true)
    else
        TaskStandStill(previewPed, -1)
    end
end

function DeletePreviewPed()
    if previewPed then
        local ped = previewPed
        previewPed = nil  -- Clear reference FIRST to prevent double-use
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end
end

function LoadCharacterSkin(citizenid)
    skinGeneration = skinGeneration + 1
    local myGen = skinGeneration

    local function applySkin(skinData)
        if skinGeneration ~= myGen or not inSelection then return end

        local model = tonumber(skinData.model) or GetHashKey(skinData.model)
        SpawnPreviewPed(model)

        if skinGeneration ~= myGen or not inSelection then return end

        if skinData.skin and previewPed and DoesEntityExist(previewPed) then
            -- Wait for ped to fully initialize, with guard
            local timeout = GetGameTimer() + 1000
            while not DoesEntityExist(previewPed) and GetGameTimer() < timeout do
                Wait(50)
            end
            if skinGeneration ~= myGen or not inSelection then return end
            ApplySkinToPreviewPed(previewPed, skinData.skin)
        end

        -- Generate headshot for NUI after skin is applied
        if skinGeneration == myGen and previewPed and DoesEntityExist(previewPed) then
            Wait(800) -- Let skin fully render (textures streaming on first connect takes longer)
            if skinGeneration == myGen then
                GenerateHeadshot(citizenid, previewPed)
            end
        end
    end

    -- Check cache first
    if skinCache[citizenid] then
        applySkin(skinCache[citizenid])
        return
    end

    QBCore.Functions.TriggerCallback('morjard-multicharacter:server:getSkin', function(skinData)
        if skinGeneration ~= myGen or not inSelection then return end

        if skinData and skinData.model then
            skinCache[citizenid] = skinData
            applySkin(skinData)
        else
            if skinGeneration ~= myGen or not inSelection then return end
            SpawnPreviewPed(Config.StarterModel)
            -- Generate headshot for default model too
            if skinGeneration == myGen and previewPed and DoesEntityExist(previewPed) then
                Wait(800) -- Let skin fully render (textures streaming on first connect takes longer)
                if skinGeneration == myGen then
                    GenerateHeadshot(citizenid, previewPed)
                end
            end
        end
    end, citizenid)
end

-- ============================================================
-- HEADSHOT GENERATION (for NUI slot card photos)
-- ============================================================

function GenerateHeadshot(citizenid, ped)
    if not ped or not DoesEntityExist(ped) then return end
    local myGen = skinGeneration  -- Capture generation to detect stale results

    -- Cleanup old headshot handle to prevent leak
    if headshotHandles[citizenid] then
        pcall(function() UnregisterPedheadshot(headshotHandles[citizenid]) end)
        headshotHandles[citizenid] = nil
    end

    local maxRetries = 3
    local handle, txdString

    for attempt = 1, maxRetries do
        -- Abort if generation changed (ped was swapped under us)
        if skinGeneration ~= myGen then
            -- Safety: cleanup any handle from previous failed iteration
            if handle then pcall(function() UnregisterPedheadshot(handle) end) end
            return
        end

        -- RegisterPedheadshotTransparent has only 1 texture slot (~50% failure)
        -- Standard RegisterPedheadshot has more slots and is more reliable
        handle = RegisterPedheadshot(ped)
        if not handle or handle == 0 then
            if attempt < maxRetries then Wait(500) end
            goto retryEnd
        end

        local timeout = GetGameTimer() + 3000
        while (not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle)) and GetGameTimer() < timeout do
            Wait(50)
        end

        if IsPedheadshotReady(handle) and IsPedheadshotValid(handle) then
            txdString = GetPedheadshotTxdString(handle)
            if txdString and txdString ~= '' then
                break -- Success
            end
        end

        -- Failed attempt, cleanup and retry
        pcall(function() UnregisterPedheadshot(handle) end)
        handle = nil
        txdString = nil
        if attempt < maxRetries then Wait(500) end

        ::retryEnd::
    end

    if not handle or not txdString or txdString == '' then
        if handle then pcall(function() UnregisterPedheadshot(handle) end) end
        return
    end

    -- Final generation check before storing result
    if skinGeneration ~= myGen then
        pcall(function() UnregisterPedheadshot(handle) end)
        return
    end

    -- Store handle for cleanup
    headshotHandles[citizenid] = handle

    -- Send to NUI
    SendNUIMessage({
        action = 'updateHeadshot',
        citizenid = citizenid,
        headshotUrl = 'https://nui-img/' .. txdString .. '/' .. txdString,
    })
end

function CleanupHeadshots()
    for cid, handle in pairs(headshotHandles) do
        pcall(function() UnregisterPedheadshot(handle) end)
    end
    headshotHandles = {}
end

-- ============================================================
-- NUI CALLBACKS
-- ============================================================

RegisterNUICallback('selectCharacter', function(data, cb)
    if not data.citizenid then cb({ ok = true }) return end
    if not inSelection then cb({ ok = true }) return end  -- Guard against double-submit

    inSelection = false
    skinGeneration = skinGeneration + 1  -- Invalidate pending callbacks
    pedSpawnGeneration = pedSpawnGeneration + 1  -- Invalidate pending ped spawns
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    CleanupHeadshots()
    DeletePreviewPed()

    DoScreenFadeOut(300)
    RestoreAtmosphere()

    TriggerServerEvent('morjard-multicharacter:server:selectCharacter', {
        citizenid = data.citizenid,
        spawnLocation = data.spawnLocation or nil,
    })
    cb({ ok = true })
end)

RegisterNUICallback('createCharacter', function(data, cb)
    if not data.firstname or not data.lastname then cb({ ok = true }) return end
    if not inSelection then cb({ ok = true }) return end  -- Guard against double-submit

    inSelection = false
    skinGeneration = skinGeneration + 1
    pedSpawnGeneration = pedSpawnGeneration + 1
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    CleanupHeadshots()
    DeletePreviewPed()

    DoScreenFadeOut(300)
    RestoreAtmosphere()

    TriggerServerEvent('morjard-multicharacter:server:createCharacter', {
        cid         = data.cid or 1,
        firstname   = data.firstname,
        lastname    = data.lastname,
        birthdate   = data.birthdate or '1990-01-01',
        gender      = data.gender or 0,
        nationality = data.nationality or 'Czech Republic',
    })
    cb({ ok = true })
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    if not data.citizenid then cb({ ok = true }) return end
    if not inSelection then cb({ ok = true }) return end  -- Guard against stale UI
    TriggerServerEvent('morjard-multicharacter:server:deleteCharacter', {
        citizenid = data.citizenid,
    })
    cb({ ok = true })
end)

RegisterNUICallback('previewCharacter', function(data, cb)
    -- Cooldown: prevent rapid ped spawn spam (min 300ms between previews)
    local now = GetGameTimer()
    if now - lastPreviewTime < 300 then cb({ ok = true }) return end
    lastPreviewTime = now

    if data.citizenid then
        LoadCharacterSkin(data.citizenid)
    elseif data.gender ~= nil then
        -- Increment skinGeneration to invalidate any pending skin callbacks
        skinGeneration = skinGeneration + 1
        local model = data.gender == 1 and Config.StarterModelFemale or Config.StarterModel
        SpawnPreviewPed(model)
    else
        skinGeneration = skinGeneration + 1
        SpawnPreviewPed(Config.StarterModel)
    end
    cb({ ok = true })
end)

RegisterNUICallback('disconnect', function(_, cb)
    TriggerServerEvent('morjard-multicharacter:server:disconnect')
    cb({ ok = true })
end)

-- ============================================================
-- FULL CLEANUP: delete ALL non-player peds near preview area
-- Called when leaving character selection to ensure zero leaked peds
-- ============================================================

local function CleanupAllPreviewPeds()
    DeletePreviewPed()

    -- Sweep the preview area for any orphaned peds (safety net)
    if Config.Interior then
        local peds = GetGamePool('CPed')
        local playerPed = PlayerPedId()
        for _, ped in ipairs(peds) do
            if ped ~= playerPed then
                local pedCoords = GetEntityCoords(ped)
                if #(pedCoords - Config.Interior) < 200.0 then
                    SetEntityAsMissionEntity(ped, true, true)
                    DeleteEntity(ped)
                end
            end
        end
    end
end

-- ============================================================
-- SPAWN CHARACTER (called from server after login)
-- ============================================================

local isSpawning = false  -- Guard against double spawn

RegisterNetEvent('morjard-multicharacter:client:spawnCharacter', function(coords, isNew)
    -- Double spawn guard (edge case #8)
    if isSpawning then return end
    isSpawning = true

    CleanupAllPreviewPeds()
    DestroyCamera()

    inSelection = false

    -- End tutorial session isolation
    if NetworkIsInTutorialSession() then
        NetworkEndTutorialSession()
    end

    SendNUIMessage({ action = 'close' })
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)

    RestoreAtmosphere()
    EnableAmbientPopulation()

    local ped = PlayerPedId()

    -- Helper: check if value is a valid finite number
    local function isFinite(v)
        return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
    end

    -- Validate coords: reject holding position, ocean, out-of-bounds, or missing data
    local x, y, z, h
    local useDefault = true
    if coords and isFinite(coords.x) and isFinite(coords.y) and isFinite(coords.z) and not isNew then
        x = coords.x
        y = coords.y
        z = coords.z
        h = isFinite(coords.w) and coords.w or 0.0
        -- GTA map bounds: roughly -4500..8500 on X, -4500..8500 on Y
        local inBounds = x > -4500.0 and x < 8500.0 and y > -4500.0 and y < 8500.0
        -- Reject holding position (500, 8000) and clearly invalid coords
        if inBounds and
           not (math.abs(x - HOLDING_POS.x) < 10.0 and math.abs(y - HOLDING_POS.y) < 10.0) and
           not (z < -50.0) and   -- underground / falling through map
           not (x == 0.0 and y == 0.0) then  -- origin
            useDefault = false
        end
    end
    if useDefault then
        x = Config.DefaultSpawn.x
        y = Config.DefaultSpawn.y
        z = Config.DefaultSpawn.z
        h = Config.DefaultSpawn.w or 0.0
    end

    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)

    -- Use SetFocusPosAndVel to force streaming at target location (helps with interiors and far distances)
    SetFocusPosAndVel(x, y, z, 0.0, 0.0, 0.0)

    -- Wait for collision to load
    local timeout = GetGameTimer() + 7000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end

    -- Ground Z detection with water awareness
    -- Pass true (includeWater) to detect water surface as ground for ocean positions
    local found, groundZ = false, z
    timeout = GetGameTimer() + 5000
    while not found and GetGameTimer() < timeout do
        found, groundZ = GetGroundZFor_3dCoord(x, y, z + 100.0, true)
        if not found then Wait(50) end
    end

    -- Check if position is over water (edge case #2: ocean spawn)
    local isInWater = false
    local waterFound, waterHeight = GetWaterHeight(x, y, z + 50.0)
    if waterFound and waterHeight then
        if not found then
            -- No ground detected at all, but water exists = deep ocean
            isInWater = true
        elseif groundZ <= waterHeight + 1.0 then
            -- Ground is at or below water surface = submerged terrain (ocean floor)
            isInWater = true
        end
    end

    -- If over deep water with no solid ground, redirect to DefaultSpawn
    if isInWater and not useDefault then
        x = Config.DefaultSpawn.x
        y = Config.DefaultSpawn.y
        z = Config.DefaultSpawn.z
        h = Config.DefaultSpawn.w or 0.0
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, h)
        -- Re-detect ground at default spawn
        RequestCollisionAtCoord(x, y, z)
        Wait(200)
        found, groundZ = GetGroundZFor_3dCoord(x, y, z + 100.0, false)
    end

    -- Release focus override and restore streaming to player entity
    ClearFocus()
    SetFocusEntity(ped)

    if found then
        -- Use detected ground Z (works for beaches Z≈0, above/below ground level)
        SetEntityCoordsNoOffset(ped, x, y, groundZ + 0.5, false, false, false)
    else
        -- Fallback: use original Z (safe for interiors where ground detection may fail)
        SetEntityCoordsNoOffset(ped, x, y, z + 0.5, false, false, false)
    end

    -- Brief stabilization wait before unfreezing (edge case #9: collision settle)
    Wait(100)

    RestorePlayer(ped)
    SetPedAoBlobRendering(ped, true)  -- Restore ambient occlusion after hiding

    DisplayRadar(true)
    DisplayHud(true)

    DoScreenFadeIn(500)

    -- Fire QBCore player loaded events directly (no server roundtrip)
    -- This must happen BEFORE playerSpawned so resources have PlayerData ready
    TriggerServerEvent('morjard-multicharacter:server:spawnComplete')
    Wait(300)
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    -- Reset inside metadata (house/apartment) to prevent stale interior state
    pcall(function() TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false) end)
    pcall(function() TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false) end)

    -- Fire playerSpawned AFTER OnPlayerLoaded so dependent resources are initialized (edge case #10)
    Wait(100)
    TriggerEvent('playerSpawned')

    Wait(500)
    if isNew then
        -- Fire both event names for compatibility (qb-clothes vs qb-clothing)
        pcall(function() TriggerEvent('qb-clothes:client:CreateFirstCharacter') end)
        pcall(function() TriggerEvent('qb-clothing:client:CreateFirstCharacter') end)
    else
        pcall(function()
            TriggerServerEvent('qb-clothes:loadPlayerSkin')
        end)
    end

    isSpawning = false
end)

-- ============================================================
-- HANDLE EXTERNAL LOGOUT (e.g. QBCore admin commands)
-- ============================================================

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if not inSelection and not isSpawning then
        -- Mark that an external logout happened; chooseChar event may follow shortly.
        -- If chooseChar arrives within 2s it will handle the selection opening.
        -- If it doesn't (e.g. admin kick), this timeout opens selection as fallback.
        pendingExternalLogout = true
        SetTimeout(2000, function()
            if pendingExternalLogout and not inSelection then
                pendingExternalLogout = false
                isSpawning = false
                DoScreenFadeOut(500)
                Wait(600)
                DeletePreviewPed()
                DestroyCamera()
                DisableAmbientPopulation()
                local ped = PlayerPedId()
                MovePlayerToHolding(ped)
                if Config.Interior then
                    ClearPreviewArea(Config.Interior, 150.0)
                end
                Wait(500)
                OpenCharacterSelection()
            end
        end)
    end
end)

-- ============================================================
-- LOGIN FAILED (server couldn't log in, reopen selection)
-- ============================================================

RegisterNetEvent('morjard-multicharacter:client:loginFailed', function()
    -- Clean up before reopening selection
    isSpawning = false  -- Reset double-spawn guard
    pendingExternalLogout = false  -- Cancel any deferred OnPlayerUnload handler
    DeletePreviewPed()
    DoScreenFadeIn(500)
    Wait(500)
    OpenCharacterSelection()
end)

-- ============================================================
-- REFRESH CHARACTERS (after delete)
-- ============================================================

RegisterNetEvent('morjard-multicharacter:client:refreshCharacters', function()
    if not inSelection then return end  -- Guard: ignore if we already left selection
    QBCore.Functions.TriggerCallback('morjard-multicharacter:server:getCharacters', function(data)
        if not inSelection then return end  -- Re-check after async wait
        if not data then data = { maxSlots = Config.DefaultSlots or 4, characters = {} } end

        SendNUIMessage({
            action             = 'refreshCharacters',
            maxSlots           = data.maxSlots,
            characters         = data.characters,
            spawnLocations     = data.spawnLocations,
            enableLastLocation = data.enableLastLocation,
        })

        local firstChar = nil
        if data.characters then
            for i = 1, (data.maxSlots or 4) do
                for _, ch in ipairs(data.characters) do
                    if ch.cid == i then firstChar = ch break end
                end
                if firstChar then break end
            end
        end

        if firstChar then
            LoadCharacterSkin(firstChar.citizenid)
        else
            SpawnPreviewPed(Config.StarterModel)
        end
    end)
end)

-- ============================================================
-- CHOOSE CHAR (called from /logout)
-- ============================================================

RegisterNetEvent('morjard-multicharacter:client:chooseChar', function()
    pendingExternalLogout = false  -- Cancel deferred OnPlayerUnload handler
    isSpawning = false  -- Reset double-spawn guard on logout

    -- Leave vehicle before teleporting to holding (prevents orphaned vehicle at logout position)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then
        TaskLeaveVehicle(ped, veh, 16)  -- 16 = teleport out instantly
        Wait(100)
    end

    DoScreenFadeOut(500)
    Wait(600)

    -- Clean up any existing preview ped from previous session
    DeletePreviewPed()
    DestroyCamera()

    DisableAmbientPopulation()

    ped = PlayerPedId()  -- Re-get after potential model change
    MovePlayerToHolding(ped)

    if Config.Interior then
        ClearPreviewArea(Config.Interior, 150.0)
    end

    Wait(500)
    OpenCharacterSelection()
end)

-- ============================================================
-- PER-FRAME LOOP: CONTROLS + DENSITY + HiDOF + SPOTLIGHT + HUD
-- ============================================================

CreateThread(function()
    while true do
        if inSelection then
            -- Disable all controls
            DisableAllControlActions(0)

            -- Per-frame density zeroing
            DisableDensityThisFrame()

            -- Hi-quality depth of field (must be called every frame)
            if cam and DoesCamExist(cam) then
                SetUseHiDof()
            end

            -- Per-frame weather + time override — wins over morjard-weathersystem every frame
            if Config.SelectionWeather then
                SetOverrideWeather(Config.SelectionWeather)
            end
            if Config.SelectionTime then
                NetworkOverrideClockTime(Config.SelectionTime, 0, 0)
            end
            -- Clear any timecycle modifiers set by weathersystem (fog, rain effects, etc.)
            if not Config.BlurStrength or Config.BlurStrength <= 0 then
                ClearTimecycleModifier()
            end

            -- Hide HUD components and notification feed
            HideHudAndRadarThisFrame()
            ThefeedHideThisFrame()

            -- Spotlight on preview ped (DrawLightWithRange is much cheaper than
            -- DrawLightWithRangeAndShadow — avoids shadow map render pass, saves 0.5-2ms GPU)
            if Config.SpotlightEnabled and previewPed and DoesEntityExist(previewPed) then
                local c = Config.SpotlightColor or { r = 220, g = 220, b = 255 }
                DrawLightWithRange(
                    Config.PedCoords.x, Config.PedCoords.y, Config.PedCoords.z + 1.0,
                    c.r, c.g, c.b,
                    Config.SpotlightRange or 3.0,
                    Config.SpotlightIntensity or 8.0
                )
            end
        end
        Wait(inSelection and 0 or 500)
    end
end)

-- ============================================================
-- LIVE ADJUSTMENT COMMANDS (dev tools — adjust camera/ped without restart)
-- ============================================================

RegisterNetEvent('morjard-multicharacter:client:adjustCam', function(x, y, z, rx, ry, rz, fov)
    if not inSelection or not cam then return end
    Config.CamCoords = vector4(x, y, z, 0.0)
    Config.CamRot = vector3(rx, ry, rz)
    Config.CameraFoV = fov
    SetupCamera()
    print(('[mcam] Camera set to %.2f %.2f %.2f rot %.1f %.1f %.1f fov %.1f'):format(x, y, z, rx, ry, rz, fov))
end)

RegisterNetEvent('morjard-multicharacter:client:adjustPed', function(x, y, z)
    if not inSelection or not previewPed or not DoesEntityExist(previewPed) then return end
    SetEntityCoordsNoOffset(previewPed, x, y, z, false, false, false)
    Config.PedCoords = vector4(x, y, z, Config.PedCoords.w)
    print(('[mped] Ped moved to %.2f %.2f %.2f'):format(x, y, z))
end)

RegisterNetEvent('morjard-multicharacter:client:adjustLight', function(range, intensity)
    Config.SpotlightRange = range
    Config.SpotlightIntensity = intensity
    print(('[mlight] Spotlight range=%.1f intensity=%.1f'):format(range, intensity))
end)

-- Failsafe cleanup on resource stop
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        DeletePreviewPed()
        DestroyCamera()
        CleanupHeadshots()
        if NetworkIsInTutorialSession() then
            NetworkEndTutorialSession()
        end
        RestoreAtmosphere()
        EnableAmbientPopulation()
        DisplayRadar(true)
        DisplayHud(true)
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        local ped = PlayerPedId()
        RestorePlayer(ped)

        -- Sweep HOLDING_POS area for temp peds from headshot generation
        local holdPeds = GetGamePool('CPed')
        for _, p in ipairs(holdPeds) do
            if p ~= ped then
                local pc = GetEntityCoords(p)
                if #(pc - HOLDING_POS) < 50.0 then
                    SetEntityAsMissionEntity(p, true, true)
                    DeleteEntity(p)
                end
            end
        end

        inSelection = false
        isSpawning = false
    end
end)
