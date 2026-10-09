-- Map pool editor (pushed from Settings > Gameplay): every arena as a thumbnail; click one
-- to turn it on or off. Edits Settings.values.maps; online, the host's pool is used.
local app = require "core.app"
local ui = require "core.ui"
local Settings = require "core.settings"
local Map = require "game.map"

local Screen = {}
Screen.__index = Screen

local COLS = 7
local THUMB_W, THUMB_H = 160, 90
local GAP_X, LABEL_H, GAP_Y = 12, 22, 12
local GRID_Y = 100

function Screen.new()
  return setmetatable({}, Screen)
end

function Screen:keypressed(key)
  if key == "escape" then app.pop() end
end

local function drawThumb(map, x, y, on)
  love.graphics.setColor(0.09, 0.09, 0.12)
  love.graphics.rectangle("fill", x, y, THUMB_W, THUMB_H, 6, 6)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.scale(THUMB_W / 1280, THUMB_H / 720)
  Map.draw(map)
  love.graphics.pop()
  if not on then
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", x, y, THUMB_W, THUMB_H, 6, 6)
    love.graphics.setFont(app.fonts.title)
    love.graphics.setColor(1, 0.45, 0.45)
    love.graphics.printf("OFF", x, y + THUMB_H / 2 - 15, THUMB_W, "center")
  end
end

function Screen:draw()
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, app.W, app.H)
  ui.panel(20, 10, app.W - 40, app.H - 20)

  love.graphics.setFont(app.fonts.big)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("MAP POOL", 44, 26)
  local enabled = Settings.enabledMapCount()
  love.graphics.setFont(app.fonts.med)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.printf(enabled .. " / " .. #Map.list .. " maps enabled", 0, 40, app.W - 44, "right")
  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(1, 1, 1, 0.45)
  love.graphics.print("Click a map to turn it on or off. Online matches use the host's map pool.", 44, 70)

  local gridW = COLS * THUMB_W + (COLS - 1) * GAP_X
  local x0 = (app.W - gridW) / 2
  for i, map in ipairs(Map.list) do
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    local x = x0 + col * (THUMB_W + GAP_X)
    local y = GRID_Y + row * (THUMB_H + LABEL_H + GAP_Y)
    local on = Settings.mapEnabled(map)
    if ui.button("", x - 4, y - 4, THUMB_W + 8, THUMB_H + LABEL_H + 6) then Settings.setMap(map, not on) end
    drawThumb(map, x, y, on)
    love.graphics.setFont(app.fonts.small)
    love.graphics.setColor(1, 1, 1, on and 0.9 or 0.35)
    love.graphics.printf(map.name, x, y + THUMB_H + 3, THUMB_W, "center")
  end

  if enabled == 0 then
    love.graphics.setFont(app.fonts.med)
    love.graphics.setColor(1, 0.6, 0.45)
    love.graphics.printf("No maps are enabled, so every map will be used.", 0, 600, app.W, "center")
  end

  local bw, by = 220, 636
  if ui.button("Enable All", app.W / 2 - bw - 10, by, bw, 46) then Settings.values.maps = {} end
  if ui.button("Back", app.W / 2 + 10, by, bw, 46) then app.pop() end
end

return Screen
