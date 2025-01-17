-- spec/utils_spec.lua
-- require('mobdebug').start()
package.path = package.path .. ";./?.lua"

local utils = require("sqld.utils")

describe("Utils", function()

    it("should be able to generate a port number", function()
        local port = utils.get_free_os_port("localhost")

        assert.is_not_nil(port)
        assert.is_not_nil(string.match(port, "%d*"))
    end)

    it("should parse an ini config file", function()
        local config = utils.parse_inifile("test.ini")
        assert.is_not_nil(config)
        
        local DSN = { }
        for key, _ in pairs(config) do
            table.insert(DSN, key)
        end

        assert.are.equals(1, #DSN)
        assert.are.equals("MSSQLTest", DSN[1])

        local attr = { }
        for key, val in pairs(config[DSN[1]]) do
            table.insert(attr, { key, val })
        end

        assert.are.equal(5, #attr)
    end)

    it("should get the correct host operating system", function()
       local os = utils.get_os()
       local path_seperator = package.config:sub(1,1)
       
       if path_seperator == '\\' then
           assert.are.equals(os, "MS-Windows")
       else
           assert.are.equals(os, "Unix")
       end
   end)

   it("should query odbc registry keys on windows", function()
       if utils.get_os() == "MS-Windows" then
           local test_data_source
           local odbc_sources = utils.query_registry()
           assert.is_not_nil(odbc_sources)

           for key, _ in pairs(odbc_sources) do
               test_data_source = key
               assert.is_not_nil(test_data_source)
               break
           end
            
           assert.is_not_nil(odbc_sources[test_data_source].Driver)

       end
   end)

   it("should be able to retrieve odbc data sources", function()
       local test_data_source
       local odbc_sources = utils.get_odbc_data_sources()
       assert.is_not_nil(odbc_sources)

       for key, _ in pairs(odbc_sources) do
           test_data_source = key
           assert.is_not_nil(test_data_source)
           break
       end
        
       assert.is_not_nil(odbc_sources[test_data_source].Driver)
   end)
end)
