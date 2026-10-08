-- The match screen. Three roles:
--   "local"  : 2 players on one keyboard, simulated here.
--   "host"   : online host; simulates the World, applies remote inputs, broadcasts snapshots.
--   "client" : online client; sends input, renders snapshots from the host.
local app = require "app"
local ui = require "ui"
local World = require "world"
local Player = require "player"
local Bullet = require "bullet"
local Map = require "map"
local Cards = require "cards"
local Input = require "input"
local Bloom = require "bloom"
local fx = require "fx"
local net = require "net"
local Snap = require "snapshot"
local hud = require "hud"
local session = require "session"

local Match = {}
Match.__index = Match

local SNAPSHOT_INTERVAL = 1 / 30
local LOCAL_HINTS = {
  "A / D to choose, SPACE to take",
  "LEFT / RIGHT to choose, RIGHT CTRL to take",
}

local function newMatch(role)
  return setmetatable({
    role = role,
    paused = false,
    toasts = {},
    picks = {},     -- slot -> { options, index, delay, waiting } for pickers on this machine
  }, Match)
end

---------------------------------------------------------------- construction
function Match.newLocal(winScore)
  local m = newMatch("local")
  m.inputs = { Input.keys(Input.LOCAL_CONTROLS[1]), Input.keys(Input.LOCAL_CONTROLS[2]) }
  m.world = World.new({
    { name = "Player 1", input = m.inputs[1] },
    { name = "Player 2", input = m.inputs[2] },
  }, winScore)
  m:hookWorld()
  fx.recorder = nil
  m.world:startRound()
  return m
end

-- slots[1] is the host. opts.popEvents overrides the session event source (tests).
function Match.newHost(slots, winScore, transport, opts)
  opts = opts or {}
  local m = newMatch("host")
  m.transport = transport
  m.popEvents = opts.popEvents or session.popEvents
  m.myInput = Input.mouse()
  m.mySlot = 1
  m.peers = {}
  local defs = {}
  for i, s in ipairs(slots) do
    local input = (i == 1) and m.myInput or Input.remote()
    defs[i] = { name = s.name, input = input, peer = s.peer }
    if i > 1 then m.peers[s.peer] = { slot = i, seq = -1 } end
  end
  m.world = World.new(defs, winScore)
  m:hookWorld()
  m.snapTimer = 0
  fx.recorder = {}
  m.world:startRound()
  return m
end

function Match.newClient(slots, mySlot, winScore, transport, hostPeer, pending, opts)
  opts = opts or {}
  local m = newMatch("client")
  m.transport = transport
  m.popEvents = opts.popEvents or session.popEvents
  m.hostPeer = hostPeer
  m.mySlot = mySlot
  m.myInput = Input.mouse()
  m.inputSeq = 0
  m.pending = pending
  m.view = { state = "countdown", timer = 0, winScore = winScore, mapIndex = 1, winner = 0, picking = 0 }
  m.proxies = {}
  for i, s in ipairs(slots) do m.proxies[i] = m:newProxy(i, s.name) end
  m.bulletViews, m.bulletList, m.wellList = {}, {}, {}
  m.snapTime = love.timer.getTime()
  fx.recorder = nil
  fx.clear()
  return m
end

function Match:leave()
  self.closed = true
  fx.recorder = nil
  fx.clear()
  love.mouse.setVisible(true)
end

---------------------------------------------------------------- helpers
function Match:showToast(text, code)
  table.insert(self.toasts, { text = text, color = World.toastColor(code), t = 3.5 })
  if #self.toasts > 3 then table.remove(self.toasts, 1) end
end

function Match:broadcast(data, reliable)
  for peer, info in pairs(self.peers) do
    if not info.gone then self.transport:send(peer, data, reliable) end
  end
end

function Match:hookWorld()
  local w = self.world
  w.on.toast = function(text, code)
    self:showToast(text, code)
    if self.role == "host" then self:broadcast(net.encodeToast(text, code), true) end
  end
  w.on.roster = function()
    if self.role == "host" then self:broadcast(net.encodeRoster(w.players), true) end
  end
  w.on.pick = function(slot, options)
    if self.role == "local" or slot == self.mySlot then
      self.picks[slot] = { options = options, index = 2, delay = 0.4 }
    else
      self.transport:send(w.players[slot].peer, net.encodePick(slot, options), true)
    end
  end
  w.on.matchOver = function() ui.reset() end
