fx_version 'cerulean'
game      'gta5'

author      'Morjard'
description 'Advanced Dynamic Weather System'
version     '1.0.0'

shared_scripts {
    'config/config.lua',
    'locales/loader.lua',
    'locales/en.lua',
    'locales/cs.lua',
    'locales/de.lua',
    'locales/fr.lua',
    'locales/ru.lua',
    'locales/ua.lua',
    'locales/ja.lua',
    'locales/es.lua',
    'locales/it.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    -- NUI
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    -- Sounds
    'sound/siren.mp3',
    'sound/zombie/zombie_aggressive_1.mp3',
    'sound/zombie/zombie_aggressive_2.mp3',
    'sound/zombie/zombie_aggressive_3.mp3',
    'sound/zombie/zombie_aggressive_4.mp3',
    'sound/zombie/zombie_aggressive_5.mp3',
    'sound/zombie/zombie_growl_1.mp3',
    'sound/zombie/zombie_growl_2.mp3',
    -- Water (tsunami)
    'flood_initial.xml',
    'water.xml',
    -- VFX Weather Particle XML (Foxy_Oxy: Realistic Weather Effects Unleashed)
    'vfx/rainstorm_emitter_mist.xml',
    'vfx/rainstorm_render_drop.xml',
    'vfx/rainstorm_render_ground.xml',
    'vfx/rainstorm_render_mist.xml',
    'vfx/thunder_render_drop.xml',
    'vfx/thunder_render_ground.xml',
    'vfx/desert_emitter_ground.xml',
    'vfx/desert_render_ground.xml',
    'vfx/pollen_emitter_drop.xml',
    'vfx/pollen_render_drop.xml',
    'vfx/firefly_render_drop.xml',
    'vfx/vfxlightningsettings.xml',
}

-- Rain (RAIN / THUNDER) — realistic drops + fog
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/rainstorm_render_drop.xml'
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/rainstorm_render_ground.xml'
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/rainstorm_render_mist.xml'
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/rainstorm_emitter_mist.xml'
-- Thunderstorm (THUNDER) — more intense drops
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/thunder_render_drop.xml'
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/thunder_render_ground.xml'
-- Desert / Sandy Shores
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/desert_render_ground.xml'
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/desert_emitter_ground.xml'
-- Pollen (SMOG weather)
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/pollen_render_drop.xml'
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/pollen_emitter_drop.xml'
-- Fireflies (CLEAR at night)
data_file 'PTXGPU_SETTINGS_FILE' 'vfx/firefly_render_drop.xml'
-- Lightning (THUNDER) — realistic branched lightning
data_file 'VFX_LIGHTNING_SETTINGS_FILE' 'vfx/vfxlightningsettings.xml'

lua54 'yes'
