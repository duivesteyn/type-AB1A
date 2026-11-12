import CoreGraphics
import CoreText
import Foundation

// MARK: - Faces

/// One family of clock, drawn in its own y-down artboard units.
protocol ClockFace {
    /// The part of the artboard every renderer shows (not necessarily square).
    static func crop(_ style: ClockStyle) -> CGRect
    /// Dial geometry.
    static func dial(_ style: ClockStyle) -> DialSpec
    /// Case and dial, everything that doesn't move.
    static func drawBody(_ c: CGContext, _ style: ClockStyle, _ palette: ClockPalette)
    /// The alarm control (button, slider or light) at `progress` 0 (off) to 1 (armed).
    static func drawControl(_ c: CGContext, _ style: ClockStyle, _ palette: ClockPalette, progress: Double)
    /// True when the control sits behind the case (the cube's top button).
    static var controlBehindBody: Bool { get }
    /// Where a click toggles the alarm, if this face has a control.
    static func controlRect(_ style: ClockStyle) -> CGRect?
}

/// Composes faces and dials into whole clocks.
enum ClockRender {
    static func face(_ style: ClockStyle) -> ClockFace.Type {
        switch style.family {
        case .cube: CubeFace.self
        case .arch: ArchFace.self
        case .wall: WallFace.self
        }
    }

    /// The still parts. With `control`, the alarm control is drawn in at that progress.
    static func drawStill(_ c: CGContext, _ style: ClockStyle, _ palette: ClockPalette, control: Double?) {
        let face = face(style)
        if let control, face.controlBehindBody { face.drawControl(c, style, palette, progress: control) }
        face.drawBody(c, style, palette)
        if let control, !face.controlBehindBody { face.drawControl(c, style, palette, progress: control) }
    }

    /// Date window and hands for a moment in time.
    static func drawLive(_ c: CGContext, _ style: ClockStyle, _ palette: ClockPalette, date: Date, zone: TimeZone,
                         alarmAngle: Double?, shadowScale: CGFloat) {
        let dial = face(style).dial(style)
        if style.dateWindow { DialKit.dateWindow(c, dial, palette, day: ClockReading.day(date, zone)) }
        let angles = HandAngles.at(date, zone: zone, showSeconds: style.seconds != .hidden, smooth: style.seconds == .sweep)
        DialKit.drawMoving(c, dial, palette, angles: angles, showSeconds: style.seconds != .hidden,
                           alarmAngle: alarmAngle, shadowScale: shadowScale)
    }

    static func drawGlass(_ c: CGContext, _ style: ClockStyle, _ palette: ClockPalette) {
        guard style.glass else { return }
        let dial = face(style).dial(style)
        DialKit.glass(c, center: dial.center, radius: dial.glassRadius, strength: palette.glass)
    }

    /// The whole clock at one moment, for icons, previews and thumbnails.
    static func drawComposite(_ c: CGContext, _ style: ClockStyle, dark: Bool, date: Date, zone: TimeZone,
                              control: Double = 0, alarmAngle: Double? = nil, shadowScale: CGFloat) {
        let palette = ClockPalette(style, dark: dark)
        drawStill(c, style, palette, control: control)
        drawLive(c, style, palette, date: date, zone: zone, alarmAngle: alarmAngle, shadowScale: shadowScale)
        drawGlass(c, style, palette)
    }
}

enum ClockReading {
    static func day(_ date: Date, _ zone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        return calendar.component(.day, from: date)
    }
}

// MARK: - Palette

/// Every colour a face needs, worked out once from the style and the appearance.
struct ClockPalette {
    let finish: ClockFinish
    var dark: Bool { finish != .white && finish != .lagoon }
    /// The dial reads dark (light ink) even on a light case.
    var darkDial: Bool { finish != .white }

