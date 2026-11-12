import AppKit

/// Renders the app icon from the clock's own vectors, at 10:10:30 (it likes to look
/// cheerful for photographs). Run through Scripts/make-icon.sh.
///
/// The AB1's housing is already a rounded square, so the icon *is* the housing: it
/// fills Apple's macOS icon shape (an 824-point continuous-corner square on a 1024
/// canvas). macOS 26 shows icons that fill that shape as they are; anything else is
/// shrunk onto a grey tile.
@main struct IconRenderer {
    static let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    static let corner: CGFloat = 185.4

    static func main() throws {
        let date = ISO8601DateFormatter().date(from: "2026-01-01T10:10:30Z")!
        let utc = TimeZone(identifier: "UTC")!
        let iconset = URL(fileURLWithPath: "Resources/Clock.iconset", isDirectory: true)
        try? FileManager.default.removeItem(at: iconset)
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
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw CocoaError(.fileWriteUnknown) }
        c.interpolationQuality = .high
        let pixelsPerPoint = CGFloat(size) / 1024
        // A y-down 1024-point canvas, like Apple's icon template.
        c.translateBy(x: 0, y: CGFloat(size))
        c.scaleBy(x: pixelsPerPoint, y: -pixelsPerPoint)
        let shape = continuousSquare(body, radius: corner)
        let angles = HandAngles.at(date, zone: zone)

        // Lift off the Dock with a soft shadow inside the template margin.
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -10 * pixelsPerPoint), blur: 26 * pixelsPerPoint,
                    color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.32))
        c.addPath(shape); c.setFillColor(ClockDesign.rgb(0x2A2B2D)); c.fillPath()
        c.restoreGState()

        ClockDesign.drawHousingSurface(c, shape, bounds: body)
        // The dial, scaled so the housing matches the icon body and centred on its pivot.
        let scale = body.width / ClockDesign.housing.width
        c.saveGState()
        c.addPath(shape); c.clip()
        artboard(c, centre: CGPoint(x: body.midX, y: body.midY), scale: scale)
        ClockDesign.drawDialRecess(c)
        ClockDesign.drawDial(c)
        detailedDial(c, angles: angles, size: size, shadowScale: scale * pixelsPerPoint)
        c.restoreGState()
        guard let image = c.makeImage() else { throw CocoaError(.fileWriteUnknown) }
        return image
    }

    /// Put the artboard's pivot at `centre`, scaled.
    static func artboard(_ c: CGContext, centre: CGPoint, scale: CGFloat) {
        c.translateBy(x: centre.x, y: centre.y)
        c.scaleBy(x: scale, y: scale)
        c.translateBy(x: -ClockDesign.pivot.x, y: -ClockDesign.pivot.y)
    }

    /// The real dial; below 64 pixels, numerals and minute ticks give way to heavier hands.
    static func detailedDial(_ c: CGContext, angles: HandAngles, size: Int, shadowScale: CGFloat) {
        ClockDesign.drawTicks(c, minuteTicks: size >= 64)
        if size >= 64 { ClockDesign.drawNumerals(c) }
        if size >= 64 {
            ClockDesign.drawMovingParts(c, angles: angles, showSeconds: true, alarmAngle: nil, shadowScale: shadowScale)
            ClockDesign.drawGlass(c)
        } else {
            boldHands(c, angles: angles, showSeconds: size >= 32)
        }
    }

    /// Heavier hands for 16 and 32 pixels, where the real proportions vanish.
    static func boldHands(_ c: CGContext, angles: HandAngles, showSeconds: Bool) {
        func line(_ degrees: Double, length: CGFloat, width: CGFloat, color: CGColor) {
            let a = CGFloat(degrees) * .pi / 180, p = ClockDesign.pivot
            c.move(to: p)
            c.addLine(to: CGPoint(x: p.x + sin(a) * length, y: p.y - cos(a) * length))
            c.setLineWidth(width); c.setLineCap(.round); c.setStrokeColor(color); c.strokePath()
        }
        line(angles.hour, length: 250, width: 64, color: ClockDesign.handWhite)
        line(angles.minute, length: 360, width: 52, color: ClockDesign.handWhite)
        if showSeconds { line(angles.second, length: 360, width: 24, color: ClockDesign.yellow) }
        c.setFillColor(ClockDesign.yellow)
        c.fillEllipse(in: ClockDesign.circle(72))
    }

    /// Apple's continuous-curvature ("squircle") rounded rectangle.
    static func continuousSquare(_ rect: CGRect, radius r: CGFloat) -> CGPath {
        // One corner as offsets from its corner point, going from the top edge down the right edge.
        let corner: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: -1.08849323, y: 0), CGPoint(x: -0.86840689, y: 0), CGPoint(x: -0.66993427, y: 0.06549600)),
            (CGPoint(x: -0.37282392, y: 0.16906013), CGPoint(x: -0.16906013, y: 0.37282392), CGPoint(x: -0.06549600, y: 0.66993427)),
            (CGPoint(x: 0, y: 0.86840689), CGPoint(x: 0, y: 1.08849323), CGPoint(x: 0, y: 1.52866483)),
        ]
        let path = CGMutablePath()
        // Corners clockwise from top right; each maps (x along edge, y into side) to canvas.
        let frames: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: 1)),   // top right
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: 0, y: 1), CGPoint(x: -1, y: 0)),  // bottom right
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: -1)), // bottom left
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: 0, y: -1), CGPoint(x: 1, y: 0)),  // top left
        ]
        func point(_ frame: (CGPoint, CGPoint, CGPoint), _ p: CGPoint) -> CGPoint {
            CGPoint(x: frame.0.x + (frame.1.x * p.x + frame.2.x * p.y) * r,
                    y: frame.0.y + (frame.1.y * p.x + frame.2.y * p.y) * r)
        }
        path.move(to: point(frames[0], CGPoint(x: -1.52866483, y: 0)))
        for frame in frames {
            path.addLine(to: point(frame, CGPoint(x: -1.52866483, y: 0)))
            for (c1, c2, end) in corner { path.addCurve(to: point(frame, end), control1: point(frame, c1), control2: point(frame, c2)) }
        }
        path.closeSubpath()
        return path
    }

    static func png(_ image: CGImage) throws -> Data {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return data
    }
}
