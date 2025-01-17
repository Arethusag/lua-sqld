-- spec/executor_spec.lua
-- require("mobdebug").start()
package.path = package.path .. ";./?.lua"

local socket = require("socket")
local utils = require("sqld.utils")
local Logger = require("sqld.logger")
local logger = Logger:new("log", "executor_spec.lua")
local json = require("cjson")

describe("SQL Executor", function()
    local executor
    local client
    local test_data_source
    local host = "localhost"
    local port = utils.get_free_os_port(host)
    local lua_cmd = os.getenv("LUA"):gsub('\\', "/")
    local test_config = utils.parse_inifile("test.ini")

    -- Use first DSN in test.ini for mock db tests
    for key, _ in pairs(test_config) do
        test_data_source = key
        break
    end

    -- Get the expected error message
    local invalid_query_error = test_config[test_data_source].InvalidQueryError

    local function send_request(request)
        local message = json.encode(request) .. "\n"
        local _, err = client:send(message)
        if err then
            error("Failed to send request: " .. (err or "unknown error"))
        end
    end

    local function receive_response()
        local response, err = client:receive("*l")
        if not response then
            error("Failed to receive response: " .. (err or "unknown error"))
        end
        return json.decode(response)
    end

    setup(function()
        logger:log("Setting up test environment")
        executor = assert(io.popen(lua_cmd .. " sqld/executor.lua " .. port))
        client = assert(socket.connect(host, port))
        client:settimeout(5)
        logger:log("Test environment set up complete")
    end)

    it("should connect to a valid database", function()

        logger:log("Testing database connection")
        local request = { action = "connect", dsn = test_data_source }
        send_request(request)
        logger:log("Connection request sent")

        
        local ready_received = false
        while not ready_received do
            local ready_msg = receive_response()
                if ready_msg.action == "ready" then
                    ready_received = true
                end
            socket.sleep(0.1)
        end

        local response = receive_response()
        assert.is_not_nil(response)
        logger:log("Connection response received: " .. json.encode(response))
        assert.are.equal("success", response.status)
        logger:log("Database connection test completed")
    end)

    it("should process a simple query", function()
        logger:log("Testing simple query processing")
        local query = {
            action = "query",
            query_id = "test1",
            query_string = "SELECT GETDATE() AS date;"
        }

        send_request(query)
        logger:log("Query sent: " .. json.encode(query))
        local response = receive_response()
        logger:log("Query response received: " .. json.encode(response))
        assert.are.equal("completed", response.status)
        assert.is_true(#response.result > 0)
        assert.is_not_nil(response.result[1].date)
        logger:log("Simple query test completed")
    end)

    it("should handle an invalid query", function()
        logger:log("Testing invalid query handling")
        local query = {
            action = "query",
            query_id = "test2",
            query_string = "SELECT * FROM non_existent_table;"
        }
        send_request(query)
        logger:log("Invalid query sent: " .. json.encode(query))

        local response = receive_response()
        logger:log("Invalid query response received: " .. json.encode(response))
        assert.are.equal("error", response.status)
        assert.is_not_nil(response.error)
        assert.truthy(response.error:find(invalid_query_error))
        logger:log("invalid query test completed")
    end)

    it("should process multiple queries sequentially", function()
        logger:log("Testing multiple sequential queries")
        local queries = {
            {
                action = "query",
                query_id = "test3",
                query_string = "SELECT GETDATE() as date;"
            },
            {
                action = "query",
                query_id = "test4",
                query_string = "SELECT GETDATE() as date, GETDATE() as date2;"
            }
        }

        for i, query in ipairs(queries) do
            logger:log("Sending query " .. i .. ": " .. json.encode(query))
            send_request(query)
            local response = receive_response()
            logger:log("Response received for query " .. i .. ": " ..
                json.encode(response)
            )
            assert.are.equal("completed", response.status)

            if i == 1 then
                assert.is_true(#response.result > 0)
                assert.is_not_nil(response.result[1].date)
            elseif i == 2 then
                assert.is_true(#response.result > 0)
                assert.is_not_nil(response.result[1].date)
                assert.is_not_nil(response.result[1].date2)
            end
        end
        logger:log("Multiple sequential queries test completed")
    end)

    it("should disconnect the driver when receiving a disconnect action", function()

        send_request({ action = "disconnect" })
        logger:log("Disconnect request sent")

        local response = receive_response()
        assert.is_not_nil(response)
        assert.are.equal("success", response.status)

        logger:log("Database disconnect test completed")
    end)

    it("should terminate when receiving a shutdown action", function()
        logger:log("Testing shutdown action")
        send_request({ action = "shutdown" })
        logger:log("Shutdown request sent")

        local exit_code = executor:close()
        logger:log("Executor exit code " .. tostring(exit_code))
        assert.is_true(exit_code)
        logger:log("Shutdown test completed")
    end)

    teardown(function()
        logger:log("Tearing down test environment")
        if client then
            client:close()
        end
        logger:log("test environment tear down complete")
    end)
end)
