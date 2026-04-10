local encoder = require('lua_obfuscator.modules.encoder')

local M = {}

local function safe_load(source, chunkname)
  local loader = loadstring or load
  local fn, err = loader(source, chunkname)
  if not fn then error(err) end
  return fn
end

local function split_bytes(s, size)
  local out, i = {}, 1
  while i <= #s do
    out[#out + 1] = s:sub(i, i + size - 1)
    i = i + size
  end
  return out
end

function M.compile(source, seed)
  local fn = safe_load(source, '@input')
  local dumped = string.dump(fn)
  local seg_size = 12 + (seed % 17)
  local raw_segments = split_bytes(dumped, seg_size)

  local segments = {}
  local instructions = {}
  local chain = encoder.dynamic_key(seed, #dumped)

  for i, seg in ipairs(raw_segments) do
    local key = encoder.chain_key(chain, seg)
    local dyn = encoder.dynamic_key(seed + i * 53, #seg + i)
    local blob = encoder.encrypt_layers(seg, key, dyn)
    local packed_key = encoder.encrypt_layers(key, chain, dyn)

    segments[i] = {
      blob = blob,
      key = packed_key,
      dyn = dyn,
      idx = i,
    }

    instructions[#instructions + 1] = { 'PUSH_SEG', i }
    instructions[#instructions + 1] = { 'SEG_KEY_MIX', i }
    if i % 2 == 0 then
      instructions[#instructions + 1] = { 'FAKE_CALL', i, 'noop_' .. i }
    end

    chain = key
  end

  instructions[#instructions + 1] = { 'LOOP_FAKE', #raw_segments }
  instructions[#instructions + 1] = { 'CONCAT_ALL' }
  instructions[#instructions + 1] = { 'VM_CALL', 1 }

  return {
    version = 2,
    segments = segments,
    instructions = instructions,
    chain0 = encoder.dynamic_key(seed, #dumped),
  }
end

local function serialize_value(v)
  local tv = type(v)
  if tv == 'number' then return tostring(v)
  elseif tv == 'boolean' then return tostring(v)
  elseif tv == 'string' then return string.format('%q', v)
  elseif tv == 'table' then
    local parts, n = {}, #v
    for i = 1, n do parts[#parts + 1] = serialize_value(v[i]) end
    for k, val in pairs(v) do
      if not (type(k) == 'number' and k >= 1 and k <= n and math.floor(k) == k) then
        parts[#parts + 1] = '[' .. serialize_value(k) .. ']=' .. serialize_value(val)
      end
    end
    return '{' .. table.concat(parts, ',') .. '}'
  end
  return 'nil'
end

function M.serialize(tbl)
  return serialize_value(tbl)
end

return M
