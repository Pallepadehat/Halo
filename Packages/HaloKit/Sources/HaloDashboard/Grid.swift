import CoreGraphics

/// A widget's place on a page, in grid cells. Pages are a fixed grid so layouts look the
/// same on every iPad size and never need reflowing.
public struct GridFrame: Codable, Sendable, Hashable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(origin: GridPoint, size: GridSize) {
        self.init(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }

    public var origin: GridPoint { GridPoint(x: x, y: y) }
    public var size: GridSize { GridSize(width: width, height: height) }
    public var maxX: Int { x + width }
    public var maxY: Int { y + height }

    public func intersects(_ other: GridFrame) -> Bool {
        x < other.maxX && other.x < maxX && y < other.maxY && other.y < maxY
    }

    public var fitsGrid: Bool {
        x >= 0 && y >= 0 && width > 0 && height > 0 && maxX <= Grid.columns && maxY <= Grid.rows
    }
}

public struct GridPoint: Codable, Sendable, Hashable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct GridSize: Codable, Sendable, Hashable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    func clamped(to range: ClosedRange<GridSize>) -> GridSize {
        GridSize(
            width: min(max(width, range.lowerBound.width), range.upperBound.width),
            height: min(max(height, range.lowerBound.height), range.upperBound.height)
        )
    }
}

extension GridSize: Comparable {
    /// Component-wise, so `min...max` reads as a size range.
    public static func < (lhs: GridSize, rhs: GridSize) -> Bool {
        lhs.width <= rhs.width && lhs.height <= rhs.height && lhs != rhs
    }
}

public enum Grid {
    /// Landscape iPad: twelve columns, eight rows.
    public static let columns = 12
    public static let rows = 8
}

/// Converts between grid cells and points for a page of a given size.
public struct GridGeometry: Sendable, Equatable {
    public let bounds: CGSize
    public let spacing: CGFloat

    public init(bounds: CGSize, spacing: CGFloat = 16) {
        self.bounds = bounds
        self.spacing = spacing
    }

    public var cellSize: CGSize {
        CGSize(
            width: (bounds.width - spacing * CGFloat(Grid.columns - 1)) / CGFloat(Grid.columns),
            height: (bounds.height - spacing * CGFloat(Grid.rows - 1)) / CGFloat(Grid.rows)
        )
    }

    public func rect(for frame: GridFrame) -> CGRect {
        let cell = cellSize
        return CGRect(
            x: CGFloat(frame.x) * (cell.width + spacing),
            y: CGFloat(frame.y) * (cell.height + spacing),
            width: CGFloat(frame.width) * cell.width + CGFloat(frame.width - 1) * spacing,
            height: CGFloat(frame.height) * cell.height + CGFloat(frame.height - 1) * spacing
        )
    }

    /// The cell origin nearest a point, e.g. while dragging a widget's top-left corner.
    public func nearestOrigin(to point: CGPoint, for size: GridSize) -> GridPoint {
        let pitch = CGSize(width: cellSize.width + spacing, height: cellSize.height + spacing)
        let x = Int((point.x / pitch.width).rounded())
        let y = Int((point.y / pitch.height).rounded())
        return GridPoint(
            x: min(max(x, 0), Grid.columns - size.width),
            y: min(max(y, 0), Grid.rows - size.height)
        )
    }

    /// The size whose bottom-right corner lands nearest a point, measured from `origin`.
    public func nearestSize(reaching point: CGPoint, from origin: GridPoint) -> GridSize {
        let pitch = CGSize(width: cellSize.width + spacing, height: cellSize.height + spacing)
        let start = rect(for: GridFrame(origin: origin, size: GridSize(width: 1, height: 1))).origin
        return GridSize(
            width: max(1, Int(((point.x - start.x + spacing) / pitch.width).rounded())),
            height: max(1, Int(((point.y - start.y + spacing) / pitch.height).rounded()))
        )
    }
}
