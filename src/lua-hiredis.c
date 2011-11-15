/*
* lua-hiredis.c: Bindings for hiredis Redis-client library
*                See copyright information in file COPYRIGHT.
*/

#if defined (__cplusplus)
extern "C" {
#endif

#include <lua.h>
#include <lauxlib.h>

#if defined (__cplusplus)
}
#endif

#include "hiredis.h"

#if 0
  #define SPAM(a) printf a
#else
  #define SPAM(a) (void)0
#endif

#define LUAHIREDIS_VERSION     "lua-hiredis 0.1.3"
#define LUAHIREDIS_COPYRIGHT   "Copyright (C) 2011, lua-hiredis authors"
#define LUAHIREDIS_DESCRIPTION "Bindings for hiredis Redis-client library"

#define LUAHIREDIS_CONN_MT "lua-hiredis.connection"
#define LUAHIREDIS_CONST_MT "lua-hiredis.const"

#define LUAHIREDIS_MAXARGS (256)

#define LUAHIREDIS_KEY_NIL "NIL"

typedef struct luahiredis_Enum
{
  const char * name;
  const int value;
} luahiredis_Enum;

static void reg_enum(lua_State * L, const luahiredis_Enum * e)
{
  for ( ; e->name; ++e)
  {
    lua_pushinteger(L, e->value);
    lua_setfield(L, -2, e->name);
  }
}

/* This is luaL_setfuncs() from Lua 5.2 alpha */
static void setfuncs (lua_State *L, const luaL_Reg *l, int nup) {
  luaL_checkstack(L, nup, "too many upvalues");
  for (; l && l->name; l++) {  /* fill the table with given functions */
    int i;
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -nup);
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_setfield(L, -(nup + 2), l->name);
  }
  lua_pop(L, nup);  /* remove upvalues */
}
/* End of luaL_setfuncs() from Lua 5.2 alpha */

static int lconst_tostring(lua_State * L)
{
  /*
  * Assuming we have correct argument type.
  * Should be reasonably safe, since this is a metamethod.
  */
  luaL_checktype(L, 1, LUA_TTABLE);
  lua_getfield(L, 1, "name"); /* TODO: Do we need fancier representation? */

  return 1;
}

/* const API */
static const struct luaL_reg CONST_MT[] =
{
  { "__tostring", lconst_tostring },

  { NULL, NULL }
};

static int push_new_const(
    lua_State * L,
    const char * name,
    size_t name_len,
    int type
  )
{
  /* We trust that user would not change these values */
  lua_createtable(L, 0, 2);
  lua_pushlstring(L, name, name_len);
  lua_setfield(L, -2, "name");
  lua_pushinteger(L, type);
  lua_setfield(L, -2, "type");

  if (luaL_newmetatable(L, LUAHIREDIS_CONST_MT))
  {
    luaL_register(L, NULL, CONST_MT);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_pushliteral(L, LUAHIREDIS_CONST_MT);
    lua_setfield(L, -2, "__metatable");
  }

  lua_setmetatable(L, -2);

  return 1;
}

static const struct luahiredis_Enum Errors[] =
{
  { "ERR_IO",       REDIS_ERR_IO },
  { "ERR_EOF",      REDIS_ERR_EOF },
  { "ERR_PROTOCOL", REDIS_ERR_PROTOCOL },
  { "ERR_OTHER",    REDIS_ERR_OTHER },

  { NULL, 0 }
};

static const struct luahiredis_Enum ReplyTypes[] =
{
  { "REPLY_STRING",  REDIS_REPLY_STRING },
  { "REPLY_ARRAY",   REDIS_REPLY_ARRAY },
  { "REPLY_INTEGER", REDIS_REPLY_INTEGER },
  { "REPLY_NIL",     REDIS_REPLY_NIL },
  { "REPLY_STATUS",  REDIS_REPLY_STATUS },
  { "REPLY_ERROR",   REDIS_REPLY_ERROR },

  { NULL, 0 }
};

typedef struct luahiredis_Connection
{
  redisContext * pContext;
} luahiredis_Connection;

