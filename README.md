# Exposure

**Nice Thoughts Ranch** · Torogao Jam Program week 13 (Wave D — Features) · Lux · **Lua**

A one-day schedule sim — a shoot, a public appearance, a recorded set.

An 18+ game built for the weekly Gameotron jam on itch.io (NTRanch), as one
rung of the 14-week Torogao system-validation program (D-333/D-334/D-335/D-336).
The full planning book lives in [`book/`](book/) (mdBook, NTRanch theme);
this repo's bloch roadmap is [`.ai/roadmap.md`](.ai/roadmap.md).

- **Delivery:** one self-contained `index.html` (see `docs` in the book).
- **Cast/art law (D-292):** existing keeper art only; a missing asset is an
  abstract stand-in, logged — never a generation job.
- **Quality bar:** Laplace3D-class animation or the medium's equivalent
  (book chapter: Quality Bar).
- **Audio:** nothing is ever played aloud by an agent; the Owner presses play.

## Play

Open [`web/index.html`](web/index.html) in a browser — it runs fully
offline, Lua core readable in the page source. Each day has six slots;
every slot offers three engagements. Book one with the arrow keys and
ENTER. Its gains go **pending** — nothing about her moves until the
appraisal witnesses the day, after slot three and again at the close.
That is when tracks tip from Stirring into Forming.

The ledger logs **contexts, not repetitions**: the first shoot of a
kind counts in full, repeats at a quarter. Attention is the day's
economy — it decays between slots, and praise programmes earn half
again while a recorded context (a set, a feed, a tape) is still warm.

- **Day One — The Shoot:** form 1 track, hold 300 attention.
- **Day Two — The Appearance:** form 2, 450 attention, 6 contexts.
- **Day Three — The Set:** form 3, 600 attention, 6 contexts.

Settings (pace, text size) and the written record — days closed, best
formation — persist in the browser. Settings are reachable before any
play.

## Preview videos (rendered from the shipped core, demo mode)

- [Day One — The Shoot](docs/previews/level-1-exposure.mp4)
- [Day Two — The Appearance](docs/previews/level-2-exposure.mp4)
- [Day Three — The Set](docs/previews/level-3-exposure.mp4)

## Build & verify

```sh
just build   # assemble web/index.html (wasmoon + readable Lua core)
just check   # 14 busted specs, bridges, perf budget, playtest
just previews
```

Status: **v1.0.0** (2026-10-30) — playable, gated, tagged. The seahawk
playtest pass on primo and the live itch.io entry checks (GJ-07) remain
scheduled follow-ups; both are recorded in `docs/BREAKAGE-LOG.md`.
