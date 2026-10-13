import SwiftUI
import AppKit
import WidgetKit

@main struct PreviewRenderer {
    @MainActor static func main() throws {
        let date = ISO8601DateFormatter().date(from: "2026-10-13T23:40:00Z")!
        func save<V: View>(_ view: V, size: CGSize, name: String) throws {
            let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            renderer.scale = 2
            guard let cg = renderer.cgImage else { fatalError("Could not render \(name)") }
            let rep = NSBitmapImageRep(cgImage: cg)
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/\(name).png"))
        }
        try save(FittedClockArtwork(date: date, zone: TimeZone(identifier: "Australia/Adelaide")!), size: CGSize(width: 164, height: 164), name: "Clock-Preview")
        try save(FittedClockArtwork(date: date, zone: TimeZone(identifier: "Australia/Adelaide")!, armed: true, alarmAngle: 210), size: CGSize(width: 164, height: 164), name: "Clock-Armed-Preview")
        try save(ClockWidgetContent(entry: ClockEntry(date: date, city: .adelaide), family: .systemSmall), size: CGSize(width: 170, height: 170), name: "Widget-Small-Preview")
        try save(ClockWidgetContent(entry: ClockEntry(date: date, city: .london), family: .systemMedium), size: CGSize(width: 360, height: 170), name: "Widget-Medium-Preview")
        print("Rendered app and both widget sizes.")
    }
}
