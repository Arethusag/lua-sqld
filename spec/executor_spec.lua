local utils = require("utils")

describe("Driver Process", function()
    local request_pipe
    local response_pipe
    local executor

    setup(function()
        request_pipe = os.tmpname()
        response_pipe = os.tmpname()
        executor = assert(io.popen("lua executor.lua " .. request_pipe .. " " .. response_pipe))
        os.execute("sleep 1")
    end)

    it("should create pipes at the specified locations", function()
        assert.is_true(os.execute("test -p " .. request_pipe))
        assert.is_true(os.execute("test -p " .. response_pipe))
    end)

    it("should connect to a valid database", function()
        local connection_request = {
            action = "connect",
            dsn = "PostgreSQL-TestDB"
        }
        utils.write_to_pipe(request_pipe, connection_request)

        local response = utils.read_from_pipe(response_pipe)
        assert.are.equal("success", response.status)
    end)

    it("should process a simple query", function()
        local query = {
            action = "query",
            query_id = "test1",
            query_string = "SELECT * FROM client LIMIT 1"
        }
        utils.write_to_pipe(request_pipe, query)

        local response = utils.read_from_pipe(response_pipe)
        assert.are.equal("completed", response.status)
        assert.is_true(#response.result > 0)
    end)

    it("should handle an invalid query", function()
        local query = {
            action = "query",
            query_id = "test2",
            query_string = "SELECT * FROM non_existent_table"
        }
        utils.write_to_pipe(request_pipe, query)

        local response = utils.read_from_pipe(response_pipe)
        assert.are.equal("error", response.status)
        assert.is_not_nil(response.error)
    end)

    it("should process multiple queries sequentially", function()
        local queries = {
            { action = "query", query_id = "test3", query_string = "SELECT COUNT(*) FROM client" },
            { action = "query", query_id = "test4", query_string = "SELECT * FROM client LIMIT 5" }
        }

        for _, query in ipairs(queries) do
            utils.write_to_pipe(request_pipe, query)
            local response = utils.read_from_pipe(response_pipe)
            assert.are.equal("completed", response.status)
        end
    end)

    it("should terminate when receiving a disconnect action", function()
        utils.write_to_pipe(request_pipe, { action = "disconnect" })
        os.execute("sleep 1")

        local exit_code = executor:close()
        assert.is_true(exit_code)
    end)
end)
