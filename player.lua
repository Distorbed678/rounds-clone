local Map = require "map"
local fx = require "fx"
local Bullet = require "bullet"

local Player = {}
Player.__index = Player

local GRAVITY = 1800
local MAX_FALL = 1100
local WALL_SLIDE = 120
local ORB_DISTANCE = 55
local ORB_SIZE = 9
local WELL_RADIUS = 280
local SHOCKWAVE_RADIUS = 170
local STASIS_RADIUS = 160

local BASE = {
  maxHp = 100, radius = 20,
  speed = 340, jump = 800, airJumps = 0, gravityMul = 1,
  damage = 34, bulletSpeed = 950, bulletGravity = 0.25, bulletSize = 5,
  bullets = 1, spread = 0, bounces = 0,
  fireDelay = 0.25, ammo = 3, reloadTime = 1.5,
  knockback = 250, lifesteal = 0, explosion = 0, poison = 0, homing = 0,
  blockCooldown = 4, blockTime = 0.3,
  -- block effects
  reflect = false, shockwave = 0, blockHeal = 0, blink = 0, empower = false,
  parry = false, blockReload = false, cloak = 0, blockNova = 0,
  -- special behaviours
  lives = 0, split = false, bounceDamage = 0, distDamage = 0, accel = 0, decay = false,
  recoil = 0, frost = 0, ghost = false, burst = 0, spinup = false, crit = 0, sticky = false,
  orbs = 0, berserk = 0, martyr = 0, repel = 0, backShot = false, blackhole = false,
  underdog = 0, scavenger = 0, laser = false, knockbackImmune = false, stasis = false,
}

local function approach(v, target, amount)
  if v < target then return math.min(v + amount, target) end
  return math.max(v - amount, target)
end

-- `input` is an input state table (see input.lua) that this player reads every frame.
function Player.new(id, color, input)
  local p = setmetatable({ id = id, color = color, input = input, cards = {}, score = 0 }, Player)
  p:recompute()
  return p
end

-- Rebuild stats from the base values plus every card collected.
function Player:recompute()
  local s = {}
  for k, v in pairs(BASE) do s[k] = v end
  for _, card in ipairs(self.cards) do card.apply(s) end
  s.maxHp = math.max(10, s.maxHp)
  s.fireDelay = math.max(0.06, s.fireDelay)
  s.reloadTime = math.max(0.3, s.reloadTime)
  s.blockCooldown = math.max(1, s.blockCooldown)
  s.ammo = math.max(1, math.floor(s.ammo + 0.5))
  s.bullets = math.max(1, math.floor(s.bullets + 0.5))
  s.crit = math.min(0.9, s.crit)
  s.orbs = math.min(8, s.orbs)
  self.stats = s
  self.r = s.radius
end

function Player:addCard(card)
  table.insert(self.cards, card)
  self:recompute()
end

function Player:spawn(x, y, facing, game)
  self.game = game
  self.spawnX, self.spawnY = x, y
  self.x, self.y = x, y
  self.vx, self.vy = 0, 0
  self.facing = facing
  self.aimX, self.aimY = facing, 0
  self.hp = self.stats.maxHp
  self.dead = false
  self.ammo = self.stats.ammo
  self.reloadTimer = 0
  self.fireTimer = 0
  self.sinceShot = 0
  self.blockTimer = 0
  self.blockCd = 0
  self.onGround = false
  self.coyote = 0
  self.wallDir = 0
  self.jumpsLeft = self.stats.airJumps
  self.controlLock = 0
  self.poisonTimer, self.poisonDps = 0, 0
  self.decay = {}
  self.hitFlash = 0
  self.livesLeft = self.stats.lives
  self.invuln = 0
  self.slowTimer = 0
  self.cloakTimer = 0
  self.empowered = false
  self.spin = 0
  self.burstLeft, self.burstTimer = 0, 0
  self.orbAngle = 0
  self.orbHit = {}
  self.seenJump = self.input.jumpCount
  self.seenBlock = self.input.blockCount
  self.jumpWasHeld = self.input.jumpHeld
