-- TODO: Scrap these hacks and write a proper test suite.

pcall(require, 'luarocks.require')

local hiredis = require 'hiredis'

assert(hiredis.connect("xxx", 1) == nil)
local conn = assert(hiredis.connect("localhost", 6379))

assert(conn:command("SET", "MYKEY", "MYVALUE"))
assert(assert(conn:command("GET", "MYKEY")) == "MYVALUE")

local NIL = assert(conn:command("GET", "BADKEY"))
assert(NIL == hiredis.NIL)

assert(conn:command("SET") == nil) -- Not enough args

do
  local a = { }
  for i = 1, 512 do
    a[#a + 1] = "SET"
  end
  -- Too many arguments
  assert(pcall(conn.command, conn, unpack(a)) == false)
end

assert(assert(conn:command("MULTI")) == "OK")
assert(assert(conn:command("SET", "MYKEY1", "MYVALUE1")) == "QUEUED")
assert(assert(conn:command("GET", "MYKEY1")) == "QUEUED")
local t = assert(conn:command("EXEC"))
assert(t[1] == "OK")
assert(t[2] == "MYVALUE1")

assert(conn:command("MULTI"))
assert(assert(conn:command("GET", "MYKEY1")) == "QUEUED")
assert(conn:command("SET") == nil) -- Not enough args
assert(assert(conn:command("GET", "MYKEY1")) == "QUEUED")
local t = assert(conn:command("EXEC"))

for i = 1, #t do
  assert(t[i] == "MYVALUE1")
end

assert(conn:command("MULTI"))

assert(assert(conn:command("SET", "MYKEY2", 1)) == "QUEUED")

-- Wrong value type
assert(assert(conn:command("SADD", "MYKEY1", "MYVAL")) == "QUEUED")

assert(assert(conn:command("INCR", "MYKEY2")) == "QUEUED")
local t = assert(conn:command("EXEC"))
local r =
{
  "OK",
  "Operation against a key holding the wrong kind of value",
  2
}
assert(#t == #r)
for i = 1, #r do
  assert(t[i] == r[i])
end

conn:close()
conn:close()

error("TODO: Write better tests")

print("OK")
