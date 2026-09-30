#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."
source_icon="${PWD}/spotmenu-icon.png"
iconset="${PWD}/Resources/SpotMenu.iconset"
mkdir -p "${iconset}"

# macOS requires square images at both standard and Retina resolutions.
# sips preserves the source PNG's transparent corners when resizing.
for size in 16 32 128 256 512; do
  sips -z "${size}" "${size}" "${source_icon}" \
    --out "${iconset}/icon_${size}x${size}.png" >/dev/null
  retina_size=$((size * 2))
  sips -z "${retina_size}" "${retina_size}" "${source_icon}" \
    --out "${iconset}/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil --convert icns "${iconset}" --output "${PWD}/Resources/SpotMenu.icns"
echo "Built Resources/SpotMenu.iconset and Resources/SpotMenu.icns"