end

function Player:isBlocking()
  return self.blockTimer > 0
end

function Player:orbPos(i)
  local a = self.orbAngle + (i - 1) / self.stats.orbs * math.pi * 2
  return self.x + math.cos(a) * ORB_DISTANCE, self.y + math.sin(a) * ORB_DISTANCE
end

function Player:update(dt, frozen)
  if self.dead then return end
  local s, game = self.stats, self.game

  self.fireTimer = math.max(0, self.fireTimer - dt)
  self.blockTimer = math.max(0, self.blockTimer - dt)
  self.blockCd = math.max(0, self.blockCd - dt)
  self.controlLock = math.max(0, self.controlLock - dt)
  self.hitFlash = math.max(0, self.hitFlash - dt)
  self.invuln = math.max(0, self.invuln - dt)
  self.slowTimer = math.max(0, self.slowTimer - dt)
  self.cloakTimer = math.max(0, self.cloakTimer - dt)
  self.sinceShot = self.sinceShot + dt

  -- Reload when empty, or top up after a short pause in firing.
  if self.reloadTimer > 0 then
    self.reloadTimer = self.reloadTimer - dt
    if self.reloadTimer <= 0 then
      self.reloadTimer = 0
      self.ammo = s.ammo
    end
  elseif self.ammo < s.ammo and self.sinceShot > 1.0 then
    self.reloadTimer = s.reloadTime
  end

  -- Damage over time: poison and Decay
  if self.poisonTimer > 0 then
    self.poisonTimer = self.poisonTimer - dt
    self.hp = self.hp - self.poisonDps * dt
    if love.math.random() < dt * 12 then
      fx.burst(self.x, self.y, { 0.4, 0.9, 0.2 }, 1, 60, 3)
    end
  end
  for i = #self.decay, 1, -1 do
    local d = self.decay[i]
    local amount = math.min(d.remaining, d.rate * dt)
    d.remaining = d.remaining - amount
    self.hp = self.hp - amount
    if d.remaining <= 0 then table.remove(self.decay, i) end
  end
  if self.hp <= 0 then
    self:die()
    if self.dead then return end
  end

  -- Jump/block are edge-triggered from press counters, so no press is ever lost.
  local inp = self.input
  if frozen then
    self.seenJump, self.seenBlock = inp.jumpCount, inp.blockCount
  else
    if inp.jumpCount ~= self.seenJump then
      self.seenJump = inp.jumpCount
      self:jumpPressed()
    end
    if inp.blockCount ~= self.seenBlock then
      self.seenBlock = inp.blockCount
      self:blockPressed()
    end
    if self.jumpWasHeld and not inp.jumpHeld then self:jumpReleased() end
  end
  self.jumpWasHeld = inp.jumpHeld

  -- Horizontal movement
  local dir = 0
  if not frozen then
    if inp.left then dir = dir - 1 end
    if inp.right then dir = dir + 1 end
  end
  if dir ~= 0 and self.controlLock <= 0 and not inp.aim then self.facing = dir end
  local speed = s.speed * (self.slowTimer > 0 and 0.5 or 1)
  local accel = self.onGround and 4000 or 2200
  if self.controlLock > 0 then accel = 600 end
  self.vx = approach(self.vx, dir * speed, accel * dt)

  -- Gravity and wall slide
  local fastFall = inp.aim and inp.down and not frozen and not self.onGround
  self.vy = math.min(self.vy + GRAVITY * s.gravityMul * (fastFall and 2.2 or 1) * dt, MAX_FALL)
  if not self.onGround and self.wallDir ~= 0 and dir == self.wallDir and self.vy > WALL_SLIDE then
    self.vy = WALL_SLIDE
  end

  -- Enemy black holes pull you in
  for _, w in ipairs(game.wells) do
    if w.owner ~= self then
      local dx, dy = w.x - self.x, w.y - self.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d > 1 and d < WELL_RADIUS then
        local f = 3200 * (1 - d / WELL_RADIUS) * dt
        self.vx = self.vx + dx / d * f
        self.vy = self.vy + dy / d * f
        self.controlLock = math.max(self.controlLock, 0.05)
      end
    end
  end

  local rects = game.map.rects
  self:moveX(self.vx * dt, rects)
  self:moveY(self.vy * dt, rects)
  self:senseWalls(rects)

  if self.onGround then
    self.coyote = 0.08
  else
    self.coyote = math.max(0, self.coyote - dt)
  end
  if self.onGround or self.wallDir ~= 0 then self.jumpsLeft = s.airJumps end

  if inp.aim then
    -- Mouse aim (online): free angle, facing follows the aim.
    self.aimX, self.aimY = math.cos(inp.aim), math.sin(inp.aim)
    if math.abs(self.aimX) > 0.05 and self.controlLock <= 0 then
      self.facing = self.aimX > 0 and 1 or -1
    end
  else
    -- Keyboard aim: facing direction, tilted 45 degrees up or down while holding up/down.
    local angle = 0
    if not frozen then
      if inp.up and not inp.down then angle = -math.pi / 4 elseif inp.down and not inp.up then angle = math.pi / 4 end
    end
    self.aimX, self.aimY = math.cos(angle) * self.facing, math.sin(angle)
  end

  local holding = not frozen and inp.fire
  if holding then self:tryFire() end
  if not holding or self.ammo == 0 then self.spin = math.max(0, self.spin - dt * 1.5) end

  -- Echo shots
  if self.burstLeft > 0 then
    self.burstTimer = self.burstTimer - dt
    if self.burstTimer <= 0 then
      self.burstLeft = self.burstLeft - 1
      self.burstTimer = 0.09
      self:volley(false)
    end
  end

  if s.orbs > 0 then self:updateOrbs(dt) end

  if self.y > 820 or self.x < -150 or self.x > 1430 then self:die(true) end
