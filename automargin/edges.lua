--[[--
Pure analysis of rendered pages: pick the body lines, find where the x-band
starts and ends inside a line box, and check that the sample pages agree.

A measurement is {L, x_off, b_off}: the body line height, the first row of
the x-band and the first row below the baseline, both counted from the top
of the line box.
]]

local Edges = {}

local MIN_LINES = 4
-- Shorter lines (paragraph ends, speaker names in plays) blur the profile.
local MIN_WIDTH = 0.6
-- How tall the x-band can be, as a share of the line height.
local MIN_BAND, MAX_BAND = 0.25, 0.8

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

--- Finds the x-band in an ink profile.
-- Every lowercase letter starts at the x-height line, so the largest increase
-- in ink marks it; the baseline is where the largest drop happens.
-- @tparam table profile ink per row of the line box, indexed 0 to L - 1
-- @int L line height
-- @treturn int|nil x_off, or nil
-- @treturn int|string b_off, or why there is no x-band
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
    return x_off, b_off
end

local function same(a, b)
    return a.L == b.L and a.x_off == b.x_off and a.b_off == b.b_off
end

--- Returns the measurement that at least two samples agree on.
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
