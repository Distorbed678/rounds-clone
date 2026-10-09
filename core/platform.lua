-- Where the game is running. love._os is set before conf.lua runs, so this works everywhere.
-- The browser build (love.js) runs plain Lua 5.1: no LuaJIT, no ffi, no `bit` library.
local platform = {}

platform.web = love._os == "Web"

return platform
