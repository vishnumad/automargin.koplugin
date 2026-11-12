# AutoMargin for KOReader

Keeps the text vertically centered on the page, whatever the font, font size or
line spacing. Your margin settings stay as they are.

## Install

Download `automargin.koplugin.zip` from the
[latest release](https://github.com/vishnumad/automargin.koplugin/releases/latest),
unzip it into KOReader's `plugins/` folder and restart KOReader. Tested on
v2026.07.1.

## Updating

Open a book and choose **Typesetting › AutoMargin › Check for updates**. If
you installed v0.1.1 or earlier, update by hand once, as above.

## Usage

**Typesetting › AutoMargin › Enabled** turns it on for the current book.
Long-press it to set the default for new books.

**Top edge** and **Bottom edge** set where the text starts and ends when
measuring the gaps above and below it. By default, that's the midline (the
top of letters like x) and the baseline. Choose **Ascender** or **Descender**
to measure from the top of letters like h and l, or the bottom of letters
like g and p. These apply to all books.

Note:
- In EPUBs with **Settings › Document › Enable partial renderings** on (the default), font changes are centered right away. Otherwise, changing font settings takes noticeably longer with the plugin enabled, as the book is rendered twice. If you need to make many layout changes, temporarily turn AutoMargin off, change your desired settings, then turn it back on to re-center.
- Only the total of your top and bottom margins matters. Turn on **Sync T/B
  Margins** to change both at once.

## Limitations

- Only works for reflowable documents (EPUB, FB2, HTML) in page mode.
- Pages with space between paragraphs can't be centered exactly. It's recommended to enable **Typesetting › Style tweaks › Paragraphs › Spacing between paragraphs › No spacing between paragraphs**.
- Scripts other than Latin and Chinese are untested.

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
