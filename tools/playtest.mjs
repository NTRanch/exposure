// playtest.mjs — automated playtest: the demo policy plays every day
// from a fresh start against the shipped Lua core (wasmoon) and must
// close it WON on the first attempt — a loss restarts nothing here.
// This is the sandbox playtest of record; the seahawk pass on primo is
// the follow-up named in docs/BREAKAGE-LOG.md.
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createGame } from "../web/game.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
void root;
const SCREENS = ["gate", "title", "howto", "play", "pause", "settings", "victory", "gameover"];

let failures = 0;
for (let level = 0; level < 3; level++) {
  const game = await createGame(null, { seed: 9000 + level, level, demo: true });
  game.startLevel(level);
  let steps = 0;
  const maxSteps = (6 * 60 * 1000) / 16;
  while (game.screen() !== 6 && game.screen() !== 7 && steps < maxSteps) {
    game.step(0);
    steps++;
  }
  const won = game.screen() === 6;
  console.log(`day ${level + 1}: screen=${SCREENS[game.screen()]} steps=${steps} formed=${game.formedCount()} ${won ? "VICTORY" : "FAIL"}`);
  if (!won) failures++;
}
if (failures) {
  console.error(`playtest: ${failures} day(s) not closed won by the demo policy`);
  process.exit(1);
}
console.log("playtest: all 3 days closed won, first attempt");
