---@type utils
local utils = require('..src.utils')

local roblox_pid = utils.process.get_pid_by_name("RobloxPlayerBeta.exe")
utils.process.open(roblox_pid)

-- TODO: New varname
local base