-- require("mobdebug").start()
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
        error("Failed to open file: " .. filepath)
    end

    local config = {}
    local current_section = nil

    for line in file:lines() do
        if line:match("^%[(.+)%]$") then
            current_section = line:match("^%[(.+)%]$")
            config[current_section] = { }
        elseif line:match("^(.+)=(.+)$") and current_section then
            local key, value = line:match("^(.+)=(.+)$")
            config[current_section][key] = value
        end
    end

    file:close()
    return config
end

function utils.get_os()
    local os
    local path_separator = tostring(package.config:sub(1,1))
    
    if not path_separator then
        error("Unable to determine host operating system")
    end

    if path_separator == '\\' then 
        return "MS-Windows"

    elseif path_separator == '/' then
        return "Unix"
    else
        error("Unknown path separator: " .. tostring(path_separator))
    end
end 

function utils.query_registry()
    local odbc_sources = {}
    local command = 'reg query "HKCU\\SOFTWARE\\ODBC\\ODBC.INI\\ODBC Data Sources"'

    local handle = io.popen(command)
    if not handle then
        error("Failed to execute registry query command: " .. command)
    end

    for line in handle:lines() do
        local dsn, driver = line:match("^%s*(%S+)%s+REG_SZ%s+(.*)$")
        if dsn and driver then
            odbc_sources[dsn] = { Driver = driver }
        end
    end

    handle:close()
    return odbc_sources
end
    
function utils.get_odbc_data_sources()
    local os = utils.get_os()

    if os == "MS-Windows" then
        return utils.query_registry()
    elseif os == "Unix" then
        return utils.parse_inifile("/etc/odbc.ini")
    else
        error("Unable to determine host OS")
    end
end

return utils
