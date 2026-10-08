local Map = require "game.map"
local fx = require "gfx.fx"

local Bullet = {}
Bullet.__index = Bullet

local GRAVITY = 1800
local MAX_SPEED = 3200
local LASER_SPEED = 2000
local LASER_RANGE = 2600
local LASER_FADE = 0.22
local REPEL_RADIUS = 170
local STASIS_RADIUS = 160
local MINE_TRIGGER = 85
local HOMING_CONE = math.rad(70)
local CRIT_COLOR = { 1, 0.85, 0.2 }
Bullet.LASER_FADE = LASER_FADE
Bullet.CRIT_COLOR = CRIT_COLOR

local nextId = 0

function Bullet.new(owner, x, y, vx, vy)
  local s = owner.stats
  nextId = (nextId + 1) % 65536
  return setmetatable({
    id = nextId,
    owner = owner,
    x = x, y = y, vx = vx, vy = vy,
    r = s.bulletSize,
    damage = s.damage,
    bounces = s.bounces,
    bounced = false,
    gravity = s.bulletGravity,
    explosion = s.explosion,
    poison = s.poison,
    homing = s.homing,
    lifesteal = s.lifesteal,
    knockback = s.knockback,
    split = s.split,
    bounceDamage = s.bounceDamage,
    distDamage = s.distDamage,
    accel = s.accel,
    frost = s.frost,
    ghost = s.ghost,
    sticky = s.sticky,
    blackhole = s.blackhole,
    scavenger = s.scavenger,
    laser = s.laser,
    color = owner.color,
    life = 4,
    age = 0,
    travel = 0,
    dead = false,
    trail = {},
  }, Bullet)
end

function Bullet:makeCrit()
  self.crit = true
  self.damage = self.damage * 3
  self.r = self.r + 2
  self.color = CRIT_COLOR
end

function Bullet:currentDamage()
  return self.damage * (1 + self.distDamage * self.travel / 1000)
end

function Bullet:update(dt, game)
  if self.laser then return self:updateLaser(dt, game) end
  if self.mine then return self:updateMine(dt, game) end

  -- Stasis Field: enemy bullets crawl near the field's owner.
  for _, p in ipairs(game.players) do
    if p ~= self.owner and not p.dead and p.stats.stasis then
      local dx, dy = self.x - p.x, self.y - p.y
      if dx * dx + dy * dy < STASIS_RADIUS * STASIS_RADIUS then
        dt = dt * 0.3
        break
      end
    end
  end

  self.age = self.age + dt
  self.life = self.life - dt
  if self.life <= 0 then
    self.dead = true
    return
  end

  -- Homing only kicks in after a moment and only steers toward targets roughly ahead.
  if self.homing > 0 and self.age > 0.2 then
    local target = game:nearestEnemy(self.owner, self.x, self.y, true)
    if target then
      local speed = math.sqrt(self.vx * self.vx + self.vy * self.vy)
      local cur = math.atan2(self.vy, self.vx)
      local want = math.atan2(target.y - self.y, target.x - self.x)
      local diff = (want - cur + math.pi) % (math.pi * 2) - math.pi
      if math.abs(diff) < HOMING_CONE then
        local maxTurn = self.homing * dt
        cur = cur + math.max(-maxTurn, math.min(maxTurn, diff))
        self.vx, self.vy = math.cos(cur) * speed, math.sin(cur) * speed
      end
    end
  end

  if self.accel > 0 then
    local sp = math.sqrt(self.vx * self.vx + self.vy * self.vy)
    if sp > 0 and sp < MAX_SPEED then
      local k = math.min(MAX_SPEED, sp + self.accel * dt) / sp
      self.vx, self.vy = self.vx * k, self.vy * k
    end
  end

  for _, p in ipairs(game.players) do
    if p ~= self.owner and not p.dead and p.stats.repel > 0 then
      local dx, dy = self.x - p.x, self.y - p.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d > 1 and d < REPEL_RADIUS then
        local f = 2600 * p.stats.repel * (1 - d / REPEL_RADIUS) * dt
        self.vx = self.vx + dx / d * f
        self.vy = self.vy + dy / d * f
      end
    end
  end

  self.vy = self.vy + GRAVITY * self.gravity * dt

  -- Sub-step so fast bullets don't tunnel through thin platforms.
  local dist = math.sqrt(self.vx * self.vx + self.vy * self.vy) * dt
  local steps = math.max(1, math.ceil(dist / 6))
  local sdt = dt / steps
  for _ = 1, steps do
    self:step(sdt, game)
    if self.dead or self.mine then return end
  end

  table.insert(self.trail, 1, { self.x, self.y })
  if #self.trail > 6 then table.remove(self.trail) end
