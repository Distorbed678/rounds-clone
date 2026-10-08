local app = require "app"
local steam = require "steam"
local session = require "session"
local Settings = require "settings"
local Bloom = require "bloom"

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

function love.mousemoved()
  app.mousemoved()
end

function love.textinput(t)
  app.textinput(t)
end

function love.quit()
  session.leave()
  steam.shutdown()
end
