#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
APP="$PWD/build/Type AB1.app"
EXT="$APP/Contents/PlugIns/TypeAB1Widget.appex"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/Artwork" "$EXT/Contents/MacOS" "$EXT/Contents/Resources/Artwork"
for NAME in ClockBody ButtonWell ButtonCap HourHand MinuteHand SecondHand CentreHub AlarmPointer; do
  cp "Resources/Artwork/$NAME.png" "$APP/Contents/Resources/Artwork/$NAME.png"
  cp "$APP/Contents/Resources/Artwork/$NAME.png" "$EXT/Contents/Resources/Artwork/$NAME.png"
done
cp Config/App-Info.plist "$APP/Contents/Info.plist"
cp Config/Widget-Info.plist "$EXT/Contents/Info.plist"
cp Resources/Clock.icns "$APP/Contents/Resources/Clock.icns"
cp art/Clock-Live-Preview.html "$APP/Contents/Resources/Clock-Live-Preview.html"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
swiftc -parse-as-library -O -target arm64-apple-macosx14.0 -sdk "$SDK" -module-cache-path build/module-cache Sources/Shared/*.swift Sources/App/*.swift -o "$APP/Contents/MacOS/TypeAB1"
swiftc -parse-as-library -application-extension -Xlinker -e -Xlinker _NSExtensionMain -O -target arm64-apple-macosx14.0 -sdk "$SDK" -module-cache-path build/module-cache Sources/Shared/*.swift Sources/Widget/*.swift -o "$EXT/Contents/MacOS/TypeAB1Widget"
codesign --force --sign - --entitlements Config/Widget.entitlements "$EXT"
codesign --force --sign - "$APP"
printf 'Built %s\n' "$APP"
