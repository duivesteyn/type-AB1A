import CoreGraphics
import CoreText
import Foundation

/// The whole clock, drawn as vectors on the 1254-unit artboard.
///
/// Coordinates are y-down with the origin top-left, matching the original artwork
/// package. Hands point to 12 at 0° and turn clockwise about `pivot`. Every function
/// expects a context whose user space is already this artboard (see `ClockRaster`
/// and `NativeClockView` for the mapping).
///
/// Proportions follow a photograph of a real AB1A: a matte, lightly grained square
/// housing, a recessed dial under a clear crystal, light geometric numerals, long
/// white hands, and a yellow seconds hand with a round counterweight.
enum ClockDesign {
    static let pivot = CGPoint(x: 627, y: 677)

    // MARK: Housing and top button

    static let housing = CGRect(x: 104, y: 154, width: 1046, height: 1046)
    static let housingCorner: CGFloat = 92
    static let buttonWidth: CGFloat = 330
    /// How far the cap stands above the housing when down (alarm off).
    static let buttonRest: CGFloat = 20
    /// Extra lift when up (alarm armed).
    static let buttonTravel: CGFloat = 36

    /// The visible cap, from its top edge down into the housing slot.
    static func buttonRect(progress: Double) -> CGRect {
        let top = housing.minY - buttonRest - buttonTravel * CGFloat(progress)
        return CGRect(x: pivot.x - buttonWidth / 2, y: top, width: buttonWidth, height: housing.minY + 24 - top)
    }

    // MARK: Dial

    static let bezelRadius: CGFloat = 462
    static let dialRadius: CGFloat = 438
    static let tickOuter: CGFloat = 404
    static let minuteTick = CGSize(width: 5, height: 22)
    static let hourTick = CGSize(width: 7.5, height: 36)
    static let numeralSize: CGFloat = 66
    /// Gap between the hour ticks and the nearest edge of each numeral.
    static let numeralGap: CGFloat = 22

    // MARK: Hands

    struct Hand { let length: CGFloat; let width: CGFloat; let tail: CGFloat }
    static let hourHand = Hand(length: 296, width: 25, tail: 36)
    static let minuteHand = Hand(length: 398, width: 20, tail: 36)
    static let secondHand = Hand(length: 386, width: 6, tail: 40)
    static let alarmHand = Hand(length: 394, width: 6, tail: 0)
    static let counterweightRadius: CGFloat = 23
    static let counterweightOffset: CGFloat = 48
    static let hubRadius: CGFloat = 50

    enum HandKind: String, CaseIterable { case hour, minute, second, alarm }

    // MARK: Palette (sRGB)

    static func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
    static func white(_ alpha: CGFloat) -> CGColor { CGColor(srgbRed: 1, green: 1, blue: 1, alpha: alpha) }
    static func black(_ alpha: CGFloat) -> CGColor { CGColor(srgbRed: 0, green: 0, blue: 0, alpha: alpha) }
    static let ink = rgb(0xEDEDE7)          // ticks and numerals
    static let handWhite = rgb(0xF5F5F2)
    static let yellow = rgb(0xFFD203)
    static let printedGreen = rgb(0x88D672)
    static let alarmGreen = rgb(0x67D64D)

    // MARK: Static body

    /// Housing, dial recess, dial, ticks and numerals. Optionally the top button,
    /// for renderers that never animate it (widget, icon).
    static func drawBody(_ c: CGContext, buttonProgress: Double? = nil) {
        if let buttonProgress { drawButton(c, progress: buttonProgress) }
        drawHousing(c)
        drawDialRecess(c)
        drawDial(c)
        drawTicks(c)
        drawNumerals(c)
    }

