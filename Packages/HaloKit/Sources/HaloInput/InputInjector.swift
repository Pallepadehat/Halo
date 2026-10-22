#if os(macOS)
import AppKit
import CoreGraphics
import HaloProtocol
import Synchronization

/// Plays `PointerEvent`s on this Mac as real pointer, scroll and keyboard input.
///
/// Called straight from the network receive loop, off the main thread, so nothing on the
/// UI side can delay a pointer move. CGEvent posting is thread-safe; the little state we keep
/// (buttons held, click counting, scroll remainders) sits behind a mutex.
public final class InputInjector: Sendable {
    private struct State {
        var isLeftButtonDown = false
        var clicks: ClickCounter
        var scroll: ScrollAccumulator
    }

    private let acceleration: PointerAcceleration
    private let state: Mutex<State>

    public init(acceleration: PointerAcceleration = PointerAcceleration()) {
        self.acceleration = acceleration
        state = Mutex(State(
            clicks: ClickCounter(interval: NSEvent.doubleClickInterval),
            scroll: ScrollAccumulator(isNatural: Self.prefersNaturalScrolling)
        ))
    }

    public func play(_ event: PointerEvent) {
        guard InputAccess.isGranted else { return }
        switch event {
        case .move(let dx, let dy, let interval):
            move(by: acceleration.scaled(dx: dx, dy: dy, interval: interval))
        case .button(let button, let isPressed):
            press(button, isPressed: isPressed, clickCount: 1)
        case .click(let button):
            click(button)
        case .scroll(let dx, let dy, let phase):
            scroll(dx: dx, dy: dy, phase: phase)
        case .zoom(let direction):
            // Synthesising magnify gestures isn't public API; ⌘= and ⌘- are what apps honour.
            KeyChord(key: direction == .in ? .equals : .minus, flags: .maskCommand).post()
        case .swipe(let direction):
            KeyChord(key: Self.spaceKey(for: direction), flags: .maskControl).post()
        }
    }

    // MARK: - Pointer

    private func move(by delta: (dx: Double, dy: Double)) {
        let isDragging = state.withLock { $0.isLeftButtonDown }
        let target = Screen.clamp(CGPoint(x: Self.cursor.x + delta.dx, y: Self.cursor.y + delta.dy))
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: isDragging ? .leftMouseDragged : .mouseMoved,
            mouseCursorPosition: target,
            mouseButton: .left
        )
        // Raw deltas, for apps (and games) that read motion rather than position.
        event?.setIntegerValueField(.mouseEventDeltaX, value: Int64(delta.dx.rounded()))
        event?.setIntegerValueField(.mouseEventDeltaY, value: Int64(delta.dy.rounded()))
        event?.post(tap: .cghidEventTap)
    }

    private func click(_ button: MouseButton) {
        let location = Self.cursor
        let count = state.withLock {
            $0.clicks.register(button, at: ProcessInfo.processInfo.systemUptime, x: location.x, y: location.y)
        }
        press(button, isPressed: true, clickCount: count)
        press(button, isPressed: false, clickCount: count)
    }

    private func press(_ button: MouseButton, isPressed: Bool, clickCount: Int) {
        if button == .left { state.withLock { $0.isLeftButtonDown = isPressed } }
        let type: CGEventType = switch (button, isPressed) {
        case (.left, true): .leftMouseDown
        case (.left, false): .leftMouseUp
        case (.right, true): .rightMouseDown
        case (.right, false): .rightMouseUp
        }
        let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: Self.cursor,
            mouseButton: button == .left ? .left : .right
        )
        event?.setIntegerValueField(.mouseEventClickState, value: Int64(clickCount))
        event?.post(tap: .cghidEventTap)
    }

    // MARK: - Scrolling

    /// Pixel-precise, phased scroll events, so apps treat them like a real trackpad's.
    private func scroll(dx: Double, dy: Double, phase: GesturePhase) {
        let wheel = state.withLock { state in
            if phase == .began { state.scroll.reset() }
            return state.scroll.wheelDeltas(dx: dx, dy: dy)
        }
        let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: wheel.vertical,
            wheel2: wheel.horizontal,
            wheel3: 0
        )
        event?.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event?.setIntegerValueField(.scrollWheelEventScrollPhase, value: Self.scrollPhase(phase))
        event?.post(tap: .cghidEventTap)
    }

    /// `kCGScrollPhase…` values.
    private static func scrollPhase(_ phase: GesturePhase) -> Int64 {
        switch phase {
        case .began: 1
        case .changed: 2
        case .ended: 4
        }
    }

    // MARK: - Environment

    /// Where the pointer is now, in the global top-left-origin space CGEvent uses.
    private static var cursor: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    /// The person's System Settings › Trackpad › Natural scrolling choice. The standard
    /// defaults search list already includes the global domain, where this lives.
    private static var prefersNaturalScrolling: Bool {
        UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") as? Bool ?? true
    }

    /// Fingers moving left reveal the space to the right, as on a Magic Trackpad.
    private static func spaceKey(for direction: SwipeDirection) -> KeyChord.Key {
        switch direction {
        case .left: .rightArrow
        case .right: .leftArrow
        case .up: .upArrow      // Mission Control
        case .down: .downArrow  // App Exposé
        }
    }
}

/// A key press with modifiers, e.g. ⌃→.
public struct KeyChord: Sendable {
    /// Virtual key codes from `Carbon.HIToolbox.Events`.
    public enum Key: CGKeyCode, Sendable {
        case minus = 0x1B
        case equals = 0x18
        case leftArrow = 0x7B
        case rightArrow = 0x7C
        case downArrow = 0x7D
        case upArrow = 0x7E
        case q = 0x0C
        case five = 0x17
    }

    public let key: Key
    public let flags: CGEventFlags

    public init(key: Key, flags: CGEventFlags) {
        self.key = key
        self.flags = flags
    }

    public func post() {
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: isDown)
            event?.flags = flags
            event?.post(tap: .cghidEventTap)
        }
    }
}

/// Keeps the pointer on a display.
enum Screen {
    static func clamp(_ point: CGPoint) -> CGPoint {
        let displays = activeDisplayBounds()
        if displays.contains(where: { $0.contains(point) }) { return point }
        // Off every display: pull it to the nearest point on the closest one.
        guard let nearest = displays.min(by: { $0.distance(to: point) < $1.distance(to: point) }) else { return point }
        return CGPoint(
            x: min(max(point.x, nearest.minX), nearest.maxX - 1),
            y: min(max(point.y, nearest.minY), nearest.maxY - 1)
        )
    }

    private static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return [] }
        return displays.prefix(Int(count)).map(CGDisplayBounds)
    }
}

private extension CGRect {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = max(minX - point.x, 0, point.x - maxX)
        let dy = max(minY - point.y, 0, point.y - maxY)
        return (dx * dx + dy * dy).squareRoot()
    }
}
#endif
