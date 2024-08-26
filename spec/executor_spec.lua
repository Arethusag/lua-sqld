local json = require("cjson")

describe("Driver Process", function()
    local request_pipe
    local response_pipe
    local driver_process

    local function write_to_pipe(pipe, data)
        local file = assert(io.open(pipe, "w"))
        file:write(json.encode(data) .. "\n")
        file:flush()
        file:close()
    end

    local function read_from_pipe(pipe)
        local file = assert(io.open(pipe, "r"))
        local data = file:read("*a")
        file:close()
        return json.decode(data)
    end

    setup(function()
        request_pipe = os.tmpname()
        response_pipe = os.tmpname()
        driver_process = assert(io.popen("lua driver_process.lua " .. request_pipe .. " " .. response_pipe))
        os.execute("sleep 1") -- Give the driver process time to start
    end)

    it("should create pipes at the specified locations", function()
        assert.is_true(os.execute("test -p " .. request_pipe))
        assert.is_true(os.execute("test -p " .. response_pipe))
    end)

    it("should process a simple query", function()
        local query = {
            action = "query",
            query_id = "test1",
            query_string = "SELECT * FROM client LIMIT 1"
        }
        write_to_pipe(request_pipe, query)

        local response = read_from_pipe(response_pipe)
        assert.are.equal("completed", response.status)
        assert.is_true(#response.result > 0)
    end)

    it("should handle an invalid query", function()
        local query = {
            action = "query",
            query_id = "test2",
            query_string = "SELECT * FROM non_existent_table"
        }
        write_to_pipe(request_pipe, query)

        local response = read_from_pipe(response_pipe)
        assert.are.equal("error", response.status)
        assert.is_not_nil(response.error)
    end)

    it("should process multiple queries sequentially", function()
        local queries = {
            { action = "query", query_id = "test3", query_string = "SELECT COUNT(*) FROM client" },
            { action = "query", query_id = "test4", query_string = "SELECT * FROM client LIMIT 5" }
        }

        for _, query in ipairs(queries) do
            write_to_pipe(request_pipe, query)
            local response = read_from_pipe(response_pipe)
            assert.are.equal("completed", response.status)
        end
    end)

    it("should terminate when receiving a disconnect action", function()
        write_to_pipe(request_pipe, { action = "disconnect" })
        os.execute("sleep 1") -- Give the driver process time to terminate

        local exit_code = driver_process:close()
        assert.is_true(exit_code)
    end)
end)
