import CoreGraphics
import Foundation

/// Renders clock layers into bitmaps covering a face's crop, cached per style and size.
///
/// Still layers are drawn once and reused, so the desktop clock redraws only what moves
/// and the widget shares one set of images across every timeline entry.
enum ClockRaster {
    enum Layer: Hashable {
        /// Case and dial; with `control`, the alarm control at that progress.
        case body(control: Double?)
        case hand(ClockDesign.HandKind)
        case hub
        case glass
        /// Date window showing this day.
        case date(Int)
        /// The alarm control alone, at this progress.
        case control(Double)
    }

    private static let cache: NSCache<NSString, CGImage> = {
        let cache = NSCache<NSString, CGImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()
    private static let lock = NSLock()

    /// Round a requested size up to a 32-pixel bucket so small layout changes reuse images.
    static func bucket(_ pixels: CGFloat) -> Int {
        min(2048, max(64, Int((pixels / 32).rounded(.up)) * 32))
    }

    /// A layer for `style`, `pixels` wide across the face's crop.
    static func image(_ layer: Layer, style: ClockStyle = .standard, dark: Bool = true, pixels: Int) -> CGImage? {
        image(layer, style: style, dark: dark, region: nil, pixelsPerUnit: CGFloat(pixels) / ClockRender.face(style).crop(style).width)
    }

    /// A layer drawn only within `region` of the artboard (the whole crop when nil), at a given density.
    /// The desktop clock uses this for hand-sized images that Core Animation rotates.
    static func image(_ layer: Layer, style: ClockStyle, dark: Bool, region: CGRect?, pixelsPerUnit: CGFloat) -> CGImage? {
        let face = ClockRender.face(style)
        let crop = region ?? face.crop(style)
        let width = max(1, Int((crop.width * pixelsPerUnit).rounded(.up)))
        let key = "\(layer)-\(style.cacheKey(dark: dark))-\(crop)-\(width)" as NSString
        lock.lock(); defer { lock.unlock() }
        if let cached = cache.object(forKey: key) { return cached }
        let palette = ClockPalette(style, dark: dark)
        let image = render(crop: crop, width: width) { c in
            switch layer {
            case .body(let control): ClockRender.drawStill(c, style, palette, control: control)
            case .hand(let kind): DialKit.drawHand(c, face.dial(style), palette, kind)
            case .hub: DialKit.drawHub(c, face.dial(style), palette)
            case .glass: ClockRender.drawGlass(c, style, palette)
            case .date(let day): DialKit.dateWindow(c, face.dial(style), palette, day: day)
            case .control(let progress): face.drawControl(c, style, palette, progress: progress)
            }
        }
        if let image { cache.setObject(image, forKey: key, cost: image.bytesPerRow * image.height) }
        return image
    }

    /// The complete clock in one image: icons, previews, thumbnails.
    static func composite(pixels: Int, date: Date, zone: TimeZone, style: ClockStyle = .standard, dark: Bool = true,
                          buttonProgress: Double = 0, showSeconds: Bool = true, alarmAngle: Double? = nil) -> CGImage? {
        var style = style
        if !showSeconds { style.seconds = .hidden }
        let crop = ClockRender.face(style).crop(style)
        return render(crop: crop, width: pixels) { c in
            ClockRender.drawComposite(c, style, dark: dark, date: date, zone: zone, control: buttonProgress,
                                      alarmAngle: alarmAngle, shadowScale: CGFloat(pixels) / crop.width)
        }
    }

    /// Pixel height for a crop drawn `width` pixels wide.
    static func height(_ crop: CGRect, width: Int) -> Int { max(1, Int((CGFloat(width) * crop.height / crop.width).rounded())) }

    /// A transparent bitmap whose user space is the artboard, y-down.
    static func render(crop: CGRect = ClockGeometry.sourceSquare, width: Int, _ draw: (CGContext) -> Void) -> CGImage? {
        let height = height(crop, width: width)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let c = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        c.interpolationQuality = .high
        c.setShouldAntialias(true); c.setAllowsFontSmoothing(false)
        mapArtboard(c, crop: crop, into: CGRect(x: 0, y: 0, width: width, height: height))
        draw(c)
        return c.makeImage()
    }

    /// Map `crop` of the artboard (y-down) onto `rect` in a y-up context.
    static func mapArtboard(_ c: CGContext, crop: CGRect = ClockGeometry.sourceSquare, into rect: CGRect) {
        let scale = rect.width / crop.width
        c.translateBy(x: rect.minX, y: rect.maxY)
        c.scaleBy(x: scale, y: -scale)
        c.translateBy(x: -crop.minX, y: -crop.minY)
    }

    /// Draw an image across `rect` in an artboard (y-down) context.
    static func drawLayer(_ image: CGImage, in c: CGContext, rect: CGRect = ClockGeometry.sourceSquare) {
        c.saveGState()
        c.translateBy(x: 0, y: rect.minY + rect.maxY)
        c.scaleBy(x: 1, y: -1)
        c.draw(image, in: rect)
        c.restoreGState()
    }

    /// The largest rect with `crop`'s proportions that fits in `bounds`, centred; with `standing`,
    /// resting on the bottom edge of a y-up `bounds` instead of centred vertically.
    static func fit(_ crop: CGRect, in bounds: CGRect, standing: Bool = false) -> CGRect {
        let scale = min(bounds.width / crop.width, bounds.height / crop.height)
        let size = CGSize(width: crop.width * scale, height: crop.height * scale)
        let y = standing ? bounds.minY : bounds.midY - size.height / 2
        return CGRect(x: bounds.midX - size.width / 2, y: y, width: size.width, height: size.height)
    }
}