    var housing: [CGColor]
    var sheen: CGFloat
    var grain: CGFloat
    var bevelLight: CGFloat
    var bevelDark: CGFloat
    var outline: CGColor
    var recess: [CGColor]
    var crystalEdge: [CGColor]
    var dial: [CGColor]
    var dialShade: CGFloat
    var dialGrain: CGFloat
    var ink: CGColor
    var minorTickAlpha: CGFloat
    var hour: CGColor
    var minute: CGColor
    var second: CGColor
    var hub: CGColor
    var pin: CGColor
    var lume: CGColor?
    var alarmShaft: CGColor
    var glass: CGFloat
    var dateWindow: CGColor
    var dateText: CGColor

    static let yellow = ClockDesign.rgb(0xFFD203)
    static let red = ClockDesign.rgb(0xE53935)

    init(_ style: ClockStyle, dark appearanceDark: Bool) {
        let finish = style.finish.resolved(dark: appearanceDark)
        self.finish = finish
        let rgb: (UInt32) -> CGColor = { ClockDesign.rgb($0) }
        let darkDial = finish != .white
        let light = finish == .white || finish == .lagoon
        // Case.
        switch (style.family, light) {
        case (.wall, true): housing = [rgb(0xFFFFFF), rgb(0xF3F3F5), rgb(0xDCDCE0)]
        case (.arch, true): housing = [rgb(0xFFFFFF), rgb(0xF4F4F6), rgb(0xDFDFE3)]
        case (_, true): housing = [rgb(0xF8F8F6), rgb(0xEEEEEB), rgb(0xD9D9D5)]
        case (.arch, false), (.wall, false): housing = [rgb(0x303033), rgb(0x232325), rgb(0x161618)]
        default: housing = [rgb(0x333436), rgb(0x2A2B2D), rgb(0x222325)]
        }
        sheen = light ? 0.35 : 0.075
        grain = light ? 0.05 : 0.11
        bevelLight = light ? 0.8 : 0.20
        bevelDark = light ? 0.20 : 0.45
        outline = light ? ClockDesign.black(0.22) : ClockDesign.black(0.7)
        recess = light ? [rgb(0xA9A9A6), rgb(0xD4D4D1), rgb(0xFFFFFF)] : [rgb(0x0B0C0D), rgb(0x1A1B1D), rgb(0x55575A)]
        // Dial.
        switch finish {
        case .lagoon:
            crystalEdge = [rgb(0xD6DDE2), rgb(0xEEF2F5)]
            dial = [rgb(0x56BDE8), rgb(0x1E8AC6), rgb(0x0B4F7D)]
            dialShade = 0.35; dialGrain = 0
        case .white:
            crystalEdge = [rgb(0xDCDCD9), rgb(0xF0F0EE)]
            dial = [rgb(0xFFFFFF), rgb(0xFBFBF9), rgb(0xF0F0ED)]
            dialShade = 0.16; dialGrain = 0.03
        default:
            crystalEdge = [rgb(0x0E0F10), rgb(0x161719)]
            dial = [rgb(0x232426), rgb(0x1C1D1F), rgb(0x161718)]
            dialShade = 0.45; dialGrain = 0.05
        }
        ink = darkDial ? rgb(0xEDEDE7) : rgb(0x1B1B1D)
        minorTickAlpha = style.family == .cube ? 1 : (darkDial ? 0.45 : 0.5)
        // Hands.
        let handInk = darkDial ? ClockDesign.handWhite : rgb(0x1A1A1C)
        switch style.hands {
        case .classic, .lume: hour = handInk; minute = handInk; second = Self.yellow; hub = Self.yellow
        case .redMinute: hour = handInk; minute = Self.red; second = Self.yellow; hub = Self.yellow
        case .redSeconds: hour = handInk; minute = handInk; second = Self.red; hub = Self.red
        case .allRed: hour = Self.red; minute = Self.red; second = Self.red; hub = Self.red
        case .mono: hour = handInk; minute = handInk; second = handInk; hub = handInk
        }
        lume = style.hands == .lume ? (darkDial ? rgb(0xD4E8CD) : rgb(0xBDE2B4)) : nil
        pin = darkDial ? rgb(0x161718) : rgb(0x1A1A1C)
        alarmShaft = darkDial ? rgb(0x3A3B3E) : rgb(0xB9B9B5)
        glass = finish == .lagoon ? 1.6 : (light ? 0.7 : 1)
        dateWindow = finish == .white ? rgb(0xFFFFFF) : rgb(0xF4F4F0)
        dateText = rgb(0x1A1A1C)
    }

