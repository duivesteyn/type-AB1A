import SwiftUI
import WidgetKit

/// The clock as SwiftUI layers, for the widget and the About window.
///
/// Each layer is a cached full-square image from `ClockRaster`; hands are rotated about
/// the off-centre dial pivot. WidgetKit archives each image once and stores only a
/// rotation per timeline entry, so a long timeline stays small.
struct ClockFaceView: View {
    let date: Date
    let zone: TimeZone
    var showSeconds = true
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let pixels = ClockRaster.bucket(side * displayScale)
            let angles = HandAngles.at(date, zone: zone, showSeconds: showSeconds)
            let unit = side / ClockGeometry.cropSide
            ZStack {
                layer(.body(buttonProgress: 0), pixels)
                hand(.hour, angles.hour, pixels, unit: unit, lift: 4)
                hand(.minute, angles.minute, pixels, unit: unit, lift: 5)
                if showSeconds { hand(.second, angles.second, pixels, unit: unit, lift: 7) }
                layer(.hub, pixels).shadow(color: .black.opacity(0.5), radius: 5.5 * unit, x: 1.75 * unit, y: 7 * unit)
                layer(.glass, pixels)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Analog clock")
        .accessibilityValue(date.formatted(Date.FormatStyle(date: .omitted, time: showSeconds ? .standard : .shortened, timeZone: zone)))
    }

    private func hand(_ kind: ClockDesign.HandKind, _ degrees: Double, _ pixels: Int, unit: CGFloat, lift: CGFloat) -> some View {
        layer(.hand(kind), pixels)
            .rotationEffect(.degrees(degrees), anchor: UnitPoint(x: ClockGeometry.pivotFraction.x, y: ClockGeometry.pivotFraction.y))
            // Matches ClockDesign.setShadow: applied after rotation so the light stays put.
            .shadow(color: .black.opacity(0.5), radius: (4 + lift) * unit * 0.5, x: lift * 0.25 * unit, y: lift * unit)
    }

    @ViewBuilder private func layer(_ layer: ClockRaster.Layer, _ pixels: Int) -> some View {
        if let image = ClockRaster.image(layer, pixels: pixels) {
            let view = Image(decorative: image, scale: 1).resizable().interpolation(.high)
            if #available(macOS 15.0, *) { view.widgetAccentedRenderingMode(.fullColor) } else { view }
        }
    }
}
