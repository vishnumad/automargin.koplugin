--[[--
Pure geometry: the page margins to give crengine so that the page area holds a
whole number of body lines, placed so the gap from the top of the screen to the
text block equals the gap from the text block to the bottom of the screen.
Status bars don't count, but the page area never moves into their space.
Everything is in screen pixels.

The user's margins decide how many lines fit on a page. The leftover space,
less than a line, goes to the margins, so no page can use it: content never
reaches further down than a full page of body text does.

Both functions take the same table:
  screen_h: screen height
  top, bottom: page margins (bottom includes the space the status bar reserves)
  header: space above the page area for top status bars: crengine's, and what
    other plugins add to the top margin for theirs
  bar: space the bottom status bar reserves, 0 with "Overlap status bar"
  line: body line height
  top_off, bottom_off: the rows of a line box where the text block starts and
    where it has ended: the x-height or ascender line, and the first row below
    the baseline or the descenders (see automargin/edges)
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
    local first = g.header + top -- top of the first line box
    local last = first + (lines - 1) * g.line
    return { top = first + g.top_off, bottom = g.screen_h - (last + g.bottom_off) }
end

--- The gaps on a full page of body lines with these margins.
-- @treturn table top: from the top of the screen to the text block;
--   bottom: from the text block to the bottom of the screen
function Layout.gaps(g)
    return gapsAt(g, g.top, linesPerPage(g))
end

--- Computes the margins to use instead of the user's.
-- @treturn table top, bottom: the margins to use; lines: per page; clamped;
--   before, after: the gaps with the user's margins and with these
function Layout.compute(g)
    local lines = linesPerPage(g)
    local spare = g.top + g.bottom + math.max(0, area(g) - lines * g.line)
    -- Gap above: header + top + top_off. Gap below: (spare - top) + (line - bottom_off).
    local wanted = round((spare - g.header + g.line - g.bottom_off - g.top_off) / 2)
    -- Never move the page area into a status bar's space.
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
