-- server.lua
local socket = require("socket")

local Server = {}
Server.__index = Server

function Server:new(host, port)
    local server = {}
    setmetatable(server, Server)
    server.host = host or "127.0.0.1"
    server.port = port or 12345
    server.clients = {}
    server.running = false
    return server
end

function Server:start()
    self.server_socket = assert(socket.bind(self.host, self.port))
    self.server_socket:settimeout(0)
    self.running = true
    print("Server started on " .. self.host .. ":" .. self.port)

    self.server_thread = coroutine.create(function()
        self:run()
    end)
    coroutine.resume(self.server_thread)
end

function Server:run()
    while self.running do
        self:accept_client()
        self:handle_clients()
        coroutine.yield()
    end
end

function Server:accept_client()
    local client = self.server_socket:accept()
    if client then
        client:settimeout(0)
        table.insert(self.clients, client)
        print("Client connected")
    end
end

function Server:handle_clients()
    for i = #self.clients, 1, -1 do
        local client = self.clients[i]
        client:settimeout(0)
        local line, err = client:receive("*l")
        if line then
            print("Received: " .. line)
            client:send("Echo: " .. line .. "\n")
        elseif err == "closed" then
            table.remove(self.clients, i)
            print("Client disconnected")
        end
    end
end

function Server:stop()
    self.running = false
    if self.server_socket then
        self.server_socket:close()
    end
    for _, client in ipairs(self.clients) do
        client:close()
    end
    self.clients = {}
    print("Server stopped")
end

function Server:update()
    if self.server_thread and coroutine.status(self.server_thread) ~= "dead" then
        coroutine.resume(self.server_thread)
    end
end

return Server
