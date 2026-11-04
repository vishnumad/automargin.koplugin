-- "Enabled" is a per-book setting; long-press sets the default for newly
-- opened books, as KOReader's own per-book settings do.
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

test("the gesture action only changes the current book", function()
    local reader = H.reader(c)
    require("dispatcher"):execute({ automargin_toggle = true })
    H.drain()
    eq(false, reader.automargin:isEnabled(), "c")
    eq(true, G_reader_settings:isTrue("automargin_enabled"), "default")
end)

H.closeReader()
H.finish()
