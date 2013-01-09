-- TODO: Scrap these hacks and write a proper test suite.

pcall(require, 'luarocks.require')

local hiredis = require 'hiredis'

local CACHED_ERR = nil

--------------------------------------------------------------------------------

local UDS_SOCKET = "/var/run/redis/redis.sock"
local HOST = "localhost"
local PORT = 6379

--------------------------------------------------------------------------------

assert(type(hiredis.NIL == "table"))
assert(hiredis.NIL.name == "NIL")
assert(hiredis.NIL.type == hiredis.REPLY_NIL)
assert(tostring(hiredis.NIL) == "NIL")
assert(type(assert(getmetatable(hiredis.NIL))) == "string")

--------------------------------------------------------------------------------

assert(type(hiredis.status.OK == "table"))
assert(hiredis.status.OK.name == "OK")
assert(hiredis.status.OK.type == hiredis.REPLY_STATUS)
assert(tostring(hiredis.status.OK) == "OK")
assert(getmetatable(hiredis.status.OK) == getmetatable(hiredis.NIL))

-- deprecated backwards compatibility
assert(hiredis.OK == hiredis.status.OK)

--------------------------------------------------------------------------------

assert(type(hiredis.status.QUEUED == "table"))
assert(hiredis.status.QUEUED.name == "QUEUED")
assert(hiredis.status.QUEUED.type == hiredis.REPLY_STATUS)
assert(tostring(hiredis.status.QUEUED) == "QUEUED")
assert(getmetatable(hiredis.status.QUEUED) == getmetatable(hiredis.NIL))

-- deprecated backwards compatibility
assert(hiredis.QUEUED == hiredis.status.QUEUED)

--------------------------------------------------------------------------------

assert(type(hiredis.status.PONG == "table"))
assert(hiredis.status.PONG.name == "PONG")
assert(hiredis.status.PONG.type == hiredis.REPLY_STATUS)
assert(tostring(hiredis.status.PONG) == "PONG")
assert(getmetatable(hiredis.status.PONG) == getmetatable(hiredis.NIL))

-- deprecated backwards compatibility
assert(hiredis.PONG == hiredis.status.PONG)

--------------------------------------------------------------------------------

assert(hiredis.connect("badaddress", 1) == nil)

--------------------------------------------------------------------------------

assert(hiredis.connect("/var/run/redis/inexistant.sock") == nil)

--------------------------------------------------------------------------------

local ok, posix = pcall(require, "posix")
if not ok then
  print("WARNING: luaposix not found, can't test Unix Domain Socket support")
  print("         consider installing it as follows:")
  print("")
  print("         sudo luarocks install luaposix")
  print("")
elseif not posix.stat(UDS_SOCKET) then
  print("WARNING: Redis Unix domain socket file not found.")
  print("         Can't test Unix Domain Socket support.")
  print("         consider running Redis as follows:")
  print("")
  print("         sudo redis-server --unixsocket ".. UDS_SOCKET .. " --port 0")
  print("")
else
  local net_unix = assert(io.open("/proc/net/unix", "r"))
  local sockets = assert(net_unix:read("*a"))
  net_unix:close()
  if not sockets:find(UDS_SOCKET, nil, true) then
    print("WARNING: Redis Unix domain socket file not open.")
    print("         Can't test Unix Domain Socket support.")
    print("         consider running Redis as follows:")
    print("")
    print("        sudo redis-server --unixsocket ".. UDS_SOCKET .. " --port 0")
    print("")
  else
    local conn = assert(hiredis.connect(UDS_SOCKET))
    assert(conn:command("quit"))
  end
end

--------------------------------------------------------------------------------

local conn = assert(hiredis.connect(HOST, PORT))

--------------------------------------------------------------------------------

assert(conn:command("PING") == hiredis.status.PONG)

--------------------------------------------------------------------------------

assert(conn:command("SET", "MYKEY", "MYVALUE"))
assert(assert(conn:command("GET", "MYKEY")) == "MYVALUE")

--------------------------------------------------------------------------------

local T = assert(conn:command("TYPE", "MYKEY"))
assert(type(T) == "table")
assert(T.type == hiredis.REPLY_STATUS)
assert(T.name == "string")

assert(hiredis.unwrap_reply(T) == "string")
assert(T == hiredis.status.string)

--------------------------------------------------------------------------------

local res, err = hiredis.unwrap_reply(nil, "err")
assert(res == nil)
assert(err == "err")

--------------------------------------------------------------------------------

local NIL = assert(conn:command("GET", "BADKEY"))
assert(NIL == hiredis.NIL)

--------------------------------------------------------------------------------

local T = assert(conn:command("TYPE", "BADKEY2"))
assert(type(T) == "table")
assert(T.type == hiredis.REPLY_STATUS)
assert(T.name == "none")

assert(hiredis.unwrap_reply(T) == "none")
assert(T == hiredis.status.none)

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