    static func drawButton(_ c: CGContext, progress: Double) {
        let rect = buttonRect(progress: progress)
        let corner: CGFloat = 9
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addQuadCurve(to: CGPoint(x: rect.minX + corner, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + corner), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        c.saveGState()
        c.addPath(path); c.clip()
        // Front face, lit from above.
        linear(c, [rgb(0x37383B), rgb(0x232426), rgb(0x1A1B1D)], [0, 0.45, 1],
               from: CGPoint(x: 0, y: rect.minY), to: CGPoint(x: 0, y: housing.minY))
        // Rounded side edges.
        linear(c, [black(0.45), black(0), black(0), black(0.45)], [0, 0.06, 0.94, 1],
               from: CGPoint(x: rect.minX, y: 0), to: CGPoint(x: rect.maxX, y: 0))
        // Thin top face seen from slightly above, with its printed green mark.
        let top = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 9)
        linear(c, [rgb(0x55565A), rgb(0x3A3B3E)], [0, 1], from: CGPoint(x: 0, y: top.minY), to: CGPoint(x: 0, y: top.maxY))
        c.setFillColor(white(0.22)); c.fill(CGRect(x: rect.minX + corner, y: rect.minY, width: rect.width - corner * 2, height: 1.6))
        c.setFillColor(printedGreen)
        c.fillEllipse(in: CGRect(x: pivot.x - 22, y: top.midY - 2.6, width: 44, height: 5.2))
        c.restoreGState()
    }

    static func drawHousing(_ c: CGContext) {
        let path = CGPath(roundedRect: housing, cornerWidth: housingCorner, cornerHeight: housingCorner, transform: nil)
        c.saveGState()
        c.addPath(path); c.clip()
        linear(c, [rgb(0x333436), rgb(0x2A2B2D), rgb(0x222325)], [0, 0.55, 1],
               from: CGPoint(x: 0, y: housing.minY), to: CGPoint(x: 0, y: housing.maxY))
        // Soft sheen from a window up and to the left.
        radial(c, [white(0.075), white(0)], [0, 1], center: CGPoint(x: housing.minX + 250, y: housing.minY + 160), radius: 760)
        grain(c, in: housing, alpha: 0.11)
        // Bevel: bright top lip, darker lower edge.
        c.addPath(path); c.setLineWidth(14); c.replacePathWithStrokedPath(); c.clip()
        linear(c, [white(0.20), white(0.04), black(0.10), black(0.45)], [0, 0.08, 0.6, 1],
               from: CGPoint(x: 0, y: housing.minY), to: CGPoint(x: 0, y: housing.maxY))
        c.restoreGState()
        c.saveGState()
        c.addPath(path); c.setStrokeColor(black(0.7)); c.setLineWidth(2); c.strokePath()
        c.restoreGState()
    }

    static func drawDialRecess(_ c: CGContext) {
        // A chamfered opening: in shadow at the top, catching light at the bottom.
        let outer = bezelRadius + 10
        c.saveGState()
        c.addEllipse(in: circle(outer)); c.clip()
        linear(c, [rgb(0x0B0C0D), rgb(0x1A1B1D), rgb(0x55575A)], [0, 0.5, 1],
               from: CGPoint(x: 0, y: pivot.y - outer), to: CGPoint(x: 0, y: pivot.y + outer))
        c.restoreGState()
        // Clear crystal edge between the opening and the dial.
        c.saveGState()
        c.addEllipse(in: circle(bezelRadius)); c.clip()
        linear(c, [rgb(0x0E0F10), rgb(0x161719)], [0, 1],
               from: CGPoint(x: 0, y: pivot.y - bezelRadius), to: CGPoint(x: 0, y: pivot.y + bezelRadius))
        c.restoreGState()
    }

    static func drawDial(_ c: CGContext) {
        c.saveGState()
        c.addEllipse(in: circle(dialRadius)); c.clip()
        radial(c, [rgb(0x232426), rgb(0x1C1D1F), rgb(0x161718)], [0, 0.7, 1], center: pivot, radius: dialRadius)
        grain(c, in: circle(dialRadius), alpha: 0.05)
        // The housing lip shades the top of the dial.
        radial(c, [black(0), black(0), black(0.45)], [0, 0.88, 1.0],
               center: CGPoint(x: pivot.x, y: pivot.y + 16), radius: dialRadius + 14)
        c.restoreGState()
    }

    static func drawTicks(_ c: CGContext) {
        c.saveGState()
        c.setFillColor(ink)
        for index in 0..<60 {
            let size = index % 5 == 0 ? hourTick : minuteTick
            c.saveGState()
            c.translateBy(x: pivot.x, y: pivot.y)
            c.rotate(by: CGFloat(index) * .pi / 30)
            c.fill(CGRect(x: -size.width / 2, y: -tickOuter, width: size.width, height: size.height))
            c.restoreGState()
        }
        c.restoreGState()
    }

