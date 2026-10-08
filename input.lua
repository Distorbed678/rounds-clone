-- Input sources. Each player reads an input state table:
--   left, right, up, down, fire, jumpHeld  (held this frame)
--   aim       (angle in radians for mouse aim, nil for keyboard aim)
--   jumpCount, blockCount (press counters; a change means "pressed")
local Input = {}

Input.LOCAL_CONTROLS = {
  { left = "a", right = "d", up = "w", down = "s", fire = "space", block = "lshift" },
  { left = "left", right = "right", up = "up", down = "down", fire = "rctrl", block = "rshift" },
}

local function newState(kind)
  return {
    kind = kind,
    left = false, right = false, up = false, down = false, fire = false, jumpHeld = false,
    aim = nil, jumpCount = 0, blockCount = 0,
  }
end

-- Shared-keyboard local player.
function Input.keys(controls)
  local s = newState("keys")
  s.controls = controls
  return s
end

-- Online player on this machine: WASD + Space, mouse aim, LMB fire, RMB block.
function Input.mouse()
  local s = newState("mouse")
  s.aim = 0
  return s
end

-- Network player, filled in from received packets.
function Input.remote()
  local s = newState("remote")
  s.aim = 0
  return s
end

local function clearHeld(s)
  s.left, s.right, s.up, s.down, s.fire, s.jumpHeld = false, false, false, false, false, false
end

-- Refresh held state. (px, py) is the player's position, used for mouse aim.
-- mx, my are the mouse position in game coordinates.
function Input.poll(s, suppressed, px, py, mx, my)
  if suppressed then
    clearHeld(s)
    return
  end
  local down = love.keyboard.isDown
  if s.kind == "keys" then
    local c = s.controls
    s.left, s.right, s.up, s.down, s.fire = down(c.left), down(c.right), down(c.up), down(c.down), down(c.fire)
    s.jumpHeld = s.up
  elseif s.kind == "mouse" then
    s.left, s.right, s.down = down("a"), down("d"), down("s")
    s.jumpHeld = down("space") or down("w")
    s.fire = love.mouse.isDown(1)
    if px and mx then s.aim = math.atan2(my - py, mx - px) end
  end
end

function Input.keypressed(s, key)
  if s.kind == "keys" then
    if key == s.controls.up then s.jumpCount = s.jumpCount + 1 end
    if key == s.controls.block then s.blockCount = s.blockCount + 1 end
  elseif s.kind == "mouse" then
    if key == "space" or key == "w" then s.jumpCount = s.jumpCount + 1 end
  end
end

function Input.mousepressed(s, button)
  if s.kind == "mouse" and button == 2 then s.blockCount = s.blockCount + 1 end
end

return Input
