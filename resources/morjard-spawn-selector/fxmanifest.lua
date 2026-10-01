fx_version 'cerulean'
game 'gta5'

author 'Morjard'
description 'Morjard Spawn Selector - Standalone spawn location picker with Ember Design'
version '1.0.0'

lua54 'yes'

-- Both client/main.lua and server/main.lua call exports['qb-core']:GetCoreObject()
-- unprotected on their very first line -- this makes FXServer actually wait for
-- qb-core to start first instead of relying on server.cfg ensure order (found
-- 2026-10-01: it happened to work only because `ensure qb-core` is placed before
-- every category ensure in server.cfg, an unenforced convention).
dependency 'qb-core'
dependency 'morjard-settings'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/js/morjard-style-bridge.js',
    'html/dev.html',
}
