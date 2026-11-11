import CoreGraphics
import Foundation

/// Renders `ClockDesign` layers into square bitmaps covering `ClockGeometry.sourceSquare`.
///
/// Static layers are drawn once per pixel size and cached, so the desktop clock only
/// redraws its hands each second and the widget shares one set of images across every
/// timeline entry.
enum ClockRaster {
    enum Layer: Hashable {
        case body(buttonProgress: Double?)
        case hand(ClockDesign.HandKind)
        case hub
        case glass
    }

    private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 24 * 1024 * 1024
        return cache
    }()
    private static let lock = NSLock()

    /// Round a requested size up to a 32-pixel bucket so small layout changes reuse images.
    static func bucket(_ pixels: CGFloat) -> Int {
        min(2048, max(64, Int((pixels / 32).rounded(.up)) * 32))
    }

    static func image(_ layer: Layer, pixels: Int) -> CGImage? {
        let key = "\(layer)-\(pixels)" as NSString
        lock.lock(); defer { lock.unlock() }
        if let cached = cache.object(forKey: key) { return cached }
        let image = render(pixels: pixels) { c in
            switch layer {
            case .body(let progress): ClockDesign.drawBody(c, buttonProgress: progress)
            case .hand(let kind): ClockDesign.drawHand(c, kind)
            case .hub: ClockDesign.drawHub(c)
            case .glass: ClockDesign.drawGlass(c)
            }
        }
        if let image { cache.setObject(image, forKey: key, cost: image.bytesPerRow * image.height) }
        return image
    }

    /// The complete clock in one image: used for the app icon and previews.
    static func composite(pixels: Int, date: Date, zone: TimeZone, buttonProgress: Double = 0,
                          showSeconds: Bool = true, alarmAngle: Double? = nil) -> CGImage? {
        render(pixels: pixels) { c in
            ClockDesign.drawBody(c, buttonProgress: buttonProgress)
            ClockDesign.drawMovingParts(c, angles: HandAngles.at(date, zone: zone, showSeconds: showSeconds),
                                        showSeconds: showSeconds, alarmAngle: alarmAngle,
                                        shadowScale: CGFloat(pixels) / ClockGeometry.cropSide)
            ClockDesign.drawGlass(c)
        }
    }

    /// A transparent square bitmap whose user space is the artboard, y-down.
    static func render(pixels: Int, _ draw: (CGContext) -> Void) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let c = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.interpolationQuality = .high
        c.setShouldAntialias(true); c.setAllowsFontSmoothing(false)
        mapArtboard(c, into: CGRect(x: 0, y: 0, width: pixels, height: pixels))
        draw(c)
        return c.makeImage()
    }

    /// Map the crop square of the artboard (y-down) onto `rect` in a y-up context.
    static func mapArtboard(_ c: CGContext, into rect: CGRect) {
        let scale = rect.width / ClockGeometry.cropSide
        c.translateBy(x: rect.minX, y: rect.maxY)
        c.scaleBy(x: scale, y: -scale)
        c.translateBy(x: -ClockGeometry.cropX, y: -ClockGeometry.cropY)
    }

    /// Draw a cached layer image across the crop square in an artboard (y-down) context.
    static func drawLayer(_ image: CGImage, in c: CGContext) {
        let rect = ClockGeometry.sourceSquare
        c.saveGState()
        c.translateBy(x: 0, y: rect.minY + rect.maxY)
        c.scaleBy(x: 1, y: -1)
        c.draw(image, in: rect)
        c.restoreGState()
    }
}
