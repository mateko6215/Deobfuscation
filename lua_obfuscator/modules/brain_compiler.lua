local compiler = require('lua_obfuscator.modules.compiler')
local renamer = require('lua_obfuscator.modules.identifier_renamer')
local strenc = require('lua_obfuscator.modules.string_encryptor')
local flow = require('lua_obfuscator.modules.control_flow')
local env = require('lua_obfuscator.modules.env_checks')
local anti_debug = require('lua_obfuscator.modules.anti_debug')
local anti_tamper = require('lua_obfuscator.modules.anti_tamper')

local M = {}

local DECRYPT_HELPER = [[
local function __bxor(a, b)
  local res, bit = 0, 1
  while a > 0 or b > 0 do
    local aa, bb = a %% 2, b %% 2
    if aa ~= bb then res = res + bit end
    a, b, bit = math.floor(a/2), math.floor(b/2), bit * 2
  end
  return res
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

function __DEC(encoded, key, dyn)
  local a = __b64d(encoded)
  local b = __rot(a, (#dyn + #key) %% 251, true)
  local c = {}
  for i = 1, #b do
    local kb = key:byte(((i - 1) %% #key) + 1)
    c[i] = string.char(__bxor(b:byte(i), kb) %% 256)
  end
  local d = __mix(table.concat(c), dyn, true)
  return __rle_dec(d)
end
]]

function M.compile(source, seed)
  local renamed, rename_map = renamer.rename(source, seed)
  local cf = flow.inject_opaque(renamed, seed)
  local checked = env.inject_source_checks(cf)
  checked = anti_debug.inject_source_guard(checked)
  checked = anti_tamper.inject_source_guard(checked)
  local with_strings, count = strenc.transform(checked, seed)
  local final_source = DECRYPT_HELPER .. '\n' .. with_strings

  local program = compiler.compile(final_source, seed)
  program.rename_map = rename_map
  program.string_count = count
  program.env_policy = env.profile(seed)
  program.anti_debug = anti_debug.profile(seed)
  program = anti_tamper.attach(program, seed)
  program = flow.decorate_program(program, seed)
  return program
end

return M
