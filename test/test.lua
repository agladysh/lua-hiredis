-- TODO: Scrap these hacks and write a proper test suite.

pcall(require, 'luarocks.require')

local hiredis = require 'hiredis'

-- TODO: Remove quick hacks below

print(hiredis.connect("xxx", 1))
local conn = assert(hiredis.connect("localhost", 6379))
conn:close()

error("TODO: Implement")
