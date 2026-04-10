local M = {}

local OPCODES = {
  'PUSH_SEG', 'SEG_KEY_MIX', 'CONCAT_ALL', 'VM_CALL',
  'FAKE_CALL', 'LOOP_FAKE', 'FAKE_MATH', 'NOP',
  'JMP', 'JZ', 'STACK_SWAP'
}

local function rnd_factory(seed)
  local state = seed
  return function(max)
    state = (state * 48271 + 17) % 2147483647
    return (state % max) + 1
  end
end

local function shuffle(arr, rnd)
  for i = #arr, 2, -1 do
    local j = rnd(i)
    arr[i], arr[j] = arr[j], arr[i]
  end
end

function M.build_opcode_map(seed)
  local rnd = rnd_factory(seed)
  local ids = {}
  for i = 1, #OPCODES do ids[i] = 100 + i * 3 end
  shuffle(ids, rnd)
  local forward, reverse = {}, {}
  for i, name in ipairs(OPCODES) do
    forward[name] = ids[i]
    reverse[ids[i]] = name
  end
  return forward, reverse
end

function M.remap_instructions(program, map)
  local out = {}
  for i, inst in ipairs(program.instructions) do
    out[i] = { map[inst[1]], inst[2], inst[3], inst[4] }
  end
  program.instructions = out
  return program
end

return M
