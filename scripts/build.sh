#!/bin/zsh
# Builds "Halo Helper.app" (the Mac half of Halo) into build/ with xcodebuild.
#
# Signing: your Apple Development certificate when there is one (so macOS remembers Local Network,
# Accessibility and Automation across rebuilds), otherwise ad hoc. HALO_SIGN=developer-id signs with
# your Developer ID Application certificate and a secure timestamp instead, which is what
# notarization (and so a release) needs.
set -euo pipefail
cd "$(dirname "$0")/.."

# Regenerate the project if XcodeGen is around, so it matches project.yml.
command -v xcodegen >/dev/null && xcodegen generate --quiet

TEAM=$(grep -E '^\s*DEVELOPMENT_TEAM:' project.yml | head -1 | awk '{print $2}')
SIGNING=()
# Read into a variable rather than `| grep -q`, which can trip pipefail with SIGPIPE.
IDENTITIES=$(security find-identity -v -p codesigning)
if [[ "${HALO_SIGN:-}" == "developer-id" ]]; then
  [[ "$IDENTITIES" == *'"Developer ID Application'* ]] \
    || { echo "No Developer ID Application certificate in your keychain."; exit 1; }
  SIGNING=(CODE_SIGN_IDENTITY="Developer ID Application" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="$TEAM"
    OTHER_CODE_SIGN_FLAGS=--timestamp CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)  # no get-task-allow: Apple refuses to notarize it
elif [[ "$IDENTITIES" != *'"Apple Development'* ]]; then
  echo "No Apple Development certificate found; signing ad hoc. (Bonjour needs a real signature: pairing won't work.)"
  SIGNING=(CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=)
fi

APP="build/DerivedData/Build/Products/Release/Halo Helper.app"
# A failed build must never leave an older app behind to be picked up below.
rm -rf "$APP"
mkdir -p build
if ! xcodebuild -project Halo.xcodeproj -scheme HaloMac -configuration Release \
  -derivedDataPath build/DerivedData -destination 'platform=macOS' \
  -skipMacroValidation -skipPackagePluginValidation \
  "${SIGNING[@]}" build > build/xcodebuild.log 2>&1; then
  grep -E "error:" build/xcodebuild.log | sort -u | head -20
  echo "Build failed. The whole log is in build/xcodebuild.log"
  exit 1
fi
grep -E "warning: .*Halo/(Apps|Packages)/" build/xcodebuild.log | sort -u || true

[[ -d "$APP" ]] || { echo "Build failed"; exit 1; }

# Sparkle's helpers come signed ad hoc, and Xcode only re-signs the framework around them; the
# embedded halo-hook tool needs the same treatment. Notarization, and Sparkle's own check of an
# update, need every piece signed by us.
if [[ "${HALO_SIGN:-}" == "developer-id" ]]; then
  SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
  sign() { codesign --force --sign "Developer ID Application" --options runtime --timestamp "$@"; }
  sign "$SPARKLE/XPCServices/Installer.xpc"
  sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
  sign "$SPARKLE/Autoupdate"
  sign "$SPARKLE/Updater.app"
  sign "$APP/Contents/Frameworks/Sparkle.framework"
  sign "$APP/Contents/MacOS/halo-hook"
  # And the app again, as its signature covers everything inside it.
  sign --preserve-metadata=entitlements,requirements,flags "$APP"
  codesign --verify --deep --strict "$APP" || { echo "The app's signature doesn't check out."; exit 1; }
fi
rm -rf "build/Halo Helper.app"
ditto "$APP" "build/Halo Helper.app"
echo "Built build/Halo Helper.app"
echo "Run it with: open \"build/Halo Helper.app\" (or move it to Applications first: Bonjour needs a standard location)"
