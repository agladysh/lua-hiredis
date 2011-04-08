-- TODO: Scrap these hacks and write a proper test suite.

pcall(require, 'luarocks.require')

local hiredis = require 'hiredis'

local CACHED_ERR = nil

--------------------------------------------------------------------------------

assert(type(hiredis.NIL == "table"))
assert(hiredis.NIL.name == "NIL")
assert(hiredis.NIL.type == hiredis.REPLY_NIL)
assert(tostring(hiredis.NIL) == "NIL")
assert(type(assert(getmetatable(hiredis.NIL))) == "string")

--------------------------------------------------------------------------------

assert(type(hiredis.OK == "table"))
assert(hiredis.OK.name == "OK")
assert(hiredis.OK.type == hiredis.REPLY_STATUS)
assert(tostring(hiredis.OK) == "OK")
assert(getmetatable(hiredis.OK) == getmetatable(hiredis.NIL))

--------------------------------------------------------------------------------

assert(type(hiredis.QUEUED== "table"))
assert(hiredis.QUEUED.name == "QUEUED")
assert(hiredis.QUEUED.type == hiredis.REPLY_STATUS)
assert(tostring(hiredis.QUEUED) == "QUEUED")
assert(getmetatable(hiredis.QUEUED) == getmetatable(hiredis.NIL))

--------------------------------------------------------------------------------

assert(type(hiredis.PONG== "table"))
assert(hiredis.PONG.name == "PONG")
assert(hiredis.PONG.type == hiredis.REPLY_STATUS)
assert(tostring(hiredis.PONG) == "PONG")
assert(getmetatable(hiredis.PONG) == getmetatable(hiredis.NIL))

--------------------------------------------------------------------------------

assert(hiredis.connect("badaddress", 1) == nil)

--------------------------------------------------------------------------------

local conn = assert(hiredis.connect("localhost", 6379))

--------------------------------------------------------------------------------

assert(conn:command("PING") == hiredis.PONG)

--------------------------------------------------------------------------------

assert(conn:command("SET", "MYKEY", "MYVALUE"))
assert(assert(conn:command("GET", "MYKEY")) == "MYVALUE")

--------------------------------------------------------------------------------

local NIL = assert(conn:command("GET", "BADKEY"))
assert(NIL == hiredis.NIL)

--------------------------------------------------------------------------------

local err = assert(conn:command("SET"))
assert(err.type == hiredis.REPLY_ERROR)
assert(err.name == "ERR wrong number of arguments for 'set' command")
assert(tostring(err) == "ERR wrong number of arguments for 'set' command")
assert(getmetatable(err) == getmetatable(hiredis.NIL))
CACHED_ERR = err

--------------------------------------------------------------------------------

do
  local a = { }
  for i = 1, 512 do
    a[#a + 1] = "SET"
  end
  -- Too many arguments
  assert(pcall(conn.command, conn, unpack(a)) == false)
end

--------------------------------------------------------------------------------

assert(assert(conn:command("MULTI")) == hiredis.OK)
assert(assert(conn:command("SET", "MYKEY1", "MYVALUE1")) == hiredis.QUEUED)
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.QUEUED)
local t = assert(conn:command("EXEC"))
assert(t[1] == hiredis.OK)
assert(t[2] == "MYVALUE1")

--------------------------------------------------------------------------------

-- Based on actual bug scenario.
assert(assert(conn:command("MULTI")) == hiredis.OK)
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.QUEUED)
assert(assert(conn:command("SET", "MYKEY1", "MYVALUE2")) == hiredis.QUEUED)
local t = assert(conn:command("EXEC"))
assert(t[1] == "MYVALUE1")
assert(t[2] == hiredis.OK)

--------------------------------------------------------------------------------

assert(conn:command("MULTI"))
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.QUEUED)

local err = assert(conn:command("SET"))
assert(err.type == hiredis.REPLY_ERROR)
assert(err.name == "ERR wrong number of arguments for 'set' command")
assert(tostring(err) == "ERR wrong number of arguments for 'set' command")

assert(assert(conn:command("GET", "MYKEY1")) == hiredis.QUEUED)
local t = assert(conn:command("EXEC"))

for i = 1, #t do
  assert(t[i] == "MYVALUE2")
end

--------------------------------------------------------------------------------

assert(conn:command("MULTI"))

assert(assert(conn:command("SET", "MYKEY2", 1)) == hiredis.QUEUED)

-- Wrong value type
assert(assert(conn:command("SADD", "MYKEY1", "MYVAL")) == hiredis.QUEUED)

assert(assert(conn:command("INCR", "MYKEY2")) == hiredis.QUEUED)
local t = assert(conn:command("EXEC"))

assert(t[1] == hiredis.OK)
assert(t[2].type == hiredis.REPLY_ERROR)
assert(
    t[2].name == "ERR Operation against a key holding the wrong kind of value"
  )
assert(t[3] == 2)

--------------------------------------------------------------------------------

conn:append_command("MULTI")
conn:append_command("SET", "MYKEY2", 1)
conn:append_command("SADD", "MYKEY1", "MYVAL")
conn:append_command("INCR", "MYKEY2")
conn:append_command("EXEC")

