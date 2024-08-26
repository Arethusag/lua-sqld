-- spec/server_spec.lua
package.path = package.path .. ";../?.lua"

local socket = require("socket")
local json = require("cjson")

describe("TCP Server", function()
    local host = "127.0.0.1"
    local port = 12345

    local function create_client()
        local client = assert(socket.tcp())
        assert(client:connect(host, port))
        return client
    end

    local function encode_request(data)
        local json_string = json.encode(data)
        return json_string:gsub("\n", "") .. "\n"
    end

    setup(function()
        server_process = io.popen("lua server_init.lua " .. host .. " " .. port)
        socket.sleep(0.5)
    end)

    teardown(function()
        local client = create_client()
        local shutdown_request = encode_request({ action = "shutdown" })
        client:send(shutdown_request)
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
        local request_table = { action = "echo", message = "test0" }
        local request_string = encode_request(request_table)
        assert(client:send(request_string))
        local response, err = client:receive("*l")
        assert.is_nil(err)
        assert.are.equal(request_table.message, response)
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
            local request_table = { action = "echo", message = messages[i] }
            local request_string = encode_request(request_table)
            assert(client:send(request_string))
        end

        for i, client in ipairs(clients) do
            local response, err = client:receive("*l")
            assert.is_nil(err)
            assert.are.equal(messages[i], response)
            client:close()
        end
    end)
end)
