# AutoMargin for KOReader

Keeps the text vertically centered on the page, whatever the font, font size or
line spacing. Your margin settings stay as they are.

## Install

Copy the `automargin.koplugin` folder into KOReader's `plugins/` folder and
restart KOReader. Tested on v2026.07.1.

## Usage

**Typesetting › AutoMargin › Enabled** turns it on for the current book.
Long-press it to set the default for new books.

**Top edge** and **Bottom edge** set where the text starts and ends when
measuring the gaps above and below it. By default, that's the midline (the
top of letters like x) and the baseline. Choose **Ascender** or **Descender**
to measure from the top of letters like h and l, or the bottom of letters
like g and p. These apply to all books.

Note:
- Changing font settings will take noticeably longer with the plugin enabled, as the book is rendered twice. If you need to make layout changes, temporarily turn AutoMargin off, change your desired settings, then turn it back on to re-center.
- Only the total of your top and bottom margins matters. Turn on **Sync T/B
  Margins** to change both at once.

## Limitations

- Only works for reflowable documents (EPUB, FB2, HTML) in page mode.
- Pages with space between paragraphs can't be centered exactly. It's recommended to enable **Typesetting › Style tweaks › Paragraphs › Spacing between paragraphs › No spacing between paragraphs**.
- Non-Latin scripts are untested.

## Development

Install the tools with `mise install`.

```sh
make check      # lint, format check and unit tests
make fmt
make integration KOREADER_DIR=<koreader>/koreader-emulator-x86_64-linux-gnu-debug/koreader
```

To test against a release, extract `koreader-linux-x86_64-<version>.tar.xz`,
copy KOReader's `spec/unit/commonrequire.lua` (same tag) into its
`lib/koreader/spec/front/unit/` and the test books `juliet.epub` and
`leaves.epub` into `data/` there, then use `KOREADER_DIR=<release>/lib/koreader`.
