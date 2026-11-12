#!/bin/bash
# Regenerate Resources/icon-*.png and Resources/Clock.icns from the clock vectors.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
swiftc -parse-as-library -module-cache-path build/module-cache Sources/Shared/ClockDesign.swift Sources/Shared/ClockRaster.swift Sources/Shared/ClockLayout.swift Sources/Shared/ClockTime.swift Sources/Shared/ClockStyle.swift Sources/Shared/ClockFaces.swift Sources/Shared/ClockFamilies.swift Scripts/make-icon.swift -o build/MakeIcon
build/MakeIcon
iconutil -c icns Resources/Clock.iconset -o Resources/Clock.icns
echo "Wrote Resources/Clock.icns"
