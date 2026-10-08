-- The Steam lobby: members, lobby code, invites, and the host's Start button.
local app = require "app"
local ui = require "ui"
local steam = require "steam"
local session = require "session"
local Settings = require "settings"
local World = require "world"
local net = require "net"

local Lobby = {}
Lobby.__index = Lobby

function Lobby.new(message)
  return setmetatable({ message = message, friends = {}, friendTimer = 0, copied = 0 }, Lobby)
end

function Lobby:enter()
  love.mouse.setVisible(true)
  self.friends = session.friendsOnline()
  self.invited = {}
end

local function toMenu(message)
  session.leave()
  app.switch(require("screens.menu").new(message))
end

function Lobby:keypressed(key)
  if key == "escape" then toMenu() end
end

function Lobby:start()
  local slots = {}
  for i, m in ipairs(session.members) do
    if i > session.MAX_PLAYERS then break end
    slots[i] = { peer = m.id, name = m.name }
  end
  local data = net.encodeStart(session.rounds, slots)
  for i = 2, #slots do session.transport:send(slots[i].peer, data, true) end
  session.setJoinable(false)
  app.switch(require("screens.match").newHost(slots, session.rounds, session.transport))
end

function Lobby:update(dt)
  if not session.inLobby() then
    app.switch(require("screens.menu").new(session.error or "You left the lobby"))
    return
  end

  for _, ev in ipairs(session.popEvents()) do
    if ev.type == "hostLeft" and not session.isHost then
      toMenu("The host closed the lobby")
      return
    end
  end

  local msgs = session.popMessages()
  for i, msg in ipairs(msgs) do
    if not session.isHost and msg.from == session.hostId and net.kind(msg.data) == net.MSG.START then
      local winScore, slots = net.decodeStart(msg.data)
      local me = steam.myId()
      local mySlot
      for k, s in ipairs(slots) do
        if s.peer == me then mySlot = k end
      end
      if mySlot then
        -- Hand any messages that arrived right after START to the match.
        local rest = {}
        for k = i + 1, #msgs do rest[#rest + 1] = msgs[k] end
        app.switch(require("screens.match").newClient(slots, mySlot, winScore, session.transport, msg.from, rest))
        return
      end
    end
  end

  self.friendTimer = self.friendTimer + dt
  if self.friendTimer > 5 then
    self.friendTimer = 0
    self.friends = session.friendsOnline()
  end
  self.copied = math.max(0, self.copied - dt)
end

