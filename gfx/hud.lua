-- Shared drawing helpers for the match: score panels, cards, black holes, crosshair.
local app = require "core.app"
local Cards = require "game.cards"

local hud = {}

-- Card names grouped with counts, each tinted by rarity (a LÖVE coloredtext table).
function hud.cardSummary(p)
  local order, counts = {}, {}
  for _, c in ipairs(p.cards) do
    if not counts[c] then
      counts[c] = 0
      table.insert(order, c)
    end
    counts[c] = counts[c] + 1
  end
  local text = {}
  for i, c in ipairs(order) do
    local rc = Cards.rarity[c.rarity].color
    table.insert(text, { rc[1], rc[2], rc[3], 0.75 })
    table.insert(text, c.name .. (counts[c] > 1 and (" x" .. counts[c]) or "") .. (i < #order and ", " or ""))
  end
  return text
end

-- One panel per player across the top of the screen.
function hud.drawScores(players, winScore)
  local n = #players
  local W = app.W
  local pw = n <= 2 and 320 or math.floor((W - 48 - (n - 1) * 16) / n)
  for i, p in ipairs(players) do
    local x, align
    if n <= 2 then
      x = i == 1 and 24 or W - 24 - pw
      align = i == 1 and "left" or "right"
    else
      x = 24 + (i - 1) * (pw + 16)
      align = "left"
    end
    local a = p.disconnected and 0.35 or 1
    local c = p.color

    love.graphics.setFont(app.fonts.med)
    love.graphics.setColor(c[1], c[2], c[3], a)
    local name = (p.name or ("PLAYER " .. i)):upper()
    if p.disconnected then name = name .. " (LEFT)" end
    love.graphics.printf(name, x, 14, pw, align)

    local spacing = 22
    if winScore * spacing <= pw then
      for k = 1, winScore do
        local px
        if align == "left" then px = x + 8 + (k - 1) * spacing else px = x + pw - 8 - (k - 1) * spacing end
        if k <= p.score then
          love.graphics.setColor(c[1], c[2], c[3], a)
          love.graphics.circle("fill", px, 48, 7)
        else
          love.graphics.setColor(1, 1, 1, 0.25 * a)
          love.graphics.setLineWidth(2)
          love.graphics.circle("line", px, 48, 7)
        end
      end
    else
      love.graphics.setColor(c[1], c[2], c[3], a)
      love.graphics.printf(p.score .. " / " .. winScore, x, 38, pw, align)
    end

    if #p.cards > 0 then
      love.graphics.setFont(app.fonts.small)
      love.graphics.setColor(1, 1, 1, a)
      love.graphics.printf(hud.cardSummary(p), x, 62, pw, align)
    end
  end
end

-- Card layout used for both drawing and mouse hit-testing.
-- Cards shrink so that up to 6 fit across the screen.
function hud.cardRects(n, selected)
  local ch = 360
  local gap = n <= 3 and 36 or 18
  local cw = math.min(290, math.floor((app.W - 60 - (n - 1) * gap) / math.max(1, n)))
  local startX = (app.W - (n * cw + (n - 1) * gap)) / 2
  local rects = {}
  for i = 1, n do
    rects[i] = { startX + (i - 1) * (cw + gap), i == selected and 195 or 220, cw, ch }
  end
  return rects
end

-- rarityId: optional override (the card pool editor shows the configured rarity).
function hud.drawCard(card, x, y, w, h, selected, ownerColor, rarityId)
  rarityId = rarityId or card.rarity
  local rarity = Cards.rarity[rarityId]
  local rc = rarity.color
  local t = love.timer.getTime()

  if rarityId == "legendary" then
    local pulse = 0.5 + 0.5 * math.sin(t * 3)
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.15 + 0.2 * pulse)
    love.graphics.rectangle("fill", x - 8, y - 8, w + 16, h + 16, 18, 18)
  end

  love.graphics.setColor(0.12, 0.12, 0.16)
  love.graphics.rectangle("fill", x, y, w, h, 14, 14)
  love.graphics.setColor(rc)
  love.graphics.rectangle("fill", x, y, w, 80, 14, 14)
  love.graphics.rectangle("fill", x, y + 50, w, 30)

  if selected then
    love.graphics.setColor(ownerColor)
    love.graphics.setLineWidth(5)
  else
    love.graphics.setColor(rc[1], rc[2], rc[3], 0.5)
    love.graphics.setLineWidth(2)
  end
  love.graphics.rectangle("line", x, y, w, h, 14, 14)

  -- Narrow cards (5-6 on screen) use a smaller title font so long names fit.
  local titleFont = app.fonts.title
  if titleFont:getWidth(card.name) > w - 20 then titleFont = app.fonts.med end
  love.graphics.setFont(titleFont)
  love.graphics.setColor(0.08, 0.08, 0.1)
  love.graphics.printf(card.name, x + 10, y + 40 - titleFont:getHeight() / 2, w - 20, "center")

  local font = app.fonts.med
  love.graphics.setFont(font)
  local ly = y + 100
  for _, line in ipairs(card.lines) do
    local first = line:sub(1, 1)
    if first == "+" then
      love.graphics.setColor(0.5, 1, 0.5)
    elseif first == "-" then
      love.graphics.setColor(1, 0.45, 0.45)
    else
      love.graphics.setColor(1, 1, 1)
    end
    love.graphics.printf(line, x + 14, ly, w - 28, "center")
    local _, wrapped = font:getWrap(line, w - 28)
    ly = ly + #wrapped * font:getHeight() + 10
  end

  -- What extra copies do (for cards where it isn't just "the stats add up").
  if card.stack then
    local sf = app.fonts.small
    love.graphics.setFont(sf)
    local _, wrapped = sf:getWrap("Stacking: " .. card.stack, w - 28)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("Stacking: " .. card.stack, x + 14, y + h - 40 - #wrapped * sf:getHeight(), w - 28, "center")
  end

  local label = rarity.name:upper()
  if card.block then label = label .. "  -  BLOCK" end
  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(rc)
  love.graphics.printf(label, x, y + h - 30, w, "center")
end

function hud.drawWells(wells)
  local t = love.timer.getTime()
  for _, w in ipairs(wells) do
    local k = math.max(0, math.min(1, w.t / 0.3, (w.max - w.t) / 0.15 + 0.2))
    local c = w.owner.color
    love.graphics.setColor(c[1], c[2], c[3], 0.08 * k)
    love.graphics.circle("fill", w.x, w.y, w.radius or 280)
    love.graphics.setLineWidth(2)
    for i = 0, 2 do
      local rr = (22 + ((t * 60 + i * 20) % 60)) * k
      love.graphics.setColor(c[1], c[2], c[3], 0.5 * (1 - rr / (82 * math.max(k, 0.01))))
      love.graphics.circle("line", w.x, w.y, rr)
    end
    love.graphics.setColor(0.02, 0.02, 0.04, 0.95)
    love.graphics.circle("fill", w.x, w.y, 18 * k)
  end
end

function hud.drawCrosshair(x, y, color)
  love.graphics.setLineWidth(2)
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.circle("line", x, y, 11)
  love.graphics.setColor(color)
  love.graphics.circle("line", x, y, 9)
  love.graphics.line(x - 15, y, x - 5, y)
  love.graphics.line(x + 5, y, x + 15, y)
  love.graphics.line(x, y - 15, x, y - 5)
  love.graphics.line(x, y + 5, x, y + 15)
end

return hud
