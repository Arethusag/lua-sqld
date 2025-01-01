-- spec/dispatcher_spec.lua
package.path = package.path .. ";../?.lua;./?.lua"

--require("mobdebug").start()

local socket = require("socket")
local json = require("cjson")
local utils = require("utils")
local Logger = require("logger")
local logger = Logger:new("dispatcher.log", "dispatcher_spec.lua")
local config = require("inifile").parse("config.ini")

describe("TCP Dispatcher", function()
    local host = "127.0.0.1"
    local port = utils.get_free_os_port(host)

    local function create_client()
        local client = assert(socket.tcp())
        assert(client:connect(host, port))
        client:settimeout(0)
        return client
    end

    local function receive_response(client)
        local json_response, err = client:receive("*l")
        assert.is_nil(err)
        return json.decode(json_response)
    end


    local function send_and_receive(client, request)
        local json_request = utils.encode_json_singleline(request)
        logger:log("Client sending request: " .. json_request)
        assert(client:send(json_request))
        socket.sleep(1)
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
        local process_cmd = config.lua.exec .. " dispatcher_init.lua "
        local process_args = host .. " " .. port
        server_process = io.popen(process_cmd .. process_args)
        socket.sleep(1)
        logger:log("Dispatcher started")
    end)

    teardown(function()
        logger:log("Tearing down test environment")
        local client = create_client()
        local request = { action = "shutdown" }
        local json_request = utils.encode_json_singleline(request)
        client:send(json_request)
        client:close()

        if server_process then
            server_process:close()
        end
        socket.sleep(1)
        logger:log("Server stopped")
    end)

    it("should accept client connections", function()
        logger:log("Testing client connection")
        local client = create_client()
        assert.is_truthy(client)
        client:close()
        logger:log("Client connection test completed")
    end)

    it("should echo messages back to the client", function()
        logger:log("Testing echo functionality")
        local client = create_client()
        local request = { action = "echo", message = "test0" }
        local response = send_and_receive(client, request)
        assert.are.equal(request.message, response.message)
        client:close()
        logger:log("Echo test completed")
    end)

    it("should handle multiple clients sequentially", function()
        logger:log("Testing multiple client handling")
        local clients = {}
        local messages = { "test1", "test2", "test3" }

        for i = 1, #messages do
            local client = create_client()
            table.insert(clients, client)
        end

        for i, client in ipairs(clients) do
            local request = { action = "echo", message = messages[i] }
            local response = send_and_receive(client, request)
            assert.are.equal(messages[i], response.message)
        end

        for _, client in ipairs(clients) do
            client:close()
        end
        logger:log("Multiple client test completed")
    end)

    it("should handle multiple clients concurrently", function()
        logger:log("Testing concurrent client handling")
        local client_count = 3
        local clients = {}
        local messages = { "concurrent1", "concurrent2", "concurrent3" }
        local responses = {}

        local function client_coroutine(index)
            local client = create_client()
            clients[index] = client
            coroutine.yield()

            local request = { action = "echo", message = messages[index] }
            local json_request = utils.encode_json_singleline(request)
            logger:log("Client sending request: " .. json_request)
            client:send(json_request)
            socket.sleep(1)
            coroutine.yield()

            local json_response = client:receive("*l")
            logger:log("Client received response: " .. json_response)
            responses[index] = json.decode(json_response)
            client:close()
        end

        -- Create coroutines for each client
        local threads = {}
        for i = 1, client_count do
            threads[i] = coroutine.create(function() client_coroutine(i) end)
        end

        -- Connect all clients
        for i = 1, client_count do
            assert(coroutine.resume(threads[i]))
        end

        -- Send requests from all clients
        for i = 1, client_count do
            assert(coroutine.resume(threads[i]))
        end

        -- Receive responses for all clients
        for i = 1, client_count do
            assert(coroutine.resume(threads[i]))
        end

        -- Verify responses
        for i = 1, client_count do
            assert.are.equal(messages[i], responses[i].message)
        end

        logger:log("Concurrent client test completed")
    end)

    it("should handle database connection requests", function()
        logger:log("Testing database connection requests")
        local client = create_client()

        local request = {
            action = "dbconnect",
            bufnr = "1",
            dsn = config.odbc.dsn
        }

        local json_request = utils.encode_json_singleline(request)
        logger:log("Client sending request: " .. json_request)
        client:send(json_request)
        socket.sleep(1)

        local json_response, err = client:receive("*l")
        assert.is_nil(err, "Error receiving response: " .. tostring(err))
        assert.is_not_nil(json_response)

        local response = json.decode(json_response)
        assert.are.equal("success", response.status)

        client:close()
        logger:log("Database connection test completed")
    end)
end)