end

function Player:updateOrbs(dt)
  local game = self.game
  self.orbAngle = self.orbAngle + dt * 3
  for i = 1, self.stats.orbs do
    local ox, oy = self:orbPos(i)
    for _, b in ipairs(game.bullets) do
      if b.owner ~= self and not b.dead and not b.laser then
        local dx, dy = b.x - ox, b.y - oy
        local reach = ORB_SIZE + b.r
        if dx * dx + dy * dy < reach * reach then
          b.dead = true
          fx.burst(ox, oy, { 1, 1, 1 }, 5, 150, 2)
        end
      end
    end
    self.orbHit[i] = (self.orbHit[i] or 0) - dt
    if self.orbHit[i] <= 0 then
      for _, enemy in ipairs(game:enemiesOf(self)) do
        local dx, dy = enemy.x - ox, enemy.y - oy
        local reach = ORB_SIZE + enemy.r
        if dx * dx + dy * dy < reach * reach then
          enemy:hit(10, enemy.x - self.x, enemy.y - self.y, 300)
          self.orbHit[i] = 0.5
          break
        end
      end
    end
  end
end

function Player:moveX(dx, rects)
  local r = self.r
  self.x = self.x + dx
  for _, b in ipairs(rects) do
    if Map.overlaps(self.x - r, self.y - r, r * 2, r * 2, b) then
      if dx > 0 then self.x = b.x - r elseif dx < 0 then self.x = b.x + b.w + r end
      self.vx = 0
    end
  end
end

function Player:moveY(dy, rects)
  local r = self.r
  self.onGround = false
  self.y = self.y + dy
  for _, b in ipairs(rects) do
    if Map.overlaps(self.x - r, self.y - r, r * 2, r * 2, b) then
      if dy > 0 then
        self.y = b.y - r
        self.onGround = true
      elseif dy < 0 then
        self.y = b.y + b.h + r
      end
      self.vy = 0
    end
  end
