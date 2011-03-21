package = "lua-hiredis"
version = "0.1-1"
source = {
   url = "git://github.com/agladysh/lua-hiredis.git",
   branch = "v0.1"
}
external_dependencies = {
   HIREDIS = {
     header = "hiredis.h",
   }
}
description = {
   summary = "Bindings for hiredis Redis-client library",
   homepage = "http://github.com/agladysh/lua-hiredis",
   license = "MIT/X11",
   maintainer = "Alexander Gladysh <agladysh@gmail.com>"
}
dependencies = {
   "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      hiredis = {
         sources = {
            "src/lua-hiredis.c",
         },
         incdirs = {
            "src/"
         },
         libraries = { "hiredis" }
      }
   }
}
