local encoder = require('lua_obfuscator.modules.encoder')

local VM = {}

local function safe_load(blob)
  if loadstring then
    return loadstring(blob)
  end
  return load(blob, nil, 'b', {})
end

function VM.execute(program, reverse, depth)
  depth = depth or 0
  if depth > 2 then return nil end

  local stack, chain = {}, program.chain0
  local ip = 1

  local function decode_segment(seg)
    local key = encoder.decrypt_layers(seg.key, chain, seg.dyn)
    local raw = encoder.decrypt_layers(seg.blob, key, seg.dyn)
    chain = encoder.chain_key(chain, raw)
    return raw
  end

  while ip <= #program.instructions do
    local inst = program.instructions[ip]
    local op = reverse[inst[1]]

    if op == 'PUSH_SEG' then
      stack[#stack + 1] = decode_segment(program.segments[inst[2]])
    elseif op == 'SEG_KEY_MIX' then
      chain = encoder.chain_key(chain, tostring(inst[2]))
    elseif op == 'STACK_SWAP' then
      local n = #stack
      if n > 1 then stack[n], stack[n - 1] = stack[n - 1], stack[n] end
    elseif op == 'CONCAT_ALL' then
      stack = { table.concat(stack) }
    elseif op == 'VM_CALL' then
      if (inst[2] or 0) > 0 and depth < 1 then
        VM.execute({ instructions = {}, segments = program.segments, chain0 = program.chain0 }, reverse, depth + 1)
      end
      local fn = safe_load(stack[1])
      if not fn then return nil end
      local ok = pcall(fn)
      if not ok then return nil end
    elseif op == 'FAKE_CALL' or op == 'LOOP_FAKE' or op == 'FAKE_MATH' or op == 'NOP' then
      local _ = ((inst[2] or 0) + (inst[3] or 0) + ip) % 97
    elseif op == 'JMP' then
      ip = ip + (inst[2] or 0)
    elseif op == 'JZ' then
      if (inst[2] or 1) == 0 then ip = ip + (inst[3] or 1) end
    end

    ip = ip + 1
  end

  return true
end

return VM
