#if os(macOS)
import AppKit

/// Downscales images before they cross the network: the iPad blurs wallpapers and shows icons
/// at a few dozen points, so full-resolution originals would only cost latency.
enum ImageEncoding {
    static func jpeg(_ image: NSImage, maxDimension: CGFloat, quality: Double = 0.75) -> Data? {
        rendered(image, maxDimension: maxDimension)?
            .representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    static func png(_ image: NSImage, side: CGFloat) -> Data? {
        rendered(image, maxDimension: side, square: true)?.representation(using: .png, properties: [:])
    }

    private static func rendered(_ image: NSImage, maxDimension: CGFloat, square: Bool = false) -> NSBitmapImageRep? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = square
            ? CGSize(width: maxDimension, height: maxDimension)
            : CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(target.width), pixelsHigh: Int(target.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: CGRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1)
        return bitmap
    }
}
#endif
