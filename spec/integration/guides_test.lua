-- Debug › Show guide lines draws where the text block sits.
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeTrue("automargin_enabled")
G_reader_settings:makeFalse("cre_partial_rerendering")
local reader = H.reader(H.freshBook("prose.html", "guides.html"))
local doc, footer = reader.document, reader.view.footer

-- Gray level of the screen at x = 1, inside the left margin, after a repaint.
local function shade(row)
    return H.Screen.bb:getPixel(1, row):getColor8().a
end
local function isBlack(row)
    return shade(row) < 0x20
end
local function isGray(row)
    return shade(row) > 0x40 and shade(row) < 0xC0
end

-- The rows the lines should be on, from the ink of a full page.
local function expectedRows()
    local gaps = H.gotoFullPage(reader)
    local m, hdr = doc:getPageMargins(), doc:getHeaderHeight()
    local h, bar = H.Screen:getHeight(), footer.reclaim_height and 0 or footer:getHeight()
    return {
        text_top = hdr + gaps.top - 1,
        text_bottom = h - bar - gaps.bottom,
        area_top = hdr + m.top,
        area_bottom = h - m.bottom - 1,
        bar = h - bar,
        header = hdr - 1,
    }
end

local function toggleGuides()
    H.menuItem(reader, "Show guide lines").callback()
    H.drain()
end

test("Show measurements and the guides live in the Debug menu", function()
    local items = {}
    reader.automargin:addToMainMenu(items)
    for _, item in ipairs(items.automargin.sub_item_table) do
        assert(item.text ~= "Show measurements", "Show measurements at the top level")
    end
    H.menuItem(reader, "Debug")
    eq(false, H.menuItem(reader, "Show guide lines").checked_func())
end)

test("the guides mark the text block, the text area and the status bar", function()
    toggleGuides()
    local rows = expectedRows()
    H.shot("guides-on")
    assert(isBlack(rows.text_top), "no line above the x-height")
    assert(isBlack(rows.text_bottom), "no line below the baseline")
    assert(isGray(rows.area_top), "no line at the top of the text area")
    assert(isGray(rows.area_bottom), "no line at the bottom of the text area")
    assert(isBlack(rows.bar), "no line at the status bar")
    assert(shade(rows.text_top - 3) > 0xF0, "the top gap isn't clear")
end)

test("with AutoMargin off for the book, they show the uncentered text block", function()
    H.setEnabled(reader, false)
    local rows = expectedRows()
    H.shot("guides-off-for-book")
    assert(isBlack(rows.text_top), "no line above the x-height")
    assert(isBlack(rows.text_bottom), "no line below the baseline")
    H.setEnabled(reader, true)
end)

test("with the top status bar, they mark its bottom too", function()
    H.send(reader, "SetStatusLine", 0)
    local rows = expectedRows()
    H.shot("guides-header")
    assert(isBlack(rows.header), "no line at the top status bar")
    assert(isBlack(rows.text_top), "no line above the x-height")
    H.send(reader, "SetStatusLine", 1)
end)

test("with the ascender and descender as edges, they mark those", function()
    H.menuItem(reader, "Ascender").callback()
    H.menuItem(reader, "Descender").callback()
    local rows = expectedRows()
    H.shot("guides-ascender-descender")
    assert(isBlack(rows.text_top), "no line above the ascenders")
    assert(isBlack(rows.text_bottom), "no line below the descenders")
    H.menuItem(reader, "Midline").callback()
    H.menuItem(reader, "Baseline").callback()
end)

test("turning them off removes them", function()
    toggleGuides()
    eq(false, H.menuItem(reader, "Show guide lines").checked_func())
    local rows = expectedRows()
    H.shot("guides-removed")
    assert(shade(rows.text_top) > 0xF0, "line above the x-height still drawn")
    assert(shade(rows.text_bottom) > 0xF0, "line below the baseline still drawn")
end)

H.closeReader()
H.finish()
