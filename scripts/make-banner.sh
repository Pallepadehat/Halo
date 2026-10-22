#!/bin/zsh
# Draws the README banner and GitHub's social preview from the home screenshot and the icon.
# Refresh the screenshots first (see "Screenshots" in the README) if the design changed.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f docs/images/home.jpg && -f docs/images/icon.png ]] || { echo "Needs docs/images/home.jpg and icon.png first."; exit 1; }
mkdir -p build
for spec in "2560 1280 banner" "1280 640 social-preview"; do
  set -- ${=spec}
  swift scripts/banner/Banner.swift $1 $2 docs/images/home.jpg docs/images/icon.png build/$3.png
  sips -s format jpeg -s formatOptions 86 build/$3.png --out docs/images/$3.jpg >/dev/null
done
echo "Drew docs/images/banner.jpg and docs/images/social-preview.jpg"
