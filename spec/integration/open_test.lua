-- Opening books with the plugin on, the per-book saved measurement, and
-- partial re-rendering (KOReader's default for EPUBs).
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeTrue("automargin_enabled")
G_reader_settings:makeFalse("cre_partial_rerendering")

-- crengine's margins when the reader first paints.
local first_paint
local ReaderView = require("apps/reader/modules/readerview")
local paintTo = ReaderView.paintTo
ReaderView.paintTo = function(self, ...)
    first_paint = first_paint or H.margins(self.ui)
    return paintTo(self, ...)
end

local function open(book)
    first_paint = nil
    H.resetCounts()
    local start = require("ui/time").now()
    local reader = H.reader(book)
    local ms = require("ui/time").to_ms(require("ui/time").since(start))
    return reader, ms
end

local book = H.freshBook("prose.html", "open.html")

test("a new book opens fitted and centered on its first paint", function()
    local reader, ms = open(book)
    assert(reader.automargin.measurement, reader.automargin.error)
    eq(1, H.count.samples, "samplings")
    eq(1, H.count.rerenders, "re-renders to fit")
    assert(H.isFitted(reader), "not fitted")
    local now = H.margins(reader)
    eq(now.top, first_paint.top, "top margin at first paint")
    eq(now.bottom, first_paint.bottom, "bottom margin at first paint")
    H.checkCentered(reader, "first open")
    print(("    opened in %.0f ms"):format(ms))
end)

test("reopening uses the saved measurement: no sampling, no extra render", function()
    local reader, ms = open(book)
    eq(0, H.count.samples, "samplings")
    eq(0, H.count.rerenders, "re-renders")
    assert(H.isFitted(reader), "not fitted")
    H.checkCentered(reader, "reopened")
    print(("    opened in %.0f ms"):format(ms))
end)

test("the samples agree on every test book", function()
    for _, name in ipairs({ "prose.html", "juliet.epub", "leaves.epub" }) do
        local reader = open(H.freshBook(name, "agree-" .. name))
        local m = assert(reader.automargin.measurement, name .. ": " .. tostring(reader.automargin.error))
        print(("    %-12s L=%d rows %d/%d/%d/%d (%.0f ms)"):format(name, m.L, m.a_off, m.x_off, m.b_off, m.d_off, m.ms))
    end
end)

test("with partial re-rendering, nothing changes until KOReader reloads the book", function()
    -- KOReader remembers the partial re-rendering setting per book: use a new one.
    G_reader_settings:makeTrue("cre_partial_rerendering")
    local reader = open(H.freshBook("leaves.epub", "partial.epub"))
    local plugin = reader.automargin
    local measurement, margins = plugin.measurement, H.margins(reader)
    reader:handleEvent(H.Event:new("SetFontSize", reader.document.configurable.font_size + 6))
    eq(measurement, plugin.measurement, "measurement")
    eq(margins.top, H.margins(reader).top, "top margin")
    eq(margins.bottom, H.margins(reader).bottom, "bottom margin")
    local reloaded = H.waitForReload(reader)
    local m = assert(reloaded.automargin.measurement, reloaded.automargin.error)
    assert(m.L ~= measurement.L, "measurement not updated")
    assert(H.isFitted(reloaded), "not fitted after the reload")
end)

H.closeReader()
H.finish()
