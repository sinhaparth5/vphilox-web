#!/usr/bin/env bash
# Regenerate the paper MDX from the LaTeX source.
#
#   ./scripts/convert-paper.sh [path/to/vphilox.tex]
#
# The .tex lives in the sibling vphilox repo, not here, so this is a local step:
# CI builds the committed MDX as-is. Hand edits to that file are overwritten --
# put durable changes in the .tex, the sed pre-pass, or the Lua filter.
set -euo pipefail

# Resolve the argument against the caller's directory, before we move.
TEX=$(realpath "${1:-$(dirname "$0")/../../vphilox/paper/vphilox.tex}")

cd "$(dirname "$0")/.."
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
