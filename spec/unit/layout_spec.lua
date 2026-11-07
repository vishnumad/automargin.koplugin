local Layout = require("automargin/layout")

-- 1072x1448 at 300 dpi with KOReader's default margins and status bar, as in
-- spec/integration/hd_test.lua, which renders these gaps.
local function hd(line, top_off, bottom_off, overrides)
    local g = {
        screen_h = 1448,
        top = 27,
        bottom = 55,
        header = 0,
        bar = 28,
        line = line,
        top_off = top_off,
        bottom_off = bottom_off,
    }
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
            -- size, L, x_off, b_off (as top_off, bottom_off), gaps before, gaps after
            { 20, 49, 18, 38, { 45, 109 }, { 77, 77 } },
            { 24, 59, 22, 46, { 49, 77 }, { 63, 63 } },
            { 28, 69, 27, 54, { 54, 125 }, { 90, 89 } },
            { 32, 79, 31, 62, { 58, 95 }, { 77, 76 } },
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
        assert.equal(63, l.top)
        assert.equal(1448 - 19 * 69 - 63, l.bottom)
    end)

    it("with no space left over, moves the area within the margins", function()
        local l, g = hd(49, 18, 38, { top = 24, bottom = 52 })
        assert.equal(28, l.lines)
        assert.equal(28 * 49, area(l, g))
        assert.equal(35, l.top)
        assert.equal(41, l.bottom)
    end)

    it("measures the top gap from the top of the screen, above the top status bar", function()
        local l, g = hd(49, 18, 38, { header = 40 })
        assert.equal(40 + 27 + 18, l.before.top)
        assert.equal(math.floor((1448 - 27 - 55 - 40) / 49), l.lines)
        assert.equal(l.lines * 49, area(l, g))
        assert.is_true(math.abs(l.after.top - l.after.bottom) <= 1)
    end)

    it("centers the same way whether or not the status bar overlaps the text", function()
        local reserved, overlapping = hd(49, 18, 38), hd(49, 18, 38, { bar = 0 })
        assert.same({ reserved.top, reserved.bottom }, { overlapping.top, overlapping.bottom })
    end)

    -- 800 px below the top status bar, 20 px bottom status bar, no margins and no space left over.
    local function tight(top_off, bottom_off, header)
        return Layout.compute {
            screen_h = 800 + (header or 0),
            top = 0,
            bottom = 20,
            header = header or 0,
            bar = 20,
            line = 30,
            top_off = top_off,
            bottom_off = bottom_off,
        }
    end

    it("never moves the page area into the status bar's space", function()
        local l = tight(5, 15)
        assert.is_true(l.clamped)
        assert.same({ 0, 20 }, { l.top, l.bottom })
    end)

    it("never moves the page area into the top status bar's space", function()
        local l = tight(12, 28, 30)
        assert.is_true(l.clamped)
        assert.same({ 0, 20 }, { l.top, l.bottom })
    end)
end)
