local M = {}

local function rnd(seed)
  local s = seed
  return function(max)
    s = (s * 48271 + 17) % 2147483647
    return (s % max) + 1
  end
end

function M.inject_opaque(source, seed)
  local r = rnd(seed + 303)
  local guards = {}
  for i = 1, 4 do
    local a, b = r(999), r(999)
    guards[#guards + 1] = string.format('if ((%d*%d+%d) %% 2) == 0 then local _o%d = %d end', a, b, i, i, a + b)
  end
  return table.concat(guards, '\n') .. '\n' .. source
end

function M.decorate_program(program, seed)
  local r = rnd(seed + 404)
  local out = {}
  for i, inst in ipairs(program.instructions) do
    if r(3) == 1 then out[#out + 1] = { 'JZ', 1, 1, 'opaque' } end
    out[#out + 1] = inst
    if i % 6 == 0 and r(2) == 1 then out[#out + 1] = { 'LOOP_FAKE', r(9) } end
  end
  program.instructions = out
  return program
end

return M
