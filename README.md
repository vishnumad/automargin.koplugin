# AutoMargin for KOReader

KOReader fits as many whole lines on a page as it can and leaves the leftover
space at the bottom. AutoMargin keeps the text vertically centered instead, or
aligned to the top or bottom of the page, whatever the font, font size or line
spacing. Your margin settings stay as they are.

Works with reflowable books (EPUB, FB2, HTML) in page mode. Tested on KOReader
v2026.07.1 with Latin and Chinese text.

## Install

1. Download `automargin.koplugin.zip` from the
   [latest release](https://github.com/vishnumad/automargin.koplugin/releases/latest).
2. Unzip it into KOReader's `plugins/` folder.
3. Restart KOReader.

To update later, open a book and choose **Typesetting › AutoMargin › Check for
updates**.

## Getting started

Open a book and turn on **Typesetting › AutoMargin › Enabled**. This applies to
the current book; long-press it to make it the default for new books.

Space between paragraphs keeps the text from being centered exactly, so for the
best results also turn on **Typesetting › Style tweaks › Paragraphs › Spacing
between paragraphs › No spacing between paragraphs**.

## Settings

These are under **Typesetting › AutoMargin**. Long-press **Enabled**, **Shift**
or an **Alignment** choice to set the default for new books.

- **Alignment** centers the text, or aligns it to the top or bottom of the page
  with the gap there matching the gap at the sides.
- **Shift** moves the text down, or up with a negative value, in the same units
  as KOReader's margins. Only the total of your top and bottom margins matters,
  so use Shift rather than the margins to move the text.
- **Top edge** and **Bottom edge** set what counts as the top and bottom of the
  text: by default, the top of letters like x and the baseline. Choose
  **Ascender** or **Descender** to use the top of letters like h, or the bottom
  of letters like g. These apply to all books.

Changing font settings can take a little longer with AutoMargin on. If you're
making many changes, turn it off first and back on when you're done.
**Toggle AutoMargin**, **Enable AutoMargin** and **Disable AutoMargin** can be
assigned to a gesture or added to a profile to make this quicker.

## Development

Install the tools with `mise install`.

```sh
make check      # lint, format check and unit tests
make fmt
make integration KOREADER_DIR=<koreader>/koreader-emulator-x86_64-linux-gnu-debug/koreader
```

To test against a KOReader release (the latest by default):

```sh
make integration KOREADER_DIR=$(spec/integration/release.sh <dir> [tag])
```

### Publishing a new release

```sh
make release VERSION=x.y.z
git push origin master vx.y.z
```

Pushing the tag runs the checks, builds `automargin.koplugin.zip` and publishes
the GitHub release. A tag with a suffix, like `v1.0.0-beta.1`, is published as
a prerelease.
