local M = {}

function M.profile(seed)
  return {
    block_debug_hook = true,
    clock_threshold = 5,
    nonce = (seed * 1231) % 2147483647,
  }
end

function M.inject_source_guard(source)
  local guard = [[
if type(debug) == 'table' and type(debug.gethook) == 'function' and debug.gethook() then return end
local __t0 = os and os.clock and os.clock() or 0
local __t1 = os and os.clock and os.clock() or 0
if (__t1 - __t0) > 5 then return end
]]
  return guard .. '\n' .. source
end

return M