    /// The colour lightened (positive) or darkened (negative).
    static func shade(_ color: CGColor, _ amount: CGFloat) -> CGColor {
        guard let rgb = color.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil),
              let comps = rgb.components, comps.count >= 3 else { return color }
        let target: CGFloat = amount > 0 ? 1 : 0, t = abs(amount)
        return CGColor(srgbRed: comps[0] + (target - comps[0]) * t, green: comps[1] + (target - comps[1]) * t,
                       blue: comps[2] + (target - comps[2]) * t, alpha: comps.count > 3 ? comps[3] : 1)
    }
}

// MARK: - Dial kit

struct HandShape {
    var length: CGFloat
    var width: CGFloat
    var tail: CGFloat
    /// Tip width for a tapered hand; nil for a straight baton.
    var tipWidth: CGFloat? = nil
    /// Corner radius as a fraction of the width.
    var corner: CGFloat = 0.5
}

/// Geometry of an analog dial in its face's artboard units.
struct DialSpec {
    var center: CGPoint
    var face: CGFloat
    var tickOuter: CGFloat
    var minorTick: CGSize
    var majorTick: CGSize
    var roundTicks = false
    var numeralSize: CGFloat
    var numeralGap: CGFloat
    var numeralFont = "HelveticaNeue"
    var hour: HandShape
    var minute: HandShape
    var second: HandShape
    var alarmLength: CGFloat
    var counterweight: (radius: CGFloat, offset: CGFloat)? = nil
    var hubRadius: CGFloat
    var pinRadius: CGFloat = 0
    var glassRadius: CGFloat

    func circle(_ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}

/// Dial parts shared by every analog face.
enum DialKit {
    static func ticks(_ c: CGContext, _ d: DialSpec, _ p: ClockPalette, minuteTicks: Bool = true) {
        for index in 0..<60 where minuteTicks || index % 5 == 0 {
            let major = index % 5 == 0
            let size = major ? d.majorTick : d.minorTick
            c.saveGState()
            c.translateBy(x: d.center.x, y: d.center.y)
            c.rotate(by: CGFloat(index) * .pi / 30)
            c.setFillColor(major ? p.ink : p.ink.copy(alpha: p.minorTickAlpha) ?? p.ink)
            let rect = CGRect(x: -size.width / 2, y: -d.tickOuter, width: size.width, height: size.height)
            if d.roundTicks {
                c.addPath(CGPath(roundedRect: rect, cornerWidth: size.width / 2, cornerHeight: size.width / 2, transform: nil)); c.fillPath()
            } else { c.fill(rect) }
            c.restoreGState()
        }
    }

    /// Each numeral sits so its nearest edge keeps the same gap from the hour ticks.
    static func numerals(_ c: CGContext, _ d: DialSpec, _ p: ClockPalette, _ style: ClockStyle) {
        let roman = style.numerals == .roman
        let size = d.numeralSize * (roman ? 0.92 : style.numerals == .quarters ? 1.3 : 1)
        let font = CTFontCreateWithName((roman ? "Baskerville" : d.numeralFont) as CFString, size, nil)
        for position in 1...12 {
            if style.dateWindow && position == 3 { continue }
            guard let label = style.numerals.label(position) else { continue }
            place(c, label, font: font, color: p.ink, d, angle: CGFloat(position) * .pi / 6,
                  kern: roman ? 0 : -1.5, maxWidth: d.numeralSize * (roman ? 2.0 : 1.6))
        }
    }

