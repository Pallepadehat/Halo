/// Scroll events carry whole pixels; this keeps the fractional remainder so slow scrolls
/// still move, and applies the person's scroll direction.
public struct ScrollAccumulator: Sendable {
    /// "Natural" scrolling: content follows the fingers.
    public var isNatural: Bool
    private var remainder = (x: 0.0, y: 0.0)

    public init(isNatural: Bool) {
        self.isNatural = isNatural
    }

    /// Wheel deltas for finger motion `dx`, `dy` (iPad points, y down). Positive wheel values
    /// scroll content towards the top/left, which is what fingers moving down/right do naturally.
    public mutating func wheelDeltas(dx: Double, dy: Double) -> (horizontal: Int32, vertical: Int32) {
        let sign = isNatural ? 1.0 : -1.0
        let x = remainder.x + dx * sign
        let y = remainder.y + dy * sign
        let whole = (x: x.rounded(.towardZero), y: y.rounded(.towardZero))
        remainder = (x - whole.x, y - whole.y)
        return (Int32(whole.x), Int32(whole.y))
    }

    public mutating func reset() {
        remainder = (0, 0)
    }
}
