local Logger = {}
Logger.__index = Logger

function Logger:new(log_file, source)
    local logger = setmetatable({}, self)
    logger.log_file = log_file or "default.log"
    logger.source = source or "logger.lua"
    return logger
end

function Logger:log(message)
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_message = string.format("[%s] [%s] %s\n", timestamp, self.source,
        message)
    local file = assert(io.open(self.log_file, "a"))
    file:write(log_message)
    file:flush()
    file:close()
end

return Logger
