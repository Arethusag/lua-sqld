package.path = package.path .. ";./?.lua"

local socket = require("socket")
local Driver = require("driver")
local Logger = require("logger")
local json = require("cjson")
local utils = require("utils")

local port = arg[1] or 8080
local logger = Logger:new("dispatcher.log", "executor.lua")

logger:log("SQL Executor Process started on port: " .. port)

local function process_query(query_id, query_string)
    logger:log("Processing query: " .. query_id .. ", " .. query_string)
    if not driver then
        logger:log("Error: No active database connection")
        return {
            status = "error",
            error = "No active database connection"
        }
    end

    local success, result = pcall(function()
        driver:execute_query(query_id, query_string)
        return driver:get_query_result(query_id)
    end)

    logger:log("Query execution result: " .. json.encode(result))

    if success and result.status == "completed" then
        logger:log("Query result obtained")
        return {
            status = "completed",
            result = result.result
        }
    else
        local error_message = result.error or "Unknown error"
        logger:log("Error processing query: " .. error_message)
        return {
            status = "error",
            error = error_message
        }
    end
end

local function create_driver()
    logger:log("Attempting to create new Driver instance")
    local success, result = pcall(function()
        return Driver:new()
    end)
    if success then
        logger:log("Driver instance created successfully")
        return result
    else
        logger:log("Failed to create Driver instance: " .. tostring(result()))
        return nil, tostring(result)
    end
end

local function connect_driver(driver_instance, dsn)
    logger:log("Attempting to connect to database")
    local success, result = pcall(function()
        driver_instance:connect(dsn)
        return true
    end)
    if success then
        logger:log("Connected to " .. dsn)
        return true
    else
        logger:log("Failed to connect: " .. tostring(result))
        return false, tostring(result)
    end
end

local function handle_connect_request(dsn)
    logger:log("Handling connect request for DSN: " .. dsn)
    local new_driver, create_error = create_driver()
    if not new_driver then
        logger:log("Failed to create driver: " .. tostring(create_error))
        return {
            status = "error",
            error = "Failed to create driver: " .. tostring(create_error)
        }
    end

    local connected, connect_error = connect_driver(new_driver, dsn)
    if connected then
        driver = new_driver
        logger:log("Connection successful")
        return { status = "success" }
    else
        logger:log("Connection failed: " .. connect_error)
        return {
            status = "error",
            error = "Failed to connect: " .. connect_error
        }
    end
end


local function main()
    logger:log("Starting main executor loop.")
    local server = assert(socket.bind("*", port))
    server:settimeout(5)
    logger:log("Waiting for dispatcher connection...")

    local client, err = server:accept()
    if not client then
        logger:log("Failed to accept connection: " .. tostring(err))
        return
    end
    logger:log("Dispatcher connected. Listening on port: " .. port)

    -- Initialization is complete, send the "ready" signal
    local ready_signal = json.encode({ action = "ready" })
    logger:log("Sending ready signal: " .. ready_signal)
    local bytes_sent, send_err = client:send(ready_signal .. "\n")
    if not bytes_sent then
        logger:log("Failed to send ready signal: " .. tostring(send_err))
    end

    client:settimeout(0)

    logger:log("Waiting for request from client..")

    local should_continue = true
    local driver = nil

    while should_continue do
        local json_request = client:receive("*l")
        if json_request then
            local success, request = pcall(json.decode, json_request)
            if success then
                logger:log("Request received: " .. json_request)

                local response
                if request.action == "dbconnect" then
                    response = handle_connect_request(request.dsn)
                elseif request.action == "query" then
                    response = process_query(request.query_id,
                        request.query_string)
                elseif request.action == "disconnect" then
                    logger:log("Disconnect request received")
                    should_continue = false
                    response = { status = "success", message = "Disconnected" }
                else
                    logger:log("Unknown request received: " ..
                        json.encode(request))
                    response = { status = "error", error = "Unknown action" }
                end
                logger:log("Sending response: " .. json.encode(response))
                client:send(json.encode(response) .. "\n")
            else
                logger:log("Error decoding JSON request: " .. json_request)
                response = { status = "error", error = "invlalid JSON" }
                logger:log("Sending response: " .. json.encode(response))
                client:send(json.encode(response))
            end
        else
            socket.sleep(0.1)
        end
    end

    if driver then
        logger:log("Disconnecting driver")
        driver:disconnect()
    end
    client:close()
    server:close()
    logger:log("Driver process terminated.")
end

main()