end

-- Lasers trace their whole path on the first frame, then linger briefly as a beam.
function Bullet:updateLaser(dt, game)
  if self.points then
    self.beam = self.beam - dt
    if self.beam <= 0 then self.dead = true end
    return
  end

  self.points = { { self.x, self.y } }
  local sp = math.sqrt(self.vx * self.vx + self.vy * self.vy)
  if sp == 0 then sp = 1 end
  self.vx, self.vy = self.vx / sp * LASER_SPEED, self.vy / sp * LASER_SPEED
  self.gravity = 0
  local sdt = 5 / LASER_SPEED
  local n = 0
  while not self.dead and self.travel < LASER_RANGE and n < 2000 do
    self:step(sdt, game)
    n = n + 1
  end
  table.insert(self.points, { self.x, self.y })
  fx.burst(self.x, self.y, self.color, 6, 160, 2)
  self.dead = false
  self.beam = LASER_FADE
end

function Bullet:updateMine(dt, game)
  self.life = self.life - dt
  self.armTime = self.armTime - dt
  if self.life <= 0 then
    self.dead = true
    return
  end
  if self.armTime > 0 then return end
  for _, e in ipairs(game:enemiesOf(self.owner)) do
    local dx, dy = e.x - self.x, e.y - self.y
    local reach = MINE_TRIGGER + e.r
    if dx * dx + dy * dy < reach * reach then
      self.dead = true
      self:explode(game, 1)
      return
    end
  end
end

function Bullet:step(dt, game)
  local r = self.r
  local rects = game.map.rects
  local mx, my = self.vx * dt, self.vy * dt
  self.travel = self.travel + math.sqrt(mx * mx + my * my)

  self.x = self.x + mx
  if not self.ghost and Map.hit(rects, self.x - r, self.y - r, r * 2, r * 2) then
    self.x = self.x - mx
    self.vx = -self.vx
    if not self:bounce(game) then return end
  end

  self.y = self.y + my
  if not self.ghost and Map.hit(rects, self.x - r, self.y - r, r * 2, r * 2) then
    self.y = self.y - my
    self.vy = -self.vy
    if not self:bounce(game) then return end
  end

  if self.x < -200 or self.x > 1480 or self.y > 900 or self.y < -600 then
    self.dead = true
    return
  end

  for _, p in ipairs(game.players) do
    -- A bullet can only hit its own shooter after it has bounced.
    if not p.dead and (p ~= self.owner or (self.bounced and self.age > 0.15)) then
      local dx, dy = p.x - self.x, p.y - self.y
      local reach = p.r + r
      if p:isBlocking() then reach = p.r + 14 + r end
      if dx * dx + dy * dy < reach * reach then
        self:hitPlayer(p, game)
        return
      end
    end
  end
end

-- Returns false if the bullet stops (dies or turns into a mine).
function Bullet:bounce(game)
  self.bounced = true
  self.bounces = self.bounces - 1
  if self.laser then table.insert(self.points, { self.x, self.y }) end
  if self.split and not self.isFragment then self:spawnFragments(game) end
  if not self.laser then fx.burst(self.x, self.y, self.color, 4, 120, 2) end

  if self.bounces < 0 then
    if self.sticky and not self.laser then
      self:becomeMine()
    else
      self.dead = true
      self:impact(game)
    end
    return false
  end
  if self.bounceDamage > 0 then self.damage = self.damage * (1 + self.bounceDamage) end
  return true
end

function Bullet:spawnFragments(game)
  self.split = false
  local ang = math.atan2(self.vy, self.vx)
  local sp = math.sqrt(self.vx * self.vx + self.vy * self.vy) * 0.85
  for i = -1, 1 do
    local a = ang + i * 0.45
    local f = Bullet.new(self.owner, self.x, self.y, math.cos(a) * sp, math.sin(a) * sp)
    f.isFragment = true
    f.split = false
    f.sticky = false
    f.damage = self.damage * 0.5
    f.r = math.max(2.5, self.r * 0.7)
    f.bounces = 0
    f.bounced = true
    f.color = self.color
    f.laser = self.laser
    game:addBullet(f)
  end
end

function Bullet:becomeMine()
  self.mine = true
  self.vx, self.vy = 0, 0
  self.life = 6
  self.armTime = 0.4
  self.explosion = math.max(self.explosion, 80)
  self.r = math.max(self.r, 6)
end

