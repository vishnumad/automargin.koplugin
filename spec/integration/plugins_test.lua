-- Other plugins hooking the same margins, as ZenOS does for its top status bar.
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeTrue("automargin_enabled")
G_reader_settings:makeFalse("cre_partial_rerendering")

-- Like ZenOS: reserve space at the top for a status bar, on margin changes
-- that go through ReaderTypeset.
local RESERVE = 21
local CreDocument = require("document/credocument")
local ReaderTypeset = require("apps/reader/modules/readertypeset")
local setPageMargins, onSetPageMargins = CreDocument.setPageMargins, ReaderTypeset.onSetPageMargins
CreDocument.setPageMargins = function(doc, left, top, right, bottom)
    return setPageMargins(doc, left, top + (doc.test_reserve or 0), right, bottom)
end
ReaderTypeset.onSetPageMargins = function(typeset, ...)
    typeset.ui.document.test_reserve = RESERVE
    onSetPageMargins(typeset, ...)
    typeset.ui.document.test_reserve = nil
end

local function checkCentered(reader, label)
    eq(reader.automargin.applied[1] + RESERVE, reader.document:getPageMargins().top, label .. ": reserve kept")
    H.checkCentered(reader, label)
end

local reader = H.reader(H.freshBook("prose.html", "plugins.html"))

test("keeps the page area below the reserved space and centers the text on the screen", function()
    checkCentered(reader, "opened")
end)

test("keeps the reserve when a font change fits the page again", function()
    H.send(reader, "SetFontSize", 30)
    checkCentered(reader, "size 30")
end)

test("keeps fitting after KOReader's call cache is set up again", function()
    reader.document:setupCallCache()
    H.send(reader, "SetFontSize", 24)
    checkCentered(reader, "size 24")
end)

H.closeReader()
H.finish()
