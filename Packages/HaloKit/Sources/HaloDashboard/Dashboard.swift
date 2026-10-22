import Foundation

/// Per-widget settings. Optional throughout, so new settings never break saved layouts.
public struct WidgetOptions: Codable, Sendable, Hashable {
    /// Deck: the actions to show, in order. `nil` shows everything the Mac offers.
    public var deckActions: [String]?
    /// Trackpad: a Deck action to run for each custom gesture, keyed by `TrackpadGesture` raw value.
    public var gestureActions: [String: String]

    public init(deckActions: [String]? = nil, gestureActions: [String: String] = [:]) {
        self.deckActions = deckActions
        self.gestureActions = gestureActions
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deckActions = try container.decodeIfPresent([String].self, forKey: .deckActions)
        gestureActions = try container.decodeIfPresent([String: String].self, forKey: .gestureActions) ?? [:]
    }
}

public struct DashboardWidget: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let kind: WidgetKind
    public var family: WidgetFamily
    public var origin: GridPoint
    public var options: WidgetOptions

    public init(id: UUID = UUID(), kind: WidgetKind, family: WidgetFamily? = nil, origin: GridPoint, options: WidgetOptions = WidgetOptions()) {
        self.id = id
        self.kind = kind
        self.family = family ?? kind.defaultFamily
        self.origin = origin
        self.options = options
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(WidgetKind.self, forKey: .kind)
        family = try container.decode(WidgetFamily.self, forKey: .family)
        origin = try container.decode(GridPoint.self, forKey: .origin)
        options = try container.decodeIfPresent(WidgetOptions.self, forKey: .options) ?? WidgetOptions()
    }

    public var frame: GridFrame {
        GridFrame(origin: origin, size: family.size)
    }
}

public struct DashboardPage: Sendable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public private(set) var widgets: [DashboardWidget]

    public init(id: UUID = UUID(), title: String, widgets: [DashboardWidget] = []) {
        self.id = id
        self.title = title
        self.widgets = widgets
    }

    public func widget(_ id: DashboardWidget.ID) -> DashboardWidget? {
        widgets.first { $0.id == id }
    }

    public func contains(_ kind: WidgetKind) -> Bool {
        widgets.contains { $0.kind == kind }
    }

    /// Whether `frame` is on the grid and clear of every other widget.
    public func isAvailable(_ frame: GridFrame, ignoring id: DashboardWidget.ID? = nil) -> Bool {
        frame.fitsGrid && !widgets.contains { $0.id != id && $0.frame.intersects(frame) }
    }

    /// The first free spot for `size`, scanning row by row like a Home Screen.
    public func firstAvailableOrigin(for size: GridSize) -> GridPoint? {
        for y in 0...max(Grid.rows - size.height, 0) {
            for x in 0...max(Grid.columns - size.width, 0) {
                let origin = GridPoint(x: x, y: y)
                if isAvailable(GridFrame(origin: origin, size: size)) { return origin }
            }
        }
        return nil
    }

    /// Adds in `family`, or the default, falling back to smaller sizes. `nil` when the page is full.
    @discardableResult
    public mutating func add(_ kind: WidgetKind, family: WidgetFamily? = nil) -> DashboardWidget? {
        let preferred = family ?? kind.defaultFamily
        let candidates = [preferred] + kind.families.filter { $0 < preferred }.reversed()
        for candidate in candidates {
            guard let origin = firstAvailableOrigin(for: candidate.size) else { continue }
            let widget = DashboardWidget(kind: kind, family: candidate, origin: origin)
            widgets.append(widget)
            return widget
        }
        return nil
    }

    @discardableResult
    public mutating func move(_ id: DashboardWidget.ID, to origin: GridPoint) -> Bool {
        update(id) { widget, page in
            let frame = GridFrame(origin: origin, size: widget.family.size)
            guard page.isAvailable(frame, ignoring: id) else { return false }
            widget.origin = origin
            return true
        }
    }

    /// Changes size, keeping the top-left corner, or nudging it up and left if the new size
    /// would run off the grid. Refused if the widget doesn't come in `family` or there's no room.
    @discardableResult
    public mutating func resize(_ id: DashboardWidget.ID, to family: WidgetFamily) -> Bool {
        update(id) { widget, page in
            guard widget.kind.families.contains(family), widget.family != family else { return false }
            let origin = GridPoint(
                x: min(widget.origin.x, Grid.columns - family.size.width),
                y: min(widget.origin.y, Grid.rows - family.size.height)
            )
            guard page.isAvailable(GridFrame(origin: origin, size: family.size), ignoring: id) else { return false }
            widget.family = family
            widget.origin = origin
            return true
        }
    }

    public mutating func setOptions(_ options: WidgetOptions, for id: DashboardWidget.ID) {
        _ = update(id) { widget, _ in
            widget.options = options
            return true
        }
    }

    public mutating func remove(_ id: DashboardWidget.ID) {
        widgets.removeAll { $0.id == id }
    }

    /// Changes one widget; `change` sees the page as it was, to check for room.
    private mutating func update(_ id: DashboardWidget.ID, _ change: (inout DashboardWidget, DashboardPage) -> Bool) -> Bool {
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return false }
        var widget = widgets[index]
        guard change(&widget, self) else { return false }
        widgets[index] = widget
        return true
    }
}

