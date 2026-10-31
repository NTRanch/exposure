-- exposure/src/main.lua — Exposure core (Lua 5.4, wasmoon seam).
--
-- Tiger Style (tiger-style-lua): explicit contracts, bounded work,
-- disciplined ownership, no hidden behaviour. The core is a fixed-step
-- deterministic simulation: the shell calls step() at 60 Hz; the core
-- never reads a wall clock and reports everything it wants drawn as a
-- draw list string. The same file runs under the estate's PUC Lua for
-- the busted specs and under wasmoon in the shipped page.
--
-- Game: Lux's one-day schedule sim. Each day offers engagements in
-- slots; picking one logs its CONTEXT in the exposure ledger (distinct
-- contexts count in full, repetitions at a quarter) and banks its
-- track gains as PENDING. Nothing moves until the day is witnessed:
-- at appraisal (midday and close) pending gains are applied to her
-- four development tracks, and a track tipping Stirring -> Forming is
-- presented as an event. Lens Toy attention is the day's economy:
-- it decays between slots, and praise programmes earn more while a
-- recorded context is still warm.

-- ---------------------------------------------------------------------------
-- Domain constants
-- ---------------------------------------------------------------------------

local CANVAS_PX = 960
local MAX_OPS = 1024
local STEP_MS = 16

-- Palette indices (shared with the shell + rasteriser; 0 = background).
local PAL = {
  BG = 0, PINK = 1, SKIN = 2, MAUVE = 3, PLUM = 4,
  ROSE = 5, PAPER = 6, DIM = 7, GOLD = 8, DEEP = 9,
}

-- Input bitset delivered by the shell each step.
local IN = { TAP = 1, CONFIRM = 2, BACK = 4, PAUSE = 8, UP = 16, DOWN = 32, LEFT = 64, RIGHT = 128 }

-- Event codes the shell sonifies; audio only ever answers input.
local EV = { NONE = 0, PICK = 1, APPLY = 2, TIPPING = 3, VICTORY = 4, GAMEOVER = 5, APPRAISE = 6 }

-- Screens (the numbering is the program-wide convention).
local SCR = { GATE = 0, TITLE = 1, HOWTO = 2, PLAY = 3, PAUSE = 4, SETTINGS = 5, VICTORY = 6, GAMEOVER = 7 }

-- Development track law (the DEVELOPMENT-SYSTEM, one-sitting scale):
-- no decay, ever; a drift cap; stage thresholds on applied totals.
local TRACK_CAP = 140
local STIR_AT = 40
local FORM_AT = 100
local STAGE_NAMES = { [0] = "DORMANT", [1] = "STIRRING", [2] = "FORMING" }

local TRACKS = {
  { key = "EXHIBITION", short = "EXHIB" },
  { key = "LENS", short = "LENS" },
  { key = "PRAISE", short = "PRAISE" },
  { key = "USE", short = "USE" },
}

-- The engagement deck. gains are per-track pending points at FULL
-- ledger weight (first logging of the context today); repeats bank a
-- quarter. praise programmes earn weighted attention while a recorded
-- context is warm.
local ENGAGEMENTS = {
  { name = "STUDIO SHOOT", ctx = "STUDIO", gains = { 34, 18, 0, 0 }, att = 120, praise = false },
  { name = "STREET APPEARANCE", ctx = "STREET", gains = { 26, 0, 14, 0 }, att = 140, praise = false },
  { name = "RECORDED SET", ctx = "SET", gains = { 0, 36, 0, 12 }, att = 130, praise = false },
  { name = "LENS TOY LIVE", ctx = "LENSFEED", gains = { 0, 24, 20, 0 }, att = 185, praise = true },
  { name = "GALLERY OPENING", ctx = "GALLERY", gains = { 16, 0, 30, 0 }, att = 110, praise = true },
  { name = "FAN SESSION", ctx = "FANS", gains = { 0, 0, 16, 30 }, att = 120, praise = false },
  { name = "WINDOW DISPLAY", ctx = "WINDOW", gains = { 30, 0, 0, 14 }, att = 160, praise = false },
  { name = "INTERVIEW TAPE", ctx = "TAPE", gains = { 0, 28, 18, 0 }, att = 100, praise = false },
  { name = "PRIVATE VIEWING", ctx = "PRIVATE", gains = { 12, 0, 0, 34 }, att = 90, praise = false },
}

-- Contexts that count as recorded (they warm the praise weighting).
local RECORDED = { SET = true, LENSFEED = true, TAPE = true }

-- The three days. base = the archive the written record carries into
-- the day (starting a later day standalone banks its priors, the way
-- the campaign would have earned them).
local DAYS = {
  { name = "DAY ONE - THE SHOOT", base = { 0, 0, 0, 0 }, formed = 1, attention = 300, contexts = 0 },
  { name = "DAY TWO - THE APPEARANCE", base = { 50, 45, 40, 35 }, formed = 2, attention = 450, contexts = 6 },
  { name = "DAY THREE - THE SET", base = { 85, 85, 60, 60 }, formed = 3, attention = 600, contexts = 6 },
}
local DAY_COUNT = 3
local SLOTS_PER_DAY = 6
local APPRAISE_AFTER = 3 -- midday appraisal follows this slot

