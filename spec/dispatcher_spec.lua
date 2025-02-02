-- spec/dispatcher_spec.lua
package.path = package.path .. ";./lua/?.lua"

local socket = require("socket")
local json = require("cjson")
local utils = require("sqld.utils")
local Logger = require("sqld.logger")
local logger = Logger:new("log", "dispatcher_spec.lua")
local test_config = utils.parse_inifile("test.ini")

describe("TCP Dispatcher", function()
    local test_data_source
    local host = "127.0.0.1"
    local port = utils.get_free_os_port(host)

    for key, _ in pairs(test_config) do
        test_data_source = key
        break
    end

    local function create_client()
        local client = assert(socket.tcp())
        assert(client:connect(host, port))
        client:settimeout(5)
        return client
    end

    local function receive_response(client)
        local json_response, err = client:receive("*l")
        assert.is_nil(err)
        return json.decode(json_response)
    end

    local function send_and_receive(client, request)
        local message = json.encode(request)
        logger:log("Client sending request: " .. message)
        assert(client:send(message .. "\n"))
        local json_response, err = client:receive("*l")
        if err then
            logger:log("Error receiving response: " .. tostring(err))
        end
        if json_response then
            logger:log("Client received response: " .. json_response)
        else
            logger:log("No response received from server")
        end
        assert.is_nil(err)
        assert.is_not_nil(json_response, "Expected response from server but got none")
        return json.decode(json_response)
    end

    setup(function()
        logger:log("Setting up test environment")
        -- local lua_path = os.getenv("LUA")
        local cmd = os.getenv("LUA") .. " ./lua/sqld/init.lua " .. host .. " " .. port
        server_process = io.popen(cmd)
        logger:log("Dispatcher started")
    end)

    teardown(function()
        logger:log("Tearing down test environment")
        local client = create_client()
        local request = { action = "shutdown" }
        local message = json.encode(request)
        client:send(message .. "\n")
        client:close()

        if server_process then
            server_process:close()
        end
        logger:log("Server stopped")
    end)

    it("should accept client connections", function()
        logger:log("Testing client connection")
        local client = create_client()
        assert.is_truthy(client)
        client:close()
        logger:log("Client connection test completed")
    end)

    it("should handle database connection requests", function()
        logger:log("Testing database connection requests")
        local client = create_client()

        local request = {
            action = "connect",
            bufnr = "1",
            dsn = test_data_source
        }

        local message = json.encode(request)
        logger:log("Client sending request: " .. message)
        client:send(message .. "\n")

        local json_response, err = client:receive("*l")
        assert.is_nil(err, "Error receiving response: " .. tostring(err))
        assert.is_not_nil(json_response)

        local response = json.decode(json_response)
        assert.are.equal("success", response.status)

        client:close()
        logger:log("Database connection test completed")
    end)

    it("should execute a simple SELECT query", function()
        logger:log("Testing simple SELECT query execution")
        local client = create_client()

        local connect_request = {
            action = "connect",
            bufnr = "2",
            dsn = test_data_source
        }
        local connect_response = send_and_receive(client, connect_request)
        assert.are.equal("success", connect_response.status)

        local query_request = {
            action = "query",
            bufnr = "2",
            query_id = "test1",
            query_string = "SELECT 1 as test;"
        }
        local query_response = send_and_receive(client, query_request)
        
        assert.are.equal("completed", query_response.status)
        assert.is_not_nil(query_response.result)
        assert.are.equal(1, #query_response.result)
        assert.are.equal(1, query_response.result[1].test)

        client:close()
        logger:log("Simple SELECT query test completed")
    end)

    it("should handle database disconnect requests", function()
        logger:log("Testing database disconnect requests")
        local client = create_client()

        local connect_request = {
            action = "connect",
            bufnr = "3",
            dsn = test_data_source
        }

        local message = json.encode(connect_request)
        logger:log("Client sending request: " .. message)
        client:send(message .. "\n")

        local json_response, err = client:receive("*l")
        assert.is_nil(err, "Error receiving response: " .. tostring(err))
        assert.is_not_nil(json_response)

        local connect_response = json.decode(json_response)
        assert.are.equal("success", connect_response.status)

        local disconnect_request = {
            action = "disconnect",
            bufnr = "3",
        }

        local disconnect_response = send_and_receive(client, disconnect_request)
        assert.are.equal("success", disconnect_response.status)

        client:close()
        logger:log("Database disconnect test completed")
    end)

    it("should handle multiple queries sequentially", function()
        logger:log("Testing multiple sequential queries")
        local client = create_client()
        local connect_request = {
            action = "connect",
            bufnr = "4",
            dsn = test_data_source
        }

        local message = json.encode(connect_request)
        logger:log("Client sending request: " .. message)
        client:send(message .. "\n")

        local json_response, err = client:receive("*l")
        assert.is_nil(err, "Error receiving response: " .. tostring(err))
        assert.is_not_nil(json_response)

        local connect_response = json.decode(json_response)
        assert.are.equal("success", connect_response.status)

        local queries = {
            "SELECT 1 AS test;",
            "SELECT 2 AS test;",
            "SELECT 3 AS test;",
        }

        for i = 1, #queries do
            local query_request = {
                action = "query",
                bufnr = "4",
                query_id = "query" .. i,
                query_string = queries[i]
            }
            local query_response = send_and_receive(client, query_request)
            
            assert.are.equal("completed", query_response.status)
            assert.is_not_nil(query_response.result)
            assert.are.equal(1, #query_response.result)
            assert.are.equal(i, query_response.result[1].test)
        end

        logger:log("Multiple query test completed")
    end)

    it("should handle multiple queries concurrently", function()
        logger:log("Testing concurrent query handling")
        local client_count = 3
        local clients = {}
        local queries = {
            "SELECT 1 AS test;",
            "SELECT 2 AS test;",
            "SELECT 3 AS test;",
        }
        local responses = {}

        local function client_coroutine(index)
            local bufnr = 3 + index
            local client = create_client()
            clients[index] = client

            local connect_request = {
                action = "connect",
                bufnr = bufnr,
                dsn = test_data_source
            }

            local message = json.encode(connect_request)
            logger:log("Client sending request: " .. message)
            client:send(message .. "\n")

            local json_response, err = client:receive("*l")
            assert.is_nil(err, "Error receiving response: " .. tostring(err))
            assert.is_not_nil(json_response)

            local connect_response = json.decode(json_response)
            assert.are.equal("success", connect_response.status)
            coroutine.yield()

            local query_request = {
               action = "query",
               bufnr = bufnr,
               query_id = "query" .. index,
               query_string = queries[index]
            }

            local message = json.encode(query_request)
            logger:log("Client sending request: " .. message)
            client:send(message .. "\n")
            coroutine.yield()

            local json_response = client:receive("*l")
            logger:log("Client received response: " .. json_response)
            responses[index] = json.decode(json_response)
            client:close()
        end

        local threads = {}
        for i = 1, client_count do
            threads[i] = coroutine.create(function() client_coroutine(i) end)
        end
 
        for i = 1, client_count do
            assert(coroutine.resume(threads[i]))
        end
 
        for i = 1, client_count do
            assert(coroutine.resume(threads[i]))
        end
 
        for i = 1, client_count do
            assert(coroutine.resume(threads[i]))
        end
 
        for i = 1, client_count do
            assert.are.equal("completed", responses[i].status)
            assert.is_not_nil(responses[i].result)
            assert.are.equal(1, #responses[i].result)
            assert.are.equal(i, responses[i].result[1].test)
        end

        logger:log("Concurrent client test completed")
    end)

    it("should provide ODBC connection information", function()
        local client = create_client()
        local odbcinfo_request = {
            action = "odbcinfo",
        }

        local odbcinfo_message = json.encode(odbcinfo_request)
        logger:log("Client sending request: " .. odbcinfo_message)
        client:send(odbcinfo_message .. "\n")

        local json_response, err = client:receive("*l")
        logger:log("Client received response: " .. json_response)
        assert.is_nil(err, "Error receiving response: " .. tostring(err))
        assert.is_not_nil(json_response)

        local odbcinfo_response = json.decode(json_response)
        assert.are.equal("success", odbcinfo_response.status)
        client:close()
    end)
end)