static redisContext * check_connection(lua_State * L, int idx)
{
  luahiredis_Connection * pConn = (luahiredis_Connection *)luaL_checkudata(
      L, idx, LUAHIREDIS_CONN_MT
    );
  if (pConn == NULL)
  {
    luaL_error(L, "lua-hiredis error: connection is null");
    return NULL; /* Unreachable */
  }

  if (pConn->pContext == NULL)
  {
    luaL_error(
        L, "lua-hiredis error: attempted to use closed connection"
      );
    return NULL; /* Unreachable */
  }

  return pConn->pContext;
}

/* Call this only if error is already detected */
static int push_error(lua_State * L, redisContext * pContext)
{
  /* TODO: Use errno if err is REDIS_ERR_IO */
  lua_pushnil(L);
  lua_pushstring(
      L,
      (pContext->errstr != NULL)
        ? pContext->errstr
        : "(lua-hiredis: no error message)" /* TODO: ?! */
    );
  lua_pushnumber(L, pContext->err);

  return 3;
}

static int load_args(
    lua_State * L,
    redisContext * pContext,
    int idx, /* index of first argument */
    const char ** argv,
    size_t * argvlen
  )
{
  int nargs = lua_gettop(L) - idx + 1;
  int i = 0;

  if (nargs <= 0)
  {
    return luaL_error(L, "missing command name");
  }

  if (nargs > LUAHIREDIS_MAXARGS)
  {
    return luaL_error(L, "too many arguments");
  }

  for (i = 0; i < nargs; ++i)
  {
    size_t len = 0;
    const char * str = lua_tolstring(L, idx + i, &len);

    if (str == NULL)
    {
      return luaL_argerror(L, idx + i, "expected a string or number value");
    }

    argv[i] = str;
    argvlen[i] = len;
  }

  return nargs;
}

static int push_reply(lua_State * L, redisReply * pReply)
{
  /* int base = lua_gettop(L); */

  switch(pReply->type)
  {
    case REDIS_REPLY_STATUS:
      lua_pushvalue(L, lua_upvalueindex(1)); /* M (module table) */

      lua_pushlstring(L, pReply->str, pReply->len); /* status */
      lua_gettable(L, -2); /* M[status] */

      if (lua_isnil(L, -1)) /* Not bothering with metatables */
      {
        /*
        * TODO: Following code is likely to be broken due to early binding
        * (imagine that RETURN is a command that returns given string
        * as a status):
        *
        *    assert(conn:command("RETURN", "FOO") == hiredis.FOO)
        *
        * Here hiredis.FOO would be nil before conn:command() is called.
        *
        * Note that this is not relevant to the current Redis implementation
        * (that is 2.2 and before), since it seems that it wouldn't
        * return any status code except OK, QUEUED or PONG,
        * all of which are already covered.
        */
        lua_pushlstring(L, pReply->str, pReply->len); /* status */
        push_new_const(
            L, pReply->str, pReply->len, REDIS_REPLY_STATUS /* const */
          );
        lua_settable(L, -3); /* M[status] = const */

        lua_pushlstring(L, pReply->str, pReply->len); /* status */
        lua_gettable(L, -2); /* return M[status] */
      }

      lua_remove(L, -2); /* Remove module table */

      break;

    case REDIS_REPLY_ERROR:
      /* Not caching errors, they are (hopefully) not that common */
      push_new_const(L, pReply->str, pReply->len, REDIS_REPLY_ERROR);
      break;

    case REDIS_REPLY_INTEGER:
      lua_pushinteger(L, pReply->integer);
      break;

    case REDIS_REPLY_NIL:
      lua_pushvalue(L, lua_upvalueindex(1)); /* module table */
      lua_getfield(L, -1, LUAHIREDIS_KEY_NIL);
      lua_remove(L, -2); /* module table */
      break;

    case REDIS_REPLY_STRING:
      lua_pushlstring(L, pReply->str, pReply->len);
      break;

    case REDIS_REPLY_ARRAY:
    {
      unsigned int i = 0;

      lua_createtable(L, pReply->elements, 0);

      for (i = 0; i < pReply->elements; ++i)
      {
        /*
        * Not controlling recursion depth:
        * if we parsed the reply somehow,
        * we hope to be able to push it.
        */

        push_reply(L, pReply->element[i]);
        lua_rawseti(L, -2, i + 1); /* Store sub-reply */
      }
      break;
    }

    default: /* should not happen */
      return luaL_error(L, "command: unknown reply type: %d", pReply->type);
  }

  /*
  if (lua_gettop(L) != base + 1)
  {
    return luaL_error(L, "pushreplystackerror: actual %d expected %d base %d type %d", lua_gettop(L), base + 1, base, pReply->type);
  }
  */

  /*
  * Always returning a single value.
  * If changed, change REDIS_REPLY_ARRAY above.
  */
  return 1;
}

