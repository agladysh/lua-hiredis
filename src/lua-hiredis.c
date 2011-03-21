/*
* lua-hiredis.c: Bindings for hiredis Redis-client library
*                See copyright information in file COPYRIGHT.
*/

#define LUAHIREDIS_VERSION     "lua-hiredis 0.1.1"
#define LUAHIREDIS_COPYRIGHT   "Copyright (C) 2011, lua-hiredis authors"
#define LUAHIREDIS_DESCRIPTION "Bindings for hiredis Redis-client library"

#include "lua-hiredis.h"

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

static const struct luahiredis_Enum Options[] =
{
  /* TODO */

  { NULL, 0 }
};

/* Lua module API */
static const struct luaL_reg R[] =
{
  /* TODO */

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

  /* TODO */

  return 1;
}

#ifdef __cplusplus
}
#endif
