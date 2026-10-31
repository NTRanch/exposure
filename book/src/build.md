# Build & Delivery — Exposure

**Language:** Lua (tiger-style-lua)

**Delivery shape:** Game logic ships as readable Lua source on an embedded Lua VM inlined in the single file (wasm-compiled Lua interpreter, or a JS Lua VM of the Fengari class — the week's preflight picks and records which). Toolchain home: sandbox.

**Jam rule:** one self-contained `index.html`, ≥6 screens (Title / Pause /
How to Play / Gameplay / Settings / Game Over-or-Victory), documented
process (GAMEOTRON orchestrates; the language build chain is part of the
documentation).

**Book:** `mdbook build book` renders this planning book to `book/html/`
with the NTRanch theme (dark background, hot pink).