assert(assert(conn:get_reply()) == hiredis.OK) -- MULTI
assert(assert(conn:get_reply()) == hiredis.QUEUED) -- SET
assert(assert(conn:get_reply()) == hiredis.QUEUED) -- SADD
assert(assert(conn:get_reply()) == hiredis.QUEUED) -- INCR
local t = assert(conn:get_reply()) -- EXEC

assert(t[1] == hiredis.OK)
assert(t[2].type == hiredis.REPLY_ERROR)
assert(
    t[2].name == "ERR Operation against a key holding the wrong kind of value"
  )
assert(t[3] == 2)

--------------------------------------------------------------------------------

assert(hiredis.unwrap_reply(assert(conn:command("DEL", "MYSET1"))))
assert(hiredis.unwrap_reply(assert(conn:command("DEL", "MYSET2"))))
assert(hiredis.unwrap_reply(assert(conn:command("SADD", "MYSET1", "A"))))
assert(hiredis.unwrap_reply(assert(conn:command("SADD", "MYSET1", "B"))))
local res = assert(
    hiredis.unwrap_reply(assert(conn:command("SDIFF", "MYSET1", "MYSET2")))
  )

assert(type(res) == "table")
assert(#res == 2)
assert(res[1] == "A")
assert(res[2] == "B")

--------------------------------------------------------------------------------

assert(hiredis.unwrap_reply(assert(conn:command("MULTI"))))
assert(hiredis.unwrap_reply(assert(conn:command("DEL", "MYSET1"))))
assert(hiredis.unwrap_reply(assert(conn:command("DEL", "MYSET2"))))
assert(hiredis.unwrap_reply(assert(conn:command("SADD", "MYSET1", "A"))))
assert(hiredis.unwrap_reply(assert(conn:command("SADD", "MYSET1", "B"))))
assert(hiredis.unwrap_reply(assert(conn:command("SDIFF", "MYSET1", "MYSET2"))))
local res = assert(hiredis.unwrap_reply(assert(conn:command("EXEC"))))

assert(type(res) == "table")
assert(#res == 5)
local res2 = res[5]
assert(type(res2) == "table")
assert(res2[1] == "A")
assert(res2[2] == "B")

--------------------------------------------------------------------------------

conn:append_command("MULTI")
conn:append_command("DEL", "MYSET1")
conn:append_command("DEL", "MYSET2")
conn:append_command("SADD", "MYSET1", "A")
conn:append_command("SADD", "MYSET1", "B")
conn:append_command("SDIFF", "MYSET1", "MYSET2")
conn:append_command("EXEC")

assert(hiredis.unwrap_reply(assert(conn:get_reply()))) -- multi
assert(hiredis.unwrap_reply(assert(conn:get_reply()))) -- del
assert(hiredis.unwrap_reply(assert(conn:get_reply()))) -- del
assert(hiredis.unwrap_reply(assert(conn:get_reply()))) -- sadd
assert(hiredis.unwrap_reply(assert(conn:get_reply()))) -- sadd
assert(hiredis.unwrap_reply(assert(conn:get_reply()))) -- sdiff
local res = assert(hiredis.unwrap_reply(assert(conn:get_reply()))) -- exec

assert(type(res) == "table")
assert(#res == 5)
local res2 = res[5]
assert(type(res2) == "table")
assert(res2[1] == "A")
assert(res2[2] == "B")

--------------------------------------------------------------------------------

conn:close()
conn:close() -- double close check
conn = nil

--------------------------------------------------------------------------------

local pack = function(...) return { n = select("#", ...), ... } end

do
  local r = pack(hiredis.unwrap_reply(nil))
  assert(r.n == 1)
  assert(r[1] == nil)
end

do
  local r = pack(hiredis.unwrap_reply(true))
  assert(r.n == 1)
  assert(r[1] == true)
end

do
  local r = pack(hiredis.unwrap_reply(false))
  assert(r.n == 1)
  assert(r[1] == false)
end

do
  local r = pack(hiredis.unwrap_reply(math.pi))
  assert(r.n == 1)
  assert(r[1] == math.pi)
end

do
  local r = pack(hiredis.unwrap_reply("42"))
  assert(r.n == 1)
  assert(r[1] == "42")
end

do
  local t = { type = hiredis.REPLY_STATUS, name = "OK" }
  local r = pack(hiredis.unwrap_reply(t))
  assert(r.n == 1)
  assert(r[1] == t) -- no unwrap
end

do
  local r = pack(hiredis.unwrap_reply(hiredis.NIL))
  assert(r.n == 1)
  assert(r[1] == hiredis.NIL) -- no unwrap
end

do
  local r = pack(hiredis.unwrap_reply(hiredis.OK))
  assert(r.n == 2)
  assert(r[1] == "OK")
  assert(r[2] == hiredis.REPLY_STATUS)
end

do
  local r = pack(hiredis.unwrap_reply(assert(CACHED_ERR)))
  assert(r.n == 2)
  assert(r[1] == nil)
  assert(r[2] == "ERR wrong number of arguments for 'set' command")
  assert(r[2] == CACHED_ERR.name)
end

--------------------------------------------------------------------------------

-- TODO: Test PUB/SUB stuff.
-- TODO: Test that both open and closed connections
--       are collected properly and do not crash on GC.
-- TODO: Test command() after several append_command() without get_reply()

print("OK")
