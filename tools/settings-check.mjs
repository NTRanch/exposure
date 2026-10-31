// settings-check.mjs — gates R-202/R-203/R-403: the settings AND
// archive bridges round-trip, and the settings screen is reachable
// from boot with no progression (safety/accessibility options and the
// written record are never gated).
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createGame, INPUT } from "../web/game.mjs";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
void root;
const game = await createGame(null, { seed: 7, level: 0, demo: false });

function steps(n, bits = 0) { for (let i = 0; i < n; i++) game.step(bits); }
function fail(msg) { console.error(`settings-check: ${msg}`); process.exit(1); }

if (game.screen() !== 0) fail("boot screen is not the 18+ gate");
game.applySettings(true, false);
if (game.settingsBits() !== 1) fail("apply_settings(pace_quick) did not round-trip");
game.applySettings(false, true);
if (game.settingsBits() !== 2) fail("apply_settings(text_large) did not round-trip");
game.applySettings(true, true);

// The archive bridge: the written record restored before the first day.
game.applyArchive(2, 3);
if (game.archiveDays() !== 2) fail("apply_archive days did not round-trip");
if (game.archiveBest() !== 3) fail("apply_archive best did not round-trip");
game.applyArchive(5000, 99);
if (game.archiveDays() !== 999 || game.archiveBest() !== 4) fail("apply_archive did not clamp");

// Navigate gate -> title -> settings with plain input, no play first.
steps(1, INPUT.confirm);
if (game.screen() !== 1) fail("confirm did not leave the gate");
steps(1, INPUT.down); steps(1, INPUT.down);
steps(1, INPUT.confirm);
if (game.screen() !== 5) fail(`settings not reachable from title (screen=${game.screen()})`);
steps(2);
if (!game.frameText().includes("QUICK")) fail("settings screen does not show restored QUICK pace");
if (!game.frameText().includes("LARGE")) fail("settings screen does not show restored LARGE text");
console.log("settings-check: settings + archive bridges round-trip; settings reachable ungated; restored values render");
