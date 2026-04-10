local integrity = require('lua_obfuscator.modules.integrity')

local M = {}

function M.attach(program, seed)
  local digest = integrity.checksum({ tostring(seed), tostring(#program.instructions), tostring(#program.segments) })
  program.anti_tamper = {
    digest = digest,
    seed_mask = (seed * 97) % 2147483647,
    expected_version = program.version,
  }
  return program
end

function M.inject_source_guard(source)
  local guard = [[
local function __tamper_guard(v)
  return type(v) == 'number' and v > 0
end
if not __tamper_guard(1) then return end
]]
  return guard .. '\n' .. source
end

return M
