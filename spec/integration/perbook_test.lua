-- "Enabled" and "Shift" are per-book settings; long-press sets the default for
-- newly opened books, as KOReader's own per-book settings do.
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeFalse("cre_partial_rerendering")
local a = H.freshBook("prose.html", "book-a.html")
local b = H.freshBook("prose.html", "book-b.html")
local c = H.freshBook("prose.html", "book-c.html")

test("each book keeps its own setting", function()
    local reader = H.reader(a)
    eq(false, reader.automargin:isEnabled(), "a, default")
    H.setEnabled(reader, true)
    assert(H.isFitted(reader), "a not fitted")
    reader = H.reader(b)
    eq(false, reader.automargin:isEnabled(), "b, default")
    reader = H.reader(a)
    eq(true, reader.automargin:isEnabled(), "a, reopened")
    assert(H.isFitted(reader), "a not fitted after reopening")
end)

test("long-press sets the default for newly opened books", function()
    local reader = H.reader(a)
    local item = H.menuItem(reader, "Enabled")
    eq("Enabled", item.text_func())
    item.hold_callback()
    local box = H.UIManager._window_stack[#H.UIManager._window_stack].widget
    eq("Disable (★)", box.choice1_text_func())
    eq("Enable", box.choice2_text_func())
    box.choice2_callback()
    H.UIManager:close(box)
    H.drain()
    eq(true, G_reader_settings:isTrue("automargin_enabled"), "default")
    eq("Enabled   ★", item.text_func())

    reader = H.reader(c)
    eq(true, reader.automargin:isEnabled(), "c, new book")
    assert(H.isFitted(reader), "c not fitted")
    -- b was opened before, while the default was off.
    reader = H.reader(b)
    eq(false, reader.automargin:isEnabled(), "b, opened before")
end)

local function setShiftWith(open, value)
    open { updateItems = function() end }
    local spin = H.top()
    spin.callback { value = value }
    H.UIManager:close(spin)
    H.drain()
end

test("the shift moves the page area, per book; long-press sets the default", function()
    local reader = H.reader(a)
    local centered = H.margins(reader)
    local item = H.menuItem(reader, "Shift: 0")
    setShiftWith(item.callback, 6)
    local px = H.Screen:scaleBySize(6)
    eq(centered.top + px, H.margins(reader).top, "top")
    eq(centered.bottom - px, H.margins(reader).bottom, "bottom")

    setShiftWith(item.hold_callback, -4)
    eq("Shift: +6", item.text_func())
    reader = H.reader(a)
    eq(6, reader.automargin.shift, "a, reopened")
    reader = H.reader(H.freshBook("prose.html", "book-d.html"))
    eq(-4, reader.automargin.shift, "new book")
    eq("Shift: -4   ★", H.menuItem(reader, "Shift: -4").text_func())
end)

test("the alignment is per book; long-press sets the default", function()
    local reader = H.reader(a)
    eq("center", reader.automargin.align, "a, default")
    H.menuItem(reader, "Top").callback()
    H.menuItem(reader, "Bottom").hold_callback { updateItems = function() end }
    eq("Bottom   ★", H.menuItem(reader, "Bottom").text_func())
    reader = H.reader(a)
    eq("top", reader.automargin.align, "a, reopened")
    reader = H.reader(H.freshBook("prose.html", "book-e.html"))
    eq("bottom", reader.automargin.align, "new book")
end)

test("the gesture action only changes the current book", function()
    local reader = H.reader(c)
    require("dispatcher"):execute({ automargin_toggle = true })
    H.drain()
    eq(false, reader.automargin:isEnabled(), "c")
    eq(true, G_reader_settings:isTrue("automargin_enabled"), "default")
end)

H.closeReader()
H.finish()
