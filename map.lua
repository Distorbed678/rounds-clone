-- Arenas (lists of solid rectangles) and collision helpers.
local Map = {}

local function R(x, y, w, h) return { x = x, y = y, w = w, h = h } end

Map.list = {
  {
    name = "Classic",
    spawns = { { 300, 520 }, { 980, 520 }, { 360, 370 }, { 920, 370 } },
    rects = {
      R(140, 560, 1000, 40),
      R(600, 500, 80, 60),
      R(260, 410, 200, 20),
      R(820, 410, 200, 20),
      R(540, 280, 200, 20),
    },
  },
  {
    name = "Islands",
    spawns = { { 200, 540 }, { 1080, 540 }, { 350, 380 }, { 930, 380 } },
    rects = {
      R(80, 580, 300, 40),
      R(540, 500, 200, 40),
      R(900, 580, 300, 40),
      R(280, 420, 140, 20),
      R(860, 420, 140, 20),
      R(540, 320, 200, 20),
    },
  },
  {
    name = "The Pit",
    spawns = { { 220, 560 }, { 1060, 560 }, { 330, 290 }, { 950, 290 } },
    rects = {
      R(100, 600, 1080, 40),
      R(100, 180, 40, 420),
      R(1140, 180, 40, 420),
      R(600, 560, 80, 40),
      R(500, 450, 280, 20),
      R(260, 330, 140, 20),
      R(880, 330, 140, 20),
    },
  },
  {
    name = "The Box",
    spawns = { { 180, 600 }, { 1100, 600 }, { 250, 330 }, { 1030, 330 } },
    rects = {
      R(60, 640, 1160, 40),
      R(60, 40, 1160, 30),
      R(60, 70, 30, 570),
      R(1190, 70, 30, 570),
      R(360, 500, 140, 24),
      R(780, 500, 140, 24),
      R(570, 370, 140, 24),
      R(200, 370, 100, 24),
      R(980, 370, 100, 24),
    },
  },
  {
    name = "Pillars",
    spawns = { { 200, 560 }, { 1080, 560 }, { 500, 430 }, { 780, 430 } },
    rects = {
      R(120, 600, 1040, 40),
      R(300, 440, 40, 160),
      R(620, 380, 40, 220),
      R(940, 440, 40, 160),
      R(440, 470, 120, 16),
      R(720, 470, 120, 16),
      R(560, 260, 160, 16),
    },
  },
  {
    name = "Staircase",
    spawns = { { 160, 580 }, { 1120, 580 }, { 260, 340 }, { 1020, 340 } },
    rects = {
      R(80, 620, 240, 30),
      R(320, 540, 160, 30),
      R(480, 460, 320, 30),
      R(800, 540, 160, 30),
      R(960, 620, 240, 30),
      R(200, 380, 120, 16),
      R(960, 380, 120, 16),
      R(580, 300, 120, 16),
    },
  },
  {
    name = "The Bridge",
    spawns = { { 180, 480 }, { 1100, 480 }, { 270, 320 }, { 1010, 320 } },
    rects = {
      R(60, 520, 260, 200),
      R(960, 520, 260, 200),
      R(420, 520, 440, 16),
      R(60, 300, 24, 220),
      R(1196, 300, 24, 220),
      R(200, 360, 140, 16),
      R(940, 360, 140, 16),
      R(570, 330, 140, 16),
    },
  },
  {
    name = "The Cage",
    spawns = { { 200, 580 }, { 1080, 580 }, { 300, 430 }, { 980, 430 } },
    rects = {
      R(100, 620, 1080, 40),
      R(500, 320, 280, 20),
      R(500, 340, 20, 180),
      R(760, 340, 20, 180),
      R(560, 470, 160, 16),
      R(220, 470, 160, 16),
      R(900, 470, 160, 16),
      R(320, 330, 100, 16),
      R(860, 330, 100, 16),
    },
  },
  {
    name = "Skyward",
    spawns = { { 200, 540 }, { 1080, 540 }, { 350, 380 }, { 930, 380 } },
    rects = {
      R(120, 580, 160, 20),
      R(1000, 580, 160, 20),
      R(400, 520, 140, 20),
      R(740, 520, 140, 20),
      R(580, 420, 120, 20),
      R(260, 400, 120, 20),
      R(900, 400, 120, 20),
      R(420, 290, 120, 20),
      R(740, 290, 120, 20),
      R(580, 180, 120, 20),
    },
  },
  {
    name = "The Divide",
    spawns = { { 220, 560 }, { 1060, 560 }, { 240, 300 }, { 1040, 300 } },
    rects = {
      R(100, 600, 1080, 40),
      R(615, 330, 50, 270),
      R(380, 470, 140, 16),
      R(760, 470, 140, 16),
      R(180, 340, 120, 16),
      R(980, 340, 120, 16),
    },
  },
}

-- Pick a random map, avoiding the index of the previous one.
function Map.random(exclude)
  local i
  repeat
    i = love.math.random(#Map.list)
  until i ~= exclude or #Map.list == 1
  return Map.list[i], i
end

function Map.overlaps(ax, ay, aw, ah, b)
  return ax < b.x + b.w and ax + aw > b.x and ay < b.y + b.h and ay + ah > b.y
end

-- Returns the first rect overlapping the given box, or nil.
function Map.hit(rects, x, y, w, h)
  for _, b in ipairs(rects) do
    if Map.overlaps(x, y, w, h, b) then return b end
  end
  return nil
end

function Map.draw(map)
  for _, b in ipairs(map.rects) do
    love.graphics.setColor(0.3, 0.31, 0.38)
    love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
    love.graphics.setColor(0.45, 0.46, 0.55)
    love.graphics.rectangle("fill", b.x, b.y, b.w, 3)
  end
end

return Map
