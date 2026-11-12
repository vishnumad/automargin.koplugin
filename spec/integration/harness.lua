--[[--
Integration harness: runs AutoMargin inside a real (headless) KOReader.

Run through spec/integration/run.sh, which sets KO_HOME to a scratch dir and
starts the emulator's luajit from the KOReader build dir.
]]

local H = {}

local PLUGIN_DIR = os.getenv("AUTOMARGIN_DIR")
local HOME = os.getenv("KO_HOME")

local SENTENCES = {
    "The house stood at the end of a long lane, half hidden behind a row of old beech trees whose branches met overhead and made a kind of green tunnel in the summer months.",
    "Nobody in the village could remember who had built it, though everyone had an opinion, and most of those opinions were offered freely to anyone who happened to be standing nearby with a glass in hand.",
    "She walked quickly, keeping her eyes on the uneven ground, and did not look up until she reached the gate, where she stopped and listened for a long moment to the quiet ticking of the evening.",
    "It was the kind of light that makes ordinary things look important: a wheelbarrow tipped against a wall, a bicycle with a flat tyre, a dog asleep in a patch of dust beside the open door.",
    "He had always believed that a person could be judged by the way they treated their books, and by that measure his uncle was either a saint or a lunatic, depending on which room you happened to enter first.",
    "There were letters in the drawer, dozens of them, tied with string and arranged by year, and the earliest had been written in a hand so careful and so small that she needed a lamp to make out the words.",
    "By morning the fog had lifted, and the fields below the ridge lay bright and wet under a sky that seemed far too large for the quiet little valley it was supposed to cover.",
    "Questions, he thought, were like stones in a stream: you could step from one to the next and reach the other side, or you could pick one up and find something living underneath.",
    "The kitchen smelled of bread and woodsmoke and something sharper that she could not quite name, and she stood for a while in the doorway, unwilling to break whatever spell was holding the room together.",
    "Nothing happened for three days, and then everything happened at once, which is how most important things seem to arrive, quietly at first and then with a rush that leaves no time for thinking.",
}

local CJK_SENTENCES = {
    "那座房子立在一条长巷的尽头，一半藏在一排老山毛榉树后面，夏天的时候，树枝在头顶交会，像一条绿色的隧道。",
    "村里没有人记得是谁建造了它，不过每个人都有自己的看法，而且很乐意说给任何站在旁边端着酒杯的人听。",
    "她走得很快，眼睛盯着坑坑洼洼的地面，一直走到大门口才抬起头，停下来静静地听了很久傍晚的声音。",
    "那种光线会让普通的东西显得很重要：靠在墙边的手推车，轮胎瘪了的自行车，睡在敞开的门旁边尘土里的狗。",
    "抽屉里有几十封信，用绳子捆着，按年份排好，最早的那几封字写得又小又工整，她得点上灯才看得清。",
    "到了早上，雾已经散了，山岭下面的田野在天空下又亮又湿，那片天空对这个安静的小山谷来说似乎太大了。",
}