end

function Player:senseWalls(rects)
  local r = self.r
  self.wallDir = 0
  if self.onGround then return end
  if Map.hit(rects, self.x - r - 2, self.y - r + 4, 2, r * 2 - 8) then
    self.wallDir = -1
  elseif Map.hit(rects, self.x + r, self.y - r + 4, 2, r * 2 - 8) then
    self.wallDir = 1
  end
end

function Player:jumpPressed()
  if self.dead then return end
  local s = self.stats
  if self.onGround or self.coyote > 0 then
    self.vy = -s.jump
    self.coyote = 0
    self.onGround = false
  elseif self.wallDir ~= 0 then
    self.vy = -s.jump * 0.95
    self.vx = -self.wallDir * s.speed * 1.2
    self.facing = -self.wallDir
    self.controlLock = 0.18
    fx.burst(self.x + self.wallDir * self.r, self.y, { 0.8, 0.8, 0.8 }, 5, 120, 3)
  elseif self.jumpsLeft > 0 then
    self.jumpsLeft = self.jumpsLeft - 1
    self.vy = -s.jump * 0.9
    fx.burst(self.x, self.y + self.r, self.color, 6, 150, 3)
  end
end

-- Releasing jump early cuts the jump short.
function Player:jumpReleased()
  if not self.dead and self.vy < 0 then self.vy = self.vy * 0.5 end
end

function Player:blockPressed()
  if self.dead or self.blockCd > 0 then return end
  local s, game = self.stats, self.game
  self.blockTimer = s.blockTime
  self.blockCd = s.blockCooldown
  fx.ring(self.x, self.y, self.r + 18, { 1, 1, 1 })

  if s.blockHeal > 0 then
    self:heal(s.blockHeal)
    fx.burst(self.x, self.y, { 0.4, 1, 0.5 }, 10, 160, 3)
  end
  if s.blockReload then
    self.ammo = s.ammo
    self.reloadTimer = 0
  end
  if s.empower then self.empowered = true end
  if s.cloak > 0 then self.cloakTimer = s.cloak end
  if s.blink > 0 then self:blink(s.blink) end

  if s.shockwave > 0 then
    fx.ring(self.x, self.y, SHOCKWAVE_RADIUS, self.color)
    fx.addShake(6)
    for _, e in ipairs(game:enemiesOf(self)) do
      local dx, dy = e.x - self.x, e.y - self.y
      local reach = SHOCKWAVE_RADIUS + e.r
      if dx * dx + dy * dy < reach * reach then e:hit(15 * s.shockwave, dx, dy, 650) end
    end
    for _, b in ipairs(game.bullets) do
      if b.owner ~= self and not b.laser then
        local dx, dy = b.x - self.x, b.y - self.y
        if dx * dx + dy * dy < SHOCKWAVE_RADIUS * SHOCKWAVE_RADIUS then b.dead = true end
      end
    end
  end

  if s.blockNova > 0 then
    for i = 1, s.blockNova do
      self:spawnBullet(i / s.blockNova * math.pi * 2, 0.8, false)
    end
  end
end

-- Teleport along the aim direction, as far as possible up to `dist`.
function Player:blink(dist)
  local rects = self.game.map.rects
  local r = self.r
  for d = dist, 30, -15 do
    local nx, ny = self.x + self.aimX * d, self.y + self.aimY * d
    if nx > 20 and nx < 1260 and ny > 20 and ny < 700
        and not Map.hit(rects, nx - r, ny - r, r * 2, r * 2) then
      fx.burst(self.x, self.y, self.color, 14, 220, 3)
      self.x, self.y = nx, ny
      self.vy = math.min(self.vy, 0)
      fx.burst(nx, ny, { 1, 1, 1 }, 14, 220, 3)
      return
    end
  end
end

