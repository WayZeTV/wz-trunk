fx_version 'cerulean'
game 'gta5'

author 'WayZe'
description 'Système de coffre de véhicule pour ESX'
version '1.0.0'

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

dependencies {
    'es_extended',
    'mysql-async'
}