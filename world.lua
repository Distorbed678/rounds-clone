-- The authoritative match simulation (used for local play and by the online host).
-- Rendering and networking live in screens/match.lua; this file only runs the game.
local Player = require "player"
local Map = require "map"
local Cards = require "cards"
local fx = require "fx"

local World = {}
World.__index = World

World.COLORS = {
  { 1, 0.55, 0.15 },
  { 0.25, 0.6, 1 },
  { 0.35, 0.9, 0.4 },
  { 1, 0.4, 0.75 },
}
World.CONTINUE_ROUNDS = 3

-- Toast colour codes (also sent over the network): 0 white, 1-4 player slot, 5 legendary.
function World.toastColor(code)
  if code and code >= 1 and code <= 4 then return World.COLORS[code] end
  if code == 5 then return Cards.rarity.legendary.color end
  return { 1, 1, 1 }
end

-- defs: list of { name = string, input = input state, peer = optional network id }
function World.new(defs, winScore)
  local w = setmetatable({
    players = {}, bullets = {}, pending = {}, wells = {},
    state = "countdown", timer = 0,
    winScore = winScore,
    startScore = winScore,
    picks = {},
    on = {},
  }, World)
  for i, d in ipairs(defs) do
    local p = Player.new(i, World.COLORS[i], d.input)
    p.slot = i
    p.name = d.name
    p.peer = d.peer
    w.players[i] = p
  end
  return w
end

function World:emit(event, ...)
  local f = self.on[event]
  if f then f(...) end
end

function World:toast(text, colorCode)
  self:emit("toast", text, colorCode or 0)
end

function World:addBullet(b)
  table.insert(self.pending, b)
end

-- Living, connected players other than p.
function World:enemiesOf(p)
  local list = {}
  for _, e in ipairs(self.players) do
    if e ~= p and not e.dead then list[#list + 1] = e end
  end
  return list
end

function World:nearestEnemy(p, x, y, visibleOnly)
  local best, bestD
  for _, e in ipairs(self.players) do
    if e ~= p and not e.dead and not (visibleOnly and e.cloakTimer > 0) then
      local dx, dy = e.x - x, e.y - y
      local d = dx * dx + dy * dy
      if not bestD or d < bestD then best, bestD = e, d end
    end
  end
  return best
end

function World:startRound()
  self.map, self.mapIndex = Map.random(self.mapIndex)
  self.bullets = {}
  self.pending = {}
  self.wells = {}
  fx.clear()
  for i, p in ipairs(self.players) do
    local s = self.map.spawns[i]
    p:spawn(s[1], s[2], s[1] < 640 and 1 or -1, self)
    if p.disconnected then
      p.dead = true
      p.hp = 0
    end
  end
  self.picks = {}
  self.roundWinner = nil
  self.state = "countdown"
  self.timer = 2.4
  self:emit("roster")
end

function World:update(dt)
  if self.state == "countdown" then
    self.timer = self.timer - dt
    for _, p in ipairs(self.players) do p:update(dt, true) end
    if self.timer <= 0 then self.state = "playing" end
  elseif self.state == "playing" or self.state == "roundOver" then
    local sdt = (self.state == "roundOver") and dt * 0.35 or dt
    for _, p in ipairs(self.players) do p:update(sdt, false) end
    for i = #self.bullets, 1, -1 do
      local b = self.bullets[i]
      if not b.dead then b:update(sdt, self) end
      if b.dead then table.remove(self.bullets, i) end
    end
    for _, b in ipairs(self.pending) do table.insert(self.bullets, b) end
    self.pending = {}
    for i = #self.wells, 1, -1 do
      local w = self.wells[i]
      w.t = w.t - sdt
      if w.t <= 0 then table.remove(self.wells, i) end
    end
    if self.state == "playing" then
      self:checkRoundEnd()
    else
      self.timer = self.timer - dt
      if self.timer <= 0 then self:afterRound() end
    end
  end
end

function World:connectedCount()
  local n = 0
  for _, p in ipairs(self.players) do
    if not p.disconnected then n = n + 1 end
  end
  return n
end

function World:checkRoundEnd()
  local alive, last = 0, nil
  for _, p in ipairs(self.players) do
    if not p.dead and not p.disconnected then
      alive = alive + 1
      last = p
    end
  end
  if alive > 1 then return end
  self.roundWinner = last
  if last then last.score = last.score + 1 end
  self.state = "roundOver"
  self.timer = 1.6
end

function World:afterRound()
  if self.roundWinner and self.roundWinner.score >= self.winScore then
    self.state = "matchOver"
    self:emit("matchOver", self.roundWinner)
  else
    self:openPicks()
  end
end

-- Every connected player except the round winner picks a card. A draw skips picks.
function World:openPicks()
  if not self.roundWinner then return self:startRound() end
  self.picks = {}
  local any = false
  for i, p in ipairs(self.players) do
    if p ~= self.roundWinner and not p.disconnected then
      self.picks[i] = { options = Cards.deal(3, p), done = false }
      any = true
    end
  end
  if not any then return self:startRound() end
  self.state = "cardPick"
  for i, pk in pairs(self.picks) do self:emit("pick", i, pk.options) end
end

function World:pendingPickers()
  local list = {}
  for i = 1, #self.players do
    local pk = self.picks[i]
    if pk and not pk.done then list[#list + 1] = i end
  end
  return list
end

function World:choose(slot, optionIndex)
  if self.state ~= "cardPick" then return end
  local pk = self.picks[slot]
  if not pk or pk.done then return end
  local card = pk.options[optionIndex]
  if not card then return end
  local p = self.players[slot]

  if card.special == "reroll" then
    pk.options = Cards.deal(3, p)
    self:emit("pick", slot, pk.options)
    return
  elseif card.special == "tableflip" then
    self:toast(Cards.tableFlip(p), slot)
  elseif card.special == "shrine" then
    self:toast(Cards.shrine(p), 5)
  else
    p:addCard(card)
  end
  pk.done = true
  self:emit("roster")
  if #self:pendingPickers() == 0 then self:startRound() end
end

function World:continueMatch()
  if self.state ~= "matchOver" then return end
  self.winScore = self.winScore + World.CONTINUE_ROUNDS
  self:toast("CONTINUE! First to " .. self.winScore)
  self:openPicks()
end

function World:newMatch()
  for _, p in ipairs(self.players) do
    p.cards = {}
    p.score = 0
    p:recompute()
  end
  self.winScore = self.startScore
  self.mapIndex = nil
  self:startRound()
end

-- A network player left: they sit out the rest of the match.
function World:disconnect(slot)
  local p = self.players[slot]
  if not p or p.disconnected then return end
  p.disconnected = true
  if not p.dead then
    fx.burst(p.x, p.y, p.color, 30, 300, 5)
    p.dead = true
    p.hp = 0
  end
  if self.picks[slot] then self.picks[slot].done = true end
  if self.state == "cardPick" and #self:pendingPickers() == 0 then self:startRound() end
end

return World
