local M = {}

function M.enrich(program, seed)
  program.runtime_policy = {
    min_lua = '5.1',
    max_vm_depth = 2,
    strict_mode = true,
    policy_nonce = (seed * 31337) % 2147483647,
  }
  return program
end

return M
