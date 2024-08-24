-- spec/server_spec.lua
package.path = package.path .. ";../?.lua"

local socket = require("socket")

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
        client:send("shutdown\n")
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
        local message = "echo_test"
        assert(client:send(message .. "\n"))
        local response, err = client:receive("*l")
        assert.is_nil(err)
        assert.are.equal(message, response)
        client:close()
    end)

    it("should handle multiple clients simultaneously", function()
        local clients = {}
        local messages = { "echo_test1", "echo_test2", "echo_test3" }

        for i = 1, #messages do
            local client = create_client()
            table.insert(clients, client)
        end

        for i, client in ipairs(clients) do
            assert(client:send(messages[i] .. "\n"))
        end

        for i, client in ipairs(clients) do
            local response, err = client:receive("*l")
            assert.is_nil(err)
            assert.are.equal(messages[i], response)
            client:close()
        end
    end)
end)
