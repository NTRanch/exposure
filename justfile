# Exposure — task recipes (wired at the v1.0 build, 2026-10-30).
# The core is readable Lua 5.4 (src/main.lua) on wasmoon; the specs run
# on the estate PUC Lua 5.4.8 via its busted. Paths are the sandbox's;
# override as the machine requires.

LUA := env_var_or_default("LUA", join(home_dir(), "workspace/tools/lua-5.4.8/src/lua"))
BUSTED := env_var_or_default("BUSTED", join(home_dir(), "workspace/tools/luarocks-tree/bin/busted"))

# Assemble the single-file jam entry: wasmoon + glue + Lua core inlined
build:
    node tools/assemble.mjs

# Run every gate: core specs, bridges, perf budget, scripted playtest
check:
    {{BUSTED}} tests/exposure_spec.lua
    node tools/assemble.mjs
    node tools/settings-check.mjs
    node tools/perf.mjs
    node tools/playtest.mjs

# Render the per-level preview videos from the shipped core (demo mode)
previews:
    node tools/capture.mjs 0 20264
    node tools/capture.mjs 1 20264
    node tools/capture.mjs 2 20264

# Build the planning book
book:
    mdbook build book
