#!/bin/bash
# Build, then install to /Applications as the only registered copy, so macOS loads
# one widget extension and its current timeline. Replaces /Applications/Type AB1.app.
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build.sh
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT="$PWD/build/Type AB1.app"
TARGET="/Applications/Type AB1.app"
osascript -e 'tell application id "com.duivesteyn.typeab1" to quit' >/dev/null 2>&1 || true
sleep 1
# Forget the copy in build/ so its widget does not compete with the installed one.
pluginkit -r "$BUILT/Contents/PlugIns/TypeAB1Widget.appex" >/dev/null 2>&1 || true
"$LSREGISTER" -u "$BUILT" >/dev/null 2>&1 || true
rm -rf "$TARGET"
ditto "$BUILT" "$TARGET"
"$LSREGISTER" -f "$TARGET"
pluginkit -a "$TARGET/Contents/PlugIns/TypeAB1Widget.appex"
# Stop any widget process still running the old build; macOS starts the new one on demand.
pkill -f "^$TARGET/Contents/PlugIns/TypeAB1Widget\.appex/Contents/MacOS/TypeAB1Widget" 2>/dev/null || true
open "$TARGET"
echo "Installed $TARGET. The app asks macOS to refresh the widget on launch."
