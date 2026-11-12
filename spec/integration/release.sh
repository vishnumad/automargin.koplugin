#!/usr/bin/env bash
# Sets up a KOReader release for the integration tests, and prints the
# directory to pass as KOREADER_DIR:
#   spec/integration/release.sh <dir> [tag]    (default: the latest release)
set -euo pipefail
dir="${1:?usage: $0 <dir> [tag]}"
repo=https://github.com/koreader/koreader
tag="${2:-$(curl -fsSLI -o /dev/null -w '%{url_effective}' "$repo/releases/latest")}"
tag="${tag##*/}"

mkdir -p "$dir"
curl -fsSL "$repo/releases/download/$tag/koreader-linux-x86_64-$tag.tar.xz" | tar -xJ -C "$dir"
ko="$(cd "$dir/lib/koreader" && pwd)"
unit="$ko/spec/front/unit"
mkdir -p "$unit/data"
curl -fsSL -o "$unit/commonrequire.lua" "https://raw.githubusercontent.com/koreader/koreader/$tag/spec/unit/commonrequire.lua"
for book in juliet.epub leaves.epub; do
    curl -fsSL -o "$unit/data/$book" "https://raw.githubusercontent.com/koreader/test-data/master/$book"
done
echo "$ko"
