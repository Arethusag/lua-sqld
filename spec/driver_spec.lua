package.path = package.path .. ";./?.lua"

local Driver = require("driver")

describe("Driver", function()
    local driver

    before_each(function()
        driver = Driver:new()
        driver:connect()
    end)

    after_each(function()
        driver:disconnect()
    end)

    it("should execute queries successfully", function()
        driver:execute_query("test_query", "SELECT COUNT(*) as client_count FROM client")
        local result = driver:get_query_result("test_query")
        assert.are.equal("completed", result.status)
        assert.is_true(#result.result > 0)
        assert.is_not_nil(result.result[1].client_count)
    end)

    it("should handle query errors", function()
        driver:execute_query("error_query", "SELECT * FROM non_existent_table")
        local result = driver:get_query_result("error_query")
        assert.are.equal("error", result.status)
        assert.is_not_nil(result.error)
    end)
end)
