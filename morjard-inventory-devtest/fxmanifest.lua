fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Morjard'
description 'Dev-only manual test harness for morjard-inventory FLOW types'
version '0.1.0'

dependency 'morjard-inventory'
dependency 'qb-inventory'

server_scripts {
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}