function Player:tryFire()
  local s = self.stats
  if self.fireTimer > 0 or self.ammo <= 0 then return end

  local delay = s.fireDelay
  if s.spinup then
    self.spin = math.min(1, self.spin + 0.12)
    delay = delay / (1 + 2 * self.spin)
  end
  self.ammo = self.ammo - 1
  self.fireTimer = delay
  self.sinceShot = 0
  self.reloadTimer = (self.ammo == 0) and s.reloadTime or 0

  self:volley(true)
  if s.burst > 0 then
    self.burstLeft = s.burst
    self.burstTimer = 0.09
  end
end

-- Fire one volley (all pellets). Echo repeats call this with primary = false.
function Player:volley(primary)
  local s = self.stats
  local empowered = primary and self.empowered
  if primary then self.empowered = false end

  local base = math.atan2(self.aimY, self.aimX)
  for i = 1, s.bullets do
    local t = s.bullets > 1 and ((i - 1) / (s.bullets - 1) - 0.5) or 0
    local ang = base + t * s.spread + (love.math.random() - 0.5) * s.spread * 0.3
    local speedMul = s.bullets > 1 and (0.9 + love.math.random() * 0.2) or 1
    self:spawnBullet(ang, speedMul, empowered)
  end
  if s.backShot then self:spawnBullet(base + math.pi, 1, empowered) end

  fx.burst(self.x + self.aimX * (self.r + 12), self.y + self.aimY * (self.r + 12), { 1, 0.95, 0.7 }, 4, 150, 2)

  if s.recoil > 0 then
    if self.aimY > 0 and self.vy > 0 then self.vy = 0 end
    self.vx = self.vx - self.aimX * s.recoil
    self.vy = self.vy - self.aimY * s.recoil
    self.controlLock = math.max(self.controlLock, 0.12)
  end
end

function Player:spawnBullet(ang, speedMul, empowered)
  local s, game = self.stats, self.game
  local speed = s.bulletSpeed * (speedMul or 1)
  local bx = self.x + math.cos(ang) * (self.r + 8)
  local by = self.y + math.sin(ang) * (self.r + 8)
  -- If the muzzle is inside a wall, spawn from the body instead.
  if Map.hit(game.map.rects, bx - s.bulletSize, by - s.bulletSize, s.bulletSize * 2, s.bulletSize * 2) then
    bx, by = self.x, self.y
  end

  local b = Bullet.new(self, bx, by, math.cos(ang) * speed, math.sin(ang) * speed)
  if s.berserk > 0 then
    b.damage = b.damage * (1 + s.berserk * (1 - math.max(0, self.hp) / s.maxHp))
  end
  if s.underdog > 0 then
    local best = 0
    for _, p in ipairs(game.players) do
      if p ~= self then best = math.max(best, p.score) end
    end
    local behind = math.max(0, best - self.score)
    b.damage = b.damage * (1 + 0.2 * s.underdog * behind)
  end
  if empowered then
    b.damage = b.damage * 2
    b.r = b.r * 1.5
    b.vx, b.vy = b.vx * 1.2, b.vy * 1.2
  end
  if s.crit > 0 and love.math.random() < s.crit then b:makeCrit() end
  game:addBullet(b)
end

-- Returns true if damage landed (false when blocked, invulnerable or already dead).
function Player:hit(amount, dx, dy, knock)
  if self.dead then return false end
  if self:isBlocking() then
    fx.burst(self.x, self.y, { 1, 1, 1 }, 8, 200, 3)
    if self.stats.parry then self.blockCd = 0 end
    return false
  end
  if self.invuln > 0 then return false end

  if self.stats.decay then
    table.insert(self.decay, { remaining = amount, rate = amount / 4 })
  else
    self.hp = self.hp - amount
  end
  self.hitFlash = 0.1
  fx.burst(self.x, self.y, self.color, 10, 220, 4)
  fx.addShake(4)
  local len = math.sqrt(dx * dx + dy * dy)
  if len > 0 and not self.stats.knockbackImmune then
    self.vx = self.vx + dx / len * knock
    self.vy = self.vy + dy / len * knock - knock * 0.3
    self.controlLock = 0.12
  end
  if self.hp <= 0 then self:die() end
  return true
