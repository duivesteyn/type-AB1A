import AppKit

/// Renders the app icon from the same vectors as the clock, at 10:10:30 (it likes to
/// look cheerful for photographs). Follows the macOS icon grid: an 824-point body on a
/// 1024 canvas with a soft shadow. Run through Scripts/make-icon.sh.
@main struct IconRenderer {
    static func main() throws {
        let date = ISO8601DateFormatter().date(from: "2026-01-01T10:10:30Z")!
        let utc = TimeZone(identifier: "UTC")!
        let iconset = URL(fileURLWithPath: "Resources/Clock.iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        var rendered: [Int: Data] = [:]
        for size in [16, 32, 64, 128, 256, 512, 1024] {
            let data = try png(render(size: size, date: date, zone: utc))
            rendered[size] = data
            try data.write(to: URL(fileURLWithPath: "Resources/icon-\(size).png"))
        }
        for size in [16, 32, 128, 256, 512] {
            try rendered[size]!.write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
            try rendered[size * 2]!.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
        }
        print("Rendered icons and Resources/Clock.iconset.")
    }

    static func render(size: Int, date: Date, zone: TimeZone) throws -> CGImage {
        let canvas = CGFloat(size)
        // The housing is 1046/1102 of the clock square; size it to the 824/1024 grid.
        let clockSide = canvas * (824.0 / 1024.0) * (ClockGeometry.cropSide / ClockDesign.housing.width)
        let pixels = max(16, Int(clockSide.rounded()))
        guard let clock = ClockRaster.composite(pixels: pixels, date: date, zone: zone, showSeconds: size >= 32),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
        c.interpolationQuality = .high
        let side = CGFloat(pixels)
        // Centre the housing (not the button) in the canvas; y-up context.
        let housingCentreY = (ClockDesign.housing.midY - ClockGeometry.cropY) / ClockGeometry.cropSide * side
        let rect = CGRect(x: (canvas - side) / 2, y: canvas / 2 - (side - housingCentreY), width: side, height: side)
        c.setShadow(offset: CGSize(width: 0, height: -canvas * 0.012), blur: canvas * 0.03,
                    color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.38))
        c.draw(clock, in: rect)
        guard let image = c.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        return image
    }

    static func png(_ image: CGImage) throws -> Data {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