extension DashboardPage: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, title, widgets
    }

    /// Skips widgets this build can't read (an unknown kind, a size it no longer offers), so a
    /// layout from a newer or older version still opens.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        widgets = try container.decode([Lossy<DashboardWidget>].self, forKey: .widgets)
            .compactMap(\.value)
            .filter { $0.kind.families.contains($0.family) && $0.frame.fitsGrid }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(widgets, forKey: .widgets)
    }
}

/// Decodes to `nil` instead of failing the whole array.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) throws {
        value = try? Value(from: decoder)
    }
}

/// Every page, in order. The iPad owns this: it's how *this* person arranged *their* desk.
public struct Dashboard: Sendable, Hashable {
    /// Bumped when the grid itself changes; older layouts can't be mapped and start fresh.
    public static let version = 2

    public private(set) var pages: [DashboardPage]

    public init(pages: [DashboardPage]) {
        self.pages = pages.isEmpty ? [DashboardPage(title: String(localized: "Home"))] : pages
    }

    /// A first launch: one empty page, waiting to be filled.
    public static var empty: Dashboard {
        Dashboard(pages: [])
    }

    public var isEmpty: Bool {
        pages.allSatisfy(\.widgets.isEmpty)
    }

    public subscript(page id: DashboardPage.ID) -> DashboardPage? {
        get { pages.first { $0.id == id } }
        set {
            guard let newValue, let index = pages.firstIndex(where: { $0.id == id }) else { return }
            pages[index] = newValue
        }
    }

    public func index(of id: DashboardPage.ID) -> Int? {
        pages.firstIndex { $0.id == id }
    }

    /// The first page showing `kind`, e.g. where to go when an agent needs you.
    public func firstPage(containing kind: WidgetKind) -> DashboardPage? {
        pages.first { $0.contains(kind) }
    }

    @discardableResult
    public mutating func addPage(after id: DashboardPage.ID? = nil) -> DashboardPage {
        let page = DashboardPage(title: String(localized: "Page \(pages.count + 1)"))
        let index = id.flatMap(index(of:)).map { $0 + 1 } ?? pages.endIndex
        pages.insert(page, at: index)
        return page
    }

    /// The last page can't be removed: there's always somewhere to be.
    public mutating func removePage(_ id: DashboardPage.ID) {
        guard pages.count > 1 else { return }
        pages.removeAll { $0.id == id }
    }

    public mutating func movePage(_ id: DashboardPage.ID, to destination: Int) {
        guard let source = index(of: id) else { return }
        let page = pages.remove(at: source)
        pages.insert(page, at: min(max(destination, 0), pages.count))
    }
}

extension Dashboard: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, pages
    }

    public struct IncompatibleVersion: Error {}

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decodeIfPresent(Int.self, forKey: .version) == Self.version else { throw IncompatibleVersion() }
        self.init(pages: try container.decode([DashboardPage].self, forKey: .pages))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.version, forKey: .version)
        try container.encode(pages, forKey: .pages)
    }
}
