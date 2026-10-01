Config = {}

-- Interior for character preview (Eclipse Towers penthouse)
Config.Interior = vector3(-763.28, 330.04, 199.49)
Config.InteriorIpl = 'apa_v_mp_h_01_a'  -- IPL for Eclipse Towers apt (nil = no IPL needed)

-- Default spawn when no last position (LSIA airport)
Config.DefaultSpawn = vector4(-1035.71, -2731.87, 12.86, 326.76)

-- Ped spawn position inside interior
Config.PedCoords = vector4(-763.28, 330.04, 199.49, 177.79)

-- Camera position looking at ped (closer for portrait framing)
Config.CamCoords = vector4(-763.28, 328.5, 199.95, 0.0)

-- Camera rotation (rx, ry, rz) — rz=357 = facing north toward ped
Config.CamRot = vector3(-2.0, 0.0, 357.10)

-- ============================================================
-- CHARACTER SLOTS
-- ============================================================

-- Default slots for all players
Config.DefaultSlots = 4

-- When true, skip this resource's own built-in spawn-location modal and defer to the
-- standalone morjard-spawn-selector resource instead (opened once QBCore:Client:OnPlayerLoaded
-- fires, i.e. after the character has fully loaded). Off by default: flip to true only after
-- you've verified morjard-spawn-selector is active (`ensure morjard-spawn-selector` in
-- server.cfg) and tested the full character->spawn flow in-game yourself. See
-- docs/FINDING_spawn_selector_integration.md in the morjard-fivem repo for why this exists.
Config.UseSpawnSelector = false

-- VIP slot overrides and Tebex integration are in server/vip_config.lua
-- (server-only to prevent license hash exposure to clients)

-- Allow character deletion
Config.EnableDelete = true

-- Default ped model for new characters
Config.StarterModel = `mp_m_freemode_01`
Config.StarterModelFemale = `mp_f_freemode_01`

-- ============================================================
-- CAMERA SETTINGS
-- ============================================================

Config.CameraFoV = 38.0            -- Field of view (narrower = closer framing)
Config.CameraNearDof = 0.3         -- Near depth of field (sharper at close range)
Config.CameraFarDof = 3.0          -- Far depth of field (ped ~1.5m away now)
Config.CameraDofStrength = 0.8     -- DoF intensity (stronger background blur)
Config.CameraShake = 0.08          -- Subtle hand shake (0.0 = off)
Config.CameraShakeType = 'HAND_SHAKE'

-- ============================================================
-- PREVIEW PED ANIMATIONS
-- ============================================================

-- Random idle scenarios for preview ped (picked randomly each time)
Config.PreviewAnimations = {
    'WORLD_HUMAN_STAND_IMPATIENT',
    'WORLD_HUMAN_HANG_OUT_STREET',
    'WORLD_HUMAN_SMOKING',
    'WORLD_HUMAN_LEANING',
}

-- ============================================================
-- WEATHER & ATMOSPHERE
-- ============================================================

-- Override weather/time during character selection
Config.WeatherControl = true        -- Disable qb-weathersync during selection
Config.SelectionTime = 22           -- Hour (22 = night, dramatic spotlight on ped)
Config.SelectionWeather = 'CLEAR'   -- Weather type during selection

-- Timecycle blur on background during loading
Config.BlurStrength = 0.0           -- 0.0 = off, camera DoF + CSS vignette handles atmosphere

-- ============================================================
-- SPOTLIGHT ON PREVIEW PED
-- ============================================================

Config.SpotlightEnabled = true
Config.SpotlightColor = { r = 255, g = 248, b = 235 }  -- Warm white (no blue tint)
Config.SpotlightRange = 6.0
Config.SpotlightIntensity = 18.0
Config.SpotlightShadow = 14.0

-- ============================================================
-- SPAWN LOCATIONS (shown on map after character select)
-- ============================================================

Config.EnableLastLocation = true  -- Show "Last Location" option

Config.SpawnLocations = {
    -- Pin position calculated from coords via JS: mapX = (x+5500)/12000*100, mapY = (8000-y)/12000*100
    { id = 'legion',   label = 'Legion Square',    coords = vector4(195.17, -933.78, 30.69, 144.5),    icon = 'fa-city',           x = 195.17,  y = -933.78  },
    { id = 'hospital', label = 'Pillbox Hospital', coords = vector4(311.81, -590.42, 43.29, 339.5),    icon = 'fa-hospital',       x = 311.81,  y = -590.42  },
    { id = 'police',   label = 'Mission Row PD',   coords = vector4(428.23, -984.28, 30.71, 3.5),      icon = 'fa-shield-halved',  x = 428.23,  y = -984.28  },
    { id = 'airport',  label = 'LS Airport',        coords = vector4(-1037.7, -2737.8, 13.76, 326.76), icon = 'fa-plane',          x = -1037.7, y = -2737.8  },
    { id = 'paleto',   label = 'Paleto Bay',        coords = vector4(-277.14, 6226.41, 31.49, 45.63),  icon = 'fa-water',          x = -277.14, y = 6226.41  },
}
