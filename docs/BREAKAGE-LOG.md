# Breakage log — Exposure

Every breakage found in playtest or build lands here with: what broke, the
evidence, the bloch attempt id, and the fix or the filed finding. Copied to
bloch at the week's close (the log is the input, bloch is the record).

## 2026-10-30 — v1.0 build (sandbox)

- **B-1: an impossible goal shipped in the first calibration.** Day
  Three demanded 8 distinct ledger contexts from a 6-slot day (max
  possible: 6). Found by the demo playtest, not by inspection. Fix:
  the goal is 6 — every pick distinct — and the deck now returns
  unpicked offers to its back, so the day cycles through all nine
  contexts before any is offered twice.
- **B-2: the demo lost days it should win, twice, for two different
  reasons.** First on attention (it scored raw attention, not the
  praise-weighted attention a pick would actually bank); then on
  spread (it valued gains linearly and finished no track). Fixes:
  score effective attention with the warmth rule applied; add
  threshold-crossing bonuses (a pick that completes a Forming is the
  day's real currency). After: first-attempt wins on the playtest
  seeds, 27/30 across a seed sweep — strong, not superhuman.
- **B-3: text overflow on the play screen (D-221 frame check).** The
  day title ran into the ATTENTION label, EXHIBITION ran into its
  stage word, and long captions clipped at the right edge. Fixes:
  attention block moved right and down, the goal line moved to the
  left column, track rows set a size down, captions built from short
  track names. Re-captured, re-inspected PASS. The same session's
  estate-wide raster-advance audit (B-4) then swept the rest.
- **B-4: the raster-advance audit.** The preview rasteriser's font
  advance doubles at size >= 21 (unit = round(size/14)); any long line
  set larger clips in the rendered videos even though the browser's
  real font fits it. An audit over every screen of every Pax-built
  game flagged the gate press line, the tracks header, and the
  record's closing line here — all set down a size, audit now CLEAN.
  The same fix was applied to trancefall, idle-hands, and withheld.
  Lesson filed for the estate: long lines live at size <= 20.
- **B-5 (held, not a defect): seahawk playtest pass not run.** Primo
  unreachable tonight (tunnel outage since 03:15 PDT). The sandbox
  automated playtest is the record of the moment; R-905's verify
  names it for this reason.
- **B-6 (held, by design of the jam): GJ-07 live itch checks open.**
  Verified live at entry time; no entry is being submitted tonight.
  R-904 stays open. The game's own 18+ gate ships first regardless.
- **B-7 (design ruling): persistence scope.** What persists (shell
  localStorage): settings and the written record (days closed, best
  formation). A day's track totals restart from the day's archive
  base each sitting; there is no mid-day save. Recorded here rather
  than silently narrowing R-202/R-203.
