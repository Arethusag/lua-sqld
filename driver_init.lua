package.path = package.path .. ";./?.lua"

local Driver = require("driver")
local Logger = require("logger")
local json = require("cjson")
local lfs = require("lfs")

local PID = tostring(require("posix.unistd").getpid())
local PIPE_DIR = "/tmp"
local REQUEST_PIPE = PIPE_DIR .. "/driver_request_pipe_" .. PID
local RESPONSE_PIPE = PIPE_DIR .. "/driver_response_pipe_" .. PID

local driver = Driver:new()
local logger = Logger:new("

local function create_pipe(pipe_name)
    if not lfs.attributes(pipe_name) then
        os.execute("mkfifo " .. pipe_name)
    end
end

local function delete_pipes()
    os.remove(REQUEST_PIPE)
    os.remove(RESPONSE_PIPE)
end

local function send_response(response)
    local file = assert(io.open(RESPONSE_PIPE, "w"))
    file:write(json.encode(response) .. "\n")
    file:flush()
    file:close()
end

local function process_query(query_id, query_string)
    driver:execute_query(query_id, query_string)
    local result = driver:get_query_result(query_id)
    send_response(result)
end

local function clear_pipe(pipe_name)
    local file = io.open(pipe_name, "r")
    file:read("*a")
    file:close()
end

local function main()
    create_pipe(REQUEST_PIPE)
    create_pipe(RESPONSE_PIPE)

    driver:connect()

    print("Driver process started with PID " .. PID .. ". Waiting for queries...")

    local should_continue = true
    while should_continue do
        local request_file = io.open(REQUEST_PIPE, "r")
        local line = request_file:read("*l")
        request_file:close()

        if line then
            local request = json.decode(line)

            if request.action == "query" then
                process_query(request.query_id, request.query_string)
            elseif request.action == "disconnect" then
                should_continue = false
            end

            -- Clear the pipe after processing the request
            clear_pipe(REQUEST_PIPE)
        end
    end

    driver:disconnect()
    delete_pipes()
    print("Driver process " .. PID .. " terminated.")
end

main()

