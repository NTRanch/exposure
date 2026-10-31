-- Exposure specs (busted on the estate Lua 5.4.8).
-- Half validation / half adversarial, per estate test law.
-- Run from the repo root: busted tests/exposure_spec.lua

local IN = { TAP = 1, CONFIRM = 2, BACK = 4, PAUSE = 8, UP = 16, DOWN = 32, LEFT = 64, RIGHT = 128 }
local SCR = { GATE = 0, TITLE = 1, HOWTO = 2, PLAY = 3, PAUSE = 4, SETTINGS = 5, VICTORY = 6, GAMEOVER = 7 }

local function fresh(seed, day, demo)
  local Core = dofile("src/main.lua")
  assert.are.equal(0, Core.init(seed or 42, day or 0, demo or false))
  return Core
end

local function steps(Core, n, inp)
  for _ = 1, n do Core.step(16, inp or 0) end
end

-- Pick the offered card at position k (1..3) through real input.
local function pick(Core, k)
  local S = Core._state()
  local guard = 0
  while S.card_cursor ~= k - 1 and guard < 6 do
    local cur, tgt = S.card_cursor, k - 1
    if (tgt - cur) % 3 == 1 then Core.step(16, IN.RIGHT) else Core.step(16, IN.LEFT) end
    guard = guard + 1
  end
  Core.step(16, IN.CONFIRM)
  assert.are.equal("outcome", Core._state().phase)
end

-- Run out the current outcome phase into whatever follows.
local function settle_outcome(Core)
  local guard = 0
  while Core._state().phase == "outcome" and guard < 400 do
    Core.step(16, 0)
    guard = guard + 1
  end
end

-- Run an appraisal to its end (next choose phase or a closed day).
local function settle_appraisal(Core)
  local guard = 0
  while Core._state().phase == "appraise" and guard < 800 do
    Core.step(16, 0)
    guard = guard + 1
  end
end

