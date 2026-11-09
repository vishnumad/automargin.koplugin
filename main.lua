--[[--
AutoMargin: keeps the text block optically centered on the page.

The page area is trimmed to a whole number of body lines and placed so the gap
above the first line's x-height (or ascenders) equals the gap below the last
line's baseline (or descenders), see automargin/layout. Only the margins given
to crengine change: the user's settings are untouched, so turning the plugin
off brings back what they had.
]]

local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local Layout = require("automargin/layout")
local Measure = require("automargin/measure")
local Notification = require("ui/widget/notification")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")
local T = require("ffi/util").template

-- Per book, as KOReader does: the book's own value once it has been opened,
-- and in G_reader_settings, the default (★) for newly opened books.
local ENABLED = "automargin_enabled"
-- Per book: the last measurement and the rendering hash it was made on.
local SAVED = "automargin"
-- Where the text block starts and ends: the ascender line instead of the
-- midline (x-height), the descender line instead of the baseline.
local ASCENDER = "automargin_ascender"
local DESCENDER = "automargin_descender"
-- Debug: draw where the text block sits.
local GUIDES = "automargin_guides"

local AutoMargin = WidgetContainer:extend {
    name = "automargin",
    is_doc_only = true,
    enabled = false, -- for this book
    margins = nil, -- the last top and bottom margins ReaderTypeset set
    applied = nil, -- the {top, bottom} margins given to crengine
    reserved = 0, -- space other plugins add to the top margin, e.g. ZenOS for its status bar
    measurement = nil, -- {L, a_off, x_off, b_off, d_off, ms}, see automargin/edges
    measured_hash = nil, -- the rendering the last measurement was made on
    error = nil, -- why the last measurement failed
    layout = nil, -- see automargin/layout, for "Show measurements"
    remeasuring = false,
}

function AutoMargin:init()
    self:onDispatcherRegisterActions()
    if not self.ui.rolling then return end
    self.ui.menu:registerToMainMenu(self)
    self.ui.view:registerViewModule("automargin", self) -- see paintTo

    local doc_settings = self.ui.doc_settings
    if doc_settings:has(ENABLED) then
        self.enabled = doc_settings:isTrue(ENABLED)
    else
        self.enabled = G_reader_settings:isTrue(ENABLED)
    end

    -- With a saved measurement, the book's first render is already fitted.
    -- Older measurements have no ascender or descender: measure again.
    local saved = doc_settings:readSetting(SAVED)
    if saved and saved.d_off then
        self.measurement =
            { L = saved.L, a_off = saved.a_off, x_off = saved.x_off, b_off = saved.b_off, d_off = saved.d_off }
        self.measured_hash = saved.hash
    end

    self:wrapSetPageMargins()

    -- ReaderRolling runs updatePos after every re-render, and once between
    -- ReaderReady and the first paint. Fitting before it checks the rendering
    -- means the extra render a new measurement needs is handled with the first
    -- one: a single DocumentRerendered and a single paint.
    local rolling = self.ui.rolling
    local updatePos = rolling.updatePos
    rolling.updatePos = function(this, ...)
        self:remeasure()
        return updatePos(this, ...)
    end
end

-- Every margin change goes through the document's setPageMargins: the user's,
-- status bar changes, and other plugins' wrappers around ReaderTypeset.
-- Setting up KOReader's call cache again, as other plugins may, rebuilds the
-- document's methods from CreDocument, so wrap it again then.
function AutoMargin:wrapSetPageMargins()
    local doc = self.ui.document
    local setPageMargins, setupCallCache = doc.setPageMargins, doc.setupCallCache
    local function wrapped(this, left, top, right, bottom)
        self.margins = { top, bottom }
        setPageMargins(this, left, top, right, bottom)
        self.reserved = this:getPageMargins().top - top
        local t, b = self:pageMargins(top, bottom)
        self.applied = { t, b }
        return setPageMargins(this, left, t, right, b)
    end
    doc.setPageMargins = wrapped
    doc.setupCallCache = function(this, ...)
        setupCallCache(this, ...)
        if this.setPageMargins ~= wrapped then self:wrapSetPageMargins() end
    end
end

function AutoMargin:isEnabled()
    return self.enabled
end

function AutoMargin:onSaveSettings()
    if self.ui.rolling then self.ui.doc_settings:saveSetting(ENABLED, self.enabled) end
end

function AutoMargin:isActive()
    return self:isEnabled() and self.ui.view.view_mode == "page"
end

-- The top and bottom margins to give crengine, for the ones the user set.
function AutoMargin:pageMargins(top, bottom)
    self.layout = nil
    local m = self.measurement
    if not (self:isActive() and m) then return top, bottom end
    self.layout = Layout.compute(self:geometry(m, top, bottom))
    return self.layout.top, self.layout.bottom
end

