local base64 = require('lua_obfuscator.modules.base64')

local M = {}

local function bxor(a, b)
  local res, bit = 0, 1
  while a > 0 or b > 0 do
    local aa, bb = a % 2, b % 2
    if aa ~= bb then
      res = res + bit
    end
    a, b, bit = math.floor(a / 2), math.floor(b / 2), bit * 2
  end
  return res
end

local function xor_bytes(input, key)
  local out = {}
  for i = 1, #input do
    local kb = key:byte(((i - 1) % #key) + 1)
    out[i] = string.char(bxor(input:byte(i), kb) % 256)
  end
  return table.concat(out)
end

local function rotate_bytes(input, offset)
  local out = {}
  for i = 1, #input do
    out[i] = string.char((input:byte(i) + offset) % 256)
  end
  return table.concat(out)
end

local function derotate_bytes(input, offset)
  local out = {}
  for i = 1, #input do
    out[i] = string.char((input:byte(i) - offset) % 256)
  end
  return table.concat(out)
end

local function custom_mix(input, salt)
  local out = {}
  for i = 1, #input do
    local b = input:byte(i)
    local s = (salt:byte(((i - 1) % #salt) + 1) + i * 7) % 256
    out[i] = string.char((b + s) % 256)
  end
  return table.concat(out)
end

local function custom_unmix(input, salt)
  local out = {}
  for i = 1, #input do
    local b = input:byte(i)
    local s = (salt:byte(((i - 1) % #salt) + 1) + i * 7) % 256
    out[i] = string.char((b - s) % 256)
  end
  return table.concat(out)
end

local function rle_compress(input)
  local out, i = {}, 1
  while i <= #input do
    local c, run = input:sub(i, i), 1
    while i + run <= #input and input:sub(i + run, i + run) == c and run < 255 do
      run = run + 1
    end
    out[#out + 1] = string.char(run)
    out[#out + 1] = c
    i = i + run
  end
  return table.concat(out)
end

local function rle_decompress(input)
  local out, i = {}, 1
  while i < #input do
    local run = input:byte(i)
    local c = input:sub(i + 1, i + 1)
    out[#out + 1] = string.rep(c, run)
    i = i + 2
  end
  return table.concat(out)
end

function M.dynamic_key(seed, salt)
  local n = (seed * 1103515245 + 12345 + salt * 97) % 2147483647
  local out = {}
  for i = 1, 24 do
    n = (n * 1664525 + 1013904223 + i * 31) % 2147483647
    out[i] = string.char((n % 94) + 33)
  end
  return table.concat(out)
end

function M.per_item_key(master, idx, salt)
  local seed = 0
  for i = 1, #master do
    seed = (seed + master:byte(i) * (i + idx + salt)) % 2147483647
  end
  return M.dynamic_key(seed + idx * 17, salt + idx * 13)
end

function M.chain_key(prev_key, payload)
  local n = #prev_key * 131 + #payload * 17
  for i = 1, #payload do
    n = (n + payload:byte(i) * (i + 3)) % 2147483647
  end
  return M.dynamic_key(n, #payload)
end

function M.encrypt(raw, key)
  local s1 = xor_bytes(raw, key)
  local s2 = rotate_bytes(s1, (#key * 13) % 251)
  return base64.encode(s2)
end

function M.decrypt(encoded, key)
  local s1 = base64.decode(encoded)
  local s2 = derotate_bytes(s1, (#key * 13) % 251)
  return xor_bytes(s2, key)
end

function M.encrypt_layers(raw, key, dyn)
  local a = rle_compress(raw)
  local b = custom_mix(a, dyn)
  local c = xor_bytes(b, key)
  local d = rotate_bytes(c, (#dyn + #key) % 251)
  return base64.encode(d)
end

function M.decrypt_layers(encoded, key, dyn)
  local a = base64.decode(encoded)
  local b = derotate_bytes(a, (#dyn + #key) % 251)
  local c = xor_bytes(b, key)
  local d = custom_unmix(c, dyn)
  return rle_decompress(d)
end

return M
