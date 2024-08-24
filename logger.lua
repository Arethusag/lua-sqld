local Logger = {}
Logger.__index = Logger

function Logger:new(log_file)
    local logger = {}
    setmetatable(logger, Logger)
    self.log_file = log_file or "default.log"
    return self
end

function Logger:log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_message = string.format("[%s] %s\n", timestamp, message)
    local file = assert(io.open(self.log_file, "a"))
    file:write(log_message)
    file:close()
end

return Logger