-- The page geometry for a measurement and crengine margins, as automargin/layout takes it.
function AutoMargin:geometry(m, top, bottom)
    local footer = self.ui.view.footer
    return {
        screen_h = Screen:getHeight(),
        top = top,
        bottom = bottom,
        header = self.ui.document:getHeaderHeight() + self.reserved,
        bar = footer.reclaim_height and 0 or footer:getHeight(),
        line = m.L,
        top_off = G_reader_settings:isTrue(ASCENDER) and m.a_off or m.x_off,
        bottom_off = G_reader_settings:isTrue(DESCENDER) and m.d_off or m.b_off,
    }
end

-- Debug guides, drawn over the page as a ReaderView module. They use the
-- margins crengine has now, so with AutoMargin off they show the uncentered
-- text block.
function AutoMargin:paintTo(bb, x, y)
    local m = self.measurement
    if not (G_reader_settings:isTrue(GUIDES) and m and self.ui.view.view_mode == "page") then return end
    local margins = self.ui.document:getPageMargins()
    local g = self:geometry(m, margins.top - self.reserved, margins.bottom)
    local gaps = Layout.gaps(g)
    local w = Screen:getWidth()
    local function line(row, color)
        bb:paintRect(x, y + row, w, 1, color)
    end
    -- The page area: the margins given to crengine.
    line(g.header + g.top, Blitbuffer.COLOR_GRAY)
    line(g.screen_h - g.bottom - 1, Blitbuffer.COLOR_GRAY)
    -- Just outside the text block: above the first line, below the last one.
    line(gaps.top - 1, Blitbuffer.COLOR_BLACK)
    line(g.screen_h - gaps.bottom, Blitbuffer.COLOR_BLACK)
end

-- Measures the book if it was re-rendered since the last measurement, and
-- re-fits the page area if the result changed.
function AutoMargin:remeasure()
    local doc = self.ui.document
    if self.remeasuring or not (self:isActive() and self.margins) then return end
    if doc:getDocumentRenderingHash(false) == self.measured_hash then return end

    -- If the book can't be measured, the user's margins are used as they are.
    local m, err = Measure.sample(doc, Screen:getWidth(), Screen:getHeight())
    self.measurement, self.error = m, err
    local t, b = self:pageMargins(unpack(self.margins))
    if t ~= self.applied[1] or b ~= self.applied[2] then
        -- ReaderTypeset's UpdatePos runs updatePos, which comes back here.
        self.remeasuring = true
        self:reapply()
        self.remeasuring = false
        doc:getCurrentPos() -- render now, so updatePos sees the new rendering
    end
    self.measured_hash = doc:getDocumentRenderingHash(false)
    self:save()
end

function AutoMargin:save()
    local m = self.measurement
    if not m then return self.ui.doc_settings:delSetting(SAVED) end
    self.ui.doc_settings:saveSetting(SAVED, {
        hash = self.measured_hash,
        L = m.L,
        a_off = m.a_off,
        x_off = m.x_off,
        b_off = m.b_off,
        d_off = m.d_off,
    })
end

-- Hands the user's margins to crengine again, through ReaderTypeset, whose
-- UpdatePos re-renders if needed and measures (see init). Other plugins'
-- wrappers around ReaderTypeset need it to go through there.
function AutoMargin:reapply()
    if not self.margins then return end -- not a crengine document, or not set up yet
    self.ui.typeset:onSetPageMargins(self.ui.typeset.unscaled_margins)
    -- Highlight boxes are cached in screen coordinates. A re-render clears
    -- them, but a change that keeps top + bottom doesn't re-render.
    self.ui.view:resetHighlightBoxesCache()
end

function AutoMargin:onChangeViewMode()
    self:reapply()
end

function AutoMargin:onToggleAutoMargin()
    if not self.ui.rolling then return end
    self.enabled = not self.enabled
    -- Measure the page as it is now, so that after layout changes made while
    -- it was off, fitting takes a single render.
    if self.enabled then self:remeasure() end
    self:reapply()
    Notification:notify(self:isEnabled() and _("AutoMargin on") or _("AutoMargin off"))
    return true
end

function AutoMargin:onDispatcherRegisterActions()
    Dispatcher:registerAction("automargin_toggle", {
        category = "none",
        event = "ToggleAutoMargin",
        title = _("Toggle AutoMargin"),
        rolling = true,
    })
end

