/// Maps finger motion to pointer motion: slow movements stay precise, fast flicks cross the
/// screen. Gain grows linearly with speed between a floor and a ceiling, the same shape as
/// macOS's own trackpad curve.
public struct PointerAcceleration: Sendable, Equatable {
    /// Gain at rest, in Mac points per iPad point.
    public var minimumGain = 1.0
    public var maximumGain = 4.5
    /// Extra gain per point-per-millisecond of finger speed.
    public var gainPerSpeed = 1.6
    /// Ignore intervals longer than this when estimating speed: the finger paused.
    public var maximumInterval = 0.1

    public init() {}

    public func scaled(dx: Double, dy: Double, interval: Double) -> (dx: Double, dy: Double) {
        let gain = gain(dx: dx, dy: dy, interval: interval)
        return (dx * gain, dy * gain)
    }

    func gain(dx: Double, dy: Double, interval: Double) -> Double {
        guard interval > 0 else { return minimumGain }
        let distance = (dx * dx + dy * dy).squareRoot()
        let speed = distance / (min(interval, maximumInterval) * 1000) // points per millisecond
        return min(maximumGain, minimumGain + gainPerSpeed * speed)
    }
}
