#!/bin/zsh
# Retakes the README screenshots from the iPad app's demo, with real pictures from this Mac:
# its icons, the wallpaper given (Sonoma by default) and whatever Music has loaded.
#
#   scripts/make-screenshots.sh [wallpaper]
#
# Needs a booted iPad Pro 13-inch simulator. Then run make-banner.sh to redraw the banner.
set -euo pipefail
cd "$(dirname "$0")/.."

WALLPAPER=${1:-"/System/Library/Desktop Pictures/Sonoma.heic"}
BUNDLE=dk.patrickjak.halo.pad
DERIVED=build/screenshots-dd
OUT=docs/images

xcodegen generate >/dev/null
xcodebuild -project Halo.xcodeproj -scheme HaloPad -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' \
  -derivedDataPath "$DERIVED" build -quiet
xcrun simctl install booted "$DERIVED/Build/Products/Debug-iphonesimulator/Halo.app"

# Real icons in the default style, whatever this Mac's icon style is set to.
swift scripts/demo/DemoAssets.swift build/demo-assets "$WALLPAPER" -AppleIconAppearanceTheme RegularLight
CONTAINER=$(xcrun simctl get_app_container booted $BUNDLE data)
rm -rf "$CONTAINER/Documents/DemoAssets"
mkdir -p "$CONTAINER/Documents"
cp -R build/demo-assets "$CONTAINER/Documents/DemoAssets"

# name, then the launch arguments. The frame is the 13-inch iPad in landscape.
shots=(
  "hello|-HaloDemo 0 -HaloDemoEmpty"
  "home|-HaloDemo 0"
  "pulse|-HaloDemo 1"
  "agents|-HaloDemo 2"
  "desk|-HaloDemo 3"
  "editing|-HaloDemo 1 -HaloDemoEditing"
)
for shot in $shots; do
  name=${shot%%|*}
  xcrun simctl launch --terminate-running-process booted $BUNDLE ${=${shot#*|}} -HaloFrame 1366x1024 >/dev/null
  # Long enough for the hello to finish writing and the chrome to settle.
  sleep 7
  xcrun simctl io booted screenshot --type=png build/shot.png >/dev/null 2>&1
  sips -r 270 build/shot.png --out build/shot.png >/dev/null
  sips -z 1200 1600 build/shot.png --out build/shot.png >/dev/null
  sips -s format jpeg -s formatOptions 86 build/shot.png --out "$OUT/$name.jpg" >/dev/null
  echo "Took $OUT/$name.jpg"
done
