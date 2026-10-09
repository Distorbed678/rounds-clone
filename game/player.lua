local Map = require "game.map"
local fx = require "gfx.fx"
local Bullet = require "game.bullet"

local Player = {}
Player.__index = Player

-- Wall jump: upward speed (fraction of jump), push away from the wall (fraction of move
-- speed) and how long steering is weakened afterwards.
Player.WALL_JUMP = { up = 0.95, push = 0.6, lock = 0.1 }

local GRAVITY = 1800
local MAX_FALL = 1100
local WALL_SLIDE = 120
local ORB_DISTANCE = 55
local ORB_SIZE = 9
local SHOCKWAVE_RADIUS = 170
local STATIC_RADIUS = 130
local SENTRY_DELAY = 0.9
local ARENA_W, ARENA_H = 1280, 720

local BASE = {
  maxHp = 100, radius = 20,
  speed = 340, jump = 800, airJumps = 0, gravityMul = 1,
  damage = 34, bulletSpeed = 950, bulletGravity = 0.25, bulletSize = 5,
  bullets = 1, spread = 0, bounces = 0,
  fireDelay = 0.25, ammo = 3, reloadTime = 1.5,
  knockback = 250, lifesteal = 0, explosion = 0, poison = 0, homing = 0,
  blockCooldown = 4, blockTime = 0.3,
  -- Card abilities are counts (copies held), so every card stacks; 0 = not owned.
  -- block effects
  reflect = 0, shockwave = 0, blockHeal = 0, blink = 0, empower = 0,
  parry = 0, blockReload = 0, cloak = 0, blockNova = 0,
  -- special behaviours
  lives = 0, split = 0, bounceDamage = 0, distDamage = 0, accel = 0, decay = 0,
  recoil = 0, frost = 0, ghost = 0, burst = 0, spinup = 0, crit = 0, sticky = 0,
  orbs = 0, berserk = 0, martyr = 0, repel = 0, backShot = 0, blackhole = 0,
  underdog = 0, scavenger = 0, laser = 0, knockbackImmune = false, stasis = 0,
  -- v0.3 cards
  armor = 0, regen = 0, lastRound = 0, thorns = 0, spite = 0, execute = 0, combo = 0,
  sprintBlock = 0, frostback = 0, mineLayer = 0, static = 0, quickdraw = 0, pierce = 0,
  shrapnel = 0, seek = 0, lastStand = 0, lockLoad = 0, momentum = 0, reloadNova = 0,
  adrenaline = 0, gravityBlock = 0, swap = 0, cluster = 0, shieldMax = 0, timeWarp = 0,
  hydra = 0, sentry = 0, mirror = 0, railgun = 0,
}

Player.stasisRadius = Bullet.stasisRadius

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
  s.radius = math.max(10, s.radius)
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
  self.empowerShots = 0
  self.spin = 0
  self.burstLeft, self.burstTimer = 0, 0
  self.orbAngle = 0
  self.orbHit = {}
  self.shield = self.stats.shieldMax
  self.lastStandLeft = self.stats.lastStand
  self.spiteReady = false
  self.quickdrawReady = false
  self.comboCount, self.comboTimer = 0, 0
  self.sprintTimer = 0
  self.freeAmmo = 0
  self.warpTimer = 0
  self.swapCd = 0
  self.sentryTimer = 1
  self.staticTimer = 0
  self.seenJump = self.input.jumpCount
  self.seenBlock = self.input.blockCount
  self.jumpWasHeld = self.input.jumpHeld
end

function Player:isBlocking()
  return self.blockTimer > 0
end

