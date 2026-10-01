fx_version 'cerulean'
game 'gta5'

name 'morjard-multicharacter'
author 'Morjard Dev Team'
description 'Morjard Multicharacter Selection System'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/vip_config.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/map.jpg',
    'html/morjard-style-bridge.js',
}

lua54 'yes'

dependencies {
    'qb-core',
    'oxmysql',
}

dependency 'morjard-settings'

-- Allow resources that depend on 'qb-multicharacter' to find this resource
provide 'qb-multicharacter'
