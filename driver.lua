local luasql = require("luasql.odbc")
local Logger = require("logger")
local utils = require("utils")


local Driver = {}
Driver.__index = Driver

function Driver:new()
    local driver = {}
    setmetatable(driver, Driver)
    driver.queries = {}
    driver.env = luasql.odbc()
    driver.driver_logger = Logger:new("dispatcher.log", "driver.lua")
    return driver
end

function Driver:connect(dsn)
    self.driver_logger:log("Instantiating connection to databse")
    local conn, err = self.env:connect(dsn)
    if not conn then
        self.driver_logger:log("Failed to connect: " .. tostring(err))
        error(err)
    end
    self.conn = conn
    self.driver_logger:log("Connected to database")
end

function Driver:disconnect()
    if self.conn then
        self.driver_logger:log("Closing database connection")
        self.conn:close()
        self.conn = nil
    end
    if self.env then
        self.env:close()
        self.env = nil
    end
    self.driver_logger:log("Disconnected from database")
end

function Driver:execute_query(query_id, query_string)
    self.driver_logger:log("Executing query: " .. query_id)
    local success, result = pcall(function()
        local cursor, err = self.conn:execute(query_string)
        if not cursor then
            self.driver_logger:log("Query execution failed: " .. tostring(err))
            error(err)
        end

        local rows = {}
        local row = cursor:fetch({}, "a")
        while row do
            table.insert(rows, row)
            row = cursor:fetch({}, "a")
        end

        cursor:close()
        return rows
    end)

    if success then
        self.queries[query_id] = { status = "completed", result = result }
    else
        local error_message = tostring(result)
        self.queries[query_id] = { status = "error", error = error_message }
    end

    local json_result = utils.encode_json_singleline(self.queries[query_id])
    self.driver_logger:log("Query results: " .. json_result)
end

function Driver:get_query_result(query_id)
    local result = self.queries[query_id]
    self.driver_logger:log("Retrieving query result: " ..
        utils.encode_json_singleline(result))
    return result
end

return Driver
