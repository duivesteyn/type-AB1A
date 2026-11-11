#!/bin/bash
# Render preview PNGs of the desktop clock and the widget into build/Previews.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
# The widget file has its own @main; drop it so the preview tool can provide one.
python3 - <<'PY'
from pathlib import Path
source = Path('Sources/Widget/ClockWidget.swift').read_text()
Path('build/WidgetForPreview.swift').write_text(source.split('@main')[0])
PY
swiftc -parse-as-library -module-cache-path build/module-cache Sources/Shared/*.swift build/WidgetForPreview.swift Scripts/render-previews.swift -o build/RenderPreviews
build/RenderPreviews
