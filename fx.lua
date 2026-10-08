-- Particles, explosion rings and screen shake.
-- When fx.recorder is a table (online host), every effect is also recorded so it
-- can be replayed on clients.
local fx = {
  particles = {}, rings = {}, shake = 0,
  shakeScale = 1, particleScale = 1,
  recorder = nil,
}

local MAX_RECORDED = 300

local function record(ev)
  local r = fx.recorder
  if r and #r < MAX_RECORDED then r[#r + 1] = ev end
end

function fx.burst(x, y, color, count, speed, size)
  count = count or 12
  speed = speed or 250
  size = size or 4
  record({ 1, x, y, color, count, speed, size })
  count = math.max(1, math.floor(count * fx.particleScale + 0.5))
  for _ = 1, count do
    local a = love.math.random() * math.pi * 2
    local s = speed * (0.3 + love.math.random() * 0.7)
    local life = 0.3 + love.math.random() * 0.4
    table.insert(fx.particles, {
      x = x, y = y,
      vx = math.cos(a) * s, vy = math.sin(a) * s,
      life = life, max = life,
      color = color,
      size = size * (0.5 + love.math.random() * 0.8),
    })
  end
end

function fx.ring(x, y, radius, color)
  record({ 2, x, y, radius, color })
  table.insert(fx.rings, { x = x, y = y, r = radius, life = 0.25, max = 0.25, color = color })
end

function fx.addShake(amount)
  record({ 3, amount })
  fx.shake = math.max(fx.shake, amount * fx.shakeScale)
end

function fx.clear()
  record({ 4 })
  fx.particles = {}
  fx.rings = {}
  fx.shake = 0
end

function fx.update(dt)
  for i = #fx.particles, 1, -1 do
    local p = fx.particles[i]
    p.life = p.life - dt
    if p.life <= 0 then
      table.remove(fx.particles, i)
    else
      p.vy = p.vy + 700 * dt
      p.vx = p.vx * (1 - 2 * dt)
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
    end
  end
  for i = #fx.rings, 1, -1 do
    local r = fx.rings[i]
    r.life = r.life - dt
    if r.life <= 0 then table.remove(fx.rings, i) end
  end
  fx.shake = math.max(0, fx.shake - 40 * dt)
end

function fx.draw()
  for _, p in ipairs(fx.particles) do
    local c = p.color
    love.graphics.setColor(c[1], c[2], c[3], p.life / p.max)
    love.graphics.circle("fill", p.x, p.y, p.size * (0.4 + 0.6 * p.life / p.max))
  end
  for _, r in ipairs(fx.rings) do
    local t = 1 - r.life / r.max
    local c = r.color
    love.graphics.setColor(c[1], c[2], c[3], 0.35 * (1 - t))
    love.graphics.circle("fill", r.x, r.y, r.r * (0.4 + 0.6 * t))
    love.graphics.setColor(1, 1, 1, 0.8 * (1 - t))
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", r.x, r.y, r.r * (0.4 + 0.6 * t))
  end
end

return fx
