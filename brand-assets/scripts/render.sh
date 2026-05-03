#!/usr/bin/env bash
# Re-render all PNG exports from the SVG sources.
# Requires: librsvg (`brew install librsvg`).
#
# Run from repo root:  brand-assets/scripts/render.sh

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

mkdir -p exports

# --- Marks: line + fill, in three brand tints, at five sizes -----------------

# Per-variant working SVGs (currentColor swapped for a literal hex)
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for variant in line fill; do
  for tint_name in ink paper coral; do
    case "$tint_name" in
      ink)   hex="#0E0F12" ;;
      paper) hex="#F8F4EC" ;;
      coral) hex="#E86B3B" ;;
    esac
    sed "s|currentColor|$hex|g" "marks/parakeet-${variant}.svg" \
      > "$WORK/parakeet-${variant}-${tint_name}.svg"
    for size in 256 512 1024 2048 4096; do
      rsvg-convert -w "$size" -h "$size" \
        "$WORK/parakeet-${variant}-${tint_name}.svg" \
        -o "exports/parakeet-${variant}-${tint_name}-${size}.png"
    done
  done
done

# --- Compositions ------------------------------------------------------------

rsvg-convert -w 1024 -h 1024 compositions/single-portrait.svg -o exports/single-portrait.png
rsvg-convert -w 1500 -h 2000 compositions/warhol-3x4.svg      -o exports/warhol-3x4.png
rsvg-convert -w 1600 -h 900  compositions/wordmark-lockup.svg -o exports/wordmark-lockup.png
rsvg-convert -w 1200 -h 630  compositions/og-image.svg        -o exports/og-image.png
rsvg-convert -w 1080 -h 1080 compositions/social-square.svg   -o exports/social-square.png
rsvg-convert -w 1080 -h 1920 compositions/social-story.svg    -o exports/social-story.png

# --- Palette swatch sheet ----------------------------------------------------

rsvg-convert -w 1600 -h 900 palette/palette.svg -o palette/palette.png

echo "✓ rendered $(ls exports/ | wc -l | tr -d ' ') files into exports/"
