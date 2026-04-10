local M = {}

function M.split_text(text, chunks)
  local out = {}
  local size = math.max(1, math.floor(#text / chunks))
  local i = 1
  while i <= #text do
    out[#out + 1] = text:sub(i, i + size - 1)
    i = i + size
  end
  return out
end

function M.emit_reconstructor(parts, out_path)
  local f = assert(io.open(out_path, 'w'))
  f:write('local p = {}\n')
  for i, part in ipairs(parts) do
    f:write(('p[%d]=%q\n'):format(i, part))
  end
  f:write('local s=table.concat(p)\nlocal fn=assert((loadstring or load)(s))\nfn()\n')
  f:close()
end

return M
