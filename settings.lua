-- Player settings: saved to settings.txt in the LÖVE save folder.
local Bloom = require "bloom"
local fx = require "fx"

local Settings = {}

local FILE = "settings.txt"

Settings.RESOLUTIONS = { { 1280, 720 }, { 1600, 900 }, { 1920, 1080 }, { 2560, 1440 } }
Settings.WINDOW_MODES = { "windowed", "borderless", "fullscreen" }
Settings.WINDOW_MODE_NAMES = { windowed = "Windowed", borderless = "Borderless", fullscreen = "Fullscreen" }
Settings.BLOOM_LEVELS = { { "Low", 0.35 }, { "Medium", 0.6 }, { "High", 0.9 } }
Settings.SHAKE_LEVELS = { { "Off", 0 }, { "Low", 0.5 }, { "Full", 1 } }
Settings.PARTICLE_LEVELS = { { "Reduced", 0.5 }, { "Full", 1 } }
Settings.ROUND_OPTIONS = { 3, 5, 7, 10, 15 }

local defaults = {
  windowMode = "windowed",
  resolution = 1,
  vsync = true,
  bloom = true,
  bloomLevel = 2,
  shake = 3,
  particles = 2,
  showFps = false,
  roundsToWin = 5,
}

Settings.values = {}
for k, v in pairs(defaults) do Settings.values[k] = v end

function Settings.load()
  if not love.filesystem.getInfo(FILE) then return end
  for line in love.filesystem.lines(FILE) do
    local k, v = line:match("^([%w_]+)=(.*)$")
    local d = k and defaults[k]
    if d ~= nil then
      if type(d) == "boolean" then
        Settings.values[k] = (v == "true")
      elseif type(d) == "number" then
        Settings.values[k] = tonumber(v) or d
      else
        Settings.values[k] = v
      end
    end
  end
  local v = Settings.values
  v.resolution = math.max(1, math.min(#Settings.RESOLUTIONS, v.resolution))
  v.bloomLevel = math.max(1, math.min(#Settings.BLOOM_LEVELS, v.bloomLevel))
  v.shake = math.max(1, math.min(#Settings.SHAKE_LEVELS, v.shake))
  v.particles = math.max(1, math.min(#Settings.PARTICLE_LEVELS, v.particles))
  if not Settings.WINDOW_MODE_NAMES[v.windowMode] then v.windowMode = "windowed" end
end

function Settings.save()
  local lines = {}
  for k in pairs(defaults) do
    lines[#lines + 1] = k .. "=" .. tostring(Settings.values[k])
  end
  table.sort(lines)
  love.filesystem.write(FILE, table.concat(lines, "\n") .. "\n")
end

-- Effects that don't touch the window.
function Settings.applyEffects()
  local v = Settings.values
  Bloom.enabled = v.bloom
  Bloom.intensity = Settings.BLOOM_LEVELS[v.bloomLevel][2]
  fx.shakeScale = Settings.SHAKE_LEVELS[v.shake][2]
  fx.particleScale = Settings.PARTICLE_LEVELS[v.particles][2]
end

function Settings.applyWindow()
  local v = Settings.values
  local res = Settings.RESOLUTIONS[v.resolution]
  local w, h = res[1], res[2]
  local flags = {
    vsync = v.vsync and 1 or 0,
    resizable = true,
    minwidth = 640,
    minheight = 360,
  }
  if v.windowMode == "fullscreen" then
    flags.fullscreen = true
    flags.fullscreentype = "exclusive"
  elseif v.windowMode == "borderless" then
    flags.fullscreen = true
    flags.fullscreentype = "desktop"
    w, h = 0, 0
  else
    flags.fullscreen = false
    -- Don't open a window bigger than the desktop.
    local dw, dh = love.window.getDesktopDimensions()
    if w > dw or h > dh then w, h = math.floor(dw * 0.9), math.floor(dh * 0.9) end
  end
  local ok = pcall(love.window.setMode, w, h, flags)
  if not ok then
    -- Unsupported mode (e.g. exclusive fullscreen at that size): fall back to windowed.
    flags.fullscreen = false
    pcall(love.window.setMode, 1280, 720, flags)
  end
end

function Settings.apply()
  Settings.applyEffects()
  Settings.applyWindow()
end

return Settings
