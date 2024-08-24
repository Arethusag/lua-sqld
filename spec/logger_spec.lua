-- spec/logger_spec.lua
package.path = package.path .. ";./?.lua"

local Logger = require("logger")

describe("Logger", function()
    local test_log_file = "test.log"
    local logger

    setup(function()
        logger = Logger:new(test_log_file)
    end)

    teardown(function()
        os.remove(test_log_file)
    end)

    it("logs messages with a timestamp", function()
        logger:log("Test message")
        local file = assert(io.open(test_log_file, "r"))
        local content = file:read("*a")
        file:close()

        assert.is_not_nil(string.find(content, "Test message"))
        assert.is_not_nil(string.match(content, "%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d"))
    end)
end)
