--dispatcher_init.lua
package.path = package.path .. ";./?.lua"

--main entry point for the dispatcher process
local Dispatcher = require("dispatcher")

local host = arg[1]
local port = tonumber(arg[2])

local dispatcher = Dispatcher:new(host, port)
dispatcher:run()
