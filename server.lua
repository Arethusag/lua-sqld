-- server.lua
local socket = require("socket")
local copas = require("copas")
local logger = require("logger")
local json = require("cjson")
local utils = require("utils")

local Server = {}
Server.__index = Server

function Server:new(host, port)
    local server = {}
    setmetatable(server, Server)
    server.host = host or "127.0.0.1"
    server.port = port or 12345
    server.logger = logger:new("server.log")
    server.clients = {}
    return server
end

function Server:spawn_executor(request_pipe, response_pipe)
    executor = assert(io.popen("lua executor.lua " ..
        request_pipe .. " " .. response_pipe))
    return executor
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
                response = { message = request.message }
                json_response = utils.encode_json_singleline(response)
                copas.send(sock, json_response)
            elseif request.action == "dbconnect" then
                request_pipe = os.tmpname()
                response_pipe = os.tmpname()
                executor = self:spawn_executor(request_pipe, response_pipe)
                self.clients[request.client_id] = {
                    dsn = request.dsn,
                    request_pipe = request_pipe,
                    response_pipe = response_pipe,
                    executor = executor
                }
                logger:log("Connecting client " .. request.client_id ..
                    " to DSN " .. request.dsn)
                connection_request = { action = "connect", dsn = request.dsn }
                utils.write_to_pipe(request_pipe, connection_request)
                response = utils.read_from_pipe(response_pipe, connection_reponse)
            elseif request.action == "dbdisconnect" then
                client = self.clients[request.clientid]
                if client then
                    utils.write_to_pipe(client.request_pipe,
                        { action = "disconnect" })
                    client.executor:close()
                end
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