--- Writes a book of three chapters of novel-style paragraphs. With no
-- paragraph spacing, every page inside a chapter is a full page of body lines.
-- opts.p: CSS for the paragraphs; opts.cjk: Chinese text.
function H.writeProse(name, opts)
    opts = opts or {}
    local sentences = opts.cjk and CJK_SENTENCES or SENTENCES
    local body, n = {}, 0
    for chapter = 1, 3 do
        table.insert(body, ("<h2>Chapter %d</h2>"):format(chapter))
        for _ = 1, 45 do
            local p = {}
            for i = 1, 3 do
                n = n + 1
                p[i] = sentences[(n * 7) % #sentences + 1]
            end
            table.insert(body, "<p>" .. table.concat(p, opts.cjk and "" or " ") .. "</p>")
        end
    end
    local f = assert(io.open(H.book(name), "w"))
    f:write(
        ('<!DOCTYPE html><html lang="%s"><head><meta charset="utf-8"><title>Prose</title>'):format(
            opts.cjk and "zh" or "en"
        ),
        "<style>p { margin: 0; text-indent: 1.5em; text-align: justify; } h2 { text-align: center; } p { ",
        opts.p or "",
        " }</style></head><body>",
        table.concat(body, "\n"),
        "</body></html>"
    )
    f:close()
    return name
end

--- Writes a book that can't be measured: verse with too few long lines on a
-- page. Like most books, it's large enough for crengine to cache (over 64 KB):
-- an uncached book's rendering hash after a re-render differs from the one it
-- opens with, so it would be sampled again once more on reopening.
function H.writeVerse(name)
    local lines = {}
    for i = 1, 4000 do
        table.insert(lines, i % 12 == 0 and "<p>And all the long evening the rain kept on</p>" or "<p>A short line</p>")
    end
    local f = assert(io.open(H.book(name), "w"))
    f:write(
        '<!DOCTYPE html><html><head><meta charset="utf-8"><title>Verse</title>',
        "<style>p { margin: 0; text-indent: 0; }</style></head><body>",
        table.concat(lines, "\n"),
        "</body></html>"
    )
    f:close()
    return name
end

local function realpath(path)
    local f = assert(io.popen(("realpath -e %q 2>/dev/null"):format(path)))
    local resolved = f:read("*l")
    f:close()
    return resolved
end

--- Starts KOReader with the plugin. opts.w, opts.h, opts.dpi resize the dummy screen.
function H.setup(opts)
    opts = opts or {}
    require("setupkoenv")
    package.path = "spec/front/unit/?.lua;" .. package.path
    require("commonrequire")
    H.Screen = require("device").screen
    if opts.w then
        local Blitbuffer = require("ffi/blitbuffer")
        H.Screen.bb:free()
        H.Screen.bb = Blitbuffer.new(opts.w, opts.h)
        H.Screen.dpi = opts.dpi
    end
    local lfs = require("libs/libkoreader-lfs")
    for _, dir in ipairs({ "settings", "shots", "books", "plugins" }) do
        lfs.mkdir(HOME .. "/" .. dir)
    end
    -- A KOReader checkout may already have the plugin linked into its plugins/
    -- folder: loading it from there and from extra_plugin_paths would run two
    -- instances.
    local installed, ours = realpath("plugins/automargin.koplugin"), realpath(PLUGIN_DIR)
    if installed then
        assert(installed == ours, "KOReader's plugins/automargin.koplugin is another copy: " .. installed)
    else
        os.execute(("ln -sfn %q %q"):format(PLUGIN_DIR, HOME .. "/plugins/automargin.koplugin"))
        G_reader_settings:saveSetting("extra_plugin_paths", { HOME .. "/plugins" })
    end
    for _, f in ipairs({ "juliet.epub", "leaves.epub" }) do
        os.execute(("cp --update=none spec/front/unit/data/%s %q"):format(f, HOME .. "/books/"))
    end
    H.writeProse("prose.html")
    -- autosuspend reschedules itself on every input, and zenos's tbr_index
    -- task never returns, so fastforward_ui_events hangs. storefront's startup
    -- catalog update can show a notice on top of a test's dialog.
    G_reader_settings:saveSetting("plugins_disabled", { autosuspend = true, storefront = true, zenos = true })
    G_reader_settings:delSetting("automargin_enabled")
    local PluginLoader = require("pluginloader")
    PluginLoader.enabled_plugins = nil
    PluginLoader:loadPlugins()

    -- A KOReader checkout can be ahead of the base it was built with: closing
    -- a book then fails on this binding (added after v2026.07.1).
    local CreDocument = require("document/credocument")
    local getEPubCFI = CreDocument.getEPubCFIFromXPointer
    if getEPubCFI then
        CreDocument.getEPubCFIFromXPointer = function(doc, xp)
            if doc._document.getEPubCFIFromXPointer then return getEPubCFI(doc, xp) end
        end
    end

    H.UIManager = require("ui/uimanager")
    H.Event = require("ui/event")
    H.Edges = require("automargin/edges")
    H.Measure = require("automargin/measure")

    -- Re-renders and samplings, for tests to reset and check.
    H.count = { rerenders = 0, samples = 0 }
    local ReaderView = require("apps/reader/modules/readerview")
    local onDocumentRerendered = ReaderView.onDocumentRerendered
    ReaderView.onDocumentRerendered = function(...)
        H.count.rerenders = H.count.rerenders + 1
        return onDocumentRerendered(...)
    end
    local sample = H.Measure.sample
    ---@diagnostic disable-next-line: duplicate-set-field
    H.Measure.sample = function(...)
        H.count.samples = H.count.samples + 1
        return sample(...)
    end
    return H
end

function H.resetCounts()
    H.count.rerenders, H.count.samples = 0, 0
end

--- Waits for KOReader to reload the book after partial re-rendering: it does
-- once the layout is done in the background, a few seconds of wall-clock time
-- after the last input. Returns the new reader.
function H.waitForReload(reader)
    local ReaderUI = require("apps/reader/readerui")
    for _ = 1, 60 do
        if ReaderUI.instance ~= reader then break end
        require("ffi/util").usleep(250000)
        H.drain(1)
    end
    H.drain()
    assert(ReaderUI.instance ~= reader, "book not reloaded")
    return ReaderUI.instance
end

function H.drain(n)
    for _ = 1, n or 3 do
        fastforward_ui_events()
    end
end

function H.tap(x, y)
    local Geom = require("ui/geometry")
    local ges = { ges = "tap", pos = Geom:new { x = x, y = y, w = 0, h = 0 }, time = require("ui/time").now() }
    H.UIManager:sendEvent(H.Event:new("Gesture", ges))
    H.drain()
end

function H.top()
    return H.UIManager:getTopmostVisibleWidget() or H.UIManager._window_stack[#H.UIManager._window_stack].widget
end

function H.tapButton(text, widget)
    for _, line in ipairs((widget or H.top()).button_table.buttons_layout) do
        for _, b in ipairs(line) do
            if b.text == text then
                local d = b.dimen
                return H.tap(d.x + math.floor(d.w / 2), d.y + math.floor(d.h / 2))
            end
        end
    end
    error("no button " .. text)
end

function H.book(name)
    return HOME .. "/books/" .. name
end

--- A copy of a test book under a new name, so it opens with no saved settings.
function H.freshBook(name, as)
    os.execute(("cp %q %q"):format(H.book(name), H.book(as)))
    return as
end

function H.reader(file)
    local ReaderUI = require("apps/reader/readerui")
    local DocumentRegistry = require("document/documentregistry")
    H.closeReader()
    local reader = ReaderUI:new {
        dimen = H.Screen:getSize(),
        document = DocumentRegistry:openDocument(H.book(file)),
    }
    H.UIManager:show(reader)
    H.drain()
    return reader
end

function H.closeReader()
    local ReaderUI = require("apps/reader/readerui")
    if ReaderUI.instance then
        ReaderUI.instance:onClose()
        H.drain()
    end
end

function H.send(reader, name, ...)
    reader:handleEvent(H.Event:new(name, ...))
    H.drain()
end

function H.setEnabled(reader, enabled)
    if reader.automargin:isEnabled() ~= enabled then H.send(reader, "ToggleAutoMargin") end
end

--- An item of the plugin's menu, submenus included, by its text without the
-- default marker (★).
function H.menuItem(reader, text)
    local items = {}
    reader.automargin:addToMainMenu(items)
    local function find(list)
        for _, item in ipairs(list) do
            local label = item.text or item.text_func()
            if label:gsub("%s*★$", "") == text then return item end
            local found = item.sub_item_table and find(item.sub_item_table)
            if found then return found end
        end
    end
    return find(items.automargin.sub_item_table) or error("no menu item " .. text)
end

--- Repaint everything and save a PNG.
function H.shot(name)
    H.UIManager:setDirty("all", "full")
    H.drain(1)
    local path = HOME .. "/shots/" .. name .. ".png"
    H.Screen:shot(path)
    return path
end

-- Edges of one line, from its own ink.
local function lineEdges(bb, line)
    return H.Edges.find(H.Measure.inkProfile(bb, { line }, line.h), line.h)
end

--- The gaps on the rendered current page, from the ink of its first and last
-- lines. Returns nil unless the page is a full page of same-height lines.
function H.observedGaps(reader)
    local doc = reader.document
    local W, h = H.Screen:getWidth(), H.Screen:getHeight()
    local text = doc:getTextFromPositions({ x = 0, y = 0 }, { x = W, y = h }, true)
    local lines = H.Edges.lines(text and text.sboxes or {})
    local first, last = lines[1], lines[#lines]
    if not first then return end
    local m, hdr = doc:getPageMargins(), doc:getHeaderHeight()
    local N = math.floor((h - m.top - m.bottom - hdr) / first.h)
    if #lines ~= N or first.y ~= m.top + hdr or last.h ~= first.h then return end
    local Blitbuffer = require("ffi/blitbuffer")
    local Geom = require("ui/geometry")
    local bb = Blitbuffer.new(W, h, Blitbuffer.TYPE_BB8)
    doc:drawCurrentView(bb, 0, 0, Geom:new { x = 0, y = 0, w = W, h = h })
    local top, bottom = lineEdges(bb, first), lineEdges(bb, last)
    bb:free()
    if not (top and bottom) then return end
    -- The edges chosen in the menu.
    local top_off = G_reader_settings:isTrue("automargin_ascender") and top.a_off or top.x_off
    local bottom_off = G_reader_settings:isTrue("automargin_descender") and bottom.d_off or bottom.b_off
    return { top = first.y + top_off, bottom = h - (last.y + bottom_off) }
end

--- Goes to the first full page in the middle part of the book, or fails.
function H.gotoFullPage(reader)
    local doc = reader.document
    local count = doc:getPageCount()
    for page = math.floor(count * 0.3), count do
        H.send(reader, "GotoPage", page)
        local gaps = H.observedGaps(reader)
        if gaps then return gaps, page end
    end
    error("no full page")
end

--- The {top, bottom} page margins the user set, in crengine's terms.
function H.userMargins(reader)
    local u, footer = reader.typeset.unscaled_margins, reader.view.footer
    local bar = footer.reclaim_height and 0 or footer:getHeight()
    return { top = H.Screen:scaleBySize(u[2]), bottom = H.Screen:scaleBySize(u[4]) + bar }
end

--- The {top, bottom} page margins crengine uses.
function H.margins(reader)
    local m = reader.document:getPageMargins()
    return { top = m.top, bottom = m.bottom }
end

function H.isFitted(reader)
    local user, now = H.userMargins(reader), H.margins(reader)
    return user.top ~= now.top or user.bottom ~= now.bottom
end

--- Checks that a full page matches the plugin's prediction and is centered.
-- slack: how far, in px, the gaps seen on the page's first and last lines
-- may be from the prediction (0 by default).
function H.checkCentered(reader, label, slack)
    slack = slack or 0
    local plugin = reader.automargin
    local gaps = H.gotoFullPage(reader)
    local l = assert(plugin.fit.layout, label .. ": no layout")
    local function near(predicted, seen, what)
        assert(
            math.abs(predicted - seen) <= slack,
            ("%s: predicted %s gap: expected %d, got %d"):format(label, what, predicted, seen)
        )
    end
    near(l.after.top, gaps.top, "top")
    near(l.after.bottom, gaps.bottom, "bottom")
    assert(math.abs(gaps.top - gaps.bottom) <= 1 + 2 * slack, ("%s: gaps %d / %d"):format(label, gaps.top, gaps.bottom))
    local m, user = plugin.measurement, H.userMargins(reader)
    io.stdout:write(
        ("    %-20s L=%d rows %d/%d/%d/%d, gaps %d/%d -> %d/%d, margins %d/%d -> %d/%d\n"):format(
            label,
            m.L,
            m.a_off,
            m.x_off,
            m.b_off,
            m.d_off,
            l.before.top,
            l.before.bottom,
            gaps.top,
            gaps.bottom,
            user.top,
            user.bottom,
            l.top,
            l.bottom
        )
    )
end

-- Tiny test runner -------------------------------------------------------

local results = { pass = 0, fail = 0 }

function H.test(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        results.pass = results.pass + 1
        io.stdout:write("  ok   ", name, "\n")
    else
        results.fail = results.fail + 1
        io.stdout:write("  FAIL ", name, "\n", err, "\n")
    end
    H.drain()
end

function H.eq(expected, actual, msg)
    if expected ~= actual then
        error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", tostring(expected), tostring(actual)), 2)
    end
end

function H.finish()
    io.stdout:write(("\n%d passed, %d failed\n"):format(results.pass, results.fail))
    os.exit(results.fail == 0 and 0 or 1)
end

return H
