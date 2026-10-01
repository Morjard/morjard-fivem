local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================
-- STATE
-- ============================================================
local zoneWeather         = {}
local currentTime         = { hour = 12, minute = 0 }
local showWidget          = false
local menuOpen            = false
local currentZone         = nil
local currentWeatherState = 'CLEAR'
local currentTemperature  = 20

-- activeSpecialEvent: nil = no event | string = running event
-- Events NEVER auto-stop — only admin via UI stops them
local activeSpecialEvent  = nil
local weatherLocked       = false
local targetWeatherNow    = 'CLEAR'

-- Tsunami state
local tsunamiActive       = false
local tsunamiWaterHeight  = 0.0
local waterLoaded         = false

-- Meteor: track spawned boulders so we can clean them up
local spawnedBoulders     = {}

-- ============================================================
-- MASTER WEATHER LOOP — apply on change + periodic refresh
-- FIX: Was Wait(0) with 4 natives every frame = 240 calls/sec
-- Now: apply immediately on change, then refresh every 500ms
-- ============================================================
local lastAppliedWeather = ''

CreateThread(function()
    while true do
        local weather = targetWeatherNow
        if weather ~= lastAppliedWeather then
            -- Weather changed — apply immediately
            SetWeatherTypePersist(weather)
            SetWeatherTypeNow(weather)
            SetWeatherTypeNowPersist(weather)
            SetOverrideWeather(weather)
            lastAppliedWeather = weather
        else
            -- No change — just override to prevent GTA auto-transitions
            SetOverrideWeather(weather)
        end
        Wait(500)
    end
end)

-- ============================================================
-- APPLY WEATHER — defined inside Zone section below
-- ============================================================
-- ZONE CHECK + SMOOTH TRANSITION
-- Temperature lerps gradually, weather fades over 30s
-- ============================================================

-- Lerp helper: move 'from' toward 'to' by factor t
local function Lerp(a, b, t)
    return a + (b - a) * t
end

-- Target temperature for lerp
local targetTemperature = 20

-- Apply weather with smooth over-time transition
local function ApplyWeather(weatherType, instantly)
    if not Config.WeatherTypes[weatherType] then return end
    local wdata = Config.WeatherTypes[weatherType]
    currentWeatherState = weatherType
    targetWeatherNow    = weatherType
    if instantly then
        -- Instant apply (e.g. after event stop)
        SetWindSpeed(wdata.windSpeed or 0.0)
        SetWindDirection(math.random(0, 359) + 0.0)
        SetRainLevel(wdata.rainLevel or 0.0)
    else
        -- Smooth 30-second transition
        SetWeatherTypeOvertimePersist(weatherType, 30.0)
        SetWindSpeed(wdata.windSpeed or 0.0)
        SetRainLevel(wdata.rainLevel or 0.0)
    end
end

local function CheckZone()
    if weatherLocked then return end
    local coords = GetEntityCoords(PlayerPedId())
    local nearest, nearestDist = 1, 999999.0

    for i, zone in ipairs(Config.WeatherZones) do
        local dist = #(coords - zone.center)
        if dist <= (zone.radius + 1500.0) and dist < nearestDist then
            nearest, nearestDist = i, dist
        end
    end

    if nearest ~= currentZone then
        currentZone = nearest
        if zoneWeather[currentZone] then
            -- Smooth weather transition (30s fade)
            ApplyWeather(zoneWeather[currentZone].weather, false)
            -- Set target temp — lerped in background thread
            targetTemperature = zoneWeather[currentZone].temperature or 20
        end
    end

    -- Sync target temperature from server data (handles dynamic changes)
    if currentZone and zoneWeather[currentZone] then
        targetTemperature = zoneWeather[currentZone].temperature or 20
    end
end

-- Smooth temperature lerp: moves currentTemperature toward targetTemperature
-- 0.5°C per second — feels natural, never jarring
CreateThread(function()
    while true do
        Wait(500)
        if not weatherLocked then
            local diff = targetTemperature - currentTemperature
            if math.abs(diff) > 0.2 then
                currentTemperature = currentTemperature + diff * 0.1
            else
                currentTemperature = targetTemperature
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        CheckZone()
    end
end)

-- ============================================================
-- SERVER SYNC
-- ============================================================
RegisterNetEvent('morjard-weather:client:init', function(weatherData, time)
    zoneWeather = weatherData
    currentTime = time
    NetworkOverrideClockTime(time.hour, time.minute, 0)
    Wait(1000)
    CheckZone()
    print('^2[Morjard-Weather]^7 Initialized. Zone: ' .. tostring(currentZone))
end)

RegisterNetEvent('morjard-weather:client:forceWeatherSync', function(zoneId, data)
    zoneWeather[zoneId] = data
    if currentZone == zoneId and not weatherLocked then
        ApplyWeather(data.weather, false)
    end
end)

RegisterNetEvent('morjard-weather:client:forceTimeSync', function(time)
    currentTime = time
    NetworkOverrideClockTime(time.hour, time.minute, 0)
    UpdateWidget()
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('morjard-weather:server:sync')
end)

