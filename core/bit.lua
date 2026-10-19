-- LuaJIT's `bit` library, or a pure-Lua stand-in for the browser build (plain Lua 5.1).
-- Only band, bor and bxor are needed (flag bytes, WebSocket masks).
local ok, bit = pcall(require, "bit")
if ok and bit then return bit end

local compat = {}

-- op: "and", "or" or "xor"
local function bitwise(a, b, op)
  local result, place = 0, 1
  while a > 0 or b > 0 do
    local x, y = a % 2, b % 2
    local on
    if op == "and" then on = x == 1 and y == 1
    elseif op == "or" then on = x == 1 or y == 1
    else on = x ~= y end
    if on then result = result + place end
    a, b, place = (a - x) / 2, (b - y) / 2, place * 2
  end
  return result
end

function compat.band(a, ...)
  for _, b in ipairs({ ... }) do a = bitwise(a, b, "and") end
  return a
end

function compat.bor(a, ...)
  for _, b in ipairs({ ... }) do a = bitwise(a, b, "or") end
  return a
end

function compat.bxor(a, ...)
  for _, b in ipairs({ ... }) do a = bitwise(a, b, "xor") end
  return a
end

return compat
