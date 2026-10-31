# Lua — W9 *Quartermaster* + W13 *Exposure*

**Language:** Lua (PUC-Rio Lua, MIT — https://www.lua.org/license.html), game logic
only, running as **readable Lua source** on an embedded Lua VM inside the jam's single
HTML file.
**Weeks:** W9 *Quartermaster* (Sloane — *Drilled*: positions called, held, appraised;
protocol tables, recall sets, appraisal bookkeeping) and W13 *Exposure* (Lux — a
one-day schedule sim: development tracks, the exposure ledger logged by distinct
contexts, Stirring → Forming witnessed as an event).
**Role in the program:** Lua is the estate's scripting idiom (the Diver config's
language) and the natural home of table-and-ledger work. These two weeks test whether
that idiom carries a whole game: in W9 the drill *is* a script and the protocol *is* a
table; in W13 the day *is* a ledger with a UI on it. Both weeks return a Lua verdict
(table-driven protocol work; ledger/track scripting) with their port-back.

## Delivery shape and the named seams

The jam's single-file rule holds: one self-contained `index.html`, no external assets.
The Lua weeks' shape, fixed by D-336:

- **Game logic ships as readable Lua source** — the actual `.lua` files, embedded as
  text in the page and executed by the in-page VM. Legibility is a feature: Gameotron
  grades documented process, and a judge can read the drill tables and the exposure
  ledger in the shipped artifact.
