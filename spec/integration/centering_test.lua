-- Centering on full prose pages across fonts, sizes, line spacings and status bars (600x800).
local H = require("harness").setup()
local test, eq = H.test, H.eq

G_reader_settings:makeFalse("cre_partial_rerendering")
local reader = H.reader("prose.html")
local plugin = reader.automargin

local function checkCentered(label)
    H.checkCentered(reader, label)
end

test("is off by default and leaves the margins alone", function()
    eq(false, plugin:isEnabled())
    eq(false, H.isFitted(reader))
    eq(nil, plugin.measurement)
end)

test("turning it on centers a full page", function()
    H.gotoFullPage(reader)
    H.shot("prose-off")
    H.setEnabled(reader, true)
    assert(plugin.measurement, plugin.error)
    checkCentered("default")
    H.shot("prose-on")
end)

test("stays centered through font, size and line spacing changes", function()
    local cases = {
        { "SetFontSize", 18 },
        { "SetFontSize", 26 },
        { "SetFontSize", 33 },
        { "SetLineSpace", 120 },
        { "SetLineSpace", 90 },
        { "SetFont", "Noto Sans" },
        { "SetFont", "FreeSerif" },
        { "SetFontSize", 21 },
        { "SetLineSpace", 100 },
        { "SetFont", "Noto Serif" },
        { "SetFontSize", 22 },
    }
    for _, c in ipairs(cases) do
        H.send(reader, c[1], c[2])
        checkCentered(c[1] .. " " .. tostring(c[2]))
    end
end)

test("top status bar", function()
    H.send(reader, "SetStatusLine", 0)
    assert(reader.document:getHeaderHeight() > 0, "header not shown")
    checkCentered("header on")
    H.shot("prose-header")
    H.send(reader, "SetStatusLine", 1)
    eq(0, reader.document:getHeaderHeight())
    checkCentered("header off")
end)

test("overlap status bar", function()
    local footer = reader.view.footer
    -- What the "Overlap status bar" menu item does.
    local function setOverlap(on)
        footer.settings.reclaim_height = on
        footer.reclaim_height = on
        footer:refreshFooter(true, true)
        H.drain()
    end
    setOverlap(true)
    checkCentered("overlap on")
    H.shot("prose-overlap")
    setOverlap(false)
    checkCentered("overlap off")
end)

test("margin changes that keep the total stay centered", function()
    local typeset = reader.typeset
    local t, b = typeset.unscaled_margins[2], typeset.unscaled_margins[4]
    H.send(reader, "SetPageTopAndBottomMargin", { t + 5, b - 5 })
    checkCentered("top +5 bottom -5")
    H.send(reader, "SetPageTopAndBottomMargin", { t, b })
end)

test("scroll mode uses the user's margins, page mode fits again", function()
    assert(H.isFitted(reader), "not fitted")
    H.send(reader, "SetViewMode", "scroll")
    eq(false, H.isFitted(reader), "fitted in scroll mode")
    H.send(reader, "SetViewMode", "page")
    assert(H.isFitted(reader), "not fitted again")
    checkCentered("back to page mode")
end)

test("Show measurements describes the fit", function()
    local text, l = plugin:describe(), plugin.layout
    assert(text:find(("Line height: %d px, %d lines a page"):format(plugin.measurement.L, l.lines), 1, true), text)
    assert(text:find(("Gap above: %d → %d px"):format(l.before.top, l.after.top), 1, true), text)
    assert(text:find(("Gap below: %d → %d px"):format(l.before.bottom, l.after.bottom), 1, true), text)
end)

test("turning it off restores the user's margins", function()
    H.setEnabled(reader, false)
    local user, now = H.userMargins(reader), H.margins(reader)
    eq(user.top, now.top, "top")
    eq(user.bottom, now.bottom, "bottom")
    eq("AutoMargin is off for this book.", plugin:describe())
end)

H.finish()
