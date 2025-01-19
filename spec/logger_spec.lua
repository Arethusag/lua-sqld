-- spec/logger_spec.lua
package.path = package.path .. ";./lua/?.lua"

local Logger = require("sqld.logger")

describe("Logger", function()
    local log_file = "logger.log"
    local source = "logger_spec.lua"
    local logger

    setup(function()
        logger = Logger:new(log_file, source)
    end)

    teardown(function()
        os.remove(log_file)
    end)

    it("Logs messages in correct format", function()
        logger:log("Test message")
        local file = assert(io.open(log_file, "r"))
        local content = file:read("*a")
        file:close()

        assert.is_not_nil(string.find(content, "Test message"))
        --assert.is_not_nil(string.find(content, "logger_spec.lua"))
        assert.is_not_nil(string.match(content, "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d"))
    end)
end)