-- ============================================================
-- WIDGET
-- ============================================================
function UpdateWidget()
    if not showWidget then return end
    local zoneName = (currentZone and Config.WeatherZones[currentZone]) and Config.WeatherZones[currentZone].name or 'Unknown'
    local wLabel, icon, wind = 'Unknown', 'sun', 0
    if currentWeatherState and Config.WeatherTypes[currentWeatherState] then
        local wd = Config.WeatherTypes[currentWeatherState]
        wLabel, icon, wind = wd.label, wd.icon, wd.windSpeed or 0
    end
    SendNUIMessage({
        action = 'update', locale = Config.Locale,
        data = {
            zone=zoneName, weather=wLabel, weatherIcon=icon,
            temperature=currentTemperature, windSpeed=wind,
            time=string.format('%02d:%02d', currentTime.hour, currentTime.minute),
            showTemperature=true, showWind=true, showTime=true, showZone=true,
        }
    })
end

CreateThread(function()
    while true do
        Wait(1000)
        UpdateWidget()
    end
end)

-- /weather: pro adminy otevře admin menu, pro všechny otevře player tablet
RegisterCommand('weather', function()
    TriggerServerEvent('morjard-weather:server:openUI')
end, false)

-- Interní toggle widgetu
RegisterCommand('weatherwidget', function()
    showWidget = not showWidget
    SendNUIMessage({ action = showWidget and 'show' or 'hide' })
    if showWidget then UpdateWidget() end
end, false)

CreateThread(function()
    Wait(6000)
    TriggerEvent('QBCore:Notify', T('notify_widget'), 'primary', 5000)
end)

