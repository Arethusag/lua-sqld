SQLDispatch is an asynchronous SQL query dispatcher written in lua. It is designed to provide a non-blocking TCP network
interface for multiple clients connect to databases, execute arbitrary SQL statements, and retrieve results.

# Installation

Tested with luajit, should work also on 5.1, 5,2, 5.3 and 5.4 lua runtimes. 

The dispatch server expects $LUA to be an 
environment variable with the location of you lua executable.

```
git clone https://github.com/Arethusag/SQLDispatch
cd SQLDispatch
luarocks install SQLDispatch
```

# Features

ODBC Driver Support

# Todo
pagination, cancel mid-execution
