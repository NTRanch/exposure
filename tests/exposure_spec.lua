-- Busted spec stub (estate runner: busted on Lua 5.4.8).
-- Half validation / half adversarial, per estate test law.
describe("exposure", function()
    it("loads", function()
        local game = require("src.main")
        assert.is_table(game)
    end)
end)
