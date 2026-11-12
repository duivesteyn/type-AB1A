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
    static let handWhite = rgb(0xF5F5F2)
    static let yellow = rgb(0xFFD203)
    static let printedGreen = rgb(0x88D672)
    static let alarmGreen = rgb(0x67D64D)

    // MARK: Cube dial

    /// The cube's dial in shared `DialSpec` form.
    static let dialSpec = DialSpec(
        center: pivot, face: dialRadius, tickOuter: tickOuter, minorTick: minuteTick, majorTick: hourTick,
        numeralSize: numeralSize, numeralGap: numeralGap,
        hour: HandShape(length: hourHand.length, width: hourHand.width, tail: hourHand.tail),
        minute: HandShape(length: minuteHand.length, width: minuteHand.width, tail: minuteHand.tail),
        second: HandShape(length: secondHand.length, width: secondHand.width, tail: secondHand.tail),
        alarmLength: alarmHand.length, counterweight: (counterweightRadius, counterweightOffset),
        hubRadius: hubRadius, glassRadius: bezelRadius)

    /// The original black Type AB1, for callers that don't pass a style.
    static let standardPalette = ClockPalette(.standard, dark: true)

    // MARK: Cube parts (default: black Type AB1)

    /// Housing, dial recess, dial, ticks and numerals; optionally the top button.
    static func drawBody(_ c: CGContext, buttonProgress: Double? = nil) {
        ClockRender.drawStill(c, .standard, standardPalette, control: buttonProgress)
    }

    static func drawButton(_ c: CGContext, progress: Double, _ p: ClockPalette = standardPalette) {
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
        let light = !p.dark
        c.saveGState()
        c.addPath(path); c.clip()
        // Front face, lit from above.
        linear(c, light ? [rgb(0xF4F4F2), rgb(0xE2E2DF), rgb(0xCFCFCB)] : [rgb(0x37383B), rgb(0x232426), rgb(0x1A1B1D)], [0, 0.45, 1],
               from: CGPoint(x: 0, y: rect.minY), to: CGPoint(x: 0, y: housing.minY))
        // Rounded side edges.
        linear(c, [black(light ? 0.15 : 0.45), black(0), black(0), black(light ? 0.15 : 0.45)], [0, 0.06, 0.94, 1],
               from: CGPoint(x: rect.minX, y: 0), to: CGPoint(x: rect.maxX, y: 0))
        // Thin top face seen from slightly above, with its printed green mark.
        let top = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 9)
        linear(c, light ? [rgb(0xFFFFFF), rgb(0xF0F0EE)] : [rgb(0x55565A), rgb(0x3A3B3E)], [0, 1],
               from: CGPoint(x: 0, y: top.minY), to: CGPoint(x: 0, y: top.maxY))
        c.setFillColor(white(light ? 0.8 : 0.22)); c.fill(CGRect(x: rect.minX + corner, y: rect.minY, width: rect.width - corner * 2, height: 1.6))
        c.setFillColor(printedGreen)
        c.fillEllipse(in: CGRect(x: pivot.x - 22, y: top.midY - 2.6, width: 44, height: 5.2))
        c.restoreGState()
    }

    static func drawHousing(_ c: CGContext, _ p: ClockPalette = standardPalette) {
        drawHousingSurface(c, CGPath(roundedRect: housing, cornerWidth: housingCorner, cornerHeight: housingCorner, transform: nil), bounds: housing, p)
    }

    /// Moulded plastic filling `path`, lit from the upper left, with a bevelled edge.
    /// Shared by every case and by the app icon's rounded-square body.
    static func drawHousingSurface(_ c: CGContext, _ path: CGPath, bounds: CGRect, _ p: ClockPalette = standardPalette,
                                   reference: CGFloat? = nil) {
        let unit = bounds.width / (reference ?? housing.width)
        c.saveGState()
        c.addPath(path); c.clip()
        linear(c, p.housing, [0, 0.55, 1], from: CGPoint(x: 0, y: bounds.minY), to: CGPoint(x: 0, y: bounds.maxY))
        // Soft sheen from a window up and to the left.
        radial(c, [white(p.sheen), white(0)], [0, 1], center: CGPoint(x: bounds.minX + 250 * unit, y: bounds.minY + 160 * unit), radius: 760 * unit)
        grain(c, in: bounds, alpha: p.grain)
        // Bevel: bright top lip, darker lower edge.
        c.addPath(path); c.setLineWidth(14 * unit); c.replacePathWithStrokedPath(); c.clip()
        linear(c, [white(p.bevelLight), white(p.bevelLight * 0.2), black(p.bevelDark * 0.22), black(p.bevelDark)], [0, 0.08, 0.6, 1],
               from: CGPoint(x: 0, y: bounds.minY), to: CGPoint(x: 0, y: bounds.maxY))
        c.restoreGState()
        c.saveGState()
        c.addPath(path); c.setStrokeColor(p.outline); c.setLineWidth(2 * unit); c.strokePath()
        c.restoreGState()
    }

    /// A chamfered round opening: in shadow at the top, catching light at the bottom,
    /// with the clear crystal's edge inside it.
    static func drawDialRecess(_ c: CGContext, _ p: ClockPalette = standardPalette, center: CGPoint = pivot,
                               radius: CGFloat = bezelRadius, chamfer: CGFloat = 10) {
        let outer = radius + chamfer
        c.saveGState()
        c.addEllipse(in: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)); c.clip()
        linear(c, p.recess, [0, 0.5, 1], from: CGPoint(x: 0, y: center.y - outer), to: CGPoint(x: 0, y: center.y + outer))
        c.restoreGState()
        c.saveGState()
        c.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)); c.clip()
        linear(c, p.crystalEdge, [0, 1], from: CGPoint(x: 0, y: center.y - radius), to: CGPoint(x: 0, y: center.y + radius))
        c.restoreGState()
    }

    /// The dial disc, shaded at the top by the case lip.
    static func drawDial(_ c: CGContext, _ p: ClockPalette = standardPalette, _ d: DialSpec = dialSpec) {
        c.saveGState()
        c.addEllipse(in: d.circle(d.face)); c.clip()
        radial(c, p.dial, [0, 0.7, 1], center: d.center, radius: d.face)
        if p.finish == .lagoon {
            // Lacquered sunburst: a bright bloom up and to the left.
            radial(c, [white(0.32), white(0)], [0, 1], center: CGPoint(x: d.center.x - d.face * 0.35, y: d.center.y - d.face * 0.45), radius: d.face * 0.9)
        }
        grain(c, in: d.circle(d.face), alpha: p.dialGrain)
        radial(c, [black(0), black(0), black(p.dialShade)], [0, 0.88, 1.0],
               center: CGPoint(x: d.center.x, y: d.center.y + d.face * 0.037), radius: d.face * 1.032)
        c.restoreGState()
    }

    static func drawTicks(_ c: CGContext, minuteTicks: Bool = true) {
        DialKit.ticks(c, dialSpec, standardPalette, minuteTicks: minuteTicks)
    }

    static func drawNumerals(_ c: CGContext) {
        DialKit.numerals(c, dialSpec, standardPalette, .standard)
    }

    /// One hand pointing at 12, without a shadow. Callers rotate about `pivot`.
    static func drawHand(_ c: CGContext, _ kind: HandKind) { DialKit.drawHand(c, dialSpec, standardPalette, kind) }
    static func drawHub(_ c: CGContext) { DialKit.drawHub(c, dialSpec, standardPalette) }
    static func drawGlass(_ c: CGContext) { DialKit.glass(c, center: pivot, radius: bezelRadius, strength: 1) }

    /// Everything on the dial that moves, with screen-fixed shadows.
    static func drawMovingParts(_ c: CGContext, angles: HandAngles, showSeconds: Bool,
                                alarmAngle: Double?, shadowScale: CGFloat) {
        DialKit.drawMoving(c, dialSpec, standardPalette, angles: angles, showSeconds: showSeconds,
                           alarmAngle: alarmAngle, shadowScale: shadowScale)
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

    /// Fine moulded-plastic grain from a small fixed noise tile, one tile pixel per device pixel.
    static func grain(_ c: CGContext, in rect: CGRect, alpha: CGFloat) {
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

/// The square desk alarm clock: the original Type AB1, now in black, white or lagoon.
enum CubeFace: ClockFace {
    static func crop(_ style: ClockStyle) -> CGRect { ClockGeometry.sourceSquare }
    static func dial(_ style: ClockStyle) -> DialSpec { ClockDesign.dialSpec }
    static var controlBehindBody: Bool { true }
    static func controlRect(_ style: ClockStyle) -> CGRect? {
        let cap = ClockDesign.buttonRect(progress: 1)
        return CGRect(x: cap.minX, y: cap.minY, width: cap.width, height: ClockDesign.housing.minY + 30 - cap.minY)
    }
    static func drawControl(_ c: CGContext, _ style: ClockStyle, _ palette: ClockPalette, progress: Double) {
        ClockDesign.drawButton(c, progress: progress, palette)
    }
    static func drawBody(_ c: CGContext, _ style: ClockStyle, _ p: ClockPalette) {
        let d = ClockDesign.dialSpec
        ClockDesign.drawHousing(c, p)
        ClockDesign.drawDialRecess(c, p)
        ClockDesign.drawDial(c, p, d)
        DialKit.ticks(c, d, p)
        DialKit.numerals(c, d, p, style)
        if style.dialText { DialKit.dialText(c, d, p) }
    }
}
