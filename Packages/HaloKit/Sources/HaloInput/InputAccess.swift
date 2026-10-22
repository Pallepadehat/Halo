#if os(macOS)
import CoreGraphics

/// Posting synthetic input needs the person's consent under Privacy & Security › Accessibility.
public enum InputAccess {
    public static var isGranted: Bool {
        CGPreflightPostEventAccess()
    }

    /// Shows the system prompt (once per app identity) and adds the helper to the Accessibility list.
    @discardableResult
    public static func request() -> Bool {
        CGRequestPostEventAccess()
    }
}
#endif
