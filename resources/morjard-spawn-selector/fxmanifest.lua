fx_version 'cerulean'
game 'gta5'

author 'Morjard'
description 'Morjard Spawn Selector - Standalone spawn location picker with Ember Design'
version '1.0.0'

lua54 'yes'

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