end

-- What to draw and the round status, for any role.
function Match:scene()
  if self.role == "client" then
    return self.proxies, self.bulletList, self.wellList, Map.list[self.view.mapIndex] or Map.list[1]
  end
  local w = self.world
  return w.players, w.bullets, w.wells, w.map
end

function Match:status()
  if self.role == "client" then
    local v = self.view
    local pickers = {}
    for i = 1, #self.proxies do
      if math.floor(v.picking / 2 ^ (i - 1)) % 2 == 1 then pickers[#pickers + 1] = i end
    end
    return {
      state = v.state, timer = v.timer, winScore = v.winScore,
      winner = v.winner > 0 and self.proxies[v.winner] or nil, pickers = pickers,
    }
  end
  local w = self.world
  return { state = w.state, timer = w.timer, winScore = w.winScore, winner = w.roundWinner, pickers = w:pendingPickers() }
end

function Match:players()
  return self.role == "client" and self.proxies or self.world.players
end

-- The pick shown on this machine (local: lowest pending slot; online: our own).
function Match:activePick()
  if self.role == "local" then
    for slot = 1, 4 do
      if self.picks[slot] then return self.picks[slot], slot end
    end
    return nil
  end
  return self.picks[self.mySlot], self.mySlot
end

function Match:choosePick(slot, index)
  local pk = self.picks[slot]
  if not pk or pk.delay > 0 or pk.waiting then return end
  if self.role == "client" then
    pk.waiting = true
    self.transport:send(self.hostPeer, net.encodeChoose(index), true)
  else
    self.picks[slot] = nil
    self.world:choose(slot, index) -- a Reroll re-deals through w.on.pick
  end
end

function Match:prunePicks()
  for slot in pairs(self.picks) do
    local wp = self.world.picks[slot]
    if not wp or wp.done or self.world.state ~= "cardPick" then self.picks[slot] = nil end
  end
end

---------------------------------------------------------------- client side
function Match:newProxy(slot, name)
  return setmetatable({
    id = slot, slot = slot, name = name, color = World.COLORS[slot],
    cards = {}, score = 0,
    stats = { maxHp = 100, ammo = 3, reloadTime = 1, blockCooldown = 1, orbs = 0, stasis = false },
    decay = { { remaining = 0 } },
    x = -1000, y = -1000, r = 20, aimX = 1, aimY = 0, facing = 1,
    hp = 100, ammo = 3, reloadTimer = 0, blockTimer = 0, blockCd = 0,
    cloakTimer = 0, invuln = 0, poisonTimer = 0, slowTimer = 0,
    empowered = false, hitFlash = 0, livesLeft = 0, orbAngle = 0, dead = true,
  }, Player)
end

function Match:applySnapshot(v)
  local now = love.timer.getTime()
  local view = self.view
  view.state, view.timer, view.winScore = v.state, v.timer, v.winScore
  view.mapIndex, view.winner, view.picking = v.mapIndex, v.winner, v.picking

  for i, pv in ipairs(v.players) do
    local p = self.proxies[i]
    if not p then
      p = self:newProxy(i, "Player " .. i)
      self.proxies[i] = p
    end
    local jump = math.abs(pv.x - p.x) + math.abs(pv.y - p.y) > 250
    if p.dead or pv.dead or jump then
      p.fromX, p.fromY = pv.x, pv.y
    else
      p.fromX, p.fromY = p.x, p.y
    end
    p.toX, p.toY = pv.x, pv.y
    p.aimX, p.aimY = math.cos(pv.aim), math.sin(pv.aim)
    p.facing = pv.facing
    p.hp = pv.hp
    p.r = pv.r
    p.dead = pv.dead
    p.blockTimer = pv.blocking and 1 or 0
    p.empowered = pv.empowered
    p.poisonTimer = pv.poisoned and 1 or 0
    p.slowTimer = pv.slowed and 1 or 0
    p.cloakTimer = pv.cloaked and 1 or 0
    p.hitFlash = pv.hitFlash and 0.1 or 0
    p.invuln = pv.invuln
    p.ammo = pv.ammo
    p.reloadTimer = pv.reload / 255
    p.blockCd = pv.blockCd / 255
    p.orbAngle = pv.orbAngle
    p.livesLeft = pv.lives
    p.decay[1].remaining = pv.pending
    p.score = pv.score
    local s = p.stats
    s.maxHp, s.ammo, s.orbs, s.stasis = pv.maxHp, pv.maxAmmo, pv.orbs, pv.stasis
  end

  local views, list = {}, {}
  for _, bv in ipairs(v.bullets) do
    local b = self.bulletViews[bv.id] or setmetatable({ trail = {}, life = 6 }, Bullet)
    b.id = bv.id
    b.baseX, b.baseY = bv.x, bv.y
    b.x, b.y = bv.x, bv.y
    b.vx, b.vy = bv.vx, bv.vy
    b.r = bv.r
    b.color = bv.colorIdx == 5 and Bullet.CRIT_COLOR or (World.COLORS[bv.colorIdx] or { 1, 1, 1 })
    b.ghost, b.mine, b.laser = bv.ghost, bv.mine, bv.laser
    b.armTime = bv.armed and 0 or 1
    if bv.laser then
      b.points = bv.points
      b.beam = bv.beam
    end
    views[bv.id] = b
    list[#list + 1] = b
  end
  self.bulletViews, self.bulletList = views, list

  self.wellList = {}
  for _, w in ipairs(v.wells) do
    self.wellList[#self.wellList + 1] = {
      x = w.x, y = w.y, t = w.t, max = w.max,
      owner = { color = World.COLORS[w.slot] or { 1, 1, 1 } },
    }
  end

  for _, e in ipairs(v.fx) do
    if e[1] == 1 then
      fx.burst(e[2], e[3], e[4], e[5], e[6], e[7])
    elseif e[1] == 2 then
      fx.ring(e[2], e[3], e[4], e[5])
    elseif e[1] == 3 then
      fx.addShake(e[2])
    else
      fx.clear()
    end
  end

  -- Our pick is finished once the host no longer lists us as picking.
  if math.floor(v.picking / 2 ^ (self.mySlot - 1)) % 2 == 0 then self.picks[self.mySlot] = nil end
  self.snapTime = now
end

function Match:clientInterpolate(dt)
  local t = math.min(1, (love.timer.getTime() - self.snapTime) / SNAPSHOT_INTERVAL)
  for _, p in ipairs(self.proxies) do
    if p.toX then
      p.x = p.fromX + (p.toX - p.fromX) * t
      p.y = p.fromY + (p.toY - p.fromY) * t
    end
    p.hitFlash = math.max(0, p.hitFlash - dt)
  end
  local age = love.timer.getTime() - self.snapTime
  for _, b in ipairs(self.bulletList) do
    if not b.mine and not b.laser then
      b.x = b.baseX + b.vx * math.min(age, 0.1)
      b.y = b.baseY + b.vy * math.min(age, 0.1)
      table.insert(b.trail, 1, { b.x, b.y })
      if #b.trail > 6 then table.remove(b.trail) end
    end
    b.life = b.life - dt
  end
end

function Match:clientNetwork()
  local msgs = self.transport:receive()
  if self.pending then
    for i = #self.pending, 1, -1 do table.insert(msgs, 1, self.pending[i]) end
    self.pending = nil
  end
  for _, msg in ipairs(msgs) do
    if msg.from == self.hostPeer then
      local kind = net.kind(msg.data)
      if kind == net.MSG.SNAPSHOT then
        local ok, v = pcall(Snap.decode, msg.data)
        if ok then self:applySnapshot(v) end
      elseif kind == net.MSG.ROSTER then
        for i, r in ipairs(net.decodeRoster(msg.data)) do
          local p = self.proxies[i]
          if p then
            p.disconnected = r.disconnected
            p.cards = {}
            for k, idx in ipairs(r.cards) do p.cards[k] = Cards.list[idx] end
          end
        end
      elseif kind == net.MSG.PICK then
        local slot, ids = net.decodePick(msg.data)
        if slot == self.mySlot then
          local options = {}
          for k, idx in ipairs(ids) do options[k] = Cards.list[idx] end
          self.picks[slot] = { options = options, index = 2, delay = 0.3 }
        end
      elseif kind == net.MSG.TOAST then
        self:showToast(net.decodeToast(msg.data))
      elseif kind == net.MSG.TOLOBBY then
        app.switch(require("screens.lobby").new())
        return
      end
    end
  end

  for _, ev in ipairs(self.popEvents()) do
    if ev.type == "hostLeft" then
      session.leave()
      app.switch(require("screens.menu").new("The host left the game"))
      return
    end
  end
end

---------------------------------------------------------------- host side
local scratch = Input.remote()

function Match:hostNetwork(dt)
  for _, msg in ipairs(self.transport:receive()) do
    local info = self.peers[msg.from]
    if info and not info.gone then
      local kind = net.kind(msg.data)
      if kind == net.MSG.INPUT then
        local seq = net.decodeInput(msg.data, scratch)
        if seq > info.seq then
          info.seq = seq
          local inp = self.world.players[info.slot].input
          for _, k in ipairs({ "left", "right", "down", "fire", "jumpHeld", "aim", "jumpCount", "blockCount" }) do
            inp[k] = scratch[k]
          end
        end
      elseif kind == net.MSG.CHOOSE then
        self.world:choose(info.slot, net.decodeChoose(msg.data))
      end
    end
  end

  for _, ev in ipairs(self.popEvents()) do
    if ev.type == "left" and self.peers[ev.id] and not self.peers[ev.id].gone then
      local info = self.peers[ev.id]
      info.gone = true
      local p = self.world.players[info.slot]
      self.world:disconnect(info.slot)
      self.world:toast((p.name or "A player") .. " left the game", info.slot)
      self.world:emit("roster")
      if self.world:connectedCount() < 2 then
        self:backToLobby("Everyone else left the game")
        return
      end
    end
  end

  self.snapTimer = self.snapTimer - dt
  if self.snapTimer <= 0 then
    self.snapTimer = SNAPSHOT_INTERVAL
    local data = Snap.encode(self.world, fx.recorder)
    fx.recorder = {}
    self:broadcast(data, false)
  end
end

function Match:backToLobby(message)
  if self.role == "host" then
    self:broadcast(net.encodeToLobby(), true)
    session.setJoinable(true)
  end
  app.switch(require("screens.lobby").new(message))
end

---------------------------------------------------------------- update
function Match:update(dt, isTop)
  local suppressed = self.paused or not isTop
  fx.update(dt)
  for i = #self.toasts, 1, -1 do
    local t = self.toasts[i]
    t.t = t.t - dt
    if t.t <= 0 then table.remove(self.toasts, i) end
  end
  for _, pk in pairs(self.picks) do pk.delay = math.max(0, pk.delay - dt) end

  local mx, my = app.mouse()
  if self.role == "local" then
    for _, inp in ipairs(self.inputs) do Input.poll(inp, suppressed) end
    if not self.paused then self.world:update(dt) end
    self:prunePicks()
  elseif self.role == "host" then
    local me = self.world.players[1]
    Input.poll(self.myInput, suppressed, me.x, me.y, mx, my)
    self.world:update(dt)
    self:prunePicks()
    self:hostNetwork(dt)
  else
    self:clientNetwork()
    if self.closed then return end -- switched to the lobby/menu
    local me = self.proxies[self.mySlot]
    Input.poll(self.myInput, suppressed, me.x, me.y, mx, my)
    self.inputSeq = self.inputSeq + 1
    self.transport:send(self.hostPeer, net.encodeInput(self.myInput, self.inputSeq), false)
    self:clientInterpolate(dt)
  end

  if self.role ~= "local" then
    local st = self:status().state
    local playing = isTop and not self.paused and (st == "countdown" or st == "playing" or st == "roundOver")
    love.mouse.setVisible(not playing)
  end
end

---------------------------------------------------------------- input
function Match:keypressed(key)
  if key == "escape" then
    self.paused = not self.paused
    ui.reset()
    return
  end
  if self.paused then return end

  local pk, slot = self:activePick()
  if pk then
    local keys = self.role == "local" and Input.LOCAL_CONTROLS[slot] or { left = "a", right = "d", fire = "space" }
    local n = #pk.options
    if key == keys.left or (self.role ~= "local" and key == "left") then
      pk.index = (pk.index - 2) % n + 1
    elseif key == keys.right or (self.role ~= "local" and key == "right") then
      pk.index = pk.index % n + 1
    elseif key == keys.fire or (self.role ~= "local" and key == "return") then
      self:choosePick(slot, pk.index)
    end
    return
  end

  if self.role == "local" then
    for _, inp in ipairs(self.inputs) do Input.keypressed(inp, key) end
    if key == "r" and self.world.state == "matchOver" then self.world:newMatch() end
  else
    Input.keypressed(self.myInput, key)
  end
end

function Match:mousepressed(x, y, button)
  if self.paused then return end
  local pk, slot = self:activePick()
  if pk then
    if button == 1 then
      for i, r in ipairs(hud.cardRects(#pk.options, pk.index)) do
        if x >= r[1] and x <= r[1] + r[3] and y >= r[2] and y <= r[2] + r[4] then
          pk.index = i
          self:choosePick(slot, i)
        end
      end
    end
    return
  end
  if self.role ~= "local" then Input.mousepressed(self.myInput, button) end
end

---------------------------------------------------------------- drawing
function Match:drawCardPick(st)
  love.graphics.setColor(0, 0, 0, 0.75)
  love.graphics.rectangle("fill", 0, 0, app.W, app.H)

  local pk, slot = self:activePick()
  local players = self:players()
  if not pk then
    local names = {}
    for _, i in ipairs(st.pickers) do names[#names + 1] = players[i] and players[i].name or ("Player " .. i) end
    app.centered("Waiting for " .. table.concat(names, ", ") .. " to pick a card...", app.fonts.title, 320, { 1, 1, 1, 0.8 })
    return
  end

  local p = players[slot]
  local title = self.role == "local" and ((p.name or "Player"):upper() .. " - PICK A CARD") or "PICK A CARD"
  app.centered(title, app.fonts.big, 90, p.color)
  local hint = self.role == "local" and LOCAL_HINTS[slot]
    or "Click a card  -  or A / D and SPACE"
  if pk.waiting then hint = "Waiting for the host..." end
  app.centered(hint, app.fonts.med, 140, { 1, 1, 1, 0.7 })

  -- Mouse hover selects (online, and local player 1 can use the mouse too).
  local mx, my = app.mouse()
  local rects = hud.cardRects(#pk.options, pk.index)
  if ui.mouseMoved then
    for i, r in ipairs(rects) do
      if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then pk.index = i end
    end
    rects = hud.cardRects(#pk.options, pk.index)
  end
  for i, card in ipairs(pk.options) do
    local r = rects[i]
    hud.drawCard(card, r[1], r[2], r[3], r[4], i == pk.index, p.color)
  end
end

function Match:drawMatchOver(st)
  love.graphics.setColor(0, 0, 0, 0.7)
  love.graphics.rectangle("fill", 0, 0, app.W, app.H)
  local winner = st.winner
  if winner then
    app.centered((winner.name or "Player"):upper() .. " WINS!", app.fonts.huge, 150, winner.color)
  end
  local scores = {}
  for _, p in ipairs(self:players()) do scores[#scores + 1] = tostring(p.score) end
  app.centered(table.concat(scores, "  -  "), app.fonts.big, 280)

  if self.role == "client" then
    app.centered("Waiting for the host to continue...", app.fonts.med, 400, { 1, 1, 1, 0.7 })
    return
  end
  local x, w, h = app.W / 2 - 220, 440, 52
  local nextScore = st.winScore + World.CONTINUE_ROUNDS
  if ui.button("Continue  (+" .. World.CONTINUE_ROUNDS .. " rounds, first to " .. nextScore .. ")", x, 370, w, h) then
    self.world:continueMatch()
  end
  if ui.button("New Match", x, 432, w, h) then self.world:newMatch() end
  if self.role == "host" then
    if ui.button("Back to Lobby", x, 494, w, h) then self:backToLobby() end
  else
    if ui.button("Main Menu", x, 494, w, h) then app.switch(require("screens.menu").new()) end
  end
end

function Match:drawPause()
  love.graphics.setColor(0, 0, 0, 0.6)
  love.graphics.rectangle("fill", 0, 0, app.W, app.H)
  local buttons = self.role == "host" and 4 or 3
  local pw, ph = 420, 120 + buttons * 62
  local px, py = (app.W - pw) / 2, (app.H - ph) / 2
  ui.panel(px, py, pw, ph)
  love.graphics.setFont(app.fonts.big)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf(self.role == "local" and "PAUSED" or "MENU", px, py + 22, pw, "center")
  if self.role ~= "local" then
    love.graphics.setFont(app.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.printf("The game keeps running online", px, py + 66, pw, "center")
  end

  local bx, bw, bh = px + 50, pw - 100, 50
  local y = py + 100
  if ui.button("Resume", bx, y, bw, bh) then self.paused = false end
  y = y + 62
  if ui.button("Settings", bx, y, bw, bh) then app.push(require("screens.settings").new()) end
  y = y + 62
  if self.role == "local" then
    if ui.button("Main Menu", bx, y, bw, bh) then app.switch(require("screens.menu").new()) end
  elseif self.role == "host" then
    if ui.button("Back to Lobby (everyone)", bx, y, bw, bh) then self:backToLobby() end
    y = y + 62
    if ui.button("Leave Lobby", bx, y, bw, bh) then
      session.leave()
      app.switch(require("screens.menu").new())
    end
  else
    if ui.button("Leave Lobby", bx, y, bw, bh) then
      session.leave()
      app.switch(require("screens.menu").new())
    end
  end
end

function Match:draw()
  local players, bullets, wells, map = self:scene()
  if not map then return end
  local st = self:status()

  local sx, sy = 0, 0
  if fx.shake > 0 then
    sx, sy = (love.math.random() - 0.5) * fx.shake * 2, (love.math.random() - 0.5) * fx.shake * 2
  end

  love.graphics.push()
  love.graphics.translate(sx, sy)
  Map.draw(map)
  hud.drawWells(wells)
  for _, b in ipairs(bullets) do b:draw() end
  for _, p in ipairs(players) do p:draw() end
  fx.draw()
  love.graphics.pop()

  Bloom.draw(function()
    love.graphics.translate(sx, sy)
    for _, b in ipairs(bullets) do b:draw() end
    for _, p in ipairs(players) do p:drawGlow() end
    fx.draw()
  end, app.canvas)

  hud.drawScores(players, st.winScore)
  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(1, 1, 1, 0.3)
  love.graphics.printf(map.name .. "   -   First to " .. st.winScore, 0, app.H - 24, app.W, "center")

  for i, t in ipairs(self.toasts) do
    local c = t.color
    app.centered(t.text, app.fonts.med, 92 + i * 26, { c[1], c[2], c[3], math.min(1, t.t) })
  end

  if st.state == "countdown" then
    app.centered(tostring(math.max(1, math.ceil(st.timer / 0.8))), app.fonts.huge, 250, { 1, 1, 1, 0.9 })
  elseif st.state == "roundOver" then
    if st.winner then
      app.centered((st.winner.name or "Player"):upper() .. " WINS THE ROUND", app.fonts.big, 280, st.winner.color)
    else
      app.centered("DRAW", app.fonts.big, 280)
    end
  elseif st.state == "cardPick" then
    self:drawCardPick(st)
  elseif st.state == "matchOver" then
    self:drawMatchOver(st)
  end

  if self.paused then
    self:drawPause()
  elseif self.role ~= "local" and (st.state == "countdown" or st.state == "playing" or st.state == "roundOver") then
    local mx, my = app.mouse()
    local me = players[self.mySlot]
    hud.drawCrosshair(mx, my, me and me.color or { 1, 1, 1 })
  end
end

return Match
