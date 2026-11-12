#!/bin/bash
# Render the README's pictures into docs/images from the app's own artwork.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
# The widget file has its own @main; drop it so this tool can provide one.
python3 - <<'PY'
from pathlib import Path
source = Path('Sources/Widget/ClockWidget.swift').read_text()
Path('build/WidgetForPreview.swift').write_text(source.split('@main')[0])
PY
swiftc -parse-as-library -module-cache-path build/module-cache Sources/Shared/*.swift build/WidgetForPreview.swift Scripts/make-readme-images.swift -o build/MakeReadmeImages
build/MakeReadmeImages
