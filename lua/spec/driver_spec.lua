package.path = package.path .. ";./?.lua"

local Driver = require("sqld.driver")
local utils = require("sqld.utils")
local config = utils.parse_inifile("test.ini")

describe("Driver", function()
    local driver
    local DSN

    -- Use first DSN entry in test.ini as the mock odbc connection
    for key, _ in pairs(config) do
        DSN = key
        break
    end


    before_each(function()
        driver = Driver:new()
        driver:connect(DSN)
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
