fx_version 'cerulean'
game 'rdr3'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

name 'rd_scoardboard'
author 'RD SCRIPT/ RD DEV/Eagle County RP'
description 'Fast book-style RedM VORP/RedEM online players scoreboard with Discord info, saved playtime and optimized NUI'
version '1.4.6'

lua54 'yes'

shared_scripts {
    'config.lua',
    'languages/*.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server_config.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/img/*.*'
}