    static func drawNumerals(_ c: CGContext) {
        let font = CTFontCreateWithName("HelveticaNeue" as CFString, numeralSize, nil)
        let outer = tickOuter - hourTick.height - numeralGap
        for hour in 1...12 {
            let text = NSAttributedString(string: "\(hour)", attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
                NSAttributedString.Key(kCTKernAttributeName as String): -1.5
            ])
            let line = CTLineCreateWithAttributedString(text)
            let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
            let angle = CGFloat(hour) * .pi / 6
            let (sx, cy) = (sin(angle), -cos(angle))
            // Keep each numeral's nearest edge the same distance from the ticks.
            let reach = abs(sx) * bounds.width / 2 + abs(cy) * bounds.height / 2
            let centre = CGPoint(x: pivot.x + (outer - reach) * sx, y: pivot.y + (outer - reach) * cy)
            c.saveGState()
            c.translateBy(x: centre.x, y: centre.y)
            c.scaleBy(x: 1, y: -1)
            c.textMatrix = .identity
            c.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
            CTLineDraw(line, c)
            c.restoreGState()
        }
    }

    // MARK: Moving parts

    /// One hand pointing at 12, without a shadow. Callers rotate about `pivot`.
    static func drawHand(_ c: CGContext, _ kind: HandKind) {
        c.saveGState()
        c.translateBy(x: pivot.x, y: pivot.y)
        switch kind {
        case .hour: whiteHand(c, hourHand)
        case .minute: whiteHand(c, minuteHand)
        case .second:
            let hand = secondHand
            let path = CGMutablePath()
            path.addRoundedRect(in: CGRect(x: -hand.width / 2, y: -hand.length, width: hand.width, height: hand.length + hand.tail),
                                cornerWidth: hand.width / 2, cornerHeight: hand.width / 2)
            path.addEllipse(in: CGRect(x: -counterweightRadius, y: counterweightOffset - counterweightRadius,
                                       width: counterweightRadius * 2, height: counterweightRadius * 2))
            c.addPath(path); c.clip()
            linear(c, [rgb(0xFFE14A), yellow, rgb(0xEABF00)], [0, 0.5, 1],
                   from: CGPoint(x: -counterweightRadius, y: 0), to: CGPoint(x: counterweightRadius, y: 0))
        case .alarm:
            let hand = alarmHand
            c.setFillColor(rgb(0x3A3B3E))
            c.fill(CGRect(x: -hand.width / 2, y: -hand.length, width: hand.width, height: hand.length))
            c.setFillColor(alarmGreen)
            c.fill(CGRect(x: -4.5, y: -hand.length, width: 9, height: 34))
        }
        c.restoreGState()
    }

    static func drawHub(_ c: CGContext) {
        let rect = circle(hubRadius)
        c.saveGState()
        c.addEllipse(in: rect); c.clip()
        radial(c, [rgb(0xFFE866), yellow, rgb(0xE8BC00)], [0, 0.5, 1],
               center: CGPoint(x: pivot.x - 16, y: pivot.y - 20), radius: hubRadius * 1.45)
        c.restoreGState()
        c.saveGState()
        c.setStrokeColor(rgb(0xD9AE00)); c.setLineWidth(2)
        c.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
        c.restoreGState()
    }

    /// Clear crystal over everything on the dial: a soft reflection and a lit rim.
    static func drawGlass(_ c: CGContext) {
        c.saveGState()
        c.addEllipse(in: circle(bezelRadius)); c.clip()
        // Broad crescent reflection, upper left, fading to nothing at its inner edge.
        let inner = bezelRadius * 1.08
        let innerCentre = CGPoint(x: pivot.x + 70, y: pivot.y + 95)
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                     colors: [white(0), white(0.05), white(0.09)] as CFArray, locations: [0, 0.6, 1]) {
            c.drawRadialGradient(gradient, startCenter: innerCentre, startRadius: inner,
                                 endCenter: innerCentre, endRadius: inner + 160, options: [.drawsAfterEndLocation])
        }
        // Gentle overall sheen.
        linear(c, [white(0.035), white(0), white(0)], [0, 0.45, 1],
               from: CGPoint(x: 0, y: pivot.y - bezelRadius), to: CGPoint(x: 0, y: pivot.y + bezelRadius))
        c.restoreGState()
        // Polished crystal rim, brightest where it faces the light.
        c.saveGState()
        c.addEllipse(in: circle(bezelRadius - 4)); c.setLineWidth(5); c.replacePathWithStrokedPath(); c.clip()
        linear(c, [white(0.06), white(0.03), white(0.30)], [0, 0.45, 1],
               from: CGPoint(x: pivot.x - 300, y: pivot.y - 340), to: CGPoint(x: pivot.x + 300, y: pivot.y + 340))
        c.restoreGState()
    }

    // MARK: Composition

    /// Everything on the dial that moves, in stacking order, with screen-fixed shadows.
    /// `shadowScale` converts artboard units to the context's base (shadow) space.
    static func drawMovingParts(_ c: CGContext, angles: HandAngles, showSeconds: Bool,
                                alarmAngle: Double?, shadowScale: CGFloat) {
        func rotated(_ degrees: Double, _ kind: HandKind, lift: CGFloat) {
            c.saveGState()
            setShadow(c, lift: lift, scale: shadowScale)
            c.translateBy(x: pivot.x, y: pivot.y)
            c.rotate(by: CGFloat(degrees) * .pi / 180)
            c.translateBy(x: -pivot.x, y: -pivot.y)
            drawHand(c, kind)
            c.restoreGState()
        }
        if let alarmAngle { rotated(alarmAngle, .alarm, lift: 2) }
        rotated(angles.hour, .hour, lift: 4)
        rotated(angles.minute, .minute, lift: 5)
        if showSeconds { rotated(angles.second, .second, lift: 7) }
        c.saveGState()
        setShadow(c, lift: 7, scale: shadowScale)
        drawHub(c)
        c.restoreGState()
    }

    /// Light from above: shadows fall straight down, further for higher parts.
    static func setShadow(_ c: CGContext, lift: CGFloat, scale: CGFloat) {
        c.setShadow(offset: CGSize(width: lift * 0.25 * scale, height: -lift * scale),
                    blur: (4 + lift) * scale, color: black(0.5))
    }

    // MARK: Helpers

    static func circle(_ radius: CGFloat) -> CGRect {
        CGRect(x: pivot.x - radius, y: pivot.y - radius, width: radius * 2, height: radius * 2)
    }

    static func linear(_ c: CGContext, _ colors: [CGColor], _ locations: [CGFloat], from: CGPoint, to: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations) else { return }
        c.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    static func radial(_ c: CGContext, _ colors: [CGColor], _ locations: [CGFloat], center: CGPoint, radius: CGFloat) {
        guard let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: locations) else { return }
        c.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [.drawsAfterEndLocation])
    }

    private static func whiteHand(_ c: CGContext, _ hand: Hand) {
        let rect = CGRect(x: -hand.width / 2, y: -hand.length, width: hand.width, height: hand.length + hand.tail)
        c.addPath(CGPath(roundedRect: rect, cornerWidth: hand.width / 2, cornerHeight: hand.width / 2, transform: nil))
        c.clip()
        linear(c, [rgb(0xFFFFFF), handWhite, rgb(0xD4D4CF)], [0, 0.45, 1],
               from: CGPoint(x: rect.minX, y: 0), to: CGPoint(x: rect.maxX, y: 0))
    }

    /// Fine moulded-plastic grain from a small fixed noise tile, one tile pixel per device pixel.
    private static func grain(_ c: CGContext, in rect: CGRect, alpha: CGFloat) {
        guard let tile = noiseTile else { return }
        let deviceScale = max(0.05, abs(c.userSpaceToDeviceSpaceTransform.a))
        let size = CGFloat(tile.width) / deviceScale
        c.saveGState()
        c.setAlpha(alpha)
        c.setBlendMode(.overlay)
        c.draw(tile, in: CGRect(x: rect.minX, y: rect.minY, width: size, height: size), byTiling: true)
        c.restoreGState()
    }

    private static let noiseTile: CGImage? = {
        let side = 128
        var state: UInt32 = 0x9E37_79B9
        var pixels = [UInt8](repeating: 0, count: side * side)
        for i in pixels.indices {
            state ^= state << 13; state ^= state >> 17; state ^= state << 5
            pixels[i] = UInt8(truncatingIfNeeded: 64 + Int(state % 128))
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }()
}