static int lconn_command(lua_State * L)
{
  redisContext * pContext = check_connection(L, 1);

  const char * argv[LUAHIREDIS_MAXARGS];
  size_t argvlen[LUAHIREDIS_MAXARGS];
  int nargs = load_args(L, pContext, 2, argv, argvlen);

  int nret = 0;

  redisReply * pReply = (redisReply *)redisCommandArgv(
      pContext, nargs, argv, argvlen
    );
  if (pReply == NULL)
  {
    /* TODO: Shouldn't we clear the context error state somehow after this? */
    return push_error(L, pContext);
  }

  nret = push_reply(L, pReply);

  /*
  * TODO: Not entirely safe: if above code throws error, reply object is leaked.
  */
  freeReplyObject(pReply);
  pReply = NULL;

  return nret;
}

static int lconn_append_command(lua_State * L)
{
  redisContext * pContext = check_connection(L, 1);

  const char * argv[LUAHIREDIS_MAXARGS];
  size_t argvlen[LUAHIREDIS_MAXARGS];
  int nargs = load_args(L, pContext, 2, argv, argvlen);

  redisAppendCommandArgv(pContext, nargs, argv, argvlen);

  return 0;
}

static int lconn_get_reply(lua_State * L)
{
  redisContext * pContext = check_connection(L, 1);
  /* int base = lua_gettop(L); */

  int nret = 0;

  redisReply * pReply = NULL;

  int ok = redisGetReply(pContext, (void **)&pReply);
  if (ok != REDIS_OK || pReply == NULL)
  {
    /* TODO: Shouldn't we clear the context error state somehow after this? */
    return push_error(L, pContext);
  }

  /*
  if (lua_gettop(L) != base)
  {
    freeReplyObject(pReply);
    return luaL_error(
        L, "lhrstackerror1 actual %d expected %d", lua_gettop(L), base
      );
  }
  */

  nret = push_reply(L, pReply);

  /*
  if (lua_gettop(L) != base + nret)
  {
    freeReplyObject(pReply);
    return luaL_error(
        L, "lhrstackerror2 actual %d expected %d base %d", lua_gettop(L),
        base + nret, base
      );
  }
  */

  /*
  * TODO: Not entirely safe: if above code throws error, reply object is leaked.
  */
  freeReplyObject(pReply);
  pReply = NULL;

  return nret;
}

static int lconn_close(lua_State * L)
{
  luahiredis_Connection * pConn = (luahiredis_Connection *)luaL_checkudata(
      L, 1, LUAHIREDIS_CONN_MT
    );

  if (pConn && pConn->pContext != NULL)
  {
    redisFree(pConn->pContext);
    pConn->pContext = NULL;
  }

  return 0;
}

#define lconn_gc lconn_close

static int lconn_tostring(lua_State * L)
{
  /* redisContext * pContext = */check_connection(L, 1);

  /* TODO: Provide more information? */
  lua_pushliteral(L, "lua-hiredis.connection");

  return 1;
}

static const luaL_reg M[] =
{
  { "command", lconn_command },
  { "append_command", lconn_append_command },
  { "get_reply", lconn_get_reply },

  { "close", lconn_close },
  { "__gc", lconn_gc },
  { "__tostring", lconn_tostring },

  { NULL, NULL }
};

