local socket = require("socket")
local copas = require("copas")
local Logger = require("logger")
local json = require("cjson")
local utils = require("utils")

local Dispatcher = {}
Dispatcher.__index = Dispatcher

function Dispatcher:new(host, port)
    local dispatcher = {}
    setmetatable(dispatcher, Dispatcher)
    dispatcher.host = host or "127.0.0.1"
    dispatcher.port = port or 12345
    dispatcher.logger = Logger:new("dispatcher.log", "dispatcher.lua")
    dispatcher.shutdown = false
    dispatcher.clients = {}
    return dispatcher
end

function Dispatcher:spawn_executor(bufnr, dsn)

    -- Let the OS pick a free port
    local temp_socket = socket.tcp()
    temp_socket:bind(self.host, 0)
    local _, executor_port = temp_socket:getsockname()
    temp_socket:close()

    local cmd = string.format("luajit executor.lua %d", executor_port)

    self.logger:log("Spawning executor: " .. cmd)
    local executor_process = io.popen(cmd)

    local executor_socket = socket.tcp()
    executor_socket:settimeout(5)
    local ok, err = executor_socket:connect(self.host, executor_port)
    if not ok then
        self.logger:log(string.format("Failed to connect to executor: %s", err))
        executor_process:close()
        return nil
    end

    executor_socket:settimeout(0)
    self.logger:log("Connected to executor on port " .. executor_port)

    local executor_request_queue = {}
    local executor_response_queue = {}

    copas.addthread(function()
        self:handle_executor(executor_socket, executor_request_queue,
            executor_response_queue)
    end)

    local executor = {
        process = executor_process,
        socket = executor_socket,
        port = executor_port,
        bufnr = bufnr,
        dsn = dsn,
        request_queue = executor_request_queue,
        response_queue = executor_response_queue
    }
    table.insert(self.clients, executor)

    self.logger:log("Executor spawned for bufnr " .. bufnr)
    return executor
end

function Dispatcher:handle_executor(sock, request_queue, response_queue)
    self.logger:log("Handle executor started")
    while true do
        -- Send any pending requests to the executor
        while #request_queue > 0 do
            local request = table.remove(request_queue, 1)
            self.logger:log("Sending next request in queue: " .. request)
            copas.send(sock, request)
        end

        -- Receive responses from the executor
        local response, err = copas.receive(sock, "*l")
        if response then
            self.logger:log("Received from executor: " .. response)
            table.insert(response_queue, response)
        elseif err == "closed" then
            self.logger:log("Executor disconnected")
            break
        else
            copas.sleep(0.1)
        end
    end
end

function Dispatcher:handle_client_request(request, sock)
    if request.action == "echo" then
        self.logger:log("Echo request received")
        copas.send(sock, utils.encode_json_singleline({
            message = request.message
        }))
    elseif request.action == "dbconnect" then
        self.logger:log("DB connect request received: " .. json.encode(request))
        local executor = self:spawn_executor(request.bufnr, request.dsn)
        if executor then
            self.logger:log("Executor spawned successfully")
            self.logger:log("Connecting to DSN: " .. request.dsn)
            local connect_request = utils.encode_json_singleline({
                action = "connect",
                dsn = request.dsn
            })
            self.logger:log("Queueing request to executor: " .. connect_request)
            table.insert(executor.request_queue, connect_request)

            local response
            while not response do
                if #executor.response_queue > 0 then
                    response = table.remove(executor.response_queue, 1)
                else
                    copas.sleep(0.1)
                end
            end

            self.logger:log("Received executor response: " .. response)
            copas.send(sock, response .. "\n")
        else
            self.logger:log("Failed to spawn executor")
            copas.send(sock, utils.encode_json_singleline({
                status = "error",
                error = "Failed to spawn executor"
            }))
        end
    elseif request.action == "shutdown" then
        self.logger:log("Shutdown request received")
        self.shutdown = true
    end
end

function Dispatcher:handle_client(sock)
    self.logger:log("New client connected")
    while true do
        local data, err = copas.receive(sock, "*l")
        if data then
            local success, request = pcall(json.decode, data)
            if success then
                self.logger:log("Received data from client: " .. data)
                self:handle_client_request(request, sock)
            else
                self.logger:log("Error decoding JSON: " .. tostring(request))
            end
        else
            if err == "closed" then
                self.logger:log("Client disconnected")
                break
            elseif err ~= "timeout" then
                self.logger:log("Error receiving data:" .. tostring(err))
            end
            copas.sleep(0.1)
        end
    end
    sock:close()
end

function Dispatcher:run()
    self.dispatcher_socket = assert(socket.bind(self.host, self.port))
    self.dispatcher_socket:settimeout(0)
    copas.addserver(self.dispatcher_socket, function(sock)
        self:handle_client(sock)
    end)
    self.logger:log("Dispatcher started on " .. self.host .. ":" .. self.port)
    while not self.shutdown do
        copas.step(0.1)
    end
    self:cleanup()
    self.logger:log("Dispatcher stopped")
end

function Dispatcher:cleanup()
    if self.dispatcher_socket then
        self.dispatcher_socket:close()
    end
    for _, executor in pairs(self.clients) do
        if executor.socket then
            self.logger:log("Sending disconnect request to executor, bufnr: " ..
                executor.bufnr)
            executor.socket:send(json.encode({ action = "disconnect" }) .. "\n")
        end
        if executor.process then
            executor.process:close()
        end
    end
end

return Dispatcher
