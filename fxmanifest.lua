fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Blackstone Development'
description 'Emergency Alert System for FiveM featuring targeted alerts, phone integration, and chat fallback.'
version '20.0.0'

ui_page 'web/composer.html'

files {
    'web/composer.html',
    'web/composer.css',
    'web/composer.js',
    'web/app.html',
    'web/app.css',
    'web/app.js',
    'web/eastone.mp3',
    'web/icons/*.svg'
}

shared_script 'config.lua'
client_script 'client.lua'
server_script 'server.lua'
