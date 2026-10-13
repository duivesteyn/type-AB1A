import SwiftUI
import AppKit
import WidgetKit

/// Every layer uses the original 1254-point artboard and the off-centre dial pivot.
struct ClockArtwork: View {
    let date: Date
    let zone: TimeZone
    var armed = false
    var showSeconds = true
    var alarmAngle: Double? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    private func layer(_ name: String, pixels: Int) -> some View {
        Group {
            if let image = ArtworkCache.shared.image(name, pixels: pixels) {
                if #available(macOS 15.0, *) {
                    Image(nsImage: image).resizable().interpolation(.high).widgetAccentedRenderingMode(.fullColor)
                } else { Image(nsImage: image).resizable().interpolation(.high) }
            }
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let pixels = Int(ceil(side * displayScale))
            let angles = HandAngles.at(date, zone: zone, showSeconds: showSeconds)
            let anchor = UnitPoint(x: 0.5, y: 677.0 / 1254.0)
            ZStack {
                layer("ClockBody", pixels: pixels)
                layer("ButtonWell", pixels: pixels)
                ButtonSkirt(progress: armed ? 1 : 0)
                layer("ButtonCap", pixels: pixels).offset(y: armed ? -side * 36 / 1254 : 0)
                if let alarmAngle { layer("AlarmPointer", pixels: pixels).rotationEffect(.degrees(alarmAngle), anchor: anchor) }
                layer("HourHand", pixels: pixels).rotationEffect(.degrees(angles.hour), anchor: anchor)
                layer("MinuteHand", pixels: pixels).rotationEffect(.degrees(angles.minute), anchor: anchor)
                if showSeconds { layer("SecondHand", pixels: pixels).rotationEffect(.degrees(angles.second), anchor: anchor) }
                layer("CentreHub", pixels: pixels)
            }
            .frame(width: side, height: side)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: armed)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clock")
        .accessibilityValue(date.formatted(Date.FormatStyle(date: .omitted, time: .standard, timeZone: zone)))
    }
}

private struct ButtonSkirt: View, Animatable {
    var progress: Double
    var animatableData: Double { get { progress } set { progress = newValue } }
    var body: some View {
        GeometryReader { geometry in
            let scale = geometry.size.width / 1254
            Path { path in
                path.move(to: CGPoint(x: 455 * scale, y: (177 - 36 * progress) * scale))
                path.addLine(to: CGPoint(x: 798 * scale, y: (177 - 36 * progress) * scale))
                path.addLine(to: CGPoint(x: 799 * scale, y: 178 * scale))
                path.addQuadCurve(to: CGPoint(x: 454 * scale, y: 178 * scale), control: CGPoint(x: 627 * scale, y: 184 * scale))
                path.closeSubpath()
            }.fill(LinearGradient(colors: [Color(white: 0.07), Color(white: 0.15), Color(white: 0.09), Color(white: 0.14), Color(white: 0.07)], startPoint: .leading, endPoint: .trailing))
            .opacity(progress > 0 ? 1 : 0)
        }
    }
}

/// Remove only the transparent margin of the supplied artboard. Layers keep their
/// original geometry internally; the visible housing fits a standard widget square.
struct FittedClockArtwork: View {
    let date: Date
    let zone: TimeZone
    var armed = false
    var showSeconds = true
    var alarmAngle: Double? = nil
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ClockArtwork(date: date, zone: zone, armed: armed, showSeconds: showSeconds, alarmAngle: alarmAngle)
                .frame(width: side * ClockGeometry.canvas / ClockGeometry.cropSide, height: side * ClockGeometry.canvas / ClockGeometry.cropSide)
                .offset(x: -side * ClockGeometry.cropX / ClockGeometry.cropSide, y: -side * ClockGeometry.cropY / ClockGeometry.cropSide)
        }.aspectRatio(1, contentMode: .fit).clipped()
    }
}
