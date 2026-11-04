local Layout = require("automargin/layout")

-- 1072x1448 at 300 dpi with KOReader's default margins and status bar, as in
-- spec/integration/hd_test.lua, which renders these gaps.
local function hd(line, x_off, b_off, overrides)
    local g =
        { screen_h = 1448, top = 27, bottom = 55, header = 0, bar = 28, line = line, x_off = x_off, b_off = b_off }
    for k, v in pairs(overrides or {}) do
        g[k] = v
    end
    return Layout.compute(g), g
end

local function area(l, g)
    return g.screen_h - l.top - l.bottom - g.header
end

describe("Layout.compute", function()
    it("predicts the gaps KOReader renders, and centers them", function()
        local cases = {
            -- size, L, x_off, b_off, gaps before, gaps after
            { 20, 49, 18, 38, { 45, 81 }, { 63, 63 } },
            { 24, 59, 22, 46, { 49, 49 }, { 49, 49 } },
            { 28, 69, 27, 54, { 54, 97 }, { 76, 75 } },
            { 32, 79, 31, 62, { 58, 67 }, { 63, 62 } },
        }
        for _, c in ipairs(cases) do
            local l = hd(c[2], c[3], c[4])
            local size = "size " .. c[1]
            assert.same({ top = c[5][1], bottom = c[5][2] }, l.before, size)
            assert.same({ top = c[6][1], bottom = c[6][2] }, l.after, size)
            assert.equal(false, l.clamped, size)
        end
    end)

    it("trims the page area to whole lines and gives the rest to the margins", function()
        local l, g = hd(69, 27, 54)
        assert.equal(19, l.lines)
        assert.equal(19 * 69, area(l, g))
        assert.equal(49, l.top)
        assert.equal(1448 - 19 * 69 - 49, l.bottom)
    end)

    it("with no space left over, only moves the area for the x-height/baseline asymmetry", function()
        local l, g = hd(49, 18, 38, { top = 24, bottom = 52 })
        assert.equal(28, l.lines)
        assert.equal(28 * 49, area(l, g))
        assert.equal(21, l.top)
        assert.equal(55, l.bottom)
    end)

    it("measures the top gap from below the top status bar", function()
        local without = hd(49, 18, 38)
        local with, g = hd(49, 18, 38, { header = 40 })
        assert.equal(without.before.top, with.before.top)
        assert.equal(math.floor((1448 - 27 - 55 - 40) / 49), with.lines)
        assert.equal(with.lines * 49, area(with, g))
        assert.is_true(math.abs(with.after.top - with.after.bottom) <= 1)
    end)

    it("measures the bottom gap to the screen edge with Overlap status bar", function()
        local l, g = hd(49, 18, 38, { bottom = 27, bar = 0 })
        assert.equal(28, l.lines)
        assert.same({ top = 45, bottom = 1448 - (27 + 27 * 49 + 38) }, l.before)
        assert.equal(28 * 49, area(l, g))
        assert.is_true(math.abs(l.after.top - l.after.bottom) <= 1)
    end)

    -- 800 px screen, 20 px status bar, no margins and no space left over.
    local function tight(x_off, b_off)
        return Layout.compute {
            screen_h = 800,
            top = 0,
            bottom = 20,
            header = 0,
            bar = 20,
            line = 30,
            x_off = x_off,
            b_off = b_off,
        }
    end

    it("never moves the page area into the status bar's space", function()
        local l = tight(5, 15)
        assert.is_true(l.clamped)
        assert.same({ 0, 20 }, { l.top, l.bottom })
    end)

    it("never moves the page area above the screen", function()
        local l = tight(12, 28)
        assert.is_true(l.clamped)
        assert.same({ 0, 20 }, { l.top, l.bottom })
    end)
end)
