#!/bin/zsh
# Redraws the app icons from scripts/icon/AppIcon.swift and fills both asset catalogs, plus the
# README's icon in docs/images.
set -euo pipefail
cd "$(dirname "$0")/.."

PAD=Apps/HaloPad/Resources/Assets.xcassets/AppIcon.appiconset
MAC=Apps/HaloMac/Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p "$PAD" "$MAC" docs/images

# Compiled, not interpreted: the conic gradient is computed per pixel.
mkdir -p build
swiftc -O scripts/icon/AppIcon.swift -o build/AppIcon
build/AppIcon ios "$PAD/AppIcon.png"
build/AppIcon mac build/AppIcon-mac.png

for size in 16 32 64 128 256 512 1024; do
  sips -z $size $size build/AppIcon-mac.png --out "$MAC/icon_$size.png" >/dev/null
done
sips -z 280 280 build/AppIcon-mac.png --out docs/images/icon.png >/dev/null

cat > "$PAD/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "AppIcon.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

cat > "$MAC/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_64.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_1024.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

for catalog in Apps/HaloPad/Resources/Assets.xcassets Apps/HaloMac/Resources/Assets.xcassets; do
  echo '{ "info" : { "author" : "xcode", "version" : 1 } }' > "$catalog/Contents.json"
done
echo "Icons drawn: $PAD, $MAC and docs/images/icon.png"
