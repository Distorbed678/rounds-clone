-- Online menu: host a lobby or join one with a code.
local app = require "app"
local ui = require "ui"
local steam = require "steam"
local session = require "session"
local Settings = require "settings"

local Online = {}
Online.__index = Online

function Online.new()
  return setmetatable({ code = "" }, Online)
end

function Online:enter()
  session.error = nil
end

local function back()
  app.switch(require("screens.menu").new())
end

function Online:keypressed(key)
  if key == "escape" then back() end
end

local function codeFilter(s)
  return (s:upper():gsub("[^A-Z0-9]", ""))
end

function Online:draw()
  app.centered("ONLINE", app.fonts.huge, 60)

  local w = 420
  local x = (app.W - w) / 2

  if not steam.available then
    app.centered("Steam isn't available", app.fonts.title, 230, { 1, 0.6, 0.45 })
    love.graphics.setFont(app.fonts.med)
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.printf(steam.error or "Unknown error", app.W / 2 - 360, 280, 720, "center")
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("Online play uses Steam (test app Spacewar, 480). Make sure Steam is running " ..
      "and you're logged in, then restart the game.", app.W / 2 - 360, 350, 720, "center")
    if ui.button("Back", x, 470, w, 54) then back() end
    return
  end

  app.centered("Signed in as " .. steam.myName(), app.fonts.med, 175, { 0.6, 1, 0.6 })

  local busy = session.busy
  if ui.button("Host Lobby", x, 225, w, 58, { disabled = busy }) then
    session.host(Settings.values.roundsToWin)
  end

  app.centered("or join with a lobby code", app.fonts.med, 315, { 1, 1, 1, 0.6 })
  local submitted
  self.code, submitted = ui.textField(self.code, x, 350, w, 60, {
    placeholder = "ENTER CODE", maxLength = 6, filter = codeFilter, font = app.fonts.big,
  })
  if ui.button("Join", x, 424, w, 54, { disabled = busy or #self.code < 6 }) or (submitted and #self.code == 6) then
    session.joinByCode(self.code)
  end

  if session.status then
    app.centered(session.status, app.fonts.med, 500, { 1, 1, 1, 0.8 })
  elseif session.error then
    app.centered(session.error, app.fonts.med, 500, { 1, 0.6, 0.45 })
  end

  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(1, 1, 1, 0.45)
  love.graphics.printf("Got a Steam invite? Accept it in Steam while the game is open and you'll join automatically.",
    0, 545, app.W, "center")

  if ui.button("Back", x, 590, w, 50) then back() end
end

return Online
