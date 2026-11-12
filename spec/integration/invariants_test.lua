-- Sampling and fitting must not disturb the reader: position, events, highlights.
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeFalse("cre_partial_rerendering")
local reader = H.reader(H.freshBook("prose.html", "invariants.html"))
local doc = reader.document

local events = {}
local handleEvent = reader.handleEvent
reader.handleEvent = function(self, event)
    events[#events + 1] = event.handler
    return handleEvent(self, event)
end

H.send(reader, "GotoPage", 5)

test("sampling leaves the reader where it was and sends no events", function()
    local before = {
        page = doc:getCurrentPage(),
        xpointer = doc:getXPointer(),
        rolling = reader.rolling.xpointer,
        view = reader.view.state.page,
        pages = doc:getPageCount(),
        hash = doc:getDocumentRenderingHash(true),
    }
    events = {}
    local m = assert(H.Measure.sample(doc, H.Screen:getWidth(), H.Screen:getHeight()))
    eq(0, #events, "events sent")
    eq(before.page, doc:getCurrentPage(), "page")
    eq(before.xpointer, doc:getXPointer(), "xpointer")
    eq(before.rolling, reader.rolling.xpointer, "reading position")
    eq(before.view, reader.view.state.page, "view page")
    eq(before.pages, doc:getPageCount(), "page count")
    eq(before.hash, doc:getDocumentRenderingHash(true), "rendering hash")
    print(("    sampled in %.1f ms"):format(m.ms))
end)

test("sampling starts with the current page and stops once two pages agree", function()
    local drawn, draw = {}, doc.drawCurrentView
    doc.drawCurrentView = function(this, ...)
        table.insert(drawn, this:getCurrentPage())
        return draw(this, ...)
    end
    local page = doc:getCurrentPage()
    assert(H.Measure.sample(doc, H.Screen:getWidth(), H.Screen:getHeight()))
    doc.drawCurrentView = draw
    eq(2, #drawn, "pages drawn")
    eq(page, drawn[1], "first page drawn")
end)

-- A highlight over the first three lines of the page.
local text = doc:getTextFromPositions({ x = 0, y = 0 }, { x = H.Screen:getWidth(), y = 80 }, true)
reader.annotation:addItem { page = text.pos0, pos0 = text.pos0, pos1 = text.pos1, text = text.text, drawer = "lighten" }

local function highlightY()
    local boxes = assert(reader.view.highlight.page_boxes[doc:getCurrentPage()], "highlight not drawn")
    return boxes[1].rect.y
end

H.shot("highlight-off")
local highlight_before = highlightY()

test("fitting re-renders once and keeps the reading position", function()
    local xpointer = reader.rolling.xpointer
    H.resetCounts()
    H.setEnabled(reader, true)
    assert(H.isFitted(reader), "not fitted")
    eq(1, H.count.rerenders, "re-renders")
    eq(xpointer, reader.rolling.xpointer, "reading position")
end)

test("highlights move with the text", function()
    H.send(reader, "GotoXPointer", text.pos0)
    H.shot("highlight-on")
    local text_y = doc:getScreenBoxesFromPositions(text.pos0, text.pos1, true)[1].y
    eq(text_y, highlightY(), "highlight box")
    assert(text_y ~= highlight_before, "test needs the text to move")
end)

H.finish()
