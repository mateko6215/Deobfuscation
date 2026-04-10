local M = {}

function M.checksum(parts)
  local blob = table.concat(parts)
  local n = 0
  for i = 1, #blob do
    n = (n + blob:byte(i) * (i + 17)) % 2147483647
  end
  return n
end

function M.fingerprint(seed, payload_size)
  return (seed * 65537 + payload_size * 257) % 2147483647
end

return M
