local app = require "core.app"
local steam = require "online.steam"
local session = require "online.session"
local Settings = require "core.settings"
local Bloom = require "gfx.bloom"

function love.load(args)
  love.keyboard.setKeyRepeat(false)
  Settings.load()
  Settings.apply()
  app.load()
  app.showFps = Settings.values.showFps
  Bloom.load(app.W, app.H)

  steam.init() -- normally already done in conf.lua; this is a no-op then
  session.init()
  session.onEntered = function()
    app.switch(require("screens.lobby").new())
  end

  app.switch(require("screens.menu").new())

  -- Launched from a Steam invite: "+connect_lobby <id>"
  for i, a in ipairs(args or {}) do
    if a == "+connect_lobby" and args[i + 1] then session.joinLobby(args[i + 1]) end
  end
end

function love.update(dt)
  dt = math.min(dt, 1 / 30)
  steam.update()
  session.update()
  app.update(dt)
end

function love.draw()
  app.draw()
end

function love.keypressed(key, scancode, isrepeat)
  local alt = love.keyboard.isDown("lalt", "ralt")
  if not isrepeat and (key == "f11" or ((key == "return" or key == "kpenter") and alt)) then
    Settings.toggleFullscreen()
    return
  end
  app.keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key)
  app.keyreleased(key)
end

function love.mousepressed(x, y, button)
  app.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
  app.mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
  app.wheelmoved(x, y)
end

function love.mousemoved()
  app.mousemoved()
end

function love.textinput(t)
  app.textinput(t)
end

-- LÖVE 11.5's default loop plus an optional frame cap (Settings.values.maxFps).
function love.run()
  if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
  if love.timer then love.timer.step() end

  local dt = 0
  local nextFrame = love.timer.getTime()
  return function()
    if love.event then
      love.event.pump()
      for name, a, b, c, d, e, f in love.event.poll() do
        if name == "quit" then
          if not love.quit or not love.quit() then return a or 0 end
        end
        love.handlers[name](a, b, c, d, e, f)
      end
    end

    dt = love.timer.step()
    if love.update then love.update(dt) end

    if love.graphics and love.graphics.isActive() then
      love.graphics.origin()
      love.graphics.clear(love.graphics.getBackgroundColor())
      if love.draw then love.draw() end
      love.graphics.present()
    end

    local cap = Settings.values.maxFps
    if cap and cap > 0 then
      local now = love.timer.getTime()
      nextFrame = math.max(nextFrame + 1 / cap, now - 1 / cap)
      local wait = nextFrame - now
      -- Sleep for most of the wait, then spin for precision.
      if wait > 0.002 then love.timer.sleep(wait - 0.0015) end
      while love.timer.getTime() < nextFrame do end
    else
      nextFrame = love.timer.getTime()
      love.timer.sleep(0.001)
    end
  end
end

function love.quit()
  session.leave()
  steam.shutdown()
end
