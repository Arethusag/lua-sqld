local json = require("cjson")

local utils = {}

function utils.encode_json_singleline(table)
    local json_string = json.encode(table)
    json_string = json_string:gsub("\n", "")
    return json_string .. "\n"
end

function utils.write_to_pipe(pipe, data)
    local file = assert(io.open(pipe, "w"))
    file:write(json.encode(data) .. "\n")
    file:flush()
    file:close()
end

function utils.read_from_pipe(pipe)
    local file = assert(io.open(pipe, "r"))
    local data = file:read("*a")
    file:close()

    if data then
        local success, result = pcall(json.decode, data)
        if success then
            return result
        else
            error(result)
            return nil
        end
    else
        return nil
    end
end

return utils
