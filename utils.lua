local socket = require("socket")

local utils = {}

function utils.get_free_os_port(host)
    local temp_socket = socket.tcp()
    temp_socket:bind(host, 0)
    local _, port = temp_socket:getsockname()
    temp_socket:close()
    return port
end 

function utils.parse_inifile(filepath)
    local file = io.open(filepath, "r")
    if not file then
        return nil, "Failed to open file: " .. filepath
    end

    local config = {}
    local current_section = nil

    for line in file:lines() do

        if line:match("^%[(.+)%]$") then
            current_section = line:match("^%[(.+)%]$")
            config[current_section] = {}
        elseif line:match("^(.+)=(.+)$") and current_section then
            local key, value = line:match("^(.+)=(.+)$")
            config[current_section][key] = value
        end
    end

  file:close()
  return config
end

return utils
