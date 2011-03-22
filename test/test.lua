-- TODO: Scrap these hacks and write a proper test suite.

pcall(require, 'luarocks.require')

local hiredis = require 'hiredis'

assert(type(hiredis.NIL == "table"))
assert(hiredis.NIL.name == "NIL")
assert(hiredis.NIL.type == "nil")
assert(tostring(hiredis.NIL) == "NIL")

assert(type(hiredis.OK == "table"))
assert(hiredis.OK.name == "OK")
assert(hiredis.OK.type == "status")
assert(tostring(hiredis.OK) == "OK")

assert(type(hiredis.QUEUED== "table"))
assert(hiredis.QUEUED.name == "QUEUED")
assert(hiredis.QUEUED.type == "status")
assert(tostring(hiredis.QUEUED) == "QUEUED")

assert(type(hiredis.PONG== "table"))
assert(hiredis.PONG.name == "PONG")
assert(hiredis.PONG.type == "status")
assert(tostring(hiredis.PONG) == "PONG")

assert(hiredis.connect("badaddress", 1) == nil)

local conn = assert(hiredis.connect("localhost", 6379))

assert(conn:command("PING") == hiredis.PONG)

assert(conn:command("SET", "MYKEY", "MYVALUE"))
assert(assert(conn:command("GET", "MYKEY")) == "MYVALUE")

local NIL = assert(conn:command("GET", "BADKEY"))
assert(NIL == hiredis.NIL)

local err = assert(conn:command("SET"))
assert(err.type == "error")
assert(err.name == "ERR wrong number of arguments for 'set' command")
assert(tostring(err) == "ERR wrong number of arguments for 'set' command")

do
  local a = { }
  for i = 1, 512 do
    a[#a + 1] = "SET"
  end
  -- Too many arguments
  assert(pcall(conn.command, conn, unpack(a)) == false)
end

assert(assert(conn:command("MULTI")) == hiredis.OK)
assert(assert(conn:command("SET", "MYKEY1", "MYVALUE1")) == hiredis.QUEUED)
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.QUEUED)
local t = assert(conn:command("EXEC"))
assert(t[1] == hiredis.OK)
assert(t[2] == "MYVALUE1")

assert(conn:command("MULTI"))
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.QUEUED)

local err = assert(conn:command("SET"))
assert(err.type == "error")
assert(err.name == "ERR wrong number of arguments for 'set' command")
assert(tostring(err) == "ERR wrong number of arguments for 'set' command")

assert(assert(conn:command("GET", "MYKEY1")) == hiredis.QUEUED)
local t = assert(conn:command("EXEC"))

for i = 1, #t do
  assert(t[i] == "MYVALUE1")
end

assert(conn:command("MULTI"))

assert(assert(conn:command("SET", "MYKEY2", 1)) == hiredis.QUEUED)

-- Wrong value type
assert(assert(conn:command("SADD", "MYKEY1", "MYVAL")) == hiredis.QUEUED)

assert(assert(conn:command("INCR", "MYKEY2")) == hiredis.QUEUED)
local t = assert(conn:command("EXEC"))

assert(t[1] == hiredis.OK)
assert(t[2].type == "error")
assert(
    t[2].name == "ERR Operation against a key holding the wrong kind of value"
  )
assert(t[3] == 2)

conn:close()
conn:close()

error("TODO: Write better tests")

print("OK")
