# Advanced Lua VM Obfuscator Framework (Defensive)

This framework generates per-build unique protected Lua loaders using a custom VM pipeline and layered reversible encoding.

## Implemented capabilities

- **SVM-style brain compiler pipeline** (`brain_compiler.lua`) that orchestrates identifier renaming, string encryption, opaque predicates, and source-level environment checks before bytecode segmentation.
- **Custom VM bytecode stream** from source (`string.dump` segmented into VM instructions).
- **Polymorphic opcode map** (numeric opcode IDs randomized each build).
- **Multi-layer transform stack** per segment:
  - RLE compression
  - custom byte mixing
  - XOR
  - byte rotation
  - Base64
- **Key derivation chain**: each segment key is derived from prior segment state.
- **Instruction obfuscation**:
  - `NOP`, `FAKE_MATH`, `FAKE_CALL`, `LOOP_FAKE`
  - `JMP`, `JZ`, `STACK_SWAP`, fake control flow blocks
- **Self-integrity checksum** + runtime environment validation.
- **Anti-tamper / anti-debug guards** (non-destructive fail-closed checks).
- **Nested VM call path** support (`VM_CALL`) to increase analysis depth.
- **Entropy noise**: randomized comments/spacing/newlines in generated loader.
- **Optional output splitting** mode for multi-part reconstruction.

## Modules

- `builder.lua`
- `modules/brain_compiler.lua`
- `modules/compiler.lua`
- `modules/encoder.lua`
- `modules/integrity.lua`
- `modules/runtime_policy.lua`
- `modules/source_splitter.lua`
- `modules/junk_factory.lua`
- `modules/identifier_renamer.lua`
- `modules/string_encryptor.lua`
- `modules/control_flow.lua`
- `modules/env_checks.lua`
- `modules/anti_debug.lua`
- `modules/anti_tamper.lua`
- `modules/obfuscator.lua`
- `modules/polymorph.lua`
- `runtime/loader.lua`
- `runtime/vm.lua`
- `examples/input.lua`

## Build

```bash
lua lua_obfuscator/builder.lua lua_obfuscator/examples/input.lua protected.lua
lua lua_obfuscator/builder.lua lua_obfuscator/examples/input.lua protected_split.lua split
lua protected.lua
```

## Safety note

This repository focuses on defensive obfuscation architecture and avoids intentionally destructive anti-debug behavior.
