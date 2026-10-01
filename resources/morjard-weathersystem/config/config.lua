Config = {}

-- Debug mode: print weather changes to console (false = quiet)
Config.Debug = false

-- ============================================================
--  JAZYK / LANGUAGE
--  Dostupné / Available: 'en', 'cs', 'de', 'fr', 'ru', 'ua', 'ja', 'es', 'it'
--  Překlady jsou v: locales/<jazyk>.lua
-- ============================================================
Config.Locale = 'en'

-- ============================================================
--  BEZPEČNOST / SECURITY
-- ============================================================
Config.Security = {
    enabled              = true,
    kickOnExploit        = true,
    logExploits          = true,
    maxRequestsPerMinute = 20,
}

-- ============================================================
--  SYNCHRONIZACE / SYNC
-- ============================================================
Config.Sync = {
    forceSyncInterval = 5000,   -- ms — jak často se posílá sync počasí všem
    timeInterval      = 1000,   -- ms — jak často se posílá sync času
}

-- ============================================================
--  ČAS / TIME
-- ============================================================
Config.TimeSync       = true    -- synchronizovat herní čas na všechny hráče
Config.TimescaleSpeed = 1       -- minuty za sekundu (1 = reálný čas ingame)

Config.RealTime = {
    enabled  = false,           -- true = herní čas = skutečný čas
    timezone = 1,               -- UTC offset (1 = Praha)
}

-- ============================================================
--  DYNAMICKÉ POČASÍ / DYNAMIC WEATHER
--  Po změně adminem je zóna uzamčena na 5 minut,
--  pak se počasí opět mění dynamicky.
--  Nikdy se nemění během aktivního eventu.
-- ============================================================
Config.DynamicWeather = {
    enabled          = true,
    changeInterval   = 5,       -- minuty mezi každou změnou
    respectPermanent = true,    -- přeskočit permanentní zóny
}

-- ============================================================
--  TEPLOTA & ŽÍZEŇ / TEMPERATURE & THIRST
-- ============================================================
Config.Temperature = {
    thirstEnabled        = true,

    -- Animace zimy
    coldEnabled          = true,
    coldThreshold        = 5,       -- °C — pod tím se hráč třese
    coldSevereThreshold  = -3,      -- °C — pod tím silné třesení
    coldCheckInterval    = 5000,    -- ms — jak často se kontroluje
    jacketComponentId    = 3,
    jacketDrawableMin    = 1,
}

-- ============================================================
--  UI WIDGET
-- ============================================================
Config.UI = {
    position        = 'top-right',
    showTemperature = true,
    showWind        = true,
    showTime        = true,
    showZone        = true,
}

-- ============================================================
--  ZVUKY / SOUNDS  (soubory v: sound/)
-- ============================================================
Config.Sounds = {
    sirenEnabled  = true,
    sirenFile     = 'siren.mp3',
    sirenVolume   = 0.85,
    sirenDuration = 15000,      -- ms — jak dlouho hraje sirény
}

-- ============================================================
--  PERMANENTNÍ ZÓNY / PERMANENT ZONES
--  Tyto zóny mají vždy pevné počasí, dynamika je nezmění.
--  Klíč = index zóny v Config.WeatherZones (níže)
-- ============================================================
Config.PermanentWeatherZones = {
    [5] = 'XMAS',   -- Mount Chiliad — vždy sníh
}

