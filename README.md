# [Dartable](darktable.org) plugin (lua script) for automatic backup on exit

This plugin enable automatic backup procedure on Darktable exit. No additional software is required, however in this case backup will be raw copy of config directory. Plugin supports also compression, but some additional software may be required. Following backup modes are supported:

- uncompressed
- 7zip (install: 7z)
- zip (install: zip)
- tar.gz (install: tar, gzip)
- tar.bz2 (install: tar, bzip2)

## Install (Manual)
- copy `backup.lua` to your darktable config directory under lua folder (by default `~/.config/darktable/lua`) 
- edit your `luarc` (by default `~/.config/darktable/luarc`)
- put `require 'backup'`
- save file, open Darktable and go to configuration to set some options

## Install (Plugin manager)

...plugin manager is under preparation... soom :)
