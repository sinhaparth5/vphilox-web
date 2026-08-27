#!/usr/bin/env bash
# Regenerate the social-card image and the touch icon.
#
#   ./scripts/gen-og-image.sh
#
# Writes public/og.png (1200x630, the og:image / twitter:image) and
# public/apple-touch-icon.png (180x180, from public/favicon.svg).
#
# The page fonts are self-hosted as woff2, which ImageMagick cannot read, so the
# upstream TTFs are fetched into a temp dir for the run. Nothing is cached in the
# repo: this is a once-in-a-while step and the PNGs are committed.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v magick >/dev/null || { echo "needs ImageMagick (magick)" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

GF=https://raw.githubusercontent.com/google/fonts/main/ofl
curl -sfL -o "$TMP/serif.ttf" "$GF/sourceserif4/SourceSerif4%5Bopsz,wght%5D.ttf"
curl -sfL -o "$TMP/sans.ttf"  "$GF/sourcesans3/SourceSans3%5Bwght%5D.ttf"

BG='#fbfbf9'
INK='#16161a'
SOFT='#52525c'
FAINT='#7c7c86'
ACCENT='#a3341f'

# Same paper, same ink, same rule as the site: the card is the page, cropped.
magick -size 1200x630 "xc:$BG" \
  -fill "$INK" -draw "roundrectangle 80,72 152,144 15,15" \
  -font "$TMP/serif.ttf" -pointsize 58 -fill "$BG" \
  -draw "text 96,128 'φ'" \
  -font "$TMP/sans.ttf" -pointsize 30 -fill "$FAINT" \
  -draw "text 180,120 'vphilox'" \
  -font "$TMP/serif.ttf" -pointsize 68 -fill "$INK" \
  -draw "text 80,268 'Portable, seekable random'" \
  -draw "text 80,352 'streams for parallel CPU'" \
  -draw "text 80,436 'simulation'" \
  -fill "$ACCENT" -draw "rectangle 80,486 152,490" \
  -font "$TMP/sans.ttf" -pointsize 27 -fill "$SOFT" \
  -draw "text 80,542 'Parth Sinha · header-only C++20 · Philox4x32-10'" \
  -font "$TMP/sans.ttf" -pointsize 24 -fill "$FAINT" \
  -draw "text 80,584 'sinhaparth5.github.io/vphilox-web'" \
  public/og.png

# iOS applies its own corner mask, so the tile is flattened to a full-bleed
# square -- transparent corners composite to whatever is behind them.
magick -background none public/favicon.svg -resize 180x180 \
  -background "$INK" -alpha remove -alpha off public/apple-touch-icon.png

echo "wrote public/og.png ($(identify -format '%wx%h' public/og.png))"
echo "wrote public/apple-touch-icon.png ($(identify -format '%wx%h' public/apple-touch-icon.png))"
