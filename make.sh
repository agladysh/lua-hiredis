#! /bin/bash

set -e

echo "----> Going pedantic all over the source"

# Ugh. hiredis.h is not c89-compatible
echo "--> c89..."
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/lua-hiredis.c -o /dev/null -Isrc/ -Ilib/ -Wall --pedantic --std=c89 #-Werror

echo "--> c99..."
gcc -O2 -fPIC -I/usr/include/lua5.1 -c src/lua-hiredis.c -o /dev/null -Isrc/ -Ilib/ -Wall --pedantic -Werror --std=c99

# Ugh. hiredis.h is not c++98-compatible
echo "--> c++98..."
gcc -xc++ -O2 -fPIC -I/usr/include/lua5.1 -c src/lua-hiredis.c -o /dev/null -Isrc/c/ -Ilib/ --pedantic -Wall --std=c++98 #-Werror

echo "----> Making rock"
sudo luarocks make rockspec/lua-hiredis-scm-1.rockspec
