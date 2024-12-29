local json = require("cjson")
local socket = require("socket")

local utils = {}

function utils.encode_json_singleline(table)
    local json_string = json.encode(table)
    json_string = json_string:gsub("\n", "")
    return json_string .. "\n"
end

function utils.get_free_os_port(host)
    local temp_socket = socket.tcp()
    temp_socket:bind(host, 0)
    local _, port = temp_socket:getsockname()
    temp_socket:close()
    return port
end 

return utils
