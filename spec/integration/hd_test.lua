-- A 1072x1448, 300 dpi screen, where the gaps start furthest apart, and rotation
-- with one and two columns.
local H = require("harness").setup { w = 1072, h = 1448, dpi = 300 }
local test, eq = H.test, H.eq

G_reader_settings:makeFalse("cre_partial_rerendering")
local reader = H.reader("prose.html")
H.setEnabled(reader, true)

test("font sizes", function()
    for _, size in ipairs({ 20, 24, 28, 32 }) do
        H.send(reader, "SetFontSize", size)
        H.checkCentered(reader, "size " .. size)
    end
    H.shot("hd-size32")
end)

test("rotation", function()
    H.send(reader, "SetRotationMode", 1)
    eq(1448, H.Screen:getWidth(), "screen width after rotation")
    H.checkCentered(reader, "landscape")
    H.shot("hd-landscape")
    H.send(reader, "SetVisiblePages", 2)
    eq(2, reader.document:getVisiblePageCount(), "columns")
    H.checkCentered(reader, "two columns")
    H.shot("hd-two-columns")
    H.send(reader, "SetVisiblePages", 1)
    H.send(reader, "SetRotationMode", 0)
    eq(1072, H.Screen:getWidth(), "screen width after rotating back")
    H.checkCentered(reader, "portrait")
end)

H.finish()