    /// "quartz", small, between the centre and the 6.
    static func dialText(_ c: CGContext, _ d: DialSpec, _ p: ClockPalette) {
        let font = CTFontCreateWithName("HelveticaNeue" as CFString, d.face * 0.075, nil)
        let line = textLine("quartz", font: font, color: p.ink.copy(alpha: 0.6) ?? p.ink, kern: 0.5)
        drawCentred(c, line, at: CGPoint(x: d.center.x, y: d.center.y + d.face * 0.40))
    }

    /// Where the date window sits: at 3 o'clock, inside the hour ticks.
    static func dateRect(_ d: DialSpec) -> CGRect {
        let width = d.numeralSize * 1.25, height = d.numeralSize * 0.95
        let outer = d.tickOuter - d.majorTick.height - d.numeralGap
        return CGRect(x: d.center.x + outer - width, y: d.center.y - height / 2, width: width, height: height)
    }

    /// The area one part covers when pointing at 12, with room for antialiasing.
    static func region(_ kind: ClockDesign.HandKind, _ d: DialSpec) -> CGRect {
        let pad: CGFloat = 6
        let shape: HandShape = switch kind {
        case .hour: d.hour
        case .minute: d.minute
        case .second: d.second
        case .alarm: HandShape(length: d.alarmLength, width: 9, tail: 0)
        }
        var half = shape.width / 2, below = shape.tail
        if kind == .second, let weight = d.counterweight { half = max(half, weight.radius); below = max(below, weight.offset + weight.radius) }
        return CGRect(x: d.center.x - half - pad, y: d.center.y - shape.length - pad, width: (half + pad) * 2, height: shape.length + below + pad * 2)
    }

    /// A small window at 3 o'clock showing the day of the month.
    static func dateWindow(_ c: CGContext, _ d: DialSpec, _ p: ClockPalette, day: Int) {
        let rect = dateRect(d), height = rect.height
        let path = CGPath(roundedRect: rect, cornerWidth: height * 0.12, cornerHeight: height * 0.12, transform: nil)
        c.saveGState()
        c.addPath(path); c.setFillColor(p.darkDial ? ClockDesign.rgb(0x101112) : ClockDesign.rgb(0xC9C9C5)); c.fillPath()
        c.addPath(CGPath(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerWidth: height * 0.1, cornerHeight: height * 0.1, transform: nil))
        c.clip()
        ClockDesign.linear(c, [ClockPalette.shade(p.dateWindow, -0.12), p.dateWindow], [0, 0.35],
                           from: CGPoint(x: 0, y: rect.minY), to: CGPoint(x: 0, y: rect.maxY))
        c.restoreGState()
        let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, height * 0.66, nil)
        drawCentred(c, textLine("\(day)", font: font, color: p.dateText, kern: -0.5), at: CGPoint(x: rect.midX, y: rect.midY))
    }

