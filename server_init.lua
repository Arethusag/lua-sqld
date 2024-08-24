--server_init.lua
package.path = package.path .. ";./?.lua"

--main entry point for the server process
local Server = require("server")

local host = arg[1]
local port = tonumber(arg[2])

local server = Server:new(host, port)
server:run()
