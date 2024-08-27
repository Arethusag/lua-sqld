package.path = package.path .. ";./?.lua"

local Driver = require("driver")
local Logger = require("logger")
local json = require("cjson")
local utils = require("utils")

local request_pipe = arg[1] or os.tmpname()
local response_pipe = arg[2] or os.tmpname()

local logger = Logger:new("executor.log")

local function create_pipe(pipe_name)
    os.remove(pipe_name)
    os.execute("mkfifo " .. pipe_name)
    logger:log("Pipe created at " .. pipe_name)
end

local function delete_pipes()
    os.remove(request_pipe)
    os.remove(response_pipe)
end

local function process_query(query_id, query_string)
    logger:log("Processing query: " .. query_id .. ", " .. query_string)
    driver:execute_query(query_id, query_string)
    local result = driver:get_query_result(query_id)
    utils.write_to_pipe(response_pipe, result)
end

local function main()
    create_pipe(request_pipe)
    create_pipe(response_pipe)
    logger:log("SQL Executor started. Waiting for connections...")
    local should_continue = true
    while should_continue do
        request = utils.read_from_pipe(request_pipe)
        if request then
            logger:log("Request received: " .. request.action)
            if request.action == "query" then
                process_query(request.query_id, request.query_string)
            elseif request.action == "disconnect" then
                should_continue = false
            elseif request.action == "connect" then
                driver = Driver:new()
                driver:connect(request.dsn)
                utils.write_to_pipe(response_pipe, { status = "success" })
            end
        end
    end
    driver:disconnect()
    delete_pipes()
    print("Driver process terminated.")
end

main()
