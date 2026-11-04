-- No page reaches into the margins the user set, even on pages that aren't
-- full pages of body text (plays, poetry, headings).
local H = require("harness").setup()
local test = H.test

G_reader_settings:makeFalse("cre_partial_rerendering")
G_reader_settings:makeTrue("automargin_enabled")

local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local ffi = require("ffi")

-- The first and last rows crengine draws ink on (status bars are drawn by ReaderView, not here).
local function inkRows(doc, bb, from)
    local W, h = bb:getWidth(), bb:getHeight()
    doc:drawCurrentView(bb, 0, 0, Geom:new { x = 0, y = 0, w = W, h = h })
    local data = ffi.cast("uint8_t*", bb.data)
    local first, last
    for y = from, h - 1 do
        local row = data + y * bb.stride
        for x = 0, W - 1 do
            if row[x] < 160 then
                first, last = first or y, y
                break
            end
        end
    end
    return first, last
end

for _, book in ipairs({ "juliet.epub", "leaves.epub" }) do
    test(book .. " at size 33: content stays inside the user's margins on every page", function()
        local reader = H.reader(H.freshBook(book, "margins-" .. book))
        H.send(reader, "SetFontSize", 33)
        assert(H.isFitted(reader), "not fitted")
        local doc, footer, l = reader.document, reader.view.footer, reader.automargin.layout
        local user = H.userMargins(reader)
        local hdr, bar = doc:getHeaderHeight(), footer.reclaim_height and 0 or footer:getHeight()
        -- The optical correction may move the text block up by a few px.
        local allowed_top = user.top - math.max(0, user.top - l.top)
        local bb = Blitbuffer.new(H.Screen:getWidth(), H.Screen:getHeight(), Blitbuffer.TYPE_BB8)
        local worst_top, worst_bottom = math.huge, math.huge
        local page = doc:getCurrentPage()
        for p = 2, doc:getPageCount() do
            doc:gotoPage(p)
            local first, last = inkRows(doc, bb, hdr)
            if first then
                worst_top = math.min(worst_top, first - hdr)
                worst_bottom = math.min(worst_bottom, (bb:getHeight() - bar) - (last + 1))
            end
        end
        doc:gotoPage(page)
        bb:free()
        print(
            ("    margins %d/%d, closest content %d px from the top, %d px from the status bar"):format(
                user.top,
                user.bottom - bar,
                worst_top,
                worst_bottom
            )
        )
        assert(worst_top >= allowed_top, "content inside the top margin")
        assert(worst_bottom >= user.bottom - bar, "content inside the bottom margin")
    end)
end

H.closeReader()
H.finish()
