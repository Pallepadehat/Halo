import Foundation
import HaloProtocol

/// One finger on the surface, in points.
public struct TouchPoint: Sendable, Equatable {
    public let id: Int
    public let x: Double
    public let y: Double

    public init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }
}

/// Turns raw touches into Mac trackpad gestures, the way a Magic Trackpad behaves:
///
/// | Fingers | Gesture              | Result                         |
/// | ------- | -------------------- | ------------------------------ |
/// | 1       | move                 | pointer moves                  |
/// | 1       | tap                  | click                          |
/// | 1       | hold, then move      | drag                           |
/// | 2       | tap                  | right click                    |
/// | 2       | move                 | scroll                         |
/// | 2       | pinch                | zoom in / out                  |
/// | 3       | swipe                | spaces, Mission Control, Exposé |
///
/// Pure and clock-free: callers pass timestamps in, so every gesture is a deterministic test.
/// Events are emitted as soon as a gesture is unambiguous, never after a recognition delay.
public struct TrackpadInterpreter: Sendable {
    public struct Configuration: Sendable {
        /// Movement under this (points) still counts as a tap or a hold.
        public var slop = 6.0
        public var tapMaximumDuration = 0.25
        public var holdToDragDuration = 0.4
        /// A pinch steps one zoom level per this change in log-scale (~20%).
        public var zoomStep = 0.18
        public var swipeDistance = 70.0

        public init() {}
    }

    public let configuration: Configuration
    private var gesture: Gesture?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Whether a hold could still turn into a drag; callers schedule `holdElapsed` while true.
    public var isAwaitingHold: Bool {
        guard let gesture else { return false }
        return gesture.fingerCount == 1 && gesture.maximumFingerCount == 1 && !gesture.hasMoved && !gesture.isDragging
    }

    /// Feed the complete set of touches after every change: began, moved or ended.
    public mutating func update(_ touches: [TouchPoint], at time: TimeInterval) -> [PointerEvent] {
        guard !touches.isEmpty else { return finish(at: time) }

        let centroid = Point.centroid(of: touches)
        let spread = Point.spread(of: touches, around: centroid)
        guard var gesture else {
            gesture = Gesture(start: time, origin: centroid, fingerCount: touches.count, spread: spread)
            return []
        }
        defer { self.gesture = gesture }

        // A finger landed or lifted: re-anchor rather than read the jump as motion.
        guard touches.count == gesture.fingerCount else {
            var events: [PointerEvent] = []
            if gesture.isScrolling, touches.count != 2 {
                events.append(.scroll(dx: 0, dy: 0, phase: .ended))
                gesture.isScrolling = false
            }
            gesture.rebase(fingerCount: touches.count, centroid: centroid, spread: spread, at: time)
            return events
        }

        let delta = centroid - gesture.last
        let interval = time - gesture.lastTime
        if (centroid - gesture.anchor).length > configuration.slop { gesture.hasMoved = true }
        gesture.last = centroid
        gesture.lastTime = time

        switch touches.count {
        case 1:
            guard gesture.hasMoved || gesture.isDragging else { return [] }
            return [.move(dx: delta.x, dy: delta.y, interval: interval)]
        case 2:
            return twoFingerEvents(delta: delta, spread: spread, gesture: &gesture)
        default:
            return swipeEvents(translation: centroid - gesture.anchor, gesture: &gesture)
        }
    }

    /// Call once `holdToDragDuration` has passed with a still finger: starts a drag.
    public mutating func holdElapsed(at time: TimeInterval) -> [PointerEvent] {
        guard isAwaitingHold, var gesture, time - gesture.start >= configuration.holdToDragDuration else { return [] }
        gesture.isDragging = true
        self.gesture = gesture
        return [.button(.left, isPressed: true)]
    }

    // MARK: - Gestures

    /// Pinch and scroll are told apart by whichever crosses its threshold first; once
    /// decided, the gesture stays that way until the fingers lift.
    private func twoFingerEvents(delta: Point, spread: Double, gesture: inout Gesture) -> [PointerEvent] {
        if !gesture.isScrolling, gesture.spread > 0, spread > 0 {
            let scale = log(spread / gesture.spread)
            if abs(scale) >= configuration.zoomStep {
                gesture.isPinching = true
                gesture.spread = spread
                return [.zoom(scale > 0 ? .in : .out)]
            }
        }
        guard !gesture.isPinching, gesture.hasMoved else { return [] }

        let phase: GesturePhase = gesture.isScrolling ? .changed : .began
        gesture.isScrolling = true
        return [.scroll(dx: delta.x, dy: delta.y, phase: phase)]
    }

    /// One swipe per gesture, along whichever axis the fingers travelled furthest.
    private func swipeEvents(translation: Point, gesture: inout Gesture) -> [PointerEvent] {
        guard !gesture.hasSwiped, translation.length >= configuration.swipeDistance else { return [] }
        gesture.hasSwiped = true
        let direction: SwipeDirection = abs(translation.x) > abs(translation.y)
            ? (translation.x < 0 ? .left : .right)
            : (translation.y < 0 ? .up : .down)
        return [.swipe(direction)]
    }

    private mutating func finish(at time: TimeInterval) -> [PointerEvent] {
        guard let gesture else { return [] }
        self.gesture = nil

        if gesture.isDragging { return [.button(.left, isPressed: false)] }
        if gesture.isScrolling { return [.scroll(dx: 0, dy: 0, phase: .ended)] }

        let isTap = !gesture.hasMoved && !gesture.isPinching && !gesture.hasSwiped
            && time - gesture.start <= configuration.tapMaximumDuration
        guard isTap else { return [] }
        switch gesture.maximumFingerCount {
        case 1: return [.click(.left)]
        case 2: return [.click(.right)]
        default: return []
        }
    }
}

// MARK: - State

private extension TrackpadInterpreter {
    struct Gesture: Sendable {
        let start: TimeInterval
        var fingerCount: Int
        var maximumFingerCount: Int
        /// Where the current finger configuration started; slop and swipes measure from here.
        var anchor: Point
        var last: Point
        var lastTime: TimeInterval
        /// Mean distance of the fingers from their centroid, for pinch detection.
        var spread: Double
        var hasMoved = false
        var isDragging = false
        var isScrolling = false
        var isPinching = false
        var hasSwiped = false

        init(start: TimeInterval, origin: Point, fingerCount: Int, spread: Double) {
            self.start = start
            self.fingerCount = fingerCount
            maximumFingerCount = fingerCount
            anchor = origin
            last = origin
            lastTime = start
            self.spread = spread
        }

        mutating func rebase(fingerCount: Int, centroid: Point, spread: Double, at time: TimeInterval) {
            self.fingerCount = fingerCount
            maximumFingerCount = max(maximumFingerCount, fingerCount)
            anchor = centroid
            last = centroid
            lastTime = time
            self.spread = spread
        }
    }
}

struct Point: Sendable, Equatable {
    var x: Double
    var y: Double

    var length: Double { (x * x + y * y).squareRoot() }

    static func - (lhs: Point, rhs: Point) -> Point {
        Point(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func centroid(of touches: [TouchPoint]) -> Point {
        let count = Double(touches.count)
        return Point(x: touches.map(\.x).reduce(0, +) / count, y: touches.map(\.y).reduce(0, +) / count)
    }

    static func spread(of touches: [TouchPoint], around centroid: Point) -> Double {
        guard touches.count > 1 else { return 0 }
        return touches.map { (Point(x: $0.x, y: $0.y) - centroid).length }.reduce(0, +) / Double(touches.count)
    }
}
