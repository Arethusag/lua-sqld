local luasql = require("luasql.odbc")
local logger = require("logger")

local Driver = {}
Driver.__index = Driver

function Driver:new(options)
    local driver = {}
    setmetatable(driver, Driver)
    driver.options = options or {}
    driver.queries = {}
    driver.env = luasql.odbc()
    driver.logger = logger:new("driver.log")
    return driver
end

function Driver:connect()
    local conn, err = self.env:connect("PostgreSQL-TestDB")
    if not conn then
        error("Failed to connect: " .. tostring(err))
    end
    self.conn = conn
    self.logger:log("Connected to database")
end

function Driver:disconnect()
    if self.conn then
        self.conn:close()
        self.conn = nil
        self.logger:log("Disconnected from database")
    end
    if self.env then
        self.env:close()
        self.env = nil
    end
end

function Driver:execute_query(query_id, query_string)
    self.logger:log("Executing query: " .. query_id)
    local success, result = pcall(function()
        local cursor, err = self.conn:execute(query_string)
        if not cursor then
            error("Query execution failed: " .. tostring(err))
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
        self.queries[query_id] = { status = "error", error = result }
    end
end

function Driver:get_query_result(query_id)
    return self.queries[query_id]
end

return Driver