end

function Player:heal(amount)
  if self.dead then return end
  self.hp = math.min(self.stats.maxHp, self.hp + amount)
end

function Player:poisonFor(total, duration)
  local remaining = self.poisonDps * self.poisonTimer
  self.poisonTimer = duration
  self.poisonDps = (remaining + total) / duration
end

function Player:die(outOfBounds)
  if self.dead then return end
  fx.burst(self.x, self.y, self.color, 40, 450, 6)
  fx.addShake(12)

  -- Phoenix: come back instead of dying.
  if self.livesLeft > 0 then
    self.livesLeft = self.livesLeft - 1
    self.hp = self.stats.maxHp * 0.5
    self.poisonTimer = 0
    self.decay = {}
    self.invuln = 1.2
    if outOfBounds then
      self.x, self.y = self.spawnX, self.spawnY
      self.vx, self.vy = 0, 0
    end
    fx.ring(self.x, self.y, 90, { 1, 0.6, 0.15 })
    fx.burst(self.x, self.y, { 1, 0.7, 0.2 }, 30, 350, 5)
    return
  end

  self.dead = true
  self.hp = 0
  fx.burst(self.x, self.y, { 1, 1, 1 }, 15, 300, 4)

  if self.stats.martyr > 0 then
    local radius = 200
    fx.ring(self.x, self.y, radius, self.color)
    fx.burst(self.x, self.y, { 1, 0.6, 0.2 }, 50, 600, 6)
    fx.addShake(18)
    for _, e in ipairs(self.game:enemiesOf(self)) do
      local dx, dy = e.x - self.x, e.y - self.y
      if math.sqrt(dx * dx + dy * dy) < radius + e.r then
        e:hit(60 * self.stats.martyr, dx, dy, 800)
      end
    end
  end
end

-- Emissive parts only, drawn into the bloom buffer.
function Player:drawGlow()
  if self.dead then return end
  local A = self.cloakTimer > 0 and 0.08 or 1
  local c = self.color
  love.graphics.setColor(c[1], c[2], c[3], 0.45 * A)
  love.graphics.circle("fill", self.x, self.y, self.r)
  if self:isBlocking() then
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.setLineWidth(4)
    love.graphics.circle("line", self.x, self.y, self.r + 14)
  end
  if self.empowered then
    love.graphics.setColor(1, 0.9, 0.5, 0.8 * A)
    love.graphics.circle("fill", self.x + self.aimX * (self.r + 12), self.y + self.aimY * (self.r + 12), 6)
  end
  for i = 1, self.stats.orbs do
    local ox, oy = self:orbPos(i)
    love.graphics.setColor(c[1], c[2], c[3], 0.9)
    love.graphics.circle("fill", ox, oy, ORB_SIZE)
  end
end