- **Lua renders nothing and plays no audio.** Presentation is a thin JS shell —
  DOM/Canvas for text and portraits, **PixiJS** (MIT, WebGL/WebGPU 2D renderer —
  https://pixijs.com/blog/pixi-universe; licence and maturity survey:
  https://wpdean.com/what-is-pixijs/) for sprite/portrait layers, WebAudio for sound.
  Lua emits *presentation intents* (show line, set expression F-03, move track bar,
  play cue) through a narrow bridge; the shell executes them. Every system that
  matters — drill state, appraisal evidence, tracks, ledger — lives in Lua where it
  can be unit-tested headlessly.
- **Not LÖVE.** LÖVE/love.js would make Lua the whole runtime (its own renderer, its
  own frame loop) — a different architecture from the program's shell-and-core shape,
  and not the thing being validated. Lua-based narrative runtimes below note LÖVE
  support where it exists, but for these weeks LÖVE is named and set aside: the shell
  is JS by design.

**The VM choice is the week's first preflight decision** (see (g)); the recommendation
is **wasmoon**, with Fengari as the recorded fallback, for reasons given there.

## Parts matrix

### (a) 2D rendering

| Candidate | Verdict |
|---|---|
| **Lua itself** | **NONE — by design.** Lua has no renderer; any Lua-side "graphics library" would be bindings to a host the single-file page doesn't have. Stating this plainly is the point of the Lua shape: logic/presentation separation is total. |
| **PixiJS** (JS shell) | **Adopted for sprite/portrait layers.** Mature (v8 line, active releases), MIT, GPU-batched 2D with scene graph, sprites, and filters — the shell's portrait staging, track-bar UI, and ledger book all draw here or in DOM. Lua drives it through intents (`stage.show{who="sloane", face="F-03"}`), never through direct object access. |
| **DOM/CSS** (JS shell) | **Adopted for text.** Drill calls, recall prompts, ledger entries, and the book of record are text; DOM text is selectable, accessible, and free. The kinetic-UI layer (typewriter timing, punctuation pauses) is shell JS implementing an estate spec, fed line-by-line from Lua. |
| Canvas 2D raw | Fallback if Pixi's inlined size ever threatens the file budget; not the plan. |

### (b) Skeletal / puppet animation

| Candidate | Verdict |
|---|---|
| **In-Lua skeletal/puppet runtime** | **NONE worth adopting.** No maintained Lua skeletal runtime exists for a browser host; the Lua game-engine runtimes that do exist (Defold's, LÖVE's ecosystem) belong to architectures this shape excludes. |
| **Data-driven parameter playback** (custom, shell-executed) | **Adopted.** The estate's own model already fits: a character is a parameter set (the Torogao rig layer's face/body parameters), Lua computes parameter *values* per tick from its state machines (drill hold → posture parameter; track movement → expression bias), and the shell interpolates and draws layered portrait parts (Pixi containers per part, transforms from the parameter set). Secondary motion (breath, sway) is a Lua-side oscillator table — deterministic, seeded, testable. What Lua contributes is the *choreography logic*; the shell contributes pixels. |
| **Cubism SDK for Web** (Live2D Inc.) | **Named, not adopted for these weeks.** An official web runtime for Cubism models exists (listed among the Cubism SDKs: https://docs.live2d.com/en/cubism-sdk-manual/cubism-core/), and if a future Lua week needs a true Live2D model, the shell would host it and Lua would drive its parameters through the bridge. W9/W13 use estate parameter data, not .moc3 models, and the proprietary Core + publication licence is weight these weeks don't need. |
| Flipbook strips | For any frame-animated element (a gesture strip), the shell plays estate-baked strips; Lua selects and times them. Honest ceiling: see the quality bar. |

### (c) Audio

| Candidate | Verdict |
|---|---|
| **Lua-side audio library** | **NONE.** As with rendering, there is no in-page Lua audio path; pretending otherwise would hide the bridge. |
| **WebAudio via Howler.js** (JS shell) | **Adopted.** Howler.js (goldfire, MIT — https://github.com/goldfire/howler.js.git) is the mature single-API WebAudio/HTML5-audio wrapper: audio sprites, caching, codec fallback. Lua emits cue intents with estate timing (`cue{at="on_hold", sound="brush_tap"}`); the shell owns the clock that must hit the sync bar, because only the shell is close enough to the audio hardware. |
| Command/response timing | W9's call-and-hold is audio-led (the call *is* the game input's clock). The timing contract — call lands, hold window opens — is specified in Lua data and executed by the shell; measured sync is reported from the shell side in the week's evidence. Estate audio-silence rule applies throughout development: cues verified by file metrics, never played aloud by an agent. |

### (d) Dialogue / narrative

First, a correction the research owes the reader: **"inklecate" is not a Lua port of
ink.** Inklecate is inkle's *compiler* (ink source → ink JSON, C#). The Lua side of the
ink ecosystem is two real runtimes:

| Candidate | Verdict |
|---|---|
| **Tinta** (smwhr) | **Adopted if ink is used.** A pure-Lua ink runtime, a close port of the original C# runtime — threads, flows, external functions included — rated ink-compatible (⭐) in inkle's own library (https://github.com/smwhr/tinta; listing: https://github.com/inkle/ink-library, via https://awesome.ecosyste.ms/projects/github.com%2Finkle%2Fink-library). Targets Lua 5.4 (which is why it cannot run inside LÖVE's 5.1 — irrelevant here, our VM is 5.4), 1.0.0 released 2024 (https://devforum.play.date/t/tinta-another-ink-language-runtime-for-the-playdate/16848). Known trade: it mimics the C# structure and is slower than Narrator on simple stories — irrelevant at VN line rates. |
| **Narrator** (astrochili) | **Named alternative.** Pure-Lua ink parser + runtime, faster on simple cases, smaller feature surface; parses ink to a Lua-table "book" at build time (its `lpeg` dependency is a build-time tool only — pre-parse the books, ship the tables, and no parser ships in the page) (https://github.com/astrochili/narrator; https://forum.defold.com/t/narrator-the-ink-narrative-scripting-language-runtime/65653). Choose Narrator if the week's ink stays simple and build-time parsing is acceptable; Tinta if runtime fidelity matters. For W9/W13 — short, state-heavy scripts — either works; Tinta is the default. |
| **Native Lua tables** (no narrative library) | **Adopted for W9's drill script; co-adopted W13.** Honestly: the drill script and the day schedule are *already* Lua data — position tables, recall sets, schedule slots with condition functions. A narrative library earns its keep on prose branching; W9's branching is protocol branching, and hand-rolled tables are more readable in the shipped source (the week's legibility feature). W13's scene text can ride Tinta where prose flow dominates. The decision is per-week and recorded in each week's preflight. |
| inklecate (build-time) | If ink is used, inklecate runs **at build time only** to produce ink JSON for Tinta. It never ships, and no Lua code "ports" it. |

### (e) State machines / protocol tables

| Candidate | Verdict |
|---|---|
| **Lua tables + metatable-light machine modules** | **Adopted — this is the idiom being validated.** A protocol in Lua is a table: positions with hold durations and appraisal criteria; a track definition with its contexts and drift cap; a state machine as a transition table keyed by (state, event) with guard functions. No framework competes with the language itself here, and the week's verdict *is* the measurement of that claim. Small helper libraries were surveyed (state-machine micro-libs on LuaRocks) and rejected: each is a thin wrapper over exactly this table pattern, adding a dependency to save ~40 lines. |
| Class libraries (middleclass etc.) | Not adopted. The modules use plain tables and closures; OO ceremony is not what these weeks test. |

### (f) Persistence

| Candidate | Verdict |
|---|---|
| **Shell `localStorage` via bridge** | **Adopted.** Lua serialises its record (appraisal evidence, ledger, track states) to a JSON string through a tiny hand-written serializer (tables here are data-only by discipline — no functions in saved state), the shell stores it. Save schema is shared verbatim with the C++/UE weeks' book-of-record schema so records inter-operate across the program. |
| In-Lua serialisation libraries (inspect/binser class) | Not adopted; the data-only discipline makes the hand serializer ~60 lines and auditable in the shipped source — a feature under the legibility rule. |

### (g) VM options, build tooling, and testing

The VM comparison the W9 preflight must run (all four options verified to exist):

| Option | What it is | Lua version | Size / speed (as reported by the projects) | Maturity | Verdict |
|---|---|---|---|---|---|
| **wasmoon** (ceifa) | The official PUC Lua C implementation compiled to WebAssembly (Emscripten) with TypeScript JS bindings (https://www.skypack.dev/view/wasmoon; source survey: https://deepwiki.com/ceifa/wasmoon) | **5.4** | Wasm-fast for pure Lua; wasmoon's own README notes Fengari is *lighter*, and that heavy JS↔Lua interop can erase the speed edge — our bridge is deliberately narrow (intents out, events in), so pure-Lua speed dominates | Actively maintained npm package; the maintained wasm option | **RECOMMENDED.** Real Lua 5.4 (Tinta-compatible), fastest logic, and the glue wasm base64-inlines into the single file like every other week's module. |
| **Fengari** (fengari-lua) | A Lua VM *rewritten in JavaScript* (ES6), port of the C implementation with C-API-shaped JS bindings; `fengari-web` packages it for browsers (README: https://cdn.jsdelivr.net/npm/fengari@0.1.5/README.md; architecture: https://deepwiki.com/fengari-lua/fengari) | **5.3** | Smallest footprint (third-party benchmarks put it ≈69 kB gzipped vs wasmoon ≈130 kB — https://copyprogramming.com/howto/running-a-lua-program-from-a-text-file) and the smoothest DOM interop (it *is* JS, GC-shared); noticeably slower on compute-heavy Lua | Stable but quiet: core releases are old (0.1.x line); semantics frozen at 5.3 | **Fallback.** If wasmoon's wasm or interop misbehaves in the itch iframe context, Fengari is the drop-in: pure JS, no wasm fetch/instantiation edge cases. Cost: 5.3 dialect (no integer division idioms from 5.4 code) and slower ledger math — both tolerable at this scale. |
| **lua.vm.js** (kripken) | The 2013 Emscripten/asm.js port of Lua **5.2.2** | 5.2 | asm.js-era; superseded | **Unmaintained — its own listing states "This project is superceded by Fengari"** (https://www.gitplanet.com/project/luavmjs) | **Rejected.** Historical interest only; named so nobody rediscovers it mid-week. |
| **DIY: PUC Lua 5.4 → wasm via Emscripten** | Compile lua.org's C sources (MIT — https://www.lua.org/license.html) with `emcc` ourselves, hand-write the JS bridge | 5.4 (any, incl. 5.4.x latest) | Smallest *possible* wasm (no TS binding layer); bridge is our code to debug | The Lua sources are rock-solid; *our* glue would be the least-tested component in the stack | **Rejected for the jam weeks, kept as the long-term option.** wasmoon *is* this, with the bridge already written and tested. Rebuilding it to save kilobytes spends the week's budget re-deriving a maintained project. If Lua becomes a permanent estate web runtime, revisit. |

**Build tooling:** the build is a pack script (estate tooling) that (1) runs the busted
suite, (2) syntax-checks every `.lua` with the estate's Lua 5.4 (`luac -p`), (3) inlines
VM + shell + Lua sources + assets (base64) into `index.html`, (4) records the VM choice
and version in the page's process documentation, as D-336 requires the week's preflight
to do.

**Testing: busted** (https://lunarmodules.github.io/busted/) — the standard Lua BDD
framework (Lua ≥ 5.1, LuaRocks install), run **headlessly against the real game
modules**: drill tables validate (every position has criteria; every recall set is
reachable), ledger rules hold (distinct-context counting, drift caps, no decay), T-gate
arithmetic matches canon. This is the Lua shape's superpower — the entire game logic
is testable without a browser, and the busted output ships as week evidence.
Determinism tests (fixed seed → identical day in W13, identical drill sequence in W9)
are part of the suite, per the quality bar.

## Write-from-scratch register

1. **Exposure ledger by distinct contexts (W13 core).** *Why:* "logged by distinct
   contexts, not raw repetitions" is an estate rule with no library analogue — a
   context is a (place, witness, activity-class) tuple, and a repetition in a seen
   context counts zero. *Layer:* pure Lua module over the day state. *Rides on:*
   nothing but tables; busted proves the counting rules including the adversarial
   cases (same context re-entered via a different door is still the same context).
2. **Development tracks with drift caps (W13).** *Why:* 24 tracks estate-wide, four
   per girl, movement capped (×1.5 rate, ±15% per-period drift), no decay, stages
   Stirring → Forming → Eligible → Recognised — canon arithmetic from the
   DEVELOPMENT-SYSTEM record. *Layer:* Lua track module; stage transitions are
   events the day sim *shows* (Stirring tipping into Forming is a witnessed scene
   beat, not a silent number). *Rides on:* the ledger (track movement is justified
   by ledger entries), the shell for track-bar presentation.
3. **Appraisal bookkeeping (W9 core).** *Why:* evidence logged and witnessed during
   the drill; rank moves only at the Appraisal ceremony stub, nowhere else — an
   append-only evidence ledger with witness stamps, shared schema with the UE
   weeks' book of record. *Layer:* Lua ledger module. *Rides on:* the persistence
   bridge; the ceremony is a Lua state the shell presents.
4. **Drill / protocol engine (W9).** *Why:* positions called and held, stiffness
   presets scoring the hold, Protocol Recall woven in (later positions answered
   from memory) — the game's rules are Sloane's canon, not a genre pattern.
   *Layer:* Lua state machine over the position/recall tables. *Rides on:* shell
   audio clock for call timing; face/posture parameters emitted as intents.
5. **Face-state system (both weeks, Lua side).** *Why:* as in every week, the
   F-code states are estate canon. *Layer:* Lua parameter targets + transition
   curves (the same spec the other languages implement; Lua's version is the
   data-driven playback driver in (b)). *Rides on:* the shell's interpolation —
   Lua computes, the shell smooths; the seam between them is where the ≤17 ms
   secondary-lag number is won or lost, and the week's evidence must measure it
   at the bridge, not assume it.
6. **Sex-scene staging / contact (W13's recorded set; W9's guided positions).**
   *Why:* staging and contact remain authored work in every stack. *Layer:* Lua
   scene scripts (parameter tracks + intent sequences, timed to the day clock).
   *Rides on:* estate baked strips/parameter data; no library pretends to help here.
7. **The intent bridge + serializer.** *Why:* the narrow Lua↔shell contract
   (intents out, events in, data-only saves) is an estate design decision, and its
   narrowness is what makes the wasmoon speed argument and the busted testability
   both true. *Layer:* ~150 lines Lua + ~150 lines JS. *Rides on:* the chosen VM's
   interop API.

## Quality bar — Laplace3D-class minimum, honestly applied

The floor is the program's: **60 fps; motion every frame; secondary lag ≤ 17 ms;
humanised (seeded) jitter; expression readability at delivery size; loop seam ≤ 1.1;
audio sync +12 ms ± 25 ms; determinism.**

**Lua's honest position against this bar:** the *logic* side can meet every number —
drill timing, ledger arithmetic, and determinism are pure computation, and busted can
*prove* them. The *presentation* side has a hard ceiling the report must not paper
over: the shell draws layered 2D portraits and baked strips, not a 60 fps 3D rig.
Secondary motion is oscillator-driven parameter work — good enough for breath, sway,
and held-pose life, visibly poorer than skeletal secondary motion on hair and
clothing; contact is baked, not simulated; expression readability is achievable
(F-states are parameter sets, and parameters read well in 2D), but the *richness*
between two F-states — the micro-travel Laplace-class 3D gives for free — must be
hand-authored as transition curves. Verdict these weeks can honestly earn:
**specification and systems validated at full bar; animation richness validated at
the 2D-parameter ceiling, with the gap to Laplace3D-class named, not hidden.** That
is a legitimate jam outcome — W9/W13 exist to validate tables, ledgers, and tracks,
and those are exactly the parts Lua carries at full strength.

## Risks and seams

- **VM dialect split.** wasmoon/Fengari differ (5.4 vs 5.3): game code must be
  written to the *intersection* dialect until the preflight locks the VM, or the
  fallback stops being a fallback. `luac -p` checks run under both versions in the
  build until the lock.
- **Interop cost inversion.** wasmoon's speed advantage inverts under chatty
  JS↔Lua calls (its own README warns of this). The narrow intent bridge is the
  mitigation; a week that starts calling across the bridge per-frame has broken
  the design, and the fix is batching intents, not a VM swap.
- **Single-file size.** wasmoon's glue wasm + PixiJS + assets all inline as
  base64 (+33%). The file budget is a preflight measurement, not a hope; Fengari's
  smaller footprint is the pressure valve.
- **itch iframe / wasm instantiation.** Wasm compile in an embedded iframe is
  well-supported in current browsers, but the Fengari fallback exists precisely
  because "well-supported" is not "universal"; the preflight tests the actual
  itch embed, not a local page.
- **Tinta's completeness vs speed.** Tinta is the faithful runtime and the slower
  one; at VN rates this does not matter, but a week that grows ink threads/flows
  heavily should re-run the Narrator comparison before assuming.
- **Legibility is a constraint, not a bonus.** Shipping readable Lua source means
  no minified/obfuscated logic and no clever metatable tricks that a judge (or a
  future port-back author) can't read at sight. Code review for these weeks
  includes a readability pass.
- **The shell is shared temptation.** Every Lua week could quietly grow shell-side
  game logic "just for this bit"; that logic escapes busted, escapes the verdict,
  and falsifies the port-back. Rule: if it decides anything, it lives in Lua.


## How the research applies to Exposure

- Language: **Lua** under tiger-style-lua.
- Canon core: A one-day schedule sim — a shoot, a public appearance, a recorded set.
- The parts matrix in the dossier names, for every part of the full game
  (rendering, animation, audio, dialogue/UI, state, persistence, assets,
  build), the library or tool this entry pins — or states plainly that the
  part is written from scratch (see the next chapter).
