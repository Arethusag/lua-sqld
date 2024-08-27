-- spec/server_spec.lua
package.path = package.path .. ";../?.lua"

local socket = require("socket")
local json = require("cjson")
local utils = require("utils")

describe("TCP Server", function()
    local host = "127.0.0.1"
    local port = 12345

    local function create_client()
        local client = assert(socket.tcp())
        assert(client:connect(host, port))
        return client
    end

    setup(function()
        server_process = io.popen("lua server_init.lua " .. host .. " " .. port)
        socket.sleep(0.5)
    end)

    teardown(function()
        local client = create_client()
        local request = { action = "shutdown" }
        local json_request = utils.encode_json_singleline(request)
        client:send(json_request)
        client:close()

        if server_process then
            server_process:close()
        end
    end)

    it("should accept client connections", function()
        local client = create_client()
        assert.is_truthy(client)
        client:close()
    end)

    it("should echo messages back to the client", function()
        local client = create_client()
        local request = { action = "echo", message = "test0" }
        local json_request = utils.encode_json_singleline(request)
        assert(client:send(json_request))
        local json_response, err = client:receive("*l")
        local response = json.decode(json_response)
        assert.is_nil(err)
        assert.are.equal(request.message, response.message)
        client:close()
    end)

    it("should handle multiple clients simultaneously", function()
        local clients = {}
        local messages = { "test1", "test2", "test3" }

        for i = 1, #messages do
            local client = create_client()
            table.insert(clients, client)
        end

        for i, client in ipairs(clients) do
            local request = { action = "echo", message = messages[i] }
            local json_request = utils.encode_json_singleline(request)
            assert(client:send(json_request))
        end

        for i, client in ipairs(clients) do
            local json_response, err = client:receive("*l")
            local response = json.decode(json_response)
            assert.is_nil(err)
            assert.are.equal(messages[i], response.message)
            client:close()
        end
    end)

    -- it("should let clients establish database connections")
end)
