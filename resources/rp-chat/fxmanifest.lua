fx_version 'cerulean'
game 'gta5'

name 'rp-chat'
description 'Advanced RP Chat System with modern UI'
author 'Morjard'
version '1.0.0'

lua54 'yes'

dependency 'oxmysql'
dependency 'morjard-settings'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'html/index.html',
    'html/assets/**/*'
}
