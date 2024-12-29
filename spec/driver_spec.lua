package.path = package.path .. ";./?.lua"

local mobdebug = require("mobdebug")
local Driver = require("driver")

mobdebug.start()

describe("Driver", function()
    local driver

    before_each(function()
        driver = Driver:new()
        driver:connect("localhost")
    end)

    after_each(function()
        driver:disconnect()
    end)

    it("should execute queries successfully", function()
        driver:execute_query("test_query", "SELECT GETDATE() AS date;")
        local result = driver:get_query_result("test_query")
        assert.are.equal("completed", result.status)
        assert.is_true(#result.result > 0)
        assert.is_not_nil(result.result[1].date)
    end)
end)