-- ============================================================
--  TYPY POČASÍ / WEATHER TYPES
--  canTransitionTo = do jakého počasí může přejít dynamicky
-- ============================================================
Config.WeatherTypes = {
    ['EXTRASUNNY'] = { label='Extra Sunny',   icon='sun',        rainLevel=0.0, windSpeed=0.0,  fogLevel=0.0, temperature=30, tempMin=26, tempMax=36, canTransitionTo={'CLEAR','CLOUDS'} },
    ['CLEAR']      = { label='Clear Sky',     icon='sun',        rainLevel=0.0, windSpeed=5.0,  fogLevel=0.0, temperature=25, tempMin=20, tempMax=28, canTransitionTo={'EXTRASUNNY','CLOUDS','CLEARING'} },
    ['CLOUDS']     = { label='Cloudy',        icon='cloud',      rainLevel=0.0, windSpeed=10.0, fogLevel=0.1, temperature=18, tempMin=14, tempMax=22, canTransitionTo={'CLEAR','OVERCAST','RAIN','FOGGY'} },
    ['OVERCAST']   = { label='Overcast',      icon='cloud',      rainLevel=0.0, windSpeed=15.0, fogLevel=0.2, temperature=15, tempMin=10, tempMax=18, canTransitionTo={'CLOUDS','RAIN','THUNDER','FOGGY'} },
    ['RAIN']       = { label='Rain',          icon='cloud-rain', rainLevel=0.3, windSpeed=20.0, fogLevel=0.3, temperature=13, tempMin=8,  tempMax=16, canTransitionTo={'OVERCAST','THUNDER','CLEARING'} },
    ['THUNDER']    = { label='Thunderstorm',  icon='cloud-bolt', rainLevel=0.5, windSpeed=30.0, fogLevel=0.5, temperature=12, tempMin=7,  tempMax=15, canTransitionTo={'RAIN','CLEARING','OVERCAST'} },
    ['CLEARING']   = { label='Clearing',      icon='cloud-sun',  rainLevel=0.1, windSpeed=15.0, fogLevel=0.1, temperature=20, tempMin=16, tempMax=24, canTransitionTo={'CLEAR','CLOUDS','OVERCAST'} },
    ['FOGGY']      = { label='Foggy',         icon='smog',       rainLevel=0.0, windSpeed=5.0,  fogLevel=0.8, temperature=12, tempMin=8,  tempMax=16, canTransitionTo={'CLOUDS','OVERCAST','CLEAR'} },
    ['SMOG']       = { label='Smog',          icon='smog',       rainLevel=0.0, windSpeed=2.0,  fogLevel=0.6, temperature=23, tempMin=20, tempMax=28, canTransitionTo={'FOGGY','OVERCAST','CLEAR'} },
    ['SNOW']       = { label='Snow',          icon='snowflake',  rainLevel=0.0, windSpeed=15.0, fogLevel=0.2, temperature=-2, tempMin=-6, tempMax=1,  canTransitionTo={'SNOWLIGHT','BLIZZARD','CLOUDS'} },
    ['BLIZZARD']   = { label='Blizzard',      icon='wind',       rainLevel=0.0, windSpeed=40.0, fogLevel=0.7, temperature=-8, tempMin=-14,tempMax=-4, canTransitionTo={'SNOW','SNOWLIGHT','CLOUDS'} },
    ['SNOWLIGHT']  = { label='Light Snow',    icon='snowflake',  rainLevel=0.0, windSpeed=10.0, fogLevel=0.1, temperature=0,  tempMin=-3, tempMax=3,  canTransitionTo={'SNOW','CLOUDS','CLEAR'} },
    ['XMAS']       = { label='Christmas',     icon='snowflake',  rainLevel=0.0, windSpeed=5.0,  fogLevel=0.0, temperature=-1, tempMin=-4, tempMax=2,  canTransitionTo={'XMAS'} },
    ['HALLOWEEN']  = { label='Sandstorm Sky', icon='smog',       rainLevel=0.0, windSpeed=25.0, fogLevel=0.5, temperature=28, tempMin=24, tempMax=35, canTransitionTo={'SMOG','OVERCAST'} },
    ['NEUTRAL']    = { label='Neutral',       icon='cloud',      rainLevel=0.0, windSpeed=5.0,  fogLevel=0.0, temperature=20, tempMin=16, tempMax=24, canTransitionTo={'CLEAR','CLOUDS'} },
}

