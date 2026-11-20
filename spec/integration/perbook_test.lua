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

-- Sets a value in the dialog that tapping or long-pressing "Shift" opens.
local function setShiftWith(open, value)
    open()
    local spin = H.UIManager._window_stack[#H.UIManager._window_stack].widget
    spin.callback({ value = value })
    H.UIManager:close(spin)
    H.drain()
end

test("the shift moves the page area, per book; long-press sets the default", function()
    local reader = H.reader(a)
    local centered = H.margins(reader)
    local item = H.menuItem(reader, "Shift: 0")
    eq("Shift: 0   ★", item.text_func())
    setShiftWith(item.callback, 6)
    eq("Shift: +6", item.text_func())
    local px = H.Screen:scaleBySize(6)
    local shifted = H.margins(reader)
    eq(centered.top + px, shifted.top, "top")
    eq(centered.bottom - px, shifted.bottom, "bottom")

    reader = H.reader(b)
    eq(0, reader.automargin.shift, "b")
    reader = H.reader(a)
    eq(6, reader.automargin.shift, "a, reopened")
    eq(shifted.top, H.margins(reader).top, "a, reopened")

    item = H.menuItem(reader, "Shift: +6")
    setShiftWith(item.hold_callback, -4)
    eq(-4, G_reader_settings:readSetting("automargin_shift"), "default")
    eq(6, reader.automargin.shift, "a keeps its own")
    eq("Shift: +6", item.text_func())
    reader = H.reader(H.freshBook("prose.html", "book-d.html"))
    eq(-4, reader.automargin.shift, "d, new book")
    eq("Shift: -4   ★", H.menuItem(reader, "Shift: -4").text_func())
    G_reader_settings:delSetting("automargin_shift")
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
