# Planning — Exposure

- **Program:** Torogao Jam Program (D-333), week 13 of 14, Wave D — Features
- **Cast:** Lux
- **Language:** Lua (tiger-style-lua)
- **Canon core:** A one-day schedule sim — a shoot, a public appearance, a recorded set.

## Mechanism group (D-334: primary + coupled + persistence/revelation + feel)

- Development tracks (her four) moving visibly on the day's choices
- The exposure ledger — logged by distinct contexts, not raw repetitions
- Stirring visibly tipping into Forming as an event the player witnesses
- Lens Toy attention programmes (decay curves, praise weighting) as the day's economy
- The written record closing the day
- An Appraisal stub — the day is witnessed, and that is when anything moves

## Validates

The DEVELOPMENT-SYSTEM (24 tracks, exposure ledger, no decay, drift caps) as something a player can feel in one sitting — the double meaning is the design: exposure the mechanic, exposure the fantasy.

## Port-back

Track-visibility UI findings for the main game; Lua verdict, second pass (ledger/track scripting).

## Delivery

Game logic ships as readable Lua source on an embedded Lua VM inlined in the single file (wasm-compiled Lua interpreter, or a JS Lua VM of the Fengari class — the week's preflight picks and records which). Toolchain home: sandbox.

## Open preflight items

- GJ-06-class start gate for this week's toolchain (later weeks gate their
  own preflight; only W1's gate covers the program start).
- GJ-07: 18+ flag, content warnings listed, itch ToS screen — verified live
  at entry (the NSFW allowance clause is Owner-reported; re-verify on page).
- Engine-research chapter in the book: confirm the pinned library versions
  before the first build commit.
