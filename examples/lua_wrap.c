#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

// luaL_openlibs and luaL_dostring are macros in Lua 5.5
// wrap them as real functions for FFI

void lua_openlibs_wrap(lua_State *L) {
    luaL_openlibs(L);
}

int lua_dostring_wrap(lua_State *L, const char *s) {
    return luaL_dostring(L, s);
}
