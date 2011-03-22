-- TODO: Scrap these hacks and write a proper test suite.

pcall(require, 'luarocks.require')

local hiredis = require 'hiredis'

print(hiredis.connect("xxx", 1))
local conn = assert(hiredis.connect("localhost", 6379))

assert(conn:command("SET", "MYKEY", "MYVALUE"))
assert(assert(conn:command("GET", "MYKEY")) == "MYVALUE")

local NIL = assert(conn:command("GET", "BADKEY"))
assert(NIL == hiredis.NIL)

print(conn:command("SET")) -- Not enough args

print(assert(conn:command("MULTI")))
print(assert(conn:command("SET", "MYKEY1", "MYVALUE1")))
assert(assert(conn:command("GET", "MYKEY1")) == "QUEUED")
local t = assert(conn:command("EXEC"))
assert(t[1] == "OK")
assert(t[2] == "MYVALUE1")

print(assert(conn:command("MULTI")))
assert(assert(conn:command("GET", "MYKEY1")) == "QUEUED")
print(conn:command("SET")) -- Not enough args
assert(assert(conn:command("GET", "MYKEY1")) == "QUEUED")
local t = assert(conn:command("EXEC"))

for i = 1, #t do
  print(type(t[i]))
end
print("EXEC:", unpack(t))

print("---")

print(assert(conn:command("MULTI")))
-- Wrong type
assert(assert(conn:command("SADD", "MYKEY1", "MYVAL")) == "QUEUED")
assert(assert(conn:command("GET", "MYKEY1")) == "QUEUED")
local t = assert(conn:command("EXEC"))
for i = 1, #t do
  print(type(t[i]))
end
print("EXEC:", unpack(t))

conn:close()
conn:close()

error("TODO: Write better tests")
