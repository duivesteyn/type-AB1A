import SwiftUI
import AppKit
import WidgetKit

/// Renders the desktop clock (Core Graphics) and the widget (SwiftUI) to build/Previews.
@main struct PreviewRenderer {
    @MainActor static func main() throws {
        let folder = URL(fileURLWithPath: "build/Previews", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let date = ISO8601DateFormatter().date(from: "2026-10-13T23:40:37Z")!
        let adelaide = TimeZone(identifier: "Australia/Adelaide")!
        func write(_ image: CGImage?, _ name: String) throws {
            guard let image else { fatalError("Could not render \(name)") }
            let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
            try data.write(to: folder.appendingPathComponent("\(name).png"))
        }
        try write(ClockRaster.composite(pixels: 1024, date: date, zone: adelaide), "Clock-1024")
        try write(ClockRaster.composite(pixels: 340, date: date, zone: adelaide), "Clock-Small-2x")
        try write(ClockRaster.composite(pixels: 1024, date: date, zone: adelaide, buttonProgress: 1, alarmAngle: 210), "Clock-Armed-1024")
        try write(ClockRaster.composite(pixels: 64, date: date, zone: adelaide, showSeconds: false), "Clock-64")
        let widget = ImageRenderer(content: ClockWidgetContent(entry: ClockEntry(date: date, city: .adelaide))
            .frame(width: 170, height: 170))
        widget.scale = 2
        try write(widget.cgImage, "Widget-Small-2x")
        // Every preset on one sheet, in both appearances.
        for dark in [true, false] { try write(styleSheet(date: date, zone: adelaide, dark: dark), dark ? "Styles-Dark" : "Styles-Light") }
        // Layers for the browser preview (Scripts/make-preview-html.py).
        try write(ClockRaster.image(.body(control: nil), pixels: 1102), "Layer-Body")
        try write(ClockRaster.image(.glass, pixels: 1102), "Layer-Glass")
        print("Rendered previews to build/Previews.")
    }

    /// A grid of every preset, each fitted into a square cell with its name beneath.
    static func styleSheet(date: Date, zone: TimeZone, dark: Bool) -> CGImage? {
        let columns = 3, cell = 340, label = 44
        let presets = ClockPreset.all
        let rows = (presets.count + columns - 1) / columns
        let width = columns * cell, height = rows * (cell + label)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.setFillColor(dark ? ClockDesign.rgb(0x1E1F22) : ClockDesign.rgb(0xE9E8E4)); c.fill(CGRect(x: 0, y: 0, width: width, height: height))
        for (i, preset) in presets.enumerated() {
            let col = i % columns, row = i / columns
            let box = CGRect(x: col * cell + 20, y: height - (row + 1) * (cell + label) + label + 10, width: cell - 40, height: cell - 40)
            let crop = ClockRender.face(preset.style).crop(preset.style)
            let fitted = ClockRaster.fit(crop, in: box)
            if let image = ClockRaster.composite(pixels: Int(fitted.width * 2), date: date, zone: zone, style: preset.style, dark: dark,
                                                 alarmAngle: preset.style.family == .arch ? nil : nil) {
                c.draw(image, in: fitted)
            }
            let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 20, nil)
            let line = DialKit.textLine(preset.name, font: font, color: dark ? ClockDesign.white(0.85) : ClockDesign.black(0.75))
            let w = CTLineGetTypographicBounds(line, nil, nil, nil)
            c.textPosition = CGPoint(x: CGFloat(col * cell) + (CGFloat(cell) - w) / 2, y: CGFloat(height - (row + 1) * (cell + label) + 16))
            CTLineDraw(line, c)
        }
        return c.makeImage()
    }
}
