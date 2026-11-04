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
        list[k + 1] = ink
    end
    return profile(list)
end

describe("Edges.find", function()
    it("finds the x-band of a sans profile", function()
        assert.same({ 7, 16 }, { Edges.find(synthetic(20, 3, 7, 16, 19), 20) })
    end)

    it("isn't fooled by serifs at the x-height line and the baseline", function()
        assert.same({ 7, 16 }, { Edges.find(synthetic(20, 3, 7, 16, 19, { serifs = true }), 20) })
    end)

    it("ignores noise", function()
        assert.same({ 7, 16 }, { Edges.find(synthetic(20, 3, 7, 16, 19, { noise = true }), 20) })
    end)

    it("reads a real profile: Noto Serif 22 at 600x800", function()
        -- stylua: ignore
        local real = profile({
            0, 0, 0, 0, 0, 0, 254652, 201002, 163288, 156201, 178914, 1529081, 1382380, 1056741, 938153,
            917347, 1195064, 957209, 860301, 865506, 945450, 1303985, 1643430, 55410, 51854, 54463, 66096,
            96905, 0, 0,
        })
        assert.same({ 11, 23 }, { Edges.find(real, 30) })
    end)

    it("finds a baseline on the box's last row", function()
        assert.same({ 7, 20 }, { Edges.find(synthetic(20, 3, 7, 20, 20), 20) })
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
    local a = { L = 30, x_off = 11, b_off = 23 }
    local b = { L = 30, x_off = 12, b_off = 23 }
    local c = { L = 31, x_off = 11, b_off = 23 }

    it("accepts samples that all match", function()
        assert.equal(a, Edges.agree({ a, { L = 30, x_off = 11, b_off = 23 }, a }))
    end)

    it("accepts two of three", function()
        assert.same(a, Edges.agree({ b, a, { L = 30, x_off = 11, b_off = 23 } }))
        assert.same(a, Edges.agree({ a, false, a }))
    end)

    it("rejects samples that all differ", function()
        assert.is_nil(Edges.agree({ a, b, c }))
    end)

    it("rejects a single measured page", function()
        assert.is_nil(Edges.agree({ false, a, false }))
    end)
end)
