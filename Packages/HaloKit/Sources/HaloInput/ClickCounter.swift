import Foundation
import HaloProtocol

/// Decides whether a click is a single, double or triple click, as macOS does for real mice:
/// same button, within the double-click interval, without the pointer wandering.
public struct ClickCounter: Sendable {
    public var interval: TimeInterval
    public var tolerance = 4.0

    private var last: (button: MouseButton, time: TimeInterval, x: Double, y: Double, count: Int)?

    public init(interval: TimeInterval) {
        self.interval = interval
    }

    public mutating func register(_ button: MouseButton, at time: TimeInterval, x: Double, y: Double) -> Int {
        let count: Int
        if let last, last.button == button, time - last.time <= interval,
           abs(x - last.x) <= tolerance, abs(y - last.y) <= tolerance {
            count = last.count + 1
        } else {
            count = 1
        }
        last = (button, time, x, y, count)
        return count
    }
}