describe("exposure — validation", function()
  it("loads and honours the init contract", function()
    local Core = dofile("src/main.lua")
    assert.are.equal(1, Core.init(1, 3, false))
    assert.are.equal(1, Core.init(1, -1, false))
    assert.are.equal(0, Core.init(1, 0, false))
    assert.are.equal(SCR.GATE, Core.screen())
  end)

  it("banks a first-context pick in full, pending — totals unmoved", function()
    local Core = fresh()
    Core.start_level(0)
    Core._force_offers(1, 2, 3) -- STUDIO SHOOT first
    pick(Core, 1)
    local S = Core._state()
    assert.are.equal(34, S.pending[1])
    assert.are.equal(18, S.pending[2])
    assert.are.equal(0, S.totals[1]) -- nothing moves until witnessed
    assert.are.equal(1, S.ledger_count)
  end)

  it("applies pending at the midday appraisal, and only there", function()
    local Core = fresh()
    Core.start_level(0)
    local S = Core._state()
    Core._force_offers(1, 2, 3)
    pick(Core, 1)
    settle_outcome(Core) -- slot 2 choose
    Core._force_offers(7, 2, 3) -- WINDOW DISPLAY
    pick(Core, 1)
    settle_outcome(Core) -- slot 3 choose
    assert.are.equal(0, S.totals[1]) -- still unwitnessed after two picks
    Core._force_offers(2, 3, 4)
    pick(Core, 1)
    settle_outcome(Core) -- slot 3 ends -> appraisal
    assert.are.equal("appraise", S.phase)
    settle_appraisal(Core)
    assert.are.equal(4, S.slot)
    assert.is_true(S.totals[1] > 0)
    for t = 1, 4 do assert.are.equal(0, S.pending[t]) end
  end)

  it("tips a track into Forming at the appraisal, as an event", function()
    local Core = fresh()
    Core.start_level(0)
    local S = Core._state()
    -- Bank EXHIBITION past the Forming line before midday.
    S.pending[1] = 120
    S.slot = 3
    S.phase = "outcome"
    S.phase_ms = 99999
    Core.step(16, 0) -- outcome ends -> appraisal begins
    assert.are.equal("appraise", S.phase)
    local saw_tipping = false
    for _ = 1, 800 do
      local ev = Core.step(16, 0)
      if ev == 3 then saw_tipping = true end
      if S.phase ~= "appraise" then break end
    end
    assert.is_true(saw_tipping)
    assert.are.equal(120, S.totals[1])
  end)

  it("weights praise attention while a recorded context is warm", function()
    local Core = fresh()
    Core.start_level(0)
    local S = Core._state()
    -- Cold: praise card first, nothing recorded yet, not itself recorded.
    Core._force_offers(5, 1, 2) -- GALLERY OPENING (praise, att 110)
    local before = S.attention
    pick(Core, 1)
    assert.are.equal(110, S.attention - before)
    settle_outcome(Core)
    -- Warm: a recorded context inside the window.
    S.last_recorded_slot = S.slot
    Core._force_offers(4, 1, 2) -- LENS TOY LIVE (praise, att 185)
    before = S.attention
    pick(Core, 1)
    assert.are.equal((185 * 3) // 2, S.attention - before)
  end)

  it("decays attention by the slot curve", function()
    local Core = fresh()
    Core.start_level(0)
    local S = Core._state()
    Core._force_offers(1, 2, 3)
    pick(Core, 1) -- +120 attention, slot 1
    settle_outcome(Core)
    assert.are.equal((120 * 88) // 100, S.attention)
  end)

  it("caps a track at the drift cap when the appraisal applies", function()
    local Core = fresh()
    Core.start_level(0)
    local S = Core._state()
    S.totals[2] = 135
    S.pending[2] = 30
    S.slot = 3
    S.phase = "outcome"
    S.phase_ms = 99999
    Core.step(16, 0)
    settle_appraisal(Core)
    assert.are.equal(140, S.totals[2])
    assert.are.equal(0, S.pending[2])
  end)

  it("demo policy closes all three days on the first attempt", function()
    for day = 0, 2 do
      local Core = fresh(9000 + day, day, true)
      Core.start_level(day)
      local n = 0
      while Core.screen() ~= SCR.VICTORY and Core.screen() ~= SCR.GAMEOVER and n < 20000 do
        Core.step(16, 0)
        n = n + 1
      end
      assert.are.equal(SCR.VICTORY, Core.screen())
    end
  end)
end)

describe("exposure — adversarial", function()
  it("rejects out-of-range days and survives stepping pre-start", function()
    local Core = dofile("src/main.lua")
    assert.are.equal(0, Core.step(16, 0)) -- no game yet: NONE, no crash
    assert.are.equal(0, Core.init(5, 0, false))
    assert.are.equal(1, Core.start_level(3))
    assert.are.equal(1, Core.start_level(-2))
    assert.are.equal(SCR.GATE, Core.screen())
  end)

  it("banks a repeated context at a quarter, floored", function()
    local Core = fresh()
    Core.start_level(0)
    local S = Core._state()
    Core._force_offers(1, 2, 3)
    pick(Core, 1) -- STUDIO full: EXHIB +34
    settle_outcome(Core)
    Core._force_offers(1, 2, 3)
    local before = S.pending[1]
    pick(Core, 1) -- STUDIO again: +floor(34/4) = +8
    assert.are.equal(8, S.pending[1] - before)
    assert.are.equal(1, S.ledger_count) -- the context was already logged
  end)

  it("clamps an oversized dt instead of fast-forwarding", function()
    local Core = fresh()
    Core.step(100000, 0)
    assert.is_true(Core._state().screen_ms <= 50)
  end)

  it("is deterministic: same seed, same inputs, same frame", function()
    local function run()
      local Core = fresh(777, 0, false)
      Core.start_level(0)
      local x = 12345
      for _ = 1, 3000 do
        x = (x * 1103515245 + 12345) % 2147483648
        Core.step(16, x % 256)
      end
      return Core.draw()
    end
    assert.are.equal(run(), run())
  end)

  it("renders well-formed, bounded draw lists on every screen", function()
    local Core = fresh(11, 0, false)
    local function check()
      local text = Core.draw()
      local ops = 0
      for line in text:gmatch("[^\n]+") do
        local kind = line:sub(1, 1)
        assert.is_true(kind == "r" or kind == "c" or kind == "l" or kind == "p" or kind == "t",
          "bad op: " .. line)
        ops = ops + 1
      end
      assert.is_true(ops > 0 and ops <= 1024)
    end
    check() -- gate
    Core.step(16, IN.CONFIRM)
    check() -- title
    Core.step(16, IN.DOWN)
    Core.step(16, IN.DOWN)
    Core.step(16, IN.CONFIRM)
    assert.are.equal(SCR.SETTINGS, Core.screen())
    check() -- settings
    Core.step(16, IN.BACK)
    Core.start_level(0)
    steps(Core, 30, 0)
    check() -- play
    Core.step(16, IN.PAUSE)
    assert.are.equal(SCR.PAUSE, Core.screen())
    check() -- pause
  end)

  it("closes a neglected day as a loss, in the record", function()
    local Core = fresh()
    Core.start_level(0)
    local S = Core._state()
    -- A day of nothing: no pending, no attention, straight to close.
    S.slot = 6
    S.phase = "outcome"
    S.phase_ms = 99999
    Core.step(16, 0)
    settle_appraisal(Core)
    assert.are.equal(SCR.GAMEOVER, Core.screen())
  end)
end)