-- ---------------------------------------------------------------------------
-- Deterministic RNG (xorshift32; same family as the other jam cores)
-- ---------------------------------------------------------------------------

local function rng_new(seed)
  if seed == 0 then seed = 0x9E3779B9 end
  return { state = seed & 0xFFFFFFFF }
end

local function rng_next(r)
  local x = r.state
  x = x ~ ((x << 13) & 0xFFFFFFFF)
  x = x ~ (x >> 17)
  x = x ~ ((x << 5) & 0xFFFFFFFF)
  r.state = x & 0xFFFFFFFF
  return r.state
end

local function rng_range(r, lo, hi)
  return lo + (rng_next(r) % (hi - lo + 1))
end

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local S = nil -- the one current game (the shell owns exactly one)

local function stage_of(total)
  if total >= FORM_AT then return 2 end
  if total >= STIR_AT then return 1 end
  return 0
end

local function new_game(seed, demo)
  local g = {
    rng = rng_new(seed),
    demo = demo and true or false,
    screen = SCR.GATE,
    screen_ms = 0,
    level_idx = 0,
    title_level = 0,
    menu_cursor = 0,
    -- settings + archive bridges
    pace_quick = false,
    text_large = false,
    archive_days = 0,
    archive_best = 0,
    event_code = EV.NONE,
    caption = "",
    caption_ms = 0,
    -- day state (reset by start_level)
    totals = { 0, 0, 0, 0 },
    pending = { 0, 0, 0, 0 },
    attention = 0,
    ledger = {},
    ledger_count = 0,
    slot = 0,
    phase = "choose", -- choose | outcome | appraise
    phase_ms = 0,
    deck = {},
    offers = {},
    card_cursor = 0,
    last_recorded_slot = -10,
    appraise_queue = {},
    appraise_close = false,
    formed_count = 0,
  }
  return g
end

local function set_screen(g, s)
  g.screen = s
  g.screen_ms = 0
  g.menu_cursor = 0
end

local function set_caption(g, text, ms)
  g.caption = text
  g.caption_ms = ms
end

-- ---------------------------------------------------------------------------
-- The day: deck, picks, ledger, appraisal
-- ---------------------------------------------------------------------------

local function reshuffle(g)
  g.deck = {}
  for i = 1, #ENGAGEMENTS do g.deck[i] = i end
  for i = #g.deck, 2, -1 do
    local j = rng_range(g.rng, 1, i)
    g.deck[i], g.deck[j] = g.deck[j], g.deck[i]
  end
end

local function draw_offers(g)
  -- Offers are the deck's front three. The two unpicked return to the
  -- back of the deck when a pick is made, so the day cycles through
  -- every context before any context is offered twice.
  g.offers = {}
  for k = 1, 3 do
    g.offers[k] = g.deck[k]
  end
  g.card_cursor = 0
end

local function formed_count(g)
  local n = 0
  for t = 1, 4 do
    if stage_of(g.totals[t]) >= 2 then n = n + 1 end
  end
  return n
end

-- Ledger law: a context logged for the first time today banks its
-- gains in full; a repetition banks a quarter (floored, min 0).
local function ledger_weight(g, ctx)
  if g.ledger[ctx] then return 0.25 end
  return 1.0
end

