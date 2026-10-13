import SwiftUI
import AppKit

@main struct IconRenderer {
    @MainActor static func main() throws {
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let renderer = ImageRenderer(content: ClockAppIcon().frame(width: CGFloat(size), height: CGFloat(size)))
            renderer.scale = 1
            guard let cg = renderer.cgImage else { fatalError("Could not render icon") }
            let rep = NSBitmapImageRep(cgImage: cg)
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "Resources/icon-\(size).png"))
        }
    }
}
