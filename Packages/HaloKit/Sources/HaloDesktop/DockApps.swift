#if os(macOS)
import AppKit
import HaloCore

/// The apps in the Mac's Dock, in Dock order, with Finder first as the Dock shows it.
public struct DockApp: Sendable, Hashable {
    public let item: LaunchItem
    public let url: URL
}

public enum DockApps {
    static let finder = DockApp(
        item: LaunchItem(id: "com.apple.finder", name: "Finder"),
        url: URL(filePath: "/System/Library/CoreServices/Finder.app", directoryHint: .isDirectory)
    )

    public static func current() -> [DockApp] {
        let tiles = UserDefaults(suiteName: "com.apple.dock")?.array(forKey: "persistent-apps") as? [[String: Any]] ?? []
        return [finder] + parse(tiles)
    }

    /// Reads `persistent-apps` tiles: `tile-data` → `file-label`, `bundle-identifier`,
    /// `file-data._CFURLString`. Malformed or duplicate tiles are skipped.
    static func parse(_ tiles: [[String: Any]]) -> [DockApp] {
        var seen: Set<String> = [finder.item.id]
        return tiles.compactMap { tile in
            guard let data = tile["tile-data"] as? [String: Any],
                  let name = data["file-label"] as? String,
                  let urlString = (data["file-data"] as? [String: Any])?["_CFURLString"] as? String,
                  let url = URL(string: urlString)
            else { return nil }
            let id = data["bundle-identifier"] as? String ?? url.path(percentEncoded: false)
            guard seen.insert(id).inserted else { return nil }
            return DockApp(item: LaunchItem(id: id, name: name), url: url)
        }
    }

    /// The app's icon at a size that's crisp at the iPad's Dock size on a Retina screen.
    @MainActor
    public static func iconPNG(for app: DockApp) -> Data? {
        ImageEncoding.png(NSWorkspace.shared.icon(forFile: app.url.path(percentEncoded: false)), side: 180)
    }

    @MainActor
    public static func launch(_ app: DockApp) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: configuration)
    }
}
#endif