static int lhiredis_connect(lua_State * L)
{
  luahiredis_Connection * pResult = NULL;
  redisContext * pContext = NULL;

  const char * host = luaL_checkstring(L, 1);
  int port = luaL_checkint(L, 2);

  /* TODO: Support Timeout, Unix and UnixTimeout flavors */

  pContext = redisConnect(host, port);
  if (!pContext)
  {
    lua_pushnil(L);
    lua_pushliteral(L, "failed to create hiredis context");
    return 2;
  }

  if (pContext->err)
  {
    int result = push_error(L, pContext);

    redisFree(pContext);
    pContext = NULL;

    return result;
  }

  pResult = (luahiredis_Connection *)lua_newuserdata(
      L, sizeof(luahiredis_Connection)
    );
  pResult->pContext = pContext;

  if (luaL_newmetatable(L, LUAHIREDIS_CONN_MT))
  {
    /* Module table to be set as upvalue */
    lua_pushvalue(L, lua_upvalueindex(1));
    setfuncs(L, M, 1);

    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
  }

  lua_setmetatable(L, -2);

  return 1;
}

static int lhiredis_unwrap_reply(lua_State * L)
{
  int type = 0;

  luaL_checkany(L, 1);

  if (!lua_istable(L, 1))
  {
    lua_pushvalue(L, 1);
    return 1;
  }

  if (!lua_getmetatable(L, 1))
  {
    lua_pushvalue(L, 1);
    return 1;
  }

  luaL_getmetatable(L, LUAHIREDIS_CONST_MT);
  if (!lua_rawequal(L, -1, -2))
  {
    lua_pop(L, 2); /* both metatables */

    lua_pushvalue(L, 1);
    return 1;
  }

  lua_pop(L, 2); /* both metatables */

  lua_getfield(L, 1, "type");
  if (lua_type(L, -1) != LUA_TNUMBER)
  {
    lua_pop(L, 1); /* t.type */

    lua_pushvalue(L, 1);
    return 1;
  }

  type = lua_tonumber(L, -1);
  lua_pop(L, 1); /* t.type */

  if (type == REDIS_REPLY_STATUS)
  {
    lua_getfield(L, 1, "name");
    if (!lua_isstring(L, -1))
    {
      /* We promised to users that this wouldn't be nil */
      return luaL_error(L, "lua-hiredis internal error: bad const-object");
    }

    lua_pushinteger(L, REDIS_REPLY_STATUS);

    return 2;
  }
  else if (type == REDIS_REPLY_ERROR)
  {
    lua_pushnil(L);

    lua_getfield(L, 1, "name");
    if (!lua_isstring(L, -1))
    {
      /* We promised to users that this wouldn't be nil */
      return luaL_error(L, "lua-hiredis internal error: bad const-object");
    }

    return 2;
  }

  /* Note that NIL is not unwrapped */

  lua_pushvalue(L, 1);

  return 1;
}

static const struct luaL_reg E[] = /* Empty */
{
  { NULL, NULL }
};

/* Lua module API */
static const struct luaL_reg R[] =
{
  { "connect", lhiredis_connect },
  { "unwrap_reply", lhiredis_unwrap_reply },

  { NULL, NULL }
};

#ifdef __cplusplus
extern "C" {
#endif

LUALIB_API int luaopen_hiredis(lua_State * L)
{
  /*
  * Register module
  */
  luaL_register(L, "hiredis", E);

  /*
  * Register module information
  */
  lua_pushliteral(L, LUAHIREDIS_VERSION);
  lua_setfield(L, -2, "_VERSION");

  lua_pushliteral(L, LUAHIREDIS_COPYRIGHT);
  lua_setfield(L, -2, "_COPYRIGHT");

  lua_pushliteral(L, LUAHIREDIS_DESCRIPTION);
  lua_setfield(L, -2, "_DESCRIPTION");

  /*
  * Register enums
  */
  reg_enum(L, Errors);
  reg_enum(L, ReplyTypes);

  /*
  * Register constants
  */
  push_new_const(L, "NIL", 3, REDIS_REPLY_NIL);
  lua_setfield(L, -2, LUAHIREDIS_KEY_NIL);

  push_new_const(L, "OK", 2, REDIS_REPLY_STATUS);
  lua_setfield(L, -2, "OK");

  push_new_const(L, "QUEUED", 6, REDIS_REPLY_STATUS);
  lua_setfield(L, -2, "QUEUED");

  push_new_const(L, "PONG", 4, REDIS_REPLY_STATUS);
  lua_setfield(L, -2, "PONG");

  /*
  * Register functions
  */
  lua_pushvalue(L, -1); /* Module table to be set as upvalue */
  setfuncs(L, R, 1);

  return 1;
}

#ifdef __cplusplus
}
#endif
