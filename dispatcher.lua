--dispatcher.lua

local socket = require("socket")
local copas = require("copas")
local Logger = require("logger")
local json = require("cjson")
local utils = require("utils")
local config = utils.parse_inifile("config.ini")

local Dispatcher = {}
Dispatcher.__index = Dispatcher

function Dispatcher:new(host, port)
	local dispatcher = {}
	setmetatable(dispatcher, Dispatcher)
	dispatcher.host = host or "127.0.0.1"
	dispatcher.port = port or utils.get_free_os_port(host)
	dispatcher.logger = Logger:new("log", "dispatcher.lua")
	dispatcher.shutdown = false
	dispatcher.executors = {}
	return dispatcher
end

function Dispatcher:get_executor(bufnr)
	for _, executor in ipairs(self.executors) do
		if executor.bufnr == bufnr then
			return executor
		end
	end
	return nil
end

function Dispatcher:spawn_executor(bufnr, dsn)
	executor_port = utils.get_free_os_port(self.host)
	local cmd = string.format(config.lua.exec .. " executor.lua %d", executor_port)

	self.logger:log("Spawning executor: " .. cmd)
	local executor_process = io.popen(cmd)

	local executor_socket = assert(socket.tcp())
	executor_socket:settimeout(5)
	local ok, err = executor_socket:connect(self.host, executor_port)
	if not ok then
		self.logger:log(string.format("Failed to connect to executor: %s", err))
		executor_process:close()
		return nil
	end

	executor_socket:settimeout(0)
	self.logger:log("Connected to executor on port " .. executor_port)

	local ready_received = false
	while not ready_received do
		local ready_msg, err = copas.receive(executor_socket, "*l")
		if ready_msg then
			local success, ready_data = pcall(json.decode, ready_msg)
			if success and ready_data.action == "ready" then
				ready_received = true
			end
		elseif err ~= "timeout" then
			self.logger:log("Error receiving ready message from executor: " .. tostring(err))
			break
		end
		copas.sleep(0.1)
	end

	local executor = {
		process = executor_process,
		socket = executor_socket,
		port = executor_port,
		bufnr = bufnr,
		dsn = dsn,
	}
	table.insert(self.executors, executor)

	self:start_executor_response_handler(executor)

	self.logger:log("Executor spawned for bufnr " .. bufnr)

	return executor
end

function Dispatcher:start_executor_response_handler(executor)
	copas.addthread(function()
		self.logger:log("Started response handler thread for executor " .. executor.bufnr)
		while not self.shutdown do
			local response, err = copas.receive(executor.socket, "*l")
			if response then
				self.logger:log("Received response from executor " .. executor.bufnr .. ": " .. response)
				self.result_queue:push({
					result = response,
					client_socket = executor.client_socket,
				})
			elseif err == "closed" then
				self.logger:log("Executor " .. executor.bufnr .. " connection closed")
				break
			elseif err ~= "timeout" then
				self.logger:log("Error receiving from executor " .. executor.bufnr .. ": " .. tostring(err))
				break
			end
			copas.sleep(0.1)
		end
		self.logger:log("Executor response handler thread ended for " .. executor.bufnr)
	end)
end

function Dispatcher:handle_executor_request(request, client_socket, executor)
	self.logger:log("Handle executor started for bufnr: " .. executor.bufnr)
	executor.client_socket = client_socket
	self.logger:log("Sending request to executor, bufnr: " .. executor.bufnr .. ", request: " .. json.encode(request))
	local ok, msg = copas.send(executor.socket, json.encode(request) .. "\n")
	if not ok then
		self.logger:log("Failed to send request to executor, bufnr: " .. executor.bufnr .. ": " .. msg)
	end
end

function Dispatcher:handle_executor_result(result, client_socket)
	self.logger:log("Handling executor result: " .. result)
	local ok, msg = copas.send(client_socket, result .. "\n")
	if not ok then
		self.logger:log("Failed to send result to client")
	end
end

