-- Aligned to the top or bottom, the gap there matches the gap at the sides (600x800).
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeFalse("cre_partial_rerendering")
G_reader_settings:makeTrue("automargin_enabled")
-- With KOReader's default side margins (10), the gap above the first line's
-- x-height inside its line box is already wider than the side gap.
G_reader_settings:saveSetting("copt_h_page_margins", { 25, 25 })
local book = H.freshBook("prose.html", "aligned.html")
local reader = H.reader(book)
local plugin = reader.automargin

local function align(text)
    H.resetCounts()
    H.menuItem(reader, text).callback()
    H.drain()
    eq(0, H.count.rerenders, text .. ": re-renders")
end

test("top: the gap above is the side gap, without re-rendering", function()
    align("Top")
    eq("Alignment: Top", H.menuItem(reader, "Alignment: Top").text_func())
    H.checkAligned(reader, "top")
    H.shot("aligned-top")
end)

test("bottom: the gap below is the side gap, without re-rendering", function()
    H.setOverlap(reader, true)
    align("Bottom")
    H.checkAligned(reader, "bottom")
    H.shot("aligned-bottom-overlap")
end)

test("stays aligned through a font size change", function()
    H.setOverlap(reader, false)
    align("Top")
    H.send(reader, "SetFontSize", 26)
    H.checkAligned(reader, "top, size 26")
end)

test("a measurement saved without the side gap: centering doesn't sample, aligning samples once", function()
    align("Center")
    plugin.measurement.side = nil
    plugin:save()
    H.resetCounts()
    reader = H.reader(book)
    plugin = reader.automargin
    eq(nil, plugin.measurement.side, "side on reopening")
    eq(0, H.count.samples, "samplings on reopening")
    eq(0, H.count.rerenders, "re-renders on reopening")
    local text = plugin:describe()
    assert(not text:find("Gap at the sides", 1, true), text)
    align("Top")
    eq(1, H.count.samples, "samplings")
    H.checkAligned(reader, "top, side measured")
end)

test("bottom with the status bar and default side margins: the text sits just above the bar", function()
    H.setOverlap(reader, false)
    H.send(reader, "SetPageHorizMargins", { 10, 10 })
    align("Bottom")
    assert(plugin.fit.layout.clamped, "not clamped")
    eq(reader.view.footer:getHeight(), H.margins(reader).bottom)
    local text = plugin:describe()
    assert(text:find("only partly aligned", 1, true), text)
    H.shot("aligned-bottom")
end)

H.closeReader()
H.finish()
