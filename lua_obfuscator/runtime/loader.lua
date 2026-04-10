local M = {}

function M.template(encoded_program, encoded_reverse, key, dyn, checksum)
  return ([[
local function __sum(s)
  local n = 0
  for i = 1, #s do n = (n + s:byte(i) * i) %% 2147483647 end
  return n
end

local function __b64d(data)
  local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  data = data:gsub('[^' .. alphabet .. '=]', '')
  return (data:gsub('.', function(x)
    if x == '=' then return '' end
    local c = alphabet:find(x, 1, true) - 1
    local out = ''
    for i = 6, 1, -1 do out = out .. ((c %% 2 ^ i - c %% 2 ^ (i - 1) > 0) and '1' or '0') end
    return out
  end):gsub('%%d%%d%%d?%%d?%%d?%%d?%%d?%%d?', function(x)
    if #x ~= 8 then return '' end
    local c = 0
    for i = 1, 8 do c = c + ((x:sub(i, i) == '1') and 2 ^ (8 - i) or 0) end
    return string.char(c)
  end))
end

local function __bxor(a, b)
  local res, bit = 0, 1
  while a > 0 or b > 0 do
    local aa, bb = a %% 2, b %% 2
    if aa ~= bb then res = res + bit end
    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
  end
  return res
end

local function __xor(input, k)
  local out = {}
  for i = 1, #input do
    local kb = k:byte(((i - 1) %% #k) + 1)
    out[i] = string.char(__bxor(input:byte(i), kb) %% 256)
  end
  return table.concat(out)
end

local function __rot(input, offset, inv)
  local out = {}
  for i = 1, #input do
    local b = input:byte(i)
    out[i] = string.char(((inv and (b - offset) or (b + offset))) %% 256)
  end
  return table.concat(out)
end

local function __mix(input, salt, inv)
  local out = {}
  for i = 1, #input do
    local b = input:byte(i)
    local s = (salt:byte(((i - 1) %% #salt) + 1) + i * 7) %% 256
    out[i] = string.char(((inv and (b - s) or (b + s))) %% 256)
  end
  return table.concat(out)
end

local function __rle_dec(input)
  local out, i = {}, 1
  while i < #input do
    local run, c = input:byte(i), input:sub(i + 1, i + 1)
    out[#out + 1] = string.rep(c, run)
    i = i + 2
  end
  return table.concat(out)
end

local function __decrypt_layers(encoded, k, d)
  local a = __b64d(encoded)
  local b = __rot(a, (#d + #k) %% 251, true)
  local c = __xor(b, k)
  local e = __mix(c, d, true)
  return __rle_dec(e)
end

if type(debug) == 'table' and type(debug.gethook) == 'function' and debug.gethook() then return end

local encoded_program = %q
local encoded_reverse = %q
local key = %q
local dyn = %q
if __sum(encoded_program .. encoded_reverse .. key .. dyn) ~= %d then return end

local loader = loadstring or load
local pchunk = loader(__decrypt_layers(encoded_program, key, dyn), nil, 't', {})
local rchunk = loader(__decrypt_layers(encoded_reverse, key, dyn), nil, 't', {})
if not pchunk or not rchunk then return end

local okp, program = pcall(pchunk)
local okr, reverse = pcall(rchunk)
if not okp or not okr or type(program) ~= 'table' then return end


local function __env_ok(policy)
  if type(policy) ~= 'table' then return true end
  if type(policy.require_globals) == 'table' then
    for i = 1, #policy.require_globals do
      if _G[policy.require_globals[i]] == nil then return false end
    end
  end
  if type(policy.deny_globals) == 'table' then
    for i = 1, #policy.deny_globals do
      local path = policy.deny_globals[i]
      if path == 'jit.util' and _G.jit and _G.jit.util then return false end
    end
  end
  return true
end
if not __env_ok(program.env_policy) then return end

if type(program.runtime_policy) == 'table' then
  if program.runtime_policy.strict_mode and program.runtime_policy.max_vm_depth and program.runtime_policy.max_vm_depth < 1 then return end
end


local function __meta_digest(prog)
  local n = 0
  n = (n + (#prog.instructions or 0) * 13) %% 2147483647
  n = (n + (#prog.segments or 0) * 17) %% 2147483647
  n = (n + (prog.seed or 0)) %% 2147483647
  return n
end

if type(program.anti_debug) == 'table' and program.anti_debug.block_debug_hook then
  if type(debug) == 'table' and type(debug.gethook) == 'function' and debug.gethook() then return end
end

if type(program.anti_tamper) == 'table' then
  if program.anti_tamper.expected_version ~= program.version then return end
  if __meta_digest(program) <= 0 then return end
end

local function __dynkey(seed, salt)
  local n = (seed * 1103515245 + 12345 + salt * 97) %% 2147483647
  local out = {}
  for i = 1, 24 do
    n = (n * 1664525 + 1013904223 + i * 31) %% 2147483647
    out[i] = string.char((n %% 94) + 33)
  end
  return table.concat(out)
end

local function __chain(prev, payload)
  local n = #prev * 131 + #payload * 17
  for i = 1, #payload do n = (n + payload:byte(i) * (i + 3)) %% 2147483647 end
  return __dynkey(n, #payload)
end

local function __vm_exec(prog, rev, depth)
  depth = depth or 0
  if depth > 2 then return nil end

  local stack, outbuf, chain = {}, {}, prog.chain0
  local ip = 1

  local function decode_segment(seg)
    local key = __decrypt_layers(seg.key, chain, seg.dyn)
    local raw = __decrypt_layers(seg.blob, key, seg.dyn)
    chain = __chain(chain, raw)
    return raw
  end

  while ip <= #prog.instructions do
    local inst = prog.instructions[ip]
    local op = rev[inst[1]]

    if op == 'PUSH_SEG' then
      stack[#stack + 1] = decode_segment(prog.segments[inst[2]])
    elseif op == 'SEG_KEY_MIX' then
      chain = __chain(chain, tostring(inst[2] or 0))
    elseif op == 'STACK_SWAP' then
      local n = #stack
      if n > 1 then stack[n], stack[n - 1] = stack[n - 1], stack[n] end
    elseif op == 'CONCAT_ALL' then
      outbuf[1] = table.concat(stack)
      stack = { outbuf[1] }
    elseif op == 'VM_CALL' then
      if (inst[2] or 0) > 0 and depth < 1 then
        __vm_exec({instructions={{inst[1], 0, 0, 0}}, segments=prog.segments, chain0=prog.chain0}, rev, depth + 1)
      end
      local chunk
      if loadstring then chunk = loadstring(stack[1]) else chunk = load(stack[1], nil, 'b', {}) end
      if not chunk then return nil end
      local ok = pcall(chunk)
      if not ok then return nil end
    elseif op == 'FAKE_CALL' or op == 'LOOP_FAKE' or op == 'FAKE_MATH' or op == 'NOP' then
      local _ = ((inst[2] or 0) + (inst[3] or 0) + ip) %% 101
    elseif op == 'JMP' then
      ip = ip + (inst[2] or 0)
    elseif op == 'JZ' then
      if (inst[2] or 1) == 0 then ip = ip + (inst[3] or 1) end
    end

    ip = ip + 1
  end

  return true
end

__vm_exec(program, reverse, 0)
]]):format(encoded_program, encoded_reverse, key, dyn, checksum)
end

return M
