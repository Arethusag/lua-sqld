local package_name = "lua-sqld"
local package_version = "0.1"
local rockspec_revision = "1"
local github_account_name = "ArethusaG"
local github_repo_name = package_name

package = package_name
version = package_version .. "-" .. rockspec_revision

source = {
   url = "git+https://github.com/" .. github_account_name .. "/" .. github_repo_name .. ".git",
   tag = "master" --TODO: stable release branch: tag = "v" .. package_version
}

description = {
   summary = "Lua TCP Client-Server for Asynchronous SQL Dispatching",
   detailed = [[
       SQLD is an asynchronous TCP client-server application written in Lua.
       It allows clients to send SQL queries to a server, which executes them
       using an ODBC driver and returns the results.
   ]],
   homepage = "https://github.com/Arethusag/lua-sqld",
   license = "MIT <http://opensource.org/licenses/MIT>"
}

dependencies = {
    "lua >= 5.1",
    "luasocket",
    "luasql-odbc",
    "lua-cjson",
    "copas"
}

build = {
   type = "builtin",
   modules = {
      ["sqld.dispatcher"] = "lua/sqld/dispatcher.lua",
      ["sqld.driver"] = "lua/sqld/driver.lua",
      ["sqld.executor"] = "lua/sqld/executor.lua",
      ["sqld.logger"] = "lua/sqld/logger.lua",
      ["sqld.utils"] = "lua/sqld/utils.lua"
   },
   install = {
      bin = {
          sqld = 'lua/sqld.lua'  
      }
   }
}
