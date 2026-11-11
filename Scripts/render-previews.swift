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
        // Layers for the browser preview (Scripts/make-preview-html.py).
        try write(ClockRaster.image(.body(buttonProgress: nil), pixels: 1102), "Layer-Body")
        try write(ClockRaster.image(.glass, pixels: 1102), "Layer-Glass")
        print("Rendered previews to build/Previews.")
    }
}
