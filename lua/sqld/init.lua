--sqld/init.lua
package.path = package.path .. ";./lua/?.lua"

local Dispatcher = require("sqld.dispatcher")

local host = arg[1] or "localhost"
local port = tonumber(arg[2]) or 8181

local dispatcher = Dispatcher:new(host, port)
dispatcher:run()
