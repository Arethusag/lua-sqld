package.path = package.path .. ";./?.lua"

local Driver = require("driver")
local Logger = require("logger")
local json = require("cjson")

local REQUEST_PIPE = arg[1] or os.tmpname()
local RESPONSE_PIPE = arg[2] or os.tmpname()

local driver = Driver:new()
local logger = Logger:new("executor.log")

local function create_pipe(pipe_name)
    os.remove(pipe_name)
    os.execute("mkfifo " .. pipe_name)
    logger:log("Pipe created at " .. pipe_name)
end

local function delete_pipes()
    os.remove(REQUEST_PIPE)
    os.remove(RESPONSE_PIPE)
end

local function send_response(response)
    local file = assert(io.open(RESPONSE_PIPE, "w"))
    file:write(json.encode(response) .. "\n")
    logger:log("Saved query reponse to " .. RESPONSE_PIPE)
    file:flush()
    file:close()
end

local function process_query(query_id, query_string)
    logger:log("Processing query: " .. query_id .. ", " .. query_string)
    driver:execute_query(query_id, query_string)
    local result = driver:get_query_result(query_id)
    send_response(result)
end

local function main()
    create_pipe(REQUEST_PIPE)
    create_pipe(RESPONSE_PIPE)
    driver:connect()
    logger:log("Driver process started. Waiting for queries...")
    local should_continue = true
    while should_continue do
        local request_file = assert(io.open(REQUEST_PIPE, "r"))
        local data = request_file:read("*a")
        request_file:close()
        if data then
            local request = json.decode(data)
            if request.action == "query" then
                process_query(request.query_id, request.query_string)
            elseif request.action == "disconnect" then
                should_continue = false
            end
        end
    end
    driver:disconnect()
    delete_pipes()
    print("Driver process terminated.")
end

main()
