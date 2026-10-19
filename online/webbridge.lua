-- Browser only: a LAN connection through the page's JavaScript (web/index.html), because love.js
-- has no sockets. The page opens a WebSocket to the desktop host that served it.
--   Lua -> page: print("\27LAN <command> ...") lines, which the page's Module.print handles.
--   Page -> Lua: on every command the page rewrites /tmp/rclan.bin (in-memory filesystem):
--     [u8 state][u32 sequence number of the first message][s2 detail], then [u32 length][bytes]...
-- Received messages stay in the file until a later "sync" acknowledges their sequence number,
-- so none are lost even if the page handles a print later than expected.
local pack, unpack = love.data.pack, love.data.unpack

local bridge = {}

local FILE = "/tmp/rclan.bin"
local STATES = { [0] = "idle", "connecting", "open", "closed", "unavailable" }

local function call(cmd, arg)
  print("\27LAN " .. cmd .. (arg and (" " .. arg) or ""))
  local f = io.open(FILE, "rb")
  if not f then return nil end
  local data = f:read("*a")
  f:close()
  return data
end

local function header(data)
  if not data or #data < 7 then return "unavailable", 0, "This page can't use LAN play", 1 end
  local state, first, detail, pos = unpack("<BI4s2", data)
  return STATES[state] or "closed", first, detail, pos
end

-- Can this page join a LAN game? Returns available, detail (the host's address, or why not).
function bridge.info()
  local state, _, detail = header(call("info"))
  return state ~= "unavailable", detail
end

local Conn = {}
Conn.__index = Conn

function bridge.open()
  local t = love.timer.getTime()
  local c = setmetatable({ web = true, state = "connecting", ack = 0, out = {}, inbox = {}, heard = t, sent = t }, Conn)
  c:handle(call("open"))
  return c
end

function Conn:handle(data)
  local state, first, detail, pos = header(data)
  self.state, self.detail = state, detail
  local seq = first
  while data and pos + 3 <= #data do
    local len
    len, pos = unpack("<I4", data, pos)
    if seq > self.ack then
      self.inbox[#self.inbox + 1] = data:sub(pos, pos + len - 1)
      self.ack = seq
      self.heard = love.timer.getTime()
    end
    pos = pos + len
    seq = seq + 1
  end
  if state == "closed" or state == "unavailable" then self.closed = true end
end

-- Send what's queued and pick up what has arrived.
function Conn:sync()
  if self.closed then return end
  local payload = ""
  if #self.out > 0 then
    payload = love.data.encode("string", "base64", table.concat(self.out))
    self.out = {}
  end
  self:handle(call("sync", self.ack .. " " .. payload))
end

-- true once open, false while connecting, nil + reason on failure.
function Conn:checkConnected()
  self:sync()
  if self.state == "open" then return true end
  if self.closed then return nil, self.detail end
  return false
end

function Conn:read() self:sync() end

function Conn:flush()
  if #self.out > 0 then self:sync() end
end

function Conn:sendMsg(data)
  if self.closed then return end
  self.out[#self.out + 1] = pack("string", "<I4", #data) .. data
  self.sent = love.timer.getTime()
end

function Conn:messages()
  local m = self.inbox
  self.inbox = {}
  return m
end

function Conn:close()
  if not self.closed then call("close") end
  self.closed = true
end

return bridge
