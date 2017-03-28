--[[
Copyright 2014 by Dominik Markiewicz.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
darktable script to automatic backup dartkable configuration and databases

USAGE
* require this script from your main lua file
]] 

local dt = require "darktable"
local gettext = dt.gettext
dt.configuration.check_version(...,{4,0,0},{5,0,0})

gettext.bindtextdomain("backup", dt.configuration.config_dir.."lua")

-- UTILS
--
local function _(msgid)
  return gettext.dgettext("backup", msgid)
end

function table.slice(tbl, first, last, step)
  local sliced = {}
 
  for i = first or 1, last or #tbl, step or 1 do
    sliced[#sliced+1] = tbl[i]
  end
 
  return sliced
end

local function checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (result) then
    dt.print_error("true checkIfBinExists: "..bin)
    ret = true
  else
    dt.print_error(bin.." not found")
    ret = false
  end
  return ret
end

local function ensure_dest(dest)
  local result = dt.control.execute("mkdir -p "..dest)
  if result ~= 0 then 
    return _("cannot create destination directory!") 
  end
end

local function uncompressed_backup(source, dest, dest_name)
  local result = dt.control.execute("cp -r "..source.." "..dest.."/"..dest_name)  
  if result ~= 0 then
    return _("copy operation failed!")
  end
  
  return _("success")
end

local function zip_backup(source, dest, dest_name)
  local result = dt.control.execute("zip -r "..dest.."/"..dest_name..".zip "..source)
  if result ~= 0 then
    return _("cannot create zip archive")
  end
  return _("success")
end

local function tar_gz_backup(source, dest, dest_name)
  local result = dt.control.execute("tar -zcvf "..dest.."/"..dest_name..".tar.gz "..source)
  if result ~= 0 then
    return _("cannot create tar.gz archive")
  end
  return _("success")
end


local function tar_bz2_backup(source, dest, dest_name)
  local result = dt.control.execute("tar -jcvf "..dest.."/"..dest_name..".tar.bz2 "..source)
  if result ~= 0 then
    return _("cannot create tar.gz archive")
  end
  return _("success")
end

local function a7z_backup(source, dest, dest_name)
  local result = dt.control.execute("7z a -r "..dest.."/"..dest_name..".7z "..source)
  if result ~= 0 then
    return _("cannot create 7z archive")
  end
  return _("success")
end

local function get_available_formats(formats)
  local arr = {}
  for key, value in pairs(formats) do

    local exists = true 
    for _, bin in pairs(value.bin) do 
      exists = exists and checkIfBinExists(bin) 
    end
      
    if exists then
      table.insert(arr, key)
    end
  end
  dt.print_error("available backup types: "..table.concat(arr,", "))
  table.sort(arr)
  return arr
end

-------------------_REGISTRATION_--------------------------

local formats_config = {
  ["uncompressed"] = {
    ["tooltip"] = "save backup as uncompressed copy of Dartkable config",
    ["bin"] = {},
    ["exec"] = uncompressed_backup
  },
  ["zip"] = {
    ["tooltip"] = "save backup as zip archive",
    ["bin"] = {"zip"},
    ["exec"] = zip_backup 
  }, 
  ["tar.gz"] = {
    ["tooltip"] = "save backup as tar.gz archive",
    ["bin"] = {"tar", "gzip"},
    ["exec"] = tar_gz_backup 
  }, 
  ["tar.bz2"] = {
    ["tooltip"] = "save backup as tar.gz archive",
    ["bin"] = {"tar", "bzip2"},
    ["exec"] = tar_bz2_backup
  },
  ["7z"] = {
    ["tooltip"] = "save backup as 7z archive",
    ["bin"] = {"7z"},
    ["exec"] = a7z_backup

  }
}

local formats = get_available_formats(formats_config)

dt.preferences.register("backup",
      "method",
      "enum",
      _("backup: method"),
      _("Method used to backup. It some may require additional software to install (see. README)"),
      formats[1], table.unpack(table.slice(formats, 2, #formats)))

dt.preferences.register("backup",
      "remove_old_backups",
      "bool",
      _("backup: remove old backups (UNSAFE!)"),
      _("Allow to remove old backup files.\nWARINING: this method will try to remove all but n files/directories from backup directory. It's important to make sure that there is nothing more in the same directory, because this script will not recognize origin of the files"),
      false)

dt.preferences.register("backup",
      "number_of_persisted_backups",
      "integer",
      _("backup: number of backups to persist"),
      _("How many backups should be persisted. Value 0 means that backups should not be removed at all.\nWARNING: remooving backups can be potentialy harmful operation, so additional check is required to start process."),
      0,
      0,
      99)

local default_backup_path = os.getenv("HOME")..'/.backup/darktable'
ensure_dest(default_backup_path)
dt.preferences.register("backup",
      "backup_directory",
      "directory",
      _("Backup: backup directory"),
      _("Directory where all backups should be stored"),
      default_backup_path)

local function on_exit()
  -- check if should do stuff
  
  local backup_dir = dt.preferences.read("backup", "backup_directory", "string")
  ensure_dest(backup_dir)

  local filename_prefix = "dt_backup_"
  local date = os.date("%Y-%m-%d_%H-%M-%S")
  local filename = filename_prefix .. date
  local backup_method = dt.preferences.read("backup", "method", "string")
  local result = formats_config[backup_method]["exec"](dt.configuration.config_dir, backup_dir, filename)
  dt.print("Backup: "..result)

  local allow_remove = dt.preferences.read("backup", "remove_old_backups", "bool")
  if allow_remove then
    -- WARNING: following part of code can be harmfull in some very specific environment setup. 
    -- For more info look for "why do *not* process ls output" 
    local number_of_persisted_backups = dt.preferences.read("backup", "number_of_persisted_backups", "integer")
    if number_of_persisted_backups > 0 then
      local rm_cmd = "ls -dt "..backup_dir.."/"..filename_prefix.."* | tail -n +"..(number_of_persisted_backups+1).." | xargs rm -r -- "
      dt.control.execute(rm_cmd)
    end
  end
end

dt.register_event(
  "exit",
  on_exit
)

-- vim: ts=2 sw=2 et:
