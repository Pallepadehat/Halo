import Foundation
import HaloHookBridge
import os

/// The `halo-hook` binary shipped inside the helper's bundle, and the stable symlink
/// that agent configs point at.
enum HookExecutable {
    private static let log = Logger(subsystem: "app.halo", category: "HookExecutable")

    /// The path installed into agent configs. Survives the app being moved or updated.
    static let stablePath = HookBridgeLocation.executableLink

    /// Points the stable symlink at this copy of the app. Called on every launch.
    static func refreshLink() {
        guard let bundled = Bundle.main.url(forAuxiliaryExecutable: "halo-hook") else {
            log.fault("halo-hook is missing from the app bundle")
            return
        }
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: stablePath.deletingLastPathComponent(), withIntermediateDirectories: true)
            if (try? stablePath.checkResourceIsReachable()) == true || isSymlink(stablePath) {
                try fileManager.removeItem(at: stablePath)
            }
            try fileManager.createSymbolicLink(at: stablePath, withDestinationURL: bundled)
        } catch {
            log.error("Could not link halo-hook: \(error, privacy: .public)")
        }
    }

    /// `checkResourceIsReachable` follows links, so a dangling one needs its own check.
    private static func isSymlink(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true
    }
}