-- "First to 5  -  pick 1 of 3 cards" (the host's rules, from the lobby data).
function Lobby.rulesText()
  local picks = session.picks > 1 and (session.picks .. " picks of ") or "pick 1 of "
  return "First to " .. session.rounds .. "  -  " .. picks .. session.pickFrom .. " cards"
end

function Lobby:draw()
  app.centered("LOBBY", app.fonts.big, 28)

  -- Players
  local lx, ly, lw, lh = 60, 90, 560, 380
  ui.panel(lx, ly, lw, lh)
  love.graphics.setFont(app.fonts.title)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print("Players  " .. #session.members .. " / " .. session.MAX_PLAYERS, lx + 24, ly + 18)
  local me = steam.myId()
  for i = 1, session.MAX_PLAYERS do
    local m = session.members[i]
    local ry = ly + 70 + (i - 1) * 74
    local c = World.COLORS[i]
    love.graphics.setColor(0.17, 0.17, 0.22)
    love.graphics.rectangle("fill", lx + 20, ry, lw - 40, 60, 10, 10)
    if m then
      love.graphics.setColor(c)
      love.graphics.circle("fill", lx + 56, ry + 30, 18)
      love.graphics.setColor(0.1, 0.1, 0.12)
      love.graphics.circle("fill", lx + 52, ry + 26, 2.5)
      love.graphics.circle("fill", lx + 62, ry + 26, 2.5)
      love.graphics.setFont(app.fonts.title)
      love.graphics.setColor(1, 1, 1)
      love.graphics.print(m.name, lx + 90, ry + 15)
      local tags = {}
      if m.id == session.hostId then tags[#tags + 1] = "HOST" end
      if m.id == me then tags[#tags + 1] = "YOU" end
      love.graphics.setFont(app.fonts.small)
      love.graphics.setColor(c)
      love.graphics.printf(table.concat(tags, "  "), lx + 20, ry + 22, lw - 60, "right")
    else
      love.graphics.setFont(app.fonts.med)
      love.graphics.setColor(1, 1, 1, 0.3)
      love.graphics.print("Waiting for player...", lx + 90, ry + 19)
    end
  end

  -- Code + invites
  local rx, ry, rw, rh = 660, 90, 560, 380
  ui.panel(rx, ry, rw, rh)
  love.graphics.setFont(app.fonts.med)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.printf("Lobby code", rx, ry + 16, rw, "center")
  love.graphics.setFont(app.fonts.huge)
  love.graphics.setColor(1, 0.85, 0.4)
  love.graphics.printf(session.code or "------", rx, ry + 34, rw, "center")

  local bw = (rw - 60) / 2
  if ui.button(self.copied > 0 and "Copied!" or "Copy Code", rx + 20, ry + 150, bw, 46) then
    love.system.setClipboardText(session.code or "")
    self.copied = 1.5
  end
  if ui.button("Steam Invite...", rx + 40 + bw, ry + 150, bw, 46) then
    session.openInviteDialog()
  end

  love.graphics.setFont(app.fonts.med)
  love.graphics.setColor(1, 1, 1, 0.6)
  love.graphics.print("Friends online", rx + 24, ry + 210)
  if #self.friends == 0 then
    love.graphics.setFont(app.fonts.small)
    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.print("No friends online right now", rx + 24, ry + 240)
  end
  for i = 1, math.min(#self.friends, 4) do
    local f = self.friends[i]
    local fy = ry + 238 + (i - 1) * 34
    love.graphics.setFont(app.fonts.med)
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print(f.name, rx + 24, fy + 4)
    local sent = self.invited[f.id]
    if ui.button(sent and "Sent" or "Invite", rx + rw - 130, fy, 106, 30, { font = app.fonts.small, disabled = sent }) then
      session.invite(f)
      self.invited[f.id] = true
    end
  end

  -- Bottom controls
  local by = 495
  if session.isHost then
    local d = ui.cycler("Rounds to win", tostring(session.rounds), 60, by, 560, 50)
    if d ~= 0 then
      local opts = Settings.ROUND_OPTIONS
      local idx = 1
      for k, v in ipairs(opts) do if v == session.rounds then idx = k end end
      session.setRounds(opts[(idx - 1 + d) % #opts + 1])
    end
    local enough = #session.members >= 2
    if ui.button(enough and "Start Match" or "Need 2+ players", 660, by, 560, 50,
      { disabled = not enough, color = { 0.4, 1, 0.5 } }) then
      self:start()
    end
  else
    love.graphics.setFont(app.fonts.title)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.printf(Lobby.rulesText() .. "  -  waiting for the host to start...", 0, by + 10, app.W, "center")
  end

  if ui.button("Leave Lobby", app.W / 2 - 310, 570, 300, 46) then toMenu() end
  if ui.button("Settings", app.W / 2 + 10, 570, 300, 46) then app.push(require("screens.settings").new()) end

  love.graphics.setFont(app.fonts.small)
  love.graphics.setColor(1, 1, 1, 0.4)
  love.graphics.printf("Friends can join with the code, or by accepting a Steam invite while they have the game open " ..
    "(the game runs as Spacewar, so Steam can't launch it for them).", 100, 630, app.W - 200, "center")
  if self.message then
    app.centered(self.message, app.fonts.med, 672, { 1, 0.6, 0.45 })
  end
end

return Lobby
