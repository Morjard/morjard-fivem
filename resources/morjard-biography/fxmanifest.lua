fx_version 'cerulean'
games {'gta5'}

author 'morjard'
description 'morjard-biography - track worked hours and job history (biography CV)'
version '1.0.0'

shared_scripts {
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/locales/*.json'
}

dependencies {
    'qb-core',
    'oxmysql'
}