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

#define LUAHIREDIS_MT "lua-hiredis.connection"

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

static const struct luahiredis_Enum Errors[] =
{
  { "ERR_IO",       REDIS_ERR_IO },
  { "ERR_EOF",      REDIS_ERR_EOF },
  { "ERR_PROTOCOL", REDIS_ERR_PROTOCOL },
  { "ERR_OTHER",    REDIS_ERR_OTHER },

  { NULL, 0 }
};

/* Call this only if error is already detected */
static int push_error(lua_State * L, redisContext * pContext)
{
  lua_pushnil(L);
  lua_pushstring(L, pContext->errstr);
  lua_pushnumber(L, pContext->err);

  return 3;
}

typedef struct luahiredis_Connection
{
  redisContext * pContext;
} luahiredis_Connection;

static int lconn_command(lua_State * L)
{
  return 0; /* TODO */
}

static int lconn_append_command(lua_State * L)
{
  return 0; /* TODO */
}

static int lconn_get_reply(lua_State * L)
{
  return 0; /* TODO */
}

static int lconn_close(lua_State * L)
{
  return 0; /* TODO */
}

#define lconn_gc lconn_close

static int lconn_tostring(lua_State * L)
{
  return 0; /* TODO */
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

  pContext = redisConnect(host, port);
  if (!pContext)
  {
    /* Should not happen */
    return luaL_error(L, "failed to create hiredis context");
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

  if (luaL_newmetatable(L, LUAHIREDIS_MT))
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

  return 1;
}

#ifdef __cplusplus
}
#endif
