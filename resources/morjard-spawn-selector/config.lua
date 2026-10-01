Config = {}

-- ============================================================
-- SPAWN LOCATIONS
-- ============================================================
-- Each location: id, name, description, category, icon (FA), coords, heading
-- Categories: 'default', 'property', 'last' (last is auto-injected)
-- css.top/css.left = pin position on the game world overlay (percentage)
-- These are used ONLY for the diamond pins overlaying the game camera view

Config.Locations = {
    {
        id = 'legion',
        name = 'LEGION SQUARE',
        description = 'Central downtown Los Santos',
        category = 'default',
        icon = 'city',
        pos = { x = 195.17, y = -933.77, z = 30.69 },
        heading = 145.0,
    },
    {
        id = 'hospital',
        name = 'PILLBOX HOSPITAL',
        description = 'Los Santos medical center',
        category = 'default',
        icon = 'hospital',
        pos = { x = 311.81, y = -590.42, z = 43.29 },
        heading = 339.5,
    },
    {
        id = 'police',
        name = 'MISSION ROW PD',
        description = 'Los Santos police department',
        category = 'default',
        icon = 'shield-halved',
        pos = { x = 428.23, y = -984.28, z = 30.71 },
        heading = 3.5,
    },
    {
        id = 'parking',
        name = 'PARKING GARAGE',
        description = 'Multi-level parking structure',
        category = 'default',
        icon = 'square-parking',
        pos = { x = 216.28, y = -816.07, z = 30.64 },
        heading = 70.0,
    },
    {
        id = 'paleto',
        name = 'PALETO BAY',
        description = 'Quiet coastal town up north',
        category = 'default',
        icon = 'water',
        pos = { x = -277.14, y = 6226.41, z = 31.49 },
        heading = 45.63,
    },
    {
        id = 'beach',
        name = 'VESPUCCI BEACH',
        description = 'Sun, sand, and ocean breeze',
        category = 'default',
        icon = 'umbrella-beach',
        pos = { x = -1458.93, y = -1085.03, z = 3.46 },
        heading = 310.0,
    },
    {
        id = 'airport',
        name = 'LS AIRPORT',
        description = 'Los Santos International Airport',
        category = 'default',
        icon = 'plane',
        pos = { x = -1037.66, y = -2963.18, z = 13.95 },
        heading = 150.0,
    },
    {
        id = 'sandy',
        name = 'SANDY SHORES',
        description = 'Desert town in Blaine County',
        category = 'default',
        icon = 'sun',
        pos = { x = 1839.0, y = 3672.0, z = 34.0 },
        heading = 210.0,
    },
}

-- ============================================================
-- CAMERA SETTINGS
-- ============================================================

Config.Camera = {
    topHeight = 800.0,        -- Initial top-down camera height
    previewHeight = 120.0,    -- Camera height when previewing a location
    previewAngle = -35.0,     -- Camera pitch for preview
    previewOffset = 80.0,     -- How far behind the location the camera sits
    descentSpeed = 4.0,       -- Camera descent speed multiplier
    transitionTime = 1500,    -- ms for camera transition between previews
}

-- ============================================================
-- FEATURES
-- ============================================================

Config.EnableLastLocation = true   -- Show "Last Location" button
Config.SaveLastLocation = true     -- Save player position on disconnect
Config.UseDatabase = true          -- Save last location to database (oxmysql)
                                   -- If false, uses server memory only (resets on restart)
