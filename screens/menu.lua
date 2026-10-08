local app = require "app"
local ui = require "ui"
local Settings = require "settings"

local Menu = {}
Menu.__index = Menu

-- message: optional notice, e.g. "The host left the game"
function Menu.new(message)
  return setmetatable({ message = message }, Menu)
end

function Menu:enter()
  love.mouse.setVisible(true)
end

function Menu:draw()
  local t = love.timer.getTime()
  -- Drifting background dots in the four player colours.
  local colors = require("world").COLORS
  for i = 1, 24 do
    local c = colors[(i - 1) % 4 + 1]
    local x = (i * 173 + t * (12 + i % 5 * 6)) % (app.W + 80) - 40
    local y = (i * 97) % app.H
    love.graphics.setColor(c[1], c[2], c[3], 0.07)
    love.graphics.circle("fill", x, y, 18 + (i % 4) * 10)
  end

  app.centered("ROUNDS", app.fonts.huge, 80)
  app.centered("Lose a round, pick a card. Up to 4 players online.", app.fonts.med, 192, { 1, 1, 1, 0.55 })

  local w, h = 340, 58
  local x = (app.W - w) / 2
  local y = 260
  if ui.button("Local Play", x, y, w, h) then
    app.switch(require("screens.match").newLocal(Settings.values.roundsToWin))
  end
  if ui.button("Online Play", x, y + 72, w, h) then
    app.switch(require("screens.online").new())
  end
  if ui.button("Settings", x, y + 144, w, h) then
    app.push(require("screens.settings").new())
  end
  if ui.button("Quit", x, y + 216, w, h) then
    love.event.quit()
  end

  if self.message then
    app.centered(self.message, app.fonts.med, 560, { 1, 0.6, 0.45 })
  end

  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(1, 1, 1, 0.4)
  love.graphics.printf(
    "Local:  P1 WASD, Space fire, L-Shift block   |   P2 Arrows, R-Ctrl fire, R-Shift block\n" ..
    "Online:  A/D move, Space or W jump, S fast-fall, mouse aim, Left click fire, Right click block   |   Esc: menu",
    0, app.H - 56, app.W, "center")
end

return Menu
