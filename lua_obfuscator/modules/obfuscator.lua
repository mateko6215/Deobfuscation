local M = {}

local function rnd_factory(seed)
  local state = seed
  return function(max)
    state = (state * 1103515245 + 12345) % 2147483647
    return (state % max) + 1
  end
end

function M.shuffle_segments(program, seed)
  local rnd = rnd_factory(seed + 77)
  local old = program.segments
  local order = {}
  for i = 1, #old do order[i] = i end
  for i = #order, 2, -1 do
    local j = rnd(i)
    order[i], order[j] = order[j], order[i]
  end

  local new_segments, map = {}, {}
  for new_i, old_i in ipairs(order) do
    new_segments[new_i] = old[old_i]
    map[old_i] = new_i
    new_segments[new_i].idx = new_i
  end
  program.segments = new_segments

  for _, inst in ipairs(program.instructions) do
    if inst[1] == 'PUSH_SEG' or inst[1] == 'SEG_KEY_MIX' then
      inst[2] = map[inst[2]]
    end
  end

  return program
end

function M.inject_noise(program, seed)
  local rnd = rnd_factory(seed)
  local out = {}
  for i, inst in ipairs(program.instructions) do
    if rnd(3) == 1 then out[#out + 1] = { 'NOP', rnd(999), rnd(999) } end
    if rnd(4) == 1 then out[#out + 1] = { 'FAKE_MATH', rnd(9999), rnd(9999), 'm' } end
    if rnd(5) == 1 then out[#out + 1] = { 'JZ', 1, 2, 'opaque' } end
    if rnd(6) == 1 then out[#out + 1] = { 'STACK_SWAP' } end
    out[#out + 1] = inst
    if i % 4 == 0 and rnd(2) == 1 then out[#out + 1] = { 'JMP', 1, 0, 'short' } end
  end
  program.instructions = out
  return program
end

function M.rename_metadata(program, seed)
  local rnd = rnd_factory(seed + 912)
  local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'
  local function random_name(prefix)
    local t = { prefix }
    for _ = 1, 12 do
      local j = rnd(#chars)
      t[#t + 1] = chars:sub(j, j)
    end
    return table.concat(t)
  end
  program.meta = {
    entry = random_name('_e'),
    seg = random_name('_s'),
    vm = random_name('_v'),
    tag = random_name('_t'),
  }
  return program
end

return M
