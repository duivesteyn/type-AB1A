import Foundation
import CoreGraphics

@main struct ClockLayoutTests {
    static func main() {
        let expected: [(ClockSizingStandard, ClockFootprint, Double, Double)] = [
            (.nativeMac, .small, 164, 164), (.nativeMac, .medium, 344, 164), (.nativeMac, .large, 344, 344),
            (.calendar, .small, 170, 170), (.calendar, .medium, 364, 170), (.calendar, .large, 364, 382)
        ]
        for (standard, size, width, height) in expected {
            precondition(size.width(for: standard) == width && size.height(for: standard) == height)
        }

        // Cube: the visible square holds the whole housing and the fully raised button.
        let crop = ClockGeometry.sourceSquare
        precondition(crop.contains(ClockDesign.housing))
        precondition(crop.contains(ClockDesign.buttonRect(progress: 1)) && crop.contains(ClockDesign.buttonRect(progress: 0)))
        precondition(abs(ClockGeometry.pivotFraction.x - 0.5) < 0.0001)
        precondition(abs(ClockDesign.housing.midX - ClockDesign.pivot.x) < 0.0001)
        precondition(ClockDesign.counterweightOffset - ClockDesign.counterweightRadius < ClockDesign.hubRadius)

        // Every analog face: hands stay inside the ticks, the dial inside the case, controls inside the crop.
        for family in ClockFamily.allCases {
            let style = ClockStyle(family: family, finish: .automatic)
            let face = ClockRender.face(style)
            let crop = face.crop(style)
            if let control = face.controlRect(style) { precondition(crop.contains(control), "\(family) control outside crop") }
            let d = face.dial(style)
            let reach = [d.hour, d.minute, d.second].map(\.length).max()!
            precondition(reach <= d.tickOuter && d.alarmLength <= d.tickOuter && d.tickOuter < d.face, "\(family) hands too long")
            precondition(d.hour.length < d.minute.length, "\(family) hour hand longer than minute hand")
            precondition(crop.contains(d.circle(d.glassRadius)), "\(family) dial outside crop")
        }
        precondition(ArchFace.crop(.standard).contains(ArchFace.caseRect))
        precondition(ArchFace.crop(.standard).maxY == ArchFace.caseRect.maxY)
        precondition(WallFace.crop(.standard).maxY == WallFace.center.y + WallFace.rim)
        precondition(ClockGeometry.sourceSquare.maxY == ClockDesign.housing.maxY)
        // Fitted into a wide window, the clock stands on the bottom edge.
        let window = CGRect(x: 0, y: 0, width: 364, height: 382)
        for family in ClockFamily.allCases { precondition(ClockRaster.fit(ClockRender.face(ClockStyle(family: family)).crop(.standard), in: window, standing: true).minY == 0) }
        precondition(ArchFace.caseRect.contains(ArchFace.slot))

        // Styles: presets are valid, round-trip through JSON, and old saved data still loads.
        for preset in ClockPreset.all {
            precondition(preset.style.family.finishes.contains(preset.style.finish), "\(preset.id) has a finish its family lacks")
            let data = try! JSONEncoder().encode(preset.style)
            precondition(try! JSONDecoder().decode(ClockStyle.self, from: data) == preset.style)
            precondition(ClockPreset.matching(preset.style)?.id == preset.id, "\(preset.id) doesn't match itself")
        }
        let partial = try! JSONDecoder().decode(ClockStyle.self, from: Data(#"{"family":"wall","finish":"lagoon","future":1}"#.utf8))
        precondition(partial.family == .wall && partial.finish != .lagoon, "Unknown finish should be corrected")
        precondition(ClockNumerals.minutes.label(12) == "60" && ClockNumerals.roman.label(4) == "IV" && ClockNumerals.quarters.label(4) == nil)

        // Rendering: every preset draws, with transparent corners where the case is round or arched.
        for preset in ClockPreset.all {
            for dark in [true, false] {
                guard let image = ClockRaster.image(.body(control: 0), style: preset.style, dark: dark, pixels: 128),
                      let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { fatalError("\(preset.id) did not render") }
                func alpha(_ x: Int, _ y: Int) -> UInt8 { bytes[y * image.bytesPerRow + x * 4 + 3] }
                precondition(alpha(0, 0) == 0, "\(preset.id) corner should be transparent")
                precondition(alpha(image.width / 2, image.height / 2) == 255, "\(preset.id) centre should be opaque")
                // The case stands on the bottom edge: no transparent margin under it.
                precondition(alpha(image.width / 2, image.height - 1) > 200, "\(preset.id) should reach the bottom edge")
            }
        }
        precondition(ClockRaster.bucket(170) == 192 && ClockRaster.bucket(10) == 64 && ClockRaster.bucket(9000) == 2048)
        print("Passed sizes, every face's geometry, style storage and rendering of all \(ClockPreset.all.count) presets.")
    }
}
