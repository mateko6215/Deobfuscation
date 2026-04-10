local brain = require('lua_obfuscator.modules.brain_compiler')
local compiler = require('lua_obfuscator.modules.compiler')
local encoder = require('lua_obfuscator.modules.encoder')
local polymorph = require('lua_obfuscator.modules.polymorph')
local obfuscator = require('lua_obfuscator.modules.obfuscator')
local junk_factory = require('lua_obfuscator.modules.junk_factory')
local runtime_policy = require('lua_obfuscator.modules.runtime_policy')
local integrity = require('lua_obfuscator.modules.integrity')
local splitter = require('lua_obfuscator.modules.source_splitter')
local loader = require('lua_obfuscator.runtime.loader')

local input = arg[1]
local output = arg[2] or 'protected_output.lua'
local mode = arg[3] or 'single'
assert(input, 'Usage: lua lua_obfuscator/builder.lua <input.lua> [output.lua] [single|split]')

local fh = assert(io.open(input, 'r'))
local source = fh:read('*a')
fh:close()

local seed = os.time() + math.random(1, 999999)
math.randomseed(seed)

local program = brain.compile(source, seed)
program.seed = seed
program = runtime_policy.enrich(program, seed)
program = obfuscator.shuffle_segments(program, seed)
program = obfuscator.inject_noise(program, seed)
program = junk_factory.inject(program, seed)
program = obfuscator.rename_metadata(program, seed)

local opmap, reverse = polymorph.build_opcode_map(seed)
program = polymorph.remap_instructions(program, opmap)

local program_src = 'return ' .. compiler.serialize(program)
local reverse_src = 'return ' .. compiler.serialize(reverse)

local transport_key = encoder.dynamic_key(seed, #program_src + #reverse_src)
local dyn = encoder.dynamic_key(seed + 131, #transport_key)
local encoded_program = encoder.encrypt_layers(program_src, transport_key, dyn)
local encoded_reverse = encoder.encrypt_layers(reverse_src, transport_key, dyn)

local checksum = integrity.checksum({ encoded_program, encoded_reverse, transport_key, dyn })
local generated = loader.template(encoded_program, encoded_reverse, transport_key, dyn, checksum)

local out_lines = {}
for line in generated:gmatch('[^\n]*\n?') do
  if line == '' then break end
  out_lines[#out_lines + 1] = line
  if math.random(1, 5) == 1 then out_lines[#out_lines + 1] = ('--%x\n'):format(math.random(1, 1e8)) end
  if math.random(1, 4) == 1 then out_lines[#out_lines + 1] = string.rep(' ', math.random(1, 8)) .. '\n' end
end

local final_source = table.concat(out_lines)
if mode == 'split' then
  local parts = splitter.split_text(final_source, 4)
  splitter.emit_reconstructor(parts, output)
else
  local out = assert(io.open(output, 'w'))
  out:write(final_source)
  out:close()
end

print(('Built %s (seed=%d, mode=%s)'):format(output, seed, mode))
