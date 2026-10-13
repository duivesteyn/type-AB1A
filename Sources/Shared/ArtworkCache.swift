import AppKit
import ImageIO

/// Decode only the pixels the view can display. Bound retained image memory.
final class ArtworkCache {
    static let shared = ArtworkCache()
    private let cache = NSCache<NSString, NSImage>()
    init() { cache.totalCostLimit = 6 * 1024 * 1024; cache.countLimit = 12 }
    func image(_ name: String, pixels: Int) -> NSImage? {
        let dimension = min(1024, max(64, ((pixels + 63) / 64) * 64))
        let key = "\(name)-\(dimension)" as NSString
        if let image = cache.object(forKey: key) { return image }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Artwork"),
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: dimension,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: 1254, height: 1254))
        cache.setObject(image, forKey: key, cost: cg.bytesPerRow * cg.height)
        return image
    }
}
