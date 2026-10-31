# Changelog — Exposure

All notable changes, newest first. Format: Keep a Changelog.

## [1.0.0] — 2026-10-30

First playable release: the full W13 mechanism group, built and gated in
the sandbox under the Owner's v1.0 jam directive.

- **One-day schedule sim** (Lua 5.4, shipped readable on wasmoon):
  six slots a day, three engagements offered per slot — a shoot, an
  appearance, a recorded set, a Lens Toy feed, and more.
- **Her four development tracks** (EXHIBITION, LENS, PRAISE, USE) on
  the development-system's law at one-sitting scale: no decay, drift
  cap 140, Stirring at 40, Forming at 100.
- **The exposure ledger**: contexts logged in full the first time,
  at a quarter on repeats — variety is what pays.
- **Appraisal**: gains stay PENDING until the day is witnessed
  (midday and close); tracks tip Stirring → Forming as events.
- **Lens Toy attention economy**: attention decays between slots;
  praise programmes earn half again while a recorded context is warm.
- **The written record** closes every day, goals named MET or SHORT.
- **Three days**: The Shoot, The Appearance, The Set — each starts
  from the archive the record carries.
- **Screens**: 18+ gate, title with day picker, the brief, gameplay,
  pause, settings (pace, text size), the written record (won/lost).
- **Audio**: generated WebAudio cues answering player input only.
- **Previews**: `docs/previews/level-{1,2,3}-exposure.mp4`, rendered
  from the shipped core in demo mode.
- **Gates**: 14 busted specs (validation + adversarial) on the
  identical shipped core file, settings/archive bridge checks,
  performance budget (0.238 ms per step+draw), scripted playtest
  closing all three days won on the first attempt.

## [0.1.0] — 2026-10-30

- Repo scaffolded 2026-10-30: bloch roadmap (kind=game, lane=restricted),
  planning, per-game skill, baseline Lua config, NTRanch-themed mdBook,
  brand assets (header + icon).
