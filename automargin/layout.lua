--[[--
Pure geometry: the page margins to give crengine so that the page area holds a
whole number of body lines, placed so the gap above the first line's x-height
equals the gap below the last line's baseline. Everything is in screen pixels.

The user's margins decide how many lines fit on a page. The leftover space,
less than a line, goes to the margins, so no page can use it: content never
reaches further down than a full page of body text does.

Both functions take the same table:
  screen_h: screen height
  top, bottom: page margins (bottom includes the space the status bar reserves)
  header: height of crengine's top status bar, 0 when hidden
  bar: space the bottom status bar reserves, 0 with "Overlap status bar"
  line, x_off, b_off: the measurement (see automargin/edges)
]]

local Layout = {}

local function round(x)
    return math.floor(x + 0.5)
end

local function area(g)
    return g.screen_h - g.top - g.bottom - g.header
end

local function linesPerPage(g)
    return math.max(1, math.floor(area(g) / g.line))
end

local function gapsAt(g, top, lines)
    local last = top + g.header + (lines - 1) * g.line -- top of the last line box
    return { top = top + g.x_off, bottom = g.screen_h - g.bar - (last + g.b_off) }
end

--- The gaps on a full page of body lines with these margins.
-- @treturn table top: from the top edge to the first line's x-height;
--   bottom: from the last line's baseline to the bottom edge
function Layout.gaps(g)
    return gapsAt(g, g.top, linesPerPage(g))
end

--- Computes the margins to use instead of the user's.
-- @treturn table top, bottom: the margins to use; lines: per page; clamped;
--   before, after: the gaps with the user's margins and with these
function Layout.compute(g)
    local lines = linesPerPage(g)
    local spare = g.top + g.bottom + math.max(0, area(g) - lines * g.line)
    -- Gap above: top + x_off. Gap below: (spare - top - bar) + (line - b_off).
    local wanted = round((spare - g.bar + g.line - g.b_off - g.x_off) / 2)
    -- Never move the page area off the screen or into the status bar's space.
    local top = math.max(0, math.min(wanted, spare - g.bar))
    return {
        top = top,
        bottom = spare - top,
        lines = lines,
        clamped = top ~= wanted,
        before = gapsAt(g, g.top, lines),
        after = gapsAt(g, top, lines),
    }
end

return Layout
