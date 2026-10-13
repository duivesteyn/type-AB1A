#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ArtworkPreview.app/Contents/MacOS build/ArtworkPreview.app/Contents/Resources
cp -R Resources/Artwork build/ArtworkPreview.app/Contents/Resources/
python3 - <<'PY'
from pathlib import Path
Path('build/WidgetForPreview.swift').write_text(Path('Sources/Widget/ClockWidget.swift').read_text().split('@main')[0])
PY
swiftc -parse-as-library -module-cache-path build/module-cache Sources/Shared/*.swift build/WidgetForPreview.swift Scripts/render-previews.swift -o build/ArtworkPreview.app/Contents/MacOS/ArtworkPreview
build/ArtworkPreview.app/Contents/MacOS/ArtworkPreview
