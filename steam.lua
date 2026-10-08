-- Loads luasteam and initializes Steam. Every failure is caught: if anything is
-- missing (Steam not running, DLLs absent, wrong OS) steam.available is false and
-- steam.error explains why, so the rest of the game keeps working offline.
local steam = { available = false, Steam = nil, error = nil, tried = false }

local APP_ID = "480" -- Spacewar, Valve's public test app

-- Folder holding luasteam.dll / steam_api64.dll.
local function libDir()
  local src = love.filesystem.getSource()
  if love.filesystem.isFused() or src:match("%.love$") then
    return love.filesystem.getSourceBaseDirectory()
  end
  return src
end

function steam.init()
  if steam.tried then return steam.available end
  steam.tried = true

  local ok, err = pcall(function()
    local ffi = require "ffi"
    if ffi.os ~= "Windows" then error("Online play is only set up for Windows") end
    local dir = libDir()

    -- Tell steam_api which app we are, without depending on the working directory.
    pcall(ffi.cdef, "int SetEnvironmentVariableA(const char* name, const char* value);")
    ffi.C.SetEnvironmentVariableA("SteamAppId", APP_ID)
    ffi.C.SetEnvironmentVariableA("SteamGameId", APP_ID)

    -- Load steam_api64.dll from our folder first so luasteam.dll's dependency resolves to it.
    local okLib, lib = pcall(ffi.load, dir .. "/steam_api64.dll")
    if not okLib then error("steam_api64.dll is missing from the game folder") end
    steam.apiLib = lib -- keep a reference so it stays loaded

    package.cpath = dir .. "/?.dll;" .. package.cpath
    local okReq, Steam = pcall(require, "luasteam")
    if not okReq then error("luasteam.dll could not be loaded: " .. tostring(Steam)) end
    if not Steam.Init() then error("Steam is not running. Start Steam, log in, then restart the game.") end
    steam.Steam = Steam
  end)

  steam.available = ok
  if not ok then
    steam.error = tostring(err):gsub("^.-:%d+: ", "")
  end
  return ok
end

function steam.update()
  if steam.available then steam.Steam.RunCallbacks() end
end

function steam.shutdown()
  if steam.available then
    pcall(steam.Steam.Shutdown)
    steam.available = false
  end
end

function steam.myId()
  if not steam.available then return nil end
  return tostring(steam.Steam.User.GetSteamID())
end

function steam.myName()
  if not steam.available then return "Player" end
  return steam.Steam.Friends.GetPersonaName()
end

return steam
