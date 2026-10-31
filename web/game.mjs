// game.mjs — Exposure core wrapper. Shared by the shipped page (inlined
// by tools/assemble.mjs) and the node capture/playtest harnesses.
// The core is readable Lua source (src/main.lua) on wasmoon (real Lua
// 5.4 in wasm). In the page, wasmoon + the glue wasm + the Lua source
// are inlined and handed over as globals; in node, they resolve from
// the estate tools tree. This wrapper only moves values across.

export const PALETTE = [
  "#0d0208", "#ff2e88", "#f8f0ed", "#ac9393", "#540e46",
  "#ec8584", "#eaeaea", "#68636c", "#ffd166", "#1a0510",
];

export const INPUT = { tap: 1, confirm: 2, back: 4, pause: 8, up: 16, down: 32, left: 64, right: 128 };

let wasmoon = globalThis.wasmoon;
let coreSrc = globalThis.__CORE_SRC;
let glueUri = globalThis.__GLUE_WASM_URL;
if (!wasmoon) {
  const req = (await import("node:module")).createRequire(import.meta.url);
  wasmoon = req("../../../tools/node/node_modules/wasmoon");
  const fs = req("node:fs");
  const url = req("node:url");
  const path = req("node:path");
  coreSrc = fs.readFileSync(path.join(path.dirname(url.fileURLToPath(import.meta.url)), "../src/main.lua"), "utf8");
}

export async function createGame(_ignored, { seed = 1, level = 0, demo = false } = {}) {
  const factory = glueUri ? new wasmoon.LuaFactory(glueUri) : new wasmoon.LuaFactory();
  const lua = await factory.createEngine();
  const Core = await lua.doString(coreSrc);
  const status = Core.init(seed >>> 0, level, demo);
  if (status !== 0) throw new Error(`core init rejected level ${level}`);
  let lastEvent = 0;
  return {
    core: Core,
    startLevel(l) {
      const s = Core.start_level(l);
      if (s !== 0) throw new Error(`core start_level rejected ${l}`);
    },
    step(inputBits) {
      lastEvent = Core.step(16, inputBits >>> 0);
    },
    screen() {
      return Core.screen();
    },
    levelIdx() {
      return Core.level_idx();
    },
    applySettings(paceQuick, textLarge) {
      Core.apply_settings(paceQuick, textLarge);
    },
    settingsBits() {
      return Core.settings_bits();
    },
    applyArchive(days, best) {
      Core.apply_archive(days, best);
    },
    archiveDays() {
      return Core.archive_days();
    },
    archiveBest() {
      return Core.archive_best();
    },
    formedCount() {
      return Core.formed_count();
    },
    event() {
      return lastEvent;
    },
    frameText() {
      return Core.draw();
    },
    frame() {
      return { palette: PALETTE, ops: parseDrawList(this.frameText()) };
    },
  };
}

/// Parse the core's line protocol into raster/canvas ops:
/// r -> ["r",x,y,w,h,c], c -> ["c",x,y,r,c], l -> ["l",...], p -> ["p",...],
/// t -> ["t",x,y,size,c,"text"].
export function parseDrawList(text) {
  const ops = [];
  for (const line of text.split("\n")) {
    if (!line) continue;
    const kind = line[0];
    if (kind === "t") {
      const parts = line.split(" ");
      ops.push(["t", +parts[1], +parts[2], +parts[3], +parts[4], parts.slice(5).join(" ")]);
    } else {
      const parts = line.split(" ").map(Number);
      ops.push([kind, ...parts.slice(1)]);
    }
  }
  return ops;
}
