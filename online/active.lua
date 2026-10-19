-- The online session in use: Steam (online.session) or LAN (online.lan). Both have the same
-- interface (members, isHost, hostId, myId, transport, popEvents, leave, ...), so the lobby and
-- match screens work with either.
local active = {}

active.current = require "online.session"

function active.get()
  return active.current
end

-- Switch to another session, leaving the current one if it's a different kind.
function active.use(s)
  if active.current ~= s then active.current.leave() end
  active.current = s
end

return active
