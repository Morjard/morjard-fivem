fx_version 'cerulean'
game 'gta5'

name        'Morjard Loading Screen'
description 'Custom FiveM loading screen for Morjard Roleplay'
author      'Morjard Development Team'
version     '2.3.0'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'

files {
    'html/index.html',
    'html/song.mp3',
    'html/gallery/photo1.png',
    'html/gallery/photo2.png',
    'html/gallery/photo3.png',
    'html/gallery/photo4.png'
}

client_script 'client.lua'
