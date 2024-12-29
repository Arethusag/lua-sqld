local json = require("cjson")

local utils = {}

function utils.encode_json_singleline(table)
    local json_string = json.encode(table)
    json_string = json_string:gsub("\n", "")
    return json_string .. "\n"
end

return utils
