import Foundation

/// The coast after a two-finger flick: velocity decays exponentially, at the rate UIKit's
/// scroll views use, until it's too slow to notice.
public struct ScrollMomentum: Sendable, Equatable {
    /// Velocity kept per millisecond (`UIScrollView.DecelerationRate.normal`).
    public static let decelerationRate = 0.998
    /// Below this (points per second) the coast is over.
    public static let stopSpeed = 12.0
    /// A flick slower than this (points per second) doesn't coast at all.
    public static let minimumLaunchSpeed = 180.0

    public private(set) var velocity: (x: Double, y: Double)

    public init?(velocity: (x: Double, y: Double)) {
        guard Self.speed(velocity) >= Self.minimumLaunchSpeed else { return nil }
        self.velocity = velocity
    }

    /// The distance to scroll for the next `interval` seconds, or `nil` once the coast is over.
    public mutating func advance(by interval: TimeInterval) -> (dx: Double, dy: Double)? {
        guard interval > 0 else { return (0, 0) }
        let decay = pow(Self.decelerationRate, interval * 1000)
        velocity = (velocity.x * decay, velocity.y * decay)
        guard Self.speed(velocity) >= Self.stopSpeed else { return nil }
        return (velocity.x * interval, velocity.y * interval)
    }

    private static func speed(_ velocity: (x: Double, y: Double)) -> Double {
        (velocity.x * velocity.x + velocity.y * velocity.y).squareRoot()
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.velocity == rhs.velocity
    }
}
