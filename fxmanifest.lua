fx_version 'cerulean'
game 'gta5'

author 'Distortionz'
description 'Distortionz Weed Farm - Harvest a grow field for nuggets, roll them into joints (smoke to cut stress), or deal nuggets to street NPCs for dirty money.'
version '1.0.5'
repository 'https://github.com/Distortionzz/Distortionz_WeedFarm'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua',
    'version_check.lua'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'ox_inventory'
}
