local M = {}

local function rng(seed)
  local s = seed
  return function(max)
    s = (s * 1664525 + 1013904223) % 2147483647
    return (s % max) + 1
  end
end

function M.inject(program, seed)
  local r = rng(seed + 707)
  program.decoys = {}
  for i = 1, 8 do
    program.decoys[i] = {
      id = i,
      token = ('D%08x'):format(r(0xFFFFFF)),
      values = { r(9999), r(9999), r(9999) },
      never = (i % 2 == 0)
    }
  end

  local out = {}
  for i, inst in ipairs(program.instructions) do
    if r(4) == 1 then out[#out + 1] = { 'FAKE_CALL', r(#program.decoys), 'decoy' } end
    if r(5) == 1 then out[#out + 1] = { 'NOP', r(9), r(9), 'pad' } end
    out[#out + 1] = inst
    if i % 7 == 0 and r(2) == 1 then out[#out + 1] = { 'STACK_SWAP' } end
  end
  program.instructions = out
  return program
end

return M
