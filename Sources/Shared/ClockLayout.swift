import Foundation
import CoreGraphics

/// A desktop reference size; WidgetKit supplies its own bounds to the system widget.
enum ClockSizingStandard: String, CaseIterable, Identifiable {
    case nativeMac, calendar
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nativeMac: "Native Mac · 164 pt high"
        case .calendar: "Match Calendar · 170 pt high"
        }
    }
}

enum ClockFootprint: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    func width(for standard: ClockSizingStandard) -> Double {
        switch (self, standard) {
        case (.small, .nativeMac): 164
        case (.small, .calendar): 170
        case (_, .nativeMac): 344
        case (_, .calendar): 364
        }
    }
    func height(for standard: ClockSizingStandard) -> Double {
        switch (self, standard) {
        case (.large, .nativeMac): 344
        case (.large, .calendar): 382
        case (_, .nativeMac): 164
        case (_, .calendar): 170
        }
    }
    func label(for standard: ClockSizingStandard) -> String {
        "\(rawValue.capitalized) · \(Int(width(for: standard))) × \(Int(height(for: standard)))"
    }
}

/// The square of the 1254-unit artboard every renderer shows. It holds the whole
/// housing and the fully raised top button, with the dial pivot centred left-to-right.
enum ClockGeometry {
    static let canvas: CGFloat = 1254
    static let cropSide: CGFloat = 1102
    static let cropX: CGFloat = 76
    static let cropY: CGFloat = 98
    static let sourceSquare = CGRect(x: cropX, y: cropY, width: cropSide, height: cropSide)
    /// The pivot as a fraction of the crop square, for rotating full-square layers.
    static let pivotFraction = CGPoint(x: (ClockDesign.pivot.x - cropX) / cropSide,
                                       y: (ClockDesign.pivot.y - cropY) / cropSide)
}
