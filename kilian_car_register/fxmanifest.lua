fx_version 'cerulean'
game 'gta5'

author 'Kilian'
description 'LSPD Car register'

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server.lua'
}

client_scripts {
    'client.lua'
}

dependencies {
    'es_extended'
}
