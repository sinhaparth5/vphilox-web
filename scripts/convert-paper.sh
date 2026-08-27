#!/usr/bin/env bash
# Regenerate the paper MDX from docs/vphilox.tex.
#
#   ./scripts/convert-paper.sh
#
# Output goes to src/content/paper/vphilox.mdx. Hand edits to that file are
# overwritten -- put durable changes in the .tex, the sed pre-pass, or the
# Lua filter.
set -euo pipefail

cd "$(dirname "$0")/.."

TEX=docs/vphilox.tex
OUT=src/content/paper/vphilox.mdx
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# \bibitem keys, in citation-list order; pandoc drops them, the filter needs them.
BIBKEYS=$(grep -o '\\bibitem{[^}]*}' "$TEX" | sed 's/\\bibitem{//;s/}//' | paste -sd,)

sed -f scripts/pre-pass.sed "$TEX" > "$TMP/pre.tex"

mkdir -p "$(dirname "$OUT")"

pandoc "$TMP/pre.tex" \
  -f latex \
  -t gfm+tex_math_dollars-raw_html \
  --wrap=preserve \
  --lua-filter=scripts/tex-to-mdx.lua \
  -M "bibkeys=$BIBKEYS" \
  -o "$TMP/body.md"

{
  echo '---'
  echo "title: 'Portable, Seekable Random Streams for Parallel CPU Simulation'"
  echo "author: 'Parth Sinha'"
  echo '---'
  echo
  cat "$TMP/body.md"
} > "$OUT"

echo "wrote $OUT ($(wc -l < "$OUT") lines)"
