# Validation

- All SVG documents parse.
- All 50 PNG files decode.
- Twelve Xcode image sets have valid file references, RGBA formats and 512/1024 px dimensions.
- All nine button positions are pixel-identical outside the button region.
- Assembled vector hands and both button states were visually reviewed.
- The offline preview script was executed with DOM stubs: time-zone change, known Adelaide/UTC angles, 36 px button travel and accessibility state passed.

The browser reference has not been tested in an actual browser here; its rendering was checked through SVG rendering. No native macOS build or alarm scheduling was tested. The HTML is an artwork preview, not an alarm service.