function Dispatcher:handle_client_request(request, client_socket)
	self.logger:log("Handling client request: " .. json.encode(request))
	if request.action == "echo" then
		self.logger:log("Echo request received")
		copas.send(client_socket, json.encode({ message = request.message }) .. "\n")
	elseif request.action == "connect" then
		self.logger:log("Database connect request received: " .. json.encode(request))
		local executor = self:spawn_executor(request.bufnr, request.dsn)
		if executor then
			self.logger:log("Executor spawned successfully pushing request to queue")
			request_data = { request = request, client_socket = client_socket, executor = executor }
			self.executor_queue:push(request_data)
		else
			self.logger:log("Failed to spawn executor")
			copas.send(client_socket, json.encode({
				status = "error",
				error = "Failed to spawn executor",
			}) .. "\n")
		end
	elseif request.action == "disconnect" then
		self.logger:log("Database disconnect request received: " .. json.encode(request))
		local executor = self:get_executor(request.bufnr)
		if executor then
			self.logger:log("Pushing disconnect request to executor " .. request.bufnr .. " queue")
			request_data = { request = request, client_socket = client_socket, executor = executor }
			self.executor_queue:push(request_data)
		else
			self.logger:log("Failed to retrieve executor for bufnr " .. request.bufnr)
			copas.send(client_socket, json.encode({
				status = "error",
				error = "Failed to retrieve executor",
			}) .. "\n")
		end
	elseif request.action == "query" then
		self.logger:log("Query request received: " .. json.encode(request))
		local executor = self:get_executor(request.bufnr)
		if executor then
			request_data = { request = request, client_socket = client_socket, executor = executor }
			self.executor_queue:push(request_data)
			self.logger:log("Pushing query request to the executor queue, bufnr " .. request.bufnr)
		else
			self.logger:log("Failed to retrieve executor for bufnr " .. request.bufnr)
			copas.send(client_socket, json.encode({
				status = "error",
				error = "Failed to retrieve executor",
			}) .. "\n")
		end
	elseif request.action == "shutdown" then
		self.logger:log("Shutdown request received")
		self.shutdown = true
	end
end

function Dispatcher:handle_client(client_socket)
	self.logger:log("New client connected")
	while true do
		local data, err = copas.receive(client_socket, "*l")
		if data then
			local success, request = pcall(json.decode, data)
			if success then
				self.logger:log("Received data from client: " .. data)
				request_data = { request = request, client_socket = client_socket }
				self.request_queue:push(request_data)
			else
				self.logger:log("Error decoding JSON: " .. tostring(request))
				break
			end
		else
			if err == "closed" then
				self.logger:log("Client disconnected")
				break
			elseif err ~= "timeout" then
				self.logger:log("Error receiving data:" .. tostring(err))
				break
			end
			copas.sleep(0.1)
		end
	end
end

function Dispatcher:setup_queue(name, worker_function)
	local queue = copas.queue.new({ name = name })
	queue:add_worker(function(data)
		self.logger:log(name .. " worker processing next task")
		local success, err = pcall(worker_function, data)
		if not success then
			self.logger:log("Error in " .. name .. " worker: " .. tostring(err))
		end
	end)
	return queue
end

function Dispatcher:run()
	self.dispatcher_socket = assert(socket.bind(self.host, self.port))
	self.dispatcher_socket:settimeout(0)

	copas.addserver(self.dispatcher_socket, function(client_socket)
		self:handle_client(client_socket)
	end)

	self.request_queue = setup_queue("request_queue", function(data)
		self:handle_client_request(data.request, data.client_socket)
	end)

	self.result_queue = setup_queue("result_queue", function(data)
		self:handle_executor_result(data.result, data.client_socket)
	end)

	self.executor_queue = setup_queue("executor_queue", function(data)
		self:handle_executor_request(data.request, data.client_socket, data.executor)
	end)

	self.logger:log("Dispatcher started on " .. self.host .. ":" .. self.port)
	while not self.shutdown do
		copas.step(0.1)
	end
	self:cleanup()
	self.logger:log("Dispatcher stopped")
end

function Dispatcher:cleanup()
	self.request_queue:stop()
	self.result_queue:stop()
	self.executor_queue:stop()

	if self.dispatcher_socket then
		self.dispatcher_socket:close()
	end

	for _, executor in pairs(self.executors) do
		if executor.socket then
			self.logger:log("Sending disconnect request to executor, bufnr: " .. executor.bufnr)
			executor.socket:send(json.encode({ action = "shutdown" }) .. "\n")
		end
		if executor.process then
			executor.process:close()
		end
	end
end

return Dispatcher