    /// One hand pointing at 12, without a shadow. Callers rotate about the dial centre.
    static func drawHand(_ c: CGContext, _ d: DialSpec, _ p: ClockPalette, _ kind: ClockDesign.HandKind) {
        c.saveGState()
        c.translateBy(x: d.center.x, y: d.center.y)
        switch kind {
        case .hour: baton(c, d.hour, p.hour, lume: p.lume)
        case .minute: baton(c, d.minute, p.minute, lume: p.lume)
        case .second:
            let hand = d.second
            let path = CGMutablePath()
            if let tip = hand.tipWidth {
                path.move(to: CGPoint(x: -hand.width / 2, y: 0))
                path.addLine(to: CGPoint(x: -tip / 2, y: -hand.length))
                path.addLine(to: CGPoint(x: tip / 2, y: -hand.length))
                path.addLine(to: CGPoint(x: hand.width / 2, y: 0))
                path.addLine(to: CGPoint(x: hand.width * 0.6, y: hand.tail))
                path.addLine(to: CGPoint(x: -hand.width * 0.6, y: hand.tail))
                path.closeSubpath()
            } else {
                path.addRoundedRect(in: CGRect(x: -hand.width / 2, y: -hand.length, width: hand.width, height: hand.length + hand.tail),
                                    cornerWidth: hand.width / 2, cornerHeight: hand.width / 2)
            }
            if let weight = d.counterweight {
                path.addEllipse(in: CGRect(x: -weight.radius, y: weight.offset - weight.radius, width: weight.radius * 2, height: weight.radius * 2))
            }
            c.addPath(path); c.clip()
            let span = max(hand.width, (d.counterweight?.radius ?? 0) * 2)
            ClockDesign.linear(c, [ClockPalette.shade(p.second, 0.25), p.second, ClockPalette.shade(p.second, -0.1)], [0, 0.5, 1],
                               from: CGPoint(x: -span / 2, y: 0), to: CGPoint(x: span / 2, y: 0))
        case .alarm:
            c.setFillColor(p.alarmShaft)
            c.fill(CGRect(x: -3, y: -d.alarmLength, width: 6, height: d.alarmLength))
            c.setFillColor(ClockDesign.alarmGreen)
            c.fill(CGRect(x: -4.5, y: -d.alarmLength, width: 9, height: d.alarmLength * 0.086))
        }
        c.restoreGState()
    }

    static func drawHub(_ c: CGContext, _ d: DialSpec, _ p: ClockPalette) {
        let rect = d.circle(d.hubRadius)
        c.saveGState()
        c.addEllipse(in: rect); c.clip()
        ClockDesign.radial(c, [ClockPalette.shade(p.hub, 0.35), p.hub, ClockPalette.shade(p.hub, -0.09)], [0, 0.5, 1],
                           center: CGPoint(x: d.center.x - d.hubRadius * 0.32, y: d.center.y - d.hubRadius * 0.4), radius: d.hubRadius * 1.45)
        c.restoreGState()
        c.saveGState()
        c.setStrokeColor(ClockPalette.shade(p.hub, -0.15)); c.setLineWidth(2)
        c.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
        if d.pinRadius > 0 { c.setFillColor(p.pin); c.fillEllipse(in: d.circle(d.pinRadius)) }
        c.restoreGState()
    }

    /// Everything that moves, in stacking order, with screen-fixed shadows.
    /// `shadowScale` converts artboard units to the context's base (shadow) space.
    static func drawMoving(_ c: CGContext, _ d: DialSpec, _ p: ClockPalette, angles: HandAngles, showSeconds: Bool,
                           alarmAngle: Double?, shadowScale: CGFloat) {
        let unit = d.face / ClockDesign.dialRadius
        func rotated(_ degrees: Double, _ kind: ClockDesign.HandKind, lift: CGFloat) {
            c.saveGState()
            ClockDesign.setShadow(c, lift: lift * unit, scale: shadowScale)
            c.translateBy(x: d.center.x, y: d.center.y)
            c.rotate(by: CGFloat(degrees) * .pi / 180)
            c.translateBy(x: -d.center.x, y: -d.center.y)
            drawHand(c, d, p, kind)
            c.restoreGState()
        }
        if let alarmAngle { rotated(alarmAngle, .alarm, lift: 2) }
        rotated(angles.hour, .hour, lift: 4)
        rotated(angles.minute, .minute, lift: 5)
        if showSeconds { rotated(angles.second, .second, lift: 7) }
        c.saveGState()
        ClockDesign.setShadow(c, lift: 7 * unit, scale: shadowScale)
        drawHub(c, d, p)
        c.restoreGState()
    }

