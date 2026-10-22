/// What the iPad's trackpad surface asks the Mac to do. Deltas are in iPad points; the Mac
/// applies its own acceleration and scroll-direction preference.
public enum PointerEvent: Codable, Sendable, Equatable {
    /// Relative motion. `interval` is the time since the previous move, from the iPad's touch
    /// timestamps, so acceleration doesn't depend on network jitter.
    case move(dx: Double, dy: Double, interval: Double)
    /// Press or release, for drags.
    case button(MouseButton, isPressed: Bool)
    /// A complete press-and-release. The Mac decides whether it's a double click.
    case click(MouseButton)
    /// Two-finger scroll, in the direction the fingers moved.
    case scroll(dx: Double, dy: Double, phase: GesturePhase)
    case zoom(ZoomDirection)
    /// Three-finger swipe, in the direction the fingers moved.
    case swipe(SwipeDirection)
}

public enum MouseButton: String, Codable, Sendable {
    case left, right
}

public enum GesturePhase: String, Codable, Sendable {
    case began, changed, ended
}

public enum ZoomDirection: String, Codable, Sendable {
    case `in`, out
}

public enum SwipeDirection: String, Codable, Sendable {
    case left, right, up, down
}
