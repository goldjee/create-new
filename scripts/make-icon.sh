#!/bin/bash
# Regenerates Resources/AppIcon.icns from Resources/AppIcon.svg. Run once and commit the output.
set -euo pipefail
cd "$(dirname "$0")/.."
SET="$(mktemp -d)/AppIcon.iconset"
mkdir "$SET"
for size in 16 32 128 256 512; do
  sips -s format png -z $size $size Resources/AppIcon.svg --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -s format png -z $((size * 2)) $((size * 2)) Resources/AppIcon.svg --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"
