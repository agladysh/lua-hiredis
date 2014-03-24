lua-hiredis — Bindings for hiredis Redis-client library
=======================================================

See the copyright information in the file named `COPYRIGHT`.

Status of the project
---------------------

The lua-hiredis module is pretty stable. It is heavily used in production
under high load by the author and team. There are still some things to do
(see TODO file) in the feature completeness field, this is why the module
is not 1.0 yet. But all the features necessary for regular usage are here.

API
---

* `hiredis.connect(host / socket : string, port : number / nil) : conn / nil, err, error_code`

  * `hiredis.connect("localhost", 6379)` connects to Redis at `localhost:6379`
    via TCP/IP socket.
  * `hiredis.connect("/var/run/redis/redis.sock")` connects to Redis at
    `/var/run/redis/redis.sock` via Unix domain socket.

* `hiredis.unwrap_reply(reply) : reply / name, hiredis.REPLY_STATUS / nil, err`

  * If `reply` is a `hiredis.REPLY_ERROR` object, returns `nil, reply.name`.
  * If `reply` is a `hiredis.REPLY_STATUS` object,
    returns `reply.name, hiredis.REPLY_STATUS`
    (It is guaranteed that `reply.name` is not `nil` or `false`.)
  * Returns `reply` itself otherwise
    (note that `hiredis.REPLY_NIL` object is not unwrapped).

### Connection

* `conn:command(... : string) : reply / nil, err, error_code`

* `conn:append_command(... : string) : (nothing)`

* `conn:get_reply() : reply / nil, err, error_code`

* `conn:close() : (nothing)`

### Error-code

Hiredis error codes (see docs), also available as `hiredis.ERR_<something>`:

* `REDIS_ERR_IO` is `hiredis.ERR_IO`,
* `REDIS_ERR_EOF` is `hiredis.ERR_EOF`,
* `REDIS_ERR_PROTOCOL` is `hiredis.ERR_PROTOCOL`,
* `REDIS_ERR_OTHER` is `hiredis.ERR_OTHER`.

### Reply

* `REDIS_REPLY_STATUS` is a const-object (see below)
  with type `hiredis.REPLY_STATUS`.
  Common status objects are available in hiredis module table:

  * `hiredis.status.OK`
  * `hiredis.status.QUEUED`
  * `hiredis.status.PONG`

  It is guaranteed that these object instances are always used
  for their corresponding statuses (so you can make a simple equality check).
  The same is true for any other object in `hiredis.status` table.

  Examples:

        assert(conn:command("PING") == hiredis.status.PONG)
        assert(conn:command("SET", "NAME", "lua-hiredis") == hiredis.status.OK)
        assert(conn:command("TYPE", "NAME") == hiredis.status.string)

* `REDIS_REPLY_ERROR` is a const-object with type `hiredis.REPLY_ERROR`.
  Note that Redis server errors are returned as `REDIS_REPLY_ERROR` values,
  not as `nil, err, error_code` triplet. See tests for example.

* `REDIS_REPLY_INTEGER` is a Lua number.

* `REDIS_REPLY_NIL` is a const-object with type `hiredis.REPLY_NIL`.

* `REDIS_REPLY_STRING` is a binary-safe Lua string.

* `REDIS_REPLY_ARRAY` is a linear Lua table (nesting is supported).

### Const-object

Const-object is a table with fields `name` and `type`.

There are three types of const-objects:

  * `hiredis.REPLY_NIL` (only a single instance is ever used: `hiredis.NIL`)
  * `hiredis.REPLY_ERROR`
  * `hiredis.REPLY_STATUS`

Use `hiredis.unwrap_reply()` to convert const-object to regular Lua value.

Note: Unwrapping is not done automatically to make array reply handling
more straightforward.

Deprecated features
-------------------

For backwards compatibility following status const-objects are aliased
in the `hiredis` module table:

  * `hiredis.OK = hiredis.status.OK`
  * `hiredis.QUEUED = hiredis.status.QUEUED`
  * `hiredis.PONG = hiredis.status.PONG`

These aliases will eventually be removed in one of future releases,
so, please, update your code to use `hiredis.status.*` instead.

More information
----------------

Read `test/test.lua` for examples. Read hiredis README for API motivation.