-- ============================================================
--  ZÓNY POČASÍ / WEATHER ZONES
--  Každá zóna má vlastní počasí a teplotu.
--  Hráč se automaticky přepne do nejbližší zóny.
-- ============================================================
Config.WeatherZones = {
    {
        name        = 'Los Santos City',
        center      = vector3(-265.0, -963.0, 31.0),
        radius      = 2500.0,
        weather     = 'CLEAR',
        temperature = 26,
        description = 'Downtown, Airport, Del Perro, Vinewood',
    },
    {
        name        = 'Sandy Shores Desert',
        center      = vector3(1863.0, 3747.0, 33.0),
        radius      = 2000.0,
        weather     = 'EXTRASUNNY',
        temperature = 32,
        description = 'Sandy Shores, Grand Senora Desert',
    },
    {
        name        = 'Paleto Bay',
        center      = vector3(-105.0, 6469.0, 31.0),
        radius      = 1500.0,
        weather     = 'CLOUDS',
        temperature = 18,
        description = 'Paleto Bay, Paleto Forest',
    },
    {
        name        = 'Grapeseed Area',
        center      = vector3(1700.0, 4700.0, 42.0),
        radius      = 1500.0,
        weather     = 'CLEARING',
        temperature = 22,
        description = 'Grapeseed, Alamo Sea',
    },
    {
        name        = 'Mount Chiliad',
        center      = vector3(501.0, 5604.0, 797.0),
        radius      = 1200.0,
        weather     = 'XMAS',
        temperature = -1,
        description = 'Mount Chiliad Peak — vždy sníh',
    },
}

-- ============================================================
--  ČASOVÉ ZÓNY PRO MENU / TIMEZONES FOR ADMIN MENU
-- ============================================================
Config.Timezones = {
    { offset=-12, name='Baker Island',   icon='earth-americas',   country='Pacific' },
    { offset=-11, name='American Samoa', icon='umbrella-beach',   country='Samoa' },
    { offset=-10, name='Hawaii',         icon='water',            country='USA' },
    { offset=-9,  name='Alaska',         icon='snowflake',        country='USA' },
    { offset=-8,  name='Los Angeles',    icon='film',             country='USA' },
    { offset=-7,  name='Denver',         icon='mountain',         country='USA' },
    { offset=-6,  name='Mexico City',    icon='sun',              country='Mexico' },
    { offset=-5,  name='New York',       icon='building',         country='USA' },
    { offset=-4,  name='Santiago',       icon='mountain-sun',     country='Chile' },
    { offset=-3,  name='Buenos Aires',   icon='futbol',           country='Argentina' },
    { offset=-2,  name='South Georgia',  icon='anchor',           country='Atlantic' },
    { offset=-1,  name='Azores',         icon='ship',             country='Portugal' },
    { offset=0,   name='London',         icon='clock',            country='UK' },
    { offset=1,   name='Prague',         icon='crown',            country='Czech Republic', dst=true },
    { offset=2,   name='Athens',         icon='landmark',         country='Greece' },
    { offset=3,   name='Moscow',         icon='hammer',           country='Russia' },
    { offset=4,   name='Dubai',          icon='city',             country='UAE' },
    { offset=5,   name='Karachi',        icon='mosque',           country='Pakistan' },
    { offset=6,   name='Dhaka',          icon='tree',             country='Bangladesh' },
    { offset=7,   name='Bangkok',        icon='spa',              country='Thailand' },
    { offset=8,   name='Singapore',      icon='building-columns', country='Singapore' },
    { offset=9,   name='Tokyo',          icon='mountain',         country='Japan' },
    { offset=10,  name='Sydney',         icon='person-swimming',  country='Australia' },
    { offset=11,  name='Noumea',         icon='umbrella-beach',   country='New Caledonia' },
    { offset=12,  name='Auckland',       icon='kiwi-bird',        country='New Zealand' },
}
