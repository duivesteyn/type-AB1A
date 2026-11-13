import CoreGraphics
import CoreText
import Foundation

private func rgb(_ hex: UInt32) -> CGColor { ClockDesign.rgb(hex) }

/// Shadow under a whole case, scaled to the bitmap it is drawn into.
private func caseShadow(_ c: CGContext, _ path: CGPath, _ p: ClockPalette, drop: CGFloat, blur: CGFloat) {
    let scale = abs(c.userSpaceToDeviceSpaceTransform.a)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -drop * scale), blur: blur * scale, color: ClockDesign.black(p.dark ? 0.45 : 0.25))
    c.addPath(path); c.setFillColor(p.housing[1]); c.fillPath()
    c.restoreGState()
}

// MARK: - Arch

/// A desk alarm clock with a round-topped, tower-like case (width : height = 1 : 1.133),
/// a dial concentric with the arch, and an alarm slider in the base.
enum ArchFace: ClockFace {
    static let caseRect = CGRect(x: 40, y: 30, width: 856, height: 970)
    static let center = CGPoint(x: 468, y: 458)
    static let bezel: CGFloat = 347
    static let slot = CGRect(x: 600, y: 896, width: 200, height: 44)

    static let spec = DialSpec(
        center: center, face: 327, tickOuter: 311, minorTick: CGSize(width: 2.8, height: 13), majorTick: CGSize(width: 5.1, height: 44),
        roundTicks: true, numeralSize: 50, numeralGap: 12, numeralFont: "HelveticaNeue-Medium",
        hour: HandShape(length: 170, width: 24, tail: 28, corner: 0.35),
        minute: HandShape(length: 268, width: 21, tail: 28, corner: 0.35),
        second: HandShape(length: 288, width: 9.4, tail: 82, tipWidth: 4.3),
        alarmLength: 300, counterweight: (17, 36), hubRadius: 37, glassRadius: bezel)

    /// Ends exactly at the base, so the clock can stand on the bottom of the screen.
    static func crop(_ style: ClockStyle) -> CGRect { CGRect(x: 0, y: 0, width: 936, height: caseRect.maxY) }
    static func dial(_ style: ClockStyle) -> DialSpec { spec }
    static var controlBehindBody: Bool { false }
    static func controlRect(_ style: ClockStyle) -> CGRect? { slot.insetBy(dx: -20, dy: -24) }

    static func casePath() -> CGPath {
        let r = caseRect, arch = r.width / 2, corner = r.width * 0.055
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r.minX, y: r.maxY - corner))
        path.addLine(to: CGPoint(x: r.minX, y: center.y))
        path.addArc(center: center, radius: arch, startAngle: .pi, endAngle: 0, clockwise: false)
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - corner))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - corner, y: r.maxY), radius: corner)
        path.addLine(to: CGPoint(x: r.minX + corner, y: r.maxY))
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - corner), radius: corner)
        path.closeSubpath()
        return path
    }

    static func drawBody(_ c: CGContext, _ style: ClockStyle, _ p: ClockPalette) {
        let path = casePath()
        caseShadow(c, path, p, drop: 14, blur: 30)
        ClockDesign.drawHousingSurface(c, path, bounds: caseRect, p)
        // A fine engraved line marks off the base.
        let groove = caseRect.minY + 832
        c.saveGState()
        c.setFillColor(ClockDesign.black(p.dark ? 0.55 : 0.12)); c.fill(CGRect(x: caseRect.minX + 36, y: groove, width: caseRect.width - 72, height: 2))
        c.setFillColor(ClockDesign.white(p.dark ? 0.08 : 0.9)); c.fill(CGRect(x: caseRect.minX + 36, y: groove + 2, width: caseRect.width - 72, height: 1.5))
        c.restoreGState()
        // "alarm", printed beside the slider.
        let font = CTFontCreateWithName("HelveticaNeue" as CFString, 26, nil)
        let label = DialKit.textLine("alarm", font: font, color: p.dark ? ClockDesign.white(0.45) : ClockDesign.black(0.4), kern: 1)
        let width = CTLineGetBoundsWithOptions(label, .useGlyphPathBounds).width
        DialKit.drawCentred(c, label, at: CGPoint(x: slot.minX - 26 - width / 2, y: slot.midY))
        ClockDesign.drawDialRecess(c, p, center: center, radius: bezel, chamfer: 9)
        ClockDesign.drawDial(c, p, spec)
        DialKit.ticks(c, spec, p)
        DialKit.numerals(c, spec, p, style)
        if style.dialText { DialKit.dialText(c, spec, p) }
    }

    /// A recessed slot. Sliding the knob right uncovers signal green: the alarm is armed.
    static func drawControl(_ c: CGContext, _ style: ClockStyle, _ p: ClockPalette, progress: Double) {
        let slotPath = CGPath(roundedRect: slot, cornerWidth: slot.height / 2, cornerHeight: slot.height / 2, transform: nil)
        c.saveGState()
        c.addPath(slotPath); c.clip()
        ClockDesign.linear(c, [rgb(0x050506), rgb(0x1C1C1E)], [0, 1], from: CGPoint(x: 0, y: slot.minY), to: CGPoint(x: 0, y: slot.maxY))
        c.setFillColor(rgb(0x52D032))
        c.fill(CGRect(x: slot.minX + 8, y: slot.minY + 9, width: 84, height: slot.height - 18))
        c.restoreGState()
        // Knob.
        let knob = CGRect(x: slot.minX + 4 + 100 * CGFloat(progress), y: slot.minY - 6, width: 92, height: slot.height + 12)
        let knobPath = CGPath(roundedRect: knob, cornerWidth: 18, cornerHeight: 18, transform: nil)
        c.saveGState()
        let scale = abs(c.userSpaceToDeviceSpaceTransform.a)
        c.setShadow(offset: CGSize(width: 0, height: -3 * scale), blur: 6 * scale, color: ClockDesign.black(0.4))
        c.addPath(knobPath); c.setFillColor(p.housing[0]); c.fillPath()
        c.restoreGState()
        c.saveGState()
        c.addPath(knobPath); c.clip()
        ClockDesign.linear(c, [ClockPalette.shade(p.housing[0], 0.12), p.housing[2]], [0, 1], from: CGPoint(x: 0, y: knob.minY), to: CGPoint(x: 0, y: knob.maxY))
        c.setFillColor(ClockDesign.black(p.dark ? 0.5 : 0.18))
        for i in 0..<4 { c.fill(CGRect(x: knob.midX - 21 + CGFloat(i) * 13, y: knob.minY + 14, width: 3, height: knob.height - 28)) }
        c.restoreGState()
    }
}

// MARK: - Wall

/// A round wall clock: a broad moulded rim, a stepped bezel and a large, airy dial.
enum WallFace: ClockFace {
    static let center = CGPoint(x: 500, y: 500)
    static let rim: CGFloat = 460

    static let spec = DialSpec(
        center: center, face: 410, tickOuter: 390, minorTick: CGSize(width: 3, height: 16), majorTick: CGSize(width: 5.5, height: 35),
        roundTicks: true, numeralSize: 64, numeralGap: 16, numeralFont: "HelveticaNeue-Medium",
        hour: HandShape(length: 213, width: 27, tail: 36, corner: 0.35),
        minute: HandShape(length: 336, width: 24, tail: 36, corner: 0.35),
        second: HandShape(length: 361, width: 10, tail: 103, tipWidth: 4.6),
        alarmLength: 380, counterweight: (22, 45), hubRadius: 47, glassRadius: 428)

    /// Ends exactly at the bottom of the rim.
    static func crop(_ style: ClockStyle) -> CGRect { CGRect(x: 0, y: 0, width: 1000, height: center.y + rim) }
    static func dial(_ style: ClockStyle) -> DialSpec { spec }
    static var controlBehindBody: Bool { false }
    static func controlRect(_ style: ClockStyle) -> CGRect? { nil }
    static func drawControl(_ c: CGContext, _ style: ClockStyle, _ palette: ClockPalette, progress: Double) {}

    static func drawBody(_ c: CGContext, _ style: ClockStyle, _ p: ClockPalette) {
        let rimRect = spec.circle(rim)
        let path = CGPath(ellipseIn: rimRect, transform: nil)
        caseShadow(c, path, p, drop: 18, blur: 36)
        ClockDesign.drawHousingSurface(c, path, bounds: rimRect, p)
        // Stepped bezel: a narrow lit ring before the recess.
        c.saveGState()
        c.addEllipse(in: spec.circle(442)); c.setLineWidth(5); c.replacePathWithStrokedPath(); c.clip()
        ClockDesign.linear(c, [ClockDesign.black(p.dark ? 0.5 : 0.15), ClockDesign.white(p.dark ? 0.12 : 0.9)], [0, 1],
                           from: CGPoint(x: 0, y: center.y - 442), to: CGPoint(x: 0, y: center.y + 442))
        c.restoreGState()
        ClockDesign.drawDialRecess(c, p, center: center, radius: 428, chamfer: 10)
        ClockDesign.drawDial(c, p, spec)
        DialKit.ticks(c, spec, p)
        DialKit.numerals(c, spec, p, style)
        if style.dialText { DialKit.dialText(c, spec, p) }
    }
}
