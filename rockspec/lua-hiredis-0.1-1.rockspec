package = "lua-hiredis"
version = "0.1-1"
source = {
   url = "git://github.com/agladysh/lua-hiredis.git",
   branch = "v0.1"
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

            -- bundled hiredis code --
            "lib/hiredis/net.c",
            "lib/hiredis/async.c",
            "lib/hiredis/dict.c",
            "lib/hiredis/hiredis.c",
            "lib/hiredis/sds.c"
         },
         incdirs = {
            "src/",

            -- bundled hiredis code --
            "lib/hiredis/"
         }
      }
   }
}
