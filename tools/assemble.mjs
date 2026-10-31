// assemble.mjs — build the single-file jam entry web/index.html from
// src/main.lua (the readable Lua core) + wasmoon (UMD + glue wasm) +
// web/game.mjs + web/shell.html. The Lua source ships readable in the
// page, as the week's delivery seam specifies.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const toolsTree = join(root, "../../tools/node/node_modules/wasmoon/dist");
const wasmoonJs = readFileSync(join(toolsTree, "index.js"), "utf8");
const glueB64 = readFileSync(join(toolsTree, "glue.wasm")).toString("base64");
const coreSrc = readFileSync(join(root, "src/main.lua"), "utf8");
const gameMjs = readFileSync(join(root, "web/game.mjs"), "utf8").replace(/^export /gm, "");
const shell = readFileSync(join(root, "web/shell.html"), "utf8");

const out = shell
  .replace("/*__WASMOON_JS__*/", () => wasmoonJs)
  .replace("/*__GLUE_B64__*/", () => glueB64)
  .replace("/*__CORE_SRC__*/", () => JSON.stringify(coreSrc))
  .replace("/*__GAME_MJS__*/", () => gameMjs);
if (out === shell) throw new Error("shell placeholders not found — nothing assembled");
writeFileSync(join(root, "web/index.html"), out);
console.log(`assembled web/index.html (${out.length} bytes, glue wasm ${glueB64.length} b64 chars, lua core ${coreSrc.length} chars)`);
