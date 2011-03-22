-- TODO: Scrap these hacks and write a proper test suite.

pcall(require, 'luarocks.require')

local hiredis = require 'hiredis'

print(hiredis.connect("xxx", 1))
local conn = assert(hiredis.connect("localhost", 6379))

assert(conn:command("SET", "MYKEY", "MYVALUE"))
assert(assert(conn:command("GET", "MYKEY")) == "MYVALUE")

local NIL = assert(conn:command("GET", "BADKEY"))
assert(NIL == hiredis.NIL)

conn:close()
conn:close()

error("TODO: Write better tests")
