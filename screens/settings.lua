-- Settings, shown as an overlay on top of whatever screen opened it.
local app = require "app"
local ui = require "ui"
local Settings = require "settings"

local Screen = {}
Screen.__index = Screen

function Screen.new()
  return setmetatable({}, Screen)
end

local function cycle(i, n, d)
  return (i - 1 + d) % n + 1
end

local function indexOf(list, value)
  for i, v in ipairs(list) do
    if v == value then return i end
  end
  return 1
end

function Screen:close()
  Settings.save()
  app.pop()
end

function Screen:keypressed(key)
  if key == "escape" then self:close() end
end

function Screen:draw()
  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, app.W, app.H)
  local pw, ph = 620, 640
  local px, py = (app.W - pw) / 2, (app.H - ph) / 2
  ui.panel(px, py, pw, ph)
  love.graphics.setFont(app.fonts.big)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("SETTINGS", px, py + 18, pw, "center")

  local v = Settings.values
  local x, w, h, gap = px + 40, pw - 80, 44, 52
  local y = py + 80
  local d

  -- Display
  d = ui.cycler("Window mode", Settings.WINDOW_MODE_NAMES[v.windowMode], x, y, w, h)
  if d ~= 0 then
    local modes = Settings.WINDOW_MODES
    v.windowMode = modes[cycle(indexOf(modes, v.windowMode), #modes, d)]
    Settings.applyWindow()
  end
  y = y + gap

  local res = Settings.RESOLUTIONS[v.resolution]
  local resText = v.windowMode == "borderless" and "Desktop" or (res[1] .. " x " .. res[2])
  d = ui.cycler("Resolution", resText, x, y, w, h)
  if d ~= 0 then
    v.resolution = cycle(v.resolution, #Settings.RESOLUTIONS, d)
    Settings.applyWindow()
  end
  y = y + gap

  d = ui.cycler("VSync", v.vsync and "On" or "Off", x, y, w, h)
  if d ~= 0 then
    v.vsync = not v.vsync
    Settings.applyWindow()
  end
  y = y + gap

  -- Graphics
  d = ui.cycler("Bloom", v.bloom and "On" or "Off", x, y, w, h)
  if d ~= 0 then
    v.bloom = not v.bloom
    Settings.applyEffects()
  end
  y = y + gap

  d = ui.cycler("Bloom intensity", Settings.BLOOM_LEVELS[v.bloomLevel][1], x, y, w, h)
  if d ~= 0 then
    v.bloomLevel = cycle(v.bloomLevel, #Settings.BLOOM_LEVELS, d)
    Settings.applyEffects()
  end
  y = y + gap

  d = ui.cycler("Screen shake", Settings.SHAKE_LEVELS[v.shake][1], x, y, w, h)
  if d ~= 0 then
    v.shake = cycle(v.shake, #Settings.SHAKE_LEVELS, d)
    Settings.applyEffects()
  end
  y = y + gap

  d = ui.cycler("Particles", Settings.PARTICLE_LEVELS[v.particles][1], x, y, w, h)
  if d ~= 0 then
    v.particles = cycle(v.particles, #Settings.PARTICLE_LEVELS, d)
    Settings.applyEffects()
  end
  y = y + gap

  d = ui.cycler("Show FPS", v.showFps and "On" or "Off", x, y, w, h)
  if d ~= 0 then
    v.showFps = not v.showFps
    app.showFps = v.showFps
  end
  y = y + gap

  -- Gameplay
  d = ui.cycler("Rounds to win (local)", tostring(v.roundsToWin), x, y, w, h)
  if d ~= 0 then
    local opts = Settings.ROUND_OPTIONS
    v.roundsToWin = opts[cycle(indexOf(opts, v.roundsToWin), #opts, d)]
  end
  y = y + gap + 12

  if ui.button("Back", x + w / 2 - 110, y, 220, 48) then self:close() end
end

return Screen