function Bullet:hitPlayer(p, game)
  -- Reflector: send the bullet straight back at whoever fired it.
  if p:isBlocking() and p.stats.reflect and p ~= self.owner then
    local shooter = self.owner
    if self.laser then table.insert(self.points, { self.x, self.y }) end
    self.owner = p
    self.color = p.color
    self.bounced = false
    self.age = 0
    local sp = math.max(600, math.sqrt(self.vx * self.vx + self.vy * self.vy))
    local dx, dy = shooter.x - p.x, shooter.y - p.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then dx, dy, d = -self.vx, -self.vy, sp end
    self.vx, self.vy = dx / d * sp, dy / d * sp
    self.x = p.x + dx / d * (p.r + 20 + self.r)
    self.y = p.y + dy / d * (p.r + 20 + self.r)
    if self.laser then table.insert(self.points, { self.x, self.y }) end
    fx.burst(self.x, self.y, { 1, 1, 1 }, 8, 200, 3)
    if p.stats.parry then p.blockCd = 0 end
    return
  end

  self.dead = true
  local dmg = self:currentDamage()
  local landed = p:hit(dmg, self.vx, self.vy, self.knockback)
  if landed then
    local o = self.owner
    if self.lifesteal > 0 then o:heal(dmg * self.lifesteal) end
    if self.poison > 0 then p:poisonFor(dmg * self.poison, 3) end
    if self.frost > 0 then p.slowTimer = math.max(p.slowTimer, self.frost) end
    if self.scavenger > 0 and not o.dead and o ~= p then
      o.ammo = math.min(o.stats.ammo, o.ammo + self.scavenger)
      o.reloadTimer = 0
    end
    if self.crit then fx.burst(p.x, p.y, CRIT_COLOR, 14, 300, 4) end
  end
  self:impact(game)
end

function Bullet:impact(game)
  if self.blackhole then
    table.insert(game.wells, { x = self.x, y = self.y, t = 1.4, max = 1.4, owner = self.owner })
  end
  self:explode(game)
end

function Bullet:explode(game, mult)
  if self.explosion <= 0 then return end
  fx.ring(self.x, self.y, self.explosion, self.color)
  fx.burst(self.x, self.y, self.color, 16, 300, 4)
  fx.addShake(5)
  local dmg = self:currentDamage() * (mult or 0.5)
  for _, p in ipairs(game.players) do
    if p ~= self.owner and not p.dead then
      local dx, dy = p.x - self.x, p.y - self.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d < self.explosion + p.r then
        p:hit(dmg, dx, dy, self.knockback * 1.5)
      end
    end
  end
end

function Bullet:draw()
  local c = self.color

  if self.laser then
    if not self.points then return end
    local flat = {}
    for _, pt in ipairs(self.points) do
      flat[#flat + 1] = pt[1]
      flat[#flat + 1] = pt[2]
    end
    if #flat < 4 then return end
    local a = math.max(0, self.beam / LASER_FADE)
    love.graphics.setLineJoin("bevel")
    love.graphics.setColor(c[1], c[2], c[3], 0.85 * a)
    love.graphics.setLineWidth(self.r * 1.4 + 3)
    love.graphics.line(flat)
    love.graphics.setColor(1, 1, 1, a)
    love.graphics.setLineWidth(math.max(1.5, self.r * 0.5))
    love.graphics.line(flat)
    love.graphics.setLineJoin("miter")
    return
  end

  if self.mine then
    local pulse = 0.5 + 0.5 * math.sin(self.life * (self.armTime > 0 and 6 or 14))
    love.graphics.setColor(c[1], c[2], c[3], 0.25 + 0.25 * pulse)
    love.graphics.circle("line", self.x, self.y, MINE_TRIGGER * 0.35)
    love.graphics.setColor(0.1, 0.1, 0.12)
    love.graphics.circle("fill", self.x, self.y, self.r + 2)
    love.graphics.setColor(c[1], c[2], c[3], 0.5 + 0.5 * pulse)
    love.graphics.circle("fill", self.x, self.y, self.r * 0.6)
    return
  end

  for i, t in ipairs(self.trail) do
    love.graphics.setColor(c[1], c[2], c[3], 0.4 * (1 - i / 7))
    love.graphics.circle("fill", t[1], t[2], self.r * (1 - i / 8))
  end
  love.graphics.setColor(1, 1, 1, self.ghost and 0.5 or 1)
  love.graphics.circle("fill", self.x, self.y, self.r + 1.5)
  love.graphics.setColor(c[1], c[2], c[3], self.ghost and 0.6 or 1)
  love.graphics.circle("fill", self.x, self.y, self.r)
end

return Bullet