function Player:draw()
  if self.dead then return end
  local r, s = self.r, self.stats
  local c = self.color

  local A = 1
  if self.cloakTimer > 0 then
    A = 0.12
  elseif self.invuln > 0 and math.floor(self.invuln * 15) % 2 == 0 then
    A = 0.4
  end

  if s.stasis then
    love.graphics.setColor(0.6, 0.8, 1, 0.06 * A)
    love.graphics.circle("fill", self.x, self.y, STASIS_RADIUS)
    love.graphics.setColor(0.6, 0.8, 1, 0.15 * A)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", self.x, self.y, STASIS_RADIUS)
  end

  if self:isBlocking() then
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle("fill", self.x, self.y, r + 14)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", self.x, self.y, r + 14)
  elseif self.blockCd > 0 then
    -- Block cooldown ring
    love.graphics.setColor(1, 1, 1, 0.25 * A)
    love.graphics.setLineWidth(2)
    local frac = 1 - self.blockCd / s.blockCooldown
    love.graphics.arc("line", "open", self.x, self.y, r + 7, -math.pi / 2, -math.pi / 2 + math.pi * 2 * frac)
  end

  for i = 1, s.orbs do
    local ox, oy = self:orbPos(i)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", ox, oy, ORB_SIZE + 1.5)
    love.graphics.setColor(c)
    love.graphics.circle("fill", ox, oy, ORB_SIZE)
  end

  -- Gun
  if self.empowered then
    love.graphics.setColor(1, 0.9, 0.5, A)
    love.graphics.setLineWidth(9)
  else
    love.graphics.setColor(0.85, 0.85, 0.9, A)
    love.graphics.setLineWidth(6)
  end
  love.graphics.line(self.x, self.y, self.x + self.aimX * (r + 12), self.y + self.aimY * (r + 12))

  -- Body
  if self.hitFlash > 0 then
    love.graphics.setColor(1, 1, 1, A)
  elseif self.poisonTimer > 0 then
    love.graphics.setColor(c[1] * 0.6 + 0.16, c[2] * 0.6 + 0.36, c[3] * 0.6 + 0.08, A)
  elseif self.slowTimer > 0 then
    love.graphics.setColor(c[1] * 0.5 + 0.3, c[2] * 0.5 + 0.4, c[3] * 0.5 + 0.5, A)
  else
    love.graphics.setColor(c[1], c[2], c[3], A)
  end
  love.graphics.circle("fill", self.x, self.y, r)
  if self.slowTimer > 0 then
    love.graphics.setColor(0.7, 0.9, 1, 0.7 * A)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, r + 2)
  end

  -- Eyes
  love.graphics.setColor(0.1, 0.1, 0.12, A)
  local ex = self.x + self.facing * r * 0.3
  love.graphics.circle("fill", ex - 5, self.y - r * 0.25, r * 0.13)
  love.graphics.circle("fill", ex + 5, self.y - r * 0.25, r * 0.13)

  -- HP bar (pending Decay damage shown faded)
  local pending = 0
  for _, d in ipairs(self.decay) do pending = pending + d.remaining end
  local bw, bx, by = 56, self.x - 28, self.y - r - 18
  local hpFrac = math.max(0, self.hp) / s.maxHp
  local solidFrac = math.max(0, self.hp - pending) / s.maxHp
  love.graphics.setColor(0, 0, 0, 0.6 * A)
  love.graphics.rectangle("fill", bx - 1, by - 1, bw + 2, 8)
  love.graphics.setColor(c[1], c[2], c[3], 0.35 * A)
  love.graphics.rectangle("fill", bx, by, bw * hpFrac, 6)
  love.graphics.setColor(c[1], c[2], c[3], A)
  love.graphics.rectangle("fill", bx, by, bw * solidFrac, 6)

  -- Phoenix lives
  for i = 1, self.livesLeft do
    love.graphics.setColor(1, 0.6, 0.15, A)
    love.graphics.circle("fill", bx + bw + 4 + i * 8, by + 3, 3)
  end

  -- Ammo pips, or a reload bar while reloading from empty
  local py = by - 8
  if self.ammo == 0 and self.reloadTimer > 0 then
    love.graphics.setColor(1, 1, 1, 0.8 * A)
    love.graphics.rectangle("fill", bx, py - 1, bw * (1 - self.reloadTimer / s.reloadTime), 3)
  else
    local spacing = math.min(9, bw / math.max(1, s.ammo))
    local startX = self.x - (s.ammo - 1) * spacing / 2
    for i = 1, s.ammo do
      love.graphics.setColor(1, 1, 1, (i <= self.ammo and 0.9 or 0.2) * A)
      love.graphics.circle("fill", startX + (i - 1) * spacing, py, 2.5)
    end
  end
end

return Player
