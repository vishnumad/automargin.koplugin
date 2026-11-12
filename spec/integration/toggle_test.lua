-- To try several font settings quickly: turn AutoMargin off for the book,
-- change them, and turn it back on.
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeTrue("automargin_enabled")
G_reader_settings:makeFalse("cre_partial_rerendering")
local reader = H.reader(H.freshBook("prose.html", "toggle.html"))

test("while it's off, each change renders once and nothing is measured", function()
    H.setEnabled(reader, false)
    H.resetCounts()
    H.send(reader, "SetFontSize", 26)
    H.send(reader, "SetLineSpace", 110)
    eq(2, H.count.rerenders, "re-renders")
    eq(0, H.count.samples, "samplings")
end)

test("turning it back on measures and fits in a single render", function()
    H.resetCounts()
    H.setEnabled(reader, true)
    eq(1, H.count.samples, "samplings")
    eq(1, H.count.rerenders, "re-renders")
    H.checkCentered(reader, "turned back on")
end)

test("turning it on says when the book can't be measured", function()
    local Notification = require("ui/widget/notification")
    local notify, said = Notification.notify, nil
    Notification.notify = function(this, text, ...)
        said = text
        return notify(this, text, ...)
    end
    G_reader_settings:makeFalse("automargin_enabled")
    reader = H.reader(H.writeVerse("toggle-verse.html"))
    H.setEnabled(reader, true)
    Notification.notify = notify
    eq("AutoMargin couldn't measure this book", said)
end)

H.closeReader()
H.finish()
