-- spec/server_spec.lua
package.path = package.path .. ";./?.lua"

local Server = require("server")
local socket = require("socket")

describe("TCP Server", function()
    local server
    local host = "127.0.0.1"
    local port = 12345

    setup(function()
        server = Server:new(host, port)
        server:start()
    end)

    teardown(function()
        server:stop()
    end)

    local function update_server(times)
        for i = 1, times do
            server:update()
            socket.sleep(0.01)
        end
    end

    local function create_client()
        local client = assert(socket.tcp())
        client:settimeout(2)
        assert(client:connect(host, port))
        update_server(10) -- Allow time for server to process the connection
        return client
    end

    it("should accept client connections", function()
        local client = create_client()
        update_server(10)
        assert.is_true(#server.clients == 1)
        client:close()
        update_server(10)
    end)

    it("should echo messages back to the client", function()
        local client = create_client()
        local message = "Hello, Server!"
        assert(client:send(message .. "\n"))
        update_server(10)
        local response, err = client:receive("*l")
        assert.is_nil(err)
        assert.are.equal("Echo: " .. message, response)
        client:close()
        update_server(10)
    end)

    it("should handle multiple clients simultaneously", function()
        local clients = {}
        local messages = { "First", "Second", "Third" }

        for i = 1, #messages do
            local client = create_client()
            table.insert(clients, client)
        end

        for i, client in ipairs(clients) do
            assert(client:send(messages[i] .. "\n"))
        end

        update_server(20)

        for i, client in ipairs(clients) do
            local response, err = client:receive("*l")
            assert.is_nil(err)
            assert.are.equal("Echo: " .. messages[i], response)
            client:close()
        end
    end)

    it("should properly disconnect clients", function()
        local client = create_client()
        client:close()
        update_server(10)
        assert.is_true(#server.clients == 0)
    end)
end)

