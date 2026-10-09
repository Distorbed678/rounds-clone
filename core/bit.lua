-- LuaJIT's `bit` library, or a pure-Lua stand-in for the browser build (plain Lua 5.1).
-- Only band and bor are needed (packing small flag sets into bytes).
local ok, bit = pcall(require, "bit")
if ok and bit then return bit end

local compat = {}

local function bitwise(a, b, both)
  local result, place = 0, 1
  while a > 0 or b > 0 do
    local x, y = a % 2, b % 2
    if (both and x == 1 and y == 1) or (not both and (x == 1 or y == 1)) then result = result + place end
    a, b, place = (a - x) / 2, (b - y) / 2, place * 2
  end
  return result
end

function compat.band(a, ...)
  for _, b in ipairs({ ... }) do a = bitwise(a, b, true) end
  return a
end

function compat.bor(a, ...)
  for _, b in ipairs({ ... }) do a = bitwise(a, b, false) end
  return a
end

return compat
