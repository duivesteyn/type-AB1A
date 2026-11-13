import SwiftUI
import WidgetKit

/// The clock as SwiftUI layers, for the widget, the About window and Settings previews.
///
/// Every layer is a cached image from `ClockRaster`; hands rotate about the dial centre.
/// WidgetKit archives each distinct image once and stores only rotations per timeline
/// entry, so long timelines stay small.
struct ClockFaceView: View {
    let date: Date
    let zone: TimeZone
    var style: ClockStyle = .standard
    var showSeconds = true
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let face = ClockRender.face(style)
        let crop = face.crop(style)
        GeometryReader { geometry in
            let fitted = ClockRaster.fit(crop, in: CGRect(origin: .zero, size: geometry.size))
            let pixels = ClockRaster.bucket(fitted.width * displayScale)
            let unit = fitted.width / crop.width
            ZStack(alignment: .topLeading) {
                layer(.body(control: 0), pixels)
                analog(face.dial(style), crop: crop, pixels: pixels, unit: unit)
            }
            // When the desktop dims widgets, macOS turns brightness into translucency. Flattening
            // the layers first keeps the hub solid over the hands instead of see-through.
            .compositingGroup()
            .frame(width: fitted.width, height: fitted.height)
            .position(x: fitted.midX, y: fitted.midY)
        }
        .aspectRatio(crop.width / crop.height, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Clock")
        .accessibilityValue(date.formatted(Date.FormatStyle(date: .omitted, time: showSeconds ? .standard : .shortened, timeZone: zone)))
    }

    private var dark: Bool { colorScheme == .dark }
    private var shownStyle: ClockStyle {
        var s = style; if !showSeconds { s.seconds = .hidden }; return s
    }

    @ViewBuilder private func analog(_ dial: DialSpec, crop: CGRect, pixels: Int, unit: CGFloat) -> some View {
        let angles = HandAngles.at(date, zone: zone, showSeconds: shownStyle.seconds != .hidden)
        let anchor = UnitPoint(x: (dial.center.x - crop.minX) / crop.width, y: (dial.center.y - crop.minY) / crop.height)
        let lift = dial.face / ClockDesign.dialRadius * unit
        if style.dateWindow { layer(.date(ClockReading.day(date, zone)), pixels) }
        hand(.hour, angles.hour, pixels, anchor, lift * 4)
        hand(.minute, angles.minute, pixels, anchor, lift * 5)
        if shownStyle.seconds != .hidden { hand(.second, angles.second, pixels, anchor, lift * 7) }
        layer(.hub, pixels).shadow(color: .black.opacity(0.5), radius: (4 * unit + lift * 7) * 0.5, x: lift * 7 * 0.25, y: lift * 7)
        if style.glass { layer(.glass, pixels) }
    }

    private func hand(_ kind: ClockDesign.HandKind, _ degrees: Double, _ pixels: Int, _ anchor: UnitPoint, _ lift: CGFloat) -> some View {
        layer(.hand(kind), pixels)
            .rotationEffect(.degrees(degrees), anchor: anchor)
            // Matches ClockDesign.setShadow: applied after rotation so the light stays put.
            .shadow(color: .black.opacity(0.5), radius: (lift + 4 * lift / 4) * 0.5, x: lift * 0.25, y: lift)
    }

    @ViewBuilder private func layer(_ layer: ClockRaster.Layer, _ pixels: Int) -> some View {
        if let image = ClockRaster.image(layer, style: shownStyle, dark: dark, pixels: pixels) { picture(image) }
    }

    @ViewBuilder private func picture(_ image: CGImage) -> some View {
        let view = Image(decorative: image, scale: 1).resizable().interpolation(.high)
        if #available(macOS 15.0, *) { view.widgetAccentedRenderingMode(.fullColor) } else { view }
    }
}
