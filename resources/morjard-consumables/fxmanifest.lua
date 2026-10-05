-- morjard-consumables: registers QBCore useable items (food/drink/medical)
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Morjard'
description 'Standalone useable item registration for QBCore consumables'
version '1.0.0'

dependency 'qb-core'

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }
