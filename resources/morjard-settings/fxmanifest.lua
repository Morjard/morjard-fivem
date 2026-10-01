fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'morjard-settings'
author 'Morjard'
description 'Shared hybrid style config (Morjard / DDCZ) for other Morjard resources'
version '1.0.0'

shared_scripts {
	'shared/settings.lua',
}

server_scripts {
	'server/main.lua',
}

client_scripts {
	'client/main.lua',
}

exports {
	'GetStyle',
	'GetActiveStyleName',
}

server_exports {
	'GetStyle',
	'GetActiveStyleName',
}
