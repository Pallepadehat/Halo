import Foundation

/// Well-known filesystem locations shared by the helper and `halo-hook`.
public enum HookBridgeLocation {
    /// `~/Library/Application Support/Halo`, created with owner-only permissions.
    public static let supportDirectory = URL.applicationSupportDirectory
        .appending(path: "Halo", directoryHint: .isDirectory)

    /// The Unix domain socket the helper listens on.
    public static let socket = supportDirectory.appending(path: "hook.sock", directoryHint: .notDirectory)

    /// A stable path to `halo-hook` that agent configs point at. The helper refreshes this
    /// symlink on launch, so moving the app doesn't break installed hooks.
    public static let executableLink = supportDirectory.appending(path: "bin/halo-hook", directoryHint: .notDirectory)
}
