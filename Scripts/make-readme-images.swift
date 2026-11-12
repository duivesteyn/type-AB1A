import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
import WidgetKit

/// Renders the README's pictures into docs/images from the app's own artwork.
/// Run through Scripts/make-readme-images.sh.
@main struct ReadmeImages {
    static let folder = URL(fileURLWithPath: "docs/images", isDirectory: true)
    static let space = CGColorSpace(name: CGColorSpace.sRGB)!

    @MainActor static func main() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try realAndDrawn()
        try buttonStates()
        try widgets()
        let date = ISO8601DateFormatter().date(from: "2026-10-13T23:40:37Z")!
        for dark in [true, false] {
            try write(styleSheet(date: date, zone: TimeZone(identifier: "Australia/Adelaide")!, dark: dark)!, dark ? "styles-dark.png" : "styles-light.png", type: .png)
        }
        print("Wrote README images to docs/images.")
    }

    /// The photographed clock beside the drawn one, set to the same moment and alarm.
    static func realAndDrawn() throws {
        guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: "20261014_Braun_AB1A_Type3885_BMD.jpeg") as CFURL, nil),
              let photo = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let crop = photo.cropping(to: CGRect(x: 830, y: 175, width: 1230, height: 1230)) else { throw CocoaError(.fileReadUnknown) }
        // The photo reads about 10:12:23 with the alarm hand at 3.
        let date = ISO8601DateFormatter().date(from: "2026-10-14T10:12:23Z")!
        let side = 760, gap = 40, pad = 40
        let c = context(width: side * 2 + gap + pad * 2, height: side + pad * 2)
        c.setFillColor(ClockDesign.rgb(0xEDEBE6)); c.fill(CGRect(x: 0, y: 0, width: c.width, height: c.height))
        c.draw(crop, in: CGRect(x: pad, y: pad, width: side, height: side))
        let drawn = ClockRaster.composite(pixels: 680, date: date, zone: TimeZone(identifier: "UTC")!, alarmAngle: 90)!
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: ClockDesign.black(0.35))
        c.draw(drawn, in: CGRect(x: pad + side + gap + 40, y: pad + 40, width: 680, height: 680))
        c.restoreGState()
        try write(c.makeImage()!, "real-and-drawn.jpg", type: .jpeg)
    }

    /// Alarm off (button down) and armed for 07:00 (button up, green-tipped alarm hand).
    static func buttonStates() throws {
        let date = ISO8601DateFormatter().date(from: "2026-10-14T09:41:12Z")!, utc = TimeZone(identifier: "UTC")!
        let side = 520, gap = 60
        let c = context(width: side * 2 + gap, height: side)
        c.draw(ClockRaster.composite(pixels: side, date: date, zone: utc)!, in: CGRect(x: 0, y: 0, width: side, height: side))
        c.draw(ClockRaster.composite(pixels: side, date: date, zone: utc, buttonProgress: 1, alarmAngle: 210)!,
               in: CGRect(x: side + gap, y: 0, width: side, height: side))
        try write(c.makeImage()!, "button-states.png", type: .png)
    }

    /// The three widgets on a soft wallpaper, at 2x (4:40 in Adelaide, Dark Mode): Large cube, Small arch and wall.
    @MainActor static func widgets() throws {
        let date = ISO8601DateFormatter().date(from: "2026-10-13T18:10:00Z")!
        func widget(_ points: CGFloat, _ style: ClockStyle) -> CGImage {
            let view = ClockWidgetContent(entry: ClockEntry(date: date, city: .adelaide, style: style))
                .frame(width: points, height: points)
                .environment(\.colorScheme, .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            return renderer.cgImage!
        }
        let large = widget(364, WidgetStyle.cube), arch = widget(170, WidgetStyle.arch), wall = widget(170, WidgetStyle.wall)
        let pad = 90, gap = 70
        let c = context(width: large.width + arch.width + gap + pad * 2, height: large.height + pad * 2)
        ClockDesign.linear(c, [ClockDesign.rgb(0x9DB4C7), ClockDesign.rgb(0x6F8FA8), ClockDesign.rgb(0x4B6780)], [0, 0.5, 1],
                           from: CGPoint(x: 0, y: CGFloat(c.height)), to: CGPoint(x: CGFloat(c.width), y: 0))
        ClockDesign.radial(c, [ClockDesign.white(0.25), ClockDesign.white(0)], [0, 1], center: CGPoint(x: 260, y: CGFloat(c.height) - 120), radius: 700)
        let column = pad + large.width + gap
        for (image, x, y) in [(large, pad, pad), (arch, column, pad + large.height - arch.height), (wall, column, pad)] {
            c.saveGState()
            c.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: ClockDesign.black(0.3))
            c.draw(image, in: CGRect(x: x, y: y, width: image.width, height: image.height))
            c.restoreGState()
        }
        try write(c.makeImage()!, "widgets.jpg", type: .jpeg)
    }

    static func context(width: Int, height: Int) -> CGContext {
        let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.interpolationQuality = .high
        return c
    }

    static func write(_ image: CGImage, _ name: String, type: UTType) throws {
        let url = folder.appendingPathComponent(name)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
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
                                                 alarmAngle: nil) {
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
