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

#define LUAHIREDIS_VERSION     "lua-hiredis 0.1"
#define LUAHIREDIS_COPYRIGHT   "Copyright (C) 2011, lua-hiredis authors"
#define LUAHIREDIS_DESCRIPTION "Bindings for hiredis Redis-client library"

#define LUAHIREDIS_CONN_MT "lua-hiredis.connection"

#define LUAHIREDIS_MAXARGS (256)

#define LUAHIREDIS_NIL_KEY "NIL"
static const int NIL_TOKEN = 1; /* TODO: Is this the best solution possible? */

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

/* Error as a reply */
#define REDIS_ERR_REPLY 255

static const struct luahiredis_Enum Errors[] =
{
  { "ERR_IO",       REDIS_ERR_IO },
  { "ERR_EOF",      REDIS_ERR_EOF },
  { "ERR_PROTOCOL", REDIS_ERR_PROTOCOL },
  { "ERR_OTHER",    REDIS_ERR_OTHER },
  { "ERR_REPLY",    REDIS_ERR_REPLY },

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
  int nret = 0;
  int base = 0;
  int i = 0;

  switch(pReply->type)
  {
    case REDIS_REPLY_STATUS:
      nret = 1;
      lua_pushlstring(L, pReply->str, pReply->len);
      break;

    case REDIS_REPLY_ERROR:
      nret = 3;
      lua_pushnil(L);
      lua_pushlstring(L, pReply->str, pReply->len);
      lua_pushinteger(L, REDIS_ERR_REPLY);
      break;

    case REDIS_REPLY_INTEGER:
      nret = 1;
      lua_pushinteger(L, pReply->integer);
      break;

    case REDIS_REPLY_NIL:
      nret = 1;
      /* TODO: Lazy. Make this overridable? */
      lua_pushlightuserdata(L, (void *)&NIL_TOKEN);
      break;

    case REDIS_REPLY_STRING:
      nret = 1;
      lua_pushlstring(L, pReply->str, pReply->len);
      break;

    case REDIS_REPLY_ARRAY:
      nret = 1;

      lua_createtable(L, pReply->elements, 0);
      base = lua_gettop(L);

      for (i = 0; i < pReply->elements; ++i)
      {
        /*
          Not checking for too deep recursion:
          if we parsed the reply somehow,
          we should be able to push it.
        */

        int n = push_reply(L, pReply->element[i]);
        if (n != 1)
        {
          /* Probably there was an error */

          /*
            TODO: ?! Looks fragile and not robust.
                  At least for MULTI/EXEC we probably
                  want to get other command results.
          */

          lua_remove(L, base); /* Remove table, created above */
          nret = n;

          break;
        }

        lua_rawseti(L, -2, i + 1); /* Store sub-reply */
      }
      break;

    default: /* should not happen */
      nret = 2;
      lua_pushnil(L);
      lua_pushliteral(L, "command: unknown reply type");
      break;
  }

  return nret;
}

static int lconn_command(lua_State * L)
{
  redisContext * pContext = check_connection(L, 1);

  const char * argv[LUAHIREDIS_MAXARGS];
  size_t argvlen[LUAHIREDIS_MAXARGS];
  int nargs = load_args(L, pContext, 2, argv, argvlen);

  int nret = 0;
  int i = 0;

  redisReply * pReply = redisCommandArgv(pContext, nargs, argv, argvlen);
  if (pReply == NULL)
  {
    /* TODO: Shouldn't we clear the context error state after this? */
    return push_error(L, pContext);
  }

  nret = push_reply(L, pReply);

  freeReplyObject(pReply);
  pReply = NULL;

  return nret;
}

static int lconn_append_command(lua_State * L)
{
  redisContext * pContext = check_connection(L, 1);

  return 0; /* TODO */
}

static int lconn_get_reply(lua_State * L)
{
  redisContext * pContext = check_connection(L, 1);

  return 0; /* TODO */
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
  redisContext * pContext = check_connection(L, 1);

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

  pResult = lua_newuserdata(L, sizeof(luahiredis_Connection));
  pResult->pContext = pContext;

  if (luaL_newmetatable(L, LUAHIREDIS_CONN_MT))
  {
    luaL_register(L, NULL, M);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
  }

  lua_setmetatable(L, -2);

  return 1;
}

/* Lua module API */
static const struct luaL_reg R[] =
{
  { "connect", lhiredis_connect },

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
  luaL_register(L, "hiredis", R);

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

  /*
  * Register NIL token
  */
  lua_pushlightuserdata(L, (void *)&NIL_TOKEN);
  lua_setfield(L, -2, LUAHIREDIS_NIL_KEY);

  return 1;
}

#ifdef __cplusplus
}
#endif
