-- A Chinese book: with no x-height, the text block is the ideographs' box.
local H = require("harness").setup()
local test = H.test

-- Ideographs end at different rows, so the gaps seen on a page's first and
-- last lines alone can be a row off the measurement, which averages many lines.
local function checkCentered(reader, label)
    H.checkCentered(reader, label, 1)
end

G_reader_settings:makeFalse("cre_partial_rerendering")
G_reader_settings:makeTrue("automargin_enabled")
local reader = H.reader(H.writeProse("cjk.html", { cjk = true }))

test("is measured and centered", function()
    assert(reader.automargin.measurement, reader.automargin.error)
    checkCentered(reader, "default")
    H.shot("cjk")
end)

test("stays centered through font size changes", function()
    for _, size in ipairs({ 18, 26, 33 }) do
        H.send(reader, "SetFontSize", size)
        checkCentered(reader, "size " .. size)
    end
end)

H.closeReader()
H.finish()
