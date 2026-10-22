import Foundation

public struct Widget: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public let kind: WidgetKind
    public var frame: GridFrame

    public init(id: UUID = UUID(), kind: WidgetKind, frame: GridFrame) {
        self.id = id
        self.kind = kind
        self.frame = frame
    }
}

public struct DashboardPage: Codable, Sendable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public private(set) var widgets: [Widget]

    public init(id: UUID = UUID(), title: String, widgets: [Widget] = []) {
        self.id = id
        self.title = title
        self.widgets = widgets
    }

    public func widget(_ id: Widget.ID) -> Widget? {
        widgets.first { $0.id == id }
    }

    public func contains(_ kind: WidgetKind) -> Bool {
        widgets.contains { $0.kind == kind }
    }

    /// Whether `frame` is on the grid and clear of every other widget.
    public func isAvailable(_ frame: GridFrame, ignoring id: Widget.ID? = nil) -> Bool {
        frame.fitsGrid && !widgets.contains { $0.id != id && $0.frame.intersects(frame) }
    }

    /// The first free spot for `size`, scanning row by row like a Home Screen.
    public func firstAvailableFrame(for size: GridSize) -> GridFrame? {
        for y in 0...(Grid.rows - size.height) {
            for x in 0...(Grid.columns - size.width) {
                let frame = GridFrame(x: x, y: y, width: size.width, height: size.height)
                if isAvailable(frame) { return frame }
            }
        }
        return nil
    }

    /// Adds at the default size, or the smallest that fits. `nil` when the page is full.
    @discardableResult
    public mutating func add(_ kind: WidgetKind) -> Widget? {
        let candidates = [kind.defaultSize, kind.minimumSize]
        guard let frame = candidates.lazy.compactMap(firstAvailableFrame).first else { return nil }
        let widget = Widget(kind: kind, frame: frame)
        widgets.append(widget)
        return widget
    }

    @discardableResult
    public mutating func move(_ id: Widget.ID, to origin: GridPoint) -> Bool {
        update(id) { GridFrame(origin: origin, size: $0.frame.size) }
    }

    /// Resizes within the kind's limits; the top-left corner stays put.
    @discardableResult
    public mutating func resize(_ id: Widget.ID, to size: GridSize) -> Bool {
        update(id) { GridFrame(origin: $0.frame.origin, size: size.clamped(to: $0.kind.sizeRange)) }
    }

    public mutating func remove(_ id: Widget.ID) {
        widgets.removeAll { $0.id == id }
    }

    private mutating func update(_ id: Widget.ID, frame makeFrame: (Widget) -> GridFrame) -> Bool {
        guard let index = widgets.firstIndex(where: { $0.id == id }) else { return false }
        let frame = makeFrame(widgets[index])
        guard frame != widgets[index].frame, isAvailable(frame, ignoring: id) else { return false }
        widgets[index].frame = frame
        return true
    }
}

/// Every page, in order. The iPad owns this: it's how *this* person arranged *their* desk.
public struct Dashboard: Codable, Sendable, Hashable {
    public private(set) var pages: [DashboardPage]

    public init(pages: [DashboardPage]) {
        self.pages = pages.isEmpty ? [DashboardPage(title: "Home")] : pages
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
