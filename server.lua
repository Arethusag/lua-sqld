-- server.lua
local socket = require("socket")
local copas = require("copas")
local logger = require("logger")
local json = require("cjson")

local Server = {}
Server.__index = Server

function Server:new(host, port)
    local server = {}
    setmetatable(server, Server)
    server.host = host or "127.0.0.1"
    server.port = port or 12345
    server.logger = logger:new("server.log")
    return server
end

function Server:handle_client(sock)
    while true do
        local data, err = copas.receive(sock, "*l")
        if data then
            request = json.decode(data)
            self.logger:log("Received: " .. data)
            if request.action == "shutdown" then
                self.shutdown = true
                break
            elseif request.action == "echo" then
                copas.send(sock, request.message .. "\n")
            else
                copas.send(sock, "Unknown request: " .. data "\n")
            end
        else
            if err == "closed" then
                self.logger:log("Client disconnected")
                break
            else
                self.logger:log("Error receiving data:" .. tostring(err))
            end
        end
    end
end

function Server:run()
    self.server_socket = assert(socket.bind(self.host, self.port))
    copas.addserver(self.server_socket, function(sock)
        self:handle_client(sock)
    end)
    self.logger:log("Server started on " .. self.host .. ":" .. self.port)
    while not self.shutdown do
        copas.step()
    end
    if self.server_socket then
        self.server_socket:close()
    end
    self.logger:log("Server stopped")
end

return Server
