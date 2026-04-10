local M = {}

local RESERVED = {
  ['and']=true,['break']=true,['do']=true,['else']=true,['elseif']=true,['end']=true,
  ['false']=true,['for']=true,['function']=true,['if']=true,['in']=true,['local']=true,
  ['nil']=true,['not']=true,['or']=true,['repeat']=true,['return']=true,['then']=true,
  ['true']=true,['until']=true,['while']=true,
}

local function rng(seed)
  local s = seed
  return function(max)
    s = (s * 1103515245 + 12345) % 2147483647
    return (s % max) + 1
  end
end

function M.rename(source, seed)
  local rnd = rng(seed + 201)
  local map = {}
  local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ'

  local function mkname()
    local t = { '_' }
    for _ = 1, 10 do
      local i = rnd(#chars)
      t[#t + 1] = chars:sub(i, i)
    end
    return table.concat(t)
  end

  source = source:gsub('([%a_][%w_]*)', function(tok)
    if RESERVED[tok] then return tok end
    if tok == '_ENV' or tok == 'self' then return tok end
    if not map[tok] then map[tok] = mkname() end
    return map[tok]
  end)

  return source, map
end

return M
