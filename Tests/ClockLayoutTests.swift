import Foundation

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
        // Source-space bounds include the complete housing and fully lifted cap.
        precondition(ClockGeometry.sourceSquare.contains(CGRect(x: 81, y: 111, width: 1095, height: 1081)))
        precondition(ClockGeometry.sourceSquare.contains(CGRect(x: 450, y: 94, width: 352, height: 49)))
        // The seconds hand must fit at every angle; its rear weight is shorter.
        for degrees in 0..<360 {
            let angle = Double(degrees) * .pi / 180
            let tip = CGPoint(x: 627 + 360 * sin(angle), y: 677 - 360 * cos(angle))
            precondition(ClockGeometry.sourceSquare.contains(tip))
        }
        print("Passed both size references, square containment, raised button and full hand rotation checks.")
    }
}