-- ============================================================
-- ADMIN MENU
-- ============================================================
RegisterNetEvent('morjard-weather:client:menu', function()
    menuOpen = true
    local zones, weathers, timezones = {}, {}, {}
    for i, zone in ipairs(Config.WeatherZones) do
        zones[#zones+1] = { id=i, name=zone.name, currentWeather=zoneWeather[i] and zoneWeather[i].weather or 'CLEAR' }
    end
    for wType, data in pairs(Config.WeatherTypes) do
        weathers[#weathers+1] = { type=wType, label=data.label, icon=data.icon }
    end
    for _, tz in ipairs(Config.Timezones) do timezones[#timezones+1] = tz end
    local strings = {}
    for k, v in pairs(Lang[Config.Locale] or Lang['en'] or {}) do strings[k] = v end
    SendNUIMessage({
        action='openMenu', locale=Config.Locale, strings=strings,
        zones=zones, weathers=weathers, timezones=timezones,
        currentTime=currentTime, realTimeEnabled=Config.RealTime.enabled,
        realTimeTimezone=Config.RealTime.timezone,
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end)

RegisterNUICallback('closeMenu',          function(d,cb) menuOpen=false SetNuiFocus(false,false) cb('ok') end)
RegisterNUICallback('changeWeather',      function(d,cb) TriggerServerEvent('morjard-weather:server:weather', d.zoneId, d.weatherType) cb('ok') end)
RegisterNUICallback('changeTime',         function(d,cb) TriggerServerEvent('morjard-weather:server:time', d.hour, d.minute) cb('ok') end)
RegisterNUICallback('toggleRealTime',     function(d,cb) TriggerServerEvent('morjard-weather:server:realtime', d.enabled, d.offset) cb('ok') end)
RegisterNUICallback('triggerEvent',       function(d,cb) TriggerServerEvent('morjard-weather:server:specialEvent', d.event) cb('ok') end)
RegisterNUICallback('realtimeTimeChange', function(d,cb)
    currentTime = { hour=d.hour, minute=d.minute }
    NetworkOverrideClockTime(currentTime.hour, currentTime.minute, 0)
    UpdateWidget() cb('ok')
end)

-- ============================================================
-- THIRST — progresivní podle teploty (bez auto-stop)
-- ============================================================
CreateThread(function()
    while true do
        local temp = currentTemperature
        local interval, drain
        if     temp >= 40 then interval = 8000;  drain = 4
        elseif temp >= 30 then interval = 25000; drain = 1
        elseif temp >= 20 then interval = 60000; drain = 1
        else                    interval = 120000; drain = 1
        end
        Wait(interval)
        TriggerServerEvent('morjard-weather:server:drainThirst', drain)
    end
end)

-- ============================================================
-- COLD SYSTEM — detekce oblečení + animace + health drain
-- ============================================================
local coldAnimActive = false
local coldDict       = 'amb@code_human_wander_cold@male@idle_a'
local coldAnim       = 'idle_a'
local coldDictSev    = 'amb@code_human_wander_cold_and_target@male@idle_a'
local coldAnimSev    = 'idle_a'

local function IsIndoors()
    local room = GetRoomKeyFromEntity(PlayerPedId())
    return room ~= 0 and room ~= -1936012354
end

local function HasWarmClothing()
    local ped    = PlayerPedId()
    local torso  = GetPedDrawableVariation(ped, 3)
    local torso2 = GetPedDrawableVariation(ped, 11)
    if torso2 > 0 then return true end
    if torso > 1 then return true end
    return false
end

local function StopColdAnim()
    if not coldAnimActive then return end
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    StopAnimTask(ped, coldDict,    coldAnim,    2.0)
    StopAnimTask(ped, coldDictSev, coldAnimSev, 2.0)
    coldAnimActive = false
end

local function StartColdAnim(severe)
    local ped  = PlayerPedId()
    local dict = severe and coldDictSev or coldDict
    local anim = severe and coldAnimSev  or coldAnim
    if not HasAnimDictLoaded(dict) then
        RequestAnimDict(dict)
        local t = 0
        while not HasAnimDictLoaded(dict) and t < 100 do Wait(50) t=t+1 end
    end
    if not HasAnimDictLoaded(dict) then return end
    TaskPlayAnim(ped, dict, anim, 2.0, -2.0, -1, 1, 0, false, false, false)
    coldAnimActive = true
end

-- Preload animací ihned při startu
CreateThread(function()
    RequestAnimDict(coldDict)
    RequestAnimDict(coldDictSev)
end)

CreateThread(function()
    while true do
        Wait(2000)

        local ped      = PlayerPedId()
        local isCold   = currentTemperature < Config.Temperature.coldThreshold
        local isSevere = currentTemperature < Config.Temperature.coldSevereThreshold
        local outside  = not IsIndoors()
        local noCoat   = not HasWarmClothing()

        if outside and isCold and noCoat then
            StartColdAnim(isSevere)
            local drain = isSevere and 5 or 2
            local hp    = GetEntityHealth(ped)
            local newHp = math.max(101, hp - drain)
            SetEntityHealth(ped, newHp)
        else
            if coldAnimActive then
                StopColdAnim()
            end
        end
    end
end)

-- ============================================================
-- PARTICLE FX HELPERS
-- ============================================================
local activeParticleFx = {}

local function LoadPtfx(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local t = 0
    while not HasNamedPtfxAssetLoaded(asset) and t < 200 do Wait(10) t=t+1 end
    return HasNamedPtfxAssetLoaded(asset)
end

local function StopAllParticles()
    for _, h in ipairs(activeParticleFx) do
        if DoesParticleFxLoopedExist(h) then StopParticleFxLooped(h, false) end
    end
    activeParticleFx = {}
end

-- ============================================================
-- TSUNAMI: WATER LEVEL NATIVES
-- ============================================================
local function LoadTsunamiWater()
    if waterLoaded then return end
    waterLoaded = true
    local ok = LoadWaterFromPath(GetCurrentResourceName(), 'flood_initial.xml')
    print('[Morjard-Tsunami] flood_initial.xml: ' .. tostring(ok))
end

local function SetGlobalWaterHeight(height)
    local count = GetWaterQuadCount()
    for i = 1, count do
        local ok, _ = GetWaterQuadLevel(i)
        if ok then SetWaterQuadLevel(i, height) end
    end
end

RegisterNetEvent('morjard-weather:client:tsunamiHeight', function(height)
    LoadTsunamiWater()
    tsunamiWaterHeight = height
    SetGlobalWaterHeight(height)
    local c = GetEntityCoords(PlayerPedId())
    if GetWaterQuadAtCoords_3d(c.x, c.y, c.z) ~= -1 then
        for _, ped in ipairs(GetGamePool('CPed')) do
            SetPedConfigFlag(ped, 65, true)
            SetPedDiesInWater(ped, true)
        end
    end
end)

RegisterNetEvent('morjard-weather:client:tsunamiLoad', function()
    LoadTsunamiWater()
    SetVehiclePopulationBudget(0)
    SetPedPopulationBudget(0)
    tsunamiActive = true
end)

RegisterNetEvent('morjard-weather:client:tsunamiStop', function()
    print('^2[Morjard-Tsunami]^7 Stopping — water receding')
    tsunamiActive = false
    CreateThread(function()
        while tsunamiWaterHeight > 0.1 do
            tsunamiWaterHeight = math.max(0.0, tsunamiWaterHeight - 0.15)
            SetGlobalWaterHeight(tsunamiWaterHeight)
            Wait(80)
        end
        SetGlobalWaterHeight(0.0)
        tsunamiWaterHeight = 0.0
        waterLoaded = false
        local ok = LoadWaterFromPath(GetCurrentResourceName(), 'water.xml')
        print('[Morjard-Tsunami] water.xml restored: ' .. tostring(ok))
        SetVehiclePopulationBudget(3)
        SetPedPopulationBudget(3)
    end)
end)

-- ============================================================
-- EVENT: TSUNAMI
-- ============================================================
local function DoTsunami()
    weatherLocked    = true
    targetWeatherNow = 'THUNDER'

    LoadTsunamiWater()
    SetVehiclePopulationBudget(0)
    SetPedPopulationBudget(0)
    tsunamiActive = true

    SetWindSpeed(80.0)
    SetWindDirection(180.0)
    SetRainLevel(1.0)

    CreateThread(function()
        while activeSpecialEvent == 'tsunami' do
            Wait(500)
            SetWindSpeed(80.0)
            SetRainLevel(1.0)
        end
    end)

    SendNUIMessage({ action='showAlert', text=T('alert_tsunami') })
    SendNUIMessage({ action='playSiren' })
    TriggerEvent('QBCore:Notify', T('notify_tsunami'), 'error', 12000)
end

-- ============================================================
-- EVENT: EARTHQUAKE — shake every frame + ragdoll waves
-- NEVER auto-stops
-- ============================================================
local function DoEarthquake()
    SendNUIMessage({ action='showAlert', text=T('alert_earthquake') })
    TriggerEvent('QBCore:Notify', T('notify_earthquake'), 'error', 8000)

    -- Continuous shake — must be called every single frame
    CreateThread(function()
        while activeSpecialEvent == 'earthquake' do
            Wait(0)
            ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 0.06)
        end
        StopGameplayCamShaking(true)
    end)

    -- Ragdoll the player randomly every 8–15 seconds
    CreateThread(function()
        while activeSpecialEvent == 'earthquake' do
            Wait(math.random(8000, 15000))
            if activeSpecialEvent ~= 'earthquake' then break end
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) and not IsEntityDead(ped) then
                SetPedToRagdoll(ped, 3000, 4000, 0, false, false, false)
                ApplyForceToEntity(ped, 1,
                    (math.random()-0.5)*6.0, (math.random()-0.5)*6.0, 1.5,
                    0,0,0, false, true, true, true, false, true)
            end
        end
    end)

    -- Shake nearby vehicles every 3s
    CreateThread(function()
        while activeSpecialEvent == 'earthquake' do
            Wait(3000)
            if activeSpecialEvent ~= 'earthquake' then break end
            local coords = GetEntityCoords(PlayerPedId())
            for _, veh in ipairs(GetGamePool('CVehicle')) do
                if #(coords - GetEntityCoords(veh)) < 40.0 then
                    ApplyForceToEntity(veh, 1,
                        (math.random()-0.5)*2.0, (math.random()-0.5)*2.0, math.random()*1.5,
                        0,0,0, true, true, true, true, false, true)
                end
            end
            PlaySoundFrontend(-1, 'THUNDER_1', 'WEATHER_WARNINGS', true)
        end
    end)
end

-- ============================================================
-- EVENT: METEOR SHOWER
-- ============================================================
local function CleanMeteorBoulders()
    for _, data in ipairs(spawnedBoulders) do
        if data.ped   and DoesEntityExist(data.ped)    then DeleteEntity(data.ped) end
        if data.prop  and DoesEntityExist(data.prop)   then DeleteEntity(data.prop) end
    end
    spawnedBoulders = {}
end

local function LoadBoulderModel()
    local model = GetHashKey('prop_test_boulder_02')
    if not IsModelValid(model) then return false end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do Wait(50) t=t+1 end
    return HasModelLoaded(model)
end

local function SpawnOneBoulder(boulderModel, pCoord)
    if not HasModelLoaded(boulderModel) then return end
    local offsetX = (math.random() - 0.5) * 600.0
    local offsetY = (math.random() - 0.5) * 600.0
    local spawnZ  = pCoord.z + math.random(120, 200)
    local found, gz = GetGroundZFor_3dCoord(
        pCoord.x + offsetX, pCoord.y + offsetY, pCoord.z + 10.0, false)
    if not found then return end
    local boulder = CreateObjectNoOffset(
        boulderModel,
        pCoord.x + offsetX, pCoord.y + offsetY, spawnZ,
        true, true, true)
    if not DoesEntityExist(boulder) then return end
    SetEntityDynamic(boulder, true)
    SetEntityHasGravity(boulder, true)
    SetEntityAngularVelocity(boulder,
        (math.random()-0.5)*5.0, (math.random()-0.5)*5.0, (math.random()-0.5)*5.0)
    SetEntityVelocity(boulder,
        (math.random()-0.5)*10.0, (math.random()-0.5)*10.0, -math.random(20, 40) * 1.0)
    spawnedBoulders[#spawnedBoulders+1] = { prop = boulder }
    local groundZ = gz
    CreateThread(function()
        local deadline = GetGameTimer() + 20000
        while DoesEntityExist(boulder) and GetGameTimer() < deadline do
            Wait(80)
            local bc = GetEntityCoords(boulder)
            if bc.z - groundZ < 4.0 then
                AddExplosion(bc.x, bc.y, bc.z, 9, 5.5, true, false, 0.9)
                if LoadPtfx('core') then
                    UseParticleFxAsset('core')
                    StartParticleFxNonLoopedAtCoord('exp_grd_grenade_smoke',
                        bc.x, bc.y, bc.z, 0.0, 0.0, 0.0, 3.5, false, false, false)
                end
                Wait(150)
                if DoesEntityExist(boulder) then DeleteEntity(boulder) end
                return
            end
        end
        if DoesEntityExist(boulder) then DeleteEntity(boulder) end
    end)
end

local function DoMeteor()
    SendNUIMessage({ action='showAlert', text=T('alert_meteor') })
    SendNUIMessage({ action='playSiren' })
    TriggerEvent('QBCore:Notify', T('notify_meteor'), 'warning', 6000)

    local boulderModel = GetHashKey('prop_test_boulder_02')
    LoadBoulderModel()

    CreateThread(function()
        while activeSpecialEvent == 'meteor' do
            Wait(math.random(600, 1200))
            if activeSpecialEvent ~= 'meteor' then break end
            if not HasModelLoaded(boulderModel) then LoadBoulderModel() end
            local pCoord  = GetEntityCoords(PlayerPedId())
            local count   = math.random(2, 4)
            for i = 1, count do
                SpawnOneBoulder(boulderModel, pCoord)
            end
            while #spawnedBoulders > 60 do
                local old = table.remove(spawnedBoulders, 1)
                if old.prop and DoesEntityExist(old.prop) then DeleteEntity(old.prop) end
            end
        end
        CleanMeteorBoulders()
    end)
end

-- ============================================================
-- EVENT: BLACKOUT — never auto-stops
-- ============================================================
local function DoBlackout()
    SetArtificialLightsState(true)
    SendNUIMessage({ action='showAlert', text=T('alert_blackout') })
    TriggerEvent('QBCore:Notify', T('notify_blackout'), 'warning', 8000)
end

-- ============================================================
-- EVENT: SANDSTORM
-- FIX: timecycle loop was Wait(0) = every frame
-- Now: Wait(200) + only update on glasses change
-- ============================================================
local activeSandParticles = {}

local function StopSandParticles()
    for _, h in ipairs(activeSandParticles) do
        if DoesParticleFxLoopedExist(h) then StopParticleFxLooped(h, false) end
    end
    activeSandParticles = {}
end

local function SpawnSandParticlesAtPos(cx, cy, cz)
    StopSandParticles()
    local sets = {
        { asset='scr_rcpaparazzo3', fx='scr_mex_dust', ox=0,   oy=0,   oz=0.5,  scale=6.0 },
        { asset='scr_rcpaparazzo3', fx='scr_mex_dust', ox=20,  oy=0,   oz=0,    scale=5.0 },
        { asset='scr_rcpaparazzo3', fx='scr_mex_dust', ox=-20, oy=0,   oz=0,    scale=5.0 },
        { asset='scr_rcpaparazzo3', fx='scr_mex_dust', ox=0,   oy=20,  oz=0,    scale=5.0 },
        { asset='scr_rcpaparazzo3', fx='scr_mex_dust', ox=0,   oy=-20, oz=0,    scale=5.0 },
        { asset='scr_rcpaparazzo3', fx='scr_mex_dust', ox=8,   oy=8,   oz=-0.5, scale=3.5 },
        { asset='scr_rcpaparazzo3', fx='scr_mex_dust', ox=-8,  oy=-8,  oz=-0.5, scale=3.5 },
        { asset='core',             fx='exp_grd_sand', ox=5,   oy=-5,  oz=0,    scale=2.5 },
        { asset='core',             fx='exp_grd_sand', ox=-5,  oy=5,   oz=0,    scale=2.5 },
        { asset='core',             fx='exp_grd_sand', ox=12,  oy=0,   oz=0,    scale=2.0 },
        { asset='core',             fx='exp_grd_sand', ox=-12, oy=0,   oz=0,    scale=2.0 },
    }
    for _, p in ipairs(sets) do
        if LoadPtfx(p.asset) then
            UseParticleFxAsset(p.asset)
            local h = StartParticleFxLoopedAtCoord(
                p.fx, cx+p.ox, cy+p.oy, cz+p.oz,
                0.0, 0.0, 0.0, p.scale, false, false, false, false)
            if h and h ~= 0 then activeSandParticles[#activeSandParticles+1] = h end
        end
    end
end

local function PlayerHasGlasses()
    return GetPedPropIndex(PlayerPedId(), 1) > 0
end

local function DoSandstorm()
    weatherLocked    = true
    targetWeatherNow = 'SMOG'

    SetWindSpeed(65.0)
    SetWindDirection(math.random(0, 359) + 0.0)
    SetRainLevel(0.0)

    -- Particle loop
    CreateThread(function()
        Wait(300)
        local c = GetEntityCoords(PlayerPedId())
        SpawnSandParticlesAtPos(c.x, c.y, c.z)
        local lastPos = c
        while activeSpecialEvent == 'sandstorm' do
            Wait(3000)
            if activeSpecialEvent ~= 'sandstorm' then break end
            local nc = GetEntityCoords(PlayerPedId())
            if #(nc - lastPos) > 25.0 then
                SpawnSandParticlesAtPos(nc.x, nc.y, nc.z)
                lastPos = nc
            end
            SetWindSpeed(65.0)
        end
        StopSandParticles()
    end)

    -- Screen blur + timecycle loop
    -- FIX: Was Wait(0), now Wait(200) + track glasses state change
    CreateThread(function()
        local lastGlasses = nil
        -- Apply immediately on start
        local hasGlasses = PlayerHasGlasses()
        SetTimecycleModifier('damage')
        SetTimecycleModifierStrength(hasGlasses and 0.08 or 0.35)
        lastGlasses = hasGlasses

        while activeSpecialEvent == 'sandstorm' do
            Wait(200)
            hasGlasses = PlayerHasGlasses()

            if hasGlasses ~= lastGlasses then
                SetTimecycleModifier('damage')
                SetTimecycleModifierStrength(hasGlasses and 0.08 or 0.35)
                lastGlasses = hasGlasses
            end

            if not hasGlasses then
                ShakeGameplayCam('SKY_DIVING_SHAKE', 0.02)
            end
        end
        ClearTimecycleModifier()
        StopGameplayCamShaking(true)
    end)

    SendNUIMessage({ action='showAlert', text=T('alert_sandstorm') })
    TriggerEvent('QBCore:Notify', T('notify_sandstorm'), 'warning', 8000)
end

-- ============================================================
-- EVENT: HEATWAVE — never auto-stops
-- FIX: timecycle was Wait(0), now set once + refresh every 2s
-- ============================================================
local function DoHeatwave()
    weatherLocked      = true
    targetWeatherNow   = 'EXTRASUNNY'
    currentTemperature = 42
    SetWindSpeed(0.0)
    SetRainLevel(0.0)

    CreateThread(function()
        while activeSpecialEvent == 'heatwave' do
            Wait(3000)
            currentTemperature = 42
        end
        if currentZone and zoneWeather[currentZone] then
            currentTemperature = zoneWeather[currentZone].temperature or 20
        end
    end)

    -- FIX: Was Wait(0) = 2 natives every frame. Now set once + refresh every 2s
    CreateThread(function()
        SetTimecycleModifier('heatwave')
        SetTimecycleModifierStrength(0.4)
        while activeSpecialEvent == 'heatwave' do
            Wait(2000)
            SetTimecycleModifier('heatwave')
            SetTimecycleModifierStrength(0.4)
        end
        ClearTimecycleModifier()
    end)

    SendNUIMessage({ action='showAlert', text=T('alert_heatwave') })
    TriggerEvent('QBCore:Notify', T('notify_heatwave'), 'error', 8000)
end

-- ============================================================
-- EVENT: BLIZZARD — never auto-stops
-- FIX: timecycle was Wait(0), now set once + refresh every 2s
-- ============================================================
local function DoBlizzardEvent()
    weatherLocked      = true
    targetWeatherNow   = 'BLIZZARD'
    currentTemperature = -15
    SetWindSpeed(40.0)
    SetWindDirection(math.random(0, 359) + 0.0)
    SetRainLevel(0.0)

    CreateThread(function()
        while activeSpecialEvent == 'blizzard_event' do
            Wait(2000)
            SetWindSpeed(40.0)
            currentTemperature = -15
        end
        if currentZone and zoneWeather[currentZone] then
            currentTemperature = zoneWeather[currentZone].temperature or 20
        end
    end)

    -- FIX: Was Wait(0) = 2 natives every frame. Now set once + refresh every 2s
    CreateThread(function()
        SetTimecycleModifier('snow_bright')
        SetTimecycleModifierStrength(0.4)
        while activeSpecialEvent == 'blizzard_event' do
            Wait(2000)
            SetTimecycleModifier('snow_bright')
            SetTimecycleModifierStrength(0.4)
        end
        ClearTimecycleModifier()
    end)

    SendNUIMessage({ action='showAlert', text=T('alert_blizzard') })
    TriggerEvent('QBCore:Notify', T('notify_blizzard'), 'error', 8000)
end

-- ============================================================
-- EVENT: FOGPOCALYPSE — never auto-stops
-- ============================================================
local function DoFogpocalypse()
    weatherLocked    = true
    targetWeatherNow = 'FOGGY'
    SetWindSpeed(2.0)
    SetRainLevel(0.0)

    CreateThread(function()
        while activeSpecialEvent == 'fogpocalypse' do
            Wait(500)
        end
    end)

    SendNUIMessage({ action='showAlert', text=T('alert_fog') })
    TriggerEvent('QBCore:Notify', T('notify_fog'), 'warning', 8000)
end

-- ============================================================
-- RECEIVE EVENT FROM SERVER — single entry point
-- ============================================================
-- ============================================================
-- EVENT: ZOMBIE APOKALYPSA
-- ============================================================
local zombieActive   = false
local spawnedZombies = {}

local ZOMBIE_MODELS = {
    "a_f_y_juggalo_01",
    "a_m_m_beach_01",
    "a_m_m_eastsa_02",
    "a_m_m_farmer_01",
    "a_m_m_fatlatin_01",
    "a_m_m_hillbilly_01",
    "a_m_m_malibu_01",
    "a_m_m_mexlabor_01",
    "a_m_m_og_boss_01",
    "a_m_m_polynesian_01",
    "a_m_m_rurmeth_01",
    "a_m_m_salton_02",
    "a_m_m_skater_01",
    "a_m_m_skidrow_01",
    "a_m_m_soucent_04",
    "a_m_m_tennis_01",
    "a_m_o_acult_02",
    "a_m_y_genstreet_01",
    "a_m_y_genstreet_02",
    "a_m_y_methhead_01",
    "a_m_y_salton_01",
    "a_m_y_stlat_01",
    "csb_agent",
    "s_m_y_cop_01",
    "s_m_y_prismuscl_01",
    "s_m_y_prisoner_01",
}

local ZOMBIE_SOUNDS = {
    'sound/zombie/zombie_aggressive_1.mp3',
    'sound/zombie/zombie_aggressive_2.mp3',
    'sound/zombie/zombie_aggressive_3.mp3',
    'sound/zombie/zombie_aggressive_4.mp3',
    'sound/zombie/zombie_aggressive_5.mp3',
    'sound/zombie/zombie_growl_1.mp3',
    'sound/zombie/zombie_growl_2.mp3',
}

local zombieGroupHash = nil
local function EnsureZombieRelationshipGroup()
    if zombieGroupHash then return end
    local ok, hash = AddRelationshipGroup('Morjard_ZOMBIES')
    zombieGroupHash = hash
    local playerGroup = GetPedRelationshipGroupHash(PlayerPedId())
    SetRelationshipBetweenGroups(5, zombieGroupHash, playerGroup)
    SetRelationshipBetweenGroups(5, playerGroup, zombieGroupHash)
    SetRelationshipBetweenGroups(0, zombieGroupHash, zombieGroupHash)
end

local function SetupZombie(zombie, target)
    if zombieGroupHash then
        SetPedRelationshipGroupHash(zombie, zombieGroupHash)
    end
    SetPedCanRagdoll(zombie, true)
    SetPedSuffersCriticalHits(zombie, false)
    RemoveAllPedWeapons(zombie, true)
    GiveWeaponToPed(zombie, GetHashKey('WEAPON_UNARMED'), 1, false, true)
    SetBlockingOfNonTemporaryEvents(zombie, false)
    SetPedFleeAttributes(zombie, 0, false)
    SetPedCombatAttributes(zombie, 0,  true)
    SetPedCombatAttributes(zombie, 46, true)
    SetPedCombatAttributes(zombie, 5,  false)
    SetPedCombatAttributes(zombie, 2,  false)
    SetPedCombatAbility(zombie, 100)
    SetPedCombatMovement(zombie, 3)
    SetPedCombatRange(zombie, 2)
    SetPedMoveRateOverride(zombie, 1.0)
    SetPedAsEnemy(zombie, true)
    TaskCombatPed(zombie, target, 0, 16)
end

local function SpawnZombieWave(count, radius, center)
    local player = PlayerPedId()
    EnsureZombieRelationshipGroup()
    for i = 1, count do
        local modelName = ZOMBIE_MODELS[math.random(#ZOMBIE_MODELS)]
        local model     = GetHashKey(modelName)
        if not HasModelLoaded(model) then
            RequestModel(model)
            local t = 0
            while not HasModelLoaded(model) and t < 40 do Wait(50) t=t+1 end
        end
        if HasModelLoaded(model) then
            local angle = math.random() * 2.0 * math.pi
            local dist  = radius * (0.3 + math.random() * 0.7)
            local sx    = center.x + math.cos(angle) * dist
            local sy    = center.y + math.sin(angle) * dist
            local sz    = center.z
            local found, gz = GetGroundZFor_3dCoord(sx, sy, 1000.0, false)
            if found then sz = gz end
            local zombie = CreatePed(4, model, sx, sy, sz, math.random() * 360.0, false, false)
            if DoesEntityExist(zombie) then
                Wait(0)
                SetupZombie(zombie, player)
                spawnedZombies[#spawnedZombies + 1] = zombie
            end
            SetModelAsNoLongerNeeded(model)
        end
        if i % 5 == 0 then Wait(10) end
    end
end

local function CleanZombies()
    if not spawnedZombies then spawnedZombies = {} return end
    for _, z in ipairs(spawnedZombies) do
        if DoesEntityExist(z) and not IsPedAPlayer(z) then
            DeletePed(z)
        end
    end
    spawnedZombies = {}
end

local function DoZombieApocalypse()
    zombieActive   = true
    spawnedZombies = {}
    CleanZombies()

    SetWeatherTypeNow('HALLOWEEN')
    SetWindSpeed(20.0)
    SetTimecycleModifier('damage')
    SetTimecycleModifierStrength(0.25)
    SetArtificialLightsState(true)

    CreateThread(function()
        while activeSpecialEvent == 'zombie_apocalypse' do
            Wait(3000)
            SetWeatherTypeNow('HALLOWEEN')
            SetArtificialLightsState(true)
        end
    end)

    local ped = PlayerPedId()
    EnsureZombieRelationshipGroup()

    CreateThread(function()
        while activeSpecialEvent == 'zombie_apocalypse' do
            Wait(math.random(3000, 7000))
            if activeSpecialEvent ~= 'zombie_apocalypse' then break end
            SendNUIMessage({ action='playZombieSound', file=ZOMBIE_SOUNDS[math.random(#ZOMBIE_SOUNDS)] })
        end
        SendNUIMessage({ action='stopZombieSound' })
    end)

    SendNUIMessage({ action='showAlert', text='🧟 ZOMBIE APOKALYPSA — PŘEŽIJ!' })

    local playerPos = GetEntityCoords(ped)
    SpawnZombieWave(20, 100.0, playerPos)

    CreateThread(function()
        while activeSpecialEvent == 'zombie_apocalypse' do
            Wait(3000)
            if activeSpecialEvent ~= 'zombie_apocalypse' then break end
            local player = PlayerPedId()
            for _, z in ipairs(spawnedZombies) do
                if DoesEntityExist(z) and not IsEntityDead(z) then
                    local state = GetScriptTaskStatus(z, 0x6C9D4D9F)
                    if state ~= 1 then
                        TaskCombatPed(z, player, 0, 16)
                    end
                end
            end
        end
    end)

    CreateThread(function()
        local waveCount = 0
        while activeSpecialEvent == 'zombie_apocalypse' do
            Wait(15000)
            if activeSpecialEvent ~= 'zombie_apocalypse' then break end
            local alive = {}
            for _, z in ipairs(spawnedZombies) do
                if DoesEntityExist(z) and not IsEntityDead(z) then
                    alive[#alive + 1] = z
                end
            end
            spawnedZombies = alive
            if #spawnedZombies < 45 then
                local ppos = GetEntityCoords(PlayerPedId())
                SpawnZombieWave(math.random(12, 20), 130.0, ppos)
                waveCount = waveCount + 1
            end
            if waveCount > 0 and waveCount % 3 == 0 then
                local ppos = GetEntityCoords(PlayerPedId())
                SpawnZombieWave(12, 45.0, ppos)
            end
        end
        CleanZombies()
        zombieGroupHash = nil
        zombieActive = false
        SetArtificialLightsState(false)
        ClearTimecycleModifier()
        SetWindSpeed(0.0)
    end)
end


-- ============================================================
-- HLAVNÍ EVENT DISPATCHER — přijímá eventy ze serveru
-- ============================================================
RegisterNetEvent('morjard-weather:client:specialEvent', function(eventType)
    print('^3[Morjard-Events]^7 Received: ' .. tostring(eventType))

    StopGameplayCamShaking(true)
    AnimpostfxStopAll()
    SetArtificialLightsState(false)
    StopSandParticles()
    ClearTimecycleModifier()

    activeSpecialEvent = nil
    Wait(200)

    if eventType == 'stop_all' then
        weatherLocked = false
        SetRainLevel(0.0)
        SetWindSpeed(0.0)
        CleanMeteorBoulders()
        CleanZombies()
        if currentZone and zoneWeather[currentZone] then
            ApplyWeather(zoneWeather[currentZone].weather, true)
        end
        SendNUIMessage({ action='eventStopped' })
        SendNUIMessage({ action='hideAlert' })
        return
    end

    activeSpecialEvent = eventType

    if     eventType == 'tsunami'           then DoTsunami()
    elseif eventType == 'earthquake'        then DoEarthquake()
    elseif eventType == 'meteor'            then DoMeteor()
    elseif eventType == 'blackout'          then DoBlackout()
    elseif eventType == 'sandstorm'         then DoSandstorm()
    elseif eventType == 'heatwave'          then DoHeatwave()
    elseif eventType == 'blizzard_event'    then DoBlizzardEvent()
    elseif eventType == 'fogpocalypse'      then DoFogpocalypse()
    elseif eventType == 'zombie_apocalypse' then DoZombieApocalypse()
    end

    SendNUIMessage({ action='eventStarted', event=eventType })
end)


-- PLAYER TABLET (hráčský UI pro /weather)
-- ============================================================
local playerTabletOpen = false

RegisterNetEvent('morjard-weather:client:openPlayerTablet', function()
    if playerTabletOpen then return end
    playerTabletOpen = true

    local zonesData = {}
    for i, zone in ipairs(Config.WeatherZones) do
        local wd = zoneWeather[i] or { weather='CLEAR', temperature=20 }
        zonesData[#zonesData+1] = {
            id          = i,
            name        = zone.name,
            description = zone.description or '',
            weather     = wd.weather,
            temperature = wd.temperature,
        }
    end

    local zoneName = (currentZone and Config.WeatherZones[currentZone]) and Config.WeatherZones[currentZone].name or 'Unknown'
    local wLabel, icon, wind = 'Unknown', 'sun', 0
    local wType = 'CLEAR'
    if currentWeatherState and Config.WeatherTypes[currentWeatherState] then
        local wd = Config.WeatherTypes[currentWeatherState]
        wLabel, icon, wind = wd.label, wd.icon, wd.windSpeed or 0
        wType = currentWeatherState
    end

    SendNUIMessage({
        action       = 'openPlayerTablet',
        locale       = Config.Locale,
        zones        = zonesData,
        currentZone  = currentZone or 1,
        activeEvent  = activeSpecialEvent,
        time         = string.format('%02d:%02d', currentTime.hour, currentTime.minute),
        weather      = {
            zone        = zoneName,
            weather     = wLabel,
            weatherIcon = icon,
            weatherType = wType,
            windSpeed   = wind,
            temperature = currentTemperature,
            time        = string.format('%02d:%02d', currentTime.hour, currentTime.minute),
        }
    })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
end)

RegisterNUICallback('closePlayerTablet', function(data, cb)
    playerTabletOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('tabletWidgetToggle', function(data, cb)
    showWidget = data.enabled
    if showWidget then
        SendNUIMessage({ action = 'show' })
        UpdateWidget()
    else
        SendNUIMessage({ action = 'hide' })
    end
    cb('ok')
end)

CreateThread(function()
    while true do
        Wait(2000)
        if playerTabletOpen then
            if activeSpecialEvent then
                SendNUIMessage({ action='eventStarted', event=activeSpecialEvent })
            else
                SendNUIMessage({ action='eventStopped' })
            end
        end
    end
end)

print('^2[Morjard-Weather]^7 Client v5 loaded — performance optimized')