function AutoMargin:addToMainMenu(menu_items)
    menu_items.automargin = {
        text = _("AutoMargin"),
        sorting_hint = "typeset",
        sub_item_table = {
            {
                text_func = function()
                    return G_reader_settings:isTrue(ENABLED) and _("Enabled") .. "   ★" or _("Enabled")
                end,
                checked_func = function()
                    return self:isEnabled()
                end,
                callback = function()
                    self:onToggleAutoMargin()
                end,
                hold_callback = function(touchmenu_instance)
                    self:showDefaultDialog(touchmenu_instance)
                end,
                separator = true,
            },
            {
                text_func = function()
                    return G_reader_settings:isTrue(ASCENDER) and _("Top edge: ascender") or _("Top edge: midline")
                end,
                help_text = _(
                    "Where the text starts, for the gap above it: the midline, at the top of letters such as x, or the ascender line, at the top of letters such as h and l."
                ),
                sub_item_table = {
                    self:edgeItem(_("Midline"), ASCENDER, false),
                    self:edgeItem(_("Ascender"), ASCENDER, true),
                },
            },
            {
                text_func = function()
                    return G_reader_settings:isTrue(DESCENDER) and _("Bottom edge: descender")
                        or _("Bottom edge: baseline")
                end,
                help_text = _(
                    "Where the text ends, for the gap below it: the baseline, at the bottom of letters such as x, or the descender line, at the bottom of letters such as g and p."
                ),
                sub_item_table = {
                    self:edgeItem(_("Baseline"), DESCENDER, false),
                    self:edgeItem(_("Descender"), DESCENDER, true),
                },
                separator = true,
            },
            {
                text = _("Debug"),
                sub_item_table = {
                    {
                        text = _("Show measurements"),
                        keep_menu_open = true,
                        callback = function()
                            UIManager:show(InfoMessage:new { text = self:describe(), show_icon = false })
                        end,
                    },
                    {
                        text = _("Show guide lines"),
                        help_text = _(
                            "Black lines: just outside the text block on a full page of text, above the first line's top edge and below the last line's bottom edge. The gap from the top of the screen to the top one should equal the gap from the bottom one to the bottom of the screen.\n\nGray lines: the text area, inside the margins."
                        ),
                        checked_func = function()
                            return G_reader_settings:isTrue(GUIDES)
                        end,
                        callback = function()
                            G_reader_settings:flipNilOrFalse(GUIDES)
                            UIManager:setDirty(self.ui.dialog, "ui")
                        end,
                    },
                },
            },
            {
                text = _("Check for updates"),
                keep_menu_open = true,
                callback = function()
                    require("automargin/updateui").check()
                end,
            },
        },
    }
end

-- A choice for an edge of the text block: the ascender or descender line
-- (value true), or the midline or baseline.
function AutoMargin:edgeItem(text, setting, value)
    return {
        text = text,
        radio = true,
        checked_func = function()
            return G_reader_settings:isTrue(setting) == value
        end,
        callback = function()
            G_reader_settings:saveSetting(setting, value)
            self:reapply()
        end,
    }
end

-- Long-press on "Enabled", as for KOReader's own per-book settings.
function AutoMargin:showDefaultDialog(touchmenu_instance)
    local enabled = G_reader_settings:isTrue(ENABLED)
    local function setDefault(value)
        G_reader_settings:saveSetting(ENABLED, value)
        if touchmenu_instance then touchmenu_instance:updateItems() end
    end
    UIManager:show(MultiConfirmBox:new {
        text = enabled
                and _(
                    "The default (★) for newly opened books is to center the text with AutoMargin.\n\nWould you like to change it?"
                )
            or _(
                "The default (★) for newly opened books is not to center the text with AutoMargin.\n\nWould you like to change it?"
            ),
        choice1_text_func = function()
            return enabled and _("Disable") or _("Disable") .. " (★)"
        end,
        choice1_callback = function()
            setDefault(false)
        end,
        choice2_text_func = function()
            return enabled and _("Enable") .. " (★)" or _("Enable")
        end,
        choice2_callback = function()
            setDefault(true)
        end,
    })
end

function AutoMargin:describe()
    if not self:isEnabled() then return _("AutoMargin is off for this book.") end
    if self.ui.view.view_mode ~= "page" then return _("AutoMargin only works in page mode.") end
    local m, l = self.measurement, self.layout
    if not (m and l) then
        return self.error and T(_("This book couldn't be measured: %1."), self.error)
            or _("This book hasn't been measured yet.")
    end
    local lines = {
        T(_("Line height: %1 px, %2 lines a page"), m.L, l.lines),
        T(_("Ascender to descender: rows %1–%2"), m.a_off, m.d_off - 1),
        T(_("x-height to baseline: rows %1–%2"), m.x_off, m.b_off - 1),
        T(_("Gap above: %1 → %2 px"), l.before.top, l.after.top),
        T(_("Gap below: %1 → %2 px"), l.before.bottom, l.after.bottom),
    }
    -- A measurement saved with the book has no timing.
    if m.ms then table.insert(lines, T(_("Measured in %1 ms"), math.floor(m.ms + 0.5))) end
    if l.clamped then
        table.insert(lines, _("The status bar limits how far the text can move, so it's only partly centered."))
    end
    return table.concat(lines, "\n")
end

return AutoMargin
