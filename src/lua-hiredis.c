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

#define LUAHIREDIS_VERSION     "lua-hiredis 0.1.1"
#define LUAHIREDIS_COPYRIGHT   "Copyright (C) 2011, lua-hiredis authors"
#define LUAHIREDIS_DESCRIPTION "Bindings for hiredis Redis-client library"

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

static int lhiredis_command(lua_State * L)
{
  return 0; /* TODO */
}

static int lhiredis_append_command(lua_State * L)
{
  return 0; /* TODO */
}

static int lhiredis_get_reply(lua_State * L)
{
  return 0; /* TODO */
}

static int lhiredis_close(lua_State * L)
{
  return 0; /* TODO */
}

#define lhiredis_gc lhiredis_close

static int lhiredis_tostring(lua_State * L)
{
  return 0; /* TODO */
}

static const luaL_reg M[] =
{
  { "command", lhiredis_command },
  { "append_command", lhiredis_append_command },
  { "get_reply", lhiredis_get_reply },

  { "__close", lhiredis_close },
  { "__gc", lhiredis_gc },
  { "__tostring", lhiredis_tostring },

  { NULL, NULL }
};

static int lhiredis_connect(lua_State * L)
{
  return 0; /* TODO */
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
