--[[--
Pure analysis of rendered pages: pick the body lines, find where the ink's
edges are inside a line box, and check that the sample pages agree.

A measurement is {L, a_off, x_off, b_off, d_off}: the body line height, then,
counted from the top of the line box, the first row of the ascenders, the
first row of the x-band, the first row below the baseline and the first row
below the descenders.
]]

local Edges = {}

local MIN_LINES = 4
-- Shorter lines (paragraph ends, speaker names in plays) blur the profile.
local MIN_WIDTH = 0.6
-- How tall the x-band can be, as a share of the line height.
local MIN_BAND, MAX_BAND = 0.25, 0.8
-- Past the ascenders and descenders, rows have less ink than this share of
-- the median row above or below the x-band.
local FAINT = 0.25

--- Merges text segments that share a line box.
-- @tparam table segments {x, y, w, h} boxes, as in getTextFromPositions().sboxes
-- @treturn table lines {y, h, x0, x1}, top to bottom
function Edges.lines(segments)
    local lines, by_key = {}, {}
    for _, s in ipairs(segments) do
        local key = s.y .. ":" .. s.h
        local line = by_key[key]
        if line then
            line.x0 = math.min(line.x0, s.x)
            line.x1 = math.max(line.x1, s.x + s.w)
        else
            line = { y = s.y, h = s.h, x0 = s.x, x1 = s.x + s.w }
            by_key[key] = line
            table.insert(lines, line)
        end
    end
    table.sort(lines, function(a, b)
        return a.y < b.y
    end)
    return lines
end

--- Keeps the full-width body lines.
-- @tparam table segments as for Edges.lines
-- @treturn table|nil lines, or nil
-- @treturn number|string the line height, or why there are no body lines
function Edges.bodyLines(segments)
    local lines = Edges.lines(segments)

    -- Body text has the most common height: this drops headings, drop caps
    -- and lines with inline images.
    local count, L = {}, nil
    for _, line in ipairs(lines) do
        count[line.h] = (count[line.h] or 0) + 1
        if not L or count[line.h] > count[L] then L = line.h end
    end
    if not L then return nil, "no text" end

    local widest = 0
    for _, line in ipairs(lines) do
        if line.h == L then widest = math.max(widest, line.x1 - line.x0) end
    end
    local body = {}
    for _, line in ipairs(lines) do
        if line.h == L and line.x1 - line.x0 >= MIN_WIDTH * widest then table.insert(body, line) end
    end
    if #body < MIN_LINES then return nil, "too few body lines" end
    return body, L
end

-- The median ink of the rows from..to that have any, or 0.
local function level(profile, from, to)
    local inked = {}
    for k = from, to do
        if profile[k] > 0 then table.insert(inked, profile[k]) end
    end
    table.sort(inked)
    return inked[math.ceil(#inked / 2)] or 0
end

--- Finds the edges of the ink in a profile.
-- Every lowercase letter starts at the x-height line, so the largest increase
-- in ink marks it; the baseline is where the largest drop happens.
--
-- Ascenders and descenders are fainter and uneven: capitals and t stop short
-- of the ascender line, and descenders end at different depths. So their
-- edges are where the ink, going out from the x-band, falls below a share of
-- its usual level. That stops at a gap: accents, brackets, and the line
-- above's descenders at tight line spacing are left out.
-- @tparam table profile ink per row of the line box, indexed 0 to L - 1
-- @int L line height
-- @treturn table|nil {a_off, x_off, b_off, d_off}, or nil
-- @treturn string|nil why there is no x-band
function Edges.find(profile, L)
    local x_off, b_off, best_rise, best_drop = nil, nil, 0, 0
    for k = 1, L do
        -- Row L is the next line's top row: count it as blank, so a baseline
        -- on the box's last row is still found.
        local prev, cur = profile[k - 1], k < L and profile[k] or 0
        if cur - prev > best_rise then
            best_rise, x_off = cur - prev, k
        end
        if prev - cur > best_drop then
            best_drop, b_off = prev - cur, k
        end
    end
    if not (x_off and b_off and x_off < b_off) then return nil, "no x-band" end
    local band = (b_off - x_off) / L
    if band < MIN_BAND or band > MAX_BAND then return nil, "x-band out of range" end

    local above = FAINT * level(profile, 0, x_off - 1)
    local below = FAINT * level(profile, b_off, L - 1)
    local a_off, d_off = x_off, b_off
    while a_off > 0 and profile[a_off - 1] > above do
        a_off = a_off - 1
    end
    while d_off < L and profile[d_off] > below do
        d_off = d_off + 1
    end
    return { a_off = a_off, x_off = x_off, b_off = b_off, d_off = d_off }
end

-- The ascender and descender lines aren't compared: with few lines on a page,
-- samples can differ on them by a row or two.
local function same(a, b)
    return a.L == b.L and a.x_off == b.x_off and a.b_off == b.b_off
end

--- Returns the measurement that at least two samples agree on: the first of them.
-- @tparam table samples measurements, or false for pages that couldn't be measured
-- @treturn table|nil
function Edges.agree(samples)
    for i = 1, #samples do
        for j = i + 1, #samples do
            if samples[i] and samples[j] and same(samples[i], samples[j]) then return samples[i] end
        end
    end
end

return Edges