local function pick_card(g, offer_idx)
  local eng = ENGAGEMENTS[g.offers[offer_idx]]
  -- Retire the picked card for the day; the unpicked offers go to the
  -- back of the deck.
  local rest = {}
  for k = 1, 3 do
    if k ~= offer_idx then rest[#rest + 1] = g.offers[k] end
  end
  for i = 1, #rest do g.deck[#g.deck + 1] = rest[i] end
  for _ = 1, 3 do table.remove(g.deck, 1) end
  local first = not g.ledger[eng.ctx]
  if first then
    g.ledger[eng.ctx] = true
    g.ledger_count = g.ledger_count + 1
  end
  local w = first and 1.0 or 0.25
  local parts = {}
  for t = 1, 4 do
    local gain = math.floor(eng.gains[t] * w)
    if gain > 0 then
      g.pending[t] = g.pending[t] + gain
      parts[#parts + 1] = TRACKS[t].short .. " +" .. gain
    end
  end
  -- Attention economy: praise weighting while a recorded context is
  -- warm (within two slots), or when the programme itself is recorded.
  local att = eng.att
  local warm = (g.slot - g.last_recorded_slot <= 2) or RECORDED[eng.ctx] == true
  if eng.praise and warm then
    att = (att * 3) // 2
  end
  g.attention = math.min(1000, g.attention + att)
  if RECORDED[eng.ctx] then g.last_recorded_slot = g.slot end
  local head = first and (eng.ctx .. " LOGGED. ") or (eng.ctx .. " AGAIN - QUARTER. ")
  set_caption(g, head .. table.concat(parts, " ") .. " PENDING", 2600)
  g.event_code = EV.PICK
end

local function begin_appraisal(g, is_close)
  g.phase = "appraise"
  g.phase_ms = 0
  g.appraise_close = is_close
  g.appraise_queue = {}
  for t = 1, 4 do
    if g.pending[t] > 0 then g.appraise_queue[#g.appraise_queue + 1] = t end
  end
  g.event_code = EV.APPRAISE
  if #g.appraise_queue == 0 then
    set_caption(g, "THE DAY IS WITNESSED. NOTHING WAS WAITING.", 1500)
  else
    set_caption(g, "THE DAY IS WITNESSED. NOW IT MOVES.", 1500)
  end
end

-- Apply one queued track's pending gains. The drift cap binds here:
-- what does not fit under the cap is gone, and the record says so.
local function apply_next(g)
  local t = table.remove(g.appraise_queue, 1)
  if not t then return false end
  local before = stage_of(g.totals[t])
  local want = g.pending[t]
  local fits = math.min(want, TRACK_CAP - g.totals[t])
  g.totals[t] = g.totals[t] + fits
  g.pending[t] = 0
  local after = stage_of(g.totals[t])
  local name = TRACKS[t].key
  if after > before then
    g.event_code = EV.TIPPING
    if after == 2 then
      set_caption(g, name .. " TIPS INTO FORMING.", 2400)
    else
      set_caption(g, name .. " STIRS. THE ROOM NOTICES.", 2000)
    end
  else
    g.event_code = EV.APPLY
    local msg = name .. " +" .. fits .. " - NOW " .. g.totals[t] .. "."
    if fits < want then msg = msg .. " THE REST DRIFTS OFF." end
    set_caption(g, msg, 1600)
  end
  return true
end

local function close_day(g)
  local day = DAYS[g.level_idx + 1]
  local formed = formed_count(g)
  g.formed_count = formed
  local won = formed >= day.formed
    and g.attention >= day.attention
    and g.ledger_count >= day.contexts
  if won then
    g.event_code = EV.VICTORY
    set_screen(g, SCR.VICTORY)
  else
    g.event_code = EV.GAMEOVER
    set_screen(g, SCR.GAMEOVER)
  end
end

local function finish_appraisal(g)
  if g.appraise_close then
    close_day(g)
  else
    g.phase = "choose"
    g.slot = g.slot + 1
    draw_offers(g)
  end
end

local function end_outcome(g)
  -- Attention decays at every slot boundary (the Lens Toy curve).
  g.attention = (g.attention * 88) // 100
  if g.slot == APPRAISE_AFTER then
    begin_appraisal(g, false)
  elseif g.slot >= SLOTS_PER_DAY then
    begin_appraisal(g, true)
  else
    g.phase = "choose"
    g.slot = g.slot + 1
    draw_offers(g)
  end
end

-- ---------------------------------------------------------------------------
-- Public interface (the shell's whole contract; the specs use it too)
-- ---------------------------------------------------------------------------

local M = {}

function M.init(seed, level, demo)
  if level < 0 or level >= DAY_COUNT then return 1 end
  S = new_game(seed, demo)
  S.title_level = level
  return 0
end

function M.start_level(idx)
  if not S then return 1 end
  if idx < 0 or idx >= DAY_COUNT then return 1 end
  local day = DAYS[idx + 1]
  S.level_idx = idx
  for t = 1, 4 do
    S.totals[t] = day.base[t]
    S.pending[t] = 0
  end
  S.attention = 0
  S.ledger = {}
  S.ledger_count = 0
  S.slot = 1
  S.phase = "choose"
  S.phase_ms = 0
  S.last_recorded_slot = -10
  S.appraise_queue = {}
  S.formed_count = formed_count(S)
  reshuffle(S)
  draw_offers(S)
  set_caption(S, "THE DAY OPENS. SIX SLOTS. CHOOSE WHAT SHE IS SEEN DOING.", 3000)
  set_screen(S, SCR.PLAY)
  return 0
end

function M.screen()
  return S and S.screen or SCR.GATE
end

function M.level_idx()
  return S and S.level_idx or 0
end

function M.event_code()
  return S and S.event_code or EV.NONE
end

function M.apply_settings(pace_quick, text_large)
  if not S then return end
  S.pace_quick = pace_quick and true or false
  S.text_large = text_large and true or false
end

function M.settings_bits()
  if not S then return 0 end
  return (S.pace_quick and 1 or 0) + (S.text_large and 2 or 0)
end

function M.apply_archive(days, best)
  if not S then return end
  S.archive_days = math.max(0, math.min(days, 999))
  S.archive_best = math.max(0, math.min(best, 4))
end

function M.archive_days()
  return S and S.archive_days or 0
end

function M.formed_count()
  if not S then return 0 end
  return formed_count(S)
end

function M.archive_best()
  return S and S.archive_best or 0
end

--- Test hook: the raw state table, for the specs.
function M._state()
  return S
end

--- Test hook: replace the current offers (specs only — the deck's
--- RNG order is an implementation detail the laws should not ride on).
function M._force_offers(a, b, c)
  if not S then return end
  S.offers = { a, b, c }
  S.card_cursor = 0
end

-- ---------------------------------------------------------------------------
-- Stepping: menus, the day, the demo policy
-- ---------------------------------------------------------------------------

local function outcome_ms(g)
  return g.pace_quick and 700 or 1400
end

local function appraise_ms(g)
  return g.pace_quick and 420 or 800
end

local function step_play(g, dt, inp)
  if (inp & IN.PAUSE) ~= 0 then
    set_screen(g, SCR.PAUSE)
    return
  end
  g.phase_ms = g.phase_ms + dt
  if g.phase == "choose" then
    if (inp & IN.LEFT) ~= 0 or (inp & IN.UP) ~= 0 then
      g.card_cursor = (g.card_cursor + 2) % 3
    end
    if (inp & IN.RIGHT) ~= 0 or (inp & IN.DOWN) ~= 0 then
      g.card_cursor = (g.card_cursor + 1) % 3
    end
    if (inp & (IN.CONFIRM | IN.TAP)) ~= 0 then
      pick_card(g, g.card_cursor + 1)
      g.phase = "outcome"
      g.phase_ms = 0
    end
  elseif g.phase == "outcome" then
    if g.phase_ms >= outcome_ms(g) then
      g.phase_ms = 0
      end_outcome(g)
    end
  elseif g.phase == "appraise" then
    local advance = (inp & (IN.CONFIRM | IN.TAP)) ~= 0
    if advance or g.phase_ms >= appraise_ms(g) then
      g.phase_ms = 0
      if #g.appraise_queue > 0 then
        apply_next(g)
      elseif g.caption_ms <= 0 then
        finish_appraisal(g)
      end
    end
  end
end

local TITLE_ITEMS = 3 -- BEGIN / THE BRIEF / SETTINGS; row 3 = day picker

local function step_title(g, inp)
  if (inp & IN.DOWN) ~= 0 then g.menu_cursor = math.min(g.menu_cursor + 1, 3) end
  if (inp & IN.UP) ~= 0 then g.menu_cursor = math.max(g.menu_cursor - 1, 0) end
  if (inp & (IN.CONFIRM | IN.TAP)) ~= 0 then
    if g.menu_cursor == 0 then
      M.start_level(g.title_level)
    elseif g.menu_cursor == 1 then
      set_screen(g, SCR.HOWTO)
    elseif g.menu_cursor == 2 then
      set_screen(g, SCR.SETTINGS)
    else
      g.title_level = (g.title_level + 1) % DAY_COUNT
    end
  end
end

local function step_pause(g, inp)
  if (inp & IN.DOWN) ~= 0 then g.menu_cursor = math.min(g.menu_cursor + 1, 2) end
  if (inp & IN.UP) ~= 0 then g.menu_cursor = math.max(g.menu_cursor - 1, 0) end
  if (inp & IN.PAUSE) ~= 0 then
    set_screen(g, SCR.PLAY)
    return
  end
  if (inp & (IN.CONFIRM | IN.TAP)) ~= 0 then
    if g.menu_cursor == 0 then
      set_screen(g, SCR.PLAY)
    elseif g.menu_cursor == 1 then
      M.start_level(g.level_idx)
    else
      set_screen(g, SCR.TITLE)
    end
  end
end

local function step_settings(g, inp)
  if (inp & IN.DOWN) ~= 0 then g.menu_cursor = math.min(g.menu_cursor + 1, 2) end
  if (inp & IN.UP) ~= 0 then g.menu_cursor = math.max(g.menu_cursor - 1, 0) end
  if (inp & IN.BACK) ~= 0 then
    set_screen(g, SCR.TITLE)
    return
  end
  if (inp & (IN.CONFIRM | IN.TAP)) ~= 0 then
    if g.menu_cursor == 0 then
      g.pace_quick = not g.pace_quick
    elseif g.menu_cursor == 1 then
      g.text_large = not g.text_large
    else
      set_screen(g, SCR.TITLE)
    end
  end
end

-- The demo policy: a player with full information. It scores each
-- offered card by need (tracks still short of Forming weigh most),
-- the day's attention goal, and ledger novelty; appraisals and
-- outcomes advance on their timers.
local function demo_policy(g)
  if g.screen == SCR.GATE then
    return g.screen_ms > 600 and IN.CONFIRM or 0
  end
  if g.screen == SCR.TITLE then
    return g.screen_ms > 700 and IN.CONFIRM or 0
  end
  if g.screen == SCR.VICTORY or g.screen == SCR.GAMEOVER then
    return g.screen_ms > 1500 and IN.CONFIRM or 0
  end
  if g.screen ~= SCR.PLAY then return 0 end
  if g.phase ~= "choose" then return 0 end
  local day = DAYS[g.level_idx + 1]
  local best_idx, best_score = 1, -1
  for k = 1, 3 do
    local eng = ENGAGEMENTS[g.offers[k]]
    local w = ledger_weight(g, eng.ctx)
    local score = 0
    for t = 1, 4 do
      local gain = math.floor(eng.gains[t] * w)
      local reach = g.totals[t] + g.pending[t]
      if stage_of(reach) < 2 then
        local need = math.max(0, FORM_AT - reach)
        score = score + math.min(gain, need + 20) * 3
        -- Crossing a threshold is the day's real currency: a pick
        -- that finishes a Forming outweighs two that merely add.
        if reach < FORM_AT and reach + gain >= FORM_AT then score = score + 220 end
        if reach < STIR_AT and reach + gain >= STIR_AT then score = score + 60 end
      else
        score = score + gain * 0.25
      end
    end
    if g.attention < day.attention then
      -- Score the attention the pick will REALLY bank, praise
      -- weighting included, and weigh a shortfall heavily: a day
      -- lost on attention is lost outright.
      local eff = eng.att
      local warm = (g.slot - g.last_recorded_slot <= 2) or RECORDED[eng.ctx] == true
      if eng.praise and warm then eff = (eff * 3) // 2 end
      score = score + eff * 1.2
    end
    if not g.ledger[eng.ctx] then
      -- Novelty is worth more while the day's ledger goal is unmet:
      -- a repeated context can lose the day outright.
      score = score + (g.ledger_count < day.contexts and 90 or 30)
    end
    if eng.praise then score = score + 12 end
    if score > best_score then
      best_score = score
      best_idx = k
    end
  end
  if best_idx - 1 == g.card_cursor then return IN.CONFIRM end
  -- Move the cursor one step toward the target card.
  local cur = g.card_cursor
  local tgt = best_idx - 1
  if (tgt - cur) % 3 == 1 then return IN.RIGHT end
  return IN.LEFT
end

function M.step(dt_ms, inp)
  if not S then return EV.NONE end
  local dt = math.min(math.max(dt_ms, 0), 50)
  S.event_code = EV.NONE
  local bits = S.demo and demo_policy(S) or inp
  S.screen_ms = S.screen_ms + dt
  if S.caption_ms > 0 then S.caption_ms = S.caption_ms - dt end
  local scr = S.screen
  if scr == SCR.GATE then
    if (bits & (IN.CONFIRM | IN.TAP)) ~= 0 then set_screen(S, SCR.TITLE) end
  elseif scr == SCR.TITLE then
    step_title(S, bits)
  elseif scr == SCR.HOWTO then
    if (bits & (IN.BACK | IN.CONFIRM)) ~= 0 then set_screen(S, SCR.TITLE) end
  elseif scr == SCR.PLAY then
    step_play(S, dt, bits)
  elseif scr == SCR.PAUSE then
    step_pause(S, bits)
  elseif scr == SCR.SETTINGS then
    step_settings(S, bits)
  elseif scr == SCR.VICTORY or scr == SCR.GAMEOVER then
    if (bits & (IN.CONFIRM | IN.TAP)) ~= 0 then set_screen(S, SCR.TITLE) end
  end
  return S.event_code
end

-- ---------------------------------------------------------------------------
-- Rendering: the draw list (one op per line, the program protocol)
-- ---------------------------------------------------------------------------

local function text_size(g, base)
  if g.text_large then return (base * 5) // 4 end
  return base
end

local function render(g)
  local lines = {}
  local ops = 0
  local function add(s)
    if ops >= MAX_OPS then return end
    ops = ops + 1
    lines[#lines + 1] = s
  end
  local function rect(x, y, w, h, c) add("r " .. x .. " " .. y .. " " .. w .. " " .. h .. " " .. c) end
  local function circ(x, y, r, c) add("c " .. x .. " " .. y .. " " .. r .. " " .. c) end
  local function line(x1, y1, x2, y2, c, w) add("l " .. x1 .. " " .. y1 .. " " .. x2 .. " " .. y2 .. " " .. c .. " " .. w) end
  local function tri(x1, y1, x2, y2, x3, y3, c) add("p " .. x1 .. " " .. y1 .. " " .. x2 .. " " .. y2 .. " " .. x3 .. " " .. y3 .. " " .. c) end
  local function text(x, y, size, c, s) add("t " .. x .. " " .. y .. " " .. size .. " " .. c .. " " .. s) end

  local function room()
    rect(0, 0, CANVAS_PX, CANVAS_PX, PAL.BG)
    for i = 0, 39 do
      circ((i * 397 + 53) % 940 + 10, (i * 613 + 91) % 940 + 10, 2, PAL.DIM)
    end
    line(40, 845, 920, 845, PAL.PLUM, 3)
  end

  local function figure(cx)
    local poise = 0
    for t = 1, 4 do
      if stage_of(g.totals[t]) >= 1 then poise = poise + 1 end
    end
    local head_y = 380 - 4 * poise
    tri(cx - 115, 845, cx + 115, 845, cx, 505, PAL.PLUM)
    rect(cx - 50, 488, 100, 88, PAL.ROSE)
    circ(cx, head_y - 20, 100, PAL.PLUM)
    circ(cx, head_y, 88, PAL.SKIN)
    line(cx - 52, head_y - 74, cx - 24, head_y - 92, PAL.MAUVE, 5)
    line(cx + 28, head_y - 88, cx + 55, head_y - 70, PAL.MAUVE, 5)
    local blush = 8 + 4 * poise
    circ(cx - 46, head_y + 28, blush, PAL.ROSE)
    circ(cx + 46, head_y + 28, blush, PAL.ROSE)
    if poise >= 3 then
      -- Forming reads in the eyes: lidded, direct.
      line(cx - 44, head_y - 6, cx - 16, head_y - 2, PAL.BG, 4)
      line(cx + 16, head_y - 2, cx + 44, head_y - 6, PAL.BG, 4)
      line(cx - 10, head_y + 48, cx + 10, head_y + 46, PAL.PLUM, 4)
    else
      circ(cx - 30, head_y - 6, 7, PAL.BG)
      circ(cx + 30, head_y - 6, 7, PAL.BG)
      circ(cx, head_y + 48, 5 + poise, PAL.BG)
    end
    rect(cx - 24, 472, 48, 10, PAL.GOLD)
    -- Halo of witness: one dotted ring per track that has stirred.
    for t = 1, 4 do
      if stage_of(g.totals[t]) >= 1 then
        local rr = 118 + (t - 1) * 13
        local c = stage_of(g.totals[t]) >= 2 and PAL.PINK or PAL.GOLD
        for k = 0, 11 do
          local a = k / 12.0 * 6.2832
          circ(cx + math.floor(math.cos(a) * rr), head_y + math.floor(math.sin(a) * rr), 3, c)
        end
      end
    end
  end

  local function tracks_panel()
    text(610, 150, text_size(g, 20), PAL.MAUVE, "HER FOUR TRACKS")
    for t = 1, 4 do
      local y = 195 + (t - 1) * 92
      local total = g.totals[t]
      local st = stage_of(total)
      local sc = (st == 2 and PAL.PINK) or (st == 1 and PAL.GOLD) or PAL.DIM
      text(610, y, text_size(g, 20), PAL.PAPER, TRACKS[t].key)
      text(800, y, text_size(g, 20), sc, STAGE_NAMES[st])
      rect(610, y + 34, 300, 14, PAL.DEEP)
      local fill = (total * 300) // TRACK_CAP
      if fill > 0 then rect(610, y + 34, fill, 14, sc) end
      -- Forming threshold tick at FORM_AT.
      local tick = 610 + (FORM_AT * 300) // TRACK_CAP
      line(tick, y + 30, tick, y + 52, PAL.GOLD, 2)
      if g.pending[t] > 0 then
        text(610, y + 56, text_size(g, 18), PAL.GOLD, "+" .. g.pending[t] .. " PENDING - UNWITNESSED")
      end
    end
  end

  local function play()
    room()
    local day = DAYS[g.level_idx + 1]
    text(36, 28, text_size(g, 26), PAL.PAPER, day.name)
    text(36, 64, text_size(g, 20), PAL.MAUVE, "SLOT " .. g.slot .. " OF " .. SLOTS_PER_DAY)
    for sIdx = 1, SLOTS_PER_DAY do
      local c = sIdx < g.slot and PAL.PINK or (sIdx == g.slot and PAL.GOLD or PAL.DEEP)
      rect(200 + (sIdx - 1) * 26, 66, 18, 12, c)
    end
    text(560, 28, text_size(g, 22), PAL.MAUVE, "ATTENTION")
    rect(560, 60, 230, 14, PAL.DEEP)
    local afill = (g.attention * 230) // 1000
    if afill > 0 then rect(560, 60, afill, 14, PAL.PINK) end
    text(806, 24, text_size(g, 26), PAL.PAPER, "" .. g.attention)
    text(560, 88, text_size(g, 18), PAL.MAUVE, "LEDGER: " .. g.ledger_count .. " CONTEXTS")
    text(36, 100, text_size(g, 18), PAL.MAUVE, "GOAL " .. day.attention .. " / " .. day.formed .. " FORMING")
    figure(280)
    tracks_panel()
    if g.phase == "choose" then
      for k = 1, 3 do
        local eng = ENGAGEMENTS[g.offers[k]]
        local x = 40 + (k - 1) * 300
        local y = 640
        rect(x, y, 280, 185, PAL.DEEP)
        local bc = (g.card_cursor == k - 1) and PAL.PINK or PAL.PLUM
        line(x, y, x + 280, y, bc, 4)
        line(x, y + 185, x + 280, y + 185, bc, 4)
        if g.card_cursor == k - 1 then text(x + 8, y + 10, text_size(g, 22), PAL.PINK, ">") end
        text(x + 34, y + 10, text_size(g, 20), PAL.PAPER, eng.name)
        local tag = "CTX " .. eng.ctx
        if eng.praise then tag = tag .. " - PRAISE" end
        text(x + 16, y + 44, text_size(g, 17), PAL.GOLD, tag)
        local gl = {}
        for t = 1, 4 do
          if eng.gains[t] > 0 then gl[#gl + 1] = TRACKS[t].short .. " +" .. eng.gains[t] end
        end
        text(x + 16, y + 76, text_size(g, 18), PAL.PAPER, gl[1] or "")
        text(x + 16, y + 102, text_size(g, 18), PAL.PAPER, gl[2] or "")
        text(x + 16, y + 130, text_size(g, 18), PAL.MAUVE, "ATTENTION +" .. eng.att)
        local led = g.ledger[eng.ctx] and "LOGGED - REPEAT: QUARTER" or "NEW CONTEXT - FULL"
        text(x + 16, y + 156, text_size(g, 16), g.ledger[eng.ctx] and PAL.DIM or PAL.GOLD, led)
      end
      text(40, 838, text_size(g, 18), PAL.DIM, "ARROWS CHOOSE - ENTER BOOKS THE ENGAGEMENT")
    elseif g.phase == "appraise" then
      text(330, 620, text_size(g, 30), PAL.GOLD, "APPRAISAL")
      text(330, 662, text_size(g, 20), PAL.MAUVE, "THE DAY IS WITNESSED. GAINS APPLY NOW - ONLY NOW.")
    end
    if g.caption_ms > 0 then
      text(90, 862, text_size(g, 20), PAL.ROSE, g.caption)
    end
  end

  local function gate()
    rect(0, 0, CANVAS_PX, CANVAS_PX, PAL.BG)
    text(250, 250, text_size(g, 64), PAL.PINK, "EXPOSURE")
    text(250, 350, text_size(g, 26), PAL.PAPER, "18+ ONLY BEYOND THIS GATE")
    text(250, 410, text_size(g, 19), PAL.MAUVE, "AN ADULT GAME OF BEING SEEN, BY NICE THOUGHTS RANCH.")
    text(250, 445, text_size(g, 19), PAL.MAUVE, "EXHIBITION AND THE ECONOMICS OF ATTENTION, AS A SCHEDULE.")
    text(250, 480, text_size(g, 19), PAL.MAUVE, "EVERYTHING IS ABSTRACT AND SYMBOLIC. NO ONE IS REAL.")
    text(250, 560, text_size(g, 20), PAL.GOLD, "PRESS ENTER OR TAP TO CONFIRM YOU ARE 18+")
  end

  local function title()
    room()
    text(250, 130, text_size(g, 72), PAL.PINK, "EXPOSURE")
    text(250, 225, text_size(g, 20), PAL.MAUVE, "ONE DAY OF BEING SEEN - A SCHEDULE SIM")
    local items = { "BEGIN THE DAY", "THE BRIEF", "SETTINGS" }
    for i = 1, 3 do
      local y = 340 + (i - 1) * 64
      local c = (g.menu_cursor == i - 1) and PAL.PINK or PAL.PAPER
      if g.menu_cursor == i - 1 then text(210, y, text_size(g, 34), PAL.PINK, ">") end
      text(250, y, text_size(g, 34), c, items[i])
    end
    local y = 340 + 3 * 64
    if g.menu_cursor == 3 then text(210, y, text_size(g, 34), PAL.PINK, ">") end
    text(250, y, text_size(g, 34), PAL.PAPER, "DAY: " .. DAYS[g.title_level + 1].name)
    local day = DAYS[g.title_level + 1]
    text(250, y + 48, text_size(g, 20), PAL.MAUVE,
      "GOAL: " .. day.formed .. " FORMING - ATTENTION " .. day.attention .. " - TAP ROW TO CHANGE")
    if g.archive_days > 0 then
      text(250, 660, text_size(g, 22), PAL.GOLD,
        "THE WRITTEN RECORD: " .. g.archive_days .. " DAYS CLOSED - BEST " .. g.archive_best .. " FORMING")
    end
    text(250, 880, text_size(g, 20), PAL.DIM, "ARROWS CHOOSE - ENTER CONFIRMS")
  end

  local function howto()
    rect(0, 0, CANVAS_PX, CANVAS_PX, PAL.BG)
    text(110, 100, text_size(g, 40), PAL.PINK, "THE BRIEF")
    local lines = {
      "EACH DAY HAS SIX SLOTS. EVERY SLOT OFFERS THREE",
      "ENGAGEMENTS: A SHOOT, AN APPEARANCE, A SET, A FEED.",
      "BOOK ONE. ITS TRACK GAINS GO PENDING - NOTHING",
      "MOVES UNTIL THE DAY IS WITNESSED AT APPRAISAL",
      "(AFTER SLOT THREE, AND AGAIN AT THE CLOSE).",
      "",
      "THE LEDGER LOGS CONTEXTS, NOT REPETITIONS: THE",
      "FIRST SHOOT OF A KIND COUNTS IN FULL; REPEATS",
      "COUNT A QUARTER. DIVERSIFY WHAT SHE IS SEEN IN.",
      "",
      "ATTENTION IS THE DAY'S ECONOMY. IT DECAYS BETWEEN",
      "SLOTS. PRAISE PROGRAMMES EARN HALF AGAIN WHILE A",
      "RECORDED CONTEXT - A SET, A FEED, A TAPE - IS WARM.",
      "",
      "TRACKS TIP FROM STIRRING TO FORMING AT APPRAISAL.",
      "FORM ENOUGH OF HER FOUR BEFORE THE DAY CLOSES.",
    }
    for i = 1, #lines do
      text(110, 185 + (i - 1) * 42, text_size(g, 20), PAL.PAPER, lines[i])
    end
    text(110, 850, text_size(g, 22), PAL.GOLD, "ENTER OR ESC TO RETURN")
  end

  local function settings()
    rect(0, 0, CANVAS_PX, CANVAS_PX, PAL.BG)
    text(250, 160, text_size(g, 44), PAL.PINK, "SETTINGS")
    local rows = {
      "PACE: " .. (g.pace_quick and "QUICK" or "FULL"),
      "TEXT: " .. (g.text_large and "LARGE" or "NORMAL"),
      "BACK",
    }
    for i = 1, 3 do
      local y = 300 + (i - 1) * 70
      local c = (g.menu_cursor == i - 1) and PAL.PINK or PAL.PAPER
      if g.menu_cursor == i - 1 then text(210, y, text_size(g, 32), PAL.PINK, ">") end
      text(250, y, text_size(g, 32), c, rows[i])
    end
    text(250, 560, text_size(g, 20), PAL.MAUVE, "SETTINGS ARE NEVER GATED. THEY APPLY AT ONCE")
    text(250, 590, text_size(g, 20), PAL.MAUVE, "AND ARE REMEMBERED BETWEEN VISITS.")
  end

  local function pause()
    play()
    rect(230, 260, 500, 400, PAL.DEEP)
    text(360, 300, text_size(g, 44), PAL.PINK, "HELD")
    local items = { "RESUME", "RESTART DAY", "QUIT TO TITLE" }
    for i = 1, 3 do
      local y = 400 + (i - 1) * 64
      local c = (g.menu_cursor == i - 1) and PAL.PINK or PAL.PAPER
      if g.menu_cursor == i - 1 then text(310, y, text_size(g, 32), PAL.PINK, ">") end
      text(350, y, text_size(g, 32), c, items[i])
    end
  end

  local function record(won)
    room()
    local day = DAYS[g.level_idx + 1]
    text(170, 150, text_size(g, 46), PAL.PINK, "THE WRITTEN RECORD")
    text(170, 220, text_size(g, 26), won and PAL.PAPER or PAL.MAUVE, day.name)
    for t = 1, 4 do
      local y = 300 + (t - 1) * 52
      local st = stage_of(g.totals[t])
      local sc = (st == 2 and PAL.PINK) or (st == 1 and PAL.GOLD) or PAL.DIM
      text(170, y, text_size(g, 24), PAL.PAPER, TRACKS[t].key)
      text(470, y, text_size(g, 24), sc, STAGE_NAMES[st] .. " - " .. g.totals[t])
    end
    text(170, 540, text_size(g, 20), PAL.PAPER,
      "GOALS: " .. day.formed .. " FORMING (SHE HAS " .. formed_count(g) .. ") - ATTENTION "
      .. day.attention .. " (SHE HOLDS " .. g.attention .. ")")
    text(170, 575, text_size(g, 20), PAL.PAPER,
      "CONTEXTS " .. day.contexts .. " (LOGGED " .. g.ledger_count .. ")")
    if won then
      text(170, 600, text_size(g, 20), PAL.PINK, "THE DAY CLOSES WELL. IT IS WRITTEN.")
    else
      text(170, 600, text_size(g, 20), PAL.MAUVE, "THE DAY CLOSES SHORT. THE RECORD KEEPS THAT TOO.")
    end
    text(170, 680, text_size(g, 24), PAL.GOLD, "ENTER OR TAP TO RETURN")
  end

  if g.screen == SCR.GATE then gate()
  elseif g.screen == SCR.TITLE then title()
  elseif g.screen == SCR.HOWTO then howto()
  elseif g.screen == SCR.PLAY then play()
  elseif g.screen == SCR.PAUSE then pause()
  elseif g.screen == SCR.SETTINGS then settings()
  elseif g.screen == SCR.VICTORY then record(true)
  elseif g.screen == SCR.GAMEOVER then record(false)
  end
  return table.concat(lines, "\n") .. "\n"
end

function M.draw()
  if not S then return "" end
  return render(S)
end

return M