-- Where the Sentry turret hovers (behind the player's shoulder).
function Player:sentryPos()
  return self.x - self.facing * (self.r + 16), self.y - self.r - 14
end

-- Adrenaline is active below half HP.
function Player:adrenalineActive()
  return self.stats.adrenaline > 0 and self.hp < self.stats.maxHp * 0.5
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
  self.sprintTimer = math.max(0, self.sprintTimer - dt)
  self.freeAmmo = math.max(0, self.freeAmmo - dt)
  self.warpTimer = math.max(0, self.warpTimer - dt)
  self.swapCd = math.max(0, self.swapCd - dt)
  if self.comboTimer > 0 then
    self.comboTimer = self.comboTimer - dt
    if self.comboTimer <= 0 then self.comboCount = 0 end
  end
  self.sinceShot = self.sinceShot + dt

  -- Reload when empty, or top up after a short pause in firing.
  if self.reloadTimer > 0 then
    self.reloadTimer = self.reloadTimer - dt
    if self.reloadTimer <= 0 then
      self.reloadTimer = 0
      self.ammo = s.ammo
      self:reloaded()
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
  if s.regen > 0 and self.hp > 0 then self.hp = math.min(s.maxHp, self.hp + s.regen * dt) end
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
  if self.sprintTimer > 0 then speed = speed * (1 + 0.4 * s.sprintBlock) end
  if self:adrenalineActive() then speed = speed * (1 + 0.2 * s.adrenaline) end
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
      if d > 1 and d < w.radius then
        local f = w.strength * (1 - d / w.radius) * dt
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
  -- Overclock copies make the ramp drain more slowly.
  if not holding or self.ammo == 0 then self.spin = math.max(0, self.spin - dt * 1.5 / math.max(1, s.spinup)) end

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
  if not frozen then
    if s.static > 0 then self:updateStatic(dt) end
    if s.sentry > 0 then self:updateSentry(dt) end
  end

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
          enemy:hit(10, enemy.x - self.x, enemy.y - self.y, 300, self)
          self.orbHit[i] = 0.5
          break
        end
      end
    end
  end
end

-- Static Field: enemies close by take damage over time (pulses a ring so it's visible online).
function Player:updateStatic(dt)
  local s = self.stats
  self.staticTimer = self.staticTimer - dt
  if self.staticTimer <= 0 then
    self.staticTimer = 0.8
    fx.ring(self.x, self.y, STATIC_RADIUS, { 0.55, 0.8, 1 })
  end
  for _, e in ipairs(self.game:enemiesOf(self)) do
    local dx, dy = e.x - self.x, e.y - self.y
    local reach = STATIC_RADIUS + e.r
    if dx * dx + dy * dy < reach * reach and e.invuln <= 0 and not e:isBlocking() then
      e.hp = e.hp - s.static * dt
      if e.hp <= 0 then e:die() end
    end
  end
end

-- Sentry: a turret that shoots the nearest visible enemy.
function Player:updateSentry(dt)
  local s, game = self.stats, self.game
  self.sentryTimer = self.sentryTimer - dt
  if self.sentryTimer > 0 then return end
  local sx, sy = self:sentryPos()
  local target = game:nearestEnemy(self, sx, sy, true)
  if not target then
    self.sentryTimer = 0.2
    return
  end
  self.sentryTimer = SENTRY_DELAY / (1 + 0.5 * (s.sentry - 1))
  local dx, dy = target.x - sx, target.y - sy
  local d = math.max(1, math.sqrt(dx * dx + dy * dy))
  local b = Bullet.new(self, sx, sy, dx / d * s.bulletSpeed, dy / d * s.bulletSpeed)
  b.damage = b.damage * 0.4
  b.r = math.max(2.5, b.r * 0.7)
  b.gravity = 0
  game:addBullet(b)
  fx.burst(sx, sy, self.color, 3, 100, 2)
end

-- A reload just finished.
function Player:reloaded()
  local s = self.stats
  if s.quickdraw > 0 then self.quickdrawReady = true end
  for i = 1, s.reloadNova do
    self:spawnBullet(i / s.reloadNova * math.pi * 2, 0.8, false)
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
    local wj = Player.WALL_JUMP
    self.vy = -s.jump * wj.up
    self.vx = -self.wallDir * s.speed * wj.push
    self.facing = -self.wallDir
    self.controlLock = wj.lock
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
  if s.blockReload > 0 then
    -- Extra Supply Drops overfill the magazine.
    self.ammo = math.max(self.ammo, s.ammo + s.blockReload - 1)
    self.reloadTimer = 0
  end
  if s.empower > 0 then
    self.empowered = true
    self.empowerShots = s.empower
  end
  if s.cloak > 0 then self.cloakTimer = s.cloak end
  if s.blink > 0 then self:blink(s.blink) end
  if s.sprintBlock > 0 then self.sprintTimer = 2 end
  if s.lockLoad > 0 then self.freeAmmo = 1.5 + (s.lockLoad - 1) end
  if s.timeWarp > 0 then
    self.warpTimer = 1.5 + (s.timeWarp - 1)
    fx.ring(self.x, self.y, 140, { 0.65, 0.5, 1 })
  end
  if s.gravityBlock > 0 then
    local mult = 1 + 0.3 * (s.gravityBlock - 1)
    table.insert(game.wells, {
      x = self.x, y = self.y, t = 1.4, max = 1.4, owner = self, radius = 280 * mult, strength = 3200 * mult,
    })
  end
  for i = 1, s.mineLayer do
    local m = Bullet.new(self, self.x + (i - (s.mineLayer + 1) / 2) * 22, self.y + self.r - 6, 0, 0)
    m.laser = false
    m:becomeMine()
    m.armTime = 0.8
    game:addBullet(m)
  end

  if s.shockwave > 0 then
    fx.ring(self.x, self.y, SHOCKWAVE_RADIUS, self.color)
    fx.addShake(6)
    for _, e in ipairs(game:enemiesOf(self)) do
      local dx, dy = e.x - self.x, e.y - self.y
      local reach = SHOCKWAVE_RADIUS + e.r
      if dx * dx + dy * dy < reach * reach then e:hit(15 * s.shockwave, dx, dy, 650, self) end
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
  if s.spinup > 0 then
    self.spin = math.min(1, self.spin + 0.12 * s.spinup)
    delay = delay / (1 + 2 * self.spin)
  end
  if self:adrenalineActive() then delay = delay / (1 + 0.4 * s.adrenaline) end

  -- One-shot damage bonuses for this volley.
  local mult = 1
  local free = self.freeAmmo > 0 -- Lock and Load
  if s.lastRound > 0 and self.ammo == 1 and not free then mult = mult * (1 + s.lastRound) end
  if self.quickdrawReady then
    mult = mult * (1 + 0.5 * s.quickdraw)
    self.quickdrawReady = false
  end
  if self.spiteReady and s.spite > 0 then
    mult = mult * (1 + 0.6 * s.spite)
    self.spiteReady = false
  end

  if not free then self.ammo = self.ammo - 1 end
  self.fireTimer = delay
  self.sinceShot = 0
  self.reloadTimer = (self.ammo == 0) and s.reloadTime or 0

  self:volley(true, mult)
  if s.burst > 0 then
    self.burstLeft = s.burst
    self.burstTimer = 0.09
  end
end

-- Fire one volley (all pellets). Echo repeats call this with primary = false.
-- mult: one-shot damage multiplier (Last Round, Quickdraw, Spite).
function Player:volley(primary, mult)
  local s = self.stats
  local empowered = primary and self.empowered
  if empowered then
    self.empowerShots = self.empowerShots - 1
    self.empowered = self.empowerShots > 0
  end

  local base = math.atan2(self.aimY, self.aimX)
  for i = 1, s.bullets do
    local t = s.bullets > 1 and ((i - 1) / (s.bullets - 1) - 0.5) or 0
    local ang = base + t * s.spread + (love.math.random() - 0.5) * s.spread * 0.3
    local speedMul = s.bullets > 1 and (0.9 + love.math.random() * 0.2) or 1
    self:spawnBullet(ang, speedMul, empowered, mult)
  end
  for i = 1, s.backShot do
    self:spawnBullet(base + math.pi + (i - (s.backShot + 1) / 2) * 0.18, 1, empowered, mult)
  end

  fx.burst(self.x + self.aimX * (self.r + 12), self.y + self.aimY * (self.r + 12), { 1, 0.95, 0.7 }, 4, 150, 2)

  if s.recoil > 0 then
    if self.aimY > 0 and self.vy > 0 then self.vy = 0 end
    self.vx = self.vx - self.aimX * s.recoil
    self.vy = self.vy - self.aimY * s.recoil
    self.controlLock = math.max(self.controlLock, 0.12)
  end
end

function Player:spawnBullet(ang, speedMul, empowered, mult)
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
  if mult and mult ~= 1 then b.damage = b.damage * mult end
  if s.momentum > 0 then
    local frac = math.min(1, math.abs(self.vx) / math.max(1, s.speed))
    b.damage = b.damage * (1 + 0.5 * s.momentum * frac)
  end
  if s.crit > 0 and love.math.random() < s.crit then b:makeCrit() end
  game:addBullet(b)
  if s.mirror > 0 then self:mirrorBullet(b) end
end

-- Mirror Shot: copies of a bullet from the mirrored side(s) of the arena.
local MIRRORS = { { true, false }, { false, true }, { true, true } }
function Player:mirrorBullet(b)
  local s, game = self.stats, self.game
  if s.mirror > 3 then b.damage = b.damage * (1 + 0.15 * (s.mirror - 3)) end
  for i = 1, math.min(3, s.mirror) do
    local c = b:clone()
    if MIRRORS[i][1] then c.x, c.vx = ARENA_W - c.x, -c.vx end
    if MIRRORS[i][2] then c.y, c.vy = ARENA_H - c.y, -c.vy end
    if not Map.hit(game.map.rects, c.x - c.r, c.y - c.r, c.r * 2, c.r * 2) then game:addBullet(c) end
  end
end

-- An attack hit our block. Parry recharges the block; extra copies also heal.
function Player:blocked()
  local s = self.stats
  if s.parry > 0 then
    self.blockCd = 0
    if s.parry > 1 then self:heal(10 * (s.parry - 1)) end
  end
end

-- Returns true if damage landed (false when blocked, invulnerable or already dead).
-- source: the player who caused it (for Thorns and Frostback), or nil.
function Player:hit(amount, dx, dy, knock, source)
  if self.dead then return false end
  if self:isBlocking() then
    fx.burst(self.x, self.y, { 1, 1, 1 }, 8, 200, 3)
    self:blocked()
    return false
  end
  if self.invuln > 0 then return false end

  local s = self.stats
  local taken = amount
  if s.armor > 0 then amount = math.max(amount * 0.25, amount - s.armor) end
  if self.shield > 0 then
    local absorbed = math.min(self.shield, amount)
    self.shield = self.shield - absorbed
    amount = amount - absorbed
    fx.burst(self.x, self.y, { 0.5, 0.8, 1 }, 6, 160, 3)
  end

  if s.decay > 0 then
    local duration = 4 + 2 * (s.decay - 1)
    table.insert(self.decay, { remaining = amount, rate = amount / duration })
  else
    self.hp = self.hp - amount
  end
  if s.spite > 0 then self.spiteReady = true end
  if source and source ~= self and not source.dead then
    if s.frostback > 0 then source.slowTimer = math.max(source.slowTimer, s.frostback) end
    if s.thorns > 0 and source.invuln <= 0 then
      source.hp = source.hp - taken * s.thorns
      source.hitFlash = 0.1
      if source.hp <= 0 then source:die() end
    end
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

  -- Last Stand: shrug off a lethal hit (not falling out of the arena).
  if (self.lastStandLeft or 0) > 0 and not outOfBounds then
    self.lastStandLeft = self.lastStandLeft - 1
    self.hp = 1
    self.poisonTimer = 0
    self.decay = {}
    self.invuln = 1
    fx.ring(self.x, self.y, 70, { 1, 1, 1 })
    fx.burst(self.x, self.y, { 1, 0.95, 0.6 }, 20, 300, 4)
    return
  end

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
        e:hit(60 * self.stats.martyr, dx, dy, 800, self)
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

  if s.stasis > 0 then
    local sr = Player.stasisRadius(s.stasis)
    love.graphics.setColor(0.6, 0.8, 1, 0.06 * A)
    love.graphics.circle("fill", self.x, self.y, sr)
    love.graphics.setColor(0.6, 0.8, 1, 0.15 * A)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", self.x, self.y, sr)
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

  -- Shield Generator bubble
  if (self.shield or 0) > 0 then
    love.graphics.setColor(0.5, 0.8, 1, (0.25 + 0.35 * math.min(1, self.shield / 60)) * A)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, r + 5)
  end

  -- Sentry turret
  if (s.sentry or 0) > 0 then
    local sx, sy = self:sentryPos()
    love.graphics.setColor(0.85, 0.85, 0.9, A)
    love.graphics.rectangle("fill", sx - 7, sy - 5, 14, 10, 3, 3)
    love.graphics.setColor(c[1], c[2], c[3], A)
    love.graphics.circle("fill", sx, sy, 3.5)
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
    local slots = math.max(s.ammo, self.ammo) -- Supply Drop can overfill
    local spacing = math.min(9, bw / math.max(1, slots))
    local startX = self.x - (slots - 1) * spacing / 2
    for i = 1, slots do
      love.graphics.setColor(1, 1, 1, (i <= self.ammo and 0.9 or 0.2) * A)
      love.graphics.circle("fill", startX + (i - 1) * spacing, py, 2.5)
    end
  end
end

return Player
