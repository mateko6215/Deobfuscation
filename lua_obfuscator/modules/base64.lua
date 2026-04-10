local M = {}

local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function M.encode(data)
  return ((data:gsub('.', function(x)
    local bits = x:byte()
    local out = ''
    for i = 8, 1, -1 do
      out = out .. ((bits % 2 ^ i - bits % 2 ^ (i - 1) > 0) and '1' or '0')
    end
    return out
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then
      return ''
    end
    local c = 0
    for i = 1, 6 do
      c = c + ((x:sub(i, i) == '1') and 2 ^ (6 - i) or 0)
    end
    return alphabet:sub(c + 1, c + 1)
  end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function M.decode(data)
  data = data:gsub('[^' .. alphabet .. '=]', '')
  return (data:gsub('.', function(x)
    if x == '=' then
      return ''
    end
    local c = alphabet:find(x, 1, true) - 1
    local out = ''
    for i = 6, 1, -1 do
      out = out .. ((c % 2 ^ i - c % 2 ^ (i - 1) > 0) and '1' or '0')
    end
    return out
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if #x ~= 8 then
      return ''
    end
    local c = 0
    for i = 1, 8 do
      c = c + ((x:sub(i, i) == '1') and 2 ^ (8 - i) or 0)
    end
    return string.char(c)
  end))
end

return M
