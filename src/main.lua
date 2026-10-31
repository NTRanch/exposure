-- exposure/src/main.lua — Exposure core (Lua).
-- Tiger Style (tiger-style-lua): explicit contracts, bounded work,
-- disciplined ownership. The week's data (protocol tables, ledgers) lives
-- in this idiom natively; presentation is the shell's job.
-- The jam ships this source READABLE on an embedded Lua VM inlined in the
-- single file (preflight picks wasm-interpreter vs JS VM; see docs/BUILD.md).

local M = {}

--- One fixed simulation step (1/60 s, fixed by the shell).
function M.step() end

return M
