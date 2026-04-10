local M = {}

function M.profile(seed)
  return {
    deny_globals = { 'jit.util', 'debug.sethook' },
    require_globals = { 'pcall', 'string', 'table', 'math' },
    nonce = (seed * 73) % 2147483647,
  }
end

function M.inject_source_checks(source)
  local checks = [[
if _G and _G.jit and _G.jit.util then return end
if type(debug) == 'table' and type(debug.gethook) == 'function' and debug.gethook() then return end
]]
  return checks .. '\n' .. source
end

return M
