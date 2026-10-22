#if os(macOS)
import AppKit

/// The desktop picture of the Mac's main display, ready to blur into the iPad's backdrop.
@MainActor
public enum Wallpaper {
    /// Small on purpose: it's blurred beyond recognition on the iPad anyway.
    static let maxDimension: CGFloat = 640

    /// Identifies the current picture cheaply, to tell whether it changed without re-encoding.
    public static func currentSignature() -> String? {
        guard let url = currentURL() else { return nil }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return "\(url.path(percentEncoded: false))|\(modified?.timeIntervalSince1970 ?? 0)"
    }

    /// `nil` when the picture can't be read, e.g. a moving Aerial wallpaper.
    public static func currentJPEG() -> Data? {
        guard let url = currentURL(), let image = NSImage(contentsOf: url) else { return nil }
        return ImageEncoding.jpeg(image, maxDimension: maxDimension, quality: 0.7)
    }

    private static func currentURL() -> URL? {
        guard let screen = NSScreen.main else { return nil }
        return NSWorkspace.shared.desktopImageURL(for: screen)
    }
}
#endif
