--[[--
Measures a crengine document's body text by rendering sample pages offscreen
and reading their ink. The current page is often a cover or a table of
contents, so the pages at 25 %, 50 % and 75 % of the book are used instead.
]]

local Blitbuffer = require("ffi/blitbuffer")
local Edges = require("automargin/edges")
local Geom = require("ui/geometry")
local ffi = require("ffi")
local logger = require("logger")
local time = require("ui/time")

local Measure = {}

local SAMPLES = { 0.25, 0.5, 0.75 } -- of the book

--- Ink (255 - gray) per row of the line box, summed across lines.
-- @tparam BlitBuffer bb an 8-bit rendering of the page
-- @tparam table lines {y, x0, x1}, see automargin/edges
-- @int L line height
-- @treturn table ink, indexed 0 to L - 1
function Measure.inkProfile(bb, lines, L)
    local data = ffi.cast("uint8_t*", bb.data)
    local profile = {}
    for k = 0, L - 1 do
        local ink = 0
        for _, line in ipairs(lines) do
            local row = data + (line.y + k) * bb.stride
            for x = line.x0, line.x1 - 1 do
                ink = ink + 255 - row[x]
            end
        end
        profile[k] = ink
    end
    return profile
end

local function measurePage(doc, bb)
    local w, h = bb:getWidth(), bb:getHeight()
    local text = doc:getTextFromPositions({ x = 0, y = 0 }, { x = w, y = h }, true)
    if not text then return nil, "no text" end
    local lines, L = Edges.bodyLines(text.sboxes)
    if not lines then return nil, L end
    -- The ink is read straight from memory: never read outside the buffer.
    for _, line in ipairs(lines) do
        if line.y < 0 or line.y + L > h or line.x0 < 0 or line.x1 > w then return nil, "line off screen" end
    end
    doc:drawCurrentView(bb, 0, 0, Geom:new { x = 0, y = 0, w = w, h = h })
    local x_off, b_off = Edges.find(Measure.inkProfile(bb, lines, L), L)
    if not x_off then return nil, b_off end
    return { L = L, x_off = x_off, b_off = b_off }
end

--- Measures the document's body lines, then goes back to the current page.
-- Only crengine's position moves: no events are sent.
-- @treturn table|nil {L, x_off, b_off, ms}, or nil
-- @treturn string|nil why there is no measurement
function Measure.sample(doc, w, h)
    local start = time.now()
    local page, count = doc:getCurrentPage(), doc:getPageCount()
    local bb = Blitbuffer.new(w, h, Blitbuffer.TYPE_BB8)
    local samples, reason = {}, nil
    -- Whatever happens, free the buffer and go back to the reader's page.
    local ok, err = pcall(function()
        for i, f in ipairs(SAMPLES) do
            doc:gotoPage(math.max(1, math.floor(count * f)))
            local m, why = measurePage(doc, bb)
            samples[i], reason = m or false, why or reason
        end
    end)
    bb:free()
    doc:gotoPage(page)
    if not ok then
        logger.warn("AutoMargin: measuring failed:", err)
        return nil, "error"
    end
    local m = Edges.agree(samples)
    if not m then return nil, reason or "samples disagree" end
    local result = { L = m.L, x_off = m.x_off, b_off = m.b_off, ms = time.to_ms(time.since(start)) }
    logger.dbg("AutoMargin: measured", result)
    return result
end

return Measure
