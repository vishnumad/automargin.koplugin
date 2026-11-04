local Edges = require("automargin/edges")

-- Builds a 0-indexed profile from a list.
local function profile(list)
    local p = {}
    for i, v in ipairs(list) do
        p[i - 1] = v
    end
    return p
end

-- L rows: blank, ascenders from asc, x-band from x to b - 1, descenders to desc - 1.
local function synthetic(L, asc, x, b, desc, opts)
    opts = opts or {}
    local list = {}
    for k = 0, L - 1 do
        local ink = 0
        if k >= asc and k < x then ink = 10 end
        if k >= x and k < b then ink = 100 end
        if k >= b and k < desc then ink = 8 end
        if opts.serifs and (k == x or k == b - 1) then ink = 160 end
        if opts.noise then ink = ink + (k * 7) % 5 end
        -- Ink past a blank row, above the ascenders and below the descenders.
        if opts.beyond and (k == asc - 2 or k == desc + 1) then ink = opts.beyond end
        list[k + 1] = ink
    end
    return profile(list)
end

local function edges(a, x, b, d)
    return { a_off = a, x_off = x, b_off = b, d_off = d }
end

describe("Edges.find", function()
    it("finds the edges of a sans profile", function()
        assert.same(edges(3, 7, 16, 19), Edges.find(synthetic(20, 3, 7, 16, 19), 20))
    end)

    local function xBand(m)
        return { m.x_off, m.b_off }
    end

    it("isn't fooled by serifs at the x-height line and the baseline", function()
        assert.same({ 7, 16 }, xBand(Edges.find(synthetic(20, 3, 7, 16, 19, { serifs = true }), 20)))
    end)

    it("ignores noise", function()
        assert.same({ 7, 16 }, xBand(Edges.find(synthetic(20, 3, 7, 16, 19, { noise = true }), 20)))
    end)

    it("leaves out ink past a gap: accents, brackets, the line above's descenders", function()
        assert.same(edges(4, 8, 16, 18), Edges.find(synthetic(20, 4, 8, 16, 18, { beyond = 12 }), 20))
    end)

    it("reads a real profile: Noto Serif 22 at 600x800", function()
        -- stylua: ignore
        local real = profile({
            0, 0, 0, 0, 0, 0, 254652, 201002, 163288, 156201, 178914, 1529081, 1382380, 1056741, 938153,
            917347, 1195064, 957209, 860301, 865506, 945450, 1303985, 1643430, 55410, 51854, 54463, 66096,
            96905, 0, 0,
        })
        assert.same(edges(6, 11, 23, 28), Edges.find(real, 30))
    end)

    it("reads a real profile with partly inked rows around the x-band: Noto Serif 28 at 1072x1448", function()
        -- stylua: ignore
        local real = profile({
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7202, 346418, 370118, 322531, 262892, 240356, 249397,
            214287, 210193, 214585, 220531, 232981, 515528, 2106982, 2500206, 2290486, 1671546, 1536018,
            1459630, 1390566, 1297373, 1273172, 1271226, 1278828, 1653611, 1704520, 1565758, 1269213, 1248680,
            1226811, 1201303, 1199339, 1220838, 1248154, 1322312, 1438185, 1630568, 2260232, 2609307, 2312803,
            290138, 65540, 63977, 64301, 65931, 68128, 66138, 64887, 73853, 114684, 128958, 97342, 0, 0, 0,
        })
        assert.same(edges(15, 27, 54, 66), Edges.find(real, 69))
    end)

    it("finds edges on the box's first and last rows", function()
        assert.same(edges(0, 7, 16, 20), Edges.find(synthetic(20, 0, 7, 16, 20), 20))
        assert.same(edges(3, 7, 20, 20), Edges.find(synthetic(20, 3, 7, 20, 20), 20))
    end)

    it("with no ascenders or descenders, ends the ink with the x-band", function()
        assert.same(edges(7, 7, 16, 16), Edges.find(synthetic(20, 7, 7, 16, 16), 20))
    end)

    it("rejects a blank profile", function()
        assert.same({ nil, "no x-band" }, { Edges.find(synthetic(20, 0, 0, 0, 0), 20) })
    end)

    it("rejects an x-band that is too thin or too tall", function()
        assert.same({ nil, "x-band out of range" }, { Edges.find(synthetic(20, 3, 7, 10, 19), 20) })
        assert.same({ nil, "x-band out of range" }, { Edges.find(synthetic(20, 0, 1, 19, 19), 20) })
    end)
end)

local function seg(x, y, w, h)
    return { x = x, y = y, w = w, h = h }
end

describe("Edges.lines", function()
    it("merges segments that share a line box, top to bottom", function()
        local lines = Edges.lines({ seg(10, 80, 100, 30), seg(10, 50, 300, 30), seg(310, 50, 280, 30) })
        assert.same({
            { y = 50, h = 30, x0 = 10, x1 = 590 },
            { y = 80, h = 30, x0 = 10, x1 = 110 },
        }, lines)
    end)
end)

describe("Edges.bodyLines", function()
    it("keeps the full-width lines of the most common height", function()
        local segments = {
            seg(200, 10, 200, 40), -- heading
            seg(10, 50, 300, 30), -- line split by a link
            seg(310, 50, 280, 30),
            seg(10, 80, 580, 30),
            seg(10, 110, 580, 30),
            seg(10, 140, 100, 30), -- paragraph end
            seg(40, 170, 550, 30),
        }
        local lines, L = Edges.bodyLines(segments)
        assert.equal(30, L)
        assert.same({
            { y = 50, h = 30, x0 = 10, x1 = 590 },
            { y = 80, h = 30, x0 = 10, x1 = 590 },
            { y = 110, h = 30, x0 = 10, x1 = 590 },
            { y = 170, h = 30, x0 = 40, x1 = 590 },
        }, lines)
    end)

    it("needs enough body lines", function()
        local segments = { seg(10, 50, 580, 30), seg(10, 80, 580, 30), seg(10, 110, 580, 30), seg(10, 140, 50, 30) }
        assert.same({ nil, "too few body lines" }, { Edges.bodyLines(segments) })
        assert.same({ nil, "no text" }, { Edges.bodyLines({}) })
    end)
end)

describe("Edges.agree", function()
    local function m(L, a_off, x_off, b_off, d_off)
        return { L = L, a_off = a_off, x_off = x_off, b_off = b_off, d_off = d_off }
    end
    local a = m(30, 6, 11, 23, 28)
    local b = m(30, 6, 12, 23, 28)
    local c = m(31, 6, 11, 23, 28)

    it("accepts samples that all match", function()
        assert.equal(a, Edges.agree({ a, m(30, 6, 11, 23, 28), a }))
    end)

    it("accepts two of three", function()
        assert.same(a, Edges.agree({ b, a, m(30, 6, 11, 23, 28) }))
        assert.same(a, Edges.agree({ a, false, a }))
    end)

    it("rejects samples that all differ", function()
        assert.is_nil(Edges.agree({ a, b, c }))
    end)

    it("doesn't compare the ascender and descender lines", function()
        assert.equal(a, Edges.agree({ a, m(30, 5, 11, 23, 27), c }))
    end)

    it("rejects a single measured page", function()
        assert.is_nil(Edges.agree({ false, a, false }))
    end)
end)
