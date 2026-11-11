#!/bin/bash
# Build "build/Type AB1.app" with its widget extension, ad-hoc signed for this Mac.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
APP="$PWD/build/Type AB1.app"
EXT="$APP/Contents/PlugIns/TypeAB1Widget.appex"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$EXT/Contents/MacOS"
cp Config/App-Info.plist "$APP/Contents/Info.plist"
cp Config/Widget-Info.plist "$EXT/Contents/Info.plist"
# A fresh build number every time. macOS keys cached widget timelines to the
# extension's version; reusing one can leave an old timeline frozen on screen.
BUILD="$(date +%Y%m%d.%H%M)"
for PLIST in "$APP/Contents/Info.plist" "$EXT/Contents/Info.plist"; do
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"
done
cp Resources/Clock.icns "$APP/Contents/Resources/Clock.icns"
cp art/Clock-Live-Preview.html "$APP/Contents/Resources/Clock-Live-Preview.html"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 -sdk "$SDK" -module-cache-path build/module-cache Sources/Shared/*.swift Sources/App/*.swift -o "$APP/Contents/MacOS/TypeAB1"
swiftc -parse-as-library -application-extension -Xlinker -e -Xlinker _NSExtensionMain -O -target arm64-apple-macosx14.0 -sdk "$SDK" -module-cache-path build/module-cache Sources/Shared/*.swift Sources/Widget/*.swift -o "$EXT/Contents/MacOS/TypeAB1Widget"
codesign --force --sign - --entitlements Config/Widget.entitlements "$EXT"
codesign --force --sign - "$APP"
printf 'Built %s (build %s)\n' "$APP" "$BUILD"
