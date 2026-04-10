local encoder = require('lua_obfuscator.modules.encoder')

local M = {}

function M.transform(source, seed)
  local strings = {}
  local idx = 0

  local function replace_string(raw)
    idx = idx + 1
    local key = encoder.dynamic_key(seed + idx * 97, #raw + idx)
    local dyn = encoder.dynamic_key(seed + idx * 31, #key)
    local enc = encoder.encrypt_layers(raw, key, dyn)
    strings[#strings + 1] = { enc = enc, key = key, dyn = dyn }
    return string.format('__S(%d)', idx)
  end

  source = source:gsub('"([^"]-)"', function(s) return replace_string(s) end)
  source = source:gsub("'([^']-)'", function(s) return replace_string(s) end)

  local bootstrap = {
    'local __STR = {}',
    'local function __S(i)',
    '  local d = __STR[i]',
    '  return __DEC(d[1], d[2], d[3])',
    'end',
  }

  for i, item in ipairs(strings) do
    bootstrap[#bootstrap + 1] = string.format('__STR[%d] = {%q,%q,%q}', i, item.enc, item.key, item.dyn)
  end

  local out = table.concat(bootstrap, '\n') .. '\n' .. source
  return out, #strings
end

return M
