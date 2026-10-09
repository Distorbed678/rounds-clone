-- Card pool editor (pushed from Settings > Gameplay): browse every card, change
-- its rarity, and enable / disable it. Edits Settings.values.cards.
local app = require "core.app"
local ui = require "core.ui"
local Settings = require "core.settings"
local Cards = require "game.cards"
local hud = require "gfx.hud"

local Screen = {}
Screen.__index = Screen

local COLS, ROWS = 5, 12
local PER_PAGE = COLS * ROWS
local GRID_X, GRID_Y = 40, 116
local TILE_W, TILE_H, TILE_GAP = 148, 34, 6

-- Filters: all, one per rarity, disabled only.
local FILTERS = { { "All" } }
for _, r in ipairs(Cards.RARITIES) do FILTERS[#FILTERS + 1] = { r.name, rarity = r.id } end
FILTERS[#FILTERS + 1] = { "Disabled", disabled = true }

function Screen.new()
  return setmetatable({ selected = Cards.list[1], filter = 1, page = 1, tiles = {} }, Screen)
end

local function cycle(i, n, d)
  return (i - 1 + d) % n + 1
end

local function rarityIndex(id)
  for i, r in ipairs(Cards.RARITIES) do
    if r.id == id then return i end
  end
  return 1
end

-- Cards matching the filter, grouped by their configured rarity (so a card moved to
-- another rarity sits with that rarity's cards), then in list order.
function Screen:visibleCards()
  local f = FILTERS[self.filter]
  local list = {}
  for _, c in ipairs(Cards.list) do
    local ok = true
    if f.rarity and Settings.cardRarity(c) ~= f.rarity then ok = false end
    if f.disabled and Settings.cardEnabled(c) then ok = false end
    if ok then list[#list + 1] = c end
  end
  table.sort(list, function(a, b)
    local ra, rb = rarityIndex(Settings.cardRarity(a)), rarityIndex(Settings.cardRarity(b))
    if ra ~= rb then return ra < rb end
    return a.index < b.index
  end)
  return list
end

function Screen:pageCount(n)
  return math.max(1, math.ceil(n / PER_PAGE))
end

local function toggle(card)
  Settings.setCard(card, Settings.cardRarity(card), not Settings.cardEnabled(card))
end

function Screen:keypressed(key)
  if key == "escape" then app.pop() end
end

-- Right click a tile to toggle it on / off.
function Screen:mousepressed(x, y, button)
  if button ~= 2 then return end
  for _, t in ipairs(self.tiles) do
    if x >= t.x and x <= t.x + TILE_W and y >= t.y and y <= t.y + TILE_H then
      self.selected = t.card
      toggle(t.card)
      return
    end
  end
end

function Screen:wheelmoved(_, dy)
  local pages = self:pageCount(#self:visibleCards())
  if pages > 1 and dy ~= 0 then self.page = cycle(self.page, pages, dy > 0 and -1 or 1) end
end

-- Warnings about rarities that can roll but have nothing to offer.
local function warning()
  local enabled, total = {}, 0
  for _, c in ipairs(Cards.list) do
    if Settings.cardEnabled(c) then
      local r = Settings.cardRarity(c)
      enabled[r] = (enabled[r] or 0) + 1
      total = total + 1
    end
  end
  if total == 0 then return "Every card is disabled: card picks will be skipped." end
  local empty = {}
  for _, r in ipairs(Cards.RARITIES) do
    if Settings.values["weight_" .. r.id] > 0 and not enabled[r.id] then empty[#empty + 1] = r.name end
  end
  if #empty > 0 then
    return "No enabled cards for: " .. table.concat(empty, ", ") .. " (those rolls are skipped)."
  end
end

function Screen:draw()
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, app.W, app.H)
  ui.panel(20, 10, app.W - 40, app.H - 20)

  love.graphics.setFont(app.fonts.big)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("CARD POOL", GRID_X, 26)

  local cards = self:visibleCards()
  local pages = self:pageCount(#cards)
  self.page = math.min(self.page, pages)

  local d = ui.cycler("Show", FILTERS[self.filter][1], 330, 26, 300, 40)
  if d ~= 0 then
    self.filter = cycle(self.filter, #FILTERS, d)
    self.page = 1
    cards = self:visibleCards()
    pages = self:pageCount(#cards)
  end
  if pages > 1 then
    d = ui.cycler("Page", self.page .. " / " .. pages, 640, 26, 190, 40)
    if d ~= 0 then self.page = cycle(self.page, pages, d) end
  end

  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(1, 1, 1, 0.45)
  love.graphics.print("Click a card to edit it  -  right-click to turn it on / off", GRID_X, 80)

  -- Grid
  self.tiles = {}
  local first = (self.page - 1) * PER_PAGE
  for i = 1, math.min(PER_PAGE, #cards - first) do
    local c = cards[first + i]
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    local tx, ty = GRID_X + col * (TILE_W + TILE_GAP), GRID_Y + row * (TILE_H + TILE_GAP)
    self.tiles[#self.tiles + 1] = { x = tx, y = ty, card = c }
    local rc = Cards.rarity[Settings.cardRarity(c)].color
    local on = Settings.cardEnabled(c)
    if ui.button("", tx, ty, TILE_W, TILE_H) then self.selected = c end

    love.graphics.setColor(rc[1], rc[2], rc[3], on and 1 or 0.3)
    love.graphics.rectangle("fill", tx + 5, ty + 6, 5, TILE_H - 12, 2, 2)
    love.graphics.setFont(app.fonts.small)
    love.graphics.setColor(1, 1, 1, on and 0.9 or 0.3)
    love.graphics.printf(c.name, tx + 16, ty + (TILE_H - app.fonts.small:getHeight()) / 2, TILE_W - 22, "left")
    if not on then
      love.graphics.setFont(app.fonts.tiny)
      love.graphics.setColor(1, 0.45, 0.45, 0.9)
      love.graphics.printf("OFF", tx, ty + 2, TILE_W - 6, "right")
    end
    if c == self.selected then
      love.graphics.setColor(1, 1, 1)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", tx - 2, ty - 2, TILE_W + 4, TILE_H + 4, 10, 10)
    end
  end
  if #cards == 0 then
    love.graphics.setFont(app.fonts.med)
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.print("No cards match this filter.", GRID_X, GRID_Y + 10)
  end

  local warn = warning()
  if warn then
    love.graphics.setFont(app.fonts.med)
    love.graphics.setColor(1, 0.6, 0.45)
    love.graphics.printf(warn, GRID_X, 616, 760, "left")
  end

  -- Selected card
  local c = self.selected
  local px, pw = 830, 410
  local rarity = Settings.cardRarity(c)
  local on = Settings.cardEnabled(c)
  hud.drawCard(c, px + (pw - 290) / 2, 30, 290, 360, false, { 1, 1, 1 }, rarity)
  if not on then
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", px + (pw - 290) / 2, 30, 290, 360, 14, 14)
    love.graphics.setFont(app.fonts.big)
    love.graphics.setColor(1, 0.45, 0.45)
    love.graphics.printf("DISABLED", px, 290, pw, "center")
  end

  local y = 408
  d = ui.cycler("Rarity", Cards.rarity[rarity].name, px, y, pw, 42)
  if d ~= 0 then
    Settings.setCard(c, Cards.RARITIES[cycle(rarityIndex(rarity), #Cards.RARITIES, d)].id, on)
  end
  y = y + 50
  d = ui.cycler("Enabled", on and "Yes" or "No", px, y, pw, 42)
  if d ~= 0 then toggle(c) end
  y = y + 50

  local defaultText = c.baseRarity == rarity and on and "Default" or ("Reset (" .. Cards.rarity[c.baseRarity].name .. ")")
  if ui.button(defaultText, px, y, pw, 42, { font = app.fonts.med, disabled = c.baseRarity == rarity and on }) then
    Settings.setCard(c, c.baseRarity, true)
  end
  y = y + 56

  local bw = (pw - 12) / 2
  if ui.button("Enable All", px, y, bw, 42, { font = app.fonts.med }) then
    for _, card in ipairs(Cards.list) do Settings.setCard(card, Settings.cardRarity(card), true) end
  end
  if ui.button("Reset All Cards", px + bw + 12, y, bw, 42, { font = app.fonts.med }) then
    Settings.values.cards = {}
  end
  y = y + 56

  if ui.button("Back", px + pw / 2 - 110, y, 220, 46) then app.pop() end
end

return Screen
