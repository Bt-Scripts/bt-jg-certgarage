fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Certification system for jg job garages'
author 'bt-scripts'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

client_scripts {
    'client.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'es_extended',
}