    /// Clear crystal: a soft crescent reflection, a gentle sheen and a lit rim.
    static func glass(_ c: CGContext, center: CGPoint, radius: CGFloat, strength: CGFloat) {
        let w = ClockDesign.white
        let unit = radius / ClockDesign.bezelRadius
        c.saveGState()
        c.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)); c.clip()
        let inner = radius * 1.08
        let innerCentre = CGPoint(x: center.x + 70 * unit, y: center.y + 95 * unit)
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                     colors: [w(0), w(0.05 * strength), w(0.09 * strength)] as CFArray, locations: [0, 0.6, 1]) {
            c.drawRadialGradient(gradient, startCenter: innerCentre, startRadius: inner,
                                 endCenter: innerCentre, endRadius: inner + 160 * unit, options: [.drawsAfterEndLocation])
        }
        ClockDesign.linear(c, [w(0.035 * strength), w(0), w(0)], [0, 0.45, 1],
                           from: CGPoint(x: 0, y: center.y - radius), to: CGPoint(x: 0, y: center.y + radius))
        c.restoreGState()
        c.saveGState()
        c.addEllipse(in: CGRect(x: center.x - radius + 4 * unit, y: center.y - radius + 4 * unit, width: (radius - 4 * unit) * 2, height: (radius - 4 * unit) * 2))
        c.setLineWidth(5 * unit); c.replacePathWithStrokedPath(); c.clip()
        ClockDesign.linear(c, [w(0.06 * strength), w(0.03 * strength), w(min(0.6, 0.30 * strength))], [0, 0.45, 1],
                           from: CGPoint(x: center.x - 300 * unit, y: center.y - 340 * unit), to: CGPoint(x: center.x + 300 * unit, y: center.y + 340 * unit))
        c.restoreGState()
    }

    // MARK: Text

    static func textLine(_ text: String, font: CTFont, color: CGColor, kern: CGFloat = 0) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTKernAttributeName as String): kern
        ]))
    }

    /// Draw a line with its glyph bounds centred on `point`, upright in a y-down context.
    static func drawCentred(_ c: CGContext, _ line: CTLine, at point: CGPoint, scale: CGFloat = 1) {
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        c.saveGState()
        c.translateBy(x: point.x, y: point.y)
        c.scaleBy(x: scale, y: -scale)
        c.textMatrix = .identity
        c.textPosition = CGPoint(x: -bounds.midX, y: -bounds.midY)
        CTLineDraw(line, c)
        c.restoreGState()
    }

    private static func place(_ c: CGContext, _ label: String, font: CTFont, color: CGColor, _ d: DialSpec,
                              angle: CGFloat, kern: CGFloat, maxWidth: CGFloat) {
        let line = textLine(label, font: font, color: color, kern: kern)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let scale = min(1, maxWidth / max(1, bounds.width))
        let (sx, cy) = (sin(angle), -cos(angle))
        let outer = d.tickOuter - d.majorTick.height - d.numeralGap
        let reach = (abs(sx) * bounds.width / 2 + abs(cy) * bounds.height / 2) * scale
        drawCentred(c, line, at: CGPoint(x: d.center.x + (outer - reach) * sx, y: d.center.y + (outer - reach) * cy), scale: scale)
    }

    private static func baton(_ c: CGContext, _ hand: HandShape, _ color: CGColor, lume: CGColor?) {
        let rect = CGRect(x: -hand.width / 2, y: -hand.length, width: hand.width, height: hand.length + hand.tail)
        let radius = hand.width * hand.corner
        c.saveGState()
        c.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); c.clip()
        ClockDesign.linear(c, [ClockPalette.shade(color, 0.3), color, ClockPalette.shade(color, -0.13)], [0, 0.45, 1],
                           from: CGPoint(x: rect.minX, y: 0), to: CGPoint(x: rect.maxX, y: 0))
        c.restoreGState()
        if let lume {
            let w = hand.width * 0.42
            let strip = CGRect(x: -w / 2, y: -hand.length * 0.88, width: w, height: hand.length * 0.65)
            c.addPath(CGPath(roundedRect: strip, cornerWidth: w * 0.45, cornerHeight: w * 0.45, transform: nil))
            c.setFillColor(lume); c.fillPath()
        }
    }
}
