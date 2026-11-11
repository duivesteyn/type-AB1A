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
            let side = min(width, height)
            let frame = CGRect(x: (width - side)/2, y: (height - side)/2, width: side, height: side)
            precondition(CGRect(x: 0, y: 0, width: width, height: height).contains(frame))
        }
        let crop = ClockGeometry.sourceSquare
        // The visible square holds the whole housing and the fully raised button.
        precondition(crop.contains(ClockDesign.housing))
        precondition(crop.contains(ClockDesign.buttonRect(progress: 1)))
        precondition(crop.contains(ClockDesign.buttonRect(progress: 0)))
        // The pivot sits on the centre line of the crop and of the housing.
        precondition(abs(ClockGeometry.pivotFraction.x - 0.5) < 0.0001)
        precondition(abs(ClockDesign.housing.midX - ClockDesign.pivot.x) < 0.0001)
        // Every hand, at every angle, stays on the dial and inside the ticks' outer edge.
        let reach = [ClockDesign.hourHand, ClockDesign.minuteHand, ClockDesign.secondHand, ClockDesign.alarmHand].map(\.length).max()!
        precondition(reach <= ClockDesign.tickOuter && ClockDesign.tickOuter < ClockDesign.dialRadius)
        precondition(ClockDesign.dialRadius < ClockDesign.bezelRadius)
        precondition(ClockDesign.circle(ClockDesign.bezelRadius + 10).maxY < ClockDesign.housing.maxY)
        // Hour hand stays shorter than the minute hand; the counterweight hides under the hub's edge.
        precondition(ClockDesign.hourHand.length < ClockDesign.minuteHand.length)
        precondition(ClockDesign.counterweightOffset - ClockDesign.counterweightRadius < ClockDesign.hubRadius)
        // Rendering produces a square image with transparent corners and an opaque dial.
        guard let image = ClockRaster.image(.body(buttonProgress: 0), pixels: 128),
              let data = image.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { fatalError("Body did not render") }
        precondition(image.width == 128 && image.height == 128)
        func alpha(_ x: Int, _ y: Int) -> UInt8 { bytes[y * image.bytesPerRow + x * 4 + 3] }
        precondition(alpha(0, 127) == 0 && alpha(127, 127) == 0, "Corners should be transparent")
        precondition(alpha(64, 64) == 255, "Dial should be opaque")
        precondition(ClockRaster.bucket(170) == 192 && ClockRaster.bucket(10) == 64 && ClockRaster.bucket(9000) == 2048)
        print("Passed size references, crop containment, hand reach, pivot and rendering checks.")
    }
}