assert(assert(conn:command("MULTI")) == hiredis.status.OK)
assert(
    assert(conn:command("SET", "MYKEY1", "MYVALUE1")) == hiredis.status.QUEUED
  )
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.status.QUEUED)
local t = assert(conn:command("EXEC"))
assert(t[1] == hiredis.status.OK)
assert(t[2] == "MYVALUE1")

--------------------------------------------------------------------------------

-- Based on actual bug scenario.
assert(assert(conn:command("MULTI")) == hiredis.status.OK)
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.status.QUEUED)
assert(
    assert(conn:command("SET", "MYKEY1", "MYVALUE2")) == hiredis.status.QUEUED
  )
local t = assert(conn:command("EXEC"))
assert(t[1] == "MYVALUE1")
assert(t[2] == hiredis.status.OK)

--------------------------------------------------------------------------------

assert(conn:command("MULTI"))
assert(assert(conn:command("GET", "MYKEY1")) == hiredis.status.QUEUED)

local err = assert(conn:command("SET"))
assert(err.type == hiredis.REPLY_ERROR)
assert(err.name == "ERR wrong number of arguments for 'set' command")
assert(tostring(err) == "ERR wrong number of arguments for 'set' command")

assert(assert(conn:command("GET", "MYKEY1")) == hiredis.status.QUEUED)
local t = assert(conn:command("EXEC"))

for i = 1, #t do
  assert(t[i] == "MYVALUE2")
end

--------------------------------------------------------------------------------

assert(conn:command("MULTI"))

assert(assert(conn:command("SET", "MYKEY2", 1)) == hiredis.status.QUEUED)

-- Wrong value type
assert(assert(conn:command("SADD", "MYKEY1", "MYVAL")) == hiredis.status.QUEUED)

assert(assert(conn:command("INCR", "MYKEY2")) == hiredis.status.QUEUED)
local t = assert(conn:command("EXEC"))

assert(t[1] == hiredis.status.OK)
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

assert(assert(conn:get_reply()) == hiredis.status.OK) -- MULTI
assert(assert(conn:get_reply()) == hiredis.status.QUEUED) -- SET
assert(assert(conn:get_reply()) == hiredis.status.QUEUED) -- SADD
assert(assert(conn:get_reply()) == hiredis.status.QUEUED) -- INCR
local t = assert(conn:get_reply()) -- EXEC

assert(t[1] == hiredis.status.OK)
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
assert(
    (res[1] == "A" and res[2] == "B") or
    (res[1] == "B" and res[2] == "A")
  )

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
assert(
    (res2[1] == "A" and res2[2] == "B") or
    (res2[1] == "B" and res2[2] == "A")
  )

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
assert(
    (res2[1] == "A" and res2[2] == "B") or
    (res2[1] == "B" and res2[2] == "A")
  )

--------------------------------------------------------------------------------

do
  local info = assert(hiredis.unwrap_reply(conn:command("INFO")))
  local major, minor = info:find("redis_version:%s*(%d+)%.(%d+)")
  if not major or not minor then
    error("can't determine Redis version from INFO command")
  elseif tonumber(major) < 2 or tonumber(minor) < 6 then
    print("Redis version <2.6, skipping nested bulk test")
  else
    -- Based on a real bug scenario:
    -- https://github.com/agladysh/lua-hiredis/issues/2
    -- Note that hiredis C library has built in limitation
    -- on bulk reply nesting.
    do
      local r = assert(
          hiredis.unwrap_reply(
              conn:command(
                  "EVAL",
                  [[return { 1, { 2, { 3 }, 4 }, 5 }]],
                  0
                )
            )
        )
      assert(type(r) == "table")
      assert(r[1] == 1)
      assert(r[2][1] == 2)
      assert(r[2][2][1] == 3)
      assert(r[2][3] == 4)
      assert(r[3] == 5)
    end

    do
      local r = assert(
          hiredis.unwrap_reply(
              conn:command(
                  "EVAL",
                  [[return { 1, { 2, { 3, { 4 }, 5 }, 6 }, 7 }]],
                  0
                )
            )
        )
      assert(type(r) == "table")
      assert(r[1] == 1)
      assert(r[2][1] == 2)
      assert(r[2][2][1] == 3)
      assert(r[2][2][2][1] == 4)
      assert(r[2][2][3] == 5)
      assert(r[2][3] == 6)
      assert(r[3] == 7)
    end

    do
      local res, err = hiredis.unwrap_reply(
          conn:command(
              "EVAL",
              [[
                return
                  { 1, { 2, { 3, { 4, { 5, { 6, { 7, { 8, {
                  9
                  }, 8 }, 7 }, 6 }, 5 }, 4 }, 3 }, 2 }, 1 }
              ]],
              0
            )
        )
      assert(res == nil)
      assert(err == "No support for nested multi bulk replies with depth > 7")
    end
  end
end

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
  local r = pack(hiredis.unwrap_reply(hiredis.status.OK))
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
